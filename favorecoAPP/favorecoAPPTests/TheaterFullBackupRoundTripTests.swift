import SwiftData
import XCTest
@testable import favoreco

@MainActor
final class TheaterFullBackupRoundTripTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    func testCompleteTheaterRecordSurvivesFullBackupRoundTrip() throws {
        let fixture = makeFixture()
        let packageURL = try makePackage(for: fixture)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let preview = try FullBackupService.inspect(packageURL: packageURL)
        XCTAssertEqual(preview.jsonPreview.schemaVersion, JSONBackupExportService.schemaVersion)
        XCTAssertEqual(preview.jsonPreview.eventCount, 1)
        XCTAssertEqual(preview.jsonPreview.visitCount, 1)
        XCTAssertEqual(preview.availablePhotoCount, 3)

        let context = try makeContext()
        let result = try FullBackupService.restore(packageURL: packageURL, in: context)

        XCTAssertEqual(result.insertedPhotoCount, 3)
        XCTAssertEqual(result.updatedPhotoCount, 0)
        XCTAssertEqual(result.missingPhotoCount, 0)
        XCTAssertEqual(result.modelResult.clearedDeviceReferenceCount, 3)

        let restoredEvent = try fetch(
            ExperienceEvent.self,
            id: fixture.event.id,
            keyPath: \.id,
            in: context
        )
        XCTAssertEqual(restoredEvent.category?.id, fixture.category.id)
        XCTAssertEqual(restoredEvent.title, "月影のアトリエ")
        XCTAssertEqual(restoredEvent.seriesName, "月影シリーズ")
        XCTAssertEqual(restoredEvent.subTypeKey, "musical")
        XCTAssertEqual(restoredEvent.organizerNameSnapshot, "星空歌劇団")
        XCTAssertEqual(restoredEvent.officialURL, "https://example.com/moonlight")
        XCTAssertEqual(restoredEvent.memo, "公演全体のあらすじ")
        XCTAssertEqual(restoredEvent.eyecatchData, fixture.event.eyecatchData)

        let eventFields = VisitUnitFields(rawValue: restoredEvent.unitFieldsRaw)
        XCTAssertEqual(eventFields.eventSubtitle, "2026年夏公演")
        XCTAssertEqual(eventFields.eventCreditsText, "出演：神崎 透\n演出：朝倉 澪")
        XCTAssertEqual(eventFields.socialLinks, ["https://x.com/moonlight"])
        XCTAssertEqual(eventFields.eventPeriodStartsAt, fixture.eventPeriodStartsAt)
        XCTAssertEqual(eventFields.eventPeriodEndsAt, fixture.eventPeriodEndsAt)
        XCTAssertEqual(eventFields.eventVenues, fixture.eventVenues)

        let restoredVisit = try fetch(Visit.self, id: fixture.visit.id, keyPath: \.id, in: context)
        XCTAssertEqual(restoredVisit.event?.id, fixture.event.id)
        XCTAssertEqual(restoredVisit.placeMaster?.id, fixture.place.id)
        XCTAssertEqual(restoredVisit.visitedAt, fixture.visit.visitedAt)
        XCTAssertEqual(restoredVisit.endedAt, fixture.visit.endedAt)
        XCTAssertEqual(restoredVisit.venueNameSnapshot, "銀河劇場")
        XCTAssertEqual(restoredVisit.overallRating, 4.5)
        XCTAssertEqual(restoredVisit.seatText, "1階 10列 12番")
        XCTAssertEqual(restoredVisit.note, "第二幕の照明と歌が特に印象的だった。")
        XCTAssertEqual(restoredVisit.tagNamesRaw, "感動,胸が熱くなった")
        XCTAssertEqual(restoredVisit.companionNamesRaw, "友人A")
        XCTAssertEqual(restoredVisit.amount, Decimal(1_500))
        XCTAssertEqual(restoredVisit.latitude, 35.6762)
        XCTAssertEqual(restoredVisit.longitude, 139.6503)
        let visitFields = VisitUnitFields(rawValue: restoredVisit.unitFieldsRaw)
        XCTAssertEqual(visitFields.styleNames, ["現地", "イマーシブ演劇"])
        XCTAssertEqual(visitFields.ocrText, "2026年8月10日 13:00開演")
        XCTAssertEqual(visitFields.weatherSymbolName, "sun.max.fill")

