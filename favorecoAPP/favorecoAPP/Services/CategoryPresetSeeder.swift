//
//  CategoryPresetSeeder.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

struct CategoryPreset: Sendable {
    let name: String
    let templateKey: String
    let templateTypeKey: String
    let iconSymbol: String
    let colorHex: String
    let sortOrder: Int
    let enabledUnitsRaw: String
    let targetNameLabel: String
    let recordUnitName: String
    let dateLabel: String
}

enum CategoryPresetSeeder {
    static let seedVersion = 1

    static let initialReleaseTemplateKeys: Set<String> = [
        "theater",
        "movie",
        "live",
        "book",
        "museum",
        "theme_park",
        "nature_living",
    ]

    static func isInitialReleaseTemplate(_ templateKey: String) -> Bool {
        initialReleaseTemplateKeys.contains(templateKey)
    }

    static let presets: [CategoryPreset] = [
        CategoryPreset(
            name: "観劇",
            templateKey: "theater",
            templateTypeKey: "watching",
            iconSymbol: "theatermasks.fill",
            colorHex: "#8B2F45",
            sortOrder: 10,
            enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,money,officialInfo,memo",
            targetNameLabel: "作品・公演",
            recordUnitName: "観劇",
            dateLabel: "観劇日"
        ),
        CategoryPreset(
            name: "ミュージアム",
            templateKey: "museum",
            templateTypeKey: "visiting",
            iconSymbol: "paintpalette.fill",
            colorHex: "#7D8C78",
            sortOrder: 20,
            enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,officialInfo,memo",
            targetNameLabel: "展示・イベント",
            recordUnitName: "鑑賞",
            dateLabel: "鑑賞日"
        ),
        CategoryPreset(
            name: "ライブ",
            templateKey: "live",
            templateTypeKey: "watching",
            iconSymbol: "music.mic",
            colorHex: "#147C88",
            sortOrder: 30,
            enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,money,officialInfo,memo",
            targetNameLabel: "ライブ",
            recordUnitName: "参戦",
            dateLabel: "参戦日"
        ),
        CategoryPreset(
            name: "映像作品",
            templateKey: "movie",
            templateTypeKey: "watching",
            iconSymbol: "movieclapper.fill",
            colorHex: "#3B3D4A",
            sortOrder: 40,
            enabledUnitsRaw: "basic,people,photos,importOCR,officialInfo,memo",
            targetNameLabel: "映像作品",
            recordUnitName: "鑑賞",
            dateLabel: "鑑賞日"
        ),
        CategoryPreset(
            name: "酒",
            templateKey: "sake",
            templateTypeKey: "food",
            iconSymbol: "wineglass.fill",
            colorHex: "#B8792F",
            sortOrder: 50,
            enabledUnitsRaw: "basic,photos,importOCR,memo",
            targetNameLabel: "お酒",
            recordUnitName: "飲んだ回",
            dateLabel: "飲んだ日"
        ),
        CategoryPreset(
            name: "テーマパーク",
            templateKey: "theme_park",
            templateTypeKey: "visiting",
            iconSymbol: "ticket.fill",
            colorHex: "#2F7FB8",
            sortOrder: 60,
            enabledUnitsRaw: "basic,ticketPlan,photos,importOCR,money,officialInfo,memo",
            targetNameLabel: "施設",
            recordUnitName: "訪問",
            dateLabel: "訪問日"
        ),
        CategoryPreset(
            name: "自然・生き物",
            templateKey: "nature_living",
            templateTypeKey: "visiting",
            iconSymbol: "pawprint.fill",
            colorHex: "#2F7FB8",
            sortOrder: 61,
            enabledUnitsRaw: "basic,ticketPlan,photos,importOCR,money,officialInfo,memo",
            targetNameLabel: "施設",
            recordUnitName: "訪問",
            dateLabel: "訪問日"
        ),
        CategoryPreset(
            name: "その他・未分類",
            templateKey: "outing_facility",
            templateTypeKey: "visiting",
            iconSymbol: "questionmark.folder.fill",
            colorHex: "#2F7FB8",
            sortOrder: 62,
            enabledUnitsRaw: "basic,ticketPlan,photos,importOCR,money,officialInfo,memo",
            targetNameLabel: "施設",
            recordUnitName: "訪問",
            dateLabel: "訪問日"
        ),
        CategoryPreset(
            name: "御朱印",
            templateKey: "goshuin",
            templateTypeKey: "visiting",
            iconSymbol: "seal.fill",
            colorHex: "#A24C55",
            sortOrder: 70,
            enabledUnitsRaw: "basic,goshuinBook,photos,importOCR,memo",
            targetNameLabel: "参拝先",
            recordUnitName: "いただいた回",
            dateLabel: "参拝日"
        ),
        CategoryPreset(
            name: "書籍",
            templateKey: "book",
            templateTypeKey: "reading",
            iconSymbol: "books.vertical.fill",
            colorHex: "#536C95",
            sortOrder: 80,
            enabledUnitsRaw: "basic,people,photos,importOCR,memo",
            targetNameLabel: "本",
            recordUnitName: "読書",
            dateLabel: "読了日"
        ),
        CategoryPreset(
            name: "Goods",
            templateKey: "random_goods",
            templateTypeKey: "collection",
            iconSymbol: "shippingbox.fill",
            colorHex: "#A65A74",
            sortOrder: 90,
            enabledUnitsRaw: "basic,photos,money,officialInfo,memo",
            targetNameLabel: "シリーズ",
            recordUnitName: "入手・手放し",
            dateLabel: "記録日"
        ),
    ]

