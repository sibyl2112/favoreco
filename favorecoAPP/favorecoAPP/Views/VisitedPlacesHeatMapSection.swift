import SwiftUI
import MapKit

struct VisitedPlacesHeatMapSection: View {
    let visits: [Visit]
    let category: RecordCategory
    let tint: Color

    @State private var selectedArea: JapanVisitArea = .nationwide
    @State private var searchText = ""
    @State private var selectedPrefecture = ""
    @State private var isShowingDetailedSearch = false
    @State private var cameraPosition: MapCameraPosition = .region(JapanVisitArea.nationwide.region)
    @State private var selectedPointID: String?
    @State private var mapDestination: FavorecoMapDestination?
    @State private var selectedHistoryPointID: String?

    private var allPoints: [VisitedPlaceHeatPoint] {
        VisitedPlaceHeatPoint.make(from: visits)
    }

    private var filteredPoints: [VisitedPlaceHeatPoint] {
        allPoints.filter { point in
            selectedArea.includes(prefecture: point.prefecture)
                && (selectedPrefecture.isEmpty || point.prefecture == selectedPrefecture)
                && (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || point.searchableText.localizedCaseInsensitiveContains(
                        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
        }
    }

    private var missingCoordinateCount: Int {
        visits.count - visits.filter(\.hasUsableMapCoordinate).count
    }

    private var activeDetailedFilterCount: Int {
        (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            + (selectedPrefecture.isEmpty ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    LayeredCategorySectionTitle(
                        englishTitle: englishSectionTitle,
                        japaneseTitle: sectionTitle,
                        foregroundColor: .primary
                    )
                    Text("色が濃いほど訪問回数が多い場所")
                        .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Button {
                    isShowingDetailedSearch = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                        Text("詳細検索")
                        if activeDetailedFilterCount > 0 {
                            Text("\(activeDetailedFilterCount)")
                                .font(FavorecoTypography.jpSans(9, weight: .bold, relativeTo: .caption2))
                                .foregroundStyle(.white)
                                .frame(width: 17, height: 17)
                                .background(tint, in: Circle())
                        }
                    }
                    .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
            }

            areaFilter

            map

            HStack(spacing: 8) {
                FavorecoIconLabel("\(filteredPoints.count)か所", systemImage: "mappin.and.ellipse")
                Text("\(filteredPoints.reduce(0) { $0 + $1.visitCount })回")
                if missingCoordinateCount > 0 {
                    Text("位置未設定 \(missingCoordinateCount)件")
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)

            if category.templateKey == "museum", !allPoints.isEmpty {
                museumRanking
            }
        }
        .sheet(isPresented: $isShowingDetailedSearch) {
            VisitedPlacesDetailedSearchSheet(
                searchText: $searchText,
                selectedPrefecture: $selectedPrefecture,
                availablePrefectures: Array(Set(allPoints.compactMap { point in
                    point.prefecture.isEmpty ? nil : point.prefecture
                })).sorted(),
                tint: tint
            )
        }
        .onChange(of: selectedArea) { _, area in
            selectedPrefecture = ""
            selectedPointID = nil
            cameraPosition = .region(area.region)
        }
        .onChange(of: searchText) { _, _ in focusFilteredPoints() }
        .onChange(of: selectedPrefecture) { _, _ in focusFilteredPoints() }
        .onChange(of: filteredPoints.map(\.id)) { _, _ in focusFilteredPoints() }
        .sheet(isPresented: Binding(
            get: { selectedHistoryPointID != nil },
            set: { if !$0 { selectedHistoryPointID = nil } }
        )) {
            if let point = allPoints.first(where: { $0.id == selectedHistoryPointID }) {
                MuseumPlaceHistoryView(
                    placeName: point.name,
                    visits: visits
                        .filter { point.visitIDs.contains($0.id) }
                        .sorted { $0.visitedAt > $1.visitedAt },
                    tint: tint
                )
            }
        }
    }

    private var sectionTitle: String {
        switch category.templateKey {
        case "museum": return "ミュージアムMAP"
        case "live": return "ライブ会場"
        case "theme_park": return "行ったパークMAP"
        case "nature_living": return "訪れた自然・いきものMAP"
        case "outing_facility": return "その他・未分類施設MAP"
        default: return "行った場所MAP"
        }
    }

    private var englishSectionTitle: String {
        switch category.templateKey {
        case "museum": return "Museum Map"
        case "live": return "Venue Map"
        case "theme_park": return "Park Map"
        case "nature_living": return "Nature Map"
        case "outing_facility": return "Places Map"
        default: return "Places Map"
        }
    }

    private var areaFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(JapanVisitArea.allCases) { area in
                    Button {
                        selectedArea = area
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: selectedArea == area ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14, weight: .medium))
                            Text(area.title)
                                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                        }
                        .foregroundStyle(selectedArea == area ? tint : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 30)
        .accessibilityLabel("エリアで絞り込む")
    }

    private var museumRanking: some View {
        VStack(alignment: .leading, spacing: 10) {
            LayeredCategorySectionTitle(
                englishTitle: "Museum Ranking",
                japaneseTitle: "よく行くミュージアム",
                foregroundColor: .primary
            )

            VStack(spacing: 0) {
                ForEach(Array(allPoints.prefix(10).enumerated()), id: \.element.id) { index, point in
                    Button {
                        selectedHistoryPointID = point.id
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(FavorecoTypography.jpSerif(19, weight: .semibold, relativeTo: .headline))
                                .foregroundStyle(tint)
                                .frame(width: 26)
                            Text(point.name)
                                .font(FavorecoTypography.bodyStrong)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(point.visitCount)回")
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < min(allPoints.count, 10) - 1 {
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var map: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            ForEach(filteredPoints) { point in
                Annotation(point.name, coordinate: point.coordinate, anchor: .center) {
                    Button {
                        focus(on: point)
                        mapDestination = FavorecoMapDestination(
                            name: point.name,
                            address: "",
                            latitude: point.coordinate.latitude,
                            longitude: point.coordinate.longitude
                        )
                    } label: {
                        VisitedPlaceHeatMarker(
                            visitCount: point.visitCount,
                            maximumVisitCount: allPoints.map(\.visitCount).max() ?? 1,
                            tint: tint,
                            isSelected: selectedPointID == point.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.name)、\(point.visitCount)回")
                    .accessibilityHint("地図の中央に表示して外部地図を選べます")
                }
            }
        }
        .favorecoEmbeddedMapInteraction()
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 0.75)

            if filteredPoints.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.94))
                    .overlay {
                        VStack(spacing: 8) {
                            FavorecoIcon(systemName: "map", size: 22)
                            Text(allPoints.isEmpty ? "位置を登録するとMAPに表示されます" : "条件に合う場所がありません")
                                .font(FavorecoTypography.captionStrong)
                            if allPoints.isEmpty {
                                Text("記録の場所をApple Mapsから選ぶか、住所と座標を登録してください。")
                                    .font(FavorecoTypography.caption)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(24)
                    }
            }
        }
        .favorecoMapDestinationDialog(destination: $mapDestination)
    }

    private func focusFilteredPoints() {
        selectedPointID = nil
        guard !filteredPoints.isEmpty else {
            cameraPosition = .region(selectedArea.region)
            return
        }
        cameraPosition = .region(VisitedPlaceHeatPoint.region(for: filteredPoints))
    }

    private func focus(on point: VisitedPlaceHeatPoint) {
        selectedPointID = point.id
        let region = FavorecoMapViewport.singlePointRegion(center: point.coordinate)
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(region)
        }
    }
}

private struct VisitedPlaceHeatMarker: View {
    let visitCount: Int
    let maximumVisitCount: Int
    let tint: Color
    let isSelected: Bool

    private var strength: Double {
        guard maximumVisitCount > 1 else { return 0.55 }
        return 0.30 + (Double(visitCount - 1) / Double(maximumVisitCount - 1)) * 0.70
    }

    private var diameter: CGFloat {
        24 + CGFloat(strength) * 24
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(tint, lineWidth: 3)
                    .frame(width: diameter + 10, height: diameter + 10)
                    .shadow(color: tint.opacity(0.35), radius: 4)
            }

            Circle()
                .fill(tint.opacity(0.15 + strength * 0.18))
                .frame(width: diameter * 1.65, height: diameter * 1.65)
                .blur(radius: 7)

            Circle()
                .fill(tint.opacity(0.35 + strength * 0.55))
                .frame(width: diameter, height: diameter)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.82), lineWidth: 1.5)
                }

            Text("\(visitCount)")
                .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

