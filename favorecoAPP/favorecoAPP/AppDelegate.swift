//
//  AppDelegate.swift
//  favorecoAPP
//
//  UNUserNotificationCenterDelegate を設定し、アプリ前面表示中でも
//  ローカル通知（チケット申込締切・当落・入金締切など）をバナー/サウンド/バッジで表示する。
//  通知のスケジュール・ID・タイミングは既存スケジューラのまま（ここでは表示挙動のみを担う）。
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// アプリが前面表示中に通知が届いたときの表示方法。
    /// iOS標準では前面時にバナーが出ないため、明示的に banner / sound / badge を返して表示させる。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let planID = userInfo[TicketNotificationScheduler.destinationPlanIDKey] as? String,
           UUID(uuidString: planID) != nil {
            let taskID = userInfo[TicketNotificationScheduler.destinationPreparationTaskIDKey] as? String
            openPlanNotification(planID: planID, preparationTaskID: taskID)
            return
        }

        let identifierParts = response.notification.request.identifier.split(separator: ".")
        if identifierParts.count >= 2,
           identifierParts[0] == "plan",
           UUID(uuidString: String(identifierParts[1])) != nil {
            let taskID = identifierParts.count >= 4 && identifierParts[2] == "preparation"
                ? String(identifierParts[3])
                : nil
            openPlanNotification(planID: String(identifierParts[1]), preparationTaskID: taskID)
            return
        }
        if identifierParts.count >= 2,
           identifierParts[0] == "ticket",
           UUID(uuidString: String(identifierParts[1])) != nil {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.pendingNotificationPlanID)
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.pendingNotificationPreparationTaskID)
            UserDefaults.standard.set(
                String(identifierParts[1]),
                forKey: AppStorageKeys.pendingNotificationAttemptID
            )
            postOpenPlanNotification()
            return
        }

        guard let destination = userInfo[MonthlyReportNotificationScheduler.destinationKey] as? String else { return }
        switch destination {
        case MonthlyReportNotificationScheduler.monthlyDestinationValue:
            UserDefaults.standard.set(true, forKey: AppStorageKeys.opensPreviousMonthlyReport)
        case MonthlyReportNotificationScheduler.yearlyDestinationValue:
            UserDefaults.standard.set(true, forKey: AppStorageKeys.opensPreviousYearlyReport)
        default:
            return
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .openFavorecoStats, object: nil)
        }
    }

    private func openPlanNotification(planID: String, preparationTaskID: String?) {
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.pendingNotificationAttemptID)
        if let preparationTaskID, UUID(uuidString: preparationTaskID) != nil {
            UserDefaults.standard.set(
                preparationTaskID,
                forKey: AppStorageKeys.pendingNotificationPreparationTaskID
            )
        } else {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.pendingNotificationPreparationTaskID)
        }
        UserDefaults.standard.set(planID, forKey: AppStorageKeys.pendingNotificationPlanID)
        postOpenPlanNotification()
    }

    private func postOpenPlanNotification() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .openFavorecoPlan, object: nil)
        }
    }
}

extension Notification.Name {
    static let openFavorecoStats = Notification.Name("openFavorecoStats")
    static let openFavorecoPlan = Notification.Name("openFavorecoPlan")
}
