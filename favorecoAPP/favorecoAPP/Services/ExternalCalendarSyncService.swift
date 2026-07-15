import EventKit
import Foundation

enum ExternalCalendarSyncResult {
    case updated
    case eventNotFound
    case permissionDenied
}

enum ExternalCalendarSyncService {
    @MainActor
    static func update(plan: Plan) async throws -> ExternalCalendarSyncResult {
        let identifier = ExternalCalendarLinkStore.identifier(for: plan)
        guard !identifier.isEmpty else { return .eventNotFound }

        let store = EKEventStore()
        guard try await requestAccess(using: store) else { return .permissionDenied }
        guard let event = store.event(withIdentifier: identifier) else {
            ExternalCalendarLinkStore.clear(planID: plan.id)
            return .eventNotFound
        }

        apply(plan: plan, to: event)
        try store.save(event, span: .thisEvent, commit: true)
        return .updated
    }

    @MainActor
    static func remove(plan: Plan) async throws -> ExternalCalendarSyncResult {
        let identifier = ExternalCalendarLinkStore.identifier(for: plan)
        return try await remove(identifier: identifier, planID: plan.id)
    }

    @MainActor
    static func remove(identifier: String, planID: UUID) async throws -> ExternalCalendarSyncResult {
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return .eventNotFound }

        let store = EKEventStore()
        guard try await requestAccess(using: store) else { return .permissionDenied }
        guard let event = store.event(withIdentifier: identifier) else {
            ExternalCalendarLinkStore.clear(planID: planID)
            return .eventNotFound
        }
        try store.remove(event, span: .thisEvent, commit: true)
        ExternalCalendarLinkStore.clear(planID: planID)
        return .updated
    }

    @MainActor
    private static func requestAccess(using store: EKEventStore) async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return try await store.requestFullAccessToEvents()
        default:
            return false
        }
    }

    @MainActor
    private static func apply(plan: Plan, to event: EKEvent) {
        event.title = plan.title.isEmpty ? "予定" : plan.title
        let address = plan.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        event.location = address.isEmpty ? plan.venueNameSnapshot : address
        event.startDate = plan.calendarStartsAt
        event.endDate = plan.endsAt > plan.calendarStartsAt
            ? plan.endsAt
            : Calendar.current.date(byAdding: .hour, value: 2, to: plan.calendarStartsAt) ?? plan.calendarStartsAt
        event.notes = notes(for: plan)
    }

    @MainActor
    private static func notes(for plan: Plan) -> String {
        let attempt = (plan.ticketAttempts ?? []).filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }.first
        return [
            plan.subtitle,
            attempt.map { TicketStatusDefinition.name(for: $0.statusKey) } ?? "",
            attempt?.seatText ?? "",
            plan.memo,
            plan.officialURL,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

enum ExternalCalendarLinkStore {
    nonisolated private static let storageKey = "externalCalendarEventIdentifiersByPlan"

    @MainActor
    static func identifier(for plan: Plan) -> String {
        let key = plan.id.uuidString
        if let value = storedLinks()[key], !value.isEmpty {
            return value
        }

        let legacyValue = plan.externalCalendarEventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !legacyValue.isEmpty {
            set(identifier: legacyValue, planID: plan.id)
            plan.externalCalendarEventIdentifier = ""
        }
        return legacyValue
    }

    nonisolated static func set(identifier: String, planID: UUID) {
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var links = storedLinks()
        links[planID.uuidString] = value
        UserDefaults.standard.set(links, forKey: storageKey)
    }

    nonisolated static func clear(planID: UUID) {
        var links = storedLinks()
        links.removeValue(forKey: planID.uuidString)
        UserDefaults.standard.set(links, forKey: storageKey)
    }

    nonisolated static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    nonisolated static func hasLink(planID: UUID) -> Bool {
        !(storedLinks()[planID.uuidString] ?? "").isEmpty
    }

    nonisolated static func identifier(planID: UUID) -> String {
        storedLinks()[planID.uuidString] ?? ""
    }

    nonisolated private static func storedLinks() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}