private struct VisitedPlacesDetailedSearchSheet: View {
    @Binding var searchText: String
    @Binding var selectedPrefecture: String
    let availablePrefectures: [String]
    let tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var draftSearchText: String
    @State private var draftPrefecture: String

    init(
        searchText: Binding<String>,
        selectedPrefecture: Binding<String>,
        availablePrefectures: [String],
        tint: Color
    ) {
        _searchText = searchText
        _selectedPrefecture = selectedPrefecture
        self.availablePrefectures = availablePrefectures
        self.tint = tint
        _draftSearchText = State(initialValue: searchText.wrappedValue)
        _draftPrefecture = State(initialValue: selectedPrefecture.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("自由ワード") {
                    TextField("施設名・会場名・住所・メモなど", text: $draftSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("都道府県") {
                    Picker("都道府県", selection: $draftPrefecture) {
                        Text("すべての都道府県").tag("")
                        ForEach(prefectureOptions, id: \.self) { prefecture in
                            Text(prefecture).tag(prefecture)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Button("条件をクリア") {
                        draftSearchText = ""
                        draftPrefecture = ""
                    }
                    .foregroundStyle(tint)
                }
            }
            .navigationTitle("MAPを詳細検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        searchText = draftSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        selectedPrefecture = draftPrefecture
                        dismiss()
                    }
                    .foregroundStyle(tint)
                }
            }
        }
    }

    private var prefectureOptions: [String] {
        availablePrefectures.isEmpty
            ? JapanPrefecture.all
            : availablePrefectures
    }
}

private struct VisitedPlaceHeatPoint: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let visitCount: Int
    let prefecture: String
    let searchableText: String
    let visitIDs: Set<UUID>

