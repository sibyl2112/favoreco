//
//  CategoryTopView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit
import MapKit

enum CategoryPlanningHeroPolicy {
    static let supportedTemplateKeys: Set<String> = [
        "movie",
        "live",
        "museum",
        "theme_park",
        "nature_living",
    ]

    static func supports(_ templateKey: String) -> Bool {
        supportedTemplateKeys.contains(templateKey)
    }
}

@MainActor
private final class CategoryTopResolutionCache {
    private var visitIDs: [UUID] = []
    private var visits: [Visit] = []
    private var categoryID: UUID?
    private var eventIDs: [UUID] = []
    private var events: [ExperienceEvent] = []
    private var eventsByID: [UUID: ExperienceEvent] = [:]

    func resolvedVisits(snapshot: CategoryTopSnapshot, allVisits: [Visit]) -> [Visit] {
        guard visitIDs != snapshot.visitIDs else { return visits }
        let idSet = Set(snapshot.visitIDs)
        visitIDs = snapshot.visitIDs
        visits = allVisits.filter { idSet.contains($0.id) }
        return visits
    }

    func resolvedEvents(
        snapshot: CategoryTopSnapshot,
        category: RecordCategory
    ) -> [ExperienceEvent] {
        let nextEventIDs = snapshot.events.map(\.id)
        guard categoryID != category.id || eventIDs != nextEventIDs else { return events }
        let categoryEventsByID = Dictionary(
            (category.events ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        categoryID = category.id
        eventIDs = nextEventIDs
        events = nextEventIDs.compactMap { categoryEventsByID[$0] }
        eventsByID = Dictionary(
            events.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        return events
    }

    func resolvedEventsByID(
        snapshot: CategoryTopSnapshot,
        category: RecordCategory
    ) -> [UUID: ExperienceEvent] {
        _ = resolvedEvents(snapshot: snapshot, category: category)
        return eventsByID
    }
}

struct CategoryTopView: View {
    let category: RecordCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var createEntryContextRouter: CreateEntryContextRouter
    @Query(sort: \RecordCategory.sortOrder) private var allCategories: [RecordCategory]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @Query(sort: \Plan.startsAt, order: .forward) private var allPlans: [Plan]
    @Query(sort: \PlaceMaster.name) private var allPlaceMasters: [PlaceMaster]
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @AppStorage(AppStorageKeys.theaterPerformanceLogLayoutMode)
    private var theaterPerformanceLogLayoutRaw = TheaterPerformanceLogLayoutMode.banner.rawValue
    @State private var isShowingAddExperience = false
    @State private var isShowingTheaterPerformanceRegistration = false
    @State private var selectedEventForNewVisit: ExperienceEvent?
    @State private var selectedCategoryID: UUID
    @State private var goshuinFilter: GoshuinVisitFilter = .all
    @State private var goshuinMapFilter: GoshuinVisitFilter = .all
    @State private var goshuinListLimit = 10
    @State private var selectedGoshuinPrefecture = ""
    @State private var isShowingGoshuinSearch = false
    @State private var selectedGoshuinBook: GoshuinBookSelection?
    @State private var goshuinShareImage: UIImage?
    @State private var isShowingGoshuinShare = false
    @State private var goshuinShareLocked = false
    @State private var selectedFeatureCarouselIndex = 0
    @State private var selectedGoshuinHeroIndex = 0
    @State private var libraryLayoutModes: [String: CategoryLibraryLayoutMode]
    @State private var screenWorkFilter: ScreenWorkFilter = .all
    @State private var isShowingAllUpcomingPlans = false
    @State private var isShowingAllTheaterTicketManagementPlans = false
    @State private var isShowingAllTheaterVisits = false
    @State private var isShowingArchivedTheaterEvents = false
    @State private var isShowingCategorySettings = false
    @State private var selectedCategoryDetail: CategoryDetailPanelSelection?
    @State private var selectedCategoryEventID: UUID?
    @State private var selectedBookSeries: BookSeriesRoute?
    @State private var selectedPlaceDetail: PlaceExperienceDetailSelection?
    @State private var isShowingTheaterTicketOverview = false
    @State private var ticketDetailsPromptAttempt: TicketAttempt?
    @State private var ticketDetailsEditAttempt: TicketAttempt?
    @State private var ticketStatusUpdateError = ""
    @State private var resolutionCache = CategoryTopResolutionCache()

    init(category: RecordCategory) {
        self.category = category
        _selectedCategoryID = State(initialValue: category.id)
        _libraryLayoutModes = State(initialValue: [
            category.templateKey: CategoryLibraryLayoutMode.stored(for: category.templateKey)
        ])
    }

    var body: some View {
        let activeCategory = currentCategory
        let recordTemplate = CategoryRecordTemplate.template(for: activeCategory)
        let snapshot = CategoryTopSnapshot.make(
            category: activeCategory,
            categories: allCategories,
            visits: allVisits
        )

        VStack(spacing: 0) {
            MainScreenHeader(
                title: "Favoreco",
                usesBrandFont: true,
                centeredTitle: categoryDisplayName(activeCategory),
                usesCompactBrand: true,
                brandGradient: categoryBrandGradient(activeCategory),
                headerForegroundColor: categoryHeaderForeground(activeCategory),
                onLeadingTap: { dismiss() },
                showsTicketManagement: true
            )
            .padding(.horizontal, 20)
            .padding(.top, -4)
            .padding(.bottom, 6)

            GenreNavigationStrip(
                categories: visibleCategories,
                selectedCategoryID: activeCategory.id,
                onSelectAll: { dismiss() },
                onSelectCategory: { selectedCategory in
                    switchCategory(to: selectedCategory)
                }
            )
            .padding(.horizontal, 18)

            MainHeaderDivider(
                tint: categoryAccent(activeCategory)
            )

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear
                            .frame(height: 0)
                            .id(CategoryScrollAnchor.top)

                        VStack(alignment: .leading, spacing: 24) {
                            if activeCategory.templateKey == "movie" {
                                ScreenWorkFilterBar(
                                    selection: $screenWorkFilter,
                                    tint: categoryAccent(activeCategory)
                                )
                            }

                            Group {
                                if activeCategory.templateKey == "goshuin" {
                                    goshuinHero(category: activeCategory, snapshot: snapshot)
                                } else if activeCategory.templateKey == "random_goods" {
                                    collectibleHero(category: activeCategory, snapshot: snapshot)
                                } else if activeCategory.templateKey == "theater" {
                                    theaterTicketManagementSection(category: activeCategory)
                                } else if CategoryPlanningHeroPolicy.supports(activeCategory.templateKey) {
                                    categoryPriorityHero(category: activeCategory, snapshot: snapshot)
                                }
                            }
                            .id("category-hero-\(activeCategory.id.uuidString)")

                            GenreSwipeContainer(
                                canMoveBackward: !visibleCategories.isEmpty,
                                canMoveForward: !visibleCategories.isEmpty,
                                onMove: { direction in
                                    if let destination = neighboringCategory(from: activeCategory, offset: direction) {
                                        switchCategory(to: destination)
                                    } else {
                                        dismiss()
                                    }
                                }
                            ) {
                                VStack(alignment: .leading, spacing: 24) {
                                    if activeCategory.templateKey == "theater" {
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate,
                                            showsComingUp: true,
                                            showsPerformanceLog: true
                                        )
                                            .id(CategoryScrollAnchor.events)
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        archivedTheaterEventsEntry(category: activeCategory)
                                    } else if activeCategory.templateKey == "goshuin" {
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        goshuinContent(category: activeCategory, snapshot: snapshot)
                                            .id(CategoryScrollAnchor.events)
                                    } else if activeCategory.templateKey == "random_goods" {
                                        CollectibleCategorySeriesGrid(
                                            events: resolvedEvents(in: snapshot),
                                            tint: categoryAccent(activeCategory),
                                            onAdd: { isShowingAddExperience = true }
                                        )
                                        .id(CategoryScrollAnchor.events)
                                    } else {
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        categoryTicketProgressSection(category: activeCategory)
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
                                        if supportsVisitedPlacesMap(activeCategory) {
                                            VisitedPlacesHeatMapSection(
                                                visits: resolvedVisits(in: snapshot),
                                                category: activeCategory,
                                                tint: categoryAccent(activeCategory)
                                            )
                                            .id("visited-places-map-\(activeCategory.id.uuidString)")
                                        }
                                    }
                                    chapterFooter(
                                        categories: visibleCategories,
                                        currentCategory: activeCategory,
                                        onSelect: { selectedCategory in
                                            switchCategory(to: selectedCategory)
                                            Task { @MainActor in
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    scrollProxy.scrollTo(CategoryScrollAnchor.top, anchor: .top)
                                                }
                                            }
                                        }
                                    )
                                }
                                .id("category-content-\(activeCategory.id.uuidString)")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(categoryBackground(category: activeCategory))
        .environment(\.colorScheme, usesAtmosphericDarkStyle(activeCategory) ? .dark : colorScheme)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(selectedCategoryDetail == nil ? .visible : .hidden, for: .tabBar)
        .overlay {
            if let selectedCategoryDetail {
                CategoryDetailPanelOverlay(
                    selection: selectedCategoryDetail,
                    onClose: { self.selectedCategoryDetail = nil },
                    onOpenEvent: openEventFromDetailPanel,
                    onOpenVisit: { self.selectedCategoryDetail = .visit($0) }
                )
                .transition(.opacity.combined(with: .offset(y: 18)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: selectedCategoryDetail?.id)
        .navigationDestination(item: $selectedCategoryEventID) { eventID in
            CategoryEventDestination(eventID: eventID)
        }
        .navigationDestination(item: $selectedBookSeries) { route in
            BookSeriesDetailView(route: route)
        }
        .navigationDestination(item: $selectedPlaceDetail) { selection in
            PlaceExperienceDetailDestination(
                placeID: selection.placeID,
                categoryID: selection.categoryID
            )
        }
        .sheet(isPresented: $isShowingAddExperience) {
            if activeCategory.templateKey == "random_goods" {
                AddCollectibleSeriesView(category: activeCategory)
            } else {
                AddExperienceView(category: activeCategory)
            }
        }
        .sheet(isPresented: $isShowingTheaterPerformanceRegistration) {
            TheaterPerformanceRegistrationView(category: activeCategory)
        }
        .sheet(isPresented: $isShowingTheaterTicketOverview) {
            NavigationStack {
                TicketOverviewView(showsCloseButton: true, initialFilter: .needsAction)
            }
        }
        .sheet(item: $ticketDetailsEditAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .ticketPostAcquisitionDetailsPrompt(
            attempt: $ticketDetailsPromptAttempt,
            onEdit: { ticketDetailsEditAttempt = $0 },
            onLater: { _ in }
        )
        .sheet(isPresented: $isShowingArchivedTheaterEvents) {
            NavigationStack {
                ArchivedTheaterEventsView(categoryID: activeCategory.id)
            }
        }
        .sheet(isPresented: $isShowingCategorySettings, onDismiss: reconcileCategoryAfterSettings) {
            NavigationStack {
                GenreDetailSettingsView(category: activeCategory)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                isShowingCategorySettings = false
                            } label: {
                                FavorecoIcon(systemName: "xmark", size: 17, fallbackWeight: .bold)
                            }
                            .accessibilityLabel("閉じる")
                        }
                    }
            }
            .environment(\.colorScheme, colorScheme)
        }
        .sheet(item: $selectedEventForNewVisit) { event in
            AddVisitView(event: event)
        }
        .sheet(item: $selectedGoshuinBook) { selection in
            GoshuinBookGalleryView(selection: selection)
        }
        .sheet(isPresented: $isShowingGoshuinSearch) {
            GoshuinPrefectureSearchView(
                selectedPrefecture: $selectedGoshuinPrefecture,
                availablePrefectures: goshuinAvailablePrefectures(in: resolvedVisits(in: snapshot))
            )
        }
        .sheet(isPresented: $isShowingGoshuinShare) {
            if let goshuinShareImage {
                GoshuinActivityView(activityItems: [goshuinShareImage])
            }
        }
        .alert("シェア画像はPro以上で利用できます", isPresented: $goshuinShareLocked) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("行った神社・お寺リストを画像として保存・SNS共有する機能はPro以上の機能です。")
        }
        .alert("更新できませんでした", isPresented: Binding(
            get: { !ticketStatusUpdateError.isEmpty },
            set: { if !$0 { ticketStatusUpdateError = "" } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ticketStatusUpdateError)
        }
        .onAppear {
            homeSelectedCategoryTemplateKey = activeCategory.templateKey
            createEntryContextRouter.activate(categoryID: activeCategory.id)
        }
    }

    private func collectibleHero(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let summaries = resolvedEvents(in: snapshot).map { CollectibleSeriesSummary.make(series: $0) }
        let collected = summaries.reduce(0) { $0 + $1.collectedCount }
        let target = summaries.reduce(0) { $0 + $1.targetCount }
        let duplicates = summaries.reduce(0) { $0 + $1.duplicateQuantity }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                FavorecoIcon(systemName: "shippingbox.fill", size: 27)
                    .foregroundStyle(categoryAccent(category))
                    .frame(width: 48, height: 48)
                    .background(categoryAccent(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goods")
                        .font(FavorecoTypography.jpSerif(25, weight: .bold, relativeTo: .title2))
                    Text(snapshot.events.isEmpty ? "シリーズを登録して、何種類・何個集まったか残せます。" : "全 \(snapshot.eventCount) シリーズ・\(collected)/\(target) 種類・ダブり \(duplicates) 個")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
            Button { isShowingAddExperience = true } label: {
                FavorecoIconLabel("シリーズを追加", systemImage: "plus.circle.fill", iconSize: 17)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(categoryAccent(category))
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func hero(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                FavorecoIcon(
                    systemName: PhosphorIconGlyph.categorySystemName(
                        templateKey: category.templateKey,
                        storedSystemName: category.iconSymbol
                    ),
                    size: 27
                )
                    .foregroundStyle(categoryAccent(category))
                    .frame(width: 44, height: 44)
                    .background(categoryAccent(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(recordTemplate.targetSectionTitle)ライブラリ")
                        .font(FavorecoTypography.jpSerif(25, weight: .bold, relativeTo: .title2))
                    Text(libraryMessage(snapshot: snapshot))
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                isShowingAddExperience = true
            } label: {
                FavorecoIconLabel(
                    snapshot.events.isEmpty ? "最初の記録を追加" : "記録を追加",
                    systemImage: "plus.circle.fill",
                    iconSize: 17
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(categoryAccent(category))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func theaterHero(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let eventsByID = resolvedEventsByID(in: snapshot)
        let featuredEvent = snapshot.events.first.flatMap { eventsByID[$0.id] }

        return HStack(alignment: .top, spacing: 16) {
            TheaterPosterView(event: featuredEvent, width: 118)

            VStack(alignment: .leading, spacing: 10) {
                Text("作品・公演ライブラリ")
                    .font(FavorecoTypography.jpSerif(23, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(TheaterCategoryStyle.ivory)

                Text(libraryMessage(snapshot: snapshot))
                    .font(FavorecoTypography.body)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    openPrimaryRegistration(for: category)
                } label: {
                    FavorecoIconLabel(
                        snapshot.events.isEmpty ? "最初の公演を登録" : "公演を登録",
                        systemImage: "plus",
                        iconSize: 17
                    )
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(TheaterCategoryStyle.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .overlay {
                    Capsule()
                        .stroke(TheaterCategoryStyle.gold.opacity(0.78), lineWidth: 1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.52), lineWidth: 0.7)
        }
    }

    private func categoryStats(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        Group {
            if category.templateKey == "book" {
                BookYearStatusStrip(
                    items: categoryLibraryItems(category: category, snapshot: snapshot),
                    tint: categoryAccent(category)
                )
            } else {
                CategoryStatisticsPanel(
                    items: categoryStatisticsItems(category: category, snapshot: snapshot),
                    tint: categoryAccent(category),
                    isTheater: category.templateKey == "theater",
                    isLive: category.templateKey == "live"
                )
            }
        }
    }

    @ViewBuilder
    private func archivedTheaterEventsEntry(category: RecordCategory) -> some View {
        let archivedCount = (category.events ?? []).lazy.filter(\.isArchived).count
        if archivedCount > 0 {
            Button {
                isShowingArchivedTheaterEvents = true
            } label: {
                HStack(spacing: 12) {
                    FavorecoIcon(systemName: "archivebox", size: 16)
                        .foregroundStyle(TheaterCategoryStyle.gold)
                        .frame(width: 30, height: 30)
                        .background(TheaterCategoryStyle.gold.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("非表示の公演")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(TheaterCategoryStyle.ivory)
                        Text("一覧から公演を再表示できます")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
                    }

                    Spacer(minLength: 8)

                    Text("\(archivedCount)件")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(TheaterCategoryStyle.gold)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.52))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    TheaterCategoryStyle.tileBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TheaterCategoryStyle.gold.opacity(0.34), lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("非表示にした公演の一覧を開きます")
        }
    }

    private func categoryStatisticsItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryStatisticsItem] {
        let values: [(String, String, String, String)]

        switch category.templateKey {
        case "theater":
            let theaterItems = categoryLibraryItems(category: category, snapshot: snapshot)
            let productionCount = theaterItems.count
            let interestedCount = theaterItems.filter {
                $0.event.stateKey == "interested"
                    && $0.nextPlan == nil
                    && !$0.hasActiveTicketProgress
            }.count
            values = [
                ("作品・公演", "\(productionCount)", "件", "総作品数"),
                ("観劇済み", "\(snapshot.visitCount)", "回", "総観劇数"),
                ("気になる", "\(interestedCount)", "件", "観劇予定"),
            ]
        case "movie":
            values = [
                ("映像作品", "\(snapshot.eventCount)", "作品", "総作品数"),
                ("鑑賞済み", "\(snapshot.visitCount)", "作品", "総鑑賞数"),
                ("気になる", "\(snapshot.interestedEventCount)", "作品", "鑑賞候補"),
            ]
        case "museum":
            let visits = resolvedVisits(in: snapshot)
            let visitedVenueCount = museumVisitedVenueCount(in: visits)
            let viewedEventCount = Set(visits.compactMap { $0.event?.id }).count
            values = [
                ("訪れた館", "\(visitedVenueCount)", "館", "訪問館数"),
                ("鑑賞イベント", "\(viewedEventCount)", "件", "鑑賞済み"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "鑑賞候補"),
            ]
        case "live":
            values = [
                ("ライブ", "\(snapshot.eventCount)", "件", "総公演数"),
                ("参加済み", "\(snapshot.visitCount)", "回", "総参加数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "参加候補"),
            ]
        case "book":
            let bookItems = categoryLibraryItems(category: category, snapshot: snapshot)
            let readCount = bookItems.filter { !$0.visits.isEmpty }.count
            let toReadCount = bookItems.filter {
                $0.event.stateKey == "interested" || $0.visits.isEmpty
            }.count
            values = [
                ("本", "\(bookItems.count)", "冊", "総登録数"),
                ("読了", "\(readCount)", "冊", "読了した本"),
                ("気になる", "\(toReadCount)", "冊", "気になる・積読"),
            ]
        case "sake":
            values = [
                ("銘柄", "\(snapshot.eventCount)", "本", "総銘柄数"),
                ("飲んだ", "\(snapshot.visitCount)", "回", "総記録数"),
                ("気になる", "\(snapshot.interestedEventCount)", "本", "試飲候補"),
            ]
        case "theme_park":
            values = [
                ("パーク", "\(snapshot.eventCount)", "園", "総登録数"),
                ("来園済み", "\(snapshot.visitCount)", "回", "総来園数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "nature_living":
            values = [
                ("訪れた施設", "\(snapshot.eventCount)", "館", "総施設数"),
                ("訪問済み", "\(snapshot.visitCount)", "回", "総訪問数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "outing_facility":
            values = [
                ("その他施設", "\(snapshot.eventCount)", "件", "未分類を含む"),
                ("訪問済み", "\(snapshot.visitCount)", "回", "総訪問数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "訪問候補"),
            ]
        case "goshuin":
            let visitedPlaceCount = Set(resolvedVisits(in: snapshot).compactMap { $0.event?.id }).count
            values = [
                ("参拝先", "\(visitedPlaceCount)", "寺社", "総参拝先数"),
                ("ご記帳済み", "\(snapshot.visitCount)", "印", "総御朱印数"),
                ("気になる", "\(snapshot.interestedEventCount)", "寺社", "参拝候補"),
            ]
        default:
            let targetTitle = CategoryRecordTemplate.template(for: category).targetSectionTitle
            values = [
                (targetTitle, "\(snapshot.eventCount)", "件", "総登録数"),
                ("体験済み", "\(snapshot.visitCount)", "回", "総体験数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "体験候補"),
            ]
        }

        return values.map {
            CategoryStatisticsItem(title: $0.0, value: $0.1, unit: $0.2, note: $0.3)
        }
    }

    private func museumVisitedVenueCount(in visits: [Visit]) -> Int {
        Set(visits.compactMap { visit -> String? in
            if let placeID = visit.placeMaster?.id {
                return "place:\(placeID.uuidString)"
            }

            let venueName = visit.venueNameSnapshot
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            return venueName.isEmpty ? nil : "name:\(venueName)"
        }).count
    }

    private func theaterEventSection(
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate
    ) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            TheaterSectionHeader(title: recordTemplate.targetSectionTitle, count: snapshot.eventCount)

            if snapshot.events.isEmpty {
                TheaterEmptyState(
                    icon: "theatermasks",
                    title: "作品・公演はまだありません",
                    message: "最初の記録を追加すると、ここから同じ公演に回を重ねられます。"
                )
            } else {
                let eventsByID = resolvedEventsByID(in: snapshot)
                ForEach(snapshot.events.prefix(10)) { eventSnapshot in
                    if let event = eventsByID[eventSnapshot.id] {
                        TheaterEventRow(snapshot: eventSnapshot, event: event) {
                            selectedEventForNewVisit = event
                        }
                    }
                }
            }
        }
    }

    private func theaterPerformanceLogSection(snapshot: CategoryTopSnapshot) -> some View {
        let visits = resolvedVisits(in: snapshot)
        let visibleVisits = isShowingAllTheaterVisits ? visits : Array(visits.prefix(10))
        let selectedLayout = TheaterPerformanceLogLayoutMode(
            rawValue: theaterPerformanceLogLayoutRaw
        ) ?? .banner

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    LayeredCategorySectionTitle(
                        englishTitle: "Performance Log",
                        japaneseTitle: "観劇記録",
                        foregroundColor: TheaterCategoryStyle.ivory
                    )

                    Text("\(snapshot.visitCount)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))

                    Spacer(minLength: 4)

                    let events = resolvedEvents(in: snapshot)
                    if !events.isEmpty {
                        Menu {
                            ForEach(events) { event in
                                Button(event.title.isEmpty ? "公演" : event.title) {
                                    selectedEventForNewVisit = event
                                }
                            }
                        } label: {
                            FavorecoIconLabel("記録する", systemImage: "plus", iconSize: 17)
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(TheaterCategoryStyle.gold)
                        }
                        .accessibilityLabel("公演を選んで観劇を記録")
                    }
                }

                TheaterPerformanceLogLayoutPicker(
                    selection: Binding(
                        get: { selectedLayout },
                        set: { theaterPerformanceLogLayoutRaw = $0.rawValue }
                    )
                )
            }

            if snapshot.visitIDs.isEmpty {
                CategoryScheduleEmptyRow(
                    icon: "ticket",
                    title: "観劇記録はまだありません",
                    actionTitle: nil,
                    tint: TheaterCategoryStyle.gold,
                    isTheater: true,
                    isLive: false
                )
            } else {
                switch selectedLayout {
                case .compact:
                    TheaterVisitCompactGrid(visits: visibleVisits) { visit in
                        selectedCategoryDetail = .visit(visit.id)
                    }
                case .banner:
                    ForEach(visibleVisits) { visit in
                        Button {
                            selectedCategoryDetail = .visit(visit.id)
                        } label: {
                            TheaterVisitRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if visits.count > 10 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingAllTheaterVisits.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(isShowingAllTheaterVisits ? "観劇記録を閉じる" : "さらに\(visits.count - 10)件見る")
                            Image(systemName: isShowingAllTheaterVisits ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(TheaterCategoryStyle.gold)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedLayout)
    }

    private func categoryPriorityHero(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let items = priorityHeroItems(category: category, snapshot: snapshot)

        return VStack(alignment: .leading, spacing: 14) {
            CategoryFeatureCarousel(
                title: "Coming Up / Interests",
                japaneseTitle: categoryFeatureCarouselJapaneseTitle(category),
                emptyMessage: "これからの予定や興味のあるものを追加すると、ここに並びます。",
                items: items,
                selectedIndex: $selectedFeatureCarouselIndex,
                tint: categoryAccent(category),
                fallbackIcon: category.iconSymbol,
                onOpenPlan: { selectedCategoryDetail = .plan($0) },
                onOpenVisit: { selectedCategoryDetail = .visit($0) },
                onAdd: { openPrimaryRegistration(for: category) }
            )

        }
        .onChange(of: items.count) { _, count in
            if count == 0 {
                selectedFeatureCarouselIndex = 0
            } else if selectedFeatureCarouselIndex >= count {
                selectedFeatureCarouselIndex = count - 1
            }
        }
        .onChange(of: category.id) { _, _ in
            selectedFeatureCarouselIndex = 0
        }
    }

    private func openPrimaryRegistration(for category: RecordCategory) {
        if ["theater", "live"].contains(category.templateKey) {
            isShowingTheaterPerformanceRegistration = true
        } else {
            isShowingAddExperience = true
        }
    }

    private func theaterTicketManagementSection(category: RecordCategory) -> some View {
        let plans = theaterTicketManagementPlans(category: category)
        let visiblePlans = isShowingAllTheaterTicketManagementPlans ? plans : Array(plans.prefix(1))
        let tint = categoryAccent(category)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: "Ticket Management",
                    japaneseTitle: "チケット管理",
                    foregroundColor: TheaterCategoryStyle.ivory
                )

                Text("\(plans.count)件")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(TheaterCategoryStyle.ticketActionRose)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    isShowingTheaterTicketOverview = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(TheaterCategoryStyle.ticketActionRose)
                }
                .buttonStyle(.plain)
            }

            if plans.isEmpty {
                CategoryScheduleEmptyRow(
                    icon: "checkmark.circle",
                    title: "対応が必要なチケットはありません",
                    actionTitle: nil,
                    tint: tint,
                    isTheater: true,
                    isLive: false
                )
            } else {
                ForEach(visiblePlans) { plan in
                    TheaterTicketManagementPlanCard(
                        plan: plan,
                        category: category,
                        tint: tint,
                        onOpenPlan: { selectedCategoryDetail = .plan($0) },
                        onMarkAcquired: markTicketAcquired
                    )
                }

                if plans.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingAllTheaterTicketManagementPlans.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(
                                isShowingAllTheaterTicketManagementPlans
                                    ? "閉じる"
                                    : "さらに見る（残り\(plans.count - 1)件）"
                            )
                            Image(
                                systemName: isShowingAllTheaterTicketManagementPlans
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(TheaterCategoryStyle.ticketActionRose)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: category.id) { _, _ in
            isShowingAllTheaterTicketManagementPlans = false
        }
        .onChange(of: plans.count) { _, count in
            if count <= 1 {
                isShowingAllTheaterTicketManagementPlans = false
            }
        }
    }

    private func categoryComingUpSection(category: RecordCategory) -> some View {
        let isTheater = category.templateKey == "theater"
        let plans = isTheater
            ? theaterComingUpPlans(category: category)
            : categoryUpcomingPlans(category: category)
        let visiblePlans = isShowingAllUpcomingPlans ? plans : Array(plans.prefix(1))
        let tint = categoryAccent(category)
        let isLive = category.templateKey == "live"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: "Coming Up",
                    japaneseTitle: categorySectionJapaneseTitle(
                        for: "Coming Up",
                        category: category
                    ) ?? "これからの予定",
                    foregroundColor: isTheater
                        ? TheaterCategoryStyle.ivory
                        : isLive ? LiveCategoryStyle.mist : FavorecoTypography.brandColor(for: colorScheme)
                )

                Text("\(plans.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(
                        isTheater
                            ? TheaterCategoryStyle.ivory.opacity(0.68)
                            : isLive ? LiveCategoryStyle.mist.opacity(0.72) : Color.secondary
                    )
            }

            if plans.isEmpty {
                if isTheater {
                    CategoryScheduleEmptyRow(
                        icon: "ticket",
                        title: "取得済みの観劇予定はまだありません",
                        actionTitle: nil,
                        tint: tint,
                        isTheater: true,
                        isLive: false
                    )
                } else {
                    Button {
                        NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                    } label: {
                        CategoryScheduleEmptyRow(
                            icon: "calendar.badge.plus",
                            title: "次の予定はまだありません",
                            actionTitle: "予定を追加",
                            tint: tint,
                            isTheater: false,
                            isLive: isLive
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if isTheater {
                    ForEach(plans) { plan in
                        Button {
                            selectedCategoryDetail = .plan(plan.id)
                        } label: {
                            FavorecoComingUpRow(
                                date: plan.startsAt,
                                timeText: FavorecoDateText.time(plan.startsAt),
                                categoryName: category.name,
                                title: theaterPlanTitle(plan),
                                venue: plan.venueNameSnapshot,
                                tint: tint,
                                isTheater: true
                            ) {
                                CategoryFeaturePoster(
                                    item: .plan(plan),
                                    fallbackIcon: category.iconSymbol,
                                    tint: tint
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(visiblePlans) { plan in
                        Button {
                            selectedCategoryDetail = .plan(plan.id)
                        } label: {
                            CategoryComingUpRow(
                                plan: plan,
                                category: category,
                                tint: tint,
                                isTheater: false,
                                isLive: isLive
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if plans.count > 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShowingAllUpcomingPlans.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(isShowingAllUpcomingPlans ? "予定を閉じる" : "ほか\(plans.count - 1)件の予定を見る")
                                Image(systemName: isShowingAllUpcomingPlans ? "chevron.up" : "chevron.down")
                            }
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: category.id) { _, _ in
            isShowingAllUpcomingPlans = false
        }
    }

    private func theaterTicketManagementPlans(category: RecordCategory) -> [Plan] {
        let now = Date()
        return allPlans
            .filter { plan in
                guard !plan.isArchived,
                      plan.visit == nil,
                      (plan.category ?? plan.event?.category)?.id == category.id else {
                    return false
                }
                guard !plan.hasConfirmedSchedule || plan.isUpcomingOrOngoing(at: now) else {
                    return false
                }
                return !isTheaterComingUpPlan(plan, now: now)
            }
            .sorted { theaterManagementPlanPrecedes($0, $1, now: now) }
    }

    private func theaterComingUpPlans(category: RecordCategory) -> [Plan] {
        let now = Date()
        return allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.visit == nil
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && isTheaterComingUpPlan(plan, now: now)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func isTheaterComingUpPlan(_ plan: Plan, now: Date) -> Bool {
        guard plan.isUpcomingOrOngoing(at: now) else { return false }
        let attempts = (plan.ticketAttempts ?? []).filter { !$0.isArchived }
        let hasAcquiredTicket = TicketAcquisitionState.hasAcquiredTicket(in: attempts)
        let hasUnresolvedAttempt = attempts.contains {
            !["interested", "lost", "attended", "skipped", "issued"].contains($0.statusKey)
        }
        return hasAcquiredTicket && !hasUnresolvedAttempt
    }

    private func theaterManagementPlanPrecedes(_ lhs: Plan, _ rhs: Plan, now: Date) -> Bool {
        let leftAction = theaterManagementNextAction(for: lhs, now: now)
        let rightAction = theaterManagementNextAction(for: rhs, now: now)

        switch (leftAction, rightAction) {
        case let (.some(left), .some(right)):
            if left.date != right.date { return left.date < right.date }
            if left.priority != right.priority { return left.priority < right.priority }
        case (.some(_), .none):
            return true
        case (.none, .some(_)):
            return false
        case (.none, .none):
            break
        }

        if lhs.hasConfirmedSchedule != rhs.hasConfirmedSchedule {
            return lhs.hasConfirmedSchedule
        }
        if lhs.hasConfirmedSchedule, lhs.startsAt != rhs.startsAt {
            return lhs.startsAt < rhs.startsAt
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func theaterManagementNextAction(
        for plan: Plan,
        now: Date
    ) -> TicketNextActionDefinition? {
        let attempts = TicketAttemptPresentationOrder.sorted(
            (plan.ticketAttempts ?? []).filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped", "issued"].contains($0.statusKey)
            },
            now: now
        )
        return attempts.lazy.compactMap {
            TicketNextActionDefinition.nextAction(for: $0, now: now)
        }.first
    }

    private func theaterPlanTitle(_ plan: Plan) -> String {
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private func markTicketAcquired(_ attempt: TicketAttempt) {
        do {
            try TicketAttemptStatusUpdater.update(
                attempt: attempt,
                to: "issued",
                in: modelContext
            )
            if TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: "issued"
            ) {
                DispatchQueue.main.async {
                    ticketDetailsPromptAttempt = attempt
                }
            }
        } catch {
            ticketStatusUpdateError = "チケットを取得済みに更新できませんでした。もう一度お試しください。"
        }
    }

    private func categoryUpcomingPlans(category: RecordCategory) -> [Plan] {
        let now = Date()
        return allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.isUpcomingOrOngoing(at: now)
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && (category.templateKey != "movie"
                        || plan.event.map { screenWorkFilter.includes($0.screenWorkType) } != false)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func priorityHeroItems(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [CategoryFeatureItem] {
        let now = Date()
        let upcomingPlans = allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.isUpcomingOrOngoing(at: now)
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && (category.templateKey != "movie"
                        || plan.event.map { screenWorkFilter.includes($0.screenWorkType) } != false)
            }
            .sorted { $0.startsAt < $1.startsAt }
        let plannedEventIDs = Set(upcomingPlans.compactMap { $0.event?.id })
        let interestedEvents = resolvedEvents(in: snapshot, category: category)
            .filter {
                $0.stateKey == "interested"
                    && !plannedEventIDs.contains($0.id)
                    && (category.templateKey != "movie" || screenWorkFilter.includes($0.screenWorkType))
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        let planItems = upcomingPlans.map(CategoryFeatureItem.plan)
        let interestItems = interestedEvents.map(CategoryFeatureItem.interest)
        return Array((planItems + interestItems).prefix(10))
    }

    private func featureMetrics(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [MiniStatisticsItem] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let visits = resolvedVisits(in: snapshot)
        let yearVisits = visits.filter { calendar.component(.year, from: $0.visitedAt) == currentYear }
        let ratedYearVisits = yearVisits.filter { $0.overallRating > 0 }
        let averageText: String = {
            guard !ratedYearVisits.isEmpty else { return "-" }
            let average = ratedYearVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedYearVisits.count)
            return String(format: "%.1f", average)
        }()
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        let movieReviewText: String = {
            guard !ratedVisits.isEmpty else { return "-" }
            let average = ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
            return String(format: "%.1f", average)
        }()

        switch category.templateKey {
        case "movie":
            return [
                MiniStatisticsItem(title: "総鑑賞数", value: "\(snapshot.visitCount)", unit: "作品", icon: "movieclapper"),
                MiniStatisticsItem(title: "年間数", value: "\(yearVisits.count)", unit: "作品", icon: "calendar"),
                MiniStatisticsItem(title: "観たい", value: "\(snapshot.interestedEventCount)", unit: "作品", icon: "bookmark"),
                MiniStatisticsItem(title: "レビュー", value: movieReviewText, unit: movieReviewText == "-" ? "" : "点", icon: "text.bubble"),
            ]
        case "book":
            let favoriteCount = visits.filter { $0.overallRating >= 4.5 }.count
            return [
                MiniStatisticsItem(title: "総冊数", value: "\(snapshot.eventCount)", unit: "冊", icon: "books.vertical"),
                MiniStatisticsItem(title: "年間冊数", value: "\(yearVisits.count)", unit: "冊", icon: "calendar"),
                MiniStatisticsItem(title: "年間評価", value: averageText, unit: "", icon: "star"),
                MiniStatisticsItem(title: "お気に入り", value: "\(favoriteCount)", unit: "冊", icon: "bookmark"),
            ]
        case "theme_park":
            let repeatCount = repeatVisitCount(in: visits)
            return [
                MiniStatisticsItem(title: "総来園数", value: "\(snapshot.visitCount)", unit: "回", icon: "ticket"),
                MiniStatisticsItem(title: "年間来園", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "件", icon: "bookmark"),
            ]
        case "nature_living":
            let repeatCount = repeatVisitCount(in: visits)
            let encounteredCount = encounteredItemCount(in: visits)
            return [
                MiniStatisticsItem(title: "総訪問数", value: "\(snapshot.visitCount)", unit: "回", icon: "pawprint"),
                MiniStatisticsItem(title: "年間訪問", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "出会った数", value: encounteredCount == 0 ? "-" : "\(encounteredCount)", unit: "種", icon: "pawprint"),
            ]
        case "outing_facility":
            return [
                MiniStatisticsItem(title: "施設", value: "\(snapshot.eventCount)", unit: "件", icon: "questionmark.folder"),
                MiniStatisticsItem(title: "訪問", value: "\(snapshot.visitCount)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "件", icon: "bookmark"),
            ]
        default:
            return [
                MiniStatisticsItem(title: "対象", value: "\(snapshot.eventCount)", unit: "", icon: "rectangle.stack"),
                MiniStatisticsItem(title: "記録", value: "\(snapshot.visitCount)", unit: "", icon: "sparkles.rectangle.stack"),
                MiniStatisticsItem(title: "年間", value: "\(yearVisits.count)", unit: "", icon: "calendar"),
            ]
        }
    }

    private func featureText(for event: ExperienceEvent) -> String {
        [
            event.title,
            event.seriesName,
            event.subTypeKey,
            event.memo,
            event.importMemo,
            VisitUnitFields(rawValue: event.unitFieldsRaw).ocrText,
        ].joined(separator: " ")
    }

    private func repeatVisitCount(in visits: [Visit]) -> Int {
        let grouped = Dictionary(grouping: visits) { visit in
            let venue = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !venue.isEmpty { return venue }
            return visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? visit.id.uuidString
        }
        return grouped.values.reduce(0) { total, groupedVisits in
            groupedVisits.count > 1 ? total + groupedVisits.count : total
        }
    }

    private func encounteredItemCount(in visits: [Visit]) -> Int {
        let labels = ["出会った", "生きもの", "生き物", "動物", "魚", "種類"]
        var names = Set<String>()
        for visit in visits {
            let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            for entry in fields.advancedEntries {
                guard labels.contains(where: { entry.trimmedLabel.contains($0) }) else { continue }
                entry.trimmedValue
                    .components(separatedBy: CharacterSet(charactersIn: ",、/\n "))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .forEach { names.insert($0) }
            }
        }
        return names.count
    }

    private func goshuinContent(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let visits = resolvedVisits(in: snapshot)
        let filteredVisits = goshuinFilteredVisits(in: visits, filter: goshuinFilter)
        let mapVisits = goshuinMapVisits(in: visits)
        let displayedVisits = Array(mapVisits.prefix(goshuinListLimit))
        let books = goshuinBookSelections(from: visits)

        return VStack(alignment: .leading, spacing: 18) {
            GoshuinFilterBar(selection: $goshuinFilter, options: [.all, .shrine, .temple, .limited, .special])

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    LayeredCategorySectionTitle(
                        englishTitle: "Goshuin",
                        japaneseTitle: "御朱印",
                        foregroundColor: .primary
                    )
                    Spacer()
                    Text("\(filteredVisits.count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                if filteredVisits.isEmpty {
                    EmptyStateMessage(
                        icon: "seal",
                        title: "御朱印はまだありません",
                        message: "参拝先、日付、御朱印帳サイズ、写真を入れるとここに並びます。",
                        tint: themePalette.categoryColor(hex: category.colorHex)
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                        ForEach(filteredVisits.prefix(6)) { visit in
                            Button {
                                selectedCategoryDetail = .visit(visit.id)
                            } label: {
                                GoshuinStampTile(visit: visit, photo: firstPhoto(in: visit))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                LayeredCategorySectionTitle(
                    englishTitle: "Goshuin Books",
                    japaneseTitle: "使用中の御朱印帳",
                    foregroundColor: .primary
                )

                if books.isEmpty {
                    EmptyStateMessage(
                        icon: "book.closed",
                        title: "御朱印帳はまだありません",
                        message: "記録時に御朱印帳サイズを選ぶと、サイズごとにまとまります。",
                        tint: themePalette.categoryColor(hex: category.colorHex)
                    )
                } else {
                    ForEach(books) { book in
                        Button {
                            selectedGoshuinBook = book
                        } label: {
                            GoshuinBookRow(selection: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    LayeredCategorySectionTitle(
                        englishTitle: "Pilgrimage Map",
                        japaneseTitle: "行った神社・お寺MAP",
                        foregroundColor: .primary
                    )
                    Spacer()
                    Button {
                        isShowingGoshuinSearch = true
                    } label: {
                        Label(selectedGoshuinPrefecture.isEmpty ? "詳細検索" : selectedGoshuinPrefecture, systemImage: "line.3.horizontal.decrease.circle")
                            .labelStyle(.titleAndIcon)
                    }
                    .font(FavorecoTypography.captionStrong)
                }

                GoshuinMapPreview(visits: mapVisits)

                GoshuinFilterBar(selection: $goshuinMapFilter, options: [.all, .shrine, .temple])

                if !selectedGoshuinPrefecture.isEmpty {
                    HStack {
                        FavorecoIconLabel(selectedGoshuinPrefecture, systemImage: "mappin.and.ellipse", iconSize: 13)
                            .font(FavorecoTypography.captionStrong)
                        Spacer()
                        Button("解除") {
                            selectedGoshuinPrefecture = ""
                            goshuinListLimit = 10
                        }
                        .font(FavorecoTypography.captionStrong)
                    }
                    .foregroundStyle(.secondary)
                }

                if displayedVisits.isEmpty {
                    EmptyStateMessage(
                        icon: "map",
                        title: "MAPに表示できる場所がありません",
                        message: "Apple Mapsから場所を選ぶか住所を入れると、全国MAPと一覧に反映されます。",
                        tint: themePalette.categoryColor(hex: category.colorHex)
                    )
                } else {
                    ForEach(displayedVisits) { visit in
                        Button {
                            selectedCategoryDetail = .visit(visit.id)
                        } label: {
                            GoshuinVisitedPlaceRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }

                    if mapVisits.count > displayedVisits.count {
                        Button {
                            goshuinListLimit += 10
                        } label: {
                            Text("さらに10件表示")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button {
                    generateGoshuinShareImage(visits: mapVisits)
                } label: {
                    Label(
                        purchaseManager.currentPlan.includesLocalFullFeatures ? "行ったリストをシェア画像にする" : "行ったリストのシェア画像はPro以上",
                        systemImage: purchaseManager.currentPlan.includesLocalFullFeatures ? "square.and.arrow.up" : "lock.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themePalette.categoryColor(hex: category.colorHex))
            }
        }
        .onChange(of: goshuinMapFilter) { _, _ in
            goshuinListLimit = 10
        }
        .onChange(of: selectedGoshuinPrefecture) { _, _ in
            goshuinListLimit = 10
        }
    }

    private func goshuinHero(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let recentVisits = Array(resolvedVisits(in: snapshot).sorted { $0.visitedAt > $1.visitedAt }.prefix(5))

        return GoshuinTopHero(
            category: category,
            visits: recentVisits,
            selectedIndex: $selectedGoshuinHeroIndex,
            onAdd: { isShowingAddExperience = true }
        )
        .onChange(of: recentVisits.count) { _, count in
            if count == 0 {
                selectedGoshuinHeroIndex = 0
            } else if selectedGoshuinHeroIndex >= count {
                selectedGoshuinHeroIndex = count - 1
            }
        }
        .onChange(of: category.id) { _, _ in
            selectedGoshuinHeroIndex = 0
        }
    }

    private func goshuinFilteredVisits(in visits: [Visit], filter: GoshuinVisitFilter) -> [Visit] {
        visits.filter { filter.matches($0) }
    }

    private func goshuinMapVisits(in visits: [Visit]) -> [Visit] {
        goshuinFilteredVisits(in: visits, filter: goshuinMapFilter)
            .filter { visit in
                selectedGoshuinPrefecture.isEmpty || goshuinPrefectureText(for: visit).contains(selectedGoshuinPrefecture)
            }
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
    }

    private func goshuinBookSelections(from visits: [Visit]) -> [GoshuinBookSelection] {
        let grouped = Dictionary(grouping: visits) { visit in
            let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            return fields.goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : fields.goshuinBookSizeKey
        }

        return grouped.map { key, visits in
            let sortedVisits = visits.sorted { $0.visitedAt > $1.visitedAt }
            return GoshuinBookSelection(
                size: GoshuinBookSize.option(for: key),
                visits: sortedVisits,
                coverPhoto: sortedVisits.first.flatMap { firstPhoto(in: $0) }
            )
        }
        .sorted { left, right in
            let leftDate = left.visits.first?.visitedAt ?? .distantPast
            let rightDate = right.visits.first?.visitedAt ?? .distantPast
            return leftDate > rightDate
        }
    }

    private func goshuinAvailablePrefectures(in visits: [Visit]) -> [String] {
        CategoryTopJapanPrefecture.allCases
            .map(\.rawValue)
            .filter { prefecture in
                visits.contains { goshuinPrefectureText(for: $0).contains(prefecture) }
            }
    }

    private func goshuinPrefectureText(for visit: Visit) -> String {
        [
            visit.placeMaster?.address ?? "",
            visit.venueNameSnapshot,
            visit.note,
        ].joined(separator: " ")
    }

    private func generateGoshuinShareImage(visits: [Visit]) {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else {
            goshuinShareLocked = true
            return
        }
        let renderer = ImageRenderer(content: GoshuinVisitedShareCard(visits: Array(visits.prefix(24))))
        renderer.proposedSize = ProposedViewSize(width: 390, height: 760)
        renderer.scale = UIScreen.main.scale
        goshuinShareImage = renderer.uiImage
        isShowingGoshuinShare = goshuinShareImage != nil
    }

    private func stats(snapshot: CategoryTopSnapshot) -> some View {
        CategoryFeatureMetricsGrid(
            metrics: [
                MiniStatisticsItem(title: "対象", value: "\(snapshot.eventCount)", unit: "", icon: "rectangle.stack"),
                MiniStatisticsItem(title: "体験済み", value: "\(snapshot.visitCount)", unit: "", icon: "checkmark.circle"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "", icon: "bookmark"),
            ],
            tint: themePalette.categoryColor(hex: currentCategory.colorHex)
        )
    }

    private func eventSection(
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recordTemplate.targetSectionTitle)
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(snapshot.eventCount)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if snapshot.events.isEmpty {
                EmptyStateMessage(
                    icon: "rectangle.stack.badge.plus",
                    title: "対象はまだありません",
                    message: "最初の記録を追加すると、ここから同じ対象に回を重ねられます。"
                )
            } else {
                let eventsByID = resolvedEventsByID(in: snapshot)
                ForEach(snapshot.events.prefix(10)) { eventSnapshot in
                    if let event = eventsByID[eventSnapshot.id] {
                        EventRow(snapshot: eventSnapshot, event: event) {
                            selectedEventForNewVisit = event
                        }
                    }
                }
            }
        }
    }

    private func categoryLibrarySection(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate,
        showsComingUp: Bool = true,
        showsPerformanceLog: Bool = false
    ) -> some View {
        let selectedLayout = libraryLayoutMode(for: category)
        let allItems = categoryLibraryItems(category: category, snapshot: snapshot)
        let items = category.templateKey == "movie"
            ? allItems.filter { screenWorkFilter.includes($0.event.screenWorkType) }
            : allItems
        let showsPlaceExperienceSections = isPlaceExperienceCategory(category)
        let showsPlanningSections = ["theater", "live", "museum", "movie", "theme_park", "nature_living", "outing_facility"]
            .contains(category.templateKey)
        let showsIntegratedPlanningHero = CategoryPlanningHeroPolicy.supports(category.templateKey)
        let separatesInterests = showsPlanningSections
        let showsBookSections = category.templateKey == "book"
        let showsVisitRecordLibrary = ["museum", "movie"].contains(category.templateKey)
        let interestedItems: [CategoryLibraryItem] = if showsPlanningSections {
            items.filter {
                $0.event.stateKey == "interested"
                    && $0.nextPlan == nil
                    && !$0.hasActiveTicketProgress
            }
        } else if showsBookSections {
            items.filter { $0.event.stateKey == "interested" }
        } else {
            []
        }
        let productionItems: [CategoryLibraryItem] = if showsPlaceExperienceSections {
            items
        } else if category.templateKey == "theater" {
            items.filter {
                !(
                    $0.event.stateKey == "interested"
                        && $0.nextPlan == nil
                        && !$0.hasActiveTicketProgress
                )
            }
        } else if showsPlanningSections {
            items.filter { $0.event.stateKey != "interested" }
        } else if showsBookSections {
            items.filter { $0.event.stateKey != "interested" && $0.latestVisit != nil }
        } else {
            items
        }
        let showsFacilityPlaceLibrary = showsPlaceExperienceSections || category.templateKey == "museum"
        let facilityPlaces = showsFacilityPlaceLibrary
            ? facilityPlaceMasters(for: category)
            : []
        // 施設系は PlaceMaster を唯一の施設一覧にする。旧構造の ExperienceEvent は
        // 統合Heroまたは専用の予定・気になる表示とLogで扱い、施設情報へ重複表示しない。
        let displayedProductionItems = showsPlaceExperienceSections ? [] : productionItems
        let productionCount = facilityPlaces.count + displayedProductionItems.count
        let tint: Color = switch category.templateKey {
        case "theater": TheaterCategoryStyle.gold
        case "live": LiveCategoryStyle.teal
        default: themePalette.categoryColor(hex: category.colorHex)
        }

        return VStack(alignment: .leading, spacing: 12) {
            if showsPlaceExperienceSections {
                if showsComingUp && !showsIntegratedPlanningHero {
                    categoryComingUpSection(category: category)

                    Spacer()
                        .frame(height: 8)
                }

                if !showsIntegratedPlanningHero {
                    categoryLibrarySubsection(
                        title: "Interests",
                        items: interestedItems,
                        sectionKey: "interests",
                        emptyIcon: "heart",
                        emptyTitle: category.templateKey == "theme_park"
                            ? "気になるパークはまだありません"
                            : "気になる施設はまだありません",
                        category: category,
                        tint: tint
                    )

                    Spacer()
                        .frame(height: 8)
                }

                placeExperienceLogSection(category: category, snapshot: snapshot)

                Spacer()
                    .frame(height: 8)
            } else if showsBookSections {
                BookLibrarySection(
                    items: items,
                    category: category,
                    tint: tint,
                    onOpenEvent: openCategoryEvent,
                    onOpenVisit: { selectedCategoryDetail = .visit($0) },
                    onOpenSeries: { route in selectedBookSeries = route }
                )

                Spacer()
                    .frame(height: 8)
            } else if separatesInterests && !showsIntegratedPlanningHero {
                categoryLibrarySubsection(
                    title: "Interests",
                    items: interestedItems,
                    sectionKey: "interests",
                    emptyIcon: "heart",
                    emptyTitle: category.templateKey == "theater"
                        ? "気になる公演はまだありません"
                        : "気になるものはまだありません",
                    category: category,
                    tint: tint
                )

                Spacer()
                    .frame(height: 8)
            }

            if showsPlanningSections
                && showsComingUp
                && !showsPlaceExperienceSections
                && !showsIntegratedPlanningHero {
                categoryComingUpSection(category: category)

                Spacer()
                    .frame(height: 8)
            }

            if showsPerformanceLog {
                theaterPerformanceLogSection(snapshot: snapshot)

                Spacer()
                    .frame(height: 8)
            }

            if showsVisitRecordLibrary {
                categoryVisitRecordLibrarySection(
                    category: category,
                    snapshot: snapshot,
                    tint: tint
                )

                if category.templateKey == "museum" {
                    Spacer()
                        .frame(height: 8)

                    facilityPlaceLibrarySection(
                        category: category,
                        places: facilityPlaces,
                        tint: tint
                    )
                }
            } else if !showsBookSections {
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    let title = librarySectionTitle(
                        category: category,
                        fallback: recordTemplate.targetSectionTitle
                    )
                    if let japaneseTitle = categorySectionJapaneseTitle(for: title, category: category) {
                        LayeredCategorySectionTitle(
                            englishTitle: title,
                            japaneseTitle: japaneseTitle,
                            foregroundColor: libraryPrimaryTextColor(category)
                        )
                    } else {
                        Text(title)
                            .font(FavorecoTypography.sectionTitle)
                            .foregroundStyle(libraryPrimaryTextColor(category))
                    }

                    Text("\(productionCount)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(librarySecondaryTextColor(category))
                }

                Spacer(minLength: 4)

                if category.templateKey != "live" {
                    let layoutModes: [CategoryLibraryLayoutMode] = if showsPlaceExperienceSections {
                        [.compact, .banner]
                    } else if category.templateKey == "movie" {
                        [.gallery, .banner]
                    } else {
                        CategoryLibraryLayoutMode.allCases
                    }
                    CategoryLibraryLayoutPicker(
                        selection: Binding(
                            get: { libraryLayoutMode(for: category) },
                            set: { selectLibraryLayout($0, for: category) }
                        ),
                        tint: tint,
                        modes: layoutModes,
                        onSelect: { _ in }
                    )
                }
            }

            if productionCount == 0 {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "\(recordTemplate.targetSectionTitle)はまだありません",
                    message: "最初の記録や予定を追加すると、ここに並びます。",
                    tint: tint
                )
            } else {
                if !facilityPlaces.isEmpty {
                    if selectedLayout == .compact {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10, alignment: .top),
                                GridItem(.flexible(), spacing: 10, alignment: .top),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(facilityPlaces) { place in
                                PlaceMasterFacilityGridCard(
                                    place: place,
                                    category: category,
                                    plans: categoryPlans(for: place, category: category),
                                    visits: categoryVisits(for: place, category: category),
                                    tint: tint,
                                    onOpen: {
                                        selectedPlaceDetail = PlaceExperienceDetailSelection(
                                            placeID: place.id,
                                            categoryID: category.id
                                        )
                                    }
                                )
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(facilityPlaces) { place in
                                Button {
                                    selectedPlaceDetail = PlaceExperienceDetailSelection(
                                        placeID: place.id,
                                        categoryID: category.id
                                    )
                                } label: {
                                    PlaceMasterFacilityRow(
                                        place: place,
                                        category: category,
                                        plans: categoryPlans(for: place, category: category),
                                        visits: categoryVisits(for: place, category: category),
                                        tint: tint
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !displayedProductionItems.isEmpty {
                    categoryLibraryItemsContent(
                        items: displayedProductionItems,
                        sectionKey: "productions",
                        category: category,
                        tint: tint,
                        layout: selectedLayout
                    )
                }
            }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedLayout)
    }

    @ViewBuilder
    private func facilityPlaceLibrarySection(
        category: RecordCategory,
        places: [PlaceMaster],
        tint: Color
    ) -> some View {
        let selectedLayout = facilityLibraryLayoutMode(for: category)

        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                LayeredCategorySectionTitle(
                    englishTitle: category.templateKey == "museum" ? "Museums" : "Places",
                    japaneseTitle: "施設情報",
                    foregroundColor: libraryPrimaryTextColor(category)
                )

                Text("\(places.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(librarySecondaryTextColor(category))
            }

            Spacer(minLength: 4)

            CategoryLibraryLayoutPicker(
                selection: Binding(
                    get: { facilityLibraryLayoutMode(for: category) },
                    set: { selectFacilityLibraryLayout($0, for: category) }
                ),
                tint: tint,
                modes: [.compact, .banner],
                onSelect: { _ in }
            )
        }

        if places.isEmpty {
            EmptyStateMessage(
                icon: "building.columns",
                title: "美術館・博物館はまだありません",
                message: "施設を登録すると、予定や鑑賞記録を同じ館へまとめられます。",
                tint: tint
            )
        } else if selectedLayout == .compact {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(places) { place in
                    PlaceMasterFacilityGridCard(
                        place: place,
                        category: category,
                        plans: categoryPlans(for: place, category: category),
                        visits: categoryVisits(for: place, category: category),
                        tint: tint,
                        onOpen: {
                            selectedPlaceDetail = PlaceExperienceDetailSelection(
                                placeID: place.id,
                                categoryID: category.id
                            )
                        }
                    )
                }
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(places) { place in
                    Button {
                        selectedPlaceDetail = PlaceExperienceDetailSelection(
                            placeID: place.id,
                            categoryID: category.id
                        )
                    } label: {
                        PlaceMasterFacilityRow(
                            place: place,
                            category: category,
                            plans: categoryPlans(for: place, category: category),
                            visits: categoryVisits(for: place, category: category),
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryLibrarySubsection(
        title: String,
        items: [CategoryLibraryItem],
        sectionKey: String,
        emptyIcon: String,
        emptyTitle: String,
        category: RecordCategory,
        tint: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let japaneseTitle = categorySectionJapaneseTitle(for: title, category: category) {
                LayeredCategorySectionTitle(
                    englishTitle: title,
                    japaneseTitle: japaneseTitle,
                    foregroundColor: libraryPrimaryTextColor(category)
                )
            } else {
                Text(title)
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(libraryPrimaryTextColor(category))
            }

            Text("\(items.count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(librarySecondaryTextColor(category))
        }

        if items.isEmpty {
            if sectionKey == "interests" || sectionKey == "book-interests" {
                Button {
                    openPrimaryRegistration(for: category)
                } label: {
                    CategoryScheduleEmptyRow(
                        icon: emptyIcon,
                        title: emptyTitle,
                        actionTitle: interestAddActionTitle(for: category),
                        tint: tint,
                        isTheater: category.templateKey == "theater",
                        isLive: category.templateKey == "live"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("このジャンルの気になる項目を追加します")
            } else {
                CategoryScheduleEmptyRow(
                    icon: emptyIcon,
                    title: emptyTitle,
                    actionTitle: nil,
                    tint: tint,
                    isTheater: category.templateKey == "theater",
                    isLive: category.templateKey == "live"
                )
            }
        } else {
            categoryLibraryItemsContent(
                items: items,
                sectionKey: sectionKey,
                category: category,
                tint: tint,
                layout: libraryLayoutMode(for: category)
            )
        }
    }

    private func interestAddActionTitle(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "theater": "公演を追加"
        case "live": "ライブを追加"
        case "museum": "展示を追加"
        case "movie": "作品を追加"
        case "book": "本を追加"
        case "theme_park": "パークを追加"
        case "nature_living", "outing_facility": "施設を追加"
        default: "追加する"
        }
    }

    private func isPlaceExperienceCategory(_ category: RecordCategory) -> Bool {
        ["theme_park", "nature_living", "outing_facility"].contains(category.templateKey)
    }

    private func facilityPlaceMasters(for category: RecordCategory) -> [PlaceMaster] {
        var relatedIDs = Set<UUID>()
        for plan in allPlans where !plan.isArchived {
            let planCategoryID = plan.category?.id ?? plan.event?.category?.id
            guard planCategoryID == category.id, let placeID = plan.placeMaster?.id else { continue }
            relatedIDs.insert(placeID)
        }
        for visit in allVisits {
            guard visit.event?.category?.id == category.id,
                  let placeID = visit.placeMaster?.id else { continue }
            relatedIDs.insert(placeID)
        }
        let scope: PublicPlaceCatalogScope? = switch category.templateKey {
        case "museum": .museum
        case "theme_park": .themePark
        case "nature_living", "outing_facility": .natureLiving
        default: nil
        }
        return allPlaceMasters
            .filter { !$0.isArchived }
            .filter { relatedIDs.contains($0.id) || scope?.includes($0) == true }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func categoryPlans(for place: PlaceMaster, category: RecordCategory) -> [Plan] {
        allPlans.filter {
            !$0.isArchived
                && $0.placeMaster?.id == place.id
                && ($0.category ?? $0.event?.category)?.id == category.id
        }
    }

    private func categoryVisits(for place: PlaceMaster, category: RecordCategory) -> [Visit] {
        allVisits.filter {
            $0.placeMaster?.id == place.id
                && $0.event?.category?.id == category.id
        }
    }

    private func placeExperienceLogSection(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> some View {
        let visits = resolvedVisits(in: snapshot)
        let tint = themePalette.categoryColor(hex: category.colorHex)
        let isPark = category.templateKey == "theme_park"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: isPark ? "Park Log" : "Nature Log",
                    japaneseTitle: isPark ? "来園記録" : "体験記録",
                    foregroundColor: libraryPrimaryTextColor(category)
                )

                Text("\(visits.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(librarySecondaryTextColor(category))

                Spacer(minLength: 4)

                let events = resolvedEvents(in: snapshot)
                if !events.isEmpty {
                    Menu {
                        ForEach(events) { event in
                            Button(event.title.isEmpty ? "施設" : event.title) {
                                selectedEventForNewVisit = event
                            }
                        }
                    } label: {
                        FavorecoIconLabel("記録する", systemImage: "plus", iconSize: 15)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                    }
                    .accessibilityLabel("施設を選んで記録を追加")
                }
            }

            if visits.isEmpty {
                CategoryScheduleEmptyRow(
                    icon: isPark ? "ticket" : "leaf",
                    title: isPark ? "来園記録はまだありません" : "体験記録はまだありません",
                    actionTitle: nil,
                    tint: tint,
                    isTheater: false,
                    isLive: false
                )
            } else {
                ForEach(visits.prefix(10)) { visit in
                    Button {
                        selectedCategoryDetail = .visit(visit.id)
                    } label: {
                        PlaceExperienceVisitRow(visit: visit, isPark: isPark, tint: tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryLibraryItemsContent(
        items: [CategoryLibraryItem],
        sectionKey: String,
        category: RecordCategory,
        tint: Color,
        layout: CategoryLibraryLayoutMode
    ) -> some View {
        let pageSize = libraryPageSize(for: layout)
        let key = libraryDisplayKey(category: category, sectionKey: sectionKey, layout: layout)

        ProgressiveCategoryLibraryContent(
            items: items,
            category: category,
            tint: tint,
            layout: layout,
            pageSize: pageSize,
            showsProductionMetadata: category.templateKey == "theater"
                && sectionKey == "productions",
            onOpenEvent: openCategoryEvent
        )
        .id(key)
    }

    private func openCategoryEvent(_ eventID: UUID) {
        guard selectedCategoryEventID == nil else { return }
        Task { @MainActor in
            await Task.yield()
            selectedCategoryEventID = eventID
        }
    }

    private func libraryPageSize(for layout: CategoryLibraryLayoutMode) -> Int {
        switch layout {
        case .gallery: return 6
        case .compact: return 6
        case .banner: return 4
        }
    }

    private func libraryLayoutMode(for category: RecordCategory) -> CategoryLibraryLayoutMode {
        if isPlaceExperienceCategory(category) {
            let storedMode = libraryLayoutModes[category.templateKey]
                ?? CategoryLibraryLayoutMode.stored(for: category.templateKey)
            return storedMode == .banner ? .banner : .compact
        }
        if category.templateKey == "movie" {
            let storedMode = libraryLayoutModes[category.templateKey]
                ?? CategoryLibraryLayoutMode.stored(for: category.templateKey)
            return storedMode == .banner ? .banner : .gallery
        }
        if category.templateKey == "live" {
            return .banner
        }
        return libraryLayoutModes[category.templateKey]
            ?? CategoryLibraryLayoutMode.stored(for: category.templateKey)
    }

    private func facilityLibraryLayoutMode(for category: RecordCategory) -> CategoryLibraryLayoutMode {
        let storageKey = category.templateKey == "museum"
            ? "museum.facilities"
            : category.templateKey
        let storedMode = libraryLayoutModes[storageKey]
            ?? CategoryLibraryLayoutMode.stored(for: storageKey)
        return storedMode == .banner ? .banner : .compact
    }

    private func selectFacilityLibraryLayout(
        _ mode: CategoryLibraryLayoutMode,
        for category: RecordCategory
    ) {
        let storageKey = category.templateKey == "museum"
            ? "museum.facilities"
            : category.templateKey
        let resolvedMode: CategoryLibraryLayoutMode = mode == .banner ? .banner : .compact
        libraryLayoutModes[storageKey] = resolvedMode
        resolvedMode.store(for: storageKey)
    }

    private func selectLibraryLayout(
        _ mode: CategoryLibraryLayoutMode,
        for category: RecordCategory
    ) {
        if isPlaceExperienceCategory(category) {
            let resolvedMode: CategoryLibraryLayoutMode = mode == .banner ? .banner : .compact
            libraryLayoutModes[category.templateKey] = resolvedMode
            resolvedMode.store(for: category.templateKey)
            return
        }
        if category.templateKey == "movie" {
            let resolvedMode: CategoryLibraryLayoutMode = mode == .banner ? .banner : .gallery
            libraryLayoutModes[category.templateKey] = resolvedMode
            resolvedMode.store(for: category.templateKey)
            return
        }
        guard category.templateKey != "live" else {
            libraryLayoutModes[category.templateKey] = .banner
            return
        }
        libraryLayoutModes[category.templateKey] = mode
        mode.store(for: category.templateKey)
    }

    private func librarySectionTitle(category: RecordCategory, fallback: String) -> String {
        switch category.templateKey {
        case "theater": "Productions"
        case "live": "Live History"
        case "museum": "Exhibitions"
        case "movie": "Library"
        case "sake": "Drinks"
        case "theme_park": "Destinations"
        case "nature_living", "outing_facility": "Places"
        case "book": "Library"
        default: fallback
        }
    }

    private func categoryFeatureCarouselJapaneseTitle(_ category: RecordCategory) -> String {
        switch category.templateKey {
        case "museum": "観覧予定 / 気になる"
        case "live": "ライブ予定 / 気になる"
        case "movie": "鑑賞予定 / 気になる"
        case "theme_park", "nature_living": "来園予定 / 気になる"
        default: "予定 / 気になる"
        }
    }

    private func categorySectionJapaneseTitle(
        for englishTitle: String,
        category: RecordCategory
    ) -> String? {
        switch (category.templateKey, englishTitle) {
        case ("theater", "Coming Up"): "観劇予定"
        case ("theater", "Interests"): "気になる"
        case ("theater", "Performance Log"): "観劇記録"
        case ("theater", "Productions"): "公演情報"
        case ("theater", "Ticket Management"): "チケット管理"
        case ("live", "Coming Up"): "ライブ予定"
        case ("live", "Interests"): "気になる"
        case ("live", "Live History"): "ライブ記録"
        case ("museum", "Coming Up"): "鑑賞予定"
        case ("museum", "Interests"): "気になる"
        case ("museum", "Exhibitions"): "鑑賞済み"
        case ("movie", "Coming Up"): "鑑賞予定"
        case ("movie", "Interests"): "気になる"
        case ("movie", "Library"): "鑑賞済み"
        case ("sake", "Drinks"): "お酒"
        case ("theme_park", "Destinations"): "施設情報"
        case ("theme_park", "Coming Up"): "来園予定"
        case ("theme_park", "Interests"): "気になる"
        case ("nature_living", "Coming Up"), ("outing_facility", "Coming Up"): "体験予定"
        case ("nature_living", "Interests"), ("outing_facility", "Interests"): "気になる"
        case ("nature_living", "Places"), ("outing_facility", "Places"): "施設"
        case ("book", "Interests"): "気になる"
        case ("book", "To Read"): "積読"
        case ("book", "Library"): "本"
        default: nil
        }
    }

    private func libraryPrimaryTextColor(_ category: RecordCategory) -> Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.ivory
        case "live": LiveCategoryStyle.mist
        default: Color.primary
        }
    }

    private func librarySecondaryTextColor(_ category: RecordCategory) -> Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.ivory.opacity(0.62)
        case "live": LiveCategoryStyle.mist.opacity(0.58)
        default: Color.secondary
        }
    }

    private func libraryDisplayKey(
        category: RecordCategory,
        sectionKey: String,
        layout: CategoryLibraryLayoutMode
    ) -> String {
        "\(category.id.uuidString)-\(sectionKey)-\(layout.rawValue)"
    }

    @ViewBuilder
    private func categoryTicketProgressSection(category: RecordCategory) -> some View {
        let items = categoryTicketProgressItems(category: category)
        if category.templateKey == "theater" || !items.isEmpty {
            CategoryTicketProgressSection(
                items: items,
                title: category.templateKey == "theater"
                    ? "Ticket Management"
                    : category.templateKey == "live" ? "Ticket Progress" : "チケット進捗",
                japaneseTitle: category.templateKey == "theater" ? "チケット管理" : nil,
                usesLatinTitle: category.templateKey == "theater" || category.templateKey == "live",
                usesTheaterStyle: category.templateKey == "theater",
                usesLiveStyle: category.templateKey == "live",
                showsCategoryInSelector: false,
                fixedTint: categoryAccent(category)
            )
            .id("ticket-progress-\(category.id.uuidString)")
        }
    }

    private func categoryTicketProgressItems(category: RecordCategory) -> [CategoryTicketProgressItem] {
        let items = CategoryTicketProgressItem.activeItems(in: allPlans, categoryID: category.id)
        guard ["theater", "live"].contains(category.templateKey) else { return items }
        return items.filter { !$0.plan.hasConfirmedSchedule }
    }

    private func categoryLibraryItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryLibraryItem] {
        let now = Date()
        let categoryVisits = resolvedVisits(in: snapshot)
        let eventsByID = resolvedEventsByID(in: snapshot, category: category)
        let visitsByEventID = Dictionary(grouping: categoryVisits) { $0.event?.id }
        let plansByEventID = Dictionary(grouping: allPlans.filter { plan in
            !plan.isArchived
                && (plan.category ?? plan.event?.category)?.id == category.id
                && plan.event != nil
        }) { $0.event?.id }

        let items: [CategoryLibraryItem] = snapshot.events.compactMap {
            eventSnapshot -> CategoryLibraryItem? in
            guard let event = eventsByID[eventSnapshot.id] else { return nil }
            let eventID = eventSnapshot.id
            let latestVisit = visitsByEventID[eventID]?.max(by: { $0.visitedAt < $1.visitedAt })
            let eventPlans = plansByEventID[eventID] ?? []
            let nextPlan = eventPlans
                .filter { $0.isUpcomingOrOngoing(at: now) }
                .min(by: { $0.startsAt < $1.startsAt })
            let attempts = TicketAttemptPresentationOrder.sorted(
                eventPlans.flatMap { $0.ticketAttempts ?? [] }.filter { !$0.isArchived },
                now: now
            )
            let eventVisits = visitsByEventID[eventID] ?? []
            let representativePlace = latestVisit?.placeMaster ?? nextPlan?.placeMaster
            let resolvedFacilityName = representativePlace?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? latestVisit?.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? nextPlan?.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            let facilityName = isPlaceExperienceCategory(category) ? resolvedFacilityName : ""
            let facilityIdentityKey: String
            let aggregatedVisits: [Visit]
            if isPlaceExperienceCategory(category), let placeID = representativePlace?.id {
                facilityIdentityKey = "place|\(placeID.uuidString)"
                aggregatedVisits = categoryVisits.filter { $0.placeMaster?.id == placeID }
            } else if isPlaceExperienceCategory(category), !facilityName.isEmpty {
                let normalizedName = facilityName
                    .folding(
                        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                        locale: Locale(identifier: "ja_JP")
                    )
                    .filter { !$0.isWhitespace }
                facilityIdentityKey = "name|\(normalizedName)"
                aggregatedVisits = categoryVisits.filter { visit in
                    let name = (visit.placeMaster?.name ?? visit.venueNameSnapshot)
                        .folding(
                            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                            locale: Locale(identifier: "ja_JP")
                        )
                        .filter { !$0.isWhitespace }
                    return name == normalizedName
                }
            } else {
                facilityIdentityKey = "event|\(eventID.uuidString)"
                aggregatedVisits = eventVisits
            }
            let aggregatedLatestVisit = aggregatedVisits.max(by: { $0.visitedAt < $1.visitedAt })
            return CategoryLibraryItem(
                event: event,
                visits: aggregatedVisits,
                latestVisit: aggregatedLatestVisit ?? latestVisit,
                nextPlan: nextPlan,
                ticketAttempts: attempts,
                facilityName: facilityName,
                facilityIdentityKey: facilityIdentityKey,
                placeMasterID: representativePlace?.id
            )
        }

        let uniqueItems: [CategoryLibraryItem]
        if isPlaceExperienceCategory(category) {
            uniqueItems = Dictionary(grouping: items, by: \.facilityIdentityKey)
                .values
                .compactMap { matchingItems in
                    matchingItems.max { lhs, rhs in
                        let lhsDate = lhs.displayDate ?? lhs.event.updatedAt
                        let rhsDate = rhs.displayDate ?? rhs.event.updatedAt
                        return lhsDate < rhsDate
                    }
                }
        } else if category.templateKey == "theater" {
            func relationScore(for item: CategoryLibraryItem) -> Int {
                let visitScore = item.latestVisit == nil ? 0 : 4
                let planScore = item.nextPlan == nil ? 0 : 2
                let ticketScore = min(item.ticketAttempts.count, 2)
                return visitScore + planScore + ticketScore
            }

            uniqueItems = Dictionary(grouping: items, by: \.event.productionIdentityKey)
                .values
                .compactMap { matchingItems in
                    matchingItems.max { lhs, rhs in
                        let lhsRelationScore = relationScore(for: lhs)
                        let rhsRelationScore = relationScore(for: rhs)
                        if lhsRelationScore != rhsRelationScore {
                            return lhsRelationScore < rhsRelationScore
                        }
                        return lhs.event.updatedAt < rhs.event.updatedAt
                    }
                }
        } else {
            uniqueItems = items
        }

        return uniqueItems.sorted { lhs, rhs in
            switch (lhs.nextPlan, rhs.nextPlan) {
            case let (.some(left), .some(right)):
                return left.startsAt < right.startsAt
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                let leftDate = lhs.latestVisit?.visitedAt ?? lhs.event.updatedAt
                let rightDate = rhs.latestVisit?.visitedAt ?? rhs.event.updatedAt
                return leftDate > rightDate
            }
        }
    }

    private func categoryVisitRecordLibrarySection(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        tint: Color
    ) -> some View {
        let items = categoryVisitRecordItems(category: category, snapshot: snapshot)
        let isMovie = category.templateKey == "movie"
        let storedLayout = libraryLayoutMode(for: category)
        let layout: CategoryLibraryLayoutMode = storedLayout == .gallery ? .gallery : .banner

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: isMovie ? "Library" : "Museum Log",
                    japaneseTitle: "鑑賞記録",
                    foregroundColor: libraryPrimaryTextColor(category)
                )

                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(librarySecondaryTextColor(category))

                Spacer(minLength: 4)

                CategoryLibraryLayoutPicker(
                    selection: Binding(
                        get: {
                            libraryLayoutMode(for: category) == .gallery ? .gallery : .banner
                        },
                        set: { selectLibraryLayout($0, for: category) }
                    ),
                    tint: tint,
                    modes: isMovie ? [.gallery, .banner] : [.gallery, .banner],
                    onSelect: { _ in }
                )
            }

            if items.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "鑑賞記録はまだありません",
                    message: "鑑賞した記録を追加すると、1回ごとにここへ並びます。",
                    tint: tint
                )
            } else {
                if layout == .gallery {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(items) { item in
                            Button {
                                selectedCategoryDetail = .visit(item.visit.id)
                            } label: {
                                CategoryVisitRecordPosterTile(item: item, category: category)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                        Button {
                            selectedCategoryDetail = .visit(item.visit.id)
                        } label: {
                                CategoryVisitRecordBannerCard(
                                    item: item,
                                    category: category,
                                    tint: tint
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func categoryVisitRecordItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryVisitRecordItem] {
        resolvedVisits(in: snapshot).compactMap { visit in
            guard let event = visit.event,
                  event.category?.id == category.id else { return nil }
            if category.templateKey == "movie",
               !screenWorkFilter.includes(event.screenWorkType) {
                return nil
            }
            return CategoryVisitRecordItem(event: event, visit: visit)
        }
        .sorted { $0.visit.visitedAt > $1.visit.visitedAt }
    }

    private func recentVisits(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近の記録")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(snapshot.visitCount)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if snapshot.visitIDs.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "まだ記録がありません",
                    message: "タイトル、日付、場所、評価、メモだけの軽い記録から始められます。",
                    tint: themePalette.categoryColor(hex: category.colorHex)
                )
            } else {
                ForEach(resolvedVisits(in: snapshot).prefix(10)) { visit in
                    Button {
                        selectedCategoryDetail = .visit(visit.id)
                    } label: {
                        VisitSummaryRow(visit: visit, showsCategory: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func libraryMessage(snapshot: CategoryTopSnapshot) -> String {
        if snapshot.eventCount == 0 {
            return "登録した対象をここへまとめ、体験を重ねていけます。"
        }
        return "\(snapshot.eventCount)件の対象と、\(snapshot.visitCount)件の体験をまとめています。"
    }

    private func categoryBackground(category: RecordCategory) -> some View {
        if category.templateKey == "theater" {
            return AnyView(
                LinearGradient(
                    colors: [
                        TheaterCategoryStyle.wine,
                        TheaterCategoryStyle.deepWine,
                        TheaterCategoryStyle.black,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }

        if category.templateKey == "live" {
            return AnyView(
                LinearGradient(
                    colors: [
                        LiveCategoryStyle.navy,
                        LiveCategoryStyle.deepNavy,
                        LiveCategoryStyle.blackNavy,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }

        return AnyView(
            LinearGradient(
                colors: [
                    themePalette.categoryColor(hex: category.colorHex).opacity(colorScheme == .dark ? 0.12 : 0.10),
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var currentCategory: RecordCategory {
        visibleCategories.first(where: { $0.id == selectedCategoryID }) ?? category
    }

    private func openEventFromDetailPanel(_ eventID: UUID) {
        guard selectedCategoryEventID == nil else { return }
        Task { @MainActor in
            await Task.yield()
            selectedCategoryEventID = eventID
        }
    }

    private func categoryDisplayName(_ category: RecordCategory) -> String {
        if category.templateKey == "live" { return "LIVE" }
        return category.name.isEmpty ? "ジャンル" : category.name
    }

    private func categoryAccent(_ category: RecordCategory) -> Color {
        category.templateKey == "live"
            ? LiveCategoryStyle.teal
            : themePalette.categoryColor(hex: category.colorHex)
    }

    private func supportsVisitedPlacesMap(_ category: RecordCategory) -> Bool {
        ["museum", "live", "outing_facility", "theme_park", "nature_living"].contains(category.templateKey)
    }

    private func usesAtmosphericDarkStyle(_ category: RecordCategory) -> Bool {
        category.templateKey == "theater" || category.templateKey == "live"
    }

    private func categoryBrandGradient(_ category: RecordCategory) -> LinearGradient? {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.brandGradient
        case "live": LiveCategoryStyle.brandGradient
        default: nil
        }
    }

    private func categoryHeaderForeground(_ category: RecordCategory) -> Color? {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.ivory
        case "live": LiveCategoryStyle.mist
        default: nil
        }
    }

    private var visibleCategories: [RecordCategory] {
        allCategories.filter { !$0.isArchived }
    }

    private func resolvedVisits(in snapshot: CategoryTopSnapshot) -> [Visit] {
        resolutionCache.resolvedVisits(snapshot: snapshot, allVisits: allVisits)
    }

    private func resolvedEvents(
        in snapshot: CategoryTopSnapshot,
        category: RecordCategory? = nil
    ) -> [ExperienceEvent] {
        resolutionCache.resolvedEvents(
            snapshot: snapshot,
            category: category ?? currentCategory
        )
    }

    private func resolvedEventsByID(
        in snapshot: CategoryTopSnapshot,
        category: RecordCategory? = nil
    ) -> [UUID: ExperienceEvent] {
        resolutionCache.resolvedEventsByID(
            snapshot: snapshot,
            category: category ?? currentCategory
        )
    }

    private func switchCategory(to destination: RecordCategory) {
        guard destination.id != currentCategory.id else { return }
        if destination.templateKey == "goshuin" {
            selectedGoshuinHeroIndex = 0
        }
        isShowingAllTheaterVisits = false

        selectedCategoryID = destination.id
        homeSelectedCategoryTemplateKey = destination.templateKey
        if libraryLayoutModes[destination.templateKey] == nil {
            libraryLayoutModes[destination.templateKey] = CategoryLibraryLayoutMode.stored(for: destination.templateKey)
        }
        createEntryContextRouter.activate(categoryID: destination.id)
    }

    private func reconcileCategoryAfterSettings() {
        guard !visibleCategories.contains(where: { $0.id == selectedCategoryID }) else { return }
        guard let replacement = visibleCategories.first else {
            dismiss()
            return
        }
        switchCategory(to: replacement)
    }

    private func neighboringCategory(from category: RecordCategory, offset: Int) -> RecordCategory? {
        guard let index = visibleCategories.firstIndex(where: { $0.id == category.id }) else { return nil }
        let destinationIndex = index + offset
        guard visibleCategories.indices.contains(destinationIndex) else { return nil }
        return visibleCategories[destinationIndex]
    }

    @ViewBuilder
    private func chapterFooter(
        categories: [RecordCategory],
        currentCategory: RecordCategory,
        onSelect: @escaping (RecordCategory) -> Void
    ) -> some View {
        if let currentIndex = categories.firstIndex(where: { $0.id == currentCategory.id }) {
            let previousCategory = currentIndex > categories.startIndex ? categories[currentIndex - 1] : nil
            let nextIndex = currentIndex + 1
            let nextCategory = categories.indices.contains(nextIndex) ? categories[nextIndex] : nil

            VStack(alignment: .leading, spacing: 18) {
                if previousCategory != nil || nextCategory != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("別の章へ")
                            .font(FavorecoTypography.sectionTitle)

                        HStack(alignment: .top, spacing: 12) {
                            if let previousCategory {
                                ChapterPreviewCard(
                                    directionTitle: "前の章",
                                    category: previousCategory,
                                    isNext: false,
                                    action: { onSelect(previousCategory) }
                                )
                            }

                            if let nextCategory {
                                ChapterPreviewCard(
                                    directionTitle: "次の章",
                                    category: nextCategory,
                                    isNext: true,
                                    action: { onSelect(nextCategory) }
                                )
                            }
                        }
                    }
                }

                Button {
                    isShowingCategorySettings = true
                } label: {
                    HStack(spacing: 12) {
                        FavorecoIcon(systemName: "gearshape", size: 20)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(categoryDisplayName(currentCategory))の設定")
                                .font(FavorecoTypography.bodyStrong)
                            Text("表示名・色・記録項目を変更")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        FavorecoIcon(systemName: "chevron.right", size: 15, fallbackWeight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(categoryAccent(currentCategory))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground).opacity(0.92))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(categoryAccent(currentCategory).opacity(0.28), lineWidth: 0.8)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("このジャンルの設定画面を開きます")
            }
        }
    }
}

struct CategoryEventDestination: View {
    @Query private var events: [ExperienceEvent]

    init(eventID: UUID) {
        _events = Query(filter: #Predicate<ExperienceEvent> { $0.id == eventID })
    }

    var body: some View {
        if let event = events.first {
            EventDetailView(event: event)
        } else {
            FavorecoContentUnavailableView("対象が見つかりません", systemImage: "trash")
        }
    }
}

private enum CategoryDetailPanelSelection: Identifiable, Equatable {
    case plan(UUID)
    case visit(UUID)

    var id: String {
        switch self {
        case .plan(let id): return "plan-\(id.uuidString)"
        case .visit(let id): return "visit-\(id.uuidString)"
        }
    }
}

struct CategoryDetailSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct CategoryDetailPanelOverlay: View {
    let selection: CategoryDetailPanelSelection
    let onClose: () -> Void
    let onOpenEvent: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false
    @State private var swipeExclusionFrames: [CGRect] = []

    var body: some View {
        GeometryReader { proxy in
            let swipeProgress = min(max(dragOffset / 300, 0), 1)

            ZStack {
                Color.black.opacity(0.62 * (1 - Double(swipeProgress) * 0.45))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                Group {
                    switch selection {
                    case .plan(let planID):
                        CategoryPlanDestination(
                            planID: planID,
                            onBack: onClose,
                            onOpenEvent: onOpenEvent
                        )
                    case .visit(let visitID):
                        CategoryVisitDestination(
                            visitID: visitID,
                            onBack: onClose,
                            onOpenEvent: onOpenEvent,
                            onOpenVisit: onOpenVisit
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: max(dragOffset, 0))
                .rotationEffect(
                    .degrees(Double(swipeProgress) * 12),
                    anchor: .bottomLeading
                )
                .opacity(1 - Double(swipeProgress) * 0.4)
                .simultaneousGesture(
                    dismissGesture(containerWidth: proxy.size.width),
                    including: .all
                )
            }
        }
        .ignoresSafeArea()
        .zIndex(100)
        .accessibilityElement(children: .contain)
        .onPreferenceChange(CategoryDetailSwipeExclusionPreferenceKey.self) { frames in
            swipeExclusionFrames = frames.filter { !$0.isEmpty && !$0.isNull }
        }
    }

    private func dismissGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onChanged { value in
                guard !isDismissing else { return }
                guard value.startLocation.x <= containerWidth * 0.72 else { return }
                guard !startsInsideSwipeExclusion(value.startLocation) else { return }

                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 0, horizontal > vertical * 1.35 else { return }
                dragOffset = horizontal
            }
            .onEnded { value in
                guard !isDismissing else { return }
                guard value.startLocation.x <= containerWidth * 0.72 else { return }
                guard !startsInsideSwipeExclusion(value.startLocation) else {
                    dragOffset = 0
                    return
                }

                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                let predictedHorizontal = value.predictedEndTranslation.width
                let isHorizontalSwipe = horizontal > 0 && horizontal > vertical * 1.35

                if isHorizontalSwipe,
                   (horizontal > 80 || predictedHorizontal > 420) {
                    isDismissing = true
                    withAnimation(.easeOut(duration: 0.28)) {
                        dragOffset = max(containerWidth, 1) * 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            onClose()
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func startsInsideSwipeExclusion(_ location: CGPoint) -> Bool {
        swipeExclusionFrames.contains { $0.contains(location) }
    }
}

struct CategoryVisitDestination: View {
    @Query private var visits: [Visit]
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?
    let onOpenVisit: ((UUID) -> Void)?

    init(
        visitID: UUID,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil,
        onOpenVisit: ((UUID) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
        self.onOpenVisit = onOpenVisit
        _visits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

    var body: some View {
        if let visit = visits.first {
            ExperienceDetailView(
                visit: visit,
                onBack: onBack,
                onOpenEvent: onOpenEvent,
                onOpenVisit: onOpenVisit
            )
        } else {
            FavorecoContentUnavailableView("記録が見つかりません", systemImage: "trash")
        }
    }
}

private struct CategoryPlanDestination: View {
    @Query private var plans: [Plan]
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?

    init(
        planID: UUID,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(
                plan: plan,
                onBack: onBack,
                onOpenEvent: onOpenEvent
            )
        } else {
            FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
        }
    }
}

struct GenreSwipeContainer<Content: View>: View {
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onMove: (Int) -> Void
    @ViewBuilder let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var isMoveLocked = false

    var body: some View {
        content
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .background {
                GeometryReader { geometry in
                    DirectionalHorizontalPanInstaller(
                        onBegan: {},
                        onChanged: { translation in
                            guard !isMoveLocked else { return }
                            let direction = translation < 0 ? 1 : -1
                            let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
                            dragOffset = hasDestination ? translation : translation * 0.18
                        },
                        onEnded: { translation, velocity in
                            finishGesture(translation: translation, velocity: velocity)
                        },
                        onCancelled: {
                            settleBack()
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
    }

    private func finishGesture(translation: CGFloat, velocity: CGFloat) {
        guard !isMoveLocked else {
            settleBack()
            return
        }

        let projectedTranslation = translation + velocity * 0.16
        let direction = translation < 0 ? 1 : -1
        let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
        let shouldMove = abs(translation) >= 72 || abs(projectedTranslation) >= 140

        if shouldMove && hasDestination {
            isMoveLocked = true
            dragOffset = 0
            onMove(direction)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                isMoveLocked = false
            }
        } else {
            settleBack()
        }
    }

    private func settleBack() {
        withAnimation(.timingCurve(0.18, 0.78, 0.24, 1, duration: 0.18)) {
            dragOffset = 0
        }
    }

}

struct GenreSwipeExclusionZone: View {
    var body: some View {
        GenreSwipeExclusionMarker()
            .allowsHitTesting(false)
    }
}

enum GenreSwipeGestureCoordination {
    static let activationDistance: CGFloat = 24

    static func hasReachedActivationDistance(_ translation: CGPoint) -> Bool {
        hypot(translation.x, translation.y) >= activationDistance
    }

    static func allowsSimultaneousRecognition(
        with otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }
}

private struct GenreSwipeExclusionMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        GenreSwipeExclusionMarkerView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

@MainActor
private final class GenreSwipeExclusionMarkerView: UIView {}

private struct DirectionalHorizontalPanInstaller: UIViewRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = HierarchyAwareMarkerView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onHierarchyChange = { [weak coordinator = context.coordinator] markerView in
            coordinator?.installIfNeeded(from: markerView)
        }
        context.coordinator.markerView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
        context.coordinator.markerView = uiView
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        (uiView as? HierarchyAwareMarkerView)?.onHierarchyChange = nil
        coordinator.uninstall()
    }

    @MainActor
    final class HierarchyAwareMarkerView: UIView {
        var onHierarchyChange: ((UIView) -> Void)?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            onHierarchyChange?(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onHierarchyChange?(self)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var markerView: UIView?
        private weak var installedView: UIView?
        private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
            let recognizer = IntentionalGenrePanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = true
            recognizer.delaysTouchesBegan = false
            recognizer.maximumNumberOfTouches = 1
            return recognizer
        }()

        private var onBegan: () -> Void
        private var onChanged: (CGFloat) -> Void
        private var onEnded: (CGFloat, CGFloat) -> Void
        private var onCancelled: () -> Void

        init(
            onBegan: @escaping () -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func update(
            onBegan: @escaping () -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func installIfNeeded(from markerView: UIView) {
            var ancestor = markerView.superview
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            guard let scrollView = ancestor else { return }
            guard installedView !== scrollView else { return }
            uninstall()
            scrollView.addGestureRecognizer(panGestureRecognizer)
            installedView = scrollView
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(panGestureRecognizer)
            installedView = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let installedView,
                  let markerView else { return false }

            let location = pan.location(in: installedView)
            let activeFrame = markerView.convert(markerView.bounds, to: installedView)
            guard activeFrame.contains(location) else { return false }
            guard !containsExclusionZone(at: location, in: installedView) else { return false }

            if let touchedView = installedView.hitTest(location, with: nil) {
                if isInsideNestedHorizontalScrollView(touchedView, outerScrollView: installedView)
                    || isInsideMapView(touchedView, outerScrollView: installedView) {
                    return false
                }
            }

            let velocity = pan.velocity(in: installedView)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }

            if let window = installedView.window {
                let windowLocation = pan.location(in: window)
                guard windowLocation.x >= 24, windowLocation.x <= window.bounds.width - 24 else { return false }
            }
            return true
        }

        private func containsExclusionZone(at location: CGPoint, in rootView: UIView) -> Bool {
            var pendingViews = rootView.subviews
            while let view = pendingViews.popLast() {
                if let marker = view as? GenreSwipeExclusionMarkerView {
                    let frame = marker.convert(marker.bounds, to: rootView)
                    if frame.contains(location) {
                        return true
                    }
                }
                pendingViews.append(contentsOf: view.subviews)
            }
            return false
        }

        private func isInsideNestedHorizontalScrollView(
            _ touchedView: UIView,
            outerScrollView: UIView
        ) -> Bool {
            var candidate: UIView? = touchedView
            while let view = candidate, view !== outerScrollView {
                if let scrollView = view as? UIScrollView,
                   scrollView.contentSize.width > scrollView.bounds.width + 1 {
                    return true
                }
                candidate = view.superview
            }
            return false
        }

        private func isInsideMapView(
            _ touchedView: UIView,
            outerScrollView: UIView
        ) -> Bool {
            var candidate: UIView? = touchedView
            while let view = candidate, view !== outerScrollView {
                if view is MKMapView { return true }
                candidate = view.superview
            }
            return false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            GenreSwipeGestureCoordination.allowsSimultaneousRecognition(
                with: otherGestureRecognizer
            )
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: installedView).x
            let velocity = recognizer.velocity(in: installedView).x
            switch recognizer.state {
            case .began:
                onBegan()
            case .changed:
                onChanged(translation)
            case .ended:
                onEnded(translation, velocity)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }
    }
}

@MainActor
private final class IntentionalGenrePanGestureRecognizer: UIPanGestureRecognizer {
    private var initialLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        initialLocation = touches.first?.location(in: view)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible,
           let initialLocation,
           let currentLocation = touches.first?.location(in: view) {
            let translation = CGPoint(
                x: currentLocation.x - initialLocation.x,
                y: currentLocation.y - initialLocation.y
            )
            guard GenreSwipeGestureCoordination.hasReachedActivationDistance(translation) else {
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        initialLocation = nil
        super.reset()
    }
}

private enum CategoryScrollAnchor {
    static let top = "category-top"
    static let events = "category-events"
    static let recentVisits = "category-recent-visits"
}

struct CategoryTicketProgressItem: Identifiable {
    let plan: Plan
    let attempt: TicketAttempt

    var id: UUID { attempt.id }

    var title: String {
        if !plan.title.isEmpty { return plan.title }
        if let eventTitle = plan.event?.title, !eventTitle.isEmpty { return eventTitle }
        return "公演"
    }

    var selectorTitle: String {
        guard plan.hasConfirmedSchedule else {
            return plan.venueNameSnapshot.isEmpty ? "参加日未定" : "参加日未定 \(plan.venueNameSnapshot)"
        }
        let date = FavorecoDateText.monthDay(plan.startsAt)
        return plan.venueNameSnapshot.isEmpty ? date : "\(date) \(plan.venueNameSnapshot)"
    }

    var crossGenreSelectorTitle: String {
        let categoryName = (plan.category ?? plan.event?.category)?.name ?? "ジャンル"
        return "\(categoryName)・\(selectorTitle)"
    }

    var categoryColorHex: String {
        (plan.category ?? plan.event?.category)?.colorHex ?? "#147C88"
    }

    var metadataChips: [String] {
        var values = plan.hasConfirmedSchedule
            ? [FavorecoDateText.compactDateTime(plan.startsAt)]
            : ["参加日未定"]
        if !plan.venueNameSnapshot.isEmpty {
            values.append(plan.venueNameSnapshot)
        }
        if !attempt.entryRouteKey.isEmpty {
            values.append(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
        }
        if !attempt.ticketSite.isEmpty {
            values.append(attempt.ticketSite)
        }
        values.append(contentsOf: TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames)

        var seen = Set<String>()
        return values.filter { value in
            let normalized = value.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            return !value.isEmpty && seen.insert(normalized).inserted
        }
    }

    var stages: [TicketProgressStage] {
        TicketProgressTimeline.stages(for: attempt, plan: plan)
    }

    var currentStageIndex: Int {
        TicketProgressTimeline.currentIndex(for: attempt, stages: stages)
    }

    static func activeItems(in plans: [Plan], categoryID: UUID? = nil) -> [CategoryTicketProgressItem] {
        let items = plans
            .filter { plan in
                guard !plan.isArchived else { return false }
                guard let categoryID else { return true }
                return (plan.category ?? plan.event?.category)?.id == categoryID
            }
            .flatMap { plan in
                (plan.ticketAttempts ?? []).compactMap { attempt -> CategoryTicketProgressItem? in
                    guard !attempt.isArchived,
                          !["interested", "lost", "attended", "skipped"].contains(attempt.statusKey) else {
                        return nil
                    }
                    return CategoryTicketProgressItem(plan: plan, attempt: attempt)
                }
            }

        return TicketAttemptPresentationOrder.sorted(items.map(\.attempt)).compactMap { sortedAttempt in
            items.first(where: { $0.attempt.id == sortedAttempt.id })
        }
    }

}

struct LayeredCategorySectionTitle: View {
    let englishTitle: String
    let japaneseTitle: String
    let foregroundColor: Color

    private var displayedJapaneseTitle: String {
        let normalizedTitle = String(japaneseTitle.filter { !$0.isWhitespace })
        guard normalizedTitle.count <= 5 else { return normalizedTitle }
        return normalizedTitle.map(String.init).joined(separator: " ")
    }

    var body: some View {
        Text(englishTitle)
            .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(foregroundColor)
            .background(alignment: .leading) {
                Text(displayedJapaneseTitle)
                    .font(FavorecoTypography.jpSerif(20, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(foregroundColor.opacity(0.18))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .offset(x: 17, y: -10)
                    .allowsHitTesting(false)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(japaneseTitle)
    }
}

struct CategoryTicketProgressSection: View {
    let items: [CategoryTicketProgressItem]
    let title: String
    let japaneseTitle: String?
    let usesLatinTitle: Bool
    let usesTheaterStyle: Bool
    let usesLiveStyle: Bool
    let showsCategoryInSelector: Bool
    let fixedTint: Color?

    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedAttemptID: UUID?
    @State private var quickActionAttempt: TicketAttempt?
    @State private var editingAttempt: TicketAttempt?
    @State private var isShowingTicketOverview = false

    init(
        items: [CategoryTicketProgressItem],
        title: String,
        japaneseTitle: String? = nil,
        usesLatinTitle: Bool,
        usesTheaterStyle: Bool,
        usesLiveStyle: Bool = false,
        showsCategoryInSelector: Bool,
        fixedTint: Color? = nil
    ) {
        self.items = items
        self.title = title
        self.japaneseTitle = japaneseTitle
        self.usesLatinTitle = usesLatinTitle
        self.usesTheaterStyle = usesTheaterStyle
        self.usesLiveStyle = usesLiveStyle
        self.showsCategoryInSelector = showsCategoryInSelector
        self.fixedTint = fixedTint
        _selectedAttemptID = State(initialValue: items.first?.id)
    }

    private var selectedItem: CategoryTicketProgressItem? {
        items.first(where: { $0.id == selectedAttemptID }) ?? items.first
    }

    private var tint: Color {
        if let fixedTint { return fixedTint }
        return themePalette.categoryColor(hex: selectedItem?.categoryColorHex ?? "#147C88")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if usesLatinTitle, let japaneseTitle {
                    LayeredCategorySectionTitle(
                        englishTitle: title,
                        japaneseTitle: japaneseTitle,
                        foregroundColor: primaryTextColor
                    )
                } else {
                    Text(title)
                        .font(sectionTitleFont)
                        .foregroundStyle(primaryTextColor)
                }

                Spacer(minLength: 8)

                Button {
                    isShowingTicketOverview = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(actionTint)
                }
                .buttonStyle(.plain)
                .frame(alignment: .trailing)
            }

            if items.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(items) { item in
                            selectorButton(for: item)
                        }
                    }
                }
                .clipped()
            }

            if let selectedItem {
                VStack(spacing: 0) {
                    Button {
                        quickActionAttempt = selectedItem.attempt
                    } label: {
                        CategoryTicketProgressCard(
                            item: selectedItem,
                            tint: tint,
                            isTheater: usesTheaterStyle,
                            isLive: usesLiveStyle,
                            showsFrame: false
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(tint.opacity(0.22))
                        .padding(.horizontal, 9)

                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            editingAttempt = selectedItem.attempt
                        } label: {
                            FavorecoIconLabel("日付編集", systemImage: "pencil", iconSize: 13)
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(actionTint)
                                .frame(minHeight: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("申込日、当落日、支払期限、取得日を編集します")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 5)
                }
                .background(ticketProgressCardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            tint.opacity(usesTheaterStyle || usesLiveStyle ? 0.48 : 0.20),
                            lineWidth: usesTheaterStyle || usesLiveStyle ? 0.7 : 0.75
                        )
                }
                .id(selectedItem.id)
                .transition(.opacity)
            } else if usesTheaterStyle {
                HStack(spacing: 10) {
                    FavorecoIcon(systemName: "checkmark.circle", size: 17)
                        .foregroundStyle(tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("参加日未定のチケットはありません")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(primaryTextColor)
                        Text("日程が決まったチケットは Coming Up に表示されます")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.20), lineWidth: 0.8)
                }
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if let selectedAttemptID, ids.contains(selectedAttemptID) { return }
            self.selectedAttemptID = ids.first
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
        .sheet(item: $editingAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt, prioritizesDates: true)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingTicketOverview) {
            NavigationStack {
                TicketOverviewView(
                    showsCloseButton: true,
                    initialFilter: usesTheaterStyle ? .undated : .needsAction
                )
            }
        }
    }

    private var primaryTextColor: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.ivory }
        if usesLiveStyle { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var secondaryTextColor: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.ivory.opacity(0.68) }
        if usesLiveStyle { return LiveCategoryStyle.mist.opacity(0.62) }
        return Color.secondary
    }

    private var ticketProgressCardBackground: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.tileBackground }
        if usesLiveStyle { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground)
    }

    private var actionTint: Color {
        usesTheaterStyle ? TheaterCategoryStyle.ticketActionRose : tint
    }

    private func selectorButton(for item: CategoryTicketProgressItem) -> some View {
        let isSelected = selectedAttemptID == item.id
        let selectorTitle = showsCategoryInSelector
            ? item.crossGenreSelectorTitle
            : item.selectorTitle

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedAttemptID = item.id
            }
        } label: {
            Text(selectorTitle)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(isSelected ? Color.white : actionTint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(isSelected ? actionTint : actionTint.opacity(0.12), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(actionTint.opacity(isSelected ? 0 : 0.48), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(selectorTitle)のチケット状況")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sectionTitleFont: Font {
        usesLatinTitle
            ? FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3)
            : FavorecoTypography.sectionTitle
    }
}

struct CategoryTicketProgressCard: View {
    let item: CategoryTicketProgressItem
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    var showsFrame = true

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 7) {
            Text(item.title)
                .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(item.metadataChips, id: \.self) { chip in
                        let isAttention = isTheater && chip == "参加日未定"
                        let chipTint = isTheater ? TheaterCategoryStyle.ticketMetadataRose : tint
                        Text(chip)
                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                            .foregroundStyle(isAttention ? TicketProgressColorPalette.scheduleUndated : chipTint)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(
                                isAttention
                                    ? TicketProgressColorPalette.scheduleUndated.opacity(0.18)
                                    : chipTint.opacity(isTheater ? 0.15 : 0.10),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        isAttention
                                            ? TicketProgressColorPalette.scheduleUndated.opacity(0.82)
                                            : chipTint.opacity(isTheater ? 0.56 : 0.28),
                                        lineWidth: 1
                                    )
                            }
                    }
                }
            }
            .clipped()

            TicketProgressTimelineView(
                stages: item.stages,
                currentIndex: item.currentStageIndex,
                nodeBackground: cardBackground,
                secondaryTextColor: secondaryTextColor,
                completedTint: TicketProgressColorPalette.completedNeutral
            )
        }
        .padding(9)

        if showsFrame {
            content
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            tint.opacity(isTheater || isLive ? 0.48 : 0.20),
                            lineWidth: isTheater || isLive ? 0.7 : 0.75
                        )
                }
        } else {
            content
        }
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground)
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.68) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.62) }
        return Color.secondary
    }
}

struct TicketProgressTimelineView: View {
    let stages: [TicketProgressStage]
    let currentIndex: Int
    let nodeBackground: Color
    let secondaryTextColor: Color
    var currentTint: Color? = nil
    var completedTint: Color? = nil
    var nodeDiameter: CGFloat = 34
    var nodeTextSize: CGFloat = 9
    var emphasizesCurrentDate = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                GeometryReader { geometry in
                    let stageColor = TicketProgressColorPalette.color(for: stage)
                    let state = nodeState(at: index)
                    let nodeTint = switch state {
                    case .completed: completedTint ?? stageColor
                    case .current: currentTint ?? stageColor
                    case .future: stageColor
                    }
                    let dateWeight: Font.Weight = emphasizesCurrentDate
                        && state == .current
                        && stage.date != nil
                        ? .semibold
                        : .medium
                    ZStack(alignment: .top) {
                        if index < stages.count - 1 {
                            TicketProgressConnectorShape()
                                .stroke(
                                    index < currentIndex
                                        ? (completedTint ?? stageColor)
                                        : secondaryTextColor.opacity(0.54),
                                    style: StrokeStyle(
                                        lineWidth: 1.5,
                                        lineCap: .round,
                                        dash: index < currentIndex ? [] : [2.5, 3.5]
                                    )
                                )
                                .frame(
                                    width: max(0, geometry.size.width - nodeDiameter),
                                    height: 2
                                )
                                .position(x: geometry.size.width, y: nodeDiameter / 2)
                        }

                        VStack(spacing: 3) {
                            TicketProgressNode(
                                title: stage.title,
                                state: state,
                                tint: nodeTint,
                                background: nodeBackground,
                                diameter: nodeDiameter,
                                textSize: nodeTextSize
                            )

                            Group {
                                if let date = stage.date {
                                    Text(FavorecoDateText.monthDay(date))
                                } else {
                                    Text("—")
                                }
                            }
                                .font(FavorecoTypography.jpSans(9, weight: dateWeight, relativeTo: .caption2))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                        .frame(width: geometry.size.width)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 52)
        .accessibilityElement(children: .combine)
    }

    private func nodeState(at index: Int) -> TicketProgressNode.State {
        if index < currentIndex { return .completed }
        if index == currentIndex { return .current }
        return .future
    }
}

private struct TicketProgressNode: View {
    enum State: Equatable {
        case completed
        case current
        case future
    }

    let title: String
    let state: State
    let tint: Color
    let background: Color
    let diameter: CGFloat
    let textSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(state == .future ? background : tint)

            if state == .future {
                Circle()
                    .stroke(Color.secondary.opacity(0.52), lineWidth: 1.5)
            }

            Text(title)
                .font(FavorecoTypography.jpSans(textSize, weight: .semibold, relativeTo: .caption2))
                .foregroundStyle(state == .future ? Color.primary : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct TicketProgressConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private enum BookLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case interested
    case toRead
    case reading
    case read

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .interested: "気になる"
        case .toRead: "積読"
        case .reading: "読書中"
        case .read: "読了"
        }
    }

    var englishTitle: String {
        switch self {
        case .all: "Library"
        case .interested: "Interests"
        case .toRead: "To Read"
        case .reading: "Reading"
        case .read: "Read"
        }
    }
}

private enum BookSeriesSort: String, CaseIterable, Identifiable {
    case volumeAscending
    case volumeDescending
    case recentlyRead
    case recentlyAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volumeAscending: "巻数が小さい順"
        case .volumeDescending: "巻数が大きい順"
        case .recentlyRead: "最近読んだ順"
        case .recentlyAdded: "最近登録した順"
        }
    }
}

private struct BookSeriesRoute: Identifiable, Hashable {
    let categoryID: UUID
    let seriesName: String
    let normalizedSeriesName: String

    var id: String { "\(categoryID.uuidString)|\(normalizedSeriesName)" }
}

private struct BookLibraryEntry: Identifiable {
    let items: [CategoryLibraryItem]
    let seriesName: String?

    var id: String {
        if let seriesName {
            return "series|\(normalizedBookText(seriesName))"
        }
        return "book|\(items[0].event.id.uuidString)"
    }

    var representative: CategoryLibraryItem {
        guard seriesName != nil else { return items[0] }
        let numberedItems = items.compactMap { item -> (item: CategoryLibraryItem, volume: Double)? in
            guard let volume = bookVolumeNumericValue(item.event.bookVolumeNumber) else { return nil }
            return (item, volume)
        }
        if let latest = numberedItems.max(by: { $0.volume < $1.volume }) {
            return latest.item
        }
        return items.max(by: { $0.event.createdAt < $1.event.createdAt }) ?? items[0]
    }
    var title: String { seriesName ?? representative.title }
    var readCount: Int { items.filter { bookStatus(for: $0) == .read }.count }

    /// 「すべて」でシリーズを1枚に集約する場合は、次に対応が必要な状態を優先する。
    /// 単巻はその本自身の状態をそのまま返す。
    var displayStatus: BookLibraryFilter {
        guard seriesName != nil else { return bookStatus(for: representative) }
        let statuses = items.map(bookStatus(for:))
        if statuses.contains(.reading) { return .reading }
        if statuses.contains(.toRead) { return .toRead }
        if statuses.contains(.interested) { return .interested }
        return .read
    }

    /// 書影は、気になる／積読から読書記録を追加した後も共有する
    /// 親の本（ExperienceEvent）の正本画像を常に使う。
    var eyecatchReference: ThumbnailReference {
        .event(representative.event.id)
    }

    var volumeBadgeText: String {
        guard seriesName != nil else { return representative.event.bookVolumeLabel }
        if let volume = bookVolumeNumericValue(representative.event.bookVolumeNumber) {
            return volume.rounded() == volume ? String(Int(volume)) : String(format: "%g", volume)
        }
        return "\(items.count)"
    }
}

private struct BookYearStatusStrip: View {
    let items: [CategoryLibraryItem]
    let tint: Color

    private var currentYearReadCount: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return items
            .flatMap(\.visits)
            .filter { visit in
                let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
                let completedAt = fields.bookReadingHasEndDate == false ? visit.visitedAt : visit.endedAt
                return fields.bookReadingHasEndDate != false
                    && calendar.component(.year, from: completedAt) == year
            }
            .count
    }

    private var interestedCount: Int {
        items.filter { bookStatus(for: $0) == .interested }.count
    }

    private var toReadCount: Int {
        items.filter { bookStatus(for: $0) == .toRead }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            metric(title: "今年", value: "\(currentYearReadCount)", unit: "冊/年")
            divider
            metric(title: "気になる", value: "\(interestedCount)", unit: "冊")
            divider
            metric(title: "積読", value: "\(toReadCount)", unit: "冊")
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今年の読了\(currentYearReadCount)冊、気になる\(interestedCount)冊、積読\(toReadCount)冊")
    }

    private func metric(title: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(FavorecoTypography.jpSerif(22, weight: .medium, relativeTo: .title3))
                .foregroundStyle(tint.opacity(0.88))
            Text(unit)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .minimumScaleFactor(0.82)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.20))
            .frame(width: 0.6, height: 20)
    }
}

private struct BookTypeStat: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

private struct BookTagStat: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

private struct BookReadingInsightsSection: View {
    let items: [CategoryLibraryItem]
    let tint: Color
    let selectedTag: String?
    let onSelectTag: (String) -> Void
    let onResetTag: () -> Void

    private var typeStats: [BookTypeStat] {
        let counts = Dictionary(grouping: items) { item in
            let key = VisitUnitFields(rawValue: item.event.unitFieldsRaw).eyecatchAspectRatioKey
            let resolved = EyecatchAspectRatio.option(for: key, category: item.event.category)
            return resolved == .bookCover ? "その他" : resolved.name
        }
        return counts
            .map { BookTypeStat(name: $0.key, count: $0.value.count) }
            .sorted {
                $0.count == $1.count
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : $0.count > $1.count
            }
    }

    private var tagStats: [BookTagStat] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .month, value: -6, to: Date()) ?? .distantPast
        var counts: [String: (name: String, count: Int)] = [:]

        for visit in items.flatMap(\.visits) {
            let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            let completedAt = fields.bookReadingHasEndDate == false ? visit.visitedAt : visit.endedAt
            guard fields.bookReadingHasEndDate != false, completedAt >= cutoff else { continue }
            for name in TheaterEmotionTags.names(from: visit.tagNamesRaw) {
                let key = normalizedBookText(name)
                guard !key.isEmpty else { continue }
                let current = counts[key]
                counts[key] = (current?.name ?? name, (current?.count ?? 0) + 1)
            }
        }

        return counts.values
            .map { BookTagStat(name: $0.name, count: $0.count) }
            .sorted {
                $0.count == $1.count
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : $0.count > $1.count
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LayeredCategorySectionTitle(
                englishTitle: "Reading Insights",
                japaneseTitle: "読書の傾向",
                foregroundColor: .primary
            )

            if typeStats.isEmpty && tagStats.isEmpty {
                EmptyStateMessage(
                    icon: "chart.pie",
                    title: "集計できる読書記録はまだありません",
                    message: "本の種類や読了記録のタグを追加すると、ここに傾向が表示されます。",
                    tint: tint
                )
            } else {
                if !typeStats.isEmpty {
                    BookTypeDistributionCard(stats: typeStats, tint: tint)
                }

                if !tagStats.isEmpty {
                    BookTagConstellationCard(
                        stats: Array(tagStats.prefix(18)),
                        tint: tint,
                        selectedTag: selectedTag,
                        onReset: onResetTag,
                        onSelect: onSelectTag
                    )
                }
            }
        }
        .padding(.top, 8)
    }
}

private struct BookTypeDistributionCard: View {
    let stats: [BookTypeStat]
    let tint: Color

    private var total: Int { stats.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本の種類")
                .font(FavorecoTypography.bodyStrong)

            HStack(spacing: 18) {
                ZStack {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        Circle()
                            .trim(from: startFraction(for: index), to: endFraction(for: index))
                            .stroke(
                                color(for: index),
                                style: StrokeStyle(lineWidth: 17, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 0) {
                        Text("\(total)")
                            .font(FavorecoTypography.jpSerif(24, weight: .semibold, relativeTo: .title3))
                        Text("冊")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("本の種類、合計\(total)冊")

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(color(for: index))
                                .frame(width: 8, height: 8)
                            Text(stat.name)
                                .font(FavorecoTypography.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(stat.count)冊")
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.22), lineWidth: 0.7)
        }
    }

    private func startFraction(for index: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(stats.prefix(index).reduce(0) { $0 + $1.count }) / CGFloat(total)
    }

    private func endFraction(for index: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(stats.prefix(index + 1).reduce(0) { $0 + $1.count }) / CGFloat(total)
    }

    private func color(for index: Int) -> Color {
        let opacity = max(0.28, 0.96 - Double(index) * 0.11)
        return tint.opacity(opacity)
    }
}

private struct BookTagConstellationCard: View {
    let stats: [BookTagStat]
    let tint: Color
    let selectedTag: String?
    let onReset: () -> Void
    let onSelect: (String) -> Void

    private let positions: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.48), CGPoint(x: 0.23, y: 0.30), CGPoint(x: 0.76, y: 0.28),
        CGPoint(x: 0.73, y: 0.69), CGPoint(x: 0.27, y: 0.72), CGPoint(x: 0.48, y: 0.18),
        CGPoint(x: 0.48, y: 0.82), CGPoint(x: 0.12, y: 0.53), CGPoint(x: 0.88, y: 0.50),
        CGPoint(x: 0.13, y: 0.17), CGPoint(x: 0.88, y: 0.16), CGPoint(x: 0.88, y: 0.84),
        CGPoint(x: 0.12, y: 0.85), CGPoint(x: 0.35, y: 0.48), CGPoint(x: 0.64, y: 0.48),
        CGPoint(x: 0.37, y: 0.88), CGPoint(x: 0.65, y: 0.88), CGPoint(x: 0.64, y: 0.10),
    ]

    private var maximumCount: Int { max(stats.map(\.count).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("この6か月に読んだ世界")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                if selectedTag != nil {
                    Button("リセット", action: onReset)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .buttonStyle(.plain)
                        .accessibilityLabel("タグの絞り込みをリセット")
                } else {
                    Text("タグをタップして本を表示")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<54, id: \.self) { index in
                        Circle()
                            .fill(tint.opacity(0.07 + Double(index % 4) * 0.025))
                            .frame(width: dotSize(for: index), height: dotSize(for: index))
                            .position(dotPosition(for: index, in: geometry.size))
                    }

                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        let diameter = bubbleDiameter(for: stat, at: index)
                        Button {
                            onSelect(stat.name)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(tint.opacity(bubbleOpacity(for: index)))
                                    .overlay {
                                        if normalizedBookText(selectedTag ?? "") == normalizedBookText(stat.name) {
                                            Circle().stroke(tint.opacity(0.82), lineWidth: 1.5)
                                        }
                                    }
                                Text(stat.name)
                                    .font(tagFont(for: diameter))
                                    .foregroundStyle(.primary.opacity(0.82))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.58)
                                    .padding(.horizontal, 5)
                            }
                            .frame(width: diameter, height: diameter)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(
                            x: positions[index % positions.count].x * geometry.size.width,
                            y: positions[index % positions.count].y * geometry.size.height
                        )
                        .accessibilityLabel("\(stat.name)、\(stat.count)冊")
                        .accessibilityHint("このタグの本に絞り込みます")
                    }
                }
                .clipped()
            }
            .frame(height: 228)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.22), lineWidth: 0.7)
        }
    }

    private func bubbleDiameter(for stat: BookTagStat, at index: Int) -> CGFloat {
        let ratio = CGFloat(stat.count) / CGFloat(maximumCount)
        let rankedFloor = max(34, 74 - CGFloat(index) * 2.2)
        return min(92, max(rankedFloor, 34 + ratio * 58))
    }

    private func bubbleOpacity(for index: Int) -> Double {
        max(0.11, 0.24 - Double(index) * 0.006)
    }

    private func tagFont(for diameter: CGFloat) -> Font {
        FavorecoTypography.jpSerif(
            max(9, min(22, diameter * 0.25)),
            weight: diameter >= 68 ? .semibold : .regular,
            relativeTo: .body
        )
    }

    private func dotSize(for index: Int) -> CGFloat {
        CGFloat(3 + (index * 7) % 9)
    }

    private func dotPosition(for index: Int, in size: CGSize) -> CGPoint {
        let x = CGFloat((index * 37 + 11) % 101) / 100
        let y = CGFloat((index * 61 + 17) % 103) / 102
        return CGPoint(x: x * size.width, y: y * size.height)
    }
}

private struct BookLibrarySection: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color
    let onOpenEvent: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void
    let onOpenSeries: (BookSeriesRoute) -> Void

    @State private var searchText = ""
    @State private var filter: BookLibraryFilter = .all
    @State private var selectedInsightTag: String?
    @State private var layout: CategoryLibraryLayoutMode = .gallery
    @State private var expandedBannerStatuses: Set<BookLibraryFilter> = []
    @State private var isShowingBookShelves = false
    @State private var initialBookShelfID: UUID?

    private var searchedItems: [CategoryLibraryItem] {
        let query = normalizedBookText(searchText)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            let event = item.event
            let visitTags = item.visits.flatMap { TheaterEmotionTags.names(from: $0.tagNamesRaw) }
            return ([event.title, event.bookSeriesName, event.bookVolumeNumber, event.bookAuthorName, event.seriesName] + visitTags)
                .map(normalizedBookText)
                .contains { $0.contains(query) }
        }
    }

    private var filteredItems: [CategoryLibraryItem] {
        guard filter != .all else { return searchedItems }
        return searchedItems.filter { bookStatus(for: $0) == filter }
    }

    private func count(for option: BookLibraryFilter) -> Int {
        guard option != .all else { return searchedItems.count }
        return searchedItems.filter { bookStatus(for: $0) == option }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                FavorecoIcon(systemName: "magnifyingglass", size: 15)
                    .foregroundStyle(.secondary)
                TextField(
                    "本・シリーズ・著者を検索",
                    text: Binding(
                        get: { searchText },
                        set: { newValue in
                            searchText = newValue
                            if normalizedBookText(newValue) != normalizedBookText(selectedInsightTag ?? "") {
                                selectedInsightTag = nil
                            }
                        }
                    )
                )
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedInsightTag = nil
                    } label: {
                        FavorecoIcon(systemName: "xmark.circle.fill", size: 17)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("検索語をすべて削除")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

            BookShelfTopStrip(categoryID: category.id, tint: tint) { shelfID in
                initialBookShelfID = shelfID
                isShowingBookShelves = true
            }

            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BookLibraryFilter.allCases) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    filter = option
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(option.title)
                                    Text("\(count(for: option))")
                                        .foregroundStyle(filter == option ? Color.white.opacity(0.82) : Color.secondary)
                                }
                                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(filter == option ? Color.white : Color.primary)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 30)
                                .background(
                                    filter == option ? tint : tint.opacity(0.07),
                                    in: Capsule()
                                )
                                .overlay {
                                    if filter != option {
                                        Capsule().stroke(tint.opacity(0.18), lineWidth: 0.7)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.title)、\(count(for: option))冊")
                            .accessibilityAddTraits(filter == option ? .isSelected : [])
                        }
                    }
                }

                CategoryLibraryLayoutPicker(
                    selection: $layout,
                    tint: tint,
                    modes: [.gallery, .banner],
                    onSelect: { _ in }
                )
                .fixedSize()
            }

            if let selectedInsightTag {
                HStack(spacing: 7) {
                    Text("#\(selectedInsightTag) で絞り込み中")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button("リセット") {
                        resetInsightTagFilter()
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }

            if filteredItems.isEmpty {
                EmptyStateMessage(
                    icon: filter == .read ? "book.closed" : "books.vertical",
                    title: "該当する本はありません",
                    message: searchText.isEmpty ? "本を登録すると、ここに並びます。" : "検索語や絞り込みを変更してください。",
                    tint: tint
                )
            } else {
                bookList(items: filteredItems)
            }

            BookReadingInsightsSection(
                items: items,
                tint: tint,
                selectedTag: selectedInsightTag,
                onSelectTag: { tag in
                    selectedInsightTag = tag
                    searchText = tag
                    filter = .all
                },
                onResetTag: resetInsightTagFilter
            )
        }
        .sheet(isPresented: $isShowingBookShelves) {
            BookShelfBrowserView(
                categoryID: category.id,
                initialShelfID: initialBookShelfID
            )
        }
    }

    @ViewBuilder
    private func bookList(items: [CategoryLibraryItem]) -> some View {
        let entries = bookEntries(from: items, allItems: searchedItems)
        let usesCoverGrid = layout == .gallery
        VStack(alignment: .leading, spacing: 10) {
            if usesCoverGrid {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .bottom), count: 3),
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(entries) { entry in
                        Button { open(entry) } label: {
                            BookLibraryGridTile(
                                entry: entry,
                                tint: tint,
                                showsStatusLabel: true
                            )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                let visibleEntries = expandedBannerStatuses.contains(filter)
                    ? entries
                    : Array(entries.prefix(3))
                LazyVStack(spacing: 10) {
                    ForEach(visibleEntries) { entry in
                        Button { open(entry) } label: {
                            BookLibraryListRow(
                                entry: entry,
                                tint: tint,
                                showsStatusLabel: true
                            )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if entries.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedBannerStatuses.contains(filter) {
                                expandedBannerStatuses.remove(filter)
                            } else {
                                expandedBannerStatuses.insert(filter)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(expandedBannerStatuses.contains(filter)
                                ? "閉じる"
                                : "さらに見る (残り\(entries.count - 3)件)")
                            FavorecoIcon(
                                systemName: expandedBannerStatuses.contains(filter) ? "chevron.up" : "chevron.down",
                                size: 11
                            )
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resetInsightTagFilter() {
        selectedInsightTag = nil
        searchText = ""
        filter = .all
    }

    private func open(_ entry: BookLibraryEntry) {
        if let seriesName = entry.seriesName {
            onOpenSeries(BookSeriesRoute(
                categoryID: category.id,
                seriesName: seriesName,
                normalizedSeriesName: normalizedBookText(seriesName)
            ))
        } else if let visit = readingRecordToOpen(for: entry.representative) {
            onOpenVisit(visit.id)
        } else {
            onOpenEvent(entry.representative.event.id)
        }
    }

    /// 状態チップは「本の情報」と「1回ごとの読書記録」の入口も切り替える。
    /// `すべて / 気になる / 積読`は親の本詳細、`読書中 / 読了`は該当状態の最新記録を開く。
    private func readingRecordToOpen(for item: CategoryLibraryItem) -> Visit? {
        let matchesSelectedState: (Visit) -> Bool
        switch filter {
        case .reading:
            matchesSelectedState = {
                VisitUnitFields(rawValue: $0.unitFieldsRaw).bookReadingHasEndDate == false
            }
        case .read:
            matchesSelectedState = {
                VisitUnitFields(rawValue: $0.unitFieldsRaw).bookReadingHasEndDate != false
            }
        case .all, .interested, .toRead:
            return nil
        }

        return item.visits
            .filter(matchesSelectedState)
            .max { lhs, rhs in
                let lhsDate = filter == .read ? lhs.endedAt : lhs.visitedAt
                let rhsDate = filter == .read ? rhs.endedAt : rhs.visitedAt
                return lhsDate < rhsDate
            }
    }
}

private struct BookLibraryGridTile: View {
    let entry: BookLibraryEntry
    let tint: Color
    let showsStatusLabel: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if entry.seriesName != nil {
                BookSeriesStackLayers(tint: tint)
                    .aspectRatio(coverAspectRatio, contentMode: .fit)
            }
            BookCoverArtwork(
                event: entry.representative.event,
                reference: entry.eyecatchReference
            )
            if showsStatusLabel {
                BookCoverStatusRibbon(status: entry.displayStatus)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 6)
            }
            if !entry.volumeBadgeText.isEmpty {
                Text(entry.volumeBadgeText)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.78), in: Circle())
                    .padding(5)
            }
        }
        .aspectRatio(coverAspectRatio, contentMode: .fit)
        .overlay {
            Rectangle()
                .stroke(
                    tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
        .padding(.top, entry.seriesName == nil ? 0 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(showsStatusLabel ? "\(entry.title)、\(entry.displayStatus.title)" : entry.title)
    }

    private var coverAspectRatio: CGFloat {
        CGFloat(EyecatchAspectRatio.resolved(for: entry.representative.event).value)
    }
}

private struct BookSeriesStackLayers: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(tint.opacity(0.34), lineWidth: 0.8)
                }
                .offset(y: -8)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(tint.opacity(0.26), lineWidth: 0.8)
                }
                .offset(y: -4)
        }
    }
}

private struct BookLibraryListRow: View {
    let entry: BookLibraryEntry
    let tint: Color
    let showsStatusLabel: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                BookCoverArtwork(
                    event: entry.representative.event,
                    reference: entry.eyecatchReference
                )
                if showsStatusLabel {
                    BookCoverStatusRibbon(status: entry.displayStatus, isCompact: true)
                        .padding(.leading, 4)
                }
            }
                .frame(width: 68)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(2)
                    .frame(minHeight: 38, alignment: .topLeading)

                ForEach(Array(metadataLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            FavorecoIcon(systemName: "chevron.right", size: 14)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.2), lineWidth: 0.7)
        }
        .accessibilityLabel(showsStatusLabel ? "\(entry.title)、\(entry.displayStatus.title)" : entry.title)
    }

    private var metadataLines: [String] {
        let event = entry.representative.event
        return [
            labeledBookMetadata("著者", value: event.bookAuthorName),
            labeledBookMetadata("発売日", value: formattedBookPublishedDate(event.bookPublishedDate)),
            labeledBookMetadata("出版社", value: event.bookPublisherName),
        ].filter { !$0.isEmpty }
    }
}

/// Filmarksの上映状態表示のように、書影上端から垂らす状態帯。
private struct BookCoverStatusRibbon: View {
    let status: BookLibraryFilter
    var isCompact = false

    var body: some View {
        VStack(spacing: isCompact ? -2 : -1) {
            ForEach(Array(status.title.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.system(size: isCompact ? 8 : 9, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.top, isCompact ? 4 : 6)
        .padding(.bottom, isCompact ? 8 : 10)
        .frame(width: isCompact ? 22 : 28)
        .background(BookCoverStatusRibbonShape().fill(status.ribbonColor))
        .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)
        .allowsHitTesting(false)
    }
}

private struct BookCoverStatusRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notchDepth = min(8, rect.height * 0.18)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - notchDepth))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notchDepth))
        path.closeSubpath()
        return path
    }
}

private extension BookLibraryFilter {
    var ribbonColor: Color {
        switch self {
        case .interested: Color(hex: "#C45E3A")
        case .toRead: Color(hex: "#A47728")
        case .reading: Color(hex: "#2F7894")
        case .read: Color(hex: "#557A5B")
        case .all: Color(hex: "#4B5563")
        }
    }
}

private func labeledBookMetadata(_ label: String, value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "" : "\(label)  \(trimmed)"
}

private func formattedBookPublishedDate(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    let parts = trimmed.split(separator: "-").compactMap { Int($0) }
    switch parts.count {
    case 3: return "\(parts[0])年\(parts[1])月\(parts[2])日"
    case 2: return "\(parts[0])年\(parts[1])月"
    case 1 where trimmed.allSatisfy(\.isNumber): return "\(parts[0])年"
    default: return trimmed
    }
}

struct BookCoverArtwork: View {
    let event: ExperienceEvent
    let reference: ThumbnailReference

    init(event: ExperienceEvent, reference: ThumbnailReference? = nil) {
        self.event = event
        self.reference = reference ?? .event(event.id)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemGroupedBackground)
                ThumbnailImage(reference: reference, displaySize: geometry.size, contentMode: .fit) {
                    CategoryDefaultArtworkImage(
                        templateKey: "book",
                        displaySize: geometry.size,
                        contentMode: .fit
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(CGFloat(EyecatchAspectRatio.resolved(for: event).value), contentMode: .fit)
    }
}

private struct BookSeriesDetailView: View {
    let route: BookSeriesRoute
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]
    @State private var filter: BookLibraryFilter = .all
    @State private var sort: BookSeriesSort = .volumeAscending
    @State private var layout: CategoryLibraryLayoutMode = .gallery
    @State private var isShowingNextVolumeRegistration = false

    private var seriesEvents: [ExperienceEvent] {
        let source = allEvents.filter {
            !$0.isArchived
                && $0.category?.id == route.categoryID
                && normalizedBookText($0.bookSeriesName) == route.normalizedSeriesName
        }
        let filtered = filter == .all ? source : source.filter { bookStatus(for: $0) == filter }
        return filtered.sorted(by: eventSort)
    }

    private var allSeriesEvents: [ExperienceEvent] {
        allEvents.filter {
            !$0.isArchived
                && $0.category?.id == route.categoryID
                && normalizedBookText($0.bookSeriesName) == route.normalizedSeriesName
        }
    }

    private var representativeEvent: ExperienceEvent? {
        allSeriesEvents.sorted {
            bookVolumeSortValue($0.bookVolumeNumber) < bookVolumeSortValue($1.bookVolumeNumber)
        }.first
    }

    private var nextVolumeNumber: String {
        BookSeriesRegistrationDefaults.nextVolumeNumber(
            from: allSeriesEvents.map(\.bookVolumeNumber)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(route.seriesName)
                    .font(FavorecoTypography.heroTitle)
                HStack(alignment: .center, spacing: 12) {
                    Text("全\(allSeriesEvents.count)冊・読了\(allSeriesEvents.filter { bookStatus(for: $0) == .read }.count)冊")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button {
                        isShowingNextVolumeRegistration = true
                    } label: {
                        FavorecoIconLabel("次の巻を追加", systemImage: "plus", iconSize: 14)
                            .font(FavorecoTypography.captionStrong)
                    }
                    .buttonStyle(.bordered)
                    .disabled(representativeEvent?.category == nil)
                }

                HStack {
                    Menu {
                        Picker("状態", selection: $filter) {
                            ForEach(BookLibraryFilter.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        FavorecoIconLabel(filter.title, systemImage: "line.3.horizontal.decrease.circle", iconSize: 15)
                    }
                    Menu {
                        Picker("並び順", selection: $sort) {
                            ForEach(BookSeriesSort.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        FavorecoIconLabel(sort.title, systemImage: "arrow.up.arrow.down", iconSize: 15)
                    }
                    Spacer()
                    CategoryLibraryLayoutPicker(selection: $layout, tint: .accentColor, modes: [.gallery, .banner], onSelect: { _ in })
                }

                if seriesEvents.isEmpty {
                    FavorecoContentUnavailableView("該当する巻はありません", systemImage: "books.vertical")
                } else if layout == .gallery {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
                        ForEach(seriesEvents) { event in
                            NavigationLink(value: event.id) {
                                BookSeriesVolumeGridTile(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(seriesEvents) { event in
                            NavigationLink(value: event.id) {
                                BookSeriesVolumeListRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("シリーズ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { eventID in
            CategoryEventDestination(eventID: eventID)
        }
        .sheet(isPresented: $isShowingNextVolumeRegistration) {
            if let representativeEvent,
               representativeEvent.category != nil {
                QuickRegistrationView(
                    initialTemplateKey: "book",
                    screenTitle: "次の巻を追加",
                    locksCategory: true,
                    initialBookTitle: route.seriesName,
                    initialBookSeriesName: route.seriesName,
                    initialBookVolumeNumber: nextVolumeNumber,
                    initialBookAuthorName: representativeEvent.bookAuthorName,
                    initialBookStateKey: "active",
                    initialBookAspectRatioKey: VisitUnitFields(rawValue: representativeEvent.unitFieldsRaw)
                        .eyecatchAspectRatioKey
                )
            }
        }
    }

    private func eventSort(_ lhs: ExperienceEvent, _ rhs: ExperienceEvent) -> Bool {
        switch sort {
        case .volumeAscending: bookVolumeSortValue(lhs.bookVolumeNumber) < bookVolumeSortValue(rhs.bookVolumeNumber)
        case .volumeDescending: bookVolumeSortValue(lhs.bookVolumeNumber) > bookVolumeSortValue(rhs.bookVolumeNumber)
        case .recentlyRead: (lhs.visits?.map(\.visitedAt).max() ?? .distantPast) > (rhs.visits?.map(\.visitedAt).max() ?? .distantPast)
        case .recentlyAdded: lhs.createdAt > rhs.createdAt
        }
    }
}

private struct BookSeriesVolumeGridTile: View {
    let event: ExperienceEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverArtwork(event: event)
            Text(event.bookVolumeLabel.isEmpty ? event.title : event.bookVolumeLabel)
                .font(FavorecoTypography.bodyStrong)
                .lineLimit(1)
            Text(bookStatus(for: event).title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BookSeriesVolumeListRow: View {
    let event: ExperienceEvent
    var body: some View {
        HStack(spacing: 12) {
            BookCoverArtwork(event: event)
                .frame(width: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(FavorecoTypography.bodyStrong).lineLimit(2)
                Text([event.bookVolumeLabel, event.bookAuthorName].filter { !$0.isEmpty }.joined(separator: "・"))
                    .font(FavorecoTypography.caption).foregroundStyle(.secondary)
                Text(bookStatus(for: event).title)
                    .font(FavorecoTypography.captionStrong).foregroundStyle(Color.accentColor)
            }
            Spacer()
            FavorecoIcon(systemName: "chevron.right", size: 14).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private func bookEntries(
    from items: [CategoryLibraryItem],
    allItems: [CategoryLibraryItem]
) -> [BookLibraryEntry] {
    let grouped = Dictionary(grouping: items.filter { !$0.event.bookSeriesName.isEmpty }) {
        normalizedBookText($0.event.bookSeriesName)
    }
    let seriesEntries = grouped.values.compactMap { group -> BookLibraryEntry? in
        guard let first = group.first else { return nil }
        let fullSeries = allItems.filter {
            normalizedBookText($0.event.bookSeriesName) == normalizedBookText(first.event.bookSeriesName)
        }
        return BookLibraryEntry(
            items: fullSeries.sorted {
                bookVolumeSortValue($0.event.bookVolumeNumber) < bookVolumeSortValue($1.event.bookVolumeNumber)
            },
            seriesName: first.event.bookSeriesName
        )
    }
    let standalone = items.filter { $0.event.bookSeriesName.isEmpty }.map {
        BookLibraryEntry(items: [$0], seriesName: nil)
    }
    return (seriesEntries + standalone).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
}

private func bookStatus(for item: CategoryLibraryItem) -> BookLibraryFilter {
    bookStatus(stateKey: item.event.stateKey, visits: item.visits)
}

private func bookStatus(for event: ExperienceEvent) -> BookLibraryFilter {
    bookStatus(stateKey: event.stateKey, visits: event.visits ?? [])
}

private func bookStatus(stateKey: String, visits: [Visit]) -> BookLibraryFilter {
    if stateKey == "interested" { return .interested }
    guard let latest = visits.max(by: { $0.visitedAt < $1.visitedAt }) else { return .toRead }
    let fields = VisitUnitFields(rawValue: latest.unitFieldsRaw)
    return fields.bookReadingHasEndDate == false ? .reading : .read
}

private func normalizedBookText(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
        .filter { !$0.isWhitespace }
}

private func bookVolumeSortValue(_ value: String) -> Double {
    bookVolumeNumericValue(value) ?? .greatestFiniteMagnitude
}

private func bookVolumeNumericValue(_ value: String) -> Double? {
    let normalized = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    let numeric = normalized.filter { $0.isNumber || $0 == "." }
    return Double(numeric)
}

private struct CategoryLibraryItem: Identifiable {
    let event: ExperienceEvent
    let visits: [Visit]
    let latestVisit: Visit?
    let nextPlan: Plan?
    let ticketAttempts: [TicketAttempt]
    let facilityName: String
    let facilityIdentityKey: String
    let placeMasterID: UUID?

    var id: UUID { event.id }

    var hasActiveTicketProgress: Bool {
        ticketAttempts.contains {
            !$0.isArchived
                && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
        }
    }

    var title: String {
        if !facilityName.isEmpty { return facilityName }
        return event.title.isEmpty ? "記録" : event.title
    }

    var physicalVisitCount: Int {
        Set(visits.map { Calendar.autoupdatingCurrent.startOfDay(for: $0.visitedAt) }).count
    }

    func visitSummaryText(for category: RecordCategory) -> String {
        let visitLabel = category.templateKey == "theme_park" ? "来園" : "訪問"
        return "\(visitLabel)\(physicalVisitCount)回・記録\(visits.count)件"
    }

    var ratingText: String {
        guard let rating = latestVisit?.overallRating, rating > 0 else { return "—" }
        return String(format: "%.1f", rating)
    }

    var ratingValue: Double? {
        guard let rating = latestVisit?.overallRating, rating > 0 else { return nil }
        return rating
    }

    var dateText: String {
        guard let displayDate else { return "—" }
        return FavorecoDateText.compactDate(displayDate)
    }

    var displayDate: Date? {
        if let nextPlan { return nextPlan.startsAt }
        if let latestVisit { return latestVisit.visitedAt }
        return nil
    }

    var galleryDateText: String {
        guard let displayDate else { return "—" }
        return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
    }

    var screenWorkDateText: String {
        guard let displayDate else { return "—" }
        if event.screenWorkType == .movie {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
        }
        if event.screenWorkType != .movie {
            return screenWorkBroadcastSeasonText(for: displayDate)
        }
        return "—"
    }

    var screenWorkBannerDateText: String {
        guard let displayDate else { return "—" }
        if event.screenWorkType != .movie {
            return screenWorkBroadcastSeasonText(for: displayDate)
        }
        return FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
    }

    private func screenWorkBroadcastSeasonText(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return "—" }
        let seasonName = switch month {
        case 1...3: "冬"
        case 4...6: "春"
        case 7...9: "夏"
        default: "秋"
        }
        let typeName = event.screenWorkType == .drama ? "ドラマ" : "アニメ"
        return "\(FavorecoDateText.year(year)) \(seasonName)\(typeName)"
    }

    var galleryDateColor: Color {
        guard let displayDate else { return .secondary }
        switch FavorecoDateText.weekdayNumber(displayDate) {
        case 1:
            return .red
        case 7:
            return .blue
        default:
            return dateColor
        }
    }

    var ratingSymbol: String {
        ratingText == "—" ? "star" : "star.fill"
    }

    var ratingColor: Color {
        ratingText == "—" ? .secondary : .yellow
    }

    var dateColor: Color {
        nextPlan == nil ? .secondary : .red
    }

    var compactTileDateText: String {
        guard let displayDate else { return "—" }
        let text = FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)
        return nextPlan == nil ? text : "予定 \(text)"
    }

    var bannerDateTimeText: String {
        guard let displayDate else { return "—" }
        return "\(FavorecoDateText.compactDateWithHalfWidthWeekday(displayDate)) \(FavorecoDateText.time(displayDate))"
    }

    var accessibilitySummary: String {
        "\(title)、評価\(ratingText)、\(dateText)"
    }

    var screenWorkAccessibilitySummary: String {
        let typeAndSeason = [event.screenWorkType.displayName, event.screenWorkSeasonLabel]
            .filter { !$0.isEmpty }
            .joined(separator: "、")
        let rating = ratingValue.map { "評価\(String(format: "%.1f", $0))" } ?? "評価なし"
        return [title, typeAndSeason, screenWorkDateText, rating]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: "、")
    }

    var screenWorkBannerAccessibilitySummary: String {
        [title, screenWorkBannerDateText, event.screenWorkType.displayName]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: "、")
    }

    var productionTypeText: String {
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        return TheaterPerformanceType.displayName(
            for: event.subTypeKey,
            customName: fields.eventPerformanceTypeCustomName
        )
    }

    var productionSeriesText: String {
        event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var productionOrganizerText: String {
        let savedOrganizer = event.organizerNameSnapshot
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !savedOrganizer.isEmpty {
            return savedOrganizer
        }
        return linkedNames(for: "organizer").joined(separator: "・")
    }

    var productionAccessibilitySummary: String {
        [title, productionTypeText, productionSeriesText, productionOrganizerText]
            .filter { !$0.isEmpty }
            .joined(separator: "、")
    }

    var venueText: String {
        if let nextPlan, !nextPlan.venueNameSnapshot.isEmpty {
            return nextPlan.venueNameSnapshot
        }
        if let planVenue = nextPlan?.placeMaster?.name, !planVenue.isEmpty {
            return planVenue
        }
        if let latestVisit, !latestVisit.venueNameSnapshot.isEmpty {
            return latestVisit.venueNameSnapshot
        }
        return latestVisit?.placeMaster?.name ?? ""
    }

    var prefectureText: String {
        let placeMasters = [nextPlan?.placeMaster, latestVisit?.placeMaster].compactMap { $0 }
        if let savedPrefecture = placeMasters.map(\.prefecture).first(where: { !$0.isEmpty }) {
            return savedPrefecture
        }
        let address = placeMasters.map(\.address).first(where: { !$0.isEmpty }) ?? ""
        return JapanPrefecture.extract(from: address)
    }

    var ticketStatusNames: [String] {
        var seen = Set<String>()
        return ticketAttempts.compactMap { attempt in
            let name = TicketStatusDefinition.name(for: attempt.statusKey)
            return seen.insert(name).inserted ? name : nil
        }
    }

    func bannerStatusText(for category: RecordCategory) -> String {
        if nextPlan != nil {
            if let attempt = ticketAttempts.first(where: {
                !["lost", "attended", "skipped"].contains($0.statusKey)
            }) {
                switch attempt.statusKey {
                case "interested": return "気になる"
                case "beforeApply": return "申込予定"
                case "onSaleSoon": return "チケット発売待ち"
                case "waitingResult": return "当落待ち"
                case "won": return "当選"
                case "waitingPayment": return "支払待ち"
                case "waitingIssue": return "取得処理中"
                case "issued": return "受取済み"
                default: return TicketStatusDefinition.name(for: attempt.statusKey)
                }
            }

            switch category.templateKey {
            case "theater": return "観劇予定"
            case "movie": return "鑑賞予定"
            case "live": return "参加予定"
            default: return "予定"
            }
        }

        if latestVisit != nil {
            switch category.templateKey {
            case "theater": return "観劇済み"
            case "movie": return "鑑賞済み"
            case "live": return "参加済み"
            default: return "体験済み"
            }
        }

        return event.stateKey == "interested" ? "気になる" : "登録済み"
    }

    func bannerCreditText(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "theater":
            if let nextPlan, !nextPlan.organizerNameSnapshot.isEmpty {
                return "主催: \(nextPlan.organizerNameSnapshot)"
            }
            if !event.organizerNameSnapshot.isEmpty {
                return "主催: \(event.organizerNameSnapshot)"
            }
            let organizers = linkedNames(for: "organizer")
            return organizers.isEmpty ? "" : "主催: \(organizers.joined(separator: "・"))"
        case "movie":
            let directors = linkedNames(for: "director")
            return directors.isEmpty ? "" : "監督: \(directors.joined(separator: "・"))"
        case "live":
            let artists = ["artist", "performer", "cast"]
                .flatMap { linkedNames(for: $0) }
                .reduce(into: [String]()) { names, name in
                    if !names.contains(name) {
                        names.append(name)
                    }
                }
            if !artists.isEmpty {
                return "出演: \(artists.joined(separator: "・"))"
            }
            if let nextPlan, !nextPlan.organizerNameSnapshot.isEmpty {
                return "主催: \(nextPlan.organizerNameSnapshot)"
            }
            if !event.organizerNameSnapshot.isEmpty {
                return "主催: \(event.organizerNameSnapshot)"
            }
            let organizers = linkedNames(for: "organizer")
            return organizers.isEmpty ? "" : "主催: \(organizers.joined(separator: "・"))"
        default:
            return ""
        }
    }

    private func linkedNames(for roleKey: String) -> [String] {
        var seen = Set<String>()
        return (event.personLinks ?? [])
            .filter { !$0.isArchived && $0.roleKey == roleKey }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { link in
                let name = link.nameSnapshot.isEmpty
                    ? link.person?.displayName ?? ""
                    : link.nameSnapshot
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return name
            }
    }
}

private struct CategoryGalleryMetadata: View {
    let item: CategoryLibraryItem
    let category: RecordCategory
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Text(category.templateKey == "movie" ? item.screenWorkDateText : item.galleryDateText)
                .foregroundStyle(item.galleryDateColor)
                .minimumScaleFactor(0.72)

            if category.templateKey != "movie" || item.ratingValue != nil {
                Spacer(minLength: 1)

                Rectangle()
                    .fill(tint.opacity(0.34))
                    .frame(width: 0.6, height: 11)

                Spacer(minLength: 1)

                HStack(spacing: 2) {
                    Image(systemName: item.ratingSymbol)
                    Text(item.ratingText)
                }
                .foregroundStyle(item.ratingColor)
            }
        }
        .font(FavorecoTypography.jpSans(9.5, weight: .medium, relativeTo: .caption2))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
    }
}

private struct CompactRatingView: View {
    let rating: Double?
    let ratingText: String
    let color: Color
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let rating {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: starSymbol(at: index, rating: rating))
                        }
                    }
                } else {
                    Image(systemName: "star")
                }
            }
            .font(.system(size: max(7, fontSize - 1.5), weight: .medium))

            Text(ratingText)
                .font(FavorecoTypography.jpSans(fontSize, weight: .medium, relativeTo: .caption2))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(rating.map { "5点満点中\(String(format: "%.1f", $0))点" } ?? "未評価")
    }

    private func starSymbol(at index: Int, rating: Double) -> String {
        let roundedRating = (rating * 2).rounded() / 2
        if roundedRating >= Double(index) {
            return "star.fill"
        }
        if roundedRating >= Double(index) - 0.5 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }
}

private struct CompactTileDateView: View {
    let text: String
    let color: Color
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            FavorecoIcon(systemName: "calendar", size: max(7.5, fontSize - 0.5))

            Text(text)
                .font(FavorecoTypography.jpSans(fontSize, weight: .medium, relativeTo: .caption2))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityLabel(text)
    }
}

private struct CompactTileSupplementalView: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 3) {
            FavorecoIcon(systemName: systemImage, size: 7.5)

            Text(text.isEmpty ? "—" : text)
                .font(FavorecoTypography.jpSans(8.5, weight: .medium, relativeTo: .caption2))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(text.isEmpty ? "未設定" : text)
    }
}

private struct MovieCompactLibraryCard: View {
    let item: CategoryLibraryItem
    let category: RecordCategory
    let tint: Color

    private let cardHeight: CGFloat = 108
    private let artworkWidth: CGFloat = 76

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CategoryLibraryArtwork(
                item: item,
                category: category,
                aspectRatioOverride: artworkWidth / cardHeight,
                borderTint: tint
            )
            .frame(width: artworkWidth, height: cardHeight)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(FavorecoTypography.jpSans(10.5, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.primary)
                    .tracking(-0.35)
                    .lineSpacing(-1.5)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                CompactTileDateView(
                    text: item.compactTileDateText,
                    color: item.dateColor,
                    fontSize: 8.5
                )

                CompactTileSupplementalView(
                    text: item.venueText,
                    systemImage: "mappin.and.ellipse"
                )

                CompactRatingView(
                    rating: item.ratingValue,
                    ratingText: item.ratingText,
                    color: item.ratingColor,
                    fontSize: 9.35
                )
            }
            .padding(.vertical, 7)
            .padding(.trailing, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilitySummary)
    }
}

private struct ScreenWorkFilterBar: View {
    @Binding var selection: ScreenWorkFilter
    let tint: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(ScreenWorkFilter.allCases.enumerated()), id: \.element.id) { index, filter in
                if index > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 18)
                }

                Button {
                    selection = filter
                } label: {
                    Text(filter.displayName)
                        .font(FavorecoTypography.jpSans(12, weight: selection == filter ? .semibold : .regular, relativeTo: .caption))
                        .foregroundStyle(selection == filter ? Color.white : tint)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            selection == filter ? tint : Color.clear,
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: index == 0 ? 7 : 0,
                                bottomLeadingRadius: index == 0 ? 7 : 0,
                                bottomTrailingRadius: index == ScreenWorkFilter.allCases.count - 1 ? 7 : 0,
                                topTrailingRadius: index == ScreenWorkFilter.allCases.count - 1 ? 7 : 0
                            )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
            }
        }
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("映像作品の分類")
    }
}

struct CategoryLibraryLayoutPicker: View {
    @Binding var selection: CategoryLibraryLayoutMode
    let tint: Color
    var modes: [CategoryLibraryLayoutMode] = CategoryLibraryLayoutMode.allCases
    let onSelect: (CategoryLibraryLayoutMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(modes) { mode in
                Button {
                    selection = mode
                    onSelect(mode)
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection == mode ? Color.white : tint)
                        .frame(width: 30, height: 28)
                        .background(selection == mode ? tint : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.displayName)表示")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(3)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 0.75)
        }
    }
}

private struct ProgressiveCategoryLibraryContent: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color
    let layout: CategoryLibraryLayoutMode
    let pageSize: Int
    let showsProductionMetadata: Bool
    let onOpenEvent: (UUID) -> Void

    @State private var visibleCount: Int

    init(
        items: [CategoryLibraryItem],
        category: RecordCategory,
        tint: Color,
        layout: CategoryLibraryLayoutMode,
        pageSize: Int,
        showsProductionMetadata: Bool,
        onOpenEvent: @escaping (UUID) -> Void
    ) {
        self.items = items
        self.category = category
        self.tint = tint
        self.layout = layout
        self.pageSize = pageSize
        self.showsProductionMetadata = showsProductionMetadata
        self.onOpenEvent = onOpenEvent
        _visibleCount = State(initialValue: pageSize)
    }

    var body: some View {
        let effectiveVisibleCount = min(items.count, visibleCount)
        let visibleItems = Array(items.prefix(effectiveVisibleCount))

        VStack(alignment: .leading, spacing: 10) {
            switch layout {
            case .gallery:
                CategoryLibraryGallery(
                    items: visibleItems,
                    category: category,
                    tint: tint,
                    showsProductionMetadata: showsProductionMetadata,
                    onOpenEvent: onOpenEvent
                )
            case .compact:
                CategoryLibraryCompactGrid(
                    items: visibleItems,
                    category: category,
                    tint: tint,
                    showsProductionMetadata: showsProductionMetadata,
                    onOpenEvent: onOpenEvent
                )
            case .banner:
                CategoryLibraryBannerList(
                    items: visibleItems,
                    category: category,
                    tint: tint,
                    showsProductionMetadata: showsProductionMetadata,
                    onOpenEvent: onOpenEvent
                )
            }

            if items.count > pageSize {
                LibraryDisclosureButton(
                    remainingCount: max(0, items.count - effectiveVisibleCount),
                    isFullyExpanded: effectiveVisibleCount >= items.count,
                    tint: tint,
                    isTheater: category.templateKey == "theater",
                    isLive: category.templateKey == "live",
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if effectiveVisibleCount >= items.count {
                                visibleCount = pageSize
                            } else {
                                visibleCount = min(items.count, effectiveVisibleCount + pageSize)
                            }
                        }
                    }
                )
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if ids.count <= pageSize {
                visibleCount = pageSize
            } else {
                visibleCount = max(pageSize, min(visibleCount, ids.count))
            }
        }
    }
}

private struct LibraryDisclosureButton: View {
    let remainingCount: Int
    let isFullyExpanded: Bool
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(tint.opacity(0.24))
                    .frame(height: 0.6)

                Text(isFullyExpanded ? "閉じる" : "さらに\(remainingCount)件")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(disclosureTextColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(tint.opacity(0.24))
                    .frame(height: 0.6)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityLabel(isFullyExpanded ? "一覧を閉じる" : "さらに\(remainingCount)件を表示")
    }

    private var disclosureTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.74) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.78) }
        return tint
    }
}

enum CategoryLibraryChrome {
    static let borderLineWidth: CGFloat = 0.7
    static let cardBorderOpacity: Double = 0.42
    static let artworkBorderOpacity: Double = 0.62
}

private struct CategoryLibraryGallery: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color
    let showsProductionMetadata: Bool
    let onOpenEvent: (UUID) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                Button {
                    onOpenEvent(item.event.id)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        CategoryLibraryArtwork(item: item, category: category)

                        if !showsProductionMetadata,
                           item.event.stateKey != "interested",
                           category.templateKey != "movie" || item.displayDate != nil || item.ratingValue != nil {
                            CategoryGalleryMetadata(
                                item: item,
                                category: category,
                                tint: tint
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .background(galleryCardBackground)
                    .overlay {
                        Rectangle()
                            .stroke(
                                tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                                lineWidth: CategoryLibraryChrome.borderLineWidth
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    showsProductionMetadata
                        ? item.productionAccessibilitySummary
                        : category.templateKey == "movie"
                            ? item.screenWorkAccessibilitySummary
                            : item.accessibilitySummary
                )
            }
        }
    }

    private var galleryCardBackground: Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.tileBackground
        case "live": LiveCategoryStyle.tileBackground
        default: Color(.secondarySystemGroupedBackground)
        }
    }
}

private struct CategoryLibraryCompactGrid: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color
    let showsProductionMetadata: Bool
    let onOpenEvent: (UUID) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 2
    )
    private var cardHeight: CGFloat {
        showsProductionMetadata ? 112 : 106
    }

    private var artworkHeight: CGFloat {
        cardHeight - 16
    }

    private var artworkWidth: CGFloat {
        if category.templateKey == "theater" {
            return artworkHeight * CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
        }
        return showsProductionMetadata ? 52 : 58
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                Button {
                    onOpenEvent(item.event.id)
                } label: {
                    if category.templateKey == "movie" {
                        MovieCompactLibraryCard(item: item, category: category, tint: tint)
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            CategoryLibraryArtwork(
                                item: item,
                                category: category,
                                aspectRatioOverride: artworkWidth / artworkHeight,
                                borderTint: tint
                            )
                            .frame(width: artworkWidth, height: artworkHeight)

                            VStack(alignment: .leading, spacing: showsProductionMetadata ? 2 : 4) {
                                Text(item.title)
                                    .font(
                                        FavorecoTypography.jpSans(
                                            showsProductionMetadata ? 10.5 : 11,
                                            weight: .bold,
                                            relativeTo: .caption
                                        )
                                    )
                                    .foregroundStyle(.primary)
                                    .tracking(-0.35)
                                    .lineSpacing(showsProductionMetadata ? -2 : -1.5)
                                    .lineLimit(2, reservesSpace: !showsProductionMetadata)

                                if showsProductionMetadata {
                                    CompactTileSupplementalView(
                                        text: item.productionTypeText,
                                        systemImage: "theatermasks"
                                    )
                                    CompactTileSupplementalView(
                                        text: item.productionOrganizerText,
                                        systemImage: "building.2"
                                    )
                                    if !item.productionSeriesText.isEmpty {
                                        CompactTileSupplementalView(
                                            text: item.productionSeriesText,
                                            systemImage: "rectangle.stack"
                                        )
                                    }
                                } else {
                                    CompactTileDateView(
                                        text: item.compactTileDateText,
                                        color: item.dateColor,
                                        fontSize: 9
                                    )
                                }

                                if category.templateKey == "theater" && !showsProductionMetadata {
                                    CompactTileSupplementalView(
                                        text: item.venueText,
                                        systemImage: "mappin.and.ellipse"
                                    )
                                } else if category.isOutingFacilityGenre {
                                    CompactTileSupplementalView(
                                        text: item.prefectureText,
                                        systemImage: "mappin"
                                    )
                                }

                                if category.isOutingFacilityGenre {
                                    CompactTileSupplementalView(
                                        text: item.visitSummaryText(for: category),
                                        systemImage: "calendar.badge.checkmark"
                                    )
                                } else if !showsProductionMetadata {
                                    CompactRatingView(
                                        rating: item.ratingValue,
                                        ratingText: item.ratingText,
                                        color: item.ratingColor,
                                        fontSize: 9.35
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
                        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                                    lineWidth: CategoryLibraryChrome.borderLineWidth
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardBackground: Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.tileBackground
        case "live": LiveCategoryStyle.tileBackground
        default: Color(.secondarySystemGroupedBackground)
        }
    }
}

private struct CategoryLibraryBannerList: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color
    let showsProductionMetadata: Bool
    let onOpenEvent: (UUID) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { item in
                Button {
                    onOpenEvent(item.event.id)
                } label: {
                    if category.templateKey == "movie" {
                        ScreenWorkLibraryBannerCard(item: item, category: category, tint: tint)
                    } else {
                        standardBanner(item)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    category.templateKey == "movie"
                        ? item.screenWorkBannerAccessibilitySummary
                        : showsProductionMetadata
                            ? item.productionAccessibilitySummary
                            : item.accessibilitySummary
                )
            }
        }
    }

    private func standardBanner(_ item: CategoryLibraryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
                        CategoryLibraryArtwork(item: item, category: category, borderTint: tint)
                            .frame(width: 82)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(
                                    showsProductionMetadata
                                        ? "公演情報"
                                        : item.bannerStatusText(for: category)
                                )
                                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .frame(height: 18)
                                    .background(tint.opacity(0.12), in: Capsule())

                                Spacer(minLength: 4)

                                let creditText = showsProductionMetadata
                                    ? item.productionOrganizerText
                                    : item.bannerCreditText(for: category)
                                if !creditText.isEmpty {
                                    Text(creditText)
                                        .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }

                            Text(item.title)
                                .font(FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .headline))
                                .foregroundStyle(.primary)
                                .lineSpacing(-1)
                                .lineLimit(2, reservesSpace: true)

                            if (category.templateKey == "live" || showsProductionMetadata),
                               !item.event.seriesName.isEmpty {
                                Text(item.event.seriesName)
                                    .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                if showsProductionMetadata {
                                    if !item.productionTypeText.isEmpty {
                                        FavorecoIconLabel(item.productionTypeText, systemImage: "theatermasks", iconSize: 12)
                                            .foregroundStyle(.secondary)
                                    }
                                } else if item.dateText != "—" {
                                    FavorecoIconLabel(item.bannerDateTimeText, systemImage: "calendar", iconSize: 12)
                                        .foregroundStyle(item.nextPlan == nil ? Color.secondary : Color.red)
                                }
                                if !showsProductionMetadata, !item.venueText.isEmpty {
                                    FavorecoIconLabel(item.venueText, systemImage: "mappin.and.ellipse", iconSize: 12)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if category.isOutingFacilityGenre {
                                    FavorecoIconLabel(
                                        item.visitSummaryText(for: category),
                                        systemImage: "calendar.badge.checkmark",
                                        iconSize: 12
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                            .font(FavorecoTypography.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 45)
        }
        .padding(10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
    }

    private var cardBackground: Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.tileBackground
        case "live": LiveCategoryStyle.tileBackground
        default: Color(.secondarySystemGroupedBackground)
        }
    }
}

private struct ScreenWorkLibraryBannerCard: View {
    let item: CategoryLibraryItem
    let category: RecordCategory
    let tint: Color

    private let cardHeight: CGFloat = 124
    private let artworkWidth: CGFloat = 78

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryLibraryArtwork(
                item: item,
                category: category,
                aspectRatioOverride: artworkWidth / (cardHeight - 20),
                borderTint: tint
            )
            .frame(width: artworkWidth, height: cardHeight - 20)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineSpacing(-1)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                FavorecoIconLabel(
                    item.screenWorkBannerDateText,
                    systemImage: "calendar",
                    iconSize: 14
                )
                .foregroundStyle(item.displayDate == nil ? Color.secondary : tint)

                FavorecoIconLabel(
                    item.event.screenWorkType.displayName,
                    systemImage: "film",
                    iconSize: 12
                )
                .foregroundStyle(.secondary)
            }
            .font(FavorecoTypography.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    tint.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
    }
}

private struct CategoryLibraryArtwork: View {
    let item: CategoryLibraryItem
    let category: RecordCategory
    var aspectRatioOverride: CGFloat? = nil
    var borderTint: Color? = nil

    private var aspectRatio: CGFloat {
        if let aspectRatioOverride {
            return aspectRatioOverride
        }
        if category.templateKey == "theater" {
            return CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
        }
        return CGFloat(EyecatchAspectRatio.resolved(for: item.event).value)
    }

    @ViewBuilder
    var body: some View {
        if category.templateKey == "theater" {
            decorated(
                TheaterPosterArtwork(
                    reference: .event(item.event.id),
                    backgroundColor: TheaterCategoryStyle.tileBackground
                ) { size in
                    CategoryDefaultArtworkImage(
                        templateKey: category.templateKey,
                        displaySize: size,
                        contentMode: .fit
                    )
                }
            )
        } else {
            decorated(
                GeometryReader { geometry in
                    ThumbnailImage(
                        reference: .event(item.event.id),
                        displaySize: geometry.size,
                        contentMode: .fill
                    ) {
                        CategoryDefaultArtworkImage(
                            templateKey: category.templateKey,
                            displaySize: geometry.size
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipped()
            )
        }
    }

    private func decorated<Artwork: View>(_ artwork: Artwork) -> some View {
        artwork
            .overlay {
                if let borderTint {
                    Rectangle()
                        .stroke(
                            borderTint.opacity(CategoryLibraryChrome.artworkBorderOpacity),
                            lineWidth: CategoryLibraryChrome.borderLineWidth
                        )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if category.templateKey == "movie", !item.event.screenWorkSeasonLabel.isEmpty {
                    Text(item.event.screenWorkSeasonLabel)
                        .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(.black.opacity(0.78))
                        .padding(5)
                }
            }
    }
}

private struct ChapterPreviewCard: View {
    let directionTitle: String
    let category: RecordCategory
    let isNext: Bool
    let action: () -> Void

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if !isNext {
                        Image(systemName: "arrow.left")
                    }
                    Text(directionTitle)
                    if isNext {
                        Image(systemName: "arrow.right")
                    }
                }
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)

                ZStack {
                    LinearGradient(
                        colors: [categoryTint.opacity(0.28), categoryTint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    FavorecoIcon(
                        systemName: PhosphorIconGlyph.categorySystemName(
                            templateKey: category.templateKey,
                            storedSystemName: category.iconSymbol
                        ),
                        size: 30
                    )
                        .foregroundStyle(categoryTint)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(category.name.isEmpty ? "無題" : category.name)
                    .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("このジャンルへ移動")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(categoryTint.opacity(0.28), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(directionTitle)、\(category.name.isEmpty ? "無題" : category.name)")
        .accessibilityHint("このジャンルの先頭へ移動します")
    }

    private var categoryTint: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }
}

enum LiveCategoryStyle {
    static let navy = Color(red: 0.018, green: 0.090, blue: 0.115)
    static let deepNavy = Color(red: 0.010, green: 0.048, blue: 0.066)
    static let blackNavy = Color(red: 0.006, green: 0.022, blue: 0.032)
    static let tileBackground = Color(red: 0.024, green: 0.076, blue: 0.094).opacity(0.95)
    static let teal = Color(red: 0.25, green: 0.68, blue: 0.70)
    static let lightTeal = Color(red: 0.56, green: 0.86, blue: 0.86)
    static let mist = Color(red: 0.88, green: 0.96, blue: 0.95)

    static let brandGradient = LinearGradient(
        colors: [mist, lightTeal, teal, mist],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct CategoryStatisticsItem: Identifiable {
    let title: String
    let value: String
    let unit: String
    let note: String

    var id: String { title }
}

private struct CategoryStatisticsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    let items: [CategoryStatisticsItem]
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    dividerTint.opacity(0.08),
                                    dividerTint.opacity(0.46),
                                    dividerTint.opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 0.7, height: 70)
                }

                VStack(spacing: 0) {
                    Text(item.title)
                        .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.bottom, 1)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.value)
                            .font(FavorecoTypography.latinDisplay(33, weight: .semibold, relativeTo: .title2))
                            .foregroundStyle(valueColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(item.unit)
                            .font(FavorecoTypography.jpSerif(11, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(unitColor)
                    }

                    Text(item.note)
                        .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                        .foregroundStyle(noteColor)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
            }
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: panelGradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                glowColor,
                                Color.clear,
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 210
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            borderTint.opacity(0.62),
                            borderTint.opacity(0.36),
                            borderTint.opacity(0.52),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("3項目のミニ統計")
    }

    private var dividerTint: Color {
        if isTheater { return TheaterCategoryStyle.lightGold }
        if isLive { return LiveCategoryStyle.lightTeal }
        return tint
    }

    private var borderTint: Color {
        if isTheater { return TheaterCategoryStyle.gold }
        if isLive { return LiveCategoryStyle.teal }
        return tint
    }

    private var titleColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.88) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.88) }
        return Color.primary.opacity(0.82)
    }

    private var valueColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var unitColor: Color {
        if isTheater { return TheaterCategoryStyle.lightGold.opacity(0.78) }
        if isLive { return LiveCategoryStyle.lightTeal.opacity(0.82) }
        return tint.opacity(0.82)
    }

    private var noteColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.48) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.50) }
        return Color.secondary.opacity(0.76)
    }

    private var glowColor: Color {
        if isTheater { return TheaterCategoryStyle.lightGold.opacity(0.09) }
        if isLive { return LiveCategoryStyle.lightTeal.opacity(0.10) }
        return tint.opacity(0.08)
    }

    private var panelGradientColors: [Color] {
        if isTheater {
            return [
                Color(red: 0.105, green: 0.045, blue: 0.055),
                Color(red: 0.078, green: 0.033, blue: 0.043),
                Color(red: 0.046, green: 0.024, blue: 0.030),
            ]
        }
        if isLive {
            return [
                Color(red: 0.030, green: 0.105, blue: 0.125),
                Color(red: 0.020, green: 0.075, blue: 0.094),
                Color(red: 0.010, green: 0.040, blue: 0.054),
            ]
        }
        return [
            Color(.secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.92 : 0.98),
            tint.opacity(colorScheme == .dark ? 0.09 : 0.045),
            Color(.systemBackground).opacity(colorScheme == .dark ? 0.86 : 0.96),
        ]
    }
}

private struct EventRow: View {
    let snapshot: CategoryEventSnapshot
    let event: ExperienceEvent
    let onAddVisit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                HStack(spacing: 12) {
                    CategoryEyecatchArtwork(
                        reference: .event(event.id),
                        templateKey: event.category?.templateKey ?? "",
                        backgroundColor: Color(.secondarySystemFill),
                        defaultContentMode: EyecatchAspectRatio.usesEyecatchFill(for: event.category) ? .fill : .fit
                    ) { size in
                        CategoryDefaultArtworkImage(
                            templateKey: event.category?.templateKey ?? "",
                            displaySize: size
                        )
                    }
                    .frame(width: 68, height: representativeImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.cardTitle)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            if !event.seriesName.isEmpty {
                                FavorecoIconLabel(event.seriesName, systemImage: "rectangle.stack", iconSize: 12)
                                    .lineLimit(1)
                            }
                            FavorecoIconLabel("\(snapshot.visitCount)件", systemImage: "number", iconSize: 12)
                            if let latestVisitDate = snapshot.latestVisitDate {
                                FavorecoIconLabel(
                                    FavorecoDateText.compactDate(latestVisitDate),
                                    systemImage: "calendar",
                                    iconSize: 12
                                )
                            }
                        }
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onAddVisit) {
                FavorecoIcon(systemName: "plus.circle.fill", size: 20)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var representativeImageHeight: CGFloat {
        let ratio = EyecatchAspectRatio.resolved(for: event).value
        return 68 / CGFloat(ratio)
    }
}

private enum CategoryFeatureItem: Identifiable {
    case plan(Plan)
    case visit(Visit)
    case interest(ExperienceEvent)

    var id: String {
        switch self {
        case .plan(let plan): return "plan-\(plan.id.uuidString)"
        case .visit(let visit): return "visit-\(visit.id.uuidString)"
        case .interest(let event): return "interest-\(event.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .plan(let plan):
            if !plan.title.isEmpty { return plan.title }
            return plan.event?.title ?? "予定"
        case .visit(let visit):
            return visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
        case .interest(let event):
            return event.title.isEmpty ? "興味あり" : event.title
        }
    }

    var subtitle: String {
        switch self {
        case .plan(let plan):
            return plan.subtitle.isEmpty ? plan.event?.seriesName ?? "" : plan.subtitle
        case .visit(let visit):
            return visit.event?.seriesName ?? ""
        case .interest(let event):
            return event.seriesName
        }
    }

    var badgeText: String {
        switch self {
        case .plan: return "予定"
        case .visit: return "記録済み"
        case .interest: return "興味あり"
        }
    }

    var actionText: String {
        switch self {
        case .plan: return "予定を見る"
        case .visit: return "記録を見る"
        case .interest: return "詳細を見る"
        }
    }

    var actionIcon: String {
        switch self {
        case .plan: return "calendar"
        case .visit: return "doc.text"
        case .interest: return "chevron.right"
        }
    }

    var dateText: String {
        switch self {
        case .plan(let plan): return FavorecoDateText.compactDate(plan.startsAt)
        case .visit(let visit): return FavorecoDateText.compactDate(visit.visitedAt)
        case .interest: return ""
        }
    }

    var placeText: String {
        switch self {
        case .plan(let plan):
            return plan.venueNameSnapshot.isEmpty ? plan.placeMaster?.name ?? "" : plan.venueNameSnapshot
        case .visit(let visit):
            return visit.venueNameSnapshot.isEmpty ? visit.placeMaster?.name ?? "" : visit.venueNameSnapshot
        case .interest:
            return ""
        }
    }

    var detailText: String {
        switch self {
        case .plan(let plan):
            return plan.organizerNameSnapshot
        case .visit(let visit):
            if visit.overallRating > 0 {
                return String(format: "評価 %.1f", visit.overallRating)
            }
            return ""
        case .interest:
            return ""
        }
    }

    var event: ExperienceEvent? {
        switch self {
        case .plan(let plan): return plan.event
        case .visit(let visit): return visit.event
        case .interest(let event): return event
        }
    }

    var visit: Visit? {
        switch self {
        case .plan(let plan): return plan.visit
        case .visit(let visit): return visit
        case .interest: return nil
        }
    }
}

struct FavorecoComingUpRow<Artwork: View>: View {
    let date: Date
    let timeText: String
    let categoryName: String
    let title: String
    let venue: String
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    @ViewBuilder let artwork: Artwork

    init(
        date: Date,
        timeText: String = "",
        categoryName: String,
        title: String,
        venue: String,
        tint: Color,
        isTheater: Bool,
        isLive: Bool = false,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.date = date
        self.timeText = timeText
        self.categoryName = categoryName
        self.title = title
        self.venue = venue
        self.tint = tint
        self.isTheater = isTheater
        self.isLive = isLive
        self.artwork = artwork()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 0) {
                Text(FavorecoDateText.monthDay(date))
                    .font(FavorecoTypography.latinDisplay(24, weight: .semibold, relativeTo: .title2))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(FavorecoDateText.weekdayName(date))
                    .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                    .lineLimit(1)

                if !timeText.isEmpty {
                    Text(timeText)
                        .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(primaryTextColor)
            .frame(width: 50)

            artwork
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Text(title)
                    .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)

                if !venue.isEmpty {
                    Text(venue)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isTheater || isLive ? 0.42 : 0.20), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityScheduleText)、\(categoryName)、\(title)、\(venue)")
    }

    private var accessibilityScheduleText: String {
        let dateText = FavorecoDateText.compactDate(date)
        return timeText.isEmpty ? dateText : "\(dateText)、\(timeText)"
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return .primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.62) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.58) }
        return .secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.82)
    }
}

private struct TheaterTicketManagementPlanCard: View {
    let plan: Plan
    let category: RecordCategory
    let tint: Color
    let onOpenPlan: (UUID) -> Void
    let onMarkAcquired: (TicketAttempt) -> Void

    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false
    @State private var isShowingAddAttempt = false
    @State private var editingProgressAttempt: TicketAttempt?
    @State private var quickActionAttempt: TicketAttempt?

    private let posterWidth: CGFloat = 116

    private var posterHeight: CGFloat {
        posterWidth / CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
    }

    init(
        plan: Plan,
        category: RecordCategory,
        tint: Color,
        onOpenPlan: @escaping (UUID) -> Void,
        onMarkAcquired: @escaping (TicketAttempt) -> Void
    ) {
        self.plan = plan
        self.category = category
        self.tint = tint
        self.onOpenPlan = onOpenPlan
        self.onMarkAcquired = onMarkAcquired
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    private var displayPlan: Plan {
        currentPlans.first ?? plan
    }

    private var displayTitle: String {
        let eventTitle = displayPlan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = displayPlan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private var activeAttempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            allAttempts.filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
            }
        )
    }

    private var allAttempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            (displayPlan.ticketAttempts ?? []).filter { !$0.isArchived }
        )
    }

    private var hasAcquiredTicket: Bool {
        TicketAcquisitionState.hasAcquiredTicket(in: allAttempts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    onOpenPlan(displayPlan.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CategoryFeaturePoster(
                            item: .plan(displayPlan),
                            fallbackIcon: category.iconSymbol,
                            tint: tint
                        )
                        .frame(width: posterWidth, height: posterHeight)
                        .clipped()

                        VStack(alignment: .leading, spacing: 7) {
                            if hasUnacquiredTicket {
                                ticketAcquisitionChip
                            }

                            Text(displayTitle)
                                .font(FavorecoTypography.jpSerif(20, weight: .semibold, relativeTo: .title3))
                                .foregroundStyle(TheaterCategoryStyle.ivory)
                                .lineLimit(3)

                            if displayPlan.hasConfirmedSchedule {
                                FavorecoIconLabel(
                                    FavorecoDateText.compactDate(displayPlan.startsAt),
                                    systemImage: "calendar",
                                    iconSize: 17
                                )
                                    .font(FavorecoTypography.body)
                                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.78))
                                    .lineLimit(1)

                                FavorecoIconLabel(
                                    "開演 \(FavorecoDateText.time(displayPlan.startsAt))",
                                    systemImage: "clock",
                                    iconSize: 13
                                )
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.68))
                                    .lineLimit(1)
                            } else {
                                FavorecoIconLabel(
                                    "参加日未定",
                                    systemImage: "calendar.badge.exclamationmark",
                                    iconSize: 15
                                )
                                .font(FavorecoTypography.bodyStrong)
                                .foregroundStyle(TicketProgressColorPalette.scheduleUndated)
                                .lineLimit(1)
                            }

                            if !displayPlan.venueNameSnapshot.isEmpty {
                                FavorecoIconLabel(
                                    displayPlan.venueNameSnapshot,
                                    systemImage: "mappin.and.ellipse",
                                    iconSize: 13
                                )
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.68))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.trailing, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    isShowingEditPlan = true
                } label: {
                    FavorecoIcon(systemName: "pencil", size: 12)
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.09), in: Circle())
                        .overlay {
                            Circle().stroke(tint.opacity(0.38), lineWidth: 0.7)
                        }
                }
                .buttonStyle(.plain)
                .disabled(currentPlans.isEmpty)
                .accessibilityLabel("予定を編集")
            }

            if !activeAttempts.isEmpty {
                Divider()
                    .overlay(TheaterCategoryStyle.gold.opacity(0.46))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Ticket Progress")
                        .font(FavorecoTypography.latinDisplay(17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(TheaterCategoryStyle.gold)

                    ForEach(Array(activeAttempts.enumerated()), id: \.element.id) { index, attempt in
                        VStack(alignment: .leading, spacing: 6) {
                            if attempt.statusKey == "issued" {
                                ZStack {
                                    Button {
                                        quickActionAttempt = attempt
                                    } label: {
                                        acquiredTicketStatus
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("進捗管理を開きます")

                                    HStack {
                                        Spacer(minLength: 0)
                                        progressEditButton(for: attempt)
                                    }
                                }
                            } else {
                                HStack(spacing: 6) {
                                    theaterProgressMetadata(for: attempt)
                                    Spacer(minLength: 6)
                                    compactMarkAcquiredButton(for: attempt)
                                    progressEditButton(for: attempt)
                                }
                            }

                            if attempt.statusKey != "issued" {
                                let item = CategoryTicketProgressItem(
                                    plan: displayPlan,
                                    attempt: attempt
                                )
                                Button {
                                    quickActionAttempt = attempt
                                } label: {
                                    TicketProgressTimelineView(
                                        stages: item.stages,
                                        currentIndex: item.currentStageIndex,
                                        nodeBackground: TheaterCategoryStyle.tileBackground,
                                        secondaryTextColor: TheaterCategoryStyle.ivory.opacity(0.62),
                                        completedTint: TicketProgressColorPalette.completedNeutral
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("進捗管理を開きます")
                            }

                            if index < activeAttempts.count - 1 {
                                Divider()
                                    .overlay(TheaterCategoryStyle.gold.opacity(0.22))
                            }
                        }
                    }
                }
            }

            Divider()
                .overlay(TheaterCategoryStyle.gold.opacity(0.46))

            HStack(spacing: 7) {
                Button {
                    isShowingAddAttempt = true
                } label: {
                    theaterActionLabel("チケット追加", systemImage: "ticket")
                }
                .buttonStyle(.plain)
                .disabled(currentPlans.isEmpty)

                Button {
                    onOpenPlan(displayPlan.id)
                } label: {
                    theaterActionLabel("詳細", systemImage: "book.pages")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            TheaterCategoryStyle.tileBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.62), lineWidth: 0.75)
        }
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingAddAttempt) {
            if let currentPlan = currentPlans.first {
                EditTicketAttemptView(plan: currentPlan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(item: $editingProgressAttempt) { attempt in
            EditTicketAttemptView(plan: displayPlan, attempt: attempt, prioritizesDates: true)
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
    }

    private func theaterChip(_ title: String, isEmphasized: Bool) -> some View {
        Text(title)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(isEmphasized ? tint : TheaterCategoryStyle.ivory.opacity(0.78))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                isEmphasized ? tint.opacity(0.12) : Color.white.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        isEmphasized ? tint.opacity(0.44) : TheaterCategoryStyle.ivory.opacity(0.18),
                        lineWidth: 0.7
                    )
            }
    }

    private var ticketAcquisitionChip: some View {
        let color = Color(red: 0.94, green: 0.43, blue: 0.52)
        return Text("チケット未取得")
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(color.opacity(0.38), lineWidth: 0.7)
            }
    }

    private var hasUnacquiredTicket: Bool {
        !hasAcquiredTicket || activeAttempts.contains { $0.statusKey != "issued" }
    }

    private func compactMarkAcquiredButton(for attempt: TicketAttempt) -> some View {
        Button {
            onMarkAcquired(attempt)
        } label: {
            Text("取得済みにする")
                .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(TheaterCategoryStyle.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    TicketProgressColorPalette.color(for: .acquired).opacity(0.76),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(TicketProgressColorPalette.color(for: .acquired), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("チケットを取得済みにする")
        .accessibilityHint("このチケットを受取済みに更新します")
    }

    @ViewBuilder
    private func theaterProgressMetadata(for attempt: TicketAttempt) -> some View {
        HStack(spacing: 5) {
            let entryRoute = TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !entryRoute.isEmpty {
                theaterProgressMetadataChip(
                    entryRoute,
                    isEntryRoute: true
                )
            }

            let ticketSite = attempt.ticketSite.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ticketSite.isEmpty {
                theaterProgressMetadataChip(
                    ticketSite,
                    isEntryRoute: false
                )
            }
        }
    }

    private var acquiredTicketStatus: some View {
        FavorecoIconLabel(
            "チケット取得済み",
            systemImage: "checkmark.circle",
            iconSize: 15
        )
        .font(FavorecoTypography.captionStrong)
        .foregroundStyle(TheaterCategoryStyle.ivory)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(
            TicketProgressColorPalette.surface(for: .acquired).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(TicketProgressColorPalette.color(for: .acquired), lineWidth: 0.8)
        }
        .accessibilityLabel("チケット取得済み")
    }

    private func progressEditButton(for attempt: TicketAttempt) -> some View {
        Button {
            editingProgressAttempt = attempt
        } label: {
            FavorecoIcon(systemName: "pencil", size: 16)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("このチケットスケジュールの日付を編集")
    }

    private func theaterProgressMetadataChip(
        _ title: String,
        isEntryRoute: Bool
    ) -> some View {
        let foreground = isEntryRoute
            ? TicketProgressColorPalette.entryRouteChipText
            : TicketProgressColorPalette.metadataChipText
        let border = isEntryRoute
            ? TicketProgressColorPalette.entryRouteChipBorder
            : TicketProgressColorPalette.metadataChipBorder

        return Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
                TicketProgressColorPalette.metadataChipSurface.opacity(0.86),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(border.opacity(isEntryRoute ? 0.78 : 0.24), lineWidth: 0.7)
            }
    }

    private func theaterActionLabel(_ title: String, systemImage: String) -> some View {
        FavorecoIconLabel(title, systemImage: systemImage, iconSize: 16)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(TheaterCategoryStyle.ticketActionRose)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .padding(.horizontal, 5)
            .overlay {
                Capsule()
                    .stroke(TheaterCategoryStyle.ticketActionRose.opacity(0.86), lineWidth: 0.8)
            }
    }
}

private struct CategoryComingUpRow: View {
    let plan: Plan
    let category: RecordCategory
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    private var activeAttempt: TicketAttempt? {
        guard let attempts = plan.ticketAttempts else { return nil }
        return TicketAttemptPresentationOrder.sorted(
            attempts.filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
            }
        ).first
    }

    var body: some View {
        if let activeAttempt {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(spacing: 0) {
                        Text(FavorecoDateText.monthDay(plan.startsAt))
                            .font(FavorecoTypography.latinDisplay(24, weight: .semibold, relativeTo: .title2))
                            .monospacedDigit()
                        Text(FavorecoDateText.weekdayName(plan.startsAt))
                            .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                    }
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 50)

                    CategoryFeaturePoster(
                        item: .plan(plan),
                        fallbackIcon: category.iconSymbol,
                        tint: tint
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(TicketStatusDefinition.name(for: activeAttempt.statusKey))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                        Text(plan.title.isEmpty ? "予定" : plan.title)
                            .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
                        if !plan.venueNameSnapshot.isEmpty {
                            Text(plan.venueNameSnapshot)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                let item = CategoryTicketProgressItem(plan: plan, attempt: activeAttempt)
                TicketProgressTimelineView(
                    stages: item.stages,
                    currentIndex: item.currentStageIndex,
                    nodeBackground: cardBackground,
                    secondaryTextColor: secondaryTextColor,
                    completedTint: TicketProgressColorPalette.completedNeutral
                )
            }
            .padding(10)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 0.75)
            }
        } else {
            FavorecoComingUpRow(
                date: plan.startsAt,
                categoryName: category.name,
                title: plan.title.isEmpty ? "予定" : plan.title,
                venue: plan.venueNameSnapshot,
                tint: tint,
                isTheater: isTheater,
                isLive: isLive
            ) {
                CategoryFeaturePoster(
                    item: .plan(plan),
                    fallbackIcon: category.iconSymbol,
                    tint: tint
                )
            }
        }
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return .primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.62) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.58) }
        return .secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.82)
    }
}

private struct CategoryScheduleEmptyRow: View {
    let icon: String
    let title: String
    let actionTitle: String?
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: Circle())

            Text(title)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 8)

