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

nonisolated struct VisitExpenseEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = Decimal(0)

    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedAmount: Decimal {
        max(amount, Decimal(0))
    }

    var isEmpty: Bool {
        normalizedTitle.isEmpty && normalizedAmount == Decimal(0)
    }
}

/// パークや自然系の1回の体験に含まれる、繰り返し追加可能な見どころ。
/// 写真本体は複製せず、同じVisitに属するPhotoBlobのUUIDだけを参照する。
nonisolated struct VisitMomentEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var linkedPhotoIDs: [UUID] = []

    var normalized: VisitMomentEntry {
        VisitMomentEntry(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            linkedPhotoIDs: Array(Set(linkedPhotoIDs)).sorted { $0.uuidString < $1.uuidString }
        )
    }

    var isEmpty: Bool {
        let value = normalized
        return value.title.isEmpty && value.note.isEmpty && value.linkedPhotoIDs.isEmpty
    }
}

struct VisitUnitFields: Codable {
    var ocrText: String = ""
    var styleNames: [String] = []
    var socialLinks: [String] = []
    /// この回の同行者に紐づけて残すSNS名・URL。公演公式SNSとは分離する。
    var companionSocialLinks: [String] = []
    var eventSubtitle: String = ""
    /// 施設そのものではなく、この1回で見た展示・目的を表す短い副題。
    var visitSubtitle: String = ""
    var venueAddressSnapshot: String = ""
    var eventCreditsText: String = ""
    /// 公演公式URLとは分離して保持する、公演共通のチケット案内・販売ページ。
    var eventTicketURL: String = ""
    var eventPerformanceTypeCustomName: String = ""
    var eventPeriodStartsAt: Date?
    var eventPeriodEndsAt: Date?
    var eventVenues: [EventVenueEntry] = []
    /// 観劇・LIVEの参加回で使う任意の開場日時。
    var performanceOpensAt: Date?
    var excludedEventCastLinkIDs: [UUID] = []
    var hasVisitCastSnapshot: Bool = false
    var screenWorkSeasonNumber: Int = 0
    var screenWorkOriginalTitle: String = ""
    var screenWorkReleaseDate: String = ""
    var screenWorkOverview: String = ""
    var screenWorkTMDBID: Int = 0
    var screenWorkTMDBMediaType: String = ""
    var eyecatchAspectRatioKey: String = ""
    var heroBackgroundPath: String = ""
    var heroBackgroundPresetKey: String = ""
    /// `Visit.note` は検索互換のためプレーンテキストのまま保持し、装飾範囲だけをここへ保存する。
    var memoStyleRuns: [MemoStyleRun] = []
    var goshuinBookSizeKey: String = ""
    var weatherSymbolName: String = ""
    var weatherHighCelsius: Double?
    var weatherLowCelsius: Double?
    var weatherFetchedAt: Date?
    var weatherAttributionURL: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    /// LIVE参戦回のセットリスト。MCとアンコールは曲とは別種別で保持する。
    var liveSetlistEntries: [LiveSetlistEntry] = []
    /// この1回に直接入力した費用内訳。旧データの Visit.amount は合計として引き続き保持する。
    var expenseEntries: [VisitExpenseEntry] = []
    /// テーマパークのイベント、自然・生き物の「見たもの・体験」。
    var momentEntries: [VisitMomentEntry] = []
    /// 書籍（巻）をシリーズ単位で束ねるための構造化メタデータ。
    var bookSeriesName: String = ""
    var bookVolumeNumber: String = ""
    var bookAuthorName: String = ""
    var bookTranslatorName: String = ""
    var bookISBN: String = ""
    var bookPublisherName: String = ""
    var bookPublishedDate: String = ""
    var bookPriceText: String = ""
    var bookPageCount: Int = 0
    /// 小説・漫画など、判型や読書媒体とは独立した本の内容分類。
    var bookContentTypeKey: String = ""
    /// 紙・電子・音声など、表紙比率とは独立した読書媒体。
    var bookMediumKey: String = ""
    /// ISBN検索で書誌情報を取得したサービス名。ユーザー入力の公式URLとは分離する。
    var bookInformationSourceName: String = ""
    /// ISBN検索結果の参照ページ。公式URLとして扱わない。
    var bookInformationSourceURL: String = ""
    /// 書籍記録で終了日を明示したか。nil は旧データ（従来の読了日1日）として扱う。
    var bookReadingHasEndDate: Bool?

