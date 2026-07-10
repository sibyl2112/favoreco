//
//  AddTicketPlanView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData

struct AddTicketPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]
    @State private var draft = TicketPlanDraft()

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var activeAccounts: [TicketAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.id == draft.categoryID }
    }

    private var selectedAccount: TicketAccount? {
        activeAccounts.first { $0.id == draft.accountID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("予定") {
                    Picker("ジャンル", selection: $draft.categoryID) {
                        Text("未設定").tag(Optional<UUID>.none)
                        ForEach(visibleCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                    TextField("公演・イベント名", text: $draft.title)
                    TextField("サブタイトル（任意）", text: $draft.subtitle)
                    DatePicker("開始", selection: $draft.startsAt)
                    DatePicker("終了", selection: $draft.endsAt)
                    DatePicker("開場", selection: $draft.opensAt)
                    TextField("会場", text: $draft.venueName)
                    TextField("公式URL", text: $draft.officialURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("チケット申込") {
                    Toggle("申込情報も作成", isOn: $draft.createsTicketAttempt)

                    if draft.createsTicketAttempt {
                        Picker("状態", selection: $draft.statusKey) {
                            ForEach(TicketStatusDefinition.all) { status in
                                Text(status.name).tag(status.key)
                            }
                        }

                        Picker("区分", selection: $draft.entryRouteKey) {
                            Text("未設定").tag("")
                            ForEach(TicketEntryRouteDefinition.all) { route in
                                Text(route.name).tag(route.key)
                            }
                        }

                        Picker("名義・アカウント", selection: $draft.accountID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(activeAccounts) { account in
                                Text(accountLabel(account)).tag(Optional(account.id))
                            }
                        }

                        TextField("購入先・サイト名", text: $draft.ticketSite)
                        TextField("名義メモ", text: $draft.holderName)

                        DateToggleRow(title: "申込開始", isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                        DateToggleRow(title: "申込締切", isOn: $draft.hasApplyDeadline, date: $draft.applyDeadlineAt)
                        DateToggleRow(title: "当落発表", isOn: $draft.hasResultAnnounce, date: $draft.resultAnnounceAt)
                        DateToggleRow(title: "入金締切", isOn: $draft.hasPaymentDeadline, date: $draft.paymentDeadlineAt)
                        DateToggleRow(title: "発券開始", isOn: $draft.hasIssueStart, date: $draft.issueStartAt)
                    }
                }

                if draft.createsTicketAttempt {
                    Section("金額・座席") {
                        TextField("チケット代", text: $draft.priceText)
                            .keyboardType(.numberPad)
                        TextField("手数料", text: $draft.feeText)
                            .keyboardType(.numberPad)
                        Stepper("枚数 \(draft.quantity)", value: $draft.quantity, in: 1...20)
                        TextField("座席・整理番号", text: $draft.seatText, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("購入URL", text: $draft.purchaseURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("メモ") {
                    TextField("メモ", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("予定・チケット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
            .onAppear {
                draft.setInitialCategoryIfNeeded(visibleCategories)
            }
            .onChange(of: draft.startsAt) { _, newValue in
                if draft.endsAt < newValue {
                    draft.endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: newValue) ?? newValue
                }
                if draft.opensAt > newValue {
                    draft.opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: newValue) ?? newValue
                }
            }
        }
    }

    private func accountLabel(_ account: TicketAccount) -> String {
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(account.serviceName) / \(holder)"
    }

    private func save() {
        let now = Date()
        let plan = Plan(
            title: draft.trimmedTitle,
            subtitle: draft.trimmedSubtitle,
            planKindKey: "performance",
            stateKey: draft.createsTicketAttempt ? draft.statusKey : "planned",
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            opensAt: draft.opensAt,
            venueNameSnapshot: draft.trimmedVenueName,
            officialURL: draft.trimmedOfficialURL,
            sourceURL: draft.trimmedOfficialURL,
            memo: draft.trimmedMemo,
            createdAt: now,
            updatedAt: now,
            category: selectedCategory
        )
        modelContext.insert(plan)

        if draft.createsTicketAttempt {
            let attempt = TicketAttempt(
                statusKey: draft.statusKey,
                entryRouteKey: draft.entryRouteKey,
                ticketSite: draft.trimmedTicketSite,
                holderName: draft.trimmedHolderName,
                saleStartAt: draft.hasSaleStart ? draft.saleStartAt : Date.distantPast,
                applyDeadlineAt: draft.hasApplyDeadline ? draft.applyDeadlineAt : Date.distantPast,
                resultAnnounceAt: draft.hasResultAnnounce ? draft.resultAnnounceAt : Date.distantPast,
                paymentDeadlineAt: draft.hasPaymentDeadline ? draft.paymentDeadlineAt : Date.distantPast,
                issueStartAt: draft.hasIssueStart ? draft.issueStartAt : Date.distantPast,
                price: decimal(from: draft.priceText),
                fee: decimal(from: draft.feeText),
                quantity: draft.quantity,
                purchaseURL: draft.trimmedPurchaseURL,
                seatText: draft.trimmedSeatText,
                memo: draft.trimmedMemo,
                createdAt: now,
                updatedAt: now,
                plan: plan,
                account: selectedAccount
            )
            modelContext.insert(attempt)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save ticket plan: \(error)")
        }
    }

    private func decimal(from text: String) -> Decimal {
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: digits) ?? Decimal(0)
    }
}

private struct DateToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: $isOn)
            if isOn {
                DatePicker(title, selection: $date)
                    .labelsHidden()
            }
        }
    }
}

private struct TicketPlanDraft {
    var categoryID: UUID?
    var title = ""
    var subtitle = ""
    var startsAt = Date()
    var endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    var opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date()
    var venueName = ""
    var officialURL = ""
    var createsTicketAttempt = true
    var statusKey = "beforeApply"
    var entryRouteKey = ""
    var accountID: UUID?
    var ticketSite = ""
    var holderName = ""
    var hasSaleStart = false
    var saleStartAt = Date()
    var hasApplyDeadline = true
    var applyDeadlineAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var hasResultAnnounce = false
    var resultAnnounceAt = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    var hasPaymentDeadline = false
    var paymentDeadlineAt = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    var hasIssueStart = false
    var issueStartAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var priceText = ""
    var feeText = ""
    var quantity = 1
    var seatText = ""
    var purchaseURL = ""
    var memo = ""

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSubtitle: String { subtitle.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedVenueName: String { venueName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedTicketSite: String { ticketSite.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHolderName: String { holderName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSeatText: String { seatText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPurchaseURL: String { purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    mutating func setInitialCategoryIfNeeded(_ categories: [RecordCategory]) {
        guard categoryID == nil else { return }
        categoryID = categories.first { category in
            category.enabledUnitsRaw.components(separatedBy: ",").contains("ticketPlan")
        }?.id ?? categories.first?.id
    }
}

#Preview {
    AddTicketPlanView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
