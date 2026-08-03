//
//  EventDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

private func bundledHeroBackgroundImage(resourceName: String) -> UIImage? {
    if let image = UIImage(named: resourceName) { return image }
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else {
        return nil
    }
    return UIImage(contentsOfFile: url.path)
}

struct EventDetailBackSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}
struct TheaterPublicVenue: Identifiable {
    let id = UUID()
    let name: String
    let address: String
}

struct TheaterPublicLink: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let url: URL
}

private struct EventHeroBackgroundPicker: View {
    let categoryKey: String
    @Binding var selection: String

    private var presets: [HeroBackgroundPreset] {
        HeroBackgroundPreset.presets(for: categoryKey)
    }

    private var resolvedSelection: String {
        HeroBackgroundPreset.resolved(categoryKey: categoryKey, storedKey: selection)?.key ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ページ背景")
                .font(FavorecoTypography.bodyStrong)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
    }

    private func presetButton(_ preset: HeroBackgroundPreset) -> some View {
        let isSelected = resolvedSelection == preset.key
        return Button {
            selection = preset.key
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let image = bundledHeroBackgroundImage(resourceName: preset.resourceName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.12)
                    }
                }
                    .frame(width: 82, height: 100)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color(red: 0.82, green: 0.62, blue: 0.30) : Color.secondary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(preset.title)
                    .font(FavorecoTypography.caption)
                    .lineLimit(2)
                    .frame(width: 82, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EventDetailView: View {
    let event: ExperienceEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @State private var isShowingAddVisit = false
    @State private var isShowingAddPlan = false
    @State private var isShowingAddTicketSchedule = false
    @State private var isShowingTheaterPlanChoice = false
    @State private var isShowingEditEvent = false
    @State private var isShowingRepresentativePhotoPicker = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingTheaterActionPanel = false
    @State private var selectedPlanID: UUID?
    @State private var actionErrorMessage: String?
    @State private var backSwipeExclusionFrames: [CGRect] = []

    private var category: RecordCategory? {
        event.category
    }

    private var accentColor: Color {
        themePalette.categoryColor(hex: category?.colorHex ?? "#6F8F7A")
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    var body: some View {
        let snapshot = EventDetailSnapshot.make(event: event)
        let scheduleSnapshot = TheaterEventScheduleSnapshot.make(event: event)
        let expenseSnapshot = TheaterEventExpenseSnapshot.make(event: event)
        let isTheater = category?.templateKey == "theater"
        let eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        let performanceSchedules = EventDetailPresentation.theaterSchedules(
            event: event,
            fields: eventFields
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: isTheater ? 8 : 20) {
                if isTheater {
                    theaterHero(snapshot: snapshot, schedules: performanceSchedules)
                        .padding(.horizontal, -20)
                        .padding(.top, -24)
                    TheaterPerformanceScheduleSection(
                        schedules: performanceSchedules,
                        accentColor: theaterGold
                    )
                    TheaterEventInformationSection(event: event, accentColor: theaterGold)
                    TheaterEventPeopleSection(
                        creditsText: snapshot.creditsText,
                        castLinks: snapshot.castLinks,
                        staffLinks: snapshot.staffLinks,
                        accentColor: theaterGold
                    )
                    TheaterEventTicketProgressSection(
                        references: scheduleSnapshot.ticketReferences,
                        accentColor: theaterGold,
                        onOpenPlan: { selectedPlanID = $0 }
                    )
                    TheaterEventUpcomingPlansSection(
                        event: event,
                        plans: scheduleSnapshot.upcomingPlans,
                        representativePhoto: snapshot.representativePhoto,
                        accentColor: theaterGold,
                        onAddPlan: openPlanEntry,
                        onOpenPlan: { selectedPlanID = $0 }
                    )
                    TheaterEventParticipationHistorySection(
                        visits: snapshot.visits,
                        accentColor: theaterGold
                    )
                    TheaterEventExpenseSection(
                        snapshot: expenseSnapshot,
                        accentColor: theaterGold
                    )
                    TheaterEventMemoryGallerySection(
                        items: snapshot.memoryPhotos,
                        accentColor: theaterGold
                    )
                    TheaterEventTravelMapSection(
                        snapshot: TheaterTravelMapSnapshot.make(visits: snapshot.visits),
                        accentColor: theaterGold
                    )
                } else if category?.templateKey == "random_goods" {
                    hero(snapshot: snapshot)
                    CollectibleSeriesDashboard(series: event, accentColor: accentColor)
                } else {
                    hero(snapshot: snapshot)
                    eventMemoSection
                    stats(snapshot: snapshot)
                    visitHistory(snapshot: snapshot)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .ignoresSafeArea(edges: isTheater ? .top : [])
        .background {
            if isTheater {
                theaterPageBackground
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .environment(\.colorScheme, isTheater ? .dark : systemColorScheme)
        .navigationTitle(snapshot.eventTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isTheater ? .hidden : .visible, for: .navigationBar)
        .simultaneousGesture(theaterEdgeBackGesture)
        .onPreferenceChange(EventDetailBackSwipeExclusionPreferenceKey.self) { frames in
            backSwipeExclusionFrames = frames
        }
        .overlay(alignment: .top) {
            if isTheater {
                ZStack(alignment: .topTrailing) {
                    theaterNavigationControls
                    if isShowingTheaterActionPanel {
                        theaterActionPanel
                            .padding(.top, 70)
                            .padding(.trailing, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                            .zIndex(1)
                    }
                }
            }
        }
        .toolbar {
            if !isTheater {
                ToolbarItem(placement: .topBarTrailing) {
                    eventMenu
                }
            }
        }
        .navigationDestination(item: $selectedPlanID) { planID in
            EventPlanDestination(planID: planID)
        }
        .sheet(isPresented: $isShowingAddVisit) {
            if category?.templateKey == "random_goods" {
                CollectibleTransactionEditorView(series: event)
            } else {
                AddVisitView(event: event)
            }
        }
        .sheet(isPresented: $isShowingAddPlan) {
            AddTicketPlanView(event: event, entryMode: .plan)
        }
        .sheet(isPresented: $isShowingAddTicketSchedule) {
            AddTicketPlanView(event: event, entryMode: .ticketSchedule)
        }
        .sheet(isPresented: $isShowingEditEvent) {
            if category?.templateKey == "random_goods" {
                AddCollectibleSeriesView(series: event)
            } else {
                EditEventView(event: event)
            }
        }
        .sheet(isPresented: $isShowingRepresentativePhotoPicker) {
            RepresentativePhotoPicker(event: event)
        }
        .confirmationDialog(
            "予定の登録方法",
            isPresented: $isShowingTheaterPlanChoice,
            titleVisibility: .visible
        ) {
            Button("日程を決めて予定を登録") {
                isShowingAddPlan = true
            }
            Button("チケット取得から始める") {
                isShowingAddTicketSchedule = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("参加日が未定でも、この公演に抽選・発売スケジュールを登録できます。")
        }
        .confirmationDialog("この対象を非表示にしますか？", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                archiveThisEvent()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("履歴と写真は削除せず、通常の対象一覧から外します。データ管理の「非表示の対象」から復元できます。")
        }
        .confirmationDialog("この対象を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("この対象とすべての記録を削除", role: .destructive) {
                deleteThisEvent()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(snapshot.eventTitle)」と、ひもづく記録 \(snapshot.visitCount) 件（写真を含む）をすべて削除します。取り消せません。")
        }
        .alert("処理に失敗しました", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var eventMenu: some View {
        Menu {
            eventMenuItems
        } label: {
            Label("メニュー", systemImage: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var eventMenuItems: some View {
        Button {
            isShowingEditEvent = true
        } label: {
            Label(
                category?.templateKey == "random_goods"
                    ? "シリーズ情報・画像を編集"
                    : "対象情報・画像を編集",
                systemImage: "pencil"
            )
        }

        if EventRepresentativePhotoResolver.resolve(
            for: event,
            sortedVisits: (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
        ).photos.isEmpty == false {
            Button {
                isShowingRepresentativePhotoPicker = true
            } label: {
                Label("代表写真を選ぶ", systemImage: "photo.badge.checkmark")
            }
        }

        Button(role: .destructive) {
            isShowingArchiveConfirmation = true
        } label: {
            Label("対象を非表示", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("この対象とすべての記録を削除", systemImage: "trash")
        }
    }

    private var theaterNavigationControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.black.opacity(0.48), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.20), lineWidth: 0.7) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    isShowingTheaterActionPanel.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theaterGold)
                    .frame(width: 50, height: 50)
                    .background(theaterWine.opacity(0.88), in: Circle())
                    .overlay { Circle().stroke(theaterGold.opacity(0.72), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("メニュー")
            .accessibilityValue(isShowingTheaterActionPanel ? "展開中" : "閉じています")
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 8)
    }

    private var theaterActionPanel: some View {
        VStack(spacing: 0) {
            theaterActionButton(
                title: "対象情報・画像を編集",
                systemImage: "pencil"
            ) {
                isShowingTheaterActionPanel = false
                isShowingEditEvent = true
            }

            if EventRepresentativePhotoResolver.resolve(
                for: event,
                sortedVisits: (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
            ).photos.isEmpty == false {
                theaterActionDivider
                theaterActionButton(
                    title: "代表写真を選ぶ",
                    systemImage: "photo.badge.checkmark"
                ) {
                    isShowingTheaterActionPanel = false
                    isShowingRepresentativePhotoPicker = true
                }
            }

            theaterActionDivider
            theaterActionButton(
                title: "対象を非表示",
                systemImage: "archivebox",
                isDestructive: true
            ) {
                isShowingTheaterActionPanel = false
                isShowingArchiveConfirmation = true
            }

            theaterActionDivider
            theaterActionButton(
                title: "すべての記録を削除",
                systemImage: "trash",
                isDestructive: true
            ) {
                isShowingTheaterActionPanel = false
                isShowingDeleteConfirmation = true
            }
        }
        .frame(width: 250)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.025, blue: 0.055),
                    Color.black.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theaterGold.opacity(0.78), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.52), radius: 18, y: 8)
    }

    private var theaterActionDivider: some View {
        Rectangle()
            .fill(theaterGold.opacity(0.20))
            .frame(height: 0.5)
            .padding(.horizontal, 12)
    }

    private func theaterActionButton(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            FavorecoIconLabel(title, systemImage: systemImage, iconSize: 17)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(isDestructive ? Color(red: 0.96, green: 0.45, blue: 0.45) : Color(red: 0.96, green: 0.93, blue: 0.88))
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var theaterPageBackground: some View {
        LinearGradient(
            colors: [theaterWine, Color(red: 0.18, green: 0.025, blue: 0.05), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var theaterWine: Color {
        Color(red: 0.55, green: 0.18, blue: 0.27)
    }

    private var theaterGold: Color {
        Color(red: 0.82, green: 0.62, blue: 0.30)
    }

    private func theaterHero(
        snapshot: EventDetailSnapshot,
        schedules: [TheaterPerformanceScheduleItem]
    ) -> some View {
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        return VStack(spacing: 9) {
            Spacer().frame(height: 132)
            theaterPoster(snapshot: snapshot)

            let performanceTypeName = TheaterPerformanceType.displayName(
                for: event.subTypeKey,
                customName: fields.eventPerformanceTypeCustomName
            )
            if !performanceTypeName.isEmpty {
                Text(performanceTypeName)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(theaterGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.35), in: Capsule())
                    .overlay { Capsule().stroke(theaterGold.opacity(0.50), lineWidth: 0.7) }
            }

            if !event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(event.seriesName)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Text(snapshot.eventTitle)
                .font(FavorecoTypography.jpSerif(29, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !fields.eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(fields.eventSubtitle)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(theaterGold.opacity(0.92))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                FavorecoIconLabel(
                    EventDetailPresentation.theaterPeriodText(event: event, fields: fields),
                    systemImage: "calendar",
                    iconSize: 17
                )
                FavorecoIconLabel(
                    EventDetailPresentation.theaterHeroVenueSummary(schedules: schedules),
                    systemImage: "mappin.and.ellipse",
                    iconSize: 17
                )
                if !event.organizerNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    FavorecoIconLabel(event.organizerNameSnapshot, systemImage: "building.2", iconSize: 17)
                }
            }
            .font(FavorecoTypography.bodyStrong)
            .foregroundStyle(.white.opacity(0.88))
            .symbolRenderingMode(.monochrome)
            .tint(theaterGold)
            .frame(maxWidth: .infinity, alignment: .leading)

            theaterOfficialLinks(fields: fields)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    theaterPlanButton
                    theaterVisitButton
                }
                VStack(spacing: 10) {
                    theaterPlanButton
                    theaterVisitButton
                }
            }
            .tint(theaterGold)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 620, alignment: .top)
        .background {
            theaterHeroBackground(fields: fields)
        }
        .clipped()
    }

    private func theaterHeroBackground(fields: VisitUnitFields) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black

                theaterHeroBackdropImage(fields: fields)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Color(red: 0.18, green: 0.02, blue: 0.04).opacity(0.14)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.10), location: 0),
                        .init(color: .clear, location: 0.42),
                        .init(color: Color(red: 0.12, green: 0.01, blue: 0.025).opacity(0.72), location: 0.78),
                        .init(color: .black.opacity(0.98), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func theaterHeroBackdropImage(
        fields: VisitUnitFields
    ) -> some View {
        let resourceName = HeroBackgroundPreset.resolved(
            categoryKey: "theater",
            storedKey: fields.heroBackgroundPresetKey
        )?.resourceName ?? "theater-hero-venue-v2"
        if let image = bundledHeroBackgroundImage(resourceName: resourceName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(red: 0.18, green: 0.02, blue: 0.04)
        }
    }

    @ViewBuilder
    private func theaterPoster(snapshot: EventDetailSnapshot) -> some View {
        Group {
            if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let photo = snapshot.representativePhoto {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 900, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.black.opacity(0.42))
                    .overlay {
                        FavorecoIcon(systemName: "theatermasks.fill", size: 54)
                            .foregroundStyle(theaterGold.opacity(0.8))
                    }
            }
        }
        .frame(width: 148, height: 209)
        .clipped()
        .theaterPosterFrame(tint: theaterGold)
    }

    private var theaterPlanButton: some View {
        Button(action: openPlanEntry) {
            FavorecoIconLabel("予定を立てる", systemImage: "calendar.badge.plus", iconSize: 17)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func openPlanEntry() {
        if category?.templateKey == "theater" {
            isShowingTheaterPlanChoice = true
        } else {
            isShowingAddPlan = true
        }
    }

    private var theaterVisitButton: some View {
        Button { isShowingAddVisit = true } label: {
            FavorecoIconLabel("記録を追加", systemImage: "plus.circle.fill", iconSize: 17)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var theaterEdgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .onEnded { value in
                guard category?.templateKey == "theater" else { return }
                guard DetailBackSwipePolicy.shouldClose(
                    startLocation: value.startLocation,
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    exclusionFrames: backSwipeExclusionFrames
                ) else { return }
                dismiss()
            }
    }

    @ViewBuilder
    private func theaterOfficialLinks(fields: VisitUnitFields) -> some View {
        let officialURL = EventDetailPresentation.theaterOfficialURL(event: event)
        let ticketURL = EventDetailPresentation.theaterTicketURL(event: event)

        HStack(spacing: 8) {
            theaterPublicLinkButton(
                title: "公式サイト",
                systemImage: "link",
                url: officialURL
            )
            theaterPublicLinkButton(
                title: "チケット",
                systemImage: "ticket",
                url: ticketURL
            )

            HStack(spacing: 6) {
                ForEach(TheaterSocialPlatform.allCases) { platform in
                    let url = EventDetailPresentation.theaterSocialURL(
                        platform: platform,
                        fields: fields
                    )
                    Button {
                        if let url { openURL(url) }
                    } label: {
                        TheaterSocialPlatformIcon(
                            platform: platform,
                            isActive: url != nil,
                            size: 30
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(url == nil)
                    .accessibilityLabel(platform.displayName)
                    .accessibilityValue(url == nil ? "未登録" : "登録済み")
                }
            }
            .accessibilityElement(children: .contain)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func theaterPublicLinkButton(
        title: String,
        systemImage: String,
        url: URL?
    ) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            FavorecoIconLabel(title, systemImage: systemImage, iconSize: 11)
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(.black.opacity(url == nil ? 0.10 : 0.24), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            url == nil
                                ? Color.white.opacity(0.10)
                                : theaterGold.opacity(0.42),
                            lineWidth: 0.7
                        )
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(url == nil ? Color.white.opacity(0.30) : theaterGold)
        .disabled(url == nil)
        .accessibilityValue(url == nil ? "未登録" : "登録済み")
    }

    private func archiveThisEvent() {
        event.isArchived = true
        event.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            actionErrorMessage = "この対象を非表示にできませんでした。もう一度お試しください。"
        }
    }

    private func deleteThisEvent() {
        do {
            let result = try RecordDeletionService.deleteEvent(event, in: modelContext)
            reconcileExternalCalendarAfterDeletion(result.externalCalendarTargets)
            dismiss()
        } catch {
            actionErrorMessage = "この対象を削除できませんでした。もう一度お試しください。"
            assertionFailure("Failed to delete event: \(error)")
        }
    }

    private func reconcileExternalCalendarAfterDeletion(
        _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget]
    ) {
        guard !targets.isEmpty else { return }
        let removesExternalEvents = purchaseManager.currentPlan.includesSync
            && automaticallyUpdatesExternalCalendar

        guard removesExternalEvents else {
            for target in targets {
                ExternalCalendarLinkStore.clear(planID: target.planID)
            }
            return
        }

        Task {
            for target in targets {
                _ = try? await ExternalCalendarSyncService.remove(
                    identifier: target.eventIdentifier,
                    planID: target.planID
                )
            }
        }
    }

    private func hero(snapshot: EventDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let representativePhoto = snapshot.representativePhoto {
                RepresentativePhotoImage(
                    photo: representativePhoto,
                    maxPixelSize: 1200,
                    contentMode: representativeContentMode
                )
                    .aspectRatio(representativeAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: representativeContentMode)
                    .aspectRatio(representativeAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(alignment: .top, spacing: 14) {
                FavorecoIcon(systemName: category?.iconSymbol ?? "rectangle.stack", size: 22)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.eventTitle)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(category?.name ?? "未分類")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)

                    if event.stateKey == "interested" {
                        FavorecoIconLabel("気になる", systemImage: "bookmark.fill", iconSize: 13)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !event.seriesName.isEmpty {
                FavorecoIconLabel(event.seriesName, systemImage: "rectangle.stack", iconSize: 17)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    openPlanEntry()
                } label: {
                    FavorecoIconLabel("予定を立てる", systemImage: "calendar.badge.plus", iconSize: 17)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingAddVisit = true
                } label: {
                    FavorecoIconLabel("記録を追加", systemImage: "plus.circle.fill", iconSize: 17)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .tint(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var representativeAspectRatio: CGFloat {
        CGFloat(EyecatchAspectRatio.resolved(for: event).value)
    }

    private var representativeContentMode: ContentMode {
        EyecatchAspectRatio.usesEyecatchFill(for: category) ? .fill : .fit
    }

    private func stats(snapshot: EventDetailSnapshot) -> some View {
        HStack(spacing: 12) {
            StatSummaryTile(title: "記録", value: "\(snapshot.visitCount)")
            StatSummaryTile(title: "最新", value: snapshot.latestVisitText)
            StatSummaryTile(title: template.ratingLabel, value: snapshot.averageRatingText)
        }
    }

    @ViewBuilder
    private var eventMemoSection: some View {
        if !event.memo.isEmpty || !event.importMemo.isEmpty || !event.officialURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.targetSectionTitle)
                    .font(FavorecoTypography.sectionTitle)

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !event.importMemo.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        FavorecoIconLabel("読み取りメモ", systemImage: "text.viewfinder", iconSize: 13)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        Text(event.importMemo)
                            .font(FavorecoTypography.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
                    Link(destination: url) {
                        FavorecoIconLabel("公式リンク", systemImage: "link", iconSize: 17)
                            .font(FavorecoTypography.bodyStrong)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func visitHistory(snapshot: EventDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("履歴")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(snapshot.visitCount)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if snapshot.visits.isEmpty {
                EventEmptyState(icon: "calendar.badge.plus", message: "この対象の回はまだありません。")
            } else {
                ForEach(snapshot.visits) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        VisitSummaryRow(visit: visit, showsCategory: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

private struct EventPlanDestination: View {
    @Query private var plans: [Plan]

    init(planID: UUID) {
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(plan: plan)
        } else {
            FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
        }
    }
}

enum EventRepresentativePhotoResolver {
    static func photo(for event: ExperienceEvent) -> PhotoBlob? {
        resolve(for: event, sortedVisits: sortedVisits(event)).photo
    }

    static func resolve(
        for event: ExperienceEvent,
        sortedVisits: [Visit]
    ) -> (photo: PhotoBlob?, photos: [PhotoBlob]) {
        var photos: [PhotoBlob] = []
        var automaticPhoto: PhotoBlob?
        for visit in sortedVisits {
            let visitPhotos = photoItems(in: visit)
            photos.append(contentsOf: visitPhotos)
            if automaticPhoto == nil {
                if !visit.eyecatchPath.isEmpty,
                   let cover = visitPhotos.first(where: { $0.relativePath == visit.eyecatchPath }) {
                    automaticPhoto = cover
                } else {
                    automaticPhoto = visitPhotos.first
                }
            }
        }

        let photo: PhotoBlob?
        if !event.representativeEyecatchPath.isEmpty,
           let selected = photos.first(where: { $0.relativePath == event.representativeEyecatchPath }) {
            photo = selected
        } else if event.eyecatchData != nil {
            photo = nil
        } else {
            photo = automaticPhoto
        }
        return (photo, photos)
    }

    static func allPhotos(in event: ExperienceEvent) -> [PhotoBlob] {
        resolve(for: event, sortedVisits: sortedVisits(event)).photos
    }

    private static func sortedVisits(_ event: ExperienceEvent) -> [Visit] {
        (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
    }

    private static func photoItems(in visit: Visit) -> [PhotoBlob] {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

struct RepresentativePhotoImage: View {
    let photo: PhotoBlob
    let maxPixelSize: CGFloat
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var loadedCacheKey: String?

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill))
                    .overlay { ProgressView() }
            }
        }
        .task(id: cacheKey) {
            if let cached = ThumbnailLoader.cached(forKey: cacheKey) {
                image = cached
                loadedCacheKey = cacheKey
                return
            }
            image = nil
            loadedCacheKey = nil
            let data = photo.data
            let key = cacheKey
            let loadedImage = await Task.detached(priority: .userInitiated) {
                ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixelSize, cacheKey: key)
            }.value
            guard !Task.isCancelled else { return }
            image = loadedImage
            loadedCacheKey = key
        }
    }

    private var displayedImage: UIImage? {
        if loadedCacheKey == cacheKey {
            return image
        }
        return ThumbnailLoader.cached(forKey: cacheKey)
    }

    private var cacheKey: String {
        "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
    }
}

private struct RepresentativePhotoPicker: View {
    let event: ExperienceEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var saveErrorMessage: String?

    private var photos: [PhotoBlob] {
        EventRepresentativePhotoResolver.allPhotos(in: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(photos) { photo in
                        Button {
                            save(photo.relativePath)
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 360)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                if photo.relativePath == event.representativeEyecatchPath {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.accentColor)
                                        .padding(7)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(photo.relativePath == event.representativeEyecatchPath ? "選択中の代表写真" : "代表写真に設定")
                    }
                }
                .padding(16)
            }
            .navigationTitle("代表写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("自動") { save("") }
                        .disabled(event.representativeEyecatchPath.isEmpty)
                }
            }
            .alert("保存に失敗しました", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private func save(_ path: String) {
        let previousPath = event.representativeEyecatchPath
        event.representativeEyecatchPath = path
        event.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            event.representativeEyecatchPath = previousPath
            saveErrorMessage = "代表写真を保存できませんでした。もう一度お試しください。"
        }
    }
}

struct EditEventView: View {
    let event: ExperienceEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @State private var draft: EventDraft
    @State private var eyecatchData: Data?
    @State private var selectedEyecatchItem: PhotosPickerItem?
    @State private var isProcessingEyecatch = false
    @State private var isConfirmingEyecatchRemoval = false
    @State private var saveErrorMessage: String?
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var deletedPersonLinkIDs: Set<UUID> = []
    @State private var showingPerformanceBasic = true
    @State private var showingPerformanceDetails = false
    @State private var showingImportDetails = false

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    init(event: ExperienceEvent) {
        self.event = event
        _draft = State(initialValue: EventDraft(event: event))
        _eyecatchData = State(initialValue: event.eyecatchData)
    }

    var body: some View {
        NavigationStack {
            Form {
                if event.category?.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .performanceEditing)
                    }
                }
                Section {
                    let photoActionTitle = eyecatchData == nil ? "写真を選ぶ" : "写真を変更"
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        if event.category?.templateKey == "theater" {
                            HStack {
                                Spacer(minLength: 0)
                                ZStack(alignment: .topTrailing) {
                                    eyecatchPreview(image)
                                    Button {
                                        isConfirmingEyecatchRemoval = true
                                    } label: {
                                        FavorecoIcon(systemName: "trash", size: 16)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 30, height: 30)
                                            .background(.black.opacity(0.68), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(6)
                                    .accessibilityLabel("公演ビジュアルを削除")
                                }
                                Spacer(minLength: 0)
                            }
                        } else {
                            eyecatchPreview(image)
                            Button("画像を外す", role: .destructive) {
                                self.eyecatchData = nil
                            }
                        }
                    } else if event.category?.templateKey == "theater" {
                        theaterVisualPlaceholder
                    }

                    if event.category?.templateKey == "theater" {
                        PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                            FavorecoIconLabel(photoActionTitle, systemImage: "photo", iconSize: 13)
                                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .caption))
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(Color.accentColor.opacity(0.11), in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isProcessingEyecatch)
                        .onChange(of: selectedEyecatchItem) { _, item in
                            guard let item else { return }
                            Task { await loadEyecatch(from: item) }
                        }
                    } else {
                        PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                            FavorecoIconLabel(photoActionTitle, systemImage: "photo", iconSize: 17)
                        }
                        .disabled(isProcessingEyecatch)
                        .onChange(of: selectedEyecatchItem) { _, item in
                            guard let item else { return }
                            Task { await loadEyecatch(from: item) }
                        }
                    }

                    if isProcessingEyecatch {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("画像を準備しています")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if event.category?.templateKey == "book" {
                        Picker("本の種類", selection: $draft.eyecatchAspectRatioKey) {
                            ForEach(bookFormatOptions) { format in
                                Text(format.name).tag(format.key)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(selectedEyecatchAspectRatio.note)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if event.category?.templateKey == "theater" {
                        EventHeroBackgroundPicker(
                            categoryKey: "theater",
                            selection: $draft.heroBackgroundPresetKey
                        )
                    }
                } header: {
                    if event.category?.templateKey == "theater" {
                        Text("公演ビジュアル")
                    } else {
                        Text("対象アイキャッチ")
                    }
                } footer: {
                    Text(
                        event.category?.templateKey == "theater"
                            ? "公演ページや、記録写真がない観劇記録の代表画像として表示します。"
                            : "クイック登録の表紙や、記録写真がない対象の代表画像として表示します。"
                    )
                }

                Section {
                    if event.category?.templateKey == "theater" {
                        DisclosureGroup(isExpanded: $showingPerformanceBasic) {
                            ExplicitFormTextField(
                                title: "公演名",
                                prompt: "例：月影のアトリエ",
                                text: $draft.title,
                                labelStyle: .horizontal
                            )
                            ExplicitFormTextField(
                                title: "シリーズ",
                                prompt: "〇〇シリーズ（任意）",
                                text: $draft.seriesName,
                                labelStyle: .horizontal
                            )
                            TheaterPerformanceTypePicker(
                                selection: $draft.subTypeKey,
                                customName: $draft.performanceTypeCustomName,
                                usesCompactLabelStyle: true
                            )
                            ExplicitFormTextField(
                                title: "サブタイトル",
                                prompt: "東京公演限定版（任意）",
                                text: $draft.eventSubtitle,
                                labelStyle: .horizontal
                            )
                            ExplicitFormTextField(
                                title: "公式URL",
                                prompt: "https://example.com（任意）",
                                text: $draft.officialURL,
                                labelStyle: .horizontal
                            )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            TheaterSocialLinksEditor(
                                xURL: $draft.xURL,
                                instagramURL: $draft.instagramURL,
                                threadsURL: $draft.threadsURL
                            )
                        } label: {
                            TheaterUnifiedSectionLabel(section: .performanceBasic)
                        }
                    } else if event.category?.templateKey == "movie" {
                        VStack(alignment: .leading, spacing: 12) {
                            ScreenWorkTypeAndSeasonEditor(
                                typeKey: $draft.subTypeKey,
                                seasonNumber: $draft.screenWorkSeasonNumber
                            )
                            TextField(template.titlePlaceholder, text: $draft.title)
                        }
                    } else {
                        TextField(template.titlePlaceholder, text: $draft.title)
                        TextField(template.seriesPlaceholder, text: $draft.seriesName)
                        TextField("サブタイトル（任意）", text: $draft.eventSubtitle)
                        TextField("公式URL（任意）", text: $draft.officialURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        TextField("SNSリンク（1行1件・任意）", text: $draft.socialLinksText, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .lineLimit(2...5)
                    }
                } header: {
                    if event.category?.templateKey != "theater" {
                        Text(template.targetSectionTitle)
                    }
                }

                if event.category?.templateKey == "theater" {
                    Section {
                        ForEach($draft.venueEntries) { $venue in
                            TheaterScheduleEntryEditor(
                                entry: $venue,
                                fallbackStart: draft.performanceStartsAt,
                                fallbackEnd: draft.performanceEndsAt
                            )
                        }
                        .onDelete { offsets in
                            draft.venueEntries.remove(atOffsets: offsets)
                        }

                        Button {
                            let usesLegacySharedPeriod = draft.venueEntries.isEmpty
                                && draft.hasPerformancePeriod
                            draft.venueEntries.append(
                                EventVenueEntry(
                                    startsAt: usesLegacySharedPeriod ? draft.performanceStartsAt : nil,
                                    endsAt: usesLegacySharedPeriod ? draft.performanceEndsAt : nil
                                )
                            )
                        } label: {
                            FavorecoIconLabel("公演地を追加", systemImage: "plus.circle", iconSize: 17)
                        }
                    } header: {
                        TheaterUnifiedSectionLabel(section: .venueSchedule)
                    } footer: {
                        Text("東京公演・大阪公演など、公演地ごとに会期と会場を登録します。未登録の場合は予定と参加履歴から補完表示します。")
                    }
                }

                if event.category?.templateKey == "theater" {
                    Section {
                        DisclosureGroup(isExpanded: $showingPerformanceDetails) {
                            TheaterCreditsTextEditor(text: $draft.creditsText)
                            Divider()
                            PeopleUnitEditor(
                                existingLinks: visibleEventOrganizationLinks,
                                deletedLinkIDs: $deletedPersonLinkIDs,
                                pendingLinks: $pendingPeople,
                                personMasters: personMasters,
                                roleOptions: PersonRoleOption.theaterOrganizations,
                                emptyDescription: "団体別に振り返りたい場合だけ、上演団体・主催・制作などを追加します。"
                            )
                            Divider()
                            ExplicitFormTextField(
                                title: "メモ（任意）",
                                prompt: "あらすじ・自由メモ",
                                text: $draft.memo,
                                axis: .vertical,
                                minimumLines: 5,
                                maximumLines: 5,
                                labelStyle: .horizontal,
                                reservesLineSpace: true
                            )
                        } label: {
                            TheaterUnifiedSectionLabel(section: .performanceDetails)
                        }
                    }
                } else {
                    Section("対象メモ") {
                        ZStack(alignment: .topLeading) {
                            if draft.memo.isEmpty {
                                Text("対象そのものについて残しておきたいこと")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $draft.memo)
                                .frame(minHeight: 120)
                        }
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showingImportDetails) {
                        TextEditor(text: $draft.importMemo)
                            .frame(minHeight: 140)
                    } label: {
                        TheaterUnifiedSectionLabel(section: .importDetails)
                    }
                }
            }
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .navigationTitle(
                event.category?.templateKey == "theater"
                    ? TheaterUnifiedFormEntry.performanceEditing.navigationTitle
                    : "対象を編集"
            )
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
                    .disabled(!draft.canSave || isProcessingEyecatch)
                }
            }
            .alert("保存に失敗しました", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .confirmationDialog(
                "公演ビジュアルを削除しますか？",
                isPresented: $isConfirmingEyecatchRemoval,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    eyecatchData = nil
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("保存すると、この公演のビジュアルが削除されます。")
            }
        }
    }

    @MainActor
    private func loadEyecatch(from item: PhotosPickerItem) async {
        isProcessingEyecatch = true
        defer {
            isProcessingEyecatch = false
            selectedEyecatchItem = nil
        }
        let targetAspectRatio = event.category?.templateKey == "theater"
            ? CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
            : nil
        guard let sourceData = try? await item.loadTransferable(type: Data.self),
              let compressed = await Task.detached(priority: .userInitiated, operation: {
                  QuickCaptureImageService.compressedJPEG(
                      from: sourceData,
                      centeredToAspectRatio: targetAspectRatio
                  )
              }).value else {
            saveErrorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed
    }

    @ViewBuilder
    private func eyecatchPreview(_ image: UIImage) -> some View {
        if EyecatchAspectRatio.usesEyecatchFill(for: event.category) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: event.category?.templateKey == "theater" ? 150 : nil,
                    height: event.category?.templateKey == "theater" ? 212 : nil
                )
                .frame(maxWidth: event.category?.templateKey == "theater" ? nil : .infinity)
                .aspectRatio(
                    event.category?.templateKey == "theater"
                        ? nil
                        : CGFloat(selectedEyecatchAspectRatio.value),
                    contentMode: .fit
                )
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var theaterVisualPlaceholder: some View {
        HStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 150, height: 212)
                .overlay {
                    VStack(spacing: 7) {
                        FavorecoIcon(systemName: "photo", size: 24)
                        Text("未設定")
                            .font(FavorecoTypography.caption)
                    }
                    .foregroundStyle(Color.secondary.opacity(0.72))
                }
            Spacer(minLength: 0)
        }
    }

    private func save() {
        let now = Date()
        let updatedTitle = draft.trimmedTitle
        event.title = updatedTitle
        event.seriesName = draft.trimmedSeriesName
        if event.category?.templateKey == "theater" {
            event.subTypeKey = draft.subTypeKey
            for plan in event.plans ?? [] {
                plan.title = updatedTitle
                plan.updatedAt = now
            }
        } else if event.category?.templateKey == "movie" {
            event.subTypeKey = ScreenWorkType.resolved(from: draft.subTypeKey).rawValue
        }
        event.officialURL = draft.trimmedOfficialURL
        var unitFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        unitFields.socialLinks = draft.normalizedSocialLinks
        unitFields.eventSubtitle = draft.trimmedEventSubtitle
        unitFields.eventCreditsText = draft.trimmedCreditsText
        unitFields.eventPerformanceTypeCustomName = TheaterPerformanceType.customNameForStorage(
            key: draft.subTypeKey,
            input: draft.performanceTypeCustomName
        )
        if event.category?.templateKey == "movie" {
            unitFields.screenWorkSeasonNumber = ScreenWorkType.resolved(from: draft.subTypeKey).supportsSeason
                ? draft.screenWorkSeasonNumber
                : 0
        }
        let normalizedVenueEntries = draft.normalizedVenueEntries
        unitFields.eventVenues = normalizedVenueEntries
        if normalizedVenueEntries.isEmpty {
            unitFields.eventPeriodStartsAt = draft.hasPerformancePeriod ? draft.performanceStartsAt : nil
            unitFields.eventPeriodEndsAt = draft.hasPerformancePeriod ? draft.performanceEndsAt : nil
        } else {
            unitFields.eventPeriodStartsAt = normalizedVenueEntries.compactMap(\.startsAt).min()
            unitFields.eventPeriodEndsAt = normalizedVenueEntries.compactMap { $0.endsAt ?? $0.startsAt }.max()
        }
        unitFields.heroBackgroundPresetKey = draft.heroBackgroundPresetKey
        event.memo = draft.trimmedMemo
        event.importMemo = draft.trimmedImportMemo
        event.eyecatchData = eyecatchData
        ThumbnailLoader.purge()
        if event.category?.templateKey == "book" {
            unitFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
        }
        event.unitFieldsRaw = unitFields.encodedRawValue
        event.updatedAt = now
        deleteMarkedPersonLinks()
        insertPendingPeople()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "対象情報を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to update event: \(error)")
        }
    }

    private var visibleEventOrganizationLinks: [EventPersonLink] {
        let organizationRoleKeys = Set(PersonRoleOption.theaterOrganizations.map(\.key))
        return (event.personLinks ?? [])
            .filter {
                !$0.isArchived
                    && !deletedPersonLinkIDs.contains($0.id)
                    && $0.visit == nil
                    && organizationRoleKeys.contains($0.roleKey)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func deleteMarkedPersonLinks() {
        for link in event.personLinks ?? [] where deletedPersonLinkIDs.contains(link.id) {
            modelContext.delete(link)
        }
    }

    private func insertPendingPeople() {
        let startIndex = (event.personLinks ?? []).filter { !$0.isArchived && $0.visit == nil }.count
        for (offset, pending) in pendingPeople.enumerated() {
            let person = resolvePersonMaster(for: pending, from: personMasters, in: modelContext)
            modelContext.insert(pending.makeEventPersonLink(
                person: person,
                event: event,
                visit: nil,
                sortOrder: startIndex + offset
            ))
        }
    }

    private var selectedEyecatchAspectRatio: EyecatchAspectRatio {
        EyecatchAspectRatio.option(for: draft.eyecatchAspectRatioKey, category: event.category)
    }

    private var bookFormatOptions: [EyecatchAspectRatio] {
        if draft.eyecatchAspectRatioKey == EyecatchAspectRatio.bookCover.key {
            return [EyecatchAspectRatio.bookCover] + EyecatchAspectRatio.selectableBookFormats
        }
        return EyecatchAspectRatio.selectableBookFormats
    }
}

private struct EventDraft {
    var title: String
    var seriesName: String
    var subTypeKey: String
    var screenWorkSeasonNumber: Int
    var performanceTypeCustomName: String
    var officialURL: String
    var xURL: String
    var instagramURL: String
    var threadsURL: String
    var otherSocialLinks: [String]
    var socialLinksText: String
    var usesPlatformSocialLinks: Bool
    var eventSubtitle: String
    var creditsText: String
    var memo: String
    var importMemo: String
    var eyecatchAspectRatioKey: String
    var hasPerformancePeriod: Bool
    var performanceStartsAt: Date
    var performanceEndsAt: Date
    var venueEntries: [EventVenueEntry]
    var heroBackgroundPresetKey: String

    init(event: ExperienceEvent) {
        title = event.title
        seriesName = event.seriesName
        subTypeKey = event.subTypeKey
        officialURL = event.officialURL
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        if event.category?.templateKey == "movie" {
            subTypeKey = ScreenWorkType.resolved(from: subTypeKey).rawValue
        }
        screenWorkSeasonNumber = fields.screenWorkSeasonNumber
        performanceTypeCustomName = fields.eventPerformanceTypeCustomName
        xURL = fields.socialLinks.first {
            TheaterSocialPlatform.platform(for: $0) == .x
        } ?? ""
        instagramURL = fields.socialLinks.first {
            TheaterSocialPlatform.platform(for: $0) == .instagram
        } ?? ""
        threadsURL = fields.socialLinks.first {
            TheaterSocialPlatform.platform(for: $0) == .threads
        } ?? ""
        otherSocialLinks = fields.socialLinks.filter {
            TheaterSocialPlatform.platform(for: $0) == nil
        }
        socialLinksText = fields.socialLinks.joined(separator: "\n")
        usesPlatformSocialLinks = event.category?.templateKey == "theater"
        eventSubtitle = fields.eventSubtitle
        creditsText = fields.eventCreditsText
        memo = event.memo
        importMemo = event.importMemo
        eyecatchAspectRatioKey = EyecatchAspectRatio.resolved(for: event).key
        hasPerformancePeriod = fields.eventPeriodStartsAt != nil || fields.eventPeriodEndsAt != nil
        performanceStartsAt = fields.eventPeriodStartsAt ?? (event.plans ?? []).map(\.startsAt).min() ?? Date()
        let fallbackEnd = (event.plans ?? []).map(\.endsAt).max() ?? performanceStartsAt
        performanceEndsAt = max(fields.eventPeriodEndsAt ?? fallbackEnd, performanceStartsAt)
        let usesLegacySharedPeriod = !fields.eventVenues.isEmpty
            && fields.eventVenues.allSatisfy { $0.startsAt == nil && $0.endsAt == nil }
        venueEntries = fields.eventVenues.map { entry in
            var migrated = entry
            if usesLegacySharedPeriod {
                migrated.startsAt = fields.eventPeriodStartsAt
                migrated.endsAt = fields.eventPeriodEndsAt
            }
            return migrated
        }
        heroBackgroundPresetKey = fields.heroBackgroundPresetKey
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEventSubtitle: String {
        eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCreditsText: String {
        creditsText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSocialLinks: [String] {
        let source = usesPlatformSocialLinks
            ? otherSocialLinks + [xURL, instagramURL, threadsURL]
            : socialLinksText.components(separatedBy: .newlines)
        return source
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedImportMemo: String {
        importMemo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedVenueEntries: [EventVenueEntry] {
        venueEntries.compactMap { entry in
            let normalized = EventVenueEntry(
                id: entry.id,
                name: entry.trimmedName,
                address: entry.trimmedAddress,
                performanceLabel: entry.trimmedPerformanceLabel.isEmpty ? nil : entry.trimmedPerformanceLabel,
                startsAt: entry.startsAt,
                endsAt: entry.startsAt.map { max(entry.endsAt ?? $0, $0) }
            )
            return normalized.isEmpty ? nil : normalized
        }
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
            && TheaterPerformanceType.isValidSelection(
                key: subTypeKey,
                customName: performanceTypeCustomName
            )
    }
}

struct EventDetailDestination: View {
    @Query private var events: [ExperienceEvent]

    init(eventID: UUID) {
        _events = Query(filter: #Predicate<ExperienceEvent> { $0.id == eventID })
    }

    var body: some View {
        if let event = events.first {
            EventDetailView(event: event)
        } else {
            FavorecoContentUnavailableView("公演情報が見つかりません", systemImage: "trash")
        }
    }
}

private struct StatSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FavorecoTypography.latinDisplay(22, weight: .bold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EventEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(message)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let category = RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45", templateKey: "theater")
    let event = ExperienceEvent(title: "サンプル公演", seriesName: "東京公演", category: category)

    NavigationStack {
        EventDetailView(event: event)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
