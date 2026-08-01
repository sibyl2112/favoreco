import Foundation
import ImageIO
import UIKit
import Vision

struct QuickCaptureOCRResult: Sendable {
    let fullText: String
    let lines: [String]
    let titleCandidates: [String]
    let suggestedTitle: String
    let isTitleSuggestionReliable: Bool
    let venueCandidates: [String]
    let eventDateRange: QuickCaptureDateRange?

    nonisolated static var empty: QuickCaptureOCRResult {
        QuickCaptureOCRResult(
            fullText: "",
            lines: [],
            titleCandidates: [],
            suggestedTitle: "",
            isTitleSuggestionReliable: false,
            venueCandidates: [],
            eventDateRange: nil
        )
    }
}

struct QuickCaptureDateRange: Sendable {
    let startsAt: Date
    let endsAt: Date
}

enum QuickCaptureImageService {
    nonisolated static func inferredFieldsForTesting(
        lines: [(text: String, width: Double, height: Double)],
        referenceDate: Date
    ) -> (
        titleCandidates: [String],
        venueCandidates: [String],
        eventDateRange: QuickCaptureDateRange?
    ) {
        let recognized = lines.enumerated().map { index, line in
            RecognizedLine(
                text: line.text,
                confidence: 0.9,
                width: line.width,
                height: line.height,
                order: index,
                alternatives: [
                    RecognizedAlternative(text: line.text, confidence: 0.9)
                ]
            )
        }
        let ranking = rankedTitleCandidates(from: recognized)
        return (
            inferredTitleCandidates(
                from: recognized,
                ranking: ranking,
                isReliable: false
            ),
            inferredVenueCandidates(from: recognized),
            inferredEventDateRange(from: recognized, referenceDate: referenceDate)
        )
    }

    nonisolated static func compressedJPEG(from data: Data) -> Data? {
        compressedJPEG(from: data, centeredToAspectRatio: nil)
    }

    nonisolated static func compressedJPEG(
        from data: Data,
        centeredToAspectRatio targetAspectRatio: CGFloat?
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let decoded = UIImage(cgImage: image)
        guard let targetAspectRatio, targetAspectRatio > 0 else {
            return decoded.jpegData(compressionQuality: 0.85)
        }

        let sourceSize = decoded.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let sourceAspectRatio = sourceSize.width / sourceSize.height
        let cropRect: CGRect
        if sourceAspectRatio > targetAspectRatio {
            let cropWidth = sourceSize.height * targetAspectRatio
            cropRect = CGRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        } else {
            let cropHeight = sourceSize.width / targetAspectRatio
            cropRect = CGRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            decoded.draw(
                in: CGRect(
                    x: -cropRect.minX,
                    y: -cropRect.minY,
                    width: sourceSize.width,
                    height: sourceSize.height
                )
            )
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    nonisolated static func recognizedText(from data: Data) -> String {
        recognizedTextAnalysis(from: data).fullText
    }

    nonisolated static func recognizedTextAnalysis(from data: Data) -> QuickCaptureOCRResult {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return .empty }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let recognizedLines = observations.enumerated().compactMap { index, observation -> RecognizedLine? in
                let candidates = observation.topCandidates(5)
                guard let candidate = candidates.first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                let alternatives = candidates.compactMap { candidate -> RecognizedAlternative? in
                    let alternativeText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !alternativeText.isEmpty else { return nil }
                    return RecognizedAlternative(text: alternativeText, confidence: candidate.confidence)
                }
                return RecognizedLine(
                    text: text,
                    confidence: candidate.confidence,
                    width: Double(observation.boundingBox.width),
                    height: Double(observation.boundingBox.height),
                    order: index,
                    alternatives: alternatives
                )
            }
            guard !recognizedLines.isEmpty else { return .empty }

            let titleRanking = rankedTitleCandidates(from: recognizedLines)
            let isReliable = isReliableTitleSuggestion(titleRanking)
            let titleCandidates = inferredTitleCandidates(
                from: recognizedLines,
                ranking: titleRanking,
                isReliable: isReliable
            )
            let suggestedTitle = titleCandidates.first ?? titleRanking.first?.line.text ?? ""
            let titleAlternatives = titleRanking.first?.line.alternatives.map(\.text) ?? []

            return QuickCaptureOCRResult(
                fullText: recognizedLines.map(\.text).joined(separator: "\n"),
                lines: uniqueLines(titleAlternatives + recognizedLines.map(\.text)),
                titleCandidates: titleCandidates,
                suggestedTitle: suggestedTitle,
                isTitleSuggestionReliable: isReliable,
                venueCandidates: inferredVenueCandidates(from: recognizedLines),
                eventDateRange: inferredEventDateRange(from: recognizedLines)
            )
        } catch {
            return .empty
        }
    }

