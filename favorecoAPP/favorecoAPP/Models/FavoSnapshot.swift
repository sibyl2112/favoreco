import Foundation

struct FavoPersonSnapshot: Identifiable {
    let profile: FavoriteProfile
    let person: PersonMaster
    let visits: [Visit]
    let upcomingPlans: [Plan]
    let categorySummaries: [FavoCategorySummary]
    let frequentPlaces: [FavoPlaceSummary]
    let photoCount: Int
    let spendingBreakdown: FavoSpendingBreakdown

    var id: UUID { profile.id }

    var displayName: String {
        let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? person.displayName : nickname
    }

    var supportDayCount: Int? {
        guard profile.hasStartedAt else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: profile.startedAt)
        let today = calendar.startOfDay(for: Date())
        let elapsed = max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0)
        return elapsed + (profile.includesStartDay ? 1 : 0)
    }

    var latestVisit: Visit? { visits.first }
    var firstVisit: Visit? { visits.last }
    var recordedSpending: Decimal { spendingBreakdown.total }
}

struct FavoCategorySummary: Identifiable {
    let id: String
    let name: String
    let iconSymbol: String
    let colorHex: String
    let count: Int
}

struct FavoPlaceSummary: Identifiable {
    let id: String
    let name: String
    let count: Int
}

struct FavoSpendingSlice: Identifiable {
    let id: String
    let title: String
    let detail: String
    let iconSymbol: String
    let colorHex: String
    let amount: Decimal
}

struct FavoSpendingBreakdown {
    let total: Decimal
    let recordedVisitCount: Int
    let yearly: [FavoSpendingSlice]
    let categories: [FavoSpendingSlice]

    var hasRecordedSpending: Bool {
        total != Decimal(0)
    }

    static func make(visits: [Visit], calendar: Calendar = .current) -> FavoSpendingBreakdown {
        let recordedVisits = visits.filter { $0.amount != Decimal(0) }
        let total = recordedVisits.reduce(Decimal(0)) { $0 + $1.amount }

        struct Value {
            let title: String
            let iconSymbol: String
            let colorHex: String
            var amount: Decimal
            var visitCount: Int
        }

        var yearValues: [Int: Value] = [:]
        var categoryValues: [String: Value] = [:]
        for visit in recordedVisits {
            let year = calendar.component(.year, from: visit.visitedAt)
            let yearValue = yearValues[year]
            yearValues[year] = Value(
                title: "\(year)年",
                iconSymbol: "calendar",
                colorHex: "#8F5E73",
                amount: (yearValue?.amount ?? Decimal(0)) + visit.amount,
                visitCount: (yearValue?.visitCount ?? 0) + 1
            )

            if let category = visit.event?.category {
                let key = category.id.uuidString
                let categoryValue = categoryValues[key]
                categoryValues[key] = Value(
                    title: category.name,
                    iconSymbol: category.iconSymbol,
                    colorHex: category.colorHex,
                    amount: (categoryValue?.amount ?? Decimal(0)) + visit.amount,
                    visitCount: (categoryValue?.visitCount ?? 0) + 1
                )
            } else {
                let key = "uncategorized"
                let categoryValue = categoryValues[key]
                categoryValues[key] = Value(
                    title: "未分類",
                    iconSymbol: "square.dashed",
                    colorHex: "#7A7A7A",
                    amount: (categoryValue?.amount ?? Decimal(0)) + visit.amount,
                    visitCount: (categoryValue?.visitCount ?? 0) + 1
                )
            }
        }

        let yearly = yearValues.map { year, value in
            FavoSpendingSlice(
                id: "year:\(year)",
                title: value.title,
                detail: "\(value.visitCount)件の記録",
                iconSymbol: value.iconSymbol,
                colorHex: value.colorHex,
                amount: value.amount
            )
        }
        .sorted { $0.id > $1.id }

        let categories = categoryValues.map { key, value in
            FavoSpendingSlice(
                id: "category:\(key)",
                title: value.title,
                detail: "\(value.visitCount)件の記録",
                iconSymbol: value.iconSymbol,
                colorHex: value.colorHex,
                amount: value.amount
            )
        }
        .sorted { lhs, rhs in
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }

        return FavoSpendingBreakdown(
            total: total,
            recordedVisitCount: recordedVisits.count,
            yearly: yearly,
            categories: categories
        )
    }
}

