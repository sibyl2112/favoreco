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
    let interestCount: Int
    let catalogOnlyCount: Int
    let ticketAttemptCount: Int

    static let empty = DebugSampleDataSummary(
        eventCount: 0,
        visitCount: 0,
        planCount: 0,
        interestCount: 0,
        catalogOnlyCount: 0,
        ticketAttemptCount: 0
    )

    var insertedMessage: String {
        "ダミー\(eventCount)件（記録\(visitCount)・予定\(planCount)・興味あり\(interestCount)・対象情報\(catalogOnlyCount)）を追加しました。"
    }

    var deletedMessage: String {
        "サンプル\(eventCount)件（記録\(visitCount)件・予定\(planCount)件）を削除しました。通常の記録とマスターは残ります。"
    }
}

enum SampleDataSeeder {
    static let sampleURLPrefix = "https://sample.favoreco.app/v3/"
    static let samplePhotoPrefix = "sample/v3/"

    private static let previousURLPrefix = "https://sample.favoreco.app/v2/"
    private static let previousPhotoPrefix = "sample/v2/"
    private static let legacyURLPrefix = "https://example.com/favoreco/"
    private static let legacyPhotoPrefix = "debug/sample-"
    private static let sampleMasterMarker = "favoreco-sample-v3"
    private static let automaticInsertionKey = "hasInsertedAutomaticSampleDataV3"
    private static let completedPerCategory = 5
    private static let plannedPerCategory = 3
    private static let interestedPerCategory = 3
    private static let catalogOnlyPerCategory = 5
    private static let samplesPerCategory = completedPerCategory
        + plannedPerCategory
        + interestedPerCategory
        + catalogOnlyPerCategory

    private enum SampleScenario: Equatable {
        case completed
        case planned
        case interested
        case catalogOnly
    }

    @MainActor
    @discardableResult
    static func insertAutomaticSamples(
        in context: ModelContext,
        categoryTemplateKeys: Set<String>
    ) throws -> DebugSampleDataSummary {
        // 大量の検証データを意図せず投入しない。現在は開発者設定からのみ作成する。
        _ = context
        _ = categoryTemplateKeys
        UserDefaults.standard.set(true, forKey: automaticInsertionKey)
        return .empty
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
            !category.isArchived
                && (categoryTemplateKeys?.contains(category.templateKey) ?? true)
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
        var interestCount = 0
        var catalogOnlyCount = 0
        var ticketAttemptCount = 0

        for (categoryIndex, category) in categories.enumerated() {
            // 同じジャンルの16件は共通の軽量サンプル画像を使う。
            // Bundle読み込みとUIImageデコードを各レコードで繰り返さない。
            let categoryImage = sampleImage(for: category, index: 0)
            for sampleIndex in 0..<samplesPerCategory {
                let scenario = sampleScenario(for: sampleIndex)
                if category.templateKey == "random_goods" {
                    insertCollectibleSample(
                        category: category,
                        categoryIndex: categoryIndex,
                        sampleIndex: sampleIndex,
                        scenario: scenario,
                        image: categoryImage,
                        now: now,
                        context: context
                    )
                    eventCount += 1
                    switch scenario {
                    case .interested: interestCount += 1
                    case .catalogOnly: catalogOnlyCount += 1
                    default: break
                    }
                    continue
                }

                let definition = sampleDefinition(for: category, index: sampleIndex)
                let image = categoryImage
                let imagePath = "\(samplePhotoPrefix)\(category.templateKey).jpg"
                let itemDate = sampleDate(
                    now: now,
                    categoryIndex: categoryIndex,
                    sampleIndex: sampleIndex,
                    scenario: scenario
                )
                let aspectRatioKey = sampleAspectRatioKey(for: category)
                let placeSeed = samplePlace(for: category, index: sampleIndex)
                let unitFields = VisitUnitFields(
                    ocrText: sampleOCRText(for: category, title: definition.title),
                    visitSubtitle: category.templateKey == "nature_living" && scenario == .completed
                        ? natureVisitSubtitle(for: sampleIndex)
                        : "",
                    eventPeriodStartsAt: scenario == .catalogOnly ? itemDate : nil,
                    eventPeriodEndsAt: scenario == .catalogOnly
                        ? itemDate.addingTimeInterval(14 * 24 * 60 * 60)
                        : nil,
                    eventVenues: scenario == .catalogOnly
                        ? [EventVenueEntry(
                            name: placeSeed.name,
                            address: placeSeed.address,
                            performanceLabel: targetInformationLabel(for: category),
                            startsAt: itemDate,
                            endsAt: itemDate.addingTimeInterval(14 * 24 * 60 * 60)
                        )]
                        : [],
                    screenWorkSeasonNumber: sampleScreenWorkSeasonNumber(
                        for: category,
                        index: sampleIndex
                    ),
                    eyecatchAspectRatioKey: aspectRatioKey,
                    goshuinBookSizeKey: category.templateKey == "goshuin" ? GoshuinBookSize.standard.key : "",
                    advancedEntries: sampleAdvancedEntries(for: category, index: sampleIndex),
                    bookSeriesName: "",
                    bookVolumeNumber: "",
                    bookAuthorName: "",
                    bookPublisherName: ""
                )
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
                    stateKey: scenario == .interested ? "interested" : "active",
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

                if scenario == .planned {
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
                } else if scenario == .completed {
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
                } else if scenario == .interested {
                    interestCount += 1
                } else {
                    catalogOnlyCount += 1
                }
            }
        }

        try context.save()
        return DebugSampleDataSummary(
            eventCount: eventCount,
            visitCount: visitCount,
            planCount: planCount,
            interestCount: interestCount,
            catalogOnlyCount: catalogOnlyCount,
            ticketAttemptCount: ticketAttemptCount
        )
    }

