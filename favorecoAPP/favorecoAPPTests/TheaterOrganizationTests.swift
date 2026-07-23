import XCTest
@testable import favoreco

@MainActor
final class TheaterOrganizationTests: XCTestCase {
    func testChildOrganizationRollsUpWithoutDoubleCountingVisits() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(title: "星組公演", category: category)
        let parent = PersonMaster(
            displayName: "宝塚歌劇団",
            entityKindKey: PersonEntityKind.organization.rawValue
        )
        let child = PersonMaster(
            displayName: "星組",
            entityKindKey: PersonEntityKind.organization.rawValue,
            parentOrganizationIDRaw: parent.id.uuidString
        )
        let firstVisit = Visit(event: event)
        let secondVisit = Visit(event: event)
        let firstLink = EventPersonLink(
            roleKey: "performing_organization",
            person: child,
            event: event
        )
        let duplicateLink = EventPersonLink(
            roleKey: "production",
            person: child,
            event: event
        )

        let stats = TheaterOrganizationAnalytics.make(
            people: [parent, child],
            links: [firstLink, duplicateLink],
            visits: [firstVisit, secondVisit]
        )

        XCTAssertEqual(stats.first(where: { $0.id == child.id })?.eventCount, 1)
        XCTAssertEqual(stats.first(where: { $0.id == child.id })?.visitCount, 2)
        XCTAssertEqual(stats.first(where: { $0.id == parent.id })?.eventCount, 1)
        XCTAssertEqual(stats.first(where: { $0.id == parent.id })?.visitCount, 2)
        XCTAssertTrue(stats.first(where: { $0.id == parent.id })?.includesChildOrganizations == true)
    }

    func testCastPersonIsNotIncludedInOrganizationStats() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(title: "公演", category: category)
        let actor = PersonMaster(displayName: "出演者", entityKindKey: PersonEntityKind.person.rawValue)
        let link = EventPersonLink(roleKey: "cast", person: actor, event: event)

        XCTAssertTrue(TheaterOrganizationAnalytics.make(
            people: [actor],
            links: [link],
            visits: [Visit(event: event)]
        ).isEmpty)
    }

    func testOrganizationBackupKeepsKindAndParentID() throws {
        let parentID = UUID()
        let organization = PersonMaster(
            displayName: "星組",
            entityKindKey: PersonEntityKind.organization.rawValue,
            parentOrganizationIDRaw: parentID.uuidString
        )

        let data = try JSONEncoder().encode(BackupPerson(organization))
        let restored = try JSONDecoder().decode(BackupPerson.self, from: data)

        XCTAssertEqual(restored.entityKindKey, PersonEntityKind.organization.rawValue)
        XCTAssertEqual(restored.parentOrganizationIDRaw, parentID.uuidString)
    }

    func testDescendantCannotBeSelectedAsParentOrganization() {
        let parent = PersonMaster(
            displayName: "宝塚歌劇団",
            entityKindKey: PersonEntityKind.organization.rawValue
        )
        let child = PersonMaster(
            displayName: "星組",
            entityKindKey: PersonEntityKind.organization.rawValue,
            parentOrganizationIDRaw: parent.id.uuidString
        )
        let unrelated = PersonMaster(
            displayName: "キャラメルボックス",
            entityKindKey: PersonEntityKind.organization.rawValue
        )

        let candidates = eligibleParentOrganizations(
            for: parent.id,
            among: [parent, child, unrelated]
        )

        XCTAssertEqual(candidates.map(\.id), [unrelated.id])
    }

    func testEmotionTagsNormalizeAndKeepCustomValues() {
        XCTAssertEqual(
            TheaterEmotionTags.names(from: "感動、 泣いた,感動\n余韻がすごい"),
            ["感動", "泣いた", "余韻がすごい"]
        )
    }
}
