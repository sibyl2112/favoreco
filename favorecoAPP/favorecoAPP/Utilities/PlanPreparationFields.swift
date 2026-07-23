//
//  PlanPreparationFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import Foundation

nonisolated struct PlanPreparationFields: Codable, Equatable {
    enum ChecklistMode: String, Codable {
        case automatic
        case enabled
        case disabled
    }

    var checklistModeKey: String = ChecklistMode.automatic.rawValue
    var tasks: [PlanPreparationTask] = []

    init(
        checklistModeKey: String = ChecklistMode.automatic.rawValue,
        tasks: [PlanPreparationTask] = []
    ) {
        self.checklistModeKey = checklistModeKey
        self.tasks = tasks
    }

    private enum CodingKeys: String, CodingKey {
        case checklistModeKey
        case tasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checklistModeKey = try container.decodeIfPresent(String.self, forKey: .checklistModeKey)
            ?? ChecklistMode.automatic.rawValue
        tasks = try container.decodeIfPresent([PlanPreparationTask].self, forKey: .tasks) ?? []
    }

    init(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PlanPreparationFields.self, from: data) else {
            self.init()
            return
        }
        self = decoded
    }

    var checklistMode: ChecklistMode {
        ChecklistMode(rawValue: checklistModeKey) ?? .automatic
    }

    func isActive(automaticActivation: Bool) -> Bool {
        switch checklistMode {
        case .automatic:
            return automaticActivation
        case .enabled:
            return true
        case .disabled:
            return false
        }
    }

    var orderedTasks: [PlanPreparationTask] {
        tasks.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    var encodedRawValue: String {
        let normalizedTasks = tasks.enumerated().map { index, task in
            var task = task
            task.sortOrder = index
            return task
        }
        let normalized = PlanPreparationFields(
            checklistModeKey: checklistModeKey,
            tasks: normalizedTasks
        )
        guard normalized.checklistMode != .automatic || !normalized.tasks.isEmpty,
              let data = try? JSONEncoder().encode(normalized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

nonisolated struct PlanPreparationTask: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var kindKey: String = PlanPreparationKind.other.rawValue
    var startsAt: Date?
    var endsAt: Date?
    var dueAt: Date?
    var amount: Decimal = Decimal(0)
    var ocrText: String = ""
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case kindKey
        case startsAt
        case endsAt
        case dueAt
        case amount
        case ocrText
        case isCompleted
        case sortOrder
        case createdAt
        case updatedAt
        case completedAt
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        kindKey: String = PlanPreparationKind.other.rawValue,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        dueAt: Date? = nil,
        amount: Decimal = Decimal(0),
        ocrText: String = "",
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.kindKey = kindKey
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.dueAt = dueAt
        self.amount = amount
        self.ocrText = ocrText
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        kindKey = try container.decodeIfPresent(String.self, forKey: .kindKey) ?? PlanPreparationKind.other.rawValue
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        amount = try container.decodeIfPresent(Decimal.self, forKey: .amount) ?? Decimal(0)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var kind: PlanPreparationKind {
        PlanPreparationKind(rawValue: kindKey) ?? .other
    }

    var hasTravelSchedule: Bool {
        kind.isTravel || startsAt != nil || endsAt != nil
    }
}

nonisolated enum PlanPreparationKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case other
    case hotel
    case shinkansen
    case flight
    case localTransport
    case otherTravel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .other: return "その他"
        case .hotel: return "ホテル"
        case .shinkansen: return "新幹線"
        case .flight: return "飛行機"
        case .localTransport: return "現地交通"
        case .otherTravel: return "その他の遠征"
        }
    }

    var systemImage: String {
        switch self {
        case .other: return "checklist"
        case .hotel: return "bed.double"
        case .shinkansen: return "tram.fill"
        case .flight: return "airplane"
        case .localTransport: return "bus"
        case .otherTravel: return "suitcase.rolling"
        }
    }

    var isTravel: Bool { self != .other }

    static func inferred(from text: String) -> PlanPreparationKind? {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        if ["ホテル", "宿泊", "旅館", "チェックイン", "宿を"].contains(where: normalized.contains) {
            return .hotel
        }
        if ["新幹線", "jr東海", "jr東日本", "jr西日本", "乗車券", "特急券"].contains(where: normalized.contains) {
            return .shinkansen
        }
        if ["飛行機", "航空", "搭乗", "フライト", "jal", "ana"].contains(where: normalized.contains) {
            return .flight
        }
        if ["バス", "地下鉄", "タクシー", "現地交通", "レンタカー"].contains(where: normalized.contains) {
            return .localTransport
        }
        return nil
    }
}

