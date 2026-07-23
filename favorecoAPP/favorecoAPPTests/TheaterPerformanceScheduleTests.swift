import XCTest
@testable import favoreco

@MainActor
final class TheaterPerformanceScheduleTests: XCTestCase {
    func testLegacyVenueJSONDecodesWithoutPerVenuePeriod() throws {
        let id = UUID()
        let data = Data("""
        {"id":"\(id.uuidString)","name":"旧劇場","address":"東京都"}
        """.utf8)

        let entry = try JSONDecoder().decode(EventVenueEntry.self, from: data)

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.name, "旧劇場")
        XCTAssertNil(entry.performanceLabel)
        XCTAssertNil(entry.startsAt)
        XCTAssertNil(entry.endsAt)
    }

    func testScheduleBuildsHeroSummaryAndOverallPeriodFromPerformancePlaces() {
        let tokyoStart = date(2026, 7, 4)
        let tokyoEnd = date(2026, 7, 31)
        let osakaStart = date(2026, 8, 10)
        let osakaEnd = date(2026, 8, 18)
        let fields = VisitUnitFields(eventVenues: [
            EventVenueEntry(
                name: "東京芸術劇場",
                address: "東京都",
                performanceLabel: "東京公演",
                startsAt: tokyoStart,
                endsAt: tokyoEnd
            ),
            EventVenueEntry(
                name: "梅田芸術劇場",
                address: "大阪府",
                performanceLabel: "大阪公演",
                startsAt: osakaStart,
                endsAt: osakaEnd
            ),
        ])
        let event = ExperienceEvent()

        let schedules = EventDetailPresentation.theaterSchedules(event: event, fields: fields)

        XCTAssertEqual(schedules.map(\.performanceLabel), ["東京公演", "大阪公演"])
        XCTAssertEqual(
            EventDetailPresentation.theaterHeroVenueSummary(schedules: schedules),
            "東京・大阪｜2都市・2会場"
        )
        XCTAssertEqual(
            EventDetailPresentation.theaterPeriodText(event: event, fields: fields),
            "\(FavorecoDateText.compactDate(tokyoStart))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(osakaEnd))"
        )
    }

    func testCompactSchedulePrioritizesActiveAndNextPerformancePlace() {
        let now = date(2026, 7, 15)
        let schedules = [
            schedule(id: "past", start: date(2026, 6, 1), end: date(2026, 6, 5)),
            schedule(id: "active", start: date(2026, 7, 1), end: date(2026, 7, 31)),
            schedule(id: "next", start: date(2026, 8, 10), end: date(2026, 8, 18)),
            schedule(id: "later", start: date(2026, 9, 1), end: date(2026, 9, 3)),
        ]

        let visible = EventDetailPresentation.prioritizedTheaterSchedules(schedules, now: now)

        XCTAssertEqual(visible.map(\.id), ["active", "next"])
    }

    func testLegacyOfficialPeriodRemainsPreferredWithoutStructuredScheduleDates() {
        let officialStart = date(2026, 7, 1)
        let officialEnd = date(2026, 8, 31)
        let event = ExperienceEvent()
        event.plans = [
            Plan(
                title: "東京公演",
                startsAt: date(2026, 7, 10),
                endsAt: date(2026, 7, 10),
                venueNameSnapshot: "東京劇場"
            )
        ]
        let fields = VisitUnitFields(
            eventPeriodStartsAt: officialStart,
            eventPeriodEndsAt: officialEnd
        )

        XCTAssertEqual(
            EventDetailPresentation.theaterPeriodText(event: event, fields: fields),
            "\(FavorecoDateText.compactDate(officialStart))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(officialEnd))"
        )
    }

    func testCompactScheduleNeverExceedsTwoItemsWhenMultiplePlacesAreActive() {
        let now = date(2026, 7, 15)
        let schedules = [
            schedule(id: "active1", start: date(2026, 7, 1), end: date(2026, 7, 31)),
            schedule(id: "active2", start: date(2026, 7, 2), end: date(2026, 7, 31)),
            schedule(id: "active3", start: date(2026, 7, 3), end: date(2026, 7, 31)),
        ]

        XCTAssertEqual(
            EventDetailPresentation.prioritizedTheaterSchedules(schedules, now: now).map(\.id),
            ["active1", "active2"]
        )
    }

    private func schedule(id: String, start: Date, end: Date) -> TheaterPerformanceScheduleItem {
        TheaterPerformanceScheduleItem(
            id: id,
            performanceLabel: "\(id)公演",
            startsAt: start,
            endsAt: end,
            venueName: "\(id)劇場",
            address: ""
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day)
        )!
    }
}
