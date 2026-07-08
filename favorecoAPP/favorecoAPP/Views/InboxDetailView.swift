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
    @State private var selectedTemplateKey: String
    @State private var isShowingConvertForm = false

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.templateKey == selectedTemplateKey }
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
                    Label("本記録に変換", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(selectedCategory == nil)

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
                    item.targetTemplateKey = category.templateKey
                    item.state = "resolved"
                    item.updatedAt = Date()
                }
            }
        }
    }

    private func deleteItem() {
        modelContext.delete(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
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
