import SwiftUI
import SwiftData

enum RecordFacetMasterKind: String, Identifiable {
    case tag
    case companion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tag: "タグ"
        case .companion: "同行者"
        }
    }

    var systemImage: String {
        switch self {
        case .tag: "tag"
        case .companion: "person.2"
        }
    }

    func rawValue(from visit: Visit) -> String {
        switch self {
        case .tag: visit.tagNamesRaw
        case .companion: visit.companionNamesRaw
        }
    }

    func setRawValue(_ value: String, on visit: Visit) {
        switch self {
        case .tag: visit.tagNamesRaw = value
        case .companion: visit.companionNamesRaw = value
        }
    }
}

struct RecordFacetMasterValue: Identifiable {
    let name: String
    let usageCount: Int

    var id: String { normalizedRecordFacetMasterName(name) }
}

struct RecordFacetMasterManagementView: View {
    let kind: RecordFacetMasterKind

    @Environment(\.modelContext) private var modelContext
    @Query private var visits: [Visit]
    @State private var searchText = ""
    @State private var editingValue: RecordFacetMasterValue?
    @State private var draftName = ""
    @State private var valuePendingDeletion: RecordFacetMasterValue?
    @State private var errorMessage = ""

    private var values: [RecordFacetMasterValue] {
        let allValues = recordFacetMasterValues(in: visits, kind: kind)
        let query = normalizedRecordFacetMasterName(searchText)
        guard !query.isEmpty else { return allValues }
        return allValues.filter { normalizedRecordFacetMasterName($0.name).contains(query) }
    }

