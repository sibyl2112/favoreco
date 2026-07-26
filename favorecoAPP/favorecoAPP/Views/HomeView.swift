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
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.createdAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \Plan.startsAt, order: .forward) private var plans: [Plan]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsAttention = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsCategories = true
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var categoryLayoutModeRaw = HomeCategoryLayoutMode.horizontal.rawValue
    @State private var isShowingNextActionList = false
    @State private var selectedQuickTicketAttempt: TicketAttempt?
    @State private var admissionPreparationPlan: Plan?
    @State private var isShowingSampleDeletionConfirmation = false
    @State private var sampleDeletionError = ""
    @State private var swipeDestinationCategoryID: UUID?
    @State private var pickupDetailTarget: HomePickupDetailTarget?

    private var categoryLayoutMode: HomeCategoryLayoutMode {
        HomeCategoryLayoutMode(rawValue: categoryLayoutModeRaw) ?? .horizontal
    }

    private func ticketScheduleItems(now: Date = Date()) -> [HomeAttentionItem] {
        let activeAttempts = ticketAttempts.filter { attempt in
            !attempt.isArchived
                && attempt.plan?.isArchived != true
                && !["lost", "attended", "skipped"].contains(attempt.statusKey)
        }
        let ticketItems = activeAttempts.compactMap { attempt in
            nextActionItem(for: attempt, now: now)
        }
        return ticketItems.sorted { lhs, rhs in
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
        let plan = attempt.plan
        let planTitle: String = {
            if let title = plan?.title, !title.isEmpty { return title }
            if let title = plan?.event?.title, !title.isEmpty { return title }
            return "予定"
        }()
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        if ["waitingIssue", "issued"].contains(attempt.statusKey),
           let plan,
           !plan.hasConfirmedSchedule {
            return HomeAttentionItem(
                id: "ticket-\(attempt.id.uuidString)-schedule",
                icon: "calendar.badge.plus",
                title: "参加日を設定",
                subtitle: "\(planTitle)・参加日未定",
                contextTitle: planTitle,
                dueDate: attempt.updatedAt,
                plan: plan,
                attempt: attempt,
                tint: .orange,
                priority: 0,
                showsDueDate: false
            )
        }
        guard let action = TicketNextActionDefinition.nextAction(for: attempt, now: now) else {
            let fallbackTitle: String? = {
                if let issue = TicketInputIssueDefinition.issue(for: attempt) {
                    return issue.title
                }
                switch attempt.statusKey {
                case "beforeApply": return "申込状況を更新"
                case "onSaleSoon": return "購入状況を更新"
                case "waitingResult": return "当落結果を入力"
                case "won", "waitingPayment": return "支払・取得状況を更新"
                case "waitingIssue": return "取得状況を更新"
                default: return nil
                }
            }()
            guard let fallbackTitle else { return nil }
            return HomeAttentionItem(
                id: "ticket-\(attempt.id.uuidString)-status",
                icon: TicketInputIssueDefinition.issue(for: attempt)?.systemImage ?? "arrow.right.circle",
                title: fallbackTitle,
                subtitle: planTitle,
                contextTitle: planTitle,
                dueDate: attempt.updatedAt,
                plan: plan,
                attempt: attempt,
                tint: tint,
                priority: 20,
                showsDueDate: false
            )
        }
        return HomeAttentionItem(
            id: "ticket-\(attempt.id.uuidString)-\(action.title)-\(action.date.timeIntervalSinceReferenceDate)",
            icon: action.systemImage,
            title: action.title,
            subtitle: "\(planTitle)・\(FavorecoDateText.compactDateTime(action.date))",
            contextTitle: planTitle,
            dueDate: action.date,
            plan: plan,
            attempt: attempt,
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
            personLinks: personLinks
        )
        let visibleCategories = categories.filter { !$0.isArchived }
        let homeNextActionItems = ticketScheduleItems()
        let hasSampleData = events.contains { event in
            event.officialURL.starts(with: SampleDataSeeder.sampleURLPrefix)
                || event.officialURL.starts(with: "https://example.com/favoreco/")
        }

        NavigationStack {
            VStack(spacing: 0) {
                MainScreenHeader(
                    title: "Favoreco",
                    usesBrandFont: true,
                    showsTicketManagement: true
                )
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .padding(.bottom, 6)

                if showsCategories, !visibleCategories.isEmpty {
                    GenreNavigationStrip(categories: visibleCategories)
                        .padding(.horizontal, 18)
                }

                MainHeaderDivider()

                ScrollView {
                    GenreSwipeContainer(
                        canMoveBackward: !visibleCategories.isEmpty,
                        canMoveForward: !visibleCategories.isEmpty,
                        onMove: { direction in
                            let destination = direction > 0
                                ? visibleCategories.first
                                : visibleCategories.last
                            swipeDestinationCategoryID = destination?.id
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 24) {
                            if showsAttention, !homeNextActionItems.isEmpty {
                                HomeAttentionSection(
                                    items: homeNextActionItems,
                                    onShowAll: { isShowingNextActionList = true },
                                    onSelectTicket: { selectedQuickTicketAttempt = $0 }
                                )
                            }

                            HomeHeroSection(
                                interestedEvents: snapshot.interestedEvents,
                                unresolvedInboxItems: snapshot.unresolvedInboxItems,
                                upcomingItems: snapshot.upcomingItems,
                                recordedVisits: snapshot.pickupRecordedVisits,
                                onSelectInterest: { pickupDetailTarget = $0 },
                                onSelectPlan: { pickupDetailTarget = .plan($0) },
                                onSelectVisit: { pickupDetailTarget = .visit($0) }
                            )

                            if hasSampleData {
                                HomeSampleDataNotice {
                                    isShowingSampleDeletionConfirmation = true
                                }
                            }

                            HomeReportSection(visits: snapshot.reportVisits)
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
                NavigationStack {
                    TicketOverviewView(showsCloseButton: true)
                }
            }
            .sheet(item: $selectedQuickTicketAttempt) { attempt in
                TicketQuickActionSheet(attempt: attempt)
            }
            .sheet(item: $admissionPreparationPlan) { plan in
                AdmissionPreparationConfirmationSheet(plan: plan)
                    .interactiveDismissDisabled()
            }
            .task(id: admissionPreparationCandidateID) {
                presentAdmissionPreparationIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                presentAdmissionPreparationIfNeeded()
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
            .navigationDestination(item: $swipeDestinationCategoryID) { categoryID in
                HomeCategoryDestination(categoryID: categoryID)
            }
            .navigationDestination(item: $pickupDetailTarget) { target in
                switch target {
                case .event(let eventID):
                    HomeEventDestination(eventID: eventID)
                case .inbox(let itemID):
                    HomeInboxDestination(itemID: itemID)
                case .plan(let planID):
                    HomePlanDestination(planID: planID)
                case .visit(let visitID):
                    HomeVisitDestination(visitID: visitID)
                }
            }
            .task {
                try? LegacyInboxMigrationService.migrateIfNeeded(in: modelContext)
            }
        }
    }

    private var admissionPreparationCandidate: Plan? {
        plans
            .filter { $0.shouldRequestAdmissionPreparationConfirmation() }
            .sorted { $0.startsAt < $1.startsAt }
            .first
    }

    private var admissionPreparationCandidateID: UUID? {
        admissionPreparationCandidate?.id
    }

    private func presentAdmissionPreparationIfNeeded() {
        guard admissionPreparationPlan == nil,
              let candidate = admissionPreparationCandidate else { return }
        admissionPreparationPlan = candidate
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

    private func statsSummarySection(snapshot: HomeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("統計サマリ", count: snapshot.visibleVisitCount)

            HStack(spacing: 12) {
                SummaryMetricCard(title: "記録", value: "\(snapshot.visibleVisitCount)", icon: "sparkles.rectangle.stack")
                SummaryMetricCard(title: "ジャンル", value: "\(snapshot.visibleCategoryCount)", icon: "square.grid.2x2")
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
            ThumbnailImage(
                reference: event.thumbnailReference,
                displaySize: CGSize(width: 64, height: interestedEyecatchHeight),
                contentMode: event.fillsEyecatchFrame ? .fill : .fit
            ) {
                Color(.secondarySystemFill)
            }
            .frame(width: 64, height: interestedEyecatchHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

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

enum HomeInterestingItem: Identifiable {
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

    var thumbnailReference: ThumbnailReference {
        switch self {
        case .event(let event): event.thumbnailReference
        case .inbox(let item): item.thumbnailReference
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .event(let event): CGFloat(event.eyecatchAspectRatio)
        case .inbox: 1
        }
    }

    var fillsEyecatchFrame: Bool {
        switch self {
        case .event(let event): event.fillsEyecatchFrame
        case .inbox: true
        }
    }

    var detailText: String {
        switch self {
        case .event(let event): event.memo
        case .inbox(let item): item.body
        }
    }

    var officialURLString: String {
        switch self {
        case .event(let event): event.officialURLString
        case .inbox(let item): item.sourceURLString
        }
    }

    var periodText: String {
        switch self {
        case .event(let event): event.periodText
        case .inbox: ""
        }
    }

    var venueName: String {
        switch self {
        case .event(let event): event.venueName
        case .inbox: ""
        }
    }

    var detailTarget: HomePickupDetailTarget {
        switch self {
        case .event(let event): .event(event.id)
        case .inbox(let item): .inbox(item.id)
        }
    }

    var sortDate: Date {
        switch self {
        case .event(let event): event.updatedAt
        case .inbox(let item): item.createdAt
        }
    }
}

enum HomePickupDetailTarget: Hashable {
    case event(UUID)
    case inbox(UUID)
    case plan(UUID)
    case visit(UUID)
}

struct HomeInterestingCollection: View {
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
            ThumbnailImage(
                reference: item.thumbnailReference,
                displaySize: geometry.size,
                contentMode: .fill
            ) {
                ZStack {
                    Color(.secondarySystemFill)
                    Image(systemName: item.categoryIcon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: item.colorHex))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
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

struct HomeComingUpLink: View {
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
                    timeText: plan.comingUpTimeText,
                    place: plan.venueName,
                    thumbnailReference: plan.thumbnailReference
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
                    timeText: visit.comingUpTimeText,
                    place: visit.venueName,
                    thumbnailReference: visit.thumbnailReference
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
    let timeText: String
    let place: String
    let thumbnailReference: ThumbnailReference?

    var body: some View {
        let tint = Color(hex: colorHex)
        FavorecoComingUpRow(
            date: date,
            timeText: timeText,
            categoryName: categoryName,
            title: title,
            venue: place,
            tint: tint,
            isTheater: false
        ) {
            ThumbnailImage(
                reference: thumbnailReference,
                displaySize: CGSize(width: 72, height: 88),
                contentMode: .fill
            ) {
                ZStack {
                    Color(.secondarySystemFill)
                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
            }
            .clipped()
        }
    }
}

struct HomeUpcomingPlanCard: View {
    let plan: HomePlanSnapshot
    let isEmbedded: Bool
    let onOpen: () -> Void
    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false
    @Environment(\.favorecoThemePalette) private var themePalette

    init(
        plan: HomePlanSnapshot,
        isEmbedded: Bool = false,
        onOpen: @escaping () -> Void
    ) {
        self.plan = plan
        self.isEmbedded = isEmbedded
        self.onOpen = onOpen
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
        HomeUpcomingHeroLayout {
            HomeUpcomingPoster(
                thumbnailReference: plan.thumbnailReference,
                fallbackIcon: plan.categoryIcon,
                tint: tint,
                fillsFrame: plan.fillsPosterFrame
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HomeUpcomingHeroDetails(
                categoryName: plan.categoryName,
                title: plan.title,
                subtitle: plan.subtitle.isEmpty ? plan.organizerName : plan.subtitle,
                dateText: dateText,
                venueName: plan.venueName,
                officialURLString: plan.officialURLString,
                tint: tint,
                onOpen: onOpen
            ) {
                HStack(spacing: 6) {
                    Button(action: onOpen) {
                        HomeUpcomingActionLabel(
                            title: "予定詳細",
                            systemImage: "book.pages",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 110)

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
                    .frame(width: 64)
                    .disabled(currentPlans.isEmpty)
                }
            }
        }
        .frame(
            height: isEmbedded
                ? HomeUpcomingHeroMetrics.embeddedContentHeight
                : HomeUpcomingHeroMetrics.contentHeight,
            alignment: .top
        )
        .padding(isEmbedded ? HomeUpcomingHeroMetrics.embeddedPadding : 12)
        .background(isEmbedded ? Color.clear : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isEmbedded ? 0 : 0.18), lineWidth: 1)
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

struct HomeUpcomingVisitCard: View {
    let visit: HomeVisitSnapshot
    let isEmbedded: Bool
    let onOpen: () -> Void
    @Query private var currentVisits: [Visit]
    @State private var isShowingEditVisit = false
    @Environment(\.favorecoThemePalette) private var themePalette

    init(
        visit: HomeVisitSnapshot,
        isEmbedded: Bool = false,
        onOpen: @escaping () -> Void
    ) {
        self.visit = visit
        self.isEmbedded = isEmbedded
        self.onOpen = onOpen
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
        HomeUpcomingHeroLayout {
            HomeUpcomingPoster(
                thumbnailReference: visit.thumbnailReference,
                fallbackIcon: visit.categoryIcon,
                tint: tint,
                fillsFrame: visit.fillsEyecatchFrame
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HomeUpcomingHeroDetails(
                categoryName: visit.categoryName,
                title: visit.title,
                subtitle: visit.peopleSummary,
                dateText: dateText,
                venueName: visit.venueName,
                officialURLString: visit.officialURLString,
                tint: tint,
                onOpen: onOpen
            ) {
                HStack(spacing: 6) {
                    Button(action: onOpen) {
                        HomeUpcomingActionLabel(
                            title: "記録詳細",
                            systemImage: "book.pages",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 110)

                    Button {
                        isShowingEditVisit = true
                    } label: {
                        HomeUpcomingActionLabel(
                            title: "編集",
                            systemImage: "pencil",
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 64)
                    .disabled(currentVisits.isEmpty)
                }
            }
        }
        .frame(
            height: isEmbedded
                ? HomeUpcomingHeroMetrics.embeddedContentHeight
                : HomeUpcomingHeroMetrics.contentHeight,
            alignment: .top
        )
        .padding(isEmbedded ? HomeUpcomingHeroMetrics.embeddedPadding : 12)
        .background(isEmbedded ? Color.clear : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isEmbedded ? 0 : 0.18), lineWidth: 1)
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

enum HomeUpcomingHeroMetrics {
    static let contentHeight: CGFloat = 224
    static let cardHeight: CGFloat = contentHeight + 24
    static let posterWidth: CGFloat = 132
    static let posterHeight: CGFloat = 196
    static let spacing: CGFloat = 12
    static let embeddedPadding: CGFloat = 2
    static let embeddedContentHeight: CGFloat = posterHeight
    static let embeddedCardHeight: CGFloat = embeddedContentHeight + (embeddedPadding * 2)
}

struct HomeUpcomingHeroLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 340
        let detailsWidth = max(
            0,
            width - HomeUpcomingHeroMetrics.posterWidth - HomeUpcomingHeroMetrics.spacing
        )
        let detailsSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailsWidth, height: proposal.height)
        )
        return CGSize(
            width: width,
            height: max(HomeUpcomingHeroMetrics.posterHeight, detailsSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let detailsWidth = max(
            0,
            bounds.width - HomeUpcomingHeroMetrics.posterWidth - HomeUpcomingHeroMetrics.spacing
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: HomeUpcomingHeroMetrics.posterWidth,
                height: HomeUpcomingHeroMetrics.posterHeight
            )
        )
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX + HomeUpcomingHeroMetrics.posterWidth + HomeUpcomingHeroMetrics.spacing,
                y: bounds.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailsWidth, height: bounds.height)
        )
    }
}

private struct HomeUpcomingPoster: View {
    let thumbnailReference: ThumbnailReference?
    let fallbackIcon: String
    let tint: Color
    let fillsFrame: Bool

    var body: some View {
        GeometryReader { geometry in
            ThumbnailImage(
                reference: thumbnailReference,
                displaySize: geometry.size,
                contentMode: fillsFrame ? .fill : .fit
            ) {
                ZStack {
                    tint.opacity(0.14)
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

struct HomeUpcomingHeroDetails<Actions: View>: View {
    let categoryName: String
    let title: String
    let subtitle: String
    let dateText: String
    let venueName: String
    let officialURLString: String
    let tint: Color
    let onOpen: () -> Void
    let actions: Actions

    private var subtitleText: String {
        displayText(for: subtitle)
    }

    private var venueText: String {
        displayText(for: venueName)
    }

    init(
        categoryName: String,
        title: String,
        subtitle: String,
        dateText: String,
        venueName: String,
        officialURLString: String,
        tint: Color,
        onOpen: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.categoryName = categoryName
        self.title = title
        self.subtitle = subtitle
        self.dateText = dateText
        self.venueName = venueName
        self.officialURLString = officialURLString
        self.tint = tint
        self.onOpen = onOpen
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

                Text(subtitleText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(dateText, systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(venueText, systemImage: "mappin.and.ellipse")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HomePickupURLRow(urlString: officialURLString, tint: tint)

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func displayText(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "ー" : trimmed
    }
}

struct HomeUpcomingActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(title)
        }
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .overlay {
                Capsule().stroke(tint.opacity(0.48), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

struct HomePickupURLRow: View {
    @Environment(\.openURL) private var openURL

    let urlString: String
    let tint: Color

    private var destination: URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    var body: some View {
        if let destination {
            Button {
                openURL(destination)
            } label: {
                label("公式サイト", color: tint)
            }
            .buttonStyle(.plain)
            .accessibilityHint("外部ブラウザで開きます")
        } else {
            label("ー", color: .secondary)
                .accessibilityLabel("公式サイト、未設定")
        }
    }

    private func label(_ title: String, color: Color) -> some View {
        Label(title, systemImage: "safari")
            .font(FavorecoTypography.caption)
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .contentShape(Rectangle())
    }
}

struct HomeUpcomingEmptyCard: View {
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

struct HomeAttentionItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    var contextTitle = ""
    let dueDate: Date
    var plan: Plan? = nil
    var attempt: TicketAttempt? = nil
    let tint: Color
    let priority: Int
    var isOverdue = false
    var showsDueDate = true
}

nonisolated enum HomeTicketDeadlineUrgency: Equatable {
    case undated
    case normal
    case tomorrow
    case today
    case overdue

    static func resolve(
        dueDate: Date,
        showsDueDate: Bool,
        isOverdue: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeTicketDeadlineUrgency {
        guard showsDueDate else { return .undated }
        if isOverdue || dueDate < now { return .overdue }

        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        if days == 0 { return .today }
        if days == 1 { return .tomorrow }
        return .normal
    }
}

struct HomeTicketScheduleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let item: HomeAttentionItem

    @State private var isTodayShadowEmphasized = false
    @State private var todayShakeOffset: CGFloat = 0

    private var plan: Plan? { item.plan }
    private var attempt: TicketAttempt? { item.attempt }

    private var eventTitle: String {
        if let title = plan?.title, !title.isEmpty { return title }
        if let title = plan?.event?.title, !title.isEmpty { return title }
        return item.contextTitle.isEmpty ? "公演" : item.contextTitle
    }

    private var entryRouteTitle: String {
        let values = [entryRouteBadgeTitle, ticketSiteBadgeTitle].compactMap { $0 }
        return values.isEmpty ? "チケット" : values.joined(separator: "、")
    }

    private var entryRouteBadgeTitle: String? {
        guard let attempt, !attempt.entryRouteKey.isEmpty else { return nil }
        let title = TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private var ticketSiteBadgeTitle: String? {
        guard let attempt else { return nil }
        let title = attempt.ticketSite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let entryRouteBadgeTitle,
           entryRouteBadgeTitle.compare(
            title,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
           ) == .orderedSame {
            return nil
        }
        return title
    }

    private var deadlineLabel: String {
        if isAttendanceScheduleAction { return "参加日" }
        if item.title.contains("申込・発売") {
            guard let attempt else { return "チケ発売" }
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "抽選申込" : "チケ発売"
        }
        if item.title.contains("当落") { return "抽選当落" }
        if item.title.contains("入金") || item.title.contains("支払") { return "チケ支払" }
        if item.title.contains("受取") || item.title.contains("取得") { return "チケ取得" }
        if item.title.contains("発売") { return "チケ発売" }
        if item.title.contains("購入") { return "チケ発売" }
        if item.title.contains("申込") { return "抽選申込" }
        return item.title
    }

    private var isAttendanceScheduleAction: Bool {
        item.title == "参加日を設定"
    }

    private var scheduleText: String {
        guard let plan, plan.hasConfirmedSchedule else { return "参加日未定" }
        return FavorecoDateText.compactDateTime(plan.startsAt)
    }

    private var thumbnailReference: ThumbnailReference? {
        plan?.event.map { .event($0.id) }
    }

    private var categoryIcon: String {
        (plan?.category ?? plan?.event?.category)?.iconSymbol ?? "ticket"
    }

    private var urgency: HomeTicketDeadlineUrgency {
        HomeTicketDeadlineUrgency.resolve(
            dueDate: item.dueDate,
            showsDueDate: item.showsDueDate,
            isOverdue: item.isOverdue
        )
    }

    private var remainingDays: Int? {
        guard item.showsDueDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: item.dueDate)
        ).day
    }

    private var urgencyColor: Color {
        switch urgency {
        case .undated, .normal:
            return colorScheme == .dark
                ? Color(hex: "#D7CFBE")
                : Color(hex: "#243247")
        case .tomorrow:
            return Color(hex: "#D8555F")
        case .today:
            return Color(hex: "#E43D4C")
        case .overdue:
            return Color(hex: "#A91F32")
        }
    }

    private var statusColor: Color {
        switch deadlineLabel {
        case "チケ発売":
            return Color(hex: "#D47A36")
        case "抽選申込":
            return Color(hex: "#983650")
        case "抽選当落":
            return Color(hex: "#76528B")
        case "チケ支払":
            return Color(hex: "#247E85")
        case "チケ取得":
            return Color(hex: "#54745A")
        case "参加日":
            return Color(hex: "#B66A32")
        default:
            return item.tint
        }
    }

    private var entryMethodColor: Color {
        guard let attempt else { return item.tint }
        switch attempt.entryRouteKey {
        case "fanClub", "official", "lottery", "card", "generalLottery":
            return Color(hex: "#8E3657")
        case "presale", "general", "sameDay":
            return Color(hex: "#247E85")
        case "resale":
            return Color(hex: "#B66A32")
        default:
            return item.tint
        }
    }

    private var cardBorderWidth: CGFloat {
        switch urgency {
        case .today: return 1.8
        case .tomorrow, .overdue: return 1.5
        case .undated, .normal: return 0.9
        }
    }

    private var cardShadowColor: Color {
        switch urgency {
        case .today:
            return urgencyColor.opacity(0.28)
        case .tomorrow:
            return urgencyColor.opacity(0.16)
        case .undated, .normal, .overdue:
            return .clear
        }
    }

    private var cardShadowRadius: CGFloat {
        switch urgency {
        case .today: return 7
        case .tomorrow: return 4
        case .undated, .normal, .overdue: return 0
        }
    }

    private var displayedCardShadowColor: Color {
        guard urgency == .today, isTodayShadowEmphasized else {
            return cardShadowColor
        }
        return urgencyColor.opacity(colorScheme == .dark ? 0.62 : 0.52)
    }

    private var displayedCardShadowRadius: CGFloat {
        urgency == .today && isTodayShadowEmphasized ? 14 : cardShadowRadius
    }

    private var deadlineSupplement: String {
        guard item.showsDueDate else {
            return isAttendanceScheduleAction ? "日程を入力" : "期限を入力"
        }
        if urgency == .overdue { return "期限超過" }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: item.dueDate)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        if days < 0 { return "期限超過" }
        if days == 0 { return "今日" }
        if days == 1 { return "明日" }
        return "あと\(days)日"
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                ticketHorizontalStatusBadge(
                    deadlineLabel,
                    backgroundColor: statusColor
                )

                ThumbnailImage(
                    reference: thumbnailReference,
                    displaySize: CGSize(width: 64, height: 64),
                    contentMode: .fill
                ) {
                    ZStack {
                        item.tint.opacity(0.10)
                        Image(systemName: categoryIcon)
                            .font(.title2)
                            .foregroundStyle(item.tint)
                    }
                }
                .frame(width: 64, height: 64)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(width: 64)

            deadlineBlock
                .frame(width: 70, alignment: .center)

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: 86)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let entryRouteBadgeTitle {
                        ticketMetadataBadge(
                            entryRouteBadgeTitle,
                            backgroundColor: entryMethodColor
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                    }
                    if let ticketSiteBadgeTitle {
                        ticketMetadataBadge(
                            ticketSiteBadgeTitle,
                            backgroundColor: entryMethodColor
                        )
                        .layoutPriority(1)
                    }
                    if entryRouteBadgeTitle == nil, ticketSiteBadgeTitle == nil {
                        ticketMetadataBadge(
                            "チケット",
                            backgroundColor: entryMethodColor
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eventTitle)
                        .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Label(scheduleText, systemImage: plan?.hasConfirmedSchedule == true ? "calendar" : "calendar.badge.exclamationmark")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(plan?.hasConfirmedSchedule == true ? Color.primary.opacity(0.72) : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: displayedCardShadowColor,
                        radius: displayedCardShadowRadius,
                        y: 2
                    )
                if urgency == .overdue {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(urgencyColor.opacity(colorScheme == .dark ? 0.22 : 0.10))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    urgency == .normal || urgency == .undated
                        ? urgencyColor.opacity(0.22)
                        : urgencyColor,
                    lineWidth: cardBorderWidth
                )
        }
        .offset(x: todayShakeOffset)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            item.showsDueDate
                ? "\(deadlineLabel)、\(deadlineSupplement)、\(FavorecoDateText.compactDateTime(item.dueDate))、\(entryRouteTitle)、\(eventTitle)、\(scheduleText)"
                : "\(deadlineLabel)、\(isAttendanceScheduleAction ? "未定" : "要確認")、\(entryRouteTitle)、\(eventTitle)、\(scheduleText)"
        )
        .task(id: scenePhase) {
            await pulseTodayDeadlineShadowIfNeeded()
        }
    }

    private func pulseTodayDeadlineShadowIfNeeded() async {
        isTodayShadowEmphasized = false
        todayShakeOffset = 0
        guard scenePhase == .active,
              urgency == .today,
              !accessibilityReduceMotion else { return }

        do {
            try await Task.sleep(for: .milliseconds(160))
            for pulseIndex in 0..<2 {
                withAnimation(.easeInOut(duration: 0.32)) {
                    isTodayShadowEmphasized = true
                }
                try await shakeTodayDeadlineCard()
                try await Task.sleep(for: .milliseconds(70))
                withAnimation(.easeInOut(duration: 0.32)) {
                    isTodayShadowEmphasized = false
                }
                try await Task.sleep(for: .milliseconds(320))
                if pulseIndex == 0 {
                    try await Task.sleep(for: .milliseconds(120))
                }
            }
        } catch {
            isTodayShadowEmphasized = false
            todayShakeOffset = 0
        }
    }

    private func shakeTodayDeadlineCard() async throws {
        let offsets: [CGFloat] = [-2.5, 2.5, -1.6, 1.6, 0]
        for offset in offsets {
            withAnimation(.linear(duration: 0.05)) {
                todayShakeOffset = offset
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    @ViewBuilder
    private var deadlineBlock: some View {
        VStack(spacing: -2) {
            if item.showsDueDate {
                if urgency == .normal, let remainingDays, remainingDays >= 2 {
                    HStack(alignment: .center, spacing: 3) {
                        VStack(spacing: -4) {
                            Text("あ")
                            Text("と")
                        }
                        .font(FavorecoTypography.jpSerif(14, weight: .semibold, relativeTo: .caption))
                        .frame(height: 42, alignment: .center)

                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(remainingDays)")
                                .font(FavorecoTypography.latinDisplay(38, weight: .bold, relativeTo: .title))
                                .monospacedDigit()
                                .offset(y: -5)
                            Text("日")
                                .font(FavorecoTypography.jpSerif(15, weight: .semibold, relativeTo: .caption))
                        }
                        .frame(height: 42, alignment: .center)
                    }
                    .foregroundStyle(urgencyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                } else {
                    Text(deadlineSupplement)
                        .font(FavorecoTypography.jpSerif(
                            urgency == .overdue ? 14 : 19,
                            weight: .bold,
                            relativeTo: .title3
                        ))
                        .foregroundStyle(urgencyColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(urgency == .overdue ? 2 : 1)
                        .minimumScaleFactor(0.72)
                }

                HStack(spacing: 0) {
                    Text(FavorecoDateText.monthDay(item.dueDate))
                        .font(FavorecoTypography.latinDisplay(14, weight: .bold, relativeTo: .caption))
                        .monospacedDigit()
                    Text("(\(shortWeekday))")
                        .font(FavorecoTypography.jpSerif(11, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(.primary.opacity(0.78))
                .lineLimit(1)

                Text(FavorecoDateText.time(item.dueDate))
                    .font(FavorecoTypography.latinDisplay(14, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.primary.opacity(0.78))
                    .monospacedDigit()
                    .lineLimit(1)
            } else {
                Text(isAttendanceScheduleAction ? "未定" : "要確認")
                    .font(FavorecoTypography.jpSerif(
                        isAttendanceScheduleAction ? 20 : 15,
                        weight: .semibold,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 5)

                Text(deadlineSupplement)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var shortWeekday: String {
        FavorecoDateText.weekdayName(item.dueDate)
            .replacingOccurrences(of: "曜", with: "")
    }

    private func ticketMetadataBadge(
        _ title: String,
        backgroundColor: Color
    ) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(TheaterCategoryStyle.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 4)
            .frame(height: 20)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }

    private func ticketHorizontalStatusBadge(
        _ title: String,
        backgroundColor: Color
    ) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(TheaterCategoryStyle.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .accessibilityHidden(true)
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

struct HomeAttentionListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HomeAttentionItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                if let plan = item.plan {
                    NavigationLink {
                        HomePlanDestination(planID: plan.id)
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
                        description: Text("申込期限や入金、チケット受取、会員期限などをここで確認できます。")
                    )
                } else {
                    List(items) { item in
                        if let plan = item.plan {
                            NavigationLink {
                                HomePlanDestination(planID: plan.id)
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
        appendAttention(&result, if: attempt.issueStartAt > now, attempt: attempt, suffix: "issue-start", icon: "ticket.fill", label: "チケット受取開始", title: title, date: attempt.issueStartAt, plan: plan, tint: .teal, priority: 10)
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

    @Environment(\.favorecoThemePalette) private var themePalette

    private var categoryColor: Color {
        themePalette.categoryColor(hex: visit.categoryColorHex)
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
                GeometryReader { geometry in
                    ThumbnailImage(
                        reference: visit.thumbnailReference,
                        displaySize: geometry.size,
                        contentMode: visit.fillsEyecatchFrame ? .fill : .fit
                    ) {
                        ZStack {
                            Rectangle().fill(categoryColor.opacity(0.18))
                            Image(systemName: visit.eyecatchPath.isEmpty ? "sparkles" : "photo.fill")
                                .font(.largeTitle)
                                .foregroundStyle(categoryColor)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
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
    }
}

private struct HomeVisitSummaryRow: View {
    let visit: HomeVisitSnapshot

    @Environment(\.favorecoThemePalette) private var themePalette

    private var categoryColor: Color {
        themePalette.categoryColor(hex: visit.categoryColorHex)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
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
    }

    @ViewBuilder
    private var thumbnail: some View {
        ThumbnailImage(
            reference: visit.thumbnailReference,
            displaySize: CGSize(width: 64, height: thumbnailHeight),
            contentMode: visit.fillsEyecatchFrame ? .fill : .fit
        ) {
            Image(systemName: visit.categoryIcon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(categoryColor.opacity(0.12))
        }
        .frame(width: 64, height: thumbnailHeight)
        .clipped()
        .background(categoryColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var thumbnailHeight: CGFloat {
        let rawHeight = 64 / max(0.45, visit.eyecatchAspectRatio)
        return min(96, max(56, rawHeight))
    }

}

struct HomePlanDestination: View {
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

private struct HomeCategoryDestination: View {
    @Query private var categories: [RecordCategory]

    init(categoryID: UUID) {
        _categories = Query(filter: #Predicate<RecordCategory> { $0.id == categoryID })
    }

    var body: some View {
        if let category = categories.first {
            CategoryTopView(category: category)
        } else {
            ContentUnavailableView("ジャンルが見つかりません", systemImage: "trash")
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
            ThumbnailImage(
                reference: item.thumbnailReference,
                displaySize: CGSize(width: 64, height: 78),
                contentMode: .fill
            ) {
                Color(.secondarySystemFill)
            }
            .frame(width: 64, height: 78)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

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

struct EmptyStateRow: View {
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
