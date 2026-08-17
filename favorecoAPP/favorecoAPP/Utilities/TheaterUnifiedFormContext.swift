import SwiftUI

/// 観劇の公演登録から観劇後の記録までを、同じ情報構造で見せ分けるための入口。
enum TheaterUnifiedFormEntry: String, CaseIterable, Identifiable {
    case performanceRegistration
    case planCreation
    case visitCreation
    case visitEditing
    case performanceEditing
    case planEditing

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .performanceRegistration: "公演を登録"
        case .planCreation: "観劇予定を追加"
        case .visitCreation: "観劇記録を追加"
        case .visitEditing: "観劇記録を編集"
        case .performanceEditing: "公演情報を編集"
        case .planEditing: "観劇予定を編集"
        }
    }

    var guidance: String {
        switch self {
        case .performanceRegistration:
            "まずタイトルだけでも保存できます。必要な情報は後から追加できます。"
        case .planCreation:
            "公演情報を引き継ぎ、参加する日時と会場を登録します。"
        case .visitCreation:
            "公演情報を引き継ぎ、体験日程・座席・写真・感想・金額を記録できます。"
        case .visitEditing:
            "予定を引き継ぎ、座席・写真・感想・金額を記録できます。"
        case .performanceEditing:
            "公演そのものの公式情報を編集します。観劇ごとの情報は変更しません。"
        case .planEditing:
            "公演情報はそのまま、参加する日時と会場を更新します。"
        }
    }

    func scope(isLive: Bool) -> String {
        let performanceName = isLive ? "ライブ" : "公演"
        let planName = isLive ? "参戦予定" : "観劇予定"
        let visitName = isLive ? "この参戦回だけ" : "この観劇回だけ"
        return switch self {
        case .performanceRegistration, .performanceEditing:
            "この\(performanceName)のすべての予定・記録"
        case .planCreation, .planEditing:
            "この\(planName)だけ"
        case .visitCreation, .visitEditing:
            visitName
        }
    }

    var initiallyExpandedSections: Set<TheaterUnifiedFormSection> {
        switch self {
        case .performanceRegistration:
            [.performanceBasic]
        case .performanceEditing:
            [.performanceBasic, .venueSchedule]
        case .planCreation, .planEditing:
            [.performanceBasic, .participation]
        case .visitCreation, .visitEditing:
            [.performanceBasic, .participation, .viewing, .photos]
        }
    }

    func visibility(of section: TheaterUnifiedFormSection) -> TheaterUnifiedSectionVisibility {
        switch self {
        case .performanceRegistration, .performanceEditing:
            return section.isPerformanceSection ? .visible : .hidden
        case .planCreation, .planEditing:
            switch section {
            case .performanceBasic, .participation, .tasks, .viewing, .photos:
                return .visible
            default:
                return .hidden
            }
        case .visitCreation, .visitEditing:
            return section == .importDetails ? .hidden : .visible
        }
    }
}

enum TheaterUnifiedSectionVisibility {
    case visible
    case hidden
}

enum TheaterUnifiedFormSection: String, CaseIterable, Identifiable {
    case performanceBasic
    case venueSchedule
    case performanceDetails
    case importDetails
    case participation
    case tasks
    case viewing
    case photos
    case impressions
    case totals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .performanceBasic: "公演基本情報"
        case .venueSchedule: "会期・会場"
        case .performanceDetails: "公演詳細情報"
        case .importDetails: "読み取り情報"
        case .participation: "体験日程"
        case .tasks: "やる事リスト"
        case .viewing: "鑑賞記録"
        case .photos: "写真・アイキャッチ"
        case .impressions: "感想記録"
        case .totals: "集計記録"
        }
    }

    var summary: String {
        switch self {
        case .performanceBasic: "タイトル・種別・ビジュアル・公式URL"
        case .venueSchedule: "会場と会期を複数追加"
        case .performanceDetails: "主催・SNS・出演者・メモ"
        case .importDetails: "URL・OCRから取得した原文"
        case .participation: "日付・開場・開演・終了"
        case .tasks: "当日までの準備"
        case .viewing: "鑑賞方法・座席・注目した人"
        case .photos: "この回のアイキャッチ・観劇の写真"
        case .impressions: "評価・感情タグ・自由メモ"
        case .totals: "金額・レシート読み取り"
        }
    }

    var isPerformanceSection: Bool {
        switch self {
        case .performanceBasic, .venueSchedule, .performanceDetails, .importDetails:
            true
        default:
            false
        }
    }
}

struct TheaterUnifiedFormIntroduction: View {
    let entry: TheaterUnifiedFormEntry
    var isLive = false

    var body: some View {
        EditScopeNotice(
            scope: entry.scope(isLive: isLive),
            detail: liveAdjustedGuidance
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var liveAdjustedGuidance: String {
        guard isLive else { return entry.guidance }
        return switch entry {
        case .performanceRegistration:
            "まず公演名だけでも保存できます。アーティストや日程は後から追加できます。"
        case .planCreation:
            "ライブ情報を引き継ぎ、参戦する日時と会場を登録します。"
        case .visitCreation:
            "ライブ情報を引き継ぎ、参戦日時・写真・感想・セトリを記録できます。"
        case .visitEditing:
            "予定を引き継ぎ、写真・感想・同行者・セトリを記録できます。"
        case .performanceEditing:
            "ライブそのものの公式情報を編集します。参戦ごとの情報は変更しません。"
        case .planEditing:
            "ライブ情報はそのまま、参戦する日時と会場を更新します。"
        }
    }
}

struct TheaterUnifiedSectionLabel: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    let section: TheaterUnifiedFormSection
    var isLive = false
    var summaryOverride: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sectionTitle)
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(themePalette.registrationSectionHeaderTint)
                Text(sectionSummary)
                    .font(FavorecoTypography.jpSans(9.5, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(ExplicitFormMetrics.canvasSupportingTextColor(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
        }
        .textCase(nil)
    }

    private var sectionTitle: String {
        guard isLive else { return section.title }
        return switch section {
        case .viewing: "参戦記録"
        case .impressions: "感想・タグ"
        default: section.title
        }
    }

    private var sectionSummary: String {
        if let summaryOverride { return summaryOverride }
        guard isLive else { return section.summary }
        return switch section {
        case .performanceBasic: "公演名・アーティスト・種別・公式URL"
        case .venueSchedule: "開催日程・会場・公演メモ"
        case .performanceDetails: "SNS・制作情報・読み取り情報"
        case .participation: "参戦日・開場・開演・終了"
        case .viewing: "チケット・座席・同行者・タグ"
        case .photos: "この回のアイキャッチ・ライブの写真"
        default: section.summary
        }
    }
}

/// 横スワイプを使わず、詳細画面の閉じるジェスチャーと競合しない写真サマリー。
struct TheaterCompactPhotoGrid<Item: Identifiable, Thumbnail: View>: View {
    let items: [Item]
    let onShowAll: () -> Void
    @ViewBuilder let thumbnail: (Item) -> Thumbnail

    private let visibleLimit = 8
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(items.prefix(visibleLimit))) { item in
                thumbnail(item)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }

        if items.count > visibleLimit {
            Button {
                onShowAll()
            } label: {
                Text("さらに見る（残り\(items.count - visibleLimit)枚）")
                    .font(FavorecoTypography.captionStrong)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
