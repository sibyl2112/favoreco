import XCTest
@testable import favoreco

@MainActor
final class PlaceFacilityCardMetricsTests: XCTestCase {
    func testUniqueVisitDayCountCollapsesMultipleRecordsOnSameDay() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = Visit(visitedAt: date(2026, 8, 10, 9, calendar: calendar))
        let sameDay = Visit(visitedAt: date(2026, 8, 10, 18, calendar: calendar))
        let nextDay = Visit(visitedAt: date(2026, 8, 11, 9, calendar: calendar))

        XCTAssertEqual(
            PlaceFacilityCardMetrics.uniqueVisitDayCount(
                in: [first, sameDay, nextDay],
                calendar: calendar
            ),
            2
        )
    }

    func testRecentPhotosUsesNewestVisitFirstAndFiltersNonPhotos() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let olderVisit = Visit(visitedAt: date(2026, 8, 10, 9, calendar: calendar))
        let newerVisit = Visit(visitedAt: date(2026, 8, 12, 9, calendar: calendar))
        let olderPhoto = storedPhoto(createdAt: date(2026, 8, 10, 10, calendar: calendar))
        let newerPhoto = storedPhoto(createdAt: date(2026, 8, 12, 11, calendar: calendar))
        let newestPhoto = storedPhoto(createdAt: date(2026, 8, 12, 12, calendar: calendar))
        let video = PhotoBlob(mediaKind: "video", byteCount: 1, createdAt: date(2026, 8, 12, 13, calendar: calendar))
        let emptyPhoto = PhotoBlob(mediaKind: "photo", byteCount: 0, createdAt: date(2026, 8, 12, 14, calendar: calendar))
        olderVisit.photos = [olderPhoto]
        newerVisit.photos = [newerPhoto, video, newestPhoto, emptyPhoto]

        let result = PlaceFacilityCardMetrics.recentPhotos(
            in: [olderVisit, newerVisit],
            limit: 2
        )

        XCTAssertEqual(result.map(\.id), [newestPhoto.id, newerPhoto.id])
    }

    private func storedPhoto(createdAt: Date) -> PhotoBlob {
        PhotoBlob(mediaKind: "photo", byteCount: 1, createdAt: createdAt)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}
