import SwiftUI

struct HomeInterestingSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let interestedEvents: [HomeInterestedEventSnapshot]
    let unresolvedInboxItems: [HomeInboxItemSnapshot]
    @Binding var isExpanded: Bool
    @Binding var layoutMode: CategoryLibraryLayoutMode

    private var items: [HomeInterestingItem] {
        interestedEvents.map(HomeInterestingItem.event)
            + unresolvedInboxItems.map(HomeInterestingItem.inbox)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Interesting")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if isExpanded, !items.isEmpty {
                    CategoryLibraryLayoutPicker(selection: $layoutMode, tint: themePalette.globalTint, onSelect: { _ in })
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Interestingを閉じる" : "Interestingを開く")
            }

            if isExpanded {
                if items.isEmpty {
                    EmptyStateRow(icon: "tray", title: "気になる対象はありません", message: "クイック登録した作品や場所がここに表示されます。")
                } else {
                    HomeInterestingCollection(items: items, layout: layoutMode, tint: themePalette.globalTint)
                        .id("home-interesting-\(layoutMode.rawValue)")
                }
            }
        }
    }
}
