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

struct TicketGuideDefinition: Identifiable, Hashable {
    let key: String
    let name: String
    let urlString: String
    let category: String

    var id: String { key }

    static let customKey = "custom"

    static let all: [TicketGuideDefinition] = [
        TicketGuideDefinition(key: "pia", name: "チケットぴあ", urlString: "https://t.pia.jp/", category: "総合"),
        TicketGuideDefinition(key: "eplus", name: "イープラス", urlString: "https://eplus.jp/", category: "総合"),
        TicketGuideDefinition(key: "lawson", name: "ローソンチケット", urlString: "https://l-tike.com/", category: "総合"),
        TicketGuideDefinition(key: "rakuten", name: "楽天チケット", urlString: "https://ticket.rakuten.co.jp/", category: "総合"),
        TicketGuideDefinition(key: "cnplayguide", name: "CNプレイガイド", urlString: "https://www.cnplayguide.com/", category: "総合"),
        TicketGuideDefinition(key: "ticketboard", name: "ticket board", urlString: "https://ticket.tickebo.jp/", category: "総合"),
        TicketGuideDefinition(key: "tixplus", name: "Tixplus", urlString: "https://tixplus.jp/", category: "総合"),
        TicketGuideDefinition(key: "confetti", name: "カンフェティ", urlString: "https://www.confetti-web.com/", category: "演劇"),
        TicketGuideDefinition(key: "stageGate", name: "Stage Gate", urlString: "https://stagegate.jp/", category: "演劇"),
        TicketGuideDefinition(key: "teket", name: "teket", urlString: "https://teket.jp/", category: "クラシック/公演"),
        TicketGuideDefinition(key: "livepocket", name: "LivePocket", urlString: "https://t.livepocket.jp/", category: "ライブ/イベント"),
        TicketGuideDefinition(key: "tiget", name: "TIGET", urlString: "https://tiget.net/", category: "ライブ/イベント"),
        TicketGuideDefinition(key: "zaiko", name: "ZAIKO", urlString: "https://zaiko.io/", category: "配信"),
        TicketGuideDefinition(key: "streamingPlus", name: "Streaming+", urlString: "https://eplus.jp/sf/streamingplus", category: "配信"),
        TicketGuideDefinition(key: "lawsonStreaming", name: "ローチケ LIVE STREAMING", urlString: "https://l-tike.com/livestreaming/", category: "配信"),
        TicketGuideDefinition(key: "peatix", name: "Peatix", urlString: "https://peatix.com/", category: "イベント"),
        TicketGuideDefinition(key: "passmarket", name: "PassMarket", urlString: "https://passmarket.yahoo.co.jp/", category: "イベント"),
        TicketGuideDefinition(key: "eventRegist", name: "EventRegist", urlString: "https://eventregist.com/", category: "イベント"),
        TicketGuideDefinition(key: "mubic", name: "ムビチケ", urlString: "https://mvtk.jp/", category: "映画"),
        TicketGuideDefinition(key: "tohoCinemas", name: "TOHOシネマズ", urlString: "https://hlo.tohotheater.jp/net/movie/TNPI3090J01.do", category: "映画"),
        TicketGuideDefinition(key: "aeonCinema", name: "イオンシネマ", urlString: "https://www.aeoncinema.com/", category: "映画"),
        TicketGuideDefinition(key: "109cinemas", name: "109シネマズ", urlString: "https://109cinemas.net/", category: "映画"),
        TicketGuideDefinition(key: "unitedCinemas", name: "ユナイテッド・シネマ", urlString: "https://www.unitedcinemas.jp/", category: "映画"),
        TicketGuideDefinition(key: "custom", name: "カスタム", urlString: "", category: "手入力"),
    ]

    static func guide(for key: String) -> TicketGuideDefinition? {
        all.first(where: { $0.key == key && $0.key != customKey })
    }

    static func inferredKey(siteName: String, urlString: String) -> String {
        let site = siteName.lowercased()
        let url = urlString.lowercased()
        return all.first { guide in
            guard guide.key != customKey else { return false }
            return site == guide.name.lowercased()
                || (!guide.urlString.isEmpty && url.hasPrefix(guide.urlString.lowercased()))
        }?.key ?? customKey
    }
}

struct TicketNextActionDefinition {
    let title: String
    let date: Date
    let systemImage: String
    let priority: Int

    static func nextAction(for attempt: TicketAttempt, now: Date = Date()) -> TicketNextActionDefinition? {
        guard !["lost", "attended", "skipped"].contains(attempt.statusKey) else {
            return nil
        }

        let candidates: [TicketNextActionDefinition] = [
            TicketNextActionDefinition(title: "申込・発売開始", date: attempt.saleStartAt, systemImage: "ticket", priority: 4),
            TicketNextActionDefinition(title: "申込締切", date: attempt.applyDeadlineAt, systemImage: "hourglass", priority: 0),
            TicketNextActionDefinition(title: "当落発表", date: attempt.resultAnnounceAt, systemImage: "checkmark.seal", priority: 2),
            TicketNextActionDefinition(title: "入金締切", date: attempt.paymentDeadlineAt, systemImage: "yensign.circle", priority: 1),
            TicketNextActionDefinition(title: "発券開始", date: attempt.issueStartAt, systemImage: "ticket.fill", priority: 3),
        ]

        return candidates
            .filter { $0.date != Date.distantPast && $0.date >= now }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first
    }
}

struct TicketStatusTransitionDefinition: Identifiable, Hashable {
    let targetStatusKey: String
    let title: String
    let systemImage: String

    var id: String { targetStatusKey }

    static func transitions(for attempt: TicketAttempt) -> [TicketStatusTransitionDefinition] {
        switch attempt.statusKey {
        case "interested":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "beforeApply", title: "抽選応募予定にする", systemImage: "hourglass"),
                TicketStatusTransitionDefinition(targetStatusKey: "onSaleSoon", title: "発売待ちにする", systemImage: "ticket"),
            ]
        case "beforeApply":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingResult", title: "申込済みにする", systemImage: "paperplane"),
                TicketStatusTransitionDefinition(targetStatusKey: "skipped", title: "見送りにする", systemImage: "xmark.circle"),
            ]
        case "onSaleSoon":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "won", title: "取得済みにする", systemImage: "checkmark.circle"),
                TicketStatusTransitionDefinition(targetStatusKey: "skipped", title: "見送りにする", systemImage: "xmark.circle"),
            ]
        case "waitingResult":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "won", title: "当選にする", systemImage: "checkmark.seal"),
                TicketStatusTransitionDefinition(targetStatusKey: "lost", title: "落選にする", systemImage: "xmark.seal"),
            ]
        case "won":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingPayment", title: "入金待ちにする", systemImage: "yensign.circle"),
                TicketStatusTransitionDefinition(targetStatusKey: "waitingIssue", title: "発券待ちにする", systemImage: "ticket"),
                TicketStatusTransitionDefinition(targetStatusKey: "issued", title: "発券済みにする", systemImage: "ticket.fill"),
            ]
        case "waitingPayment":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingIssue", title: "入金済み・発券待ちにする", systemImage: "ticket"),
                TicketStatusTransitionDefinition(targetStatusKey: "issued", title: "発券済みにする", systemImage: "ticket.fill"),
            ]
        case "waitingIssue":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "issued", title: "発券済みにする", systemImage: "ticket.fill"),
            ]
        case "issued":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "attended", title: "参加済みにする", systemImage: "checkmark.seal.fill"),
            ]
        case "lost", "skipped":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "beforeApply", title: "再度申込予定にする", systemImage: "arrow.uturn.left"),
            ]
        default:
            return []
        }
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
