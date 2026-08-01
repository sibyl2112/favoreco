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
    @State private var selectedFilter: TicketOverviewFilter = .needsAction
    @State private var selectedCategoryID: UUID?
    @State private var statusUpdateError = ""
    @State private var searchText = ""
    @State private var isShowingAddTicketPlan = false
    @State private var editingAttempt: TicketAttempt?
    @State private var quickActionAttempt: TicketAttempt?
    @State private var attemptPendingArchive: TicketAttempt?
    @State private var statusActionAttempt: TicketAttempt?
    @State private var schedulePlan: Plan?
    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
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
        switch selectedFilter {
        case .all:
            return applicationDisplayGroups
        case .needsAction:
            return groupedAttempts { attempt in
                needsActionGroup(for: attempt)
            }
        case .planning:
            return groupedAttempts { attempt in
                progressGroup(for: attempt)
            }
        case .acquired:
            return groupedAttempts { attempt in
                attempt.plan?.hasConfirmedSchedule == true
                    ? ("schedule-confirmed", "参加日確定")
                    : ("schedule-undated", "参加日未定")
            }
        case .completed:
            return groupedAttempts { attempt in
                let title = TicketStatusDefinition.name(for: attempt.statusKey)
                return ("completed-\(attempt.statusKey)", title)
            }
        case .archived:
            return [
                TicketOverviewDisplayGroup(
                    id: "archived",
                    title: "非表示の申込",
                    attempts: filteredAttempts
                ),
            ]
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

        if action.title.contains("当落") {
            return ("result-action", "当落確認")
        }
        if action.title.contains("入金") || action.title.contains("支払") {
            return ("payment-action", "入金・支払")
        }
        if action.title.contains("受取") || action.title.contains("取得") {
            return ("acquired-action", "チケット取得")
        }
        if action.title.contains("発売") {
            return ("sale-action", "発売・購入")
        }
        if action.title.contains("申込") {
            return ("application-action", "抽選申込")
        }
        return ("other-action", "その他の対応")
    }

    private func progressGroup(for attempt: TicketAttempt) -> (key: String, title: String) {
        guard let plan = attempt.plan else {
            return ("progress-other", "その他の進捗")
        }
        let stages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        let currentIndex = TicketProgressTimeline.currentIndex(for: attempt, stages: stages)
        guard stages.indices.contains(currentIndex) else {
            return ("progress-complete", "取得完了")
        }
        switch stages[currentIndex].kind {
        case .entry:
            return ("progress-entry", stages[currentIndex].title == "発売" ? "発売・購入" : "抽選申込")
        case .result:
            return ("progress-result", "当落待ち")
        case .payment:
            return ("progress-payment", "入金・支払")
        case .acquired:
            return ("progress-acquired", "チケット取得")
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
        List {
            Section {
                TicketOverviewSearchField(text: $searchText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TicketOverviewFilter.allCases) { filter in
                            filterButton(filter)
                        }
                    }
                }

                if !genreOptions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            genreButton(
                                title: "すべて",
                                categoryID: nil,
                                tint: TicketOverviewStyle.accent
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
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(TicketOverviewStyle.surface)

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
                        ForEach(group.attempts) { attempt in
                            ticketCard(for: attempt)
                                .listRowInsets(
                                    EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        overviewSectionHeader(
                            title: group.headerTitle(
                                fallback: selectedFilter.title,
                                showsIndividualLabel: selectedFilter == .all
                                    && applicationDisplayGroups.count > 1
                            ),
                            count: group.attempts.count
                        )
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(TicketOverviewStyle.canvas)
        .tint(TicketOverviewStyle.accent)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .navigationTitle("チケット管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TicketOverviewStyle.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onChange(of: genreOptions.map(\.id)) { _, categoryIDs in
            if let selectedCategoryID, !categoryIDs.contains(selectedCategoryID) {
                self.selectedCategoryID = nil
            }
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddTicketPlan = true
                } label: {
                    FavorecoIcon(systemName: "plus", size: 17)
                }
                .accessibilityLabel("申込・発売を登録")
            }
        }
        .sheet(isPresented: $isShowingAddTicketPlan) {
            AddTicketPlanView()
        }
        .sheet(item: $editingAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt)
            }
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
        .sheet(item: $schedulePlan) { plan in
            TicketAttendanceScheduleSheet(plan: plan)
        }
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
    }

    private func category(for attempt: TicketAttempt) -> RecordCategory? {
        attempt.plan?.category ?? attempt.plan?.event?.category
    }

    private func overviewSectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(TicketOverviewStyle.text)
                .textCase(nil)
            Spacer()
            Text("\(count)件")
                .font(FavorecoTypography.caption)
                .foregroundStyle(TicketOverviewStyle.secondaryText)
                .textCase(nil)
        }
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
                        Label("再表示", systemImage: "arrow.uturn.left.circle")
                    }
                    .tint(.green)
                }
        } else if attempt.plan != nil {
            Button {
                quickActionAttempt = attempt
            } label: {
                TicketOverviewRow(attempt: attempt, showsSwipeHints: true)
            }
            .buttonStyle(.plain)
            .contextMenu {
                statusTransitionMenu(for: attempt)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    statusActionAttempt = attempt
                } label: {
                    Label("進める", systemImage: "arrow.right.circle")
                }
                .tint(TicketOverviewStyle.advancePeek)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    close(attempt)
                } label: {
                    Label(
                        attempt.statusKey == "waitingResult" ? "落選" : "見送り",
                        systemImage: "xmark.circle"
                    )
                }
                Button {
                    editingAttempt = attempt
                } label: {
                    FavorecoIconLabel("編集", systemImage: "pencil", iconSize: 17)
                }
                .tint(TicketOverviewStyle.accent)
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
            .frame(height: 34)
            .background(
                isSelected ? TicketOverviewStyle.accent : TicketOverviewStyle.surface,
                in: Capsule()
            )
            .overlay {
                if !isSelected {
                    Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
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
                .frame(height: 32)
                .background(isSelected ? tint : tint.opacity(0.10), in: Capsule())
                .overlay {
                    Capsule().stroke(tint.opacity(isSelected ? 0 : 0.28), lineWidth: 0.8)
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
            if TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: statusKey,
                plan: attempt.plan
            ), let plan = attempt.plan {
                DispatchQueue.main.async {
                    schedulePlan = plan
                }
            }
        } catch {
            statusUpdateError = error.localizedDescription
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
    static let canvas = Color(hex: "#F7F5F3")
    static let surface = Color.white
    static let accent = Color(hex: "#B04464")
    static let text = Color(hex: "#302A2D")
    static let secondaryText = Color(hex: "#746B70")
    static let advancePeek = Color(hex: "#4AAE70")
    static let editPeek = Color(hex: "#D95561")
}

private enum TicketOverviewFilter: String, CaseIterable, Identifiable {
    case all
    case needsAction
    case planning
    case acquired
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .needsAction: "要対応"
        case .planning: "進行中"
        case .acquired: "取得済み"
        case .completed: "終了"
        case .archived: "非表示"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "ticket"
        case .needsAction: "bell.badge"
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
        case .planning: "進行中のチケットはありません"
        case .acquired: "取得済みのチケットはありません"
        case .completed: "終了したチケットはありません"
        case .archived: "非表示のチケットはありません"
        }
    }

    var emptyMessage: String {
        switch self {
        case .needsAction:
            "申込締切、当落発表、入金締切、チケット受取開始が近づくとここに表示されます。"
        case .archived:
            "個別に非表示にした申込を、ここから再表示できます。"
        default:
            "右上の＋または下部の「追加」から、申込・発売を登録できます。"
        }
    }

    func includes(_ attempt: TicketAttempt) -> Bool {
        switch self {
        case .all:
            return true
        case .needsAction:
            return TicketNextActionDefinition.nextAction(for: attempt) != nil
                || TicketInputIssueDefinition.issue(for: attempt) != nil
                || (["waitingIssue", "issued"].contains(attempt.statusKey)
                    && attempt.plan?.hasConfirmedSchedule == false)
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

            TextField("公演名・申込まとめ・プレイガイドを検索", text: $text)
                .font(FavorecoTypography.body)
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
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(TicketOverviewStyle.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(TicketOverviewStyle.text.opacity(0.10), lineWidth: 0.8)
        }
    }
}

