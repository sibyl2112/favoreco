//
//  CategoryRecordTemplate.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation

extension RecordCategory {
    var usesOpeningTime: Bool {
        templateKey == "theater" || templateKey == "live"
    }
}

extension Plan {
    var usesOpeningTime: Bool {
        category?.usesOpeningTime == true
    }

    var calendarStartsAt: Date {
        guard usesOpeningTime, opensAt != Date.distantPast else { return startsAt }
        return opensAt
    }
}

struct CategoryRecordTemplate {
    let targetSectionTitle: String
    let titlePlaceholder: String
    let seriesPlaceholder: String
    let visitSectionTitle: String
    let dateLabel: String
    let venuePlaceholder: String
    let ratingLabel: String
    let memoSectionTitle: String
    let memoPlaceholder: String

    static func template(for category: RecordCategory?) -> CategoryRecordTemplate {
        if let category,
           category.isBuiltIn == false,
           !category.targetNameLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !category.dateLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let targetName = category.targetNameLabel
            let recordUnit = category.recordUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "回" : category.recordUnitName
            return CategoryRecordTemplate(
                targetSectionTitle: targetName,
                titlePlaceholder: "\(targetName)名",
                seriesPlaceholder: "シリーズ・分類（任意）",
                visitSectionTitle: "\(recordUnit)の記録",
                dateLabel: category.dateLabel,
                venuePlaceholder: "場所（任意）",
                ratingLabel: "評価",
                memoSectionTitle: "\(category.name)メモ",
                memoPlaceholder: "残しておきたいこと"
            )
        }

        switch category?.templateKey {
        case "theater":
            return CategoryRecordTemplate(
                targetSectionTitle: "作品・公演",
                titlePlaceholder: "作品名・公演名",
                seriesPlaceholder: "劇団・シリーズ・ツアー名（任意）",
                visitSectionTitle: "観劇した回",
                dateLabel: "観劇日",
                venuePlaceholder: "劇場・会場（任意）",
                ratingLabel: "満足度",
                memoSectionTitle: "観劇メモ",
                memoPlaceholder: "席、印象に残った場面、余韻など"
            )
        case "museum":
            return CategoryRecordTemplate(
                targetSectionTitle: "展示",
                titlePlaceholder: "展覧会名・展示名",
                seriesPlaceholder: "美術館・企画シリーズ（任意）",
                visitSectionTitle: "訪問した回",
                dateLabel: "訪問日",
                venuePlaceholder: "美術館・博物館・ギャラリー（任意）",
                ratingLabel: "満足度",
                memoSectionTitle: "鑑賞メモ",
                memoPlaceholder: "好きだった作品、展示室、混雑感など"
            )
        case "live":
            return CategoryRecordTemplate(
                targetSectionTitle: "ライブ",
                titlePlaceholder: "アーティスト・公演名",
                seriesPlaceholder: "ツアー名（任意）",
                visitSectionTitle: "参戦した回",
                dateLabel: "参戦日",
                venuePlaceholder: "会場（任意）",
                ratingLabel: "熱量",
                memoSectionTitle: "ライブメモ",
                memoPlaceholder: "セトリ、MC、席、会場の空気など"
            )
        case "movie":
            return CategoryRecordTemplate(
                targetSectionTitle: "映画",
                titlePlaceholder: "映画タイトル",
                seriesPlaceholder: "シリーズ・上映企画（任意）",
                visitSectionTitle: "鑑賞した回",
                dateLabel: "鑑賞日",
                venuePlaceholder: "映画館・スクリーン（任意）",
                ratingLabel: "評価",
                memoSectionTitle: "映画メモ",
                memoPlaceholder: "印象に残った場面、音響、上映形式など"
            )
        case "sake":
            return CategoryRecordTemplate(
                targetSectionTitle: "お酒",
                titlePlaceholder: "銘柄・商品名",
                seriesPlaceholder: "蔵元・シリーズ（任意）",
                visitSectionTitle: "飲んだ回",
                dateLabel: "飲んだ日",
                venuePlaceholder: "店・家・イベント（任意）",
                ratingLabel: "好み",
                memoSectionTitle: "味わいメモ",
                memoPlaceholder: "香り、甘辛、合わせた料理、また飲みたいか"
            )
        case "outing_facility":
            return CategoryRecordTemplate(
                targetSectionTitle: "施設",
                titlePlaceholder: "施設名・イベント名",
                seriesPlaceholder: "エリア・企画名（任意）",
                visitSectionTitle: "行った回",
                dateLabel: "訪問日",
                venuePlaceholder: "場所・施設（任意）",
                ratingLabel: "満足度",
                memoSectionTitle: "おでかけメモ",
                memoPlaceholder: "回った場所、混雑、また行きたいポイントなど"
            )
        case "goshuin":
            return CategoryRecordTemplate(
                targetSectionTitle: "参拝先",
                titlePlaceholder: "寺社・城・船など",
                seriesPlaceholder: "御朱印種別・巡礼名（任意）",
                visitSectionTitle: "いただいた回",
                dateLabel: "参拝日",
                venuePlaceholder: "所在地・授与所（任意）",
                ratingLabel: "思い出度",
                memoSectionTitle: "御朱印メモ",
                memoPlaceholder: "印の種類、授与所、参拝時のことなど"
            )
        case "book":
            return CategoryRecordTemplate(
                targetSectionTitle: "本",
                titlePlaceholder: "書名",
                seriesPlaceholder: "シリーズ・巻数・著者（任意）",
                visitSectionTitle: "読んだ記録",
                dateLabel: "読了日",
                venuePlaceholder: "購入店・読んだ場所（任意）",
                ratingLabel: "評価",
                memoSectionTitle: "読書メモ",
                memoPlaceholder: "好きな章、引用したい言葉、読み返したい理由など"
            )
        default:
            return CategoryRecordTemplate(
                targetSectionTitle: "対象",
                titlePlaceholder: "タイトル",
                seriesPlaceholder: "シリーズ・ツアー名（任意）",
                visitSectionTitle: "この回",
                dateLabel: "日付",
                venuePlaceholder: "場所（任意）",
                ratingLabel: "評価",
                memoSectionTitle: "メモ",
                memoPlaceholder: "残しておきたいこと"
            )
        }
    }
}
