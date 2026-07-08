//
//  AddInboxItemView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct AddInboxItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var draft = InboxDraft()

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("あとで記録") {
                    TextField("タイトル", text: $draft.title)
                    TextField("URL（任意）", text: $draft.sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("カテゴリ候補") {
                    Picker("カテゴリ", selection: $draft.targetTemplateKey) {
                        Text("未分類").tag("")
                        ForEach(visibleCategories) { category in
                            Text(category.name).tag(category.templateKey)
                        }
                    }
                }

                Section("メモ") {
                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("気になった理由、あとで調べたいことなど")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.body)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("あとで記録")
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
        let item = InboxItem(
            title: draft.trimmedTitle,
            body: draft.trimmedBody,
            sourceURL: draft.trimmedSourceURL,
            targetTemplateKey: draft.targetTemplateKey,
            createdAt: now,
            updatedAt: now
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save inbox item: \(error)")
        }
    }
}

private struct InboxDraft {
    var title: String = ""
    var body: String = ""
    var sourceURL: String = ""
    var targetTemplateKey: String = ""

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSourceURL: String {
        sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }
}

#Preview {
    AddInboxItemView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
