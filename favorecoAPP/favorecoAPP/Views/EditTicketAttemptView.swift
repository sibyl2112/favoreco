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
    private let prioritizesDates: Bool
    @State private var draft: TicketAttemptDraft
    @State private var validationError = ""
    @State private var operationError = ""
    @State private var isShowingArchiveConfirmation = false

    init(plan: Plan, attempt: TicketAttempt? = nil, prioritizesDates: Bool = false) {
        self.plan = plan
        self.editingAttempt = attempt
        self.prioritizesDates = prioritizesDates
        _draft = State(initialValue: TicketAttemptDraft(attempt: attempt))
    }

    private var activeAccounts: [TicketAccount] {
        accounts
            .filter { !$0.isArchived }
            .sorted {
                if $0.serviceName != $1.serviceName {
                    return $0.serviceName.localizedStandardCompare($1.serviceName) == .orderedAscending
                }
                return $0.accountName.localizedStandardCompare($1.accountName) == .orderedAscending
            }
    }

    private var selectedAccount: TicketAccount? {
        accounts.first { $0.id == draft.accountID }
    }

    private var editorTitle: String {
        editingAttempt == nil ? "チケットを追加" : "チケットを編集"
    }

    private var saveAccentColor: Color {
        if plan.category?.templateKey == "theater" {
            return TheaterCategoryStyle.gold
        }
        return plan.category.map { Color(hex: $0.colorHex) } ?? Color.accentColor
    }

    private var saveForegroundColor: Color {
        plan.category?.templateKey == "theater"
            ? TheaterCategoryStyle.black
            : .white
    }

    var body: some View {
        NavigationStack {
            Form {
                if prioritizesDates {
                    dateFieldsSection
                }

                Section("チケット情報") {
                    Picker("登録内容", selection: $draft.flowKey) {
                        ForEach(draft.flowOptions) { flow in
                            Text(flow.name).tag(flow.key)
                        }
                    }
                    .onChange(of: draft.flowKey) { _, newValue in
                        draft.applyFlowDefaults(newValue)
                    }

                    Text(TicketFlowDefinition.definition(for: draft.flowKey).description)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)

                    if draft.showsEntryRoute {
                        Picker(draft.entryRouteLabel, selection: $draft.entryRouteKey) {
                            Text("未設定").tag("")
                            ForEach(draft.entryRouteOptions) { route in
                                Text(route.name).tag(route.key)
                            }
                        }
                    }

                    if draft.showsAccountFields {
                        Picker("申込アカウント（任意）", selection: $draft.accountID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(activeAccounts) { account in
                                Text(accountLabel(account)).tag(Optional(account.id))
                            }
                        }
                        .onChange(of: draft.accountID) { _, newValue in
                            draft.applyAccount(activeAccounts.first { $0.id == newValue })
                        }

                        TextField("名義（任意）", text: $draft.holderName)
                    }

                    if draft.showsTicketGuide {
                        Picker("購入先", selection: $draft.ticketGuideKey) {
                            ForEach(TicketGuideDefinition.all) { guide in
                                Text(guide.name).tag(guide.key)
                            }
                        }
                        .onChange(of: draft.ticketGuideKey) { _, newValue in
                            draft.applyTicketGuide(newValue)
                        }
                        .disabled(draft.accountID != nil)

                        if draft.ticketGuideKey == TicketGuideDefinition.customKey {
                            TextField("FC・公式サイトなど", text: $draft.ticketSite)
                            TextField("申込・購入URL", text: $draft.purchaseURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        } else {
                            LabeledContent("申込・購入URL", value: draft.purchaseURL.isEmpty ? "未設定" : draft.purchaseURL)
                                .font(FavorecoTypography.caption)
                        }
                    }
                }

                if !prioritizesDates {
                    dateFieldsSection
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

                Section("タグ・メモ") {
                    TextField("任意タグ（カンマ区切り）", text: $draft.tagNamesText)
                    Text("例: S席、第1希望、同行者分")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    TextField("メモ", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }

                if editingAttempt != nil {
                    Section {
                        Button(role: .destructive) {
                            isShowingArchiveConfirmation = true
                        } label: {
                            Label("このチケット情報を非表示", systemImage: "archivebox")
                        }
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .principal) {
                    Text(editorTitle)
                        .font(FavorecoTypography.jpSerif(17, weight: .semibold, relativeTo: .headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .layoutPriority(1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(saveForegroundColor)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(saveAccentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
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
            .confirmationDialog(
                "このチケット情報を非表示にしますか？",
                isPresented: $isShowingArchiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("チケット情報を非表示", role: .destructive) {
                    archiveAttempt()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("予定本体と他のチケット情報は残り、この項目の予約済み通知だけを解除します。")
            }
            .alert("操作を完了できませんでした", isPresented: Binding(
                get: { !operationError.isEmpty },
                set: { if !$0 { operationError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(operationError)
            }
        }
    }

    @ViewBuilder
    private var dateFieldsSection: some View {
        if draft.showsDateSection {
            Section("工程日") {
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
                    DateToggleRow(
                        title: "チケット受取開始（任意）",
                        isOn: $draft.hasIssueStart,
                        date: $draft.issueStartAt
                    )
                }
            }
        }
    }

    private func accountLabel(_ account: TicketAccount) -> String {
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(account.serviceName)｜\(holder)"
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

        let isTerminal = TicketStatusDefinition.isTerminal(attempt.statusKey)
        attempt.notificationSettingsRaw = isTerminal
            ? ""
            : TicketNotificationScheduler.scheduledAttemptIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")

        do {
            try modelContext.save()
            if isTerminal {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            } else {
                Task {
                    await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
                }
            }
            dismiss()
        } catch {
            modelContext.rollback()
            operationError = "申込を保存できませんでした。もう一度お試しください。"
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
            operationError = "申込を非表示にできませんでした。もう一度お試しください。"
            assertionFailure("Failed to archive ticket attempt: \(error)")
        }
    }

    private func applyDraft(to attempt: TicketAttempt, now: Date) {
        attempt.statusKey = draft.resolvedStatusKey
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
        attempt.unitFieldsRaw = draft.ticketUnitFieldsRaw
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
    var tagNamesText = ""
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
        tagNamesText = TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames.joined(separator: ", ")
        purchaseURL = attempt.purchaseURL
        memo = attempt.memo
    }

    var trimmedTicketSite: String { ticketSite.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHolderName: String { holderName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSeatText: String { seatText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var ticketUnitFieldsRaw: String {
        TicketAttemptUnitFields(
            tagNames: TicketAttemptUnitFields.normalizedTagNames(from: tagNamesText)
        ).encodedRawValue
    }
    var trimmedPurchaseURL: String { purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
    var resolvedStatusKey: String {
        flowKey == "acquired" ? "issued" : statusKey
    }

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

    var flowOptions: [TicketFlowDefinition] {
        if flowKey == "interested",
           let interested = TicketFlowDefinition.all.first(where: { $0.key == "interested" }) {
            return [interested] + TicketFlowDefinition.registrationOptions
        }
        return TicketFlowDefinition.registrationOptions
    }

    var showsEntryRoute: Bool {
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
    }

    var showsAccountFields: Bool {
        flowKey == "lotteryPlanned"
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
        flowKey == "lotteryPlanned"
    }

    var showsIssueStart: Bool {
        flowKey == "saleWaiting"
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

    var entryRouteLabel: String {
        flowKey == "lotteryPlanned" ? "申込枠" : "販売方法"
    }

    var entryRouteOptions: [TicketEntryRouteDefinition] {
        switch flowKey {
        case "lotteryPlanned":
            return TicketEntryRouteDefinition.all.filter {
                ["fanClub", "official", "lottery", "card", "generalLottery", "other"].contains($0.key)
            }
        case "saleWaiting":
            return TicketEntryRouteDefinition.all.filter {
                ["presale", "general", "resale", "other"].contains($0.key)
            }
        default:
            return []
        }
    }

    mutating func applyFlowDefaults(_ key: String) {
        let flow = TicketFlowDefinition.definition(for: key)
        flowKey = flow.key
        statusKey = flow.defaultStatusKey
        if flow.key != "acquired",
           (entryRouteKey.isEmpty || !entryRouteOptions.contains(where: { $0.key == entryRouteKey })) {
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
        default:
            break
        }
    }

    mutating func applyTicketGuide(_ key: String) {
        guard accountID == nil else { return }
        guard let guide = TicketGuideDefinition.guide(for: key) else {
            ticketGuideKey = TicketGuideDefinition.customKey
            return
        }
        ticketSite = guide.name
        purchaseURL = guide.urlString
    }

    mutating func applyAccount(_ account: TicketAccount?) {
        guard let account else { return }
        let serviceName = account.serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let siteURL = account.siteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        accountID = account.id
        ticketSite = serviceName
        holderName = account.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        ticketGuideKey = TicketGuideDefinition.inferredKey(
            siteName: serviceName,
            urlString: siteURL
        )
        purchaseURL = !siteURL.isEmpty
            ? siteURL
            : (TicketGuideDefinition.guide(for: ticketGuideKey)?.urlString ?? "")
    }

    private func decimalText(_ value: Decimal) -> String {
        guard value != Decimal(0) else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}