struct FavoStorySnapshot: Identifiable {
    let id: String
    let label: String
    let title: String
    let visit: Visit
}

struct FavoCollectionSummary: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let iconSymbol: String
    let colorHex: String
    let visits: [Visit]
}

struct FavoPinnedTargetSnapshot: Identifiable {
    let pin: FavoPin
    let profile: FavoriteProfile?
    let kind: FavoTargetKind
    let title: String
    let subtitle: String
    let iconSymbol: String
    let colorHex: String
    let visits: [Visit]
    let upcomingPlans: [Plan]
    let spendingBreakdown: FavoSpendingBreakdown
    let personSnapshot: FavoPersonSnapshot?

    var id: UUID { pin.id }
    var photoCount: Int {
        visits.reduce(0) { result, visit in
            result + (visit.photos ?? []).filter {
                $0.mediaKind == "photo" && $0.hasStoredData
            }.count
        }
    }
    var recordedSpending: Decimal {
        spendingBreakdown.total
    }
}

struct FavoSnapshot {
    let favorites: [FavoPersonSnapshot]
    let pinnedTargets: [FavoPinnedTargetSnapshot]
    let stories: [FavoStorySnapshot]
    let collections: [FavoCollectionSummary]
    let visibleVisitCount: Int
    let activePeopleCount: Int
    let activePlaceCount: Int

    var primaryFavorite: FavoPersonSnapshot? {
        favorites.first(where: { $0.profile.isPrimary }) ?? favorites.first
    }

