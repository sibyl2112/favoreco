//
//  CategoryLibraryItem.swift
//  favorecoAPP
//
//  Display adapter shared by category libraries.
//

import SwiftUI

struct CategoryLibraryItem: Identifiable {
    let event: ExperienceEvent
    let visits: [Visit]
    let latestVisit: Visit?
    let nextPlan: Plan?
    let ticketAttempts: [TicketAttempt]
    let facilityName: String
    let facilityIdentityKey: String
    let placeMasterID: UUID?

    var id: UUID { event.id }

    var hasActiveTicketProgress: Bool {
        ticketAttempts.contains {
            !$0.isArchived
                && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
        }
    }

    var title: String {
        if !facilityName.isEmpty { return facilityName }
        return event.title.isEmpty ? "記録" : event.title
    }

    var physicalVisitCount: Int {
        Set(visits.map { Calendar.autoupdatingCurrent.startOfDay(for: $0.visitedAt) }).count
    }

    func visitSummaryText(for category: RecordCategory) -> String {
        let visitLabel = category.templateKey == "theme_park" ? "来園" : "訪問"
        return "\(visitLabel)\(physicalVisitCount)回・記録\(visits.count)件"
    }

    var ratingText: String {
        guard let rating = latestVisit?.overallRating, rating > 0 else { return "—" }
        return String(format: "%.1f", rating)
    }

    var ratingValue: Double? {
        guard let rating = latestVisit?.overallRating, rating > 0 else { return nil }
        return rating
    }

    var dateText: String {
        guard let displayDate else { return "—" }
        return FavorecoDateText.compactDate(displayDate)
    }

    var displayDate: Date? {
        if let nextPlan { return nextPlan.startsAt }
        if let latestVisit { return latestVisit.visitedAt }
        return nil
    }

    var galleryDateText: String {
        guard let displayDate else { return "—" }
        return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
    }

    var screenWorkDateText: String {
        guard let displayDate else { return "—" }
        if event.screenWorkType == .movie {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
        }
        if event.screenWorkType != .movie {
            return screenWorkBroadcastSeasonText(for: displayDate)
        }
        return "—"
    }

    var screenWorkBannerDateText: String {
        guard let displayDate else { return "—" }
        if event.screenWorkType != .movie {
            return screenWorkBroadcastSeasonText(for: displayDate)
        }
        return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
    }

