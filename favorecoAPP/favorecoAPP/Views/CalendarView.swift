import SwiftUI
import SwiftData

private struct CalendarNotificationDestination: Identifiable, Hashable {
    let plan: Plan
    let preparationTaskID: UUID?

    var id: String {
        "\(plan.id.uuidString)-\(preparationTaskID?.uuidString ?? "plan")"
    }

    static func == (lhs: CalendarNotificationDestination, rhs: CalendarNotificationDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CalendarView: View {
    @Binding var displayMode: CalendarDisplayMode
    @Binding var requestedPlanID: String
    @Binding var requestedAttemptID: String
    @Binding var requestedPreparationTaskID: String
    @Query(sort: \Visit.visitedAt, order: .forward) private var visits: [Visit]
    @Query(sort: \Plan.startsAt, order: .forward) private var plans: [Plan]
    @Query private var ticketAttempts: [TicketAttempt]
    @AppStorage(AppStorageKeys.showsExternalCalendarEvents) private var showsExternalCalendarEvents = true
    @AppStorage(AppStorageKeys.selectedExternalCalendarIdentifiers) private var selectedExternalCalendarIdentifiers = ""
    @StateObject private var externalCalendarStore = ExternalCalendarOverlayStore()
    @State private var displayedMonth = Date().startOfMonth
    @State private var selectedDate = Date()
    @State private var notificationDestination: CalendarNotificationDestination?

    private let calendar = Calendar.current

    private var visibleVisits: [Visit] {
        visits.filter { $0.event?.isArchived != true }
    }

    private var daysInDisplayedMonth: [CalendarDay] {
        CalendarDay.days(for: displayedMonth, calendar: calendar)
    }

    private var visitsByDay: [Date: [Visit]] {
        Dictionary(grouping: visibleVisits) { visit in
            calendar.startOfDay(for: visit.visitedAt)
        }
    }

    private var plansByDay: [Date: [Plan]] {
        Dictionary(grouping: plans.filter { !$0.isArchived }) { plan in
            calendar.startOfDay(for: plan.startsAt)
        }
    }

    private var externalEventsByDay: [Date: [ExternalCalendarEvent]] {
        Dictionary(grouping: externalCalendarStore.events) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }

    private var selectedDayVisits: [Visit] {
        visitsByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var selectedDayPlans: [Plan] {
        plansByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var selectedDayExternalEvents: [ExternalCalendarEvent] {
        externalEventsByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var upcomingVisits: [Visit] {
        let today = calendar.startOfDay(for: Date())
        return visibleVisits
            .filter { calendar.startOfDay(for: $0.visitedAt) >= today }
            .prefix(5)
            .map { $0 }
    }

    private var upcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .prefix(5)
            .map { $0 }
    }

    private var allUpcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingPlanGroups: [(month: Date, plans: [Plan])] {
        Dictionary(grouping: allUpcomingPlans) { $0.startsAt.startOfMonth }
            .map { (month: $0.key, plans: $0.value.sorted { $0.startsAt < $1.startsAt }) }
            .sorted { $0.month < $1.month }
    }

    private var upcomingExternalEvents: [ExternalCalendarEvent] {
        let now = Date()
        return externalCalendarStore.events
            .filter { $0.endDate >= now }
            .prefix(5)
            .map { $0 }
    }

    private var calendarFetchInterval: DateInterval {
        switch displayMode {
        case .month, .planList:
            let days = daysInDisplayedMonth
            let start = days.first?.date ?? displayedMonth
            let lastDay = days.last?.date ?? displayedMonth
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: start, end: end)
        case .week:
            let start = selectedWeekStart
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var selectedWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
    }

    private var selectedWeekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: selectedWeekStart)
        }
    }

    private var timelineSnapshot: CalendarTimelineSnapshot {
        CalendarTimelineSnapshot.make(
            visits: visibleVisits,
            plans: plans,
            externalEvents: externalCalendarStore.events,
            showsExternalEvents: showsExternalCalendarEvents,
            calendar: calendar
        )
    }

    private var ticketProgressItems: [CategoryTicketProgressItem] {
        CategoryTicketProgressItem.activeItems(in: plans)
    }

    private var nextActionItems: [CalendarNextActionItem] {
        let now = Date()
        let ticketItems = plans
            .filter { !$0.isArchived }
            .flatMap { plan -> [CalendarNextActionItem] in
                (plan.ticketAttempts ?? []).compactMap { attempt -> CalendarNextActionItem? in
                    guard !attempt.isArchived,
                          let action = TicketNextActionDefinition.nextAction(for: attempt, now: now) else {
                        return nil
                    }
                    return CalendarNextActionItem(
                        id: "ticket-\(attempt.id.uuidString)-\(action.title)-\(action.date.timeIntervalSinceReferenceDate)",
                        plan: plan,
                        title: action.title,
                        date: action.date,
                        systemImage: action.systemImage,
                        isOverdue: action.isOverdue,
                        priority: action.priority
                    )
                }
            }

        let preparationItems = plans
            .filter { !$0.isArchived && $0.isPreparationChecklistActive }
            .flatMap { plan -> [CalendarNextActionItem] in
                plan.preparationFields.tasks.compactMap { task -> CalendarNextActionItem? in
                    guard !task.isCompleted,
                          !task.trimmedTitle.isEmpty,
                          let dueAt = task.dueAt else {
                        return nil
                    }
                    return CalendarNextActionItem(
                        id: "preparation-\(plan.id.uuidString)-\(task.id.uuidString)",
                        plan: plan,
                        title: task.trimmedTitle,
                        date: dueAt,
                        systemImage: "checklist",
                        isOverdue: dueAt < now,
                        priority: 50
                    )
                }
            }

        return (ticketItems + preparationItems)
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue
                }
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.priority < rhs.priority
            }
    }

    var body: some View {
        NavigationStack {
            notificationRoutingScreen
        }
    }

    private var notificationRoutingScreen: some View {
        externalCalendarRefreshingScreen
            .navigationDestination(item: $notificationDestination) { destination in
                PlanDetailView(
                    plan: destination.plan,
                    highlightedPreparationTaskID: destination.preparationTaskID
                )
            }
            .task(id: requestedRouteKey) {
                openRequestedPlanIfNeeded()
            }
            .onChange(of: planIDs) { _, _ in
                openRequestedPlanIfNeeded()
            }
            .onChange(of: ticketAttemptIDs) { _, _ in
                openRequestedPlanIfNeeded()
            }
    }

    private var externalCalendarRefreshingScreen: some View {
        decoratedCalendarScreen
            .task {
                await refreshExternalCalendarIfNeeded()
            }
            .onChange(of: displayedMonth) { _, _ in
                refreshExternalCalendar()
            }
            .onChange(of: selectedDate) { _, _ in
                refreshExternalCalendar()
            }
            .onChange(of: displayMode) { _, _ in
                refreshExternalCalendar()
            }
            .onChange(of: showsExternalCalendarEvents) { _, newValue in
                handleExternalCalendarVisibilityChange(isVisible: newValue)
            }
            .onChange(of: selectedExternalCalendarIdentifiers) { _, _ in
                refreshExternalCalendar()
            }
    }

    private var decoratedCalendarScreen: some View {
        calendarScreen
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
    }

    private var requestedRouteKey: String {
        "\(requestedPlanID)|\(requestedAttemptID)"
    }

    private var planIDs: [UUID] {
        plans.map(\.id)
    }

    private var ticketAttemptIDs: [UUID] {
        ticketAttempts.map(\.id)
    }

    private func refreshExternalCalendar() {
        Task {
            await refreshExternalCalendarIfNeeded()
        }
    }

    private func handleExternalCalendarVisibilityChange(isVisible: Bool) {
        guard isVisible else {
            externalCalendarStore.updateAuthorizationStatus()
            return
        }
        refreshExternalCalendar()
    }

    private var calendarScreen: some View {
        VStack(spacing: 0) {
            MainScreenHeader(
                title: "Calendar",
                usesBrandFont: true,
                usesCompactBrand: true
            )
                .padding(.horizontal, 20)
                .padding(.top, -4)
                .padding(.bottom, 6)

            CalendarDisplayToolbar(displayMode: $displayMode)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            MainHeaderDivider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        displayedCalendarContent
                    }
                    .padding(20)
                }
                .task(id: timelineInitialScrollKey) {
                    await scrollToCurrentTimelineTimeIfNeeded(using: proxy)
                }
            }
        }
    }

    private var timelineInitialScrollKey: String {
        switch displayMode {
        case .week where selectedWeekDays.contains(where: calendar.isDateInToday):
            return "week-\(selectedWeekStart.timeIntervalSinceReferenceDate)"
        case .day where calendar.isDateInToday(selectedDate):
            return "day-today"
        default:
            return "none"
        }
    }

    @MainActor
    private func scrollToCurrentTimelineTimeIfNeeded(using proxy: ScrollViewProxy) async {
        guard timelineInitialScrollKey != "none" else { return }
        try? await Task.sleep(for: .milliseconds(80))
        let currentHour = calendar.component(.hour, from: Date())
        let contextHour = max(currentHour - 1, 0)
        proxy.scrollTo(CalendarTimelineScrollTarget.hour(contextHour), anchor: .top)
    }

    @ViewBuilder
    private var displayedCalendarContent: some View {
        switch displayMode {
        case .month:
            monthCalendarContent
        case .week:
            weekCalendarContent
        case .day:
            dayCalendarContent
        case .planList:
            planListSection
        }
    }

    private var monthCalendarContent: some View {
        Group {
            monthHeader
            monthGrid
            calendarAgendaSection
        }
    }

    private var weekCalendarContent: some View {
        Group {
            timelineNavigationHeader
            weekTimeline
            calendarAgendaSection
        }
    }

    private var dayCalendarContent: some View {
        Group {
            timelineNavigationHeader
            dayTimeline
            calendarAgendaSection
        }
    }

    private func openRequestedPlanIfNeeded() {
        var destinationPlan: Plan?

        if !requestedPlanID.isEmpty {
            guard let planID = UUID(uuidString: requestedPlanID) else {
                requestedPlanID = ""
                requestedPreparationTaskID = ""
                return
            }
            destinationPlan = plans.first(where: { $0.id == planID })
        } else if !requestedAttemptID.isEmpty {
            guard let attemptID = UUID(uuidString: requestedAttemptID) else {
                requestedAttemptID = ""
                return
            }
            destinationPlan = ticketAttempts.first(where: { $0.id == attemptID })?.plan
        }

        guard let plan = destinationPlan else { return }
        guard !plan.isArchived else {
            requestedPlanID = ""
            requestedAttemptID = ""
            requestedPreparationTaskID = ""
            return
        }

        selectedDate = plan.startsAt
        displayedMonth = plan.startsAt.startOfMonth
        let preparationTaskID = UUID(uuidString: requestedPreparationTaskID)
        notificationDestination = CalendarNotificationDestination(
            plan: plan,
            preparationTaskID: preparationTaskID
        )
        requestedPlanID = ""
        requestedAttemptID = ""
        requestedPreparationTaskID = ""
    }

    private var monthHeader: some View {
        CalendarPeriodStepControls(
            title: japaneseYearMonth(displayedMonth),
            previousAccessibilityLabel: "前の月",
            nextAccessibilityLabel: "次の月",
            resetTitle: calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
                ? nil
                : "今月へ戻る",
            onPrevious: { moveDisplayedMonth(by: -1) },
            onNext: { moveDisplayedMonth(by: 1) },
            onReset: {
                displayedMonth = Date().startOfMonth
                selectedDate = Date()
            }
        )
    }

    private var timelineNavigationHeader: some View {
        CalendarPeriodStepControls(
            title: timelineTitle,
            previousAccessibilityLabel: displayMode == .week ? "前の週" : "前の日",
            nextAccessibilityLabel: displayMode == .week ? "次の週" : "次の日",
            resetTitle: calendar.isDateInToday(selectedDate)
                ? nil
                : (displayMode == .week ? "今週へ戻る" : "今日へ戻る"),
            onPrevious: { moveTimeline(by: -1) },
            onNext: { moveTimeline(by: 1) },
            onReset: {
                selectedDate = Date()
                displayedMonth = Date().startOfMonth
            }
        )
    }

    private var timelineTitle: String {
        if displayMode == .week, let lastDay = selectedWeekDays.last {
            let startMonth = calendar.component(.month, from: selectedWeekStart)
            let startDay = calendar.component(.day, from: selectedWeekStart)
            let endMonth = calendar.component(.month, from: lastDay)
            let endDay = calendar.component(.day, from: lastDay)
            return startMonth == endMonth
                ? "\(startMonth)月\(startDay)日〜\(endDay)日"
                : "\(startMonth)月\(startDay)日〜\(endMonth)月\(endDay)日"
        }
        return japaneseFullDate(selectedDate)
    }

    private func moveTimeline(by offset: Int) {
        let component: Calendar.Component = displayMode == .week ? .weekOfYear : .day
        let date = calendar.date(byAdding: component, value: offset, to: selectedDate) ?? selectedDate
        selectedDate = date
        displayedMonth = date.startOfMonth
    }

    private var planListSection: some View {
        CalendarPlanListSection(groups: upcomingPlanGroups)
    }

    private func japaneseYearMonth(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private func moveDisplayedMonth(by offset: Int) {
        let month = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
        selectMonth(month)
    }

    private func selectMonth(_ month: Date) {
        let monthStart = month.startOfMonth
        let preferredDay = calendar.component(.day, from: selectedDate)
        let lastDay = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 1
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = min(preferredDay, lastDay)

        displayedMonth = monthStart
        selectedDate = calendar.date(from: components) ?? monthStart
    }

    private var monthGrid: some View {
        let snapshot = CalendarMonthSnapshot.make(
            days: daysInDisplayedMonth,
            visitsByDay: visitsByDay,
            plansByDay: plansByDay,
            plans: plans,
            externalEventsByDay: externalEventsByDay,
            showsExternalEvents: showsExternalCalendarEvents,
            calendar: calendar
        )

        return CalendarMonthGridView(
            weekdaySymbols: weekdaySymbols,
            days: daysInDisplayedMonth,
            entriesByDay: snapshot.entriesByDay,
            selectedDate: selectedDate,
            calendar: calendar
        ) { day in
            selectedDate = day.date
            if !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = day.date.startOfMonth
            }
        }
        .padding(.horizontal, -20)
        .simultaneousGesture(
            calendarPeriodSwipeGesture(
                onPrevious: { moveDisplayedMonth(by: -1) },
                onNext: { moveDisplayedMonth(by: 1) }
            )
        )
    }

    private var weekTimeline: some View {
        CalendarWeekTimelineView(
            weekDays: selectedWeekDays,
            snapshot: timelineSnapshot,
            selectedDate: selectedDate,
            calendar: calendar
        ) { date in
            selectedDate = date
            displayedMonth = date.startOfMonth
        }
        .padding(.horizontal, -20)
        .simultaneousGesture(
            calendarPeriodSwipeGesture(
                onPrevious: { moveTimeline(by: -1) },
                onNext: { moveTimeline(by: 1) }
            )
        )
    }

    private var dayTimeline: some View {
        CalendarDayTimelineView(
            date: selectedDate,
            snapshot: timelineSnapshot,
            calendar: calendar
        )
        .padding(.horizontal, -20)
        .simultaneousGesture(
            calendarPeriodSwipeGesture(
                onPrevious: { moveTimeline(by: -1) },
                onNext: { moveTimeline(by: 1) }
            )
        )
    }

    private func calendarPeriodSwipeGesture(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                guard abs(horizontalDistance) >= 50,
                      abs(horizontalDistance) > abs(verticalDistance) else { return }

                withAnimation(.easeOut(duration: 0.18)) {
                    if horizontalDistance < 0 {
                        onNext()
                    } else {
                        onPrevious()
                    }
                }
            }
    }

    private var calendarAgendaSection: some View {
        CalendarAgendaSection(
            ticketProgressItems: ticketProgressItems,
            nextActionItems: nextActionItems,
            selectedDate: selectedDate,
            selectedDayVisits: selectedDayVisits,
            selectedDayPlans: selectedDayPlans,
            selectedDayExternalEvents: selectedDayExternalEvents,
            upcomingPlans: upcomingPlans,
            upcomingVisits: upcomingVisits,
            upcomingExternalEvents: upcomingExternalEvents,
            showsExternalCalendarEvents: showsExternalCalendarEvents
        )
    }

    private func refreshExternalCalendarIfNeeded() async {
        externalCalendarStore.updateAuthorizationStatus()
        guard showsExternalCalendarEvents else { return }
        await externalCalendarStore.refresh(
            interval: calendarFetchInterval,
            selectedCalendarIDs: ExternalCalendarSelection.identifiers(
                from: selectedExternalCalendarIdentifiers
            )
        )
    }

    private func japaneseFullDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
        let weekdayIndex = max(0, min((components.weekday ?? 1) - 1, weekdayNames.count - 1))
        return "\(components.year ?? 0)年\(components.month ?? 0)月\(components.day ?? 0)日（\(weekdayNames[weekdayIndex])）"
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}
