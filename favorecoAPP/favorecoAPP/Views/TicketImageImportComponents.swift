import Foundation
import SwiftUI

struct TicketOCRImportResult {
    var ticketGuideKey: String?
    var purchaseURL: String?
    var saleStartAt: Date?
    var applyDeadlineAt: Date?
    var resultAnnounceAt: Date?
    var paymentDeadlineAt: Date?
    var issueStartAt: Date?
    var priceText: String?
    var feeText: String?
    var seatText: String?
    var quantity: Int?
}

struct PendingTicketOCRImport: Identifiable {
    let id = UUID()
    let result: TicketOCRImportResult
    let suggestedTitle: String?
    let venue: String?
    let eventDateRange: QuickCaptureDateRange?
    let isExistingDuplicate: Bool

    var hasSuggestions: Bool {
        !summaryItems.isEmpty
    }

    var summary: String {
        "候補：\(summaryItems.joined(separator: "、"))"
    }

    var displayTitle: String {
        let title = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "チケット申込" : title
    }

    var scheduleSummary: String {
        var values: [String] = []
        if let dateRange = eventDateRange {
            values.append(FavorecoDateText.compactDateTime(dateRange.startsAt))
        } else {
            values.append("参加日未定")
        }
        if let venue, !venue.isEmpty { values.append(venue) }
        if let guideKey = result.ticketGuideKey,
           let guide = TicketGuideDefinition.guide(for: guideKey) {
            values.append(guide.name)
        }
        return values.joined(separator: " / ")
    }

    var fingerprint: String {
        let values: [String] = [
            suggestedTitle ?? "",
            venue ?? "",
            eventDateRange.map { String(Int($0.startsAt.timeIntervalSince1970 / 60)) } ?? "",
            result.ticketGuideKey ?? "",
            result.purchaseURL ?? "",
            result.applyDeadlineAt.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "",
            result.resultAnnounceAt.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "",
        ]
        return values
            .joined(separator: "|")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }

    func withExistingDuplicate(_ isDuplicate: Bool) -> PendingTicketOCRImport {
        PendingTicketOCRImport(
            result: result,
            suggestedTitle: suggestedTitle,
            venue: venue,
            eventDateRange: eventDateRange,
            isExistingDuplicate: isDuplicate
        )
    }

    private var summaryItems: [String] {
        var values: [String] = []
        if result.ticketGuideKey != nil { values.append("購入先") }
        if result.purchaseURL != nil { values.append("購入URL") }
        if result.saleStartAt != nil { values.append("申込・発売開始") }
        if result.applyDeadlineAt != nil { values.append("抽選申込締切") }
        if result.resultAnnounceAt != nil { values.append("当落発表") }
        if result.paymentDeadlineAt != nil { values.append("支払締切") }
        if result.issueStartAt != nil { values.append("チケット受取開始") }
        if result.priceText != nil { values.append("チケット代") }
        if result.feeText != nil { values.append("手数料") }
        if result.seatText != nil { values.append("座席") }
        if result.quantity != nil { values.append("枚数") }
        if suggestedTitle?.isEmpty == false { values.append("タイトル") }
        if venue?.isEmpty == false { values.append("会場") }
        if eventDateRange != nil { values.append("日時") }
        return values
    }
}

