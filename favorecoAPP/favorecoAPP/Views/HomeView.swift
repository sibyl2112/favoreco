//
//  HomeView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.createdAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \Plan.startsAt, order: .forward) private var plans: [Plan]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsAttention = true
    @AppStorage(AppStorageKeys.showsHomeExperienceGallery) private var showsExperienceGallery = true
    @AppStorage(AppStorageKeys.showsHomeInbox) private var showsInbox = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsStatsSummary = false
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var categoryLayoutModeRaw = HomeCategoryLayoutMode.horizontal.rawValue
    @State private var isShowingAttentionList = false
    @State private var selectedUpcomingPlanIndex = 0

    private var categoryLayoutMode: HomeCategoryLayoutMode {
        HomeCategoryLayoutMode(rawValue: categoryLayoutModeRaw) ?? .horizontal
    }

    private func attentionItems(for snapshot: HomeSnapshot) -> [HomeAttentionItem] {
        var items = ticketAttentionItems(for: snapshot.activeTicketAttempts)

        if items.count < 5 {
            items.append(contentsOf: membershipAttentionItems(for: snapshot.expiringTicketAccounts).prefix(5 - items.count))
        }

        return Array(items.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.dueDate < rhs.dueDate
        }.prefix(5))
    }

    private func ticketAttentionItems(for attempts: [TicketAttempt]) -> [HomeAttentionItem] {
        attempts
            .flatMap { ticketAttentionItems(for: $0) }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.dueDate < rhs.dueDate
            }
            .prefix(5)
            .map { $0 }
    }

    private func membershipAttentionItems(for accounts: [TicketAccount]) -> [HomeAttentionItem] {
        accounts
            .map { account in
                HomeAttentionItem(
                    id: "membership-\(account.id.uuidString)-expiry",
                    icon: "person.text.rectangle",
                    title: account.serviceName.isEmpty ? "会員期限" : account.serviceName,
                    subtitle: "期限 \(attentionDateFormatter.string(from: account.expiryDate))",
                    dueDate: account.expiryDate,
                    tint: Color(hex: account.colorHex),
                    priority: 8
                )
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    private func ticketAttentionItems(for attempt: TicketAttempt) -> [HomeAttentionItem] {
        let now = Date()
        let plan = attempt.plan
        let title = plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定"
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        var items: [HomeAttentionItem] = []

        if attempt.saleStartAt > now {
            items.append(ticketAttention(
                id: "ticket-\(attempt.id.uuidString)-sale-start",
                icon: "ticket",
                label: "申込開始",
                title: title,
                date: attempt.saleStartAt,
                plan: plan,
                tint: tint,
                priority: 12
            ))
        }

        if attempt.applyDeadlineAt > now {
            items.append(ticketAttention(
                id: "ticket-\(attempt.id.uuidString)-apply-deadline",
                icon: "hourglass",
                label: "申込締切",
                title: title,
                date: attempt.applyDeadlineAt,
                plan: plan,
                tint: .red,
                priority: 1
            ))
        }

        if attempt.resultAnnounceAt > now {
            items.append(ticketAttention(
                id: "ticket-\(attempt.id.uuidString)-result",
                icon: "checkmark.seal",
                label: "当落発表",
                title: title,
                date: attempt.resultAnnounceAt,
                plan: plan,
                tint: .purple,
                priority: 5
            ))
        }

        if attempt.paymentDeadlineAt > now {
            items.append(ticketAttention(
                id: "ticket-\(attempt.id.uuidString)-payment",
                icon: "yensign.circle",
                label: "入金締切",
                title: title,
                date: attempt.paymentDeadlineAt,
                plan: plan,
                tint: .orange,
                priority: 2
            ))
        }

        if attempt.issueStartAt > now {
            items.append(ticketAttention(
                id: "ticket-\(attempt.id.uuidString)-issue-start",
                icon: "ticket.fill",
                label: "発券開始",
                title: title,
                date: attempt.issueStartAt,
                plan: plan,
                tint: .teal,
                priority: 10
            ))
        }

        return items
    }

    private func ticketAttention(
        id: String,
        icon: String,
        label: String,
        title: String,
        date: Date,
        plan: Plan?,
        tint: Color,
        priority: Int
    ) -> HomeAttentionItem {
        HomeAttentionItem(
            id: id,
            icon: icon,
            title: title,
            subtitle: "\(label) \(attentionDateFormatter.string(from: date))",
            dueDate: date,
            plan: plan,
            tint: tint,
            priority: priority
        )
    }

    private var attentionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }

    var body: some View {
        let snapshot = HomeSnapshot.make(
            categories: categories,
            events: events,
            visits: visits,
            inboxItems: inboxItems,
            plans: plans,
            ticketAttempts: ticketAttempts,
            ticketAccounts: ticketAccounts,
            personLinks: personLinks
        )
        let attentionItems = attentionItems(for: snapshot)

        NavigationStack {
            VStack(spacing: 0) {
                MainScreenHeader(title: "Favoreco", usesBrandFont: true)
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if showsCategories {
                            categorySection(categories: snapshot.visibleCategories)
                        }

                        upcomingPlansSection(items: snapshot.upcomingItems)

                        if showsAttention {
                            attentionSection(items: attentionItems)
                        }

                        if showsExperienceGallery && !snapshot.recentVisits.isEmpty {
                            experienceGallerySection(visits: snapshot.recentVisits)
                        }

                        if showsInbox && (!snapshot.interestedEvents.isEmpty || !snapshot.unresolvedInboxItems.isEmpty) {
                            inboxSection(
                                interestedEvents: snapshot.interestedEvents,
                                unresolvedInboxItems: snapshot.unresolvedInboxItems
                            )
                        }

                        if showsRecentRecords && !snapshot.recentVisits.isEmpty {
                            recentSection(visits: snapshot.recentVisits)
                        }

                        if showsStatsSummary && snapshot.visibleVisitCount > 0 {
                            statsSummarySection(snapshot: snapshot)
                        }

                        crossGenreMiniStats(snapshot: snapshot)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(homeBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingAttentionList) {
                HomeAttentionListView(items: attentionItems)
            }
            .task {
                try? LegacyInboxMigrationService.migrateIfNeeded(in: modelContext)
            }
        }
    }

    private func crossGenreMiniStats(snapshot: HomeSnapshot) -> some View {
        HStack(spacing: 10) {
            HomeMiniStatCell(
                value: "\(snapshot.upcomingItemCount)",
                label: "今後の予定",
                icon: "calendar.badge.clock",
                tint: Color(hex: "#147C88")
            )
            HomeMiniStatCell(
                value: "\(snapshot.currentYearVisitCount)",
                label: "今年の記録",
                icon: "sparkles.rectangle.stack",
                tint: Color(hex: "#8B2F45")
            )
            HomeMiniStatCell(
                value: "\(snapshot.visibleVisitCount)",
                label: "総記録数",
                icon: "chart.bar.fill",
                tint: Color(hex: "#B8792F")
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func upcomingPlansSection(items: [HomeUpcomingItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("次の予定")
                    .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

                Spacer()

                if !items.isEmpty {
                    Button("予定一覧") {
                        NotificationCenter.default.post(name: .openFavorecoPlanList, object: nil)
                    }
                    .font(FavorecoTypography.captionStrong)
                }
            }

            switch items.count {
            case 0:
                Button {
                    NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                } label: {
                    HomeUpcomingEmptyCard()
                }
                .buttonStyle(.plain)

            case 1:
                upcomingItemLink(items[0])

            default:
                TabView(selection: $selectedUpcomingPlanIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        upcomingItemLink(item)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 224)

                Text("\(min(selectedUpcomingPlanIndex + 1, items.count)) / \(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("予定 \(min(selectedUpcomingPlanIndex + 1, items.count))件目、全\(items.count)件")
            }
        }
        .onChange(of: items.count) { _, count in
            if count == 0 {
                selectedUpcomingPlanIndex = 0
            } else if selectedUpcomingPlanIndex >= count {
                selectedUpcomingPlanIndex = count - 1
            }
        }
    }

    @ViewBuilder
    private func upcomingItemLink(_ item: HomeUpcomingItem) -> some View {
        switch item {
        case .plan(let plan):
            HomeUpcomingPlanCard(plan: plan)
        case .visit(let visit):
            HomeUpcomingVisitCard(visit: visit)
        }
    }

    private func categorySection(categories: [RecordCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if categories.isEmpty {
                EmptyStateRow(
                    icon: "square.grid.2x2",
                    title: "何もありません",
                    message: "設定からジャンルを選び直すと、記録の入口が表示されます。"
                )
            } else if categoryLayoutMode == .horizontal {
                GenreNavigationStrip(categories: categories)
            } else {
                gridCategoryLayout(categories: categories)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ジャンル")
    }

    private func gridCategoryLayout(categories: [RecordCategory]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 8), count: 4),
            alignment: .leading,
            spacing: 12
        ) {
            categoryLinks(categories: categories)
        }
        .accessibilityLabel("ジャンル一覧 4列表示")
    }

    @ViewBuilder
    private func categoryLinks(categories: [RecordCategory]) -> some View {
        ForEach(categories) { category in
            NavigationLink {
                CategoryTopView(category: category)
            } label: {
                HomeCategoryShortcut(category: category)
            }
            .buttonStyle(.plain)
        }
    }

    private var homeBackground: some View {
        ZStack {
            Color(colorScheme == .dark ? .systemGroupedBackground : .init(red: 0.988, green: 0.972, blue: 0.945, alpha: 1))

            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#F1D8D2").opacity(colorScheme == .dark ? 0.08 : 0.34), location: 0),
                    .init(color: Color(hex: "#F8F3E8").opacity(colorScheme == .dark ? 0.03 : 0.18), location: 0.25),
                    .init(color: Color(hex: "#D6E3DF").opacity(colorScheme == .dark ? 0.06 : 0.18), location: 0.56),
                    .init(color: Color(hex: "#E9D4C9").opacity(colorScheme == .dark ? 0.08 : 0.30), location: 0.80),
                    .init(color: Color(hex: "#F4DAD6").opacity(colorScheme == .dark ? 0.07 : 0.28), location: 1),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    themePalette.globalTint.opacity(colorScheme == .dark ? 0.025 : 0.035),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HomePaperGrainOverlay(isDark: colorScheme == .dark)
        }
        .ignoresSafeArea()
    }

    private func attentionSection(items: [HomeAttentionItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("アテンション", count: items.count)

            if items.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                    Text("対応が必要なお知らせはありません")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(items.prefix(2)) { item in
                    if let plan = item.plan {
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            AttentionRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AttentionRow(item: item)
                    }
                }

                if items.count > 2 {
                    Button("ほか\(items.count - 2)件") {
                        isShowingAttentionList = true
                    }
                    .font(FavorecoTypography.captionStrong)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func experienceGallerySection(visits: [HomeVisitSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近の思い出", count: visits.count)

            if visits.isEmpty {
                EmptyStateRow(
                    icon: "photo.on.rectangle.angled",
                    title: "ギャラリーはまだ空です",
                    message: "写真付きの記録やこれから参加する予定が、ここに並びます。"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(visits) { visit in
                            NavigationLink {
                                HomeVisitDestination(visitID: visit.id)
                            } label: {
                                ExperienceGalleryCard(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
    }

    private func recentSection(visits: [HomeVisitSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近の記録", count: visits.count)

            if visits.isEmpty {
                EmptyStateRow(
                    icon: "sparkles.rectangle.stack",
                    title: "記録はまだありません",
                    message: "下部の「追加」から体験済みの記録を登録できます。"
                )
            } else {
                ForEach(visits.prefix(5)) { visit in
                    NavigationLink {
                        HomeVisitDestination(visitID: visit.id)
                    } label: {
                        HomeVisitSummaryRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func inboxSection(
        interestedEvents: [HomeInterestedEventSnapshot],
        unresolvedInboxItems: [HomeInboxItemSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("気になる", count: interestedEvents.count + unresolvedInboxItems.count)

            if interestedEvents.isEmpty && unresolvedInboxItems.isEmpty {
                EmptyStateRow(
                    icon: "tray",
                    title: "気になる対象はありません",
                    message: "クイック登録した作品や場所がここに表示されます。"
                )
            } else {
                ForEach(interestedEvents.prefix(3)) { event in
                    NavigationLink {
                        HomeEventDestination(eventID: event.id)
                    } label: {
                        InterestedEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(unresolvedInboxItems.prefix(max(0, 3 - interestedEvents.count))) { item in
                    NavigationLink {
                        HomeInboxDestination(itemID: item.id)
                    } label: {
                        InboxItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statsSummarySection(snapshot: HomeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("統計サマリ", count: snapshot.visibleVisitCount)

            HStack(spacing: 12) {
                SummaryMetricCard(title: "記録", value: "\(snapshot.visibleVisitCount)", icon: "sparkles.rectangle.stack")
                SummaryMetricCard(title: "ジャンル", value: "\(snapshot.visibleCategories.count)", icon: "square.grid.2x2")
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
            Spacer()
            Text("\(count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InterestedEventRow: View {
    let event: HomeInterestedEventSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let categoryName = event.categoryName {
                        Label(categoryName, systemImage: event.categoryIcon ?? "square.grid.2x2")
                    }
                    if event.hasOfficialURL {
                        Label("URL", systemImage: "link")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeUpcomingPlanCard: View {
    let plan: HomePlanSnapshot
    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false
    @Environment(\.favorecoThemePalette) private var themePalette

    init(plan: HomePlanSnapshot) {
        self.plan = plan
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    private var tint: Color {
        themePalette.categoryColor(hex: plan.categoryColorHex)
    }

    private var dateText: String {
        plan.startsAt.formatted(
            .dateTime
                .locale(Locale(identifier: "ja_JP"))
                .month(.defaultDigits)
                .day()
                .weekday(.abbreviated)
                .hour()
                .minute()
        )
    }

    var body: some View {
        HomeUpcomingHeroLayout(posterAspectRatio: CGFloat(plan.posterAspectRatio)) {
            HomeUpcomingPoster(
                imageData: plan.posterData,
                fallbackIcon: plan.categoryIcon,
                tint: tint
            )

            HomeUpcomingHeroDetails(
                categoryName: plan.categoryName,
                title: plan.title,
                subtitle: plan.subtitle.isEmpty ? plan.organizerName : plan.subtitle,
                dateText: dateText,
                venueName: plan.venueName,
                tint: tint
            ) {
                HStack(spacing: 6) {
                    NavigationLink {
                        HomePlanDestination(planID: plan.id)
                    } label: {
                        HomeUpcomingActionLabel(
                            title: "予定を見る",
                            systemImage: "book.pages",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingEditPlan = true
                    } label: {
                        HomeUpcomingActionLabel(
                            title: "編集",
                            systemImage: "pencil",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPlans.isEmpty)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                ContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
    }

}

private struct HomeUpcomingVisitCard: View {
    let visit: HomeVisitSnapshot
    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        themePalette.categoryColor(hex: visit.categoryColorHex)
    }

    private var dateText: String {
        visit.visitedAt.formatted(
            .dateTime
                .locale(Locale(identifier: "ja_JP"))
                .month(.defaultDigits)
                .day()
                .weekday(.abbreviated)
                .hour()
                .minute()
        )
    }

    var body: some View {
        HomeUpcomingHeroLayout(posterAspectRatio: CGFloat(visit.eyecatchAspectRatio)) {
            HomeUpcomingPoster(
                imageData: visit.photo?.data,
                fallbackIcon: visit.categoryIcon,
                tint: tint
            )

            HomeUpcomingHeroDetails(
                categoryName: visit.categoryName,
                title: visit.title,
                subtitle: "",
                dateText: dateText,
                venueName: visit.venueName,
                tint: tint
            ) {
                NavigationLink {
                    HomeVisitDestination(visitID: visit.id)
                } label: {
                    HomeUpcomingActionLabel(
                        title: "記録を見る",
                        systemImage: "book.pages",
                        tint: tint
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

}

private struct HomeUpcomingHeroLayout: Layout {
    let posterAspectRatio: CGFloat
    private let posterFraction: CGFloat = 0.34
    private let maximumPosterWidth: CGFloat = 112
    private let spacing: CGFloat = 14

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 340
        let availableWidth = max(0, width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.6, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio
        let detailsSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailsWidth, height: posterHeight)
        )
        return CGSize(width: width, height: max(posterHeight, detailsSize.height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let availableWidth = max(0, bounds.width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.6, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: posterWidth, height: posterHeight)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + posterWidth + spacing, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailsWidth, height: max(posterHeight, bounds.height))
        )
    }
}

private struct HomeUpcomingPoster: View {
    let imageData: Data?
    let fallbackIcon: String
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        tint.opacity(0.14)
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct HomeUpcomingHeroDetails<Actions: View>: View {
    let categoryName: String
    let title: String
    let subtitle: String
    let dateText: String
    let venueName: String
    let tint: Color
    let actions: Actions

    init(
        categoryName: String,
        title: String,
        subtitle: String,
        dateText: String,
        venueName: String,
        tint: Color,
        @ViewBuilder actions: () -> Actions
    ) {
        self.categoryName = categoryName
        self.title = title
        self.subtitle = subtitle
        self.dateText = dateText
        self.venueName = venueName
        self.tint = tint
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(categoryName)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(tint)

            Text(title)
                .font(FavorecoTypography.jpSerif(19, weight: .bold, relativeTo: .headline))
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Label(dateText, systemImage: "calendar")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !venueName.isEmpty {
                Label(venueName, systemImage: "mappin.and.ellipse")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct HomeUpcomingActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .overlay {
                Capsule().stroke(tint.opacity(0.55), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private struct HomeUpcomingEmptyCard: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(themePalette.globalTint)

            VStack(spacing: 5) {
                Text("次の予定はありません")
                    .font(FavorecoTypography.cardTitle)
                    .foregroundStyle(.primary)
                Text("行きたい作品や場所が決まったら、予定を立てておけます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Label("予定を立てる", systemImage: "plus")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(themePalette.globalTint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 274, maxHeight: 274)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(themePalette.globalTint.opacity(0.18), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAttentionItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let dueDate: Date
    var plan: Plan? = nil
    let tint: Color
    let priority: Int
}

private struct HomeMiniStatCell: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(value)
                .font(FavorecoTypography.jpSans(24, weight: .bold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AttentionRow: View {
    let item: HomeAttentionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(item.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAttentionListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HomeAttentionItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                if let plan = item.plan {
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        AttentionRow(item: item)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                } else {
                    AttentionRow(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct AppNotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]

    private var items: [HomeAttentionItem] {
        let now = Date()
        let warningLimit = Calendar.current.date(byAdding: .day, value: 45, to: now) ?? now
        let attempts = ticketAttempts.filter { attempt in
            !attempt.isArchived
                && attempt.plan?.isArchived != true
                && !["lost", "attended", "skipped"].contains(attempt.statusKey)
        }
        let accounts = ticketAccounts.filter { account in
            !account.isArchived
                && account.renewalNotify
                && account.expiryDate != Date.distantPast
                && account.expiryDate >= now
                && account.expiryDate <= warningLimit
        }

        var result = attempts.flatMap { attentionItems(for: $0, now: now) }
        result.append(contentsOf: accounts.map { account in
            HomeAttentionItem(
                id: "membership-\(account.id.uuidString)-expiry",
                icon: "person.text.rectangle",
                title: account.serviceName.isEmpty ? "会員期限" : account.serviceName,
                subtitle: "期限 \(dateText(account.expiryDate))",
                dueDate: account.expiryDate,
                tint: Color(hex: account.colorHex),
                priority: 8
            )
        })
        return result.sorted { lhs, rhs in
            lhs.priority == rhs.priority ? lhs.dueDate < rhs.dueDate : lhs.priority < rhs.priority
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "お知らせはありません",
                        systemImage: "bell",
                        description: Text("申込期限や入金、発券、会員期限などをここで確認できます。")
                    )
                } else {
                    List(items) { item in
                        if let plan = item.plan {
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                AttentionRow(item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                        } else {
                            AttentionRow(item: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func attentionItems(for attempt: TicketAttempt, now: Date) -> [HomeAttentionItem] {
        let plan = attempt.plan
        let title = plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定"
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        var result: [HomeAttentionItem] = []

        appendAttention(&result, if: attempt.saleStartAt > now, attempt: attempt, suffix: "sale-start", icon: "ticket", label: "申込開始", title: title, date: attempt.saleStartAt, plan: plan, tint: tint, priority: 12)
        appendAttention(&result, if: attempt.applyDeadlineAt > now, attempt: attempt, suffix: "apply-deadline", icon: "hourglass", label: "申込締切", title: title, date: attempt.applyDeadlineAt, plan: plan, tint: .red, priority: 1)
        appendAttention(&result, if: attempt.resultAnnounceAt > now, attempt: attempt, suffix: "result", icon: "checkmark.seal", label: "当落発表", title: title, date: attempt.resultAnnounceAt, plan: plan, tint: .purple, priority: 5)
        appendAttention(&result, if: attempt.paymentDeadlineAt > now, attempt: attempt, suffix: "payment", icon: "yensign.circle", label: "入金締切", title: title, date: attempt.paymentDeadlineAt, plan: plan, tint: .orange, priority: 2)
        appendAttention(&result, if: attempt.issueStartAt > now, attempt: attempt, suffix: "issue-start", icon: "ticket.fill", label: "発券開始", title: title, date: attempt.issueStartAt, plan: plan, tint: .teal, priority: 10)
        return result
    }

    private func appendAttention(
        _ items: inout [HomeAttentionItem],
        if condition: Bool,
        attempt: TicketAttempt,
        suffix: String,
        icon: String,
        label: String,
        title: String,
        date: Date,
        plan: Plan?,
        tint: Color,
        priority: Int
    ) {
        guard condition else { return }
        items.append(HomeAttentionItem(
            id: "ticket-\(attempt.id.uuidString)-\(suffix)",
            icon: icon,
            title: title,
            subtitle: "\(label) \(dateText(date))",
            dueDate: date,
            plan: plan,
            tint: tint,
            priority: priority
        ))
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "ja_JP"))
                .month(.defaultDigits)
                .day()
                .hour()
                .minute()
        )
    }
}

private struct ExperienceGalleryCard: View {
    let visit: HomeVisitSnapshot

    @Environment(\.displayScale) private var displayScale
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var thumbnailImage: UIImage?

    private var categoryColor: Color {
        themePalette.categoryColor(hex: visit.categoryColorHex)
    }

    // 190pt幅カード。scale過剰を避けるため上限クランプ。
    private var thumbnailMaxPixel: CGFloat {
        min(200 * displayScale, 1200)
    }

    // 写真ID＋表示サイズをキーに含める（サイズ違いは別キャッシュ・task再実行の判定にも使う）
    private func cacheKey(for photo: HomePhotoSnapshot) -> String {
        "\(photo.id.uuidString)@\(Int(thumbnailMaxPixel.rounded()))"
    }

    private var thumbnailTaskID: String? {
        visit.photo.map { cacheKey(for: $0) }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let photo = visit.photo else {
            thumbnailImage = nil
            return
        }
        let targetID = photo.id
        let key = cacheKey(for: photo)
        if let cached = ThumbnailLoader.cached(forKey: key) {
            thumbnailImage = cached
            return
        }
        let data = photo.data // SwiftData プロパティはメインで読み、値型で渡す
        let maxPixel = thumbnailMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixel, cacheKey: key)
        }.value
        // セル再利用や写真変更後に遅れて届いた結果で、別の写真の画像を上書きしない
        guard !Task.isCancelled, visit.photo?.id == targetID else { return }
        thumbnailImage = image
    }

    private var statusText: String? {
        visitTicketStatusText(visit.outcomeKey)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(categoryColor.opacity(0.18))
                    Image(systemName: visit.eyecatchPath.isEmpty ? "sparkles" : "photo.fill")
                        .font(.largeTitle)
                        .foregroundStyle(categoryColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(visit.categoryName)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())

                    if let statusText {
                        Text(statusText)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(10)
            }
            .aspectRatio(CGFloat(visit.eyecatchAspectRatio), contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(visit.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                Label(visit.visitedAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if !visit.venueName.isEmpty {
                    Label(visit.venueName, systemImage: "mappin.and.ellipse")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !visit.peopleSummary.isEmpty {
                    Label(visit.peopleSummary, systemImage: "person.2")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if visit.amount != Decimal(0) || !unitFields.ocrText.isEmpty || !unitFields.advancedEntries.isEmpty {
                    HStack(spacing: 6) {
                        if visit.amount != Decimal(0) {
                            HomeVisitBadge(text: formattedVisitAmount(visit.amount), icon: "yensign.circle")
                        }
                        if !unitFields.ocrText.isEmpty {
                            HomeVisitBadge(text: "OCR", icon: "text.viewfinder")
                        }
                        if !unitFields.advancedEntries.isEmpty {
                            HomeVisitBadge(text: "詳細", icon: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .frame(width: 190, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }
}

private struct HomeVisitSummaryRow: View {
    let visit: HomeVisitSnapshot

    @Environment(\.displayScale) private var displayScale
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var thumbnailImage: UIImage?

    private var categoryColor: Color {
        themePalette.categoryColor(hex: visit.categoryColorHex)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    private var thumbnailMaxPixel: CGFloat {
        min(80 * displayScale, 480)
    }

    private var thumbnailTaskID: String? {
        visit.photo.map { "\($0.id.uuidString)@\(Int(thumbnailMaxPixel.rounded()))" }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(visit.title)
                        .font(FavorecoTypography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let statusText = visitTicketStatusText(visit.outcomeKey) {
                        Text(statusText)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(categoryColor)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 10) {
                    Label(visit.visitedAt.formatted(date: .numeric, time: .omitted), systemImage: unitFields.weatherSymbolName.isEmpty ? "calendar" : unitFields.weatherSymbolName)
                    Label(visit.categoryName, systemImage: visit.categoryIcon)
                    if !visit.venueName.isEmpty {
                        Label(visit.venueName, systemImage: "mappin.and.ellipse")
                    }
                    if visit.overallRating > 0 {
                        Label(String(format: "%.1f", visit.overallRating), systemImage: "star.fill")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !visit.peopleSummary.isEmpty {
                    Label(visit.peopleSummary, systemImage: "person.2")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !visit.note.isEmpty {
                    Text(visit.note)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if visit.amount != Decimal(0) || !unitFields.ocrText.isEmpty || !unitFields.advancedEntries.isEmpty {
                    HStack(spacing: 6) {
                        if visit.amount != Decimal(0) {
                            HomeVisitBadge(text: formattedVisitAmount(visit.amount), icon: "yensign.circle")
                        }
                        if !unitFields.ocrText.isEmpty {
                            HomeVisitBadge(text: "OCR", icon: "text.viewfinder")
                        }
                        if !unitFields.advancedEntries.isEmpty {
                            HomeVisitBadge(text: "詳細", icon: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: visit.categoryIcon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 64, height: thumbnailHeight)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var thumbnailHeight: CGFloat {
        let rawHeight = 64 / max(0.45, visit.eyecatchAspectRatio)
        return min(96, max(56, rawHeight))
    }

    @MainActor
    private func loadThumbnail() async {
        guard let photo = visit.photo else {
            thumbnailImage = nil
            return
        }
        let key = "\(photo.id.uuidString)@\(Int(thumbnailMaxPixel.rounded()))"
        if let cached = ThumbnailLoader.cached(forKey: key) {
            thumbnailImage = cached
            return
        }
        let data = photo.data
        let maxPixel = thumbnailMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixel, cacheKey: key)
        }.value
        guard !Task.isCancelled, visit.photo?.id == photo.id else { return }
        thumbnailImage = image
    }
}

private struct HomePlanDestination: View {
    @Query private var plans: [Plan]

    init(planID: UUID) {
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(plan: plan)
        } else {
            ContentUnavailableView("予定が見つかりません", systemImage: "trash")
        }
    }
}

private struct HomeVisitDestination: View {
    @Query private var visits: [Visit]

    init(visitID: UUID) {
        _visits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

    var body: some View {
        if let visit = visits.first {
            ExperienceDetailView(visit: visit)
        } else {
            ContentUnavailableView("記録が見つかりません", systemImage: "trash")
        }
    }
}

private struct HomeEventDestination: View {
    @Query private var events: [ExperienceEvent]

    init(eventID: UUID) {
        _events = Query(filter: #Predicate<ExperienceEvent> { $0.id == eventID })
    }

    var body: some View {
        if let event = events.first {
            EventDetailView(event: event)
        } else {
            ContentUnavailableView("対象が見つかりません", systemImage: "trash")
        }
    }
}

private struct HomeInboxDestination: View {
    @Query private var items: [InboxItem]

    init(itemID: UUID) {
        _items = Query(filter: #Predicate<InboxItem> { $0.id == itemID })
    }

    var body: some View {
        if let item = items.first {
            InboxDetailView(item: item)
        } else {
            ContentUnavailableView("受信項目が見つかりません", systemImage: "trash")
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(FavorecoTypography.sectionTitle)
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct InboxItemRow: View {
    let item: HomeInboxItemSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = item.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let categoryName = item.categoryName {
                        Label(categoryName, systemImage: "square.grid.2x2")
                    }
                    if item.hasSourceURL {
                        Label("URL", systemImage: "link")
                    }
                    Label(item.createdAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeCategoryShortcut: View {
    let category: RecordCategory
    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: category.iconSymbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            Text(category.name.isEmpty ? "無題" : category.name)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 68, alignment: .top)
        .frame(minHeight: 64, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name.isEmpty ? "無題ジャンル" : category.name)
        .accessibilityHint("ジャンルトップを開きます")
    }
}

private struct HomeVisitBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private func visitTicketStatusText(_ key: String) -> String? {
    switch key {
    case "planned": return "予定"
    case "applied": return "申込中"
    case "won": return "当選"
    case "paid": return "入金済み"
    case "ticketed": return "発券済み"
    case "attended": return "参加済み"
    case "canceled": return "中止"
    default: return nil
    }
}

private func formattedVisitAmount(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "JPY"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
}

private struct EmptyStateRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomePaperGrainOverlay: View {
    let isDark: Bool

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let spacing: CGFloat = 4
            let columns = Int(ceil(size.width / spacing))
            let rows = Int(ceil(size.height / spacing))
            let color = isDark ? Color.white.opacity(0.13) : Color.black.opacity(0.14)

            for row in 0...rows {
                for column in 0...columns {
                    let seed = (column * 73 + row * 151 + column * row * 19) % 101
                    guard seed < 46 else { continue }

                    let offsetX = CGFloat((seed * 7) % 9) / 9 * 1.6
                    let offsetY = CGFloat((seed * 11) % 9) / 9 * 1.6
                    let side: CGFloat = seed.isMultiple(of: 5) ? 1.05 : 0.65
                    let rect = CGRect(
                        x: CGFloat(column) * spacing + offsetX,
                        y: CGFloat(row) * spacing + offsetY,
                        width: side,
                        height: side
                    )
                    var grain = Path()
                    grain.addRect(rect)
                    context.fill(grain, with: .color(color))
                }
            }
        }
        .blendMode(isDark ? .screen : .multiply)
        .opacity(isDark ? 0.10 : 0.16)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


#Preview {
    HomeView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}

extension Notification.Name {
    static let openFavorecoPlanList = Notification.Name("openFavorecoPlanList")
    static let openFavorecoPlanCreation = Notification.Name("openFavorecoPlanCreation")
}
