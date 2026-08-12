import XCTest
@testable import favoreco

final class CategoryPlanningHeroPolicyTests: XCTestCase {
    func testForwardPlanningGenresUseCombinedHero() {
        for templateKey in ["movie", "live", "museum", "theme_park", "nature_living"] {
            XCTAssertTrue(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
        }
    }

    func testSpecializedAndAfterTheFactGenresDoNotUseCombinedHero() {
        for templateKey in ["theater", "book", "goshuin", "sake", "random_goods", "outing_facility"] {
            XCTAssertFalse(CategoryPlanningHeroPolicy.supports(templateKey), templateKey)
        }
    }
}
