import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @Query private var categories: [RecordCategory]
    @Query private var events: [ExperienceEvent]
    @Query private var visits: [Visit]
    @Query private var inboxItems: [InboxItem]
    @Query private var photos: [PhotoBlob]
    @Query private var plans: [Plan]
    @Query private var ticketAttempts: [TicketAttempt]
    @Query private var ticketAccounts: [TicketAccount]
    @Query private var socialAccounts: [SocialAccount]
    @Query private var people: [PersonMaster]
    @Query private var places: [PlaceMaster]
    @State private var isConfirmingArchivedDeletion = false
    @State private var maintenanceMessage = ""

    private var archivedItemCount: Int {
        events.filter(\.isArchived).count
            + plans.filter(\.isArchived).count
            + ticketAttempts.filter(\.isArchived).count
            + ticketAccounts.filter(\.isArchived).count
            + socialAccounts.filter(\.isArchived).count
            + people.filter(\.isArchived).count
            + places.filter(\.isArchived).count
    }

    private var totalPhotoBytes: Int64 {
        photos.reduce(Int64(0)) { partialResult, photo in
            partialResult + Int64(max(photo.byteCount, 0))
        }
    }

    private var averagePhotoBytes: Int64 {
        photos.isEmpty ? 0 : totalPhotoBytes / Int64(photos.count)
    }

    private var estimatedTenThousandPhotoBytes: Int64 {
        averagePhotoBytes * 10_000
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Text("\(visits.count)件の記録")
                        .font(FavorecoTypography.heroLead)
                    Text("\(photos.count)枚の写真")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("保存データ") {
                LabeledContent("対象", value: "\(events.count)")
                LabeledContent("気になる対象", value: "\(events.filter { $0.stateKey == "interested" && !$0.isArchived }.count)")
                LabeledContent("訪問/鑑賞記録", value: "\(visits.count)")
                if !inboxItems.isEmpty {
                    LabeledContent("旧クイックデータ（移行待ち）", value: "\(inboxItems.count)")
                }
                LabeledContent("ジャンル", value: "\(categories.count)")
                LabeledContent("写真", value: "\(photos.count)")
                LabeledContent("写真容量", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
                if !photos.isEmpty {
                    LabeledContent("1枚の平均", value: ByteCountFormatter.string(fromByteCount: averagePhotoBytes, countStyle: .file))
                    LabeledContent("1万枚の推定", value: ByteCountFormatter.string(fromByteCount: estimatedTenThousandPhotoBytes, countStyle: .file))
                }
            }

            Section("インポート・エクスポート") {
                NavigationLink {
                    FullBackupView()
                } label: {
                    Label("写真付き完全バックアップ", systemImage: "archivebox")
                }

                NavigationLink {
                    JSONExportView()
                } label: {
                    Label("JSONエクスポート", systemImage: "square.and.arrow.up")
                }

                NavigationLink {
                    CSVExportView()
                } label: {
                    Label("CSVエクスポート", systemImage: "tablecells")
                }

                NavigationLink {
                    JSONImportView()
                } label: {
                    Label("JSONインポート", systemImage: "square.and.arrow.down")
                }

                NavigationLink {
                    CSVImportView()
                } label: {
                    Label("CSVインポート", systemImage: "tray.and.arrow.down")
                }
            }

            Section("バックアップについて") {
                Text("記録はこの端末に保存されています。アプリを削除する前やデータ整理の前に、無料のJSONエクスポートで手動バックアップしてください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("キャッシュ") {
                Button {
                    URLCache.shared.removeAllCachedResponses()
                    maintenanceMessage = "Webキャッシュを削除しました。記録データは変更していません。"
                } label: {
                    Label("Webキャッシュを削除", systemImage: "network.slash")
                }

                Button {
                    ThumbnailLoader.purge()
                    maintenanceMessage = "写真サムネイルのキャッシュを削除しました。写真本体は残っています。"
                } label: {
                    Label("写真キャッシュを削除", systemImage: "photo.badge.arrow.down")
                }

                Text("キャッシュは表示を速くする一時データです。削除しても記録や写真本体は消えません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("データ整理") {
                NavigationLink {
                    ArchivedEventManagementView()
                } label: {
                    LabeledContent("非表示の対象", value: "\(events.filter(\.isArchived).count)")
                }

                Button(role: .destructive) {
                    isConfirmingArchivedDeletion = true
                } label: {
                    Label("アーカイブ済みデータを完全削除", systemImage: "archivebox.fill")
                }
                .disabled(archivedItemCount == 0)

                Text(archivedItemCount == 0
                     ? "完全削除できるアーカイブ済み項目はありません。"
                     : "非表示にした対象・予定・申込・マスターなどが\(archivedItemCount)件あります。関連する記録や写真も削除される場合があります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    FullDataDeletionView()
                } label: {
                    Label("全データ削除", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
            }

            if !maintenanceMessage.isEmpty {
                Section("処理結果") {
                    Text(maintenanceMessage)
                        .font(FavorecoTypography.caption)
                }
            }
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "アーカイブ済みデータを完全削除しますか？",
            isPresented: $isConfirmingArchivedDeletion,
            titleVisibility: .visible
        ) {
            Button("完全削除する", role: .destructive) {
                deleteArchivedData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。非表示の対象に紐づく記録・写真、非表示の予定・申込なども削除されます。先にJSONバックアップを推奨します。")
        }
    }

    private func deleteArchivedData() {
        do {
            let result = try RecordDeletionService.deleteArchivedData(in: modelContext)
            reconcileDeletedCalendarLinks(result.externalCalendarTargets, clearsAllLinks: false)
            maintenanceMessage = "アーカイブ済みデータを\(result.totalCount)件削除しました（対象\(result.eventCount)、記録\(result.visitCount)、予定\(result.planCount)、申込\(result.attemptCount)、マスター\(result.masterCount)、人物リンク\(result.linkCount)）。"
        } catch {
            modelContext.rollback()
            maintenanceMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }

    private func reconcileDeletedCalendarLinks(
        _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget],
        clearsAllLinks: Bool
    ) {
        reconcileExternalCalendarLinks(
            targets,
            removesExternalEvents: purchaseManager.currentPlan.includesSync
                && automaticallyUpdatesExternalCalendar,
            clearsAllLinks: clearsAllLinks
        )
    }
}

private struct ArchivedEventManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]
    @State private var restoreErrorMessage: String?

    private var archivedEvents: [ExperienceEvent] {
        allEvents.filter(\.isArchived)
    }

    var body: some View {
        List {
            if archivedEvents.isEmpty {
                ContentUnavailableView(
                    "非表示の対象はありません",
                    systemImage: "archivebox",
                    description: Text("対象詳細のメニューから非表示にした項目がここへ表示されます。")
                )
            } else {
                Section {
                    ForEach(archivedEvents) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.category?.iconSymbol ?? "rectangle.stack")
                                .foregroundStyle(Color(hex: event.category?.colorHex ?? "#6F8F7A"))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title.isEmpty ? "記録" : event.title)
                                    .font(FavorecoTypography.bodyStrong)
                                HStack(spacing: 8) {
                                    Text(event.category?.name ?? "未分類")
                                    Text("履歴 \((event.visits ?? []).count)件")
                                }
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                restore(event)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(event.title)を再表示")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("再表示") {
                                restore(event)
                            }
                            .tint(.accentColor)
                        }
                    }
                } footer: {
                    Text("再表示すると、ジャンル内の対象一覧と記録一覧へ戻ります。履歴・写真・予定は変更しません。")
                }
            }
        }
        .navigationTitle("非表示の対象")
        .navigationBarTitleDisplayMode(.inline)
        .alert("復元に失敗しました", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { if !$0 { restoreErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { restoreErrorMessage = nil }
        } message: {
            Text(restoreErrorMessage ?? "")
        }
    }

    private func restore(_ event: ExperienceEvent) {
        event.isArchived = false
        event.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            restoreErrorMessage = "「\(event.title.isEmpty ? "記録" : event.title)」を再表示できませんでした。"
        }
    }
}

