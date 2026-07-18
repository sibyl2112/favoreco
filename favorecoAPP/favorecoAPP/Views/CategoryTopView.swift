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
    @State private var isShowingGenrePicker = false
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
    @State private var libraryLayoutMode: CategoryLibraryLayoutMode

    init(category: RecordCategory) {
        self.category = category
        _selectedCategoryID = State(initialValue: category.id)
        _libraryLayoutMode = State(initialValue: CategoryLibraryLayoutMode.stored(for: category.templateKey))
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
                centeredTitle: activeCategory.name.isEmpty ? "ジャンル" : activeCategory.name,
                usesCompactBrand: true,
                brandGradient: activeCategory.templateKey == "theater" ? TheaterCategoryStyle.brandGradient : nil,
                headerForegroundColor: activeCategory.templateKey == "theater" ? TheaterCategoryStyle.ivory : nil,
                onLeadingTap: { dismiss() },
                onCenteredTitleTap: { isShowingGenrePicker = true }
            )
            .padding(.horizontal, 20)
            .padding(.top, -4)
            .padding(.bottom, 6)

            MainHeaderDivider(
                tint: themePalette.categoryColor(hex: activeCategory.colorHex)
            )

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear
                            .frame(height: 0)
                            .id(CategoryScrollAnchor.top)

                        GenreNavigationStrip(
                            categories: snapshot.visibleCategories,
                            selectedCategoryID: activeCategory.id,
                            onSelectAll: { dismiss() },
                            onSelectCategory: { selectedCategory in
                                switchCategory(to: selectedCategory)
                            }
                        )

                        VStack(alignment: .leading, spacing: 24) {
                            if activeCategory.templateKey == "theater" {
                                theaterHero(category: activeCategory, snapshot: snapshot)
                            } else if activeCategory.templateKey == "goshuin" {
                                goshuinHero(category: activeCategory, snapshot: snapshot)
                            } else if usesFeatureOverview(for: activeCategory) {
                                featureOverviewContent(category: activeCategory, snapshot: snapshot)
                            } else {
                                hero(
                                    category: activeCategory,
                                    snapshot: snapshot,
                                    recordTemplate: recordTemplate
                                )
                            }

                            GenreSwipeContainer(
                                canMoveBackward: neighboringCategory(from: activeCategory, offset: -1) != nil,
                                canMoveForward: neighboringCategory(from: activeCategory, offset: 1) != nil,
                                onMove: { offset in
                                    guard let destination = neighboringCategory(from: activeCategory, offset: offset) else { return }
                                    switchCategory(to: destination)
                                }
                            ) {
                                VStack(alignment: .leading, spacing: 24) {
                                    if activeCategory.templateKey == "theater" {
                                        theaterStats(snapshot: snapshot)
                                        categoryTicketProgressSection(category: activeCategory)
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
                                    } else if activeCategory.templateKey == "goshuin" {
                                        goshuinContent(category: activeCategory, snapshot: snapshot)
                                            .id(CategoryScrollAnchor.events)
                                    } else {
                                        if !usesFeatureOverview(for: activeCategory) {
                                            stats(snapshot: snapshot)
                                        }
                                        categoryTicketProgressSection(category: activeCategory)
                                        categoryLibrarySection(
                                            category: activeCategory,
                                            snapshot: snapshot,
                                            recordTemplate: recordTemplate
                                        )
                                            .id(CategoryScrollAnchor.events)
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
                            }
                        }
                        .id(activeCategory.id)
                        .transition(categoryPageTransition)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(categoryBackground(category: activeCategory))
        .environment(\.colorScheme, activeCategory.templateKey == "theater" ? .dark : colorScheme)
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
        .confirmationDialog("ジャンルを選ぶ", isPresented: $isShowingGenrePicker, titleVisibility: .visible) {
            ForEach(snapshot.visibleCategories) { selectableCategory in
                Button(selectableCategory.name.isEmpty ? "無題" : selectableCategory.name) {
                    switchCategory(to: selectableCategory)
                }
            }
            Button("キャンセル", role: .cancel) {}
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
                    .foregroundStyle(themePalette.categoryColor(hex: category.colorHex))
                    .frame(width: 44, height: 44)
                    .background(themePalette.categoryColor(hex: category.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
            .tint(themePalette.categoryColor(hex: category.colorHex))
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
                .stroke(TheaterCategoryStyle.gold.opacity(0.52), lineWidth: 1)
        }
    }

    private func theaterStats(snapshot: CategoryTopSnapshot) -> some View {
        CategoryFeatureMetricsGrid(
            metrics: [
                MiniStatisticsItem(title: "作品・公演", value: "\(snapshot.eventCount)", unit: "", icon: "theatermasks"),
                MiniStatisticsItem(title: "観劇済み", value: "\(snapshot.visitCount)", unit: "", icon: "ticket"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "", icon: "bookmark"),
            ],
            tint: TheaterCategoryStyle.gold,
            backgroundColor: TheaterCategoryStyle.tileBackground,
            primaryTextColor: TheaterCategoryStyle.ivory,
            secondaryTextColor: TheaterCategoryStyle.ivory.opacity(0.62),
            borderColor: TheaterCategoryStyle.gold.opacity(0.42),
            dividerColor: TheaterCategoryStyle.gold.opacity(0.34)
        )
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

    private func usesFeatureOverview(for category: RecordCategory) -> Bool {
        ["movie", "book", "outing_facility"].contains(category.templateKey)
    }

    private func featureOverviewContent(category: RecordCategory, snapshot: CategoryTopSnapshot) -> some View {
        let items = featureCarouselItems(category: category, visits: snapshot.visits)
        let metrics = featureMetrics(category: category, snapshot: snapshot)

        return VStack(alignment: .leading, spacing: 14) {
            CategoryFeatureCarousel(
                title: featureCarouselTitle(for: category),
                emptyMessage: featureEmptyMessage(for: category),
                items: items,
                selectedIndex: $selectedFeatureCarouselIndex,
                tint: themePalette.categoryColor(hex: category.colorHex),
                fallbackIcon: category.iconSymbol,
                onAdd: { isShowingAddExperience = true }
            )

            if category.templateKey == "movie" {
                MiniStatisticsBlock(
                    items: metrics,
                    tint: themePalette.categoryColor(hex: category.colorHex),
                    format: .fourColumns
                )
            } else {
                CategoryFeatureMetricsGrid(metrics: metrics, tint: themePalette.categoryColor(hex: category.colorHex))
            }
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

    private func featureCarouselTitle(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "最近観た映画・これから観る予定"
        case "book": return "最近読んだ本・これから読む予定"
        case "outing_facility": return "最近行った場所・これから行く予定"
        default: return "最近の記録・これからの予定"
        }
    }

    private func featureEmptyMessage(for category: RecordCategory) -> String {
        switch category.templateKey {
        case "movie": return "映画を観た記録や鑑賞予定を入れると、ここに並びます。"
        case "book": return "読んだ本やこれから読む本を入れると、ここに並びます。"
        case "outing_facility": return "来園記録やこれから行く予定を入れると、ここに並びます。"
        default: return "記録や予定を入れると、ここに並びます。"
        }
    }

    private func featureCarouselItems(category: RecordCategory, visits: [Visit]) -> [CategoryFeatureItem] {
        let now = Date()
        let upcomingPlans = allPlans
            .filter { plan in
                !plan.isArchived && plan.startsAt >= now && plan.category?.id == category.id
            }
            .sorted { $0.startsAt < $1.startsAt }
            .prefix(5)
            .map(CategoryFeatureItem.plan)

        let linkedVisitIDs = Set(upcomingPlans.compactMap { item -> UUID? in
            if case .plan(let plan) = item {
                return plan.visit?.id
            }
            return nil
        })

        let recentVisits = visits
            .filter { !linkedVisitIDs.contains($0.id) }
            .sorted { $0.visitedAt > $1.visitedAt }
            .prefix(8)
            .map(CategoryFeatureItem.visit)

        return Array(upcomingPlans + recentVisits).prefix(10).map { $0 }
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
        case "outing_facility":
            let repeatCount = repeatVisitCount(in: snapshot.visits)
            let encounteredCount = encounteredItemCount(in: snapshot.visits)
            return [
                MiniStatisticsItem(title: "総来園数", value: "\(snapshot.visitCount)", unit: "回", icon: "building.columns"),
                MiniStatisticsItem(title: "年間来園", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "出会った数", value: encounteredCount == 0 ? "-" : "\(encounteredCount)", unit: "種", icon: "pawprint"),
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
        GoshuinTopHero(
            category: category,
            visit: snapshot.visits.first,
            photo: snapshot.visits.first.flatMap { firstPhoto(in: $0) },
            onAdd: { isShowingAddExperience = true }
        )
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
        JapanPrefecture.allCases
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
        let items = categoryLibraryItems(category: category, snapshot: snapshot)
        let tint = category.templateKey == "theater"
            ? TheaterCategoryStyle.gold
            : themePalette.categoryColor(hex: category.colorHex)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(recordTemplate.targetSectionTitle)
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(category.templateKey == "theater" ? TheaterCategoryStyle.ivory : Color.primary)

                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(category.templateKey == "theater" ? TheaterCategoryStyle.ivory.opacity(0.62) : Color.secondary)

                Spacer(minLength: 4)

                CategoryLibraryLayoutPicker(
                    selection: $libraryLayoutMode,
                    tint: tint,
                    onSelect: { mode in
                        mode.store(for: category.templateKey)
                    }
                )
            }

            if items.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "\(recordTemplate.targetSectionTitle)はまだありません",
                    message: "最初の記録や予定を追加すると、ここに並びます。",
                    tint: tint
                )
            } else {
                switch libraryLayoutMode {
                case .gallery:
                    CategoryLibraryGallery(items: items, category: category, tint: tint)
                case .compact:
                    CategoryLibraryCompactGrid(items: items, category: category, tint: tint)
                case .banner:
                    CategoryLibraryBannerList(items: items, category: category, tint: tint)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: libraryLayoutMode)
    }

    @ViewBuilder
    private func categoryTicketProgressSection(category: RecordCategory) -> some View {
        let items = categoryTicketProgressItems(category: category)
        if !items.isEmpty {
            CategoryTicketProgressSection(
                items: items,
                category: category,
                tint: themePalette.categoryColor(hex: category.colorHex)
            )
            .id("ticket-progress-\(category.id.uuidString)")
        }
    }

    private func categoryTicketProgressItems(category: RecordCategory) -> [CategoryTicketProgressItem] {
        let attempts = allPlans
            .filter { plan in
                !plan.isArchived
                    && (plan.category ?? plan.event?.category)?.id == category.id
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

        return TicketAttemptPresentationOrder.sorted(
            attempts.map(\.attempt)
        ).compactMap { sortedAttempt in
            attempts.first(where: { $0.attempt.id == sortedAttempt.id })
        }
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

        withAnimation(categorySwitchAnimation) {
            selectedCategoryID = destination.id
            libraryLayoutMode = CategoryLibraryLayoutMode.stored(for: destination.templateKey)
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

        if usesFeatureOverview(for: category) {
            for item in featureCarouselItems(category: category, visits: snapshot.visits).prefix(2) {
                guard let photo = item.visit.flatMap({ firstPhoto(in: $0) })
                    ?? item.event.flatMap({ EventRepresentativePhotoResolver.photo(for: $0) }) else { continue }
                let maxPixelSize: CGFloat = 520
                append(
                    photo,
                    maxPixelSize: maxPixelSize,
                    cacheKey: "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
                )
            }
        } else if category.templateKey == "goshuin" {
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

private struct GenreSwipeContainer<Content: View>: View {
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
                DirectionalHorizontalPanInstaller(
                    onBegan: {
                        suppressesContentTap = true
                    },
                    onChanged: { translation in
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

            if let touchedView = installedView.hitTest(location, with: nil),
               isInsideNestedHorizontalScrollView(touchedView, outerScrollView: installedView) {
                return false
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

private struct CategoryTicketProgressItem: Identifiable {
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
}

private struct CategoryTicketProgressSection: View {
    let items: [CategoryTicketProgressItem]
    let category: RecordCategory
    let tint: Color

    @State private var selectedAttemptID: UUID?

    init(items: [CategoryTicketProgressItem], category: RecordCategory, tint: Color) {
        self.items = items
        self.category = category
        self.tint = tint
        _selectedAttemptID = State(initialValue: items.first?.id)
    }

    private var selectedItem: CategoryTicketProgressItem? {
        items.first(where: { $0.id == selectedAttemptID }) ?? items.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("チケット進捗")
                    .font(FavorecoTypography.sectionTitle)
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
                                Text(item.selectorTitle)
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
                            .accessibilityLabel("\(item.selectorTitle)のチケット進捗")
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
                        isTheater: category.templateKey == "theater"
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
        category.templateKey == "theater" ? TheaterCategoryStyle.ivory : Color.primary
    }
}

private struct CategoryTicketProgressCard: View {
    let item: CategoryTicketProgressItem
    let tint: Color
    let isTheater: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(item.title)
                .font(FavorecoTypography.cardTitle)
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(item.metadataChips, id: \.self) { chip in
                        Text(chip)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
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
        .padding(11)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isTheater ? 0.48 : 0.20), lineWidth: 1)
        }
    }

    private var cardBackground: Color {
        isTheater ? TheaterCategoryStyle.tileBackground : Color(.secondarySystemGroupedBackground)
    }

    private var primaryTextColor: Color {
        isTheater ? TheaterCategoryStyle.ivory : Color.primary
    }

    private var secondaryTextColor: Color {
        isTheater ? TheaterCategoryStyle.ivory.opacity(0.68) : Color.secondary
    }
}

private struct TicketProgressTimelineView: View {
    let stages: [TicketProgressStage]
    let currentIndex: Int
    let tint: Color
    let nodeBackground: Color
    let secondaryTextColor: Color

    private let nodeDiameter: CGFloat = 38

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

                        VStack(spacing: 4) {
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
                                .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                        .frame(width: geometry.size.width)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 58)
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
                    .padding(4)
            } else if state == .future {
                Circle()
                    .stroke(Color.secondary.opacity(0.52), lineWidth: 1.5)
            }

            Text(title)
                .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
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

    var dateText: String {
        if let nextPlan {
            return FavorecoDateText.compactDate(nextPlan.startsAt)
        }
        if let latestVisit {
            return FavorecoDateText.compactDate(latestVisit.visitedAt)
        }
        return "—"
    }

    var venueText: String {
        if let nextPlan, !nextPlan.venueNameSnapshot.isEmpty {
            return nextPlan.venueNameSnapshot
        }
        return latestVisit?.venueNameSnapshot ?? ""
    }

    var ticketStatusNames: [String] {
        var seen = Set<String>()
        return ticketAttempts.compactMap { attempt in
            let name = TicketStatusDefinition.name(for: attempt.statusKey)
            return seen.insert(name).inserted ? name : nil
        }
    }
}

private struct CategoryLibraryLayoutPicker: View {
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
                .stroke(tint.opacity(0.24), lineWidth: 1)
        }
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
            ForEach(items.prefix(30)) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        CategoryLibraryArtwork(item: item, category: category)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(item.dateText)
                                .foregroundStyle(item.nextPlan == nil ? Color.secondary : Color.red)
                            Spacer(minLength: 1)
                            Label(item.ratingText, systemImage: item.ratingText == "—" ? "star" : "star.fill")
                                .foregroundStyle(item.ratingText == "—" ? Color.secondary : Color.yellow)
                        }
                        .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 7)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(galleryCardBackground)
                    .overlay {
                        Rectangle()
                            .stroke(tint.opacity(0.18), lineWidth: 0.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title)、評価\(item.ratingText)、\(item.dateText)")
            }
        }
    }

    private var galleryCardBackground: Color {
        category.templateKey == "theater" ? TheaterCategoryStyle.tileBackground : Color(.secondarySystemBackground)
    }
}

private struct CategoryLibraryCompactGrid: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 2
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items.prefix(20)) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        CategoryLibraryArtwork(item: item, category: category)
                            .frame(width: 58)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(FavorecoTypography.jpSerif(13, weight: .bold, relativeTo: .caption))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(item.nextPlan == nil ? item.dateText : "予定 \(item.dateText)")
                                .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(item.nextPlan == nil ? Color.secondary : Color.red)
                                .lineLimit(1)

                            Label(item.ratingText, systemImage: item.ratingText == "—" ? "star" : "star.fill")
                                .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(item.ratingText == "—" ? Color.secondary : Color.yellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardBackground: Color {
        category.templateKey == "theater" ? TheaterCategoryStyle.tileBackground : Color(.secondarySystemGroupedBackground)
    }
}

private struct CategoryLibraryBannerList: View {
    let items: [CategoryLibraryItem]
    let category: RecordCategory
    let tint: Color

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(items.prefix(30)) { item in
                NavigationLink {
                    EventDetailView(event: item.event)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        CategoryLibraryArtwork(item: item, category: category, aspectRatioOverride: 1)
                            .frame(width: 82, height: 82)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(FavorecoTypography.cardTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                if item.dateText != "—" {
                                    Label(item.dateText, systemImage: "calendar")
                                        .foregroundStyle(item.nextPlan == nil ? Color.secondary : Color.red)
                                }
                                if !item.venueText.isEmpty {
                                    Label(item.venueText, systemImage: "mappin.and.ellipse")
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .font(FavorecoTypography.caption)

                            if !item.ticketStatusNames.isEmpty {
                                HStack(spacing: 5) {
                                    ForEach(Array(item.ticketStatusNames.prefix(3)), id: \.self) { name in
                                        Text(name)
                                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                                            .foregroundStyle(tint)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(tint.opacity(0.12), in: Capsule())
                                    }
                                }
                            } else if item.nextPlan != nil {
                                Text("予定")
                                    .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                                    .foregroundStyle(tint)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(tint.opacity(0.12), in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardBackground: Color {
        category.templateKey == "theater" ? TheaterCategoryStyle.tileBackground : Color(.secondarySystemGroupedBackground)
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
                    .stroke(categoryTint.opacity(0.28), lineWidth: 1)
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
                .stroke(TheaterCategoryStyle.gold.opacity(0.62), lineWidth: 1)
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
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 1)
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
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 1)
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
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 1)
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

    var id: String {
        switch self {
        case .plan(let plan): return "plan-\(plan.id.uuidString)"
        case .visit(let visit): return "visit-\(visit.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .plan(let plan):
            if !plan.title.isEmpty { return plan.title }
            return plan.event?.title ?? "予定"
        case .visit(let visit):
            return visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
        }
    }

    var subtitle: String {
        switch self {
        case .plan(let plan):
            return plan.subtitle.isEmpty ? plan.event?.seriesName ?? "" : plan.subtitle
        case .visit(let visit):
            return visit.event?.seriesName ?? ""
        }
    }

    var badgeText: String {
        switch self {
        case .plan: return "予定"
        case .visit: return "記録済み"
        }
    }

    var dateText: String {
        switch self {
        case .plan(let plan): return FavorecoDateText.compactDate(plan.startsAt)
        case .visit(let visit): return FavorecoDateText.compactDate(visit.visitedAt)
        }
    }

    var placeText: String {
        switch self {
        case .plan(let plan):
            return plan.venueNameSnapshot.isEmpty ? plan.placeMaster?.name ?? "" : plan.venueNameSnapshot
        case .visit(let visit):
            return visit.venueNameSnapshot.isEmpty ? visit.placeMaster?.name ?? "" : visit.venueNameSnapshot
        }
    }

    var detailText: String {
        switch self {
        case .plan(let plan):
            return plan.memo.isEmpty ? plan.organizerNameSnapshot : plan.memo
        case .visit(let visit):
            if visit.overallRating > 0 {
                return String(format: "評価 %.1f", visit.overallRating)
            }
            return visit.note
        }
    }

    var event: ExperienceEvent? {
        switch self {
        case .plan(let plan): return plan.event
        case .visit(let visit): return visit.event
        }
    }

    var visit: Visit? {
        switch self {
        case .plan(let plan): return plan.visit
        case .visit(let visit): return visit
        }
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
                .frame(height: 206)

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
            NavigationLink {
                PlanDetailView(plan: plan)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon)
            }
            .buttonStyle(.plain)
        case .visit(let visit):
            NavigationLink {
                ExperienceDetailView(visit: visit)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CategoryFeatureCard: View {
    let item: CategoryFeatureItem
    let tint: Color
    let fallbackIcon: String

    var body: some View {
        CategoryFeatureHeroLayout(posterAspectRatio: posterAspectRatio) {
            CategoryFeaturePoster(
                item: item,
                fallbackIcon: fallbackIcon,
                tint: tint
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.badgeText)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)

                Text(item.title)
                    .font(FavorecoTypography.jpSerif(18.5, weight: .bold, relativeTo: .headline))
                    .lineLimit(2, reservesSpace: true)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Label(item.dateText, systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

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

                Spacer(minLength: 0)

                Label(item.badgeText == "予定" ? "予定を見る" : "記録を見る", systemImage: "pencil")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .overlay {
                        Capsule()
                            .stroke(tint.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var posterAspectRatio: CGFloat {
        if let event = item.event {
            return CGFloat(EyecatchAspectRatio.resolved(for: event).value)
        }
        return 0.7
    }
}

private struct CategoryFeatureHeroLayout: Layout {
    let posterAspectRatio: CGFloat
    private let posterFraction: CGFloat = 0.36
    private let maximumPosterWidth: CGFloat = 122
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
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
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
                .stroke(borderColor ?? tint.opacity(0.16), lineWidth: 1)
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
    let visit: Visit?
    let photo: PhotoBlob?
    let onAdd: () -> Void

    @Environment(\.favorecoThemePalette) private var themePalette

    private var accent: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            goshuinImage

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
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var goshuinImage: some View {
        let sizeKey = visit.map { VisitUnitFields(rawValue: $0.unitFieldsRaw).goshuinBookSizeKey } ?? ""
        let size = GoshuinBookSize.option(for: sizeKey)
        let isWide = size.key == GoshuinBookSize.wide.key
        let imageWidth: CGFloat = isWide ? 132 : 104
        let imageHeight = imageWidth / CGFloat(size.aspectRatio)

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

private enum JapanPrefecture: String, CaseIterable {
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
        let base = availablePrefectures.isEmpty ? JapanPrefecture.allCases.map(\.rawValue) : availablePrefectures
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
