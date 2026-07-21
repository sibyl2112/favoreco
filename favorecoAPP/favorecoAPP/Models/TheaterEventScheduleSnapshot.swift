import Foundation

struct TheaterEventTicketReference: Identifiable {
    let plan: Plan
    let attempt: TicketAttempt

    var id: UUID { attempt.id }
}

struct TheaterEventScheduleSnapshot {
    let upcomingPlans: [Plan]
    let ticketReferences: [TheaterEventTicketReference]

    static func make(event: ExperienceEvent, now: Date = Date()) -> TheaterEventScheduleSnapshot {
        let plans = (event.plans ?? [])
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                let lhsIsUpcoming = lhs.startsAt >= now
                let rhsIsUpcoming = rhs.startsAt >= now
                if lhsIsUpcoming != rhsIsUpcoming { return lhsIsUpcoming }
                return lhsIsUpcoming
                    ? lhs.startsAt < rhs.startsAt
                    : lhs.startsAt > rhs.startsAt
            }

        let upcomingPlans = plans.filter { $0.startsAt >= now }
        let ticketReferences = plans.flatMap { plan in
            TicketAttemptPresentationOrder.sorted(
                (plan.ticketAttempts ?? []).filter { !$0.isArchived },
                now: now
            )
            .map { TheaterEventTicketReference(plan: plan, attempt: $0) }
        }

        return TheaterEventScheduleSnapshot(
            upcomingPlans: upcomingPlans,
            ticketReferences: ticketReferences
        )
    }
}
