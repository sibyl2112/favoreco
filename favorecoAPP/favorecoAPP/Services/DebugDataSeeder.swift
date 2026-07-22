//
//  DebugDataSeeder.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import Foundation
import SwiftData
import UIKit

struct DebugSampleDataSummary {
    let eventCount: Int
    let visitCount: Int
    let planCount: Int
    let ticketAttemptCount: Int

    static let empty = DebugSampleDataSummary(
        eventCount: 0,
        visitCount: 0,
        planCount: 0,
        ticketAttemptCount: 0
    )

    var insertedMessage: String {
        "サンプル\(eventCount)件（記録\(visitCount)件・未来予定\(planCount)件）を追加しました。"
    }

    var deletedMessage: String {
        "サンプル\(eventCount)件（記録\(visitCount)件・予定\(planCount)件）を削除しました。通常の記録とマスターは残ります。"
    }
}

enum SampleDataSeeder {
    static let sampleURLPrefix = "https://sample.favoreco.app/v2/"
    static let samplePhotoPrefix = "sample/v2/"

    private static let legacyURLPrefix = "https://example.com/favoreco/"
    private static let legacyPhotoPrefix = "debug/sample-"
    private static let sampleMasterMarker = "favoreco-sample-v2"
    private static let automaticInsertionKey = "hasInsertedAutomaticSampleDataV2"
    private static let samplesPerCategory = 3

    @MainActor
    @discardableResult
    static func insertAutomaticSamples(
        in context: ModelContext,
        categoryTemplateKeys: Set<String>
    ) throws -> DebugSampleDataSummary {
        guard !UserDefaults.standard.bool(forKey: automaticInsertionKey) else {
            return .empty
        }

        let existingEvents = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let hasPersonalData = existingEvents.contains { !isSampleEvent($0) }
        guard !hasPersonalData else {
            if existingEvents.contains(where: isSampleEvent) {
                _ = try deleteSamples(in: context)
            }
            UserDefaults.standard.set(true, forKey: automaticInsertionKey)
            return .empty
        }

        let summary = try replaceSamples(
            in: context,
            categoryTemplateKeys: categoryTemplateKeys
        )
        UserDefaults.standard.set(true, forKey: automaticInsertionKey)
        return summary
    }

    @MainActor
    @discardableResult
    static func replaceSamples(
        in context: ModelContext,
        categoryTemplateKeys: Set<String>? = nil
    ) throws -> DebugSampleDataSummary {
        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: context)
        _ = try deleteSamples(in: context)

        let descriptor = FetchDescriptor<RecordCategory>(
            sortBy: [SortDescriptor(\RecordCategory.sortOrder)]
        )
        let categories = try context.fetch(descriptor).filter { category in
            categoryTemplateKeys?.contains(category.templateKey) ?? true
        }
        let now = Date()
        var placesByName: [String: PlaceMaster] = [:]
        for place in try context.fetch(FetchDescriptor<PlaceMaster>()) where placesByName[place.name] == nil {
            placesByName[place.name] = place
        }
        var peopleByName: [String: PersonMaster] = [:]
        for person in try context.fetch(FetchDescriptor<PersonMaster>()) where peopleByName[person.displayName] == nil {
            peopleByName[person.displayName] = person
        }
        var eventCount = 0
        var visitCount = 0
        var planCount = 0
        var ticketAttemptCount = 0

