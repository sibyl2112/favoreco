import Foundation
import PhotosUI
import SwiftUI

private enum TicketDetailsOCRField: String, CaseIterable, Hashable {
    case price
    case fee
    case quantity
    case seat

    var title: String {
        switch self {
        case .price: "チケット代"
        case .fee: "手数料"
        case .quantity: "枚数"
        case .seat: "座席・整理番号"
        }
    }
}

private struct TicketDetailsOCRCandidate: Identifiable {
    let id = UUID()
    let priceText: String?
    let feeText: String?
    let quantity: Int?
    let seatText: String?

    var availableFields: [TicketDetailsOCRField] {
        TicketDetailsOCRField.allCases.filter { value(for: $0) != nil }
    }

    func value(for field: TicketDetailsOCRField) -> String? {
        switch field {
        case .price:
            priceText.map { "¥\($0)" }
        case .fee:
            feeText.map { "¥\($0)" }
        case .quantity:
            quantity.map { "\($0)枚" }
        case .seat:
            seatText
        }
    }
}

struct TicketDetailsOCRInput: View {
    @Binding var priceText: String
    @Binding var feeText: String
    @Binding var quantity: Int
    @Binding var seatText: String

    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isReading = false
    @State private var status = ""
    @State private var reviewCandidate: TicketDetailsOCRCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if usesOCRImportAssist {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 2,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        FavorecoIcon(
                            systemName: "text.viewfinder",
                            size: 17,
                            fallbackWeight: .semibold
                        )
                        Text(isReading ? "読み取り中" : "写真から入力")
                            .font(FavorecoTypography.bodyStrong)
                        Spacer(minLength: 0)
                        if isReading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .disabled(isReading)
                .onChange(of: selectedItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await readImages(from: items) }
                }
                .accessibilityHint("チケット画像から金額、手数料、枚数、座席を読み取ります")
            } else {
                FavorecoIconLabel(
                    "画像OCRは設定でOFFになっています",
                    systemImage: "text.viewfinder"
                )
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }

            if !status.isEmpty {
                Text(status)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $reviewCandidate) { candidate in
            TicketDetailsOCRReviewSheet(
                candidate: candidate,
                currentPriceText: priceText,
                currentFeeText: feeText,
                currentQuantity: quantity,
                currentSeatText: seatText
            ) { selectedFields in
                apply(candidate, fields: selectedFields)
                reviewCandidate = nil
            }
            .favorecoAppAppearance()
        }
    }

    @MainActor
    private func readImages(from items: [PhotosPickerItem]) async {
        isReading = true
        status = "写真から文字を読み取っています。"
        defer {
            isReading = false
            selectedItems = []
        }

        var sourceData: [Data] = []
        for item in items.prefix(2) {
            if let data = try? await item.loadTransferable(type: Data.self) {
                sourceData.append(data)
            }
        }
        guard !sourceData.isEmpty else {
            status = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }

        let recognizedText = await Task.detached(priority: .userInitiated) {
            sourceData
                .map { QuickCaptureImageService.recognizedTextAnalysis(from: $0).fullText }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }.value
        guard !recognizedText.isEmpty else {
            status = "文字を読み取れませんでした。必要な項目を手入力してください。"
            return
        }

        let result = TicketOCRImportParser.parse(text: recognizedText, referenceDate: Date())
        let candidate = TicketDetailsOCRCandidate(
            priceText: result.priceText,
            feeText: result.feeText,
            quantity: result.quantity,
            seatText: result.seatText
        )
        guard !candidate.availableFields.isEmpty else {
            status = "文字は読み取れましたが、金額・手数料・枚数・座席を見つけられませんでした。"
            return
        }
        status = "読み取った内容を確認してください。"
        reviewCandidate = candidate
    }

    private func apply(
        _ candidate: TicketDetailsOCRCandidate,
        fields: Set<TicketDetailsOCRField>
    ) {
        var applied: [String] = []
        if fields.contains(.price), let value = candidate.priceText {
            priceText = value
            applied.append(TicketDetailsOCRField.price.title)
        }
        if fields.contains(.fee), let value = candidate.feeText {
            feeText = value
            applied.append(TicketDetailsOCRField.fee.title)
        }
        if fields.contains(.quantity), let value = candidate.quantity {
            quantity = value
            applied.append(TicketDetailsOCRField.quantity.title)
        }
        if fields.contains(.seat), let value = candidate.seatText {
            seatText = value
            applied.append(TicketDetailsOCRField.seat.title)
        }
        status = applied.isEmpty
            ? "反映する項目は選ばれませんでした。"
            : "\(applied.joined(separator: "・"))へ仮入力しました。保存前に確認してください。"
    }
}

private struct TicketDetailsOCRReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: TicketDetailsOCRCandidate
    let currentPriceText: String
    let currentFeeText: String
    let currentQuantity: Int
    let currentSeatText: String
    let onApply: (Set<TicketDetailsOCRField>) -> Void
    @State private var selectedFields: Set<TicketDetailsOCRField>

    init(
        candidate: TicketDetailsOCRCandidate,
        currentPriceText: String,
        currentFeeText: String,
        currentQuantity: Int,
        currentSeatText: String,
        onApply: @escaping (Set<TicketDetailsOCRField>) -> Void
    ) {
        self.candidate = candidate
        self.currentPriceText = currentPriceText
        self.currentFeeText = currentFeeText
        self.currentQuantity = currentQuantity
        self.currentSeatText = currentSeatText
        self.onApply = onApply
        _selectedFields = State(initialValue: Set(candidate.availableFields.filter { field in
            switch field {
            case .price: currentPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .fee: currentFeeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .quantity: currentQuantity == 1
            case .seat: currentSeatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidate.availableFields, id: \.self) { field in
                        Button {
                            if selectedFields.contains(field) {
                                selectedFields.remove(field)
                            } else {
                                selectedFields.insert(field)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedFields.contains(field)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(field.title)
                                        .font(FavorecoTypography.bodyStrong)
                                        .foregroundStyle(.primary)
                                    Text(candidate.value(for: field) ?? "—")
                                        .font(FavorecoTypography.body)
                                        .foregroundStyle(.secondary)
                                    if let currentValue = currentValue(for: field) {
                                        Text("現在：\(currentValue)")
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    FavorecoRegistrationSectionHeader("読み取った内容")
                } footer: {
                    Text("反映する項目だけを選んでください。入力済みの項目は初期選択していません。写真とOCR全文は保存しません。")
                }
            }
            .navigationTitle("写真から入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("反映") {
                        onApply(selectedFields)
                        dismiss()
                    }
                    .disabled(selectedFields.isEmpty)
                }
            }
        }
    }

    private func currentValue(for field: TicketDetailsOCRField) -> String? {
        switch field {
        case .price:
            currentPriceText.isEmpty ? nil : "¥\(currentPriceText)"
        case .fee:
            currentFeeText.isEmpty ? nil : "¥\(currentFeeText)"
        case .quantity:
            currentQuantity == 1 ? nil : "\(currentQuantity)枚"
        case .seat:
            currentSeatText.isEmpty ? nil : currentSeatText
        }
    }
}
