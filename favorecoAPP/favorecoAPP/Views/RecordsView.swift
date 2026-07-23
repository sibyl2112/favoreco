import SwiftUI
import SwiftData

struct RecordsView: View {
    let embedsInNavigationStack: Bool
    let screenTitle: String
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @State private var searchText = ""
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var selectedTagNames: Set<String> = []
    @State private var selectedCompanionNames: Set<String> = []
    @State private var periodFilter: RecordPeriodFilter = .all
    @State private var customPeriodStart = Date().startOfMonth
    @State private var customPeriodEnd = Date()
    @State private var photoFilterEnabled = false
    @State private var sortOrder: RecordSortOrder = .newest
    @State private var isShowingFilters = false
    @AppStorage(AppStorageKeys.recordsLayoutMode) private var recordsLayoutModeRaw = RecordsLayoutMode.banner.rawValue

    init(embedsInNavigationStack: Bool = true, screenTitle: String = "記録") {
        self.embedsInNavigationStack = embedsInNavigationStack
        self.screenTitle = screenTitle
    }

    private var recordsLayoutMode: RecordsLayoutMode {
        RecordsLayoutMode(rawValue: recordsLayoutModeRaw) ?? .banner
    }

    private var visibleVisits: [Visit] {
        let calendar = Calendar.current
        let now = Date()
        var peopleTextByEventID: [UUID: [String]] = [:]
        var peopleTextByVisitID: [UUID: [String]] = [:]

        for link in personLinks where !link.isArchived {
            let person = link.person
            let text = [
                link.nameSnapshot,
                link.displayRole,
                link.roleKey,
                link.memo,
                person?.displayName ?? "",
                person?.reading ?? "",
                person?.aliasesRaw ?? "",
                person?.roleTagsRaw ?? "",
                person?.memo ?? "",
                person?.sourceSnapshotRaw ?? "",
            ].joined(separator: " ")

            if let eventID = link.event?.id {
                peopleTextByEventID[eventID, default: []].append(text)
            }
            if let visitID = link.visit?.id {
                peopleTextByVisitID[visitID, default: []].append(text)
            }
        }

        let filtered = visits.filter { visit in
            guard visit.event?.isArchived != true else { return false }
            if !selectedCategoryIDs.isEmpty {
                guard let categoryID = visit.event?.category?.id,
                      selectedCategoryIDs.contains(categoryID) else { return false }
            }
            switch periodFilter {
            case .all:
                break
            case .thisMonth:
                guard calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .month) else { return false }
            case .thisYear:
                guard calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .year) else { return false }
            case .custom:
                let start = calendar.startOfDay(for: customPeriodStart)
                let endDay = calendar.startOfDay(for: customPeriodEnd)
                guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay),
                      visit.visitedAt >= start,
                      visit.visitedAt < endExclusive else { return false }
            }
            if photoFilterEnabled,
               !(visit.photos ?? []).contains(where: { $0.mediaKind == "photo" && $0.hasStoredData }) {
                return false
            }

            let visitTags = Set(recordFacetNames(from: visit.tagNamesRaw))
            if !selectedTagNames.isEmpty, selectedTagNames.isDisjoint(with: visitTags) {
                return false
            }

            let visitCompanions = Set(recordFacetNames(from: visit.companionNamesRaw))
            if !selectedCompanionNames.isEmpty,
               selectedCompanionNames.isDisjoint(with: visitCompanions) {
                return false
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            let event = visit.event
            let place = visit.placeMaster
            let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            let advancedText = unitFields.advancedEntries
                .flatMap { [$0.label, $0.value] }
                .joined(separator: " ")
            let eventPeopleText = event.flatMap { peopleTextByEventID[$0.id] } ?? []
            let linkedPeopleText = eventPeopleText + (peopleTextByVisitID[visit.id] ?? [])
            let searchableText = [
                event?.title ?? "",
                event?.seriesName ?? "",
                event?.organizerNameSnapshot ?? "",
                event?.memo ?? "",
                event?.importMemo ?? "",
                event?.unitFieldsRaw ?? "",
                event?.officialURL ?? "",
                event?.category?.name ?? "",
                visit.venueNameSnapshot,
                visit.note,
                visit.tagNamesRaw,
                visit.companionNamesRaw,
                visit.seatText,
                visit.outcomeKey,
                String(describing: visit.amount),
                String(visit.overallRating),
                unitFields.ocrText,
                advancedText,
                place?.name ?? "",
                place?.reading ?? "",
                place?.aliasesRaw ?? "",
                place?.placeTagsRaw ?? "",
                place?.address ?? "",
                place?.memo ?? "",
                linkedPeopleText.joined(separator: " "),
            ].joined(separator: " ")
            let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            return terms.allSatisfy { searchableText.localizedCaseInsensitiveContains($0) }
        }

        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .newest:
                lhs.visitedAt > rhs.visitedAt
            case .oldest:
                lhs.visitedAt < rhs.visitedAt
            case .recentlyUpdated:
                lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedCategoryIDs.isEmpty { count += 1 }
        if periodFilter != .all { count += 1 }
        if !selectedTagNames.isEmpty { count += 1 }
        if !selectedCompanionNames.isEmpty { count += 1 }
        if photoFilterEnabled { count += 1 }
        if sortOrder != .newest { count += 1 }
        return count
    }

    private var detailedFilterCount: Int {
        var count = 0
        if periodFilter != .all { count += 1 }
        if !selectedTagNames.isEmpty { count += 1 }
        if !selectedCompanionNames.isEmpty { count += 1 }
        if photoFilterEnabled { count += 1 }
        if sortOrder != .newest { count += 1 }
        return count
    }

    private var activeCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var quickFilterCategories: [RecordCategory] {
        let usedCategoryIDs = Set(
            visits.compactMap { visit -> UUID? in
                guard visit.event?.isArchived != true else { return nil }
                return visit.event?.category?.id
            }
        )
        return activeCategories.filter {
            usedCategoryIDs.contains($0.id) || selectedCategoryIDs.contains($0.id)
        }
    }

    private var availableTagNames: [String] {
        recordFacetOptions(\.tagNamesRaw, including: selectedTagNames)
    }

    private var availableCompanionNames: [String] {
        recordFacetOptions(\.companionNamesRaw, including: selectedCompanionNames)
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack { recordsRoot }
        } else {
            recordsRoot
        }
    }

    private var recordsRoot: some View {
        VStack(spacing: 0) {
            if embedsInNavigationStack {
                MainScreenHeader(title: screenTitle)
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .padding(.bottom, 6)
            }

            recordToolbar

            recordsContent
        }
        .navigationTitle(embedsInNavigationStack ? "" : screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(embedsInNavigationStack ? .hidden : .visible, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingFilters) {
            RecordFilterView(
                selectedCategoryIDs: $selectedCategoryIDs,
                selectedTagNames: $selectedTagNames,
                selectedCompanionNames: $selectedCompanionNames,
                availableTagNames: availableTagNames,
                availableCompanionNames: availableCompanionNames,
                periodFilter: $periodFilter,
                customPeriodStart: $customPeriodStart,
                customPeriodEnd: $customPeriodEnd,
                photoFilterEnabled: $photoFilterEnabled,
                sortOrder: $sortOrder
            )
        }
    }

    private var recordToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("タイトル・人物・会場などを検索", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("検索をクリア")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            quickCategoryFilter

            detailedSearchButton

            HStack {
                Text("\(visibleVisits.count)件")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                RecordsLayoutPicker(selectionRawValue: $recordsLayoutModeRaw)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
    }

    private var detailedSearchButton: some View {
        Button {
            isShowingFilters = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text("詳細検索")

                if detailedFilterCount > 0 {
                    Text("\(detailedFilterCount)")
                        .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.accentColor, in: Circle())
                }
            }
            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(Color.accentColor.opacity(0.08), in: Capsule())
            .overlay {
                Capsule().stroke(Color.accentColor.opacity(0.22), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("詳細検索")
        .accessibilityValue(detailedFilterCount > 0 ? "\(detailedFilterCount)件の条件を適用中" : "条件なし")
    }

    private var quickCategoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                quickCategoryButton(
                    title: "すべて",
                    isSelected: selectedCategoryIDs.isEmpty,
                    action: { selectedCategoryIDs.removeAll() }
                )

                ForEach(quickFilterCategories) { category in
                    quickCategoryButton(
                        title: category.name.isEmpty ? "無題" : category.name,
                        isSelected: selectedCategoryIDs.contains(category.id),
                        action: { toggleQuickCategory(category.id) }
                    )
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        .frame(height: 30)
        .accessibilityLabel("ジャンルで絞り込む")
    }

    private func quickCategoryButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(title)
                    .font(FavorecoTypography.jpSans(12, weight: isSelected ? .semibold : .regular, relativeTo: .caption))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func toggleQuickCategory(_ categoryID: UUID) {
        if selectedCategoryIDs.isEmpty {
            selectedCategoryIDs = [categoryID]
        } else if selectedCategoryIDs.contains(categoryID) {
            selectedCategoryIDs.remove(categoryID)
        } else {
            selectedCategoryIDs.insert(categoryID)
        }
    }

    private func recordFacetOptions(
        _ keyPath: KeyPath<Visit, String>,
        including selectedValues: Set<String>
    ) -> [String] {
        let values = visits
            .filter { $0.event?.isArchived != true }
            .flatMap { recordFacetNames(from: $0[keyPath: keyPath]) }
        return Array(Set(values).union(selectedValues))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @ViewBuilder
    private var recordsContent: some View {
        if visibleVisits.isEmpty {
            List {
                PlaceholderRow(
                    icon: activeFilterCount > 0 || !searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "rectangle.stack",
                    title: activeFilterCount > 0 || !searchText.isEmpty ? "条件に合う記録がありません" : "記録はまだありません",
                    message: activeFilterCount > 0 || !searchText.isEmpty ? "検索語やフィルターを変更してください。" : "下部の「追加」から最初の記録を追加できます。"
                )
            }
            .listStyle(.plain)
        } else {
            ScrollView {
                Group {
                    switch recordsLayoutMode {
                    case .gallery:
                        VisitRecordGalleryGrid(visits: visibleVisits)
                    case .compact:
                        VisitRecordCompactGrid(visits: visibleVisits)
                    case .banner:
                        VisitRecordBannerList(visits: visibleVisits)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
        }
    }

}

private enum RecordPeriodFilter: String, CaseIterable, Identifiable {
    case all
    case thisMonth
    case thisYear
    case custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "すべて"
        case .thisMonth: "今月"
        case .thisYear: "今年"
        case .custom: "期間指定"
        }
    }
}

private enum RecordSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case recentlyUpdated

    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "新しい順"
        case .oldest: "古い順"
        case .recentlyUpdated: "最近更新した順"
        }
    }
}

private struct RecordsLayoutPicker: View {
    @Binding var selectionRawValue: String

    private var selection: RecordsLayoutMode {
        RecordsLayoutMode(rawValue: selectionRawValue) ?? .banner
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RecordsLayoutMode.allCases) { mode in
                Button {
                    selectionRawValue = mode.rawValue
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 28)
                        .foregroundStyle(selection == mode ? Color.white : Color.accentColor)
                        .background(
                            selection == mode ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.displayName)表示")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 0.75)
        }
    }
}

