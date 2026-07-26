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
            Form {
                Section {
                    LabeledContent("公演", value: plan.title.isEmpty ? plan.event?.title ?? "公演" : plan.title)
                }

                Section("参加予定") {
                    FiveMinuteDateTimeRow(title: "開始", selection: startBinding)
                    FiveMinuteDateTimeRow(title: "終了", selection: $endsAt)
                    TextField("会場（任意）", text: $venueName)
                }
            }
            .navigationTitle("参加日を設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("あとで") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Coming Upに追加") {
                        save()
                    }
                    .disabled(endsAt < startsAt)
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
            saveError = error.localizedDescription
        }
    }
}
