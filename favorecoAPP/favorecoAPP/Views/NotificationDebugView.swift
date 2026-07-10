//
//  NotificationDebugView.swift
//  favorecoAPP
//
//  開発者向け通知診断画面。チケット/予定/FC・会員期限の通知を実機で検証するため、
//  予約中・配信済みの一覧確認、権限リクエスト、テスト通知の送信/削除を行う。
//  既存の通知スケジューラ（TicketNotificationScheduler / TicketAccountNotificationScheduler）
//  のロジックは変更せず、UNUserNotificationCenter を直接参照して状態を可視化する。
//

import SwiftUI
import UserNotifications

struct NotificationDebugView: View {
    /// Favoreco が発行する通知IDの接頭辞（この接頭辞に一致するものだけを削除対象にする）。
    private static let favorecoPrefixes = ["plan.", "ticket.", "ticketAccount.", NotificationDebugView.testPrefix]
    /// 診断画面から送るテスト通知の接頭辞。
    private static let testPrefix = "favoreco.debug.notification."

    @State private var authorizationStatusText = "確認中"
    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var deliveredNotifications: [UNNotification] = []
    @State private var statusMessage = ""

    var body: some View {
        Form {
            Section("通知権限") {
                LabeledContent("iOS通知許可", value: authorizationStatusText)
                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Label("通知の許可をリクエスト", systemImage: "bell.badge")
                }
            }

            Section("サマリー") {
                LabeledContent("予約中", value: "\(pendingRequests.count) 件")
                LabeledContent("配信済み", value: "\(deliveredNotifications.count) 件")
                Button {
                    Task { await reload() }
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }
            }

            Section("テスト通知") {
                Button {
                    Task { await scheduleTestNotification(after: 5) }
                } label: {
                    Label("5秒後にテスト通知", systemImage: "5.circle")
                }
                Button {
                    Task { await scheduleTestNotification(after: 30) }
                } label: {
                    Label("30秒後にテスト通知", systemImage: "30.circle")
                }
                Button(role: .destructive) {
                    Task { await removeTestNotifications() }
                } label: {
                    Label("テスト通知を削除", systemImage: "trash")
                }
                Text("テスト通知IDは「\(Self.testPrefix)」で始まります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("予約中 (\(pendingRequests.count))") {
                if pendingRequests.isEmpty {
                    Text("予約中の通知はありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pendingRequests, id: \.identifier) { request in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.content.title.isEmpty ? request.identifier : request.content.title)
                                .font(.body)
                            Text(request.identifier)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                            Text(triggerDescription(for: request.trigger))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("配信済み (\(deliveredNotifications.count))") {
                if deliveredNotifications.isEmpty {
                    Text("配信済みの通知はありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deliveredNotifications, id: \.request.identifier) { notification in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.request.content.title.isEmpty
                                 ? notification.request.identifier
                                 : notification.request.content.title)
                                .font(.body)
                            Text(notification.request.identifier)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                            Text(deliveredDateText(notification.date))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("削除") {
                Button(role: .destructive) {
                    Task { await removeFavorecoNotifications() }
                } label: {
                    Label("Favoreco通知をすべて削除", systemImage: "trash.slash")
                }
                Text("plan. / ticket. / ticketAccount. / \(Self.testPrefix) で始まる通知だけを削除します（他アプリ・全削除はしません）。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("チケット・通知診断")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
    }

    // MARK: - 操作

    @MainActor
    private func reload() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()

        authorizationStatusText = Self.statusText(settings.authorizationStatus)
        pendingRequests = pending.sorted { $0.identifier < $1.identifier }
        deliveredNotifications = delivered.sorted { $0.date > $1.date }
    }

    @MainActor
    private func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            statusMessage = granted ? "通知が許可されました。" : "iOS側で通知が許可されていません。設定アプリから許可できます。"
        } catch {
            statusMessage = "通知許可の取得に失敗しました。"
        }
        await reload()
    }

    @MainActor
    private func scheduleTestNotification(after seconds: TimeInterval) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = "\(Int(seconds))秒後のテスト通知です。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let identifier = "\(Self.testPrefix)\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            statusMessage = "\(Int(seconds))秒後のテスト通知を予約しました。"
        } catch {
            statusMessage = "テスト通知の予約に失敗しました。"
        }
        await reload()
    }

    @MainActor
    private func removeTestNotifications() async {
        await removeNotifications(matchingPrefixes: [Self.testPrefix])
        statusMessage = "テスト通知を削除しました。"
        await reload()
    }

    @MainActor
    private func removeFavorecoNotifications() async {
        await removeNotifications(matchingPrefixes: Self.favorecoPrefixes)
        statusMessage = "Favoreco通知を削除しました。"
        await reload()
    }

    /// 指定した接頭辞のいずれかに一致する通知IDだけを、予約中・配信済みの両方から削除する。
    /// センターから最新の状態を取得してから対象を絞り込むため、画面表示のずれに影響されない。
    /// `removeAllPendingNotificationRequests()` は使わない（他アプリ由来を巻き込まないため）。
    @MainActor
    private func removeNotifications(matchingPrefixes prefixes: [String]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()

        let pendingIDs = pending
            .map(\.identifier)
            .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }
        let deliveredIDs = delivered
            .map(\.request.identifier)
            .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }

        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    // MARK: - 表示ヘルパー

    private func triggerDescription(for trigger: UNNotificationTrigger?) -> String {
        switch trigger {
        case let interval as UNTimeIntervalNotificationTrigger:
            return "約\(Int(interval.timeInterval))秒後"
        case let calendar as UNCalendarNotificationTrigger:
            if let next = calendar.nextTriggerDate() {
                return Self.dateFormatter.string(from: next)
            }
            return "日時指定"
        default:
            return "トリガーなし"
        }
    }

    private func deliveredDateText(_ date: Date) -> String {
        "配信: " + Self.dateFormatter.string(from: date)
    }

    private static func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未確認"
        case .denied: return "拒否"
        case .authorized: return "許可済み"
        case .provisional: return "仮許可"
        case .ephemeral: return "一時許可"
        @unknown default: return "不明"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) HH:mm"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        NotificationDebugView()
    }
}
