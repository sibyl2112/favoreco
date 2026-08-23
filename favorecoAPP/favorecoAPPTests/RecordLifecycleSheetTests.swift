import XCTest
@testable import favoreco

@MainActor
final class RecordLifecycleSheetTests: XCTestCase {
    func testOpeningStageUsesOneSharedThreeBlockPolicy() {
        XCTAssertEqual(
            RecordLifecycleBlockExpansion.resolved(for: .initialRecord),
            .init(primary: true, memories: false, notes: false)
        )
        XCTAssertEqual(
            RecordLifecycleBlockExpansion.resolved(for: .plannedTarget),
            .init(primary: true, memories: false, notes: false)
        )
        XCTAssertEqual(
            RecordLifecycleBlockExpansion.resolved(for: .afterExperience),
            .init(primary: false, memories: true, notes: false)
        )
    }

    func testVisitDraftInheritsThePlansPlaceSnapshot() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(7_200)
        let place = PlaceMaster(
            name: "国立新美術館",
            prefecture: "東京都",
            address: "東京都港区六本木7-22-2",
            latitude: 35.6653,
            longitude: 139.7264,
            officialURL: "https://www.nact.jp/"
        )
        let event = ExperienceEvent(title: "光の粒子展")
        let plan = Plan(
            title: event.title,
            startsAt: start,
            endsAt: end,
            venueNameSnapshot: place.name,
            officialURL: "https://example.com/exhibition",
            memo: "音声ガイドを確認",
            event: event,
            placeMaster: place
        )

        let draft = VisitDraft(plan: plan)

