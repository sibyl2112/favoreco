import SwiftData
import SwiftUI
import UIKit

struct FavoView: View {
    @Query(sort: \FavoPin.sortOrder) private var favoPins: [FavoPin]
    @Query(sort: \FavoriteProfile.sortOrder) private var profiles: [FavoriteProfile]
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \Plan.startsAt) private var plans: [Plan]
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]

    var body: some View {
        let snapshot = FavoSnapshot.make(
            profiles: profiles,
            pins: favoPins,
            people: people,
            links: personLinks,
            visits: visits,
            plans: plans,
            activePlaceCount: places.filter { !$0.isArchived }.count
        )

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    myFavoSection(snapshot: snapshot)
                    storiesSection(snapshot.stories)
                    collectionsSection(snapshot.collections)
                    exploreSection(snapshot: snapshot)
                    allRecordsButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    MainScreenHeader(title: "FAVO")
                        .padding(.horizontal, 20)
                        .padding(.top, -4)
                        .padding(.bottom, 4)
                    Text("好きから振り返る")
                        .font(FavorecoTypography.jpSans(11, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func myFavoSection(snapshot: FavoSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                FavoSectionTitle(title: "MY FAVO", subtitle: "自分で選んだ好き")
                NavigationLink {
                    FavoPinManagementView()
                } label: {
                    Label("編集", systemImage: "slider.horizontal.3")
                        .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                }
            }

            if !snapshot.pinnedTargets.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(snapshot.pinnedTargets) { target in
                        NavigationLink {
                            FavoPinnedTargetDestination(snapshot: target)
                        } label: {
                            FavoPinnedTargetCard(target: target)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let primaryFavorite = snapshot.primaryFavorite {
                featuredFavoriteCard(primaryFavorite)

                let otherFavorites = snapshot.favorites.filter { $0.id != primaryFavorite.id }
                if !otherFavorites.isEmpty {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(otherFavorites) { favorite in
                                NavigationLink {
                                    FavoPersonDestination(snapshot: favorite, pinID: nil)
                                } label: {
                                    VStack(spacing: 8) {
                                        ThumbnailImage(
                                            reference: favorite.thumbnailReference,
                                            displaySize: CGSize(width: 64, height: 64),
                                            contentMode: .fill
                                        ) {
                                            Image(systemName: "person.fill")
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color(hex: favorite.colorHex).opacity(0.12))
                                        }
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                        Text(favorite.displayName)
                                            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .frame(width: 78)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("自分で選んだFAVOはまだありません", systemImage: "heart")
                        .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                    Text("推しを登録しなくても、下のSTORIESとコレクションから思い出を振り返れます。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        FavoPinManagementView()
                    } label: {
                        Label("人物・作品・場所から選ぶ", systemImage: "heart.circle")
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func featuredFavoriteCard(_ favorite: FavoPersonSnapshot) -> some View {
        NavigationLink {
            FavoPersonDestination(snapshot: favorite, pinID: nil)
        } label: {
            HStack(spacing: 16) {
                ThumbnailImage(
                    reference: favorite.thumbnailReference,
                    displaySize: CGSize(width: 82, height: 82),
                    contentMode: .fill
                ) {
                    Image(systemName: "person.fill")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: favorite.colorHex).opacity(0.12))
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(favorite.isPrimary ? "PRIMARY" : "FAVO")
                        .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                        .tracking(1.4)
                        .foregroundStyle(Color(hex: favorite.colorHex))
                    Text(favorite.displayName)
                        .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title2))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let days = favorite.supportDayCount {
                        Text("推して \(days)日")
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(favorite.visitIDs.count)件の思い出")
                            .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: favorite.colorHex).opacity(0.18), Color(.secondarySystemGroupedBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: favorite.colorHex).opacity(0.25), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
    }

    private func storiesSection(_ stories: [FavoStorySnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FavoSectionTitle(title: "STORIES", subtitle: "時間から振り返る")
            if stories.isEmpty {
                Text("記録を追加すると、最初と最新の思い出がここに育ちます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(stories) { story in
                            NavigationLink {
                                FavoVisitDestination(visitID: story.visitID)
                            } label: {
                                FavoStoryCard(story: story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func collectionsSection(_ collections: [FavoCollectionSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FavoSectionTitle(title: "コレクション", subtitle: "記録から自動でまとまる")
            if collections.isEmpty {
                Text("写真や場所を含む記録が増えると、自分だけのコレクションが育ちます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(collections) { collection in
                        NavigationLink {
                            FavoCollectionDestination(collection: collection)
                        } label: {
                            FavoCollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func exploreSection(snapshot: FavoSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FavoSectionTitle(title: "探す", subtitle: "好きから記録へ")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink { PersonMasterManagementView() } label: {
                    FavoEntranceCard(title: "人物・団体", count: snapshot.activePeopleCount, icon: "person.2")
                }
                NavigationLink { PlaceMasterManagementView() } label: {
                    FavoEntranceCard(title: "場所", count: snapshot.activePlaceCount, icon: "mappin.and.ellipse")
                }
                NavigationLink { RecordsView(embedsInNavigationStack: false, screenTitle: "タグ・同行者") } label: {
                    FavoEntranceCard(title: "タグ・同行者", count: nil, icon: "tag")
                }
                NavigationLink { RecordsView(embedsInNavigationStack: false, screenTitle: "作品・体験") } label: {
                    FavoEntranceCard(title: "作品・体験", count: snapshot.visibleVisitCount, icon: "sparkles.rectangle.stack")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var allRecordsButton: some View {
        NavigationLink {
            RecordsView(embedsInNavigationStack: false, screenTitle: "すべての記録")
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("すべての記録を検索")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

}

private struct FavoVisitDestination: View {
    @Query private var visits: [Visit]

    init(visitID: UUID) {
        _visits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

    var body: some View {
        if let visit = visits.first {
            ExperienceDetailView(visit: visit)
        } else {
            ContentUnavailableView("記録が見つかりません", systemImage: "trash")
        }
    }
}

private struct FavoPlanDestination: View {
    @Query private var plans: [Plan]

    init(planID: UUID) {
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(plan: plan)
        } else {
            ContentUnavailableView("予定が見つかりません", systemImage: "trash")
        }
    }
}

private struct FavoPersonDestination: View {
    let snapshot: FavoPersonSnapshot
    @Query private var profiles: [FavoriteProfile]
    @Query private var people: [PersonMaster]
    @Query private var pins: [FavoPin]
    @Query private var allVisits: [Visit]
    @Query private var allPlans: [Plan]

    init(snapshot: FavoPersonSnapshot, pinID: UUID?) {
        self.snapshot = snapshot
        let profileID = snapshot.profileID
        let personID = snapshot.personID
        let resolvedPinID = pinID ?? UUID()
        _profiles = Query(filter: #Predicate<FavoriteProfile> { $0.id == profileID })
        _people = Query(filter: #Predicate<PersonMaster> { $0.id == personID })
        _pins = Query(filter: #Predicate<FavoPin> { $0.id == resolvedPinID })
    }

    var body: some View {
        if let profile = profiles.first, let person = people.first {
            FavoPersonDetailView(
                snapshot: snapshot,
                profile: profile,
                person: person,
                visits: resolvedVisits,
                upcomingPlans: resolvedPlans,
                pin: pins.first
            )
        } else {
            ContentUnavailableView("FAVOが見つかりません", systemImage: "trash")
        }
    }

    private var resolvedVisits: [Visit] {
        let ids = Set(snapshot.visitIDs)
        return allVisits.filter { ids.contains($0.id) }
            .sorted { $0.visitedAt > $1.visitedAt }
    }

    private var resolvedPlans: [Plan] {
        let ids = Set(snapshot.upcomingPlanIDs)
        return allPlans.filter { ids.contains($0.id) }
            .sorted { $0.startsAt < $1.startsAt }
    }
}

private struct FavoPinnedTargetDestination: View {
    let snapshot: FavoPinnedTargetSnapshot
    @Query private var pins: [FavoPin]
    @Query private var profiles: [FavoriteProfile]
    @Query private var allVisits: [Visit]
    @Query private var allPlans: [Plan]

    init(snapshot: FavoPinnedTargetSnapshot) {
        self.snapshot = snapshot
        let pinID = snapshot.pinID
        let profileID = snapshot.profileID ?? UUID()
        _pins = Query(filter: #Predicate<FavoPin> { $0.id == pinID })
        _profiles = Query(filter: #Predicate<FavoriteProfile> { $0.id == profileID })
    }

    var body: some View {
        if let personSnapshot = snapshot.personSnapshot {
            FavoPersonDestination(snapshot: personSnapshot, pinID: snapshot.pinID)
        } else if let pin = pins.first {
            FavoPinnedTargetDetailView(
                snapshot: snapshot,
                pin: pin,
                profile: profiles.first,
                visits: resolvedVisits,
                upcomingPlans: resolvedPlans
            )
        } else {
            ContentUnavailableView("FAVOが見つかりません", systemImage: "trash")
        }
    }

    private var resolvedVisits: [Visit] {
        let ids = Set(snapshot.visitIDs)
        return allVisits.filter { ids.contains($0.id) }
            .sorted { $0.visitedAt > $1.visitedAt }
    }

    private var resolvedPlans: [Plan] {
        let ids = Set(snapshot.upcomingPlanIDs)
        return allPlans.filter { ids.contains($0.id) }
            .sorted { $0.startsAt < $1.startsAt }
    }
}

private struct FavoCollectionDestination: View {
    let collection: FavoCollectionSummary
    @Query private var allVisits: [Visit]

    var body: some View {
        let ids = Set(collection.visitIDs)
        FavoCollectionDetailView(
            collection: collection,
            visits: allVisits.filter { ids.contains($0.id) }
                .sorted { $0.visitedAt > $1.visitedAt }
        )
    }
}

private struct FavoPinManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoPin.sortOrder) private var pins: [FavoPin]
    @Query(sort: \FavoriteProfile.sortOrder) private var profiles: [FavoriteProfile]
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \ExperienceEvent.title) private var events: [ExperienceEvent]
    @Query(sort: \PlaceMaster.name) private var places: [PlaceMaster]
    @AppStorage(AppStorageKeys.hasMigratedLegacyFavoritesToFavoPins) private var didMigrateLegacyFavorites = false
    @State private var searchText = ""
    @State private var message = ""
    @State private var showsNewPerson = false

    private var visiblePins: [FavoPin] {
        pins.filter(isAvailable).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var visiblePeople: [PersonMaster] {
        people.filter { person in
            guard !person.isArchived else { return false }
            return PersonMasterSuggestion.matches(person, query: searchText)
                || matches(person.favoriteProfile?.nickname ?? "")
        }
    }

    private var visibleEvents: [ExperienceEvent] {
        events.filter { !$0.isArchived && matches($0.title) }
    }

    private var visiblePlaces: [PlaceMaster] {
        places.filter { !$0.isArchived && matches($0.name) }
    }

    var body: some View {
        List {
            Section {
                if visiblePins.isEmpty {
                    Text("下の候補から、自分の好きを選んでください。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visiblePins) { pin in
                        NavigationLink {
                            FavoProfileEditorView(pin: pin)
                        } label: {
                            FavoPinRow(pin: pin)
                        }
                    }
                    .onMove(perform: movePins)
                    .onDelete(perform: deletePins)
                }
            } header: {
                Text("MY FAVO \(visiblePins.count)/4")
            } footer: {
                Text("並び順はFAVOトップにそのまま反映されます。外しても元の人物・作品・場所・記録は削除しません。")
            }

            Section {
                Button {
                    showsNewPerson = true
                } label: {
                    Label("新しい人物・団体を登録", systemImage: "person.badge.plus")
                }
                .disabled(visiblePins.count >= 4)

                if visiblePeople.isEmpty {
                    Text("該当する人物・団体はありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visiblePeople) { person in
                        candidateButton(
                            title: person.favoriteProfile?.nickname.isEmpty == false
                                ? person.favoriteProfile?.nickname ?? person.displayName
                                : person.displayName,
                            subtitle: person.reading.isEmpty
                                ? (person.eventLinks?.isEmpty == false ? "登録済みキャスト" : "人物・団体マスター")
                                : person.reading,
                            icon: "person.fill",
                            colorHex: person.favoriteProfile?.colorHex ?? "#8F5E73",
                            kind: .person,
                            targetID: person.id,
                            person: person
                        )
                    }
                }
            } header: {
                Text("人物・団体・キャスト")
            } footer: {
                Text("登録済みマスターと作品のキャストを検索できます。新規登録した人物はマスター管理にも追加されます。")
            }

            Section("作品・体験") {
                if visibleEvents.isEmpty {
                    Text("該当する作品・体験はありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleEvents) { event in
                        candidateButton(
                            title: event.title.isEmpty ? "無題の作品" : event.title,
                            subtitle: event.category?.name ?? "作品・体験",
                            icon: event.category?.iconSymbol ?? "sparkles.rectangle.stack",
                            colorHex: event.category?.colorHex ?? "#147C88",
                            kind: .event,
                            targetID: event.id,
                            event: event
                        )
                    }
                }
            }

            Section("場所") {
                if visiblePlaces.isEmpty {
                    Text("該当する場所はありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visiblePlaces) { place in
                        candidateButton(
                            title: place.name.isEmpty ? "名称未設定の場所" : place.name,
                            subtitle: place.isClosed
                                ? "閉館 · \(place.prefecture.isEmpty ? "場所" : place.prefecture)"
                                : (place.prefecture.isEmpty ? "場所" : place.prefecture),
                            icon: "mappin.and.ellipse",
                            colorHex: "#2F7FB8",
                            kind: .place,
                            targetID: place.id,
                            place: place
                        )
                    }
                }
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("MY FAVOを編集")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "人物・作品・場所を検索")
        .toolbar { EditButton() }
        .task { migrateLegacyFavoritesIfNeeded() }
        .sheet(isPresented: $showsNewPerson) {
            FavoNewPersonView(nextSortOrder: visiblePins.count)
        }
    }

    @ViewBuilder
    private func candidateButton(
        title: String,
        subtitle: String,
        icon: String,
        colorHex: String,
        kind: FavoTargetKind,
        targetID: UUID,
        person: PersonMaster? = nil,
        event: ExperienceEvent? = nil,
        place: PlaceMaster? = nil
    ) -> some View {
        let existingPin = pin(kind: kind, targetID: targetID)
        let selected = existingPin != nil
        let unavailable = !selected && visiblePins.count >= 4
        HStack(spacing: 8) {
            Button {
                togglePin(
                    kind: kind,
                    targetID: targetID,
                    person: person,
                    event: event,
                    place: place
                )
            } label: {
                FavoPinCandidateRow(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    colorHex: colorHex,
                    isSelected: selected,
                    isDisabled: unavailable
                )
            }
            .buttonStyle(.plain)
            .disabled(unavailable)

            if let existingPin {
                NavigationLink {
                    FavoProfileEditorView(pin: existingPin)
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(title)のFAVOプロフィールを編集")
            }
        }
    }

    private func togglePin(
        kind: FavoTargetKind,
        targetID: UUID,
        person: PersonMaster?,
        event: ExperienceEvent?,
        place: PlaceMaster?
    ) {
        if let existing = pin(kind: kind, targetID: targetID) {
            let remainingPins = visiblePins.filter { $0.id != existing.id }
            modelContext.delete(existing)
            message = "MY FAVOから外しました。元のデータは残っています。"
            saveNormalizedOrder(remainingPins)
        } else {
            guard visiblePins.count < 4 else {
                message = "MY FAVOは最大4件です。先に1件外してください。"
                return
            }
            let now = Date()
            modelContext.insert(
                FavoPin(
                    targetKindKey: kind.rawValue,
                    sortOrder: visiblePins.count,
                    createdAt: now,
                    updatedAt: now,
                    person: kind == .person ? person : nil,
                    event: kind == .event ? event : nil,
                    place: kind == .place ? place : nil
                )
            )
            ensureProfile(kind: kind, person: person, event: event, place: place, now: now)
            message = "MY FAVOに追加しました。"
            saveContext()
        }
    }

    private func ensureProfile(
        kind: FavoTargetKind,
        person: PersonMaster?,
        event: ExperienceEvent?,
        place: PlaceMaster?,
        now: Date
    ) {
        let existing = person?.favoriteProfile ?? event?.favoriteProfile ?? place?.favoriteProfile
        guard existing == nil else {
            existing?.isFavorite = true
            existing?.updatedAt = now
            return
        }
        let profile = FavoriteProfile(
            isFavorite: true,
            colorHex: event?.category?.colorHex ?? (kind == .place ? "#2F7FB8" : "#8F5E73"),
            createdAt: now,
            updatedAt: now,
            person: kind == .person ? person : nil,
            event: kind == .event ? event : nil,
            place: kind == .place ? place : nil
        )
        modelContext.insert(profile)
    }

    private func movePins(from source: IndexSet, to destination: Int) {
        var reordered = visiblePins
        reordered.move(fromOffsets: source, toOffset: destination)
        let now = Date()
        for (index, pin) in reordered.enumerated() {
            pin.sortOrder = index
            pin.updatedAt = now
        }
        saveContext()
    }

    private func deletePins(at offsets: IndexSet) {
        let removedIDs = Set(offsets.compactMap { index in
            visiblePins.indices.contains(index) ? visiblePins[index].id : nil
        })
        for index in offsets where visiblePins.indices.contains(index) {
            modelContext.delete(visiblePins[index])
        }
        message = "MY FAVOから外しました。元のデータは残っています。"
        saveNormalizedOrder(visiblePins.filter { !removedIDs.contains($0.id) })
    }

    private func migrateLegacyFavoritesIfNeeded() {
        var seenTargets = Set<String>()
        var keptPins: [FavoPin] = []
        for pin in pins.sorted(by: { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }) {
            guard isAvailable(pin), let targetID = pin.targetID else {
                modelContext.delete(pin)
                continue
            }
            let key = "\(pin.targetKind.rawValue):\(targetID.uuidString)"
            if !seenTargets.insert(key).inserted || keptPins.count >= 4 {
                modelContext.delete(pin)
            } else {
                keptPins.append(pin)
            }
        }
        guard !didMigrateLegacyFavorites else {
            saveNormalizedOrder(keptPins)
            return
        }

        if keptPins.isEmpty {
            let legacyProfiles = profiles.filter {
                $0.isFavorite && $0.person?.isArchived != true && $0.person != nil
            }
            for (index, profile) in legacyProfiles.prefix(4).enumerated() {
                let now = Date()
                let pin = FavoPin(
                    targetKindKey: FavoTargetKind.person.rawValue,
                    sortOrder: index,
                    createdAt: now,
                    updatedAt: now,
                    person: profile.person
                )
                modelContext.insert(pin)
                keptPins.append(pin)
            }
        }
        didMigrateLegacyFavorites = true
        saveNormalizedOrder(keptPins)
    }

    private func saveNormalizedOrder(_ orderedPins: [FavoPin]? = nil) {
        let now = Date()
        for (index, pin) in (orderedPins ?? visiblePins).enumerated() {
            pin.sortOrder = index
            pin.updatedAt = now
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            message = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func pin(kind: FavoTargetKind, targetID: UUID) -> FavoPin? {
        visiblePins.first { $0.targetKind == kind && $0.targetID == targetID }
    }

    private func isAvailable(_ pin: FavoPin) -> Bool {
        switch pin.targetKind {
        case .person: pin.person?.isArchived == false
        case .event: pin.event?.isArchived == false
        case .place: pin.place?.isArchived == false
        }
    }

    private func matches(_ value: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || value.localizedCaseInsensitiveContains(query)
    }
}

private struct FavoPinnedTargetDetailView: View {
    let snapshot: FavoPinnedTargetSnapshot
    let pin: FavoPin
    let profile: FavoriteProfile?
    let visits: [Visit]
    let upcomingPlans: [Plan]
    @State private var revealsRecordedSpending = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                FavoProfileHero(
                    title: snapshot.title,
                    subtitle: snapshot.subtitle,
                    kindLabel: snapshot.kind.displayName,
                    colorHex: snapshot.colorHex,
                    profile: profile,
                    fallbackImage: fallbackImage,
                    fallbackSymbol: snapshot.iconSymbol
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    FavoInsightMetric(
                        title: "思い出",
                        value: "\(visits.count)件",
                        icon: "sparkles",
                        colorHex: snapshot.colorHex
                    )
                    FavoInsightMetric(
                        title: "写真",
                        value: "\(snapshot.photoCount)枚",
                        icon: "photo.on.rectangle.angled",
                        colorHex: snapshot.colorHex
                    )
                    Button {
                        withAnimation(.snappy) { revealsRecordedSpending.toggle() }
                    } label: {
                        FavoInsightMetric(
                            title: "記録済み支出",
                            value: spendingMetricValue,
                            icon: revealsRecordedSpending ? "eye.slash" : "eye",
                            colorHex: snapshot.colorHex
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!snapshot.spendingBreakdown.hasRecordedSpending)
                    .accessibilityLabel(spendingAccessibilityLabel)
                }

                if revealsRecordedSpending, snapshot.spendingBreakdown.hasRecordedSpending {
                    FavoSpendingBreakdownSection(
                        breakdown: snapshot.spendingBreakdown,
                        accentColorHex: snapshot.colorHex
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let plan = upcomingPlans.first {
                    VStack(alignment: .leading, spacing: 10) {
                        FavoSectionTitle(title: "次の予定", subtitle: "1件だけ表示")
                        NavigationLink {
                            FavoPlanDestination(planID: plan.id)
                        } label: {
                            FavoTargetPlanRow(plan: plan, colorHex: snapshot.colorHex)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let profile {
                    FavoAnniversarySection(profile: profile, colorHex: snapshot.colorHex)
                }

                if let profile {
                    FavoGallerySection(
                        profile: profile,
                        colorHex: snapshot.colorHex,
                        candidateVisits: visits
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    FavoSectionTitle(title: "思い出", subtitle: "\(visits.count)件")
                    if visits.isEmpty {
                        Text("このFAVOに紐づく記録はまだありません。")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(visits) { visit in
                            NavigationLink {
                                FavoVisitDestination(visitID: visit.id)
                            } label: {
                                FavoVisitRow(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(snapshot.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { FavoProfileEditorView(pin: pin) } label: {
                    Label("推しを編集", systemImage: "pencil")
                }
            }
        }
    }

    private var fallbackImage: UIImage? {
        switch snapshot.kind {
        case .person:
            if let data = pin.person?.imageData { return UIImage(data: data) }
            return pin.person.flatMap { PersonImageStore.image(at: $0.imagePath) }
        case .event:
            return pin.event?.eyecatchData.flatMap(UIImage.init(data:))
        case .place:
            return nil
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
    }

    private var spendingMetricValue: String {
        guard snapshot.spendingBreakdown.hasRecordedSpending else { return "記録なし" }
        return revealsRecordedSpending ? formattedAmount(snapshot.recordedSpending) : "タップで表示"
    }

    private var spendingAccessibilityLabel: String {
        guard snapshot.spendingBreakdown.hasRecordedSpending else { return "記録済み支出はありません" }
        return revealsRecordedSpending ? "記録済み支出と内訳を隠す" : "記録済み支出と内訳を表示"
    }
}

private struct FavoCollectionDetailView: View {
    let collection: FavoCollectionSummary
    let visits: [Visit]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: collection.iconSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: collection.colorHex))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: collection.colorHex).opacity(0.12), in: Circle())
                    Text(collection.value)
                        .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    Text(collection.detail)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: collection.colorHex).opacity(0.16),
                                    Color(.secondarySystemGroupedBackground)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: collection.colorHex).opacity(0.22), lineWidth: 0.75)
                }

                FavoSectionTitle(title: "思い出", subtitle: "\(visits.count)件")

                if visits.isEmpty {
                    Text("該当する記録はありません。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(visits) { visit in
                        NavigationLink {
                            FavoVisitDestination(visitID: visit.id)
                        } label: {
                            FavoVisitRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FavoPersonDetailView: View {
    let snapshot: FavoPersonSnapshot
    let profile: FavoriteProfile
    let person: PersonMaster
    let visits: [Visit]
    let upcomingPlans: [Plan]
    let pin: FavoPin?
    @State private var revealsRecordedSpending = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                FavoProfileHero(
                    title: snapshot.displayName,
                    subtitle: personHeroSubtitle,
                    kindLabel: "人物・団体",
                    colorHex: snapshot.colorHex,
                    profile: profile,
                    fallbackImage: personImage,
                    fallbackSymbol: "person.fill"
                )

                HStack(spacing: 10) {
                    FavoMiniMetric(value: visits.count, label: "思い出")
                    FavoMiniMetric(value: Set(visits.compactMap { $0.event?.id }).count, label: "作品・公演")
                    FavoMiniMetric(value: upcomingPlans.count, label: "予定")
                }

                if let plan = upcomingPlans.first {
                    VStack(alignment: .leading, spacing: 10) {
                        FavoSectionTitle(title: "次に会える", subtitle: nil)
                        NavigationLink { FavoPlanDestination(planID: plan.id) } label: {
                            FavoPlanRow(favorite: snapshot, plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                FavoAnniversarySection(profile: profile, colorHex: snapshot.colorHex)

                FavoGallerySection(
                    profile: profile,
                    colorHex: snapshot.colorHex,
                    candidateVisits: visits
                )

                if visits.isEmpty {
                    Text("この人物・団体に紐づく記録はまだありません。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    milestoneSection
                    accumulatedSection
                    categorySection
                    frequentPlacesSection
                    timelineSection
                }

                if !snapshot.originText.isEmpty || !snapshot.memo.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        FavoSectionTitle(title: "わたしのFAVO", subtitle: nil)
                        if !snapshot.originText.isEmpty {
                            LabeledContent("きっかけ", value: snapshot.originText)
                        }
                        if !snapshot.memo.isEmpty {
                            Text(snapshot.memo)
                                .font(FavorecoTypography.body)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(snapshot.personDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pin {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { FavoProfileEditorView(pin: pin) } label: {
                        Label("推しを編集", systemImage: "pencil")
                    }
                }
            }
        }
    }

    private var personImage: UIImage? {
        if let data = person.imageData { return UIImage(data: data) }
        return PersonImageStore.image(at: person.imagePath)
    }

    private var personHeroSubtitle: String {
        var values: [String] = []
        if snapshot.displayName != snapshot.personDisplayName { values.append(snapshot.personDisplayName) }
        if let days = snapshot.supportDayCount { values.append("推して \(days)日") }
        if values.isEmpty { values.append("\(visits.count)件の思い出") }
        return values.joined(separator: " · ")
    }

    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoSectionTitle(title: "記憶のはじまりと今", subtitle: nil)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let firstVisit = visits.last {
                    NavigationLink { FavoVisitDestination(visitID: firstVisit.id) } label: {
                        FavoMilestoneCard(title: "初回", visit: firstVisit, colorHex: snapshot.colorHex)
                    }
                    .buttonStyle(.plain)
                }
                if let latestVisit = visits.first {
                    NavigationLink { FavoVisitDestination(visitID: latestVisit.id) } label: {
                        FavoMilestoneCard(title: "最新", visit: latestVisit, colorHex: snapshot.colorHex)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accumulatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoSectionTitle(title: "積み重ね", subtitle: nil)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                FavoInsightMetric(
                    title: "写真",
                    value: "\(snapshot.photoCount)枚",
                    icon: "photo.on.rectangle.angled",
                    colorHex: snapshot.colorHex
                )
                Button {
                    withAnimation(.snappy) {
                        revealsRecordedSpending.toggle()
                    }
                } label: {
                    FavoInsightMetric(
                        title: "記録済み支出",
                        value: spendingMetricValue,
                        icon: revealsRecordedSpending ? "eye.slash" : "eye",
                        colorHex: snapshot.colorHex
                    )
                }
                .buttonStyle(.plain)
                .disabled(!snapshot.spendingBreakdown.hasRecordedSpending)
                .accessibilityLabel(spendingAccessibilityLabel)
            }
            if revealsRecordedSpending, snapshot.spendingBreakdown.hasRecordedSpending {
                FavoSpendingBreakdownSection(
                    breakdown: snapshot.spendingBreakdown,
                    accentColorHex: snapshot.colorHex
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("支出は、この人物・団体に紐づく体験記録の金額ユニットだけを合計しています。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoSectionTitle(title: "ジャンル別", subtitle: "全\(visits.count)件")
            VStack(spacing: 8) {
                ForEach(snapshot.categorySummaries) { summary in
                    FavoCategorySummaryRow(summary: summary, totalCount: visits.count)
                }
            }
        }
    }

    @ViewBuilder
    private var frequentPlacesSection: some View {
        if !snapshot.frequentPlaces.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FavoSectionTitle(title: "よく行く場所", subtitle: nil)
                VStack(spacing: 8) {
                    ForEach(Array(snapshot.frequentPlaces.prefix(5).enumerated()), id: \.element.id) { index, place in
                        FavoFrequentPlaceRow(rank: index + 1, place: place, colorHex: snapshot.colorHex)
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoSectionTitle(title: "ジャンル横断タイムライン", subtitle: "全件")
            ForEach(visits) { visit in
                NavigationLink { FavoVisitDestination(visitID: visit.id) } label: {
                    FavoVisitRow(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
    }

    private var spendingMetricValue: String {
        guard snapshot.spendingBreakdown.hasRecordedSpending else { return "記録なし" }
        return revealsRecordedSpending ? formattedAmount(snapshot.recordedSpending) : "タップで表示"
    }

    private var spendingAccessibilityLabel: String {
        guard snapshot.spendingBreakdown.hasRecordedSpending else { return "記録済み支出はありません" }
        return revealsRecordedSpending ? "記録済み支出と内訳を隠す" : "記録済み支出と内訳を表示"
    }
}

private struct FavoStoryCard: View {
    let story: FavoStorySnapshot

    private var colorHex: String {
        story.categoryColorHex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.label)
                .font(FavorecoTypography.jpSans(9, weight: .bold, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(Color(hex: colorHex))
            Text(story.title)
                .font(FavorecoTypography.jpSerif(16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(.primary)
            Text(story.visitTitle)
                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            HStack(spacing: 5) {
                Image(systemName: story.categoryIcon)
                Text(FavorecoDateText.compactDate(story.visitedAt))
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            if !story.placeName.isEmpty {
                Text(story.placeName)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(15)
        .frame(width: 244)
        .frame(minHeight: 158, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: colorHex).opacity(0.14), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: colorHex).opacity(0.2), lineWidth: 0.75)
        }
    }
}

private struct FavoPinnedTargetCard: View {
    let target: FavoPinnedTargetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ThumbnailImage(
                    reference: target.thumbnailReference,
                    displaySize: CGSize(width: 38, height: 38),
                    contentMode: .fill
                ) {
                    Image(systemName: target.iconSymbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color(hex: target.colorHex))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: target.colorHex).opacity(0.12))
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            Text(target.kind.displayName)
                .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                .foregroundStyle(.secondary)
            Text(target.title)
                .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            Text(target.subtitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: target.colorHex).opacity(0.12), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: target.colorHex).opacity(0.18), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FavoPinRow: View {
    let pin: FavoPin

    private var title: String {
        let custom = pin.customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        switch pin.targetKind {
        case .person: return pin.person?.displayName ?? "人物・団体"
        case .event: return pin.event?.title ?? "作品・体験"
        case .place: return pin.place?.name ?? "場所"
        }
    }

    private var icon: String {
        switch pin.targetKind {
        case .person: "person.fill"
        case .event: pin.event?.category?.iconSymbol ?? "sparkles.rectangle.stack"
        case .place: "mappin.and.ellipse"
        }
    }

    private var colorHex: String {
        switch pin.targetKind {
        case .person: pin.person?.favoriteProfile?.colorHex ?? "#8F5E73"
        case .event: pin.event?.category?.colorHex ?? "#147C88"
        case .place: "#2F7FB8"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 34, height: 34)
                .background(Color(hex: colorHex).opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .lineLimit(2)
                Text(pin.targetKind.displayName)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FavoPinCandidateRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 34, height: 34)
                .background(Color(hex: colorHex).opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Color(hex: colorHex) : (isDisabled ? Color.secondary.opacity(0.45) : Color.accentColor))
        }
        .contentShape(Rectangle())
    }
}

private struct FavoTargetPlanRow: View {
    let plan: Plan
    let colorHex: String

    var body: some View {
        HStack(spacing: 12) {
            Text(FavorecoDateText.compactDate(plan.startsAt))
                .font(FavorecoTypography.jpSans(11, weight: .bold, relativeTo: .caption))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title.isEmpty ? plan.event?.title ?? "予定" : plan.title)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !plan.venueNameSnapshot.isEmpty {
                    Text(plan.venueNameSnapshot)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FavoCollectionCard: View {
    let collection: FavoCollectionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: collection.iconSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: collection.colorHex))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: collection.colorHex).opacity(0.1), in: Circle())
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            Text(collection.title)
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.secondary)
            Text(collection.value)
                .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .title3))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(collection.detail)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct FavoMilestoneCard: View {
    let title: String
    let visit: Visit
    let colorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(Color(hex: colorHex))
            Text(visit.event?.title ?? "無題の記録")
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            Text(FavorecoDateText.compactDate(visit.visitedAt))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            if !visit.venueNameSnapshot.isEmpty {
                Text(visit.venueNameSnapshot)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: colorHex).opacity(0.18), lineWidth: 0.75)
        }
    }
}

private struct FavoInsightMetric: View {
    let title: String
    let value: String
    let icon: String
    let colorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
            Text(value)
                .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .title3))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FavoSpendingBreakdownSection: View {
    let breakdown: FavoSpendingBreakdown
    let accentColorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FavoSectionTitle(
                title: "支出の内訳",
                subtitle: "金額を記録した\(breakdown.recordedVisitCount)件"
            )

            spendingGroup(title: "年別", slices: breakdown.yearly)
            spendingGroup(title: "ジャンル別", slices: breakdown.categories)

            Text("体験記録の金額ユニットだけを集計しています。チケット申込の金額は重ねて加算しません。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: accentColorHex).opacity(0.16), lineWidth: 0.75)
        }
    }

    private func spendingGroup(title: String, slices: [FavoSpendingSlice]) -> some View {
        let maximumAmountMagnitude = maximumAmountMagnitude(in: slices)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
            ForEach(slices) { slice in
                FavoSpendingSliceRow(
                    slice: slice,
                    colorHex: slice.id.hasPrefix("year:") ? accentColorHex : slice.colorHex,
                    maximumAmountMagnitude: maximumAmountMagnitude
                )
            }
        }
    }

    private func maximumAmountMagnitude(in slices: [FavoSpendingSlice]) -> Double {
        slices.map { abs(NSDecimalNumber(decimal: $0.amount).doubleValue) }.max() ?? 0
    }
}

private struct FavoSpendingSliceRow: View {
    let slice: FavoSpendingSlice
    let colorHex: String
    let maximumAmountMagnitude: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: slice.iconSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: colorHex).opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(slice.title)
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                    Text(slice.detail)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(formattedAmount(slice.amount))
                    .font(FavorecoTypography.jpSerif(15, weight: .bold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color(hex: colorHex).opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: colorHex).opacity(0.7))
                            .frame(width: proxy.size.width * ratio)
                    }
            }
            .frame(height: 4)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var ratio: CGFloat {
        guard maximumAmountMagnitude > 0 else { return 0 }
        let magnitude = abs(NSDecimalNumber(decimal: slice.amount).doubleValue)
        return min(CGFloat(magnitude / maximumAmountMagnitude), 1)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }
}

private struct FavoCategorySummaryRow: View {
    let summary: FavoCategorySummary
    let totalCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: summary.iconSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: summary.colorHex))
                .frame(width: 30, height: 30)
                .background(Color(hex: summary.colorHex).opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(summary.name)
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                    Spacer()
                    Text("\(summary.count)件")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(hex: summary.colorHex).opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: summary.colorHex).opacity(0.7))
                                .frame(width: proxy.size.width * ratio)
                        }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var ratio: CGFloat {
        guard totalCount > 0 else { return 0 }
        return min(CGFloat(summary.count) / CGFloat(totalCount), 1)
    }
}

private struct FavoFrequentPlaceRow: View {
    let rank: Int
    let place: FavoPlaceSummary
    let colorHex: String

    var body: some View {
        HStack(spacing: 11) {
            Text("\(rank)")
                .font(FavorecoTypography.jpSerif(16, weight: .bold, relativeTo: .headline))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 26)
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(Color(hex: colorHex))
            Text(place.name)
                .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                .lineLimit(1)
            Spacer()
            Text("\(place.count)回")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct FavoAvatar: View {
    let person: PersonMaster
    let profile: FavoriteProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let image = personImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: profile.colorHex), Color(hex: profile.colorHex).opacity(0.58)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: PersonActivityTags.icon(for: person.roleTagsRaw, isFavorite: true))
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
        .shadow(color: Color(hex: profile.colorHex).opacity(0.22), radius: 8, y: 4)
        .accessibilityLabel(person.displayName)
    }

    private var personImage: UIImage? {
        if let iconData = profile.iconImageData, let image = UIImage(data: iconData) {
            return image
        }
        if let imageData = person.imageData, let image = UIImage(data: imageData) {
            return image
        }
        return PersonImageStore.image(at: person.imagePath)
    }
}

private struct FavoProfileHero: View {
    let title: String
    let subtitle: String
    let kindLabel: String
    let colorHex: String
    let profile: FavoriteProfile?
    let fallbackImage: UIImage?
    let fallbackSymbol: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackground
            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(kindLabel.uppercased())
                        .font(FavorecoTypography.jpSans(10, weight: .bold, relativeTo: .caption2))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(title)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    Text(subtitle)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: colorHex).opacity(0.35), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let data = profile?.heroImageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let fallbackImage {
            Image(uiImage: fallbackImage).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        Group {
            if let data = profile?.iconImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let fallbackImage {
                Image(uiImage: fallbackImage).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(hex: colorHex)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
    }
}

private struct FavoMiniMetric: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
            Text(label)
                .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct FavoSectionTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
            if let subtitle {
                Text(subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct FavoEntranceCard: View {
    let title: String
    let count: Int?
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.accentColor)
            HStack {
                Text(title)
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FavoPlanRow: View {
    let favorite: FavoPersonSnapshot
    let plan: Plan

    var body: some View {
        HStack(spacing: 12) {
            Text(FavorecoDateText.compactDate(plan.startsAt))
                .font(FavorecoTypography.jpSans(11, weight: .bold, relativeTo: .caption))
                .multilineTextAlignment(.center)
            .foregroundStyle(Color(hex: favorite.colorHex))
            .frame(width: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.displayName)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Text(plan.title.isEmpty ? plan.event?.title ?? "予定" : plan.title)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !plan.venueNameSnapshot.isEmpty {
                    Text(plan.venueNameSnapshot)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FavoVisitRow: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: visit.event?.category?.iconSymbol ?? "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: visit.event?.category?.colorHex ?? "#147C88"))
                .frame(width: 34, height: 34)
                .background(Color(hex: visit.event?.category?.colorHex ?? "#147C88").opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(visit.event?.title ?? "無題の記録")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(FavorecoDateText.compactDate(visit.visitedAt))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
