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