        XCTAssertEqual(plan.event?.id, event.id)
        XCTAssertEqual(plan.placeMaster?.id, place.id)
        XCTAssertEqual(draft.visitedAt, start)
        XCTAssertEqual(draft.endedAt, end)
        XCTAssertEqual(draft.venueName, place.name)
        XCTAssertEqual(draft.venueAddress, place.address)
        XCTAssertEqual(draft.venueOfficialURL, place.officialURL)
        XCTAssertEqual(draft.latitude, place.latitude)
        XCTAssertEqual(draft.longitude, place.longitude)
        XCTAssertTrue(draft.note.contains("音声ガイドを確認"))
        XCTAssertTrue(draft.note.contains("https://example.com/exhibition"))
    }

    func testPlanMemoriesRoundTripAndBecomeTheVisitDraft() {
        let moment = VisitMomentEntry(title: "企画展示", note: "音声ガイドがよかった")
        let setlist = LiveSetlistEntry(kind: .song, text: "Opening")
        let person = PlanMemoryPerson(name: "白瀬 碧", roleKey: "author")
        let expense = VisitExpenseEntry(title: "図録", amount: Decimal(2_200))
        let advanced = AdvancedFieldEntry(label: "整理番号", value: "A-12")
        let fields = PlanPreparationFields(
            attendanceMethodKey: "live_viewing",
            tagNames: ["再訪したい"],
            overallRating: 4.5,
            momentEntries: [moment],
            liveSetlistEntries: [setlist],
            people: [person],
            amountText: "2200",
            expenseEntries: [expense],
            ocrText: "図録 2,200円",
            advancedEntries: [advanced]
        )
        let restored = PlanPreparationFields(rawValue: fields.encodedRawValue)
        let plan = Plan(title: "青の考古学", memo: "展示室が静か", unitFieldsRaw: fields.encodedRawValue)
        let draft = VisitDraft(plan: plan)

        XCTAssertEqual(restored.overallRating, 4.5)
        XCTAssertEqual(restored.attendanceMethodKey, "live_viewing")
        XCTAssertEqual(restored.momentEntries, [moment])
        XCTAssertEqual(restored.liveSetlistEntries, [setlist])
        XCTAssertEqual(restored.people, [person])
        XCTAssertEqual(restored.amountText, "2200")
        XCTAssertEqual(restored.expenseEntries, [expense])
        XCTAssertEqual(restored.ocrText, "図録 2,200円")
        XCTAssertEqual(restored.advancedEntries, [advanced])
        XCTAssertEqual(draft.overallRating, 4.5)
        XCTAssertEqual(draft.momentEntries, [moment])
        XCTAssertEqual(draft.liveSetlistEntries, [setlist])
        XCTAssertEqual(draft.amountText, "2200")
        XCTAssertEqual(draft.expenseEntries, [expense])
        XCTAssertEqual(draft.ocrText, "図録 2,200円")
        XCTAssertEqual(draft.advancedEntries, [advanced])
        XCTAssertEqual(draft.tagNamesText, "再訪したい")
        XCTAssertTrue(draft.note.contains("展示室が静か"))
    }

    func testTheaterCreditPersonFieldsRoundTripWithoutBecomingFavo() {
        let pending = PendingPersonLink(
            name: "森田ユウ",
            reading: "もりた ゆう",
            role: PersonRoleOption.option(for: "cast"),
            roleDetail: "冬木役",
            affiliationName: "月灯り劇団",
            entityKind: .person,
            isEventFocus: true
        )

        let snapshot = PlanMemoryPerson(pending)
        let restored = snapshot.pendingPersonLink
        let person = PersonMaster(displayName: pending.name, reading: pending.reading)
        let link = pending.makeEventPersonLink(person: person, event: nil, visit: nil, sortOrder: 0)

        XCTAssertEqual(restored.name, "森田ユウ")
        XCTAssertEqual(restored.reading, "もりた ゆう")
        XCTAssertEqual(restored.roleDetail, "冬木役")
        XCTAssertEqual(restored.affiliationName, "月灯り劇団")
        XCTAssertTrue(restored.isEventFocus)
        XCTAssertEqual(link.displayRole, "出演｜冬木役")
        XCTAssertTrue(TheaterEventCreditMetadata.isHighlighted(link))
        XCTAssertNil(person.favoriteProfile)
    }

    func testLegacyPlanMemoryPersonDecodesWithNewCreditFieldsEmpty() throws {
        let legacyJSON = #"{"name":"佐倉ミナ","roleKey":"cast","entityKindKey":"person"}"#
        let restored = try JSONDecoder().decode(
            PlanMemoryPerson.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertEqual(restored.name, "佐倉ミナ")
        XCTAssertEqual(restored.roleKey, "cast")
        XCTAssertEqual(restored.reading, "")
        XCTAssertEqual(restored.roleDetail, "")
        XCTAssertEqual(restored.affiliationName, "")
        XCTAssertFalse(restored.isEventFocus)
    }

    func testPlanUsesTheSameEditDraftAsAVisitWithoutCreatingAVisit() {
        let category = RecordCategory(name: "ミュージアム", templateKey: "museum")
        let event = ExperienceEvent(title: "透明な記憶", category: category)
        let place = PlaceMaster(
            name: "京都国立博物館",
            address: "京都府京都市東山区茶屋町527",
            officialURL: "https://www.kyohaku.go.jp/"
        )
        let fields = PlanPreparationFields(
            tagNames: ["再訪"],
            overallRating: 3.5,
            ocrText: "前売券"
        )
        let plan = Plan(
            title: event.title,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000),
            endsAt: Date(timeIntervalSince1970: 1_800_007_200),
            venueNameSnapshot: place.name,
            memo: "常設展も見る",
            unitFieldsRaw: fields.encodedRawValue,
            category: category,
            event: event,
            placeMaster: place
        )

        let draft = AddExperienceDraft(plan: plan)

        XCTAssertNil(plan.visit)
        XCTAssertEqual(draft.title, event.title)
        XCTAssertEqual(draft.venueName, place.name)
        XCTAssertEqual(draft.venueAddress, place.address)
        XCTAssertEqual(draft.venueOfficialURL, place.officialURL)
        XCTAssertEqual(draft.overallRating, 3.5)
        XCTAssertEqual(draft.tagNamesText, "再訪")
        XCTAssertEqual(draft.ocrText, "前売券")
        XCTAssertEqual(draft.note, "常設展も見る")
    }
}
