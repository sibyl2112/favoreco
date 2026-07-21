//
//  CalendarTimelineView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import Foundation
import SwiftUI

struct CalendarTimelineEntry: Identifiable {
    enum Kind: Equatable {
        case plan
        case visit
        case ticketAction
        case preparationTask
        case external
    }

    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let colorHex: String
    let kind: Kind
    let isAllDay: Bool
}

struct CalendarTimelineSnapshot {
    let entries: [CalendarTimelineEntry]

    static func make(
        visits: [Visit],
        plans: [Plan],
        externalEvents: [ExternalCalendarEvent],
        showsExternalEvents: Bool,
        calendar: Calendar,
        now: Date = Date()
    ) -> CalendarTimelineSnapshot {
        let planEntries = plans
            .filter { !$0.isArchived }
            .map { plan in
                CalendarTimelineEntry(
                    id: "plan-\(plan.id.uuidString)",
                    title: title(plan.title, fallback: "予定"),
                    startDate: plan.startsAt,
                    endDate: validEndDate(plan.endsAt, after: plan.startsAt),
                    colorHex: plan.category?.colorHex ?? plan.event?.category?.colorHex ?? "#147C88",
                    kind: .plan,
                    isAllDay: isAllDay(start: plan.startsAt, end: plan.endsAt, calendar: calendar)
                )
            }

        let visitEntries = visits
            .filter { $0.event?.isArchived != true }
            .map { visit in
                CalendarTimelineEntry(
                    id: "visit-\(visit.id.uuidString)",
                    title: title(visit.event?.title ?? "", fallback: "記録"),
                    startDate: visit.visitedAt,
                    endDate: validEndDate(visit.endedAt, after: visit.visitedAt),
                    colorHex: visit.event?.category?.colorHex ?? "#147C88",
                    kind: .visit,
                    isAllDay: isAllDay(start: visit.visitedAt, end: visit.endedAt, calendar: calendar)
                )
            }

        let ticketEntries = plans
            .filter { !$0.isArchived }
            .flatMap { plan in
                (plan.ticketAttempts ?? []).compactMap { attempt -> CalendarTimelineEntry? in
                    guard !attempt.isArchived,
                          let action = TicketNextActionDefinition.nextAction(for: attempt, now: now) else {
                        return nil
                    }
                    return CalendarTimelineEntry(
                        id: "ticket-action-\(attempt.id.uuidString)-\(action.title)-\(action.date.timeIntervalSinceReferenceDate)",
                        title: action.title,
                        startDate: action.date,
                        endDate: validEndDate(
                            calendar.date(byAdding: .minute, value: 45, to: action.date) ?? action.date,
                            after: action.date
                        ),
                        colorHex: action.isOverdue ? "#C62828" : (plan.category?.colorHex ?? "#147C88"),
                        kind: .ticketAction,
                        isAllDay: false
                    )
                }
            }

        let preparationEntries = plans
            .filter { !$0.isArchived && $0.isPreparationChecklistActive }
            .flatMap { plan in
                plan.preparationFields.tasks.compactMap { task -> CalendarTimelineEntry? in
                    guard !task.isCompleted,
                          !task.trimmedTitle.isEmpty,
                          let dueAt = task.dueAt else {
                        return nil
                    }
                    return CalendarTimelineEntry(
                        id: "preparation-\(plan.id.uuidString)-\(task.id.uuidString)",
                        title: task.trimmedTitle,
                        startDate: dueAt,
                        endDate: validEndDate(
                            calendar.date(byAdding: .minute, value: 45, to: dueAt) ?? dueAt,
                            after: dueAt
                        ),
                        colorHex: plan.category?.colorHex ?? "#147C88",
                        kind: .preparationTask,
                        isAllDay: false
                    )
                }
            }

        let externalEntries = showsExternalEvents
            ? externalEvents.map { event in
                CalendarTimelineEntry(
                    id: "external-\(event.id)",
                    title: title(event.title, fallback: "外部予定"),
                    startDate: event.startDate,
                    endDate: validEndDate(event.endDate, after: event.startDate),
                    colorHex: "#7A7F87",
                    kind: .external,
                    isAllDay: event.isAllDay
                )
            }
            : []

        let entries = (planEntries + visitEntries + ticketEntries + preparationEntries + externalEntries)
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        return CalendarTimelineSnapshot(entries: entries)
    }

    func entries(overlapping interval: DateInterval, allDay: Bool? = nil) -> [CalendarTimelineEntry] {
        entries.filter { entry in
            let overlaps = entry.startDate < interval.end && entry.endDate > interval.start
            guard overlaps else { return false }
            guard let allDay else { return true }
            return entry.isAllDay == allDay
        }
    }

