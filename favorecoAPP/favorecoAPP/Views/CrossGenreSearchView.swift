import SwiftUI
import SwiftData

struct CrossGenreSearchEntryBar: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themePalette.globalTint)

            Text("すべてのジャンルを検索")
                .font(FavorecoTypography.jpSans(14, weight: .medium, relativeTo: .body))
                .foregroundStyle(themePalette.secondaryText(for: colorScheme))

            Spacer(minLength: 8)

            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themePalette.tertiaryText(for: colorScheme))

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themePalette.tertiaryText(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(themePalette.globalTint.opacity(0.22), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("すべてのジャンルを検索、フィルターあり")
    }
}

struct CrossGenreSearchView: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Plan.updatedAt, order: .reverse) private var plans: [Plan]
    @Query(sort: \Visit.updatedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.updatedAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \PersonMaster.updatedAt, order: .reverse) private var people: [PersonMaster]
    @Query(sort: \PlaceMaster.updatedAt, order: .reverse) private var places: [PlaceMaster]

    @State private var query = ""
    @State private var selectedKind: CrossGenreSearchKind?
    @State private var categoryFilter: CrossGenreCategoryFilter = .all
    @State private var snapshot = CrossGenreSearchSnapshot(items: [], categories: [])
    @State private var selectedTarget: CrossGenreSearchTarget?

    private var normalizedTerms: [String] {
        query
            .components(separatedBy: .whitespacesAndNewlines)
            .map(normalizedCrossGenreSearchText)
            .filter { !$0.isEmpty }
    }

    private var hasActiveCondition: Bool {
        !normalizedTerms.isEmpty || selectedKind != nil || categoryFilter != .all
    }

    private var filteredItems: [CrossGenreSearchItem] {
        guard hasActiveCondition else { return [] }
        let terms = normalizedTerms
        return snapshot.items
            .filter { item in
                if let selectedKind, item.kind != selectedKind { return false }
                switch categoryFilter {
                case .all:
                    break
                case .category(let categoryID):
                    guard item.categoryID == categoryID else { return false }
                case .common:
                    guard item.categoryID == nil else { return false }
                }
                return terms.allSatisfy { item.normalizedSearchText.contains($0) }
            }
            .sorted { lhs, rhs in
                guard let firstTerm = terms.first else {
                    return lhs.sortDate > rhs.sortDate
                }
                let lhsPrefix = lhs.normalizedTitle.hasPrefix(firstTerm)
                let rhsPrefix = rhs.normalizedTitle.hasPrefix(firstTerm)
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                let lhsTitleMatch = lhs.normalizedTitle.contains(firstTerm)
                let rhsTitleMatch = rhs.normalizedTitle.contains(firstTerm)
                if lhsTitleMatch != rhsTitleMatch { return lhsTitleMatch }
                return lhs.sortDate > rhs.sortDate
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                filterSection

                if !hasActiveCondition {
                    FavorecoContentUnavailableView(
                        "検索語を入力してください",
                        systemImage: "magnifyingglass",
                        description: "作品・予定・記録・人物・場所を、すべてのジャンルから探せます。フィルターだけでも絞り込めます。"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 46)
                } else if filteredItems.isEmpty {
                    FavorecoContentUnavailableView(
                        "一致する結果はありません",
                        systemImage: "magnifyingglass",
                        description: "検索語またはフィルターを変えてください。"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 46)
                } else {
                    HStack {
                        Text("\(filteredItems.count)件")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(themePalette.secondaryText(for: colorScheme))
                        Spacer()
                        if selectedKind != nil || categoryFilter != .all {
                            Button("フィルターを解除") {
                                selectedKind = nil
                                categoryFilter = .all
                            }
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(themePalette.globalTint)
                        }
                    }

                    ForEach(filteredItems) { item in
                        Button {
                            selectedTarget = item.target
                        } label: {
                            CrossGenreSearchResultRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("横断検索")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "タイトル・人物・場所・メモ")
        .task { rebuildSnapshot() }
        .onChange(of: sourceCount) { _, _ in rebuildSnapshot() }
        .onChange(of: selectedTarget) { previous, current in
            if previous != nil, current == nil { rebuildSnapshot() }
        }
        .navigationDestination(item: $selectedTarget) { target in
            CrossGenreSearchDestination(target: target)
        }
    }

    private var sourceCount: Int {
        categories.count + events.count + plans.count + visits.count
            + inboxItems.count + people.count + places.count
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            filterRow(title: "種類") {
                CrossGenreSearchFilterChip(title: "すべて", isSelected: selectedKind == nil, tint: themePalette.globalTint) {
                    selectedKind = nil
                }
                ForEach(CrossGenreSearchKind.allCases) { kind in
                    CrossGenreSearchFilterChip(
                        title: kind.title,
                        systemImage: kind.systemImage,
                        isSelected: selectedKind == kind,
                        tint: themePalette.globalTint
                    ) {
                        selectedKind = selectedKind == kind ? nil : kind
                    }
                }
            }

            filterRow(title: "ジャンル") {
                CrossGenreSearchFilterChip(title: "すべて", isSelected: categoryFilter == .all, tint: themePalette.globalTint) {
                    categoryFilter = .all
                }
                ForEach(snapshot.categories) { category in
                    let filter = CrossGenreCategoryFilter.category(category.id)
                    CrossGenreSearchFilterChip(
                        title: category.name,
                        isSelected: categoryFilter == filter,
                        tint: Color(hex: category.colorHex)
                    ) {
                        categoryFilter = categoryFilter == filter ? .all : filter
                    }
                }
                CrossGenreSearchFilterChip(
                    title: "共通",
                    systemImage: "person.2",
                    isSelected: categoryFilter == .common,
                    tint: themePalette.globalTint
                ) {
                    categoryFilter = categoryFilter == .common ? .all : .common
                }
            }
        }
    }

    private func filterRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(themePalette.secondaryText(for: colorScheme))
            ScrollView(.horizontal) {
                HStack(spacing: 7) { content() }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func rebuildSnapshot() {
        snapshot = CrossGenreSearchSnapshot.make(
            categories: categories,
            events: events,
            plans: plans,
            visits: visits,
            inboxItems: inboxItems,
            people: people,
            places: places
        )
    }
}

private struct CrossGenreSearchFilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(FavorecoTypography.jpSans(12, weight: isSelected ? .semibold : .regular, relativeTo: .caption))
            .foregroundStyle(isSelected ? Color.white : tint)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(isSelected ? tint : tint.opacity(0.09), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(isSelected ? 0 : 0.30), lineWidth: 0.8) }
        }
        .buttonStyle(.plain)
    }
}