        let restoredPeople = try context.fetch(FetchDescriptor<PersonMaster>())
        XCTAssertEqual(restoredPeople.count, 3)
        let restoredParent = try XCTUnwrap(restoredPeople.first { $0.id == fixture.parentOrganization.id })
        let restoredOrganization = try XCTUnwrap(restoredPeople.first { $0.id == fixture.organization.id })
        let restoredFocusPerson = try XCTUnwrap(restoredPeople.first { $0.id == fixture.focusPerson.id })
        XCTAssertTrue(restoredParent.isOrganization)
        XCTAssertTrue(restoredOrganization.isOrganization)
        XCTAssertEqual(restoredOrganization.parentOrganizationID, restoredParent.id)
        XCTAssertEqual(restoredFocusPerson.reading, "かんざき とおる")

        let restoredLinks = try context.fetch(FetchDescriptor<EventPersonLink>())
        XCTAssertEqual(restoredLinks.count, 2)
        let organizationLink = try XCTUnwrap(restoredLinks.first { $0.id == fixture.organizationLink.id })
        XCTAssertEqual(organizationLink.event?.id, fixture.event.id)
        XCTAssertNil(organizationLink.visit)
        XCTAssertEqual(organizationLink.person?.id, fixture.organization.id)
        let focusLink = try XCTUnwrap(restoredLinks.first { $0.id == fixture.focusLink.id })
        XCTAssertEqual(focusLink.visit?.id, fixture.visit.id)
        XCTAssertNil(focusLink.event)
        XCTAssertEqual(focusLink.person?.id, fixture.focusPerson.id)
        XCTAssertEqual(
            TheaterFocusLinkMetadata(memo: focusLink.memo).reactionKeys,
            ["target", "moved", "precious"]
        )

        let restoredPlan = try fetch(Plan.self, id: fixture.plan.id, keyPath: \.id, in: context)
        XCTAssertEqual(restoredPlan.category?.id, fixture.category.id)
        XCTAssertEqual(restoredPlan.event?.id, fixture.event.id)
        XCTAssertEqual(restoredPlan.visit?.id, fixture.visit.id)
        XCTAssertEqual(restoredPlan.placeMaster?.id, fixture.place.id)
        XCTAssertEqual(restoredPlan.stateKey, "attended")
        XCTAssertEqual(restoredPlan.externalCalendarEventIdentifier, "")
        let preparation = restoredPlan.preparationFields
        XCTAssertEqual(preparation.checklistMode, .enabled)
        XCTAssertEqual(preparation.tasks.count, 2)
        XCTAssertEqual(preparation.tasks[0].kind, .hotel)
        XCTAssertEqual(preparation.tasks[0].amount, Decimal(18_000))
        XCTAssertEqual(preparation.tasks[0].ocrText, "ホテル予約確認番号 ABC123")
        XCTAssertEqual(preparation.tasks[1].kind, .shinkansen)
        XCTAssertTrue(preparation.tasks[1].isCompleted)

        let restoredAttempt = try fetch(
            TicketAttempt.self,
            id: fixture.ticketAttempt.id,
            keyPath: \.id,
            in: context
        )
        XCTAssertEqual(restoredAttempt.plan?.id, fixture.plan.id)
        XCTAssertEqual(restoredAttempt.account?.id, fixture.ticketAccount.id)
        XCTAssertEqual(restoredAttempt.statusKey, "issued")
        XCTAssertEqual(restoredAttempt.entryRouteKey, "fanClub")
        XCTAssertEqual(restoredAttempt.price, Decimal(13_500))
        XCTAssertEqual(restoredAttempt.fee, Decimal(880))
        XCTAssertEqual(restoredAttempt.quantity, 1)
        XCTAssertEqual(restoredAttempt.seatText, "S席 1階10列12番")
        XCTAssertEqual(
            TicketAttemptUnitFields(rawValue: restoredAttempt.unitFieldsRaw).tagNames,
            ["FC先行", "第1希望"]
        )
        XCTAssertEqual(restoredAttempt.notificationSettingsRaw, "")
        let restoredAccount = try fetch(
            TicketAccount.self,
            id: fixture.ticketAccount.id,
            keyPath: \.id,
            in: context
        )
        XCTAssertEqual(restoredAccount.serviceName, "星空歌劇団FC")
        XCTAssertEqual(restoredAccount.keychainPasswordRef, "")

