import Foundation
import MapKit
import Contacts

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

        let candidates = response.mapItems.prefix(20).map { item in
            let coordinate = coordinate(for: item)
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = formattedAddress(for: item)
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

        return prioritizedCandidates(candidates, for: trimmedQuery)
    }

    nonisolated static func prioritizedCandidates(
        _ candidates: [PlaceSearchCandidate],
        for query: String
    ) -> [PlaceSearchCandidate] {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return candidates }

        let scored = candidates.enumerated().map { index, candidate in
            (
                candidate: candidate,
                originalIndex: index,
                score: matchScore(
                    normalizedSearchText(candidate.name),
                    query: normalizedQuery
                )
            )
        }
        let matching = scored.filter { $0.score < 3 }
        guard !matching.isEmpty else { return candidates }

        return matching
            .sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                return $0.originalIndex < $1.originalIndex
            }
            .map(\.candidate)
    }

    nonisolated private static func matchScore(_ name: String, query: String) -> Int {
        if name == query { return 0 }
        if name.hasPrefix(query) || query.hasPrefix(name) { return 1 }
        if name.contains(query) || query.contains(name) { return 2 }
        return 3
    }

    nonisolated private static func normalizedSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    private static func coordinate(for item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }

    private static func formattedAddress(for item: MKMapItem) -> String {
        let address: String
        if #available(iOS 26.0, *) {
            address = item.address?.fullAddress ?? ""
        } else if let postalAddress = item.placemark.postalAddress {
            address = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: " ")
        } else {
            address = item.placemark.title ?? ""
        }
        return address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func appleMapsURL(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://maps.apple.com/")

        if !trimmedAddress.isEmpty {
            components?.queryItems = [URLQueryItem(name: "q", value: trimmedAddress)]
        } else if latitude != 0 || longitude != 0 {
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: trimmedName.isEmpty ? nil : trimmedName)
            ].filter { $0.value != nil }
        } else if !trimmedName.isEmpty {
            components?.queryItems = [URLQueryItem(name: "q", value: trimmedName)]
        } else {
            return nil
        }
        return components?.url
    }
}
