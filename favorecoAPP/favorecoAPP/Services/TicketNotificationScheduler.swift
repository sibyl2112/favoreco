//
//  TicketNotificationScheduler.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import UserNotifications

enum TicketNotificationScheduler {
    static func scheduledAttemptIdentifiers(plan: Plan, attempt: TicketAttempt) -> [String] {
        guard UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMasterEnabled) else {
            return []
        }
        return notificationSpecs(plan: plan, attempt: attempt).map(\.identifier)
    }

    static func cancel(plan: Plan, attempt: TicketAttempt?) {
        cancel(planID: plan.id, attemptID: attempt?.id)
    }

    static func cancel(planID: UUID, attemptID: UUID?) {
        let center = UNUserNotificationCenter.current()
        let staleIdentifiers = staleIdentifierCandidates(planID: planID, attemptID: attemptID)
        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: staleIdentifiers)
    }

    static func reschedule(plan: Plan, attempt: TicketAttempt?) async {
        let center = UNUserNotificationCenter.current()
        let specs = notificationSpecs(plan: plan, attempt: attempt)
        let staleIdentifiers = staleIdentifierCandidates(planID: plan.id, attemptID: attempt?.id)

        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: staleIdentifiers)

        guard UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMasterEnabled) else {
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        for spec in specs {
            guard spec.fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: spec.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private static func notificationSpecs(plan: Plan, attempt: TicketAttempt?) -> [TicketNotificationSpec] {
        guard let attempt else {
            guard UserDefaults.standard.bool(
                forKey: AppStorageKeys.notificationPerformanceReminderEnabled
            ) else {
                return []
            }
            return performanceReminderSpecs(plan: plan)
        }

        var specs: [TicketNotificationSpec] = []
        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationApplicationStartEnabled),
           attempt.saleStartAt != Date.distantPast {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).applicationStart",
                    fireDate: attempt.saleStartAt,
                    title: "申込開始",
                    body: "\(planTitle(plan)) の申込が始まります。"
                )
            )
        }

        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationApplicationDeadlineEnabled),
           attempt.applyDeadlineAt != Date.distantPast {
            specs.append(contentsOf: deadlineSpecs(
                attemptID: attempt.id,
                typeKey: "applicationDeadline",
                date: attempt.applyDeadlineAt,
                title: "申込締切",
                body: "\(planTitle(plan)) の申込締切が近づいています。"
            ))
        }

        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationLotteryResultEnabled),
           attempt.resultAnnounceAt != Date.distantPast {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).lotteryResult",
                    fireDate: attempt.resultAnnounceAt,
                    title: "当落発表",
                    body: "\(planTitle(plan)) の当落発表日です。"
                )
            )
        }

        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationPaymentDeadlineEnabled),
           attempt.paymentDeadlineAt != Date.distantPast {
            specs.append(contentsOf: deadlineSpecs(
                attemptID: attempt.id,
                typeKey: "paymentDeadline",
                date: attempt.paymentDeadlineAt,
                title: "入金締切",
                body: "\(planTitle(plan)) の入金締切が近づいています。"
            ))
        }

        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationTicketIssueEnabled),
           attempt.issueStartAt != Date.distantPast {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).ticketIssue",
                    fireDate: attempt.issueStartAt,
                    title: "発券開始",
                    body: "\(planTitle(plan)) の発券開始日です。"
                )
            )
        }

        return specs
    }

    private static func performanceReminderSpecs(plan: Plan) -> [TicketNotificationSpec] {
        var specs: [TicketNotificationSpec] = []
        let calendar = Calendar.current

        if let previousDay = calendar.date(byAdding: .day, value: -1, to: plan.startsAt),
           let previousDayEvening = calendar.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: previousDay
           ) {
            specs.append(
                TicketNotificationSpec(
                    identifier: "plan.\(plan.id.uuidString).performance.previousDay",
                    fireDate: previousDayEvening,
                    title: "明日の予定",
                    body: "\(planTitle(plan)) は明日です。"
                )
            )
        }

        if let dayMorning = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: plan.startsAt
        ) {
            specs.append(
                TicketNotificationSpec(
                    identifier: "plan.\(plan.id.uuidString).performance.sameDay",
                    fireDate: dayMorning,
                    title: "今日の予定",
                    body: "\(planTitle(plan)) は今日です。"
                )
            )
        }

        return specs
    }

    private static func deadlineSpecs(
        attemptID: UUID,
        typeKey: String,
        date: Date,
        title: String,
        body: String
    ) -> [TicketNotificationSpec] {
        var specs: [TicketNotificationSpec] = []
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date) {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attemptID.uuidString).\(typeKey).dayBefore",
                    fireDate: dayBefore,
                    title: title,
                    body: body
                )
            )
        }
        if let hourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: date) {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attemptID.uuidString).\(typeKey).hourBefore",
                    fireDate: hourBefore,
                    title: title,
                    body: body
                )
            )
        }
        return specs
    }

    private static func staleIdentifierCandidates(planID: UUID, attemptID: UUID?) -> [String] {
        if let attemptID {
            let prefix = "ticket.\(attemptID.uuidString)"
            return [
                "\(prefix).applicationStart",
                "\(prefix).applicationDeadline.dayBefore",
                "\(prefix).applicationDeadline.hourBefore",
                "\(prefix).lotteryResult",
                "\(prefix).paymentDeadline.dayBefore",
                "\(prefix).paymentDeadline.hourBefore",
                "\(prefix).ticketIssue",
            ]
        }

        return [
            "plan.\(planID.uuidString).performance.previousDay",
            "plan.\(planID.uuidString).performance.sameDay",
        ]
    }

    private static func planTitle(_ plan: Plan) -> String {
        plan.title.isEmpty ? "予定" : plan.title
    }
}

private struct TicketNotificationSpec {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}
