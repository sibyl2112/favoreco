import XCTest
@testable import favoreco

@MainActor
final class TheaterVisitEditBoundaryTests: XCTestCase {
    func testTheaterVisitEditDoesNotMutateTarget() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_000)
        let originalFields = VisitUnitFields(
            socialLinks: ["https://example.com/original"],
            eventSubtitle: "初演"
        ).encodedRawValue
        let event = ExperienceEvent(
            title: "元の公演名",
            seriesName: "元のシリーズ",
            subTypeKey: "musical",
            organizerNameSnapshot: "元の主催",
            representativeEyecatchPath: "original.jpg",
            officialURL: "https://example.com/official",
            unitFieldsRaw: originalFields,
            updatedAt: originalUpdatedAt,
            category: category
        )
        var draft = AddExperienceDraft()
        draft.title = "変更後の公演名"
        draft.seriesName = "変更後のシリーズ"
        draft.subTypeKey = "play"
        draft.officialURL = "https://example.com/changed"
        draft.socialLinksText = "https://example.com/changed-social"
        draft.eventSubtitle = "変更後の副題"

        applyTargetChangesFromExperienceEdit(
            to: event,
            draft: draft,
            categories: [category],
            at: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(event.title, "元の公演名")
        XCTAssertEqual(event.seriesName, "元のシリーズ")
        XCTAssertEqual(event.subTypeKey, "musical")
        XCTAssertEqual(event.organizerNameSnapshot, "元の主催")
        XCTAssertEqual(event.representativeEyecatchPath, "original.jpg")
        XCTAssertEqual(event.officialURL, "https://example.com/official")
        XCTAssertEqual(event.unitFieldsRaw, originalFields)
        XCTAssertEqual(event.updatedAt, originalUpdatedAt)
        XCTAssertEqual(event.category?.id, category.id)
    }

    func testNonTheaterExperienceEditKeepsExistingCombinedBehavior() {
        let category = RecordCategory(name: "映画", templateKey: "movie")
        let event = ExperienceEvent(title: "元の作品名", category: category)
        var draft = AddExperienceDraft()
        draft.title = "変更後の作品名"
        draft.seriesName = "シリーズ"
        draft.officialURL = "https://example.com/movie"
        let now = Date(timeIntervalSince1970: 2_000)

        applyTargetChangesFromExperienceEdit(
            to: event,
            draft: draft,
            categories: [category],
            at: now
        )

        XCTAssertEqual(event.title, "変更後の作品名")
        XCTAssertEqual(event.seriesName, "シリーズ")
        XCTAssertEqual(event.officialURL, "https://example.com/movie")
        XCTAssertEqual(event.updatedAt, now)
    }
}
