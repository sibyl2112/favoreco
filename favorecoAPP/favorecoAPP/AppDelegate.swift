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
        guard userInfo[MonthlyReportNotificationScheduler.destinationKey] as? String
                == MonthlyReportNotificationScheduler.destinationValue else { return }
        UserDefaults.standard.set(true, forKey: AppStorageKeys.opensPreviousMonthlyReport)
        await MainActor.run {
            NotificationCenter.default.post(name: .openFavorecoStats, object: nil)
        }
    }
}

extension Notification.Name {
    static let openFavorecoStats = Notification.Name("openFavorecoStats")
}
