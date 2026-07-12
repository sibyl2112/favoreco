import Foundation
import UserNotifications

enum MonthlyReportNotificationScheduler {
    nonisolated static let identifier = "favoreco.report.monthly"
    nonisolated static let destinationKey = "favorecoDestination"
    nonisolated static let destinationValue = "previousMonthlyReport"

    static func reschedule(isEntitled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let defaults = UserDefaults.standard
        guard isEntitled,
              defaults.bool(forKey: AppStorageKeys.notificationMasterEnabled),
              defaults.bool(forKey: AppStorageKeys.notificationMonthlyReportEnabled) else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "月刊Favorecoが届きました"
        content.body = "先月の記録を、写真やジャンルを横断した思い出カードで振り返れます。"
        content.sound = .default
        content.userInfo = [destinationKey: destinationValue]

        var components = DateComponents()
        components.calendar = Calendar.current
        components.day = 1
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    nonisolated static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
