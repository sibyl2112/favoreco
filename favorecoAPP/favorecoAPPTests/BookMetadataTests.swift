import XCTest
@testable import favoreco

final class BookMetadataTests: XCTestCase {
    func testStructuredBookMetadataRoundTrip() {
        let rawValue = VisitUnitFields(
            bookSeriesName: "灯台文庫",
            bookVolumeNumber: "2",
            bookAuthorName: "架空 著者",
            bookTranslatorName: "架空 訳者",
            bookISBN: "9784101010014",
            bookPublisherName: "灯台出版",
            bookPublishedDate: "2026-08-13",
            bookPriceText: "1980",
            bookPageCount: 320,
            bookInformationSourceName: "openBD",
            bookInformationSourceURL: "https://www.books.or.jp/book-details/9784101010014"
        ).encodedRawValue
        let restored = VisitUnitFields(rawValue: rawValue)

        XCTAssertEqual(restored.bookSeriesName, "灯台文庫")
        XCTAssertEqual(restored.bookVolumeNumber, "2")
        XCTAssertEqual(restored.bookAuthorName, "架空 著者")
        XCTAssertEqual(restored.bookTranslatorName, "架空 訳者")
        XCTAssertEqual(restored.bookISBN, "9784101010014")
        XCTAssertEqual(restored.bookPublisherName, "灯台出版")
        XCTAssertEqual(restored.bookPublishedDate, "2026-08-13")
        XCTAssertEqual(restored.bookPriceText, "1980")
        XCTAssertEqual(restored.bookPageCount, 320)
        XCTAssertEqual(restored.bookInformationSourceName, "openBD")
        XCTAssertEqual(
            restored.bookInformationSourceURL,
            "https://www.books.or.jp/book-details/9784101010014"
        )
    }

    @MainActor
    func testApplyingBookMetadataDoesNotGenerateGenericSeriesSummary() {
        let event = ExperienceEvent(title: "第2巻", seriesName: "既存の汎用シリーズ")

        event.applyBookMetadata(
            seriesName: "灯台文庫",
            volumeNumber: "2",
            authorName: "架空 著者",
            translatorName: "架空 訳者",
            isbn: "9784101010014",
            publisherName: "灯台出版",
            publishedDate: "2026-08-13",
            priceText: "1980",
            pageCount: 320,
            informationSourceName: "openBD",
            informationSourceURL: "https://www.books.or.jp/book-details/9784101010014"
        )

        XCTAssertEqual(event.bookSeriesName, "灯台文庫")
        XCTAssertEqual(event.bookVolumeLabel, "第2巻")
        XCTAssertEqual(event.bookAuthorName, "架空 著者")
        XCTAssertEqual(event.bookTranslatorName, "架空 訳者")
        XCTAssertEqual(event.bookISBN, "9784101010014")
        XCTAssertEqual(event.bookPublisherName, "灯台出版")
        XCTAssertEqual(event.bookPublishedDate, "2026-08-13")
        XCTAssertEqual(event.bookPriceText, "1980")
        XCTAssertEqual(event.bookPageCount, 320)
        XCTAssertEqual(event.bookInformationSourceName, "openBD")
        XCTAssertEqual(
            event.bookInformationSourceURL,
            "https://www.books.or.jp/book-details/9784101010014"
        )
        XCTAssertEqual(event.seriesName, "既存の汎用シリーズ")
    }

