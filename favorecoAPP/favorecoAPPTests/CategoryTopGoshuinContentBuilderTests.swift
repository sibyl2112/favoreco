import XCTest
@testable import favoreco

@MainActor
final class CategoryTopGoshuinContentBuilderTests: XCTestCase {
    func testMapVisitsCombinesKindAndPrefectureFilters() {
        let tokyoShrine = Visit(
            venueNameSnapshot: "東京神社",
            note: "東京都千代田区"
        )
        let kyotoTemple = Visit(
            venueNameSnapshot: "京都観音寺",
            note: "京都府京都市"
        )

        XCTAssertEqual(
            GoshuinTopContentBuilder.mapVisits(
                [kyotoTemple, tokyoShrine],
                filter: .shrine,
                selectedPrefecture: "東京都"
            ).map(\.id),
            [tokyoShrine.id]
        )
        XCTAssertEqual(
            GoshuinTopContentBuilder.availablePrefectures(in: [kyotoTemple, tokyoShrine]),
            ["東京都", "京都府"]
        )
    }

    func testBookSelectionsKeepSavedOrderAndSortVisitsNewestFirst() {
        let olderStandard = Visit(
            visitedAt: Date(timeIntervalSince1970: 1_000),
            unitFieldsRaw: VisitUnitFields(
                goshuinBookSizeKey: GoshuinBookSize.standard.key
            ).encodedRawValue
        )
        let newerStandard = Visit(
            visitedAt: Date(timeIntervalSince1970: 3_000),
            unitFieldsRaw: VisitUnitFields(
                goshuinBookSizeKey: GoshuinBookSize.standard.key
            ).encodedRawValue
        )
        let large = Visit(
            visitedAt: Date(timeIntervalSince1970: 2_000),
            unitFieldsRaw: VisitUnitFields(
                goshuinBookSizeKey: GoshuinBookSize.large.key
            ).encodedRawValue
        )

        let selections = GoshuinTopContentBuilder.bookSelections(
            from: [olderStandard, large, newerStandard],
            registeredSizeKeysRaw: GoshuinBookSize.wide.key,
            closedSizeKeysRaw: GoshuinBookSize.large.key,
            sortOrderKeysRaw: "\(GoshuinBookSize.large.key),\(GoshuinBookSize.standard.key)"
        )

        XCTAssertEqual(
            selections.map(\.size.key),
            [GoshuinBookSize.large.key, GoshuinBookSize.standard.key, GoshuinBookSize.wide.key]
        )
        XCTAssertFalse(selections[0].isActive)
        XCTAssertEqual(selections[1].visits.map(\.id), [newerStandard.id, olderStandard.id])
        XCTAssertTrue(selections[2].visits.isEmpty)
    }

    func testBookSelectionsUseStandardSizeForLegacyEmptyKey() {
        let legacyVisit = Visit(visitedAt: Date(timeIntervalSince1970: 1_000))

        let selections = GoshuinTopContentBuilder.bookSelections(
            from: [legacyVisit],
            registeredSizeKeysRaw: "",
            closedSizeKeysRaw: "",
            sortOrderKeysRaw: ""
        )

        XCTAssertEqual(selections.map(\.size.key), [GoshuinBookSize.standard.key])
        XCTAssertEqual(selections[0].visits.map(\.id), [legacyVisit.id])
        XCTAssertTrue(selections[0].isActive)
    }
}
