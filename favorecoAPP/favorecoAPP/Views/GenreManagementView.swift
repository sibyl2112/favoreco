//
//  GenreManagementView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct GenreManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var warningMessage = ""

    private var sortedCategories: [RecordCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeCategoryCount: Int {
        categories.filter { !$0.isArchived }.count
    }

    var body: some View {
        List {
            if !warningMessage.isEmpty {
                Section {
                    Label(warningMessage, systemImage: "exclamationmark.circle")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("表示ジャンル") {
                ForEach(sortedCategories) { category in
                    HStack(spacing: 12) {
                        NavigationLink {
                            GenreDetailSettingsView(category: category)
                        } label: {
                            GenreManagementRow(category: category)
                        }

                        Button {
                            toggle(category)
                        } label: {
                            Image(systemName: category.isArchived ? "circle" : "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(category.isArchived ? .secondary : Color(hex: category.colorHex))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!category.isArchived && activeCategoryCount <= 1)
                        .accessibilityLabel(category.isArchived ? "表示にする" : "非表示にする")
                    }
                }
                .onMove(perform: moveCategories)
            }
        }
        .navigationTitle("ジャンル管理")
        .toolbar {
            EditButton()
        }
    }

    private func toggle(_ category: RecordCategory) {
        warningMessage = ""

        if !category.isArchived && activeCategoryCount <= 1 {
            warningMessage = "少なくとも1つのジャンルが必要です。"
            return
        }

        category.isArchived.toggle()
        category.updatedAt = Date()

        do {
            try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
            try modelContext.save()
        } catch {
            assertionFailure("Failed to update category visibility: \(error)")
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = sortedCategories
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, category) in reordered.enumerated() {
            category.sortOrder = (index + 1) * 10
            category.updatedAt = Date()
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to reorder categories: \(error)")
        }
    }
}

private struct GenreManagementRow: View {
    let category: RecordCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconSymbol)
                .foregroundStyle(Color(hex: category.colorHex))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(FavorecoTypography.bodyStrong)
                Text(category.isArchived ? "非表示" : "表示中")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct GenreDetailSettingsView: View {
    let category: RecordCategory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]
    @State private var draft: GenreDetailDraft
    @State private var warningMessage = ""

    private var linkedSocialAccounts: [SocialAccount] {
        socialAccounts
            .filter { !$0.isArchived && $0.category?.id == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var enabledUnits: [RecordUnitDefinition] {
        RecordUnitDefinition.definitions(for: category.enabledUnitsRaw)
    }

    init(category: RecordCategory) {
        self.category = category
        _draft = State(initialValue: GenreDetailDraft(category: category))
    }

    var body: some View {
        Form {
            Section("基本") {
                TextField("表示名", text: $draft.name)
                TextField("アイコン", text: $draft.iconSymbol)
                    .textInputAutocapitalization(.never)

                Picker("テーマカラー", selection: $draft.colorHex) {
                    ForEach(GenreThemeColorPreset.all) { preset in
                        Label(preset.name, systemImage: "circle.fill")
                            .foregroundStyle(Color(hex: preset.hex))
                            .tag(preset.hex)
                    }
                }
            }

            Section("SNS") {
                if linkedSocialAccounts.isEmpty {
                    Text("このジャンルに紐付いたSNSはありません。プロフィール > SNSでジャンルを指定できます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linkedSocialAccounts) { account in
                        let platform = SocialPlatform.platform(for: account.platformKey)
                        Label(account.label.isEmpty ? account.accountInput : account.label, systemImage: platform.symbolName)
                    }
                }
            }

            Section("有効ユニット") {
                ForEach(enabledUnits) { unit in
                    UnitRow(unit: unit)
                }
            }

            Section("表示") {
                Toggle("このジャンルを表示", isOn: Binding(
                    get: { !draft.isArchived },
                    set: { draft.isArchived = !$0 }
                ))

                if !warningMessage.isEmpty {
                    Text(warningMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!draft.canSave)
            }
        }
    }

    private func save() {
        warningMessage = ""

        if draft.isArchived && !category.isArchived {
            let activeCount = (try? activeCategoryCount()) ?? 1
            guard activeCount > 1 else {
                warningMessage = "少なくとも1つのジャンルが必要です。"
                return
            }
        }

        category.name = draft.trimmedName
        category.iconSymbol = draft.trimmedIconSymbol
        category.colorHex = draft.colorHex
        category.isArchived = draft.isArchived
        category.updatedAt = Date()

        do {
            try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save category detail: \(error)")
        }
    }

    private func activeCategoryCount() throws -> Int {
        let descriptor = FetchDescriptor<RecordCategory>()
        return try modelContext.fetch(descriptor).filter { !$0.isArchived }.count
    }
}

private struct UnitRow: View {
    let unit: RecordUnitDefinition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: unit.isImplemented ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(unit.isImplemented ? .green : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(unit.name)
                        .font(FavorecoTypography.bodyStrong)
                    if unit.isRequired {
                        Text("必須")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(unit.description)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if !unit.isImplemented {
                    Text("準備中")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GenreDetailDraft {
    var name: String
    var iconSymbol: String
    var colorHex: String
    var isArchived: Bool

    init(category: RecordCategory) {
        name = category.name
        iconSymbol = category.iconSymbol
        colorHex = category.colorHex
        isArchived = category.isArchived
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIconSymbol: String {
        iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !trimmedIconSymbol.isEmpty
    }
}

private struct GenreThemeColorPreset: Identifiable {
    let id: String
    let name: String
    let hex: String

    static let all: [GenreThemeColorPreset] = [
        GenreThemeColorPreset(id: "wine", name: "ワイン", hex: "#8B2F45"),
        GenreThemeColorPreset(id: "sage", name: "セージ", hex: "#7D8C78"),
        GenreThemeColorPreset(id: "teal", name: "ティール", hex: "#147C88"),
        GenreThemeColorPreset(id: "charcoal", name: "チャコール", hex: "#3B3D4A"),
        GenreThemeColorPreset(id: "amber", name: "アンバー", hex: "#B8792F"),
        GenreThemeColorPreset(id: "green", name: "グリーン", hex: "#2E7D60"),
        GenreThemeColorPreset(id: "rose", name: "ローズ", hex: "#A24C55"),
        GenreThemeColorPreset(id: "blue", name: "ブルー", hex: "#536C95"),
    ]
}

#Preview {
    NavigationStack {
        GenreManagementView()
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
