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
    static func update(
        attempt: TicketAttempt,
        to statusKey: String,
        in modelContext: ModelContext
    ) throws {
        guard attempt.statusKey != statusKey, let plan = attempt.plan else { return }

        let previousStatusKey = attempt.statusKey
        let now = Date()
        attempt.statusKey = statusKey
        attempt.updatedAt = now
        if statusKey == "waitingIssue", attempt.paidAt == Date.distantPast {
            attempt.paidAt = now
        }
        if statusKey == "issued" {
            if previousStatusKey != "waitingIssue", attempt.paidAt == Date.distantPast {
                attempt.paidAt = now
            }
            if attempt.issuedAt == Date.distantPast {
                attempt.issuedAt = now
            }
        }

        let isTerminal = TicketStatusDefinition.isTerminal(statusKey)
        if isTerminal {
            attempt.notificationSettingsRaw = ""
        } else {
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledAttemptIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        if isTerminal {
            TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
        } else {
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }

    static func moveBackOneStage(
        attempt: TicketAttempt,
        in modelContext: ModelContext
    ) throws {
        guard let previousStatusKey = TicketStatusTransitionDefinition.previousStatusKey(for: attempt) else {
            return
        }

        switch previousStatusKey {
        case "beforeApply", "onSaleSoon", "waitingResult", "won", "waitingPayment":
            attempt.paidAt = .distantPast
            attempt.issuedAt = .distantPast
        case "waitingIssue":
            attempt.issuedAt = .distantPast
        default:
            break
        }

        try update(attempt: attempt, to: previousStatusKey, in: modelContext)
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

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
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
        if TicketStatusDefinition.isTerminal(attempt.statusKey) {
            attempt.notificationSettingsRaw = ""
        } else {
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledAttemptIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        if !TicketStatusDefinition.isTerminal(attempt.statusKey) {
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }
}