    @MainActor
    @discardableResult
    static func deleteSamples(in context: ModelContext) throws -> DebugSampleDataSummary {
        let currentURLPrefix = sampleURLPrefix
        let priorURLPrefix = Self.previousURLPrefix
        let oldURLPrefix = legacyURLPrefix
        let currentPhotoPrefix = samplePhotoPrefix
        let priorPhotoPrefix = Self.previousPhotoPrefix
        let oldPhotoPrefix = legacyPhotoPrefix

        let sampleEvents = try context.fetch(FetchDescriptor<ExperienceEvent>(
            predicate: #Predicate {
                $0.officialURL.starts(with: currentURLPrefix)
                    || $0.officialURL.starts(with: priorURLPrefix)
                    || $0.officialURL.starts(with: oldURLPrefix)
            }
        ))
        let samplePlans = try context.fetch(FetchDescriptor<Plan>(
            predicate: #Predicate {
                $0.officialURL.starts(with: currentURLPrefix)
                    || $0.officialURL.starts(with: priorURLPrefix)
                    || $0.officialURL.starts(with: oldURLPrefix)
            }
        ))
        let sampleAttempts = try context.fetch(FetchDescriptor<TicketAttempt>(
            predicate: #Predicate {
                $0.purchaseURL.starts(with: currentURLPrefix)
                    || $0.purchaseURL.starts(with: priorURLPrefix)
                    || $0.purchaseURL.starts(with: oldURLPrefix)
            }
        ))
        let sampleVisits = try context.fetch(FetchDescriptor<Visit>(
            predicate: #Predicate {
                $0.eyecatchPath.starts(with: currentPhotoPrefix)
                    || $0.eyecatchPath.starts(with: priorPhotoPrefix)
                    || $0.eyecatchPath.starts(with: oldPhotoPrefix)
            }
        ))
        let interestCount = sampleEvents.filter { $0.stateKey == "interested" }.count
        let catalogOnlyCount = sampleEvents.filter {
            $0.stateKey != "interested"
                && ($0.visits ?? []).isEmpty
                && ($0.plans ?? []).isEmpty
        }.count

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
            where: #Predicate { $0.relativePath.starts(with: priorPhotoPrefix) }
        )
        try context.delete(
            model: PhotoBlob.self,
            where: #Predicate { $0.relativePath.starts(with: oldPhotoPrefix) }
        )
        try context.save()

        return DebugSampleDataSummary(
            eventCount: sampleEvents.count,
            visitCount: sampleVisits.count,
            planCount: samplePlans.count,
            interestCount: interestCount,
            catalogOnlyCount: catalogOnlyCount,
            ticketAttemptCount: sampleAttempts.count
        )
    }

    static func isSampleEvent(_ event: ExperienceEvent) -> Bool {
        event.officialURL.starts(with: sampleURLPrefix)
            || event.officialURL.starts(with: previousURLPrefix)
            || event.officialURL.starts(with: legacyURLPrefix)
    }

    static func resetAutomaticInsertionState() {
        UserDefaults.standard.set(false, forKey: automaticInsertionKey)
    }

    @MainActor
    @discardableResult
    static func refreshBundledTheaterSampleEyecatches(
        in context: ModelContext
    ) throws -> Int {
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        var refreshedCount = 0

        for event in events where isSampleEvent(event) {
            guard let category = event.category,
                  category.templateKey == "theater",
                  let sampleIndex = theaterSampleIndex(for: event, category: category) else {
                continue
            }
            let image = sampleImage(for: category, index: sampleIndex)
            let expectedPath = "\(samplePhotoPrefix)theater.jpg"
            var unitFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            let expectedRatioKey = EyecatchAspectRatio.bSeriesPoster.key
            let needsRefresh = event.eyecatchData != image.data
                || event.representativeEyecatchPath != expectedPath
                || unitFields.eyecatchAspectRatioKey != expectedRatioKey
            guard needsRefresh else { continue }

            event.eyecatchData = image.data
            event.representativeEyecatchPath = expectedPath
            unitFields.eyecatchAspectRatioKey = expectedRatioKey
            event.unitFieldsRaw = unitFields.encodedRawValue
            event.updatedAt = Date()
            refreshedCount += 1
        }

        if refreshedCount > 0 {
            try context.save()
        }
        return refreshedCount
    }

    private static func theaterSampleIndex(
        for event: ExperienceEvent,
        category: RecordCategory
    ) -> Int? {
        if let lastComponent = URL(string: event.officialURL)?.lastPathComponent,
           let oneBasedIndex = Int(lastComponent),
           (1...samplesPerCategory).contains(oneBasedIndex) {
            return oneBasedIndex - 1
        }

        return (0..<samplesPerCategory).first { sampleIndex in
            sampleDefinition(for: category, index: sampleIndex).title == event.title
        }
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
        var catalogID: String = ""
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
        scenario: SampleScenario,
        image: SampleImage,
        now: Date,
        context: ModelContext
    ) {
        let definition = collectibleSampleDefinition(index: sampleIndex)
        let itemDate = sampleDate(
            now: now,
            categoryIndex: categoryIndex,
            sampleIndex: sampleIndex,
            scenario: scenario
        )
        let event = ExperienceEvent(
            title: definition.title,
            seriesName: definition.releaseText,
            subTypeKey: definition.kind.rawValue,
            organizerNameSnapshot: definition.maker,
            representativeEyecatchPath: "\(samplePhotoPrefix)random_goods.jpg",
            officialURL: "\(sampleURLPrefix)random_goods/\(sampleIndex + 1)",
            stateKey: scenario == .interested ? "interested" : "active",
            memo: "種類別の所持数、未入手、ダブり、コンプリート表示を確認するサンプルです。",
            unitFieldsRaw: VisitUnitFields(
                eventSubtitle: scenario == .planned ? "発売予定" : "",
                eventPeriodStartsAt: scenario == .planned ? itemDate : nil,
                eventPeriodEndsAt: nil,
                eyecatchAspectRatioKey: sampleAspectRatioKey(for: category)
            ).encodedRawValue,
            createdAt: itemDate,
            updatedAt: now,
            eyecatchData: image.data,
            category: category
        )
        context.insert(event)

        // 所持履歴は「体験済み」に相当する5シリーズだけへ付与する。
        guard scenario == .completed else { return }
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
        let baseDefinitions = [
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
        let titles = [
            "星空どうぶつカプセル", "月影アクリルチャーム", "花色缶バッジコレクション",
            "夜空のピンバッジ", "小さな旅のキーホルダー", "雨音ステッカーセット",
            "灯台ミニチュア", "青のポストカード", "次のカプセルトイ",
            "新作アクリルスタンド", "限定ピンバッジが気になる", "星座チャームシリーズ",
            "喫茶店モチーフ雑貨", "四季の缶バッジ", "旅するマスコット", "月夜の紙もの"
        ]
        let base = baseDefinitions[index % baseDefinitions.count]
        return CollectibleSampleDefinition(
            title: titles[index % titles.count],
            releaseText: index >= completedPerCategory ? "2026年 発売予定" : base.releaseText,
            kind: base.kind,
            maker: base.maker,
            itemNames: base.itemNames,
            acquiredQuantities: base.acquiredQuantities,
            unitPrice: base.unitPrice,
            outgoingItemIndex: base.outgoingItemIndex
        )
    }

    private static func sampleDefinition(for category: RecordCategory, index: Int) -> SampleDefinition {
        let titles: [String]
        let seriesName: String
        let organizer: String
        switch category.templateKey {
        case "theater":
            titles = ["月影のアトリエ", "雨音の王国", "星屑の航路", "冬庭の手紙", "透明な客席", "青い鳥の約束", "灯台のワルツ", "夜明け前の標本", "風待ちホテル", "銀河の余白", "カーテンコールのあと", "遠雷のレクイエム", "春を待つ劇場", "黄昏のリハーサル", "白昼夢の幕間", "海辺のモノローグ"]
            seriesName = "シリーズ名"
            organizer = "灯台座"
        case "museum":
            titles = ["透明な記憶", "風を採集する", "深海の光譜", "植物と金属", "余白の地図", "光の粒子展", "青の考古学", "手ざわりの宇宙", "季節を編む", "静物の呼吸", "水脈のデザイン", "未来の民藝", "雲を測る", "夜の博物誌", "小さな建築", "色彩の標本"]
            seriesName = "企画展"
            organizer = "架空文化企画室"
        case "live":
            titles = ["LUMINA TOUR", "ECHOES AT DAWN", "NEON TIDE", "Moonlit Signals", "CITY LIGHTS", "Glass Horizon", "BLUE HOUR", "Parallel Lines", "Afterglow Session", "Northern Echo", "Silent Parade", "Prism Night", "Coastal Frequency", "Starlight Archive", "Dawn Circuit", "Amber Resonance"]
            seriesName = "2026 TOUR"
            organizer = "North Light Music"
        case "movie":
            titles = ["夜を編む人", "光のメトロノーム", "白い海の記憶", "雨の駅で", "水平線の手紙", "時計塔の迷子", "花束と彗星", "夏の残像", "北風の食卓", "透明な午後", "砂丘の図書館", "冬眠する街", "月を運ぶ船", "静かな交差点", "最後の青信号", "星のない夜"]
            seriesName = ""
            organizer = "Orion Pictures"
        case "sake":
            titles = ["月灯り 純米吟醸", "山凪 クラフトビール", "燻樹 シングルモルト", "白雨 純米酒", "夕凪 ペールエール", "森影 ジン", "雪解け にごり酒", "青葉 セゾン", "麦星 ウイスキー", "花霞 ロゼ", "宵月 大吟醸", "潮風 ラガー", "木漏れ日 リキュール", "冬灯り 古酒", "朝霧 サワー", "深緑 ボタニカルジン"]
            seriesName = "試飲ノート"
            organizer = ""
        case "theme_park":
            titles = ["東京ディズニーランド", "ユニバーサル・スタジオ・ジャパン", "富士急ハイランド", "サンリオピューロランド", "東京ディズニーシー", "夜のパーク散策", "季節のパレード", "アトラクション巡り", "次のテーマパーク", "イルミネーション候補", "新エリアが気になる", "休日のパーク計画", "春のスペシャルイベント", "夏のナイトプログラム", "秋のフェスティバル", "冬のライトアップ"]
            seriesName = ""
            organizer = ""
        case "nature_living":
            titles = ["海遊館", "沖縄美ら海水族館", "旭山動物園", "名古屋港水族館", "鳥羽水族館", "葛西臨海水族園", "神戸どうぶつ王国", "京都府立植物園", "すみだ水族館", "新江ノ島水族館", "神代植物公園", "サンシャイン水族館", "上野動物園", "夢の島熱帯植物館", "アクアマリンふくしま", "掛川花鳥園"]
            seriesName = ""
            organizer = ""
        case "outing_facility":
            titles = ["東京スカイツリー", "大阪城天守閣", "せんだいメディアテーク", "横浜赤レンガ倉庫", "京都タワー", "展望台へ行く", "建築を見に行く", "港エリアを散策", "夜景スポットが気になる", "歴史施設が気になる", "文化施設を調べる", "屋上庭園の特別公開", "近代建築ツアー", "街を眺める展望イベント", "期間限定ライトアップ", "水辺の文化プログラム"]
            seriesName = ""
            organizer = ""
        case "goshuin":
            titles = ["明治神宮", "浅草寺", "伏見稲荷大社", "伊勢神宮 内宮", "伊勢神宮 外宮", "次の神社参拝", "次の寺院参拝", "御朱印帳を持って巡る", "季節の御朱印が気になる", "静かな境内を訪ねたい", "建築を見に行きたい", "夏越の祓", "秋季例大祭", "紅葉の特別拝観", "初詣", "春の限定御朱印"]
            seriesName = "参拝の記録"
            organizer = ""
        case "book":
            titles = ["夜明けの標本室", "雨粒の図書館", "北へ帰る鳥", "月光庭園", "静かな航海日誌", "星を数える部屋", "風の脚注", "冬の栞", "透明な物語", "遠雷のエッセイ", "海辺の短編集", "森を読む", "夜行列車の随筆", "青い装丁の詩集", "小さな博物誌", "灯台守の手紙"]
            // 書誌情報はISBN検索またはユーザー入力だけを正とし、サンプル生成では捏造しない。
            seriesName = ""
            organizer = ""
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

    private static func natureVisitSubtitle(for index: Int) -> String {
        ["クラゲ展示", "夜の水族館", "ペンギンの生態展示", "珊瑚礁の企画展示", "温室の特別公開"][index % 5]
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
                .init(catalogID: "jp-tokyo-national-art-center", name: "国立新美術館", reading: "こくりつしんびじゅつかん", tags: "art_museum,museum,cultural_facility", prefecture: "東京都", address: "東京都港区六本木7-22-2", officialURL: "https://www.nact.jp/"),
                .init(catalogID: "jp-tokyo-tokyo-national-museum", name: "東京国立博物館", reading: "とうきょうこくりつはくぶつかん", tags: "museum,cultural_facility,historic_site", prefecture: "東京都", address: "東京都台東区上野公園13-9", officialURL: "https://www.tnm.jp/"),
                .init(catalogID: "jp-tokyo-national-museum-nature-science", name: "国立科学博物館", reading: "こくりつかがくはくぶつかん", tags: "museum,science_museum,cultural_facility", prefecture: "東京都", address: "東京都台東区上野公園7-20", officialURL: "https://www.kahaku.go.jp/")
            ]
        case "live":
            places = [
                .init(catalogID: "jp-tokyo-tokyo-dome", name: "東京ドーム", reading: "とうきょうどーむ", tags: "dome,stadium,live_venue", prefecture: "東京都", address: "東京都文京区後楽1-3-61", officialURL: "https://www.tokyo-dome.co.jp/dome/"),
                .init(catalogID: "jp-tokyo-nippon-budokan", name: "日本武道館", reading: "にっぽんぶどうかん", tags: "arena,live_venue,landmark", prefecture: "東京都", address: "東京都千代田区北の丸公園2-3", officialURL: "https://www.nipponbudokan.or.jp/"),
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
                .init(catalogID: "jp-chiba-tokyo-disneyland", name: "東京ディズニーランド", reading: "とうきょうでぃずにーらんど", tags: "theme_park,leisure_facility", prefecture: "千葉県", address: "千葉県浦安市舞浜1-1", officialURL: "https://www.tokyodisneyresort.jp/tdl/"),
                .init(catalogID: "jp-osaka-universal-studios-japan", name: "ユニバーサル・スタジオ・ジャパン", reading: "ゆにばーさるすたじおじゃぱん", tags: "theme_park,leisure_facility", prefecture: "大阪府", address: "大阪府大阪市此花区桜島2-1-33", officialURL: "https://www.usj.co.jp/web/"),
                .init(name: "ハウステンボス", reading: "はうすてんぼす", tags: "theme_park,leisure_facility", prefecture: "長崎県", address: "長崎県佐世保市ハウステンボス町1-1", officialURL: "https://www.huistenbosch.co.jp/")
            ]
        case "nature_living":
            places = [
                .init(catalogID: "jp-osaka-kaiyukan", name: "海遊館", reading: "かいゆうかん", tags: "aquarium,museum,leisure_facility", prefecture: "大阪府", address: "大阪府大阪市港区海岸通1-1-10", officialURL: "https://www.kaiyukan.com/"),
                .init(name: "上野動物園", reading: "うえのどうぶつえん", tags: "zoo,leisure_facility", prefecture: "東京都", address: "東京都台東区上野公園9-83", officialURL: "https://www.tokyo-zoo.net/zoo/ueno/"),
                .init(name: "あしかがフラワーパーク", reading: "あしかがふらわーぱーく", tags: "botanical_garden,garden,leisure_facility", prefecture: "栃木県", address: "栃木県足利市迫間町607", officialURL: "https://www.ashikaga.co.jp/")
            ]
        case "outing_facility":
            places = [
                .init(catalogID: "jp-tokyo-tokyo-skytree", name: "東京スカイツリー", reading: "とうきょうすかいつりー", tags: "tower,observation_deck,landmark", prefecture: "東京都", address: "東京都墨田区押上1-1-2", officialURL: "https://www.tokyo-skytree.jp/"),
                .init(name: "大阪城天守閣", reading: "おおさかじょうてんしゅかく", tags: "castle,museum,historic_site", prefecture: "大阪府", address: "大阪府大阪市中央区大阪城1-1", officialURL: "https://www.osakacastle.net/"),
                .init(name: "せんだいメディアテーク", reading: "せんだいめでぃあてーく", tags: "library,architecture,cultural_facility", prefecture: "宮城県", address: "宮城県仙台市青葉区春日町2-1", officialURL: "https://www.smt.jp/")
            ]
        case "goshuin":
            places = [
                .init(catalogID: "jp-tokyo-meiji-jingu", name: "明治神宮", reading: "めいじじんぐう", tags: "shrine,landmark", prefecture: "東京都", address: "東京都渋谷区代々木神園町1-1", officialURL: "https://www.meijijingu.or.jp/"),
                .init(catalogID: "jp-tokyo-sensoji", name: "浅草寺", reading: "せんそうじ", tags: "temple,historic_site,landmark", prefecture: "東京都", address: "東京都台東区浅草2-3-1", officialURL: "https://www.senso-ji.jp/"),
                .init(catalogID: "jp-kyoto-fushimi-inari-taisha", name: "伏見稲荷大社", reading: "ふしみいなりたいしゃ", tags: "shrine,historic_site,landmark", prefecture: "京都府", address: "京都府京都市伏見区深草薮之内町68", officialURL: "https://inari.jp/")
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
            if !seed.catalogID.isEmpty {
                existing.sourceSnapshotRaw = "favoreco.public-place-catalog:\(seed.catalogID)"
                if existing.reading.isEmpty { existing.reading = seed.reading }
                if existing.placeTagsRaw.isEmpty { existing.placeTagsRaw = seed.tags }
                if existing.prefecture.isEmpty { existing.prefecture = seed.prefecture }
                if existing.address.isEmpty { existing.address = seed.address }
                if existing.officialURL.isEmpty { existing.officialURL = seed.officialURL }
                existing.updatedAt = now
            }
            return existing
        }
        let place = PlaceMaster(
            name: seed.name,
            reading: seed.reading,
            placeTagsRaw: seed.tags,
            prefecture: seed.prefecture,
            address: seed.address,
            officialURL: seed.officialURL,
            memo: seed.catalogID.isEmpty
                ? "サンプル用の場所マスターです。"
                : "公式確認済みの共通場所カタログから登録しました。",
            sourceSnapshotRaw: seed.catalogID.isEmpty
                ? sampleMasterMarker
                : "favoreco.public-place-catalog:\(seed.catalogID)",
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
        let resourceName = "v3-\(category.templateKey)"
        let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg")
            ?? Bundle.main.url(
                forResource: resourceName,
                withExtension: "jpg",
                subdirectory: "Resources/SampleDataImagesV3"
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
        let maxDimension: CGFloat = ["live", "random_goods"].contains(category.templateKey)
            ? 640
            : 768
        let size: CGSize
        if ratio >= 1 {
            size = CGSize(width: maxDimension, height: maxDimension / CGFloat(ratio))
        } else {
            size = CGSize(width: maxDimension * CGFloat(ratio), height: maxDimension)
        }
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
        let data = image.jpegData(compressionQuality: 0.60) ?? Data()
        return SampleImage(data: data, width: Int(size.width), height: Int(size.height))
    }

    private static func samplePastDate(now: Date, categoryIndex: Int, sampleIndex: Int) -> Date {
        let daysAgo = 18 + categoryIndex * 7 + sampleIndex * 23
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    private static func sampleFutureDate(now: Date, categoryIndex: Int, offset: Int = 0) -> Date {
        let day = Calendar.current.date(
            byAdding: .day,
            value: 5 + categoryIndex * 3 + offset * 7,
            to: now
        ) ?? now
        return Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
    }

    private static func sampleScenario(for index: Int) -> SampleScenario {
        if index < completedPerCategory { return .completed }
        if index < completedPerCategory + plannedPerCategory { return .planned }
        if index < completedPerCategory + plannedPerCategory + interestedPerCategory {
            return .interested
        }
        return .catalogOnly
    }

    private static func sampleDate(
        now: Date,
        categoryIndex: Int,
        sampleIndex: Int,
        scenario: SampleScenario
    ) -> Date {
        switch scenario {
        case .completed:
            return samplePastDate(
                now: now,
                categoryIndex: categoryIndex,
                sampleIndex: sampleIndex
            )
        case .planned:
            return sampleFutureDate(
                now: now,
                categoryIndex: categoryIndex,
                offset: sampleIndex - completedPerCategory
            )
        case .interested:
            return now.addingTimeInterval(TimeInterval(sampleIndex) * -60)
        case .catalogOnly:
            let offset = sampleIndex
                - completedPerCategory
                - plannedPerCategory
                - interestedPerCategory
            return sampleFutureDate(
                now: now,
                categoryIndex: categoryIndex,
                offset: offset + plannedPerCategory + 1
            )
        }
    }

    private static func targetInformationLabel(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "theater", "live": return "公演情報"
        case "museum": return "展示情報"
        case "movie": return "上映情報"
        case "book": return "刊行情報"
        case "theme_park", "nature_living", "outing_facility", "goshuin": return "施設情報"
        default: return "対象情報"
        }
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
        case "movie":
            return [ScreenWorkType.movie, .drama, .anime][index % 3].rawValue
        default:
            return ""
        }
    }

    private static func sampleScreenWorkSeasonNumber(
        for category: RecordCategory,
        index: Int
    ) -> Int {
        guard category.templateKey == "movie" else { return 0 }
        switch ScreenWorkType.resolved(from: sampleSubTypeKey(for: category, index: index)) {
        case .movie: return 0
        case .drama: return 1
        case .anime: return 2
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
                memo: "支払待ち表示を確認するサンプルです。通知は予約しません。",
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
struct DebugDataRebuildSummary {
    let deletedCount: Int
    let inserted: DebugSampleDataSummary

    var message: String {
        "体験データ\(deletedCount)件を削除し、\(inserted.insertedMessage)"
    }
}

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

    @MainActor
    @discardableResult
    static func rebuildAllExperienceData(
        in context: ModelContext
    ) throws -> DebugDataRebuildSummary {
        let deletion = try RecordDeletionService.deleteAllExperienceDataPreservingMasters(
            in: context
        )
        let inserted = try SampleDataSeeder.replaceSamples(in: context)
        return DebugDataRebuildSummary(
            deletedCount: deletion.deletedModelCount,
            inserted: inserted
        )
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
