//
//  CSVImportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData

enum CSVImportService {
    nonisolated static func inspect(data: Data) throws -> CSVImportPreview {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidEncoding
        }

        let table = try parse(text: text)
        guard let rawHeader = table.first else {
            throw CSVImportError.emptyFile
        }

        let headers = rawHeader.map(normalizeHeader)
        guard !headers.contains("") else {
            throw CSVImportError.emptyHeader
        }
        guard Set(headers).count == headers.count else {
            throw CSVImportError.duplicateHeader
        }
        for required in ["date", "title"] where !headers.contains(required) {
            throw CSVImportError.missingRequiredColumn(required)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false

        let rows = table.dropFirst().enumerated().compactMap { offset, values -> CSVImportRow? in
            guard values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }

            var fields: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                fields[header] = index < values.count
                    ? values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""
            }

            let dateText = fields["date"] ?? ""
            let title = fields["title"] ?? ""
            var issues: [String] = []
            if parseDate(dateText, formatter: dateFormatter) == nil {
                issues.append("dateはYYYY-MM-DDで入力してください")
            }
            if title.isEmpty {
                issues.append("titleが空です")
            }
            if values.count > headers.count {
                issues.append("ヘッダーより列が多い行です")
            }
            for idColumn in ["visit_id", "event_id"] {
                let value = fields[idColumn] ?? ""
                if !value.isEmpty, UUID(uuidString: value) == nil {
                    issues.append("\(idColumn)がUUID形式ではありません")
                }
            }
            if let ratingText = fields["rating"], !ratingText.isEmpty,
               (Double(ratingText) == nil || !(0...5).contains(Double(ratingText) ?? -1)) {
                issues.append("ratingは0〜5の数値で入力してください")
            }
            if let amountText = fields["amount"], !amountText.isEmpty,
               Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) == nil {
                issues.append("amountが数値ではありません")
            }

            return CSVImportRow(
                lineNumber: offset + 2,
                dateText: dateText,
                category: fields["category"] ?? "",
                title: title,
                venue: fields["venue"] ?? "",
                note: fields["note"] ?? fields["memo"] ?? "",
                fields: fields,
                issues: issues
            )
        }

        guard !rows.isEmpty else {
            throw CSVImportError.noDataRows
        }
        return CSVImportPreview(headers: headers, rows: rows)
    }

    @MainActor
    static func restore(
        preview: CSVImportPreview,
        defaultCategory: RecordCategory,
        in context: ModelContext
    ) throws -> CSVImportRestoreResult {
        let categories = try context.fetch(FetchDescriptor<RecordCategory>())
        let categoryByName = Dictionary(
            grouping: categories,
            by: { normalized($0.name) }
        ).compactMapValues(\.first)
        var visitsByID = Dictionary(
            grouping: try context.fetch(FetchDescriptor<Visit>()),
            by: \.id
        ).compactMapValues(\.first)
        var eventsByID = Dictionary(
            grouping: try context.fetch(FetchDescriptor<ExperienceEvent>()),
            by: \.id
        ).compactMapValues(\.first)
        var duplicateKeys = Set(visitsByID.values.map(duplicateKey))
        let formatter = makeDateFormatter()
        let now = Date()

        var result = CSVImportRestoreResult()

        for row in preview.rows {
            guard row.isValid, let visitedAt = parseDate(row.dateText, formatter: formatter) else {
                result.invalidRowCount += 1
                continue
            }

            let category: RecordCategory
            if row.category.isEmpty {
                category = defaultCategory
            } else if let matched = categoryByName[normalized(row.category)], !matched.isArchived {
                category = matched
            } else {
                result.unknownCategoryCount += 1
                continue
            }

            let visitID = row.uuid(for: "visit_id")
            let existingVisit = visitID.flatMap { visitsByID[$0] }
            let key = duplicateKey(date: visitedAt, title: row.title, venue: row.venue)
            if existingVisit == nil, duplicateKeys.contains(key) {
                result.duplicateCount += 1
                continue
            }

            let eventID = row.uuid(for: "event_id")
            let event: ExperienceEvent
            if let matched = eventID.flatMap({ eventsByID[$0] }) ?? existingVisit?.event {
                event = matched
            } else {
                let newEvent = ExperienceEvent(
                    id: eventID ?? UUID(),
                    title: row.title,
                    seriesName: row.value("series"),
                    officialURL: row.value("official_url"),
                    memo: row.note,
                    createdAt: row.timestamp("created_at") ?? now,
                    updatedAt: row.timestamp("updated_at") ?? now,
                    category: category
                )
                context.insert(newEvent)
                eventsByID[newEvent.id] = newEvent
                event = newEvent
                result.insertedEventCount += 1
            }

            if eventID != nil || existingVisit?.event === event || event.title.isEmpty {
                event.title = row.title
                event.seriesName = row.value("series")
                event.officialURL = row.value("official_url")
                event.memo = row.note
                event.category = category
                event.updatedAt = row.timestamp("updated_at") ?? now
            }

            let visit: Visit
            if let existingVisit {
                duplicateKeys.remove(duplicateKey(existingVisit))
                visit = existingVisit
                result.updatedVisitCount += 1
            } else {
                let newVisit = Visit(id: visitID ?? UUID())
                context.insert(newVisit)
                visitsByID[newVisit.id] = newVisit
                visit = newVisit
                result.insertedVisitCount += 1
            }

            visit.visitedAt = visitedAt
            visit.endedAt = visitedAt
            visit.venueNameSnapshot = row.venue
            visit.overallRating = Double(row.value("rating")) ?? 0
            visit.outcomeKey = row.value("status")
            visit.seatText = row.value("seat")
            visit.note = row.note
            visit.tagNamesRaw = row.value("tags")
            visit.companionNamesRaw = row.value("companions")
            visit.amount = Decimal(
                string: row.value("amount"),
                locale: Locale(identifier: "en_US_POSIX")
            ) ?? 0
            visit.createdAt = row.timestamp("created_at") ?? visit.createdAt
            visit.updatedAt = row.timestamp("updated_at") ?? now
            visit.event = event
            duplicateKeys.insert(key)
        }

        try context.save()
        return result
    }

    nonisolated private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    nonisolated private static func parseDate(_ value: String, formatter: DateFormatter) -> Date? {
        guard value.count == 10 else { return nil }
        return formatter.date(from: value)
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ja_JP")
        )
    }

    @MainActor
    private static func duplicateKey(_ visit: Visit) -> String {
        duplicateKey(
            date: visit.visitedAt,
            title: visit.event?.title ?? "",
            venue: visit.venueNameSnapshot
        )
    }

    nonisolated private static func duplicateKey(date: Date, title: String, venue: String) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "\(day)|\(normalized(title))|\(normalized(venue))"
    }

    nonisolated private static func normalizeHeader(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{feff}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    nonisolated private static func parse(text: String) throws -> [[String]] {
        let scalars = text.unicodeScalars
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]
            let nextIndex = scalars.index(after: index)

            if scalar == "\"" {
                if isQuoted, nextIndex < scalars.endIndex, scalars[nextIndex] == "\"" {
                    field.append("\"")
                    index = scalars.index(after: nextIndex)
                    continue
                }
                isQuoted.toggle()
            } else if scalar == ",", !isQuoted {
                row.append(field)
                field = ""
            } else if (scalar == "\n" || scalar == "\r"), !isQuoted {
                if scalar == "\r", nextIndex < scalars.endIndex, scalars[nextIndex] == "\n" {
                    index = nextIndex
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.unicodeScalars.append(scalar)
            }
            index = scalars.index(after: index)
        }

        guard !isQuoted else {
            throw CSVImportError.unclosedQuote
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

struct CSVImportPreview {
    let headers: [String]
    let rows: [CSVImportRow]

    var validRows: [CSVImportRow] { rows.filter(\.isValid) }
    var invalidRows: [CSVImportRow] { rows.filter { !$0.isValid } }
}

struct CSVImportRow: Identifiable {
    let lineNumber: Int
    let dateText: String
    let category: String
    let title: String
    let venue: String
    let note: String
    let fields: [String: String]
    let issues: [String]

    var id: Int { lineNumber }
    var isValid: Bool { issues.isEmpty }

    func value(_ key: String) -> String { fields[key] ?? "" }
    func uuid(for key: String) -> UUID? { UUID(uuidString: value(key)) }
    func timestamp(_ key: String) -> Date? {
        let value = value(key)
        guard !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

struct CSVImportRestoreResult {
    var insertedVisitCount = 0
    var updatedVisitCount = 0
    var insertedEventCount = 0
    var duplicateCount = 0
    var invalidRowCount = 0
    var unknownCategoryCount = 0
}

enum CSVImportError: LocalizedError {
    case invalidEncoding
    case emptyFile
    case emptyHeader
    case duplicateHeader
    case missingRequiredColumn(String)
    case noDataRows
    case unclosedQuote

    var errorDescription: String? {
        switch self {
        case .invalidEncoding: "UTF-8のCSVとして読み取れませんでした。"
        case .emptyFile: "CSVが空です。"
        case .emptyHeader: "列名が空の列があります。"
        case .duplicateHeader: "同じ列名が複数あります。"
        case .missingRequiredColumn(let column): "必須列「\(column)」がありません。"
        case .noDataRows: "取り込めるデータ行がありません。"
        case .unclosedQuote: "引用符（\"）が閉じられていません。"
        }
    }
}
