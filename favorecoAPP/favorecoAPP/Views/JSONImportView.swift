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
    @State private var isInspectingFile = false
    @State private var isRestoring = false

    var body: some View {
        Form {
            FavorecoSettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSONバックアップを確認")
                        .font(FavorecoTypography.sectionTitle)
                    Text("復元前にファイル形式と件数を確認します。この画面では端末内データを変更しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            FavorecoSettingsSection("ファイル") {
                Button {
                    isImporterPresented = true
                } label: {
                    if isInspectingFile {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("ファイルを確認中…")
                        }
                    } else {
                        Label("JSONファイルを選択", systemImage: "doc.badge.plus")
                    }
                }
                .disabled(isInspectingFile || isRestoring)

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
                FavorecoSettingsSection("形式確認") {
                    Label("Favorecoバックアップとして確認できました", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    LabeledContent("バックアップ形式", value: "バージョン\(preview.schemaVersion)")
                    LabeledContent("書き出し日時", value: FavorecoDateText.fullDateTime(preview.exportedAt))
                    LabeledContent("復元対象データ", value: "\(preview.totalModelCount)件")
                }

                FavorecoSettingsSection("内容") {
                    previewRow("ジャンル", preview.categoryCount)
                    previewRow("対象", preview.eventCount)
                    previewRow("訪問/鑑賞記録", preview.visitCount)
                    previewRow("人物・団体", preview.personCount)
                    previewRow("同行者", preview.companionCount)
                    previewRow("人物リンク", preview.personLinkCount)
                    previewRow("場所", preview.placeCount)
                    previewRow("予定", preview.planCount)
                    previewRow("登録情報・名義", preview.ticketAccountCount)
                    previewRow("チケット申込", preview.ticketAttemptCount)
                    previewRow("旧形式の気になる項目", preview.inboxCount)
                    previewRow("SNS", preview.socialAccountCount)
                    previewRow("写真メタデータ", preview.photoMetadataCount)
                }

                FavorecoSettingsSection("写真について") {
                    Label("写真・動画本体はこのJSONに含まれません", systemImage: "photo.badge.exclamationmark")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.orange)
                    Text("写真メタデータが\(preview.photoMetadataCount)件ありますが、画像本体は復元できません。写真付き完全バックアップは別方式で対応します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                FavorecoSettingsSection("復元") {
                    Button {
                        isConfirmingRestore = true
                    } label: {
                        if isRestoring {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("復元中…")
                            }
                        } else {
                            Label("既存データへ追加・更新", systemImage: "arrow.trianglehead.merge")
                        }
                    }
                    .disabled(selectedData == nil || isInspectingFile || isRestoring)

                    Text("同じUUIDのデータは更新し、存在しないデータは追加します。現在のデータを一括削除することはありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if let restoreResult {
                    FavorecoSettingsSection("復元結果") {
                        Label("復元が完了しました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        LabeledContent("追加", value: "\(restoreResult.insertedCount)件")
                        LabeledContent("更新", value: "\(restoreResult.updatedCount)件")
                        LabeledContent("写真本体なしでスキップ", value: "\(restoreResult.skippedPhotoCount)件")
                        LabeledContent("端末固有の連携を除外", value: "\(restoreResult.clearedDeviceReferenceCount)件")
                    }
                }
            }
        }
        .favorecoSettingsListLayout()
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
            guard !isInspectingFile, !isRestoring else { return }
            isInspectingFile = true
            preview = nil
            selectedData = nil
            restoreResult = nil
            selectedFileName = url.lastPathComponent
            errorMessage = ""

            Task { @MainActor in
                defer { isInspectingFile = false }
                do {
                    let inspection = try await Task.detached(priority: .userInitiated) {
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer {
                            if hasAccess {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                        let data = try Data(contentsOf: url)
                        return (data, try JSONBackupImportService.inspect(data: data))
                    }.value
                    selectedData = inspection.0
                    preview = inspection.1
                } catch {
                    preview = nil
                    selectedData = nil
                    restoreResult = nil
                    selectedFileName = ""
                    errorMessage = "ファイルを確認できませんでした: \(error.localizedDescription)"
                }
            }
        } catch {
            preview = nil
            selectedData = nil
            restoreResult = nil
            selectedFileName = ""
            errorMessage = "ファイルを選択できませんでした: \(error.localizedDescription)"
        }
    }

    private func restoreSelectedBackup() {
        guard let selectedData, !isInspectingFile, !isRestoring else { return }
        isRestoring = true
        restoreResult = nil
        errorMessage = ""

        Task { @MainActor in
            await Task.yield()
            defer { isRestoring = false }
            do {
                let envelope = try await Task.detached(priority: .userInitiated) {
                    try JSONBackupImportService.decodedBackup(data: selectedData)
                }.value
                restoreResult = try JSONBackupImportService.restore(
                    envelope: envelope,
                    in: modelContext
                )
            } catch {
                modelContext.rollback()
                restoreResult = nil
                errorMessage = "復元に失敗しました。データは変更されていません。もう一度お試しください。\n\(error.localizedDescription)"
            }
        }
    }
}
