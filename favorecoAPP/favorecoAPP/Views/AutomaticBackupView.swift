import SwiftData
import SwiftUI

struct AutomaticBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.automaticBackupLastCreatedAt) private var lastCreatedAt = Date.distantPast
    @State private var snapshots: [AutomaticBackupSnapshot] = []
    @State private var selectedSnapshot: AutomaticBackupSnapshot?
    @State private var isConfirmingRestore = false
    @State private var isWorking = false
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("保存先", value: "この端末")
                LabeledContent("保持数", value: "最大\(AutomaticBackupService.retentionCount)世代")
                LabeledContent("最終作成", value: lastCreatedText)
                Button {
                    createSnapshot()
                } label: {
                    Label("今すぐバックアップ", systemImage: "arrow.clockwise.icloud")
                }
                .disabled(isWorking)
            } header: {
                Text("自動バックアップ")
            } footer: {
                Text("端末内の記録と写真を世代保存します。端末の紛失やアプリ削除に備えるには、完全バックアップをFilesやiCloud Driveへ手動保存してください。")
            }

            Section("保存済み世代") {
                if snapshots.isEmpty {
                    Text("バックアップはまだありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshots) { snapshot in
                        Button {
                            selectedSnapshot = snapshot
                            isConfirmingRestore = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.primary)
                                    Text(ByteCountFormatter.string(fromByteCount: snapshot.byteCount, countStyle: .file))
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "clock.arrow.circlepath")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(snapshot)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("処理中です。")
                    }
                }
            }

            if !message.isEmpty {
                Section("結果") {
                    Text(message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(message.hasPrefix("失敗") ? .red : .secondary)
                }
            }
        }
        .navigationTitle("自動バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .confirmationDialog("この世代を復元しますか？", isPresented: $isConfirmingRestore, titleVisibility: .visible) {
            Button("既存データへ追加・更新") { restoreSelectedSnapshot() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("同じUUIDは更新し、存在しないデータと写真を追加します。現在のデータは一括削除しません。")
        }
    }

    private var lastCreatedText: String {
        guard lastCreatedAt != .distantPast else { return "未作成" }
        return lastCreatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func createSnapshot() {
        isWorking = true
        message = ""
        do {
            if try AutomaticBackupService.create(in: modelContext) != nil {
                message = "バックアップを作成しました。"
            } else {
                message = "保存できるデータがまだありません。"
            }
            reload()
        } catch {
            message = "失敗: \(error.localizedDescription)"
        }
        isWorking = false
    }

    private func restoreSelectedSnapshot() {
        guard let selectedSnapshot else { return }
        isWorking = true
        do {
            let result = try FullBackupService.restore(packageURL: selectedSnapshot.url, in: modelContext)
            message = "復元完了: データ\(result.modelResult.totalRestoredCount)件、写真追加\(result.insertedPhotoCount)枚、写真更新\(result.updatedPhotoCount)枚"
        } catch {
            modelContext.rollback()
            message = "失敗: \(error.localizedDescription)"
        }
        isWorking = false
    }

    private func delete(_ snapshot: AutomaticBackupSnapshot) {
        do {
            try AutomaticBackupService.delete(snapshot)
            reload()
            message = "バックアップを削除しました。"
        } catch {
            message = "失敗: \(error.localizedDescription)"
        }
    }

    private func reload() {
        do {
            snapshots = try AutomaticBackupService.snapshots()
        } catch {
            snapshots = []
            message = "失敗: \(error.localizedDescription)"
        }
    }
}
