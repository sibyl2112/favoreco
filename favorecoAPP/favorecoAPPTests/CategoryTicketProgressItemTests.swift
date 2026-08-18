import XCTest
@testable import favoreco

@MainActor
final class CategoryTicketProgressItemTests: XCTestCase {
    func testTheaterTopKeepsOnlyUndatedActiveTicketPlans() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let undated = makePlan(
            category: category,
            planKindKey: Plan.undatedTicketPlanKindKey,
            statusKey: "beforeApply"
        )
        let dated = makePlan(
            category: category,
            planKindKey: "event",
            statusKey: "beforeApply"
        )

        XCTAssertEqual(
            CategoryTicketProgressItem.topItems(
                in: [dated.plan, undated.plan],
                category: category
            ).map(\.attempt.id),
            [undated.attempt.id]
        )
    }

    func testLiveTopKeepsActionableStagesAndExcludesIssued() {
        let category = RecordCategory(name: "LIVE", templateKey: "live")
        let actionable = makePlan(
            category: category,
            planKindKey: "event",
            statusKey: "waitingPayment"
        )
        let issued = makePlan(
            category: category,
            planKindKey: "event",
            statusKey: "issued"
        )

        XCTAssertEqual(
            CategoryTicketProgressItem.topItems(
                in: [issued.plan, actionable.plan],
                category: category
            ).map(\.attempt.id),
            [actionable.attempt.id]
        )
    }

    func testOtherGenresKeepAllActiveItemsWithinSelectedCategory() {
        let category = RecordCategory(name: "ミュージアム", templateKey: "museum")
        let otherCategory = RecordCategory(name: "別ジャンル", templateKey: "custom")
        let active = makePlan(
            category: category,
            planKindKey: "event",
            statusKey: "issued"
        )
        let other = makePlan(
            category: otherCategory,
            planKindKey: "event",
            statusKey: "waitingPayment"
        )

        XCTAssertEqual(
            CategoryTicketProgressItem.topItems(
                in: [other.plan, active.plan],
                category: category
            ).map(\.attempt.id),
            [active.attempt.id]
        )
    }

    private func makePlan(
        category: RecordCategory,
        planKindKey: String,
        statusKey: String
    ) -> (plan: Plan, attempt: TicketAttempt) {
        let plan = Plan(
            planKindKey: planKindKey,
            category: category
        )
        let attempt = TicketAttempt(statusKey: statusKey, plan: plan)
        plan.ticketAttempts = [attempt]
        return (plan, attempt)
    }
}