    init(
        ocrText: String = "",
        styleNames: [String] = [],
        socialLinks: [String] = [],
        companionSocialLinks: [String] = [],
        eventSubtitle: String = "",
        visitSubtitle: String = "",
        venueAddressSnapshot: String = "",
        eventCreditsText: String = "",
        eventTicketURL: String = "",
        eventPerformanceTypeCustomName: String = "",
        eventPeriodStartsAt: Date? = nil,
        eventPeriodEndsAt: Date? = nil,
        eventVenues: [EventVenueEntry] = [],
        performanceOpensAt: Date? = nil,
        excludedEventCastLinkIDs: [UUID] = [],
        hasVisitCastSnapshot: Bool = false,
        screenWorkSeasonNumber: Int = 0,
        screenWorkOriginalTitle: String = "",
        screenWorkReleaseDate: String = "",
        screenWorkOverview: String = "",
        screenWorkTMDBID: Int = 0,
        screenWorkTMDBMediaType: String = "",
        eyecatchAspectRatioKey: String = "",
        heroBackgroundPath: String = "",
        heroBackgroundPresetKey: String = "",
        memoStyleRuns: [MemoStyleRun] = [],
        goshuinBookSizeKey: String = "",
        weatherSymbolName: String = "",
        weatherHighCelsius: Double? = nil,
        weatherLowCelsius: Double? = nil,
        weatherFetchedAt: Date? = nil,
        weatherAttributionURL: String = "",
        advancedEntries: [AdvancedFieldEntry] = [],
        liveSetlistEntries: [LiveSetlistEntry] = [],
        expenseEntries: [VisitExpenseEntry] = [],
        momentEntries: [VisitMomentEntry] = [],
        bookSeriesName: String = "",
        bookVolumeNumber: String = "",
        bookAuthorName: String = "",
        bookTranslatorName: String = "",
        bookISBN: String = "",
        bookPublisherName: String = "",
        bookPublishedDate: String = "",
        bookPriceText: String = "",
        bookPageCount: Int = 0,
        bookContentTypeKey: String = "",
        bookMediumKey: String = "",
        bookInformationSourceName: String = "",
        bookInformationSourceURL: String = "",
        bookReadingHasEndDate: Bool? = nil
    ) {
        self.ocrText = ocrText
        self.styleNames = styleNames
        self.socialLinks = socialLinks
        self.companionSocialLinks = companionSocialLinks
        self.eventSubtitle = eventSubtitle
        self.visitSubtitle = visitSubtitle
        self.venueAddressSnapshot = venueAddressSnapshot
        self.eventCreditsText = eventCreditsText
        self.eventTicketURL = eventTicketURL
        self.eventPerformanceTypeCustomName = eventPerformanceTypeCustomName
        self.eventPeriodStartsAt = eventPeriodStartsAt
        self.eventPeriodEndsAt = eventPeriodEndsAt
        self.eventVenues = eventVenues
        self.performanceOpensAt = performanceOpensAt
        self.excludedEventCastLinkIDs = excludedEventCastLinkIDs
        self.hasVisitCastSnapshot = hasVisitCastSnapshot
        self.screenWorkSeasonNumber = Self.normalizedSeasonNumber(screenWorkSeasonNumber)
        self.screenWorkOriginalTitle = screenWorkOriginalTitle
        self.screenWorkReleaseDate = screenWorkReleaseDate
        self.screenWorkOverview = screenWorkOverview
        self.screenWorkTMDBID = max(screenWorkTMDBID, 0)
        self.screenWorkTMDBMediaType = screenWorkTMDBMediaType
        self.eyecatchAspectRatioKey = eyecatchAspectRatioKey
        self.heroBackgroundPath = heroBackgroundPath
        self.heroBackgroundPresetKey = heroBackgroundPresetKey
        self.memoStyleRuns = memoStyleRuns
        self.goshuinBookSizeKey = goshuinBookSizeKey
        self.weatherSymbolName = weatherSymbolName
        self.weatherHighCelsius = weatherHighCelsius
        self.weatherLowCelsius = weatherLowCelsius
        self.weatherFetchedAt = weatherFetchedAt
        self.weatherAttributionURL = weatherAttributionURL
        self.advancedEntries = advancedEntries
        self.liveSetlistEntries = liveSetlistEntries
        self.expenseEntries = expenseEntries
        self.momentEntries = momentEntries
        self.bookSeriesName = bookSeriesName
        self.bookVolumeNumber = bookVolumeNumber
        self.bookAuthorName = bookAuthorName
        self.bookTranslatorName = bookTranslatorName
        self.bookISBN = bookISBN
        self.bookPublisherName = bookPublisherName
        self.bookPublishedDate = bookPublishedDate
        self.bookPriceText = bookPriceText
        self.bookPageCount = max(bookPageCount, 0)
        self.bookContentTypeKey = bookContentTypeKey
        self.bookMediumKey = bookMediumKey
        self.bookInformationSourceName = bookInformationSourceName
        self.bookInformationSourceURL = bookInformationSourceURL
        self.bookReadingHasEndDate = bookReadingHasEndDate
    }

