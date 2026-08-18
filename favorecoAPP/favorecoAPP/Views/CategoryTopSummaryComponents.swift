//
//  CategoryTopSummaryComponents.swift
//  favorecoAPP
//
//  Shared summary strips, memory hero, and compact statistics.
//

import SwiftUI

struct CategoryMemoryHeroSection: View {
    let visits: [Visit]
    let category: RecordCategory
    let tint: Color
    let onOpen: (Visit) -> Void

    var body: some View {
        if let visit = selectedVisit {
            CategoryMemoryHeroCard(
                visit: visit,
                category: category,
                tint: tint,
                onOpen: { onOpen(visit) }
            )
        }
    }

    /// 表示更新のたびに絵が入れ替わらないよう、日単位で安定する1件を選ぶ。
    private var selectedVisit: Visit? {
        let now = Date()
        let candidates = visits
            .filter { $0.visitedAt <= now }
            .sorted {
                if $0.visitedAt != $1.visitedAt { return $0.visitedAt > $1.visitedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        guard let index = CategoryMemoryHeroPolicy.stableIndex(
            itemCount: candidates.count,
            categoryID: category.id,
            now: now,
            calendar: .current
        ) else {
            return nil
        }
        return candidates[index]
    }
}

/// 書籍トップの年次ティッカーと同じ密度で、各ジャンルの要点だけを見せる。
struct CategoryTopStatusStrip: View {
    let items: [CategoryStatisticsItem]
    let tint: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.20))
                        .frame(width: 0.6, height: 20)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(item.title)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(item.value)
                        .font(FavorecoTypography.jpSerif(22, weight: .medium, relativeTo: .title3))
                        .foregroundStyle(tint.opacity(0.88))
                        .monospacedDigit()

                    Text(item.unit)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            items.prefix(3).map { "\($0.title)\($0.value)\($0.unit)" }.joined(separator: "、")
        )
    }
}

