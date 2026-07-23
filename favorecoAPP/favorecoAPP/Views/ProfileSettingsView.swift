//
//  ProfileSettingsView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ProfileSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]
    @AppStorage(AppStorageKeys.profileDisplayName) private var profileDisplayName = ""
    @AppStorage(AppStorageKeys.profileImageData) private var profileImageData = Data()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var photoErrorMessage = ""

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
        let photoActionTitle = profileImageData.isEmpty ? "写真を選ぶ" : "写真を変更"
        List {
            Section("プロフィール") {
                HStack(spacing: 16) {
                    ProfileAvatarView(data: profileImageData, size: 72)

                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                            Label(photoActionTitle, systemImage: "photo")
                        }

                        if !profileImageData.isEmpty {
                            Button("写真を削除", role: .destructive) {
                                profileImageData = Data()
                            }
                            .font(FavorecoTypography.caption)
                        }
                    }
                }
                .padding(.vertical, 4)

                TextField("表示名（任意）", text: $profileDisplayName)
                    .textInputAutocapitalization(.words)

                if !photoErrorMessage.isEmpty {
                    Text(photoErrorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
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
        .task(id: selectedProfilePhoto) {
            await loadSelectedProfilePhoto()
        }
    }

    @MainActor
    private func loadSelectedProfilePhoto() async {
        guard let selectedProfilePhoto else { return }
        guard let sourceData = try? await selectedProfilePhoto.loadTransferable(type: Data.self),
              let sourceImage = UIImage(data: sourceData),
              let processedData = sourceImage.profileAvatarData else {
            photoErrorMessage = "写真を読み込めませんでした。別の写真を選んでください。"
            return
        }
        profileImageData = processedData
        photoErrorMessage = ""
    }
}

struct ProfileAvatarView: View {
    let data: Data
    var size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private extension UIImage {
    var profileAvatarData: Data? {
        guard size.width > 0, size.height > 0 else { return nil }
        let outputSize = CGSize(width: 320, height: 320)
        let scale = max(outputSize.width / size.width, outputSize.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: (outputSize.width - drawSize.width) / 2,
            y: (outputSize.height - drawSize.height) / 2
        )
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let redrawn = renderer.image { _ in
            draw(in: CGRect(origin: origin, size: drawSize))
        }
        return redrawn.jpegData(compressionQuality: 0.82)
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