    static func make(
        profiles: [FavoriteProfile],
        pins: [FavoPin],
        people: [PersonMaster],
        links: [EventPersonLink],
        visits: [Visit],
        plans: [Plan],
        activePlaceCount: Int,
        now: Date = Date()
    ) -> FavoSnapshot {
        let activePeople = people.filter { !$0.isArchived }
        let activePersonIDs = Set(activePeople.map(\.id))
        let activeLinks = links.filter {
            !$0.isArchived && $0.person.map { activePersonIDs.contains($0.id) } == true
        }
        let visibleVisits = Self.uniqueVisits(
            visits.filter { $0.event?.isArchived != true }
        )
        let linksByPersonID = Dictionary(grouping: activeLinks.compactMap { link in
            link.person.map { ($0.id, link) }
        }, by: \.0)
        .mapValues { $0.map(\.1) }
        let visitsByID = Dictionary(uniqueKeysWithValues: visibleVisits.map { ($0.id, $0) })
        let visitsByEventID = Dictionary(grouping: visibleVisits.compactMap { visit in
            visit.event.map { ($0.id, visit) }
        }, by: \.0)
        .mapValues { $0.map(\.1) }
        let activePlans = plans.filter { !$0.isArchived }
        let plansByEventID = Dictionary(grouping: activePlans.compactMap { plan in
            plan.event.map { ($0.id, plan) }
        }, by: \.0)
        .mapValues { $0.map(\.1) }
        let startOfToday = Calendar.current.startOfDay(for: now)

        let favorites = profiles.compactMap { profile -> FavoPersonSnapshot? in
            guard profile.isFavorite,
                  let person = profile.person,
                  !person.isArchived else { return nil }

            let personLinks = linksByPersonID[person.id] ?? []
            let eventIDs = Set(personLinks.compactMap { $0.event?.id })
            let directVisitIDs = Set(personLinks.compactMap { $0.visit?.id })
            let eventVisits = eventIDs.flatMap { visitsByEventID[$0] ?? [] }
            let directVisits = directVisitIDs.compactMap { visitsByID[$0] }
            let relatedVisits = Self.uniqueVisits(eventVisits + directVisits)
            let relatedPlans = eventIDs.flatMap { plansByEventID[$0] ?? [] }.filter { plan in
                plan.startsAt >= startOfToday
            }
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return FavoPersonSnapshot(
                profile: profile,
                person: person,
                visits: relatedVisits,
                upcomingPlans: relatedPlans,
                categorySummaries: Self.categorySummaries(for: relatedVisits),
                frequentPlaces: Self.frequentPlaces(for: relatedVisits),
                photoCount: relatedVisits.reduce(0) { partialResult, visit in
                    partialResult + (visit.photos ?? []).filter {
                        $0.mediaKind == "photo" && $0.hasStoredData
                    }.count
                },
                spendingBreakdown: FavoSpendingBreakdown.make(visits: relatedVisits)
            )
        }
        .sorted { lhs, rhs in
            if lhs.profile.isPrimary != rhs.profile.isPrimary { return lhs.profile.isPrimary }
            if lhs.profile.isPinned != rhs.profile.isPinned { return lhs.profile.isPinned }
            if lhs.profile.sortOrder != rhs.profile.sortOrder { return lhs.profile.sortOrder < rhs.profile.sortOrder }
            return lhs.person.displayName.localizedStandardCompare(rhs.person.displayName) == .orderedAscending
        }

        let favoritesByPersonID = Dictionary(uniqueKeysWithValues: favorites.map { ($0.person.id, $0) })
        let profilesByTargetKey = Dictionary(
            profiles.compactMap { profile -> (String, FavoriteProfile)? in
                guard let targetID = profile.targetID else { return nil }
                return ("\(profile.targetKind.rawValue):\(targetID.uuidString)", profile)
            },
            uniquingKeysWith: { current, candidate in
                current.updatedAt >= candidate.updatedAt ? current : candidate
            }
        )
        var usedTargets = Set<String>()
        let pinnedTargets = pins
            .filter(\.isValid)
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .compactMap { pin -> FavoPinnedTargetSnapshot? in
                guard let targetID = pin.targetID else { return nil }
                let targetKey = "\(pin.targetKind.rawValue):\(targetID.uuidString)"
                guard usedTargets.insert(targetKey).inserted else { return nil }
                let targetProfile = profilesByTargetKey[targetKey]

                switch pin.targetKind {
                case .person:
                    guard let person = pin.person, !person.isArchived else { return nil }
                    let favorite = favoritesByPersonID[person.id]
                    let personLinks = linksByPersonID[person.id] ?? []
                    let eventIDs = Set(personLinks.compactMap { $0.event?.id })
                    let directVisitIDs = Set(personLinks.compactMap { $0.visit?.id })
                    let relatedVisits = favorite?.visits ?? Self.uniqueVisits(
                        eventIDs.flatMap { visitsByEventID[$0] ?? [] }
                            + directVisitIDs.compactMap { visitsByID[$0] }
                    )
                    let relatedPlans = favorite?.upcomingPlans ?? eventIDs
                        .flatMap { plansByEventID[$0] ?? [] }
                        .filter { $0.startsAt >= startOfToday }
                        .sorted { lhs, rhs in
                            if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                            return lhs.id.uuidString < rhs.id.uuidString
                        }
                    let profileTitle = favorite?.displayName ?? person.displayName
                    return FavoPinnedTargetSnapshot(
                        pin: pin,
                        profile: targetProfile,
                        kind: .person,
                        title: Self.preferredTitle(targetProfile?.nickname ?? pin.customTitle, fallback: profileTitle),
                        subtitle: "人物・団体 · \(relatedVisits.count)件",
                        iconSymbol: "person.fill",
                        colorHex: targetProfile?.colorHex ?? favorite?.profile.colorHex ?? "#8F5E73",
                        visits: relatedVisits,
                        upcomingPlans: relatedPlans,
                        spendingBreakdown: favorite?.spendingBreakdown ?? FavoSpendingBreakdown.make(visits: relatedVisits),
                        personSnapshot: favorite
                    )
                case .event:
                    guard let event = pin.event, !event.isArchived else { return nil }
                    let relatedVisits = Self.uniqueVisits(visitsByEventID[event.id] ?? [])
                    let relatedPlans = (plansByEventID[event.id] ?? [])
                        .filter { $0.startsAt >= startOfToday }
                        .sorted { $0.startsAt < $1.startsAt }
                    return FavoPinnedTargetSnapshot(
                        pin: pin,
                        profile: targetProfile,
                        kind: .event,
                        title: Self.preferredTitle(targetProfile?.nickname ?? pin.customTitle, fallback: event.title.isEmpty ? "無題の作品" : event.title),
                        subtitle: "\(event.category?.name ?? "作品・体験") · \(relatedVisits.count)件",
                        iconSymbol: event.category?.iconSymbol ?? "sparkles.rectangle.stack",
                        colorHex: targetProfile?.colorHex ?? event.category?.colorHex ?? "#147C88",
                        visits: relatedVisits,
                        upcomingPlans: relatedPlans,
                        spendingBreakdown: FavoSpendingBreakdown.make(visits: relatedVisits),
                        personSnapshot: nil
                    )
                case .place:
                    guard let place = pin.place, !place.isArchived else { return nil }
                    let relatedVisits = Self.uniqueVisits(visibleVisits.filter { $0.placeMaster?.id == place.id })
                    let relatedPlans = activePlans
                        .filter { $0.placeMaster?.id == place.id && $0.startsAt >= startOfToday }
                        .sorted { $0.startsAt < $1.startsAt }
                    let location = place.prefecture.isEmpty ? "場所" : place.prefecture
                    let placeContext = place.isClosed ? "閉館 · \(location)" : location
                    return FavoPinnedTargetSnapshot(
                        pin: pin,
                        profile: targetProfile,
                        kind: .place,
                        title: Self.preferredTitle(targetProfile?.nickname ?? pin.customTitle, fallback: place.name.isEmpty ? "名称未設定の場所" : place.name),
                        subtitle: "\(placeContext) · \(relatedVisits.count)件",
                        iconSymbol: "mappin.and.ellipse",
                        colorHex: targetProfile?.colorHex ?? "#2F7FB8",
                        visits: relatedVisits,
                        upcomingPlans: relatedPlans,
                        spendingBreakdown: FavoSpendingBreakdown.make(visits: relatedVisits),
                        personSnapshot: nil
                    )
                }
            }
            .prefix(4)

        return FavoSnapshot(
            favorites: favorites,
            pinnedTargets: Array(pinnedTargets),
            stories: Self.stories(for: visibleVisits, now: now),
            collections: Self.collections(for: visibleVisits, now: now),
            visibleVisitCount: visibleVisits.count,
            activePeopleCount: activePeople.count,
            activePlaceCount: activePlaceCount
        )
    }