    private static func title(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func validEndDate(_ endDate: Date, after startDate: Date) -> Date {
        guard endDate > startDate else {
            return Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        }
        return endDate
    }

    private static func isAllDay(start: Date, end: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: start)
        let startsAtMidnight = components.hour == 0 && components.minute == 0
        return startsAtMidnight && end.timeIntervalSince(start) >= 23 * 60 * 60
    }
}

struct CalendarWeekTimelineView: View {
    let weekDays: [Date]
    let snapshot: CalendarTimelineSnapshot
    let selectedDate: Date
    let calendar: Calendar
    let onSelectDate: (Date) -> Void

    private let hourHeight: CGFloat = 60
    private let timeLabelWidth: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
            allDayRow

            HStack(alignment: .top, spacing: 0) {
                CalendarTimelineHourLabels(hourHeight: hourHeight)
                    .frame(width: timeLabelWidth)

                ForEach(weekDays, id: \.self) { day in
                    CalendarTimelineDayColumn(
                        day: day,
                        entries: timedEntries(on: day),
                        calendar: calendar,
                        hourHeight: hourHeight,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate)
                    ) {
                        onSelectDate(day)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay {
            Rectangle()
                .stroke(Color(.separator).opacity(0.55), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeLabelWidth, height: 48)

            ForEach(weekDays, id: \.self) { day in
                Button {
                    onSelectDate(day)
                } label: {
                    VStack(spacing: 2) {
                        Text(FavorecoDateText.weekdayName(day).replacingOccurrences(of: "曜", with: ""))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(String(calendar.component(.day, from: day)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.white : Color.primary)
                            .frame(width: 24, height: 24)
                            .background {
                                if calendar.isDate(day, inSameDayAs: selectedDate) || calendar.isDateInToday(day) {
                                    Circle().fill(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor : Color.blue)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(.separator).opacity(0.5)).frame(height: 0.5)
        }
    }

    private var allDayRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("終日")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: timeLabelWidth, height: 42, alignment: .top)
                .padding(.top, 5)

            ForEach(weekDays, id: \.self) { day in
                let entries = allDayEntries(on: day)
                VStack(spacing: 2) {
                    ForEach(entries.prefix(2)) { entry in
                        CalendarTimelineCompactLabel(entry: entry)
                    }
                    if entries.count > 2 {
                        Text("+\(entries.count - 2)")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(2)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .top)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color(.separator).opacity(0.35)).frame(width: 0.5)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(.separator).opacity(0.55)).frame(height: 0.5)
        }
    }

    private func dayInterval(_ day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        return DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start) ?? start
        )
    }

    private func allDayEntries(on day: Date) -> [CalendarTimelineEntry] {
        snapshot.entries(overlapping: dayInterval(day), allDay: true)
    }

    private func timedEntries(on day: Date) -> [CalendarTimelineEntry] {
        snapshot.entries(overlapping: dayInterval(day), allDay: false)
    }
}

struct CalendarDayTimelineView: View {
    let date: Date
    let snapshot: CalendarTimelineSnapshot
    let calendar: Calendar

    private let hourHeight: CGFloat = 60
    private let timeLabelWidth: CGFloat = 42

    private var interval: DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start) ?? start
        )
    }

    private var timedEntries: [CalendarTimelineEntry] {
        snapshot.entries(overlapping: interval, allDay: false)
    }

    private var allDayEntries: [CalendarTimelineEntry] {
        snapshot.entries(overlapping: interval, allDay: true)
    }

    var body: some View {
        GeometryReader { proxy in
            let allDayWidth = allDayEntries.isEmpty ? 0 : max(76, proxy.size.width * 0.25)
            let timedWidth = max(proxy.size.width - allDayWidth, 0)

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 36)

                    HStack(alignment: .top, spacing: 0) {
                        CalendarTimelineHourLabels(hourHeight: hourHeight)
                            .frame(width: timeLabelWidth)
                        CalendarTimelineDayColumn(
                            day: date,
                            entries: timedEntries,
                            calendar: calendar,
                            hourHeight: hourHeight,
                            isSelected: true,
                            action: {}
                        )
                    }
                }
                .frame(width: timedWidth)

                if !allDayEntries.isEmpty {
                    CalendarVerticalAllDayColumn(
                        entries: allDayEntries,
                        totalHeight: hourHeight * 24
                    )
                    .frame(width: allDayWidth)
                }
            }
        }
        .frame(height: hourHeight * 24 + 36)
        .background(Color(.systemBackground))
        .overlay {
            Rectangle()
                .stroke(Color(.separator).opacity(0.55), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }
}

