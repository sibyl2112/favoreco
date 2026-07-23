import Foundation
import CoreGraphics

struct TheaterPerformanceScheduleItem: Identifiable, Equatable {
    let id: String
    let performanceLabel: String
    let startsAt: Date?
    let endsAt: Date?
    let venueName: String
    let address: String
}

enum DetailBackSwipePolicy {
    static func shouldClose(
        startLocation: CGPoint,
        translation: CGSize,
        predictedEndTranslation: CGSize,
        exclusionFrames: [CGRect]
    ) -> Bool {
        guard startLocation.x <= 32 else { return false }
        guard !exclusionFrames.contains(where: { $0.contains(startLocation) }) else { return false }
        let horizontalDistance = translation.width
        let verticalDistance = abs(translation.height)
        return horizontalDistance >= 72
            && horizontalDistance > verticalDistance * 1.35
            && predictedEndTranslation.width >= 110
    }
}

enum EventDetailPresentation {
    static func theaterPeriodText(event: ExperienceEvent, fields: VisitUnitFields) -> String {
        let schedules = theaterSchedules(event: event, fields: fields)
        let plans = (event.plans ?? []).filter { !$0.isArchived }
        let visits = event.visits ?? []
        let fallbackDates = plans.flatMap { [$0.startsAt, $0.endsAt] }
            + visits.flatMap { [$0.visitedAt, max($0.endedAt, $0.visitedAt)] }
        let scheduleStarts = schedules.compactMap(\.startsAt)
        let scheduleEnds = schedules.compactMap { $0.endsAt ?? $0.startsAt }
        let hasExplicitScheduleDates = fields.eventVenues.contains {
            $0.startsAt != nil || $0.endsAt != nil
        }
        let start = hasExplicitScheduleDates
            ? scheduleStarts.min()
            : fields.eventPeriodStartsAt ?? fallbackDates.min()
        let end = hasExplicitScheduleDates
            ? scheduleEnds.max()
            : fields.eventPeriodEndsAt ?? fallbackDates.max()
        guard let start else { return "公演期間 未登録" }
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(start)
        }
        return "\(FavorecoDateText.compactDate(start))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
    }

    static func theaterVenues(event: ExperienceEvent, fields: VisitUnitFields) -> [TheaterPublicVenue] {
        let schedules = theaterSchedules(event: event, fields: fields)
        let venues = schedules.map { TheaterPublicVenue(name: $0.venueName, address: $0.address) }
        return venues.isEmpty
            ? [TheaterPublicVenue(name: "会場 未登録", address: "")]
            : deduplicatedVenues(venues)
    }

    static func theaterSchedules(
        event: ExperienceEvent,
        fields: VisitUnitFields
    ) -> [TheaterPerformanceScheduleItem] {
        let usesLegacySharedPeriod = !fields.eventVenues.isEmpty
            && fields.eventVenues.allSatisfy { $0.startsAt == nil && $0.endsAt == nil }
        let explicit = fields.eventVenues.compactMap { entry -> TheaterPerformanceScheduleItem? in
            guard !entry.trimmedName.isEmpty else { return nil }
            return TheaterPerformanceScheduleItem(
                id: "entry-\(entry.id.uuidString)",
                performanceLabel: entry.trimmedPerformanceLabel,
                startsAt: entry.startsAt ?? (usesLegacySharedPeriod ? fields.eventPeriodStartsAt : nil),
                endsAt: entry.endsAt ?? (usesLegacySharedPeriod ? fields.eventPeriodEndsAt : nil),
                venueName: entry.trimmedName,
                address: entry.trimmedAddress
            )
        }
        if !explicit.isEmpty { return sortedSchedules(explicit) }

        let planSchedules = (event.plans ?? []).filter { !$0.isArchived }.compactMap { plan -> TheaterPerformanceScheduleItem? in
            let name = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TheaterPerformanceScheduleItem(
                id: "plan-\(plan.id.uuidString)",
                performanceLabel: "",
                startsAt: plan.startsAt,
                endsAt: max(plan.endsAt, plan.startsAt),
                venueName: name,
                address: plan.placeMaster?.address ?? ""
            )
        }
        let visitSchedules = (event.visits ?? []).compactMap { visit -> TheaterPerformanceScheduleItem? in
            let name = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TheaterPerformanceScheduleItem(
                id: "visit-\(visit.id.uuidString)",
                performanceLabel: "",
                startsAt: visit.visitedAt,
                endsAt: max(visit.endedAt, visit.visitedAt),
                venueName: name,
                address: visit.placeMaster?.address ?? ""
            )
        }
        return mergedSchedulesByVenue(planSchedules + visitSchedules)
    }

    static func theaterHeroVenueSummary(schedules: [TheaterPerformanceScheduleItem]) -> String {
        guard let only = schedules.first else { return "会場 未登録" }
        guard schedules.count > 1 else { return only.venueName }

        let venueCount = Set(schedules.map { normalizedVenueKey($0.venueName) }).count
        var seenLabels = Set<String>()
        let areaNames = schedules.compactMap { item -> String? in
            let value = item.performanceLabel
                .replacingOccurrences(of: "公演", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let key = value.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            return seenLabels.insert(key).inserted ? value : nil
        }
        guard !areaNames.isEmpty else { return "\(schedules.count)公演地・\(venueCount)会場" }

        let visibleAreas = areaNames.prefix(2).joined(separator: "・")
        let areaSummary = areaNames.count > 2
            ? "\(visibleAreas)・ほか\(areaNames.count - 2)都市"
            : visibleAreas
        return "\(areaSummary)｜\(areaNames.count)都市・\(venueCount)会場"
    }

    static func prioritizedTheaterSchedules(
        _ schedules: [TheaterPerformanceScheduleItem],
        now: Date = Date(),
        limit: Int = 2
    ) -> [TheaterPerformanceScheduleItem] {
        guard schedules.count > limit else { return schedules }
        let active = schedules.filter { item in
            guard let start = item.startsAt else { return false }
            return start <= now && (item.endsAt ?? start) >= now
        }
        let upcoming = schedules.filter { ($0.startsAt ?? .distantPast) > now }
        if !active.isEmpty || !upcoming.isEmpty {
            return Array((sortedSchedules(active) + sortedSchedules(upcoming)).prefix(limit))
        }
        return Array(sortedSchedules(schedules).prefix(limit))
    }

    static func theaterLinks(event: ExperienceEvent, fields: VisitUnitFields) -> [TheaterPublicLink] {
        var result: [TheaterPublicLink] = []
        if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
            result.append(TheaterPublicLink(title: "公式", systemImage: "link", url: url))
        }
        let ticketURLText = (event.plans ?? [])
            .filter { !$0.isArchived }
            .flatMap { $0.ticketAttempts ?? [] }
            .map(\.purchaseURL)
            .first { !$0.isEmpty }
            ?? (event.plans ?? []).map(\.sourceURL).first { !$0.isEmpty }
        if let ticketURLText, let url = URL(string: ticketURLText) {
            result.append(TheaterPublicLink(title: "チケット", systemImage: "ticket", url: url))
        }
        for (index, value) in fields.socialLinks.enumerated() {
            if let url = URL(string: value) {
                result.append(TheaterPublicLink(title: "SNS \(index + 1)", systemImage: "bubble.left.and.bubble.right", url: url))
            }
        }
        return result
    }

    private static func deduplicatedVenues(_ venues: [TheaterPublicVenue]) -> [TheaterPublicVenue] {
        var seen = Set<String>()
        return venues.filter { venue in
            let key = venue.name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            return seen.insert(key).inserted
        }
    }

    private static func sortedSchedules(
        _ schedules: [TheaterPerformanceScheduleItem]
    ) -> [TheaterPerformanceScheduleItem] {
        schedules.sorted { lhs, rhs in
            switch (lhs.startsAt, rhs.startsAt) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.venueName.localizedStandardCompare(rhs.venueName) == .orderedAscending
            }
        }
    }

    private static func mergedSchedulesByVenue(
        _ schedules: [TheaterPerformanceScheduleItem]
    ) -> [TheaterPerformanceScheduleItem] {
        Dictionary(grouping: schedules, by: { normalizedVenueKey($0.venueName) })
            .map { key, grouped in
                let ordered = sortedSchedules(grouped)
                let first = ordered[0]
                return TheaterPerformanceScheduleItem(
                    id: "fallback-\(key)",
                    performanceLabel: "",
                    startsAt: grouped.compactMap(\.startsAt).min(),
                    endsAt: grouped.compactMap { $0.endsAt ?? $0.startsAt }.max(),
                    venueName: first.venueName,
                    address: grouped.first(where: { !$0.address.isEmpty })?.address ?? ""
                )
            }
            .sorted { lhs, rhs in
                (lhs.startsAt ?? .distantFuture) < (rhs.startsAt ?? .distantFuture)
            }
    }

    private static func normalizedVenueKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }
}

