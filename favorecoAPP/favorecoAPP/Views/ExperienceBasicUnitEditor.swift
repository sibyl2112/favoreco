import MapKit
import SwiftUI

struct ExperienceBasicUnitEditor: View {
    @StateObject private var publicPlaceStore = PublicPlaceCatalogStore.shared
    let template: CategoryRecordTemplate
    private let editableTitle: Binding<String>?
    private let editableSeriesName: Binding<String>?
    private let existingTitle: String
    private let existingSeriesName: String
    @Binding private var visitedAt: Date
    @Binding private var endedAt: Date
    @Binding private var styleNamesText: String
    @Binding private var venueName: String
    @Binding private var venueAddress: String
    @Binding private var overallRating: Double
    let latitude: Double
    let longitude: Double
    let placeMasters: [PlaceMaster]
    let usesPlaceSuggestions: Bool
    let usesMapSearchAssist: Bool
    let supportsPerformanceTime: Bool
    let supportsStyles: Bool
    let usesExplicitTheaterLayout: Bool
    let ratingText: String
    let onSelectPlace: (PlaceMaster) -> Void
    let onSelectPublicPlace: (PublicPlaceSelectionDraft) -> Void
    let onOpenPlaceSearch: () -> Void

    init(
        template: CategoryRecordTemplate,
        title: Binding<String>,
        seriesName: Binding<String>,
        visitedAt: Binding<Date>,
        endedAt: Binding<Date>,
        styleNamesText: Binding<String>,
        venueName: Binding<String>,
        venueAddress: Binding<String>,
        overallRating: Binding<Double>,
        latitude: Double,
        longitude: Double,
        placeMasters: [PlaceMaster],
        usesPlaceSuggestions: Bool,
        usesMapSearchAssist: Bool,
        supportsPerformanceTime: Bool,
        supportsStyles: Bool,
        usesExplicitTheaterLayout: Bool = false,
        ratingText: String,
        onSelectPlace: @escaping (PlaceMaster) -> Void,
        onSelectPublicPlace: @escaping (PublicPlaceSelectionDraft) -> Void,
        onOpenPlaceSearch: @escaping () -> Void
    ) {
        self.template = template
        editableTitle = title
        editableSeriesName = seriesName
        existingTitle = ""
        existingSeriesName = ""
        _visitedAt = visitedAt
        _endedAt = endedAt
        _styleNamesText = styleNamesText
        _venueName = venueName
        _venueAddress = venueAddress
        _overallRating = overallRating
        self.latitude = latitude
        self.longitude = longitude
        self.placeMasters = placeMasters
        self.usesPlaceSuggestions = usesPlaceSuggestions
        self.usesMapSearchAssist = usesMapSearchAssist
        self.supportsPerformanceTime = supportsPerformanceTime
        self.supportsStyles = supportsStyles
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
        self.ratingText = ratingText
        self.onSelectPlace = onSelectPlace
        self.onSelectPublicPlace = onSelectPublicPlace
        self.onOpenPlaceSearch = onOpenPlaceSearch
    }

    init(
        template: CategoryRecordTemplate,
        eventTitle: String,
        eventSeriesName: String,
        visitedAt: Binding<Date>,
        endedAt: Binding<Date>,
        styleNamesText: Binding<String>,
        venueName: Binding<String>,
        venueAddress: Binding<String>,
        overallRating: Binding<Double>,
        latitude: Double,
        longitude: Double,
        placeMasters: [PlaceMaster],
        usesPlaceSuggestions: Bool,
        usesMapSearchAssist: Bool,
        supportsPerformanceTime: Bool,
        supportsStyles: Bool,
        usesExplicitTheaterLayout: Bool = false,
        ratingText: String,
        onSelectPlace: @escaping (PlaceMaster) -> Void,
        onSelectPublicPlace: @escaping (PublicPlaceSelectionDraft) -> Void,
        onOpenPlaceSearch: @escaping () -> Void
    ) {
        self.template = template
        editableTitle = nil
        editableSeriesName = nil
        existingTitle = eventTitle
        existingSeriesName = eventSeriesName
        _visitedAt = visitedAt
        _endedAt = endedAt
        _styleNamesText = styleNamesText
        _venueName = venueName
        _venueAddress = venueAddress
        _overallRating = overallRating
        self.latitude = latitude
        self.longitude = longitude
        self.placeMasters = placeMasters
        self.usesPlaceSuggestions = usesPlaceSuggestions
        self.usesMapSearchAssist = usesMapSearchAssist
        self.supportsPerformanceTime = supportsPerformanceTime
        self.supportsStyles = supportsStyles
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
        self.ratingText = ratingText
        self.onSelectPlace = onSelectPlace
        self.onSelectPublicPlace = onSelectPublicPlace
        self.onOpenPlaceSearch = onOpenPlaceSearch
    }

