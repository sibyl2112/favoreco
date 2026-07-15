import Foundation

struct HomeSnapshot {
    let visibleCategories: [RecordCategory]
    let visibleVisits: [Visit]
    let recentVisits: [Visit]
    let interestedEvents: [ExperienceEvent]
    let unresolvedInboxItems: [InboxItem]
    let upcomingItems: [HomeUpcomingItem]
    let activeTicketAttempts: [TicketAttempt]
    let expiringTicketAccounts: [TicketAccount]
    let currentYearVisitCount: Int

    var upcomingItemCount: Int { upcomingItems.count }

    static func make(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        visits: [Visit],
        inboxItems: [InboxItem],
        plans: [Plan],
        ticketAttempts: [TicketAttempt],
        ticketAccounts: [TicketAccount],
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
        let upcomingItems = (
            upcomingPlans.map(HomeUpcomingItem.plan)
                + futureVisits.map(HomeUpcomingItem.visit)
        )
        .sorted { $0.startsAt < $1.startsAt }
        let warningLimit = calendar.date(byAdding: .day, value: 45, to: now) ?? now
        let currentYear = calendar.component(.year, from: now)

        return HomeSnapshot(
            visibleCategories: visibleCategories,
            visibleVisits: visibleVisits,
            recentVisits: Array(visibleVisits.prefix(8)),
            interestedEvents: events.filter { !$0.isArchived && $0.stateKey == "interested" },
            unresolvedInboxItems: inboxItems.filter { $0.state == "unresolved" },
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
}

enum HomeUpcomingItem: Identifiable {
    case plan(Plan)
    case visit(Visit)

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
