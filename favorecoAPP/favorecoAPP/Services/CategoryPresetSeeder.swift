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
    let iconSymbol: String
    let colorHex: String
    let sortOrder: Int
    let enabledUnitsRaw: String
}

enum CategoryPresetSeeder {
    static let presets: [CategoryPreset] = [
        CategoryPreset(
            name: "観劇",
            templateKey: "theater",
            iconSymbol: "theatermasks.fill",
            colorHex: "#8B2F45",
            sortOrder: 10,
            enabledUnitsRaw: "U1,U3,U4,U7,U11,U12,U14,U15,U18"
        ),
        CategoryPreset(
            name: "美術展",
            templateKey: "museum",
            iconSymbol: "paintpalette.fill",
            colorHex: "#7D8C78",
            sortOrder: 20,
            enabledUnitsRaw: "U1,U3,U4,U11,U12,U14,U15"
        ),
        CategoryPreset(
            name: "ライブ",
            templateKey: "live",
            iconSymbol: "music.mic",
            colorHex: "#147C88",
            sortOrder: 30,
            enabledUnitsRaw: "U1,U3,U4,U7,U11,U12,U14,U15,U18"
        ),
        CategoryPreset(
            name: "映画",
            templateKey: "movie",
            iconSymbol: "movieclapper.fill",
            colorHex: "#3B3D4A",
            sortOrder: 40,
            enabledUnitsRaw: "U1,U3,U7,U11,U12,U14,U15"
        ),
        CategoryPreset(
            name: "酒",
            templateKey: "sake",
            iconSymbol: "wineglass.fill",
            colorHex: "#B8792F",
            sortOrder: 50,
            enabledUnitsRaw: "U1,U3,U7,U9,U10,U11,U12,U16,U17"
        ),
        CategoryPreset(
            name: "おでかけ施設",
            templateKey: "outing_facility",
            iconSymbol: "ticket.fill",
            colorHex: "#2E7D60",
            sortOrder: 60,
            enabledUnitsRaw: "U1,U3,U4,U7,U11,U12,U14,U18"
        ),
        CategoryPreset(
            name: "御朱印",
            templateKey: "goshuin",
            iconSymbol: "seal.fill",
            colorHex: "#A24C55",
            sortOrder: 70,
            enabledUnitsRaw: "U1,U3,U11,U12,U14"
        ),
        CategoryPreset(
            name: "書籍",
            templateKey: "book",
            iconSymbol: "books.vertical.fill",
            colorHex: "#536C95",
            sortOrder: 80,
            enabledUnitsRaw: "U1,U3,U7,U11,U12,U14,U15"
        ),
    ]

    @MainActor
    static func seedIfNeeded(in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<RecordCategory>()
            let existingCategories = try context.fetch(descriptor)
            let now = Date()

            for preset in presets {
                if let existing = existingCategories.first(where: { $0.isBuiltIn && $0.templateKey == preset.templateKey }) {
                    existing.name = preset.name
                    existing.iconSymbol = preset.iconSymbol
                    existing.colorHex = preset.colorHex
                    existing.sortOrder = preset.sortOrder
                    existing.enabledUnitsRaw = preset.enabledUnitsRaw
                    existing.isArchived = false
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
                        createdAt: now,
                        updatedAt: now
                    ))
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            assertionFailure("Failed to seed category presets: \(error)")
        }
    }
}
