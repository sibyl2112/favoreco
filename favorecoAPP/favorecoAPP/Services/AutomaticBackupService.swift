import Foundation
import SwiftData

enum AutomaticBackupStorage: String, Sendable {
    case local
    case iCloudDrive

    nonisolated var displayName: String {
        switch self {
        case .local: return "この端末"
        case .iCloudDrive: return "iCloud Drive"
        }
    }
}

struct AutomaticBackupSnapshot: Identifiable {
    let url: URL
    let createdAt: Date
    let byteCount: Int64
    let storage: AutomaticBackupStorage

    var id: String { "\(storage.rawValue):\(url.path)" }
}

enum AutomaticBackupError: LocalizedError {
    case iCloudDriveUnavailable
    case insufficientStorage(requiredBytes: Int64, availableBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .iCloudDriveUnavailable:
            return "iCloud Driveを利用できません。Apple AccountとiCloud Driveの設定を確認してください。"
        case .insufficientStorage(let requiredBytes, let availableBytes):
            let required = ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)
            let available = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
            return "写真付きバックアップには約\(required)の空きが必要です。現在の空きは約\(available)です。"
        }
    }
}

enum AutomaticBackupService {
    nonisolated static let retentionCount = 5
    nonisolated static let interval: TimeInterval = 24 * 60 * 60

    nonisolated static func retentionCount(forPhotoBytes byteCount: Int64) -> Int {
        if byteCount >= 1_000_000_000 { return 2 }
        if byteCount >= 500_000_000 { return 3 }
        return retentionCount
    }

