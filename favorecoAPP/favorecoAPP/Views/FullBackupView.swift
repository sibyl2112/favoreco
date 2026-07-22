import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FullBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
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

    @State private var exportURL: URL?
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var importedPackageURL: URL?
    @State private var importPreview: FullBackupPreview?
    @State private var restoreResult: FullBackupRestoreResult?
    @State private var isConfirmingRestore = false
    @State private var isWorking = false
    @State private var message = ""

    private var totalModelCount: Int {
        categories.count + events.count + visits.count + inboxItems.count + socialAccounts.count
            + people.count + companions.count + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count + favoPins.count + personLinks.count + places.count + plans.count + ticketAccounts.count + ticketAttempts.count
    }

    private var totalPhotoBytes: Int64 {
        photos.reduce(0) { $0 + Int64($1.byteCount) }
            + favoGalleryPhotos.reduce(0) { $0 + Int64($1.byteCount) }
    }

    var body: some View {
        Form {
            Section {
                Text("記録、予定、チケット、マスター、写真本体を1つのFavorecoバックアップへ保存します。")
                    .font(FavorecoTypography.body)
                LabeledContent("保存モデル", value: "\(totalModelCount)件")
                LabeledContent("写真", value: "\(photos.count + favoGalleryPhotos.count)枚")
                LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
            }

            Section("書き出し") {
                Button {
                    createBackup()
                } label: {
                    Label("写真付きバックアップを作成", systemImage: "archivebox")
                }
                .disabled(isWorking || totalModelCount == 0)
            }

            Section("復元") {
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
                }
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("処理中です。画面を閉じずにお待ちください。")
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
        isWorking = true
        message = ""
        do {
            removeTemporaryPackage(exportURL)
            let json = try JSONBackupExportService.makeBackupJSON(
                categories: categories,
                events: events,
                visits: visits,
                inboxItems: inboxItems,
                photos: photos,
                socialAccounts: socialAccounts,
                people: people,
                companions: companions,
                favoriteProfiles: favoriteProfiles,
                favoGalleryPhotos: favoGalleryPhotos,
                favoAnniversaries: favoAnniversaries,
                favoPins: favoPins,
                personLinks: personLinks,
                places: places,
                plans: plans,
                ticketAccounts: ticketAccounts,
                ticketAttempts: ticketAttempts,
                includesPhotoBinaryData: false,
                isFullBackupManifest: true
            )
            exportURL = try FullBackupService.makePackage(json: json, photos: photos)
            isShowingExporter = true
            message = "バックアップを作成しました。保存先を選んでください。"
        } catch {
            message = "失敗: \(error.localizedDescription)"
        }
        isWorking = false
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        var copiedPackageURL: URL?
        do {
            guard let sourceURL = try result.get().first else { return }
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            removeTemporaryPackage(importedPackageURL)
            let localURL = try FullBackupService.copyPackageToTemporaryLocation(from: sourceURL)
            copiedPackageURL = localURL
            importPreview = try FullBackupService.inspect(packageURL: localURL)
            importedPackageURL = localURL
            restoreResult = nil
            message = "バックアップを確認しました。"
        } catch {
            removeTemporaryPackage(copiedPackageURL)
            importedPackageURL = nil
            importPreview = nil
            message = "失敗: \(error.localizedDescription)"
        }
    }

    private func restoreBackup() {
        guard let importedPackageURL else { return }
        isWorking = true
        do {
            let result = try FullBackupService.restore(packageURL: importedPackageURL, in: modelContext)
            restoreResult = result
            message = "復元完了: データ\(result.modelResult.totalRestoredCount)件、写真追加\(result.insertedPhotoCount)枚、写真更新\(result.updatedPhotoCount)枚、写真不足\(result.missingPhotoCount)枚"
        } catch {
            modelContext.rollback()
            restoreResult = nil
            message = "失敗: \(error.localizedDescription)"
        }
        isWorking = false
    }

    private func removeTemporaryPackage(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

private struct FullBackupExportPicker: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
