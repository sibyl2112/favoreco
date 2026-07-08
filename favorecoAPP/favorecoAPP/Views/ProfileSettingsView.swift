//
//  ProfileSettingsView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]

    private var activeAccounts: [SocialAccount] {
        socialAccounts
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    var body: some View {
        List {
            Section("プロフィール") {
                LabeledContent("表示名", value: "未設定")
                Text("アイコンと表示名は次の実装で編集できるようにします。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    EditSocialAccountView(account: nil)
                } label: {
                    Label("SNSを追加", systemImage: "plus.circle.fill")
                }
            }

            Section("SNS") {
                if activeAccounts.isEmpty {
                    Text("SNSはまだ登録されていません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeAccounts) { account in
                        SocialAccountRow(account: account) {
                            if let url = SocialPlatform.platform(for: account.platformKey).url(from: account.accountInput) {
                                openURL(url)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("プロフィール")
    }
}

private struct SocialAccountRow: View {
    let account: SocialAccount
    let open: () -> Void

    private var platform: SocialPlatform {
        SocialPlatform.platform(for: account.platformKey)
    }

    private var title: String {
        if !account.label.isEmpty {
            return account.label
        }
        return platform.displayName
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Label(platform.displayName, systemImage: platform.symbolName)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)

                        if let category = account.category {
                            Text(category.name)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(Color(hex: category.colorHex))
                        }
                    }

                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)

                    if !account.accountInput.isEmpty {
                        Text(account.accountInput)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !account.memo.isEmpty {
                        Text(account.memo)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            NavigationLink {
                EditSocialAccountView(account: account)
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("SNSを編集")
        }
        .padding(.vertical, 4)
    }
}

struct EditSocialAccountView: View {
    let account: SocialAccount?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var draft: SocialAccountDraft

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    init(account: SocialAccount?) {
        self.account = account
        _draft = State(initialValue: SocialAccountDraft(account: account))
    }

    var body: some View {
        Form {
            Section("SNS") {
                Picker("種類", selection: $draft.platformKey) {
                    ForEach(SocialPlatform.allCases) { platform in
                        Text(platform.displayName).tag(platform.rawValue)
                    }
                }

                TextField("メモ / 名前（任意）", text: $draft.label)
                TextField(SocialPlatform.platform(for: draft.platformKey).placeholder, text: $draft.accountInput)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("ジャンル") {
                Picker("紐付け", selection: $draft.categoryID) {
                    Text("全体プロフィール").tag(UUID?.none)
                    ForEach(visibleCategories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
            }

            Section("メモ") {
                TextField("用途や名義など", text: $draft.memo, axis: .vertical)
                    .lineLimit(2...4)
            }

            if account != nil {
                Section {
                    Button(role: .destructive) {
                        archive()
                    } label: {
                        Label("このSNSを削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(account == nil ? "SNSを追加" : "SNSを編集")
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
                .disabled(!draft.canSave)
            }
        }
    }

    private func save() {
        let now = Date()
        let selectedCategory = visibleCategories.first { $0.id == draft.categoryID }

        if let account {
            account.platformKey = draft.platformKey
            account.label = draft.trimmedLabel
            account.accountInput = draft.trimmedAccountInput
            account.memo = draft.trimmedMemo
            account.category = selectedCategory
            account.updatedAt = now
        } else {
            let descriptor = FetchDescriptor<SocialAccount>()
            let count = (try? modelContext.fetchCount(descriptor)) ?? 0
            modelContext.insert(SocialAccount(
                platformKey: draft.platformKey,
                label: draft.trimmedLabel,
                accountInput: draft.trimmedAccountInput,
                memo: draft.trimmedMemo,
                sortOrder: count + 1,
                createdAt: now,
                updatedAt: now,
                category: selectedCategory
            ))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save social account: \(error)")
        }
    }

    private func archive() {
        guard let account else { return }
        account.isArchived = true
        account.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to archive social account: \(error)")
        }
    }
}

private struct SocialAccountDraft {
    var platformKey = SocialPlatform.instagram.rawValue
    var label = ""
    var accountInput = ""
    var memo = ""
    var categoryID: UUID?

    init(account: SocialAccount?) {
        guard let account else { return }
        platformKey = account.platformKey
        label = account.label
        accountInput = account.accountInput
        memo = account.memo
        categoryID = account.category?.id
    }

    var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAccountInput: String {
        accountInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedAccountInput.isEmpty
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
