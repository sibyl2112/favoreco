import SwiftData
import XCTest
@testable import favoreco

@MainActor
final class PersonRegistrationBoundaryTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    func testTheaterPersonMasterAndFavoEntrancesReuseOnePersonProfileAndPin() throws {
        let context = try makeContext()
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(title: "月影のアトリエ", category: category)
        let visit = Visit(event: event)
        let person = PersonMaster(
            displayName: "神崎 透",
            entityKindKey: PersonEntityKind.person.rawValue,
            reading: "かんざき とおる",
            aliasesRaw: "トオル",
            normalizedName: "神崎透"
        )
        context.insert(category)
        context.insert(event)
        context.insert(visit)
        context.insert(person)
        try context.save()

        let pending = PendingPersonLink(
            name: "トオル",
            role: .theaterFocus,
            entityKind: .person,
            relationshipTagKeys: ["target", "precious"]
        )
        let resolved = resolvePersonMaster(
            for: pending,
            from: try context.fetch(FetchDescriptor<PersonMaster>()),
            in: context
        )
        let focusLink = pending.makeEventPersonLink(
            person: resolved,
            event: nil,
            visit: visit,
            sortOrder: 0
        )
        context.insert(focusLink)
        try context.save()

        XCTAssertEqual(resolved.id, person.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonMaster>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 0)
        XCTAssertEqual(
            TheaterFocusLinkMetadata(memo: focusLink.memo).reactionKeys,
            ["target", "precious"]
        )

        let profileFromPersonMaster = FavoriteProfile(
            isFavorite: true,
            nickname: "トオルさん",
            person: person
        )
        context.insert(profileFromPersonMaster)
        person.favoriteProfile = profileFromPersonMaster
        try context.save()

        let firstFavoRegistration = try PersonFavoRegistrationService.ensureRegistered(
            person: person,
            preferredSortOrder: 0,
            in: context,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let secondFavoRegistration = try PersonFavoRegistrationService.ensureRegistered(
            person: person,
            preferredSortOrder: 0,
            in: context,
            now: Date(timeIntervalSince1970: 1_800_000_100)
        )

        XCTAssertEqual(firstFavoRegistration.profile.id, profileFromPersonMaster.id)
        XCTAssertFalse(firstFavoRegistration.createdProfile)
        XCTAssertTrue(firstFavoRegistration.createdPin)
        XCTAssertEqual(secondFavoRegistration.profile.id, profileFromPersonMaster.id)
        XCTAssertEqual(secondFavoRegistration.pin.id, firstFavoRegistration.pin.id)
        XCTAssertFalse(secondFavoRegistration.createdProfile)
        XCTAssertFalse(secondFavoRegistration.createdPin)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonMaster>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 1)

