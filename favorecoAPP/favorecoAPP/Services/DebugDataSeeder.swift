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
    let visitCount: Int
    let planCount: Int
    let ticketAttemptCount: Int

    var insertedMessage: String {
        "記録\(visitCount)件・未来予定\(planCount)件・チケット申込\(ticketAttemptCount)件を追加しました。"
    }

    var deletedMessage: String {
        "記録\(visitCount)件・予定\(planCount)件・チケット申込\(ticketAttemptCount)件を削除しました。ジャンルと有効ユニット設定は残ります。"
    }
}

enum DebugDataSeeder {
    private static let debugURLPrefix = "https://example.com/favoreco/"
    private static let debugPhotoPrefix = "debug/sample-"
    private static let defaultSampleCountPerCategory = 10
    private static let movieSampleCount = 13
    private static let theaterSampleCount = 15

    @MainActor
    @discardableResult
    static func insertSampleData(in context: ModelContext) throws -> DebugSampleDataSummary {
        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: context)
        try deleteSampleData(in: context)

        let categoryDescriptor = FetchDescriptor<RecordCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try context.fetch(categoryDescriptor)
        let now = Date()
        var insertedVisitCount = 0
        var insertedPlanCount = 0
        var insertedTicketAttemptCount = 0

        for (categoryIndex, category) in categories.enumerated() {
            category.isArchived = false
            category.updatedAt = now
            var firstSampleEvent: ExperienceEvent?

            let sampleCount = sampleCount(for: category)
            for sampleIndex in 0..<sampleCount {
                let sampleNumber = sampleIndex + 1
                let title = sampleTitle(for: category, index: sampleIndex)
                let sampleImage = sampleImage(
                    for: category,
                    title: title,
                    index: sampleIndex
                )
                let samplePath = "\(debugPhotoPrefix)\(category.templateKey)-\(sampleNumber).jpg"
                let createdAt = now.addingTimeInterval(TimeInterval(-insertedVisitCount * 86400))
                let event = ExperienceEvent(
                    title: title,
                    seriesName: sampleSeries(for: category, index: sampleIndex),
                    organizerNameSnapshot: sampleOrganizer(for: category),
                    representativeEyecatchPath: samplePath,
                    officialURL: "\(debugURLPrefix)\(category.templateKey)/\(sampleNumber)",
                    memo: "デバッグ用の仮データです。\(category.name)のカード、一覧、詳細、編集導線を確認するために作成しました。",
                    createdAt: createdAt,
                    updatedAt: now,
                    category: category
                )
                let unitFields = VisitUnitFields(
                    ocrText: sampleOCRText(for: category, title: title, index: sampleIndex),
                    eyecatchAspectRatioKey: EyecatchAspectRatio.recommended(for: category).key,
                    goshuinBookSizeKey: category.templateKey == "goshuin" ? sampleGoshuinBookSizeKey(index: sampleIndex) : "",
                    advancedEntries: sampleAdvancedEntries(for: category, index: sampleIndex)
                )
                let visit = Visit(
                    visitedAt: createdAt,
                    endedAt: createdAt.addingTimeInterval(7200),
                    venueNameSnapshot: sampleVenue(for: category, index: sampleIndex),
                    overallRating: sampleRating(index: sampleIndex),
                    outcomeKey: sampleOutcomeKey(for: category, index: sampleIndex),
                    seatText: sampleSeatText(for: category, index: sampleIndex),
                    eyecatchPath: samplePath,
                    note: sampleNote(for: category, title: title, index: sampleIndex),
                    tagNamesRaw: sampleTags(for: category, index: sampleIndex),
                    companionNamesRaw: sampleCompanions(index: sampleIndex),
                    amount: sampleAmount(for: category, index: sampleIndex),
                    unitFieldsRaw: unitFields.encodedRawValue,
                    createdAt: createdAt,
                    updatedAt: now,
                    event: event
                )
                let photo = PhotoBlob(
                    relativePath: samplePath,
                    originalFilename: "sample-\(category.templateKey)-\(sampleNumber).jpg",
                    mediaKind: "photo",
                    purpose: "memory",
                    byteCount: sampleImage.data.count,
                    width: sampleImage.width,
                    height: sampleImage.height,
                    createdAt: createdAt,
                    data: sampleImage.data,
                    visit: visit
                )

                context.insert(event)
                context.insert(visit)
                context.insert(photo)
                if firstSampleEvent == nil {
                    firstSampleEvent = event
                }
                insertedVisitCount += 1
            }

            if let firstSampleEvent {
                let planStart = samplePlanStart(now: now, categoryIndex: categoryIndex)
                let usesDoorTime = ["theater", "live"].contains(category.templateKey)
                let plan = Plan(
                    title: firstSampleEvent.title,
                    subtitle: "デバッグ用の未来予定",
                    planKindKey: samplePlanKind(for: category),
                    stateKey: "planned",
                    startsAt: planStart,
                    endsAt: planStart.addingTimeInterval(2 * 60 * 60),
                    opensAt: usesDoorTime ? planStart.addingTimeInterval(-30 * 60) : Date.distantPast,
                    venueNameSnapshot: sampleVenue(for: category, index: 0),
                    organizerNameSnapshot: sampleOrganizer(for: category),
                    officialURL: "\(debugURLPrefix)\(category.templateKey)/plan",
                    sourceURL: "\(debugURLPrefix)\(category.templateKey)/plan/source",
                    memo: "Homeの次の予定、カレンダー、予定詳細を確認するデバッグ用データです。",
                    notificationLeadTimeKey: "none",
                    createdAt: now,
                    updatedAt: now,
                    category: category,
                    event: firstSampleEvent
                )
                context.insert(plan)
                insertedPlanCount += 1

                if let attempt = sampleTicketAttempt(for: category, plan: plan, planStart: planStart, now: now) {
                    context.insert(attempt)
                    insertedTicketAttemptCount += 1
                }
            }
        }

