//
//  GenreOnboardingView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct GenreOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var selectedTemplateKeys: Set<String> = []

    private var builtInCategories: [RecordCategory] {
        categories.filter(\.isBuiltIn)
    }

    private var hasSelection: Bool {
        !selectedTemplateKeys.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("記録したいジャンルを選んでください")
                            .font(FavorecoTypography.sectionTitle)
                        Text("あとから設定で選び直せます。まずはひとつ以上選んで始めます。")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if builtInCategories.isEmpty {
                    Section {
                        OnboardingEmptyStateRow(
                            icon: "square.grid.2x2",
                            title: "ジャンルを準備中です",
                            message: "標準ジャンルの読み込みが終わると選択できます。"
                        )
                    }
                } else {
                    Section("ジャンル") {
                        ForEach(builtInCategories) { category in
                            GenreSelectionRow(
                                category: category,
                                isSelected: selectedTemplateKeys.contains(category.templateKey)
                            ) {
                                toggle(category)
                            }
                        }
                    }

                    if !hasSelection {
                        Section {
                            Label("何もありません。ひとつ選ぶと開始できます。", systemImage: "exclamationmark.circle")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("初期設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始") {
                        complete()
                    }
                    .disabled(!hasSelection)
                }
            }
            .onAppear {
                if selectedTemplateKeys.isEmpty {
                    selectedTemplateKeys = Set(builtInCategories.map(\.templateKey))
                }
            }
            .onChange(of: builtInCategories.map(\.templateKey)) { _, keys in
                if selectedTemplateKeys.isEmpty {
                    selectedTemplateKeys = Set(keys)
                }
            }
        }
    }

    private func toggle(_ category: RecordCategory) {
        if selectedTemplateKeys.contains(category.templateKey) {
            selectedTemplateKeys.remove(category.templateKey)
        } else {
            selectedTemplateKeys.insert(category.templateKey)
        }
    }

    private func complete() {
        let selectedKeys = selectedTemplateKeys.isEmpty
            ? Set(builtInCategories.prefix(1).map(\.templateKey))
            : selectedTemplateKeys
        let now = Date()

        for category in builtInCategories {
            category.isArchived = !selectedKeys.contains(category.templateKey)
            category.updatedAt = now
        }

        do {
            try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
            try modelContext.save()
            hasCompletedGenreOnboarding = true
        } catch {
            assertionFailure("Failed to save genre onboarding: \(error)")
        }
    }
}

private struct GenreSelectionRow: View {
    let category: RecordCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.iconSymbol)
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 28)

                Text(category.name)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color(hex: category.colorHex) : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingEmptyStateRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    GenreOnboardingView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
