import XCTest
@testable import favoreco

final class HeroBackgroundPresetTests: XCTestCase {
    func testGenresWithAlternativesExposeMultipleBundledBackgrounds() {
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "theater").count, 3)
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "goshuin").count, 3)
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "movie").count, 3)
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "nature_living").count, 3)

        for key in [
            "book", "museum", "live", "sake",
            "theme_park", "outing_facility", "random_goods",
        ] {
            XCTAssertEqual(HeroBackgroundPreset.presets(for: key).count, 1, key)
        }
    }

    func testSingleBackgroundGenresUseDefaultResource() {
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "movie").first?.resourceName, "movie-hero-default")
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "book").first?.resourceName, "book-hero-default")
        XCTAssertEqual(HeroBackgroundPreset.presets(for: "museum").first?.resourceName, "museum-hero-default")
    }

    func testRemovedStoredPresetFallsBackToAvailableBackground() {
        let resolved = HeroBackgroundPreset.resolved(categoryKey: "movie", storedKey: "movieNoir")

        XCTAssertEqual(resolved?.key, "movieDefault")
        XCTAssertEqual(resolved?.resourceName, "movie-hero-default")
    }

    func testExplicitNoneDoesNotResolveToDefaultBackground() {
        XCTAssertNil(
            HeroBackgroundPreset.resolved(
                categoryKey: "theater",
                storedKey: HeroBackgroundPreset.noneKey
            )
        )
    }

    func testNaturePresetsRepresentPrimaryVisitTypes() {
        let presets = HeroBackgroundPreset.presets(for: "nature_living")

        XCTAssertEqual(presets.map(\.title), ["動物園", "水族館", "植物園"])
        XCTAssertEqual(
            presets.map(\.resourceName),
            [
                "nature_living-hero-zoo",
                "nature_living-hero-aquarium",
                "nature_living-hero-botanical",
            ]
        )
        XCTAssertEqual(HeroBackgroundPreset.resolved(categoryKey: "nature_living", storedKey: "natureDefault")?.title, "動物園")
    }

    func testPresetKeysAndResourcesAreUniqueWithinEachGenre() {
        for key in ["theater", "goshuin", "movie", "book", "museum", "live", "nature_living"] {
            let presets = HeroBackgroundPreset.presets(for: key)
            XCTAssertEqual(Set(presets.map(\.key)).count, presets.count, key)
            XCTAssertEqual(Set(presets.map(\.resourceName)).count, presets.count, key)
        }
    }

    func testUnknownGenreDoesNotBundlePreset() {
        XCTAssertTrue(HeroBackgroundPreset.presets(for: "custom-user-genre").isEmpty)
    }
}
