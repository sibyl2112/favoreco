import Foundation
import Vision

struct BookMetadataCandidate: Identifiable, Sendable {
    let id = UUID()
    let isbn: String
    let title: String
    let authors: [String]
    let translators: [String]
    let publisher: String
    let publishedDate: String
    let priceText: String
    let pageCount: Int
    let informationURL: String
    let coverURL: URL?
    let sourceName: String

    var authorText: String {
        authors.joined(separator: "、")
    }

    var translatorText: String {
        translators.joined(separator: "、")
    }
}

struct BookOCRMetadataCandidate: Equatable, Sendable {
    let title: String
    let alternateTitles: [String]
    let seriesName: String
    let volumeNumber: String
    let author: String
    let publisher: String
    let publishedDate: String
    let pageCount: Int

    var hasStructuredMetadata: Bool {
        !author.isEmpty || !publisher.isEmpty || !publishedDate.isEmpty || pageCount > 0
    }

    var detectedFieldNames: [String] {
        var values: [String] = []
        if !title.isEmpty { values.append("書名") }
        if !volumeNumber.isEmpty { values.append("巻数") }
        if !author.isEmpty { values.append("著者") }
        if !publisher.isEmpty { values.append("出版社") }
        if !publishedDate.isEmpty { values.append("発行日") }
        if pageCount > 0 { values.append("ページ数") }
        return values
    }
}

