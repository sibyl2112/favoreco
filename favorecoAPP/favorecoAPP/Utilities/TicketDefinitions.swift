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
            name: "抽選に申し込む",
            description: "締切・当落・支払など、次に必要な日程を登録",
            defaultStatusKey: "beforeApply",
            defaultEntryRouteKey: "lottery"
        ),
        TicketFlowDefinition(
            key: "saleWaiting",
            name: "発売を待つ",
            description: "先行販売・一般発売などの開始を登録",
            defaultStatusKey: "onSaleSoon",
            defaultEntryRouteKey: "general"
        ),
        TicketFlowDefinition(
            key: "acquired",
            name: "チケットを受取済み",
            description: "手元にあるチケットの購入先や内容を記録",
            defaultStatusKey: "issued",
            defaultEntryRouteKey: "other"
        ),
    ]

    static let registrationOptions = all.filter { $0.key != "interested" }

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
        case "won", "waitingPayment":
            return "lotteryPlanned"
        case "waitingIssue", "issued", "attended":
            return "acquired"
        default:
            if ["presale", "general", "sameDay", "resale"].contains(entryRouteKey) {
                return "saleWaiting"
            }
            if ["fanClub", "official", "lottery", "card", "generalLottery"].contains(entryRouteKey) {
                return "lotteryPlanned"
            }
            return "interested"
        }
    }
}

nonisolated struct TicketStatusDefinition: Identifiable, Hashable {
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
        TicketStatusDefinition(key: "waitingPayment", name: "支払待ち", attentionLevel: "high"),
        TicketStatusDefinition(key: "waitingIssue", name: "取得処理中", attentionLevel: "medium"),
        TicketStatusDefinition(key: "issued", name: "受取済み", attentionLevel: "low"),
        TicketStatusDefinition(key: "attended", name: "参加済み", attentionLevel: "none"),
        TicketStatusDefinition(key: "skipped", name: "見送り", attentionLevel: "none"),
    ]

    static let terminalKeys: Set<String> = ["lost", "attended", "skipped"]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }

    static func isTerminal(_ key: String) -> Bool {
        terminalKeys.contains(key)
    }
}

enum TicketAcquisitionState {
    private static let acquiredStatusKeys: Set<String> = ["issued", "attended"]

    static func hasAcquiredTicket(in attempts: [TicketAttempt]) -> Bool {
        attempts.contains {
            !$0.isArchived && acquiredStatusKeys.contains($0.statusKey)
        }
    }
}

enum TicketAttemptPresentationOrder {
    static func sorted(_ attempts: [TicketAttempt], now: Date = Date()) -> [TicketAttempt] {
        attempts.sorted { isOrderedBefore($0, $1, now: now) }
    }

    static func isOrderedBefore(_ lhs: TicketAttempt, _ rhs: TicketAttempt, now: Date = Date()) -> Bool {
        let leftAction = TicketNextActionDefinition.nextAction(for: lhs, now: now)
        let rightAction = TicketNextActionDefinition.nextAction(for: rhs, now: now)

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

        let leftIssue = TicketInputIssueDefinition.issue(for: lhs)
        let rightIssue = TicketInputIssueDefinition.issue(for: rhs)
        switch (leftIssue, rightIssue) {
        case let (.some(left), .some(right)):
            if left.priority != right.priority { return left.priority < right.priority }
        case (.some(_), .none):
            return true
        case (.none, .some(_)):
            return false
        case (.none, .none):
            break
        }

        let leftRank = statusRank(lhs.statusKey)
        let rightRank = statusRank(rhs.statusKey)
        if leftRank != rightRank { return leftRank < rightRank }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func statusRank(_ key: String) -> Int {
        switch key {
        case "waitingPayment": 0
        case "beforeApply": 1
        case "onSaleSoon": 2
        case "waitingResult": 3
        case "won": 4
        case "waitingIssue": 5
        case "issued": 6
        case "interested": 7
        case "lost": 8
        case "skipped": 9
        case "attended": 10
        default: 11
        }
    }
}

struct TicketEntryRouteDefinition: Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [TicketEntryRouteDefinition] = [
        TicketEntryRouteDefinition(key: "fanClub", name: "FC先行"),
        TicketEntryRouteDefinition(key: "official", name: "公式先行"),
        TicketEntryRouteDefinition(key: "lottery", name: "プレイガイド先行"),
        TicketEntryRouteDefinition(key: "card", name: "カード枠"),
        TicketEntryRouteDefinition(key: "generalLottery", name: "一般抽選"),
        TicketEntryRouteDefinition(key: "presale", name: "先行販売（先着）"),
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
        TicketGuideDefinition(key: "custom", name: "FC・公式・その他を入力", urlString: "", category: "手入力"),
    ]

