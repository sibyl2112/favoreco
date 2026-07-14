//
//  JSONImportView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct JSONImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isImporterPresented = false
    @State private var preview: JSONBackupPreview?
    @State private var selectedData: Data?
    @State private var restoreResult: JSONBackupRestoreResult?
    @State private var selectedFileName = ""
    @State private var errorMessage = ""
    @State private var isConfirmingRestore = false

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
                    previewRow("旧クイックデータ", preview.inboxCount)
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

                Section("復元") {
                    Button {
                        isConfirmingRestore = true
                    } label: {
                        Label("既存データへ追加・更新", systemImage: "arrow.trianglehead.merge")
                    }
                    .disabled(selectedData == nil)

                    Text("同じUUIDのデータは更新し、存在しないデータは追加します。現在のデータを一括削除することはありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if let restoreResult {
                    Section("復元結果") {
                        Label("復元が完了しました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        LabeledContent("追加", value: "\(restoreResult.insertedCount)件")
                        LabeledContent("更新", value: "\(restoreResult.updatedCount)件")
                        LabeledContent("写真本体なしでスキップ", value: "\(restoreResult.skippedPhotoCount)件")
                        LabeledContent("端末固有参照を解除", value: "\(restoreResult.clearedDeviceReferenceCount)件")
                    }
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
        .confirmationDialog(
            "バックアップを追加・更新しますか？",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("復元を実行") {
                restoreSelectedBackup()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("同じUUIDのデータはバックアップ内容で更新されます。写真本体、通知予約、Keychain、外部カレンダーIDは復元されません。")
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
            selectedData = data
            restoreResult = nil
            selectedFileName = url.lastPathComponent
            errorMessage = ""
        } catch {
            preview = nil
            selectedData = nil
            restoreResult = nil
            selectedFileName = ""
            errorMessage = error.localizedDescription
        }
    }

    private func restoreSelectedBackup() {
        guard let selectedData else { return }
        do {
            restoreResult = try JSONBackupImportService.restore(
                data: selectedData,
                in: modelContext
            )
            errorMessage = ""
        } catch {
            modelContext.rollback()
            restoreResult = nil
            errorMessage = "復元に失敗しました: \(error.localizedDescription)"
        }
    }
}