        if let firstCategory = categories.first {
            context.insert(ExperienceEvent(
                title: "気になる候補",
                officialURL: "\(debugURLPrefix)interested",
                stateKey: "interested",
                memo: "クイック登録後の対象詳細と、予定・記録の追加導線を確認する仮データです。",
                importMemo: "読み取りメモの表示確認用テキスト",
                createdAt: now,
                updatedAt: now,
                category: firstCategory
            ))
        }

        try context.save()
        return DebugSampleDataSummary(
            visitCount: insertedVisitCount,
            planCount: insertedPlanCount,
            ticketAttemptCount: insertedTicketAttemptCount
        )
    }

    @MainActor
    @discardableResult
    static func deleteSampleData(in context: ModelContext) throws -> DebugSampleDataSummary {
        let urlPrefix = debugURLPrefix
        let photoPrefix = debugPhotoPrefix

        let attemptDescriptor = FetchDescriptor<TicketAttempt>(
            predicate: #Predicate { $0.purchaseURL.starts(with: urlPrefix) }
        )
        let debugAttempts = try context.fetch(attemptDescriptor)
        for attempt in debugAttempts {
            TicketNotificationScheduler.cancel(attemptID: attempt.id)
            context.delete(attempt)
        }

        let planDescriptor = FetchDescriptor<Plan>(
            predicate: #Predicate { $0.officialURL.starts(with: urlPrefix) }
        )
        let debugPlans = try context.fetch(planDescriptor)
        for plan in debugPlans {
            TicketNotificationScheduler.cancel(planID: plan.id, attemptID: nil)
            context.delete(plan)
        }

        let visitDescriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { $0.eyecatchPath.starts(with: photoPrefix) }
        )
        let debugVisits = try context.fetch(visitDescriptor)
        let deletedCount = debugVisits.count

        // Delete the records explicitly so category counts cannot retain orphaned visits.
        for visit in debugVisits {
            context.delete(visit)
        }

        let eventDescriptor = FetchDescriptor<ExperienceEvent>(
            predicate: #Predicate { $0.officialURL.starts(with: urlPrefix) }
        )
        for event in try context.fetch(eventDescriptor) {
            context.delete(event)
        }

        let inboxDescriptor = FetchDescriptor<InboxItem>(
            predicate: #Predicate { $0.sourceURL.starts(with: urlPrefix) }
        )
        for item in try context.fetch(inboxDescriptor) {
            context.delete(item)
        }

        try context.save()

        // Visitのcascade対象外になった古い孤立写真も、画像Dataを展開せず一括削除する。
        try context.delete(
            model: PhotoBlob.self,
            where: #Predicate { $0.relativePath.starts(with: photoPrefix) }
        )
        try context.save()
        return DebugSampleDataSummary(
            visitCount: deletedCount,
            planCount: debugPlans.count,
            ticketAttemptCount: debugAttempts.count
        )
    }

    private static func samplePlanStart(now: Date, categoryIndex: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let futureDay = calendar.date(byAdding: .day, value: 2 + categoryIndex * 3, to: now) ?? now
        return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: futureDay) ?? futureDay
    }

    private static func samplePlanKind(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": "screening"
        case "book": "reading"
        case "art": "exhibition"
        case "outing", "goshuin": "visit"
        case "sake": "tasting"
        default: "performance"
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
                ticketSite: "チケットぴあ",
                saleStartAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                applyDeadlineAt: now.addingTimeInterval(24 * 60 * 60),
                resultAnnounceAt: now.addingTimeInterval(3 * 24 * 60 * 60),
                issueStartAt: planStart.addingTimeInterval(-7 * 24 * 60 * 60),
                price: Decimal(12_000),
                purchaseURL: "\(debugURLPrefix)theater/ticket",
                memo: "抽選応募予定から当落待ちまでの表示確認用です。通知は自動予約しません。",
                createdAt: now,
                updatedAt: now,
                plan: plan
            )
        case "live":
            return TicketAttempt(
                statusKey: "waitingPayment",
                entryRouteKey: "fanClub",
                ticketSite: "イープラス",
                resultAnnounceAt: now.addingTimeInterval(-24 * 60 * 60),
                paymentDeadlineAt: now.addingTimeInterval(2 * 24 * 60 * 60),
                issueStartAt: planStart.addingTimeInterval(-5 * 24 * 60 * 60),
                price: Decimal(9_800),
                purchaseURL: "\(debugURLPrefix)live/ticket",
                memo: "当選後の入金待ちと発券予定の表示確認用です。通知は自動予約しません。",
                createdAt: now,
                updatedAt: now,
                plan: plan
            )
        default:
            return nil
        }
    }

    private struct SampleImage {
        let data: Data
        let width: Int
        let height: Int
    }

    private static func sampleImage(for category: RecordCategory, title: String, index: Int) -> SampleImage {
        let resourceIndex = ["movie", "theater", "book"].contains(category.templateKey)
            ? index + 1
            : (index % 3) + 1
        let resourceName = "\(category.templateKey)-\(resourceIndex)"
        let resourceURL = ["jpg", "png"].lazy.compactMap { fileExtension in
            Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
                ?? Bundle.main.url(
                    forResource: resourceName,
                    withExtension: fileExtension,
                    subdirectory: "Resources/DebugSampleImages"
                )
        }.first
        if let url = resourceURL,
           let data = try? Data(contentsOf: url),
           let normalized = normalizedJPEG(from: data) {
            return normalized
        }

        let size = sampleImageSize(for: category, index: index)
        let data = sampleJPEGData(for: category, title: title, index: index, size: size)
        return SampleImage(data: data, width: Int(size.width), height: Int(size.height))
    }

    private static func normalizedJPEG(from data: Data) -> SampleImage? {
        guard let source = UIImage(data: data),
              let cgImage = source.cgImage else {
            return nil
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.82) else {
            return nil
        }
        return SampleImage(data: jpegData, width: cgImage.width, height: cgImage.height)
    }

    private static func sampleJPEGData(for category: RecordCategory, title: String, index: Int, size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let baseColor = UIColor(hexString: category.colorHex)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            baseColor.setFill()
            context.fill(rect)

            let accent = UIColor.white.withAlphaComponent(0.18)
            accent.setFill()
            cgContext.fillEllipse(in: CGRect(
                x: size.width * 0.12,
                y: size.height * 0.08,
                width: size.width * 0.76,
                height: size.width * 0.76
            ))

            UIColor.black.withAlphaComponent(0.18).setFill()
            context.fill(CGRect(
                x: 0,
                y: size.height * 0.68,
                width: size.width,
                height: size.height * 0.32
            ))

            let symbol = sampleSymbol(for: category)
            let symbolAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.24, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            let symbolSize = symbol.size(withAttributes: symbolAttributes)
            symbol.draw(
                at: CGPoint(x: (size.width - symbolSize.width) / 2, y: size.height * 0.28),
                withAttributes: symbolAttributes
            )

            let numberText = String(format: "%02d", index + 1)
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: min(size.width, size.height) * 0.10, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.72)
            ]
            numberText.draw(
                at: CGPoint(x: size.width * 0.08, y: size.height * 0.08),
                withAttributes: numberAttributes
            )

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(18, min(size.width, size.height) * 0.09), weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let categoryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(12, min(size.width, size.height) * 0.052), weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.82)
            ]
            let titleLine = String(title.prefix(12))
            titleLine.draw(
                in: CGRect(x: size.width * 0.08, y: size.height * 0.74, width: size.width * 0.84, height: size.height * 0.12),
                withAttributes: titleAttributes
            )
            category.name.draw(
                in: CGRect(x: size.width * 0.08, y: size.height * 0.87, width: size.width * 0.84, height: size.height * 0.08),
                withAttributes: categoryAttributes
            )
        }
        return image.jpegData(compressionQuality: 0.82) ?? Data()
    }

    private static func sampleImageSize(for category: RecordCategory, index: Int) -> CGSize {
        let ratio = category.templateKey == "goshuin" && sampleGoshuinBookSizeKey(index: index) == GoshuinBookSize.wide.key
            ? EyecatchAspectRatio.labelLandscape.value
            : EyecatchAspectRatio.recommended(for: category).value
        let height: CGFloat = 720
        return CGSize(width: max(360, height * CGFloat(ratio)), height: height)
    }

    private static func sampleTitle(for category: RecordCategory, index: Int) -> String {
        let titles: [String]
        switch category.templateKey {
        case "movie":
            titles = [
                "マトリックス",
                "シン・エヴァンゲリオン劇場版",
                "秒速5センチメートル",
                "スター・ウォーズ／マンダロリアン・アンド・グローグ",
                "悪夢ちゃん The 夢ovie",
                "TITANE／チタン",
                "【推しの子】The Final Act",
                "名探偵コナン 紺青の拳",
                "国宝",
                "気狂いピエロ",
                "ジョーカー",
                "トップガン",
                "ショーシャンクの空に"
            ]
        case "theater":
            titles = [
                "ジェイミー",
                "エリザベート 10th Anniversary",
                "ピーター・パン",
                "CATS",
                "SPY×FAMILY",
                "モアナと伝説の海2",
                "ムーラン・ルージュ！ザ・ミュージカル",
                "パリの恋人",
                "RENT JAPAN TOUR 2018",
                "CITY HUNTER／Fire Fever!",
                "美女と野獣",
                "カラーパープル",
                "ラ・ボエーム ニューヨーク愛の歌",
                "オペラ座の怪人",
                "アルプススタンドのはしの方"
            ]
        case "book":
            titles = [
                "成瀬は都を駆け抜ける",
                "僕のヒーローアカデミア 37",
                "世界の歴史 1 オリエントと地中海の文明",
                "Veil 7",
                "すごいメモ。",
                "余白のノート",
                "海辺の短編集",
                "静かなページ",
                "月曜日の小説",
                "読むための午後"
            ]
        case "sake":
            titles = ["純米吟醸 霞", "山廃 月影", "初しぼり 青嵐", "大吟醸 白露", "にごり 雪待ち", "純米 原風景", "微発泡 星粒", "古酒 琥珀", "生酛 夕凪", "限定酒 花明かり"]
        case "museum":
            titles = ["光の断片展", "静物たちの部屋", "青の近代", "余白の彫刻", "紙と祈りの博物展", "夜の常設展", "色彩のアーカイブ", "小さな工芸展", "記憶の標本室", "風景を集める"]
        case "live":
            titles = ["夏のライブツアー", "Blue Hour", "星屑アリーナ", "週末フェス", "アンコールの夜", "Neon Session", "小さなクラブ公演", "音の記念日", "雨上がりのステージ", "ラストナンバー"]
        case "outing_facility":
            titles = ["海辺の水族館", "夜の展望台", "森の温室", "クラシックホテル", "港の遊園地", "朝の動物園", "湖畔の公園", "古い街並み散歩", "雨の日のプラネタリウム", "夕暮れの庭園"]
        case "goshuin":
            titles = ["青葉神社", "白山寺", "水鏡稲荷", "月守神宮", "花霞寺", "千歳八幡宮", "風待不動尊", "椿森神社", "朝霧観音", "星川天満宮"]
        default:
            titles = (1...defaultSampleCountPerCategory).map { "\(category.name)のサンプル\($0)" }
        }
        return titles[index % titles.count]
    }

    private static func sampleCount(for category: RecordCategory) -> Int {
        switch category.templateKey {
        case "movie": movieSampleCount
        case "theater": theaterSampleCount
        default: defaultSampleCountPerCategory
        }
    }

    private static func sampleSeries(for category: RecordCategory, index: Int) -> String {
        switch category.templateKey {
        case "book": return index.isMultiple(of: 2) ? "旅の本棚" : "夜の読書"
        case "movie": return index.isMultiple(of: 2) ? "週末映画" : "名画座メモ"
        case "sake": return index.isMultiple(of: 2) ? "試飲メモ" : "家飲み記録"
        case "live": return "2026 Tour"
        case "theater": return index.isMultiple(of: 3) ? "東京公演" : ""
        default: return ""
        }
    }

    private static func sampleVenue(for category: RecordCategory, index: Int) -> String {
        let venues: [String]
        switch category.templateKey {
        case "movie": venues = ["favorecoシネマ", "日比谷シアター", "新宿スクリーン", "横浜ミニシアター"]
        case "theater": venues = ["favoreco劇場", "東京芸術劇場", "世田谷パブリックシアター", "小劇場ルミエール"]
        case "museum": venues = ["favoreco美術館", "国立西洋美術館", "東京都美術館", "森の博物館"]
        case "live": venues = ["favorecoホール", "Zepp DiverCity", "日本武道館", "Blue Note Tokyo"]
        case "sake": venues = ["自宅", "日本酒バー 澄", "蔵元試飲会", "友人宅"]
        case "outing_facility": venues = ["favorecoパーク", "海辺の水族館", "港の展望台", "森の植物園"]
        case "goshuin": venues = ["favoreco神社", "青葉神社", "白山寺", "月守神宮"]
        case "book": venues = ["読書メモ", "自宅", "カフェ", "移動中"]
        default: venues = ["favoreco"]
        }
        return venues[index % venues.count]
    }

    private static func sampleOrganizer(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "Favoreco Pictures"
        case "theater": return "Favoreco Stage"
        case "museum": return "Favoreco Museum"
        case "live": return "Favoreco Music"
        default: return ""
        }
    }

    private static func sampleOCRText(for category: RecordCategory, title: String, index: Int) -> String {
        switch category.templateKey {
        case "theater":
            return sampleTheaterOCRText(title: title, index: index)
        case "museum", "live", "movie":
            return "\(title)\n開場 17:30 / 開演 18:30\n電子チケット控え"
        case "book":
            return "\(title)\n気になった一節と読了メモ"
        case "goshuin":
            return "\(title)\n参拝日と御朱印の控え"
        default:
            return ""
        }
    }

    private static func sampleTheaterOCRText(title: String, index: Int) -> String {
        switch index {
        case 10:
            return """
            Disney
            BEAUTY AND THE BEAST
            """
        case 11:
            return """
            カラーパープル
            ゴールデングローブ賞 Wノミネート
            不朽の名作がミュージカルとしてよみがえる！
            2.9 (Fri) 魂の歌声が心を揺さぶる
            """
        case 12:
            return """
            ラ・ボエーム ニューヨーク愛の歌
            新たな感動、圧巻の歌声！ミュージカルに生まれ変わったオペラ最高傑作！
            夢に生きた 愛にもがいた 永遠を信じた
            格差、貧困、マイノリティー
            苦境を前に声の限り命を燃やす、若者たちの青春賛歌
            """
        case 13:
            return "The Phantom of the Opera"
        case 14:
            return """
            アルプススタンドのはしの方
            小野莉奈 / 平井亜門 / 西本まりん / 中村守里 / 黒木ひかり / 平井珠生
            そこは、輝けない私たちのちょっとだけ輝かしい特等席。
            第15回 大阪アジアン映画祭 正式出品作品
            カラー / 16:9 / 5.1ch / 75分
            """
        default:
            return "\(title)\n開場 17:30 / 開演 18:30\n電子チケット控え"
        }
    }

    private static func sampleAdvancedEntries(for category: RecordCategory, index: Int) -> [AdvancedFieldEntry] {
        switch category.templateKey {
        case "sake":
            return [
                AdvancedFieldEntry(label: "精米歩合", value: "\(50 + (index % 5) * 5)%"),
                AdvancedFieldEntry(label: "温度", value: index.isMultiple(of: 2) ? "冷酒" : "常温")
            ]
        case "book":
            return [AdvancedFieldEntry(label: "読書状態", value: index.isMultiple(of: 3) ? "読了" : "読書中")]
        case "goshuin":
            return [AdvancedFieldEntry(label: "御朱印帳", value: GoshuinBookSize.option(for: sampleGoshuinBookSizeKey(index: index)).name)]
        default:
            return []
        }
    }

    private static func sampleGoshuinBookSizeKey(index: Int) -> String {
        GoshuinBookSize.all[index % GoshuinBookSize.all.count].key
    }

    private static func sampleOutcomeKey(for category: RecordCategory, index: Int) -> String {
        guard hasEnabledUnit("ticketPlan", in: category) else { return "" }
        let states = ["planned", "applied", "won", "paid", "ticketed", "attended"]
        return states[index % states.count]
    }

    private static func sampleSeatText(for category: RecordCategory, index: Int) -> String {
        guard hasEnabledUnit("ticketPlan", in: category) else { return "" }
        return "\(1 + index % 3)階 \(8 + index)列 \(12 + index)番"
    }

    private static func hasEnabledUnit(_ unitID: String, in category: RecordCategory) -> Bool {
        category.enabledUnitsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(unitID)
    }

    private static func sampleRating(index: Int) -> Double {
        [4.8, 4.5, 4.2, 5.0, 3.8][index % 5]
    }

    private static func sampleNote(for category: RecordCategory, title: String, index: Int) -> String {
        switch category.templateKey {
        case "goshuin":
            return "\(title)でいただいた御朱印。御朱印帳サイズと画像表示の確認用サンプルです。"
        case "book":
            return "読み終わったあとに残った印象をメモ。書影比率と読書記録の確認用サンプルです。"
        default:
            return "写真付きサンプル記録。アイキャッチ比率、一覧表示、詳細表示の確認用です。"
        }
    }

    private static func sampleTags(for category: RecordCategory, index: Int) -> String {
        ["デバッグ", category.name, index.isMultiple(of: 2) ? "お気に入り" : "確認用"].joined(separator: ",")
    }

    private static func sampleCompanions(index: Int) -> String {
        index.isMultiple(of: 3) ? "友人" : ""
    }

    private static func sampleAmount(for category: RecordCategory, index: Int) -> Decimal {
        switch category.templateKey {
        case "theater", "live": return Decimal(6500 + index * 800)
        case "museum", "movie", "outing_facility": return Decimal(1200 + index * 300)
        case "sake": return Decimal(1800 + index * 450)
        case "book": return Decimal(900 + index * 120)
        default: return Decimal(0)
        }
    }

    private static func sampleSymbol(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "映画"
        case "theater": return "観劇"
        case "book": return "本"
        case "sake": return "酒"
        case "museum": return "展"
        case "live": return "音"
        case "outing_facility": return "旅"
        case "goshuin": return "印"
        default: return String(category.name.prefix(1))
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
