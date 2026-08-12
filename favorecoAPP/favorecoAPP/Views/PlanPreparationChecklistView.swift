//
//  PlanPreparationChecklistView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import PhotosUI
import SwiftData
import SwiftUI

enum PlanPreparationPresentation {
    case planning
    case record
}

struct PlanPreparationChecklistView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var plan: Plan
    let tint: Color
    var title = "公演の準備・遠征"
    var highlightedTaskID: UUID? = nil
    var presentation: PlanPreparationPresentation = .planning
    var showsHeader = true
    var appliesCardBackground = true

    @State private var editorRequest: PlanPreparationEditorRequest?
    @State private var errorMessage = ""

    private var fields: PlanPreparationFields {
        plan.preparationFields
    }

    private var isActive: Bool {
        switch presentation {
        case .planning:
            return fields.isActive(automaticActivation: plan.automaticallyActivatesPreparationChecklist)
        case .record:
            return true
        }
    }

    private var canEditTasks: Bool {
        plan.supportsPreparationChecklist
    }

    private var ticketPhase: PlanPreparationTicketPhase {
        plan.preparationTicketPhase
    }

    private var explicitlyEnabled: Bool {
        fields.checklistMode == .enabled
    }

    private var availableSuggestions: [String] {
        orderedSuggestionTitles
    }

    private var orderedSuggestionTitles: [String] {
        PlanPreparationSuggestion.titles
    }

    private var showsSuggestions: Bool {
        guard isActive else { return false }
        if presentation == .record { return true }
        if case .closed = ticketPhase { return explicitlyEnabled }
        return true
    }

    var body: some View {
        Group {
            if appliesCardBackground {
                content
                    .planPreparationCard()
            } else {
                content
            }
        }
        .sheet(item: $editorRequest) { request in
            PlanPreparationTaskEditor(
                task: request.task,
                defaultDueDate: defaultDueDate,
                defaultScheduleDate: plan.startsAt,
                tint: tint
            ) { task in
                save(task)
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { !errorMessage.isEmpty },
            set: { if !$0 { errorMessage = "" } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(FavorecoTypography.sectionTitle)
                        if !plan.hasConfirmedSchedule {
                            Text("参加日未定でも入力できます")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        } else if presentation == .record {
                            Text("宿泊・交通の実績と金額をこの回へ残します")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        } else if fields.checklistMode == .automatic {
                            Text(automaticStatusText)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 12)

                    if presentation == .planning {
                        Toggle("準備リストを使う", isOn: activeBinding)
                            .labelsHidden()
                            .accessibilityLabel("公演の準備リストを使う")
                    }
                }
            }

            if !canEditTasks {
                FavorecoIconLabel(
                    "参加日を確定すると、遠征ToDoを入力できます。",
                    systemImage: "calendar.badge.exclamationmark"
                )
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isActive {
                if case .secured = ticketPhase {
                    FavorecoIconLabel(
                        "チケット確保後の宿・交通と費用をまとめられます",
                        systemImage: "checkmark.seal.fill"
                    )
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if fields.tasks.isEmpty {
                    Text(emptyStateText)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 2) {
                        ForEach(fields.orderedTasks) { task in
                            taskRow(task)
                        }
                    }
                }

                if showsSuggestions && !availableSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(suggestionSectionTitle)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableSuggestions, id: \.self) { title in
                                    suggestionButton(title)
                                }
                            }
                        }
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: CategoryDetailSwipeExclusionPreferenceKey.self,
                                    value: [proxy.frame(in: .global).insetBy(dx: -6, dy: -6)]
                                )
                            }
                        }
                    }
                }

                Button {
                    editorRequest = PlanPreparationEditorRequest(task: nil)
                } label: {
                    FavorecoIconLabel(
                        presentation == .record ? "遠征・準備の記録を追加" : "準備・遠征項目を追加",
                        systemImage: "plus"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(tint)
            } else {
                Text(inactiveStateText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .saturation(canEditTasks ? 1 : 0)
        .opacity(canEditTasks ? 1 : 0.55)
        .disabled(!canEditTasks)
    }

    private var automaticStatusText: String {
        switch ticketPhase {
        case .noTicket: return "必要な場合だけ手動で利用"
        case .applying: return "チケット申込中・準備は任意"
        case .secured: return "当選・取得に合わせて表示中"
        case .closed: return "落選・見送りに合わせて自動停止"
        }
    }

    private var emptyStateText: String {
        if presentation == .record {
            return "宿泊・新幹線・飛行機など、実際に使った内容と金額を追加できます。"
        }
        switch ticketPhase {
        case .secured:
            return "当選・取得後に必要な準備だけを追加できます。"
        case .applying:
            return "結果を待ちながら、必要な準備だけ先に追加できます。"
        case .noTicket, .closed:
            return "宿泊・交通・荷物・同行者への連絡など、必要な項目だけを追加できます。"
        }
    }

    private var suggestionSectionTitle: String {
        if presentation == .record { return "履歴を追加" }
        switch ticketPhase {
        case .secured: return "当選・取得後に確認"
        case .applying: return "必要なら先に追加"
        case .noTicket, .closed: return "追加候補"
        }
    }

    private var inactiveStateText: String {
        if fields.checklistMode == .disabled {
            return "この公演では準備リストを使わない設定です。追加済み項目は保持されています。"
        }
        if case .closed = ticketPhase {
            return "落選・見送りのため準備候補を閉じました。追加済み項目は削除せず保持しています。"
        }
        return "必要な場合だけオンにすると、遠征日程・費用・準備ToDoを公演へ紐づけられます。"
    }

    @ViewBuilder
    private func suggestionButton(_ title: String) -> some View {
        let button = Button {
            addSuggestion(title)
        } label: {
            FavorecoIconLabel(title, systemImage: "plus", iconSize: 17)
        }
        .tint(tint)

        if case .secured = ticketPhase,
           PlanPreparationSuggestion.emphasizedTitles.contains(title) {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { isActive },
            set: { newValue in
                updateFields { fields in
                    fields.checklistModeKey = newValue
                        ? PlanPreparationFields.ChecklistMode.enabled.rawValue
                        : PlanPreparationFields.ChecklistMode.disabled.rawValue
                }
            }
        )
    }

    private var defaultDueDate: Date {
        let calendar = Calendar.current
        let suggested = calendar.date(byAdding: .day, value: -1, to: plan.startsAt) ?? plan.startsAt
        return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: suggested) ?? suggested
    }

    private func taskRow(_ task: PlanPreparationTask) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(task.isCompleted ? Color.green : tint)
                    .frame(width: 32, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "未完了に戻す" : "完了にする")

            Button {
                editorRequest = PlanPreparationEditorRequest(task: task)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.trimmedTitle.isEmpty ? "準備項目" : task.trimmedTitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let dueAt = task.dueAt {
                        FavorecoIconLabel(
                            FavorecoDateText.compactDateTime(dueAt),
                            systemImage: "clock",
                            iconSize: 13
                        )
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(!task.isCompleted && dueAt < Date() ? Color.red : .secondary)
                    }

                    if let startsAt = task.startsAt {
                        FavorecoIconLabel(
                            scheduleText(for: task, startsAt: startsAt),
                            systemImage: task.kind.systemImage,
                            iconSize: 13
                        )
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    } else if task.kind.isTravel {
                        FavorecoIconLabel(task.kind.title, systemImage: task.kind.systemImage, iconSize: 13)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if task.amount > 0 {
                        Text(currencyText(task.amount))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    editorRequest = PlanPreparationEditorRequest(task: task)
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    delete(task)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 40)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background {
            if task.id == highlightedTaskID {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(.separator).opacity(0.35)).frame(height: 0.5)
        }
        .id(task.id)
    }

    private func addSuggestion(_ title: String) {
        let now = Date()
        let kind = PlanPreparationKind.inferred(from: title) ?? .other
        updateFields { fields in
            fields.tasks.append(PlanPreparationTask(
                title: title,
                kindKey: kind.rawValue,
                sortOrder: fields.tasks.count,
                createdAt: now,
                updatedAt: now
            ))
        }
    }

    private func save(_ task: PlanPreparationTask) {
        updateFields { fields in
            if let index = fields.tasks.firstIndex(where: { $0.id == task.id }) {
                fields.tasks[index] = task
            } else {
                var task = task
                task.sortOrder = fields.tasks.count
                fields.tasks.append(task)
            }
        }
    }

    private func toggleCompletion(_ task: PlanPreparationTask) {
        updateFields { fields in
            guard let index = fields.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            fields.tasks[index].isCompleted.toggle()
            fields.tasks[index].completedAt = fields.tasks[index].isCompleted ? Date() : nil
            fields.tasks[index].updatedAt = Date()
        }
    }

    private func delete(_ task: PlanPreparationTask) {
        updateFields { fields in
            fields.tasks.removeAll { $0.id == task.id }
        }
    }

    private func updateFields(_ update: (inout PlanPreparationFields) -> Void) {
        guard canEditTasks else { return }
        let previousValue = plan.unitFieldsRaw
        var fields = plan.preparationFields
        update(&fields)
        plan.unitFieldsRaw = fields.encodedRawValue
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            Task {
                await TicketNotificationScheduler.reschedulePreparation(plan: plan)
            }
        } catch {
            modelContext.rollback()
            plan.unitFieldsRaw = previousValue
            errorMessage = "公演の準備を保存できませんでした。もう一度お試しください。"
        }
    }

    private func scheduleText(for task: PlanPreparationTask, startsAt: Date) -> String {
        guard let endsAt = task.endsAt, endsAt > startsAt else {
            return "\(task.kind.title)・\(FavorecoDateText.compactDateTime(startsAt))"
        }
        return "\(task.kind.title)・\(FavorecoDateText.range(from: startsAt, to: endsAt))"
    }

    private func currencyText(_ amount: Decimal) -> String {
        NumberFormatter.planCurrency.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).intValue)"
    }
}