private struct TicketOverviewRow: View {
    let attempt: TicketAttempt
    var showsSwipeHints = false

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
            return "チケ取得"
        }
        let source = nextAction?.title ?? inputIssue?.title ?? actionTitle ?? ""
        if source.contains("当落") { return "抽選当落" }
        if source.contains("入金") || source.contains("支払") { return "チケ支払" }
        if source.contains("受取") || source.contains("取得") { return "チケ取得" }
        if source.contains("発売") || source.contains("購入") { return "チケ発売" }
        if source.contains("申込") { return "抽選申込" }
        if source.contains("参加日") { return "参加日" }
        if stages.indices.contains(currentStageIndex) {
            let stage = stages[currentStageIndex]
            return switch stage.kind {
            case .entry: stage.title == "発売" ? "チケ発売" : "抽選申込"
            case .result: "抽選当落"
            case .payment: "チケ支払"
            case .acquired: "チケ取得"
            }
        }
        return "チケット"
    }
    private var terminalHeadline: String? {
        switch attempt.statusKey {
        case "issued": "取得済み"
        case "attended": "参加済み"
        case "lost": "落選"
        case "skipped": "見送り"
        default: nil
        }
    }
    private var deadlineStatusColor: Color {
        TicketProgressColorPalette.color(
            forDeadlineLabel: deadlineLabel,
            fallback: categoryColor
        )
    }
    private var entryMethodColor: Color {
        switch attempt.entryRouteKey {
        case "fanClub", "official", "lottery", "card", "generalLottery":
            return TicketProgressColorPalette.application
        case "presale", "general", "sameDay":
            return TicketProgressColorPalette.payment
        case "resale":
            return Color(hex: "#B66A32")
        default:
            return TicketOverviewStyle.accent
        }
    }
    private func taskTitle(for action: TicketNextActionDefinition) -> String {
        switch action.title {
        case "申込・発売開始":
            return TicketProgressTimeline.usesLotteryFlow(attempt) ? "申込を開始する" : "購入する"
        case "申込締切":
            return "申込を完了する"
        case "申込締切超過":
            return "申込状況を更新"
        case "当落発表", "当落を確認":
            return "当落結果を入力"
        case "入金締切":
            return "入金を完了する"
        case "入金期限超過":
            return "支払状況を更新"
        case "チケット受取開始", "チケットを受け取る":
            return "チケットを受け取る"
        case "発売開始済み":
            return "購入状況を更新"
        default:
            return action.title
        }
    }

    var body: some View {
        ZStack {
            if showsSwipeHints {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(TicketOverviewStyle.advancePeek)
                    .padding(.horizontal, 6)
                    .offset(x: -6)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(TicketOverviewStyle.editPeek)
                    .padding(.horizontal, 6)
                    .offset(x: 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 4) {
                    VStack(spacing: 4) {
                        overviewBadge(deadlineLabel, color: deadlineStatusColor)

                        ThumbnailImage(
                            reference: thumbnailReference,
                            displaySize: CGSize(width: 64, height: 64),
                            contentMode: .fill
                        ) {
                            CategoryDefaultArtworkImage(
                                templateKey: category?.templateKey ?? "",
                                displaySize: CGSize(width: 64, height: 64)
                            )
                        }
                        .frame(width: 64, height: 64)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .frame(width: 64)

                    TicketOverviewDeadlineBlock(
                        date: actionDate,
                        requiresInput: inputIssue != nil,
                        isAttendanceUndated: actionTitle == "参加日を設定",
                        isOverdue: nextAction?.isOverdue == true,
                        fallbackHeadline: terminalHeadline
                    )
                    .frame(width: 68)

                    Rectangle()
                        .fill(TicketOverviewStyle.text.opacity(0.12))
                        .frame(width: 1, height: 84)
                        .padding(.trailing, 5)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if let entryRouteBadgeTitle {
                                overviewBadge(entryRouteBadgeTitle, color: entryMethodColor)
                            }
                            if let ticketSiteBadgeTitle {
                                overviewBadge(ticketSiteBadgeTitle, color: entryMethodColor)
                            }
                            if entryRouteBadgeTitle == nil, ticketSiteBadgeTitle == nil {
                                overviewBadge("チケット", color: entryMethodColor)
                            }
                            Spacer(minLength: 0)
                        }

                        Text(plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定")
                            .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(TicketOverviewStyle.text)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let plan {
                            FavorecoIconLabel(
                                plan.hasConfirmedSchedule
                                    ? FavorecoDateText.compactDateTime(plan.startsAt)
                                    : "参加日未定",
                                systemImage: plan.hasConfirmedSchedule
                                    ? "calendar"
                                    : "calendar.badge.exclamationmark",
                                iconSize: 12
                            )
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(
                                plan.hasConfirmedSchedule
                                    ? TicketOverviewStyle.secondaryText
                                    : Color.orange
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(minHeight: 84)
                }

                if !stages.isEmpty {
                    TicketProgressTimelineView(
                        stages: stages,
                        currentIndex: currentStageIndex,
                        nodeBackground: TicketOverviewStyle.surface,
                        secondaryTextColor: TicketOverviewStyle.secondaryText
                    )
                    .padding(.top, 7)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(TicketOverviewStyle.text.opacity(0.10))
                            .frame(height: 1)
                    }
                }

                TicketOverviewNextActionRow(
                    actionTitle: actionTitle,
                    fallbackTitle: TicketStatusDefinition.name(for: attempt.statusKey),
                    systemImage: actionSystemImage,
                    actionDate: actionDate,
                    isOverdue: nextAction?.isOverdue == true
                )
            }
            .padding(8)
            .background(
                TicketOverviewStyle.surface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(TicketOverviewStyle.text.opacity(0.12), lineWidth: 0.8)
            }
            .padding(.horizontal, showsSwipeHints ? 6 : 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func overviewBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct TicketOverviewDeadlineBlock: View {
    let date: Date?
    let requiresInput: Bool
    let isAttendanceUndated: Bool
    let isOverdue: Bool
    let fallbackHeadline: String?

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
        hasExpired ? Color(hex: "#C9364F") : TicketOverviewStyle.text
    }

    var body: some View {
        VStack(spacing: 1) {
            if let daysRemaining, daysRemaining >= 2, !hasExpired {
                HStack(alignment: .center, spacing: 1) {
                    VStack(spacing: -4) {
                        Text("あ")
                        Text("と")
                    }
                    .font(FavorecoTypography.jpSerif(10, weight: .semibold, relativeTo: .caption2))

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(daysRemaining)")
                            .font(FavorecoTypography.latinDisplay(30, weight: .bold, relativeTo: .title2))
                            .monospacedDigit()
                        Text("日")
                            .font(FavorecoTypography.jpSerif(10, weight: .semibold, relativeTo: .caption2))
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
            }

            if let date {
                Text(FavorecoDateText.compactDate(date))
                    .font(FavorecoTypography.jpSerif(11, weight: .semibold, relativeTo: .caption))
                    .lineLimit(1)
                Text(FavorecoDateText.time(date))
                    .font(FavorecoTypography.latinDisplay(12, weight: .bold, relativeTo: .caption))
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
                        fallbackHeadline != nil || isAttendanceUndated
                            ? TicketOverviewStyle.secondaryText
                            : Color(hex: "#C9364F")
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

    private var urgencyColor: Color {
        if isOverdue || (actionDate.map { $0 < Date() } == true) { return .red }
        if actionDate == nil { return .orange }
        return .primary
    }

    var body: some View {
        HStack(spacing: 8) {
            FavorecoIcon(systemName: systemImage, size: 15)
                .foregroundStyle(urgencyColor)
                .frame(width: 24, height: 24)
                .background(urgencyColor.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(actionTitle == nil ? "現在の状態" : "次にやること")
                    .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(.secondary)

                Text(actionTitle ?? fallbackTitle)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(urgencyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 6)

            if let actionDate {
                Text(FavorecoDateText.compactDateTime(actionDate))
                    .font(FavorecoTypography.captionStrong)
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