    private func screenWorkBroadcastSeasonText(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return "—" }
        let seasonName = switch month {
        case 1...3: "冬"
        case 4...6: "春"
        case 7...9: "夏"
        default: "秋"
        }
        let typeName = event.screenWorkType == .drama ? "ドラマ" : "アニメ"
        return "\(FavorecoDateText.year(year)) \(seasonName)\(typeName)"
    }

    var galleryDateColor: Color {
        guard let displayDate else { return .secondary }
        switch FavorecoDateText.weekdayNumber(displayDate) {
        case 1:
            return .red
        case 7:
            return .blue
        default:
            return dateColor
        }
    }

    var ratingSymbol: String {
        ratingText == "—" ? "star" : "star.fill"
    }

    var ratingColor: Color {
        ratingText == "—" ? .secondary : .yellow
    }

    var dateColor: Color {
        nextPlan == nil ? .secondary : .red
    }

    var compactTileDateText: String {
        guard let displayDate else { return "—" }
        let text = FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
        return nextPlan == nil ? text : "予定 \(text)"
    }

    var bannerDateTimeText: String {
        guard let displayDate else { return "—" }
        return "\(FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)) \(FavorecoDateText.time(displayDate))"
    }

    var accessibilitySummary: String {
        "\(title)、評価\(ratingText)、\(dateText)"
    }

    var screenWorkAccessibilitySummary: String {
        let typeAndSeason = [event.screenWorkType.displayName, event.screenWorkSeasonLabel]
            .filter { !$0.isEmpty }
            .joined(separator: "、")
        let rating = ratingValue.map { "評価\(String(format: "%.1f", $0))" } ?? "評価なし"
        return [title, typeAndSeason, screenWorkDateText, rating]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: "、")
    }

    var screenWorkBannerAccessibilitySummary: String {
        [title, screenWorkBannerDateText, event.screenWorkType.displayName]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: "、")
    }

    var productionTypeText: String {
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        return TheaterPerformanceType.displayName(
            for: event.subTypeKey,
            customName: fields.eventPerformanceTypeCustomName
        )
    }

    var productionSeriesText: String {
        event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var productionOrganizerText: String {
        let savedOrganizer = event.organizerNameSnapshot
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !savedOrganizer.isEmpty {
            return savedOrganizer
        }
        return linkedNames(for: "organizer").joined(separator: "・")
    }

    func eventInformationCreditText(for category: RecordCategory) -> String {
        guard category.templateKey == "live" else { return productionOrganizerText }

        let artists = ["artist", "performer", "cast"]
            .flatMap { linkedNames(for: $0) }
            .reduce(into: [String]()) { names, name in
                if !names.contains(name) {
                    names.append(name)
                }
            }
        if !artists.isEmpty {
            return "出演: \(artists.joined(separator: "・"))"
        }
        return productionOrganizerText.isEmpty ? "" : "主催: \(productionOrganizerText)"
    }

    var productionAccessibilitySummary: String {
        [title, productionTypeText, productionSeriesText, productionOrganizerText]
            .filter { !$0.isEmpty }
            .joined(separator: "、")
    }

    var venueText: String {
        if let nextPlan, !nextPlan.venueNameSnapshot.isEmpty {
            return nextPlan.venueNameSnapshot
        }
        if let planVenue = nextPlan?.placeMaster?.name, !planVenue.isEmpty {
            return planVenue
        }
        if let latestVisit, !latestVisit.venueNameSnapshot.isEmpty {
            return latestVisit.venueNameSnapshot
        }
        return latestVisit?.placeMaster?.name ?? ""
    }

    var prefectureText: String {
        let placeMasters = [nextPlan?.placeMaster, latestVisit?.placeMaster].compactMap { $0 }
        if let savedPrefecture = placeMasters.map(\.prefecture).first(where: { !$0.isEmpty }) {
            return savedPrefecture
        }
        let address = placeMasters.map(\.address).first(where: { !$0.isEmpty }) ?? ""
        return JapanPrefecture.extract(from: address)
    }

    var ticketStatusNames: [String] {
        var seen = Set<String>()
        return ticketAttempts.compactMap { attempt in
            let name = TicketStatusDefinition.name(for: attempt.statusKey)
            return seen.insert(name).inserted ? name : nil
        }
    }

    func bannerStatusText(for category: RecordCategory) -> String {
        if nextPlan != nil {
            if let attempt = ticketAttempts.first(where: {
                !["lost", "attended", "skipped"].contains($0.statusKey)
            }) {
                switch attempt.statusKey {
                case "interested": return "気になる"
                case "beforeApply": return "申込予定"
                case "onSaleSoon": return "チケット発売待ち"
                case "waitingResult": return "当落待ち"
                case "won": return "当選"
                case "waitingPayment": return "支払待ち"
                case "waitingIssue": return "取得処理中"
                case "issued": return "受取済み"
                default: return TicketStatusDefinition.name(for: attempt.statusKey)
                }
            }

            switch category.templateKey {
            case "theater": return "観劇予定"
            case "movie": return "鑑賞予定"
            case "live": return "参加予定"
            default: return "予定"
            }
        }

        if latestVisit != nil {
            switch category.templateKey {
            case "theater": return "観劇済み"
            case "movie": return "鑑賞済み"
            case "live": return "参加済み"
            default: return "体験済み"
            }
        }

        return event.stateKey == "interested" ? "気になる" : "登録済み"
    }

    func bannerCreditText(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "theater":
            if let nextPlan, !nextPlan.organizerNameSnapshot.isEmpty {
                return "主催: \(nextPlan.organizerNameSnapshot)"
            }
            if !event.organizerNameSnapshot.isEmpty {
                return "主催: \(event.organizerNameSnapshot)"
            }
            let organizers = linkedNames(for: "organizer")
            return organizers.isEmpty ? "" : "主催: \(organizers.joined(separator: "・"))"
        case "movie":
            let directors = linkedNames(for: "director")
            return directors.isEmpty ? "" : "監督: \(directors.joined(separator: "・"))"
        case "live":
            let artists = ["artist", "performer", "cast"]
                .flatMap { linkedNames(for: $0) }
                .reduce(into: [String]()) { names, name in
                    if !names.contains(name) {
                        names.append(name)
                    }
                }
            if !artists.isEmpty {
                return "出演: \(artists.joined(separator: "・"))"
            }
            if let nextPlan, !nextPlan.organizerNameSnapshot.isEmpty {
                return "主催: \(nextPlan.organizerNameSnapshot)"
            }
            if !event.organizerNameSnapshot.isEmpty {
                return "主催: \(event.organizerNameSnapshot)"
            }
            let organizers = linkedNames(for: "organizer")
            return organizers.isEmpty ? "" : "主催: \(organizers.joined(separator: "・"))"
        default:
            return ""
        }
    }

    private func linkedNames(for roleKey: String) -> [String] {
        var seen = Set<String>()
        return (event.personLinks ?? [])
            .filter { !$0.isArchived && $0.roleKey == roleKey }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { link in
                let name = link.nameSnapshot.isEmpty
                    ? link.person?.displayName ?? ""
                    : link.nameSnapshot
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return name
            }
    }
}

