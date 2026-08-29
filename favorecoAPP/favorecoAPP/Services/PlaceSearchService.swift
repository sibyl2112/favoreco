import Foundation
import MapKit
import Contacts
import LinkPresentation

struct PlaceSearchCandidate: Identifiable, Sendable {
    enum Source: String, Sendable {
        case registered = "登録済み"
        case publicCatalog = "全国カタログ"
        case appleMaps = "Apple Maps"
        case sharedLink = "共有URL"
        case manualPin = "地図指定"
    }

    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let source: Source

    init(
        id: String,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        source: Source = .appleMaps
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
    }
}

struct SharedMapLinkPreview: Sendable {
    let url: URL
    let name: String
    let latitude: Double?
    let longitude: Double?
}

enum SharedMapLinkError: LocalizedError {
    case invalidURL
    case unsupportedLink

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Google MapsまたはApple Mapsの共有URLを貼り付けてください。"
        case .unsupportedLink:
            "このURLから場所名を確認できませんでした。会場名と住所を入力し、地図で位置を指定してください。"
        }
    }
}

enum PlaceSearchService {
    /// 利用者が共有した地図URLから、保存可能な最小情報を得る。
    /// Google URLは参照URLとOGP名称だけを扱い、Placesデータの住所・座標は永続化しない。
    /// Apple Maps URLは公開クエリの名称・座標をそのまま利用できる。
    @MainActor
    static func sharedMapLinkPreview(from rawValue: String) async throws -> SharedMapLinkPreview {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw SharedMapLinkError.invalidURL
        }

        let host = url.host?.lowercased() ?? ""
        guard host.contains("google") || host.contains("goo.gl") || host.contains("apple.com") else {
            throw SharedMapLinkError.invalidURL
        }

        if host.contains("maps.apple.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let name = components?.queryItems?.first(where: { ["q", "name"].contains($0.name) })?.value ?? ""
            let coordinateText = components?.queryItems?.first(where: { ["ll", "sll"].contains($0.name) })?.value
            let coordinate = coordinateText.flatMap(coordinatePair(from:))
            guard !name.isEmpty || coordinate != nil else { throw SharedMapLinkError.unsupportedLink }
            return SharedMapLinkPreview(
                url: url,
                name: name,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude
            )
        }

        let provider = LPMetadataProvider()
        provider.timeout = 12
        let metadata = try await provider.startFetchingMetadata(for: url)
        let name = cleanedSharedPlaceTitle(metadata.title ?? "")
        guard !name.isEmpty else { throw SharedMapLinkError.unsupportedLink }
        return SharedMapLinkPreview(url: url, name: name, latitude: nil, longitude: nil)
    }

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

    /// 名称だけで見つからない小規模会場向けに、名称＋住所、名称、住所を順に横断する。
    /// 同じ座標・名称・住所は1候補へまとめ、各入力画面で同じ検索結果を使う。
    @MainActor
    static func search(queries: [String]) async throws -> [PlaceSearchCandidate] {
        let normalizedQueries = queries.reduce(into: [String]()) { result, value in
            let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty, !result.contains(query) else { return }
            result.append(query)
        }
        guard !normalizedQueries.isEmpty else { return [] }

        var merged: [PlaceSearchCandidate] = []
        var seen = Set<String>()
        var lastError: Error?
        for query in normalizedQueries {
            guard !Task.isCancelled else { return [] }
            do {
                for candidate in try await search(query: query) {
                    let key = candidateDeduplicationKey(candidate)
                    if seen.insert(key).inserted { merged.append(candidate) }
                }
            } catch {
                lastError = error
            }
        }
        if merged.isEmpty, let lastError { throw lastError }
        return merged
    }

    /// Map previewで使う座標解決。Apple MapsのPOI検索で見つからない住所は
    /// 住所ジオコーダーへフォールバックし、施設詳細と記録詳細で同じ結果を使う。
    @MainActor
    static func resolveCoordinate(queries: [String]) async -> CLLocationCoordinate2D? {
        let normalizedQueries = queries.reduce(into: [String]()) { result, value in
            let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty, !result.contains(query) else { return }
            result.append(query)
        }

        for query in normalizedQueries {
            guard !Task.isCancelled else { return nil }
            if let candidate = try? await search(query: query).first {
                return CLLocationCoordinate2D(
                    latitude: candidate.latitude,
                    longitude: candidate.longitude
                )
            }
        }

        for query in normalizedQueries {
            guard !Task.isCancelled else { return nil }
            let geocoder = CLGeocoder()
            if let location = try? await geocoder.geocodeAddressString(query).first?.location {
                return location.coordinate
            }
        }

        return nil
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

    nonisolated static func normalizedSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    nonisolated static func candidateDeduplicationKey(_ candidate: PlaceSearchCandidate) -> String {
        let name = normalizedSearchText(candidate.name)
        let address = normalizedSearchText(candidate.address)
        if candidate.latitude != 0 || candidate.longitude != 0 {
            return String(format: "%.5f|%.5f|%@", candidate.latitude, candidate.longitude, name)
        }
        return "\(name)|\(address)"
    }

    nonisolated private static func coordinatePair(from value: String) -> (latitude: Double, longitude: Double)? {
        let components = value.split(separator: ",", maxSplits: 2).map(String.init)
        guard components.count >= 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return (latitude, longitude)
    }

    nonisolated private static func cleanedSharedPlaceTitle(_ value: String) -> String {
        let title = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }
        let genericTitles = ["Google Maps", "Google マップ", "Maps"]
        guard !genericTitles.contains(title) else { return "" }
        return title
            .components(separatedBy: " · ").first?
            .components(separatedBy: " - Google Maps").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    nonisolated static func googleMapsURL(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: String

        if latitude != 0 || longitude != 0 {
            query = "\(latitude),\(longitude)"
        } else {
            query = [trimmedName, trimmedAddress]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        guard !query.isEmpty else { return nil }

        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query),
        ]
        return components?.url
    }
}
