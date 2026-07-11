//
//  CSVImportView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var isImporterPresented = false
    @State private var preview: CSVImportPreview?
    @State private var restoreResult: CSVImportRestoreResult?
    @State private var defaultCategoryID: UUID?
    @State private var selectedFileName = ""
    @State private var errorMessage = ""
    @State private var isConfirmingRestore = false

    private var activeCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var defaultCategory: RecordCategory? {
        activeCategories.first { $0.id == defaultCategoryID } ?? activeCategories.first
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("記録CSVを確認")
                        .font(FavorecoTypography.sectionTitle)
                    Text("保存前に列と各行を検証します。この段階では端末内データを変更しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("ファイル") {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("CSVファイルを選択", systemImage: "doc.badge.plus")
                }
                if !selectedFileName.isEmpty {
                    LabeledContent("選択中", value: selectedFileName)
                }
                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("対応形式") {
                LabeledContent("必須列", value: "date, title")
                Text("category, venue, note（またはmemo）などは任意です。dateはYYYY-MM-DD形式で入力してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if let preview {
                Section("検証結果") {
                    LabeledContent("データ行", value: "\(preview.rows.count)件")
                    LabeledContent("取り込み可能", value: "\(preview.validRows.count)件")
                    LabeledContent("要修正", value: "\(preview.invalidRows.count)件")
                    if preview.invalidRows.isEmpty {
                        Label("すべての行を取り込める形式です", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section("プレビュー") {
                    ForEach(preview.rows.prefix(20)) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.title.isEmpty ? "タイトルなし" : row.title)
                                    .font(FavorecoTypography.bodyStrong)
                                Spacer()
                                Text("\(row.lineNumber)行目")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text([row.dateText, row.category, row.venue].filter { !$0.isEmpty }.joined(separator: " ・ "))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                            ForEach(row.issues, id: \.self) { issue in
                                Label(issue, systemImage: "exclamationmark.circle.fill")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    if preview.rows.count > 20 {
                        Text("先頭20件を表示しています。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("取り込み") {
                    Picker("空欄時のジャンル", selection: Binding(
                        get: { defaultCategory?.id },
                        set: { defaultCategoryID = $0 }
                    )) {
                        ForEach(activeCategories) { category in
                            Label(category.name, systemImage: category.iconSymbol)
                                .tag(Optional(category.id))
                        }
                    }

                    Button {
                        isConfirmingRestore = true
                    } label: {
                        Label("取り込み可能な行を保存", systemImage: "square.and.arrow.down")
                    }
                    .disabled(preview.validRows.isEmpty || defaultCategory == nil)

                    Text("CSVにジャンル名がある行は既存ジャンルと照合します。未登録ジャンル、不正行、重複行は保存せず結果に表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if let restoreResult {
                    Section("保存結果") {
                        Label("CSVの保存が完了しました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        LabeledContent("記録を追加", value: "\(restoreResult.insertedVisitCount)件")
                        LabeledContent("記録を更新", value: "\(restoreResult.updatedVisitCount)件")
                        LabeledContent("対象を追加", value: "\(restoreResult.insertedEventCount)件")
                        LabeledContent("重複をスキップ", value: "\(restoreResult.duplicateCount)件")
                        LabeledContent("不正行をスキップ", value: "\(restoreResult.invalidRowCount)件")
                        LabeledContent("未知ジャンルをスキップ", value: "\(restoreResult.unknownCategoryCount)件")
                    }
                }
            }
        }
        .navigationTitle("CSVインポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            inspect(result)
        }
        .confirmationDialog(
            "CSVの記録を保存しますか？",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("保存を実行") { restore() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("同じvisit_idは更新します。IDがない同一日・同一タイトル・同一会場の行は重複として保存しません。")
        }
        .onAppear {
            if defaultCategoryID == nil {
                defaultCategoryID = activeCategories.first?.id
            }
        }
    }

    private func inspect(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            preview = try CSVImportService.inspect(data: Data(contentsOf: url))
            restoreResult = nil
            selectedFileName = url.lastPathComponent
            errorMessage = ""
        } catch {
            preview = nil
            restoreResult = nil
            selectedFileName = ""
            errorMessage = error.localizedDescription
        }
    }

    private func restore() {
        guard let preview, let defaultCategory else { return }
        do {
            restoreResult = try CSVImportService.restore(
                preview: preview,
                defaultCategory: defaultCategory,
                in: modelContext
            )
            errorMessage = ""
        } catch {
            modelContext.rollback()
            restoreResult = nil
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
