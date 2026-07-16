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
    private enum GenreDragAxis {
        case horizontal
        case vertical
    }

    let category: RecordCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var lowerContentDragOffset: CGFloat = 0
    @State private var genreDragAxis: GenreDragAxis?
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

    init(category: RecordCategory) {
        self.category = category
        _selectedCategoryID = State(initialValue: category.id)
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
                onLeadingTap: { dismiss() },
                onCenteredTitleTap: { isShowingGenrePicker = true }
            )
            .padding(.horizontal, 20)
            .padding(.top, -4)
            .padding(.bottom, 6)

            MainHeaderDivider()

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
                            if activeCategory.templateKey != "goshuin" && !usesFeatureOverview(for: activeCategory) {
                                hero(
                                    category: activeCategory,
                                    snapshot: snapshot,
                                    recordTemplate: recordTemplate
                                )
                            }

                            VStack(alignment: .leading, spacing: 24) {
                                if activeCategory.templateKey == "goshuin" {
                                    goshuinContent(category: activeCategory, snapshot: snapshot)
                                        .id(CategoryScrollAnchor.events)
                                } else {
                                    if usesFeatureOverview(for: activeCategory) {
                                        featureOverviewContent(category: activeCategory, snapshot: snapshot)
                                    } else {
                                        stats(snapshot: snapshot)
                                    }
                                    eventSection(snapshot: snapshot, recordTemplate: recordTemplate)
                                        .id(CategoryScrollAnchor.events)
                                    recentVisits(category: activeCategory, snapshot: snapshot)
                                        .id(CategoryScrollAnchor.recentVisits)
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
                            .contentShape(Rectangle())
                            .offset(x: lowerContentDragOffset)
                            .simultaneousGesture(lowerGenreSwipeGesture)
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
        .animation(.easeInOut(duration: 0.32), value: activeCategory.id)
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

            CategoryFeatureMetricsGrid(metrics: metrics, tint: themePalette.categoryColor(hex: category.colorHex))
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

    private func featureMetrics(category: RecordCategory, snapshot: CategoryTopSnapshot) -> [CategoryFeatureMetric] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let yearVisits = snapshot.visits.filter { calendar.component(.year, from: $0.visitedAt) == currentYear }
        let ratedYearVisits = yearVisits.filter { $0.overallRating > 0 }
        let averageText: String = {
            guard !ratedYearVisits.isEmpty else { return "-" }
            let average = ratedYearVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedYearVisits.count)
            return String(format: "%.1f", average)
        }()

        switch category.templateKey {
        case "movie":
            let japaneseCount = snapshot.events.filter { featureText(for: $0.event).contains("邦画") || $0.event.subTypeKey.contains("japanese") }.count
            let foreignCount = snapshot.events.filter { featureText(for: $0.event).contains("洋画") || $0.event.subTypeKey.contains("foreign") }.count
            return [
                CategoryFeatureMetric(title: "トータル本数", value: "\(snapshot.visitCount)", unit: "本", icon: "movieclapper"),
                CategoryFeatureMetric(title: "年間本数", value: "\(yearVisits.count)", unit: "本", icon: "calendar"),
                CategoryFeatureMetric(title: "年間評価", value: averageText, unit: "", icon: "star"),
                CategoryFeatureMetric(title: "邦画 / 洋画", value: japaneseCount + foreignCount == 0 ? "-" : "\(japaneseCount) / \(foreignCount)", unit: "本", icon: "globe.asia.australia"),
            ]
        case "book":
            let favoriteCount = snapshot.visits.filter { $0.overallRating >= 4.5 }.count
            return [
                CategoryFeatureMetric(title: "トータル冊数", value: "\(snapshot.eventCount)", unit: "冊", icon: "books.vertical"),
                CategoryFeatureMetric(title: "年間冊数", value: "\(yearVisits.count)", unit: "冊", icon: "calendar"),
                CategoryFeatureMetric(title: "年間評価", value: averageText, unit: "", icon: "star"),
                CategoryFeatureMetric(title: "お気に入り", value: "\(favoriteCount)", unit: "冊", icon: "bookmark"),
            ]
        case "outing_facility":
            let repeatCount = repeatVisitCount(in: snapshot.visits)
            let encounteredCount = encounteredItemCount(in: snapshot.visits)
            return [
                CategoryFeatureMetric(title: "トータル来園", value: "\(snapshot.visitCount)", unit: "回", icon: "building.columns"),
                CategoryFeatureMetric(title: "年間来園", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                CategoryFeatureMetric(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                CategoryFeatureMetric(title: "出会った数", value: encounteredCount == 0 ? "-" : "\(encounteredCount)", unit: "種", icon: "pawprint"),
            ]
        default:
            return [
                CategoryFeatureMetric(title: "対象", value: "\(snapshot.eventCount)", unit: "", icon: "rectangle.stack"),
                CategoryFeatureMetric(title: "記録", value: "\(snapshot.visitCount)", unit: "", icon: "sparkles.rectangle.stack"),
                CategoryFeatureMetric(title: "年間", value: "\(yearVisits.count)", unit: "", icon: "calendar"),
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
            GoshuinTopHero(
                category: category,
                visit: snapshot.visits.first,
                photo: snapshot.visits.first.flatMap { firstPhoto(in: $0) },
                onAdd: { isShowingAddExperience = true }
            )

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
        HStack(spacing: 12) {
            StatTile(title: "対象", value: "\(snapshot.eventCount)")
            StatTile(title: "体験済み", value: "\(snapshot.visitCount)")
            StatTile(title: "気になる", value: "\(snapshot.interestedEventCount)")
        }
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
    }

    private var currentCategory: RecordCategory {
        visibleCategories.first(where: { $0.id == selectedCategoryID }) ?? category
    }

    private var visibleCategories: [RecordCategory] {
        allCategories.filter { !$0.isArchived }
    }

    private var lowerGenreSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if genreDragAxis == nil {
                    guard max(abs(horizontal), abs(vertical)) >= 12 else { return }
                    genreDragAxis = abs(horizontal) > abs(vertical) * 1.2 ? .horizontal : .vertical
                }

                guard genreDragAxis == .horizontal else { return }
                guard !isSystemEdgeDrag(startX: value.startLocation.x) else { return }

                let direction = horizontal < 0 ? 1 : -1
                let hasDestination = neighboringCategory(from: currentCategory, offset: direction) != nil
                lowerContentDragOffset = hasDestination ? horizontal : horizontal * 0.18
            }
            .onEnded { value in
                defer {
                    genreDragAxis = nil
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        lowerContentDragOffset = 0
                    }
                }

                guard genreDragAxis == .horizontal else { return }
                guard !isSystemEdgeDrag(startX: value.startLocation.x) else { return }

                let projected = value.predictedEndTranslation.width
                let translation = value.translation.width
                let shouldMove = abs(translation) >= 72 || abs(projected) >= 140
                guard shouldMove else { return }

                let offset = translation < 0 ? 1 : -1
                guard let destination = neighboringCategory(from: currentCategory, offset: offset) else { return }
                switchCategory(to: destination)
            }
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

    private func switchCategory(to destination: RecordCategory) {
        guard destination.id != currentCategory.id else { return }
        let currentIndex = visibleCategories.firstIndex(where: { $0.id == currentCategory.id }) ?? 0
        let destinationIndex = visibleCategories.firstIndex(where: { $0.id == destination.id }) ?? currentIndex
        transitionMovesForward = destinationIndex > currentIndex
        homeSelectedCategoryTemplateKey = destination.templateKey

        withAnimation(.easeInOut(duration: 0.32)) {
            selectedCategoryID = destination.id
            lowerContentDragOffset = 0
        }
    }

    private func neighboringCategory(from category: RecordCategory, offset: Int) -> RecordCategory? {
        guard let index = visibleCategories.firstIndex(where: { $0.id == category.id }) else { return nil }
        let destinationIndex = index + offset
        guard visibleCategories.indices.contains(destinationIndex) else { return nil }
        return visibleCategories[destinationIndex]
    }

    private func isSystemEdgeDrag(startX: CGFloat) -> Bool {
        let contentWidth = max(0, UIScreen.main.bounds.width - 40)
        return startX < 24 || startX > contentWidth - 24
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

private enum CategoryScrollAnchor {
    static let top = "category-top"
    static let events = "category-events"
    static let recentVisits = "category-recent-visits"
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
                        RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 220, contentMode: .fit)
                            .frame(width: 68, height: representativeImageHeight)
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if let data = event.eyecatchData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: representativeImageHeight)
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
        let ratio = EyecatchAspectRatio.recommended(for: event.category).value
        return min(96, max(68, 68 / CGFloat(ratio)))
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FavorecoTypography.latinDisplay(24, weight: .bold, relativeTo: .title3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct CategoryFeatureMetric: Identifiable {
    let title: String
    let value: String
    let unit: String
    let icon: String

    var id: String { "\(title)-\(value)-\(unit)" }
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
                    .font(FavorecoTypography.jpSerif(23, weight: .bold, relativeTo: .title3))
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
            return CGFloat(EyecatchAspectRatio.recommended(for: event.category).value)
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
                    RepresentativePhotoImage(photo: photo, maxPixelSize: 520, contentMode: .fit)
                } else if let data = item.event?.eyecatchData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
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
    let metrics: [CategoryFeatureMetric]
    let tint: Color

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(metrics) { metric in
                VStack(spacing: 6) {
                    Image(systemName: metric.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(metric.title)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(metric.value)
                            .font(FavorecoTypography.latinDisplay(24, weight: .bold, relativeTo: .title3))
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
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

        ZStack(alignment: .bottomLeading) {
            if let photo {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fit)
                    .frame(width: isWide ? 132 : 104, height: 140)
                    .background(Color.white.opacity(0.72))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 104, height: 140)
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
            RepresentativePhotoImage(photo: photo, maxPixelSize: 360, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(size.aspectRatio), contentMode: .fit)
                .frame(minHeight: 120)
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
                RepresentativePhotoImage(photo: coverPhoto, maxPixelSize: 240, contentMode: .fit)
                    .frame(width: 56, height: 74)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 56, height: 74)
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
