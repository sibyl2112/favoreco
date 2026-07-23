import SwiftUI

struct HomeComingUpSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let items: [HomeUpcomingItem]
    @Binding var isShowingAll: Bool

    var body: some View {
        let visibleItems = isShowingAll ? items : Array(items.prefix(1))
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming Up")
                .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

            if items.isEmpty {
                Button {
                    NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(themePalette.globalTint)
                            .frame(width: 34, height: 34)
                            .background(themePalette.globalTint.opacity(0.10), in: Circle())
                        Text("次の予定はまだありません")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("予定を追加")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(themePalette.globalTint)
                    }
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(visibleItems) { HomeComingUpLink(item: $0) }
                if items.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { isShowingAll.toggle() }
                    } label: {
                        HStack(spacing: 10) {
                            Rectangle().fill(themePalette.globalTint.opacity(0.24)).frame(height: 0.6)
                            Text(isShowingAll ? "閉じる" : "さらに\(items.count - 1)件")
                                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(themePalette.globalTint)
                            Rectangle().fill(themePalette.globalTint.opacity(0.24)).frame(height: 0.6)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
