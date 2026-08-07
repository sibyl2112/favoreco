import SwiftData
import SwiftUI

enum PublicPlaceCatalogScope: Equatable, Sendable {
    case all
    case facility
    case museum
    case themePark
    case natureLiving

    var navigationTitle: String {
        switch self {
        case .all: "全国場所カタログ"
        case .facility: "施設を登録"
        case .museum: "美術館・博物館を登録"
        case .themePark: "施設を登録"
        case .natureLiving: "スポットを登録"
        }
    }

    var emptyDescription: String {
        switch self {
        case .all, .facility:
            "検索語または絞り込みを変更してください。"
        case .museum:
            "美術館・博物館・ギャラリーの名称や住所で検索してください。"
        case .themePark:
            "テーマパーク・遊園地の名称や住所で検索してください。"
        case .natureLiving:
            "動物園・水族館・植物園・公園などの名称や住所で検索してください。"
        }
    }

    var typeFilterTitle: String {
        switch self {
        case .all: "場所種別"
        case .facility, .museum, .themePark: "施設種別"
        case .natureLiving: "スポット種別"
        }
    }

    var registrationTargetName: String {
        switch self {
        case .all: "場所"
        case .facility, .museum, .themePark: "施設"
        case .natureLiving: "スポット"
        }
    }

    var registrationButtonTitle: String {
        "場所マスターに追加"
    }

    func includes(_ entry: PublicPlaceCatalogEntry) -> Bool {
        includes(catalogID: entry.catalogID, typeKeys: entry.typeKeys)
    }

    func includes(_ place: PlaceMaster) -> Bool {
        let typeKeys = place.placeTagsRaw
            .components(separatedBy: CharacterSet(charactersIn: ",、|\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return includes(catalogID: "", typeKeys: typeKeys)
    }

    private func includes(catalogID: String, typeKeys: [String]) -> Bool {
        let keys = Set(typeKeys)
        switch self {
        case .all, .facility:
            return true
        case .museum:
            return catalogID == "museum"
                || !keys.isDisjoint(with: ["museum", "art_museum", "science_museum", "gallery"])
        case .themePark:
            return !keys.isDisjoint(with: ["theme_park", "amusement_park", "indoor_theme_park"])
        case .natureLiving:
            return !keys.isDisjoint(with: [
                "zoo", "aquarium", "safari_park", "botanical_garden", "garden",
                "park", "national_park", "geopark", "scenic_spot", "wildlife_center",
                "marine_park",
            ])
        }
    }
}

struct PublicPlaceCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceMaster.name) private var personalPlaces: [PlaceMaster]
    @StateObject private var store = PublicPlaceCatalogStore.shared
    @State private var searchText = ""
    @State private var selectedArea: JapanArea?
    @State private var selectedPrefecture = ""
    @State private var selectedTypeKey = ""
    @State private var feedbackMessage = ""
    let scope: PublicPlaceCatalogScope

    init(scope: PublicPlaceCatalogScope = .all) {
        self.scope = scope
    }

    private var scopedEntries: [PublicPlaceCatalogEntry] {
        store.entries.filter { scope.includes($0) }
    }

    private var availablePrefectures: [String] {
        selectedArea?.prefectures ?? JapanPrefecture.all
    }

    private var availableTypeKeys: [String] {
        Array(Set(scopedEntries.flatMap(\.typeKeys))).sorted()
    }

