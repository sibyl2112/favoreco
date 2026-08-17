//
//  MainTabView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit
import Charts
import Combine

@MainActor
final class CreateEntryContextRouter: ObservableObject {
    struct Context: Equatable {
        let categoryID: UUID

        fileprivate let baseCategoryID: UUID?
        fileprivate let detailContexts: [DetailContext]

        fileprivate init(
            categoryID: UUID,
            baseCategoryID: UUID? = nil,
            detailContexts: [DetailContext] = []
        ) {
            self.categoryID = categoryID
            self.baseCategoryID = baseCategoryID ?? (detailContexts.isEmpty ? categoryID : nil)
            self.detailContexts = detailContexts
        }
    }

    fileprivate struct DetailContext: Equatable {
        let token: UUID
        let categoryID: UUID
    }

    @Published private(set) var activeContext: Context?

    func activate(categoryID: UUID) {
        guard let context = activeContext, !context.detailContexts.isEmpty else {
            activeContext = Context(categoryID: categoryID)
            return
        }
        activeContext = Context(
            categoryID: context.categoryID,
            baseCategoryID: categoryID,
            detailContexts: context.detailContexts
        )
    }

    func resetToHome() {
        guard let context = activeContext, !context.detailContexts.isEmpty else {
            activeContext = nil
            return
        }
        activeContext = Context(
            categoryID: context.categoryID,
            detailContexts: context.detailContexts
        )
    }

    func activateDetail(categoryID: UUID, token: UUID) {
        let context = activeContext
        var detailContexts = context?.detailContexts ?? []
        detailContexts.removeAll { $0.token == token }
        detailContexts.append(DetailContext(token: token, categoryID: categoryID))
        let baseCategoryID = if let context, context.detailContexts.isEmpty {
            context.categoryID
        } else {
            context?.baseCategoryID
        }
        activeContext = Context(
            categoryID: categoryID,
            baseCategoryID: baseCategoryID,
            detailContexts: detailContexts
        )
    }

    func deactivateDetail(token: UUID) {
        guard let context = activeContext else { return }
        let detailContexts = context.detailContexts.filter { $0.token != token }
        if let frontmost = detailContexts.last {
            activeContext = Context(
                categoryID: frontmost.categoryID,
                baseCategoryID: context.baseCategoryID,
                detailContexts: detailContexts
            )
        } else if let baseCategoryID = context.baseCategoryID {
            activeContext = Context(categoryID: baseCategoryID)
        } else {
            activeContext = nil
        }
    }

    func categoryIDForCreateMenu(isHomeTabActive: Bool) -> UUID? {
        guard isHomeTabActive else { return nil }
        return activeContext?.categoryID
    }

    func createMenuRequest(isHomeTabActive: Bool) -> CreateEntryMenuRequest {
        CreateEntryMenuRequest(
            categoryID: categoryIDForCreateMenu(isHomeTabActive: isHomeTabActive)
        )
    }
}

