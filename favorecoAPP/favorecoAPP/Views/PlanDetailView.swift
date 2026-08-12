//
//  PlanDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData
import UIKit

struct PlanDetailView: View {
    private static let theaterPreparationSectionID = UUID(uuidString: "A115DB05-31BE-4BF5-870B-BDF5846A8E0A")!

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    let plan: Plan
    var highlightedPreparationTaskID: UUID? = nil
    var highlightedTicketAttemptID: UUID? = nil
    var showsRecordedPlanDetail = false
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?
    @State private var isShowingEditPlan = false
    @State private var isShowingAddAttempt = false
    @State private var editingAttempt: TicketAttempt?
    @State private var quickActionAttempt: TicketAttempt?
    @State private var calendarDraft: CalendarEventDraft?
    @State private var isShowingDeleteConfirmation = false
    @State private var recordEventForVisit: ExperienceEvent?
    @State private var navigatingVisit: Visit?
    @State private var navigatingEventID: UUID?
    @State private var operationError = ""
    @State private var isTicketSectionExpanded = true
    @State private var isTheaterVenueExpanded = false
    @State private var isTheaterNextActionsExpanded = true
    @State private var isTheaterPlanMemoExpanded = false
    @State private var isTheaterExpenseExpanded = false
    @State private var isTheaterEventInformationExpanded = false
    @State private var isTheaterCastExpanded = false
    @State private var isTheaterReviewExpanded = false
    @State private var isTheaterPhotosExpanded = false
    @State private var isTheaterOCRExpanded = false
    @State private var requestedTheaterScrollTargetID: UUID?
    @State private var ticketDetailsPromptAttempt: TicketAttempt?
    @State private var isShowingActionMenu = false
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false

    init(
        plan: Plan,
        highlightedPreparationTaskID: UUID? = nil,
        highlightedTicketAttemptID: UUID? = nil,
        showsRecordedPlanDetail: Bool = false,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil
    ) {
        self.plan = plan
        self.highlightedPreparationTaskID = highlightedPreparationTaskID
        self.highlightedTicketAttemptID = highlightedTicketAttemptID
        self.showsRecordedPlanDetail = showsRecordedPlanDetail
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
    }

