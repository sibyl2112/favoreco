import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FullBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \BookShelf.sortOrder) private var bookShelves: [BookShelf]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.updatedAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \PhotoBlob.createdAt, order: .reverse) private var photos: [PhotoBlob]
    @Query(sort: \SocialAccount.sortOrder) private var socialAccounts: [SocialAccount]
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \CompanionMaster.name) private var companions: [CompanionMaster]
    @Query(sort: \FavoriteProfile.sortOrder) private var favoriteProfiles: [FavoriteProfile]
    @Query(sort: \FavoGalleryPhoto.sortOrder) private var favoGalleryPhotos: [FavoGalleryPhoto]
    @Query(sort: \FavoAnniversary.sortOrder) private var favoAnniversaries: [FavoAnniversary]
    @Query(sort: \FavoPin.sortOrder) private var favoPins: [FavoPin]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @Query(sort: \Plan.startsAt, order: .reverse) private var plans: [Plan]
    @Query(sort: \TicketAccount.serviceName) private var ticketAccounts: [TicketAccount]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \MovieBestEntry.updatedAt, order: .reverse) private var movieBestEntries: [MovieBestEntry]

    @State private var exportURL: URL?
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var importedPackageURL: URL?
    @State private var importPreview: FullBackupPreview?
    @State private var restoreResult: FullBackupRestoreResult?
    @State private var isConfirmingRestore = false
    @State private var isWorking = false
    @State private var workingMessage = ""
    @State private var message = ""

    private var totalModelCount: Int {
        categories.count + events.count + bookShelves.count + visits.count + inboxItems.count + socialAccounts.count
            + people.count + companions.count + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count + favoPins.count + personLinks.count + places.count + plans.count + ticketAccounts.count + ticketAttempts.count + movieBestEntries.count
    }

    private var totalPhotoBytes: Int64 {
        photos.reduce(0) { $0 + Int64($1.byteCount) }
            + favoGalleryPhotos.reduce(0) { $0 + Int64($1.byteCount) }
    }

    var body: some View {
        Form {
            FavorecoSettingsCard {
                Text("記録、予定、チケット、マスター、写真本体を1つのFavorecoバックアップへ保存します。")
                    .font(FavorecoTypography.body)
                LabeledContent("保存モデル", value: "\(totalModelCount)件")
                LabeledContent("写真", value: "\(photos.count + favoGalleryPhotos.count)枚")
                LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
            }

            FavorecoSettingsSection("書き出し") {
                Button {
                    createBackup()
                } label: {
                    FavorecoIconLabel("写真付きバックアップを作成", systemImage: "archivebox")
                }
                .disabled(isWorking || totalModelCount == 0)
            }

            FavorecoSettingsSection("復元") {
                Button {
                    isShowingImporter = true
                } label: {
                    Label("バックアップを選択", systemImage: "clock.arrow.circlepath")
                }
                .disabled(isWorking)

                if let importPreview {
                    LabeledContent("記録データ", value: "\(importPreview.jsonPreview.totalModelCount)件")
                    LabeledContent("復元できる写真", value: "\(importPreview.availablePhotoCount)枚")
                    LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: importPreview.totalPhotoBytes, countStyle: .file))
                    Button("既存データへ追加・更新") {
                        isConfirmingRestore = true
                    }
                    .disabled(isWorking)
                }
            }

            if isWorking {
                FavorecoSettingsCard {
                    HStack {
                        ProgressView()
                        Text(workingMessage.isEmpty ? "処理中です…" : workingMessage)
                    }
                }
            }

            if !message.isEmpty {
                FavorecoSettingsSection("結果") {
                    Text(message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(message.contains("失敗") ? .red : .secondary)
                }
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("完全バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExporter) {
            if let exportURL {
                FullBackupExportPicker(url: exportURL)
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.favorecoBackup, .package],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .confirmationDialog("バックアップを復元しますか？", isPresented: $isConfirmingRestore, titleVisibility: .visible) {
            Button("追加・更新する") { restoreBackup() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("同じUUIDは更新し、存在しないデータと写真を追加します。現在のデータは一括削除しません。")
        }
        .onDisappear {
            removeTemporaryPackage(exportURL)
            removeTemporaryPackage(importedPackageURL)
        }
    }

    private func createBackup() {
        guard !isWorking else { return }
        isWorking = true
        workingMessage = "写真付きバックアップを作成中…"
        message = ""
        let previousExportURL = exportURL
        exportURL = nil
        let modelContainer = modelContext.container

        Task { @MainActor in
            await Task.yield()
            defer {
                isWorking = false
                workingMessage = ""
            }
            do {
                if let previousExportURL {
                    await Task.detached(priority: .utility) {
                        AutomaticBackupService.removeTemporaryPackageIfPresent(at: previousExportURL)
                    }.value
                }
                let worker = AutomaticBackupModelActor(modelContainer: modelContainer)
                exportURL = try await worker.makeTemporaryExportPackage()
                isShowingExporter = true
                message = "バックアップを作成しました。保存先を選んでください。"
            } catch {
                exportURL = nil
                message = "バックアップの作成に失敗しました。もう一度お試しください。\n\(error.localizedDescription)"
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            guard !isWorking else { return }
            isWorking = true
            workingMessage = "バックアップを確認中…"
            message = ""
            let previousPackageURL = importedPackageURL
            importedPackageURL = nil
            importPreview = nil
            restoreResult = nil

            Task { @MainActor in
                await Task.yield()
                defer {
                    isWorking = false
                    workingMessage = ""
                }
                do {
                    let inspection = try await Task.detached(priority: .userInitiated) {
                        if let previousPackageURL {
                            AutomaticBackupService.removeTemporaryPackageIfPresent(at: previousPackageURL)
                        }
                        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
                        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
                        let localURL = try FullBackupService.copyPackageToTemporaryLocation(from: sourceURL)
                        do {
                            return (localURL, try FullBackupService.inspect(packageURL: localURL))
                        } catch {
                            AutomaticBackupService.removeTemporaryPackageIfPresent(at: localURL)
                            throw error
                        }
                    }.value
                    importedPackageURL = inspection.0
                    importPreview = inspection.1
                    message = "バックアップを確認しました。内容を確認してから復元してください。"
                } catch {
                    importedPackageURL = nil
                    importPreview = nil
                    message = "バックアップの確認に失敗しました。ファイルを選び直してください。\n\(error.localizedDescription)"
                }
            }
        } catch {
            importedPackageURL = nil
            importPreview = nil
            message = "バックアップを選択できませんでした。\n\(error.localizedDescription)"
        }
    }

    private func restoreBackup() {
        guard let importedPackageURL, !isWorking else { return }
        isWorking = true
        workingMessage = "バックアップを復元中…"
        restoreResult = nil
        message = ""

        Task { @MainActor in
            await Task.yield()
            defer {
                isWorking = false
                workingMessage = ""
            }
            do {
                let result = try await FullBackupService.restoreResponsively(
                    packageURL: importedPackageURL,
                    in: modelContext
                )
                restoreResult = result
                message = "復元が完了しました。データ\(result.modelResult.totalRestoredCount)件、写真追加\(result.insertedPhotoCount)枚、写真更新\(result.updatedPhotoCount)枚、写真不足\(result.missingPhotoCount)枚"
            } catch {
                modelContext.rollback()
                restoreResult = nil
                message = "復元に失敗しました。データは変更されていません。もう一度お試しください。\n\(error.localizedDescription)"
            }
        }
    }

    private func removeTemporaryPackage(_ url: URL?) {
        guard let url else { return }
        Task.detached(priority: .utility) {
            AutomaticBackupService.removeTemporaryPackageIfPresent(at: url)
        }
    }
}

private struct FullBackupExportPicker: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
