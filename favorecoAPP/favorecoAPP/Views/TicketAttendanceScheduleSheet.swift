import SwiftUI
import SwiftData

struct TicketAttendanceScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: Plan

    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var venueName: String
    @State private var saveError = ""
    @State private var isSaving = false

    init(plan: Plan) {
        self.plan = plan
        let start = plan.hasConfirmedSchedule
            ? plan.startsAt
            : Date().roundedToNearestFiveMinutes()
        _startsAt = State(initialValue: start)
        _endsAt = State(
            initialValue: plan.hasConfirmedSchedule
                ? plan.endsAt
                : Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start
        )
        _venueName = State(initialValue: plan.venueNameSnapshot)
    }

    var body: some View {
        NavigationStack {
            RecordLifecycleFlatScaffold(
                title: isLive ? "参戦日を設定" : "観劇日を設定",
                canSave: endsAt >= startsAt,
                saveButtonTitle: isSaving ? "保存中" : "保存",
                isSaving: isSaving,
                onClose: { dismiss() },
                onSave: save
            ) {
                FavorecoRegistrationSection(isLive ? "ライブ情報" : "公演情報") {
                    LabeledContent(isLive ? "ライブ" : "公演", value: plan.title.isEmpty ? plan.event?.title ?? (isLive ? "ライブ" : "公演") : plan.title)
                }

                FavorecoRegistrationSection(isLive ? "参戦予定" : "観劇予定") {
                    FiveMinuteDateTimeRow(title: "開始", selection: startBinding)
                    FiveMinuteDateTimeRow(title: "終了", selection: $endsAt)
                    TextField("会場（任意）", text: $venueName)
                }
            }
            .alert("予定を保存できませんでした", isPresented: Binding(
                get: { !saveError.isEmpty },
                set: { if !$0 { saveError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError)
            }
        }
    }

    private var isLive: Bool {
        plan.event?.category?.templateKey == "live"
    }

    private var startBinding: Binding<Date> {
        Binding {
            startsAt
        } set: { value in
            let rounded = value.roundedToNearestFiveMinutes()
            startsAt = rounded
            endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: rounded) ?? rounded
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveError = ""
        Task { @MainActor in
            await Task.yield()
            persistChanges()
        }
    }

    private func persistChanges() {
        let now = Date()
        plan.planKindKey = "performance"
        plan.startsAt = startsAt
        plan.endsAt = endsAt
        plan.venueNameSnapshot = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.updatedAt = now
        plan.event?.stateKey = "active"
        plan.event?.updatedAt = now

        do {
            try modelContext.save()
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: nil)
            }
            dismiss()
        } catch {
            modelContext.rollback()
            isSaving = false
            saveError = "予定を保存できませんでした。入力内容は保持されています。もう一度お試しください。"
            debugPrint("Failed to save attendance schedule: \(error)")
        }
    }
}
