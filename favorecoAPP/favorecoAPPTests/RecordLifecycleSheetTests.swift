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
            .init(primary: true, memories: true, notes: false)
        )
        XCTAssertEqual(
            RecordLifecycleBlockExpansion.resolved(for: .afterExperience),
            .init(primary: false, memories: true, notes: true)
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
}
