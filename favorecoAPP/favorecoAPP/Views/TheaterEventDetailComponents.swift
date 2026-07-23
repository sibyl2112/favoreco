import SwiftUI
import UIKit

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
    @State private var isExpanded = true

    private var hasInformation: Bool {
        !event.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    var body: some View {
        if hasInformation {
            VStack(alignment: .leading, spacing: 12) {
                TheaterEventCollapsibleHeader(
                    title: "あらすじ",
                    count: nil,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

                if isExpanded {
                    Text(event.memo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(Color(red: 0.94, green: 0.91, blue: 0.86).opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .theaterEventCard(accentColor: accentColor)
        }
    }
}

struct TheaterEventPeopleSection: View {
    let creditsText: String
    let castLinks: [EventPersonLink]
    let staffLinks: [EventPersonLink]
    let accentColor: Color
    @State private var isExpanded = true
    @State private var showsAllCast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TheaterEventCollapsibleHeader(
                title: "キャスト・スタッフ",
                count: creditsLineCount + castLinks.count + staffLinks.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                Group {
                    if creditsText.isEmpty && castLinks.isEmpty && staffLinks.isEmpty {
                        TheaterEventEmptyRow(
                            systemImage: "person.3",
                            message: "キャスト・スタッフはまだ登録されていません。"
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            if !creditsText.isEmpty {
                                Text(creditsText)
                                    .font(FavorecoTypography.body)
                                    .foregroundStyle(Color(red: 0.94, green: 0.91, blue: 0.86).opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }

                            if !castLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(creditsText.isEmpty ? "キャスト" : "以前の形式で登録したキャスト")
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
                                    Text(creditsText.isEmpty ? "スタッフ・関係者" : "登録済みの団体・関係者")
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
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

    private var creditsLineCount: Int {
        creditsText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
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
                        TheaterEventParticipationRow(visit: visit, accentColor: accentColor)
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

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(displayedItems) { item in
                            NavigationLink {
                                ExperienceDetailView(visit: item.visit)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    TheaterEventGalleryPhoto(photo: item.photo, height: 132)

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
                    .padding(.horizontal, 1)
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

private struct TheaterEventParticipationRow: View {
    let visit: Visit
    let accentColor: Color

    private var firstPhoto: PhotoBlob? {
        let photos = (visit.photos ?? [])
            .filter {
                $0.mediaKind == "photo"
                    && $0.hasStoredData
                    && ExperiencePhotoPurpose.resolved(from: $0.purpose) == .memory
            }
            .sorted { $0.createdAt < $1.createdAt }
        if !visit.eyecatchPath.isEmpty,
           let cover = photos.first(where: { $0.relativePath == visit.eyecatchPath }) {
            return cover
        }
        return photos.first
    }

    private var venueText: String {
        let snapshot = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshot.isEmpty { return snapshot }
        return visit.placeMaster?.name ?? "場所未登録"
    }

    private var focusPeopleText: String {
        let visitLinks = (visit.personLinks ?? []).filter { !$0.isArchived }
        let focusLinks = visitLinks.filter { $0.roleKey == PersonRoleOption.theaterFocus.key }
        let legacyVisitLinks = visitLinks.filter { !TheaterVisitCastResolver.isInheritedSnapshotLink($0) }
        let legacyEventLinks = (visit.event?.personLinks ?? []).filter {
            !$0.isArchived && TheaterVisitCastResolver.isCastLink($0)
        }
        var seen = Set<String>()
        let names = (focusLinks + legacyVisitLinks + legacyEventLinks)
            .compactMap { link -> String? in
                let name = TheaterVisitCastResolver.personName(for: link)
                guard !name.isEmpty else { return nil }
                let key = normalizedPersonName(name)
                return seen.insert(key).inserted ? name : nil
            }
        return names.isEmpty ? "未登録" : names.prefix(2).joined(separator: " / ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let firstPhoto {
                    RepresentativePhotoImage(
                        photo: firstPhoto,
                        maxPixelSize: 280,
                        contentMode: .fill
                    )
                } else {
                    Image(systemName: "theatermasks.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(accentColor.opacity(0.10))
                }
            }
            .frame(width: 72, height: 102)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                TheaterEventParticipationMetaRow(
                    systemImage: "calendar",
                    text: FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt)
                )
                TheaterEventParticipationMetaRow(
                    systemImage: "clock",
                    text: ExperienceDetailPresentation.performanceTime(for: visit)
                )
                TheaterEventParticipationMetaRow(
                    systemImage: "mappin.and.ellipse",
                    text: venueText
                )
                TheaterEventParticipationMetaRow(
                    systemImage: "heart.fill",
                    text: focusPeopleText
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt))、\(ExperienceDetailPresentation.performanceTime(for: visit))、\(venueText)、お目当て・注目した人 \(focusPeopleText)"
        )
    }
}

private struct TheaterEventParticipationMetaRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(FavorecoTypography.caption)
            .foregroundStyle(Color(red: 0.94, green: 0.91, blue: 0.86).opacity(0.86))
            .lineLimit(1)
    }
}

private struct TheaterEventGalleryPhoto: View {
    let photo: PhotoBlob
    let height: CGFloat
    @State private var image: UIImage?
    @State private var loadedCacheKey: String?

    private var cacheKey: String {
        "theater-gallery-\(photo.id.uuidString)-\(photo.byteCount)-520"
    }

    private var displayedImage: UIImage? {
        if loadedCacheKey == cacheKey { return image }
        return ThumbnailLoader.cached(forKey: cacheKey)
    }

    private var displayedWidth: CGFloat {
        guard let displayedImage, displayedImage.size.height > 0 else { return height }
        return height * displayedImage.size.width / displayedImage.size.height
    }

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .overlay { ProgressView() }
            }
        }
        .frame(width: displayedWidth, height: height)
        .task(id: cacheKey) {
            if let cached = ThumbnailLoader.cached(forKey: cacheKey) {
                image = cached
                loadedCacheKey = cacheKey
                return
            }
            image = nil
            loadedCacheKey = nil
            let data = photo.data
            let key = cacheKey
            let loadedImage = await Task.detached(priority: .userInitiated) {
                ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: 520, cacheKey: key)
            }.value
            guard !Task.isCancelled else { return }
            image = loadedImage
            loadedCacheKey = key
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

private struct TheaterEventCollapsibleHeader: View {
    let title: String
    let count: Int?
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "展開中" : "折りたたみ中")
        .accessibilityHint(isExpanded ? "ダブルタップで閉じます" : "ダブルタップで開きます")
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