    @MainActor
    static func seedIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) async {
        let currentVersion = defaults.integer(forKey: AppStorageKeys.categoryPresetSeedVersion)
        guard currentVersion < seedVersion else { return }

        do {
            let descriptor = FetchDescriptor<RecordCategory>()
            let existingCategories = try context.fetch(descriptor)
            let now = Date()
            let hasCompletedGenreOnboarding = defaults.bool(forKey: AppStorageKeys.hasCompletedGenreOnboarding)
            let isFirstOutingSplit = !existingCategories.contains(where: { $0.isBuiltIn && $0.templateKey == "theme_park" })
                || !existingCategories.contains(where: { $0.isBuiltIn && $0.templateKey == "nature_living" })
            var resolvedCategories: [String: RecordCategory] = [:]

            for preset in presets {
                let isReleaseTemplate = isInitialReleaseTemplate(preset.templateKey)
                if let existing = existingCategories.first(where: { $0.isBuiltIn && $0.templateKey == preset.templateKey }) {
                    _ = apply(
                        preset,
                        to: existing,
                        isReleaseTemplate: isReleaseTemplate,
                        hasCompletedGenreOnboarding: hasCompletedGenreOnboarding,
                        now: now
                    )
                    resolvedCategories[preset.templateKey] = existing
                } else {
                    let category = RecordCategory(
                        name: preset.name,
                        iconSymbol: preset.iconSymbol,
                        colorHex: preset.colorHex,
                        sortOrder: preset.sortOrder,
                        isBuiltIn: true,
                        templateKey: preset.templateKey,
                        enabledUnitsRaw: preset.enabledUnitsRaw,
                        templateTypeKey: preset.templateTypeKey,
                        targetNameLabel: preset.targetNameLabel,
                        recordUnitName: preset.recordUnitName,
                        dateLabel: preset.dateLabel,
                        // 7ジャンルを初回表示で優先する。残りも継続開発対象として定義を保持するが、
                        // 新規利用者の初期UIには出さない。
                        // オンボーディング完了後に追加された標準ジャンルも、利用者の選択を尊重して非表示で作る。
                        isArchived: hasCompletedGenreOnboarding || !isReleaseTemplate,
                        createdAt: now,
                        updatedAt: now
                    )
                    context.insert(category)
                    resolvedCategories[preset.templateKey] = category
                }
            }

            migrateLegacyOutingCategoryIfNeeded(
                existingCategories: existingCategories,
                resolvedCategories: resolvedCategories,
                isFirstSplit: isFirstOutingSplit,
                now: now
            )

            try ensureAtLeastOneActiveCategory(in: context)

            if context.hasChanges {
                try context.save()
            }
            defaults.set(seedVersion, forKey: AppStorageKeys.categoryPresetSeedVersion)
        } catch {
            assertionFailure("Failed to seed category presets: \(error)")
        }
    }

    @MainActor
    @discardableResult
    static func apply(
        _ preset: CategoryPreset,
        to category: RecordCategory,
        isReleaseTemplate: Bool,
        hasCompletedGenreOnboarding: Bool,
        now: Date
    ) -> Bool {
        var changed = false

        func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RecordCategory, Value>, to value: Value) {
            guard category[keyPath: keyPath] != value else { return }
            category[keyPath: keyPath] = value
            changed = true
        }

        update(\.name, to: preset.name)
        update(\.iconSymbol, to: preset.iconSymbol)
        update(\.templateTypeKey, to: preset.templateTypeKey)
        update(\.targetNameLabel, to: preset.targetNameLabel)
        update(\.recordUnitName, to: preset.recordUnitName)
        update(\.dateLabel, to: preset.dateLabel)

        // 色・並び順・有効ユニットは利用者が設定画面で変更できるため、
        // 起動時のプリセット更新では上書きしない。旧データの空値だけ補完する。
        if category.colorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            update(\.colorHex, to: preset.colorHex)
        }
        if category.sortOrder <= 0 {
            update(\.sortOrder, to: preset.sortOrder)
        }
        if category.enabledUnitsRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            update(\.enabledUnitsRaw, to: preset.enabledUnitsRaw)
        }
        if !hasCompletedGenreOnboarding {
            update(\.isArchived, to: !isReleaseTemplate)
        }
        if changed {
            category.updatedAt = now
        }
        return changed
    }

    @MainActor
    static func ensureAtLeastOneActiveCategory(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<RecordCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try context.fetch(descriptor)

        guard !categories.isEmpty else { return }
        guard categories.allSatisfy(\.isArchived) else { return }

        categories[0].isArchived = false
        categories[0].updatedAt = Date()
    }

    @MainActor
    private static func migrateLegacyOutingCategoryIfNeeded(
        existingCategories: [RecordCategory],
        resolvedCategories: [String: RecordCategory],
        isFirstSplit: Bool,
        now: Date
    ) {
        guard isFirstSplit else { return }
        guard let legacyCategory = existingCategories.first(where: {
            $0.isBuiltIn && $0.templateKey == "outing_facility"
        }),
        let themeParkCategory = resolvedCategories["theme_park"],
        let natureCategory = resolvedCategories["nature_living"] else { return }

        let legacyWasVisible = !legacyCategory.isArchived
        if legacyWasVisible {
            themeParkCategory.isArchived = false
            natureCategory.isArchived = false
        }

        for event in legacyCategory.events ?? [] {
            guard let facilityType = OutingFacilityType(rawValue: event.subTypeKey) else { continue }
            switch facilityType.destinationTemplateKey {
            case "theme_park":
                event.category = themeParkCategory
            case "nature_living":
                event.category = natureCategory
            default:
                continue
            }
            event.updatedAt = now
        }

        for plan in legacyCategory.plans ?? [] {
            guard let eventCategory = plan.event?.category,
                  eventCategory.id != legacyCategory.id else { continue }
            plan.category = eventCategory
            plan.updatedAt = now
        }

        let hasUnclassifiedEvents = (legacyCategory.events ?? []).contains { event in
            !event.isArchived && event.category?.id == legacyCategory.id
        }
        let hasUnclassifiedPlans = (legacyCategory.plans ?? []).contains { plan in
            !plan.isArchived && (plan.category?.id == legacyCategory.id || plan.event?.category?.id == legacyCategory.id)
        }

        legacyCategory.name = "その他・未分類"
        legacyCategory.iconSymbol = "questionmark.folder.fill"
        legacyCategory.colorHex = "#2F7FB8"
        legacyCategory.sortOrder = 62
        legacyCategory.isArchived = legacyWasVisible ? !(hasUnclassifiedEvents || hasUnclassifiedPlans) : true
        legacyCategory.updatedAt = now
    }
}
