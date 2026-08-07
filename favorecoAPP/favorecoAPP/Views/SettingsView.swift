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
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        NavigationStack {
            List {
                FavorecoSettingsSection("個人情報") {
                    NavigationLink {
                        MySettingsHubView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "プロフィール・連携",
                            detail: "表示名・SNS、FC・チケットサイト、カレンダー",
                            systemImage: "person.crop.circle"
                        )
                    }
                }

                FavorecoSettingsSection("記録・アプリ管理") {
                    NavigationLink {
                        GenreManagementView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "ジャンル設定",
                            detail: "表示順、表示・非表示、色、記録項目",
                            systemImage: "square.grid.2x2"
                        )
                    }

                    NavigationLink {
                        MasterDataSettingsHubView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "マスターデータ",
                            detail: "人物・団体、場所、タグ、同行者",
                            systemImage: "tray.full"
                        )
                    }

                    NavigationLink {
                        AppSettingsHubView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "アプリ設定",
                            detail: "表示、記録の初期値、通知",
                            systemImage: "slider.horizontal.3"
                        )
                    }

                    NavigationLink {
                        DataSyncSettingsHubView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "データと同期",
                            detail: "書き出し、バックアップ、iCloud",
                            systemImage: "externaldrive.badge.icloud"
                        )
                    }
                }

                FavorecoSettingsSection("サービス・情報") {
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
                }

#if DEBUG
                FavorecoSettingsSection("開発用") {
                    NavigationLink {
                        DeveloperSettingsView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "開発者メニュー",
                            detail: "テスト権利、仮データ、通知診断",
                            systemImage: "hammer"
                        )
                    }
                }
#endif
            }
            .favorecoSettingsListLayout()
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
        .favorecoAppAppearance()
        .tint(themePalette.globalTint)
    }
}
