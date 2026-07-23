import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let favorecoBackup = UTType(exportedAs: "com.ranoviqo.favoreco.backup", conformingTo: .package)
}

struct FullBackupPreview {
    let jsonPreview: JSONBackupPreview
    let availablePhotoCount: Int
    let totalPhotoBytes: Int64
}

struct FullBackupRestoreResult {
    let modelResult: JSONBackupRestoreResult
    let insertedPhotoCount: Int
    let updatedPhotoCount: Int
    let missingPhotoCount: Int
}

enum FullBackupService {
    nonisolated static let manifestFilename = "manifest.json"
    nonisolated static let mediaDirectoryName = "media"

    nonisolated static func makePackage(
        json: String,
        photos: [PhotoBlob]
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("favoreco-full-\(UUID().uuidString)")
            .appendingPathExtension("favorecobackup")
        do {
            let mediaDirectory = root.appendingPathComponent(mediaDirectoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
            try Data(json.utf8).write(to: root.appendingPathComponent(manifestFilename), options: .atomic)

            for photo in photos {
                let data = photo.data
                guard !data.isEmpty else { continue }
                let destination = mediaDirectory.appendingPathComponent("\(photo.id.uuidString).bin")
                try data.write(to: destination, options: .atomic)
            }
            return root
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    nonisolated static func copyPackageToTemporaryLocation(from sourceURL: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("favoreco-import-\(UUID().uuidString)")
            .appendingPathExtension("favorecobackup")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    @MainActor
    static func inspect(packageURL: URL) throws -> FullBackupPreview {
        let manifestData = try Data(contentsOf: packageURL.appendingPathComponent(manifestFilename))
        let jsonPreview = try JSONBackupImportService.inspect(data: manifestData)
        let envelope = try decodeEnvelope(manifestData)
        let mediaDirectory = packageURL.appendingPathComponent(mediaDirectoryName, isDirectory: true)
        var availablePhotoCount = 0
        var totalPhotoBytes: Int64 = 0
        for photo in envelope.photos {
            let fileURL = mediaDirectory.appendingPathComponent("\(photo.id.uuidString).bin")
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            availablePhotoCount += 1
            totalPhotoBytes += Int64(values.fileSize ?? 0)
        }
        return FullBackupPreview(
            jsonPreview: jsonPreview,
            availablePhotoCount: availablePhotoCount,
            totalPhotoBytes: totalPhotoBytes
        )
    }

    @MainActor
    static func restore(packageURL: URL, in context: ModelContext) throws -> FullBackupRestoreResult {
        let manifestData = try Data(contentsOf: packageURL.appendingPathComponent(manifestFilename))
        let envelope = try decodeEnvelope(manifestData)
        let modelResult = try JSONBackupImportService.restore(
            data: manifestData,
            in: context,
            savesChanges: false
        )
        let mediaDirectory = packageURL.appendingPathComponent(mediaDirectoryName, isDirectory: true)

        let visits = Dictionary(grouping: try context.fetch(FetchDescriptor<Visit>()), by: \.id)
            .compactMapValues(\.first)
        var photos = Dictionary(grouping: try context.fetch(FetchDescriptor<PhotoBlob>()), by: \.id)
            .compactMapValues(\.first)
        var insertedPhotoCount = 0
        var updatedPhotoCount = 0
        var missingPhotoCount = 0

        for item in envelope.photos {
            let sourceURL = mediaDirectory.appendingPathComponent("\(item.id.uuidString).bin")
            guard let data = try? Data(contentsOf: sourceURL), !data.isEmpty else {
                missingPhotoCount += 1
                continue
            }

            let model: PhotoBlob
            if let existing = photos[item.id] {
                model = existing
                updatedPhotoCount += 1
            } else {
                model = PhotoBlob(id: item.id)
                context.insert(model)
                photos[item.id] = model
                insertedPhotoCount += 1
            }
            model.relativePath = item.relativePath
            model.originalFilename = item.originalFilename
            model.mediaKind = item.mediaKind
            model.purpose = item.purpose
            model.ocrText = item.ocrText ?? ""
            model.amount = item.amount ?? Decimal(0)
            model.byteCount = data.count
            model.width = item.width
            model.height = item.height
            model.createdAt = item.createdAt
            model.data = data
            model.visit = item.visitID.flatMap { visits[$0] }
        }

        let galleryPhotos = Dictionary(
            grouping: try context.fetch(FetchDescriptor<FavoGalleryPhoto>()),
            by: \.id
        ).compactMapValues(\.first)
        for item in envelope.favoGalleryPhotos ?? [] {
            guard let galleryPhoto = galleryPhotos[item.id],
                  let sourcePhotoID = item.sourcePhotoID,
                  let sourcePhoto = photos[sourcePhotoID] else { continue }
            galleryPhoto.sourcePhoto = sourcePhoto
            galleryPhoto.data = Data()
            galleryPhoto.byteCount = sourcePhoto.byteCount
            galleryPhoto.width = sourcePhoto.width
            galleryPhoto.height = sourcePhoto.height
        }

        try context.save()
        return FullBackupRestoreResult(
            modelResult: modelResult,
            insertedPhotoCount: insertedPhotoCount,
            updatedPhotoCount: updatedPhotoCount,
            missingPhotoCount: missingPhotoCount
        )
    }

    @MainActor
    private static func decodeEnvelope(_ data: Data) throws -> FavorecoBackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FavorecoBackupEnvelope.self, from: data)
    }
}
