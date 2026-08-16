import SwiftUI
import SwiftData

struct AppSettingsHubView: View {
    @AppStorage(AppStorageKeys.showsGenreOnboarding) private var showsGenreOnboarding = false

    var body: some View {
        List {
            FavorecoSettingsSection("表示と記録") {
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
                RecordInputAssistSettingsView()
            } label: {
                SettingsNavigationLabel(
                    title: "記録・入力補助",
                    detail: "初期値、写真圧縮、URL・OCR・Map・天気の補助",
                    systemImage: "wand.and.sparkles"
                )
            }
            }

            FavorecoSettingsSection("お知らせ") {
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

            FavorecoSettingsSection("使い方") {
                FavorecoSettingsToggleRow(
                    title: "オンボーディングを表示",
                    detail: "オンにすると初期案内をもう一度確認できます",
                    isOn: $showsGenreOnboarding
                )
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("アプリ設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSyncSettingsHubView: View {
    var body: some View {
        List {
            FavorecoSettingsSection("データ") {
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
        }
        .favorecoSettingsListLayout()
        .navigationTitle("データと同期")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.debugPlanOverride) private var debugPlanOverride = "storekit"
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var debugHomeCategoryLayout = HomeCategoryLayoutMode.horizontal.rawValue
    @AppStorage(AppStorageKeys.lastSeenReleaseVersion) private var lastSeenReleaseVersion = ""
    @AppStorage(AppStorageKeys.debugForcesLocalStoreRecovery) private var debugForcesLocalStoreRecovery = false
    @State private var debugMessage = ""
    @State private var isMutatingDebugData = false
    @State private var showsRebuildConfirmation = false

    var body: some View {
        Form {
            FavorecoSettingsSection("権利と表示") {
                Picker("テスト権利", selection: $debugPlanOverride) {
                    Text("StoreKit購入結果").tag("storekit")
                    Text("無料版").tag(FavorecoPlan.free.rawValue)
                    Text("Pro").tag(FavorecoPlan.lightLifetime.rawValue)
                    Text("Premium").tag(FavorecoPlan.syncSubscription.rawValue)
                    Text("Premium 永久版").tag(FavorecoPlan.fullLifetime.rawValue)
                }
                .onChange(of: debugPlanOverride) { _, newValue in
                    Task {
                        await purchaseManager.setDebugPlanOverride(FavorecoPlan(rawValue: newValue))
                    }
                }

                LabeledContent("現在の権利", value: purchaseManager.currentPlan.displayName)

                LabeledContent("Pro機能", value: accessLabel(purchaseManager.currentPlan.includesLocalFullFeatures))
                LabeledContent("写真上限", value: photoLimitLabel)
                LabeledContent("自作ジャンル", value: accessLabel(purchaseManager.currentPlan.canCreateCustomGenres))
                LabeledContent("同期", value: accessLabel(purchaseManager.currentPlan.includesSync))

                Picker("Homeジャンル表示", selection: $debugHomeCategoryLayout) {
                    ForEach(HomeCategoryLayoutMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            FavorecoSettingsSection("診断") {
                NavigationLink {
                    NotificationDebugView()
                } label: {
                    Label("チケット・通知診断", systemImage: "bell.badge")
                }

                Button {
                    lastSeenReleaseVersion = ""
                    debugMessage = "アプリを終了して再起動すると、更新案内が表示されます。"
                } label: {
                    FavorecoIconLabel("次回起動で更新案内を表示", systemImage: "sparkles")
                }

                Button {
                    debugForcesLocalStoreRecovery = true
                    debugMessage = "アプリを終了して再起動すると、保存データを変更せず復旧画面を表示します。"
                } label: {
                    Label("次回起動で復旧画面を診断", systemImage: "externaldrive.badge.exclamationmark")
                }
            }

            FavorecoSettingsSection("仮データ") {
                Button(role: .destructive) {
                    showsRebuildConfirmation = true
                } label: {
                    Label("全体験データを削除して再作成", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isMutatingDebugData)

                Button {
                    insertDebugData()
                } label: {
                    Label("ジャンル別ダミーデータを更新", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(isMutatingDebugData)

                Button(role: .destructive) {
                    deleteDebugData()
                } label: {
                    FavorecoIconLabel("仮データを削除", systemImage: "trash")
                }
                .disabled(isMutatingDebugData)

                NavigationLink {
                    FullDataDeletionView()
                } label: {
                    FavorecoIconLabel("全データ削除（テスト）", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }

                if !debugMessage.isEmpty {
                    Text(debugMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if isMutatingDebugData {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("仮データを処理しています…")
                    }
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .favorecoSettingsListLayout()
        .confirmationDialog(
            "マスター以外の体験データを削除しますか？",
            isPresented: $showsRebuildConfirmation,
            titleVisibility: .visible
        ) {
            Button("全削除してダミーデータを作成", role: .destructive) {
                rebuildDebugData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ジャンル・人物・場所などのマスターは残ります。公演・施設・作品、予定、記録、チケット進捗、写真、コレクションは削除されます。")
        }
        .navigationTitle("開発者メニュー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var photoLimitLabel: String {
        guard let limit = purchaseManager.currentPlan.maximumPhotosPerRecord else {
            return "上限なし"
        }
        return "1記録\(limit)枚"
    }

    private func accessLabel(_ isAvailable: Bool) -> String {
        isAvailable ? "利用可能" : "ロック"
    }

    private func insertDebugData() {
        guard !isMutatingDebugData else { return }
        isMutatingDebugData = true
        debugMessage = ""
        Task { @MainActor in
            await Task.yield()
            defer { isMutatingDebugData = false }
            do {
                let summary = try DebugDataSeeder.insertSampleData(in: modelContext)
                debugMessage = summary.insertedMessage
            } catch {
                debugMessage = "ダミーデータの更新に失敗しました。"
                assertionFailure("Failed to insert debug data: \(error)")
            }
        }
    }

    private func rebuildDebugData() {
        guard !isMutatingDebugData else { return }
        isMutatingDebugData = true
        debugMessage = ""
        Task { @MainActor in
            await Task.yield()
            defer { isMutatingDebugData = false }
            do {
                let summary = try DebugDataSeeder.rebuildAllExperienceData(in: modelContext)
                debugMessage = summary.message
            } catch {
                debugMessage = "体験データの再作成に失敗しました。"
                assertionFailure("Failed to rebuild debug data: \(error)")
            }
        }
    }

    private func deleteDebugData() {
        guard !isMutatingDebugData else { return }
        isMutatingDebugData = true
        debugMessage = ""

        Task { @MainActor in
            // ProgressViewを先に描画してからSwiftDataの削除を始める。
            await Task.yield()
            defer { isMutatingDebugData = false }
            do {
                let summary = try DebugDataSeeder.deleteSampleData(in: modelContext)
                debugMessage = summary.deletedMessage
            } catch {
                debugMessage = "仮データの削除に失敗しました。"
                assertionFailure("Failed to delete debug data: \(error)")
            }
        }
    }
}
#endif