    private var categoryColor: Color {
        if (plan.event?.category ?? plan.category)?.templateKey == "theater" {
            return Color(red: 0.82, green: 0.62, blue: 0.30)
        }
        return themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var attempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            (plan.ticketAttempts ?? []).filter { !$0.isArchived }
        )
    }

    private var dateRangeText: String {
        FavorecoDateText.range(from: plan.startsAt, to: plan.endsAt)
    }

    private var preferredOpenDestination: TicketOpenDestination? {
        let attempt = attempts.first

        if let purchaseURL = attempt?.purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
           !purchaseURL.isEmpty,
           let url = URL(string: purchaseURL) {
            return TicketOpenDestination(label: "チケットサイトを開く", url: url)
        }

        if let attempt,
           let guide = TicketGuideDefinition.guide(for: TicketGuideDefinition.inferredKey(
            siteName: attempt.ticketSite,
            urlString: attempt.purchaseURL
           )),
           !guide.urlString.isEmpty,
           let url = URL(string: guide.urlString) {
            return TicketOpenDestination(label: "プレイガイドを開く", url: url)
        }

        let officialURLString = plan.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !officialURLString.isEmpty,
           let url = URL(string: officialURLString) {
            return TicketOpenDestination(label: "公式URLを開く", url: url)
        }

        let sourceURLString = plan.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceURLString.isEmpty,
           let url = URL(string: sourceURLString) {
            return TicketOpenDestination(label: "公式URLを開く", url: url)
        }

        return nil
    }

    private var nextPlanActionEntry: (attempt: TicketAttempt, action: TicketNextActionDefinition)? {
        attempts
            .compactMap { attempt -> (attempt: TicketAttempt, action: TicketNextActionDefinition)? in
                guard let action = TicketNextActionDefinition.nextAction(for: attempt) else { return nil }
                return (attempt: attempt, action: action)
            }
            .sorted { lhs, rhs in
                if Calendar.current.isDate(lhs.action.date, inSameDayAs: rhs.action.date) {
                    return lhs.action.priority < rhs.action.priority
                }
                return lhs.action.date < rhs.action.date
            }
            .first
    }

    private var nextPlanAction: TicketNextActionDefinition? {
        nextPlanActionEntry?.action
    }

    private var nextPlanActionCallout: TicketAttemptNextAction? {
        guard let entry = nextPlanActionEntry else { return nil }
        let action = entry.action
        return TicketAttemptNextAction(
            title: ticketProgressUpdateTitle(for: entry.attempt),
            date: action.date,
            icon: action.systemImage,
            tint: action.isOverdue ? .red : .orange,
            priority: action.priority,
            isOverdue: action.isOverdue
        )
    }

    private var isTheaterPlan: Bool {
        (plan.event?.category ?? plan.category)?.templateKey == "theater"
    }

    var body: some View {
        Group {
            if let visit = plan.visit, !showsRecordedPlanDetail {
                ExperienceDetailView(visit: visit, onBack: onBack)
            } else if isTheaterPlan {
                theaterDetailContent
            } else {
                standardDetailContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            if showsDetailPanelNavigationControls {
                detailPanelNavigationControls
            }
        }
        .favorecoDetailActionMenu(
            isPresented: $isShowingActionMenu,
            genreColor: panelGenreColor,
            accentColor: categoryColor,
            topPadding: showsDetailPanelNavigationControls
                ? (onBack != nil ? 116 : 70)
                : 54,
            actions: planMenuActions
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if onBack != nil, showsDetailPanelNavigationControls {
                CategoryDetailBottomActionBar(
                    shareText: detailShareText,
                    tint: categoryColor,
                    labelColor: isTheaterPlan ? categoryColor : .white,
                    onEdit: { isShowingEditPlan = true }
                )
            }
        }
        .sheet(isPresented: $isShowingEditPlan) {
            AddTicketPlanView(plan: plan, entryMode: .plan)
        }
        .sheet(isPresented: $isShowingAddAttempt) {
            EditTicketAttemptView(plan: plan)
        }
        .sheet(item: $editingAttempt) { attempt in
            EditTicketAttemptView(plan: plan, attempt: attempt)
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
        .ticketPostAcquisitionDetailsPrompt(
            attempt: $ticketDetailsPromptAttempt,
            onEdit: { attempt in
                editingAttempt = attempt
            },
            onLater: { _ in }
        )
        .sheet(item: $recordEventForVisit) { event in
            AddVisitView(
                event: event,
                initialDraft: VisitDraft(plan: plan),
                sourcePlan: plan
            )
        }
        .sheet(item: $calendarDraft) { draft in
            CalendarEventEditSheet(draft: draft) { identifier in
                ExternalCalendarLinkStore.set(identifier: identifier, planID: plan.id)
                if !plan.externalCalendarEventIdentifier.isEmpty {
                    plan.externalCalendarEventIdentifier = ""
                    try? modelContext.save()
                }
            }
        }
        .navigationDestination(item: $navigatingVisit) { visit in
            ExperienceDetailView(visit: visit)
        }
        .navigationDestination(item: $navigatingEventID) { eventID in
            EventDetailDestination(eventID: eventID)
        }
        .confirmationDialog("予定を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("予定を削除", role: .destructive) {
                archivePlan()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("予定と紐づく申込を非表示にし、予約済み通知をキャンセルします。記録済みVisitは削除しません。")
        }
        .alert("処理に失敗しました", isPresented: Binding(
            get: { !operationError.isEmpty },
            set: { if !$0 { operationError = "" } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(operationError)
        }
    }

    private var standardDetailContent: some View {
        CategoryExperiencePage(
            genreColor: panelGenreColor,
            borderColor: categoryColor,
            scrollTargetID: detailScrollTargetID,
            showsScrollingFrame: onBack != nil
        ) {
            categoryPlanHero
        } content: {
            AnyView(basicSection)
            AnyView(ticketSection)
            AnyView(expenseSection)
            AnyView(preparationSection)
            AnyView(officialSection)
            AnyView(memoSection)
        }
    }

    private var planMenuActions: [FavorecoDetailAction] {
        var actions = [
            FavorecoDetailAction(
                title: "予定を編集",
                systemImage: "pencil",
                action: { isShowingEditPlan = true }
            ),
            FavorecoDetailAction(
                title: "チケットを追加",
                systemImage: "ticket",
                action: { isShowingAddAttempt = true }
            ),
            FavorecoDetailAction(
                title: "カレンダーに追加",
                systemImage: "calendar.badge.plus",
                action: { calendarDraft = makeCalendarDraft() }
            )
        ]

        if let destination = preferredOpenDestination {
            actions.append(
                FavorecoDetailAction(
                    title: destination.label,
                    systemImage: "safari",
                    action: { openURL(destination.url) }
                )
            )
        }

        actions.append(contentsOf: [
            FavorecoDetailAction(
                title: plan.visit == nil ? "参加記録を入力" : "参加記録を開く",
                systemImage: "sparkles",
                action: {
                    if let visit = plan.visit {
                        navigatingVisit = visit
                    } else {
                        prepareRecordEntry()
                    }
                }
            ),
            FavorecoDetailAction(
                title: "予定を削除",
                systemImage: "trash",
                isDestructive: true,
                action: { isShowingDeleteConfirmation = true }
            )
        ])
        return actions
    }

    private var theaterAccentColor: Color {
        Color(red: 0.82, green: 0.62, blue: 0.30)
    }

    private var theaterGenreColor: Color {
        Color(hex: (plan.event?.category ?? plan.category)?.colorHex ?? "#8B2F45")
    }

    private var panelGenreColor: Color {
        Color(hex: (plan.event?.category ?? plan.category)?.colorHex ?? "#147C88")
    }

    private var theaterDetailContent: some View {
        CategoryExperiencePage(
            genreColor: theaterGenreColor,
            borderColor: theaterAccentColor,
            scrollTargetID: detailScrollTargetID,
            showsScrollingFrame: onBack != nil
        ) {
            categoryPlanHero
        } content: {
            theaterVenueMapSection
            theaterNextActionsSection
            ticketSection
            preparationSection
            theaterPlanMemoSection
            ExperienceExpenseSummaryCard(
                summary: ExperienceExpenseSummary.make(visit: plan.visit, plan: plan),
                tint: categoryColor,
                title: "費用",
                isExpanded: $isTheaterExpenseExpanded,
                titleFont: TheaterDetailSectionStyle.titleFont
            )
            theaterEventInformationSection
            theaterCastSection
            theaterReviewSection
            theaterPhotoCollectionSection
            theaterOCRSection
        }
    }

    private var showsDetailPanelNavigationControls: Bool {
        plan.visit == nil || showsRecordedPlanDetail
    }

    private var detailPanelNavigationControls: some View {
        HStack {
            Button {
                closeDetail()
            } label: {
                if onBack != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("閉じる")
                    }
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .background(.black.opacity(0.48), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.24), lineWidth: 0.8)
                    }
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.black.opacity(0.48), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.20), lineWidth: 0.7)
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(onBack != nil ? "閉じる" : "戻る")

            Spacer()

            FavorecoDetailActionMenuButton(
                isPresented: $isShowingActionMenu,
                genreColor: panelGenreColor,
                accentColor: categoryColor,
                accessibilityLabel: "予定メニュー"
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, onBack != nil ? 54 : 0)
        .safeAreaPadding(.top, onBack != nil ? 0 : 8)
    }

    private var categoryPlanHero: some View {
        ZStack(alignment: .bottomLeading) {
            planHeroBackground

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 8) {
                        if let seriesName = plan.event?.seriesName, !seriesName.isEmpty {
                            Text(seriesName)
                                .lineLimit(1)
                            Text("•")
                        }
                        Text(planStatusLabel)
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white.opacity(0.76))
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

                    Spacer(minLength: 8)
                    theaterHeroWeather
                }

                if let event = plan.event {
                    if let onOpenEvent {
                        Button {
                            onOpenEvent(event.id)
                        } label: {
                            theaterHeroEventLinkLabel
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            navigatingEventID = event.id
                        } label: {
                            theaterHeroEventLinkLabel
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    theaterHeroTitle
                }

                let eventSubtitle = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
                    .eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !eventSubtitle.isEmpty {
                    Text(eventSubtitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }

                HStack(alignment: .top, spacing: 16) {
                    PlanDetailArtwork(
                        event: plan.event,
                        fallbackSymbol: (plan.event?.category ?? plan.category)?.iconSymbol ?? "theatermasks.fill",
                        tint: categoryColor,
                        usesGoldFrame: isTheaterPlan
                    )
                    .frame(width: isTheaterPlan ? 140 : 112)

                    VStack(alignment: .leading, spacing: 6) {
                        theaterHeroDateRow

                        theaterHeroMetadataRow(
                            icon: "clock",
                            text: theaterPerformanceTime,
                            tint: .white.opacity(0.86)
                        )

                        let styles = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "").styleNames
                        theaterHeroMetadataRow(
                            icon: "tag.fill",
                            text: displayText(planStyleText(styles: styles)),
                            tint: .white.opacity(0.86)
                        )

                        theaterHeroMetadataRow(
                            icon: "mappin.and.ellipse",
                            text: displayText(plan.venueNameSnapshot),
                            tint: .white.opacity(0.86)
                        )

                        if ["theater", "live"].contains(planTemplateKey) {
                            theaterHeroMetadataRow(
                                icon: "chair",
                                text: displayText(theaterSeatText),
                                tint: .white.opacity(0.86)
                            )
                        }

                        theaterHeroMetadataRow(
                            icon: "star.fill",
                            text: "—",
                            tint: .white.opacity(0.90)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minHeight: 485, alignment: .bottom)
    }

    private var planTemplateKey: String {
        (plan.event?.category ?? plan.category)?.templateKey ?? ""
    }

    private var planStatusLabel: String {
        switch planTemplateKey {
        case "theater": "観劇予定"
        case "movie", "museum": "鑑賞予定"
        case "live": "ライブ予定"
        case "theme_park": "来園予定"
        case "nature_living", "goshuin": "訪問予定"
        case "book": "読書予定"
        default: "予定"
        }
    }

    private func planStyleText(styles: [String]) -> String {
        if !styles.isEmpty { return styles.joined(separator: "・") }
        let subtype = plan.event?.subTypeKey.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return subtype
    }

    private var theaterHeroEventLinkLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            theaterHeroTitle
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private var theaterHeroTitle: some View {
        Text(theaterDisplayTitle)
            .font(FavorecoTypography.jpSerif(27, weight: .bold, relativeTo: .title2))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.62), radius: 5, y: 2)
    }

    private var theaterDisplayTitle: String {
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private var detailShareText: String {
        var lines = [
            theaterDisplayTitle,
            FavorecoDateText.fullDate(plan.startsAt)
        ]

        let performanceTime = [
            FavorecoDateText.time(plan.startsAt),
            FavorecoDateText.time(plan.endsAt)
        ].joined(separator: "–")
        lines.append(performanceTime)

        let venue = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !venue.isEmpty {
            lines.append(venue)
        }

        let eventURL = plan.event?.officialURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let planURL = plan.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let officialURL = eventURL.isEmpty ? planURL : eventURL
        if !officialURL.isEmpty {
            lines.append(officialURL)
        }

        return lines.joined(separator: "\n")
    }

    private var planHeroBackground: some View {
        GeometryReader { proxy in
            let fields = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
            let resourceName = HeroBackgroundPreset.resolved(
                categoryKey: planTemplateKey,
                storedKey: fields.heroBackgroundPresetKey
            )?.resourceName ?? "\(planTemplateKey)-hero-default"
            let imageBandHeight = proxy.size.height
            let genreColor = isTheaterPlan ? theaterGenreColor : panelGenreColor

            ZStack(alignment: .top) {
                genreColor
                if let image = theaterHeroBackgroundImage(resourceName: resourceName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: imageBandHeight)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [genreColor.opacity(0.92), Color.black.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: imageBandHeight)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.42), location: 0.00),
                        .init(color: .black.opacity(0.14), location: 0.24),
                        .init(color: .clear, location: 0.48),
                        .init(color: genreColor.opacity(0.18), location: 0.70),
                        .init(color: genreColor.opacity(0.82), location: 0.92),
                        .init(color: genreColor, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: imageBandHeight)
            }
        }
        .clipped()
    }

    private func theaterHeroBackgroundImage(resourceName: String) -> UIImage? {
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private var theaterPerformanceTime: String {
        let start = FavorecoDateText.time(plan.startsAt)
        guard plan.endsAt > plan.startsAt else { return "開演 \(start)" }
        return "\(start)-\(FavorecoDateText.time(plan.endsAt))"
    }

    private var theaterSeatText: String {
        attempts
            .map(\.seatText)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? ""
    }

    private var theaterHeroDateRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            FavorecoIcon(systemName: "calendar", size: 17)
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 20)
            Text(FavorecoDateText.fullDate(plan.startsAt))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
        .foregroundStyle(.white.opacity(0.96))
    }

    private var theaterHeroWeather: some View {
        HStack(spacing: 4) {
            FavorecoIcon(systemName: "cloud.sun", size: 17)
            Text("—")
        }
        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
        .foregroundStyle(.white.opacity(0.92))
        .fixedSize()
    }

    private func theaterHeroMetadataRow(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.96))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func displayText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private var theaterVenueMapSection: some View {
        let venue = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = planAddress
        let hasMapSource = !venue.isEmpty || !address.isEmpty || planMapURL != nil

        return VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .venue,
                tint: theaterAccentColor,
                isExpanded: $isTheaterVenueExpanded
            )

            if !venue.isEmpty || !address.isEmpty {
                TheaterVenueSummary(venueName: venue, address: address)
            }
            PlaceOfficialWebsiteLink(urlString: plan.placeMaster?.officialURL ?? "")
            if venue.isEmpty, address.isEmpty {
                Text("会場・住所は未登録です")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            if isTheaterVenueExpanded {
                if hasMapSource {
                    if let planMapURL {
                        Button {
                            openURL(planMapURL)
                        } label: {
                            FavorecoIconLabel("地図を開く", systemImage: "map", iconSize: 15)
                                .font(FavorecoTypography.captionStrong)
                        }
                        .buttonStyle(.bordered)
                        .tint(theaterAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    ZStack {
                        Color.white.opacity(0.06)
                        FavorecoIcon(systemName: "map", size: 30)
                            .foregroundStyle(theaterAccentColor.opacity(0.52))
                        PlaceMapPreview(
                            venueName: venue,
                            address: address.isEmpty ? venue : address,
                            latitude: plan.placeMaster?.latitude ?? 0,
                            longitude: plan.placeMaster?.longitude ?? 0
                        )
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Text("会場や住所を登録すると地図が表示されます")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterEventInformationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TheaterDetailDisclosureHeader(
                    .eventInformation,
                    tint: theaterAccentColor,
                    isExpanded: $isTheaterEventInformationExpanded
                )
                Spacer()
                if let event = plan.event {
                    if let onOpenEvent {
                        Button {
                            onOpenEvent(event.id)
                        } label: {
                            theaterEventInformationLinkLabel
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            navigatingEventID = event.id
                        } label: {
                            theaterEventInformationLinkLabel
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let event = plan.event {
                PlanInfoRow(icon: "theatermasks", title: "公演", value: displayText(event.title))
                if !event.organizerNameSnapshot.isEmpty {
                    PlanInfoRow(icon: "building.2", title: "主催", value: event.organizerNameSnapshot)
                }

                if isTheaterEventInformationExpanded {
                    if !event.seriesName.isEmpty {
                        PlanInfoRow(icon: "rectangle.stack", title: "シリーズ", value: event.seriesName)
                    }
                    let subtitle = VisitUnitFields(rawValue: event.unitFieldsRaw)
                        .eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !subtitle.isEmpty {
                        PlanInfoRow(icon: "text.quote", title: "副題", value: subtitle)
                    }
                    if !event.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(event.memo)
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let officialURL = URL(string: event.officialURL), !event.officialURL.isEmpty {
                        Link(destination: officialURL) {
                            Label("公式サイト", systemImage: "arrow.up.right.square")
                                .font(FavorecoTypography.bodyStrong)
                                .foregroundStyle(theaterAccentColor)
                        }
                    }
                }
            } else {
                Text("この予定には公演情報が紐づいていません。予定を編集すると、公演情報とまとめて管理できます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterEventInformationLinkLabel: some View {
        Label("公演情報を開く", systemImage: "chevron.right")
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(theaterAccentColor)
    }

    private var theaterNextActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .nextActions,
                countText: theaterIncompleteActionCount > 0 ? "未完了 \(theaterIncompleteActionCount)" : nil,
                tint: theaterAccentColor,
                isExpanded: $isTheaterNextActionsExpanded
            )

            if isTheaterNextActionsExpanded {
                if let nextPlanActionCallout, let nextPlanActionEntry {
                    Button {
                        quickActionAttempt = nextPlanActionEntry.attempt
                    } label: {
                        TicketNextActionCallout(
                            action: nextPlanActionCallout,
                            showsDisclosureIndicator: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("進捗管理を開きます")
                } else if attempts.isEmpty {
                    Text("チケット申込を追加すると、申込・当落・入金・受取の次の期限をここに表示します。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    FavorecoIconLabel("現在、期限のある対応はありません", systemImage: "checkmark.circle")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(theaterAccentColor)
                }

                HStack(spacing: 10) {
                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        FavorecoIconLabel("チケット申込", systemImage: "ticket", iconSize: 17)
                            .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theaterAccentColor)

                    Button {
                        requestedTheaterScrollTargetID = nil
                        Task { @MainActor in
                            await Task.yield()
                            requestedTheaterScrollTargetID = Self.theaterPreparationSectionID
                        }
                    } label: {
                        FavorecoIconLabel("遠征ToDo", systemImage: "suitcase.rolling", iconSize: 17)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(theaterAccentColor)
                }
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterPlanMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .planMemo,
                tint: theaterAccentColor,
                isExpanded: $isTheaterPlanMemoExpanded
            )

            if !isTheaterPlanMemoExpanded, !plan.memo.isEmpty {
                Text(plan.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if isTheaterPlanMemoExpanded {
                if !plan.memo.isEmpty {
                    Text(plan.memo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let url = URL(string: plan.officialURL),
                   !plan.officialURL.isEmpty,
                   plan.officialURL != plan.event?.officialURL {
                    Link(destination: url) {
                        Label("この予定の公式URL", systemImage: "arrow.up.right.square")
                            .foregroundStyle(theaterAccentColor)
                    }
                }
                if plan.memo.isEmpty,
                   plan.officialURL.isEmpty || plan.officialURL == plan.event?.officialURL {
                    Text("予定メモはまだありません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isShowingEditPlan = true
                } label: {
                    FavorecoIconLabel("予定メモを編集", systemImage: "pencil", iconSize: 15)
                        .font(FavorecoTypography.captionStrong)
                }
                .buttonStyle(.bordered)
                .tint(theaterAccentColor)
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterIncompleteActionCount: Int {
        let ticketCount = nextPlanAction == nil ? 0 : 1
        let preparationCount = plan.preparationFields.tasks.filter { !$0.isCompleted }.count
        return ticketCount + preparationCount
    }

    private var theaterCastSection: some View {
        let credits = theaterCreditLines

        return VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .cast,
                tint: theaterAccentColor,
                isExpanded: $isTheaterCastExpanded
            )

            if isTheaterCastExpanded {
                Text("公演全体のキャスト・スタッフ")
                    .font(FavorecoTypography.bodyStrong)

                if credits.isEmpty {
                    Text("キャスト・スタッフはまだ登録されていません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(credits) { line in
                            if let role = line.role, let name = line.name {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(role)
                                        .font(FavorecoTypography.captionStrong)
                                        .foregroundStyle(theaterAccentColor)
                                        .frame(width: 84, alignment: .leading)
                                    Text(name)
                                        .font(FavorecoTypography.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Text(line.rawValue)
                                    .font(FavorecoTypography.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .textSelection(.enabled)
                }

                Divider().overlay(theaterAccentColor.opacity(0.24))

                Text("この回のお目当て・注目した人")
                    .font(FavorecoTypography.bodyStrong)
                Text("観劇記録を入力すると、人物のアイコンと名前をこの回に紐づけて表示できます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                if let event = plan.event {
                    Button {
                        if let onOpenEvent {
                            onOpenEvent(event.id)
                        } else {
                            navigatingEventID = event.id
                        }
                    } label: {
                        theaterEventInformationLinkLabel
                    }
                    .buttonStyle(.bordered)
                    .tint(theaterAccentColor)
                }
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .review,
                tint: theaterAccentColor,
                isExpanded: $isTheaterReviewExpanded
            )

            if isTheaterReviewExpanded {
                Text("観劇後に感情タグや感想を記録できます。予定メモとは分けて保存されます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)

                Button {
                    prepareRecordEntry()
                } label: {
                    FavorecoIconLabel("観劇記録を入力", systemImage: "square.and.pencil", iconSize: 15)
                        .font(FavorecoTypography.captionStrong)
                }
                .buttonStyle(.bordered)
                .tint(theaterAccentColor)
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterPhotoCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TheaterDetailDisclosureHeader(
                    .photos,
                    countText: "0枚",
                    tint: theaterAccentColor,
                    isExpanded: $isTheaterPhotosExpanded
                )

                Spacer()

                Button {
                    prepareRecordEntry()
                } label: {
                    FavorecoIconLabel("写真を追加", systemImage: "plus", iconSize: 13)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(theaterAccentColor)
                }
                .buttonStyle(.borderless)
            }

            if isTheaterPhotosExpanded {
                Text("観劇記録を作成すると、思い出・グッズ・ノベルティや特典の写真を分類して追加できます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterOCRSection: some View {
        let texts = theaterOCRTexts

        return VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .ocr,
                countText: "\(texts.count)件",
                tint: theaterAccentColor,
                isExpanded: $isTheaterOCRExpanded
            )

            if isTheaterOCRExpanded {
                if texts.isEmpty {
                    Text("保存されたOCR・取込結果はありません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .theaterDetailSectionCard(tint: theaterAccentColor)
    }

    private var theaterOCRTexts: [String] {
        var values = plan.preparationFields.tasks
            .map(\.ocrText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let importMemo = plan.event?.importMemo.trimmingCharacters(in: .whitespacesAndNewlines),
           !importMemo.isEmpty {
            values.append(importMemo)
        }
        return values
    }

    private var theaterCreditLines: [PlanTheaterCreditLine] {
        let text = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "").eventCreditsText
        return text.split(whereSeparator: \Character.isNewline).enumerated().compactMap { index, line in
            let rawValue = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { return nil }
            if let separatorIndex = rawValue.firstIndex(where: { $0 == "：" || $0 == ":" }) {
                let role = String(rawValue[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let name = String(rawValue[rawValue.index(after: separatorIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !role.isEmpty, !name.isEmpty {
                    return PlanTheaterCreditLine(id: index, rawValue: rawValue, role: role, name: name)
                }
            }
            return PlanTheaterCreditLine(id: index, rawValue: rawValue, role: nil, name: nil)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FavorecoIcon(systemName: plan.category?.iconSymbol ?? "ticket", size: 20)
                    .foregroundStyle(categoryColor)
                    .frame(width: 38, height: 38)
                    .background(categoryColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.category?.name ?? "予定")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(categoryColor)
                    Text(planStatusText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(plan.title.isEmpty ? "予定" : plan.title)
                .font(FavorecoTypography.heroLead)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !plan.subtitle.isEmpty {
                Text(plan.subtitle)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if !attempts.isEmpty {
                    PlanStatusChip(
                        icon: "ticket",
                        text: "申込 \(attempts.count)件",
                        tint: categoryColor
                    )
                }

                if let nextPlanAction {
                    PlanStatusChip(
                        icon: nextPlanAction.systemImage,
                        text: "\(nextPlanAction.title) \(FavorecoDateText.compactDateTime(nextPlanAction.date))",
                        tint: nextPlanAction.isOverdue ? .red : .orange
                    )
                }

                if plan.visit != nil {
                    PlanStatusChip(
                        icon: "checkmark.seal.fill",
                        text: "記録済み",
                        tint: .green
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .theaterDetailSectionCard(tint: categoryColor)
    }

    private var planStatusText: String {
        if let attempt = attempts.first {
            return TicketStatusDefinition.name(for: attempt.statusKey)
        }
        return plan.visit != nil || plan.stateKey == "attended" ? "参加済み" : "予定"
    }

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            planSectionTitle("基本情報")
            PlanInfoRow(icon: "calendar", title: "日時", value: dateRangeText)
            if plan.usesOpeningTime, plan.opensAt != Date.distantPast {
                PlanInfoRow(icon: "door.left.hand.open", title: "開場", value: FavorecoDateText.time(plan.opensAt))
            }
            if !plan.venueNameSnapshot.isEmpty {
                PlanInfoRow(icon: "mappin.and.ellipse", title: "会場", value: plan.venueNameSnapshot)
            }
            if !planAddress.isEmpty {
                PlanInfoRow(icon: "signpost.right", title: "住所", value: planAddress)
            }
            PlaceOfficialWebsiteLink(urlString: plan.placeMaster?.officialURL ?? "")
            if let mapURL = planMapURL {
                Button {
                    openURL(mapURL)
                } label: {
                    FavorecoIconLabel("地図で見る", systemImage: "map", iconSize: 17)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(categoryColor)
            }
            if !plan.organizerNameSnapshot.isEmpty {
                PlanInfoRow(icon: "building.2", title: "主催", value: plan.organizerNameSnapshot)
            }
        }
        .theaterDetailSectionCard(tint: categoryColor)
    }

    private var planAddress: String {
        plan.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var planMapURL: URL? {
        PlaceSearchService.appleMapsURL(
            name: plan.venueNameSnapshot,
            address: planAddress,
            latitude: plan.placeMaster?.latitude ?? 0,
            longitude: plan.placeMaster?.longitude ?? 0
        )
    }

    @ViewBuilder
    private var ticketSection: some View {
        if attempts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if isTheaterPlan {
                    TheaterDetailDisclosureHeader(
                        .ticket,
                        countText: "0件",
                        tint: theaterAccentColor,
                        isExpanded: $isTicketSectionExpanded
                    )
                } else {
                    planSectionTitle("チケット")
                }
                if !isTheaterPlan || isTicketSectionExpanded {
                    Text("チケット申込はまだ登録されていません。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        FavorecoIconLabel("チケットを追加", systemImage: "plus", iconSize: 17)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(categoryColor)
                }
            }
            .modifier(PlanOrTheaterSectionCard(isTheater: isTheaterPlan, tint: categoryColor))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if isTheaterPlan {
                        TheaterDetailDisclosureHeader(
                            .ticket,
                            countText: "\(attempts.count)件",
                            tint: theaterAccentColor,
                            isExpanded: $isTicketSectionExpanded
                        )
                    } else {
                        planSectionTitle("チケット")
                    }
                    Spacer()
                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        FavorecoIconLabel("チケットを追加", systemImage: "plus", iconSize: 13)
                            .font(FavorecoTypography.captionStrong)
                    }
                    .buttonStyle(.borderless)
                }
                if !isTheaterPlan || isTicketSectionExpanded {
                    ForEach(attempts) { attempt in
                        Button {
                            editingAttempt = attempt
                        } label: {
                            TicketAttemptDetailCard(attempt: attempt, accentColor: categoryColor)
                        }
                        .buttonStyle(.plain)
                        .id(attempt.id)
                        .overlay {
                            if highlightedTicketAttemptID == attempt.id {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(categoryColor, lineWidth: 2)
                                    .shadow(color: categoryColor.opacity(0.55), radius: 7)
                                    .allowsHitTesting(false)
                            }
                        }
                        .contextMenu {
                            Button {
                                editingAttempt = attempt
                            } label: {
                                Label("チケットを編集", systemImage: "pencil")
                            }

                            let transitions = TicketStatusTransitionDefinition.transitions(for: attempt)
                            if !transitions.isEmpty {
                                Divider()
                                ForEach(transitions) { transition in
                                    Button {
                                        updateAttemptStatus(attempt, to: transition.targetStatusKey)
                                    } label: {
                                        Label(transition.title, systemImage: transition.systemImage)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .modifier(PlanOrTheaterSectionCard(isTheater: isTheaterPlan, tint: categoryColor))
        }
    }

    private var detailScrollTargetID: UUID? {
        requestedTheaterScrollTargetID ?? highlightedTicketAttemptID ?? highlightedPreparationTaskID
    }

    @ViewBuilder
    private var preparationSection: some View {
        if plan.supportsPreparationChecklist {
            PlanPreparationChecklistView(
                plan: plan,
                tint: categoryColor,
                title: isTheaterPlan ? "準備・遠征ToDo" : "公演の準備・遠征",
                highlightedTaskID: highlightedPreparationTaskID
            )
            .id(Self.theaterPreparationSectionID)
        }
    }

    private var expenseSection: some View {
        ExperienceExpenseSummaryCard(
            summary: ExperienceExpenseSummary.make(visit: plan.visit, plan: plan),
            tint: categoryColor
        )
    }

    @ViewBuilder
    private var officialSection: some View {
        if !plan.officialURL.isEmpty || !plan.sourceURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("公式情報")
                if let officialURL = URL(string: plan.officialURL), !plan.officialURL.isEmpty {
                    Link(destination: officialURL) {
                        PlanInfoRow(icon: "safari", title: "公式", value: plan.officialURL)
                    }
                    .buttonStyle(.plain)
                }
                if let sourceURL = URL(string: plan.sourceURL), !plan.sourceURL.isEmpty {
                    Link(destination: sourceURL) {
                        PlanInfoRow(icon: "link", title: "参考", value: plan.sourceURL)
                    }
                    .buttonStyle(.plain)
                }
            }
            .theaterDetailSectionCard(tint: categoryColor)
        }
    }

    @ViewBuilder
    private var memoSection: some View {
        if !plan.memo.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("メモ")
                Text(plan.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .theaterDetailSectionCard(tint: categoryColor)
        }
    }

    private func planSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.sectionTitle)
            .foregroundStyle(.primary)
    }

    private func makeCalendarDraft() -> CalendarEventDraft {
        let notes = [
            plan.subtitle,
            attempts.first.map { TicketStatusDefinition.name(for: $0.statusKey) } ?? "",
            attempts.first?.seatText ?? "",
            plan.memo,
            plan.officialURL,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return CalendarEventDraft(
            title: plan.title.isEmpty ? "予定" : plan.title,
            location: plan.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? plan.placeMaster?.address ?? plan.venueNameSnapshot
                : plan.venueNameSnapshot,
            notes: notes,
            startDate: plan.calendarStartsAt,
            endDate: plan.endsAt
        )
    }

    private func archivePlan() {
        let hasExternalCalendarLink = !ExternalCalendarLinkStore.identifier(for: plan).isEmpty
        plan.externalCalendarEventIdentifier = ""
        plan.isArchived = true
        plan.updatedAt = Date()
        let activeAttempts = attempts
        for attempt in activeAttempts {
            attempt.isArchived = true
            attempt.updatedAt = Date()
            attempt.notificationSettingsRaw = ""
        }

        let removesExternalEvent = purchaseManager.currentPlan.includesSync
            && automaticallyUpdatesExternalCalendar
            && hasExternalCalendarLink

        do {
            try modelContext.save()
            for attempt in activeAttempts {
                TicketNotificationScheduler.cancel(plan: plan, attempt: attempt)
            }
            TicketNotificationScheduler.cancel(plan: plan, attempt: nil)
            if removesExternalEvent {
                Task {
                    _ = try? await ExternalCalendarSyncService.remove(plan: plan)
                    try? modelContext.save()
                }
            } else {
                ExternalCalendarLinkStore.clear(planID: plan.id)
            }
            closeDetail()
        } catch {
            modelContext.rollback()
            operationError = "予定を非表示にできませんでした。もう一度お試しください。"
        }
    }

    private func prepareRecordEntry() {
        if let visit = plan.visit {
            navigatingVisit = visit
            return
        }

        let now = Date()
        let event = plan.event ?? ExperienceEvent(
            title: plan.title.isEmpty ? "予定" : plan.title,
            seriesName: plan.subtitle,
            organizerNameSnapshot: plan.organizerNameSnapshot,
            officialURL: plan.officialURL,
            memo: plan.memo,
            createdAt: now,
            updatedAt: now,
            category: plan.category
        )

        if plan.event == nil {
            modelContext.insert(event)
            plan.event = event
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                operationError = "参加記録の準備に失敗しました。もう一度お試しください。"
                return
            }
        }

        recordEventForVisit = event
    }

    private func closeDetail() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func updateAttemptStatus(_ attempt: TicketAttempt, to statusKey: String) {
        do {
            try TicketAttemptStatusUpdater.update(
                attempt: attempt,
                to: statusKey,
                in: modelContext
            )
            if TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: statusKey
            ) {
                DispatchQueue.main.async {
                    ticketDetailsPromptAttempt = attempt
                }
            }
        } catch {
            operationError = "申込状態を更新できませんでした。もう一度お試しください。"
        }
    }

}

private struct TicketOpenDestination {
    let label: String
    let url: URL
}

private struct PlanTheaterCreditLine: Identifiable {
    let id: Int
    let rawValue: String
    let role: String?
    let name: String?
}

private struct PlanDetailArtwork: View {
    let event: ExperienceEvent?
    let fallbackSymbol: String
    let tint: Color
    let usesGoldFrame: Bool

    var body: some View {
        RecordDetailEyecatch(
            event: event,
            photo: event.flatMap { EventRepresentativePhotoResolver.photo(for: $0) },
            aspectRatio: event.map { EyecatchAspectRatio.resolved(for: $0).value }
                ?? EyecatchAspectRatio.bSeriesPoster.value,
            fallbackSymbol: fallbackSymbol,
            tint: tint,
            usesGoldFrame: usesGoldFrame
        )
    }
}

private struct TicketAttemptDetailCard: View {
    let attempt: TicketAttempt
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(TicketStatusDefinition.name(for: attempt.statusKey))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Spacer(minLength: 10)
                if !attempt.entryRouteKey.isEmpty {
                    Text(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }

            TicketCurrentStageCallout(attempt: attempt, fallbackColor: accentColor)

            if let inputIssue {
                FavorecoIconLabel(inputIssue.title, systemImage: inputIssue.systemImage, iconSize: 13)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let accountName {
                PlanInfoRow(icon: "person.crop.circle", title: "名義", value: accountName)
            }
            if !attempt.ticketSite.isEmpty {
                PlanInfoRow(icon: "safari", title: "購入先", value: attempt.ticketSite)
            }
            if attempt.saleStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket", title: "開始", value: FavorecoDateText.fullDateTime(attempt.saleStartAt))
            }
            if attempt.applyDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "hourglass", title: "締切", value: FavorecoDateText.fullDateTime(attempt.applyDeadlineAt))
            }
            if attempt.resultAnnounceAt != Date.distantPast {
                PlanInfoRow(icon: "checkmark.seal", title: "当落", value: FavorecoDateText.fullDateTime(attempt.resultAnnounceAt))
            }
            if attempt.paymentDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "yensign.circle", title: "入金", value: FavorecoDateText.fullDateTime(attempt.paymentDeadlineAt))
            }
            if attempt.issueStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket.fill", title: "チケット受取", value: FavorecoDateText.fullDateTime(attempt.issueStartAt))
            }
            if attempt.price != Decimal(0) || attempt.fee != Decimal(0) {
                PlanInfoRow(icon: "creditcard", title: "金額", value: amountText)
            }
            if !attempt.seatText.isEmpty {
                PlanInfoRow(icon: "chair", title: "座席", value: attempt.seatText)
            }
            let tagNames = TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames
            if !tagNames.isEmpty {
                PlanInfoRow(icon: "tag", title: "タグ", value: tagNames.joined(separator: "、"))
            }
            if let purchaseURL = URL(string: attempt.purchaseURL), !attempt.purchaseURL.isEmpty {
                Link(destination: purchaseURL) {
                    PlanInfoRow(icon: "safari", title: "購入", value: attempt.purchaseURL)
                }
                .buttonStyle(.plain)
            }
            if !attempt.memo.isEmpty {
                Text(attempt.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.90))
        .background(
            Color.black.opacity(0.66),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accentColor.opacity(0.34), lineWidth: 0.7)
        }
    }

    private var accountName: String? {
        if !attempt.holderName.isEmpty {
            return attempt.holderName
        }
        if let account = attempt.account {
            if !account.accountName.isEmpty {
                return account.accountName
            }
            if !account.serviceName.isEmpty {
                return account.serviceName
            }
        }
        return nil
    }

    private var amountText: String {
        let total = (attempt.price + attempt.fee) * Decimal(attempt.quantity)
        let number = NSDecimalNumber(decimal: total)
        return NumberFormatter.planCurrency.string(from: number) ?? "¥\(number.intValue)"
    }

    private var inputIssue: TicketInputIssueDefinition? {
        TicketInputIssueDefinition.issue(for: attempt)
    }
}

private func ticketProgressUpdateTitle(for attempt: TicketAttempt) -> String {
    switch attempt.statusKey {
    case "beforeApply", "onSaleSoon":
        return TicketProgressTimeline.usesLotteryFlow(attempt)
            ? "申込済みにする"
            : "購入済みにする"
    case "waitingResult":
        return "当落結果を入力"
    case "won", "waitingPayment":
        return "支払い済みにする"
    case "waitingIssue":
        return "受取済みにする"
    default:
        return "進捗を更新"
    }
}

private struct TicketAttemptNextAction {
    let title: String
    let date: Date
    let icon: String
    let tint: Color
    let priority: Int
    let isOverdue: Bool
}

private struct TicketNextActionCallout: View {
    let action: TicketAttemptNextAction
    var showsDisclosureIndicator = false

    var body: some View {
        HStack(spacing: 8) {
            FavorecoIcon(systemName: action.icon, size: 13)
            Text(action.isOverdue ? "要確認" : "次のアクション")
                .font(FavorecoTypography.caption)
            Text(action.title)
                .font(FavorecoTypography.captionStrong)
            Spacer(minLength: 8)
            Text(FavorecoDateText.compactDateTime(action.date))
                .font(FavorecoTypography.captionStrong)
            if showsDisclosureIndicator {
                FavorecoIcon(systemName: "chevron.right", size: 13, fallbackWeight: .semibold)
            }
        }
        .foregroundStyle(action.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TicketCurrentStageCallout: View {
    let attempt: TicketAttempt
    let fallbackColor: Color

    var body: some View {
        HStack(spacing: 8) {
            FavorecoIcon(systemName: "ticket", size: 13)
            Text("現在の工程")
                .font(FavorecoTypography.caption)
            Text(TicketProgressPresentation.currentStageLabel(for: attempt))
                .font(FavorecoTypography.captionStrong)
            Spacer(minLength: 8)
        }
        .foregroundStyle(stageColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(stageColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var stageColor: Color {
        guard let plan = attempt.plan else { return fallbackColor }
        let item = CategoryTicketProgressItem(plan: plan, attempt: attempt)
        guard item.currentStageIndex < item.stages.count else {
            return TicketProgressColorPalette.color(for: .acquired)
        }
        return TicketProgressColorPalette.color(for: item.stages[item.currentStageIndex])
    }
}

private struct PlanInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
    }
}

private struct PlanStatusChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        FavorecoIconLabel(text, systemImage: icon, iconSize: 13)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

extension NumberFormatter {
    static let planCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

struct ExperienceExpenseSummaryCard: View {
    let summary: ExperienceExpenseSummary
    let tint: Color
    var title = "費用合計"
    var isExpanded: Binding<Bool>? = nil
    var titleFont: Font = FavorecoTypography.sectionTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded?.wrappedValue ?? true {
                if summary.total == 0 {
                    Text("チケット、グッズ、遠征費を登録するとここにまとまります。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else if summary.usesLegacyFallback {
                    if summary.legacyEntries.isEmpty {
                        expenseRow(icon: "yensign.circle", title: "記録済み合計", amount: summary.legacyAmount)
                    } else {
                        ForEach(summary.legacyEntries) { entry in
                            expenseRow(
                                icon: "yensign.circle",
                                title: entry.normalizedTitle.isEmpty ? "その他" : entry.normalizedTitle,
                                amount: entry.normalizedAmount
                            )
                        }
                        Divider()
                        expenseRow(icon: "sum", title: "合計", amount: summary.legacyAmount)
                    }
                } else {
                    if summary.ticketAmount > 0 {
                        expenseRow(icon: "ticket", title: "チケット", amount: summary.ticketAmount)
                    }
                    if summary.goodsAmount > 0 {
                        expenseRow(icon: "bag", title: "グッズ", amount: summary.goodsAmount)
                    }
                    if summary.travelAmount > 0 {
                        expenseRow(icon: "suitcase.rolling", title: "遠征", amount: summary.travelAmount)
                    }
                }

                if summary.usesTicketPhotoFallback {
                    Text("チケット申込に金額がないため、チケット写真の確認済み金額を使っています。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else if summary.structuredAmount > 0, summary.legacyAmount > 0 {
                    Text("旧入力の合計 \(currencyText(summary.legacyAmount)) は参考値として保持し、二重加算していません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var header: some View {
        if let isExpanded {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                headerContent(showsChevron: true, expanded: isExpanded.wrappedValue)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            headerContent(showsChevron: false, expanded: true)
        }
    }

    private func headerContent(showsChevron: Bool, expanded: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(titleFont)
            Spacer(minLength: 12)
            Text(currencyText(summary.total))
                .font(FavorecoTypography.heroLead)
                .foregroundStyle(tint)
            if showsChevron {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
            }
        }
    }

    private func expenseRow(icon: String, title: String, amount: Decimal) -> some View {
        HStack(spacing: 10) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.body)
            Spacer()
            Text(currencyText(amount))
                .font(FavorecoTypography.bodyStrong)
        }
    }

    private func currencyText(_ amount: Decimal) -> String {
        NumberFormatter.planCurrency.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).intValue)"
    }
}

private struct PlanOrTheaterSectionCard: ViewModifier {
    let isTheater: Bool
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        content.theaterDetailSectionCard(tint: tint)
    }
}

private extension View {
    func planSectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
