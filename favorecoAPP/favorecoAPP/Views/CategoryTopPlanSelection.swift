//
//  CategoryTopPlanSelection.swift
//  favorecoAPP
//
//  Pure plan placement and ordering rules used by CategoryTopView.
//

import Foundation

enum CategoryTopPlanSelection {
    static func ticketManagementPlans(
        from plans: [Plan],
        category: RecordCategory,
        now: Date
    ) -> [Plan] {
        plans
            .filter { plan in
                guard !plan.isArchived,
                      plan.visit == nil,
                      (plan.category ?? plan.event?.category)?.id == category.id else {
                    return false
                }
                guard !plan.hasConfirmedSchedule || plan.isUpcomingOrOngoing(at: now) else {
                    return false
                }
                if category.templateKey == "live" {
                    return (plan.ticketAttempts ?? []).contains {
                        !$0.isArchived
                            && LiveTicketPlacementPolicy.showsInTicketManagement(
                                statusKey: $0.statusKey
                            )
                    }
                }
                return !isTheaterComingUpPlan(plan, now: now)
            }
            .sorted { theaterManagementPlanPrecedes($0, $1, now: now) }
    }

    static func theaterComingUpPlans(
        from plans: [Plan],
        category: RecordCategory,
        now: Date
    ) -> [Plan] {
        plans
            .filter { plan in
                !plan.isArchived
                    && plan.visit == nil
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && isTheaterComingUpPlan(plan, now: now)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    static func liveComingUpPlans(
        from plans: [Plan],
        category: RecordCategory,
        now: Date
    ) -> [Plan] {
        plans
            .filter { plan in
                guard !plan.isArchived,
                      plan.visit == nil,
                      plan.isUpcomingOrOngoing(at: now),
                      (plan.category ?? plan.event?.category)?.id == category.id else {
                    return false
                }
                let activeStatusKeys = (plan.ticketAttempts ?? [])
                    .filter { !$0.isArchived }
                    .map(\.statusKey)
                return LiveTicketPlacementPolicy.allowsComingUp(statusKeys: activeStatusKeys)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    static func upcomingPlans(
        from plans: [Plan],
        category: RecordCategory,
        screenWorkFilter: ScreenWorkFilter,
        now: Date
    ) -> [Plan] {
        plans
            .filter { plan in
                !plan.isArchived
                    && plan.isUpcomingOrOngoing(at: now)
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && (category.templateKey != "movie"
                        || plan.event.map { screenWorkFilter.includes($0.screenWorkType) } != false)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    static func theaterPlanTitle(_ plan: Plan) -> String {
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private static func isTheaterComingUpPlan(_ plan: Plan, now: Date) -> Bool {
        guard plan.isUpcomingOrOngoing(at: now) else { return false }
        let attempts = (plan.ticketAttempts ?? []).filter { !$0.isArchived }
        let hasAcquiredTicket = TicketAcquisitionState.hasAcquiredTicket(in: attempts)
        let hasUnresolvedAttempt = attempts.contains {
            !["interested", "lost", "attended", "skipped", "issued"].contains($0.statusKey)
        }
        return hasAcquiredTicket && !hasUnresolvedAttempt
    }

    private static func theaterManagementPlanPrecedes(
        _ lhs: Plan,
        _ rhs: Plan,
        now: Date
    ) -> Bool {
        let leftAction = theaterManagementNextAction(for: lhs, now: now)
        let rightAction = theaterManagementNextAction(for: rhs, now: now)

        switch (leftAction, rightAction) {
        case let (.some(left), .some(right)):
            if left.date != right.date { return left.date < right.date }
            if left.priority != right.priority { return left.priority < right.priority }
        case (.some(_), .none):
            return true
        case (.none, .some(_)):
            return false
        case (.none, .none):
            break
        }

        if lhs.hasConfirmedSchedule != rhs.hasConfirmedSchedule {
            return lhs.hasConfirmedSchedule
        }
        if lhs.hasConfirmedSchedule, lhs.startsAt != rhs.startsAt {
            return lhs.startsAt < rhs.startsAt
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private static func theaterManagementNextAction(
        for plan: Plan,
        now: Date
    ) -> TicketNextActionDefinition? {
        let attempts = TicketAttemptPresentationOrder.sorted(
            (plan.ticketAttempts ?? []).filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped", "issued"].contains($0.statusKey)
            },
            now: now
        )
        return attempts.lazy.compactMap {
            TicketNextActionDefinition.nextAction(for: $0, now: now)
        }.first
    }
}
