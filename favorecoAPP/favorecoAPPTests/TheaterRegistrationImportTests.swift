import XCTest
@testable import favoreco

final class TheaterRegistrationImportTests: XCTestCase {
    func testPosterOCRCombinesProminentTitleAndFindsVenueAndPeriod() {
        let referenceDate = date(2026, 7, 28)
        let result = QuickCaptureImageService.inferredFieldsForTesting(
            lines: [
                ("HORIPRO", 0.12, 0.025),
                ("どこか", 0.18, 0.11),
                ("奇妙な", 0.19, 0.11),
                ("職業体験", 0.28, 0.14),
                ("夜の学校調査員", 0.46, 0.09),
                ("会場 千代田中学校・高等学校", 0.44, 0.035),
                ("開催日時 8月21日・23日・28日・30日", 0.52, 0.034),
            ],
            referenceDate: referenceDate
        )

        XCTAssertEqual(
            result.titleCandidates.first,
            "どこか奇妙な職業体験　夜の学校調査員"
        )
        XCTAssertEqual(result.venueCandidates.first, "千代田中学校・高等学校")
        XCTAssertEqual(result.eventDateRange?.startsAt, date(2026, 8, 21))
        XCTAssertEqual(result.eventDateRange?.endsAt, date(2026, 8, 30))
    }

    func testOGPMetadataReadsTitleAndImageRegardlessOfAttributeOrder() {
        let html = """
        <html><head>
        <meta content="https://example.com/poster.jpg" property="og:image">
        <meta property="og:title" content="どこか奇妙な職業体験 &amp; 夜の学校調査員">
        </head></html>
        """

        let metadata = URLMetadataService.htmlMetadataForTesting(in: html)

        XCTAssertEqual(metadata.title, "どこか奇妙な職業体験 & 夜の学校調査員")
        XCTAssertEqual(metadata.imageURLString, "https://example.com/poster.jpg")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day
            )
        )!
    }
}
