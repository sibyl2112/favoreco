//
//  JSONImportView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import UniformTypeIdentifiers

struct JSONImportView: View {
    @State private var isImporterPresented = false
    @State private var preview: JSONBackupPreview?
    @State private var selectedFileName = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSONバックアップを確認")
                        .font(FavorecoTypography.sectionTitle)
                    Text("復元前にファイル形式と件数を確認します。この画面では端末内データを変更しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("ファイル") {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("JSONファイルを選択", systemImage: "doc.badge.plus")
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

            if let preview {
                Section("形式確認") {
                    Label("Favorecoバックアップとして確認できました", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    LabeledContent("形式", value: "schema \(preview.schemaVersion)")
                    LabeledContent("書き出し日時", value: preview.exportedAt.formatted(date: .long, time: .shortened))
                    LabeledContent("復元対象モデル", value: "\(preview.totalModelCount)件")
                }

                Section("内容") {
                    previewRow("ジャンル", preview.categoryCount)
                    previewRow("対象", preview.eventCount)
                    previewRow("訪問/鑑賞記録", preview.visitCount)
                    previewRow("人物・団体", preview.personCount)
                    previewRow("人物リンク", preview.personLinkCount)
                    previewRow("場所", preview.placeCount)
                    previewRow("予定", preview.planCount)
                    previewRow("登録情報・名義", preview.ticketAccountCount)
                    previewRow("チケット申込", preview.ticketAttemptCount)
                    previewRow("あとで記録", preview.inboxCount)
                    previewRow("SNS", preview.socialAccountCount)
                    previewRow("写真メタデータ", preview.photoMetadataCount)
                }

                Section("写真について") {
                    Label("写真・動画本体はこのJSONに含まれません", systemImage: "photo.badge.exclamationmark")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.orange)
                    Text("写真メタデータが\(preview.photoMetadataCount)件ありますが、画像本体は復元できません。写真付き完全バックアップは別方式で対応します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Section("次の段階") {
                    Text("形式確認済みのデータを既存データへUUID基準で追加・更新し、人物・場所・予定・チケットなどの関係を再構築する復元処理を次に接続します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("JSONインポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func previewRow(_ title: String, _ count: Int) -> some View {
        LabeledContent(title, value: "\(count)")
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            preview = try JSONBackupImportService.inspect(data: data)
            selectedFileName = url.lastPathComponent
            errorMessage = ""
        } catch {
            preview = nil
            selectedFileName = ""
            errorMessage = error.localizedDescription
        }
    }
}
