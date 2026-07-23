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

enum AutomaticBackupRunMode: Sendable {
    case automatic
    case manual
}

struct AutomaticBackupRequest: Sendable {
    let mode: AutomaticBackupRunMode
    let now: Date
    let isEnabled: Bool
    let canUseSyncFeatures: Bool
    let usesICloudDrive: Bool
    let lastCreatedAt: Date?

    @MainActor
    static func automatic(canUseSyncFeatures: Bool, now: Date = Date()) -> Self {
        let defaults = UserDefaults.standard
        return Self(
            mode: .automatic,
            now: now,
            isEnabled: defaults.bool(forKey: AppStorageKeys.automaticBackupEnabled),
            canUseSyncFeatures: canUseSyncFeatures,
            usesICloudDrive: defaults.bool(forKey: AppStorageKeys.automaticBackupUsesICloudDrive),
            lastCreatedAt: defaults.object(forKey: AppStorageKeys.automaticBackupLastCreatedAt) as? Date
        )
    }

    @MainActor
    static func manual(usesICloudDrive: Bool, now: Date = Date()) -> Self {
        Self(
            mode: .manual,
            now: now,
            isEnabled: true,
            canUseSyncFeatures: true,
            usesICloudDrive: usesICloudDrive,
            lastCreatedAt: nil
        )
    }
}

enum AutomaticBackupRunStatus: String, Sendable, Equatable {
    case succeeded
    case succeededWithWarning
    case failed
    case noData
    case skippedDisabled
    case skippedNotDue
    case alreadyRunning

    nonisolated var displayName: String {
        switch self {
        case .succeeded: return "成功"
        case .succeededWithWarning: return "一部失敗"
        case .failed: return "失敗"
        case .noData: return "対象データなし"
        case .skippedDisabled: return "無効"
        case .skippedNotDue: return "作成時刻前"
        case .alreadyRunning: return "処理中"
        }
    }
}

struct AutomaticBackupRunResult: Sendable {
    let status: AutomaticBackupRunStatus
    let attemptedAt: Date
    let message: String
    let localURL: URL?
    let iCloudCreatedAt: Date?
    let iCloudError: String?
}

enum AutomaticBackupPolicy {
    nonisolated static func skipStatus(
        for request: AutomaticBackupRequest,
        interval: TimeInterval = AutomaticBackupService.interval
    ) -> AutomaticBackupRunStatus? {
        guard case .automatic = request.mode else { return nil }
        guard request.isEnabled, request.canUseSyncFeatures else { return .skippedDisabled }
        if let lastCreatedAt = request.lastCreatedAt,
           request.now.timeIntervalSince(lastCreatedAt) < interval {
            return .skippedNotDue
        }
        return nil
    }
}

actor AutomaticBackupCoordinator {
    static let shared = AutomaticBackupCoordinator()

    private var isRunning = false

    func run(
        request: AutomaticBackupRequest,
        modelContainer: ModelContainer
    ) async -> AutomaticBackupRunResult {
        if let status = AutomaticBackupPolicy.skipStatus(for: request) {
            return AutomaticBackupRunResult(
                status: status,
                attemptedAt: request.now,
                message: status.displayName,
                localURL: nil,
                iCloudCreatedAt: nil,
                iCloudError: nil
            )
        }
        guard !isRunning else {
            return AutomaticBackupRunResult(
                status: .alreadyRunning,
                attemptedAt: request.now,
                message: "別のバックアップ処理が進行中です。",
                localURL: nil,
                iCloudCreatedAt: nil,
                iCloudError: nil
            )
        }

        isRunning = true
        defer { isRunning = false }

        let result: AutomaticBackupRunResult
        do {
            let worker = AutomaticBackupModelActor(modelContainer: modelContainer)
            result = try await worker.create(request: request)
        } catch {
            result = AutomaticBackupRunResult(
                status: .failed,
                attemptedAt: request.now,
                message: error.localizedDescription,
                localURL: nil,
                iCloudCreatedAt: nil,
                iCloudError: nil
            )
        }
        persist(result)
        return result
    }

    private func persist(_ result: AutomaticBackupRunResult) {
        let defaults = UserDefaults.standard
        defaults.set(result.attemptedAt, forKey: AppStorageKeys.automaticBackupLastAttemptAt)
        defaults.set(result.status.rawValue, forKey: AppStorageKeys.automaticBackupLastResultStatus)
        defaults.set(result.message, forKey: AppStorageKeys.automaticBackupLastResultMessage)
        defaults.set(result.localURL?.path ?? "", forKey: AppStorageKeys.automaticBackupLastResultPath)
        if result.localURL != nil {
            defaults.set(result.attemptedAt, forKey: AppStorageKeys.automaticBackupLastCreatedAt)
        }
        if let iCloudCreatedAt = result.iCloudCreatedAt {
            defaults.set(iCloudCreatedAt, forKey: AppStorageKeys.automaticBackupLastICloudCreatedAt)
        }
        defaults.set(result.iCloudError ?? "", forKey: AppStorageKeys.automaticBackupICloudError)
    }
}