    var body: some View {
        List {
            if values.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "\(kind.title)はまだありません" : "条件に一致する\(kind.title)がありません",
                    systemImage: kind.systemImage,
                    description: Text("記録へ保存した\(kind.title)がここへ自動的にまとまります。")
                )
            } else {
                ForEach(values) { value in
                    Button {
                        editingValue = value
                        draftName = value.name
                    } label: {
                        HStack {
                            Label(value.name, systemImage: kind.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(value.usageCount)件の記録")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            valuePendingDeletion = value
                        }
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("\(kind.title)マスター")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "\(kind.title)を検索")
        .sheet(item: $editingValue) { value in
            NavigationStack {
                Form {
                    Section("表記") {
                        TextField(kind.title, text: $draftName)
                    }
                    Section {
                        Text("同じ表記がすでにある場合は1つへ統合します。関連する\(value.usageCount)件の記録へ反映されます。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("\(kind.title)を編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { editingValue = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { rename(value, to: draftName) }
                            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .confirmationDialog(
            "「\(valuePendingDeletion?.name ?? "")」を削除しますか？",
            isPresented: Binding(
                get: { valuePendingDeletion != nil },
                set: { if !$0 { valuePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let value = valuePendingDeletion {
                Button("\(value.usageCount)件の記録から削除", role: .destructive) {
                    delete(value)
                }
            }
            Button("キャンセル", role: .cancel) { valuePendingDeletion = nil }
        } message: {
            Text("人物・場所・写真など、ほかの記録内容は変更しません。")
        }
    }

    private func rename(_ value: RecordFacetMasterValue, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        applyChange(for: value) { names in
            names.map {
                normalizedRecordFacetMasterName($0) == value.id ? trimmedName : $0
            }
        }
        if errorMessage.isEmpty {
            editingValue = nil
        }
    }

    private func delete(_ value: RecordFacetMasterValue) {
        applyChange(for: value) { names in
            names.filter { normalizedRecordFacetMasterName($0) != value.id }
        }
        if errorMessage.isEmpty {
            valuePendingDeletion = nil
        }
    }

    private func applyChange(
        for value: RecordFacetMasterValue,
        transform: ([String]) -> [String]
    ) {
        let now = Date()
        for visit in visits {
            let currentNames = recordFacetMasterNames(from: kind.rawValue(from: visit))
            guard currentNames.contains(where: { normalizedRecordFacetMasterName($0) == value.id }) else {
                continue
            }
            let changedNames = deduplicatedRecordFacetMasterNames(transform(currentNames))
            kind.setRawValue(changedNames.joined(separator: "、"), on: visit)
            visit.updatedAt = now
        }

        do {
            try modelContext.save()
            errorMessage = ""
        } catch {
            modelContext.rollback()
            errorMessage = "更新できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct CompanionMasterListValue: Identifiable {
    let name: String
    let usageCount: Int
    let iconSymbol: String
    let masterID: UUID?

    var id: String { normalizedRecordFacetMasterName(name) }
}

struct CompanionMasterManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CompanionMaster.name) private var companions: [CompanionMaster]
    @Query private var visits: [Visit]
    @State private var searchText = ""
    @State private var editingValue: CompanionMasterListValue?
    @State private var isShowingCreate = false
    @State private var draftName = ""
    @State private var draftIcon = CompanionIconCatalog.defaultSymbol
    @State private var valuePendingDeletion: CompanionMasterListValue?
    @State private var errorMessage = ""

    private var allValues: [CompanionMasterListValue] {
        var valuesByKey: [String: CompanionMasterListValue] = [:]
        let activeMasters = companions.filter { !$0.isArchived }

        for recorded in recordFacetMasterValues(in: visits, kind: .companion) {
            let master = activeMasters.first {
                normalizedRecordFacetMasterName($0.name) == recorded.id
                    || $0.normalizedName == recorded.id
            }
            let displayName = master.flatMap { $0.name.isEmpty ? nil : $0.name } ?? recorded.name
            valuesByKey[recorded.id] = CompanionMasterListValue(
                name: displayName,
                usageCount: recorded.usageCount,
                iconSymbol: CompanionIconCatalog.validated(master?.iconSymbol),
                masterID: master?.id
            )
        }

        for master in activeMasters {
            let key = normalizedRecordFacetMasterName(master.name)
            guard !key.isEmpty, valuesByKey[key] == nil else { continue }
            valuesByKey[key] = CompanionMasterListValue(
                name: master.name,
                usageCount: 0,
                iconSymbol: CompanionIconCatalog.validated(master.iconSymbol),
                masterID: master.id
            )
        }

        return valuesByKey.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var filteredValues: [CompanionMasterListValue] {
        let query = normalizedRecordFacetMasterName(searchText)
        guard !query.isEmpty else { return allValues }
        return allValues.filter { normalizedRecordFacetMasterName($0.name).contains(query) }
    }

    var body: some View {
        List {
            if filteredValues.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "同行者はまだありません" : "条件に一致する同行者がありません",
                    systemImage: "person.2",
                    description: Text("記録へ保存した同行者は自動的にまとまります。ここから先に登録することもできます。")
                )
            } else {
                ForEach(filteredValues) { value in
                    Button {
                        beginEditing(value)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: value.iconSymbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 30, height: 30)
                                .background(Color.accentColor.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(value.name)
                                    .foregroundStyle(.primary)
                                Text(value.usageCount == 0 ? "記録では未使用" : "\(value.usageCount)件の記録")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            valuePendingDeletion = value
                        }
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("同行者マスター")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "同行者を検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftName = ""
                    draftIcon = CompanionIconCatalog.defaultSymbol
                    isShowingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("同行者を追加")
            }
        }
        .sheet(isPresented: Binding(
            get: { isShowingCreate || editingValue != nil },
            set: { isPresented in
                if !isPresented {
                    isShowingCreate = false
                    editingValue = nil
                }
            }
        )) {
            CompanionMasterEditor(
                title: editingValue == nil ? "同行者を追加" : "同行者を編集",
                name: $draftName,
                iconSymbol: $draftIcon,
                usageCount: editingValue?.usageCount ?? 0,
                onCancel: {
                    isShowingCreate = false
                    editingValue = nil
                },
                onSave: saveDraft
            )
        }
        .confirmationDialog(
            "「\(valuePendingDeletion?.name ?? "")」を削除しますか？",
            isPresented: Binding(
                get: { valuePendingDeletion != nil },
                set: { if !$0 { valuePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let value = valuePendingDeletion {
                Button(
                    value.usageCount == 0 ? "同行者マスターを削除" : "\(value.usageCount)件の記録から削除",
                    role: .destructive
                ) {
                    delete(value)
                }
            }
            Button("キャンセル", role: .cancel) { valuePendingDeletion = nil }
        } message: {
            Text("人物・場所・写真など、ほかの記録内容は変更しません。")
        }
    }

    private func beginEditing(_ value: CompanionMasterListValue) {
        editingValue = value
        draftName = value.name
        draftIcon = value.iconSymbol
    }

    private func saveDraft() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = normalizedRecordFacetMasterName(trimmedName)
        guard !newKey.isEmpty else { return }
        let oldKey = editingValue?.id
        let now = Date()

        if let oldKey {
            replaceCompanionName(oldKey: oldKey, newName: trimmedName, now: now)
        }

        let sourceMaster = editingValue?.masterID.flatMap { id in companions.first { $0.id == id } }
        let destinationMaster = companions.first {
            !$0.isArchived && $0.id != sourceMaster?.id
                && (normalizedRecordFacetMasterName($0.name) == newKey || $0.normalizedName == newKey)
        }

        if let destinationMaster {
            destinationMaster.name = trimmedName
            destinationMaster.normalizedName = newKey
            destinationMaster.iconSymbol = CompanionIconCatalog.validated(draftIcon)
            destinationMaster.updatedAt = now
            if let sourceMaster {
                modelContext.delete(sourceMaster)
            }
        } else if let sourceMaster {
            sourceMaster.name = trimmedName
            sourceMaster.normalizedName = newKey
            sourceMaster.iconSymbol = CompanionIconCatalog.validated(draftIcon)
            sourceMaster.updatedAt = now
        } else {
            modelContext.insert(CompanionMaster(
                name: trimmedName,
                normalizedName: newKey,
                iconSymbol: CompanionIconCatalog.validated(draftIcon),
                createdAt: now,
                updatedAt: now
            ))
        }

        do {
            try modelContext.save()
            errorMessage = ""
            isShowingCreate = false
            editingValue = nil
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func delete(_ value: CompanionMasterListValue) {
        let now = Date()
        for visit in visits {
            let names = recordFacetMasterNames(from: visit.companionNamesRaw)
            guard names.contains(where: { normalizedRecordFacetMasterName($0) == value.id }) else { continue }
            visit.companionNamesRaw = deduplicatedRecordFacetMasterNames(
                names.filter { normalizedRecordFacetMasterName($0) != value.id }
            ).joined(separator: "、")
            visit.updatedAt = now
        }
        companions.filter {
            $0.id == value.masterID
                || normalizedRecordFacetMasterName($0.name) == value.id
                || $0.normalizedName == value.id
        }.forEach(modelContext.delete)

        do {
            try modelContext.save()
            errorMessage = ""
            valuePendingDeletion = nil
        } catch {
            modelContext.rollback()
            errorMessage = "削除できませんでした: \(error.localizedDescription)"
        }
    }

    private func replaceCompanionName(oldKey: String, newName: String, now: Date) {
        for visit in visits {
            let currentNames = recordFacetMasterNames(from: visit.companionNamesRaw)
            guard currentNames.contains(where: { normalizedRecordFacetMasterName($0) == oldKey }) else { continue }
            visit.companionNamesRaw = deduplicatedRecordFacetMasterNames(currentNames.map {
                normalizedRecordFacetMasterName($0) == oldKey ? newName : $0
            }).joined(separator: "、")
            visit.updatedAt = now
        }
    }
}

private struct CompanionMasterEditor: View {
    let title: String
    @Binding var name: String
    @Binding var iconSymbol: String
    let usageCount: Int
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("同行者") {
                    HStack(spacing: 12) {
                        Image(systemName: CompanionIconCatalog.validated(iconSymbol))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor.opacity(0.12), in: Circle())
                        TextField("名前", text: $name)
                    }
                }

                Section("アイコン") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                        ForEach(CompanionIconCatalog.symbols, id: \.self) { symbol in
                            Button {
                                iconSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(iconSymbol == symbol ? Color.white : Color.accentColor)
                                    .background(iconSymbol == symbol ? Color.accentColor : Color.accentColor.opacity(0.1), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("アイコン \(symbol)")
                            .accessibilityValue(iconSymbol == symbol ? "選択中" : "未選択")
                        }
                    }
                    .padding(.vertical, 4)
                }

                if usageCount > 0 {
                    Section {
                        Text("名前を変更すると、関連する\(usageCount)件の記録に反映されます。アイコンの変更では記録内容を変更しません。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum CompanionIconCatalog {
    static let defaultSymbol = "person.crop.circle"
    static let symbols = [
        "person.crop.circle", "person.circle", "person.2.circle", "figure.2",
        "heart.circle", "star.circle", "face.smiling", "hand.thumbsup",
        "figure.walk", "figure.run", "car.circle", "tram.circle",
        "cup.and.saucer", "fork.knife.circle", "camera.circle", "music.note",
        "gamecontroller", "book.circle", "pawprint.circle", "house.circle",
    ]

    static func validated(_ symbol: String?) -> String {
        guard let symbol, symbols.contains(symbol) else { return defaultSymbol }
        return symbol
    }
}

func recordFacetMasterValues(
    in visits: [Visit],
    kind: RecordFacetMasterKind
) -> [RecordFacetMasterValue] {
    var displayNames: [String: String] = [:]
    var usageCounts: [String: Int] = [:]

    for visit in visits {
        let uniqueNames = deduplicatedRecordFacetMasterNames(
            recordFacetMasterNames(from: kind.rawValue(from: visit))
        )
        for name in uniqueNames {
            let key = normalizedRecordFacetMasterName(name)
            displayNames[key] = displayNames[key] ?? name
            usageCounts[key, default: 0] += 1
        }
    }

    return usageCounts.compactMap { key, count in
        guard let name = displayNames[key] else { return nil }
        return RecordFacetMasterValue(name: name, usageCount: count)
    }
    .sorted {
        if $0.usageCount != $1.usageCount { return $0.usageCount > $1.usageCount }
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
}

private func recordFacetMasterNames(from rawValue: String) -> [String] {
    rawValue
        .components(separatedBy: CharacterSet(charactersIn: ",、;；\n"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func deduplicatedRecordFacetMasterNames(_ names: [String]) -> [String] {
    var seen = Set<String>()
    return names.filter { seen.insert(normalizedRecordFacetMasterName($0)).inserted }
}

func normalizedRecordFacetMasterName(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}
