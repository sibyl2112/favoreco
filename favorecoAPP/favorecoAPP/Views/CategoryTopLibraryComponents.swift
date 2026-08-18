//
//  CategoryTopLibraryComponents.swift
//  favorecoAPP
//
//  Extracted from CategoryTopView to keep shared library presentation isolated.
//

import SwiftUI
import UIKit

enum CategoryScrollAnchor {
    static let top = "category-top"
    static let events = "category-events"
    static let recentVisits = "category-recent-visits"
}

struct CategoryFacilityLibrarySnapshot {
    let places: [PlaceMaster]
    private let plansByPlaceID: [UUID: [Plan]]
    private let visitsByPlaceID: [UUID: [Visit]]

    init(
        places: [PlaceMaster],
        plansByPlaceID: [UUID: [Plan]],
        visitsByPlaceID: [UUID: [Visit]]
    ) {
        self.places = places
        self.plansByPlaceID = plansByPlaceID
        self.visitsByPlaceID = visitsByPlaceID
    }

    static var empty: CategoryFacilityLibrarySnapshot {
        CategoryFacilityLibrarySnapshot(
            places: [],
            plansByPlaceID: [:],
            visitsByPlaceID: [:]
        )
    }

    func plans(for place: PlaceMaster) -> [Plan] {
        plansByPlaceID[place.id] ?? []
    }

    func visits(for place: PlaceMaster) -> [Visit] {
        visitsByPlaceID[place.id] ?? []
    }
}

enum CategoryFacilityLibraryBuilder {
    static func make(
        category: RecordCategory,
        allPlans: [Plan],
        allVisits: [Visit],
        allPlaceMasters: [PlaceMaster]
    ) -> CategoryFacilityLibrarySnapshot {
        var plansByPlaceID: [UUID: [Plan]] = [:]
        for plan in allPlans where !plan.isArchived {
            let planCategoryID = plan.category?.id ?? plan.event?.category?.id
            guard planCategoryID == category.id,
                  let placeID = plan.placeMaster?.id else {
                continue
            }
            plansByPlaceID[placeID, default: []].append(plan)
        }

        var visitsByPlaceID: [UUID: [Visit]] = [:]
        for visit in allVisits {
            guard visit.event?.category?.id == category.id,
                  let placeID = visit.placeMaster?.id else {
                continue
            }
            visitsByPlaceID[placeID, default: []].append(visit)
        }

        let relatedPlaceIDs = Set(plansByPlaceID.keys).union(visitsByPlaceID.keys)
        let scope: PublicPlaceCatalogScope? = switch category.templateKey {
        case "museum": .museum
        case "theme_park": .themePark
        case "nature_living", "outing_facility": .natureLiving
        default: nil
        }
        let places = allPlaceMasters
            .filter { !$0.isArchived }
            .filter { relatedPlaceIDs.contains($0.id) || scope?.includes($0) == true }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return CategoryFacilityLibrarySnapshot(
            places: places,
            plansByPlaceID: plansByPlaceID,
            visitsByPlaceID: visitsByPlaceID
        )
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

struct ScreenWorkFilterBar: View {
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

struct CategoryLibrarySectionChrome: View {
    let category: RecordCategory
    let targetSectionTitle: String
    let itemCount: Int
    let tint: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    @Binding var selectedLayout: CategoryLibraryLayoutMode

    private var layoutModes: [CategoryLibraryLayoutMode] {
        if CategoryTopLibraryPolicy.isPlaceExperience(templateKey: category.templateKey) {
            return [.compact, .banner]
        }
        if category.templateKey == "movie" {
            return [.gallery, .banner]
        }
        return CategoryLibraryLayoutMode.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    let title = CategoryTopVocabulary.librarySectionTitle(
                        templateKey: category.templateKey,
                        fallback: targetSectionTitle
                    )
                    if let japaneseTitle = CategoryTopVocabulary.sectionJapaneseTitle(
                        englishTitle: title,
                        templateKey: category.templateKey
                    ) {
                        LayeredCategorySectionTitle(
                            englishTitle: title,
                            japaneseTitle: japaneseTitle,
                            foregroundColor: primaryTextColor
                        )
                    } else {
                        Text(title)
                            .font(FavorecoTypography.sectionTitle)
                            .foregroundStyle(primaryTextColor)
                    }

                    Text("\(itemCount)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer(minLength: 4)

                if category.templateKey != "live" {
                    CategoryLibraryLayoutPicker(
                        selection: $selectedLayout,
                        tint: tint,
                        modes: layoutModes,
                        onSelect: { _ in }
                    )
                }
            }

            if itemCount == 0 {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "\(targetSectionTitle)はまだありません",
                    message: "最初の記録や予定を追加すると、ここに並びます。",
                    tint: tint
                )
            }
        }
    }
}

struct CategoryFacilityLibraryContent: View {
    let category: RecordCategory
    let library: CategoryFacilityLibrarySnapshot
    let tint: Color
    let layout: CategoryLibraryLayoutMode
    let onOpen: (PlaceMaster) -> Void

