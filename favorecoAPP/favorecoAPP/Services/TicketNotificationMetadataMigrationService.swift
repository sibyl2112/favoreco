import Foundation
import SwiftData

@MainActor
enum TicketNotificationMetadataMigrationService {
    @discardableResult
    static func normalize(in context: ModelContext) throws -> Int {
        let attempts = try context.fetch(FetchDescriptor<TicketAttempt>())
        var changedCount = 0

        for attempt in attempts {
            let normalized = normalizedIdentifiers(for: attempt).joined(separator: ",")
            guard attempt.notificationSettingsRaw != normalized else { continue }
            attempt.notificationSettingsRaw = normalized
            changedCount += 1
        }

        if changedCount > 0 {
            try context.save()
        }
        return changedCount
    }

    private static func normalizedIdentifiers(for attempt: TicketAttempt) -> [String] {
        guard !attempt.isArchived,
              !TicketStatusDefinition.isTerminal(attempt.statusKey) else {
            return []
        }

        let ownPrefix = "ticket.\(attempt.id.uuidString)."
        var seen = Set<String>()
        return attempt.notificationSettingsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { identifier in
                identifier.hasPrefix(ownPrefix) && seen.insert(identifier).inserted
            }
    }
}
