import SwiftData
import SwiftUI

struct FavoPeopleManagementView: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @State private var searchText = ""
    @State private var selectedFilter: FavoPeopleFilter = .all
    @State private var isShowingCreatePerson = false

    private var activePeople: [PersonMaster] {
        people.filter { person in
            guard !person.isArchived else { return false }
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || PersonMasterSuggestion.matches(person, query: searchText)
                || PersonActivityTags.displayTitles(from: person.roleTagsRaw).contains { title in
                    title.localizedStandardContains(searchText)
                }
            return matchesSearch && selectedFilter.includes(person)
        }
    }

    private var favoriteCount: Int {
        people.filter { !$0.isArchived && $0.favoriteProfile?.isFavorite == true }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                introduction
                filterBar

                if activePeople.isEmpty {
                    emptyState
                } else {
                    peopleList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(background)
        .navigationTitle("人物・団体")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "名前・よみ・別名・活動分野を検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreatePerson = true
                } label: {
                    Label("追加", systemImage: "person.badge.plus")
                }
                .accessibilityLabel("人物・団体を追加")
            }
        }
        .sheet(isPresented: $isShowingCreatePerson) {
            PersonMasterCreateView()
        }
        .tint(themePalette.emotionTint)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("好きな人も、作品をつくった人も")
                .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title2))
            Text("公演や記録に登場する人物・団体をここで管理できます。名前や写真の変更は、紐づく作品や記録でも使われます。")
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                FavoPeopleCount(value: people.filter { !$0.isArchived }.count, label: "人物・団体")
                FavoPeopleCount(value: favoriteCount, label: "FAVO")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FavoPeopleFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 34)
                            .background(
                                selectedFilter == filter
                                    ? themePalette.emotionTint
                                    : Color.primary.opacity(0.07),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedFilter == filter ? "選択中" : "未選択")
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private var peopleList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(activePeople.enumerated()), id: \.element.id) { index, person in
                NavigationLink {
                    PersonMasterEditDestination(personID: person.id)
                } label: {
                    FavoPersonManagementRow(person: person)
                }
                .buttonStyle(.plain)

                if index < activePeople.count - 1 {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(
            Color(.secondarySystemGroupedBackground).opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(themePalette.emotionTint.opacity(0.16), lineWidth: 0.8)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavorecoIconLabel(
                searchText.isEmpty ? "該当する人物・団体はまだありません" : "検索結果がありません",
                systemImage: "person.2",
                iconSize: 18
            )
            .font(FavorecoTypography.bodyStrong)
            Text("人物・団体を追加すると、作品や体験とのつながりを同じ相手として振り返れます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                themePalette.emotionTint.opacity(0.08),
                Color(.systemGroupedBackground),
                Color(.systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private enum FavoPeopleFilter: String, CaseIterable, Identifiable {
    case all
    case favorite
    case person
    case organization

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "すべて"
        case .favorite: "FAVO"
        case .person: "人物"
        case .organization: "団体"
        }
    }

    func includes(_ person: PersonMaster) -> Bool {
        switch self {
        case .all: true
        case .favorite: person.favoriteProfile?.isFavorite == true
        case .person: !person.isOrganization
        case .organization: person.isOrganization
        }
    }
}

private struct FavoPeopleCount: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value.formatted())
                .font(FavorecoTypography.jpSerif(21, weight: .bold, relativeTo: .title3))
            Text(label)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FavoPersonManagementRow: View {
    let person: PersonMaster

    private var profile: FavoriteProfile? { person.favoriteProfile }

    private var displayName: String {
        let nickname = profile?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nickname.isEmpty ? person.displayName : nickname
    }

    private var showsOfficialName: Bool {
        displayName != person.displayName
    }

    private var activityText: String {
        let titles = PersonActivityTags.displayTitles(from: person.roleTagsRaw)
        return titles.isEmpty ? person.entityKind.displayName : titles.prefix(3).joined(separator: "・")
    }

    private var relationshipText: String {
        let count = person.eventLinks?.count ?? 0
        return count == 0 ? "まだ作品・記録との紐づきはありません" : "関連 \(count)件"
    }

    private var accentColor: Color {
        Color(hex: profile?.colorHex ?? "#8F5E73")
    }

    private var avatarReference: ThumbnailReference {
        guard let profile, profile.isFavorite else {
            return .person(person.id)
        }
        return .profileIcon(profile.id, fallback: .person(person.id))
    }

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailImage(
                reference: avatarReference,
                displaySize: CGSize(width: 54, height: 54)
            ) {
                ZStack {
                    accentColor.opacity(0.12)
                    FavorecoIcon(
                        systemName: PersonActivityTags.icon(
                            for: person.roleTagsRaw,
                            isFavorite: profile?.isFavorite == true
                        ),
                        size: 24,
                        fallbackWeight: .medium
                    )
                    .foregroundStyle(accentColor)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(displayName)
                        .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if profile?.isFavorite == true {
                        Text(profile?.isPrimary == true ? "最推し" : "推し")
                            .font(FavorecoTypography.jpSans(9, weight: .bold, relativeTo: .caption2))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 7)
                            .frame(minHeight: 20)
                            .background(accentColor.opacity(0.12), in: Capsule())
                    }
                }

                if showsOfficialName {
                    Text(person.displayName)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(activityText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(accentColor)
                    .lineLimit(2)

                Text(relationshipText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .tint(accentColor)
    }
}
