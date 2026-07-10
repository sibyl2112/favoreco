//
//  TicketDefinitions.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct TicketFlowDefinition: Identifiable, Hashable {
    let key: String
    let name: String
    let description: String
    let defaultStatusKey: String
    let defaultEntryRouteKey: String

    var id: String { key }

    static let all: [TicketFlowDefinition] = [
        TicketFlowDefinition(
            key: "interested",
            name: "気になる",
            description: "行くか未定。情報だけ保存",
            defaultStatusKey: "interested",
            defaultEntryRouteKey: ""
        ),
        TicketFlowDefinition(
            key: "lotteryPlanned",
            name: "抽選応募予定",
            description: "FC先行・抽選・カード枠などに応募する",
            defaultStatusKey: "beforeApply",
            defaultEntryRouteKey: "lottery"
        ),
        TicketFlowDefinition(
            key: "saleWaiting",
            name: "発売待ち",
            description: "先着・一般発売・当日券などを待つ",
            defaultStatusKey: "onSaleSoon",
            defaultEntryRouteKey: "general"
        ),
        TicketFlowDefinition(
            key: "acquired",
            name: "取得済み",
            description: "当選済み・購入済み・招待確定",
            defaultStatusKey: "won",
            defaultEntryRouteKey: "other"
        ),
    ]

    static func definition(for key: String) -> TicketFlowDefinition {
        all.first(where: { $0.key == key }) ?? all[0]
    }

    static func inferredKey(statusKey: String, entryRouteKey: String) -> String {
        switch statusKey {
        case "interested", "skipped":
            return "interested"
        case "beforeApply", "waitingResult", "lost":
            return "lotteryPlanned"
        case "onSaleSoon":
            return "saleWaiting"
        case "won", "waitingPayment", "waitingIssue", "issued", "attended":
            return "acquired"
        default:
            if ["general", "sameDay", "resale"].contains(entryRouteKey) {
                return "saleWaiting"
            }
            if ["fanClub", "lottery", "card"].contains(entryRouteKey) {
                return "lotteryPlanned"
            }
            return "interested"
        }
    }
}

struct TicketStatusDefinition: Identifiable, Hashable {
    let key: String
    let name: String
    let attentionLevel: String

    var id: String { key }

    static let all: [TicketStatusDefinition] = [
        TicketStatusDefinition(key: "interested", name: "気になる", attentionLevel: "low"),
        TicketStatusDefinition(key: "beforeApply", name: "申込前", attentionLevel: "high"),
        TicketStatusDefinition(key: "onSaleSoon", name: "発売前", attentionLevel: "medium"),
        TicketStatusDefinition(key: "waitingResult", name: "当落待ち", attentionLevel: "medium"),
        TicketStatusDefinition(key: "won", name: "当選", attentionLevel: "medium"),
        TicketStatusDefinition(key: "lost", name: "落選", attentionLevel: "none"),
        TicketStatusDefinition(key: "waitingPayment", name: "入金待ち", attentionLevel: "high"),
        TicketStatusDefinition(key: "waitingIssue", name: "発券待ち", attentionLevel: "medium"),
        TicketStatusDefinition(key: "issued", name: "発券済み", attentionLevel: "low"),
        TicketStatusDefinition(key: "attended", name: "参加済み", attentionLevel: "none"),
        TicketStatusDefinition(key: "skipped", name: "見送り", attentionLevel: "none"),
    ]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }
}

struct TicketEntryRouteDefinition: Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [TicketEntryRouteDefinition] = [
        TicketEntryRouteDefinition(key: "fanClub", name: "FC先行"),
        TicketEntryRouteDefinition(key: "lottery", name: "抽選先行"),
        TicketEntryRouteDefinition(key: "card", name: "カード枠"),
        TicketEntryRouteDefinition(key: "general", name: "一般発売"),
        TicketEntryRouteDefinition(key: "sameDay", name: "当日券"),
        TicketEntryRouteDefinition(key: "invitation", name: "招待"),
        TicketEntryRouteDefinition(key: "resale", name: "リセール"),
        TicketEntryRouteDefinition(key: "other", name: "その他"),
    ]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }
}

struct TicketAccountTypeDefinition: Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [TicketAccountTypeDefinition] = [
        TicketAccountTypeDefinition(key: "fanClub", name: "FC"),
        TicketAccountTypeDefinition(key: "playguide", name: "プレイガイド"),
        TicketAccountTypeDefinition(key: "theaterMembership", name: "劇場会員"),
        TicketAccountTypeDefinition(key: "card", name: "カード枠"),
        TicketAccountTypeDefinition(key: "calendar", name: "外部カレンダー"),
        TicketAccountTypeDefinition(key: "other", name: "その他"),
    ]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }
}
