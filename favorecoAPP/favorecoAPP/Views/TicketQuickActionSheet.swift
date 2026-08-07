import SwiftUI
import SwiftData

struct TicketQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    let attempt: TicketAttempt
    let onStatusUpdated: ((TicketAttempt) -> Void)?

    @State private var updateError = ""
    @State private var isShowingSchedule = false
    @State private var editingAttempt: TicketAttempt?
    @State private var ticketDetailsPromptAttempt: TicketAttempt?
    @State private var pendingUpdatedStatusKey: String?
    @State private var finishesUpdateAfterTicketEdit = false

    init(
        attempt: TicketAttempt,
        onStatusUpdated: ((TicketAttempt) -> Void)? = nil
    ) {
        self.attempt = attempt
        self.onStatusUpdated = onStatusUpdated
    }

    private var plan: Plan? { attempt.plan }

    private var item: CategoryTicketProgressItem? {
        guard let plan else { return nil }
        return CategoryTicketProgressItem(plan: plan, attempt: attempt)
    }

    private var tint: Color {
        themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
    }

    private var entryRouteBadgeTitle: String? {
        guard !attempt.entryRouteKey.isEmpty else { return nil }
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

    private var visibleActionCount: Int {
        guard let plan else { return 0 }
        return TicketStatusTransitionDefinition.transitions(for: attempt).count
            + (plan.hasConfirmedSchedule ? 0 : 1)
            + 1
    }

    private var initialSheetFraction: CGFloat {
        switch visibleActionCount {
        case ...2:
            return 0.58
        case 3:
            return 0.64
        default:
            return 0.70
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let plan {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                if let entryRouteBadgeTitle {
                                    ticketMetadataBadge(
                                        entryRouteBadgeTitle,
                                        systemImage: "ticket",
                                        role: .entryRoute
                                    )
                                }
                                if let ticketSiteBadgeTitle {
                                    ticketMetadataBadge(
                                        ticketSiteBadgeTitle,
                                        systemImage: "safari",
                                        role: .ticketSite
                                    )
                                }
                                if entryRouteBadgeTitle == nil, ticketSiteBadgeTitle == nil {
                                    ticketMetadataBadge(
                                        "チケット",
                                        systemImage: "ticket",
                                        role: .entryRoute
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(plan.title.isEmpty ? plan.event?.title ?? "公演" : plan.title)
                                .font(FavorecoTypography.cardTitle)
                                .lineLimit(2)
                                .minimumScaleFactor(0.88)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                FavorecoIconLabel(
                                    plan.hasConfirmedSchedule
                                        ? FavorecoDateText.compactDateTime(plan.startsAt)
                                        : "参加日未定",
                                    systemImage: plan.hasConfirmedSchedule
                                        ? "calendar"
                                        : "calendar.badge.exclamationmark",
                                    iconSize: 13
                                )
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(
                                    plan.hasConfirmedSchedule
                                        ? Color.primary.opacity(0.72)
                                        : TicketProgressColorPalette.scheduleUndated
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                                Spacer(minLength: 0)

                                Button {
                                    editingAttempt = attempt
                                } label: {
                                    FavorecoIcon(systemName: "pencil", size: 16)
                                        .frame(width: 34, height: 30)
                                        .background(tint.opacity(0.10), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(tint)
                                .accessibilityLabel("チケットスケジュールの日付を編集")
                                .accessibilityHint("申込、当落、支払、受取の日付を編集します")
                            }
                        }

                        if let item {
                            HStack(spacing: 6) {
                                Text("現在の工程")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                Text(TicketProgressPresentation.currentStageLabel(for: attempt))
                                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                                    .foregroundStyle(currentStageColor(for: item))
                            }

                            TicketProgressTimelineView(
                                stages: item.stages,
                                currentIndex: item.currentStageIndex,
                                nodeBackground: Color(.secondarySystemGroupedBackground),
                                secondaryTextColor: .secondary,
                                completedTint: TicketProgressColorPalette.completedNeutral
                            )
                        }

                        nextActionBlock

                        transitionButtons

                        if !plan.hasConfirmedSchedule {
                            Button {
                                isShowingSchedule = true
                            } label: {
                                compactButtonLabel("参加日を設定", systemImage: "calendar.badge.plus")
                                    .foregroundStyle(prominentButtonForeground)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themePalette.prominentAction)
                            .controlSize(.small)
                        }

                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            compactTextButtonLabel("チケットの詳細を見る")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        FavorecoContentUnavailableView(
                            "予定が見つかりません",
                            systemImage: "ticket",
                            description: "このチケットに紐づく予定を確認できません。"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("進捗管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingSchedule) {
                if let plan {
                    TicketAttendanceScheduleSheet(plan: plan)
                }
            }
            .sheet(item: $editingAttempt, onDismiss: finishUpdateAfterTicketEditIfNeeded) { editingAttempt in
                if let plan = editingAttempt.plan {
                    EditTicketAttemptView(
                        plan: plan,
                        attempt: editingAttempt,
                        prioritizesDates: !finishesUpdateAfterTicketEdit
                    )
                } else {
                    FavorecoContentUnavailableView(
                        "予定が見つかりません",
                        systemImage: "ticket"
                    )
                }
            }
            .ticketPostAcquisitionDetailsPrompt(
                attempt: $ticketDetailsPromptAttempt,
                onEdit: { pendingAttempt in
                    finishesUpdateAfterTicketEdit = true
                    editingAttempt = pendingAttempt
                },
                onLater: { _ in
                    finishPendingStatusUpdate()
                }
            )
            .alert("状態を更新できませんでした", isPresented: Binding(
                get: { !updateError.isEmpty },
                set: { if !$0 { updateError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(updateError)
            }
        }
        .presentationDetents([.fraction(initialSheetFraction), .large])
    }

    private func ticketMetadataBadge(
        _ title: String,
        systemImage: String,
        role: TicketMetadataRole
    ) -> some View {
        let foreground = role == .entryRoute
            ? TicketProgressColorPalette.entryRouteChipText
            : TicketProgressColorPalette.metadataChipText
        let border = role == .entryRoute
            ? TicketProgressColorPalette.entryRouteChipBorder
            : TicketProgressColorPalette.metadataChipBorder

        return FavorecoIconLabel(title, systemImage: systemImage, iconSize: 14)
            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                TicketProgressColorPalette.metadataChipSurface,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(border.opacity(0.78), lineWidth: 0.8)
            }
    }

    @ViewBuilder
    private var nextActionBlock: some View {
        if TicketAttendanceScheduleRequirement.shouldPrompt(
            afterTransitionTo: attempt.statusKey,
            plan: plan
        ) {
            FavorecoIconLabel("次にやること：参加日を設定", systemImage: "calendar.badge.plus", iconSize: 16)
                .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(TicketProgressColorPalette.scheduleUndated)
        } else if let action = TicketNextActionDefinition.nextAction(for: attempt) {
            VStack(alignment: .leading, spacing: 4) {
                Text("次にやること")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Label(
                    "\(action.title)  \(FavorecoDateText.compactDateTime(action.date))",
                    systemImage: action.systemImage
                )
                .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(action.isOverdue ? .red : .primary)
            }
        }
    }

    private var transitionButtons: some View {
        let transitions = TicketStatusTransitionDefinition.transitions(for: attempt)
        return VStack(spacing: 10) {
            ForEach(transitions) { transition in
                if transition.targetStatusKey == "lost" || transition.targetStatusKey == "skipped" {
                    Button {
                        update(to: transition.targetStatusKey)
                    } label: {
                        compactButtonLabel(
                            transition.title,
                            systemImage: transition.systemImage
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        update(to: transition.targetStatusKey)
                    } label: {
                        compactButtonLabel(
                            transition.title,
                            systemImage: transition.systemImage
                        )
                        .foregroundStyle(prominentButtonForeground)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themePalette.prominentAction)
                    .controlSize(.small)
                }
            }
        }
    }

    private func currentStageColor(for item: CategoryTicketProgressItem) -> Color {
        guard item.currentStageIndex < item.stages.count else {
            return TicketProgressColorPalette.color(for: .acquired)
        }
        return TicketProgressColorPalette.color(for: item.stages[item.currentStageIndex])
    }

    private func compactButtonLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        FavorecoIconLabel(title, systemImage: systemImage, iconSize: 14)
            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 26)
    }

    private func compactTextButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 26)
    }

    private var prominentButtonForeground: Color {
        themePalette.prominentActionForeground(for: colorScheme)
    }

    private func update(to statusKey: String) {
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
                pendingUpdatedStatusKey = statusKey
                DispatchQueue.main.async {
                    ticketDetailsPromptAttempt = attempt
                }
                return
            }
            completeStatusUpdate(statusKey: statusKey)
        } catch {
            updateError = error.localizedDescription
        }
    }

    private func finishUpdateAfterTicketEditIfNeeded() {
        guard finishesUpdateAfterTicketEdit else { return }
        finishesUpdateAfterTicketEdit = false
        finishPendingStatusUpdate()
    }

    private func finishPendingStatusUpdate() {
        guard let statusKey = pendingUpdatedStatusKey else { return }
        pendingUpdatedStatusKey = nil
        completeStatusUpdate(statusKey: statusKey)
    }

    private func completeStatusUpdate(statusKey: String) {
        if let onStatusUpdated {
            onStatusUpdated(attempt)
            dismiss()
            return
        }
        if TicketAttendanceScheduleRequirement.shouldPrompt(
            afterTransitionTo: statusKey,
            plan: plan
        ) {
            DispatchQueue.main.async {
                isShowingSchedule = true
            }
        }
    }
}

private enum TicketMetadataRole {
    case entryRoute
    case ticketSite
}
