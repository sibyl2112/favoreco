//
//  CSVImportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import Foundation

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
            if dateFormatter.date(from: dateText) == nil {
                issues.append("dateはYYYY-MM-DDで入力してください")
            }
            if title.isEmpty {
                issues.append("titleが空です")
            }
            if values.count > headers.count {
                issues.append("ヘッダーより列が多い行です")
            }

            return CSVImportRow(
                lineNumber: offset + 2,
                dateText: dateText,
                category: fields["category"] ?? "",
                title: title,
                venue: fields["venue"] ?? "",
                note: fields["note"] ?? fields["memo"] ?? "",
                issues: issues
            )
        }

        guard !rows.isEmpty else {
            throw CSVImportError.noDataRows
        }
        return CSVImportPreview(headers: headers, rows: rows)
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
    let issues: [String]

    var id: Int { lineNumber }
    var isValid: Bool { issues.isEmpty }
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
