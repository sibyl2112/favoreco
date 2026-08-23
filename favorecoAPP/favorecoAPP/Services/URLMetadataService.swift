import Foundation
import LinkPresentation
import UIKit

struct URLMetadataCandidate: Sendable {
    let title: String
    let resolvedURL: URL
    let officialURL: URL?
    let purchaseURL: URL?
    let eventDate: Date?
    let eventEndDate: Date?
    let venueName: String
    let venueAddress: String
    let imageData: Data?
    let structuredType: String
    let structuredDateLabel: String
    let contributors: [URLContributorCandidate]
    let creditsText: String
}

struct URLContributorCandidate: Identifiable, Sendable {
    let name: String
    let roleKey: String
    let roleName: String

    var id: String { "\(roleKey):\(name)" }
}

enum URLMetadataService {
    nonisolated static func htmlMetadataForTesting(
        in html: String
    ) -> (title: String?, imageURLString: String?) {
        (
            htmlMetadataContent(property: "og:title", in: html) ?? htmlTitle(in: html),
            htmlMetadataContent(property: "og:image", in: html)
        )
    }

    nonisolated static func structuredMetadataForTesting(
        in html: String,
        sourceURL: URL
    ) -> (
        date: Date?,
        venueName: String,
        venueAddress: String,
        officialURL: URL?,
        purchaseURL: URL?,
        contributors: [URLContributorCandidate],
        creditsText: String
    ) {
        let data = pageData(in: html, sourceURL: sourceURL)
        return (
            data.date,
            data.venueName,
            data.venueAddress,
            data.officialURL,
            data.purchaseURL,
            data.contributors,
            data.creditsText
        )
    }

    @MainActor
    static func fetch(from rawValue: String, includesStructuredData: Bool = false) async throws -> URLMetadataCandidate {
        guard let url = normalizedURL(from: rawValue) else {
            throw URLMetadataError.invalidURL
        }

        let basicMetadata = try await fetchBasicMetadata(from: url)
        let title = basicMetadata.title
        let resolvedURL = basicMetadata.resolvedURL
        let structuredData = includesStructuredData
            ? (try? await fetchStructuredData(from: resolvedURL))
            : nil
        return URLMetadataCandidate(
            title: title,
            resolvedURL: resolvedURL,
            officialURL: structuredData?.officialURL ?? (isTicketingURL(resolvedURL) ? nil : resolvedURL),
            purchaseURL: structuredData?.purchaseURL,
            eventDate: structuredData?.date,
            eventEndDate: structuredData?.endDate,
            venueName: structuredData?.venueName ?? "",
            venueAddress: structuredData?.venueAddress ?? "",
            imageData: basicMetadata.imageData,
            structuredType: structuredData?.typeName ?? "",
            structuredDateLabel: structuredData.map { dateLabel(for: $0.typeName) } ?? "",
            contributors: structuredData?.contributors ?? [],
            creditsText: structuredData?.creditsText ?? ""
        )
    }

    @MainActor
    private static func fetchBasicMetadata(
        from url: URL
    ) async throws -> (title: String, resolvedURL: URL, imageData: Data?) {
        let provider = LPMetadataProvider()
        provider.timeout = 15
        if let metadata = try? await provider.startFetchingMetadata(for: url) {
            let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !title.isEmpty {
                let resolvedURL = metadata.originalURL ?? metadata.url ?? url
                let providerImageData = await loadImageData(from: metadata.imageProvider)
                var fallbackImageData: Data?
                if providerImageData == nil,
                   let fallbackMetadata = try? await fetchHTMLMetadata(from: resolvedURL) {
                    fallbackImageData = fallbackMetadata.imageData
                }
                return (title, resolvedURL, providerImageData ?? fallbackImageData)
            }
        }

        let metadata = try await fetchHTMLMetadata(from: url)
        return (metadata.title, metadata.resolvedURL, metadata.imageData)
    }