    static func guide(for key: String) -> TicketGuideDefinition? {
        all.first(where: { $0.key == key && $0.key != customKey })
    }

    static func suggestions(matching query: String) -> [TicketGuideDefinition] {
        let normalizedQuery = normalizedSearchText(query)
        guard normalizedQuery.count >= 2 else { return [] }

        return all.filter { guide in
            guard guide.key != customKey else { return false }
            return searchKeywords(for: guide).contains { keyword in
                normalizedSearchText(keyword).contains(normalizedQuery)
            }
        }
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

    private static func searchKeywords(for guide: TicketGuideDefinition) -> [String] {
        let aliases: [String: [String]] = [
            "pia": ["ぴあ", "pia"],
            "eplus": ["イープラ", "eplus", "e+"],
            "lawson": ["ローチケ", "ローソン"],
            "rakuten": ["楽天", "rakuten"],
            "cnplayguide": ["cn", "シーエヌ"],
            "ticketboard": ["チケットボード", "tickebo"],
            "tixplus": ["チケプラ"],
            "confetti": ["カンフェティ", "confetti"],
            "livepocket": ["ライブポケット"],
            "passmarket": ["パスマーケット"],
            "mubic": ["ムビチケ"],
        ]
        return [guide.name, guide.key, guide.urlString] + (aliases[guide.key] ?? [])
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .lowercased()
    }
}

struct TicketAttemptUnitFields: Codable, Equatable {
    var tagNames: [String] = []

    init(tagNames: [String] = []) {
        self.tagNames = tagNames
    }

    private enum CodingKeys: String, CodingKey {
        case tagNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagNames = try container.decodeIfPresent([String].self, forKey: .tagNames) ?? []
    }

    init(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TicketAttemptUnitFields.self, from: data) else {
            self.init()
            return
        }
        self = decoded
    }

    var encodedRawValue: String {
        guard !tagNames.isEmpty,
              let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func normalizedTagNames(from text: String) -> [String] {
        var normalizedKeys = Set<String>()
        var results: [String] = []

        for component in text.components(separatedBy: CharacterSet(charactersIn: ",、\n")) {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let displayName = String(trimmed.prefix(30))
            let normalizedKey = displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            guard normalizedKeys.insert(normalizedKey).inserted else { continue }
            results.append(displayName)
            if results.count == 12 { break }
        }
        return results
    }
}

enum TicketApplicationCollectionNaming {
    static func scheduleName(for plan: Plan) -> String {
        let title = eventTitle(for: plan)
        let schedule: String
        if plan.hasConfirmedSchedule {
            let components = Calendar.current.dateComponents([.month, .day], from: plan.startsAt)
            let date = "\(components.month ?? 0)/\(components.day ?? 0)"
            let venue = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            schedule = venue.isEmpty ? date : "\(date) \(venue)"
        } else {
            schedule = "参加日未定"
        }
        return "\(title)｜\(schedule)"
    }

    static func tourName(eventTitle: String) -> String {
        let title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(title.isEmpty ? "チケット" : title)｜ツアー申込"
    }

    static func tourName(for plan: Plan) -> String {
        tourName(eventTitle: eventTitle(for: plan))
    }

