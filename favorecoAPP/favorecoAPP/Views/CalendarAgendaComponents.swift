//
//  CalendarAgendaComponents.swift
//  favorecoAPP
//

import SwiftUI

struct CalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool

    var id: Date { date }

    static func days(for month: Date, calendar: Calendar) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leadingDays = (0..<leadingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leadingCount, to: monthInterval.start)
        }
        let currentMonthDays = monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        let totalCount = leadingDays.count + currentMonthDays.count
        let trailingCount = max(42 - totalCount, 0)
        let trailingDays = (0..<trailingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset + 1, to: currentMonthDays.last ?? monthInterval.start)
        }

        return (leadingDays + currentMonthDays + trailingDays).map { date in
            CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthInterval.start, toGranularity: .month)
            )
        }
    }
}

struct CalendarNextActionItem: Identifiable {
    let id: String
    let plan: Plan
    let title: String
    let date: Date
    let systemImage: String
    let isOverdue: Bool
    let priority: Int
}

struct CalendarNextActionRow: View {
    let item: CalendarNextActionItem
    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        item.isOverdue
            ? .red
            : themePalette.categoryColor(hex: item.plan.category?.colorHex ?? "#147C88")
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: item.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)

            Text(FavorecoDateText.compactDateTime(item.date))
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(item.isOverdue ? Color.red : .secondary)
                .fixedSize(horizontal: true, vertical: false)

            Text(item.title)
                .font(FavorecoTypography.bodyStrong)
                .lineLimit(1)

            Text(item.plan.title.isEmpty ? "予定" : item.plan.title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 0.75)
        }
    }
}

struct CalendarPlanSummaryRow: View {
    let plan: Plan
    @Environment(\.favorecoThemePalette) private var themePalette

