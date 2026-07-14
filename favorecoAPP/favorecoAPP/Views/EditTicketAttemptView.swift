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
    @State private var validationError = ""

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
                    Picker("今の状態", selection: $draft.flowKey) {
                        ForEach(TicketFlowDefinition.all) { flow in
                            Text(flow.name).tag(flow.key)
                        }
                    }
                    .onChange(of: draft.flowKey) { _, newValue in
                        draft.applyFlowDefaults(newValue)
                    }

                    Text(TicketFlowDefinition.definition(for: draft.flowKey).description)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)

                    if draft.showsDetailedStatus {
                        Picker("詳細状態", selection: $draft.statusKey) {
                            ForEach(draft.statusOptions) { status in
                                Text(status.name).tag(status.key)
                            }
                        }
                    }

                    if draft.showsEntryRoute {
                        Picker("区分", selection: $draft.entryRouteKey) {
                            Text("未設定").tag("")
                            ForEach(draft.entryRouteOptions) { route in
                                Text(route.name).tag(route.key)
                            }
                        }
                    }

                    if draft.showsAccountFields {
                        Picker("名義・アカウント", selection: $draft.accountID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(activeAccounts) { account in
                                Text(accountLabel(account)).tag(Optional(account.id))
                            }
                        }

                        TextField("名義メモ", text: $draft.holderName)
                    }

                    if draft.showsTicketGuide {
                        Picker("プレイガイド", selection: $draft.ticketGuideKey) {
                            ForEach(TicketGuideDefinition.all) { guide in
                                Text(guide.name).tag(guide.key)
                            }
                        }
                        .onChange(of: draft.ticketGuideKey) { _, newValue in
                            draft.applyTicketGuide(newValue)
                        }

                        if draft.ticketGuideKey == TicketGuideDefinition.customKey {
                            TextField("購入先・サイト名", text: $draft.ticketSite)
                            TextField("申込・購入URL", text: $draft.purchaseURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        } else {
                            LabeledContent("申込・購入URL", value: draft.purchaseURL.isEmpty ? "未設定" : draft.purchaseURL)
                                .font(FavorecoTypography.caption)
                        }
                    }
                }

                if draft.showsDateSection {
                    Section("日付") {
                        if draft.showsSaleStart {
                            DateToggleRow(title: draft.saleStartLabel, isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                        }
                        if draft.showsApplyDeadline {
                            DateToggleRow(title: "申込締切", isOn: $draft.hasApplyDeadline, date: $draft.applyDeadlineAt)
                        }
                        if draft.showsResultAnnounce {
                            DateToggleRow(title: "当落発表", isOn: $draft.hasResultAnnounce, date: $draft.resultAnnounceAt)
                        }
                        if draft.showsPaymentDeadline {
                            DateToggleRow(title: "入金締切", isOn: $draft.hasPaymentDeadline, date: $draft.paymentDeadlineAt)
                        }
                        if draft.showsIssueStart {
                            DateToggleRow(title: "発券開始", isOn: $draft.hasIssueStart, date: $draft.issueStartAt)
                        }
                    }
                }

                if draft.showsTicketDetails {
                    Section("金額・座席") {
                    TextField("チケット代", text: $draft.priceText)
                        .keyboardType(.numberPad)
                    TextField("手数料", text: $draft.feeText)
                        .keyboardType(.numberPad)
                    Stepper("枚数 \(draft.quantity)", value: $draft.quantity, in: 1...20)
                    TextField("座席・整理番号", text: $draft.seatText, axis: .vertical)
                        .lineLimit(2...4)
                    }
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
            .alert("日付を確認してください", isPresented: Binding(
                get: { !validationError.isEmpty },
                set: { if !$0 { validationError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError)
            }
        }
    }

    private func accountLabel(_ account: TicketAccount) -> String {
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(account.serviceName) / \(holder)"
    }

    private func save() {
        if let validationMessage = draft.validationMessage {
            validationError = validationMessage
            return
        }

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
        do {
            try TicketAttemptStatusUpdater.archive(
                attempt: editingAttempt,
                in: modelContext
            )
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
    var flowKey = "lotteryPlanned"
    var statusKey = "beforeApply"
    var entryRouteKey = ""
    var accountID: UUID?
    var ticketGuideKey = TicketGuideDefinition.customKey
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
        flowKey = TicketFlowDefinition.inferredKey(statusKey: attempt.statusKey, entryRouteKey: attempt.entryRouteKey)
        statusKey = attempt.statusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketGuideKey = TicketGuideDefinition.inferredKey(siteName: attempt.ticketSite, urlString: attempt.purchaseURL)
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

    var validationMessage: String? {
        if hasSaleStart && hasApplyDeadline && saleStartAt > applyDeadlineAt {
            return "申込開始は申込締切以前にしてください。"
        }
        if hasApplyDeadline && hasResultAnnounce && applyDeadlineAt > resultAnnounceAt {
            return "当落発表は申込締切以降にしてください。"
        }
        if hasResultAnnounce && hasPaymentDeadline && resultAnnounceAt > paymentDeadlineAt {
            return "入金締切は当落発表以降にしてください。"
        }
        return nil
    }

    var showsDetailedStatus: Bool {
        flowKey == "acquired"
    }

    var showsEntryRoute: Bool {
        flowKey != "interested"
    }

    var showsAccountFields: Bool {
        flowKey != "interested"
    }

    var showsTicketGuide: Bool {
        flowKey != "interested"
    }

    var showsSaleStart: Bool {
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
    }

    var showsApplyDeadline: Bool {
        flowKey == "lotteryPlanned"
    }

    var showsResultAnnounce: Bool {
        flowKey == "lotteryPlanned"
    }

    var showsPaymentDeadline: Bool {
        flowKey == "lotteryPlanned" || flowKey == "acquired"
    }

    var showsIssueStart: Bool {
        flowKey == "saleWaiting" || flowKey == "acquired"
    }

    var showsDateSection: Bool {
        showsSaleStart || showsApplyDeadline || showsResultAnnounce || showsPaymentDeadline || showsIssueStart
    }

    var showsTicketDetails: Bool {
        flowKey == "acquired"
    }

    var saleStartLabel: String {
        flowKey == "saleWaiting" ? "発売開始" : "申込開始"
    }

    var statusOptions: [TicketStatusDefinition] {
        switch flowKey {
        case "acquired":
            return TicketStatusDefinition.all.filter { ["won", "waitingPayment", "waitingIssue", "issued", "attended"].contains($0.key) }
        default:
            return TicketStatusDefinition.all.filter { $0.key == TicketFlowDefinition.definition(for: flowKey).defaultStatusKey }
        }
    }

    var entryRouteOptions: [TicketEntryRouteDefinition] {
        switch flowKey {
        case "lotteryPlanned":
            return TicketEntryRouteDefinition.all.filter { ["fanClub", "lottery", "card", "other"].contains($0.key) }
        case "saleWaiting":
            return TicketEntryRouteDefinition.all.filter { ["general", "sameDay", "resale", "other"].contains($0.key) }
        case "acquired":
            return TicketEntryRouteDefinition.all
        default:
            return []
        }
    }

    mutating func applyFlowDefaults(_ key: String) {
        let flow = TicketFlowDefinition.definition(for: key)
        flowKey = flow.key
        statusKey = flow.defaultStatusKey
        if entryRouteKey.isEmpty || !entryRouteOptions.contains(where: { $0.key == entryRouteKey }) {
            entryRouteKey = flow.defaultEntryRouteKey
        }

        switch flow.key {
        case "interested":
            hasSaleStart = false
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
            hasIssueStart = false
            priceText = ""
            feeText = ""
            seatText = ""
            purchaseURL = ""
        case "lotteryPlanned":
            hasApplyDeadline = true
            hasResultAnnounce = true
            hasIssueStart = false
        case "saleWaiting":
            hasSaleStart = true
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
        case "acquired":
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasIssueStart = true
        default:
            break
        }
    }

    mutating func applyTicketGuide(_ key: String) {
        guard let guide = TicketGuideDefinition.guide(for: key) else {
            ticketGuideKey = TicketGuideDefinition.customKey
            return
        }
        ticketSite = guide.name
        purchaseURL = guide.urlString
    }

    private func decimalText(_ value: Decimal) -> String {
        guard value != Decimal(0) else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}
