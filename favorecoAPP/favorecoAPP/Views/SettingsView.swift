//
//  SettingsView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @State private var debugMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("マイ") {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        Label("プロフィール", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        RegistrationIntegrationSettingsView()
                    } label: {
                        Label("登録情報・連携", systemImage: "person.text.rectangle")
                    }
                }

                Section("表示") {
                    NavigationLink {
                        DisplaySettingsView()
                    } label: {
                        Label("表示設定", systemImage: "textformat.size")
                    }
                }

                Section("ジャンル") {
                    NavigationLink {
                        GenreManagementView()
                    } label: {
                        Label("ジャンル管理", systemImage: "square.grid.2x2")
                    }

                    Button {
                        hasCompletedGenreOnboarding = false
                        dismiss()
                    } label: {
                        Label("初回ジャンル選択をやり直す", systemImage: "checklist")
                    }
                }

                Section("記録・入力補助") {
                    NavigationLink {
                        RecordInputAssistSettingsView()
                    } label: {
                        Label("記録・入力補助", systemImage: "wand.and.sparkles")
                    }
                }

                Section("通知") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("通知設定", systemImage: "bell")
                    }
                }

                Section("データ管理") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("データ管理", systemImage: "externaldrive")
                    }
                }

                Section("同期・バックアップ") {
                    NavigationLink {
                        SyncBackupSettingsView()
                    } label: {
                        Label("同期・バックアップ", systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                }

                Section("課金・プラン") {
                    NavigationLink {
                        BillingPlanSettingsView()
                    } label: {
                        Label("課金・プラン", systemImage: "crown")
                    }
                }

                Section("リンク・サポート") {
                    NavigationLink {
                        SupportLinksView()
                    } label: {
                        Label("リンク・サポート", systemImage: "questionmark.circle")
                    }
                }

                Section("開発") {
                    NavigationLink {
                        NotificationDebugView()
                    } label: {
                        Label("チケット・通知診断", systemImage: "bell.badge")
                    }

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

                    if !debugMessage.isEmpty {
                        Text(debugMessage)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
    @AppStorage(AppStorageKeys.defaultRecordDateMode) private var defaultRecordDateMode = "today"
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
            Section("記録の初期値") {
                Picker("デフォルト記録日", selection: $defaultRecordDateMode) {
                    Text("今日").tag("today")
                }

                Picker("デフォルトジャンル", selection: $defaultGenreMode) {
                    Text("最後に使ったジャンル").tag("lastUsed")
                    Text("Homeで選択中のジャンル").tag("homeSelected")
                }

                Picker("記録追加後", selection: $afterSaveRecordAction) {
                    Text("詳細を開く").tag("openDetail")
                }
            }

            Section("写真") {
                Picker("写真追加", selection: $photoAddStartMode) {
                    Text("カメラを開く").tag("camera")
                    Text("写真ライブラリを開く").tag("library")
                }

                Picker("写真圧縮", selection: $photoCompressionQuality) {
                    Text("85%（画質優先）").tag(0.85)
                    Text("65%（容量優先）").tag(0.65)
                }

                LabeledContent("メタデータ削除", value: "ON")
                Text("追加時に長辺1600pxへ縮小し、選択した品質で保存します。位置情報や撮影日時などの元画像メタデータは引き継ぎません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("入力補助") {
                Toggle("URL取込候補", isOn: $usesURLImportAssist)
                Toggle("OCR取込", isOn: $usesOCRImportAssist)
                Toggle("Map検索", isOn: $usesMapSearchAssist)
                Toggle("天気自動付与", isOn: $usesWeatherAutoFill)
                Toggle("入力補助辞書", isOn: $usesInputSuggestionDictionary)
                Text("OCR取込をOFFにしても、保存済みの読み取りテキストと手入力欄は残ります。項目への自動振り分けなどの高度OCRはPro候補です。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("後日検討") {
                LabeledContent("Apple Music連携", value: "V2以降で検討")
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
    @State private var authorizationStatusText = "確認中"
    @State private var permissionMessage = ""

    var body: some View {
        Form {
            Section("通知") {
                Toggle("通知を有効化", isOn: $masterEnabled)
                    .onChange(of: masterEnabled) { _, newValue in
                        if newValue {
                            requestNotificationAuthorization()
                            rescheduleMembershipNotificationsIfNeeded()
                        } else {
                            cancelMembershipNotifications()
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
                Toggle("申込締切", isOn: $applicationDeadlineEnabled)
                Toggle("当落発表", isOn: $lotteryResultEnabled)
                Toggle("入金締切", isOn: $paymentDeadlineEnabled)
                Toggle("発券開始", isOn: $ticketIssueEnabled)
                Toggle("公演前日/当日", isOn: $performanceReminderEnabled)
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
            }
            .disabled(!masterEnabled)

            Section("現在の実装範囲") {
                Text("通知タイプ別の設定保存、iOS通知許可、予定・申込・FC/会員期限の予約まで接続しています。予定・申込は保存時、FC・会員期限は設定変更時にも反映します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshNotificationAuthorizationStatus()
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
                    rescheduleMembershipNotificationsIfNeeded()
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

    private func cancelMembershipNotifications() {
        for account in ticketAccounts {
            TicketAccountNotificationScheduler.cancel(account: account)
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
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsHomeAttention = true
    @AppStorage(AppStorageKeys.showsHomeExperienceGallery) private var showsHomeExperienceGallery = true
    @AppStorage(AppStorageKeys.showsHomeInbox) private var showsHomeInbox = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsHomeRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsHomeCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsHomeStatsSummary = false
    @AppStorage(AppStorageKeys.showsHomeFavorites) private var showsHomeFavorites = false

    var body: some View {
        Form {
            Section("Home表示") {
                Toggle("アテンション", isOn: $showsHomeAttention)
                Toggle("体験ギャラリー", isOn: $showsHomeExperienceGallery)
                Toggle("あとで記録", isOn: $showsHomeInbox)
                Toggle("最近の記録", isOn: $showsHomeRecentRecords)
                Toggle("ジャンル一覧", isOn: $showsHomeCategories)
                Toggle("統計サマリ", isOn: $showsHomeStatsSummary)
                Toggle("お気に入り/ベスト", isOn: $showsHomeFavorites)
            }

            Section("外観") {
                LabeledContent("文字サイズ", value: "準備中")
                LabeledContent("外観モード", value: "端末設定に従う")
            }
        }
        .navigationTitle("表示設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
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
                LabeledContent("訪問/鑑賞記録", value: "\(visits.count)")
                LabeledContent("あとで記録", value: "\(inboxItems.count)")
                LabeledContent("ジャンル", value: "\(categories.count)")
                LabeledContent("写真", value: "\(photos.count)")
            }

            Section("インポート・エクスポート") {
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
            maintenanceMessage = "アーカイブ済みデータを\(result.totalCount)件削除しました（対象\(result.eventCount)、記録\(result.visitCount)、予定\(result.planCount)、申込\(result.attemptCount)、マスター\(result.masterCount)、人物リンク\(result.linkCount)）。"
        } catch {
            modelContext.rollback()
            maintenanceMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

struct FullDataDeletionView: View {
    @Environment(\.modelContext) private var modelContext
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
                Text("自作ジャンル、人物、場所、SNS、登録情報、あとで記録も削除されます。通知予約とキャッシュも消去します。")
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
                _ = try RecordDeletionService.deleteAllData(in: modelContext)
            } catch {
                modelContext.rollback()
                errorMessage = "全データ削除に失敗しました: \(error.localizedDescription)"
                isDeleting = false
            }
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
                LabeledContent("あとで記録", value: "\(inboxItems.count)")
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
                Text("写真/動画の実データ、iCloud同期状態、通知予約、外部カレンダー側のイベントはまだ含めません。写真付き完全バックアップは後続で扱います。")
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
    var body: some View {
        Form {
            Section("同期") {
                Toggle("iCloud同期", isOn: .constant(false))
                    .disabled(true)
                LabeledContent("最終同期", value: "未同期")
                Button {
                } label: {
                    Label("今すぐ同期", systemImage: "arrow.clockwise")
                }
                .disabled(true)
                LabeledContent("写真の同期", value: "準備中")
            }

            Section("バックアップ") {
                Toggle("自動バックアップ", isOn: .constant(false))
                    .disabled(true)
                LabeledContent("バックアップ先", value: "準備中")
                NavigationLink {
                    SettingsDocumentView(title: "復元", bodyText: "バックアップから復元する入口として準備予定です。既存データを壊さない取り込み方式にします。")
                } label: {
                    Label("復元", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("同期トラブル診断") {
                NavigationLink {
                    SettingsDocumentView(title: "同期トラブル診断", bodyText: "iCloud状態、端末容量、写真同期、最終同期時刻を確認する画面として準備予定です。")
                } label: {
                    Label("診断を開く", systemImage: "stethoscope")
                }
            }
        }
        .navigationTitle("同期・バックアップ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BillingPlanSettingsView: View {
    var body: some View {
        Form {
            Section("現在のプラン") {
                LabeledContent("プラン", value: "無料")
                Text("購入処理は未接続です。同期実装後の4プラン構造を前提に、無料/有料の境界だけ先に整理しています。")
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

            Section("Pro買い切り候補") {
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
                    title: "テーマ・フォント拡張",
                    detail: "追加テーマ、個別テーマ、高度なフォント変更候補。",
                    systemImage: "paintpalette"
                )
            }

            Section("同期プラン候補") {
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

            Section("フル買い切り候補") {
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
                NavigationLink {
                    SettingsDocumentView(title: "アップグレード", bodyText: "StoreKit接続前のため購入はまだできません。無料、ライト買い切り、同期サブスク、フル買い切りの見せ方をこの画面で固めてから実装します。")
                } label: {
                    Label("アップグレード", systemImage: "crown")
                }
                Button {
                } label: {
                    Label("購入を復元", systemImage: "arrow.clockwise")
                }
                .disabled(true)
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
    var body: some View {
        Form {
            Section("リンク") {
                NavigationLink {
                    SettingsDocumentView(title: "公式サイト", bodyText: "公式サイトへのリンク入口として準備予定です。")
                } label: {
                    Label("公式サイト", systemImage: "globe")
                }

                NavigationLink {
                    SettingsDocumentView(title: "利用規約", bodyText: "利用規約は準備中です。写真、座席、メモ、SNS紐付けなどの扱いを整理してから掲載します。")
                } label: {
                    Label("利用規約", systemImage: "doc.text")
                }

                NavigationLink {
                    SettingsDocumentView(title: "プライバシーポリシー", bodyText: "プライバシーポリシーは準備中です。端末内保存、写真、位置情報、同期、外部サービス連携の扱いを明記します。")
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
            }

            Section("サポート") {
                NavigationLink {
                    SettingsDocumentView(title: "お問い合わせ", bodyText: "お問い合わせ導線は準備中です。不具合報告、ご意見、ご要望を送れる入口にします。")
                } label: {
                    Label("お問い合わせ", systemImage: "envelope")
                }

                Button {
                } label: {
                    Label("レビューで応援", systemImage: "star")
                }
                .disabled(true)

                Button {
                } label: {
                    Label("アプリをシェア", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
            }

            Section("公式SNS") {
                NavigationLink {
                    SettingsDocumentView(title: "公式X", bodyText: "公式Xへのリンク入口として準備予定です。")
                } label: {
                    Label("公式X", systemImage: "arrow.up.right.square")
                }

                NavigationLink {
                    SettingsDocumentView(title: "公式Threads", bodyText: "公式Threadsへのリンク入口として準備予定です。")
                } label: {
                    Label("公式Threads", systemImage: "arrow.up.right.square")
                }
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

#Preview {
    SettingsView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
