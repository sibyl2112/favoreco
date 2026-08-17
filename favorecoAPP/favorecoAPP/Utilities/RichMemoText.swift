import Combine
import SwiftUI
import UIKit

nonisolated struct MemoStyleRun: Codable, Equatable, Sendable {
    var location: Int
    var length: Int
    var isBold: Bool = false
    var isUnderlined: Bool = false
    var colorKey: String = MemoTextColorKey.standard.rawValue

    var isEmpty: Bool {
        length <= 0 || (!isBold && !isUnderlined && colorKey == MemoTextColorKey.standard.rawValue)
    }
}

nonisolated enum MemoTextColorKey: String, CaseIterable, Identifiable, Sendable {
    case standard
    case accent
    case red
    case blue
    case green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "標準"
        case .accent: "テーマ色"
        case .red: "赤"
        case .blue: "青"
        case .green: "緑"
        }
    }

    @MainActor var swiftUIColor: Color {
        switch self {
        case .standard: .primary
        case .accent: Color(hex: "#B04464")
        case .red: Color(hex: "#B93645")
        case .blue: Color(hex: "#326B9A")
        case .green: Color(hex: "#34765D")
        }
    }

    var uiColor: UIColor {
        switch self {
        case .standard: .label
        case .accent: UIColor(red: 176 / 255, green: 68 / 255, blue: 100 / 255, alpha: 1)
        case .red: UIColor(red: 185 / 255, green: 54 / 255, blue: 69 / 255, alpha: 1)
        case .blue: UIColor(red: 50 / 255, green: 107 / 255, blue: 154 / 255, alpha: 1)
        case .green: UIColor(red: 52 / 255, green: 118 / 255, blue: 93 / 255, alpha: 1)
        }
    }

    static func resolved(_ rawValue: String) -> MemoTextColorKey {
        MemoTextColorKey(rawValue: rawValue) ?? .standard
    }

    static func key(for color: UIColor?) -> MemoTextColorKey {
        guard let color else { return .standard }
        return allCases.first(where: { $0.uiColor.isEqual(color) }) ?? .standard
    }
}

enum RichMemoText {
    static func makeAttributedString(
        text: String,
        runs: [MemoStyleRun],
        linkColor: Color = .accentColor
    ) -> AttributedString {
        var value = AttributedString(text)
        value.font = FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body)
        value.foregroundColor = .primary

        for run in normalized(runs, text: text) {
            guard let stringRange = stringRange(for: run, in: text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: value),
                  let upper = AttributedString.Index(stringRange.upperBound, within: value)
            else { continue }
            let range = lower..<upper
            if run.isBold {
                value[range].font = FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .body)
            }
            if run.isUnderlined {
                value[range].underlineStyle = .single
            }
            value[range].foregroundColor = MemoTextColorKey.resolved(run.colorKey).swiftUIColor
        }
        applyDetectedLinks(in: text, to: &value, linkColor: linkColor)
        return value
    }

    private static func applyDetectedLinks(
        in text: String,
        to value: inout AttributedString,
        linkColor: Color
    ) {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, options: [], range: fullRange) {
            guard let url = match.url,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let stringRange = Range(match.range, in: text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: value),
                  let upper = AttributedString.Index(stringRange.upperBound, within: value)
            else { continue }

            let range = lower..<upper
            value[range].link = url
            value[range].foregroundColor = linkColor
            value[range].underlineStyle = .single
        }
    }

    static func normalized(_ runs: [MemoStyleRun], text: String) -> [MemoStyleRun] {
        let count = (text as NSString).length
        return runs.compactMap { run in
            let location = min(max(run.location, 0), count)
            let length = min(max(run.length, 0), count - location)
            let normalized = MemoStyleRun(
                location: location,
                length: length,
                isBold: run.isBold,
                isUnderlined: run.isUnderlined,
                colorKey: MemoTextColorKey.resolved(run.colorKey).rawValue
            )
            return normalized.isEmpty ? nil : normalized
        }
    }

    private static func stringRange(for run: MemoStyleRun, in text: String) -> Range<String.Index>? {
        let nsRange = NSRange(location: run.location, length: run.length)
        return Range(nsRange, in: text)
    }
}

