import XCTest
@testable import favoreco

@MainActor
final class PlanPreparationKindTests: XCTestCase {
    func testKindOrderSeparatesTravelTypesFromOtherPreparation() {
        XCTAssertEqual(
            PlanPreparationKind.allCases.map(\.title),
            [
                "宿泊",
                "新幹線",
                "飛行機",
                "高速・夜行バス",
                "現地交通",
                "レンタカー",
                "荷物・持ち物",
                "その他の遠征",
                "その他の準備",
            ]
        )
    }

    func testNewTravelKindsAreInferredBeforeGenericLocalTransport() {
        XCTAssertEqual(PlanPreparationKind.inferred(from: "夜行バスを予約"), .highwayBus)
        XCTAssertEqual(PlanPreparationKind.inferred(from: "レンタカーを予約"), .rentalCar)
        XCTAssertEqual(PlanPreparationKind.inferred(from: "持ち物を準備"), .baggage)
        XCTAssertEqual(PlanPreparationKind.inferred(from: "会場までのバスを確認"), .localTransport)
    }

    func testLodgingSuggestionUsesHotelKindAndRemainsAvailable() {
        XCTAssertEqual(PlanPreparationKind.inferred(from: "宿泊を予約"), .hotel)
        XCTAssertEqual(PlanPreparationKind(rawValue: "hotel"), .hotel)
        XCTAssertTrue(PlanPreparationSuggestion.titles.contains("宿泊を予約"))
    }

    func testTicketTaskIsNotDuplicatedInPreparationSuggestions() {
        XCTAssertFalse(PlanPreparationSuggestion.titles.contains("チケット・座席を確認"))
    }

    func testPlanTagsRoundTripWithoutLosingPreparationTasks() {
        let task = PlanPreparationTask(title: "ホテルを予約", kindKey: PlanPreparationKind.hotel.rawValue)
        let fields = PlanPreparationFields(tasks: [task], tagNames: ["遠征", "初日"])

        let restored = PlanPreparationFields(rawValue: fields.encodedRawValue)

        XCTAssertEqual(restored.tagNames, ["遠征", "初日"])
        XCTAssertEqual(restored.tasks.map(\.title), ["ホテルを予約"])
    }

    func testOldPlanPreparationJSONDefaultsToNoTags() {
        let restored = PlanPreparationFields(
            rawValue: #"{"checklistModeKey":"automatic","tasks":[]}"#
        )

        XCTAssertEqual(restored.tagNames, [])
    }
}
