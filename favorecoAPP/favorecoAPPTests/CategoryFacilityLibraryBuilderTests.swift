import XCTest
@testable import favoreco

final class CategoryFacilityLibraryBuilderTests: XCTestCase {
    func testBuildsSortedFacilityLibraryWithoutCrossCategoryOrArchivedRelations() {
        let category = RecordCategory(name: "ミュージアム", templateKey: "museum")
        let otherCategory = RecordCategory(name: "別ジャンル", templateKey: "custom")

        let visitPlace = PlaceMaster(name: "A 記録施設")
        let catalogPlace = PlaceMaster(name: "B 公開施設", placeTagsRaw: "museum")
        let planPlace = PlaceMaster(name: "C 予定施設")
        let unrelatedPlace = PlaceMaster(name: "D 別ジャンル施設")
        let archivedCatalogPlace = PlaceMaster(
            name: "E 非表示施設",
            placeTagsRaw: "museum",
            isArchived: true
        )
        let archivedPlanPlace = PlaceMaster(name: "F 終了予定だけの施設")

        let activePlan = Plan(
            title: "予定",
            category: category,
            placeMaster: planPlace
        )
        let otherPlan = Plan(
            title: "別ジャンル予定",
            category: otherCategory,
            placeMaster: unrelatedPlace
        )
        let archivedPlan = Plan(
            title: "終了予定",
            isArchived: true,
            category: category,
            placeMaster: archivedPlanPlace
        )
        let event = ExperienceEvent(title: "鑑賞", category: category)
        let visit = Visit(event: event, placeMaster: visitPlace)

        let snapshot = CategoryFacilityLibraryBuilder.make(
            category: category,
            allPlans: [otherPlan, archivedPlan, activePlan],
            allVisits: [visit],
            allPlaceMasters: [
                archivedPlanPlace,
                planPlace,
                archivedCatalogPlace,
                catalogPlace,
                unrelatedPlace,
                visitPlace,
            ]
        )

        XCTAssertEqual(snapshot.places.map(\.id), [visitPlace.id, catalogPlace.id, planPlace.id])
        XCTAssertEqual(snapshot.plans(for: planPlace).map(\.id), [activePlan.id])
        XCTAssertTrue(snapshot.plans(for: catalogPlace).isEmpty)
        XCTAssertEqual(snapshot.visits(for: visitPlace).map(\.id), [visit.id])
        XCTAssertTrue(snapshot.visits(for: planPlace).isEmpty)
    }

    func testEmptyInputProducesEmptyLibrary() {
        let category = RecordCategory(name: "その他", templateKey: "custom")

        let snapshot = CategoryFacilityLibraryBuilder.make(
            category: category,
            allPlans: [],
            allVisits: [],
            allPlaceMasters: []
        )

        XCTAssertTrue(snapshot.places.isEmpty)
    }
}
