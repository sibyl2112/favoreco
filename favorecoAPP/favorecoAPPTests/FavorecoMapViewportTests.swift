import MapKit
import XCTest
@testable import favoreco

@MainActor
final class FavorecoMapViewportTests: XCTestCase {
    func testSinglePointRegionShowsApproximatelyFiveHundredMeters() {
        let center = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let region = FavorecoMapViewport.singlePointRegion(center: center)
        let north = CLLocation(
            latitude: center.latitude + region.span.latitudeDelta / 2,
            longitude: center.longitude
        )
        let south = CLLocation(
            latitude: center.latitude - region.span.latitudeDelta / 2,
            longitude: center.longitude
        )
        let east = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude + region.span.longitudeDelta / 2
        )
        let west = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude - region.span.longitudeDelta / 2
        )

        XCTAssertEqual(north.distance(from: south), 500, accuracy: 2)
        XCTAssertEqual(east.distance(from: west), 500, accuracy: 2)
    }
}
