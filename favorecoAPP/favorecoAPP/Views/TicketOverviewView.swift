//
//  TicketOverviewView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import SwiftData

struct TicketOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var attempts: [TicketAttempt]
    @State private var selectedFilter: TicketOverviewFilter
    @State private var selectedCategoryID: UUID?
    @State private var groupingMode: TicketOverviewGroupingMode = .performance
    @State private var statusUpdateError = ""
    @State private var searchText = ""
    @State private var collapsedGroupKeys: Set<String> = []
    @State private var isShowingAddTicketPlan = false
    @State private var editingAttempt: TicketAttempt?
    @State private var quickActionAttempt: TicketAttempt?
    @State private var attemptPendingArchive: TicketAttempt?
    @State private var statusActionAttempt: TicketAttempt?
    @State private var schedulePlan: Plan?
    @State private var ticketDetailsPromptAttempt: TicketAttempt?
    @State private var pendingTicketDetailsStatusKey: String?
    @State private var finishesTicketDetailsPromptAfterEdit = false
    @State private var ticketDetailsEditAttemptID: UUID?
    @State private var pendingRevealAttemptID: UUID?
    @State private var highlightedAttemptID: UUID?
    let showsCloseButton: Bool

    init(
        showsCloseButton: Bool = false,
        initialFilter: TicketOverviewFilter = .needsAction
    ) {
        self.showsCloseButton = showsCloseButton
        _selectedFilter = State(initialValue: initialFilter)
    }

    private var activeAttempts: [TicketAttempt] {
        attempts.filter { !$0.isArchived && $0.plan?.isArchived != true }
    }

    private var individuallyArchivedAttempts: [TicketAttempt] {
        attempts.filter { $0.isArchived && $0.plan?.isArchived == false }
    }

    private var scopedAttempts: [TicketAttempt] {
        selectedFilter == .archived ? individuallyArchivedAttempts : activeAttempts
    }

    private var genreOptions: [TicketOverviewGenreOption] {
        var categoriesByID: [UUID: RecordCategory] = [:]
        for attempt in scopedAttempts {
            guard let category = category(for: attempt) else { continue }
            categoriesByID[category.id] = category
        }
        let sortedCategories = categoriesByID.values.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        var options: [TicketOverviewGenreOption] = []
        for category in sortedCategories {
            options.append(
                TicketOverviewGenreOption(
                    id: category.id,
                    title: category.name.isEmpty ? "未分類" : category.name,
                    colorHex: category.colorHex
                )
            )
        }
        return options
    }

    private var genreScopedAttempts: [TicketAttempt] {
        guard let selectedCategoryID else { return scopedAttempts }
        return scopedAttempts.filter { category(for: $0)?.id == selectedCategoryID }
    }

    private var filteredAttempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            searchedAttempts.filter(selectedFilter.includes)
        )
    }

    private var displayGroups: [TicketOverviewDisplayGroup] {
        switch groupingMode {
        case .performance:
            return applicationDisplayGroups
        case .deadline:
            return [
                TicketOverviewDisplayGroup(
                    id: "deadline-order",
                    title: "期限が近い順",
                    attempts: filteredAttempts
                ),
            ]
        case .progress:
            return groupedAttempts { attempt in
                progressGroup(for: attempt)
            }
            .sorted { progressGroupRank($0.id) < progressGroupRank($1.id) }
        }
    }

    private var applicationDisplayGroups: [TicketOverviewDisplayGroup] {
        var orderedKeys: [String] = []
        var attemptsByKey: [String: [TicketAttempt]] = [:]
        var titlesByKey: [String: String] = [:]

        for attempt in filteredAttempts {
            let rawGroupID = attempt.applicationGroupIDRaw
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = rawGroupID.isEmpty ? TicketOverviewDisplayGroup.ungroupedKey : rawGroupID
            if attemptsByKey[key] == nil {
                orderedKeys.append(key)
                attemptsByKey[key] = []
            }
            attemptsByKey[key, default: []].append(attempt)

            let groupName = attempt.applicationGroupName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !groupName.isEmpty, titlesByKey[key] == nil {
                titlesByKey[key] = groupName
            }
        }

        return orderedKeys.map { key in
            let groupedAttempts = attemptsByKey[key] ?? []
            return TicketOverviewDisplayGroup(
                id: key,
                title: key == TicketOverviewDisplayGroup.ungroupedKey
                    ? nil
                    : TicketApplicationCollectionNaming.displayName(
                        storedName: titlesByKey[key],
                        attempts: groupedAttempts
                    ),
                attempts: groupedAttempts
            )
        }
    }

    private func groupedAttempts(
        by keyAndTitle: (TicketAttempt) -> (key: String, title: String)
    ) -> [TicketOverviewDisplayGroup] {
        var orderedKeys: [String] = []
        var titlesByKey: [String: String] = [:]
        var attemptsByKey: [String: [TicketAttempt]] = [:]

        for attempt in filteredAttempts {
            let group = keyAndTitle(attempt)
            if attemptsByKey[group.key] == nil {
                orderedKeys.append(group.key)
                titlesByKey[group.key] = group.title
            }
            attemptsByKey[group.key, default: []].append(attempt)
        }

        return orderedKeys.map { key in
            TicketOverviewDisplayGroup(
                id: key,
                title: titlesByKey[key],
                attempts: attemptsByKey[key] ?? []
            )
        }
    }

    private func needsActionGroup(for attempt: TicketAttempt) -> (key: String, title: String) {
        if TicketInputIssueDefinition.issue(for: attempt) != nil {
            return ("input-required", "入力が必要")
        }
        guard let action = TicketNextActionDefinition.nextAction(for: attempt) else {
            if ["waitingIssue", "issued"].contains(attempt.statusKey),
               attempt.plan?.hasConfirmedSchedule == false {
                return ("schedule-undated", "参加日未定")
            }
            return ("other-action", "その他の対応")
        }

        let deadlineLabel = TicketProgressPresentation.deadlineLabel(
            forActionTitle: action.title,
            attempt: attempt
        )
        if deadlineLabel == "抽選当落" {
            return ("result-action", "当落確認")
        }
        if deadlineLabel == "チケ支払" {
            return ("payment-action", "支払")
        }
        if deadlineLabel == "チケ受取" || deadlineLabel == "チケ取得" {
            return ("acquired-action", "チケット受取")
        }
        if deadlineLabel == "チケ発売" {
            return ("sale-action", "発売・購入")
        }
        if deadlineLabel == "抽選申込" {
            return ("application-action", "抽選申込")
        }
        return ("other-action", "その他の対応")
    }

    private func progressGroup(for attempt: TicketAttempt) -> (key: String, title: String) {
        switch attempt.statusKey {
        case "lost":
            return ("progress-lost", "落選")
        case "skipped":
            return ("progress-skipped", "見送り")
        case "attended":
            return ("progress-attended", "参加済み")
        case "issued":
            return attempt.plan?.hasConfirmedSchedule == false
                ? ("progress-issued-undated", "受取済み・参加日未定")
                : ("progress-issued", "受取済み")
        default:
            break
        }
        guard let plan = attempt.plan else {
            return ("progress-other", "その他の進捗")
        }
        let stages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        let currentIndex = TicketProgressTimeline.currentIndex(for: attempt, stages: stages)
        guard stages.indices.contains(currentIndex) else {
            return ("progress-complete", "受取完了")
        }
        switch stages[currentIndex].kind {
        case .entry:
            return stages[currentIndex].title == "発売"
                ? ("progress-sale", "発売・購入")
                : ("progress-application", "抽選申込")
        case .result:
            return ("progress-result", "当落待ち")
        case .payment:
            return ("progress-payment", "支払")
        case .acquired:
            return ("progress-acquired", "チケット受取")
        }
    }

    private func progressGroupRank(_ id: String) -> Int {
        switch id {
        case "progress-application": 0
        case "progress-sale": 1
        case "progress-result": 2
        case "progress-payment": 3
        case "progress-acquired": 4
        case "progress-complete", "progress-issued-undated": 5
        case "progress-issued": 6
        case "progress-attended": 7
        case "progress-lost": 8
        case "progress-skipped": 9
        default: 10
        }
    }

    private var searchedAttempts: [TicketAttempt] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return genreScopedAttempts }

        return genreScopedAttempts.filter { attempt in
            let plan = attempt.plan
            let account = attempt.account
            let searchableText = [
                plan?.title ?? "",
                plan?.subtitle ?? "",
                plan?.venueNameSnapshot ?? "",
                plan?.organizerNameSnapshot ?? "",
                attempt.ticketSite,
                attempt.holderName,
                attempt.applicationGroupName,
                account?.serviceName ?? "",
                account?.accountName ?? "",
                TicketStatusDefinition.name(for: attempt.statusKey),
                TicketEntryRouteDefinition.name(for: attempt.entryRouteKey),
                TicketInputIssueDefinition.issue(for: attempt)?.title ?? "",
                TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames.joined(separator: " "),
                attempt.memo,
            ].joined(separator: " ")
            return searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                ticketManagementHeader

                List {
                    overviewControls
                        .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Rectangle()
                        .fill(TicketOverviewStyle.text.opacity(0.14))
                        .frame(height: 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if filteredAttempts.isEmpty {
                        Section {
                            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(spacing: 12) {
                                    FavorecoContentUnavailableView(
                                        selectedFilter.emptyTitle,
                                        systemImage: selectedFilter.systemImage,
                                        description: selectedFilter.emptyMessage
                                    )
                                    if selectedFilter != .archived {
                                        Button {
                                            isShowingAddTicketPlan = true
                                        } label: {
                                            FavorecoIconLabel("申込・発売を登録", systemImage: "plus", iconSize: 17)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            } else {
                                ContentUnavailableView.search(text: searchText)
                            }
                        } header: {
                            overviewSectionHeader(title: selectedFilter.title, count: 0)
                        }
                    } else {
                        ForEach(displayGroups) { group in
                            Section {
                                if !isGroupCollapsed(group) {
                                    ForEach(group.attempts) { attempt in
                                        ticketCardListRow(for: attempt)
                                    }
                                }
                            } header: {
                                collapsibleSectionHeader(for: group)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(TicketOverviewStyle.canvas)
            }
            .background(TicketOverviewStyle.canvas)
            .tint(TicketOverviewStyle.accent)
            .environment(\.colorScheme, .light)
            .preferredColorScheme(.light)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: genreOptions.map(\.id)) { _, categoryIDs in
                if let selectedCategoryID, !categoryIDs.contains(selectedCategoryID) {
                    self.selectedCategoryID = nil
                }
            }
            .sheet(isPresented: $isShowingAddTicketPlan) {
                AddTicketPlanView()
            }
            .sheet(item: $editingAttempt, onDismiss: finishTicketDetailsEditIfNeeded) { attempt in
                if let plan = attempt.plan {
                    EditTicketAttemptView(plan: plan, attempt: attempt)
                }
            }
            .sheet(item: $quickActionAttempt) { attempt in
                TicketQuickActionSheet(attempt: attempt) { updatedAttempt in
                    prepareToReveal(updatedAttempt)
                }
            }
            .sheet(item: $schedulePlan) { plan in
                TicketAttendanceScheduleSheet(plan: plan)
            }
            .ticketPostAcquisitionDetailsPrompt(
                attempt: $ticketDetailsPromptAttempt,
                onEdit: { attempt in
                    finishesTicketDetailsPromptAfterEdit = true
                    ticketDetailsEditAttemptID = attempt.id
                    editingAttempt = attempt
                },
                onLater: { attempt in
                    finishTicketDetailsPrompt(for: attempt)
                }
            )
            .confirmationDialog(
                "チケットの状態を更新",
                isPresented: Binding(
                    get: { statusActionAttempt != nil },
                    set: { if !$0 { statusActionAttempt = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let attempt = statusActionAttempt {
                    ForEach(TicketStatusTransitionDefinition.transitions(for: attempt)) { transition in
                        Button(transition.title) {
                            updateStatus(attempt, to: transition.targetStatusKey)
                            statusActionAttempt = nil
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {
                    statusActionAttempt = nil
                }
            }
            .confirmationDialog(
                "この申込を非表示にしますか？",
                isPresented: Binding(
                    get: { attemptPendingArchive != nil },
                    set: { if !$0 { attemptPendingArchive = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("申込を非表示", role: .destructive) {
                    archivePendingAttempt()
                }
                Button("キャンセル", role: .cancel) {
                    attemptPendingArchive = nil
                }
            } message: {
                Text("予定本体と他の申込は残り、この申込の予約済み通知だけを解除します。")
            }
            .alert("状態を更新できませんでした", isPresented: Binding(
                get: { !statusUpdateError.isEmpty },
                set: { if !$0 { statusUpdateError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusUpdateError)
            }
            .onChange(of: quickActionAttempt?.id) { previousID, currentID in
                guard previousID != nil, currentID == nil else { return }
                revealPendingAttempt(using: scrollProxy)
            }
        }
    }

    private var ticketManagementHeader: some View {
        ZStack {
            Text("チケット管理")
                .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(TicketOverviewStyle.text)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: showsCloseButton ? "xmark" : "chevron.left")
                        .font(.system(size: showsCloseButton ? 23 : 21, weight: .medium))
                        .foregroundStyle(TicketOverviewStyle.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsCloseButton ? "閉じる" : "戻る")

                Spacer(minLength: 0)

                Button {
                    isShowingAddTicketPlan = true
                } label: {
                    Label("チケットを追加", systemImage: "plus")
                        .font(FavorecoTypography.jpSans(11.5, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(TicketOverviewStyle.editorAccent)
                        .padding(.horizontal, 7)
                        .frame(height: 44)
                        .background(TicketOverviewStyle.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(TicketOverviewStyle.editorAccent.opacity(0.74), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("チケットを追加")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(TicketOverviewStyle.surface)
    }

    private var overviewControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            TicketOverviewSearchField(text: $searchText)

            VStack(alignment: .leading, spacing: 9) {
                controlLabel("対応状況")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TicketOverviewFilter.allCases) { filter in
                            filterButton(filter)
                        }
                    }
                }
            }

            if !genreOptions.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    controlLabel("ジャンル")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            genreButton(
                                title: "すべて",
                                categoryID: nil,
                                tint: TicketOverviewStyle.editorAccent
                            )
                            ForEach(genreOptions) { option in
                                genreButton(
                                    title: option.title,
                                    categoryID: option.id,
                                    tint: themeColor(for: option)
                                )
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                groupingMenu
            }
            .frame(minHeight: 38)
        }
    }

    private func controlLabel(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
            .foregroundStyle(TicketOverviewStyle.text)
    }

    private func category(for attempt: TicketAttempt) -> RecordCategory? {
        attempt.plan?.category ?? attempt.plan?.event?.category
    }

    private func overviewSectionHeader(
        title: String,
        count: Int,
        tint: Color = TicketOverviewStyle.text
    ) -> some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(tint)
                .textCase(nil)
            Spacer()
            Text("\(count)件")
                .font(FavorecoTypography.caption)
                .foregroundStyle(tint.opacity(0.86))
                .textCase(nil)
        }
    }

    private func collapsibleSectionHeader(for group: TicketOverviewDisplayGroup) -> some View {
        let title = group.headerTitle(
            fallback: selectedFilter.title,
            showsIndividualLabel: groupingMode == .performance
                && applicationDisplayGroups.count > 1
        )
        let tint = groupHeaderTint(for: group)
        let isCollapsed = isGroupCollapsed(group)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                toggleGroup(group)
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(tint)
                    .textCase(nil)
                Spacer()
                Text("\(group.attempts.count)件")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(tint.opacity(0.86))
                    .textCase(nil)
                FavorecoIcon(
                    systemName: isCollapsed ? "chevron.right" : "chevron.down",
                    size: 13
                )
                .foregroundStyle(tint)
                .frame(width: 20, height: 28)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue("\(group.attempts.count)件、\(isCollapsed ? "閉じています" : "開いています")")
        .accessibilityHint(isCollapsed ? "ダブルタップで開きます" : "ダブルタップで閉じます")
    }

    private func isGroupCollapsed(_ group: TicketOverviewDisplayGroup) -> Bool {
        collapsedGroupKeys.contains(groupCollapseKey(group))
    }

    private func toggleGroup(_ group: TicketOverviewDisplayGroup) {
        let key = groupCollapseKey(group)
        if collapsedGroupKeys.contains(key) {
            collapsedGroupKeys.remove(key)
        } else {
            collapsedGroupKeys.insert(key)
        }
    }

    private func groupCollapseKey(_ group: TicketOverviewDisplayGroup) -> String {
        "\(groupingMode.rawValue)::\(group.id)"
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(TicketOverviewGroupingMode.allCases) { mode in
                Button {
                    groupingMode = mode
                } label: {
                    Label(mode.title, systemImage: groupingMode == mode ? "checkmark" : mode.systemImage)
                }
            }
        } label: {
            HStack(spacing: 6) {
                FavorecoIcon(systemName: groupingMode.systemImage, size: 14)
                Text(groupingMode.title)
                FavorecoIcon(systemName: "chevron.down", size: 10)
            }
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(TicketOverviewStyle.editorAccent)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(TicketOverviewStyle.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(TicketOverviewStyle.editorAccent.opacity(0.42), lineWidth: 1)
            }
        }
        .accessibilityLabel("表示方法")
        .accessibilityValue(groupingMode.title)
    }

    private func groupHeaderTint(for group: TicketOverviewDisplayGroup) -> Color {
        switch group.id {
        case "input-required":
            return TicketProgressColorPalette.warning
        case "schedule-undated":
            return TicketProgressColorPalette.scheduleUndated
        case "application-action", "progress-application":
            if group.title?.contains("発売") == true {
                return TicketProgressColorPalette.color(for: .sale)
            }
            return TicketProgressColorPalette.color(for: .application)
        case "sale-action", "progress-sale":
            return TicketProgressColorPalette.color(for: .sale)
        case "result-action", "progress-result":
            return TicketProgressColorPalette.color(for: .result)
        case "payment-action", "progress-payment":
            return TicketProgressColorPalette.color(for: .payment)
        case "progress-issued-undated":
            return TicketProgressColorPalette.scheduleUndated
        case "acquired-action", "progress-acquired", "progress-complete",
             "progress-issued", "progress-attended", "schedule-confirmed":
            return TicketProgressColorPalette.color(for: .acquired)
        case "progress-lost", "progress-skipped":
            return TicketOverviewStyle.closeAction
        default:
            return selectedFilter == .acquired
                ? TicketProgressColorPalette.color(for: .acquired)
                : TicketOverviewStyle.text
        }
    }

    private func ticketCardListRow(for attempt: TicketAttempt) -> some View {
        ticketCard(for: attempt)
            .id(attempt.id)
            .overlay {
                if highlightedAttemptID == attempt.id {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TicketOverviewStyle.accent, lineWidth: 2)
                        .padding(-2)
                        .allowsHitTesting(false)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func ticketCard(for attempt: TicketAttempt) -> some View {
        if attempt.isArchived {
            TicketOverviewRow(attempt: attempt)
                .contextMenu {
                    Button {
                        restore(attempt)
                    } label: {
                        Label("申込を再表示", systemImage: "arrow.uturn.left.circle")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        restore(attempt)
                    } label: {
                        Label("再表示", systemImage: "arrow.uturn.left")
                            .foregroundStyle(Color.white)
                    }
                    .tint(TicketOverviewStyle.advanceAction)
                }
        } else if attempt.plan != nil {
            Button {
                quickActionAttempt = attempt
            } label: {
                TicketOverviewRow(attempt: attempt)
            }
            .buttonStyle(.plain)
            .contextMenu {
                statusTransitionMenu(for: attempt)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    statusActionAttempt = attempt
                } label: {
                    Label("進める", systemImage: "arrow.right")
                        .foregroundStyle(Color.white)
                }
                .tint(TicketOverviewStyle.advanceAction)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    close(attempt)
                } label: {
                    Label(
                        attempt.statusKey == "waitingResult" ? "落選" : "見送り",
                        systemImage: "xmark"
                    )
                    .foregroundStyle(Color.white)
                }
                .tint(TicketOverviewStyle.closeAction)
                Button {
                    editingAttempt = attempt
                } label: {
                    Label("編集", systemImage: "pencil")
                        .foregroundStyle(Color.white)
                }
                .tint(TicketOverviewStyle.editAction)
            }
            .accessibilityHint(
                "右へスワイプすると状態を進め、左へスワイプすると編集または見送りにできます"
            )
        } else {
            TicketOverviewRow(attempt: attempt)
        }
    }

    private func count(for filter: TicketOverviewFilter) -> Int {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseAttempts = filter == .archived ? individuallyArchivedAttempts : activeAttempts
        return baseAttempts.filter { attempt in
            if let selectedCategoryID, category(for: attempt)?.id != selectedCategoryID {
                return false
            }
            guard filter.includes(attempt) else { return false }
            guard !query.isEmpty else { return true }
            return matchesSearch(attempt, query: query)
        }.count
    }

    private func matchesSearch(_ attempt: TicketAttempt, query: String) -> Bool {
        let plan = attempt.plan
        let account = attempt.account
        let searchableText = [
            plan?.title ?? "",
            plan?.subtitle ?? "",
            plan?.venueNameSnapshot ?? "",
            plan?.organizerNameSnapshot ?? "",
            attempt.ticketSite,
            attempt.holderName,
            attempt.applicationGroupName,
            account?.serviceName ?? "",
            account?.accountName ?? "",
            TicketStatusDefinition.name(for: attempt.statusKey),
            TicketEntryRouteDefinition.name(for: attempt.entryRouteKey),
            TicketInputIssueDefinition.issue(for: attempt)?.title ?? "",
            TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames.joined(separator: " "),
            attempt.memo,
        ].joined(separator: " ")
        return searchableText.localizedCaseInsensitiveContains(query)
    }

    private func filterButton(_ filter: TicketOverviewFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 5) {
                Text(filter.title)
                Text("\(count(for: filter))")
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : .secondary)
            }
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(isSelected ? Color.white : TicketOverviewStyle.text)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                isSelected ? TicketOverviewStyle.editorAccent : TicketOverviewStyle.surface,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(TicketOverviewStyle.text.opacity(0.18), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func genreButton(title: String, categoryID: UUID?, tint: Color) -> some View {
        let isSelected = selectedCategoryID == categoryID
        return Button {
            selectedCategoryID = categoryID
        } label: {
            Text(title)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(isSelected ? Color.white : tint)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    isSelected ? tint : TicketOverviewStyle.surface,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(tint.opacity(isSelected ? 0 : 0.34), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func themeColor(for option: TicketOverviewGenreOption) -> Color {
        Color(hex: option.colorHex)
    }

    @ViewBuilder
    private func statusTransitionMenu(for attempt: TicketAttempt) -> some View {
        let transitions = TicketStatusTransitionDefinition.transitions(for: attempt)
        if transitions.isEmpty {
            Text("変更できる状態はありません")
        } else {
            ForEach(transitions) { transition in
                Button {
                    updateStatus(attempt, to: transition.targetStatusKey)
                } label: {
                    FavorecoIconLabel(transition.title, systemImage: transition.systemImage)
                }
            }
        }
    }

    private func updateStatus(_ attempt: TicketAttempt, to statusKey: String) {
        do {
            try TicketAttemptStatusUpdater.update(
                attempt: attempt,
                to: statusKey,
                in: modelContext
            )
            if TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: statusKey
            ) {
                pendingTicketDetailsStatusKey = statusKey
                DispatchQueue.main.async {
                    ticketDetailsPromptAttempt = attempt
                }
                return
            }
            finishStatusUpdate(attempt, statusKey: statusKey)
        } catch {
            statusUpdateError = error.localizedDescription
        }
    }

    private func finishTicketDetailsEditIfNeeded() {
        guard finishesTicketDetailsPromptAfterEdit else { return }
        finishesTicketDetailsPromptAfterEdit = false
        guard let attemptID = ticketDetailsEditAttemptID,
              let attempt = attempts.first(where: { $0.id == attemptID }) else {
            ticketDetailsEditAttemptID = nil
            pendingTicketDetailsStatusKey = nil
            return
        }
        ticketDetailsEditAttemptID = nil
        finishTicketDetailsPrompt(for: attempt)
    }

    private func finishTicketDetailsPrompt(for attempt: TicketAttempt) {
        ticketDetailsPromptAttempt = nil
        guard let statusKey = pendingTicketDetailsStatusKey else { return }
        pendingTicketDetailsStatusKey = nil
        finishStatusUpdate(attempt, statusKey: statusKey)
    }

    private func finishStatusUpdate(_ attempt: TicketAttempt, statusKey: String) {
            if TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: statusKey,
                plan: attempt.plan
            ), let plan = attempt.plan {
                DispatchQueue.main.async {
                    schedulePlan = plan
                }
            }
    }

    private func prepareToReveal(_ attempt: TicketAttempt) {
        if !selectedFilter.includes(attempt) {
            selectedFilter = .all
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty, !matchesSearch(attempt, query: query) {
            searchText = ""
        }
        pendingRevealAttemptID = attempt.id
    }

    private func revealPendingAttempt(using proxy: ScrollViewProxy) {
        guard let attemptID = pendingRevealAttemptID else { return }
        pendingRevealAttemptID = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(attemptID, anchor: .center)
            }
            highlightedAttemptID = attemptID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if highlightedAttemptID == attemptID {
                    withAnimation(.easeOut(duration: 0.2)) {
                        highlightedAttemptID = nil
                    }
                }
            }
        }
    }

    private func close(_ attempt: TicketAttempt) {
        updateStatus(
            attempt,
            to: attempt.statusKey == "waitingResult" ? "lost" : "skipped"
        )
    }

    private func archivePendingAttempt() {
        guard let attempt = attemptPendingArchive else { return }
        do {
            try TicketAttemptStatusUpdater.archive(
                attempt: attempt,
                in: modelContext
            )
            attemptPendingArchive = nil
        } catch {
            attemptPendingArchive = nil
            statusUpdateError = error.localizedDescription
        }
    }

    private func restore(_ attempt: TicketAttempt) {
        do {
            try TicketAttemptStatusUpdater.restore(
                attempt: attempt,
                in: modelContext
            )
        } catch {
            statusUpdateError = error.localizedDescription
        }
    }

}

private enum TicketOverviewStyle {
    static let canvas = Color.white
    static let surface = Color.white
    static let accent = Color(hex: "#B04464")
    static let editorAccent = Color(hex: "#8B2F45")
    static let text = Color(hex: "#302A2D")
    static let secondaryText = Color(hex: "#746B70")
    static let advanceAction = Color(hex: "#2F9FB0")
    static let editAction = Color(hex: "#578BC2")
    static let closeAction = Color(hex: "#D65C7A")
}

private enum TicketOverviewGroupingMode: String, CaseIterable, Identifiable {
    case performance
    case deadline
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .performance: "公演ごと"
        case .deadline: "期限が近い順"
        case .progress: "進捗ごと"
        }
    }

    var systemImage: String {
        switch self {
        case .performance: "rectangle.3.group"
        case .deadline: "calendar.badge.clock"
        case .progress: "chart.bar.xaxis"
        }
    }
}

enum TicketOverviewFilter: String, CaseIterable, Identifiable {
    case all
    case needsAction
    case undated
    case planning
    case acquired
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .needsAction: "要対応"
        case .undated: "参加日未定"
        case .planning: "進行中"
        case .acquired: "受取済み"
        case .completed: "終了"
        case .archived: "非表示"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "ticket"
        case .needsAction: "bell.badge"
        case .undated: "calendar.badge.exclamationmark"
        case .planning: "hourglass"
        case .acquired: "ticket.fill"
        case .completed: "checkmark.circle"
        case .archived: "archivebox"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "チケット情報はありません"
        case .needsAction: "対応が必要なチケットはありません"
        case .undated: "参加日未定のチケットはありません"
        case .planning: "進行中のチケットはありません"
        case .acquired: "受取済みのチケットはありません"
        case .completed: "終了したチケットはありません"
        case .archived: "非表示のチケットはありません"
        }
    }

    var emptyMessage: String {
        switch self {
        case .needsAction:
            "申込締切、当落発表、支払締切、チケット受取開始が近づくとここに表示されます。"
        case .undated:
            "参加日が決まったチケットは Coming Up に表示されます。"
        case .archived:
            "個別に非表示にした申込を、ここから再表示できます。"
        default:
            "右上の「チケットを追加」または下部の「追加」から、申込・発売を登録できます。"
        }
    }

    func includes(_ attempt: TicketAttempt) -> Bool {
        switch self {
        case .all:
            return true
        case .needsAction:
            return TicketNextActionDefinition.nextAction(for: attempt) != nil
                || TicketInputIssueDefinition.issue(for: attempt) != nil
                || [
                    "beforeApply", "onSaleSoon", "waitingResult",
                    "won", "waitingPayment", "waitingIssue",
                ].contains(attempt.statusKey)
                || (["waitingIssue", "issued"].contains(attempt.statusKey)
                    && attempt.plan?.hasConfirmedSchedule == false)
        case .undated:
            return attempt.plan?.hasConfirmedSchedule == false
                && !["interested", "lost", "attended", "skipped"].contains(attempt.statusKey)
        case .planning:
            return [
                "interested", "beforeApply", "onSaleSoon",
                "waitingResult", "won", "waitingPayment",
            ].contains(attempt.statusKey)
        case .acquired:
            return ["waitingIssue", "issued"].contains(attempt.statusKey)
        case .completed:
            return ["lost", "attended", "skipped"].contains(attempt.statusKey)
        case .archived:
            return attempt.isArchived
        }
    }
}

private struct TicketOverviewGenreOption: Identifiable {
    let id: UUID
    let title: String
    let colorHex: String

    nonisolated init(id: UUID, title: String, colorHex: String) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
    }
}

private struct TicketOverviewDisplayGroup: Identifiable {
    static let ungroupedKey = "__ungrouped__"

    let id: String
    let title: String?
    let attempts: [TicketAttempt]

    func headerTitle(fallback: String, showsIndividualLabel: Bool) -> String {
        if let title, !title.isEmpty {
            return title
        }
        return showsIndividualLabel ? "個別の申込" : fallback
    }
}

private struct TicketOverviewSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            FavorecoIcon(systemName: "magnifyingglass", size: 17)
                .foregroundStyle(.secondary)

            TextField("公演名・申込先・プレイガイドを検索", text: $text)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索文字を消去")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            TicketOverviewStyle.surface,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(TicketOverviewStyle.text.opacity(0.20), lineWidth: 1)
        }
    }
}

private enum TicketOverviewCardGeometry {
    static let cornerCut: CGFloat = 18
}

private struct TicketOverviewCardShape: Shape {
    private let cornerCut = TicketOverviewCardGeometry.cornerCut
    private let notchDepth: CGFloat = 8
    private let notchHalfHeight: CGFloat = 8
    private let notchCenterY: CGFloat = 104
    private let circleControlRatio: CGFloat = 0.552_284_8

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerY = min(max(cornerCut + notchHalfHeight, notchCenterY), height - cornerCut - notchHalfHeight)
        var path = Path()

        path.move(to: CGPoint(x: cornerCut, y: 0))
        path.addLine(to: CGPoint(x: width - cornerCut, y: 0))
        path.addLine(to: CGPoint(x: width, y: cornerCut))
        path.addLine(to: CGPoint(x: width, y: centerY - notchHalfHeight))
        path.addCurve(
            to: CGPoint(x: width - notchDepth, y: centerY),
            control1: CGPoint(x: width - notchDepth * circleControlRatio, y: centerY - notchHalfHeight),
            control2: CGPoint(x: width - notchDepth, y: centerY - notchHalfHeight * circleControlRatio)
        )
        path.addCurve(
            to: CGPoint(x: width, y: centerY + notchHalfHeight),
            control1: CGPoint(x: width - notchDepth, y: centerY + notchHalfHeight * circleControlRatio),
            control2: CGPoint(x: width - notchDepth * circleControlRatio, y: centerY + notchHalfHeight)
        )
        path.addLine(to: CGPoint(x: width, y: height - cornerCut))
        path.addLine(to: CGPoint(x: width - cornerCut, y: height))
        path.addLine(to: CGPoint(x: cornerCut, y: height))
        path.addLine(to: CGPoint(x: 0, y: height - cornerCut))
        path.addLine(to: CGPoint(x: 0, y: centerY + notchHalfHeight))
        path.addCurve(
            to: CGPoint(x: notchDepth, y: centerY),
            control1: CGPoint(x: notchDepth * circleControlRatio, y: centerY + notchHalfHeight),
            control2: CGPoint(x: notchDepth, y: centerY + notchHalfHeight * circleControlRatio)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: centerY - notchHalfHeight),
            control1: CGPoint(x: notchDepth, y: centerY - notchHalfHeight * circleControlRatio),
            control2: CGPoint(x: notchDepth * circleControlRatio, y: centerY - notchHalfHeight)
        )
        path.addLine(to: CGPoint(x: 0, y: cornerCut))
        path.closeSubpath()
        return path
    }
}

