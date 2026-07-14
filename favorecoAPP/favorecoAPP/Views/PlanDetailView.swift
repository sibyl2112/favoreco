//
//  PlanDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    let plan: Plan
    @State private var isShowingEditPlan = false
    @State private var isShowingAddAttempt = false
    @State private var editingAttempt: TicketAttempt?
    @State private var calendarDraft: CalendarEventDraft?
    @State private var isShowingDeleteConfirmation = false
    @State private var recordEventForVisit: ExperienceEvent?
    @State private var navigatingVisit: Visit?
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false

    private var categoryColor: Color {
        themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var attempts: [TicketAttempt] {
        (plan.ticketAttempts ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var dateRangeText: String {
        if Calendar.current.isDate(plan.startsAt, inSameDayAs: plan.endsAt) {
            return "\(plan.startsAt.formatted(date: .long, time: .shortened)) - \(plan.endsAt.formatted(date: .omitted, time: .shortened))"
        }
        return "\(plan.startsAt.formatted(date: .long, time: .shortened)) - \(plan.endsAt.formatted(date: .long, time: .shortened))"
    }

    private var preferredOpenDestination: TicketOpenDestination? {
        let attempt = attempts.first

        if let purchaseURL = attempt?.purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
           !purchaseURL.isEmpty,
           let url = URL(string: purchaseURL) {
            return TicketOpenDestination(label: "申込・購入ページを開く", url: url)
        }

        if let attempt,
           let guide = TicketGuideDefinition.guide(for: TicketGuideDefinition.inferredKey(
            siteName: attempt.ticketSite,
            urlString: attempt.purchaseURL
           )),
           !guide.urlString.isEmpty,
           let url = URL(string: guide.urlString) {
            return TicketOpenDestination(label: "プレイガイドを開く", url: url)
        }

        let officialURLString = plan.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !officialURLString.isEmpty,
           let url = URL(string: officialURLString) {
            return TicketOpenDestination(label: "公式URLを開く", url: url)
        }

        let sourceURLString = plan.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceURLString.isEmpty,
           let url = URL(string: sourceURLString) {
            return TicketOpenDestination(label: "公式URLを開く", url: url)
        }

        return nil
    }

    private var nextPlanAction: TicketNextActionDefinition? {
        attempts
            .compactMap { TicketNextActionDefinition.nextAction(for: $0) }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                basicSection
                ticketSection
                officialSection
                memoSection
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("予定・チケット")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isShowingEditPlan = true
                    } label: {
                        Label("予定を編集", systemImage: "pencil")
                    }

                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        Label("申込を追加", systemImage: "ticket")
                    }

                    Button {
                        calendarDraft = makeCalendarDraft()
                    } label: {
                        Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    }

                    if let destination = preferredOpenDestination {
                        Button {
                            openURL(destination.url)
                        } label: {
                            Label(destination.label, systemImage: "safari")
                        }
                    }

                    Button {
                        if let visit = plan.visit {
                            navigatingVisit = visit
                        } else {
                            prepareRecordEntry()
                        }
                    } label: {
                        Label(plan.visit == nil ? "参加記録を入力" : "参加記録を開く", systemImage: "sparkles")
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("予定を削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingEditPlan) {
            AddTicketPlanView(plan: plan, entryMode: .plan)
        }
        .sheet(isPresented: $isShowingAddAttempt) {
            EditTicketAttemptView(plan: plan)
        }
        .sheet(item: $editingAttempt) { attempt in
            EditTicketAttemptView(plan: plan, attempt: attempt)
        }
        .sheet(item: $recordEventForVisit) { event in
            AddVisitView(
                event: event,
                initialDraft: VisitDraft(plan: plan),
                sourcePlan: plan
            )
        }
        .sheet(item: $calendarDraft) { draft in
            CalendarEventEditSheet(draft: draft) { identifier in
                ExternalCalendarLinkStore.set(identifier: identifier, planID: plan.id)
                if !plan.externalCalendarEventIdentifier.isEmpty {
                    plan.externalCalendarEventIdentifier = ""
                    try? modelContext.save()
                }
            }
        }
        .navigationDestination(item: $navigatingVisit) { visit in
            ExperienceDetailView(visit: visit)
        }
        .confirmationDialog("予定を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("予定を削除", role: .destructive) {
                archivePlan()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("予定と紐づく申込を非表示にし、予約済み通知をキャンセルします。記録済みVisitは削除しません。")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: plan.category?.iconSymbol ?? "ticket")
                    .font(.title3)
                    .foregroundStyle(categoryColor)
                    .frame(width: 38, height: 38)
                    .background(categoryColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.category?.name ?? "予定")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(categoryColor)
                    Text(planStatusText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(plan.title.isEmpty ? "予定" : plan.title)
                .font(FavorecoTypography.heroLead)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !plan.subtitle.isEmpty {
                Text(plan.subtitle)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if !attempts.isEmpty {
                    PlanStatusChip(
                        icon: "ticket",
                        text: "申込 \(attempts.count)件",
                        tint: categoryColor
                    )
                }

                if let nextPlanAction {
                    PlanStatusChip(
                        icon: nextPlanAction.systemImage,
                        text: "\(nextPlanAction.title) \(nextPlanAction.date.formatted(date: .numeric, time: .shortened))",
                        tint: nextPlanAction.isOverdue ? .red : .orange
                    )
                }

                if plan.visit != nil {
                    PlanStatusChip(
                        icon: "checkmark.seal.fill",
                        text: "記録済み",
                        tint: .green
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .planSectionCard()
    }

    private var planStatusText: String {
        if let attempt = attempts.first {
            return TicketStatusDefinition.name(for: attempt.statusKey)
        }
        return plan.visit != nil || plan.stateKey == "attended" ? "参加済み" : "予定"
    }

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            planSectionTitle("基本情報")
            PlanInfoRow(icon: "calendar", title: "日時", value: dateRangeText)
            if plan.opensAt != Date.distantPast {
                PlanInfoRow(icon: "door.left.hand.open", title: "開場", value: plan.opensAt.formatted(date: .omitted, time: .shortened))
            }
            if !plan.venueNameSnapshot.isEmpty {
                PlanInfoRow(icon: "mappin.and.ellipse", title: "会場", value: plan.venueNameSnapshot)
            }
            if !plan.organizerNameSnapshot.isEmpty {
                PlanInfoRow(icon: "building.2", title: "主催", value: plan.organizerNameSnapshot)
            }
        }
        .planSectionCard()
    }

    @ViewBuilder
    private var ticketSection: some View {
        if attempts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("チケット")
                Text("チケット申込はまだ登録されていません。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
            .planSectionCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    planSectionTitle("チケット")
                    Spacer()
                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        Label("申込を追加", systemImage: "plus")
                            .font(FavorecoTypography.captionStrong)
                    }
                    .buttonStyle(.borderless)
                }
                ForEach(attempts) { attempt in
                    Button {
                        editingAttempt = attempt
                    } label: {
                        TicketAttemptDetailCard(attempt: attempt, accentColor: categoryColor)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingAttempt = attempt
                        } label: {
                            Label("申込を編集", systemImage: "pencil")
                        }

                        let transitions = TicketStatusTransitionDefinition.transitions(for: attempt)
                        if !transitions.isEmpty {
                            Divider()
                            ForEach(transitions) { transition in
                                Button {
                                    updateAttemptStatus(attempt, to: transition.targetStatusKey)
                                } label: {
                                    Label(transition.title, systemImage: transition.systemImage)
                                }
                            }
                        }
                    }
                }
            }
            .planSectionCard()
        }
    }

    @ViewBuilder
    private var officialSection: some View {
        if !plan.officialURL.isEmpty || !plan.sourceURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("公式情報")
                if let officialURL = URL(string: plan.officialURL), !plan.officialURL.isEmpty {
                    Link(destination: officialURL) {
                        PlanInfoRow(icon: "safari", title: "公式", value: plan.officialURL)
                    }
                    .buttonStyle(.plain)
                }
                if let sourceURL = URL(string: plan.sourceURL), !plan.sourceURL.isEmpty {
                    Link(destination: sourceURL) {
                        PlanInfoRow(icon: "link", title: "参考", value: plan.sourceURL)
                    }
                    .buttonStyle(.plain)
                }
            }
            .planSectionCard()
        }
    }

    @ViewBuilder
    private var memoSection: some View {
        if !plan.memo.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("メモ")
                Text(plan.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .planSectionCard()
        }
    }

    private func planSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.sectionTitle)
            .foregroundStyle(.primary)
    }

    private func makeCalendarDraft() -> CalendarEventDraft {
        let notes = [
            plan.subtitle,
            attempts.first.map { TicketStatusDefinition.name(for: $0.statusKey) } ?? "",
            attempts.first?.seatText ?? "",
            plan.memo,
            plan.officialURL,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return CalendarEventDraft(
            title: plan.title.isEmpty ? "予定" : plan.title,
            location: plan.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? plan.placeMaster?.address ?? plan.venueNameSnapshot
                : plan.venueNameSnapshot,
            notes: notes,
            startDate: plan.startsAt,
            endDate: plan.endsAt
        )
    }

    private func archivePlan() {
        let hasExternalCalendarLink = !ExternalCalendarLinkStore.identifier(for: plan).isEmpty
        plan.externalCalendarEventIdentifier = ""
        plan.isArchived = true
        plan.updatedAt = Date()
        let activeAttempts = attempts
        for attempt in activeAttempts {
            attempt.isArchived = true
            attempt.updatedAt = Date()
            TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
        }
        TicketNotificationScheduler.cancel(plan: plan, attempt: nil)

        let removesExternalEvent = purchaseManager.currentPlan.includesSync
            && automaticallyUpdatesExternalCalendar
            && hasExternalCalendarLink

        do {
            try modelContext.save()
            if removesExternalEvent {
                Task {
                    _ = try? await ExternalCalendarSyncService.remove(plan: plan)
                    try? modelContext.save()
                }
            } else {
                ExternalCalendarLinkStore.clear(planID: plan.id)
            }
            dismiss()
        } catch {
            assertionFailure("Failed to archive plan: \(error)")
        }
    }

    private func prepareRecordEntry() {
        if let visit = plan.visit {
            navigatingVisit = visit
            return
        }

        let now = Date()
        let event = plan.event ?? ExperienceEvent(
            title: plan.title.isEmpty ? "予定" : plan.title,
            seriesName: plan.subtitle,
            organizerNameSnapshot: plan.organizerNameSnapshot,
            officialURL: plan.officialURL,
            memo: plan.memo,
            createdAt: now,
            updatedAt: now,
            category: plan.category
        )

        if plan.event == nil {
            modelContext.insert(event)
            plan.event = event
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                assertionFailure("Failed to repair plan event before record entry: \(error)")
                return
            }
        }

        recordEventForVisit = event
    }

    private func updateAttemptStatus(_ attempt: TicketAttempt, to statusKey: String) {
        do {
            try TicketAttemptStatusUpdater.update(
                attempt: attempt,
                to: statusKey,
                in: modelContext
            )
        } catch {
            assertionFailure("Failed to update ticket status: \(error)")
        }
    }

}

