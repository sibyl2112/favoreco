import SwiftUI
import SwiftData

struct HomeGalleryItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let categoryID: UUID?
    let categoryName: String
    let categoryTemplateKey: String
    let categoryColorHex: String
    let visitedAt: Date
    let registeredAt: Date
    let thumbnailReference: ThumbnailReference?
    let aspectRatio: Double
    let fillsFrame: Bool
    let tagNames: [String]
    let normalizedSearchText: String

    init(snapshot: HomeVisitSnapshot) {
        id = snapshot.id
        title = snapshot.title
        categoryID = snapshot.categoryID
        categoryName = snapshot.categoryName
        categoryTemplateKey = snapshot.categoryTemplateKey
        categoryColorHex = snapshot.categoryColorHex
        visitedAt = snapshot.visitedAt
        registeredAt = snapshot.registeredAt
        thumbnailReference = snapshot.thumbnailReference
        aspectRatio = snapshot.eyecatchAspectRatio
        fillsFrame = snapshot.fillsEyecatchFrame
        tagNames = snapshot.tagNames
        normalizedSearchText = snapshot.normalizedSearchText
    }

    init(
        id: UUID = UUID(),
        title: String,
        categoryID: UUID?,
        categoryName: String,
        categoryTemplateKey: String = "",
        categoryColorHex: String = "#147C88",
        visitedAt: Date,
        registeredAt: Date,
        thumbnailReference: ThumbnailReference? = nil,
        aspectRatio: Double = 1,
        fillsFrame: Bool = true,
        tagNames: [String] = [],
        normalizedSearchText: String = ""
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.categoryTemplateKey = categoryTemplateKey
        self.categoryColorHex = categoryColorHex
        self.visitedAt = visitedAt
        self.registeredAt = registeredAt
        self.thumbnailReference = thumbnailReference
        self.aspectRatio = aspectRatio
        self.fillsFrame = fillsFrame
        self.tagNames = tagNames
        self.normalizedSearchText = normalizedSearchText
    }
}

struct HomeGalleryCategoryOption: Identifiable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String
}

