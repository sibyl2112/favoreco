//
//  AddExperienceView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct AddExperienceView: View {
    let category: RecordCategory
    let onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    init(
        category: RecordCategory,
        initialDraft: AddExperienceDraft = AddExperienceDraft(),
        onSave: (() -> Void)? = nil
    ) {
        self.category = category
        self.onSave = onSave
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(template.targetSectionTitle) {
                    TextField(template.titlePlaceholder, text: $draft.title)
                    TextField(template.seriesPlaceholder, text: $draft.seriesName)
                    TextField("公式URL（任意）", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section(template.visitSectionTitle) {
                    DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
                    TextField(template.venuePlaceholder, text: $draft.venueName)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(template.ratingLabel)
                            Spacer()
                            Text(draft.ratingLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $draft.overallRating, in: 0...5, step: 0.5)
                    }
                }

                Section(template.memoSectionTitle) {
                    ZStack(alignment: .topLeading) {
                        if draft.note.isEmpty {
                            Text(template.memoPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.note)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func save() {
        let now = Date()
        let event = ExperienceEvent(
            title: draft.trimmedTitle,
            seriesName: draft.trimmedSeriesName,
            officialURL: draft.trimmedOfficialURL,
            createdAt: now,
            updatedAt: now,
            category: category
        )
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: draft.visitedAt,
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            note: draft.trimmedNote,
            createdAt: now,
            updatedAt: now,
            event: event
        )

        modelContext.insert(event)
        modelContext.insert(visit)
        onSave?()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save experience: \(error)")
        }
    }
}

struct EditExperienceView: View {
    let visit: Visit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft

    private var event: ExperienceEvent? {
        visit.event
    }

    private var category: RecordCategory? {
        event?.category
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    init(visit: Visit) {
        self.visit = visit
        _draft = State(initialValue: AddExperienceDraft(visit: visit))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(template.targetSectionTitle) {
                    TextField(template.titlePlaceholder, text: $draft.title)
                    TextField(template.seriesPlaceholder, text: $draft.seriesName)
                    TextField("公式URL（任意）", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section(template.visitSectionTitle) {
                    DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
                    TextField(template.venuePlaceholder, text: $draft.venueName)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(template.ratingLabel)
                            Spacer()
                            Text(draft.ratingLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $draft.overallRating, in: 0...5, step: 0.5)
                    }
                }

                Section(template.memoSectionTitle) {
                    ZStack(alignment: .topLeading) {
                        if draft.note.isEmpty {
                            Text(template.memoPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.note)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func save() {
        let now = Date()

        if let event {
            event.title = draft.trimmedTitle
            event.seriesName = draft.trimmedSeriesName
            event.officialURL = draft.trimmedOfficialURL
            event.updatedAt = now
        }

        visit.visitedAt = draft.visitedAt
        visit.endedAt = draft.visitedAt
        visit.venueNameSnapshot = draft.trimmedVenueName
        visit.overallRating = draft.overallRating
        visit.note = draft.trimmedNote
        visit.updatedAt = now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to update experience: \(error)")
        }
    }
}

struct AddVisitView: View {
    let event: ExperienceEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = VisitDraft()

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(template.targetSectionTitle) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.bodyStrong)
                        if !event.seriesName.isEmpty {
                            Text(event.seriesName)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(template.visitSectionTitle) {
                    DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
                    TextField(template.venuePlaceholder, text: $draft.venueName)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(template.ratingLabel)
                            Spacer()
                            Text(draft.ratingLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $draft.overallRating, in: 0...5, step: 0.5)
                    }
                }

                Section(template.memoSectionTitle) {
                    ZStack(alignment: .topLeading) {
                        if draft.note.isEmpty {
                            Text(template.memoPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.note)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("回を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        let now = Date()
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: draft.visitedAt,
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            note: draft.trimmedNote,
            createdAt: now,
            updatedAt: now,
            event: event
        )

        event.updatedAt = now
        modelContext.insert(visit)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save visit: \(error)")
        }
    }
}

struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var officialURL: String = ""
    var visitedAt: Date = Date()
    var venueName: String = ""
    var overallRating: Double = 0
    var note: String = ""

    init() {}

    init(visit: Visit) {
        title = visit.event?.title ?? ""
        seriesName = visit.event?.seriesName ?? ""
        officialURL = visit.event?.officialURL ?? ""
        visitedAt = visit.visitedAt
        venueName = visit.venueNameSnapshot
        overallRating = visit.overallRating
        note = visit.note
    }

    init(inboxItem: InboxItem) {
        title = inboxItem.title
        officialURL = inboxItem.sourceURL
        note = inboxItem.body
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedVenueName: String {
        venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    var ratingLabel: String {
        if overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", overallRating)
    }
}

private struct VisitDraft {
    var visitedAt: Date = Date()
    var venueName: String = ""
    var overallRating: Double = 0
    var note: String = ""

    var trimmedVenueName: String {
        venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var ratingLabel: String {
        if overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", overallRating)
    }
}

#Preview {
    AddExperienceView(category: RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45"))
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
