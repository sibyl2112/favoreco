//
//  VisitUnitFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct VisitUnitFields: Codable {
    var ocrText: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []

    init(ocrText: String = "", advancedEntries: [AdvancedFieldEntry] = []) {
        self.ocrText = ocrText
        self.advancedEntries = advancedEntries
    }

    init(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(VisitUnitFields.self, from: data) else {
            self.init()
            return
        }
        self = decoded
    }

    var encodedRawValue: String {
        guard !ocrText.isEmpty || !advancedEntries.isEmpty,
              let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

struct AdvancedFieldEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = ""
    var value: String = ""

    var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedLabel.isEmpty && trimmedValue.isEmpty
    }

    var normalized: AdvancedFieldEntry {
        AdvancedFieldEntry(id: id, label: trimmedLabel, value: trimmedValue)
    }
}