    static func displayName(
        storedName: String?,
        attempts: [TicketAttempt]
    ) -> String? {
        let name = storedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let firstPlan = attempts.compactMap(\.plan).first else {
            return name.isEmpty ? nil : name
        }

        let plans = attempts.compactMap(\.plan)
        let planIDs = Set(plans.map(\.id))
        let eventIDs = Set(plans.compactMap { $0.event?.id })
        let sharesOneEvent = eventIDs.count == 1
            || Set(plans.map { eventTitle(for: $0) }).count == 1

        if name.isEmpty || isLegacyReceptionName(name, attempts: attempts) {
            if planIDs.count > 1, sharesOneEvent {
                return tourName(for: firstPlan)
            }
            return scheduleName(for: firstPlan)
        }
        return name
    }

    static func shouldReplaceWithTourName(
        _ name: String,
        attempts: [TicketAttempt]
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if isLegacyReceptionName(trimmed, attempts: attempts) {
            return true
        }
        return attempts.compactMap(\.plan).contains {
            scheduleName(for: $0) == trimmed
        }
    }

    static func legacyReceptionName(for attempt: TicketAttempt) -> String {
        var parts: [String] = []
        let routeName = TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
        if !routeName.isEmpty,
           routeName != attempt.entryRouteKey || !attempt.entryRouteKey.isEmpty {
            parts.append(routeName)
        }
        let site = attempt.ticketSite.trimmingCharacters(in: .whitespacesAndNewlines)
        if !site.isEmpty,
           !parts.contains(where: { $0.localizedCaseInsensitiveCompare(site) == .orderedSame }) {
            parts.append(site)
        }
        return parts.isEmpty ? "先行・受付" : parts.joined(separator: "・")
    }

