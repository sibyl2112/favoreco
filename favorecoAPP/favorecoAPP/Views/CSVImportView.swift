//
//  CSVImportView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @State private var isImporterPresented = false
    @State private var preview: CSVImportPreview?
    @State private var selectedFileName = ""
    @State private var errorMessage = ""

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
                    Text("ジャンル照合、重複判定、保存は次段階で接続します。要修正行がある場合は保存前に除外または修正できるようにします。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
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
    }

    private func inspect(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            preview = try CSVImportService.inspect(data: Data(contentsOf: url))
            selectedFileName = url.lastPathComponent
            errorMessage = ""
        } catch {
            preview = nil
            selectedFileName = ""
            errorMessage = error.localizedDescription
        }
    }
}