@ModelActor
actor AutomaticBackupModelActor {
    func create(request: AutomaticBackupRequest) throws -> AutomaticBackupRunResult {
        modelContext.autosaveEnabled = false
        let categories = try modelContext.fetch(FetchDescriptor<RecordCategory>())
        let events = try modelContext.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try modelContext.fetch(FetchDescriptor<Visit>())
        let inboxItems = try modelContext.fetch(FetchDescriptor<InboxItem>())
        let photos = try modelContext.fetch(FetchDescriptor<PhotoBlob>())
        let socialAccounts = try modelContext.fetch(FetchDescriptor<SocialAccount>())
        let people = try modelContext.fetch(FetchDescriptor<PersonMaster>())
        let companions = try modelContext.fetch(FetchDescriptor<CompanionMaster>())
        let favoriteProfiles = try modelContext.fetch(FetchDescriptor<FavoriteProfile>())
        let favoGalleryPhotos = try modelContext.fetch(FetchDescriptor<FavoGalleryPhoto>())
        let favoAnniversaries = try modelContext.fetch(FetchDescriptor<FavoAnniversary>())
        let favoPins = try modelContext.fetch(FetchDescriptor<FavoPin>())
        let personLinks = try modelContext.fetch(FetchDescriptor<EventPersonLink>())
        let places = try modelContext.fetch(FetchDescriptor<PlaceMaster>())
        let plans = try modelContext.fetch(FetchDescriptor<Plan>())
        let ticketAccounts = try modelContext.fetch(FetchDescriptor<TicketAccount>())
        let ticketAttempts = try modelContext.fetch(FetchDescriptor<TicketAttempt>())
        let primaryContentCount = categories.filter { !$0.isBuiltIn }.count
            + events.count + visits.count + inboxItems.count + photos.count
        let profileContentCount = socialAccounts.count + people.count + companions.count
            + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count
        let linkedContentCount = favoPins.count + personLinks.count + places.count
        let planningContentCount = plans.count + ticketAccounts.count + ticketAttempts.count
        let userContentCount = primaryContentCount
            + profileContentCount
            + linkedContentCount
            + planningContentCount
        guard userContentCount > 0 else {
            return AutomaticBackupRunResult(
                status: .noData,
                attemptedAt: request.now,
                message: "保存できるデータがまだありません。",
                localURL: nil,
                iCloudCreatedAt: nil,
                iCloudError: nil
            )
        }

        let totalPhotoBytes = photos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
            + favoGalleryPhotos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
        try AutomaticBackupService.ensureAvailableCapacity(forPhotoBytes: totalPhotoBytes)
        let retentionLimit = AutomaticBackupService.retentionCount(forPhotoBytes: totalPhotoBytes)
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
        defer { AutomaticBackupService.removeTemporaryPackageIfPresent(at: temporaryURL) }
        let directory = try AutomaticBackupService.backupDirectory(for: .local)
        let destination = directory
            .appendingPathComponent(AutomaticBackupService.filename(for: request.now))
            .appendingPathExtension("favorecobackup")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        try AutomaticBackupService.pruneOldSnapshots(in: .local, keeping: retentionLimit)

        let iCloudError = AutomaticBackupService.copyToICloudDrive(
            localURL: destination,
            retentionLimit: retentionLimit,
            isEnabled: request.usesICloudDrive
        )
        return AutomaticBackupRunResult(
            status: iCloudError == nil ? .succeeded : .succeededWithWarning,
            attemptedAt: request.now,
            message: iCloudError ?? "バックアップを作成しました。",
            localURL: destination,
            iCloudCreatedAt: request.usesICloudDrive && iCloudError == nil ? request.now : nil,
            iCloudError: iCloudError
        )
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

    nonisolated static func backupDirectory(for storage: AutomaticBackupStorage) throws -> URL {
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

    nonisolated static func pruneOldSnapshots(in storage: AutomaticBackupStorage, keeping retentionLimit: Int) throws {
        for snapshot in try snapshots(in: storage).dropFirst(retentionLimit) {
            try FileManager.default.removeItem(at: snapshot.url)
        }
    }

    nonisolated static func copyToICloudDrive(
        localURL: URL,
        retentionLimit: Int,
        isEnabled: Bool
    ) -> String? {
        guard isEnabled else { return nil }
        do {
            let directory = try backupDirectory(for: .iCloudDrive)
            let destination = directory.appendingPathComponent(localURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: localURL, to: destination)
            try pruneOldSnapshots(in: .iCloudDrive, keeping: retentionLimit)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    nonisolated static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "favoreco-auto-\(formatter.string(from: date))"
    }

    nonisolated static func ensureAvailableCapacity(forPhotoBytes photoBytes: Int64) throws {
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

    nonisolated static func removeTemporaryPackageIfPresent(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            assertionFailure("Failed to remove temporary backup package: \(error)")
        }
    }
}