    private static func preferredTitle(_ customTitle: String, fallback: String) -> String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func stories(for visits: [Visit], now: Date) -> [FavoStorySnapshot] {
        guard let latestVisit = visits.first else { return [] }

        var stories: [FavoStorySnapshot] = []
        var usedVisitIDs = Set<UUID>()

        func append(label: String, title: String, visit: Visit) {
            guard usedVisitIDs.insert(visit.id).inserted else { return }
            stories.append(
                FavoStorySnapshot(
                    id: "\(label)-\(visit.id.uuidString)",
                    label: label,
                    title: title,
                    visit: visit
                )
            )
        }

        append(label: "LATEST", title: "いちばん新しい思い出", visit: latestVisit)

        if let firstVisit = visits.last {
            append(label: "FIRST", title: "記録のはじまり", visit: firstVisit)
        }

        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: now)
        let targetDay = calendar.component(.day, from: now)
        let targetYear = calendar.component(.year, from: now)
        if let onThisDayVisit = visits.first(where: { visit in
            calendar.component(.year, from: visit.visitedAt) < targetYear
                && calendar.component(.month, from: visit.visitedAt) == targetMonth
                && calendar.component(.day, from: visit.visitedAt) == targetDay
        }) {
            append(label: "ON THIS DAY", title: "過去の今日", visit: onThisDayVisit)
        }