struct FullDataDeletionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @Query private var categories: [RecordCategory]
    @Query private var events: [ExperienceEvent]
    @Query private var visits: [Visit]
    @Query private var inboxItems: [InboxItem]
    @Query private var photos: [PhotoBlob]
    @Query private var socialAccounts: [SocialAccount]
    @Query private var people: [PersonMaster]
    @Query private var personLinks: [EventPersonLink]
    @Query private var places: [PlaceMaster]
    @Query private var plans: [Plan]
    @Query private var ticketAccounts: [TicketAccount]
    @Query private var ticketAttempts: [TicketAttempt]
    @State private var confirmationText = ""
    @State private var isShowingFinalConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage = ""

    private let requiredText = "削除する"

    private var totalModelCount: Int {
        categories.count + events.count + visits.count + inboxItems.count + photos.count
            + socialAccounts.count + people.count + personLinks.count + places.count
            + plans.count + ticketAccounts.count + ticketAttempts.count
    }

    var body: some View {
        Form {
            Section {
                Label("すべての記録データが失われます", systemImage: "exclamationmark.triangle.fill")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(.red)
                Text("この操作は取り消せません。実行前にデータ管理からJSONバックアップを書き出してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("削除されるもの") {
                LabeledContent("保存モデル", value: "\(totalModelCount)件")
                LabeledContent("対象", value: "\(events.count)件")
                LabeledContent("記録", value: "\(visits.count)件")
                LabeledContent("写真", value: "\(photos.count)件")
                LabeledContent("予定・申込", value: "\(plans.count + ticketAttempts.count)件")
                Text("自作ジャンル、人物、場所、SNS、登録情報、気になる対象も削除されます。通知予約とキャッシュも消去します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("保持されるもの") {
                Text("Home表示、入力補助、通知タイプなどの設定値は保持します。削除後は標準ジャンルを再生成し、初回ジャンル選択へ戻ります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("確認") {
                Text("続けるには「\(requiredText)」と入力してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                TextField(requiredText, text: $confirmationText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(role: .destructive) {
                    isShowingFinalConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("全データ削除へ進む", systemImage: "trash.fill")
                    }
                }
                .disabled(confirmationText != requiredText || isDeleting || totalModelCount == 0)
            }

            if !errorMessage.isEmpty {
                Section("エラー") {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("全データ削除")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "本当に全データを削除しますか？",
            isPresented: $isShowingFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("すべて削除する", role: .destructive) {
                deleteAllData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(totalModelCount)件の保存モデルを削除します。この操作は取り消せません。")
        }
    }

    private func deleteAllData() {
        isDeleting = true
        errorMessage = ""
        Task { @MainActor in
            do {
                let result = try RecordDeletionService.deleteAllData(in: modelContext)
                reconcileExternalCalendarLinks(
                    result.externalCalendarTargets,
                    removesExternalEvents: purchaseManager.currentPlan.includesSync
                        && automaticallyUpdatesExternalCalendar,
                    clearsAllLinks: true
                )
            } catch {
                modelContext.rollback()
                errorMessage = "全データ削除に失敗しました: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }
}

private func reconcileExternalCalendarLinks(
    _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget],
    removesExternalEvents: Bool,
    clearsAllLinks: Bool
) {
    guard removesExternalEvents else {
        if clearsAllLinks {
            ExternalCalendarLinkStore.clearAll()
        } else {
            for target in targets {
                ExternalCalendarLinkStore.clear(planID: target.planID)
            }
        }
        return
    }

    Task { @MainActor in
        for target in targets {
            _ = try? await ExternalCalendarSyncService.remove(
                identifier: target.eventIdentifier,
                planID: target.planID
            )
        }
        if clearsAllLinks {
            ExternalCalendarLinkStore.clearAll()
        }
    }
}

struct CSVExportView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @State private var isExporterPresented = false
    @State private var exportDocument = CSVExportDocument()
    @State private var exportErrorMessage = ""

    private var csvText: String {
        CSVExportService.makeVisitsCSV(visits: visits)
    }

    private var fileName: String {
        "favoreco-visits-\(Date().formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("記録CSV")
                        .font(FavorecoTypography.sectionTitle)
                    Text("保存済みの訪問/鑑賞記録を、表計算アプリで開けるCSVとして書き出します。写真データは含みません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("対象データ") {
                LabeledContent("記録数", value: "\(visits.count)")
                LabeledContent("形式", value: "CSV / UTF-8")
                LabeledContent("写真", value: "含めない")
            }

            Section("書き出し") {
                Button {
                    exportDocument = CSVExportDocument(text: csvText)
                    exportErrorMessage = ""
                    isExporterPresented = true
                } label: {
                    Label("CSVファイルを書き出す", systemImage: "square.and.arrow.up")
                }
                .disabled(visits.isEmpty)

                if visits.isEmpty {
                    Text("書き出せる記録がまだありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !exportErrorMessage.isEmpty {
                    Text(exportErrorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("列") {
                Text("date, category, title, series, venue, rating, status, seat, amount, official_url, tags, companions, note などを書き出します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("CSVエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: fileName
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

struct JSONExportView: View {
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

    @State private var isExporterPresented = false
    @State private var exportDocument = JSONBackupDocument()
    @State private var exportErrorMessage = ""

    private var fileName: String {
        "favoreco-backup-\(Date().formatted(.iso8601.year().month().day()))"
    }

    private var totalRecordCount: Int {
        categories.count + events.count + visits.count + inboxItems.count + socialAccounts.count + people.count + companions.count + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count + favoPins.count + personLinks.count + places.count + plans.count + ticketAccounts.count + ticketAttempts.count
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSONバックアップ")
                        .font(FavorecoTypography.sectionTitle)
                    Text("アプリに戻せる形式の手動バックアップです。人物プロフィール写真とFAVO専用ギャラリーは含みますが、記録へ添付した写真・動画本体は含めず、記録本体と紐付け情報を書き出します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("対象データ") {
                LabeledContent("ジャンル", value: "\(categories.count)")
                LabeledContent("対象", value: "\(events.count)")
                LabeledContent("訪問/鑑賞記録", value: "\(visits.count)")
                LabeledContent("人物・団体", value: "\(people.count)")
                LabeledContent("同行者", value: "\(companions.count)")
                LabeledContent("FAVO", value: "\(favoriteProfiles.filter(\.isFavorite).count)")
                LabeledContent("FAVO記念日", value: "\(favoAnniversaries.count)")
                LabeledContent("MY FAVO固定", value: "\(favoPins.count)")
                LabeledContent("人物リンク", value: "\(personLinks.count)")
                LabeledContent("場所", value: "\(places.count)")
                LabeledContent("予定", value: "\(plans.count)")
                LabeledContent("登録情報・名義", value: "\(ticketAccounts.count)")
                LabeledContent("チケット申込", value: "\(ticketAttempts.count)")
                LabeledContent("気になる対象", value: "\(events.filter { $0.stateKey == "interested" && !$0.isArchived }.count)")
                if !inboxItems.isEmpty {
                    LabeledContent("旧クイックデータ", value: "\(inboxItems.count)")
                }
                LabeledContent("SNS", value: "\(socialAccounts.count)")
                LabeledContent("写真メタデータ", value: "\(photos.count)")
            }

            Section("書き出し") {
                Button {
                    do {
                        let text = try JSONBackupExportService.makeBackupJSON(
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
                            ticketAttempts: ticketAttempts
                        )
                        exportDocument = JSONBackupDocument(text: text)
                        exportErrorMessage = ""
                        isExporterPresented = true
                    } catch {
                        exportErrorMessage = error.localizedDescription
                    }
                } label: {
                    Label("JSONファイルを書き出す", systemImage: "square.and.arrow.up")
                }
                .disabled(totalRecordCount == 0)

                if totalRecordCount == 0 {
                    Text("書き出せるデータがまだありません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !exportErrorMessage.isEmpty {
                    Text(exportErrorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("含まれないもの") {
                Text("JSON単体には写真/動画の実データ、iCloud同期状態、通知予約、外部カレンダー側のイベントを含めません。写真本体を残す場合は「完全バックアップ」を使用してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("JSONエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: fileName
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

struct SyncBackupSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \PhotoBlob.createdAt, order: .reverse) private var photos: [PhotoBlob]
    @AppStorage(AppStorageKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(AppStorageKeys.iCloudSyncActiveAtLaunch) private var iCloudSyncActiveAtLaunch = false
    @AppStorage(AppStorageKeys.iCloudSyncStartupError) private var iCloudSyncStartupError = ""
    @AppStorage(AppStorageKeys.automaticBackupEnabled) private var automaticBackupEnabled = false
    @AppStorage(AppStorageKeys.automaticBackupUsesICloudDrive) private var automaticBackupUsesICloudDrive = false
    @AppStorage(AppStorageKeys.automaticBackupICloudError) private var automaticBackupICloudError = ""
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @State private var diagnostic: CloudSyncDiagnostic?
    @State private var isRefreshingDiagnostic = false

    private var totalPhotoBytes: Int64 {
        photos.reduce(Int64(0)) { $0 + Int64(max($1.byteCount, 0)) }
    }

    var body: some View {
        Form {
            Section {
                Toggle("iCloud同期", isOn: $iCloudSyncEnabled)
                    .disabled(!canUseSyncFeatures)
                LabeledContent("現在の保存先", value: iCloudSyncActiveAtLaunch ? "端末 + iCloud" : "この端末")
                LabeledContent("iCloudアカウント", value: diagnostic?.accountStatusText ?? "未確認")

                if iCloudSyncEnabled != iCloudSyncActiveAtLaunch {
                    Label("変更はアプリを終了し、次に起動した時から反映されます。", systemImage: "arrow.clockwise.circle")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !iCloudSyncStartupError.isEmpty {
                    Label("同期を開始できなかったため、この端末だけで安全に起動しました。", systemImage: "exclamationmark.icloud")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.orange)
                    Text(iCloudSyncStartupError)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await refreshDiagnostic() }
                } label: {
                    Label(isRefreshingDiagnostic ? "確認中" : "同期環境を確認", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshingDiagnostic)
                LabeledContent("写真の同期", value: iCloudSyncActiveAtLaunch ? "含む" : "OFF")
                LabeledContent("写真データ", value: ByteCountFormatter.string(fromByteCount: totalPhotoBytes, countStyle: .file))
            } header: {
                Text("同期")
            } footer: {
                Text("ONでは同じApple Accountの端末間で記録と写真を自動同期します。まず端末内へ保存されるため、通信やiCloud容量の問題で記録が失われることはありません。初回はWi-Fi環境を推奨します。")
            }

            Section("バックアップ") {
#if DEBUG
                Toggle("自動バックアップ", isOn: $automaticBackupEnabled)
                Toggle("iCloud Driveにも保存", isOn: $automaticBackupUsesICloudDrive)
                    .disabled(!automaticBackupEnabled)
#else
                Toggle("自動バックアップ", isOn: $automaticBackupEnabled)
                    .disabled(!canUseSyncFeatures)
                Toggle("iCloud Driveにも保存", isOn: $automaticBackupUsesICloudDrive)
                    .disabled(!canUseSyncFeatures || !automaticBackupEnabled)
#endif
                LabeledContent(
                    "バックアップ先",
                    value: automaticBackupUsesICloudDrive ? "端末 + iCloud Drive" : "この端末"
                )
                if !automaticBackupICloudError.isEmpty {
                    Label(automaticBackupICloudError, systemImage: "exclamationmark.icloud")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.orange)
                }
                NavigationLink {
                    AutomaticBackupView()
                } label: {
                    Label("自動バックアップの管理", systemImage: "clock.arrow.2.circlepath")
                }
                NavigationLink {
                    FullBackupView()
                } label: {
                    Label("完全バックアップ・復元", systemImage: "archivebox")
                }
                Text("24時間に1回、起動時に写真付きバックアップを作成します。写真容量が増えると保持世代数を自動で減らし、作成前に端末の空き容量を確認します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("外部カレンダー") {
                Toggle("favorecoの予定変更を自動反映", isOn: $automaticallyUpdatesExternalCalendar)
                    .disabled(!purchaseManager.currentPlan.includesSync)
                Text("先に予定詳細の「カレンダーに追加」からApple/Googleなどの追加先を選びます。以後、favorecoで予定を編集・削除した時だけ同じ外部イベントへ片方向で反映します。外部側の編集はfavorecoへ戻しません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                if !purchaseManager.currentPlan.includesSync {
                    Label("自動更新はPremium限定", systemImage: "lock.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("同期トラブル診断") {
                LabeledContent("iCloud Drive", value: diagnostic?.hasUbiquityContainer == true ? "利用可能" : "未確認 / 利用不可")
                LabeledContent("起動時の同期接続", value: iCloudSyncActiveAtLaunch ? "接続済み" : "未接続")
                if let errorMessage = diagnostic?.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("同期・バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshDiagnostic()
        }
    }

    @MainActor
    private func refreshDiagnostic() async {
        guard !isRefreshingDiagnostic else { return }
        isRefreshingDiagnostic = true
        diagnostic = await CloudSyncService.diagnostic()
        isRefreshingDiagnostic = false
    }

    private var canUseSyncFeatures: Bool {
#if DEBUG
        true
#else
        purchaseManager.currentPlan.includesSync
#endif
    }
}