enum ExperienceDetailPresentation {
    static func performanceTime(for visit: Visit) -> String {
        let start = FavorecoDateText.time(visit.visitedAt)
        guard visit.endedAt > visit.visitedAt else { return start }
        return "\(start)–\(FavorecoDateText.time(visit.endedAt))"
    }

    static func theaterVisitOrdinal(for visit: Visit) -> String {
        guard let visits = visit.event?.visits else { return "観劇1回目" }
        let ordered = visits.sorted {
            if $0.visitedAt != $1.visitedAt { return $0.visitedAt < $1.visitedAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let ordinal = (ordered.firstIndex(where: { $0.id == visit.id }) ?? 0) + 1
        return "観劇\(ordinal)回目"
    }

    static func compactWeatherText(fields: VisitUnitFields) -> String {
        guard let high = fields.weatherHighCelsius, let low = fields.weatherLowCelsius else { return "" }
        return "\(Int(high.rounded()))°/\(Int(low.rounded()))°"
    }

    static func ratingSymbol(rating: Double, index: Int) -> String {
        let threshold = Double(index)
        if rating >= threshold { return "star.fill" }
        if rating >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    static func securedTicketAttempts(in plan: Plan?) -> [TicketAttempt] {
        let securedStatusKeys: Set<String> = ["won", "waitingPayment", "waitingIssue", "issued", "attended"]
        return TicketAttemptPresentationOrder.sorted(
            (plan?.ticketAttempts ?? []).filter {
                !$0.isArchived && securedStatusKeys.contains($0.statusKey)
            }
        )
    }

    static func roleName(for roleKey: String) -> String {
        switch roleKey {
        case "actor": "俳優"
        case "artist": "アーティスト"
        case "cast": "出演"
        case "lead": "主演"
        case "writer": "作家"
        case "author": "作者"
        case "director": "監督"
        case "screenplay": "脚本"
        case "stage_director": "演出"
        case "original_work": "原作"
        case "music": "音楽"
        case "choreography": "振付"
        case "conductor": "指揮"
        case "performer": "演奏"
        case "replacement": "代役"
        case "daily_guest": "日替わりゲスト"
        case "stage_design": "美術"
        case "lighting": "照明"
        case "sound": "音響"
        case "costume": "衣裳"
        case "hair_makeup": "ヘアメイク"
        case "stage_manager": "舞台監督"
        case "translator": "翻訳"
        case "curator": "キュレーター"
        case "organizer": "主催"
        case "production": "制作"
        case "publisher": "出版社"
        case "guest": "ゲスト"
        default: "その他"
        }
    }

    static func isTheaterCastLink(_ link: EventPersonLink) -> Bool {
        TheaterVisitCastResolver.isCastLink(link)
    }

    static func personName(for link: EventPersonLink) -> String {
        let snapshotName = link.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshotName.isEmpty { return snapshotName }
        let masterName = link.person?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return masterName.isEmpty ? "出演者" : masterName
    }
}
