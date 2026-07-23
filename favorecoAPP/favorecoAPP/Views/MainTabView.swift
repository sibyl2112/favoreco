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

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @AppStorage(AppStorageKeys.defaultGenreMode) private var defaultGenreMode = "lastUsed"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.opensPreviousMonthlyReport) private var opensPreviousMonthlyReport = false
    @AppStorage(AppStorageKeys.opensPreviousYearlyReport) private var opensPreviousYearlyReport = false
    @AppStorage(AppStorageKeys.pendingNotificationPlanID) private var pendingNotificationPlanID = ""
    @AppStorage(AppStorageKeys.pendingNotificationAttemptID) private var pendingNotificationAttemptID = ""
    @AppStorage(AppStorageKeys.pendingNotificationPreparationTaskID) private var pendingNotificationPreparationTaskID = ""
    @State private var selectedTab: MainTab = .home
    @State private var isShowingCreateMenu = false
    @State private var isShowingRecordTargetSelection = false
    @State private var isShowingAddPlan = false
    @State private var isShowingAddTicketSchedule = false
    @State private var isShowingQuickRegistration = false
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

    private var createMenuCategories: [RecordCategory] {
        guard let preferredCategory else { return visibleCategories }
        return [preferredCategory] + visibleCategories.filter { $0.id != preferredCategory.id }
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .create {
                    isShowingCreateMenu = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            FavoView()
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label("FAVO", systemImage: "heart.text.square.fill")
                }
                .tag(MainTab.records)

            Color.clear
                .tabItem {
                    Label("追加", systemImage: "plus")
                }
                .tag(MainTab.create)

            CalendarView(
                displayMode: $calendarDisplayMode,
                requestedPlanID: $pendingNotificationPlanID,
                requestedAttemptID: $pendingNotificationAttemptID,
                requestedPreparationTaskID: $pendingNotificationPreparationTaskID
            )
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(MainTab.calendar)

            StatsView(isActive: selectedTab == .stats)
                .ignoresSafeArea(.container, edges: .bottom)
                .tabItem {
                    Label("統計", systemImage: "chart.bar.fill")
                }
                .tag(MainTab.stats)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $isShowingCreateMenu, onDismiss: openPendingCreateAction) {
            CreateEntryMenuView(
                canCreateRecord: !visibleCategories.isEmpty,
                onSelect: { action in
                    pendingCreateAction = action
                    isShowingCreateMenu = false
                }
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingRecordTargetSelection, onDismiss: openPendingRecordDestination) {
            RecordTargetSelectionView(
                categories: createMenuCategories,
                preferredCategory: preferredCategory
            ) { destination in
                pendingRecordDestination = destination
                isShowingRecordTargetSelection = false
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
            isShowingAddPlan = true
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
            }
        }
        .sheet(isPresented: $isShowingAddPlan) {
            AddTicketPlanView(entryMode: .plan)
        }
        .sheet(isPresented: $isShowingQuickRegistration) {
            QuickRegistrationView()
        }
        .sheet(isPresented: $isShowingAddTicketSchedule) {
            AddTicketPlanView(entryMode: .ticketSchedule)
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
        case .quick:
            isShowingQuickRegistration = true
        case .ticketSchedule:
            isShowingAddTicketSchedule = true
        }
    }

    private func openPendingRecordDestination() {
        guard let pendingRecordDestination else { return }
        self.pendingRecordDestination = nil
        recordDestination = pendingRecordDestination
    }

    private func scheduleAutomaticBackupAfterInitialDisplay() async {
        guard !didScheduleStartupBackup else { return }
        didScheduleStartupBackup = true
        await Task.yield()
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        let request = AutomaticBackupRequest.automatic(
            canUseSyncFeatures: EntitlementAccess.canUseSyncFeatures
        )
        _ = await AutomaticBackupCoordinator.shared.run(
            request: request,
            modelContainer: modelContext.container
        )
    }
}
struct MainScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var usesBrandFont = false
    var centeredTitle: String? = nil
    var usesCompactBrand = false
    var brandGradient: LinearGradient? = nil
    var headerForegroundColor: Color? = nil
    var onLeadingTap: (() -> Void)? = nil
    var onCenteredTitleTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
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
            }

            HStack(alignment: .center, spacing: 12) {
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

                Spacer(minLength: 8)
                MainToolbarActions(tint: headerForegroundColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }

    private func centeredTitleLabel(_ title: String, showsChevron: Bool) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .tracking(5)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
        .foregroundStyle(headerForegroundColor ?? .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 112)
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
                ? FavorecoTypography.brandColor(for: colorScheme).opacity(usesCompactBrand ? 0.78 : 1)
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

    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 2) {
            Button {
                isShowingNotifications = true
            } label: {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 22, weight: .semibold))

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

    var id: String {
        switch self {
        case .new(let category): "new-\(category.id.uuidString)"
        case .existing(let event): "existing-\(event.id.uuidString)"
        }
    }
}