    @MainActor
    private static func fetchHTMLMetadata(
        from url: URL
    ) async throws -> (title: String, resolvedURL: URL, imageData: Data?) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Favoreco/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              data.count <= 5_000_000 else {
            throw URLMetadataError.titleNotFound
        }
        let encoding = String.Encoding.utf8
        guard let html = String(data: data, encoding: encoding),
              let title = htmlMetadataContent(property: "og:title", in: html) ?? htmlTitle(in: html),
              !title.isEmpty else {
            throw URLMetadataError.titleNotFound
        }
        let resolvedURL = httpResponse.url ?? url
        let imageData: Data?
        if let rawImageURL = htmlMetadataContent(property: "og:image", in: html),
           let imageURL = URL(string: rawImageURL, relativeTo: resolvedURL)?.absoluteURL {
            imageData = await downloadedImageData(from: imageURL)
        } else {
            imageData = nil
        }
        return (title, resolvedURL, imageData)
    }

    nonisolated private static func htmlTitle(in html: String) -> String? {
        let pattern = #"<title[^>]*>([\s\S]*?)</title>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                in: html,
                range: NSRange(html.startIndex..., in: html)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func htmlMetadataContent(
        property: String,
        in html: String
    ) -> String? {
        let escapedProperty = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            #"<meta[^>]+(?:property|name)\s*=\s*["']\#(escapedProperty)["'][^>]+content\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+(?:property|name)\s*=\s*["']\#(escapedProperty)["'][^>]*>"#,
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = expression.firstMatch(
                    in: html,
                    range: NSRange(html.startIndex..., in: html)
                  ),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            return decodedHTMLEntities(String(html[range]))
        }
        return nil
    }

    nonisolated private static func decodedHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private static func loadImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(
                    returning: (object as? UIImage)?.jpegData(compressionQuality: 0.9)
                )
            }
        }
    }

    @MainActor
    private static func downloadedImageData(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Favoreco/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              data.count <= 10_000_000,
              UIImage(data: data) != nil else { return nil }
        return data
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

        return pageData(in: html, sourceURL: httpResponse.url ?? url)
    }

    nonisolated private static func pageData(in html: String, sourceURL: URL) -> StructuredPageData {
        let structuredObject = jsonLDScriptData(in: html).lazy.compactMap { data -> [String: Any]? in
            guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return findSupportedObject(in: object)
        }.first
        let typeName = structuredObject.flatMap(supportedType(in:)) ?? inferredStructuredType(in: html)
        let description = pageDescription(in: html, structuredObject: structuredObject)
        let labeledContributors = contributorsFromLabels(in: description)
        let structuredContributors = structuredObject.map {
            contributors(from: $0, typeName: typeName)
        } ?? []
        let allContributors = mergedContributors(structuredContributors + labeledContributors)

        let date = structuredObject.flatMap { structuredDate(from: $0, typeName: typeName) }
            ?? firstJSONLDDate(key: "startDate", in: html)
            ?? labeledDate(in: description)
        let endDate = structuredObject.flatMap { parsedISODate($0["endDate"] as? String) }
            ?? firstJSONLDDate(key: "endDate", in: html)

        let structuredVenueName = structuredObject.map(venueName(from:)) ?? ""
        let fallbackVenueName = labeledValue(
            labels: ["会場", "開催場所", "場所", "劇場"],
            in: description
        )
        let resolvedVenueName = firstNonempty(structuredVenueName, fallbackVenueName)

        let structuredVenueAddress = structuredObject.map(venueAddress(from:)) ?? ""
        let fallbackAddress = labeledValue(
            labels: ["会場住所", "開催地住所", "住所"],
            in: description
        )
        let resolvedAddress = sanitizedAddress(firstNonempty(structuredVenueAddress, fallbackAddress))

        let explicitOfficialURL = labeledURL(
            labels: ["イベント公式サイト", "公演公式サイト", "公式サイト", "公式URL", "公式ページ"],
            in: description,
            relativeTo: sourceURL
        )
        let sourceIsTicketing = isTicketingURL(sourceURL)
        let officialURL = explicitOfficialURL ?? (sourceIsTicketing ? nil : sourceURL)
        let purchaseURL = sourceIsTicketing ? sourceURL : nil

        return StructuredPageData(
            typeName: typeName,
            date: date,
            endDate: endDate,
            venueName: sanitizedValue(resolvedVenueName),
            venueAddress: resolvedAddress,
            officialURL: officialURL,
            purchaseURL: purchaseURL,
            contributors: allContributors,
            creditsText: creditsText(
                description: description,
                contributors: allContributors
            )
        )
    }

    nonisolated private static func pageDescription(
        in html: String,
        structuredObject: [String: Any]?
    ) -> String {
        let candidates = [
            structuredObject?["description"] as? String,
            malformedJSONLDDescription(in: html),
            htmlMetadataContent(property: "og:description", in: html),
            htmlMetadataContent(property: "twitter:description", in: html),
            htmlMetadataContent(property: "description", in: html),
        ].compactMap { $0 }
        let value = candidates.max { lhs, rhs in
            descriptionScore(lhs) < descriptionScore(rhs)
        } ?? ""
        return normalizedMultilineText(value)
    }

    nonisolated private static func descriptionScore(_ value: String) -> Int {
        min(value.count, 20_000) + value.filter { $0.isNewline }.count * 200
    }

    nonisolated private static func malformedJSONLDDescription(in html: String) -> String? {
        firstRegexCapture(
            pattern: #"\"description\"\s*:\s*\"([\s\S]*?)\"\s*,\s*(?://|\"[A-Za-z@])"#,
            in: html
        )
    }

    nonisolated private static func normalizedMultilineText(_ value: String) -> String {
        decodedHTMLEntities(value)
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"[\t　]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #" *\n *"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func labeledValue(labels: [String], in text: String) -> String {
        guard !text.isEmpty else { return "" }
        let alternatives = labels
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let knownLabels = [
            "開催日時", "開催日", "公演日", "日時", "会場住所", "開催地住所", "住所",
            "会場", "開催場所", "場所", "劇場", "出演者", "出演", "キャスト",
            "イベント公式サイト", "公演公式サイト", "公式サイト", "公式URL", "公式ページ",
            "公演団体", "上演団体", "劇団", "主催", "主催者", "企画", "制作", "製作",
            "協力", "運営協力", "料金", "チケット", "販売期間", "当落発表",
        ]
        let stopAlternatives = knownLabels
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let pattern = #"(?im)(?:^|[\n\t　 ]|[-=]{5,})\s*(?:\#(alternatives))\s*[：:]\s*(.+?)(?=(?:[\n\t　 ]|[-=]{5,})\s*(?:\#(stopAlternatives))\s*[：:]|[-=]{5,}|【|●|◆|◇|■|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return "" }
        return sanitizedValue(String(text[range]))
    }

    nonisolated private static func labeledURL(
        labels: [String],
        in text: String,
        relativeTo sourceURL: URL
    ) -> URL? {
        let value = labeledValue(labels: labels, in: text)
        guard !value.isEmpty else { return nil }
        let pattern = #"https?://[^\s<>\"'）)]+"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let range = Range(match.range, in: value) else { return nil }
        let rawURL = String(value[range]).trimmingCharacters(in: CharacterSet(charactersIn: "。、,;；"))
        return URL(string: rawURL, relativeTo: sourceURL)?.absoluteURL
    }

    nonisolated private static func contributorsFromLabels(in text: String) -> [URLContributorCandidate] {
        let definitions: [(labels: [String], roleKey: String, roleName: String)] = [
            (["公演団体", "上演団体", "劇団"], "performing_organization", "公演団体"),
            (["主催", "主催者"], "organizer", "主催"),
            (["企画"], "planning", "企画"),
            (["制作", "製作"], "production", "制作"),
            (["協力", "運営協力"], "other", "協力"),
        ]
        return definitions.compactMap { definition in
            let value = labeledValue(labels: definition.labels, in: text)
            guard !value.isEmpty else { return nil }
            return URLContributorCandidate(
                name: value,
                roleKey: definition.roleKey,
                roleName: definition.roleName
            )
        }
    }

    nonisolated private static func mergedContributors(
        _ values: [URLContributorCandidate]
    ) -> [URLContributorCandidate] {
        var seen = Set<String>()
        return values.filter { contributor in
            let key = "\(contributor.roleKey):\(contributor.name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current))"
            return seen.insert(key).inserted
        }
    }

    nonisolated private static func creditsText(
        description: String,
        contributors: [URLContributorCandidate]
    ) -> String {
        let performers = labeledBlock(
            labels: ["出演者", "出演", "キャスト"],
            stopLabels: ["料金", "チケット", "販売期間", "入場順", "注意事項", "イベント公式サイト", "主催", "企画", "制作", "協力"],
            in: description
        )
        var lines = contributors
            .filter { $0.roleKey != "cast" || performers.isEmpty }
            .map { "\($0.roleName)：\($0.name)" }
        if !performers.isEmpty {
            lines.append("出演者：\n\(performers)")
        }
        return lines.joined(separator: "\n")
    }

    nonisolated private static func labeledBlock(
        labels: [String],
        stopLabels: [String],
        in text: String
    ) -> String {
        let lines = text.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { line in
            labels.contains { label in
                line.range(
                    of: #"^\s*\#(NSRegularExpression.escapedPattern(for: label))\s*[：:]"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
            }
        }) else { return "" }

        let labelPattern = labels
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        var result: [String] = []
        let first = lines[start].replacingOccurrences(
            of: #"^\s*(?:\#(labelPattern))\s*[：:]\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        if !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(first)
        }

        for line in lines.dropFirst(start + 1).prefix(40) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: #"^[-=ー―]{5,}"#, options: .regularExpression) != nil { break }
            if stopLabels.contains(where: { label in
                trimmed.range(
                    of: #"^[●◆◇■]?\s*\#(NSRegularExpression.escapedPattern(for: label))\s*[：:]"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
            }) { break }
            if !trimmed.isEmpty { result.append(trimmed) }
        }
        return result.joined(separator: "\n").prefix(2_000).description
    }

    nonisolated private static func labeledDate(in text: String) -> Date? {
        let value = labeledValue(labels: ["開催日時", "開催日", "公演日", "日時"], in: text)
        return parsedISODate(value)
    }

    nonisolated private static func firstJSONLDDate(key: String, in html: String) -> Date? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #"\"\#(escapedKey)\"\s*:\s*\"([^\"]+)\""#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                in: html,
                range: NSRange(html.startIndex..., in: html)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return parsedISODate(String(html[range]))
    }

    nonisolated private static func inferredStructuredType(in html: String) -> String {
        guard let type = firstRegexCapture(
            pattern: #"\"@type\"\s*:\s*\"([^\"]+)\""#,
            in: html
        ) else { return "" }
        return type.lowercased().hasSuffix("event") ? "Event" : type
    }

    nonisolated private static func firstRegexCapture(pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    nonisolated private static func firstNonempty(_ values: String...) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    nonisolated private static func sanitizedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func sanitizedAddress(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare("NaN") != .orderedSame }
            .joined(separator: " ")
    }

    nonisolated private static func isTicketingURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let ticketHosts = [
            "tiget.net", "eplus.jp", "pia.jp", "ticket.pia.jp", "l-tike.com",
            "livepocket.jp", "teket.jp", "zaiko.io", "ticketbook.jp",
            "passmarket.yahoo.co.jp", "rakuten-ticket.com",
        ]
        return ticketHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    nonisolated private static func jsonLDScriptData(in html: String) -> [Data] {
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

    nonisolated private static func findSupportedObject(in object: Any) -> [String: Any]? {
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

    nonisolated private static func supportedType(in dictionary: [String: Any]) -> String? {
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

    nonisolated private static func structuredDate(from object: [String: Any], typeName: String) -> Date? {
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

    nonisolated private static func contributors(from object: [String: Any], typeName: String) -> [URLContributorCandidate] {
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

    nonisolated private static func names(from value: Any?) -> [String] {
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

    nonisolated private static func normalizedNames(_ names: [String]) -> [String] {
        names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    nonisolated private static func parsedISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dayFormatter.date(from: value) { return date }

        let pattern = #"(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日(?:\([^)]*\))?(?:[T\s]*(\d{1,2}):(\d{2}))?"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              match.numberOfRanges >= 4 else { return nil }
        func integer(at index: Int) -> Int? {
            guard index < match.numberOfRanges,
                  match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: value) else { return nil }
            return Int(value[range])
        }
        guard let year = integer(at: 1),
              let month = integer(at: 2),
              let day = integer(at: 3) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: integer(at: 4) ?? 0,
                minute: integer(at: 5) ?? 0
            )
        )
    }

    nonisolated private static func venueName(from event: [String: Any]) -> String {
        if let location = event["location"] as? [String: Any] {
            return (location["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if let locations = event["location"] as? [[String: Any]] {
            return (locations.first?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return ""
    }

    nonisolated private static func venueAddress(from event: [String: Any]) -> String {
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
    let endDate: Date?
    let venueName: String
    let venueAddress: String
    let officialURL: URL?
    let purchaseURL: URL?
    let contributors: [URLContributorCandidate]
    let creditsText: String
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
