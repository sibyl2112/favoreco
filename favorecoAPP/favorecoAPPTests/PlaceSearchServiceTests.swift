import XCTest
@testable import favoreco

final class PlaceSearchServiceTests: XCTestCase {
    func testGoogleMapsURLUsesOfficialSearchQueryParameter() throws {
        let url = try XCTUnwrap(PlaceSearchService.googleMapsURL(
            name: "東京芸術劇場 プレイハウス",
            address: "東京都豊島区西池袋1-8-1",
            latitude: 0,
            longitude: 0
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/maps/search/")
        XCTAssertEqual(queryItems["api"], "1")
        XCTAssertEqual(
            queryItems["query"],
            "東京芸術劇場 プレイハウス 東京都豊島区西池袋1-8-1"
        )
        XCTAssertNil(queryItems["q"])
    }

    func testGoogleMapsURLPrefersSavedCoordinate() throws {
        let url = try XCTUnwrap(PlaceSearchService.googleMapsURL(
            name: "東京芸術劇場",
            address: "東京都豊島区西池袋1-8-1",
            latitude: 35.7297,
            longitude: 139.7088
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = components.queryItems?.first(where: { $0.name == "query" })?.value

        XCTAssertEqual(query, "35.7297,139.7088")
    }

    func testPlaceSuggestionsMergePostalCodeVariantsAndPreferCoordinates() throws {
        let addressOnly = PlaceMaster(
            name: "東京ドーム",
            address: "東京都文京区後楽1-3-61"
        )
        let coordinateResolved = PlaceMaster(
            name: "東京ドーム",
            address: "〒112-0004 東京都文京区後楽1-3-61",
            latitude: 35.7056,
            longitude: 139.7519
        )

        let suggestions = deduplicatedPlaceSuggestions([addressOnly, coordinateResolved])

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(try XCTUnwrap(suggestions.first).id, coordinateResolved.id)
    }

    func testPlaceSuggestionsKeepSameNameAtDifferentAddresses() {
        let first = PlaceMaster(name: "文化会館", address: "東京都千代田区1-1")
        let second = PlaceMaster(name: "文化会館", address: "大阪府大阪市2-2")

        XCTAssertEqual(deduplicatedPlaceSuggestions([first, second]).count, 2)
    }
}