struct TicketImportReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidates: [PendingTicketOCRImport]
    let onApply: ([PendingTicketOCRImport]) -> Void
    @State private var selectedIDs: Set<UUID>

    init(
        candidates: [PendingTicketOCRImport],
        onApply: @escaping ([PendingTicketOCRImport]) -> Void
    ) {
        self.candidates = candidates
        self.onApply = onApply
        _selectedIDs = State(initialValue: Set(
            candidates.filter { !$0.isExistingDuplicate }.map(\.id)
        ))
    }

    private var selectedCandidates: [PendingTicketOCRImport] {
        candidates.filter { selectedIDs.contains($0.id) && !$0.isExistingDuplicate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { candidate in
                        Button {
                            guard !candidate.isExistingDuplicate else { return }
                            if selectedIDs.contains(candidate.id) {
                                selectedIDs.remove(candidate.id)
                            } else {
                                selectedIDs.insert(candidate.id)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedIDs.contains(candidate.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        candidate.isExistingDuplicate
                                            ? Color.secondary
                                            : Color.accentColor
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.displayTitle)
                                        .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                                        .foregroundStyle(.primary)
                                    Text(candidate.scheduleSummary)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(candidate.isExistingDuplicate ? "登録済みのため除外します" : candidate.summary)
                                        .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                                        .foregroundStyle(
                                            candidate.isExistingDuplicate
                                                ? Color.orange
                                                : Color.secondary
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(candidate.isExistingDuplicate)
                    }
                } header: {
                    FavorecoRegistrationSectionHeader("読み取った内容")
                } footer: {
                    Text("内容を確認し、登録する候補だけを選んでください。登録済みと一致する候補は追加しません。")
                }
            }
            .navigationTitle("画像から入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedCandidates.count > 1
                           ? "\(selectedCandidates.count)件を反映"
                           : "反映") {
                        onApply(selectedCandidates)
                    }
                    .disabled(selectedCandidates.isEmpty)
                }
            }
        }
    }
}

enum TicketOCRImportParser {
    static func parse(text: String, referenceDate: Date) -> TicketOCRImportResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let contexts = lines + zip(lines, lines.dropFirst()).map { "\($0) \($1)" }

