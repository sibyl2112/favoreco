//
//  VisitUnitFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

enum ScreenWorkType: String, CaseIterable, Identifiable {
    case movie
    case drama
    case anime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .movie: "映画"
        case .drama: "ドラマ"
        case .anime: "アニメ"
        }
    }

    var supportsSeason: Bool { self != .movie }

    static func resolved(from rawValue: String) -> ScreenWorkType {
        ScreenWorkType(rawValue: rawValue) ?? .movie
    }
}

enum ScreenWorkFilter: String, CaseIterable, Identifiable {
    case all
    case movie
    case drama
    case anime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "すべて"
        case .movie: "映画"
        case .drama: "ドラマ"
        case .anime: "アニメ"
        }
    }

    func includes(_ type: ScreenWorkType) -> Bool {
        self == .all || rawValue == type.rawValue
    }
}

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
    /// 施設そのものではなく、この1回で見た展示・目的を表す短い副題。
    var visitSubtitle: String = ""
    var eventCreditsText: String = ""
    var eventPerformanceTypeCustomName: String = ""
    var eventPeriodStartsAt: Date?
    var eventPeriodEndsAt: Date?
    var eventVenues: [EventVenueEntry] = []
    var excludedEventCastLinkIDs: [UUID] = []
    var hasVisitCastSnapshot: Bool = false
    var screenWorkSeasonNumber: Int = 0
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
    /// 書籍（巻）をシリーズ単位で束ねるための構造化メタデータ。
    var bookSeriesName: String = ""
    var bookVolumeNumber: String = ""
    var bookAuthorName: String = ""
    var bookISBN: String = ""
    /// 書籍記録で終了日を明示したか。nil は旧データ（従来の読了日1日）として扱う。
    var bookReadingHasEndDate: Bool?

    init(
        ocrText: String = "",
        styleNames: [String] = [],
        socialLinks: [String] = [],
        eventSubtitle: String = "",
        visitSubtitle: String = "",
        eventCreditsText: String = "",
        eventPerformanceTypeCustomName: String = "",
        eventPeriodStartsAt: Date? = nil,
        eventPeriodEndsAt: Date? = nil,
        eventVenues: [EventVenueEntry] = [],
        excludedEventCastLinkIDs: [UUID] = [],
        hasVisitCastSnapshot: Bool = false,
        screenWorkSeasonNumber: Int = 0,
        eyecatchAspectRatioKey: String = "",
        heroBackgroundPath: String = "",
        heroBackgroundPresetKey: String = "",
        goshuinBookSizeKey: String = "",
        weatherSymbolName: String = "",
        weatherHighCelsius: Double? = nil,
        weatherLowCelsius: Double? = nil,
        weatherFetchedAt: Date? = nil,
        weatherAttributionURL: String = "",
        advancedEntries: [AdvancedFieldEntry] = [],
        bookSeriesName: String = "",
        bookVolumeNumber: String = "",
        bookAuthorName: String = "",
        bookISBN: String = "",
        bookReadingHasEndDate: Bool? = nil
    ) {
        self.ocrText = ocrText
        self.styleNames = styleNames
        self.socialLinks = socialLinks
        self.eventSubtitle = eventSubtitle
        self.visitSubtitle = visitSubtitle
        self.eventCreditsText = eventCreditsText
        self.eventPerformanceTypeCustomName = eventPerformanceTypeCustomName
        self.eventPeriodStartsAt = eventPeriodStartsAt
        self.eventPeriodEndsAt = eventPeriodEndsAt
        self.eventVenues = eventVenues
        self.excludedEventCastLinkIDs = excludedEventCastLinkIDs
        self.hasVisitCastSnapshot = hasVisitCastSnapshot
        self.screenWorkSeasonNumber = Self.normalizedSeasonNumber(screenWorkSeasonNumber)
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
        self.bookSeriesName = bookSeriesName
        self.bookVolumeNumber = bookVolumeNumber
        self.bookAuthorName = bookAuthorName
        self.bookISBN = bookISBN
        self.bookReadingHasEndDate = bookReadingHasEndDate
    }

    private enum CodingKeys: String, CodingKey {
        case ocrText
        case styleNames
        case socialLinks
        case eventSubtitle
        case visitSubtitle
        case eventCreditsText
        case eventPerformanceTypeCustomName
        case eventPeriodStartsAt
        case eventPeriodEndsAt
        case eventVenues
        case excludedEventCastLinkIDs
        case hasVisitCastSnapshot
        case screenWorkSeasonNumber
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
        case bookSeriesName
        case bookVolumeNumber
        case bookAuthorName
        case bookISBN
        case bookReadingHasEndDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
        styleNames = try container.decodeIfPresent([String].self, forKey: .styleNames) ?? []
        socialLinks = try container.decodeIfPresent([String].self, forKey: .socialLinks) ?? []
        eventSubtitle = try container.decodeIfPresent(String.self, forKey: .eventSubtitle) ?? ""
        visitSubtitle = try container.decodeIfPresent(String.self, forKey: .visitSubtitle) ?? ""
        eventCreditsText = try container.decodeIfPresent(String.self, forKey: .eventCreditsText) ?? ""
        eventPerformanceTypeCustomName = try container.decodeIfPresent(String.self, forKey: .eventPerformanceTypeCustomName) ?? ""
        eventPeriodStartsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodStartsAt)
        eventPeriodEndsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodEndsAt)
        eventVenues = try container.decodeIfPresent([EventVenueEntry].self, forKey: .eventVenues) ?? []
        excludedEventCastLinkIDs = try container.decodeIfPresent([UUID].self, forKey: .excludedEventCastLinkIDs) ?? []
        hasVisitCastSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasVisitCastSnapshot) ?? false
        screenWorkSeasonNumber = Self.normalizedSeasonNumber(
            try container.decodeIfPresent(Int.self, forKey: .screenWorkSeasonNumber) ?? 0
        )
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
        bookSeriesName = try container.decodeIfPresent(String.self, forKey: .bookSeriesName) ?? ""
        bookVolumeNumber = try container.decodeIfPresent(String.self, forKey: .bookVolumeNumber) ?? ""
        bookAuthorName = try container.decodeIfPresent(String.self, forKey: .bookAuthorName) ?? ""
        bookISBN = try container.decodeIfPresent(String.self, forKey: .bookISBN) ?? ""
        bookReadingHasEndDate = try container.decodeIfPresent(Bool.self, forKey: .bookReadingHasEndDate)
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
                || !visitSubtitle.isEmpty
                || !eventCreditsText.isEmpty
                || !eventPerformanceTypeCustomName.isEmpty
                || eventPeriodStartsAt != nil
                || eventPeriodEndsAt != nil
                || !eventVenues.isEmpty
                || !excludedEventCastLinkIDs.isEmpty
                || hasVisitCastSnapshot
                || screenWorkSeasonNumber > 0
                || !eyecatchAspectRatioKey.isEmpty
                || !heroBackgroundPath.isEmpty
                || !heroBackgroundPresetKey.isEmpty
                || !goshuinBookSizeKey.isEmpty
                || !weatherSymbolName.isEmpty
                || weatherHighCelsius != nil
                || weatherLowCelsius != nil
                || weatherFetchedAt != nil
                || !weatherAttributionURL.isEmpty
                || !advancedEntries.isEmpty
                || !bookSeriesName.isEmpty
                || !bookVolumeNumber.isEmpty
                || !bookAuthorName.isEmpty
                || !bookISBN.isEmpty
                || bookReadingHasEndDate != nil,
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

    static func normalizedSeasonNumber(_ value: Int) -> Int {
        (1...10).contains(value) ? value : 0
    }
}

