//
//  RecordDeletionService.swift
//  favorecoAPP
//
//  通常記録（Visit / ExperienceEvent）のハード削除と、関連モデルの安全な解除・削除を担う。
//  - PhotoBlob は Visit.photos の deleteRule = .cascade で自動削除される（CoreModels の Visit を参照）。
//  - EventPersonLink（event/visit 参照）と Plan.visit は inverse 未定義のため、ここで明示的に解除・削除する。
//  データモデル定義は変更しない（削除時の後始末のみ）。
//

import Foundation
import SwiftData

enum RecordDeletionService {
    struct ArchivedDeletionResult {
        let eventCount: Int
        let visitCount: Int
        let planCount: Int
        let attemptCount: Int
        let masterCount: Int
        let linkCount: Int

        var totalCount: Int {
            eventCount + visitCount + planCount + attemptCount + masterCount + linkCount
        }
    }

    /// この記録（Visit）だけを削除する。Event は残す（配下の Visit が 0 件になっても自動削除しない）。
    /// PhotoBlob は cascade で削除。Plan.visit 参照は nil 解除、EventPersonLink の visit 参照は削除。
    @MainActor
    static func deleteVisit(_ visit: Visit, in context: ModelContext) throws {
        detachReferences(toVisitID: visit.id, in: context)
        context.delete(visit) // PhotoBlob は Visit.photos の .cascade で連鎖削除
        try context.save()
    }

    /// この対象（Event）と配下のすべての記録を削除する。
    /// Event の .cascade で Visit / Plan（さらに各 Visit の PhotoBlob、Plan の TicketAttempt）が連鎖削除される。
    /// inverse 未定義の EventPersonLink（event 参照・各 visit 参照）と、外部 Plan.visit 参照はここで後始末する。
    @MainActor
    static func deleteEvent(_ event: ExperienceEvent, in context: ModelContext) throws {
        let eventID = event.id
        let allLinks = (try? context.fetch(FetchDescriptor<EventPersonLink>())) ?? []
        let allPlans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        let visitIDs = Set((event.visits ?? []).map(\.id))

        // 配下 Visit を参照する Plan.visit を解除（Event 配下の Plan は cascade 対象だが、外部参照も安全に外す）
        for plan in allPlans where plan.visit.map({ visitIDs.contains($0.id) }) == true {
            plan.visit = nil
        }
        // event 参照・配下 visit 参照の EventPersonLink を削除
        for link in allLinks where link.event?.id == eventID || link.visit.map({ visitIDs.contains($0.id) }) == true {
            context.delete(link)
        }

        context.delete(event) // Visit / Plan は Event の .cascade、PhotoBlob / TicketAttempt はさらに cascade
        try context.save()
    }

    /// 非表示済みのモデルだけを完全削除する。ジャンルは非表示設定として保持する。
    /// Archived Event/Plan の配下は cascade 対象なので、子を重ねて delete しない。
    @MainActor
    static func deleteArchivedData(in context: ModelContext) throws -> ArchivedDeletionResult {
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        let attempts = try context.fetch(FetchDescriptor<TicketAttempt>())
        let accounts = try context.fetch(FetchDescriptor<TicketAccount>())
        let socialAccounts = try context.fetch(FetchDescriptor<SocialAccount>())
        let people = try context.fetch(FetchDescriptor<PersonMaster>())
        let places = try context.fetch(FetchDescriptor<PlaceMaster>())
        let links = try context.fetch(FetchDescriptor<EventPersonLink>())

        let archivedEvents = events.filter(\.isArchived)
        let archivedEventIDs = Set(archivedEvents.map(\.id))
        let archivedVisits = archivedEvents.flatMap { $0.visits ?? [] }
        let archivedVisitIDs = Set(archivedVisits.map(\.id))
        let archivedPlans = plans.filter { plan in
            plan.isArchived || plan.event.map { archivedEventIDs.contains($0.id) } == true
        }
        let archivedPlanIDs = Set(archivedPlans.map(\.id))
        let archivedAttempts = attempts.filter { attempt in
            attempt.isArchived || attempt.plan.map { archivedPlanIDs.contains($0.id) } == true
        }
        let archivedAccounts = accounts.filter(\.isArchived)
        let archivedPeople = people.filter(\.isArchived)
        let archivedPersonIDs = Set(archivedPeople.map(\.id))
        let archivedPlaces = places.filter(\.isArchived)
        let archivedSocialAccounts = socialAccounts.filter(\.isArchived)

        for plan in archivedPlans {
            for attempt in plan.ticketAttempts ?? [] {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            }
            TicketNotificationScheduler.cancel(plan: plan, attempt: nil)
        }
        for attempt in archivedAttempts where attempt.plan.map({ !archivedPlanIDs.contains($0.id) }) == true {
            if let plan = attempt.plan {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            }
        }
        for account in archivedAccounts {
            TicketAccountNotificationScheduler.cancel(account: account)
        }

        let archivedLinks = links.filter { link in
            link.isArchived
            || link.event.map({ archivedEventIDs.contains($0.id) }) == true
            || link.visit.map({ archivedVisitIDs.contains($0.id) }) == true
            || link.person.map({ archivedPersonIDs.contains($0.id) }) == true
        }
        for link in archivedLinks {
            context.delete(link)
        }
        for attempt in archivedAttempts {
            if let plan = attempt.plan, archivedPlanIDs.contains(plan.id) { continue }
            context.delete(attempt)
        }
        for plan in archivedPlans {
            if let event = plan.event, archivedEventIDs.contains(event.id) { continue }
            context.delete(plan)
        }
        for event in archivedEvents {
            context.delete(event)
        }
        for account in archivedAccounts { context.delete(account) }
        for account in archivedSocialAccounts { context.delete(account) }
        for person in archivedPeople { context.delete(person) }
        for place in archivedPlaces { context.delete(place) }

        try context.save()
        ThumbnailLoader.purge()

        return ArchivedDeletionResult(
            eventCount: archivedEvents.count,
            visitCount: archivedVisits.count,
            planCount: archivedPlans.count,
            attemptCount: archivedAttempts.count,
            masterCount: archivedAccounts.count
                + archivedSocialAccounts.count
                + archivedPeople.count
                + archivedPlaces.count,
            linkCount: archivedLinks.count
        )
    }

    /// 指定 Visit を参照する関連（Plan.visit / EventPersonLink.visit）を安全に解除・削除する。
    @MainActor
    private static func detachReferences(toVisitID visitID: UUID, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        for plan in plans where plan.visit?.id == visitID {
            plan.visit = nil
        }
        let links = (try? context.fetch(FetchDescriptor<EventPersonLink>())) ?? []
        for link in links where link.visit?.id == visitID {
            context.delete(link)
        }
    }
}
