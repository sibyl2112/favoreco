import SwiftData
import XCTest
@testable import favoreco

@MainActor
final class FavoGalleryReferenceTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    func testRemovingGallerySelectionKeepsOriginalRecordPhoto() throws {
        let context = try makeContext()
        let models = makeReferencedGalleryModels()
        insert(models, into: context)
        try context.save()

        XCTAssertEqual(models.galleryPhoto.resolvedData, models.sourcePhoto.data)

        context.delete(models.galleryPhoto)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoGalleryPhoto>()), 0)
    }

    func testDeletingOriginalRecordPhotoRemovesGallerySelection() throws {
        let context = try makeContext()
        let models = makeReferencedGalleryModels()
        insert(models, into: context)
        try context.save()

        context.delete(models.sourcePhoto)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoBlob>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FavoGalleryPhoto>()), 0)
    }

    func testCurrentSchemaBackupContainsSourceReferenceAndFallbackImage() throws {
        let models = makeReferencedGalleryModels()
        let json = try JSONBackupExportService.makeBackupJSON(
            categories: [],
            events: [models.event],
            visits: [models.visit],
            inboxItems: [],
            photos: [models.sourcePhoto],
            socialAccounts: [],
            people: [],
            companions: [],
            favoriteProfiles: [models.profile],
            favoGalleryPhotos: [models.galleryPhoto],
            favoAnniversaries: [],
            favoPins: [],
            personLinks: [],
            places: [],
            plans: [],
            ticketAccounts: [],
            ticketAttempts: []
        )
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(FavorecoBackupEnvelope.self, from: data)
        let backupPhoto = try XCTUnwrap(envelope.favoGalleryPhotos?.first)

        XCTAssertEqual(envelope.schemaVersion, JSONBackupExportService.schemaVersion)
        XCTAssertEqual(backupPhoto.sourcePhotoID, models.sourcePhoto.id)
        let fallbackData = try XCTUnwrap(Data(base64Encoded: backupPhoto.dataBase64))
        XCTAssertEqual(fallbackData, models.sourcePhoto.data)
    }

    func testStoriesAddSeasonalPhotoAndStaleFavoriteMemories() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 16,
            hour: 12
        )))
        let latest = makeVisit("最新", date: date(2026, 8, 15, calendar: calendar))
        let first = makeVisit("最初", date: date(2020, 1, 1, calendar: calendar))
        let onThisDay = makeVisit("過去の今日", date: date(2024, 8, 16, calendar: calendar))
        let lastYear = makeVisit("前年同月", date: date(2025, 8, 10, calendar: calendar))
        let photoRich = makeVisit("写真多数", date: date(2026, 7, 20, calendar: calendar))
        photoRich.photos = (0 ..< 3).map { index in
            PhotoBlob(
                originalFilename: "photo-\(index).jpg",
                byteCount: 1,
                width: 1,
                height: 1,
                data: Data([UInt8(index)]),
                visit: photoRich
            )
        }
        let staleFavorite = makeVisit("久しぶりの推し", date: date(2025, 4, 1, calendar: calendar))
        let stalePin = FavoPin(event: staleFavorite.event)

        let snapshot = FavoSnapshot.make(
            profiles: [],
            pins: [stalePin],
            people: [],
            links: [],
            visits: [first, lastYear, staleFavorite, latest, photoRich, onThisDay],
            plans: [],
            activePlaceCount: 0,
            now: now
        )

        XCTAssertEqual(
            snapshot.stories.map(\.label),
            ["LATEST", "FIRST", "ON THIS DAY", "LAST YEAR", "PHOTO MEMORY", "FAVO AGAIN"]
        )
        XCTAssertEqual(Set(snapshot.stories.map(\.visitID)).count, snapshot.stories.count)
    }

    func testStoriesDoNotDuplicateOneVisitAcrossThemes() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 16,
            hour: 12
        )))
        let visit = makeVisit("ひとつの記録", date: date(2025, 8, 16, calendar: calendar))
        visit.photos = (0 ..< 2).map { index in
            PhotoBlob(
                byteCount: 1,
                width: 1,
                height: 1,
                data: Data([UInt8(index)]),
                visit: visit
            )
        }

        let snapshot = FavoSnapshot.make(
            profiles: [],
            pins: [FavoPin(event: visit.event)],
            people: [],
            links: [],
            visits: [visit],
            plans: [],
            activePlaceCount: 0,
            now: now
        )

        XCTAssertEqual(snapshot.stories.map(\.label), ["LATEST"])
    }

    func testOldFavoriteMemoryIsNotStaleWhenSameFavoriteHasRecentVisit() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 16,
            hour: 12
        )))
        let favoriteEvent = ExperienceEvent(title: "継続している推し")
        let oldFavoriteVisit = Visit(
            visitedAt: date(2025, 4, 1, calendar: calendar),
            event: favoriteEvent
        )
        let recentFavoriteVisit = Visit(
            visitedAt: date(2026, 7, 20, calendar: calendar),
            event: favoriteEvent
        )
        let latest = makeVisit("最新", date: date(2026, 8, 15, calendar: calendar))
        let first = makeVisit("最初", date: date(2020, 1, 1, calendar: calendar))

        let snapshot = FavoSnapshot.make(
            profiles: [],
            pins: [FavoPin(event: favoriteEvent)],
            people: [],
            links: [],
            visits: [oldFavoriteVisit, recentFavoriteVisit, latest, first],
            plans: [],
            activePlaceCount: 0,
            now: now
        )

        XCTAssertFalse(snapshot.stories.map(\.label).contains("FAVO AGAIN"))
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

    private func makeReferencedGalleryModels() -> Models {
        let event = ExperienceEvent(title: "夏の公演")
        let visit = Visit(event: event)
        let imageData = Data([0x01, 0x02, 0x03, 0x04])
        let sourcePhoto = PhotoBlob(
            byteCount: imageData.count,
            width: 2,
            height: 2,
            data: imageData,
            visit: visit
        )
        let profile = FavoriteProfile(event: event)
        let galleryPhoto = FavoGalleryPhoto(
            byteCount: sourcePhoto.byteCount,
            width: sourcePhoto.width,
            height: sourcePhoto.height,
            profile: profile,
            sourcePhoto: sourcePhoto
        )
        return Models(
            event: event,
            visit: visit,
            sourcePhoto: sourcePhoto,
            profile: profile,
            galleryPhoto: galleryPhoto
        )
    }

    private func makeVisit(_ title: String, date: Date) -> Visit {
        let event = ExperienceEvent(title: title)
        return Visit(visitedAt: date, endedAt: date, createdAt: date, updatedAt: date, event: event)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func insert(_ models: Models, into context: ModelContext) {
        context.insert(models.event)
        context.insert(models.visit)
        context.insert(models.sourcePhoto)
        context.insert(models.profile)
        context.insert(models.galleryPhoto)
    }

    private struct Models {
        let event: ExperienceEvent
        let visit: Visit
        let sourcePhoto: PhotoBlob
        let profile: FavoriteProfile
        let galleryPhoto: FavoGalleryPhoto
    }
}
