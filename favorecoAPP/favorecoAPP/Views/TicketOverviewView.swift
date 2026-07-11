//
//  TicketOverviewView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import SwiftUI
import SwiftData

struct TicketOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var attempts: [TicketAttempt]
    @State private var selectedFilter: TicketOverviewFilter = .needsAction
    @State private var statusUpdateError = ""
    @State private var searchText = ""
    @State private var isShowingAddTicketPlan = false

    private var activeAttempts: [TicketAttempt] {
        attempts.filter { !$0.isArchived && $0.plan?.isArchived != true }
    }

    private var filteredAttempts: [TicketAttempt] {
        searchedAttempts
            .filter(selectedFilter.includes)
            .sorted(by: ticketAttemptOrder)
    }

    private var searchedAttempts: [TicketAttempt] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activeAttempts }

        return activeAttempts.filter { attempt in
            let plan = attempt.plan
            let account = attempt.account
            let searchableText = [
                plan?.title ?? "",
                plan?.subtitle ?? "",
                plan?.venueNameSnapshot ?? "",
                plan?.organizerNameSnapshot ?? "",
                attempt.ticketSite,
                attempt.holderName,
                account?.serviceName ?? "",
                account?.accountName ?? "",
                TicketStatusDefinition.name(for: attempt.statusKey),
                TicketEntryRouteDefinition.name(for: attempt.entryRouteKey),
                attempt.memo,
            ].joined(separator: " ")
            return searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("表示", selection: $selectedFilter) {
                    ForEach(TicketOverviewFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                TicketOverviewCounts(attempts: searchedAttempts)
            }

            Section(selectedFilter.title) {
                if filteredAttempts.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            selectedFilter.emptyTitle,
                            systemImage: selectedFilter.systemImage,
                            description: Text(selectedFilter.emptyMessage)
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    ForEach(filteredAttempts) { attempt in
                        if let plan = attempt.plan {
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                TicketOverviewRow(attempt: attempt)
                            }
                            .contextMenu {
                                statusTransitionMenu(for: attempt)
                            }
                        } else {
                            TicketOverviewRow(attempt: attempt)
                        }
                    }
                }
            }
        }
        .navigationTitle("チケット")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "予定名・会場・プレイガイド・名義")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddTicketPlan = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("予定・チケットを追加")
            }
        }
        .sheet(isPresented: $isShowingAddTicketPlan) {
            AddTicketPlanView()
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
                    Label(transition.title, systemImage: transition.systemImage)
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
        } catch {
            statusUpdateError = error.localizedDescription
        }
    }

    private func ticketAttemptOrder(_ lhs: TicketAttempt, _ rhs: TicketAttempt) -> Bool {
        let leftAction = TicketNextActionDefinition.nextAction(for: lhs)
        let rightAction = TicketNextActionDefinition.nextAction(for: rhs)

        switch (leftAction, rightAction) {
        case let (.some(left), .some(right)):
            return left.date == right.date ? left.priority < right.priority : left.date < right.date
        case (.some(_), .none):
            return true
        case (.none, .some(_)):
            return false
        case (.none, .none):
            let leftDate = lhs.plan?.startsAt ?? lhs.updatedAt
            let rightDate = rhs.plan?.startsAt ?? rhs.updatedAt
            return leftDate < rightDate
        }
    }
}

private enum TicketOverviewFilter: String, CaseIterable, Identifiable {
    case all
    case needsAction
    case planning
    case acquired
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .needsAction: "要対応"
        case .planning: "検討・申込"
        case .acquired: "取得済み"
        case .completed: "終了"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "ticket"
        case .needsAction: "bell.badge"
        case .planning: "hourglass"
        case .acquired: "ticket.fill"
        case .completed: "checkmark.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "チケット情報はありません"
        case .needsAction: "対応が必要なチケットはありません"
        case .planning: "検討・申込中のチケットはありません"
        case .acquired: "取得済みのチケットはありません"
        case .completed: "終了したチケットはありません"
        }
    }

    var emptyMessage: String {
        self == .needsAction
            ? "申込締切、当落発表、入金締切、発券開始が近づくとここに表示されます。"
            : "中央の＋から予定・チケットを追加できます。"
    }

    func includes(_ attempt: TicketAttempt) -> Bool {
        switch self {
        case .all:
            return true
        case .needsAction:
            return TicketNextActionDefinition.nextAction(for: attempt) != nil
        case .planning:
            return ["interested", "beforeApply", "onSaleSoon", "waitingResult"].contains(attempt.statusKey)
        case .acquired:
            return ["won", "waitingPayment", "waitingIssue", "issued"].contains(attempt.statusKey)
        case .completed:
            return ["lost", "attended", "skipped"].contains(attempt.statusKey)
        }
    }
}

private struct TicketOverviewCounts: View {
    let attempts: [TicketAttempt]

    private var needsActionCount: Int {
        attempts.filter { TicketNextActionDefinition.nextAction(for: $0) != nil }.count
    }

    private var acquiredCount: Int {
        attempts.filter { ["won", "waitingPayment", "waitingIssue", "issued"].contains($0.statusKey) }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            countCell(value: attempts.count, label: "申込")
            Divider().frame(height: 34)
            countCell(value: needsActionCount, label: "要対応")
            Divider().frame(height: 34)
            countCell(value: acquiredCount, label: "取得済み")
        }
        .accessibilityElement(children: .contain)
    }

    private func countCell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(FavorecoTypography.bodyStrong)
            Text(label)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TicketOverviewRow: View {
    let attempt: TicketAttempt

    private var plan: Plan? { attempt.plan }
    private var nextAction: TicketNextActionDefinition? {
        TicketNextActionDefinition.nextAction(for: attempt)
    }
    private var categoryColor: Color {
        Color(hex: plan?.category?.colorHex ?? "#147C88")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: plan?.category?.iconSymbol ?? "ticket")
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 42, height: 42)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定")
                        .font(FavorecoTypography.bodyStrong)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(TicketStatusDefinition.name(for: attempt.statusKey))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }

                if let plan {
                    Label(plan.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if !attempt.ticketSite.isEmpty || !attempt.entryRouteKey.isEmpty {
                    Text([attempt.ticketSite, TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)]
                        .filter { !$0.isEmpty }
                        .joined(separator: " / "))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let nextAction {
                    Label(
                        "\(nextAction.title)  \(nextAction.date.formatted(date: .numeric, time: .shortened))",
                        systemImage: nextAction.systemImage
                    )
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(nextAction.isOverdue ? .red : .orange)
                    .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch attempt.statusKey {
        case "lost", "skipped": .secondary
        case "attended": .green
        case "waitingPayment": .red
        case "won", "waitingIssue", "issued": categoryColor
        default: .orange
        }
    }
}
