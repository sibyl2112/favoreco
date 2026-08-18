import XCTest
@testable import favoreco

final class CategoryLibraryPartitionBuilderTests: XCTestCase {
    func testTheaterSeparatesStandaloneInterestButKeepsActionableTicketInProductions() {
        let standaloneInterest = makeItem(title: "気になる", stateKey: "interested")
        let ticketInterest = makeItem(
            title: "申込中",
            stateKey: "interested",
            ticketAttempts: [TicketAttempt(statusKey: "waitingResult")]
        )
        let active = makeItem(title: "公演", stateKey: "active")

        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: "theater",
            items: [standaloneInterest, ticketInterest, active]
        )

        XCTAssertTrue(partition.showsPlanningSections)
        XCTAssertFalse(partition.showsPlaceExperienceSections)
        XCTAssertEqual(partition.interestedItems.map(\.id), [standaloneInterest.id])
        XCTAssertEqual(partition.displayedProductionItems.map(\.id), [ticketInterest.id, active.id])
    }

    func testStandardPlanningCategoryExcludesInterestedItemsWithPlansFromBothLibraries() {
        let standaloneInterest = makeItem(title: "気になる", stateKey: "interested")
        let plannedInterest = makeItem(
            title: "予定あり",
            stateKey: "interested",
            nextPlan: Plan(title: "予定")
        )
        let watched = makeItem(title: "鑑賞済み", stateKey: "active")

        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: "movie",
            items: [standaloneInterest, plannedInterest, watched]
        )

        XCTAssertTrue(partition.showsVisitRecordLibrary)
        XCTAssertEqual(partition.interestedItems.map(\.id), [standaloneInterest.id])
        XCTAssertEqual(partition.displayedProductionItems.map(\.id), [watched.id])
    }

    func testPlaceExperienceKeepsProductionSourceButDoesNotDisplayItAsDuplicateFacilityList() {
        let interest = makeItem(title: "気になる", stateKey: "interested")
        let visited = makeItem(title: "訪問済み", stateKey: "active")

        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: "theme_park",
            items: [interest, visited]
        )

        XCTAssertTrue(partition.showsPlaceExperienceSections)
        XCTAssertEqual(partition.interestedItems.map(\.id), [interest.id])
        XCTAssertEqual(partition.productionItems.map(\.id), [interest.id, visited.id])
        XCTAssertTrue(partition.displayedProductionItems.isEmpty)
    }

    func testBookSeparatesInterestsAndOnlyShowsRecordedNonInterests() {
        let interest = makeItem(title: "気になる本", stateKey: "interested")
        let unread = makeItem(title: "未記録", stateKey: "active")
        let recorded = makeItem(
            title: "読了",
            stateKey: "active",
            latestVisit: Visit()
        )

        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: "book",
            items: [interest, unread, recorded]
        )

        XCTAssertTrue(partition.showsBookSections)
        XCTAssertEqual(partition.interestedItems.map(\.id), [interest.id])
        XCTAssertEqual(partition.displayedProductionItems.map(\.id), [recorded.id])
    }

    func testOtherCategoryPreservesEveryItemAndItsOrder() {
        let first = makeItem(title: "1", stateKey: "interested")
        let second = makeItem(title: "2", stateKey: "active")

        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: "custom",
            items: [first, second]
        )

        XCTAssertFalse(partition.showsPlanningSections)
        XCTAssertFalse(partition.showsBookSections)
        XCTAssertFalse(partition.showsVisitRecordLibrary)
        XCTAssertTrue(partition.interestedItems.isEmpty)
        XCTAssertEqual(partition.displayedProductionItems.map(\.id), [first.id, second.id])
    }

    private func makeItem(
        title: String,
        stateKey: String,
        latestVisit: Visit? = nil,
        nextPlan: Plan? = nil,
        ticketAttempts: [TicketAttempt] = []
    ) -> CategoryLibraryItem {
        CategoryLibraryItem(
            event: ExperienceEvent(title: title, stateKey: stateKey),
            visits: latestVisit.map { [$0] } ?? [],
            latestVisit: latestVisit,
            nextPlan: nextPlan,
            ticketAttempts: ticketAttempts,
            facilityName: "",
            facilityIdentityKey: title,
            placeMasterID: nil
        )
    }
}
