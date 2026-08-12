import SwiftData
import SwiftUI

struct PublicRecurringEventCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @StateObject private var store = PublicRecurringEventCatalogStore.shared
    @State private var searchText = ""
    @State private var selectedTemplateKey = ""
    @State private var feedbackMessage = ""

    private let onSelect: ((PublicRecurringEventCatalogEntry, PublicRecurringEventEdition?) -> Void)?

    init(
        templateKey: String? = nil,
        onSelect: ((PublicRecurringEventCatalogEntry, PublicRecurringEventEdition?) -> Void)? = nil
    ) {
        _selectedTemplateKey = State(initialValue: templateKey ?? "")
        self.onSelect = onSelect
    }

    private var filteredEntries: [PublicRecurringEventCatalogEntry] {
        let query = normalizedRecurringCatalogSearchText(searchText)
        return store.entries.filter { entry in
            let matchesTemplate = selectedTemplateKey.isEmpty || entry.templateKey == selectedTemplateKey
            let values = [
                entry.officialName,
                entry.reading,
                entry.aliases.joined(separator: " "),
                entry.prefectures.joined(separator: " "),
                entry.areaSummary,
                entry.eventTypeKeys.joined(separator: " "),
                entry.editions.map(\.label).joined(separator: " "),
                entry.editions.flatMap(\.prefectures).joined(separator: " "),
                entry.editions.map(\.areaSummary).joined(separator: " "),
            ]
            let matchesQuery = query.isEmpty || values.contains {
                normalizedRecurringCatalogSearchText($0).contains(query)
            }
            return matchesTemplate && matchesQuery
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FavorecoSettingsInfoCallout(
                        title: onSelect == nil ? "定期イベントを対象へ追加" : "定期イベントから入力",
                        message: "シリーズの名称と公式URLだけを利用者データへ写します。開催回の会期は予定日候補として選べます。"
                    )
                }

                Section("絞り込み") {
                    Picker("ジャンル", selection: $selectedTemplateKey) {
                        Text("すべて").tag("")
                        Text("ミュージアム").tag("museum")
                        Text("観劇").tag("theater")
                        Text("LIVE").tag("live")
                    }
                    LabeledContent("表示件数", value: "\(filteredEntries.count) / \(store.entries.count)件")
                }

                syncSection

                Section("公開定期イベントカタログ") {
                    if filteredEntries.isEmpty {
                        FavorecoContentUnavailableView(
                            store.entries.isEmpty ? "カタログを取得できていません" : "条件に一致するイベントがありません",
                            systemImage: "calendar.badge.clock",
                            description: store.entries.isEmpty
                                ? "通信状態を確認して再取得してください。取得済みデータはオフラインでも使えます。"
                                : "名称・地域・ジャンルを変えて検索してください。"
                        )
                    } else {
                        ForEach(filteredEntries) { entry in
                            recurringEventRow(entry)
                        }
                    }
                }
            }
            .navigationTitle("定期イベントカタログ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "名称・よみ・地域・別名を検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.state == .syncing)
                }
            }
            .task { await store.prepare() }
            .alert("定期イベント", isPresented: Binding(
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
    private var syncSection: some View {
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

    private func recurringEventRow(_ entry: PublicRecurringEventCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.officialName)
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text(recurringEventTemplateName(entry.templateKey))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Text([entry.recurrenceLabel, entry.prefectures.joined(separator: "・"), entry.areaSummary]
                .filter { !$0.isEmpty }
                .joined(separator: "｜"))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

            if let edition = entry.preferredEdition {
                HStack(spacing: 7) {
                    FavorecoIcon(systemName: "calendar", size: 12)
                    Text(editionSummary(edition))
                        .lineLimit(2)
                }
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))

                if entry.editions.count > 1 {
                    Text("開催回 (entry.editions.count)件")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                if let url = validatedRecurringCatalogURL(entry.officialURL) {
                    Link(destination: url) {
                        FavorecoIconLabel("公式サイト", systemImage: "arrow.up.right.square", iconSize: 11)
                    }
                }
                if let url = validatedRecurringCatalogURL(entry.sourceURL) {
                    Link(destination: url) {
                        FavorecoIconLabel("情報元", systemImage: "doc.text.magnifyingglass", iconSize: 11)
                    }
                }
                Spacer()
                actionButton(entry)
            }
            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(_ entry: PublicRecurringEventCatalogEntry) -> some View {
        if let onSelect {
            if entry.selectableEditions.count > 1 {
                Menu("開催回を選ぶ") {
                    ForEach(entry.selectableEditions) { edition in
                        Button {
                            onSelect(entry, edition)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(edition.label.isEmpty ? entry.officialName : edition.label)
                                Text(editionSummary(edition))
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button("選択") {
                    onSelect(entry, entry.preferredEdition)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        } else if let category = category(for: entry.templateKey) {
            let alreadyImported = PublicRecurringEventCatalogImporter.matchingEvent(
                for: entry,
                category: category,
                in: events
            ) != nil
            Button(alreadyImported ? "登録済み" : "対象に追加") {
                importEntry(entry, category: category)
            }
            .buttonStyle(.bordered)
            .disabled(alreadyImported)
        } else {
            Text("ジャンル未設定")
                .foregroundStyle(.secondary)
        }
    }

    private func category(for templateKey: String) -> RecordCategory? {
        categories.first { !$0.isArchived && $0.templateKey == templateKey }
    }

    private func importEntry(_ entry: PublicRecurringEventCatalogEntry, category: RecordCategory) {
        do {
            _ = try PublicRecurringEventCatalogImporter.importEntry(
                entry,
                category: category,
                existingEvents: events,
                in: modelContext
            )
            feedbackMessage = "「\(entry.officialName)」を気になる対象へ追加しました。"
        } catch {
            feedbackMessage = "追加できませんでした: \(error.localizedDescription)"
        }
    }
}

private func recurringEventTemplateName(_ key: String) -> String {
    switch key {
    case "museum": "ミュージアム"
    case "theater": "観劇"
    case "live": "LIVE"
    default: key
    }
}

private func editionSummary(_ edition: PublicRecurringEventEdition) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/M/d"
    let dates: String
    if let start = edition.startDate, let end = edition.endDate {
        dates = start == end ? formatter.string(from: start) : "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    } else if let start = edition.startDate {
        dates = formatter.string(from: start)
    } else {
        dates = "会期未発表"
    }
    return [edition.label, dates].filter { !$0.isEmpty }.joined(separator: "｜")
}

private func validatedRecurringCatalogURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          url.host != nil else { return nil }
    return url
}

private func normalizedRecurringCatalogSearchText(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .filter { !$0.isWhitespace }
}