    func testLegacyPayloadWithoutBookMetadataRemainsReadable() {
        let restored = VisitUnitFields(rawValue: #"{"eventSubtitle":"旧データ"}"#)

        XCTAssertEqual(restored.eventSubtitle, "旧データ")
        XCTAssertTrue(restored.bookSeriesName.isEmpty)
        XCTAssertTrue(restored.bookVolumeNumber.isEmpty)
        XCTAssertTrue(restored.bookAuthorName.isEmpty)
        XCTAssertTrue(restored.bookTranslatorName.isEmpty)
        XCTAssertTrue(restored.bookISBN.isEmpty)
        XCTAssertTrue(restored.bookPublisherName.isEmpty)
        XCTAssertTrue(restored.bookPublishedDate.isEmpty)
        XCTAssertTrue(restored.bookPriceText.isEmpty)
        XCTAssertEqual(restored.bookPageCount, 0)
        XCTAssertTrue(restored.bookInformationSourceName.isEmpty)
        XCTAssertTrue(restored.bookInformationSourceURL.isEmpty)
    }

    func testISBNNormalizationAcceptsHyphensAndSpaces() {
        XCTAssertEqual(
            BookMetadataLookupService.normalizedISBN("ISBN 978-4-10-101001-4"),
            "9784101010014"
        )
        XCTAssertEqual(
            BookMetadataLookupService.normalizedISBN("4-10-101001-3"),
            "4101010013"
        )
    }

    func testISBNNormalizationRejectsPriceCodeAndInvalidChecksum() {
        XCTAssertNil(BookMetadataLookupService.normalizedISBN("1929979008505"))
        XCTAssertNil(BookMetadataLookupService.normalizedISBN("9784065409687"))
    }

    func testOpenBDCandidateDecoding() throws {
        let data = Data(#"[{"summary":{"isbn":"9784065409688","title":"もやしもん+. 1","publisher":"講談社","pubdate":"202510","cover":"","author":"石川,雅之"}}]"#.utf8)
        let candidate = try BookMetadataLookupService.openBDCandidate(
            from: data,
            requestedISBN: "9784065409688"
        )

        XCTAssertEqual(candidate.isbn, "9784065409688")
        XCTAssertEqual(candidate.title, "もやしもん+. 1")
        XCTAssertEqual(candidate.authorText, "石川雅之")
        XCTAssertEqual(candidate.publisher, "講談社")
        XCTAssertEqual(candidate.publishedDate, "2025-10")
        XCTAssertEqual(
            candidate.coverURL?.absoluteString,
            "https://thumbnail-s.images.books.or.jp/9784065409688.jpg"
        )
        XCTAssertEqual(candidate.sourceName, "openBD")
    }

    func testOpenBDCandidateDecodesTranslatorAndPriceWhenAvailable() throws {
        let data = Data(
            #"[{"onix":{"DescriptiveDetail":{"Contributor":[{"ContributorRole":["A01"],"PersonName":"架空 著者"},{"ContributorRole":["B06"],"PersonName":"訳者A"},{"ContributorRole":["B08"],"PersonName":"訳者B"}],"Extent":[{"ExtentType":"00","ExtentValue":"320"}]},"ProductSupply":{"SupplyDetail":{"Price":[{"PriceAmount":"1980","CurrencyCode":"JPY"}]}}},"summary":{"isbn":"9784065409688","title":"翻訳書","publisher":"灯台出版","pubdate":"202510","cover":"","author":"架空 著者"}}]"#.utf8
        )
        let candidate = try BookMetadataLookupService.openBDCandidate(
            from: data,
            requestedISBN: "9784065409688"
        )

        XCTAssertEqual(candidate.translatorText, "訳者A、訳者B")
        XCTAssertEqual(candidate.priceText, "1980")
        XCTAssertEqual(candidate.pageCount, 320)
    }

    func testColophonOCRExtractsStructuredBookMetadata() {
        let metadata = BookMetadataLookupService.ocrMetadata(
            from: """
            講談社キャラクターズA
            ガンム かせい せんき とくそうばん
            銃夢火星戦記 9 特装版
            2022年11月18日 第1刷発行
            著者
            発行者
            発行所
            きしろ
            木城ゆきと
            ©Yukito Kishiro 2022
            森田浩章
            株式会社 講談社
            〒112-8001 東京都文京区音羽2-12-21
            電話 編集（03）5395-3803
            N.D.C.726 162p 19cm Printed in Japan
            """
        )

        XCTAssertEqual(metadata.title, "銃夢火星戦記 9 特装版")
        XCTAssertTrue(metadata.seriesName.isEmpty)
        XCTAssertTrue(metadata.volumeNumber.isEmpty)
        XCTAssertEqual(metadata.author, "木城ゆきと")
        XCTAssertEqual(metadata.publisher, "講談社")
        XCTAssertEqual(metadata.publishedDate, "2022-11-18")
        XCTAssertEqual(metadata.pageCount, 162)
        XCTAssertEqual(metadata.alternateTitles.count, 0)
    }

    func testColophonOCRRejectsContactAndNoticeTextAsTitle() {
        let metadata = BookMetadataLookupService.ocrMetadata(
            from: """
            なお、この本についてのお問い合わせはイブニング編集部にお願いいたします。
            販売（03）5395-3608 業務（03）5395-3603
            著者
            木城ゆきと
            発行所 株式会社 講談社
            """
        )

        XCTAssertTrue(metadata.title.isEmpty)
        XCTAssertTrue(metadata.alternateTitles.isEmpty)
        XCTAssertEqual(metadata.author, "木城ゆきと")
        XCTAssertEqual(metadata.publisher, "講談社")
    }

    func testNDLReverseLookupSelectsMatchingVolumeAndEdition() {
        let xml = Data(
            """
            <rss xmlns:dc="http://purl.org/dc/elements/1.1/"
                 xmlns:dcndl="http://ndl.go.jp/dcndl/terms/"
                 xmlns:dcterms="http://purl.org/dc/terms/"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <channel>
                <item>
                  <dc:title>銃夢火星戦記</dc:title>
                  <dc:creator>木城, ゆきと, 1967-</dc:creator>
                  <dc:publisher>講談社</dc:publisher>
                  <dc:date>2022</dc:date>
                  <dcndl:volume>9</dcndl:volume>
                  <dcndl:edition>特装版</dcndl:edition>
                  <dc:identifier xsi:type="dcndl:ISBN">978-4-06-530219-4</dc:identifier>
                </item>
                <item>
                  <dc:title>銃夢火星戦記</dc:title>
                  <dc:creator>木城, ゆきと, 1967-</dc:creator>
                  <dc:publisher>講談社</dc:publisher>
                  <dc:date>2024</dc:date>
                  <dcndl:volume>10</dcndl:volume>
                  <dc:identifier xsi:type="dcndl:ISBN">978-4-06-535282-3</dc:identifier>
                </item>
              </channel>
            </rss>
            """.utf8
        )
        let metadata = BookOCRMetadataCandidate(
            title: "銃夢火星戦記 9 特装版",
            alternateTitles: [],
            seriesName: "銃夢火星戦記",
            volumeNumber: "9",
            author: "木城ゆきと",
            publisher: "講談社",
            publishedDate: "2022-11-18",
            pageCount: 0
        )

        XCTAssertEqual(
            BookMetadataLookupService.ndlReverseLookupISBN(
                from: xml,
                matching: metadata
            ),
            "9784065302194"
        )
    }

    func testNDLReverseLookupRejectsAmbiguousSameTitle() {
        let xml = Data(
            """
            <rss xmlns:dc="http://purl.org/dc/elements/1.1/"
                 xmlns:dcndl="http://ndl.go.jp/dcndl/terms/"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <channel>
                <item>
                  <dc:title>同じ本</dc:title>
                  <dc:identifier xsi:type="dcndl:ISBN">978-4-10-101001-4</dc:identifier>
                </item>
                <item>
                  <dc:title>同じ本</dc:title>
                  <dc:identifier xsi:type="dcndl:ISBN">978-4-10-101002-1</dc:identifier>
                </item>
              </channel>
            </rss>
            """.utf8
        )
        let metadata = BookOCRMetadataCandidate(
            title: "同じ本",
            alternateTitles: [],
            seriesName: "",
            volumeNumber: "",
            author: "",
            publisher: "",
            publishedDate: "",
            pageCount: 0
        )

        XCTAssertNil(
            BookMetadataLookupService.ndlReverseLookupISBN(
                from: xml,
                matching: metadata
            )
        )
    }

    func testISBNExtractionFromOCRText() {
        XCTAssertEqual(
            BookMetadataLookupService.isbnCandidates(
                from: "定価 700円\nISBN 978-4-10-101001-4\n新潮文庫"
            ),
            ["9784101010014"]
        )
    }

    func testISBNExtractionKeepsISBNSeparateFromPriceCodeOnBookBackCover() {
        XCTAssertEqual(
            BookMetadataLookupService.isbnCandidates(
                from: "9784798182681\n1923055025004"
            ),
            ["9784798182681"]
        )
    }

    func testNextVolumeNumberUsesLargestStructuredVolume() {
        XCTAssertEqual(
            BookSeriesRegistrationDefaults.nextVolumeNumber(from: ["1", "第2巻 2026年版", "３"]),
            "4"
        )
    }

    func testNextVolumeNumberIsEmptyWithoutNumericVolume() {
        XCTAssertEqual(
            BookSeriesRegistrationDefaults.nextVolumeNumber(from: ["上", "下", ""]),
            ""
        )
    }

    func testYearlyReadingAnalyticsCountsBooksAndKnownPagesByCompletionMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        }

        let summary = BookReadingAnalytics.yearly(
            entries: [
                BookReadingEntry(completedAt: try date(2026, 1, 10), pageCount: 320),
                BookReadingEntry(completedAt: try date(2026, 1, 20), pageCount: 0),
                BookReadingEntry(completedAt: try date(2026, 2, 2), pageCount: 320),
                BookReadingEntry(completedAt: try date(2025, 12, 31), pageCount: 999)
            ],
            yearContaining: try date(2026, 8, 14),
            calendar: calendar
        )

        XCTAssertEqual(summary.year, 2026)
        XCTAssertEqual(summary.bookCount, 3)
        XCTAssertEqual(summary.pageCount, 640)
        XCTAssertEqual(summary.months[0], BookReadingMonthStat(month: 1, bookCount: 2, pageCount: 320))
        XCTAssertEqual(summary.months[1], BookReadingMonthStat(month: 2, bookCount: 1, pageCount: 320))
        XCTAssertEqual(summary.months[2], BookReadingMonthStat(month: 3, bookCount: 0, pageCount: 0))
    }
}