struct CategoryLibraryPartition {
    let showsPlanningSections: Bool
    let showsPlaceExperienceSections: Bool
    let showsBookSections: Bool
    let showsVisitRecordLibrary: Bool
    let interestedItems: [CategoryLibraryItem]
    let productionItems: [CategoryLibraryItem]

    var displayedProductionItems: [CategoryLibraryItem] {
        showsPlaceExperienceSections ? [] : productionItems
    }
}

enum CategoryLibraryPartitionBuilder {
    private static let planningTemplateKeys: Set<String> = [
        "theater",
        "live",
        "museum",
        "movie",
        "theme_park",
        "nature_living",
        "outing_facility",
    ]

    private static let visitRecordTemplateKeys: Set<String> = [
        "live",
        "museum",
        "movie",
    ]

    static func make(
        templateKey: String,
        items: [CategoryLibraryItem]
    ) -> CategoryLibraryPartition {
        let showsPlanningSections = planningTemplateKeys.contains(templateKey)
        let showsPlaceExperienceSections = CategoryTopLibraryPolicy.isPlaceExperience(
            templateKey: templateKey
        )
        let showsBookSections = templateKey == "book"
        var interestedItems: [CategoryLibraryItem] = []
        var productionItems: [CategoryLibraryItem] = []

        for item in items {
            if showsPlanningSections {
                let isStandaloneInterest = item.event.stateKey == "interested"
                    && item.nextPlan == nil
                    && !item.hasActiveTicketProgress
                if isStandaloneInterest {
                    interestedItems.append(item)
                }

                if showsPlaceExperienceSections {
                    productionItems.append(item)
                } else if templateKey == "theater" {
                    if !isStandaloneInterest {
                        productionItems.append(item)
                    }
                } else if item.event.stateKey != "interested" {
                    productionItems.append(item)
                }
            } else if showsBookSections {
                if item.event.stateKey == "interested" {
                    interestedItems.append(item)
                } else if item.latestVisit != nil {
                    productionItems.append(item)
                }
            } else {
                productionItems.append(item)
            }
        }

        return CategoryLibraryPartition(
            showsPlanningSections: showsPlanningSections,
            showsPlaceExperienceSections: showsPlaceExperienceSections,
            showsBookSections: showsBookSections,
            showsVisitRecordLibrary: visitRecordTemplateKeys.contains(templateKey),
            interestedItems: interestedItems,
            productionItems: productionItems
        )
    }
}

