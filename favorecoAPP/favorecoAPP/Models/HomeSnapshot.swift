import Foundation

struct HomeSnapshot {
    let visibleCategories: [RecordCategory]
    let visibleVisitCount: Int
    let recentVisits: [HomeVisitSnapshot]
    let interestedEvents: [HomeInterestedEventSnapshot]
    let unresolvedInboxItems: [HomeInboxItemSnapshot]
    let upcomingItems: [HomeUpcomingItem]
    let activeTicketAttempts: [TicketAttempt]
    let expiringTicketAccounts: [TicketAccount]
    let currentYearVisitCount: Int

    var upcomingItemCount: Int { upcomingItems.count }

    @MainActor
    static func make(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        visits: [Visit],
        inboxItems: [InboxItem],
        plans: [Plan],
        ticketAttempts: [TicketAttempt],
        ticketAccounts: [TicketAccount],
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
        let warningLimit = calendar.date(byAdding: .day, value: 45, to: now) ?? now
        let currentYear = calendar.component(.year, from: now)

        return HomeSnapshot(
            visibleCategories: visibleCategories,
            visibleVisitCount: visibleVisits.count,
            recentVisits: visitSnapshots,
            interestedEvents: events
                .filter { !$0.isArchived && $0.stateKey == "interested" }
                .map(HomeInterestedEventSnapshot.init),
            unresolvedInboxItems: inboxItems
                .filter { $0.state == "unresolved" }
                .map { HomeInboxItemSnapshot(item: $0, categories: visibleCategories) },
            upcomingItems: upcomingItems,
            activeTicketAttempts: ticketAttempts.filter { attempt in
                !attempt.isArchived
                    && attempt.plan?.isArchived != true
                    && !["lost", "attended", "skipped"].contains(attempt.statusKey)
            },
            expiringTicketAccounts: ticketAccounts.filter { account in
                !account.isArchived
                    && account.renewalNotify
                    && account.expiryDate != Date.distantPast
                    && account.expiryDate >= now
                    && account.expiryDate <= warningLimit
            },
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
    let photo: HomePhotoSnapshot?

    init(visit: Visit, peopleSummary: String) {
        let category = visit.event?.category
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let photos = (visit.photos ?? []).filter { $0.mediaKind == "photo" && $0.hasStoredData }
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
        photo = selectedPhoto.map { HomePhotoSnapshot(photo: $0) }
    }
}

struct HomePhotoSnapshot {
    let id: UUID
    let data: Data

    init(photo: PhotoBlob) {
        id = photo.id
        data = photo.data
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
    let posterData: Data?
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
        posterData = plan.event?.eyecatchData
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
    let hasOfficialURL: Bool
    let memo: String
    let eyecatchData: Data?
    let eyecatchAspectRatio: Double
    let fillsEyecatchFrame: Bool

    init(event: ExperienceEvent) {
        id = event.id
        title = event.title.isEmpty ? "無題" : event.title
        categoryName = event.category?.name
        categoryIcon = event.category?.iconSymbol
        hasOfficialURL = !event.officialURL.isEmpty
        memo = event.memo
        eyecatchData = event.eyecatchData
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
    let createdAt: Date
    let eyecatchData: Data?

    init(item: InboxItem, categories: [RecordCategory]) {
        id = item.id
        title = item.title.isEmpty ? "無題" : item.title
        body = item.body
        hasSourceURL = !item.sourceURL.isEmpty
        categoryName = categories.first(where: { $0.templateKey == item.targetTemplateKey })?.name
        createdAt = item.createdAt
        eyecatchData = item.eyecatchData
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
