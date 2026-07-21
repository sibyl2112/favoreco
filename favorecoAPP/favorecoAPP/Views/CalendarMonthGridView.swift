//
//  CalendarMonthGridView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import Foundation
import SwiftUI

struct CalendarMonthEntry: Identifiable {
    enum Kind: Equatable {
        case plan
        case visit
        case preparationTask
        case external
    }

    let id: String
    let title: String
    let colorHex: String
    let kind: Kind
}

struct CalendarMonthSnapshot {
    let entriesByDay: [Date: [CalendarMonthEntry]]

    static func make(
        days: [CalendarDay],
        visitsByDay: [Date: [Visit]],
        plansByDay: [Date: [Plan]],
        plans: [Plan],
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        showsExternalEvents: Bool,
        calendar: Calendar
    ) -> CalendarMonthSnapshot {
        var entriesByDay: [Date: [CalendarMonthEntry]] = [:]

        for day in days {
            let dayKey = calendar.startOfDay(for: day.date)
            let planEntries = (plansByDay[dayKey] ?? [])
                .sorted { $0.startsAt < $1.startsAt }
                .map { plan in
                    CalendarMonthEntry(
                        id: "plan-\(plan.id.uuidString)",
                        title: calendarTitle(plan.title, fallback: "予定"),
                        colorHex: plan.category?.colorHex ?? "#147C88",
                        kind: .plan
                    )
                }
            let visitEntries = (visitsByDay[dayKey] ?? [])
                .sorted { $0.visitedAt < $1.visitedAt }
                .map { visit in
                    CalendarMonthEntry(
                        id: "visit-\(visit.id.uuidString)",
                        title: calendarTitle(visit.event?.title ?? "", fallback: "記録"),
                        colorHex: visit.event?.category?.colorHex ?? "#147C88",
                        kind: .visit
                    )
                }
            let preparationEntries = plans
                .filter { !$0.isArchived && $0.isPreparationChecklistActive }
                .flatMap { plan in
                    plan.preparationFields.tasks.compactMap { task -> CalendarMonthEntry? in
                        guard !task.isCompleted,
                              !task.trimmedTitle.isEmpty,
                              let dueAt = task.dueAt,
                              calendar.isDate(dueAt, inSameDayAs: day.date) else {
                            return nil
                        }
                        return CalendarMonthEntry(
                            id: "preparation-\(plan.id.uuidString)-\(task.id.uuidString)",
                            title: task.trimmedTitle,
                            colorHex: plan.category?.colorHex ?? "#147C88",
                            kind: .preparationTask
                        )
                    }
                }
            let externalEntries = showsExternalEvents
                ? (externalEventsByDay[dayKey] ?? [])
                    .sorted { $0.startDate < $1.startDate }
                    .map { event in
                        CalendarMonthEntry(
                            id: "external-\(event.id)",
                            title: calendarTitle(event.title, fallback: "外部予定"),
                            colorHex: "#7A7F87",
                            kind: .external
                        )
                    }
                : []

            let entries = planEntries + visitEntries + preparationEntries + externalEntries
            if !entries.isEmpty {
                entriesByDay[dayKey] = entries
            }
        }

        return CalendarMonthSnapshot(entriesByDay: entriesByDay)
    }

    private static func calendarTitle(_ title: String, fallback: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct CalendarMonthGridView: View {
    let weekdaySymbols: [String]
    let days: [CalendarDay]
    let entriesByDay: [Date: [CalendarMonthEntry]]
    let selectedDate: Date
    let calendar: Calendar
    let onSelect: (CalendarDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(days) { day in
                    CalendarMonthDayCell(
                        day: day,
                        entries: entriesByDay[calendar.startOfDay(for: day.date)] ?? [],
                        isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(day.date),
                        calendar: calendar
                    ) {
                        onSelect(day)
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
        .accessibilityElement(children: .contain)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(weekdayColor(at: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.55))
                .frame(height: 0.5)
        }
    }

    private func weekdayColor(at index: Int) -> Color {
        guard weekdaySymbols.indices.contains(index) else { return .secondary }
        switch weekdaySymbols[index] {
        case "日": return .red.opacity(0.85)
        case "土": return .blue.opacity(0.85)
        default: return .secondary
        }
    }
}

private struct CalendarMonthDayCell: View {
    let day: CalendarDay
    let entries: [CalendarMonthEntry]
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let action: () -> Void

    @Environment(\.favorecoThemePalette) private var themePalette

    private let visibleEntryLimit = 3

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                dayNumber

                VStack(spacing: 2) {
                    ForEach(entries.prefix(visibleEntryLimit)) { entry in
                        entryLabel(entry)
                    }

                    if entries.count > visibleEntryLimit {
                        Text("ほか\(entries.count - visibleEntryLimit)件")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 3)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
            .background(isSelected ? Color.accentColor.opacity(0.055) : Color(.systemBackground))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.42))
                    .frame(width: 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.42))
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("選択してこの日の詳細を表示")
    }

    private var dayNumber: some View {
        Text(String(calendar.component(.day, from: day.date)))
            .font(.system(size: 12, weight: isSelected || isToday ? .semibold : .regular))
            .foregroundStyle(dayNumberColor)
            .frame(width: 25, height: 25)
            .background {
                if isSelected || isToday {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.blue)
                }
            }
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func entryLabel(_ entry: CalendarMonthEntry) -> some View {
        let tint = themePalette.categoryColor(hex: entry.colorHex)

        Text(entryTitle(entry))
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(entry.kind == .external ? Color.secondary : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
            .padding(.horizontal, 3)
            .background {
                if entry.kind == .external {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(
                                    Color.secondary.opacity(0.6),
                                    style: StrokeStyle(lineWidth: 0.75, dash: [2, 1.5])
                                )
                        }
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint.opacity(entry.kind == .visit ? 0.78 : 0.95))
                }
            }
    }

    private func entryTitle(_ entry: CalendarMonthEntry) -> String {
        switch entry.kind {
        case .visit: return "✓ \(entry.title)"
        case .preparationTask: return "□ \(entry.title)"
        case .plan, .external: return entry.title
        }
    }

    private var dayNumberColor: Color {
        if isSelected || isToday {
            return .white
        }
        return day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.45)
    }

    private var accessibilityLabel: String {
        let dateText = FavorecoDateText.fullDate(day.date)
        guard !entries.isEmpty else { return "\(dateText)、予定なし" }
        let titles = entries.prefix(visibleEntryLimit).map(\.title).joined(separator: "、")
        let remainder = max(entries.count - visibleEntryLimit, 0)
        return remainder > 0
            ? "\(dateText)、\(titles)、ほか\(remainder)件"
            : "\(dateText)、\(titles)"
    }
}
