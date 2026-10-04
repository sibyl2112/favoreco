import SwiftData
import XCTest
@testable import favoreco

@MainActor
final class SampleDataSeederTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    func testRandomGoodsSamplesUseCollectibleModelsAndDeleteCleanly() throws {
        let context = try makeContext()
        let category = makeCategory(name: "ランダムグッズ", templateKey: "random_goods")
        let personalEvent = ExperienceEvent(
            title: "通常データ",
            officialURL: "https://example.org/personal",
            category: category
        )
        context.insert(category)
        context.insert(personalEvent)
        try context.save()

        let inserted = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["random_goods"]
        )

        XCTAssertEqual(inserted.eventCount, 16)
        XCTAssertEqual(inserted.visitCount, 0)
        XCTAssertEqual(inserted.planCount, 0)
        XCTAssertEqual(inserted.interestCount, 3)
        XCTAssertEqual(inserted.catalogOnlyCount, 5)
        XCTAssertEqual(inserted.ticketAttemptCount, 0)

        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let samples = events.filter(SampleDataSeeder.isSampleEvent)
        XCTAssertEqual(samples.count, 16)
        XCTAssertTrue(samples.allSatisfy { ($0.visits ?? []).isEmpty })
        XCTAssertTrue(samples.allSatisfy { ($0.plans ?? []).isEmpty })

        let summaries = Dictionary(
            uniqueKeysWithValues: samples.map { ($0.title, CollectibleSeriesSummary.make(series: $0)) }
        )
        assertSummary(
            summaries["星空どうぶつカプセル"],
            target: 5,
            collected: 3,
            owned: 4,
            duplicates: 1,
            spent: 1_600
        )
        assertSummary(
            summaries["月影アクリルチャーム"],
            target: 6,
            collected: 3,
            owned: 4,
            duplicates: 1,
            spent: 3_500
        )
        assertSummary(
            summaries["花色缶バッジコレクション"],
            target: 4,
            collected: 4,
            owned: 4,
            duplicates: 0,
            spent: 2_000
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 26)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 18)

        let deleted = try SampleDataSeeder.deleteSamples(in: context)
        XCTAssertEqual(deleted.eventCount, 16)
        XCTAssertEqual(deleted.visitCount, 0)
        XCTAssertEqual(deleted.planCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 0)

        let remainingEvents = try context.fetch(FetchDescriptor<ExperienceEvent>())
        XCTAssertEqual(remainingEvents.map(\.id), [personalEvent.id])
    }

    func testStandardCategoryCreatesCurrentFourStageDataset() throws {
        let context = try makeContext()
        let category = makeCategory(name: "映画", templateKey: "movie")
        context.insert(category)
        try context.save()

        let inserted = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["movie"]
        )

        XCTAssertEqual(inserted.eventCount, 16)
        XCTAssertEqual(inserted.visitCount, 5)
        XCTAssertEqual(inserted.planCount, 3)
        XCTAssertEqual(inserted.interestCount, 3)
        XCTAssertEqual(inserted.catalogOnlyCount, 5)
        XCTAssertEqual(inserted.ticketAttemptCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 5)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 5)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 0)

        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        XCTAssertEqual(events.filter { $0.stateKey == "interested" }.count, 3)
        XCTAssertEqual(events.filter {
            $0.stateKey == "active" && ($0.visits ?? []).isEmpty && ($0.plans ?? []).isEmpty
        }.count, 5)
        XCTAssertEqual(Set(events.map(\.screenWorkType)), Set(ScreenWorkType.allCases))
        XCTAssertEqual(
            Set(events.map(\.screenWorkSeasonNumber)),
            Set([0, 1, 2])
        )
        XCTAssertTrue(events.allSatisfy { $0.eyecatchData?.isEmpty == false })
        let displayFields = events.map { VisitUnitFields(rawValue: $0.unitFieldsRaw) }
        XCTAssertTrue(displayFields.allSatisfy { !$0.venueAddressSnapshot.isEmpty })
        XCTAssertTrue(displayFields.allSatisfy { !$0.screenWorkOriginalTitle.isEmpty })
        XCTAssertTrue(displayFields.allSatisfy { !$0.screenWorkOverview.isEmpty })
        XCTAssertTrue(displayFields.allSatisfy { !$0.socialLinks.isEmpty })
    }

    func testBookSamplesCoverReadingStatesAndGenreShelves() throws {
        let context = try makeContext()
        let category = makeCategory(name: "書籍", templateKey: "book")
        context.insert(category)
        try context.save()

        let inserted = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["book"]
        )

        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
            .filter(SampleDataSeeder.isSampleEvent)
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let shelves = try context.fetch(FetchDescriptor<BookShelf>())
        let readCount = visits.filter {
            VisitUnitFields(rawValue: $0.unitFieldsRaw).bookReadingHasEndDate == true
        }.count
        let readingCount = visits.filter {
            VisitUnitFields(rawValue: $0.unitFieldsRaw).bookReadingHasEndDate == false
        }.count
        let interestedCount = events.filter { $0.stateKey == "interested" }.count
        let toReadCount = events.filter {
            $0.stateKey == "active" && ($0.visits ?? []).isEmpty
        }.count

        XCTAssertEqual(inserted.eventCount, 24)
        XCTAssertEqual(inserted.visitCount, 12)
        XCTAssertEqual(inserted.planCount, 0)
        XCTAssertEqual(inserted.interestCount, 4)
        XCTAssertEqual(inserted.catalogOnlyCount, 8)
        XCTAssertEqual(readCount, 8)
        XCTAssertEqual(readingCount, 4)
        XCTAssertEqual(interestedCount, 4)
        XCTAssertEqual(toReadCount, 8)
        XCTAssertEqual(
            shelves.sorted { $0.sortOrder < $1.sortOrder }.map(\.name),
            ["小説", "エッセイ・詩", "漫画", "仕事・学び"]
        )
        XCTAssertTrue(shelves.allSatisfy { ($0.books ?? []).count >= 4 })
        XCTAssertEqual(events.filter { ($0.bookShelves ?? []).count > 1 }.count, 2)
        XCTAssertTrue(events.contains { !$0.bookSeriesName.isEmpty })
        XCTAssertTrue(events.contains { $0.bookSeriesName.isEmpty })
        XCTAssertTrue(events.allSatisfy { event in
            (event.personLinks ?? []).contains { $0.nameSnapshot == event.bookAuthorName }
        })

        _ = try SampleDataSeeder.deleteSamples(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BookShelf>()), 0)
    }

    func testExperienceResetPreservesCategoryPersonAndPlaceMasters() throws {
        let context = try makeContext()
        let category = makeCategory(name: "映画", templateKey: "movie")
        let person = PersonMaster(displayName: "保存する人物")
        let place = PlaceMaster(name: "保存する場所")
        let event = ExperienceEvent(title: "削除する作品", category: category)
        let visit = Visit(event: event, placeMaster: place)
        let plan = Plan(title: "削除する予定", category: category, event: event, placeMaster: place)
        context.insert(category)
        context.insert(person)
        context.insert(place)
        context.insert(event)
        context.insert(visit)
        context.insert(plan)
        try context.save()

        let result = try RecordDeletionService.deleteAllExperienceDataPreservingMasters(
            in: context
        )

        XCTAssertEqual(result.eventCount, 1)
        XCTAssertEqual(result.visitCount, 1)
        XCTAssertEqual(result.planCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecordCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonMaster>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlaceMaster>()), 1)
    }

    func testFirstUseResetKeepsOnlyStarterPeopleAndPublicCatalogPlaces() throws {
        let context = try makeContext()
        let customCategory = RecordCategory(
            name: "手入力ジャンル",
            iconSymbol: "star",
            colorHex: "#123456",
            sortOrder: 999,
            templateKey: "custom"
        )
        let starterPerson = PersonMaster(
            displayName: "初期人物",
            sourceSnapshotRaw: PersonStarterPresetSeeder.sourceMarker
        )
        let manualPerson = PersonMaster(displayName: "手入力人物")
        let publicPlace = PlaceMaster(
            name: "公開場所",
            sourceSnapshotRaw: PublicPlaceCatalogImporter.sourceMarker(for: "test-place")
        )
        let manualPlace = PlaceMaster(name: "手入力場所")
        let event = ExperienceEvent(title: "手入力作品", category: customCategory)
        let visit = Visit(event: event, placeMaster: manualPlace)
        let plan = Plan(title: "手入力予定", category: customCategory, event: event, placeMaster: publicPlace)
        context.insert(customCategory)
        context.insert(starterPerson)
        context.insert(manualPerson)
        context.insert(publicPlace)
        context.insert(manualPlace)
        context.insert(event)
        context.insert(visit)
        context.insert(plan)
        try context.save()

        let result = try RecordDeletionService.resetToFirstUseBaseData(in: context)

        XCTAssertGreaterThan(result.deletedExperienceCount, 0)
        XCTAssertGreaterThan(result.deletedMasterCount, 0)
        XCTAssertEqual(result.preservedPersonCount, 1)
        XCTAssertEqual(result.preservedPlaceCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PersonMaster>()).map(\.displayName), ["初期人物"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlaceMaster>()).map(\.name), ["公開場所"])

        let categories = try context.fetch(FetchDescriptor<RecordCategory>())
        XCTAssertEqual(categories.count, CategoryPresetSeeder.presets.count)
        XCTAssertTrue(categories.allSatisfy(\.isBuiltIn))
        XCTAssertFalse(categories.contains { $0.templateKey == "custom" })
    }

    func testTheaterAndLiveSamplesCoverCurrentTicketProgressAndTimelineDates() throws {
        let context = try makeContext()
        context.insert(makeCategory(name: "観劇", templateKey: "theater"))
        context.insert(makeCategory(name: "LIVE", templateKey: "live"))
        try context.save()

        let inserted = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["theater", "live"]
        )

        let attempts = try context.fetch(FetchDescriptor<TicketAttempt>())
        let statuses = Set(attempts.map(\.statusKey))
        XCTAssertEqual(inserted.ticketAttemptCount, 10)
        XCTAssertTrue([
            "beforeApply", "onSaleSoon", "waitingResult", "won", "lost",
            "waitingPayment", "waitingIssue", "issued"
        ].allSatisfy(statuses.contains))

        let now = Date()
        let calendar = Calendar.current
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        XCTAssertTrue(visits.contains { $0.visitedAt < now })
        XCTAssertTrue(plans.contains { $0.startsAt > now })
        XCTAssertTrue(visits.contains { calendar.isDate($0.visitedAt, inSameDayAs: now) })
        // Today is covered by completed records; ticketed plans must remain future.
        XCTAssertTrue(plans.allSatisfy { $0.startsAt > now })
        XCTAssertTrue(plans.contains { !$0.preparationFields.tasks.isEmpty })

        let liveVisit = try XCTUnwrap(visits.first { $0.event?.category?.templateKey == "live" })
        XCTAssertFalse(VisitUnitFields(rawValue: liveVisit.unitFieldsRaw).liveSetlistEntries.isEmpty)
    }

    func testAutomaticInsertionDoesNotCreateLargeDebugDataset() throws {
        SampleDataSeeder.resetAutomaticInsertionState()
        defer { SampleDataSeeder.resetAutomaticInsertionState() }

        let context = try makeContext()
        let category = makeCategory(name: "ランダムグッズ", templateKey: "random_goods")
        context.insert(category)
        try context.save()

        let first = try SampleDataSeeder.insertAutomaticSamples(
            in: context,
            categoryTemplateKeys: ["random_goods"]
        )
        let second = try SampleDataSeeder.insertAutomaticSamples(
            in: context,
            categoryTemplateKeys: ["random_goods"]
        )

        XCTAssertEqual(first.eventCount, 0)
        XCTAssertEqual(first.visitCount, 0)
        XCTAssertEqual(first.planCount, 0)
        XCTAssertEqual(second.eventCount, 0)
        XCTAssertEqual(second.visitCount, 0)
        XCTAssertEqual(second.planCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 0)
    }

    func testAutomaticInsertionDoesNotAddSamplesWhenPersonalDataExists() throws {
        SampleDataSeeder.resetAutomaticInsertionState()
        defer { SampleDataSeeder.resetAutomaticInsertionState() }

        let context = try makeContext()
        let category = makeCategory(name: "映画", templateKey: "movie")
        let personalEvent = ExperienceEvent(
            title: "利用者の映画",
            officialURL: "https://example.org/personal-movie",
            category: category
        )
        context.insert(category)
        context.insert(personalEvent)
        try context.save()

        let inserted = try SampleDataSeeder.insertAutomaticSamples(
            in: context,
            categoryTemplateKeys: ["movie"]
        )

        XCTAssertEqual(inserted.eventCount, 0)
        XCTAssertEqual(inserted.visitCount, 0)
        XCTAssertEqual(inserted.planCount, 0)
        XCTAssertEqual(inserted.ticketAttemptCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 0)
        XCTAssertFalse(SampleDataSeeder.isSampleEvent(personalEvent))
    }

    func testRefreshBundledTheaterEyecatchesRestoresBSeriesSampleOnly() throws {
        let context = try makeContext()
        let category = makeCategory(name: "観劇", templateKey: "theater")
        context.insert(category)
        try context.save()

        _ = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["theater"]
        )
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let sample = try XCTUnwrap(events.first { $0.title == "月影のアトリエ" })
        sample.eyecatchData = Data("old-cropped-sample".utf8)
        sample.representativeEyecatchPath = "old/path.jpg"
        var sampleFields = VisitUnitFields(rawValue: sample.unitFieldsRaw)
        sampleFields.eyecatchAspectRatioKey = EyecatchAspectRatio.square.key
        sample.unitFieldsRaw = sampleFields.encodedRawValue

        let personalData = Data("personal-image".utf8)
        let personalEvent = ExperienceEvent(
            title: "月影のアトリエ",
            officialURL: "https://example.org/personal-theater",
            unitFieldsRaw: VisitUnitFields(
                eyecatchAspectRatioKey: EyecatchAspectRatio.square.key
            ).encodedRawValue,
            eyecatchData: personalData,
            category: category
        )
        context.insert(personalEvent)
        try context.save()

        let refreshedCount = try SampleDataSeeder.refreshBundledTheaterSampleEyecatches(
            in: context
        )

        XCTAssertEqual(refreshedCount, 1)
        let refreshedImage = try XCTUnwrap(sample.eyecatchData.flatMap(UIImage.init(data:)))
        XCTAssertEqual(
            refreshedImage.size.width / refreshedImage.size.height,
            CGFloat(EyecatchAspectRatio.bSeriesPoster.value),
            accuracy: 0.01
        )
        XCTAssertEqual(sample.representativeEyecatchPath, "sample/v3/theater.jpg")
        XCTAssertEqual(
            VisitUnitFields(rawValue: sample.unitFieldsRaw).eyecatchAspectRatioKey,
            EyecatchAspectRatio.bSeriesPoster.key
        )
        XCTAssertEqual(personalEvent.eyecatchData, personalData)
        XCTAssertEqual(
            VisitUnitFields(rawValue: personalEvent.unitFieldsRaw).eyecatchAspectRatioKey,
            EyecatchAspectRatio.square.key
        )
    }

    func testRefreshAtNightAndYearEndKeepsSchedulesFutureAndPreservesPersonalData() throws {
        let context = try makeContext()
        let theater = makeCategory(name: "観劇", templateKey: "theater")
        let live = makeCategory(name: "LIVE", templateKey: "live")
        context.insert(theater)
        context.insert(live)
        let personal = ExperienceEvent(title: "通常データ", officialURL: "https://example.org/keep", category: theater)
        let personalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let visit = Visit(visitedAt: personalDate, note: "変更しない", event: personal)
        context.insert(personal)
        context.insert(visit)
        try context.save()
        let calendar = Calendar.current
        for components in [DateComponents(year: 2026, month: 9, day: 30, hour: 0, minute: 30),
                           DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59),
                           DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59)] {
            let now = try XCTUnwrap(calendar.date(from: components))
            _ = try SampleDataSeeder.replaceSamples(in: context, categoryTemplateKeys: ["theater", "live"], now: now)
            let plans = try context.fetch(FetchDescriptor<Plan>())
            XCTAssertEqual(plans.count, 6)
            for record in try context.fetch(FetchDescriptor<Visit>()) {
                if let event = record.event, SampleDataSeeder.isSampleEvent(event) {
                    XCTAssertLessThanOrEqual(record.endedAt, now)
                    XCTAssertGreaterThanOrEqual(record.endedAt, record.visitedAt)
                }
            }
            for plan in plans {
                XCTAssertGreaterThan(plan.startsAt, now)
                XCTAssertGreaterThan(plan.endsAt, plan.startsAt)
            }
            for attempt in try context.fetch(FetchDescriptor<TicketAttempt>()) {
                let start = try XCTUnwrap(attempt.plan?.startsAt)
                for deadline in [attempt.saleStartAt, attempt.applyDeadlineAt, attempt.resultAnnounceAt,
                                 attempt.paymentDeadlineAt, attempt.issueStartAt] where deadline != .distantPast {
                    XCTAssertLessThan(deadline, start, "\(attempt.statusKey): deadline after performance")
                }
            }
            let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
            XCTAssertEqual(events.filter(SampleDataSeeder.isSampleEvent).count, 32)
            XCTAssertEqual(events.filter { !SampleDataSeeder.isSampleEvent($0) }.map(\.id), [personal.id])
            XCTAssertEqual(visit.visitedAt, personalDate)
            XCTAssertEqual(visit.note, "変更しない")
            XCTAssertEqual(visit.event?.id, personal.id)
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

    private func makeCategory(name: String, templateKey: String) -> RecordCategory {
        RecordCategory(
            name: name,
            iconSymbol: templateKey == "random_goods" ? "shippingbox.fill" : "movieclapper.fill",
            colorHex: templateKey == "random_goods" ? "#9A6A8F" : "#3B3D4A",
            sortOrder: templateKey == "random_goods" ? 110 : 40,
            isBuiltIn: true,
            templateKey: templateKey
        )
    }

    private func assertSummary(
        _ summary: CollectibleSeriesSummary?,
        target: Int,
        collected: Int,
        owned: Int,
        duplicates: Int,
        spent: Decimal,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let summary else {
            XCTFail("期待したシリーズがありません", file: file, line: line)
            return
        }
        XCTAssertEqual(summary.targetCount, target, file: file, line: line)
        XCTAssertEqual(summary.collectedCount, collected, file: file, line: line)
        XCTAssertEqual(summary.ownedQuantity, owned, file: file, line: line)
        XCTAssertEqual(summary.duplicateQuantity, duplicates, file: file, line: line)
        XCTAssertEqual(summary.spentAmount, spent, file: file, line: line)
    }
}