private struct TicketOpenDestination {
    let label: String
    let url: URL
}

private struct TicketAttemptDetailCard: View {
    let attempt: TicketAttempt
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(TicketStatusDefinition.name(for: attempt.statusKey))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Spacer(minLength: 10)
                if !attempt.entryRouteKey.isEmpty {
                    Text(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }

            if let nextAction {
                TicketNextActionCallout(action: nextAction)
            }

            if let inputIssue {
                Label(inputIssue.title, systemImage: inputIssue.systemImage)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let accountName {
                PlanInfoRow(icon: "person.crop.circle", title: "名義", value: accountName)
            }
            if !attempt.ticketSite.isEmpty {
                PlanInfoRow(icon: "safari", title: "購入先", value: attempt.ticketSite)
            }
            if attempt.saleStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket", title: "開始", value: attempt.saleStartAt.formatted(date: .long, time: .shortened))
            }
            if attempt.applyDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "hourglass", title: "締切", value: attempt.applyDeadlineAt.formatted(date: .long, time: .shortened))
            }
            if attempt.resultAnnounceAt != Date.distantPast {
                PlanInfoRow(icon: "checkmark.seal", title: "当落", value: attempt.resultAnnounceAt.formatted(date: .long, time: .shortened))
            }
            if attempt.paymentDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "yensign.circle", title: "入金", value: attempt.paymentDeadlineAt.formatted(date: .long, time: .shortened))
            }
            if attempt.issueStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket.fill", title: "発券", value: attempt.issueStartAt.formatted(date: .long, time: .shortened))
            }
            if attempt.price != Decimal(0) || attempt.fee != Decimal(0) {
                PlanInfoRow(icon: "creditcard", title: "金額", value: amountText)
            }
            if !attempt.seatText.isEmpty {
                PlanInfoRow(icon: "chair", title: "座席", value: attempt.seatText)
            }
            if let purchaseURL = URL(string: attempt.purchaseURL), !attempt.purchaseURL.isEmpty {
                Link(destination: purchaseURL) {
                    PlanInfoRow(icon: "safari", title: "購入", value: attempt.purchaseURL)
                }
                .buttonStyle(.plain)
            }
            if !attempt.memo.isEmpty {
                Text(attempt.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var accountName: String? {
        if !attempt.holderName.isEmpty {
            return attempt.holderName
        }
        if let account = attempt.account {
            if !account.accountName.isEmpty {
                return account.accountName
            }
            if !account.serviceName.isEmpty {
                return account.serviceName
            }
        }
        return nil
    }

    private var amountText: String {
        let total = (attempt.price + attempt.fee) * Decimal(attempt.quantity)
        let number = NSDecimalNumber(decimal: total)
        return NumberFormatter.planCurrency.string(from: number) ?? "¥\(number.intValue)"
    }

    private var nextAction: TicketAttemptNextAction? {
        guard let action = TicketNextActionDefinition.nextAction(for: attempt) else { return nil }
        return TicketAttemptNextAction(
            title: action.title,
            date: action.date,
            icon: action.systemImage,
            tint: tint(for: action),
            priority: action.priority,
            isOverdue: action.isOverdue
        )
    }

    private var inputIssue: TicketInputIssueDefinition? {
        TicketInputIssueDefinition.issue(for: attempt)
    }

    private func tint(for action: TicketNextActionDefinition) -> Color {
        if action.isOverdue {
            return .red
        }
        switch action.title {
        case "申込締切":
            return .red
        case "入金締切":
            return .orange
        case "当落発表":
            return .purple
        case "発券開始":
            return .teal
        default:
            return accentColor
        }
    }
}

private struct TicketAttemptNextAction {
    let title: String
    let date: Date
    let icon: String
    let tint: Color
    let priority: Int
    let isOverdue: Bool
}

private struct TicketNextActionCallout: View {
    let action: TicketAttemptNextAction

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(FavorecoTypography.captionStrong)
            Text(action.isOverdue ? "要確認" : "次のアクション")
                .font(FavorecoTypography.caption)
            Text(action.title)
                .font(FavorecoTypography.captionStrong)
            Spacer(minLength: 8)
            Text(action.date.formatted(date: .abbreviated, time: .shortened))
                .font(FavorecoTypography.captionStrong)
        }
        .foregroundStyle(action.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlanInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
    }
}

private struct PlanStatusChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private extension NumberFormatter {
    static let planCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private extension View {
    func planSectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
