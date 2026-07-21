//
//  TicketNotificationScheduler.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import UserNotifications

enum TicketPointNotificationTiming: String, CaseIterable, Identifiable {
    case atTime
    case oneHourBefore
    case previousDayEvening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .atTime: "設定時刻どおり"
        case .oneHourBefore: "1時間前"
        case .previousDayEvening: "前日20時"
        }
    }
}

enum TicketDeadlineNotificationTiming: String, CaseIterable, Identifiable {
    case dayBeforeAndHourBefore
    case dayBefore
    case hourBefore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dayBeforeAndHourBefore: "前日＋1時間前"
        case .dayBefore: "前日のみ"
        case .hourBefore: "1時間前のみ"
        }
    }
}

enum PerformanceNotificationTiming: String, CaseIterable, Identifiable {
    case previousDayAndSameDay
    case previousDay
    case sameDay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previousDayAndSameDay: "前日20時＋当日9時"
        case .previousDay: "前日20時のみ"
        case .sameDay: "当日9時のみ"
        }
    }
}

enum PreparationNotificationTiming: String, CaseIterable, Identifiable {
    case previousDayEvening
    case oneHourBefore
    case atTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previousDayEvening: "前日20時"
        case .oneHourBefore: "1時間前"
        case .atTime: "期限時刻どおり"
        }
    }
}

enum TicketNotificationScheduler {
    static let destinationPlanIDKey = "favorecoPlanID"
    static let destinationPreparationTaskIDKey = "favorecoPreparationTaskID"

