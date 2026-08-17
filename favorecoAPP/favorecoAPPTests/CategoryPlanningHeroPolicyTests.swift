import XCTest
@testable import favoreco

final class CategoryPlanningHeroPolicyTests: XCTestCase {
    func testForwardPlanningGenresKeepCombinedHeroAvailableButUseMemoryLayout() {
        for templateKey in ["movie", "museum", "theme_park", "nature_living"] {
            XCTAssertTrue(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
            XCTAssertFalse(CategoryPlanningHeroPolicy.usesIntegratedHero(templateKey), templateKey)
            XCTAssertTrue(CategoryMemoryHeroPolicy.supports(templateKey), templateKey)
        }
    }

    func testSpecializedAndAfterTheFactGenresDoNotUseCombinedHero() {
        for templateKey in ["theater", "live", "book", "goshuin", "sake", "random_goods", "outing_facility"] {
            XCTAssertFalse(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
        }
    }

    func testLiveActionableTicketStagesStayInTicketManagement() {
        for statusKey in ["beforeApply", "onSaleSoon", "waitingResult", "won", "waitingPayment", "waitingIssue"] {
            XCTAssertTrue(LiveTicketPlacementPolicy.showsInTicketManagement(statusKey: statusKey), statusKey)
        }
    }

    func testLiveComingUpAllowsNoTicketOrCompletedTicketFlow() {
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: []))
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["issued"]))
        XCTAssertTrue(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["lost", "skipped"]))
        XCTAssertFalse(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["waitingPayment"]))
        XCTAssertFalse(LiveTicketPlacementPolicy.allowsComingUp(statusKeys: ["issued", "waitingIssue"]))
    }

    func testTheaterAndLiveInformationUseParentEventCards() {
        for templateKey in ["theater", "live"] {
            XCTAssertTrue(
                CategoryEventInformationPolicy.usesParentEventCard(
                    templateKey: templateKey,
                    sectionKey: "productions"
                ),
                templateKey
            )
        }
    }

    func testPlanningAndHistorySectionsDoNotUseParentEventCards() {
        for sectionKey in ["interests", "coming-up", "history"] {
            XCTAssertFalse(
                CategoryEventInformationPolicy.usesParentEventCard(
                    templateKey: "live",
                    sectionKey: sectionKey
                ),
                sectionKey
            )
        }
    }

    func testTheaterAndLiveUseFullTicketManagementPlanCards() {
        XCTAssertTrue(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "theater"))
        XCTAssertTrue(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "live"))
        XCTAssertFalse(PerformanceTicketManagementPolicy.usesFullPlanCard(templateKey: "movie"))
    }
}
