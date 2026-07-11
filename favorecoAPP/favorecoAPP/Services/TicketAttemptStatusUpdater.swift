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
        plan.stateKey = statusKey
        plan.updatedAt = now

        if terminalStatusKeys.contains(statusKey) {
            TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
        }

        try modelContext.save()

        if !terminalStatusKeys.contains(statusKey) {
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }
}
