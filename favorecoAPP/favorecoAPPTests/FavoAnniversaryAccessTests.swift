import XCTest
@testable import favoreco

final class FavoAnniversaryAccessTests: XCTestCase {
    func testFreePlanCanCreateAndEditOneAnniversary() {
        XCTAssertTrue(FavoAnniversaryAccess.canAdd(plan: .free, existingCount: 0))
        XCTAssertFalse(FavoAnniversaryAccess.canAdd(plan: .free, existingCount: 1))
        XCTAssertTrue(FavoAnniversaryAccess.canEditExisting(plan: .free, existingCount: 1))
    }

    func testPaidPlansCanManageMultipleAnniversaries() {
        let paidPlans: [FavorecoPlan] = [.lightLifetime, .syncSubscription, .fullLifetime]

        for plan in paidPlans {
            XCTAssertTrue(FavoAnniversaryAccess.canAdd(plan: plan, existingCount: 8))
            XCTAssertTrue(FavoAnniversaryAccess.canEditExisting(plan: plan, existingCount: 8))
        }
    }

    func testDowngradedPlanKeepsMultipleAnniversariesReadOnly() {
        XCTAssertFalse(FavoAnniversaryAccess.canAdd(plan: .free, existingCount: 3))
        XCTAssertFalse(FavoAnniversaryAccess.canEditExisting(plan: .free, existingCount: 3))
    }
}