enum CategoryLibraryItemBuilder {
    static func make(
        category: RecordCategory,
        eventSnapshots: [CategoryEventSnapshot],
        categoryVisits: [Visit],
        eventsByID: [UUID: ExperienceEvent],
        allPlans: [Plan],
        groupsByPlace: Bool,
        now: Date
    ) -> [CategoryLibraryItem] {
        let visitsByEventID = Dictionary(grouping: categoryVisits) { $0.event?.id }
        let plansByEventID = Dictionary(grouping: allPlans.filter { plan in
            !plan.isArchived
                && (plan.category ?? plan.event?.category)?.id == category.id
                && plan.event != nil
        }) { $0.event?.id }

        let items: [CategoryLibraryItem] = eventSnapshots.compactMap {
            eventSnapshot -> CategoryLibraryItem? in
            guard let event = eventsByID[eventSnapshot.id] else { return nil }
            let eventID = eventSnapshot.id
            let latestVisit = visitsByEventID[eventID]?.max(by: { $0.visitedAt < $1.visitedAt })
            let eventPlans = plansByEventID[eventID] ?? []
            let nextPlan = eventPlans
                .filter { $0.isUpcomingOrOngoing(at: now) }
                .min(by: { $0.startsAt < $1.startsAt })
            let attempts = TicketAttemptPresentationOrder.sorted(
                eventPlans.flatMap { $0.ticketAttempts ?? [] }.filter { !$0.isArchived },
                now: now
            )
            let eventVisits = visitsByEventID[eventID] ?? []
            let representativePlace = latestVisit?.placeMaster ?? nextPlan?.placeMaster
            let resolvedFacilityName = representativePlace?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? latestVisit?.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? nextPlan?.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            let facilityName = groupsByPlace ? resolvedFacilityName : ""
            let facilityIdentityKey: String
            let aggregatedVisits: [Visit]
            if groupsByPlace, let placeID = representativePlace?.id {
                facilityIdentityKey = "place|\(placeID.uuidString)"
                aggregatedVisits = categoryVisits.filter { $0.placeMaster?.id == placeID }
            } else if groupsByPlace, !facilityName.isEmpty {
                let normalizedName = facilityName
                    .folding(
                        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                        locale: Locale(identifier: "ja_JP")
                    )
                    .filter { !$0.isWhitespace }
                facilityIdentityKey = "name|\(normalizedName)"
                aggregatedVisits = categoryVisits.filter { visit in
                    let name = (visit.placeMaster?.name ?? visit.venueNameSnapshot)
                        .folding(
                            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                            locale: Locale(identifier: "ja_JP")
                        )
                        .filter { !$0.isWhitespace }
                    return name == normalizedName
                }
            } else {
                facilityIdentityKey = "event|\(eventID.uuidString)"
                aggregatedVisits = eventVisits
            }
            let aggregatedLatestVisit = aggregatedVisits.max(by: { $0.visitedAt < $1.visitedAt })
            return CategoryLibraryItem(
                event: event,
                visits: aggregatedVisits,
                latestVisit: aggregatedLatestVisit ?? latestVisit,
                nextPlan: nextPlan,
                ticketAttempts: attempts,
                facilityName: facilityName,
                facilityIdentityKey: facilityIdentityKey,
                placeMasterID: representativePlace?.id
            )
        }

        let uniqueItems: [CategoryLibraryItem]
        if groupsByPlace {
            uniqueItems = Dictionary(grouping: items, by: \.facilityIdentityKey)
                .values
                .compactMap { matchingItems in
                    matchingItems.max { lhs, rhs in
                        let lhsDate = lhs.displayDate ?? lhs.event.updatedAt
                        let rhsDate = rhs.displayDate ?? rhs.event.updatedAt
                        return lhsDate < rhsDate
                    }
                }
        } else if category.templateKey == "theater" {
            func relationScore(for item: CategoryLibraryItem) -> Int {
                let visitScore = item.latestVisit == nil ? 0 : 4
                let planScore = item.nextPlan == nil ? 0 : 2
                let ticketScore = min(item.ticketAttempts.count, 2)
                return visitScore + planScore + ticketScore
            }

            uniqueItems = Dictionary(grouping: items, by: \.event.productionIdentityKey)
                .values
                .compactMap { matchingItems in
                    matchingItems.max { lhs, rhs in
                        let lhsRelationScore = relationScore(for: lhs)
                        let rhsRelationScore = relationScore(for: rhs)
                        if lhsRelationScore != rhsRelationScore {
                            return lhsRelationScore < rhsRelationScore
                        }
                        return lhs.event.updatedAt < rhs.event.updatedAt
                    }
                }
        } else {
            uniqueItems = items
        }

        return uniqueItems.sorted { lhs, rhs in
            switch (lhs.nextPlan, rhs.nextPlan) {
            case let (.some(left), .some(right)):
                return left.startsAt < right.startsAt
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                let leftDate = lhs.latestVisit?.visitedAt ?? lhs.event.updatedAt
                let rightDate = rhs.latestVisit?.visitedAt ?? rhs.event.updatedAt
                return leftDate > rightDate
            }
        }
    }
}
