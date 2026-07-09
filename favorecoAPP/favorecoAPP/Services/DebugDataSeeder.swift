//
//  DebugDataSeeder.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation
import SwiftData
import UIKit

enum DebugDataSeeder {
    private static let debugURLPrefix = "https://example.com/favoreco/"

    @MainActor
    static func insertSampleData(in context: ModelContext) throws {
        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: context)
        try deleteSampleData(in: context)

        let categoryDescriptor = FetchDescriptor<RecordCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try context.fetch(categoryDescriptor)
        let now = Date()

        for (index, category) in categories.enumerated() {
            let samplePath = "debug/sample-\(category.templateKey).png"
            let imageData = samplePNGData(for: category)

            category.isArchived = false
            category.updatedAt = now

            let event = ExperienceEvent(
                title: sampleTitle(for: category),
                seriesName: sampleSeries(for: category),
                representativeEyecatchPath: samplePath,
                officialURL: "\(debugURLPrefix)\(category.templateKey)",
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
                eyecatchPath: samplePath,
                note: "写真付きサンプル記録。あとで本物の写真/チケット/OCRユニットに差し替える前提の確認用です。",
                createdAt: now,
                updatedAt: now,
                event: event
            )
            let photo = PhotoBlob(
                relativePath: samplePath,
                originalFilename: "sample-\(category.templateKey).png",
                mediaKind: "photo",
                purpose: "memory",
                byteCount: imageData.count,
                width: 256,
                height: 256,
                createdAt: now,
                data: imageData,
                visit: visit
            )

            context.insert(event)
            context.insert(visit)
            context.insert(photo)
        }

        if let firstCategory = categories.first {
            context.insert(InboxItem(
                title: "あとで記録する候補",
                body: "デバッグ用のInboxItemです。本記録への変換導線を確認できます。",
                sourceURL: "\(debugURLPrefix)inbox",
                targetTemplateKey: firstCategory.templateKey,
                createdAt: now,
                updatedAt: now
            ))
        }

        try context.save()
    }

    @MainActor
    static func deleteSampleData(in context: ModelContext) throws {
        let eventDescriptor = FetchDescriptor<ExperienceEvent>()
        let events = try context.fetch(eventDescriptor)
        for event in events where event.officialURL.hasPrefix(debugURLPrefix) {
            context.delete(event)
        }

        let inboxDescriptor = FetchDescriptor<InboxItem>()
        let inboxItems = try context.fetch(inboxDescriptor)
        for item in inboxItems where item.sourceURL.hasPrefix(debugURLPrefix) {
            context.delete(item)
        }

        let photoDescriptor = FetchDescriptor<PhotoBlob>()
        let photos = try context.fetch(photoDescriptor)
        for photo in photos where photo.relativePath.hasPrefix("debug/sample-") {
            context.delete(photo)
        }

        try context.save()
    }

    private static func samplePNGData(for category: RecordCategory) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
        let color = UIColor(hexString: category.colorHex)
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))

            UIColor.white.withAlphaComponent(0.18).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 46, y: 42, width: 164, height: 164))

            let text = String(category.name.prefix(2))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (256 - textSize.width) / 2, y: (256 - textSize.height) / 2),
                withAttributes: attributes
            )
        }
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

private extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
