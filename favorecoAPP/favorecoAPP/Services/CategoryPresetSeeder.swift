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
            name: "映画",
            templateKey: "movie",
            templateTypeKey: "watching",
            iconSymbol: "movieclapper.fill",
            colorHex: "#3B3D4A",
            sortOrder: 40,
            enabledUnitsRaw: "basic,people,photos,importOCR,officialInfo,memo",
            targetNameLabel: "映画",
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
            name: "自然・いきもの",
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
            name: "ランダムグッズ",
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
    static func seedIfNeeded(in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<RecordCategory>()
            let existingCategories = try context.fetch(descriptor)
            let now = Date()
            let hasCompletedGenreOnboarding = UserDefaults.standard.bool(forKey: AppStorageKeys.hasCompletedGenreOnboarding)
            let isFirstOutingSplit = !existingCategories.contains(where: { $0.isBuiltIn && $0.templateKey == "theme_park" })
                || !existingCategories.contains(where: { $0.isBuiltIn && $0.templateKey == "nature_living" })
            var resolvedCategories: [String: RecordCategory] = [:]

            for preset in presets {
                if let existing = existingCategories.first(where: { $0.isBuiltIn && $0.templateKey == preset.templateKey }) {
                    existing.name = preset.name
                    existing.iconSymbol = preset.iconSymbol
                    existing.colorHex = preset.colorHex
                    existing.sortOrder = preset.sortOrder
                    existing.enabledUnitsRaw = preset.enabledUnitsRaw
                    existing.templateTypeKey = preset.templateTypeKey
                    existing.targetNameLabel = preset.targetNameLabel
                    existing.recordUnitName = preset.recordUnitName
                    existing.dateLabel = preset.dateLabel
                    if !hasCompletedGenreOnboarding {
                        existing.isArchived = false
                    }
                    existing.updatedAt = now
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
                        // 新設ジャンルは更新直後から利用できるよう、既存利用者にも初回だけ表示する。
                        isArchived: hasCompletedGenreOnboarding && preset.templateKey != "random_goods",
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
        } catch {
            assertionFailure("Failed to seed category presets: \(error)")
        }
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
        guard let legacyCategory = existingCategories.first(where: {
            $0.isBuiltIn && $0.templateKey == "outing_facility"
        }),
        let themeParkCategory = resolvedCategories["theme_park"],
        let natureCategory = resolvedCategories["nature_living"] else { return }

        let legacyWasVisible = !legacyCategory.isArchived
        if isFirstSplit && legacyWasVisible {
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
        if isFirstSplit {
            legacyCategory.isArchived = legacyWasVisible ? !(hasUnclassifiedEvents || hasUnclassifiedPlans) : true
        }
        legacyCategory.updatedAt = now
    }
}