private struct RecordFilterView: View {
    @Binding var selectedCategoryIDs: Set<UUID>
    @Binding var selectedTagNames: Set<String>
    @Binding var selectedCompanionNames: Set<String>
    let availableTagNames: [String]
    let availableCompanionNames: [String]
    @Binding var periodFilter: RecordPeriodFilter
    @Binding var customPeriodStart: Date
    @Binding var customPeriodEnd: Date
    @Binding var photoFilterEnabled: Bool
    @Binding var sortOrder: RecordSortOrder

    var body: some View {
        Form {
            Section("日付・期間") {
                Picker("期間", selection: $periodFilter) {
                    ForEach(RecordPeriodFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if periodFilter == .custom {
                    DatePicker("開始日", selection: $customPeriodStart, displayedComponents: .date)
                        .onChange(of: customPeriodStart) { _, newValue in
                            if customPeriodEnd < newValue {
                                customPeriodEnd = newValue
                            }
                        }
                    DatePicker(
                        "終了日",
                        selection: $customPeriodEnd,
                        in: customPeriodStart...,
                        displayedComponents: .date
                    )
                }
            }

            if !availableTagNames.isEmpty {
                RecordFacetFilterSection(
                    title: "タグ",
                    values: availableTagNames,
                    selection: $selectedTagNames
                )
            }

            if !availableCompanionNames.isEmpty {
                RecordFacetFilterSection(
                    title: "同行者",
                    values: availableCompanionNames,
                    selection: $selectedCompanionNames
                )
            }

            Section("内容") {
                Toggle("写真がある記録だけ", isOn: $photoFilterEnabled)
            }

            Section("並び順") {
                Picker("並び順", selection: $sortOrder) {
                    ForEach(RecordSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            }

            Section {
                Button("すべての条件をクリア") {
                    selectedCategoryIDs.removeAll()
                    selectedTagNames.removeAll()
                    selectedCompanionNames.removeAll()
                    periodFilter = .all
                    customPeriodStart = Date().startOfMonth
                    customPeriodEnd = Date()
                    photoFilterEnabled = false
                    sortOrder = .newest
                }
            }
        }
        .navigationTitle("詳細検索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct RecordFacetFilterSection: View {
    let title: String
    let values: [String]
    @Binding var selection: Set<String>

    var body: some View {
        Section(title) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(values, id: \.self) { value in
                    Button {
                        toggle(value)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: selection.contains(value) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selection.contains(value) ? Color.accentColor : .secondary)
                            Text(value)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selection.contains(value) ? "選択中" : "未選択")
                }
            }

            if !selection.isEmpty {
                Button("この条件をクリア") {
                    selection.removeAll()
                }
                .font(FavorecoTypography.captionStrong)
            }
        }
    }

    private func toggle(_ value: String) {
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
    }
}

private func recordFacetNames(from rawValue: String) -> [String] {
    rawValue
        .components(separatedBy: CharacterSet(charactersIn: ",、;；\n"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}
