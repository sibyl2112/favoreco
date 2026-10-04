import SwiftUI
import SwiftData

struct AdmissionPreparationConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: Plan

    @State private var saveError = ""
    @State private var isSaving = false

    private var isLive: Bool {
        plan.event?.category?.templateKey == "live"
    }

    private var performanceNoun: String {
        isLive ? "ライブ" : "公演"
    }

    private var planDisplayTitle: String {
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !planTitle.isEmpty { return planTitle }
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return eventTitle.isEmpty ? "予定" : eventTitle
    }

    private var daysUntilPerformance: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: plan.startsAt)
        ).day ?? 0
    }

    private var scheduleLeadText: String {
        switch daysUntilPerformance {
        case 0:
            return "今日は「\(planDisplayTitle)」です。"
        case 1:
            return "明日は「\(planDisplayTitle)」です。"
        case 2:
            return "明後日は「\(planDisplayTitle)」です。"
        default:
            return "\(FavorecoDateText.compactDate(plan.startsAt))は「\(planDisplayTitle)」です。"
        }
    }

    private var preparationGuidance: String {
        let opening = daysUntilPerformance == 0
            ? "チケットや持ち物を確認し、時間に余裕を持って向かいましょう。"
            : "チケットや持ち物、移動予定など、当日の準備を確認しましょう。"
        return "\(opening) 電子チケットの表示、紙チケットの発券、招待情報、チケット不要の\(performanceNoun)も含め、入場できる状態か確認してください。"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("入場の準備はできていますか？")
                        .font(FavorecoTypography.sectionTitle)
                    Text(scheduleLeadText)
                        .font(FavorecoTypography.bodyStrong)
                    Text("\(FavorecoDateText.compactDateTime(plan.startsAt))\(plan.venueNameSnapshot.isEmpty ? "" : "・\(plan.venueNameSnapshot)")")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Text(preparationGuidance)
                    .font(FavorecoTypography.body)

                Button {
                    confirm()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSaving ? "保存中" : "準備できている")
                    }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button {
                    snooze()
                } label: {
                    FavorecoIconLabel("あとで確認", systemImage: "clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("\(performanceNoun)前チェック")
            .navigationBarTitleDisplayMode(.inline)
            .alert("確認状態を保存できませんでした", isPresented: Binding(
                get: { !saveError.isEmpty },
                set: { if !$0 { saveError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError)
            }
        }
        .presentationDetents([.medium])
    }

    private func confirm() {
        guard !isSaving else { return }
        var fields = plan.preparationFields
        fields.admissionPreparationConfirmedAt = Date()
        fields.admissionPreparationSnoozedUntil = nil
        save(fields)
    }

    private func snooze() {
        guard !isSaving else { return }
        var fields = plan.preparationFields
        fields.admissionPreparationSnoozedUntil = plan.nextAdmissionPreparationPromptDate()
        save(fields)
    }

    private func save(_ fields: PlanPreparationFields) {
        guard !isSaving else { return }
        isSaving = true
        saveError = ""
        Task { @MainActor in
            await Task.yield()
            persist(fields)
        }
    }

    private func persist(_ fields: PlanPreparationFields) {
        plan.unitFieldsRaw = fields.encodedRawValue
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            isSaving = false
            dismiss()
        } catch {
            modelContext.rollback()
            isSaving = false
            saveError = "確認状態を保存できませんでした。もう一度お試しください。"
            debugPrint("Failed to save admission preparation state: \(error)")
        }
    }
}