struct CreateEntryMenuRequest: Identifiable, Equatable {
    let id = UUID()
    let categoryID: UUID?
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @AppStorage(AppStorageKeys.defaultGenreMode) private var defaultGenreMode = "lastUsed"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.opensPreviousMonthlyReport) private var opensPreviousMonthlyReport = false
    @AppStorage(AppStorageKeys.opensPreviousYearlyReport) private var opensPreviousYearlyReport = false
    @AppStorage(AppStorageKeys.pendingNotificationPlanID) private var pendingNotificationPlanID = ""
    @AppStorage(AppStorageKeys.pendingNotificationAttemptID) private var pendingNotificationAttemptID = ""
    @AppStorage(AppStorageKeys.pendingNotificationPreparationTaskID) private var pendingNotificationPreparationTaskID = ""
    @StateObject private var createEntryContextRouter = CreateEntryContextRouter()
    @State private var selectedTab: MainTab = .home
    @State private var presentedCreateContextCategoryID: UUID?
    @State private var presentedCreateContextTemplateKey: String?
    @State private var presentedCreateMenuRequest: CreateEntryMenuRequest?
    @State private var isShowingRecordTargetSelection = false
    @State private var isShowingTheaterMemorySelection = false
    @State private var isShowingAddPlan = false
    @State private var isShowingAddTicketSchedule = false
    @State private var isShowingUnifiedTheaterRegistration = false
    @State private var isShowingSimpleCategoryRegistration = false
    @State private var pendingSimpleRegistrationPurpose: SimpleCategoryRegistrationPurpose?
    @State private var isShowingTheaterPlanChoice = false
    @State private var isShowingQuickRegistration = false
    @State private var isShowingPublicPlaceCatalog = false
    @State private var theaterRegistrationCategory: RecordCategory?
    @State private var pendingCreateAction: CreateAction?
    @State private var pendingRecordDestination: RecordEntryDestination?
    @State private var recordDestination: RecordEntryDestination?
    @State private var calendarDisplayMode: CalendarDisplayMode = .month
    @State private var didScheduleStartupBackup = false

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var preferredCategory: RecordCategory? {
        let preferredKey = defaultGenreMode == "homeSelected"
            ? homeSelectedCategoryTemplateKey
            : lastUsedCategoryTemplateKey
        return visibleCategories.first(where: { $0.templateKey == preferredKey }) ?? visibleCategories.first
    }

    private var activeCreateContextCategory: RecordCategory? {
        guard let categoryID = createEntryContextRouter.categoryIDForCreateMenu(
            isHomeTabActive: selectedTab == .home
        ) else { return nil }
        return visibleCategories.first(where: { $0.id == categoryID })
    }

    private var presentedCreateContextCategory: RecordCategory? {
        guard let presentedCreateContextCategoryID else { return nil }
        return visibleCategories.first(where: { $0.id == presentedCreateContextCategoryID })
    }

    private var createMenuCategories: [RecordCategory] {
        let firstCategory = presentedCreateContextCategory ?? preferredCategory
        guard let firstCategory else { return visibleCategories }
        return [firstCategory] + visibleCategories.filter { $0.id != firstCategory.id }
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .create {
                    let request = createEntryContextRouter.createMenuRequest(
                        isHomeTabActive: selectedTab == .home
                    )
                    presentedCreateContextCategoryID = request.categoryID
                    presentCreateMenuAfterRetainingCurrentTab(
                        request,
                        sourceTab: selectedTab
                    )
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    private func presentCreateMenuAfterRetainingCurrentTab(
        _ request: CreateEntryMenuRequest,
        sourceTab: MainTab
    ) {
        Task { @MainActor in
            // The center item is an action, not a destination. Let TabView finish
            // rejecting the attempted selection before creating the sheet host.
            await Task.yield()
            guard selectedTab == sourceTab else { return }
            guard presentedCreateMenuRequest == nil else { return }
            presentedCreateMenuRequest = request
        }
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(
                onCategoryReturnToRoot: {
                    createEntryContextRouter.resetToHome()
                },
                onCategoryNavigate: { categoryID in
                    createEntryContextRouter.activate(categoryID: categoryID)
                }
            )
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label {
                        Text("Home")
                    } icon: {
                        FavorecoTabIcon(systemName: "house.fill")
                    }
                }
                .tag(MainTab.home)

            DeferredTabContent(isActive: selectedTab == .records) {
                FavoView()
            }
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label {
                        Text("FAVO")
                    } icon: {
                        FavorecoTabIcon(systemName: "heart.text.square.fill")
                    }
                }
                .tag(MainTab.records)

            Color.clear
                .tabItem {
                    Label {
                        Text("追加")
                    } icon: {
                        FavorecoTabIcon(systemName: "plus")
                    }
                }
                .tag(MainTab.create)

            DeferredTabContent(isActive: selectedTab == .calendar) {
                CalendarView(
                    displayMode: $calendarDisplayMode,
                    requestedPlanID: $pendingNotificationPlanID,
                    requestedAttemptID: $pendingNotificationAttemptID,
                    requestedPreparationTaskID: $pendingNotificationPreparationTaskID
                )
            }
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label {
                        Text("カレンダー")
                    } icon: {
                        FavorecoTabIcon(systemName: "calendar")
                    }
                }
                .tag(MainTab.calendar)

            DeferredTabContent(isActive: selectedTab == .stats) {
                StatsView(isActive: selectedTab == .stats)
            }
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label {
                        Text("統計")
                    } icon: {
                        FavorecoTabIcon(systemName: "chart.bar.fill")
                    }
                }
                .tag(MainTab.stats)
        }
        .environmentObject(createEntryContextRouter)
        .tint(selectedTab == .records ? themePalette.emotionTint : themePalette.globalTint)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(item: $presentedCreateMenuRequest, onDismiss: openPendingCreateAction) { request in
            let category = request.categoryID.flatMap { categoryID in
                visibleCategories.first(where: { $0.id == categoryID })
            }
            let definition = CreateEntryMenuDefinition.resolve(
                templateKey: category?.templateKey
            )
            CreateEntryMenuView(
                canCreateRecord: !visibleCategories.isEmpty,
                definition: definition,
                onSelect: { action in
                    presentedCreateContextCategoryID = request.categoryID
                    presentedCreateContextTemplateKey = category?.templateKey
                    pendingCreateAction = action
                    presentedCreateMenuRequest = nil
                }
            )
            .presentationDetents([
                .height(CreateEntryMenuView.preferredSheetHeight(
                    itemCount: definition.items.count
                ))
            ])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingRecordTargetSelection, onDismiss: openPendingRecordDestination) {
            RecordTargetSelectionView(
                categories: isScopedViewingRecordFlow
                    ? presentedCreateContextCategory.map { [$0] } ?? []
                    : createMenuCategories,
                preferredCategory: presentedCreateContextCategory ?? preferredCategory,
                screenTitle: viewingRecordScreenTitle,
                locksCategory: isScopedViewingRecordFlow
            ) { destination in
                pendingRecordDestination = destination
                isShowingRecordTargetSelection = false
            }
        }
        .sheet(isPresented: $isShowingTheaterMemorySelection, onDismiss: openPendingRecordDestination) {
            if let theaterCategory = presentedCreateContextCategory,
               theaterCategory.templateKey == "theater" {
                TheaterMemoryTargetSelectionView(category: theaterCategory) { destination in
                    pendingRecordDestination = destination
                    isShowingTheaterMemorySelection = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFavorecoStats)) { _ in
            selectedTab = .stats
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFavorecoPlanList)) { _ in
            calendarDisplayMode = .planList
            selectedTab = .calendar
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFavorecoPlanCreation)) { _ in
            openPlanCreation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFavorecoPlan)) { _ in
            selectedTab = .calendar
        }
        .task {
            if !pendingNotificationPlanID.isEmpty || !pendingNotificationAttemptID.isEmpty {
                selectedTab = .calendar
            } else if opensPreviousMonthlyReport || opensPreviousYearlyReport {
                selectedTab = .stats
            }
            await scheduleAutomaticBackupAfterInitialDisplay()
        }
        .onChange(of: pendingNotificationPlanID) { _, planID in
            if !planID.isEmpty {
                selectedTab = .calendar
            }
        }
        .onChange(of: pendingNotificationAttemptID) { _, attemptID in
            if !attemptID.isEmpty {
                selectedTab = .calendar
            }
        }
        .onChange(of: opensPreviousMonthlyReport) { _, shouldOpen in
            if shouldOpen {
                selectedTab = .stats
            }
        }
        .onChange(of: opensPreviousYearlyReport) { _, shouldOpen in
            if shouldOpen {
                selectedTab = .stats
            }
        }
        .sheet(item: $recordDestination) { destination in
            switch destination {
            case .new(let category):
                if category.templateKey == "random_goods" {
                    AddCollectibleSeriesView(category: category)
                } else {
                    AddExperienceView(category: category)
                }
            case .existing(let event):
                if event.category?.templateKey == "random_goods" {
                    CollectibleTransactionEditorView(series: event)
                } else {
                    AddVisitView(event: event)
                }
            case .plan(let plan):
                if let event = plan.event {
                    AddVisitView(
                        event: event,
                        initialDraft: VisitDraft(plan: plan),
                        sourcePlan: plan
                    )
                }
            case .edit(let visit):
                EditExperienceView(visit: visit)
            }
        }
        .sheet(isPresented: $isShowingAddPlan) {
            AddTicketPlanView(
                entryMode: .plan,
                initialCategoryID: presentedCreateContextCategory?.id
            )
        }
        .sheet(isPresented: $isShowingQuickRegistration) {
            QuickRegistrationView(
                initialTemplateKey: presentedCreateContextTemplateKey,
                screenTitle: quickRegistrationScreenTitle,
                locksCategory: presentedCreateContextTemplateKey != nil
            )
        }
        .sheet(isPresented: $isShowingPublicPlaceCatalog) {
            PublicPlaceCatalogView(scope: publicPlaceCatalogScope)
        }
        .sheet(isPresented: $isShowingAddTicketSchedule) {
            AddTicketPlanView(entryMode: .ticketSchedule)
        }
        .sheet(isPresented: $isShowingUnifiedTheaterRegistration) {
            AddTicketPlanView(entryMode: .unified)
        }
        .sheet(
            isPresented: $isShowingSimpleCategoryRegistration,
            onDismiss: openPendingSimpleRegistrationPurpose
        ) {
            if let category = presentedCreateContextCategory,
               ["movie", "museum"].contains(category.templateKey) {
                SimpleCategoryRegistrationView(category: category) { purpose in
                    pendingSimpleRegistrationPurpose = purpose
                    isShowingSimpleCategoryRegistration = false
                }
            }
        }
        .sheet(item: $theaterRegistrationCategory) { category in
            TheaterPerformanceRegistrationView(category: category)
        }
        .confirmationDialog(
            "予定の登録方法",
            isPresented: $isShowingTheaterPlanChoice,
            titleVisibility: .visible
        ) {
            Button("日程を決めて予定を登録") {
                isShowingAddPlan = true
            }
            Button("チケット取得から始める") {
                isShowingAddTicketSchedule = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("チケット取得から始める場合は、参加日が未定のまま抽選・発売スケジュールを登録できます。")
        }
    }

    private func openPendingCreateAction() {
        guard let action = pendingCreateAction else { return }
        pendingCreateAction = nil

        switch action {
        case .plan:
            isShowingAddPlan = true
        case .record:
            isShowingRecordTargetSelection = true
        case .theaterMemory:
            isShowingTheaterMemorySelection = true
        case .quick:
            isShowingQuickRegistration = true
        case .placeCatalog:
            isShowingPublicPlaceCatalog = true
        case .theaterRegistration:
            isShowingUnifiedTheaterRegistration = true
        case .performanceRegistration:
            theaterRegistrationCategory = presentedCreateContextCategory
        case .simpleCategoryRegistration:
            isShowingSimpleCategoryRegistration = true
        case .ticketSchedule:
            isShowingAddTicketSchedule = true
        }
    }

    private func openPlanCreation() {
        if activeCreateContextCategory?.templateKey == "theater" {
            isShowingTheaterPlanChoice = true
        } else {
            isShowingAddPlan = true
        }
    }

    private func openPendingRecordDestination() {
        guard let pendingRecordDestination else { return }
        self.pendingRecordDestination = nil
        recordDestination = pendingRecordDestination
    }

    private func openPendingSimpleRegistrationPurpose() {
        guard let purpose = pendingSimpleRegistrationPurpose,
              let category = presentedCreateContextCategory else { return }
        pendingSimpleRegistrationPurpose = nil

        switch purpose {
        case .interested:
            isShowingQuickRegistration = true
        case .plan:
            isShowingAddPlan = true
        case .visited:
            recordDestination = .new(category)
        }
    }

    private var quickRegistrationScreenTitle: String {
        switch presentedCreateContextTemplateKey {
        case "book": "本を登録する"
        case "movie": "観たい作品を登録"
        case "museum": "気になる展示を登録"
        case "theme_park": "気になる施設を登録"
        case "nature_living": "気になるスポットを登録"
        case "outing_facility": "気になる施設を登録"
        default: "クイック登録"
        }
    }

    private var publicPlaceCatalogScope: PublicPlaceCatalogScope {
        switch presentedCreateContextCategory?.templateKey {
        case "museum": .museum
        case "theme_park": .themePark
        case "nature_living": .natureLiving
        case "outing_facility": .facility
        default: .all
        }
    }

    private var isScopedViewingRecordFlow: Bool {
        ["movie", "museum"].contains(presentedCreateContextCategory?.templateKey ?? "")
    }

    private var viewingRecordScreenTitle: String {
        isScopedViewingRecordFlow ? "鑑賞の記録をつける" : "体験済みを記録"
    }

    private func scheduleAutomaticBackupAfterInitialDisplay() async {
        guard !didScheduleStartupBackup else { return }
        didScheduleStartupBackup = true
        let request = AutomaticBackupRequest.automatic(
            canUseSyncFeatures: EntitlementAccess.canUseSyncFeatures
        )
        guard AutomaticBackupPolicy.skipStatus(for: request) == nil else { return }
        await Task.yield()
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        _ = await AutomaticBackupCoordinator.shared.run(
            request: request,
            modelContainer: modelContext.container
        )
    }
}

