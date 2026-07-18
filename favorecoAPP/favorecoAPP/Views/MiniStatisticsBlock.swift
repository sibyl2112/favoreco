import SwiftUI

struct MiniStatisticsItem: Identifiable {
    let title: String
    let value: String
    let unit: String
    let icon: String

    var id: String { "\(title)-\(value)-\(unit)-\(icon)" }
}

enum MiniStatisticsBlockFormat {
    case threeColumns
    case fourColumns

    var columnCount: Int {
        switch self {
        case .threeColumns: return 3
        case .fourColumns: return 4
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .threeColumns: return 22
        case .fourColumns: return 20
        }
    }

    var iconFrameWidth: CGFloat {
        switch self {
        case .threeColumns: return 24
        case .fourColumns: return 22
        }
    }

    var valueSize: CGFloat {
        switch self {
        case .threeColumns: return 24
        case .fourColumns: return 22
        }
    }

    var dividerHeight: CGFloat {
        switch self {
        case .threeColumns: return 58
        case .fourColumns: return 54
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .threeColumns: return 8
        case .fourColumns: return 3
        }
    }

    var minimumTextWidth: CGFloat {
        switch self {
        case .threeColumns: return 52
        case .fourColumns: return 40
        }
    }
}

struct MiniStatisticsBlock: View {
    let items: [MiniStatisticsItem]
    let tint: Color
    var format: MiniStatisticsBlockFormat = .fourColumns
    var backgroundColor: Color = Color(.systemBackground)
    var primaryTextColor: Color = .primary
    var secondaryTextColor: Color = .secondary
    var borderColor: Color? = nil
    var dividerColor: Color? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(dividerColor ?? tint.opacity(0.20))
                        .frame(width: 1, height: format.dividerHeight)
                }

                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: item.icon)
                        .font(.system(size: format.iconSize, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: format.iconFrameWidth)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(item.value)
                                .font(FavorecoTypography.latinDisplay(format.valueSize, weight: .bold, relativeTo: .title3))
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .monospacedDigit()

                            if !item.unit.isEmpty {
                                Text(item.unit)
                                    .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(minWidth: format.minimumTextWidth, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, format.horizontalPadding)
                .padding(.vertical, 11)
            }
        }
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor ?? tint.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("\(format.columnCount)列のミニ統計")
    }
}
