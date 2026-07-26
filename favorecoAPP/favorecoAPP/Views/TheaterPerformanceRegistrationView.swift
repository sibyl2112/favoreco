import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TheaterPerformanceRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: RecordCategory

    @State private var title = ""
    @State private var officialURL = ""
    @State private var xURL = ""
    @State private var instagramURL = ""
    @State private var threadsURL = ""
    @State private var hasPerformancePeriod = false
    @State private var performanceStartsAt = Date().roundedToNearestFiveMinutes()
    @State private var performanceEndsAt = Calendar.current.date(
        byAdding: .day,
        value: 30,
        to: Date()
    )?.roundedToNearestFiveMinutes() ?? Date()
    @State private var eyecatchData: Data?
    @State private var selectedEyecatchItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var nextEvent: ExperienceEvent?
    @State private var nextEntryMode: AddTicketPlanView.EntryMode = .plan
    @State private var shouldDismissAfterNextStep = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSocialLinks: [String] {
        [xURL, instagramURL, threadsURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ExplicitFormTextField(
                        title: "公演名",
                        prompt: "月影のアトリエ（必須）",
                        text: $title,
                        labelStyle: .horizontal
                    )
                } header: {
                    Text("公演")
                } footer: {
                    Text("公演名だけで登録を始められます。ほかの情報は後から追加できます。")
                }

                Section("アイキャッチ（任意）") {
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Button("画像を外す", role: .destructive) {
                            self.eyecatchData = nil
                        }
                    }

                    PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                        Label(
                            eyecatchData == nil ? "写真を選ぶ" : "写真を変更",
                            systemImage: "photo"
                        )
                    }
                    .disabled(isProcessingImage)
                    .onChange(of: selectedEyecatchItem) { _, item in
                        guard let item else { return }
                        Task { await loadEyecatch(from: item) }
                    }
                }

                Section("公演情報（任意）") {
                    ExplicitFormTextField(
                        title: "公式URL",
                        prompt: "https://example.com（任意）",
                        text: $officialURL,
                        labelStyle: .horizontal
                    )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TheaterSocialLinksEditor(
                        xURL: $xURL,
                        instagramURL: $instagramURL,
                        threadsURL: $threadsURL
                    )

                    Toggle("会期が決まっている", isOn: $hasPerformancePeriod)

                    if hasPerformancePeriod {
                        DatePicker(
                            "会期開始",
                            selection: $performanceStartsAt,
                            displayedComponents: .date
                        )
                        .onChange(of: performanceStartsAt) { _, newValue in
                            if performanceEndsAt < newValue {
                                performanceEndsAt = newValue
                            }
                        }
                        DatePicker(
                            "会期終了",
                            selection: $performanceEndsAt,
                            in: performanceStartsAt...,
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    registrationButton(
                        title: "とりあえず登録",
                        detail: "Interestsに保存して、あとで予定やチケットを追加",
                        systemImage: "bookmark",
                        tint: .gray
                    ) {
                        save(nextStep: .interest)
                    }

                    registrationButton(
                        title: "日程確定済み",
                        detail: "公演を保存して、参加日時を続けて入力",
                        systemImage: "calendar.badge.plus",
                        tint: .blue
                    ) {
                        save(nextStep: .datedPlan)
                    }

                    registrationButton(
                        title: "チケットスケジュール設定",
                        detail: "抽選・発売予定を登録。参加日は未定でもOK",
                        systemImage: "ticket",
                        tint: .orange
                    ) {
                        save(nextStep: .ticketSchedule)
                    }
                } header: {
                    Text("このあと")
                }
            }
            .navigationTitle("公演を登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .disabled(isSaving)
            .sheet(item: $nextEvent, onDismiss: {
                if shouldDismissAfterNextStep {
                    dismiss()
                }
            }) { event in
                AddTicketPlanView(event: event, entryMode: nextEntryMode)
            }
            .alert("公演を登録できませんでした", isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func registrationButton(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(trimmedTitle.isEmpty || isSaving)
    }

    private func save(nextStep: TheaterPerformanceRegistrationNextStep) {
        guard !trimmedTitle.isEmpty else {
            errorMessage = "公演名を入力してください。"
            return
        }
        guard !hasPerformancePeriod || performanceEndsAt >= performanceStartsAt else {
            errorMessage = "会期終了は会期開始以降にしてください。"
            return
        }

        isSaving = true
        let now = Date()
        let fields = VisitUnitFields(
            socialLinks: normalizedSocialLinks,
            eventPeriodStartsAt: hasPerformancePeriod ? performanceStartsAt : nil,
            eventPeriodEndsAt: hasPerformancePeriod ? performanceEndsAt : nil
        )
        let event = ExperienceEvent(
            title: trimmedTitle,
            officialURL: trimmedOfficialURL,
            stateKey: "interested",
            unitFieldsRaw: fields.encodedRawValue,
            createdAt: now,
            updatedAt: now,
            eyecatchData: eyecatchData,
            category: category
        )
        modelContext.insert(event)

        do {
            try modelContext.save()
            switch nextStep {
            case .interest:
                dismiss()
            case .datedPlan:
                nextEntryMode = .plan
                shouldDismissAfterNextStep = true
                nextEvent = event
            case .ticketSchedule:
                nextEntryMode = .ticketSchedule
                shouldDismissAfterNextStep = true
                nextEvent = event
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    @MainActor
    private func loadEyecatch(from item: PhotosPickerItem) async {
        isProcessingImage = true
        defer {
            isProcessingImage = false
            selectedEyecatchItem = nil
        }
        guard let sourceData = try? await item.loadTransferable(type: Data.self),
              let compressed = await Task.detached(priority: .userInitiated, operation: {
                  QuickCaptureImageService.compressedJPEG(from: sourceData)
              }).value else {
            errorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed
    }
}

private enum TheaterPerformanceRegistrationNextStep {
    case interest
    case datedPlan
    case ticketSchedule
}