/// 未訪問タブのQueryと集計Viewを起動時に生成しない。
/// 一度表示した後はViewを保持し、タブ往復時のナビゲーション状態を維持する。
private struct DeferredTabContent<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: () -> Content
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if isActive || hasLoaded {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if isActive { hasLoaded = true }
        }
        .onChange(of: isActive) { _, active in
            if active { hasLoaded = true }
        }
    }
}

struct MainScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let title: String
    var usesBrandFont = false
    var centeredTitle: String? = nil
    var usesCompactBrand = false
    var brandGradient: LinearGradient? = nil
    var headerForegroundColor: Color? = nil
    var onLeadingTap: (() -> Void)? = nil
    var onCenteredTitleTap: (() -> Void)? = nil
    var showsTicketManagement = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onLeadingTap {
                Button(action: onLeadingTap) {
                    leadingTitle
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Homeへ戻る")
            } else {
                leadingTitle
                    .accessibilityAddTraits(.isHeader)
            }

            if let centeredTitle {
                if let onCenteredTitleTap {
                    Button(action: onCenteredTitleTap) {
                        centeredTitleLabel(centeredTitle, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("現在のジャンルは\(centeredTitle)です。ジャンル一覧を開く")
                } else {
                    centeredTitleLabel(centeredTitle, showsChevron: false)
                        .accessibilityAddTraits(.isHeader)
                }
            } else {
                Spacer(minLength: 8)
            }

            MainToolbarActions(
                tint: headerForegroundColor,
                showsTicketManagement: showsTicketManagement
            )
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }

    private func centeredTitleLabel(_ title: String, showsChevron: Bool) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .tracking(title.count <= 3 ? 5 : 0)
            if showsChevron {
                FavorecoIcon(systemName: "chevron.down", size: 10)
            }
        }
        .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
        .foregroundStyle(headerForegroundColor ?? .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var leadingTitle: some View {
        Text(title)
            .font(
                usesBrandFont
                    ? FavorecoTypography.latinDisplay(
                        usesCompactBrand ? 27 : 34,
                        weight: usesCompactBrand ? .semibold : .bold,
                        relativeTo: usesCompactBrand ? .headline : .largeTitle
                    )
                    : FavorecoTypography.jpSans(30, weight: .bold, relativeTo: .title)
            )
            .foregroundStyle(leadingTitleStyle)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .layoutPriority(1)
    }

    private var leadingTitleStyle: AnyShapeStyle {
        if let brandGradient {
            return AnyShapeStyle(brandGradient)
        }
        if let headerForegroundColor {
            return AnyShapeStyle(headerForegroundColor)
        }
        return AnyShapeStyle(
            usesBrandFont
                ? themePalette.headingText(for: colorScheme).opacity(usesCompactBrand ? 0.78 : 1)
                : Color.primary
        )
    }
}

struct MainHeaderDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    var tint: Color? = nil

    var body: some View {
        Rectangle()
            .fill(
                (tint ?? themePalette.globalTint).opacity(
                    tint == nil
                        ? (colorScheme == .dark ? 0.26 : 0.18)
                        : (colorScheme == .dark ? 0.55 : 0.45)
                )
            )
            .frame(height: 1)
    }
}

