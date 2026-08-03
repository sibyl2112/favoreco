import SwiftUI
import SwiftData

enum HomePickupMode: String, CaseIterable, Identifiable {
    case interested
    case upcoming
    case recorded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interested: "気になる"
        case .upcoming: "予定"
        case .recorded: "記録"
        }
    }
}

struct HomeHeroSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette
    @AppStorage(AppStorageKeys.homePickupMode) private var selectedModeRaw = HomePickupMode.upcoming.rawValue

    let interestedEvents: [HomeInterestedEventSnapshot]
    let unresolvedInboxItems: [HomeInboxItemSnapshot]
    let upcomingItems: [HomeUpcomingItem]
    let recordedVisits: [HomeVisitSnapshot]
    let onSelectInterest: (HomePickupDetailTarget) -> Void
    let onSelectPlan: (UUID) -> Void
    let onSelectVisit: (UUID) -> Void

    @State private var interestedIndex = 0
    @State private var upcomingIndex = 0
    @State private var recordedIndex = 0

    private var selectedMode: HomePickupMode {
        get { HomePickupMode(rawValue: selectedModeRaw) ?? .upcoming }
        nonmutating set { selectedModeRaw = newValue.rawValue }
    }

    private var interestItems: [HomeInterestingItem] {
        Array(
            (interestedEvents.map(HomeInterestingItem.event)
                + unresolvedInboxItems.map(HomeInterestingItem.inbox))
                .sorted { $0.sortDate > $1.sortDate }
                .prefix(10)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PICK UP")
                .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(themePalette.headingText(for: colorScheme))

            VStack(spacing: 0) {
                pickupTabs

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 1)

                pickupBody
                    .padding(12)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(themePalette.globalTint.opacity(0.20), lineWidth: 1)
            }
        }
        .background { GenreSwipeExclusionZone() }
        .onChange(of: interestedEvents.count) { _, _ in clampSelections() }
        .onChange(of: unresolvedInboxItems.count) { _, _ in clampSelections() }
        .onChange(of: upcomingItems.count) { _, _ in clampSelections() }
        .onChange(of: recordedVisits.count) { _, _ in clampSelections() }
    }

    private var pickupTabs: some View {
        HStack(spacing: 0) {
            ForEach(HomePickupMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(FavorecoTypography.jpSerif(14, weight: selectedMode == mode ? .bold : .medium, relativeTo: .body))
                        .foregroundStyle(selectedMode == mode ? Color.white : Color.primary.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            selectedMode == mode ? themePalette.globalTint : Color.clear,
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: mode == .interested ? 7 : 0,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: mode == .recorded ? 7 : 0
                            )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle().inset(by: -3))
                .accessibilityLabel("\(mode.title)タブ")
                .accessibilityValue(selectedMode == mode ? "選択中" : "")

                if mode != .recorded {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 20)
                }
            }
        }
    }

    @ViewBuilder
    private var pickupBody: some View {
        switch selectedMode {
        case .interested:
            if interestItems.isEmpty {
                HomePickupEmptyState(
                    icon: "bookmark",
                    title: "気になるものはありません",
                    message: "ジャンルで気になる作品や場所を追加すると、最新10件がここに並びます。"
                )
            } else {
                pickupPager(items: interestItems, selectedIndex: $interestedIndex) { item in
                    HomePickupInterestCard(
                        item: item,
                        onOpen: { onSelectInterest(item.detailTarget) }
                    )
                }
            }
        case .upcoming:
            if upcomingItems.isEmpty {
                Button {
                    NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                } label: {
                    HomePickupEmptyState(
                        icon: "calendar.badge.plus",
                        title: "予定はありません",
                        message: "行きたい作品や場所が決まったら、予定を立てておけます。",
                        actionTitle: "予定を立てる"
                    )
                }
                .buttonStyle(.plain)
            } else {
                pickupPager(items: upcomingItems, selectedIndex: $upcomingIndex) { item in
                    switch item {
                    case .plan(let plan):
                        HomeUpcomingPlanCard(
                            plan: plan,
                            isEmbedded: true,
                            onOpen: { onSelectPlan(plan.id) }
                        )
                    case .visit(let visit):
                        HomeUpcomingVisitCard(
                            visit: visit,
                            isEmbedded: true,
                            onOpen: { onSelectVisit(visit.id) }
                        )
                    }
                }
            }
        case .recorded:
            if recordedVisits.isEmpty {
                HomePickupEmptyState(
                    icon: "sparkles.rectangle.stack",
                    title: "記録はまだありません",
                    message: "追加した記録のうち最新10件がここに並びます。"
                )
            } else {
                pickupPager(items: recordedVisits, selectedIndex: $recordedIndex) { visit in
                    HomeUpcomingVisitCard(
                        visit: visit,
                        isEmbedded: true,
                        onOpen: { onSelectVisit(visit.id) }
                    )
                }
            }
        }
    }

    private func pickupPager<Item: Identifiable, Card: View>(
        items: [Item],
        selectedIndex: Binding<Int>,
        @ViewBuilder card: @escaping (Item) -> Card
    ) -> some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        card(item)
                            .frame(
                                width: geometry.size.width,
                                height: HomeUpcomingHeroMetrics.embeddedCardHeight
                            )
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: positionBinding(selectedIndex))
        }
        .frame(height: HomeUpcomingHeroMetrics.embeddedCardHeight)
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(
                        width: HomeUpcomingHeroMetrics.embeddedPageMaskWidth,
                        height: HomeUpcomingHeroMetrics.embeddedPageMaskHeight
                    )

                pickupPageIndicator
                    .frame(
                        width: HomeUpcomingHeroMetrics.posterWidth,
                        height: HomeUpcomingHeroMetrics.actionHeight
                    )
                    .padding(.leading, HomeUpcomingHeroMetrics.embeddedPadding)
                    .padding(.bottom, HomeUpcomingHeroMetrics.embeddedPadding)
            }
            .allowsHitTesting(false)
        }
    }

    private var pickupPageIndicator: some View {
        Text("\(selectedPageNumber) / \(selectedItemCount)")
            .font(FavorecoTypography.latinDisplay(13, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel("最新\(selectedItemCount)件中\(selectedPageNumber)件目")
    }

    private var selectedItemCount: Int {
        switch selectedMode {
        case .interested:
            interestItems.count
        case .upcoming:
            upcomingItems.count
        case .recorded:
            recordedVisits.count
        }
    }

    private var selectedPageNumber: Int {
        let selectedIndex: Int
        switch selectedMode {
        case .interested:
            selectedIndex = interestedIndex
        case .upcoming:
            selectedIndex = upcomingIndex
        case .recorded:
            selectedIndex = recordedIndex
        }
        return min(selectedIndex + 1, selectedItemCount)
    }

    private func positionBinding(_ selection: Binding<Int>) -> Binding<Int?> {
        Binding(
            get: { selection.wrappedValue },
            set: { if let value = $0 { selection.wrappedValue = value } }
        )
    }

    private func clampSelections() {
        interestedIndex = min(interestedIndex, max(0, interestItems.count - 1))
        upcomingIndex = min(upcomingIndex, max(0, upcomingItems.count - 1))
        recordedIndex = min(recordedIndex, max(0, recordedVisits.count - 1))
    }
}

private struct HomePickupInterestCard: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let item: HomeInterestingItem
    let onOpen: () -> Void

    var body: some View {
        HomeUpcomingHeroLayout(isEmbedded: true) {
            HomeUpcomingPoster(
                thumbnailReference: item.thumbnailReference,
                categoryTemplateKey: item.categoryTemplateKey,
                fallbackIcon: item.categoryIcon,
                tint: Color(hex: item.colorHex),
                fillsFrame: false
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HomeUpcomingHeroDetails(
                categoryName: item.categoryName,
                title: item.title,
                subtitle: item.detailText,
                dateText: item.periodText,
                venueName: item.venueName,
                officialURLString: item.officialURLString,
                tint: themePalette.globalTint,
                isEmbedded: true,
                onOpen: onOpen
            ) {
                Button {
                    onOpen()
                } label: {
                    HomeUpcomingActionLabel(
                        title: "詳細を見る",
                        systemImage: "book.pages",
                        tint: themePalette.globalTint
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: HomeUpcomingHeroMetrics.embeddedContentHeight, alignment: .top)
        .padding(HomeUpcomingHeroMetrics.embeddedPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: HomeUpcomingHeroMetrics.embeddedCardHeight,
            alignment: .topLeading
        )
    }
}

private struct HomePickupEmptyState: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            FavorecoIcon(systemName: icon, size: 28)
                .foregroundStyle(themePalette.globalTint)
            Text(title)
                .font(FavorecoTypography.cardTitle)
            Text(message)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle {
                FavorecoIconLabel(actionTitle, systemImage: "plus")
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(themePalette.globalTint)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: HomeUpcomingHeroMetrics.embeddedCardHeight)
    }
}