@MainActor
final class RichMemoFormattingController: ObservableObject {
    weak var textView: UITextView?
    var onFormattingChange: (() -> Void)?

    func toggleBold() {
        guard let textView else { return }
        applyFontTrait(.traitBold, in: textView)
    }

    func toggleUnderline() {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            let current = (textView.typingAttributes[.underlineStyle] as? Int) ?? 0
            textView.typingAttributes[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
        } else {
            let current = (textView.textStorage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int) ?? 0
            textView.textStorage.addAttribute(
                .underlineStyle,
                value: current == 0 ? NSUnderlineStyle.single.rawValue : 0,
                range: range
            )
        }
        onFormattingChange?()
    }

    func setColor(_ key: MemoTextColorKey) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            textView.typingAttributes[.foregroundColor] = key.uiColor
        } else {
            textView.textStorage.addAttribute(.foregroundColor, value: key.uiColor, range: range)
        }
        onFormattingChange?()
    }

    func toggleBullet() {
        guard let textView else { return }
        let storage = textView.textStorage
        let source = storage.string as NSString
        let selected = textView.selectedRange
        let paragraphRange = source.paragraphRange(for: selected)
        var lineStarts: [Int] = []
        var cursor = paragraphRange.location
        while cursor < NSMaxRange(paragraphRange) {
            lineStarts.append(cursor)
            let lineRange = source.lineRange(for: NSRange(location: cursor, length: 0))
            let next = NSMaxRange(lineRange)
            guard next > cursor else { break }
            cursor = next
        }

        let allBulleted = lineStarts.allSatisfy { start in
            start + 2 <= storage.length
                && (storage.string as NSString).substring(with: NSRange(location: start, length: 2)) == "• "
        }
        storage.beginEditing()
        for start in lineStarts.reversed() {
            if allBulleted {
                storage.deleteCharacters(in: NSRange(location: start, length: 2))
            } else {
                let attributes = start < storage.length ? storage.attributes(at: start, effectiveRange: nil) : textView.typingAttributes
                storage.insert(NSAttributedString(string: "• ", attributes: attributes), at: start)
            }
        }
        storage.endEditing()
        let selectionDelta = lineStarts.count * (allBulleted ? -2 : 2)
        let updatedLocation = min(max(selected.location + selectionDelta, 0), storage.length)
        textView.selectedRange = NSRange(
            location: updatedLocation,
            length: min(selected.length, storage.length - updatedLocation)
        )
        onFormattingChange?()
    }

    private func applyFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView) {
        let range = textView.selectedRange
        if range.length == 0 {
            let current = (textView.typingAttributes[.font] as? UIFont) ?? RichMemoTextView.baseFont
            textView.typingAttributes[.font] = toggledFont(current, trait: trait)
        } else {
            let storage = textView.textStorage
            let initialFont = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont) ?? RichMemoTextView.baseFont
            let shouldRemove = initialFont.fontDescriptor.symbolicTraits.contains(trait)
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = (value as? UIFont) ?? RichMemoTextView.baseFont
                let descriptor = shouldRemove
                    ? font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.subtracting(trait))
                    : font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(trait))
                storage.addAttribute(.font, value: UIFont(descriptor: descriptor ?? font.fontDescriptor, size: font.pointSize), range: subrange)
            }
        }
        onFormattingChange?()
    }

    private func toggledFont(_ font: UIFont, trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits
        let updated = traits.contains(trait) ? traits.subtracting(trait) : traits.union(trait)
        let descriptor = font.fontDescriptor.withSymbolicTraits(updated) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

struct RichMemoTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var styleRuns: [MemoStyleRun]
    let controller: RichMemoFormattingController
    @Binding var contentHeight: CGFloat

    static var baseFont: UIFont {
        let base = UIFont(name: "NotoSansJP-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, maximumPointSize: 18)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = Self.baseFont
        view.textColor = .label
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.keyboardDismissMode = .interactive
        view.accessibilityLabel = "メモ"
        controller.textView = view
        controller.onFormattingChange = { [weak coordinator = context.coordinator] in
            coordinator?.publishChanges()
        }
        context.coordinator.apply(text: text, runs: styleRuns, to: view)
        context.coordinator.reportHeight(of: view)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = uiView
        if uiView.text != text {
            context.coordinator.apply(text: text, runs: styleRuns, to: uiView)
        }
        context.coordinator.reportHeight(of: uiView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichMemoTextView
        private var isApplying = false

        init(parent: RichMemoTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplying else { return }
            publishChanges()
        }

        func reportHeight(of textView: UITextView) {
            let width = textView.bounds.width
            guard width > 0 else { return }
            let measured = ceil(
                textView.sizeThatFits(
                    CGSize(width: width, height: .greatestFiniteMagnitude)
                ).height
            )
            let resolved = max(190, measured)
            guard abs(parent.contentHeight - resolved) > 0.5 else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, abs(self.parent.contentHeight - resolved) > 0.5 else { return }
                self.parent.contentHeight = resolved
            }
        }

        func publishChanges() {
            guard let textView = parent.controller.textView else { return }
            parent.text = textView.text
            parent.styleRuns = Self.extractRuns(from: textView.attributedText)
            reportHeight(of: textView)
        }

        func apply(text: String, runs: [MemoStyleRun], to textView: UITextView) {
            isApplying = true
            defer { isApplying = false }
            let selectedRange = textView.selectedRange
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: RichMemoTextView.baseFont,
                    .foregroundColor: UIColor.label,
                ]
            )
            for run in RichMemoText.normalized(runs, text: text) {
                let range = NSRange(location: run.location, length: run.length)
                if run.isBold {
                    let bold = UIFont(name: "NotoSansJP-Bold", size: RichMemoTextView.baseFont.pointSize)
                        ?? UIFont.boldSystemFont(ofSize: RichMemoTextView.baseFont.pointSize)
                    attributed.addAttribute(.font, value: bold, range: range)
                }
                if run.isUnderlined {
                    attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
                attributed.addAttribute(
                    .foregroundColor,
                    value: MemoTextColorKey.resolved(run.colorKey).uiColor,
                    range: range
                )
            }
            textView.attributedText = attributed
            textView.selectedRange = NSRange(
                location: min(selectedRange.location, attributed.length),
                length: min(selectedRange.length, max(attributed.length - selectedRange.location, 0))
            )
        }

        private static func extractRuns(from attributed: NSAttributedString) -> [MemoStyleRun] {
            guard attributed.length > 0 else { return [] }
            var results: [MemoStyleRun] = []
            var location = 0
            while location < attributed.length {
                var effectiveRange = NSRange(location: 0, length: 0)
                let attributes = attributed.attributes(at: location, effectiveRange: &effectiveRange)
                let font = (attributes[.font] as? UIFont) ?? RichMemoTextView.baseFont
                let underline = ((attributes[.underlineStyle] as? Int) ?? 0) != 0
                let colorKey = MemoTextColorKey.key(for: attributes[.foregroundColor] as? UIColor)
                let run = MemoStyleRun(
                    location: effectiveRange.location,
                    length: effectiveRange.length,
                    isBold: font.fontDescriptor.symbolicTraits.contains(.traitBold)
                        || font.fontName.localizedCaseInsensitiveContains("bold"),
                    isUnderlined: underline,
                    colorKey: colorKey.rawValue
                )
                if !run.isEmpty { results.append(run) }
                location = NSMaxRange(effectiveRange)
            }
            return results
        }
    }
}
