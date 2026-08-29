import SwiftUI

enum CategoryDetailChrome {
    /// 公演情報（1.8〜1.9pt）と参加記録外枠（0.8pt）の中間値。
    /// 全ジャンルの主要な詳細カードで同じ視覚重量を使う。
    static let borderLineWidth: CGFloat = 1.35
}

/// 観劇ポスターをB判比率で全体表示する共通部品。
/// 表示サイズに合わせたサムネイルを使い、画像は切り抜かず`.fit`で収める。
struct TheaterPosterArtwork<Placeholder: View>: View {
    let reference: ThumbnailReference?
    let backgroundColor: Color
    private let placeholder: (CGSize) -> Placeholder

    init(
        reference: ThumbnailReference?,
        backgroundColor: Color = Color(.secondarySystemBackground),
        @ViewBuilder placeholder: @escaping (CGSize) -> Placeholder
    ) {
        self.reference = reference
        self.backgroundColor = backgroundColor
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                ThumbnailImage(
                    reference: reference,
                    displaySize: geometry.size,
                    contentMode: .fit
                ) {
                    placeholder(geometry.size)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .aspectRatio(CGFloat(EyecatchAspectRatio.bSeriesPoster.value), contentMode: .fit)
        .clipped()
    }
}

/// 共通画面でジャンルをまたいで画像を出すための部品。
/// 観劇だけはB判の全体表示、その他は各画面が指定した従来の表示方式を保つ。
struct CategoryEyecatchArtwork<Placeholder: View>: View {
    let reference: ThumbnailReference?
    let templateKey: String
    let backgroundColor: Color
    let defaultContentMode: ContentMode
    private let placeholder: (CGSize) -> Placeholder

    init(
        reference: ThumbnailReference?,
        templateKey: String,
        backgroundColor: Color = .clear,
        defaultContentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping (CGSize) -> Placeholder
    ) {
        self.reference = reference
        self.templateKey = templateKey
        self.backgroundColor = backgroundColor
        self.defaultContentMode = defaultContentMode
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { geometry in
            if templateKey == "theater" {
                TheaterPosterArtwork(
                    reference: reference,
                    backgroundColor: backgroundColor,
                    placeholder: placeholder
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ZStack {
                    backgroundColor
                    ThumbnailImage(
                        reference: reference,
                        displaySize: geometry.size,
                        contentMode: defaultContentMode
                    ) {
                        placeholder(geometry.size)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .clipped()
            }
        }
    }
}

private struct TheaterPosterFrameModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.95), lineWidth: 2)
                    .padding(3)
            }
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.46), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.48), radius: 18, y: 9)
    }
}

extension View {
    func theaterPosterFrame(tint: Color) -> some View {
        modifier(TheaterPosterFrameModifier(tint: tint))
    }
}

/// 予定詳細と観劇記録詳細で共有する会場名・住所の要約表示。
struct TheaterVenueSummary: View {
    let venueName: String
    let address: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !venueName.isEmpty {
                Text(venueName)
                    .font(FavorecoTypography.bodyStrong)
                    .textSelection(.enabled)
            }
            if !address.isEmpty {
                Text(address)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 観劇予定詳細と観劇記録詳細で共有するセクション種別。
/// 表示順と初期開閉状態だけを各画面側で決め、名称・アイコン・見た目はここを正本にする。
enum TheaterDetailSectionKind {
    case venue
    case nextActions
    case ticket
    case preparation
    case travelRecord
    case planMemo
    case expense
    case eventInformation
    case performanceInformation
    case workInformation
    case cast
    case focusCast
    case companions
    case review
    case photos
    case ocr

    var title: String {
        switch self {
        case .venue: "会場・地図"
        case .nextActions: "次にやること"
        case .ticket: "チケット・座席"
        case .preparation: "準備・遠征ToDo"
        case .travelRecord: "遠征・準備の記録"
        case .planMemo: "予定メモ"
        case .expense: "費用"
        case .eventInformation: "作品・公演情報"
        case .performanceInformation: "公演情報"
        case .workInformation: "作品情報"
        case .cast: "キャスト・スタッフ"
        case .focusCast: "注目キャスト"
        case .companions: "同行者"
        case .review: "感想"
        case .photos: "写真・コレクション"
        case .ocr: "OCR・取込情報"
        }
    }

    var systemImage: String {
        switch self {
        case .venue: "map"
        case .nextActions: "checklist"
        case .ticket: "ticket"
        case .preparation: "suitcase.rolling"
        case .travelRecord: "suitcase.rolling.fill"
        case .planMemo: "note.text"
        case .expense: "yensign.circle"
        case .eventInformation: "theatermasks"
        case .performanceInformation: "building.2"
        case .workInformation: "theatermasks"
        case .cast: "person.3"
        case .focusCast: "person.crop.circle.badge.checkmark"
        case .companions: "person.2"
        case .review: "heart.text.square"
        case .photos: "photo.on.rectangle.angled"
        case .ocr: "doc.text.viewfinder"
        }
    }
}

enum TheaterDetailSectionStyle {
    static var titleFont: Font {
        FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline)
    }

    static let iconSize: CGFloat = 19
    static let iconFrameSize: CGFloat = 24
    static let contentPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
}

/// 観劇詳細の見出しで、字形ごとの見かけの大きさと線幅を揃えるアイコン。
/// 公演情報を基準にSF SymbolsのMediumと24pt固定枠を使う。
struct TheaterDetailHeaderIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: TheaterDetailSectionStyle.iconSize, weight: .medium))
            .frame(
                width: TheaterDetailSectionStyle.iconFrameSize,
                height: TheaterDetailSectionStyle.iconFrameSize
            )
            .accessibilityHidden(true)
    }
}

struct TheaterDetailIconLabel: View {
    let title: String
    let systemImage: String
    var spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            TheaterDetailHeaderIcon(systemName: systemImage)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 観劇予定・観劇記録で共有する開閉見出し。
struct TheaterDetailDisclosureHeader: View {
    let section: TheaterDetailSectionKind
    let countText: String?
    let tint: Color
    @Binding var isExpanded: Bool

    init(
        _ section: TheaterDetailSectionKind,
        countText: String? = nil,
        tint: Color,
        isExpanded: Binding<Bool>
    ) {
        self.section = section
        self.countText = countText
        self.tint = tint
        _isExpanded = isExpanded
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                TheaterDetailIconLabel(
                    title: section.title,
                    systemImage: section.systemImage
                )
                    .font(TheaterDetailSectionStyle.titleFont)
                if let countText, !countText.isEmpty {
                    Text(countText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityValue(isExpanded ? "開いています" : "閉じています")
        .accessibilityHint(isExpanded ? "ダブルタップで閉じます" : "ダブルタップで開きます")
    }
}

private struct TheaterDetailSectionCardModifier: ViewModifier {
    let tint: Color
    let showsBottomDivider: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, TheaterDetailSectionStyle.contentPadding)
            .overlay(alignment: .bottom) {
                if showsBottomDivider {
                    Rectangle()
                        .fill(tint.opacity(0.42))
                        .frame(height: CategoryDetailChrome.borderLineWidth)
                }
            }
    }
}

extension View {
    func theaterDetailSectionCard(tint: Color, showsBottomDivider: Bool = true) -> some View {
        modifier(
            TheaterDetailSectionCardModifier(
                tint: tint,
                showsBottomDivider: showsBottomDivider
            )
        )
    }
}
