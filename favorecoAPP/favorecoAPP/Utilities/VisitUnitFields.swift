//
//  VisitUnitFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct EventVenueEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var performanceLabel: String?
    var startsAt: Date?
    var endsAt: Date?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPerformanceLabel: String {
        (performanceLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedName.isEmpty && trimmedAddress.isEmpty
    }
}

struct VisitUnitFields: Codable {
    var ocrText: String = ""
    var styleNames: [String] = []
    var socialLinks: [String] = []
    var eventSubtitle: String = ""
    var eventCreditsText: String = ""
    var eventPerformanceTypeCustomName: String = ""
    var eventPeriodStartsAt: Date?
    var eventPeriodEndsAt: Date?
    var eventVenues: [EventVenueEntry] = []
    var excludedEventCastLinkIDs: [UUID] = []
    var hasVisitCastSnapshot: Bool = false
    var eyecatchAspectRatioKey: String = ""
    var heroBackgroundPath: String = ""
    var heroBackgroundPresetKey: String = ""
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
        eventSubtitle: String = "",
        eventCreditsText: String = "",
        eventPerformanceTypeCustomName: String = "",
        eventPeriodStartsAt: Date? = nil,
        eventPeriodEndsAt: Date? = nil,
        eventVenues: [EventVenueEntry] = [],
        excludedEventCastLinkIDs: [UUID] = [],
        hasVisitCastSnapshot: Bool = false,
        eyecatchAspectRatioKey: String = "",
        heroBackgroundPath: String = "",
        heroBackgroundPresetKey: String = "",
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
        self.eventSubtitle = eventSubtitle
        self.eventCreditsText = eventCreditsText
        self.eventPerformanceTypeCustomName = eventPerformanceTypeCustomName
        self.eventPeriodStartsAt = eventPeriodStartsAt
        self.eventPeriodEndsAt = eventPeriodEndsAt
        self.eventVenues = eventVenues
        self.excludedEventCastLinkIDs = excludedEventCastLinkIDs
        self.hasVisitCastSnapshot = hasVisitCastSnapshot
        self.eyecatchAspectRatioKey = eyecatchAspectRatioKey
        self.heroBackgroundPath = heroBackgroundPath
        self.heroBackgroundPresetKey = heroBackgroundPresetKey
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
        case eventSubtitle
        case eventCreditsText
        case eventPerformanceTypeCustomName
        case eventPeriodStartsAt
        case eventPeriodEndsAt
        case eventVenues
        case excludedEventCastLinkIDs
        case hasVisitCastSnapshot
        case eyecatchAspectRatioKey
        case heroBackgroundPath
        case heroBackgroundPresetKey
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
        eventSubtitle = try container.decodeIfPresent(String.self, forKey: .eventSubtitle) ?? ""
        eventCreditsText = try container.decodeIfPresent(String.self, forKey: .eventCreditsText) ?? ""
        eventPerformanceTypeCustomName = try container.decodeIfPresent(String.self, forKey: .eventPerformanceTypeCustomName) ?? ""
        eventPeriodStartsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodStartsAt)
        eventPeriodEndsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodEndsAt)
        eventVenues = try container.decodeIfPresent([EventVenueEntry].self, forKey: .eventVenues) ?? []
        excludedEventCastLinkIDs = try container.decodeIfPresent([UUID].self, forKey: .excludedEventCastLinkIDs) ?? []
        hasVisitCastSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasVisitCastSnapshot) ?? false
        eyecatchAspectRatioKey = try container.decodeIfPresent(String.self, forKey: .eyecatchAspectRatioKey) ?? ""
        heroBackgroundPath = try container.decodeIfPresent(String.self, forKey: .heroBackgroundPath) ?? ""
        heroBackgroundPresetKey = try container.decodeIfPresent(String.self, forKey: .heroBackgroundPresetKey) ?? ""
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
                || !eventSubtitle.isEmpty
                || !eventCreditsText.isEmpty
                || !eventPerformanceTypeCustomName.isEmpty
                || eventPeriodStartsAt != nil
                || eventPeriodEndsAt != nil
                || !eventVenues.isEmpty
                || !excludedEventCastLinkIDs.isEmpty
                || hasVisitCastSnapshot
                || !eyecatchAspectRatioKey.isEmpty
                || !heroBackgroundPath.isEmpty
                || !heroBackgroundPresetKey.isEmpty
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

struct HeroBackgroundPreset: Identifiable, Equatable {
    let key: String
    let title: String
    let resourceName: String

    var id: String { key }

    static func presets(for categoryKey: String?) -> [HeroBackgroundPreset] {
        switch categoryKey {
        case "theater":
            [
                .init(key: "theaterVenue", title: "劇場", resourceName: "theater-hero-venue-v2"),
                .init(key: "theaterNightTrain", title: "夜行列車", resourceName: "theater-hero-fictional-night-train"),
                .init(key: "theaterWinterGarden", title: "冬の庭園", resourceName: "theater-hero-fictional-winter-garden"),
            ]
        case "movie":
            [
                .init(key: "movieDefault", title: "映画", resourceName: "movie-hero-default"),
            ]
        case "book":
            [
                .init(key: "bookDefault", title: "書籍", resourceName: "book-hero-default"),
            ]
        case "museum":
            [
                .init(key: "museumDefault", title: "ミュージアム", resourceName: "museum-hero-default"),
            ]
        case "live":
            [
                .init(key: "liveDefault", title: "ライブ", resourceName: "live-hero-default"),
            ]
        case "sake":
            [
                .init(key: "sakeDefault", title: "お酒", resourceName: "sake-hero-default"),
            ]
        case "theme_park":
            [
                .init(key: "themeParkDefault", title: "テーマパーク", resourceName: "theme_park-hero-default"),
            ]
        case "nature_living":
            [
                .init(key: "natureDefault", title: "自然・いきもの", resourceName: "nature_living-hero-default"),
            ]
        case "outing_facility":
            [
                .init(key: "outingDefault", title: "おでかけ施設", resourceName: "outing_facility-hero-default"),
            ]
        case "goshuin":
            [
                .init(key: "goshuinShrine", title: "神社", resourceName: "goshuin-hero-bright-shrine"),
                .init(key: "goshuinTemple", title: "寺院", resourceName: "goshuin-hero-temple"),
                .init(key: "goshuinMoss", title: "苔庭", resourceName: "goshuin-hero-moss-garden"),
            ]
        case "random_goods":
            [
                .init(key: "goodsDefault", title: "コレクション", resourceName: "random_goods-hero-default"),
            ]
        default:
            []
        }
    }

    static func resolved(categoryKey: String?, storedKey: String) -> HeroBackgroundPreset? {
        let options = presets(for: categoryKey)
        return options.first(where: { $0.key == storedKey }) ?? options.first
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