        return TicketOCRImportResult(
            ticketGuideKey: inferredTicketGuideKey(from: text),
            purchaseURL: firstMatch(
                in: text,
                pattern: #"https?://[^\s　]+"#
            ),
            saleStartAt: labeledDate(
                in: contexts,
                labels: ["抽選申込開始", "申込開始", "受付開始", "発売開始"],
                referenceDate: referenceDate
            ),
            applyDeadlineAt: labeledDate(
                in: contexts,
                labels: ["抽選申込締切", "申込締切", "受付終了", "応募締切"],
                referenceDate: referenceDate
            ),
            resultAnnounceAt: labeledDate(
                in: contexts,
                labels: ["当落発表", "抽選結果", "結果発表"],
                referenceDate: referenceDate
            ),
            paymentDeadlineAt: labeledDate(
                in: contexts,
                labels: ["入金締切", "支払締切", "支払期限", "入金期限"],
                referenceDate: referenceDate
            ),
            issueStartAt: labeledDate(
                in: contexts,
                labels: ["チケット受取開始", "受取開始", "発券開始", "表示開始"],
                referenceDate: referenceDate
            ),
            priceText: inferredPrice(from: lines),
            feeText: inferredFee(from: lines),
            seatText: inferredSeat(from: lines),
            quantity: inferredQuantity(from: lines)
        )
    }

    private static func inferredTicketGuideKey(from text: String) -> String? {
        let normalizedText = normalized(text)
        let aliases: [(String, [String])] = [
            ("pia", ["チケットぴあ", "t.pia.jp"]),
            ("eplus", ["イープラス", "eplus", "eplus.jp", "e+"]),
            ("lawson", ["ローソンチケット", "ローチケ", "l-tike"]),
            ("rakuten", ["楽天チケット", "ticket.rakuten"]),
            ("cnplayguide", ["cnプレイガイド", "cnplayguide"]),
            ("ticketboard", ["ticketboard", "tickebo"]),
            ("tixplus", ["tixplus"]),
            ("confetti", ["カンフェティ", "confetti"]),
            ("teket", ["teket"]),
            ("livepocket", ["livepocket"]),
            ("tiget", ["tiget"]),
            ("zaiko", ["zaiko"]),
            ("peatix", ["peatix"]),
            ("passmarket", ["passmarket"]),
        ]
        return aliases.first { _, values in
            values.contains { normalizedText.contains(normalized($0)) }
        }?.0
    }

    private static func labeledDate(
        in lines: [String],
        labels: [String],
        referenceDate: Date
    ) -> Date? {
        guard let line = lines.first(where: { line in
            let normalizedLine = normalized(line)
            return labels.contains { normalizedLine.contains(normalized($0)) }
        }) else {
            return nil
        }
        return parsedDate(in: line, referenceDate: referenceDate)
    }

    private static func parsedDate(in text: String, referenceDate: Date) -> Date? {
        let pattern = #"(?:(20\d{2})[年./-]\s*)?(\d{1,2})[月./-]\s*(\d{1,2})日?(?:[^0-9]{0,8}(\d{1,2})[:：](\d{2}))?"#
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) else {
            return nil
        }

        func integer(at index: Int) -> Int? {
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: text) else {
                return nil
            }
            return Int(text[swiftRange])
        }

        let calendar = Calendar.current
        let referenceYear = calendar.component(.year, from: referenceDate)
        let referenceMonth = calendar.component(.month, from: referenceDate)
        guard let month = integer(at: 2), let day = integer(at: 3) else {
            return nil
        }
        var year = integer(at: 1) ?? referenceYear
        if integer(at: 1) == nil, month + 6 < referenceMonth {
            year += 1
        }
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: integer(at: 4) ?? 0,
            minute: integer(at: 5) ?? 0
        ))
    }

    private static func inferredPrice(from lines: [String]) -> String? {
        let preferred = lines.filter { line in
            let value = normalized(line)
            return ["チケット代", "券面額", "料金", "合計"].contains {
                value.contains(normalized($0))
            } && !isFeeLine(line)
        }
        for line in preferred {
            if let amount = firstCapturedGroup(
                in: line,
                pattern: #"(?:[¥￥]\s*|)([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})\s*円?"#
            ) {
                return amount.replacingOccurrences(of: ",", with: "")
            }
        }
        for line in lines where !isFeeLine(line) {
            if let amount = firstCapturedGroup(
                in: line,
                pattern: #"(?:[¥￥]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})|([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})\s*円)"#
            ) {
                return amount.replacingOccurrences(of: ",", with: "")
            }
        }
        return nil
    }

    private static func inferredFee(from lines: [String]) -> String? {
        let totalLabels = ["手数料合計", "各種手数料"]
        let totalLines = lines.filter { line in
            totalLabels.contains { normalized(line).contains(normalized($0)) }
        }
        let candidates = totalLines + lines.filter {
            isFeeLine($0) && !totalLines.contains($0)
        }
        for line in candidates {
            if let amount = firstCapturedGroup(
                in: line,
                pattern: #"(?:[¥￥]\s*|)([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,6})\s*円?"#
            ) {
                return amount.replacingOccurrences(of: ",", with: "")
            }
        }
        return nil
    }

    private static func isFeeLine(_ line: String) -> Bool {
        [
            "手数料合計", "各種手数料", "システム利用料", "サービス料",
            "発券手数料", "決済手数料", "先行手数料", "手数料"
        ].contains { normalized(line).contains(normalized($0)) }
    }

    private static func inferredSeat(from lines: [String]) -> String? {
        let labels = ["座席番号", "座席", "席種", "整理番号"]
        for line in lines {
            if let label = labels.first(where: { normalized(line).contains(normalized($0)) }) {
                let value = line.replacingOccurrences(
                    of: label,
                    with: "",
                    options: [.caseInsensitive, .widthInsensitive]
                )
                .trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines.union(
                        CharacterSet(charactersIn: ":：-｜")
                    )
                )
                if !value.isEmpty {
                    return value
                }
            }
        }
        return lines.first {
            $0.range(of: #"\d+\s*列.*\d+\s*番"#, options: .regularExpression) != nil
        }
    }

    private static func inferredQuantity(from lines: [String]) -> Int? {
        for line in lines where normalized(line).contains("枚") {
            if let value = firstCapturedGroup(in: line, pattern: #"([0-9]{1,2})\s*枚"#),
               let quantity = Int(value),
               (1...20).contains(quantity) {
                return quantity
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ), let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,、。"))
    }

    private static func firstCapturedGroup(in text: String, pattern: String) -> String? {
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ), match.numberOfRanges > 1 else {
            return nil
        }
        for index in 1..<match.numberOfRanges {
            let capturedRange = match.range(at: index)
            guard capturedRange.location != NSNotFound,
                  let range = Range(capturedRange, in: text) else {
                continue
            }
            let value = String(text[range])
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func regularExpression(_ pattern: String) -> NSRegularExpression {
        // Patterns are static and controlled by this parser.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }
}
