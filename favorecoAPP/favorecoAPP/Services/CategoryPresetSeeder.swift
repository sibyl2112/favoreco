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
            name: "おでかけ施設",
            templateKey: "outing_facility",
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
    ]

    @MainActor
    static func seedIfNeeded(in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<RecordCategory>()
            let existingCategories = try context.fetch(descriptor)
            let now = Date()
            let hasCompletedGenreOnboarding = UserDefaults.standard.bool(forKey: AppStorageKeys.hasCompletedGenreOnboarding)

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
                } else {
                    context.insert(RecordCategory(
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
                        isArchived: hasCompletedGenreOnboarding,
                        createdAt: now,
                        updatedAt: now
                    ))
                }
            }

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
}
