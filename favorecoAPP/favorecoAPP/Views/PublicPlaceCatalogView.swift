import SwiftData
import SwiftUI

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

    private var availablePrefectures: [String] {
        selectedArea?.prefectures ?? JapanPrefecture.all
    }

    private var availableTypeKeys: [String] {
        Array(Set(store.entries.flatMap(\.typeKeys))).sorted()
    }

    private var filteredEntries: [PublicPlaceCatalogEntry] {
        let query = normalizedCatalogText(searchText)
        return store.entries.filter { entry in
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
                    Picker("種別", selection: $selectedTypeKey) {
                        Text("すべて").tag("")
                        ForEach(availableTypeKeys, id: \.self) { typeKey in
                            Text(catalogTypeDisplayName(typeKey)).tag(typeKey)
                        }
                    }
                    LabeledContent("表示件数", value: "\(filteredEntries.count) / \(store.entries.count)件")
                }

                syncStatusSection

                Section("公開場所カタログ") {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView(
                            store.entries.isEmpty ? "カタログを取得できていません" : "条件に一致する場所がありません",
                            systemImage: "building.2.crop.circle",
                            description: Text(store.entries.isEmpty ? "通信状態を確認して再取得してください。端末に取得済みのデータがあればオフラインでも表示します。" : "検索語または絞り込みを変更してください。")
                        )
                    } else {
                        ForEach(filteredEntries) { entry in
                            PublicPlaceCatalogRow(
                                entry: entry,
                                isImported: matchingPersonalPlace(for: entry) != nil,
                                importAction: { importEntry(entry) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("全国場所カタログ")
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
            .alert("場所マスター", isPresented: Binding(
                get: { !feedbackMessage.isEmpty },
                set: { if !$0 { feedbackMessage = "" } }
            )) {
                Button("OK", role: .cancel) { feedbackMessage = "" }
            } message: {
                Text(feedbackMessage)
            }
        }
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
                Section { LabeledContent("最終更新", value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened)) }
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
            feedbackMessage = "「\(existing.name)」はすでに場所マスターへ登録されています。"
            return
        }
        do {
            _ = try PublicPlaceCatalogImporter.importEntry(
                entry,
                existingPlaces: personalPlaces,
                in: modelContext
            )
            feedbackMessage = "「\(entry.officialName)」を場所マスターへ追加しました。"
        } catch {
            feedbackMessage = "追加できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct PublicPlaceCatalogRow: View {
    let entry: PublicPlaceCatalogEntry
    let isImported: Bool
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
            HStack {
                if let capacity = entry.capacity, capacity > 0 {
                    Label("\(capacity.formatted())人", systemImage: "person.3")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isImported ? "登録済み" : "マスターに追加", action: importAction)
                    .buttonStyle(.bordered)
                    .disabled(isImported)
            }
        }
        .padding(.vertical, 3)
    }
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
    case "music_venue", "concert_hall": "ライブ会場"
    case "theater", "performing_arts_venue": "劇場"
    case "public_hall", "civic_hall", "cultural_center": "公共ホール"
    case "stadium", "arena", "dome": "スタジアム・アリーナ"
    case "theme_park", "amusement_park", "indoor_theme_park": "テーマパーク"
    case "zoo": "動物園"
    case "aquarium": "水族館"
    case "museum": "博物館"
    case "art_museum": "美術館"
    case "castle": "城"
    case "dam": "ダム"
    case "landmark", "historic_site": "ランドマーク・史跡"
    default: key.replacingOccurrences(of: "_", with: " ")
    }
}
