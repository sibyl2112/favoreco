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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = AddExperienceDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("対象") {
                    TextField("タイトル", text: $draft.title)
                    TextField("シリーズ・ツアー名（任意）", text: $draft.seriesName)
                }

                Section("この回") {
                    DatePicker("日付", selection: $draft.visitedAt, displayedComponents: .date)
                    TextField("場所（任意）", text: $draft.venueName)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("評価")
                            Spacer()
                            Text(draft.ratingLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $draft.overallRating, in: 0...5, step: 0.5)
                    }
                }

                Section("メモ") {
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 120)
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

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save experience: \(error)")
        }
    }
}

private struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var visitedAt: Date = Date()
    var venueName: String = ""
    var overallRating: Double = 0
    var note: String = ""

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
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

#Preview {
    AddExperienceView(category: RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45"))
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
