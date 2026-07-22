import CloudKit
import Combine
import Foundation
import SwiftData

struct PublicPlaceCatalogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let catalogID: String
    let parentPlaceID: String
    let typeKeys: [String]
    let officialName: String
    let reading: String
    let aliases: [String]
    let prefecture: String
    let municipality: String
    let address: String
    let latitude: Double
    let longitude: Double
    let officialURL: String
    let capacity: Int?
    let operationalStatusRaw: String
    let templeSect: String
    let enshrinedDeities: [String]
    let pilgrimageMemberships: [PlacePilgrimageMembership]
    let updatedAt: Date

    var isClosed: Bool { operationalStatusRaw == PlaceOperationalStatus.closed.rawValue }
}

enum PublicPlaceCatalogSearch {
    static func suggestions(
        for query: String,
        in entries: [PublicPlaceCatalogEntry],
        excludingSourceMarkers: Set<String> = [],
        includesClosed: Bool,
        limit: Int = 4
    ) -> [PublicPlaceCatalogEntry] {
        let normalizedQuery = normalizedPlaceText(query)
        guard !normalizedQuery.isEmpty, limit > 0 else { return [] }
        return entries.lazy
            .filter { includesClosed || !$0.isClosed }
            .filter { !excludingSourceMarkers.contains(PublicPlaceCatalogImporter.sourceMarker(for: $0.id)) }
            .filter { entry in
                normalizedPlaceText(entry.officialName).contains(normalizedQuery)
                    || normalizedPlaceText(entry.reading).contains(normalizedQuery)
                    || entry.aliases.contains { normalizedPlaceText($0).contains(normalizedQuery) }
                    || normalizedPlaceText(entry.address).contains(normalizedQuery)
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct PublicPlaceCatalogCache: Codable, Sendable {
    static let schemaVersion = 1

    var schemaVersion: Int = Self.schemaVersion
    var lastSyncedAt: Date?
    var entries: [PublicPlaceCatalogEntry] = []

    mutating func merge(_ changes: [PublicPlaceCatalogChange]) {
        var values = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for change in changes {
            if change.isDeleted || !change.isPublished {
                values.removeValue(forKey: change.id)
            } else if let entry = change.entry {
                values[entry.id] = entry
            }
        }
        entries = values.values.sorted {
            if $0.prefecture != $1.prefecture { return $0.prefecture < $1.prefecture }
            return $0.officialName.localizedStandardCompare($1.officialName) == .orderedAscending
        }
        if let newest = changes.map(\.updatedAt).max() {
            lastSyncedAt = max(lastSyncedAt ?? .distantPast, newest)
        }
    }
}

struct PublicPlaceCatalogChange: Sendable {
    let id: String
    let isPublished: Bool
    let isDeleted: Bool
    let updatedAt: Date
    let entry: PublicPlaceCatalogEntry?
}

enum PublicPlaceCatalogError: LocalizedError {
    case invalidRecord(String)

    var errorDescription: String? {
        switch self {
        case let .invalidRecord(recordName):
            "公開場所カタログに必須項目がないレコードがあります（\(recordName)）。"
        }
    }
}

enum PublicPlaceCatalogImporter {
    static func sourceMarker(for id: String) -> String {
        "favoreco.public-place-catalog:\(id)"
    }

    static func matchingPlace(
        for entry: PublicPlaceCatalogEntry,
        in places: [PlaceMaster]
    ) -> PlaceMaster? {
        let marker = sourceMarker(for: entry.id)
        let normalizedName = normalizedPlaceText(entry.officialName)
        let normalizedAddress = normalizedPlaceText(entry.address)
        return places.first { place in
            guard !place.isArchived else { return false }
            if place.sourceSnapshotRaw == marker { return true }
            guard normalizedPlaceText(place.name) == normalizedName else { return false }
            return normalizedAddress.isEmpty || normalizedPlaceText(place.address) == normalizedAddress
        }
    }

    @MainActor
    static func importEntry(
        _ entry: PublicPlaceCatalogEntry,
        existingPlaces: [PlaceMaster],
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> PlaceMaster {
        if let existing = matchingPlace(for: entry, in: existingPlaces) {
            return existing
        }
        let place = makePlaceMaster(from: entry, now: now)
        modelContext.insert(place)
        do {
            try modelContext.save()
            return place
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func makePlaceMaster(from entry: PublicPlaceCatalogEntry, now: Date = Date()) -> PlaceMaster {
        var memoParts: [String] = []
        if !entry.templeSect.isEmpty { memoParts.append("宗派: \(entry.templeSect)") }
        if !entry.enshrinedDeities.isEmpty {
            memoParts.append("御祭神: \(entry.enshrinedDeities.joined(separator: "、"))")
        }
        return PlaceMaster(
            name: entry.officialName,
            reading: entry.reading,
            aliasesRaw: entry.aliases.joined(separator: ","),
            placeTagsRaw: entry.typeKeys.joined(separator: ","),
            prefecture: entry.prefecture,
            address: entry.address,
            latitude: entry.latitude,
            longitude: entry.longitude,
            officialURL: entry.officialURL,
            memo: memoParts.joined(separator: "\n"),
            sourceSnapshotRaw: sourceMarker(for: entry.id),
            pilgrimageMembershipsRaw: PlacePilgrimageMembership.encode(entry.pilgrimageMemberships),
            operationalStatusRaw: entry.operationalStatusRaw,
            normalizedName: normalizedPlaceText(entry.officialName),
            normalizedAddress: normalizedPlaceText(entry.address),
            createdAt: now,
            updatedAt: now
        )
    }
}

enum PublicPlaceCatalogSyncState: Equatable {
    case idle
    case loadingCache
    case syncing
    case ready(lastSyncedAt: Date?)
    case failed(message: String, hasCache: Bool)
}

@MainActor
final class PublicPlaceCatalogStore: ObservableObject {
    static let shared = PublicPlaceCatalogStore()

    @Published private(set) var entries: [PublicPlaceCatalogEntry] = []
    @Published private(set) var state: PublicPlaceCatalogSyncState = .idle

    private let repository: PublicPlaceCatalogRepository
    private var hasPrepared = false

    init(repository: PublicPlaceCatalogRepository = PublicPlaceCatalogRepository()) {
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

actor PublicPlaceCatalogRepository {
    private static let recordType = "PublicPlace"
    private let database: CKDatabase
    private let fileURL: URL
    private var memoryCache: PublicPlaceCatalogCache?

    init(
        database: CKDatabase = CKContainer.default().publicCloudDatabase,
        fileURL: URL? = nil
    ) {
        self.database = database
        self.fileURL = fileURL ?? Self.defaultCacheURL()
    }

    func loadCache() -> PublicPlaceCatalogCache {
        if let memoryCache { return memoryCache }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.catalogDecoder.decode(PublicPlaceCatalogCache.self, from: data),
              decoded.schemaVersion == PublicPlaceCatalogCache.schemaVersion else {
            let empty = PublicPlaceCatalogCache()
            memoryCache = empty
            return empty
        }
        memoryCache = decoded
        return decoded
    }

    func synchronize() async throws -> PublicPlaceCatalogCache {
        var cache = loadCache()
        // One-second overlap prevents records sharing the last cursor timestamp from being skipped.
        let cursorDate = cache.lastSyncedAt?.addingTimeInterval(-1)
        let predicate = cursorDate.map { NSPredicate(format: "updatedAt > %@", $0 as NSDate) }
            ?? NSPredicate(value: true)
        let records = try await fetchAllRecords(matching: predicate)
        let changes = try records.map { try Self.change(from: $0) }
        cache.merge(changes)
        try persist(cache)
        memoryCache = cache
        return cache
    }

    private func fetchAllRecords(matching predicate: NSPredicate) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var nextCursor: CKQueryOperation.Cursor?
        repeat {
            let page = try await fetchPage(predicate: predicate, cursor: nextCursor)
            records.append(contentsOf: page.records)
            nextCursor = page.cursor
        } while nextCursor != nil
        return records
    }

    private func fetchPage(
        predicate: NSPredicate,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation = cursor.map(CKQueryOperation.init(cursor:))
                ?? CKQueryOperation(query: CKQuery(recordType: Self.recordType, predicate: predicate))
            operation.resultsLimit = 300
            let lock = NSLock()
            var pageRecords: [CKRecord] = []
            var firstRecordError: Error?
            operation.recordMatchedBlock = { _, result in
                switch result {
                case let .success(record):
                    lock.lock()
                    pageRecords.append(record)
                    lock.unlock()
                case let .failure(error):
                    lock.lock()
                    if firstRecordError == nil { firstRecordError = error }
                    lock.unlock()
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case let .success(cursor):
                    lock.lock()
                    let resolved = pageRecords
                    let recordError = firstRecordError
                    lock.unlock()
                    if let recordError {
                        continuation.resume(throwing: recordError)
                    } else {
                        continuation.resume(returning: (resolved, cursor))
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func persist(_ cache: PublicPlaceCatalogCache) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.catalogEncoder.encode(cache)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultCacheURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("PublicPlaceCatalog", isDirectory: true)
            .appendingPathComponent("catalog-v1.json")
    }

    private static func change(from record: CKRecord) throws -> PublicPlaceCatalogChange {
        let id = string(record, "placeID", fallback: record.recordID.recordName)
        guard !id.isEmpty else { throw PublicPlaceCatalogError.invalidRecord(record.recordID.recordName) }
        let updatedAt = (record["updatedAt"] as? Date) ?? record.modificationDate ?? .distantPast
        let isPublished = (record["isPublished"] as? NSNumber)?.boolValue ?? true
        let isDeleted = (record["isDeleted"] as? NSNumber)?.boolValue ?? false
        let entry: PublicPlaceCatalogEntry?
        if isPublished && !isDeleted {
            let name = string(record, "officialName")
            let prefecture = string(record, "prefecture")
            guard !name.isEmpty, JapanPrefecture.all.contains(prefecture) else {
                throw PublicPlaceCatalogError.invalidRecord(record.recordID.recordName)
            }
            entry = PublicPlaceCatalogEntry(
                id: id,
                catalogID: string(record, "catalogID"),
                parentPlaceID: string(record, "parentPlaceID"),
                typeKeys: strings(record, "typeKeys"),
                officialName: name,
                reading: string(record, "reading"),
                aliases: strings(record, "aliases"),
                prefecture: prefecture,
                municipality: string(record, "municipality"),
                address: string(record, "address"),
                latitude: (record["latitude"] as? NSNumber)?.doubleValue ?? 0,
                longitude: (record["longitude"] as? NSNumber)?.doubleValue ?? 0,
                officialURL: string(record, "officialURL"),
                capacity: (record["capacity"] as? NSNumber)?.intValue,
                operationalStatusRaw: string(record, "operationalStatus", fallback: "open"),
                templeSect: string(record, "templeSect"),
                enshrinedDeities: strings(record, "enshrinedDeities"),
                pilgrimageMemberships: pilgrimageMemberships(record),
                updatedAt: updatedAt
            )
        } else {
            entry = nil
        }
        return PublicPlaceCatalogChange(
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

    private static func pilgrimageMemberships(_ record: CKRecord) -> [PlacePilgrimageMembership] {
        guard let raw = record["pilgrimageMembershipsJSON"] as? String else { return [] }
        return PlacePilgrimageMembership.decode(raw)
    }
}

private extension JSONDecoder {
    static var catalogDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var catalogEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
