import XCTest
@testable import favoreco

final class CollectibleKindTests: XCTestCase {
    func testCommonGoodsKindsRemainStableAndComplete() {
        XCTAssertEqual(
            CollectibleKind.allCases.map(\.rawValue),
            [
                "capsule_toy",
                "acrylic_stand",
                "acrylic_keychain",
                "can_badge",
                "bromide",
                "card",
                "sticker",
                "plush",
                "keychain_strap",
                "figure",
                "other",
            ]
        )
    }

    func testLegacyKindsKeepTheirStoredRawValues() {
        XCTAssertEqual(CollectibleKind.resolved(from: "capsule_toy"), .capsuleToy)
        XCTAssertEqual(CollectibleKind.resolved(from: "acrylic_keychain"), .acrylicKeychain)
        XCTAssertEqual(CollectibleKind.resolved(from: "can_badge"), .canBadge)
        XCTAssertEqual(CollectibleKind.resolved(from: "bromide"), .bromide)
        XCTAssertEqual(CollectibleKind.resolved(from: "sticker"), .sticker)
        XCTAssertEqual(CollectibleKind.resolved(from: "other"), .other)
    }

    func testUnknownOrEmptyStoredKindFallsBackToOther() {
        XCTAssertEqual(CollectibleKind.resolved(from: ""), .other)
        XCTAssertEqual(CollectibleKind.resolved(from: "legacy_unknown_kind"), .other)
    }
}