    static func make(from visits: [Visit]) -> [VisitedPlaceHeatPoint] {
        let locatedVisits = visits.compactMap { visit -> LocatedVisit? in
            guard let coordinate = visit.mapCoordinate else { return nil }
            let venueName = visit.venueNameSnapshot.isEmpty
                ? (visit.placeMaster?.name ?? visit.event?.title ?? "場所")
                : visit.venueNameSnapshot
            let address = visit.placeMaster?.address ?? ""
            let savedPrefecture = visit.placeMaster?.prefecture ?? ""
            let prefecture = savedPrefecture.isEmpty ? JapanPrefecture.extract(from: address) : savedPrefecture
            let key: String
            if let placeID = visit.placeMaster?.id {
                key = "place-\(placeID.uuidString)"
            } else {
                key = String(format: "coordinate-%.4f-%.4f-%@", coordinate.latitude, coordinate.longitude, venueName)
            }
            return LocatedVisit(
                key: key,
                name: venueName,
                coordinate: coordinate,
                prefecture: prefecture,
                searchableText: [
                    visit.event?.title ?? "",
                    visit.event?.seriesName ?? "",
                    venueName,
                    address,
                    visit.placeMaster?.placeTagsRaw ?? "",
                    visit.tagNamesRaw,
                    visit.note,
                ].joined(separator: " "),
                visitID: visit.id
            )
        }

        return Dictionary(grouping: locatedVisits, by: \.key)
            .map { key, grouped in
                let first = grouped[0]
                return VisitedPlaceHeatPoint(
                    id: key,
                    name: first.name,
                    coordinate: first.coordinate,
                    visitCount: grouped.count,
                    prefecture: grouped.compactMap { $0.prefecture.isEmpty ? nil : $0.prefecture }.first ?? "",
                    searchableText: grouped.map(\.searchableText).joined(separator: " "),
                    visitIDs: Set(grouped.map(\.visitID))
                )
            }
            .sorted {
                if $0.visitCount != $1.visitCount { return $0.visitCount > $1.visitCount }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    static func region(for points: [VisitedPlaceHeatPoint]) -> MKCoordinateRegion {
        guard !points.isEmpty else { return JapanVisitArea.nationwide.region }
        if let point = points.first, points.count == 1 {
            return FavorecoMapViewport.singlePointRegion(center: point.coordinate)
        }
        let latitudes = points.map { $0.coordinate.latitude }
        let longitudes = points.map { $0.coordinate.longitude }
        let minimumLatitude = latitudes.min() ?? 36.2
        let maximumLatitude = latitudes.max() ?? 36.2
        let minimumLongitude = longitudes.min() ?? 138.2
        let maximumLongitude = longitudes.max() ?? 138.2
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.35, (maximumLatitude - minimumLatitude) * 1.65),
                longitudeDelta: max(0.35, (maximumLongitude - minimumLongitude) * 1.65)
            )
        )
    }

    private struct LocatedVisit {
        let key: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let prefecture: String
        let searchableText: String
        let visitID: UUID
    }
}

