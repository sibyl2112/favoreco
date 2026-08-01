import Foundation

struct HomeSnapshot {
    let visibleCategoryCount: Int
    let visibleVisitCount: Int
    let recentVisits: [HomeVisitSnapshot]
    let reportVisits: [HomeVisitSnapshot]
    let interestedEvents: [HomeInterestedEventSnapshot]
    let unresolvedInboxItems: [HomeInboxItemSnapshot]
    let heroItems: [HomeUpcomingItem]
    let upcomingItems: [HomeUpcomingItem]
    let pickupRecordedVisits: [HomeVisitSnapshot]
    let upcomingItemCount: Int
    let currentYearVisitCount: Int

    @MainActor
    static func make(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        visits: [Visit],
        inboxItems: [InboxItem],
        plans: [Plan],
        personLinks: [EventPersonLink],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeSnapshot {
        let visibleCategories = categories.filter { !$0.isArchived }
        let visibleVisits = visits
            .filter { $0.event?.isArchived != true }
            .sorted { $0.visitedAt > $1.visitedAt }
        let upcomingPlans = plans
            .filter { !$0.isArchived && $0.hasConfirmedSchedule && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
        let eventIDsWithActivePlans = Set(plans.compactMap { plan -> UUID? in
            guard !plan.isArchived, let eventID = plan.event?.id else { return nil }
            let hasUpcomingSchedule = plan.hasConfirmedSchedule && plan.endsAt >= now
            let hasActiveTicket = (plan.ticketAttempts ?? []).contains { attempt in
                !attempt.isArchived
                    && !["lost", "attended", "skipped"].contains(attempt.statusKey)
            }
            return hasUpcomingSchedule || hasActiveTicket ? eventID : nil
        })
        let today = calendar.startOfDay(for: now)
        let linkedVisitIDs = Set(upcomingPlans.compactMap { $0.visit?.id })
        let futureVisits = visibleVisits.filter { visit in
            calendar.startOfDay(for: visit.visitedAt) >= today
                && !linkedVisitIDs.contains(visit.id)
        }
        let peopleIndex = HomePeopleSummaryIndex(links: personLinks)
        let allVisitSnapshots = visibleVisits.map {
            HomeVisitSnapshot(visit: $0, peopleSummary: peopleIndex.summary(for: $0))
        }
        let visitSnapshots = Array(allVisitSnapshots.prefix(8))
        let futureVisitSnapshots = futureVisits.map {
            HomeVisitSnapshot(visit: $0, peopleSummary: peopleIndex.summary(for: $0))
        }
        let upcomingItems = (
            upcomingPlans.map { HomeUpcomingItem.plan(HomePlanSnapshot(plan: $0)) }
                + futureVisitSnapshots.map(HomeUpcomingItem.visit)
        )
        .sorted { $0.startsAt < $1.startsAt }
        let recentHeroVisits = allVisitSnapshots
            .filter { calendar.startOfDay(for: $0.visitedAt) < today }
            .prefix(5)
            .map(HomeUpcomingItem.visit)
        let heroItems = Array(upcomingItems.prefix(5)) + recentHeroVisits
        let pickupRecordedVisits = Array(
            allVisitSnapshots
                .filter { $0.visitedAt <= now }
                .prefix(10)
        )
        let currentYear = calendar.component(.year, from: now)

        return HomeSnapshot(
            visibleCategoryCount: visibleCategories.count,
            visibleVisitCount: visibleVisits.count,
            recentVisits: visitSnapshots,
            reportVisits: allVisitSnapshots,
            interestedEvents: events
                .filter {
                    !$0.isArchived
                        && $0.stateKey == "interested"
                        && !eventIDsWithActivePlans.contains($0.id)
                }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(10)
                .map(HomeInterestedEventSnapshot.init),
            unresolvedInboxItems: inboxItems
                .filter { $0.state == "unresolved" }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(10)
                .map { HomeInboxItemSnapshot(item: $0, categories: visibleCategories) },
            heroItems: heroItems,
            upcomingItems: Array(upcomingItems.prefix(10)),
            pickupRecordedVisits: pickupRecordedVisits,
            upcomingItemCount: upcomingItems.count,
            currentYearVisitCount: visibleVisits.filter {
                calendar.component(.year, from: $0.visitedAt) == currentYear
            }.count
        )
    }

}

struct HomeVisitSnapshot: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String
    let categoryIcon: String
    let categoryTemplateKey: String
    let categoryColorHex: String
    let visitedAt: Date
    let venueName: String
    let outcomeKey: String
    let note: String
    let amount: Decimal
    let overallRating: Double
    let unitFieldsRaw: String
    let eyecatchPath: String
    let eyecatchAspectRatio: Double
    let fillsEyecatchFrame: Bool
    let peopleSummary: String
    let thumbnailReference: ThumbnailReference?
    let comingUpTimeText: String
    let officialURLString: String

    init(visit: Visit, peopleSummary: String) {
        let category = visit.event?.category
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        id = visit.id
        title = visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
        categoryName = category?.name ?? "記録"
        categoryIcon = category?.iconSymbol ?? "sparkles.rectangle.stack"
        categoryTemplateKey = category?.templateKey ?? ""
        categoryColorHex = category?.colorHex ?? "#147C88"
        visitedAt = visit.visitedAt
        venueName = visit.venueNameSnapshot
        outcomeKey = visit.outcomeKey
        note = visit.note
        amount = visit.amount
        overallRating = visit.overallRating
        unitFieldsRaw = visit.unitFieldsRaw
        eyecatchPath = visit.eyecatchPath
        eyecatchAspectRatio = EyecatchAspectRatio.option(
            for: unitFields.eyecatchAspectRatioKey,
            category: category
        ).value
        fillsEyecatchFrame = EyecatchAspectRatio.usesEyecatchFill(for: category)
        self.peopleSummary = peopleSummary
        thumbnailReference = visit.event.map { .event($0.id) }
        comingUpTimeText = category?.usesOpeningTime == true
            ? "開演 \(FavorecoDateText.time(visit.visitedAt))"
            : ""
        officialURLString = visit.event?.officialURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct HomePlanSnapshot: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let categoryName: String
    let categoryIcon: String
    let categoryTemplateKey: String
    let categoryColorHex: String
    let startsAt: Date
    let venueName: String
    let organizerName: String
    let thumbnailReference: ThumbnailReference?
    let posterAspectRatio: Double
    let fillsPosterFrame: Bool
    let comingUpTimeText: String
    let officialURLString: String

    init(plan: Plan) {
        let category = plan.category ?? plan.event?.category
        id = plan.id
        title = plan.title.isEmpty ? plan.event?.title ?? "予定" : plan.title
        subtitle = plan.subtitle
        categoryName = category?.name ?? "予定"
        categoryIcon = category?.iconSymbol ?? "calendar"
        categoryTemplateKey = category?.templateKey ?? ""
        categoryColorHex = category?.colorHex ?? "#147C88"
        startsAt = plan.startsAt
        venueName = plan.venueNameSnapshot
        organizerName = plan.organizerNameSnapshot.isEmpty
            ? plan.event?.organizerNameSnapshot ?? ""
            : plan.organizerNameSnapshot
        thumbnailReference = plan.event.map { .event($0.id) }
        posterAspectRatio = plan.event.map { EyecatchAspectRatio.resolved(for: $0).value }
            ?? EyecatchAspectRatio.recommended(for: category).value
        fillsPosterFrame = EyecatchAspectRatio.usesEyecatchFill(for: category)
        officialURLString = [
            plan.officialURL,
            plan.event?.officialURL ?? "",
            plan.sourceURL,
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty }) ?? ""
        if category?.usesOpeningTime == true {
            let hasValidOpeningTime = plan.opensAt != Date.distantPast
                && plan.opensAt <= plan.startsAt
                && Calendar.current.isDate(plan.opensAt, inSameDayAs: plan.startsAt)
            comingUpTimeText = hasValidOpeningTime
                ? "開場 \(FavorecoDateText.time(plan.opensAt))"
                : "開演 \(FavorecoDateText.time(plan.startsAt))"
        } else {
            comingUpTimeText = ""
        }
    }
}

struct HomeInterestedEventSnapshot: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String?
    let categoryIcon: String?
    let categoryTemplateKey: String
    let categoryColorHex: String
    let periodText: String
    let venueName: String
    let hasOfficialURL: Bool
    let officialURLString: String
    let memo: String
    let thumbnailReference: ThumbnailReference
    let eyecatchAspectRatio: Double
    let fillsEyecatchFrame: Bool
    let updatedAt: Date

