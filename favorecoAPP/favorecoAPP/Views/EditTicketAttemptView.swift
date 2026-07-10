//
//  EditTicketAttemptView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData

struct EditTicketAttemptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]

    let plan: Plan
    private let editingAttempt: TicketAttempt?
    @State private var draft: TicketAttemptDraft

    init(plan: Plan, attempt: TicketAttempt? = nil) {
        self.plan = plan
        self.editingAttempt = attempt
        _draft = State(initialValue: TicketAttemptDraft(attempt: attempt))
    }

    private var activeAccounts: [TicketAccount] {
        accounts.filter { !$0.isArchived }
    }

    private var selectedAccount: TicketAccount? {
        activeAccounts.first { $0.id == draft.accountID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("申込") {
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
                }

                Section("日付") {
                    DateToggleRow(title: "申込開始", isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                    DateToggleRow(title: "申込締切", isOn: $draft.hasApplyDeadline, date: $draft.applyDeadlineAt)
                    DateToggleRow(title: "当落発表", isOn: $draft.hasResultAnnounce, date: $draft.resultAnnounceAt)
                    DateToggleRow(title: "入金締切", isOn: $draft.hasPaymentDeadline, date: $draft.paymentDeadlineAt)
                    DateToggleRow(title: "発券開始", isOn: $draft.hasIssueStart, date: $draft.issueStartAt)
                }

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

                Section("メモ") {
                    TextField("メモ", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }

                if editingAttempt != nil {
                    Section {
                        Button(role: .destructive) {
                            archiveAttempt()
                        } label: {
                            Label("この申込を削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editingAttempt == nil ? "申込を追加" : "申込を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
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
        let attempt = editingAttempt ?? TicketAttempt(createdAt: now, plan: plan)
        applyDraft(to: attempt, now: now)

        if editingAttempt == nil {
            modelContext.insert(attempt)
        }

        attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
            plan: plan,
            attempt: attempt
        ).joined(separator: ",")
        plan.updatedAt = now
        plan.stateKey = attempt.statusKey

        do {
            try modelContext.save()
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
            dismiss()
        } catch {
            assertionFailure("Failed to save ticket attempt: \(error)")
        }
    }

    private func archiveAttempt() {
        guard let editingAttempt else { return }
        editingAttempt.isArchived = true
        editingAttempt.updatedAt = Date()
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            TicketNotificationScheduler.cancel(plan: plan, attempt: editingAttempt)
            dismiss()
        } catch {
            assertionFailure("Failed to archive ticket attempt: \(error)")
        }
    }

    private func applyDraft(to attempt: TicketAttempt, now: Date) {
        attempt.statusKey = draft.statusKey
        attempt.entryRouteKey = draft.entryRouteKey
        attempt.ticketSite = draft.trimmedTicketSite
        attempt.holderName = draft.trimmedHolderName
        attempt.saleStartAt = draft.hasSaleStart ? draft.saleStartAt : Date.distantPast
        attempt.applyDeadlineAt = draft.hasApplyDeadline ? draft.applyDeadlineAt : Date.distantPast
        attempt.resultAnnounceAt = draft.hasResultAnnounce ? draft.resultAnnounceAt : Date.distantPast
        attempt.paymentDeadlineAt = draft.hasPaymentDeadline ? draft.paymentDeadlineAt : Date.distantPast
        attempt.issueStartAt = draft.hasIssueStart ? draft.issueStartAt : Date.distantPast
        attempt.price = decimal(from: draft.priceText)
        attempt.fee = decimal(from: draft.feeText)
        attempt.quantity = draft.quantity
        attempt.purchaseURL = draft.trimmedPurchaseURL
        attempt.seatText = draft.trimmedSeatText
        attempt.memo = draft.trimmedMemo
        attempt.updatedAt = now
        attempt.isArchived = false
        attempt.plan = plan
        attempt.account = selectedAccount
    }

    private func decimal(from text: String) -> Decimal {
        Decimal(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Decimal(0)
    }
}

private struct TicketAttemptDraft {
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

    init() {}

    init(attempt: TicketAttempt?) {
        guard let attempt else { return }
        statusKey = attempt.statusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        hasSaleStart = attempt.saleStartAt != Date.distantPast
        saleStartAt = hasSaleStart ? attempt.saleStartAt : Date()
        hasApplyDeadline = attempt.applyDeadlineAt != Date.distantPast
        applyDeadlineAt = hasApplyDeadline ? attempt.applyDeadlineAt : Date()
        hasResultAnnounce = attempt.resultAnnounceAt != Date.distantPast
        resultAnnounceAt = hasResultAnnounce ? attempt.resultAnnounceAt : Date()
        hasPaymentDeadline = attempt.paymentDeadlineAt != Date.distantPast
        paymentDeadlineAt = hasPaymentDeadline ? attempt.paymentDeadlineAt : Date()
        hasIssueStart = attempt.issueStartAt != Date.distantPast
        issueStartAt = hasIssueStart ? attempt.issueStartAt : Date()
        priceText = decimalText(attempt.price)
        feeText = decimalText(attempt.fee)
        quantity = attempt.quantity
        seatText = attempt.seatText
        purchaseURL = attempt.purchaseURL
        memo = attempt.memo
    }

    var trimmedTicketSite: String { ticketSite.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHolderName: String { holderName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSeatText: String { seatText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPurchaseURL: String { purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func decimalText(_ value: Decimal) -> String {
        guard value != Decimal(0) else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}