    private nonisolated static func rankedTitleCandidates(
        from lines: [RecognizedLine]
    ) -> [ScoredRecognizedLine] {
        lines
            .filter { !isLikelyMetadata($0.text) }
            .map { line in
                let area = line.width * line.height
                let visualProminence = (line.height * 0.72) + (sqrt(area) * 0.28)
                let confidenceFactor = 0.72 + (Double(line.confidence) * 0.28)
                let lengthFactor: Double
                switch line.text.count {
                case 0...24: lengthFactor = 1
                case 25...40: lengthFactor = 0.78
                default: lengthFactor = 0.56
                }
                return ScoredRecognizedLine(
                    line: line,
                    score: visualProminence * confidenceFactor * lengthFactor
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.line.confidence > rhs.line.confidence
                }
                return lhs.score > rhs.score
            }
    }

    private nonisolated static func isReliableTitleSuggestion(
        _ ranking: [ScoredRecognizedLine]
    ) -> Bool {
        guard let first = ranking.first,
              first.line.confidence >= 0.45,
              first.line.height >= 0.035,
              hasUnambiguousRecognition(first.line) else {
            return false
        }
        guard ranking.count > 1 else { return true }

        let second = ranking[1]
        return first.score >= second.score * 1.35
            || first.line.height >= second.line.height * 1.55
    }

    private nonisolated static func inferredTitleCandidates(
        from lines: [RecognizedLine],
        ranking: [ScoredRecognizedLine],
        isReliable: Bool
    ) -> [String] {
        guard let first = ranking.first else { return [] }
        if isReliable {
            return uniqueLines([first.line.text] + first.line.alternatives.map(\.text))
        }

        let prominent = ranking
            .filter {
                $0.score >= first.score * 0.42
                    && $0.line.width >= 0.1
                    && $0.line.text.count <= 24
                    && !isLikelyVenueOrDate($0.line.text)
            }
            .prefix(6)
            .map(\.line)
        let prominentOrders = Set(prominent.map(\.order))
        let pieces = lines
            .filter { prominentOrders.contains($0.order) }
            .sorted { $0.order < $1.order }
            .map(\.text)

        var candidates: [String] = []
        if pieces.count >= 2 {
            let leading = pieces.dropLast().joined()
            let trailing = pieces.last ?? ""
            candidates.append("\(leading)　\(trailing)")
            candidates.append(pieces.joined())
        }
        candidates.append(contentsOf: ranking.prefix(8).map(\.line.text))
        return uniqueLines(candidates)
    }

    private nonisolated static func inferredVenueCandidates(
        from lines: [RecognizedLine]
    ) -> [String] {
        let labels = ["会場", "劇場", "場所"]
        var candidates: [String] = []

        for (index, line) in lines.enumerated() {
            let compact = line.text.replacingOccurrences(of: " ", with: "")
            if let label = labels.first(where: { compact.hasPrefix($0) }) {
                let value = String(compact.dropFirst(label.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "：:｜|・ "))
                if !value.isEmpty {
                    candidates.append(value)
                } else if lines.indices.contains(index + 1) {
                    candidates.append(lines[index + 1].text)
                }
            } else if isLikelyVenueName(compact) {
                candidates.append(line.text)
            }
        }
        return uniqueLines(candidates)
    }