struct MainToolbarActions: View {
    @AppStorage(AppStorageKeys.profileImageData) private var profileImageData = Data()
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @State private var isShowingNotifications = false
    @State private var isShowingSettings = false
    @State private var isShowingTicketManagement = false

    var tint: Color? = nil
    var showsTicketManagement = false

    var body: some View {
        HStack(spacing: 2) {
            if showsTicketManagement {
                Button {
                    isShowingTicketManagement = true
                } label: {
                    FavorecoIcon(systemName: "ticket", size: 23)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(tint ?? .primary)
                .accessibilityLabel("チケット管理")
            }

            Button {
                isShowingNotifications = true
            } label: {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ZStack(alignment: .topTrailing) {
                        FavorecoIcon(systemName: "bell", size: 23)

                        if hasReachedAction(at: context.date) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle().stroke(Color(.systemBackground), lineWidth: 1.5)
                                }
                                .offset(x: 2, y: -1)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint ?? .primary)
            .accessibilityLabel("お知らせ・次にやること")

            Button {
                isShowingSettings = true
            } label: {
                ProfileAvatarView(data: profileImageData, size: 38)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("マイ・設定")
        }
        .foregroundStyle(tint ?? .primary)
        .sheet(isPresented: $isShowingNotifications) {
            AppNotificationCenterView()
        }
        .sheet(isPresented: $isShowingTicketManagement) {
            NavigationStack {
                TicketOverviewView(showsCloseButton: true)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    private func hasReachedAction(at now: Date) -> Bool {
        let hasTicketAction = ticketAttempts.contains { attempt in
            guard !attempt.isArchived,
                  attempt.plan?.isArchived != true,
                  let action = TicketNextActionDefinition.nextAction(for: attempt, now: now) else {
                return false
            }
            return action.isOverdue
        }

        if hasTicketAction {
            return true
        }

        let warningLimit = Calendar.current.date(byAdding: .day, value: 45, to: now) ?? now
        return ticketAccounts.contains { account in
            !account.isArchived
                && account.renewalNotify
                && account.expiryDate != Date.distantPast
                && account.expiryDate >= now
                && account.expiryDate <= warningLimit
        }
    }
}

private enum RecordEntryDestination: Identifiable {
    case new(RecordCategory)
    case existing(ExperienceEvent)
    case plan(Plan)
    case edit(Visit)

    var id: String {
        switch self {
        case .new(let category): "new-\(category.id.uuidString)"
        case .existing(let event): "existing-\(event.id.uuidString)"
        case .plan(let plan): "plan-\(plan.id.uuidString)"
        case .edit(let visit): "edit-\(visit.id.uuidString)"
        }
    }
}

private struct TheaterMemoryTargetSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \Plan.startsAt, order: .reverse) private var allPlans: [Plan]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]

    @State private var showsAllUnrecordedPlans = false
    @State private var showsAllRecordedVisits = false

    let category: RecordCategory
    let onSelect: (RecordEntryDestination) -> Void

    private let initialVisibleCount = 3

    private var eligiblePlans: [Plan] {
        let endOfToday = Calendar.current.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: Date()
        ) ?? Date()
        return allPlans.filter {
            !$0.isArchived
                && $0.category?.id == category.id
                && $0.hasConfirmedSchedule
                && $0.startsAt <= endOfToday
        }
    }

    private var unrecordedPlans: [Plan] {
        eligiblePlans.filter { $0.visit == nil }
    }

    private var visibleUnrecordedPlans: [Plan] {
        Array(
            unrecordedPlans.prefix(
                showsAllUnrecordedPlans ? unrecordedPlans.count : initialVisibleCount
            )
        )
    }

    private var recordedVisits: [Visit] {
        allVisits.filter { visit in
            if visit.event?.category?.id == category.id {
                return true
            }
            return visit.plans?.contains(where: { plan in
                plan.category?.id == category.id || plan.event?.category?.id == category.id
            }) == true
        }
    }

    private var visibleRecordedVisits: [Visit] {
        Array(
            recordedVisits.prefix(
                showsAllRecordedVisits ? recordedVisits.count : initialVisibleCount
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(.new(category))
                    } label: {
                        FavorecoIconLabel(
                            "予定なしで過去の観劇を記録",
                            systemImage: "plus.circle"
                        )
                        .font(FavorecoTypography.bodyStrong)
                    }
                } footer: {
                    Text("事前に予定を登録していなかった公演も、ここから直接記録できます。")
                }

                Section("記録できる観劇予定") {
                    if unrecordedPlans.isEmpty {
                        FavorecoContentUnavailableView(
                            "記録待ちの観劇予定はありません",
                            systemImage: "calendar.badge.checkmark",
                            description: "参加日を登録した公演がここに表示されます。"
                        )
                    } else {
                        ForEach(visibleUnrecordedPlans) { plan in
                            Button {
                                onSelect(.plan(plan))
                            } label: {
                                theaterMemoryPlanRow(plan)
                            }
                            .buttonStyle(.plain)
                        }

                        if unrecordedPlans.count > initialVisibleCount {
                            listExpansionButton(
                                isExpanded: $showsAllUnrecordedPlans,
                                hiddenCount: unrecordedPlans.count - initialVisibleCount
                            )
                        }
                    }
                }

                if !recordedVisits.isEmpty {
                    Section("登録済みの観劇記録") {
                        ForEach(visibleRecordedVisits) { visit in
                            Button {
                                onSelect(.edit(visit))
                            } label: {
                                theaterMemoryVisitRow(visit)
                            }
                            .buttonStyle(.plain)
                        }

                        if recordedVisits.count > initialVisibleCount {
                            listExpansionButton(
                                isExpanded: $showsAllRecordedVisits,
                                hiddenCount: recordedVisits.count - initialVisibleCount
                            )
                        }
                    }
                }
            }
            .navigationTitle("観劇の思い出を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .favorecoAppAppearance()
        .tint(themePalette.globalTint)
    }

    private func theaterMemoryPlanRow(_ plan: Plan) -> some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: "calendar", size: 19)
                .foregroundStyle(themePalette.globalTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.event?.title.isEmpty == false ? plan.event?.title ?? plan.title : plan.title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(memoryPlanDescription(plan))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func theaterMemoryVisitRow(_ visit: Visit) -> some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: "checkmark.circle.fill", size: 19)
                .foregroundStyle(Color.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(memoryVisitTitle(visit))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(memoryVisitDescription(visit))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func listExpansionButton(
        isExpanded: Binding<Bool>,
        hiddenCount: Int
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(isExpanded.wrappedValue ? "表示を減らす" : "さらに見る")
                    .font(FavorecoTypography.bodyStrong)

                if !isExpanded.wrappedValue {
                    Text("残り\(hiddenCount)件")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(themePalette.globalTint)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isExpanded.wrappedValue
                ? "表示を3件に戻す"
                : "残り\(hiddenCount)件をさらに見る"
        )
    }

    private func memoryPlanDescription(_ plan: Plan) -> String {
        let date = FavorecoDateText.compactDateTime(plan.startsAt)
        let venue = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return venue.isEmpty ? date : "\(date)｜\(venue)"
    }

    private func memoryVisitTitle(_ visit: Visit) -> String {
        let eventTitle = visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty {
            return eventTitle
        }
        let planTitle = matchingPlan(for: visit)?.title
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return planTitle.isEmpty ? "公演名未設定" : planTitle
    }

    private func memoryVisitDescription(_ visit: Visit) -> String {
        let date = FavorecoDateText.compactDateTime(visit.visitedAt)
        let visitVenue = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = visitVenue.isEmpty
            ? matchingPlan(for: visit)?.venueNameSnapshot
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            : visitVenue
        return venue.isEmpty ? date : "\(date)｜\(venue)"
    }

    private func matchingPlan(for visit: Visit) -> Plan? {
        visit.plans?
            .filter {
                $0.category?.id == category.id || $0.event?.category?.id == category.id
            }
            .max { $0.startsAt < $1.startsAt }
    }
}

private struct RecordTargetSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]

    let categories: [RecordCategory]
    let preferredCategory: RecordCategory?
    let screenTitle: String
    let locksCategory: Bool
    let onSelect: (RecordEntryDestination) -> Void

    @State private var selectedCategoryID: UUID?
    @State private var searchText = ""

    private var selectedCategory: RecordCategory? {
        categories.first(where: { $0.id == selectedCategoryID }) ?? preferredCategory ?? categories.first
    }

    private var matchingEvents: [ExperienceEvent] {
        guard let selectedCategory else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allEvents
            .filter { event in
                guard !event.isArchived, event.category?.id == selectedCategory.id else { return false }
                return query.isEmpty
                    || event.title.localizedCaseInsensitiveContains(query)
                    || event.seriesName.localizedCaseInsensitiveContains(query)
            }
            .prefix(query.isEmpty ? 5 : 20)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if !locksCategory {
                    Section {
                        Menu {
                        ForEach(categories) { category in
                            Button {
                                selectedCategoryID = category.id
                                searchText = ""
                            } label: {
                                Label {
                                    Text(category.name)
                                } icon: {
                                    FavorecoIcon(
                                        systemName: PhosphorIconGlyph.categorySystemName(
                                            templateKey: category.templateKey,
                                            storedSystemName: category.iconSymbol
                                        ),
                                        size: 17
                                    )
                                }
                            }
                        }
                        } label: {
                        HStack(spacing: 12) {
                            FavorecoIcon(
                                systemName: selectedCategory.map {
                                    PhosphorIconGlyph.categorySystemName(
                                        templateKey: $0.templateKey,
                                        storedSystemName: $0.iconSymbol
                                    )
                                } ?? "square.grid.2x2",
                                size: 19
                            )
                                .frame(width: 28)
                            Text(selectedCategory?.name ?? "ジャンルを選択")
                                .font(FavorecoTypography.bodyStrong)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("ジャンル")
                    }
                }

                if !locksCategory {
                    Section {
                        Button {
                            guard let selectedCategory else { return }
                            onSelect(.new(selectedCategory))
                        } label: {
                            FavorecoIconLabel(newTargetTitle, systemImage: "plus.circle.fill")
                                .font(FavorecoTypography.bodyStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedCategory == nil)
                    }
                }

                Section {
                    TextField("タイトルを検索", text: $searchText)
                        .textInputAutocapitalization(.never)

                    if matchingEvents.isEmpty {
                        FavorecoContentUnavailableView(
                            searchText.isEmpty ? "登録済みの対象はありません" : "一致する対象はありません",
                            systemImage: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass",
                            description: searchText.isEmpty
                                ? emptyTargetDescription
                                : "タイトルやシリーズ名を変えて検索してください。"
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(matchingEvents) { event in
                                    Button {
                                        onSelect(.existing(event))
                                    } label: {
                                        HStack(spacing: 12) {
                                            FavorecoIcon(
                                                systemName: event.category.map {
                                                    PhosphorIconGlyph.categorySystemName(
                                                        templateKey: $0.templateKey,
                                                        storedSystemName: $0.iconSymbol
                                                    )
                                                } ?? "rectangle.stack",
                                                size: 20
                                            )
                                                .foregroundStyle(.secondary)
                                                .frame(width: 36, height: 36)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(event.title.isEmpty ? "名称未設定" : event.title)
                                                    .font(FavorecoTypography.bodyStrong)
                                                    .foregroundStyle(.primary)
                                                if !event.seriesName.isEmpty {
                                                    Text(event.seriesName)
                                                        .font(FavorecoTypography.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if event.id != matchingEvents.last?.id {
                                        Divider()
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                        }
                        .frame(height: min(CGFloat(matchingEvents.count) * 64, 320))
                        .scrollIndicators(.visible)
                    }
                } header: {
                    FavorecoRegistrationSectionHeader(
                        searchText.isEmpty ? "最近の作品・対象" : "検索結果"
                    )
                } footer: {
                    Text("登録済みの対象を選ぶと、タイトルや公式情報を重複登録せず、今回の記録だけを追加できます。")
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                selectedCategoryID = selectedCategoryID ?? preferredCategory?.id ?? categories.first?.id
            }
        }
    }

    private var newTargetTitle: String {
        switch selectedCategory?.templateKey {
        case "movie": "新しい作品を登録して記録"
        case "museum": "新しい展示を登録して記録"
        default: "新しい作品・対象を登録"
        }
    }

    private var emptyTargetDescription: String {
        guard locksCategory else { return "上のボタンから新しい対象を登録できます。" }
        switch selectedCategory?.templateKey {
        case "movie": return "先に「作品を登録する」から作品と鑑賞記録を登録してください。"
        case "museum": return "先に「展示・イベントを登録」から展示と鑑賞記録を登録してください。"
        default: return "先に対象を登録してください。"
        }
    }
}

private enum CreateAction: String, Identifiable {
    case plan
    case record
    case theaterMemory
    case quick
    case placeCatalog
    case theaterRegistration
    case performanceRegistration
    case simpleCategoryRegistration
    case ticketSchedule

    var id: String { rawValue }
}

private struct CreateEntryMenuItem: Identifiable {
    let action: CreateAction
    let title: String
    let detail: String
    let systemImage: String
    var requiresExistingRecord = false
    var isSecondary = false

    var id: CreateAction { action }
}

private struct CreateEntryMenuDefinition {
    let templateKey: String?
    let items: [CreateEntryMenuItem]

    static func resolve(templateKey: String?) -> CreateEntryMenuDefinition {
        switch templateKey {
        case "theater":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .theaterRegistration,
                        title: "公演・チケットを登録",
                        detail: "気になる・予定・申込・取得済みを追加",
                        systemImage: "ticket"
                    ),
                    CreateEntryMenuItem(
                        action: .theaterMemory,
                        title: "観劇の思い出を記録",
                        detail: "参加した公演を選んで記録を残す",
                        systemImage: "square.and.pencil"
                    ),
                ]
            )
        case "live":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .performanceRegistration,
                        title: "ライブを登録",
                        detail: "公演情報を登録して予定・チケットへ進む",
                        systemImage: "music.mic"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "参戦の記録をつける",
                        detail: "登録済みライブへ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                ]
            )
        case "book":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .quick,
                        title: "本を登録する",
                        detail: "読みたい本を日程なしで追加",
                        systemImage: "books.vertical.fill"
                    ),
                ]
            )
        case "movie":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .simpleCategoryRegistration,
                        title: "作品を登録する",
                        detail: "観たい・観る予定・鑑賞済みを選択",
                        systemImage: "film.stack"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "鑑賞の記録をつける",
                        detail: "登録済み作品へ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                ]
            )
        case "museum":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .simpleCategoryRegistration,
                        title: "展示・イベントを登録",
                        detail: "気になる・鑑賞予定・鑑賞済みを選択",
                        systemImage: "building.columns"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "鑑賞の記録をつける",
                        detail: "登録済み展示へ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                    CreateEntryMenuItem(
                        action: .placeCatalog,
                        title: "美術館・博物館を登録",
                        detail: "全国カタログから場所マスターへ追加",
                        systemImage: "building.2.crop.circle",
                        isSecondary: true
                    ),
                ]
            )
        case "theme_park":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .plan,
                        title: "行く予定を立てる",
                        detail: "施設を選ぶか、新しく登録して予定を追加",
                        systemImage: "calendar.badge.plus"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "来園の記録をつける",
                        detail: "登録済み施設へ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                    CreateEntryMenuItem(
                        action: .placeCatalog,
                        title: "施設を登録",
                        detail: "全国カタログから場所マスターへ追加",
                        systemImage: "building.2.crop.circle",
                        isSecondary: true
                    ),
                ]
            )
        case "nature_living":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .plan,
                        title: "行く予定を立てる",
                        detail: "スポットを選ぶか、新しく登録して予定を追加",
                        systemImage: "calendar.badge.plus"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "訪問の記録をつける",
                        detail: "登録済みスポットへ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                    CreateEntryMenuItem(
                        action: .placeCatalog,
                        title: "スポットを登録",
                        detail: "全国カタログから場所マスターへ追加",
                        systemImage: "leaf.circle.fill",
                        isSecondary: true
                    ),
                ]
            )
        case "outing_facility":
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .plan,
                        title: "行く予定を立てる",
                        detail: "施設を選ぶか、新しく登録して予定を追加",
                        systemImage: "calendar.badge.plus"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "訪問の記録をつける",
                        detail: "登録済み施設へ今回の記録を追加",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                    CreateEntryMenuItem(
                        action: .placeCatalog,
                        title: "施設を登録",
                        detail: "全国カタログから場所マスターへ追加",
                        systemImage: "building.2.crop.circle",
                        isSecondary: true
                    ),
                ]
            )
        default:
            CreateEntryMenuDefinition(
                templateKey: templateKey,
                items: [
                    CreateEntryMenuItem(
                        action: .plan,
                        title: "予定を立てる",
                        detail: "これから体験する予定を登録",
                        systemImage: "calendar.badge.plus"
                    ),
                    CreateEntryMenuItem(
                        action: .record,
                        title: "体験済みを記録",
                        detail: "観た・行った・体験した思い出を残す",
                        systemImage: "square.and.pencil",
                        requiresExistingRecord: true
                    ),
                    CreateEntryMenuItem(
                        action: .quick,
                        title: "クイック登録",
                        detail: "気になるものを最低限で一時保存",
                        systemImage: "bolt.fill"
                    ),
                    CreateEntryMenuItem(
                        action: .ticketSchedule,
                        title: "申込・発売を登録",
                        detail: "抽選・先着・取得済みのチケットを管理",
                        systemImage: "ticket"
                    ),
                ]
            )
        }
    }
}