extension ExperienceEvent {
    var bookSeriesName: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookSeriesName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookVolumeNumber: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookVolumeNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookAuthorName: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookAuthorName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookISBN: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookISBN
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookVolumeLabel: String {
        let value = bookVolumeNumber
        guard !value.isEmpty else { return "" }
        if value.contains("巻") || value.contains("編") || value.contains("冊") {
            return value
        }
        return "第\(value)巻"
    }

    var bookLegacySummary: String {
        [bookSeriesName, bookVolumeLabel, bookAuthorName]
            .filter { !$0.isEmpty }
            .joined(separator: "・")
    }

    func applyBookMetadata(
        seriesName: String,
        volumeNumber: String,
        authorName: String,
        isbn: String? = nil
    ) {
        var fields = VisitUnitFields(rawValue: unitFieldsRaw)
        fields.bookSeriesName = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.bookVolumeNumber = volumeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.bookAuthorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let isbn {
            fields.bookISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        unitFieldsRaw = fields.encodedRawValue
        self.seriesName = [
            fields.bookSeriesName,
            fields.bookVolumeNumber.isEmpty
                ? ""
                : (fields.bookVolumeNumber.contains("巻") ? fields.bookVolumeNumber : "第\(fields.bookVolumeNumber)巻"),
            fields.bookAuthorName,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "・")
    }

    var screenWorkType: ScreenWorkType {
        ScreenWorkType.resolved(from: subTypeKey)
    }

    var screenWorkSeasonNumber: Int {
        guard screenWorkType.supportsSeason else { return 0 }
        return VisitUnitFields(rawValue: unitFieldsRaw).screenWorkSeasonNumber
    }

    var screenWorkSeasonLabel: String {
        let number = screenWorkSeasonNumber
        return number > 0 ? "シーズン\(number)" : ""
    }

    func applyScreenWorkClassification(typeKey: String, seasonNumber: Int) {
        let type = ScreenWorkType.resolved(from: typeKey)
        subTypeKey = type.rawValue
        var fields = VisitUnitFields(rawValue: unitFieldsRaw)
        fields.screenWorkSeasonNumber = type.supportsSeason
            ? VisitUnitFields.normalizedSeasonNumber(seasonNumber)
            : 0
        unitFieldsRaw = fields.encodedRawValue
    }
}

enum BookSeriesRegistrationDefaults {
    nonisolated static func nextVolumeNumber(from volumeNumbers: [String]) -> String {
        let values = volumeNumbers.compactMap(bookVolumeValue)
        guard let maximum = values.max() else { return "" }
        return String(Int(floor(maximum)) + 1)
    }

    nonisolated private static func bookVolumeValue(_ value: String) -> Double? {
        let normalized = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        var numeric = ""
        var foundDigit = false
        for character in normalized {
            if character.isNumber {
                numeric.append(character)
                foundDigit = true
            } else if character == ".", foundDigit, !numeric.contains(".") {
                numeric.append(character)
            } else if foundDigit {
                break
            }
        }
        return Double(numeric)
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
                .init(key: "movieDefault", title: "映像作品", resourceName: "movie-hero-default"),
                .init(key: "movieDrama", title: "ドラマ", resourceName: "movie-hero-drama"),
                .init(key: "movieAnime", title: "アニメ", resourceName: "movie-hero-anime"),
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
