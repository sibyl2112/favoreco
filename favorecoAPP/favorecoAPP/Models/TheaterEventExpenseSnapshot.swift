import Foundation

struct TheaterEventExpenseSnapshot {
    let ticketAmount: Decimal
    let goodsAmount: Decimal
    let travelAmount: Decimal
    let legacyFallbackAmount: Decimal
    let ignoredLegacyAmount: Decimal
    let usesTicketPhotoFallback: Bool
    let visitCount: Int
    let planCount: Int

    var total: Decimal {
        ticketAmount + goodsAmount + travelAmount + legacyFallbackAmount
    }

    static func make(event: ExperienceEvent) -> TheaterEventExpenseSnapshot {
        let visits = uniqueVisits(event.visits ?? [])
        let plans = uniquePlans((event.plans ?? []).filter { !$0.isArchived })
        let visitIDs = Set(visits.map(\.id))
        let plansByVisitID = plans.reduce(into: [UUID: [Plan]]()) { grouped, plan in
            guard let visitID = plan.visit?.id, visitIDs.contains(visitID) else { return }
            grouped[visitID, default: []].append(plan)
        }

        var ticketAmount = Decimal(0)
        var goodsAmount = Decimal(0)
        var legacyFallbackAmount = Decimal(0)
        var ignoredLegacyAmount = Decimal(0)
        var usesTicketPhotoFallback = false

        for visit in visits {
            let linkedPlans = plansByVisitID[visit.id] ?? []
            let securedTicketAmount = linkedPlans.reduce(Decimal(0)) {
                $0 + ExperienceExpenseCalculator.securedTicketAmount(for: $1)
            }
            let ticketPhotoAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .ticket)
            let resolvedTicketAmount = securedTicketAmount > 0 ? securedTicketAmount : ticketPhotoAmount
            let visitGoodsAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .goods)
            let linkedTravelAmount = linkedPlans.reduce(Decimal(0)) {
                $0 + ExperienceExpenseCalculator.travelAmount(for: $1)
            }
            let legacyAmount = max(visit.amount, Decimal(0))
            let structuredVisitAmount = resolvedTicketAmount + visitGoodsAmount + linkedTravelAmount

            ticketAmount += resolvedTicketAmount
            goodsAmount += visitGoodsAmount
            if securedTicketAmount == 0, ticketPhotoAmount > 0 {
                usesTicketPhotoFallback = true
            }
            if structuredVisitAmount == 0 {
                legacyFallbackAmount += legacyAmount
            } else {
                ignoredLegacyAmount += legacyAmount
            }
        }

        let unlinkedPlans = plans.filter { plan in
            guard let visitID = plan.visit?.id else { return true }
            return !visitIDs.contains(visitID)
        }
        ticketAmount += unlinkedPlans.reduce(Decimal(0)) {
            $0 + ExperienceExpenseCalculator.securedTicketAmount(for: $1)
        }
        let travelAmount = plans.reduce(Decimal(0)) {
            $0 + ExperienceExpenseCalculator.travelAmount(for: $1)
        }

        return TheaterEventExpenseSnapshot(
            ticketAmount: ticketAmount,
            goodsAmount: goodsAmount,
            travelAmount: travelAmount,
            legacyFallbackAmount: legacyFallbackAmount,
            ignoredLegacyAmount: ignoredLegacyAmount,
            usesTicketPhotoFallback: usesTicketPhotoFallback,
            visitCount: visits.count,
            planCount: plans.count
        )
    }

    private static func uniqueVisits(_ visits: [Visit]) -> [Visit] {
        var seen = Set<UUID>()
        return visits.filter { seen.insert($0.id).inserted }
    }

    private static func uniquePlans(_ plans: [Plan]) -> [Plan] {
        var seen = Set<UUID>()
        return plans.filter { seen.insert($0.id).inserted }
    }
}
