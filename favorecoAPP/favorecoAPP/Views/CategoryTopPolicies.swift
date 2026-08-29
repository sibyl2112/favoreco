import SwiftUI

enum CategoryTopBackgroundStyle: Equatable {
    case theater
    case live
    case themed
}

struct CategoryChapterNeighborIndices: Equatable {
    let previous: Int?
    let next: Int?
}

enum CategoryChapterNavigationPolicy {
    static func neighborIndices(
        categoryCount: Int,
        currentIndex: Int?
    ) -> CategoryChapterNeighborIndices? {
        guard let currentIndex,
              categoryCount > 0,
              (0..<categoryCount).contains(currentIndex) else {
            return nil
        }
        return CategoryChapterNeighborIndices(
            previous: currentIndex > 0 ? currentIndex - 1 : nil,
            next: currentIndex + 1 < categoryCount ? currentIndex + 1 : nil
        )
    }
}

enum CategoryTopPresentationPolicy {
    private static let visitedPlacesMapTemplateKeys: Set<String> = [
        "museum",
        "live",
        "outing_facility",
        "theme_park",
        "nature_living",
    ]

    static func displayName(name: String, templateKey: String) -> String {
        if templateKey == "live" { return "LIVE" }
        return name.isEmpty ? "ジャンル" : name
    }

    static func supportsVisitedPlacesMap(templateKey: String) -> Bool {
        visitedPlacesMapTemplateKeys.contains(templateKey)
    }

    static func usesAtmosphericDarkStyle(templateKey: String) -> Bool {
        templateKey == "theater" || templateKey == "live"
    }

    static func backgroundStyle(templateKey: String) -> CategoryTopBackgroundStyle {
        switch templateKey {
        case "theater": .theater
        case "live": .live
        default: .themed
        }
    }

    static func brandGradient(templateKey: String) -> LinearGradient? {
        switch templateKey {
        case "theater": TheaterCategoryStyle.brandGradient
        case "live": LiveCategoryStyle.brandGradient
        default: nil
        }
    }

    static func headerForeground(templateKey: String) -> Color? {
        switch templateKey {
        case "theater": TheaterCategoryStyle.ivory
        case "live": LiveCategoryStyle.mist
        default: nil
        }
    }

    /// ジャンル上部の選択名・集計値に使う、背景上で判読できるアクセント色。
    /// 観劇は保存色のワインが背景へ沈むため、チケット件数と同じ明るい操作色を使う。
    static func highContrastAccent(templateKey: String, categoryColor: Color) -> Color {
        switch templateKey {
        case "theater": TheaterCategoryStyle.ticketActionRose
        case "live": LiveCategoryStyle.teal
        default: categoryColor
        }
    }

    static func libraryPrimaryTextColor(templateKey: String) -> Color {
        switch templateKey {
        case "theater": TheaterCategoryStyle.ivory
        case "live": LiveCategoryStyle.mist
        default: Color.primary
        }
    }

    static func librarySecondaryTextColor(templateKey: String) -> Color {
        switch templateKey {
        case "theater": TheaterCategoryStyle.ivory.opacity(0.62)
        case "live": LiveCategoryStyle.mist.opacity(0.58)
        default: Color.secondary
        }
    }
}

enum CategoryPlanningHeroPolicy {
    static let isIntegratedHeroEnabled = false

    static let supportedTemplateKeys: Set<String> = [
        "movie",
        "museum",
        "theme_park",
        "nature_living",
    ]

    static func supports(_ templateKey: String) -> Bool {
        supportedTemplateKeys.contains(templateKey)
    }

    /// 統合Heroは再採用できるよう実装を残すが、現在のトップでは使用しない。
    static func usesIntegratedHero(_ templateKey: String) -> Bool {
        isIntegratedHeroEnabled && supports(templateKey)
    }
}

enum CategoryMemoryHeroPolicy {
    static let supportedTemplateKeys: Set<String> = [
        "movie",
        "museum",
        "theme_park",
        "nature_living",
    ]

    static func supports(_ templateKey: String) -> Bool {
        supportedTemplateKeys.contains(templateKey)
    }

    static func stableIndex(
        itemCount: Int,
        categoryID: UUID,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        guard itemCount > 0 else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let categorySeed = categoryID.uuidString.unicodeScalars.reduce(0) {
            $0 + Int($1.value)
        }
        return (day + categorySeed) % itemCount
    }
}

enum CategoryTopTickerPolicy {
    static let supportedTemplateKeys: Set<String> = [
        "book",
        "theater",
        "live",
        "movie",
        "museum",
        "theme_park",
        "nature_living",
    ]

    static func supports(_ templateKey: String) -> Bool {
        supportedTemplateKeys.contains(templateKey)
    }
}

enum LiveTicketPlacementPolicy {
    private static let nonActionableStatusKeys: Set<String> = [
        "interested",
        "lost",
        "attended",
        "skipped",
        "issued",
    ]

    static func showsInTicketManagement(statusKey: String) -> Bool {
        !nonActionableStatusKeys.contains(statusKey)
    }

    static func allowsComingUp(statusKeys: [String]) -> Bool {
        for statusKey in statusKeys where showsInTicketManagement(statusKey: statusKey) {
            return false
        }
        return true
    }
}

