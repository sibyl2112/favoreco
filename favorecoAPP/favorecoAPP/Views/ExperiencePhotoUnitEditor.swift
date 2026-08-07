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
    @AppStorage(AppStorageKeys.photoAddStartMode) private var photoAddStartMode = "library"
    let existingPhotos: [PhotoBlob]
    @Binding var deletedPhotoIDs: Set<UUID>
    @Binding var existingPhotoMetadata: [UUID: PhotoMetadataDraft]
    @Binding var pendingPhotos: [PendingPhoto]
    @Binding var selectedItems: [PhotosPickerItem]
    let category: RecordCategory?
    @Binding var aspectRatioKey: String
    @Binding var coverPhotoPath: String
    @Binding var heroBackgroundPath: String
    @Binding var heroBackgroundPresetKey: String
    var showsBookFormatPicker = true
    var showsHeroBackgroundPicker = true
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var importCompletedCount = 0
    @State private var importTotalCount = 0
    @State private var editingTarget: PhotoEditorTarget?
    @State private var isShowingAllPhotos = false
    @State private var editingTargetAfterGallery: PhotoEditorTarget?
    @State private var isShowingCoverPicker = false
    @State private var isTheaterPhotoManagerExpanded = false

    private let largePhotoNoticeThreshold = 50
    private let compactPhotoLimit = 8
    private let compactColumns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 4
    )

    private var isImportingPhotos: Bool {
        importTotalCount > 0
    }

    private var maxPhotoCount: Int? {
        purchaseManager.currentPlan.maximumPhotosPerRecord
    }

    private var selectedAspectRatio: EyecatchAspectRatio {
        EyecatchAspectRatio.option(for: aspectRatioKey, category: category)
    }

    private var heroBackgroundPresets: [HeroBackgroundPreset] {
        HeroBackgroundPreset.presets(for: category?.templateKey)
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

    private var isTheater: Bool {
        category?.templateKey == "theater"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isTheater {
                theaterEyecatchPicker
                theaterPhotoManager
            } else {
                standardPhotoEditorContent
            }
        }
        .onAppear {
            initializeExistingMetadataDrafts()
            if aspectRatioKey.isEmpty {
                aspectRatioKey = category?.templateKey == "book"
                    ? EyecatchAspectRatio.hardcoverBook.key
                    : EyecatchAspectRatio.recommended(for: category).key
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await appendPhotos(from: newItems)
                selectedItems.removeAll()
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
        .sheet(item: $editingTarget) { target in
            NavigationStack {
                metadataEditor(for: target)
                    .navigationTitle("写真の情報")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { editingTarget = nil }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(
            isPresented: $isShowingAllPhotos,
            onDismiss: {
                if let target = editingTargetAfterGallery {
                    editingTargetAfterGallery = nil
                    editingTarget = target
                }
            }
        ) {
            NavigationStack {
                ScrollView {
                    allPhotoGrid
                        .padding(16)
                }
                .navigationTitle("写真 \(currentPhotoCount)枚")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") {
                            isShowingAllPhotos = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCoverPicker) {
            NavigationStack {
                ScrollView {
                    coverSelectionGrid
                        .padding(16)
                }
                .navigationTitle("アイキャッチを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            isShowingCoverPicker = false
                        }
                    }
                }
            }
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

    @ViewBuilder
    private var standardPhotoEditorContent: some View {
        HStack {
            Text("写真")
                .font(FavorecoTypography.bodyStrong)
            Spacer()
            Text(photoCountLabel)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }

        if category?.templateKey == "book", showsBookFormatPicker {
            bookFormatPicker
        }

        if showsHeroBackgroundPicker, !heroBackgroundPresets.isEmpty {
            heroBackgroundPicker
        } else if showsHeroBackgroundPicker, !heroBackgroundPath.isEmpty {
            Button {
                heroBackgroundPath = ""
            } label: {
                FavorecoIconLabel("トップ背景をジャンル既定に戻す", systemImage: "rectangle.landscape")
            }
            .buttonStyle(.bordered)
        }

        photoLibraryContent
    }

    private var theaterPhotoManager: some View {
        DisclosureGroup(isExpanded: $isTheaterPhotoManagerExpanded) {
            photoLibraryContent
                .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                FavorecoIconLabel(
                    currentPhotoCount == 0 ? "写真を追加" : "写真一覧・追加",
                    systemImage: "photo.on.rectangle.angled",
                    iconSize: 14
                )
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Text(photoCountLabel)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var photoLibraryContent: some View {
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
                FavorecoIcon(systemName: "externaldrive.badge.exclamationmark", size: 17)
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
            FavorecoIconLabel(photoLimitMessage, systemImage: "checkmark.circle")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var coverEligiblePhotoItems: [PhotoGridItem] {
        photoItems.filter { item in
            switch item.kind {
            case .existing:
                guard let photo = activeExistingPhotos.first(where: { $0.id == item.id }) else {
                    return false
                }
                return existingMetadata(for: photo).purpose == .memory
            case .pending:
                return pendingPhotos.first(where: { $0.id == item.id })?.metadata.purpose == .memory
            }
        }
    }

    private var activeCoverPaths: Set<String> {
        Set(coverEligiblePhotoItems.compactMap { item in
            switch item.kind {
            case .existing:
                return activeExistingPhotos.first(where: { $0.id == item.id })?.relativePath
            case .pending:
                return pendingPhotos.first(where: { $0.id == item.id })?.relativePath
            }
        })
    }

    private var hasActiveCoverPhoto: Bool {
        activeCoverPaths.contains(coverPhotoPath)
    }

    private var selectedCoverPhotoItem: PhotoGridItem? {
        coverEligiblePhotoItems.first { item in
            switch item.kind {
            case .existing:
                return activeExistingPhotos.first(where: { $0.id == item.id })?.relativePath == coverPhotoPath
            case .pending:
                return pendingPhotos.first(where: { $0.id == item.id })?.relativePath == coverPhotoPath
            }
        }
    }

    private var theaterEyecatchPicker: some View {
        HStack(spacing: 12) {
            coverPhotoPreview
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text("この回のアイキャッチ")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
                Text(hasActiveCoverPhoto ? "設定済み" : "未設定")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(hasActiveCoverPhoto ? Color.green : Color.secondary)
            }

            Spacer(minLength: 4)

            if coverEligiblePhotoItems.isEmpty {
                eyecatchPhotoAddPicker
            } else {
                Button(hasActiveCoverPhoto ? "変更" : "選ぶ") {
                    isShowingCoverPicker = true
                }
                .buttonStyle(.bordered)

                if hasActiveCoverPhoto {
                    Button("解除") {
                        coverPhotoPath = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .controlSize(.small)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var coverPhotoPreview: some View {
        if let item = selectedCoverPhotoItem {
            switch item.kind {
            case .existing:
                if let photo = activeExistingPhotos.first(where: { $0.id == item.id }) {
                    CompactSavedPhotoThumbnail(
                        photo: photo,
                        purpose: existingMetadata(for: photo).purpose,
                        isCover: true,
                        isHeroBackground: false
                    )
                }
            case .pending:
                if let photo = pendingPhotos.first(where: { $0.id == item.id }) {
                    CompactPendingPhotoThumbnail(
                        photo: photo,
                        purpose: photo.metadata.purpose,
                        isCover: true,
                        isHeroBackground: false
                    )
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    FavorecoIcon(systemName: "photo", size: 20)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.8)
                }
        }
    }

    private var eyecatchPhotoAddPicker: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: remainingPhotoSlots,
            matching: .images
        ) {
            FavorecoIconLabel("写真を追加", systemImage: "photo.badge.plus", iconSize: 13)
                .font(FavorecoTypography.jpSans(12.5, weight: .semibold, relativeTo: .caption))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canAddPhotos)
    }

    @ViewBuilder
    private var coverSelectionGrid: some View {
        if coverEligiblePhotoItems.isEmpty {
            FavorecoContentUnavailableView(
                "選べる写真がありません",
                systemImage: "photo",
                description: "思い出写真を追加してから選択してください。"
            )
        } else {
            LazyVGrid(columns: compactColumns, spacing: 6) {
                ForEach(coverEligiblePhotoItems) { item in
                    coverSelectionTile(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func coverSelectionTile(for item: PhotoGridItem) -> some View {
        switch item.kind {
        case .existing:
            if let photo = activeExistingPhotos.first(where: { $0.id == item.id }) {
                Button {
                    coverPhotoPath = photo.relativePath
                    isShowingCoverPicker = false
                } label: {
                    CompactSavedPhotoThumbnail(
                        photo: photo,
                        purpose: existingMetadata(for: photo).purpose,
                        isCover: coverPhotoPath == photo.relativePath,
                        isHeroBackground: heroBackgroundPath == photo.relativePath
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("この写真をアイキャッチにする")
                .accessibilityAddTraits(coverPhotoPath == photo.relativePath ? .isSelected : [])
            }
        case .pending:
            if let photo = pendingPhotos.first(where: { $0.id == item.id }) {
                Button {
                    coverPhotoPath = photo.relativePath
                    isShowingCoverPicker = false
                } label: {
                    CompactPendingPhotoThumbnail(
                        photo: photo,
                        purpose: photo.metadata.purpose,
                        isCover: coverPhotoPath == photo.relativePath,
                        isHeroBackground: heroBackgroundPath == photo.relativePath
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("この写真をアイキャッチにする")
                .accessibilityAddTraits(coverPhotoPath == photo.relativePath ? .isSelected : [])
            }
        }
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

    private var heroBackgroundPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("トップ背景")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                if !heroBackgroundPath.isEmpty {
                    FavorecoIconLabel("自分の写真", systemImage: "photo.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(heroBackgroundPresets) { preset in
                        Button {
                            heroBackgroundPresetKey = preset.key
                            heroBackgroundPath = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                heroBackgroundPreview(for: preset)

                                Text(preset.title)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .frame(width: 92, height: 34, alignment: .topLeading)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("トップ背景、\(preset.title)")
                        .accessibilityAddTraits(isSelected(preset) ? .isSelected : [])
                    }
                }
            }

            Text("自分の写真を使う場合は、下の写真にある背景ボタンから選べます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func isSelected(_ preset: HeroBackgroundPreset) -> Bool {
        heroBackgroundPath.isEmpty
            && HeroBackgroundPreset.resolved(
                categoryKey: category?.templateKey,
                storedKey: heroBackgroundPresetKey
            ) == preset
    }

    private func heroBackgroundPreview(for preset: HeroBackgroundPreset) -> some View {
        Group {
            if let image = bundledHeroBackgroundImage(named: preset.resourceName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.08)
                    .overlay {
                        FavorecoIcon(systemName: "photo", size: 22)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 92, height: 112)
        .clipped()
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected(preset) ? Color.accentColor : Color.secondary.opacity(0.28),
                    lineWidth: isSelected(preset) ? 3 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func bundledHeroBackgroundImage(named resourceName: String) -> UIImage? {
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
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
            FavorecoIconLabel(label, systemImage: "photo.on.rectangle.angled")
                .frame(maxWidth: .infinity)
        }
        if prominent {
            picker
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
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
            FavorecoIconLabel(label, systemImage: "camera")
                .frame(maxWidth: .infinity)
        }
        if prominent {
            button
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var photoGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: compactColumns, spacing: 6) {
                ForEach(Array(photoItems.prefix(compactPhotoLimit))) { item in
                    compactTile(for: item, opensFromGallery: false)
                }
            }

            if currentPhotoCount > compactPhotoLimit {
                Button {
                    isShowingAllPhotos = true
                } label: {
                    HStack(spacing: 6) {
                        Text("さらに見る")
                        Text("残り\(currentPhotoCount - compactPhotoLimit)枚")
                            .foregroundStyle(.secondary)
                    }
                    .font(FavorecoTypography.captionStrong)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var allPhotoGrid: some View {
        LazyVGrid(columns: compactColumns, spacing: 6) {
            ForEach(photoItems) { item in
                compactTile(for: item, opensFromGallery: true)
            }
        }
    }

    private var photoItems: [PhotoGridItem] {
        activeExistingPhotos.map {
            PhotoGridItem(id: $0.id, kind: .existing)
        } + pendingPhotos.map {
            PhotoGridItem(id: $0.id, kind: .pending)
        }
    }

    @ViewBuilder
    private func compactTile(
        for item: PhotoGridItem,
        opensFromGallery: Bool
    ) -> some View {
        switch item.kind {
        case .existing:
            if let photo = activeExistingPhotos.first(where: { $0.id == item.id }) {
                let metadata = existingMetadata(for: photo)
                Button {
                    openEditor(for: item.editorTarget, fromGallery: opensFromGallery)
                } label: {
                    CompactSavedPhotoThumbnail(
                        photo: photo,
                        purpose: metadata.purpose,
                        isCover: coverPhotoPath == photo.relativePath,
                        isHeroBackground: heroBackgroundPath == photo.relativePath
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    photoContextMenu(
                        purpose: metadata.purpose,
                        path: photo.relativePath,
                        editorTarget: item.editorTarget,
                        opensFromGallery: opensFromGallery,
                        onDelete: {
                            deletedPhotoIDs.insert(photo.id)
                            selectFallbackCover(excluding: photo.relativePath)
                            clearHeroBackground(excluding: photo.relativePath)
                        }
                    )
                }
                .accessibilityLabel("保存済み写真、\(metadata.purpose.title)")
                .accessibilityHint("タップして写真の情報を編集")
            }
        case .pending:
            if let photo = pendingPhotos.first(where: { $0.id == item.id }) {
                Button {
                    openEditor(for: item.editorTarget, fromGallery: opensFromGallery)
                } label: {
                    CompactPendingPhotoThumbnail(
                        photo: photo,
                        purpose: photo.metadata.purpose,
                        isCover: coverPhotoPath == photo.relativePath,
                        isHeroBackground: heroBackgroundPath == photo.relativePath
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    photoContextMenu(
                        purpose: photo.metadata.purpose,
                        path: photo.relativePath,
                        editorTarget: item.editorTarget,
                        opensFromGallery: opensFromGallery,
                        onDelete: {
                            pendingPhotos.removeAll { $0.id == photo.id }
                            selectFallbackCover(excluding: photo.relativePath)
                            clearHeroBackground(excluding: photo.relativePath)
                        }
                    )
                }
                .accessibilityLabel("追加予定の写真、\(photo.metadata.purpose.title)")
                .accessibilityHint("タップして写真の情報を編集")
            }
        }
    }

    @ViewBuilder
    private func photoContextMenu(
        purpose: ExperiencePhotoPurpose,
        path: String,
        editorTarget: PhotoEditorTarget,
        opensFromGallery: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        Button {
            openEditor(for: editorTarget, fromGallery: opensFromGallery)
        } label: {
            Label("写真の情報を編集", systemImage: "slider.horizontal.3")
        }
        if purpose == .memory {
            Button {
                coverPhotoPath = path
            } label: {
                Label("カバー写真にする", systemImage: "star")
            }
            Button {
                heroBackgroundPath = path
            } label: {
                Label("トップ背景にする", systemImage: "rectangle.landscape")
            }
        }
        Button(role: .destructive, action: onDelete) {
            Label("削除", systemImage: "trash")
        }
    }

    private func openEditor(
        for target: PhotoEditorTarget,
        fromGallery: Bool
    ) {
        if fromGallery {
            editingTargetAfterGallery = target
            isShowingAllPhotos = false
        } else {
            editingTarget = target
        }
    }

    @ViewBuilder
    private func metadataEditor(for target: PhotoEditorTarget) -> some View {
        switch target.kind {
        case .existing:
            if let photo = activeExistingPhotos.first(where: { $0.id == target.id }) {
                PhotoMetadataEditor(
                    metadata: existingMetadataBinding(for: photo),
                    imageData: photo.data,
                    allowsBenefits: category?.templateKey == "theater"
                )
            } else {
                FavorecoContentUnavailableView("写真が見つかりません", systemImage: "photo")
            }
        case .pending:
            if let index = pendingPhotos.firstIndex(where: { $0.id == target.id }) {
                PhotoMetadataEditor(
                    metadata: Binding(
                        get: { pendingPhotos[index].metadata },
                        set: { metadata in
                            pendingPhotos[index].metadata = metadata
                            if metadata.purpose != .memory, coverPhotoPath == pendingPhotos[index].relativePath {
                                selectFallbackCover(excluding: pendingPhotos[index].relativePath)
                            }
                            if metadata.purpose != .memory {
                                clearHeroBackground(excluding: pendingPhotos[index].relativePath)
                            }
                        }
                    ),
                    imageData: pendingPhotos[index].data,
                    allowsBenefits: category?.templateKey == "theater"
                )
            } else {
                FavorecoContentUnavailableView("写真が見つかりません", systemImage: "photo")
            }
        }
    }

    private func initializeExistingMetadataDrafts() {
        for photo in existingPhotos where existingPhotoMetadata[photo.id] == nil {
            existingPhotoMetadata[photo.id] = PhotoMetadataDraft(photo: photo)
        }
    }

    private func existingMetadata(for photo: PhotoBlob) -> PhotoMetadataDraft {
        existingPhotoMetadata[photo.id] ?? PhotoMetadataDraft(photo: photo)
    }

    private func existingMetadataBinding(for photo: PhotoBlob) -> Binding<PhotoMetadataDraft> {
        Binding(
            get: { existingMetadata(for: photo) },
            set: { metadata in
                existingPhotoMetadata[photo.id] = metadata
                if metadata.purpose != .memory, coverPhotoPath == photo.relativePath {
                    selectFallbackCover(excluding: photo.relativePath)
                }
                if metadata.purpose != .memory {
                    clearHeroBackground(excluding: photo.relativePath)
                }
            }
        )
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
            .first(where: {
                $0.relativePath != path && existingMetadata(for: $0).purpose == .memory
            })?
            .relativePath
            ?? pendingPhotos.first(where: {
                $0.relativePath != path && $0.metadata.purpose == .memory
            })?.relativePath
            ?? ""
    }

    private func clearHeroBackground(excluding path: String) {
        guard heroBackgroundPath == path else { return }
        heroBackgroundPath = ""
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

private struct PhotoEditorTarget: Identifiable {
    enum Kind {
        case existing
        case pending
    }

    let id: UUID
    let kind: Kind
}

private struct PhotoGridItem: Identifiable {
    enum Kind {
        case existing
        case pending
    }

    let id: UUID
    let kind: Kind

    var editorTarget: PhotoEditorTarget {
        switch kind {
        case .existing:
            PhotoEditorTarget(id: id, kind: .existing)
        case .pending:
            PhotoEditorTarget(id: id, kind: .pending)
        }
    }
}

private struct PhotoMetadataEditor: View {
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @Binding var metadata: PhotoMetadataDraft
    let imageData: Data
    let allowsBenefits: Bool
    @State private var isRecognizing = false
    @State private var isOCRSectionExpanded = false
    @State private var statusText = ""
    @State private var suggestions: [OCRImportSuggestion] = []

    var body: some View {
        Form {
            Section("分類") {
                if allowsBenefits {
                    Picker("写真の種類", selection: $metadata.purpose) {
                        ForEach(ExperiencePhotoPurpose.allCases) { purpose in
                            Text(purpose.title).tag(purpose)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("写真の種類", selection: $metadata.purpose) {
                        ForEach(ExperiencePhotoPurpose.allCases.filter { $0 != .benefit }) { purpose in
                            Text(purpose.title).tag(purpose)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(purposeDescription)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("キャプション") {
                TextField(
                    "写真に写っているものや、その時のひとこと",
                    text: $metadata.caption,
                    axis: .vertical
                )
                .lineLimit(2...4)

                Text("生きものの名前なども、写真ごとにここへ残せます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if metadata.purpose != .memory {
                Section {
                    DisclosureGroup(isExpanded: $isOCRSectionExpanded) {
                        Button {
                            recognizeText()
                        } label: {
                            Label(
                                isRecognizing ? "読み取り中" : "この写真から文字を読み取る",
                                systemImage: "text.viewfinder"
                            )
                        }
                        .disabled(isRecognizing || !usesOCRImportAssist)

                        if !usesOCRImportAssist {
                            Text("画像OCRは設定でOFFになっています。")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        TextEditor(text: $metadata.ocrText)
                            .frame(minHeight: 120)

                        ForEach(amountSuggestions) { suggestion in
                            Button {
                                metadata.amountText = suggestion.value
                                statusText = "金額候補を反映しました。"
                            } label: {
                                Text("金額候補 \(suggestion.displayValue)を使う")
                            }
                        }
                    } label: {
                        Label("文字読み取り（任意）", systemImage: "text.viewfinder")
                    }
                }

                if metadata.purpose.supportsAmount {
                    Section(metadata.purpose == .ticket ? "チケット金額" : "グッズ金額") {
                        TextField("0", text: $metadata.amountText)
                            .keyboardType(.decimalPad)
                        Text("合計金額は後続Stepで、記録全体の費用と分けて表示します。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Text("思い出写真はトップ背景や写真一覧に使用されます。OCR本文と金額は表示・集計しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            refreshSuggestions()
            isOCRSectionExpanded = !metadata.ocrText.isEmpty
        }
        .onChange(of: metadata.ocrText) { _, _ in refreshSuggestions() }
    }

    private var purposeDescription: String {
        switch metadata.purpose {
        case .memory:
            return "通常の写真です。カバーやトップ背景にも指定できます。"
        case .ticket:
            return "チケット画像です。必要な場合だけ文字読み取りと金額を記録できます。"
        case .goods:
            return "グッズ画像です。必要な場合だけ文字読み取りと金額を記録できます。"
        case .benefit:
            return "ノベルティ・特典の画像です。費用には集計しません。"
        }
    }

    private var amountSuggestions: [OCRImportSuggestion] {
        suggestions.filter { $0.kind == .amount }
    }

    private func refreshSuggestions() {
        suggestions = OCRImportSuggestionParser.suggestions(from: metadata.ocrText)
    }

    private func recognizeText() {
        guard usesOCRImportAssist, !isRecognizing else { return }
        isRecognizing = true
        statusText = ""
        let data = imageData
        Task {
            let recognizedText = await Task.detached(priority: .userInitiated) {
                QuickCaptureImageService.recognizedText(from: data)
            }.value
            await MainActor.run {
                isRecognizing = false
                guard !recognizedText.isEmpty else {
                    statusText = "文字を読み取れませんでした。必要なら手入力してください。"
                    return
                }
                metadata.ocrText = recognizedText
                statusText = "読み取り結果を保存候補へ反映しました。"
            }
        }
    }
}
