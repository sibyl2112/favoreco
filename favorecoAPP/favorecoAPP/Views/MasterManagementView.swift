import CoreLocation
import SwiftData
import SwiftUI

struct PersonMasterManagementView: View {
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var searchText = ""
    @State private var isShowingCreatePerson = false

    private var activePeople: [PersonMaster] {
        let active = people.filter { !$0.isArchived }
        let query = normalizedMasterText(searchText)
        guard !query.isEmpty else { return active }
        return active.filter {
            normalizedMasterText($0.displayName).contains(query)
                || normalizedMasterText($0.reading).contains(query)
                || $0.aliasesRaw.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
                    .contains { normalizedMasterText($0).contains(query) }
        }
    }

    var body: some View {
        List {
            if activePeople.isEmpty {
                ContentUnavailableView("人物・団体はまだありません", systemImage: "person.2")
            } else {
                ForEach(activePeople) { person in
                    NavigationLink {
                        PersonMasterMergeView(person: person)
                    } label: {
                        MasterListRow(
                            title: person.displayName,
                            subtitle: person.reading,
                            countLabel: "\(person.eventLinks?.count ?? 0)件の紐付け",
                            systemImage: person.favoriteProfile?.isFavorite == true
                                ? "person.crop.circle.fill.badge.heart"
                                : "person.crop.circle"
                        )
                    }
                }
            }
        }
        .navigationTitle("人物・団体マスター")
        .searchable(text: $searchText, prompt: "名前・よみ・別名を検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreatePerson = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("人物・団体を追加")
            }
        }
        .sheet(isPresented: $isShowingCreatePerson) {
            PersonMasterCreateView()
        }
    }
}

private struct PersonMasterCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var displayName = ""
    @State private var reading = ""
    @State private var roleTagsRaw = ""
    @State private var aliasesRaw = ""
    @State private var officialURL = ""
    @State private var socialLinksRaw = ""
    @State private var memo = ""
    @State private var showsOptionalFields = false
    @State private var errorMessage = ""

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("表示名", text: $displayName)
                    TextField("よみ（任意）", text: $reading)
                    TextField("タグ（カンマ区切り）", text: $roleTagsRaw)
                }

                Section {
                    DisclosureGroup("詳細オプション", isExpanded: $showsOptionalFields) {
                        TextField("別名（カンマ区切り）", text: $aliasesRaw)
                        TextField("公式URL", text: $officialURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        TextField("SNS・参考リンク（1行1件）", text: $socialLinksRaw, axis: .vertical)
                            .lineLimit(2...6)
                        TextField("メモ", text: $memo, axis: .vertical)
                            .lineLimit(3...8)
                    }
                }

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("人物・団体を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let now = Date()
        modelContext.insert(PersonMaster(
            displayName: trimmedName,
            reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
            aliasesRaw: aliasesRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            roleTagsRaw: roleTagsRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            officialURL: officialURL.trimmingCharacters(in: .whitespacesAndNewlines),
            socialLinksRaw: socialLinksRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedName: normalizedMasterText(trimmedName),
            createdAt: now,
            updatedAt: now
        ))
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }
}

struct PlaceMasterManagementView: View {
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @State private var searchText = ""
    @State private var selectedArea: JapanArea?
    @State private var prefectureFilter: PlacePrefectureFilter = .all

    private var allActivePlaces: [PlaceMaster] {
        places.filter { !$0.isArchived }
    }

    private var activePlaces: [PlaceMaster] {
        let query = normalizedMasterText(searchText)
        return allActivePlaces.filter { place in
            let prefecture = resolvedPrefecture(for: place)
            let matchesArea = selectedArea?.includes(prefecture: prefecture) ?? true
            let matchesPrefecture: Bool
            switch prefectureFilter {
            case .all:
                matchesPrefecture = true
            case .missing:
                matchesPrefecture = prefecture.isEmpty
            case let .prefecture(value):
                matchesPrefecture = prefecture == value
            }
            let matchesSearch = query.isEmpty
                || normalizedMasterText(place.name).contains(query)
                || normalizedMasterText(place.reading).contains(query)
                || normalizedMasterText(place.address).contains(query)
                || normalizedMasterText(prefecture).contains(query)
                || place.aliasesRaw.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
                    .contains { normalizedMasterText($0).contains(query) }
            return matchesArea && matchesPrefecture && matchesSearch
        }
    }

