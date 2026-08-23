//
//  AddInboxItemView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct QuickRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @State private var draft = QuickRegistrationDraft()
    @State private var eyecatchData: Data?
    @State private var selectedEyecatchItem: PhotosPickerItem?
    @State private var selectedOCRItem: PhotosPickerItem?
    @State private var selectedBookImportImageItem: PhotosPickerItem?
    @State private var isShowingOCRCamera = false
    @State private var isShowingBookImageSource = false
    @State private var isShowingBookImagePicker = false
    @State private var isShowingBookImportCamera = false
    @State private var isShowingBookISBNImport = false
    @State private var bookMetadataCandidate: BookMetadataCandidate?
    @State private var bookOCRMetadataCandidate: BookOCRMetadataCandidate?
    @State private var screenWorkSearchQuery = ""
    @State private var screenWorkCandidates: [ScreenWorkMetadataCandidate] = []
    @State private var isSearchingScreenWorks = false
    @State private var screenWorkSearchStatus = ""
    @State private var isShowingCameraUnavailableAlert = false
    @State private var isProcessingImage = false
    @State private var isFetchingURL = false
    @State private var inputStatus = ""
    @State private var titleCandidate = ""
    @State private var recognizedOCRLines: [String] = []
    @State private var isTitleCandidateFromOCR = false
    private let initialTemplateKey: String?
    private let screenTitle: String
    private let locksCategory: Bool
    private let simpleRegistrationPurpose: Binding<SimpleCategoryRegistrationPurpose>?

    init(
        initialTemplateKey: String? = nil,
        screenTitle: String = "クイック登録",
        locksCategory: Bool = false,
        simpleRegistrationPurpose: Binding<SimpleCategoryRegistrationPurpose>? = nil,
        initialBookTitle: String = "",
        initialBookSeriesName: String = "",
        initialBookVolumeNumber: String = "",
        initialBookAuthorName: String = "",
        initialBookStateKey: String = "interested",
        initialBookContentTypeKey: String = "",
        initialBookAspectRatioKey: String = EyecatchAspectRatio.hardcoverBook.key
    ) {
        self.initialTemplateKey = initialTemplateKey
        self.screenTitle = screenTitle
        self.locksCategory = locksCategory
        self.simpleRegistrationPurpose = simpleRegistrationPurpose
        var initialDraft = QuickRegistrationDraft()
        initialDraft.targetTemplateKey = initialTemplateKey ?? ""
        initialDraft.title = initialBookTitle
        initialDraft.bookSeriesName = initialBookSeriesName
        initialDraft.bookVolumeNumber = initialBookVolumeNumber
        initialDraft.bookAuthorName = initialBookAuthorName
        initialDraft.bookStateKey = initialBookStateKey
        initialDraft.bookContentTypeKey = initialBookContentTypeKey
        initialDraft.eyecatchAspectRatioKey = initialBookAspectRatioKey.isEmpty
            ? EyecatchAspectRatio.hardcoverBook.key
            : initialBookAspectRatioKey
        _draft = State(initialValue: initialDraft)
    }

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.templateKey == draft.targetTemplateKey }
    }

    private var isBookRegistration: Bool {
        draft.targetTemplateKey == "book"
    }

    private var isMovieRegistration: Bool {
        draft.targetTemplateKey == "movie"
    }

    private var isMuseumRegistration: Bool {
        draft.targetTemplateKey == "museum"
    }

    private var targetName: String {
        switch draft.targetTemplateKey {
        case "book": "本"
        case "movie": "作品"
        case "museum": "展示・イベント"
        case "theme_park": "施設"
        case "nature_living": "スポット"
        case "outing_facility": "施設"
        default: "対象"
        }
    }

    private var basicSectionTitle: String {
        isBookRegistration ? "本の情報" : "\(targetName)情報"
    }

    private var targetFieldLabel: String {
        isBookRegistration ? "書名" : "\(targetName)名"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let simpleRegistrationPurpose, let selectedCategory {
                    SimpleCategoryRegistrationPurposePicker(
                        selection: simpleRegistrationPurpose,
                        category: selectedCategory
                    )
                }

                if isMovieRegistration {
                    screenWorkSearchSection
                }

                if isBookRegistration {
                    FavorecoRegistrationSection("入力を省く") {
                        Button {
                            isShowingBookImageSource = true
                        } label: {
                            bookImportActionLabel(
                                title: "画像から入力",
                                systemImage: "text.viewfinder"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessingImage)

                        if !usesOCRImportAssist {
                            Text("画像からの読み取りは設定でOFFになっています。ISBN入力と手入力は利用できます。")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        if isProcessingImage {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("本の情報を読み取っています")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !inputStatus.isEmpty {
                            Text(inputStatus)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let bookOCRMetadataCandidate {
                            bookOCRMetadataCandidateView(bookOCRMetadataCandidate)
                        } else if !titleCandidate.isEmpty {
                            bookTitleCandidateView
                        }

                        if bookOCRMetadataCandidate == nil, !recognizedOCRLines.isEmpty {
                            bookOCRCandidateView
                        }
                    }
                }

                FavorecoRegistrationSection(basicSectionTitle) {
                    if !locksCategory {
                        Picker("ジャンル", selection: $draft.targetTemplateKey) {
                            ForEach(visibleCategories) { category in
                                Text(category.name).tag(category.templateKey)
                            }
                        }
                    }

                    ExplicitFormTextField(
                        title: "\(targetFieldLabel)（必須）",
                        prompt: isBookRegistration ? "書名を入力" : "\(targetName)名を入力",
                        text: $draft.title,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal,
                        focusesFromWholeRow: true
                    )

                    if isBookRegistration {
                        ExplicitFormTextField(
                            title: "シリーズ",
                            prompt: "シリーズ名（任意）",
                            text: $draft.bookSeriesName,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )

                        ExplicitFormTextField(
                            title: "巻数",
                            prompt: "巻数（任意）",
                            text: $draft.bookVolumeNumber,
                            labelStyle: .horizontal
                        )
                        .keyboardType(.numbersAndPunctuation)

                        ExplicitFormTextField(
                            title: "著者",
                            prompt: "著者名（任意）",
                            text: $draft.bookAuthorName,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )

                        ExplicitFormTextField(
                            title: "訳者",
                            prompt: "訳者名（任意）",
                            text: $draft.bookTranslatorName,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )

                        ExplicitFormTextField(
                            title: "出版社",
                            prompt: "出版社（任意）",
                            text: $draft.bookPublisherName,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )

                        ExplicitFormTextField(
                            title: "発行日",
                            prompt: "YYYY-MM-DD（任意）",
                            text: $draft.bookPublishedDate,
                            labelStyle: .horizontal
                        )
                        .keyboardType(.numbersAndPunctuation)

                        ExplicitFormTextField(
                            title: "ISBN",
                            prompt: "ISBN（任意）",
                            text: $draft.bookISBN,
                            labelStyle: .horizontal
                        )
                        .keyboardType(.asciiCapableNumberPad)

                        ExplicitFormTextField(
                            title: "価格",
                            prompt: "価格（任意）",
                            text: $draft.bookPriceText,
                            labelStyle: .horizontal
                        )
                        .keyboardType(.decimalPad)

                        ExplicitFormTextField(
                            title: "ページ数",
                            prompt: "ページ数（任意）",
                            text: $draft.bookPageCountText,
                            labelStyle: .horizontal
                        )
                        .keyboardType(.numberPad)

                        ExplicitFormControlRow(title: "読書状態") {
                            Picker("読書状態", selection: $draft.bookStateKey) {
                                Text("気になる").tag("interested")
                                Text("積読").tag("active")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        ExplicitFormControlRow(title: "本の種類") {
                            Picker("本の種類", selection: $draft.bookContentTypeKey) {
                                Text("未設定").tag("")
                                ForEach(BookContentType.allCases) { type in
                                    Text(type.displayName).tag(type.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        ExplicitFormControlRow(title: "本の判型") {
                            Picker("本の判型", selection: $draft.eyecatchAspectRatioKey) {
                                ForEach(EyecatchAspectRatio.selectableBookFormats) { format in
                                    Text(format.name).tag(format.key)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                }

                FavorecoRegistrationSection(mediaSectionTitle) {
                    let photoActionTitle = eyecatchData == nil ? "写真を選ぶ" : "写真を変更"
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Button("画像を外す", role: .destructive) {
                            self.eyecatchData = nil
                        }
                    }

                    PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                        FavorecoIconLabel(photoActionTitle, systemImage: "photo")
                    }
                    .disabled(isProcessingImage)
                    .onChange(of: selectedEyecatchItem) { _, item in
                        guard let item else { return }
                        Task { await loadEyecatch(from: item) }
                    }

                    Divider()

                    TextField("URL（任意）", text: $draft.sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    Button {
                        Task { await fetchURLCandidate() }
                    } label: {
                        FavorecoIconLabel(
                            isFetchingURL ? "取得中" : "URLからタイトル候補を取得",
                            systemImage: "link"
                        )
                    }
                    .disabled(draft.trimmedSourceURL.isEmpty || isFetchingURL)

                    if usesOCRImportAssist && !isBookRegistration {
                        PhotosPicker(selection: $selectedOCRItem, matching: .images) {
                            Label("写真から読み取る", systemImage: "text.viewfinder")
                        }
                        .disabled(isProcessingImage)
                        .onChange(of: selectedOCRItem) { _, item in
                            guard let item else { return }
                            Task { await readText(from: item) }
                        }

                        Button {
                            openOCRCamera()
                        } label: {
                            FavorecoIconLabel("カメラで読み取る", systemImage: "camera")
                        }
                        .disabled(isProcessingImage)
                    } else if !isBookRegistration {
                        Label("OCR取込は設定でOFFになっています", systemImage: "text.viewfinder")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !isBookRegistration, !titleCandidate.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                isTitleCandidateFromOCR
                                    ? "大きな文字からのタイトル候補"
                                    : "タイトル候補"
                            )
                                .font(FavorecoTypography.captionStrong)
                            Text(titleCandidate)
                                .font(FavorecoTypography.body)
                                .lineLimit(3)
                            Button("タイトルに使う") {
                                draft.title = titleCandidate
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if !isBookRegistration, !recognizedOCRLines.isEmpty {
                        DisclosureGroup("読み取り候補からタイトルを選ぶ") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(recognizedOCRLines.enumerated()), id: \.offset) { _, line in
                                    Button {
                                        draft.title = line
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(line)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(3)
                                            Spacer(minLength: 8)
                                            Image(systemName: "arrow.up.left")
                                                .accessibilityHidden(true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.top, 8)
                        }

                        DisclosureGroup("OCR全文を確認") {
                            Text(draft.ocrText)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, 8)
                        }
                    }

                    if !isBookRegistration, !inputStatus.isEmpty {
                        Text(inputStatus)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                FavorecoRegistrationSection(memoSectionTitle) {
                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text(memoPrompt)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.body)
                            .frame(minHeight: 88)
                    }
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
            .onAppear {
                if let initialTemplateKey,
                   visibleCategories.contains(where: { $0.templateKey == initialTemplateKey }) {
                    draft.targetTemplateKey = initialTemplateKey
                } else if draft.targetTemplateKey.isEmpty {
                    draft.targetTemplateKey = visibleCategories.first?.templateKey ?? ""
                }
            }
            .photosPicker(
                isPresented: $isShowingBookImagePicker,
                selection: $selectedBookImportImageItem,
                matching: .images
            )
            .onChange(of: selectedBookImportImageItem) { _, item in
                guard let item else { return }
                Task { await readBookInformation(from: item) }
            }
            .confirmationDialog(
                "画像から入力",
                isPresented: $isShowingBookImageSource,
                titleVisibility: .visible
            ) {
                Button("写真ライブラリから選ぶ") {
                    isShowingBookImagePicker = true
                }
                Button("カメラで撮影") {
                    openBookImportCamera()
                }
                Button("ISBN番号を入力") {
                    isShowingBookISBNImport = true
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ISBN・奥付・表紙のいずれかを自動で判定します。ISBNが読み取れた場合は本の情報を優先して検索します。")
            }
        }
        .fullScreenCover(isPresented: $isShowingOCRCamera) {
            CameraImagePicker(
                onCapture: { image in
                    isShowingOCRCamera = false
                    guard let data = image.jpegData(compressionQuality: 1) else { return }
                    Task { await processOCRImage(data) }
                },
                onCancel: { isShowingOCRCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingBookImportCamera) {
            CameraImagePicker(
                onCapture: { image in
                    isShowingBookImportCamera = false
                    guard let data = image.jpegData(compressionQuality: 1) else { return }
                    Task { await readBookInformation(from: data) }
                },
                onCancel: { isShowingBookImportCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingBookISBNImport) {
            BookISBNImportSheet { candidate in
                isShowingBookISBNImport = false
                Task { await applyBookMetadata(candidate) }
            }
        }
        .sheet(item: $bookMetadataCandidate) { candidate in
            BookMetadataReviewSheet(candidate: candidate) {
                bookMetadataCandidate = nil
                Task { await applyBookMetadata(candidate) }
            }
        }
        .alert("カメラを使用できません", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("写真ライブラリから読み取ってください。")
        }
    }

    private func save() {
        guard let selectedCategory else { return }
        let now = Date()
        let event = ExperienceEvent(
            title: draft.trimmedTitle,
            seriesName: isBookRegistration ? "" : draft.trimmedSeriesName,
            subTypeKey: isMovieRegistration ? draft.subTypeKey : "",
            officialURL: draft.trimmedSourceURL,
            stateKey: isBookRegistration ? draft.bookStateKey : "interested",
            memo: draft.trimmedBody,
            importMemo: draft.trimmedOCRText,
            unitFieldsRaw: registrationUnitFieldsRaw,
            createdAt: now,
            updatedAt: now,
            eyecatchData: eyecatchData,
            category: selectedCategory
        )

        if isBookRegistration {
            event.applyBookMetadata(
                seriesName: draft.trimmedBookSeriesName,
                volumeNumber: draft.trimmedBookVolumeNumber,
                authorName: draft.trimmedBookAuthorName,
                translatorName: draft.trimmedBookTranslatorName,
                isbn: draft.trimmedBookISBN,
                publisherName: draft.trimmedBookPublisherName,
                publishedDate: draft.trimmedBookPublishedDate,
                priceText: draft.trimmedBookPriceText,
                pageCount: draft.bookPageCount,
                informationSourceName: draft.trimmedBookInformationSourceName,
                informationSourceURL: draft.trimmedBookInformationSourceURL
            )
        }

        modelContext.insert(event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save quick registration: \(error)")
        }
    }

    private var mediaSectionTitle: String {
        switch draft.targetTemplateKey {
        case "book": "表紙・公式情報（任意）"
        case "movie": "ポスター・公式情報（任意）"
        default: "画像・公式情報（任意）"
        }
    }

    private var screenWorkSearchSection: some View {
        FavorecoRegistrationSection("作品を検索") {
            ScreenWorkTypeAndSeasonEditor(
                typeKey: $draft.subTypeKey,
                seasonNumber: $draft.screenWorkSeasonNumber
            )
            .onChange(of: draft.subTypeKey) { _, _ in
                screenWorkCandidates = []
                screenWorkSearchStatus = ""
            }

            ExplicitFormTextField(
                title: "作品名",
                prompt: "映画・ドラマ・アニメのタイトル",
                text: $screenWorkSearchQuery,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal,
                focusesFromWholeRow: true
            )
            .submitLabel(.search)
            .onSubmit { Task { await searchScreenWorks() } }

            Button {
                Task { await searchScreenWorks() }
            } label: {
                FavorecoIconLabel(
                    isSearchingScreenWorks ? "検索しています" : "作品を検索",
                    systemImage: "magnifyingglass",
                    iconSize: 16
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSearchingScreenWorks || screenWorkSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !ScreenWorkMetadataLookupService.isConfigured {
                Text("作品検索は現在利用できません。作品情報は手入力で登録できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if !screenWorkCandidates.isEmpty {
                VStack(spacing: 0) {
                    ForEach(screenWorkCandidates) { candidate in
                        Button {
                            Task { await applyScreenWorkMetadata(candidate) }
                        } label: {
                            screenWorkCandidateRow(candidate)
                        }
                        .buttonStyle(.plain)

                        if candidate.id != screenWorkCandidates.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if !screenWorkSearchStatus.isEmpty {
                Text(screenWorkSearchStatus)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Text("作品情報提供: TMDB（候補を選んだ後に内容を確認して保存します）")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func screenWorkCandidateRow(_ candidate: ScreenWorkMetadataCandidate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: candidate.posterURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.10)
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 48, height: 68)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(candidate.type.displayName)
                    if !candidate.yearText.isEmpty {
                        Text(candidate.yearText)
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                if !candidate.originalTitle.isEmpty {
                    Text(candidate.originalTitle)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.down.to.line")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var memoSectionTitle: String {
        switch draft.targetTemplateKey {
        case "book": "読書メモ（任意）"
        case "movie": "作品メモ（任意）"
        case "museum": "展示メモ（任意）"
        default: "メモ（任意）"
        }
    }

    private var memoPrompt: String {
        switch draft.targetTemplateKey {
        case "book": "読みたい理由、気になったことなど"
        case "movie": "観たい理由、気になったことなど"
        case "museum": "気になった理由、会期のメモなど"
        default: "気になった理由、あとで調べたいことなど"
        }
    }

    private var registrationUnitFieldsRaw: String {
        if isBookRegistration {
            return VisitUnitFields(
                eyecatchAspectRatioKey: draft.eyecatchAspectRatioKey,
                bookSeriesName: draft.trimmedBookSeriesName,
                bookVolumeNumber: draft.trimmedBookVolumeNumber,
                bookAuthorName: draft.trimmedBookAuthorName,
                bookTranslatorName: draft.trimmedBookTranslatorName,
                bookISBN: draft.trimmedBookISBN,
                bookPublisherName: draft.trimmedBookPublisherName,
                bookPublishedDate: draft.trimmedBookPublishedDate,
                bookPriceText: draft.trimmedBookPriceText,
                bookPageCount: draft.bookPageCount,
                bookContentTypeKey: draft.bookContentTypeKey,
                bookInformationSourceName: draft.trimmedBookInformationSourceName,
                bookInformationSourceURL: draft.trimmedBookInformationSourceURL
            ).encodedRawValue
        }
        if isMovieRegistration {
            return VisitUnitFields(
                screenWorkSeasonNumber: ScreenWorkType.resolved(from: draft.subTypeKey).supportsSeason
                    ? draft.screenWorkSeasonNumber
                    : 0,
                screenWorkOriginalTitle: draft.trimmedScreenWorkOriginalTitle,
                screenWorkReleaseDate: draft.screenWorkReleaseDate,
                screenWorkOverview: draft.trimmedScreenWorkOverview,
                screenWorkTMDBID: draft.screenWorkTMDBID,
                screenWorkTMDBMediaType: draft.screenWorkTMDBMediaType
            ).encodedRawValue
        }
        return ""
    }

    @MainActor
    private func loadEyecatch(from item: PhotosPickerItem) async {
        isProcessingImage = true
        defer {
            isProcessingImage = false
            selectedEyecatchItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let compressed = await Task.detached(priority: .userInitiated, operation: {
                  QuickCaptureImageService.compressedJPEG(from: data)
              }).value else {
            inputStatus = "画像を読み込めませんでした。"
            return
        }
        eyecatchData = compressed
        inputStatus = "アイキャッチを追加しました。"
    }

    @MainActor
    private func searchScreenWorks() async {
        isSearchingScreenWorks = true
        screenWorkCandidates = []
        screenWorkSearchStatus = ""
        defer { isSearchingScreenWorks = false }
        do {
            let type = ScreenWorkType.resolved(from: draft.subTypeKey)
            screenWorkCandidates = try await ScreenWorkMetadataLookupService.search(
                query: screenWorkSearchQuery,
                type: type
            )
            screenWorkSearchStatus = screenWorkCandidates.isEmpty
                ? "一致する作品が見つかりませんでした。作品名を変えるか、手入力で続けられます。"
                : "候補を選ぶと作品情報をフォームへ入力します。"
        } catch {
            screenWorkSearchStatus = error.localizedDescription
        }
    }

    @MainActor
    private func applyScreenWorkMetadata(_ candidate: ScreenWorkMetadataCandidate) async {
        draft.subTypeKey = candidate.type.rawValue
        draft.title = candidate.title
        draft.screenWorkOriginalTitle = candidate.originalTitle
        draft.screenWorkReleaseDate = candidate.releaseDate
        draft.screenWorkOverview = candidate.overview
        draft.screenWorkTMDBID = candidate.tmdbID
        draft.screenWorkTMDBMediaType = candidate.mediaType
        if draft.trimmedSourceURL.isEmpty {
            draft.sourceURL = candidate.informationURL
        }
        if let poster = await ScreenWorkMetadataLookupService.posterData(from: candidate.posterURL),
           let compressed = await Task.detached(priority: .userInitiated, operation: {
               QuickCaptureImageService.compressedJPEG(from: poster)
           }).value {
            eyecatchData = compressed
        }
        screenWorkSearchStatus = "作品情報を入力しました。内容を確認して保存してください。"
    }

    @MainActor
    private func readText(from item: PhotosPickerItem) async {
        defer { selectedOCRItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            inputStatus = "画像を読み込めませんでした。"
            return
        }
        await processOCRImage(data)
    }

    @MainActor
    private func processOCRImage(_ data: Data) async {
        isProcessingImage = true
        inputStatus = "読み取り中です。"
        resetOCRResult()
        defer { isProcessingImage = false }

        let result = await Task.detached(priority: .userInitiated) {
            let compressed = QuickCaptureImageService.compressedJPEG(from: data)
            let analysis = QuickCaptureImageService.recognizedTextAnalysis(from: data)
            return (compressed, analysis)
        }.value

        if let compressed = result.0 {
            eyecatchData = compressed
        }
        let analysis = result.1
        let recognized = analysis.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recognized.isEmpty else {
            inputStatus = "文字を読み取れませんでした。タイトルは手入力できます。"
            return
        }

        recognizedOCRLines = analysis.lines
        isTitleCandidateFromOCR = analysis.isTitleSuggestionReliable
        titleCandidate = analysis.isTitleSuggestionReliable ? analysis.suggestedTitle : ""
        draft.ocrText = recognized
        inputStatus = analysis.isTitleSuggestionReliable
            ? "大きく目立つ文字を候補にしました。内容を確認してください。"
            : "タイトルを特定できませんでした。読み取ったテキストから選んでください。"
    }

    @MainActor
    private func fetchURLCandidate() async {
        isFetchingURL = true
        inputStatus = ""
        defer { isFetchingURL = false }
        do {
            let candidate = try await URLMetadataService.fetch(from: draft.trimmedSourceURL)
            titleCandidate = candidate.title
            isTitleCandidateFromOCR = false
            draft.sourceURL = candidate.resolvedURL.absoluteString
            inputStatus = "URLから候補を取得しました。"
        } catch {
            inputStatus = "タイトル候補を取得できませんでした。URLはそのまま保存できます。"
        }
    }

    private func resetOCRResult() {
        draft.ocrText = ""
        titleCandidate = ""
        recognizedOCRLines = []
        bookOCRMetadataCandidate = nil
        isTitleCandidateFromOCR = false
    }

    private func openOCRCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }
        isShowingOCRCamera = true
    }

    private func bookImportActionLabel(
        title: String,
        detail: String? = nil,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: systemImage, size: 20)
                .foregroundStyle(selectedCategory.map { Color(hex: $0.colorHex) } ?? .accentColor)
                .frame(width: 28)
            Text(title)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 48)
    }

    private func openBookImportCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }
        isShowingBookImportCamera = true
    }

    private func bookOCRMetadataCandidateView(
        _ candidate: BookOCRMetadataCandidate
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("奥付から仮入力しました", systemImage: "checkmark.circle")
                .font(FavorecoTypography.captionStrong)

            if !candidate.title.isEmpty {
                LabeledContent("書名", value: candidate.title)
            }
            if !candidate.volumeNumber.isEmpty {
                LabeledContent("巻数", value: candidate.volumeNumber)
            }
            if !candidate.author.isEmpty {
                LabeledContent("著者", value: candidate.author)
            }
            if !candidate.publisher.isEmpty {
                LabeledContent("出版社", value: candidate.publisher)
            }
            if !candidate.publishedDate.isEmpty {
                LabeledContent("発行日", value: candidate.publishedDate)
            }

            Text("フォームへ仮入力済みです。保存前に各項目を修正できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var bookTitleCandidateView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("書名の候補")
                .font(FavorecoTypography.captionStrong)
            Text(titleCandidate)
                .font(FavorecoTypography.body)
                .lineLimit(3)
            Button("書名に使う") {
                draft.title = titleCandidate
            }
            .buttonStyle(.bordered)
        }
    }

    private var bookOCRCandidateView: some View {
        DisclosureGroup("読み取り候補を確認") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recognizedOCRLines.enumerated()), id: \.offset) { _, line in
                    Button {
                        draft.title = line
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(line)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.left")
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.top, 8)
        }
    }

    @MainActor
    private func readBookInformation(from item: PhotosPickerItem) async {
        defer { selectedBookImportImageItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            inputStatus = "画像を読み込めませんでした。"
            return
        }
        await readBookInformation(from: data)
    }

    @MainActor
    private func readBookInformation(from data: Data) async {
        isProcessingImage = true
        inputStatus = "本の情報を読み取っています。"
        resetOCRResult()
        bookMetadataCandidate = nil
        let allowsTextRecognition = usesOCRImportAssist

        let result = await Task.detached(priority: .userInitiated) {
            let compressed = QuickCaptureImageService.compressedJPEG(from: data)
            let barcodeISBNs = BookMetadataLookupService.isbnCandidates(fromImageData: data)
            // バーコードは文字OCRより判定精度が高い。ISBNを取得できた場合は
            // 重い文字認識を省き、そのまま書誌検索へ進める。
            let analysis = allowsTextRecognition && barcodeISBNs.isEmpty
                ? QuickCaptureImageService.recognizedTextAnalysis(from: data)
                : .empty
            let textISBNs = BookMetadataLookupService.isbnCandidates(from: analysis.fullText)
            return (compressed, analysis, barcodeISBNs + textISBNs)
        }.value

        let analysis = result.1
        draft.ocrText = analysis.fullText
        let ocrMetadata = BookMetadataLookupService.ocrMetadata(from: analysis.fullText)
        recognizedOCRLines = []
        titleCandidate = ""
        isTitleCandidateFromOCR = false
        var resolvedFromReverseLookup = false

        if let isbn = result.2.first {
            draft.bookISBN = isbn
            do {
                bookMetadataCandidate = try await BookMetadataLookupService.lookup(isbn: isbn)
                inputStatus = "ISBNを読み取りました。候補を確認してください。"
            } catch {
                inputStatus = error.localizedDescription
            }
        } else if analysis.fullText.isEmpty {
            inputStatus = allowsTextRecognition
                ? "ISBN・奥付・表紙の情報を読み取れませんでした。手入力で続けられます。"
                : "バーコードからISBNを読み取れませんでした。画像OCRは設定でOFFになっています。"
        } else {
            if ocrMetadata.hasStructuredMetadata {
                bookOCRMetadataCandidate = ocrMetadata
                applyBookOCRMetadata(ocrMetadata)
                inputStatus = "奥付から本を検索しています。"
                if let matchedBook = await BookMetadataLookupService.reverseLookup(from: ocrMetadata) {
                    let didLoadCover = await applyReverseLookedUpBookMetadata(matchedBook)
                    inputStatus = didLoadCover
                        ? "奥付からISBNと正式な表紙を取得しました。内容を確認してください。"
                        : "奥付からISBNと書誌情報を取得しました。表紙は見つかりませんでした。"
                } else {
                    inputStatus = "奥付から\(ocrMetadata.detectedFieldNames.joined(separator: "・"))を読み取りました。"
                }
            } else {
                let searchableMetadata = !ocrMetadata.title.isEmpty
                    ? ocrMetadata
                    : BookOCRMetadataCandidate(
                        title: analysis.isTitleSuggestionReliable ? analysis.suggestedTitle : "",
                        alternateTitles: [],
                        seriesName: "",
                        volumeNumber: "",
                        author: "",
                        publisher: "",
                        publishedDate: "",
                        pageCount: 0
                    )
                if !searchableMetadata.title.isEmpty,
                   let matchedBook = await BookMetadataLookupService.reverseLookup(
                    from: searchableMetadata
                   ) {
                    applyBookOCRMetadata(searchableMetadata)
                    let didLoadCover = await applyReverseLookedUpBookMetadata(matchedBook)
                    resolvedFromReverseLookup = true
                    inputStatus = didLoadCover
                        ? "表紙からISBNと正式な表紙を取得しました。内容を確認してください。"
                        : "表紙からISBNと書誌情報を取得しました。正式な表紙は見つかりませんでした。"
                } else {
                    titleCandidate = searchableMetadata.title
                    recognizedOCRLines = Array(
                        ([ocrMetadata.title] + ocrMetadata.alternateTitles + analysis.titleCandidates)
                            .filter { !$0.isEmpty && $0 != titleCandidate }
                            .prefix(2)
                    )
                }
            }
            if !ocrMetadata.hasStructuredMetadata,
               !resolvedFromReverseLookup,
               analysis.isTitleSuggestionReliable,
               let compressed = result.0 {
                eyecatchData = compressed
            }
            if bookOCRMetadataCandidate == nil, !resolvedFromReverseLookup {
                inputStatus = analysis.isTitleSuggestionReliable
                    ? "表紙の可能性が高い画像です。書名候補を確認してください。"
                    : "本の情報を特定できませんでした。手入力で続けられます。"
            }
        }
        isProcessingImage = false
    }

    private func applyBookOCRMetadata(_ candidate: BookOCRMetadataCandidate) {
        if draft.trimmedTitle.isEmpty, !candidate.title.isEmpty {
            draft.title = candidate.title
        }
        if draft.trimmedBookSeriesName.isEmpty, !candidate.seriesName.isEmpty {
            draft.bookSeriesName = candidate.seriesName
        }
        if draft.trimmedBookVolumeNumber.isEmpty, !candidate.volumeNumber.isEmpty {
            draft.bookVolumeNumber = candidate.volumeNumber
        }
        if draft.trimmedBookAuthorName.isEmpty, !candidate.author.isEmpty {
            draft.bookAuthorName = candidate.author
        }
        if draft.trimmedBookPublisherName.isEmpty, !candidate.publisher.isEmpty {
            draft.bookPublisherName = candidate.publisher
        }
        if draft.trimmedBookPublishedDate.isEmpty, !candidate.publishedDate.isEmpty {
            draft.bookPublishedDate = candidate.publishedDate
        }
        if draft.bookPageCount == 0, candidate.pageCount > 0 {
            draft.bookPageCountText = String(candidate.pageCount)
        }
    }

    @MainActor
    private func applyReverseLookedUpBookMetadata(_ candidate: BookMetadataCandidate) async -> Bool {
        draft.bookISBN = candidate.isbn
        if draft.trimmedBookAuthorName.isEmpty, !candidate.authorText.isEmpty {
            draft.bookAuthorName = candidate.authorText
        }
        if draft.trimmedBookTranslatorName.isEmpty, !candidate.translatorText.isEmpty {
            draft.bookTranslatorName = candidate.translatorText
        }
        if draft.trimmedBookPublisherName.isEmpty, !candidate.publisher.isEmpty {
            draft.bookPublisherName = candidate.publisher
        }
        if draft.trimmedBookPublishedDate.isEmpty, !candidate.publishedDate.isEmpty {
            draft.bookPublishedDate = candidate.publishedDate
        }
        if draft.trimmedBookPriceText.isEmpty, !candidate.priceText.isEmpty {
            draft.bookPriceText = candidate.priceText
        }
        if draft.bookPageCount == 0, candidate.pageCount > 0 {
            draft.bookPageCountText = String(candidate.pageCount)
        }
        draft.bookInformationSourceName = candidate.sourceName
        draft.bookInformationSourceURL = candidate.informationURL
        if let cover = await BookMetadataLookupService.coverData(from: candidate.coverURL),
           let compressed = await Task.detached(priority: .userInitiated, operation: {
               QuickCaptureImageService.compressedJPEG(from: cover)
           }).value {
            eyecatchData = compressed
            return true
        }
        return false
    }

    @MainActor
    private func applyBookMetadata(_ candidate: BookMetadataCandidate) async {
        draft.bookISBN = candidate.isbn
        draft.title = candidate.title
        if !candidate.authorText.isEmpty {
            draft.bookAuthorName = candidate.authorText
        }
        draft.bookTranslatorName = candidate.translatorText
        draft.bookPublisherName = candidate.publisher
        draft.bookPublishedDate = candidate.publishedDate
        draft.bookPriceText = candidate.priceText
        draft.bookPageCountText = candidate.pageCount > 0 ? String(candidate.pageCount) : ""
        draft.bookInformationSourceName = candidate.sourceName
        draft.bookInformationSourceURL = candidate.informationURL
        if let cover = await BookMetadataLookupService.coverData(from: candidate.coverURL),
           let compressed = await Task.detached(priority: .userInitiated, operation: {
               QuickCaptureImageService.compressedJPEG(from: cover)
           }).value {
            eyecatchData = compressed
        }
        inputStatus = "ISBNから本の情報を入力しました。内容を確認して保存してください。"
    }
}

private struct BookISBNImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onApply: (BookMetadataCandidate) -> Void

    @State private var isbn = ""
    @State private var candidate: BookMetadataCandidate?
    @State private var isLoading = false
    @State private var isShowingCamera = false
    @State private var selectedBarcodeImageItem: PhotosPickerItem?
    @State private var statusText = ""

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("ISBNから検索") {
                    ExplicitFormTextField(
                        title: "ISBN",
                        prompt: "978・979から始まる番号など",
                        text: $isbn,
                        labelStyle: .horizontal,
                        focusesFromWholeRow: true
                    )
                    .keyboardType(.asciiCapableNumberPad)

                    Text("上段の978・979から始まる番号がISBNです。192から始まる下段は価格コードのため検索しません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await lookup() }
                    } label: {
                        FavorecoIconLabel(
                            isLoading ? "検索しています" : "本の情報を検索",
                            systemImage: "magnifyingglass",
                            iconSize: 16
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || BookMetadataLookupService.normalizedISBN(isbn) == nil)

                    Button {
                        isShowingCamera = true
                    } label: {
                        FavorecoIconLabel(
                            "裏表紙のバーコードを撮影",
                            systemImage: "camera",
                            iconSize: 16
                        )
                    }
                    .disabled(isLoading)

                    PhotosPicker(selection: $selectedBarcodeImageItem, matching: .images) {
                        FavorecoIconLabel(
                            "写真ライブラリから選ぶ",
                            systemImage: "photo.on.rectangle",
                            iconSize: 16
                        )
                    }
                    .disabled(isLoading)
                    .onChange(of: selectedBarcodeImageItem) { _, item in
                        guard let item else { return }
                        Task { await readBarcode(from: item) }
                    }
                }

                if let candidate {
                    FavorecoRegistrationSection("読み取り結果") {
                        LabeledContent("書名", value: candidate.title)
                        if !candidate.authorText.isEmpty {
                            LabeledContent("著者", value: candidate.authorText)
                        }
                        if !candidate.translatorText.isEmpty {
                            LabeledContent("訳者", value: candidate.translatorText)
                        }
                        LabeledContent("ISBN", value: candidate.isbn)
                        if !candidate.publishedDate.isEmpty {
                            LabeledContent("発売日", value: candidate.publishedDate)
                        }
                        if !candidate.publisher.isEmpty {
                            LabeledContent("出版社", value: candidate.publisher)
                        }
                        if !candidate.priceText.isEmpty {
                            LabeledContent("価格", value: "¥\(candidate.priceText)")
                        }
                        Text("書名・著者・訳者・発売日・出版社・価格・ISBN・表紙・参照URLを、取得できた範囲で入力します。保存前に修正できます。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Text("情報元: \(candidate.sourceName)")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            onApply(candidate)
                        } label: {
                            Text("この情報を入力")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !statusText.isEmpty {
                    Section {
                        Text(statusText)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle("ISBNから入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePicker(
                onCapture: { image in
                    isShowingCamera = false
                    guard let data = image.jpegData(compressionQuality: 1) else { return }
                    Task { await readBarcode(from: data) }
                },
                onCancel: { isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    @MainActor
    private func lookup() async {
        isLoading = true
        candidate = nil
        statusText = ""
        defer { isLoading = false }
        do {
            candidate = try await BookMetadataLookupService.lookup(isbn: isbn)
        } catch {
            statusText = error.localizedDescription
        }
    }

    @MainActor
    private func readBarcode(from data: Data) async {
        isLoading = true
        candidate = nil
        statusText = "バーコードと印字された番号を読み取っています。"
        let candidates = await Task.detached(priority: .userInitiated) {
            let barcodeCandidates = BookMetadataLookupService.isbnCandidates(fromImageData: data)
            guard barcodeCandidates.isEmpty else { return barcodeCandidates }

            let recognizedText = QuickCaptureImageService.recognizedText(from: data)
            return BookMetadataLookupService.isbnCandidates(from: recognizedText)
        }.value
        guard let value = candidates.first else {
            statusText = "ISBNを読み取れませんでした。番号を入力して検索できます。"
            isLoading = false
            return
        }
        isbn = value
        isLoading = false
        await lookup()
    }

    @MainActor
    private func readBarcode(from item: PhotosPickerItem) async {
        defer { selectedBarcodeImageItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            statusText = "画像を読み込めませんでした。別の写真を選ぶか、番号を入力してください。"
            return
        }
        await readBarcode(from: data)
    }
}

private struct BookMetadataReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: BookMetadataCandidate
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("画像から見つかった本") {
                    LabeledContent("書名", value: candidate.title)
                    if !candidate.authorText.isEmpty {
                        LabeledContent("著者", value: candidate.authorText)
                    }
                    if !candidate.translatorText.isEmpty {
                        LabeledContent("訳者", value: candidate.translatorText)
                    }
                    LabeledContent("ISBN", value: candidate.isbn)
                    if !candidate.publishedDate.isEmpty {
                        LabeledContent("発売日", value: candidate.publishedDate)
                    }
                    if !candidate.publisher.isEmpty {
                        LabeledContent("出版社", value: candidate.publisher)
                    }
                    if !candidate.priceText.isEmpty {
                        LabeledContent("価格", value: "¥\(candidate.priceText)")
                    }
                    Text("書名・著者・訳者・発売日・出版社・価格・ISBN・表紙・参照URLを、取得できた範囲で入力します。保存前に修正できます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("情報元: \(candidate.sourceName)")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        dismiss()
                        onApply()
                    } label: {
                        Text("この情報を入力")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle("読み取り結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

private struct QuickRegistrationDraft {
    var title: String = ""
    var seriesName: String = ""
    var bookSeriesName: String = ""
    var bookVolumeNumber: String = ""
    var bookAuthorName: String = ""
    var bookTranslatorName: String = ""
    var bookISBN: String = ""
    var bookPublisherName: String = ""
    var bookPublishedDate: String = ""
    var bookPriceText: String = ""
    var bookPageCountText: String = ""
    var bookInformationSourceName: String = ""
    var bookInformationSourceURL: String = ""
    var bookStateKey: String = "interested"
    var bookContentTypeKey: String = ""
    var body: String = ""
    var sourceURL: String = ""
    var targetTemplateKey: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey = EyecatchAspectRatio.hardcoverBook.key
    var subTypeKey = ScreenWorkType.movie.rawValue
    var screenWorkSeasonNumber = 0
    var screenWorkOriginalTitle = ""
    var screenWorkReleaseDate = ""
    var screenWorkOverview = ""
    var screenWorkTMDBID = 0
    var screenWorkTMDBMediaType = ""

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookSeriesName: String {
        bookSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookVolumeNumber: String {
        bookVolumeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookAuthorName: String {
        bookAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookTranslatorName: String {
        bookTranslatorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookISBN: String {
        bookISBN.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublisherName: String {
        bookPublisherName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublishedDate: String {
        bookPublishedDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPriceText: String {
        bookPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPageCount: Int {
        max(Int(bookPageCountText.filter(\.isNumber)) ?? 0, 0)
    }

    var trimmedBookInformationSourceName: String {
        bookInformationSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookInformationSourceURL: String {
        bookInformationSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSourceURL: String {
        sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedScreenWorkOriginalTitle: String {
        screenWorkOriginalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedScreenWorkOverview: String {
        screenWorkOverview.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty && !targetTemplateKey.isEmpty
    }

    var trimmedOCRText: String {
        ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    QuickRegistrationView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