private struct CreateEntryMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    let canCreateRecord: Bool
    let definition: CreateEntryMenuDefinition
    let onSelect: (CreateAction) -> Void

    static func preferredSheetHeight(itemCount: Int) -> CGFloat {
        let buttonHeight: CGFloat = 64
        let buttonSpacing: CGFloat = 10
        let sheetChromeAndInsets: CGFloat = 120
        return sheetChromeAndInsets
            + (CGFloat(itemCount) * buttonHeight)
            + (CGFloat(itemCount - 1) * buttonSpacing)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ForEach(definition.items) { item in
                    CreateEntryButton(
                        title: item.title,
                        detail: item.detail,
                        systemImage: item.systemImage,
                        isEnabled: !item.requiresExistingRecord || canCreateRecord,
                        isSecondary: item.isSecondary
                    ) {
                        onSelect(item.action)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .favorecoAppAppearance()
        .tint(themePalette.globalTint)
    }
}

private struct CreateEntryButton: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let title: String
    let detail: String
    let systemImage: String
    var isEnabled = true
    var isSecondary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                FavorecoIcon(systemName: systemImage, size: 20)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themePalette.globalTint.opacity(isSecondary ? 0.72 : 1))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    Text(detail)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        Color(uiColor: isSecondary
                              ? .tertiarySystemGroupedBackground
                              : .secondarySystemGroupedBackground)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(isSecondary ? 0.20 : 0.32), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private enum MainTab: Hashable {
    case home
    case records
    case create
    case calendar
    case stats
}

struct PlaceholderRow: View {
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
        .padding(.vertical, 6)
    }
}

#Preview {
    MainTabView()
        .environmentObject(PurchaseManager.shared)
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, CompanionMaster.self, FavoriteProfile.self, FavoGalleryPhoto.self, FavoAnniversary.self, FavoPin.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
