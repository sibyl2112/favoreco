//
//  PersonStarterPresetSeeder.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/21.
//

import Foundation
import SwiftData

struct PersonStarterPreset: Sendable {
    let displayName: String
    let reading: String
    let aliasesRaw: String
    let identityAliasesRaw: String
    let roleTagsRaw: String
    let introducedInVersion: Int

    init(
        displayName: String,
        reading: String,
        aliasesRaw: String,
        identityAliasesRaw: String,
        roleTagsRaw: String,
        introducedInVersion: Int = 1
    ) {
        self.displayName = displayName
        self.reading = reading
        self.aliasesRaw = aliasesRaw
        self.identityAliasesRaw = identityAliasesRaw
        self.roleTagsRaw = roleTagsRaw
        self.introducedInVersion = introducedInVersion
    }
}

enum PersonStarterPresetSeeder {
    private static let seedVersion = 2

    static let presets: [PersonStarterPreset] = [
        PersonStarterPreset(
            displayName: "米津玄師",
            reading: "よねづけんし",
            aliasesRaw: "ハチ",
            identityAliasesRaw: "",
            roleTagsRaw: "アーティスト, 歌手, ミュージシャン, 作曲家, 作詞家"
        ),
        PersonStarterPreset(
            displayName: "藤井風",
            reading: "ふじいかぜ",
            aliasesRaw: "風くん",
            identityAliasesRaw: "",
            roleTagsRaw: "アーティスト, 歌手, ミュージシャン, 作曲家, 作詞家"
        ),
        PersonStarterPreset(
            displayName: "Vaundy",
            reading: "ばうんでぃ",
            aliasesRaw: "バウンディ, バウ",
            identityAliasesRaw: "バウンディ",
            roleTagsRaw: "アーティスト, 歌手, ミュージシャン, 作曲家, 作詞家"
        ),
        PersonStarterPreset(
            displayName: "吉沢亮",
            reading: "よしざわりょう",
            aliasesRaw: "お亮",
            identityAliasesRaw: "",
            roleTagsRaw: "俳優"
        ),
        PersonStarterPreset(
            displayName: "松村北斗",
            reading: "まつむらほくと",
            aliasesRaw: "ほっくん",
            identityAliasesRaw: "",
            roleTagsRaw: "俳優, アイドル, 歌手"
        ),
        PersonStarterPreset(
            displayName: "横浜流星",
            reading: "よこはまりゅうせい",
            aliasesRaw: "流星くん",
            identityAliasesRaw: "",
            roleTagsRaw: "俳優"
        ),
        PersonStarterPreset(
            displayName: "見上愛",
            reading: "みかみあい",
            aliasesRaw: "愛ちゃん",
            identityAliasesRaw: "",
            roleTagsRaw: "俳優"
        ),
        PersonStarterPreset(
            displayName: "坂東龍汰",
            reading: "ばんどうりょうた",
            aliasesRaw: "ばんちゃん",
            identityAliasesRaw: "",
            roleTagsRaw: "俳優"
        ),
        PersonStarterPreset(
            displayName: "市村正親",
            reading: "いちむらまさちか",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "大竹しのぶ",
            reading: "おおたけしのぶ",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "井上芳雄",
            reading: "いのうえよしお",
            aliasesRaw: "ミュージカル界のプリンス",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "山崎育三郎",
            reading: "やまざきいくさぶろう",
            aliasesRaw: "いっくん",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "生田絵梨花",
            reading: "いくたえりか",
            aliasesRaw: "いくちゃん",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手, アイドル",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "上白石萌音",
            reading: "かみしらいしもね",
            aliasesRaw: "萌音ちゃん",
            identityAliasesRaw: "",
            roleTagsRaw: "舞台俳優・ミュージカル俳優, 俳優, 歌手",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "蜷川幸雄",
            reading: "にながわゆきお",
            aliasesRaw: "ニナガワ",
            identityAliasesRaw: "",
            roleTagsRaw: "演出家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "宮本亞門",
            reading: "みやもとあもん",
            aliasesRaw: "宮本亜門",
            identityAliasesRaw: "宮本亜門",
            roleTagsRaw: "演出家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "野田秀樹",
            reading: "のだひでき",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "演出家, 脚本家・劇作家, 俳優",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "三谷幸喜",
            reading: "みたにこうき",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "脚本家・劇作家, 演出家, 監督",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "是枝裕和",
            reading: "これえだひろかず",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "監督, 脚本家・劇作家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "李相日",
            reading: "りさんいる",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "監督, 脚本家・劇作家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "村上春樹",
            reading: "むらかみはるき",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "作家, 翻訳者",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "宮部みゆき",
            reading: "みやべみゆき",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "作家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "東野圭吾",
            reading: "ひがしのけいご",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "作家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "恩田陸",
            reading: "おんだりく",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "作家",
            introducedInVersion: 2
        ),
        PersonStarterPreset(
            displayName: "朝井リョウ",
            reading: "あさいりょう",
            aliasesRaw: "",
            identityAliasesRaw: "",
            roleTagsRaw: "作家",
            introducedInVersion: 2
        ),
    ]

    @MainActor
    static func seedIfNeeded(in context: ModelContext) async {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.integer(forKey: AppStorageKeys.personStarterPresetSeedVersion)
        guard currentVersion < seedVersion else {
            return
        }

        do {
            let existingPeople = try context.fetch(FetchDescriptor<PersonMaster>())
            var existingNames = Set(existingPeople.flatMap { person in
                [person.normalizedName, person.displayName]
            }.map(normalized).filter { !$0.isEmpty })
            let now = Date()

            for preset in presets where preset.introducedInVersion > currentVersion {
                let normalizedName = normalized(preset.displayName)
                let candidateNames = Set(
                    ([preset.displayName] + PersonActivityTags.values(from: preset.identityAliasesRaw))
                        .map(normalized)
                        .filter { !$0.isEmpty }
                )
                guard !normalizedName.isEmpty, existingNames.isDisjoint(with: candidateNames) else { continue }

                context.insert(PersonMaster(
                    displayName: preset.displayName,
                    reading: preset.reading,
                    aliasesRaw: preset.aliasesRaw,
                    roleTagsRaw: PersonActivityTags.encode(
                        PersonActivityTags.values(from: preset.roleTagsRaw)
                    ),
                    sourceSnapshotRaw: "favoreco.person-starter.2026-07",
                    normalizedName: normalizedName,
                    createdAt: now,
                    updatedAt: now
                ))
                existingNames.formUnion(candidateNames)
            }

            if context.hasChanges {
                try context.save()
            }
            defaults.set(seedVersion, forKey: AppStorageKeys.personStarterPresetSeedVersion)
        } catch {
            context.rollback()
            assertionFailure("Failed to seed person starter presets: \(error)")
        }
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "ja_JP")
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
