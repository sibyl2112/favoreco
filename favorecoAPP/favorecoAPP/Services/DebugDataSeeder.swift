//
//  DebugDataSeeder.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation
import SwiftData

enum DebugDataSeeder {
    @MainActor
    static func insertSampleData(in context: ModelContext) throws {
        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: context)

        let categoryDescriptor = FetchDescriptor<RecordCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try context.fetch(categoryDescriptor)
        let activeCategories = categories.filter { !$0.isArchived }
        let now = Date()

        for (index, category) in activeCategories.prefix(4).enumerated() {
            let event = ExperienceEvent(
                title: sampleTitle(for: category),
                seriesName: sampleSeries(for: category),
                officialURL: "https://example.com/favoreco/\(category.templateKey)",
                memo: "デバッグ用の仮データです。カテゴリ別の表示と編集導線を確認するために作成しました。",
                createdAt: now.addingTimeInterval(TimeInterval(-index * 86400)),
                updatedAt: now,
                category: category
            )
            let visit = Visit(
                visitedAt: now.addingTimeInterval(TimeInterval(-index * 86400)),
                endedAt: now.addingTimeInterval(TimeInterval(-index * 86400)),
                venueNameSnapshot: sampleVenue(for: category),
                overallRating: Double(4 - min(index, 2)) + 0.5,
                eyecatchPath: "debug/sample-\(category.templateKey).png",
                note: "写真付きサンプル記録。あとで本物の写真/チケット/OCRユニットに差し替える前提の確認用です。",
                createdAt: now,
                updatedAt: now,
                event: event
            )
            let photo = PhotoBlob(
                relativePath: "debug/sample-\(category.templateKey).png",
                originalFilename: "sample-\(category.templateKey).png",
                mediaKind: "photo",
                purpose: "memory",
                byteCount: samplePNGData.count,
                width: 1,
                height: 1,
                createdAt: now,
                data: samplePNGData,
                visit: visit
            )

            context.insert(event)
            context.insert(visit)
            context.insert(photo)
        }

        if let firstCategory = activeCategories.first {
            context.insert(InboxItem(
                title: "あとで記録する候補",
                body: "デバッグ用のInboxItemです。本記録への変換導線を確認できます。",
                sourceURL: "https://example.com/favoreco/inbox",
                targetTemplateKey: firstCategory.templateKey,
                createdAt: now,
                updatedAt: now
            ))
        }

        try context.save()
    }

    private static var samplePNGData: Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=") ?? Data()
    }

    private static func sampleTitle(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "雨の日のシネマ"
        case "theater": return "夜明けの劇場"
        case "book": return "小さな旅の記録"
        case "sake": return "純米吟醸 霞"
        case "museum": return "光の断片展"
        case "live": return "夏のライブツアー"
        case "outing_facility": return "海辺の水族館"
        case "goshuin": return "青葉神社"
        default: return "\(category.name)のサンプル"
        }
    }

    private static func sampleSeries(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "book": return "旅の本棚"
        case "movie": return "週末映画"
        case "sake": return "試飲メモ"
        default: return ""
        }
    }

    private static func sampleVenue(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "favorecoシネマ"
        case "theater": return "favoreco劇場"
        case "museum": return "favoreco美術館"
        case "live": return "favorecoホール"
        case "sake": return "自宅"
        case "outing_facility": return "favorecoパーク"
        case "goshuin": return "favoreco神社"
        case "book": return "読書メモ"
        default: return "favoreco"
        }
    }
}
