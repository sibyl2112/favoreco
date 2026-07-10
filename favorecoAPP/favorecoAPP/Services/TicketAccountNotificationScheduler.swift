//
//  TicketAccountNotificationScheduler.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import UserNotifications

enum TicketAccountNotificationScheduler {
    static func cancel(account: TicketAccount) {
        let identifiers = staleIdentifierCandidates(accountID: account.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    static func reschedule(account: TicketAccount) async {
        cancel(account: account)

        guard UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMasterEnabled),
              UserDefaults.standard.bool(forKey: AppStorageKeys.notificationMembershipExpiryEnabled),
              account.renewalNotify,
              account.expiryDate != Date.distantPast else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        for spec in notificationSpecs(account: account) where spec.fireDate > Date() {
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

    private static func notificationSpecs(account: TicketAccount) -> [TicketAccountNotificationSpec] {
        let title = account.serviceName.isEmpty ? "会員期限" : account.serviceName
        let body = "\(title) の有効期限が近づいています。"
        var specs: [TicketAccountNotificationSpec] = []

        if let monthBefore = Calendar.current.date(byAdding: .day, value: -30, to: account.expiryDate) {
            specs.append(
                TicketAccountNotificationSpec(
                    identifier: "ticketAccount.\(account.id.uuidString).expiry.monthBefore",
                    fireDate: reminderMorning(for: monthBefore),
                    title: "会員期限まで30日",
                    body: body
                )
            )
        }

        if let weekBefore = Calendar.current.date(byAdding: .day, value: -7, to: account.expiryDate) {
            specs.append(
                TicketAccountNotificationSpec(
                    identifier: "ticketAccount.\(account.id.uuidString).expiry.weekBefore",
                    fireDate: reminderMorning(for: weekBefore),
                    title: "会員期限まで7日",
                    body: body
                )
            )
        }

        specs.append(
            TicketAccountNotificationSpec(
                identifier: "ticketAccount.\(account.id.uuidString).expiry.sameDay",
                fireDate: reminderMorning(for: account.expiryDate),
                title: "会員期限日",
                body: "\(title) の有効期限日です。"
            )
        )

        return specs
    }

    private static func reminderMorning(for date: Date) -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }

    private static func staleIdentifierCandidates(accountID: UUID) -> [String] {
        let prefix = "ticketAccount.\(accountID.uuidString).expiry"
        return [
            "\(prefix).monthBefore",
            "\(prefix).weekBefore",
            "\(prefix).sameDay",
        ]
    }
}

private struct TicketAccountNotificationSpec {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}