enum PlanPreparationSuggestion {
    static let titles = [
        "ホテルを予約",
        "新幹線を予約",
        "飛行機を予約",
        "現地交通を確認",
        "休暇を申請",
        "同行者へ連絡",
        "グッズを準備",
        "発券・座席を確認",
    ]
}

struct ExperienceExpenseSummary {
    let ticketAttemptAmount: Decimal
    let ticketPhotoAmount: Decimal
    let ticketAmount: Decimal
    let goodsAmount: Decimal
    let travelAmount: Decimal
    let legacyAmount: Decimal
    let usesTicketPhotoFallback: Bool
    let usesLegacyFallback: Bool

    var structuredAmount: Decimal {
        ticketAmount + goodsAmount + travelAmount
    }

    var total: Decimal {
        usesLegacyFallback ? legacyAmount : structuredAmount
    }

    static func make(visit: Visit?, plan: Plan?) -> ExperienceExpenseSummary {
        let ticketPhotoAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .ticket)
        let goodsAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .goods)
        let ticketAttemptAmount = ExperienceExpenseCalculator.securedTicketAmount(for: plan)
        let travelAmount = ExperienceExpenseCalculator.travelAmount(for: plan)
        let ticketAmount = ticketAttemptAmount > 0 ? ticketAttemptAmount : ticketPhotoAmount
        let structuredAmount = ticketAmount + goodsAmount + travelAmount
        let legacyAmount = max(visit?.amount ?? Decimal(0), Decimal(0))

        return ExperienceExpenseSummary(
            ticketAttemptAmount: ticketAttemptAmount,
            ticketPhotoAmount: ticketPhotoAmount,
            ticketAmount: ticketAmount,
            goodsAmount: goodsAmount,
            travelAmount: travelAmount,
            legacyAmount: legacyAmount,
            usesTicketPhotoFallback: ticketAttemptAmount == 0 && ticketPhotoAmount > 0,
            usesLegacyFallback: structuredAmount == 0 && legacyAmount > 0
        )
    }
}

enum PlanPreparationTicketPhase {
    case noTicket
    case applying
    case secured
    case closed
}

extension Plan {
    var preparationFields: PlanPreparationFields {
        PlanPreparationFields(rawValue: unitFieldsRaw)
    }

    var preparationTicketPhase: PlanPreparationTicketPhase {
        let statusKeys = (ticketAttempts ?? [])
            .filter { !$0.isArchived }
            .map(\.statusKey)

        guard !statusKeys.isEmpty else { return .noTicket }

        let securedKeys: Set<String> = ["won", "waitingPayment", "waitingIssue", "issued"]
        if statusKeys.contains(where: securedKeys.contains) {
            return .secured
        }

        if statusKeys.contains(where: { !TicketStatusDefinition.isTerminal($0) }) {
            return .applying
        }

        return .closed
    }

    var automaticallyActivatesPreparationChecklist: Bool {
        switch preparationTicketPhase {
        case .applying, .secured: return true
        case .noTicket, .closed: return false
        }
    }

    var supportsPreparationChecklist: Bool {
        guard let templateKey = category?.templateKey else { return false }
        return templateKey == "theater" || templateKey == "live"
    }

    var isPreparationChecklistActive: Bool {
        supportsPreparationChecklist
            && preparationFields.isActive(automaticActivation: automaticallyActivatesPreparationChecklist)
    }
}