            if let actionTitle {
                Text(actionTitle)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isTheater || isLive ? 0.34 : 0.16), lineWidth: 0.75)
        }
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.78) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.78) }
        return Color.secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.64)
    }
}

private struct CategoryFeatureCarousel: View {
    let title: String
    let japaneseTitle: String
    let emptyMessage: String
    let items: [CategoryFeatureItem]
    @Binding var selectedIndex: Int
    let tint: Color
    let fallbackIcon: String
    let onOpenPlan: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: title,
                    japaneseTitle: japaneseTitle,
                    foregroundColor: .primary
                )

                Spacer(minLength: 0)

            }

            if items.isEmpty {
                Button(action: onAdd) {
                    CategoryFeatureEmptyCard(message: emptyMessage, tint: tint, fallbackIcon: fallbackIcon)
                }
                .buttonStyle(.plain)
            } else if items.count == 1 {
                CategoryFeatureCardLink(
                    item: items[0],
                    tint: tint,
                    fallbackIcon: fallbackIcon,
                    onOpenPlan: onOpenPlan,
                    onOpenVisit: onOpenVisit
                )
            } else {
                GeometryReader { geometry in
                    let cardWidth = max(0, geometry.size.width - 36)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                CategoryFeatureCardLink(
                                    item: item,
                                    tint: tint,
                                    fallbackIcon: fallbackIcon,
                                    onOpenPlan: onOpenPlan,
                                    onOpenVisit: onOpenVisit
                                )
                                    .frame(width: cardWidth, alignment: .top)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 18, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: selectedPosition)
                }
                .frame(height: CategoryFeatureHeroMetrics.cardHeight)

                HStack(spacing: 7) {
                    ForEach(items.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? tint : Color.secondary.opacity(0.28))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var selectedPosition: Binding<Int?> {
        Binding(
            get: { selectedIndex },
            set: { newValue in
                if let newValue {
                    selectedIndex = newValue
                }
            }
        )
    }
}

