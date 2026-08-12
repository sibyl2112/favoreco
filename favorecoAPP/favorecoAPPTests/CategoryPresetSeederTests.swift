import XCTest
@testable import favoreco

final class CategoryPresetSeederTests: XCTestCase {
    func testInitialReleaseContainsOnlyTheSevenConfirmedGenres() {
        XCTAssertEqual(
            CategoryPresetSeeder.initialReleaseTemplateKeys,
            Set([
                "theater",
                "movie",
                "live",
                "book",
                "museum",
                "theme_park",
                "nature_living",
            ])
        )
    }

    func testNonPriorityPresetsRemainAvailableForContinuedDevelopment() {
        for templateKey in ["sake", "outing_facility", "goshuin", "random_goods"] {
            XCTAssertFalse(CategoryPresetSeeder.isInitialReleaseTemplate(templateKey))
            XCTAssertTrue(CategoryPresetSeeder.presets.contains { $0.templateKey == templateKey })
        }
    }

    func testNatureAndLivingThingsRemainOneGenre() {
        let matchingPresets = CategoryPresetSeeder.presets.filter {
            CategoryPresetSeeder.isInitialReleaseTemplate($0.templateKey)
                && $0.templateKey == "nature_living"
        }

        XCTAssertEqual(matchingPresets.count, 1)
        XCTAssertEqual(matchingPresets.first?.name, "自然・生き物")
    }

    @MainActor
    func testApplyingCurrentPresetDoesNotChangeUpdatedAt() throws {
        let preset = try XCTUnwrap(CategoryPresetSeeder.presets.first { $0.templateKey == "theater" })
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_700_000_000)
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
            isArchived: false,
            createdAt: originalUpdatedAt,
            updatedAt: originalUpdatedAt
        )

        let changed = CategoryPresetSeeder.apply(
            preset,
            to: category,
            isReleaseTemplate: true,
            hasCompletedGenreOnboarding: true,
            now: originalUpdatedAt.addingTimeInterval(100)
        )

        XCTAssertFalse(changed)
        XCTAssertEqual(category.updatedAt, originalUpdatedAt)
    }

    @MainActor
    func testApplyingChangedPresetUpdatesOnlyCanonicalFieldsAndTimestamp() throws {
        let preset = try XCTUnwrap(CategoryPresetSeeder.presets.first { $0.templateKey == "theater" })
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updateDate = originalUpdatedAt.addingTimeInterval(100)
        let category = RecordCategory(
            name: "旧表示名",
            iconSymbol: preset.iconSymbol,
            colorHex: "#123456",
            sortOrder: 999,
            isBuiltIn: true,
            templateKey: preset.templateKey,
            enabledUnitsRaw: "basic",
            templateTypeKey: preset.templateTypeKey,
            targetNameLabel: preset.targetNameLabel,
            recordUnitName: preset.recordUnitName,
            dateLabel: preset.dateLabel,
            isArchived: false,
            createdAt: originalUpdatedAt,
            updatedAt: originalUpdatedAt
        )

        let changed = CategoryPresetSeeder.apply(
            preset,
            to: category,
            isReleaseTemplate: true,
            hasCompletedGenreOnboarding: true,
            now: updateDate
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(category.name, preset.name)
        XCTAssertEqual(category.colorHex, "#123456")
        XCTAssertEqual(category.sortOrder, 999)
        XCTAssertEqual(category.enabledUnitsRaw, "basic")
        XCTAssertEqual(category.updatedAt, updateDate)
    }
}
