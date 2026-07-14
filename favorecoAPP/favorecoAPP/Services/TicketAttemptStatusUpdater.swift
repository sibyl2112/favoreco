//
//  TicketAttemptStatusUpdater.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData

@MainActor
enum TicketAttemptStatusUpdater {
    private static let terminalStatusKeys: Set<String> = ["lost", "skipped", "attended"]

    static func update(
        attempt: TicketAttempt,
        to statusKey: String,
        in modelContext: ModelContext
    ) throws {
        guard attempt.statusKey != statusKey, let plan = attempt.plan else { return }

        let now = Date()
        attempt.statusKey = statusKey
        attempt.updatedAt = now

        if terminalStatusKeys.contains(statusKey) {
            attempt.notificationSettingsRaw = ""
            TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
        } else {
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
        }

        try modelContext.save()

        if !terminalStatusKeys.contains(statusKey) {
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }

    static func archive(
        attempt: TicketAttempt,
        in modelContext: ModelContext
    ) throws {
        guard !attempt.isArchived, let plan = attempt.plan else { return }

        let now = Date()
        attempt.isArchived = true
        attempt.updatedAt = now
        attempt.notificationSettingsRaw = ""

        try modelContext.save()
        TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
    }

    static func restore(
        attempt: TicketAttempt,
        in modelContext: ModelContext
    ) throws {
        guard attempt.isArchived,
              let plan = attempt.plan,
              !plan.isArchived else { return }

        let now = Date()
        attempt.isArchived = false
        attempt.updatedAt = now
        if terminalStatusKeys.contains(attempt.statusKey) {
            attempt.notificationSettingsRaw = ""
        } else {
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
        }

        try modelContext.save()

        if !terminalStatusKeys.contains(attempt.statusKey) {
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }
}
