import Foundation

struct HomeSnapshot {
    let visibleCategoryCount: Int
    let visibleVisitCount: Int
    let recentVisits: [HomeVisitSnapshot]
    let interestedEvents: [HomeInterestedEventSnapshot]
    let unresolvedInboxItems: [HomeInboxItemSnapshot]
    let heroItems: [HomeUpcomingItem]
    let upcomingItems: [HomeUpcomingItem]
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
        let visibleVisits = visits.filter { $0.event?.isArchived != true }
        let upcomingPlans = plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
        let today = calendar.startOfDay(for: now)
        let linkedVisitIDs = Set(upcomingPlans.compactMap { $0.visit?.id })
        let futureVisits = visibleVisits.filter { visit in
            calendar.startOfDay(for: visit.visitedAt) >= today
                && !linkedVisitIDs.contains(visit.id)
        }
        let visitSnapshots = visibleVisits.prefix(8).map {
            HomeVisitSnapshot(visit: $0, peopleSummary: peopleSummary(for: $0, links: personLinks))
        }
        let futureVisitSnapshots = futureVisits.map {
            HomeVisitSnapshot(visit: $0, peopleSummary: peopleSummary(for: $0, links: personLinks))
        }
        let upcomingItems = (
            upcomingPlans.map { HomeUpcomingItem.plan(HomePlanSnapshot(plan: $0)) }
                + futureVisitSnapshots.map(HomeUpcomingItem.visit)
        )
        .sorted { $0.startsAt < $1.startsAt }
        let recentHeroVisits = visitSnapshots
            .filter { calendar.startOfDay(for: $0.visitedAt) < today }
            .prefix(5)
            .map(HomeUpcomingItem.visit)
        let heroItems = Array(upcomingItems.prefix(5)) + recentHeroVisits
        let currentYear = calendar.component(.year, from: now)

        return HomeSnapshot(
            visibleCategoryCount: visibleCategories.count,
            visibleVisitCount: visibleVisits.count,
            recentVisits: visitSnapshots,
            interestedEvents: events
                .filter { !$0.isArchived && $0.stateKey == "interested" }
                .map(HomeInterestedEventSnapshot.init),
            unresolvedInboxItems: inboxItems
                .filter { $0.state == "unresolved" }
                .map { HomeInboxItemSnapshot(item: $0, categories: visibleCategories) },
            heroItems: heroItems,
            upcomingItems: upcomingItems,
            upcomingItemCount: upcomingItems.count,
            currentYearVisitCount: visibleVisits.filter {
                calendar.component(.year, from: $0.visitedAt) == currentYear
            }.count
        )
    }

    @MainActor
    private static func peopleSummary(for visit: Visit, links: [EventPersonLink]) -> String {
        links
            .filter { link in
                !link.isArchived && (link.event?.id == visit.event?.id || link.visit?.id == visit.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(2)
            .map { link in
                link.nameSnapshot.isEmpty ? link.person?.displayName ?? "" : link.nameSnapshot
            }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }
}

struct HomeVisitSnapshot: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String
    let categoryIcon: String
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

    init(visit: Visit, peopleSummary: String) {
        let category = visit.event?.category
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let photos = (visit.photos ?? []).filter { $0.mediaKind == "photo" }
        let selectedPhoto: PhotoBlob?
        if !visit.eyecatchPath.isEmpty,
           let cover = photos.first(where: { $0.relativePath == visit.eyecatchPath }) {
            selectedPhoto = cover
        } else {
            selectedPhoto = photos.min { $0.createdAt < $1.createdAt }
        }

        id = visit.id
        title = visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
        categoryName = category?.name ?? "記録"
        categoryIcon = category?.iconSymbol ?? "sparkles.rectangle.stack"
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
        thumbnailReference = selectedPhoto.map { .photo($0.id) }
    }
}

struct HomePlanSnapshot: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let categoryName: String
    let categoryIcon: String
    let categoryColorHex: String
    let startsAt: Date
    let venueName: String
    let organizerName: String
    let thumbnailReference: ThumbnailReference?
    let posterAspectRatio: Double
    let fillsPosterFrame: Bool

    init(plan: Plan) {
        let category = plan.category ?? plan.event?.category
        id = plan.id
        title = plan.title.isEmpty ? plan.event?.title ?? "予定" : plan.title
        subtitle = plan.subtitle
        categoryName = category?.name ?? "予定"
        categoryIcon = category?.iconSymbol ?? "calendar"
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
    }
}

struct HomeInterestedEventSnapshot: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String?
    let categoryIcon: String?
    let categoryColorHex: String
    let hasOfficialURL: Bool
    let memo: String
    let thumbnailReference: ThumbnailReference
    let eyecatchAspectRatio: Double
    let fillsEyecatchFrame: Bool

    init(event: ExperienceEvent) {
        id = event.id
        title = event.title.isEmpty ? "無題" : event.title
        categoryName = event.category?.name
        categoryIcon = event.category?.iconSymbol
        categoryColorHex = event.category?.colorHex ?? "#147C88"
        hasOfficialURL = !event.officialURL.isEmpty
        memo = event.memo
        thumbnailReference = .event(event.id)
        eyecatchAspectRatio = EyecatchAspectRatio.resolved(for: event).value
        fillsEyecatchFrame = EyecatchAspectRatio.usesEyecatchFill(for: event.category)
    }
}

struct HomeInboxItemSnapshot: Identifiable {
    let id: UUID
    let title: String
    let body: String
    let hasSourceURL: Bool
    let categoryName: String?
    let categoryIcon: String?
    let categoryColorHex: String
    let createdAt: Date
    let thumbnailReference: ThumbnailReference

    init(item: InboxItem, categories: [RecordCategory]) {
        id = item.id
        title = item.title.isEmpty ? "無題" : item.title
        body = item.body
        hasSourceURL = !item.sourceURL.isEmpty
        let category = categories.first(where: { $0.templateKey == item.targetTemplateKey })
        categoryName = category?.name
        categoryIcon = category?.iconSymbol
        categoryColorHex = category?.colorHex ?? "#147C88"
        createdAt = item.createdAt
        thumbnailReference = .inbox(item.id)
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
