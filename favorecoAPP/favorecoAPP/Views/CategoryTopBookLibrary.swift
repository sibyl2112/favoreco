//
//  CategoryTopBookLibrary.swift
//  favorecoAPP
//
//  Book-specific category library, insights, and series navigation.
//

import SwiftUI
import SwiftData

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

struct BookSeriesRoute: Identifiable, Hashable {
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

struct BookYearStatusStrip: View {
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
        var counts: [String: Int] = [:]
        for item in items {
            let key = VisitUnitFields(rawValue: item.event.unitFieldsRaw).bookContentTypeKey
            guard let type = BookContentType(rawValue: key) else { continue }
            counts[type.displayName, default: 0] += 1
        }
        return counts
            .map { BookTypeStat(name: $0.key, count: $0.value) }
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

struct BookLibrarySection: View {
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

    /// タブではなくカード自身の読書状態を正本に遷移先を決める。
    /// 「すべて」内でも読書中／読了なら最新の該当記録を直接開く。
    private func readingRecordToOpen(for item: CategoryLibraryItem) -> Visit? {
        let matchesSelectedState: (Visit) -> Bool
        let itemStatus = bookStatus(for: item)
        switch itemStatus {
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
                let lhsDate = itemStatus == .read ? lhs.endedAt : lhs.visitedAt
                let rhsDate = itemStatus == .read ? rhs.endedAt : rhs.visitedAt
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
                    .font(.system(size: isCompact ? 9 : 10, weight: .heavy))
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
        case .read: Color(hex: "#C43D4B")
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

struct BookSeriesDetailView: View {
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
                    initialBookContentTypeKey: VisitUnitFields(rawValue: representativeEvent.unitFieldsRaw)
                        .bookContentTypeKey,
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
