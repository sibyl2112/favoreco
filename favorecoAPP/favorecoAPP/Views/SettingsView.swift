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
                        detail: "表示、ジャンル、記録の初期値、通知",
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
