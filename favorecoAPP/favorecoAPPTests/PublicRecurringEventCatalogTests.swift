import XCTest
@testable import favoreco

@MainActor
final class PublicRecurringEventCatalogTests: XCTestCase {
    func testCacheUpsertsAndRemovesTombstone() {
        let old = makeEntry(name: "旧名称", updatedAt: date(1))
        let new = makeEntry(name: "新名称", updatedAt: date(2))
        var cache = PublicRecurringEventCatalogCache()

        cache.merge([change(old)])
        cache.merge([change(new)])

        XCTAssertEqual(cache.entries.map(\.officialName), ["新名称"])
        XCTAssertEqual(cache.lastSyncedAt, date(2))

        cache.merge([
            PublicRecurringEventCatalogChange(
                id: new.id,
                isPublished: true,
                isDeleted: true,
                updatedAt: date(3),
                entry: nil
            ),
        ])

        XCTAssertTrue(cache.entries.isEmpty)
    }

    func testPreferredEditionUsesFutureEditionBeforePastEdition() {
        let future = edition(id: "future", startDate: Date().addingTimeInterval(86_400))
        let past = edition(id: "past", startDate: Date().addingTimeInterval(-172_800))
        let entry = makeEntry(editions: [past, future])

        XCTAssertEqual(entry.preferredEdition?.id, "future")
    }

    func testSelectableEditionsPutUpcomingFirstAndRecentPastNext() {
        let futureLater = edition(id: "future-later", startDate: Date().addingTimeInterval(172_800))
        let pastOlder = edition(id: "past-older", startDate: Date().addingTimeInterval(-259_200))
        let futureSooner = edition(id: "future-sooner", startDate: Date().addingTimeInterval(86_400))
        let pastRecent = edition(id: "past-recent", startDate: Date().addingTimeInterval(-172_800))
        let entry = makeEntry(editions: [pastOlder, futureLater, pastRecent, futureSooner])

        XCTAssertEqual(
            entry.selectableEditions.map(\.id),
            ["future-sooner", "future-later", "past-recent", "past-older"]
        )
    }

    func testImporterMatchesSourceMarkerWithoutOverwritingTitle() {
        let category = RecordCategory(name: "ミュージアム", templateKey: "museum")
        let entry = makeEntry(name: "横浜トリエンナーレ")
        let event = ExperienceEvent(
            title: "利用者が編集した名称",
            importMemo: PublicRecurringEventCatalogImporter.sourceMarker(for: entry.id),
            category: category
        )

        XCTAssertTrue(
            PublicRecurringEventCatalogImporter.matchingEvent(
                for: entry,
                category: category,
                in: [event]
            ) === event
        )
    }

    private func makeEntry(
        name: String = "横浜トリエンナーレ",
        editions: [PublicRecurringEventEdition]? = nil,
        updatedAt: Date? = nil
    ) -> PublicRecurringEventCatalogEntry {
        PublicRecurringEventCatalogEntry(
            id: "jp-art-yokohama-triennale",
            officialName: name,
            reading: "よこはまとりえんなーれ",
            aliases: ["Yokohama Triennale"],
            templateKey: "museum",
            eventTypeKeys: ["art_festival", "triennale"],
            recurrenceKey: "triennial",
            recurrenceLabel: "3年ごと",
            prefectures: ["神奈川県"],
            areaSummary: "横浜美術館ほか",
            officialURL: "https://example.com/",
            sourceURL: "https://example.com/source",
            status: "active",
            editions: editions ?? [edition(id: "edition", startDate: Date())],
            updatedAt: updatedAt ?? date(1)
        )
    }

    private func edition(id: String, startDate: Date) -> PublicRecurringEventEdition {
        PublicRecurringEventEdition(
            id: id,
            label: id,
            startDate: startDate,
            endDate: startDate,
            dateStatus: "confirmed",
            status: "announced",
            prefectures: ["神奈川県"],
            areaSummary: "横浜市",
            officialURL: "https://example.com/edition",
            sourceURL: "https://example.com/source",
            verifiedAt: date(1)
        )
    }

    private func change(_ entry: PublicRecurringEventCatalogEntry) -> PublicRecurringEventCatalogChange {
        PublicRecurringEventCatalogChange(
            id: entry.id,
            isPublished: true,
            isDeleted: false,
            updatedAt: entry.updatedAt,
            entry: entry
        )
    }

    private func date(_ day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400))
    }
}