        for (categoryIndex, category) in categories.enumerated() {
            for sampleIndex in 0..<samplesPerCategory {
                if category.templateKey == "random_goods" {
                    insertCollectibleSample(
                        category: category,
                        categoryIndex: categoryIndex,
                        sampleIndex: sampleIndex,
                        now: now,
                        context: context
                    )
                    eventCount += 1
                    continue
                }

                let definition = sampleDefinition(for: category, index: sampleIndex)
                let image = sampleImage(for: category, index: sampleIndex)
                let imagePath = "\(samplePhotoPrefix)\(category.templateKey)-\(sampleIndex + 1).jpg"
                let isFuture = sampleIndex == samplesPerCategory - 1
                let itemDate = isFuture
                    ? sampleFutureDate(now: now, categoryIndex: categoryIndex)
                    : samplePastDate(now: now, categoryIndex: categoryIndex, sampleIndex: sampleIndex)
                let aspectRatioKey = sampleAspectRatioKey(for: category)
                let unitFields = VisitUnitFields(
                    ocrText: sampleOCRText(for: category, title: definition.title),
                    eyecatchAspectRatioKey: aspectRatioKey,
                    goshuinBookSizeKey: category.templateKey == "goshuin" ? GoshuinBookSize.standard.key : "",
                    advancedEntries: sampleAdvancedEntries(for: category, index: sampleIndex)
                )
                let placeSeed = samplePlace(for: category, index: sampleIndex)
                let place = resolvePlace(
                    placeSeed,
                    context: context,
                    placesByName: &placesByName,
                    now: now
                )
                let event = ExperienceEvent(
                    title: definition.title,
                    seriesName: definition.seriesName,
                    subTypeKey: definition.subTypeKey,
                    organizerNameSnapshot: definition.organizer,
                    representativeEyecatchPath: imagePath,
                    officialURL: "\(sampleURLPrefix)\(category.templateKey)/\(sampleIndex + 1)",
                    memo: "使い方を確認するためのサンプルデータです。いつでもサンプルだけ削除できます。",
                    unitFieldsRaw: unitFields.encodedRawValue,
                    createdAt: itemDate,
                    updatedAt: now,
                    eyecatchData: image.data,
                    category: category
                )
                context.insert(event)
                eventCount += 1

                if let personSeed = samplePerson(for: category, index: sampleIndex) {
                    let person = resolvePerson(
                        personSeed,
                        context: context,
                        peopleByName: &peopleByName,
                        now: now
                    )
                    context.insert(EventPersonLink(
                        roleKey: personSeed.roleKey,
                        displayRole: personSeed.displayRole,
                        nameSnapshot: person.displayName,
                        memo: "架空の人物・団体によるサンプルです。",
                        createdAt: itemDate,
                        updatedAt: now,
                        person: person,
                        event: event
                    ))
                }

                if isFuture {
                    let plan = Plan(
                        title: definition.title,
                        subtitle: "サンプルの未来予定",
                        planKindKey: samplePlanKind(for: category),
                        stateKey: "planned",
                        startsAt: itemDate,
                        endsAt: itemDate.addingTimeInterval(sampleDuration(for: category)),
                        opensAt: ["theater", "live"].contains(category.templateKey)
                            ? itemDate.addingTimeInterval(-30 * 60)
                            : Date.distantPast,
                        venueNameSnapshot: place.name,
                        organizerNameSnapshot: definition.organizer,
                        officialURL: "\(sampleURLPrefix)\(category.templateKey)/plan",
                        sourceURL: "\(sampleURLPrefix)\(category.templateKey)/plan/source",
                        memo: "Homeとカレンダーで未来予定の使い方を確認できるサンプルです。",
                        notificationLeadTimeKey: "none",
                        createdAt: now,
                        updatedAt: now,
                        category: category,
                        event: event,
                        placeMaster: place
                    )
                    context.insert(plan)
                    planCount += 1

                    if let attempt = sampleTicketAttempt(
                        for: category,
                        plan: plan,
                        planStart: itemDate,
                        now: now
                    ) {
                        context.insert(attempt)
                        ticketAttemptCount += 1
                    }
                } else {
                    let visit = Visit(
                        visitedAt: itemDate,
                        endedAt: itemDate.addingTimeInterval(sampleDuration(for: category)),
                        venueNameSnapshot: place.name,
                        overallRating: sampleIndex == 0 ? 4.5 : 4.0,
                        outcomeKey: hasEnabledUnit("ticketPlan", in: category) ? "attended" : "",
                        seatText: ["theater", "live"].contains(category.templateKey)
                            ? "1階 \(10 + sampleIndex)列 \(12 + sampleIndex)番"
                            : "",
                        eyecatchPath: imagePath,
                        note: sampleNote(for: category, title: definition.title),
                        tagNamesRaw: "サンプル,\(category.name)",
                        amount: sampleAmount(for: category, index: sampleIndex),
                        latitude: place.latitude,
                        longitude: place.longitude,
                        unitFieldsRaw: unitFields.encodedRawValue,
                        createdAt: itemDate,
                        updatedAt: now,
                        event: event,
                        placeMaster: place
                    )
                    context.insert(visit)
                    context.insert(PhotoBlob(
                        relativePath: imagePath,
                        originalFilename: "\(category.templateKey)-\(sampleIndex + 1).jpg",
                        mediaKind: "photo",
                        purpose: "memory",
                        byteCount: image.data.count,
                        width: image.width,
                        height: image.height,
                        createdAt: itemDate,
                        data: image.data,
                        visit: visit
                    ))
                    visitCount += 1
                }
            }
        }

