import PhotosUI
import SwiftUI
import UIKit

struct BookRecordEyecatchEditor: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.photoCompressionQuality) private var compressionQuality = 0.85

    let existingPhotos: [PhotoBlob]
    @Binding var pendingPhotos: [PendingPhoto]
    @Binding var coverPhotoPath: String
    let fallbackImageData: Data?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    private var selectedExistingPhoto: PhotoBlob? {
        existingPhotos.first { $0.relativePath == coverPhotoPath }
    }

    private var selectedPendingPhoto: PendingPhoto? {
        pendingPhotos.first { $0.relativePath == coverPhotoPath }
    }

    private var canAddPhoto: Bool {
        guard let maximum = purchaseManager.currentPlan.maximumPhotosPerRecord else { return true }
        return existingPhotos.count + pendingPhotos.count < maximum
    }

    var body: some View {
        Section("アイキャッチ") {
            HStack {
                Spacer(minLength: 0)
                preview
                    .frame(width: 126, height: 178)
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    FavorecoIconLabel(
                        coverPhotoPath.isEmpty ? "設定" : "変更",
                        systemImage: "photo",
                        iconSize: 15
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || !canAddPhoto)

                if !coverPhotoPath.isEmpty {
                    Button(role: .destructive) {
                        coverPhotoPath = ""
                    } label: {
                        FavorecoIconLabel("解除", systemImage: "xmark.circle", iconSize: 15)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("画像を準備しています")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !canAddPhoto {
                Text("写真上限に達しています。写真欄で不要な写真を整理してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            } else if coverPhotoPath.isEmpty, fallbackImageData != nil {
                Text("未設定時は本の表紙を表示します。ここで設定すると、この読書記録だけのアイキャッチになります。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let selectedExistingPhoto {
            RepresentativePhotoImage(
                photo: selectedExistingPhoto,
                maxPixelSize: 520,
                contentMode: .fill
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let selectedPendingPhoto,
                  let image = UIImage(data: selectedPendingPhoto.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let fallbackImageData,
                  let image = UIImage(data: fallbackImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                Color.secondary.opacity(0.08)
                FavorecoIcon(systemName: "book.closed", size: 34)
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer {
            isLoading = false
            selectedItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let quality = compressionQuality
        guard let pending = await Task.detached(priority: .userInitiated, operation: {
            PendingPhoto.make(
                from: data,
                filename: "book-record-eyecatch.jpg",
                compressionQuality: quality
            )
        }).value else { return }
        pendingPhotos.append(pending)
        coverPhotoPath = pending.relativePath
    }
}

struct BookInformationEditor: View {
    @Binding var title: String
    @Binding var seriesName: String
    @Binding var volumeNumber: String
    @Binding var authorName: String
    @Binding var translatorName: String
    @Binding var isbn: String
    @Binding var publisherName: String
    @Binding var publishedDate: String
    @Binding var priceText: String
    @Binding var pageCountText: String
    @Binding var officialURL: String
    @Binding var aspectRatioKey: String
    let isEditable: Bool

    private var formats: [EyecatchAspectRatio] {
        if aspectRatioKey == EyecatchAspectRatio.bookCover.key {
            return [EyecatchAspectRatio.bookCover] + EyecatchAspectRatio.selectableBookFormats
        }
        return EyecatchAspectRatio.selectableBookFormats
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditable {
                ExplicitFormTextField(
                    title: "書名（必須）",
                    prompt: "書名を入力",
                    text: $title,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                fieldDivider
                ExplicitFormTextField(
                    title: "シリーズ名（任意）",
                    prompt: "シリーズ名を入力",
                    text: $seriesName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                fieldDivider
                ExplicitFormTextField(
                    title: "巻数（任意）",
                    prompt: "例：3",
                    text: $volumeNumber,
                    labelStyle: .horizontal
                )
                    .keyboardType(.numbersAndPunctuation)
                fieldDivider
                ExplicitFormTextField(
                    title: "著者（任意）",
                    prompt: "著者名を入力",
                    text: $authorName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                fieldDivider
                ExplicitFormTextField(
                    title: "訳者（任意）",
                    prompt: "訳者名を入力",
                    text: $translatorName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                fieldDivider
                ExplicitFormTextField(
                    title: "出版社（任意）",
                    prompt: "出版社名を入力",
                    text: $publisherName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                fieldDivider
                ExplicitFormTextField(
                    title: "発行日（任意）",
                    prompt: "例：2026/08/14",
                    text: $publishedDate,
                    labelStyle: .horizontal
                )
                    .keyboardType(.numbersAndPunctuation)
                fieldDivider
                ExplicitFormTextField(
                    title: "ISBN（任意）",
                    prompt: "ISBN-10またはISBN-13",
                    text: $isbn,
                    labelStyle: .horizontal
                )
                    .keyboardType(.asciiCapableNumberPad)
                fieldDivider
                ExplicitFormTextField(
                    title: "価格（任意）",
                    prompt: "例：1980",
                    text: $priceText,
                    labelStyle: .horizontal
                )
                    .keyboardType(.decimalPad)
                fieldDivider
                ExplicitFormTextField(
                    title: "ページ数（任意）",
                    prompt: "例：320",
                    text: $pageCountText,
                    labelStyle: .horizontal
                )
                    .keyboardType(.numberPad)
                fieldDivider
                ExplicitFormControlRow(title: "表紙の比率", isOptional: true) {
                    Picker("表紙の比率", selection: $aspectRatioKey) {
                        ForEach(formats) { format in
                            Text(format.name).tag(format.key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                fieldDivider
                ExplicitFormTextField(
                    title: "公式URL（任意）",
                    prompt: "https://example.com",
                    text: $officialURL,
                    labelStyle: .horizontal
                )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } else {
                LabeledContent("書名", value: title.isEmpty ? "未設定" : title)
                if !seriesName.isEmpty { LabeledContent("シリーズ", value: seriesName) }
                if !volumeNumber.isEmpty { LabeledContent("巻数", value: volumeNumber) }
                if !authorName.isEmpty { LabeledContent("著者", value: authorName) }
                if !translatorName.isEmpty { LabeledContent("訳者", value: translatorName) }
                if !publisherName.isEmpty { LabeledContent("出版社", value: publisherName) }
                if !publishedDate.isEmpty { LabeledContent("発行日", value: publishedDate) }
                if !isbn.isEmpty { LabeledContent("ISBN", value: isbn) }
                if !priceText.isEmpty { LabeledContent("価格", value: "¥\(priceText)") }
                if !pageCountText.isEmpty { LabeledContent("ページ数", value: "\(pageCountText)ページ") }
                LabeledContent(
                    "表紙の比率",
                    value: EyecatchAspectRatio.option(forKey: aspectRatioKey)?.name ?? "未設定"
                )
                if !officialURL.isEmpty {
                    LabeledContent("公式URL", value: officialURL)
                }
            }
        }
        .onAppear {
            if aspectRatioKey.isEmpty {
                aspectRatioKey = EyecatchAspectRatio.hardcoverBook.key
            }
        }
    }

    private var fieldDivider: some View {
        Divider().overlay(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct BookReadingPeriodEditor: View {
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var hasEndDate: Bool
    @Binding var rating: Double
    let ratingText: String
    var showsRating: Bool = true

    @State private var isShowingCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExplicitFormControlRow(title: "読書状態", isOptional: false) {
                Picker("読書状態", selection: readingStatusBinding) {
                    Text("読書中").tag(false)
                    Text("読了").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()

            Button {
                isShowingCalendar = true
            } label: {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "calendar", size: 17)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("読書期間")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(periodText)
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsRating {
                Divider()

                HStack(spacing: 10) {
                    Text("評価")
                        .font(FavorecoTypography.body)
                    Slider(value: $rating, in: 0...5, step: 0.5)
                    Text(ratingText)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 42, alignment: .trailing)
                }
            }
        }
        .sheet(isPresented: $isShowingCalendar) {
            BookReadingCalendarSheet(
                startsAt: startsAt,
                endsAt: endsAt,
                hasEndDate: hasEndDate
            ) { start, end in
                startsAt = start
                if let end {
                    endsAt = max(end, start)
                    hasEndDate = true
                } else {
                    endsAt = start
                    hasEndDate = false
                }
            }
        }
    }

    private var periodText: String {
        let start = Self.dateFormatter.string(from: startsAt)
        guard hasEndDate else { return "\(start)〜" }
        return "\(start)〜\(Self.dateFormatter.string(from: endsAt))"
    }

    private var readingStatusBinding: Binding<Bool> {
        Binding {
            hasEndDate
        } set: { isRead in
            hasEndDate = isRead
            if isRead {
                endsAt = max(endsAt, startsAt)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()
}

enum BookReadingMedium: String, CaseIterable, Identifiable {
    case paper
    case ebook
    case audiobook
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paper: "書籍"
        case .ebook: "電子書籍"
        case .audiobook: "オーディオブック"
        case .other: "その他"
        }
    }

    static func resolved(_ key: String) -> BookReadingMedium {
        BookReadingMedium(rawValue: key) ?? .paper
    }
}

struct BookReadingMediumEditor: View {
    @Binding var mediumKey: String

    var body: some View {
        ExplicitFormControlRow(title: "媒体", isOptional: false) {
            Picker("媒体", selection: mediumBinding) {
                ForEach(BookReadingMedium.allCases) { medium in
                    Text(medium.displayName).tag(medium.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .onAppear {
            if mediumKey.isEmpty {
                mediumKey = BookReadingMedium.paper.rawValue
            }
        }
    }

    private var mediumBinding: Binding<String> {
        Binding {
            BookReadingMedium.resolved(mediumKey).rawValue
        } set: { mediumKey = $0 }
    }
}

private struct BookReadingCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onApply: (Date, Date?) -> Void
    @State private var selectedDates: Set<DateComponents>

    init(
        startsAt: Date,
        endsAt: Date,
        hasEndDate: Bool,
        onApply: @escaping (Date, Date?) -> Void
    ) {
        self.onApply = onApply
        var values: Set<DateComponents> = [Self.components(for: startsAt)]
        if hasEndDate {
            values.insert(Self.components(for: endsAt))
        }
        _selectedDates = State(initialValue: values)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("開始日を選び、続けて終了日を選択します。開始日だけでも保存できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                MultiDatePicker("読書期間", selection: $selectedDates)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                Text(selectionSummary)
                    .font(FavorecoTypography.bodyStrong)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("読書期間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        let dates = resolvedDates
                        guard let start = dates.first else { return }
                        onApply(start, dates.count > 1 ? dates.last : nil)
                        dismiss()
                    }
                    .disabled(resolvedDates.isEmpty)
                }
            }
            .onChange(of: selectedDates) { oldValue, newValue in
                guard newValue.count > 2 else { return }
                if let added = newValue.subtracting(oldValue).first {
                    selectedDates = [added]
                } else {
                    selectedDates = Set(newValue.sorted { lhs, rhs in
                        let left = Calendar.current.date(from: lhs) ?? .distantPast
                        let right = Calendar.current.date(from: rhs) ?? .distantPast
                        return left < right
                    }.suffix(2))
                }
            }
        }
        .presentationDetents([.large])
    }

    private var resolvedDates: [Date] {
        selectedDates.compactMap { Calendar.current.date(from: $0) }.sorted()
    }

    private var selectionSummary: String {
        let dates = resolvedDates
        guard let first = dates.first else { return "開始日を選択してください" }
        let start = Self.formatter.string(from: first)
        guard dates.count > 1, let last = dates.last else { return "開始 \(start)" }
        return "開始 \(start)　終了 \(Self.formatter.string(from: last))"
    }

    private static func components(for date: Date) -> DateComponents {
        Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()
}

private extension EyecatchAspectRatio {
    static func option(forKey key: String) -> EyecatchAspectRatio? {
        all.first { $0.key == key }
    }
}
