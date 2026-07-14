//
//  AddTicketPlanView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData

struct AddTicketPlanView: View {
    enum EntryMode {
        case plan
        case ticketSchedule
    }

    private enum TargetSelectionMode: String, CaseIterable, Identifiable {
        case new
        case interested
        case existingEvent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .new: "新しく登録"
            case .interested: "気になるから選ぶ"
            case .existingEvent: "登録済みから選ぶ"
            }
        }
    }

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Plan.startsAt) private var plans: [Plan]
    @State private var draft = TicketPlanDraft()
    @State private var validationError = ""
    @State private var targetSelectionMode: TargetSelectionMode = .new
    @State private var selectedEventID: UUID?
    @State private var selectedPlanID: UUID?
    @State private var isShowingInterestedEventPicker = false
    @State private var isShowingRegisteredEventPicker = false
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    private let editingPlan: Plan?
    private let targetEvent: ExperienceEvent?
    private let onSave: (() -> Void)?
    private let entryMode: EntryMode

    init(plan: Plan? = nil, entryMode: EntryMode = .ticketSchedule) {
        self.editingPlan = plan
        self.targetEvent = plan?.event
        self.onSave = nil
        self.entryMode = entryMode
        _draft = State(initialValue: TicketPlanDraft(plan: plan, entryMode: entryMode))
        _targetSelectionMode = State(initialValue: entryMode == .ticketSchedule ? .existingEvent : .new)
    }

    init(inboxItem: InboxItem, category: RecordCategory, onSave: (() -> Void)? = nil) {
        self.editingPlan = nil
        self.targetEvent = nil
        self.onSave = onSave
        self.entryMode = .plan
        _draft = State(initialValue: TicketPlanDraft(inboxItem: inboxItem, categoryID: category.id))
    }

    init(event: ExperienceEvent, entryMode: EntryMode = .plan, onSave: (() -> Void)? = nil) {
        self.editingPlan = nil
        self.targetEvent = event
        self.onSave = onSave
        self.entryMode = entryMode
        _draft = State(initialValue: TicketPlanDraft(event: event, entryMode: entryMode))
        _targetSelectionMode = State(initialValue: entryMode == .ticketSchedule ? .existingEvent : .new)
    }

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

    private var interestedEvents: [ExperienceEvent] {
        events.filter { !$0.isArchived && $0.stateKey == "interested" }
    }

    private var activeEvents: [ExperienceEvent] {
        events.filter { !$0.isArchived }
    }

    private var availablePlans: [Plan] {
        plans.filter { !$0.isArchived && $0.visit == nil }
    }

    private var selectedInterestedEvent: ExperienceEvent? {
        interestedEvents.first { $0.id == selectedEventID }
    }

    private var selectedRegisteredEvent: ExperienceEvent? {
        activeEvents.first { $0.id == selectedEventID }
    }

    private var plansForSelectedEvent: [Plan] {
        guard let selectedRegisteredEvent else { return [] }
        return availablePlans.filter { $0.event?.id == selectedRegisteredEvent.id }
    }

    private var selectedExistingPlan: Plan? {
        availablePlans.first { $0.id == selectedPlanID }
    }

    private var resolvedTargetEvent: ExperienceEvent? {
        targetEvent ?? selectedExistingPlan?.event ?? selectedRegisteredEvent ?? selectedInterestedEvent
    }

    private var targetSelectionModes: [TargetSelectionMode] {
        entryMode == .ticketSchedule ? [.new, .existingEvent] : [.new, .interested]
    }

    private var allowsTargetSelection: Bool {
        editingPlan == nil && targetEvent == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if allowsTargetSelection {
                    Section("予定の対象") {
                        Picker("登録方法", selection: $targetSelectionMode) {
                            ForEach(targetSelectionModes) { mode in
                                Text(targetSelectionTitle(mode)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if targetSelectionMode == .existingEvent {
                            if activeEvents.isEmpty {
                                ContentUnavailableView(
                                    "登録済みのイベントがありません",
                                    systemImage: "rectangle.stack.badge.plus",
                                    description: Text("新しいイベントとチケットを登録してください。")
                                )
                            } else {
                                Button {
                                    isShowingRegisteredEventPicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedRegisteredEvent?.category?.iconSymbol ?? "magnifyingglass")
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(selectedRegisteredEvent?.title ?? "登録済みイベントを検索")
                                                .font(FavorecoTypography.bodyStrong)
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)

                                            if let selectedRegisteredEvent {
                                                Text(selectedRegisteredEvent.category?.name ?? "未分類")
                                                    .font(FavorecoTypography.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if selectedRegisteredEvent != nil {
                                    if plansForSelectedEvent.isEmpty {
                                        Label("予定も同時に作成します", systemImage: "calendar.badge.plus")
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Picker("チケットを追加する予定", selection: $selectedPlanID) {
                                            Text("新しい予定を作る").tag(Optional<UUID>.none)
                                            ForEach(plansForSelectedEvent) { plan in
                                                Text(planSelectionDescription(plan)).tag(Optional(plan.id))
                                            }
                                        }
                                    }
                                }
                            }
                        } else if targetSelectionMode == .interested {
                            if interestedEvents.isEmpty {
                                ContentUnavailableView(
                                    "気になる対象がありません",
                                    systemImage: "heart",
                                    description: Text("先にクイック登録するか、新しく対象を登録してください。")
                                )
                            } else {
                                Button {
                                    isShowingInterestedEventPicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedInterestedEvent?.category?.iconSymbol ?? "magnifyingglass")
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(selectedInterestedEvent?.title ?? "作品・対象を検索")
                                                .font(FavorecoTypography.bodyStrong)
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)

                                            if let selectedInterestedEvent {
                                                Text(selectedInterestedEvent.category?.name ?? "未分類")
                                                    .font(FavorecoTypography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(entryMode == .ticketSchedule
                                 ? "新しいイベント、予定、チケット情報をまとめて登録します。"
                                 : "作品・施設などの対象と予定を同時に登録します。")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("予定の基本情報") {
                    if entryMode == .ticketSchedule, let selectedExistingPlan {
                        LabeledContent("ジャンル", value: selectedExistingPlan.category?.name ?? "未設定")
                        LabeledContent("予定", value: selectedExistingPlan.title)
                        LabeledContent("日時", value: selectedExistingPlan.startsAt.formatted(date: .abbreviated, time: .shortened))
                        if !selectedExistingPlan.venueNameSnapshot.isEmpty {
                            LabeledContent("会場", value: selectedExistingPlan.venueNameSnapshot)
                        }
                    } else if let event = resolvedTargetEvent {
                        LabeledContent("ジャンル", value: event.category?.name ?? "未設定")
                    } else {
                        Picker("ジャンル", selection: $draft.categoryID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(visibleCategories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    }

                    if selectedExistingPlan == nil {
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
                }

                Section("申込状況") {
                    if entryMode == .ticketSchedule {
                        LabeledContent("入力内容", value: "チケットスケジュール")
                    } else {
                        Toggle("申込情報も作成", isOn: $draft.createsTicketAttempt)
                    }

                    if draft.createsTicketAttempt {
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
                }

                if draft.createsTicketAttempt && draft.showsAnyTicketMilestone {
                    Section("締切・発券") {
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

                if draft.createsTicketAttempt && draft.showsTicketDetails {
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
            }
            .navigationTitle(navigationTitle)
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
                if editingPlan == nil {
                    draft.setInitialCategoryIfNeeded(visibleCategories)
                }
            }
            .onChange(of: draft.startsAt) { _, newValue in
                if draft.endsAt < newValue {
                    draft.endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: newValue) ?? newValue
                }
                if draft.opensAt > newValue {
                    draft.opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: newValue) ?? newValue
                }
            }
            .onChange(of: targetSelectionMode) { _, newValue in
                selectedEventID = nil
                selectedPlanID = nil
                draft.clearTarget()
                draft.setInitialCategoryIfNeeded(visibleCategories)
            }
            .onChange(of: selectedEventID) { _, _ in
                let event = targetSelectionMode == .existingEvent ? selectedRegisteredEvent : selectedInterestedEvent
                guard let event else { return }
                draft.applyTarget(event)
                if targetSelectionMode == .existingEvent {
                    selectedPlanID = plansForSelectedEvent.first?.id
                    if let selectedExistingPlan {
                        draft.applyTarget(selectedExistingPlan)
                    }
                }
            }
            .onChange(of: selectedPlanID) { _, _ in
                if let plan = selectedExistingPlan {
                    draft.applyTarget(plan)
                } else if targetSelectionMode == .existingEvent, let event = selectedRegisteredEvent {
                    draft.clearTarget()
                    draft.applyTarget(event)
                }
            }
            .alert("入力内容を確認してください", isPresented: Binding(
                get: { !validationError.isEmpty },
                set: { if !$0 { validationError = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError)
            }
            .sheet(isPresented: $isShowingInterestedEventPicker) {
                EventPicker(
                    title: "気になるから選ぶ",
                    searchPrompt: "タイトル・シリーズ・ジャンル",
                    events: interestedEvents,
                    selectedEventID: selectedEventID
                ) { event in
                    selectedEventID = event.id
                    isShowingInterestedEventPicker = false
                }
            }
            .sheet(isPresented: $isShowingRegisteredEventPicker) {
                EventPicker(
                    title: "登録済みイベントから選ぶ",
                    searchPrompt: "タイトル・シリーズ・ジャンル",
                    events: activeEvents,
                    selectedEventID: selectedEventID
                ) { event in
                    selectedEventID = event.id
                    isShowingRegisteredEventPicker = false
                }
            }
        }
    }

    private var navigationTitle: String {
        if editingPlan != nil { return "予定を編集" }
        return draft.createsTicketAttempt ? "チケットスケジュール" : "予定を立てる"
    }

    private func accountLabel(_ account: TicketAccount) -> String {
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(account.serviceName) / \(holder)"
    }

    private func planSelectionDescription(_ plan: Plan) -> String {
        let date = plan.startsAt.formatted(date: .abbreviated, time: .shortened)
        let title = plan.title.isEmpty ? (plan.event?.title ?? "予定") : plan.title
        guard !plan.venueNameSnapshot.isEmpty else { return "\(title) / \(date)" }
        return "\(title) / \(date) / \(plan.venueNameSnapshot)"
    }

    private func targetSelectionTitle(_ mode: TargetSelectionMode) -> String {
        guard entryMode == .ticketSchedule else { return mode.title }
        switch mode {
        case .new: return "新規イベント"
        case .existingEvent: return "登録済みイベント"
        case .interested: return mode.title
        }
    }

    private func save() {
        if allowsTargetSelection,
           targetSelectionMode == .existingEvent,
           selectedRegisteredEvent == nil {
            validationError = "チケット情報を追加するイベントを選んでください。"
            return
        }
        if allowsTargetSelection,
           targetSelectionMode == .interested,
           selectedInterestedEvent == nil {
            validationError = "予定を追加する作品・対象を選んでください。"
            return
        }
        if let validationMessage = draft.validationMessage {
            validationError = validationMessage
            return
        }

        let now = Date()
        if let editingPlan {
            update(plan: editingPlan, now: now)
        } else if entryMode == .ticketSchedule, let selectedExistingPlan {
            createTicketAttempt(on: selectedExistingPlan, now: now)
        } else {
            create(now: now)
        }
    }

    private func create(now: Date) {
        let event = resolvedTargetEvent ?? createTargetEvent(now: now)
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
            category: event.category ?? selectedCategory,
            event: event
        )
        modelContext.insert(plan)
        event.stateKey = "active"
        event.updatedAt = now

        var attemptForScheduling: TicketAttempt?
        if draft.createsTicketAttempt {
            let attempt = makeTicketAttempt(for: plan, now: now)
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
            modelContext.insert(attempt)
            attemptForScheduling = attempt
        }

        do {
            try modelContext.save()
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attemptForScheduling)
            }
            onSave?()
            dismiss()
        } catch {
            modelContext.rollback()
            validationError = "予定を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to save ticket plan: \(error)")
        }
    }

    private func createTicketAttempt(on plan: Plan, now: Date) {
        let attempt = makeTicketAttempt(for: plan, now: now)
        attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
            plan: plan,
            attempt: attempt
        ).joined(separator: ",")
        modelContext.insert(attempt)
        plan.stateKey = draft.statusKey
        plan.updatedAt = now
        plan.event?.stateKey = "active"
        plan.event?.updatedAt = now

        do {
            try modelContext.save()
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
            onSave?()
            dismiss()
        } catch {
            modelContext.rollback()
            validationError = "チケットスケジュールを保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to add ticket attempt: \(error)")
        }
    }

    private func makeTicketAttempt(for plan: Plan, now: Date) -> TicketAttempt {
        TicketAttempt(
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
    }

    private func createTargetEvent(now: Date) -> ExperienceEvent {
        let event = ExperienceEvent(
            title: draft.trimmedTitle,
            officialURL: draft.trimmedOfficialURL,
            stateKey: "active",
            createdAt: now,
            updatedAt: now,
            category: selectedCategory
        )
        modelContext.insert(event)
        return event
    }

    private func update(plan: Plan, now: Date) {
        if plan.event == nil {
            plan.event = createTargetEvent(now: now)
        }
        let existingAttempt = latestAttempt(for: plan)

        plan.title = draft.trimmedTitle
        plan.subtitle = draft.trimmedSubtitle
        plan.stateKey = draft.createsTicketAttempt ? draft.statusKey : "planned"
        plan.startsAt = draft.startsAt
        plan.endsAt = draft.endsAt
        plan.opensAt = draft.opensAt
        plan.venueNameSnapshot = draft.trimmedVenueName
        plan.officialURL = draft.trimmedOfficialURL
        plan.sourceURL = draft.trimmedOfficialURL
        plan.memo = draft.trimmedMemo
        plan.updatedAt = now
        plan.category = plan.event?.category ?? selectedCategory
        plan.event?.stateKey = "active"
        plan.event?.updatedAt = now

        let attemptForScheduling: TicketAttempt?
        if draft.createsTicketAttempt {
            let attempt = existingAttempt ?? TicketAttempt(createdAt: now, plan: plan)
            applyDraft(to: attempt, plan: plan, now: now)
            if existingAttempt == nil {
                modelContext.insert(attempt)
            }
            attempt.notificationSettingsRaw = TicketNotificationScheduler.scheduledIdentifiers(
                plan: plan,
                attempt: attempt
            ).joined(separator: ",")
            attemptForScheduling = attempt
        } else {
            existingAttempt?.isArchived = true
            existingAttempt?.updatedAt = now
            attemptForScheduling = nil
        }

        do {
            try modelContext.save()
            if let existingAttempt, !draft.createsTicketAttempt {
                TicketNotificationScheduler.cancel(plan: plan, attempt: existingAttempt)
            }
            Task {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attemptForScheduling)
                if purchaseManager.currentPlan.includesSync,
                   automaticallyUpdatesExternalCalendar,
                   (ExternalCalendarLinkStore.hasLink(planID: plan.id) || !plan.externalCalendarEventIdentifier.isEmpty) {
                    _ = try? await ExternalCalendarSyncService.update(plan: plan)
                    try? modelContext.save()
                }
            }
            dismiss()
        } catch {
            assertionFailure("Failed to update ticket plan: \(error)")
        }
    }

    private func latestAttempt(for plan: Plan) -> TicketAttempt? {
        plan.ticketAttempts?
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private func applyDraft(to attempt: TicketAttempt, plan: Plan, now: Date) {
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
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: digits) ?? Decimal(0)
    }
}

struct DateToggleRow: View {
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

private struct EventPicker: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let searchPrompt: String
    let events: [ExperienceEvent]
    let selectedEventID: UUID?
    let onSelect: (ExperienceEvent) -> Void

    @State private var searchText = ""

    private var filteredEvents: [ExperienceEvent] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return events }
        return events.filter { event in
            normalized(event.title).contains(query)
                || normalized(event.seriesName).contains(query)
                || normalized(event.category?.name ?? "").contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredEvents.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredEvents) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: event.category?.iconSymbol ?? "rectangle.stack")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(FavorecoTypography.bodyStrong)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(eventDescription(event))
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                                if event.id == selectedEventID {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: searchPrompt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func eventDescription(_ event: ExperienceEvent) -> String {
        let description = [event.category?.name, event.seriesName.isEmpty ? nil : event.seriesName]
            .compactMap { $0 }
            .joined(separator: " / ")
        return description.isEmpty ? "未分類" : description
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
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

    init(entryMode: AddTicketPlanView.EntryMode = .ticketSchedule) {
        createsTicketAttempt = entryMode == .ticketSchedule
    }

    init(inboxItem: InboxItem, categoryID: UUID) {
        self.categoryID = categoryID
        title = inboxItem.title
        officialURL = inboxItem.sourceURL
        memo = inboxItem.body
        createsTicketAttempt = false
    }

    init(event: ExperienceEvent, entryMode: AddTicketPlanView.EntryMode = .plan) {
        categoryID = event.category?.id
        title = event.title
        officialURL = event.officialURL
        memo = event.memo
        createsTicketAttempt = entryMode == .ticketSchedule
    }

    init(plan: Plan?, entryMode: AddTicketPlanView.EntryMode = .ticketSchedule) {
        guard let plan else {
            createsTicketAttempt = entryMode == .ticketSchedule
            return
        }
        let attempt = plan.ticketAttempts?
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        categoryID = plan.category?.id
        title = plan.title
        subtitle = plan.subtitle
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        opensAt = plan.opensAt
        venueName = plan.venueNameSnapshot
        officialURL = plan.officialURL
        createsTicketAttempt = attempt != nil
        memo = plan.memo

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
        memo = attempt.memo.isEmpty ? plan.memo : attempt.memo
    }

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

    var validationMessage: String? {
        if endsAt < startsAt {
            return "終了日時は開始日時以降にしてください。"
        }
        if opensAt > startsAt {
            return "開場日時は開始日時以前にしてください。"
        }
        guard createsTicketAttempt else { return nil }
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

    var showsAnyTicketMilestone: Bool {
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

    mutating func setInitialCategoryIfNeeded(_ categories: [RecordCategory]) {
        guard categoryID == nil else { return }
        categoryID = categories.first { category in
            category.enabledUnitsRaw.components(separatedBy: ",").contains("ticketPlan")
        }?.id ?? categories.first?.id
    }

    mutating func applyTarget(_ event: ExperienceEvent) {
        categoryID = event.category?.id
        title = event.title
        officialURL = event.officialURL
    }

    mutating func applyTarget(_ plan: Plan) {
        categoryID = plan.category?.id
        title = plan.title.isEmpty ? (plan.event?.title ?? "") : plan.title
        subtitle = plan.subtitle
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        opensAt = plan.opensAt
        venueName = plan.venueNameSnapshot
        officialURL = plan.officialURL
    }

    mutating func clearTarget() {
        let now = Date()
        categoryID = nil
        title = ""
        subtitle = ""
        startsAt = now
        endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now
        opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now
        venueName = ""
        officialURL = ""
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

#Preview {
    AddTicketPlanView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
