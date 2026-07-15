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

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.templateKey == draft.targetTemplateKey }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("クイック登録") {
                    Picker("ジャンル", selection: $draft.targetTemplateKey) {
                        ForEach(visibleCategories) { category in
                            Text(category.name).tag(category.templateKey)
                        }
                    }

                    TextField("タイトル（必須）", text: $draft.title)
                }

                Section("アイキャッチ（任意）") {
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
                        Label(eyecatchData == nil ? "写真を選ぶ" : "写真を変更", systemImage: "photo")
                    }
                    .disabled(isProcessingImage)
                    .onChange(of: selectedEyecatchItem) { _, item in
                        guard let item else { return }
                        Task { await loadEyecatch(from: item) }
                    }
                }

                Section("入力補助") {
                    TextField("URL（任意）", text: $draft.sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    Button {
                        Task { await fetchURLCandidate() }
                    } label: {
                        Label(isFetchingURL ? "取得中" : "URLからタイトル候補を取得", systemImage: "link")
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
                            Label("カメラで読み取る", systemImage: "camera")
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

                Section("メモ") {
                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("気になった理由、あとで調べたいことなど")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.body)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("クイック登録")
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
                if draft.targetTemplateKey.isEmpty {
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
            officialURL: draft.trimmedSourceURL,
            stateKey: "interested",
            memo: draft.trimmedBody,
            importMemo: draft.trimmedOCRText,
            createdAt: now,
            updatedAt: now,
            eyecatchData: eyecatchData,
            category: selectedCategory
        )

        modelContext.insert(event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save quick registration: \(error)")
        }
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
    var body: String = ""
    var sourceURL: String = ""
    var targetTemplateKey: String = ""
    var ocrText: String = ""

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
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
