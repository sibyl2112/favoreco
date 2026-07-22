//
//  VisitUnitFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct VisitUnitFields: Codable {
    var ocrText: String = ""
    var styleNames: [String] = []
    var socialLinks: [String] = []
    var eyecatchAspectRatioKey: String = ""
    var goshuinBookSizeKey: String = ""
    var weatherSymbolName: String = ""
    var weatherHighCelsius: Double?
    var weatherLowCelsius: Double?
    var weatherFetchedAt: Date?
    var weatherAttributionURL: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []

    init(
        ocrText: String = "",
        styleNames: [String] = [],
        socialLinks: [String] = [],
        eyecatchAspectRatioKey: String = "",
        goshuinBookSizeKey: String = "",
        weatherSymbolName: String = "",
        weatherHighCelsius: Double? = nil,
        weatherLowCelsius: Double? = nil,
        weatherFetchedAt: Date? = nil,
        weatherAttributionURL: String = "",
        advancedEntries: [AdvancedFieldEntry] = []
    ) {
        self.ocrText = ocrText
        self.styleNames = styleNames
        self.socialLinks = socialLinks
        self.eyecatchAspectRatioKey = eyecatchAspectRatioKey
        self.goshuinBookSizeKey = goshuinBookSizeKey
        self.weatherSymbolName = weatherSymbolName
        self.weatherHighCelsius = weatherHighCelsius
        self.weatherLowCelsius = weatherLowCelsius
        self.weatherFetchedAt = weatherFetchedAt
        self.weatherAttributionURL = weatherAttributionURL
        self.advancedEntries = advancedEntries
    }

    private enum CodingKeys: String, CodingKey {
        case ocrText
        case styleNames
        case socialLinks
        case eyecatchAspectRatioKey
        case goshuinBookSizeKey
        case weatherSymbolName
        case weatherHighCelsius
        case weatherLowCelsius
        case weatherFetchedAt
        case weatherAttributionURL
        case advancedEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
        styleNames = try container.decodeIfPresent([String].self, forKey: .styleNames) ?? []
        socialLinks = try container.decodeIfPresent([String].self, forKey: .socialLinks) ?? []
        eyecatchAspectRatioKey = try container.decodeIfPresent(String.self, forKey: .eyecatchAspectRatioKey) ?? ""
        goshuinBookSizeKey = try container.decodeIfPresent(String.self, forKey: .goshuinBookSizeKey) ?? ""
        weatherSymbolName = try container.decodeIfPresent(String.self, forKey: .weatherSymbolName) ?? ""
        weatherHighCelsius = try container.decodeIfPresent(Double.self, forKey: .weatherHighCelsius)
        weatherLowCelsius = try container.decodeIfPresent(Double.self, forKey: .weatherLowCelsius)
        weatherFetchedAt = try container.decodeIfPresent(Date.self, forKey: .weatherFetchedAt)
        weatherAttributionURL = try container.decodeIfPresent(String.self, forKey: .weatherAttributionURL) ?? ""
        advancedEntries = try container.decodeIfPresent([AdvancedFieldEntry].self, forKey: .advancedEntries) ?? []
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
        guard !ocrText.isEmpty
                || !styleNames.isEmpty
                || !socialLinks.isEmpty
                || !eyecatchAspectRatioKey.isEmpty
                || !goshuinBookSizeKey.isEmpty
                || !weatherSymbolName.isEmpty
                || weatherHighCelsius != nil
                || weatherLowCelsius != nil
                || weatherFetchedAt != nil
                || !weatherAttributionURL.isEmpty
                || !advancedEntries.isEmpty,
              let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    mutating func copyWeather(from other: VisitUnitFields) {
        weatherSymbolName = other.weatherSymbolName
        weatherHighCelsius = other.weatherHighCelsius
        weatherLowCelsius = other.weatherLowCelsius
        weatherFetchedAt = other.weatherFetchedAt
        weatherAttributionURL = other.weatherAttributionURL
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
