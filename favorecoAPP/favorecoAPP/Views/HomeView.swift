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
    @AppStorage(AppStorageKeys.showsHomeInterestingExpanded) private var isInterestingExpanded = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsStatsSummary = false
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var categoryLayoutModeRaw = HomeCategoryLayoutMode.horizontal.rawValue
    @State private var selectedUpcomingPlanIndex = 0
    @State private var interestLayoutMode: CategoryLibraryLayoutMode = .gallery
    @State private var isShowingAllHomeUpcoming = false
    @State private var isShowingNextActionList = false
    @State private var isShowingSampleDeletionConfirmation = false
    @State private var sampleDeletionError = ""
    @State private var swipeDestinationCategoryID: UUID?

    private var categoryLayoutMode: HomeCategoryLayoutMode {
        HomeCategoryLayoutMode(rawValue: categoryLayoutModeRaw) ?? .horizontal
    }

    private func nextActionItems(for snapshot: HomeSnapshot, now: Date = Date()) -> [HomeAttentionItem] {
        let ticketItems = snapshot.activeTicketAttempts.compactMap { attempt in
            nextActionItem(for: attempt, now: now)
        }
        let preparationItems = plans
            .filter { !$0.isArchived && $0.isPreparationChecklistActive }
            .flatMap { plan in
                preparationAttentionItems(for: plan, now: now)
            }
        let items = ticketItems
            + preparationItems
            + membershipAttentionItems(for: snapshot.expiringTicketAccounts)

        return items.sorted { lhs, rhs in
            if lhs.isOverdue != rhs.isOverdue {
                return lhs.isOverdue
            }
            if lhs.dueDate != rhs.dueDate {
                return lhs.dueDate < rhs.dueDate
            }
            return lhs.priority < rhs.priority
        }
    }

    private func preparationAttentionItems(for plan: Plan, now: Date) -> [HomeAttentionItem] {
        let planTitle = plan.title.isEmpty ? "予定" : plan.title
        let tint = themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
        return plan.preparationFields.tasks.compactMap { task in
            guard !task.isCompleted,
                  !task.trimmedTitle.isEmpty,
                  let dueAt = task.dueAt else {
                return nil
            }
            let isOverdue = dueAt < now
            return HomeAttentionItem(
                id: "preparation-\(plan.id.uuidString)-\(task.id.uuidString)",
                icon: "checklist",
                title: task.trimmedTitle,
                subtitle: "\(planTitle)・\(FavorecoDateText.compactDateTime(dueAt))",
                contextTitle: planTitle,
                dueDate: dueAt,
                plan: plan,
                tint: isOverdue ? .red : tint,
                priority: 50,
                isOverdue: isOverdue
            )
        }
    }

    private func membershipAttentionItems(for accounts: [TicketAccount]) -> [HomeAttentionItem] {
        accounts
            .map { account in
                HomeAttentionItem(
                    id: "membership-\(account.id.uuidString)-expiry",
                    icon: "person.text.rectangle",
                    title: "会員期限",
                    subtitle: "\(account.serviceName.isEmpty ? "登録サービス" : account.serviceName)・\(FavorecoDateText.compactDateTime(account.expiryDate))",
                    contextTitle: account.serviceName.isEmpty ? "登録サービス" : account.serviceName,
                    dueDate: account.expiryDate,
                    tint: Color(hex: account.colorHex),
                    priority: 8,
                    isOverdue: false
                )
            }
    }

    private func nextActionItem(for attempt: TicketAttempt, now: Date) -> HomeAttentionItem? {
        guard let action = TicketNextActionDefinition.nextAction(for: attempt, now: now) else {
            return nil
        }

        let plan = attempt.plan
        let planTitle = plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定"
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        return HomeAttentionItem(
            id: "ticket-\(attempt.id.uuidString)-\(action.title)-\(action.date.timeIntervalSinceReferenceDate)",
            icon: action.systemImage,
            title: action.title,
            subtitle: "\(planTitle)・\(FavorecoDateText.compactDateTime(action.date))",
            contextTitle: planTitle,
            dueDate: action.date,
            plan: plan,
            tint: action.isOverdue ? .red : tint,
            priority: action.priority,
            isOverdue: action.isOverdue
        )
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
        let ticketProgressItems = CategoryTicketProgressItem.activeItems(in: plans)
        let homeNextActionItems = nextActionItems(for: snapshot)
        let hasSampleData = events.contains { event in
            event.officialURL.starts(with: SampleDataSeeder.sampleURLPrefix)
                || event.officialURL.starts(with: "https://example.com/favoreco/")
        }

        NavigationStack {
            VStack(spacing: 0) {
                MainScreenHeader(title: "Favoreco", usesBrandFont: true)
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .padding(.bottom, 6)

                if showsCategories, !snapshot.visibleCategories.isEmpty {
                    GenreNavigationStrip(categories: snapshot.visibleCategories)
                        .padding(.horizontal, 18)
                }

                MainHeaderDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        homeHeroSection(items: snapshot.heroItems)

                        if hasSampleData {
                            HomeSampleDataNotice {
                                isShowingSampleDeletionConfirmation = true
                            }
                        }

                        GenreSwipeContainer(
                            canMoveBackward: !snapshot.visibleCategories.isEmpty,
                            canMoveForward: !snapshot.visibleCategories.isEmpty,
                            onMove: { direction in
                                let destination = direction > 0
                                    ? snapshot.visibleCategories.first
                                    : snapshot.visibleCategories.last
                                swipeDestinationCategoryID = destination?.id
                            }
                        ) {
                            VStack(alignment: .leading, spacing: 24) {
                                if showsAttention {
                                    nextActionSection(items: homeNextActionItems)
                                    ticketScheduleSection(items: ticketProgressItems)
                                }

                                if showsInbox {
                                    inboxSection(
                                        interestedEvents: snapshot.interestedEvents,
                                        unresolvedInboxItems: snapshot.unresolvedInboxItems
                                    )
                                }

                                homeComingUpSection(items: snapshot.upcomingItems)

                                if showsExperienceGallery && !snapshot.recentVisits.isEmpty {
                                    experienceGallerySection(visits: snapshot.recentVisits)
                                }

                                if showsRecentRecords && !snapshot.recentVisits.isEmpty {
                                    recentSection(visits: snapshot.recentVisits)
                                }

                                if showsStatsSummary && snapshot.visibleVisitCount > 0 {
                                    statsSummarySection(snapshot: snapshot)
                                }

                                crossGenreMiniStats(snapshot: snapshot)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(homeBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingNextActionList) {
                HomeAttentionListView(items: homeNextActionItems)
            }
            .confirmationDialog(
                "サンプルデータを削除しますか？",
                isPresented: $isShowingSampleDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button("サンプルだけ削除", role: .destructive) {
                    do {
                        _ = try SampleDataSeeder.deleteSamples(in: modelContext)
                    } catch {
                        sampleDeletionError = "サンプルデータを削除できませんでした。"
                        assertionFailure("Failed to delete sample data: \(error)")
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("自分で追加した記録・予定・人物・場所マスターは削除されません。")
            }
            .alert("削除できませんでした", isPresented: Binding(
                get: { !sampleDeletionError.isEmpty },
                set: { if !$0 { sampleDeletionError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sampleDeletionError)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { swipeDestinationCategoryID != nil },
                    set: { isPresented in
                        if !isPresented {
                            swipeDestinationCategoryID = nil
                        }
                    }
                )
            ) {
                if let categoryID = swipeDestinationCategoryID,
                   let category = snapshot.visibleCategories.first(where: { $0.id == categoryID }) {
                    CategoryTopView(category: category)
                }
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

    private func homeHeroSection(items: [HomeUpcomingItem]) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
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
                upcomingItemLink(items[0])

            default:
                GeometryReader { geometry in
                    let cardWidth = max(0, geometry.size.width)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                upcomingItemLink(item)
                                    .frame(width: cardWidth, alignment: .top)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: selectedUpcomingPlanPosition)
                }
                .frame(height: HomeUpcomingHeroMetrics.cardHeight)

                HStack(spacing: 7) {
                    ForEach(items.indices, id: \.self) { index in
                        Circle()
                            .fill(
                                index == selectedUpcomingPlanIndex
                                    ? themePalette.globalTint
                                    : Color.secondary.opacity(0.28)
                            )
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityElement(children: .ignore)
                    .accessibilityLabel("ピックアップ \(min(selectedUpcomingPlanIndex + 1, items.count))件目、全\(items.count)件")
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

    private var selectedUpcomingPlanPosition: Binding<Int?> {
        Binding(
            get: { selectedUpcomingPlanIndex },
            set: { newValue in
                if let newValue {
                    selectedUpcomingPlanIndex = newValue
                }
            }
        )
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

    private func nextActionSection(items: [HomeAttentionItem]) -> some View {
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
                            PlanDetailView(plan: plan)
                        } label: {
                            HomeNextActionCapsuleRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeNextActionCapsuleRow(item: item)
                    }
                }

                if items.count > 3 {
                    Button {
                        isShowingNextActionList = true
                    } label: {
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

    @ViewBuilder
    private func ticketScheduleSection(items: [CategoryTicketProgressItem]) -> some View {
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ticket Schedule")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                    Text("進行中のチケット予定はありません")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else {
            CategoryTicketProgressSection(
                items: items,
                title: "Ticket Schedule",
                usesLatinTitle: true,
                usesTheaterStyle: false,
                showsCategoryInSelector: true
            )
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
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(visits) { visit in
                        NavigationLink {
                            HomeVisitDestination(visitID: visit.id)
                        } label: {
                            ExperienceGalleryCard(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
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
        let items = interestedEvents.map(HomeInterestingItem.event)
            + unresolvedInboxItems.map(HomeInterestingItem.inbox)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Interesting")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if isInterestingExpanded, !items.isEmpty {
                    CategoryLibraryLayoutPicker(
                        selection: $interestLayoutMode,
                        tint: themePalette.globalTint,
                        onSelect: { _ in }
                    )
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isInterestingExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))
                        .rotationEffect(.degrees(isInterestingExpanded ? 0 : -90))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isInterestingExpanded ? "Interestingを閉じる" : "Interestingを開く")
            }

            if isInterestingExpanded {
                if items.isEmpty {
                    EmptyStateRow(
                        icon: "tray",
                        title: "気になる対象はありません",
                        message: "クイック登録した作品や場所がここに表示されます。"
                    )
                } else {
                    HomeInterestingCollection(
                        items: items,
                        layout: interestLayoutMode,
                        tint: themePalette.globalTint
                    )
                    .id("home-interesting-\(interestLayoutMode.rawValue)")
                }
            }
        }
    }

    private func homeComingUpSection(items: [HomeUpcomingItem]) -> some View {
        let visibleItems = isShowingAllHomeUpcoming ? items : Array(items.prefix(1))

        return VStack(alignment: .leading, spacing: 10) {
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
                ForEach(visibleItems) { item in
                    HomeComingUpLink(item: item)
                }

                if items.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isShowingAllHomeUpcoming.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(themePalette.globalTint.opacity(0.24))
                                .frame(height: 0.6)
                            Text(isShowingAllHomeUpcoming ? "閉じる" : "さらに\(items.count - 1)件")
                                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(themePalette.globalTint)
                            Rectangle()
                                .fill(themePalette.globalTint.opacity(0.24))
                                .frame(height: 0.6)
                        }
                        .frame(minHeight: 44)
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
                .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
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
                    .aspectRatio(contentMode: event.fillsEyecatchFrame ? .fill : .fit)
                    .frame(width: 64, height: interestedEyecatchHeight)
                    .clipped()
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

    private var interestedEyecatchHeight: CGFloat {
        guard event.fillsEyecatchFrame else { return 78 }
        return 64 / CGFloat(event.eyecatchAspectRatio)
    }
}

private enum HomeInterestingItem: Identifiable {
    case event(HomeInterestedEventSnapshot)
    case inbox(HomeInboxItemSnapshot)

    var id: String {
        switch self {
        case .event(let event): "event-\(event.id.uuidString)"
        case .inbox(let item): "inbox-\(item.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .event(let event): event.title
        case .inbox(let item): item.title
        }
    }

    var categoryName: String {
        switch self {
        case .event(let event): event.categoryName ?? "気になる"
        case .inbox(let item): item.categoryName ?? "未整理"
        }
    }

    var categoryIcon: String {
        switch self {
        case .event(let event): event.categoryIcon ?? "bookmark"
        case .inbox(let item): item.categoryIcon ?? "tray"
        }
    }

    var colorHex: String {
        switch self {
        case .event(let event): event.categoryColorHex
        case .inbox(let item): item.categoryColorHex
        }
    }

    var imageData: Data? {
        switch self {
        case .event(let event): event.eyecatchData
        case .inbox(let item): item.eyecatchData
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .event(let event): CGFloat(event.eyecatchAspectRatio)
        case .inbox: 1
        }
    }

    var detailText: String {
        switch self {
        case .event(let event): event.memo
        case .inbox(let item): item.body
        }
    }
}

private struct HomeInterestingCollection: View {
    let items: [HomeInterestingItem]
    let layout: CategoryLibraryLayoutMode
    let tint: Color

    @State private var visibleCount: Int

    init(items: [HomeInterestingItem], layout: CategoryLibraryLayoutMode, tint: Color) {
        self.items = items
        self.layout = layout
        self.tint = tint
        _visibleCount = State(initialValue: Self.pageSize(for: layout))
    }

    var body: some View {
        let pageSize = Self.pageSize(for: layout)
        let visibleItems = Array(items.prefix(min(items.count, visibleCount)))

        VStack(alignment: .leading, spacing: 10) {
            switch layout {
            case .gallery:
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(visibleItems) { item in
                        HomeInterestingLink(item: item) {
                            HomeInterestingPosterCard(item: item)
                        }
                    }
                }
            case .compact:
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 2),
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(visibleItems) { item in
                        HomeInterestingLink(item: item) {
                            HomeInterestingCompactCard(item: item)
                        }
                    }
                }
            case .banner:
                LazyVStack(spacing: 10) {
                    ForEach(visibleItems) { item in
                        HomeInterestingLink(item: item) {
                            HomeInterestingBannerCard(item: item)
                        }
                    }
                }
            }

            if items.count > pageSize {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        visibleCount = visibleCount >= items.count
                            ? pageSize
                            : min(items.count, visibleCount + pageSize)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Rectangle().fill(tint.opacity(0.24)).frame(height: 0.6)
                        Text(visibleCount >= items.count ? "閉じる" : "さらに\(items.count - visibleCount)件")
                            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                        Rectangle().fill(tint.opacity(0.24)).frame(height: 0.6)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func pageSize(for layout: CategoryLibraryLayoutMode) -> Int {
        switch layout {
        case .gallery: 9
        case .compact: 8
        case .banner: 6
        }
    }
}

private struct HomeInterestingLink<Label: View>: View {
    let item: HomeInterestingItem
    @ViewBuilder let label: Label

    var body: some View {
        NavigationLink {
            switch item {
            case .event(let event):
                HomeEventDestination(eventID: event.id)
            case .inbox(let inbox):
                HomeInboxDestination(itemID: inbox.id)
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.categoryName)、\(item.title)")
    }
}

private struct HomeInterestingArtwork: View {
    let item: HomeInterestingItem

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemFill)
                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: item.categoryIcon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: item.colorHex))
                }
            }
        }
        .clipped()
    }
}

private struct HomeInterestingPosterCard: View {
    let item: HomeInterestingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeInterestingArtwork(item: item)
                .aspectRatio(item.aspectRatio, contentMode: .fit)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.categoryName)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: item.colorHex))
                    .lineLimit(1)
                Text(item.title)
                    .font(FavorecoTypography.jpSans(10.5, weight: .semibold, relativeTo: .caption))
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(6)
        }
        .background(Color(.secondarySystemBackground))
        .overlay { Rectangle().stroke(Color(hex: item.colorHex).opacity(0.18), lineWidth: 0.5) }
    }
}

