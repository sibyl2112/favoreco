import XCTest
@testable import favoreco

final class ScreenWorkMetadataTests: XCTestCase {
    func testLegacyEmptySubtypeRemainsMovie() {
        XCTAssertEqual(ScreenWorkType.resolved(from: ""), .movie)
    }

    func testSeasonRoundTripAcceptsOnlyOneThroughTen() {
        let encoded = VisitUnitFields(screenWorkSeasonNumber: 7).encodedRawValue
        XCTAssertEqual(VisitUnitFields(rawValue: encoded).screenWorkSeasonNumber, 7)
        XCTAssertEqual(VisitUnitFields(screenWorkSeasonNumber: 11).screenWorkSeasonNumber, 0)
        XCTAssertEqual(VisitUnitFields(screenWorkSeasonNumber: -1).screenWorkSeasonNumber, 0)
    }

    func testFiltersIncludeOnlySelectedWorkType() {
        XCTAssertTrue(ScreenWorkFilter.all.includes(.anime))
        XCTAssertTrue(ScreenWorkFilter.drama.includes(.drama))
        XCTAssertFalse(ScreenWorkFilter.drama.includes(.movie))
    }

    @MainActor
    func testExistingWorkCanBeReclassifiedFromVisitForm() {
        let event = ExperienceEvent(title: "分類前")

        event.applyScreenWorkClassification(typeKey: ScreenWorkType.anime.rawValue, seasonNumber: 10)

        XCTAssertEqual(event.screenWorkType, .anime)
        XCTAssertEqual(event.screenWorkSeasonNumber, 10)
        XCTAssertTrue(ScreenWorkFilter.anime.includes(event.screenWorkType))

        event.applyScreenWorkClassification(typeKey: ScreenWorkType.movie.rawValue, seasonNumber: 10)
        XCTAssertEqual(event.screenWorkType, .movie)
        XCTAssertEqual(event.screenWorkSeasonNumber, 0)
    }
}
