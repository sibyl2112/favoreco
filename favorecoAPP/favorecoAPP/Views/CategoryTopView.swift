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
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \RecordCategory.sortOrder) private var allCategories: [RecordCategory]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @Query(sort: \Plan.startsAt, order: .forward) private var allPlans: [Plan]
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @State private var isShowingAddExperience = false
    @State private var selectedEventForNewVisit: ExperienceEvent?
    @State private var selectedCategoryID: UUID
    @State private var transitionMovesForward = true
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
    @State private var isShowingAllUpcomingPlans = false

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
                onLeadingTap: { dismiss() }
            )
            .padding(.horizontal, 20)
            .padding(.top, -4)
            .padding(.bottom, 6)

            GenreNavigationStrip(
                categories: snapshot.visibleCategories,
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
                            Group {
                                if activeCategory.templateKey == "goshuin" {
                                    goshuinHero(category: activeCategory, snapshot: snapshot)
                                } else {
                                    categoryPriorityHero(category: activeCategory, snapshot: snapshot)
                                }
                            }
                            .id("category-hero-\(activeCategory.id.uuidString)")
                            .transition(categoryPageTransition)

                            GenreSwipeContainer(
                                canMoveBackward: !snapshot.visibleCategories.isEmpty,
                                canMoveForward: !snapshot.visibleCategories.isEmpty,
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
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        categoryTicketProgressSection(category: activeCategory)
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
                                    } else if activeCategory.templateKey == "goshuin" {
                                        categoryStats(category: activeCategory, snapshot: snapshot)
                                        goshuinContent(category: activeCategory, snapshot: snapshot)
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
                                                visits: snapshot.visits,
                                                category: activeCategory,
                                                tint: categoryAccent(activeCategory)
                                            )
                                            .id("visited-places-map-\(activeCategory.id.uuidString)")
                                        }
                                    }
                                    chapterFooter(
                                        categories: snapshot.visibleCategories,
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
                                .transition(categoryPageTransition)
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
        .animation(categorySwitchAnimation, value: activeCategory.id)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingAddExperience) {
            AddExperienceView(category: activeCategory)
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
                availablePrefectures: goshuinAvailablePrefectures(in: snapshot.visits)
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
        .onAppear {
            homeSelectedCategoryTemplateKey = activeCategory.templateKey
        }
        .task(id: activeCategory.id) {
            await preloadAdjacentCategoryThumbnails(around: activeCategory)
        }
    }

    private func hero(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category.iconSymbol)
                    .font(.title)
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
                Label(snapshot.events.isEmpty ? "最初の記録を追加" : "記録を追加", systemImage: "plus.circle.fill")
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
        let featuredEvent = snapshot.events.first?.event

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
                    isShowingAddExperience = true
                } label: {
                    Label(snapshot.events.isEmpty ? "最初の記録を追加" : "記録を追加", systemImage: "plus")
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
        CategoryStatisticsPanel(
            items: categoryStatisticsItems(category: category, snapshot: snapshot),
            tint: categoryAccent(category),
            isTheater: category.templateKey == "theater",
            isLive: category.templateKey == "live"
        )
    }

    private func categoryStatisticsItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryStatisticsItem] {
        let values: [(String, String, String, String)]

        switch category.templateKey {
        case "theater":
            values = [
                ("作品・公演", "\(snapshot.eventCount)", "件", "総作品数"),
                ("観劇済み", "\(snapshot.visitCount)", "回", "総観劇数"),
                ("気になる", "\(snapshot.interestedEventCount)", "件", "観劇予定"),
            ]
        case "movie":
            values = [
                ("映画", "\(snapshot.eventCount)", "本", "総作品数"),
                ("鑑賞済み", "\(snapshot.visitCount)", "本", "総鑑賞数"),
                ("観たい", "\(snapshot.interestedEventCount)", "本", "鑑賞候補"),
            ]
        case "museum":
            let visitedVenueCount = museumVisitedVenueCount(in: snapshot.visits)
            let viewedEventCount = Set(snapshot.visits.compactMap { $0.event?.id }).count
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
            values = [
                ("本", "\(snapshot.eventCount)", "冊", "総登録数"),
                ("読了", "\(snapshot.visitCount)", "冊", "総読了数"),
                ("読みたい", "\(snapshot.interestedEventCount)", "冊", "読書候補"),
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
            let visitedPlaceCount = Set(snapshot.visits.compactMap { $0.event?.id }).count
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
        VStack(alignment: .leading, spacing: 12) {
            TheaterSectionHeader(title: recordTemplate.targetSectionTitle, count: snapshot.eventCount)

            if snapshot.events.isEmpty {
                TheaterEmptyState(
                    icon: "theatermasks",
                    title: "作品・公演はまだありません",
                    message: "最初の記録を追加すると、ここから同じ公演に回を重ねられます。"
                )
            } else {
                ForEach(snapshot.events.prefix(10)) { eventSnapshot in
                    TheaterEventRow(snapshot: eventSnapshot) {
                        selectedEventForNewVisit = eventSnapshot.event
                    }
                }
            }
        }
    }

    private func theaterRecentVisits(snapshot: CategoryTopSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterSectionHeader(title: "最近の観劇", count: snapshot.visitCount)

            if snapshot.visits.isEmpty {
                TheaterEmptyState(
                    icon: "ticket",
                    title: "観劇記録はまだありません",
                    message: "作品、観劇日、劇場、感想を入れるとここに並びます。"
                )
            } else {
                ForEach(snapshot.visits.prefix(10)) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        TheaterVisitRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryPriorityHero(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let items = priorityHeroItems(category: category, snapshot: snapshot)

        return VStack(alignment: .leading, spacing: 14) {
            CategoryFeatureCarousel(
                title: "Coming Up / Interests",
                emptyMessage: "これからの予定や興味のあるものを追加すると、ここに並びます。",
                items: items,
                selectedIndex: $selectedFeatureCarouselIndex,
                tint: categoryAccent(category),
                fallbackIcon: category.iconSymbol,
                onAdd: { isShowingAddExperience = true }
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

    private func categoryComingUpSection(category: RecordCategory) -> some View {
        let plans = categoryUpcomingPlans(category: category)
        let visiblePlans = isShowingAllUpcomingPlans ? plans : Array(plans.prefix(1))
        let tint = categoryAccent(category)
        let isTheater = category.templateKey == "theater"
        let isLive = category.templateKey == "live"

        return VStack(alignment: .leading, spacing: 10) {
            Text("Coming Up")
                .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(
                    isTheater
                        ? TheaterCategoryStyle.ivory
                        : isLive ? LiveCategoryStyle.mist : FavorecoTypography.brandColor(for: colorScheme)
                )

            if plans.isEmpty {
                Button {
                    NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                } label: {
                    CategoryScheduleEmptyRow(
                        icon: "calendar.badge.plus",
                        title: "次の予定はまだありません",
                        actionTitle: "予定を追加",
                        tint: tint,
                        isTheater: isTheater,
                        isLive: isLive
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(visiblePlans) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        CategoryComingUpRow(
                            plan: plan,
                            category: category,
                            tint: tint,
                            isTheater: isTheater,
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
        .onChange(of: category.id) { _, _ in
            isShowingAllUpcomingPlans = false
        }
    }

    private func categoryUpcomingPlans(category: RecordCategory) -> [Plan] {
        let now = Date()
        return allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.startsAt >= now
                    && (plan.category ?? plan.event?.category)?.id == category.id
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func priorityHeroItems(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [CategoryFeatureItem] {
        let now = Date()
        let upcomingPlans = allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.startsAt >= now
                    && (plan.category ?? plan.event?.category)?.id == category.id
            }
            .sorted { $0.startsAt < $1.startsAt }
        let plannedEventIDs = Set(upcomingPlans.compactMap { $0.event?.id })
        let interestedEvents = snapshot.events
            .map(\.event)
            .filter { $0.stateKey == "interested" && !plannedEventIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }

        let planItems = upcomingPlans.map(CategoryFeatureItem.plan)
        let interestItems = interestedEvents.map(CategoryFeatureItem.interest)
        return Array((planItems + interestItems).prefix(10))
    }

    private func featureMetrics(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [MiniStatisticsItem] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let yearVisits = snapshot.visits.filter { calendar.component(.year, from: $0.visitedAt) == currentYear }
        let ratedYearVisits = yearVisits.filter { $0.overallRating > 0 }
        let averageText: String = {
            guard !ratedYearVisits.isEmpty else { return "-" }
            let average = ratedYearVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedYearVisits.count)
            return String(format: "%.1f", average)
        }()
        let ratedVisits = snapshot.visits.filter { $0.overallRating > 0 }
        let movieReviewText: String = {
            guard !ratedVisits.isEmpty else { return "-" }
            let average = ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
            return String(format: "%.1f", average)
        }()

        switch category.templateKey {
        case "movie":
            return [
                MiniStatisticsItem(title: "総鑑賞数", value: "\(snapshot.visitCount)", unit: "本", icon: "movieclapper"),
                MiniStatisticsItem(title: "年間数", value: "\(yearVisits.count)", unit: "本", icon: "calendar"),
                MiniStatisticsItem(title: "観たい", value: "\(snapshot.interestedEventCount)", unit: "本", icon: "bookmark"),
                MiniStatisticsItem(title: "レビュー", value: movieReviewText, unit: movieReviewText == "-" ? "" : "点", icon: "text.bubble"),
            ]
        case "book":
            let favoriteCount = snapshot.visits.filter { $0.overallRating >= 4.5 }.count
            return [
                MiniStatisticsItem(title: "総冊数", value: "\(snapshot.eventCount)", unit: "冊", icon: "books.vertical"),
                MiniStatisticsItem(title: "年間冊数", value: "\(yearVisits.count)", unit: "冊", icon: "calendar"),
                MiniStatisticsItem(title: "年間評価", value: averageText, unit: "", icon: "star"),
                MiniStatisticsItem(title: "お気に入り", value: "\(favoriteCount)", unit: "冊", icon: "bookmark"),
            ]
        case "theme_park":
            let repeatCount = repeatVisitCount(in: snapshot.visits)
            return [
                MiniStatisticsItem(title: "総来園数", value: "\(snapshot.visitCount)", unit: "回", icon: "ticket"),
                MiniStatisticsItem(title: "年間来園", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "件", icon: "bookmark"),
            ]
        case "nature_living":
            let repeatCount = repeatVisitCount(in: snapshot.visits)
            let encounteredCount = encounteredItemCount(in: snapshot.visits)
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
        let filteredVisits = goshuinFilteredVisits(in: snapshot.visits, filter: goshuinFilter)
        let mapVisits = goshuinMapVisits(in: snapshot.visits)
        let displayedVisits = Array(mapVisits.prefix(goshuinListLimit))
        let books = goshuinBookSelections(from: snapshot.visits)

        return VStack(alignment: .leading, spacing: 18) {
            GoshuinFilterBar(selection: $goshuinFilter, options: [.all, .shrine, .temple, .limited, .special])

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("御朱印")
                        .font(FavorecoTypography.sectionTitle)
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
                            NavigationLink {
                                ExperienceDetailView(visit: visit)
                            } label: {
                                GoshuinStampTile(visit: visit, photo: firstPhoto(in: visit))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("使用中の御朱印帳")
                    .font(FavorecoTypography.sectionTitle)

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
                HStack {
                    Text("行った神社・お寺MAP")
                        .font(FavorecoTypography.sectionTitle)
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
                        Label(selectedGoshuinPrefecture, systemImage: "mappin.and.ellipse")
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
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
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
        let recentVisits = Array(snapshot.visits.sorted { $0.visitedAt > $1.visitedAt }.prefix(5))

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
                ForEach(snapshot.events.prefix(10)) { eventSnapshot in
                    EventRow(snapshot: eventSnapshot) {
                        selectedEventForNewVisit = eventSnapshot.event
                    }
                }
            }
        }
    }

    private func categoryLibrarySection(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        recordTemplate: CategoryRecordTemplate
    ) -> some View {
        let selectedLayout = libraryLayoutMode(for: category)
        let items = categoryLibraryItems(category: category, snapshot: snapshot)
        let usesLatinLibraryStyle = category.templateKey == "theater" || category.templateKey == "live"
        let showsPlanningSections = ["theater", "live", "museum", "movie"].contains(category.templateKey)
        let separatesInterests = showsPlanningSections
        let showsBookSections = category.templateKey == "book"
        let interestedItems: [CategoryLibraryItem] = if showsPlanningSections {
            items.filter { $0.event.stateKey == "interested" && $0.nextPlan == nil }
        } else if showsBookSections {
            items.filter { $0.event.stateKey == "interested" }
        } else {
            []
        }
        let unreadBookItems = showsBookSections
            ? items.filter { $0.event.stateKey != "interested" && $0.latestVisit == nil }
            : []
        let productionItems: [CategoryLibraryItem] = if showsPlanningSections {
            items.filter { $0.event.stateKey != "interested" }
        } else if showsBookSections {
            items.filter { $0.event.stateKey != "interested" && $0.latestVisit != nil }
        } else {
            items
        }
        let tint: Color = switch category.templateKey {
        case "theater": TheaterCategoryStyle.gold
        case "live": LiveCategoryStyle.teal
        default: themePalette.categoryColor(hex: category.colorHex)
        }

        return VStack(alignment: .leading, spacing: 12) {
            if showsBookSections {
                categoryLibrarySubsection(
                    title: "気になる！",
                    items: interestedItems,
                    sectionKey: "book-interests",
                    emptyIcon: "heart",
                    emptyTitle: "気になる本はまだありません",
                    category: category,
                    tint: tint
                )

                Spacer()
                    .frame(height: 8)

                categoryLibrarySubsection(
                    title: "積読",
                    items: unreadBookItems,
                    sectionKey: "book-unread",
                    emptyIcon: "books.vertical",
                    emptyTitle: "積読はまだありません",
                    category: category,
                    tint: tint
                )

                Spacer()
                    .frame(height: 8)
            } else if separatesInterests {
                categoryLibrarySubsection(
                    title: "Interests",
                    items: interestedItems,
                    sectionKey: "interests",
                    emptyIcon: "heart",
                    emptyTitle: "気になるものはまだありません",
                    category: category,
                    tint: tint
                )

                Spacer()
                    .frame(height: 8)
            }

            if showsPlanningSections {
                categoryComingUpSection(category: category)

                Spacer()
                    .frame(height: 8)
            }

            HStack(spacing: 12) {
                Text(librarySectionTitle(category: category, fallback: recordTemplate.targetSectionTitle))
                    .font(
                        usesLatinLibraryStyle
                            ? FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3)
                            : FavorecoTypography.sectionTitle
                    )
                    .foregroundStyle(libraryPrimaryTextColor(category))

                Text("\(productionItems.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(librarySecondaryTextColor(category))

                Spacer(minLength: 4)

                if category.templateKey != "live" {
                    CategoryLibraryLayoutPicker(
                        selection: Binding(
                            get: { libraryLayoutMode(for: category) },
                            set: { selectLibraryLayout($0, for: category) }
                        ),
                        tint: tint,
                        onSelect: { _ in }
                    )
                }
            }

            if productionItems.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "\(recordTemplate.targetSectionTitle)はまだありません",
                    message: "最初の記録や予定を追加すると、ここに並びます。",
                    tint: tint
                )
            } else {
                categoryLibraryItemsContent(
                    items: productionItems,
                    sectionKey: "productions",
                    category: category,
                    tint: tint,
                    layout: selectedLayout
                )
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
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(
                    ["theater", "live", "museum", "movie"].contains(category.templateKey)
                        ? FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3)
                        : FavorecoTypography.sectionTitle
                )
                .foregroundStyle(libraryPrimaryTextColor(category))

            Text("\(items.count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(librarySecondaryTextColor(category))
        }

        if items.isEmpty {
            CategoryScheduleEmptyRow(
                icon: emptyIcon,
                title: emptyTitle,
                actionTitle: nil,
                tint: tint,
                isTheater: category.templateKey == "theater",
                isLive: category.templateKey == "live"
            )
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
            pageSize: pageSize
        )
        .id(key)
    }

    private func libraryPageSize(for layout: CategoryLibraryLayoutMode) -> Int {
        switch layout {
        case .gallery: 9
        case .compact: 8
        case .banner: 6
        }
    }

    private func libraryLayoutMode(for category: RecordCategory) -> CategoryLibraryLayoutMode {
        if category.templateKey == "live" {
            return .banner
        }
        return libraryLayoutModes[category.templateKey]
            ?? CategoryLibraryLayoutMode.stored(for: category.templateKey)
    }

    private func selectLibraryLayout(
        _ mode: CategoryLibraryLayoutMode,
        for category: RecordCategory
    ) {
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
        default: fallback
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
        if !items.isEmpty {
            CategoryTicketProgressSection(
                items: items,
                title: ["theater", "live"].contains(category.templateKey) ? "Ticket Progress" : "チケット進捗",
                usesLatinTitle: ["theater", "live"].contains(category.templateKey),
                usesTheaterStyle: category.templateKey == "theater",
                usesLiveStyle: category.templateKey == "live",
                showsCategoryInSelector: false,
                fixedTint: categoryAccent(category)
            )
            .id("ticket-progress-\(category.id.uuidString)")
        }
    }

    private func categoryTicketProgressItems(category: RecordCategory) -> [CategoryTicketProgressItem] {
        CategoryTicketProgressItem.activeItems(in: allPlans, categoryID: category.id)
    }

    private func categoryLibraryItems(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryLibraryItem] {
        let now = Date()
        let visitsByEventID = Dictionary(grouping: snapshot.visits) { $0.event?.id }
        let plansByEventID = Dictionary(grouping: allPlans.filter { plan in
            !plan.isArchived
                && (plan.category ?? plan.event?.category)?.id == category.id
                && plan.event != nil
        }) { $0.event?.id }

        return snapshot.events.map { eventSnapshot in
            let eventID = eventSnapshot.event.id
            let latestVisit = visitsByEventID[eventID]?.max(by: { $0.visitedAt < $1.visitedAt })
            let eventPlans = plansByEventID[eventID] ?? []
            let nextPlan = eventPlans
                .filter { $0.startsAt >= now }
                .min(by: { $0.startsAt < $1.startsAt })
            let attempts = TicketAttemptPresentationOrder.sorted(
                eventPlans.flatMap { $0.ticketAttempts ?? [] }.filter { !$0.isArchived },
                now: now
            )
            return CategoryLibraryItem(
                event: eventSnapshot.event,
                latestVisit: latestVisit,
                nextPlan: nextPlan,
                ticketAttempts: attempts
            )
        }
        .sorted { lhs, rhs in
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

    private func movieWatchedSection(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> some View {
        let items = movieWatchedItems(in: snapshot)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("観た映画")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "観た映画はまだありません",
                    message: "映画を観た記録を追加すると、ポスターがここに並びます。",
                    tint: themePalette.categoryColor(hex: category.colorHex)
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(items.prefix(12)) { item in
                        NavigationLink {
                            EventDetailView(event: item.event)
                        } label: {
                            MovieWatchedPosterTile(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func movieWatchedItems(in snapshot: CategoryTopSnapshot) -> [MovieWatchedItem] {
        let visitsByEventID = Dictionary(grouping: snapshot.visits) { $0.event?.id }

        return snapshot.events.compactMap { eventSnapshot in
            guard let latestVisit = visitsByEventID[eventSnapshot.event.id]?
                .max(by: { $0.visitedAt < $1.visitedAt }) else { return nil }
            return MovieWatchedItem(event: eventSnapshot.event, latestVisit: latestVisit)
        }
        .sorted { $0.latestVisit.visitedAt > $1.latestVisit.visitedAt }
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

            if snapshot.visits.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "まだ記録がありません",
                    message: "タイトル、日付、場所、評価、メモだけの軽い記録から始められます。",
                    tint: themePalette.categoryColor(hex: category.colorHex)
                )
            } else {
                ForEach(snapshot.visits.prefix(10)) { visit in
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

    private var categoryPageTransition: AnyTransition {
        if transitionMovesForward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private var categorySwitchAnimation: Animation {
        .timingCurve(0.16, 0.82, 0.24, 1, duration: 0.22)
    }

    private func switchCategory(to destination: RecordCategory) {
        guard destination.id != currentCategory.id else { return }
        let currentIndex = visibleCategories.firstIndex(where: { $0.id == currentCategory.id }) ?? 0
        let destinationIndex = visibleCategories.firstIndex(where: { $0.id == destination.id }) ?? currentIndex
        transitionMovesForward = destinationIndex > currentIndex
        homeSelectedCategoryTemplateKey = destination.templateKey
        if destination.templateKey == "goshuin" {
            selectedGoshuinHeroIndex = 0
        }

        withAnimation(categorySwitchAnimation) {
            selectedCategoryID = destination.id
            if libraryLayoutModes[destination.templateKey] == nil {
                libraryLayoutModes[destination.templateKey] = CategoryLibraryLayoutMode.stored(for: destination.templateKey)
            }
        }
    }

    private func neighboringCategory(from category: RecordCategory, offset: Int) -> RecordCategory? {
        guard let index = visibleCategories.firstIndex(where: { $0.id == category.id }) else { return nil }
        let destinationIndex = index + offset
        guard visibleCategories.indices.contains(destinationIndex) else { return nil }
        return visibleCategories[destinationIndex]
    }

    private func preloadAdjacentCategoryThumbnails(around category: RecordCategory) async {
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }

        let adjacentCategories = [-1, 1].compactMap {
            neighboringCategory(from: category, offset: $0)
        }

        for adjacentCategory in adjacentCategories {
            guard !Task.isCancelled else { return }
            let snapshot = CategoryTopSnapshot.make(
                category: adjacentCategory,
                categories: allCategories,
                visits: allVisits
            )
            let requests = thumbnailPreloadRequests(category: adjacentCategory, snapshot: snapshot)
            await Task.detached(priority: .utility) {
                for request in requests {
                    guard !Task.isCancelled else { return }
                    _ = ThumbnailLoader.makeThumbnail(
                        from: request.data,
                        maxPixelSize: request.maxPixelSize,
                        cacheKey: request.cacheKey
                    )
                }
            }.value
        }
    }

    private func thumbnailPreloadRequests(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot
    ) -> [CategoryThumbnailPreloadRequest] {
        var requests: [CategoryThumbnailPreloadRequest] = []
        var cacheKeys = Set<String>()

        func append(_ photo: PhotoBlob, maxPixelSize: CGFloat, cacheKey: String) {
            guard cacheKeys.insert(cacheKey).inserted,
                  ThumbnailLoader.cached(forKey: cacheKey) == nil else { return }
            requests.append(
                CategoryThumbnailPreloadRequest(
                    data: photo.data,
                    maxPixelSize: maxPixelSize,
                    cacheKey: cacheKey
                )
            )
        }

        for eventSnapshot in snapshot.events.prefix(4) {
            guard let photo = EventRepresentativePhotoResolver.photo(for: eventSnapshot.event) else { continue }
            let maxPixelSize: CGFloat = 220
            append(
                photo,
                maxPixelSize: maxPixelSize,
                cacheKey: "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
            )
        }

        let listMaxPixelSize = min(80 * displayScale, 480)
        for visit in snapshot.visits.prefix(4) {
            guard let photo = firstPhoto(in: visit) else { continue }
            append(
                photo,
                maxPixelSize: listMaxPixelSize,
                cacheKey: "\(photo.id.uuidString)@\(Int(listMaxPixelSize.rounded()))"
            )
        }

        if category.templateKey != "goshuin" {
            for item in priorityHeroItems(category: category, snapshot: snapshot).prefix(2) {
                guard let photo = item.visit.flatMap({ firstPhoto(in: $0) })
                    ?? item.event.flatMap({ EventRepresentativePhotoResolver.photo(for: $0) }) else { continue }
                let maxPixelSize: CGFloat = 520
                append(
                    photo,
                    maxPixelSize: maxPixelSize,
                    cacheKey: "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
                )
            }
        } else {
            for visit in snapshot.visits.prefix(4) {
                guard let photo = firstPhoto(in: visit) else { continue }
                let maxPixelSize: CGFloat = 360
                append(
                    photo,
                    maxPixelSize: maxPixelSize,
                    cacheKey: "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
                )
            }
        }

        return requests
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

            if previousCategory != nil || nextCategory != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("別の章へ")
                        .font(FavorecoTypography.sectionTitle)

                    HStack(alignment: .top, spacing: 12) {
                        if let previousCategory {
                            let previousSnapshot = CategoryTopSnapshot.make(
                                category: previousCategory,
                                categories: allCategories,
                                visits: allVisits
                            )
                            ChapterPreviewCard(
                                directionTitle: "前の章",
                                category: previousCategory,
                                snapshot: previousSnapshot,
                                photo: chapterPreviewPhoto(in: previousSnapshot),
                                isNext: false,
                                action: { onSelect(previousCategory) }
                            )
                        }

                        if let nextCategory {
                            let nextSnapshot = CategoryTopSnapshot.make(
                                category: nextCategory,
                                categories: allCategories,
                                visits: allVisits
                            )
                            ChapterPreviewCard(
                                directionTitle: "次の章",
                                category: nextCategory,
                                snapshot: nextSnapshot,
                                photo: chapterPreviewPhoto(in: nextSnapshot),
                                isNext: true,
                                action: { onSelect(nextCategory) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func chapterPreviewPhoto(in snapshot: CategoryTopSnapshot) -> PhotoBlob? {
        for visit in snapshot.visits.prefix(6) {
            if let photo = (visit.photos ?? [])
                .filter({ $0.mediaKind == "photo" && $0.hasStoredData })
                .min(by: { $0.createdAt < $1.createdAt }) {
                return photo
            }
        }
        return nil
    }
}

struct GenreSwipeContainer<Content: View>: View {
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onMove: (Int) -> Void
    @ViewBuilder let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var suppressesContentTap = false

    var body: some View {
        content
            .contentShape(Rectangle())
            .disabled(suppressesContentTap)
            .offset(x: dragOffset)
            .background {
                GeometryReader { geometry in
                    DirectionalHorizontalPanInstaller(
                        onBegan: {},
                        onChanged: { translation in
                            if abs(translation) >= 16 {
                                suppressesContentTap = true
                            }
                            let direction = translation < 0 ? 1 : -1
                            let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
                            dragOffset = hasDestination ? translation : translation * 0.18
                        },
                        onEnded: { translation, velocity in
                            finishGesture(translation: translation, velocity: velocity)
                        },
                        onCancelled: {
                            settleBack()
                            restoreContentTap()
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
    }

    private func finishGesture(translation: CGFloat, velocity: CGFloat) {
        let projectedTranslation = translation + velocity * 0.16
        let direction = translation < 0 ? 1 : -1
        let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
        let shouldMove = abs(translation) >= 72 || abs(projectedTranslation) >= 140

        if shouldMove && hasDestination {
            dragOffset = 0
            onMove(direction)
        } else {
            settleBack()
        }
        restoreContentTap()
    }

    private func settleBack() {
        withAnimation(.timingCurve(0.18, 0.78, 0.24, 1, duration: 0.18)) {
            dragOffset = 0
        }
    }

    private func restoreContentTap() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            suppressesContentTap = false
        }
    }
}

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
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
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
            true
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

private enum CategoryScrollAnchor {
    static let top = "category-top"
    static let events = "category-events"
    static let recentVisits = "category-recent-visits"
}

private struct CategoryThumbnailPreloadRequest: Sendable {
    let data: Data
    let maxPixelSize: CGFloat
    let cacheKey: String
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
        var values = [FavorecoDateText.compactDateTime(plan.startsAt)]
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

struct CategoryTicketProgressSection: View {
    let items: [CategoryTicketProgressItem]
    let title: String
    let usesLatinTitle: Bool
    let usesTheaterStyle: Bool
    let usesLiveStyle: Bool
    let showsCategoryInSelector: Bool
    let fixedTint: Color?

    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedAttemptID: UUID?

    init(
        items: [CategoryTicketProgressItem],
        title: String,
        usesLatinTitle: Bool,
        usesTheaterStyle: Bool,
        usesLiveStyle: Bool = false,
        showsCategoryInSelector: Bool,
        fixedTint: Color? = nil
    ) {
        self.items = items
        self.title = title
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
            HStack {
                Text(title)
                    .font(sectionTitleFont)
                    .foregroundStyle(primaryTextColor)

                Spacer()

                NavigationLink {
                    TicketOverviewView()
                } label: {
                    HStack(spacing: 3) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
            }

            if items.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(items) { item in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    selectedAttemptID = item.id
                                }
                            } label: {
                                Text(showsCategoryInSelector ? item.crossGenreSelectorTitle : item.selectorTitle)
                                    .font(FavorecoTypography.captionStrong)
                                    .foregroundStyle(selectedAttemptID == item.id ? Color.white : tint)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(
                                        selectedAttemptID == item.id ? tint : tint.opacity(0.10),
                                        in: Capsule()
                                    )
                                    .overlay {
                                        Capsule()
                                            .stroke(tint.opacity(selectedAttemptID == item.id ? 0 : 0.28), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(showsCategoryInSelector ? item.crossGenreSelectorTitle : item.selectorTitle)のチケット進捗")
                            .accessibilityAddTraits(selectedAttemptID == item.id ? .isSelected : [])
                        }
                    }
                }
                .clipped()
            }

            if let selectedItem {
                NavigationLink {
                    PlanDetailView(plan: selectedItem.plan)
                } label: {
                    CategoryTicketProgressCard(
                        item: selectedItem,
                        tint: tint,
                        isTheater: usesTheaterStyle,
                        isLive: usesLiveStyle
                    )
                }
                .buttonStyle(.plain)
                .id(selectedItem.id)
                .transition(.opacity)
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if let selectedAttemptID, ids.contains(selectedAttemptID) { return }
            self.selectedAttemptID = ids.first
        }
    }

    private var primaryTextColor: Color {
        if usesTheaterStyle { return TheaterCategoryStyle.ivory }
        if usesLiveStyle { return LiveCategoryStyle.mist }
        return Color.primary
    }

    private var sectionTitleFont: Font {
        usesLatinTitle
            ? FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3)
            : FavorecoTypography.sectionTitle
    }
}

private struct CategoryTicketProgressCard: View {
    let item: CategoryTicketProgressItem
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.title)
                .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(item.metadataChips, id: \.self) { chip in
                        Text(chip)
                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(tint.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.28), lineWidth: 1)
                            }
                    }
                }
            }
            .clipped()

            TicketProgressTimelineView(
                stages: item.stages,
                currentIndex: item.currentStageIndex,
                tint: tint,
                nodeBackground: cardBackground,
                secondaryTextColor: secondaryTextColor
            )
        }
        .padding(9)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    tint.opacity(isTheater || isLive ? 0.48 : 0.20),
                    lineWidth: isTheater || isLive ? 0.7 : 0.75
                )
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

private struct TicketProgressTimelineView: View {
    let stages: [TicketProgressStage]
    let currentIndex: Int
    let tint: Color
    let nodeBackground: Color
    let secondaryTextColor: Color

    private let nodeDiameter: CGFloat = 34

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        if index < stages.count - 1 {
                            TicketProgressConnectorShape()
                                .stroke(
                                    index < currentIndex ? tint : secondaryTextColor.opacity(0.54),
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
                                state: nodeState(at: index),
                                tint: tint,
                                background: nodeBackground,
                                diameter: nodeDiameter
                            )

                            Group {
                                if let date = stage.date {
                                    Text(FavorecoDateText.monthDay(date))
                                } else {
                                    Text("—")
                                }
                            }
                                .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
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

    var body: some View {
        ZStack {
            Circle()
                .fill(state == .completed ? tint : background)

            if state == .current {
                Circle()
                    .stroke(tint, lineWidth: 2)
                Circle()
                    .stroke(tint, lineWidth: 1)
                    .padding(3.5)
            } else if state == .future {
                Circle()
                    .stroke(Color.secondary.opacity(0.52), lineWidth: 1.5)
            }

            Text(title)
                .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                .foregroundStyle(state == .completed ? Color.white : (state == .current ? tint : Color.primary))
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

private struct CategoryLibraryItem: Identifiable {
    let event: ExperienceEvent
    let latestVisit: Visit?
    let nextPlan: Plan?
    let ticketAttempts: [TicketAttempt]

    var id: UUID { event.id }

    var title: String {
        event.title.isEmpty ? "記録" : event.title
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
                case "waitingPayment": return "入金待ち"
                case "waitingIssue": return "発券待ち"
                case "issued": return "発券済み"
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
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Text(item.galleryDateText)
                .foregroundStyle(item.galleryDateColor)
                .minimumScaleFactor(0.72)

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
            Image(systemName: "calendar")
                .font(.system(size: max(7.5, fontSize - 0.5), weight: .medium))

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
            Image(systemName: systemImage)
                .font(.system(size: 7.5, weight: .medium))

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
                aspectRatioOverride: artworkWidth / cardHeight
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
                .stroke(tint.opacity(0.20), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilitySummary)
    }
}

struct CategoryLibraryLayoutPicker: View {
    @Binding var selection: CategoryLibraryLayoutMode
    let tint: Color
    let onSelect: (CategoryLibraryLayoutMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CategoryLibraryLayoutMode.allCases) { mode in
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

    @State private var visibleCount: Int

    init(
        items: [CategoryLibraryItem],
        category: RecordCategory,
        tint: Color,
        layout: CategoryLibraryLayoutMode,
        pageSize: Int
    ) {
        self.items = items
        self.category = category
        self.tint = tint
        self.layout = layout
        self.pageSize = pageSize
        _visibleCount = State(initialValue: pageSize)
    }

    var body: some View {
        let effectiveVisibleCount = min(items.count, visibleCount)
        let visibleItems = Array(items.prefix(effectiveVisibleCount))

        VStack(alignment: .leading, spacing: 10) {
            switch layout {
            case .gallery:
                CategoryLibraryGallery(items: visibleItems, category: category, tint: tint)
            case .compact:
                CategoryLibraryCompactGrid(items: visibleItems, category: category, tint: tint)
            case .banner:
                CategoryLibraryBannerList(items: visibleItems, category: category, tint: tint)
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

private struct CategoryLibraryGallery: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        CategoryLibraryArtwork(item: item, category: category)

                        CategoryGalleryMetadata(item: item, tint: tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(galleryCardBackground)
                    .overlay {
                        Rectangle()
                            .stroke(tint.opacity(0.18), lineWidth: 0.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilitySummary)
            }
        }
    }

    private var galleryCardBackground: Color {
        switch category.templateKey {
        case "theater": TheaterCategoryStyle.tileBackground
        case "live": LiveCategoryStyle.tileBackground
        default: Color(.secondarySystemBackground)
        }
    }
}

private struct CategoryLibraryCompactGrid: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 2
    )
    private let artworkWidth: CGFloat = 58

    private let cardHeight: CGFloat = 106

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    if category.templateKey == "movie" {
                        MovieCompactLibraryCard(item: item, category: category, tint: tint)
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            CategoryLibraryArtwork(
                                item: item,
                                category: category,
                                aspectRatioOverride: artworkWidth / (cardHeight - 16)
                            )
                            .frame(width: artworkWidth, height: cardHeight - 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(FavorecoTypography.jpSans(11, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(.primary)
                                    .tracking(-0.35)
                                    .lineSpacing(-1.5)
                                    .lineLimit(2, reservesSpace: true)

                                CompactTileDateView(
                                    text: item.compactTileDateText,
                                    color: item.dateColor,
                                    fontSize: 9
                                )

                                if category.templateKey == "theater" {
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

                                CompactRatingView(
                                    rating: item.ratingValue,
                                    ratingText: item.ratingText,
                                    color: item.ratingColor,
                                    fontSize: 9.35
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
                        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(tint.opacity(0.20), lineWidth: 0.75)
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

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CategoryLibraryArtwork(item: item, category: category)
                            .frame(width: 82)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(item.bannerStatusText(for: category))
                                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .frame(height: 18)
                                    .background(tint.opacity(0.12), in: Capsule())

                                Spacer(minLength: 4)

                                let creditText = item.bannerCreditText(for: category)
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

                            if category.templateKey == "live", !item.event.seriesName.isEmpty {
                                Text(item.event.seriesName)
                                    .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                if item.dateText != "—" {
                                    Label(item.bannerDateTimeText, systemImage: "calendar")
                                        .foregroundStyle(item.nextPlan == nil ? Color.secondary : Color.red)
                                }
                                if !item.venueText.isEmpty {
                                    Label(item.venueText, systemImage: "mappin.and.ellipse")
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
                            .stroke(tint.opacity(0.20), lineWidth: 0.75)
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

private struct CategoryLibraryArtwork: View {
    let item: CategoryLibraryItem
    let category: RecordCategory
    var aspectRatioOverride: CGFloat? = nil

    private var representativePhoto: PhotoBlob? {
        EventRepresentativePhotoResolver.photo(for: item.event)
    }

    private var aspectRatio: CGFloat {
        aspectRatioOverride ?? CGFloat(EyecatchAspectRatio.resolved(for: item.event).value)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemFill)

                if let representativePhoto {
                    RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 520, contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if let data = item.event.eyecatchData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: category.iconSymbol)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
    }
}

private struct ChapterPreviewCard: View {
    let directionTitle: String
    let category: RecordCategory
    let snapshot: CategoryTopSnapshot
    let photo: PhotoBlob?
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

                previewImage

                Text(category.name.isEmpty ? "無題" : category.name)
                    .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(previewMessage)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(categoryTint.opacity(0.28), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(directionTitle)、\(category.name.isEmpty ? "無題" : category.name)")
        .accessibilityHint("このジャンルの先頭へ移動します")
    }

    @ViewBuilder
    private var previewImage: some View {
        if let photo {
            RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 104)
                .clipped()
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                LinearGradient(
                    colors: [categoryTint.opacity(0.28), categoryTint.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: category.iconSymbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(categoryTint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var previewMessage: String {
        if let eventSnapshot = snapshot.events.first {
            return eventSnapshot.event.title.isEmpty ? "記録があります" : eventSnapshot.event.title
        }
        if snapshot.visitCount > 0 {
            return "\(snapshot.visitCount)件の記録"
        }
        return "まだ記録はありません"
    }

    private var categoryTint: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }
}

private struct MovieWatchedItem: Identifiable {
    let event: ExperienceEvent
    let latestVisit: Visit

    var id: UUID { event.id }
}

private struct MovieWatchedPosterTile: View {
    let item: MovieWatchedItem

    private let posterAspectRatio = CGFloat(EyecatchAspectRatio.cinemaPoster.value)

    private var representativePhoto: PhotoBlob? {
        EventRepresentativePhotoResolver.photo(for: item.event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geometry in
                ZStack {
                    Color(.secondarySystemFill)

                    if let representativePhoto {
                        RepresentativePhotoImage(
                            photo: representativePhoto,
                            maxPixelSize: 420,
                            contentMode: .fill
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    } else if let data = item.event.eyecatchData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "movieclapper")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(posterAspectRatio, contentMode: .fit)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(FavorecoDateText.compactDate(item.latestVisit.visitedAt))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                Image(systemName: item.latestVisit.overallRating > 0 ? "star.fill" : "star")
                    .foregroundStyle(item.latestVisit.overallRating > 0 ? Color.yellow : Color.secondary)
                if item.latestVisit.overallRating > 0 {
                    Text(String(format: "%.1f", item.latestVisit.overallRating))
                        .monospacedDigit()
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.bottom, 7)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .overlay {
            Rectangle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("映画の作品詳細を開きます")
    }

    private var accessibilityLabel: String {
        let title = item.event.title.isEmpty ? "映画" : item.event.title
        let date = FavorecoDateText.compactDate(item.latestVisit.visitedAt)
        guard item.latestVisit.overallRating > 0 else {
            return "\(title)、\(date)、評価なし"
        }
        return "\(title)、\(date)、評価\(String(format: "%.1f", item.latestVisit.overallRating))"
    }
}

private enum TheaterCategoryStyle {
    static let wine = Color(red: 0.28, green: 0.035, blue: 0.08)
    static let deepWine = Color(red: 0.11, green: 0.025, blue: 0.04)
    static let black = Color(red: 0.025, green: 0.02, blue: 0.022)
    static let tileBackground = Color(red: 0.075, green: 0.045, blue: 0.05).opacity(0.94)
    static let gold = Color(red: 0.82, green: 0.62, blue: 0.30)
    static let lightGold = Color(red: 0.96, green: 0.82, blue: 0.52)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.84)

    static let brandGradient = LinearGradient(
        colors: [lightGold, Color(red: 0.70, green: 0.38, blue: 0.18), lightGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

private struct TheaterPosterView: View {
    let event: ExperienceEvent?
    let width: CGFloat

    private var representativePhoto: PhotoBlob? {
        event.flatMap { EventRepresentativePhotoResolver.photo(for: $0) }
    }

    var body: some View {
        Group {
            if let representativePhoto {
                RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 420, contentMode: .fill)
            } else if let data = event?.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    TheaterCategoryStyle.wine.opacity(0.72)
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(TheaterCategoryStyle.gold)
                }
            }
        }
        .frame(width: width, height: width * 1.414)
        .background(TheaterCategoryStyle.black)
        .clipped()
        .overlay {
            Rectangle()
                .stroke(TheaterCategoryStyle.gold.opacity(0.62), lineWidth: 0.7)
        }
    }
}

private struct TheaterSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(TheaterCategoryStyle.ivory)
            Spacer()
            Text("\(count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(TheaterCategoryStyle.gold)
        }
    }
}

private struct TheaterEventRow: View {
    let snapshot: CategoryEventSnapshot
    let onAddVisit: () -> Void

    private var event: ExperienceEvent { snapshot.event }

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            NavigationLink {
                EventDetailView(event: event)
            } label: {
                HStack(spacing: 13) {
                    TheaterPosterView(event: event, width: 72)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(TheaterCategoryStyle.ivory)
                            .lineLimit(2)

                        if !event.seriesName.isEmpty {
                            Text(event.seriesName)
                                .lineLimit(1)
                        }

                        HStack(spacing: 9) {
                            Label("\(snapshot.visitCount)件", systemImage: "number")
                            if let latestVisitDate = snapshot.latestVisitDate {
                                Label(FavorecoDateText.compactDate(latestVisitDate), systemImage: "calendar")
                            }
                        }
                    }
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button(action: onAddVisit) {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TheaterCategoryStyle.gold)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle().stroke(TheaterCategoryStyle.gold.opacity(0.65), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct TheaterVisitRow: View {
    let visit: Visit

    private var event: ExperienceEvent? { visit.event }

    var body: some View {
        HStack(spacing: 13) {
            TheaterPosterView(event: event, width: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(event?.title.isEmpty == false ? event?.title ?? "観劇記録" : "観劇記録")
                    .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                    .lineLimit(2)

                Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar")
                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TheaterCategoryStyle.gold.opacity(0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct TheaterEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TheaterCategoryStyle.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct EventRow: View {
    let snapshot: CategoryEventSnapshot
    let onAddVisit: () -> Void

    private var event: ExperienceEvent { snapshot.event }

    private var representativePhoto: PhotoBlob? {
        EventRepresentativePhotoResolver.photo(for: event)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                EventDetailView(event: event)
            } label: {
                HStack(spacing: 12) {
                    if let representativePhoto {
                        RepresentativePhotoImage(
                            photo: representativePhoto,
                            maxPixelSize: 220,
                            contentMode: EyecatchAspectRatio.usesEyecatchFill(for: event.category) ? .fill : .fit
                        )
                            .frame(width: 68, height: representativeImageHeight)
                            .clipped()
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if let data = event.eyecatchData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(
                                contentMode: EyecatchAspectRatio.usesEyecatchFill(for: event.category) ? .fill : .fit
                            )
                            .frame(width: 68, height: representativeImageHeight)
                            .clipped()
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.cardTitle)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            if !event.seriesName.isEmpty {
                                Label(event.seriesName, systemImage: "rectangle.stack")
                                    .lineLimit(1)
                            }
                            Label("\(snapshot.visitCount)件", systemImage: "number")
                            if let latestVisitDate = snapshot.latestVisitDate {
                                Label(FavorecoDateText.compactDate(latestVisitDate), systemImage: "calendar")
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
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
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
    let categoryName: String
    let title: String
    let venue: String
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    @ViewBuilder let artwork: Artwork

    init(
        date: Date,
        categoryName: String,
        title: String,
        venue: String,
        tint: Color,
        isTheater: Bool,
        isLive: Bool = false,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.date = date
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
        .accessibilityLabel("\(FavorecoDateText.compactDate(date))、\(categoryName)、\(title)、\(venue)")
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

private struct CategoryComingUpRow: View {
    let plan: Plan
    let category: RecordCategory
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
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

private struct CategoryScheduleEmptyRow: View {
    let icon: String
    let title: String
    let actionTitle: String?
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
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
    let emptyMessage: String
    let items: [CategoryFeatureItem]
    @Binding var selectedIndex: Int
    let tint: Color
    let fallbackIcon: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(FavorecoTypography.sectionTitle)

            if items.isEmpty {
                Button(action: onAdd) {
                    CategoryFeatureEmptyCard(message: emptyMessage, tint: tint, fallbackIcon: fallbackIcon)
                }
                .buttonStyle(.plain)
            } else if items.count == 1 {
                CategoryFeatureCardLink(item: items[0], tint: tint, fallbackIcon: fallbackIcon)
            } else {
                GeometryReader { geometry in
                    let cardWidth = max(0, geometry.size.width - 36)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                CategoryFeatureCardLink(item: item, tint: tint, fallbackIcon: fallbackIcon)
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

    var body: some View {
        switch item {
        case .plan(let plan):
            CategoryFeaturePlanCard(
                item: item,
                plan: plan,
                tint: tint,
                fallbackIcon: fallbackIcon
            )
        case .visit(let visit):
            NavigationLink {
                ExperienceDetailView(visit: visit)
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
                EventDetailView(event: event)
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
    @Query private var currentPlans: [Plan]
    @State private var isShowingPlanDetail = false
    @State private var isShowingEditPlan = false

    init(item: CategoryFeatureItem, plan: Plan, tint: Color, fallbackIcon: String) {
        self.item = item
        self.plan = plan
        self.tint = tint
        self.fallbackIcon = fallbackIcon
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        CategoryFeatureCard(
            item: item,
            tint: tint,
            fallbackIcon: fallbackIcon,
            onOpen: {
                isShowingPlanDetail = true
            }
        ) {
            HStack(spacing: 6) {
                Button {
                    isShowingPlanDetail = true
                } label: {
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
        .navigationDestination(isPresented: $isShowingPlanDetail) {
            if let currentPlan = currentPlans.first {
                PlanDetailView(plan: currentPlan)
            } else {
                ContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                ContentUnavailableView("予定が見つかりません", systemImage: "trash")
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
                Label(item.dateText, systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.placeText.isEmpty {
                Label(item.placeText, systemImage: "mappin.and.ellipse")
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
            Image(systemName: systemImage)
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
            Group {
                if let photo = item.visit.flatMap({ firstPhoto(in: $0) }) ?? item.event.flatMap({ EventRepresentativePhotoResolver.photo(for: $0) }) {
                    RepresentativePhotoImage(
                        photo: photo,
                        maxPixelSize: 520,
                        contentMode: usesEyecatchFill ? .fill : .fit
                    )
                } else if let data = item.event?.eyecatchData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: usesEyecatchFill ? .fill : .fit)
                } else {
                    ZStack {
                        tint.opacity(0.14)
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: usesPosterFill ? 0 : 7, style: .continuous))
        }
    }

    private var usesPosterFill: Bool {
        EyecatchAspectRatio.usesPosterFill(for: item.event?.category)
    }

    private var usesEyecatchFill: Bool {
        EyecatchAspectRatio.usesEyecatchFill(for: item.event?.category)
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
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
                Image(systemName: fallbackIcon)
                    .font(.system(size: 32, weight: .medium))
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
                Label("追加する", systemImage: "plus.circle.fill")
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
                    Image(systemName: metric.icon)
                        .font(.caption.weight(.semibold))
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

private enum GoshuinVisitFilter: String, CaseIterable, Identifiable {
    case all
    case shrine
    case temple
    case limited
    case special

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全て"
        case .shrine: return "神社"
        case .temple: return "お寺"
        case .limited: return "限定"
        case .special: return "特別"
        }
    }

    func matches(_ visit: Visit) -> Bool {
        switch self {
        case .all:
            return true
        case .shrine:
            return placeKind(for: visit) == .shrine
        case .temple:
            return placeKind(for: visit) == .temple
        case .limited:
            return searchableText(for: visit).contains("限定")
        case .special:
            let text = searchableText(for: visit)
            return text.contains("特別") || text.contains("特製") || text.contains("記念")
        }
    }

    private func placeKind(for visit: Visit) -> GoshuinPlaceKind {
        let text = searchableText(for: visit)
        if text.contains("寺") || text.contains("院") || text.contains("観音") || text.contains("薬師") {
            return .temple
        }
        if text.contains("神社") || text.contains("大社") || text.contains("宮") || text.contains("稲荷") {
            return .shrine
        }
        return .unknown
    }

    private func searchableText(for visit: Visit) -> String {
        [
            visit.event?.title ?? "",
            visit.venueNameSnapshot,
            visit.placeMaster?.name ?? "",
            visit.placeMaster?.placeTagsRaw ?? "",
            visit.placeMaster?.address ?? "",
            visit.note,
            VisitUnitFields(rawValue: visit.unitFieldsRaw).ocrText,
        ].joined(separator: " ")
    }
}

private enum GoshuinPlaceKind {
    case shrine
    case temple
    case unknown
}

private struct GoshuinFilterBar: View {
    @Binding var selection: GoshuinVisitFilter
    let options: [GoshuinVisitFilter]

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(option.title)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(selection == option ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                selection == option
                                ? themePalette.globalTint
                                : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GoshuinTopHero: View {
    let category: RecordCategory
    let visits: [Visit]
    @Binding var selectedIndex: Int
    let onAdd: () -> Void

    @Environment(\.favorecoThemePalette) private var themePalette

    private var accent: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    var body: some View {
        VStack(spacing: 10) {
            if visits.isEmpty {
                heroCard(visit: nil)
            } else if visits.count == 1 {
                heroCard(visit: visits[0])
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        heroCard(visit: visit)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 196)

                HStack(spacing: 7) {
                    ForEach(visits.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? accent : Color.secondary.opacity(0.28))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(selectedIndex + 1)件目／全\(visits.count)件")
            }
        }
    }

    private func heroCard(visit: Visit?) -> some View {
        HStack(alignment: .center, spacing: 16) {
            goshuinImage(visit: visit)

            VStack(alignment: .leading, spacing: 8) {
                Text("最近いただいた御朱印")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(accent)

                Text(visit?.event?.title.isEmpty == false ? visit?.event?.title ?? "参拝先" : "御朱印を残す")
                    .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title3))
                    .lineLimit(2, reservesSpace: true)

                if let visit {
                    Text("\(FavorecoDateText.compactDate(visit.visitedAt)) ・ \(visit.venueNameSnapshot.isEmpty ? "場所未設定" : visit.venueNameSnapshot)")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("御朱印帳のサイズに合わせて、参拝の証を美しく残せます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onAdd) {
                    Label(visit == nil ? "最初の御朱印を追加" : "御朱印を追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .padding(14)
        .background {
            GoshuinWashiBackground(accent: accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 0.75)
        }
    }

    @ViewBuilder
    private func goshuinImage(visit: Visit?) -> some View {
        let sizeKey = visit.map { VisitUnitFields(rawValue: $0.unitFieldsRaw).goshuinBookSizeKey } ?? ""
        let size = GoshuinBookSize.option(for: sizeKey)
        let isWide = size.key == GoshuinBookSize.wide.key
        let imageWidth: CGFloat = isWide ? 132 : 104
        let imageHeight = imageWidth / CGFloat(size.aspectRatio)
        let photo = visit.flatMap { firstPhoto(in: $0) }

        ZStack(alignment: .bottomLeading) {
            if let photo {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .background(Color.white.opacity(0.72))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .frame(width: imageWidth, height: imageHeight)
                    .overlay {
                        Image(systemName: "seal")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.8))
                    }
            }

            if isWide {
                Text("見開き")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
    }
}

private struct GoshuinWashiBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.96, blue: 0.90),
                    accent.opacity(0.26),
                    Color(red: 0.93, green: 0.84, blue: 0.76),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                for index in 0..<90 {
                    let x = CGFloat((index * 37) % 100) / 100 * size.width
                    let y = CGFloat((index * 61) % 100) / 100 * size.height
                    let radius = CGFloat((index % 3) + 1) * 0.42
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.14))
                    )
                }
            }
        }
    }
}

private struct GoshuinStampTile: View {
    let visit: Visit
    let photo: PhotoBlob?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            stampImage
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                .font(FavorecoTypography.captionStrong)
                .lineLimit(1)
            Text(FavorecoDateText.compactDate(visit.visitedAt))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var stampImage: some View {
        let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let size = GoshuinBookSize.option(for: fields.goshuinBookSizeKey)
        if let photo {
            RepresentativePhotoImage(photo: photo, maxPixelSize: 360, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(size.aspectRatio), contentMode: .fit)
                .frame(minHeight: 120)
                .clipped()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .aspectRatio(CGFloat(size.aspectRatio), contentMode: .fit)
                .overlay {
                    Image(systemName: "seal")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct GoshuinBookSelection: Identifiable {
    let size: GoshuinBookSize
    let visits: [Visit]
    let coverPhoto: PhotoBlob?

    var id: String { size.key }
}

private struct GoshuinBookRow: View {
    let selection: GoshuinBookSelection

    var body: some View {
        HStack(spacing: 12) {
            if let coverPhoto = selection.coverPhoto {
                RepresentativePhotoImage(photo: coverPhoto, maxPixelSize: 240, contentMode: .fill)
                    .frame(width: 56, height: 56 / CGFloat(selection.size.aspectRatio))
                    .clipped()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 56, height: 56 / CGFloat(selection.size.aspectRatio))
                    .overlay { Image(systemName: "book.closed") }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(selection.size.name)
                    .font(FavorecoTypography.bodyStrong)
                Text("\(selection.visits.count)件 ・ \(selection.size.displaySize)")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoshuinBookGalleryView: View {
    let selection: GoshuinBookSelection
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(selection.visits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            GoshuinStampTile(visit: visit, photo: firstPhoto(in: visit))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selection.size.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
    }
}

private struct GoshuinMapItem: Identifiable {
    let id: UUID
    let title: String
    let coordinate: CLLocationCoordinate2D
}

private struct GoshuinMapPreview: View {
    let visits: [Visit]

    private var items: [GoshuinMapItem] {
        visits.compactMap { visit in
            let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
            let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
            let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
            guard latitude != 0 || longitude != 0 else { return nil }
            return GoshuinMapItem(
                id: visit.id,
                title: visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        }
    }

    var body: some View {
        Map(initialPosition: .region(Self.region(for: items))) {
            ForEach(items) { item in
                Marker(item.title, coordinate: item.coordinate)
            }
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if items.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.title2)
                            Text("場所を登録するとMAPにピンが立ちます")
                                .font(FavorecoTypography.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private static func region(for items: [GoshuinMapItem]) -> MKCoordinateRegion {
        guard !items.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
            )
        }

        let latitudes = items.map { $0.coordinate.latitude }
        let longitudes = items.map { $0.coordinate.longitude }
        let minLatitude = latitudes.min() ?? 36.2048
        let maxLatitude = latitudes.max() ?? 36.2048
        let minLongitude = longitudes.min() ?? 138.2529
        let maxLongitude = longitudes.max() ?? 138.2529
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.5, (maxLatitude - minLatitude) * 1.8),
                longitudeDelta: max(0.5, (maxLongitude - minLongitude) * 1.8)
            )
        )
    }
}

private struct GoshuinVisitedPlaceRow: View {
    let visit: Visit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                Text(placeText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(FavorecoDateText.compactDate(visit.visitedAt))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeText: String {
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty { return address }
        if !visit.venueNameSnapshot.isEmpty { return visit.venueNameSnapshot }
        return "場所未設定"
    }
}

private enum CategoryTopJapanPrefecture: String, CaseIterable {
    case hokkaido = "北海道"
    case aomori = "青森県"
    case iwate = "岩手県"
    case miyagi = "宮城県"
    case akita = "秋田県"
    case yamagata = "山形県"
    case fukushima = "福島県"
    case ibaraki = "茨城県"
    case tochigi = "栃木県"
    case gunma = "群馬県"
    case saitama = "埼玉県"
    case chiba = "千葉県"
    case tokyo = "東京都"
    case kanagawa = "神奈川県"
    case niigata = "新潟県"
    case toyama = "富山県"
    case ishikawa = "石川県"
    case fukui = "福井県"
    case yamanashi = "山梨県"
    case nagano = "長野県"
    case gifu = "岐阜県"
    case shizuoka = "静岡県"
    case aichi = "愛知県"
    case mie = "三重県"
    case shiga = "滋賀県"
    case kyoto = "京都府"
    case osaka = "大阪府"
    case hyogo = "兵庫県"
    case nara = "奈良県"
    case wakayama = "和歌山県"
    case tottori = "鳥取県"
    case shimane = "島根県"
    case okayama = "岡山県"
    case hiroshima = "広島県"
    case yamaguchi = "山口県"
    case tokushima = "徳島県"
    case kagawa = "香川県"
    case ehime = "愛媛県"
    case kochi = "高知県"
    case fukuoka = "福岡県"
    case saga = "佐賀県"
    case nagasaki = "長崎県"
    case kumamoto = "熊本県"
    case oita = "大分県"
    case miyazaki = "宮崎県"
    case kagoshima = "鹿児島県"
    case okinawa = "沖縄県"
}

private struct GoshuinPrefectureSearchView: View {
    @Binding var selectedPrefecture: String
    let availablePrefectures: [String]
    @Environment(\.dismiss) private var dismiss

    private var prefectures: [String] {
        let base = availablePrefectures.isEmpty ? CategoryTopJapanPrefecture.allCases.map(\.rawValue) : availablePrefectures
        return base.sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Button("すべての都道府県") {
                    selectedPrefecture = ""
                    dismiss()
                }
                ForEach(prefectures, id: \.self) { prefecture in
                    Button {
                        selectedPrefecture = prefecture
                        dismiss()
                    } label: {
                        HStack {
                            Text(prefecture)
                            Spacer()
                            if selectedPrefecture == prefecture {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("県で絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct GoshuinVisitedShareCard: View {
    let visits: [Visit]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Favoreco")
                .font(FavorecoTypography.latinDisplay(34, weight: .bold, relativeTo: .title))
            Text("行った神社・お寺リスト")
                .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title2))
            Text("\(visits.count)件の参拝記録")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(visits.prefix(12).enumerated()), id: \.element.id) { index, visit in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(red: 0.58, green: 0.18, blue: 0.22), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                                .font(FavorecoTypography.bodyStrong)
                                .lineLimit(1)
                            Text("\(FavorecoDateText.compactDate(visit.visitedAt)) ・ \(visit.venueNameSnapshot.isEmpty ? "場所未設定" : visit.venueNameSnapshot)")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer()
            Text("#Favoreco")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(Color(red: 0.58, green: 0.18, blue: 0.22))
        }
        .padding(28)
        .frame(width: 390, height: 760, alignment: .topLeading)
        .background(GoshuinWashiBackground(accent: Color(red: 0.58, green: 0.18, blue: 0.22)))
    }
}

private struct GoshuinActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CategoryVisitRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録")
                .font(FavorecoTypography.cardTitle)
                .lineLimit(2)
            HStack(spacing: 10) {
                Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar")
                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
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
            Image(systemName: icon)
                .font(.title3)
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
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self, Plan.self], inMemory: true)
}