/// 縦長アイキャッチでもトップを占有しすぎない、固定高の思い出Hero。
struct CategoryMemoryHeroCard: View {
    let visit: Visit
    let category: RecordCategory
    let tint: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                GeometryReader { geometry in
                    ThumbnailImage(
                        reference: thumbnailReference,
                        displaySize: geometry.size,
                        contentMode: .fill
                    ) {
                        CategoryDefaultArtworkImage(
                            templateKey: category.templateKey,
                            displaySize: geometry.size
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .frame(width: 94, height: 132)
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("MEMORY")
                        .font(FavorecoTypography.jpSans(11, weight: .bold, relativeTo: .caption2))
                        .tracking(1.6)
                        .foregroundStyle(tint)

                    Text(title)
                        .font(FavorecoTypography.jpSerif(22, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        FavorecoIcon(systemName: "calendar", size: 12)
                        Text(FavorecoDateText.compactDate(visit.visitedAt))
                    }
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                    if !venue.isEmpty {
                        HStack(spacing: 5) {
                            FavorecoIcon(systemName: "mappin", size: 12)
                            Text(venue)
                                .lineLimit(1)
                        }
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text("思い出をひらく")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                FavorecoIcon(systemName: "chevron.right", size: 13)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground).opacity(0.82),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("思い出、\(title)、\(FavorecoDateText.compactDate(visit.visitedAt))")
        .accessibilityHint("記録の詳細を開きます")
    }

    private var title: String {
        let eventTitle = visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return eventTitle.isEmpty ? "記録" : eventTitle
    }

    private var venue: String {
        visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var thumbnailReference: ThumbnailReference? {
        if let photo = (visit.photos ?? [])
            .filter(\.hasStoredData)
            .sorted(by: { $0.createdAt < $1.createdAt })
            .first {
            return .photo(photo.id)
        }
        return visit.event.map { .event($0.id) }
    }
}

struct CategoryStatisticsItem: Identifiable {
    let title: String
    let value: String
    let unit: String
    let note: String

    var id: String { title }
}

enum CategoryStatisticsItemBuilder {
    static func make(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        libraryItems: [CategoryLibraryItem],
        visits: [Visit]
    ) -> [CategoryStatisticsItem] {
        let values: [(String, String, String, String)]

        switch category.templateKey {
        case "theater":
            let productionCount = libraryItems.count
            let interestedCount = libraryItems.filter {
                $0.event.stateKey == "interested"
                    && $0.nextPlan == nil
                    && !$0.hasActiveTicketProgress
            }.count
            values = [
                ("作品・公演", "\(productionCount)", "件", "総作品数"),
                ("観劇済み", "\(snapshot.visitCount)", "回", "総観劇数"),
                ("気になる", "\(interestedCount)", "件", "観劇予定"),
            ]
        case "movie":
            values = [
                ("映像作品", "\(snapshot.eventCount)", "作品", "総作品数"),
                ("鑑賞済み", "\(snapshot.visitCount)", "作品", "総鑑賞数"),
                ("気になる", "\(snapshot.interestedEventCount)", "作品", "鑑賞候補"),
            ]
        case "museum":
            let visitedVenueCount = museumVisitedVenueCount(in: visits)
            let viewedEventCount = Set(visits.compactMap { $0.event?.id }).count
            values = [
                ("訪れた館", "\(visitedVenueCount)", "館", "訪問館数"),
                ("鑑賞イベント", "\(viewedEventCount)", "件", "鑑賞済み"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "鑑賞候補"),
            ]
        case "live":
            values = [
                ("ライブ", "\(snapshot.eventCount)", "件", "総公演数"),
                ("参加済み", "\(snapshot.visitCount)", "回", "総参加数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "参加候補"),
            ]
        case "book":
            let readCount = libraryItems.filter { !$0.visits.isEmpty }.count
            let toReadCount = libraryItems.filter {
                $0.event.stateKey == "interested" || $0.visits.isEmpty
            }.count
            values = [
                ("本", "\(libraryItems.count)", "冊", "総登録数"),
                ("読了", "\(readCount)", "冊", "読了した本"),
                ("気になる", "\(toReadCount)", "冊", "気になる・積読"),
            ]
        case "sake":
            values = [
                ("銘柄", "\(snapshot.eventCount)", "本", "総銘柄数"),
                ("飲んだ", "\(snapshot.visitCount)", "回", "総記録数"),
                ("気になる", "\(snapshot.interestedEventCount)", "本", "試飲候補"),
            ]
        case "theme_park":
            values = [
                ("パーク", "\(snapshot.eventCount)", "園", "総登録数"),
                ("来園済み", "\(snapshot.visitCount)", "回", "総来園数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "nature_living":
            values = [
                ("訪れた施設", "\(snapshot.eventCount)", "館", "総施設数"),
                ("訪問済み", "\(snapshot.visitCount)", "回", "総訪問数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "outing_facility":
            values = [
                ("その他施設", "\(snapshot.eventCount)", "件", "未分類を含む"),
                ("訪問済み", "\(snapshot.visitCount)", "回", "総訪問数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "goshuin":
            let visitedPlaceCount = Set(visits.compactMap { $0.event?.id }).count
            values = [
                ("参拝先", "\(visitedPlaceCount)", "寺社", "総参拝先数"),
                ("ご記帳済み", "\(snapshot.visitCount)", "印", "総御朱印数"),
                ("気になる", "\(snapshot.interestedEventCount)", "寺社", "参拝候補"),
            ]
        default:
            let targetTitle = CategoryRecordTemplate.template(for: category).targetSectionTitle
            values = [
                (targetTitle, "\(snapshot.eventCount)", "件", "総登録数"),
                ("体験済み", "\(snapshot.visitCount)", "回", "総体験数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "体験候補"),
            ]
        }

        return values.map {
            CategoryStatisticsItem(title: $0.0, value: $0.1, unit: $0.2, note: $0.3)
        }
    }

    private static func museumVisitedVenueCount(in visits: [Visit]) -> Int {
        Set(visits.compactMap { visit -> String? in
            if let placeID = visit.placeMaster?.id {
                return "place:\(placeID.uuidString)"
            }

            let venueName = visit.venueNameSnapshot
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            return venueName.isEmpty ? nil : "name:\(venueName)"
        }).count
    }
}

struct CategoryStatisticsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    let items: [CategoryStatisticsItem]
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    dividerTint.opacity(0.08),
                                    dividerTint.opacity(0.46),
                                    dividerTint.opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 0.7, height: 70)
                }

                VStack(spacing: 0) {
                    Text(item.title)
                        .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.bottom, 1)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.value)
                            .font(FavorecoTypography.latinDisplay(33, weight: .semibold, relativeTo: .title2))
                            .foregroundStyle(valueColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(item.unit)
                            .font(FavorecoTypography.jpSerif(11, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(unitColor)
                    }

                    Text(item.note)
                        .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                        .foregroundStyle(noteColor)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
            }
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: panelGradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                glowColor,
                                Color.clear,
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 210
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            borderTint.opacity(0.62),
                            borderTint.opacity(0.36),
                            borderTint.opacity(0.52),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("3項目のミニ統計")
    }

    private var dividerTint: Color {
        if isTheater { return TheaterCategoryStyle.lightGold }
        if isLive { return LiveCategoryStyle.lightTeal }
        return tint
    }

    private var borderTint: Color {
        if isTheater { return TheaterCategoryStyle.gold }
        if isLive { return LiveCategoryStyle.teal }
        return tint
    }

    private var titleColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.88) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.88) }
        return Color.primary.opacity(0.82)
    }

    private var valueColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var unitColor: Color {
        if isTheater { return TheaterCategoryStyle.lightGold.opacity(0.78) }
        if isLive { return LiveCategoryStyle.lightTeal.opacity(0.82) }
        return tint.opacity(0.82)
    }

    private var noteColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.48) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.50) }
        return Color.secondary.opacity(0.76)
    }

    private var glowColor: Color {
        if isTheater { return TheaterCategoryStyle.lightGold.opacity(0.09) }
        if isLive { return LiveCategoryStyle.lightTeal.opacity(0.10) }
        return tint.opacity(0.08)
    }

    private var panelGradientColors: [Color] {
        if isTheater {
            return [
                Color(red: 0.105, green: 0.045, blue: 0.055),
                Color(red: 0.078, green: 0.033, blue: 0.043),
                Color(red: 0.046, green: 0.024, blue: 0.030),
            ]
        }
        if isLive {
            return [
                Color(red: 0.030, green: 0.105, blue: 0.125),
                Color(red: 0.020, green: 0.075, blue: 0.094),
                Color(red: 0.010, green: 0.040, blue: 0.054),
            ]
        }
        return [
            Color(.secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.92 : 0.98),
            tint.opacity(colorScheme == .dark ? 0.09 : 0.045),
            Color(.systemBackground).opacity(colorScheme == .dark ? 0.86 : 0.96),
        ]
    }
}
