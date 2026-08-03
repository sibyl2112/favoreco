import SwiftUI

struct HomeAttentionSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let items: [HomeAttentionItem]
    let onShowAll: () -> Void
    let onSelectTicket: (TicketAttempt) -> Void
    @State private var showsAllItems = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Ticket Schedule")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(themePalette.headingText(for: colorScheme))
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
                    FavorecoIcon(systemName: "checkmark.circle", size: 14)
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
                ForEach(items.prefix(HomeAttentionDisplay.visibleCount(
                    total: items.count,
                    isExpanded: showsAllItems
                ))) { item in
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

                if items.count > HomeAttentionDisplay.collapsedLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAllItems.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(
                                showsAllItems
                                    ? "閉じる"
                                    : "さらに見る（残り\(HomeAttentionDisplay.hiddenCount(total: items.count))件）"
                            )
                            FavorecoIcon(
                                systemName: showsAllItems ? "chevron.up" : "chevron.down",
                                size: 11
                            )
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(themePalette.globalTint)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        showsAllItems
                            ? "Ticket Scheduleを3件表示へ戻す"
                            : "残り\(HomeAttentionDisplay.hiddenCount(total: items.count))件を表示"
                    )
                }
            }
        }
        .onChange(of: items.count) { _, itemCount in
            if itemCount <= HomeAttentionDisplay.collapsedLimit {
                showsAllItems = false
            }
        }
    }
}

enum HomeAttentionDisplay {
    static let collapsedLimit = 3

    static func visibleCount(total: Int, isExpanded: Bool) -> Int {
        max(0, isExpanded ? total : min(total, collapsedLimit))
    }

    static func hiddenCount(total: Int) -> Int {
        max(0, total - collapsedLimit)
    }
}