        try context.save()
        return DebugSampleDataSummary(
            eventCount: eventCount,
            visitCount: visitCount,
            planCount: planCount,
            ticketAttemptCount: ticketAttemptCount
        )
    }

    @MainActor
    @discardableResult
    static func deleteSamples(in context: ModelContext) throws -> DebugSampleDataSummary {
        let currentURLPrefix = sampleURLPrefix
        let oldURLPrefix = legacyURLPrefix
        let currentPhotoPrefix = samplePhotoPrefix
        let oldPhotoPrefix = legacyPhotoPrefix

        let sampleEvents = try context.fetch(FetchDescriptor<ExperienceEvent>(
            predicate: #Predicate {
                $0.officialURL.starts(with: currentURLPrefix)
                    || $0.officialURL.starts(with: oldURLPrefix)
            }
        ))
        let samplePlans = try context.fetch(FetchDescriptor<Plan>(
            predicate: #Predicate {
                $0.officialURL.starts(with: currentURLPrefix)
                    || $0.officialURL.starts(with: oldURLPrefix)
            }
        ))
        let sampleAttempts = try context.fetch(FetchDescriptor<TicketAttempt>(
            predicate: #Predicate {
                $0.purchaseURL.starts(with: currentURLPrefix)
                    || $0.purchaseURL.starts(with: oldURLPrefix)
            }
        ))
        let sampleVisits = try context.fetch(FetchDescriptor<Visit>(
            predicate: #Predicate {
                $0.eyecatchPath.starts(with: currentPhotoPrefix)
                    || $0.eyecatchPath.starts(with: oldPhotoPrefix)
            }
        ))

        for attempt in sampleAttempts {
            TicketNotificationScheduler.cancel(attemptID: attempt.id)
            context.delete(attempt)
        }
        for plan in samplePlans {
            TicketNotificationScheduler.cancel(planID: plan.id, attemptID: nil)
            context.delete(plan)
        }
        for event in sampleEvents {
            context.delete(event)
        }
        try context.save()

        try context.delete(
            model: PhotoBlob.self,
            where: #Predicate { $0.relativePath.starts(with: currentPhotoPrefix) }
        )
        try context.delete(
            model: PhotoBlob.self,
            where: #Predicate { $0.relativePath.starts(with: oldPhotoPrefix) }
        )
        try context.save()
        try deleteOrphanedSampleMasters(in: context)

        return DebugSampleDataSummary(
            eventCount: sampleEvents.count,
            visitCount: sampleVisits.count,
            planCount: samplePlans.count,
            ticketAttemptCount: sampleAttempts.count
        )
    }

    static func isSampleEvent(_ event: ExperienceEvent) -> Bool {
        event.officialURL.starts(with: sampleURLPrefix)
            || event.officialURL.starts(with: legacyURLPrefix)
    }

    static func resetAutomaticInsertionState() {
        UserDefaults.standard.set(false, forKey: automaticInsertionKey)
    }

    private struct SampleImage {
        let data: Data
        let width: Int
        let height: Int
    }

    private struct SampleDefinition {
        let title: String
        let seriesName: String
        let subTypeKey: String
        let organizer: String
    }

    private struct SamplePlace {
        let name: String
        let reading: String
        let tags: String
        let prefecture: String
        let address: String
        let officialURL: String
    }

    private struct SamplePerson {
        let name: String
        let reading: String
        let roleKey: String
        let displayRole: String
    }

    private struct CollectibleSampleDefinition {
        let title: String
        let releaseText: String
        let kind: CollectibleKind
        let maker: String
        let itemNames: [String]
        let acquiredQuantities: [Int]
        let unitPrice: Decimal
        let outgoingItemIndex: Int?
    }

    @MainActor
    private static func insertCollectibleSample(
        category: RecordCategory,
        categoryIndex: Int,
        sampleIndex: Int,
        now: Date,
        context: ModelContext
    ) {
        let definition = collectibleSampleDefinition(index: sampleIndex)
        let image = sampleImage(for: category, index: sampleIndex)
        let itemDate = samplePastDate(
            now: now,
            categoryIndex: categoryIndex,
            sampleIndex: sampleIndex
        )
        let event = ExperienceEvent(
            title: definition.title,
            seriesName: definition.releaseText,
            subTypeKey: definition.kind.rawValue,
            organizerNameSnapshot: definition.maker,
            officialURL: "\(sampleURLPrefix)random_goods/\(sampleIndex + 1)",
            memo: "種類別の所持数、未入手、ダブり、コンプリート表示を確認するサンプルです。",
            createdAt: itemDate,
            updatedAt: now,
            eyecatchData: image.data,
            category: category
        )
        context.insert(event)

        for (itemIndex, itemName) in definition.itemNames.enumerated() {
            let item = CollectibleItem(
                name: itemName,
                sortOrder: itemIndex,
                createdAt: itemDate,
                updatedAt: now,
                series: event
            )
            context.insert(item)

            let acquiredQuantity = definition.acquiredQuantities[itemIndex]
            if acquiredQuantity > 0 {
                context.insert(CollectibleTransaction(
                    kindKey: definition.kind == .capsuleToy
                        ? CollectibleTransactionKind.capsule.rawValue
                        : CollectibleTransactionKind.purchase.rawValue,
                    quantity: acquiredQuantity,
                    occurredAt: itemDate.addingTimeInterval(TimeInterval(itemIndex * 60)),
                    amount: definition.unitPrice * Decimal(acquiredQuantity),
                    placeNameSnapshot: "サンプルショップ",
                    memo: acquiredQuantity > 1 ? "同じ種類を複数入手したサンプルです。" : "入手履歴のサンプルです。",
                    createdAt: itemDate,
                    updatedAt: now,
                    item: item
                ))
            }

            if definition.outgoingItemIndex == itemIndex {
                context.insert(CollectibleTransaction(
                    kindKey: CollectibleTransactionKind.tradeOut.rawValue,
                    quantity: 1,
                    occurredAt: itemDate.addingTimeInterval(24 * 60 * 60),
                    placeNameSnapshot: "交換会",
                    memo: "交換で1個手放したサンプルです。",
                    createdAt: itemDate,
                    updatedAt: now,
                    item: item
                ))
            }
        }
    }

    private static func collectibleSampleDefinition(index: Int) -> CollectibleSampleDefinition {
        let definitions = [
            CollectibleSampleDefinition(
                title: "星空どうぶつカプセル",
                releaseText: "2026年7月",
                kind: .capsuleToy,
                maker: "北極星トイ",
                itemNames: ["しろくま", "ペンギン", "あざらし", "きつね", "ふくろう"],
                acquiredQuantities: [2, 1, 0, 1, 0],
                unitPrice: 400,
                outgoingItemIndex: nil
            ),
            CollectibleSampleDefinition(
                title: "月影アクリルチャーム",
                releaseText: "第1弾",
                kind: .acrylicKeychain,
                maker: "灯台雑貨店",
                itemNames: ["ルナ", "アオ", "ミナト", "レン", "トワ", "シークレット"],
                acquiredQuantities: [3, 0, 1, 0, 1, 0],
                unitPrice: 700,
                outgoingItemIndex: 0
            ),
            CollectibleSampleDefinition(
                title: "花色缶バッジコレクション",
                releaseText: "春色シリーズ",
                kind: .canBadge,
                maker: "架空アート企画",
                itemNames: ["桜", "菜の花", "藤", "青葉"],
                acquiredQuantities: [1, 1, 1, 1],
                unitPrice: 500,
                outgoingItemIndex: nil
            )
        ]
        return definitions[index % definitions.count]
    }

    private static func sampleDefinition(for category: RecordCategory, index: Int) -> SampleDefinition {
        let titles: [String]
        let seriesName: String
        let organizer: String
        switch category.templateKey {
        case "theater":
            titles = ["月影のアトリエ", "雨音の王国", "星屑の航路"]
            seriesName = "2026年公演"
            organizer = "灯台座"
        case "museum":
            titles = ["透明な記憶", "風を採集する", "深海の光譜"]
            seriesName = "企画展"
            organizer = "架空文化企画室"
        case "live":
            titles = ["LUMINA TOUR", "ECHOES AT DAWN", "NEON TIDE"]
            seriesName = "2026 TOUR"
            organizer = "North Light Music"
        case "movie":
            titles = ["夜を編む人", "光のメトロノーム", "白い海の記憶"]
            seriesName = ""
            organizer = "Orion Pictures"
        case "sake":
            titles = ["月灯り 純米吟醸", "山凪 クラフトビール", "燻樹 シングルモルト"]
            seriesName = "試飲ノート"
            organizer = ""
        case "theme_park":
            titles = ["星降る遊園地", "蒼海の冒険島", "森のからくり王国"]
            seriesName = ""
            organizer = ""
        case "nature_living":
            titles = ["水の森水族館", "光の丘どうぶつ園", "月草植物園"]
            seriesName = ""
            organizer = ""
        case "outing_facility":
            titles = ["風見塔展望台", "港の赤レンガ倉庫", "雲上ロープウェイ"]
            seriesName = ""
            organizer = ""
        case "goshuin":
            titles = ["明治神宮", "浅草寺", "伏見稲荷大社"]
            seriesName = "参拝の記録"
            organizer = ""
        case "book":
            titles = ["夜明けの標本室", "雨粒の図書館", "北へ帰る鳥"]
            seriesName = "灯台文庫"
            organizer = "架空書房"
        case "random_goods":
            let definition = collectibleSampleDefinition(index: index)
            titles = [definition.title]
            seriesName = definition.releaseText
            organizer = definition.maker
        default:
            titles = ["はじめての\(category.name)", "思い出の\(category.name)", "次の\(category.name)"]
            seriesName = ""
            organizer = ""
        }
        return SampleDefinition(
            title: titles[index % titles.count],
            seriesName: seriesName,
            subTypeKey: sampleSubTypeKey(for: category, index: index),
            organizer: organizer
        )
    }

    private static func samplePlace(for category: RecordCategory, index: Int) -> SamplePlace {
        let places: [SamplePlace]
        switch category.templateKey {
        case "theater":
            places = [
                .init(name: "東京芸術劇場 プレイハウス", reading: "とうきょうげいじゅつげきじょうぷれいはうす", tags: "theater,performing_arts_venue", prefecture: "東京都", address: "東京都豊島区西池袋1-8-1", officialURL: "https://www.geigeki.jp/facilities/playhouse/"),
                .init(name: "新国立劇場 中劇場", reading: "しんこくりつげきじょうちゅうげきじょう", tags: "theater,performing_arts_venue", prefecture: "東京都", address: "東京都渋谷区本町1-1-1", officialURL: "https://www.nntt.jac.go.jp/guide/playhouse/"),
                .init(name: "南座", reading: "みなみざ", tags: "theater,kabuki_theater,historic_site", prefecture: "京都府", address: "京都府京都市東山区四条大橋東詰", officialURL: "https://www.shochiku.co.jp/play/theater/minamiza/")
            ]
        case "museum":
            places = [
                .init(name: "国立新美術館", reading: "こくりつしんびじゅつかん", tags: "art_museum,museum,cultural_facility", prefecture: "東京都", address: "東京都港区六本木7-22-2", officialURL: "https://www.nact.jp/"),
                .init(name: "東京国立博物館", reading: "とうきょうこくりつはくぶつかん", tags: "museum,cultural_facility,historic_site", prefecture: "東京都", address: "東京都台東区上野公園13-9", officialURL: "https://www.tnm.jp/"),
                .init(name: "国立科学博物館", reading: "こくりつかがくはくぶつかん", tags: "museum,science_museum,cultural_facility", prefecture: "東京都", address: "東京都台東区上野公園7-20", officialURL: "https://www.kahaku.go.jp/")
            ]
        case "live":
            places = [
                .init(name: "東京ドーム", reading: "とうきょうどーむ", tags: "dome,stadium,live_venue", prefecture: "東京都", address: "東京都文京区後楽1-3-61", officialURL: "https://www.tokyo-dome.co.jp/dome/"),
                .init(name: "日本武道館", reading: "にっぽんぶどうかん", tags: "arena,live_venue,landmark", prefecture: "東京都", address: "東京都千代田区北の丸公園2-3", officialURL: "https://www.nipponbudokan.or.jp/"),
                .init(name: "Zepp DiverCity (TOKYO)", reading: "ぜっぷだいばーしてぃとうきょう", tags: "live_house,music_venue", prefecture: "東京都", address: "東京都江東区青海1-1-10 ダイバーシティ東京 プラザ", officialURL: "https://www.zepp.co.jp/hall/divercity/")
            ]
        case "movie":
            places = Array(repeating: .init(name: "桜坂劇場 ホールA", reading: "さくらざかげきじょうほーるえー", tags: "cinema,theater,cultural_venue", prefecture: "沖縄県", address: "沖縄県那覇市牧志3-6-10", officialURL: "https://sakura-zaka.com/"), count: samplesPerCategory)
        case "sake":
            places = [
                .init(name: "月桂冠大倉記念館", reading: "げっけいかんおおくらきねんかん", tags: "sake_brewery,museum", prefecture: "京都府", address: "京都府京都市伏見区南浜町247", officialURL: "https://www.gekkeikan.co.jp/enjoy/museum/"),
                .init(name: "白鶴酒造資料館", reading: "はくつるしゅぞうしりょうかん", tags: "sake_brewery,museum", prefecture: "兵庫県", address: "兵庫県神戸市東灘区住吉南町4丁目5-5", officialURL: "https://www.hakutsuru.co.jp/community/shiryo/"),
                .init(name: "サントリー山崎蒸溜所", reading: "さんとりーやまざきじょうりゅうしょ", tags: "whisky_distillery,industrial_tourism", prefecture: "大阪府", address: "大阪府三島郡島本町山崎5-2-1", officialURL: "https://www.suntory.co.jp/factory/yamazaki/")
            ]
        case "theme_park":
            places = [
                .init(name: "東京ディズニーランド", reading: "とうきょうでぃずにーらんど", tags: "theme_park,leisure_facility", prefecture: "千葉県", address: "千葉県浦安市舞浜1-1", officialURL: "https://www.tokyodisneyresort.jp/tdl/"),
                .init(name: "ユニバーサル・スタジオ・ジャパン", reading: "ゆにばーさるすたじおじゃぱん", tags: "theme_park,leisure_facility", prefecture: "大阪府", address: "大阪府大阪市此花区桜島2-1-33", officialURL: "https://www.usj.co.jp/web/"),
                .init(name: "ハウステンボス", reading: "はうすてんぼす", tags: "theme_park,leisure_facility", prefecture: "長崎県", address: "長崎県佐世保市ハウステンボス町1-1", officialURL: "https://www.huistenbosch.co.jp/")
            ]
        case "nature_living":
            places = [
                .init(name: "海遊館", reading: "かいゆうかん", tags: "aquarium,museum,leisure_facility", prefecture: "大阪府", address: "大阪府大阪市港区海岸通1-1-10", officialURL: "https://www.kaiyukan.com/"),
                .init(name: "上野動物園", reading: "うえのどうぶつえん", tags: "zoo,leisure_facility", prefecture: "東京都", address: "東京都台東区上野公園9-83", officialURL: "https://www.tokyo-zoo.net/zoo/ueno/"),
                .init(name: "あしかがフラワーパーク", reading: "あしかがふらわーぱーく", tags: "botanical_garden,garden,leisure_facility", prefecture: "栃木県", address: "栃木県足利市迫間町607", officialURL: "https://www.ashikaga.co.jp/")
            ]
        case "outing_facility":
            places = [
                .init(name: "東京スカイツリー", reading: "とうきょうすかいつりー", tags: "tower,observation_deck,landmark", prefecture: "東京都", address: "東京都墨田区押上1-1-2", officialURL: "https://www.tokyo-skytree.jp/"),
                .init(name: "大阪城天守閣", reading: "おおさかじょうてんしゅかく", tags: "castle,museum,historic_site", prefecture: "大阪府", address: "大阪府大阪市中央区大阪城1-1", officialURL: "https://www.osakacastle.net/"),
                .init(name: "せんだいメディアテーク", reading: "せんだいめでぃあてーく", tags: "library,architecture,cultural_facility", prefecture: "宮城県", address: "宮城県仙台市青葉区春日町2-1", officialURL: "https://www.smt.jp/")
            ]
        case "goshuin":
            places = [
                .init(name: "明治神宮", reading: "めいじじんぐう", tags: "shrine,landmark", prefecture: "東京都", address: "東京都渋谷区代々木神園町1-1", officialURL: "https://www.meijijingu.or.jp/"),
                .init(name: "浅草寺", reading: "せんそうじ", tags: "temple,historic_site,landmark", prefecture: "東京都", address: "東京都台東区浅草2-3-1", officialURL: "https://www.senso-ji.jp/"),
                .init(name: "伏見稲荷大社", reading: "ふしみいなりたいしゃ", tags: "shrine,historic_site,landmark", prefecture: "京都府", address: "京都府京都市伏見区深草薮之内町68", officialURL: "https://inari.jp/")
            ]
        case "book":
            places = [
                .init(name: "金沢海みらい図書館", reading: "かなざわうみみらいとしょかん", tags: "library,architecture,cultural_facility", prefecture: "石川県", address: "石川県金沢市寺中町イ1番地1", officialURL: "https://www.lib.kanazawa.ishikawa.jp/umimirai/"),
                .init(name: "武雄市図書館", reading: "たけおしとしょかん", tags: "library,architecture,cultural_facility", prefecture: "佐賀県", address: "佐賀県武雄市武雄町大字武雄5304番地1", officialURL: "https://takeo.city-library.jp/"),
                .init(name: "小布施町立図書館まちとしょテラソ", reading: "おぶせちょうりつとしょかんまちとしょてらそ", tags: "library,architecture,cultural_facility", prefecture: "長野県", address: "長野県上高井郡小布施町小布施1491-2", officialURL: "https://www.town.obuse.nagano.jp/lib/")
            ]
        default:
            places = Array(repeating: .init(name: "サンプル場所", reading: "さんぷるばしょ", tags: "sample", prefecture: "東京都", address: "東京都", officialURL: ""), count: samplesPerCategory)
        }
        return places[index % places.count]
    }

    private static func samplePerson(for category: RecordCategory, index: Int) -> SamplePerson? {
        let people: [SamplePerson]
        switch category.templateKey {
        case "theater":
            people = [
                .init(name: "神崎 透", reading: "かんざきとおる", roleKey: "actor", displayRole: "出演"),
                .init(name: "水城 紗英", reading: "みずきさえ", roleKey: "actor", displayRole: "主演"),
                .init(name: "結城 蓮", reading: "ゆうきれん", roleKey: "director", displayRole: "演出")
            ]
        case "museum":
            people = [
                .init(name: "白瀬 碧", reading: "しらせあお", roleKey: "artist", displayRole: "作家"),
                .init(name: "有馬 凪", reading: "ありまなぎ", roleKey: "artist", displayRole: "作家"),
                .init(name: "久遠 澪", reading: "くおんみお", roleKey: "curator", displayRole: "キュレーター")
            ]
        case "live":
            people = [
                .init(name: "青凪ルカ", reading: "あおなぎるか", roleKey: "artist", displayRole: "アーティスト"),
                .init(name: "The Lanterns", reading: "ざらんたんず", roleKey: "group", displayRole: "バンド"),
                .init(name: "潮見ネオン", reading: "しおみねおん", roleKey: "artist", displayRole: "アーティスト")
            ]
        case "movie":
            people = [
                .init(name: "冬木 遥", reading: "ふゆきはるか", roleKey: "director", displayRole: "監督"),
                .init(name: "朝倉 律", reading: "あさくらりつ", roleKey: "actor", displayRole: "主演"),
                .init(name: "雪村 灯", reading: "ゆきむらあかり", roleKey: "director", displayRole: "監督")
            ]
        case "book":
            people = [
                .init(name: "遠野 灯子", reading: "とおのとうこ", roleKey: "author", displayRole: "著者"),
                .init(name: "水瀬 栞", reading: "みなせしおり", roleKey: "author", displayRole: "著者"),
                .init(name: "北原 澄", reading: "きたはらすみ", roleKey: "author", displayRole: "著者")
            ]
        default:
            return nil
        }
        return people[index % people.count]
    }

    private static func resolvePlace(
        _ seed: SamplePlace,
        context: ModelContext,
        placesByName: inout [String: PlaceMaster],
        now: Date
    ) -> PlaceMaster {
        if let existing = placesByName[seed.name] {
            return existing
        }
        let place = PlaceMaster(
            name: seed.name,
            reading: seed.reading,
            placeTagsRaw: seed.tags,
            prefecture: seed.prefecture,
            address: seed.address,
            officialURL: seed.officialURL,
            memo: "共通場所カタログからサンプル用に登録しました。",
            sourceSnapshotRaw: sampleMasterMarker,
            normalizedName: normalized(seed.name),
            normalizedAddress: normalized(seed.address),
            createdAt: now,
            updatedAt: now
        )
        context.insert(place)
        placesByName[seed.name] = place
        return place
    }

    private static func resolvePerson(
        _ seed: SamplePerson,
        context: ModelContext,
        peopleByName: inout [String: PersonMaster],
        now: Date
    ) -> PersonMaster {
        if let existing = peopleByName[seed.name] {
            return existing
        }
        let person = PersonMaster(
            displayName: seed.name,
            reading: seed.reading,
            roleTagsRaw: seed.displayRole,
            memo: "Favorecoの使い方を示すために作成した架空の人物・団体です。",
            sourceSnapshotRaw: sampleMasterMarker,
            normalizedName: normalized(seed.name),
            createdAt: now,
            updatedAt: now
        )
        context.insert(person)
        peopleByName[seed.name] = person
        return person
    }

    @MainActor
    private static func deleteOrphanedSampleMasters(in context: ModelContext) throws {
        let marker = sampleMasterMarker
        let samplePeople = try context.fetch(FetchDescriptor<PersonMaster>(
            predicate: #Predicate { $0.sourceSnapshotRaw == marker }
        ))
        for person in samplePeople where (person.eventLinks ?? []).isEmpty && person.favoriteProfile == nil && (person.favoPins ?? []).isEmpty {
            context.delete(person)
        }

        let samplePlaces = try context.fetch(FetchDescriptor<PlaceMaster>(
            predicate: #Predicate { $0.sourceSnapshotRaw == marker }
        ))
        for place in samplePlaces where (place.visits ?? []).isEmpty && (place.plans ?? []).isEmpty && (place.favoPins ?? []).isEmpty {
            context.delete(place)
        }
        if context.hasChanges {
            try context.save()
        }
    }

    private static func sampleImage(for category: RecordCategory, index: Int) -> SampleImage {
        let resourceName = "\(category.templateKey)-\(index + 1)"
        let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg")
            ?? Bundle.main.url(
                forResource: resourceName,
                withExtension: "jpg",
                subdirectory: "Resources/SampleDataImages"
            )
        guard let url = resourceURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            return fallbackImage(for: category, title: sampleDefinition(for: category, index: index).title)
        }
        return SampleImage(data: data, width: cgImage.width, height: cgImage.height)
    }

    private static func fallbackImage(for category: RecordCategory, title: String) -> SampleImage {
        let ratio = sampleRatio(for: category)
        let height: CGFloat = 960
        let size = CGSize(width: max(480, height * CGFloat(ratio)), height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hexString: category.colorHex).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(28, size.width * 0.075), weight: .bold),
                .foregroundColor: UIColor.white
            ]
            title.draw(
                in: CGRect(x: size.width * 0.08, y: size.height * 0.72, width: size.width * 0.84, height: size.height * 0.2),
                withAttributes: attributes
            )
        }
        let data = image.jpegData(compressionQuality: 0.86) ?? Data()
        return SampleImage(data: data, width: Int(size.width), height: Int(size.height))
    }

    private static func samplePastDate(now: Date, categoryIndex: Int, sampleIndex: Int) -> Date {
        let daysAgo = 18 + categoryIndex * 7 + sampleIndex * 23
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    private static func sampleFutureDate(now: Date, categoryIndex: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: 5 + categoryIndex * 3, to: now) ?? now
        return Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
    }

    private static func sampleAspectRatioKey(for category: RecordCategory) -> String {
        category.templateKey == "book"
            ? EyecatchAspectRatio.hardcoverBook.key
            : EyecatchAspectRatio.recommended(for: category).key
    }

    private static func sampleRatio(for category: RecordCategory) -> Double {
        category.templateKey == "book"
            ? EyecatchAspectRatio.hardcoverBook.value
            : EyecatchAspectRatio.recommended(for: category).value
    }

    private static func sampleSubTypeKey(for category: RecordCategory, index: Int) -> String {
        switch category.templateKey {
        case "theme_park":
            return OutingFacilityType.themePark.rawValue
        case "nature_living":
            return [OutingFacilityType.aquarium, .zoo, .botanicalGarden][index % 3].rawValue
        case "outing_facility":
            return OutingFacilityType.facilityOther.rawValue
        default:
            return ""
        }
    }

    private static func samplePlanKind(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "screening"
        case "book": return "reading"
        case "museum": return "exhibition"
        case "sake": return "tasting"
        case "theme_park", "nature_living", "outing_facility", "goshuin": return "visit"
        default: return "performance"
        }
    }

    private static func sampleDuration(for category: RecordCategory) -> TimeInterval {
        switch category.templateKey {
        case "book": return 60 * 60
        case "theme_park", "nature_living", "outing_facility": return 5 * 60 * 60
        default: return 2 * 60 * 60
        }
    }

    private static func sampleAmount(for category: RecordCategory, index: Int) -> Decimal {
        switch category.templateKey {
        case "theater": return Decimal(8_800 + index * 1_200)
        case "live": return Decimal(7_500 + index * 1_000)
        case "movie": return Decimal(1_800 + index * 200)
        case "museum": return Decimal(1_500 + index * 300)
        case "sake": return Decimal(1_200 + index * 800)
        case "theme_park": return Decimal(7_900 + index * 900)
        case "nature_living", "outing_facility": return Decimal(1_800 + index * 400)
        case "book": return Decimal(1_600 + index * 300)
        default: return Decimal(0)
        }
    }

    private static func sampleNote(for category: RecordCategory, title: String) -> String {
        switch category.templateKey {
        case "goshuin": return "\(title)でいただいた御朱印を残すサンプルです。"
        case "book": return "読了後の感想や心に残った一節を記録するサンプルです。"
        default: return "\(title)の写真、評価、場所、人物の記録方法を確認できます。"
        }
    }

    private static func sampleOCRText(for category: RecordCategory, title: String) -> String {
        switch category.templateKey {
        case "theater", "live": return "\(title)\n開場 18:00 / 開演 18:30\nサンプルチケット"
        case "museum": return "\(title)\n出品目録のサンプル"
        case "book": return "\(title)\n読書メモのサンプル"
        case "goshuin": return "\(title)\n参拝記録のサンプル"
        default: return ""
        }
    }

    private static func sampleAdvancedEntries(for category: RecordCategory, index: Int) -> [AdvancedFieldEntry] {
        switch category.templateKey {
        case "sake":
            return [AdvancedFieldEntry(label: "飲み方", value: index == 2 ? "ロック" : "冷やして")]
        case "book":
            return [AdvancedFieldEntry(label: "読書状態", value: index == 2 ? "読みたい" : "読了")]
        case "goshuin":
            return [AdvancedFieldEntry(label: "御朱印帳", value: GoshuinBookSize.standard.name)]
        default:
            return []
        }
    }

    private static func sampleTicketAttempt(
        for category: RecordCategory,
        plan: Plan,
        planStart: Date,
        now: Date
    ) -> TicketAttempt? {
        switch category.templateKey {
        case "theater":
            return TicketAttempt(
                statusKey: "waitingResult",
                entryRouteKey: "lottery",
                ticketSite: "サンプルプレイガイド",
                applyDeadlineAt: now.addingTimeInterval(2 * 24 * 60 * 60),
                resultAnnounceAt: now.addingTimeInterval(5 * 24 * 60 * 60),
                issueStartAt: planStart.addingTimeInterval(-7 * 24 * 60 * 60),
                price: Decimal(12_000),
                purchaseURL: "\(sampleURLPrefix)theater/ticket",
                memo: "当落待ち表示を確認するサンプルです。通知は予約しません。",
                createdAt: now,
                updatedAt: now,
                plan: plan
            )
        case "live":
            return TicketAttempt(
                statusKey: "waitingPayment",
                entryRouteKey: "fanClub",
                ticketSite: "サンプルFC",
                resultAnnounceAt: now.addingTimeInterval(-24 * 60 * 60),
                paymentDeadlineAt: now.addingTimeInterval(2 * 24 * 60 * 60),
                issueStartAt: planStart.addingTimeInterval(-5 * 24 * 60 * 60),
                price: Decimal(9_800),
                purchaseURL: "\(sampleURLPrefix)live/ticket",
                memo: "入金待ち表示を確認するサンプルです。通知は予約しません。",
                createdAt: now,
                updatedAt: now,
                plan: plan
            )
        default:
            return nil
        }
    }

    private static func hasEnabledUnit(_ unitID: String, in category: RecordCategory) -> Bool {
        category.enabledUnitsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(unitID)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}

#if DEBUG
enum DebugDataSeeder {
    @MainActor
    @discardableResult
    static func insertSampleData(in context: ModelContext) throws -> DebugSampleDataSummary {
        try SampleDataSeeder.replaceSamples(in: context)
    }

    @MainActor
    @discardableResult
    static func deleteSampleData(in context: ModelContext) throws -> DebugSampleDataSummary {
        try SampleDataSeeder.deleteSamples(in: context)
    }
}
#endif

private extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
