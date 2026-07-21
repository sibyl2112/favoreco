//
//  PlanPreparationChecklistView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import SwiftData
import SwiftUI

struct PlanPreparationChecklistView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var plan: Plan
    let tint: Color
    var highlightedTaskID: UUID? = nil

    @State private var isShowingEditor = false
    @State private var editingTask: PlanPreparationTask?
    @State private var errorMessage = ""

    private var fields: PlanPreparationFields {
        plan.preparationFields
    }

    private var isActive: Bool {
        fields.isActive(automaticActivation: plan.automaticallyActivatesPreparationChecklist)
    }

    private var ticketPhase: PlanPreparationTicketPhase {
        plan.preparationTicketPhase
    }

    private var explicitlyEnabled: Bool {
        fields.checklistMode == .enabled
    }

    private var availableSuggestions: [String] {
        let existing = Set(fields.tasks.map { normalizedTitle($0.title) })
        return orderedSuggestionTitles.filter { !existing.contains(normalizedTitle($0)) }
    }

    private var orderedSuggestionTitles: [String] {
        switch ticketPhase {
        case .secured:
            return ["宿を予約", "交通を手配", "休暇を申請", "同行者へ連絡", "発券・座席を確認", "グッズを準備"]
        case .noTicket, .applying, .closed:
            return PlanPreparationSuggestion.titles
        }
    }

    private var showsSuggestions: Bool {
        guard isActive else { return false }
        if case .closed = ticketPhase { return explicitlyEnabled }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("公演の準備")
                        .font(FavorecoTypography.sectionTitle)
                    if fields.checklistMode == .automatic {
                        Text(automaticStatusText)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Toggle("準備リストを使う", isOn: activeBinding)
                    .labelsHidden()
                    .accessibilityLabel("公演の準備リストを使う")
            }

            if isActive {
                if case .secured = ticketPhase {
                    Label("チケット確保後の宿・交通などを確認しましょう", systemImage: "checkmark.seal.fill")
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
                    }
                }

                Button {
                    editingTask = nil
                    isShowingEditor = true
                } label: {
                    Label("準備項目を追加", systemImage: "plus")
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
        .planPreparationCard()
        .sheet(isPresented: $isShowingEditor) {
            PlanPreparationTaskEditor(
                task: editingTask,
                defaultDueDate: defaultDueDate,
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

    private var automaticStatusText: String {
        switch ticketPhase {
        case .noTicket: return "必要な場合だけ手動で利用"
        case .applying: return "チケット申込中・準備は任意"
        case .secured: return "当選・取得に合わせて表示中"
        case .closed: return "落選・見送りに合わせて自動停止"
        }
    }

    private var emptyStateText: String {
        switch ticketPhase {
        case .secured:
            return "当選・取得後に必要な準備だけを追加できます。"
        case .applying:
            return "結果を待ちながら、必要な準備だけ先に追加できます。"
        case .noTicket, .closed:
            return "宿・交通・同行者への連絡など、必要な準備だけを追加できます。"
        }
    }

    private var suggestionSectionTitle: String {
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
        return "必要な場合だけオンにすると、宿や交通などの準備を公演へ紐づけられます。"
    }

    @ViewBuilder
    private func suggestionButton(_ title: String) -> some View {
        let button = Button {
            addSuggestion(title)
        } label: {
            Label(title, systemImage: "plus")
                .font(FavorecoTypography.captionStrong)
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
        }
        .tint(tint)

        if case .secured = ticketPhase,
           ["宿を予約", "交通を手配"].contains(title) {
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
                editingTask = task
                isShowingEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.trimmedTitle.isEmpty ? "準備項目" : task.trimmedTitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let dueAt = task.dueAt {
                        Label(FavorecoDateText.compactDateTime(dueAt), systemImage: "clock")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(!task.isCompleted && dueAt < Date() ? Color.red : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    editingTask = task
                    isShowingEditor = true
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
        updateFields { fields in
            fields.tasks.append(PlanPreparationTask(
                title: title,
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

    private func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}

private struct PlanPreparationTaskEditor: View {
    @Environment(\.dismiss) private var dismiss

    let task: PlanPreparationTask?
    let defaultDueDate: Date
    let tint: Color
    let onSave: (PlanPreparationTask) -> Void

    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueAt: Date

    init(
        task: PlanPreparationTask?,
        defaultDueDate: Date,
        tint: Color,
        onSave: @escaping (PlanPreparationTask) -> Void
    ) {
        self.task = task
        self.defaultDueDate = defaultDueDate
        self.tint = tint
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _hasDueDate = State(initialValue: task?.dueAt != nil)
        _dueAt = State(initialValue: task?.dueAt ?? defaultDueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("準備すること") {
                    TextField("例：宿を予約", text: $title)
                        .textInputAutocapitalization(.never)
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "日時",
                            selection: $dueAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
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
                        value.dueAt = hasDueDate ? dueAt : nil
                        value.updatedAt = now
                        onSave(value)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .tint(tint)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var trimmedTitle: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
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