        return stories
    }

    private static func collections(for visits: [Visit], now: Date) -> [FavoCollectionSummary] {
        guard !visits.isEmpty else { return [] }

        var summaries: [FavoCollectionSummary] = []
        let photoVisits = visits.filter { visit in
            (visit.photos ?? []).contains {
                $0.mediaKind == "photo" && $0.hasStoredData
            }
        }
        let photoCount = photoVisits.reduce(0) { result, visit in
            result + (visit.photos ?? []).filter {
                $0.mediaKind == "photo" && $0.hasStoredData
            }.count
        }
        if photoCount > 0 {
            summaries.append(
                FavoCollectionSummary(
                    id: "photos",
                    title: "写真で振り返る",
                    value: "\(photoCount)枚",
                    detail: "\(photoVisits.count)件の思い出から",
                    iconSymbol: "photo.on.rectangle.angled",
                    colorHex: "#8A5FA8",
                    visits: photoVisits
                )
            )
        }

        if let favoritePlace = frequentPlaces(for: visits).first {
            let placeVisits = visits.filter {
                placeIdentity(for: $0)?.id == favoritePlace.id
            }
            summaries.append(
                FavoCollectionSummary(
                    id: "places",
                    title: "よく行く場所",
                    value: favoritePlace.name,
                    detail: "\(favoritePlace.count)回訪れています",
                    iconSymbol: "mappin.and.ellipse",
                    colorHex: "#2F7FB8",
                    visits: placeVisits
                )
            )
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentYearVisits = visits.filter {
            calendar.component(.year, from: $0.visitedAt) == currentYear
        }
        if !currentYearVisits.isEmpty {
            summaries.append(
                FavoCollectionSummary(
                    id: "current-year",
                    title: "今年の思い出",
                    value: "\(currentYearVisits.count)件",
                    detail: "\(currentYear)年",
                    iconSymbol: "calendar",
                    colorHex: "#B66A45",
                    visits: currentYearVisits
                )
            )
        }

        let categoryIDs = Set(visits.compactMap { $0.event?.category?.id })
        let hasUncategorized = visits.contains { $0.event?.category == nil }
        let categoryCount = categoryIDs.count + (hasUncategorized ? 1 : 0)
        summaries.append(
            FavoCollectionSummary(
                id: "categories",
                title: "ジャンルを越えて",
                value: "\(categoryCount)ジャンル",
                detail: "\(visits.count)件の思い出",
                iconSymbol: "square.grid.2x2",
                colorHex: "#147C88",
                visits: visits
            )
        )

        return summaries
    }

    private static func uniqueVisits(_ visits: [Visit]) -> [Visit] {
        var seenIDs = Set<UUID>()
        return visits
            .filter { seenIDs.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.visitedAt != rhs.visitedAt { return lhs.visitedAt > rhs.visitedAt }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private static func categorySummaries(for visits: [Visit]) -> [FavoCategorySummary] {
        struct CategoryValue {
            let name: String
            let iconSymbol: String
            let colorHex: String
            var count: Int
        }

        var values: [String: CategoryValue] = [:]
        for visit in visits {
            if let category = visit.event?.category {
                let key = category.id.uuidString
                let current = values[key]
                values[key] = CategoryValue(
                    name: category.name,
                    iconSymbol: category.iconSymbol,
                    colorHex: category.colorHex,
                    count: (current?.count ?? 0) + 1
                )
            } else {
                let key = "uncategorized"
                let current = values[key]
                values[key] = CategoryValue(
                    name: "未分類",
                    iconSymbol: "square.dashed",
                    colorHex: "#7A7A7A",
                    count: (current?.count ?? 0) + 1
                )
            }
        }

        return values.map { key, value in
            FavoCategorySummary(
                id: key,
                name: value.name,
                iconSymbol: value.iconSymbol,
                colorHex: value.colorHex,
                count: value.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func frequentPlaces(for visits: [Visit]) -> [FavoPlaceSummary] {
        struct PlaceValue {
            let name: String
            var count: Int
        }

        var values: [String: PlaceValue] = [:]
        for visit in visits {
            guard let place = placeIdentity(for: visit) else { continue }
            let current = values[place.id]
            values[place.id] = PlaceValue(name: current?.name ?? place.name, count: (current?.count ?? 0) + 1)
        }

        return values.map { key, value in
            FavoPlaceSummary(id: key, name: value.name, count: value.count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func placeIdentity(for visit: Visit) -> (id: String, name: String)? {
        let placeName = visit.placeMaster?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let venueName = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = placeName.isEmpty ? venueName : placeName
        guard !displayName.isEmpty else { return nil }

        let id = visit.placeMaster.map { "place:\($0.id.uuidString)" }
            ?? "venue:\(normalizedPlaceName(displayName))"
        return (id, displayName)
    }

    private static func normalizedPlaceName(_ name: String) -> String {
        let folded = name.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        return String(folded.filter { !$0.isWhitespace })
    }
}
