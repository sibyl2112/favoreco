import Foundation
import ImageIO
import UIKit
import Vision

struct QuickCaptureOCRResult: Sendable {
    let fullText: String
    let lines: [String]
    let suggestedTitle: String
    let isTitleSuggestionReliable: Bool

    nonisolated static var empty: QuickCaptureOCRResult {
        QuickCaptureOCRResult(
            fullText: "",
            lines: [],
            suggestedTitle: "",
            isTitleSuggestionReliable: false
        )
    }
}

enum QuickCaptureImageService {
    nonisolated static func compressedJPEG(from data: Data) -> Data? {
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
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
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
            let recognizedLines = observations.compactMap { observation -> RecognizedLine? in
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
                    alternatives: alternatives
                )
            }
            guard !recognizedLines.isEmpty else { return .empty }

            let titleRanking = rankedTitleCandidates(from: recognizedLines)
            let suggestedTitle = titleRanking.first?.line.text ?? ""
            let isReliable = isReliableTitleSuggestion(titleRanking)
            let titleAlternatives = titleRanking.first?.line.alternatives.map(\.text) ?? []

            return QuickCaptureOCRResult(
                fullText: recognizedLines.map(\.text).joined(separator: "\n"),
                lines: uniqueLines(titleAlternatives + recognizedLines.map(\.text)),
                suggestedTitle: suggestedTitle,
                isTitleSuggestionReliable: isReliable
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
