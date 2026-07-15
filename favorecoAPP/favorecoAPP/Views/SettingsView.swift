//
//  SettingsView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    MySettingsHubView()
                } label: {
                    SettingsNavigationLabel(
                        title: "マイ・登録情報",
                        detail: "プロフィール、SNS、FC・チケットアカウント",
                        systemImage: "person.crop.circle"
                    )
                }

                NavigationLink {
                    AppSettingsHubView()
                } label: {
                    SettingsNavigationLabel(
                        title: "アプリ設定",
                        detail: "表示、ジャンル、記録の初期値、通知",
                        systemImage: "slider.horizontal.3"
                    )
                }

                NavigationLink {
                    DataSyncSettingsHubView()
                } label: {
                    SettingsNavigationLabel(
                        title: "データと同期",
                        detail: "マスター、書き出し、バックアップ、iCloud",
                        systemImage: "externaldrive.badge.icloud"
                    )
                }

                NavigationLink {
                    BillingPlanSettingsView()
                } label: {
                    SettingsNavigationLabel(
                        title: "プラン",
                        detail: "利用中のプラン、購入、購入の復元",
                        systemImage: "crown"
                    )
                }

                NavigationLink {
                    SupportLinksView()
                } label: {
                    SettingsNavigationLabel(
                        title: "サポート",
                        detail: "公式リンク、お問い合わせ、規約、アプリ情報",
                        systemImage: "questionmark.circle"
                    )
                }

#if DEBUG
                    NavigationLink {
                        DeveloperSettingsView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "開発者メニュー",
                            detail: "テスト権利、仮データ、通知診断",
                            systemImage: "hammer"
                        )
                    }