private struct CategoryFeatureCardLink: View {
    let item: CategoryFeatureItem
    let tint: Color
    let fallbackIcon: String
    let onOpenPlan: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void

    var body: some View {
        switch item {
        case .plan(let plan):
            CategoryFeaturePlanCard(
                item: item,
                plan: plan,
                tint: tint,
                fallbackIcon: fallbackIcon,
                onOpen: { onOpenPlan(plan.id) }
            )
        case .visit(let visit):
            Button {
                onOpenVisit(visit.id)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon) {
                    CategoryFeatureSingleActionLabel(
                        title: item.actionText,
                        systemImage: item.actionIcon,
                        tint: tint
                    )
                }
            }
            .buttonStyle(.plain)
        case .interest(let event):
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon) {
                    CategoryFeatureSingleActionLabel(
                        title: item.actionText,
                        systemImage: item.actionIcon,
                        tint: tint
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CategoryFeaturePlanCard: View {
    let item: CategoryFeatureItem
    let plan: Plan
    let tint: Color
    let fallbackIcon: String
    let onOpen: () -> Void
    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false

    init(
        item: CategoryFeatureItem,
        plan: Plan,
        tint: Color,
        fallbackIcon: String,
        onOpen: @escaping () -> Void
    ) {
        self.item = item
        self.plan = plan
        self.tint = tint
        self.fallbackIcon = fallbackIcon
        self.onOpen = onOpen
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        CategoryFeatureCard(
            item: item,
            tint: tint,
            fallbackIcon: fallbackIcon,
            onOpen: onOpen
        ) {
            HStack(spacing: 6) {
                Button(action: onOpen) {
                    CategoryFeatureActionLabel(
                        title: "予定詳細",
                        systemImage: "book.pages",
                        tint: tint
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    isShowingEditPlan = true
                } label: {
                    CategoryFeatureActionLabel(
                        title: "編集",
                        systemImage: "pencil",
                        tint: tint,
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)
                .frame(width: 58)
                .disabled(currentPlans.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
    }
}

private struct CategoryFeatureCard<Actions: View>: View {
    let item: CategoryFeatureItem
    let tint: Color
    let fallbackIcon: String
    let onOpen: (() -> Void)?
    let actions: Actions

    init(
        item: CategoryFeatureItem,
        tint: Color,
        fallbackIcon: String,
        onOpen: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.item = item
        self.tint = tint
        self.fallbackIcon = fallbackIcon
        self.onOpen = onOpen
        self.actions = actions()
    }

    var body: some View {
        CategoryFeatureHeroLayout(posterAspectRatio: posterAspectRatio) {
            interactivePoster

            VStack(alignment: .leading, spacing: 4) {
                interactiveDetails

                Spacer(minLength: 0)

                actions
            }
        }
        .frame(height: CategoryFeatureHeroMetrics.contentHeight, alignment: .top)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.75)
        }
    }

    private var posterAspectRatio: CGFloat {
        if let event = item.event {
            return CGFloat(EyecatchAspectRatio.resolved(for: event).value)
        }
        return 0.7
    }

    @ViewBuilder
    private var interactivePoster: some View {
        let poster = CategoryFeaturePoster(
            item: item,
            fallbackIcon: fallbackIcon,
            tint: tint
        )
        if let onOpen {
            poster
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
        } else {
            poster
        }
    }

    @ViewBuilder
    private var interactiveDetails: some View {
        if let onOpen {
            detailsContent
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
        } else {
            detailsContent
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.badgeText)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(tint)

            Text(item.title)
                .font(FavorecoTypography.jpSerif(18.5, weight: .bold, relativeTo: .headline))
                .lineSpacing(-2)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.primary.opacity(0.68))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if !item.dateText.isEmpty {
                FavorecoIconLabel(item.dateText, systemImage: "calendar", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.placeText.isEmpty {
                FavorecoIconLabel(item.placeText, systemImage: "mappin.and.ellipse", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.detailText.isEmpty {
                Text(item.detailText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryFeatureActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isPrimary: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            FavorecoIcon(systemName: systemImage, size: isPrimary ? 12 : 10.5)
            Text(title)
        }
            .font(FavorecoTypography.jpSans(isPrimary ? 12 : 10.5, weight: isPrimary ? .semibold : .medium, relativeTo: .caption))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .overlay {
                Capsule().stroke(tint.opacity(0.48), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private struct CategoryFeatureSingleActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        CategoryFeatureActionLabel(title: title, systemImage: systemImage, tint: tint)
    }
}

private enum CategoryFeatureHeroMetrics {
    static let contentHeight: CGFloat = 224
    static let cardHeight: CGFloat = contentHeight + 24
}

private struct CategoryFeatureHeroLayout: Layout {
    let posterAspectRatio: CGFloat
    private let posterFraction: CGFloat = 0.45
    private let maximumPosterWidth: CGFloat = 152.5
    private let spacing: CGFloat = 14

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 340
        let availableWidth = max(0, width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.55, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio
        let detailsSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailsWidth, height: posterHeight)
        )
        return CGSize(width: width, height: max(posterHeight, detailsSize.height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let availableWidth = max(0, bounds.width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.55, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: posterWidth, height: posterHeight)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + posterWidth + spacing, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailsWidth, height: max(posterHeight, bounds.height))
        )
    }
}

private struct CategoryFeaturePoster: View {
    let item: CategoryFeatureItem
    let fallbackIcon: String
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            if isTheater {
                TheaterPosterArtwork(
                    reference: item.event.map { .event($0.id) },
                    backgroundColor: tint.opacity(0.08)
                ) { size in
                    CategoryDefaultArtworkImage(templateKey: "theater", displaySize: size)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ThumbnailImage(
                    reference: item.event.map { .event($0.id) },
                    displaySize: geometry.size,
                    contentMode: usesEyecatchFill ? .fill : .fit
                ) {
                    CategoryDefaultArtworkImage(
                        templateKey: item.event?.category?.templateKey ?? "",
                        displaySize: geometry.size
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: usesPosterFill ? 0 : 7, style: .continuous))
            }
        }
    }

    private var isTheater: Bool {
        item.event?.category?.templateKey == "theater"
    }

    private var usesPosterFill: Bool {
        EyecatchAspectRatio.usesPosterFill(for: item.event?.category)
    }

    private var usesEyecatchFill: Bool {
        EyecatchAspectRatio.usesEyecatchFill(for: item.event?.category)
    }
}

private struct CategoryFeatureEmptyCard: View {
    let message: String
    let tint: Color
    let fallbackIcon: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                tint.opacity(0.14)
                FavorecoIcon(systemName: fallbackIcon, size: 32)
                    .foregroundStyle(tint)
            }
            .frame(width: 104, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("まだ記録・予定がありません")
                    .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title3))
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FavorecoIconLabel("追加する", systemImage: "plus.circle.fill", iconSize: 13)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
            }
            Spacer()
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: CategoryFeatureHeroMetrics.cardHeight,
            maxHeight: CategoryFeatureHeroMetrics.cardHeight
        )
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.75)
        }
    }
}

private struct CategoryFeatureMetricsGrid: View {
    let metrics: [MiniStatisticsItem]
    let tint: Color
    var backgroundColor: Color = Color(.systemBackground)
    var primaryTextColor: Color = .primary
    var secondaryTextColor: Color = .secondary
    var borderColor: Color? = nil
    var dividerColor: Color? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(dividerColor ?? tint.opacity(0.20))
                        .frame(width: 1, height: 76)
                }

                VStack(spacing: 6) {
                    FavorecoIcon(systemName: metric.icon, size: 12)
                        .foregroundStyle(tint)
                    Text(metric.title)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(metric.value)
                            .font(FavorecoTypography.latinDisplay(24, weight: .bold, relativeTo: .title3))
                            .foregroundStyle(primaryTextColor)
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
            }
        }
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor ?? tint.opacity(0.16), lineWidth: 0.75)
        }
    }
}

private struct CategoryVisitRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録")
                .font(FavorecoTypography.cardTitle)
                .lineLimit(2)
            HStack(spacing: 10) {
                FavorecoIconLabel(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar", iconSize: 13)
                if !visit.venueNameSnapshot.isEmpty {
                    FavorecoIconLabel(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse", iconSize: 13)
                        .lineLimit(1)
                }
                if visit.overallRating > 0 {
                    Label(String(format: "%.1f", visit.overallRating), systemImage: "star.fill")
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyStateMessage: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let category = RecordCategory(
        name: "観劇",
        iconSymbol: "theatermasks.fill",
        colorHex: "#8B2F45",
        isBuiltIn: true,
        templateKey: "theater",
        enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,money,officialInfo,memo"
    )

    NavigationStack {
        CategoryTopView(category: category)
    }
    .environmentObject(PurchaseManager.shared)
    .environmentObject(CreateEntryContextRouter())
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, Plan.self], inMemory: true)
}
