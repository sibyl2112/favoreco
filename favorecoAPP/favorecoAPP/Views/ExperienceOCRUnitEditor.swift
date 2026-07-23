//
//  ExperienceOCRUnitEditor.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/15.
//

import Foundation
import PhotosUI
import SwiftUI

struct OCRImportSuggestion: Identifiable {
    enum Kind: String {
        case title, date, venue, amount

        var label: String {
            switch self {
            case .title: return "タイトル"
            case .date: return "日付"
            case .venue: return "会場・場所"
            case .amount: return "金額"
            }
        }

        var systemImage: String {
            switch self {
            case .title: return "textformat"
            case .date: return "calendar"
            case .venue: return "mappin.and.ellipse"
            case .amount: return "yensign.circle"
            }
        }
    }

    let kind: Kind
    let value: String
    let displayValue: String
    let dateValue: Date?

    var id: String { "\(kind.rawValue):\(value)" }
}

enum OCRImportSuggestionParser {
    static func suggestions(from text: String) -> [OCRImportSuggestion] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var results: [OCRImportSuggestion] = []

        for line in lines {
            appendLabeled(from: line, labels: ["公演名", "イベント名", "作品名", "タイトル"], kind: .title, to: &results)
            appendLabeled(from: line, labels: ["会場", "劇場", "場所", "VENUE"], kind: .venue, to: &results)
            if let date = parsedDate(from: line) {
                results.append(OCRImportSuggestion(
                    kind: .date,
                    value: date.formatted(.iso8601.year().month().day()),
                    displayValue: FavorecoDateText.fullDate(date),
                    dateValue: date
                ))
            }
            if let amount = parsedAmount(from: line) {
                results.append(OCRImportSuggestion(kind: .amount, value: amount, displayValue: "¥\(amount)", dateValue: nil))
            }
        }

        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }

    private static func appendLabeled(
        from line: String,
        labels: [String],
        kind: OCRImportSuggestion.Kind,
        to results: inout [OCRImportSuggestion]
    ) {
        let uppercased = line.uppercased()
        guard let label = labels.first(where: { uppercased.hasPrefix($0.uppercased()) }) else { return }
        let value = String(line.dropFirst(label.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: " :：-　"))
        guard !value.isEmpty else { return }
        results.append(OCRImportSuggestion(kind: kind, value: value, displayValue: value, dateValue: nil))
    }

    private static func parsedDate(from line: String) -> Date? {
        let patterns = [#"20\d{2}[年./-]\d{1,2}[月./-]\d{1,2}日?"#, #"\d{1,2}月\d{1,2}日"#]
        guard let match = firstMatch(in: line, patterns: patterns) else { return nil }
        let normalized = match
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let components = normalized.split(separator: "-").compactMap { Int($0) }
        let calendar = Calendar.current
        if components.count == 3 {
            return calendar.date(from: DateComponents(year: components[0], month: components[1], day: components[2]))
        }
        if components.count == 2 {
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: Date()),
                month: components[0],
                day: components[1]
            ))
        }
        return nil
    }

    private static func parsedAmount(from line: String) -> String? {
        guard line.contains("¥") || line.contains("￥") || line.contains("円") else { return nil }
        let patterns = [#"[¥￥]\s*[0-9][0-9,]*"#, #"[0-9][0-9,]*\s*円"#]
        guard let match = firstMatch(in: line, patterns: patterns) else { return nil }
        let digits = match.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else { return nil }
        return String(value)
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = expression.firstMatch(in: text, range: range),
                  let swiftRange = Range(match.range, in: text) else { continue }
            return String(text[swiftRange])
        }
        return nil
    }
}

struct OCRUnitEditor: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @Binding var ocrText: String
    @Binding var selectedItems: [PhotosPickerItem]
    var supportsTitleSuggestion = true
    let onApplySuggestion: (OCRImportSuggestion) -> Void
    @State private var isRecognizing = false
    @State private var statusText = ""
    @State private var suggestions: [OCRImportSuggestion] = []

    var body: some View {
        let recognitionActionTitle = isRecognizing ? "読み取り中" : "画像から読み取る"
        VStack(alignment: .leading, spacing: 12) {
            if usesOCRImportAssist {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                    Label(recognitionActionTitle, systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRecognizing)
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        await recognize(from: newItems)
                        selectedItems.removeAll()
                    }
                }
            } else {
                Label("画像OCRは設定でOFFになっています", systemImage: "text.viewfinder")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if ocrText.isEmpty {
                    Text("読み取ったテキスト、または手入力の取込メモ")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $ocrText)
                    .frame(minHeight: 140)
            }

            if !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                advancedSuggestionSection
            }

            Text("基本OCRは読み取り結果をそのまま保存します。高度OCRの候補は確認して選んだ項目だけに反映され、自動で上書きしません。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: ocrText) { _, newValue in
            refreshSuggestions(from: newValue)
        }
        .onChange(of: purchaseManager.currentPlan) { _, _ in
            refreshSuggestions(from: ocrText)
        }
        .onAppear {
            refreshSuggestions(from: ocrText)
        }
    }

    @ViewBuilder
    private var advancedSuggestionSection: some View {
        if purchaseManager.currentPlan.includesLocalFullFeatures {
            VStack(alignment: .leading, spacing: 8) {
                Label("項目候補", systemImage: "wand.and.stars")
                    .font(FavorecoTypography.captionStrong)

                if suggestions.isEmpty {
                    Text("日付・金額、または「会場：」「公演名：」のようなラベル付き情報が見つかると候補を表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onApplySuggestion(suggestion)
                            statusText = "\(suggestion.kind.label)へ反映しました。"
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.kind.systemImage)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.kind.label)
                                        .font(FavorecoTypography.captionStrong)
                                    Text(suggestion.displayValue)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.turn.down.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        } else {
            Label("項目候補への振り分けはPro以上", systemImage: "lock.fill")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshSuggestions(from text: String) {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else {
            suggestions = []
            return
        }
        suggestions = OCRImportSuggestionParser.suggestions(from: text)
            .filter { supportsTitleSuggestion || $0.kind != .title }
    }

    @MainActor
    private func recognize(from items: [PhotosPickerItem]) async {
        guard usesOCRImportAssist, let item = items.first else { return }
        isRecognizing = true
        statusText = ""
        defer { isRecognizing = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            statusText = "画像を読み込めませんでした。"
            return
        }

        let recognizedText = await Task.detached(priority: .userInitiated) {
            QuickCaptureImageService.recognizedText(from: data)
        }.value
        guard !recognizedText.isEmpty else {
            statusText = "文字を読み取れませんでした。必要なら手入力してください。"
            return
        }

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ocrText = recognizedText
        } else {
            ocrText += "\n\n" + recognizedText
        }
        statusText = "読み取り結果を追加しました。"
    }
}
