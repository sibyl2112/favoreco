import XCTest
@testable import favoreco

@MainActor
final class DetailPresentationLogicTests: XCTestCase {
    func testCalendarYearNeverUsesDigitGrouping() {
        XCTAssertEqual(FavorecoDateText.year(2026), "2026年")
        XCTAssertFalse(FavorecoDateText.year(2026).contains(","))
    }

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

    func testMuseumVisitOrdinalUsesDateOrderAndReordersAfterEditingDate() {
        let event = ExperienceEvent(title: "雲を測る")
        let first = Visit(
            visitedAt: Date(timeIntervalSince1970: 2_000),
            createdAt: Date(timeIntervalSince1970: 1),
            event: event
        )
        let second = Visit(
            visitedAt: Date(timeIntervalSince1970: 4_000),
            createdAt: Date(timeIntervalSince1970: 2),
            event: event
        )
        event.visits = [second, first]

        XCTAssertEqual(ExperienceDetailPresentation.museumVisitOrdinal(for: first), "鑑賞1回目")
        XCTAssertEqual(ExperienceDetailPresentation.museumVisitOrdinal(for: second), "鑑賞2回目")

        second.visitedAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(ExperienceDetailPresentation.museumVisitOrdinal(for: second), "鑑賞1回目")
        XCTAssertEqual(ExperienceDetailPresentation.museumVisitOrdinal(for: first), "鑑賞2回目")
    }

    func testRepeatVisitDraftCopiesPlaceAndDisplaySettingsButClearsPersonalRecord() {
        let place = PlaceMaster(
            name: "国立西洋美術館",
            address: "東京都台東区上野公園7-7",
            latitude: 35.7154,
            longitude: 139.7758
        )
        let fields = VisitUnitFields(
            ocrText: "前回OCR",
            styleNames: ["企画展"],
            eyecatchAspectRatioKey: EyecatchAspectRatio.cinemaPoster.key,
            advancedEntries: [AdvancedFieldEntry(label: "補足", value: "前回詳細")]
        )
        let previous = Visit(
            venueNameSnapshot: "国立西洋美術館",
            overallRating: 5,
            outcomeKey: "attended",
            seatText: "前回の座席",
            note: "前回の感想",
            tagNamesRaw: "静か",
            amount: 2_000,
            unitFieldsRaw: fields.encodedRawValue,
            placeMaster: place
        )

        let draft = VisitDraft(repeating: previous)

        XCTAssertEqual(draft.venueName, "国立西洋美術館")
        XCTAssertEqual(draft.venueAddress, "東京都台東区上野公園7-7")
        XCTAssertEqual(draft.latitude, 35.7154)
        XCTAssertEqual(draft.longitude, 139.7758)
        XCTAssertEqual(draft.styleNamesText, "企画展")
        XCTAssertEqual(draft.eyecatchAspectRatioKey, EyecatchAspectRatio.cinemaPoster.key)
        XCTAssertEqual(draft.overallRating, 0)
        XCTAssertTrue(draft.note.isEmpty)
        XCTAssertTrue(draft.amountText.isEmpty)
        XCTAssertTrue(draft.ocrText.isEmpty)
        XCTAssertTrue(draft.advancedEntries.isEmpty)
        XCTAssertTrue(draft.tagNamesText.isEmpty)
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

    func testDetailVenueAddressSkipsBlankMasterAndUsesVisitSnapshot() {
        let address = ExperienceDetailSnapshot.resolvedVenueAddress(
            venueName: "有明四季劇場",
            masterAddress: "  ",
            visitAddress: "東京都江東区有明2-1-29",
            planAddresses: [],
            eventVenues: []
        )

        XCTAssertEqual(address, "東京都江東区有明2-1-29")
    }

    func testDetailVenueAddressUsesMatchingEventVenueWithoutMixingVenues() {
        let address = ExperienceDetailSnapshot.resolvedVenueAddress(
            venueName: " 有明四季劇場 ",
            masterAddress: nil,
            visitAddress: "",
            planAddresses: [],
            eventVenues: [
                EventVenueEntry(name: "別会場", address: "別住所"),
                EventVenueEntry(name: "有明四季劇場", address: "東京都江東区有明2-1-29"),
            ]
        )

        XCTAssertEqual(address, "東京都江東区有明2-1-29")
    }

    func testMapAddressResolutionPrefersCandidateNearestStoredCoordinate() {
        let candidates = [
            PlaceSearchCandidate(
                id: "far",
                name: "同名会場",
                address: "遠い住所",
                latitude: 34.0,
                longitude: 135.0
            ),
            PlaceSearchCandidate(
                id: "near",
                name: "同名会場",
                address: "近い住所",
                latitude: 35.634,
                longitude: 139.792
            ),
        ]

        XCTAssertEqual(
            PlaceSearchService.preferredAddressCandidate(
                candidates,
                nearLatitude: 35.6339,
                longitude: 139.7917
            )?.id,
            "near"
        )
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
