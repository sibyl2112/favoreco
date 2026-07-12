import Foundation
import LinkPresentation

struct URLMetadataCandidate: Sendable {
    let title: String
    let resolvedURL: URL
    let eventDate: Date?
    let venueName: String
    let venueAddress: String
    let structuredType: String
    let structuredDateLabel: String
    let contributors: [URLContributorCandidate]
}

struct URLContributorCandidate: Identifiable, Sendable {
    let name: String
    let roleKey: String
    let roleName: String

    var id: String { "\(roleKey):\(name)" }
}

enum URLMetadataService {
    @MainActor
    static func fetch(from rawValue: String, includesStructuredData: Bool = false) async throws -> URLMetadataCandidate {
        guard let url = normalizedURL(from: rawValue) else {
            throw URLMetadataError.invalidURL
        }

        let provider = LPMetadataProvider()
        provider.timeout = 15
        let metadata = try await provider.startFetchingMetadata(for: url)
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            throw URLMetadataError.titleNotFound
        }
        let resolvedURL = metadata.originalURL ?? metadata.url ?? url
        let structuredData = includesStructuredData
            ? (try? await fetchStructuredData(from: resolvedURL))
            : nil
        return URLMetadataCandidate(
            title: title,
            resolvedURL: resolvedURL,
            eventDate: structuredData?.date,
            venueName: structuredData?.venueName ?? "",
            venueAddress: structuredData?.venueAddress ?? "",
            structuredType: structuredData?.typeName ?? "",
            structuredDateLabel: structuredData.map { dateLabel(for: $0.typeName) } ?? "",
            contributors: structuredData?.contributors ?? []
        )
    }

    nonisolated static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    private static func fetchStructuredData(from url: URL) async throws -> StructuredPageData? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Favoreco/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              data.count <= 5_000_000,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        for jsonData in jsonLDScriptData(in: html) {
            guard let object = try? JSONSerialization.jsonObject(with: jsonData),
                  let candidate = findSupportedObject(in: object) else { continue }
            let typeName = supportedType(in: candidate) ?? ""
            return StructuredPageData(
                typeName: typeName,
                date: structuredDate(from: candidate, typeName: typeName),
                venueName: typeName == "Event" ? venueName(from: candidate) : "",
                venueAddress: typeName == "Event" ? venueAddress(from: candidate) : "",
                contributors: contributors(from: candidate, typeName: typeName)
            )
        }
        return nil
    }

    private static func jsonLDScriptData(in html: String) -> [Data] {
        let pattern = #"<script[^>]*type\s*=\s*[\"']application/ld\+json[\"'][^>]*>([\s\S]*?)</script>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return expression.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[swiftRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .data(using: .utf8)
        }
    }

    private static func findSupportedObject(in object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            if supportedType(in: dictionary) != nil {
                return dictionary
            }
            for value in dictionary.values {
                if let candidate = findSupportedObject(in: value) { return candidate }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let candidate = findSupportedObject(in: value) { return candidate }
            }
        }
        return nil
    }

    private static func supportedType(in dictionary: [String: Any]) -> String? {
        let rawTypes: [String]
        if let type = dictionary["@type"] as? String {
            rawTypes = [type]
        } else {
            rawTypes = dictionary["@type"] as? [String] ?? []
        }
        if rawTypes.contains(where: { $0.caseInsensitiveCompare("Event") == .orderedSame || $0.lowercased().hasSuffix("event") }) {
            return "Event"
        }
        return ["Book", "Movie"].first { supported in
            rawTypes.contains { $0.caseInsensitiveCompare(supported) == .orderedSame }
        }
    }

    private static func structuredDate(from object: [String: Any], typeName: String) -> Date? {
        let keys = typeName == "Event"
            ? ["startDate"]
            : ["datePublished", "dateCreated", "releaseDate"]
        return keys.lazy.compactMap { parsedISODate(object[$0] as? String) }.first
    }

    private static func dateLabel(for typeName: String) -> String {
        switch typeName {
        case "Book": return "発売日"
        case "Movie": return "公開日"
        default: return "開催日時"
        }
    }

    private static func contributors(from object: [String: Any], typeName: String) -> [URLContributorCandidate] {
        let fields: [(key: String, roleKey: String, roleName: String)]
        switch typeName {
        case "Book":
            fields = [("author", "author", "作者"), ("translator", "translator", "翻訳"), ("publisher", "publisher", "出版社")]
        case "Movie":
            fields = [("director", "director", "監督"), ("actor", "cast", "出演"), ("author", "screenplay", "脚本")]
        default:
            fields = [("performer", "cast", "出演"), ("organizer", "organizer", "主催")]
        }

        var seen = Set<String>()
        return fields.flatMap { field in
            names(from: object[field.key]).compactMap { name in
                let key = "\(field.roleKey):\(name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current))"
                guard seen.insert(key).inserted else { return nil }
                return URLContributorCandidate(name: name, roleKey: field.roleKey, roleName: field.roleName)
            }
        }
    }

    private static func names(from value: Any?) -> [String] {
        if let name = value as? String {
            return normalizedNames([name])
        }
        if let dictionary = value as? [String: Any] {
            return normalizedNames([dictionary["name"] as? String].compactMap { $0 })
        }
        if let values = value as? [Any] {
            return normalizedNames(values.flatMap { names(from: $0) })
        }
        return []
    }

    private static func normalizedNames(_ names: [String]) -> [String] {
        names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func parsedISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return dayFormatter.date(from: value)
    }

    private static func venueName(from event: [String: Any]) -> String {
        if let location = event["location"] as? [String: Any] {
            return (location["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if let locations = event["location"] as? [[String: Any]] {
            return (locations.first?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return ""
    }

    private static func venueAddress(from event: [String: Any]) -> String {
        let location: [String: Any]?
        if let value = event["location"] as? [String: Any] {
            location = value
        } else {
            location = (event["location"] as? [[String: Any]])?.first
        }
        guard let address = location?["address"] else { return "" }
        if let value = address as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let dictionary = address as? [String: Any] else { return "" }
        return ["postalCode", "addressRegion", "addressLocality", "streetAddress"]
            .compactMap { dictionary[$0] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct StructuredPageData {
    let typeName: String
    let date: Date?
    let venueName: String
    let venueAddress: String
    let contributors: [URLContributorCandidate]
}

enum URLMetadataError: LocalizedError {
    case invalidURL
    case titleNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "httpまたはhttpsのURLを入力してください。"
        case .titleNotFound:
            return "このページからタイトルを取得できませんでした。"
        }
    }
}
