import Foundation

struct ScreenWorkMetadataCandidate: Identifiable, Sendable {
    let tmdbID: Int
    let mediaType: String
    let type: ScreenWorkType
    let title: String
    let originalTitle: String
    let releaseDate: String
    let overview: String
    let posterURL: URL?
    let informationURL: String

    var id: String { "\(mediaType)-\(tmdbID)" }

    var yearText: String {
        String(releaseDate.prefix(4))
    }
}

enum ScreenWorkMetadataLookupError: LocalizedError {
    case missingCredential
    case emptyQuery
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "作品検索は現在利用できません。手入力で続けてください。"
        case .emptyQuery:
            "作品名を入力してください。"
        case .invalidResponse:
            "作品情報を取得できませんでした。通信環境を確認して、もう一度お試しください。"
        }
    }
}

enum ScreenWorkMetadataLookupService {
    static var isConfigured: Bool { accessToken != nil }

    static func search(
        query rawQuery: String,
        type: ScreenWorkType
    ) async throws -> [ScreenWorkMetadataCandidate] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw ScreenWorkMetadataLookupError.emptyQuery }
        guard let accessToken else { throw ScreenWorkMetadataLookupError.missingCredential }

        var components = URLComponents(string: "https://api.themoviedb.org/3/search/multi")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: "ja-JP"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: "1"),
        ]
        guard let url = components?.url else { throw ScreenWorkMetadataLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ScreenWorkMetadataLookupError.invalidResponse
        }
        return try candidates(from: data, requestedType: type)
    }

    static func candidates(
        from data: Data,
        requestedType: ScreenWorkType
    ) throws -> [ScreenWorkMetadataCandidate] {
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return response.results.compactMap { item in
            guard item.mediaType == "movie" || item.mediaType == "tv" else { return nil }
            let isAnimation = item.genreIDs.contains(16)
            let resolvedType: ScreenWorkType
            switch requestedType {
            case .movie:
                guard item.mediaType == "movie", !isAnimation else { return nil }
                resolvedType = .movie
            case .drama:
                guard item.mediaType == "tv", !isAnimation else { return nil }
                resolvedType = .drama
            case .anime:
                guard isAnimation else { return nil }
                resolvedType = .anime
            }

            let title = (item.title ?? item.name ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let originalTitle = (item.originalTitle ?? item.originalName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let releaseDate = item.releaseDate ?? item.firstAirDate ?? ""
            let posterURL = item.posterPath.flatMap {
                URL(string: "https://image.tmdb.org/t/p/w780\($0)")
            }
            return ScreenWorkMetadataCandidate(
                tmdbID: item.id,
                mediaType: item.mediaType,
                type: resolvedType,
                title: title,
                originalTitle: originalTitle == title ? "" : originalTitle,
                releaseDate: releaseDate,
                overview: item.overview ?? "",
                posterURL: posterURL,
                informationURL: "https://www.themoviedb.org/\(item.mediaType)/\(item.id)"
            )
        }
        .prefix(10)
        .map { $0 }
    }

    static func posterData(from url: URL?) async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }

    private static var accessToken: String? {
        let environmentValue = ProcessInfo.processInfo.environment["TMDB_READ_ACCESS_TOKEN"]
        return [environmentValue]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct TMDBSearchResponse: Decodable {
    let results: [TMDBSearchItem]
}

private struct TMDBSearchItem: Decodable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let releaseDate: String?
    let firstAirDate: String?
    let overview: String?
    let posterPath: String?
    let genreIDs: [Int]

    private enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case originalTitle = "original_title"
        case originalName = "original_name"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case overview
        case posterPath = "poster_path"
        case genreIDs = "genre_ids"
    }
}