private struct MuseumPlaceHistoryView: View {
    let placeName: String
    let visits: [Visit]
    let tint: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(visits) { visit in
                NavigationLink {
                    ExperienceDetailView(visit: visit)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? placeName : placeName)
                            .font(FavorecoTypography.bodyStrong)
                        HStack(spacing: 8) {
                            FavorecoIconLabel(
                                FavorecoDateText.compactDate(visit.visitedAt),
                                systemImage: "calendar",
                                iconSize: 13
                            )
                            if visit.overallRating > 0 {
                                FavorecoIconLabel(
                                    String(format: "%.1f", visit.overallRating),
                                    systemImage: "star.fill",
                                    iconSize: 13
                                )
                                .foregroundStyle(.yellow)
                            }
                        }
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(placeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(tint)
                }
            }
        }
    }
}

private enum JapanVisitArea: String, CaseIterable, Identifiable {
    case nationwide
    case hokkaido
    case tohoku
    case kanto
    case chubu
    case kinki
    case chugoku
    case shikoku
    case kyushuOkinawa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nationwide: "全国"
        case .hokkaido: "北海道"
        case .tohoku: "東北"
        case .kanto: "関東"
        case .chubu: "中部"
        case .kinki: "近畿"
        case .chugoku: "中国"
        case .shikoku: "四国"
        case .kyushuOkinawa: "九州・沖縄"
        }
    }

    var prefectures: Set<String> {
        switch self {
        case .nationwide: Set(JapanPrefecture.all)
        case .hokkaido: Set(JapanArea.hokkaido.prefectures)
        case .tohoku: Set(JapanArea.tohoku.prefectures)
        case .kanto: Set(JapanArea.kanto.prefectures)
        case .chubu: Set(JapanArea.chubu.prefectures)
        case .kinki: Set(JapanArea.kinki.prefectures)
        case .chugoku: Set(JapanArea.chugoku.prefectures)
        case .shikoku: Set(JapanArea.shikoku.prefectures)
        case .kyushuOkinawa: Set(JapanArea.kyushuOkinawa.prefectures)
        }
    }

    var region: MKCoordinateRegion {
        switch self {
        case .nationwide: Self.mapRegion(latitude: 36.2, longitude: 138.0, latitudeDelta: 19.0, longitudeDelta: 20.0)
        case .hokkaido: Self.mapRegion(latitude: 43.3, longitude: 142.7, latitudeDelta: 5.6, longitudeDelta: 7.8)
        case .tohoku: Self.mapRegion(latitude: 39.0, longitude: 140.7, latitudeDelta: 5.2, longitudeDelta: 5.0)
        case .kanto: Self.mapRegion(latitude: 35.8, longitude: 139.2, latitudeDelta: 3.0, longitudeDelta: 3.8)
        case .chubu: Self.mapRegion(latitude: 36.2, longitude: 137.2, latitudeDelta: 4.4, longitudeDelta: 5.4)
        case .kinki: Self.mapRegion(latitude: 34.7, longitude: 135.3, latitudeDelta: 3.0, longitudeDelta: 4.2)
        case .chugoku: Self.mapRegion(latitude: 34.6, longitude: 132.8, latitudeDelta: 2.8, longitudeDelta: 5.0)
        case .shikoku: Self.mapRegion(latitude: 33.7, longitude: 133.5, latitudeDelta: 2.3, longitudeDelta: 3.8)
        case .kyushuOkinawa: Self.mapRegion(latitude: 29.8, longitude: 130.2, latitudeDelta: 10.8, longitudeDelta: 8.5)
        }
    }

    func includes(prefecture: String) -> Bool {
        self == .nationwide || prefectures.contains(prefecture)
    }

    private static func mapRegion(
        latitude: Double,
        longitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private extension Visit {
    var mapCoordinate: CLLocationCoordinate2D? {
        if latitude != 0 || longitude != 0 {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        guard let placeMaster,
              placeMaster.latitude != 0 || placeMaster.longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: placeMaster.latitude, longitude: placeMaster.longitude)
    }

    var hasUsableMapCoordinate: Bool {
        mapCoordinate != nil
    }
}
