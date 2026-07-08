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

                Section("デバッグ") {
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

#Preview {
    SettingsView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
