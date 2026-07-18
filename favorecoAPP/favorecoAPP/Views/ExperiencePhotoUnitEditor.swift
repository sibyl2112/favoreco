//
//  ExperiencePhotoUnitEditor.swift
//  favorecoAPP
//

import SwiftUI
import PhotosUI
import UIKit

struct PhotoUnitEditor: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.photoCompressionQuality) private var compressionQuality = 0.85
    @AppStorage(AppStorageKeys.photoAddStartMode) private var photoAddStartMode = "camera"
    let existingPhotos: [PhotoBlob]
    @Binding var deletedPhotoIDs: Set<UUID>
    @Binding var pendingPhotos: [PendingPhoto]
    @Binding var selectedItems: [PhotosPickerItem]
    let category: RecordCategory?
    @Binding var aspectRatioKey: String
    @Binding var coverPhotoPath: String
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var importCompletedCount = 0
    @State private var importTotalCount = 0

    private let largePhotoNoticeThreshold = 50

    private var isImportingPhotos: Bool {
        importTotalCount > 0
    }

    private var maxPhotoCount: Int? {
        purchaseManager.currentPlan.maximumPhotosPerRecord
    }

    private var selectedAspectRatio: EyecatchAspectRatio {
        EyecatchAspectRatio.option(for: aspectRatioKey, category: category)
    }

    private var activeExistingPhotos: [PhotoBlob] {
        existingPhotos.filter { !deletedPhotoIDs.contains($0.id) }
    }

    private var currentPhotoCount: Int {
        activeExistingPhotos.count + pendingPhotos.count
    }

    private var currentPhotoBytes: Int64 {
        let existingBytes = activeExistingPhotos.reduce(Int64(0)) {
            $0 + Int64(max($1.byteCount, 0))
        }
        let pendingBytes = pendingPhotos.reduce(Int64(0)) {
            $0 + Int64($1.data.count)
        }
        return existingBytes + pendingBytes
    }

    private var showsLargePhotoNotice: Bool {
        currentPhotoCount >= largePhotoNoticeThreshold
    }

    private var remainingPhotoSlots: Int? {
        maxPhotoCount.map { max(0, $0 - currentPhotoCount) }
    }

    private var canAddPhotos: Bool {
        remainingPhotoSlots != 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("写真")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text(photoCountLabel)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if category?.templateKey == "book" {
                bookFormatPicker
            }

            if currentPhotoCount == 0 {
                Text("思い出写真、半券写真、表紙画像などを追加できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                photoGrid
            }

            if isImportingPhotos {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(
                        value: Double(importCompletedCount),
                        total: Double(max(importTotalCount, 1))
                    )
                    Text("写真を取り込み中 \(importCompletedCount)/\(importTotalCount)")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if maxPhotoCount == nil, showsLargePhotoNotice {
                Label {
                    Text("写真はこのまま追加できます。枚数が多い記録は、取り込み・完全バックアップ・初回同期に時間がかかる場合があります（現在約\(formattedPhotoBytes)）。")
                } icon: {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if isImportingPhotos {
                EmptyView()
            } else if canAddPhotos {
                photoAddControls
            } else {
                Label(photoLimitMessage, systemImage: "checkmark.circle")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if aspectRatioKey.isEmpty {
                aspectRatioKey = category?.templateKey == "book"
                    ? EyecatchAspectRatio.hardcoverBook.key
                    : EyecatchAspectRatio.recommended(for: category).key
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePicker(
                onCapture: { image in
                    appendCapturedPhoto(image)
                    isShowingCamera = false
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .alert("カメラを使用できません", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラを起動できません。写真ライブラリから追加してください。")
        }
    }

    private var photoLimitMessage: String {
        guard let maxPhotoCount else { return "" }
        if currentPhotoCount > maxPhotoCount {
            return "既存写真は保持します。現在のプランでは新しい写真を追加できません"
        }
        return "写真上限の\(maxPhotoCount)枚に達しています"
    }

    private var photoCountLabel: String {
        guard let maxPhotoCount else { return "\(currentPhotoCount)枚・上限なし" }
        return "\(currentPhotoCount)/\(maxPhotoCount)"
    }

    private var formattedPhotoBytes: String {
        ByteCountFormatter.string(fromByteCount: currentPhotoBytes, countStyle: .file)
    }

    private var bookFormatOptions: [EyecatchAspectRatio] {
        if aspectRatioKey == EyecatchAspectRatio.bookCover.key {
            return [EyecatchAspectRatio.bookCover] + EyecatchAspectRatio.selectableBookFormats
        }
        return EyecatchAspectRatio.selectableBookFormats
    }

    private var bookFormatPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("本の種類", selection: $aspectRatioKey) {
                ForEach(bookFormatOptions) { format in
                    Text(format.name).tag(format.key)
                }
            }
            .pickerStyle(.menu)

            Text(selectedAspectRatio.note)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var photoAddControls: some View {
        if photoAddStartMode == "library" {
            libraryPicker(label: "写真ライブラリから追加", prominent: true)
            cameraButton(label: "カメラで撮影", prominent: false)
        } else {
            cameraButton(label: "カメラで撮影", prominent: true)
            libraryPicker(label: "写真ライブラリから選ぶ", prominent: false)
        }
    }

    @ViewBuilder
    private func libraryPicker(label: String, prominent: Bool) -> some View {
        let picker = PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: remainingPhotoSlots,
            matching: .images
        ) {
            Label(label, systemImage: "photo.on.rectangle.angled")
                .frame(maxWidth: .infinity)
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await appendPhotos(from: newItems)
                selectedItems.removeAll()
            }
        }
        if prominent {
            picker.buttonStyle(.borderedProminent)
        } else {
            picker.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func cameraButton(label: String, prominent: Bool) -> some View {
        let button = Button {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                isShowingCameraUnavailableAlert = true
                return
            }
            isShowingCamera = true
        } label: {
            Label(label, systemImage: "camera")
                .frame(maxWidth: .infinity)
        }
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(activeExistingPhotos) { photo in
                SavedPhotoThumbnail(
                    photo: photo,
                    title: "保存済み",
                    aspectRatio: selectedAspectRatio.value,
                    fillsFrame: EyecatchAspectRatio.usesEyecatchFill(for: category),
                    isCover: coverPhotoPath == photo.relativePath,
                    onSetCover: {
                        coverPhotoPath = photo.relativePath
                    },
                    onDelete: {
                        deletedPhotoIDs.insert(photo.id)
                        selectFallbackCover(excluding: photo.relativePath)
                    }
                )
            }

            ForEach(pendingPhotos) { photo in
                PendingPhotoThumbnail(
                    photo: photo,
                    title: "追加予定",
                    aspectRatio: selectedAspectRatio.value,
                    fillsFrame: EyecatchAspectRatio.usesEyecatchFill(for: category),
                    isCover: coverPhotoPath == photo.relativePath,
                    onSetCover: {
                        coverPhotoPath = photo.relativePath
                    },
                    onDelete: {
                        pendingPhotos.removeAll { $0.id == photo.id }
                        selectFallbackCover(excluding: photo.relativePath)
                    }
                )
            }
        }
    }

    @MainActor
    private func appendPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        let importItems: [PhotosPickerItem]
        if let remainingPhotoSlots {
            importItems = Array(items.prefix(remainingPhotoSlots))
        } else {
            importItems = items
        }
        importCompletedCount = 0
        importTotalCount = importItems.count
        defer {
            importCompletedCount = 0
            importTotalCount = 0
        }

        for item in importItems {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                importCompletedCount += 1
                continue
            }
            let filename = item.itemIdentifier ?? "photo.jpg"
            let quality = compressionQuality
            guard let pendingPhoto = await Task.detached(priority: .userInitiated, operation: {
                PendingPhoto.make(from: data, filename: filename, compressionQuality: quality)
            }).value else {
                importCompletedCount += 1
                continue
            }
            pendingPhotos.append(pendingPhoto)
            if coverPhotoPath.isEmpty {
                coverPhotoPath = pendingPhoto.relativePath
            }
            importCompletedCount += 1
        }
    }

    private func selectFallbackCover(excluding path: String) {
        guard coverPhotoPath == path else { return }
        coverPhotoPath = activeExistingPhotos
            .first(where: { $0.relativePath != path })?
            .relativePath
            ?? pendingPhotos.first(where: { $0.relativePath != path })?.relativePath
            ?? ""
    }

    private func appendCapturedPhoto(_ image: UIImage) {
        guard canAddPhotos, let data = image.jpegData(compressionQuality: 1) else { return }
        let filename = "camera-\(UUID().uuidString).jpg"
        let quality = compressionQuality
        Task {
            guard let pendingPhoto = await Task.detached(priority: .userInitiated, operation: {
                PendingPhoto.make(from: data, filename: filename, compressionQuality: quality)
            }).value, canAddPhotos else { return }
            pendingPhotos.append(pendingPhoto)
            if coverPhotoPath.isEmpty {
                coverPhotoPath = pendingPhoto.relativePath
            }
        }
    }
}