enum HomeGalleryFilterLogic {
    static func filtered(
        _ items: [HomeGalleryItem],
        categoryIDs: Set<UUID>,
        years: Set<Int>,
        searchText: String,
        tagNames: Set<String>,
        calendar: Calendar = .current
    ) -> [HomeGalleryItem] {
        let terms = normalizedTerms(searchText)
        return items.filter { item in
            if !categoryIDs.isEmpty {
                guard let categoryID = item.categoryID, categoryIDs.contains(categoryID) else {
                    return false
                }
            }
            if !years.isEmpty,
               !years.contains(calendar.component(.year, from: item.visitedAt)) {
                return false
            }
            if !tagNames.isEmpty, tagNames.isDisjoint(with: Set(item.tagNames)) {
                return false
            }
            return terms.allSatisfy { item.normalizedSearchText.localizedCaseInsensitiveContains($0) }
        }
        .sorted { lhs, rhs in
            if lhs.registeredAt != rhs.registeredAt { return lhs.registeredAt > rhs.registeredAt }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    static func masonryColumns(_ items: [HomeGalleryItem]) -> [[HomeGalleryItem]] {
        var columns = [[], []] as [[HomeGalleryItem]]
        var estimatedHeights = [Double](repeating: 0, count: 2)
        for item in items {
            let column = estimatedHeights[0] <= estimatedHeights[1] ? 0 : 1
            columns[column].append(item)
            estimatedHeights[column] += 1 / min(max(item.aspectRatio, 0.68), 1.55) + 0.34
        }
        return columns
    }

    private static func normalizedTerms(_ value: String) -> [String] {
        value
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }
}

struct HomeGallerySection: View {
    let visits: [HomeVisitSnapshot]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var selectedYears: Set<Int> = []
    @State private var searchText = ""
    @State private var selectedTagNames: Set<String> = []
    @State private var isShowingGallery = false
    @State private var isShowingDetailedSearch = false

    var body: some View {
        let items = visits.map { HomeGalleryItem(snapshot: $0) }
        let filteredItems = HomeGalleryFilterLogic.filtered(
            items,
            categoryIDs: selectedCategoryIDs,
            years: selectedYears,
            searchText: searchText,
            tagNames: selectedTagNames
        )
        let previewItems = Array(filteredItems.prefix(6))

        VStack(alignment: .leading, spacing: 10) {
            galleryHeading

            HomeGalleryFilterBar(
                items: items,
                selectedCategoryIDs: $selectedCategoryIDs,
                selectedYears: $selectedYears
            )

            Button {
                isShowingDetailedSearch = true
                isShowingGallery = true
            } label: {
                HStack(spacing: 6) {
                    FavorecoIcon(systemName: "slider.horizontal.3", size: 13)
                    Text("詳細検索")
                    let count = selectedTagNames.isEmpty && searchText.isEmpty ? 0 : 1
                    if count > 0 {
                        Text("設定中")
                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themePalette.globalTint.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(FavorecoTypography.jpSans(12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(themePalette.globalTint)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("全面ギャラリーで検索条件を開きます")

            if previewItems.isEmpty {
                FavorecoContentUnavailableView(
                    "該当する記録がありません",
                    systemImage: "images",
                    description: "フィルターを変更すると、ほかの記録を表示できます。"
                )
                .frame(minHeight: 150)
            } else {
                HomeGalleryMasonryGrid(items: previewItems)
            }

            galleryGrabber
        }
        .fullScreenCover(isPresented: $isShowingGallery) {
            HomeGalleryFullScreenView(
                items: items,
                selectedCategoryIDs: $selectedCategoryIDs,
                selectedYears: $selectedYears,
                searchText: $searchText,
                selectedTagNames: $selectedTagNames,
                initiallyShowsDetailedSearch: isShowingDetailedSearch
            )
        }
    }

    private var galleryHeading: some View {
        ZStack(alignment: .leading) {
            Text("記録")
                .font(FavorecoTypography.jpSerif(34, weight: .bold, relativeTo: .title))
                .foregroundStyle(themePalette.globalTint.opacity(colorScheme == .dark ? 0.10 : 0.07))
                .offset(x: 126, y: -2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("GALLERY")
                    .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(themePalette.headingText(for: colorScheme))
                Text("ギャラリー")
                    .font(FavorecoTypography.jpSans(11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
    }

    private var galleryGrabber: some View {
        Button {
            isShowingDetailedSearch = false
            isShowingGallery = true
        } label: {
            VStack(spacing: 5) {
                Capsule()
                    .fill(Color.secondary.opacity(0.38))
                    .frame(width: 42, height: 5)
                Text("すべて見る")
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(themePalette.globalTint)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onEnded { value in
                    guard value.translation.height < -36,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    isShowingDetailedSearch = false
                    isShowingGallery = true
                }
        )
        .accessibilityLabel("すべてのギャラリーを見る")
        .accessibilityHint("タップまたは上方向へスワイプして開きます")
    }
}

private struct HomeGalleryFullScreenView: View {
    let items: [HomeGalleryItem]
    @Binding var selectedCategoryIDs: Set<UUID>
    @Binding var selectedYears: Set<Int>
    @Binding var searchText: String
    @Binding var selectedTagNames: Set<String>
    let initiallyShowsDetailedSearch: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var visibleCount = 12
    @State private var isShowingDetailedSearch: Bool

    init(
        items: [HomeGalleryItem],
        selectedCategoryIDs: Binding<Set<UUID>>,
        selectedYears: Binding<Set<Int>>,
        searchText: Binding<String>,
        selectedTagNames: Binding<Set<String>>,
        initiallyShowsDetailedSearch: Bool
    ) {
        self.items = items
        _selectedCategoryIDs = selectedCategoryIDs
        _selectedYears = selectedYears
        _searchText = searchText
        _selectedTagNames = selectedTagNames
        self.initiallyShowsDetailedSearch = initiallyShowsDetailedSearch
        _isShowingDetailedSearch = State(initialValue: initiallyShowsDetailedSearch)
    }

    private var filteredItems: [HomeGalleryItem] {
        HomeGalleryFilterLogic.filtered(
            items,
            categoryIDs: selectedCategoryIDs,
            years: selectedYears,
            searchText: searchText,
            tagNames: selectedTagNames
        )
    }

    private var visibleItems: [HomeGalleryItem] {
        Array(filteredItems.prefix(visibleCount))
    }

    private var availableTags: [String] {
        Array(Set(items.flatMap(\.tagNames))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var filterToken: String {
        [
            selectedCategoryIDs.map(\.uuidString).sorted().joined(separator: ","),
            selectedYears.sorted().map(String.init).joined(separator: ","),
            searchText,
            selectedTagNames.sorted().joined(separator: ","),
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HomeGalleryFilterBar(
                        items: items,
                        selectedCategoryIDs: $selectedCategoryIDs,
                        selectedYears: $selectedYears
                    )

                    detailedSearch

                    HStack {
                        Text("\(filteredItems.count)件")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if hasActiveFilters {
                            Button("条件をクリア", action: clearFilters)
                                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                        }
                    }

                    if visibleItems.isEmpty {
                        FavorecoContentUnavailableView(
                            "該当する記録がありません",
                            systemImage: "magnifyingglass",
                            description: "検索条件を変更して、もう一度お試しください。"
                        )
                        .frame(minHeight: 300)
                    } else {
                        HomeGalleryMasonryGrid(items: visibleItems)

                        if visibleItems.count < filteredItems.count {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .onAppear {
                                    visibleCount = min(visibleCount + 12, filteredItems.count)
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(themePalette.canvas(for: colorScheme).ignoresSafeArea())
            .navigationTitle("ギャラリー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: filterToken) { _, _ in
                visibleCount = 12
            }
        }
    }

    private var detailedSearch: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isShowingDetailedSearch.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    FavorecoIcon(systemName: "slider.horizontal.3", size: 14)
                    Text("詳細検索")
                    if !searchText.isEmpty || !selectedTagNames.isEmpty {
                        Text("設定中")
                            .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themePalette.globalTint.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    Image(systemName: isShowingDetailedSearch ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isShowingDetailedSearch {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        FavorecoIcon(systemName: "magnifyingglass", size: 16)
                            .foregroundStyle(.secondary)
                        TextField("タイトル・会場・メモなどを検索", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("検索文字を消去")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))

                    if !availableTags.isEmpty {
                        Text("タグ")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button {
                                        toggle(tag, in: &selectedTagNames)
                                    } label: {
                                        Label(
                                            tag,
                                            systemImage: selectedTagNames.contains(tag) ? "checkmark.square.fill" : "square"
                                        )
                                        .font(FavorecoTypography.jpSans(11, weight: .medium, relativeTo: .caption))
                                        .padding(.horizontal, 9)
                                        .frame(minHeight: 30)
                                        .background(
                                            selectedTagNames.contains(tag)
                                                ? themePalette.globalTint.opacity(0.12)
                                                : Color.primary.opacity(0.04),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
        }
    }

    private var hasActiveFilters: Bool {
        !selectedCategoryIDs.isEmpty
            || !selectedYears.isEmpty
            || !searchText.isEmpty
            || !selectedTagNames.isEmpty
    }

    private func clearFilters() {
        selectedCategoryIDs.removeAll()
        selectedYears.removeAll()
        selectedTagNames.removeAll()
        searchText = ""
    }
}

private struct HomeGalleryFilterBar: View {
    let items: [HomeGalleryItem]
    @Binding var selectedCategoryIDs: Set<UUID>
    @Binding var selectedYears: Set<Int>

    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var isShowingCategoryPicker = false

    private var categories: [HomeGalleryCategoryOption] {
        var seen = Set<UUID>()
        return items.compactMap { item in
            guard let id = item.categoryID, seen.insert(id).inserted else { return nil }
            return HomeGalleryCategoryOption(id: id, name: item.categoryName, colorHex: item.categoryColorHex)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var years: [Int] {
        Array(Set(items.map { Calendar.current.component(.year, from: $0.visitedAt) })).sorted(by: >)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isShowingCategoryPicker = true
            } label: {
                HomeGalleryFilterLabel(title: "ジャンル", value: categorySummary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingCategoryPicker, arrowEdge: .top) {
                HomeGalleryCategoryPicker(
                    categories: categories,
                    selectedCategoryIDs: $selectedCategoryIDs
                )
                .presentationCompactAdaptation(.popover)
            }

            Menu {
                Button {
                    selectedYears.removeAll()
                } label: {
                    Label("すべて", systemImage: selectedYears.isEmpty ? "checkmark.square.fill" : "square")
                }
                Divider()
                ForEach(years, id: \.self) { year in
                    Button {
                        toggle(year, in: &selectedYears)
                    } label: {
                        HStack {
                            Image(systemName: selectedYears.contains(year) ? "checkmark.square.fill" : "square")
                            Text(verbatim: FavorecoDateText.year(year))
                        }
                    }
                }
            } label: {
                HomeGalleryFilterLabel(title: "年度", value: yearSummary)
            }
        }
        .tint(themePalette.globalTint)
    }

    private var categorySummary: String {
        guard !selectedCategoryIDs.isEmpty else { return "すべて" }
        let names = categories.filter { selectedCategoryIDs.contains($0.id) }.map(\.name)
        return names.count == 1 ? names[0] : "\(names.count)件"
    }

    private var yearSummary: String {
        guard !selectedYears.isEmpty else { return "すべて" }
        return selectedYears.count == 1
            ? FavorecoDateText.year(selectedYears.first ?? 0)
            : "\(selectedYears.count)件"
    }
}

private struct HomeGalleryCategoryPicker: View {
    let categories: [HomeGalleryCategoryOption]
    @Binding var selectedCategoryIDs: Set<UUID>

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                categoryButton(
                    title: "すべて",
                    isSelected: selectedCategoryIDs.isEmpty
                ) {
                    selectedCategoryIDs.removeAll()
                }

                Divider()
                    .padding(.horizontal, 12)

                ForEach(categories) { category in
                    categoryButton(
                        title: category.name,
                        isSelected: selectedCategoryIDs.contains(category.id)
                    ) {
                        toggle(category.id, in: &selectedCategoryIDs)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: 280, height: min(CGFloat(categories.count + 1) * 48 + 12, 420))
        .tint(themePalette.globalTint)
        .accessibilityLabel("ギャラリーのジャンルを選択")
    }

    private func categoryButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? themePalette.globalTint : Color.secondary)
                    .frame(width: 22)

                Text(title)
                    .font(FavorecoTypography.jpSans(16, weight: .medium, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

private struct HomeGalleryFilterLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .foregroundStyle(.primary)
            Text(value)
                .foregroundStyle(.tint)
                .lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .font(FavorecoTypography.jpSans(12, weight: .medium, relativeTo: .caption))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.7)
        }
    }
}

private struct HomeGalleryMasonryGrid: View {
    let items: [HomeGalleryItem]

    private var columns: [[HomeGalleryItem]] {
        HomeGalleryFilterLogic.masonryColumns(items)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(columns.indices, id: \.self) { columnIndex in
                LazyVStack(spacing: 8) {
                    ForEach(columns[columnIndex]) { item in
                        NavigationLink {
                            HomeGalleryVisitDestination(visitID: item.id)
                        } label: {
                            HomeGalleryTile(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

private struct HomeGalleryTile: View {
    let item: HomeGalleryItem

    @Environment(\.favorecoThemePalette) private var themePalette

    private var categoryColor: Color {
        themePalette.categoryColor(hex: item.categoryColorHex)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CategoryEyecatchArtwork(
                reference: item.thumbnailReference,
                templateKey: item.categoryTemplateKey,
                backgroundColor: categoryColor.opacity(0.10),
                defaultContentMode: item.fillsFrame ? .fill : .fit
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: item.categoryTemplateKey,
                    displaySize: size
                )
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.76)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.categoryName)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .padding(.horizontal, 6)
                    .frame(minHeight: 20)
                    .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(categoryColor.opacity(0.9), lineWidth: 0.7)
                    }

                Text(item.title)
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(FavorecoDateText.compactDate(item.visitedAt))
                    .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .padding(9)
        }
        .aspectRatio(CGFloat(min(max(item.aspectRatio, 0.68), 1.55)), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(categoryColor.opacity(0.26), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeGalleryVisitDestination: View {
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

private func toggle<Value: Hashable>(_ value: Value, in selection: inout Set<Value>) {
    if selection.contains(value) {
        selection.remove(value)
    } else {
        selection.insert(value)
    }
}
