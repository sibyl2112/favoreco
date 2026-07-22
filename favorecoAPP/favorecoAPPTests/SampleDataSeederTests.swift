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

        XCTAssertEqual(inserted.eventCount, 3)
        XCTAssertEqual(inserted.visitCount, 0)
        XCTAssertEqual(inserted.planCount, 0)
        XCTAssertEqual(inserted.ticketAttemptCount, 0)

        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let samples = events.filter(SampleDataSeeder.isSampleEvent)
        XCTAssertEqual(samples.count, 3)
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

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 15)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 11)

        let deleted = try SampleDataSeeder.deleteSamples(in: context)
        XCTAssertEqual(deleted.eventCount, 3)
        XCTAssertEqual(deleted.visitCount, 0)
        XCTAssertEqual(deleted.planCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 0)

        let remainingEvents = try context.fetch(FetchDescriptor<ExperienceEvent>())
        XCTAssertEqual(remainingEvents.map(\.id), [personalEvent.id])
    }

    func testStandardCategoryKeepsTwoVisitsAndOneFuturePlan() throws {
        let context = try makeContext()
        let category = makeCategory(name: "映画", templateKey: "movie")
        context.insert(category)
        try context.save()

        let inserted = try SampleDataSeeder.replaceSamples(
            in: context,
            categoryTemplateKeys: ["movie"]
        )

        XCTAssertEqual(inserted.eventCount, 3)
        XCTAssertEqual(inserted.visitCount, 2)
        XCTAssertEqual(inserted.planCount, 1)
        XCTAssertEqual(inserted.ticketAttemptCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Plan>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleTransaction>()), 0)
    }

    func testAutomaticInsertionRunsOnlyOnce() throws {
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

        XCTAssertEqual(first.eventCount, 3)
        XCTAssertEqual(first.visitCount, 0)
        XCTAssertEqual(first.planCount, 0)
        XCTAssertEqual(second.eventCount, 0)
        XCTAssertEqual(second.visitCount, 0)
        XCTAssertEqual(second.planCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExperienceEvent>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CollectibleItem>()), 15)
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
