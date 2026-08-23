//
//  HomeView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import SwiftUI
import SwiftData
import UIKit

enum HomeCategoryContextTransition: Equatable {
    case activate(UUID)
    case resetToHome
    case none

    static func resolve(previous: UUID?, current: UUID?) -> Self {
        if let current {
            return .activate(current)
        }
        if previous != nil {
            return .resetToHome
        }
        return .none
    }
}

struct HomeView: View {
    let onCategoryReturnToRoot: () -> Void
    let onCategoryNavigate: (UUID) -> Void
    let onCreatePlan: () -> Void

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
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var categoryLayoutModeRaw = HomeCategoryLayoutMode.horizontal.rawValue
    @State private var isShowingNextActionList = false
    @State private var selectedQuickTicketAttempt: TicketAttempt?
    @State private var admissionPreparationPlan: Plan?
    @State private var isShowingSampleDeletionConfirmation = false
    @State private var sampleDeletionError = ""
    @State private var categoryDestinationID: UUID?
    @State private var pickupDetailTarget: HomePickupDetailTarget?
    @State private var isShowingCrossGenreSearch = false

    init(
        onCategoryReturnToRoot: @escaping () -> Void = {},
        onCategoryNavigate: @escaping (UUID) -> Void = { _ in },
        onCreatePlan: @escaping () -> Void = {}
    ) {
        self.onCategoryReturnToRoot = onCategoryReturnToRoot
        self.onCategoryNavigate = onCategoryNavigate
        self.onCreatePlan = onCreatePlan
    }

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

