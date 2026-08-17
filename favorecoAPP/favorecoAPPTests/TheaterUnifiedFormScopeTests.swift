import XCTest
@testable import favoreco

final class TheaterUnifiedFormScopeTests: XCTestCase {
    func testTheaterEntriesDescribeTheCorrectEditingScope() {
        XCTAssertEqual(
            TheaterUnifiedFormEntry.performanceEditing.scope(isLive: false),
            "この公演のすべての予定・記録"
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.planEditing.scope(isLive: false),
            "この観劇予定だけ"
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.visitEditing.scope(isLive: false),
            "この観劇回だけ"
        )
    }

    func testLiveEntriesUseLiveSpecificLanguage() {
        XCTAssertEqual(
            TheaterUnifiedFormEntry.performanceEditing.scope(isLive: true),
            "このライブのすべての予定・記録"
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.planEditing.scope(isLive: true),
            "この参戦予定だけ"
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.visitEditing.scope(isLive: true),
            "この参戦回だけ"
        )
    }

    func testCreationAndEditingShareTheSameDataBoundary() {
        XCTAssertEqual(
            TheaterUnifiedFormEntry.performanceRegistration.scope(isLive: false),
            TheaterUnifiedFormEntry.performanceEditing.scope(isLive: false)
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.planCreation.scope(isLive: false),
            TheaterUnifiedFormEntry.planEditing.scope(isLive: false)
        )
        XCTAssertEqual(
            TheaterUnifiedFormEntry.visitCreation.scope(isLive: false),
            TheaterUnifiedFormEntry.visitEditing.scope(isLive: false)
        )
    }
}
