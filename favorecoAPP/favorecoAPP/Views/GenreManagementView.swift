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
        categories
            .filter(shouldShowInManagement)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeCategoryCount: Int {
        sortedCategories.filter { !$0.isArchived }.count
    }

    private func shouldShowInManagement(_ category: RecordCategory) -> Bool {
        guard category.isBuiltIn else { return true }
        if CategoryPresetSeeder.isInitialReleaseTemplate(category.templateKey) {
            return true
        }
        if !category.isArchived {
            return true
        }
        return !(category.events ?? []).isEmpty
            || !(category.plans ?? []).isEmpty
            || !(category.socialAccounts ?? []).isEmpty
    }

    var body: some View {
        List {
            if !warningMessage.isEmpty {
                Section {
                    FavorecoSettingsInfoCallout(
                        title: "変更できませんでした",
                        message: warningMessage
                    )
                }
            }

            FavorecoSettingsSection("表示するジャンル") {
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

            FavorecoSettingsSectionWithFooter("ジャンル選択") {
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
        .favorecoSettingsListLayout()
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
                    FavorecoIcon(
                        systemName: purchaseManager.currentPlan.canCreateCustomGenres ? "plus" : "lock.fill",
                        size: 16
                    )
                }
                .accessibilityLabel(
                    purchaseManager.currentPlan.canCreateCustomGenres
                        ? "自作ジャンルを追加"
                        : "自作ジャンルはPremiumで利用できます"
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
            FavorecoIcon(
                systemName: PhosphorIconGlyph.categorySystemName(
                    templateKey: category.templateKey,
                    storedSystemName: category.iconSymbol
                ),
                size: 20
            )
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
    @State private var isShowingResetConfirmation = false
    @State private var isShowingPlans = false

    private var linkedSocialAccounts: [SocialAccount] {
        socialAccounts
            .filter { !$0.isArchived && $0.category?.id == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var formSettingItems: [GenreFormSettingItem] {
        GenreFormSettingItem.items(for: category)
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
            if category.isBuiltIn {
                FavorecoSettingsSection("表示とデザイン") {
                    FavorecoSettingsToggleRow(
                        title: "このジャンルを表示",
                        detail: "Homeとジャンル切り替えに表示します",
                        isOn: Binding(
                            get: { !draft.isArchived },
                            set: { draft.isArchived = !$0 }
                        )
                    )

                    GenreThemeColorPickerLink(selection: $draft.colorHex)
                }
            } else {
                FavorecoSettingsSection("表示とデザイン") {
                    FavorecoSettingsToggleRow(
                        title: "このジャンルを表示",
                        detail: "Homeとジャンル切り替えに表示します",
                        isOn: Binding(
                            get: { !draft.isArchived },
                            set: { draft.isArchived = !$0 }
                        )
                    )

                    GenreLabeledTextField(
                        title: "表示名",
                        prompt: "例：カフェ巡り",
                        text: $draft.name
                    )

                    CustomGenreIconPickerLink(selection: $draft.iconSymbol)

                    GenreThemeColorPickerLink(selection: $draft.colorHex)
                }

                FavorecoSettingsSection("記録の型と呼び名") {
                    ExplicitFormControlRow(title: "記録の型") {
                        Picker("記録の型", selection: $draft.templateTypeKey) {
                            ForEach(CustomGenreTemplateType.all) { type in
                                Text(type.name).tag(type.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    let selectedType = CustomGenreTemplateType.type(for: draft.templateTypeKey)
                    FavorecoSettingsInfoCallout(
                        title: "この型で使う構造",
                        message: selectedType.description
                    )

                    GenreLabeledTextField(
                        title: "記録対象の呼び名",
                        prompt: "例：作品・場所",
                        text: $draft.targetNameLabel
                    )
                    GenreLabeledTextField(
                        title: "1回の記録の呼び名",
                        prompt: "例：鑑賞・訪問",
                        text: $draft.recordUnitName
                    )
                    GenreLabeledTextField(
                        title: "日付項目の呼び名",
                        prompt: "例：鑑賞日・訪問日",
                        text: $draft.dateLabel
                    )
                }
            }

            FavorecoSettingsSection("記録フォーム") {
                FavorecoSettingsInfoCallout(
                    title: "このジャンルで入力する項目",
                    message: "現在の(category.name)登録フォームに合わせています。常に使用する項目は非表示にできません。"
                )

                ForEach(formSettingItems) { item in
                    let isSelected = draft.isSelected(item)
                    FavorecoSettingsSelectionRow(
                        title: item.title,
                        detail: item.detail,
                        status: item.isFixed ? "常に使用" : (isSelected ? "表示する" : "表示しない"),
                        isSelected: isSelected,
                        isLocked: item.isFixed
                    ) {
                        draft.set(item, isSelected: !isSelected)
                    }
                }
            }

            FavorecoSettingsSection("SNS連携") {
                if linkedSocialAccounts.isEmpty {
                    Text("このジャンルに紐付いたSNSはありません。プロフィール > SNSでジャンルを指定できます。")
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(linkedSocialAccounts) { account in
                        let platform = SocialPlatform.platform(for: account.platformKey)
                        FavorecoIconLabel(
                            account.label.isEmpty ? account.accountInput : account.label,
                            systemImage: platform.symbolName
                        )
                    }
                }
            }

            FavorecoSettingsSection("ジャンル管理") {
                Button {
                    if purchaseManager.currentPlan.canCreateCustomGenres {
                        duplicateAsCustomGenre()
                    } else {
                        isShowingPlans = true
                    }
                } label: {
                    Label(
                        purchaseManager.currentPlan.canCreateCustomGenres
                            ? (category.isBuiltIn ? "自作ジャンルとして複製" : "この設定を複製")
                            : "複製はPremium限定",
                        systemImage: purchaseManager.currentPlan.canCreateCustomGenres ? "plus.square.on.square" : "lock.fill"
                    )
                }

                if category.isBuiltIn {
                    Button {
                        isShowingResetConfirmation = true
                    } label: {
                        Label("標準設定に戻す", systemImage: "arrow.counterclockwise")
                    }

                    Text("テーマカラーと使用する記録項目を、このジャンルの初期設定へ戻します。")
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                }

                if !category.isBuiltIn {
                    Button(role: .destructive) {
                        isShowingRemoveConfirmation = true
                    } label: {
                        FavorecoIconLabel(
                            removalActionName,
                            systemImage: linkedRecordCount == 0 ? "trash" : "archivebox"
                        )
                    }

                    if linkedRecordCount > 0 {
                        Text("記録・予定・SNS紐付けがあるため、データを守るため完全削除せず非表示にします。")
                            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                    }
                }

                if !warningMessage.isEmpty {
                    FavorecoSettingsInfoCallout(
                        title: "確認",
                        message: warningMessage
                    )
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
        .confirmationDialog(
            "標準設定に戻しますか？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("標準設定に戻す") {
                resetToPreset()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("テーマカラーと使用する記録項目を初期設定へ戻します。記録、SNS、表示設定は変更しません。")
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

        category.colorHex = draft.colorHex
        category.enabledUnitsRaw = draft.enabledUnitsRaw
        category.isArchived = draft.isArchived
        category.updatedAt = Date()

        if !category.isBuiltIn {
            category.name = draft.trimmedName
            category.iconSymbol = draft.trimmedIconSymbol
            category.templateTypeKey = draft.templateTypeKey
            category.targetNameLabel = draft.trimmedTargetNameLabel
            category.recordUnitName = draft.trimmedRecordUnitName
            category.dateLabel = draft.trimmedDateLabel
        }

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

    private func resetToPreset() {
        guard category.isBuiltIn,
              let preset = CategoryPresetSeeder.presets.first(where: { $0.templateKey == category.templateKey }) else {
            return
        }

        draft.resetEditableSettings(to: preset)
        category.colorHex = preset.colorHex
        category.enabledUnitsRaw = preset.enabledUnitsRaw
        category.updatedAt = Date()

        do {
            try modelContext.save()
            warningMessage = "標準設定に戻しました。"
        } catch {
            modelContext.rollback()
            draft = GenreDetailDraft(category: category)
            warningMessage = "標準設定に戻せませんでした。"
        }
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
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
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
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct GenreLabeledTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        ExplicitFormTextField(
            title: title,
            prompt: prompt,
            text: $text,
            focusesFromWholeRow: true
        )
    }
}

private struct GenreThemeColorPickerLink: View {
    @Binding var selection: String

    private var selectedName: String {
        GenreThemeColorPreset.preset(for: selection)?.name ?? "現在の色"
    }

    var body: some View {
        NavigationLink {
            GenreThemeColorSelectionView(selection: $selection)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ExplicitFormFieldTitle(title: "テーマカラー", isOptional: false, isRequired: false)
                HStack(spacing: 10) {
                    Spacer()
                    Circle()
                        .fill(Color(hex: selection))
                        .overlay {
                            Circle()
                                .stroke(.primary.opacity(0.16), lineWidth: 0.5)
                        }
                        .frame(width: 22, height: 22)
                    Text(selectedName)
                        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 27)
                .padding(.trailing, ExplicitFormMetrics.controlTrailingPadding)
            }
            .padding(.top, ExplicitFormMetrics.rowTopPadding)
            .padding(.bottom, ExplicitFormMetrics.rowBottomPadding)
            .frame(minHeight: ExplicitFormMetrics.rowMinimumHeight, alignment: .topLeading)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

private struct GenreThemeColorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    var body: some View {
        List(GenreThemeColorPreset.all) { preset in
            Button {
                selection = preset.hex
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .overlay {
                            Circle()
                                .stroke(.primary.opacity(0.16), lineWidth: 0.5)
                        }
                        .frame(width: 28, height: 28)

                    Text(preset.name)
                        .foregroundStyle(.primary)

                    Spacer()

                    if preset.hex.caseInsensitiveCompare(selection) == .orderedSame {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(preset.name)を選択")
            .accessibilityAddTraits(
                preset.hex.caseInsensitiveCompare(selection) == .orderedSame ? .isSelected : []
            )
        }
        .navigationTitle("テーマカラー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CustomGenreIconPickerLink: View {
    @Binding var selection: String

    private var selectedName: String {
        CustomGenreIconPreset.preset(for: selection)?.name ?? "選択中"
    }

    var body: some View {
        NavigationLink {
            CustomGenreIconSelectionView(selection: $selection)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ExplicitFormFieldTitle(title: "アイコン", isOptional: false, isRequired: false)
                HStack(spacing: 10) {
                    Spacer()
                    FavorecoIcon(systemName: selection, size: 20)
                        .frame(width: 24, height: 24)
                    Text(selectedName)
                        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 27)
                .padding(.trailing, ExplicitFormMetrics.controlTrailingPadding)
            }
            .padding(.top, ExplicitFormMetrics.rowTopPadding)
            .padding(.bottom, ExplicitFormMetrics.rowBottomPadding)
            .frame(minHeight: ExplicitFormMetrics.rowMinimumHeight, alignment: .topLeading)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

private struct CustomGenreIconSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CustomGenreIconPreset.all) { preset in
                    let isSelected = preset.systemName == selection
                    Button {
                        selection = preset.systemName
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            FavorecoIcon(systemName: preset.systemName, size: 24)
                                .frame(width: 32, height: 32)
                            Text(preset.name)
                                .font(FavorecoTypography.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.secondary.opacity(0.16),
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.name)アイコン")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(16)
        }
        .navigationTitle("アイコン")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CustomGenreIconPreset: Identifiable {
    let id: String
    let name: String
    let systemName: String

    static let all: [CustomGenreIconPreset] = [
        .init(id: "sparkles", name: "きらめき", systemName: "sparkles"),
        .init(id: "heart", name: "ハート", systemName: "heart.fill"),
        .init(id: "star", name: "スター", systemName: "star"),
        .init(id: "camera", name: "カメラ", systemName: "camera.fill"),
        .init(id: "photo", name: "写真", systemName: "photo.fill"),
        .init(id: "palette", name: "アート", systemName: "paintpalette.fill"),
        .init(id: "theater", name: "舞台", systemName: "theatermasks.fill"),
        .init(id: "music", name: "音楽", systemName: "music.mic"),
        .init(id: "movie", name: "映像", systemName: "movieclapper.fill"),
        .init(id: "book", name: "本", systemName: "books.vertical.fill"),
        .init(id: "wine", name: "ドリンク", systemName: "wineglass.fill"),
        .init(id: "ticket", name: "チケット", systemName: "ticket.fill"),
        .init(id: "paw", name: "いきもの", systemName: "pawprint.fill"),
        .init(id: "seal", name: "印", systemName: "seal.fill"),
        .init(id: "box", name: "コレクション", systemName: "shippingbox.fill"),
        .init(id: "map", name: "場所", systemName: "mappin"),
        .init(id: "tag", name: "タグ", systemName: "tag.fill"),
        .init(id: "castle", name: "施設", systemName: "castle.turret"),
    ]

    static func preset(for systemName: String) -> CustomGenreIconPreset? {
        all.first { $0.systemName == systemName }
    }
}

private struct GenreFormSettingItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let storageIDs: Set<String>
    let isFixed: Bool

    static func items(for category: RecordCategory) -> [GenreFormSettingItem] {
        switch category.templateKey {
        case "book":
            return [
                fixed("bookInfo", "本の情報", "書名、シリーズ・巻数・著者、本の種類"),
                fixed("bookReading", "読書の記録", "読み始めた日、読み終えた日、評価"),
                fixed("photos", "写真", "この読書記録に残す写真"),
                fixed("memo", "読書メモ", "感想や残しておきたいこと"),
            ]
        case "random_goods":
            return [
                fixed("series", "シリーズ情報", "シリーズ名、種類、メーカー、発売時期"),
                fixed("lineup", "ラインナップ", "種類ごとの名前、画像、収集対象"),
                fixed("transaction", "入手・手放し", "購入、交換、譲渡、売却などの履歴"),
                fixed("goodsDetails", "写真・金額・公式情報", "画像、支出、参考リンク"),
            ]
        case "theater":
            return [
                fixed("basic", "参加日・会場", "鑑賞日、開演・終演、鑑賞方法、会場"),
                fixed("theaterRating", "評価", "この回の満足度"),
                configurable("ticketPlan", "鑑賞記録", "チケット状態、座席、お目当て・注目した人", ["ticketPlan", "people"]),
                configurable("photos", "写真・アイキャッチ", "この回のアイキャッチと観劇写真"),
                fixed("memo", "感想・感情タグ", "感想、感情タグ、その他のタグ"),
                configurable("money", "集計記録", "チケット代などの金額"),
                configurable("importOCR", "読み取り情報", "OCRで取得した原文"),
                configurable("officialInfo", "公演公式情報", "公式URL、SNS、参考リンク"),
            ]
        default:
            return genericItems(for: category)
        }
    }

    private static func genericItems(for category: RecordCategory) -> [GenreFormSettingItem] {
        let definitions: [RecordUnitDefinition]
        if category.isBuiltIn,
           let preset = CategoryPresetSeeder.presets.first(where: { $0.templateKey == category.templateKey }) {
            definitions = RecordUnitDefinition.definitions(for: preset.enabledUnitsRaw)
        } else {
            definitions = RecordUnitDefinition.all
        }

        return definitions.map { definition in
            let presentation = presentation(for: definition, templateKey: category.templateKey)
            return GenreFormSettingItem(
                id: definition.id,
                title: presentation.title,
                detail: presentation.detail,
                storageIDs: [definition.id],
                isFixed: definition.isRequired
            )
        }
    }

    private static func presentation(
        for definition: RecordUnitDefinition,
        templateKey: String
    ) -> (title: String, detail: String) {
        guard definition.id == "basic" || definition.id == "memo" else {
            return (definition.name, definition.description)
        }

        switch (templateKey, definition.id) {
        case ("movie", "basic"): ("作品・鑑賞情報", "作品区分、タイトル、鑑賞日、映画館、評価")
        case ("movie", "memo"): ("感想・メモ", "作品の感想や残しておきたいこと")
        case ("museum", "basic"): ("展示・鑑賞情報", "展示名、鑑賞日、会場、評価")
        case ("live", "basic"): ("ライブ・参加情報", "ライブ名、参加日、会場、評価")
        case ("theme_park", "basic"), ("nature_living", "basic"), ("outing_facility", "basic"):
            ("施設・訪問情報", "施設名、訪問日、場所、評価")
        case ("sake", "basic"): ("お酒・記録情報", "銘柄、飲んだ日、場所、評価")
        case ("goshuin", "basic"): ("参拝情報", "参拝先、参拝日、場所")
        default: (definition.name, definition.description)
        }
    }

    private static func fixed(_ id: String, _ title: String, _ detail: String) -> GenreFormSettingItem {
        GenreFormSettingItem(id: id, title: title, detail: detail, storageIDs: [], isFixed: true)
    }

    private static func configurable(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ storageIDs: Set<String>? = nil
    ) -> GenreFormSettingItem {
        GenreFormSettingItem(
            id: id,
            title: title,
            detail: detail,
            storageIDs: storageIDs ?? [id],
            isFixed: false
        )
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

    func isSelected(_ item: GenreFormSettingItem) -> Bool {
        item.isFixed || !selectedUnitIDs.isDisjoint(with: item.storageIDs)
    }

    mutating func set(_ item: GenreFormSettingItem, isSelected: Bool) {
        guard !item.isFixed else { return }
        if isSelected {
            selectedUnitIDs.formUnion(item.storageIDs)
        } else {
            selectedUnitIDs.subtract(item.storageIDs)
        }
        selectedUnitIDs.formUnion(RecordUnitDefinition.requiredIDs)
    }

    mutating func resetEditableSettings(to preset: CategoryPreset) {
        colorHex = preset.colorHex
        selectedUnitIDs = Set(RecordUnitDefinition.definitions(for: preset.enabledUnitsRaw).map(\.id))
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
        GenreThemeColorPreset(id: "sky", name: "スカイ", hex: "#2F7FB8"),
        GenreThemeColorPreset(id: "mauve", name: "モーヴ", hex: "#A65A74"),
    ]

    static func preset(for hex: String) -> GenreThemeColorPreset? {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

struct AddCustomGenreView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var draft = CustomGenreDraft()

    private var formSettingItems: [GenreFormSettingItem] {
        RecordUnitDefinition.all.map { definition in
            GenreFormSettingItem(
                id: definition.id,
                title: definition.name,
                detail: definition.description,
                storageIDs: [definition.id],
                isFixed: definition.isRequired
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                FavorecoSettingsSection("表示とデザイン") {
                    GenreLabeledTextField(
                        title: "表示名",
                        prompt: "例：カフェ巡り",
                        text: $draft.name
                    )
                    CustomGenreIconPickerLink(selection: $draft.iconSymbol)
                    GenreThemeColorPickerLink(selection: $draft.colorHex)
                }

                FavorecoSettingsSection("記録の型と呼び名") {
                    ExplicitFormControlRow(title: "記録の型") {
                        Picker("記録の型", selection: $draft.templateTypeKey) {
                            ForEach(CustomGenreTemplateType.all) { type in
                                Text(type.name).tag(type.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    let selectedType = CustomGenreTemplateType.type(for: draft.templateTypeKey)
                    FavorecoSettingsInfoCallout(
                        title: "この型で使う構造",
                        message: selectedType.description
                    )

                    GenreLabeledTextField(
                        title: "記録対象の呼び名",
                        prompt: "例：作品・場所",
                        text: $draft.targetNameLabel
                    )
                    GenreLabeledTextField(
                        title: "1回の記録の呼び名",
                        prompt: "例：鑑賞・訪問",
                        text: $draft.recordUnitName
                    )
                    GenreLabeledTextField(
                        title: "日付項目の呼び名",
                        prompt: "例：鑑賞日・訪問日",
                        text: $draft.dateLabel
                    )
                }

                FavorecoSettingsSection("記録フォーム") {
                    FavorecoSettingsInfoCallout(
                        title: "このジャンルで入力する項目",
                        message: "記録時に表示するブロックを選びます。基本情報とメモは常に使用します。"
                    )

                    ForEach(formSettingItems) { item in
                        let isSelected = item.isFixed || draft.selectedUnitIDs.contains(item.id)
                        FavorecoSettingsSelectionRow(
                            title: item.title,
                            detail: item.detail,
                            status: item.isFixed ? "常に使用" : (isSelected ? "表示する" : "表示しない"),
                            isSelected: isSelected,
                            isLocked: item.isFixed
                        ) {
                            draft.toggleUnit(item.id)
                        }
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
