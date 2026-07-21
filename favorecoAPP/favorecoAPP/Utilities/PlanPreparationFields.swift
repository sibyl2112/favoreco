//
//  PlanPreparationFields.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import Foundation

struct PlanPreparationFields: Codable, Equatable {
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

struct PlanPreparationTask: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var dueAt: Date?
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case dueAt
        case isCompleted
        case sortOrder
        case createdAt
        case updatedAt
        case completedAt
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        dueAt: Date? = nil,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.dueAt = dueAt
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
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PlanPreparationSuggestion {
    static let titles = [
        "宿を予約",
        "交通を手配",
        "休暇を申請",
        "同行者へ連絡",
        "グッズを準備",
        "発券・座席を確認",
    ]
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