        let restoredPerson = try XCTUnwrap(
            try context.fetch(FetchDescriptor<PersonMaster>()).first
        )
        XCTAssertEqual(restoredPerson.favoriteProfile?.id, profileFromPersonMaster.id)
        XCTAssertEqual(
            Set(restoredPerson.favoPins?.map(\.id) ?? []),
            Set([firstFavoRegistration.pin.id])
        )
        XCTAssertEqual(focusLink.person?.id, restoredPerson.id)
        XCTAssertEqual(focusLink.visit?.id, visit.id)
    }

    func testFullFavoDoesNotLeavePartialProfileForUnpinnedPerson() throws {
        let context = try makeContext()
        for index in 0..<4 {
            let person = PersonMaster(
                displayName: "登録済み\(index)",
                entityKindKey: PersonEntityKind.person.rawValue,
                normalizedName: "登録済み\(index)"
            )
            let pin = FavoPin(
                targetKindKey: FavoTargetKind.person.rawValue,
                sortOrder: index,
                person: person
            )
            context.insert(person)
            context.insert(pin)
        }
        let candidate = PersonMaster(
            displayName: "追加候補",
            entityKindKey: PersonEntityKind.person.rawValue,
            normalizedName: "追加候補"
        )
        context.insert(candidate)
        try context.save()

        XCTAssertThrowsError(
            try PersonFavoRegistrationService.ensureRegistered(
                person: candidate,
                preferredSortOrder: 0,
                in: context
            )
        ) { error in
            guard case PersonFavoRegistrationError.pinLimitReached = error else {
                return XCTFail("想定外のエラー: \(error)")
            }
        }

        XCTAssertNil(candidate.favoriteProfile)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 4)
        XCTAssertFalse(context.hasChanges)
    }

    func testExistingPinAtFullCapacityReusesPinAndCreatesOnlyMissingProfile() throws {
        let context = try makeContext()
        var target: PersonMaster?
        for index in 0..<4 {
            let person = PersonMaster(
                displayName: "登録済み\(index)",
                entityKindKey: PersonEntityKind.person.rawValue,
                normalizedName: "登録済み\(index)"
            )
            let pin = FavoPin(
                targetKindKey: FavoTargetKind.person.rawValue,
                sortOrder: index,
                person: person
            )
            context.insert(person)
            context.insert(pin)
            if index == 2 {
                target = person
            }
        }
        try context.save()

        let person = try XCTUnwrap(target)
        let existingPinID = try XCTUnwrap(person.favoPins?.first?.id)
        let result = try PersonFavoRegistrationService.ensureRegistered(
            person: person,
            preferredSortOrder: 0,
            in: context
        )

        XCTAssertEqual(result.pin.id, existingPinID)
        XCTAssertTrue(result.createdProfile)
        XCTAssertFalse(result.createdPin)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 4)
    }

    func testPersonFocusRelationshipAndFavoSurvivePersistentStoreReopen() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("favoreco-person-restart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appendingPathComponent("boundary.store")

        let personID = UUID()
        let visitID = UUID()
        let linkID = UUID()
        let profileID: UUID
        let pinID: UUID

        do {
            let container = try makePersistentContainer(storeURL: storeURL)
            let context = container.mainContext
            let category = RecordCategory(name: "観劇", templateKey: "theater")
            let event = ExperienceEvent(title: "再起動公演", category: category)
            let visit = Visit(id: visitID, event: event)
            let person = PersonMaster(
                id: personID,
                displayName: "神崎 透",
                entityKindKey: PersonEntityKind.person.rawValue,
                reading: "かんざき とおる",
                normalizedName: "神崎透"
            )
            let link = EventPersonLink(
                id: linkID,
                roleKey: TheaterFocusPersonAnalytics.roleKey,
                displayRole: "お目当て・注目",
                nameSnapshot: person.displayName,
                memo: TheaterFocusLinkMetadata(
                    reactionKeys: ["target", "precious"]
                ).encodedMemo,
                person: person,
                visit: visit
            )
            context.insert(category)
            context.insert(event)
            context.insert(visit)
            context.insert(person)
            context.insert(link)
            try context.save()

            let registration = try PersonFavoRegistrationService.ensureRegistered(
                person: person,
                preferredSortOrder: 0,
                in: context
            )
            profileID = registration.profile.id
            pinID = registration.pin.id
        }

        do {
            let reopenedContainer = try makePersistentContainer(storeURL: storeURL)
            let context = reopenedContainer.mainContext
            let people = try context.fetch(FetchDescriptor<PersonMaster>())
            let visits = try context.fetch(FetchDescriptor<Visit>())
            let links = try context.fetch(FetchDescriptor<EventPersonLink>())
            let profiles = try context.fetch(FetchDescriptor<FavoriteProfile>())
            let pins = try context.fetch(FetchDescriptor<FavoPin>())

            let person = try XCTUnwrap(people.first { $0.id == personID })
            let visit = try XCTUnwrap(visits.first { $0.id == visitID })
            let link = try XCTUnwrap(links.first { $0.id == linkID })
            XCTAssertEqual(person.favoriteProfile?.id, profileID)
            XCTAssertEqual(Set(person.favoPins?.map(\.id) ?? []), Set([pinID]))
            XCTAssertEqual(link.person?.id, personID)
            XCTAssertEqual(link.visit?.id, visitID)
            XCTAssertEqual(
                TheaterFocusLinkMetadata(memo: link.memo).reactionKeys,
                ["target", "precious"]
            )
            XCTAssertEqual(Set(visit.personLinks?.map(\.id) ?? []), Set([linkID]))
            XCTAssertEqual(profiles.map(\.id), [profileID])
            XCTAssertEqual(pins.map(\.id), [pinID])
        }
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: FavorecoModelContainerBootstrap.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
        retainedContainers.append(container)
        return container.mainContext
    }

    private func makePersistentContainer(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "PersonRegistrationBoundary",
            schema: FavorecoModelContainerBootstrap.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
    }
}