    init(event: ExperienceEvent) {
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        id = event.id
        title = event.title.isEmpty ? "無題" : event.title
        categoryName = event.category?.name
        categoryIcon = event.category?.iconSymbol
        categoryTemplateKey = event.category?.templateKey ?? ""
        categoryColorHex = event.category?.colorHex ?? "#147C88"
        periodText = Self.periodText(fields: fields)
        venueName = fields.eventVenues
            .map(\.trimmedName)
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " / ")
        hasOfficialURL = !event.officialURL.isEmpty
        officialURLString = event.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        memo = event.memo
        thumbnailReference = .event(event.id)
        eyecatchAspectRatio = EyecatchAspectRatio.resolved(for: event).value
        fillsEyecatchFrame = EyecatchAspectRatio.usesEyecatchFill(for: event.category)
        updatedAt = event.updatedAt
    }

    private static func periodText(fields: VisitUnitFields) -> String {
        let explicitStarts = fields.eventVenues.compactMap(\.startsAt)
        let explicitEnds = fields.eventVenues.compactMap { $0.endsAt ?? $0.startsAt }
        let start = explicitStarts.min() ?? fields.eventPeriodStartsAt
        let end = explicitEnds.max() ?? fields.eventPeriodEndsAt

        guard let start else {
            guard let end else { return "" }
            return "〜\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
        }
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(start)
        }
        return "\(FavorecoDateText.compactDate(start))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
    }
}

