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

                Section("データ管理") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("データ管理", systemImage: "externaldrive")
                    }
                }

                Section("リンク") {
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

                    NavigationLink {
                        SettingsDocumentView(title: "お問い合わせ", bodyText: "お問い合わせ導線は準備中です。不具合報告、ご意見、ご要望を送れる入口にします。")
                    } label: {
                        Label("お問い合わせ", systemImage: "envelope")
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