    private nonisolated static func inferredEventDateRange(
        from lines: [RecognizedLine],
        referenceDate: Date = Date()
    ) -> QuickCaptureDateRange? {
        let dateLabels = ["開催日時", "開催期間", "会期", "日程", "公演期間"]
        let candidateTexts = lines.enumerated().compactMap { index, line -> String? in
            let compact = line.text.replacingOccurrences(of: " ", with: "")
            guard dateLabels.contains(where: { compact.contains($0) }) else { return nil }
            if lines.indices.contains(index + 1) {
                return "\(line.text) \(lines[index + 1].text)"
            }
            return line.text
        }
        let text = candidateTexts.joined(separator: " ")
        guard !text.isEmpty else { return nil }

        let pattern = #"(?:(\d{1,2})月)?\s*(\d{1,2})日"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )

        var currentMonth: Int?
        var components: [(month: Int, day: Int)] = []
        for match in matches {
            if match.range(at: 1).location != NSNotFound,
               let range = Range(match.range(at: 1), in: text) {
                currentMonth = Int(text[range])
            }
            guard let month = currentMonth,
                  let dayRange = Range(match.range(at: 2), in: text),
                  let day = Int(text[dayRange]) else { continue }
            components.append((month, day))
        }
        guard !components.isEmpty else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let referenceYear = calendar.component(.year, from: referenceDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let firstThisYear = calendar.date(
            from: DateComponents(
                calendar: calendar,
                year: referenceYear,
                month: components[0].month,
                day: components[0].day
            )
        )
        let year = if let firstThisYear,
                      let rolloverThreshold = calendar.date(byAdding: .month, value: -6, to: referenceDay),
                      firstThisYear < rolloverThreshold {
            referenceYear + 1
        } else {
            referenceYear
        }
        let dates = components.compactMap {
            calendar.date(
                from: DateComponents(
                    calendar: calendar,
                    year: year,
                    month: $0.month,
                    day: $0.day
                )
            )
        }
        guard let start = dates.min(), let end = dates.max() else { return nil }
        return QuickCaptureDateRange(startsAt: start, endsAt: end)
    }

    private nonisolated static func isLikelyVenueOrDate(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        return ["会場", "劇場", "場所", "開催日時", "開催期間", "会期", "日程"]
            .contains { compact.hasPrefix($0) }
            || inferredDateTokenExists(in: compact)
    }

    private nonisolated static func inferredDateTokenExists(in text: String) -> Bool {
        text.range(of: #"\d{1,2}月\s*\d{1,2}日"#, options: .regularExpression) != nil
    }

    private nonisolated static func isLikelyVenueName(_ text: String) -> Bool {
        let suffixes = [
            "劇場", "ホール", "会館", "ドーム", "アリーナ", "スタジアム",
            "中学校", "高等学校", "大学", "文化センター"
        ]
        return suffixes.contains { text.hasSuffix($0) }
    }

    private nonisolated static func hasUnambiguousRecognition(_ line: RecognizedLine) -> Bool {
        guard line.alternatives.count > 1 else { return true }
        let secondConfidence = line.alternatives[1].confidence
        return line.confidence - secondConfidence >= 0.12
    }

    private nonisolated static func isLikelyMetadata(_ text: String) -> Bool {
        let normalized = text.lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.hasPrefix("www.") {
            return true
        }

        let digits = text.filter(\.isNumber).count
        let letters = text.filter { $0.isLetter }.count
        let punctuation = text.filter { "./:-〜~→".contains($0) }.count
        return letters == 0 && digits > 0 && punctuation > 0
    }

    private nonisolated static func uniqueLines(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.filter { line in
            let key = line.folding(
                options: [.caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            return seen.insert(key).inserted
        }
    }
}

private struct RecognizedLine: Sendable {
    let text: String
    let confidence: Float
    let width: Double
    let height: Double
    let order: Int
    let alternatives: [RecognizedAlternative]
}

private struct RecognizedAlternative: Sendable {
    let text: String
    let confidence: Float
}

private struct ScoredRecognizedLine: Sendable {
    let line: RecognizedLine
    let score: Double
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
