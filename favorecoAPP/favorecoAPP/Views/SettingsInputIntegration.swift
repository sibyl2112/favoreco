import SwiftUI
import SwiftData

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
                Toggle("場所などの登録済み候補を表示", isOn: $usesInputSuggestionDictionary)
                Label(
                    purchaseManager.currentPlan.includesLocalFullFeatures
                        ? "URLの日時・会場候補を利用できます"
                        : "URLの日時・会場候補はPro以上",
                    systemImage: purchaseManager.currentPlan.includesLocalFullFeatures ? "checkmark.circle" : "lock.fill"
                )
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
                Text("OCR取込をOFFにしても、保存済みの読み取りテキストと手入力欄は残ります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Text("人物・団体は重複登録を防ぐため、この設定にかかわらず名前・よみ・別名から登録済み候補を表示します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Label(
                    purchaseManager.currentPlan.includesLocalFullFeatures
                        ? "高度OCRの項目候補を利用できます"
                        : "高度OCRの項目候補はPro以上",
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
    @AppStorage(AppStorageKeys.showsExternalCalendarEvents) private var showsExternalCalendarEvents = true
    @AppStorage(AppStorageKeys.selectedExternalCalendarIdentifiers) private var selectedExternalCalendarIdentifiers = ""
    @StateObject private var externalCalendarStore = ExternalCalendarOverlayStore()
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
                Toggle("カレンダー画面に重ねて表示", isOn: $showsExternalCalendarEvents)
                LabeledContent("読み取り許可", value: externalCalendarStore.authorizationStatusText)

                if !externalCalendarStore.canReadEvents {
                    Button {
                        Task {
                            await externalCalendarStore.requestAccessAndLoadSources()
                        }
                    } label: {
                        Label("カレンダーの読み取りを許可", systemImage: "calendar.badge.plus")
                    }
                } else {
                    HStack {
                        Button("すべて選択") {
                            selectedExternalCalendarIdentifiers = ""
                        }
                        Spacer()
                        Button("すべて解除") {
                            selectedExternalCalendarIdentifiers = ExternalCalendarSelection.rawValue(for: [])
                        }
                    }
                    .font(FavorecoTypography.captionStrong)

                    if externalCalendarStore.calendarSources.isEmpty {
                        Text("読み取り可能なカレンダーがありません。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(externalCalendarStore.calendarSources) { source in
                            Toggle(isOn: calendarSourceBinding(source)) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(uiColor: source.color))
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.title)
                                            .font(FavorecoTypography.bodyStrong)
                                        Text(source.accountTitle)
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(!showsExternalCalendarEvents)
                        }
                    }
                }

                Text("GoogleカレンダーもiOS標準カレンダーに登録済みなら、アカウント名とカレンダー名を確認して読み込む対象を選べます。未選択のカレンダーはFavorecoへ表示しません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if !externalCalendarStore.errorMessage.isEmpty {
                    Text(externalCalendarStore.errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("セキュリティ") {
                Text("パスワード本体はSwiftData/CloudKitに保存しません。必要になった場合のみKeychain参照キーを使い、Face ID/Touch ID/端末パスコードで表示・コピーします。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("登録情報・連携")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            externalCalendarStore.updateAuthorizationStatus()
            externalCalendarStore.reloadCalendarSources()
        }
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

    private func calendarSourceBinding(_ source: ExternalCalendarSource) -> Binding<Bool> {
        Binding(
            get: {
                ExternalCalendarSelection.identifiers(from: selectedExternalCalendarIdentifiers)?
                    .contains(source.id) ?? true
            },
            set: { isSelected in
                var identifiers = ExternalCalendarSelection.identifiers(
                    from: selectedExternalCalendarIdentifiers
                ) ?? Set(externalCalendarStore.calendarSources.map(\.id))
                if isSelected {
                    identifiers.insert(source.id)
                } else {
                    identifiers.remove(source.id)
                }
                selectedExternalCalendarIdentifiers = ExternalCalendarSelection.rawValue(for: identifiers)
            }
        )
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
