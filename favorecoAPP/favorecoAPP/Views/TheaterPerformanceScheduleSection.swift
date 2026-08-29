import SwiftUI
import SwiftData
import MapKit

struct TheaterPerformanceScheduleSection: View {
    let schedules: [TheaterPerformanceScheduleItem]
    let accentColor: Color

    @State private var showsAll = false
    @State private var expandedItemIDs: Set<String> = []

    private var visibleSchedules: [TheaterPerformanceScheduleItem] {
        showsAll
            ? schedules
            : EventDetailPresentation.prioritizedTheaterSchedules(schedules)
    }

    var body: some View {
        if !schedules.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    TheaterEventSectionIcon(systemName: "calendar", tint: accentColor)
                    Text("公演スケジュール")
                        .font(FavorecoTypography.jpSerif(18, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
                    Spacer(minLength: 8)
                    Text("全\(schedules.count)公演地")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                ForEach(visibleSchedules) { schedule in
                    scheduleCard(schedule)
                }

                if schedules.count > 2 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showsAll.toggle()
                            if !showsAll { expandedItemIDs.removeAll() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showsAll ? "閉じる" : "ほか\(schedules.count - visibleSchedules.count)公演地を見る")
                            Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showsAll ? "公演地を2件の表示に戻します" : "すべての公演地を表示します")
                }
            }
        }
    }

    private func scheduleCard(_ schedule: TheaterPerformanceScheduleItem) -> some View {
        let isExpanded = expandedItemIDs.contains(schedule.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                if isExpanded {
                    expandedItemIDs.remove(schedule.id)
                } else {
                    expandedItemIDs.insert(schedule.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(schedule.performanceLabel.isEmpty ? "公演情報" : schedule.performanceLabel)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)
                    Spacer(minLength: 8)
                    Text(periodText(schedule))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                FavorecoIconLabel(schedule.venueName, systemImage: "mappin.and.ellipse")
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)

                if isExpanded, !schedule.address.isEmpty {
                    Text(schedule.address)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.leading, 27)
                        .transition(.opacity)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .theaterEventCard(accentColor: accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(schedule.performanceLabel)、\(periodText(schedule))、\(schedule.venueName)")
        .accessibilityHint(isExpanded ? "住所を閉じます" : "住所を表示します")
    }

    private func periodText(_ schedule: TheaterPerformanceScheduleItem) -> String {
        guard let start = schedule.startsAt else { return "会期未登録" }
        guard let end = schedule.endsAt,
              !Calendar.current.isDate(start, inSameDayAs: end) else {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(start)
        }
        return "\(FavorecoDateText.compactDate(start))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
    }
}

struct TheaterScheduleEntryEditor: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \PlaceMaster.name) private var savedPlaces: [PlaceMaster]
    @StateObject private var publicPlaceStore = PublicPlaceCatalogStore.shared
    @Binding var entry: EventVenueEntry
    let fallbackStart: Date
    let fallbackEnd: Date
    var usesFlatLayout = false

    @State private var venueSuggestions: [PlaceSearchCandidate] = []
    @State private var selectedVenueCandidate: PlaceSearchCandidate?
    @State private var isSearchingVenues = false
    @State private var isShowingPreciseLocation = false

    private var selectedVenueCoordinate: PlaceSearchCandidate? {
        if entry.hasCoordinate, let latitude = entry.latitude, let longitude = entry.longitude {
            return PlaceSearchCandidate(
                id: "saved-coordinate-\(entry.id.uuidString)",
                name: entry.trimmedName,
                address: entry.trimmedAddress,
                latitude: latitude,
                longitude: longitude,
                source: .manualPin
            )
        }
        guard let candidate = selectedVenueCandidate,
              candidate.name.trimmingCharacters(in: .whitespacesAndNewlines) == entry.trimmedName,
              candidate.address.trimmingCharacters(in: .whitespacesAndNewlines) == entry.trimmedAddress else {
            return nil
        }
        return candidate
    }

    private var hasPeriod: Binding<Bool> {
        Binding(
            get: { entry.startsAt != nil || entry.endsAt != nil },
            set: { enabled in
                if enabled {
                    let start = entry.startsAt ?? fallbackStart
                    entry.startsAt = start
                    entry.endsAt = max(entry.endsAt ?? fallbackEnd, start)
                } else {
                    entry.startsAt = nil
                    entry.endsAt = nil
                }
            }
        )
    }

    private var performanceLabel: Binding<String> {
        Binding(
            get: { entry.performanceLabel ?? "" },
            set: { entry.performanceLabel = $0 }
        )
    }

    private var startsAt: Binding<Date> {
        Binding(
            get: { entry.startsAt ?? fallbackStart },
            set: { newValue in
                entry.startsAt = newValue
                if let end = entry.endsAt, end < newValue { entry.endsAt = newValue }
            }
        )
    }

    private var endsAt: Binding<Date> {
        Binding(
            get: { max(entry.endsAt ?? fallbackEnd, entry.startsAt ?? fallbackStart) },
            set: { entry.endsAt = $0 }
        )
    }

    @ViewBuilder
    var body: some View {
        Group {
            if usesFlatLayout {
                flatEditor
            } else {
                legacyEditor
            }
        }
        .sheet(isPresented: $isShowingPreciseLocation) {
            VenuePreciseLocationSheet(
                venueName: entry.trimmedName,
                address: entry.trimmedAddress,
                latitude: entry.latitude,
                longitude: entry.longitude,
                externalMapURL: entry.externalMapURL ?? ""
            ) { name, latitude, longitude, externalMapURL in
                if !name.isEmpty { entry.name = name }
                entry.latitude = latitude
                entry.longitude = longitude
                entry.externalMapURL = externalMapURL.isEmpty ? nil : externalMapURL
                selectedVenueCandidate = PlaceSearchCandidate(
                    id: "precise-\(entry.id.uuidString)",
                    name: entry.trimmedName,
                    address: entry.trimmedAddress,
                    latitude: latitude ?? 0,
                    longitude: longitude ?? 0,
                    source: .manualPin
                )
                venueSuggestions = []
            }
        }
    }

    private var legacyEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormTextField(
                title: "公演地名（任意）",
                prompt: "例：東京公演",
                text: performanceLabel,
                labelStyle: .horizontal
            )
            scheduleDivider
            ExplicitFormTextField(
                title: "会場",
                prompt: "例：東京ドーム",
                text: venueName,
                labelStyle: .horizontal
            )
            if !venueSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(venueSuggestions.prefix(5)) { candidate in
                        Button {
                            applyVenueCandidate(candidate)
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                FavorecoIcon(
                                    systemName: "mappin.and.ellipse",
                                    size: 15,
                                    fallbackWeight: .medium
                                )
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 20, height: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(
                                            FavorecoTypography.jpSans(
                                                13,
                                                weight: .semibold,
                                                relativeTo: .body
                                            )
                                        )
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if !candidate.address.isEmpty {
                                        Text(candidate.address)
                                            .font(
                                                FavorecoTypography.jpSans(
                                                    11,
                                                    weight: .regular,
                                                    relativeTo: .caption
                                                )
                                            )
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if candidate.id != venueSuggestions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 45)
                        }
                    }
                }
                .background(Color.secondary.opacity(0.06))
            }
            scheduleDivider
            ExplicitFormTextField(
                title: "住所",
                prompt: "例：東京都文京区後楽1丁目（任意）",
                text: venueAddress,
                labelStyle: .horizontal
            )
            preciseLocationButton
            scheduleDivider
            ExplicitFormControlRow(title: "会期") {
                Toggle("この公演地の会期を登録", isOn: hasPeriod)
                    .labelsHidden()
                    .tint(themePalette.prominentAction)
                    .accessibilityLabel("この公演地の会期を登録")
            }

            if hasPeriod.wrappedValue {
                scheduleDivider
                ExplicitFormControlRow(title: "開始日") {
                    DatePicker("開始日", selection: startsAt, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(
                            ExplicitFormMetrics.dateControlScale,
                            anchor: .trailing
                        )
                }
                scheduleDivider
                ExplicitFormControlRow(title: "終了日") {
                    DatePicker(
                        "終了日",
                        selection: endsAt,
                        in: startsAt.wrappedValue...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .scaleEffect(
                        ExplicitFormMetrics.dateControlScale,
                        anchor: .trailing
                    )
                }
            }

            if !entry.trimmedName.isEmpty, !entry.trimmedAddress.isEmpty {
                scheduleDivider
                VStack(alignment: .leading, spacing: 7) {
                    ExplicitFormFieldTitle(
                        title: "会場マップ",
                        isOptional: false,
                        isRequired: false
                    )

                    PlaceMapPreview(
                        venueName: entry.trimmedName,
                        address: entry.trimmedAddress,
                        latitude: selectedVenueCoordinate?.latitude ?? 0,
                        longitude: selectedVenueCoordinate?.longitude ?? 0
                    )
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 1)
        .task(id: venueSearchTaskID) {
            await refreshVenueSuggestions()
        }
        .task { await publicPlaceStore.prepare() }
    }

    private var flatEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            flatTextField("公演地名", prompt: "例：東京公演", text: performanceLabel, isOptional: true)
            flatTextField("会場", prompt: "例：月明かりホール", text: venueName)
            if isSearchingVenues {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("登録済み場所・全国カタログ・Apple Mapsを検索中")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !venueSuggestions.isEmpty {
                flatVenueSuggestions
            }
            flatTextField("住所", prompt: "住所からも候補を検索できます", text: venueAddress, isOptional: true)
            preciseLocationButton

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    Text("公演期間")
                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                    Spacer(minLength: 8)
                    Toggle("", isOn: hasPeriod)
                        .labelsHidden()
                        .tint(Color(hex: "#8B2F45"))
                }
                if hasPeriod.wrappedValue {
                    HStack(alignment: .top, spacing: 12) {
                        flatDateField("開始日", selection: startsAt)
                        flatDateField("終了日", selection: endsAt, range: startsAt.wrappedValue...)
                    }
                } else {
                    Text("未定の場合はオフのまま保存できます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !entry.trimmedName.isEmpty, !entry.trimmedAddress.isEmpty {
                PlaceMapPreview(
                    venueName: entry.trimmedName,
                    address: entry.trimmedAddress,
                    latitude: selectedVenueCoordinate?.latitude ?? 0,
                    longitude: selectedVenueCoordinate?.longitude ?? 0
                )
            }
        }
        .padding(14)
        .background(
            TheaterLifecycleFlatStyle.fieldBackground,
            in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )
        .task(id: venueSearchTaskID) {
            await refreshVenueSuggestions()
        }
        .task { await publicPlaceStore.prepare() }
    }

    private func flatTextField(
        _ title: String,
        prompt: String,
        text: Binding<String>,
        isOptional: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                if isOptional {
                    Text("任意")
                        .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption2))
                        .foregroundStyle(.secondary)
                }
            }
            TextField(prompt, text: text, axis: .vertical)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .lineLimit(1...2)
                .padding(.horizontal, 14)
                .frame(minHeight: 54)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private func flatDateField(
        _ title: String,
        selection: Binding<Date>,
        range: PartialRangeFrom<Date>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
            Group {
                if let range {
                    DatePicker("", selection: selection, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: selection, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(
                TheaterLifecycleFlatStyle.fieldBackground,
                in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var flatVenueSuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(venueSuggestions.prefix(5)) { candidate in
                Button {
                    applyVenueCandidate(candidate)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(candidate.name)
                                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(.primary)
                            Text(candidate.source.rawValue)
                                .font(FavorecoTypography.jpSans(9, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(.secondary)
                        }
                        if !candidate.address.isEmpty {
                            Text(candidate.address)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    @MainActor
    private func refreshVenueSuggestions() async {
        let name = entry.trimmedName
        let address = entry.trimmedAddress
        let query = name.isEmpty ? address : name
        guard query.count >= 2,
              name != selectedVenueCandidate?.name || address != selectedVenueCandidate?.address else {
            venueSuggestions = []
            return
        }

        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, name == entry.trimmedName, address == entry.trimmedAddress else { return }

        isSearchingVenues = true
        defer { isSearchingVenues = false }
        do {
            let local = localVenueCandidates(query: query)
            let remote = try await PlaceSearchService.search(
                queries: [
                    [name, address].filter { !$0.isEmpty }.joined(separator: " "),
                    name,
                    address,
                ]
            )
            venueSuggestions = mergedVenueCandidates(local + remote, limit: 8)
        } catch {
            venueSuggestions = localVenueCandidates(query: query)
        }
    }

    private var venueSearchTaskID: String {
        "\(entry.name)|\(entry.address)|\(savedPlaces.count)|\(publicPlaceStore.entries.count)"
    }

    private func localVenueCandidates(query: String) -> [PlaceSearchCandidate] {
        let normalizedQuery = PlaceSearchService.normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return [] }

        let saved = savedPlaces.compactMap { place -> PlaceSearchCandidate? in
            guard !place.isArchived else { return nil }
            let values = [place.name, place.reading, place.aliasesRaw, place.address]
                .map(PlaceSearchService.normalizedSearchText)
                .filter { !$0.isEmpty }
            guard values.contains(where: { $0.contains(normalizedQuery) || normalizedQuery.contains($0) }) else {
                return nil
            }
            return PlaceSearchCandidate(
                id: "saved-\(place.id.uuidString)",
                name: place.name,
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude,
                source: .registered
            )
        }

        let catalog = PublicPlaceCatalogSearch.suggestions(
            for: query,
            in: publicPlaceStore.entries,
            includesClosed: false,
            limit: 8
        ).map { place in
            PlaceSearchCandidate(
                id: "catalog-\(place.id)",
                name: place.officialName,
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude,
                source: .publicCatalog
            )
        }
        return mergedVenueCandidates(saved + catalog, limit: 8)
    }

    private func mergedVenueCandidates(
        _ candidates: [PlaceSearchCandidate],
        limit: Int
    ) -> [PlaceSearchCandidate] {
        var seen = Set<String>()
        return candidates.filter {
            seen.insert(PlaceSearchService.candidateDeduplicationKey($0)).inserted
        }.prefix(limit).map { $0 }
    }

    private func applyVenueCandidate(_ candidate: PlaceSearchCandidate) {
        entry.name = candidate.name
        entry.address = candidate.address
        entry.latitude = candidate.latitude == 0 && candidate.longitude == 0 ? nil : candidate.latitude
        entry.longitude = candidate.latitude == 0 && candidate.longitude == 0 ? nil : candidate.longitude
        entry.externalMapURL = nil
        selectedVenueCandidate = candidate
        venueSuggestions = []
    }

    private var venueName: Binding<String> {
        Binding(
            get: { entry.name },
            set: { newValue in
                if newValue != entry.name { clearSavedLocation() }
                entry.name = newValue
            }
        )
    }

    private var venueAddress: Binding<String> {
        Binding(
            get: { entry.address },
            set: { newValue in
                if newValue != entry.address { clearSavedLocation() }
                entry.address = newValue
            }
        )
    }

    private func clearSavedLocation() {
        entry.latitude = nil
        entry.longitude = nil
        entry.externalMapURL = nil
        selectedVenueCandidate = nil
    }

    private var preciseLocationButton: some View {
        Button {
            isShowingPreciseLocation = true
        } label: {
            HStack(spacing: 9) {
                FavorecoIcon(
                    systemName: entry.hasCoordinate ? "mappin.and.ellipse" : "map",
                    size: 16,
                    fallbackWeight: .medium
                )
                Text("正確な場所を設定")
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                Spacer(minLength: 8)
                if entry.hasCoordinate {
                    Text("位置設定済み")
                        .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color(hex: "#8B2F45"))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("地図の共有URLを取り込むか、地図をタップして位置を指定します")
    }

    private var scheduleDivider: some View {
        Rectangle()
            .fill(ExplicitFormMetrics.rowSeparatorColor)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct VenuePreciseLocationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let address: String
    let onSave: (String, Double?, Double?, String) -> Void

    @State private var venueName: String
    @State private var sharedURL: String
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition
    @State private var isLoadingLink = false
    @State private var linkMessage = ""

    init(
        venueName: String,
        address: String,
        latitude: Double?,
        longitude: Double?,
        externalMapURL: String,
        onSave: @escaping (String, Double?, Double?, String) -> Void
    ) {
        self.address = address
        self.onSave = onSave
        _venueName = State(initialValue: venueName)
        _sharedURL = State(initialValue: externalMapURL)
        let coordinate: CLLocationCoordinate2D? = if let latitude,
                                                     let longitude,
                                                     latitude != 0 || longitude != 0 {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
        _selectedCoordinate = State(initialValue: coordinate)
        let center = coordinate ?? CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(
                        latitudeDelta: coordinate == nil ? 0.18 : 0.012,
                        longitudeDelta: coordinate == nil ? 0.18 : 0.012
                    )
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Google Maps・Apple Mapsの共有URL")
                            .font(FavorecoTypography.bodyStrong)
                        TextField("共有URLを貼り付け", text: $sharedURL, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(
                                Color.secondary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )

                        Button {
                            Task { await loadSharedLink() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingLink { ProgressView() }
                                FavorecoIconLabel("共有URLから場所名を取得", systemImage: "link", iconSize: 15)
                            }
                            .font(FavorecoTypography.captionStrong)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(sharedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingLink)

                        Text("Google MapsのURLは場所名と参照リンクを取り込みます。正確な位置は下の地図をタップして保存します。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)

                        if !linkMessage.isEmpty {
                            Text(linkMessage)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(linkMessage.hasPrefix("取得") ? Color.green : Color.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("位置を地図で指定")
                                .font(FavorecoTypography.bodyStrong)
                            Spacer()
                            if selectedCoordinate != nil {
                                Text("ピン設定済み")
                                    .font(FavorecoTypography.captionStrong)
                                    .foregroundStyle(Color(hex: "#8B2F45"))
                            }
                        }
                        Text("地図を動かして、会場の建物をタップしてください。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)

                        MapReader { proxy in
                            Map(position: $cameraPosition, interactionModes: .all) {
                                if let selectedCoordinate {
                                    Marker(
                                        venueName.isEmpty ? "会場" : venueName,
                                        coordinate: selectedCoordinate
                                    )
                                    .tint(Color(hex: "#8B2F45"))
                                }
                            }
                            .mapStyle(.standard(elevation: .flat))
                            .onTapGesture { point in
                                guard let coordinate = proxy.convert(point, from: .local) else { return }
                                selectedCoordinate = coordinate
                            }
                        }
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationTitle("正確な場所を設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("反映") {
                        onSave(
                            venueName.trimmingCharacters(in: .whitespacesAndNewlines),
                            selectedCoordinate?.latitude,
                            selectedCoordinate?.longitude,
                            sharedURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                }
            }
            .task { await resolveInitialCoordinateIfNeeded() }
        }
    }

    @MainActor
    private func loadSharedLink() async {
        isLoadingLink = true
        defer { isLoadingLink = false }
        do {
            let preview = try await PlaceSearchService.sharedMapLinkPreview(from: sharedURL)
            sharedURL = preview.url.absoluteString
            if !preview.name.isEmpty { venueName = preview.name }
            if let latitude = preview.latitude, let longitude = preview.longitude {
                setCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
            linkMessage = "取得しました。位置を確認してください。"
        } catch {
            linkMessage = error.localizedDescription
        }
    }

    @MainActor
    private func resolveInitialCoordinateIfNeeded() async {
        guard selectedCoordinate == nil else { return }
        if let coordinate = await PlaceSearchService.resolveCoordinate(
            queries: [address, venueName].filter { !$0.isEmpty }
        ) {
            setCoordinate(coordinate)
        }
    }

    private func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
        )
    }
}
