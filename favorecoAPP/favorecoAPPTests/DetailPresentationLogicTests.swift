import XCTest
@testable import favoreco

@MainActor
final class DetailPresentationLogicTests: XCTestCase {
    func testBackSwipeAcceptsDeliberateLeadingEdgeSwipe() {
        XCTAssertTrue(DetailBackSwipePolicy.shouldClose(
            startLocation: CGPoint(x: 20, y: 100),
            translation: CGSize(width: 90, height: 12),
            predictedEndTranslation: CGSize(width: 140, height: 14),
            exclusionFrames: []
        ))
    }

    func testBackSwipeRejectsStartOutsideLeadingEdge() {
        XCTAssertFalse(backSwipe(startX: 33))
    }

    func testBackSwipeRejectsExcludedControlFrame() {
        XCTAssertFalse(DetailBackSwipePolicy.shouldClose(
            startLocation: CGPoint(x: 20, y: 100),
            translation: CGSize(width: 100, height: 5),
            predictedEndTranslation: CGSize(width: 150, height: 5),
            exclusionFrames: [CGRect(x: 0, y: 80, width: 80, height: 80)]
        ))
    }

    func testBackSwipeRejectsShortTranslation() {
        XCTAssertFalse(backSwipe(translation: CGSize(width: 71, height: 0)))
    }

    func testBackSwipeRejectsMostlyVerticalTranslation() {
        XCTAssertFalse(backSwipe(translation: CGSize(width: 90, height: 80)))
    }

    func testBackSwipeRejectsWeakPredictedFinish() {
        XCTAssertFalse(backSwipe(predicted: CGSize(width: 109, height: 0)))
    }

    func testPerformanceTimeShowsOnlyStartWhenEndIsNotLater() {
        let start = Date(timeIntervalSince1970: 3_600)
        let visit = Visit(visitedAt: start, endedAt: start)

        XCTAssertEqual(
            ExperienceDetailPresentation.performanceTime(for: visit),
            FavorecoDateText.time(start)
        )
    }

    func testPerformanceTimeShowsRange() {
        let start = Date(timeIntervalSince1970: 3_600)
        let end = start.addingTimeInterval(7_200)
        let visit = Visit(visitedAt: start, endedAt: end)

        XCTAssertEqual(
            ExperienceDetailPresentation.performanceTime(for: visit),
            "\(FavorecoDateText.time(start))–\(FavorecoDateText.time(end))"
        )
    }

    func testWeatherTextRequiresBothTemperaturesAndRounds() {
        XCTAssertEqual(
            ExperienceDetailPresentation.compactWeatherText(
                fields: VisitUnitFields(weatherHighCelsius: 24.6, weatherLowCelsius: 12.4)
            ),
            "25°/12°"
        )
        XCTAssertEqual(
            ExperienceDetailPresentation.compactWeatherText(
                fields: VisitUnitFields(weatherHighCelsius: 24.6)
            ),
            ""
        )
    }

    func testRatingSymbolsHandleFullHalfAndEmptyStars() {
        XCTAssertEqual(ExperienceDetailPresentation.ratingSymbol(rating: 3.5, index: 3), "star.fill")
        XCTAssertEqual(ExperienceDetailPresentation.ratingSymbol(rating: 3.5, index: 4), "star.leadinghalf.filled")
        XCTAssertEqual(ExperienceDetailPresentation.ratingSymbol(rating: 3.5, index: 5), "star")
    }

    func testRoleNamesCoverKnownAndUnknownKeys() {
        XCTAssertEqual(ExperienceDetailPresentation.roleName(for: "stage_director"), "演出")
        XCTAssertEqual(ExperienceDetailPresentation.roleName(for: "unregistered"), "その他")
    }

    func testSecuredAttemptsExcludeArchivedAndUnsecuredStatuses() {
        let plan = Plan()
        let won = TicketAttempt(statusKey: "won", createdAt: Date(timeIntervalSince1970: 1))
        let interested = TicketAttempt(statusKey: "interested", createdAt: Date(timeIntervalSince1970: 2))
        let archived = TicketAttempt(statusKey: "issued", isArchived: true, createdAt: Date(timeIntervalSince1970: 3))
        plan.ticketAttempts = [interested, archived, won]

        XCTAssertEqual(ExperienceDetailPresentation.securedTicketAttempts(in: plan).map(\.id), [won.id])
    }

    func testTheaterPeriodUsesExplicitSingleDay() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let text = EventDetailPresentation.theaterPeriodText(
            event: ExperienceEvent(),
            fields: VisitUnitFields(eventPeriodStartsAt: date, eventPeriodEndsAt: date)
        )

        XCTAssertEqual(text, FavorecoDateText.compactDateWithHalfWidthWeekday(date))
    }

    func testTheaterVenuesPreferExplicitValuesAndDeduplicateNames() {
        let fields = VisitUnitFields(eventVenues: [
            EventVenueEntry(name: " 試験劇場 ", address: "東京都"),
            EventVenueEntry(name: "試験劇場", address: "別住所"),
            EventVenueEntry(name: "", address: "無効"),
        ])

        let venues = EventDetailPresentation.theaterVenues(event: ExperienceEvent(), fields: fields)

        XCTAssertEqual(venues.count, 1)
        XCTAssertEqual(venues.first?.name, "試験劇場")
        XCTAssertEqual(venues.first?.address, "東京都")
    }

    private func backSwipe(
        startX: CGFloat = 20,
        translation: CGSize = CGSize(width: 90, height: 0),
        predicted: CGSize = CGSize(width: 140, height: 0)
    ) -> Bool {
        DetailBackSwipePolicy.shouldClose(
            startLocation: CGPoint(x: startX, y: 100),
            translation: translation,
            predictedEndTranslation: predicted,
            exclusionFrames: []
        )
    }
}
