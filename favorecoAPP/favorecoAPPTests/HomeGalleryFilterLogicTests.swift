import XCTest
@testable import favoreco

final class HomeGalleryFilterLogicTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testFiltersByMultipleCategoriesAndYearsThenSortsByRegistrationDate() {
        let theaterID = UUID()
        let liveID = UUID()
        let museumID = UUID()
        let oldest = makeItem(title: "old", categoryID: theaterID, year: 2025, registeredOffset: 1)
        let newest = makeItem(title: "new", categoryID: liveID, year: 2026, registeredOffset: 3)
        let middle = makeItem(title: "middle", categoryID: theaterID, year: 2026, registeredOffset: 2)
        let excluded = makeItem(title: "museum", categoryID: museumID, year: 2026, registeredOffset: 4)

        let result = HomeGalleryFilterLogic.filtered(
            [oldest, newest, middle, excluded],
            categoryIDs: [theaterID, liveID],
            years: [2026],
            searchText: "",
            tagNames: [],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.title), ["new", "middle"])
    }

    func testSearchRequiresEveryWordAndTagsUseAnySelectedMatch() {
        let first = makeItem(
            title: "first",
            year: 2026,
            tags: ["遠征", "感動"],
            searchText: "月影のアトリエ 東京芸術劇場"
        )
        let second = makeItem(
            title: "second",
            year: 2026,
            tags: ["友人"],
            searchText: "月影のアトリエ 大阪劇場"
        )

        let result = HomeGalleryFilterLogic.filtered(
            [first, second],
            categoryIDs: [],
            years: [],
            searchText: "月影 東京",
            tagNames: ["感動", "友人"],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.title), ["first"])
    }

    func testMasonryPlacesNextTileIntoShorterColumn() {
        let tall = makeItem(title: "tall", year: 2026, aspectRatio: 0.68)
        let wide = makeItem(title: "wide", year: 2026, aspectRatio: 1.55)
        let next = makeItem(title: "next", year: 2026, aspectRatio: 1)

        let columns = HomeGalleryFilterLogic.masonryColumns([tall, wide, next])

        XCTAssertEqual(columns[0].map(\.title), ["tall"])
        XCTAssertEqual(columns[1].map(\.title), ["wide", "next"])
    }

    private func makeItem(
        title: String,
        categoryID: UUID? = UUID(),
        year: Int,
        registeredOffset: TimeInterval = 0,
        tags: [String] = [],
        searchText: String = "",
        aspectRatio: Double = 1
    ) -> HomeGalleryItem {
        let visitedAt = calendar.date(from: DateComponents(year: year, month: 6, day: 1))!
        return HomeGalleryItem(
            title: title,
            categoryID: categoryID,
            categoryName: "テスト",
            visitedAt: visitedAt,
            registeredAt: Date(timeIntervalSince1970: registeredOffset),
            aspectRatio: aspectRatio,
            tagNames: tags,
            normalizedSearchText: searchText
        )
    }
}
