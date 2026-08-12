import CloudKit
import Combine
import Foundation
import SwiftData

nonisolated struct PublicRecurringEventEdition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let startDate: Date?
    let endDate: Date?
    let dateStatus: String
    let status: String
    let prefectures: [String]
    let areaSummary: String
    let officialURL: String
    let sourceURL: String
    let verifiedAt: Date
}

nonisolated struct PublicRecurringEventCatalogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let officialName: String
    let reading: String
    let aliases: [String]
    let templateKey: String
    let eventTypeKeys: [String]
    let recurrenceKey: String
    let recurrenceLabel: String
    let prefectures: [String]
    let areaSummary: String
    let officialURL: String
    let sourceURL: String
    let status: String
    let editions: [PublicRecurringEventEdition]
    let updatedAt: Date

    var selectableEditions: [PublicRecurringEventEdition] {
        let today = Calendar.current.startOfDay(for: Date())
        return editions.sorted { lhs, rhs in
            let lhsDate = lhs.startDate
            let rhsDate = rhs.startDate
            let lhsIsUpcoming = (lhs.endDate ?? lhsDate ?? .distantPast) >= today
            let rhsIsUpcoming = (rhs.endDate ?? rhsDate ?? .distantPast) >= today

            if lhsIsUpcoming != rhsIsUpcoming {
                return lhsIsUpcoming
            }
            if lhsIsUpcoming {
                return (lhsDate ?? .distantFuture) < (rhsDate ?? .distantFuture)
            }
            return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
        }
    }

    var preferredEdition: PublicRecurringEventEdition? {
        selectableEditions.first
    }
}

nonisolated struct PublicRecurringEventCatalogChange: Sendable {
    let id: String
    let isPublished: Bool
    let isDeleted: Bool
    let updatedAt: Date
    let entry: PublicRecurringEventCatalogEntry?
}

nonisolated struct PublicRecurringEventCatalogCache: Codable, Sendable {
    static let schemaVersion = 1

    var schemaVersion = Self.schemaVersion
    var lastSyncedAt: Date?
    var entries: [PublicRecurringEventCatalogEntry] = []

    mutating func merge(_ changes: [PublicRecurringEventCatalogChange]) {
        var values = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for change in changes {
            if change.isDeleted || !change.isPublished {
                values.removeValue(forKey: change.id)
            } else if let entry = change.entry {
                values[change.id] = entry
            }
        }
        entries = values.values.sorted {
            $0.officialName.localizedStandardCompare($1.officialName) == .orderedAscending
        }
        if let newest = changes.map(\.updatedAt).max() {
            lastSyncedAt = max(lastSyncedAt ?? .distantPast, newest)
        }
    }
}

enum PublicRecurringEventCatalogImporter {
    static func sourceMarker(for id: String) -> String {
        "favoreco.public-recurring-event-catalog:\(id)"
    }

    static func matchingEvent(
        for entry: PublicRecurringEventCatalogEntry,
        category: RecordCategory,
        in events: [ExperienceEvent]
    ) -> ExperienceEvent? {
        let marker = sourceMarker(for: entry.id)
        return events.first {
            !$0.isArchived && $0.category?.id == category.id &&
                ($0.importMemo.contains(marker)
                 || normalizedRecurringEventText($0.title) == normalizedRecurringEventText(entry.officialName))
        }
    }