private struct CrossGenreSearchResultRow: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    let item: CrossGenreSearchItem

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Label(item.kind.title, systemImage: item.kind.systemImage)
                        .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(Color(hex: item.colorHex))
                        .lineLimit(1)

                    if item.categoryID != nil {
                        Text(item.categoryName)
                            .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(themePalette.tertiaryText(for: colorScheme))
                            .lineLimit(1)
                    }
                }

                Text(item.title)
                    .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(themePalette.bodyText(for: colorScheme))
                    .lineLimit(2)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(themePalette.secondaryText(for: colorScheme))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themePalette.tertiaryText(for: colorScheme))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: item.colorHex).opacity(0.24), lineWidth: 0.7)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artwork: some View {
        if let reference = item.thumbnailReference {
            CategoryEyecatchArtwork(
                reference: reference,
                templateKey: item.categoryTemplateKey,
                backgroundColor: Color(hex: item.colorHex).opacity(0.12)
            ) { _ in
                fallbackArtwork
            }
            .frame(width: 54, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            fallbackArtwork
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            Color(hex: item.colorHex).opacity(0.12)
            Image(systemName: item.systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(hex: item.colorHex))
        }
        .frame(width: 54, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct CrossGenreSearchDestination: View {
    let target: CrossGenreSearchTarget

    @ViewBuilder
    var body: some View {
        switch target {
        case .event(let id): CrossGenreEventDestination(eventID: id)
        case .plan(let id): HomePlanDestination(planID: id)
        case .visit(let id): CrossGenreVisitDestination(visitID: id)
        case .inbox(let id): CrossGenreInboxDestination(itemID: id)
        case .person(let id): PersonMasterEditDestination(personID: id)
        case .place(let id): PlaceMasterEditDestination(placeID: id)
        }
    }
}

private struct CrossGenreEventDestination: View {
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

private struct CrossGenreVisitDestination: View {
    @Query private var visits: [Visit]

    init(visitID: UUID) {
        _visits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

    var body: some View {
        if let visit = visits.first {
            ExperienceDetailView(visit: visit)
        } else {
            FavorecoContentUnavailableView("記録が見つかりません", systemImage: "trash")
        }
    }
}

private struct CrossGenreInboxDestination: View {
    @Query private var items: [InboxItem]

    init(itemID: UUID) {
        _items = Query(filter: #Predicate<InboxItem> { $0.id == itemID })
    }

    var body: some View {
        if let item = items.first {
            InboxDetailView(item: item)
        } else {
            FavorecoContentUnavailableView("気になる項目が見つかりません", systemImage: "trash")
        }
    }
}
