import Foundation
import SwiftUI

struct CategoryTicketProgressItem: Identifiable {
    let plan: Plan
    let attempt: TicketAttempt

    var id: UUID { attempt.id }

    var title: String {
        if !plan.title.isEmpty { return plan.title }
        if let eventTitle = plan.event?.title, !eventTitle.isEmpty { return eventTitle }
        return "公演"
    }

    var selectorTitle: String {
        guard plan.hasConfirmedSchedule else {
            return plan.venueNameSnapshot.isEmpty ? "参加日未定" : "参加日未定 \(plan.venueNameSnapshot)"
        }
        let date = FavorecoDateText.monthDay(plan.startsAt)
        return plan.venueNameSnapshot.isEmpty ? date : "\(date) \(plan.venueNameSnapshot)"
    }

    var crossGenreSelectorTitle: String {
        let categoryName = (plan.category ?? plan.event?.category)?.name ?? "ジャンル"
        return "\(categoryName)・\(selectorTitle)"
    }

    var categoryColorHex: String {
        (plan.category ?? plan.event?.category)?.colorHex ?? "#147C88"
    }

    var metadataChips: [String] {
        var values = plan.hasConfirmedSchedule
            ? [FavorecoDateText.compactDateTime(plan.startsAt)]
            : ["参加日未定"]
        if !plan.venueNameSnapshot.isEmpty {
            values.append(plan.venueNameSnapshot)
        }
        if !attempt.entryRouteKey.isEmpty {
            values.append(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
        }
        if !attempt.ticketSite.isEmpty {
            values.append(attempt.ticketSite)
        }
        values.append(contentsOf: TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames)

        var seen = Set<String>()
        return values.filter { value in
            let normalized = value.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            return !value.isEmpty && seen.insert(normalized).inserted
        }
    }

    var stages: [TicketProgressStage] {
        TicketProgressTimeline.stages(for: attempt, plan: plan)
    }

    var currentStageIndex: Int {
        TicketProgressTimeline.currentIndex(for: attempt, stages: stages)
    }

    static func activeItems(in plans: [Plan], categoryID: UUID? = nil) -> [CategoryTicketProgressItem] {
        let items = plans
            .filter { plan in
                guard !plan.isArchived else { return false }
                guard let categoryID else { return true }
                return (plan.category ?? plan.event?.category)?.id == categoryID
            }
            .flatMap { plan in
                (plan.ticketAttempts ?? []).compactMap { attempt -> CategoryTicketProgressItem? in
                    guard !attempt.isArchived,
                          !["interested", "lost", "attended", "skipped"].contains(attempt.statusKey) else {
                        return nil
                    }
                    return CategoryTicketProgressItem(plan: plan, attempt: attempt)
                }
            }

        return TicketAttemptPresentationOrder.sorted(items.map(\.attempt)).compactMap { sortedAttempt in
            items.first(where: { $0.attempt.id == sortedAttempt.id })
        }
    }

    static func topItems(
        in plans: [Plan],
        category: RecordCategory
    ) -> [CategoryTicketProgressItem] {
        let items = activeItems(in: plans, categoryID: category.id)
        switch category.templateKey {
        case "theater":
            return items.filter { !$0.plan.hasConfirmedSchedule }
        case "live":
            return items.filter {
                LiveTicketPlacementPolicy.showsInTicketManagement(
                    statusKey: $0.attempt.statusKey
                )
            }
        default:
            return items
        }
    }

}

struct CategoryTicketProgressSection: View {
    let items: [CategoryTicketProgressItem]
    let title: String
    let japaneseTitle: String?
    let usesLatinTitle: Bool
    let usesTheaterStyle: Bool
    let usesLiveStyle: Bool
    let showsCategoryInSelector: Bool
    let fixedTint: Color?

    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedAttemptID: UUID?
    @State private var quickActionAttempt: TicketAttempt?
    @State private var editingAttempt: TicketAttempt?
    @State private var isShowingTicketOverview = false

    init(
        items: [CategoryTicketProgressItem],
        title: String,
        japaneseTitle: String? = nil,
        usesLatinTitle: Bool,
        usesTheaterStyle: Bool,
        usesLiveStyle: Bool = false,
        showsCategoryInSelector: Bool,
        fixedTint: Color? = nil
    ) {
        self.items = items
        self.title = title
        self.japaneseTitle = japaneseTitle
        self.usesLatinTitle = usesLatinTitle
        self.usesTheaterStyle = usesTheaterStyle
        self.usesLiveStyle = usesLiveStyle
        self.showsCategoryInSelector = showsCategoryInSelector
        self.fixedTint = fixedTint
        _selectedAttemptID = State(initialValue: items.first?.id)
    }