    @MainActor
    static func importEntry(
        _ entry: PublicRecurringEventCatalogEntry,
        category: RecordCategory,
        existingEvents: [ExperienceEvent],
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> ExperienceEvent {
        if let existing = matchingEvent(for: entry, category: category, in: existingEvents) {
            var changed = false
            if existing.officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.officialURL = entry.officialURL
                changed = true
            }
            let marker = sourceMarker(for: entry.id)
            if !existing.importMemo.contains(marker) {
                existing.importMemo = [existing.importMemo, marker].filter { !$0.isEmpty }.joined(separator: "\n")
                changed = true
            }
            if changed {
                existing.updatedAt = now
                try modelContext.save()
            }
            return existing
        }

        let event = ExperienceEvent(
            title: entry.officialName,
            officialURL: entry.officialURL,
            stateKey: "interested",
            importMemo: sourceMarker(for: entry.id),
            createdAt: now,
            updatedAt: now,
            category: category
        )
        modelContext.insert(event)
        do {
            try modelContext.save()
            return event
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

enum PublicRecurringEventCatalogSyncState: Equatable {
    case idle
    case loadingCache
    case syncing
    case ready(lastSyncedAt: Date?)
    case failed(message: String, hasCache: Bool)
}

@MainActor
final class PublicRecurringEventCatalogStore: ObservableObject {
    static let shared = PublicRecurringEventCatalogStore()

    @Published private(set) var entries: [PublicRecurringEventCatalogEntry] = []
    @Published private(set) var state: PublicRecurringEventCatalogSyncState = .idle

    private let repository: PublicRecurringEventCatalogRepository
    private var hasPrepared = false

    init(repository: PublicRecurringEventCatalogRepository = PublicRecurringEventCatalogRepository()) {
        self.repository = repository
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        state = .loadingCache
        let cache = await repository.loadCache()
        entries = cache.entries
        state = .ready(lastSyncedAt: cache.lastSyncedAt)
        await refresh()
    }

    func refresh() async {
        guard state != .syncing else { return }
        state = .syncing
        do {
            let cache = try await repository.synchronize()
            entries = cache.entries
            state = .ready(lastSyncedAt: cache.lastSyncedAt)
        } catch {
            state = .failed(message: error.localizedDescription, hasCache: !entries.isEmpty)
        }
    }
}

actor PublicRecurringEventCatalogRepository {
    private static let recordType = "PublicRecurringEvent"
    private let database: CKDatabase
    private let fileURL: URL
    private var memoryCache: PublicRecurringEventCatalogCache?

    init(database: CKDatabase = CKContainer.default().publicCloudDatabase, fileURL: URL? = nil) {
        self.database = database
        self.fileURL = fileURL ?? Self.defaultCacheURL()
    }

    func loadCache() -> PublicRecurringEventCatalogCache {
        if let memoryCache { return memoryCache }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.recurringCatalogDecoder.decode(
                PublicRecurringEventCatalogCache.self,
                from: data
              ),
              decoded.schemaVersion == PublicRecurringEventCatalogCache.schemaVersion else {
            let empty = PublicRecurringEventCatalogCache()
            memoryCache = empty
            return empty
        }
        memoryCache = decoded
        return decoded
    }

    func synchronize() async throws -> PublicRecurringEventCatalogCache {
        var cache = loadCache()
        let cursorDate = cache.lastSyncedAt?.addingTimeInterval(-1)
        let predicate = cursorDate.map { NSPredicate(format: "updatedAt > %@", $0 as NSDate) }
            ?? NSPredicate(value: true)
        let records = try await fetchAllRecords(matching: predicate)
        cache.merge(try records.map { try Self.change(from: $0) })
        try persist(cache)
        memoryCache = cache
        return cache
    }

    private func fetchAllRecords(matching predicate: NSPredicate) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page = try await fetchPage(predicate: predicate, cursor: cursor)
            records.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil
        return records
    }

    private func fetchPage(
        predicate: NSPredicate,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation = cursor.map(CKQueryOperation.init(cursor:))
                ?? CKQueryOperation(query: CKQuery(recordType: Self.recordType, predicate: predicate))
            operation.resultsLimit = 200
            let lock = NSLock()
            var pageRecords: [CKRecord] = []
            var firstError: Error?
            operation.recordMatchedBlock = { _, result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case let .success(record): pageRecords.append(record)
                case let .failure(error): if firstError == nil { firstError = error }
                }
            }
            operation.queryResultBlock = { result in
                lock.lock()
                let resolved = pageRecords
                let recordError = firstError
                lock.unlock()
                if let recordError {
                    continuation.resume(throwing: recordError)
                } else {
                    continuation.resume(with: result.map { (resolved, $0) })
                }
            }
            database.add(operation)
        }
    }

    private func persist(_ cache: PublicRecurringEventCatalogCache) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.recurringCatalogEncoder.encode(cache)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultCacheURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PublicRecurringEventCatalog", isDirectory: true)
            .appendingPathComponent("catalog-v1.json")
    }

    private static func change(from record: CKRecord) throws -> PublicRecurringEventCatalogChange {
        let id = string(record, "eventSeriesID", fallback: record.recordID.recordName)
        let updatedAt = (record["updatedAt"] as? Date) ?? record.modificationDate ?? .distantPast
        let isPublished = (record["isPublished"] as? NSNumber)?.boolValue ?? true
        let isDeleted = (record["isDeleted"] as? NSNumber)?.boolValue ?? false
        let entry: PublicRecurringEventCatalogEntry?
        if isPublished && !isDeleted {
            guard let rawEditions = record["editionsJSON"] as? String,
                  let editionData = rawEditions.data(using: .utf8),
                  let editions = try? JSONDecoder.recurringCatalogDecoder.decode(
                    [PublicRecurringEventEdition].self,
                    from: editionData
                  ) else {
                throw PublicRecurringEventCatalogError.invalidRecord(record.recordID.recordName)
            }
            let name = string(record, "officialName")
            let templateKey = string(record, "templateKey")
            guard !id.isEmpty, !name.isEmpty, ["museum", "theater", "live"].contains(templateKey) else {
                throw PublicRecurringEventCatalogError.invalidRecord(record.recordID.recordName)
            }
            entry = PublicRecurringEventCatalogEntry(
                id: id,
                officialName: name,
                reading: string(record, "reading"),
                aliases: strings(record, "aliases"),
                templateKey: templateKey,
                eventTypeKeys: strings(record, "eventTypeKeys"),
                recurrenceKey: string(record, "recurrenceKey"),
                recurrenceLabel: string(record, "recurrenceLabel"),
                prefectures: strings(record, "prefectures"),
                areaSummary: string(record, "areaSummary"),
                officialURL: string(record, "officialURL"),
                sourceURL: string(record, "sourceURL"),
                status: string(record, "status"),
                editions: editions,
                updatedAt: updatedAt
            )
        } else {
            entry = nil
        }
        return PublicRecurringEventCatalogChange(
            id: id,
            isPublished: isPublished,
            isDeleted: isDeleted,
            updatedAt: updatedAt,
            entry: entry
        )
    }

    private static func string(_ record: CKRecord, _ key: String, fallback: String = "") -> String {
        (record[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback
    }

    private static func strings(_ record: CKRecord, _ key: String) -> [String] {
        (record[key] as? [String]) ?? []
    }
}

nonisolated enum PublicRecurringEventCatalogError: LocalizedError {
    case invalidRecord(String)

    var errorDescription: String? {
        switch self {
        case let .invalidRecord(name): "定期イベントカタログのレコード形式が不正です（\(name)）。"
        }
    }
}

private extension JSONDecoder {
    nonisolated static var recurringCatalogDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    nonisolated static var recurringCatalogEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private func normalizedRecurringEventText(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .filter { !$0.isWhitespace }
}
