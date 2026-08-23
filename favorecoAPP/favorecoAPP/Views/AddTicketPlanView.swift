//
//  AddTicketPlanView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

enum TheaterLifecycleRegistrationPurpose: String, CaseIterable, Identifiable {
    case interested
    case plan
    case application
    case acquired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interested: "気になる"
        case .plan: "予定"
        case .application: "申込"
        case .acquired: "取得済み"
        }
    }
}

struct AddTicketPlanView: View {
    typealias EntryMode = TicketPlanEntryMode

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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Plan.startsAt) private var plans: [Plan]
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @StateObject private var publicPlaceStore = PublicPlaceCatalogStore.shared
    @State private var draft = TicketPlanDraft()
    @State private var unifiedPurpose: TheaterLifecycleRegistrationPurpose = .interested
    @State private var additionalApplications: [AdditionalTicketApplicationDraft] = []
    @State private var validationError = ""
    @State private var targetSelectionMode: TargetSelectionMode = .new
    @State private var selectedEventID: UUID?
    @State private var selectedPlanID: UUID?
    @State private var isShowingInterestedEventPicker = false
    @State private var isShowingRegisteredEventPicker = false
    @State private var isShowingRecurringEventCatalog = false
    @State private var selectedRecurringEventEdition: PublicRecurringEventEdition?
    @State private var pendingSelectedEventID: UUID?
    @State private var isShowingPlaceSearch = false
    @State private var suppressesPlaceSuggestions = false
    @State private var savedTheaterPlan: Plan?
    @State private var ticketPlanForNextStep: Plan?
    @State private var isShowingAfterPlanSaveActions = false
    @State private var savedTicketEvent: ExperienceEvent?
    @State private var savedTicketSchedulePlan: Plan?
    @State private var savedTicketAttempt: TicketAttempt?
    @State private var planForAdditionalTicketAttempt: Plan?
    @State private var eventForAdditionalTicketSchedule: ExperienceEvent?
    @State private var isShowingAfterTicketSaveActions = false
    @State private var selectedTicketOCRItems: [PhotosPickerItem] = []
    @State private var isShowingInformationImageSource = false
    @State private var isShowingInformationImagePicker = false
    @State private var isShowingInformationCamera = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var selectedEventEyecatchItem: PhotosPickerItem?
    @State private var eventEyecatchData: Data?
    @State private var isShowingEventEyecatchCamera = false
    @State private var isReadingTicketImage = false
    @State private var ticketOCRStatus = ""
    @State private var pastedTicketText = ""
    @State private var isShowingTicketTextImport = false
    @State private var isShowingPerformanceURLImport = false
    @State private var performanceImportURL = ""
    @State private var performanceImportStatus = ""
    @State private var isFetchingPerformanceURL = false
    @State private var isShowingEventBackgroundPicker = false
    @State private var eventHeroBackgroundPath = ""
    @State private var eventHeroBackgroundPresetKey = ""
    @State private var ticketImportCandidates: [PendingTicketOCRImport] = []
    @State private var isShowingTicketImportReview = false
    @State private var batchImportedScheduleDrafts: [TicketPlanDraft] = []
    @State private var isApplicationDetailsExpanded = false
    @State private var isUnifiedWorkExpanded = true
    @State private var isUnifiedVisualExpanded = false
    @State private var isUnifiedParticipationExpanded = false
    @State private var isUnifiedTicketExpanded = false
    @State private var isUnifiedMemoExpanded = false
    @State private var isPlanBasicExpanded = true
    @State private var isPlanMemoriesExpanded = false
    @State private var isPlanNotesExpanded = false
    @State private var didConfigurePlanLifecycleExpansion = false
    @State private var planPendingPhotos: [PendingPhoto] = []
    @State private var planPendingPeople: [PendingPersonLink] = []
    @State private var eventPendingPeople: [PendingPersonLink] = []
    @State private var deletedEventPersonLinkIDs: Set<UUID> = []
    @State private var isUnifiedCastExpanded = true
    @State private var selectedPlanPhotoItems: [PhotosPickerItem] = []
    @State private var deletedPlanPhotoIDs: Set<UUID> = []
    @State private var existingPlanPhotoMetadata: [UUID: PhotoMetadataDraft] = [:]
    @State private var planPhotoAspectRatioKey = "square"
    @State private var planCoverPhotoPath = ""
    @State private var planHeroBackgroundPath = ""
    @State private var planHeroBackgroundPresetKey = ""
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    private let editingPlan: Plan?
    private let targetEvent: ExperienceEvent?
    private let onSave: (() -> Void)?
    private let entryMode: EntryMode
    private let initialCategoryID: UUID?
    private let simpleRegistrationPurpose: Binding<SimpleCategoryRegistrationPurpose>?

    init(
        plan: Plan? = nil,
        entryMode: EntryMode = .ticketSchedule,
        initialCategoryID: UUID? = nil,
        initialPlaceMaster: PlaceMaster? = nil,
        initialUnifiedPurpose: TheaterLifecycleRegistrationPurpose = .interested,
        simpleRegistrationPurpose: Binding<SimpleCategoryRegistrationPurpose>? = nil
    ) {
        self.editingPlan = plan
        self.targetEvent = plan?.event
        self.onSave = nil
        self.entryMode = entryMode
        self.initialCategoryID = plan?.category?.id ?? initialCategoryID
        self.simpleRegistrationPurpose = simpleRegistrationPurpose
        var initialDraft = TicketPlanDraft(plan: plan, entryMode: entryMode)
        if plan == nil {
            initialDraft.categoryID = initialCategoryID
            if let initialPlaceMaster {
                initialDraft.applyDestination(placeMaster: initialPlaceMaster)
            }
        }
        _draft = State(initialValue: initialDraft)
        _unifiedPurpose = State(initialValue: initialUnifiedPurpose)
        _planPendingPeople = State(initialValue: initialDraft.planPeople.map(\.pendingPersonLink))
        _eventEyecatchData = State(initialValue: plan?.event?.eyecatchData)
        _eventHeroBackgroundPresetKey = State(
            initialValue: VisitUnitFields(rawValue: plan?.event?.unitFieldsRaw ?? "").heroBackgroundPresetKey
        )
        _eventHeroBackgroundPath = State(
            initialValue: VisitUnitFields(rawValue: plan?.event?.unitFieldsRaw ?? "").heroBackgroundPath
        )
        _targetSelectionMode = State(initialValue: entryMode == .ticketSchedule ? .existingEvent : .new)
    }

    init(inboxItem: InboxItem, category: RecordCategory, onSave: (() -> Void)? = nil) {
        self.editingPlan = nil
        self.targetEvent = nil
        self.onSave = onSave
        self.entryMode = .plan
        self.initialCategoryID = category.id
        self.simpleRegistrationPurpose = nil
        _draft = State(initialValue: TicketPlanDraft(inboxItem: inboxItem, categoryID: category.id))
        _eventEyecatchData = State(initialValue: nil)
        _eventHeroBackgroundPath = State(initialValue: "")
        _eventHeroBackgroundPresetKey = State(initialValue: "")
    }

    init(
        event: ExperienceEvent,
        entryMode: EntryMode = .plan,
        continuingApplication: TicketAttempt? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.editingPlan = nil
        self.targetEvent = event
        self.onSave = onSave
        self.entryMode = entryMode
        self.initialCategoryID = event.category?.id
        self.simpleRegistrationPurpose = nil
        _draft = State(
            initialValue: TicketPlanDraft(
                event: event,
                entryMode: entryMode,
                continuingApplication: continuingApplication
            )
        )
        _eventEyecatchData = State(initialValue: event.eyecatchData)
        _eventHeroBackgroundPresetKey = State(
            initialValue: VisitUnitFields(rawValue: event.unitFieldsRaw).heroBackgroundPresetKey
        )
        _eventHeroBackgroundPath = State(
            initialValue: VisitUnitFields(rawValue: event.unitFieldsRaw).heroBackgroundPath
        )
        _targetSelectionMode = State(initialValue: entryMode == .ticketSchedule ? .existingEvent : .new)
    }

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
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

    private var selectedCategory: RecordCategory? {
        visibleCategories.first { $0.id == draft.categoryID }
    }

    /// 登録対象を切り替えても、フォーム内の見出し・選択状態・主要操作色を
    /// そのジャンルのキーカラーへ即時に揃える。
    private var registrationPalette: FavorecoThemePalette {
        guard let colorHex = (resolvedTargetEvent?.category ?? selectedCategory)?.colorHex else {
            return themePalette
        }
        return themePalette.scopedForRegistration(categoryHex: colorHex)
    }

    private var usesOpeningTime: Bool {
        (resolvedTargetEvent?.category ?? selectedCategory)?.usesOpeningTime == true
    }

    private var selectedAccount: TicketAccount? {
        accounts.first { $0.id == draft.accountID }
    }

    private func selectedAccount(for draft: TicketPlanDraft) -> TicketAccount? {
        accounts.first { $0.id == draft.accountID }
    }

    private var interestedEvents: [ExperienceEvent] {
        events.filter {
            !$0.isArchived
                && $0.stateKey == "interested"
                && (draft.categoryID == nil || $0.category?.id == draft.categoryID)
        }
    }

    private var activeEvents: [ExperienceEvent] {
        events.filter { !$0.isArchived }
    }

    private var interestedEventPickerItems: [EventPickerItem] {
        interestedEvents.map(EventPickerItem.init)
    }

    private var activeEventPickerItems: [EventPickerItem] {
        registeredTargetEvents.map(EventPickerItem.init)
    }

    private var availablePlans: [Plan] {
        plans.filter { !$0.isArchived && $0.visit == nil }
    }

    private var selectedInterestedEvent: ExperienceEvent? {
        interestedEvents.first { $0.id == selectedEventID }
    }

    private var selectedRegisteredEvent: ExperienceEvent? {
        registeredTargetEvents.first { $0.id == selectedEventID }
    }

    private var registeredTargetEvents: [ExperienceEvent] {
        guard entryMode == .plan, let categoryID = draft.categoryID else { return activeEvents }
        return activeEvents.filter { $0.category?.id == categoryID }
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

    private var visibleEventCreditLinks: [EventPersonLink] {
        let roleKeys = Set(PersonRoleOption.theaterEvent.map(\.key))
        return (resolvedTargetEvent?.personLinks ?? [])
            .filter {
                !$0.isArchived
                    && $0.visit == nil
                    && !deletedEventPersonLinkIDs.contains($0.id)
                    && roleKeys.contains($0.roleKey)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var targetSelectionModes: [TargetSelectionMode] {
        if entryMode == .unified {
            return [.new, .existingEvent]
        }
        if entryMode == .ticketSchedule {
            return [.new, .existingEvent]
        }
        if ["theme_park", "nature_living", "outing_facility"].contains(selectedCategory?.templateKey ?? "") {
            return [.new, .existingEvent]
        }
        return [.new, .interested]
    }

    private var allowsTargetSelection: Bool {
        editingPlan == nil && targetEvent == nil
    }

    private var editsPlanOnly: Bool {
        editingPlan != nil && entryMode == .plan
    }

    private var showsTicketRegistrationSections: Bool {
        !editsPlanOnly && (isUnifiedRegistration || entryMode == .ticketSchedule)
    }

    private var showsTicketApplicationDetails: Bool {
        !isUnifiedRegistration || unifiedPurpose == .application
    }

    private var isUnifiedRegistration: Bool {
        entryMode == .unified
    }

    private var usesFlatTicketSchedule: Bool {
        entryMode == .ticketSchedule && !editsPlanOnly
    }

    private var selectedEntryRouteName: String {
        draft.entryRouteOptions.first(where: { $0.key == draft.entryRouteKey })?.name ?? "未設定"
    }

    private var isInterestedOnly: Bool {
        isUnifiedRegistration && unifiedPurpose == .interested
    }

    private var usesPlanRegistration: Bool {
        entryMode == .plan || (isUnifiedRegistration && unifiedPurpose == .plan)
    }

    private var isSimpleDestinationPlan: Bool {
        entryMode == .plan
            && ["theme_park", "nature_living", "outing_facility"].contains(selectedCategory?.templateKey ?? "")
    }

    private var isSimpleViewingPlan: Bool {
        entryMode == .plan
            && ["movie", "museum"].contains(selectedCategory?.templateKey ?? "")
    }

    private var isSimplePlan: Bool {
        isSimpleDestinationPlan || isSimpleViewingPlan
    }

    private var destinationTargetName: String {
        switch selectedCategory?.templateKey {
        case "theme_park": "施設"
        case "nature_living": "スポット"
        case "outing_facility": "施設"
        case "movie": "作品"
        case "museum": "展示・イベント"
        default: "対象"
        }
    }

    private var destinationTargetFieldTitle: String {
        destinationTargetName + "名"
    }

    private var simplePlanTitleFieldTitle: String {
        switch selectedCategory?.templateKey {
        case "movie": "作品名"
        case "museum": "展示・イベント名"
        default: "予定名"
        }
    }

    private var simplePlanTitlePrompt: String {
        switch selectedCategory?.templateKey {
        case "movie": "観る作品名を入力"
        case "museum": "展示・イベント名を入力"
        default: "例：植物園へ行く"
        }
    }

    private var planBasicTitleFieldTitle: String {
        "\(isSimplePlan ? simplePlanTitleFieldTitle : "公演・イベント名")（必須）"
    }

    private var planBasicTitleFieldPrompt: String {
        isSimplePlan ? simplePlanTitlePrompt : "公演・イベント名を入力"
    }

    private var simpleScheduleSectionTitle: String {
        switch selectedCategory?.templateKey {
        case "movie": "観る日時"
        case "museum": "鑑賞日時"
        default: "行く日時"
        }
    }

    private var simpleScheduleDateLabel: String {
        switch selectedCategory?.templateKey {
        case "movie", "museum": "鑑賞日"
        default: "訪問日"
        }
    }

    private var usesTicketRegistration: Bool {
        entryMode == .ticketSchedule
            || (isUnifiedRegistration
                && (unifiedPurpose == .application || unifiedPurpose == .acquired))
    }

    private var unifiedApplicationFlowOptions: [TicketFlowDefinition] {
        TicketFlowDefinition.registrationOptions.filter {
            $0.key == "lotteryPlanned" || $0.key == "saleWaiting"
        }
    }

    private var unifiedPurposePicker: some View {
        HStack(spacing: 4) {
            ForEach(TheaterLifecycleRegistrationPurpose.allCases) { purpose in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        unifiedPurpose = purpose
                    }
                } label: {
                    Text(purpose.title)
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(unifiedPurpose == purpose ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            unifiedPurpose == purpose ? Color(hex: "#8B2F45") : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private var unifiedRegistrationScreen: some View {
        VStack(spacing: 0) {
            flatNavigationHeader(title: "公演・チケットを登録")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    unifiedStatusUnit
                    unifiedWorkUnit
                    if !isInterestedOnly {
                        unifiedParticipationUnit
                    }
                    if usesTicketRegistration {
                        unifiedTicketUnit
                    }
                    unifiedMemoUnit
                    unifiedCastUnit
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TheaterLifecycleFlatStyle.canvasBackground)
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(.xSmall ... .large)
    }

    private func flatNavigationHeader(title: String) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("キャンセル")

            Spacer(minLength: 0)
            Text(title)
                .font(FavorecoTypography.jpSans(18, weight: .semibold, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)

            Button("保存") { save() }
                .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(width: 62, height: 44)
                .background(Color(hex: "#8B2F45"), in: RoundedRectangle(cornerRadius: 11))
                .opacity(draft.canSave ? 1 : 0.38)
                .disabled(!draft.canSave)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(TheaterLifecycleFlatStyle.fieldBackground)
    }

    private var ticketScheduleFlatScreen: some View {
        VStack(spacing: 0) {
            flatNavigationHeader(title: "チケットスケジュール")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ticketScheduleImportUnit
                    ticketScheduleTargetUnit
                    ticketSchedulePerformanceUnit
                    ticketScheduleParticipationUnit
                    ticketScheduleTicketUnit
                    ticketScheduleMemoUnit
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TheaterLifecycleFlatStyle.canvasBackground)
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(.xSmall ... .large)
    }

    private var ticketScheduleImportUnit: some View {
        VStack(alignment: .leading, spacing: 12) {
            theaterFlatSectionHeader(
                "入力方法",
                isExpanded: nil,
                info: "画像や案内メールから読み取るほか、下の各項目へ直接入力できます。"
            )
            unifiedWorkImportActions
        }
    }

    private var ticketScheduleTargetUnit: some View {
        VStack(alignment: .leading, spacing: 14) {
            theaterFlatSectionHeader("予定の対象", isExpanded: nil)
            if allowsTargetSelection {
                registeredTargetSelectionContent
                    .padding(.horizontal, 14)
                    .frame(minHeight: 54)
                    .background(
                        TheaterLifecycleFlatStyle.fieldBackground,
                        in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
            } else if let event = resolvedTargetEvent {
                theaterFlatReadOnlyField("公演", value: event.title)
            }
        }
    }

    private var ticketSchedulePerformanceUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader(
                "公演の基本情報",
                isExpanded: nil,
                info: resolvedTargetEvent == nil
                    ? nil
                    : "公演そのものの情報を変更する場合は、公演情報の編集画面から編集します。"
            )
            if let event = resolvedTargetEvent {
                theaterFlatReadOnlyField("ジャンル", value: event.category?.name ?? "未設定")
                theaterFlatReadOnlyField("公演名", value: event.title)
                if !event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    theaterFlatReadOnlyField("シリーズ・ツアー名", value: event.seriesName)
                }
                if !event.officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    theaterFlatReadOnlyField("公式URL", value: event.officialURL)
                }
            } else {
                theaterFlatTextField("公演名", required: true, prompt: "公演・イベント名を入力", text: $draft.title)
                theaterFlatTextField("サブタイトル", prompt: "任意", text: $draft.subtitle)
                theaterFlatTextField("公式URL", prompt: "https://", text: $draft.officialURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var ticketScheduleParticipationUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader("観劇予定日・会場", isExpanded: nil)
            if let selectedExistingPlan {
                theaterFlatReadOnlyField(
                    "日時",
                    value: selectedExistingPlan.hasConfirmedSchedule
                        ? FavorecoDateText.compactDateTime(selectedExistingPlan.startsAt)
                        : "未定"
                )
                if !selectedExistingPlan.venueNameSnapshot.isEmpty {
                    theaterFlatReadOnlyField("会場", value: selectedExistingPlan.venueNameSnapshot)
                }
            } else {
                theaterFlatBooleanChoice(
                    title: "日程は決まっていますか？",
                    falseTitle: "未定",
                    trueTitle: "決まっている",
                    selection: $draft.hasConfirmedSchedule
                )
                if draft.hasConfirmedSchedule {
                    theaterFlatDateField("観劇日", selection: scheduleDateBinding)
                    HStack(alignment: .top, spacing: 12) {
                        if draft.hasOpeningTime {
                            theaterFlatTimeField("開場", selection: openingTimeBinding) {
                                draft.hasOpeningTime = false
                            }
                        } else {
                            theaterFlatAddTimeButton("＋ 開場時間を追加") {
                                draft.opensAt = defaultOpeningTime
                                draft.hasOpeningTime = true
                            }
                        }
                        theaterFlatTimeField("開演", selection: startTimeBinding)
                    }
                    theaterFlatTimeField("終了", selection: endTimeBinding)
                    theaterFlatTextField("会場", prompt: "会場名を入力すると候補を表示", text: venueNameBinding)
                    Button { isShowingPlaceSearch = true } label: {
                        Label("会場を検索", systemImage: "map")
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(Color(hex: "#8B2F45"))
                    }
                    .buttonStyle(.plain)
                    theaterFlatTextField("住所", prompt: "住所を入力", text: venueAddressBinding)
                    PlaceMapPreview(
                        venueName: draft.venueName,
                        address: draft.venueAddress,
                        latitude: draft.latitude,
                        longitude: draft.longitude
                    )
                } else {
                    Text("未定の予定はComing Up・カレンダーに表示されません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ticketScheduleTicketUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader("チケット情報", isExpanded: nil)
            theaterFlatMenuField(
                "登録内容",
                required: true,
                value: TicketFlowDefinition.definition(for: draft.flowKey).name
            ) {
                ForEach(draft.flowOptions) { flow in
                    Button(flow.name) {
                        draft.flowKey = flow.key
                        draft.applyFlowDefaults(flow.key)
                    }
                }
            }

            ticketScheduleApplicationFields

            if draft.createsTicketAttempt && draft.showsAnyTicketMilestone {
                theaterFlatSubheading("チケットスケジュール")
                TheaterLifecycleInfoButton(text: "分かる工程日だけ登録できます。未定の日程は追加せずに保存できます。")
                if draft.showsSaleStart {
                    theaterFlatOptionalDateTimeField(draft.saleStartLabel, isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                }
                if draft.showsApplyDeadline {
                    theaterFlatOptionalDateTimeField("抽選申込締切", isOn: $draft.hasApplyDeadline, date: $draft.applyDeadlineAt)
                }
                if draft.showsResultAnnounce {
                    theaterFlatOptionalDateTimeField("当落発表", isOn: $draft.hasResultAnnounce, date: $draft.resultAnnounceAt)
                }
                if draft.showsPaymentDeadline {
                    theaterFlatOptionalDateTimeField("支払締切", isOn: $draft.hasPaymentDeadline, date: $draft.paymentDeadlineAt)
                }
                if draft.showsIssueStart {
                    theaterFlatOptionalDateTimeField("チケット受取開始", isOn: $draft.hasIssueStart, date: $draft.issueStartAt)
                }
            }

            if draft.createsTicketAttempt && draft.showsTicketDetails {
                theaterFlatSubheading("金額・座席")
                HStack(alignment: .top, spacing: 12) {
                    theaterFlatTextField("チケット代", prompt: "例：12,800", text: $draft.priceText)
                        .keyboardType(.numberPad)
                    theaterFlatQuantityField
                }
                theaterFlatTextField("手数料", prompt: "金額", text: $draft.feeText)
                    .keyboardType(.numberPad)
                theaterFlatTextField("座席", prompt: "座席・整理番号", text: $draft.seatText)
            }
        }
    }

    @ViewBuilder
    private var ticketScheduleApplicationFields: some View {
        if draft.showsEntryRoute {
            theaterFlatMenuField(draft.entryRouteLabel, value: selectedEntryRouteName) {
                Button("未設定") { draft.entryRouteKey = "" }
                ForEach(draft.entryRouteOptions) { route in
                    Button(route.name) { draft.entryRouteKey = route.key }
                }
            }
        }
        if draft.showsAccountFields {
            theaterFlatMenuField(
                "申込アカウント",
                value: selectedAccount.map(accountLabel) ?? "未設定"
            ) {
                Button("未設定") { draft.accountID = nil }
                ForEach(activeAccounts) { account in
                    Button(accountLabel(account)) {
                        draft.applyAccount(account, replacing: selectedAccount)
                    }
                }
            }
            theaterFlatTextField("名義", prompt: "任意", text: $draft.holderName)
        }
        if draft.showsTicketGuide {
            theaterFlatMenuField(
                "購入先",
                value: TicketGuideDefinition.guide(for: draft.ticketGuideKey)?.name ?? "未設定"
            ) {
                ForEach(TicketGuideDefinition.all) { guide in
                    Button(guide.name) {
                        draft.ticketGuideKey = guide.key
                        draft.applyTicketGuide(guide.key)
                    }
                }
            }
            if draft.ticketGuideKey == TicketGuideDefinition.customKey {
                theaterFlatTextField("購入先", prompt: "FC・公式サイトなど", text: $draft.ticketSite)
                theaterFlatTextField("申込・購入URL", prompt: "https://", text: $draft.purchaseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            } else if !draft.purchaseURL.isEmpty {
                theaterFlatReadOnlyField("申込・購入URL", value: draft.purchaseURL)
            }
        }
    }

    private var ticketScheduleMemoUnit: some View {
        VStack(alignment: .leading, spacing: 15) {
            theaterFlatSectionHeader("タグ・メモ", isExpanded: nil)
            if draft.createsTicketAttempt {
                TicketTagInputField(text: $draft.tagNamesText, usesFlatPresentation: true)
            }
            ExperienceMemoUnitEditor(
                text: $draft.memo,
                styleRuns: $draft.planMemoStyleRuns,
                placeholder: "申込や受取について残しておくこと",
                usesFlatToolbar: true
            )
        }
    }

    private var unifiedStatusUnit: some View {
        VStack(alignment: .leading, spacing: 14) {
            theaterFlatSectionHeader("登録内容", isExpanded: nil, info: unifiedPurposeDescription)
            unifiedPurposePicker
        }
    }

    private var unifiedWorkUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader("作品・公演", isExpanded: $isUnifiedWorkExpanded)
            if isUnifiedWorkExpanded {
                unifiedWorkImportActions
                unifiedTargetSelectionContent
                theaterFlatSubheading("アイキャッチ・背景")
                unifiedVisualEditor
                    .padding(14)
                    .background(
                        TheaterLifecycleFlatStyle.fieldBackground,
                        in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
                theaterFlatTextField("公演名", required: true, prompt: "公演・イベント名を入力", text: $draft.title)
                theaterFlatMenuField(
                    "公演種別",
                    required: true,
                    value: TheaterPerformanceType.displayName(
                        for: draft.performanceTypeKey,
                        customName: draft.performanceTypeCustomName
                    )
                ) {
                    ForEach(TheaterPerformanceType.allCases) { type in
                        Button(type.displayName) { draft.performanceTypeKey = type.rawValue }
                    }
                }
                if draft.performanceTypeKey == TheaterPerformanceType.other.rawValue {
                    theaterFlatTextField("その他の種別", prompt: "例：能、狂言、朗読劇", text: $draft.performanceTypeCustomName)
                }
                theaterFlatTextField(
                    "シリーズ・ツアー名",
                    prompt: "例：冬の庭 2026",
                    text: $draft.seriesName,
                    info: "同じ作品の連続公演・再演・ツアーをまとめる名前です。"
                )
                theaterFlatTextField("公演団体", prompt: "劇団・制作団体・主催者", text: $draft.organizerName)
                theaterFlatTextField("公式サイト", prompt: "https://", text: $draft.officialURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                theaterFlatTextField("チケットサイト", prompt: "https://", text: $draft.eventTicketURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                theaterFlatTextField("公式SNS", prompt: "アカウント名・URLを1行1件", text: $draft.socialLinksText)
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: isUnifiedWorkExpanded)
    }

    private var unifiedCastUnit: some View {
        VStack(alignment: .leading, spacing: 15) {
            theaterFlatSectionHeader(
                "キャスト・スタッフ",
                isExpanded: $isUnifiedCastExpanded,
                info: "公式サイトやパンフレットから、画像OCR・テキスト貼付け・直接入力でまとめて登録できます。"
            )
            if isUnifiedCastExpanded {
                TheaterEventCreditsEditor(
                    bulkText: $draft.eventCreditsText,
                    existingLinks: visibleEventCreditLinks,
                    deletedLinkIDs: $deletedEventPersonLinkIDs,
                    pendingLinks: $eventPendingPeople,
                    personMasters: personMasters,
                    showsHeader: false
                )
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: isUnifiedCastExpanded)
    }

    private var unifiedParticipationUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader("参加日時・会場", isExpanded: $isUnifiedParticipationExpanded)
            if isUnifiedParticipationExpanded {
                theaterFlatChoiceRow(
                    values: [("onsite", "現地"), ("streaming", "配信"), ("live_viewing", "ライブビューイング")],
                    selection: $draft.attendanceMethodKey
                )
                theaterFlatDateField("観劇日", selection: scheduleDateBinding)
                HStack(alignment: .top, spacing: 12) {
                    if draft.hasOpeningTime {
                        theaterFlatTimeField("開場", selection: openingTimeBinding, removable: { draft.hasOpeningTime = false })
                    } else {
                        theaterFlatAddTimeButton("＋ 開場時間を追加") {
                            draft.opensAt = defaultOpeningTime
                            draft.hasOpeningTime = true
                        }
                    }
                    theaterFlatTimeField("開演", selection: startTimeBinding)
                }
                if draft.hasEndTime {
                    theaterFlatTimeField("終演", selection: endTimeBinding, removable: { draft.hasEndTime = false })
                        .frame(maxWidth: .infinity)
                } else {
                    theaterFlatAddTimeButton("＋ 終演時間を追加") {
                        draft.endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: draft.startsAt) ?? draft.startsAt
                        draft.hasEndTime = true
                    }
                }
                theaterFlatTextField("会場", prompt: "会場名を入力すると候補を表示", text: venueNameBinding)
                Button { isShowingPlaceSearch = true } label: {
                    Label("会場を検索", systemImage: "map")
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(Color(hex: "#8B2F45"))
                }
                .buttonStyle(.plain)
                theaterFlatTextField("住所", prompt: "住所を入力", text: venueAddressBinding)
                    .textContentType(.fullStreetAddress)
                PlaceMapPreview(
                    venueName: draft.venueName,
                    address: draft.venueAddress,
                    latitude: draft.latitude,
                    longitude: draft.longitude
                )
                theaterFlatTextField("会場公式サイト", prompt: "https://", text: venueOfficialURLBinding)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: isUnifiedParticipationExpanded)
    }

    private var unifiedTicketUnit: some View {
        VStack(alignment: .leading, spacing: 17) {
            theaterFlatSectionHeader(
                unifiedPurpose == .application ? "申込・チケット" : "チケット・座席",
                isExpanded: $isUnifiedTicketExpanded,
                info: "画像またはテキストから読み取るほか、下の各項目へ直接入力できます。"
            )
            if isUnifiedTicketExpanded {
                unifiedWorkImportActions
                theaterFlatTextField("購入・申込先", prompt: "例：公式サイト", text: $draft.ticketSite)
                HStack(alignment: .top, spacing: 12) {
                    theaterFlatTextField("チケット料金", prompt: "例：12,800", text: $draft.priceText)
                        .keyboardType(.decimalPad)
                    theaterFlatQuantityField
                }
                theaterFlatTextField("座席", prompt: "例：1階 S席 12列18番", text: $draft.seatText)
                theaterFlatTextField("購入・申込ページ", prompt: "https://", text: $draft.purchaseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: isUnifiedTicketExpanded)
    }

    private var unifiedMemoUnit: some View {
        VStack(alignment: .leading, spacing: 15) {
            theaterFlatSectionHeader("感想・メモ", isExpanded: $isUnifiedMemoExpanded)
            if isUnifiedMemoExpanded {
                ExperienceMemoUnitEditor(
                    text: $draft.memo,
                    styleRuns: $draft.planMemoStyleRuns,
                    placeholder: "気になった理由、申込メモ、観劇後の感想など",
                    usesFlatToolbar: true
                )
                TicketTagInputField(
                    text: usesPlanRegistration ? $draft.planTagNamesText : $draft.tagNamesText,
                    usesFlatPresentation: true
                )
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: isUnifiedMemoExpanded)
    }

    @ViewBuilder
    private func theaterFlatSectionHeader(
        _ title: String,
        isExpanded: Binding<Bool>?,
        info: String? = nil
    ) -> some View {
        if let isExpanded, info == nil {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: "#8B2F45"))
                        .frame(width: 4, height: 24)
                    Text(title)
                        .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded.wrappedValue ? "\(title)を閉じる" : "\(title)を開く")
        } else {
            HStack(spacing: 4) {
                if let isExpanded {
                    Button {
                        isExpanded.wrappedValue.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: "#8B2F45"))
                                .frame(width: 4, height: 24)
                            Text(title)
                                .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded.wrappedValue ? "\(title)を閉じる" : "\(title)を開く")
                } else {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#8B2F45"))
                            .frame(width: 4, height: 24)
                        Text(title)
                            .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(.primary)
                    }
                    .frame(minHeight: 44)
                }

                if let info {
                    TheaterLifecycleInfoButton(text: info)
                }

                if let isExpanded {
                    Button {
                        isExpanded.wrappedValue.toggle()
                    } label: {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded.wrappedValue ? "\(title)を閉じる" : "\(title)を開く")
                } else {
                    Spacer(minLength: 8)
                }
            }
            .frame(minHeight: 44)
        }
    }

    private func theaterFlatFieldLabel(
        _ title: String,
        required: Bool = false,
        info: String? = nil
    ) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
            Text(required ? "* 必須" : "任意")
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                .foregroundStyle(required ? Color(hex: "#8B2F45") : .secondary)
            if let info {
                TheaterLifecycleInfoButton(text: info)
            }
        }
    }

    private func theaterFlatTextField(
        _ title: String,
        required: Bool = false,
        prompt: String,
        text: Binding<String>,
        info: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            theaterFlatFieldLabel(title, required: required, info: info)
            TextField(prompt, text: text, axis: .vertical)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .frame(minHeight: 54)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func theaterFlatReadOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            theaterFlatFieldLabel(title)
            Text(value)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 14)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private func theaterFlatBooleanChoice(
        title: String,
        falseTitle: String,
        trueTitle: String,
        selection: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
            HStack(spacing: 8) {
                ForEach([(false, falseTitle), (true, trueTitle)], id: \.0) { value, label in
                    Button { selection.wrappedValue = value } label: {
                        Text(label)
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(selection.wrappedValue == value ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                selection.wrappedValue == value ? Color(hex: "#8B2F45") : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func theaterFlatSubheading(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }

    private func theaterFlatOptionalDateTimeField(
        _ title: String,
        isOn: Binding<Bool>,
        date: Binding<Date>
    ) -> some View {
        TicketMilestoneDateField(title: title, isOn: isOn, date: date)
    }

    private func theaterFlatMenuField<MenuItems: View>(
        _ title: String,
        required: Bool = false,
        value: String,
        @ViewBuilder items: () -> MenuItems
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            theaterFlatFieldLabel(title, required: required)
            Menu(content: items) {
                HStack {
                    Text(value)
                        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 54)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func theaterFlatChoiceRow(values: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.0) { value, title in
                Button { selection.wrappedValue = value } label: {
                    Text(title)
                        .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(selection.wrappedValue == value ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(selection.wrappedValue == value ? Color(hex: "#8B2F45") : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func theaterFlatDateField(_ title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            theaterFlatFieldLabel(title, required: true)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 14)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private func theaterFlatTimeField(_ title: String, selection: Binding<Date>, removable: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(title)
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                Spacer(minLength: 0)
                if let removable {
                    Button(action: removable) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 10)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func theaterFlatAddTimeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Color(hex: "#8B2F45"))
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(hex: "#8B2F45").opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.top, 27)
    }

    private var theaterFlatQuantityField: some View {
        VStack(alignment: .leading, spacing: 7) {
            theaterFlatFieldLabel("枚数")
            HStack {
                Button { draft.quantity = max(1, draft.quantity - 1) } label: { Image(systemName: "minus") }
                Spacer()
                Text("\(draft.quantity)")
                    .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                Spacer()
                Button { draft.quantity += 1 } label: { Image(systemName: "plus") }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background(
                TheaterLifecycleFlatStyle.fieldBackground,
                in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var unifiedRegistrationFormSections: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                unifiedPurposePicker
                Divider()
                Text(unifiedPurposeDescription)
                    .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            theaterEditorSectionHeader("登録内容")
        }

        Section {
            unifiedSectionToggle(
                title: "作品・公演",
                isExpanded: $isUnifiedWorkExpanded
            )
            if isUnifiedWorkExpanded {
                unifiedWorkImportActions
                unifiedTargetSelectionContent
                Text("アイキャッチ・背景")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                unifiedVisualEditor
                ExplicitFormTextField(
                    title: "公演名",
                    prompt: "公演・イベント名を入力",
                    text: $draft.title,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 3,
                    labelStyle: .stacked,
                    inputFontSize: 17
                )
                TheaterPerformanceTypePicker(
                    selection: $draft.performanceTypeKey,
                    customName: $draft.performanceTypeCustomName,
                    usesCompactLabelStyle: false
                )
                ExplicitFormTextField(
                    title: "シリーズ・ツアー名（任意）",
                    prompt: "例：冬の庭 2026",
                    text: $draft.seriesName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                Text("同じ作品の連続公演・再演・ツアーをまとめる名前です。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                ExplicitFormTextField(
                    title: "公演団体（任意）",
                    prompt: "劇団・制作団体・主催者",
                    text: $draft.organizerName,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                ExplicitFormTextField(
                    title: "公式サイト（任意）",
                    prompt: "https://",
                    text: $draft.officialURL,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                ExplicitFormTextField(
                    title: "チケットサイト（任意）",
                    prompt: "https://",
                    text: $draft.eventTicketURL,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                ExplicitFormTextField(
                    title: "公式SNS（任意）",
                    prompt: "アカウント名・URLを1行1件",
                    text: $draft.socialLinksText,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 3,
                    labelStyle: .stacked
                )
            }
        }

        if !isInterestedOnly {
            unifiedParticipationSection
        }

        if usesTicketRegistration {
            Section {
                unifiedSectionToggle(
                    title: unifiedPurpose == .application ? "申込・チケット" : "チケット・座席",
                    isExpanded: $isUnifiedTicketExpanded
                )
            }
            if isUnifiedTicketExpanded {
                batchImportedScheduleSection
                ticketRegistrationSections
            }
        }

        Section {
            unifiedSectionToggle(title: "感想・メモ", isExpanded: $isUnifiedMemoExpanded)
            if isUnifiedMemoExpanded {
                if usesPlanRegistration {
                    TicketTagInputField(text: $draft.planTagNamesText)
                } else if draft.createsTicketAttempt {
                    TicketTagInputField(text: $draft.tagNamesText)
                }
                ExperienceMemoUnitEditor(
                    text: $draft.memo,
                    styleRuns: $draft.planMemoStyleRuns,
                    placeholder: "気になった理由、申込メモ、観劇後の感想など"
                )
            }
        }

        Section {
            unifiedSectionToggle(title: "キャスト・スタッフ", isExpanded: $isUnifiedCastExpanded)
            if isUnifiedCastExpanded {
                TheaterEventCreditsEditor(
                    bulkText: $draft.eventCreditsText,
                    existingLinks: visibleEventCreditLinks,
                    deletedLinkIDs: $deletedEventPersonLinkIDs,
                    pendingLinks: $eventPendingPeople,
                    personMasters: personMasters,
                    showsHeader: false
                )
            }
        }
    }

    private func theaterEditorSectionHeader(_ title: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(hex: "#8B2F45"))
                .frame(width: 4, height: 24)
            Text(title)
                .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color(hex: "#8B2F45"))
        }
        .textCase(nil)
    }

    private func unifiedSectionToggle(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(hex: "#8B2F45"))
                    .frame(width: 4, height: 26)
                Text(title)
                    .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var unifiedWorkImportActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                unifiedCompactImportButton(
                    title: "写真・カメラ",
                    systemImage: "camera"
                ) { isShowingInformationImageSource = true }
                unifiedCompactImportButton(
                    title: "テキストから",
                    systemImage: "doc.text"
                ) { isShowingTicketTextImport = true }
                unifiedCompactImportButton(
                    title: "URLから",
                    systemImage: "link"
                ) {
                    performanceImportURL = draft.officialURL
                    performanceImportStatus = ""
                    isShowingPerformanceURLImport = true
                }
            }
            if !performanceImportStatus.isEmpty {
                Text(performanceImportStatus)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func unifiedCompactImportButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                FavorecoIcon(systemName: systemImage, size: 15)
                Text(title)
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(
                    cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                    style: .continuous
                )
                    .fill(TheaterLifecycleFlatStyle.fieldBackground)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                            style: .continuous
                        )
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var unifiedTargetSelectionContent: some View {
        if allowsTargetSelection {
            HStack(spacing: 4) {
                Button {
                    targetSelectionMode = .new
                } label: {
                    unifiedTargetSelectionLabel(
                        "新規公演",
                        isSelected: targetSelectionMode == .new
                    )
                }
                .buttonStyle(.plain)

                Button {
                    targetSelectionMode = .existingEvent
                    isShowingRegisteredEventPicker = true
                } label: {
                    unifiedTargetSelectionLabel(
                        selectedRegisteredEvent?.title ?? "登録済みから選ぶ",
                        isSelected: targetSelectionMode == .existingEvent
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func unifiedTargetSelectionLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(
                isSelected
                    ? registrationPalette.prominentActionForeground(for: colorScheme)
                    : Color.primary
            )
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                isSelected ? registrationPalette.prominentAction : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var unifiedVisualEditor: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("アイキャッチ")
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                unifiedEyecatchCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text("背景")
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                unifiedBackgroundCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var unifiedEyecatchCard: some View {
        if let data = eventEyecatchData, let image = UIImage(data: data) {
            visualSquareCard {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    PhotosPicker(selection: $selectedEventEyecatchItem, matching: .images) {
                        visualEditControl("変更", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        eventEyecatchData = nil
                        if eventHeroBackgroundPresetKey == HeroBackgroundPreset.eventEyecatchKey {
                            eventHeroBackgroundPresetKey = HeroBackgroundPreset.noneKey
                            eventHeroBackgroundPath = ""
                        }
                    } label: {
                        visualDeleteControl
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("アイキャッチを削除")
                }
                .padding(8)
            }
        } else {
            PhotosPicker(selection: $selectedEventEyecatchItem, matching: .images) {
                visualSquarePlaceholder(
                    title: "ライブラリから選ぶ",
                    systemImage: "photo.on.rectangle"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var unifiedBackgroundCard: some View {
        visualSquareCard {
            if let backgroundImage = selectedEventHeroBackgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.secondarySystemFill)
                    .overlay {
                        VStack(spacing: 7) {
                            Image(systemName: "rectangle.slash")
                                .font(.system(size: 21, weight: .regular))
                            Text("背景なし")
                                .font(FavorecoTypography.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Button {
                    isShowingEventBackgroundPicker = true
                } label: {
                    visualEditControl("編集", systemImage: "paintbrush")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("背景を編集")

                if selectedEventHeroBackgroundImage != nil {
                    Button(role: .destructive) {
                        eventHeroBackgroundPath = ""
                        eventHeroBackgroundPresetKey = HeroBackgroundPreset.noneKey
                    } label: {
                        visualDeleteControl
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("背景を削除")
                }
            }
            .padding(8)
        }
    }

    private func visualSquareCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
    }

    private func visualSquarePlaceholder(title: String, systemImage: String) -> some View {
        ZStack {
            Color(.secondarySystemFill)
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                Text(title)
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
            }
            .foregroundStyle(registrationPalette.globalTint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    private func visualEditControl(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(FavorecoTypography.jpSans(10.5, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 9)
            .frame(minHeight: 32)
            .background(.regularMaterial, in: Capsule())
    }

    private var visualDeleteControl: some View {
        Image(systemName: "trash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.red)
            .frame(width: 32, height: 32)
            .background(.regularMaterial, in: Circle())
    }

    private var selectedEventHeroBackgroundImage: UIImage? {
        if eventHeroBackgroundPresetKey == HeroBackgroundPreset.eventEyecatchKey {
            return eventEyecatchData.flatMap(UIImage.init(data:))
        }
        guard let preset = HeroBackgroundPreset.resolved(
            categoryKey: planTemplateKey,
            storedKey: eventHeroBackgroundPresetKey
        ) else { return nil }
        if let image = UIImage(named: preset.resourceName) { return image }
        guard let url = Bundle.main.url(forResource: preset.resourceName, withExtension: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private var unifiedParticipationSection: some View {
        Section {
            unifiedSectionToggle(
                title: "参加日時・会場",
                isExpanded: $isUnifiedParticipationExpanded
            )
            if isUnifiedParticipationExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("参加方法")
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    Picker("参加方法", selection: $draft.attendanceMethodKey) {
                        Text("現地").tag("onsite")
                        Text("配信").tag("streaming")
                        Text("ライブビューイング").tag("live_viewing")
                    }
                    .pickerStyle(.segmented)
                }

                TheaterScheduleDateRow(
                    selection: scheduleDateBinding,
                    isSet: $draft.hasConfirmedSchedule,
                    onClear: clearExperienceSchedule
                )
                OptionalTenMinuteTimeRow(
                    title: "開場",
                    selection: openingTimeBinding,
                    isSet: $draft.hasOpeningTime,
                    defaultValue: defaultOpeningTime
                )
                TenMinuteTimeRow(title: "開演", selection: startTimeBinding)
                OptionalTenMinuteTimeRow(
                    title: "終了",
                    selection: endTimeBinding,
                    isSet: $draft.hasEndTime,
                    defaultValue: Calendar.current.date(
                        byAdding: .hour,
                        value: 2,
                        to: draft.startsAt
                    ) ?? draft.startsAt
                )

                PlanVenueSearchField(
                    title: "会場",
                    prompt: "会場名を入力すると候補を表示",
                    text: venueNameBinding,
                    tint: Color(hex: "#8B2F45"),
                    searchAction: { isShowingPlaceSearch = true }
                )
                placeSuggestionList
                ExplicitFormTextField(
                    title: "住所（任意）",
                    prompt: "住所を入力",
                    text: venueAddressBinding,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                .textContentType(.fullStreetAddress)
                PlaceMapPreview(
                    venueName: draft.venueName,
                    address: draft.venueAddress,
                    latitude: draft.latitude,
                    longitude: draft.longitude
                )
                ExplicitFormTextField(
                    title: "会場公式サイト（任意）",
                    prompt: "https://",
                    text: venueOfficialURLBinding,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .stacked
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            }
        }
    }

    var body: some View {
        registrationRoot
            .photosPicker(
                isPresented: $isShowingInformationImagePicker,
                selection: $selectedTicketOCRItems,
                maxSelectionCount: 2,
                matching: .images
            )
            .confirmationDialog(
                "写真・カメラから情報入力",
                isPresented: $isShowingInformationImageSource,
                titleVisibility: .visible
            ) {
                Button("写真ライブラリから選ぶ") {
                    isShowingInformationImagePicker = true
                }
                Button("カメラで撮影") {
                    openInformationCamera()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("タイトル・日付・会場など、読み取れた候補を確認してから反映します。")
            }
            .fullScreenCover(isPresented: $isShowingInformationCamera) {
                CameraImagePicker(
                    onCapture: { image in
                        isShowingInformationCamera = false
                        Task { await readTicketCameraImage(image) }
                    },
                    onCancel: { isShowingInformationCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingTicketTextImport) {
                ticketTextImportSheet
            }
            .sheet(isPresented: $isShowingPerformanceURLImport) {
                performanceURLImportSheet
            }
            .sheet(isPresented: $isShowingEventBackgroundPicker) {
                EventBackgroundSelectionSheet(
                    categoryKey: planTemplateKey,
                    eyecatchData: eventEyecatchData,
                    selection: Binding(
                        get: { eventHeroBackgroundPresetKey },
                        set: { key in
                            eventHeroBackgroundPath = ""
                            eventHeroBackgroundPresetKey = key
                        }
                    )
                )
                .favorecoAppAppearance()
                .tint(registrationPalette.globalTint)
            }
            .fullScreenCover(isPresented: $isShowingEventEyecatchCamera) {
                CameraImagePicker(
                    onCapture: { image in
                        isShowingEventEyecatchCamera = false
                        setEventEyecatch(from: image)
                    },
                    onCancel: { isShowingEventEyecatchCamera = false }
                )
                .ignoresSafeArea()
            }
            .onAppear(perform: handleViewAppear)
            .onChange(of: unifiedPurpose) { _, purpose in
                applyUnifiedPurpose(purpose)
            }
            .onChange(of: targetSelectionMode) { _, newValue in
                handleTargetSelectionModeChange(newValue)
            }
            .onChange(of: selectedEventID) { _, _ in
                handleSelectedEventChange()
            }
            .onChange(of: selectedPlanID) { _, _ in
                handleSelectedPlanChange()
            }
            .onChange(of: selectedEventEyecatchItem) { _, item in
                handleSelectedEventEyecatchItemChange(item)
            }
            .onChange(of: selectedTicketOCRItems) { _, items in
                handleSelectedTicketOCRItemsChange(items)
            }
            .onChange(of: draft.categoryID) { _, _ in
                guard !targetSelectionModes.contains(targetSelectionMode) else { return }
                targetSelectionMode = targetSelectionModes.contains(.existingEvent) ? .existingEvent : .new
            }
            .alert("カメラを使用できません", isPresented: $isShowingCameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("写真ライブラリから画像を選んでください。")
            }
            .alert("入力内容を確認してください", isPresented: validationErrorPresentationBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError)
            }
            .sheet(
                isPresented: $isShowingInterestedEventPicker,
                onDismiss: applyPendingEventSelection
            ) {
                EventPicker(
                    title: "気になるから選ぶ",
                    searchPrompt: "タイトル・シリーズ・ジャンル",
                    items: interestedEventPickerItems,
                    selectedEventID: selectedEventID
                ) { eventID in
                    pendingSelectedEventID = eventID
                    isShowingInterestedEventPicker = false
                }
            }
            .sheet(
                isPresented: $isShowingRegisteredEventPicker,
                onDismiss: applyPendingEventSelection
            ) {
                EventPicker(
                    title: "登録済みイベントから選ぶ",
                    searchPrompt: "タイトル・シリーズ・ジャンル",
                    items: activeEventPickerItems,
                    selectedEventID: selectedEventID
                ) { eventID in
                    pendingSelectedEventID = eventID
                    isShowingRegisteredEventPicker = false
                }
            }
            .sheet(isPresented: $isShowingRecurringEventCatalog) {
                PublicRecurringEventCatalogView(templateKey: selectedCategory?.templateKey) { entry, edition in
                    applyRecurringEventCatalogSelection(entry, edition: edition)
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    if isSimpleDestinationPlan {
                        draft.apply(place: candidate, preservingVenueName: false)
                    } else {
                        draft.apply(
                            place: candidate,
                            preservingVenueName: draft.shouldPreserveVenueNameForAddressSearch
                        )
                    }
                    finishPlaceSuggestionSelection()
                    isShowingPlaceSearch = false
                }
            }
            .sheet(isPresented: $isShowingTicketImportReview) {
                TicketImportReviewSheet(candidates: ticketImportCandidates) { selectedCandidates in
                    applySelectedTicketImportCandidates(selectedCandidates)
                    isShowingTicketImportReview = false
                }
                .favorecoAppAppearance()
                .tint(registrationPalette.globalTint)
            }
            .sheet(item: $ticketPlanForNextStep, onDismiss: {
                dismiss()
            }) { plan in
                AddTicketPlanView(plan: plan, entryMode: .ticketSchedule)
            }
            .sheet(item: $eventForAdditionalTicketSchedule, onDismiss: {
                dismiss()
            }) { event in
                AddTicketPlanView(
                    event: event,
                    entryMode: .ticketSchedule,
                    continuingApplication: savedTicketAttempt
                )
            }
            .sheet(item: $planForAdditionalTicketAttempt, onDismiss: handleAdditionalTicketAttemptDismiss) { plan in
                EditTicketAttemptView(plan: plan)
            }
            .confirmationDialog(
                "観劇予定を保存しました",
                isPresented: $isShowingAfterPlanSaveActions,
                titleVisibility: .visible
            ) {
                Button("チケットを手配する") {
                    ticketPlanForNextStep = savedTheaterPlan
                }
                Button("完了") {
                    dismiss()
                }
            } message: {
                Text("続けて、抽選・発売・受取の予定を登録できます。")
            }
            .confirmationDialog(
                "申込・発売を保存しました",
                isPresented: $isShowingAfterTicketSaveActions,
                titleVisibility: .visible
            ) {
                Button("同じ日程に別の申込を追加") {
                    planForAdditionalTicketAttempt = savedTicketSchedulePlan
                }
                Button("同じ公演の別日程を追加") {
                    continueApplicationCollectionOnAnotherSchedule()
                }
                Button("入力完了") {
                    dismiss()
                }
            } message: {
                Text("同じ日程へ別サイトの申込を追加するか、同じ公演の別日程を続けて追加できます。")
            }
            .task { await publicPlaceStore.prepare() }
        .favorecoAppAppearance()
        .environment(\.favorecoThemePalette, registrationPalette)
        .tint(registrationPalette.globalTint)
    }

    /// The flat theater screens have their own header and do not need a navigation stack.
    /// Erasing the three roots here also keeps SwiftUI from recursively expanding the
    /// complete generic type of every registration variant on physical devices.
    private var registrationRoot: AnyView {
        if isUnifiedRegistration && !editsPlanOnly {
            return AnyView(unifiedRegistrationScreen)
        }
        if usesFlatTicketSchedule {
            return AnyView(ticketScheduleFlatScreen)
        }
        return AnyView(
            NavigationStack {
                legacyRegistrationForm
            }
        )
    }

    private var legacyRegistrationForm: some View {
        Form {
            if let simpleRegistrationPurpose, let selectedCategory {
                SimpleCategoryRegistrationPurposePicker(
                    selection: simpleRegistrationPurpose,
                    category: selectedCategory
                )
            }

            if editsPlanOnly {
                planLifecycleEditSections
            } else {
                informationImageImportSection
                targetSelectionSection

                if !usesTicketRegistration {
                    eventEyecatchSection
                }

                inheritedEventIntroductionSection
                selectedPlanOrBasicInformationSection
                planScheduleAndVenueSections

                if showsTicketRegistrationSections {
                    batchImportedScheduleSection
                    ticketRegistrationSections
                }

                FavorecoRegistrationSection("タグ・メモ") {
                    if usesPlanRegistration {
                        TicketTagInputField(text: $draft.planTagNamesText)
                    } else if draft.createsTicketAttempt {
                        TicketTagInputField(text: $draft.tagNamesText)
                    }
                    ExplicitFormTextField(
                        title: "メモ",
                        prompt: "任意",
                        text: $draft.memo,
                        axis: .vertical,
                        minimumLines: isSimplePlan ? 3 : 5,
                        maximumLines: isSimplePlan ? 3 : 5,
                        reservesLineSpace: true
                    )
                }
            }
        }
        .favorecoRegistrationFormCanvas()
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { registrationToolbar }
    }

    @ViewBuilder
    private var targetSelectionSection: some View {
        if allowsTargetSelection {
            Section {
                if targetSelectionModes.count > 1 {
                    Picker("登録方法", selection: $targetSelectionMode) {
                        ForEach(targetSelectionModes) { mode in
                            Text(targetSelectionTitle(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if targetSelectionMode == .existingEvent {
                    registeredTargetSelectionContent
                } else if targetSelectionMode == .interested {
                    interestedTargetSelectionContent
                } else {
                    recurringEventCatalogSelectionRow
                }
            } header: {
                FavorecoRegistrationSectionHeader(targetSelectionSectionTitle)
            }
        }
    }

    @ToolbarContentBuilder
    private var registrationToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("キャンセル")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("保存") {
                save()
            }
            .disabled(!draft.canSave)
        }
    }

    private func handleTargetSelectionModeChange(_ newValue: TargetSelectionMode) {
        _ = newValue
        let preservedCategoryID = draft.categoryID
        selectedEventID = nil
        selectedPlanID = nil
        batchImportedScheduleDrafts.removeAll()
        additionalApplications.removeAll { $0.isImported }
        selectedRecurringEventEdition = nil
        draft.clearTarget()
        draft.categoryID = preservedCategoryID ?? initialCategoryID
        eventEyecatchData = nil
        eventHeroBackgroundPath = ""
        eventHeroBackgroundPresetKey = ""
        eventPendingPeople = []
        deletedEventPersonLinkIDs = []
    }

    private func handleViewAppear() {
        configurePlanLifecycleExpansionIfNeeded()
        if editingPlan == nil {
            restoreInitialCategoryIfNeeded()
        }
        if isUnifiedRegistration {
            applyUnifiedPurpose(unifiedPurpose)
        }
    }

    private var validationErrorPresentationBinding: Binding<Bool> {
        Binding(
            get: { !validationError.isEmpty },
            set: { isPresented in
                if !isPresented { validationError = "" }
            }
        )
    }

    private func handleSelectedEventChange() {
        batchImportedScheduleDrafts.removeAll()
        additionalApplications.removeAll { $0.isImported }
        let event = targetSelectionMode == .existingEvent ? selectedRegisteredEvent : selectedInterestedEvent
        guard let event else { return }
        eventPendingPeople = []
        deletedEventPersonLinkIDs = []
        draft.applyTarget(event)
        eventEyecatchData = event.eyecatchData
        let eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        eventHeroBackgroundPath = eventFields.heroBackgroundPath
        eventHeroBackgroundPresetKey = eventFields.heroBackgroundPresetKey
        guard targetSelectionMode == .existingEvent else { return }
        if usesTicketRegistration {
            selectedPlanID = plansForSelectedEvent.first?.id
            if let selectedExistingPlan {
                draft.applyTarget(selectedExistingPlan)
            }
        } else {
            selectedPlanID = nil
            normalizeSimpleDestinationVenueName()
        }
    }

    private func handleSelectedPlanChange() {
        batchImportedScheduleDrafts.removeAll()
        additionalApplications.removeAll { $0.isImported }
        if let plan = selectedExistingPlan {
            draft.applyTarget(plan)
        } else if targetSelectionMode == .existingEvent, let event = selectedRegisteredEvent {
            draft.clearTarget()
            draft.applyTarget(event)
        }
    }

    private func handleAdditionalTicketAttemptDismiss() {
        if savedTicketSchedulePlan != nil {
            isShowingAfterTicketSaveActions = true
        }
    }

    private func handleSelectedEventEyecatchItemChange(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { await loadEventEyecatch(from: item) }
    }

    private func handleSelectedTicketOCRItemsChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { await readTicketImages(from: items) }
    }

    private var targetSelectionSectionTitle: String {
        if isUnifiedRegistration { return "対象" }
        return isSimplePlan ? destinationTargetName : "予定の対象"
    }

    @ViewBuilder
    private var registeredTargetSelectionContent: some View {
        if registeredTargetEvents.isEmpty {
            FavorecoContentUnavailableView(
                "登録済みの対象がありません",
                systemImage: "rectangle.stack.badge.plus",
                description: "新しい施設・スポットと予定を同時に登録できます。"
            )
        } else {
            Button {
                pendingSelectedEventID = nil
                isShowingRegisteredEventPicker = true
            } label: {
                targetSelectionButtonLabel(
                    event: selectedRegisteredEvent,
                    placeholder: "登録済みから検索"
                )
            }
            .buttonStyle(.plain)

            if selectedRegisteredEvent != nil && usesTicketRegistration {
                if plansForSelectedEvent.isEmpty {
                    FavorecoIconLabel(
                        "予定も同時に作成します",
                        systemImage: "calendar.badge.plus",
                        iconSize: 13
                    )
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                } else {
                    selectedPlanDestinationMenu
                }
            }
        }
    }

    @ViewBuilder
    private var interestedTargetSelectionContent: some View {
        if interestedEvents.isEmpty {
            FavorecoContentUnavailableView(
                "気になる対象がありません",
                systemImage: "heart",
                description: "先にクイック登録するか、新しく対象を登録してください。"
            )
        } else {
            Button {
                pendingSelectedEventID = nil
                isShowingInterestedEventPicker = true
            } label: {
                targetSelectionButtonLabel(
                    event: selectedInterestedEvent,
                    placeholder: "作品・対象を検索"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func targetSelectionButtonLabel(
        event: ExperienceEvent?,
        placeholder: String
    ) -> some View {
        HStack(spacing: 12) {
            FavorecoIcon(
                systemName: event?.category?.iconSymbol ?? "magnifyingglass",
                size: 18
            )
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(event?.title ?? placeholder)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                if let event {
                    Text(event.category?.name ?? "未分類")
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

    @ViewBuilder
    private var recurringEventCatalogSelectionRow: some View {
        if let templateKey = selectedCategory?.templateKey,
           ["museum", "theater", "live"].contains(templateKey) {
            Button {
                isShowingRecurringEventCatalog = true
            } label: {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "calendar.badge.clock", size: 17)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("定期イベントカタログから選ぶ")
                            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                        Text("芸術祭・舞台芸術祭・野外音楽フェス")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .allowsTightening(true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let edition = selectedRecurringEventEdition {
                Button("会期初日を予定日に反映") {
                    applyRecurringEditionDate(edition)
                }
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .disabled(edition.startDate == nil)
            }
        }
    }

    @ViewBuilder
    private var inheritedEventIntroductionSection: some View {
        if targetSelectionMode == .interested,
           let templateKey = resolvedTargetEvent?.category?.templateKey,
           templateKey == "theater" || templateKey == "live" {
            Section {
                TheaterUnifiedFormIntroduction(
                    entry: unifiedFormEntry,
                    isLive: templateKey == "live"
                )
            }
        }
    }

    @ViewBuilder
    private var selectedPlanOrBasicInformationSection: some View {
        if usesTicketRegistration, let selectedExistingPlan {
            Section {
                VStack(spacing: 0) {
                    compactPlanSummaryRow(
                        title: "ジャンル",
                        value: selectedExistingPlan.category?.name ?? "未設定"
                    )
                    Divider()
                    compactPlanSummaryRow(
                        title: "タイトル",
                        value: displayedPlanTitle(selectedExistingPlan)
                    )
                    Divider()
                    compactPlanSummaryRow(
                        title: "日時",
                        value: selectedExistingPlan.hasConfirmedSchedule
                            ? FavorecoDateText.compactDateTime(selectedExistingPlan.startsAt)
                            : "参加日未定"
                    )
                    if !selectedExistingPlan.venueNameSnapshot.isEmpty {
                        Divider()
                        compactPlanSummaryRow(
                            title: "会場",
                            value: selectedExistingPlan.venueNameSnapshot
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } header: {
                FavorecoRegistrationSectionHeader("予定の基本情報")
            }
        } else {
            planBasicInformationSection
        }
    }

    @ViewBuilder
    private var planScheduleAndVenueSections: some View {
        if selectedExistingPlan == nil && !isInterestedOnly {
            Section {
                if usesTicketRegistration {
                    Text("日程は決まっていますか？")
                        .font(FavorecoTypography.bodyStrong)
                    Picker("日程", selection: $draft.hasConfirmedSchedule) {
                        Text("未定").tag(false)
                        Text("決まっている").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if !draft.hasConfirmedSchedule {
                        Text("未定の予定はComing Up・カレンダーに表示されません")
                            .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption2))
                            .foregroundStyle(.secondary)
                            .lineLimit(2, reservesSpace: true)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                    }
                }
                if draft.hasConfirmedSchedule {
                    if usesOpeningTime {
                        TheaterScheduleDateRow(
                            selection: scheduleDateBinding,
                            isSet: $draft.hasConfirmedSchedule,
                            onClear: clearExperienceSchedule
                        )
                        OptionalTenMinuteTimeRow(
                            title: "開場",
                            selection: openingTimeBinding,
                            isSet: $draft.hasOpeningTime,
                            defaultValue: defaultOpeningTime
                        )
                        TenMinuteTimeRow(title: "開演", selection: startTimeBinding)
                        TenMinuteTimeRow(title: "終了", selection: endTimeBinding)
                    } else {
                        ExperienceDateTimeRangeEditor(
                            startsAt: startTimeBinding,
                            endsAt: endTimeBinding,
                            dateLabel: simpleScheduleDateLabel,
                            startTimeLabel: "開始時刻",
                            endTimeLabel: "終了時刻"
                        )
                    }
                } else if usesOpeningTime && usesPlanRegistration {
                    TheaterScheduleDateRow(
                        selection: scheduleDateBinding,
                        isSet: $draft.hasConfirmedSchedule,
                        onClear: clearExperienceSchedule
                    )
                }
            } header: {
                if isSimplePlan {
                    FavorecoRegistrationSectionHeader(simpleScheduleSectionTitle)
                } else if usesPlanRegistration {
                    TheaterUnifiedSectionLabel(section: .participation)
                } else {
                    FavorecoRegistrationSectionHeader(usesOpeningTime ? "観劇予定日" : "予定日時")
                }
            }

            if !isSimpleDestinationPlan && (usesPlanRegistration || draft.hasConfirmedSchedule) {
                Section {
                    inheritedTheaterVenueChoices
                    PlanVenueSearchField(
                        title: planVenueFieldTitle,
                        prompt: planVenueFieldPrompt,
                        text: venueNameBinding,
                        tint: registrationPalette.globalTint,
                        searchAction: { isShowingPlaceSearch = true }
                    )
                    placeSuggestionList
                    ExplicitFormTextField(
                        title: "住所（任意）",
                        prompt: "住所を入力（任意）",
                        text: venueAddressBinding,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    .textContentType(.fullStreetAddress)
                    PlaceMapPreview(
                        venueName: draft.venueName,
                        address: draft.venueAddress,
                        latitude: draft.latitude,
                        longitude: draft.longitude
                    )
                    ExplicitFormTextField(
                        title: planVenueOfficialSiteFieldTitle,
                        prompt: "https://",
                        text: venueOfficialURLBinding,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    PlaceOfficialWebsiteLink(
                        urlString: venueOfficialURLString,
                        title: planVenueOfficialSiteLinkTitle
                    )
                } header: {
                    FavorecoRegistrationSectionHeader(planVenueSectionTitle)
                }
            }
        }
    }

    private var planVenueSectionTitle: String {
        if isSimpleViewingPlan {
            return selectedCategory?.templateKey == "movie" ? "鑑賞場所" : "会場"
        }
        return isSimpleDestinationPlan ? "場所" : "会場"
    }

    private var planBasicInformationSection: some View {
        Section {
            if let event = resolvedTargetEvent {
                linkedTheaterReferenceRow(
                    title: "ジャンル",
                    value: event.category?.name ?? "未設定"
                )
            } else {
                ExplicitFormControlRow(title: "ジャンル", isRequired: true) {
                    Picker("ジャンル", selection: $draft.categoryID) {
                        Text("未設定").tag(Optional<UUID>.none)
                        ForEach(visibleCategories) { category in
                            Text(category.name).tag(category.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if let event = resolvedTargetEvent, isSimplePlan {
                linkedTheaterReferenceRow(title: destinationTargetFieldTitle, value: event.title)
            } else if let event = resolvedTargetEvent,
                      event.category?.templateKey == "theater" {
                let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
                linkedTheaterReferenceRow(title: "公演名", value: event.title)
                if !event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    linkedTheaterReferenceRow(title: "シリーズ", value: event.seriesName)
                }
                let performanceTypeName = TheaterPerformanceType.displayName(
                    for: event.subTypeKey,
                    customName: fields.eventPerformanceTypeCustomName
                )
                if !performanceTypeName.isEmpty {
                    linkedTheaterReferenceRow(title: "公演種別", value: performanceTypeName)
                }
            } else {
                ExplicitFormTextField(
                    title: planBasicTitleFieldTitle,
                    prompt: planBasicTitleFieldPrompt,
                    text: $draft.title,
                    axis: .horizontal,
                    minimumLines: 1,
                    maximumLines: 1,
                    labelStyle: .horizontal,
                    inputFontSize: ExplicitFormMetrics.inputFontSize,
                    labelLineLimit: 2,
                    focusesFromWholeRow: true
                )
            }
            if isSimpleDestinationPlan {
                PlanVenueSearchField(
                    title: simpleDestinationVenueFieldTitle,
                    prompt: simpleDestinationVenueFieldPrompt,
                    text: venueNameBinding,
                    tint: registrationPalette.globalTint,
                    searchAction: { isShowingPlaceSearch = true }
                )
                placeSuggestionList
                ExplicitFormTextField(
                    title: "住所",
                    prompt: "任意（地図・カレンダーでは住所を優先）",
                    text: venueAddressBinding,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                .textContentType(.fullStreetAddress)
                PlaceMapPreview(
                    venueName: draft.venueName,
                    address: draft.venueAddress,
                    latitude: draft.latitude,
                    longitude: draft.longitude
                )
                ExplicitFormTextField(
                    title: "施設公式サイト（任意）",
                    prompt: "https://",
                    text: venueOfficialURLBinding,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                PlaceOfficialWebsiteLink(
                    urlString: venueOfficialURLString,
                    title: "施設サイトを開く"
                )
            }
            if !isSimplePlan {
                ExplicitFormTextField(
                    title: "サブタイトル",
                    prompt: "任意",
                    text: $draft.subtitle,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
            }
            ExplicitFormTextField(
                title: isSimplePlan ? "この予定の案内ページ（任意）" : "公式URL",
                prompt: isSimplePlan ? "予約・イベント情報などのURL" : "公演・この予定の案内ページ（任意）",
                text: $draft.officialURL,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)

            if resolvedTargetEvent?.category?.templateKey == "theater" {
                Text("気になる公演の情報を引き継いでいます。ここでは観劇する日時と会場を追加します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            if isSimplePlan {
                FavorecoRegistrationSectionHeader("\(destinationTargetName)情報")
            } else if usesPlanRegistration {
                TheaterUnifiedSectionLabel(
                    section: .performanceBasic,
                    isLive: selectedCategory?.templateKey == "live",
                    summaryOverride: "ジャンル・公演名・サブタイトル・公式URL"
                )
            } else {
                FavorecoRegistrationSectionHeader("公演の基本情報")
            }
        }
    }

    private var selectedPlanDestinationMenu: some View {
        Menu {
            Button {
                selectedPlanID = nil
            } label: {
                if selectedPlanID == nil {
                    Label("新しい予定を作る", systemImage: "checkmark")
                } else {
                    Text("新しい予定を作る")
                }
            }
            ForEach(plansForSelectedEvent) { plan in
                Button {
                    selectedPlanID = plan.id
                } label: {
                    if selectedPlanID == plan.id {
                        Label(planSelectionDescription(plan), systemImage: "checkmark")
                    } else {
                        Text(planSelectionDescription(plan))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("追加先予定")
                    .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Divider()
                    .frame(height: 20)

                Text(selectedPlanSelectionText)
                    .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                    .foregroundStyle(registrationPalette.globalTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(registrationPalette.globalTint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var batchImportedScheduleSection: some View {
        if !batchImportedScheduleDrafts.isEmpty {
            FavorecoRegistrationSection("一括登録する別日程") {
                ForEach(Array(batchImportedScheduleDrafts.enumerated()), id: \.offset) { index, importedDraft in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(importedDraft.trimmedTitle.isEmpty ? "公演名未設定" : importedDraft.trimmedTitle)
                                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                .lineLimit(1)
                            Text(importedScheduleSummary(importedDraft))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Button {
                            batchImportedScheduleDrafts.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("一括登録候補から削除")
                    }
                }

                Text("保存すると、選択した別日程を同じ公演の予定としてまとめて登録します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var ticketRegistrationSections: some View {
        FavorecoRegistrationSection("チケット情報") {
            if draft.createsTicketAttempt {
                if isUnifiedRegistration {
                    if unifiedPurpose == .application {
                        ExplicitFormControlRow(title: "申込方法") {
                            Picker("申込方法", selection: $draft.flowKey) {
                                ForEach(unifiedApplicationFlowOptions) { flow in
                                    Text(flow.key == "lotteryPlanned" ? "抽選" : "先着")
                                        .tag(flow.key)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .onChange(of: draft.flowKey) { _, newValue in
                            draft.applyFlowDefaults(newValue)
                        }
                    }
                } else {
                    ExplicitFormControlRow(title: "登録内容") {
                        Picker("登録内容", selection: $draft.flowKey) {
                            ForEach(draft.flowOptions) { flow in
                                Text(flow.name).tag(flow.key)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .onChange(of: draft.flowKey) { _, newValue in
                        draft.applyFlowDefaults(newValue)
                    }
                }

                if showsTicketApplicationDetails {
                    ticketFlowGuide
                }

                if draft.showsEntryRoute || draft.showsAccountFields || draft.showsTicketGuide {
                    applicationDetailsSection
                }
            }
        }

        if draft.createsTicketAttempt && draft.showsAnyTicketMilestone {
            FavorecoRegistrationSection("チケットスケジュール") {
                TicketMilestoneDateGuidance()
                if draft.showsSaleStart {
                    DateToggleRow(title: draft.saleStartLabel, isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                }
                if draft.showsApplyDeadline {
                    DateToggleRow(title: "抽選申込締切", isOn: $draft.hasApplyDeadline, date: $draft.applyDeadlineAt)
                }
                if draft.showsResultAnnounce {
                    DateToggleRow(title: "当落発表", isOn: $draft.hasResultAnnounce, date: $draft.resultAnnounceAt)
                }
                if draft.showsPaymentDeadline {
                    DateToggleRow(title: "支払締切", isOn: $draft.hasPaymentDeadline, date: $draft.paymentDeadlineAt)
                }
                if draft.showsIssueStart {
                    DateToggleRow(title: "チケット受取開始", isOn: $draft.hasIssueStart, date: $draft.issueStartAt)
                }
            }
        }

        if draft.createsTicketAttempt && draft.showsTicketDetails {
            FavorecoRegistrationSection("金額・座席") {
                ExplicitFormTextField(
                    title: "チケット代（任意）",
                    prompt: "金額",
                    text: $draft.priceText,
                    labelStyle: .horizontal
                )
                .keyboardType(.numberPad)
                ExplicitFormTextField(
                    title: "手数料（任意）",
                    prompt: "金額",
                    text: $draft.feeText,
                    labelStyle: .horizontal
                )
                .keyboardType(.numberPad)
                ExplicitFormControlRow(title: "枚数") {
                    Stepper(value: $draft.quantity, in: 1...20) {
                        Text("\(draft.quantity)枚")
                            .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                    }
                    .fixedSize()
                }
                ExplicitFormTextField(
                    title: "座席（任意）",
                    prompt: "座席・整理番号",
                    text: $draft.seatText,
                    axis: .vertical,
                    minimumLines: 1,
                    maximumLines: 2,
                    labelStyle: .horizontal
                )
            }
        }

        if isUnifiedRegistration && unifiedPurpose == .application {
            additionalApplicationsSection
        }
    }

    private var informationImageImportSection: some View {
        Section {
            Button {
                isShowingInformationImageSource = true
            } label: {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "camera.viewfinder", size: 19)
                        .foregroundStyle(registrationPalette.globalTint)
                        .frame(width: 26)
                    Text(isReadingTicketImage ? "画像を読み取り中" : "写真・カメラから情報入力")
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer(minLength: 4)
                    if isReadingTicketImage {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isReadingTicketImage || !usesOCRImportAssist)

            Button {
                isShowingTicketTextImport = true
            } label: {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "doc.text", size: 17)
                        .foregroundStyle(registrationPalette.globalTint)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("テキストを貼り付けて入力")
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.primary)
                        Text("案内メールや購入完了画面の文字を解析します")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("読み取りを使わず、この下の各項目へ直接入力することもできます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

            if !usesOCRImportAssist {
                Text("画像からの情報入力は設定でOFFになっています。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            } else if !ticketOCRStatus.isEmpty {
                Text(ticketOCRStatus)
                    .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var ticketTextImportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $pastedTicketText)
                        .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                        .frame(minHeight: 180)
                } header: {
                    Text("案内メール・購入完了画面の文字")
                } footer: {
                    Text("読み取り後に候補を確認・修正できます。元の文字列は保存しません。")
                }
            }
            .navigationTitle("テキストから入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isShowingTicketTextImport = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("読み取る") { importPastedTicketText() }
                        .disabled(pastedTicketText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var performanceURLImportSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("公演の公式ページ")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))

                TextField("https://", text: $performanceImportURL)
                    .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 54)
                    .background(
                        TheaterLifecycleFlatStyle.fieldBackground,
                        in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    }

                Text("公演名・公式URL・公演画像を取得し、空いている項目へ仮入力します。保存前に修正できます。")
                    .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("サイト側の制限やページ構造により、情報を取得できない場合があります。その場合もURLを保存し、空欄を手入力できます。")
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if !performanceImportStatus.isEmpty {
                    Text(performanceImportStatus)
                        .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(TheaterLifecycleFlatStyle.canvasBackground.ignoresSafeArea())
            .navigationTitle("URLから入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isShowingPerformanceURLImport = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isFetchingPerformanceURL ? "取得中" : "取得") {
                        Task { await fetchPerformanceURLMetadata() }
                    }
                    .disabled(
                        performanceImportURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isFetchingPerformanceURL
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func fetchPerformanceURLMetadata() async {
        let source = performanceImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        isFetchingPerformanceURL = true
        performanceImportStatus = "URLを読み取り中です。"
        defer { isFetchingPerformanceURL = false }
        do {
            let candidate = try await URLMetadataService.fetch(
                from: source,
                includesStructuredData: true
            )
            var appliedFields = [String]()
            if draft.trimmedTitle.isEmpty, !candidate.title.isEmpty {
                draft.title = candidate.title
                appliedFields.append("公演名")
            }
            if draft.trimmedOfficialURL.isEmpty, let officialURL = candidate.officialURL {
                draft.officialURL = officialURL.absoluteString
                appliedFields.append("公式サイト")
            }
            if draft.trimmedEventTicketURL.isEmpty, let purchaseURL = candidate.purchaseURL {
                draft.eventTicketURL = purchaseURL.absoluteString
                appliedFields.append("チケットサイト")
            }
            if draft.trimmedPurchaseURL.isEmpty,
               draft.createsTicketAttempt,
               let purchaseURL = candidate.purchaseURL {
                draft.purchaseURL = purchaseURL.absoluteString
                appliedFields.append("申込・購入URL")
            }
            performanceImportURL = candidate.resolvedURL.absoluteString

            if draft.trimmedOrganizerName.isEmpty,
               let organizer = candidate.contributors.first(where: {
                   ["organizer", "performing_organization", "production", "planning"].contains($0.roleKey)
               }) {
                draft.organizerName = organizer.name
                appliedFields.append("公演団体")
            }
            if draft.trimmedEventCreditsText.isEmpty, !candidate.creditsText.isEmpty {
                draft.eventCreditsText = candidate.creditsText
                appliedFields.append("キャスト・スタッフ")
            }

            if eventEyecatchData == nil, let imageData = candidate.imageData {
                eventEyecatchData = await Task.detached(priority: .userInitiated) {
                    QuickCaptureImageService.compressedJPEG(from: imageData)
                }.value
                if eventEyecatchData != nil { appliedFields.append("アイキャッチ") }
            }

            if unifiedPurpose != .interested {
                if draft.trimmedVenueName.isEmpty, !candidate.venueName.isEmpty {
                    draft.venueName = candidate.venueName
                    appliedFields.append("会場")
                }
                if draft.venueAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !candidate.venueAddress.isEmpty {
                    draft.venueAddress = candidate.venueAddress
                    appliedFields.append("住所")
                }
                if !draft.hasConfirmedSchedule, let eventDate = candidate.eventDate {
                    draft.hasConfirmedSchedule = true
                    draft.startsAt = eventDate
                    if let eventEndDate = candidate.eventEndDate {
                        draft.hasEndTime = true
                        draft.endsAt = eventEndDate
                    }
                    appliedFields.append("観劇日")
                }
            }

            performanceImportStatus = "URLから\(appliedFields.joined(separator: "・"))を仮入力しました。"
            isShowingPerformanceURLImport = false
        } catch {
            performanceImportStatus = "このサイトから情報を取得できませんでした。サイト側の制限により取得できない場合があります。URLを保存して空欄を手入力できます。"
        }
    }

    private func importPastedTicketText() {
        let text = pastedTicketText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate = makeTicketImportCandidate(
            text: text,
            analysis: nil,
            canImportPlanInformation: selectedExistingPlan == nil
        ) else {
            ticketOCRStatus = "入力項目の候補を見つけられませんでした。各項目へ直接入力してください。"
            isShowingTicketTextImport = false
            return
        }
        ticketImportCandidates = [candidate.withExistingDuplicate(isExistingTicketImportCandidate(candidate))]
        ticketOCRStatus = "読み取った候補を確認してください。"
        pastedTicketText = ""
        isShowingTicketTextImport = false
        isShowingTicketImportReview = true
    }

    private var eventEyecatchSection: some View {
        Section {
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if let eventEyecatchData, let image = UIImage(data: eventEyecatchData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(.secondarySystemFill)
                            FavorecoIcon(systemName: "photo", size: 24)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 96, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $selectedEventEyecatchItem, matching: .images) {
                        FavorecoIconLabel("写真を選ぶ", systemImage: "photo.on.rectangle", iconSize: 13)
                    }
                    .buttonStyle(.plain)

                    Button {
                        openEventEyecatchCamera()
                    } label: {
                        FavorecoIconLabel("撮影する", systemImage: "camera", iconSize: 13)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        eventEyecatchData = nil
                    } label: {
                        FavorecoIconLabel("削除", systemImage: "trash", iconSize: 13)
                    }
                    .buttonStyle(.plain)
                    .disabled(eventEyecatchData == nil)
                }
                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                .foregroundStyle(registrationPalette.globalTint)
            }
            .padding(.vertical, 2)
        } header: {
            FavorecoRegistrationSectionHeader("アイキャッチ")
        }
    }

    @ViewBuilder
    private var planLifecycleEditSections: some View {
        StagedRecordBlock(
            title: planPrimaryRecordTitle,
            description: planPrimaryRecordSubtitle,
            units: [planPrimaryRecordUnit],
            status: planLifecycleStatus(for:),
            isExpanded: planLifecycleExpansionBinding(for:)
        ) { _ in
                VStack(spacing: 0) {
                    ExplicitFormTextField(
                        title: "イベント名（必須）",
                        prompt: "イベント名を入力",
                        text: $draft.title,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 3,
                        labelStyle: .stacked,
                        inputFontSize: 17
                    )
                    Divider()

                    if usesOpeningTime {
                        TheaterScheduleDateRow(
                            selection: scheduleDateBinding,
                            isSet: $draft.hasConfirmedSchedule,
                            onClear: clearExperienceSchedule,
                            usesHorizontalLayout: true,
                            emphasizesHorizontalLabel: true
                        )
                        OptionalTenMinuteTimeRow(
                            title: "開場",
                            selection: openingTimeBinding,
                            isSet: $draft.hasOpeningTime,
                            defaultValue: defaultOpeningTime,
                            usesHorizontalLayout: true,
                            emphasizesHorizontalLabel: true
                        )
                        TenMinuteTimeRow(
                            title: "開演",
                            selection: startTimeBinding,
                            usesHorizontalLayout: true,
                            emphasizesHorizontalLabel: true
                        )
                        TenMinuteTimeRow(
                            title: "終了",
                            selection: endTimeBinding,
                            usesHorizontalLayout: true,
                            emphasizesHorizontalLabel: true
                        )
                    } else {
                        ExperienceDateTimeRangeEditor(
                            startsAt: startTimeBinding,
                            endsAt: endTimeBinding,
                            dateLabel: simpleScheduleDateLabel,
                            startTimeLabel: "開始時刻",
                            endTimeLabel: "終了時刻",
                            usesHorizontalRows: true,
                            emphasizesHorizontalLabels: true
                        )
                    }

                    Divider()
                    inheritedTheaterVenueChoices
                    PlanVenueSearchField(
                        title: planVenueFieldTitle,
                        prompt: planVenueFieldPrompt,
                        text: venueNameBinding,
                        tint: registrationPalette.globalTint,
                        searchAction: { isShowingPlaceSearch = true }
                    )
                    placeSuggestionList
                    ExplicitFormTextField(
                        title: "住所",
                        prompt: "例：東京都千代田区…",
                        text: venueAddressBinding,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal,
                        emphasizesHorizontalLabel: true
                    )
                    .textContentType(.fullStreetAddress)

                    PlaceMapPreview(
                        venueName: draft.venueName,
                        address: draft.venueAddress,
                        latitude: draft.latitude,
                        longitude: draft.longitude
                    )
                }
                .padding(.top, 4)
        }

        StagedRecordBlock(
            title: planMemoryRecordTitle,
            description: planMemoryRecordSubtitle,
            units: planMemoryRecordUnits,
            status: planLifecycleStatus(for:),
            isExpanded: planLifecycleExpansionBinding(for:)
        ) { unit in
                Group {
                    switch unit.id {
                    case "planTags":
                        TicketTagInputField(text: $draft.planTagNamesText)
                    case "theaterRating", "liveRating", "outingRating", "screenWorkRating", "bookRating":
                        ExperienceRatingUnitEditor(
                            overallRating: $draft.planOverallRating,
                            ratingText: planRatingLabel
                        )
                    case "liveSetlist":
                        LiveSetlistEditor(entries: $draft.planLiveSetlistEntries)
                    case "moments":
                        VisitMomentEntriesEditor(
                            entries: $draft.planMomentEntries,
                            availablePhotos: planMomentPhotoChoices,
                            itemName: planTemplateKey == "theme_park" ? "イベント・体験" : "見たもの・体験"
                        )
                    case "people":
                        if planTemplateKey == "theater" {
                            TheaterFocusPeopleEditor(
                                existingLinks: [],
                                deletedLinkIDs: .constant([]),
                                pendingLinks: $planPendingPeople,
                                personMasters: personMasters
                            )
                        } else {
                            PeopleUnitEditor(
                                existingLinks: [],
                                deletedLinkIDs: .constant([]),
                                pendingLinks: $planPendingPeople,
                                personMasters: personMasters,
                                roleOptions: planTemplateKey == "movie" ? screenWorkPeopleRoleOptions : PersonRoleOption.all,
                                emptyDescription: "",
                                allowsOrganizations: planTemplateKey != "movie",
                                namePlaceholder: planTemplateKey == "movie" ? "監督・出演者名" : "人物・団体名",
                                addButtonTitle: planTemplateKey == "movie" ? "監督・出演者を追加" : "人物・団体を追加"
                            )
                        }
                    case "planPhotos":
                        PhotoUnitEditor(
                            existingPhotos: activePlanPhotos,
                            deletedPhotoIDs: $deletedPlanPhotoIDs,
                            existingPhotoMetadata: $existingPlanPhotoMetadata,
                            pendingPhotos: $planPendingPhotos,
                            selectedItems: $selectedPlanPhotoItems,
                            category: resolvedTargetEvent?.category ?? selectedCategory,
                            theaterContentMode: .libraryOnly,
                            showsHeading: false,
                            aspectRatioKey: $planPhotoAspectRatioKey,
                            coverPhotoPath: $planCoverPhotoPath,
                            heroBackgroundPath: $planHeroBackgroundPath,
                            heroBackgroundPresetKey: $planHeroBackgroundPresetKey,
                            showsBookFormatPicker: false,
                            showsHeroBackgroundPicker: false
                        )
                    case "planMemo":
                        ExperienceMemoUnitEditor(
                            text: $draft.memo,
                            styleRuns: $draft.planMemoStyleRuns,
                            placeholder: planMemoryPrompt
                        )
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 4)
        }

        StagedRecordBlock(
            title: planNotesRecordTitle,
            description: "公式・参考情報、補足",
            units: [planNotesRecordUnit],
            status: planLifecycleStatus(for:),
            isExpanded: planLifecycleExpansionBinding(for:)
        ) { _ in
                VStack(spacing: 0) {
                    ExplicitFormTextField(
                        title: isSimplePlan ? "案内URL（任意）" : "公式URL（任意）",
                        prompt: "https://",
                        text: $draft.officialURL,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                    Divider()
                    ExplicitFormTextField(
                        title: "施設URL（任意）",
                        prompt: "公式サイトのURL",
                        text: venueOfficialURLBinding,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                .padding(.top, 4)
        }
    }

    private var planPrimaryRecordUnit: RecordUnitDefinition {
        RecordUnitDefinition(
            id: "planBasic",
            name: planPrimaryRecordTitle,
            description: planPrimaryRecordSubtitle,
            isRequired: true
        )
    }

    private var planMemoryRecordUnits: [RecordUnitDefinition] {
        let rating = RecordUnitDefinition(
            id: planRatingUnitID,
            name: "評価",
            description: "この体験の満足度",
            isRequired: false
        )
        let photos = RecordUnitDefinition(
            id: "planPhotos",
            name: "写真",
            description: "分類とキャプションで思い出を整理",
            isRequired: false
        )
        let people = RecordUnitDefinition(
            id: "people",
            name: "人物・団体",
            description: "出演者、作家、作者、主催、制作など",
            isRequired: false
        )
        let memo = RecordUnitDefinition(
            id: "planMemo",
            name: "感想・メモ",
            description: "印象、あとで見返したいこと",
            isRequired: false
        )
        let tags = RecordUnitDefinition(
            id: "planTags",
            name: "タグ",
            description: "この予定・記録を整理するタグ",
            isRequired: false
        )

        switch planTemplateKey {
        case "theater": return [rating, photos, tags, memo]
        case "live":
            return [
                rating,
                RecordUnitDefinition(id: "liveSetlist", name: "セットリスト", description: "曲順や演目を記録", isRequired: false),
                people,
                photos,
                tags,
                memo,
            ]
        case "movie": return [rating, photos, people, tags, memo]
        case "book": return [rating, photos, tags, memo]
        case "goshuin": return [photos, people, tags, memo]
        case "sake": return [rating, photos, tags, memo]
        case "random_goods": return [photos, tags, memo]
        case "museum", "theme_park", "nature_living":
            return [
                rating,
                RecordUnitDefinition(
                    id: "moments",
                    name: planTemplateKey == "theme_park" ? "体験したこと" : "見たもの・体験",
                    description: "項目ごとにメモと写真を紐づけ",
                    isRequired: false
                ),
                photos,
                people,
                tags,
                memo,
            ]
        default: return [people, photos, tags, memo]
        }
    }

    private var planNotesRecordUnit: RecordUnitDefinition {
        RecordUnitDefinition(
            id: "planNotes",
            name: planNotesRecordTitle,
            description: "公式・参考情報、補足",
            isRequired: false
        )
    }

    private func planLifecycleStatus(for id: String) -> RecordUnitStatus {
        switch id {
        case "planBasic":
            return draft.hasConfirmedSchedule ? .entered : .required
        case "planTags":
            return draft.planTagNamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .optional : .entered
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating", "bookRating":
            return draft.planOverallRating > 0 ? .entered : .optional
        case "liveSetlist":
            return draft.planLiveSetlistEntries.contains { !$0.isEmpty } ? .entered : .optional
        case "moments":
            return draft.planMomentEntries.contains { !$0.isEmpty } ? .entered : .optional
        case "people":
            return planPendingPeople.isEmpty ? .optional : .entered
        case "planPhotos":
            return activePlanPhotos.isEmpty && planPendingPhotos.isEmpty ? .optional : .entered
        case "planMemo":
            return draft.trimmedMemo.isEmpty ? .optional : .entered
        case "planNotes":
            return draft.trimmedOfficialURL.isEmpty && venueOfficialURLString.isEmpty ? .optional : .entered
        default:
            return .optional
        }
    }

    private func planLifecycleExpansionBinding(for id: String) -> Binding<Bool> {
        switch id {
        case "planBasic":
            return $isPlanBasicExpanded
        case "planTags", "planPhotos", "planMemo", "theaterRating", "liveRating", "outingRating", "screenWorkRating", "bookRating", "liveSetlist", "moments", "people":
            return $isPlanMemoriesExpanded
        case "planNotes":
            return $isPlanNotesExpanded
        default:
            return .constant(false)
        }
    }

    private func configurePlanLifecycleExpansionIfNeeded() {
        guard editsPlanOnly, !didConfigurePlanLifecycleExpansion else { return }
        didConfigurePlanLifecycleExpansion = true
        let referenceEnd = max(draft.endsAt, draft.startsAt)
        let hasEnded = draft.hasConfirmedSchedule && referenceEnd < Date()
        let stage: RecordFormOpeningStage = hasEnded ? .afterExperience : .plannedTarget
        let expansion = RecordLifecycleBlockExpansion.resolved(for: stage)
        isPlanBasicExpanded = expansion.primary
        isPlanMemoriesExpanded = expansion.memories
        isPlanNotesExpanded = expansion.notes
    }

    private var planTemplateKey: String {
        resolvedTargetEvent?.category?.templateKey ?? selectedCategory?.templateKey ?? ""
    }

    private var planRatingUnitID: String {
        switch planTemplateKey {
        case "theater": "theaterRating"
        case "live": "liveRating"
        case "movie": "screenWorkRating"
        case "book": "bookRating"
        default: "outingRating"
        }
    }

    private var planRatingLabel: String {
        draft.planOverallRating > 0 ? String(format: "%.1f", draft.planOverallRating) : "未評価"
    }

    private var planMomentPhotoChoices: [MomentPhotoChoice] {
        let existing = activePlanPhotos.enumerated().map { index, photo in
            MomentPhotoChoice(
                id: photo.id,
                title: photo.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "写真 \(index + 1)"
                    : photo.caption,
                data: photo.data
            )
        }
        let pending = planPendingPhotos.enumerated().map { index, photo in
            MomentPhotoChoice(
                id: photo.id,
                title: photo.metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "追加写真 \(index + 1)"
                    : photo.metadata.caption,
                data: photo.data
            )
        }
        return existing + pending
    }

    private var planPrimaryRecordTitle: String {
        switch planTemplateKey {
        case "theater": "鑑賞記録"
        case "live": "参戦記録"
        case "movie", "museum": "鑑賞記録"
        case "theme_park": "来園記録"
        case "nature_living", "outing_facility": "体験記録"
        case "book": "読書記録"
        case "goshuin": "参拝記録"
        case "sake": "飲酒記録"
        case "random_goods": "収集記録"
        default: "鑑賞記録"
        }
    }

    private var planPrimaryRecordSubtitle: String {
        switch planTemplateKey {
        case "theater", "live": "参加日・会場"
        case "movie": "鑑賞日・鑑賞場所"
        case "museum": "鑑賞日・施設・展示名"
        case "theme_park": "来園日・施設"
        case "nature_living", "outing_facility": "訪問日・施設"
        case "book": "読書日・作品"
        case "goshuin": "参拝日・寺社"
        case "sake": "飲んだ日・銘柄・場所"
        case "random_goods": "入手日・対象"
        default: "日時・場所"
        }
    }

    private var planPrimaryRecordIcon: String {
        switch planTemplateKey {
        case "book": "books.vertical"
        case "goshuin": "building.columns"
        case "sake": "wineglass"
        case "random_goods": "shippingbox"
        default: "calendar"
        }
    }

    private var planMemoryRecordTitle: String {
        switch planTemplateKey {
        case "book": "読後感"
        case "sake": "感想"
        case "random_goods": "コレクションメモ"
        default: "思い出の記録"
        }
    }

    private var planNotesRecordTitle: String {
        switch planTemplateKey {
        case "sake": "お酒情報"
        default: "備考記録"
        }
    }

    private var planMemoryRecordSubtitle: String {
        switch planTemplateKey {
        case "live": "評価・セットリスト・写真・感想"
        case "theme_park": "評価・体験したイベント・写真・感想"
        case "nature_living", "outing_facility": "評価・見たもの・写真・感想"
        case "book": "評価・引用・ページメモ・感想"
        case "goshuin": "写真・同行者・感想"
        case "sake": "評価・写真・感想"
        case "random_goods": "画像・入手履歴・メモ"
        default: "評価・写真・同行者・感想"
        }
    }

    private var planMemoryPrompt: String {
        "例：見たい展示、同行者"
    }

    private var planTargetFieldTitle: String {
        switch planTemplateKey {
        case "movie": "作品名"
        case "museum": "展示・イベント名"
        case "theme_park", "outing_facility": "施設名"
        case "nature_living": "スポット名"
        case "book": "書名"
        case "goshuin": "寺社名"
        case "sake": "銘柄"
        case "random_goods": "対象名"
        default: "タイトル"
        }
    }

    private var venueNameBinding: Binding<String> {
        Binding {
            draft.venueName
        } set: { value in
            draft.venueName = value
            draft.clearPlaceSelection()
            suppressesPlaceSuggestions = false
        }
    }

    private func restoreInitialCategoryIfNeeded() {
        if let initialCategoryID,
           visibleCategories.contains(where: { $0.id == initialCategoryID }) {
            draft.categoryID = initialCategoryID
        } else {
            draft.setInitialCategoryIfNeeded(visibleCategories)
        }
    }

    private func normalizeSimpleDestinationVenueName() {
        guard isSimpleDestinationPlan,
              draft.venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        draft.venueName = resolvedTargetEvent?.title ?? draft.title
    }

    private var venueAddressBinding: Binding<String> {
        Binding {
            draft.venueAddress
        } set: { value in
            draft.venueAddress = value
            draft.clearPlaceCoordinates()
        }
    }

    private var venueOfficialURLBinding: Binding<String> {
        Binding {
            draft.venueOfficialURL
        } set: { value in
            draft.venueOfficialURL = value
        }
    }

    private var venueOfficialURLString: String {
        let explicit = draft.venueOfficialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        if let publicPlaceSelection = draft.publicPlaceSelection {
            return publicPlaceSelection.entry.officialURL
        }

        let normalizedName = normalizedPlaceText(draft.venueName)
        guard !normalizedName.isEmpty else { return "" }
        let normalizedAddress = normalizedPlaceText(draft.venueAddress)
        return placeMasters.first { place in
            guard !place.isArchived,
                  normalizedPlaceText(place.name) == normalizedName else { return false }
            if normalizedAddress.isEmpty { return true }
            return normalizedPlaceText(place.address) == normalizedAddress
        }?.officialURL ?? ""
    }

    @ViewBuilder
    private var placeSuggestionList: some View {
        let hidesSuggestions = suppressesPlaceSuggestions || hasResolvedVenuePlace
        let suggestions = hidesSuggestions ? [] : draft.placeSuggestions(from: placeMasters)
        let publicSuggestions = hidesSuggestions ? [] : publicCatalogSuggestions
        if !suggestions.isEmpty || !publicSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !suggestions.isEmpty {
                    Text("登録済みの場所")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(suggestions) { place in
                        Button {
                            finishPlaceSuggestionSelection()
                            draft.apply(placeMaster: place)
                            resolveSimpleDestinationCoordinateIfNeeded()
                        } label: {
                            HStack(spacing: 10) {
                                FavorecoIcon(systemName: "mappin.and.ellipse", size: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)
                                    if !place.address.isEmpty {
                                        Text(place.address)
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !publicSuggestions.isEmpty {
                    Text("全国場所カタログ")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(publicSuggestions) { entry in
                        Button {
                            let selection = PublicPlaceSelectionDraft(entry: entry)
                            finishPlaceSuggestionSelection()
                            draft.apply(publicPlace: selection)
                            resolveSimpleDestinationCoordinateIfNeeded()
                        } label: {
                            HStack(spacing: 10) {
                                FavorecoIcon(systemName: "building.2.crop.circle", size: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.officialName).foregroundStyle(.primary)
                                    Text(entry.address.isEmpty ? entry.prefecture : entry.address)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                FavorecoIcon(systemName: "arrow.up.left", size: 16)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var publicCatalogSuggestions: [PublicPlaceCatalogEntry] {
        let query = draft.trimmedVenueName
        guard !query.isEmpty else { return [] }
        let importedMarkers = Set(placeMasters.map(\.sourceSnapshotRaw))
        return PublicPlaceCatalogSearch.suggestions(
            for: query,
            in: publicPlaceStore.entries,
            excludingSourceMarkers: importedMarkers,
            includesClosed: false
        )
        .filter { PublicPlaceCatalogImporter.matchingPlace(for: $0, in: placeMasters) == nil }
    }

    private var simpleDestinationVenueFieldTitle: String {
        switch selectedCategory?.templateKey {
        case "nature_living":
            return "施設・スポット名"
        case "theme_park", "outing_facility":
            return "施設名"
        default:
            return "場所・施設名"
        }
    }

    private var simpleDestinationVenueFieldPrompt: String {
        simpleDestinationVenueFieldTitle + "を入力して候補から選択"
    }

    private var planVenueFieldTitle: String {
        switch selectedCategory?.templateKey {
        case "museum": "美術館・博物館名"
        case "movie": "映画館・鑑賞場所"
        default: "会場名（任意）"
        }
    }

    private var planVenueFieldPrompt: String {
        switch selectedCategory?.templateKey {
        case "museum": "施設名を入力"
        case "movie": "映画館・場所を入力"
        default: "会場名を入力"
        }
    }

    private var planVenueOfficialSiteFieldTitle: String {
        selectedCategory?.templateKey == "museum"
            ? "施設公式サイト（任意）"
            : "会場公式サイト（任意）"
    }

    private var planVenueOfficialSiteLinkTitle: String {
        selectedCategory?.templateKey == "museum"
            ? "施設サイトを開く"
            : "会場サイトを開く"
    }

    private var hasResolvedVenuePlace: Bool {
        if draft.publicPlaceSelection != nil { return true }
        if draft.latitude != 0 || draft.longitude != 0 { return true }

        let name = normalizedPlaceText(draft.venueName)
        let address = normalizedPlaceText(draft.venueAddress)
        guard !name.isEmpty, !address.isEmpty else { return false }
        return placeMasters.contains { place in
            guard !place.isArchived,
                  normalizedPlaceText(place.name) == name else { return false }
            return normalizedPlaceText(place.address) == address
        }
    }

    @ViewBuilder
    private var inheritedTheaterVenueChoices: some View {
        if let event = resolvedTargetEvent,
           event.category?.templateKey == "theater" {
            let venues = VisitUnitFields(rawValue: event.unitFieldsRaw)
                .eventVenues
                .filter { !$0.isEmpty }
            if venues.count > 1 {
                VStack(alignment: .leading, spacing: 7) {
                    Text("公演情報から会場を選択")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    ForEach(venues) { venue in
                        Button {
                            finishPlaceSuggestionSelection()
                            draft.applyRegisteredVenue(venue)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: draft.trimmedVenueName == venue.trimmedName
                                      ? "checkmark.circle.fill"
                                      : "mappin.circle")
                                    .foregroundStyle(registrationPalette.globalTint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(venue.trimmedName.isEmpty ? "会場名未登録" : venue.trimmedName)
                                        .font(FavorecoTypography.bodyStrong)
                                    if !venue.trimmedAddress.isEmpty {
                                        Text(venue.trimmedAddress)
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func finishPlaceSuggestionSelection() {
        suppressesPlaceSuggestions = true
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func resolveSimpleDestinationCoordinateIfNeeded() {
        guard isSimpleDestinationPlan,
              draft.latitude == 0,
              draft.longitude == 0 else { return }

        let selectedName = draft.trimmedVenueName
        let selectedAddress = draft.venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectionKey = "\(selectedName)|\(selectedAddress)"
        let queries = [
            [selectedName, selectedAddress].filter { !$0.isEmpty }.joined(separator: " "),
            selectedAddress,
            selectedName
        ].reduce(into: [String]()) { values, query in
            guard !query.isEmpty, !values.contains(query) else { return }
            values.append(query)
        }

        Task { @MainActor in
            for query in queries {
                guard let candidate = try? await PlaceSearchService.search(query: query).first else {
                    continue
                }
                let currentKey = "\(draft.trimmedVenueName)|\(draft.venueAddress.trimmingCharacters(in: .whitespacesAndNewlines))"
                guard currentKey == selectionKey,
                      draft.latitude == 0,
                      draft.longitude == 0 else { return }
                draft.latitude = candidate.latitude
                draft.longitude = candidate.longitude
                return
            }
        }
    }

    private var navigationTitle: String {
        if isUnifiedRegistration { return "公演・チケットを登録" }
        if entryMode == .plan {
            if ["theme_park", "nature_living", "outing_facility"].contains(selectedCategory?.templateKey ?? "") {
                return "行く予定を立てる"
            }
            if selectedCategory?.templateKey == "theater" {
                return unifiedFormEntry.navigationTitle
            }
            return editingPlan == nil ? "予定を立てる" : "予定を編集"
        }
        if editingPlan != nil { return "予定を編集" }
        return draft.createsTicketAttempt ? "チケットスケジュール" : "予定を立てる"
    }

    private var unifiedPurposeDescription: String {
        switch unifiedPurpose {
        case .interested:
            return "公演名・種別・公式情報を保存します。日時やチケットは後から追加できます。"
        case .plan:
            return "公演情報と、観に行く日時・会場を登録します。"
        case .application:
            return "公演情報、参加日時・会場、申込先とチケット工程を登録します。"
        case .acquired:
            return "公演情報、参加日時・会場、購入先・金額・枚数・座席を登録します。"
        }
    }

    @ViewBuilder
    private var additionalApplicationsSection: some View {
        Section {
            ForEach($additionalApplications) { $application in
                DisclosureGroup(isExpanded: $application.isExpanded) {
                    additionalApplicationEditor(application: $application)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(application.title)
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                        Text(application.summary)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        additionalApplications.removeAll { $0.id == application.id }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }

            Button {
                addApplicationForSameSchedule()
            } label: {
                FavorecoIconLabel("同じ日程に別の申込を追加", systemImage: "plus.circle")
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
            }

            if !additionalApplications.isEmpty {
                Text("公演・参加日時は共通です。申込枠、購入先、名義、各期限だけを申込ごとに設定します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            FavorecoRegistrationSectionHeader("同じ日程の別申込")
        }
    }

    @ViewBuilder
    private func additionalApplicationEditor(
        application: Binding<AdditionalTicketApplicationDraft>
    ) -> some View {
        let applicationDraft = application.draft

        ExplicitFormControlRow(title: "申込方法") {
            Picker("申込方法", selection: applicationDraft.flowKey) {
                ForEach(unifiedApplicationFlowOptions) { flow in
                    Text(flow.key == "lotteryPlanned" ? "抽選" : "先着")
                        .tag(flow.key)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: applicationDraft.wrappedValue.flowKey) { _, newValue in
            applicationDraft.wrappedValue.applyFlowDefaults(newValue)
        }

        if applicationDraft.wrappedValue.showsEntryRoute {
            ExplicitFormControlRow(title: applicationDraft.wrappedValue.entryRouteLabel) {
                Picker(
                    applicationDraft.wrappedValue.entryRouteLabel,
                    selection: applicationDraft.entryRouteKey
                ) {
                    Text("未設定").tag("")
                    ForEach(applicationDraft.wrappedValue.entryRouteOptions) { route in
                        Text(route.name).tag(route.key)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }

        if applicationDraft.wrappedValue.showsAccountFields {
            ExplicitFormControlRow(title: "申込アカウント", isOptional: true) {
                Picker("申込アカウント", selection: applicationDraft.accountID) {
                    Text("未設定").tag(Optional<UUID>.none)
                    ForEach(activeAccounts) { account in
                        Text(accountLabel(account)).tag(Optional(account.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .onChange(of: applicationDraft.wrappedValue.accountID) { previousAccountID, accountID in
                applicationDraft.wrappedValue.applyAccount(
                    activeAccounts.first { $0.id == accountID },
                    replacing: accounts.first { $0.id == previousAccountID }
                )
            }

            ExplicitFormTextField(
                title: "名義",
                prompt: "任意",
                text: applicationDraft.holderName,
                labelStyle: .horizontal
            )
        }

        ExplicitFormControlRow(title: "購入先") {
            Picker("購入先", selection: applicationDraft.ticketGuideKey) {
                ForEach(TicketGuideDefinition.all) { guide in
                    Text(guide.name).tag(guide.key)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: applicationDraft.wrappedValue.ticketGuideKey) { _, newValue in
            applicationDraft.wrappedValue.applyTicketGuide(newValue)
        }
        .disabled(applicationDraft.wrappedValue.accountID != nil)

        if applicationDraft.wrappedValue.ticketGuideKey == TicketGuideDefinition.customKey {
            ExplicitFormTextField(
                title: "購入先（任意）",
                prompt: "FC・公式サイトなど",
                text: applicationDraft.ticketSite,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal
            )
            ExplicitFormTextField(
                title: "購入URL（任意）",
                prompt: "申込・購入URL",
                text: applicationDraft.purchaseURL,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
        }

        if applicationDraft.wrappedValue.showsAnyTicketMilestone {
            TicketMilestoneDateGuidance()
        }
        if applicationDraft.wrappedValue.showsSaleStart {
            DateToggleRow(
                title: applicationDraft.wrappedValue.saleStartLabel,
                isOn: applicationDraft.hasSaleStart,
                date: applicationDraft.saleStartAt
            )
        }
        if applicationDraft.wrappedValue.showsApplyDeadline {
            DateToggleRow(
                title: "抽選申込締切",
                isOn: applicationDraft.hasApplyDeadline,
                date: applicationDraft.applyDeadlineAt
            )
        }
        if applicationDraft.wrappedValue.showsResultAnnounce {
            DateToggleRow(
                title: "当落発表",
                isOn: applicationDraft.hasResultAnnounce,
                date: applicationDraft.resultAnnounceAt
            )
        }
        if applicationDraft.wrappedValue.showsPaymentDeadline {
            DateToggleRow(
                title: "支払締切",
                isOn: applicationDraft.hasPaymentDeadline,
                date: applicationDraft.paymentDeadlineAt
            )
        }
        if applicationDraft.wrappedValue.showsIssueStart {
            DateToggleRow(
                title: "チケット受取開始",
                isOn: applicationDraft.hasIssueStart,
                date: applicationDraft.issueStartAt
            )
        }
    }

    private func addApplicationForSameSchedule() {
        var newDraft = TicketPlanDraft(entryMode: .ticketSchedule)
        newDraft.applyFlowDefaults(
            unifiedApplicationFlowOptions.contains { $0.key == draft.flowKey }
                ? draft.flowKey
                : "lotteryPlanned"
        )
        newDraft.applicationGroupIDRaw = draft.applicationGroupIDRaw
        newDraft.applicationGroupName = draft.applicationGroupName
        additionalApplications.append(
            AdditionalTicketApplicationDraft(draft: newDraft, isExpanded: true)
        )
        for index in additionalApplications.indices.dropLast() {
            additionalApplications[index].isExpanded = false
        }
    }

    private func applyUnifiedPurpose(_ purpose: TheaterLifecycleRegistrationPurpose) {
        isApplicationDetailsExpanded = purpose == .application
        isUnifiedWorkExpanded = true
        isUnifiedVisualExpanded = false
        isUnifiedParticipationExpanded = purpose == .plan
        isUnifiedTicketExpanded = purpose == .application || purpose == .acquired
        isUnifiedMemoExpanded = purpose == .interested
        isUnifiedCastExpanded = purpose == .interested
        if purpose != .application {
            additionalApplications.removeAll()
        }
        if purpose != .application && purpose != .acquired {
            batchImportedScheduleDrafts.removeAll()
        }
        switch purpose {
        case .interested:
            draft.createsTicketAttempt = false
            draft.hasConfirmedSchedule = false
        case .plan:
            draft.createsTicketAttempt = false
            draft.hasConfirmedSchedule = true
        case .application:
            draft.createsTicketAttempt = true
            if draft.flowKey != "lotteryPlanned" && draft.flowKey != "saleWaiting" {
                draft.flowKey = "lotteryPlanned"
                draft.statusKey = TicketFlowDefinition.definition(for: "lotteryPlanned").defaultStatusKey
            }
        case .acquired:
            draft.createsTicketAttempt = true
            draft.flowKey = "acquired"
            draft.statusKey = TicketFlowDefinition.definition(for: "acquired").defaultStatusKey
        }
    }

    private var unifiedFormEntry: TheaterUnifiedFormEntry {
        editingPlan == nil ? .planCreation : .planEditing
    }

    private var scheduleDateBinding: Binding<Date> {
        Binding(
            get: { draft.startsAt },
            set: { newDate in
                let dayStart = Calendar.current.startOfDay(for: newDate)
                let dayEnd = Calendar.current.date(
                    bySettingHour: 23,
                    minute: 50,
                    second: 0,
                    of: newDate
                ) ?? newDate
                let proposedStart = date(on: newDate, preservingTimeFrom: draft.startsAt)
                    .roundedToNearestTenMinutes()
                let start = min(max(proposedStart, dayStart), dayEnd)
                let proposedEnd = date(on: newDate, preservingTimeFrom: draft.endsAt)
                    .roundedToNearestTenMinutes()
                let end = min(max(proposedEnd, start), dayEnd)
                draft.startsAt = start
                draft.endsAt = end
                if draft.hasOpeningTime {
                    let opening = date(on: newDate, preservingTimeFrom: draft.opensAt)
                        .roundedToNearestTenMinutes()
                    draft.opensAt = min(max(opening, dayStart), start)
                }
            }
        )
    }

    private func clearExperienceSchedule() {
        draft.hasConfirmedSchedule = false
        draft.hasOpeningTime = false
        draft.opensAt = Date.distantPast
    }

    private var openingTimeBinding: Binding<Date> {
        Binding(
            get: { draft.opensAt },
            set: { newValue in
                let opening = date(on: draft.startsAt, preservingTimeFrom: newValue)
                    .roundedToNearestTenMinutes()
                draft.opensAt = min(max(opening, startOfScheduleDay), draft.startsAt)
            }
        )
    }

    private var defaultOpeningTime: Date {
        let proposed = Calendar.current.date(byAdding: .minute, value: -30, to: draft.startsAt)
            ?? draft.startsAt
        return max(proposed, startOfScheduleDay).roundedToNearestTenMinutes()
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { draft.startsAt },
            set: { newValue in
                let previousStart = draft.startsAt
                let duration = max(0, draft.endsAt.timeIntervalSince(previousStart))
                let start = date(on: previousStart, preservingTimeFrom: newValue)
                    .roundedToNearestTenMinutes()
                let proposedEnd = start.addingTimeInterval(duration)
                draft.startsAt = start
                draft.endsAt = min(max(proposedEnd, start), endOfScheduleDay)

                if draft.hasOpeningTime {
                    let openingOffset = previousStart.timeIntervalSince(draft.opensAt)
                    let proposedOpening = start.addingTimeInterval(-max(0, openingOffset))
                    draft.opensAt = min(max(proposedOpening, startOfScheduleDay), start)
                }
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { draft.endsAt },
            set: { newValue in
                let end = date(on: draft.startsAt, preservingTimeFrom: newValue)
                    .roundedToNearestTenMinutes()
                draft.endsAt = min(max(end, draft.startsAt), endOfScheduleDay)
            }
        )
    }

    private var startOfScheduleDay: Date {
        Calendar.current.startOfDay(for: draft.startsAt)
    }

    private var endOfScheduleDay: Date {
        Calendar.current.date(
            bySettingHour: 23,
            minute: 50,
            second: 0,
            of: draft.startsAt
        ) ?? draft.startsAt
    }

    private func date(on day: Date, preservingTimeFrom time: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func accountLabel(_ account: TicketAccount) -> String {
        let holder = account.accountName.isEmpty ? "名義未設定" : account.accountName
        return "\(account.serviceName)｜\(holder)"
    }

    private func importedScheduleSummary(_ importedDraft: TicketPlanDraft) -> String {
        let schedule = importedDraft.hasConfirmedSchedule
            ? FavorecoDateText.compactDateTime(importedDraft.startsAt)
            : "参加日未定"
        let values = [schedule, importedDraft.trimmedVenueName, importedDraft.trimmedTicketSite]
            .filter { !$0.isEmpty }
        return values.joined(separator: " / ")
    }

    private func openInformationCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }
        isShowingInformationCamera = true
    }

    private func openEventEyecatchCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }
        isShowingEventEyecatchCamera = true
    }

    @MainActor
    private func loadEventEyecatch(from item: PhotosPickerItem) async {
        defer { selectedEventEyecatchItem = nil }
        guard let sourceData = try? await item.loadTransferable(type: Data.self) else { return }
        eventEyecatchData = await Task.detached(priority: .userInitiated) {
            QuickCaptureImageService.compressedJPEG(from: sourceData)
        }.value
    }

    private func setEventEyecatch(from image: UIImage) {
        guard let sourceData = image.jpegData(compressionQuality: 0.9) else { return }
        Task {
            let compressed = await Task.detached(priority: .userInitiated) {
                QuickCaptureImageService.compressedJPEG(from: sourceData)
            }.value
            await MainActor.run { eventEyecatchData = compressed }
        }
    }

    @MainActor
    private func readTicketImages(from items: [PhotosPickerItem]) async {
        isReadingTicketImage = true
        ticketOCRStatus = "\(items.count)枚の画像から文字を読み取っています。"
        defer {
            isReadingTicketImage = false
            selectedTicketOCRItems = []
        }

        var sourceData: [Data] = []
        for item in items.prefix(2) {
            if let data = try? await item.loadTransferable(type: Data.self) {
                sourceData.append(data)
            }
        }
        guard !sourceData.isEmpty else {
            ticketOCRStatus = "画像を読み込めませんでした。別の画像をお試しください。"
            return
        }

        await analyzeTicketImageData(sourceData)
    }

    @MainActor
    private func readTicketCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            ticketOCRStatus = "撮影した画像を読み込めませんでした。"
            return
        }
        isReadingTicketImage = true
        ticketOCRStatus = "撮影した画像から文字を読み取っています。"
        defer { isReadingTicketImage = false }
        await analyzeTicketImageData([data])
    }

    @MainActor
    private func analyzeTicketImageData(_ sourceData: [Data]) async {

        let analyses = await Task.detached(priority: .userInitiated) {
            sourceData.map {
                QuickCaptureImageService.recognizedTextAnalysis(from: $0)
            }
        }.value
        let combinedText = analyses
            .map(\.fullText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !combinedText.isEmpty else {
            ticketOCRStatus = "文字を読み取れませんでした。必要な項目を手入力してください。"
            return
        }

        let canImportPlanInformation = selectedExistingPlan == nil
        let distinctScheduleMoments = Set(analyses.compactMap { analysis -> Int? in
            guard let dateRange = analysis.eventDateRange else { return nil }
            return Int(dateRange.startsAt.timeIntervalSince1970 / 300)
        })
        let distinctVenues = Set(analyses.compactMap { analysis -> String? in
            guard let venue = analysis.venueCandidates.first else { return nil }
            let normalized = normalizedImportValue(venue)
            return normalized.isEmpty ? nil : normalized
        })
        let separatesImagesAsSchedules = canImportPlanInformation
            && usesTicketRegistration
            && analyses.count > 1
            && (distinctScheduleMoments.count > 1 || distinctVenues.count > 1)
        let rawCandidates: [PendingTicketOCRImport]
        if separatesImagesAsSchedules {
            rawCandidates = analyses.compactMap { analysis in
                makeTicketImportCandidate(
                    text: analysis.fullText,
                    analysis: analysis,
                    canImportPlanInformation: true
                )
            }
        } else {
            rawCandidates = [makeTicketImportCandidate(
                text: combinedText,
                analysis: analyses.first,
                canImportPlanInformation: canImportPlanInformation
            )].compactMap { $0 }
        }
        let uniqueCandidates = deduplicatedTicketImportCandidates(rawCandidates)
            .map { candidate in
                candidate.withExistingDuplicate(isExistingTicketImportCandidate(candidate))
            }
        guard !uniqueCandidates.isEmpty else {
            ticketOCRStatus = "文字は読み取れましたが、自動反映できる項目は見つかりませんでした。"
            return
        }
        ticketImportCandidates = uniqueCandidates
        isShowingTicketImportReview = true
        ticketOCRStatus = uniqueCandidates.count == 1
            ? "読み取った候補を確認してください。"
            : "\(uniqueCandidates.count)件の候補を読み取りました。登録する内容を選んでください。"
    }

    private func makeTicketImportCandidate(
        text: String,
        analysis: QuickCaptureOCRResult?,
        canImportPlanInformation: Bool
    ) -> PendingTicketOCRImport? {
        guard !text.isEmpty else { return nil }
        let referenceDate = selectedExistingPlan?.startsAt ?? Date()
        var result = TicketOCRImportParser.parse(
            text: text,
            referenceDate: referenceDate
        )
        let eventMetadata = TicketOCRImportParser.parseEventMetadata(
            text: text,
            referenceDate: referenceDate
        )
        if !draft.showsSaleStart { result.saleStartAt = nil }
        if !draft.showsApplyDeadline { result.applyDeadlineAt = nil }
        if !draft.showsResultAnnounce { result.resultAnnounceAt = nil }
        if !draft.showsPaymentDeadline { result.paymentDeadlineAt = nil }
        if !draft.showsIssueStart { result.issueStartAt = nil }
        if !draft.showsTicketDetails {
            result.priceText = nil
            result.feeText = nil
            result.seatText = nil
            result.quantity = nil
        }
        let pending = PendingTicketOCRImport(
            result: result,
            suggestedTitle: canImportPlanInformation
                ? eventMetadata.title
                    ?? (analysis?.isTitleSuggestionReliable == true
                        && analysis?.suggestedTitle.isEmpty == false
                        ? analysis?.suggestedTitle
                        : nil)
                : nil,
            venue: canImportPlanInformation
                ? eventMetadata.venue ?? analysis?.venueCandidates.first
                : nil,
            eventDateRange: canImportPlanInformation
                ? eventMetadata.eventDateRange ?? analysis?.eventDateRange
                : nil,
            isExistingDuplicate: false
        )
        return pending.hasSuggestions ? pending : nil
    }

    private func deduplicatedTicketImportCandidates(
        _ candidates: [PendingTicketOCRImport]
    ) -> [PendingTicketOCRImport] {
        var fingerprints = Set<String>()
        return candidates.filter { fingerprints.insert($0.fingerprint).inserted }
    }

    private func isExistingTicketImportCandidate(_ candidate: PendingTicketOCRImport) -> Bool {
        guard let dateRange = candidate.eventDateRange else { return false }
        let calendar = Calendar.current
        let candidateTitle = normalizedImportValue(candidate.suggestedTitle ?? draft.trimmedTitle)
        let candidateVenue = normalizedImportValue(candidate.venue ?? "")
        guard !candidateTitle.isEmpty else { return false }
        let importedGuide = candidate.result.ticketGuideKey
        let importedURL = normalizedImportValue(candidate.result.purchaseURL ?? "")
        guard importedGuide != nil || !importedURL.isEmpty else { return false }
        return plans.contains { plan in
            guard !plan.isArchived,
                  calendar.isDate(plan.startsAt, equalTo: dateRange.startsAt, toGranularity: .minute) else {
                return false
            }
            let planTitle = normalizedImportValue(plan.event?.title ?? plan.title)
            guard candidateTitle == planTitle else { return false }
            let planVenue = normalizedImportValue(plan.venueNameSnapshot)
            guard candidateVenue.isEmpty || candidateVenue == planVenue else { return false }
            return (plan.ticketAttempts ?? []).contains { attempt in
                guard !attempt.isArchived else { return false }
                let storedGuide = TicketGuideDefinition.inferredKey(
                    siteName: attempt.ticketSite,
                    urlString: attempt.purchaseURL
                )
                let sameGuide = importedGuide == nil || importedGuide == storedGuide
                let sameURL = importedURL.isEmpty
                    || importedURL == normalizedImportValue(attempt.purchaseURL)
                return sameGuide && sameURL
            }
        }
    }

    private func normalizedImportValue(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }

    private func applySelectedTicketImportCandidates(
        _ selectedCandidates: [PendingTicketOCRImport]
    ) {
        let candidates = selectedCandidates.filter { !$0.isExistingDuplicate }
        guard let primary = candidates.first else {
            ticketOCRStatus = "新しく登録する候補が選ばれていません。"
            return
        }

        batchImportedScheduleDrafts.removeAll()
        additionalApplications.removeAll { $0.isImported }
        var appliedFields = applyTicketOCRImport(
            primary,
            to: &draft,
            includesPlanInformation: selectedExistingPlan == nil,
            overwritesExisting: true
        )

        for candidate in candidates.dropFirst() {
            if isDifferentSchedule(candidate, from: primary), selectedExistingPlan == nil {
                var importedDraft = draft
                _ = applyTicketOCRImport(
                    candidate,
                    to: &importedDraft,
                    includesPlanInformation: true,
                    overwritesExisting: true
                )
                batchImportedScheduleDrafts.append(importedDraft)
            } else {
                var applicationDraft = TicketPlanDraft(entryMode: .ticketSchedule)
                applicationDraft.applyFlowDefaults(draft.flowKey)
                _ = applyTicketOCRImport(
                    candidate,
                    to: &applicationDraft,
                    includesPlanInformation: false,
                    overwritesExisting: true
                )
                additionalApplications.append(
                    AdditionalTicketApplicationDraft(
                        draft: applicationDraft,
                        isExpanded: false,
                        isImported: true
                    )
                )
            }
        }

        if candidates.count > 1 {
            appliedFields.append("\(candidates.count)件の登録候補")
        }
        let uniqueFields = appliedFields.reduce(into: [String]()) { values, field in
            if !values.contains(field) { values.append(field) }
        }
        ticketOCRStatus = "\(uniqueFields.joined(separator: "・"))へ仮入力しました。保存前に確認してください。"
    }

    private func isDifferentSchedule(
        _ candidate: PendingTicketOCRImport,
        from primary: PendingTicketOCRImport
    ) -> Bool {
        guard let candidateDate = candidate.eventDateRange?.startsAt else { return false }
        guard let primaryDate = primary.eventDateRange?.startsAt else { return true }
        return !Calendar.current.isDate(candidateDate, equalTo: primaryDate, toGranularity: .minute)
            || normalizedImportValue(candidate.venue ?? "") != normalizedImportValue(primary.venue ?? "")
    }

    @discardableResult
    private func applyTicketOCRImport(
        _ pending: PendingTicketOCRImport,
        to target: inout TicketPlanDraft,
        includesPlanInformation: Bool,
        overwritesExisting: Bool
    ) -> [String] {
        let result = pending.result
        var appliedFields: [String] = []

        if let guideKey = result.ticketGuideKey,
           overwritesExisting || (target.trimmedTicketSite.isEmpty && target.trimmedPurchaseURL.isEmpty) {
            target.applyTicketGuide(guideKey)
            appliedFields.append("購入先")
        }
        if let purchaseURL = result.purchaseURL,
           overwritesExisting || target.trimmedPurchaseURL.isEmpty {
            target.purchaseURL = purchaseURL
            appliedFields.append("購入URL")
        }

        if target.showsSaleStart,
           overwritesExisting || !target.hasSaleStart,
           let date = result.saleStartAt {
            target.hasSaleStart = true
            target.saleStartAt = date
            appliedFields.append(target.saleStartLabel)
        }
        if target.showsApplyDeadline,
           overwritesExisting || !target.hasApplyDeadline,
           let date = result.applyDeadlineAt {
            target.hasApplyDeadline = true
            target.applyDeadlineAt = date
            appliedFields.append("抽選申込締切")
        }
        if target.showsResultAnnounce,
           overwritesExisting || !target.hasResultAnnounce,
           let date = result.resultAnnounceAt {
            target.hasResultAnnounce = true
            target.resultAnnounceAt = date
            appliedFields.append("当落発表")
        }
        if target.showsPaymentDeadline,
           overwritesExisting || !target.hasPaymentDeadline,
           let date = result.paymentDeadlineAt {
            target.hasPaymentDeadline = true
            target.paymentDeadlineAt = date
            appliedFields.append("支払締切")
        }
        if target.showsIssueStart,
           overwritesExisting || !target.hasIssueStart,
           let date = result.issueStartAt {
            target.hasIssueStart = true
            target.issueStartAt = date
            appliedFields.append("チケット受取開始")
        }

        if target.showsTicketDetails {
            if let priceText = result.priceText, overwritesExisting || target.priceText.isEmpty {
                target.priceText = priceText
                appliedFields.append("チケット代")
            }
            if let feeText = result.feeText, overwritesExisting || target.feeText.isEmpty {
                target.feeText = feeText
                appliedFields.append("手数料")
            }
            if let seatText = result.seatText, overwritesExisting || target.seatText.isEmpty {
                target.seatText = seatText
                appliedFields.append("座席")
            }
            if let quantity = result.quantity, overwritesExisting || target.quantity == 1 {
                target.quantity = quantity
                appliedFields.append("枚数")
            }
        }

        if includesPlanInformation {
            if (overwritesExisting || target.trimmedTitle.isEmpty),
               let suggestedTitle = pending.suggestedTitle,
               !suggestedTitle.isEmpty {
                target.title = suggestedTitle
                appliedFields.append("タイトル")
            }
            if (overwritesExisting || target.trimmedVenueName.isEmpty),
               let venue = pending.venue {
                target.venueName = venue
                appliedFields.append("会場")
            }
            if (overwritesExisting || !target.hasConfirmedSchedule),
               let dateRange = pending.eventDateRange {
                target.hasConfirmedSchedule = true
                target.startsAt = dateRange.startsAt
                target.endsAt = dateRange.endsAt
                appliedFields.append("日時")
            }
        }
        return appliedFields
    }

    private func planSelectionDescription(_ plan: Plan) -> String {
        let date = FavorecoDateText.compactDateTime(plan.startsAt)
        let title = plan.title.isEmpty ? (plan.event?.title ?? "予定") : plan.title
        guard !plan.venueNameSnapshot.isEmpty else { return "\(title) / \(date)" }
        return "\(title) / \(date) / \(plan.venueNameSnapshot)"
    }

    private var selectedPlanSelectionText: String {
        guard let selectedExistingPlan else { return "新しい予定を作る" }
        return planSelectionDescription(selectedExistingPlan)
    }

    private func applyPendingEventSelection() {
        guard let eventID = pendingSelectedEventID else { return }
        pendingSelectedEventID = nil
        selectedEventID = eventID
    }

    private var ticketFlowGuide: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(registrationPalette.globalTint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("この登録で入力する項目")
                    .font(FavorecoTypography.jpSans(10.5, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(registrationPalette.globalTint)

                Text(TicketFlowDefinition.definition(for: draft.flowKey).description)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(registrationPalette.globalTint.opacity(0.08))
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private var applicationDetailsSummary: String {
        var values: [String] = []

        if draft.showsEntryRoute, !draft.entryRouteKey.isEmpty {
            values.append(TicketEntryRouteDefinition.name(for: draft.entryRouteKey))
        }

        if draft.showsTicketGuide {
            let siteName = draft.trimmedTicketSite
            if !siteName.isEmpty {
                values.append(siteName)
            } else if let guide = TicketGuideDefinition.guide(for: draft.ticketGuideKey) {
                values.append(guide.name)
            }
        }

        return values.isEmpty ? "任意・未入力でも登録できます" : values.joined(separator: "・")
    }

    @ViewBuilder
    private var applicationDetailsSection: some View {
        DisclosureGroup(isExpanded: $isApplicationDetailsExpanded) {
            Text("複数申込の見分けや検索に使えます。未入力でも登録できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if draft.showsEntryRoute {
                ExplicitFormControlRow(title: draft.entryRouteLabel) {
                    Picker(draft.entryRouteLabel, selection: $draft.entryRouteKey) {
                        Text("未設定").tag("")
                        ForEach(draft.entryRouteOptions) { route in
                            Text(route.name).tag(route.key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if draft.showsAccountFields {
                ExplicitFormControlRow(title: "申込アカウント", isOptional: true) {
                    Picker("申込アカウント", selection: $draft.accountID) {
                        Text("未設定").tag(Optional<UUID>.none)
                        ForEach(activeAccounts) { account in
                            Text(accountLabel(account)).tag(Optional(account.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onChange(of: draft.accountID) { previousValue, newValue in
                    draft.applyAccount(
                        activeAccounts.first { $0.id == newValue },
                        replacing: accounts.first { $0.id == previousValue }
                    )
                }

                ExplicitFormTextField(
                    title: "名義",
                    prompt: "任意",
                    text: $draft.holderName,
                    labelStyle: .horizontal
                )
            }

            if draft.showsTicketGuide {
                ExplicitFormControlRow(title: "購入先") {
                    Picker("購入先", selection: $draft.ticketGuideKey) {
                        ForEach(TicketGuideDefinition.all) { guide in
                            Text(guide.name).tag(guide.key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onChange(of: draft.ticketGuideKey) { _, newValue in
                    draft.applyTicketGuide(newValue)
                }
                .disabled(draft.accountID != nil)

                if draft.ticketGuideKey == TicketGuideDefinition.customKey {
                    ExplicitFormTextField(
                        title: "購入先（任意）",
                        prompt: "FC・公式サイトなど",
                        text: $draft.ticketSite,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    ExplicitFormTextField(
                        title: "購入URL（任意）",
                        prompt: "申込・購入URL",
                        text: $draft.purchaseURL,
                        axis: .vertical,
                        minimumLines: 1,
                        maximumLines: 2,
                        labelStyle: .horizontal
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                } else {
                    linkedTheaterReferenceRow(
                        title: "申込・購入URL",
                        value: draft.purchaseURL
                    )
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("申込の詳細")
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                Text(applicationDetailsSummary)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityHint("申込枠、購入先、申込アカウント、名義を入力します")
    }

    private func compactPlanSummaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .frame(width: 64, alignment: .leading)

            Divider()
                .frame(height: 18)

            Text(value)
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .foregroundStyle(value == "未設定" ? Color.secondary : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private func linkedTheaterReferenceRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(
                    FavorecoTypography.jpSans(
                        ExplicitFormMetrics.labelFontSize,
                        weight: .semibold,
                        relativeTo: .caption
                    )
                )
                .foregroundStyle(Color.secondary.opacity(0.92))
                .lineLimit(1)
                .frame(height: 21, alignment: .bottom)

            Text(value.isEmpty ? "未設定" : value)
                .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
        }
        .frame(minHeight: ExplicitFormMetrics.rowMinimumHeight, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)、\(value.isEmpty ? "未設定" : value)")
    }

    private func displayedPlanTitle(_ plan: Plan) -> String {
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private func targetSelectionTitle(_ mode: TargetSelectionMode) -> String {
        if entryMode == .plan,
           ["theme_park", "nature_living", "outing_facility"].contains(selectedCategory?.templateKey ?? "") {
            switch mode {
            case .new: return "新しく登録"
            case .existingEvent: return "登録済みから選ぶ"
            case .interested: return mode.title
            }
        }
        guard usesTicketRegistration || isUnifiedRegistration else { return mode.title }
        switch mode {
        case .new: return "新規イベント"
        case .existingEvent: return "登録済みイベント"
        case .interested: return mode.title
        }
    }

    private func save() {
        normalizeSimpleDestinationVenueName()
        draft.planPeople = planPendingPeople.map(PlanMemoryPerson.init)
        if allowsTargetSelection,
           targetSelectionMode == .existingEvent,
           selectedRegisteredEvent == nil {
            validationError = usesTicketRegistration
                ? "チケット情報を追加するイベントを選んでください。"
                : "予定を追加する施設・スポットを選んでください。"
            return
        }
        if allowsTargetSelection,
           targetSelectionMode == .interested,
           selectedInterestedEvent == nil {
            validationError = "予定を追加する作品・対象を選んでください。"
            return
        }
        if let validationMessage = draft.validationMessage(usesOpeningTime: usesOpeningTime) {
            validationError = validationMessage
            return
        }
        if isUnifiedRegistration && unifiedPurpose == .application {
            for (index, application) in additionalApplications.enumerated() {
                if let validationMessage = application.draft.validationMessage(
                    usesOpeningTime: false
                ) {
                    validationError = "申込\(index + 2)：\(validationMessage)"
                    return
                }
            }
        }
        for (index, importedDraft) in batchImportedScheduleDrafts.enumerated() {
            if let validationMessage = importedDraft.validationMessage(usesOpeningTime: usesOpeningTime) {
                validationError = "一括登録\(index + 2)：\(validationMessage)"
                return
            }
        }

        let now = Date()
        if isInterestedOnly {
            saveInterestedEvent(now: now)
        } else if let editingPlan {
            update(plan: editingPlan, now: now)
        } else if usesTicketRegistration, let selectedExistingPlan {
            createTicketAttempt(on: selectedExistingPlan, now: now)
        } else if !batchImportedScheduleDrafts.isEmpty {
            createImportedScheduleBatch(now: now)
        } else {
            create(now: now)
        }
    }

    private func saveInterestedEvent(now: Date) {
        let event: ExperienceEvent
        if let resolvedTargetEvent {
            event = resolvedTargetEvent
        } else {
            event = createTargetEvent(now: now, initialStateKey: "interested")
        }
        if event.stateKey.isEmpty {
            event.stateKey = "interested"
        }
        applyEventMetadata(to: event, at: now)
        applyEventCreditChanges(to: event)
        event.eyecatchData = eventEyecatchData
        event.updatedAt = now

        do {
            try modelContext.save()
            onSave?()
            dismiss()
        } catch {
            modelContext.rollback()
            validationError = "公演を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to save interested event: \(error)")
        }
    }

    private func create(now: Date) {
        let event = resolvedTargetEvent ?? createTargetEvent(now: now)
        applyEventCreditChanges(to: event)
        event.eyecatchData = eventEyecatchData
        let synchronizedTitle = synchronizedPlanTitle(event: event)
        let plan = Plan(
            title: synchronizedTitle,
            subtitle: draft.trimmedSubtitle,
            planKindKey: draft.hasConfirmedSchedule ? "performance" : Plan.undatedTicketPlanKindKey,
            stateKey: "planned",
            startsAt: draft.startsAt,
            endsAt: draft.hasEndTime ? draft.endsAt : draft.startsAt,
            opensAt: usesOpeningTime && draft.hasOpeningTime ? draft.opensAt : Date.distantPast,
            venueNameSnapshot: draft.hasConfirmedSchedule ? draft.trimmedVenueName : "",
            officialURL: draft.trimmedOfficialURL,
            sourceURL: draft.trimmedOfficialURL,
            memo: draft.trimmedMemo,
            unitFieldsRaw: draft.planUnitFieldsRaw,
            createdAt: now,
            updatedAt: now,
            category: event.category ?? selectedCategory,
            event: event,
            placeMaster: draft.hasConfirmedSchedule
                ? resolvePlaceMaster(
                    for: draft.placeSnapshot,
                    publicSelection: draft.publicPlaceSelection,
                    from: placeMasters,
                    in: modelContext
                )
                : nil
        )
        modelContext.insert(plan)
        event.stateKey = eventStateKeyAfterPlanSave
        event.updatedAt = now

        var attemptsForScheduling: [TicketAttempt] = []
        if draft.createsTicketAttempt {
            let attempts = makeTicketAttempts(for: plan, now: now)
            if let primaryAttempt = attempts.first {
                attachUngroupedAttempts(on: plan, to: primaryAttempt, now: now)
            }
            for attempt in attempts {
                attempt.notificationSettingsRaw = notificationSettingsRaw(for: attempt, plan: plan)
                modelContext.insert(attempt)
            }
            attemptsForScheduling = attempts
        }

        do {
            try modelContext.save()
            syncNotifications(
                for: plan,
                attempts: attemptsForScheduling,
                includesPlanReminder: plan.hasConfirmedSchedule
            )
            onSave?()
            if usesPlanRegistration,
               event.category?.templateKey == "theater",
               !draft.createsTicketAttempt {
                savedTheaterPlan = plan
                isShowingAfterPlanSaveActions = true
            } else {
                finishTicketSaveIfNeeded(plan, attempt: attemptsForScheduling.first)
            }
        } catch {
            modelContext.rollback()
            validationError = "予定を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to save ticket plan: \(error)")
        }
    }

    private func createImportedScheduleBatch(now: Date) {
        let event = resolvedTargetEvent ?? createTargetEvent(now: now)
        applyEventCreditChanges(to: event)
        let importedDrafts = [draft] + batchImportedScheduleDrafts
        let sharedGroupID = UUID().uuidString
        let sharedGroupName = TicketApplicationCollectionNaming.tourName(
            eventTitle: event.title.isEmpty ? draft.trimmedTitle : event.title
        )
        var createdPlans: [(plan: Plan, attempts: [TicketAttempt])] = []

        for (index, sourceDraft) in importedDrafts.enumerated() {
            let plan = makeImportedPlan(
                from: sourceDraft,
                event: event,
                now: now
            )
            modelContext.insert(plan)

            var attempts: [TicketAttempt] = [makeTicketAttempt(
                for: plan,
                now: now,
                sourceDraft: sourceDraft,
                applicationGroupIDRaw: sharedGroupID,
                applicationGroupName: sharedGroupName
            )]
            if index == 0 {
                attempts += additionalApplications.map { application in
                    makeTicketAttempt(
                        for: plan,
                        now: now,
                        sourceDraft: application.draft,
                        applicationGroupIDRaw: sharedGroupID,
                        applicationGroupName: sharedGroupName
                    )
                }
            }
            for attempt in attempts {
                attempt.notificationSettingsRaw = notificationSettingsRaw(for: attempt, plan: plan)
                modelContext.insert(attempt)
            }
            createdPlans.append((plan, attempts))
        }

        event.stateKey = eventStateKeyAfterPlanSave
        event.updatedAt = now

        do {
            try modelContext.save()
            for created in createdPlans {
                syncNotifications(
                    for: created.plan,
                    attempts: created.attempts,
                    includesPlanReminder: created.plan.hasConfirmedSchedule
                )
            }
            onSave?()
            dismiss()
        } catch {
            modelContext.rollback()
            validationError = "一括登録を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to save imported ticket schedules: \(error)")
        }
    }

    private func makeImportedPlan(
        from sourceDraft: TicketPlanDraft,
        event: ExperienceEvent,
        now: Date
    ) -> Plan {
        let eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = eventTitle.isEmpty ? sourceDraft.trimmedTitle : eventTitle
        return Plan(
            title: title,
            subtitle: sourceDraft.trimmedSubtitle,
            planKindKey: sourceDraft.hasConfirmedSchedule
                ? "performance"
                : Plan.undatedTicketPlanKindKey,
            stateKey: "planned",
            startsAt: sourceDraft.startsAt,
            endsAt: sourceDraft.endsAt,
            opensAt: usesOpeningTime && sourceDraft.hasOpeningTime
                ? sourceDraft.opensAt
                : Date.distantPast,
            venueNameSnapshot: sourceDraft.hasConfirmedSchedule
                ? sourceDraft.trimmedVenueName
                : "",
            officialURL: sourceDraft.trimmedOfficialURL,
            sourceURL: sourceDraft.trimmedOfficialURL,
            memo: sourceDraft.trimmedMemo,
            unitFieldsRaw: sourceDraft.planUnitFieldsRaw,
            createdAt: now,
            updatedAt: now,
            category: event.category ?? selectedCategory,
            event: event,
            placeMaster: sourceDraft.hasConfirmedSchedule
                ? resolvePlaceMaster(
                    for: sourceDraft.placeSnapshot,
                    publicSelection: sourceDraft.publicPlaceSelection,
                    from: placeMasters,
                    in: modelContext
                )
                : nil
        )
    }

    private func createTicketAttempt(on plan: Plan, now: Date) {
        let attempts = makeTicketAttempts(for: plan, now: now)
        guard let primaryAttempt = attempts.first else { return }
        attachUngroupedAttempts(on: plan, to: primaryAttempt, now: now)
        for attempt in attempts {
            attempt.notificationSettingsRaw = notificationSettingsRaw(for: attempt, plan: plan)
            modelContext.insert(attempt)
        }

        do {
            try modelContext.save()
            syncNotifications(for: plan, attempts: attempts, includesPlanReminder: false)
            onSave?()
            finishTicketSaveIfNeeded(plan, attempt: primaryAttempt)
        } catch {
            modelContext.rollback()
            validationError = "チケットスケジュールを保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to add ticket attempt: \(error)")
        }
    }

    private func makeTicketAttempt(
        for plan: Plan,
        now: Date,
        sourceDraft: TicketPlanDraft? = nil,
        applicationGroupIDRaw sharedGroupID: String? = nil,
        applicationGroupName sharedGroupName: String? = nil
    ) -> TicketAttempt {
        let sourceDraft = sourceDraft ?? draft
        let applicationGroupName = sharedGroupName
            ?? sourceDraft.resolvedApplicationGroupName(for: plan)
        let applicationGroupIDRaw = sharedGroupID
            ?? sourceDraft.resolvedApplicationGroupIDRaw(for: applicationGroupName)
        return TicketAttempt(
            statusKey: sourceDraft.statusKey,
            entryRouteKey: sourceDraft.entryRouteKey,
            ticketSite: sourceDraft.trimmedTicketSite,
            holderName: sourceDraft.trimmedHolderName,
            saleStartAt: sourceDraft.hasSaleStart ? sourceDraft.saleStartAt : Date.distantPast,
            applyDeadlineAt: sourceDraft.hasApplyDeadline ? sourceDraft.applyDeadlineAt : Date.distantPast,
            resultAnnounceAt: sourceDraft.hasResultAnnounce ? sourceDraft.resultAnnounceAt : Date.distantPast,
            paymentDeadlineAt: sourceDraft.hasPaymentDeadline ? sourceDraft.paymentDeadlineAt : Date.distantPast,
            issueStartAt: sourceDraft.hasIssueStart ? sourceDraft.issueStartAt : Date.distantPast,
            price: decimal(from: sourceDraft.priceText),
            fee: decimal(from: sourceDraft.feeText),
            quantity: sourceDraft.quantity,
            purchaseURL: sourceDraft.trimmedPurchaseURL,
            seatText: sourceDraft.trimmedSeatText,
            applicationGroupIDRaw: applicationGroupIDRaw,
            applicationGroupName: applicationGroupName,
            unitFieldsRaw: sourceDraft.ticketUnitFieldsRaw,
            memo: sourceDraft.trimmedMemo,
            createdAt: now,
            updatedAt: now,
            plan: plan,
            account: selectedAccount(for: sourceDraft)
        )
    }

    private func makeTicketAttempts(for plan: Plan, now: Date) -> [TicketAttempt] {
        let primary = makeTicketAttempt(for: plan, now: now)
        guard isUnifiedRegistration,
              unifiedPurpose == .application,
              !additionalApplications.isEmpty else {
            return [primary]
        }

        return [primary] + additionalApplications.map { application in
            makeTicketAttempt(
                for: plan,
                now: now,
                sourceDraft: application.draft,
                applicationGroupIDRaw: primary.applicationGroupIDRaw,
                applicationGroupName: primary.applicationGroupName
            )
        }
    }

    private func attachUngroupedAttempts(
        on plan: Plan,
        to newAttempt: TicketAttempt,
        now: Date
    ) {
        let groupID = newAttempt.applicationGroupIDRaw
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupID.isEmpty else { return }
        for existingAttempt in plan.ticketAttempts ?? [] where
            !existingAttempt.isArchived
                && existingAttempt.applicationGroupIDRaw
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
            existingAttempt.applicationGroupIDRaw = groupID
            existingAttempt.applicationGroupName = newAttempt.applicationGroupName
            existingAttempt.updatedAt = now
        }
    }

    private func createTargetEvent(
        now: Date,
        initialStateKey: String = "active"
    ) -> ExperienceEvent {
        let existingEvent: ExperienceEvent? = if ["theater", "live"].contains(selectedCategory?.templateKey ?? "") {
            ExperienceEvent.matchingProduction(
                title: draft.trimmedTitle,
                categoryID: selectedCategory?.id,
                in: events
            )
        } else {
            nil
        }
        let event = existingEvent ?? ExperienceEvent(
            title: draft.trimmedTitle,
            stateKey: initialStateKey,
            createdAt: now,
            updatedAt: now,
            category: selectedCategory
        )
        if existingEvent == nil {
            modelContext.insert(event)
        }
        event.title = draft.trimmedTitle
        applyEventMetadata(to: event, at: now)
        event.eyecatchData = eventEyecatchData
        if !draft.trimmedOfficialURL.isEmpty {
            event.officialURL = draft.trimmedOfficialURL
        }
        event.updatedAt = now
        return event
    }

    private func applyEventMetadata(to event: ExperienceEvent, at now: Date) {
        event.title = draft.trimmedTitle
        event.seriesName = draft.trimmedSeriesName
        event.subTypeKey = draft.performanceTypeKey
        event.organizerNameSnapshot = draft.trimmedOrganizerName
        if !draft.trimmedOfficialURL.isEmpty || event.officialURL.isEmpty {
            event.officialURL = draft.trimmedOfficialURL
        }
        var fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        fields.eventPerformanceTypeCustomName = draft.performanceTypeCustomName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        fields.socialLinks = draft.normalizedSocialLinks
        fields.eventCreditsText = draft.trimmedEventCreditsText
        fields.eventTicketURL = draft.trimmedEventTicketURL
        fields.heroBackgroundPresetKey = eventHeroBackgroundPresetKey
        fields.heroBackgroundPath = eventHeroBackgroundPath
        event.unitFieldsRaw = fields.encodedRawValue
        event.updatedAt = now
    }

    private func applyEventCreditChanges(to event: ExperienceEvent) {
        for link in event.personLinks ?? [] where deletedEventPersonLinkIDs.contains(link.id) {
            modelContext.delete(link)
        }

        let startIndex = (event.personLinks ?? [])
            .filter { !$0.isArchived && $0.visit == nil && !deletedEventPersonLinkIDs.contains($0.id) }
            .count
        for (offset, pending) in eventPendingPeople.enumerated() {
            let person = resolvePersonMaster(for: pending, from: personMasters, in: modelContext)
            modelContext.insert(pending.makeEventPersonLink(
                person: person,
                event: event,
                visit: nil,
                sortOrder: startIndex + offset
            ))
        }
    }

    private func update(plan: Plan, now: Date) {
        if plan.event == nil {
            plan.event = createTargetEvent(now: now)
        }
        let existingAttempt = latestAttempt(for: plan)

        if let event = plan.event {
            applyEventMetadata(to: event, at: now)
            applyEventCreditChanges(to: event)
        }
        plan.title = synchronizedPlanTitle(event: plan.event)
        plan.subtitle = draft.trimmedSubtitle
        plan.planKindKey = draft.hasConfirmedSchedule ? "performance" : Plan.undatedTicketPlanKindKey
        plan.startsAt = draft.startsAt
        plan.endsAt = draft.hasEndTime ? draft.endsAt : draft.startsAt
        plan.opensAt = usesOpeningTime && draft.hasOpeningTime ? draft.opensAt : Date.distantPast
        plan.venueNameSnapshot = draft.hasConfirmedSchedule ? draft.trimmedVenueName : ""
        plan.placeMaster = draft.hasConfirmedSchedule
            ? resolvePlaceMaster(
                for: draft.placeSnapshot,
                publicSelection: draft.publicPlaceSelection,
                from: placeMasters,
                in: modelContext
            )
            : nil
        plan.officialURL = draft.trimmedOfficialURL
        plan.sourceURL = draft.trimmedOfficialURL
        plan.memo = draft.trimmedMemo
        plan.unitFieldsRaw = draft.planUnitFieldsRaw
        applyPlanPhotoChanges(to: plan)
        plan.updatedAt = now
        plan.category = plan.event?.category ?? selectedCategory
        plan.event?.stateKey = eventStateKeyAfterPlanSave
        plan.event?.eyecatchData = eventEyecatchData
        plan.event?.updatedAt = now

        let attemptForScheduling: TicketAttempt?
        if editsPlanOnly {
            attemptForScheduling = nil
        } else if draft.createsTicketAttempt {
            let attempt = existingAttempt ?? TicketAttempt(createdAt: now, plan: plan)
            applyDraft(to: attempt, plan: plan, now: now)
            if existingAttempt == nil {
                modelContext.insert(attempt)
            }
            attempt.notificationSettingsRaw = notificationSettingsRaw(for: attempt, plan: plan)
            attemptForScheduling = attempt
        } else {
            existingAttempt?.isArchived = true
            existingAttempt?.updatedAt = now
            existingAttempt?.notificationSettingsRaw = ""
            attemptForScheduling = nil
        }

        do {
            try modelContext.save()
            if !editsPlanOnly, let existingAttempt, !draft.createsTicketAttempt {
                TicketNotificationScheduler.cancel(plan: plan, attempt: existingAttempt)
            }
            syncNotifications(
                for: plan,
                attempt: attemptForScheduling,
                includesPlanReminder: plan.hasConfirmedSchedule
            )
            Task {
                if purchaseManager.currentPlan.includesSync,
                   automaticallyUpdatesExternalCalendar,
                   plan.hasConfirmedSchedule,
                   (ExternalCalendarLinkStore.hasLink(planID: plan.id) || !plan.externalCalendarEventIdentifier.isEmpty) {
                    _ = try? await ExternalCalendarSyncService.update(plan: plan)
                    try? modelContext.save()
                }
            }
            finishTicketSaveIfNeeded(plan, attempt: attemptForScheduling)
        } catch {
            modelContext.rollback()
            validationError = "予定を更新できませんでした。もう一度お試しください。"
            assertionFailure("Failed to update ticket plan: \(error)")
        }
    }

    private var activePlanPhotos: [PhotoBlob] {
        (editingPlan?.photos ?? [])
            .filter { $0.hasStoredData && !deletedPlanPhotoIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func applyPlanPhotoChanges(to plan: Plan) {
        for photo in plan.photos ?? [] where deletedPlanPhotoIDs.contains(photo.id) {
            modelContext.delete(photo)
        }
        for photo in activePlanPhotos {
            guard let metadata = existingPlanPhotoMetadata[photo.id] else { continue }
            photo.purpose = metadata.purpose.rawValue
            photo.caption = metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            photo.ocrText = metadata.purpose.isGalleryPhoto
                ? ""
                : metadata.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
            photo.amount = metadata.purpose.supportsAmount ? metadata.amount : Decimal(0)
        }
        for pendingPhoto in planPendingPhotos {
            modelContext.insert(pendingPhoto.makePhotoBlob(plan: plan))
        }
    }

    private func synchronizedPlanTitle(event: ExperienceEvent?) -> String {
        let eventTitle = event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return eventTitle.isEmpty ? draft.trimmedTitle : eventTitle
    }

    private func applyRecurringEventCatalogSelection(
        _ entry: PublicRecurringEventCatalogEntry,
        edition: PublicRecurringEventEdition?
    ) {
        if let category = visibleCategories.first(where: { $0.templateKey == entry.templateKey }) {
            draft.categoryID = category.id
        }
        targetSelectionMode = .new
        draft.title = entry.officialName
        draft.officialURL = edition?.officialURL.isEmpty == false
            ? edition?.officialURL ?? entry.officialURL
            : entry.officialURL
        selectedRecurringEventEdition = edition
    }

    private func applyRecurringEditionDate(_ edition: PublicRecurringEventEdition) {
        guard let day = edition.startDate else { return }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: draft.startsAt)
        draft.startsAt = calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
        draft.endsAt = calendar.date(byAdding: .hour, value: 2, to: draft.startsAt) ?? draft.startsAt
        draft.hasConfirmedSchedule = true
    }

    private var eventStateKeyAfterPlanSave: String {
        draft.hasConfirmedSchedule || usesPlanRegistration ? "active" : "interested"
    }

    private func finishTicketSaveIfNeeded(_ plan: Plan, attempt: TicketAttempt?) {
        if usesTicketRegistration,
           let event = plan.event,
           event.category?.templateKey == "theater" {
            savedTicketEvent = event
            savedTicketSchedulePlan = plan
            savedTicketAttempt = attempt
            isShowingAfterTicketSaveActions = true
        } else {
            dismiss()
        }
    }

    private func notificationSettingsRaw(for attempt: TicketAttempt, plan: Plan) -> String {
        guard !TicketStatusDefinition.isTerminal(attempt.statusKey) else { return "" }
        return TicketNotificationScheduler.scheduledAttemptIdentifiers(
            plan: plan,
            attempt: attempt
        ).joined(separator: ",")
    }

    private func syncNotifications(
        for plan: Plan,
        attempt: TicketAttempt?,
        includesPlanReminder: Bool
    ) {
        Task {
            if includesPlanReminder {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: nil)
            }
            guard let attempt else { return }
            if TicketStatusDefinition.isTerminal(attempt.statusKey) {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            } else {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
            }
        }
    }

    private func syncNotifications(
        for plan: Plan,
        attempts: [TicketAttempt],
        includesPlanReminder: Bool
    ) {
        Task {
            if includesPlanReminder {
                await TicketNotificationScheduler.reschedule(plan: plan, attempt: nil)
            }
            for attempt in attempts {
                if TicketStatusDefinition.isTerminal(attempt.statusKey) {
                    TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
                } else {
                    await TicketNotificationScheduler.reschedule(plan: plan, attempt: attempt)
                }
            }
        }
    }

    private func latestAttempt(for plan: Plan) -> TicketAttempt? {
        plan.ticketAttempts?
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private func applyDraft(to attempt: TicketAttempt, plan: Plan, now: Date) {
        attempt.statusKey = draft.resolvedStatusKey
        attempt.entryRouteKey = draft.entryRouteKey
        attempt.ticketSite = draft.trimmedTicketSite
        attempt.holderName = draft.trimmedHolderName
        attempt.applicationGroupIDRaw = draft.resolvedApplicationGroupIDRaw(
            preserving: attempt.applicationGroupIDRaw
        )
        attempt.applicationGroupName = draft.trimmedApplicationGroupName
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

    private func continueApplicationCollectionOnAnotherSchedule() {
        guard let event = savedTicketEvent,
              let attempt = savedTicketAttempt else {
            validationError = "保存した申込情報を読み込めませんでした。"
            return
        }

        let now = Date()
        if attempt.applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attempt.applicationGroupIDRaw = UUID().uuidString
        }
        let groupID = attempt.applicationGroupIDRaw
        let relatedAttempts = plans
            .flatMap { $0.ticketAttempts ?? [] }
            .filter { $0.applicationGroupIDRaw == groupID }
        if TicketApplicationCollectionNaming.shouldReplaceWithTourName(
            attempt.applicationGroupName,
            attempts: relatedAttempts.isEmpty ? [attempt] : relatedAttempts
        ) {
            let groupName = TicketApplicationCollectionNaming.tourName(eventTitle: event.title)
            for relatedAttempt in relatedAttempts {
                relatedAttempt.applicationGroupName = groupName
                relatedAttempt.updatedAt = now
            }
            attempt.applicationGroupName = groupName
        }
        attempt.updatedAt = now

        do {
            try modelContext.save()
            savedTicketAttempt = attempt
            eventForAdditionalTicketSchedule = event
        } catch {
            modelContext.rollback()
            validationError = "申込情報を準備できませんでした。もう一度お試しください。"
        }
    }

    private func decimal(from text: String) -> Decimal {
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: digits) ?? Decimal(0)
    }
}

private struct EventBackgroundSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categoryKey: String
    let eyecatchData: Data?
    @Binding var selection: String

    private var presets: [HeroBackgroundPreset] {
        HeroBackgroundPreset.presets(for: categoryKey)
    }

    private var resolvedSelection: String {
        if selection == HeroBackgroundPreset.eventEyecatchKey { return selection }
        return HeroBackgroundPreset.resolved(categoryKey: categoryKey, storedKey: selection)?.key ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 14
                ) {
                    ForEach(presets) { preset in
                        backgroundButton(
                            key: preset.key,
                            title: preset.title,
                            image: bundledImage(named: preset.resourceName)
                        )
                    }
                    backgroundButton(
                        key: HeroBackgroundPreset.eventEyecatchKey,
                        title: "アイキャッチから",
                        image: eyecatchData.flatMap(UIImage.init(data:)),
                        isEnabled: eyecatchData != nil
                    )
                }
                .padding(20)
            }
            .background(TheaterLifecycleFlatStyle.canvasBackground.ignoresSafeArea())
            .navigationTitle("背景を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .dynamicTypeSize(.xSmall ... .large)
    }

    private func backgroundButton(
        key: String,
        title: String,
        image: UIImage?,
        isEnabled: Bool = true
    ) -> some View {
        let isSelected = resolvedSelection == key
        return Button {
            selection = key
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { geometry in
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color(.secondarySystemFill)
                                .overlay {
                                    Text("No Image")
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.22),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor, in: Circle())
                            .padding(6)
                    }
                }

                Text(title)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                TheaterLifecycleFlatStyle.fieldBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func bundledImage(named resourceName: String) -> UIImage? {
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct AdditionalTicketApplicationDraft: Identifiable {
    let id = UUID()
    var draft: TicketPlanDraft
    var isExpanded: Bool
    var isImported = false

    var title: String {
        draft.flowKey == "lotteryPlanned" ? "抽選申込" : "先着・発売"
    }

    var summary: String {
        let site = draft.trimmedTicketSite
        let route = TicketEntryRouteDefinition.name(for: draft.entryRouteKey)
        let values = [route, site].filter { !$0.isEmpty }
        return values.isEmpty ? "申込内容を入力" : values.joined(separator: "・")
    }
}

private struct PlanVenueSearchField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let tint: Color
    let searchAction: () -> Void

    private var hasQuery: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ExplicitFormFieldTitle(
                title: title.replacingOccurrences(of: "（任意）", with: ""),
                isOptional: title.contains("任意"),
                isRequired: false
            )

            HStack(spacing: 6) {
                TextField(
                    title,
                    text: $text,
                    prompt: Text(prompt)
                        .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                        .foregroundStyle(Color.secondary.opacity(0.66)),
                    axis: .vertical
                )
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .lineLimit(1...2)
                .frame(minHeight: 29, alignment: .leading)

                Button(action: searchAction) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasQuery ? tint : Color.secondary.opacity(0.38))
                        .frame(width: 34, height: 34)
                        .background(
                            hasQuery ? tint.opacity(0.12) : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasQuery)
                .accessibilityLabel("Apple Mapsで\(title)を検索")
            }
        }
        .padding(.top, ExplicitFormMetrics.rowTopPadding)
        .padding(.bottom, ExplicitFormMetrics.rowBottomPadding)
        .frame(minHeight: ExplicitFormMetrics.rowMinimumHeight, alignment: .topLeading)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

#Preview {
    AddTicketPlanView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
