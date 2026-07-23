import SwiftUI
import SwiftData

struct AppSettingsHubView: View {
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

struct DataSyncSettingsHubView: View {
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

    var body: some View {
        Form {
            Section("権利・表示") {
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

                Button {
                    debugForcesLocalStoreRecovery = true
                    debugMessage = "アプリを終了して再起動すると、保存データを変更せず復旧画面を表示します。"
                } label: {
                    Label("次回起動で復旧画面を診断", systemImage: "externaldrive.badge.exclamationmark")
                }
            }

            Section("仮データ") {
                Button {
                    insertDebugData()
                } label: {
                    Label("写真付き仮データを追加", systemImage: "hammer.fill")
                }
                .disabled(isMutatingDebugData)

                Button(role: .destructive) {
                    deleteDebugData()
                } label: {
                    Label("仮データを削除", systemImage: "trash")
                }
                .disabled(isMutatingDebugData)

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
        do {
            let summary = try DebugDataSeeder.insertSampleData(in: modelContext)
            debugMessage = summary.insertedMessage
        } catch {
            debugMessage = "仮データの追加に失敗しました。"
            assertionFailure("Failed to insert debug data: \(error)")
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
