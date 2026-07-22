import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FavoGalleryManagementView: View {
    let profile: FavoriteProfile
    let candidateVisits: [Visit]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: FavoGalleryPhoto?
    @State private var photoPendingDeletion: FavoGalleryPhoto?
    @State private var isShowingRecordPicker = false
    @State private var isShowingPlans = false
    @State private var isProcessing = false
    @State private var message = ""

    private var photos: [FavoGalleryPhoto] {
        (profile.galleryPhotos ?? [])
            .filter(\.hasStoredData)
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private var canAdd: Bool {
        FavoGalleryAccess.canAdd(
            plan: purchaseManager.currentPlan,
            existingCount: photos.count
        )
    }

    private var remainingFreeSlots: Int? {
        guard !purchaseManager.currentPlan.includesLocalFullFeatures else { return nil }
        return max(FavoGalleryAccess.freePhotoLimit - photos.count, 0)
    }

    private var pickerSelectionLimit: Int {
        min(remainingFreeSlots ?? 20, 20)
    }

    private var recordPhotos: [PhotoBlob] {
        candidateVisits
            .flatMap { $0.photos ?? [] }
            .filter { $0.mediaKind == "photo" && $0.hasStoredData && !$0.data.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if canAdd {
                Section {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: pickerSelectionLimit,
                        matching: .images
                    ) {
                        Label("端末の写真から追加", systemImage: "photo.badge.plus")
                    }
                    .disabled(isProcessing)

                    Button {
                        isShowingRecordPicker = true
                    } label: {
                        Label("Favorecoの記録から選ぶ", systemImage: "rectangle.stack.badge.plus")
                    }
                    .disabled(isProcessing || recordPhotos.isEmpty)

                    if isProcessing {
                        HStack {
                            ProgressView()
                            Text("写真を処理中です。")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(additionFooterText)
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("無料版の15枚を使用中", systemImage: "lock.fill")
                            .font(FavorecoTypography.bodyStrong)
                        Text("保存済み写真の閲覧・編集・並べ替え・削除はそのまま使えます。新しく追加するには枚数を減らすか、Pro以上へ変更してください。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Button("プランを見る") { isShowingPlans = true }
                    }
                }
            }

            Section("ギャラリー \(photos.count)枚") {
                if photos.isEmpty {
                    Text("推し専用の写真はまだありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(photos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            FavoGalleryManagementRow(photo: photo)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("削除", role: .destructive) {
                                photoPendingDeletion = photo
                            }
                        }
                    }
                    .onMove { source, destination in
                        movePhotos(from: source, to: destination)
                    }
                }
            }

            if !message.isEmpty {
                Section { Text(message).font(FavorecoTypography.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("推しギャラリー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if photos.count > 1 { EditButton() }
        }
        .task(id: pickerItems) {
            await addSelectedPhotos()
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                FavoGalleryPhotoEditorView(photo: photo, profile: profile)
            }
        }
        .sheet(isPresented: $isShowingRecordPicker) {
            NavigationStack {
                FavoRecordPhotoPickerView(
                    photos: recordPhotos,
                    alreadySelectedIDs: Set(photos.compactMap { $0.sourcePhoto?.id }),
                    maximumSelectionCount: remainingFreeSlots,
                    onAdd: addRecordPhotos
                )
            }
        }
        .sheet(isPresented: $isShowingPlans) {
            NavigationStack {
                BillingPlanSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { isShowingPlans = false }
                        }
                    }
            }
        }
        .confirmationDialog(
            "この写真を削除しますか？",
            isPresented: Binding(
                get: { photoPendingDeletion != nil },
                set: { if !$0 { photoPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("写真を削除", role: .destructive, action: deletePendingPhoto)
            Button("キャンセル", role: .cancel) { photoPendingDeletion = nil }
        } message: {
            Text(deletionMessage)
        }
    }

    @MainActor
    private func addSelectedPhotos() async {
        guard !pickerItems.isEmpty else { return }
        guard canAdd else {
            pickerItems = []
            isShowingPlans = true
            return
        }
        isProcessing = true
        let allowedCount = FavoGalleryAccess.availableAdditionCount(
            plan: purchaseManager.currentPlan,
            existingCount: photos.count,
            requestedCount: pickerItems.count
        )
        let items = Array(pickerItems.prefix(allowedCount))
        pickerItems = []
        var nextSortOrder = (profile.galleryPhotos ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        var addedCount = 0
        var failedCount = 0
        for item in items {
            guard let sourceData = try? await item.loadTransferable(type: Data.self),
                  let processed = await Task.detached(priority: .userInitiated, operation: {
                      FavoProfileImageProcessor.processGallery(sourceData)
                  }).value else {
                failedCount += 1
                continue
            }
            let now = Date()
            modelContext.insert(FavoGalleryPhoto(
                sortOrder: nextSortOrder,
                byteCount: processed.data.count,
                width: processed.width,
                height: processed.height,
                createdAt: now,
                updatedAt: now,
                data: processed.data,
                profile: profile
            ))
            nextSortOrder += 1
            addedCount += 1
        }
        do {
            try modelContext.save()
            message = failedCount == 0
                ? "\(addedCount)枚追加しました。"
                : "\(addedCount)枚追加し、\(failedCount)枚は読み込めませんでした。"
        } catch {
            modelContext.rollback()
            message = "保存できませんでした: \(error.localizedDescription)"
        }
        isProcessing = false
    }

    private func addRecordPhotos(_ selected: [PhotoBlob]) {
        let allowedCount = FavoGalleryAccess.availableAdditionCount(
            plan: purchaseManager.currentPlan,
            existingCount: photos.count,
            requestedCount: selected.count
        )
        guard allowedCount > 0 else {
            isShowingPlans = true
            return
        }
        let existingSourceIDs = Set((profile.galleryPhotos ?? []).compactMap { $0.sourcePhoto?.id })
        let uniquePhotos = selected
            .filter { !existingSourceIDs.contains($0.id) }
            .prefix(allowedCount)
        var nextSortOrder = (profile.galleryPhotos ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let now = Date()
        for sourcePhoto in uniquePhotos {
            modelContext.insert(FavoGalleryPhoto(
                sortOrder: nextSortOrder,
                capturedAt: sourcePhoto.visit?.visitedAt ?? sourcePhoto.createdAt,
                hasCapturedAt: true,
                byteCount: sourcePhoto.byteCount,
                width: sourcePhoto.width,
                height: sourcePhoto.height,
                createdAt: now,
                updatedAt: now,
                profile: profile,
                sourcePhoto: sourcePhoto
            ))
            nextSortOrder += 1
        }
        saveChanges(message: "記録から\(uniquePhotos.count)枚追加しました。")
    }

    private func movePhotos(from source: IndexSet, to destination: Int) {
        var reordered = photos
        reordered.move(fromOffsets: source, toOffset: destination)
        let now = Date()
        for (index, photo) in reordered.enumerated() {
            photo.sortOrder = index
            photo.updatedAt = now
        }
        saveChanges(message: "並び順を更新しました。")
    }

    private func deletePendingPhoto() {
        guard let photo = photoPendingDeletion else { return }
        let removedID = photo.id
        photoPendingDeletion = nil
        modelContext.delete(photo)
        let remaining = photos.filter { $0.id != removedID }
        let now = Date()
        for (index, item) in remaining.enumerated() {
            item.sortOrder = index
            item.updatedAt = now
        }
        saveChanges(message: "写真を1枚削除しました。")
    }

    private func saveChanges(message successMessage: String) {
        do {
            try modelContext.save()
            message = successMessage
        } catch {
            modelContext.rollback()
            message = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private var additionFooterText: String {
        if let remainingFreeSlots {
            return "無料版は推しごとに15枚までです。あと\(remainingFreeSlots)枚追加できます。端末写真は長辺1600px以内へ縮小し、記録写真は元データを参照します。"
        }
        return "Pro以上は枚数制限なしです。一度に20枚まで選べます。端末写真は長辺1600px以内へ縮小し、記録写真は元データを参照します。"
    }

    private var deletionMessage: String {
        if photoPendingDeletion?.sourcePhoto != nil {
            return "推しギャラリーから選択とメモを外します。元の記録写真は削除しません。"
        }
        return "このFAVOプロフィールから写真本体とメモを削除します。"
    }
}

private struct FavoGalleryManagementRow: View {
    let photo: FavoGalleryPhoto

    var body: some View {
        HStack(spacing: 12) {
            FavoGalleryThumbnail(data: photo.resolvedData, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                if photo.isFavorite {
                    Label("お気に入り", systemImage: "star.fill")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
                if photo.hasCapturedAt {
                    Text(FavorecoDateText.fullDate(photo.capturedAt))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Text(photo.memo.isEmpty ? "メモなし" : photo.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(photo.memo.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
private struct FavoGalleryPhotoEditorView: View {
    let photo: FavoGalleryPhoto
    let profile: FavoriteProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var hasCapturedAt: Bool
    @State private var capturedAt: Date
    @State private var memo: String
    @State private var isFavorite: Bool
    @State private var errorMessage = ""

    init(photo: FavoGalleryPhoto, profile: FavoriteProfile) {
        self.photo = photo
        self.profile = profile
        _hasCapturedAt = State(initialValue: photo.hasCapturedAt)
        _capturedAt = State(initialValue: photo.capturedAt)
        _memo = State(initialValue: photo.memo)
        _isFavorite = State(initialValue: photo.isFavorite)
    }

    var body: some View {
        Form {
            Section {
                if let image = UIImage(data: photo.resolvedData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
            }
            Section("写真情報") {
                Toggle("お気に入りにする", isOn: $isFavorite)
                Toggle("日付を設定", isOn: $hasCapturedAt)
                if hasCapturedAt {
                    DatePicker("日付", selection: $capturedAt, displayedComponents: .date)
                }
                TextField("メモ（任意）", text: $memo, axis: .vertical)
                    .lineLimit(3...8)
            }
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("写真を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
        }
    }

    private func save() {
        let now = Date()
        if isFavorite {
            for item in profile.galleryPhotos ?? [] where item.id != photo.id && item.isFavorite {
                item.isFavorite = false
                item.updatedAt = now
            }
        }
        photo.hasCapturedAt = hasCapturedAt
        photo.capturedAt = capturedAt
        photo.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        photo.isFavorite = isFavorite
        photo.updatedAt = now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }
}

enum FavoGalleryAccess {
    nonisolated static let freePhotoLimit = 15

    nonisolated static func canAdd(plan: FavorecoPlan, existingCount: Int) -> Bool {
        plan.includesLocalFullFeatures || existingCount < freePhotoLimit
    }

    nonisolated static func availableAdditionCount(
        plan: FavorecoPlan,
        existingCount: Int,
        requestedCount: Int
    ) -> Int {
        guard requestedCount > 0 else { return 0 }
        if plan.includesLocalFullFeatures { return requestedCount }
        return min(requestedCount, max(freePhotoLimit - existingCount, 0))
    }
}

private struct FavoRecordPhotoPickerView: View {
    let photos: [PhotoBlob]
    let alreadySelectedIDs: Set<UUID>
    let maximumSelectionCount: Int?
    let onAdd: ([PhotoBlob]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs = Set<UUID>()

    private var selectablePhotos: [PhotoBlob] {
        photos.filter { !alreadySelectedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if selectablePhotos.isEmpty {
                ContentUnavailableView(
                    "選べる写真がありません",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("このFAVOに紐づく記録へ写真を追加すると、ここから選べます。")
                )
            } else {
                Section {
                    ForEach(selectablePhotos) { photo in
                        Button {
                            toggle(photo.id)
                        } label: {
                            HStack(spacing: 12) {
                                FavoGalleryThumbnail(data: photo.data, size: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recordTitle(for: photo))
                                        .font(FavorecoTypography.bodyStrong)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(FavorecoDateText.fullDate(photo.visit?.visitedAt ?? photo.createdAt))
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: selectedIDs.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(
                                        selectedIDs.contains(photo.id)
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    if let maximumSelectionCount {
                        Text("このFAVOにはあと\(maximumSelectionCount)枚追加できます。")
                    } else {
                        Text("元の記録写真を参照するため、同じ画像を重複保存しません。")
                    }
                }
            }
        }
        .navigationTitle("記録の写真から選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    onAdd(selectablePhotos.filter { selectedIDs.contains($0.id) })
                    dismiss()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.remove(id) != nil { return }
        if let maximumSelectionCount, selectedIDs.count >= maximumSelectionCount { return }
        selectedIDs.insert(id)
    }

    private func recordTitle(for photo: PhotoBlob) -> String {
        guard let title = photo.visit?.event?.title, !title.isEmpty else { return "名称未設定の記録" }
        return title
    }
}

struct FavoGallerySection: View {
    let profile: FavoriteProfile
    let colorHex: String
    let candidateVisits: [Visit]

    private var photos: [FavoGalleryPhoto] {
        (profile.galleryPhotos ?? [])
            .filter(\.hasStoredData)
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                FavoSectionTitle(title: "推しギャラリー", subtitle: photos.isEmpty ? nil : "\(photos.count)枚")
                Spacer()
                NavigationLink {
                    FavoGalleryManagementView(profile: profile, candidateVisits: candidateVisits)
                } label: {
                    Text(photos.isEmpty ? "追加" : "管理")
                        .font(FavorecoTypography.captionStrong)
                }
            }

            if photos.isEmpty {
                NavigationLink {
                    FavoGalleryManagementView(profile: profile, candidateVisits: candidateVisits)
                } label: {
                    Label("推し専用の写真をまとめる", systemImage: "photo.stack")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(photos.prefix(6)) { photo in
                        NavigationLink { FavoGalleryPhotoDetailView(photo: photo, colorHex: colorHex) } label: {
                            ZStack(alignment: .topTrailing) {
                                FavoGalleryThumbnail(data: photo.resolvedData, size: 84)
                                    .frame(maxWidth: .infinity)
                                if photo.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(Color(hex: colorHex).opacity(0.86), in: Circle())
                                        .padding(5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FavoGalleryPhotoDetailView: View {
    let photo: FavoGalleryPhoto
    let colorHex: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = UIImage(data: photo.resolvedData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                if photo.isFavorite {
                    Label("お気に入り", systemImage: "star.fill")
                        .foregroundStyle(Color(hex: colorHex))
                }
                if photo.hasCapturedAt {
                    Label(FavorecoDateText.fullDate(photo.capturedAt), systemImage: "calendar")
                }
                if !photo.memo.isEmpty {
                    Text(photo.memo).font(FavorecoTypography.body)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("推しギャラリー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FavoGalleryThumbnail: View {
    let data: Data
    let size: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: data) {
            image = await Task.detached(priority: .utility) {
                FavoGalleryImageLoader.thumbnail(data: data, maxPixelSize: Int(size * 2))
            }.value
        }
    }
}

enum FavoGalleryImageLoader {
    nonisolated static func thumbnail(data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
