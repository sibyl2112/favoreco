import Foundation
import MapKit

struct PlaceSearchCandidate: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

enum PlaceSearchService {
    @MainActor
    static func search(query: String) async throws -> [PlaceSearchCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.resultTypes = [.pointOfInterest, .address]
        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.prefix(20).map { item in
            let coordinate = item.location.coordinate
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = item.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedName = (name?.isEmpty == false ? name : nil) ?? address
            return PlaceSearchCandidate(
                id: "\(coordinate.latitude),\(coordinate.longitude),\(resolvedName)",
                name: resolvedName,
                address: address == resolvedName ? "" : address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
        .filter { !$0.name.isEmpty }
    }
}
