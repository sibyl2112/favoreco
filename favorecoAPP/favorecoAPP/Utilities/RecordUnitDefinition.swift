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
    let isImplemented: Bool

    static let all: [RecordUnitDefinition] = [
        RecordUnitDefinition(id: "U1", name: "基本情報", description: "対象名、日付、場所など", isRequired: true, isImplemented: true),
        RecordUnitDefinition(id: "U3", name: "メモ", description: "感想、印象、あとで見返したいこと", isRequired: true, isImplemented: true),
        RecordUnitDefinition(id: "U4", name: "リスト/OCR", description: "セトリ、演目、作品リストなど", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U7", name: "チケット/座席", description: "チケット、座席、発券情報", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U9", name: "スペック", description: "酒や本などの詳細スペック", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U10", name: "味/評価軸", description: "味わい、好み、ジャンル別評価軸", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U11", name: "写真", description: "思い出写真、半券、表紙など", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U12", name: "タグ", description: "気分、同行者、分類タグ", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U14", name: "場所", description: "地図、会場、施設スナップショット", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U15", name: "統計", description: "回数、評価、年間まとめへの集計", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U16", name: "金額", description: "購入額、チケット代、交通費など", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U17", name: "在庫/コレクション", description: "酒、本、グッズなどの所有管理", isRequired: false, isImplemented: false),
        RecordUnitDefinition(id: "U18", name: "通知/予定", description: "申込、当落、訪問予定、リマインダー", isRequired: false, isImplemented: false),
    ]

    static var requiredIDs: Set<String> {
        Set(all.filter(\.isRequired).map(\.id))
    }

    static func definitions(for rawValue: String) -> [RecordUnitDefinition] {
        let keys = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        return keys.compactMap { key in all.first { $0.id == key } }
    }

    static func orderedIDs(from ids: Set<String>) -> [String] {
        all.map(\.id).filter { ids.contains($0) }
    }
}