enum CategoryEventInformationPolicy {
    /// 観劇の公演情報とLIVEのライブ情報は、どちらも親ExperienceEventの一覧。
    /// 紐づくPlan・Visit・TicketAttemptの状態はカードへ混ぜない。
    static func usesParentEventCard(templateKey: String, sectionKey: String) -> Bool {
        sectionKey == "productions" && ["theater", "live"].contains(templateKey)
    }
}

enum PerformanceTicketManagementPolicy {
    static func usesFullPlanCard(templateKey: String) -> Bool {
        ["theater", "live"].contains(templateKey)
    }
}

enum CategoryTopVocabulary {
    static func interestRegistrationTitle(templateKey: String) -> String {
        switch templateKey {
        case "movie": "観たい作品を追加"
        case "museum": "気になる展示を追加"
        case "book": "気になる本を追加"
        case "goshuin": "気になる寺社を追加"
        case "theme_park": "気になるパークを追加"
        case "nature_living": "気になるスポットを追加"
        case "outing_facility": "気になる施設を追加"
        default: "気になる対象を追加"
        }
    }

    static func interestAddActionTitle(templateKey: String) -> String {
        switch templateKey {
        case "theater": "公演を追加"
        case "live": "ライブを追加"
        case "museum": "展示を追加"
        case "movie": "作品を追加"
        case "book": "本を追加"
        case "theme_park": "パークを追加"
        case "nature_living", "outing_facility": "施設を追加"
        default: "追加する"
        }
    }

    static func librarySectionTitle(templateKey: String, fallback: String) -> String {
        switch templateKey {
        case "theater": "Productions"
        case "live": "Live History"
        case "museum": "Exhibitions"
        case "movie", "book": "Library"
        case "sake": "Drinks"
        case "theme_park": "Destinations"
        case "nature_living", "outing_facility": "Places"
        default: fallback
        }
    }

    static func featureCarouselJapaneseTitle(templateKey: String) -> String {
        switch templateKey {
        case "museum": "観覧予定 / 気になる"
        case "live": "ライブ予定 / 気になる"
        case "movie": "鑑賞予定 / 気になる"
        case "theme_park", "nature_living": "来園予定 / 気になる"
        default: "予定 / 気になる"
        }
    }

    static func sectionJapaneseTitle(
        englishTitle: String,
        templateKey: String
    ) -> String? {
        switch (templateKey, englishTitle) {
        case ("theater", "Coming Up"): "観劇予定"
        case ("theater", "Interests"): "気になる"
        case ("theater", "Performance Log"): "観劇記録"
        case ("theater", "Productions"): "公演情報"
        case ("theater", "Ticket Management"): "チケット管理"
        case ("live", "Coming Up"): "ライブ予定"
        case ("live", "Interests"): "気になる"
        case ("live", "Live History"): "ライブ記録"
        case ("live", "Live Information"): "ライブ情報"
        case ("goshuin", "Interests"): "気になる寺社"
        case ("museum", "Coming Up"): "鑑賞予定"
        case ("museum", "Interests"): "気になる"
        case ("museum", "Exhibitions"): "鑑賞済み"
        case ("movie", "Coming Up"): "鑑賞予定"
        case ("movie", "Interests"): "気になる"
        case ("movie", "Library"): "鑑賞済み"
        case ("sake", "Drinks"): "お酒"
        case ("theme_park", "Destinations"): "施設情報"
        case ("theme_park", "Coming Up"): "来園予定"
        case ("theme_park", "Interests"): "気になる"
        case ("nature_living", "Coming Up"), ("outing_facility", "Coming Up"): "体験予定"
        case ("nature_living", "Interests"), ("outing_facility", "Interests"): "気になる"
        case ("nature_living", "Places"), ("outing_facility", "Places"): "施設"
        case ("book", "Interests"): "気になる"
        case ("book", "To Read"): "積読"
        case ("book", "Library"): "本"
        default: nil
        }
    }
}

enum CategoryTopLibraryPolicy {
    static func isPlaceExperience(templateKey: String) -> Bool {
        ["theme_park", "nature_living", "outing_facility"].contains(templateKey)
    }

    static func pageSize(for layout: CategoryLibraryLayoutMode) -> Int {
        switch layout {
        case .gallery, .compact: 6
        case .banner: 4
        }
    }

    static func normalizedLayout(
        _ requestedLayout: CategoryLibraryLayoutMode,
        templateKey: String
    ) -> CategoryLibraryLayoutMode {
        if isPlaceExperience(templateKey: templateKey) {
            return requestedLayout == .banner ? .banner : .compact
        }
        if templateKey == "movie" {
            return requestedLayout == .banner ? .banner : .gallery
        }
        if templateKey == "live" {
            return .banner
        }
        return requestedLayout
    }

    static func facilityStorageKey(templateKey: String) -> String {
        templateKey == "museum" ? "museum.facilities" : templateKey
    }

    static func normalizedFacilityLayout(
        _ requestedLayout: CategoryLibraryLayoutMode
    ) -> CategoryLibraryLayoutMode {
        requestedLayout == .banner ? .banner : .compact
    }

    static func displayKey(
        categoryID: UUID,
        sectionKey: String,
        layout: CategoryLibraryLayoutMode
    ) -> String {
        "\(categoryID.uuidString)-\(sectionKey)-\(layout.rawValue)"
    }

    static func summaryMessage(eventCount: Int, visitCount: Int) -> String {
        guard eventCount > 0 else {
            return "登録した対象をここへまとめ、体験を重ねていけます。"
        }
        return "\(eventCount)件の対象と、\(visitCount)件の体験をまとめています。"
    }
}
