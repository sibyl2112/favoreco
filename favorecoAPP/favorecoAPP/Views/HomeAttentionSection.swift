import SwiftUI

struct HomeAttentionSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let items: [HomeAttentionItem]
    let onShowAll: () -> Void
    let onSelectTicket: (TicketAttempt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Ticket Schedule")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                Button(action: onShowAll) {
                    HStack(spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(themePalette.globalTint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("チケット管理を開く")
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
                    if let attempt = item.attempt {
                        Button {
                            onSelectTicket(attempt)
                        } label: {
                            HomeTicketScheduleCard(item: item)
                        }
                        .buttonStyle(.plain)
                    } else if let plan = item.plan {
                        NavigationLink {
                            HomePlanDestination(planID: plan.id)
                        } label: {
                            HomeTicketScheduleCard(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeTicketScheduleCard(item: item)
                    }
                }
            }
        }
    }
}
