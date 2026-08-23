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
import Combine

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
    var eyecatchData: Data? = nil
    var title = "ページ背景"

    private var presets: [HeroBackgroundPreset] {
        HeroBackgroundPreset.presets(for: categoryKey)
    }

    private var resolvedSelection: String {
        if selection == HeroBackgroundPreset.eventEyecatchKey {
            return selection
        }
        return HeroBackgroundPreset.resolved(categoryKey: categoryKey, storedKey: selection)?.key ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        presetButton(preset)
                    }
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        eyecatchButton(image)
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
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(width: 24, height: 24)
                                .background(TheaterCategoryStyle.lightGold, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
                                }
                                .shadow(color: .black.opacity(0.38), radius: 3, y: 1)
                                .padding(5)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? TheaterCategoryStyle.lightGold : Color.secondary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(preset.title)
                    .font(FavorecoTypography.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? TheaterCategoryStyle.gold : Color.primary)
                    .lineLimit(2)
                    .frame(width: 82, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func eyecatchButton(_ image: UIImage) -> some View {
        let isSelected = selection == HeroBackgroundPreset.eventEyecatchKey
        return Button {
            selection = HeroBackgroundPreset.eventEyecatchKey
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 100)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(width: 24, height: 24)
                                .background(TheaterCategoryStyle.lightGold, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
                                }
                                .shadow(color: .black.opacity(0.38), radius: 3, y: 1)
                                .padding(5)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? TheaterCategoryStyle.lightGold : Color.secondary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("アイキャッチと同じ")
                    .font(FavorecoTypography.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? TheaterCategoryStyle.gold : Color.primary)
                    .lineLimit(2)
                    .frame(width: 82, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    @EnvironmentObject private var createEntryContextRouter: CreateEntryContextRouter
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @State private var isShowingAddVisit = false
    @State private var isShowingAddPlan = false
    @State private var isShowingAddTicketSchedule = false
    @State private var isShowingTheaterPlanChoice = false
    @State private var isShowingEditEvent = false
    @State private var isShowingRepresentativePhotoPicker = false
    @State private var isShowingBookShelfAssignment = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingActionMenu = false
    @State private var selectedPlanID: UUID?
    @State private var actionErrorMessage: String?
    @State private var backSwipeExclusionFrames: [CGRect] = []
    @State private var eyecatchRefreshVersion = 0
    @State private var eyecatchPreviewRequest: DetailEyecatchPreviewRequest?
    @State private var createContextToken = UUID()

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
        let isBook = category?.templateKey == "book"
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
                        visitSnapshot: TheaterTravelMapSnapshot.make(visits: snapshot.visits),
                        schedules: performanceSchedules,
                        accentColor: theaterGold
                    )
                } else if category?.templateKey == "random_goods" {
                    hero(snapshot: snapshot)
                    CollectibleSeriesDashboard(series: event, accentColor: accentColor)
                } else {
                    hero(snapshot: snapshot)
                    if isBook {
                        bookInformationSection
                        bookReadingHistorySection(snapshot: snapshot)
                        bookMemoSection
                    } else {
                        eventMemoSection
                        stats(snapshot: snapshot)
                        visitHistory(snapshot: snapshot)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, isTheater ? 132 : 24)
        }
        .id(eyecatchRefreshVersion)
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
                GeometryReader { proxy in
                    theaterNavigationControls
                        .padding(.top, max(proxy.safeAreaInsets.top, resolvedTopSafeAreaInset) + 8)
                }
                .ignoresSafeArea()
            }
        }
        .toolbar {
            if !isTheater {
                ToolbarItem(placement: .topBarTrailing) {
                    eventMenu
                }
            }
        }
        .favorecoDetailActionMenu(
            isPresented: $isShowingActionMenu,
            genreColor: eventMenuGenreColor,
            accentColor: eventMenuAccentColor,
            topPadding: isTheater ? 126 : 54,
            actions: eventMenuActions
        )
        .navigationDestination(item: $selectedPlanID) { planID in
            EventPlanDestination(planID: planID)
        }
        .sheet(isPresented: $isShowingAddVisit) {
            Group {
                if category?.templateKey == "random_goods" {
                    CollectibleTransactionEditorView(series: event)
                } else {
                    AddVisitView(event: event)
                }
            }
            .favorecoRegistrationTheme(categoryHex: category?.colorHex)
        }
        .sheet(isPresented: $isShowingAddPlan) {
            AddTicketPlanView(event: event, entryMode: .plan)
                .favorecoRegistrationTheme(categoryHex: category?.colorHex)
        }
        .sheet(isPresented: $isShowingAddTicketSchedule) {
            AddTicketPlanView(event: event, entryMode: .ticketSchedule)
                .favorecoRegistrationTheme(categoryHex: category?.colorHex)
        }
        .sheet(isPresented: $isShowingEditEvent) {
            Group {
                if category?.templateKey == "random_goods" {
                    AddCollectibleSeriesView(series: event)
                } else {
                    TheaterLifecycleEditorSheet(interested: event)
                }
            }
            .favorecoRegistrationTheme(categoryHex: category?.colorHex)
        }
        .sheet(isPresented: $isShowingRepresentativePhotoPicker) {
            RepresentativePhotoPicker(event: event)
        }
        .sheet(isPresented: $isShowingBookShelfAssignment) {
            BookShelfAssignmentView(event: event)
        }
        .fullScreenCover(item: $eyecatchPreviewRequest) { request in
            DetailEyecatchPreview(request: request)
        }
        .onAppear {
            guard let categoryID = category?.id else { return }
            createEntryContextRouter.activateDetail(
                categoryID: categoryID,
                token: createContextToken
            )
        }
        .onDisappear {
            createEntryContextRouter.deactivateDetail(token: createContextToken)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ThumbnailLoader.didInvalidateReferenceNotification
            )
        ) { notification in
            guard ThumbnailLoader.invalidation(notification, matches: .event(event.id)) else { return }
            eyecatchRefreshVersion += 1
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
        FavorecoDetailActionMenuButton(
            isPresented: $isShowingActionMenu,
            genreColor: eventMenuGenreColor,
            accentColor: eventMenuAccentColor,
            size: 34
        )
    }

    private var eventMenuActions: [FavorecoDetailAction] {
        var actions = [
            FavorecoDetailAction(
                title: category?.templateKey == "random_goods"
                    ? "シリーズ情報・画像を編集"
                    : "対象情報・画像を編集",
                systemImage: "pencil",
                action: { isShowingEditEvent = true }
            )
        ]

        if category?.templateKey == "book" {
            actions.append(
                FavorecoDetailAction(
                    title: "本棚に追加・変更",
                    systemImage: "books.vertical",
                    action: { isShowingBookShelfAssignment = true }
                )
            )
        }

        if !EventRepresentativePhotoResolver.resolve(
            for: event,
            sortedVisits: (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
        ).photos.isEmpty {
            actions.append(
                FavorecoDetailAction(
                    title: "代表写真を選ぶ",
                    systemImage: "photo.badge.checkmark",
                    action: { isShowingRepresentativePhotoPicker = true }
                )
            )
        }

        actions.append(contentsOf: [
            FavorecoDetailAction(
                title: "対象を非表示",
                systemImage: "archivebox",
                isDestructive: true,
                action: { isShowingArchiveConfirmation = true }
            ),
            FavorecoDetailAction(
                title: "すべての記録を削除",
                systemImage: "trash",
                isDestructive: true,
                action: { isShowingDeleteConfirmation = true }
            )
        ])
        return actions
    }

    private var eventMenuGenreColor: Color {
        Color(hex: category?.colorHex ?? "#6F8F7A")
    }

    private var eventMenuAccentColor: Color {
        guard category?.templateKey != "theater" else { return theaterGold }
        let hex = themePalette.resolvedHex(categoryHex: category?.colorHex ?? "#6F8F7A")
        return Color.legibleDetailAccent(hex: hex)
    }

    /// The immersive theater page deliberately ignores the top safe area. Depending on the
    /// presentation route and first-render timing, both the overlay GeometryReader and key
    /// window can consequently report zero insets. Resolve every available UIKit value and
    /// retain a device-class minimum so the controls never enter the status bar / Dynamic
    /// Island region while those values are unavailable.
    private var resolvedTopSafeAreaInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowInset = scenes
            .flatMap(\.windows)
            .map(\.safeAreaInsets.top)
            .max() ?? 0
        let statusBarHeight = scenes
            .compactMap { $0.statusBarManager?.statusBarFrame.height }
            .max() ?? 0
        let minimumInset: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 54 : 24

        return max(max(windowInset, statusBarHeight), minimumInset)
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

            FavorecoDetailActionMenuButton(
                isPresented: $isShowingActionMenu,
                genreColor: eventMenuGenreColor,
                accentColor: eventMenuAccentColor
            )
        }
        .padding(.horizontal, 20)
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

            Text("公演情報")
                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.88))
                .tracking(0.8)
                .accessibilityAddTraits(.isHeader)

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

            HStack(spacing: 10) {
                theaterPlanButton
                theaterVisitButton
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
        let removesBackground = fields.heroBackgroundPresetKey == HeroBackgroundPreset.noneKey
        let usesEventEyecatch = fields.heroBackgroundPresetKey == HeroBackgroundPreset.eventEyecatchKey
        let resourceName = removesBackground
            ? ""
            : HeroBackgroundPreset.resolved(
                categoryKey: "theater",
                storedKey: fields.heroBackgroundPresetKey
            )?.resourceName ?? "theater-hero-venue-v2"
        if usesEventEyecatch,
           let data = event.eyecatchData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if !removesBackground,
           let image = bundledHeroBackgroundImage(resourceName: resourceName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(red: 0.18, green: 0.02, blue: 0.04)
        }
    }

    @ViewBuilder
    private func theaterPoster(snapshot: EventDetailSnapshot) -> some View {
        TheaterPosterArtwork(
            reference: .event(event.id),
            backgroundColor: .black.opacity(0.42)
        ) { size in
            if let photo = snapshot.representativePhoto {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 900, contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else {
                FavorecoIcon(systemName: "theatermasks.fill", size: 54)
                    .foregroundStyle(theaterGold.opacity(0.8))
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: 148, height: 209)
        .theaterPosterFrame(tint: theaterGold)
        .id(event.updatedAt)
        .contentShape(Rectangle())
        .onTapGesture {
            eyecatchPreviewRequest = DetailEyecatchPreviewRequest(reference: .event(event.id))
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("アイキャッチを拡大表示します")
    }

    private var theaterPlanButton: some View {
        Button(action: openPlanEntry) {
            FavorecoIconLabel("予定を立てる", systemImage: "calendar.badge.plus", iconSize: 17)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 36)
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
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 36)
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

        HStack(spacing: 6) {
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
                .frame(width: 36, height: 36)
                .accessibilityLabel(platform.displayName)
                .accessibilityValue(url == nil ? "未登録" : "登録済み")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
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
                .background(.black.opacity(url == nil ? 0.16 : 0.24), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            url == nil
                                ? Color.white.opacity(0.18)
                                : theaterGold.opacity(0.42),
                            lineWidth: 0.7
                        )
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(url == nil ? Color.white.opacity(0.52) : theaterGold)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        eyecatchPreviewRequest = DetailEyecatchPreviewRequest(
                            reference: .photo(representativePhoto.id)
                        )
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("アイキャッチを拡大表示します")
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        eyecatchPreviewRequest = DetailEyecatchPreviewRequest(
                            reference: .event(event.id)
                        )
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("アイキャッチを拡大表示します")
            }

            HStack(alignment: .top, spacing: category?.templateKey == "book" ? 0 : 14) {
                if category?.templateKey != "book" {
                    FavorecoIcon(systemName: category?.iconSymbol ?? "rectangle.stack", size: 22)
                        .foregroundStyle(accentColor)
                        .frame(width: 44, height: 44)
                        .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.eventTitle)
                        .font(
                            FavorecoTypography.jpSerif(
                                category?.templateKey == "book" ? 22 : 26,
                                weight: .bold,
                                relativeTo: category?.templateKey == "book" ? .title3 : .title2
                            )
                        )
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

            if category?.templateKey == "book" {
                if !event.bookSeriesName.isEmpty {
                    FavorecoIconLabel(
                        "シリーズ  \(event.bookSeriesName)",
                        systemImage: "books.vertical",
                        iconSize: 17
                    )
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                }

                if !event.sortedBookShelfNames.isEmpty {
                    FavorecoIconLabel(
                        "本棚  \(event.sortedBookShelfNames.joined(separator: "・"))",
                        systemImage: "rectangle.stack.fill",
                        iconSize: 17
                    )
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("本棚 \(event.sortedBookShelfNames.joined(separator: "、"))")
                }
            } else if !event.seriesName.isEmpty {
                FavorecoIconLabel(event.seriesName, systemImage: "rectangle.stack", iconSize: 17)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            detailPrimaryActions(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func detailPrimaryActions(snapshot: EventDetailSnapshot) -> some View {
        if category?.templateKey == "book" {
            Button {
                isShowingAddVisit = true
            } label: {
                FavorecoIconLabel("読書を記録", systemImage: "book.closed", iconSize: 17)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        } else {
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
    }

    private var bookInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本の情報")
                .font(FavorecoTypography.sectionTitle)

            EventBookInfoRow(icon: "text.book.closed", title: "書名", value: event.title)
            if !event.bookSeriesName.isEmpty {
                EventBookInfoRow(icon: "books.vertical", title: "シリーズ", value: event.bookSeriesName)
            }
            if !event.bookVolumeLabel.isEmpty {
                EventBookInfoRow(icon: "number", title: "巻数", value: event.bookVolumeLabel)
            }
            if !event.bookAuthorName.isEmpty {
                EventBookInfoRow(icon: "person.text.rectangle", title: "著者", value: event.bookAuthorName)
            }
            if !event.bookTranslatorName.isEmpty {
                EventBookInfoRow(icon: "character.book.closed", title: "訳者", value: event.bookTranslatorName)
            }
            if !event.bookPublisherName.isEmpty {
                EventBookInfoRow(icon: "building.2", title: "出版社", value: event.bookPublisherName)
            }
            if !event.bookPublishedDate.isEmpty {
                EventBookInfoRow(icon: "calendar.badge.clock", title: "発行日", value: event.bookPublishedDate)
            }
            if !event.bookISBN.isEmpty {
                EventBookInfoRow(icon: "barcode", title: "ISBN", value: event.bookISBN)
            }
            if !event.bookPriceText.isEmpty {
                EventBookInfoRow(icon: "yensign.circle", title: "価格", value: event.bookPriceText)
            }
            if event.bookPageCount > 0 {
                EventBookInfoRow(icon: "doc.text", title: "ページ数", value: "\(event.bookPageCount)ページ")
            }
            if !event.bookContentTypeKey.isEmpty {
                EventBookInfoRow(
                    icon: "books.vertical",
                    title: "本の種類",
                    value: BookContentType.displayName(for: event.bookContentTypeKey)
                )
            }
            EventBookInfoRow(
                icon: "rectangle.portrait",
                title: "本の判型",
                value: EyecatchAspectRatio.resolved(for: event).name
            )
            if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
                Link(destination: url) {
                    EventBookInfoRow(icon: "link", title: "公式URL", value: event.officialURL)
                }
                .buttonStyle(.plain)
            }
            if !event.bookInformationSourceName.isEmpty {
                if let url = URL(string: event.bookInformationSourceURL),
                   !event.bookInformationSourceURL.isEmpty {
                    Link(destination: url) {
                        EventBookInfoRow(
                            icon: "info.circle",
                            title: "情報元",
                            value: event.bookInformationSourceName
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    EventBookInfoRow(
                        icon: "info.circle",
                        title: "情報元",
                        value: event.bookInformationSourceName
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bookReadingHistorySection(snapshot: EventDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("読書記録")
                    .font(FavorecoTypography.sectionTitle)
                Text("\(snapshot.visitCount)回")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if snapshot.visits.isEmpty {
                Text("読書記録はまだありません")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(snapshot.visits) { readingRecord in
                    NavigationLink {
                        ExperienceDetailView(visit: readingRecord)
                    } label: {
                        VisitSummaryRow(visit: readingRecord, showsCategory: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var bookMemoSection: some View {
        if !event.memo.isEmpty || !event.importMemo.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("本のメモ")
                    .font(FavorecoTypography.sectionTitle)
                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !event.importMemo.isEmpty {
                    if !event.memo.isEmpty { Divider() }
                    Text(event.importMemo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
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

private struct EventBookInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            FavorecoIcon(systemName: icon, size: 16)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
    let usesTheaterLifecycleLayout: Bool

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
    @State private var artworkCropDraft: ArtworkPhotoCropDraft?

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    private var isPerformanceEvent: Bool {
        ["theater", "live"].contains(event.category?.templateKey ?? "")
    }

    private var isLiveEvent: Bool { event.category?.templateKey == "live" }

    init(event: ExperienceEvent, usesTheaterLifecycleLayout: Bool = false) {
        self.event = event
        self.usesTheaterLifecycleLayout = usesTheaterLifecycleLayout
        _draft = State(initialValue: EventDraft(event: event))
        _eyecatchData = State(initialValue: event.eyecatchData)
    }

    private var editEventTitle: String {
        isPerformanceEvent
            ? (isLiveEvent ? "ライブ情報を編集" : TheaterUnifiedFormEntry.performanceEditing.navigationTitle)
            : "対象を編集"
    }

    @ViewBuilder
    private var theaterLifecycleEventContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            lifecycleSectionHeader(
                "作品・公演",
                info: "ここでは公演そのものの情報を編集します。観劇日・チケット・評価・感想は、予定または観劇記録で入力します。"
            )
            lifecycleTextField("公演名", required: true, prompt: "公演・イベント名を入力", text: $draft.title)
            lifecycleMenuField(
                "公演種別",
                required: true,
                value: TheaterPerformanceType.displayName(
                    for: draft.subTypeKey,
                    customName: draft.performanceTypeCustomName
                )
            ) {
                ForEach(TheaterPerformanceType.allCases) { type in
                    Button(type.displayName) { draft.subTypeKey = type.rawValue }
                }
            }
            if draft.subTypeKey == TheaterPerformanceType.other.rawValue {
                lifecycleTextField(
                    "その他の種別",
                    prompt: "例：能、狂言、朗読劇",
                    text: $draft.performanceTypeCustomName
                )
            }
            lifecycleTextField(
                "シリーズ・ツアー名",
                prompt: "例：冬の庭 2026",
                text: $draft.seriesName,
                info: "同じ作品の連続公演・再演・ツアーをまとめる名前です。"
            )
            lifecycleTextField("公演団体", prompt: "劇団・制作団体・主催者", text: $draft.creditsText)
            lifecycleTextField("サブタイトル", prompt: "東京公演限定版", text: $draft.eventSubtitle)
            lifecycleTextField("公式サイト", prompt: "https://", text: $draft.officialURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            lifecycleTextField("チケットサイト", prompt: "https://", text: $draft.ticketURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            TheaterSocialLinksEditor(
                xURL: $draft.xURL,
                instagramURL: $draft.instagramURL,
                threadsURL: $draft.threadsURL
            )
        }

        VStack(alignment: .leading, spacing: 13) {
            lifecycleSectionHeader(
                "アイキャッチ・背景",
                info: "背景は公演ページと、記録写真がない観劇記録の代表表示に使います。"
            )
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(.secondarySystemFill)
                            Text("No Image")
                                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 104, height: 146)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()

                VStack(spacing: 10) {
                    PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                        FavorecoIconLabel(
                            eyecatchData == nil ? "アイキャッチを選ぶ" : "アイキャッチを変更",
                            systemImage: "photo",
                            iconSize: 14
                        )
                        .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(Color(hex: "#8B2F45"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.secondary.opacity(0.24), lineWidth: 1))
                    }
                    .disabled(isProcessingEyecatch)
                    .onChange(of: selectedEyecatchItem) { _, item in
                        guard let item else { return }
                        Task { await loadEyecatch(from: item) }
                    }

                    if eyecatchData != nil {
                        Button {
                            isConfirmingEyecatchRemoval = true
                        } label: {
                            FavorecoIconLabel("アイキャッチを外す", systemImage: "trash", iconSize: 13)
                                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(Color(hex: "#8B2F45"))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            EventHeroBackgroundPicker(
                categoryKey: "theater",
                selection: $draft.heroBackgroundPresetKey,
                eyecatchData: eyecatchData,
                title: "背景"
            )
        }

        VStack(alignment: .leading, spacing: 13) {
            lifecycleSectionHeader(
                "公演期間・公演会場",
                info: "東京公演・大阪公演など、公演地ごとに期間と会場を複数追加できます。"
            )
            ForEach($draft.venueEntries) { $venue in
                ZStack(alignment: .topTrailing) {
                    TheaterScheduleEntryEditor(
                        entry: $venue,
                        fallbackStart: draft.performanceStartsAt,
                        fallbackEnd: draft.performanceEndsAt,
                        usesFlatLayout: true
                    )
                    Button {
                        draft.venueEntries.removeAll { $0.id == venue.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.systemBackground), in: Circle())
                            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                    .accessibilityLabel("この公演地を削除")
                }
            }

            Button {
                let usesLegacySharedPeriod = draft.venueEntries.isEmpty && draft.hasPerformancePeriod
                draft.venueEntries.append(
                    EventVenueEntry(
                        startsAt: usesLegacySharedPeriod ? draft.performanceStartsAt : nil,
                        endsAt: usesLegacySharedPeriod ? draft.performanceEndsAt : nil
                    )
                )
            } label: {
                FavorecoIconLabel("公演地を追加", systemImage: "plus.circle", iconSize: 14)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Color(hex: "#8B2F45"))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: "#8B2F45").opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 13) {
            lifecycleSectionHeader(
                "キャスト・スタッフ",
                info: "公式サイトやパンフレットから、画像OCR・テキスト貼付け・直接入力でまとめて登録できます。"
            )
            TheaterEventCreditsEditor(
                bulkText: $draft.creditsText,
                existingLinks: visibleEventCreditLinks,
                deletedLinkIDs: $deletedPersonLinkIDs,
                pendingLinks: $pendingPeople,
                personMasters: personMasters,
                showsHeader: false
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            lifecycleDisclosureHeader("感想・メモ", isExpanded: $showingPerformanceDetails)
            if showingPerformanceDetails {
                lifecycleMemoField(
                    prompt: "気になった理由、公演そのものについて残しておくこと",
                    text: $draft.memo
                )
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: showingPerformanceDetails)

        VStack(alignment: .leading, spacing: 12) {
            lifecycleDisclosureHeader("その他", isExpanded: $showingImportDetails)
            if showingImportDetails {
                lifecycleMemoField(prompt: "URL・OCRから取得した原文", text: $draft.importMemo)
            }
        }
        .theaterLifecycleDisclosureSurface(isExpanded: showingImportDetails)
    }

    private func lifecycleSectionHeader(_ title: String, info: String? = nil) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: "#8B2F45"))
                .frame(width: 4, height: 24)
            Text(title)
                .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(.primary)
            if let info {
                TheaterLifecycleInfoButton(text: info)
            }
            Spacer(minLength: 0)
        }
    }

    private func lifecycleDisclosureHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 10) {
                lifecycleSectionHeader(title)
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func lifecycleFieldLabel(
        _ title: String,
        required: Bool,
        info: String? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
            Text(required ? "* 必須" : "任意")
                .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(required ? Color(hex: "#8B2F45") : .secondary)
            if let info {
                TheaterLifecycleInfoButton(text: info)
            }
        }
    }

    private func lifecycleTextField(
        _ title: String,
        required: Bool = false,
        prompt: String,
        text: Binding<String>,
        info: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lifecycleFieldLabel(title, required: required, info: info)
            TextField(prompt, text: text)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
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

    private func lifecycleMenuField<Items: View>(
        _ title: String,
        required: Bool = false,
        value: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lifecycleFieldLabel(title, required: required)
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
                .frame(minHeight: 52)
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

    private func lifecycleMemoField(prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text, axis: .vertical)
            .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
            .lineLimit(4...6)
            .padding(12)
            .frame(minHeight: 104, alignment: .topLeading)
            .background(
                TheaterLifecycleFlatStyle.fieldBackground,
                in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            )
    }

    var body: some View {
        NavigationStack {
            TheaterLifecycleEditorCanvas(
                usesFlatLayout: usesTheaterLifecycleLayout && isPerformanceEvent && !isLiveEvent,
                title: editEventTitle,
                canSave: draft.canSave && !isProcessingEyecatch,
                onClose: { dismiss() },
                onSave: save
            ) {
                if usesTheaterLifecycleLayout && isPerformanceEvent && !isLiveEvent {
                    theaterLifecycleEventContent
                } else {
                if usesTheaterLifecycleLayout && isPerformanceEvent && !isLiveEvent {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8B2F45"))
                            .padding(.top, 2)
                        Text("この画面は公演そのものの情報を編集します。個別の観劇日・チケット・評価・感想は、予定または観劇記録で入力します。")
                            .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .body))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#8B2F45").opacity(0.2), lineWidth: 1)
                    )
                }
                if isPerformanceEvent, !usesTheaterLifecycleLayout {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .performanceEditing, isLive: isLiveEvent)
                    }
                }
                Section {
                    let photoActionTitle = eyecatchData == nil ? "写真を選ぶ" : "写真を変更"
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        if isPerformanceEvent {
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    presentArtworkCrop(image)
                                }
                            Button {
                                presentArtworkCrop(image)
                            } label: {
                                FavorecoIconLabel(
                                    "位置とサイズを調整",
                                    systemImage: "crop",
                                    iconSize: 16
                                )
                            }
                            Button("画像を外す", role: .destructive) {
                                self.eyecatchData = nil
                            }
                        }
                    } else if isPerformanceEvent {
                        theaterVisualPlaceholder
                    }

                    if isPerformanceEvent {
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

                    if isPerformanceEvent {
                        EventHeroBackgroundPicker(
                            categoryKey: isLiveEvent ? "live" : "theater",
                            selection: $draft.heroBackgroundPresetKey,
                            eyecatchData: eyecatchData
                        )
                    }
                } header: {
                    if isPerformanceEvent {
                        FavorecoRegistrationSectionHeader("公演ビジュアル")
                    } else {
                        FavorecoRegistrationSectionHeader("対象アイキャッチ")
                    }
                } footer: {
                    Text(
                        isPerformanceEvent
                            ? "公演ページや、記録写真がない観劇記録の代表画像として表示します。"
                            : "クイック登録の表紙や、記録写真がない対象の代表画像として表示します。"
                    )
                }

                Section {
                    if isPerformanceEvent {
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
                            if isLiveEvent {
                                LivePerformanceTypePicker(
                                    selection: $draft.subTypeKey,
                                    customName: $draft.performanceTypeCustomName
                                )
                            } else {
                                TheaterPerformanceTypePicker(
                                    selection: $draft.subTypeKey,
                                    customName: $draft.performanceTypeCustomName,
                                    usesCompactLabelStyle: true
                                )
                            }
                            ExplicitFormTextField(
                                title: isLiveEvent ? "アーティスト（任意）" : "主催（任意）",
                                prompt: isLiveEvent ? "出演アーティスト名" : "主催・制作団体",
                                text: $draft.creditsText,
                                axis: .vertical,
                                minimumLines: 1,
                                maximumLines: 3,
                                labelStyle: .horizontal
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
                            TheaterUnifiedSectionLabel(section: .performanceBasic, isLive: isLiveEvent)
                        }
                    } else if event.category?.templateKey == "movie" {
                        VStack(alignment: .leading, spacing: 0) {
                            ScreenWorkTypeAndSeasonEditor(
                                typeKey: $draft.subTypeKey,
                                seasonNumber: $draft.screenWorkSeasonNumber
                            )
                            explicitFieldDivider
                            ExplicitFormTextField(
                                title: "作品名（必須）",
                                prompt: template.titlePlaceholder,
                                text: $draft.title,
                                axis: .vertical,
                                minimumLines: 1,
                                maximumLines: 2,
                                labelStyle: .horizontal
                            )
                        }
                    } else if event.category?.templateKey == "book" {
                        BookInformationEditor(
                            title: $draft.title,
                            seriesName: $draft.bookSeriesName,
                            volumeNumber: $draft.bookVolumeNumber,
                            authorName: $draft.bookAuthorName,
                            translatorName: $draft.bookTranslatorName,
                            isbn: $draft.bookISBN,
                            publisherName: $draft.bookPublisherName,
                            publishedDate: $draft.bookPublishedDate,
                            priceText: $draft.bookPriceText,
                            pageCountText: $draft.bookPageCountText,
                            officialURL: $draft.officialURL,
                            contentTypeKey: $draft.bookContentTypeKey,
                            aspectRatioKey: $draft.eyecatchAspectRatioKey,
                            isEditable: true
                        )
                    } else {
                        ExplicitFormTextField(
                            title: "\(template.titlePlaceholder)（必須）",
                            prompt: "\(template.titlePlaceholder)を入力",
                            text: $draft.title,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )
                        explicitFieldDivider
                        ExplicitFormTextField(
                            title: template.seriesPlaceholder,
                            prompt: template.seriesPlaceholder,
                            text: $draft.seriesName,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )
                        explicitFieldDivider
                        ExplicitFormTextField(
                            title: "サブタイトル（任意）",
                            prompt: "サブタイトルを入力",
                            text: $draft.eventSubtitle,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 2,
                            labelStyle: .horizontal
                        )
                        explicitFieldDivider
                        ExplicitFormTextField(
                            title: "公式URL（任意）",
                            prompt: "https://example.com",
                            text: $draft.officialURL,
                            labelStyle: .horizontal
                        )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        explicitFieldDivider
                        ExplicitFormTextField(
                            title: "SNSリンク（任意）",
                            prompt: "1行に1件ずつ入力",
                            text: $draft.socialLinksText,
                            axis: .vertical,
                            minimumLines: 2,
                            maximumLines: 5,
                            labelStyle: .horizontal
                        )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                } header: {
                    if !isPerformanceEvent {
                        FavorecoRegistrationSectionHeader(template.targetSectionTitle)
                    }
                }

                if isPerformanceEvent {
                    Section {
                        ForEach($draft.venueEntries) { $venue in
                            if usesTheaterLifecycleLayout && !isLiveEvent {
                                ZStack(alignment: .topTrailing) {
                                    TheaterScheduleEntryEditor(
                                        entry: $venue,
                                        fallbackStart: draft.performanceStartsAt,
                                        fallbackEnd: draft.performanceEndsAt,
                                        usesFlatLayout: true
                                    )
                                    Button {
                                        draft.venueEntries.removeAll { $0.id == venue.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 30, height: 30)
                                            .background(Color(.systemBackground), in: Circle())
                                            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .accessibilityLabel("この公演地を削除")
                                }
                            } else {
                                TheaterScheduleEntryEditor(
                                    entry: $venue,
                                    fallbackStart: draft.performanceStartsAt,
                                    fallbackEnd: draft.performanceEndsAt
                                )
                            }
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
                                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(Color(hex: "#8B2F45"))
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#8B2F45").opacity(0.55), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } header: {
                        if usesTheaterLifecycleLayout && !isLiveEvent {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(hex: "#8B2F45"))
                                    .frame(width: 4, height: 28)
                                Text("公演期間・公演会場")
                                    .font(FavorecoTypography.jpSans(19, weight: .semibold, relativeTo: .headline))
                                    .foregroundStyle(.primary)
                            }
                            .textCase(nil)
                        } else {
                            TheaterUnifiedSectionLabel(section: .venueSchedule, isLive: isLiveEvent)
                        }
                    } footer: {
                        Text("公演全体の開催期間と会場です。東京公演・大阪公演など、公演地ごとに複数追加できます。個別の観劇日やチケットはここでは入力しません。")
                    }
                }

                if isPerformanceEvent {
                    Section {
                        TheaterEventCreditsEditor(
                            bulkText: $draft.creditsText,
                            existingLinks: visibleEventCreditLinks,
                            deletedLinkIDs: $deletedPersonLinkIDs,
                            pendingLinks: $pendingPeople,
                            personMasters: personMasters
                        )
                    }

                    Section {
                        DisclosureGroup(isExpanded: $showingPerformanceDetails) {
                            ExplicitFormTextField(
                                title: "公演メモ（任意）",
                                prompt: "あらすじ・公演そのものについてのメモ",
                                text: $draft.memo,
                                axis: .vertical,
                                minimumLines: 5,
                                maximumLines: 5,
                                labelStyle: .horizontal,
                                reservesLineSpace: true
                            )
                        } label: {
                            TheaterUnifiedSectionLabel(section: .performanceDetails, isLive: isLiveEvent)
                        }
                    }
                } else {
                    FavorecoRegistrationSection("対象メモ") {
                        ExplicitFormTextField(
                            title: "メモ（任意）",
                            prompt: "対象そのものについて残しておきたいこと",
                            text: $draft.memo,
                            axis: .vertical,
                            minimumLines: 5,
                            maximumLines: 5,
                            labelStyle: .horizontal,
                            reservesLineSpace: true,
                            showsInputBoundary: true
                        )
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showingImportDetails) {
                        ExplicitFormTextField(
                            title: "読み取り原文（任意）",
                            prompt: "URL・OCRから取得した原文",
                            text: $draft.importMemo,
                            axis: .vertical,
                            minimumLines: 6,
                            maximumLines: 6,
                            labelStyle: .horizontal,
                            reservesLineSpace: true,
                            showsInputBoundary: true
                        )
                    } label: {
                        TheaterUnifiedSectionLabel(section: .importDetails, isLive: isLiveEvent)
                    }
                }
                }
            }
            .favorecoRegistrationFormCanvas(
                isEnabled: !(usesTheaterLifecycleLayout && isPerformanceEvent && !isLiveEvent)
            )
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .navigationTitle(editEventTitle)
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
            .fullScreenCover(item: $artworkCropDraft) { cropDraft in
                ArtworkImageCropView(
                    image: cropDraft.image,
                    aspectRatio: cropDraft.aspectRatio
                ) { adjustedData in
                    eyecatchData = adjustedData
                }
            }
        }
    }

    private var explicitFieldDivider: some View {
        Divider().overlay(ExplicitFormMetrics.rowSeparatorColor)
    }

    private func presentArtworkCrop(_ image: UIImage) {
        guard !isPerformanceEvent else { return }
        artworkCropDraft = ArtworkPhotoCropDraft(
            image: image,
            aspectRatio: CGFloat(selectedEyecatchAspectRatio.value)
        )
    }

    @MainActor
    private func loadEyecatch(from item: PhotosPickerItem) async {
        isProcessingEyecatch = true
        defer {
            isProcessingEyecatch = false
            selectedEyecatchItem = nil
        }
        guard let sourceData = try? await item.loadTransferable(type: Data.self),
              let compressed = await Task.detached(priority: .userInitiated, operation: {
                  QuickCaptureImageService.compressedJPEG(from: sourceData)
              }).value else {
            saveErrorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed
    }

    @ViewBuilder
    private func eyecatchPreview(_ image: UIImage) -> some View {
        if isPerformanceEvent {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 212)
                .background(Color(.secondarySystemBackground))
                .theaterPosterFrame(tint: TheaterCategoryStyle.gold)
        } else if EyecatchAspectRatio.usesEyecatchFill(for: event.category) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(selectedEyecatchAspectRatio.value), contentMode: .fit)
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
        if event.category?.templateKey == "book" {
            event.applyBookMetadata(
                seriesName: draft.trimmedBookSeriesName,
                volumeNumber: draft.trimmedBookVolumeNumber,
                authorName: draft.trimmedBookAuthorName,
                translatorName: draft.trimmedBookTranslatorName,
                isbn: draft.trimmedBookISBN,
                publisherName: draft.trimmedBookPublisherName,
                publishedDate: draft.trimmedBookPublishedDate,
                priceText: draft.trimmedBookPriceText,
                pageCount: draft.bookPageCount
            )
        } else {
            event.seriesName = draft.trimmedSeriesName
        }
        if isPerformanceEvent {
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
        unitFields.eventTicketURL = draft.trimmedTicketURL
        unitFields.eventPerformanceTypeCustomName = isLiveEvent
            ? LivePerformanceType.customNameForStorage(key: draft.subTypeKey, input: draft.performanceTypeCustomName)
            : TheaterPerformanceType.customNameForStorage(key: draft.subTypeKey, input: draft.performanceTypeCustomName)
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
        let didChangeEyecatch = event.eyecatchData != eyecatchData
        event.eyecatchData = eyecatchData
        if event.category?.templateKey == "book" {
            unitFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
            unitFields.bookContentTypeKey = draft.bookContentTypeKey
            unitFields.bookSeriesName = draft.trimmedBookSeriesName
            unitFields.bookVolumeNumber = draft.trimmedBookVolumeNumber
            unitFields.bookAuthorName = draft.trimmedBookAuthorName
            unitFields.bookTranslatorName = draft.trimmedBookTranslatorName
            unitFields.bookISBN = draft.trimmedBookISBN
            unitFields.bookPublisherName = draft.trimmedBookPublisherName
            unitFields.bookPublishedDate = draft.trimmedBookPublishedDate
            unitFields.bookPriceText = draft.trimmedBookPriceText
            unitFields.bookPageCount = draft.bookPageCount
        }
        event.unitFieldsRaw = unitFields.encodedRawValue
        event.updatedAt = now
        deleteMarkedPersonLinks()
        insertPendingPeople()

        do {
            try modelContext.save()
            if didChangeEyecatch {
                ThumbnailLoader.purge(reference: .event(event.id))
            }
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "対象情報を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to update event: \(error)")
        }
    }

    private var visibleEventCreditLinks: [EventPersonLink] {
        let roleKeys = Set(PersonRoleOption.theaterEvent.map(\.key))
        return (event.personLinks ?? [])
            .filter {
                !$0.isArchived
                    && !deletedPersonLinkIDs.contains($0.id)
                    && $0.visit == nil
                    && roleKeys.contains($0.roleKey)
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

}

private struct EventDraft {
    var title: String
    var seriesName: String
    var bookSeriesName: String
    var bookVolumeNumber: String
    var bookAuthorName: String
    var bookTranslatorName: String
    var bookISBN: String
    var bookPublisherName: String
    var bookPublishedDate: String
    var bookPriceText: String
    var bookPageCountText: String
    var bookContentTypeKey: String
    var subTypeKey: String
    var screenWorkSeasonNumber: Int
    var performanceTypeCustomName: String
    var officialURL: String
    var ticketURL: String
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
        ticketURL = fields.eventTicketURL
        bookSeriesName = fields.bookSeriesName
        bookVolumeNumber = fields.bookVolumeNumber
        bookAuthorName = fields.bookAuthorName
        bookTranslatorName = fields.bookTranslatorName
        bookISBN = fields.bookISBN
        bookPublisherName = fields.bookPublisherName
        bookPublishedDate = fields.bookPublishedDate
        bookPriceText = fields.bookPriceText
        bookPageCountText = fields.bookPageCount > 0 ? String(fields.bookPageCount) : ""
        bookContentTypeKey = fields.bookContentTypeKey
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
        usesPlatformSocialLinks = ["theater", "live"].contains(event.category?.templateKey ?? "")
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

    var trimmedBookSeriesName: String {
        bookSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookVolumeNumber: String {
        bookVolumeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookAuthorName: String {
        bookAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookTranslatorName: String {
        bookTranslatorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookISBN: String {
        bookISBN.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublisherName: String {
        bookPublisherName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublishedDate: String {
        bookPublishedDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPriceText: String {
        bookPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPageCount: Int {
        max(Int(bookPageCountText.filter(\.isNumber)) ?? 0, 0)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTicketURL: String {
        ticketURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
    .environmentObject(CreateEntryContextRouter())
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
