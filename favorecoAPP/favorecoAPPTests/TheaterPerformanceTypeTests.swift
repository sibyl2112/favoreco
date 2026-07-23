import XCTest
@testable import favoreco

final class TheaterPerformanceTypeTests: XCTestCase {
    func testBuiltInPerformanceTypesKeepAgreedOrder() {
        XCTAssertEqual(
            TheaterPerformanceType.allCases.map(\.displayName),
            [
                "演劇",
                "2.5次元舞台",
                "ミュージカル",
                "歌舞伎",
                "落語・寄席",
                "ダンス・バレエ",
                "オペラ",
                "その他",
            ]
        )
    }

    func testOtherUsesConcreteCustomName() {
        let key = TheaterPerformanceType.other.rawValue

        XCTAssertFalse(TheaterPerformanceType.isValidSelection(key: key, customName: "  "))
        XCTAssertTrue(TheaterPerformanceType.isValidSelection(key: key, customName: "能"))
        XCTAssertEqual(TheaterPerformanceType.customNameForStorage(key: key, input: "  能  "), "能")
        XCTAssertEqual(TheaterPerformanceType.displayName(for: key, customName: "能"), "能")
    }

    func testStandardTypeDoesNotKeepHiddenCustomName() {
        let key = TheaterPerformanceType.musical.rawValue

        XCTAssertEqual(TheaterPerformanceType.customNameForStorage(key: key, input: "能"), "")
        XCTAssertEqual(TheaterPerformanceType.displayName(for: key, customName: "能"), "ミュージカル")
    }

    func testCustomPerformanceTypeSurvivesUnitFieldsRoundTrip() {
        let original = VisitUnitFields(eventPerformanceTypeCustomName: "能")
        let restored = VisitUnitFields(rawValue: original.encodedRawValue)

        XCTAssertEqual(restored.eventPerformanceTypeCustomName, "能")
    }
}