private struct CalendarTimelineHourLabels: View {
    let hourHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%d:00", hour))
                    .font(.system(size: 8.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .offset(y: CGFloat(hour) * hourHeight - 5)
            }
        }
        .frame(height: hourHeight * 24, alignment: .topTrailing)
        .padding(.trailing, 4)
    }
}

private struct CalendarTimelineDayColumn: View {
    let day: Date
    let entries: [CalendarTimelineEntry]
    let calendar: Calendar
    let hourHeight: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Color(isSelected ? .secondarySystemBackground : .systemBackground)
                    .opacity(isSelected ? 0.28 : 1)

                ForEach(0...24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color(.separator).opacity(hour.isMultiple(of: 2) ? 0.42 : 0.22))
                        .frame(height: 0.5)
                        .offset(y: CGFloat(hour) * hourHeight)
                }

                ForEach(entries) { entry in
                    CalendarTimelineEventBlock(entry: entry)
                        .padding(.horizontal, 2)
                        .offset(y: yOffset(for: entry))
                        .frame(height: eventHeight(for: entry), alignment: .top)
                }

                if calendar.isDateInToday(day) {
                    CalendarCurrentTimeLine()
                        .offset(y: yOffset(for: Date()))
                }
            }
            .frame(maxWidth: .infinity, minHeight: hourHeight * 24, maxHeight: hourHeight * 24)
            .clipped()
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color(.separator).opacity(0.4)).frame(width: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func yOffset(for date: Date) -> CGFloat {
        let start = calendar.startOfDay(for: day)
        let clippedDate = min(max(date, start), calendar.date(byAdding: .day, value: 1, to: start) ?? date)
        return CGFloat(clippedDate.timeIntervalSince(start) / 3600) * hourHeight
    }

    private func yOffset(for entry: CalendarTimelineEntry) -> CGFloat {
        yOffset(for: entry.startDate)
    }

    private func eventHeight(for entry: CalendarTimelineEntry) -> CGFloat {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? entry.endDate
        let start = max(entry.startDate, dayStart)
        let end = min(entry.endDate, dayEnd)
        let durationHeight = CGFloat(max(end.timeIntervalSince(start), 0) / 3600) * hourHeight
        return max(durationHeight, 18)
    }
}

private struct CalendarTimelineEventBlock: View {
    let entry: CalendarTimelineEntry
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        let tint = themePalette.categoryColor(hex: entry.colorHex)
        Text(label)
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(entry.kind == .external ? Color.secondary : Color.white)
            .lineLimit(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(entry.kind == .external ? Color(.secondarySystemBackground) : tint.opacity(0.92))
                    .overlay {
                        if entry.kind == .external {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 0.75, dash: [2, 1.5]))
                        }
                    }
            }
            .accessibilityLabel("\(FavorecoDateText.time(entry.startDate))、\(entry.title)")
    }

    private var label: String {
        switch entry.kind {
        case .visit: return "✓ \(entry.title)"
        case .external: return entry.title
        case .plan, .ticketAction: return "\(FavorecoDateText.time(entry.startDate)) \(entry.title)"
        case .preparationTask: return "□ \(entry.title)"
        }
    }
}

private struct CalendarTimelineCompactLabel: View {
    let entry: CalendarTimelineEntry
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        let tint = themePalette.categoryColor(hex: entry.colorHex)
        Text(entry.title)
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(entry.kind == .external ? Color.secondary : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 14)
            .background(
                entry.kind == .external ? Color(.secondarySystemBackground) : tint.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 2, style: .continuous)
            )
    }
}

private struct CalendarVerticalAllDayColumn: View {
    let entries: [CalendarTimelineEntry]
    let totalHeight: CGFloat
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        VStack(spacing: 0) {
            Text("終日")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color(.secondarySystemBackground))

            if entries.isEmpty {
                Color(.secondarySystemBackground)
                    .opacity(0.42)
                    .frame(height: totalHeight)
            } else {
                HStack(spacing: 2) {
                    ForEach(entries.prefix(3)) { entry in
                        let tint = themePalette.categoryColor(hex: entry.colorHex)
                        Text(entry.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(entry.kind == .external ? tint : Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.horizontal, 3)
                            .padding(.top, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(entry.kind == .external ? tint.opacity(0.11) : tint.opacity(0.78))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(tint.opacity(0.55), lineWidth: 1)
                                    }
                            }
                    }
                }
                .padding(4)
                .frame(height: totalHeight)
                .background(Color(.secondarySystemBackground).opacity(0.42))
                .overlay(alignment: .bottom) {
                    if entries.count > 3 {
                        Text("ほか\(entries.count - 3)件")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(.separator).opacity(0.65)).frame(width: 1)
        }
    }
}

private struct CalendarCurrentTimeLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 5, height: 5)
            Rectangle().fill(Color.red).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}