        let restoredPhotos = try context.fetch(FetchDescriptor<PhotoBlob>())
            .sorted { $0.purpose < $1.purpose }
        XCTAssertEqual(restoredPhotos.count, 3)
        XCTAssertEqual(Set(restoredPhotos.map(\.visit?.id)), Set([Optional(fixture.visit.id)]))
        XCTAssertEqual(Set(restoredPhotos.map(\.purpose)), ["goods", "memory", "ticket"])
        XCTAssertEqual(restoredPhotos.first(where: { $0.purpose == "memory" })?.data, Data([0x01, 0x02]))
        XCTAssertEqual(restoredPhotos.first(where: { $0.purpose == "ticket" })?.ocrText, "S席 13,500円")
        XCTAssertEqual(restoredPhotos.first(where: { $0.purpose == "ticket" })?.amount, Decimal(13_500))
        XCTAssertEqual(restoredPhotos.first(where: { $0.purpose == "goods" })?.amount, Decimal(3_200))

        let restoredCompanion = try fetch(
            CompanionMaster.self,
            id: fixture.companion.id,
            keyPath: \.id,
            in: context
        )
        XCTAssertEqual(restoredCompanion.name, "友人A")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 0)
    }

    func testRestoringSameFullBackupTwiceDoesNotDuplicateTheaterData() throws {
        let fixture = makeFixture()
        let packageURL = try makePackage(for: fixture)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = try makeContext()
        let firstResult = try FullBackupService.restore(packageURL: packageURL, in: context)
        let secondResult = try FullBackupService.restore(packageURL: packageURL, in: context)

        XCTAssertEqual(firstResult.insertedPhotoCount, 3)
        XCTAssertEqual(firstResult.updatedPhotoCount, 0)
        XCTAssertEqual(secondResult.insertedPhotoCount, 0)
        XCTAssertEqual(secondResult.updatedPhotoCount, 3)
        XCTAssertEqual(secondResult.missingPhotoCount, 0)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonMaster>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EventPersonLink>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompanionMaster>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlaceMaster>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TicketAccount>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TicketAttempt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoriteProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoPin>()), 0)

        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let people = try context.fetch(FetchDescriptor<PersonMaster>())
        let links = try context.fetch(FetchDescriptor<EventPersonLink>())
        let photos = try context.fetch(FetchDescriptor<PhotoBlob>())
        XCTAssertEqual(Set(events.map(\.id)), Set([fixture.event.id]))
        XCTAssertEqual(Set(visits.map(\.id)), Set([fixture.visit.id]))
        XCTAssertEqual(Set(people.map(\.id)), Set(fixture.people.map(\.id)))
        XCTAssertEqual(Set(links.map(\.id)), Set(fixture.personLinks.map(\.id)))
        XCTAssertEqual(Set(photos.map(\.id)), Set(fixture.photos.map(\.id)))
        XCTAssertEqual(Set(photos.map(\.visit?.id)), Set([Optional(fixture.visit.id)]))
        XCTAssertEqual(
            photos.first(where: { $0.id == fixture.photos[0].id })?.data,
            fixture.photos[0].data
        )
    }

    func testRestoreRemainsIdempotentAfterPersistentStoreReopen() throws {
        let fixture = makeFixture()
        let packageURL = try makePackage(for: fixture)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("favoreco-backup-restart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appendingPathComponent("backup.store")

        do {
            let container = try makePersistentContainer(storeURL: storeURL)
            let result = try FullBackupService.restore(
                packageURL: packageURL,
                in: container.mainContext
            )
            XCTAssertEqual(result.insertedPhotoCount, 3)
            XCTAssertEqual(result.updatedPhotoCount, 0)
        }

        do {
            let reopenedContainer = try makePersistentContainer(storeURL: storeURL)
            let context = reopenedContainer.mainContext
            let result = try FullBackupService.restore(packageURL: packageURL, in: context)

            XCTAssertEqual(result.insertedPhotoCount, 0)
            XCTAssertEqual(result.updatedPhotoCount, 3)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordCategory>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonMaster>()), 3)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<EventPersonLink>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<TicketAttempt>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 3)

            let event = try fetch(
                ExperienceEvent.self,
                id: fixture.event.id,
                keyPath: \.id,
                in: context
            )
            let visit = try fetch(Visit.self, id: fixture.visit.id, keyPath: \.id, in: context)
            let photos = try context.fetch(FetchDescriptor<PhotoBlob>())
            XCTAssertEqual(event.category?.id, fixture.category.id)
            XCTAssertEqual(visit.event?.id, event.id)
            XCTAssertEqual(Set(photos.map(\.id)), Set(fixture.photos.map(\.id)))
            XCTAssertEqual(Set(photos.map(\.visit?.id)), Set([Optional(visit.id)]))
            XCTAssertEqual(
                photos.first(where: { $0.id == fixture.photos[0].id })?.data,
                fixture.photos[0].data
            )
        }
    }

    private func makePackage(for fixture: Fixture) throws -> URL {
        let json = try JSONBackupExportService.makeBackupJSON(
            categories: [fixture.category],
            events: [fixture.event],
            visits: [fixture.visit],
            inboxItems: [],
            photos: fixture.photos,
            socialAccounts: [],
            people: fixture.people,
            companions: [fixture.companion],
            favoriteProfiles: [],
            favoGalleryPhotos: [],
            favoAnniversaries: [],
            favoPins: [],
            personLinks: fixture.personLinks,
            places: [fixture.place],
            plans: [fixture.plan],
            ticketAccounts: [fixture.ticketAccount],
            ticketAttempts: [fixture.ticketAttempt],
            isFullBackupManifest: true
        )
        return try FullBackupService.makePackage(json: json, photos: fixture.photos)
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
            "TheaterBackupRestart",
            schema: FavorecoModelContainerBootstrap.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: FavorecoModelContainerBootstrap.schema,
            configurations: [configuration]
        )
    }

    private func fetch<Model: PersistentModel>(
        _ type: Model.Type,
        id: UUID,
        keyPath: KeyPath<Model, UUID>,
        in context: ModelContext
    ) throws -> Model {
        let models = try context.fetch(FetchDescriptor<Model>())
        return try XCTUnwrap(models.first { $0[keyPath: keyPath] == id })
    }

    private func makeFixture() -> Fixture {
        let createdAt = date(1_740_000_000)
        let eventPeriodStartsAt = date(1_775_174_400)
        let eventPeriodEndsAt = date(1_777_939_200)
        let venueOne = EventVenueEntry(
            id: UUID(),
            name: "銀河劇場",
            address: "東京都港区1-2-3",
            performanceLabel: "東京公演",
            startsAt: date(1_775_174_400),
            endsAt: date(1_776_038_400)
        )
        let venueTwo = EventVenueEntry(
            id: UUID(),
            name: "星雲ホール",
            address: "大阪府大阪市4-5-6",
            performanceLabel: "大阪公演",
            startsAt: date(1_777_075_200),
            endsAt: date(1_777_939_200)
        )
        let eventVenues = [venueOne, venueTwo]
        let category = RecordCategory(
            name: "観劇",
            iconSymbol: "theatermasks.fill",
            colorHex: "#8B2F45",
            sortOrder: 10,
            isBuiltIn: true,
            templateKey: "theater",
            enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,money,officialInfo,memo",
            templateTypeKey: "experience",
            targetNameLabel: "公演",
            recordUnitName: "観劇",
            dateLabel: "観劇日",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let eventFields = VisitUnitFields(
            socialLinks: ["https://x.com/moonlight"],
            eventSubtitle: "2026年夏公演",
            eventCreditsText: "出演：神崎 透\n演出：朝倉 澪",
            eventPeriodStartsAt: eventPeriodStartsAt,
            eventPeriodEndsAt: eventPeriodEndsAt,
            eventVenues: eventVenues,
            eyecatchAspectRatioKey: "b_poster",
            heroBackgroundPresetKey: "theater-night-train"
        )
        let event = ExperienceEvent(
            title: "月影のアトリエ",
            seriesName: "月影シリーズ",
            subTypeKey: "musical",
            organizerNameSnapshot: "星空歌劇団",
            officialURL: "https://example.com/moonlight",
            memo: "公演全体のあらすじ",
            importMemo: "公式サイトから確認",
            unitFieldsRaw: eventFields.encodedRawValue,
            createdAt: createdAt,
            updatedAt: date(1_750_000_000),
            eyecatchData: Data([0x10, 0x20, 0x30]),
            category: category
        )
        let place = PlaceMaster(
            name: "銀河劇場",
            reading: "ぎんがげきじょう",
            placeTagsRaw: "劇場",
            prefecture: "東京都",
            address: "東京都港区1-2-3",
            latitude: 35.6762,
            longitude: 139.6503,
            officialURL: "https://example.com/ginga",
            normalizedName: "銀河劇場",
            normalizedAddress: "東京都港区1-2-3",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let visitFields = VisitUnitFields(
            ocrText: "2026年8月10日 13:00開演",
            styleNames: ["現地", "イマーシブ演劇"],
            weatherSymbolName: "sun.max.fill",
            weatherHighCelsius: 31,
            weatherLowCelsius: 25,
            weatherFetchedAt: date(1_776_000_000)
        )
        let visit = Visit(
            visitedAt: date(1_786_345_200),
            endedAt: date(1_786_352_400),
            venueNameSnapshot: "銀河劇場",
            overallRating: 4.5,
            outcomeKey: "attended",
            seatText: "1階 10列 12番",
            note: "第二幕の照明と歌が特に印象的だった。",
            tagNamesRaw: "感動,胸が熱くなった",
            companionNamesRaw: "友人A",
            amount: Decimal(1_500),
            latitude: 35.6762,
            longitude: 139.6503,
            unitFieldsRaw: visitFields.encodedRawValue,
            createdAt: createdAt,
            updatedAt: date(1_786_352_500),
            event: event,
            placeMaster: place
        )
        let parentOrganization = PersonMaster(
            displayName: "星空歌劇団",
            entityKindKey: PersonEntityKind.organization.rawValue,
            roleTagsRaw: "theater_company",
            normalizedName: "星空歌劇団",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let organization = PersonMaster(
            displayName: "宙組",
            entityKindKey: PersonEntityKind.organization.rawValue,
            parentOrganizationIDRaw: parentOrganization.id.uuidString,
            roleTagsRaw: "theater_company",
            normalizedName: "宙組",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let focusPerson = PersonMaster(
            displayName: "神崎 透",
            entityKindKey: PersonEntityKind.person.rawValue,
            reading: "かんざき とおる",
            aliasesRaw: "トオル",
            normalizedName: "神崎透",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let organizationLink = EventPersonLink(
            roleKey: "performing_organization",
            displayRole: "上演団体",
            sortOrder: 0,
            nameSnapshot: "宙組",
            createdAt: createdAt,
            updatedAt: createdAt,
            person: organization,
            event: event
        )
        let focusLink = EventPersonLink(
            roleKey: TheaterFocusPersonAnalytics.roleKey,
            displayRole: "お目当て・注目",
            sortOrder: 0,
            nameSnapshot: "神崎 透",
            memo: TheaterFocusLinkMetadata(
                reactionKeys: ["target", "moved", "precious"]
            ).encodedMemo,
            createdAt: createdAt,
            updatedAt: createdAt,
            person: focusPerson,
            visit: visit
        )
        let companion = CompanionMaster(
            name: "友人A",
            normalizedName: "友人a",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let preparation = PlanPreparationFields(
            checklistModeKey: PlanPreparationFields.ChecklistMode.enabled.rawValue,
            tasks: [
                PlanPreparationTask(
                    title: "ホテルを予約",
                    kindKey: PlanPreparationKind.hotel.rawValue,
                    startsAt: date(1_786_276_800),
                    endsAt: date(1_786_363_200),
                    amount: Decimal(18_000),
                    ocrText: "ホテル予約確認番号 ABC123",
                    sortOrder: 0,
                    createdAt: createdAt,
                    updatedAt: createdAt
                ),
                PlanPreparationTask(
                    title: "新幹線を予約",
                    kindKey: PlanPreparationKind.shinkansen.rawValue,
                    amount: Decimal(14_720),
                    isCompleted: true,
                    sortOrder: 1,
                    createdAt: createdAt,
                    updatedAt: date(1_785_000_000),
                    completedAt: date(1_785_000_000)
                ),
            ]
        )
        let plan = Plan(
            title: "月影のアトリエ",
            subtitle: "東京公演",
            planKindKey: "performance",
            stateKey: "attended",
            startsAt: visit.visitedAt,
            endsAt: visit.endedAt,
            opensAt: date(1_786_343_400),
            venueNameSnapshot: "銀河劇場",
            organizerNameSnapshot: "星空歌劇団",
            officialURL: event.officialURL,
            sourceURL: "https://tickets.example.com/moonlight",
            memo: "13時開演",
            notificationLeadTimeKey: "previousDay",
            externalCalendarEventIdentifier: "device-calendar-id",
            unitFieldsRaw: preparation.encodedRawValue,
            createdAt: createdAt,
            updatedAt: createdAt,
            category: category,
            event: event,
            placeMaster: place,
            visit: visit
        )
        let ticketAccount = TicketAccount(
            serviceName: "星空歌劇団FC",
            accountTypeKey: "fanClub",
            loginID: "member@example.com",
            memberNumber: "FC-1234",
            accountName: "本人名義",
            keychainPasswordRef: "device-keychain-ref",
            normalizedServiceName: "星空歌劇団fc",
            normalizedMemberNumber: "fc-1234",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let ticketAttempt = TicketAttempt(
            statusKey: "issued",
            entryRouteKey: "fanClub",
            ticketSite: "星空歌劇団FC",
            holderName: "本人名義",
            saleStartAt: date(1_780_000_000),
            applyDeadlineAt: date(1_780_086_400),
            resultAnnounceAt: date(1_780_691_200),
            paymentDeadlineAt: date(1_781_296_000),
            issueStartAt: date(1_785_600_000),
            paidAt: date(1_780_777_600),
            issuedAt: date(1_785_600_100),
            price: Decimal(13_500),
            fee: Decimal(880),
            quantity: 1,
            purchaseURL: "https://tickets.example.com/moonlight/order",
            seatText: "S席 1階10列12番",
            notificationSettingsRaw: #"{"paymentDeadline":"notification-id"}"#,
            unitFieldsRaw: TicketAttemptUnitFields(
                tagNames: ["FC先行", "第1希望"]
            ).encodedRawValue,
            memo: "紙チケット",
            createdAt: createdAt,
            updatedAt: createdAt,
            plan: plan,
            account: ticketAccount
        )
        let memoryPhoto = PhotoBlob(
            originalFilename: "stage.jpg",
            purpose: "memory",
            byteCount: 2,
            width: 1200,
            height: 800,
            createdAt: createdAt,
            data: Data([0x01, 0x02]),
            visit: visit
        )
        let ticketPhoto = PhotoBlob(
            originalFilename: "ticket.jpg",
            purpose: "ticket",
            ocrText: "S席 13,500円",
            amount: Decimal(13_500),
            byteCount: 3,
            width: 900,
            height: 1_200,
            createdAt: createdAt,
            data: Data([0x03, 0x04, 0x05]),
            visit: visit
        )
        let goodsPhoto = PhotoBlob(
            originalFilename: "pamphlet.jpg",
            purpose: "goods",
            ocrText: "公演パンフレット 3,200円",
            amount: Decimal(3_200),
            byteCount: 2,
            width: 1_000,
            height: 1_000,
            createdAt: createdAt,
            data: Data([0x06, 0x07]),
            visit: visit
        )

        return Fixture(
            category: category,
            event: event,
            visit: visit,
            photos: [memoryPhoto, ticketPhoto, goodsPhoto],
            people: [parentOrganization, organization, focusPerson],
            parentOrganization: parentOrganization,
            organization: organization,
            focusPerson: focusPerson,
            personLinks: [organizationLink, focusLink],
            organizationLink: organizationLink,
            focusLink: focusLink,
            companion: companion,
            place: place,
            plan: plan,
            ticketAccount: ticketAccount,
            ticketAttempt: ticketAttempt,
            eventPeriodStartsAt: eventPeriodStartsAt,
            eventPeriodEndsAt: eventPeriodEndsAt,
            eventVenues: eventVenues
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}

private struct Fixture {
    let category: RecordCategory
    let event: ExperienceEvent
    let visit: Visit
    let photos: [PhotoBlob]
    let people: [PersonMaster]
    let parentOrganization: PersonMaster
    let organization: PersonMaster
    let focusPerson: PersonMaster
    let personLinks: [EventPersonLink]
    let organizationLink: EventPersonLink
    let focusLink: EventPersonLink
    let companion: CompanionMaster
    let place: PlaceMaster
    let plan: Plan
    let ticketAccount: TicketAccount
    let ticketAttempt: TicketAttempt
    let eventPeriodStartsAt: Date
    let eventPeriodEndsAt: Date
    let eventVenues: [EventVenueEntry]
}
