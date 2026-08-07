import Foundation
import Vision

struct BookMetadataCandidate: Identifiable, Sendable {
    let id = UUID()
    let isbn: String
    let title: String
    let authors: [String]
    let publisher: String
    let publishedDate: String
    let informationURL: String
    let coverURL: URL?
    let sourceName: String

    var authorText: String {
        authors.joined(separator: "、")
    }
}

enum BookMetadataLookupError: LocalizedError {
    case invalidISBN
    case notFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidISBN:
            "ISBNを確認してください。10桁または13桁で入力できます。"
        case .notFound:
            "このISBNの本を見つけられませんでした。手入力で続けられます。"
        case .invalidResponse:
            "本の情報を取得できませんでした。通信環境を確認して、もう一度お試しください。"
        }
    }
}

enum BookMetadataLookupService {
    nonisolated static func normalizedISBN(_ rawValue: String) -> String? {
        let value = rawValue
            .uppercased()
            .filter { $0.isNumber || $0 == "X" }
        guard value.count == 10 || value.count == 13 else { return nil }
        return value
    }

    static func lookup(isbn rawValue: String) async throws -> BookMetadataCandidate {
        guard let isbn = normalizedISBN(rawValue) else {
            throw BookMetadataLookupError.invalidISBN
        }

        if let googleCandidate = try? await lookupGoogleBooks(isbn: isbn) {
            return googleCandidate
        }
        if let openLibraryCandidate = try? await lookupOpenLibrary(isbn: isbn) {
            return openLibraryCandidate
        }
        throw BookMetadataLookupError.notFound
    }

    nonisolated static func isbnCandidates(from text: String) -> [String] {
        let pattern = #"(?i)(?:ISBN(?:-1[03])?[:：]?\s*)?([0-9X][0-9X\-\s]{8,20}[0-9X])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        for match in expression.matches(in: text, range: range) {
            guard let candidateRange = Range(match.range(at: 1), in: text),
                  let normalized = normalizedISBN(String(text[candidateRange])),
                  !values.contains(normalized) else { continue }
            values.append(normalized)
        }
        return values
    }

    nonisolated static func isbnCandidates(fromImageData data: Data) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.ean13]
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            return normalizedISBN(payload)
        }
    }

    static func coverData(from url: URL?) async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }

    private static func lookupGoogleBooks(isbn: String) async throws -> BookMetadataCandidate {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
            URLQueryItem(name: "maxResults", value: "1"),
            URLQueryItem(name: "printType", value: "books"),
        ]
        guard let url = components?.url else { throw BookMetadataLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw BookMetadataLookupError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
        guard let item = decoded.items?.first,
              !item.volumeInfo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BookMetadataLookupError.notFound
        }
        let resolvedISBN = item.volumeInfo.industryIdentifiers?
            .compactMap { normalizedISBN($0.identifier) }
            .first(where: { $0.count == 13 }) ?? isbn
        return BookMetadataCandidate(
            isbn: resolvedISBN,
            title: item.volumeInfo.title,
            authors: item.volumeInfo.authors ?? [],
            publisher: item.volumeInfo.publisher ?? "",
            publishedDate: item.volumeInfo.publishedDate ?? "",
            informationURL: item.volumeInfo.infoLink ?? "",
            coverURL: secureURL(item.volumeInfo.imageLinks?.thumbnail),
            sourceName: "Google Books"
        )
    }

    private static func lookupOpenLibrary(isbn: String) async throws -> BookMetadataCandidate {
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "isbn", value: isbn),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(
                name: "fields",
                value: "key,title,author_name,publisher,first_publish_year,cover_i,isbn"
            ),
        ]
        guard let url = components?.url else { throw BookMetadataLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw BookMetadataLookupError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
        guard let item = decoded.docs.first,
              !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BookMetadataLookupError.notFound
        }
        let resolvedISBN = item.isbn?
            .compactMap(normalizedISBN)
            .first(where: { $0.count == 13 }) ?? isbn
        let coverURL = item.coverID.flatMap {
            URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg")
        }
        let informationURL = item.key.map { "https://openlibrary.org\($0)" } ?? ""
        return BookMetadataCandidate(
            isbn: resolvedISBN,
            title: item.title,
            authors: item.authors ?? [],
            publisher: item.publishers?.first ?? "",
            publishedDate: item.firstPublishYear.map(String.init) ?? "",
            informationURL: informationURL,
            coverURL: coverURL,
            sourceName: "Open Library"
        )
    }

    private static func secureURL(_ rawValue: String?) -> URL? {
        guard var components = rawValue.flatMap(URLComponents.init(string:)) else { return nil }
        components.scheme = "https"
        return components.url
    }
}

private struct GoogleBooksResponse: Decodable {
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Decodable {
    let volumeInfo: GoogleBooksVolumeInfo
}

private struct GoogleBooksVolumeInfo: Decodable {
    let title: String
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let industryIdentifiers: [GoogleBooksIdentifier]?
    let imageLinks: GoogleBooksImageLinks?
    let infoLink: String?
}

private struct GoogleBooksIdentifier: Decodable {
    let identifier: String
}

private struct GoogleBooksImageLinks: Decodable {
    let thumbnail: String?
}

private struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryBook]
}

private struct OpenLibraryBook: Decodable {
    let key: String?
    let title: String
    let authors: [String]?
    let publishers: [String]?
    let firstPublishYear: Int?
    let coverID: Int?
    let isbn: [String]?

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case authors = "author_name"
        case publishers = "publisher"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case isbn
    }
}
