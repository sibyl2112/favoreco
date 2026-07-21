//
//  EyecatchAspectRatio.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation

struct EyecatchAspectRatio: Identifiable, Hashable, Codable {
    let key: String
    let name: String
    let width: Double
    let height: Double
    let note: String

    var id: String { key }
    var value: Double { width / height }
    var displayValue: String { "\(format(width)):\(format(height))" }

    static let square = EyecatchAspectRatio(
        key: "square",
        name: "正方形",
        width: 1,
        height: 1,
        note: "汎用の記録カード向き"
    )

    static let cinemaPoster = EyecatchAspectRatio(
        key: "cinemaPoster",
        name: "映画ポスター",
        width: 1,
        height: 1.414,
        note: "映画ポスター/B判系の共通比率"
    )

    static let bSeriesPoster = EyecatchAspectRatio(
        key: "bSeriesPoster",
        name: "チラシ・ポスター",
        width: 1,
        height: 1.414,
        note: "観劇、ミュージアムの展示・イベントチラシ向き"
    )

    static let bookCover = EyecatchAspectRatio(
        key: "bookCover",
        name: "未設定（従来）",
        width: 1,
        height: 1.45,
        note: "既存の書籍で使う従来比率"
    )

    static let comicBook = EyecatchAspectRatio(
        key: "bookComic112x174",
        name: "コミック",
        width: 112,
        height: 174,
        note: "W112mm × H174mm"
    )

    static let shinshoBook = EyecatchAspectRatio(
        key: "bookShinsho103x182",
        name: "新書",
        width: 103,
        height: 182,
        note: "W103mm × H182mm"
    )

    static let hardcoverBook = EyecatchAspectRatio(
        key: "bookHardcover127x188",
        name: "ハードカバー",
        width: 127,
        height: 188,
        note: "W127mm × H188mm"
    )

    static let paperbackBook = EyecatchAspectRatio(
        key: "bookPaperback105x148",
        name: "文庫",
        width: 105,
        height: 148,
        note: "W105mm × H148mm"
    )

    static let magazineBook = EyecatchAspectRatio(
        key: "bookMagazine182x257",
        name: "雑誌",
        width: 182,
        height: 257,
        note: "W182mm × H257mm"
    )

    static let artBook = EyecatchAspectRatio(
        key: "bookArt210x297",
        name: "写真集・画集",
        width: 210,
        height: 297,
        note: "W210mm × H297mm"
    )

    static let labelLandscape = EyecatchAspectRatio(
        key: "labelLandscape",
        name: "横長ラベル",
        width: 4,
        height: 3,
        note: "酒ラベル、施設写真、記録写真向き"
    )

    static let goshuinStandard = EyecatchAspectRatio(
        key: "goshuinStandard",
        name: "御朱印帳 標準",
        width: 11,
        height: 16,
        note: "一般的な御朱印帳ページ向き"
    )

    static let all: [EyecatchAspectRatio] = [
        square,
        cinemaPoster,
        bSeriesPoster,
        bookCover,
        comicBook,
        shinshoBook,
        hardcoverBook,
        paperbackBook,
        magazineBook,
        artBook,
        labelLandscape,
        goshuinStandard,
    ]

    static let selectableBookFormats: [EyecatchAspectRatio] = [
        comicBook,
        shinshoBook,
        hardcoverBook,
        paperbackBook,
        magazineBook,
        artBook,
    ]

    static func recommended(for category: RecordCategory?) -> EyecatchAspectRatio {
        switch category?.templateKey {
        case "movie":
            return cinemaPoster
        case "theater", "museum":
            return bSeriesPoster
        case "book":
            return bookCover
        case "goshuin":
            return goshuinStandard
        case "sake", "outing_facility":
            return labelLandscape
        default:
            return square
        }
    }

    static func option(for key: String, category: RecordCategory? = nil) -> EyecatchAspectRatio {
        if usesPosterFill(for: category) {
            return recommended(for: category)
        }
        if let option = all.first(where: { $0.key == key }) {
            return option
        }
        return recommended(for: category)
    }

    static func resolved(for event: ExperienceEvent?) -> EyecatchAspectRatio {
        guard let event else { return bookCover }
        let category = event.category
        guard category?.templateKey == "book" else { return recommended(for: category) }

        let eventKey = VisitUnitFields(rawValue: event.unitFieldsRaw).eyecatchAspectRatioKey
        if !eventKey.isEmpty {
            return option(for: eventKey, category: category)
        }

        let latestVisitKey = (event.visits ?? [])
            .max(by: { $0.visitedAt < $1.visitedAt })
            .map { VisitUnitFields(rawValue: $0.unitFieldsRaw).eyecatchAspectRatioKey } ?? ""
        return option(for: latestVisitKey, category: category)
    }

    static func usesPosterFill(for category: RecordCategory?) -> Bool {
        category?.templateKey == "movie" || category?.templateKey == "theater"
    }

    static func usesEyecatchFill(for category: RecordCategory?) -> Bool {
        category != nil
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.3g", value)
    }
}

struct GoshuinBookSize: Identifiable, Hashable, Codable {
    let key: String
    let name: String
    let widthCentimeters: Double
    let heightCentimeters: Double
    let note: String

    var id: String { key }
    var aspectRatio: Double { widthCentimeters / heightCentimeters }
    var displaySize: String {
        "\(format(widthCentimeters)) x \(format(heightCentimeters))cm"
    }

    static let standard = GoshuinBookSize(
        key: "standard_11x16",
        name: "標準",
        widthCentimeters: 11,
        heightCentimeters: 16,
        note: "一般的な御朱印帳"
    )

    static let large = GoshuinBookSize(
        key: "large_12x18",
        name: "大判",
        widthCentimeters: 12,
        heightCentimeters: 18,
        note: "大きめの御朱印帳"
    )

    static let wide = GoshuinBookSize(
        key: "wide_18x12",
        name: "見開き・横向き",
        widthCentimeters: 18,
        heightCentimeters: 12,
        note: "見開きや横向きの記録"
    )

    static let all: [GoshuinBookSize] = [standard, large, wide]

    static func option(for key: String) -> GoshuinBookSize {
        all.first(where: { $0.key == key }) ?? standard
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.3g", value)
    }
}
