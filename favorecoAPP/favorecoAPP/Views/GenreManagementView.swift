//
//  GenreManagementView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct GenreManagementView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedGenreOnboarding) private var hasCompletedGenreOnboarding = false
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var warningMessage = ""
    @State private var isShowingAddGenre = false
    @State private var isShowingPlans = false

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

            Section {
                Button {
                    hasCompletedGenreOnboarding = false
                    dismiss()
                } label: {
                    Label("ジャンル選択をやり直す", systemImage: "checklist")
                }
            } footer: {
                Text("初回設定と同じ画面で、記録するジャンルを選び直します。既存の記録は削除されません。")
            }
        }
        .navigationTitle("ジャンル管理")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if purchaseManager.currentPlan.canCreateCustomGenres {
                        isShowingAddGenre = true
                    } else {
                        isShowingPlans = true
                    }
                } label: {
                    Image(systemName: purchaseManager.currentPlan.canCreateCustomGenres ? "plus" : "lock.fill")
                }
                .accessibilityLabel(
                    purchaseManager.currentPlan.canCreateCustomGenres
                        ? "自作ジャンルを追加"
                        : "自作ジャンルは同期プランまたは完全買い切り"
                )
            }
        }
        .sheet(isPresented: $isShowingAddGenre) {
            AddCustomGenreView()
        }
        .sheet(isPresented: $isShowingPlans) {
            NavigationStack {
                BillingPlanSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { isShowingPlans = false }
                        }
                    }
            }
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
                if !category.isBuiltIn {
                    Text("自作")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct GenreDetailSettingsView: View {
    let category: RecordCategory

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]
    @State private var draft: GenreDetailDraft
    @State private var warningMessage = ""
    @State private var isShowingRemoveConfirmation = false
    @State private var isShowingPlans = false

    private var linkedSocialAccounts: [SocialAccount] {
        socialAccounts
            .filter { !$0.isArchived && $0.category?.id == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var enabledUnits: [RecordUnitDefinition] {
        RecordUnitDefinition.definitions(for: category.enabledUnitsRaw)
    }

    private var linkedRecordCount: Int {
        (category.events?.count ?? 0) + (category.plans?.count ?? 0) + (category.socialAccounts?.count ?? 0)
    }

    private var removalActionName: String {
        linkedRecordCount == 0 ? "完全に削除" : "非表示にする"
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

                Picker("テンプレタイプ", selection: $draft.templateTypeKey) {
                    ForEach(CustomGenreTemplateType.all) { type in
                        Text(type.name).tag(type.id)
                    }
                }

                TextField("対象名ラベル", text: $draft.targetNameLabel)
                TextField("記録単位の呼び名", text: $draft.recordUnitName)
                TextField("日付ラベル", text: $draft.dateLabel)
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
                ForEach(RecordUnitDefinition.all) { unit in
                    UnitToggleRow(
                        unit: unit,
                        isSelected: draft.selectedUnitIDs.contains(unit.id)
                    ) {
                        draft.toggleUnit(unit.id)
                    }
                    .disabled(unit.isRequired)
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

            Section("ジャンル管理") {
                Button {
                    if purchaseManager.currentPlan.canCreateCustomGenres {
                        duplicateAsCustomGenre()
                    } else {
                        isShowingPlans = true
                    }
                } label: {
                    Label(
                        purchaseManager.currentPlan.canCreateCustomGenres ? "この設定を複製" : "複製は同期プラン以上",
                        systemImage: purchaseManager.currentPlan.canCreateCustomGenres ? "plus.square.on.square" : "lock.fill"
                    )
                }

                if !category.isBuiltIn {
                    Button(role: .destructive) {
                        isShowingRemoveConfirmation = true
                    } label: {
                        Label(removalActionName, systemImage: linkedRecordCount == 0 ? "trash" : "archivebox")
                    }

                    if linkedRecordCount > 0 {
                        Text("記録・予定・SNS紐付けがあるため、データを守るため完全削除せず非表示にします。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
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
        .confirmationDialog(
            linkedRecordCount == 0 ? "自作ジャンルを削除しますか？" : "自作ジャンルを非表示にしますか？",
            isPresented: $isShowingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(removalActionName, role: .destructive) {
                removeCustomGenre()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if linkedRecordCount == 0 {
                Text("この操作は取り消せません。")
            } else {
                Text("紐づくデータは削除されません。ジャンル管理から再表示できます。")
            }
        }
        .sheet(isPresented: $isShowingPlans) {
            NavigationStack {
                BillingPlanSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { isShowingPlans = false }
                        }
                    }
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
        category.templateTypeKey = draft.templateTypeKey
        category.targetNameLabel = draft.trimmedTargetNameLabel
        category.recordUnitName = draft.trimmedRecordUnitName
        category.dateLabel = draft.trimmedDateLabel
        category.enabledUnitsRaw = draft.enabledUnitsRaw
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

    private func duplicateAsCustomGenre() {
        guard purchaseManager.currentPlan.canCreateCustomGenres else {
            isShowingPlans = true
            return
        }
        warningMessage = ""
        let descriptor = FetchDescriptor<RecordCategory>()
        let allCategories = (try? modelContext.fetch(descriptor)) ?? []
        let now = Date()
        let duplicate = RecordCategory(
            name: uniqueCopyName(baseName: category.name, categories: allCategories),
            iconSymbol: category.iconSymbol,
            colorHex: category.colorHex,
            sortOrder: (allCategories.map(\.sortOrder).max() ?? 0) + 10,
            isBuiltIn: false,
            templateKey: "custom_\(UUID().uuidString)",
            enabledUnitsRaw: category.enabledUnitsRaw,
            templateTypeKey: category.templateTypeKey,
            targetNameLabel: category.targetNameLabel,
            recordUnitName: category.recordUnitName,
            dateLabel: category.dateLabel,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(duplicate)
        do {
            try modelContext.save()
            warningMessage = "「\(duplicate.name)」を追加しました。"
        } catch {
            modelContext.rollback()
            warningMessage = "複製できませんでした。"
        }
    }

    private func uniqueCopyName(baseName: String, categories: [RecordCategory]) -> String {
        let names = Set(categories.map(\.name))
        let first = "\(baseName) コピー"
        guard names.contains(first) else { return first }
        var suffix = 2
        while names.contains("\(first) \(suffix)") {
            suffix += 1
        }
        return "\(first) \(suffix)"
    }

    private func removeCustomGenre() {
        guard !category.isBuiltIn else { return }
        warningMessage = ""

        if linkedRecordCount > 0 {
            if !category.isArchived, (try? activeCategoryCount()) ?? 1 <= 1 {
                warningMessage = "少なくとも1つの表示ジャンルが必要です。"
                return
            }
            category.isArchived = true
            category.updatedAt = Date()
        } else {
            if !category.isArchived, (try? activeCategoryCount()) ?? 1 <= 1 {
                warningMessage = "少なくとも1つの表示ジャンルが必要です。"
                return
            }
            modelContext.delete(category)
        }

        do {
            try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: modelContext)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            warningMessage = "更新できませんでした。"
        }
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

private struct UnitToggleRow: View {
    let unit: RecordUnitDefinition
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
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
        .buttonStyle(.plain)
    }
}

private struct GenreDetailDraft {
    var name: String
    var iconSymbol: String
    var colorHex: String
    var templateTypeKey: String
    var targetNameLabel: String
    var recordUnitName: String
    var dateLabel: String
    var selectedUnitIDs: Set<String>
    var isArchived: Bool

    init(category: RecordCategory) {
        name = category.name
        iconSymbol = category.iconSymbol
        colorHex = category.colorHex
        templateTypeKey = category.templateTypeKey
        targetNameLabel = category.targetNameLabel
        recordUnitName = category.recordUnitName
        dateLabel = category.dateLabel
        selectedUnitIDs = Set(RecordUnitDefinition.definitions(for: category.enabledUnitsRaw).map(\.id))
        selectedUnitIDs.formUnion(RecordUnitDefinition.requiredIDs)
        isArchived = category.isArchived
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIconSymbol: String {
        iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTargetNameLabel: String {
        let value = targetNameLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "対象" : value
    }

    var trimmedRecordUnitName: String {
        let value = recordUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "回" : value
    }

    var trimmedDateLabel: String {
        let value = dateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "日付" : value
    }

    var enabledUnitsRaw: String {
        RecordUnitDefinition.orderedIDs(from: selectedUnitIDs).joined(separator: ",")
    }

    mutating func toggleUnit(_ unitID: String) {
        guard !RecordUnitDefinition.requiredIDs.contains(unitID) else { return }
        if selectedUnitIDs.contains(unitID) {
            selectedUnitIDs.remove(unitID)
        } else {
            selectedUnitIDs.insert(unitID)
        }
        selectedUnitIDs.formUnion(RecordUnitDefinition.requiredIDs)
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

struct AddCustomGenreView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var draft = CustomGenreDraft()

    var body: some View {
        NavigationStack {
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

                Section("テンプレタイプ") {
                    Picker("タイプ", selection: $draft.templateTypeKey) {
                        ForEach(CustomGenreTemplateType.all) { type in
                            Text(type.name).tag(type.id)
                        }
                    }

                    let selectedType = CustomGenreTemplateType.type(for: draft.templateTypeKey)
                    Text(selectedType.description)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Section("呼び名") {
                    TextField("対象名ラベル", text: $draft.targetNameLabel)
                    TextField("記録単位の呼び名", text: $draft.recordUnitName)
                    TextField("日付ラベル", text: $draft.dateLabel)
                }

                Section("使うユニット") {
                    ForEach(RecordUnitDefinition.all) { unit in
                        UnitToggleRow(
                            unit: unit,
                            isSelected: draft.selectedUnitIDs.contains(unit.id)
                        ) {
                            draft.toggleUnit(unit.id)
                        }
                        .disabled(unit.isRequired)
                    }
                }
            }
            .navigationTitle("自作ジャンル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
            .onChange(of: draft.templateTypeKey) { _, newValue in
                draft.applyTemplateType(newValue)
            }
        }
    }

    private func save() {
        guard purchaseManager.currentPlan.canCreateCustomGenres else {
            dismiss()
            return
        }
        let now = Date()
        let maxSortOrder = categories.map(\.sortOrder).max() ?? 0
        let category = RecordCategory(
            name: draft.trimmedName,
            iconSymbol: draft.trimmedIconSymbol,
            colorHex: draft.colorHex,
            sortOrder: maxSortOrder + 10,
            isBuiltIn: false,
            templateKey: "custom_\(UUID().uuidString)",
            enabledUnitsRaw: draft.enabledUnitsRaw,
            templateTypeKey: draft.templateTypeKey,
            targetNameLabel: draft.trimmedTargetNameLabel,
            recordUnitName: draft.trimmedRecordUnitName,
            dateLabel: draft.trimmedDateLabel,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )

        modelContext.insert(category)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save custom genre: \(error)")
        }
    }
}

private struct CustomGenreDraft {
    var name = ""
    var iconSymbol = "sparkles"
    var colorHex = "#147C88"
    var templateTypeKey = "free"
    var targetNameLabel = "対象"
    var recordUnitName = "回"
    var dateLabel = "日付"
    var selectedUnitIDs: Set<String> = ["basic", "photos", "memo"]

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIconSymbol: String {
        let value = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "sparkles" : value
    }

    var trimmedTargetNameLabel: String {
        let value = targetNameLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "対象" : value
    }

    var trimmedRecordUnitName: String {
        let value = recordUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "回" : value
    }

    var trimmedDateLabel: String {
        let value = dateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "日付" : value
    }

    var enabledUnitsRaw: String {
        RecordUnitDefinition.orderedIDs(from: selectedUnitIDs.union(RecordUnitDefinition.requiredIDs)).joined(separator: ",")
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !trimmedIconSymbol.isEmpty
    }

    mutating func toggleUnit(_ unitID: String) {
        guard !RecordUnitDefinition.requiredIDs.contains(unitID) else { return }
        if selectedUnitIDs.contains(unitID) {
            selectedUnitIDs.remove(unitID)
        } else {
            selectedUnitIDs.insert(unitID)
        }
        selectedUnitIDs.formUnion(RecordUnitDefinition.requiredIDs)
    }

    mutating func applyTemplateType(_ typeID: String) {
        let type = CustomGenreTemplateType.type(for: typeID)
        targetNameLabel = type.targetNameLabel
        recordUnitName = type.recordUnitName
        dateLabel = type.dateLabel
        selectedUnitIDs = Set(type.defaultUnitIDs).union(RecordUnitDefinition.requiredIDs)
    }
}

private struct CustomGenreTemplateType: Identifiable {
    let id: String
    let name: String
    let description: String
    let targetNameLabel: String
    let recordUnitName: String
    let dateLabel: String
    let defaultUnitIDs: [String]

    static let all: [CustomGenreTemplateType] = [
        CustomGenreTemplateType(id: "watching", name: "鑑賞系", description: "映画、配信、ゲーム実況、イベント視聴など。作品を見た/体験した記録向け。", targetNameLabel: "作品", recordUnitName: "鑑賞", dateLabel: "鑑賞日", defaultUnitIDs: ["basic", "people", "photos", "importOCR", "officialInfo", "memo"]),
        CustomGenreTemplateType(id: "visiting", name: "訪問系", description: "カフェ、温泉、ショップ、施設など。場所に行った記録向け。", targetNameLabel: "場所", recordUnitName: "訪問", dateLabel: "訪問日", defaultUnitIDs: ["basic", "ticketPlan", "photos", "importOCR", "money", "officialInfo", "memo"]),
        CustomGenreTemplateType(id: "reading", name: "読書系", description: "本、漫画、雑誌、同人誌など。読んだものを残す記録向け。", targetNameLabel: "本", recordUnitName: "読書", dateLabel: "読了日", defaultUnitIDs: ["basic", "people", "photos", "importOCR", "memo"]),
        CustomGenreTemplateType(id: "collection", name: "コレクション系", description: "グッズ、香水、文具、カードなど。所有物や使用感を残す記録向け。", targetNameLabel: "アイテム", recordUnitName: "入手", dateLabel: "入手日", defaultUnitIDs: ["basic", "photos", "money", "officialInfo", "memo", "advanced"]),
        CustomGenreTemplateType(id: "food", name: "飲食系", description: "カフェ、料理、菓子、ドリンクなど。味や店を残す記録向け。", targetNameLabel: "メニュー", recordUnitName: "飲食", dateLabel: "飲食日", defaultUnitIDs: ["basic", "photos", "importOCR", "money", "memo", "advanced"]),
        CustomGenreTemplateType(id: "free", name: "自由", description: "決まった型を持たず、あとから育てるジャンル向け。", targetNameLabel: "対象", recordUnitName: "回", dateLabel: "日付", defaultUnitIDs: ["basic", "photos", "memo"]),
    ]

    static func type(for id: String) -> CustomGenreTemplateType {
        all.first { $0.id == id } ?? all.last!
    }
}

#Preview {
    NavigationStack {
        GenreManagementView()
    }
    .environmentObject(PurchaseManager.shared)
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
