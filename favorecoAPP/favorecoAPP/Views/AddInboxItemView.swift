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
    @State private var isShowingOCRCamera = false
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

    init(
        initialTemplateKey: String? = nil,
        screenTitle: String = "クイック登録",
        locksCategory: Bool = false,
        initialBookTitle: String = "",
        initialBookSeriesName: String = "",
        initialBookVolumeNumber: String = "",
        initialBookAuthorName: String = "",
        initialBookStateKey: String = "interested",
        initialBookAspectRatioKey: String = EyecatchAspectRatio.hardcoverBook.key
    ) {
        self.initialTemplateKey = initialTemplateKey
        self.screenTitle = screenTitle
        self.locksCategory = locksCategory
        var initialDraft = QuickRegistrationDraft()
        initialDraft.targetTemplateKey = initialTemplateKey ?? ""
        initialDraft.title = initialBookTitle
        initialDraft.bookSeriesName = initialBookSeriesName
        initialDraft.bookVolumeNumber = initialBookVolumeNumber
        initialDraft.bookAuthorName = initialBookAuthorName
        initialDraft.bookStateKey = initialBookStateKey
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
                FavorecoRegistrationSection(basicSectionTitle) {
                    if !locksCategory {
                        Picker("ジャンル", selection: $draft.targetTemplateKey) {
                            ForEach(visibleCategories) { category in
                                Text(category.name).tag(category.templateKey)
                            }
                        }
                    }

                    ExplicitFormTextField(
                        title: targetFieldLabel,
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

                        ExplicitFormControlRow(title: "読書状態") {
                            Picker("読書状態", selection: $draft.bookStateKey) {
                                Text("気になる").tag("interested")
                                Text("積読").tag("active")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        ExplicitFormControlRow(title: "本の種類") {
                            Picker("本の種類", selection: $draft.eyecatchAspectRatioKey) {
                                ForEach(EyecatchAspectRatio.selectableBookFormats) { format in
                                    Text(format.name).tag(format.key)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    } else if isMovieRegistration {
                        ScreenWorkTypeAndSeasonEditor(
                            typeKey: $draft.subTypeKey,
                            seasonNumber: $draft.screenWorkSeasonNumber
                        )
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

                    if usesOCRImportAssist {
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
                    } else {
                        Label("OCR取込は設定でOFFになっています", systemImage: "text.viewfinder")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !titleCandidate.isEmpty {
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

                    if !recognizedOCRLines.isEmpty {
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

                    if !inputStatus.isEmpty {
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
                authorName: draft.trimmedBookAuthorName
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
                bookAuthorName: draft.trimmedBookAuthorName
            ).encodedRawValue
        }
        if isMovieRegistration {
            return VisitUnitFields(
                screenWorkSeasonNumber: ScreenWorkType.resolved(from: draft.subTypeKey).supportsSeason
                    ? draft.screenWorkSeasonNumber
                    : 0
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
        isTitleCandidateFromOCR = false
    }

    private func openOCRCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }
        isShowingOCRCamera = true
    }
}

private struct QuickRegistrationDraft {
    var title: String = ""
    var seriesName: String = ""
    var bookSeriesName: String = ""
    var bookVolumeNumber: String = ""
    var bookAuthorName: String = ""
    var bookStateKey: String = "interested"
    var body: String = ""
    var sourceURL: String = ""
    var targetTemplateKey: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey = EyecatchAspectRatio.hardcoverBook.key
    var subTypeKey = ScreenWorkType.movie.rawValue
    var screenWorkSeasonNumber = 0

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

    var trimmedSourceURL: String {
        sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