    static func scheduledAttemptIdentifiers(plan: Plan, attempt: TicketAttempt) -> [String] {
        guard UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMasterEnabled) else {
            return []
        }
        return notificationSpecs(plan: plan, attempt: attempt).map(\.identifier)
    }

    static func cancel(plan: Plan, attempt: TicketAttempt?) {
        cancel(planID: plan.id, attemptID: attempt?.id)
        Task {
            await reschedulePreparation(plan: plan)
        }
    }

    static func cancel(planID: UUID, attemptID: UUID?) {
        let center = UNUserNotificationCenter.current()
        let staleIdentifiers = staleIdentifierCandidates(planID: planID, attemptID: attemptID)
        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: staleIdentifiers)
    }

    static func cancel(attemptID: UUID) {
        let center = UNUserNotificationCenter.current()
        let staleIdentifiers = staleAttemptIdentifierCandidates(attemptID: attemptID)
        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: staleIdentifiers)
    }

    static func reschedule(plan: Plan, attempt: TicketAttempt?) async {
        let center = UNUserNotificationCenter.current()
        await reschedulePreparation(plan: plan, center: center)
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
            content.userInfo = [destinationPlanIDKey: plan.id.uuidString]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: spec.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func reschedulePreparation(plan: Plan) async {
        await reschedulePreparation(plan: plan, center: UNUserNotificationCenter.current())
    }

    private static func reschedulePreparation(
        plan: Plan,
        center: UNUserNotificationCenter
    ) async {
        let identifierPrefix = preparationIdentifierPrefix(planID: plan.id)
        let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)

        let deliveredIdentifiers = await center.deliveredNotifications()
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)

        guard UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMasterEnabled),
              notificationPreference(
                forKey: AppStorageKeys.notificationPreparationDeadlineEnabled,
                defaultValue: true
              ),
              !plan.isArchived,
              plan.isPreparationChecklistActive else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        for spec in preparationNotificationSpecs(plan: plan) where spec.fireDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            content.userInfo = [
                destinationPlanIDKey: plan.id.uuidString,
                destinationPreparationTaskIDKey: preparationTaskID(from: spec.identifier)?.uuidString ?? "",
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: spec.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private static func preparationNotificationSpecs(plan: Plan) -> [TicketNotificationSpec] {
        let calendar = Calendar.current
        return plan.preparationFields.tasks.compactMap { task in
            guard !task.isCompleted,
                  let dueAt = task.dueAt,
                  dueAt > Date(),
                  let fireDate = preparationFireDate(dueAt: dueAt, calendar: calendar) else { return nil }

            let taskTitle = task.trimmedTitle.isEmpty ? "公演の準備" : task.trimmedTitle
            return TicketNotificationSpec(
                identifier: "\(preparationIdentifierPrefix(planID: plan.id))\(task.id.uuidString).reminder",
                fireDate: fireDate,
                title: "準備期限：\(taskTitle)",
                body: "\(planTitle(plan)) の準備期限が近づいています。"
            )
        }
    }

    private static func preparationIdentifierPrefix(planID: UUID) -> String {
        "plan.\(planID.uuidString).preparation."
    }

    private static func preparationTaskID(from identifier: String) -> UUID? {
        let parts = identifier.split(separator: ".")
        guard parts.count >= 5,
              parts[0] == "plan",
              parts[2] == "preparation" else { return nil }
        return UUID(uuidString: String(parts[3]))
    }

    private static func notificationSpecs(plan: Plan, attempt: TicketAttempt?) -> [TicketNotificationSpec] {
        guard let attempt else {
            guard notificationPreference(
                forKey: AppStorageKeys.notificationPerformanceReminderEnabled,
                defaultValue: true
            ) else {
                return []
            }
            return performanceReminderSpecs(plan: plan)
        }

        var specs: [TicketNotificationSpec] = []
        if UserDefaults.standard.bool(forKey: AppStorageKeys.notificationApplicationStartEnabled),
           attempt.saleStartAt != Date.distantPast {
            let timing = pointTiming(forKey: AppStorageKeys.notificationApplicationStartTiming)
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).applicationStart",
                    fireDate: pointFireDate(date: attempt.saleStartAt, timing: timing),
                    title: "申込開始",
                    body: "\(planTitle(plan)) の申込が始まります。"
                )
            )
        }

        if notificationPreference(
            forKey: AppStorageKeys.notificationApplicationDeadlineEnabled,
            defaultValue: true
        ),
           attempt.applyDeadlineAt != Date.distantPast {
            specs.append(contentsOf: deadlineSpecs(
                attemptID: attempt.id,
                typeKey: "applicationDeadline",
                date: attempt.applyDeadlineAt,
                title: "申込締切",
                body: "\(planTitle(plan)) の申込締切が近づいています。",
                timing: deadlineTiming(forKey: AppStorageKeys.notificationApplicationDeadlineTiming)
            ))
        }

        if notificationPreference(
            forKey: AppStorageKeys.notificationLotteryResultEnabled,
            defaultValue: true
        ),
           attempt.resultAnnounceAt != Date.distantPast {
            let timing = pointTiming(forKey: AppStorageKeys.notificationLotteryResultTiming)
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).lotteryResult",
                    fireDate: pointFireDate(date: attempt.resultAnnounceAt, timing: timing),
                    title: "当落発表",
                    body: "\(planTitle(plan)) の当落発表日です。"
                )
            )
        }

        if notificationPreference(
            forKey: AppStorageKeys.notificationPaymentDeadlineEnabled,
            defaultValue: true
        ),
           attempt.paymentDeadlineAt != Date.distantPast {
            specs.append(contentsOf: deadlineSpecs(
                attemptID: attempt.id,
                typeKey: "paymentDeadline",
                date: attempt.paymentDeadlineAt,
                title: "入金締切",
                body: "\(planTitle(plan)) の入金締切が近づいています。",
                timing: deadlineTiming(forKey: AppStorageKeys.notificationPaymentDeadlineTiming)
            ))
        }

        if notificationPreference(
            forKey: AppStorageKeys.notificationTicketIssueEnabled,
            defaultValue: true
        ),
           attempt.issueStartAt != Date.distantPast {
            let timing = pointTiming(forKey: AppStorageKeys.notificationTicketIssueTiming)
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attempt.id.uuidString).ticketIssue",
                    fireDate: pointFireDate(date: attempt.issueStartAt, timing: timing),
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
        let timing = PerformanceNotificationTiming(
            rawValue: UserDefaults.standard.string(forKey: AppStorageKeys.notificationPerformanceTiming) ?? ""
        ) ?? .previousDayAndSameDay

        if timing != .sameDay,
           let previousDay = calendar.date(byAdding: .day, value: -1, to: plan.startsAt),
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

        if timing != .previousDay,
           let dayMorning = calendar.date(
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
        body: String,
        timing: TicketDeadlineNotificationTiming
    ) -> [TicketNotificationSpec] {
        var specs: [TicketNotificationSpec] = []
        if timing != .hourBefore,
           let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date) {
            specs.append(
                TicketNotificationSpec(
                    identifier: "ticket.\(attemptID.uuidString).\(typeKey).dayBefore",
                    fireDate: dayBefore,
                    title: title,
                    body: body
                )
            )
        }
        if timing != .dayBefore,
           let hourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: date) {
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
            return staleAttemptIdentifierCandidates(attemptID: attemptID)
        }

        return [
            "plan.\(planID.uuidString).performance.previousDay",
            "plan.\(planID.uuidString).performance.sameDay",
        ]
    }

    private static func staleAttemptIdentifierCandidates(attemptID: UUID) -> [String] {
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

    private static func planTitle(_ plan: Plan) -> String {
        plan.title.isEmpty ? "予定" : plan.title
    }

    private static func pointTiming(forKey key: String) -> TicketPointNotificationTiming {
        TicketPointNotificationTiming(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .atTime
    }

    private static func deadlineTiming(forKey key: String) -> TicketDeadlineNotificationTiming {
        TicketDeadlineNotificationTiming(rawValue: UserDefaults.standard.string(forKey: key) ?? "")
            ?? .dayBeforeAndHourBefore
    }

    private static func pointFireDate(date: Date, timing: TicketPointNotificationTiming) -> Date {
        switch timing {
        case .atTime:
            return date
        case .oneHourBefore:
            return Calendar.current.date(byAdding: .hour, value: -1, to: date) ?? date
        case .previousDayEvening:
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            return Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: previousDay) ?? previousDay
        }
    }

    private static func preparationFireDate(dueAt: Date, calendar: Calendar) -> Date? {
        let timing = PreparationNotificationTiming(
            rawValue: UserDefaults.standard.string(forKey: AppStorageKeys.notificationPreparationTiming) ?? ""
        ) ?? .previousDayEvening
        switch timing {
        case .previousDayEvening:
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: dueAt) else { return nil }
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: previousDay)
        case .oneHourBefore:
            return calendar.date(byAdding: .hour, value: -1, to: dueAt)
        case .atTime:
            return dueAt
        }
    }

    private static func notificationPreference(
        forKey key: String,
        defaultValue: Bool
    ) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}

private struct TicketNotificationSpec {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}