    private static func isLegacyReceptionName(
        _ name: String,
        attempts: [TicketAttempt]
    ) -> Bool {
        attempts.contains {
            legacyReceptionName(for: $0).localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private static func eventTitle(for plan: Plan) -> String {
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "チケット" : planTitle
    }
}

struct TicketProgressStage: Identifiable, Equatable {
    enum Kind: String {
        case entry
        case result
        case payment
        case acquired
    }

    let kind: Kind
    let title: String
    let date: Date?

    var id: Kind { kind }
}

enum TicketProgressTimeline {
    static func stages(for attempt: TicketAttempt, plan: Plan) -> [TicketProgressStage] {
        let lottery = usesLotteryFlow(attempt)
        var stages: [TicketProgressStage] = [
            TicketProgressStage(
                kind: .entry,
                title: lottery ? "申込" : "発売",
                date: firstAvailableDate(attempt.applyDeadlineAt, attempt.saleStartAt)
            )
        ]

        if lottery {
            stages.append(
                TicketProgressStage(
                    kind: .result,
                    title: "当落",
                    date: availableDate(attempt.resultAnnounceAt)
                )
            )
        }

        if hasPaymentStage(attempt) {
            stages.append(
                TicketProgressStage(
                    kind: .payment,
                    title: "支払",
                    date: availableDate(attempt.paymentDeadlineAt)
                )
            )
        }

        stages.append(
            TicketProgressStage(
                kind: .acquired,
                title: "受取",
                date: availableDate(attempt.issueStartAt)
            )
        )
        return stages
    }

    static func currentIndex(for attempt: TicketAttempt, stages: [TicketProgressStage]) -> Int {
        guard !stages.isEmpty else { return 0 }
        if ["issued", "attended"].contains(attempt.statusKey) {
            return stages.count
        }

        let targetKind: TicketProgressStage.Kind
        switch attempt.statusKey {
        case "waitingResult", "lost":
            targetKind = .result
        case "won", "waitingPayment":
            targetKind = .payment
        case "waitingIssue":
            targetKind = .acquired
        default:
            targetKind = .entry
        }

        if let exactIndex = stages.firstIndex(where: { $0.kind == targetKind }) {
            return exactIndex
        }

        let targetRank = rank(of: targetKind)
        return stages.firstIndex(where: { rank(of: $0.kind) > targetRank }) ?? max(0, stages.count - 1)
    }

    static func reconciledStatusAfterScheduleEdit(
        currentStatusKey: String,
        attempt: TicketAttempt,
        now: Date = Date()
    ) -> String {
        guard !["interested", "lost", "issued", "attended", "skipped"].contains(currentStatusKey) else {
            return currentStatusKey
        }

        let candidate: String?
        if usesLotteryFlow(attempt) {
            if isFuture(attempt.applyDeadlineAt, now: now) {
                candidate = "beforeApply"
            } else if isFuture(attempt.resultAnnounceAt, now: now) {
                candidate = "waitingResult"
            } else if isFuture(attempt.paymentDeadlineAt, now: now) {
                candidate = "waitingPayment"
            } else if isFuture(attempt.issueStartAt, now: now) {
                candidate = "waitingIssue"
            } else {
                candidate = nil
            }
        } else if isFuture(attempt.saleStartAt, now: now) {
            candidate = "onSaleSoon"
        } else if isFuture(attempt.issueStartAt, now: now) {
            candidate = "waitingIssue"
        } else {
            candidate = nil
        }

        guard let candidate,
              workflowRank(candidate) < workflowRank(currentStatusKey) else {
            return currentStatusKey
        }
        return candidate
    }

    static func usesLotteryFlow(_ attempt: TicketAttempt) -> Bool {
        ["fanClub", "official", "lottery", "card", "generalLottery"].contains(attempt.entryRouteKey)
            || attempt.resultAnnounceAt != Date.distantPast
            || ["waitingResult", "lost"].contains(attempt.statusKey)
    }

    static func hasPaymentStage(_ attempt: TicketAttempt) -> Bool {
        attempt.paymentDeadlineAt != Date.distantPast
            || attempt.paidAt != Date.distantPast
            || ["won", "waitingPayment"].contains(attempt.statusKey)
    }

    private static func availableDate(_ date: Date) -> Date? {
        date == Date.distantPast ? nil : date
    }

    private static func firstAvailableDate(_ preferred: Date, _ fallback: Date) -> Date? {
        availableDate(preferred) ?? availableDate(fallback)
    }

    private static func isFuture(_ date: Date, now: Date) -> Bool {
        date != Date.distantPast && date > now
    }

    private static func workflowRank(_ statusKey: String) -> Int {
        switch statusKey {
        case "beforeApply", "onSaleSoon": 0
        case "waitingResult": 1
        case "won", "waitingPayment": 2
        case "waitingIssue": 3
        case "issued", "attended": 4
        default: 5
        }
    }

    private static func rank(of kind: TicketProgressStage.Kind) -> Int {
        switch kind {
        case .entry: 0
        case .result: 1
        case .payment: 2
        case .acquired: 3
        }
    }
}

enum TicketProgressPresentation {
    static func currentStageLabel(for attempt: TicketAttempt) -> String {
        switch attempt.statusKey {
        case "beforeApply":
            return usesLotteryFlow(attempt) ? "抽選申込" : "発売待ち"
        case "onSaleSoon": return "発売待ち"
        case "waitingResult": return "当落待ち"
        case "won": return "支払待ち"
        case "waitingPayment": return "支払待ち"
        case "waitingIssue": return "受取待ち"
        case "issued": return "受取済み"
        case "lost": return "落選"
        case "skipped": return "見送り"
        case "attended": return "参加済み"
        default: return TicketStatusDefinition.name(for: attempt.statusKey)
        }
    }

    private static func usesLotteryFlow(_ attempt: TicketAttempt) -> Bool {
        TicketProgressTimeline.usesLotteryFlow(attempt)
    }

    static func deadlineLabel(
        forActionTitle title: String,
        attempt: TicketAttempt?
    ) -> String {
        if title.contains("申込・発売") {
            guard let attempt else { return "チケ発売" }
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "抽選申込" : "チケ発売"
        }
        if title.contains("当落") { return "抽選当落" }
        if title.contains("入金") || title.contains("支払") { return "チケ支払" }
        if title.contains("受取") || title.contains("取得") { return "チケ受取" }
        if title.contains("発売") || title.contains("購入") { return "チケ発売" }
        if title.contains("申込") { return "抽選申込" }
        if title.contains("参加日") { return "参加日" }
        return title
    }
}

struct TicketNextActionDefinition {
    let title: String
    let date: Date
    let systemImage: String
    let priority: Int
    let isOverdue: Bool

    init(
        title: String,
        date: Date,
        systemImage: String,
        priority: Int,
        isOverdue: Bool = false
    ) {
        self.title = title
        self.date = date
        self.systemImage = systemImage
        self.priority = priority
        self.isOverdue = isOverdue
    }

    static func nextAction(for attempt: TicketAttempt, now: Date = Date()) -> TicketNextActionDefinition? {
        guard !["lost", "attended", "skipped"].contains(attempt.statusKey) else {
            return nil
        }

        let allCandidates: [TicketNextActionDefinition] = [
            TicketNextActionDefinition(title: "申込・発売開始", date: attempt.saleStartAt, systemImage: "ticket", priority: 4),
            TicketNextActionDefinition(title: "申込締切", date: attempt.applyDeadlineAt, systemImage: "hourglass", priority: 0),
            TicketNextActionDefinition(title: "当落発表", date: attempt.resultAnnounceAt, systemImage: "checkmark.seal", priority: 2),
            TicketNextActionDefinition(title: "支払締切", date: attempt.paymentDeadlineAt, systemImage: "yensign.circle", priority: 1),
            TicketNextActionDefinition(title: "チケット受取開始", date: attempt.issueStartAt, systemImage: "ticket.fill", priority: 3),
        ]
        let candidates: [TicketNextActionDefinition]
        switch attempt.statusKey {
        case "beforeApply":
            candidates = Array(allCandidates.prefix(2))
        case "onSaleSoon":
            candidates = [allCandidates[0]]
        case "waitingResult":
            candidates = [allCandidates[2]]
        case "won", "waitingPayment":
            candidates = [allCandidates[3]]
        case "waitingIssue":
            candidates = [allCandidates[4]]
        case "issued":
            candidates = []
        default:
            candidates = allCandidates
        }

        if let overdueAction = overdueAction(for: attempt, now: now) {
            return overdueAction
        }

        let futureAction = candidates
            .filter { $0.date != Date.distantPast && $0.date >= now }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first

        if let futureAction {
            return futureAction
        }
        return nil
    }

    private static func overdueAction(for attempt: TicketAttempt, now: Date) -> TicketNextActionDefinition? {
        let action: TicketNextActionDefinition?

        switch attempt.statusKey {
        case "beforeApply":
            action = overdueCandidate(
                title: "申込締切超過",
                date: attempt.applyDeadlineAt,
                systemImage: "exclamationmark.hourglass",
                priority: 0,
                now: now
            )
        case "onSaleSoon":
            action = overdueCandidate(
                title: "発売開始済み",
                date: attempt.saleStartAt,
                systemImage: "ticket",
                priority: 4,
                now: now
            )
        case "waitingResult":
            action = overdueCandidate(
                title: "当落を確認",
                date: attempt.resultAnnounceAt,
                systemImage: "exclamationmark.bubble",
                priority: 2,
                now: now
            )
        case "waitingPayment", "won":
            action = overdueCandidate(
                title: "支払期限超過",
                date: attempt.paymentDeadlineAt,
                systemImage: "exclamationmark.circle",
                priority: 1,
                now: now
            )
        case "waitingIssue":
            action = overdueCandidate(
                title: "チケットを受け取る",
                date: attempt.issueStartAt,
                systemImage: "ticket.fill",
                priority: 3,
                now: now
            )
        default:
            action = nil
        }

        return action
    }

    private static func overdueCandidate(
        title: String,
        date: Date,
        systemImage: String,
        priority: Int,
        now: Date
    ) -> TicketNextActionDefinition? {
        guard date != Date.distantPast, date < now else { return nil }
        return TicketNextActionDefinition(
            title: title,
            date: date,
            systemImage: systemImage,
            priority: priority,
            isOverdue: true
        )
    }
}

enum TicketAttendanceScheduleRequirement {
    static func shouldPrompt(afterTransitionTo statusKey: String, plan: Plan?) -> Bool {
        statusKey == "issued" && plan?.hasConfirmedSchedule == false
    }
}

struct TicketInputIssueDefinition {
    let title: String
    let systemImage: String
    let priority: Int

    static func issue(for attempt: TicketAttempt) -> TicketInputIssueDefinition? {
        switch attempt.statusKey {
        case "beforeApply" where attempt.applyDeadlineAt == Date.distantPast:
            TicketInputIssueDefinition(title: "申込締切を設定", systemImage: "calendar.badge.exclamationmark", priority: 0)
        case "onSaleSoon" where attempt.saleStartAt == Date.distantPast:
            TicketInputIssueDefinition(title: "発売開始を設定", systemImage: "calendar.badge.exclamationmark", priority: 1)
        case "waitingResult" where attempt.resultAnnounceAt == Date.distantPast:
            TicketInputIssueDefinition(title: "当落発表日を設定", systemImage: "calendar.badge.exclamationmark", priority: 2)
        case "won" where attempt.paymentDeadlineAt == Date.distantPast:
            TicketInputIssueDefinition(title: "支払締切を設定", systemImage: "calendar.badge.exclamationmark", priority: 3)
        case "waitingPayment" where attempt.paymentDeadlineAt == Date.distantPast:
            TicketInputIssueDefinition(title: "支払締切を設定", systemImage: "calendar.badge.exclamationmark", priority: 3)
        case "waitingIssue" where attempt.issueStartAt == Date.distantPast:
            nil
        default:
            nil
        }
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
                TicketStatusTransitionDefinition(targetStatusKey: "issued", title: "チケットを受け取った", systemImage: "checkmark.circle"),
                TicketStatusTransitionDefinition(targetStatusKey: "skipped", title: "見送りにする", systemImage: "xmark.circle"),
            ]
        case "waitingResult":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingPayment", title: "当選にする", systemImage: "checkmark.seal"),
                TicketStatusTransitionDefinition(targetStatusKey: "lost", title: "落選にする", systemImage: "xmark.seal"),
            ]
        case "won":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingIssue", title: "支払済みにする", systemImage: "checkmark.circle.fill"),
            ]
        case "waitingPayment":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "waitingIssue", title: "支払済みにする", systemImage: "checkmark.circle.fill"),
            ]
        case "waitingIssue":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "issued", title: "チケットを受け取った", systemImage: "checkmark.circle.fill"),
            ]
        case "lost", "skipped":
            return [
                TicketStatusTransitionDefinition(targetStatusKey: "beforeApply", title: "再度申込予定にする", systemImage: "arrow.uturn.left"),
            ]
        default:
            return []
        }
    }

    static func previousStatusKey(for attempt: TicketAttempt) -> String? {
        switch attempt.statusKey {
        case "waitingResult":
            return "beforeApply"
        case "lost":
            return "waitingResult"
        case "won", "waitingPayment":
            return "waitingResult"
        case "waitingIssue":
            if TicketProgressTimeline.hasPaymentStage(attempt) {
                return "waitingPayment"
            }
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "waitingResult" : "onSaleSoon"
        case "issued":
            return "waitingIssue"
        case "attended":
            return "issued"
        case "skipped":
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "beforeApply" : "onSaleSoon"
        default:
            return nil
        }
    }
}

enum TicketPostAcquisitionDetailsPrompt {
    static func shouldOffer(
        for attempt: TicketAttempt,
        afterTransitionTo statusKey: String
    ) -> Bool {
        guard statusKey == "waitingIssue" || statusKey == "issued" else {
            return false
        }
        return attempt.price == Decimal(0)
            || attempt.seatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        TicketAccountTypeDefinition(key: "other", name: "その他"),
    ]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }
}
