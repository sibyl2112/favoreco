import XCTest
import UIKit
@testable import favoreco

@MainActor
final class GenreSwipeGestureCoordinationTests: XCTestCase {
    func testAllowsSimultaneousPanForVerticalScrollCoordination() {
        XCTAssertTrue(
            GenreSwipeGestureCoordination.allowsSimultaneousRecognition(
                with: UIPanGestureRecognizer()
            )
        )
    }

    func testRejectsSimultaneousTapSoSwipeCancelsCardAction() {
        XCTAssertFalse(
            GenreSwipeGestureCoordination.allowsSimultaneousRecognition(
                with: UITapGestureRecognizer()
            )
        )
    }

    func testRejectsSimultaneousLongPressUsedByInteractiveControls() {
        XCTAssertFalse(
            GenreSwipeGestureCoordination.allowsSimultaneousRecognition(
                with: UILongPressGestureRecognizer()
            )
        )
    }
}
