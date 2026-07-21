//
//  ExternalCalendarOverlayService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import EventKit
import Combine
import Foundation
import UIKit

struct ExternalCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let calendarTitle: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let color: UIColor

    var dayKey: Date {
        Calendar.current.startOfDay(for: startDate)
    }
}

struct ExternalCalendarSource: Identifiable {
    let id: String
    let title: String
    let accountTitle: String
    let color: UIColor
}

enum ExternalCalendarSelection {
    static func identifiers(from rawValue: String) -> Set<String>? {
        guard !rawValue.isEmpty else { return nil }
        guard let data = rawValue.data(using: .utf8),
              let identifiers = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return Set(identifiers)
    }

    static func rawValue(for identifiers: Set<String>) -> String {
        let values = identifiers.sorted()
        guard let data = try? JSONEncoder().encode(values),
              let rawValue = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return rawValue
    }
}

@MainActor
final class ExternalCalendarOverlayStore: ObservableObject {
    @Published private(set) var events: [ExternalCalendarEvent] = []
    @Published private(set) var calendarSources: [ExternalCalendarSource] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var authorizationStatusText = "未確認"

    private let eventStore = EKEventStore()

    var canReadEvents: Bool {
        Self.canReadEvents(status: EKEventStore.authorizationStatus(for: .event))
    }

    func refresh(interval: DateInterval, selectedCalendarIDs: Set<String>? = nil) async {
        updateAuthorizationStatus()
        guard canReadEvents else {
            events = []
            calendarSources = []
            return
        }

        reloadCalendarSources()

        let calendars: [EKCalendar]?
        if let selectedCalendarIDs {
            guard !selectedCalendarIDs.isEmpty else {
                events = []
                return
            }
            let selectedCalendars = eventStore.calendars(for: .event).filter {
                selectedCalendarIDs.contains($0.calendarIdentifier)
            }
            guard !selectedCalendars.isEmpty else {
                events = []
                return
            }
            calendars = selectedCalendars
        } else {
            calendars = nil
        }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: calendars
        )
        events = eventStore.events(matching: predicate)
            .filter { !$0.isDetached }
            .map(Self.makeExternalEvent)
            .sorted { $0.startDate < $1.startDate }
    }

    func requestAccessAndRefresh(
        interval: DateInterval,
        selectedCalendarIDs: Set<String>? = nil
    ) async {
        let granted = await requestCalendarAccess()
        updateAuthorizationStatus()
        if granted {
            await refresh(interval: interval, selectedCalendarIDs: selectedCalendarIDs)
        }
    }

    func requestAccessAndLoadSources() async {
        let granted = await requestCalendarAccess()
        updateAuthorizationStatus()
        if granted {
            reloadCalendarSources()
        }
    }

    func reloadCalendarSources() {
        guard canReadEvents else {
            calendarSources = []
            return
        }
        calendarSources = eventStore.calendars(for: .event)
            .map { calendar in
                ExternalCalendarSource(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    accountTitle: calendar.source?.title ?? "この端末",
                    color: calendar.cgColor.map(UIColor.init(cgColor:)) ?? .systemGray
                )
            }
            .sorted {
                if $0.accountTitle != $1.accountTitle {
                    return $0.accountTitle.localizedStandardCompare($1.accountTitle) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    func updateAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatusText = Self.statusText(for: status)
    }

    private func requestCalendarAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    Task { @MainActor in
                        if let error {
                            self.errorMessage = "カレンダー権限の取得に失敗しました: \(error.localizedDescription)"
                        }
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        if let error {
                            self.errorMessage = "カレンダー権限の取得に失敗しました: \(error.localizedDescription)"
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private static func makeExternalEvent(from event: EKEvent) -> ExternalCalendarEvent {
        let calendarColor = event.calendar?.cgColor.map(UIColor.init(cgColor:)) ?? UIColor.systemGray
        return ExternalCalendarEvent(
            id: event.eventIdentifier ?? "\(event.title ?? "")-\(event.startDate.timeIntervalSince1970)",
            title: event.title?.isEmpty == false ? event.title : "予定",
            calendarTitle: event.calendar?.title ?? "外部カレンダー",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            color: calendarColor
        )
    }

    private static func canReadEvents(status: EKAuthorizationStatus) -> Bool {
        if #unavailable(iOS 17.0) {
            return status == .authorized
        }
        return status == .fullAccess
    }

    private static func statusText(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未許可"
        case .restricted:
            return "制限中"
        case .denied:
            return "拒否"
        case .authorized:
            return "許可済み"
        case .writeOnly:
            return "書き込みのみ"
        case .fullAccess:
            return "読み取り許可済み"
        @unknown default:
            return "不明"
        }
    }
}
