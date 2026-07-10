//
//  TicketDefinitions.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

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
