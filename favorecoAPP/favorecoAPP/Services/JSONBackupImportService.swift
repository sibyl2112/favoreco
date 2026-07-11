//
//  JSONBackupImportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import Foundation

enum JSONBackupImportService {
    static func inspect(data: Data) throws -> JSONBackupPreview {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: FavorecoBackupEnvelope
        do {
            envelope = try decoder.decode(FavorecoBackupEnvelope.self, from: data)
        } catch {
            throw JSONBackupImportError.invalidJSON(error.localizedDescription)
        }

        guard envelope.appName.lowercased() == "favoreco" else {
            throw JSONBackupImportError.unsupportedApp(envelope.appName)
        }
        guard envelope.schemaVersion > 0 else {
            throw JSONBackupImportError.invalidSchemaVersion(envelope.schemaVersion)
        }
        guard envelope.schemaVersion <= JSONBackupExportService.schemaVersion else {
            throw JSONBackupImportError.newerSchemaVersion(
                fileVersion: envelope.schemaVersion,
                supportedVersion: JSONBackupExportService.schemaVersion
            )
        }

        return JSONBackupPreview(envelope: envelope)
    }
}

struct JSONBackupPreview {
    let schemaVersion: Int
    let exportedAt: Date
    let note: String
    let categoryCount: Int
    let eventCount: Int
    let visitCount: Int
    let inboxCount: Int
    let photoMetadataCount: Int
    let socialAccountCount: Int
    let personCount: Int
    let personLinkCount: Int
    let placeCount: Int
    let planCount: Int
    let ticketAccountCount: Int
    let ticketAttemptCount: Int

    init(envelope: FavorecoBackupEnvelope) {
        schemaVersion = envelope.schemaVersion
        exportedAt = envelope.exportedAt
        note = envelope.note
        categoryCount = envelope.categories.count
        eventCount = envelope.events.count
        visitCount = envelope.visits.count
        inboxCount = envelope.inboxItems.count
        photoMetadataCount = envelope.photos.count
        socialAccountCount = envelope.socialAccounts.count
        personCount = envelope.people.count
        personLinkCount = envelope.personLinks.count
        placeCount = envelope.places.count
        planCount = envelope.plans.count
        ticketAccountCount = envelope.ticketAccounts.count
        ticketAttemptCount = envelope.ticketAttempts.count
    }

    var totalModelCount: Int {
        categoryCount
            + eventCount
            + visitCount
            + inboxCount
            + socialAccountCount
            + personCount
            + personLinkCount
            + placeCount
            + planCount
            + ticketAccountCount
            + ticketAttemptCount
    }
}

enum JSONBackupImportError: LocalizedError {
    case invalidJSON(String)
    case unsupportedApp(String)
    case invalidSchemaVersion(Int)
    case newerSchemaVersion(fileVersion: Int, supportedVersion: Int)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "FavorecoのバックアップJSONとして読み取れませんでした。"
        case .unsupportedApp(let appName):
            "別のアプリ用ファイルです（\(appName.isEmpty ? "アプリ名なし" : appName)）。"
        case .invalidSchemaVersion(let version):
            "バックアップ形式のバージョンが不正です（\(version)）。"
        case let .newerSchemaVersion(fileVersion, supportedVersion):
            "このバックアップは新しい形式です（ファイル: \(fileVersion)、対応: \(supportedVersion)）。アプリを更新してください。"
        }
    }

    var failureReason: String? {
        if case .invalidJSON(let detail) = self {
            return detail
        }
        return nil
    }
}
