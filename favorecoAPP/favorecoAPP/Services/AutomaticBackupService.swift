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

    var errorDescription: String? {
        switch self {
        case .iCloudDriveUnavailable:
            return "iCloud Driveを利用できません。Apple AccountとiCloud Driveの設定を確認してください。"
        }
    }
}

enum AutomaticBackupService {
    nonisolated static let retentionCount = 5
    nonisolated static let interval: TimeInterval = 24 * 60 * 60

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
        let personLinks = try snapshotContext.fetch(FetchDescriptor<EventPersonLink>())
        let places = try snapshotContext.fetch(FetchDescriptor<PlaceMaster>())
        let plans = try snapshotContext.fetch(FetchDescriptor<Plan>())
        let ticketAccounts = try snapshotContext.fetch(FetchDescriptor<TicketAccount>())
        let ticketAttempts = try snapshotContext.fetch(FetchDescriptor<TicketAttempt>())
        let modelCount = categories.count + events.count + visits.count + inboxItems.count
            + socialAccounts.count + people.count + personLinks.count + places.count
            + plans.count + ticketAccounts.count + ticketAttempts.count
        guard modelCount > 0 else { return nil }

        let json = try JSONBackupExportService.makeBackupJSON(
            categories: categories,
            events: events,
            visits: visits,
            inboxItems: inboxItems,
            photos: photos,
            socialAccounts: socialAccounts,
            people: people,
            personLinks: personLinks,
            places: places,
            plans: plans,
            ticketAccounts: ticketAccounts,
            ticketAttempts: ticketAttempts,
            includesPhotoBinaryData: false,
            isFullBackupManifest: true
        )
        let temporaryURL = try FullBackupService.makePackage(json: json, photos: photos)
        let directory = try backupDirectory(for: .local)
        let destination = directory
            .appendingPathComponent(filename(for: now))
            .appendingPathExtension("favorecobackup")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        UserDefaults.standard.set(now, forKey: AppStorageKeys.automaticBackupLastCreatedAt)
        try pruneOldSnapshots(in: .local)
        copyToICloudDriveIfEnabled(localURL: destination, createdAt: now)
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

    nonisolated private static func pruneOldSnapshots(in storage: AutomaticBackupStorage) throws {
        for snapshot in try snapshots(in: storage).dropFirst(retentionCount) {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }

    private static func copyToICloudDriveIfEnabled(localURL: URL, createdAt: Date) {
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
            try pruneOldSnapshots(in: .iCloudDrive)
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