    @MainActor
    static func createIfDue(in context: ModelContext, now: Date = Date()) throws -> URL? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: AppStorageKeys.automaticBackupEnabled),
              EntitlementAccess.canUseSyncFeatures else { return nil }
        if let lastCreatedAt = defaults.object(forKey: AppStorageKeys.automaticBackupLastCreatedAt) as? Date,
           now.timeIntervalSince(lastCreatedAt) < interval {
            return nil
        }
        return try create(in: context, now: now)
    }

    @MainActor
    @discardableResult
    static func create(in context: ModelContext, now: Date = Date()) throws -> URL? {
        let snapshotContext = ModelContext(context.container)
        snapshotContext.autosaveEnabled = false
        let categories = try snapshotContext.fetch(FetchDescriptor<RecordCategory>())
        let events = try snapshotContext.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try snapshotContext.fetch(FetchDescriptor<Visit>())
        let inboxItems = try snapshotContext.fetch(FetchDescriptor<InboxItem>())
        let photos = try snapshotContext.fetch(FetchDescriptor<PhotoBlob>())
        let socialAccounts = try snapshotContext.fetch(FetchDescriptor<SocialAccount>())
        let people = try snapshotContext.fetch(FetchDescriptor<PersonMaster>())
        let companions = try snapshotContext.fetch(FetchDescriptor<CompanionMaster>())
        let favoriteProfiles = try snapshotContext.fetch(FetchDescriptor<FavoriteProfile>())
        let favoGalleryPhotos = try snapshotContext.fetch(FetchDescriptor<FavoGalleryPhoto>())
        let favoAnniversaries = try snapshotContext.fetch(FetchDescriptor<FavoAnniversary>())
        let favoPins = try snapshotContext.fetch(FetchDescriptor<FavoPin>())
        let personLinks = try snapshotContext.fetch(FetchDescriptor<EventPersonLink>())
        let places = try snapshotContext.fetch(FetchDescriptor<PlaceMaster>())
        let plans = try snapshotContext.fetch(FetchDescriptor<Plan>())
        let ticketAccounts = try snapshotContext.fetch(FetchDescriptor<TicketAccount>())
        let ticketAttempts = try snapshotContext.fetch(FetchDescriptor<TicketAttempt>())
        let primaryContentCount = categories.filter { !$0.isBuiltIn }.count
            + events.count + visits.count + inboxItems.count + photos.count
        let masterContentCount = socialAccounts.count + people.count + companions.count
            + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count + favoPins.count + personLinks.count + places.count
        let planningContentCount = plans.count + ticketAccounts.count + ticketAttempts.count
        let userContentCount = primaryContentCount + masterContentCount + planningContentCount
        guard userContentCount > 0 else { return nil }

        let totalPhotoBytes = photos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
            + favoGalleryPhotos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
        try ensureAvailableCapacity(forPhotoBytes: totalPhotoBytes)
        let retentionLimit = retentionCount(forPhotoBytes: totalPhotoBytes)

        let json = try JSONBackupExportService.makeBackupJSON(
            categories: categories,
            events: events,
            visits: visits,
            inboxItems: inboxItems,
            photos: photos,
            socialAccounts: socialAccounts,
            people: people,
            companions: companions,
            favoriteProfiles: favoriteProfiles,
            favoGalleryPhotos: favoGalleryPhotos,
            favoAnniversaries: favoAnniversaries,
            favoPins: favoPins,
            personLinks: personLinks,
            places: places,
            plans: plans,
            ticketAccounts: ticketAccounts,
            ticketAttempts: ticketAttempts,
            includesPhotoBinaryData: false,
            isFullBackupManifest: true
        )
        let temporaryURL = try FullBackupService.makePackage(json: json, photos: photos)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        let directory = try backupDirectory(for: .local)
        let destination = directory
            .appendingPathComponent(filename(for: now))
            .appendingPathExtension("favorecobackup")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        UserDefaults.standard.set(now, forKey: AppStorageKeys.automaticBackupLastCreatedAt)
        try pruneOldSnapshots(in: .local, keeping: retentionLimit)
        copyToICloudDriveIfEnabled(localURL: destination, createdAt: now, retentionLimit: retentionLimit)
        return destination
    }

    nonisolated static func snapshots(in storage: AutomaticBackupStorage) throws -> [AutomaticBackupSnapshot] {
        let directory = try backupDirectory(for: storage)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap { url in
            guard url.pathExtension == "favorecobackup" else { return nil }
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .totalFileAllocatedSizeKey])
            return AutomaticBackupSnapshot(
                url: url,
                createdAt: values?.creationDate ?? values?.contentModificationDate ?? .distantPast,
                byteCount: directoryByteCount(at: url),
                storage: storage
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated static func delete(_ snapshot: AutomaticBackupSnapshot) throws {
        try FileManager.default.removeItem(at: snapshot.url)
    }

    nonisolated static func isICloudDriveAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    nonisolated private static func backupDirectory(for storage: AutomaticBackupStorage) throws -> URL {
        let directory: URL
        switch storage {
        case .local:
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = base.appendingPathComponent("AutomaticBackups", isDirectory: true)
        case .iCloudDrive:
            guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                throw AutomaticBackupError.iCloudDriveUnavailable
            }
            directory = container
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("Favoreco", isDirectory: true)
                .appendingPathComponent("AutomaticBackups", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func pruneOldSnapshots(in storage: AutomaticBackupStorage, keeping retentionLimit: Int) throws {
        for snapshot in try snapshots(in: storage).dropFirst(retentionLimit) {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }

    private static func copyToICloudDriveIfEnabled(localURL: URL, createdAt: Date, retentionLimit: Int) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: AppStorageKeys.automaticBackupUsesICloudDrive) else {
            defaults.set("", forKey: AppStorageKeys.automaticBackupICloudError)
            return
        }
        do {
            let directory = try backupDirectory(for: .iCloudDrive)
            let destination = directory.appendingPathComponent(localURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: localURL, to: destination)
            defaults.set(createdAt, forKey: AppStorageKeys.automaticBackupLastICloudCreatedAt)
            defaults.set("", forKey: AppStorageKeys.automaticBackupICloudError)
            try pruneOldSnapshots(in: .iCloudDrive, keeping: retentionLimit)
        } catch {
            defaults.set(error.localizedDescription, forKey: AppStorageKeys.automaticBackupICloudError)
        }
    }

    nonisolated private static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "favoreco-auto-\(formatter.string(from: date))"
    }

    nonisolated private static func ensureAvailableCapacity(forPhotoBytes photoBytes: Int64) throws {
        guard photoBytes > 0 else { return }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let values = try base.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values.volumeAvailableCapacityForImportantUsage else { return }
        let safetyMargin = max(Int64(500_000_000), photoBytes / 10)
        let required = photoBytes + safetyMargin
        if available < required {
            throw AutomaticBackupError.insufficientStorage(requiredBytes: required, availableBytes: available)
        }
    }

    nonisolated private static func directoryByteCount(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
