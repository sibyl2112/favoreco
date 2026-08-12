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

struct AddTicketPlanView: View {
    enum EntryMode {
        case plan
        case ticketSchedule
        case unified
    }

    private enum UnifiedRegistrationPurpose: String, CaseIterable, Identifiable {
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
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \TicketAccount.serviceName) private var accounts: [TicketAccount]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Plan.startsAt) private var plans: [Plan]
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @StateObject private var publicPlaceStore = PublicPlaceCatalogStore.shared
    @State private var draft = TicketPlanDraft()
    @State private var unifiedPurpose: UnifiedRegistrationPurpose = .interested
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
    @State private var isReadingTicketImage = false
    @State private var ticketOCRStatus = ""
    @State private var ticketImportCandidates: [PendingTicketOCRImport] = []
    @State private var isShowingTicketImportReview = false
    @State private var batchImportedScheduleDrafts: [TicketPlanDraft] = []
    @State private var isApplicationDetailsExpanded = false
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    private let editingPlan: Plan?
    private let targetEvent: ExperienceEvent?
    private let onSave: (() -> Void)?
    private let entryMode: EntryMode
    private let initialCategoryID: UUID?

    init(
        plan: Plan? = nil,
        entryMode: EntryMode = .ticketSchedule,
        initialCategoryID: UUID? = nil,
        initialPlaceMaster: PlaceMaster? = nil
    ) {
        self.editingPlan = plan
        self.targetEvent = plan?.event
        self.onSave = nil
        self.entryMode = entryMode
        self.initialCategoryID = plan?.category?.id ?? initialCategoryID
        var initialDraft = TicketPlanDraft(plan: plan, entryMode: entryMode)
        if plan == nil {
            initialDraft.categoryID = initialCategoryID
            if let initialPlaceMaster {
                initialDraft.applyDestination(placeMaster: initialPlaceMaster)
            }
        }
        _draft = State(initialValue: initialDraft)
        _targetSelectionMode = State(initialValue: entryMode == .ticketSchedule ? .existingEvent : .new)
    }

    init(inboxItem: InboxItem, category: RecordCategory, onSave: (() -> Void)? = nil) {
        self.editingPlan = nil
        self.targetEvent = nil
        self.onSave = onSave
        self.entryMode = .plan
        self.initialCategoryID = category.id
        _draft = State(initialValue: TicketPlanDraft(inboxItem: inboxItem, categoryID: category.id))
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
        _draft = State(
            initialValue: TicketPlanDraft(
                event: event,
                entryMode: entryMode,
                continuingApplication: continuingApplication
            )
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

    private var isUnifiedRegistration: Bool {
        entryMode == .unified
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
        Picker("登録内容", selection: $unifiedPurpose) {
            ForEach(UnifiedRegistrationPurpose.allCases) { purpose in
                Text(purpose.title).tag(purpose)
            }
        }
        .pickerStyle(.segmented)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isUnifiedRegistration {
                    FavorecoRegistrationSection("登録内容") {
                        VStack(alignment: .leading, spacing: 12) {
                            unifiedPurposePicker

                            Divider()

                            Text(unifiedPurposeDescription)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if entryMode == .plan, selectedCategory?.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: unifiedFormEntry)
                    }
                }

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
                                    HStack(spacing: 12) {
                                        FavorecoIcon(
                                            systemName: selectedRegisteredEvent?.category?.iconSymbol ?? "magnifyingglass",
                                            size: 18
                                        )
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(selectedRegisteredEvent?.title ?? "登録済みから検索")
                                                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.72)
                                                .allowsTightening(true)

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
                                                    .foregroundStyle(themePalette.globalTint)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.72)
                                                    .allowsTightening(true)

                                                Spacer(minLength: 0)

                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(themePalette.globalTint)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        } else if targetSelectionMode == .interested {
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
                                    HStack(spacing: 12) {
                                        FavorecoIcon(
                                            systemName: selectedInterestedEvent?.category?.iconSymbol ?? "magnifyingglass",
                                            size: 18
                                        )
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(selectedInterestedEvent?.title ?? "作品・対象を検索")
                                                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.72)
                                                .allowsTightening(true)

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
                            Text(usesTicketRegistration
                                 ? "新しいイベント、予定、チケット情報をまとめて登録します。"
                                 : isInterestedOnly
                                     ? "新しい公演を「気になる」に保存します。"
                                     : "作品・施設などの対象と予定を同時に登録します。")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)

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
                                            Text("芸術祭・舞台芸術祭・野外音楽祭")
                                                .font(FavorecoTypography.caption)
                                                .foregroundStyle(.secondary)
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
                    } header: {
                        FavorecoRegistrationSectionHeader(
                            isUnifiedRegistration ? "対象" : isSimplePlan ? destinationTargetName : "予定の対象"
                        )
                    }
                }

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
                    Section {
                        if let event = resolvedTargetEvent, !isSimplePlan {
                            linkedTheaterReferenceRow(
                                title: "ジャンル",
                                value: event.category?.name ?? "未設定"
                            )
                        } else if !isSimplePlan {
                            ExplicitFormControlRow(title: "ジャンル") {
                                Picker("ジャンル", selection: $draft.categoryID) {
                                    Text("未設定").tag(Optional<UUID>.none)
                                    ForEach(visibleCategories) { category in
                                        Text(category.name).tag(Optional(category.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                        if let event = resolvedTargetEvent, isSimplePlan {
                            linkedTheaterReferenceRow(title: "\(destinationTargetName)名", value: event.title)
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
                                title: isSimplePlan ? "\(destinationTargetName)名" : "公演・イベント名",
                                prompt: isSimplePlan ? "\(destinationTargetName)名を入力" : "公演・イベント名を入力",
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
                            Button {
                                isShowingPlaceSearch = true
                            } label: {
                                FavorecoIconLabel("地図から場所を入力", systemImage: "map")
                                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .allowsTightening(true)
                            }
                            PlaceMapPreview(
                                venueName: draft.venueName,
                                address: draft.venueAddress,
                                latitude: draft.latitude,
                                longitude: draft.longitude
                            )
                            PlaceOfficialWebsiteLink(
                                urlString: venueOfficialURLString,
                                title: "施設公式サイト"
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
                            title: "公式URL",
                            prompt: isSimplePlan ? "この予定の案内ページ（任意）" : "公演・この予定の案内ページ（任意）",
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
                            TheaterUnifiedSectionLabel(section: .performanceBasic)
                        } else {
                            FavorecoRegistrationSectionHeader("公演の基本情報")
                        }
                    }
                }

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
                            if !isSimpleDestinationPlan {
                                inheritedTheaterVenueChoices
                                ExplicitFormTextField(
                                    title: "会場（任意）",
                                    prompt: "公演情報から選択、または会場名を入力",
                                    text: venueNameBinding,
                                    axis: .vertical,
                                    minimumLines: 1,
                                    maximumLines: 2,
                                    labelStyle: .horizontal
                                )
                            }
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
                            Button {
                                isShowingPlaceSearch = true
                            } label: {
                                FavorecoIconLabel(
                                    isSimplePlan ? "地図から場所を入力" : "Apple Mapsで会場・住所を入力",
                                    systemImage: "map"
                                )
                                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .allowsTightening(true)
                            }
                            PlaceMapPreview(
                                venueName: draft.venueName,
                                address: draft.venueAddress,
                                latitude: draft.latitude,
                                longitude: draft.longitude
                            )
                            PlaceOfficialWebsiteLink(urlString: venueOfficialURLString)
                        } header: {
                            FavorecoRegistrationSectionHeader(
                                isSimpleViewingPlan
                                    ? (selectedCategory?.templateKey == "movie" ? "鑑賞場所" : "会場")
                                    : isSimpleDestinationPlan ? "場所" : "会場"
                            )
                        }
                    }

                }

                if !editsPlanOnly, isUnifiedRegistration || entryMode == .ticketSchedule {
                    Section {
                        if usesOCRImportAssist {
                            PhotosPicker(
                                selection: $selectedTicketOCRItems,
                                maxSelectionCount: 2,
                                matching: .images
                            ) {
                                HStack(spacing: 8) {
                                    FavorecoIcon(
                                        systemName: "text.viewfinder",
                                        size: 17
                                    )
                                    .foregroundStyle(themePalette.globalTint)

                                    Text(
                                        isReadingTicketImage
                                            ? "画像を読み取り中"
                                            : isUnifiedRegistration
                                                ? "画像から情報を読み取る"
                                                : "画像からチケット情報を読み取る"
                                    )
                                    .font(FavorecoTypography.jpSans(
                                        13,
                                        weight: .semibold,
                                        relativeTo: .body
                                    ))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .allowsTightening(true)

                                    Spacer(minLength: 4)

                                    if isReadingTicketImage {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isReadingTicketImage)
                            .onChange(of: selectedTicketOCRItems) { _, items in
                                guard !items.isEmpty else { return }
                                Task { await readTicketImages(from: items) }
                            }
                        } else {
                            FavorecoIconLabel(
                                "画像OCRは設定でOFFになっています",
                                systemImage: "text.viewfinder"
                            )
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        }

                        if !ticketOCRStatus.isEmpty {
                            Text(ticketOCRStatus)
                                .font(FavorecoTypography.jpSans(
                                    10.5,
                                    weight: .regular,
                                    relativeTo: .caption
                                ))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

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

                            if !isUnifiedRegistration || unifiedPurpose == .application {
                                ticketFlowGuide
                            }

                            if draft.showsEntryRoute || draft.showsAccountFields || draft.showsTicketGuide {
                                applicationDetailsSection
                            }
                        }
                    }

                    if draft.createsTicketAttempt && draft.showsAnyTicketMilestone {
                        FavorecoRegistrationSection("チケットスケジュール") {
                            if draft.showsSaleStart {
                                DateToggleRow(title: draft.saleStartLabel, isOn: $draft.hasSaleStart, date: $draft.saleStartAt)
                            }
                            if draft.showsApplyDeadline {
                                DateToggleRow(
                                    title: "抽選申込締切",
                                    isOn: $draft.hasApplyDeadline,
                                    date: $draft.applyDeadlineAt
                                )
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
                                Stepper(
                                    value: $draft.quantity,
                                    in: 1...20
                                ) {
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

                FavorecoRegistrationSection(editsPlanOnly ? "予定メモ" : "タグ・メモ") {
                    if !editsPlanOnly && draft.createsTicketAttempt {
                        TicketTagInputField(text: $draft.tagNamesText)
                    }
                    if editsPlanOnly {
                        ExplicitFormTextField(
                            title: "メモ",
                            prompt: "この予定について残すメモ（任意）",
                            text: $draft.memo,
                            axis: .vertical,
                            minimumLines: isSimplePlan ? 3 : 5,
                            maximumLines: isSimplePlan ? 3 : 5,
                            labelStyle: .horizontal,
                            reservesLineSpace: true
                        )
                    } else {
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
            .toolbar {
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
            .onAppear {
                if editingPlan == nil {
                    restoreInitialCategoryIfNeeded()
                }
                if isUnifiedRegistration {
                    applyUnifiedPurpose(unifiedPurpose)
                }
            }
            .onChange(of: unifiedPurpose) { _, purpose in
                applyUnifiedPurpose(purpose)
            }
            .onChange(of: targetSelectionMode) { _, newValue in
                selectedEventID = nil
                selectedPlanID = nil
                batchImportedScheduleDrafts.removeAll()
                additionalApplications.removeAll { $0.isImported }
                selectedRecurringEventEdition = nil
                draft.clearTarget()
                restoreInitialCategoryIfNeeded()
            }
            .onChange(of: selectedEventID) { _, _ in
                batchImportedScheduleDrafts.removeAll()
                additionalApplications.removeAll { $0.isImported }
                let event = targetSelectionMode == .existingEvent ? selectedRegisteredEvent : selectedInterestedEvent
                guard let event else { return }
                draft.applyTarget(event)
                if targetSelectionMode == .existingEvent {
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
            }
            .onChange(of: draft.title) { oldValue, newValue in
                guard isSimpleDestinationPlan else { return }
                let oldTitle = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentVenue = draft.venueName.trimmingCharacters(in: .whitespacesAndNewlines)
                if currentVenue.isEmpty || currentVenue == oldTitle {
                    draft.venueName = newValue
                    draft.clearPlaceSelection()
                    suppressesPlaceSuggestions = false
                }
            }
            .onChange(of: selectedPlanID) { _, _ in
                batchImportedScheduleDrafts.removeAll()
                additionalApplications.removeAll { $0.isImported }
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
                        draft.applyDestination(place: candidate)
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
                .tint(themePalette.globalTint)
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
            .sheet(item: $planForAdditionalTicketAttempt, onDismiss: {
                if savedTicketSchedulePlan != nil {
                    isShowingAfterTicketSaveActions = true
                }
            }) { plan in
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
        }
        .favorecoAppAppearance()
        .tint(themePalette.globalTint)
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

    private var venueOfficialURLString: String {
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
        let suggestions = suppressesPlaceSuggestions ? [] : draft.placeSuggestions(from: placeMasters)
        let publicSuggestions = suppressesPlaceSuggestions ? [] : publicCatalogSuggestions
        if !suggestions.isEmpty || !publicSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !suggestions.isEmpty {
                    Text("登録済みの場所")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(suggestions) { place in
                        Button {
                            if isSimpleDestinationPlan {
                                draft.applyDestination(placeMaster: place)
                            } else {
                                draft.apply(placeMaster: place)
                            }
                            finishPlaceSuggestionSelection()
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
                            if isSimpleDestinationPlan {
                                draft.applyDestination(publicPlace: selection)
                            } else {
                                draft.apply(publicPlace: selection)
                            }
                            finishPlaceSuggestionSelection()
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
                            draft.applyRegisteredVenue(venue)
                            finishPlaceSuggestionSelection()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: draft.trimmedVenueName == venue.trimmedName
                                      ? "checkmark.circle.fill"
                                      : "mappin.circle")
                                    .foregroundStyle(themePalette.globalTint)
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
            return "公演情報だけを保存します。日時やチケットは後から追加できます。"
        case .plan:
            return "観に行く日時と会場を登録します。"
        case .application:
            return "抽選または先着の申込から、当落・入金・受取まで管理します。"
        case .acquired:
            return "取得済みチケットの日時、金額、枚数、座席を記録します。"
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
                title: "入金締切",
                isOn: applicationDraft.hasPaymentDeadline,
                date: applicationDraft.paymentDeadlineAt
            )
        }
        if applicationDraft.wrappedValue.showsIssueStart {
            DateToggleRow(
                title: "チケット受取開始（任意）",
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

    private func applyUnifiedPurpose(_ purpose: UnifiedRegistrationPurpose) {
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
        var result = TicketOCRImportParser.parse(
            text: text,
            referenceDate: selectedExistingPlan?.startsAt ?? Date()
        )
        if !draft.showsSaleStart { result.saleStartAt = nil }
        if !draft.showsApplyDeadline { result.applyDeadlineAt = nil }
        if !draft.showsResultAnnounce { result.resultAnnounceAt = nil }
        if !draft.showsPaymentDeadline { result.paymentDeadlineAt = nil }
        if !draft.showsIssueStart { result.issueStartAt = nil }
        if !draft.showsTicketDetails {
            result.priceText = nil
            result.seatText = nil
            result.quantity = nil
        }
        let pending = PendingTicketOCRImport(
            result: result,
            suggestedTitle: canImportPlanInformation
                && analysis?.isTitleSuggestionReliable == true
                && analysis?.suggestedTitle.isEmpty == false
                ? analysis?.suggestedTitle
                : nil,
            venue: canImportPlanInformation ? analysis?.venueCandidates.first : nil,
            eventDateRange: canImportPlanInformation ? analysis?.eventDateRange : nil,
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
            appliedFields.append("入金締切")
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
                .foregroundStyle(themePalette.globalTint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("この登録で入力する項目")
                    .font(FavorecoTypography.jpSans(10.5, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(themePalette.globalTint)

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
                .fill(themePalette.globalTint.opacity(0.08))
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
                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .frame(width: 64, alignment: .leading)

            Divider()
                .frame(height: 18)

            Text(value)
                .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .body))
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
        let synchronizedTitle = synchronizedPlanTitle(event: event)
        let plan = Plan(
            title: synchronizedTitle,
            subtitle: draft.trimmedSubtitle,
            planKindKey: draft.hasConfirmedSchedule ? "performance" : Plan.undatedTicketPlanKindKey,
            stateKey: "planned",
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            opensAt: usesOpeningTime && draft.hasOpeningTime ? draft.opensAt : Date.distantPast,
            venueNameSnapshot: draft.hasConfirmedSchedule ? draft.trimmedVenueName : "",
            officialURL: draft.trimmedOfficialURL,
            sourceURL: draft.trimmedOfficialURL,
            memo: draft.trimmedMemo,
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
        let existingEvent: ExperienceEvent? = if selectedCategory?.templateKey == "theater" {
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
        if !draft.trimmedOfficialURL.isEmpty {
            event.officialURL = draft.trimmedOfficialURL
        }
        event.updatedAt = now
        return event
    }

    private func update(plan: Plan, now: Date) {
        if plan.event == nil {
            plan.event = createTargetEvent(now: now)
        }
        let existingAttempt = latestAttempt(for: plan)

        plan.title = synchronizedPlanTitle(event: plan.event)
        plan.subtitle = draft.trimmedSubtitle
        plan.planKindKey = draft.hasConfirmedSchedule ? "performance" : Plan.undatedTicketPlanKindKey
        plan.startsAt = draft.startsAt
        plan.endsAt = draft.endsAt
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
        plan.updatedAt = now
        plan.category = plan.event?.category ?? selectedCategory
        plan.event?.stateKey = eventStateKeyAfterPlanSave
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

struct DateToggleRow: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormControlRow(
                title: title
                    .replacingOccurrences(of: "（任意）", with: ""),
                isOptional: title.contains("任意")
            ) {
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .tint(themePalette.prominentAction)
                    .accessibilityLabel(title)
            }
            if isOn {
                FiveMinuteDateTimeRow(title: title, selection: $date, showsLabel: false)
            }
        }
    }
}

struct FiveMinuteDateTimeRow: View {
    let title: String
    @Binding var selection: Date
    var showsLabel = true

    var body: some View {
        ExplicitFormControlRow(title: showsLabel ? title : "日時") {
            HStack(spacing: 8) {
                DatePicker(
                    title,
                    selection: $selection,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .controlSize(.small)
                .fixedSize()
                .scaleEffect(ExplicitFormMetrics.dateControlScale)

                FiveMinuteTimeField(selection: $selection, accessibilityLabel: title)
            }
        }
    }
}

private struct TheaterScheduleDateRow: View {
    @Binding var selection: Date
    @Binding var isSet: Bool
    let onClear: () -> Void

    var body: some View {
        ExplicitFormControlRow(title: "日付", density: .compactSchedule) {
            HStack(spacing: 6) {
                if isSet {
                    DatePicker(
                        "日付",
                        selection: $selection,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .controlSize(.small)
                    .fixedSize()

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("体験日時を未定に戻す")
                } else {
                    Text("日時未定")
                        .foregroundStyle(.secondary)

                    Button("日付を設定") {
                        isSet = true
                    }
                    .buttonStyle(.borderless)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .accessibilityLabel("体験日を設定")
                }
            }
        }
    }
}

private struct TenMinuteTimeRow: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        ExplicitFormControlRow(title: title, density: .compactSchedule) {
            TenMinuteTimeField(
                selection: $selection,
                accessibilityLabel: "\(title)時刻"
            )
        }
    }
}

private struct OptionalTenMinuteTimeRow: View {
    let title: String
    @Binding var selection: Date
    @Binding var isSet: Bool
    let defaultValue: Date

    var body: some View {
        ExplicitFormControlRow(title: title, isOptional: true, density: .compactSchedule) {
            HStack(spacing: 6) {
                TenMinuteTimeField(
                    selection: $selection,
                    isSet: $isSet,
                    defaultValue: defaultValue,
                    accessibilityLabel: "\(title)時刻"
                )

                if isSet {
                    Button {
                        isSet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)時刻を未設定に戻す")
                }
            }
        }
    }
}

private struct TenMinuteTimeField: View {
    @Binding var selection: Date
    var isSet: Binding<Bool>?
    var defaultValue: Date?
    let accessibilityLabel: String

    @State private var isShowingPicker = false
    @State private var pendingSelection = Date()

    private var isTimeSet: Bool {
        isSet?.wrappedValue ?? true
    }

    private var displayText: String {
        guard isTimeSet else { return "--:--" }
        return selection.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ja_JP"))
        )
    }

    var body: some View {
        Button {
            pendingSelection = (isTimeSet ? selection : (defaultValue ?? selection))
                .roundedToNearestTenMinutes()
            isShowingPicker = true
        } label: {
            Text(displayText)
                .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(isTimeSet ? Color.primary : Color.secondary)
                .frame(minWidth: 72)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isTimeSet ? displayText : "未設定")
        .popover(isPresented: $isShowingPicker, attachmentAnchor: .rect(.bounds)) {
            VStack(spacing: 8) {
                TenMinuteWheelTimePicker(
                    selection: $pendingSelection,
                    accessibilityLabel: accessibilityLabel,
                    onUserChange: { newValue in
                        selection = newValue.roundedToNearestTenMinutes()
                        isSet?.wrappedValue = true
                    }
                )
                .frame(width: 180, height: 170)

                Button("完了") {
                    isShowingPicker = false
                }
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct TenMinuteWheelTimePicker: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    let onUserChange: (Date) -> Void

    private static let minuteValues = Array(stride(from: 0, to: 24 * 60, by: 10))

    private var minuteOfDay: Binding<Int> {
        Binding(
            get: {
                let rounded = selection.roundedToNearestTenMinutes()
                let components = Calendar.current.dateComponents([.hour, .minute], from: rounded)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            },
            set: { newMinuteOfDay in
                let hour = newMinuteOfDay / 60
                let minute = newMinuteOfDay % 60
                guard let updated = Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: selection
                ) else { return }
                selection = updated
                onUserChange(updated)
            }
        )
    }

    var body: some View {
        Picker(accessibilityLabel, selection: minuteOfDay) {
            ForEach(Self.minuteValues, id: \.self) { minuteOfDay in
                Text(
                    String(
                        format: "%02d:%02d",
                        minuteOfDay / 60,
                        minuteOfDay % 60
                    )
                )
                .font(FavorecoTypography.jpSans(17, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .tag(minuteOfDay)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FiveMinuteTimeField: View {
    @Binding var selection: Date
    let accessibilityLabel: String

    @State private var isShowingPicker = false
    @State private var pendingSelection = Date()

    private var displayText: String {
        selection
            .roundedToNearestFiveMinutes()
            .formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
                    .locale(Locale(identifier: "ja_JP"))
            )
    }

    var body: some View {
        Button {
            pendingSelection = selection.roundedToNearestFiveMinutes()
            isShowingPicker = true
        } label: {
            Text(displayText)
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(minWidth: 68)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(displayText)
        .onAppear {
            normalizeSelectionIfNeeded()
        }
        .onChange(of: selection) { _, newValue in
            let rounded = newValue.roundedToNearestFiveMinutes()
            if abs(newValue.timeIntervalSince(rounded)) >= 1 {
                selection = rounded
            }
        }
        .popover(isPresented: $isShowingPicker, attachmentAnchor: .rect(.bounds)) {
            VStack(spacing: 8) {
                FiveMinuteWheelTimePicker(
                    selection: $pendingSelection,
                    accessibilityLabel: accessibilityLabel
                ) { newValue in
                    selection = newValue.roundedToNearestFiveMinutes()
                }
                .frame(width: 180, height: 170)

                Button("完了") {
                    isShowingPicker = false
                }
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .buttonStyle(.borderedProminent)
                .favorecoProminentActionStyle()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func normalizeSelectionIfNeeded() {
        let rounded = selection.roundedToNearestFiveMinutes()
        if abs(selection.timeIntervalSince(rounded)) >= 1 {
            selection = rounded
        }
    }
}

private struct FiveMinuteWheelTimePicker: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    let onUserChange: (Date) -> Void

    private static let minuteValues = Array(stride(from: 0, to: 24 * 60, by: 5))

    private var minuteOfDay: Binding<Int> {
        Binding(
            get: {
                let rounded = selection.roundedToNearestFiveMinutes()
                let components = Calendar.current.dateComponents([.hour, .minute], from: rounded)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            },
            set: { newMinuteOfDay in
                let hour = newMinuteOfDay / 60
                let minute = newMinuteOfDay % 60
                guard let updated = Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: selection
                ) else { return }
                selection = updated
                onUserChange(updated)
            }
        )
    }

    var body: some View {
        Picker(accessibilityLabel, selection: minuteOfDay) {
            ForEach(Self.minuteValues, id: \.self) { minuteOfDay in
                Text(
                    String(
                        format: "%02d:%02d",
                        minuteOfDay / 60,
                        minuteOfDay % 60
                    )
                )
                .font(FavorecoTypography.jpSans(17, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .tag(minuteOfDay)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
    }
}

extension Date {
    func roundedToNearestFiveMinutes() -> Date {
        let interval: TimeInterval = 5 * 60
        return Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / interval).rounded() * interval)
    }

    func roundedToNearestTenMinutes() -> Date {
        let interval: TimeInterval = 10 * 60
        return Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / interval).rounded() * interval)
    }
}

private struct EventPickerItem: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String
    let categoryIcon: String
    let seriesName: String

    init(event: ExperienceEvent) {
        id = event.id
        title = event.title
        categoryName = event.category?.name ?? "未分類"
        categoryIcon = event.category?.iconSymbol ?? "rectangle.stack"
        seriesName = event.seriesName
    }
}

private struct EventPicker: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let searchPrompt: String
    let items: [EventPickerItem]
    let selectedEventID: UUID?
    let onSelect: (UUID) -> Void

    @State private var searchText = ""

    private var filteredItems: [EventPickerItem] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            normalized(item.title).contains(query)
                || normalized(item.seriesName).contains(query)
                || normalized(item.categoryName).contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredItems) { item in
                        Button {
                            onSelect(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                FavorecoIcon(systemName: item.categoryIcon, size: 18)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .allowsTightening(true)

                                    Text(eventDescription(item))
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                                if item.id == selectedEventID {
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

    private func eventDescription(_ item: EventPickerItem) -> String {
        let description = [item.categoryName, item.seriesName.isEmpty ? nil : item.seriesName]
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

private struct TicketOCRImportResult {
    var ticketGuideKey: String?
    var purchaseURL: String?
    var saleStartAt: Date?
    var applyDeadlineAt: Date?
    var resultAnnounceAt: Date?
    var paymentDeadlineAt: Date?
    var issueStartAt: Date?
    var priceText: String?
    var seatText: String?
    var quantity: Int?
}

private struct PendingTicketOCRImport: Identifiable {
    let id = UUID()
    let result: TicketOCRImportResult
    let suggestedTitle: String?
    let venue: String?
    let eventDateRange: QuickCaptureDateRange?
    let isExistingDuplicate: Bool

    var hasSuggestions: Bool {
        !summaryItems.isEmpty
    }

    var summary: String {
        "候補：\(summaryItems.joined(separator: "、"))"
    }

    var displayTitle: String {
        let title = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "チケット申込" : title
    }

    var scheduleSummary: String {
        var values: [String] = []
        if let dateRange = eventDateRange {
            values.append(FavorecoDateText.compactDateTime(dateRange.startsAt))
        } else {
            values.append("参加日未定")
        }
        if let venue, !venue.isEmpty { values.append(venue) }
        if let guideKey = result.ticketGuideKey,
           let guide = TicketGuideDefinition.guide(for: guideKey) {
            values.append(guide.name)
        }
        return values.joined(separator: " / ")
    }

    var fingerprint: String {
        let values: [String] = [
            suggestedTitle ?? "",
            venue ?? "",
            eventDateRange.map { String(Int($0.startsAt.timeIntervalSince1970 / 60)) } ?? "",
            result.ticketGuideKey ?? "",
            result.purchaseURL ?? "",
            result.applyDeadlineAt.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "",
            result.resultAnnounceAt.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "",
        ]
        return values
            .joined(separator: "|")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }

    func withExistingDuplicate(_ isDuplicate: Bool) -> PendingTicketOCRImport {
        PendingTicketOCRImport(
            result: result,
            suggestedTitle: suggestedTitle,
            venue: venue,
            eventDateRange: eventDateRange,
            isExistingDuplicate: isDuplicate
        )
    }

    private var summaryItems: [String] {
        var values: [String] = []
        if result.ticketGuideKey != nil { values.append("購入先") }
        if result.purchaseURL != nil { values.append("購入URL") }
        if result.saleStartAt != nil { values.append("申込・発売開始") }
        if result.applyDeadlineAt != nil { values.append("抽選申込締切") }
        if result.resultAnnounceAt != nil { values.append("当落発表") }
        if result.paymentDeadlineAt != nil { values.append("支払締切") }
        if result.issueStartAt != nil { values.append("チケット受取開始") }
        if result.priceText != nil { values.append("チケット代") }
        if result.seatText != nil { values.append("座席") }
        if result.quantity != nil { values.append("枚数") }
        if suggestedTitle?.isEmpty == false { values.append("タイトル") }
        if venue?.isEmpty == false { values.append("会場") }
        if eventDateRange != nil { values.append("日時") }
        return values
    }
}

private struct TicketImportReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidates: [PendingTicketOCRImport]
    let onApply: ([PendingTicketOCRImport]) -> Void
    @State private var selectedIDs: Set<UUID>

    init(
        candidates: [PendingTicketOCRImport],
        onApply: @escaping ([PendingTicketOCRImport]) -> Void
    ) {
        self.candidates = candidates
        self.onApply = onApply
        _selectedIDs = State(initialValue: Set(
            candidates.filter { !$0.isExistingDuplicate }.map(\.id)
        ))
    }

    private var selectedCandidates: [PendingTicketOCRImport] {
        candidates.filter { selectedIDs.contains($0.id) && !$0.isExistingDuplicate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { candidate in
                        Button {
                            guard !candidate.isExistingDuplicate else { return }
                            if selectedIDs.contains(candidate.id) {
                                selectedIDs.remove(candidate.id)
                            } else {
                                selectedIDs.insert(candidate.id)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedIDs.contains(candidate.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        candidate.isExistingDuplicate
                                            ? Color.secondary
                                            : Color.accentColor
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.displayTitle)
                                        .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                                        .foregroundStyle(.primary)
                                    Text(candidate.scheduleSummary)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(candidate.isExistingDuplicate ? "登録済みのため除外します" : candidate.summary)
                                        .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                                        .foregroundStyle(
                                            candidate.isExistingDuplicate
                                                ? Color.orange
                                                : Color.secondary
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(candidate.isExistingDuplicate)
                    }
                } header: {
                    FavorecoRegistrationSectionHeader("読み取った内容")
                } footer: {
                    Text("内容を確認し、登録する候補だけを選んでください。登録済みと一致する候補は追加しません。")
                }
            }
            .navigationTitle("画像から入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedCandidates.count > 1
                           ? "\(selectedCandidates.count)件を反映"
                           : "反映") {
                        onApply(selectedCandidates)
                    }
                    .disabled(selectedCandidates.isEmpty)
                }
            }
        }
    }
}

private enum TicketOCRImportParser {
    static func parse(text: String, referenceDate: Date) -> TicketOCRImportResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let contexts = lines + zip(lines, lines.dropFirst()).map { "\($0) \($1)" }

        return TicketOCRImportResult(
            ticketGuideKey: inferredTicketGuideKey(from: text),
            purchaseURL: firstMatch(
                in: text,
                pattern: #"https?://[^\s　]+"#
            ),
            saleStartAt: labeledDate(
                in: contexts,
                labels: ["抽選申込開始", "申込開始", "受付開始", "発売開始"],
                referenceDate: referenceDate
            ),
            applyDeadlineAt: labeledDate(
                in: contexts,
                labels: ["抽選申込締切", "申込締切", "受付終了", "応募締切"],
                referenceDate: referenceDate
            ),
            resultAnnounceAt: labeledDate(
                in: contexts,
                labels: ["当落発表", "抽選結果", "結果発表"],
                referenceDate: referenceDate
            ),
            paymentDeadlineAt: labeledDate(
                in: contexts,
                labels: ["入金締切", "支払締切", "支払期限", "入金期限"],
                referenceDate: referenceDate
            ),
            issueStartAt: labeledDate(
                in: contexts,
                labels: ["チケット受取開始", "受取開始", "発券開始", "表示開始"],
                referenceDate: referenceDate
            ),
            priceText: inferredPrice(from: lines),
            seatText: inferredSeat(from: lines),
            quantity: inferredQuantity(from: lines)
        )
    }

    private static func inferredTicketGuideKey(from text: String) -> String? {
        let normalizedText = normalized(text)
        let aliases: [(String, [String])] = [
            ("pia", ["チケットぴあ", "t.pia.jp"]),
            ("eplus", ["イープラス", "eplus", "eplus.jp", "e+"]),
            ("lawson", ["ローソンチケット", "ローチケ", "l-tike"]),
            ("rakuten", ["楽天チケット", "ticket.rakuten"]),
            ("cnplayguide", ["cnプレイガイド", "cnplayguide"]),
            ("ticketboard", ["ticketboard", "tickebo"]),
            ("tixplus", ["tixplus"]),
            ("confetti", ["カンフェティ", "confetti"]),
            ("teket", ["teket"]),
            ("livepocket", ["livepocket"]),
            ("tiget", ["tiget"]),
            ("zaiko", ["zaiko"]),
            ("peatix", ["peatix"]),
            ("passmarket", ["passmarket"]),
        ]
        return aliases.first { _, values in
            values.contains { normalizedText.contains(normalized($0)) }
        }?.0
    }

    private static func labeledDate(
        in lines: [String],
        labels: [String],
        referenceDate: Date
    ) -> Date? {
        guard let line = lines.first(where: { line in
            let normalizedLine = normalized(line)
            return labels.contains { normalizedLine.contains(normalized($0)) }
        }) else {
            return nil
        }
        return parsedDate(in: line, referenceDate: referenceDate)
    }

    private static func parsedDate(in text: String, referenceDate: Date) -> Date? {
        let pattern = #"(?:(20\d{2})[年./-]\s*)?(\d{1,2})[月./-]\s*(\d{1,2})日?(?:[^0-9]{0,8}(\d{1,2})[:：](\d{2}))?"#
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) else {
            return nil
        }

        func integer(at index: Int) -> Int? {
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: text) else {
                return nil
            }
            return Int(text[swiftRange])
        }

        let calendar = Calendar.current
        let referenceYear = calendar.component(.year, from: referenceDate)
        let referenceMonth = calendar.component(.month, from: referenceDate)
        guard let month = integer(at: 2), let day = integer(at: 3) else {
            return nil
        }
        var year = integer(at: 1) ?? referenceYear
        if integer(at: 1) == nil, month + 6 < referenceMonth {
            year += 1
        }
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: integer(at: 4) ?? 0,
            minute: integer(at: 5) ?? 0
        ))
    }

    private static func inferredPrice(from lines: [String]) -> String? {
        let preferred = lines.filter {
            let value = normalized($0)
            return ["チケット代", "券面額", "料金", "合計"].contains {
                value.contains(normalized($0))
            } && !value.contains("手数料")
        }
        for line in preferred {
            if let amount = firstCapturedGroup(
                in: line,
                pattern: #"(?:[¥￥]\s*|)([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})\s*円?"#
            ) {
                return amount.replacingOccurrences(of: ",", with: "")
            }
        }
        for line in lines where !normalized(line).contains("手数料") {
            if let amount = firstCapturedGroup(
                in: line,
                pattern: #"(?:[¥￥]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})|([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,6})\s*円)"#
            ) {
                return amount.replacingOccurrences(of: ",", with: "")
            }
        }
        return nil
    }

    private static func inferredSeat(from lines: [String]) -> String? {
        let labels = ["座席番号", "座席", "席種", "整理番号"]
        for line in lines {
            if let label = labels.first(where: { normalized(line).contains(normalized($0)) }) {
                let value = line.replacingOccurrences(
                    of: label,
                    with: "",
                    options: [.caseInsensitive, .widthInsensitive]
                )
                .trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines.union(
                        CharacterSet(charactersIn: ":：-｜")
                    )
                )
                if !value.isEmpty {
                    return value
                }
            }
        }
        return lines.first {
            $0.range(of: #"\d+\s*列.*\d+\s*番"#, options: .regularExpression) != nil
        }
    }

    private static func inferredQuantity(from lines: [String]) -> Int? {
        for line in lines where normalized(line).contains("枚") {
            if let value = firstCapturedGroup(in: line, pattern: #"([0-9]{1,2})\s*枚"#),
               let quantity = Int(value),
               (1...20).contains(quantity) {
                return quantity
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ), let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,、。"))
    }

    private static func firstCapturedGroup(in text: String, pattern: String) -> String? {
        guard let match = regularExpression(pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ), match.numberOfRanges > 1 else {
            return nil
        }
        for index in 1..<match.numberOfRanges {
            let capturedRange = match.range(at: index)
            guard capturedRange.location != NSNotFound,
                  let range = Range(capturedRange, in: text) else {
                continue
            }
            let value = String(text[range])
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func regularExpression(_ pattern: String) -> NSRegularExpression {
        // Patterns are static and controlled by this parser.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
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

private struct TicketPlanDraft {
    var categoryID: UUID?
    var title = ""
    var subtitle = ""
    var startsAt = Date().roundedToNearestTenMinutes()
    var endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: Date().roundedToNearestTenMinutes()) ?? Date()
    var opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: Date().roundedToNearestTenMinutes()) ?? Date()
    var hasOpeningTime = false
    var venueName = ""
    var venueAddress = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var publicPlaceSelection: PublicPlaceSelectionDraft?
    var officialURL = ""
    var hasConfirmedSchedule = false
    var createsTicketAttempt = true
    var flowKey = "lotteryPlanned"
    var statusKey = "beforeApply"
    var entryRouteKey = ""
    var accountID: UUID?
    var ticketGuideKey = TicketGuideDefinition.customKey
    var ticketSite = ""
    var holderName = ""
    var applicationGroupIDRaw = ""
    var applicationGroupName = ""
    var hasSaleStart = false
    var saleStartAt = Date().roundedToNearestFiveMinutes()
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

    init(entryMode: AddTicketPlanView.EntryMode = .ticketSchedule) {
        switch entryMode {
        case .plan:
            createsTicketAttempt = false
            hasConfirmedSchedule = true
        case .ticketSchedule:
            createsTicketAttempt = true
            hasConfirmedSchedule = false
        case .unified:
            createsTicketAttempt = false
            hasConfirmedSchedule = false
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
            hasIssueStart = false
        }
    }

    init(inboxItem: InboxItem, categoryID: UUID) {
        self.categoryID = categoryID
        title = inboxItem.title
        officialURL = inboxItem.sourceURL
        memo = inboxItem.body
        createsTicketAttempt = false
        hasConfirmedSchedule = true
    }

    init(
        event: ExperienceEvent,
        entryMode: AddTicketPlanView.EntryMode = .plan,
        continuingApplication: TicketAttempt? = nil
    ) {
        categoryID = event.category?.id
        title = event.title
        officialURL = event.officialURL
        memo = event.memo
        let registeredVenues = VisitUnitFields(rawValue: event.unitFieldsRaw)
            .eventVenues
            .filter { !$0.isEmpty }
        if registeredVenues.count == 1, let venue = registeredVenues.first {
            venueName = venue.trimmedName
            venueAddress = venue.trimmedAddress
        }
        createsTicketAttempt = entryMode == .ticketSchedule
        hasConfirmedSchedule = entryMode != .ticketSchedule
        if let continuingApplication {
            applyContinuation(continuingApplication)
        }
    }

    init(plan: Plan?, entryMode: AddTicketPlanView.EntryMode = .ticketSchedule) {
        guard let plan else {
            switch entryMode {
            case .plan:
                createsTicketAttempt = false
                hasConfirmedSchedule = true
            case .ticketSchedule:
                createsTicketAttempt = true
                hasConfirmedSchedule = false
            case .unified:
                createsTicketAttempt = false
                hasConfirmedSchedule = false
                hasApplyDeadline = false
                hasResultAnnounce = false
                hasPaymentDeadline = false
                hasIssueStart = false
            }
            return
        }
        let attempt = plan.ticketAttempts?
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        categoryID = plan.category?.id
        title = plan.event?.title.isEmpty == false ? plan.event?.title ?? plan.title : plan.title
        subtitle = plan.subtitle
        hasConfirmedSchedule = plan.hasConfirmedSchedule
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        opensAt = plan.opensAt
        hasOpeningTime = plan.opensAt != Date.distantPast
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        latitude = plan.placeMaster?.latitude ?? 0
        longitude = plan.placeMaster?.longitude ?? 0
        officialURL = plan.officialURL
        memo = plan.memo

        guard entryMode == .ticketSchedule else {
            createsTicketAttempt = false
            return
        }

        createsTicketAttempt = true
        guard let attempt else { return }
        flowKey = TicketFlowDefinition.inferredKey(statusKey: attempt.statusKey, entryRouteKey: attempt.entryRouteKey)
        statusKey = attempt.statusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketGuideKey = TicketGuideDefinition.inferredKey(siteName: attempt.ticketSite, urlString: attempt.purchaseURL)
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        applicationGroupIDRaw = attempt.applicationGroupIDRaw
        applicationGroupName = attempt.applicationGroupName
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
        tagNamesText = TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames.joined(separator: "\n")
        purchaseURL = attempt.purchaseURL
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSubtitle: String { subtitle.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedVenueName: String { venueName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedTicketSite: String { ticketSite.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHolderName: String { holderName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedApplicationGroupName: String {
        applicationGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func resolvedApplicationGroupName(for plan: Plan) -> String {
        if !trimmedApplicationGroupName.isEmpty {
            return trimmedApplicationGroupName
        }
        return TicketApplicationCollectionNaming.scheduleName(for: plan)
    }
    func resolvedApplicationGroupIDRaw(for groupName: String) -> String {
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        let draftID = applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return draftID.isEmpty ? UUID().uuidString : draftID
    }
    func resolvedApplicationGroupIDRaw(preserving existingID: String = "") -> String {
        guard !trimmedApplicationGroupName.isEmpty else { return "" }
        let draftID = applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draftID.isEmpty { return draftID }
        let preservedID = existingID.trimmingCharacters(in: .whitespacesAndNewlines)
        return preservedID.isEmpty ? UUID().uuidString : preservedID
    }
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

    var placeSnapshot: PlaceSnapshot {
        PlaceSnapshot(
            name: trimmedVenueName,
            address: venueAddress,
            latitude: latitude,
            longitude: longitude
        )
    }

    var mapSearchQuery: String {
        let address = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? trimmedVenueName : address
    }

    var shouldPreserveVenueNameForAddressSearch: Bool {
        !trimmedVenueName.isEmpty && !venueAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func apply(place: PlaceSearchCandidate, preservingVenueName: Bool) {
        publicPlaceSelection = nil
        if !preservingVenueName {
            venueName = place.name
        }
        if !place.address.isEmpty {
            venueAddress = place.address
        }
        latitude = place.latitude
        longitude = place.longitude
    }

    mutating func apply(placeMaster: PlaceMaster) {
        publicPlaceSelection = nil
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
    }

    mutating func applyDestination(placeMaster: PlaceMaster) {
        apply(placeMaster: placeMaster)
        title = placeMaster.name
    }

    mutating func apply(publicPlace selection: PublicPlaceSelectionDraft) {
        publicPlaceSelection = selection
        venueName = selection.entry.officialName
        venueAddress = selection.entry.address
        latitude = selection.entry.latitude
        longitude = selection.entry.longitude
    }

    mutating func applyDestination(publicPlace selection: PublicPlaceSelectionDraft) {
        apply(publicPlace: selection)
        title = selection.entry.officialName
    }

    mutating func applyDestination(place: PlaceSearchCandidate) {
        apply(place: place, preservingVenueName: false)
        title = place.name
    }

    mutating func clearPlaceSelection() {
        publicPlaceSelection = nil
        venueAddress = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        publicPlaceSelection = nil
        latitude = 0
        longitude = 0
    }

    func placeSuggestions(from placeMasters: [PlaceMaster]) -> [PlaceMaster] {
        let query = normalizedPlaceText(trimmedVenueName)
        guard !query.isEmpty else { return [] }
        let matches = placeMasters
            .filter { !$0.isArchived && !$0.isClosed }
            .filter {
                normalizedPlaceText($0.name).contains(query)
                    || normalizedPlaceText($0.reading).contains(query)
                    || normalizedPlaceText($0.aliasesRaw).contains(query)
            }
        return deduplicatedPlaceSuggestions(matches)
            .prefix(4)
            .map { $0 }
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    func validationMessage(usesOpeningTime: Bool) -> String? {
        if hasConfirmedSchedule && endsAt < startsAt {
            return "終了日時は開始日時以降にしてください。"
        }
        if hasConfirmedSchedule && usesOpeningTime && hasOpeningTime && opensAt > startsAt {
            return "開場日時は開始日時以前にしてください。"
        }
        guard createsTicketAttempt else { return nil }
        if hasSaleStart && hasApplyDeadline && saleStartAt > applyDeadlineAt {
            return "抽選申込開始は抽選申込締切以前にしてください。"
        }
        if hasApplyDeadline && hasResultAnnounce && applyDeadlineAt > resultAnnounceAt {
            return "当落発表は抽選申込締切以降にしてください。"
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
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
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

    var showsAnyTicketMilestone: Bool {
        showsSaleStart || showsApplyDeadline || showsResultAnnounce || showsPaymentDeadline || showsIssueStart
    }

    var showsTicketDetails: Bool {
        flowKey == "acquired"
    }

    var saleStartLabel: String {
        flowKey == "saleWaiting" ? "発売開始" : "抽選申込開始"
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
        venueName = ""
        venueAddress = ""
        latitude = 0
        longitude = 0
        publicPlaceSelection = nil
        let registeredVenues = VisitUnitFields(rawValue: event.unitFieldsRaw)
            .eventVenues
            .filter { !$0.isEmpty }
        if registeredVenues.count == 1, let venue = registeredVenues.first {
            venueName = venue.trimmedName
            venueAddress = venue.trimmedAddress
        }
    }

    mutating func applyTarget(_ plan: Plan) {
        categoryID = plan.category?.id
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = eventTitle.isEmpty ? plan.title : eventTitle
        subtitle = plan.subtitle
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        opensAt = plan.opensAt
        hasOpeningTime = plan.opensAt != Date.distantPast
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        latitude = plan.placeMaster?.latitude ?? 0
        longitude = plan.placeMaster?.longitude ?? 0
        officialURL = plan.officialURL

        guard applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let groupedAttempt = plan.ticketAttempts?
            .filter {
                !$0.isArchived
                    && !$0.applicationGroupIDRaw
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        if let groupedAttempt {
            applicationGroupIDRaw = groupedAttempt.applicationGroupIDRaw
            applicationGroupName = TicketApplicationCollectionNaming.displayName(
                storedName: groupedAttempt.applicationGroupName,
                attempts: [groupedAttempt]
            ) ?? TicketApplicationCollectionNaming.scheduleName(for: plan)
        } else {
            applicationGroupIDRaw = UUID().uuidString
            applicationGroupName = TicketApplicationCollectionNaming.scheduleName(for: plan)
        }
    }

    mutating func applyRegisteredVenue(_ venue: EventVenueEntry) {
        venueName = venue.trimmedName
        venueAddress = venue.trimmedAddress
        latitude = 0
        longitude = 0
        publicPlaceSelection = nil
    }

    mutating func clearTarget() {
        let now = Date().roundedToNearestTenMinutes()
        categoryID = nil
        title = ""
        subtitle = ""
        startsAt = now
        endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now
        opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now
        hasOpeningTime = false
        venueName = ""
        venueAddress = ""
        latitude = 0
        longitude = 0
        officialURL = ""
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
            applicationGroupIDRaw = ""
            applicationGroupName = ""
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
            applicationGroupIDRaw = ""
            applicationGroupName = ""
            hasApplyDeadline = false
            hasResultAnnounce = false
        default:
            break
        }
    }

    mutating func applyContinuation(_ attempt: TicketAttempt) {
        flowKey = TicketFlowDefinition.inferredKey(
            statusKey: attempt.statusKey,
            entryRouteKey: attempt.entryRouteKey
        )
        statusKey = TicketFlowDefinition.definition(for: flowKey).defaultStatusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketGuideKey = TicketGuideDefinition.inferredKey(
            siteName: attempt.ticketSite,
            urlString: attempt.purchaseURL
        )
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        applicationGroupIDRaw = attempt.applicationGroupIDRaw
        applicationGroupName = attempt.applicationGroupName
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
        purchaseURL = attempt.purchaseURL
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

    mutating func applyAccount(
        _ account: TicketAccount?,
        replacing previousAccount: TicketAccount? = nil
    ) {
        if let previousAccount {
            let previousServiceName = previousAccount.serviceName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousHolderName = previousAccount.accountName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousSiteURL = previousAccount.siteURL
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousGuideKey = TicketGuideDefinition.inferredKey(
                siteName: previousServiceName,
                urlString: previousSiteURL
            )
            let previousPurchaseURL = !previousSiteURL.isEmpty
                ? previousSiteURL
                : (TicketGuideDefinition.guide(for: previousGuideKey)?.urlString ?? "")

            if trimmedTicketSite == previousServiceName {
                ticketSite = ""
            }
            if trimmedHolderName == previousHolderName {
                holderName = ""
            }
            if trimmedPurchaseURL == previousPurchaseURL {
                purchaseURL = ""
            }
            if ticketGuideKey == previousGuideKey {
                ticketGuideKey = TicketGuideDefinition.customKey
            }
        }

        guard let account else {
            accountID = nil
            return
        }
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

#Preview {
    AddTicketPlanView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, PersonMaster.self, EventPersonLink.self, PlaceMaster.self, Plan.self, TicketAccount.self, TicketAttempt.self], inMemory: true)
}
