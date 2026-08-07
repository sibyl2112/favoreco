import XCTest
@testable import favoreco

final class BookMetadataTests: XCTestCase {
    func testStructuredBookMetadataRoundTrip() {
        let rawValue = VisitUnitFields(
            bookSeriesName: "灯台文庫",
            bookVolumeNumber: "2",
            bookAuthorName: "架空 著者",
            bookISBN: "9784101010014"
        ).encodedRawValue
        let restored = VisitUnitFields(rawValue: rawValue)

        XCTAssertEqual(restored.bookSeriesName, "灯台文庫")
        XCTAssertEqual(restored.bookVolumeNumber, "2")
        XCTAssertEqual(restored.bookAuthorName, "架空 著者")
        XCTAssertEqual(restored.bookISBN, "9784101010014")
    }

    @MainActor
    func testApplyingBookMetadataKeepsLegacySummaryForExistingViews() {
        let event = ExperienceEvent(title: "第2巻")

        event.applyBookMetadata(
            seriesName: "灯台文庫",
            volumeNumber: "2",
            authorName: "架空 著者",
            isbn: "9784101010014"
        )

        XCTAssertEqual(event.bookSeriesName, "灯台文庫")
        XCTAssertEqual(event.bookVolumeLabel, "第2巻")
        XCTAssertEqual(event.bookAuthorName, "架空 著者")
        XCTAssertEqual(event.bookISBN, "9784101010014")
        XCTAssertEqual(event.seriesName, "灯台文庫・第2巻・架空 著者")
    }

    func testLegacyPayloadWithoutBookMetadataRemainsReadable() {
        let restored = VisitUnitFields(rawValue: #"{"eventSubtitle":"旧データ"}"#)

        XCTAssertEqual(restored.eventSubtitle, "旧データ")
        XCTAssertTrue(restored.bookSeriesName.isEmpty)
        XCTAssertTrue(restored.bookVolumeNumber.isEmpty)
        XCTAssertTrue(restored.bookAuthorName.isEmpty)
        XCTAssertTrue(restored.bookISBN.isEmpty)
    }

    func testISBNNormalizationAcceptsHyphensAndSpaces() {
        XCTAssertEqual(
            BookMetadataLookupService.normalizedISBN("ISBN 978-4-10-101001-4"),
            "9784101010014"
        )
        XCTAssertEqual(
            BookMetadataLookupService.normalizedISBN("4-10-101001-X"),
            "410101001X"
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
}