private struct HomeInterestingCompactCard: View {
    let item: HomeInterestingItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HomeInterestingArtwork(item: item)
                .frame(width: 58, height: 90)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.categoryName)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: item.colorHex))
                    .lineLimit(1)
                Text(item.title)
                    .font(FavorecoTypography.jpSans(11, weight: .bold, relativeTo: .caption))
                    .lineLimit(2, reservesSpace: true)
                if !item.detailText.isEmpty {
                    Text(item.detailText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 7)
            .padding(.trailing, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 106, maxHeight: 106, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: item.colorHex).opacity(0.20), lineWidth: 0.75)
        }
    }
}

private struct HomeInterestingBannerCard: View {
    let item: HomeInterestingItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HomeInterestingArtwork(item: item)
                .frame(width: 82, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.categoryName)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color(hex: item.colorHex))
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Color(hex: item.colorHex).opacity(0.12), in: Capsule())
                Text(item.title)
                    .font(FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .headline))
                    .lineLimit(2, reservesSpace: true)
                if !item.detailText.isEmpty {
                    Text(item.detailText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 45)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: item.colorHex).opacity(0.20), lineWidth: 0.75)
        }
    }
}

private struct HomeComingUpLink: View {
    let item: HomeUpcomingItem

    var body: some View {
        switch item {
        case .plan(let plan):
            NavigationLink {
                HomePlanDestination(planID: plan.id)
            } label: {
                HomeComingUpRow(
                    title: plan.title,
                    categoryName: plan.categoryName,
                    categoryIcon: plan.categoryIcon,
                    colorHex: plan.categoryColorHex,
                    date: plan.startsAt,
                    place: plan.venueName,
                    imageData: plan.posterData
                )
            }
            .buttonStyle(.plain)
        case .visit(let visit):
            NavigationLink {
                HomeVisitDestination(visitID: visit.id)
            } label: {
                HomeComingUpRow(
                    title: visit.title,
                    categoryName: visit.categoryName,
                    categoryIcon: visit.categoryIcon,
                    colorHex: visit.categoryColorHex,
                    date: visit.visitedAt,
                    place: visit.venueName,
                    imageData: visit.photo?.data
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeComingUpRow: View {
    let title: String
    let categoryName: String
    let categoryIcon: String
    let colorHex: String
    let date: Date
    let place: String
    let imageData: Data?

    var body: some View {
        let tint = Color(hex: colorHex)
        FavorecoComingUpRow(
            date: date,
            categoryName: categoryName,
            title: title,
            venue: place,
            tint: tint,
            isTheater: false
        ) {
            ZStack {
                Color(.secondarySystemFill)
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
            }
            .clipped()
        }
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
                tint: tint,
                fillsFrame: plan.fillsPosterFrame
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
        .frame(height: HomeUpcomingHeroMetrics.contentHeight, alignment: .top)
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
    @Query private var currentVisits: [Visit]
    @State private var isShowingEditVisit = false
    @Environment(\.favorecoThemePalette) private var themePalette

    init(visit: HomeVisitSnapshot) {
        self.visit = visit
        let visitID = visit.id
        _currentVisits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

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
                tint: tint,
                fillsFrame: visit.fillsEyecatchFrame
            )

            HomeUpcomingHeroDetails(
                categoryName: visit.categoryName,
                title: visit.title,
                subtitle: "",
                dateText: dateText,
                venueName: visit.venueName,
                tint: tint
            ) {
                HStack(spacing: 6) {
                    NavigationLink {
                        HomeVisitDestination(visitID: visit.id)
                    } label: {
                        HomeUpcomingActionLabel(
                            title: "詳細",
                            systemImage: "book.pages",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingEditVisit = true
                    } label: {
                        HomeUpcomingSecondaryActionLabel(title: "編集")
                    }
                    .buttonStyle(.plain)
                    .disabled(currentVisits.isEmpty)
                }
            }
        }
        .frame(height: HomeUpcomingHeroMetrics.contentHeight, alignment: .top)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isShowingEditVisit) {
            if let currentVisit = currentVisits.first {
                EditExperienceView(visit: currentVisit)
            } else {
                ContentUnavailableView("記録が見つかりません", systemImage: "trash")
            }
        }
    }

}

private enum HomeUpcomingHeroMetrics {
    static let contentHeight: CGFloat = 250
    static let cardHeight: CGFloat = contentHeight + 24
}

private struct HomeUpcomingHeroLayout: Layout {
    let posterAspectRatio: CGFloat
    private let posterFraction: CGFloat = 0.46
    private let maximumPosterWidth: CGFloat = 148
    private let spacing: CGFloat = 10

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
    let fillsFrame: Bool

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(categoryName)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(tint)

            Text(title)
                .font(FavorecoTypography.jpSerif(19, weight: .bold, relativeTo: .headline))
                .foregroundStyle(.primary)
                .lineSpacing(-2)
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

            Spacer(minLength: 0)

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
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .overlay {
                Capsule().stroke(tint.opacity(0.55), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private struct HomeUpcomingSecondaryActionLabel: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "pencil")
            .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
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
        .frame(
            maxWidth: .infinity,
            minHeight: HomeUpcomingHeroMetrics.cardHeight,
            maxHeight: HomeUpcomingHeroMetrics.cardHeight
        )
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
    var contextTitle = ""
    let dueDate: Date
    var plan: Plan? = nil
    let tint: Color
    let priority: Int
    var isOverdue = false
}

private struct HomeNextActionCapsuleRow: View {
    let item: HomeAttentionItem

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(item.tint)
                .frame(width: 18)

            Text(FavorecoDateText.compactDateWithHalfWidthWeekday(item.dueDate))
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(item.isOverdue ? Color.red : .secondary)
                .fixedSize(horizontal: true, vertical: false)

            Text("|")
                .foregroundStyle(.tertiary)

            Text(item.title)
                .font(FavorecoTypography.jpSans(12, weight: .bold, relativeTo: .caption))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if !item.contextTitle.isEmpty {
                Text("|")
                    .foregroundStyle(.tertiary)

                Text(item.contextTitle)
                    .font(FavorecoTypography.jpSans(11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
        .background(.background, in: Capsule())
        .overlay {
            Capsule()
                .stroke(item.tint.opacity(item.isOverdue ? 0.42 : 0.18), lineWidth: 0.75)
        }
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FavorecoDateText.compactDate(item.dueDate))、\(item.title)、\(item.contextTitle)")
    }
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
            .navigationTitle("次にやること")
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

    // 2列カード。scale過剰を避けるため上限クランプ。
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
                        .aspectRatio(contentMode: visit.fillsEyecatchFrame ? .fill : .fit)
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
            .aspectRatio(CGFloat(visit.eyecatchAspectRatio), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(categoryColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(visit.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar")
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: unitFields.weatherSymbolName.isEmpty ? "calendar" : unitFields.weatherSymbolName)
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
                .aspectRatio(contentMode: visit.fillsEyecatchFrame ? .fill : .fit)
                .frame(width: 64, height: thumbnailHeight)
                .clipped()
                .background(categoryColor.opacity(0.08))
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
                    Label(FavorecoDateText.compactDate(item.createdAt), systemImage: "calendar")
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

private struct HomeSampleDataNotice: View {
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: "#B8792F"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text("サンプルデータが入っています")
                    .font(FavorecoTypography.bodyStrong)
                Text("過去の記録、未来の予定、人物や場所の登録例を見ながら使い方を確認できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("サンプルを削除", role: .destructive, action: onDelete)
                    .font(FavorecoTypography.captionStrong)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#B8792F").opacity(0.28), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
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
