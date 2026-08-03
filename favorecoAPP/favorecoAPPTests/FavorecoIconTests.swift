import XCTest
@testable import favoreco

final class FavorecoIconTests: XCTestCase {
    func testPrimaryIconsResolveToPhosphorGlyphs() {
        [
            "house.fill",
            "heart.text.square.fill",
            "plus",
            "calendar",
            "chart.bar.fill",
            "ticket",
            "bell",
            "books.vertical.fill",
            "castle.turret",
            "pawprint",
            "tag.fill",
            "chair",
            "cloud.sun",
            "person.text.rectangle",
            "safari",
            "doc.viewfinder",
            "link.badge.plus",
            "bookmark",
            "photo.on.rectangle.angled",
        ].forEach { systemName in
            XCTAssertNotNil(
                PhosphorIconGlyph.glyph(for: systemName),
                "\(systemName) should use the primary Phosphor icon family"
            )
        }
    }

    func testUnsupportedIconFallsBackToSystemSymbol() {
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "apple.logo"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "star.fill"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "checkmark.circle.fill"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "xmark.circle.fill"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "calendar.badge.exclamationmark"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "person.crop.circle"))
        XCTAssertNil(PhosphorIconGlyph.glyph(for: "photo.badge.plus"))
    }

    func testPrimaryTabIconsRenderAsTemplateImages() {
        [
            "house.fill",
            "heart.text.square.fill",
            "plus",
            "calendar",
            "chart.bar.fill",
        ].forEach { systemName in
            let image = PhosphorIconImage.image(for: systemName, size: 23)
            XCTAssertNotNil(image)
            XCTAssertEqual(image?.renderingMode, .alwaysTemplate)
        }
    }

    func testOutingCategoriesUseDistinctIconContexts() {
        XCTAssertEqual(
            PhosphorIconGlyph.categorySystemName(
                templateKey: "theme_park",
                storedSystemName: "building.columns.fill"
            ),
            "castle.turret"
        )
        XCTAssertEqual(
            PhosphorIconGlyph.categorySystemName(
                templateKey: "nature_living",
                storedSystemName: "leaf.fill"
            ),
            "pawprint"
        )
    }
}
