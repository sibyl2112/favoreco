import SwiftUI
import SwiftData

private enum CalendarSplitPreset: String, CaseIterable {
    case calendarFocused
    case balanced
    case informationFocused

    var calendarFraction: CGFloat {
        switch self {
        case .calendarFocused: 0.75
        case .balanced: 0.5
        case .informationFocused: 0.25
        }
    }

    var accessibilityValue: String {
        switch self {
        case .calendarFocused: "カレンダー4分の3、情報4分の1"
        case .balanced: "カレンダーと情報を半分ずつ"
        case .informationFocused: "カレンダー4分の1、情報4分の3"
        }
    }

    static func nearest(to fraction: CGFloat) -> CalendarSplitPreset {
        allCases.min {
            abs($0.calendarFraction - fraction) < abs($1.calendarFraction - fraction)
        } ?? .calendarFocused
    }
}

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
    @AppStorage(AppStorageKeys.calendarSplitPreset) private var calendarSplitPresetRaw = CalendarSplitPreset.calendarFocused.rawValue
    @StateObject private var externalCalendarStore = ExternalCalendarOverlayStore()
    @State private var displayedMonth = Date().startOfMonth
    @State private var selectedDate = Date()
    @State private var notificationDestination: CalendarNotificationDestination?
    @State private var calendarSplitDragStartFraction: CGFloat?
    @State private var calendarSplitDragFraction: CGFloat?

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
        Dictionary(grouping: plans.filter { !$0.isArchived && $0.hasConfirmedSchedule }) { plan in
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
            .filter { !$0.isArchived && $0.hasConfirmedSchedule && $0.endsAt >= now }
            .prefix(5)
            .map { $0 }
    }

    private var allUpcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.hasConfirmedSchedule && $0.endsAt >= now }
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

            pinnedPeriodNavigation

            calendarContentArea
        }
    }

    @ViewBuilder
    private var calendarContentArea: some View {
        if displayMode == .planList {
            ScrollView {
                planListSection
                    .padding(20)
            }
        } else {
            splitCalendarContent
        }
    }

    @ViewBuilder
    private var pinnedPeriodNavigation: some View {
        switch displayMode {
        case .month:
            monthHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
        case .week, .day:
            timelineNavigationHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
        case .planList:
            EmptyView()
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

    private var splitCalendarPreset: CalendarSplitPreset {
        CalendarSplitPreset(rawValue: calendarSplitPresetRaw) ?? .calendarFocused
    }

    private var activeCalendarSplitFraction: CGFloat {
        calendarSplitDragFraction ?? splitCalendarPreset.calendarFraction
    }

    private var splitCalendarContent: some View {
        GeometryReader { proxy in
            let availableHeight = max(proxy.size.height, 0)
            let informationHeight = availableHeight * (1 - activeCalendarSplitFraction)

            ZStack(alignment: .bottom) {
                activeCalendarViewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                calendarInformationSheet(
                    height: informationHeight,
                    availableHeight: availableHeight
                )
            }
        }
    }

    @ViewBuilder
    private var activeCalendarViewport: some View {
        switch displayMode {
        case .month:
            ScrollView(.vertical) {
                monthGrid
            }
        case .week:
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    weekTimeline
                }
                .task(id: timelineInitialScrollKey) {
                    await scrollToCurrentTimelineTimeIfNeeded(using: proxy)
                }
            }
        case .day:
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    dayTimeline
                }
                .task(id: timelineInitialScrollKey) {
                    await scrollToCurrentTimelineTimeIfNeeded(using: proxy)
                }
            }
        case .planList:
            EmptyView()
        }
    }

    private func calendarInformationSheet(
        height: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            calendarInformationSheetHandle(availableHeight: availableHeight)

            ScrollView(.vertical) {
                calendarAgendaSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(.regularMaterial)
        .clipShape(.rect(topLeadingRadius: 18, topTrailingRadius: 18))
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: -4)
    }

    private func calendarInformationSheetHandle(availableHeight: CGFloat) -> some View {
        ZStack {
            Color.clear

            Capsule()
                .fill(Color.secondary.opacity(0.55))
                .frame(width: 44, height: 5)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .gesture(calendarSheetDragGesture(availableHeight: availableHeight))
        .accessibilityElement()
        .accessibilityLabel("カレンダー情報パネルの高さ")
        .accessibilityValue(splitCalendarPreset.accessibilityValue)
        .accessibilityAdjustableAction(adjustCalendarSplit)
    }

    private func calendarSheetDragGesture(availableHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard availableHeight > 0 else { return }
                if calendarSplitDragStartFraction == nil {
                    calendarSplitDragStartFraction = splitCalendarPreset.calendarFraction
                }
                let startFraction = calendarSplitDragStartFraction ?? splitCalendarPreset.calendarFraction
                let proposedFraction = startFraction + (value.translation.height / availableHeight)
                calendarSplitDragFraction = min(max(proposedFraction, 0.25), 0.75)
            }
            .onEnded { _ in
                let preset = CalendarSplitPreset.nearest(to: activeCalendarSplitFraction)
                withAnimation(.easeOut(duration: 0.2)) {
                    calendarSplitPresetRaw = preset.rawValue
                    calendarSplitDragFraction = nil
                    calendarSplitDragStartFraction = nil
                }
            }
    }

    private func adjustCalendarSplit(_ direction: AccessibilityAdjustmentDirection) {
        let preset: CalendarSplitPreset
        switch (splitCalendarPreset, direction) {
        case (.calendarFocused, .increment):
            preset = .balanced
        case (.balanced, .increment):
            preset = .informationFocused
        case (.informationFocused, .decrement):
            preset = .balanced
        case (.balanced, .decrement):
            preset = .calendarFocused
        default:
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            calendarSplitPresetRaw = preset.rawValue
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
        FavorecoDateText.fullDate(date)
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}
