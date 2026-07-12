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
        event.calendar = store.defaultCalendarForNewEvents

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