                if !visibleCategories.isEmpty {
                    GenreNavigationStrip(
                        categories: visibleCategories,
                        onSelectCategory: navigateToCategory
                    )
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
                            selectedQuickTicketAttempt = nil
                            categoryDestinationID = destination?.id
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 24) {
                            if showsAttention, !homeNextActionItems.isEmpty {
                                HomeAttentionSection(
                                    items: homeNextActionItems,
                                    onShowAll: { isShowingNextActionList = true },
                                    onSelectTicket: { attempt in
                                        guard categoryDestinationID == nil else { return }
                                        selectedQuickTicketAttempt = attempt
                                    }
                                )
                            }

                            HomeHeroSection(
                                interestedEvents: snapshot.interestedEvents,
                                unresolvedInboxItems: snapshot.unresolvedInboxItems,
                                upcomingItems: snapshot.upcomingItems,
                                recordedVisits: snapshot.pickupRecordedVisits,
                                onSelectInterest: { pickupDetailTarget = $0 },
                                onSelectPlan: { pickupDetailTarget = .plan($0) },
                                onSelectVisit: { pickupDetailTarget = .visit($0) },
                                onCreatePlan: onCreatePlan
                            )

                            Button {
                                isShowingCrossGenreSearch = true
                            } label: {
                                CrossGenreSearchEntryBar()
                            }
                            .buttonStyle(.plain)

                            if hasSampleData {
                                HomeSampleDataNotice {
                                    isShowingSampleDeletionConfirmation = true
                                }
                            }

                            HomeReportSection(visits: snapshot.reportVisits)

                            HomeGallerySection(visits: snapshot.galleryVisits)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .foregroundStyle(
                themePalette.bodyText(for: colorScheme),
                themePalette.secondaryText(for: colorScheme),
                themePalette.tertiaryText(for: colorScheme)
            )
            .background(homeBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: categoryDestinationID) { previous, current in
                switch HomeCategoryContextTransition.resolve(
                    previous: previous,
                    current: current
                ) {
                case .activate(let categoryID):
                    selectedQuickTicketAttempt = nil
                    onCategoryNavigate(categoryID)
                case .resetToHome:
                    onCategoryReturnToRoot()
                case .none:
                    break
                }
            }
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
            .navigationDestination(item: $categoryDestinationID) { categoryID in
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
            .navigationDestination(isPresented: $isShowingCrossGenreSearch) {
                CrossGenreSearchView()
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
                GenreNavigationStrip(
                    categories: categories,
                    onSelectCategory: navigateToCategory
                )
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
            Button {
                navigateToCategory(category)
            } label: {
                HomeCategoryShortcut(category: category)
            }
            .buttonStyle(.plain)
        }
    }

    private func navigateToCategory(_ category: RecordCategory) {
        categoryDestinationID = category.id
    }

    private var homeBackground: some View {
        ZStack {
            themePalette.canvas(for: colorScheme)

            RadialGradient(
                colors: [
                    themePalette.softTint.opacity(colorScheme == .dark ? 0.09 : 0.58),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 460
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    themePalette.softTint.opacity(colorScheme == .dark ? 0.035 : 0.20),
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
                .foregroundStyle(themePalette.headingText(for: colorScheme))
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
            CategoryEyecatchArtwork(
                reference: event.thumbnailReference,
                templateKey: event.categoryTemplateKey,
                defaultContentMode: event.fillsEyecatchFrame ? .fill : .fit
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: event.categoryTemplateKey,
                    displaySize: size
                )
            }
            .frame(width: 64, height: interestedEyecatchHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let categoryName = event.categoryName {
                        FavorecoIconLabel(categoryName, systemImage: event.categoryIcon ?? "square.grid.2x2", iconSize: 13)
                    }
                    if event.hasOfficialURL {
                        FavorecoIconLabel("URL", systemImage: "link", iconSize: 13)
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
        if event.categoryTemplateKey == "theater" {
            return 64 / CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
        }
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

    var categoryTemplateKey: String {
        switch self {
        case .event(let event): event.categoryTemplateKey
        case .inbox(let item): item.categoryTemplateKey
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
        case .compact: 6
        case .banner: 5
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
        CategoryEyecatchArtwork(
            reference: item.thumbnailReference,
            templateKey: item.categoryTemplateKey
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: item.categoryTemplateKey,
                displaySize: size
            )
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
                    categoryTemplateKey: plan.categoryTemplateKey,
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
                    categoryTemplateKey: visit.categoryTemplateKey,
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
    let categoryTemplateKey: String
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
            isTheater: categoryTemplateKey == "theater"
        ) {
            CategoryEyecatchArtwork(
                reference: thumbnailReference,
                templateKey: categoryTemplateKey
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: categoryTemplateKey,
                    displaySize: size
                )
            }
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
        HomeUpcomingHeroLayout(isEmbedded: isEmbedded) {
            HomeUpcomingPoster(
                thumbnailReference: plan.thumbnailReference,
                categoryTemplateKey: plan.categoryTemplateKey,
                fallbackIcon: plan.categoryIcon,
                tint: tint,
                fillsFrame: isEmbedded ? false : plan.fillsPosterFrame
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
                isEmbedded: isEmbedded,
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
                    .frame(maxWidth: .infinity)

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
        .background {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isEmbedded ? 0 : 0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                TheaterLifecycleEditorSheet(planned: currentPlan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
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
        HomeUpcomingHeroLayout(isEmbedded: isEmbedded) {
            HomeUpcomingPoster(
                thumbnailReference: visit.thumbnailReference,
                categoryTemplateKey: visit.categoryTemplateKey,
                fallbackIcon: visit.categoryIcon,
                tint: tint,
                fillsFrame: isEmbedded ? false : visit.fillsEyecatchFrame
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
                isEmbedded: isEmbedded,
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
                    .frame(maxWidth: .infinity)

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
                TheaterLifecycleEditorSheet(recorded: currentVisit)
            } else {
                FavorecoContentUnavailableView("記録が見つかりません", systemImage: "trash")
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
    static let actionHeight: CGFloat = 30
    static let embeddedPadding: CGFloat = 2
    static let embeddedTrailingInset: CGFloat = 4
    static let embeddedBottomRowOffset: CGFloat = 6
    static let embeddedContentHeight: CGFloat = 210
    static let embeddedPosterHeight: CGFloat = 174
    static let embeddedCardHeight: CGFloat = embeddedContentHeight + (embeddedPadding * 2)
    static let embeddedPageMaskWidth: CGFloat = embeddedPadding + posterWidth + spacing
    static let embeddedPageMaskHeight: CGFloat = embeddedPadding + embeddedBottomRowOffset + actionHeight
}

struct HomeUpcomingHeroLayout: Layout {
    let isEmbedded: Bool

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    private var posterHeight: CGFloat {
        isEmbedded
            ? HomeUpcomingHeroMetrics.embeddedPosterHeight
            : HomeUpcomingHeroMetrics.posterHeight
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 340
        let trailingInset = isEmbedded
            ? HomeUpcomingHeroMetrics.embeddedTrailingInset
            : 0
        let detailsWidth = max(
            0,
            width
                - HomeUpcomingHeroMetrics.posterWidth
                - HomeUpcomingHeroMetrics.spacing
                - trailingInset
        )
        let detailsSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailsWidth, height: proposal.height)
        )
        return CGSize(
            width: width,
            height: max(posterHeight, detailsSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let trailingInset = isEmbedded
            ? HomeUpcomingHeroMetrics.embeddedTrailingInset
            : 0
        let detailsWidth = max(
            0,
            bounds.width
                - HomeUpcomingHeroMetrics.posterWidth
                - HomeUpcomingHeroMetrics.spacing
                - trailingInset
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: HomeUpcomingHeroMetrics.posterWidth,
                height: posterHeight
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

struct HomeUpcomingPoster: View {
    let thumbnailReference: ThumbnailReference?
    let categoryTemplateKey: String
    let fallbackIcon: String
    let tint: Color
    let fillsFrame: Bool

    var body: some View {
        CategoryEyecatchArtwork(
            reference: thumbnailReference,
            templateKey: categoryTemplateKey,
            backgroundColor: tint.opacity(0.08),
            defaultContentMode: fillsFrame ? .fill : .fit
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: categoryTemplateKey,
                displaySize: size
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
    let isEmbedded: Bool
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
        isEmbedded: Bool = false,
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
        self.isEmbedded = isEmbedded
        self.onOpen = onOpen
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isEmbedded ? 2 : 4) {
            VStack(alignment: .leading, spacing: isEmbedded ? 2 : 4) {
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

                FavorecoIconLabel(dateText, systemImage: "calendar", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                FavorecoIconLabel(venueText, systemImage: "mappin.and.ellipse", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HomePickupURLRow(urlString: officialURLString, tint: tint)

            actions
                .padding(.top, isEmbedded ? HomeUpcomingHeroMetrics.embeddedBottomRowOffset : 0)
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
            FavorecoIcon(systemName: systemImage, size: 13)
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
        FavorecoIconLabel(title, systemImage: "safari", iconSize: 13)
            .font(FavorecoTypography.caption)
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .contentShape(Rectangle())
    }
}

struct HomeUpcomingEmptyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        VStack(spacing: 14) {
            FavorecoIcon(systemName: "calendar.badge.plus", size: 28)
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

            FavorecoIconLabel("予定を立てる", systemImage: "plus", iconSize: 17)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(themePalette.prominentActionForeground(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(themePalette.prominentAction, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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

private struct HomeTicketCardShape: Shape {
    static let separatorX: CGFloat = 150.5

    func path(in rect: CGRect) -> Path {
        let corner: CGFloat = 9
        let notchHalfWidth: CGFloat = 7
        let notchDepth: CGFloat = 7
        let separator = min(
            max(rect.minX + corner + notchHalfWidth, rect.minX + Self.separatorX),
            rect.maxX - corner - notchHalfWidth
        )

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: separator - notchHalfWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: separator, y: rect.minY + notchDepth))
        path.addLine(to: CGPoint(x: separator + notchHalfWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: separator + notchHalfWidth, y: rect.maxY))
        path.addLine(to: CGPoint(x: separator, y: rect.maxY - notchDepth))
        path.addLine(to: CGPoint(x: separator - notchHalfWidth, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }
}

private struct HomeTicketPerforation: View {
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0.5, y: 0))
            path.addLine(to: CGPoint(x: 0.5, y: 86))
        }
        .stroke(
            color,
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
        )
        .frame(width: 1, height: 86)
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
        return TicketProgressPresentation.deadlineLabel(
            forActionTitle: item.title,
            attempt: attempt
        )
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

    private var categoryTemplateKey: String {
        (plan?.category ?? plan?.event?.category)?.templateKey ?? ""
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

    private func remainingDaysTypography(for days: Int) -> (
        leadSize: CGFloat,
        numberSize: CGFloat,
        unitSize: CGFloat
    ) {
        switch String(days).count {
        case 1:
            return (leadSize: 11, numberSize: 40, unitSize: 11)
        case 2:
            return (leadSize: 11, numberSize: 40, unitSize: 11)
        case 3:
            return (leadSize: 9, numberSize: 26, unitSize: 9)
        default:
            return (leadSize: 8, numberSize: 21, unitSize: 8)
        }
    }

    private var urgencyColor: Color {
        switch urgency {
        case .undated, .normal:
            return cardPrimaryTextColor
        case .tomorrow:
            return Color(hex: "#D8555F")
        case .today:
            return Color(hex: "#E43D4C")
        case .overdue:
            return Color(hex: "#A91F32")
        }
    }

    private var statusColor: Color {
        guard let visualStage else { return item.tint }
        return TicketProgressColorPalette.color(for: visualStage)
    }

    private var visualStage: TicketProgressVisualStage? {
        TicketProgressColorPalette.visualStage(forDeadlineLabel: deadlineLabel)
    }

    private var cardSurfaceColor: Color {
        guard let visualStage else { return Color(.systemBackground) }
        return TicketProgressColorPalette.surface(for: visualStage)
    }

    private var cardTextColor: Color {
        guard let visualStage else { return Color.primary }
        return TicketProgressColorPalette.text(for: visualStage)
    }

    private var cardPrimaryTextColor: Color {
        Color.adaptive(lightHex: "#172936", darkHex: "#FFFDF8")
    }

    private var cardSecondaryTextColor: Color {
        Color.adaptive(lightHex: "#304957", darkHex: "#DCE7ED")
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

    private var undatedSupplementColor: Color {
        guard !isAttendanceScheduleAction else { return cardSecondaryTextColor }
        return TicketProgressColorPalette.warning
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                ticketHorizontalStatusBadge(
                    deadlineLabel,
                    backgroundColor: statusColor
                )

                CategoryEyecatchArtwork(
                    reference: thumbnailReference,
                    templateKey: categoryTemplateKey,
                    backgroundColor: cardSurfaceColor
                ) { size in
                    CategoryDefaultArtworkImage(
                        templateKey: categoryTemplateKey,
                        displaySize: size
                    )
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(width: 64)

            deadlineBlock
                .frame(width: 70, alignment: .center)

            HomeTicketPerforation(color: cardSecondaryTextColor.opacity(0.32))
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let entryRouteBadgeTitle {
                        ticketMetadataBadge(entryRouteBadgeTitle, role: .entryRoute)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)
                    }
                    if let ticketSiteBadgeTitle {
                        ticketMetadataBadge(ticketSiteBadgeTitle, role: .ticketSite)
                        .layoutPriority(1)
                    }
                    if entryRouteBadgeTitle == nil, ticketSiteBadgeTitle == nil {
                        ticketMetadataBadge("チケット", role: .entryRoute)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eventTitle)
                        .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(cardPrimaryTextColor)
                        .lineLimit(2)
                        .offset(y: 1)

                    FavorecoIconLabel(
                        scheduleText,
                        systemImage: "calendar",
                        iconSize: 15
                    )
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(
                            plan?.hasConfirmedSchedule == true
                                ? cardSecondaryTextColor
                                : TicketProgressColorPalette.warning
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cardSecondaryTextColor)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background {
            ZStack {
                HomeTicketCardShape()
                    .fill(cardSurfaceColor)
                    .shadow(
                        color: displayedCardShadowColor,
                        radius: displayedCardShadowRadius,
                        y: 2
                    )
                if urgency == .overdue {
                    HomeTicketCardShape()
                        .fill(TicketProgressColorPalette.warning.opacity(colorScheme == .dark ? 0.20 : 0.10))
                }
            }
        }
        .overlay {
            HomeTicketCardShape()
                .stroke(
                    urgency == .normal || urgency == .undated
                        ? statusColor.opacity(0.42)
                        : urgencyColor,
                    lineWidth: cardBorderWidth
                )
        }
        .offset(x: todayShakeOffset)
        .contentShape(HomeTicketCardShape())
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
                    let typography = remainingDaysTypography(for: remainingDays)

                    HStack(alignment: .center, spacing: 1) {
                        VStack(spacing: -4) {
                            Text("あ")
                            Text("と")
                        }
                        .font(FavorecoTypography.jpSerif(
                            typography.leadSize,
                            weight: .semibold,
                            relativeTo: .caption
                        ))
                        .frame(height: 42, alignment: .center)
                        .fixedSize(horizontal: true, vertical: false)

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(remainingDays)")
                                .font(FavorecoTypography.latinDisplay(
                                    typography.numberSize,
                                    weight: .bold,
                                    relativeTo: .title
                                ))
                                .monospacedDigit()
                                .offset(y: -5)
                                .fixedSize(horizontal: true, vertical: false)
                            Text("日")
                                .font(FavorecoTypography.jpSerif(
                                    typography.unitSize,
                                    weight: .semibold,
                                    relativeTo: .caption
                                ))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(height: 42, alignment: .center)
                    }
                    .foregroundStyle(urgencyColor)
                    .lineLimit(1)
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
                        .font(FavorecoTypography.latinDisplay(17, weight: .bold, relativeTo: .body))
                        .monospacedDigit()
                    Text("(\(shortWeekday))")
                        .font(FavorecoTypography.jpSerif(9, weight: .semibold, relativeTo: .caption2))
                }
                .foregroundStyle(cardSecondaryTextColor)
                .lineLimit(1)

                Text(FavorecoDateText.time(item.dueDate))
                    .font(FavorecoTypography.latinDisplay(15, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(cardSecondaryTextColor)
                    .monospacedDigit()
                    .lineLimit(1)
            } else {
                Text(isAttendanceScheduleAction ? "未定" : "要確認")
                    .font(FavorecoTypography.jpSerif(
                        isAttendanceScheduleAction ? 20 : 15,
                        weight: .semibold,
                        relativeTo: .title3
                    ))
                    .foregroundStyle(cardPrimaryTextColor)
                    .padding(.vertical, 5)

                Text(deadlineSupplement)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(undatedSupplementColor)
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

    private func ticketMetadataBadge(_ title: String, role: HomeTicketMetadataRole) -> some View {
        let foreground = role == .entryRoute
            ? TicketProgressColorPalette.entryRouteChipText
            : TicketProgressColorPalette.metadataChipText
        let border = role == .entryRoute
            ? TicketProgressColorPalette.entryRouteChipBorder
            : TicketProgressColorPalette.metadataChipBorder

        return Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 4)
            .frame(height: 20)
            .background(
                TicketProgressColorPalette.metadataChipSurface.opacity(colorScheme == .dark ? 0.92 : 0.84),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(border.opacity(role == .entryRoute ? 0.78 : 0.24), lineWidth: 0.7)
            }
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

private enum HomeTicketMetadataRole {
    case entryRoute
    case ticketSite
}

private struct HomeMiniStatCell: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FavorecoIcon(systemName: icon, size: 12)
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

private struct AttentionPlanRoute: Identifiable, Hashable {
    let planID: UUID
    let highlightedTicketAttemptID: UUID?
    let showsRecordedPlanDetail: Bool

    var id: String {
        [
            planID.uuidString,
            highlightedTicketAttemptID?.uuidString ?? "none",
            showsRecordedPlanDetail ? "recorded" : "planned",
        ].joined(separator: "-")
    }
}

private struct AttentionRow: View {
    let item: HomeAttentionItem
    var showsDisclosureIndicator = false

    var body: some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: item.icon, size: 20)
                .foregroundStyle(item.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(FavorecoTypography.jpSans(11, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

struct HomeAttentionListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HomeAttentionItem]
    @State private var selectedRoute: AttentionPlanRoute?

    var body: some View {
        NavigationStack {
            List(items) { item in
                if let plan = item.plan {
                    Button {
                        selectedRoute = AttentionPlanRoute(
                            planID: plan.id,
                            highlightedTicketAttemptID: item.attempt?.id,
                            showsRecordedPlanDetail: item.attempt != nil
                        )
                    } label: {
                        AttentionRow(item: item, showsDisclosureIndicator: true)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    AttentionRow(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("次にやること")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedRoute) { route in
                HomePlanDestination(
                    planID: route.planID,
                    highlightedTicketAttemptID: route.highlightedTicketAttemptID,
                    showsRecordedPlanDetail: route.showsRecordedPlanDetail
                )
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }
}

struct AppNotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @State private var selectedRoute: AttentionPlanRoute?

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
                    FavorecoContentUnavailableView(
                        "お知らせはありません",
                        systemImage: "bell",
                        description: "申込期限や支払、チケット受取、会員期限などをここで確認できます。"
                    )
                } else {
                    List(items) { item in
                        if let plan = item.plan {
                            Button {
                                selectedRoute = AttentionPlanRoute(
                                    planID: plan.id,
                                    highlightedTicketAttemptID: item.attempt?.id,
                                    showsRecordedPlanDetail: item.attempt != nil
                                )
                            } label: {
                                AttentionRow(item: item, showsDisclosureIndicator: true)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            AttentionRow(item: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedRoute) { route in
                HomePlanDestination(
                    planID: route.planID,
                    highlightedTicketAttemptID: route.highlightedTicketAttemptID,
                    showsRecordedPlanDetail: route.showsRecordedPlanDetail
                )
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    private func attentionItems(for attempt: TicketAttempt, now: Date) -> [HomeAttentionItem] {
        let plan = attempt.plan
        let title = plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定"
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        var result: [HomeAttentionItem] = []

        appendAttention(&result, if: attempt.saleStartAt > now, attempt: attempt, suffix: "sale-start", icon: "ticket", label: "申込開始", title: title, date: attempt.saleStartAt, plan: plan, tint: tint, priority: 12)
        appendAttention(&result, if: attempt.applyDeadlineAt > now, attempt: attempt, suffix: "apply-deadline", icon: "hourglass", label: "申込締切", title: title, date: attempt.applyDeadlineAt, plan: plan, tint: .red, priority: 1)
        appendAttention(&result, if: attempt.resultAnnounceAt > now, attempt: attempt, suffix: "result", icon: "checkmark.seal", label: "当落発表", title: title, date: attempt.resultAnnounceAt, plan: plan, tint: .purple, priority: 5)
        appendAttention(&result, if: attempt.paymentDeadlineAt > now, attempt: attempt, suffix: "payment", icon: "yensign.circle", label: "支払締切", title: title, date: attempt.paymentDeadlineAt, plan: plan, tint: .orange, priority: 2)
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
            attempt: attempt,
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
                CategoryEyecatchArtwork(
                    reference: visit.thumbnailReference,
                    templateKey: visit.categoryTemplateKey,
                    backgroundColor: categoryColor.opacity(0.08),
                    defaultContentMode: visit.fillsEyecatchFrame ? .fill : .fit
                ) { size in
                    CategoryDefaultArtworkImage(
                        templateKey: visit.categoryTemplateKey,
                        displaySize: size
                    )
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

                FavorecoIconLabel(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if !visit.venueName.isEmpty {
                    FavorecoIconLabel(visit.venueName, systemImage: "mappin.and.ellipse", iconSize: 13)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !visit.peopleSummary.isEmpty {
                    FavorecoIconLabel(visit.peopleSummary, systemImage: "person.2", iconSize: 13)
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
                    FavorecoIconLabel(
                        FavorecoDateText.compactDate(visit.visitedAt),
                        systemImage: unitFields.weatherSymbolName.isEmpty ? "calendar" : unitFields.weatherSymbolName,
                        iconSize: 13
                    )
                    FavorecoIconLabel(visit.categoryName, systemImage: visit.categoryIcon, iconSize: 13)
                    if !visit.venueName.isEmpty {
                        FavorecoIconLabel(visit.venueName, systemImage: "mappin.and.ellipse", iconSize: 13)
                    }
                    if visit.overallRating > 0 {
                        Label(String(format: "%.1f", visit.overallRating), systemImage: "star.fill")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !visit.peopleSummary.isEmpty {
                    FavorecoIconLabel(visit.peopleSummary, systemImage: "person.2", iconSize: 13)
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
        CategoryEyecatchArtwork(
            reference: visit.thumbnailReference,
            templateKey: visit.categoryTemplateKey,
            backgroundColor: categoryColor.opacity(0.08),
            defaultContentMode: visit.fillsEyecatchFrame ? .fill : .fit
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: visit.categoryTemplateKey,
                displaySize: size
            )
        }
        .frame(width: 64, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var thumbnailHeight: CGFloat {
        let rawHeight = 64 / max(0.45, visit.eyecatchAspectRatio)
        return min(96, max(56, rawHeight))
    }

}

struct HomePlanDestination: View {
    @Query private var plans: [Plan]
    let highlightedTicketAttemptID: UUID?
    let showsRecordedPlanDetail: Bool

    init(
        planID: UUID,
        highlightedTicketAttemptID: UUID? = nil,
        showsRecordedPlanDetail: Bool = false
    ) {
        self.highlightedTicketAttemptID = highlightedTicketAttemptID
        self.showsRecordedPlanDetail = showsRecordedPlanDetail
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(
                plan: plan,
                highlightedTicketAttemptID: highlightedTicketAttemptID,
                showsRecordedPlanDetail: showsRecordedPlanDetail
            )
        } else {
            FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
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
            FavorecoContentUnavailableView("ジャンルが見つかりません", systemImage: "trash")
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
            FavorecoContentUnavailableView("記録が見つかりません", systemImage: "trash")
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
            FavorecoContentUnavailableView("対象が見つかりません", systemImage: "trash")
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
            FavorecoContentUnavailableView("受信項目が見つかりません", systemImage: "trash")
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
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
            CategoryEyecatchArtwork(
                reference: item.thumbnailReference,
                templateKey: item.categoryTemplateKey
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: item.categoryTemplateKey,
                    displaySize: size
                )
            }
            .frame(width: 64, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let categoryName = item.categoryName {
                        FavorecoIconLabel(categoryName, systemImage: "square.grid.2x2", iconSize: 13)
                    }
                    if item.hasSourceURL {
                        FavorecoIconLabel("URL", systemImage: "link", iconSize: 13)
                    }
                    FavorecoIconLabel(FavorecoDateText.compactDate(item.createdAt), systemImage: "calendar", iconSize: 13)
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
            FavorecoIcon(
                systemName: PhosphorIconGlyph.categorySystemName(
                    templateKey: category.templateKey,
                    storedSystemName: category.iconSymbol
                ),
                size: 21
            )
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
        FavorecoIconLabel(text, systemImage: icon, iconSize: 11)
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
    case "paid": return "支払済み"
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
            FavorecoIcon(systemName: icon, size: 20)
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
            FavorecoIcon(systemName: "sparkles.rectangle.stack.fill", size: 20)
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
