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
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    let plan: Plan
    var highlightedPreparationTaskID: UUID? = nil
    let onBack: (() -> Void)?
    @State private var isShowingEditPlan = false
    @State private var isShowingAddAttempt = false
    @State private var editingAttempt: TicketAttempt?
    @State private var calendarDraft: CalendarEventDraft?
    @State private var isShowingDeleteConfirmation = false
    @State private var recordEventForVisit: ExperienceEvent?
    @State private var navigatingVisit: Visit?
    @State private var operationError = ""
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false

    init(
        plan: Plan,
        highlightedPreparationTaskID: UUID? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.highlightedPreparationTaskID = highlightedPreparationTaskID
        self.onBack = onBack
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
            return TicketOpenDestination(label: "申込・購入ページを開く", url: url)
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

    private var nextPlanAction: TicketNextActionDefinition? {
        attempts
            .compactMap { TicketNextActionDefinition.nextAction(for: $0) }
            .sorted {
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.priority < $1.priority
                }
                return $0.date < $1.date
            }
            .first
    }

    private var nextPlanActionCallout: TicketAttemptNextAction? {
        guard let action = nextPlanAction else { return nil }
        return TicketAttemptNextAction(
            title: action.title,
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
            if isTheaterPlan, let visit = plan.visit {
                ExperienceDetailView(visit: visit, onBack: onBack)
            } else if isTheaterPlan {
                theaterDetailContent
            } else {
                standardDetailContent
            }
        }
        .navigationTitle(isTheaterPlan ? "" : "予定・チケット")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isTheaterPlan ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    planActionItems
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .top) {
            if isTheaterPlan, plan.visit == nil {
                theaterNavigationControls
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    basicSection
                    ticketSection
                    expenseSection
                    preparationSection
                    officialSection
                    memoSection
                }
                .padding(20)
            }
            .task(id: highlightedPreparationTaskID) {
                guard let highlightedPreparationTaskID else { return }
                await Task.yield()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(highlightedPreparationTaskID, anchor: .center)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var planActionItems: some View {
        Button {
            isShowingEditPlan = true
        } label: {
            Label("予定を編集", systemImage: "pencil")
        }

        Button {
            isShowingAddAttempt = true
        } label: {
            Label("チケットを追加", systemImage: "ticket")
        }

        Button {
            calendarDraft = makeCalendarDraft()
        } label: {
            Label("カレンダーに追加", systemImage: "calendar.badge.plus")
        }

        if let destination = preferredOpenDestination {
            Button {
                openURL(destination.url)
            } label: {
                Label(destination.label, systemImage: "safari")
            }
        }

        Button {
            if let visit = plan.visit {
                navigatingVisit = visit
            } else {
                prepareRecordEntry()
            }
        } label: {
            Label(plan.visit == nil ? "参加記録を入力" : "参加記録を開く", systemImage: "sparkles")
        }

        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("予定を削除", systemImage: "trash")
        }
    }

    private var theaterAccentColor: Color {
        Color(red: 0.82, green: 0.62, blue: 0.30)
    }

    private var theaterGenreColor: Color {
        Color(hex: (plan.event?.category ?? plan.category)?.colorHex ?? "#8B2F45")
    }

    private var theaterDetailContent: some View {
        TheaterExperiencePage(
            genreColor: theaterGenreColor,
            scrollTargetID: highlightedPreparationTaskID,
            showsScrollingFrame: onBack != nil
        ) {
            theaterHero
        } content: {
            theaterEventInformationSection
            theaterNextActionsSection
            ticketSection
            preparationSection
            expenseSection
            theaterPlanMemoSection
        }
    }

    private var theaterNavigationControls: some View {
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

            Menu {
                planActionItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theaterAccentColor)
                    .frame(width: 50, height: 50)
                    .background(theaterGenreColor.opacity(0.86), in: Circle())
                    .overlay {
                        Circle().stroke(theaterAccentColor.opacity(0.72), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("予定メニュー")
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 8)
    }

    private var theaterHero: some View {
        ZStack(alignment: .bottomLeading) {
            theaterHeroBackground

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 8) {
                        if let seriesName = plan.event?.seriesName, !seriesName.isEmpty {
                            Text(seriesName)
                                .lineLimit(1)
                            Text("•")
                        }
                        Text("観劇予定")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white.opacity(0.76))
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

                    Spacer(minLength: 8)
                    theaterHeroWeather
                }

                if let event = plan.event {
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            theaterHeroTitle
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                    .buttonStyle(.plain)
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
                    TheaterPlanArtwork(
                        event: plan.event,
                        fallbackSymbol: (plan.event?.category ?? plan.category)?.iconSymbol ?? "theatermasks.fill",
                        tint: theaterAccentColor
                    )
                    .frame(width: 140)

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
                            text: displayText(styles.joined(separator: "・")),
                            tint: .white.opacity(0.86)
                        )

                        theaterHeroMetadataRow(
                            icon: "mappin.and.ellipse",
                            text: displayText(plan.venueNameSnapshot),
                            tint: .white.opacity(0.86)
                        )

                        theaterHeroMetadataRow(
                            icon: "chair",
                            text: displayText(theaterSeatText),
                            tint: .white.opacity(0.86)
                        )

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
        .frame(minHeight: 560, alignment: .bottom)
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

    private var theaterHeroBackground: some View {
        GeometryReader { proxy in
            let fields = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
            let resourceName = HeroBackgroundPreset.resolved(
                categoryKey: "theater",
                storedKey: fields.heroBackgroundPresetKey
            )?.resourceName ?? "theater-hero-default"
            let imageBandHeight = min(proxy.size.height * 0.78, 440)

            ZStack(alignment: .top) {
                theaterGenreColor
                if let image = theaterHeroBackgroundImage(resourceName: resourceName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: imageBandHeight)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [theaterGenreColor.opacity(0.92), Color.black.opacity(0.72)],
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
                        .init(color: theaterGenreColor.opacity(0.18), location: 0.70),
                        .init(color: theaterGenreColor.opacity(0.82), location: 0.92),
                        .init(color: theaterGenreColor, location: 1.00),
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
            Image(systemName: "calendar")
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
            Image(systemName: "cloud.sun")
            Text("—")
        }
        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
        .foregroundStyle(.white.opacity(0.92))
        .fixedSize()
    }

    private func theaterHeroMetadataRow(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
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

    private var theaterEventInformationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("作品・公演情報", systemImage: "theatermasks")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                if let event = plan.event {
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        Label("公演情報を開く", systemImage: "chevron.right")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(theaterAccentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let event = plan.event {
                if !event.seriesName.isEmpty {
                    PlanInfoRow(icon: "rectangle.stack", title: "公演", value: event.seriesName)
                }
                let subtitle = VisitUnitFields(rawValue: event.unitFieldsRaw)
                    .eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !subtitle.isEmpty {
                    PlanInfoRow(icon: "text.quote", title: "副題", value: subtitle)
                }
                if !event.organizerNameSnapshot.isEmpty {
                    PlanInfoRow(icon: "building.2", title: "主催", value: event.organizerNameSnapshot)
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
            } else {
                Text("この予定には公演情報が紐づいていません。予定を編集すると、公演情報とまとめて管理できます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .planSectionCard()
    }

    private var theaterNextActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("次にやること", systemImage: "checklist")
                .font(FavorecoTypography.sectionTitle)

            if let nextPlanActionCallout {
                TicketNextActionCallout(action: nextPlanActionCallout)
            } else if attempts.isEmpty {
                Text("チケット申込を追加すると、申込・当落・入金・受取の次の期限をここに表示します。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                Label("現在、期限のある対応はありません", systemImage: "checkmark.circle")
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(theaterAccentColor)
            }

            HStack(spacing: 10) {
                Button {
                    isShowingAddAttempt = true
                } label: {
                    Label("チケット申込", systemImage: "ticket")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theaterAccentColor)

                Button {
                    isShowingEditPlan = true
                } label: {
                    Label("予定を編集", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theaterAccentColor)
            }
        }
        .planSectionCard()
    }

    @ViewBuilder
    private var theaterPlanMemoSection: some View {
        if !plan.memo.isEmpty || (!plan.officialURL.isEmpty && plan.officialURL != plan.event?.officialURL) {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("予定メモ")
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
            }
            .planSectionCard()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: plan.category?.iconSymbol ?? "ticket")
                    .font(.title3)
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
        .planSectionCard()
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
            if let mapURL = planMapURL {
                Button {
                    openURL(mapURL)
                } label: {
                    Label("地図で見る", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(categoryColor)
            }
            if !plan.organizerNameSnapshot.isEmpty {
                PlanInfoRow(icon: "building.2", title: "主催", value: plan.organizerNameSnapshot)
            }
        }
        .planSectionCard()
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
                planSectionTitle("チケット")
                Text("チケット申込はまだ登録されていません。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                Button {
                    isShowingAddAttempt = true
                } label: {
                    Label("チケットを追加", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(categoryColor)
            }
            .planSectionCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    planSectionTitle("チケット")
                    Spacer()
                    Button {
                        isShowingAddAttempt = true
                    } label: {
                        Label("チケットを追加", systemImage: "plus")
                            .font(FavorecoTypography.captionStrong)
                    }
                    .buttonStyle(.borderless)
                }
                ForEach(attempts) { attempt in
                    Button {
                        editingAttempt = attempt
                    } label: {
                        TicketAttemptDetailCard(attempt: attempt, accentColor: categoryColor)
                    }
                    .buttonStyle(.plain)
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
            .planSectionCard()
        }
    }

    @ViewBuilder
    private var preparationSection: some View {
        if plan.supportsPreparationChecklist {
            PlanPreparationChecklistView(
                plan: plan,
                tint: categoryColor,
                highlightedTaskID: highlightedPreparationTaskID
            )
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
            .planSectionCard()
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
            .planSectionCard()
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
        } catch {
            operationError = "申込状態を更新できませんでした。もう一度お試しください。"
        }
    }

}

private struct TicketOpenDestination {
    let label: String
    let url: URL
}

private struct TheaterPlanArtwork: View {
    let event: ExperienceEvent?
    let fallbackSymbol: String
    let tint: Color

    var body: some View {
        Group {
            if let data = event?.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let event, let photo = EventRepresentativePhotoResolver.photo(for: event) {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 720, contentMode: .fill)
            } else {
                ZStack {
                    tint.opacity(0.18)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(tint)
                }
            }
        }
        .aspectRatio(148.0 / 209.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Color(.secondarySystemBackground))
        .theaterPosterFrame(tint: tint)
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

            if let nextAction {
                TicketNextActionCallout(action: nextAction)
            }

            if let inputIssue {
                Label(inputIssue.title, systemImage: inputIssue.systemImage)
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private var nextAction: TicketAttemptNextAction? {
        guard let action = TicketNextActionDefinition.nextAction(for: attempt) else { return nil }
        return TicketAttemptNextAction(
            title: action.title,
            date: action.date,
            icon: action.systemImage,
            tint: tint(for: action),
            priority: action.priority,
            isOverdue: action.isOverdue
        )
    }

    private var inputIssue: TicketInputIssueDefinition? {
        TicketInputIssueDefinition.issue(for: attempt)
    }

    private func tint(for action: TicketNextActionDefinition) -> Color {
        if action.isOverdue {
            return .red
        }
        switch action.title {
        case "申込締切":
            return .red
        case "入金締切":
            return .orange
        case "当落発表":
            return .purple
        case "チケット受取開始":
            return .teal
        default:
            return accentColor
        }
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(FavorecoTypography.captionStrong)
            Text(action.isOverdue ? "要確認" : "次のアクション")
                .font(FavorecoTypography.caption)
            Text(action.title)
                .font(FavorecoTypography.captionStrong)
            Spacer(minLength: 8)
            Text(FavorecoDateText.compactDateTime(action.date))
                .font(FavorecoTypography.captionStrong)
        }
        .foregroundStyle(action.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlanInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(FavorecoTypography.body)
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
        Label(text, systemImage: icon)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("費用合計")
                    .font(FavorecoTypography.sectionTitle)
                Spacer(minLength: 12)
                Text(currencyText(summary.total))
                    .font(FavorecoTypography.heroLead)
                    .foregroundStyle(tint)
            }

            if summary.total == 0 {
                Text("チケット、グッズ、遠征費を登録するとここにまとまります。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            } else if summary.usesLegacyFallback {
                expenseRow(icon: "yensign.circle", title: "記録済み合計", amount: summary.legacyAmount)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func expenseRow(icon: String, title: String, amount: Decimal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
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

private extension View {
    func planSectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
