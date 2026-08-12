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

    func testCacheCodablePreservesSourceURL() throws {
        let entry = PublicPlaceCatalogEntry(
            id: "source-place",
            catalogID: "venue",
            parentPlaceID: "",
            typeKeys: ["theater"],
            officialName: "出典確認劇場",
            reading: "",
            aliases: [],
            prefecture: "東京都",
            municipality: "千代田区",
            address: "東京都千代田区1-1",
            latitude: 0,
            longitude: 0,
            officialURL: "https://example.org/venue",
            sourceURL: "https://example.org/evidence",
            capacity: 100,
            operationalStatusRaw: PlaceOperationalStatus.open.rawValue,
            templeSect: "",
            enshrinedDeities: [],
            pilgrimageMemberships: [],
            updatedAt: date(1)
        )
        var cache = PublicPlaceCatalogCache()
        cache.merge([change(entry)])

        let data = try JSONEncoder().encode(cache)
        let decoded = try JSONDecoder().decode(PublicPlaceCatalogCache.self, from: data)

        XCTAssertEqual(decoded.entries.first?.sourceURL, "https://example.org/evidence")
    }

    func testImporterPreservesCatalogFieldsInStructuredPlaceFields() {
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
            sourceURL: "https://example.org/source",
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
        XCTAssertEqual(place.templeSect, "")
        XCTAssertEqual(place.enshrinedDeities, ["天照大神", "須佐之男命"])
        XCTAssertTrue(place.memo.isEmpty)
        XCTAssertEqual(PlacePilgrimageMembership.decode(place.pilgrimageMembershipsRaw).first?.siteNumber, 4)
    }

    func testLegacyMemoReligiousDetailsRemainReadable() {
        let temple = PlaceMaster(memo: "利用者メモ\n宗派: 曹洞宗")
        let shrine = PlaceMaster(memo: "御祭神: 天照大神、須佐之男命\n利用者メモ")

        XCTAssertEqual(temple.resolvedTempleSect, "曹洞宗")
        XCTAssertEqual(shrine.resolvedEnshrinedDeities, ["天照大神", "須佐之男命"])
    }

    func testCatalogDetailsFillOnlyBlankStructuredFields() {
        let entry = PublicPlaceCatalogEntry(
            id: "shrine-details",
            catalogID: "religious",
            parentPlaceID: "",
            typeKeys: ["shrine"],
            officialName: "試験神社",
            reading: "",
            aliases: [],
            prefecture: "東京都",
            municipality: "",
            address: "東京都千代田区1-1",
            latitude: 0,
            longitude: 0,
            officialURL: "",
            sourceURL: "",
            capacity: nil,
            operationalStatusRaw: PlaceOperationalStatus.open.rawValue,
            templeSect: "",
            enshrinedDeities: ["天照大神"],
            pilgrimageMemberships: [],
            updatedAt: date(1)
        )
        let blank = PlaceMaster(name: "試験神社")
        let edited = PlaceMaster(name: "試験神社")
        edited.enshrinedDeities = ["利用者が編集した神名"]

        XCTAssertTrue(PublicPlaceCatalogImporter.applyCatalogDetails(from: entry, to: blank))
        XCTAssertEqual(blank.enshrinedDeities, ["天照大神"])
        XCTAssertFalse(PublicPlaceCatalogImporter.applyCatalogDetails(from: entry, to: edited))
        XCTAssertEqual(edited.enshrinedDeities, ["利用者が編集した神名"])
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

    func testCatalogScopesIncludeOnlyRelevantPlaceTypes() {
        let museum = makeEntry(
            id: "museum",
            name: "森美術館",
            catalogID: "museum",
            typeKeys: ["art_museum"],
            updatedAt: date(1)
        )
        let themePark = makeEntry(
            id: "theme-park",
            name: "試験テーマパーク",
            typeKeys: ["theme_park"],
            updatedAt: date(1)
        )
        let aquarium = makeEntry(
            id: "aquarium",
            name: "試験水族館",
            typeKeys: ["aquarium"],
            updatedAt: date(1)
        )

        XCTAssertTrue(PublicPlaceCatalogScope.museum.includes(museum))
        XCTAssertFalse(PublicPlaceCatalogScope.museum.includes(themePark))
        XCTAssertTrue(PublicPlaceCatalogScope.themePark.includes(themePark))
        XCTAssertFalse(PublicPlaceCatalogScope.themePark.includes(aquarium))
        XCTAssertTrue(PublicPlaceCatalogScope.natureLiving.includes(aquarium))
        XCTAssertFalse(PublicPlaceCatalogScope.natureLiving.includes(museum))
    }

    func testCatalogScopesClassifyImportedPlaceMasters() {
        let museum = PlaceMaster(name: "森美術館")
        museum.placeTagsRaw = "art_museum,museum"
        let themePark = PlaceMaster(name: "試験テーマパーク")
        themePark.placeTagsRaw = "theme_park,amusement_park"
        let aquarium = PlaceMaster(name: "試験水族館")
        aquarium.placeTagsRaw = "aquarium"

        XCTAssertTrue(PublicPlaceCatalogScope.museum.includes(museum))
        XCTAssertFalse(PublicPlaceCatalogScope.museum.includes(themePark))
        XCTAssertTrue(PublicPlaceCatalogScope.themePark.includes(themePark))
        XCTAssertFalse(PublicPlaceCatalogScope.themePark.includes(aquarium))
        XCTAssertTrue(PublicPlaceCatalogScope.natureLiving.includes(aquarium))
        XCTAssertFalse(PublicPlaceCatalogScope.natureLiving.includes(museum))
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
        catalogID: String = "test",
        typeKeys: [String] = ["theater"],
        address: String = "東京都千代田区1-1",
        status: PlaceOperationalStatus = .open,
        updatedAt: Date
    ) -> PublicPlaceCatalogEntry {
        PublicPlaceCatalogEntry(
            id: id,
            catalogID: catalogID,
            parentPlaceID: "",
            typeKeys: typeKeys,
            officialName: name,
            reading: reading,
            aliases: aliases,
            prefecture: "東京都",
            municipality: "",
            address: address,
            latitude: 0,
            longitude: 0,
            officialURL: "",
            sourceURL: "",
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
