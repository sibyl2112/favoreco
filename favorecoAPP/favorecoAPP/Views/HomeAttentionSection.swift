import SwiftUI

struct HomeAttentionSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let items: [HomeAttentionItem]
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("次にやること")
                    .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.green)
                    Text("今すぐ対応することはありません")
                        .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
                .background(.background, in: Capsule())
            } else {
                ForEach(items.prefix(3)) { item in
                    if let plan = item.plan {
                        NavigationLink {
                            HomePlanDestination(planID: plan.id)
                        } label: {
                            HomeNextActionCapsuleRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeNextActionCapsuleRow(item: item)
                    }
                }

                if items.count > 3 {
                    Button(action: onShowAll) {
                        HStack(spacing: 8) {
                            Text("ほか\(items.count - 3)件を見る")
                            Image(systemName: "chevron.right")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(themePalette.globalTint)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("次にやることをすべて見る、ほか\(items.count - 3)件")
                }
            }
        }
    }
}
