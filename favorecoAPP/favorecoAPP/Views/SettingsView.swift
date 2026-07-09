//
//  SettingsView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

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
                    Button {
                        insertDebugData()
                    } label: {
                        Label("写真付き仮データを追加", systemImage: "hammer.fill")
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
            try DebugDataSeeder.insertSampleData(in: modelContext)
            debugMessage = "仮データを追加しました。"
        } catch {
            debugMessage = "仮データの追加に失敗しました。"
            assertionFailure("Failed to insert debug data: \(error)")
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
                    Text("85%").tag(0.85)
                    Text("65%").tag(0.65)
                }

                LabeledContent("メタデータ削除", value: "ON")
            }

            Section("入力補助") {
                Toggle("URL取込候補", isOn: $usesURLImportAssist)
                Toggle("OCR取込", isOn: $usesOCRImportAssist)
                Toggle("Map検索", isOn: $usesMapSearchAssist)
                Toggle("天気自動付与", isOn: $usesWeatherAutoFill)
                Toggle("入力補助辞書", isOn: $usesInputSuggestionDictionary)
            }

            Section("後日検討") {
                LabeledContent("Apple Music連携", value: "V2以降で検討")
            }
        }
        .navigationTitle("記録・入力補助")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Form {
            Section("通知") {
                Toggle("通知を有効化", isOn: .constant(false))
                    .disabled(true)
                LabeledContent("状態", value: "準備中")
            }

            Section("予定・チケット") {
                LabeledContent("申込開始", value: "準備中")
                LabeledContent("申込締切", value: "準備中")
                LabeledContent("当落発表", value: "準備中")
                LabeledContent("入金締切", value: "準備中")
                LabeledContent("発券開始", value: "準備中")
                LabeledContent("公演前日/当日", value: "準備中")
            }

            Section("アカウント") {
                LabeledContent("FC・会員期限", value: "準備中")
            }

            Section("思い出") {
                LabeledContent("思い出リマインダー", value: "準備中")
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
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
    @Query private var categories: [RecordCategory]
    @Query private var events: [ExperienceEvent]
    @Query private var visits: [Visit]
    @Query private var inboxItems: [InboxItem]
    @Query private var photos: [PhotoBlob]

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
                    SettingsDocumentView(title: "JSONエクスポート", bodyText: "アプリに戻せるバックアップ形式として準備予定です。写真データは別扱いにします。")
                } label: {
                    Label("JSONエクスポート", systemImage: "square.and.arrow.up")
                }

                NavigationLink {
                    SettingsDocumentView(title: "CSVエクスポート", bodyText: "表計算アプリで開ける形式として準備予定です。ジャンル横断とジャンル別の両方を検討します。")
                } label: {
                    Label("CSVエクスポート", systemImage: "tablecells")
                }

                NavigationLink {
                    SettingsDocumentView(title: "JSONインポート", bodyText: "バックアップから復元する入口として準備予定です。既存データを壊さない取り込み方式にします。")
                } label: {
                    Label("JSONインポート", systemImage: "square.and.arrow.down")
                }

                NavigationLink {
                    SettingsDocumentView(title: "CSVインポート", bodyText: "date, category, title, venue, memo などからまとめて取り込む入口として準備予定です。")
                } label: {
                    Label("CSVインポート", systemImage: "tray.and.arrow.down")
                }
            }

            Section("バックアップについて") {
                Text("記録はこの端末に保存されています。アプリを削除すると端末内のデータも削除されるため、将来はJSONエクスポートでバックアップできるようにします。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
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
                NavigationLink {
                    SettingsDocumentView(title: "アップグレード", bodyText: "買い切り、サブスク、カテゴリDBパックの見せ方を整理してから実装します。")
                } label: {
                    Label("アップグレード", systemImage: "crown")
                }
                Button {
                } label: {
                    Label("購入を復元", systemImage: "arrow.clockwise")
                }
                .disabled(true)
            }

            Section("プラン管理") {
                NavigationLink {
                    SettingsDocumentView(title: "Pro機能一覧", bodyText: "統計、年間まとめ、エクスポート、自作カテゴリ、同期、自動バックアップ、参照DBなどを整理して掲載予定です。")
                } label: {
                    Label("Pro機能一覧", systemImage: "sparkles")
                }

                NavigationLink {
                    SettingsDocumentView(title: "DBパック管理", bodyText: "御朱印、100名城、御船印などのカテゴリDBパックを管理する入口として準備予定です。")
                } label: {
                    Label("DBパック管理", systemImage: "shippingbox")
                }
            }
        }
        .navigationTitle("課金・プラン")
        .navigationBarTitleDisplayMode(.inline)
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
