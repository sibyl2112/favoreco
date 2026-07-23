import XCTest
@testable import favoreco

@MainActor
final class TheaterVisitCastTests: XCTestCase {
    func testLegacyVisitInheritsEventCast() {
        let actor = PersonMaster(displayName: "公演キャスト")
        let eventLink = EventPersonLink(roleKey: "cast", person: actor)

        let actual = TheaterVisitCastResolver.actualCastLinks(
            eventLinks: [eventLink],
            visitLinks: [],
            excludedEventLinkIDs: []
        )

        XCTAssertEqual(actual.map { $0.person?.id }, [actor.id])
    }

    func testExcludedEventCastAndVisitReplacementResolveAsActualCast() {
        let restingActor = PersonMaster(displayName: "休演者")
        let replacementActor = PersonMaster(displayName: "代役")
        let eventLink = EventPersonLink(roleKey: "cast", person: restingActor)
        let visitLink = EventPersonLink(roleKey: "replacement", person: replacementActor)

        let actual = TheaterVisitCastResolver.actualCastLinks(
            eventLinks: [eventLink],
            visitLinks: [visitLink],
            excludedEventLinkIDs: [eventLink.id]
        )

        XCTAssertEqual(actual.map { $0.person?.id }, [replacementActor.id])
    }

    func testVisitSnapshotDoesNotChangeWhenEventCastChangesLater() {
        let originalActor = PersonMaster(displayName: "観た出演者")
        let laterActor = PersonMaster(displayName: "後日追加された出演者")
        let visit = Visit()
        let originalEventLink = EventPersonLink(roleKey: "cast", person: originalActor)
        let snapshotLink = TheaterVisitCastResolver.makeInheritedSnapshotLink(
            from: originalEventLink,
            visit: visit,
            sortOrder: 0
        )
        let laterEventLink = EventPersonLink(roleKey: "cast", person: laterActor)

        let actual = TheaterVisitCastResolver.actualCastLinks(
            eventLinks: [originalEventLink, laterEventLink],
            visitLinks: [snapshotLink],
            excludedEventLinkIDs: [],
            usesVisitSnapshot: true
        )

        XCTAssertEqual(actual.map { $0.person?.id }, [originalActor.id])
        XCTAssertEqual(
            TheaterVisitCastResolver.sourceEventLinkID(for: snapshotLink),
            originalEventLink.id
        )
    }

    func testVisitSpecificRoleOverridesInheritedRoleWithoutDuplication() {
        let actor = PersonMaster(displayName: "出演者")
        let visit = Visit()
        let eventLink = EventPersonLink(roleKey: "cast", person: actor)
        let inheritedLink = TheaterVisitCastResolver.makeInheritedSnapshotLink(
            from: eventLink,
            visit: visit,
            sortOrder: 0
        )
        let replacementLink = EventPersonLink(
            roleKey: "replacement",
            displayRole: "代役",
            person: actor,
            visit: visit
        )

        let actual = TheaterVisitCastResolver.actualCastLinks(
            eventLinks: [eventLink],
            visitLinks: [inheritedLink, replacementLink],
            excludedEventLinkIDs: [],
            usesVisitSnapshot: true
        )

        XCTAssertEqual(actual.count, 1)
        XCTAssertEqual(actual.first?.roleKey, "replacement")
    }

    func testVisitCastFieldsAreBackwardCompatibleAndRoundTrip() throws {
        let legacy = VisitUnitFields(rawValue: #"{"styleNames":["現地"]}"#)
        XCTAssertFalse(legacy.hasVisitCastSnapshot)
        XCTAssertTrue(legacy.excludedEventCastLinkIDs.isEmpty)

        let excludedID = UUID()
        let stored = VisitUnitFields(
            excludedEventCastLinkIDs: [excludedID],
            hasVisitCastSnapshot: true
        )
        let restored = VisitUnitFields(rawValue: stored.encodedRawValue)

        XCTAssertTrue(restored.hasVisitCastSnapshot)
        XCTAssertEqual(restored.excludedEventCastLinkIDs, [excludedID])
    }
}
