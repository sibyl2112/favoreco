import XCTest
@testable import favoreco

@MainActor
final class MovieBestPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testPeriodLimitsAndDateScope() throws {
        let annual = MovieBestPeriod(kind: .yearly, year: 2026)
        let monthly = MovieBestPeriod(kind: .monthly, year: 2026, month: 6)
        let june = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let july = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))

        XCTAssertEqual(annual.maximumCount, 10)
        XCTAssertEqual(monthly.maximumCount, 3)
        XCTAssertTrue(annual.contains(july, calendar: calendar))
        XCTAssertTrue(monthly.contains(june, calendar: calendar))
        XCTAssertFalse(monthly.contains(july, calendar: calendar))
    }

    func testCandidatesAreOnlyMovieVisitsInThePeriod() throws {
        let period = MovieBestPeriod(kind: .yearly, year: 2026)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let movie = makeVisit(type: .movie, date: date)
        let drama = makeVisit(type: .drama, date: date)
        let outside = makeVisit(
            type: .movie,
            date: try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 15)))
        )

        XCTAssertTrue(MovieBestPolicy.isMovieCandidate(movie, period: period))
        XCTAssertFalse(MovieBestPolicy.isMovieCandidate(drama, period: period))
        XCTAssertFalse(MovieBestPolicy.isMovieCandidate(outside, period: period))
    }

    func testStoredRankControlsOrderAndIgnoresOrphans() throws {
        let period = MovieBestPeriod(kind: .monthly, year: 2026, month: 6)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let first = makeVisit(type: .movie, date: date)
        let second = makeVisit(type: .movie, date: date)
        let entries = [
            MovieBestEntry(period: period, rank: 1, visitID: first.id),
            MovieBestEntry(period: period, rank: 0, visitID: second.id),
            MovieBestEntry(period: period, rank: 2, visitID: UUID()),
        ]

        XCTAssertEqual(
            MovieBestPolicy.orderedVisits(entries: entries, visits: [first, second], period: period).map(\.id),
            [second.id, first.id]
        )
    }

    private func makeVisit(type: ScreenWorkType, date: Date) -> Visit {
        let category = RecordCategory(name: "映像作品", templateKey: "movie")
        let event = ExperienceEvent(title: type.displayName, subTypeKey: type.rawValue, category: category)
        return Visit(visitedAt: date, event: event)
    }
}
