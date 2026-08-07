import XCTest
@testable import favoreco

@MainActor
final class TheaterTravelMapSnapshotTests: XCTestCase {
    func testSamePlaceMasterCountsMultipleVisitsAtOnePoint() {
        let place = PlaceMaster(
            name: "東京芸術劇場 プレイハウス",
            latitude: 35.7297,
            longitude: 139.7088
        )
        let first = Visit(venueNameSnapshot: "東京芸術劇場", placeMaster: place)
        let second = Visit(venueNameSnapshot: "東京芸術劇場 プレイハウス", placeMaster: place)

        let snapshot = TheaterTravelMapSnapshot.make(visits: [first, second])

        XCTAssertEqual(snapshot.points.count, 1)
        XCTAssertEqual(snapshot.points.first?.visitCount, 2)
        XCTAssertEqual(snapshot.missingCoordinateCount, 0)
    }

    func testLegacyVisitsWithSameNormalizedVenueAndNearbyCoordinatesAreGrouped() {
        let first = Visit(
            venueNameSnapshot: "東京芸術劇場 プレイハウス",
            latitude: 35.72971,
            longitude: 139.70881
        )
        let second = Visit(
            venueNameSnapshot: "東京芸術劇場　プレイハウス",
            latitude: 35.72974,
            longitude: 139.70884
        )

        let snapshot = TheaterTravelMapSnapshot.make(visits: [first, second])

        XCTAssertEqual(snapshot.points.count, 1)
        XCTAssertEqual(snapshot.points.first?.visitCount, 2)
    }

    func testVisitsWithoutCoordinatesAreReportedButNotMapped() {
        let mapped = Visit(
            venueNameSnapshot: "会場A",
            latitude: 35.0,
            longitude: 139.0
        )
        let missing = Visit(venueNameSnapshot: "会場B")

        let snapshot = TheaterTravelMapSnapshot.make(visits: [mapped, missing])

        XCTAssertEqual(snapshot.points.count, 1)
        XCTAssertEqual(snapshot.totalVisitCount, 2)
        XCTAssertEqual(snapshot.missingCoordinateCount, 1)
    }

    func testPublicPerformanceVenueIsMappedWithoutVisits() {
        let venue = TheaterTravelMapVenue(
            id: "osaka-castle",
            name: "大阪城天守閣",
            latitude: 34.6873,
            longitude: 135.5262
        )

        let snapshot = TheaterTravelMapSnapshot.make(visits: [], venues: [venue])

        XCTAssertEqual(snapshot.points.count, 1)
        XCTAssertEqual(snapshot.points.first?.name, "大阪城天守閣")
        XCTAssertEqual(snapshot.points.first?.visitCount, 0)
        XCTAssertEqual(snapshot.totalVisitCount, 0)
        XCTAssertEqual(snapshot.totalVenueCount, 1)
    }

    func testPublicPerformanceVenueAndNearbyVisitShareOnePoint() {
        let visit = Visit(
            venueNameSnapshot: "大阪城",
            latitude: 34.68731,
            longitude: 135.52621
        )
        let venue = TheaterTravelMapVenue(
            id: "osaka-castle",
            name: "大阪城天守閣",
            latitude: 34.6873,
            longitude: 135.5262
        )

        let visitSnapshot = TheaterTravelMapSnapshot.make(visits: [visit])
        let venueSnapshot = TheaterTravelMapSnapshot.make(visits: [], venues: [venue])
        let snapshot = venueSnapshot.mergingVisitSnapshot(visitSnapshot)

        XCTAssertEqual(snapshot.points.count, 1)
        XCTAssertEqual(snapshot.points.first?.visitCount, 1)
    }
}
