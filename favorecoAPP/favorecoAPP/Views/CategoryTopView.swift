//
//  CategoryTopView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit

struct CategoryTopView: View {
    private enum GenreDragAxis {
        case horizontal
        case vertical
    }

    let category: RecordCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RecordCategory.sortOrder) private var allCategories: [RecordCategory]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @State private var isShowingAddExperience = false
    @State private var selectedEventForNewVisit: ExperienceEvent?
    @State private var selectedCategoryID: UUID
    @State private var isShowingGenrePicker = false
    @State private var transitionMovesForward = true
    @State private var lowerContentDragOffset: CGFloat = 0
    @State private var genreDragAxis: GenreDragAxis?

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
                            hero(
                                category: activeCategory,
                                snapshot: snapshot,
                                recordTemplate: recordTemplate
                            )

                            VStack(alignment: .leading, spacing: 24) {
                                stats(snapshot: snapshot)
                                eventSection(snapshot: snapshot, recordTemplate: recordTemplate)
                                    .id(CategoryScrollAnchor.events)
                                recentVisits(category: activeCategory, snapshot: snapshot)
                                    .id(CategoryScrollAnchor.recentVisits)
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
        .confirmationDialog("ジャンルを選ぶ", isPresented: $isShowingGenrePicker, titleVisibility: .visible) {
            ForEach(snapshot.visibleCategories) { selectableCategory in
                Button(selectableCategory.name.isEmpty ? "無題" : selectableCategory.name) {
                    switchCategory(to: selectableCategory)
                }
            }
            Button("キャンセル", role: .cancel) {}
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
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
