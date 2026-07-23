import XCTest
import SwiftData
@testable import favoreco

@MainActor
final class PublicPlaceCatalogTests: XCTestCase {
    func testCacheUpsertsAndAppliesTombstones() {
        let first = makeEntry(id: "place-1", name: "旧名称", updatedAt: date(1))
        let second = makeEntry(id: "place-1", name: "新名称", updatedAt: date(2))
        var cache = PublicPlaceCatalogCache()

        cache.merge([change(first)])
        cache.merge([change(second)])

        XCTAssertEqual(cache.entries.count, 1)
        XCTAssertEqual(cache.entries.first?.officialName, "新名称")
        XCTAssertEqual(cache.lastSyncedAt, date(2))

        cache.merge([
            PublicPlaceCatalogChange(
                id: second.id,
                isPublished: true,
                isDeleted: true,
                updatedAt: date(3),
                entry: nil
            ),
        ])

        XCTAssertTrue(cache.entries.isEmpty)
        XCTAssertEqual(cache.lastSyncedAt, date(3))
    }

    func testImporterPreservesCatalogFieldsWithoutAddingSwiftDataSchema() {
        let entry = PublicPlaceCatalogEntry(
            id: "shrine-1",
            catalogID: "religious",
            parentPlaceID: "",
            typeKeys: ["shrine", "pilgrimage_site"],
            officialName: "試験神社",
            reading: "しけんじんじゃ",
            aliases: ["旧称"],
            prefecture: "東京都",
            municipality: "千代田区",
            address: "東京都千代田区1-1",
            latitude: 35.0,
            longitude: 139.0,
            officialURL: "https://example.org/",
            capacity: nil,
            operationalStatusRaw: PlaceOperationalStatus.open.rawValue,
            templeSect: "",
            enshrinedDeities: ["天照大神", "須佐之男命"],
            pilgrimageMemberships: [
                PlacePilgrimageMembership(
                    pilgrimageKey: "test-route",
                    pilgrimageName: "試験霊場",
                    siteNumber: 4,
                    siteNumberLabel: "第四番"
                ),
            ],
            updatedAt: date(1)
        )

        let place = PublicPlaceCatalogImporter.makePlaceMaster(from: entry, now: date(4))

        XCTAssertEqual(place.name, "試験神社")
        XCTAssertEqual(place.prefecture, "東京都")
        XCTAssertEqual(place.placeTagsRaw, "shrine,pilgrimage_site")
        XCTAssertEqual(place.sourceSnapshotRaw, "favoreco.public-place-catalog:shrine-1")
        XCTAssertTrue(place.memo.contains("天照大神、須佐之男命"))
        XCTAssertEqual(PlacePilgrimageMembership.decode(place.pilgrimageMembershipsRaw).first?.siteNumber, 4)
    }

    func testSuggestionsMatchReadingAliasAndAddressAndExcludeClosedForPlans() {
        let open = makeEntry(
            id: "place-open",
            name: "東京試験劇場",
            reading: "とうきょうしけんげきじょう",
            aliases: ["テストシアター"],
            address: "東京都千代田区丸の内1-1",
            status: .open,
            updatedAt: date(1)
        )
        let closed = makeEntry(
            id: "place-closed",
            name: "旧試験劇場",
            reading: "きゅうしけんげきじょう",
            status: .closed,
            updatedAt: date(1)
        )
        let entries = [open, closed]

        XCTAssertEqual(PublicPlaceCatalogSearch.suggestions(for: "とうきょう", in: entries, includesClosed: true).map(\.id), [open.id])
        XCTAssertEqual(PublicPlaceCatalogSearch.suggestions(for: "テストシアター", in: entries, includesClosed: true).map(\.id), [open.id])
        XCTAssertEqual(PublicPlaceCatalogSearch.suggestions(for: "丸の内", in: entries, includesClosed: true).map(\.id), [open.id])
        XCTAssertEqual(PublicPlaceCatalogSearch.suggestions(for: "試験劇場", in: entries, includesClosed: false).map(\.id), [open.id])
    }

    func testSelectionDraftKeepsCatalogValueWithoutCreatingModel() {
        let entry = makeEntry(id: "draft-place", name: "下書き劇場", updatedAt: date(1))

        let selection = PublicPlaceSelectionDraft(entry: entry)

        XCTAssertEqual(selection.entry, entry)
    }

    func testResolveSelectionReusesExistingPlace() throws {
        let entry = makeEntry(id: "existing-place", name: "既存劇場", updatedAt: date(1))
        let existing = PublicPlaceCatalogImporter.makePlaceMaster(from: entry, now: date(1))
        let container = try ModelContainer(
            for: PlaceMaster.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(existing)
        try context.save()

        let resolved = PublicPlaceCatalogImporter.resolveSelection(
            PublicPlaceSelectionDraft(entry: entry),
            existingPlaces: [existing],
            in: context,
            now: date(2)
        )

        XCTAssertTrue(resolved === existing)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlaceMaster>()), 1)
    }

    func testResolveSelectionRollsBackWithCancelledParentSave() throws {
        let entry = makeEntry(id: "cancelled-place", name: "キャンセル劇場", updatedAt: date(1))
        let container = try ModelContainer(
            for: PlaceMaster.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        _ = PublicPlaceCatalogImporter.resolveSelection(
            PublicPlaceSelectionDraft(entry: entry),
            existingPlaces: [],
            in: context,
            now: date(2)
        )
        XCTAssertTrue(context.hasChanges)

        context.rollback()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlaceMaster>()), 0)
    }

    private func makeEntry(
        id: String,
        name: String,
        reading: String = "",
        aliases: [String] = [],
        address: String = "東京都千代田区1-1",
        status: PlaceOperationalStatus = .open,
        updatedAt: Date
    ) -> PublicPlaceCatalogEntry {
        PublicPlaceCatalogEntry(
            id: id,
            catalogID: "test",
            parentPlaceID: "",
            typeKeys: ["theater"],
            officialName: name,
            reading: reading,
            aliases: aliases,
            prefecture: "東京都",
            municipality: "",
            address: address,
            latitude: 0,
            longitude: 0,
            officialURL: "",
            capacity: 100,
            operationalStatusRaw: status.rawValue,
            templeSect: "",
            enshrinedDeities: [],
            pilgrimageMemberships: [],
            updatedAt: updatedAt
        )
    }

    private func change(_ entry: PublicPlaceCatalogEntry) -> PublicPlaceCatalogChange {
        PublicPlaceCatalogChange(
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
