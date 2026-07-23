import CoreLocation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PersonMasterManagementView: View {
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var searchText = ""
    @State private var isShowingCreatePerson = false
    @State private var selectedActivityTagIDs: Set<String> = []
    @State private var favoritesOnly = false

    private var activePeople: [PersonMaster] {
        let active = people.filter { !$0.isArchived }
        let query = normalizedMasterText(searchText)
        return active.filter { person in
            let matchesSearch = query.isEmpty
                || PersonMasterSuggestion.matches(person, query: searchText)
                || PersonActivityTags.displayTitles(from: person.roleTagsRaw)
                    .contains { normalizedMasterText($0).contains(query) }
            let matchesFavorite = !favoritesOnly || person.favoriteProfile?.isFavorite == true
            let matchesActivity = PersonActivityTags.matchesAny(selectedActivityTagIDs, rawValue: person.roleTagsRaw)
            return matchesSearch && matchesFavorite && matchesActivity
        }
    }

    private var availableActivityTags: [PersonActivityTag] {
        let usedIDs = Set(people.filter { !$0.isArchived }.flatMap {
            PersonActivityTags.selectedPresetIDs(from: $0.roleTagsRaw)
        })
        return PersonActivityTags.presets.filter { usedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                PersonActivityFilterBar(
                    availableTags: availableActivityTags,
                    selectedIDs: $selectedActivityTagIDs,
                    favoritesOnly: $favoritesOnly
                )
            }

            if activePeople.isEmpty {
                ContentUnavailableView(
                    people.contains(where: { !$0.isArchived }) ? "条件に一致する人物・団体がありません" : "人物・団体はまだありません",
                    systemImage: "person.2"
                )
            } else {
                ForEach(activePeople) { person in
                    NavigationLink {
                        PersonMasterMergeView(person: person)
                    } label: {
                        PersonMasterListRow(person: person)
                    }
                }
            }
        }
        .navigationTitle("人物・団体マスター")
        .searchable(text: $searchText, prompt: "名前・よみ・別名・愛称を検索")
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
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var displayName = ""
    @State private var entityKind = PersonEntityKind.person
    @State private var parentOrganizationID: UUID?
    @State private var reading = ""
    @State private var roleTagsRaw = ""
    @State private var aliasesRaw = ""
    @State private var officialURL = ""
    @State private var socialLinksRaw = ""
    @State private var memo = ""
    @State private var showsOptionalFields = false
    @State private var errorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoErrorMessage = ""

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        PersonMasterSuggestion.matching(people, query: trimmedName)
    }

    private var hasExactMatch: Bool {
        PersonMasterSuggestion.exactMatch(in: people, query: trimmedName) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    PersonPhotoEditor(
                        storedData: nil,
                        storedPath: "",
                        selectedData: $selectedPhotoData,
                        selectedPhoto: $selectedPhoto,
                        removesStoredPhoto: .constant(false)
                    )
                    TextField("表示名", text: $displayName)
                    TextField("よみ（任意）", text: $reading)
                    Picker("区分", selection: $entityKind) {
                        ForEach(PersonEntityKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    if entityKind == .organization {
                        Picker("所属する上位団体", selection: $parentOrganizationID) {
                            Text("なし").tag(UUID?.none)
                            ForEach(people.filter { !$0.isArchived && $0.isOrganization }) { organization in
                                Text(organization.displayName).tag(Optional(organization.id))
                            }
                        }
                    }
                }

                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { person in
                            NavigationLink {
                                PersonMasterMergeView(person: person)
                            } label: {
                                MasterCandidateRow(
                                    title: person.displayName,
                                    subtitle: PersonMasterSuggestion.subtitle(for: person),
                                    countLabel: "\(person.eventLinks?.count ?? 0)件の紐付け"
                                )
                            }
                        }
                    } header: {
                        Text("登録済み候補")
                    } footer: {
                        Text("名前・よみ・別名が一致する人物は、新規作成せず登録済み候補を確認してください。")
                    }
                }

                PersonActivityTagEditor(rawValue: $roleTagsRaw)

                Section {
                    DisclosureGroup("詳細オプション", isExpanded: $showsOptionalFields) {
                        TextField("別名・愛称（カンマ区切り）", text: $aliasesRaw)
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
                if !photoErrorMessage.isEmpty {
                    Section { Text(photoErrorMessage).foregroundStyle(.red) }
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
                        .disabled(trimmedName.isEmpty || hasExactMatch)
                }
            }
            .task(id: selectedPhoto) {
                await loadSelectedPersonPhoto()
            }
        }
    }

    private func save() {
        if let existing = PersonMasterSuggestion.exactMatch(in: people, query: trimmedName) {
            errorMessage = "「\(existing.displayName)」が登録済みです。候補から開いてください。"
            return
        }
        let now = Date()
        let person = PersonMaster(
            displayName: trimmedName,
            entityKindKey: entityKind.rawValue,
            parentOrganizationIDRaw: entityKind == .organization ? parentOrganizationID?.uuidString ?? "" : "",
            reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
            aliasesRaw: aliasesRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            roleTagsRaw: roleTagsRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            officialURL: officialURL.trimmingCharacters(in: .whitespacesAndNewlines),
            socialLinksRaw: socialLinksRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedName: normalizedMasterText(trimmedName),
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(person)
        do {
            person.imageData = selectedPhotoData
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadSelectedPersonPhoto() async {
        guard let selectedPhoto else { return }
        guard let data = try? await selectedPhoto.loadTransferable(type: Data.self),
              let processed = PersonImageStore.processedAvatarData(from: data) else {
            photoErrorMessage = "写真を読み込めませんでした。別の写真を選んでください。"
            return
        }
        selectedPhotoData = processed
        photoErrorMessage = ""
    }
}

struct PlaceMasterManagementView: View {
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @State private var searchText = ""
    @State private var selectedArea: JapanArea?
    @State private var prefectureFilter: PlacePrefectureFilter = .all
    @State private var categoryFilter: PlaceMasterCategoryFilter = .all
    @State private var statusFilter: PlaceMasterStatusFilter = .all
    @State private var isShowingPublicCatalog = false

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
                || PlaceMasterCategories.displayTitles(from: place.placeTagsRaw)
                    .contains { normalizedMasterText($0).contains(query) }
                || place.aliasesRaw.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
                    .contains { normalizedMasterText($0).contains(query) }
            let matchesCategory: Bool
            switch categoryFilter {
            case .all:
                matchesCategory = true
            case .missing:
                matchesCategory = PlaceMasterCategories.resolvedCategories(from: place.placeTagsRaw).isEmpty
            case let .category(category):
                matchesCategory = PlaceMasterCategories.contains(category, rawValue: place.placeTagsRaw)
            }
            let matchesStatus: Bool
            switch statusFilter {
            case .all:
                matchesStatus = true
            case .open:
                matchesStatus = place.operationalStatus == .open
            case .closed:
                matchesStatus = place.isClosed
            case .unknown:
                matchesStatus = place.operationalStatus == .unknown
            }
            return matchesArea && matchesPrefecture && matchesCategory && matchesStatus && matchesSearch
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

                Picker("カテゴリ", selection: $categoryFilter) {
                    Text("すべて").tag(PlaceMasterCategoryFilter.all)
                    ForEach(PlaceMasterCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage)
                            .tag(PlaceMasterCategoryFilter.category(category))
                    }
                    Text("未分類").tag(PlaceMasterCategoryFilter.missing)
                }

                Picker("営業状態", selection: $statusFilter) {
                    Text("すべて").tag(PlaceMasterStatusFilter.all)
                    Text("営業中").tag(PlaceMasterStatusFilter.open)
                    Text("閉館・閉園").tag(PlaceMasterStatusFilter.closed)
                    Text("未設定").tag(PlaceMasterStatusFilter.unknown)
                }

                LabeledContent("表示件数", value: "\(activePlaces.count) / \(allActivePlaces.count)件")
            }

            Section {
                if allActivePlaces.isEmpty {
                    ContentUnavailableView(
                        "場所はまだありません",
                        systemImage: "mappin.and.ellipse",
                        description: Text("MAPは記録に保存した座標だけでも表示します。場所マスターは、住所から都道府県を確認できる場所を記録・編集した時に追加されます。")
                    )
                } else if activePlaces.isEmpty {
                    ContentUnavailableView(
                        "条件に一致する場所がありません",
                        systemImage: "mappin.and.ellipse"
                    )
                } else {
                    ForEach(activePlaces) { place in
                        NavigationLink {
                            PlaceMasterMergeView(place: place)
                        } label: {
                            MasterListRow(
                                title: place.name,
                                subtitle: placeMasterSubtitle(place),
                                countLabel: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件の利用",
                                systemImage: "mappin.circle",
                                badgeText: place.isClosed ? "閉館" : nil
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("場所マスター")
        .searchable(text: $searchText, prompt: "名称・住所・別名を検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingPublicCatalog = true
                } label: {
                    Label("全国場所カタログ", systemImage: "building.2.crop.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingPublicCatalog) {
            PublicPlaceCatalogView()
        }
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

private enum PlaceMasterCategoryFilter: Hashable {
    case all
    case category(PlaceMasterCategory)
    case missing
}

private enum PlaceMasterStatusFilter: Hashable {
    case all
    case open
    case closed
    case unknown
}

private func placeMasterSubtitle(_ place: PlaceMaster) -> String {
    let location = place.address.isEmpty ? resolvedPrefecture(for: place) : place.address
    let categories = PlaceMasterCategories.displayTitles(from: place.placeTagsRaw).prefix(2).joined(separator: "・")
    return categories.isEmpty ? location : "\(categories)｜\(location)"
}

struct PersonMasterEditDestination: View {
    @Query private var people: [PersonMaster]
    let showsCancelButton: Bool

    init(personID: UUID, showsCancelButton: Bool = false) {
        _people = Query(filter: #Predicate<PersonMaster> { person in
            person.id == personID
        })
        self.showsCancelButton = showsCancelButton
    }

    var body: some View {
        if let person = people.first {
            PersonMasterMergeView(person: person, showsCancelButton: showsCancelButton)
        } else {
            ContentUnavailableView(
                "人物が見つかりません",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("人物マスターが削除または統合された可能性があります。")
            )
        }
    }
}

private struct PersonMasterMergeView: View {
    let person: PersonMaster
    let showsCancelButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var draft: PersonMasterDraft
    @State private var favoriteDraft: FavoriteProfileDraft
    @State private var showsOptionalFields = false
    @State private var selectedDestination: PersonMaster?
    @State private var errorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var removesStoredPhoto = false
    @State private var photoErrorMessage = ""

    init(person: PersonMaster, showsCancelButton: Bool = false) {
        self.person = person
        self.showsCancelButton = showsCancelButton
        _draft = State(initialValue: PersonMasterDraft(person: person))
        _favoriteDraft = State(initialValue: FavoriteProfileDraft(profile: person.favoriteProfile))
    }

    private var candidates: [PersonMaster] {
        people.filter { !$0.isArchived && $0.id != person.id && isSimilarPerson($0, person) }
    }

    var body: some View {
        Form {
            Section("基本情報") {
                PersonPhotoEditor(
                    storedData: person.imageData,
                    storedPath: person.imagePath,
                    selectedData: $selectedPhotoData,
                    selectedPhoto: $selectedPhoto,
                    removesStoredPhoto: $removesStoredPhoto
                )
                TextField("表示名", text: $draft.displayName)
                TextField("よみ（任意）", text: $draft.reading)
                TextField("別名・愛称（カンマ区切り）", text: $draft.aliasesRaw)
                Picker("区分", selection: $draft.entityKind) {
                    ForEach(PersonEntityKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                if draft.entityKind == .organization {
                    Picker("所属する上位団体", selection: $draft.parentOrganizationID) {
                        Text("なし").tag(UUID?.none)
                        ForEach(eligibleParentOrganizations(for: person.id, among: people)) { organization in
                            Text(organization.displayName).tag(Optional(organization.id))
                        }
                    }
                }
                LabeledContent("紐付け", value: "\(person.eventLinks?.count ?? 0)件")
            }

            PersonActivityTagEditor(rawValue: $draft.roleTagsRaw)

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
            if !photoErrorMessage.isEmpty {
                Section { Text(photoErrorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(person.displayName)
        .task(id: selectedPhoto) {
            await loadSelectedPersonPhoto()
        }
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
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
        let previousImagePath = person.imagePath
        person.displayName = draft.trimmedDisplayName
        person.entityKind = draft.entityKind
        person.parentOrganizationID = draft.entityKind == .organization ? draft.parentOrganizationID : nil
        person.reading = draft.trimmedReading
        person.aliasesRaw = draft.trimmedAliasesRaw
        person.roleTagsRaw = draft.trimmedRoleTagsRaw
        person.officialURL = draft.trimmedOfficialURL
        person.socialLinksRaw = draft.trimmedSocialLinksRaw
        person.memo = draft.trimmedMemo
        person.normalizedName = normalizedMasterText(draft.trimmedDisplayName)
        person.updatedAt = Date()
        do {
            if removesStoredPhoto {
                person.imageData = nil
                person.imagePath = ""
            }
            if let selectedPhotoData {
                person.imageData = selectedPhotoData
                person.imagePath = ""
            }
            try saveFavoriteProfile()
            try modelContext.save()
            if (removesStoredPhoto || selectedPhotoData != nil), !previousImagePath.isEmpty {
                try? PersonImageStore.remove(path: previousImagePath)
            }
            errorMessage = ""
            selectedPhotoData = nil
            removesStoredPhoto = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            modelContext.rollback()
            draft = PersonMasterDraft(person: person)
            favoriteDraft = FavoriteProfileDraft(profile: person.favoriteProfile)
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadSelectedPersonPhoto() async {
        guard let selectedPhoto else { return }
        guard let data = try? await selectedPhoto.loadTransferable(type: Data.self),
              let processed = PersonImageStore.processedAvatarData(from: data) else {
            photoErrorMessage = "写真を読み込めませんでした。別の写真を選んでください。"
            return
        }
        selectedPhotoData = processed
        removesStoredPhoto = false
        photoErrorMessage = ""
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
                Picker("営業状態", selection: $draft.operationalStatus) {
                    ForEach(PlaceOperationalStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                LabeledContent("利用", value: "\((place.visits?.count ?? 0) + (place.plans?.count ?? 0))件")
            }

            PlaceMasterCategoryEditor(rawValue: $draft.placeTagsRaw)

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
                    TextField("カテゴリ・タグの直接編集", text: $draft.placeTagsRaw)
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
        place.operationalStatus = draft.operationalStatus
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

private struct PersonActivityFilterBar: View {
    let availableTags: [PersonActivityTag]
    @Binding var selectedIDs: Set<String>
    @Binding var favoritesOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("絞り込み")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                if favoritesOnly || !selectedIDs.isEmpty {
                    Button("解除") {
                        favoritesOnly = false
                        selectedIDs.removeAll()
                    }
                    .font(FavorecoTypography.caption)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterCheckChip(title: "推しのみ", systemImage: "heart.fill", isSelected: favoritesOnly) {
                        favoritesOnly.toggle()
                    }
                    ForEach(availableTags) { tag in
                        FilterCheckChip(title: tag.title, systemImage: tag.systemImage, isSelected: selectedIDs.contains(tag.id)) {
                            if selectedIDs.contains(tag.id) {
                                selectedIDs.remove(tag.id)
                            } else {
                                selectedIDs.insert(tag.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FilterCheckChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Image(systemName: systemImage)
                Text(title)
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }
}

private struct PersonActivityTagEditor: View {
    @Binding var rawValue: String
    @State private var customText: String

    init(rawValue: Binding<String>) {
        _rawValue = rawValue
        _customText = State(initialValue: PersonActivityTags.customValues(from: rawValue.wrappedValue).joined(separator: ", "))
    }

    private var selectedIDs: Set<String> {
        PersonActivityTags.selectedPresetIDs(from: rawValue)
    }

    var body: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(PersonActivityTags.presets) { tag in
                    Button {
                        toggle(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                            Image(systemName: tag.systemImage)
                            Text(tag.title).lineLimit(1)
                        }
                        .font(FavorecoTypography.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(
                            selectedIDs.contains(tag.id) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedIDs.contains(tag.id) ? "選択中" : "未選択")
                }
            }

            TextField("その他の活動タグ（カンマ区切り）", text: $customText)
                .onChange(of: customText) { _, newValue in
                    updateRawValue(customText: newValue)
                }
        } header: {
            Text("活動タグ（複数選択可）")
        } footer: {
            Text("人物・団体そのものの活動分野です。作品ごとの主演・出演・監督などの役割は、各記録との紐付け側へ保存されます。")
        }
    }

    private func toggle(_ tag: PersonActivityTag) {
        var ids = selectedIDs
        if ids.contains(tag.id) {
            ids.remove(tag.id)
        } else {
            ids.insert(tag.id)
        }
        rawValue = PersonActivityTags.replacingPresets(
            with: ids,
            customValues: PersonActivityTags.values(from: customText)
        )
    }

    private func updateRawValue(customText: String) {
        rawValue = PersonActivityTags.replacingPresets(
            with: selectedIDs,
            customValues: PersonActivityTags.values(from: customText)
        )
    }
}

private struct PersonMasterListRow: View {
    let person: PersonMaster

    private var tagTitles: [String] {
        PersonActivityTags.displayTitles(from: person.roleTagsRaw)
    }

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(
                imageData: person.imageData,
                imagePath: person.imagePath,
                systemImage: PersonActivityTags.icon(
                    for: person.roleTagsRaw,
                    isFavorite: person.favoriteProfile?.isFavorite == true
                ),
                size: 42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(person.displayName)
                    .font(FavorecoTypography.bodyStrong)
                if !person.reading.isEmpty {
                    Text(person.reading)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                if !tagTitles.isEmpty {
                    Text(tagTitles.prefix(3).joined(separator: "・"))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                Text("\(person.eventLinks?.count ?? 0)件の紐付け")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PersonPhotoEditor: View {
    let storedData: Data?
    let storedPath: String
    @Binding var selectedData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var removesStoredPhoto: Bool

    private var hasPhoto: Bool {
        selectedData != nil || (!removesStoredPhoto && (storedData != nil || PersonImageStore.image(at: storedPath) != nil))
    }

    var body: some View {
        let photoActionTitle = hasPhoto ? "写真を変更" : "写真を選ぶ"
        HStack(spacing: 16) {
            Group {
                if let selectedData, let image = UIImage(data: selectedData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    PersonAvatar(
                        imageData: removesStoredPhoto ? nil : storedData,
                        imagePath: removesStoredPhoto ? "" : storedPath,
                        systemImage: "person.crop.circle",
                        size: 72
                    )
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoActionTitle, systemImage: "photo")
                }
                if hasPhoto {
                    Button("写真を削除", role: .destructive) {
                        selectedData = nil
                        selectedPhoto = nil
                        removesStoredPhoto = true
                    }
                    .font(FavorecoTypography.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PersonAvatar: View {
    let imageData: Data?
    let imagePath: String
    let systemImage: String
    let size: CGFloat

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let image = PersonImageStore.image(at: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.13)
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

enum PersonImageStore {
    private static let directoryName = "PersonImages"

    static func processedAvatarData(from sourceData: Data) -> Data? {
        guard let sourceImage = UIImage(data: sourceData), sourceImage.size.width > 0, sourceImage.size.height > 0 else {
            return nil
        }
        let outputSize = CGSize(width: 640, height: 640)
        let scale = max(outputSize.width / sourceImage.size.width, outputSize.height / sourceImage.size.height)
        let drawSize = CGSize(width: sourceImage.size.width * scale, height: sourceImage.size.height * scale)
        let origin = CGPoint(x: (outputSize.width - drawSize.width) / 2, y: (outputSize.height - drawSize.height) / 2)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: origin, size: drawSize))
        }.jpegData(compressionQuality: 0.84)
    }

    static func image(at path: String) -> UIImage? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        if let fileURL = URL(string: trimmedPath), fileURL.isFileURL,
           let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        if trimmedPath.hasPrefix("/"), let image = UIImage(contentsOfFile: trimmedPath) {
            return image
        }
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return UIImage(contentsOfFile: baseURL.appendingPathComponent(trimmedPath).path)
    }

    static func remove(path: String) throws {
        guard path.hasPrefix("\(directoryName)/"),
              let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = baseURL.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

private struct PersonMasterDraft {
    var displayName: String
    var entityKind: PersonEntityKind
    var parentOrganizationID: UUID?
    var reading: String
    var aliasesRaw: String
    var roleTagsRaw: String
    var memo: String
    var officialURL: String
    var socialLinksRaw: String

    init(person: PersonMaster) {
        displayName = person.displayName
        entityKind = person.entityKind
        parentOrganizationID = person.parentOrganizationID
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

private enum PlaceMasterCategory: String, CaseIterable, Identifiable {
    case shrineTemple = "shrine_temple"
    case landmark
    case castle
    case dam
    case liveVenue = "live_venue_category"
    case publicHall = "public_hall_category"
    case stadiumArena = "stadium_arena"
    case themePark = "theme_park_category"
    case zooAquarium = "zoo_aquarium"
    case museum
    case naturePark = "nature_park"
    case breweryIndustry = "brewery_industry"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shrineTemple: "寺社仏閣・霊場"
        case .landmark: "ランドマーク・史跡"
        case .castle: "城郭・城跡"
        case .dam: "ダム"
        case .liveVenue: "ライブ・劇場・ホール"
        case .publicHall: "公共ホール・文化会館"
        case .stadiumArena: "スタジアム・アリーナ"
        case .themePark: "テーマパーク・遊園地"
        case .zooAquarium: "動物園・水族館"
        case .museum: "美術館・博物館"
        case .naturePark: "自然・公園・庭園"
        case .breweryIndustry: "醸造・産業観光"
        }
    }

    var systemImage: String {
        switch self {
        case .shrineTemple: "building.columns"
        case .landmark: "mappin.and.ellipse"
        case .castle: "building.columns.fill"
        case .dam: "drop.triangle.fill"
        case .liveVenue: "music.mic"
        case .publicHall: "building.2.crop.circle"
        case .stadiumArena: "sportscourt"
        case .themePark: "ferris.wheel"
        case .zooAquarium: "pawprint"
        case .museum: "building.2"
        case .naturePark: "leaf"
        case .breweryIndustry: "gearshape.2"
        }
    }

    var canonicalTag: String {
        switch self {
        case .shrineTemple: "sacred_site"
        case .landmark: "landmark"
        case .castle: "castle"
        case .dam: "dam"
        case .liveVenue: "music_venue"
        case .publicHall: "public_hall"
        case .stadiumArena: "arena"
        case .themePark: "theme_park"
        case .zooAquarium: "zoo_aquarium"
        case .museum: "museum"
        case .naturePark: "nature_park"
        case .breweryIndustry: "industrial_tourism"
        }
    }

    var matchingTags: Set<String> {
        switch self {
        case .shrineTemple:
            ["shrine", "temple", "buddhist_temple", "sacred_site", "pilgrimage_site"]
        case .landmark:
            ["landmark", "historic_site", "castle", "tower", "observation_deck", "bridge", "monument"]
        case .castle:
            ["castle", "japan_100_castles", "continued_japan_100_castles"]
        case .dam:
            ["dam", "reservoir", "hydroelectric_dam"]
        case .liveVenue:
            ["live_house", "music_venue", "concert_hall", "theater", "performing_arts_venue", "cultural_venue"]
        case .publicHall:
            ["public_hall", "civic_hall", "cultural_center", "municipal_hall", "prefectural_hall"]
        case .stadiumArena:
            ["stadium", "arena", "dome", "event_hall", "sports_venue"]
        case .themePark:
            ["theme_park", "amusement_park", "indoor_theme_park"]
        case .zooAquarium:
            ["zoo", "aquarium", "safari_park", "zoo_aquarium"]
        case .museum:
            ["museum", "art_museum", "science_museum"]
        case .naturePark:
            ["nature_park", "park", "garden", "botanical_garden", "natural_landmark", "scenic_spot", "visitor_center"]
        case .breweryIndustry:
            ["industrial_tourism", "brewery", "sake_brewery", "distillery", "winery", "industrial_heritage"]
        }
    }
}

private enum PlaceMasterCategories {
    static func tokens(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",、|\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    static func contains(_ category: PlaceMasterCategory, rawValue: String) -> Bool {
        !Set(tokens(from: rawValue)).isDisjoint(with: category.matchingTags)
    }

    static func resolvedCategories(from rawValue: String) -> [PlaceMasterCategory] {
        PlaceMasterCategory.allCases.filter { contains($0, rawValue: rawValue) }
    }

    static func displayTitles(from rawValue: String) -> [String] {
        resolvedCategories(from: rawValue).map(\.title)
    }

    static func setting(_ category: PlaceMasterCategory, enabled: Bool, rawValue: String) -> String {
        var values = tokens(from: rawValue)
        if enabled {
            if !contains(category, rawValue: rawValue) {
                values.append(category.canonicalTag)
            }
        } else {
            values.removeAll { category.matchingTags.contains($0) }
        }
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }.joined(separator: ",")
    }
}

private struct PlaceMasterCategoryEditor: View {
    @Binding var rawValue: String

    var body: some View {
        Section("施設カテゴリ") {
            ForEach(PlaceMasterCategory.allCases) { category in
                Toggle(
                    category.title,
                    systemImage: category.systemImage,
                    isOn: Binding(
                        get: { PlaceMasterCategories.contains(category, rawValue: rawValue) },
                        set: { rawValue = PlaceMasterCategories.setting(category, enabled: $0, rawValue: rawValue) }
                    )
                )
            }
            Text("複合施設は複数選択できます。個別タグは詳細オプションで編集できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
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
    var operationalStatus: PlaceOperationalStatus

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
        operationalStatus = place.operationalStatus
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
    var badgeText: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).font(FavorecoTypography.bodyStrong)
                    if let badgeText {
                        Text(badgeText)
                            .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                }
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