    @ViewBuilder
    var body: some View {
        if layout == .compact {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(library.places) { place in
                    PlaceMasterFacilityGridCard(
                        place: place,
                        category: category,
                        plans: library.plans(for: place),
                        visits: library.visits(for: place),
                        tint: tint,
                        onOpen: { onOpen(place) }
                    )
                }
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(library.places) { place in
                    Button {
                        onOpen(place)
                    } label: {
                        PlaceMasterFacilityRow(
                            place: place,
                            category: category,
                            plans: library.plans(for: place),
                            visits: library.visits(for: place),
                            tint: tint
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CategoryFacilityLibrarySection: View {
    let category: RecordCategory
    let library: CategoryFacilityLibrarySnapshot
    let tint: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    @Binding var selectedLayout: CategoryLibraryLayoutMode
    let onOpen: (PlaceMaster) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                LayeredCategorySectionTitle(
                    englishTitle: category.templateKey == "museum" ? "Museums" : "Places",
                    japaneseTitle: "施設情報",
                    foregroundColor: primaryTextColor
                )

                Text("\(library.places.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer(minLength: 4)

            CategoryLibraryLayoutPicker(
                selection: $selectedLayout,
                tint: tint,
                modes: [.compact, .banner],
                onSelect: { _ in }
            )
        }

        if library.places.isEmpty {
            EmptyStateMessage(
                icon: "building.columns",
                title: "美術館・博物館はまだありません",
                message: "施設を登録すると、予定や鑑賞記録を同じ館へまとめられます。",
                tint: tint
            )
        } else {
            CategoryFacilityLibraryContent(
                category: category,
                library: library,
                tint: tint,
                layout: selectedLayout,
                onOpen: onOpen
            )
        }
    }
}

struct PlaceExperienceLogSection: View {
    let category: RecordCategory
    let visits: [Visit]
    let events: [ExperienceEvent]
    let tint: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let onSelectEvent: (ExperienceEvent) -> Void
    let onOpenVisit: (Visit) -> Void

    var body: some View {
        let isPark = category.templateKey == "theme_park"

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: isPark ? "Park Log" : "Nature Log",
                    japaneseTitle: isPark ? "来園記録" : "体験記録",
                    foregroundColor: primaryTextColor
                )

                Text("\(visits.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 4)

                if !events.isEmpty {
                    Menu {
                        ForEach(events) { event in
                            Button(event.title.isEmpty ? "施設" : event.title) {
                                onSelectEvent(event)
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
                        onOpenVisit(visit)
                    } label: {
                        PlaceExperienceVisitRow(visit: visit, isPark: isPark, tint: tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CategoryLibrarySubsection: View {
    let title: String
    let items: [CategoryLibraryItem]
    let sectionKey: String
    let emptyIcon: String
    let emptyTitle: String
    let category: RecordCategory
    let tint: Color
    let layout: CategoryLibraryLayoutMode
    let displayKey: String
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let onAddInterest: () -> Void
    let onOpenEvent: (UUID) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let japaneseTitle = CategoryTopVocabulary.sectionJapaneseTitle(
                englishTitle: title,
                templateKey: category.templateKey
            ) {
                LayeredCategorySectionTitle(
                    englishTitle: title,
                    japaneseTitle: japaneseTitle,
                    foregroundColor: primaryTextColor
                )
            } else {
                Text(title)
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(primaryTextColor)
            }

            Text("\(items.count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(secondaryTextColor)
        }

        if items.isEmpty {
            if sectionKey == "interests" || sectionKey == "book-interests" {
                Button(action: onAddInterest) {
                    CategoryScheduleEmptyRow(
                        icon: emptyIcon,
                        title: emptyTitle,
                        actionTitle: CategoryTopVocabulary.interestAddActionTitle(
                            templateKey: category.templateKey
                        ),
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
            ProgressiveCategoryLibraryContent(
                items: items,
                category: category,
                tint: tint,
                layout: layout,
                pageSize: CategoryTopLibraryPolicy.pageSize(for: layout),
                showsProductionMetadata: CategoryEventInformationPolicy.usesParentEventCard(
                    templateKey: category.templateKey,
                    sectionKey: sectionKey
                ),
                onOpenEvent: onOpenEvent
            )
            .id(displayKey)
        }
    }
}

struct ProgressiveCategoryLibraryContent: View {
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
                                        ? (category.templateKey == "live" ? "ライブ情報" : "公演情報")
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
                                    ? item.eventInformationCreditText(for: category)
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
                                        FavorecoIconLabel(
                                            item.productionTypeText,
                                            systemImage: category.templateKey == "live" ? "music.mic" : "theatermasks",
                                            iconSize: 12
                                        )
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

struct ChapterPreviewCard: View {
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

struct CategoryChapterFooter: View {
    let categories: [RecordCategory]
    let currentCategory: RecordCategory
    let tint: Color
    let onSelect: (RecordCategory) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        if let currentIndex = categories.firstIndex(where: { $0.id == currentCategory.id }),
           let neighborIndices = CategoryChapterNavigationPolicy.neighborIndices(
               categoryCount: categories.count,
               currentIndex: currentIndex
           ) {
            let previousCategory = neighborIndices.previous.map { categories[$0] }
            let nextCategory = neighborIndices.next.map { categories[$0] }

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

                Button(action: onOpenSettings) {
                    HStack(spacing: 12) {
                        FavorecoIcon(systemName: "gearshape", size: 20)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                CategoryTopPresentationPolicy.displayName(
                                    name: currentCategory.name,
                                    templateKey: currentCategory.templateKey
                                ) + "の設定"
                            )
                                .font(FavorecoTypography.bodyStrong)
                            Text("表示名・色・記録項目を変更")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        FavorecoIcon(systemName: "chevron.right", size: 15, fallbackWeight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground).opacity(0.92))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(0.28), lineWidth: 0.8)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("このジャンルの設定画面を開きます")
            }
        }
    }
}
