//
//  VisitUnitFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct VisitUnitFields: Codable {
    var ocrText: String = ""

    init(ocrText: String = "") {
        self.ocrText = ocrText
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
        guard !ocrText.isEmpty,
              let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}
