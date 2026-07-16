import SwiftData
import SwiftUI

struct AutomaticBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoBlob.createdAt, order: .reverse) private var photos: [PhotoBlob]
    @AppStorage(AppStorageKeys.automaticBackupLastCreatedAt) private var lastCreatedAt = Date.distantPast
    @AppStorage(AppStorageKeys.automaticBackupLastICloudCreatedAt) private var lastICloudCreatedAt = Date.distantPast
    @AppStorage(AppStorageKeys.automaticBackupUsesICloudDrive) private var usesICloudDrive = false
    @AppStorage(AppStorageKeys.automaticBackupICloudError) private var iCloudError = ""
    @State private var localSnapshots: [AutomaticBackupSnapshot] = []
    @State private var iCloudSnapshots: [AutomaticBackupSnapshot] = []
    @State private var selectedSnapshot: AutomaticBackupSnapshot?
    @State private var isConfirmingRestore = false
    @State private var isWorking = false
    @State private var message = ""

    private var totalPhotoBytes: Int64 {
        photos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
    }

    private var effectiveRetentionCount: Int {
        AutomaticBackupService.retentionCount(forPhotoBytes: totalPhotoBytes)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("保存先", value: usesICloudDrive ? "端末 + iCloud Drive" : "この端末")
                LabeledContent("保持数", value: "最大\(effectiveRetentionCount)世代")
                LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
                LabeledContent("端末の最終作成", value: createdText(lastCreatedAt))
                if usesICloudDrive {
                    LabeledContent("iCloudの最終作成", value: createdText(lastICloudCreatedAt))
                }
                Button {
                    createSnapshot()
                } label: {
                    Label("今すぐバックアップ", systemImage: "arrow.clockwise.icloud")
                }
                .disabled(isWorking)
            } header: {
                Text("自動バックアップ")
            } footer: {
                Text("端末内へ先に保存し、設定時は同じパッケージをiCloud Driveにも複製します。写真が500MB以上では3世代、1GB以上では2世代へ自動調整します。")
            }

            snapshotSection(title: "この端末", snapshots: localSnapshots)

            if usesICloudDrive {
                snapshotSection(title: "iCloud Drive", snapshots: iCloudSnapshots)
                if !iCloudError.isEmpty {
                    Section("iCloud Drive") {
                        Label(iCloudError, systemImage: "exclamationmark.icloud")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.orange)
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

    @ViewBuilder
    private func snapshotSection(title: String, snapshots: [AutomaticBackupSnapshot]) -> some View {
        Section(title) {
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
                                Text(FavorecoDateText.compactDateTime(snapshot.createdAt))
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
    }

    private func createdText(_ date: Date) -> String {
        guard date != .distantPast else { return "未作成" }
        return FavorecoDateText.compactDateTime(date)
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
            localSnapshots = try AutomaticBackupService.snapshots(in: .local)
        } catch {
            localSnapshots = []
            message = "失敗: \(error.localizedDescription)"
        }
        guard usesICloudDrive else {
            iCloudSnapshots = []
            return
        }
        do {
            iCloudSnapshots = try AutomaticBackupService.snapshots(in: .iCloudDrive)
            if iCloudError == AutomaticBackupError.iCloudDriveUnavailable.localizedDescription {
                iCloudError = ""
            }
        } catch {
            iCloudSnapshots = []
            iCloudError = error.localizedDescription
        }
    }
}
