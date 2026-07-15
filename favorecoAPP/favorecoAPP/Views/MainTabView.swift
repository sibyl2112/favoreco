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

private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case calendar
    case planList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: "カレンダー"
        case .planList: "予定一覧"
        }
    }
}

struct MainTabView: View {
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @AppStorage(AppStorageKeys.defaultGenreMode) private var defaultGenreMode = "lastUsed"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.opensPreviousMonthlyReport) private var opensPreviousMonthlyReport = false
    @AppStorage(AppStorageKeys.opensPreviousYearlyReport) private var opensPreviousYearlyReport = false
    @State private var selectedTab: MainTab = .home
    @State private var isShowingCreateMenu = false
    @State private var isShowingRecordTargetSelection = false
    @State private var isShowingAddPlan = false
    @State private var isShowingAddTicketSchedule = false
    @State private var isShowingQuickRegistration = false
    @State private var pendingCreateAction: CreateAction?
    @State private var pendingRecordDestination: RecordEntryDestination?
    @State private var recordDestination: RecordEntryDestination?
    @State private var calendarDisplayMode: CalendarDisplayMode = .calendar

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
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(MainTab.home)

            RecordsView()
                .tabItem {
                    Label("記録", systemImage: "rectangle.stack")
                }
                .tag(MainTab.records)

            Color.clear
                .tabItem {
                    Label("追加", systemImage: "plus")
                }
                .tag(MainTab.create)

            CalendarView(displayMode: $calendarDisplayMode)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(MainTab.calendar)

            StatsView(isActive: selectedTab == .stats)
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }
                .tag(MainTab.stats)
        }
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
        .task {
            if opensPreviousMonthlyReport || opensPreviousYearlyReport {
                selectedTab = .stats
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
                AddExperienceView(category: category)
            case .existing(let event):
                AddVisitView(event: event)
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
}

struct MainToolbarActions: View {
    @AppStorage(AppStorageKeys.profileImageData) private var profileImageData = Data()
    @State private var isShowingNotifications = false
    @State private var isShowingSettings = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                isShowingNotifications = true
            } label: {
                Image(systemName: "bell")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("お知らせ")

            Button {
                isShowingSettings = true
            } label: {
                ProfileAvatarView(data: profileImageData, size: 30)
            }
            .accessibilityLabel("マイ・設定")
        }
        .sheet(isPresented: $isShowingNotifications) {
            AppNotificationCenterView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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
                            }
                            .buttonStyle(.plain)
                        }
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

private struct RecordsView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var searchText = ""
    @State private var selectedCategoryID: UUID?
    @State private var periodFilter: RecordPeriodFilter = .all
    @State private var photoFilterEnabled = false
    @State private var sortOrder: RecordSortOrder = .newest
    @State private var isShowingFilters = false

    private var visibleVisits: [Visit] {
        let calendar = Calendar.current
        let now = Date()
        let filtered = visits.filter { visit in
            guard visit.event?.isArchived != true else { return false }
            if let selectedCategoryID, visit.event?.category?.id != selectedCategoryID {
                return false
            }
            switch periodFilter {
            case .all:
                break
            case .thisMonth:
                guard calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .month) else { return false }
            case .thisYear:
                guard calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .year) else { return false }
            }
            if photoFilterEnabled,
               !(visit.photos ?? []).contains(where: { $0.mediaKind == "photo" && $0.hasStoredData }) {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            let searchableText = [
                visit.event?.title ?? "",
                visit.event?.seriesName ?? "",
                visit.venueNameSnapshot,
                visit.note,
            ].joined(separator: " ")
            return searchableText.localizedCaseInsensitiveContains(query)
        }

        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .newest:
                lhs.visitedAt > rhs.visitedAt
            case .oldest:
                lhs.visitedAt < rhs.visitedAt
            case .recentlyUpdated:
                lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedCategoryID != nil { count += 1 }
        if periodFilter != .all { count += 1 }
        if photoFilterEnabled { count += 1 }
        if sortOrder != .newest { count += 1 }
        return count
    }

    private var activeCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                recordToolbar

                List {
                if visibleVisits.isEmpty {
                    PlaceholderRow(
                        icon: activeFilterCount > 0 || !searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "rectangle.stack",
                        title: activeFilterCount > 0 || !searchText.isEmpty ? "条件に合う記録がありません" : "記録はまだありません",
                        message: activeFilterCount > 0 || !searchText.isEmpty ? "検索語やフィルターを変更してください。" : "下部の「追加」から最初の記録を追加できます。"
                    )
                } else {
                    ForEach(visibleVisits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                }
                .listStyle(.plain)
            }
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    MainToolbarActions()
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                RecordFilterView(
                    categories: activeCategories,
                    selectedCategoryID: $selectedCategoryID,
                    periodFilter: $periodFilter,
                    photoFilterEnabled: $photoFilterEnabled,
                    sortOrder: $sortOrder
                )
            }
        }
    }

    private var recordToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("タイトル・会場・メモを検索", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("検索をクリア")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    isShowingFilters = true
                } label: {
                    Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .frame(width: 42, height: 42)
                        .overlay(alignment: .topTrailing) {
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.accentColor, in: Circle())
                                    .offset(x: 5, y: -5)
                            }
                        }
                }
                .accessibilityLabel("記録を絞り込む")
            }

            HStack {
                Text("\(visibleVisits.count)件")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink {
                    TicketOverviewView()
                } label: {
                    Label("予定・チケット", systemImage: "ticket")
                        .font(FavorecoTypography.captionStrong)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
    }
}

private enum RecordPeriodFilter: String, CaseIterable, Identifiable {
    case all
    case thisMonth
    case thisYear

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "すべて"
        case .thisMonth: "今月"
        case .thisYear: "今年"
        }
    }
}

