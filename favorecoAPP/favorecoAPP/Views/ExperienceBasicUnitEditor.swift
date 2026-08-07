import MapKit
import SwiftUI
import UIKit

enum ExperienceDatePrecision {
    case day
    case year
}

struct PlaceOfficialWebsiteLink: View {
    let urlString: String
    var title = "会場公式サイト"

    var body: some View {
        if let url = validatedURL {
            Link(destination: url) {
                FavorecoIconLabel(title, systemImage: "arrow.up.right.square", iconSize: 11)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
            }
        }
    }

    private var validatedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { return nil }
        return url
    }
}

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
    let venueOfficialURL: String
    let placeMasters: [PlaceMaster]
    let usesPlaceSuggestions: Bool
    let usesMapSearchAssist: Bool
    let supportsPerformanceTime: Bool
    let supportsStyles: Bool
    let usesExplicitTheaterLayout: Bool
    let showsRating: Bool
    let datePrecision: ExperienceDatePrecision
    let usesSimpleScreenWorkLayout: Bool
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
        venueOfficialURL: String = "",
        placeMasters: [PlaceMaster],
        usesPlaceSuggestions: Bool,
        usesMapSearchAssist: Bool,
        supportsPerformanceTime: Bool,
        supportsStyles: Bool,
        usesExplicitTheaterLayout: Bool = false,
        showsRating: Bool = true,
        datePrecision: ExperienceDatePrecision = .day,
        usesSimpleScreenWorkLayout: Bool = false,
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
        self.venueOfficialURL = venueOfficialURL
        self.placeMasters = placeMasters
        self.usesPlaceSuggestions = usesPlaceSuggestions
        self.usesMapSearchAssist = usesMapSearchAssist
        self.supportsPerformanceTime = supportsPerformanceTime
        self.supportsStyles = supportsStyles
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
        self.showsRating = showsRating
        self.datePrecision = datePrecision
        self.usesSimpleScreenWorkLayout = usesSimpleScreenWorkLayout
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
        venueOfficialURL: String = "",
        placeMasters: [PlaceMaster],
        usesPlaceSuggestions: Bool,
        usesMapSearchAssist: Bool,
        supportsPerformanceTime: Bool,
        supportsStyles: Bool,
        usesExplicitTheaterLayout: Bool = false,
        showsRating: Bool = true,
        datePrecision: ExperienceDatePrecision = .day,
        usesSimpleScreenWorkLayout: Bool = false,
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
        self.venueOfficialURL = venueOfficialURL
        self.placeMasters = placeMasters
        self.usesPlaceSuggestions = usesPlaceSuggestions
        self.usesMapSearchAssist = usesMapSearchAssist
        self.supportsPerformanceTime = supportsPerformanceTime
        self.supportsStyles = supportsStyles
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
        self.showsRating = showsRating
        self.datePrecision = datePrecision
        self.usesSimpleScreenWorkLayout = usesSimpleScreenWorkLayout
        self.ratingText = ratingText
        self.onSelectPlace = onSelectPlace
        self.onSelectPublicPlace = onSelectPublicPlace
        self.onOpenPlaceSearch = onOpenPlaceSearch
    }

    var body: some View {
        VStack(spacing: 0) {
            if usesExplicitTheaterLayout {
                VStack(alignment: .leading, spacing: 0) {
                    targetFields
                    Divider()
                    visitFields
                }
            } else {
                Group {
                    targetFields
                    Divider()
                    visitFields
                }
            }
        }
        .task { await publicPlaceStore.prepare() }
    }

    @ViewBuilder
    private var targetFields: some View {
        if usesSimpleScreenWorkLayout, let editableTitle {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.targetSectionTitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                TextField(template.titlePlaceholder, text: editableTitle)
            }
        } else if usesSimpleScreenWorkLayout {
            Text(existingTitle.isEmpty ? "映像作品" : existingTitle)
                .font(FavorecoTypography.bodyStrong)
        } else if usesExplicitTheaterLayout, let editableTitle, let editableSeriesName {
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
        if usesSimpleScreenWorkLayout {
            return AnyView(simpleScreenWorkVisitFields)
        }

        return AnyView(
        VStack(alignment: .leading, spacing: 12) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            if datePrecision == .year {
                YearOnlyPicker(selection: $visitedAt)
            } else {
                DatePicker(template.dateLabel, selection: $visitedAt, displayedComponents: .date)
            }
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
                            .tint(isSelected ? Color.accentColor : Color.secondary)
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
                PlaceOfficialWebsiteLink(urlString: resolvedVenueOfficialURL)
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
        )
    }

    private var simpleScreenWorkVisitFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            if datePrecision == .year {
                YearOnlyPicker(selection: $visitedAt)
            } else {
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

                theaterDivider

                ExplicitFormTextField(
                    title: "映画館（任意）",
                    prompt: "映画館名を入力",
                    text: $venueName,
                    labelStyle: .horizontal
                )
            }

            theaterDivider

            ratingSlider
                .padding(.vertical, 8)
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
                    TheaterFiveMinuteTimeField(
                        selection: $visitedAt,
                        accessibilityLabel: "開演"
                    )
                }
                theaterDivider
                ExplicitFormControlRow(title: "終演") {
                    TheaterFiveMinuteTimeField(
                        selection: $endedAt,
                        accessibilityLabel: "終演",
                        minimumDate: visitedAt
                    )
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

                PlaceOfficialWebsiteLink(urlString: resolvedVenueOfficialURL)

                PlaceMapPreview(
                    venueName: venueName,
                    address: venueAddress,
                    latitude: latitude,
                    longitude: longitude
                )
            }

            if showsRating {
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
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
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
                    .tint(isSelected ? Color.accentColor : Color.secondary)
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

    private var resolvedVenueOfficialURL: String {
        let explicit = venueOfficialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }

        let normalizedName = normalizedPlaceText(venueName)
        guard !normalizedName.isEmpty else { return "" }
        let normalizedAddress = normalizedPlaceText(venueAddress)
        return placeMasters.first { place in
            guard !place.isArchived,
                  normalizedPlaceText(place.name) == normalizedName else { return false }
            if normalizedAddress.isEmpty { return true }
            return normalizedPlaceText(place.address) == normalizedAddress
        }?.officialURL ?? ""
    }

    private var placeSuggestions: [PlaceMaster] {
        guard !hasResolvedVenueSelection else { return [] }
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
        guard !hasResolvedVenueSelection else { return [] }
        guard !normalizedPlaceText(venueName).isEmpty else { return [] }
        let importedMarkers = Set(placeMasters.map(\.sourceSnapshotRaw))
        return PublicPlaceCatalogSearch.suggestions(
            for: venueName,
            in: publicPlaceStore.entries,
            excludingSourceMarkers: importedMarkers,
            includesClosed: true
        )
    }

    private var hasResolvedVenueSelection: Bool {
        let normalizedName = normalizedPlaceText(venueName)
        guard !normalizedName.isEmpty else { return false }
        if latitude != 0 || longitude != 0 { return true }

        let normalizedAddress = normalizedPlaceSuggestionAddress(venueAddress)
        guard !normalizedAddress.isEmpty else { return false }
        return placeMasters.contains { place in
            normalizedPlaceText(place.name) == normalizedName
                && placeAddressesReferToSameLocation(
                    normalizedPlaceSuggestionAddress(place.address),
                    normalizedAddress
                )
        }
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

struct ExperienceRatingUnitEditor: View {
    @Binding var overallRating: Double
    let ratingText: String
    var title = "満足度"

    var body: some View {
        ExplicitFormControlRow(title: title, isOptional: true) {
            HStack(spacing: 8) {
                Slider(value: $overallRating, in: 0...5, step: 0.5)
                    .frame(maxWidth: 172)
                Text(ratingText)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct ScreenWorkTypeAndSeasonEditor: View {
    @Binding var typeKey: String
    @Binding var seasonNumber: Int

    private var selection: Binding<ScreenWorkType> {
        Binding(
            get: { ScreenWorkType.resolved(from: typeKey) },
            set: { type in
                typeKey = type.rawValue
                if !type.supportsSeason {
                    seasonNumber = 0
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("種別", selection: selection) {
                ForEach(ScreenWorkType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if selection.wrappedValue.supportsSeason {
                Picker("シーズン", selection: $seasonNumber) {
                    Text("なし").tag(0)
                    ForEach(1...10, id: \.self) { number in
                        Text("シーズン\(number)").tag(number)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

private struct TheaterFiveMinuteTimeField: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    var minimumDate: Date?

    @State private var isShowingPicker = false
    @State private var pendingSelection = Date()

    private var displayText: String {
        selection
            .roundedToNearestFiveMinutes()
            .formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
                    .locale(Locale(identifier: "ja_JP"))
            )
    }

    var body: some View {
        Button {
            pendingSelection = normalized(selection)
            isShowingPicker = true
        } label: {
            Text(displayText)
                .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(minWidth: 68)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(displayText)
        .onAppear { normalizeSelectionIfNeeded() }
        .onChange(of: selection) { _, _ in normalizeSelectionIfNeeded() }
        .popover(isPresented: $isShowingPicker, attachmentAnchor: .rect(.bounds)) {
            VStack(spacing: 8) {
                TheaterFiveMinuteWheelPicker(
                    selection: $pendingSelection,
                    accessibilityLabel: accessibilityLabel
                ) { updated in
                    selection = normalized(updated)
                }
                .frame(width: 180, height: 170)

                Button("完了") { isShowingPicker = false }
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    .buttonStyle(.borderedProminent)
                    .favorecoProminentActionStyle()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func normalized(_ value: Date) -> Date {
        let rounded = value.roundedToNearestFiveMinutes()
        if let minimumDate, rounded < minimumDate {
            return minimumDate.roundedToNearestFiveMinutes()
        }
        return rounded
    }

    private func normalizeSelectionIfNeeded() {
        let updated = normalized(selection)
        if abs(selection.timeIntervalSince(updated)) >= 1 {
            selection = updated
        }
    }
}

private struct TheaterFiveMinuteWheelPicker: View {
    @Binding var selection: Date
    let accessibilityLabel: String
    let onUserChange: (Date) -> Void

    private static let minuteValues = Array(stride(from: 0, to: 24 * 60, by: 5))

    private var minuteOfDay: Binding<Int> {
        Binding(
            get: {
                let rounded = selection.roundedToNearestFiveMinutes()
                let components = Calendar.current.dateComponents([.hour, .minute], from: rounded)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            },
            set: { newMinuteOfDay in
                let hour = newMinuteOfDay / 60
                let minute = newMinuteOfDay % 60
                guard let updated = Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: selection
                ) else { return }
                selection = updated
                onUserChange(updated)
            }
        )
    }

    var body: some View {
        Picker(accessibilityLabel, selection: minuteOfDay) {
            ForEach(Self.minuteValues, id: \.self) { minuteOfDay in
                Text(String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60))
                    .font(FavorecoTypography.jpSans(17, weight: .regular, relativeTo: .body))
                    .monospacedDigit()
                    .tag(minuteOfDay)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct YearOnlyPicker: View {
    @Binding var selection: Date

    private let calendar = Calendar.current

    private var selectedYear: Binding<Int> {
        Binding(
            get: { calendar.component(.year, from: selection) },
            set: { newYear in
                let oldComponents = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: selection)
                var components = DateComponents()
                components.year = newYear
                components.month = oldComponents.month
                components.day = oldComponents.day
                components.hour = oldComponents.hour
                components.minute = oldComponents.minute
                components.second = oldComponents.second
                if let updated = calendar.date(from: components) {
                    selection = updated
                }
            }
        )
    }

    private var years: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array(stride(from: currentYear + 1, through: 1900, by: -1))
    }

    var body: some View {
        Picker("鑑賞年", selection: selectedYear) {
            ForEach(years, id: \.self) { year in
                Text(verbatim: "\(year)年").tag(year)
            }
        }
        .pickerStyle(.menu)
    }
}

struct PlaceMapPreview: View {
    let venueName: String
    let address: String
    let latitude: Double
    let longitude: Double
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    @State private var resolutionFailed = false
    @State private var mapDestination: FavorecoMapDestination?
    @State private var retryID = 0

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

    private var geocodeQueries: [String] {
        let trimmedName = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return [trimmedAddress, geocodeQuery, trimmedName].reduce(into: [String]()) { queries, query in
            guard !query.isEmpty, !queries.contains(query) else { return }
            queries.append(query)
        }
    }

    private var geocodeKey: String {
        "\(venueName)|\(address)|\(latitude)|\(longitude)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let coordinate {
                Map(initialPosition: .region(
                    FavorecoMapViewport.singlePointRegion(center: coordinate)
                )) {
                    Marker(venueName.isEmpty ? address : venueName, coordinate: coordinate)
                }
                .favorecoEmbeddedMapInteraction()
                .onTapGesture {
                    mapDestination = FavorecoMapDestination(
                        name: venueName,
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("\(venueName.isEmpty ? address : venueName)の地図")
            } else if !geocodeQuery.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                    if resolutionFailed {
                        Button {
                            retryID += 1
                        } label: {
                            VStack(spacing: 8) {
                                Label("地図を表示できません", systemImage: "exclamationmark.triangle")
                                Text("タップして再読み込み")
                                    .font(.caption2)
                            }
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ProgressView("地図を確認中")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
            }
        }
        .task(id: "\(geocodeKey)|\(retryID)") {
            await resolveCoordinateIfNeeded()
        }
        .task(id: "map-timeout-\(geocodeKey)|\(retryID)") {
            guard explicitCoordinate == nil, !geocodeQueries.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, resolvedCoordinate == nil else { return }
            resolutionFailed = true
        }
        .favorecoMapDestinationDialog(destination: $mapDestination)
    }

    @MainActor
    private func resolveCoordinateIfNeeded() async {
        resolutionFailed = false
        guard explicitCoordinate == nil else {
            resolvedCoordinate = nil
            return
        }
        guard !geocodeQueries.isEmpty else {
            resolvedCoordinate = nil
            return
        }

        resolvedCoordinate = nil
        if let coordinate = await PlaceSearchService.resolveCoordinate(queries: geocodeQueries) {
            guard !Task.isCancelled else { return }
            resolvedCoordinate = coordinate
            return
        }
        guard !Task.isCancelled else { return }
        resolutionFailed = true
    }
}

struct ExperiencePlaceSearchView: View {
    let initialQuery: String
    let registeredVenues: [EventVenueEntry]
    let onSelectRegisteredVenue: ((EventVenueEntry) -> Void)?
    let onSelect: (PlaceSearchCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [PlaceSearchCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage = ""

    init(
        initialQuery: String,
        registeredVenues: [EventVenueEntry] = [],
        onSelectRegisteredVenue: ((EventVenueEntry) -> Void)? = nil,
        onSelect: @escaping (PlaceSearchCandidate) -> Void
    ) {
        self.initialQuery = initialQuery
        self.registeredVenues = Self.deduplicated(registeredVenues)
        self.onSelectRegisteredVenue = onSelectRegisteredVenue
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching && registeredVenues.isEmpty {
                    ProgressView("検索中")
                } else if !errorMessage.isEmpty && registeredVenues.isEmpty {
                    FavorecoContentUnavailableView(
                        "検索できませんでした",
                        systemImage: "wifi.exclamationmark",
                        description: errorMessage
                    )
                } else if registeredVenues.isEmpty && results.isEmpty {
                    FavorecoContentUnavailableView(
                        "会場を検索",
                        systemImage: "map",
                        description: "会場名や住所を入力してください"
                    )
                } else {
                    List {
                        if !registeredVenues.isEmpty {
                            Section("公演情報の会場") {
                                ForEach(registeredVenues) { venue in
                                    Button {
                                        onSelectRegisteredVenue?(venue)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(venue.trimmedName.isEmpty ? "会場名未登録" : venue.trimmedName)
                                                    .font(FavorecoTypography.bodyStrong)
                                                    .foregroundStyle(.primary)
                                                if !venue.trimmedPerformanceLabel.isEmpty {
                                                    Text(venue.trimmedPerformanceLabel)
                                                        .font(FavorecoTypography.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            if !venue.trimmedAddress.isEmpty {
                                                Text(venue.trimmedAddress)
                                                    .font(FavorecoTypography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if isSearching {
                            Section("Apple Maps検索結果") {
                                ProgressView("検索中")
                            }
                        } else if !errorMessage.isEmpty {
                            Section("Apple Maps検索結果") {
                                Text(errorMessage)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !isSearching && !results.isEmpty {
                            Section("Apple Maps検索結果") {
                                ForEach(results) { candidate in
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

    private static func deduplicated(_ venues: [EventVenueEntry]) -> [EventVenueEntry] {
        var seen = Set<String>()
        return venues.filter { venue in
            let key = "\(venue.trimmedName)|\(venue.trimmedAddress)"
                .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            return !venue.isEmpty && seen.insert(key).inserted
        }
    }
}
