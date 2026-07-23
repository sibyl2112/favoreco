import XCTest
@testable import favoreco

@MainActor
final class PersonMasterSuggestionTests: XCTestCase {
    func testSuggestionsMatchDisplayNameReadingAndAliases() {
        let person = PersonMaster(
            displayName: "神崎 透",
            reading: "かんざき とおる",
            aliasesRaw: "トオル, 透くん"
        )

        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "神崎").map(\.id), [person.id])
        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "かんざき").map(\.id), [person.id])
        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "トオル").map(\.id), [person.id])
        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "透 くん").map(\.id), [person.id])
    }

    func testSuggestionsIgnoreWidthAndWhitespaceDifferences() {
        let person = PersonMaster(displayName: "ＡＢＣ 劇団", reading: "えーびーしーげきだん")

        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "abc劇団").map(\.id), [person.id])
        XCTAssertEqual(PersonMasterSuggestion.matching([person], query: "ＡＢＣ\n\t劇団").map(\.id), [person.id])
    }

    func testSuggestionsExcludeArchivedPeopleAndRespectPersonOnlyInput() {
        let archived = PersonMaster(displayName: "山田 花子", isArchived: true)
        let organization = PersonMaster(displayName: "山田劇団", entityKindKey: PersonEntityKind.organization.rawValue)
        let person = PersonMaster(displayName: "山田 太郎", entityKindKey: PersonEntityKind.person.rawValue)

        XCTAssertEqual(
            PersonMasterSuggestion.matching(
                [archived, organization, person],
                query: "山田",
                allowsOrganizations: false
            ).map(\.id),
            [person.id]
        )
    }

    func testExactReadingOrAliasFindsExistingMasterForReuse() {
        let person = PersonMaster(
            displayName: "神崎 透",
            reading: "かんざきとおる",
            aliasesRaw: "トオル"
        )

        XCTAssertEqual(
            PersonMasterSuggestion.exactMatch(in: [person], query: "かんざき とおる")?.id,
            person.id
        )
        XCTAssertEqual(
            PersonMasterSuggestion.exactMatch(in: [person], query: "トオル")?.id,
            person.id
        )
    }

    func testExactMatchDoesNotReuseOrganizationAsPerson() {
        let organization = PersonMaster(
            displayName: "ひかり",
            entityKindKey: PersonEntityKind.organization.rawValue
        )
        let person = PersonMaster(
            displayName: "ひかり",
            entityKindKey: PersonEntityKind.person.rawValue
        )

        XCTAssertEqual(
            PersonMasterSuggestion.exactMatch(
                in: [organization, person],
                query: "ひかり",
                entityKind: .person
            )?.id,
            person.id
        )
    }
}
