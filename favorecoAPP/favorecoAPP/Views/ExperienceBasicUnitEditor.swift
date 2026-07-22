import MapKit
import SwiftUI

struct ExperienceBasicUnitEditor: View {
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
    let ratingText: String
    let onSelectPlace: (PlaceMaster) -> Void
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
        ratingText: String,
        onSelectPlace: @escaping (PlaceMaster) -> Void,
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
        self.ratingText = ratingText
        self.onSelectPlace = onSelectPlace
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
        ratingText: String,
        onSelectPlace: @escaping (PlaceMaster) -> Void,
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
        self.ratingText = ratingText
        self.onSelectPlace = onSelectPlace
        self.onOpenPlaceSearch = onOpenPlaceSearch
    }

    var body: some View {
        targetFields
        Divider()
        visitFields
    }

    @ViewBuilder
    private var targetFields: some View {
        if let editableTitle, let editableSeriesName {
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

    private var visitFields: some View {
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
                    Text("スタイル")
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
            TextField(template.venuePlaceholder, text: $venueName)
            placeSuggestionList
            if usesMapSearchAssist {
                TextField("住所（地図では住所を優先）", text: $venueAddress)
                    .textContentType(.fullStreetAddress)
                Button(action: onOpenPlaceSearch) {
                    Label("Apple Mapsから会場を選択", systemImage: "map")
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

    @ViewBuilder
    private var placeSuggestionList: some View {
        let suggestions = usesPlaceSuggestions ? placeSuggestions : []
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("登録済みの場所")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                ForEach(suggestions) { place in
                    Button {
                        onSelectPlace(place)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 7) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)
                                    if place.isClosed {
                                        Text("閉館")
                                            .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.1), in: Capsule())
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
        }
    }

    private var placeSuggestions: [PlaceMaster] {
        let normalizedQuery = normalizedPlaceText(venueName)
        guard !normalizedQuery.isEmpty else { return [] }
        return placeMasters
            .filter { !$0.isArchived }
            .filter { place in
                normalizedPlaceText(place.name).contains(normalizedQuery)
                    || place.normalizedName.contains(normalizedQuery)
                    || normalizedPlaceText(place.reading).contains(normalizedQuery)
                    || normalizedPlaceText(place.aliasesRaw).contains(normalizedQuery)
            }
            .prefix(4)
            .map { $0 }
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
        [
            "ミュージカル", "宝塚歌劇団", "劇団四季", "2.5次元",
            "ストレートプレイ", "イマーシブ演劇", "大衆演劇",
            "歌舞伎・伝統芸能", "ダンス・バレエ", "ディナーショー",
            "ファンミーティング", "ライブ", "朗読劇",
            "STARTO ENTERTAINMENT", "その他",
        ]
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

    private var geocodeKey: String {
        "\(address)|\(latitude)|\(longitude)"
    }

    var body: some View {
        if let coordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))) {
                Marker(venueName.isEmpty ? address : venueName, coordinate: coordinate)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("\(venueName.isEmpty ? address : venueName)の地図")
        }
        EmptyView()
            .task(id: geocodeKey) {
                guard explicitCoordinate == nil else {
                    resolvedCoordinate = nil
                    return
                }
                let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    resolvedCoordinate = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                let placemarks = try? await CLGeocoder().geocodeAddressString(query)
                guard !Task.isCancelled else { return }
                resolvedCoordinate = placemarks?.first?.location?.coordinate
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
                    ContentUnavailableView(
                        "検索できませんでした",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "会場を検索",
                        systemImage: "map",
                        description: Text("会場名や住所を入力してください")
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