private struct RecordTargetSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]

    let categories: [RecordCategory]
    let preferredCategory: RecordCategory?
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
                Section {
                    Menu {
                        ForEach(categories) { category in
                            Button {
                                selectedCategoryID = category.id
                                searchText = ""
                            } label: {
                                Label(category.name, systemImage: category.iconSymbol)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedCategory?.iconSymbol ?? "square.grid.2x2")
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

                Section {
                    Button {
                        guard let selectedCategory else { return }
                        onSelect(.new(selectedCategory))
                    } label: {
                        Label("新しい作品・対象を登録", systemImage: "plus.circle.fill")
                            .font(FavorecoTypography.bodyStrong)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedCategory == nil)
                }

                Section {
                    TextField("タイトルを検索", text: $searchText)
                        .textInputAutocapitalization(.never)

                    if matchingEvents.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "登録済みの対象はありません" : "一致する対象はありません",
                            systemImage: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass",
                            description: Text(searchText.isEmpty ? "上のボタンから新しい対象を登録できます。" : "タイトルやシリーズ名を変えて検索してください。")
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(matchingEvents) { event in
                                    Button {
                                        onSelect(.existing(event))
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: event.category?.iconSymbol ?? "rectangle.stack")
                                                .foregroundStyle(.secondary)
                                                .frame(width: 28)
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
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                        .frame(height: min(CGFloat(matchingEvents.count) * 64, 320))
                        .scrollIndicators(.visible)
                    }
                } header: {
                    Text(searchText.isEmpty ? "最近の作品・対象" : "検索結果")
                } footer: {
                    Text("登録済みの対象を選ぶと、タイトルや公式情報を重複登録せず、今回の記録だけを追加できます。")
                }
            }
            .navigationTitle("体験済みを記録")
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
}

private enum CreateAction: String, Identifiable {
    case plan
    case record
    case quick
    case ticketSchedule

    var id: String { rawValue }
}

private struct CreateEntryMenuView: View {
    @Environment(\.dismiss) private var dismiss
    let canCreateRecord: Bool
    let onSelect: (CreateAction) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                CreateEntryButton(
                    title: "予定を立てる",
                    detail: "これから体験する予定を登録",
                    systemImage: "calendar.badge.plus"
                ) {
                    onSelect(.plan)
                }

                CreateEntryButton(
                    title: "体験済みを記録",
                    detail: "観た・行った・体験した思い出を残す",
                    systemImage: "square.and.pencil",
                    isEnabled: canCreateRecord
                ) {
                    onSelect(.record)
                }

                CreateEntryButton(
                    title: "クイック登録",
                    detail: "気になるものを最低限で一時保存",
                    systemImage: "bolt.fill"
                ) {
                    onSelect(.quick)
                }

                CreateEntryButton(
                    title: "チケットスケジュールを追加",
                    detail: "抽選・発売・発券の予定を登録",
                    systemImage: "ticket"
                ) {
                    onSelect(.ticketSchedule)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .navigationTitle("追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct CreateEntryButton: View {
    let title: String
    let detail: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
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
        .padding(.vertical, 6)
    }
}

#Preview {
    MainTabView()
        .environmentObject(PurchaseManager.shared)
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, CompanionMaster.self, FavoriteProfile.self, FavoGalleryPhoto.self, FavoAnniversary.self, FavoPin.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