    private enum CodingKeys: String, CodingKey {
        case ocrText
        case styleNames
        case socialLinks
        case companionSocialLinks
        case eventSubtitle
        case visitSubtitle
        case venueAddressSnapshot
        case eventCreditsText
        case eventTicketURL
        case eventPerformanceTypeCustomName
        case eventPeriodStartsAt
        case eventPeriodEndsAt
        case eventVenues
        case performanceOpensAt
        case excludedEventCastLinkIDs
        case hasVisitCastSnapshot
        case screenWorkSeasonNumber
        case screenWorkOriginalTitle
        case screenWorkReleaseDate
        case screenWorkOverview
        case screenWorkTMDBID
        case screenWorkTMDBMediaType
        case eyecatchAspectRatioKey
        case heroBackgroundPath
        case heroBackgroundPresetKey
        case memoStyleRuns
        case goshuinBookSizeKey
        case weatherSymbolName
        case weatherHighCelsius
        case weatherLowCelsius
        case weatherFetchedAt
        case weatherAttributionURL
        case advancedEntries
        case liveSetlistEntries
        case expenseEntries
        case momentEntries
        case bookSeriesName
        case bookVolumeNumber
        case bookAuthorName
        case bookTranslatorName
        case bookISBN
        case bookPublisherName
        case bookPublishedDate
        case bookPriceText
        case bookPageCount
        case bookContentTypeKey
        case bookMediumKey
        case bookInformationSourceName
        case bookInformationSourceURL
        case bookReadingHasEndDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
        styleNames = try container.decodeIfPresent([String].self, forKey: .styleNames) ?? []
        socialLinks = try container.decodeIfPresent([String].self, forKey: .socialLinks) ?? []
        companionSocialLinks = try container.decodeIfPresent([String].self, forKey: .companionSocialLinks) ?? []
        eventSubtitle = try container.decodeIfPresent(String.self, forKey: .eventSubtitle) ?? ""
        visitSubtitle = try container.decodeIfPresent(String.self, forKey: .visitSubtitle) ?? ""
        venueAddressSnapshot = try container.decodeIfPresent(String.self, forKey: .venueAddressSnapshot) ?? ""
        eventCreditsText = try container.decodeIfPresent(String.self, forKey: .eventCreditsText) ?? ""
        eventTicketURL = try container.decodeIfPresent(String.self, forKey: .eventTicketURL) ?? ""
        eventPerformanceTypeCustomName = try container.decodeIfPresent(String.self, forKey: .eventPerformanceTypeCustomName) ?? ""
        eventPeriodStartsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodStartsAt)
        eventPeriodEndsAt = try container.decodeIfPresent(Date.self, forKey: .eventPeriodEndsAt)
        eventVenues = try container.decodeIfPresent([EventVenueEntry].self, forKey: .eventVenues) ?? []
        performanceOpensAt = try container.decodeIfPresent(Date.self, forKey: .performanceOpensAt)
        excludedEventCastLinkIDs = try container.decodeIfPresent([UUID].self, forKey: .excludedEventCastLinkIDs) ?? []
        hasVisitCastSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasVisitCastSnapshot) ?? false
        screenWorkSeasonNumber = Self.normalizedSeasonNumber(
            try container.decodeIfPresent(Int.self, forKey: .screenWorkSeasonNumber) ?? 0
        )
        screenWorkOriginalTitle = try container.decodeIfPresent(String.self, forKey: .screenWorkOriginalTitle) ?? ""
        screenWorkReleaseDate = try container.decodeIfPresent(String.self, forKey: .screenWorkReleaseDate) ?? ""
        screenWorkOverview = try container.decodeIfPresent(String.self, forKey: .screenWorkOverview) ?? ""
        screenWorkTMDBID = max(try container.decodeIfPresent(Int.self, forKey: .screenWorkTMDBID) ?? 0, 0)
        screenWorkTMDBMediaType = try container.decodeIfPresent(String.self, forKey: .screenWorkTMDBMediaType) ?? ""
        eyecatchAspectRatioKey = try container.decodeIfPresent(String.self, forKey: .eyecatchAspectRatioKey) ?? ""
        heroBackgroundPath = try container.decodeIfPresent(String.self, forKey: .heroBackgroundPath) ?? ""
        heroBackgroundPresetKey = try container.decodeIfPresent(String.self, forKey: .heroBackgroundPresetKey) ?? ""
        memoStyleRuns = try container.decodeIfPresent([MemoStyleRun].self, forKey: .memoStyleRuns) ?? []
        goshuinBookSizeKey = try container.decodeIfPresent(String.self, forKey: .goshuinBookSizeKey) ?? ""
        weatherSymbolName = try container.decodeIfPresent(String.self, forKey: .weatherSymbolName) ?? ""
        weatherHighCelsius = try container.decodeIfPresent(Double.self, forKey: .weatherHighCelsius)
        weatherLowCelsius = try container.decodeIfPresent(Double.self, forKey: .weatherLowCelsius)
        weatherFetchedAt = try container.decodeIfPresent(Date.self, forKey: .weatherFetchedAt)
        weatherAttributionURL = try container.decodeIfPresent(String.self, forKey: .weatherAttributionURL) ?? ""
        advancedEntries = try container.decodeIfPresent([AdvancedFieldEntry].self, forKey: .advancedEntries) ?? []
        liveSetlistEntries = try container.decodeIfPresent([LiveSetlistEntry].self, forKey: .liveSetlistEntries) ?? []
        expenseEntries = try container.decodeIfPresent([VisitExpenseEntry].self, forKey: .expenseEntries) ?? []
        momentEntries = try container.decodeIfPresent([VisitMomentEntry].self, forKey: .momentEntries) ?? []
        bookSeriesName = try container.decodeIfPresent(String.self, forKey: .bookSeriesName) ?? ""
        bookVolumeNumber = try container.decodeIfPresent(String.self, forKey: .bookVolumeNumber) ?? ""
        bookAuthorName = try container.decodeIfPresent(String.self, forKey: .bookAuthorName) ?? ""
        bookTranslatorName = try container.decodeIfPresent(String.self, forKey: .bookTranslatorName) ?? ""
        bookISBN = try container.decodeIfPresent(String.self, forKey: .bookISBN) ?? ""
        bookPublisherName = try container.decodeIfPresent(String.self, forKey: .bookPublisherName) ?? ""
        bookPublishedDate = try container.decodeIfPresent(String.self, forKey: .bookPublishedDate) ?? ""
        bookPriceText = try container.decodeIfPresent(String.self, forKey: .bookPriceText) ?? ""
        bookPageCount = max(try container.decodeIfPresent(Int.self, forKey: .bookPageCount) ?? 0, 0)
        bookContentTypeKey = try container.decodeIfPresent(String.self, forKey: .bookContentTypeKey) ?? ""
        bookMediumKey = try container.decodeIfPresent(String.self, forKey: .bookMediumKey) ?? ""
        bookInformationSourceName = try container.decodeIfPresent(String.self, forKey: .bookInformationSourceName) ?? ""
        bookInformationSourceURL = try container.decodeIfPresent(String.self, forKey: .bookInformationSourceURL) ?? ""
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
                || !venueAddressSnapshot.isEmpty
                || !eventCreditsText.isEmpty
                || !eventTicketURL.isEmpty
                || !eventPerformanceTypeCustomName.isEmpty
                || eventPeriodStartsAt != nil
                || eventPeriodEndsAt != nil
                || !eventVenues.isEmpty
                || performanceOpensAt != nil
                || !excludedEventCastLinkIDs.isEmpty
                || hasVisitCastSnapshot
                || screenWorkSeasonNumber > 0
                || !screenWorkOriginalTitle.isEmpty
                || !screenWorkReleaseDate.isEmpty
                || !screenWorkOverview.isEmpty
                || screenWorkTMDBID > 0
                || !screenWorkTMDBMediaType.isEmpty
                || !eyecatchAspectRatioKey.isEmpty
                || !heroBackgroundPath.isEmpty
                || !heroBackgroundPresetKey.isEmpty
                || !memoStyleRuns.isEmpty
                || !goshuinBookSizeKey.isEmpty
                || !weatherSymbolName.isEmpty
                || weatherHighCelsius != nil
                || weatherLowCelsius != nil
                || weatherFetchedAt != nil
                || !weatherAttributionURL.isEmpty
                || !advancedEntries.isEmpty
                || !liveSetlistEntries.isEmpty
                || !expenseEntries.isEmpty
                || !momentEntries.isEmpty
                || !bookSeriesName.isEmpty
                || !bookVolumeNumber.isEmpty
                || !bookAuthorName.isEmpty
                || !bookTranslatorName.isEmpty
                || !bookISBN.isEmpty
                || !bookPublisherName.isEmpty
                || !bookPublishedDate.isEmpty
                || !bookPriceText.isEmpty
                || bookPageCount > 0
                || !bookContentTypeKey.isEmpty
                || !bookMediumKey.isEmpty
                || !bookInformationSourceName.isEmpty
                || !bookInformationSourceURL.isEmpty
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
    var bookContentTypeKey: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookContentTypeKey
    }

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

    var bookTranslatorName: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookTranslatorName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPublisherName: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookPublisherName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPublishedDate: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookPublishedDate
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPriceText: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookPriceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sortedBookShelfNames: [String] {
        (bookShelves ?? [])
            .sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var bookPageCount: Int {
        VisitUnitFields(rawValue: unitFieldsRaw).bookPageCount
    }

    var bookInformationSourceName: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookInformationSourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookInformationSourceURL: String {
        VisitUnitFields(rawValue: unitFieldsRaw).bookInformationSourceURL
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
        translatorName: String? = nil,
        isbn: String? = nil,
        publisherName: String? = nil,
        publishedDate: String? = nil,
        priceText: String? = nil,
        pageCount: Int? = nil,
        informationSourceName: String? = nil,
        informationSourceURL: String? = nil
    ) {
        var fields = VisitUnitFields(rawValue: unitFieldsRaw)
        fields.bookSeriesName = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.bookVolumeNumber = volumeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        fields.bookAuthorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let translatorName {
            fields.bookTranslatorName = translatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let isbn {
            fields.bookISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let publisherName {
            fields.bookPublisherName = publisherName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let publishedDate {
            fields.bookPublishedDate = publishedDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let priceText {
            fields.bookPriceText = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let pageCount {
            fields.bookPageCount = max(pageCount, 0)
        }
        if let informationSourceName {
            fields.bookInformationSourceName = informationSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let informationSourceURL {
            fields.bookInformationSourceURL = informationSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        unitFieldsRaw = fields.encodedRawValue
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
    static let eventEyecatchKey = "eventEyecatch"

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
                // 旧データの保存キーは維持し、既定背景を動物園へ差し替える。
                .init(key: "natureDefault", title: "動物園", resourceName: "nature_living-hero-zoo"),
                .init(key: "natureAquarium", title: "水族館", resourceName: "nature_living-hero-aquarium"),
                .init(key: "natureBotanical", title: "植物園", resourceName: "nature_living-hero-botanical"),
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

nonisolated struct AdvancedFieldEntry: Codable, Identifiable, Equatable {
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

nonisolated enum LiveSetlistEntryKind: String, Codable, CaseIterable, Identifiable {
    case song
    case mc
    case encore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .song: "曲"
        case .mc: "MC"
        case .encore: "アンコール"
        }
    }
}

nonisolated struct LiveSetlistEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: LiveSetlistEntryKind = .song
    var text: String = ""

    var normalized: LiveSetlistEntry {
        LiveSetlistEntry(
            id: id,
            kind: kind,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
