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
}
