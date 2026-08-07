import MapKit

enum FavorecoMapViewport {
    static let singlePointVisibleMeters: CLLocationDistance = 500

    static func singlePointRegion(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: singlePointVisibleMeters,
            longitudinalMeters: singlePointVisibleMeters
        )
    }
}
