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

    func testSchemaTwelveBackupContainsSourceReferenceAndFallbackImage() throws {
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

        XCTAssertEqual(envelope.schemaVersion, 13)
        XCTAssertEqual(backupPhoto.sourcePhotoID, models.sourcePhoto.id)
        let fallbackData = try XCTUnwrap(Data(base64Encoded: backupPhoto.dataBase64))
        XCTAssertEqual(fallbackData, models.sourcePhoto.data)
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
