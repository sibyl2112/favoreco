import SwiftUI
import SwiftData

struct TicketQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette

    let attempt: TicketAttempt

    @State private var updateError = ""
    @State private var isShowingSchedule = false

    private var plan: Plan? { attempt.plan }

    private var item: CategoryTicketProgressItem? {
        guard let plan else { return nil }
        return CategoryTicketProgressItem(plan: plan, attempt: attempt)
    }

    private var tint: Color {
        themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if let plan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(plan.title.isEmpty ? plan.event?.title ?? "公演" : plan.title)
                            .font(FavorecoTypography.cardTitle)
                        Text(
                            plan.hasConfirmedSchedule
                                ? FavorecoDateText.compactDateTime(plan.startsAt)
                                : "参加日未定"
                        )
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let item {
                        TicketProgressTimelineView(
                            stages: item.stages,
                            currentIndex: item.currentStageIndex,
                            tint: tint,
                            nodeBackground: Color(.secondarySystemGroupedBackground),
                            secondaryTextColor: .secondary
                        )
                    }

                    nextActionBlock

                    transitionButtons

                    if !plan.hasConfirmedSchedule {
                        Button {
                            isShowingSchedule = true
                        } label: {
                            Label("参加日を設定", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        Text("チケットの詳細を見る")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    ContentUnavailableView(
                        "予定が見つかりません",
                        systemImage: "ticket",
                        description: Text("このチケットに紐づく予定を確認できません。")
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("チケット管理")
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
            .alert("状態を更新できませんでした", isPresented: Binding(
                get: { !updateError.isEmpty },
                set: { if !$0 { updateError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(updateError)
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var nextActionBlock: some View {
        if TicketAttendanceScheduleRequirement.shouldPrompt(
            afterTransitionTo: attempt.statusKey,
            plan: plan
        ) {
            Label("次にやること：参加日を設定", systemImage: "calendar.badge.plus")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.orange)
        } else if let action = TicketNextActionDefinition.nextAction(for: attempt) {
            VStack(alignment: .leading, spacing: 4) {
                Text("次にやること")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Label(
                    "\(action.title)  \(FavorecoDateText.compactDateTime(action.date))",
                    systemImage: action.systemImage
                )
                .font(FavorecoTypography.bodyStrong)
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
                        Label(transition.title, systemImage: transition.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        update(to: transition.targetStatusKey)
                    } label: {
                        Label(transition.title, systemImage: transition.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func update(to statusKey: String) {
        do {
            try TicketAttemptStatusUpdater.update(
                attempt: attempt,
                to: statusKey,
                in: modelContext
            )
            if TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: statusKey,
                plan: plan
            ) {
                DispatchQueue.main.async {
                    isShowingSchedule = true
                }
            }
        } catch {
            updateError = error.localizedDescription
        }
    }
}
