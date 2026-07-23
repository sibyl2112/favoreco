import XCTest
@testable import favoreco

@MainActor
final class TheaterPeopleSimplicityTests: XCTestCase {
    func testCreditsTextRoundTripsAndLegacyDataDefaultsToEmpty() {
        let credits = "出演\n山田 花子\n\n演出\n佐藤 太郎"
        let stored = VisitUnitFields(eventCreditsText: credits)

        XCTAssertEqual(
            VisitUnitFields(rawValue: stored.encodedRawValue).eventCreditsText,
            credits
        )
        XCTAssertEqual(
            VisitUnitFields(rawValue: #"{"eventSubtitle":"初演"}"#).eventCreditsText,
            ""
        )
    }

    func testCombinedDraftStoresTrimmedCreditsOnEventSide() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        var draft = AddExperienceDraft()
        draft.theaterCreditsText = "  出演：山田 花子\n演出：佐藤 太郎  \n"

        let restored = VisitUnitFields(rawValue: draft.eventUnitFieldsRaw(for: category))

        XCTAssertEqual(restored.eventCreditsText, "出演：山田 花子\n演出：佐藤 太郎")
        XCTAssertEqual(draft.makeUnitFields(for: category).eventCreditsText, "")
    }

    func testFocusPersonIsNotClassifiedAsLegacyCast() {
        let person = PersonMaster(displayName: "注目した人")
        let focus = EventPersonLink(
            roleKey: PersonRoleOption.theaterFocus.key,
            displayRole: PersonRoleOption.theaterFocus.name,
            person: person
        )

        XCTAssertFalse(TheaterVisitCastResolver.isCastLink(focus))
    }

    func testFocusReactionMetadataRoundTripsWithoutTouchingPersonMaster() {
        let metadata = TheaterFocusLinkMetadata(
            reactionKeys: ["precious", "target", "custom", "target", " "]
        )

        let restored = TheaterFocusLinkMetadata(memo: metadata.encodedMemo)

        XCTAssertEqual(restored.reactionKeys, ["precious", "target", "custom"])
        XCTAssertEqual(TheaterFocusReaction.orderedKeys(restored.reactionKeys), ["target", "precious", "custom"])
        XCTAssertEqual(TheaterFocusLinkMetadata(memo: "以前の自由メモ").reactionKeys, [])
        XCTAssertEqual(TheaterFocusLinkMetadata().encodedMemo, "")
    }

    func testPendingFocusPersonStoresReactionTagsOnVisitPersonLink() {
        let person = PersonMaster(displayName: "山田 花子")
        let visit = Visit()
        let pending = PendingPersonLink(
            name: person.displayName,
            role: .theaterFocus,
            relationshipTagKeys: ["target", "resonated"]
        )

        let link = pending.makeEventPersonLink(
            person: person,
            event: nil,
            visit: visit,
            sortOrder: 0
        )

        XCTAssertEqual(
            TheaterFocusLinkMetadata(memo: link.memo).reactionKeys,
            ["target", "resonated"]
        )
        XCTAssertEqual(link.person?.id, person.id)
        XCTAssertEqual(link.visit?.id, visit.id)
    }

    func testEditingPersonMasterKeepsVisitRelationshipAndReactionTags() {
        let person = PersonMaster(displayName: "登録時の名前", reading: "とうろくじ")
        let visit = Visit()
        let link = EventPersonLink(
            roleKey: PersonRoleOption.theaterFocus.key,
            displayRole: PersonRoleOption.theaterFocus.name,
            person: person,
            visit: visit
        )
        link.memo = TheaterFocusLinkMetadata(
            reactionKeys: ["target", "precious"]
        ).encodedMemo

        let originalPersonID = person.id
        person.displayName = "編集後の名前"
        person.reading = "へんしゅうご"
        person.imageData = Data([0x01, 0x02])

        XCTAssertEqual(link.person?.id, originalPersonID)
        XCTAssertEqual(link.person?.displayName, "編集後の名前")
        XCTAssertEqual(link.person?.reading, "へんしゅうご")
        XCTAssertEqual(link.person?.imageData, Data([0x01, 0x02]))
        XCTAssertEqual(
            TheaterFocusLinkMetadata(memo: link.memo).reactionKeys,
            ["target", "precious"]
        )
    }

    func testExperienceSnapshotIncludesEventCreditsAndVisitFocus() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(
            title: "公演",
            unitFieldsRaw: VisitUnitFields(eventCreditsText: "出演：山田 花子").encodedRawValue,
            category: category
        )
        let visit = Visit(event: event)
        let person = PersonMaster(displayName: "山田 花子")
        let focus = EventPersonLink(
            roleKey: PersonRoleOption.theaterFocus.key,
            displayRole: PersonRoleOption.theaterFocus.name,
            person: person,
            visit: visit
        )
        focus.memo = TheaterFocusLinkMetadata(
            reactionKeys: ["target", "precious"]
        ).encodedMemo

