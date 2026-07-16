//
//  FavorecoDateText.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/16.
//

import Foundation

enum FavorecoDateText {
    static func fullDate(_ date: Date, includesWeekday: Bool = true) -> String {
        let values = components(for: date)
        let base = "\(values.year)年\(values.month)月\(values.day)日"
        return includesWeekday ? "\(base)（\(values.weekday)）" : base
    }

    static func fullDateTime(_ date: Date, includesWeekday: Bool = true) -> String {
        "\(fullDate(date, includesWeekday: includesWeekday)) \(time(date))"
    }

    static func compactDateTime(_ date: Date) -> String {
        let values = components(for: date)
        return "\(values.month)/\(values.day)（\(values.weekday)） \(time(date))"
    }

    static func compactDate(_ date: Date) -> String {
        let values = components(for: date)
        return "\(values.month)/\(values.day)（\(values.weekday)）"
    }

    static func month(_ date: Date) -> String {
        "\(components(for: date).month)月"
    }

    static func time(_ date: Date) -> String {
        let values = components(for: date)
        return String(format: "%02d:%02d", values.hour, values.minute)
    }

    static func range(from startDate: Date, to endDate: Date) -> String {
        if displayCalendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(fullDateTime(startDate))〜\(time(endDate))"
        }
        return "\(fullDateTime(startDate))〜\(fullDateTime(endDate))"
    }

    private static func components(for date: Date) -> DateComponentsText {
        let components = displayCalendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute],
            from: date
        )
        let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
        let weekdayIndex = max(0, min((components.weekday ?? 1) - 1, weekdayNames.count - 1))
        return DateComponentsText(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            weekday: weekdayNames[weekdayIndex],
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }

    private static var displayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}

private struct DateComponentsText {
    let year: Int
    let month: Int
    let day: Int
    let weekday: String
    let hour: Int
    let minute: Int
}