    var body: some View {
        Group {
            targetFields
            Divider()
            visitFields
        }
        .task { await publicPlaceStore.prepare() }
    }

    @ViewBuilder
    private var targetFields: some View {
        if usesExplicitTheaterLayout, let editableTitle, let editableSeriesName {
            VStack(alignment: .leading, spacing: 0) {
                ExplicitFormTextField(
                    title: "公演名",
                    prompt: template.titlePlaceholder,
                    text: editableTitle,
                    labelStyle: .horizontal
                )
                theaterDivider
                ExplicitFormTextField(
                    title: "シリーズ（任意）",
                    prompt: template.seriesPlaceholder,
                    text: editableSeriesName,
                    labelStyle: .horizontal
                )
            }
        } else if usesExplicitTheaterLayout {
            VStack(alignment: .leading, spacing: 0) {
                ExplicitFormControlRow(title: "公演名") {
                    Text(existingTitle.isEmpty ? "未設定" : existingTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                if !existingSeriesName.isEmpty {
                    theaterDivider
                    ExplicitFormControlRow(title: "シリーズ", isOptional: true) {
                        Text(existingSeriesName)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
        } else if let editableTitle, let editableSeriesName {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.targetSectionTitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                TextField(template.titlePlaceholder, text: editableTitle)
                TextField(template.seriesPlaceholder, text: editableSeriesName)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(existingTitle.isEmpty ? "記録" : existingTitle)
                    .font(FavorecoTypography.bodyStrong)
                if !existingSeriesName.isEmpty {
                    Text(existingSeriesName)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var visitFields: some View {
        if usesExplicitTheaterLayout {
            theaterVisitFields
        } else {
            standardVisitFields
        }
    }

    private var standardVisitFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            DatePicker(template.dateLabel, selection: $visitedAt, displayedComponents: .date)
            if supportsPerformanceTime {
                DatePicker("開演", selection: $visitedAt, displayedComponents: .hourAndMinute)
                DatePicker("終演", selection: $endedAt, in: visitedAt..., displayedComponents: .hourAndMinute)
            }
            if supportsStyles {
                VStack(alignment: .leading, spacing: 8) {
                    Text("鑑賞方法")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(theaterStyleSuggestions, id: \.self) { style in
                            let isSelected = selectedStyleNames.contains(style)
                            Button {
                                toggleStyle(style)
                            } label: {
                                HStack(spacing: 5) {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                    }
                                    Text(style)
                                        .lineLimit(1)
                                }
                                .font(FavorecoTypography.caption)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(isSelected ? Color(hex: "#8B2F45") : Color.secondary)
                        }
                    }

                    TextField("選択内容・自由入力（カンマ区切り）", text: $styleNamesText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                }
            }
            TextField(
                supportsStyles ? "会場（任意）" : template.venuePlaceholder,
                text: $venueName
            )
            placeSuggestionList
            if usesMapSearchAssist {
                TextField("住所（地図では住所を優先）", text: $venueAddress)
                    .textContentType(.fullStreetAddress)
                Button(action: onOpenPlaceSearch) {
                    FavorecoIconLabel("Apple Mapsから会場を選択", systemImage: "map")
                }
                PlaceMapPreview(
                    venueName: venueName,
                    address: venueAddress,
                    latitude: latitude,
                    longitude: longitude
                )
            }
            ratingSlider
        }
        .onChange(of: visitedAt) { oldValue, newValue in
            guard supportsPerformanceTime else { return }
            let duration = max(endedAt.timeIntervalSince(oldValue), 0)
            endedAt = newValue.addingTimeInterval(duration)
        }
    }

    private var theaterVisitFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormControlRow(title: template.dateLabel) {
                DatePicker(
                    template.dateLabel,
                    selection: $visitedAt,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .controlSize(.small)
                .fixedSize()
            }

            if supportsPerformanceTime {
                theaterDivider
                ExplicitFormControlRow(title: "開演") {
                    DatePicker(
                        "開演",
                        selection: $visitedAt,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }
                theaterDivider
                ExplicitFormControlRow(title: "終演") {
                    DatePicker(
                        "終演",
                        selection: $endedAt,
                        in: visitedAt...,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }
            }

            if supportsStyles {
                theaterDivider
                theaterStyleFields
            }

            theaterDivider
            ExplicitFormTextField(
                title: "会場（任意）",
                prompt: "会場名を入力",
                text: $venueName,
                labelStyle: .horizontal
            )

            placeSuggestionList

            if usesMapSearchAssist {
                theaterDivider
                ExplicitFormTextField(
                    title: "住所（任意）",
                    prompt: "地図では住所を優先",
                    text: $venueAddress,
                    labelStyle: .horizontal
                )
                .textContentType(.fullStreetAddress)

                Button(action: onOpenPlaceSearch) {
                    FavorecoIconLabel("Apple Mapsから会場を選択", systemImage: "map")
                        .font(
                            FavorecoTypography.jpSans(
                                ExplicitFormMetrics.inputFontSize,
                                weight: .semibold,
                                relativeTo: .body
                            )
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }

                PlaceMapPreview(
                    venueName: venueName,
                    address: venueAddress,
                    latitude: latitude,
                    longitude: longitude
                )
            }

            theaterDivider
            ExplicitFormControlRow(title: template.ratingLabel, isOptional: true) {
                HStack(spacing: 8) {
                    Slider(value: $overallRating, in: 0...5, step: 0.5)
                        .frame(width: 172)
                    Text(ratingText)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 30, alignment: .trailing)
                }
            }
        }
        .onChange(of: visitedAt) { oldValue, newValue in
            guard supportsPerformanceTime else { return }
            let duration = max(endedAt.timeIntervalSince(oldValue), 0)
            endedAt = newValue.addingTimeInterval(duration)
        }
    }

    private var theaterStyleFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("鑑賞方法")
                .font(
                    FavorecoTypography.jpSans(
                        ExplicitFormMetrics.labelFontSize,
                        weight: .semibold,
                        relativeTo: .caption
                    )
                )
                .foregroundStyle(Color.secondary.opacity(0.92))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(theaterStyleSuggestions, id: \.self) { style in
                    let isSelected = selectedStyleNames.contains(style)
                    Button {
                        toggleStyle(style)
                    } label: {
                        HStack(spacing: 5) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                            }
                            Text(style)
                                .lineLimit(1)
                        }
                        .font(FavorecoTypography.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? Color(hex: "#8B2F45") : Color.secondary)
                }
            }

            ExplicitFormTextField(
                title: "自由入力（任意）",
                prompt: "カンマ区切りで入力",
                text: $styleNamesText,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal
            )
            .textInputAutocapitalization(.never)
        }
        .padding(.vertical, 6)
    }

    private var theaterDivider: some View {
        Divider()
            .overlay(ExplicitFormMetrics.rowSeparatorColor)
    }

    @ViewBuilder
    private var placeSuggestionList: some View {
        let suggestions = usesPlaceSuggestions ? placeSuggestions : []
        let publicSuggestions = usesPlaceSuggestions ? publicCatalogSuggestions : []
        if !suggestions.isEmpty || !publicSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !suggestions.isEmpty {
                    Text("登録済みの場所")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(suggestions) { place in
                        Button {
                            onSelectPlace(place)
                        } label: {
                            HStack(spacing: 10) {
                                FavorecoIcon(systemName: "mappin.and.ellipse", size: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 7) {
                                        Text(place.name)
                                            .foregroundStyle(.primary)
                                        if place.isClosed {
                                            closedBadge
                                        }
                                    }
                                    if !place.address.isEmpty {
                                        Text(place.address)
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !publicSuggestions.isEmpty {
                    Text("全国場所カタログ")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(publicSuggestions) { entry in
                        Button {
                            onSelectPublicPlace(PublicPlaceSelectionDraft(entry: entry))
                        } label: {
                            HStack(spacing: 10) {
                                FavorecoIcon(systemName: "building.2.crop.circle", size: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 7) {
                                        Text(entry.officialName).foregroundStyle(.primary)
                                        if entry.isClosed { closedBadge }
                                    }
                                    Text(entry.address.isEmpty ? entry.prefecture : entry.address)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                FavorecoIcon(systemName: "plus.circle", size: 16)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var closedBadge: some View {
        Text("閉館")
            .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
            .foregroundStyle(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.1), in: Capsule())
    }

    private var placeSuggestions: [PlaceMaster] {
        let normalizedQuery = normalizedPlaceText(venueName)
        guard !normalizedQuery.isEmpty else { return [] }
        let matches = placeMasters
            .filter { !$0.isArchived }
            .filter { place in
                normalizedPlaceText(place.name).contains(normalizedQuery)
                    || place.normalizedName.contains(normalizedQuery)
                    || normalizedPlaceText(place.reading).contains(normalizedQuery)
                    || normalizedPlaceText(place.aliasesRaw).contains(normalizedQuery)
            }
        return deduplicatedPlaceSuggestions(matches)
            .prefix(4)
            .map { $0 }
    }

    private var publicCatalogSuggestions: [PublicPlaceCatalogEntry] {
        let importedMarkers = Set(placeMasters.map(\.sourceSnapshotRaw))
        return PublicPlaceCatalogSearch.suggestions(
            for: venueName,
            in: publicPlaceStore.entries,
            excludingSourceMarkers: importedMarkers,
            includesClosed: true
        )
    }

    private var ratingSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.ratingLabel)
                Spacer()
                Text(ratingText)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $overallRating, in: 0...5, step: 0.5)
        }
    }

    private var theaterStyleSuggestions: [String] {
        ["現地", "配信", "ライブビューイング"]
    }

    private var selectedStyleNames: [String] {
        styleNamesText
            .components(separatedBy: CharacterSet(charactersIn: ",、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggleStyle(_ style: String) {
        var values = selectedStyleNames
        if let index = values.firstIndex(of: style) {
            values.remove(at: index)
        } else {
            values.append(style)
        }
        styleNamesText = values.joined(separator: "、")
    }

    private func normalizedPlaceText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }
}

struct PlaceMapPreview: View {
    let venueName: String
    let address: String
    let latitude: Double
    let longitude: Double
    @State private var resolvedCoordinate: CLLocationCoordinate2D?

    private var explicitCoordinate: CLLocationCoordinate2D? {
        guard latitude != 0 || longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var coordinate: CLLocationCoordinate2D? {
        explicitCoordinate ?? resolvedCoordinate
    }

    private var geocodeQuery: String {
        [venueName, address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var geocodeKey: String {
        "\(venueName)|\(address)|\(latitude)|\(longitude)"
    }

    var body: some View {
        if let coordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0045, longitudeDelta: 0.0045)
            ))) {
                Marker(venueName.isEmpty ? address : venueName, coordinate: coordinate)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("\(venueName.isEmpty ? address : venueName)の地図")
        } else if !geocodeQuery.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                ProgressView("地図を確認中")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
        }
        EmptyView()
            .task(id: geocodeKey) {
                guard explicitCoordinate == nil else {
                    resolvedCoordinate = nil
                    return
                }
                let query = geocodeQuery
                guard !query.isEmpty else {
                    resolvedCoordinate = nil
                    return
                }
                let candidate = try? await PlaceSearchService.search(query: query).first
                guard !Task.isCancelled else { return }
                resolvedCoordinate = candidate.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
            }
    }
}

struct ExperiencePlaceSearchView: View {
    let initialQuery: String
    let onSelect: (PlaceSearchCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [PlaceSearchCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage = ""

    init(initialQuery: String, onSelect: @escaping (PlaceSearchCandidate) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("検索中")
                } else if !errorMessage.isEmpty {
                    FavorecoContentUnavailableView(
                        "検索できませんでした",
                        systemImage: "wifi.exclamationmark",
                        description: errorMessage
                    )
                } else if results.isEmpty {
                    FavorecoContentUnavailableView(
                        "会場を検索",
                        systemImage: "map",
                        description: "会場名や住所を入力してください"
                    )
                } else {
                    List(results) { candidate in
                        Button {
                            onSelect(candidate)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.name)
                                    .font(FavorecoTypography.bodyStrong)
                                    .foregroundStyle(.primary)
                                if !candidate.address.isEmpty {
                                    Text(candidate.address)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("会場を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "会場名・住所")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                guard !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                await search()
            }
        }
    }

    @MainActor
    private func search() async {
        isSearching = true
        errorMessage = ""
        defer { isSearching = false }
        do {
            results = try await PlaceSearchService.search(query: query)
        } catch {
            results = []
            errorMessage = "通信状態を確認して、もう一度お試しください。"
        }
    }
}
