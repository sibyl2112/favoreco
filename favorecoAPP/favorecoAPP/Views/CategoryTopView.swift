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
    @AppStorage("goshuinBook.registeredSizeKeys") private var goshuinBookRegisteredSizeKeysRaw = ""
    @AppStorage("goshuinBook.closedSizeKeys") private var goshuinBookClosedSizeKeysRaw = ""
    @AppStorage("goshuinBook.sortOrderKeys") private var goshuinBookSortOrderKeysRaw = ""
    @State private var isShowingAddExperience = false
    @State private var isShowingTheaterPerformanceRegistration = false
    @State private var isShowingInterestedTargetRegistration = false
    @State private var selectedEventForNewVisit: ExperienceEvent?
    @State private var selectedCategoryID: UUID
    @State private var goshuinFilter: GoshuinVisitFilter = .all
    @State private var goshuinMapFilter: GoshuinVisitFilter = .all
    @State private var goshuinListLimit = 10
    @State private var selectedGoshuinPrefecture = ""
    @State private var isShowingGoshuinSearch = false
    @State private var selectedGoshuinBook: GoshuinBookSelection?
    @State private var isShowingGoshuinBookManagement = false
    @State private var goshuinShareImage: UIImage?
    @State private var isShowingGoshuinShare = false
    @State private var goshuinShareLocked = false
    @State private var selectedFeatureCarouselIndex = 0
    @State private var selectedGoshuinHeroIndex = 0
    @State private var libraryLayoutModes: [String: CategoryLibraryLayoutMode]
    @State private var screenWorkFilter: ScreenWorkFilter = .all
    @State private var isShowingAllUpcomingPlans = false
    @State private var isShowingAllTicketManagementPlans = false
    @State private var isShowingAllTheaterVisits = false
    @State private var isShowingArchivedTheaterEvents = false
    @State private var isShowingCategorySettings = false
    @State private var selectedCategoryDetail: CategoryDetailPanelSelection?
    @State private var selectedCategoryEventID: UUID?
    @State private var selectedBookSeries: BookSeriesRoute?
    @State private var selectedPlaceDetail: PlaceExperienceDetailSelection?
    @State private var isShowingTicketOverview = false
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
                centeredTitle: CategoryTopPresentationPolicy.displayName(
                    name: activeCategory.name,
                    templateKey: activeCategory.templateKey
                ),
                usesCompactBrand: true,
                brandGradient: CategoryTopPresentationPolicy.brandGradient(
                    templateKey: activeCategory.templateKey
                ),
                headerForegroundColor: CategoryTopPresentationPolicy.headerForeground(
                    templateKey: activeCategory.templateKey
                ),
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
                            VStack(alignment: .leading, spacing: 18) {
                            if activeCategory.templateKey == "movie" {
                                ScreenWorkFilterBar(
                                    selection: $screenWorkFilter,
                                    tint: categoryAccent(activeCategory)
                                )
                            }

                            if CategoryTopTickerPolicy.supports(activeCategory.templateKey) {
                                categoryTopTicker(category: activeCategory, snapshot: snapshot)
                            }

                            Group {
                                if activeCategory.templateKey == "goshuin" {
                                    goshuinHero(category: activeCategory, snapshot: snapshot)
                                } else if activeCategory.templateKey == "random_goods" {
                                    CollectibleCategoryHero(
                                        events: resolvedEvents(in: snapshot),
                                        snapshot: snapshot,
                                        tint: categoryAccent(activeCategory),
                                        onAdd: { isShowingAddExperience = true }
                                    )
                                } else if PerformanceTicketManagementPolicy.usesFullPlanCard(
                                    templateKey: activeCategory.templateKey
                                ) {
                                    performanceTicketManagementSection(category: activeCategory)
                                } else if CategoryPlanningHeroPolicy.usesIntegratedHero(activeCategory.templateKey) {
                                    categoryPriorityHero(category: activeCategory, snapshot: snapshot)
                                } else if CategoryMemoryHeroPolicy.supports(activeCategory.templateKey) {
                                    CategoryMemoryHeroSection(
                                        visits: resolvedVisits(in: snapshot),
                                        category: activeCategory,
                                        tint: categoryAccent(activeCategory),
                                        onOpen: { visit in
                                            selectedCategoryDetail = .visit(visit.id)
                                        }
                                    )
                                    .padding(.horizontal, -20)
                                }
                            }
                            .id("category-hero-\(activeCategory.id.uuidString)")

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
                                        ArchivedTheaterEventsEntry(
                                            category: activeCategory,
                                            onOpen: { isShowingArchivedTheaterEvents = true }
                                        )
                                    } else if activeCategory.templateKey == "goshuin" {
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        goshuinContent(category: activeCategory, snapshot: snapshot)
                                            .id(CategoryScrollAnchor.events)
                                    } else if activeCategory.templateKey == "random_goods" {
                                        CollectibleCategorySeriesGrid(
                                            events: resolvedEvents(in: snapshot),
                                            tint: categoryAccent(activeCategory),
                                            onAdd: { isShowingAddExperience = true },
                                            onOpenSeries: openCategoryEvent
                                        )
                                        .id(CategoryScrollAnchor.events)
                                    } else if activeCategory.templateKey == "live" {
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
                                    } else {
                                        if !CategoryTopTickerPolicy.supports(activeCategory.templateKey) {
                                            categoryStats(category: activeCategory, snapshot: snapshot)
                                        }
                                        categoryTicketProgressSection(category: activeCategory)
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
                                        if CategoryTopPresentationPolicy.supportsVisitedPlacesMap(
                                            templateKey: activeCategory.templateKey
                                        ) {
                                            VisitedPlacesHeatMapSection(
                                                visits: resolvedVisits(in: snapshot),
                                                category: activeCategory,
                                                tint: categoryAccent(activeCategory)
                                            )
                                            .id("visited-places-map-\(activeCategory.id.uuidString)")
                                        }
                                    }
                                    CategoryChapterFooter(
                                        categories: visibleCategories,
                                        currentCategory: activeCategory,
                                        tint: categoryAccent(activeCategory),
                                        onSelect: { selectedCategory in
                                            switchCategory(to: selectedCategory)
                                            Task { @MainActor in
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    scrollProxy.scrollTo(CategoryScrollAnchor.top, anchor: .top)
                                                }
                                            }
                                        },
                                        onOpenSettings: { isShowingCategorySettings = true }
                                    )
                            }
                            .id("category-content-\(activeCategory.id.uuidString)")
                        }
                        .padding(.top, 12)
                        .id(CategoryScrollAnchor.top)
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(
            CategoryTopBackground(
                style: CategoryTopPresentationPolicy.backgroundStyle(
                    templateKey: activeCategory.templateKey
                ),
                categoryColor: themePalette.categoryColor(hex: activeCategory.colorHex),
                colorScheme: colorScheme
            )
        )
        .environment(
            \.colorScheme,
            CategoryTopPresentationPolicy.usesAtmosphericDarkStyle(
                templateKey: activeCategory.templateKey
            ) ? .dark : colorScheme
        )
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
            Group {
                if activeCategory.templateKey == "random_goods" {
                    AddCollectibleSeriesView(category: activeCategory)
                } else {
                    AddExperienceView(category: activeCategory)
                }
            }
            .favorecoRegistrationTheme(categoryHex: activeCategory.colorHex)
        }
        .sheet(isPresented: $isShowingTheaterPerformanceRegistration) {
            TheaterPerformanceRegistrationView(category: activeCategory)
                .favorecoRegistrationTheme(categoryHex: activeCategory.colorHex)
        }
        .sheet(isPresented: $isShowingInterestedTargetRegistration) {
            QuickRegistrationView(
                initialTemplateKey: activeCategory.templateKey,
                screenTitle: CategoryTopVocabulary.interestRegistrationTitle(
                    templateKey: activeCategory.templateKey
                ),
                locksCategory: true
            )
            .favorecoRegistrationTheme(categoryHex: activeCategory.colorHex)
        }
        .sheet(isPresented: $isShowingTicketOverview) {
            NavigationStack {
                TicketOverviewView(showsCloseButton: true, initialFilter: .needsAction)
            }
        }
        .sheet(item: $ticketDetailsEditAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt)
                    .favorecoRegistrationTheme(categoryHex: activeCategory.colorHex)
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
                .favorecoRegistrationTheme(categoryHex: event.category?.colorHex)
        }
        .sheet(item: $selectedGoshuinBook) { selection in
            GoshuinBookGalleryView(selection: selection)
        }
        .sheet(isPresented: $isShowingGoshuinBookManagement) {
            GoshuinBookManagementView(
                registeredSizeKeysRaw: $goshuinBookRegisteredSizeKeysRaw,
                closedSizeKeysRaw: $goshuinBookClosedSizeKeysRaw,
                sortOrderKeysRaw: $goshuinBookSortOrderKeysRaw,
                representedSizeKeys: Set(
                    resolvedVisits(in: snapshot).map {
                        let key = VisitUnitFields(rawValue: $0.unitFieldsRaw).goshuinBookSizeKey
                        return key.isEmpty ? GoshuinBookSize.standard.key : key
                    }
                )
            )
        }
        .sheet(isPresented: $isShowingGoshuinSearch) {
            GoshuinPrefectureSearchView(
                selectedPrefecture: $selectedGoshuinPrefecture,
                availablePrefectures: GoshuinTopContentBuilder.availablePrefectures(
                    in: resolvedVisits(in: snapshot)
                )
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
    private func categoryTopTicker(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> some View {
        if category.templateKey == "book" {
            BookYearStatusStrip(
                items: categoryLibraryItems(category: category, snapshot: snapshot),
                tint: categoryAccent(category)
            )
        } else {
            CategoryTopStatusStrip(
                items: categoryStatisticsItems(category: category, snapshot: snapshot),
                tint: categoryAccent(category)
            )
        }
    }

    private func categoryStatisticsItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryStatisticsItem] {
        let libraryItems = ["theater", "book"].contains(category.templateKey)
            ? categoryLibraryItems(category: category, snapshot: snapshot)
            : []
        let visits = ["museum", "goshuin"].contains(category.templateKey)
            ? resolvedVisits(in: snapshot)
            : []
        return CategoryStatisticsItemBuilder.make(
            category: category,
            snapshot: snapshot,
            libraryItems: libraryItems,
            visits: visits
        )
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
                japaneseTitle: CategoryTopVocabulary.featureCarouselJapaneseTitle(
                    templateKey: category.templateKey
                ),
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

    private func openInterestRegistration(for category: RecordCategory) {
        if ["theater", "live"].contains(category.templateKey) {
            isShowingTheaterPerformanceRegistration = true
        } else {
            isShowingInterestedTargetRegistration = true
        }
    }

    private func performanceTicketManagementSection(category: RecordCategory) -> some View {
        let plans = CategoryTopPlanSelection.ticketManagementPlans(
            from: allPlans,
            category: category,
            now: Date()
        )
        let visiblePlans = isShowingAllTicketManagementPlans ? plans : Array(plans.prefix(1))
        let tint = categoryAccent(category)
        let isLive = category.templateKey == "live"
        let primaryTextColor = isLive ? LiveCategoryStyle.mist : TheaterCategoryStyle.ivory
        let actionColor = isLive ? tint : TheaterCategoryStyle.ticketActionRose

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: "Ticket Management",
                    japaneseTitle: "チケット管理",
                    foregroundColor: primaryTextColor
                )

                Text("\(plans.count)件")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(actionColor)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    isShowingTicketOverview = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(actionColor)
                }
                .buttonStyle(.plain)
            }

            if plans.isEmpty {
                CategoryScheduleEmptyRow(
                    icon: "checkmark.circle",
                    title: "対応が必要なチケットはありません",
                    actionTitle: nil,
                    tint: tint,
                    isTheater: !isLive,
                    isLive: isLive
                )
            } else {
                ForEach(visiblePlans) { plan in
                    PerformanceTicketManagementPlanCard(
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
                            isShowingAllTicketManagementPlans.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(
                                isShowingAllTicketManagementPlans
                                    ? "閉じる"
                                    : "さらに見る（残り\(plans.count - 1)件）"
                            )
                            Image(
                                systemName: isShowingAllTicketManagementPlans
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(actionColor)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: category.id) { _, _ in
            isShowingAllTicketManagementPlans = false
        }
        .onChange(of: plans.count) { _, count in
            if count <= 1 {
                isShowingAllTicketManagementPlans = false
            }
        }
    }

    private func categoryComingUpSection(category: RecordCategory) -> some View {
        let isTheater = category.templateKey == "theater"
        let plans: [Plan] = switch category.templateKey {
        case "theater": CategoryTopPlanSelection.theaterComingUpPlans(
            from: allPlans,
            category: category,
            now: Date()
        )
        case "live": CategoryTopPlanSelection.liveComingUpPlans(
            from: allPlans,
            category: category,
            now: Date()
        )
        default: CategoryTopPlanSelection.upcomingPlans(
            from: allPlans,
            category: category,
            screenWorkFilter: screenWorkFilter,
            now: Date()
        )
        }
        let visiblePlans = isShowingAllUpcomingPlans ? plans : Array(plans.prefix(1))
        let tint = categoryAccent(category)
        let isLive = category.templateKey == "live"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: "Coming Up",
                    japaneseTitle: CategoryTopVocabulary.sectionJapaneseTitle(
                        englishTitle: "Coming Up",
                        templateKey: category.templateKey
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
                                title: CategoryTopPlanSelection.theaterPlanTitle(plan),
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

    private func priorityHeroItems(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [CategoryFeatureItem] {
        let now = Date()
        return CategoryFeatureContentBuilder.priorityItems(
            category: category,
            allPlans: allPlans,
            events: resolvedEvents(in: snapshot, category: category),
            screenWorkFilter: screenWorkFilter,
            now: now
        )
    }

    private func featureMetrics(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [MiniStatisticsItem] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let visits = resolvedVisits(in: snapshot)
        return CategoryFeatureContentBuilder.metrics(
            category: category,
            snapshot: snapshot,
            visits: visits,
            calendar: calendar,
            currentYear: currentYear
        )
    }

    private func goshuinContent(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let visits = resolvedVisits(in: snapshot)
        let filteredVisits = GoshuinTopContentBuilder.filteredVisits(visits, filter: goshuinFilter)
        let mapVisits = GoshuinTopContentBuilder.mapVisits(
            visits,
            filter: goshuinMapFilter,
            selectedPrefecture: selectedGoshuinPrefecture
        )
        let displayedVisits = Array(mapVisits.prefix(goshuinListLimit))
        let books = GoshuinTopContentBuilder.bookSelections(
            from: visits,
            registeredSizeKeysRaw: goshuinBookRegisteredSizeKeysRaw,
            closedSizeKeysRaw: goshuinBookClosedSizeKeysRaw,
            sortOrderKeysRaw: goshuinBookSortOrderKeysRaw
        )

        return VStack(alignment: .leading, spacing: 18) {
            categoryLibrarySubsection(
                title: "Interests",
                items: categoryLibraryItems(category: category, snapshot: snapshot).filter {
                    $0.event.stateKey == "interested"
                },
                sectionKey: "interests",
                emptyIcon: "heart",
                emptyTitle: "気になる寺社はまだありません",
                category: category,
                tint: categoryAccent(category)
            )

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
                                GoshuinStampTile(
                                    visit: visit,
                                    photo: GoshuinTopContentBuilder.firstPhoto(in: visit)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    LayeredCategorySectionTitle(
                        englishTitle: "Goshuin Books",
                        japaneseTitle: "御朱印帳",
                        foregroundColor: .primary
                    )
                    Spacer()
                    Button {
                        isShowingGoshuinBookManagement = true
                    } label: {
                        FavorecoIconLabel("編集", systemImage: "slider.horizontal.3", iconSize: 12)
                    }
                    .font(FavorecoTypography.captionStrong)
                    .buttonStyle(.plain)
                }

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
        let partition = CategoryLibraryPartitionBuilder.make(
            templateKey: category.templateKey,
            items: items
        )
        let showsPlaceExperienceSections = partition.showsPlaceExperienceSections
        let showsPlanningSections = partition.showsPlanningSections
        let showsIntegratedPlanningHero = CategoryPlanningHeroPolicy.usesIntegratedHero(category.templateKey)
        let separatesInterests = showsPlanningSections
        let showsBookSections = partition.showsBookSections
        // 「記録」と名付ける一覧は対象マスターではなく、1回ごとのVisitだけを扱う。
        let showsVisitRecordLibrary = partition.showsVisitRecordLibrary
        let interestedItems = partition.interestedItems
        let showsFacilityPlaceLibrary = showsPlaceExperienceSections || category.templateKey == "museum"
        let facilityLibrary = showsFacilityPlaceLibrary
            ? CategoryFacilityLibraryBuilder.make(
                category: category,
                allPlans: allPlans,
                allVisits: allVisits,
                allPlaceMasters: allPlaceMasters
            )
            : .empty
        let facilityPlaces = facilityLibrary.places
        // 施設系は PlaceMaster を唯一の施設一覧にする。旧構造の ExperienceEvent は
        // 統合Heroまたは専用の予定・気になる表示とLogで扱い、施設情報へ重複表示しない。
        let displayedProductionItems = partition.displayedProductionItems
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

                PlaceExperienceLogSection(
                    category: category,
                    visits: resolvedVisits(in: snapshot),
                    events: resolvedEvents(in: snapshot),
                    tint: tint,
                    primaryTextColor: CategoryTopPresentationPolicy.libraryPrimaryTextColor(
                        templateKey: category.templateKey
                    ),
                    secondaryTextColor: CategoryTopPresentationPolicy.librarySecondaryTextColor(
                        templateKey: category.templateKey
                    ),
                    onSelectEvent: { event in
                        selectedEventForNewVisit = event
                    },
                    onOpenVisit: { visit in
                        selectedCategoryDetail = .visit(visit.id)
                    }
                )

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
            } else if CategoryMemoryHeroPolicy.supports(category.templateKey) {
                if showsComingUp {
                    categoryComingUpSection(category: category)

                    Spacer()
                        .frame(height: 8)
                }

                categoryLibrarySubsection(
                    title: "Interests",
                    items: interestedItems,
                    sectionKey: "interests",
                    emptyIcon: "heart",
                    emptyTitle: category.templateKey == "museum"
                        ? "気になる展示はまだありません"
                        : "気になるものはまだありません",
                    category: category,
                    tint: tint
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
                && !CategoryMemoryHeroPolicy.supports(category.templateKey)
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
                CategoryVisitRecordLibrarySection(
                    category: category,
                    items: CategoryVisitRecordItemBuilder.make(
                        category: category,
                        visits: resolvedVisits(in: snapshot),
                        screenWorkFilter: screenWorkFilter
                    ),
                    tint: tint,
                    primaryTextColor: CategoryTopPresentationPolicy.libraryPrimaryTextColor(
                        templateKey: category.templateKey
                    ),
                    secondaryTextColor: CategoryTopPresentationPolicy.librarySecondaryTextColor(
                        templateKey: category.templateKey
                    ),
                    selectedLayout: Binding(
                        get: {
                            libraryLayoutMode(for: category) == .gallery ? .gallery : .banner
                        },
                        set: { selectLibraryLayout($0, for: category) }
                    ),
                    onOpenVisit: { visit in
                        selectedCategoryDetail = .visit(visit.id)
                    }
                )

                if category.templateKey == "live" {
                    Spacer()
                        .frame(height: 8)

                    categoryLibrarySubsection(
                        title: "Live Information",
                        items: displayedProductionItems,
                        sectionKey: "productions",
                        emptyIcon: category.iconSymbol,
                        emptyTitle: "ライブ情報はまだありません",
                        category: category,
                        tint: tint,
                        layout: .banner
                    )
                } else if category.templateKey == "museum" {
                    Spacer()
                        .frame(height: 8)

                    CategoryFacilityLibrarySection(
                        category: category,
                        library: facilityLibrary,
                        tint: tint,
                        primaryTextColor: CategoryTopPresentationPolicy.libraryPrimaryTextColor(
                            templateKey: category.templateKey
                        ),
                        secondaryTextColor: CategoryTopPresentationPolicy.librarySecondaryTextColor(
                            templateKey: category.templateKey
                        ),
                        selectedLayout: Binding(
                            get: { facilityLibraryLayoutMode(for: category) },
                            set: { selectFacilityLibraryLayout($0, for: category) }
                        ),
                        onOpen: { place in
                            selectedPlaceDetail = PlaceExperienceDetailSelection(
                                placeID: place.id,
                                categoryID: category.id
                            )
                        }
                    )
                }
            } else if !showsBookSections {
            CategoryLibrarySectionChrome(
                category: category,
                targetSectionTitle: recordTemplate.targetSectionTitle,
                itemCount: productionCount,
                tint: tint,
                primaryTextColor: CategoryTopPresentationPolicy.libraryPrimaryTextColor(
                    templateKey: category.templateKey
                ),
                secondaryTextColor: CategoryTopPresentationPolicy.librarySecondaryTextColor(
                    templateKey: category.templateKey
                ),
                selectedLayout: Binding(
                    get: { libraryLayoutMode(for: category) },
                    set: { selectLibraryLayout($0, for: category) }
                )
            )

            if productionCount > 0 {
                if !facilityPlaces.isEmpty {
                    CategoryFacilityLibraryContent(
                        category: category,
                        library: facilityLibrary,
                        tint: tint,
                        layout: selectedLayout,
                        onOpen: { place in
                            selectedPlaceDetail = PlaceExperienceDetailSelection(
                                placeID: place.id,
                                categoryID: category.id
                            )
                        }
                    )
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
    private func categoryLibrarySubsection(
        title: String,
        items: [CategoryLibraryItem],
        sectionKey: String,
        emptyIcon: String,
        emptyTitle: String,
        category: RecordCategory,
        tint: Color,
        layout: CategoryLibraryLayoutMode? = nil
    ) -> some View {
        let resolvedLayout = layout ?? libraryLayoutMode(for: category)

        CategoryLibrarySubsection(
            title: title,
            items: items,
            sectionKey: sectionKey,
            emptyIcon: emptyIcon,
            emptyTitle: emptyTitle,
            category: category,
            tint: tint,
            layout: resolvedLayout,
            displayKey: CategoryTopLibraryPolicy.displayKey(
                categoryID: category.id,
                sectionKey: sectionKey,
                layout: resolvedLayout
            ),
            primaryTextColor: CategoryTopPresentationPolicy.libraryPrimaryTextColor(
                templateKey: category.templateKey
            ),
            secondaryTextColor: CategoryTopPresentationPolicy.librarySecondaryTextColor(
                templateKey: category.templateKey
            ),
            onAddInterest: {
                openInterestRegistration(for: category)
            },
            onOpenEvent: openCategoryEvent
        )
    }

    @ViewBuilder
    private func categoryLibraryItemsContent(
        items: [CategoryLibraryItem],
        sectionKey: String,
        category: RecordCategory,
        tint: Color,
        layout: CategoryLibraryLayoutMode
    ) -> some View {
        let pageSize = CategoryTopLibraryPolicy.pageSize(for: layout)
        let key = CategoryTopLibraryPolicy.displayKey(
            categoryID: category.id,
            sectionKey: sectionKey,
            layout: layout
        )

        ProgressiveCategoryLibraryContent(
            items: items,
            category: category,
            tint: tint,
            layout: layout,
            pageSize: pageSize,
            showsProductionMetadata: CategoryEventInformationPolicy.usesParentEventCard(
                templateKey: category.templateKey,
                sectionKey: sectionKey
            ),
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

    private func libraryLayoutMode(for category: RecordCategory) -> CategoryLibraryLayoutMode {
        if category.templateKey == "live" {
            return .banner
        }
        let storedMode = libraryLayoutModes[category.templateKey]
            ?? CategoryLibraryLayoutMode.stored(for: category.templateKey)
        return CategoryTopLibraryPolicy.normalizedLayout(
            storedMode,
            templateKey: category.templateKey
        )
    }

    private func facilityLibraryLayoutMode(for category: RecordCategory) -> CategoryLibraryLayoutMode {
        let storageKey = CategoryTopLibraryPolicy.facilityStorageKey(
            templateKey: category.templateKey
        )
        let storedMode = libraryLayoutModes[storageKey]
            ?? CategoryLibraryLayoutMode.stored(for: storageKey)
        return CategoryTopLibraryPolicy.normalizedFacilityLayout(storedMode)
    }

    private func selectFacilityLibraryLayout(
        _ mode: CategoryLibraryLayoutMode,
        for category: RecordCategory
    ) {
        let storageKey = CategoryTopLibraryPolicy.facilityStorageKey(
            templateKey: category.templateKey
        )
        let resolvedMode = CategoryTopLibraryPolicy.normalizedFacilityLayout(mode)
        libraryLayoutModes[storageKey] = resolvedMode
        resolvedMode.store(for: storageKey)
    }

    private func selectLibraryLayout(
        _ mode: CategoryLibraryLayoutMode,
        for category: RecordCategory
    ) {
        let resolvedMode = CategoryTopLibraryPolicy.normalizedLayout(
            mode,
            templateKey: category.templateKey
        )
        libraryLayoutModes[category.templateKey] = resolvedMode
        guard category.templateKey != "live" else {
            return
        }
        resolvedMode.store(for: category.templateKey)
    }

    @ViewBuilder
    private func categoryTicketProgressSection(category: RecordCategory) -> some View {
        let items = CategoryTicketProgressItem.topItems(in: allPlans, category: category)
        if ["theater", "live"].contains(category.templateKey) || !items.isEmpty {
            CategoryTicketProgressSection(
                items: items,
                title: ["theater", "live"].contains(category.templateKey)
                    ? "Ticket Management"
                    : "チケット進捗",
                japaneseTitle: ["theater", "live"].contains(category.templateKey)
                    ? "チケット管理"
                    : nil,
                usesLatinTitle: category.templateKey == "theater" || category.templateKey == "live",
                usesTheaterStyle: category.templateKey == "theater",
                usesLiveStyle: category.templateKey == "live",
                showsCategoryInSelector: false,
                fixedTint: categoryAccent(category)
            )
            .id("ticket-progress-\(category.id.uuidString)")
        }
    }

    private func categoryLibraryItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryLibraryItem] {
        let now = Date()
        return CategoryLibraryItemBuilder.make(
            category: category,
            eventSnapshots: snapshot.events,
            categoryVisits: resolvedVisits(in: snapshot),
            eventsByID: resolvedEventsByID(in: snapshot, category: category),
            allPlans: allPlans,
            groupsByPlace: CategoryTopLibraryPolicy.isPlaceExperience(
                templateKey: category.templateKey
            ),
            now: now
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

    private func categoryAccent(_ category: RecordCategory) -> Color {
        category.templateKey == "live"
            ? LiveCategoryStyle.teal
            : themePalette.categoryColor(hex: category.colorHex)
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
