import SwiftUI

struct HomeHeroSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let items: [HomeUpcomingItem]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PICK UP")
                .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

            switch items.count {
            case 0:
                Button {
                    NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                } label: {
                    HomeUpcomingEmptyCard()
                }
                .buttonStyle(.plain)
            case 1:
                itemCard(items[0])
            default:
                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                itemCard(item)
                                    .frame(width: max(0, geometry.size.width), alignment: .top)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: selectedPosition)
                }
                .frame(height: HomeUpcomingHeroMetrics.cardHeight)

                HStack(spacing: 7) {
                    ForEach(items.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? themePalette.globalTint : Color.secondary.opacity(0.28))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("ピックアップ \(min(selectedIndex + 1, items.count))件目、全\(items.count)件")
            }
        }
        .onChange(of: items.count) { _, count in
            if count == 0 {
                selectedIndex = 0
            } else if selectedIndex >= count {
                selectedIndex = count - 1
            }
        }
    }

    private var selectedPosition: Binding<Int?> {
        Binding(
            get: { selectedIndex },
            set: { if let value = $0 { selectedIndex = value } }
        )
    }

    @ViewBuilder
    private func itemCard(_ item: HomeUpcomingItem) -> some View {
        switch item {
        case .plan(let plan): HomeUpcomingPlanCard(plan: plan)
        case .visit(let visit): HomeUpcomingVisitCard(visit: visit)
        }
    }
}
