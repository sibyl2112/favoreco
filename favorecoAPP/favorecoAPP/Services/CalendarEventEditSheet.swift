//
//  CalendarEventEditSheet.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import EventKit
import EventKitUI
import SwiftUI

struct CalendarEventDraft: Identifiable {
    let id = UUID()
    var title: String
    var location: String
    var notes: String
    var startDate: Date
    var endDate: Date
    var preferredCalendarIdentifier: String?

    init(
        title: String,
        location: String,
        notes: String,
        startDate: Date,
        endDate: Date,
        preferredCalendarIdentifier: String? = nil
    ) {
        self.title = title
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.preferredCalendarIdentifier = preferredCalendarIdentifier
    }
}

enum ExternalCalendarDestinationError: LocalizedError {
    case accessDenied
    case appleCalendarNotConfigured
    case googleCalendarNotConfigured

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "カレンダーへのアクセスを許可してください。"
        case .appleCalendarNotConfigured:
            "iPhoneの設定でAppleカレンダーを利用できるようにしてください。"
        case .googleCalendarNotConfigured:
            "iPhoneの設定でGoogleアカウントのカレンダーを追加してください。"
        }
    }
}

@MainActor
enum ExternalCalendarDestinationResolver {
    static func appleCalendarIdentifier() async throws -> String {
        try await calendarIdentifier(
            matching: isAppleCalendar,
            missingError: .appleCalendarNotConfigured
        )
    }

    static func googleCalendarIdentifier() async throws -> String {
        try await calendarIdentifier(
            matching: isGoogleCalendar,
            missingError: .googleCalendarNotConfigured
        )
    }

    private static func calendarIdentifier(
        matching providerMatches: (EKCalendar) -> Bool,
        missingError: ExternalCalendarDestinationError
    ) async throws -> String {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        let hasAccess: Bool

        switch status {
        case .fullAccess:
            hasAccess = true
        case .notDetermined:
            hasAccess = try await store.requestFullAccessToEvents()
        default:
            hasAccess = false
        }

        guard hasAccess else {
            throw ExternalCalendarDestinationError.accessDenied
        }

        let writableCalendars = store.calendars(for: .event)
            .filter { $0.allowsContentModifications && providerMatches($0) }

        if let defaultCalendar = store.defaultCalendarForNewEvents,
           writableCalendars.contains(where: {
               $0.calendarIdentifier == defaultCalendar.calendarIdentifier
           }) {
            return defaultCalendar.calendarIdentifier
        }

        guard let calendar = writableCalendars.sorted(by: {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }).first else {
            throw missingError
        }
        return calendar.calendarIdentifier
    }

    private static func isAppleCalendar(_ calendar: EKCalendar) -> Bool {
        if calendar.source.sourceType == .local {
            return true
        }
        let providerText = providerText(for: calendar)
        return providerText.contains("icloud")
            || providerText.contains("apple")
            || providerText.contains("mobileme")
    }

    private static func isGoogleCalendar(_ calendar: EKCalendar) -> Bool {
        let text = providerText(for: calendar)
        return text.contains("google") || text.contains("gmail")
    }

    private static func providerText(for calendar: EKCalendar) -> String {
        [
            calendar.source.title,
            calendar.source.sourceIdentifier,
            calendar.title,
        ]
        .joined(separator: " ")
        .lowercased()
    }
}

struct CalendarEventEditSheet: UIViewControllerRepresentable {
    let draft: CalendarEventDraft
    var onSave: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onSave: onSave)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.location = draft.location
        event.notes = draft.notes
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.calendar = draft.preferredCalendarIdentifier
            .flatMap { store.calendar(withIdentifier: $0) }
            ?? store.defaultCalendarForNewEvents

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onSave: ((String) -> Void)?

        init(onSave: ((String) -> Void)?) {
            self.onSave = onSave
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            if action == .saved, let identifier = controller.event?.eventIdentifier, !identifier.isEmpty {
                onSave?(identifier)
            }
            controller.dismiss(animated: true)
        }
    }
}
