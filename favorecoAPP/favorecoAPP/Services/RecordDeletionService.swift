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
