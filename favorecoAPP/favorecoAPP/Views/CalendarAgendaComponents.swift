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

struct CalendarSelectedDayBar: View {
    let selectedDate: Date
    let summary: String
    let bottomClearance: CGFloat
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(FavorecoDateText.fullDate(selectedDate))
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(summary)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("この日の流れ")
                        .font(FavorecoTypography.captionStrong)
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, bottomClearance)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator).opacity(0.55))
                .frame(height: 0.5)
        }
        .accessibilityLabel("\(FavorecoDateText.fullDate(selectedDate))、\(summary)")
        .accessibilityHint("この日のタイムラインを開きます")
    }
}

private enum CalendarDayTimelineEntry: Identifiable {
    case nextAction(CalendarNextActionItem)
    case plan(Plan)
    case visit(Visit)
    case external(ExternalCalendarEvent)

    var id: String {
        switch self {
        case .nextAction(let item): return "action-\(item.id)"
        case .plan(let plan): return "plan-\(plan.id.uuidString)"
        case .visit(let visit): return "visit-\(visit.id.uuidString)"
        case .external(let event): return "external-\(event.id)"
        }
    }

    var date: Date {
        switch self {
        case .nextAction(let item): return item.date
        case .plan(let plan): return plan.startsAt
        case .visit(let visit): return visit.visitedAt
        case .external(let event): return event.startDate
        }
    }

    var sortPriority: Int {
        switch self {
        case .nextAction: return 0
        case .plan: return 1
        case .external: return 2
        case .visit: return 3
        }
    }
}

struct CalendarDayTimelinePanel: View {
    let selectedDate: Date
    let nextActionItems: [CalendarNextActionItem]
    let plans: [Plan]
    let visits: [Visit]
    let externalEvents: [ExternalCalendarEvent]
    let bottomClearance: CGFloat
    let onClose: () -> Void

    private var entries: [CalendarDayTimelineEntry] {
        (
            nextActionItems.map(CalendarDayTimelineEntry.nextAction)
                + plans.map(CalendarDayTimelineEntry.plan)
                + visits.map(CalendarDayTimelineEntry.visit)
                + externalEvents.map(CalendarDayTimelineEntry.external)
        )
        .sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.sortPriority < $1.sortPriority
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(FavorecoDateText.fullDate(selectedDate))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("この日の流れ")
                        .font(FavorecoTypography.sectionTitle)
                }

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("この日のタイムラインを閉じる")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Rectangle()
                .fill(Color(.separator).opacity(0.55))
                .frame(height: 0.5)

            ScrollView(.vertical) {
                if entries.isEmpty {
                    PlaceholderRow(
                        icon: "calendar.badge.checkmark",
                        title: "予定・やることはありません",
                        message: "この日に予定や記録、期限が入ると時刻順に表示されます。"
                    )
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            timelineDestination(
                                for: entry,
                                isLast: index == entries.count - 1
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
            .contentMargins(.bottom, bottomClearance + 24, for: .scrollContent)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: -4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func timelineDestination(
        for entry: CalendarDayTimelineEntry,
        isLast: Bool
    ) -> some View {
        switch entry {
        case .nextAction(let item):
            NavigationLink {
                PlanDetailView(plan: item.plan)
            } label: {
                CalendarDayTimelineRow(entry: entry, isLast: isLast)
            }
            .buttonStyle(.plain)
        case .plan(let plan):
            NavigationLink {
                PlanDetailView(plan: plan)
            } label: {
                CalendarDayTimelineRow(entry: entry, isLast: isLast)
            }
            .buttonStyle(.plain)
        case .visit(let visit):
            NavigationLink {
                ExperienceDetailView(visit: visit)
            } label: {
                CalendarDayTimelineRow(entry: entry, isLast: isLast)
            }
            .buttonStyle(.plain)
        case .external:
            CalendarDayTimelineRow(entry: entry, isLast: isLast)
        }
    }
}

private struct CalendarDayTimelineRow: View {
    let entry: CalendarDayTimelineEntry
    let isLast: Bool

    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        switch entry {
        case .nextAction(let item):
            if let stage = item.ticketVisualStage {
                return TicketProgressColorPalette.color(for: stage)
            }
            return themePalette.categoryColor(hex: item.plan.category?.colorHex ?? "#147C88")
        case .plan(let plan):
            return themePalette.categoryColor(
                hex: plan.category?.colorHex ?? plan.event?.category?.colorHex ?? "#147C88"
            )
        case .visit(let visit):
            return themePalette.categoryColor(hex: visit.event?.category?.colorHex ?? "#147C88")
        case .external(let event):
            return Color(uiColor: event.color)
        }
    }

    private var iconName: String {
        switch entry {
        case .nextAction(let item): return item.systemImage
        case .plan(let plan): return plan.category?.iconSymbol ?? "calendar"
        case .visit(let visit): return visit.event?.category?.iconSymbol ?? "checkmark"
        case .external: return "calendar.badge.clock"
        }
    }

    private var kindLabel: String {
        switch entry {
        case .nextAction: return "やること"
        case .plan: return "予定"
        case .visit: return "記録"
        case .external: return "外部カレンダー"
        }
    }

    private var title: String {
        switch entry {
        case .nextAction(let item): return item.title
        case .plan(let plan): return nonEmpty(plan.title, fallback: "予定")
        case .visit(let visit): return nonEmpty(visit.event?.title ?? "", fallback: "記録")
        case .external(let event): return nonEmpty(event.title, fallback: "外部予定")
        }
    }

    private var detail: String {
        switch entry {
        case .nextAction(let item):
            return nonEmpty(item.plan.title, fallback: item.plan.event?.title ?? "予定")
        case .plan(let plan):
            return joinedDetail(
                timeRange(start: plan.startsAt, end: plan.endsAt),
                plan.venueNameSnapshot
            )
        case .visit(let visit):
            return joinedDetail(
                timeRange(start: visit.visitedAt, end: visit.endedAt),
                visit.venueNameSnapshot
            )
        case .external(let event):
            let time = event.isAllDay
                ? "終日"
                : timeRange(start: event.startDate, end: event.endDate)
            return joinedDetail(time, event.calendarTitle)
        }
    }

    private var timeLabel: String {
        switch entry {
        case .external(let event) where event.isAllDay:
            return "終日"
        default:
            return FavorecoDateText.time(entry.date)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeLabel)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
                .padding(.top, 5)

            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.65))
                        .frame(width: 1)
                        .padding(.top, 27)
                }

                Circle()
                    .fill(tint)
                    .frame(width: 27, height: 27)
                    .overlay {
                        FavorecoIcon(systemName: iconName, size: 13)
                            .foregroundStyle(.white)
                    }
            }
            .frame(width: 30)
            .frame(minHeight: 74)

            VStack(alignment: .leading, spacing: 3) {
                Text(kindLabel)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)

                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !detail.isEmpty {
                    Text(detail)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
            .padding(.bottom, 12)

            if isNavigable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var isNavigable: Bool {
        if case .external = entry { return false }
        return true
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let fallbackTrimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackTrimmed.isEmpty ? "予定" : fallbackTrimmed
    }

    private func joinedDetail(_ values: String...) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "・")
    }

    private func timeRange(start: Date, end: Date) -> String {
        guard end > start else { return FavorecoDateText.time(start) }
        return "\(FavorecoDateText.time(start))〜\(FavorecoDateText.time(end))"
    }
}

struct CalendarPlanOverviewSection: View {
    let ticketProgressItems: [CategoryTicketProgressItem]
    let nextActionItems: [CalendarNextActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
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

}
