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

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
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
    var eventPeriodStartsAt: Date?
    var eventPeriodEndsAt: Date?
    var eventVenues: [EventVenueEntry] = []
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
        eventPeriodStartsAt: Date? = nil,
        eventPeriodEndsAt: Date? = nil,
        eventVenues: [EventVenueEntry] = [],
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
        self.eventPeriodStartsAt = eventPeriodStartsAt
        self.eventPeriodEndsAt = eventPeriodEndsAt
        self.eventVenues = eventVenues
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
        case eventPeriodStartsAt
        case eventPeriodEndsAt
        case eventVenues
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
        eventPeriodStartsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodStartsAt)
        eventPeriodEndsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodEndsAt)
        eventVenues = try container.decodeIfPresent([EventVenueEntry].self, forKey: .eventVenues) ?? []
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
                || eventPeriodStartsAt != nil
                || eventPeriodEndsAt != nil
                || !eventVenues.isEmpty
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
                .init(key: "theaterMoonlitAtelier", title: "月夜のアトリエ", resourceName: "theater-hero-fictional-atelier"),
                .init(key: "theaterNightTrain", title: "夜行列車", resourceName: "theater-hero-fictional-night-train"),
                .init(key: "theaterWinterGarden", title: "冬の庭園", resourceName: "theater-hero-fictional-winter-garden"),
            ]
        case "movie":
            [
                .init(key: "movieCinema", title: "映画館", resourceName: "movie-hero-cinema-v2"),
                .init(key: "movieBrightLobby", title: "明るいロビー", resourceName: "movie-hero-bright-lobby"),
                .init(key: "movieNoir", title: "ノワール", resourceName: "movie-hero-fictional-noir"),
                .init(key: "movieSciFi", title: "SF", resourceName: "movie-hero-fictional-scifi"),
            ]
        case "book":
            [
                .init(key: "bookLibrary", title: "書斎", resourceName: "book-hero-library"),
                .init(key: "bookBrightRoom", title: "陽だまり", resourceName: "book-hero-bright-reading-room"),
                .init(key: "bookNightShop", title: "夜の書店", resourceName: "book-hero-night-bookshop"),
                .init(key: "bookReadingTrain", title: "読書列車", resourceName: "book-hero-reading-train"),
            ]
        case "museum":
            [
                .init(key: "museumGallery", title: "美術館", resourceName: "museum-hero-gallery-v2"),
                .init(key: "museumWhiteGallery", title: "白いギャラリー", resourceName: "museum-hero-bright-white-gallery"),
                .init(key: "museumLight", title: "光の展示", resourceName: "museum-hero-immersive-light"),
                .init(key: "museumClassic", title: "クラシック", resourceName: "museum-hero-classic-hall"),
            ]
        case "live":
            [
                .init(key: "liveHouse", title: "ライブハウス", resourceName: "live-hero-livehouse"),
                .init(key: "liveFestival", title: "昼フェス", resourceName: "live-hero-bright-festival"),
                .init(key: "liveArena", title: "アリーナ", resourceName: "live-hero-arena"),
                .init(key: "liveAcoustic", title: "アコースティック", resourceName: "live-hero-bright-acoustic"),
            ]
        case "sake":
            [
                .init(key: "sakeBar", title: "バー", resourceName: "sake-hero-tasting-bar"),
                .init(key: "sakeBrewery", title: "酒蔵", resourceName: "sake-hero-bright-brewery"),
                .init(key: "sakeWine", title: "ワインセラー", resourceName: "sake-hero-wine-cellar"),
                .init(key: "sakeCraft", title: "クラフト", resourceName: "sake-hero-bright-taproom"),
            ]
        case "theme_park":
            [
                .init(key: "themeParkAvenue", title: "パーク", resourceName: "theme_park-hero-avenue"),
                .init(key: "themeParkCarousel", title: "メリーゴーラウンド", resourceName: "theme_park-hero-bright-carousel"),
                .init(key: "themeParkNight", title: "ナイトパーク", resourceName: "theme_park-hero-night"),
                .init(key: "themeParkWaterfront", title: "水辺", resourceName: "theme_park-hero-bright-waterfront"),
            ]
        case "nature_living":
            [
                .init(key: "natureSunroom", title: "サンルーム", resourceName: "nature_living-hero-bright-sunroom"),
                .init(key: "natureGarden", title: "花の庭", resourceName: "nature_living-hero-bright-garden"),
                .init(key: "natureForest", title: "森", resourceName: "nature_living-hero-forest"),
                .init(key: "natureCoast", title: "海辺", resourceName: "nature_living-hero-bright-coast"),
            ]
        case "outing_facility":
            [
                .init(key: "outingAtrium", title: "施設", resourceName: "outing_facility-hero-bright-atrium"),
                .init(key: "outingZoo", title: "動物園", resourceName: "outing_facility-hero-bright-zoo"),
                .init(key: "outingAquarium", title: "水族館", resourceName: "outing_facility-hero-aquarium"),
                .init(key: "outingGreenhouse", title: "温室", resourceName: "outing_facility-hero-bright-greenhouse"),
            ]
        case "goshuin":
            [
                .init(key: "goshuinShrine", title: "神社", resourceName: "goshuin-hero-bright-shrine"),
                .init(key: "goshuinTemple", title: "寺院", resourceName: "goshuin-hero-temple"),
                .init(key: "goshuinMoss", title: "苔庭", resourceName: "goshuin-hero-moss-garden"),
                .init(key: "goshuinLanterns", title: "灯籠", resourceName: "goshuin-hero-lanterns"),
            ]
        case "random_goods":
            [
                .init(key: "goodsShelf", title: "コレクション棚", resourceName: "random_goods-hero-collector-shelf"),
                .init(key: "goodsCapsule", title: "カプセルトイ", resourceName: "random_goods-hero-bright-capsule"),
                .init(key: "goodsAcrylic", title: "アクスタ", resourceName: "random_goods-hero-bright-acrylic"),
                .init(key: "goodsCards", title: "カード", resourceName: "random_goods-hero-card-binder"),
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