        let snapshot = ExperienceDetailSnapshot.make(visit: visit, personLinks: [focus])

        XCTAssertEqual(snapshot.eventCreditsText, "出演：山田 花子")
        XCTAssertEqual(snapshot.linkedPeople.map(\.id), [focus.id])
    }

    func testEventSnapshotKeepsCreditsAndLegacyStructuredCast() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(
            title: "公演",
            unitFieldsRaw: VisitUnitFields(eventCreditsText: "出演：新形式").encodedRawValue,
            category: category
        )
        let legacyPerson = PersonMaster(displayName: "旧形式の出演者")
        let legacyLink = EventPersonLink(roleKey: "cast", person: legacyPerson, event: event)
        event.personLinks = [legacyLink]

        let snapshot = EventDetailSnapshot.make(event: event)

        XCTAssertEqual(snapshot.creditsText, "出演：新形式")
        XCTAssertEqual(snapshot.castLinks.map(\.id), [legacyLink.id])
    }

    func testFocusAnalyticsDeduplicatesSameVisitAndCountsDistinctEvents() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let firstEvent = ExperienceEvent(title: "公演A", category: category)
        let secondEvent = ExperienceEvent(title: "公演B", category: category)
        let firstVisit = Visit(visitedAt: Date(timeIntervalSince1970: 1_000), event: firstEvent)
        let secondVisit = Visit(visitedAt: Date(timeIntervalSince1970: 2_000), event: secondEvent)
        let person = PersonMaster(displayName: "注目した人")
        let duplicateFirst = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            person: person,
            visit: firstVisit
        )
        let duplicateSecond = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            person: person,
            visit: firstVisit
        )
        let secondEventLink = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            person: person,
            visit: secondVisit
        )

        let stats = TheaterFocusPersonAnalytics.make(
            people: [person],
            links: [duplicateFirst, duplicateSecond, secondEventLink],
            visits: [firstVisit, secondVisit]
        )

        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.first?.eventCount, 2)
        XCTAssertEqual(stats.first?.visitCount, 2)
        XCTAssertEqual(stats.first?.latestVisitedAt, secondVisit.visitedAt)
    }

    func testFocusAnalyticsExcludesLegacyCastAndNonTheaterVisits() {
        let theater = RecordCategory(name: "観劇", templateKey: "theater")
        let movie = RecordCategory(name: "映画", templateKey: "movie")
        let theaterVisit = Visit(event: ExperienceEvent(title: "公演", category: theater))
        let movieVisit = Visit(event: ExperienceEvent(title: "映画", category: movie))
        let person = PersonMaster(displayName: "人物")
        let legacyCast = EventPersonLink(roleKey: "cast", person: person, visit: theaterVisit)
        let movieFocus = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            person: person,
            visit: movieVisit
        )

        XCTAssertTrue(TheaterFocusPersonAnalytics.make(
            people: [person],
            links: [legacyCast, movieFocus],
            visits: [theaterVisit, movieVisit]
        ).isEmpty)
    }

    func testBackupJSONKeepsCreditsAndFocusLinkWithoutCreatingFavo() throws {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(
            title: "公演",
            unitFieldsRaw: VisitUnitFields(eventCreditsText: "出演：山田 花子").encodedRawValue,
            category: category
        )
        let visit = Visit(event: event)
        let person = PersonMaster(displayName: "山田 花子")
        let focus = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            displayRole: "お目当て・注目",
            person: person,
            visit: visit
        )
        focus.memo = TheaterFocusLinkMetadata(
            reactionKeys: ["target", "precious"]
        ).encodedMemo
        let json = try JSONBackupExportService.makeBackupJSON(
            categories: [category],
            events: [event],
            visits: [visit],
            inboxItems: [],
            photos: [],
            socialAccounts: [],
            people: [person],
            companions: [],
            favoriteProfiles: [],
            favoGalleryPhotos: [],
            favoAnniversaries: [],
            favoPins: [],
            personLinks: [focus],
            places: [],
            plans: [],
            ticketAccounts: [],
            ticketAttempts: []
        )
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(FavorecoBackupEnvelope.self, from: data)

        XCTAssertEqual(
            VisitUnitFields(rawValue: try XCTUnwrap(restored.events.first).unitFieldsRaw).eventCreditsText,
            "出演：山田 花子"
        )
        XCTAssertEqual(restored.personLinks.first?.roleKey, TheaterFocusPersonAnalytics.roleKey)
        XCTAssertEqual(restored.personLinks.first?.personID, person.id)
        XCTAssertEqual(restored.personLinks.first?.visitID, visit.id)
        XCTAssertEqual(
            TheaterFocusLinkMetadata(memo: try XCTUnwrap(restored.personLinks.first).memo).reactionKeys,
            ["target", "precious"]
        )
        XCTAssertTrue(restored.favoriteProfiles?.isEmpty == true)
        XCTAssertTrue(restored.favoPins?.isEmpty == true)
    }
}
