//
//  RecordUnitDefinition.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation

struct RecordUnitDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let isRequired: Bool

    static let all: [RecordUnitDefinition] = [
        RecordUnitDefinition(id: "basic", name: "基本情報", description: "対象名、日付、場所、種別、評価など", isRequired: true),
        RecordUnitDefinition(id: "people", name: "人物・団体", description: "出演者、作家、作者、主催、制作など", isRequired: false),
        RecordUnitDefinition(id: "ticketPlan", name: "チケット・予定", description: "チケット、座席、申込、発券、予定管理", isRequired: false),
        RecordUnitDefinition(id: "photos", name: "写真", description: "思い出写真、カバー写真、半券写真など", isRequired: false),
        RecordUnitDefinition(id: "goshuinBook", name: "御朱印帳", description: "御朱印帳のサイズに合わせて御朱印を登録", isRequired: false),
        RecordUnitDefinition(id: "importOCR", name: "OCR・取込", description: "半券、チケット、レシート、リスト画像の読み取り", isRequired: false),
        RecordUnitDefinition(id: "money", name: "金額", description: "チケット代、購入額、交通費、遠征費など", isRequired: false),
        RecordUnitDefinition(id: "officialInfo", name: "公式情報", description: "公式URL、SNS投稿リンク、参考URLなど", isRequired: false),
        RecordUnitDefinition(id: "memo", name: "メモ", description: "感想、印象、あとで見返したいこと", isRequired: true),
        RecordUnitDefinition(id: "advanced", name: "詳細オプション", description: "ジャンル固有の追加項目や高度な記録", isRequired: false),
    ]

    static let legacyIDMap: [String: String] = [
        "U1": "basic",
        "U3": "memo",
        "U4": "importOCR",
        "U7": "ticketPlan",
        "U9": "advanced",
        "U10": "advanced",
        "U11": "photos",
        "U12": "advanced",
        "U14": "basic",
        "U15": "advanced",
        "U16": "money",
        "U17": "advanced",
        "U18": "ticketPlan",
    ]

    static var requiredIDs: Set<String> {
        Set(all.filter(\.isRequired).map(\.id))
    }

    static func definitions(for rawValue: String) -> [RecordUnitDefinition] {
        let keys = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        var seenIDs = Set<String>()
        return keys.compactMap { key in
            let normalizedKey = legacyIDMap[key] ?? key
            guard !seenIDs.contains(normalizedKey),
                  let definition = all.first(where: { $0.id == normalizedKey }) else {
                return nil
            }
            seenIDs.insert(normalizedKey)
            return definition
        }
    }

    static func orderedIDs(from ids: Set<String>) -> [String] {
        all.map(\.id).filter { ids.contains($0) }
    }
}
