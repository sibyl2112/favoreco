import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var plans: [Plan]
    @Query private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @AppStorage(AppStorageKeys.notificationMasterEnabled) private var masterEnabled = false
    @AppStorage(AppStorageKeys.notificationApplicationStartEnabled) private var applicationStartEnabled = false
    @AppStorage(AppStorageKeys.notificationApplicationDeadlineEnabled) private var applicationDeadlineEnabled = true
    @AppStorage(AppStorageKeys.notificationLotteryResultEnabled) private var lotteryResultEnabled = true
    @AppStorage(AppStorageKeys.notificationPaymentDeadlineEnabled) private var paymentDeadlineEnabled = true
    @AppStorage(AppStorageKeys.notificationTicketIssueEnabled) private var ticketIssueEnabled = true
    @AppStorage(AppStorageKeys.notificationPerformanceReminderEnabled) private var performanceReminderEnabled = true
    @AppStorage(AppStorageKeys.notificationPreparationDeadlineEnabled) private var preparationDeadlineEnabled = true
    @AppStorage(AppStorageKeys.notificationApplicationStartTiming) private var applicationStartTiming = TicketPointNotificationTiming.atTime.rawValue
    @AppStorage(AppStorageKeys.notificationApplicationDeadlineTiming) private var applicationDeadlineTiming = TicketDeadlineNotificationTiming.dayBeforeAndHourBefore.rawValue
    @AppStorage(AppStorageKeys.notificationLotteryResultTiming) private var lotteryResultTiming = TicketPointNotificationTiming.atTime.rawValue
    @AppStorage(AppStorageKeys.notificationPaymentDeadlineTiming) private var paymentDeadlineTiming = TicketDeadlineNotificationTiming.dayBeforeAndHourBefore.rawValue
    @AppStorage(AppStorageKeys.notificationTicketIssueTiming) private var ticketIssueTiming = TicketPointNotificationTiming.atTime.rawValue
    @AppStorage(AppStorageKeys.notificationPerformanceTiming) private var performanceTiming = PerformanceNotificationTiming.previousDayAndSameDay.rawValue
    @AppStorage(AppStorageKeys.notificationPreparationTiming) private var preparationTiming = PreparationNotificationTiming.previousDayEvening.rawValue
    @AppStorage(AppStorageKeys.notificationMembershipExpiryEnabled) private var membershipExpiryEnabled = false
    @AppStorage(AppStorageKeys.notificationMemoryReminderEnabled) private var memoryReminderEnabled = false
    @AppStorage(AppStorageKeys.notificationMonthlyReportEnabled) private var monthlyReportEnabled = false
    @State private var authorizationStatusText = "確認中"
    @State private var permissionMessage = ""
    @State private var isShowingTicketTiming = false

    var body: some View {
        Form {
            Section("通知") {
                Toggle("通知を有効化", isOn: $masterEnabled)
                    .onChange(of: masterEnabled) { _, newValue in
                        if newValue {
                            requestNotificationAuthorization()
                        } else {
                            synchronizePlanAndTicketNotifications()
                            cancelMembershipNotifications()
                            MonthlyReportNotificationScheduler.cancel()
                        }
                    }
                LabeledContent("iOS通知許可", value: authorizationStatusText)
                if !permissionMessage.isEmpty {
                    Text(permissionMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("予定・チケット") {
                Picker("通知プリセット", selection: ticketPresetBinding) {
                    ForEach(TicketNotificationPreset.allCases) { preset in
                        Text(preset.title).tag(Optional(preset))
                    }
                }
                .pickerStyle(.segmented)

                Text(currentTicketPreset?.summary ?? "現在：カスタム設定")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                Toggle("申込開始", isOn: $applicationStartEnabled)
                Toggle("申込締切", isOn: $applicationDeadlineEnabled)
                Toggle("当落発表", isOn: $lotteryResultEnabled)
                Toggle("入金締切", isOn: $paymentDeadlineEnabled)
                Toggle("発券開始", isOn: $ticketIssueEnabled)
                Toggle("公演前日/当日", isOn: $performanceReminderEnabled)
                Toggle("公演準備の期限", isOn: $preparationDeadlineEnabled)

                DisclosureGroup("通知時刻を変更", isExpanded: $isShowingTicketTiming) {
                    if applicationStartEnabled {
                        pointTimingPicker("申込開始", selection: $applicationStartTiming)
                    }
                    if applicationDeadlineEnabled {
                        deadlineTimingPicker("申込締切", selection: $applicationDeadlineTiming)
                    }
                    if lotteryResultEnabled {
                        pointTimingPicker("当落発表", selection: $lotteryResultTiming)
                    }
                    if paymentDeadlineEnabled {
                        deadlineTimingPicker("入金締切", selection: $paymentDeadlineTiming)
                    }
                    if ticketIssueEnabled {
                        pointTimingPicker("発券開始", selection: $ticketIssueTiming)
                    }
                    if performanceReminderEnabled {
                        Picker("公演", selection: $performanceTiming) {
                            ForEach(PerformanceNotificationTiming.allCases) { timing in
                                Text(timing.displayName).tag(timing.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    if preparationDeadlineEnabled {
                        Picker("公演準備", selection: $preparationTiming) {
                            ForEach(PreparationNotificationTiming.allCases) { timing in
                                Text(timing.displayName).tag(timing.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Text("プリセットは通知する種類だけを変更し、ここで選んだ時刻は保持します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Text("新規利用時は「おすすめ」です。個別に変更するとカスタム設定として保持します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!masterEnabled)
            .onChange(of: ticketNotificationSignature) { _, _ in
                synchronizePlanAndTicketNotifications()
            }

            Section("アカウント") {
                Toggle("FC・会員期限", isOn: $membershipExpiryEnabled)
                    .onChange(of: membershipExpiryEnabled) { _, newValue in
                        if newValue {
                            rescheduleMembershipNotificationsIfNeeded()
                        } else {
                            cancelMembershipNotifications()
                        }
                    }
            }
            .disabled(!masterEnabled)

            Section("思い出") {
                Toggle("思い出リマインダー", isOn: $memoryReminderEnabled)
                Toggle("月刊・年間Favorecoを通知", isOn: $monthlyReportEnabled)
                    .disabled(!purchaseManager.currentPlan.includesSync)
                    .onChange(of: monthlyReportEnabled) { _, _ in
                        rescheduleMonthlyReportNotification()
                    }
                Text("月刊は毎月1日9時、年間は毎年1月1日10時にお知らせします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !purchaseManager.currentPlan.includesSync {
                    Label("思い出レポート通知はPremium限定", systemImage: "lock.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!masterEnabled)

            Section("現在の実装範囲") {
                Text("通知タイプ別の設定保存、iOS通知許可、予定・申込・公演準備・FC/会員期限、Premiumの月刊Favoreco通知まで接続しています。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshNotificationAuthorizationStatus()
            rescheduleMonthlyReportNotification()
        }
        .onChange(of: purchaseManager.currentPlan) { _, _ in
            rescheduleMonthlyReportNotification()
        }
    }

    private func requestNotificationAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                await refreshNotificationAuthorizationStatus()
                if !granted {
                    masterEnabled = false
                    permissionMessage = "iOS側で通知が許可されていません。必要になったら設定アプリから許可できます。"
                } else {
                    permissionMessage = "通知が許可されました。"
                    synchronizePlanAndTicketNotifications()
                    rescheduleMembershipNotificationsIfNeeded()
                    rescheduleMonthlyReportNotification()
                }
            } catch {
                masterEnabled = false
                permissionMessage = "通知許可の取得に失敗しました。"
            }
        }
    }

    private var currentTicketPreset: TicketNotificationPreset? {
        TicketNotificationPreset.allCases.first { preset in
            preset.applicationStart == applicationStartEnabled
                && preset.applicationDeadline == applicationDeadlineEnabled
                && preset.lotteryResult == lotteryResultEnabled
                && preset.paymentDeadline == paymentDeadlineEnabled
                && preset.ticketIssue == ticketIssueEnabled
                && preset.performanceReminder == performanceReminderEnabled
                && preset.preparationDeadline == preparationDeadlineEnabled
        }
    }

    private var ticketPresetBinding: Binding<TicketNotificationPreset?> {
        Binding(
            get: { currentTicketPreset },
            set: { preset in
                guard let preset else { return }
                applyTicketPreset(preset)
            }
        )
    }

    private var ticketNotificationSignature: String {
        [
            applicationStartEnabled,
            applicationDeadlineEnabled,
            lotteryResultEnabled,
            paymentDeadlineEnabled,
            ticketIssueEnabled,
            performanceReminderEnabled,
            preparationDeadlineEnabled,
        ]
        .map { $0 ? "1" : "0" }
        .joined() + [
            applicationStartTiming,
            applicationDeadlineTiming,
            lotteryResultTiming,
            paymentDeadlineTiming,
            ticketIssueTiming,
            performanceTiming,
            preparationTiming,
        ].joined(separator: "|")
    }

    private func applyTicketPreset(_ preset: TicketNotificationPreset) {
        applicationStartEnabled = preset.applicationStart
        applicationDeadlineEnabled = preset.applicationDeadline
        lotteryResultEnabled = preset.lotteryResult
        paymentDeadlineEnabled = preset.paymentDeadline
        ticketIssueEnabled = preset.ticketIssue
        performanceReminderEnabled = preset.performanceReminder
        preparationDeadlineEnabled = preset.preparationDeadline
    }

    private func pointTimingPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(TicketPointNotificationTiming.allCases) { timing in
                Text(timing.displayName).tag(timing.rawValue)
            }
        }
        .pickerStyle(.menu)
    }

    private func deadlineTimingPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(TicketDeadlineNotificationTiming.allCases) { timing in
                Text(timing.displayName).tag(timing.rawValue)
            }
        }
        .pickerStyle(.menu)
    }

    private func rescheduleMembershipNotificationsIfNeeded() {
        guard masterEnabled, membershipExpiryEnabled else {
            cancelMembershipNotifications()
            return
        }

        Task {
            for account in ticketAccounts where !account.isArchived && account.renewalNotify {
                await TicketAccountNotificationScheduler.reschedule(account: account)
            }
        }
    }

    private func synchronizePlanAndTicketNotifications() {
        Task {
            do {
                try await TicketNotificationSettingsSyncService.synchronize(
                    plans: plans,
                    attempts: ticketAttempts,
                    in: modelContext
                )
            } catch {
                permissionMessage = "予定・チケット通知を更新できませんでした。"
            }
        }
    }

    private func cancelMembershipNotifications() {
        for account in ticketAccounts {
            TicketAccountNotificationScheduler.cancel(account: account)
        }
    }

    private func rescheduleMonthlyReportNotification() {
        Task {
            await MonthlyReportNotificationScheduler.reschedule(
                isEntitled: purchaseManager.currentPlan.includesSync
            )
        }
    }

    private func refreshNotificationAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatusText = notificationStatusText(settings.authorizationStatus)
    }

    private func notificationStatusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未確認"
        case .denied:
            return "拒否"
        case .authorized:
            return "許可済み"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時許可"
        @unknown default:
            return "不明"
        }
    }
}

private enum TicketNotificationPreset: String, CaseIterable, Identifiable {
    case minimal
    case recommended
    case thorough

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: "少なめ"
        case .recommended: "おすすめ"
        case .thorough: "しっかり"
        }
    }

    var summary: String {
        switch self {
        case .minimal:
            "申込締切・入金締切・公演前日/当日"
        case .recommended:
            "締切・当落・入金・発券・公演・公演準備"
        case .thorough:
            "申込開始を含む予定・チケット通知をすべて使用"
        }
    }

    var applicationStart: Bool { self == .thorough }
    var applicationDeadline: Bool { true }
    var lotteryResult: Bool { self != .minimal }
    var paymentDeadline: Bool { true }
    var ticketIssue: Bool { self != .minimal }
    var performanceReminder: Bool { true }
    var preparationDeadline: Bool { self != .minimal }
}