#endif
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SettingsNavigationLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MySettingsHubView: View {
    var body: some View {
        List {
            NavigationLink {
                ProfileSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "プロフィール",
                    detail: "表示名、写真、SNSアカウント",
                    systemImage: "person.crop.circle"
                )
            }

            NavigationLink {
                RegistrationIntegrationSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "登録情報・連携",
                    detail: "FC、プレイガイド、劇場会員、外部カレンダー",
                    systemImage: "person.text.rectangle"
                )
            }
        }
        .navigationTitle("マイ・登録情報")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppSettingsHubView: View {
    var body: some View {
        List {
            NavigationLink {
                DisplaySettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "表示・外観",
                    detail: "Home表示、外観、文字、フォント、テーマ",
                    systemImage: "textformat.size"
                )
            }

            NavigationLink {
                GenreManagementView()
            } label: {
                SettingsNavigationLabel(
                    title: "ジャンル",
                    detail: "表示順、表示・非表示、自作ジャンル、有効ユニット",
                    systemImage: "square.grid.2x2"
                )
            }

            NavigationLink {
                RecordInputAssistSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "記録・入力補助",
                    detail: "初期値、写真圧縮、URL・OCR・Map・天気の補助",
                    systemImage: "wand.and.sparkles"
                )
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "通知",
                    detail: "チケット期限、公演前日・当日、会員期限、レポート",
                    systemImage: "bell"
                )
            }
        }
        .navigationTitle("アプリ設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DataSyncSettingsHubView: View {
    var body: some View {
        List {
            NavigationLink {
                DataManagementView()
            } label: {
                SettingsNavigationLabel(
                    title: "データ管理",
                    detail: "マスター、読み書き、キャッシュ、非表示・削除",
                    systemImage: "externaldrive"
                )
            }

            NavigationLink {
                SyncBackupSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "同期・バックアップ",
                    detail: "iCloud同期、自動・完全バックアップ、復元、診断",
                    systemImage: "arrow.triangle.2.circlepath.icloud"
                )
            }
        }
        .navigationTitle("データと同期")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.debugPlanOverride) private var debugPlanOverride = "storekit"
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var debugHomeCategoryLayout = HomeCategoryLayoutMode.horizontal.rawValue
    @AppStorage(AppStorageKeys.lastSeenReleaseVersion) private var lastSeenReleaseVersion = ""
    @State private var debugMessage = ""

    var body: some View {
        Form {
            Section("権利・表示") {
                Picker("テスト権利", selection: $debugPlanOverride) {
                    Text("StoreKit購入結果").tag("storekit")
                    Text("無料").tag(FavorecoPlan.free.rawValue)
                    Text("ライト買い切り").tag(FavorecoPlan.lightLifetime.rawValue)
                    Text("同期プラン").tag(FavorecoPlan.syncSubscription.rawValue)
                    Text("フル買い切り").tag(FavorecoPlan.fullLifetime.rawValue)
                }
                .onChange(of: debugPlanOverride) { _, newValue in
                    Task {
                        await purchaseManager.setDebugPlanOverride(FavorecoPlan(rawValue: newValue))
                    }
                }

                LabeledContent("現在の権利", value: purchaseManager.currentPlan.displayName)

                Picker("Homeジャンル表示", selection: $debugHomeCategoryLayout) {
                    ForEach(HomeCategoryLayoutMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("診断") {
                NavigationLink {
                    NotificationDebugView()
                } label: {
                    Label("チケット・通知診断", systemImage: "bell.badge")
                }

                Button {
                    lastSeenReleaseVersion = ""
                    debugMessage = "アプリを終了して再起動すると、更新案内が表示されます。"
                } label: {
                    Label("次回起動で更新案内を表示", systemImage: "sparkles")
                }
            }

            Section("仮データ") {
                Button {
                    insertDebugData()
                } label: {
                    Label("写真付き仮データを追加", systemImage: "hammer.fill")
                }

                Button(role: .destructive) {
                    deleteDebugData()
                } label: {
                    Label("仮データを削除", systemImage: "trash")
                }

                NavigationLink {
                    FullDataDeletionView()
                } label: {
                    Label("全データ削除（テスト）", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }

                if !debugMessage.isEmpty {
                    Text(debugMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("開発者メニュー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func insertDebugData() {
        do {
            let count = try DebugDataSeeder.insertSampleData(in: modelContext)
            debugMessage = "仮データを\(count)件追加しました。"
        } catch {
            debugMessage = "仮データの追加に失敗しました。"
            assertionFailure("Failed to insert debug data: \(error)")
        }
    }

    private func deleteDebugData() {
        do {
            let count = try DebugDataSeeder.deleteSampleData(in: modelContext)
            debugMessage = "仮データを\(count)件削除しました。"
        } catch {
            debugMessage = "仮データの削除に失敗しました。"
            assertionFailure("Failed to delete debug data: \(error)")
        }
    }
}

struct RecordInputAssistSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.defaultGenreMode) private var defaultGenreMode = "lastUsed"
    @AppStorage(AppStorageKeys.afterSaveRecordAction) private var afterSaveRecordAction = "openDetail"
    @AppStorage(AppStorageKeys.photoAddStartMode) private var photoAddStartMode = "camera"
    @AppStorage(AppStorageKeys.photoCompressionQuality) private var photoCompressionQuality = 0.85
    @AppStorage(AppStorageKeys.usesURLImportAssist) private var usesURLImportAssist = true
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesWeatherAutoFill) private var usesWeatherAutoFill = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true

    var body: some View {
        Form {
            Section {
                Picker("最初に選ぶジャンル", selection: $defaultGenreMode) {
                    Text("最後に使ったジャンル").tag("lastUsed")
                    Text("Homeで選択中のジャンル").tag("homeSelected")
                }

                Picker("保存後", selection: $afterSaveRecordAction) {
                    Text("詳細を開く").tag("openDetail")
                    Text("一覧に戻る").tag("returnToList")
                }
            } header: {
                Text("記録の初期値")
            } footer: {
                Text("新しい記録の日付は今日から始まり、入力画面で変更できます。")
            }

            Section("写真") {
                Picker("写真追加時に開く", selection: $photoAddStartMode) {
                    Text("カメラを開く").tag("camera")
                    Text("写真ライブラリを開く").tag("library")
                }

                Picker("保存画質", selection: $photoCompressionQuality) {
                    Text("85%（画質優先）").tag(0.85)
                    Text("65%（容量優先）").tag(0.65)
                }

                LabeledContent("メタデータ削除", value: "ON")
                Text("追加時に長辺1600pxへ縮小し、選択した品質で保存します。位置情報や撮影日時などの元画像メタデータは引き継ぎません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("入力補助") {
                Toggle("URLから候補を取得", isOn: $usesURLImportAssist)
                Toggle("画像から文字を読み取る", isOn: $usesOCRImportAssist)
                Toggle("会場をMapで検索", isOn: $usesMapSearchAssist)
                Toggle("対象日の天気を付ける", isOn: $usesWeatherAutoFill)
                Toggle("登録済み候補を表示", isOn: $usesInputSuggestionDictionary)
                Label(
                    purchaseManager.currentPlan.includesLocalFullFeatures
                        ? "URLの日時・会場候補を利用できます"
                        : "URLの日時・会場候補はライト以上",
                    systemImage: purchaseManager.currentPlan.includesLocalFullFeatures ? "checkmark.circle" : "lock.fill"
                )
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
                Text("OCR取込をOFFにしても、保存済みの読み取りテキストと手入力欄は残ります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Label(
                    purchaseManager.currentPlan.includesLocalFullFeatures
                        ? "高度OCRの項目候補を利用できます"
                        : "高度OCRの項目候補はライト以上",
                    systemImage: purchaseManager.currentPlan.includesLocalFullFeatures ? "checkmark.circle" : "lock.fill"
                )
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("記録・入力補助")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RegistrationIntegrationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]
    @State private var isShowingAccountEditor = false
    @State private var editingAccount: TicketAccount?

    private var activeAccounts: [TicketAccount] {
        accounts.filter { !$0.isArchived }
    }

    var body: some View {
        List {
            Section("FC・チケットアカウント") {
                if activeAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("登録情報はまだありません", systemImage: "person.crop.circle.badge.plus")
                            .font(FavorecoTypography.bodyStrong)
                        Text("FC、プレイガイド、劇場会員、カード枠などをここにまとめます。チケット申込ではここから名義を選ぶだけにします。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(activeAccounts) { account in
                        Button {
                            editingAccount = account
                        } label: {
                            TicketAccountRow(account: account)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    isShowingAccountEditor = true
                } label: {
                    Label("登録情報を追加", systemImage: "plus.circle")
                }
            }

            Section("外部カレンダー") {
                LabeledContent("連携方式", value: "iOSカレンダー経由")
                Text("GoogleカレンダーもiOS標準カレンダーに登録されていれば、カレンダー画面に読み取り重ね表示できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("セキュリティ") {
                Text("パスワード本体はSwiftData/CloudKitに保存しません。必要になった場合のみKeychain参照キーを使い、Face ID/Touch ID/端末パスコードで表示・コピーします。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("登録情報・連携")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingAccountEditor) {
            NavigationStack {
                EditTicketAccountView(account: nil)
            }
        }
        .sheet(item: $editingAccount) { account in
            NavigationStack {
                EditTicketAccountView(account: account)
            }
        }
    }
}

private struct TicketAccountRow: View {
    let account: TicketAccount

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: account.colorHex))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.serviceName.isEmpty ? "未名称" : account.serviceName)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let typeName = TicketAccountTypeDefinition.name(for: account.accountTypeKey)
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(typeName) ・ \(holder)"
    }
}

private struct EditTicketAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let account: TicketAccount?

    @State private var serviceName = ""
    @State private var accountTypeKey = "other"
    @State private var siteURL = ""
    @State private var loginID = ""
    @State private var email = ""
    @State private var memberNumber = ""
    @State private var accountName = ""
    @State private var membershipRank = ""
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var annualFeeText = ""
    @State private var renewalNotify = false
    @State private var note = ""
    @State private var colorHex = "#6F8F7A"
    @State private var isShowingArchiveConfirmation = false

    private var canSave: Bool {
        !serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("基本") {
                TextField("サービス名（例: ぴあ / FC名）", text: $serviceName)

                Picker("種別", selection: $accountTypeKey) {
                    ForEach(TicketAccountTypeDefinition.all) { type in
                        Text(type.name).tag(type.key)
                    }
                }

                TextField("名義", text: $accountName)
                TextField("会員番号", text: $memberNumber)
                TextField("会員種別・ランク", text: $membershipRank)
            }

            Section("ログイン・リンク") {
                TextField("サイトURL", text: $siteURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                TextField("ログインID", text: $loginID)
                    .textInputAutocapitalization(.never)
                TextField("メール", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section("期限・費用") {
                DatePicker("有効期限", selection: $expiryDate, displayedComponents: .date)
                Toggle("期限通知", isOn: $renewalNotify)
                TextField("年会費", text: $annualFeeText)
                    .keyboardType(.numberPad)
            }

            Section("表示") {
                ColorPicker("識別色", selection: colorBinding, supportsOpacity: false)
            }

            Section("メモ") {
                TextField("備考", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            if account != nil {
                Section {
                    Button("この登録情報を非表示にする", role: .destructive) {
                        isShowingArchiveConfirmation = true
                    }
                } header: {
                    Text("管理")
                } footer: {
                    Text("非表示にすると、今後の申込フォームや期限アテンションには表示されません。既存の申込履歴は残ります。")
                }
            }
        }
        .navigationTitle(account == nil ? "登録情報を追加" : "登録情報を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onAppear(perform: loadAccount)
        .confirmationDialog("登録情報を非表示にしますか？", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                archiveAccount()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("期限通知をキャンセルし、申込フォームの候補から外します。")
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) },
            set: { colorHex = $0.hexString() ?? "#6F8F7A" }
        )
    }

    private func loadAccount() {
        guard let account else { return }
        serviceName = account.serviceName
        accountTypeKey = account.accountTypeKey
        siteURL = account.siteURL
        loginID = account.loginID
        email = account.email
        memberNumber = account.memberNumber
        accountName = account.accountName
        membershipRank = account.membershipRank
        if account.expiryDate != Date.distantPast {
            expiryDate = account.expiryDate
        }
        annualFeeText = account.annualFee > 0 ? "\(account.annualFee)" : ""
        renewalNotify = account.renewalNotify
        note = account.note
        colorHex = account.colorHex
    }

    private func save() {
        let target = account ?? TicketAccount()
        let now = Date()
        target.serviceName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.accountTypeKey = accountTypeKey
        target.siteURL = siteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        target.loginID = loginID.trimmingCharacters(in: .whitespacesAndNewlines)
        target.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        target.memberNumber = memberNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.accountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.membershipRank = membershipRank.trimmingCharacters(in: .whitespacesAndNewlines)
        target.expiryDate = expiryDate
        target.annualFee = Int(annualFeeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        target.renewalNotify = renewalNotify
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.colorHex = colorHex
        target.normalizedServiceName = target.serviceName.lowercased()
        target.normalizedMemberNumber = target.memberNumber.lowercased()
        target.updatedAt = now

        if account == nil {
            target.createdAt = now
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            if target.renewalNotify {
                Task {
                    await TicketAccountNotificationScheduler.reschedule(account: target)
                }
            } else {
                TicketAccountNotificationScheduler.cancel(account: target)
            }
            dismiss()
        } catch {
            assertionFailure("Failed to save ticket account: \(error)")
        }
    }

    private func archiveAccount() {
        guard let account else { return }
        account.isArchived = true
        account.renewalNotify = false
        account.updatedAt = Date()
        TicketAccountNotificationScheduler.cancel(account: account)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to archive ticket account: \(error)")
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var plans: [Plan]
    @Query private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @AppStorage(AppStorageKeys.notificationMasterEnabled) private var masterEnabled = false
    @AppStorage(AppStorageKeys.notificationApplicationStartEnabled) private var applicationStartEnabled = false
    @AppStorage(AppStorageKeys.notificationApplicationDeadlineEnabled) private var applicationDeadlineEnabled = false
    @AppStorage(AppStorageKeys.notificationLotteryResultEnabled) private var lotteryResultEnabled = false
    @AppStorage(AppStorageKeys.notificationPaymentDeadlineEnabled) private var paymentDeadlineEnabled = false
    @AppStorage(AppStorageKeys.notificationTicketIssueEnabled) private var ticketIssueEnabled = false
    @AppStorage(AppStorageKeys.notificationPerformanceReminderEnabled) private var performanceReminderEnabled = true
    @AppStorage(AppStorageKeys.notificationMembershipExpiryEnabled) private var membershipExpiryEnabled = false
    @AppStorage(AppStorageKeys.notificationMemoryReminderEnabled) private var memoryReminderEnabled = false
    @AppStorage(AppStorageKeys.notificationMonthlyReportEnabled) private var monthlyReportEnabled = false
    @State private var authorizationStatusText = "確認中"
    @State private var permissionMessage = ""

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
                Toggle("申込開始", isOn: $applicationStartEnabled)
                    .onChange(of: applicationStartEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Toggle("申込締切", isOn: $applicationDeadlineEnabled)
                    .onChange(of: applicationDeadlineEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Toggle("当落発表", isOn: $lotteryResultEnabled)
                    .onChange(of: lotteryResultEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Toggle("入金締切", isOn: $paymentDeadlineEnabled)
                    .onChange(of: paymentDeadlineEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Toggle("発券開始", isOn: $ticketIssueEnabled)
                    .onChange(of: ticketIssueEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Toggle("公演前日/当日", isOn: $performanceReminderEnabled)
                    .onChange(of: performanceReminderEnabled) { _, _ in
                        synchronizePlanAndTicketNotifications()
                    }
                Text("公演前日/当日だけ初期ONです。申込、当落、入金、発券は必要なものだけ選びます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!masterEnabled)

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
                    Label("思い出レポート通知は同期プラン以上", systemImage: "lock.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!masterEnabled)

            Section("現在の実装範囲") {
                Text("通知タイプ別の設定保存、iOS通知許可、予定・申込・FC/会員期限、同期プランの月刊Favoreco通知まで接続しています。")
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

struct DisplaySettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsHomeAttention = true
    @AppStorage(AppStorageKeys.showsHomeExperienceGallery) private var showsHomeExperienceGallery = true
    @AppStorage(AppStorageKeys.showsHomeInbox) private var showsHomeInbox = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsHomeRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsHomeCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsHomeStatsSummary = false
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage(AppStorageKeys.themeMode) private var themeModeRaw = FavorecoThemeMode.categoryAccent.rawValue
    @AppStorage(AppStorageKeys.unifiedThemeColorHex) private var unifiedThemeColorHex = "#147C88"

    var body: some View {
        Form {
            Section("Home表示") {
                Toggle("アテンション", isOn: $showsHomeAttention)
                Toggle("最近の思い出", isOn: $showsHomeExperienceGallery)
                Toggle("気になる", isOn: $showsHomeInbox)
                Toggle("最近の記録", isOn: $showsHomeRecentRecords)
                Toggle("ジャンル一覧", isOn: $showsHomeCategories)
                Toggle("統計サマリ", isOn: $showsHomeStatsSummary)
            }

            Section("外観") {
                NavigationLink {
                    TextSizeSettingsView()
                } label: {
                    LabeledContent("文字サイズ", value: textSizeSummary)
                }
                NavigationLink {
                    FontStyleSettingsView()
                } label: {
                    LabeledContent("フォント", value: effectiveFontStyle.name)
                }
                Picker("外観モード", selection: $appearanceModeRaw) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.name).tag(mode.rawValue)
                    }
                }
            }

            Section("テーマ") {
                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    Picker("配色", selection: themeModeBinding) {
                        ForEach(FavorecoThemeMode.allCases) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }

                    if effectiveThemeMode == .unified {
                        Picker("全体カラー", selection: $unifiedThemeColorHex) {
                            ForEach(FavorecoThemeColorPreset.all) { preset in
                                Label {
                                    Text(preset.name)
                                } icon: {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 14, height: 14)
                                }
                                .tag(preset.hex)
                            }
                        }
                    }
                } else {
                    LabeledContent("配色", value: FavorecoThemeMode.categoryAccent.name)
                    Label("全体統一テーマはライト以上", systemImage: "lock.fill")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                Text("標準では白を基調にジャンル色をアクセントとして使います。全体統一では操作色を選んだ色へ揃えます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("表示・外観")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var textSizeSummary: String {
        followsSystemTextSize
            ? "端末設定に従う"
            : (AppTextSize(rawValue: appTextSizeRaw) ?? .standard).name
    }

    private var effectiveThemeMode: FavorecoThemeMode {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return .categoryAccent }
        return FavorecoThemeMode(rawValue: themeModeRaw) ?? .categoryAccent
    }

    private var effectiveFontStyle: AppFontStyle {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return .standard }
        return AppFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    private var themeModeBinding: Binding<FavorecoThemeMode> {
        Binding(
            get: { effectiveThemeMode },
            set: { themeModeRaw = $0.rawValue }
        )
    }
}

private struct FontStyleSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.fontWeight) private var fontWeightRaw = AppFontWeight.standard.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(AppFontStyle.allCases) { style in
                    Button {
                        guard style == .standard || canChangeFont else { return }
                        fontStyleRaw = style.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.name)
                                    .font(font(for: style, size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(style.detail)
                                    .font(font(for: style, size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.tint)
                            } else if style != .standard && !canChangeFont {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(canChangeFont
                     ? "英字の見出しには、どの設定でも Cormorant Garamond を使います。"
                     : "フォント変更はライト買い切り以上で利用できます。標準表示は無料で使えます。")
            }

            Section {
                Picker("文字の太さ", selection: fontWeightBinding) {
                    ForEach(AppFontWeight.allCases) { option in
                        Text(option.name).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canChangeFont)
            } header: {
                Text("文字の太さ")
            } footer: {
                if !canChangeFont {
                    Text("文字の太さ変更はライト買い切り以上で利用できます。")
                } else {
                    Text("本文と見出しの強弱を保ったまま、アプリ全体の文字を調整します。")
                }
            }

            Section("プレビュー") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("記録が、美しい思い出になる")
                        .font(font(for: selectedStyle, size: 24, weight: .bold, prefersSerif: true))
                    Text("観た作品や訪れた場所を、写真と一緒に残せます。")
                        .font(font(for: selectedStyle, size: 15))
                    Text("Favoreco 2026")
                        .font(FavorecoTypography.latinDisplay(20, weight: .semibold, relativeTo: .headline))
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("フォント")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canChangeFont: Bool {
        purchaseManager.currentPlan.includesLocalFullFeatures
    }

    private var selectedStyle: AppFontStyle {
        guard canChangeFont else { return .standard }
        return AppFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    private var fontWeightBinding: Binding<String> {
        Binding(
            get: { canChangeFont ? fontWeightRaw : AppFontWeight.standard.rawValue },
            set: { newValue in
                guard canChangeFont else { return }
                fontWeightRaw = newValue
            }
        )
    }

    private func font(
        for style: AppFontStyle,
        size: CGFloat,
        weight: Font.Weight = .regular,
        prefersSerif: Bool = false
    ) -> Font {
        let usesSerif = style == .serif || (style == .standard && prefersSerif)
        let name = usesSerif ? "Noto Serif JP" : "Noto Sans JP"
        return .custom(name, size: size, relativeTo: size >= 20 ? .title2 : .body)
            .weight(previewWeight(weight))
    }

    private func previewWeight(_ weight: Font.Weight) -> Font.Weight {
        let option = canChangeFont
            ? (AppFontWeight(rawValue: fontWeightRaw) ?? .standard)
            : .standard
        switch option {
        case .standard:
            return weight
        case .light:
            if weight == .bold || weight == .heavy || weight == .black { return .semibold }
            if weight == .semibold { return .medium }
            if weight == .medium { return .regular }
            return .light
        case .bold:
            if weight == .black || weight == .heavy { return .black }
            if weight == .bold || weight == .semibold { return .bold }
            if weight == .medium { return .semibold }
            return .medium
        }
    }
}

private struct TextSizeSettingsView: View {
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("iOS設定に従う", isOn: $followsSystemTextSize)

                if !followsSystemTextSize {
                    Picker("アプリ内文字サイズ", selection: $appTextSizeRaw) {
                        ForEach(AppTextSize.allCases) { option in
                            Text(option.name).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("iOS設定に従う場合は、端末の文字サイズとアクセシビリティ設定を反映します。")
            }

            Section("プレビュー") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("記録が、美しい思い出になる")
                        .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
                    Text("観た作品や訪れた場所を、写真と一緒に残せます。")
                        .font(FavorecoTypography.body)
                    Text("Favoreco 2026")
                        .font(FavorecoTypography.latinDisplay(20, weight: .semibold, relativeTo: .headline))
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("文字サイズ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @Query private var categories: [RecordCategory]
    @Query private var events: [ExperienceEvent]
    @Query private var visits: [Visit]
    @Query private var inboxItems: [InboxItem]
    @Query private var photos: [PhotoBlob]
    @Query private var plans: [Plan]
    @Query private var ticketAttempts: [TicketAttempt]
    @Query private var ticketAccounts: [TicketAccount]
    @Query private var socialAccounts: [SocialAccount]
    @Query private var people: [PersonMaster]
    @Query private var places: [PlaceMaster]
    @State private var isConfirmingArchivedDeletion = false
    @State private var maintenanceMessage = ""

    private var archivedItemCount: Int {
        events.filter(\.isArchived).count
            + plans.filter(\.isArchived).count
            + ticketAttempts.filter(\.isArchived).count
            + ticketAccounts.filter(\.isArchived).count
            + socialAccounts.filter(\.isArchived).count
            + people.filter(\.isArchived).count
            + places.filter(\.isArchived).count
    }

    private var totalPhotoBytes: Int64 {
        photos.reduce(Int64(0)) { partialResult, photo in
            partialResult + Int64(max(photo.byteCount, 0))
        }
    }

    private var averagePhotoBytes: Int64 {
        photos.isEmpty ? 0 : totalPhotoBytes / Int64(photos.count)
    }

    private var estimatedTenThousandPhotoBytes: Int64 {
        averagePhotoBytes * 10_000
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Text("\(visits.count)件の記録")
                        .font(FavorecoTypography.heroLead)
                    Text("\(photos.count)枚の写真")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("保存データ") {
                LabeledContent("対象", value: "\(events.count)")
                LabeledContent("気になる対象", value: "\(events.filter { $0.stateKey == "interested" && !$0.isArchived }.count)")
                LabeledContent("訪問/鑑賞記録", value: "\(visits.count)")
                if !inboxItems.isEmpty {
                    LabeledContent("旧クイックデータ（移行待ち）", value: "\(inboxItems.count)")
                }
                LabeledContent("ジャンル", value: "\(categories.count)")
                LabeledContent("写真", value: "\(photos.count)")
                LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
                if !photos.isEmpty {
                    LabeledContent("1枚の平均", value: ByteCountFormatter.string(fromByteCount: averagePhotoBytes, countStyle: .file))
                    LabeledContent("1万枚の推定", value: ByteCountFormatter.string(fromByteCount: estimatedTenThousandPhotoBytes, countStyle: .file))
                }
            }

            Section("マスター管理") {
                NavigationLink {
                    PersonMasterManagementView()
                } label: {
                    LabeledContent("人物・団体", value: "\(people.filter { !$0.isArchived }.count)")
                }
                NavigationLink {
                    PlaceMasterManagementView()
                } label: {
                    LabeledContent("場所", value: "\(places.filter { !$0.isArchived }.count)")
                }
                Text("似た候補を確認し、過去の表示スナップショットを変えずに統合できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("インポート・エクスポート") {
                NavigationLink {
                    FullBackupView()
                } label: {
                    Label("写真付き完全バックアップ", systemImage: "archivebox")
                }

                NavigationLink {
                    JSONExportView()
                } label: {
                    Label("JSONエクスポート", systemImage: "square.and.arrow.up")
                }

                NavigationLink {
                    CSVExportView()
                } label: {
                    Label("CSVエクスポート", systemImage: "tablecells")
                }

                NavigationLink {
                    JSONImportView()
                } label: {
                    Label("JSONインポート", systemImage: "square.and.arrow.down")
                }

                NavigationLink {
                    CSVImportView()
                } label: {
                    Label("CSVインポート", systemImage: "tray.and.arrow.down")
                }
            }

            Section("バックアップについて") {
                Text("記録はこの端末に保存されています。アプリを削除する前やデータ整理の前に、無料のJSONエクスポートで手動バックアップしてください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("キャッシュ") {
                Button {
                    URLCache.shared.removeAllCachedResponses()
                    maintenanceMessage = "Webキャッシュを削除しました。記録データは変更していません。"
                } label: {
                    Label("Webキャッシュを削除", systemImage: "network.slash")
                }

                Button {
                    ThumbnailLoader.purge()
                    maintenanceMessage = "写真サムネイルのキャッシュを削除しました。写真本体は残っています。"
                } label: {
                    Label("写真キャッシュを削除", systemImage: "photo.badge.arrow.down")
                }

                Text("キャッシュは表示を速くする一時データです。削除しても記録や写真本体は消えません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("データ整理") {
                NavigationLink {
                    ArchivedEventManagementView()
                } label: {
                    LabeledContent("非表示の対象", value: "\(events.filter(\.isArchived).count)")
                }

                Button(role: .destructive) {
                    isConfirmingArchivedDeletion = true
                } label: {
                    Label("アーカイブ済みデータを完全削除", systemImage: "archivebox.fill")
                }
                .disabled(archivedItemCount == 0)

                Text(archivedItemCount == 0
                     ? "完全削除できるアーカイブ済み項目はありません。"
                     : "非表示にした対象・予定・申込・マスターなどが\(archivedItemCount)件あります。関連する記録や写真も削除される場合があります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    FullDataDeletionView()
                } label: {
                    Label("全データ削除", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
            }

            if !maintenanceMessage.isEmpty {
                Section("処理結果") {
                    Text(maintenanceMessage)
                        .font(FavorecoTypography.caption)
                }
            }
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "アーカイブ済みデータを完全削除しますか？",
            isPresented: $isConfirmingArchivedDeletion,
            titleVisibility: .visible
        ) {
            Button("完全削除する", role: .destructive) {
                deleteArchivedData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。非表示の対象に紐づく記録・写真、非表示の予定・申込なども削除されます。先にJSONバックアップを推奨します。")
        }
    }

    private func deleteArchivedData() {
        do {
            let result = try RecordDeletionService.deleteArchivedData(in: modelContext)
            reconcileDeletedCalendarLinks(result.externalCalendarTargets, clearsAllLinks: false)
            maintenanceMessage = "アーカイブ済みデータを\(result.totalCount)件削除しました（対象\(result.eventCount)、記録\(result.visitCount)、予定\(result.planCount)、申込\(result.attemptCount)、マスター\(result.masterCount)、人物リンク\(result.linkCount)）。"
        } catch {
            modelContext.rollback()
            maintenanceMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }

    private func reconcileDeletedCalendarLinks(
        _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget],
        clearsAllLinks: Bool
    ) {
        reconcileExternalCalendarLinks(
            targets,
            removesExternalEvents: purchaseManager.currentPlan.includesSync
                && automaticallyUpdatesExternalCalendar,
            clearsAllLinks: clearsAllLinks
        )
    }
}

private struct ArchivedEventManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]
    @State private var restoreErrorMessage: String?

    private var archivedEvents: [ExperienceEvent] {
        allEvents.filter(\.isArchived)
    }

    var body: some View {
        List {
            if archivedEvents.isEmpty {
                ContentUnavailableView(
                    "非表示の対象はありません",
                    systemImage: "archivebox",
                    description: Text("対象詳細のメニューから非表示にした項目がここへ表示されます。")
                )
            } else {
                Section {
                    ForEach(archivedEvents) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.category?.iconSymbol ?? "rectangle.stack")
                                .foregroundStyle(Color(hex: event.category?.colorHex ?? "#6F8F7A"))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title.isEmpty ? "記録" : event.title)
                                    .font(FavorecoTypography.bodyStrong)
                                HStack(spacing: 8) {
                                    Text(event.category?.name ?? "未分類")
                                    Text("履歴 \((event.visits ?? []).count)件")
                                }
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                restore(event)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(event.title)を再表示")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("再表示") {
                                restore(event)
                            }
                            .tint(.accentColor)
                        }
                    }
                } footer: {
                    Text("再表示すると、ジャンル内の対象一覧と記録一覧へ戻ります。履歴・写真・予定は変更しません。")
                }
            }
        }
        .navigationTitle("非表示の対象")
        .navigationBarTitleDisplayMode(.inline)
        .alert("復元に失敗しました", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { if !$0 { restoreErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { restoreErrorMessage = nil }
        } message: {
            Text(restoreErrorMessage ?? "")
        }
    }

    private func restore(_ event: ExperienceEvent) {
        event.isArchived = false
        event.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            restoreErrorMessage = "「\(event.title.isEmpty ? "記録" : event.title)」を再表示できませんでした。"
        }
    }
}

struct FullDataDeletionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @Query private var categories: [RecordCategory]
    @Query private var events: [ExperienceEvent]
    @Query private var visits: [Visit]
    @Query private var inboxItems: [InboxItem]
    @Query private var photos: [PhotoBlob]
    @Query private var socialAccounts: [SocialAccount]
    @Query private var people: [PersonMaster]
    @Query private var personLinks: [EventPersonLink]
    @Query private var places: [PlaceMaster]
    @Query private var plans: [Plan]
    @Query private var ticketAccounts: [TicketAccount]
    @Query private var ticketAttempts: [TicketAttempt]
    @State private var confirmationText = ""
    @State private var isShowingFinalConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage = ""

    private let requiredText = "削除する"

    private var totalModelCount: Int {
        categories.count + events.count + visits.count + inboxItems.count + photos.count
            + socialAccounts.count + people.count + personLinks.count + places.count
            + plans.count + ticketAccounts.count + ticketAttempts.count
    }

    var body: some View {
        Form {
            Section {
                Label("すべての記録データが失われます", systemImage: "exclamationmark.triangle.fill")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(.red)
                Text("この操作は取り消せません。実行前にデータ管理からJSONバックアップを書き出してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("削除されるもの") {
                LabeledContent("保存モデル", value: "\(totalModelCount)件")
                LabeledContent("対象", value: "\(events.count)件")
                LabeledContent("記録", value: "\(visits.count)件")
                LabeledContent("写真", value: "\(photos.count)件")
                LabeledContent("予定・申込", value: "\(plans.count + ticketAttempts.count)件")
                Text("自作ジャンル、人物、場所、SNS、登録情報、気になる対象も削除されます。通知予約とキャッシュも消去します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("保持されるもの") {
                Text("Home表示、入力補助、通知タイプなどの設定値は保持します。削除後は標準ジャンルを再生成し、初回ジャンル選択へ戻ります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("確認") {
                Text("続けるには「\(requiredText)」と入力してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                TextField(requiredText, text: $confirmationText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(role: .destructive) {
                    isShowingFinalConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("全データ削除へ進む", systemImage: "trash.fill")
                    }
                }
                .disabled(confirmationText != requiredText || isDeleting || totalModelCount == 0)
            }

            if !errorMessage.isEmpty {
                Section("エラー") {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("全データ削除")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "本当に全データを削除しますか？",
            isPresented: $isShowingFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("すべて削除する", role: .destructive) {
                deleteAllData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(totalModelCount)件の保存モデルを削除します。この操作は取り消せません。")
        }
    }

    private func deleteAllData() {
        isDeleting = true
        errorMessage = ""
        Task { @MainActor in
            do {
                let result = try RecordDeletionService.deleteAllData(in: modelContext)
                reconcileExternalCalendarLinks(
                    result.externalCalendarTargets,
                    removesExternalEvents: purchaseManager.currentPlan.includesSync
                        && automaticallyUpdatesExternalCalendar,
                    clearsAllLinks: true
                )
            } catch {
                modelContext.rollback()
                errorMessage = "全データ削除に失敗しました: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }
}

private func reconcileExternalCalendarLinks(
    _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget],
    removesExternalEvents: Bool,
    clearsAllLinks: Bool
) {
    guard removesExternalEvents else {
        if clearsAllLinks {
            ExternalCalendarLinkStore.clearAll()
        } else {
            for target in targets {
                ExternalCalendarLinkStore.clear(planID: target.planID)
            }
        }
        return
    }

    Task { @MainActor in
        for target in targets {
            _ = try? await ExternalCalendarSyncService.remove(
                identifier: target.eventIdentifier,
                planID: target.planID
            )
        }
        if clearsAllLinks {
            ExternalCalendarLinkStore.clearAll()
        }
    }
}

struct CSVExportView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @State private var isExporterPresented = false
    @State private var exportDocument = CSVExportDocument()
    @State private var exportErrorMessage = ""

    private var csvText: String {
        CSVExportService.makeVisitsCSV(visits: visits)
    }

    private var fileName: String {
        "favoreco-visits-\(Date().formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("記録CSV")
                        .font(FavorecoTypography.sectionTitle)
                    Text("保存済みの訪問/鑑賞記録を、表計算アプリで開けるCSVとして書き出します。写真データは含みません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("対象データ") {
                LabeledContent("記録数", value: "\(visits.count)")
                LabeledContent("形式", value: "CSV / UTF-8")
                LabeledContent("写真", value: "含めない")
            }

            Section("書き出し") {
                Button {
                    exportDocument = CSVExportDocument(text: csvText)
                    exportErrorMessage = ""
                    isExporterPresented = true
                } label: {
                    Label("CSVファイルを書き出す", systemImage: "square.and.arrow.up")
                }
                .disabled(visits.isEmpty)

                if visits.isEmpty {
                    Text("書き出せる記録がまだありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !exportErrorMessage.isEmpty {
                    Text(exportErrorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("列") {
                Text("date, category, title, series, venue, rating, status, seat, amount, official_url, tags, companions, note などを書き出します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CSVエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: fileName
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

struct JSONExportView: View {
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.updatedAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \PhotoBlob.createdAt, order: .reverse) private var photos: [PhotoBlob]
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @Query(sort: \Plan.startsAt, order: .reverse) private var plans: [Plan]
    @Query(sort: \TicketAccount.serviceName) private var ticketAccounts: [TicketAccount]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]

    @State private var isExporterPresented = false
    @State private var exportDocument = JSONBackupDocument()
    @State private var exportErrorMessage = ""

    private var fileName: String {
        "favoreco-backup-\(Date().formatted(.iso8601.year().month().day()))"
    }

    private var totalRecordCount: Int {
        categories.count + events.count + visits.count + inboxItems.count + socialAccounts.count + people.count + personLinks.count + places.count + plans.count + ticketAccounts.count + ticketAttempts.count
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSONバックアップ")
                        .font(FavorecoTypography.sectionTitle)
                    Text("アプリに戻せる形式を想定した手動バックアップです。現時点では写真のバイナリデータは含めず、記録本体と紐付け情報を書き出します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("対象データ") {
                LabeledContent("ジャンル", value: "\(categories.count)")
                LabeledContent("対象", value: "\(events.count)")
                LabeledContent("訪問/鑑賞記録", value: "\(visits.count)")
                LabeledContent("人物・団体", value: "\(people.count)")
                LabeledContent("人物リンク", value: "\(personLinks.count)")
                LabeledContent("場所", value: "\(places.count)")
                LabeledContent("予定", value: "\(plans.count)")
                LabeledContent("登録情報・名義", value: "\(ticketAccounts.count)")
                LabeledContent("チケット申込", value: "\(ticketAttempts.count)")
                LabeledContent("気になる対象", value: "\(events.filter { $0.stateKey == "interested" && !$0.isArchived }.count)")
                if !inboxItems.isEmpty {
                    LabeledContent("旧クイックデータ", value: "\(inboxItems.count)")
                }
                LabeledContent("SNS", value: "\(socialAccounts.count)")
                LabeledContent("写真メタデータ", value: "\(photos.count)")
            }

            Section("書き出し") {
                Button {
                    do {
                        let text = try JSONBackupExportService.makeBackupJSON(
                            categories: categories,
                            events: events,
                            visits: visits,
                            inboxItems: inboxItems,
                            photos: photos,
                            socialAccounts: socialAccounts,
                            people: people,
                            personLinks: personLinks,
                            places: places,
                            plans: plans,
                            ticketAccounts: ticketAccounts,
                            ticketAttempts: ticketAttempts
                        )
                        exportDocument = JSONBackupDocument(text: text)
                        exportErrorMessage = ""
                        isExporterPresented = true
                    } catch {
                        exportErrorMessage = error.localizedDescription
                    }
                } label: {
                    Label("JSONファイルを書き出す", systemImage: "square.and.arrow.up")
                }
                .disabled(totalRecordCount == 0)

                if totalRecordCount == 0 {
                    Text("書き出せるデータがまだありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !exportErrorMessage.isEmpty {
                    Text(exportErrorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("含まれないもの") {
                Text("JSON単体には写真/動画の実データ、iCloud同期状態、通知予約、外部カレンダー側のイベントを含めません。写真本体を残す場合は「完全バックアップ」を使用してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("JSONエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: fileName
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

struct SyncBackupSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \PhotoBlob.createdAt, order: .reverse) private var photos: [PhotoBlob]
    @AppStorage(AppStorageKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(AppStorageKeys.iCloudSyncActiveAtLaunch) private var iCloudSyncActiveAtLaunch = false
    @AppStorage(AppStorageKeys.iCloudSyncStartupError) private var iCloudSyncStartupError = ""
    @AppStorage(AppStorageKeys.automaticBackupEnabled) private var automaticBackupEnabled = false
    @AppStorage(AppStorageKeys.automaticBackupUsesICloudDrive) private var automaticBackupUsesICloudDrive = false
    @AppStorage(AppStorageKeys.automaticBackupICloudError) private var automaticBackupICloudError = ""
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @State private var diagnostic: CloudSyncDiagnostic?
    @State private var isRefreshingDiagnostic = false

    private var totalPhotoBytes: Int64 {
        photos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
    }

    var body: some View {
        Form {
            Section {
                Toggle("iCloud同期", isOn: $iCloudSyncEnabled)
                    .disabled(!canUseSyncFeatures)
                LabeledContent("現在の保存先", value: iCloudSyncActiveAtLaunch ? "端末 + iCloud" : "この端末")
                LabeledContent("iCloudアカウント", value: diagnostic?.accountStatusText ?? "未確認")

                if iCloudSyncEnabled != iCloudSyncActiveAtLaunch {
                    Label("変更はアプリを終了し、次に起動した時から反映されます。", systemImage: "arrow.clockwise.circle")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !iCloudSyncStartupError.isEmpty {
                    Label("同期を開始できなかったため、この端末だけで安全に起動しました。", systemImage: "exclamationmark.icloud")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.orange)
                    Text(iCloudSyncStartupError)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await refreshDiagnostic() }
                } label: {
                    Label(isRefreshingDiagnostic ? "確認中" : "同期環境を確認", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshingDiagnostic)
                LabeledContent("写真の同期", value: iCloudSyncActiveAtLaunch ? "含む" : "OFF")
                LabeledContent("写真データ", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
            } header: {
                Text("同期")
            } footer: {
                Text("ONでは同じApple Accountの端末間で記録と写真を自動同期します。まず端末内へ保存されるため、通信やiCloud容量の問題で記録が失われることはありません。初回はWi-Fi環境を推奨します。")
            }

            Section("バックアップ") {
#if DEBUG
                Toggle("自動バックアップ", isOn: $automaticBackupEnabled)
                Toggle("iCloud Driveにも保存", isOn: $automaticBackupUsesICloudDrive)
                    .disabled(!automaticBackupEnabled)
#else
                Toggle("自動バックアップ", isOn: $automaticBackupEnabled)
                    .disabled(!canUseSyncFeatures)
                Toggle("iCloud Driveにも保存", isOn: $automaticBackupUsesICloudDrive)
                    .disabled(!canUseSyncFeatures || !automaticBackupEnabled)
#endif
                LabeledContent(
                    "バックアップ先",
                    value: automaticBackupUsesICloudDrive ? "端末 + iCloud Drive" : "この端末"
                )
                if !automaticBackupICloudError.isEmpty {
                    Label(automaticBackupICloudError, systemImage: "exclamationmark.icloud")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.orange)
                }
                NavigationLink {
                    AutomaticBackupView()
                } label: {
                    Label("自動バックアップの管理", systemImage: "clock.arrow.2.circlepath")
                }
                NavigationLink {
                    FullBackupView()
                } label: {
                    Label("完全バックアップ・復元", systemImage: "archivebox")
                }
                Text("24時間に1回、起動時に写真付きバックアップを作成します。写真容量が増えると保持世代数を自動で減らし、作成前に端末の空き容量を確認します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("外部カレンダー") {
                Toggle("favorecoの予定変更を自動反映", isOn: $automaticallyUpdatesExternalCalendar)
                    .disabled(!purchaseManager.currentPlan.includesSync)
                Text("先に予定詳細の「カレンダーに追加」からApple/Googleなどの追加先を選びます。以後、favorecoで予定を編集・削除した時だけ同じ外部イベントへ片方向で反映します。外部側の編集はfavorecoへ戻しません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                if !purchaseManager.currentPlan.includesSync {
                    Label("自動更新は同期プラン以上", systemImage: "lock.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("同期トラブル診断") {
                LabeledContent("iCloud Drive", value: diagnostic?.hasUbiquityContainer == true ? "利用可能" : "未確認 / 利用不可")
                LabeledContent("起動時の同期接続", value: iCloudSyncActiveAtLaunch ? "接続済み" : "未接続")
                if let errorMessage = diagnostic?.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("同期・バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshDiagnostic()
        }
    }

    @MainActor
    private func refreshDiagnostic() async {
        guard !isRefreshingDiagnostic else { return }
        isRefreshingDiagnostic = true
        diagnostic = await CloudSyncService.diagnostic()
        isRefreshingDiagnostic = false
    }

    private var canUseSyncFeatures: Bool {
#if DEBUG
        true
#else
        purchaseManager.currentPlan.includesSync
#endif
    }
}

struct BillingPlanSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        Form {
            Section("現在のプラン") {
                LabeledContent("プラン", value: purchaseManager.currentPlan.displayName)
                Text(planDescription)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("無料で使えること") {
                PlanFeatureRow(
                    title: "基本記録",
                    detail: "記録の作成、編集、閲覧。URL/動画リンク保存も含む。",
                    systemImage: "square.and.pencil"
                )
                PlanFeatureRow(
                    title: "写真",
                    detail: "1記録10枚まで。カバー写真とサムネイル表示も無料。",
                    systemImage: "photo"
                )
                PlanFeatureRow(
                    title: "カレンダー",
                    detail: "手動でカレンダーに追加。追加先カレンダーの選択も無料。",
                    systemImage: "calendar.badge.plus"
                )
                PlanFeatureRow(
                    title: "バックアップ",
                    detail: "JSON/CSVなどの手動エクスポートは無料の安全網として扱う。",
                    systemImage: "square.and.arrow.up"
                )
            }

            Section("ライト買い切り") {
                PlanHeaderRow(
                    title: "ライト買い切り",
                    price: "¥1,500",
                    detail: "ローカル全機能を永久解放。同期は含めない。"
                )
                PlanFeatureRow(
                    title: "詳細統計・年間まとめ",
                    detail: "月/年/通算の深い統計、年間ベスト画像化など。",
                    systemImage: "chart.bar.xaxis"
                )
                PlanFeatureRow(
                    title: "OCR高度化",
                    detail: "複雑な半券、チケット、レシート、リスト画像の補助を強化。",
                    systemImage: "text.viewfinder"
                )
                PlanFeatureRow(
                    title: "URL高度取込",
                    detail: "公式ページの構造化データから日時・会場候補を取得。",
                    systemImage: "link.badge.plus"
                )
                PlanFeatureRow(
                    title: "写真上限",
                    detail: "1記録あたり30枚まで保存。無料枠は10枚まで。",
                    systemImage: "photo.stack"
                )
                PlanFeatureRow(
                    title: "テーマ・フォント拡張",
                    detail: "追加テーマ、個別テーマ、高度なフォント変更候補。",
                    systemImage: "paintpalette"
                )
            }

            Section("同期プラン") {
                PlanHeaderRow(
                    title: "同期サブスク",
                    price: "月¥250 / 年¥1,500",
                    detail: "契約中はローカル全機能と同期を利用可能。"
                )
                PlanFeatureRow(
                    title: "iCloud同期",
                    detail: "端末間同期、自動バックアップ、復元を扱う。",
                    systemImage: "icloud.and.arrow.up"
                )
                PlanFeatureRow(
                    title: "自動思い出レポート",
                    detail: "月刊Favoreco、年間Favorecoを自動生成し、写真やジャンル傾向から思い出カードを提案する。",
                    systemImage: "sparkles.rectangle.stack"
                )
                PlanFeatureRow(
                    title: "継続更新される補助",
                    detail: "外部候補、参照データ、入力補助など継続価値のある機能候補。",
                    systemImage: "sparkles"
                )
            }

            Section("フル買い切り") {
                PlanHeaderRow(
                    title: "フル買い切り",
                    price: "¥6,000",
                    detail: "ライト¥1,500 + 同期永久¥4,500。どの購入ルートでも合計が揃う頭金方式。"
                )
                PlanFeatureRow(
                    title: "同期も永久",
                    detail: "ローカル全機能と同期を永久解放する最上位候補。",
                    systemImage: "checkmark.seal"
                )
            }

            Section("購入") {
                if purchaseManager.products.isEmpty {
                    Text("商品情報を取得できません。App Store Connectへ商品を登録すると購入ボタンが表示されます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    if !purchaseManager.ownsLightLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.lightLifetime) {
                        StorePurchaseRow(title: "ライト買い切り", product: product)
                    }
                    if let product = purchaseManager.product(id: FavorecoProductID.syncMonthly) {
                        StorePurchaseRow(title: "同期 月額", product: product)
                    }
                    if let product = purchaseManager.product(id: FavorecoProductID.syncYearly) {
                        StorePurchaseRow(title: "同期 年額", product: product)
                    }
                    if purchaseManager.ownsLightLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.syncLifetimeAddon) {
                        StorePurchaseRow(title: "同期永久を追加", product: product)
                    }
                    if !purchaseManager.ownsLightLifetime,
                       let product = purchaseManager.product(id: FavorecoProductID.fullLifetime) {
                        StorePurchaseRow(title: "フル買い切り", product: product)
                    }
                }
                Button {
                    Task { await purchaseManager.restore() }
                } label: {
                    Label("購入を復元", systemImage: "arrow.clockwise")
                }
                .disabled(purchaseManager.isLoading)
            }

            if purchaseManager.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("App Storeを確認中です。")
                    }
                }
            }

            if !purchaseManager.message.isEmpty {
                Section("購入状況") {
                    Text(purchaseManager.message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("補足") {
                NavigationLink {
                    SettingsDocumentView(title: "創設メンバー特典", bodyText: "既存¥980ユーザーと発売締切までの新規購入者に同期永久無料を付与する案を保持しています。締切日は未定です。")
                } label: {
                    Label("創設メンバー特典", systemImage: "person.2.badge.gearshape")
                }

                NavigationLink {
                    SettingsDocumentView(title: "DBパック管理", bodyText: "DBパックは商品として未確定です。寺社、会場、劇場、施設、辞書プリセットなど、権利と更新コストを確認できるものだけ検討します。")
                } label: {
                    Label("DBパック管理", systemImage: "shippingbox")
                }
            }
        }
        .navigationTitle("課金・プラン")
        .navigationBarTitleDisplayMode(.inline)
        .task { await purchaseManager.refresh() }
    }

    private var planDescription: String {
        switch purchaseManager.currentPlan {
        case .free: return "基本記録と無料機能を利用できます。"
        case .lightLifetime: return "ローカル全機能を永久に利用できます。同期は含みません。"
        case .syncSubscription: return "契約中はローカル全機能、同期、自動バックアップを利用できます。"
        case .fullLifetime: return "ローカル全機能、同期、自動バックアップを永久に利用できます。"
        }
    }
}

private struct StorePurchaseRow: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    let title: String
    let product: Product

    var body: some View {
        Button {
            Task { await purchaseManager.purchase(product) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(product.displayPrice)
                    .font(FavorecoTypography.bodyStrong)
            }
        }
        .disabled(purchaseManager.isLoading)
    }
}

private struct PlanHeaderRow: View {
    let title: String
    let price: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text(price)
                    .font(FavorecoTypography.bodyStrong)
            }
            Text(detail)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct PlanFeatureRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SupportLinksView: View {
    private let officialSiteURL = URL(string: "https://ranoviqo.com")!
    private let favorecoSiteURL = AppReleaseNotes.detailURL

    var body: some View {
        Form {
            Section("リンク") {
                Link(destination: officialSiteURL) {
                    Label("RANOVIQO公式サイト", systemImage: "globe")
                }

                NavigationLink {
                    SettingsDocumentView(title: "利用規約", bodyText: FavorecoLegalText.terms)
                } label: {
                    Label("利用規約", systemImage: "doc.text")
                }

                NavigationLink {
                    SettingsDocumentView(title: "プライバシーポリシー", bodyText: FavorecoLegalText.privacy)
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
            }

            Section("アプリ情報") {
                NavigationLink {
                    ReleaseHistoryView()
                } label: {
                    Label("更新履歴", systemImage: "clock.arrow.circlepath")
                }

                Link(destination: favorecoSiteURL) {
                    Label("Favoreco公式サイト", systemImage: "arrow.up.right.square")
                }

                LabeledContent("バージョン", value: AppReleaseNotes.currentVersion)
            }

            Section("サポート") {
                Link(destination: officialSiteURL) {
                    Label("お問い合わせ", systemImage: "envelope")
                }

                Button {
                } label: {
                    Label("レビューで応援", systemImage: "star")
                }
                .disabled(true)

                ShareLink(
                    item: officialSiteURL,
                    subject: Text("Favoreco"),
                    message: Text("好きな体験を、ジャンルを横断して記録できるFavoreco")
                ) {
                    Label("アプリをシェア", systemImage: "square.and.arrow.up")
                }
            }

            Section("公式SNS") {
                Label("公式X（公開準備中）", systemImage: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("リンク・サポート")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsDocumentView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(FavorecoTypography.heroLead)
                Text(bodyText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum FavorecoLegalText {
    static let terms = """
    最終更新日: 2026年7月12日

    Favorecoは、映画、観劇、ライブ、本、展示、訪問、飲食などの体験を利用者自身が記録・管理するためのアプリです。本アプリを利用することで、本規約に同意したものとみなします。

    1. 記録内容
    利用者は、入力する文章、写真、チケット、座席、金額、URLその他の情報について必要な権利を有し、法令および第三者の権利を侵害しない範囲で利用するものとします。

    2. 禁止事項
    他人になりすます行為、第三者の権利を侵害する行為、不正アクセス、アプリの運営を妨げる行為、法令または公序良俗に反する行為を禁止します。

    3. 外部サービス
    地図、カレンダー、天気、Webサイト、クラウド同期などの外部サービスは、各提供者の利用条件と提供状況に従います。外部情報の正確性や継続提供を保証するものではありません。

    4. 有料機能
    有料機能の価格、期間、利用範囲は購入画面に表示します。サブスクリプションの管理および解約はApple Accountの設定から行います。購入の復元には購入時と同じApple Accountが必要です。

    5. データ管理
    利用者は必要に応じてバックアップを書き出し、自身の責任で保管してください。端末の故障、アプリ削除、同期設定、外部サービス障害などによるデータ消失を完全に防げることは保証しません。

    6. 免責
    本アプリは現状有姿で提供します。運営者の故意または重大な過失がある場合を除き、本アプリの利用によって生じた間接的または付随的な損害について責任を負いません。

    7. 変更・終了
    機能、規約、提供条件は必要に応じて変更されることがあります。重要な変更はアプリ内または公式サイトで案内します。

    8. お問い合わせ
    不具合、ご意見、規約に関するお問い合わせはRANOVIQO公式サイトの案内をご利用ください。
    """

    static let privacy = """
    最終更新日: 2026年7月12日

    RANOVIQOは、Favorecoに保存される情報と外部サービスの利用について、以下のとおり取り扱います。

    1. 保存する情報
    利用者が入力した記録、予定、チケット情報、人物・団体、場所、金額、メモ、URL、写真、設定値を保存します。基本データは端末内に保存され、利用者がiCloud同期を有効にした場合は利用者のiCloud領域へ同期されます。

    2. 写真
    選択された写真は保存時に縮小・再描画し、撮影日時やGPSなど元画像のメタデータを引き継がない形で保存します。写真へのアクセスは、利用者が追加操作を行った時だけ求めます。

    3. 位置情報・地図
    現在地の継続取得は行いません。会場や施設の地図表示には、利用者が入力・選択した施設名、住所、座標を使用します。住所が登録されている場合は住所を優先して位置を解決します。

    4. カレンダー・通知
    利用者が許可した場合に限り、外部カレンダーの表示や予定追加、端末内通知の予約を行います。権限はiOSの設定から変更できます。

    5. Web・天気・OCR
    URL候補取得、地図検索、天気取得には入力されたURL、場所、日付など必要な情報を各サービスへ送る場合があります。OCRは端末上のApple Visionを使用し、読み取った文字は利用者が保存した場合だけ記録へ残ります。

    6. 課金
    購入処理はAppleのStoreKitを利用します。運営者がクレジットカード番号を取得・保存することはありません。アプリは購入状態と利用可能な権利を確認します。

    7. 共有と第三者提供
    利用者が共有、書き出し、外部リンクを明示的に実行した場合を除き、記録内容を第三者へ公開しません。法令に基づく場合を除き、個人データを販売しません。

    8. 削除・バックアップ
    設定からキャッシュ、写真キャッシュ、アーカイブ、全データを削除できます。JSON、CSV、写真付き完全バックアップは利用者が明示的に書き出します。iCloud上のデータは同期状態に応じて反映に時間がかかる場合があります。

    9. 変更・お問い合わせ
    本ポリシーを変更する場合は、アプリ内または公式サイトで案内します。お問い合わせはRANOVIQO公式サイトの案内をご利用ください。
    """
}

#Preview {
    SettingsView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
