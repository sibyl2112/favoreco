import Foundation
import SwiftData

@MainActor
enum TicketNotificationSettingsSyncService {
    static func synchronize(
        plans: [Plan],
        attempts: [TicketAttempt],
        in context: ModelContext
    ) async throws {
        var metadataChanged = false

        for attempt in attempts {
            let identifiers: [String]
            if attempt.isArchived || TicketStatusDefinition.isTerminal(attempt.statusKey) {
                identifiers = []
            } else if let plan = attempt.plan, !plan.isArchived {
                identifiers = TicketNotificationScheduler.scheduledAttemptIdentifiers(
                    plan: plan,
                    attempt: attempt
                )
            } else {
                identifiers = []
            }

            let rawValue = identifiers.joined(separator: ",")
            guard attempt.notificationSettingsRaw != rawValue else { continue }
            attempt.notificationSettingsRaw = rawValue
            metadataChanged = true
        }

        if metadataChanged {
            try context.save()
        }

        for plan in plans {
            if plan.isArchived {
                TicketNotificationScheduler.cancel(plan: plan, attempt: nil)
            } else {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: nil)
            }
        }

        for attempt in attempts {
            guard let plan = attempt.plan else { continue }
            if attempt.isArchived || plan.isArchived || TicketStatusDefinition.isTerminal(attempt.statusKey) {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            } else {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }
}