private struct PlanPreparationEditorRequest: Identifiable {
    let id = UUID()
    let task: PlanPreparationTask?
}

private struct PlanPreparationTaskEditor: View {
    @Environment(\.dismiss) private var dismiss

    let task: PlanPreparationTask?
    let defaultDueDate: Date
    let defaultScheduleDate: Date
    let tint: Color
    let onSave: (PlanPreparationTask) -> Void

    @State private var title: String
    @State private var kind: PlanPreparationKind
    @State private var hasSchedule: Bool
    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var amountText: String
    @State private var ocrText: String
    @State private var ocrItems: [PhotosPickerItem] = []

    init(
        task: PlanPreparationTask?,
        defaultDueDate: Date,
        defaultScheduleDate: Date,
        tint: Color,
        onSave: @escaping (PlanPreparationTask) -> Void
    ) {
        self.task = task
        self.defaultDueDate = defaultDueDate
        self.defaultScheduleDate = defaultScheduleDate
        self.tint = tint
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _kind = State(initialValue: task?.kind ?? .other)
        _hasSchedule = State(initialValue: task?.startsAt != nil || task?.endsAt != nil)
        _startsAt = State(initialValue: task?.startsAt ?? defaultScheduleDate)
        _endsAt = State(initialValue: task?.endsAt ?? defaultScheduleDate.addingTimeInterval(60 * 60))
        _hasDueDate = State(initialValue: task?.dueAt != nil)
        _dueAt = State(initialValue: task?.dueAt ?? defaultDueDate)
        _amountText = State(initialValue: Self.amountString(task?.amount ?? Decimal(0)))
        _ocrText = State(initialValue: task?.ocrText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("準備すること") {
                    TextField("例：宿泊を予約", text: $title)
                        .textInputAutocapitalization(.never)

                    Picker("種類", selection: $kind) {
                        ForEach(PlanPreparationKind.allCases) { kind in
                            FavorecoIconLabel(kind.title, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                }

                Section("遠征スケジュール") {
                    Toggle("日時を設定", isOn: $hasSchedule)
                    if hasSchedule {
                        FiveMinuteDateTimeRow(title: "開始", selection: scheduleStartBinding)
                        FiveMinuteDateTimeRow(title: "終了", selection: scheduleEndBinding)
                    }

                    if kind.isTravel {
                        HStack {
                            Text("費用")
                            Spacer()
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("円")
                                .foregroundStyle(.secondary)
                        }

                        Text("入力した費用は、チケット・グッズと一緒に公演の費用合計へ反映されます。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("費用を合算する項目は、宿泊・交通・その他の遠征から種類を選んでください。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    if hasDueDate {
                        FiveMinuteDateTimeRow(title: "日時", selection: dueAtBinding)
                    }
                }

                Section("画像OCR") {
                    OCRUnitEditor(
                        ocrText: $ocrText,
                        selectedItems: $ocrItems,
                        supportsTitleSuggestion: true,
                        onApplySuggestion: applyOCRSuggestion
                    )

                    if let inferredKind = PlanPreparationKind.inferred(from: ocrText), inferredKind != kind {
                        Button {
                            kind = inferredKind
                        } label: {
                            FavorecoIconLabel(
                                "種類候補「\(inferredKind.title)」を反映",
                                systemImage: inferredKind.systemImage
                            )
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("OCR結果は候補です。種類・日時・費用は確認して反映し、保存するまで確定しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle(task == nil ? "準備項目を追加" : "準備項目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let now = Date()
                        var value = task ?? PlanPreparationTask(createdAt: now)
                        value.title = trimmedTitle
                        value.kindKey = kind.rawValue
                        value.startsAt = hasSchedule ? startsAt : nil
                        value.endsAt = hasSchedule ? max(endsAt, startsAt) : nil
                        value.dueAt = hasDueDate ? dueAt : nil
                        value.amount = kind.isTravel ? parsedAmount : Decimal(0)
                        value.ocrText = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                        value.updatedAt = now
                        onSave(value)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .tint(tint)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var trimmedTitle: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    }

    private var scheduleStartBinding: Binding<Date> {
        Binding {
            startsAt
        } set: { newValue in
            let rounded = newValue.roundedToNearestFiveMinutes()
            startsAt = rounded
            if endsAt < rounded {
                endsAt = rounded.addingTimeInterval(60 * 60)
            }
        }
    }

    private var scheduleEndBinding: Binding<Date> {
        Binding {
            endsAt
        } set: { newValue in
            endsAt = max(newValue.roundedToNearestFiveMinutes(), startsAt)
        }
    }

    private var dueAtBinding: Binding<Date> {
        Binding {
            dueAt
        } set: { newValue in
            dueAt = newValue.roundedToNearestFiveMinutes()
        }
    }

    private var parsedAmount: Decimal {
        let digits = amountText.filter(\.isNumber)
        guard !digits.isEmpty else { return Decimal(0) }
        return Decimal(string: digits) ?? Decimal(0)
    }

    private func applyOCRSuggestion(_ suggestion: OCRImportSuggestion) {
        switch suggestion.kind {
        case .title:
            title = suggestion.value
        case .date:
            guard let date = suggestion.dateValue else { return }
            hasSchedule = true
            startsAt = date
            endsAt = date.addingTimeInterval(60 * 60)
        case .venue:
            if trimmedTitle.isEmpty {
                title = "\(suggestion.value)を確認"
            }
        case .amount:
            amountText = suggestion.value
        }
    }

    private static func amountString(_ amount: Decimal) -> String {
        guard amount > 0 else { return "" }
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

private extension View {
    func planPreparationCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
