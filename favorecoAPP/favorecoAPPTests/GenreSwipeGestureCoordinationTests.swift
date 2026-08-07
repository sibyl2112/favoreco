import XCTest
import UIKit
@testable import favoreco

@MainActor
final class GenreSwipeGestureCoordinationTests: XCTestCase {
    func testSmallFingerMovementDoesNotActivateGenreSwipe() {
        XCTAssertFalse(
            GenreSwipeGestureCoordination.hasReachedActivationDistance(
                CGPoint(x: 14, y: 4)
            )
        )
    }

    func testIntentionalDragActivatesGenreSwipe() {
        XCTAssertTrue(
            GenreSwipeGestureCoordination.hasReachedActivationDistance(
                CGPoint(x: 25, y: 2)
            )
        )
    }

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
