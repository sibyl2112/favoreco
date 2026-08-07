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
        VStack(alignment: .leading, spacing: 12) {
            if isEditable {
                TextField("書名", text: $title, axis: .vertical)
                    .lineLimit(1...2)
                TextField("シリーズ名（任意）", text: $seriesName, axis: .vertical)
                    .lineLimit(1...2)
                TextField("巻数（任意）", text: $volumeNumber)
                    .keyboardType(.numbersAndPunctuation)
                TextField("著者（任意）", text: $authorName, axis: .vertical)
                    .lineLimit(1...2)
                Picker("本の種類", selection: $aspectRatioKey) {
                    ForEach(formats) { format in
                        Text(format.name).tag(format.key)
                    }
                }
                .pickerStyle(.menu)
                TextField("公式URL（任意）", text: $officialURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } else {
                LabeledContent("書名", value: title.isEmpty ? "未設定" : title)
                if !seriesName.isEmpty { LabeledContent("シリーズ", value: seriesName) }
                if !volumeNumber.isEmpty { LabeledContent("巻数", value: volumeNumber) }
                if !authorName.isEmpty { LabeledContent("著者", value: authorName) }
                LabeledContent(
                    "本の種類",
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
}

struct BookReadingPeriodEditor: View {
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var hasEndDate: Bool
    @Binding var rating: Double
    let ratingText: String

    @State private var isShowingCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()
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
