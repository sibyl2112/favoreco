//
//  InboxDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct InboxDetailView: View {
    let item: InboxItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @State private var selectedTemplateKey: String
    @State private var isShowingConvertForm = false
    @State private var selectedExistingEventID = ""
    @State private var selectedEventForVisit: ExperienceEvent?
    @State private var operationErrorMessage: String?

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.templateKey == selectedTemplateKey }
    }

    private var existingEvents: [ExperienceEvent] {
        guard let selectedCategory else { return [] }
        return events.filter { !$0.isArchived && $0.category?.id == selectedCategory.id }
    }

    private var selectedExistingEvent: ExperienceEvent? {
        existingEvents.first { $0.id.uuidString == selectedExistingEventID }
    }

    init(item: InboxItem) {
        self.item = item
        _selectedTemplateKey = State(initialValue: item.targetTemplateKey)
    }

    var body: some View {
        Form {
            Section("あとで記録") {
                LabeledContent("タイトル", value: item.title.isEmpty ? "無題" : item.title)

                if !item.sourceURL.isEmpty {
                    LabeledContent("URL", value: item.sourceURL)
                }

                LabeledContent("作成日", value: item.createdAt.formatted(date: .numeric, time: .shortened))
                LabeledContent("状態", value: item.state == "resolved" ? "変換済み" : "未整理")
            }

            if !item.body.isEmpty {
                Section("メモ") {
                    Text(item.body)
                        .font(FavorecoTypography.body)
                }
            }

            Section("変換先") {
                Picker("カテゴリ", selection: $selectedTemplateKey) {
                    Text("未分類").tag("")
                    ForEach(visibleCategories) { category in
                        Text(category.name).tag(category.templateKey)
                    }
                }
            }

            Section {
                Button {
                    isShowingConvertForm = true
                } label: {
                    Label("新しい対象として本記録に変換", systemImage: "rectangle.stack.badge.plus")
                }
                .disabled(selectedCategory == nil || item.state == "resolved")

                if selectedCategory != nil {
                    if existingEvents.isEmpty {
                        Text("このカテゴリには追加先の対象がありません。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("既存の対象", selection: $selectedExistingEventID) {
                            Text("選択してください").tag("")
                            ForEach(existingEvents) { event in
                                Text(event.title.isEmpty ? "記録" : event.title)
                                    .tag(event.id.uuidString)
                            }
                        }

                        Button {
                            selectedEventForVisit = selectedExistingEvent
                        } label: {
                            Label("既存対象に回を追加", systemImage: "plus.square.on.square")
                        }
                        .disabled(selectedExistingEvent == nil || item.state == "resolved")
                    }
                }

                Button(role: .destructive) {
                    deleteItem()
                } label: {
                    Label("Inboxから削除", systemImage: "trash")
                }
            }
        }
        .navigationTitle("あとで記録")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingConvertForm) {
            if let category = selectedCategory {
                AddExperienceView(
                    category: category,
                    initialDraft: AddExperienceDraft(inboxItem: item)
                ) {
                    markResolved(category: category)
                }
            }
        }
        .sheet(item: $selectedEventForVisit) { event in
            AddVisitView(
                event: event,
                initialDraft: VisitDraft(inboxItem: item)
            ) {
                if let category = event.category {
                    markResolved(category: category)
                }
            }
        }
        .onChange(of: selectedTemplateKey) { _, _ in
            selectedExistingEventID = ""
        }
        .alert("処理に失敗しました", isPresented: Binding(
            get: { operationErrorMessage != nil },
            set: { if !$0 { operationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { operationErrorMessage = nil }
        } message: {
            Text(operationErrorMessage ?? "")
        }
    }

    private func markResolved(category: RecordCategory) {
        item.targetTemplateKey = category.templateKey
        item.state = "resolved"
        item.updatedAt = Date()
    }

    private func deleteItem() {
        modelContext.delete(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            operationErrorMessage = "Inbox項目を削除できませんでした。"
            assertionFailure("Failed to delete inbox item: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        InboxDetailView(item: InboxItem(title: "気になる展示", body: "週末に行く候補", sourceURL: "https://example.com"))
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
