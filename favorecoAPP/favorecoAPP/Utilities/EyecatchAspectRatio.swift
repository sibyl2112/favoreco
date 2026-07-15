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
        note: "日本の映画ポスター/B判に近い比率"
    )

    static let bSeriesPoster = EyecatchAspectRatio(
        key: "bSeriesPoster",
        name: "チラシ・ポスター",
        width: 1,
        height: 1.414,
        note: "観劇、美術展、博物展のチラシ向き"
    )

    static let bookCover = EyecatchAspectRatio(
        key: "bookCover",
        name: "書影",
        width: 1,
        height: 1.45,
        note: "書籍カバー向き"
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
        labelLandscape,
        goshuinStandard,
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
        if let option = all.first(where: { $0.key == key }) {
            return option
        }
        return recommended(for: category)
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
