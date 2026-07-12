import Foundation
import UserNotifications

enum MonthlyReportNotificationScheduler {
    nonisolated static let monthlyIdentifier = "favoreco.report.monthly"
    nonisolated static let yearlyIdentifier = "favoreco.report.yearly"
    nonisolated static let destinationKey = "favorecoDestination"
    nonisolated static let monthlyDestinationValue = "previousMonthlyReport"
    nonisolated static let yearlyDestinationValue = "previousYearlyReport"

    static func reschedule(isEntitled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = [monthlyIdentifier, yearlyIdentifier]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)

        let defaults = UserDefaults.standard
        guard isEntitled,
              defaults.bool(forKey: AppStorageKeys.notificationMasterEnabled),
              defaults.bool(forKey: AppStorageKeys.notificationMonthlyReportEnabled) else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let monthlyContent = UNMutableNotificationContent()
        monthlyContent.title = "月刊Favorecoが届きました"
        monthlyContent.body = "先月の記録を、写真やジャンルを横断した思い出カードで振り返れます。"
        monthlyContent.sound = .default
        monthlyContent.userInfo = [destinationKey: monthlyDestinationValue]

        var components = DateComponents()
        components.calendar = Calendar.current
        components.day = 1
        components.hour = 9
        components.minute = 0
        let monthlyTrigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let monthlyRequest = UNNotificationRequest(
            identifier: monthlyIdentifier,
            content: monthlyContent,
            trigger: monthlyTrigger
        )
        try? await center.add(monthlyRequest)

        let yearlyContent = UNMutableNotificationContent()
        yearlyContent.title = "年間Favorecoが届きました"
        yearlyContent.body = "昨年の記録を横断して、心に残った体験を振り返れます。"
        yearlyContent.sound = .default
        yearlyContent.userInfo = [destinationKey: yearlyDestinationValue]

        var yearlyComponents = DateComponents()
        yearlyComponents.calendar = Calendar.current
        yearlyComponents.month = 1
        yearlyComponents.day = 1
        yearlyComponents.hour = 10
        yearlyComponents.minute = 0
        let yearlyTrigger = UNCalendarNotificationTrigger(dateMatching: yearlyComponents, repeats: true)
        let yearlyRequest = UNNotificationRequest(
            identifier: yearlyIdentifier,
            content: yearlyContent,
            trigger: yearlyTrigger
        )
        try? await center.add(yearlyRequest)
    }

    nonisolated static func cancel() {
        let center = UNUserNotificationCenter.current()
        let identifiers = [monthlyIdentifier, yearlyIdentifier]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
