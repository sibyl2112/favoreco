import SwiftUI

struct TheaterEventOverviewSection: View {
    let snapshot: EventDetailSnapshot
    let ratingLabel: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterEventSectionHeader(title: "公演サマリー", count: nil)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                TheaterEventMetricTile(
                    title: "参加回数",
                    value: "\(snapshot.visitCount)回",
                    systemImage: "theatermasks"
                )
                TheaterEventMetricTile(
                    title: ratingLabel,
                    value: snapshot.averageRatingText,
                    systemImage: "star.fill"
                )
                TheaterEventMetricTile(
                    title: "初回",
                    value: snapshot.firstVisitText,
                    systemImage: "calendar.badge.checkmark"
                )
                TheaterEventMetricTile(
                    title: "最新",
                    value: snapshot.latestVisitText,
                    systemImage: "clock.arrow.circlepath"
                )
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accentColor.opacity(0.16), lineWidth: 0.75)
        }
    }
}

struct TheaterEventInformationSection: View {
    let event: ExperienceEvent
    let accentColor: Color

    private var hasInformation: Bool {
        !event.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    var body: some View {
        if hasInformation {
            VStack(alignment: .leading, spacing: 12) {
                TheaterEventSectionHeader(title: "あらすじ", count: nil)
                Text(event.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(Color(red: 0.94, green: 0.91, blue: 0.86).opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .theaterEventCard(accentColor: accentColor)
        }
    }
}

struct TheaterEventPeopleSection: View {
    let castLinks: [EventPersonLink]
    let staffLinks: [EventPersonLink]
    let accentColor: Color
    @State private var showsAllCast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TheaterEventSectionHeader(
                title: "キャスト・スタッフ",
                count: castLinks.count + staffLinks.count
            )

            if castLinks.isEmpty && staffLinks.isEmpty {
                TheaterEventEmptyRow(
                    systemImage: "person.3",
                    message: "キャスト・スタッフはまだ登録されていません。"
                )
            } else {
                if !castLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("キャスト")
                            .font(FavorecoTypography.bodyStrong)

                        if showsAllCast {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 78), spacing: 12)],
                                spacing: 14
                            ) {
                                ForEach(castLinks) { link in
                                    TheaterEventPersonCard(link: link, accentColor: accentColor)
                                }
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 14) {
                                    ForEach(castLinks.prefix(6)) { link in
                                        TheaterEventPersonCard(link: link, accentColor: accentColor)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                            .scrollClipDisabled()
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: EventDetailBackSwipeExclusionPreferenceKey.self,
                                        value: [proxy.frame(in: .global)]
                                    )
                                }
                            }
                        }

                        if castLinks.count > 6 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showsAllCast.toggle()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(showsAllCast ? "キャストを閉じる" : "さらに見る")
                                    Image(systemName: showsAllCast ? "chevron.up" : "chevron.down")
                                }
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(accentColor)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !staffLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("スタッフ・関係者")
                            .font(FavorecoTypography.bodyStrong)

                        ForEach(staffLinks) { link in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(roleName(for: link))
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(accentColor.opacity(0.82))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accentColor.opacity(0.07), in: Capsule())

                                Text(personName(for: link, fallback: "スタッフ・関係者"))
                                    .font(FavorecoTypography.bodyStrong)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
    }

    private func roleName(for link: EventPersonLink) -> String {
        let customRole = link.displayRole.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customRole.isEmpty { return customRole }
        return PersonRoleOption.option(for: link.roleKey).name
    }
}

struct TheaterEventParticipationHistorySection: View {
    let visits: [Visit]
    let accentColor: Color
    @State private var showsAll = false

    private var displayedVisits: [Visit] {
        showsAll ? visits : Array(visits.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TheaterEventSectionHeader(title: "参加した公演", count: visits.count)

            if visits.isEmpty {
                TheaterEventEmptyRow(
                    systemImage: "calendar.badge.plus",
                    message: "この公演の観劇記録はまだありません。"
                )
            } else {
                ForEach(displayedVisits) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        VisitSummaryRow(visit: visit, showsCategory: false)
                    }
                    .buttonStyle(.plain)
                }

                if visits.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(showsAll ? "履歴を閉じる" : "すべての参加履歴を見る")
                            Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
    }
}

struct TheaterEventMemoryGallerySection: View {
    let items: [EventDetailMemoryPhoto]
    let accentColor: Color
    @State private var showsAll = false

    private var displayedItems: [EventDetailMemoryPhoto] {
        showsAll ? items : Array(items.prefix(6))
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                TheaterEventSectionHeader(title: "思い出ギャラリー", count: items.count)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(displayedItems) { item in
                        NavigationLink {
                            ExperienceDetailView(visit: item.visit)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                RepresentativePhotoImage(
                                    photo: item.photo,
                                    maxPixelSize: 420,
                                    contentMode: .fill
                                )
                                .aspectRatio(1, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipped()

                                Text(FavorecoDateText.compactDate(item.visit.visitedAt))
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(.black.opacity(0.58), in: Capsule())
                                    .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(FavorecoDateText.compactDate(item.visit.visitedAt))の観劇記録を開く")
                    }
                }

                if items.count > 6 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(showsAll ? "ギャラリーを閉じる" : "すべての写真を見る")
                            Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TheaterEventMetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }
}

private struct TheaterEventInfoRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TheaterEventPersonCard: View {
    let link: EventPersonLink
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            PersonAvatar(
                imageData: link.person?.imageData,
                imagePath: link.person?.imagePath ?? "",
                systemImage: PersonActivityTags.icon(for: link.person?.roleTagsRaw ?? link.roleKey),
                size: 64
            )
            .overlay {
                Circle().stroke(accentColor.opacity(0.26), lineWidth: 0.7)
            }

            Text(personName(for: link, fallback: "出演者"))
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .lineLimit(1)
                .frame(width: 78)

            Text(roleName)
                .font(FavorecoTypography.jpSans(9, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 78)
        }
        .accessibilityElement(children: .combine)
    }

    private var roleName: String {
        let customRole = link.displayRole.trimmingCharacters(in: .whitespacesAndNewlines)
        return customRole.isEmpty ? PersonRoleOption.option(for: link.roleKey).name : customRole
    }
}

private struct TheaterEventSectionHeader: View {
    let title: String
    let count: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FavorecoTypography.sectionTitle)
                .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
            Spacer(minLength: 8)
            if let count {
                Text("\(count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TheaterEventEmptyRow: View {
    let systemImage: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(message)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func personName(for link: EventPersonLink, fallback: String) -> String {
    let snapshotName = link.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    if !snapshotName.isEmpty { return snapshotName }
    let masterName = link.person?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return masterName.isEmpty ? fallback : masterName
}

extension View {
    func theaterEventCard(accentColor: Color) -> some View {
        self
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.032), accentColor.opacity(0.022)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor.opacity(0.22), lineWidth: 0.6)
            }
    }
}