    private var selectedItem: CategoryTicketProgressItem? {
        items.first(where: { $0.id == selectedAttemptID }) ?? items.first
    }

    private var tint: Color {
        if let fixedTint { return fixedTint }
        return themePalette.categoryColor(hex: selectedItem?.categoryColorHex ?? "#147C88")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if usesLatinTitle, let japaneseTitle {
                    LayeredCategorySectionTitle(
                        englishTitle: title,
                        japaneseTitle: japaneseTitle,
                        foregroundColor: primaryTextColor
                    )
                } else {
                    Text(title)
                        .font(sectionTitleFont)
                        .foregroundStyle(primaryTextColor)
                }

                Spacer(minLength: 8)

                Button {
                    isShowingTicketOverview = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(actionTint)
                }
                .buttonStyle(.plain)
                .frame(alignment: .trailing)
            }

            if items.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(items) { item in
                            selectorButton(for: item)
                        }
                    }
                }
                .clipped()
            }

            if let selectedItem {
                VStack(spacing: 0) {
                    Button {
                        quickActionAttempt = selectedItem.attempt
                    } label: {
                        CategoryTicketProgressCard(
                            item: selectedItem,
                            tint: tint,
                            isTheater: usesTheaterStyle,
                            isLive: usesLiveStyle,
                            showsFrame: false
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(tint.opacity(0.22))
                        .padding(.horizontal, 9)

                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            editingAttempt = selectedItem.attempt
                        } label: {
                            FavorecoIconLabel("日付編集", systemImage: "pencil", iconSize: 13)
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(actionTint)
                                .frame(minHeight: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("申込日、当落日、支払期限、取得日を編集します")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 5)
                }
                .background(ticketProgressCardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            tint.opacity(usesTheaterStyle || usesLiveStyle ? 0.48 : 0.20),
                            lineWidth: usesTheaterStyle || usesLiveStyle ? 0.7 : 0.75
                        )
                }
                .id(selectedItem.id)
                .transition(.opacity)
            } else if usesTheaterStyle || usesLiveStyle {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "checkmark.circle", size: 17)
                        .foregroundStyle(tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            usesTheaterStyle
                                ? "参加日未定のチケットはありません"
                                : "対応が必要なチケットはありません"
                        )
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(primaryTextColor)
                        Text(
                            usesTheaterStyle
                                ? "日程が決まったチケットは Coming Up に表示されます"
                                : "申込・当落・支払・受取の進行中チケットを表示します"
                        )
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.20), lineWidth: 0.8)
                }
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if let selectedAttemptID, ids.contains(selectedAttemptID) { return }
            self.selectedAttemptID = ids.first
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
        .sheet(item: $editingAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt, prioritizesDates: true)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingTicketOverview) {
            NavigationStack {
                TicketOverviewView(
                    showsCloseButton: true,
                    initialFilter: usesTheaterStyle ? .undated : .needsAction
                )
            }
        }
    }

    private var primaryTextColor: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.ivory }
        if usesLiveStyle { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var secondaryTextColor: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.ivory.opacity(0.68) }
        if usesLiveStyle { return LiveCategoryStyle.mist.opacity(0.62) }
        return Color.secondary
    }

    private var ticketProgressCardBackground: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.tileBackground }
        if usesLiveStyle { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground)
    }

    private var actionTint: Color {
        usesTheaterStyle ? TheaterCategoryStyle.ticketActionRose : tint
    }

    private func selectorButton(for item: CategoryTicketProgressItem) -> some View {
        let isSelected = selectedAttemptID == item.id
        let selectorTitle = showsCategoryInSelector
            ? item.crossGenreSelectorTitle
            : item.selectorTitle

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedAttemptID = item.id
            }
        } label: {
            Text(selectorTitle)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(isSelected ? Color.white : actionTint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(isSelected ? actionTint : actionTint.opacity(0.12), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(actionTint.opacity(isSelected ? 0 : 0.48), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(selectorTitle)のチケット状況")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sectionTitleFont: Font {
        usesLatinTitle
            ? FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3)
            : FavorecoTypography.sectionTitle
    }
}

struct CategoryTicketProgressCard: View {
    let item: CategoryTicketProgressItem
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    var showsFrame = true

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 7) {
            Text(item.title)
                .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(item.metadataChips, id: \.self) { chip in
                        let isAttention = isTheater && chip == "参加日未定"
                        let chipTint = isTheater ? TheaterCategoryStyle.ticketMetadataRose : tint
                        Text(chip)
                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                            .foregroundStyle(isAttention ? TicketProgressColorPalette.scheduleUndated : chipTint)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(
                                isAttention
                                    ? TicketProgressColorPalette.scheduleUndated.opacity(0.18)
                                    : chipTint.opacity(isTheater ? 0.15 : 0.10),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        isAttention
                                            ? TicketProgressColorPalette.scheduleUndated.opacity(0.82)
                                            : chipTint.opacity(isTheater ? 0.56 : 0.28),
                                        lineWidth: 1
                                    )
                            }
                    }
                }
            }
            .clipped()

            TicketProgressTimelineView(
                stages: item.stages,
                currentIndex: item.currentStageIndex,
                nodeBackground: cardBackground,
                secondaryTextColor: secondaryTextColor,
                completedTint: TicketProgressColorPalette.completedNeutral
            )
        }
        .padding(9)

        if showsFrame {
            content
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            tint.opacity(isTheater || isLive ? 0.48 : 0.20),
                            lineWidth: isTheater || isLive ? 0.7 : 0.75
                        )
                }
        } else {
            content
        }
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground)
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.68) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.62) }
        return Color.secondary
    }
}