private enum RecordSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case recentlyUpdated

    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "新しい順"
        case .oldest: "古い順"
        case .recentlyUpdated: "最近更新した順"
        }
    }
}

private struct RecordFilterView: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [RecordCategory]
    @Binding var selectedCategoryID: UUID?
    @Binding var periodFilter: RecordPeriodFilter
    @Binding var photoFilterEnabled: Bool
    @Binding var sortOrder: RecordSortOrder

    var body: some View {
        NavigationStack {
            Form {
                Section("ジャンル") {
                    Picker("ジャンル", selection: $selectedCategoryID) {
                        Text("すべて").tag(UUID?.none)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.iconSymbol)
                                .tag(Optional(category.id))
                        }
                    }
                }

                Section("期間") {
                    Picker("期間", selection: $periodFilter) {
                        ForEach(RecordPeriodFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("内容") {
                    Toggle("写真がある記録だけ", isOn: $photoFilterEnabled)
                }

                Section("並び順") {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(RecordSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                }

                Section {
                    Button("すべての条件をクリア") {
                        selectedCategoryID = nil
                        periodFilter = .all
                        photoFilterEnabled = false
                        sortOrder = .newest
                    }
                }
            }
            .navigationTitle("記録を絞り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

private struct CalendarView: View {
    @Binding var displayMode: CalendarDisplayMode
    @Query(sort: \Visit.visitedAt, order: .forward) private var visits: [Visit]
    @Query(sort: \Plan.startsAt, order: .forward) private var plans: [Plan]
    @AppStorage(AppStorageKeys.showsExternalCalendarEvents) private var showsExternalCalendarEvents = true
    @StateObject private var externalCalendarStore = ExternalCalendarOverlayStore()
    @State private var displayedMonth = Date().startOfMonth
    @State private var selectedDate = Date()

    private let calendar = Calendar.current

    private var visibleVisits: [Visit] {
        visits.filter { $0.event?.isArchived != true }
    }

    private var daysInDisplayedMonth: [CalendarDay] {
        CalendarDay.days(for: displayedMonth, calendar: calendar)
    }

    private var visitsByDay: [Date: [Visit]] {
        Dictionary(grouping: visibleVisits) { visit in
            calendar.startOfDay(for: visit.visitedAt)
        }
    }

    private var plansByDay: [Date: [Plan]] {
        Dictionary(grouping: plans.filter { !$0.isArchived }) { plan in
            calendar.startOfDay(for: plan.startsAt)
        }
    }

    private var externalEventsByDay: [Date: [ExternalCalendarEvent]] {
        Dictionary(grouping: externalCalendarStore.events) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }

    private var selectedDayVisits: [Visit] {
        visitsByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var selectedDayPlans: [Plan] {
        plansByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var selectedDayExternalEvents: [ExternalCalendarEvent] {
        externalEventsByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var upcomingVisits: [Visit] {
        let today = calendar.startOfDay(for: Date())
        return visibleVisits
            .filter { calendar.startOfDay(for: $0.visitedAt) >= today }
            .prefix(5)
            .map { $0 }
    }

    private var upcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .prefix(5)
            .map { $0 }
    }

    private var allUpcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingPlanGroups: [(month: Date, plans: [Plan])] {
        Dictionary(grouping: allUpcomingPlans) { $0.startsAt.startOfMonth }
            .map { (month: $0.key, plans: $0.value.sorted { $0.startsAt < $1.startsAt }) }
            .sorted { $0.month < $1.month }
    }

    private var upcomingExternalEvents: [ExternalCalendarEvent] {
        let now = Date()
        return externalCalendarStore.events
            .filter { $0.endDate >= now }
            .prefix(5)
            .map { $0 }
    }

    private var calendarFetchInterval: DateInterval {
        let days = daysInDisplayedMonth
        let start = days.first?.date ?? displayedMonth
        let lastDay = days.last?.date ?? displayedMonth
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return DateInterval(start: start, end: end)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Picker("表示", selection: $displayMode) {
                            ForEach(CalendarDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        NavigationLink {
                            TicketOverviewView()
                        } label: {
                            Image(systemName: "ticket")
                                .font(.title3)
                                .frame(width: 42, height: 32)
                        }
                        .accessibilityLabel("予定・チケット")
                    }

                    if displayMode == .calendar {
                        monthHeader
                        externalCalendarControl
                        weekdayHeader
                        monthGrid
                        selectedDaySection
                        upcomingSection
                    } else {
                        planListSection
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("カレンダー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    MainToolbarActions()
                }
            }
            .task {
                await refreshExternalCalendarIfNeeded()
            }
            .onChange(of: displayedMonth) { _, _ in
                Task {
                    await refreshExternalCalendarIfNeeded()
                }
            }
            .onChange(of: showsExternalCalendarEvents) { _, newValue in
                Task {
                    if newValue {
                        await refreshExternalCalendarIfNeeded()
                    } else {
                        externalCalendarStore.updateAuthorizationStatus()
                    }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)

            Spacer()

            Text(japaneseYearMonth(displayedMonth))
                .font(FavorecoTypography.sectionTitle)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
        }
    }

    private var planListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if upcomingPlanGroups.isEmpty {
                PlaceholderRow(
                    icon: "calendar.badge.plus",
                    title: "今後の予定はありません",
                    message: "Homeまたは下部の「追加」から予定を立てられます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(upcomingPlanGroups, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(japaneseYearMonth(group.month))
                            .font(FavorecoTypography.sectionTitle)

                        ForEach(group.plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                PlanSummaryRow(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func japaneseYearMonth(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private var externalCalendarControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("外部カレンダーを重ねる", isOn: $showsExternalCalendarEvents)
                .font(FavorecoTypography.bodyStrong)

            HStack(spacing: 10) {
                Label(externalCalendarStore.authorizationStatusText, systemImage: "calendar.badge.clock")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if externalCalendarStore.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Spacer()

                if showsExternalCalendarEvents && !externalCalendarStore.canReadEvents {
                    Button("許可する") {
                        Task {
                            await externalCalendarStore.requestAccessAndRefresh(interval: calendarFetchInterval)
                        }
                    }
                    .font(FavorecoTypography.captionStrong)
                } else if showsExternalCalendarEvents {
                    Button {
                        Task {
                            await refreshExternalCalendarIfNeeded()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("外部カレンダーを再読み込み")
                }
            }

            if !externalCalendarStore.errorMessage.isEmpty {
                Text(externalCalendarStore.errorMessage)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(daysInDisplayedMonth) { day in
                let dayVisits = visitsByDay[calendar.startOfDay(for: day.date)] ?? []
                let dayPlans = plansByDay[calendar.startOfDay(for: day.date)] ?? []
                let dayExternalEvents = externalEventsByDay[calendar.startOfDay(for: day.date)] ?? []
                CalendarDayCell(
                    day: day,
                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day.date),
                    visitCount: dayVisits.count,
                    planCount: dayPlans.count,
                    externalEventCount: showsExternalCalendarEvents ? dayExternalEvents.count : 0
                ) {
                    selectedDate = day.date
                    if !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month) {
                        displayedMonth = day.date.startOfMonth
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .long, time: .omitted))
                .font(FavorecoTypography.sectionTitle)

            if selectedDayVisits.isEmpty && selectedDayPlans.isEmpty && (!showsExternalCalendarEvents || selectedDayExternalEvents.isEmpty) {
                PlaceholderRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "この日の記録はありません",
                    message: "予定や訪問記録を追加するとここに表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !selectedDayPlans.isEmpty {
                        Text("予定・チケット")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)

                        ForEach(selectedDayPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                PlanSummaryRow(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !selectedDayVisits.isEmpty {
                        Text("記録")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, selectedDayPlans.isEmpty ? 0 : 4)

                        ForEach(selectedDayVisits) { visit in
                            NavigationLink {
                                ExperienceDetailView(visit: visit)
                            } label: {
                                VisitSummaryRow(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showsExternalCalendarEvents && !selectedDayExternalEvents.isEmpty {
                        Text("外部カレンダー")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, selectedDayVisits.isEmpty && selectedDayPlans.isEmpty ? 0 : 4)

                        ForEach(selectedDayExternalEvents) { event in
                            ExternalCalendarEventRow(event: event)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingPlans.isEmpty || !upcomingVisits.isEmpty || (showsExternalCalendarEvents && !upcomingExternalEvents.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                Text("直近の予定")
                    .font(FavorecoTypography.sectionTitle)

                VStack(alignment: .leading, spacing: 10) {
                    if !upcomingPlans.isEmpty {
                        ForEach(upcomingPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                PlanSummaryRow(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !upcomingVisits.isEmpty {
                        Text("記録")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, upcomingPlans.isEmpty ? 0 : 4)

                        ForEach(upcomingVisits) { visit in
                            NavigationLink {
                                ExperienceDetailView(visit: visit)
                            } label: {
                                VisitSummaryRow(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showsExternalCalendarEvents && !upcomingExternalEvents.isEmpty {
                        Text("外部カレンダー")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .padding(.top, upcomingVisits.isEmpty && upcomingPlans.isEmpty ? 0 : 4)

                        ForEach(upcomingExternalEvents) { event in
                            ExternalCalendarEventRow(event: event)
                        }
                    }
                }
            }
        }
    }

    private func refreshExternalCalendarIfNeeded() async {
        externalCalendarStore.updateAuthorizationStatus()
        guard showsExternalCalendarEvents else { return }
        await externalCalendarStore.refresh(interval: calendarFetchInterval)
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isInDisplayedMonth: Bool

    static func days(for month: Date, calendar: Calendar) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leadingDays = (0..<leadingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leadingCount, to: monthInterval.start)
        }
        let currentMonthDays = monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        let totalCount = leadingDays.count + currentMonthDays.count
        let trailingCount = (7 - totalCount % 7) % 7
        let trailingDays = (0..<trailingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset + 1, to: currentMonthDays.last ?? monthInterval.start)
        }

        return (leadingDays + currentMonthDays + trailingDays).map { date in
            CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthInterval.start, toGranularity: .month)
            )
        }
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let visitCount: Int
    let planCount: Int
    let externalEventCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(day.date.formatted(.dateTime.day()))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(day.isInDisplayedMonth ? .primary : .tertiary)

                HStack(spacing: 3) {
                    ForEach(0..<min(visitCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? .white : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                    ForEach(0..<min(planCount, 2), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(isSelected ? .white : Color.orange)
                            .frame(width: 5, height: 4)
                    }
                    ForEach(0..<min(externalEventCount, 2), id: \.self) { _ in
                        Circle()
                            .stroke(isSelected ? .white : Color.secondary, lineWidth: 1)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(backgroundShape)
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        }
        if visitCount > 0 {
            return AnyShapeStyle(Color.accentColor.opacity(0.10))
        }
        if planCount > 0 {
            return AnyShapeStyle(Color.orange.opacity(0.12))
        }
        if externalEventCount > 0 {
            return AnyShapeStyle(Color(.tertiarySystemGroupedBackground))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }
}

private struct PlanSummaryRow: View {
    let plan: Plan
    @Environment(\.favorecoThemePalette) private var themePalette

    private var categoryColor: Color {
        themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var activeAttempts: [TicketAttempt] {
        plan.ticketAttempts?.filter { !$0.isArchived } ?? []
    }

    private var ticketAttempt: TicketAttempt? {
        TicketAttemptPresentationOrder.sorted(activeAttempts).first
    }

    private var nextTicketAction: TicketNextActionDefinition? {
        activeAttempts
            .compactMap { TicketNextActionDefinition.nextAction(for: $0) }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first
    }

    private var ticketInputIssue: TicketInputIssueDefinition? {
        activeAttempts
            .compactMap { TicketInputIssueDefinition.issue(for: $0) }
            .sorted { $0.priority < $1.priority }
            .first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: plan.category?.iconSymbol ?? "ticket")
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.title.isEmpty ? "予定" : plan.title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let ticketAttempt {
                        Text(TicketStatusDefinition.name(for: ticketAttempt.statusKey))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Label(plan.startsAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    if !plan.venueNameSnapshot.isEmpty {
                        Label(plan.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let ticketAttempt, !ticketAttempt.entryRouteKey.isEmpty {
                    Text(TicketEntryRouteDefinition.name(for: ticketAttempt.entryRouteKey))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let ticketInputIssue {
                    Label(ticketInputIssue.title, systemImage: ticketInputIssue.systemImage)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if let nextTicketAction {
                    Label(
                        "\(nextTicketAction.title) \(nextTicketAction.date.formatted(date: .numeric, time: .shortened))",
                        systemImage: nextTicketAction.systemImage
                    )
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(nextTicketAction.isOverdue ? .red : .orange)
                    .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ExternalCalendarEventRow: View {
    let event: ExternalCalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(uiColor: event.color))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(timeLabel, systemImage: event.isAllDay ? "sun.max" : "clock")
                    Text(event.calendarTitle)
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "終日"
        }
        return "\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))"
    }
}

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}

private struct StatsView: View {
    let isActive: Bool
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \Plan.startsAt, order: .reverse) private var plans: [Plan]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @State private var showsAmount = false
    @AppStorage(AppStorageKeys.opensPreviousMonthlyReport) private var opensPreviousMonthlyReport = false
    @AppStorage(AppStorageKeys.opensPreviousYearlyReport) private var opensPreviousYearlyReport = false
    @State private var isShowingAutomaticMonthlyReport = false
    @State private var isShowingAutomaticYearlyReport = false

    private var calendar: Calendar {
        Calendar.current
    }

    private var visibleVisits: [Visit] {
        visits.filter { $0.event?.isArchived != true }
    }

    private var thisYearVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .year) }
    }

    private var thisMonthVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .month) }
    }

    private var totalAmount: Decimal {
        visibleVisits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var averageRating: Double {
        let ratedVisits = visibleVisits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else { return 0 }
        return ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
    }

    private var categoryStats: [CategoryStat] {
        categories
            .filter { !$0.isArchived }
            .map { category in
                let count = visibleVisits.filter { $0.event?.category?.id == category.id }.count
                return CategoryStat(category: category, count: count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var monthlyVisitStats: [MonthlyVisitStat] {
        let currentMonth = Date().startOfMonth
        return (0..<12).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset - 11, to: currentMonth) else {
                return nil
            }
            let count = visibleVisits.lazy.filter {
                calendar.isDate($0.visitedAt, equalTo: month, toGranularity: .month)
            }.count
            return MonthlyVisitStat(month: month, count: count)
        }
    }

    private var categoryChartStats: [CategoryChartStat] {
        let topStats = Array(categoryStats.prefix(5))
        var result = topStats.map {
            CategoryChartStat(
                name: $0.category.name,
                count: $0.count,
                color: themePalette.categoryColor(hex: $0.category.colorHex)
            )
        }
        let otherCount = categoryStats.dropFirst(5).reduce(0) { $0 + $1.count }
        if otherCount > 0 {
            result.append(CategoryChartStat(name: "その他", count: otherCount, color: .secondary))
        }
        return result
    }

    private var activePlans: [Plan] {
        plans.filter { !$0.isArchived }
    }

    private var activeAttempts: [TicketAttempt] {
        ticketAttempts.filter { !$0.isArchived && $0.plan?.isArchived != true }
    }

    private var thisYearPlans: [Plan] {
        activePlans.filter { calendar.isDate($0.startsAt, equalTo: Date(), toGranularity: .year) }
    }

    private var submittedAttempts: [TicketAttempt] {
        let submittedKeys: Set<String> = [
            "waitingResult", "won", "lost", "waitingPayment", "waitingIssue", "issued", "attended",
        ]
        return activeAttempts.filter { submittedKeys.contains($0.statusKey) }
    }

    private var wonAttempts: [TicketAttempt] {
        let wonKeys: Set<String> = ["won", "waitingPayment", "waitingIssue", "issued", "attended"]
        return activeAttempts.filter { wonKeys.contains($0.statusKey) }
    }

    private var lostAttempts: [TicketAttempt] {
        activeAttempts.filter { $0.statusKey == "lost" }
    }

    private var attendedAttempts: [TicketAttempt] {
        activeAttempts.filter { $0.statusKey == "attended" }
    }

    private var winRateText: String {
        let decidedCount = wonAttempts.count + lostAttempts.count
        guard decidedCount > 0 else { return "-" }
        return String(format: "%.0f%%", Double(wonAttempts.count) / Double(decidedCount) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryGrid
                    categoryStatsSection
                    chartsSection
                    ticketStatsSection
                    spendingSection
                    ratingSection
                    reportPreviewSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("統計")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    MainToolbarActions()
                }
            }
            .navigationDestination(isPresented: $isShowingAutomaticMonthlyReport) {
                StatsReportDraftView(
                    kind: .monthly,
                    allVisits: visibleVisits,
                    categories: categories,
                    initialPeriodStart: previousMonthStart
                )
            }
            .navigationDestination(isPresented: $isShowingAutomaticYearlyReport) {
                StatsReportDraftView(
                    kind: .yearly,
                    allVisits: visibleVisits,
                    categories: categories,
                    initialPeriodStart: previousYearStart
                )
            }
        }
        .task { openAutomaticReportIfNeeded() }
        .onChange(of: opensPreviousMonthlyReport) { _, _ in
            openAutomaticReportIfNeeded()
        }
        .onChange(of: opensPreviousYearlyReport) { _, _ in
            openAutomaticReportIfNeeded()
        }
        .onChange(of: isActive) { _, _ in
            openAutomaticReportIfNeeded()
        }
    }

    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: Date().startOfMonth) ?? Date().startOfMonth
    }

    private var previousYearStart: Date {
        let currentYearStart = calendar.date(from: calendar.dateComponents([.year], from: Date())) ?? Date()
        return calendar.date(byAdding: .year, value: -1, to: currentYearStart) ?? currentYearStart
    }

    private func openAutomaticReportIfNeeded() {
        guard isActive, purchaseManager.currentPlan.includesSync else { return }
        if opensPreviousYearlyReport {
            opensPreviousYearlyReport = false
            isShowingAutomaticYearlyReport = true
        } else if opensPreviousMonthlyReport {
            opensPreviousMonthlyReport = false
            isShowingAutomaticMonthlyReport = true
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsMetricCard(title: "総記録数", value: "\(visibleVisits.count)", icon: "rectangle.stack")
            StatsMetricCard(title: "今年", value: "\(thisYearVisits.count)", icon: "calendar")
            StatsMetricCard(title: "今月", value: "\(thisMonthVisits.count)", icon: "calendar.badge.clock")
            StatsMetricCard(title: "平均評価", value: averageRating == 0 ? "-" : String(format: "%.1f", averageRating), icon: "star.fill")
        }
    }

    private var categoryStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ジャンル別")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "詳細統計",
                    message: "ジャンル別の回数や傾向は、ProまたはPremiumで利用できます。",
                    systemImage: "chart.bar.xaxis",
                    requirement: "Pro以上"
                )
            } else if categoryStats.isEmpty {
                PlaceholderRow(
                    icon: "square.grid.2x2",
                    title: "ジャンル別統計はまだありません",
                    message: "記録を追加すると、ジャンルごとの回数が表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(categoryStats) { stat in
                        CategoryStatRow(stat: stat, maxCount: categoryStats.first?.count ?? 1)
                    }
                }
            }
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出")
                .font(FavorecoTypography.sectionTitle)

            StatsPrivateAmountCard(
                title: "記録済み金額",
                value: formattedAmount(totalAmount),
                isRevealed: showsAmount,
                caption: "チケット代、購入額、遠征費など、金額ユニットに入力された合計です。",
                icon: "yensign.circle",
                onToggle: {
                    withAnimation(.snappy) {
                        showsAmount.toggle()
                    }
                }
            )
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("記録の傾向")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "推移・構成グラフ",
                    message: "直近12か月の記録推移と、ジャンル構成を見返せます。",
                    systemImage: "chart.xyaxis.line",
                    requirement: "Pro以上"
                )
            } else if visibleVisits.isEmpty {
                PlaceholderRow(
                    icon: "chart.xyaxis.line",
                    title: "記録の傾向はまだありません",
                    message: "記録を追加すると、月ごとの推移とジャンル構成が表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("直近12か月")
                        .font(FavorecoTypography.bodyStrong)
                    Chart(monthlyVisitStats) { stat in
                        AreaMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.12))
                        LineMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 2)) { value in
                            AxisValueLabel(format: .dateTime.month(.narrow))
                        }
                    }
                    .frame(height: 190)
                    .accessibilityLabel("直近12か月の記録数推移")

                    if !categoryChartStats.isEmpty {
                        Divider()
                        Text("ジャンル構成")
                            .font(FavorecoTypography.bodyStrong)
                        HStack(alignment: .center, spacing: 18) {
                            Chart(categoryChartStats) { stat in
                                SectorMark(
                                    angle: .value("記録数", stat.count),
                                    innerRadius: .ratio(0.58),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(stat.color)
                                .cornerRadius(2)
                            }
                            .frame(width: 150, height: 150)
                            .accessibilityLabel("ジャンル別の記録構成")

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(categoryChartStats) { stat in
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(stat.color)
                                            .frame(width: 9, height: 9)
                                        Text(stat.name)
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text("\(stat.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(FavorecoTypography.caption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var ticketStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("予定・チケット")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "予定・申込の詳細統計",
                    message: "今年の予定、申込済み、取得、参加、確定済み抽選の当選率をまとめます。",
                    systemImage: "ticket",
                    requirement: "Pro以上"
                )
            } else if activePlans.isEmpty && activeAttempts.isEmpty {
                PlaceholderRow(
                    icon: "ticket",
                    title: "予定・チケット統計はまだありません",
                    message: "予定や申込を追加すると、ここへ集計されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatsMetricCard(title: "今年の予定", value: "\(thisYearPlans.count)", icon: "calendar")
                    StatsMetricCard(title: "申込済み", value: "\(submittedAttempts.count)", icon: "paperplane.fill")
                    StatsMetricCard(title: "取得", value: "\(wonAttempts.count)", icon: "checkmark.seal.fill")
                    StatsMetricCard(title: "参加済み", value: "\(attendedAttempts.count)", icon: "figure.walk")
                }
                StatsWideCard(
                    title: "当選率",
                    value: winRateText,
                    caption: "当選または落選が確定した抽選だけを分母にしています。",
                    icon: "percent"
                )
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価")
                .font(FavorecoTypography.sectionTitle)

            StatsWideCard(
                title: "平均評価",
                value: averageRating == 0 ? "未評価" : String(format: "%.1f", averageRating),
                caption: "評価が入力された記録だけを平均しています。",
                icon: "star.fill"
            )
        }
    }

    private var reportPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("思い出レポート")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    NavigationLink {
                        StatsReportDraftView(kind: .monthly, allVisits: visibleVisits, categories: categories)
                    } label: {
                        StatsReportPreviewCard(
                            title: "月刊Favoreco",
                            badge: "手動作成",
                            detail: "今月の記録、写真、ジャンル傾向、印象的な体験を1枚の思い出カードにまとめます。",
                            systemImage: "sparkles"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatsLockedFeatureCard(
                        title: "月刊Favoreco",
                        message: "月ごとの記録を集計し、思い出カードを手動で作成・共有できます。",
                        systemImage: "sparkles",
                        requirement: "Pro以上"
                    )
                }

                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    NavigationLink {
                        StatsReportDraftView(kind: .yearly, allVisits: visibleVisits, categories: categories)
                    } label: {
                        StatsReportPreviewCard(
                            title: "年間Favoreco",
                            badge: "手動作成",
                            detail: "年間ベスト、今年の10枚、よく通った場所、ジャンル横断の変化を見返します。",
                            systemImage: "calendar.badge.star"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatsLockedFeatureCard(
                        title: "年間Favoreco",
                        message: "1年分の記録を集計し、年間の思い出カードを手動で作成・共有できます。",
                        systemImage: "calendar.badge.star",
                        requirement: "Pro以上"
                    )
                }

                if purchaseManager.currentPlan.includesSync {
                    NavigationLink {
                        StatsReportDraftView(
                            kind: .monthly,
                            allVisits: visibleVisits,
                            categories: categories,
                            initialPeriodStart: previousMonthStart
                        )
                    } label: {
                        StatsReportPreviewCard(
                            title: "先月の月刊Favoreco",
                            badge: "自動提案",
                            detail: "毎月1日に、先月の記録から新しい思い出カードを提案します。",
                            systemImage: "wand.and.stars"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        StatsReportDraftView(
                            kind: .yearly,
                            allVisits: visibleVisits,
                            categories: categories,
                            initialPeriodStart: previousYearStart
                        )
                    } label: {
                        StatsReportPreviewCard(
                            title: "昨年の年間Favoreco",
                            badge: "自動提案",
                            detail: "昨年の記録を横断して、ジャンル、場所、写真、印象的な体験を振り返ります。",
                            systemImage: "calendar.badge.star"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatsLockedFeatureCard(
                        title: "毎月・毎年届く思い出レポート",
                        message: "同期済みの記録から、前月の月刊と前年の年間Favorecoを自動で提案します。",
                        systemImage: "wand.and.stars",
                        requirement: "Premium限定"
                    )
                }
            }
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }
}

private struct StatsLockedFeatureCard: View {
    let title: String
    let message: String
    let systemImage: String
    let requirement: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(
                    requirement,
                    systemImage: requirement.contains("準備中") ? "clock" : "lock.fill"
                )
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum StatsReportKind {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly:
            return "月刊Favoreco"
        case .yearly:
            return "年間Favoreco"
        }
    }

    func periodStart(containing date: Date) -> Date {
        switch self {
        case .monthly:
            return date.startOfMonth
        case .yearly:
            return Calendar.current.date(
                from: Calendar.current.dateComponents([.year], from: date)
            ) ?? date
        }
    }

    func periodLabel(for date: Date) -> String {
        switch self {
        case .monthly:
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            return "\(components.year ?? 0)年\(components.month ?? 0)月"
        case .yearly:
            return date.formatted(.dateTime.year())
        }
    }

    func moved(_ date: Date, by value: Int) -> Date {
        let component: Calendar.Component = self == .monthly ? .month : .year
        return Calendar.current.date(byAdding: component, value: value, to: date) ?? date
    }

    func contains(_ date: Date, in periodStart: Date) -> Bool {
        let granularity: Calendar.Component = self == .monthly ? .month : .year
        return Calendar.current.isDate(date, equalTo: periodStart, toGranularity: granularity)
    }

    func emptyMessage(for periodLabel: String) -> String {
        switch self {
        case .monthly:
            return "\(periodLabel)に記録が入ると、思い出カード候補がここに表示されます。"
        case .yearly:
            return "\(periodLabel)に記録が入ると、年間まとめやベスト候補がここに表示されます。"
        }
    }
}

private struct StatsReportDraftView: View {
    let kind: StatsReportKind
    let allVisits: [Visit]
    let categories: [RecordCategory]
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedPeriodStart: Date
    @State private var showsAmount = false
    @State private var showsCopyConfirmation = false
    @State private var shareImage: UIImage?
    @State private var isShowingImageShare = false
    @State private var imageGenerationError = ""

    init(
        kind: StatsReportKind,
        allVisits: [Visit],
        categories: [RecordCategory],
        initialPeriodStart: Date? = nil
    ) {
        self.kind = kind
        self.allVisits = allVisits
        self.categories = categories
        _selectedPeriodStart = State(initialValue: kind.periodStart(containing: initialPeriodStart ?? Date()))
    }

    private var visits: [Visit] {
        allVisits.filter { kind.contains($0.visitedAt, in: selectedPeriodStart) }
    }

    private var periodLabel: String {
        kind.periodLabel(for: selectedPeriodStart)
    }

    private var canMoveForward: Bool {
        selectedPeriodStart < kind.periodStart(containing: Date())
    }

    private var sortedVisits: [Visit] {
        visits.sorted { $0.visitedAt > $1.visitedAt }
    }

    private var categoryStats: [CategoryStat] {
        categories
            .filter { !$0.isArchived }
            .map { category in
                let count = visits.filter { $0.event?.category?.id == category.id }.count
                return CategoryStat(category: category, count: count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var totalAmount: Decimal {
        visits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var photoCount: Int {
        visits.reduce(0) { $0 + ($1.photos?.count ?? 0) }
    }

    private var averageRating: Double {
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else { return 0 }
        return ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
    }

    private var topVenueName: String {
        let names = visits
            .map { $0.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return mostFrequentValue(in: names) ?? "未記録"
    }

    private var topCategoryName: String {
        categoryStats.first?.category.name ?? "未記録"
    }

    private var shareText: String {
        var lines = [
            "\(kind.title) \(periodLabel)",
            "記録: \(visits.count)",
            "写真: \(photoCount)",
            "ジャンル: \(categoryStats.count)",
            "平均評価: \(averageRating == 0 ? "-" : String(format: "%.1f", averageRating))",
            "最多ジャンル: \(topCategoryName)",
            "よく出てきた場所: \(topVenueName)"
        ]

        if let firstVisit = sortedVisits.first {
            lines.append("カード候補: \(firstVisit.event?.title ?? "無題")")
        }

        lines.append("#Favoreco")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                reportHero

                if visits.isEmpty {
                    PlaceholderRow(
                        icon: "sparkles",
                        title: "\(periodLabel)の記録はまだありません",
                        message: kind.emptyMessage(for: periodLabel)
                    )
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    reportCardPreview
                    reportMetrics
                    reportHighlights
                    reportCategories
                    recentRecords
                    reportNextStep
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("共有用テキストをコピーしました", isPresented: $showsCopyConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("画像化の前段として、レポートの要約をテキストで共有できます。")
        }
        .alert("画像を作成できませんでした", isPresented: Binding(
            get: { !imageGenerationError.isEmpty },
            set: { if !$0 { imageGenerationError = "" } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageGenerationError)
        }
        .sheet(isPresented: $isShowingImageShare) {
            if let shareImage {
                StatsReportActivityView(activityItems: [shareImage])
            }
        }
    }

    private var reportHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(kind == .monthly ? "前の月" : "前の年")

                Spacer()
                Text(periodLabel)
                    .font(FavorecoTypography.bodyStrong)
                Spacer()

                Button {
                    movePeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveForward)
                .accessibilityLabel(kind == .monthly ? "次の月" : "次の年")
            }
            Text(kind.title)
                .font(FavorecoTypography.jpSerif(32, weight: .bold, relativeTo: .largeTitle))
            Text("端末内の記録から集計した思い出レポートです。カード画像として保存・共有できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var reportCardPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カードプレビュー")
                .font(FavorecoTypography.sectionTitle)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .largeTitle))
                        Text(periodLabel)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: kind == .monthly ? "sparkles" : "calendar.badge.star")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                Divider()

                HStack(spacing: 12) {
                    StatsReportMiniMetric(title: "記録", value: "\(visits.count)")
                    StatsReportMiniMetric(title: "写真", value: "\(photoCount)")
                    StatsReportMiniMetric(title: "ジャンル", value: "\(categoryStats.count)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(topCategoryName, systemImage: "square.grid.2x2")
                    Label(topVenueName, systemImage: "mappin.and.ellipse")
                    if let firstVisit = sortedVisits.first {
                        Label(firstVisit.event?.title ?? "無題", systemImage: "sparkles")
                    }
                }
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.16), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var reportMetrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsMetricCard(title: "記録", value: "\(visits.count)", icon: "rectangle.stack")
            StatsMetricCard(title: "写真", value: "\(photoCount)", icon: "photo.on.rectangle")
            StatsMetricCard(title: "ジャンル", value: "\(categoryStats.count)", icon: "square.grid.2x2")
            StatsMetricCard(title: "平均評価", value: averageRating == 0 ? "-" : String(format: "%.1f", averageRating), icon: "star.fill")
        }
    }

    private var reportHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ハイライト")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                StatsWideCard(
                    title: "いちばん多かったジャンル",
                    value: topCategoryName,
                    caption: "今後はジャンル横断の変化や、前月/前年との差もここに出します。",
                    icon: "chart.pie"
                )
                StatsWideCard(
                    title: "よく出てきた場所",
                    value: topVenueName,
                    caption: "会場マスターが育つと、よく通った劇場・映画館・寺社・施設も見返せます。",
                    icon: "mappin.and.ellipse"
                )
                StatsPrivateAmountCard(
                    title: "記録済み金額",
                    value: formattedAmount(totalAmount),
                    isRevealed: showsAmount,
                    caption: "金額はプライバシー情報なので、この下書きでも初期表示では伏せます。",
                    icon: "yensign.circle",
                    onToggle: {
                        withAnimation(.snappy) {
                            showsAmount.toggle()
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var reportCategories: some View {
        if !categoryStats.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("ジャンル傾向")
                    .font(FavorecoTypography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(categoryStats.prefix(5)) { stat in
                        CategoryStatRow(stat: stat, maxCount: categoryStats.first?.count ?? 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentRecords: some View {
        if !sortedVisits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("カード候補")
                    .font(FavorecoTypography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(Array(sortedVisits.prefix(3))) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var reportNextStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("共有")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                Button {
                    generateAndShareImage()
                } label: {
                    Label("カード画像を共有", systemImage: "photo.on.rectangle.angled")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                ShareLink(
                    item: shareText,
                    subject: Text(kind.title),
                    message: Text("Favorecoの思い出レポート")
                ) {
                    Label("テキストで共有", systemImage: "square.and.arrow.up")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    UIPasteboard.general.string = shareText
                    showsCopyConfirmation = true
                } label: {
                    Label("テキストをコピー", systemImage: "doc.on.doc")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            StatsWideCard(
                title: "カード画像",
                value: "手動生成",
                caption: "共有シートから画像保存やSNSへの共有ができます。金額はカード画像に含めません。",
                icon: "photo.on.rectangle"
            )
        }
    }

    @MainActor
    private func generateAndShareImage() {
        let rows = categoryStats.prefix(4).map {
            StatsReportImageCategory(
                name: $0.category.name,
                count: $0.count,
                colorHex: themePalette.resolvedHex(categoryHex: $0.category.colorHex)
            )
        }
        let snapshot = StatsReportImageSnapshot(
            title: kind.title,
            period: periodLabel,
            recordCount: visits.count,
            photoCount: photoCount,
            categoryCount: categoryStats.count,
            averageRating: averageRating == 0 ? "-" : String(format: "%.1f", averageRating),
            topCategory: topCategoryName,
            topVenue: topVenueName,
            highlight: sortedVisits.first?.event?.title ?? "記録を重ねた時間",
            categories: rows
        )
        let renderer = ImageRenderer(content: StatsReportShareCard(snapshot: snapshot))
        renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            imageGenerationError = "画面を閉じてから、もう一度お試しください。"
            return
        }
        shareImage = image
        isShowingImageShare = true
    }

    private func movePeriod(by value: Int) {
        withAnimation(.snappy) {
            selectedPeriodStart = kind.moved(selectedPeriodStart, by: value)
            showsAmount = false
            shareImage = nil
        }
    }

    private func mostFrequentValue(in values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 })
            .map { (value: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.value < rhs.value
                }
                return lhs.count > rhs.count
            }
            .first?
            .value
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }
}

private struct StatsReportImageSnapshot {
    let title: String
    let period: String
    let recordCount: Int
    let photoCount: Int
    let categoryCount: Int
    let averageRating: String
    let topCategory: String
    let topVenue: String
    let highlight: String
    let categories: [StatsReportImageCategory]
}

private struct StatsReportImageCategory: Identifiable {
    let name: String
    let count: Int
    let colorHex: String

    var id: String { "\(name)-\(colorHex)" }
}

private struct StatsReportShareCard: View {
    let snapshot: StatsReportImageSnapshot

    private var accent: Color {
        Color(hex: snapshot.categories.first?.colorHex ?? "#147C88")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.period)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(snapshot.title)
                    .font(FavorecoTypography.jpSerif(30, weight: .bold, relativeTo: .largeTitle))
                Rectangle()
                    .fill(accent)
                    .frame(width: 56, height: 4)
            }
            .padding(.bottom, 20)

            HStack(spacing: 8) {
                imageMetric("記録", "\(snapshot.recordCount)")
                imageMetric("写真", "\(snapshot.photoCount)")
                imageMetric("ジャンル", "\(snapshot.categoryCount)")
                imageMetric("平均評価", snapshot.averageRating)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("HIGHLIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                Text(snapshot.highlight)
                    .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Label(snapshot.topCategory, systemImage: "square.grid.2x2")
                Label(snapshot.topVenue, systemImage: "mappin.and.ellipse")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 20)

            VStack(spacing: 9) {
                ForEach(snapshot.categories) { category in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: 9, height: 9)
                        Text(category.name)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(category.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
            }

            Spacer(minLength: 12)

            HStack {
                Text("Favoreco")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                Spacer()
                Text("MY EXPERIENCE ARCHIVE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .padding(24)
        .frame(width: 360, height: 450)
        .background(Color(red: 0.97, green: 0.97, blue: 0.95))
        .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.10))
    }

    private func imageMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct StatsReportActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StatsReportMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryStat: Identifiable {
    let category: RecordCategory
    let count: Int

    var id: UUID {
        category.id
    }
}

private struct MonthlyVisitStat: Identifiable {
    let month: Date
    let count: Int

    var id: Date { month }
}

private struct CategoryChartStat: Identifiable {
    let name: String
    let count: Int
    let color: Color

    var id: String { name }
}

private struct StatsMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(FavorecoTypography.jpSerif(30, weight: .bold, relativeTo: .largeTitle))
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CategoryStatRow: View {
    let stat: CategoryStat
    let maxCount: Int
    @Environment(\.favorecoThemePalette) private var themePalette

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(stat.count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(stat.category.name, systemImage: stat.category.iconSymbol)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(themePalette.categoryColor(hex: stat.category.colorHex))
                Spacer()
                Text("\(stat.count)")
                    .font(FavorecoTypography.bodyStrong)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                    Capsule()
                        .fill(themePalette.categoryColor(hex: stat.category.colorHex))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsWideCard: View {
    let title: String
    let value: String
    let caption: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(value)
                    .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                Text(caption)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsPrivateAmountCard: View {
    let title: String
    let value: String
    let isRevealed: Bool
    let caption: String
    let icon: String
    let onToggle: () -> Void

    private var displayValue: String {
        isRevealed ? value : "••••••"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "金額を隠す" : "金額を表示")
                }

                Text(displayValue)
                    .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                    .contentTransition(.numericText())
                    .privacySensitive(!isRevealed)

                Text(caption)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsReportPreviewCard: View {
    let title: String
    let badge: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                    Spacer()
                    Text(badge)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }

                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlaceholderRow: View {
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
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