    private var categoryColor: Color {
        themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var activeAttempts: [TicketAttempt] {
        plan.ticketAttempts?.filter { !$0.isArchived } ?? []
    }

    private var ticketAttempt: TicketAttempt? {
        TicketAttemptPresentationOrder.sorted(activeAttempts).first
    }

    private var nextTicketAction: TicketNextActionDefinition? {
        activeAttempts
            .compactMap { TicketNextActionDefinition.nextAction(for: $0) }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first
    }

    private var ticketInputIssue: TicketInputIssueDefinition? {
        activeAttempts
            .compactMap { TicketInputIssueDefinition.issue(for: $0) }
            .sorted { $0.priority < $1.priority }
            .first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: plan.category?.iconSymbol ?? "ticket")
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.title.isEmpty ? "予定" : plan.title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let ticketAttempt {
                        Text(TicketStatusDefinition.name(for: ticketAttempt.statusKey))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Label(FavorecoDateText.time(plan.startsAt), systemImage: "clock")
                    if !plan.venueNameSnapshot.isEmpty {
                        Label(plan.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let ticketAttempt, !ticketAttempt.entryRouteKey.isEmpty {
                    Text(TicketEntryRouteDefinition.name(for: ticketAttempt.entryRouteKey))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let ticketInputIssue {
                    Label(ticketInputIssue.title, systemImage: ticketInputIssue.systemImage)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if let nextTicketAction {
                    Label(
                        "\(nextTicketAction.title) \(FavorecoDateText.compactDateTime(nextTicketAction.date))",
                        systemImage: nextTicketAction.systemImage
                    )
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(nextTicketAction.isOverdue ? .red : .orange)
                    .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ExternalCalendarEventRow: View {
    let event: ExternalCalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(uiColor: event.color))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(timeLabel, systemImage: event.isAllDay ? "sun.max" : "clock")
                    Text(event.calendarTitle)
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "終日"
        }
        return "\(FavorecoDateText.time(event.startDate)) - \(FavorecoDateText.time(event.endDate))"
    }
}

struct CalendarPlanListSection: View {
    let groups: [(month: Date, plans: [Plan])]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if groups.isEmpty {
                PlaceholderRow(
                    icon: "calendar.badge.plus",
                    title: "今後の予定はありません",
                    message: "Homeまたは下部の「追加」から予定を立てられます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(groups, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(yearMonth(group.month))
                            .font(FavorecoTypography.sectionTitle)

                        ForEach(group.plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                CalendarPlanSummaryRow(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func yearMonth(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }
}

struct CalendarAgendaSection: View {
    let ticketProgressItems: [CategoryTicketProgressItem]
    let nextActionItems: [CalendarNextActionItem]
    let selectedDate: Date
    let selectedDayVisits: [Visit]
    let selectedDayPlans: [Plan]
    let selectedDayExternalEvents: [ExternalCalendarEvent]
    let upcomingPlans: [Plan]
    let upcomingVisits: [Visit]
    let upcomingExternalEvents: [ExternalCalendarEvent]
    let showsExternalCalendarEvents: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ticketScheduleSection
            nextActionSection
            selectedDaySection
            upcomingSection
        }
    }

    @ViewBuilder
    private var ticketScheduleSection: some View {
        if ticketProgressItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("チケットスケジュール")
                    .font(FavorecoTypography.sectionTitle)

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("進行中のチケット予定はありません")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else {
            CategoryTicketProgressSection(
                items: ticketProgressItems,
                title: "チケットスケジュール",
                usesLatinTitle: false,
                usesTheaterStyle: false,
                showsCategoryInSelector: true
            )
        }
    }

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("次にやること")
                    .font(FavorecoTypography.sectionTitle)
                if !nextActionItems.isEmpty {
                    Text("\(nextActionItems.count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if nextActionItems.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("今すぐ対応することはありません")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(nextActionItems.prefix(5)) { item in
                    NavigationLink {
                        PlanDetailView(plan: item.plan)
                    } label: {
                        CalendarNextActionRow(item: item)
                    }
                    .buttonStyle(.plain)
                }

                if nextActionItems.count > 5 {
                    Text("ほか\(nextActionItems.count - 5)件は各公演の準備・チケット欄で確認できます")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .trailing)
                }
            }
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FavorecoDateText.fullDate(selectedDate))
                .font(FavorecoTypography.sectionTitle)

            if selectedDayVisits.isEmpty
                && selectedDayPlans.isEmpty
                && (!showsExternalCalendarEvents || selectedDayExternalEvents.isEmpty) {
                PlaceholderRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "この日の記録はありません",
                    message: "予定や訪問記録を追加するとここに表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                selectedDayRows
            }
        }
    }

    private var selectedDayRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !selectedDayPlans.isEmpty {
                Text("予定・チケット")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)

                ForEach(selectedDayPlans) { plan in
                    planLink(plan)
                }
            }

            if !selectedDayVisits.isEmpty {
                Text("記録")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .padding(.top, selectedDayPlans.isEmpty ? 0 : 4)

                ForEach(selectedDayVisits) { visit in
                    visitLink(visit)
                }
            }

            if showsExternalCalendarEvents && !selectedDayExternalEvents.isEmpty {
                Text("外部カレンダー")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .padding(.top, selectedDayVisits.isEmpty && selectedDayPlans.isEmpty ? 0 : 4)

                ForEach(selectedDayExternalEvents) { event in
                    ExternalCalendarEventRow(event: event)
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if hasUpcomingItems {
            VStack(alignment: .leading, spacing: 12) {
                Text("直近の予定")
                    .font(FavorecoTypography.sectionTitle)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(upcomingPlans) { plan in
                        planLink(plan)
                    }

                    if !upcomingVisits.isEmpty {
                        Text("記録")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, upcomingPlans.isEmpty ? 0 : 4)

                        ForEach(upcomingVisits) { visit in
                            visitLink(visit)
                        }
                    }

                    if showsExternalCalendarEvents && !upcomingExternalEvents.isEmpty {
                        Text("外部カレンダー")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, upcomingVisits.isEmpty && upcomingPlans.isEmpty ? 0 : 4)

                        ForEach(upcomingExternalEvents) { event in
                            ExternalCalendarEventRow(event: event)
                        }
                    }
                }
            }
        }
    }

    private var hasUpcomingItems: Bool {
        !upcomingPlans.isEmpty
            || !upcomingVisits.isEmpty
            || (showsExternalCalendarEvents && !upcomingExternalEvents.isEmpty)
    }

    private func planLink(_ plan: Plan) -> some View {
        NavigationLink {
            PlanDetailView(plan: plan)
        } label: {
            CalendarPlanSummaryRow(plan: plan)
        }
        .buttonStyle(.plain)
    }

    private func visitLink(_ visit: Visit) -> some View {
        NavigationLink {
            ExperienceDetailView(visit: visit)
        } label: {
            VisitSummaryRow(visit: visit)
        }
        .buttonStyle(.plain)
    }
}
