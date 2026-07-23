//
//  ExperienceDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

private struct DetailBackSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct PersonMasterEditTarget: Identifiable {
    let id: UUID
}

struct ExperienceDetailView: View {
    let visit: Visit
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @State private var isShowingEdit = false
    @State private var calendarDraft: CalendarEventDraft?
    @State private var ticketPlanForEditor: Plan?
    @State private var navigatingPlan: Plan?
    @State private var isShowingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?
    @State private var planCreationErrorMessage: String?
    @State private var isNextActionsExpanded = true
    @State private var isOCRExpanded = false
    @State private var isReviewExpanded = false
    @State private var isOfficialInfoExpanded = true
    @State private var isPhotoCollectionExpanded = true
    @State private var isReviewSectionExpanded = true
    @State private var isShowingMapChooser = false
    @State private var memoryPhotoItems: [PhotosPickerItem] = []
    @State private var goodsPhotoItems: [PhotosPickerItem] = []
    @State private var benefitPhotoItems: [PhotosPickerItem] = []
    @State private var photoAddErrorMessage: String?
    @State private var backSwipeExclusionFrames: [CGRect] = []
    @State private var personMasterEditTarget: PersonMasterEditTarget?

    init(visit: Visit, onBack: (() -> Void)? = nil) {
        self.visit = visit
        self.onBack = onBack
    }