    private var prefectureOptions: [String] {
        selectedArea?.prefectures ?? JapanPrefecture.all
    }

    private var missingPrefectureCount: Int {
        allActivePlaces.filter { resolvedPrefecture(for: $0).isEmpty }.count
    }

    var body: some View {
        List {
            Section("絞り込み") {
                Picker("エリア", selection: $selectedArea) {
                    Text("全国").tag(JapanArea?.none)
                    ForEach(JapanArea.allCases) { area in
                        Text(area.title).tag(Optional(area))
                    }
                }

                Picker("都道府県", selection: $prefectureFilter) {
                    Text("すべて").tag(PlacePrefectureFilter.all)
                    ForEach(prefectureOptions, id: \.self) { prefecture in
                        Text(prefecture).tag(PlacePrefectureFilter.prefecture(prefecture))
                    }
                    if missingPrefectureCount > 0, selectedArea == nil {
                        Text("未設定（\(missingPrefectureCount)件）").tag(PlacePrefectureFilter.missing)
                    }
                }

                LabeledContent("表示件数", value: "\(activePlaces.count) / \(allActivePlaces.count)件")
            }

            Section {
                if activePlaces.isEmpty {
                    ContentUnavailableView(
                        allActivePlaces.isEmpty ? "場所はまだありません" : "条件に一致する場所がありません",
                        systemImage: "mappin.and.ellipse"
                    )
                } else {
                    ForEach(activePlaces) { place in
                        NavigationLink {
                            PlaceMasterMergeView(place: place)
                        } label: {
                            MasterListRow(
                                title: place.name,
                                subtitle: place.address.isEmpty ? resolvedPrefecture(for: place) : place.address,
                                countLabel: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件の利用",
                                systemImage: "mappin.circle"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("場所マスター")
        .searchable(text: $searchText, prompt: "名称・住所・別名を検索")
        .onChange(of: selectedArea) { _, area in
            switch prefectureFilter {
            case .all:
                break
            case .missing:
                prefectureFilter = .all
            case let .prefecture(prefecture):
                if let area, !area.includes(prefecture: prefecture) {
                    prefectureFilter = .all
                }
            }
        }
    }
}

private enum PlacePrefectureFilter: Hashable {
    case all
    case prefecture(String)
    case missing
}

private struct PersonMasterMergeView: View {
    let person: PersonMaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var draft: PersonMasterDraft
    @State private var favoriteDraft: FavoriteProfileDraft
    @State private var showsOptionalFields = false
    @State private var selectedDestination: PersonMaster?
    @State private var errorMessage = ""

    init(person: PersonMaster) {
        self.person = person
        _draft = State(initialValue: PersonMasterDraft(person: person))
        _favoriteDraft = State(initialValue: FavoriteProfileDraft(profile: person.favoriteProfile))
    }

    private var candidates: [PersonMaster] {
        people.filter { !$0.isArchived && $0.id != person.id && isSimilarPerson($0, person) }
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("表示名", text: $draft.displayName)
                TextField("よみ（任意）", text: $draft.reading)
                TextField("別名（カンマ区切り）", text: $draft.aliasesRaw)
                TextField("タグ（カンマ区切り）", text: $draft.roleTagsRaw)
                LabeledContent("紐付け", value: "\(person.eventLinks?.count ?? 0)件")
            }

            Section {
                DisclosureGroup("詳細オプション", isExpanded: $showsOptionalFields) {
                    TextField("公式URL", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("SNS・参考リンク（1行1件）", text: $draft.socialLinksRaw, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("メモ", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }
            }

            Section("FAVO") {
                Toggle("この人物・団体を推しにする", isOn: $favoriteDraft.isFavorite)

                if favoriteDraft.isFavorite {
                    Toggle("最推し", isOn: $favoriteDraft.isPrimary)
                    Toggle("上部に固定", isOn: $favoriteDraft.isPinned)
                    TextField("自分が使う呼び名（任意）", text: $favoriteDraft.nickname)
                    ColorPicker(
                        "推しカラー",
                        selection: Binding(
                            get: { Color(hex: favoriteDraft.colorHex) },
                            set: { favoriteDraft.colorHex = $0.hexString() ?? favoriteDraft.colorHex }
                        ),
                        supportsOpacity: false
                    )
                    Toggle("推し始めた日を設定", isOn: $favoriteDraft.hasStartedAt)
                    if favoriteDraft.hasStartedAt {
                        DatePicker("推し始めた日", selection: $favoriteDraft.startedAt, displayedComponents: .date)
                        Toggle("初日を1日目に含める", isOn: $favoriteDraft.includesStartDay)
                    }
                    TextField("推したきっかけ（任意）", text: $favoriteDraft.originText, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("自分だけのメモ（任意）", text: $favoriteDraft.memo, axis: .vertical)
                        .lineLimit(3...8)
                }
            }

            Section("似た人物・団体") {
                if candidates.isEmpty {
                    Text("統合候補はありません。名称・よみ・別名が近い候補をここに表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { candidate in
                        Button {
                            selectedDestination = candidate
                        } label: {
                            MasterCandidateRow(
                                title: candidate.displayName,
                                subtitle: candidate.reading,
                                countLabel: "\(candidate.eventLinks?.count ?? 0)件の紐付け"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(person.displayName)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!draft.canSave)
            }
        }
        .confirmationDialog(
            "人物・団体を統合しますか？",
            isPresented: Binding(get: { selectedDestination != nil }, set: { if !$0 { selectedDestination = nil } }),
            titleVisibility: .visible
        ) {
            if let destination = selectedDestination {
                Button("「\(destination.displayName)」へ統合", role: .destructive) {
                    merge(into: destination)
                }
            }
            Button("キャンセル", role: .cancel) { selectedDestination = nil }
        } message: {
            Text("すべての人物リンクとFAVO設定を統合先へ付け替え、現在のマスターをアーカイブします。過去の表示名スナップショットは変更しません。")
        }
    }

    private func merge(into destination: PersonMaster) {
        do {
            try MasterMergeService.merge(person: person, into: destination, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "統合できませんでした: \(error.localizedDescription)"
        }
    }

    private func save() {
        person.displayName = draft.trimmedDisplayName
        person.reading = draft.trimmedReading
        person.aliasesRaw = draft.trimmedAliasesRaw
        person.roleTagsRaw = draft.trimmedRoleTagsRaw
        person.officialURL = draft.trimmedOfficialURL
        person.socialLinksRaw = draft.trimmedSocialLinksRaw
        person.memo = draft.trimmedMemo
        person.normalizedName = normalizedMasterText(draft.trimmedDisplayName)
        person.updatedAt = Date()
        do {
            try saveFavoriteProfile()
            try modelContext.save()
            errorMessage = ""
        } catch {
            modelContext.rollback()
            draft = PersonMasterDraft(person: person)
            favoriteDraft = FavoriteProfileDraft(profile: person.favoriteProfile)
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func saveFavoriteProfile() throws {
        let now = Date()
        let profile: FavoriteProfile
        if let existing = person.favoriteProfile {
            profile = existing
        } else {
            guard favoriteDraft.isFavorite else { return }
            profile = FavoriteProfile(person: person)
            modelContext.insert(profile)
            person.favoriteProfile = profile
        }

        if favoriteDraft.isFavorite, favoriteDraft.isPrimary {
            let profiles = try modelContext.fetch(FetchDescriptor<FavoriteProfile>())
            for other in profiles where other.id != profile.id && other.isPrimary {
                other.isPrimary = false
                other.updatedAt = now
            }
        }

        profile.isFavorite = favoriteDraft.isFavorite
        profile.isPrimary = favoriteDraft.isFavorite && favoriteDraft.isPrimary
        profile.isPinned = favoriteDraft.isFavorite && favoriteDraft.isPinned
        profile.startedAt = favoriteDraft.startedAt
        profile.hasStartedAt = favoriteDraft.isFavorite && favoriteDraft.hasStartedAt
        profile.includesStartDay = favoriteDraft.includesStartDay
        profile.colorHex = favoriteDraft.colorHex
        profile.nickname = favoriteDraft.trimmedNickname
        profile.originText = favoriteDraft.trimmedOriginText
        profile.memo = favoriteDraft.trimmedMemo
        profile.updatedAt = now
        profile.person = person
    }
}

private struct PlaceMasterMergeView: View {
    let place: PlaceMaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @State private var draft: PlaceMasterDraft
    @State private var showsOptionalFields = false
    @State private var selectedDestination: PlaceMaster?
    @State private var errorMessage = ""

    init(place: PlaceMaster) {
        self.place = place
        _draft = State(initialValue: PlaceMasterDraft(place: place))
    }

    private var candidates: [PlaceMaster] {
        places.filter { !$0.isArchived && $0.id != place.id && isSimilarPlace($0, place) }
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("名称", text: $draft.name)
                TextField("よみ（任意）", text: $draft.reading)
                Picker("都道府県（必須）", selection: $draft.prefecture) {
                    Text("選択してください").tag("")
                    ForEach(JapanArea.allCases) { area in
                        Section(area.title) {
                            ForEach(area.prefectures, id: \.self) { prefecture in
                                Text(prefecture).tag(prefecture)
                            }
                        }
                    }
                }
                TextField("住所", text: $draft.address)
                    .textContentType(.fullStreetAddress)
                TextField("別名（カンマ区切り）", text: $draft.aliasesRaw)
                TextField("タグ（カンマ区切り）", text: $draft.placeTagsRaw)
                LabeledContent("利用", value: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件")
            }

            Section("巡礼・札所") {
                if draft.pilgrimageMemberships.isEmpty {
                    Text("西国・坂東・四国など、霊場名と札所番号を必要な場所だけ登録できます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(draft.pilgrimageMemberships.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("巡礼・霊場名", text: $draft.pilgrimageMemberships[index].pilgrimageName)
                        HStack {
                            TextField(
                                "札所番号",
                                text: Binding(
                                    get: {
                                        draft.pilgrimageMemberships[index].siteNumber.map(String.init) ?? ""
                                    },
                                    set: { value in
                                        let digits = value.filter(\.isNumber)
                                        draft.pilgrimageMemberships[index].siteNumber = Int(digits)
                                        let currentLabel = draft.pilgrimageMemberships[index].siteNumberLabel
                                        if currentLabel.isEmpty || currentLabel.hasPrefix("第") {
                                            draft.pilgrimageMemberships[index].siteNumberLabel = Int(digits).map { "第\($0)番" } ?? ""
                                        }
                                    }
                                )
                            )
                            .keyboardType(.numberPad)

                            TextField("表示（番外など）", text: $draft.pilgrimageMemberships[index].siteNumberLabel)
                        }
                        Button("この所属を削除", role: .destructive) {
                            draft.pilgrimageMemberships.remove(at: index)
                        }
                        .font(FavorecoTypography.caption)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    draft.pilgrimageMemberships.append(PlacePilgrimageMembership())
                } label: {
                    Label("巡礼・札所を追加", systemImage: "plus.circle")
                }
            }

            Section {
                DisclosureGroup("詳細オプション", isExpanded: $showsOptionalFields) {
                    TextField("公式URL", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("メモ", text: $draft.memo, axis: .vertical)
                        .lineLimit(3...8)
                    if place.latitude != 0 || place.longitude != 0 {
                        LabeledContent("保存座標", value: String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    }
                }
            }

            Section("同じ場所の可能性") {
                if candidates.isEmpty {
                    Text("統合候補はありません。名称、住所、座標が近い候補をここに表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { candidate in
                        Button {
                            selectedDestination = candidate
                        } label: {
                            MasterCandidateRow(
                                title: candidate.name,
                                subtitle: candidate.address,
                                countLabel: "\((candidate.visits?.count ?? 0) + (candidate.plans?.count ?? 0))件の利用"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(place.name)
        .onChange(of: draft.address) { _, address in
            let extractedPrefecture = JapanPrefecture.extract(from: address)
            if !extractedPrefecture.isEmpty {
                draft.prefecture = extractedPrefecture
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!draft.canSave)
            }
        }
        .confirmationDialog(
            "場所を統合しますか？",
            isPresented: Binding(get: { selectedDestination != nil }, set: { if !$0 { selectedDestination = nil } }),
            titleVisibility: .visible
        ) {
            if let destination = selectedDestination {
                Button("「\(destination.name)」へ統合", role: .destructive) {
                    merge(into: destination)
                }
            }
            Button("キャンセル", role: .cancel) { selectedDestination = nil }
        } message: {
            Text("記録と予定の場所参照を統合先へ付け替え、現在のマスターをアーカイブします。記録に保存した施設名・住所・座標は変更しません。")
        }
    }

    private func merge(into destination: PlaceMaster) {
        do {
            try MasterMergeService.merge(place: place, into: destination, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "統合できませんでした: \(error.localizedDescription)"
        }
    }

    private func save() {
        place.name = draft.trimmedName
        place.reading = draft.trimmedReading
        place.prefecture = draft.trimmedPrefecture
        place.address = draft.trimmedAddress
        place.aliasesRaw = draft.trimmedAliasesRaw
        place.placeTagsRaw = draft.trimmedPlaceTagsRaw
        place.pilgrimageMembershipsRaw = PlacePilgrimageMembership.encode(draft.validPilgrimageMemberships)
        place.officialURL = draft.trimmedOfficialURL
        place.memo = draft.trimmedMemo
        place.normalizedName = normalizedMasterText(draft.trimmedName)
        place.normalizedAddress = normalizedMasterText(draft.trimmedAddress)
        place.updatedAt = Date()
        do {
            try modelContext.save()
            errorMessage = ""
        } catch {
            modelContext.rollback()
            draft = PlaceMasterDraft(place: place)
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }
}

private struct PersonMasterDraft {
    var displayName: String
    var reading: String
    var aliasesRaw: String
    var roleTagsRaw: String
    var memo: String
    var officialURL: String
    var socialLinksRaw: String

    init(person: PersonMaster) {
        displayName = person.displayName
        reading = person.reading
        aliasesRaw = person.aliasesRaw
        roleTagsRaw = person.roleTagsRaw
        memo = person.memo
        officialURL = person.officialURL
        socialLinksRaw = person.socialLinksRaw
    }

    var trimmedDisplayName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedReading: String { reading.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedAliasesRaw: String { aliasesRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedRoleTagsRaw: String { roleTagsRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSocialLinksRaw: String { socialLinksRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedDisplayName.isEmpty }
}

private struct FavoriteProfileDraft {
    var isFavorite: Bool
    var isPrimary: Bool
    var isPinned: Bool
    var startedAt: Date
    var hasStartedAt: Bool
    var includesStartDay: Bool
    var colorHex: String
    var nickname: String
    var originText: String
    var memo: String

    init(profile: FavoriteProfile?) {
        isFavorite = profile?.isFavorite ?? false
        isPrimary = profile?.isPrimary ?? false
        isPinned = profile?.isPinned ?? false
        startedAt = profile?.startedAt ?? Date()
        hasStartedAt = profile?.hasStartedAt ?? false
        includesStartDay = profile?.includesStartDay ?? true
        colorHex = profile?.colorHex ?? "#8F5E73"
        nickname = profile?.nickname ?? ""
        originText = profile?.originText ?? ""
        memo = profile?.memo ?? ""
    }

    var trimmedNickname: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOriginText: String { originText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct PlaceMasterDraft {
    var name: String
    var reading: String
    var aliasesRaw: String
    var placeTagsRaw: String
    var prefecture: String
    var address: String
    var officialURL: String
    var memo: String
    var pilgrimageMemberships: [PlacePilgrimageMembership]

    init(place: PlaceMaster) {
        name = place.name
        reading = place.reading
        aliasesRaw = place.aliasesRaw
        placeTagsRaw = place.placeTagsRaw
        prefecture = place.prefecture.isEmpty ? JapanPrefecture.extract(from: place.address) : place.prefecture
        address = place.address
        officialURL = place.officialURL
        memo = place.memo
        pilgrimageMemberships = PlacePilgrimageMembership.decode(place.pilgrimageMembershipsRaw)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedReading: String { reading.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedAliasesRaw: String { aliasesRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPlaceTagsRaw: String { placeTagsRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPrefecture: String { prefecture.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
    var validPilgrimageMemberships: [PlacePilgrimageMembership] {
        pilgrimageMemberships.filter {
            !$0.pilgrimageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (($0.siteNumber ?? 0) > 0 || !$0.siteNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    var canSave: Bool {
        !trimmedName.isEmpty &&
            JapanPrefecture.all.contains(trimmedPrefecture) &&
            validPilgrimageMemberships.count == pilgrimageMemberships.count
    }
}

private struct MasterListRow: View {
    let title: String
    let subtitle: String
    let countLabel: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(FavorecoTypography.bodyStrong)
                if !subtitle.isEmpty { Text(subtitle).font(FavorecoTypography.caption).foregroundStyle(.secondary) }
                Text(countLabel).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MasterCandidateRow: View {
    let title: String
    let subtitle: String
    let countLabel: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(FavorecoTypography.bodyStrong)
                if !subtitle.isEmpty { Text(subtitle).font(FavorecoTypography.caption).foregroundStyle(.secondary) }
                Text(countLabel).font(FavorecoTypography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.triangle.merge").foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
    }
}

private func isSimilarPerson(_ lhs: PersonMaster, _ rhs: PersonMaster) -> Bool {
    let leftName = normalizedMasterText(lhs.displayName)
    let rightName = normalizedMasterText(rhs.displayName)
    if !leftName.isEmpty, leftName == rightName { return true }
    if min(leftName.count, rightName.count) >= 2, leftName.contains(rightName) || rightName.contains(leftName) { return true }
    let leftReading = normalizedMasterText(lhs.reading)
    let rightReading = normalizedMasterText(rhs.reading)
    if !leftReading.isEmpty, leftReading == rightReading { return true }
    let leftAliases = normalizedMasterTerms(lhs.aliasesRaw)
    let rightAliases = normalizedMasterTerms(rhs.aliasesRaw)
    return leftAliases.contains(rightName) || rightAliases.contains(leftName) || !leftAliases.isDisjoint(with: rightAliases)
}

private func isSimilarPlace(_ lhs: PlaceMaster, _ rhs: PlaceMaster) -> Bool {
    let leftName = normalizedMasterText(lhs.name)
    let rightName = normalizedMasterText(rhs.name)
    let sameName = !leftName.isEmpty && leftName == rightName
    let leftAddress = normalizedMasterText(lhs.address)
    let rightAddress = normalizedMasterText(rhs.address)
    let sameAddress = !leftAddress.isEmpty && leftAddress == rightAddress
    let nearby: Bool
    if lhs.latitude != 0, lhs.longitude != 0, rhs.latitude != 0, rhs.longitude != 0 {
        nearby = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)) <= 150
    } else {
        nearby = false
    }
    return sameAddress || nearby || (sameName && (leftAddress.isEmpty || rightAddress.isEmpty))
}

private func resolvedPrefecture(for place: PlaceMaster) -> String {
    place.prefecture.isEmpty ? JapanPrefecture.extract(from: place.address) : place.prefecture
}

private func normalizedMasterTerms(_ value: String) -> Set<String> {
    Set(value.components(separatedBy: CharacterSet(charactersIn: ",、\n")).map(normalizedMasterText).filter { !$0.isEmpty })
}

private func normalizedMasterText(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