struct HomeInboxItemSnapshot: Identifiable {
    let id: UUID
    let title: String
    let body: String
    let hasSourceURL: Bool
    let sourceURLString: String
    let categoryName: String?
    let categoryIcon: String?
    let categoryTemplateKey: String
    let categoryColorHex: String
    let createdAt: Date
    let thumbnailReference: ThumbnailReference

    init(item: InboxItem, categories: [RecordCategory]) {
        id = item.id
        title = item.title.isEmpty ? "無題" : item.title
        body = item.body
        hasSourceURL = !item.sourceURL.isEmpty
        sourceURLString = item.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = categories.first(where: { $0.templateKey == item.targetTemplateKey })
        categoryName = category?.name
        categoryIcon = category?.iconSymbol
        categoryTemplateKey = category?.templateKey ?? item.targetTemplateKey
        categoryColorHex = category?.colorHex ?? "#147C88"
        createdAt = item.createdAt
        thumbnailReference = .inbox(item.id)
    }
}

@MainActor
private struct HomePeopleSummaryIndex {
    private let eventLinks: [UUID: [EventPersonLink]]
    private let visitLinks: [UUID: [EventPersonLink]]

    init(links: [EventPersonLink]) {
        var byEvent: [UUID: [EventPersonLink]] = [:]
        var byVisit: [UUID: [EventPersonLink]] = [:]
        for link in links where !link.isArchived {
            if let eventID = link.event?.id {
                byEvent[eventID, default: []].append(link)
            }
            if let visitID = link.visit?.id {
                byVisit[visitID, default: []].append(link)
            }
        }
        eventLinks = byEvent
        visitLinks = byVisit
    }

    func summary(for visit: Visit) -> String {
        let linkedEventPeople: [EventPersonLink]
        if let eventID = visit.event?.id {
            linkedEventPeople = eventLinks[eventID] ?? []
        } else {
            linkedEventPeople = []
        }
        let linkedVisitPeople = visitLinks[visit.id] ?? []
        let links = linkedEventPeople + linkedVisitPeople
        return links
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(2)
            .map { link in
                link.nameSnapshot.isEmpty ? link.person?.displayName ?? "" : link.nameSnapshot
            }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }
}

enum HomeUpcomingItem: Identifiable {
    case plan(HomePlanSnapshot)
    case visit(HomeVisitSnapshot)

    var id: String {
        switch self {
        case .plan(let plan):
            return "plan-\(plan.id.uuidString)"
        case .visit(let visit):
            return "visit-\(visit.id.uuidString)"
        }
    }

    var startsAt: Date {
        switch self {
        case .plan(let plan):
            return plan.startsAt
        case .visit(let visit):
            return visit.visitedAt
        }
    }
}