    var body: some View {
        let snapshot = ExperienceDetailSnapshot.make(visit: visit, personLinks: personLinks)
        let genreColor = Color(hex: snapshot.category?.colorHex ?? "#6F8F7A")
        let template = CategoryRecordTemplate.template(for: snapshot.category)
        let isTheater = snapshot.category?.templateKey == "theater"
        let accentColor = isTheater
            ? Color(red: 0.82, green: 0.62, blue: 0.30)
            : themePalette.categoryColor(hex: snapshot.category?.colorHex ?? "#6F8F7A")
        let eyecatchPhoto = detailEyecatchPhoto(in: snapshot)
        let backgroundPhoto = detailBackgroundPhoto(in: snapshot)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recordHero(
                    snapshot: snapshot,
                    accentColor: accentColor,
                    genreColor: genreColor,
                    eyecatchPhoto: eyecatchPhoto,
                    backgroundPhoto: backgroundPhoto
                )
                .padding(.horizontal, -20)
                .padding(.top, -24)

                if isTheater {
                    officialLinksSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                    nextActionsSection(snapshot: snapshot, plan: activePlan, accentColor: accentColor)
                    venueMapSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                    theaterPhotoCollectionSection(
                        snapshot: snapshot,
                        excluding: Set([backgroundPhoto?.id, eyecatchPhoto?.id].compactMap { $0 }),
                        accentColor: accentColor
                    )
                    memoSection(template: template, accentColor: accentColor, isTheater: true)
                    theaterCreditsSection(snapshot: snapshot, accentColor: accentColor)
                    theaterFocusSection(snapshot: snapshot, accentColor: accentColor)
                    expenseAndTicketSection(
                        snapshot: snapshot,
                        plan: activePlan,
                        accentColor: accentColor,
                        showsActions: false
                    )
                    peopleSection(snapshot: snapshot, accentColor: accentColor)
                    ocrSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                } else {
                    officialLinksSection(snapshot: snapshot, accentColor: accentColor, isTheater: false)
                    venueMapSection(snapshot: snapshot, accentColor: accentColor, isTheater: false)
                    memoSection(template: template, accentColor: accentColor, isTheater: false)
                    photoSection(
                        snapshot: snapshot,
                        excluding: Set([backgroundPhoto?.id, eyecatchPhoto?.id].compactMap { $0 }),
                        accentColor: accentColor,
                        isTheater: false
                    )
                    classifiedPhotoSection(snapshot: snapshot, purpose: .ticket, accentColor: accentColor, isTheater: false)
                    classifiedPhotoSection(snapshot: snapshot, purpose: .goods, accentColor: accentColor, isTheater: false)
                    expenseAndTicketSection(
                        snapshot: snapshot,
                        plan: activePlan,
                        accentColor: accentColor,
                        showsActions: true
                    )
                    goshuinBookSection(snapshot: snapshot)
                    peopleSection(snapshot: snapshot, accentColor: accentColor)
                    ocrSection(snapshot: snapshot, accentColor: accentColor, isTheater: false)
                    basicInfo(snapshot: snapshot, template: template)
                    advancedSection(snapshot: snapshot)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(detailPageBackground(genreColor: genreColor))
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(edgeBackGesture)
        .onPreferenceChange(DetailBackSwipeExclusionPreferenceKey.self) { frames in
            backSwipeExclusionFrames = frames
        }
        .overlay(alignment: .top) {
            detailNavigationControls(accentColor: accentColor, genreColor: genreColor)
        }
        .sheet(isPresented: $isShowingEdit) {
            EditExperienceView(visit: visit)
        }
        .sheet(item: $calendarDraft) { draft in
            CalendarEventEditSheet(draft: draft)
        }
        .sheet(item: $ticketPlanForEditor) { plan in
            EditTicketAttemptView(plan: plan)
        }
        .sheet(item: $personMasterEditTarget) { target in
            NavigationStack {
                PersonMasterEditDestination(personID: target.id, showsCancelButton: true)
            }
        }
        .navigationDestination(item: $navigatingPlan) { plan in
            PlanDetailView(plan: plan)
        }
        .confirmationDialog("この記録を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("この記録だけ削除", role: .destructive) {
                deleteThisVisit()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この回の記録と写真を削除します。対象（\(snapshot.eventTitle)）と他の記録は残ります。取り消せません。")
        }
        .alert("削除に失敗しました", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deletionErrorMessage = nil }
        } message: {
            Text(deletionErrorMessage ?? "")
        }
        .alert("予定を作成できませんでした", isPresented: Binding(
            get: { planCreationErrorMessage != nil },
            set: { if !$0 { planCreationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { planCreationErrorMessage = nil }
        } message: {
            Text(planCreationErrorMessage ?? "")
        }
        .alert("写真を追加できませんでした", isPresented: Binding(
            get: { photoAddErrorMessage != nil },
            set: { if !$0 { photoAddErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { photoAddErrorMessage = nil }
        } message: {
            Text(photoAddErrorMessage ?? "")
        }
        .confirmationDialog("地図で開く", isPresented: $isShowingMapChooser, titleVisibility: .visible) {
            if let url = snapshot.mapURL {
                Button("Apple Maps") { openURL(url) }
            }
            if let url = googleMapsURL(snapshot: snapshot) {
                Button("Google Maps") { openURL(url) }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .task(id: snapshot.weatherTaskID) {
            await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext)
        }
    }

    private func deleteThisVisit() {
        do {
            try RecordDeletionService.deleteVisit(visit, in: modelContext)
            dismiss()
        } catch {
            deletionErrorMessage = "この記録を削除できませんでした。もう一度お試しください。"
            assertionFailure("Failed to delete visit: \(error)")
        }
    }

    private func recordHero(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color,
        genreColor: Color,
        eyecatchPhoto: PhotoBlob?,
        backgroundPhoto: PhotoBlob?
    ) -> some View {
        let heroSeatText = resolvedHeroSeatText
        return ZStack(alignment: .bottomLeading) {
            recordHeroBackground(
                photo: backgroundPhoto,
                genreColor: genreColor,
                categoryKey: snapshot.category?.templateKey,
                presetKey: snapshot.unitFields.heroBackgroundPresetKey
            )

            VStack(alignment: .leading, spacing: 12) {
                if let seriesName = snapshot.event?.seriesName, !seriesName.isEmpty {
                    HStack(spacing: 8) {
                        Text(seriesName)
                            .lineLimit(1)
                        if snapshot.category?.templateKey == "theater" {
                            Text("•")
                            Text(ExperienceDetailPresentation.theaterVisitOrdinal(for: visit))
                        }
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white.opacity(0.76))
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                } else if snapshot.category?.templateKey == "theater" {
                    Text(ExperienceDetailPresentation.theaterVisitOrdinal(for: visit))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                }

                if let event = snapshot.event {
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(snapshot.eventTitle)
                                .font(FavorecoTypography.jpSerif(27, weight: .bold, relativeTo: .title2))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .shadow(color: .black.opacity(0.62), radius: 5, y: 2)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(snapshot.eventTitle)
                        .font(FavorecoTypography.jpSerif(27, weight: .bold, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.62), radius: 5, y: 2)
                }

                let eventSubtitle = VisitUnitFields(rawValue: snapshot.event?.unitFieldsRaw ?? "")
                    .eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !eventSubtitle.isEmpty {
                    Text(eventSubtitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                }

                HStack(alignment: .top, spacing: 16) {
                    RecordDetailEyecatch(
                        event: snapshot.event,
                        photo: eyecatchPhoto,
                        aspectRatio: snapshot.eyecatchAspectRatio,
                        fallbackSymbol: snapshot.category?.iconSymbol ?? "sparkles.rectangle.stack",
                        tint: accentColor,
                        usesGoldFrame: snapshot.category?.templateKey == "theater"
                    )
                    .frame(width: snapshot.category?.templateKey == "theater" ? 134 : 112)

                    VStack(alignment: .leading, spacing: 11) {
                        heroDateRow(snapshot: snapshot)

                        recordMetadataRow(
                            icon: "clock",
                            text: ExperienceDetailPresentation.performanceTime(for: visit),
                            accentColor: .white.opacity(0.86)
                        )

                        if !snapshot.unitFields.styleNames.isEmpty {
                            recordMetadataRow(
                                icon: "tag.fill",
                                text: snapshot.unitFields.styleNames.joined(separator: "・"),
                                accentColor: accentColor
                            )
                        }

                        if !visit.venueNameSnapshot.isEmpty {
                            recordMetadataRow(
                                icon: "mappin.and.ellipse",
                                text: visit.venueNameSnapshot,
                                accentColor: .white.opacity(0.86)
                            )
                        }

                        if !heroSeatText.isEmpty {
                            recordMetadataRow(
                                icon: "chair",
                                text: heroSeatText,
                                accentColor: .white.opacity(0.86)
                            )
                        }

                        recordRating(accentColor: .white.opacity(0.90))
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minHeight: 560, alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func recordHeroBackground(
        photo: PhotoBlob?,
        genreColor: Color,
        categoryKey: String?,
        presetKey: String
    ) -> some View {
        GeometryReader { proxy in
            let imageBandHeight = min(proxy.size.height * 0.74, 420)
            let defaultImage = defaultHeroBackgroundImage(categoryKey: categoryKey, presetKey: presetKey)

            ZStack(alignment: .top) {
                genreColor

                Group {
                    if let photo {
                        RepresentativePhotoImage(photo: photo, maxPixelSize: 1600, contentMode: .fill)
                    } else if let defaultImage {
                        Image(uiImage: defaultImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [genreColor.opacity(0.92), Color.black.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: proxy.size.width, height: imageBandHeight, alignment: .center)
                .clipped()

                genreColor
                    .opacity(photo == nil && defaultImage == nil ? 0.10 : 0.08)
                    .frame(height: imageBandHeight)

                // ステータスバーと上部操作を、明るい写真でも読める状態に保つ。
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.48), location: 0.00),
                        .init(color: .black.opacity(0.20), location: 0.22),
                        .init(color: .clear, location: 0.46),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: imageBandHeight * 0.58)

                // 写真の色を残したまま、下端だけをジャンル色へ接続する。
                LinearGradient(
                    stops: [
                        .init(color: genreColor.opacity(0.00), location: 0.00),
                        .init(color: genreColor.opacity(0.04), location: 0.50),
                        .init(color: genreColor.opacity(0.30), location: 0.72),
                        .init(color: genreColor.opacity(0.82), location: 0.91),
                        .init(color: genreColor, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: imageBandHeight)
            }
        }
        .clipped()
    }

    private func detailPageBackground(genreColor: Color) -> some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [genreColor, genreColor.opacity(0.72), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func detailNavigationControls(accentColor: Color, genreColor: Color) -> some View {
        HStack {
            Button {
                closeDetail()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.black.opacity(0.48), in: Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.20), lineWidth: 0.7)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            Menu {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("編集", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("この記録だけ削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 50, height: 50)
                    .background(genreColor.opacity(0.86), in: Circle())
                    .overlay {
                        Circle().stroke(accentColor.opacity(0.72), lineWidth: 1)
                    }
            }
            .accessibilityLabel("メニュー")
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 8)
    }

    private var edgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .onEnded { value in
                guard DetailBackSwipePolicy.shouldClose(
                    startLocation: value.startLocation,
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    exclusionFrames: backSwipeExclusionFrames
                ) else { return }
                closeDetail()
            }
    }

    private func closeDetail() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func heroDateRow(snapshot: ExperienceDetailSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 18)
            Text(FavorecoDateText.fullDate(visit.visitedAt))
                .lineLimit(1)
            if !snapshot.unitFields.weatherSymbolName.isEmpty {
                Image(systemName: snapshot.unitFields.weatherSymbolName)
                    .foregroundStyle(.white.opacity(0.90))
                Text(ExperienceDetailPresentation.compactWeatherText(fields: snapshot.unitFields))
                    .lineLimit(1)
            }
        }
        .font(FavorecoTypography.caption)
        .foregroundStyle(.white.opacity(0.84))
    }

    private func recordMetadataRow(icon: String, text: String, accentColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .frame(width: 18)
            Text(text)
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(FavorecoTypography.caption)
    }

    private func recordRating(accentColor: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: ExperienceDetailPresentation.ratingSymbol(rating: visit.overallRating, index: index))
                    .foregroundStyle(visit.overallRating > 0 ? accentColor : Color.secondary.opacity(0.34))
            }
            Text(visit.overallRating > 0 ? String(format: "%.1f", visit.overallRating) : "未評価")
                .foregroundStyle(.white.opacity(0.68))
                .padding(.leading, 4)
        }
        .font(FavorecoTypography.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(visit.overallRating > 0 ? "評価 \(String(format: "%.1f", visit.overallRating))" : "未評価")
    }

    private func detailEyecatchPhoto(in snapshot: ExperienceDetailSnapshot) -> PhotoBlob? {
        if snapshot.event?.eyecatchData != nil { return nil }
        if let event = snapshot.event,
           let representative = EventRepresentativePhotoResolver.photo(for: event),
           ExperiencePhotoPurpose.resolved(from: representative.purpose) == .memory {
            return representative
        }
        return memoryPhotos(in: snapshot).first
    }

    private func detailBackgroundPhoto(in snapshot: ExperienceDetailSnapshot) -> PhotoBlob? {
        let path = snapshot.unitFields.heroBackgroundPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return snapshot.photos.first { $0.relativePath == path }
    }

    private func defaultHeroBackgroundImage(categoryKey: String?, presetKey: String) -> UIImage? {
        guard let categoryKey else { return nil }
        let resourceName = HeroBackgroundPreset.resolved(
            categoryKey: categoryKey,
            storedKey: presetKey
        )?.resourceName ?? "\(categoryKey)-hero-default"
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func memoryPhotos(in snapshot: ExperienceDetailSnapshot) -> [PhotoBlob] {
        snapshot.photos.filter { photo in
            ExperiencePhotoPurpose.resolved(from: photo.purpose) == .memory
        }
    }

    private func officialLinksSection(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color,
        isTheater: Bool
    ) -> some View {
        let officialURLText = snapshot.event?.officialURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let socialLinks = VisitUnitFields(rawValue: snapshot.event?.unitFieldsRaw ?? "").socialLinks
        let ticketLinks = ExperienceDetailPresentation.securedTicketAttempts(in: activePlan).compactMap { attempt -> String? in
            let value = attempt.purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let organizations = theaterOrganizationRows(snapshot: snapshot)

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                guard isTheater else { return }
                withAnimation(.easeInOut(duration: 0.2)) { isOfficialInfoExpanded.toggle() }
            } label: {
                HStack {
                    sectionTitle(isTheater ? "作品・公演情報" : "公式情報")
                    Spacer()
                    if isTheater {
                        Image(systemName: isOfficialInfoExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isTheater || isOfficialInfoExpanded {
                if isTheater, !organizations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(organizations, id: \.label) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(item.label)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 76, alignment: .leading)
                                Text(item.value)
                                    .font(FavorecoTypography.captionStrong)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Divider().overlay(accentColor.opacity(0.24))
                }

                officialLinkRow(
                    icon: "link",
                    title: "公式URL",
                    value: officialURLText,
                    emptyText: "未登録",
                    accentColor: accentColor
                )

                Divider()
                    .overlay(accentColor.opacity(0.24))

                VStack(alignment: .leading, spacing: 8) {
                    Label("チケットサイト", systemImage: "ticket")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    if ticketLinks.isEmpty {
                        Text("未登録")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(ticketLinks.enumerated()), id: \.offset) { _, link in
                            officialLinkButton(value: link, label: link, accentColor: accentColor)
                        }
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 10) {
                    Label("SNS", systemImage: "at")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)

                    if socialLinks.isEmpty {
                        Text("未登録")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(socialLinks.enumerated()), id: \.offset) { _, link in
                            officialLinkButton(
                                value: link,
                                label: socialLinkLabel(for: link),
                                accentColor: accentColor
                            )
                        }
                    }
                }
            }
        }
        .sectionCard(tint: accentColor, emphasized: isTheater)
    }

    private func theaterOrganizationRows(
        snapshot: ExperienceDetailSnapshot
    ) -> [(label: String, value: String)] {
        var rows: [(String, String)] = []
        let organizer = snapshot.event?.organizerNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !organizer.isEmpty { rows.append(("主催", organizer)) }

        for link in snapshot.linkedPeople where !link.isArchived {
            let role = link.displayRole.isEmpty ? ExperienceDetailPresentation.roleName(for: link.roleKey) : link.displayRole
            let normalizedRole: String?
            if role.contains("主催") { normalizedRole = "主催" }
            else if role.contains("企画") || role.contains("制作") { normalizedRole = "企画・制作" }
            else if role.contains("運営") { normalizedRole = "運営" }
            else if role.contains("協賛") { normalizedRole = "協賛" }
            else { normalizedRole = nil }
            guard let normalizedRole else { continue }
            let name = ExperienceDetailPresentation.personName(for: link)
            guard !rows.contains(where: { $0.0 == normalizedRole && $0.1 == name }) else { continue }
            rows.append((normalizedRole, name))
        }
        return rows.map { (label: $0.0, value: $0.1) }
    }

    @ViewBuilder
    private func officialLinkRow(
        icon: String,
        title: String,
        value: String,
        emptyText: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)

            if value.isEmpty {
                Text(emptyText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                officialLinkButton(value: value, label: value, accentColor: accentColor)
            }
        }
    }

    @ViewBuilder
    private func officialLinkButton(value: String, label: String, accentColor: Color) -> some View {
        if let url = normalizedWebURL(from: value) {
            Button {
                openURL(url)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text(label)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .font(FavorecoTypography.body)
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            Text(value)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func normalizedWebURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { return nil }
        return url
    }

    private func socialLinkLabel(for value: String) -> String {
        guard let url = normalizedWebURL(from: value), let host = url.host?.lowercased() else {
            return value
        }
        if host.contains("instagram.com") { return "Instagram" }
        if host == "x.com" || host.hasSuffix(".x.com") || host.contains("twitter.com") { return "X" }
        if host.contains("threads.net") { return "Threads" }
        if host.contains("facebook.com") { return "Facebook" }
        if host.contains("tiktok.com") { return "TikTok" }
        if host.contains("youtube.com") || host == "youtu.be" { return "YouTube" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func venueMapSection(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color,
        isTheater: Bool
    ) -> some View {
        let venueName = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        let hasMapSource = !venueName.isEmpty || !address.isEmpty || latitude != 0 || longitude != 0
        let geocodeText = address.isEmpty ? venueName : address

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("会場")
                Spacer()
                if snapshot.mapURL != nil, hasMapSource {
                    Button {
                        isShowingMapChooser = true
                    } label: {
                        Label("マップで開く", systemImage: "arrow.up.right")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if hasMapSource {
                if !venueName.isEmpty {
                    Text(venueName)
                        .font(FavorecoTypography.bodyStrong)
                        .textSelection(.enabled)
                }
                if !address.isEmpty {
                    Text(address)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: "map")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(accentColor.opacity(0.52))
                    PlaceMapPreview(
                        venueName: venueName,
                        address: geocodeText,
                        latitude: latitude,
                        longitude: longitude
                    )
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .allowsHitTesting(false)
            } else {
                ContentUnavailableView(
                    "会場未登録",
                    systemImage: "map",
                    description: Text("会場や住所を登録すると地図が表示されます")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
        .sectionCard(tint: accentColor, emphasized: isTheater)
    }

    private func googleMapsURL(snapshot: ExperienceDetailSnapshot) -> URL? {
        let venue = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let query = address.isEmpty ? venue : address
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
            return URL(string: "comgooglemaps://?q=\(encoded)")
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&q=\(encoded)")
    }

    @ViewBuilder
    private func classifiedPhotoSection(
        snapshot: ExperienceDetailSnapshot,
        purpose: ExperiencePhotoPurpose,
        accentColor: Color,
        isTheater: Bool
    ) -> some View {
        let photos = snapshot.photos.filter {
            ExperiencePhotoPurpose.resolved(from: $0.purpose) == purpose
        }
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("\(purpose.title)（\(photos.count)件）")
                    Spacer()
                    if isTheater {
                        detailPhotoPicker(purpose: purpose, accentColor: accentColor)
                    }
                }

                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    if index > 0 { Divider() }
                    HStack(alignment: .top, spacing: 12) {
                        RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                            .frame(width: 92, height: 92)
                            .clipped()
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 7) {
                            Label("\(purpose.title) \(index + 1)", systemImage: purpose.systemImage)
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(accentColor)

                            if photo.amount != Decimal(0) {
                                Text(formattedPhotoAmount(photo.amount))
                                    .font(FavorecoTypography.bodyStrong)
                                    .foregroundStyle(.primary)
                            }

                            let text = photo.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                Text(text)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                            } else if photo.amount == Decimal(0) {
                                Text("画像として保存")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater)
        } else if isTheater, purpose == .goods || purpose == .benefit {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle(purpose.title)
                    Spacer()
                    detailPhotoPicker(purpose: purpose, accentColor: accentColor)
                }
                Text(purpose == .goods ? "購入したグッズの写真・金額を残せます" : "来場特典やノベルティを分けて残せます")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .sectionCard(tint: accentColor, emphasized: true)
        }
    }

    @ViewBuilder
    private func detailPhotoPicker(
        purpose: ExperiencePhotoPurpose,
        accentColor: Color,
        title: String = "追加"
    ) -> some View {
        let labelFont = FavorecoTypography.captionStrong
        switch purpose {
        case .memory:
            PhotosPicker(selection: $memoryPhotoItems, maxSelectionCount: 20, matching: .images) {
                Label(title, systemImage: "plus")
                    .font(labelFont)
                    .foregroundStyle(accentColor)
            }
                .onChange(of: memoryPhotoItems) { _, items in
                    Task { await addDetailPhotos(items, purpose: .memory); memoryPhotoItems = [] }
                }
        case .goods:
            PhotosPicker(selection: $goodsPhotoItems, maxSelectionCount: 20, matching: .images) {
                Label(title, systemImage: "plus")
                    .font(labelFont)
                    .foregroundStyle(accentColor)
            }
                .onChange(of: goodsPhotoItems) { _, items in
                    Task { await addDetailPhotos(items, purpose: .goods); goodsPhotoItems = [] }
                }
        case .benefit:
            PhotosPicker(selection: $benefitPhotoItems, maxSelectionCount: 20, matching: .images) {
                Label(title, systemImage: "plus")
                    .font(labelFont)
                    .foregroundStyle(accentColor)
            }
                .onChange(of: benefitPhotoItems) { _, items in
                    Task { await addDetailPhotos(items, purpose: .benefit); benefitPhotoItems = [] }
                }
        case .ticket:
            Button { isShowingEdit = true } label: {
                Label(title, systemImage: "plus")
                    .font(labelFont)
                    .foregroundStyle(accentColor)
            }
        }
    }

    @MainActor
    private func addDetailPhotos(_ items: [PhotosPickerItem], purpose: ExperiencePhotoPurpose) async {
        guard !items.isEmpty else { return }
        var inserted = 0
        for item in items {
            guard let sourceData = try? await item.loadTransferable(type: Data.self),
                  var pending = await Task.detached(priority: .userInitiated, operation: {
                      PendingPhoto.make(from: sourceData, filename: "detail-photo.jpg", compressionQuality: 0.82)
                  }).value else { continue }
            pending.metadata.purpose = purpose
            modelContext.insert(pending.makePhotoBlob(visit: visit))
            inserted += 1
        }
        guard inserted > 0 else {
            photoAddErrorMessage = "選択した画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        visit.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            photoAddErrorMessage = "写真を保存できませんでした。もう一度お試しください。"
        }
    }

    private func formattedPhotoAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
    }

    private var activePlan: Plan? {
        (visit.plans ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    @ViewBuilder
    private func expenseAndTicketSection(
        snapshot: ExperienceDetailSnapshot,
        plan: Plan?,
        accentColor: Color,
        showsActions: Bool
    ) -> some View {
        let supportsTicketManagement = ["theater", "live"].contains(snapshot.category?.templateKey ?? "")
        VStack(alignment: .leading, spacing: 12) {
            ticketAndSeatCard(snapshot: snapshot, plan: plan, accentColor: accentColor)

            ExperienceExpenseSummaryCard(
                summary: ExperienceExpenseSummary.make(visit: visit, plan: plan),
                tint: accentColor
            )

            if supportsTicketManagement && showsActions {
                HStack(spacing: 10) {
                    Button {
                        guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                        ticketPlanForEditor = plan
                    } label: {
                        Label("申込を追加", systemImage: "ticket")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)

                    Button {
                        guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                        navigatingPlan = plan
                    } label: {
                        Label("遠征ToDo", systemImage: "suitcase.rolling")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                }

                Text("申込、ホテル・新幹線・飛行機などの遠征予定と費用を、この記録に紐づけて管理します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nextActionsSection(
        snapshot: ExperienceDetailSnapshot,
        plan: Plan?,
        accentColor: Color
    ) -> some View {
        let isPerformanceDayOrLater = Calendar.current.startOfDay(for: Date()) >= Calendar.current.startOfDay(for: visit.visitedAt)
        let outstanding = outstandingActionCount(in: plan)

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isNextActionsExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("次にやること", systemImage: "checklist")
                        .font(FavorecoTypography.sectionTitle)
                    Spacer()
                    if outstanding > 0 {
                        Text("未完了 \(outstanding)")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                    }
                    Image(systemName: isNextActionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isNextActionsExpanded {
                HStack(spacing: 10) {
                    Button {
                        guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                        ticketPlanForEditor = plan
                    } label: {
                        Label("チケット申込", systemImage: "ticket")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)

                    Button {
                        guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                        navigatingPlan = plan
                    } label: {
                        Label("遠征ToDo", systemImage: "suitcase.rolling")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                }

                Text("申込・入金・発券と、移動／宿泊などの準備をここから確認できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sectionCard(tint: accentColor, emphasized: true)
        .onAppear {
            isNextActionsExpanded = !isPerformanceDayOrLater || outstanding > 0
        }
    }

    private func outstandingActionCount(in plan: Plan?) -> Int {
        let attempts = (plan?.ticketAttempts ?? []).filter { !$0.isArchived }
        let pendingTickets = attempts.filter { ["planned", "applied", "won", "waitingPayment", "waitingIssue"].contains($0.statusKey) }.count
        let preparation = plan.map { PlanPreparationFields(rawValue: $0.unitFieldsRaw) }
        let pendingTasks = preparation?.tasks.filter { !$0.isCompleted }.count ?? 0
        return pendingTickets + pendingTasks
    }

    @ViewBuilder
    private func ticketAndSeatCard(
        snapshot: ExperienceDetailSnapshot,
        plan: Plan?,
        accentColor: Color
    ) -> some View {
        let attempts = ExperienceDetailPresentation.securedTicketAttempts(in: plan)
        let hasVisitDetails = !visit.seatText.isEmpty || !visit.outcomeKey.isEmpty

        if hasVisitDetails || !attempts.isEmpty || snapshot.category?.templateKey == "theater" {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("チケット・座席")

                let ticketPhotos = snapshot.photos.filter {
                    ExperiencePhotoPurpose.resolved(from: $0.purpose) == .ticket
                }
                if !ticketPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ticketPhotos) { photo in
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 420, contentMode: .fill)
                                    .frame(width: 88, height: 88)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }

                if !visit.seatText.isEmpty {
                    DetailInfoRow(icon: "chair", title: "座席", value: visit.seatText)
                }

                if attempts.isEmpty, !visit.outcomeKey.isEmpty {
                    DetailInfoRow(
                        icon: "ticket",
                        title: "状態",
                        value: snapshot.ticketStatusText
                    )
                }

                ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.12))
                    }

                    if attempts.count > 1 {
                        Text("チケット \(index + 1)")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                    }

                    DetailInfoRow(
                        icon: "ticket",
                        title: "状態",
                        value: TicketStatusDefinition.name(for: attempt.statusKey)
                    )

                    if !attempt.entryRouteKey.isEmpty {
                        DetailInfoRow(
                            icon: "person.text.rectangle",
                            title: "申込",
                            value: TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
                        )
                    }

                    if !attempt.ticketSite.isEmpty {
                        DetailInfoRow(icon: "safari", title: "購入元", value: attempt.ticketSite)
                    }

                    if !attempt.seatText.isEmpty, attempt.seatText != visit.seatText {
                        DetailInfoRow(icon: "chair", title: "座席", value: attempt.seatText)
                    }

                    if attempt.price > 0 {
                        DetailInfoRow(
                            icon: "ticket.fill",
                            title: "券面",
                            value: ticketAmountText(attempt.price, quantity: attempt.quantity)
                        )
                    }

                    if attempt.fee > 0 {
                        DetailInfoRow(
                            icon: "plus.circle",
                            title: "手数料",
                            value: ticketAmountText(attempt.fee, quantity: attempt.quantity)
                        )
                    }
                }

                if snapshot.category?.templateKey == "theater" {
                    HStack(spacing: 8) {
                        compactImportButton("画像・OCR", icon: "doc.viewfinder")
                        compactImportButton("URL", icon: "link.badge.plus")
                        compactImportButton("手入力", icon: "plus")
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: snapshot.category?.templateKey == "theater")
        }
    }

    private func compactImportButton(_ title: String, icon: String) -> some View {
        Button {
            isShowingEdit = true
        } label: {
            Label(title, systemImage: icon)
                .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var resolvedHeroSeatText: String {
        if !visit.seatText.isEmpty { return visit.seatText }
        return ExperienceDetailPresentation.securedTicketAttempts(in: activePlan)
            .first(where: { !$0.seatText.isEmpty })?
            .seatText ?? ""
    }

    private func ticketAmountText(_ amount: Decimal, quantity: Int) -> String {
        let amountText = formattedPhotoAmount(amount)
        return quantity > 1 ? "\(amountText) × \(quantity)枚" : amountText
    }

    private func ensureTicketPlan(snapshot: ExperienceDetailSnapshot) -> Plan? {
        if let activePlan { return activePlan }

        let now = Date()
        let plan = Plan(
            title: snapshot.eventTitle,
            subtitle: snapshot.event?.seriesName ?? "",
            stateKey: "attended",
            startsAt: visit.visitedAt,
            endsAt: visit.endedAt > visit.visitedAt ? visit.endedAt : visit.visitedAt.addingTimeInterval(2 * 60 * 60),
            opensAt: visit.visitedAt,
            venueNameSnapshot: visit.venueNameSnapshot,
            organizerNameSnapshot: snapshot.event?.organizerNameSnapshot ?? "",
            officialURL: snapshot.event?.officialURL ?? "",
            createdAt: now,
            updatedAt: now,
            category: snapshot.category,
            event: snapshot.event,
            placeMaster: visit.placeMaster,
            visit: visit
        )
        modelContext.insert(plan)
        do {
            try modelContext.save()
            return plan
        } catch {
            modelContext.rollback()
            planCreationErrorMessage = "チケット・遠征管理を開始できませんでした。もう一度お試しください。"
            return nil
        }
    }

    @ViewBuilder
    private func theaterCreditsSection(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        let legacyCastLinks = snapshot.linkedPeople.filter { ExperienceDetailPresentation.isTheaterCastLink($0) }
        if !snapshot.eventCreditsText.isEmpty || !legacyCastLinks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("キャスト・スタッフ")

                if !snapshot.eventCreditsText.isEmpty {
                    Text(snapshot.eventCreditsText)
                        .font(FavorecoTypography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if !legacyCastLinks.isEmpty {
                    Text(snapshot.eventCreditsText.isEmpty ? "登録済みの出演者" : "以前の形式で登録した出演者")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(legacyCastLinks.map { link in
                        let role = link.displayRole.isEmpty
                            ? ExperienceDetailPresentation.roleName(for: link.roleKey)
                            : link.displayRole
                        return "\(role)：\(ExperienceDetailPresentation.personName(for: link))"
                    }.joined(separator: "\n"))
                    .font(FavorecoTypography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
            .sectionCard(tint: accentColor, emphasized: true)
        }
    }

    @ViewBuilder
    private func theaterFocusSection(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        let focusLinks = snapshot.linkedPeople.filter { $0.roleKey == PersonRoleOption.theaterFocus.key }
        if !focusLinks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("お目当て・注目した人")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(focusLinks) { link in
                            let reactionTitles = TheaterFocusLinkMetadata(memo: link.memo)
                                .reactionKeys
                                .map { TheaterFocusReaction.title(for: $0) }
                            if let personID = link.person?.id {
                                Button {
                                    personMasterEditTarget = PersonMasterEditTarget(id: personID)
                                } label: {
                                    TheaterCastItem(
                                        name: ExperienceDetailPresentation.personName(for: link),
                                        role: reactionTitles.isEmpty ? "注目" : reactionTitles.joined(separator: "・"),
                                        imageData: link.person?.imageData,
                                        imagePath: link.person?.imagePath ?? "",
                                        roleTagsRaw: link.person?.roleTagsRaw ?? "",
                                        tint: accentColor
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("人物マスターを編集")
                            } else {
                                TheaterCastItem(
                                    name: ExperienceDetailPresentation.personName(for: link),
                                    role: reactionTitles.isEmpty ? "注目" : reactionTitles.joined(separator: "・"),
                                    imageData: nil,
                                    imagePath: "",
                                    roleTagsRaw: "",
                                    tint: accentColor
                                )
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .sectionCard(tint: accentColor, emphasized: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DetailBackSwipeExclusionPreferenceKey.self,
                        value: [proxy.frame(in: .global)]
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func theaterPhotoCollectionSection(
        snapshot: ExperienceDetailSnapshot,
        excluding excludedPhotoIDs: Set<UUID>,
        accentColor: Color
    ) -> some View {
        let memories = memoryPhotos(in: snapshot).filter { !excludedPhotoIDs.contains($0.id) }
        let collection = snapshot.photos.filter {
            let purpose = ExperiencePhotoPurpose.resolved(from: $0.purpose)
            return purpose == .goods || purpose == .benefit
        }

        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isPhotoCollectionExpanded.toggle() }
            } label: {
                HStack {
                    sectionTitle("写真・コレクション")
                    Spacer()
                    Text("\(memories.count + collection.count)枚")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isPhotoCollectionExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPhotoCollectionExpanded {
                HStack {
                    Label("思い出", systemImage: "camera")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer()
                    detailPhotoPicker(purpose: .memory, accentColor: accentColor)
                }

                if memories.isEmpty {
                    Text("当日の写真や会場の思い出を追加できます")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    theaterPhotoGrid(memories, accentColor: accentColor, showsPurpose: false)
                }

                Divider().overlay(accentColor.opacity(0.24))

                VStack(alignment: .leading, spacing: 8) {
                    Label("グッズ・ノベルティ・特典", systemImage: "gift")
                        .font(FavorecoTypography.bodyStrong)
                    HStack(spacing: 12) {
                        Spacer()
                        detailPhotoPicker(purpose: .goods, accentColor: accentColor, title: "グッズ")
                        detailPhotoPicker(purpose: .benefit, accentColor: accentColor, title: "特典")
                    }
                }

                if collection.isEmpty {
                    Text("購入品や来場特典を、分類・金額と一緒に追加できます")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    theaterPhotoGrid(collection, accentColor: accentColor, showsPurpose: true)
                }
            }
        }
        .sectionCard(tint: accentColor, emphasized: true)
    }

    private func theaterPhotoGrid(
        _ photos: [PhotoBlob],
        accentColor: Color,
        showsPurpose: Bool
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 10
        ) {
            ForEach(photos) { photo in
                let purpose = ExperiencePhotoPurpose.resolved(from: photo.purpose)
                VStack(alignment: .leading, spacing: 5) {
                    ZStack(alignment: .bottomLeading) {
                        RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        if showsPurpose {
                            Label(purpose.title, systemImage: purpose.systemImage)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.66), in: Capsule())
                                .padding(5)
                        }
                    }
                    if photo.amount != Decimal(0) {
                        Text(formattedPhotoAmount(photo.amount))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoSection(
        snapshot: ExperienceDetailSnapshot,
        excluding excludedPhotoIDs: Set<UUID>,
        accentColor: Color,
        isTheater: Bool
    ) -> some View {
        let galleryPhotos = memoryPhotos(in: snapshot).filter { !excludedPhotoIDs.contains($0.id) }
        if !galleryPhotos.isEmpty || isTheater {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle(isTheater ? "思い出" : "写真")
                    Spacer()
                    if isTheater {
                        detailPhotoPicker(purpose: .memory, accentColor: accentColor)
                    }
                }

                if galleryPhotos.isEmpty {
                    Text("当日の写真や会場の思い出を追加できます")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(galleryPhotos) { photo in
                            ZStack(alignment: .bottomLeading) {
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                    .background(Color(.secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                if photo.relativePath == visit.eyecatchPath {
                                    Image(systemName: "star.fill")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(.black.opacity(0.58), in: Circle())
                                        .padding(5)
                                }
                            }
                        }
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater)
        }
    }

    @ViewBuilder
    private func goshuinBookSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if snapshot.category?.templateKey == "goshuin", !snapshot.unitFields.goshuinBookSizeKey.isEmpty {
            let size = GoshuinBookSize.option(for: snapshot.unitFields.goshuinBookSizeKey)
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("御朱印帳")
                DetailInfoRow(
                    icon: "book.closed",
                    title: "サイズ",
                    value: "\(size.name)（\(size.displaySize)）"
                )
            }
            .sectionCard()
        }
    }

    @ViewBuilder
    private func peopleSection(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        let links = snapshot.category?.templateKey == "theater"
            ? snapshot.linkedPeople.filter {
                !ExperienceDetailPresentation.isTheaterCastLink($0)
                    && $0.roleKey != PersonRoleOption.theaterFocus.key
            }
            : snapshot.linkedPeople
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(snapshot.category?.templateKey == "theater" ? "スタッフ・関係者" : "人物・団体")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(links) { link in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(link.displayRole.isEmpty ? ExperienceDetailPresentation.roleName(for: link.roleKey) : link.displayRole)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.12), in: Capsule())

                            Text(link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物・団体" : link.nameSnapshot)
                                .font(FavorecoTypography.bodyStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .sectionCard()
        }
    }

    @ViewBuilder
    private func ocrSection(snapshot: ExperienceDetailSnapshot, accentColor: Color, isTheater: Bool) -> some View {
        if !snapshot.unitFields.ocrText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isOCRExpanded.toggle() }
                } label: {
                    HStack {
                        sectionTitle("OCR・取込結果")
                        Spacer()
                        Image(systemName: isOCRExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if isOCRExpanded {
                    Text(snapshot.unitFields.ocrText)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater)
        }
    }

    private func basicInfo(snapshot: ExperienceDetailSnapshot, template: CategoryRecordTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(template.visitSectionTitle)

            if !snapshot.unitFields.weatherSymbolName.isEmpty {
                DetailInfoRow(
                    icon: snapshot.unitFields.weatherSymbolName,
                    title: "天気",
                    value: snapshot.weatherTemperatureText
                )
                if let weatherAttributionURL = snapshot.weatherAttributionURL {
                    Link(destination: weatherAttributionURL) {
                        Label("Apple Weather", systemImage: "apple.logo")
                            .font(FavorecoTypography.caption)
                    }
                }
            }

            Button {
                calendarDraft = makeCalendarDraft(snapshot: snapshot)
            } label: {
                Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .sectionCard()
    }

    @ViewBuilder
    private func advancedSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if !snapshot.unitFields.advancedEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("詳細オプション")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.unitFields.advancedEntries) { entry in
                        if !entry.isEmpty {
                            DetailInfoRow(
                                icon: "slider.horizontal.3",
                                title: entry.trimmedLabel.isEmpty ? "追加項目" : entry.trimmedLabel,
                                value: entry.trimmedValue
                            )
                        }
                    }
                }
            }
            .sectionCard()
        }
    }

    @ViewBuilder
    private func memoSection(
        template: CategoryRecordTemplate,
        accentColor: Color,
        isTheater: Bool
    ) -> some View {
        let tagNames = TheaterEmotionTags.names(from: visit.tagNamesRaw)
        if !visit.note.isEmpty || !tagNames.isEmpty || isTheater {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    guard isTheater else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { isReviewSectionExpanded.toggle() }
                } label: {
                    HStack {
                        sectionTitle(isTheater ? "感想" : template.memoSectionTitle)
                        Spacer()
                        if isTheater {
                            Image(systemName: isReviewSectionExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !isTheater || isReviewSectionExpanded {
                    if !tagNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(tagNames, id: \.self) { tag in
                                    Label(tag, systemImage: "heart.text.square")
                                        .font(FavorecoTypography.caption)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(accentColor.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    if visit.note.isEmpty {
                        Text("感想はまだありません")
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        let isLong = visit.note.count > 180
                        Text(visit.note)
                            .font(FavorecoTypography.body)
                            .foregroundStyle(.primary)
                            .lineLimit(isLong && !isReviewExpanded ? 5 : nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if isLong {
                            Button(isReviewExpanded ? "閉じる" : "続きを読む") {
                                withAnimation(.easeInOut(duration: 0.2)) { isReviewExpanded.toggle() }
                            }
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                        }
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.sectionTitle)
    }

    private func makeCalendarDraft(snapshot: ExperienceDetailSnapshot) -> CalendarEventDraft {
        let endDate = visit.endedAt > visit.visitedAt
            ? visit.endedAt
            : Calendar.current.date(byAdding: .hour, value: 2, to: visit.visitedAt) ?? visit.visitedAt
        var notes: [String] = []
        if !visit.seatText.isEmpty {
            notes.append("座席・チケット: \(visit.seatText)")
        }
        if !snapshot.ticketStatusText.isEmpty && !visit.outcomeKey.isEmpty {
            notes.append("チケット状態: \(snapshot.ticketStatusText)")
        }
        if visit.amount != Decimal(0) {
            notes.append("金額: \(snapshot.formattedAmount)")
        }
        if !visit.note.isEmpty {
            notes.append("")
            notes.append(visit.note)
        }
        if let url = snapshot.event?.officialURL, !url.isEmpty {
            notes.append("")
            notes.append(url)
        }

        return CalendarEventDraft(
            title: snapshot.eventTitle,
            location: snapshot.preferredLocationText,
            notes: notes.joined(separator: "\n"),
            startDate: visit.visitedAt,
            endDate: endDate
        )
    }

}

private struct RecordDetailEyecatch: View {
    let event: ExperienceEvent?
    let photo: PhotoBlob?
    let aspectRatio: Double
    let fallbackSymbol: String
    let tint: Color
    let usesGoldFrame: Bool

    var body: some View {
        Group {
            if let data = event?.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let photo {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 720, contentMode: .fill)
            } else {
                ZStack {
                    tint.opacity(0.18)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(tint)
                }
            }
        }
        .aspectRatio(CGFloat(max(aspectRatio, 0.35)), contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(usesGoldFrame ? tint.opacity(0.92) : tint.opacity(0.42), lineWidth: usesGoldFrame ? 1.7 : 0.8)
                .padding(usesGoldFrame ? 2 : 0)
        }
        .overlay {
            if usesGoldFrame {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 0.7)
            }
        }
        .shadow(color: usesGoldFrame ? tint.opacity(0.24) : .clear, radius: 5, y: 2)
    }
}

private struct TheaterCastItem: View {
    let name: String
    let role: String
    let imageData: Data?
    let imagePath: String
    let roleTagsRaw: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            avatar
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(tint.opacity(0.46), lineWidth: 1)
                }

            Text(name)
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 74)

            Text(role)
                .font(FavorecoTypography.jpSans(9, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 74)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = personImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                tint.opacity(0.22)
                Image(systemName: PersonActivityTags.icon(for: roleTagsRaw))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    private var personImage: UIImage? {
        if let imageData, let image = UIImage(data: imageData) {
            return image
        }
        let trimmedPath = imagePath.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

private struct DetailInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    func sectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
            }
    }

    func sectionCard(tint: Color, emphasized: Bool) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(
                    colors: emphasized
                        ? [Color.black.opacity(0.28), tint.opacity(0.055)]
                        : [Color.white.opacity(0.075), Color.white.opacity(0.055)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: emphasized ? 12 : 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: emphasized ? 12 : 8, style: .continuous)
                    .stroke(emphasized ? tint.opacity(0.42) : Color.white.opacity(0.12), lineWidth: emphasized ? 0.9 : 0.6)
            }
    }
}

#Preview {
    let category = RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45")
    let event = ExperienceEvent(title: "サンプル公演", seriesName: "東京公演", category: category)
    let visit = Visit(venueNameSnapshot: "東京芸術劇場", overallRating: 4.5, note: "余韻が長く残った回。", event: event)

    NavigationStack {
        ExperienceDetailView(visit: visit)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
