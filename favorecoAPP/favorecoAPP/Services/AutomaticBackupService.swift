import Foundation
import SwiftData

struct AutomaticBackupSnapshot: Identifiable {
    let url: URL
    let createdAt: Date
    let byteCount: Int64

    var id: String { url.path }
}

enum AutomaticBackupService {
    nonisolated static let retentionCount = 5
    nonisolated static let interval: TimeInterval = 24 * 60 * 60

    @MainActor
    static func createIfDue(in context: ModelContext, now: Date = Date()) throws -> URL? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: AppStorageKeys.automaticBackupEnabled) else { return nil }
        if let lastCreatedAt = defaults.object(forKey: AppStorageKeys.automaticBackupLastCreatedAt) as? Date,
           now.timeIntervalSince(lastCreatedAt) < interval {
            return nil
        }
        return try create(in: context, now: now)
    }

    @MainActor
    @discardableResult
    static func create(in context: ModelContext, now: Date = Date()) throws -> URL? {
        let categories = try context.fetch(FetchDescriptor<RecordCategory>())
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let inboxItems = try context.fetch(FetchDescriptor<InboxItem>())
        let photos = try context.fetch(FetchDescriptor<PhotoBlob>())
        let socialAccounts = try context.fetch(FetchDescriptor<SocialAccount>())
        let people = try context.fetch(FetchDescriptor<PersonMaster>())
        let personLinks = try context.fetch(FetchDescriptor<EventPersonLink>())
        let places = try context.fetch(FetchDescriptor<PlaceMaster>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        let ticketAccounts = try context.fetch(FetchDescriptor<TicketAccount>())
        let ticketAttempts = try context.fetch(FetchDescriptor<TicketAttempt>())
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
        let directory = try backupDirectory()
        let destination = directory
            .appendingPathComponent(filename(for: now))
            .appendingPathExtension("favorecobackup")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        UserDefaults.standard.set(now, forKey: AppStorageKeys.automaticBackupLastCreatedAt)
        try pruneOldSnapshots()
        return destination
    }

    nonisolated static func snapshots() throws -> [AutomaticBackupSnapshot] {
        let directory = try backupDirectory()
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
                byteCount: directoryByteCount(at: url)
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated static func delete(_ snapshot: AutomaticBackupSnapshot) throws {
        try FileManager.default.removeItem(at: snapshot.url)
    }

    nonisolated private static func backupDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("AutomaticBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func pruneOldSnapshots() throws {
        for snapshot in try snapshots().dropFirst(retentionCount) {
            try? FileManager.default.removeItem(at: snapshot.url)
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