    private var filteredEntries: [PublicPlaceCatalogEntry] {
        let query = normalizedCatalogText(searchText)
        return scopedEntries.filter { entry in
            let matchesArea = selectedArea?.includes(prefecture: entry.prefecture) ?? true
            let matchesPrefecture = selectedPrefecture.isEmpty || entry.prefecture == selectedPrefecture
            let matchesType = selectedTypeKey.isEmpty || entry.typeKeys.contains(selectedTypeKey)
            let matchesQuery = query.isEmpty || [
                entry.officialName,
                entry.reading,
                entry.address,
                entry.prefecture,
                entry.municipality,
                entry.aliases.joined(separator: " "),
            ].contains { normalizedCatalogText($0).contains(query) }
            return matchesArea && matchesPrefecture && matchesType && matchesQuery
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FavorecoSettingsInfoCallout(
                        title: "公開カタログから場所マスターへ追加",
                        message: "公式サイトと情報元を確認してから追加できます。追加した場所は、設定の「マスターデータ > 場所」と予定・記録の場所候補に表示されます。"
                    )
                }
                filterSection
                syncStatusSection
                catalogSection
            }
            .navigationTitle(scope.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "名称・よみ・住所・別名を検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.state == .syncing)
                    .accessibilityLabel("公開カタログを再取得")
                }
            }
            .onChange(of: selectedArea) { _, area in
                if !selectedPrefecture.isEmpty,
                   let area,
                   !area.includes(prefecture: selectedPrefecture) {
                    selectedPrefecture = ""
                }
            }
            .task { await store.prepare() }
            .alert("\(scope.registrationTargetName)の登録", isPresented: Binding(
                get: { !feedbackMessage.isEmpty },
                set: { if !$0 { feedbackMessage = "" } }
            )) {
                Button("OK", role: .cancel) { feedbackMessage = "" }
            } message: {
                Text(feedbackMessage)
            }
        }
    }

    private var filterSection: some View {
        Section("絞り込み") {
            Picker("エリア", selection: $selectedArea) {
                Text("全国").tag(JapanArea?.none)
                ForEach(JapanArea.allCases) { area in
                    Text(area.title).tag(Optional(area))
                }
            }
            Picker("都道府県", selection: $selectedPrefecture) {
                Text("すべて").tag("")
                ForEach(availablePrefectures, id: \.self) { prefecture in
                    Text(prefecture).tag(prefecture)
                }
            }
            Picker(scope.typeFilterTitle, selection: $selectedTypeKey) {
                Text("すべて").tag("")
                ForEach(availableTypeKeys, id: \.self) { typeKey in
                    Text(catalogTypeDisplayName(typeKey)).tag(typeKey)
                }
            }
            LabeledContent("表示件数", value: "\(filteredEntries.count) / \(scopedEntries.count)件")
        }
    }

    private var catalogSection: some View {
        Section {
            catalogRows
        } header: {
            Text("公開場所カタログ")
        } footer: {
            catalogFooter
        }
    }

    @ViewBuilder
    private var catalogRows: some View {
        if filteredEntries.isEmpty {
            FavorecoContentUnavailableView(
                emptyCatalogTitle,
                systemImage: "building.2.crop.circle",
                description: emptyCatalogDescription
            )
        } else {
            ForEach(filteredEntries) { entry in
                PublicPlaceCatalogRow(
                    entry: entry,
                    isImported: matchingPersonalPlace(for: entry) != nil,
                    registrationButtonTitle: scope.registrationButtonTitle,
                    importAction: { importEntry(entry) }
                )
            }
        }
    }

    @ViewBuilder
    private var catalogFooter: some View {
        if scope != .all {
            Text("見つからない\(scope.registrationTargetName)は、予定・記録の場所欄へ名称と住所を入力すると、保存時に登録済み候補へ追加されます。")
        }
    }

    private var emptyCatalogTitle: String {
        store.entries.isEmpty ? "カタログを取得できていません" : "条件に一致する場所がありません"
    }

    private var emptyCatalogDescription: String {
        store.entries.isEmpty
            ? "通信状態を確認して再取得してください。端末に取得済みのデータがあればオフラインでも表示します。"
            : scope.emptyDescription
    }

    @ViewBuilder
    private var syncStatusSection: some View {
        switch store.state {
        case .idle, .loadingCache:
            Section { ProgressView("端末キャッシュを読み込み中…") }
        case .syncing:
            Section { ProgressView("公開カタログを更新中…") }
        case let .ready(lastSyncedAt):
            if let lastSyncedAt {
                Section { LabeledContent("最終更新", value: FavorecoDateText.compactDateTime(lastSyncedAt)) }
            }
        case let .failed(message, hasCache):
            Section {
                Label(hasCache ? "取得済みデータを表示しています" : "公開カタログを取得できませんでした", systemImage: "exclamationmark.icloud")
                Text(message).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func matchingPersonalPlace(for entry: PublicPlaceCatalogEntry) -> PlaceMaster? {
        PublicPlaceCatalogImporter.matchingPlace(for: entry, in: personalPlaces)
    }

    private func importEntry(_ entry: PublicPlaceCatalogEntry) {
        if let existing = matchingPersonalPlace(for: entry) {
            feedbackMessage = "「\(existing.name)」はすでに登録済みです。"
            return
        }
        do {
            _ = try PublicPlaceCatalogImporter.importEntry(
                entry,
                existingPlaces: personalPlaces,
                in: modelContext
            )
            feedbackMessage = "「\(entry.officialName)」を\(scope.registrationTargetName)として登録しました。"
        } catch {
            feedbackMessage = "追加できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct PublicPlaceCatalogRow: View {
    let entry: PublicPlaceCatalogEntry
    let isImported: Bool
    let registrationButtonTitle: String
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.officialName).font(FavorecoTypography.bodyStrong)
                Spacer()
                if entry.isClosed {
                    Text("閉館").font(FavorecoTypography.caption).foregroundStyle(.red)
                }
            }
            Text([entry.prefecture, entry.address, entry.typeKeys.prefix(2).map(catalogTypeDisplayName).joined(separator: "・")]
                .filter { !$0.isEmpty }
                .joined(separator: "｜"))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                if let officialURL = validatedCatalogURL(entry.officialURL) {
                    Link(destination: officialURL) {
                        FavorecoIconLabel("公式サイト", systemImage: "arrow.up.right.square", iconSize: 11)
                    }
                }

                if let sourceURL = validatedCatalogURL(entry.sourceURL) {
                    Link(destination: sourceURL) {
                        FavorecoIconLabel("情報元", systemImage: "doc.text.magnifyingglass", iconSize: 11)
                    }
                }

                if entry.updatedAt != .distantPast {
                    Text("確認 \(FavorecoDateText.fullDate(entry.updatedAt, includesWeekday: false))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
            HStack {
                if let capacity = entry.capacity, capacity > 0 {
                    Label("\(capacity.formatted())人", systemImage: "person.3")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isImported ? "登録済み" : registrationButtonTitle, action: importAction)
                    .buttonStyle(.bordered)
                    .disabled(isImported)
            }
        }
        .padding(.vertical, 3)
    }
}

private func validatedCatalogURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          url.host != nil else { return nil }
    return url
}

private func normalizedCatalogText(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}

private func catalogTypeDisplayName(_ key: String) -> String {
    switch key {
    case "temple", "buddhist_temple": "寺院"
    case "shrine": "神社"
    case "live_house": "ライブハウス"
    case "music_venue", "live_venue": "ライブ会場"
    case "concert_hall": "コンサートホール"
    case "theater", "performing_arts_venue": "劇場"
    case "public_hall", "civic_hall", "cultural_center": "公共ホール"
    case "stadium", "arena", "dome": "スタジアム・アリーナ"
    case "theme_park", "amusement_park", "indoor_theme_park": "テーマパーク"
    case "zoo": "動物園"
    case "aquarium": "水族館"
    case "museum": "博物館"
    case "art_museum": "美術館"
    case "science_museum": "科学館"
    case "castle": "城"
    case "dam": "ダム"
    case "landmark", "historic_site": "ランドマーク・史跡"
    case "archaeological_site": "遺跡"
    case "architecture": "建築"
    case "athletics_stadium": "陸上競技場"
    case "baseball_stadium": "野球場"
    case "basketball_arena": "バスケットボール会場"
    case "beer_brewery": "ビール醸造所"
    case "botanical_garden": "植物園"
    case "bridge": "橋"
    case "campground": "キャンプ場"
    case "church": "教会"
    case "cinema": "映画館"
    case "continued_japan_100_castles": "続日本100名城"
    case "convention_hall": "コンベンションホール"
    case "cultural_facility", "cultural_venue": "文化施設"
    case "event_hall", "event_venue": "イベント会場"
    case "exhibition_center": "展示場"
    case "football_stadium": "サッカー場"
    case "garden": "庭園"
    case "geopark": "ジオパーク"
    case "gymnasium": "体育館"
    case "historic_building": "歴史的建造物"
    case "ice_arena": "アイスアリーナ"
    case "immersive_theater": "体験型劇場"
    case "important_cultural_property": "重要文化財"
    case "industrial_heritage": "産業遺産"
    case "industrial_tourism": "産業観光"
    case "infrastructure": "インフラ施設"
    case "japan_100_castles": "日本100名城"
    case "kabuki_theater": "歌舞伎劇場"
    case "kumano_kodo": "熊野古道"
    case "leisure_facility": "レジャー施設"
    case "library": "図書館"
    case "marine_park": "海浜公園"
    case "martial_arts_hall", "martial_arts_venue": "武道館"
    case "medium_venue": "中規模会場"
    case "monument": "記念碑"
    case "mountain": "山"
    case "music_festival_venue": "音楽フェス会場"
    case "national_park": "国立公園"
    case "national_treasure": "国宝"
    case "natural_landmark": "自然名所"
    case "observation_deck": "展望台"
    case "opera_house": "歌劇場"
    case "outdoor_venue": "野外会場"
    case "park": "公園"
    case "pilgrimage_site": "巡礼地"
    case "rugby_stadium": "ラグビー場"
    case "sacred_site": "霊場"
    case "safari_park": "サファリパーク"
    case "sake_brewery": "酒蔵"
    case "scenic_spot": "景勝地"
    case "ski_resort": "スキー場"
    case "small_theater": "小劇場"
    case "small_venue": "小規模会場"
    case "special_historic_site": "特別史跡"
    case "sports_venue": "スポーツ会場"
    case "sumo_venue": "相撲会場"
    case "tennis_venue": "テニス会場"
    case "tower": "タワー"
    case "visitor_center": "ビジターセンター"
    case "waterfall": "滝"
    case "wetland": "湿地"
    case "whisky_distillery": "ウイスキー蒸留所"
    case "wildlife_center": "野生生物施設"
    case "winery": "ワイナリー"
    case "world_heritage": "世界遺産"
    default: "その他"
    }
}