struct TicketProgressTimelineView: View {
    let stages: [TicketProgressStage]
    let currentIndex: Int
    let nodeBackground: Color
    let secondaryTextColor: Color
    var currentTint: Color? = nil
    var completedTint: Color? = nil
    var nodeDiameter: CGFloat = 34
    var nodeTextSize: CGFloat = 9
    var emphasizesCurrentDate = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                GeometryReader { geometry in
                    let stageColor = TicketProgressColorPalette.color(for: stage)
                    let state = nodeState(at: index)
                    let nodeTint = switch state {
                    case .completed: completedTint ?? stageColor
                    case .current: currentTint ?? stageColor
                    case .future: stageColor
                    }
                    let dateWeight: Font.Weight = emphasizesCurrentDate
                        && state == .current
                        && stage.date != nil
                        ? .semibold
                        : .medium
                    ZStack(alignment: .top) {
                        if index < stages.count - 1 {
                            TicketProgressConnectorShape()
                                .stroke(
                                    index < currentIndex
                                        ? (completedTint ?? stageColor)
                                        : secondaryTextColor.opacity(0.54),
                                    style: StrokeStyle(
                                        lineWidth: 1.5,
                                        lineCap: .round,
                                        dash: index < currentIndex ? [] : [2.5, 3.5]
                                    )
                                )
                                .frame(
                                    width: max(0, geometry.size.width - nodeDiameter),
                                    height: 2
                                )
                                .position(x: geometry.size.width, y: nodeDiameter / 2)
                        }

                        VStack(spacing: 3) {
                            TicketProgressNode(
                                title: stage.title,
                                state: state,
                                tint: nodeTint,
                                background: nodeBackground,
                                diameter: nodeDiameter,
                                textSize: nodeTextSize
                            )

                            Group {
                                if let date = stage.date {
                                    Text(FavorecoDateText.monthDay(date))
                                } else {
                                    Text("—")
                                }
                            }
                                .font(FavorecoTypography.jpSans(9, weight: dateWeight, relativeTo: .caption2))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                        .frame(width: geometry.size.width)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 52)
        .accessibilityElement(children: .combine)
    }

    private func nodeState(at index: Int) -> TicketProgressNode.State {
        if index < currentIndex { return .completed }
        if index == currentIndex { return .current }
        return .future
    }
}

private struct TicketProgressNode: View {
    enum State: Equatable {
        case completed
        case current
        case future
    }

    let title: String
    let state: State
    let tint: Color
    let background: Color
    let diameter: CGFloat
    let textSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(state == .future ? background : tint)

            if state == .future {
                Circle()
                    .stroke(Color.secondary.opacity(0.52), lineWidth: 1.5)
            }

            Text(title)
                .font(FavorecoTypography.jpSans(textSize, weight: .semibold, relativeTo: .caption2))
                .foregroundStyle(state == .future ? Color.primary : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct TicketProgressConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
