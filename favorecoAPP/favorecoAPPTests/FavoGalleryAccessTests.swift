import XCTest
@testable import favoreco

final class FavoGalleryAccessTests: XCTestCase {
    func testFreePlanCanAddUntilFifteenPhotos() {
        XCTAssertTrue(FavoGalleryAccess.canAdd(plan: .free, existingCount: 0))
        XCTAssertTrue(FavoGalleryAccess.canAdd(plan: .free, existingCount: 14))
        XCTAssertFalse(FavoGalleryAccess.canAdd(plan: .free, existingCount: 15))
    }

    func testFreePlanOnlyAcceptsRemainingSlots() {
        XCTAssertEqual(
            FavoGalleryAccess.availableAdditionCount(
                plan: .free,
                existingCount: 13,
                requestedCount: 5
            ),
            2
        )
        XCTAssertEqual(
            FavoGalleryAccess.availableAdditionCount(
                plan: .free,
                existingCount: 18,
                requestedCount: 1
            ),
            0
        )
    }

    func testPaidPlansHaveNoGalleryLimit() {
        for plan in [FavorecoPlan.lightLifetime, .syncSubscription, .fullLifetime] {
            XCTAssertTrue(FavoGalleryAccess.canAdd(plan: plan, existingCount: 200))
            XCTAssertEqual(
                FavoGalleryAccess.availableAdditionCount(
                    plan: plan,
                    existingCount: 200,
                    requestedCount: 40
                ),
                40
            )
        }
    }
}