enum BookMetadataLookupError: LocalizedError {
    case invalidISBN
    case notFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidISBN:
            "ISBNを確認してください。ISBN-10、または978・979から始まるISBN-13を入力できます。"
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
        guard isValidISBN(value) else { return nil }
        return value
    }

    static func lookup(isbn rawValue: String) async throws -> BookMetadataCandidate {
        guard let isbn = normalizedISBN(rawValue) else {
            throw BookMetadataLookupError.invalidISBN
        }

        let lookupISBN = isbn13(from: isbn) ?? isbn
        if let openBDCandidate = try? await lookupOpenBD(isbn: lookupISBN) {
            return openBDCandidateWithCoverFallback(openBDCandidate)
        }
        if let googleCandidate = try? await lookupGoogleBooks(isbn: lookupISBN) {
            return googleCandidate
        }
        if let openLibraryCandidate = try? await lookupOpenLibrary(isbn: lookupISBN) {
            return openLibraryCandidate
        }
        throw BookMetadataLookupError.notFound
    }

    static func reverseLookup(
        from metadata: BookOCRMetadataCandidate
    ) async -> BookMetadataCandidate? {
        guard !metadata.title.isEmpty else { return nil }
        guard let data = try? await fetchNDLSearchData(for: metadata) else { return nil }
        let candidates = ndlCandidates(from: data)
        guard let matchedISBN = confidentNDLISBN(
            from: candidates,
            matching: metadata
        ) else { return nil }
        if let canonical = try? await lookup(isbn: matchedISBN) {
            return canonical
        }
        return BookMetadataCandidate(
            isbn: matchedISBN,
            title: metadata.title,
            authors: metadata.author.isEmpty ? [] : [metadata.author],
            translators: [],
            publisher: metadata.publisher,
            publishedDate: metadata.publishedDate,
            priceText: "",
            pageCount: metadata.pageCount,
            informationURL: "",
            coverURL: booksOrJPCoverURL(isbn: matchedISBN),
            sourceName: "国立国会図書館サーチ"
        )
    }

    nonisolated static func ndlReverseLookupISBN(
        from data: Data,
        matching metadata: BookOCRMetadataCandidate
    ) -> String? {
        confidentNDLISBN(from: ndlCandidates(from: data), matching: metadata)
    }

    nonisolated static func openBDCandidate(
        from data: Data,
        requestedISBN: String
    ) throws -> BookMetadataCandidate {
        let decoded = try JSONDecoder().decode([OpenBDEntry?].self, from: data)
        guard let entry = decoded.first.flatMap({ $0 }),
              let summary = entry.summary,
              !summary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BookMetadataLookupError.notFound
        }
        let resolvedISBN = normalizedISBN(summary.isbn) ?? requestedISBN
        let author = normalizedAuthorName(summary.author)
        let summaryCoverURL = secureURL(summary.cover)
        return BookMetadataCandidate(
            isbn: resolvedISBN,
            title: summary.title,
            authors: author.isEmpty ? [] : [author],
            translators: openBDTranslators(from: entry),
            publisher: summary.publisher,
            publishedDate: normalizedOpenBDDate(summary.publicationDate),
            priceText: openBDPriceText(from: entry),
            pageCount: openBDPageCount(from: entry),
            informationURL: "https://www.books.or.jp/book-details/\(resolvedISBN)",
            coverURL: summaryCoverURL ?? booksOrJPCoverURL(isbn: resolvedISBN),
            sourceName: "openBD"
        )
    }

    nonisolated static func ocrMetadata(from text: String) -> BookOCRMetadataCandidate {
        let lines = text
            .components(separatedBy: .newlines)
            .map(normalizedOCRLine)
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            return BookOCRMetadataCandidate(
                title: "",
                alternateTitles: [],
                seriesName: "",
                volumeNumber: "",
                author: "",
                publisher: "",
                publishedDate: "",
                pageCount: 0
            )
        }

        let dateMatch = lines.enumerated().compactMap { index, line in
            normalizedJapaneseDate(in: line).map { (index, $0) }
        }.first
        let authorLabelIndex = lines.firstIndex { compactOCRLabel($0) == "著者" }
        let titleAnchor = dateMatch?.0 ?? authorLabelIndex ?? min(lines.count, 12)
        let titlePool = Array(lines.prefix(titleAnchor))
        let titleCandidates = uniqueOCRValues(
            titlePool.reversed().filter(isPlausibleBookTitle).prefix(2).map { $0 }
        )
        let title = titleCandidates.first ?? ""
        let author = inlineOCRValue(labels: ["著者"], in: lines)
            ?? inferredAuthor(after: authorLabelIndex, in: lines)
            ?? ""
        let publisher = inlineOCRValue(labels: ["発行所", "出版社"], in: lines)
            ?? inferredPublisher(in: lines)
            ?? ""

        return BookOCRMetadataCandidate(
            title: title,
            alternateTitles: Array(titleCandidates.dropFirst()),
            // シリーズ・巻数は書名の文字列から推測しない。
            // ISBNの書誌情報に含まれず、OCRでも誤判定しやすいため手入力で確定する。
            seriesName: "",
            volumeNumber: "",
            author: normalizedAuthorName(author),
            publisher: normalizedPublisherName(publisher),
            publishedDate: dateMatch?.1 ?? "",
            pageCount: inferredPageCount(in: lines)
        )
    }

    nonisolated static func isbnCandidates(from text: String) -> [String] {
        // `\s` also matches line breaks and can join the ISBN barcode number with the
        // price-code number printed below it. Keep separators horizontal so each
        // printed number is validated independently.
        let pattern = #"(?i)(?:ISBN(?:-1[03])?[:：]?\h*)?([0-9X][0-9X\-\h]{8,20}[0-9X])"#
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
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Favoreco/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        if url.host == "thumbnail-s.images.books.or.jp" {
            request.setValue("https://www.books.or.jp/", forHTTPHeaderField: "Referer")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }

    private static func fetchNDLSearchData(
        for metadata: BookOCRMetadataCandidate
    ) async throws -> Data {
        var components = URLComponents(string: "https://ndlsearch.ndl.go.jp/api/opensearch")
        var queryItems = [
            URLQueryItem(name: "title", value: metadata.title),
            URLQueryItem(name: "cnt", value: "10"),
        ]
        if !metadata.author.isEmpty {
            queryItems.append(URLQueryItem(name: "creator", value: metadata.author))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw BookMetadataLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/rss+xml, application/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else {
            throw BookMetadataLookupError.invalidResponse
        }
        return data
    }

    private nonisolated static func ndlCandidates(from data: Data) -> [NDLBookCandidate] {
        let parser = XMLParser(data: data)
        let delegate = NDLSearchParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        return delegate.candidates
    }

    private nonisolated static func confidentNDLISBN(
        from candidates: [NDLBookCandidate],
        matching metadata: BookOCRMetadataCandidate
    ) -> String? {
        let scored = candidates.compactMap { candidate -> (String, Int)? in
            guard let isbn = normalizedISBN(candidate.isbn) else { return nil }
            return (isbn, reverseLookupScore(candidate, metadata: metadata))
        }.sorted { lhs, rhs in lhs.1 > rhs.1 }
        guard let first = scored.first, first.1 >= 6 else { return nil }
        if scored.count > 1, scored[1].1 >= first.1 - 1 { return nil }
        return first.0
    }

    private nonisolated static func reverseLookupScore(
        _ candidate: NDLBookCandidate,
        metadata: BookOCRMetadataCandidate
    ) -> Int {
        let queryTitle = normalizedMatchText(metadata.title)
        let resultTitle = normalizedMatchText(candidate.title)
        guard !resultTitle.isEmpty,
              queryTitle.contains(resultTitle) || resultTitle.contains(queryTitle) else {
            return 0
        }

        var score = queryTitle == resultTitle ? 7 : 4
        let queryAuthor = normalizedMatchText(metadata.author)
        let resultAuthor = normalizedMatchText(candidate.author)
        if !queryAuthor.isEmpty, !resultAuthor.isEmpty,
           queryAuthor.contains(resultAuthor) || resultAuthor.contains(queryAuthor) {
            score += 3
        }
        let queryPublisher = normalizedMatchText(metadata.publisher)
        let resultPublisher = normalizedMatchText(candidate.publisher)
        if !queryPublisher.isEmpty, !resultPublisher.isEmpty,
           queryPublisher.contains(resultPublisher) || resultPublisher.contains(queryPublisher) {
            score += 2
        }
        if !metadata.volumeNumber.isEmpty,
           normalizedMatchText(candidate.volume) == normalizedMatchText(metadata.volumeNumber) {
            score += 3
        }
        if !candidate.edition.isEmpty,
           queryTitle.contains(normalizedMatchText(candidate.edition)) {
            score += 2
        }
        if metadata.publishedDate.count >= 4,
           candidate.date.hasPrefix(String(metadata.publishedDate.prefix(4))) {
            score += 1
        }
        return score
    }

    private nonisolated static func normalizedMatchText(_ value: String) -> String {
        let halfwidth = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        return halfwidth
            .lowercased()
            .replacingOccurrences(
                of: #"[\h　\p{P}\p{S}]"#,
                with: "",
                options: .regularExpression
            )
    }

    private nonisolated static func openBDCandidateWithCoverFallback(
        _ candidate: BookMetadataCandidate
    ) -> BookMetadataCandidate {
        guard candidate.coverURL == nil else { return candidate }
        return BookMetadataCandidate(
            isbn: candidate.isbn,
            title: candidate.title,
            authors: candidate.authors,
            translators: candidate.translators,
            publisher: candidate.publisher,
            publishedDate: candidate.publishedDate,
            priceText: candidate.priceText,
            pageCount: candidate.pageCount,
            informationURL: candidate.informationURL,
            coverURL: booksOrJPCoverURL(isbn: candidate.isbn),
            sourceName: candidate.sourceName
        )
    }

    private static func lookupOpenBD(isbn: String) async throws -> BookMetadataCandidate {
        var components = URLComponents(string: "https://api.openbd.jp/v1/get")
        components?.queryItems = [URLQueryItem(name: "isbn", value: isbn)]
        guard let url = components?.url else { throw BookMetadataLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw BookMetadataLookupError.invalidResponse
        }
        return try openBDCandidate(from: data, requestedISBN: isbn)
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
            translators: [],
            publisher: item.volumeInfo.publisher ?? "",
            publishedDate: item.volumeInfo.publishedDate ?? "",
            priceText: googleBooksPriceText(item.saleInfo),
            pageCount: max(item.volumeInfo.pageCount ?? 0, 0),
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
                value: "key,title,author_name,publisher,first_publish_year,cover_i,isbn,number_of_pages_median"
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
            translators: [],
            publisher: item.publishers?.first ?? "",
            publishedDate: item.firstPublishYear.map(String.init) ?? "",
            priceText: "",
            pageCount: max(item.pageCount ?? 0, 0),
            informationURL: informationURL,
            coverURL: coverURL,
            sourceName: "Open Library"
        )
    }

    private nonisolated static func secureURL(_ rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              var components = URLComponents(string: rawValue) else { return nil }
        components.scheme = "https"
        return components.url
    }

    private nonisolated static func booksOrJPCoverURL(isbn: String) -> URL? {
        URL(string: "https://thumbnail-s.images.books.or.jp/\(isbn).jpg")
    }

    private nonisolated static func normalizedAuthorName(_ rawValue: String) -> String {
        let value = normalizedOCRLine(rawValue)
        let pattern = #"(?<=[\p{Han}\p{Hiragana}\p{Katakana}]),\h*(?=[\p{Han}\p{Hiragana}\p{Katakana}])"#
        return value.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #",\h*[12][0-9]{3}-?.*$"#,
            with: "",
            options: .regularExpression
        )
    }

    private nonisolated static func openBDTranslators(from entry: OpenBDEntry) -> [String] {
        let translatorRoles = Set(["B06", "B08"])
        return entry.onix?.descriptiveDetail?.contributors?
            .filter { contributor in
                !translatorRoles.isDisjoint(with: contributor.roles ?? [])
            }
            .compactMap { contributor in
                let name = contributor.personName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? nil : normalizedAuthorName(name)
            } ?? []
    }

    private nonisolated static func openBDPriceText(from entry: OpenBDEntry) -> String {
        let prices = entry.onix?.productSupply?.supplyDetail?.prices ?? []
        let preferred = prices.first { price in
            (price.currencyCode?.isEmpty ?? true) || price.currencyCode == "JPY"
        }
        return preferred?.priceAmount?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private nonisolated static func openBDPageCount(from entry: OpenBDEntry) -> Int {
        let extents = entry.onix?.descriptiveDetail?.extents ?? []
        let preferred = extents.first { $0.extentType == "00" } ?? extents.first
        return max(Int(preferred?.extentValue ?? "") ?? 0, 0)
    }

    private nonisolated static func googleBooksPriceText(_ saleInfo: GoogleBooksSaleInfo?) -> String {
        guard let price = saleInfo?.listPrice ?? saleInfo?.retailPrice,
              price.currencyCode == nil || price.currencyCode == "JPY" else { return "" }
        let amount = price.amount
        guard amount > 0 else { return "" }
        return amount.rounded() == amount
            ? String(Int(amount))
            : String(format: "%.2f", amount)
    }

    private nonisolated static func normalizedPublisherName(_ rawValue: String) -> String {
        normalizedOCRLine(rawValue)
            .replacingOccurrences(of: #"^(?:株式会社|有限会社)\h*"#, with: "", options: .regularExpression)
    }

    private nonisolated static func normalizedOCRLine(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: #"[\h　]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func compactOCRLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[\h　:：]"#, with: "", options: .regularExpression)
    }

    private nonisolated static func inlineOCRValue(
        labels: [String],
        in lines: [String]
    ) -> String? {
        for line in lines {
            let compact = compactOCRLabel(line)
            for label in labels where compact.hasPrefix(label) {
                let value = String(compact.dropFirst(label.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private nonisolated static func inferredAuthor(
        after labelIndex: Int?,
        in lines: [String]
    ) -> String? {
        let start = labelIndex.map { min($0 + 1, lines.count) } ?? 0
        return lines.dropFirst(start).first { line in
            let compact = compactOCRLabel(line)
            guard compact.count >= 2,
                  compact.count <= 14,
                  compact.range(of: #"[\p{Han}]"#, options: .regularExpression) != nil,
                  compact.range(of: #"[0-9０-９]"#, options: .regularExpression) == nil else {
                return false
            }
            let excluded = [
                "発行者", "発行所", "出版社", "印刷所", "製版所", "製本所",
                "株式会社", "有限会社", "編集", "販売", "業務", "電話", "住所",
                "著作権", "禁無断", "Printed", "Japan"
            ]
            return !excluded.contains { compact.contains($0) }
        }
    }

    private nonisolated static func inferredPublisher(in lines: [String]) -> String? {
        let labelIndex = lines.firstIndex {
            let compact = compactOCRLabel($0)
            return compact == "発行所" || compact == "出版社"
        }
        let start = labelIndex.map { min($0 + 1, lines.count) } ?? 0
        let searchLines = Array(lines.dropFirst(start)) + Array(lines.prefix(start))
        return searchLines.first { line in
            let compact = compactOCRLabel(line)
            guard !compact.contains("印刷"),
                  !compact.contains("製版"),
                  !compact.contains("製本"),
                  !compact.contains("キャラクターズ") else { return false }
            return compact.contains("出版社")
                || compact.contains("出版")
                || compact.contains("書房")
                || compact.contains("講談社")
                || compact.contains("KADOKAWA")
        }
    }

    private nonisolated static func normalizedJapaneseDate(in line: String) -> String? {
        let pattern = #"([12][0-9]{3})\h*年\h*([0-9]{1,2})\h*月\h*([0-9]{1,2})\h*日"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: line,
                range: NSRange(line.startIndex..<line.endIndex, in: line)
              ),
              let yearRange = Range(match.range(at: 1), in: line),
              let monthRange = Range(match.range(at: 2), in: line),
              let dayRange = Range(match.range(at: 3), in: line),
              let month = Int(line[monthRange]),
              let day = Int(line[dayRange]) else { return nil }
        return "\(line[yearRange])-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    private nonisolated static func inferredPageCount(in lines: [String]) -> Int {
        let pattern = #"(?i)(?<![0-9])([0-9]{1,5})\h*(?:p(?:ages?)?|頁)(?![A-Za-z])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return 0 }
        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = expression.firstMatch(in: line, range: range),
                  let valueRange = Range(match.range(at: 1), in: line),
                  let value = Int(line[valueRange]),
                  (1...10000).contains(value) else { continue }
            return value
        }
        return 0
    }

    private nonisolated static func isPlausibleBookTitle(_ line: String) -> Bool {
        let compact = compactOCRLabel(line)
        guard compact.count >= 2,
              compact.count <= 42,
              compact.range(of: #"[\p{Han}\p{Hiragana}\p{Katakana}A-Za-z]"#, options: .regularExpression) != nil,
              compact.range(of: #"(?:0\d{1,4}[-ー]\d{3,4}|〒\d{3}|https?://|www\.)"#, options: .regularExpression) == nil else {
            return false
        }
        let excluded = [
            "著者", "発行者", "発行所", "出版社", "印刷所", "製版所", "製本所",
            "株式会社", "有限会社", "電話", "編集", "販売", "業務", "定価",
            "ISBN", "Printed", "Copyright", "©", "お問い合わせ", "お願い",
            "無断", "本書のコピー", "フィクション", "価格は外貼り", "キャラクターズ"
        ]
        guard !excluded.contains(where: { compact.localizedCaseInsensitiveContains($0) }) else {
            return false
        }
        let phoneticOnly = compact.range(
            of: #"^[\p{Hiragana}\p{Katakana}ー・]+$"#,
            options: .regularExpression
        ) != nil
        return !phoneticOnly
    }

    private nonisolated static func inferredVolumeNumber(from title: String) -> String {
        let pattern = #"(?<![0-9０-９])([0-9０-９]{1,3})(?=[\h　]*(?:巻|特装版|限定版|通常版|$))"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: title,
                range: NSRange(title.startIndex..<title.endIndex, in: title)
              ),
              let range = Range(match.range(at: 1), in: title) else { return "" }
        return String(title[range]).applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? String(title[range])
    }

    private nonisolated static func inferredSeriesName(
        from title: String,
        volumeNumber: String
    ) -> String {
        guard !volumeNumber.isEmpty else { return "" }
        let escapedVolume = NSRegularExpression.escapedPattern(for: volumeNumber)
        return title
            .replacingOccurrences(
                of: #"[\h　]*\#(escapedVolume)[\h　]*(?:巻|特装版|限定版|通常版)?[\h　]*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func uniqueOCRValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let key = value.folding(
                options: [.caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            return seen.insert(key).inserted
        }
    }

    private nonisolated static func isValidISBN(_ value: String) -> Bool {
        if value.count == 13 {
            guard value.hasPrefix("978") || value.hasPrefix("979"),
                  value.allSatisfy(\.isNumber) else { return false }
            let digits = value.compactMap(\.wholeNumberValue)
            let sum = digits.prefix(12).enumerated().reduce(0) { result, element in
                result + element.element * (element.offset.isMultiple(of: 2) ? 1 : 3)
            }
            return (10 - (sum % 10)) % 10 == digits[12]
        }

        guard value.count == 10 else { return false }
        let characters = Array(value)
        guard characters.prefix(9).allSatisfy(\.isNumber),
              characters[9].isNumber || characters[9] == "X" else { return false }
        let sum = characters.enumerated().reduce(0) { result, element in
            let digit = element.offset == 9 && element.element == "X"
                ? 10
                : element.element.wholeNumberValue ?? -100
            return result + digit * (10 - element.offset)
        }
        return sum.isMultiple(of: 11)
    }

    private nonisolated static func isbn13(from isbn: String) -> String? {
        if isbn.count == 13 { return isbn }
        guard isbn.count == 10 else { return nil }
        let body = "978" + isbn.prefix(9)
        let digits = body.compactMap(\.wholeNumberValue)
        guard digits.count == 12 else { return nil }
        let sum = digits.enumerated().reduce(0) { result, element in
            result + element.element * (element.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return body + String((10 - (sum % 10)) % 10)
    }

    private nonisolated static func normalizedOpenBDDate(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count >= 4 else { return value }
        let year = digits.prefix(4)
        guard digits.count >= 6 else { return String(year) }
        let monthStart = digits.index(digits.startIndex, offsetBy: 4)
        let monthEnd = digits.index(monthStart, offsetBy: 2)
        let month = digits[monthStart..<monthEnd]
        guard digits.count >= 8 else { return "\(year)-\(month)" }
        let dayEnd = digits.index(monthEnd, offsetBy: 2)
        return "\(year)-\(month)-\(digits[monthEnd..<dayEnd])"
    }
}

private struct NDLBookCandidate: Sendable {
    var title = ""
    var author = ""
    var publisher = ""
    var date = ""
    var volume = ""
    var edition = ""
    var isbn = ""
}

private final class NDLSearchParserDelegate: NSObject, XMLParserDelegate {
    var candidates: [NDLBookCandidate] = []
    private var current: NDLBookCandidate?
    private var currentElement = ""
    private var currentText = ""
    private var readsISBN = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            current = NDLBookCandidate()
        }
        currentElement = qName ?? elementName
        currentText = ""
        if currentElement.hasSuffix("identifier") {
            let type = attributeDict["xsi:type"] ?? attributeDict["type"] ?? ""
            readsISBN = type.hasSuffix("ISBN")
        } else {
            readsISBN = false
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var value = current else { return }
        let name = qName ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "dc:title": value.title = text
        case "dc:creator": value.author = text
        case "dc:publisher": value.publisher = text
        case "dc:date", "dcterms:issued":
            if value.date.isEmpty { value.date = text }
        case "dcndl:volume": value.volume = text
        case "dcndl:edition": value.edition = text
        case "dc:identifier" where readsISBN: value.isbn = text
        case "item":
            if !value.title.isEmpty, !value.isbn.isEmpty {
                candidates.append(value)
            }
            current = nil
            return
        default: break
        }
        current = value
        currentText = ""
        readsISBN = false
    }
}

private struct OpenBDEntry: Decodable {
    let summary: OpenBDSummary?
    let onix: OpenBDOnix?
}

private struct OpenBDOnix: Decodable {
    let descriptiveDetail: OpenBDDescriptiveDetail?
    let productSupply: OpenBDProductSupply?

    private enum CodingKeys: String, CodingKey {
        case descriptiveDetail = "DescriptiveDetail"
        case productSupply = "ProductSupply"
    }
}

private struct OpenBDDescriptiveDetail: Decodable {
    let contributors: [OpenBDContributor]?
    let extents: [OpenBDExtent]?

    private enum CodingKeys: String, CodingKey {
        case contributors = "Contributor"
        case extents = "Extent"
    }
}

private struct OpenBDExtent: Decodable {
    let extentType: String?
    let extentValue: String?

    private enum CodingKeys: String, CodingKey {
        case extentType = "ExtentType"
        case extentValue = "ExtentValue"
    }
}

private struct OpenBDContributor: Decodable {
    let roles: [String]?
    let personName: String?

    private enum CodingKeys: String, CodingKey {
        case roles = "ContributorRole"
        case personName = "PersonName"
    }
}

private struct OpenBDProductSupply: Decodable {
    let supplyDetail: OpenBDSupplyDetail?

    private enum CodingKeys: String, CodingKey {
        case supplyDetail = "SupplyDetail"
    }
}

private struct OpenBDSupplyDetail: Decodable {
    let prices: [OpenBDPrice]?

    private enum CodingKeys: String, CodingKey {
        case prices = "Price"
    }
}

private struct OpenBDPrice: Decodable {
    let priceAmount: String?
    let currencyCode: String?

    private enum CodingKeys: String, CodingKey {
        case priceAmount = "PriceAmount"
        case currencyCode = "CurrencyCode"
    }
}

private struct OpenBDSummary: Decodable {
    let isbn: String
    let title: String
    let publisher: String
    let publicationDate: String
    let cover: String
    let author: String

    private enum CodingKeys: String, CodingKey {
        case isbn
        case title
        case publisher
        case publicationDate = "pubdate"
        case cover
        case author
    }
}

private struct GoogleBooksResponse: Decodable {
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Decodable {
    let volumeInfo: GoogleBooksVolumeInfo
    let saleInfo: GoogleBooksSaleInfo?
}

private struct GoogleBooksSaleInfo: Decodable {
    let listPrice: GoogleBooksPrice?
    let retailPrice: GoogleBooksPrice?
}

private struct GoogleBooksPrice: Decodable {
    let amount: Double
    let currencyCode: String?
}

private struct GoogleBooksVolumeInfo: Decodable {
    let title: String
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
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
    let pageCount: Int?

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case authors = "author_name"
        case publishers = "publisher"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case isbn
        case pageCount = "number_of_pages_median"
    }
}
