import Foundation
import LinkPresentation

struct URLMetadataCandidate: Sendable {
    let title: String
    let resolvedURL: URL
    let eventDate: Date?
    let venueName: String
    let venueAddress: String
}

enum URLMetadataService {
    @MainActor
    static func fetch(from rawValue: String, includesStructuredEventData: Bool = false) async throws -> URLMetadataCandidate {
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
        let eventData = includesStructuredEventData
            ? (try? await fetchStructuredEventData(from: resolvedURL))
            : nil
        return URLMetadataCandidate(
            title: title,
            resolvedURL: resolvedURL,
            eventDate: eventData?.date,
            venueName: eventData?.venueName ?? "",
            venueAddress: eventData?.venueAddress ?? ""
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

    private static func fetchStructuredEventData(from url: URL) async throws -> StructuredEventData? {
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
                  let event = findEventObject(in: object) else { continue }
            return StructuredEventData(
                date: parsedISODate(event["startDate"] as? String),
                venueName: venueName(from: event),
                venueAddress: venueAddress(from: event)
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

    private static func findEventObject(in object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            let typeValue = dictionary["@type"]
            let types: [String]
            if let type = typeValue as? String {
                types = [type]
            } else {
                types = typeValue as? [String] ?? []
            }
            if types.contains(where: { $0.caseInsensitiveCompare("Event") == .orderedSame }) {
                return dictionary
            }
            for value in dictionary.values {
                if let event = findEventObject(in: value) { return event }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let event = findEventObject(in: value) { return event }
            }
        }
        return nil
    }

    private static func parsedISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
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

private struct StructuredEventData {
    let date: Date?
    let venueName: String
    let venueAddress: String
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
