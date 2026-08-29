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
    var attendanceMethodKey: String = "onsite"
    var tasks: [PlanPreparationTask] = []
    var tagNames: [String] = []
    var memoStyleRuns: [MemoStyleRun] = []
    var overallRating: Double = 0
    var momentEntries: [VisitMomentEntry] = []
    var liveSetlistEntries: [LiveSetlistEntry] = []
    var people: [PlanMemoryPerson] = []
    var amountText: String = ""
    var expenseEntries: [VisitExpenseEntry] = []
    var ocrText: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    var admissionPreparationConfirmedAt: Date?
    var admissionPreparationSnoozedUntil: Date?

    init(
        checklistModeKey: String = ChecklistMode.automatic.rawValue,
        attendanceMethodKey: String = "onsite",
        tasks: [PlanPreparationTask] = [],
        tagNames: [String] = [],
        memoStyleRuns: [MemoStyleRun] = [],
        overallRating: Double = 0,
        momentEntries: [VisitMomentEntry] = [],
        liveSetlistEntries: [LiveSetlistEntry] = [],
        people: [PlanMemoryPerson] = [],
        amountText: String = "",
        expenseEntries: [VisitExpenseEntry] = [],
        ocrText: String = "",
        advancedEntries: [AdvancedFieldEntry] = [],
        admissionPreparationConfirmedAt: Date? = nil,
        admissionPreparationSnoozedUntil: Date? = nil
    ) {
        self.checklistModeKey = checklistModeKey
        self.attendanceMethodKey = attendanceMethodKey
        self.tasks = tasks
        self.tagNames = tagNames
        self.memoStyleRuns = memoStyleRuns
        self.overallRating = overallRating
        self.momentEntries = momentEntries
        self.liveSetlistEntries = liveSetlistEntries
        self.people = people
        self.amountText = amountText
        self.expenseEntries = expenseEntries
        self.ocrText = ocrText
        self.advancedEntries = advancedEntries
        self.admissionPreparationConfirmedAt = admissionPreparationConfirmedAt
        self.admissionPreparationSnoozedUntil = admissionPreparationSnoozedUntil
    }

    private enum CodingKeys: String, CodingKey {
        case checklistModeKey
        case attendanceMethodKey
        case tasks
        case tagNames
        case memoStyleRuns
        case overallRating
        case momentEntries
        case liveSetlistEntries
        case people
        case amountText
        case expenseEntries
        case ocrText
        case advancedEntries
        case admissionPreparationConfirmedAt
        case admissionPreparationSnoozedUntil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checklistModeKey = try container.decodeIfPresent(String.self, forKey: .checklistModeKey)
            ?? ChecklistMode.automatic.rawValue
        attendanceMethodKey = try container.decodeIfPresent(String.self, forKey: .attendanceMethodKey) ?? "onsite"
        tasks = try container.decodeIfPresent([PlanPreparationTask].self, forKey: .tasks) ?? []
        tagNames = try container.decodeIfPresent([String].self, forKey: .tagNames) ?? []
        memoStyleRuns = try container.decodeIfPresent([MemoStyleRun].self, forKey: .memoStyleRuns) ?? []
        overallRating = try container.decodeIfPresent(Double.self, forKey: .overallRating) ?? 0
        momentEntries = try container.decodeIfPresent([VisitMomentEntry].self, forKey: .momentEntries) ?? []
        liveSetlistEntries = try container.decodeIfPresent([LiveSetlistEntry].self, forKey: .liveSetlistEntries) ?? []
        people = try container.decodeIfPresent([PlanMemoryPerson].self, forKey: .people) ?? []
        amountText = try container.decodeIfPresent(String.self, forKey: .amountText) ?? ""
        expenseEntries = try container.decodeIfPresent([VisitExpenseEntry].self, forKey: .expenseEntries) ?? []
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText) ?? ""
        advancedEntries = try container.decodeIfPresent([AdvancedFieldEntry].self, forKey: .advancedEntries) ?? []
        admissionPreparationConfirmedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .admissionPreparationConfirmedAt
        )
        admissionPreparationSnoozedUntil = try container.decodeIfPresent(
            Date.self,
            forKey: .admissionPreparationSnoozedUntil
        )
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
            attendanceMethodKey: attendanceMethodKey,
            tasks: normalizedTasks,
            tagNames: tagNames,
            memoStyleRuns: memoStyleRuns,
            overallRating: overallRating,
            momentEntries: momentEntries.map(\.normalized).filter { !$0.isEmpty },
            liveSetlistEntries: liveSetlistEntries.map(\.normalized).filter { !$0.isEmpty },
            people: people.filter { !$0.trimmedName.isEmpty },
            amountText: amountText.trimmingCharacters(in: .whitespacesAndNewlines),
            expenseEntries: expenseEntries
                .map { VisitExpenseEntry(id: $0.id, title: $0.normalizedTitle, amount: $0.normalizedAmount) }
                .filter { !$0.isEmpty },
            ocrText: ocrText.trimmingCharacters(in: .whitespacesAndNewlines),
            advancedEntries: advancedEntries.map(\.normalized).filter { !$0.isEmpty },
            admissionPreparationConfirmedAt: admissionPreparationConfirmedAt,
            admissionPreparationSnoozedUntil: admissionPreparationSnoozedUntil
        )
        guard normalized.checklistMode != .automatic
                || !normalized.tasks.isEmpty
                || !normalized.tagNames.isEmpty
                || !normalized.memoStyleRuns.isEmpty
                || normalized.overallRating > 0
                || !normalized.momentEntries.isEmpty
                || !normalized.liveSetlistEntries.isEmpty
                || !normalized.people.isEmpty
                || !normalized.amountText.isEmpty
                || !normalized.expenseEntries.isEmpty
                || !normalized.ocrText.isEmpty
                || !normalized.advancedEntries.isEmpty
                || normalized.admissionPreparationConfirmedAt != nil
                || normalized.admissionPreparationSnoozedUntil != nil,
              let data = try? JSONEncoder().encode(normalized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

/// 予定段階で入力した「人物・団体」を、記録作成まで保持する軽量スナップショット。
/// PersonMaster / EventPersonLink は記録保存時に既存の解決処理を通して作成する。
nonisolated struct PlanMemoryPerson: Codable, Equatable {
    var name: String = ""
    var reading: String = ""
    var roleKey: String = "cast"
    var roleDetail: String = ""
    var affiliationName: String = ""
    var entityKindKey: String = PersonEntityKind.person.rawValue
    var parentOrganizationID: UUID?
    var relationshipTagKeys: [String] = []
    var isEventFocus = false

    private enum CodingKeys: String, CodingKey {
        case name
        case reading
        case roleKey
        case roleDetail
        case affiliationName
        case entityKindKey
        case parentOrganizationID
        case relationshipTagKeys
        case isEventFocus
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        name: String = "",
        reading: String = "",
        roleKey: String = "cast",
        roleDetail: String = "",
        affiliationName: String = "",
        entityKindKey: String = PersonEntityKind.person.rawValue,
        parentOrganizationID: UUID? = nil,
        relationshipTagKeys: [String] = [],
        isEventFocus: Bool = false
    ) {
        self.name = name
        self.reading = reading
        self.roleKey = roleKey
        self.roleDetail = roleDetail
        self.affiliationName = affiliationName
        self.entityKindKey = entityKindKey
        self.parentOrganizationID = parentOrganizationID
        self.relationshipTagKeys = relationshipTagKeys
        self.isEventFocus = isEventFocus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        reading = try container.decodeIfPresent(String.self, forKey: .reading) ?? ""
        roleKey = try container.decodeIfPresent(String.self, forKey: .roleKey) ?? "cast"
        roleDetail = try container.decodeIfPresent(String.self, forKey: .roleDetail) ?? ""
        affiliationName = try container.decodeIfPresent(String.self, forKey: .affiliationName) ?? ""
        entityKindKey = try container.decodeIfPresent(String.self, forKey: .entityKindKey)
            ?? PersonEntityKind.person.rawValue
        parentOrganizationID = try container.decodeIfPresent(UUID.self, forKey: .parentOrganizationID)
        relationshipTagKeys = try container.decodeIfPresent([String].self, forKey: .relationshipTagKeys) ?? []
        isEventFocus = try container.decodeIfPresent(Bool.self, forKey: .isEventFocus) ?? false
    }

    @MainActor init(_ pending: PendingPersonLink) {
        self.init(
            name: pending.name,
            reading: pending.reading,
            roleKey: pending.role.key,
            roleDetail: pending.roleDetail,
            affiliationName: pending.affiliationName,
            entityKindKey: pending.entityKind.rawValue,
            parentOrganizationID: pending.parentOrganizationID,
            relationshipTagKeys: pending.relationshipTagKeys,
            isEventFocus: pending.isEventFocus
        )
    }

    @MainActor var pendingPersonLink: PendingPersonLink {
        PendingPersonLink(
            name: trimmedName,
            reading: reading,
            role: PersonRoleOption.option(for: roleKey),
            roleDetail: roleDetail,
            affiliationName: affiliationName,
            entityKind: PersonEntityKind(rawValue: entityKindKey) ?? .person,
            parentOrganizationID: parentOrganizationID,
            relationshipTagKeys: relationshipTagKeys,
            isEventFocus: isEventFocus
        )
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
    case hotel
    case shinkansen
    case flight
    case highwayBus
    case localTransport
    case rentalCar
    case baggage
    case otherTravel
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hotel: return "宿泊"
        case .shinkansen: return "新幹線"
        case .flight: return "飛行機"
        case .highwayBus: return "高速・夜行バス"
        case .localTransport: return "現地交通"
        case .rentalCar: return "レンタカー"
        case .baggage: return "荷物・持ち物"
        case .otherTravel: return "その他の遠征"
        case .other: return "その他の準備"
        }
    }

    var systemImage: String {
        switch self {
        case .hotel: return "bed.double"
        case .shinkansen: return "tram.fill"
        case .flight: return "airplane"
        case .highwayBus: return "bus.doubledecker"
        case .localTransport: return "tram"
        case .rentalCar: return "car"
        case .baggage: return "suitcase"
        case .otherTravel: return "map"
        case .other: return "checklist"
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
        if ["高速バス", "夜行バス", "深夜バス", "バスタ"].contains(where: normalized.contains) {
            return .highwayBus
        }
        if ["レンタカー", "カーシェア", "レンタル車"].contains(where: normalized.contains) {
            return .rentalCar
        }
        if ["荷物", "持ち物", "手荷物", "ロッカー", "荷造り"].contains(where: normalized.contains) {
            return .baggage
        }
        if ["バス", "地下鉄", "タクシー", "現地交通", "路線", "乗換"].contains(where: normalized.contains) {
            return .localTransport
        }
        return nil
    }
}

enum PlanPreparationSuggestion {
    static let titles = [
        "宿泊を予約",
        "新幹線を予約",
        "飛行機を予約",
        "高速・夜行バスを予約",
        "現地交通を確認",
        "レンタカーを予約",
        "荷物・持ち物を準備",
        "休暇を申請",
        "同行者へ連絡",
        "グッズを準備",
    ]

    static let emphasizedTitles: Set<String> = [
        "宿泊を予約",
        "新幹線を予約",
        "飛行機を予約",
        "高速・夜行バスを予約",
        "レンタカーを予約",
    ]

}

struct ExperienceExpenseSummary {
    let ticketAttemptAmount: Decimal
    let ticketPhotoAmount: Decimal
    let ticketAmount: Decimal
    let goodsAmount: Decimal
    let foodAmount: Decimal
    let travelAmount: Decimal
    let travelTasks: [PlanPreparationTask]
    let recordEntryAmount: Decimal
    let legacyAmount: Decimal
    let legacyEntries: [VisitExpenseEntry]
    let usesTicketPhotoFallback: Bool
    let usesLegacyFallback: Bool

    var structuredAmount: Decimal {
        ticketAmount + goodsAmount + foodAmount + travelAmount + recordEntryAmount
    }

    var total: Decimal {
        usesLegacyFallback ? legacyAmount : structuredAmount
    }

    static func make(visit: Visit?, plan: Plan?) -> ExperienceExpenseSummary {
        let ticketPhotoAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .ticket)
        let goodsAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .goods)
        let foodAmount = ExperienceExpenseCalculator.photoAmount(for: visit, purpose: .food)
        let ticketAttemptAmount = ExperienceExpenseCalculator.securedTicketAmount(for: plan)
        let travelAmount = ExperienceExpenseCalculator.travelAmount(for: plan)
        let travelTasks = (plan?.preparationFields.orderedTasks ?? [])
            .filter { $0.kind.isTravel && $0.amount > 0 }
        let ticketAmount = ticketAttemptAmount > 0 ? ticketAttemptAmount : ticketPhotoAmount
        let legacyAmount = max(visit?.amount ?? Decimal(0), Decimal(0))
        let legacyEntries = VisitUnitFields(rawValue: visit?.unitFieldsRaw ?? "")
            .expenseEntries
            .filter { !$0.isEmpty }
        let recordEntryAmount = legacyEntries.reduce(Decimal(0)) {
            $0 + max($1.normalizedAmount, Decimal(0))
        }
        let structuredAmount = ticketAmount + goodsAmount + foodAmount + travelAmount + recordEntryAmount

        return ExperienceExpenseSummary(
            ticketAttemptAmount: ticketAttemptAmount,
            ticketPhotoAmount: ticketPhotoAmount,
            ticketAmount: ticketAmount,
            goodsAmount: goodsAmount,
            foodAmount: foodAmount,
            travelAmount: travelAmount,
            travelTasks: travelTasks,
            recordEntryAmount: recordEntryAmount,
            legacyAmount: legacyAmount,
            legacyEntries: legacyEntries,
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
    static let undatedTicketPlanKindKey = "ticketUndated"

    var preparationFields: PlanPreparationFields {
        PlanPreparationFields(rawValue: unitFieldsRaw)
    }

    var hasConfirmedSchedule: Bool {
        planKindKey != Self.undatedTicketPlanKindKey
    }

    func isUpcomingOrOngoing(at date: Date) -> Bool {
        hasConfirmedSchedule && max(startsAt, endsAt) >= date
    }

    var hasConfirmedAdmissionPreparation: Bool {
        preparationFields.admissionPreparationConfirmedAt != nil
    }

    func shouldRequestAdmissionPreparationConfirmation(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard needsAdmissionPreparationConfirmation(now: now, calendar: calendar) else { return false }

        if let snoozedUntil = preparationFields.admissionPreparationSnoozedUntil {
            return now >= snoozedUntil
        }
        return true
    }

    func needsAdmissionPreparationConfirmation(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard hasConfirmedSchedule,
              !isArchived,
              !["attended", "skipped"].contains(stateKey),
              visit == nil,
              startsAt > now,
              !hasConfirmedAdmissionPreparation,
              supportsAdmissionPreparationConfirmation else {
            return false
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let promptDay = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: startsAt)) else {
            return false
        }
        return startOfToday >= promptDay
    }

    var supportsAdmissionPreparationConfirmation: Bool {
        if (ticketAttempts ?? []).contains(where: { !$0.isArchived }) {
            return true
        }
        guard let category else { return false }
        return category.enabledUnitsRaw
            .components(separatedBy: ",")
            .contains("ticketPlan")
    }

    func nextAdmissionPreparationPromptDate(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
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
            && hasConfirmedSchedule
            && preparationFields.isActive(automaticActivation: automaticallyActivatesPreparationChecklist)
    }
}
