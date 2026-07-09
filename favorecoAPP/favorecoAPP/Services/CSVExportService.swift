//
//  CSVExportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CSVExportService {
    nonisolated static func makeVisitsCSV(visits: [Visit]) -> String {
        let header = [
            "visit_id",
            "event_id",
            "date",
            "category",
            "title",
            "series",
            "venue",
            "rating",
            "status",
            "seat",
            "amount",
            "official_url",
            "tags",
            "companions",
            "note",
            "created_at",
            "updated_at"
        ]

        let rows = visits
            .sorted { $0.visitedAt > $1.visitedAt }
            .map { visit -> [String] in
                [
                    visit.id.uuidString,
                    visit.event?.id.uuidString ?? "",
                    dateOnlyString(visit.visitedAt),
                    visit.event?.category?.name ?? "",
                    visit.event?.title ?? "",
                    visit.event?.seriesName ?? "",
                    visit.venueNameSnapshot,
                    visit.overallRating == 0 ? "" : String(format: "%.1f", visit.overallRating),
                    visit.outcomeKey,
                    visit.seatText,
                    NSDecimalNumber(decimal: visit.amount).stringValue,
                    visit.event?.officialURL ?? "",
                    visit.tagNamesRaw,
                    visit.companionNamesRaw,
                    visit.note,
                    timestampString(visit.createdAt),
                    timestampString(visit.updatedAt)
                ]
            }

        return ([header] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    nonisolated private static func escape(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\r\n", with: "\n")
        let needsQuoting = normalized.contains(",") || normalized.contains("\"") || normalized.contains("\n")
        let escaped = normalized.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuoting ? "\"\(escaped)\"" : escaped
    }

    nonisolated private static func dateOnlyString(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    nonisolated private static func timestampString(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted))
    }
}

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            self.text = ""
            return
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