private struct TicketOverviewPerforation: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 8, y: 0.5))
                path.addLine(to: CGPoint(x: max(8, proxy.size.width - 8), y: 0.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
        .allowsHitTesting(false)
    }
}

private struct TicketOverviewRow: View {
    let attempt: TicketAttempt

    private var plan: Plan? { attempt.plan }
    private var nextAction: TicketNextActionDefinition? {
        TicketNextActionDefinition.nextAction(for: attempt)
    }
    private var inputIssue: TicketInputIssueDefinition? {
        TicketInputIssueDefinition.issue(for: attempt)
    }
    private var categoryColor: Color {
        Color(hex: category?.colorHex ?? "#147C88")
    }
    private var category: RecordCategory? {
        plan?.category ?? plan?.event?.category
    }
    private var thumbnailReference: ThumbnailReference? {
        plan?.event.map { .event($0.id) }
    }
    private var stages: [TicketProgressStage] {
        guard let plan else { return [] }
        return TicketProgressTimeline.stages(for: attempt, plan: plan)
    }
    private var currentStageIndex: Int {
        TicketProgressTimeline.currentIndex(for: attempt, stages: stages)
    }
    private var primaryTransition: TicketStatusTransitionDefinition? {
        TicketStatusTransitionDefinition.transitions(for: attempt).first {
            !["lost", "skipped"].contains($0.targetStatusKey)
        }
    }
    private var actionTitle: String? {
        if let nextAction { return taskTitle(for: nextAction) }
        if let inputIssue { return inputIssue.title }
        if ["waitingIssue", "issued"].contains(attempt.statusKey),
           plan?.hasConfirmedSchedule == false {
            return "参加日を設定"
        }
        return primaryTransition?.title
    }
    private var actionSystemImage: String {
        nextAction?.systemImage
            ?? inputIssue?.systemImage
            ?? (plan?.hasConfirmedSchedule == false ? "calendar.badge.plus" : primaryTransition?.systemImage)
            ?? "checkmark.circle"
    }
    private var actionDate: Date? {
        nextAction?.date
    }
    private var entryRouteBadgeTitle: String? {
        let title = TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
    private var ticketSiteBadgeTitle: String? {
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
        if ["waitingIssue", "issued", "attended"].contains(attempt.statusKey) {
            return "チケ受取"
        }
        let source = nextAction?.title ?? inputIssue?.title ?? actionTitle ?? ""
        let resolvedLabel = TicketProgressPresentation.deadlineLabel(
            forActionTitle: source,
            attempt: attempt
        )
        if TicketProgressColorPalette.visualStage(forDeadlineLabel: resolvedLabel) != nil {
            return resolvedLabel
        }
        if stages.indices.contains(currentStageIndex) {
            let stage = stages[currentStageIndex]
            return switch stage.kind {
            case .entry: stage.title == "発売" ? "チケ発売" : "抽選申込"
            case .result: "抽選当落"
            case .payment: "チケ支払"
            case .acquired: "チケ受取"
            }
        }
        return "チケット"
    }
    private var terminalHeadline: String? {
        switch attempt.statusKey {
        case "issued": "受取済み"
        case "attended": "参加済み"
        case "lost": "落選"
        case "skipped": "見送り"
        default: nil
        }
    }
    private var deadlineStatusColor: Color {
        guard let visualStage = TicketProgressColorPalette.visualStage(
            forDeadlineLabel: deadlineLabel
        ) else { return categoryColor }
        return TicketProgressColorPalette.color(for: visualStage)
    }
    private var cardSurfaceColor: Color {
        TicketProgressColorPalette.surface(
            forDeadlineLabel: deadlineLabel,
            fallback: TicketOverviewStyle.surface
        )
    }
    private var cardTextColor: Color {
        TicketProgressColorPalette.text(
            forDeadlineLabel: deadlineLabel,
            fallback: TicketOverviewStyle.text
        )
    }
    private func taskTitle(for action: TicketNextActionDefinition) -> String {
        switch action.title {
        case "申込・発売開始":
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "抽選に申し込む" : "チケットを購入する"
        case "申込締切":
            return "抽選に申し込む"
        case "申込締切超過":
            return "申込状況を確認"
        case "当落発表", "当落を確認":
            return "当落結果を入力"
        case "支払締切", "入金締切":
            return "支払を完了する"
        case "支払期限超過", "入金期限超過":
            return "支払状況を更新"
        case "チケット受取開始", "チケットを受け取る":
            return "チケットを受け取る"
        case "発売開始済み":
            return "購入状況を確認"
        default:
            return action.title
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 4) {
                    VStack(spacing: 4) {
                        overviewBadge(deadlineLabel, color: deadlineStatusColor)

                        CategoryEyecatchArtwork(
                            reference: thumbnailReference,
                            templateKey: category?.templateKey ?? "",
                            backgroundColor: TicketOverviewStyle.surface
                        ) { size in
                            CategoryDefaultArtworkImage(
                                templateKey: category?.templateKey ?? "",
                                displaySize: size
                            )
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .frame(width: 64)

                    TicketOverviewDeadlineBlock(
                        date: actionDate,
                        requiresInput: inputIssue != nil,
                        isAttendanceUndated: actionTitle == "参加日を設定",
                        isOverdue: nextAction?.isOverdue == true,
                        fallbackHeadline: terminalHeadline,
                        textColor: cardTextColor,
                        secondaryTextColor: cardTextColor.opacity(0.72)
                    )
                    .frame(width: 70)

                    Rectangle()
                        .fill(cardTextColor.opacity(0.14))
                        .frame(width: 1, height: 84)
                        .padding(.trailing, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if let entryRouteBadgeTitle {
                                overviewMetadataBadge(entryRouteBadgeTitle, role: .entryRoute)
                            }
                            if let ticketSiteBadgeTitle {
                                overviewMetadataBadge(ticketSiteBadgeTitle, role: .ticketSite)
                            }
                            if entryRouteBadgeTitle == nil, ticketSiteBadgeTitle == nil {
                                overviewMetadataBadge("チケット", role: .entryRoute)
                            }
                            Spacer(minLength: 0)
                        }

                        Text(plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定")
                            .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(cardTextColor)
                            .lineLimit(2, reservesSpace: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let plan {
                            FavorecoIconLabel(
                                plan.hasConfirmedSchedule
                                    ? FavorecoDateText.compactDateTime(plan.startsAt)
                                    : "参加日未定",
                                systemImage: plan.hasConfirmedSchedule
                                    ? "calendar"
                                    : "calendar.badge.exclamationmark",
                                iconSize: 16
                            )
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(
                                plan.hasConfirmedSchedule
                                    ? cardTextColor.opacity(0.72)
                                    : TicketProgressColorPalette.scheduleUndated
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(cardTextColor.opacity(0.58))
                        .frame(minHeight: 84)
                }
                .frame(height: 88)
                .padding(8)
                .background(cardSurfaceColor)

                if !stages.isEmpty {
                    TicketProgressTimelineView(
                        stages: stages,
                        currentIndex: currentStageIndex,
                        nodeBackground: TicketOverviewStyle.surface,
                        secondaryTextColor: TicketOverviewStyle.secondaryText,
                        currentTint: deadlineStatusColor,
                        completedTint: TicketProgressColorPalette.completedNeutral,
                        nodeDiameter: 30,
                        nodeTextSize: 8,
                        emphasizesCurrentDate: true
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 7)
                    .padding(.bottom, 7)
                    .background(TicketOverviewStyle.surface)
                    .overlay(alignment: .top) {
                        TicketOverviewPerforation(
                            color: deadlineStatusColor.opacity(0.34)
                        )
                    }
                }

                TicketOverviewNextActionRow(
                    actionTitle: actionTitle,
                    fallbackTitle: TicketStatusDefinition.name(for: attempt.statusKey),
                    systemImage: actionSystemImage,
                    actionDate: actionDate,
                    isOverdue: nextAction?.isOverdue == true,
                    normalColor: cardTextColor
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(TicketOverviewStyle.surface)
        }
        .background(TicketOverviewStyle.surface)
        .clipShape(TicketOverviewCardShape())
        .overlay {
            TicketOverviewCardShape()
                .stroke(deadlineStatusColor.opacity(0.46), lineWidth: 1)
        }
        .contentShape(TicketOverviewCardShape())
        .accessibilityElement(children: .combine)
    }

    private func overviewBadge(_ title: String, color: Color) -> some View {
        return Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func overviewMetadataBadge(_ title: String, role: TicketOverviewMetadataRole) -> some View {
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
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
                TicketProgressColorPalette.metadataChipSurface.opacity(0.86),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(border.opacity(role == .entryRoute ? 0.78 : 0.24), lineWidth: 0.7)
            }
    }
}

private enum TicketOverviewMetadataRole {
    case entryRoute
    case ticketSite
}

private struct TicketOverviewDeadlineBlock: View {
    let date: Date?
    let requiresInput: Bool
    let isAttendanceUndated: Bool
    let isOverdue: Bool
    let fallbackHeadline: String?
    let textColor: Color
    let secondaryTextColor: Color

    private var daysRemaining: Int? {
        guard let date else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day
    }

    private var hasExpired: Bool {
        isOverdue || (date.map { $0 < Date() } == true)
    }

    private var emphasisColor: Color {
        if isAttendanceUndated {
            return TicketProgressColorPalette.scheduleUndated
        }
        return hasExpired ? TicketProgressColorPalette.warning : textColor
    }

    private var imminentUrgencyColor: Color? {
        guard !hasExpired else { return nil }
        switch daysRemaining {
        case 0: return Color(hex: "#E43D4C")
        case 1: return Color(hex: "#D8555F")
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            if let daysRemaining, daysRemaining >= 2, !hasExpired {
                HStack(alignment: .center, spacing: 1) {
                    VStack(spacing: -4) {
                        Text("あ")
                        Text("と")
                    }
                    .font(FavorecoTypography.jpSerif(9, weight: .semibold, relativeTo: .caption2))

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(daysRemaining)")
                            .font(FavorecoTypography.latinDisplay(30, weight: .bold, relativeTo: .title2))
                            .monospacedDigit()
                        Text("日")
                            .font(FavorecoTypography.jpSerif(9, weight: .semibold, relativeTo: .caption2))
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 38)
            } else {
                Text(deadlineHeadline)
                    .font(FavorecoTypography.jpSerif(
                        hasExpired ? 13 : 17,
                        weight: .bold,
                        relativeTo: .headline
                    ))
                    .multilineTextAlignment(.center)
                    .lineLimit(hasExpired ? 2 : 1)
                    .minimumScaleFactor(0.72)
                    .frame(height: 38)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(imminentUrgencyColor ?? emphasisColor)
            }

            if let date {
                Text(FavorecoDateText.compactDate(date))
                    .font(FavorecoTypography.jpSerif(11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                Text(FavorecoDateText.time(date))
                    .font(FavorecoTypography.latinDisplay(12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(secondaryTextColor)
                    .monospacedDigit()
                    .lineLimit(1)
            } else {
                Text(
                    fallbackHeadline != nil
                        ? "—"
                        : (isAttendanceUndated ? "日程を入力" : "期限を入力")
                )
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(
                        fallbackHeadline != nil
                            ? secondaryTextColor
                            : isAttendanceUndated
                                ? TicketProgressColorPalette.scheduleUndated
                            : TicketProgressColorPalette.warning
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .foregroundStyle(emphasisColor)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var deadlineHeadline: String {
        if let fallbackHeadline { return fallbackHeadline }
        if isAttendanceUndated { return "未定" }
        if requiresInput || date == nil { return "要確認" }
        if hasExpired { return "期限超過" }
        switch daysRemaining {
        case 0: return "今日"
        case 1: return "明日"
        default: return "要確認"
        }
    }
}

private struct TicketOverviewNextActionRow: View {
    let actionTitle: String?
    let fallbackTitle: String
    let systemImage: String
    let actionDate: Date?
    let isOverdue: Bool
    let normalColor: Color

    private var urgencyColor: Color {
        if isOverdue || (actionDate.map { $0 < Date() } == true) {
            return TicketProgressColorPalette.warning
        }
        if actionDate == nil { return TicketProgressColorPalette.warning }
        return normalColor
    }

    var body: some View {
        HStack(spacing: 8) {
            FavorecoIcon(systemName: systemImage, size: 17)
                .foregroundStyle(urgencyColor)
                .frame(width: 28, height: 28)
                .background(urgencyColor.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(actionTitle == nil ? "現在の状態" : "次にやること")
                    .font(FavorecoTypography.jpSans(8, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(TicketOverviewStyle.text.opacity(0.72))

                Text(actionTitle ?? fallbackTitle)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(urgencyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 6)

            if let actionDate {
                Text(FavorecoDateText.compactDateTime(actionDate))
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(urgencyColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.top, 7)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
        }
    }
}
