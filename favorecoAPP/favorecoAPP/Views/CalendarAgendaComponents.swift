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
    let ticketVisualStage: TicketProgressVisualStage?
}

struct CalendarNextActionRow: View {
    let item: CalendarNextActionItem
    @Environment(\.favorecoThemePalette) private var themePalette

    private var fallbackTint: Color {
        themePalette.categoryColor(hex: item.plan.category?.colorHex ?? "#147C88")
    }

    private var actionTint: Color {
        if let ticketVisualStage = item.ticketVisualStage {
            return TicketProgressColorPalette.color(for: ticketVisualStage)
        }
        return fallbackTint
    }

    private var planTitle: String {
        let title = item.plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let eventTitle = item.plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return eventTitle.isEmpty ? "予定" : eventTitle
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            FavorecoIcon(systemName: item.systemImage, size: 13)
                .foregroundStyle(actionTint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(FavorecoDateText.compactDate(item.date))
                Text(FavorecoDateText.time(item.date))
            }
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(item.isOverdue ? Color.red : .secondary)
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(actionTint)
                    .lineLimit(1)

                Text(planTitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(actionTint.opacity(0.22), lineWidth: 0.75)
        }
    }
}

struct CalendarPlanSummaryRow: View {
    let plan: Plan
    var showsDate = false
    var showsEyecatch = false
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

    private var eyecatchAspectRatio: CGFloat {
        CGFloat(EyecatchAspectRatio.resolved(for: plan.event).value)
    }

    private var eyecatchHeight: CGFloat {
        44 / max(0.45, eyecatchAspectRatio)
    }

    /// 公演に直接保存した画像だけでなく、記録写真から選ばれた公演代表写真も
    /// カレンダーの予定カードへ同じ優先順位で反映する。
    private var eyecatchReference: ThumbnailReference? {
        if let visit = plan.visit {
            let path = visit.eyecatchPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty,
               let photo = (visit.photos ?? []).first(where: {
                   $0.relativePath == path && $0.mediaKind == "photo" && $0.hasStoredData
               }) {
                return .photo(photo.id)
            }
        }
        if let event = plan.event {
            if let photo = EventRepresentativePhotoResolver.photo(for: event) {
                return .photo(photo.id)
            }
            return .event(event.id)
        }
        return nil
    }

    private var scheduleText: String {
        showsDate
            ? FavorecoDateText.compactDateTime(plan.startsAt)
            : FavorecoDateText.time(plan.startsAt)
    }

    @ViewBuilder
    private var leadingArtwork: some View {
        if showsEyecatch {
            CategoryEyecatchArtwork(
                reference: eyecatchReference,
                templateKey: plan.category?.templateKey ?? plan.event?.category?.templateKey ?? "",
                backgroundColor: categoryColor.opacity(0.08),
                defaultContentMode: .fit
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: plan.category?.templateKey ?? plan.event?.category?.templateKey ?? "",
                    displaySize: size
                )
            }
            .frame(width: 44, height: eyecatchHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            FavorecoIcon(systemName: plan.category?.iconSymbol ?? "ticket", size: 20)
                .foregroundStyle(categoryColor)
                .frame(width: 44, height: 44)
                .background(
                    categoryColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingArtwork

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
                    FavorecoIconLabel(scheduleText, systemImage: "clock", iconSize: 13)
                    if !plan.venueNameSnapshot.isEmpty {
                        FavorecoIconLabel(plan.venueNameSnapshot, systemImage: "mappin.and.ellipse", iconSize: 13)
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
                    FavorecoIconLabel(ticketInputIssue.title, systemImage: ticketInputIssue.systemImage, iconSize: 13)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if let nextTicketAction {
                    FavorecoIconLabel(
                        "\(nextTicketAction.title) \(FavorecoDateText.compactDateTime(nextTicketAction.date))",
                        systemImage: nextTicketAction.systemImage,
                        iconSize: 13
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
                    FavorecoIconLabel(
                        timeLabel,
                        systemImage: event.isAllDay ? "sun.max" : "clock",
                        iconSize: 13
                    )
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

                        ForEach(dayGroups(for: group.plans), id: \.date) { dayGroup in
                            CalendarPlanTimelineDay(
                                date: dayGroup.date,
                                plans: dayGroup.plans
                            )
                        }
                    }
                }
            }
        }
    }

    private func yearMonth(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(FavorecoDateText.year(components.year ?? 0))\(components.month ?? 0)月"
    }

    private func dayGroups(for plans: [Plan]) -> [(date: Date, plans: [Plan])] {
        let calendar = Calendar.current
        return Dictionary(grouping: plans) { plan in
            calendar.startOfDay(for: plan.startsAt)
        }
        .map { date, plans in
            (date: date, plans: plans.sorted { $0.startsAt < $1.startsAt })
        }
        .sorted { $0.date < $1.date }
    }
}

private struct CalendarPlanTimelineDay: View {
    let date: Date
    let plans: [Plan]

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    private var weekday: String {
        FavorecoDateText.weekdayName(date).replacingOccurrences(of: "曜", with: "")
    }

    private var weekdayColor: Color {
        switch FavorecoDateText.weekdayNumber(date) {
        case 1: return .red.opacity(0.85)
        case 7: return .blue.opacity(0.85)
        default: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(weekday)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekdayColor)
            }
            .frame(width: 38)

            VStack(spacing: 10) {
                ForEach(plans) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        CalendarPlanSummaryRow(plan: plan, showsEyecatch: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .overlay {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color(.separator).opacity(0.55))
                    .frame(width: 1, height: max(proxy.size.height - 10, 0))
                    .offset(x: 47, y: 10)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .offset(x: 44, y: 11)
            }
            .allowsHitTesting(false)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(FavorecoDateText.fullDate(date))の予定")
    }
}

struct CalendarAgendaSection: View {
    let ticketProgressItems: [CategoryTicketProgressItem]
    let nextActionItems: [CalendarNextActionItem]
    let selectedDate: Date
    let selectedDayVisits: [Visit]
    let selectedDayPlans: [Plan]
    let selectedDayExternalEvents: [ExternalCalendarEvent]
    let showsExternalCalendarEvents: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            selectedDaySection
            nextActionSection
            ticketScheduleSection
        }
    }

    @ViewBuilder
    private var ticketScheduleSection: some View {
        if ticketProgressItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("チケットスケジュール")
                    .font(FavorecoTypography.sectionTitle)

                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "checkmark.circle")
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
                    FavorecoIcon(systemName: "checkmark.circle")
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
