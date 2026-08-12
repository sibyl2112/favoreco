//
//  ExperienceDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit
import Photos
import PhotosUI
import Combine

private enum DetailPhotoSourceAction {
    case library
    case camera
}

private struct DetailPhotoSourceSheet: View {
    let onLibrary: () -> Void
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("写真を追加")
                .font(FavorecoTypography.sectionTitle)
                .frame(maxWidth: .infinity)

            Button(action: onLibrary) {
                Text("写真ライブラリから選ぶ")
                    .font(FavorecoTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onCamera) {
                Text("カメラで撮影")
                    .font(FavorecoTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .presentationDetents([.height(210)])
        .presentationDragIndicator(.visible)
    }
}

struct CategoryExperiencePage<Hero: View, Content: View>: View {
    let genreColor: Color
    let borderColor: Color
    let scrollTargetID: UUID?
    let showsScrollingFrame: Bool
    private let hero: () -> Hero
    private let content: () -> Content

    init(
        genreColor: Color,
        borderColor: Color,
        scrollTargetID: UUID? = nil,
        showsScrollingFrame: Bool = false,
        @ViewBuilder hero: @escaping () -> Hero,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.genreColor = genreColor
        self.borderColor = borderColor
        self.scrollTargetID = scrollTargetID
        self.showsScrollingFrame = showsScrollingFrame
        self.hero = hero
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pageHeader

                    LazyVStack(alignment: .leading, spacing: 20) {
                        content()
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .modifier(
                    CategoryEmbeddedDetailCardModifier(
                        isEnabled: showsScrollingFrame,
                        genreColor: genreColor,
                        borderColor: borderColor
                    )
                )
                .padding(.horizontal, showsScrollingFrame ? 10 : 0)
                .padding(.top, showsScrollingFrame ? 74 : 0)
            }
            // 没入型詳細は暗い写真・ジャンル色面の上へ表示する。
            // Buttonのtintによって本文が低輝度のジャンル色へ解決されないよう、
            // ページ本文の基準色を明るいアイボリーへ固定する。
            .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.90))
            .scrollIndicators(showsScrollingFrame ? .hidden : .automatic)
            .task(id: scrollTargetID) {
                guard let scrollTargetID else { return }
                await Task.yield()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(scrollTargetID, anchor: .center)
                }
            }
        }
        .background {
            if !showsScrollingFrame {
                categoryDetailPageBackground(genreColor: genreColor)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea(edges: showsScrollingFrame ? [] : .top)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var pageHeader: some View {
        hero()
            .padding(.horizontal, -20)
            .padding(.top, -24)

        LinearGradient(
            colors: [genreColor, genreColor.opacity(0.56), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 12)
        .padding(.horizontal, -20)
    }
}

struct CategoryEmbeddedDetailCardModifier: ViewModifier {
    let isEnabled: Bool
    let genreColor: Color
    let borderColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .background {
                    categoryDetailPageBackground(genreColor: genreColor)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            borderColor.opacity(0.72),
                            lineWidth: 0.8
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.48), radius: 22, y: 8)
        } else {
            content
        }
    }
}

func categoryDetailPageBackground(genreColor: Color) -> some View {
    ZStack {
        Color.black
        LinearGradient(
            colors: [genreColor, genreColor.opacity(0.72), Color.black.opacity(0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct CategoryDetailBottomActionBar: View {
    let shareText: String
    let tint: Color
    let labelColor: Color
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(tint.opacity(0.54))
                .frame(height: 0.8)

            HStack(spacing: 0) {
                Button(action: onEdit) {
                    FavorecoIconLabel("編集", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(tint.opacity(0.42))
                    .frame(width: 0.8, height: 34)

                ShareLink(item: shareText) {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }
}

private struct DetailBackSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct PersonMasterEditTarget: Identifiable {
    let id: UUID
}

private struct ExperiencePhotoViewerRequest: Identifiable {
    let id = UUID()
    let photoIDs: [UUID]
    let initialPhotoID: UUID
}

struct ExperienceDetailView: View {
    let visit: Visit
    private let showsScrollingFrame: Bool
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?
    let onOpenVisit: ((UUID) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @State private var isShowingEdit = false
    @State private var ticketPlanForEditor: Plan?
    @State private var navigatingPlan: Plan?
    @State private var recordPreparationPlan: Plan?
    @State private var navigatingEventID: UUID?
    @State private var navigatingSiblingVisit: Visit?
    @State private var isShowingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?
    @State private var planCreationErrorMessage: String?
    @State private var isNextActionsExpanded = false
    @State private var isOCRExpanded = false
    @State private var isReviewExpanded = false
    @State private var isOfficialInfoExpanded = false
    @State private var isVenueExpanded = false
    @State private var isPhotoCollectionExpanded = true
    @State private var isReviewSectionExpanded = true
    @State private var isTicketExpanded = false
    @State private var isTravelRecordExpanded = true
    @State private var isExpenseExpanded = false
    @State private var isCastExpanded = false
    @State private var isBookInformationExpanded = false
    @State private var isBookReadingExpanded = false
    @State private var isBookPhotosExpanded = true
    @State private var eventEyecatchRefreshVersion = 0
    @State private var isBookMemoExpanded = true
    @State private var isPlaceOfficialInfoExpanded = true
    @State private var isPlaceVenueExpanded = true
    @State private var isPlaceMemoExpanded = true
    @State private var isPlacePhotosExpanded = true
    @State private var isPlaceTicketPhotosExpanded = true
    @State private var isPlaceGoodsPhotosExpanded = true
    @State private var isPlaceBenefitPhotosExpanded = true
    @State private var isPlacePeopleExpanded = true
    @State private var isPlaceBasicInfoExpanded = true
    @State private var isPlaceAdvancedExpanded = true
    @State private var isGenericTicketExpanded = true
    @State private var isGoshuinBookExpanded = true
    @State private var isShowingMapChooser = false
    @State private var memoryPhotoItems: [PhotosPickerItem] = []
    @State private var goodsPhotoItems: [PhotosPickerItem] = []
    @State private var benefitPhotoItems: [PhotosPickerItem] = []
    @State private var photoAddErrorMessage: String?
    @State private var pendingPhotoPurpose: ExperiencePhotoPurpose?
    @State private var isShowingPhotoSourceChoice = false
    @State private var queuedPhotoSourceAction: DetailPhotoSourceAction?
    @State private var isShowingDetailLibrary = false
    @State private var isShowingDetailCamera = false
    @State private var isShowingDetailCameraUnavailable = false
    @State private var backSwipeExclusionFrames: [CGRect] = []
    @State private var personMasterEditTarget: PersonMasterEditTarget?
    @State private var photoViewerRequest: ExperiencePhotoViewerRequest?
    @State private var isShowingActionMenu = false
    @State private var isShowingRepeatEntry = false
    @State private var isMuseumHistoryExpanded = true

    init(
        visit: Visit,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil,
        onOpenVisit: ((UUID) -> Void)? = nil,
        showsScrollingFrame: Bool? = nil
    ) {
        self.visit = visit
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
        self.onOpenVisit = onOpenVisit
        self.showsScrollingFrame = showsScrollingFrame ?? (onBack != nil)
    }

    var body: some View {
        let snapshot = ExperienceDetailSnapshot.make(visit: visit, personLinks: personLinks)
        let genreColor = Color(hex: snapshot.category?.colorHex ?? "#6F8F7A")
        let template = CategoryRecordTemplate.template(for: snapshot.category)
        let isTheater = snapshot.category?.templateKey == "theater"
        let isBook = snapshot.category?.templateKey == "book"
        let categoryHex = themePalette.resolvedHex(categoryHex: snapshot.category?.colorHex ?? "#6F8F7A")
        let accentColor = isTheater
            ? Color(red: 0.82, green: 0.62, blue: 0.30)
            : Color.legibleDetailAccent(hex: categoryHex)
        let eyecatchPhoto = detailEyecatchPhoto(in: snapshot)
        let backgroundPhoto = detailBackgroundPhoto(in: snapshot)

        Group {
            if isTheater {
                CategoryExperiencePage(
                    genreColor: genreColor,
                    borderColor: accentColor,
                    showsScrollingFrame: showsScrollingFrame
                ) {
                    recordHero(
                        snapshot: snapshot,
                        accentColor: accentColor,
                        genreColor: genreColor,
                        eyecatchPhoto: eyecatchPhoto,
                        backgroundPhoto: backgroundPhoto
                    )
                } content: {
                    officialLinksSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                    venueMapSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                    nextActionsSection(snapshot: snapshot, plan: activePlan, accentColor: accentColor)
                    theaterPhotoCollectionSection(
                        snapshot: snapshot,
                        excluding: Set([backgroundPhoto?.id, eyecatchPhoto?.id].compactMap { $0 }),
                        accentColor: accentColor
                    )
                    memoSection(template: template, accentColor: accentColor, isTheater: true)
                    ticketAndSeatCard(snapshot: snapshot, plan: activePlan, accentColor: accentColor)
                    theaterTravelRecordSection(
                        snapshot: snapshot,
                        plan: activePlan,
                        accentColor: accentColor
                    )
                    ExperienceExpenseSummaryCard(
                        summary: ExperienceExpenseSummary.make(visit: visit, plan: activePlan),
                        tint: accentColor,
                        title: "費用",
                        isExpanded: $isExpenseExpanded,
                        titleFont: TheaterDetailSectionStyle.titleFont
                    )
                    theaterCastAndFocusSection(snapshot: snapshot, accentColor: accentColor)
                    ocrSection(snapshot: snapshot, accentColor: accentColor, isTheater: true)
                }
            } else {
                CategoryExperiencePage(
                    genreColor: genreColor,
                    borderColor: accentColor,
                    showsScrollingFrame: showsScrollingFrame
                ) {
                    recordHero(
                        snapshot: snapshot,
                        accentColor: accentColor,
                        genreColor: genreColor,
                        eyecatchPhoto: eyecatchPhoto,
                        backgroundPhoto: backgroundPhoto
                    )
                } content: {
                        if isBook {
                            AnyView(bookInformationSection(snapshot: snapshot, accentColor: accentColor))
                            AnyView(bookReadingSection(snapshot: snapshot, accentColor: accentColor))
                            if hasVenueMapSource {
                                AnyView(venueMapSection(snapshot: snapshot, accentColor: accentColor, isTheater: false))
                            }
                            AnyView(bookPhotosSection(
                                snapshot: snapshot,
                                excluding: Set([eyecatchPhoto?.id].compactMap { $0 }),
                                accentColor: accentColor
                            ))
                            AnyView(bookMemoSection(accentColor: accentColor))
                        } else {
                            AnyView(officialLinksSection(snapshot: snapshot, accentColor: accentColor, isTheater: false))
                            AnyView(venueMapSection(snapshot: snapshot, accentColor: accentColor, isTheater: false))
                            if snapshot.category?.templateKey == "museum" {
                                AnyView(museumVisitHistorySection(accentColor: accentColor))
                            }
                            AnyView(memoSection(template: template, accentColor: accentColor, isTheater: false))
                            AnyView(photoSection(
                                snapshot: snapshot,
                                excluding: Set([backgroundPhoto?.id, eyecatchPhoto?.id].compactMap { $0 }),
                                accentColor: accentColor,
                                isTheater: false
                            ))
                            AnyView(classifiedPhotoSection(snapshot: snapshot, purpose: .ticket, accentColor: accentColor, isTheater: false))
                            AnyView(classifiedPhotoSection(snapshot: snapshot, purpose: .goods, accentColor: accentColor, isTheater: false))
                            AnyView(classifiedPhotoSection(snapshot: snapshot, purpose: .benefit, accentColor: accentColor, isTheater: false))
                            AnyView(expenseAndTicketSection(
                                snapshot: snapshot,
                                plan: activePlan,
                                accentColor: accentColor,
                                showsActions: true
                            ))
                            AnyView(goshuinBookSection(snapshot: snapshot))
                            AnyView(peopleSection(snapshot: snapshot, accentColor: accentColor))
                            AnyView(ocrSection(snapshot: snapshot, accentColor: accentColor, isTheater: false))
                            AnyView(basicInfo(snapshot: snapshot, template: template))
                            AnyView(advancedSection(snapshot: snapshot))
                        }
                    }
            }
        }
        .id(eventEyecatchRefreshVersion)
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(edgeBackGesture)
        .onPreferenceChange(DetailBackSwipeExclusionPreferenceKey.self) { frames in
            backSwipeExclusionFrames = frames
        }
        .overlay(alignment: .top) {
            detailNavigationControls(accentColor: accentColor, genreColor: genreColor)
        }
        .favorecoDetailActionMenu(
            isPresented: $isShowingActionMenu,
            genreColor: genreColor,
            accentColor: accentColor,
            topPadding: onBack != nil ? 116 : 70,
            actions: recordMenuActions
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if onBack != nil {
                CategoryDetailBottomActionBar(
                    shareText: detailShareText,
                    tint: accentColor,
                    labelColor: isTheater ? accentColor : .white,
                    onEdit: { isShowingEdit = true }
                )
            }
        }
        .sheet(isPresented: $isShowingEdit) {
            EditExperienceView(visit: visit)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ThumbnailLoader.didInvalidateReferenceNotification
            )
        ) { notification in
            guard let event = visit.event,
                  ThumbnailLoader.invalidation(notification, matches: .event(event.id)) else { return }
            eventEyecatchRefreshVersion += 1
        }
        .sheet(isPresented: $isShowingRepeatEntry) {
            if let event = visit.event {
                let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
                AddVisitView(
                    event: event,
                    initialDraft: VisitDraft(repeating: visit),
                    initialCoverPhotoPath: visit.eyecatchPath.isEmpty
                        ? event.representativeEyecatchPath
                        : visit.eyecatchPath,
                    initialHeroBackgroundPath: fields.heroBackgroundPath,
                    initialHeroBackgroundPresetKey: fields.heroBackgroundPresetKey,
                    inheritedVisualSource: visit
                )
            }
        }
        .sheet(item: $ticketPlanForEditor) { plan in
            EditTicketAttemptView(plan: plan)
        }
        .sheet(item: $personMasterEditTarget) { target in
            NavigationStack {
                PersonMasterEditDestination(personID: target.id, showsCancelButton: true)
            }
        }
        .sheet(
            isPresented: $isShowingPhotoSourceChoice,
            onDismiss: performQueuedPhotoSourceAction
        ) {
            DetailPhotoSourceSheet(
                onLibrary: {
                    queuedPhotoSourceAction = .library
                    isShowingPhotoSourceChoice = false
                },
                onCamera: {
                    queuedPhotoSourceAction = .camera
                    isShowingPhotoSourceChoice = false
                }
            )
        }
        .photosPicker(
            isPresented: $isShowingDetailLibrary,
            selection: detailLibrarySelection,
            maxSelectionCount: 20,
            matching: .images
        )
        .fullScreenCover(item: $photoViewerRequest) { request in
            ExperiencePhotoViewer(
                photos: resolvedViewerPhotos(for: request),
                initialPhotoID: request.initialPhotoID
            )
        }
        .fullScreenCover(isPresented: $isShowingDetailCamera) {
            CameraImagePicker(
                onCapture: { image in
                    if let purpose = pendingPhotoPurpose {
                        addCapturedDetailPhoto(image, purpose: purpose)
                    }
                    isShowingDetailCamera = false
                    pendingPhotoPurpose = nil
                },
                onCancel: {
                    isShowingDetailCamera = false
                    pendingPhotoPurpose = nil
                }
            )
            .ignoresSafeArea()
        }
        .navigationDestination(item: $navigatingPlan) { plan in
            PlanDetailView(plan: plan)
        }
        .navigationDestination(item: $navigatingEventID) { eventID in
            EventDetailDestination(eventID: eventID)
        }
        .navigationDestination(item: $navigatingSiblingVisit) { siblingVisit in
            ExperienceDetailView(visit: siblingVisit)
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
        .alert("カメラを使用できません", isPresented: $isShowingDetailCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラを起動できません。写真ライブラリから追加してください。")
        }
        .confirmationDialog("地図で開く", isPresented: $isShowingMapChooser, titleVisibility: .visible) {
            if let url = snapshot.mapURL {
                Button("Apple Maps") { openURL(url) }
            }
            if let url = googleMapsURL {
                Button("Google Maps") { openURL(url) }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onChange(of: memoryPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await addDetailPhotos(items, purpose: .memory)
                memoryPhotoItems = []
                pendingPhotoPurpose = nil
            }
        }
        .onChange(of: goodsPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await addDetailPhotos(items, purpose: .goods)
                goodsPhotoItems = []
                pendingPhotoPurpose = nil
            }
        }
        .onChange(of: benefitPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await addDetailPhotos(items, purpose: .benefit)
                benefitPhotoItems = []
                pendingPhotoPurpose = nil
            }
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

    private func presentPhotoViewer(_ photos: [PhotoBlob], initialPhoto: PhotoBlob) {
        photoViewerRequest = ExperiencePhotoViewerRequest(
            photoIDs: photos.map(\.id),
            initialPhotoID: initialPhoto.id
        )
    }

    private func resolvedViewerPhotos(for request: ExperiencePhotoViewerRequest) -> [PhotoBlob] {
        let photosByID = Dictionary(uniqueKeysWithValues: (visit.photos ?? []).map { ($0.id, $0) })
        return request.photoIDs.compactMap { photosByID[$0] }
    }

    private func recordHero(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color,
        genreColor: Color,
        eyecatchPhoto: PhotoBlob?,
        backgroundPhoto: PhotoBlob?
    ) -> some View {
        let heroSeatText = resolvedHeroSeatText
        let metadataFontSize: CGFloat = snapshot.category?.templateKey == "theater" ? 14 : 15
        return ZStack(alignment: .bottomLeading) {
            recordHeroBackground(
                photo: backgroundPhoto,
                genreColor: genreColor,
                categoryKey: snapshot.category?.templateKey,
                presetKey: snapshot.unitFields.heroBackgroundPresetKey
            )

            VStack(alignment: .leading, spacing: 12) {
                if snapshot.category?.templateKey == "theater" {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        HStack(spacing: 8) {
                            if let seriesName = snapshot.event?.seriesName, !seriesName.isEmpty {
                                Text(seriesName)
                                    .lineLimit(1)
                                Text("•")
                            }
                            Text(ExperienceDetailPresentation.theaterVisitOrdinal(for: visit))
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

                        Spacer(minLength: 8)
                        heroWeather(snapshot: snapshot)
                    }
                } else if snapshot.category?.templateKey == "museum" {
                    Text(ExperienceDetailPresentation.museumVisitOrdinal(for: visit))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                } else if let seriesName = snapshot.event?.seriesName, !seriesName.isEmpty {
                    Text(seriesName)
                        .lineLimit(1)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                }

                let exposesEventMaster = !["museum", "movie"].contains(snapshot.category?.templateKey ?? "")
                if let event = snapshot.event, exposesEventMaster {
                    if let onOpenEvent {
                        Button {
                            onOpenEvent(event.id)
                        } label: {
                            recordHeroEventLinkLabel(title: snapshot.eventTitle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            navigatingEventID = event.id
                        } label: {
                            recordHeroEventLinkLabel(title: snapshot.eventTitle)
                        }
                        .buttonStyle(.plain)
                    }
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

                let visitSubtitle = snapshot.unitFields.visitSubtitle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if ["theme_park", "nature_living"].contains(snapshot.category?.templateKey ?? ""),
                   !visitSubtitle.isEmpty {
                    Text(visitSubtitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.86))
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
                    .frame(width: snapshot.category?.templateKey == "theater" ? 140 : 112)

                    VStack(alignment: .leading, spacing: 6) {
                        if snapshot.category?.templateKey == "book" {
                            recordMetadataRow(
                                icon: "calendar",
                                text: bookReadingPeriodText(snapshot: snapshot),
                                accentColor: .white.opacity(0.86),
                                fontSize: metadataFontSize
                            )
                        } else {
                            heroDateRow(snapshot: snapshot)

                            recordMetadataRow(
                                icon: "clock",
                                text: ExperienceDetailPresentation.performanceTime(for: visit),
                                accentColor: .white.opacity(0.86),
                                fontSize: metadataFontSize
                            )

                            recordMetadataRow(
                                icon: "tag.fill",
                                text: heroDisplayText(snapshot.unitFields.styleNames.joined(separator: "・")),
                                accentColor: .white.opacity(0.86),
                                fontSize: metadataFontSize
                            )

                            recordMetadataRow(
                                icon: "mappin.and.ellipse",
                                text: heroDisplayText(visit.venueNameSnapshot),
                                accentColor: .white.opacity(0.86),
                                fontSize: metadataFontSize
                            )

                            if ["theater", "live"].contains(snapshot.category?.templateKey ?? "") {
                                recordMetadataRow(
                                    icon: "chair",
                                    text: heroDisplayText(heroSeatText),
                                    accentColor: .white.opacity(0.86),
                                    fontSize: metadataFontSize
                                )
                            }
                        }

                        recordRating(accentColor: .white.opacity(0.90))
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        // 全ジャンルを観劇詳細と同じHero基準へ統一する。
        // 非観劇だけ560ptにすると、背景は揃っても情報全体が下へ残って見える。
        .frame(minHeight: 485, alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func recordHeroEventLinkLabel(title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
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

    private func recordHeroBackground(
        photo: PhotoBlob?,
        genreColor: Color,
        categoryKey: String?,
        presetKey: String
    ) -> some View {
        GeometryReader { proxy in
            // 観劇と同じく、背景写真を Hero の下端まで使う。
            // 途中で単色へ切り替えると、観劇以外だけ Hero が低く見えるため、
            // 下端のグラデーションでジャンル色へ自然につなぐ。
            let imageBandHeight = proxy.size.height
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

    private func detailPageBackground(genreColor: Color, usesHighContrast: Bool) -> some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: usesHighContrast
                    ? [genreColor.opacity(0.64), genreColor.opacity(0.46), Color.black.opacity(0.96)]
                    : [genreColor, genreColor.opacity(0.72), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            if usesHighContrast {
                Color.black.opacity(0.24)
            }
        }
        .ignoresSafeArea()
    }

    private func detailNavigationControls(accentColor: Color, genreColor: Color) -> some View {
        HStack {
            Button {
                closeDetail()
            } label: {
                if onBack != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("閉じる")
                    }
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .background(.black.opacity(0.48), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.24), lineWidth: 0.8)
                    }
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.black.opacity(0.48), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.20), lineWidth: 0.7)
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(onBack != nil ? "閉じる" : "戻る")

            Spacer()

            FavorecoDetailActionMenuButton(
                isPresented: $isShowingActionMenu,
                genreColor: genreColor,
                accentColor: accentColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, onBack != nil ? 54 : 0)
        .safeAreaPadding(.top, onBack != nil ? 0 : 8)
    }

    private var recordMenuActions: [FavorecoDetailAction] {
        var actions = [
            FavorecoDetailAction(
                title: "記録を編集",
                systemImage: "pencil",
                action: { isShowingEdit = true }
            )
        ]
        if visit.event?.category?.templateKey == "museum" {
            actions.append(
                FavorecoDetailAction(
                    title: "この展示をもう一度記録",
                    systemImage: "arrow.clockwise.circle",
                    action: { isShowingRepeatEntry = true }
                )
            )
        }
        actions.append(
            FavorecoDetailAction(
                title: "この記録だけ削除",
                systemImage: "trash",
                isDestructive: true,
                action: { isShowingDeleteConfirmation = true }
            )
        )
        return actions
    }

    private var edgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .onEnded { value in
                guard onBack == nil else { return }
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

    private var detailShareText: String {
        var lines: [String] = []
        let title = visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        lines.append(title.isEmpty ? "記録" : title)
        lines.append(FavorecoDateText.fullDate(visit.visitedAt))

        let performanceTime = ExperienceDetailPresentation.performanceTime(for: visit)
        if !performanceTime.isEmpty {
            lines.append(performanceTime)
        }

        let venue = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !venue.isEmpty {
            lines.append(venue)
        }

        let officialURL = visit.event?.officialURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !officialURL.isEmpty {
            lines.append(officialURL)
        }

        return lines.joined(separator: "\n")
    }

    private func heroDateRow(snapshot: ExperienceDetailSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            FavorecoIcon(systemName: "calendar", size: 17)
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 20)
            Text(FavorecoDateText.fullDate(visit.visitedAt))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(FavorecoTypography.jpSans(
            snapshot.category?.templateKey == "theater" ? 14 : 15,
            weight: .regular,
            relativeTo: .body
        ))
        .foregroundStyle(.white.opacity(0.96))
    }

    private func heroWeather(snapshot: ExperienceDetailSnapshot) -> some View {
        HStack(spacing: 4) {
            FavorecoIcon(
                systemName: snapshot.unitFields.weatherSymbolName.isEmpty
                    ? "cloud.sun"
                    : snapshot.unitFields.weatherSymbolName,
                size: 18
            )
            Text(
                heroDisplayText(
                    ExperienceDetailPresentation.compactWeatherText(fields: snapshot.unitFields)
                )
            )
        }
        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
        .foregroundStyle(.white.opacity(0.92))
        .fixedSize()
    }

    private func recordMetadataRow(
        icon: String,
        text: String,
        accentColor: Color,
        fontSize: CGFloat = 15
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(accentColor)
                .frame(width: 20)
            Text(text)
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(FavorecoTypography.jpSans(fontSize, weight: .regular, relativeTo: .body))
    }

    private func recordRating(accentColor: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: ExperienceDetailPresentation.ratingSymbol(rating: visit.overallRating, index: index))
                    .foregroundStyle(visit.overallRating > 0 ? accentColor : Color.secondary.opacity(0.34))
            }
            Text(visit.overallRating > 0 ? String(format: "%.1f", visit.overallRating) : "—")
                .foregroundStyle(.white.opacity(0.96))
                .padding(.leading, 4)
        }
        .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(visit.overallRating > 0 ? "評価 \(String(format: "%.1f", visit.overallRating))" : "未評価")
    }

    private func heroDisplayText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func detailEyecatchPhoto(in snapshot: ExperienceDetailSnapshot) -> PhotoBlob? {
        let visitEyecatchPath = visit.eyecatchPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !visitEyecatchPath.isEmpty,
           let visitEyecatch = snapshot.photos.first(where: { $0.relativePath == visitEyecatchPath }) {
            return visitEyecatch
        }
        // The shared event eyecatch is rendered through ThumbnailImage below.
        // Returning a representative photo here would make the detail choose a
        // different source from the Library tile.
        if snapshot.event?.eyecatchData != nil {
            return nil
        }
        if let event = snapshot.event,
           let representative = EventRepresentativePhotoResolver.photo(for: event),
           ExperiencePhotoPurpose.resolved(from: representative.purpose).isGalleryPhoto {
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
            ExperiencePhotoPurpose.resolved(from: photo.purpose).isGalleryPhoto
        }
    }

    private func bookInformationSection(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color
    ) -> some View {
        let event = snapshot.event
        let format = EyecatchAspectRatio.option(
            for: snapshot.unitFields.eyecatchAspectRatioKey,
            category: snapshot.category
        )
        return VStack(alignment: .leading, spacing: 14) {
            bookSectionHeader(
                title: "本の情報",
                icon: "book.closed",
                isExpanded: $isBookInformationExpanded,
                accentColor: accentColor
            )
            if isBookInformationExpanded {
                DetailInfoRow(icon: "text.book.closed", title: "書名", value: snapshot.eventTitle)
                if let seriesName = event?.seriesName, !seriesName.isEmpty {
                    DetailInfoRow(icon: "books.vertical", title: "補足", value: seriesName)
                }
                if let isbn = event?.bookISBN, !isbn.isEmpty {
                    DetailInfoRow(icon: "barcode", title: "ISBN", value: isbn)
                }
                DetailInfoRow(icon: "rectangle.portrait", title: "種類", value: format.name)
                if let officialURL = event?.officialURL,
                   !officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        guard let url = URL(string: officialURL) else { return }
                        openURL(url)
                    } label: {
                        DetailInfoRow(icon: "link", title: "URL", value: officialURL)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sectionCard(tint: accentColor, emphasized: false)
    }

    private func bookReadingSection(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            bookSectionHeader(
                title: "読書の記録",
                icon: "calendar",
                isExpanded: $isBookReadingExpanded,
                accentColor: accentColor
            )
            if isBookReadingExpanded {
                DetailInfoRow(
                    icon: "calendar.badge.clock",
                    title: "期間",
                    value: bookReadingPeriodText(snapshot: snapshot)
                )
                DetailInfoRow(
                    icon: "star",
                    title: "評価",
                    value: snapshot.ratingText
                )
            }
        }
        .sectionCard(tint: accentColor, emphasized: false)
    }

    private func bookPhotosSection(
        snapshot: ExperienceDetailSnapshot,
        excluding excludedPhotoIDs: Set<UUID>,
        accentColor: Color
    ) -> some View {
        let photos = memoryPhotos(in: snapshot).filter { !excludedPhotoIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 14) {
            bookSectionHeader(
                title: "写真",
                icon: "photo.on.rectangle",
                count: photos.count,
                isExpanded: $isBookPhotosExpanded,
                accentColor: accentColor
            )
            if isBookPhotosExpanded {
                if photos.isEmpty {
                    Text("写真はまだありません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(photos) { photo in
                            Button {
                                presentPhotoViewer(photos, initialPhoto: photo)
                            } label: {
                                let purpose = ExperiencePhotoPurpose.resolved(from: photo.purpose)
                                ZStack(alignment: .bottomLeading) {
                                    RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipped()
                                        .background(Color(.secondarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    photoPurposeCapsule(purpose)
                                        .padding(5)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(ExperiencePhotoPurpose.resolved(from: photo.purpose).title)の写真")
                        }
                    }
                }
            }
        }
        .sectionCard(tint: accentColor, emphasized: false)
    }

    private func bookMemoSection(accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            bookSectionHeader(
                title: "読書メモ",
                icon: "note.text",
                isExpanded: $isBookMemoExpanded,
                accentColor: accentColor
            )
            if isBookMemoExpanded {
                Text(visit.note.isEmpty ? "メモはまだありません" : visit.note)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(visit.note.isEmpty ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sectionCard(tint: accentColor, emphasized: false)
    }

    private func bookSectionHeader(
        title: String,
        icon: String,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        accentColor: Color
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                FavorecoIcon(systemName: icon, size: 17)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(.primary)
                if let count {
                    Text("\(count)枚")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bookReadingPeriodText(snapshot: ExperienceDetailSnapshot) -> String {
        let start = Self.bookDateFormatter.string(from: visit.visitedAt)
        let hasEndDate = snapshot.unitFields.bookReadingHasEndDate ?? true
        guard hasEndDate else { return "\(start)〜" }
        let end = Self.bookDateFormatter.string(from: max(visit.endedAt, visit.visitedAt))
        return start == end ? start : "\(start)〜\(end)"
    }

    private static let bookDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()

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
            if isTheater {
                TheaterDetailDisclosureHeader(
                    .eventInformation,
                    tint: accentColor,
                    isExpanded: $isOfficialInfoExpanded
                )
            } else if isGenericExperienceDetail {
                genericDisclosureHeader(
                    "公式情報",
                    accentColor: accentColor,
                    isExpanded: $isPlaceOfficialInfoExpanded
                )
            } else {
                sectionTitle("公式情報")
            }

            if (isTheater && isOfficialInfoExpanded)
                || (isGenericExperienceDetail && isPlaceOfficialInfoExpanded)
                || (!isTheater && !isGenericExperienceDetail) {
                if isTheater, !organizations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(organizations, id: \.label) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.label)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
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
                    FavorecoIconLabel("チケットサイト", systemImage: "ticket", iconSize: 13)
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
                    FavorecoIconLabel("SNS", systemImage: "at", iconSize: 13)
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
        .modifier(ExperienceOrTheaterSectionCard(
            isTheater: isTheater,
            tint: accentColor,
            emphasizesGenericCard: isGenericExperienceDetail
        ))
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
            FavorecoIconLabel(title, systemImage: icon, iconSize: 13)
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
        let storedAddress = visit.placeMaster?.address
            ?? snapshot.unitFields.venueAddressSnapshot
        let address = storedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        let hasMapSource = !venueName.isEmpty || !address.isEmpty || latitude != 0 || longitude != 0
        let geocodeText = address.isEmpty ? venueName : address

        return VStack(alignment: .leading, spacing: 12) {
            if isTheater {
                TheaterDetailDisclosureHeader(
                    .venue,
                    tint: accentColor,
                    isExpanded: $isVenueExpanded
                )
            } else if isGenericExperienceDetail {
                genericDisclosureHeader(
                    "会場・地図",
                    accentColor: accentColor,
                    isExpanded: $isPlaceVenueExpanded
                )
            } else {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle("会場")
                    Spacer()
                    mapOpenButton(snapshot: snapshot, hasMapSource: hasMapSource, accentColor: accentColor)
                }
            }

            if hasMapSource {
                if !venueName.isEmpty || !address.isEmpty {
                    TheaterVenueSummary(venueName: venueName, address: address)
                }

                PlaceOfficialWebsiteLink(urlString: visit.placeMaster?.officialURL ?? "")

                if (!isTheater && !isGenericExperienceDetail)
                    || (isTheater && isVenueExpanded)
                    || (isGenericExperienceDetail && isPlaceVenueExpanded) {
                    if isTheater {
                        HStack {
                            Spacer()
                            mapOpenButton(snapshot: snapshot, hasMapSource: hasMapSource, accentColor: accentColor)
                        }
                    }

                    ZStack(alignment: .topTrailing) {
                        Color.white.opacity(0.06)
                        FavorecoIcon(systemName: "map", size: 30)
                            .foregroundStyle(accentColor.opacity(0.52))
                        PlaceMapPreview(
                            venueName: venueName,
                            address: geocodeText,
                            latitude: latitude,
                            longitude: longitude
                        )

                        if isGenericExperienceDetail {
                            mapOpenButton(
                                snapshot: snapshot,
                                hasMapSource: hasMapSource,
                                accentColor: accentColor,
                                usesMapOverlayStyle: true
                            )
                            .padding(10)
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else if !isGenericExperienceDetail || isPlaceVenueExpanded {
                if !isTheater || isVenueExpanded || isGenericExperienceDetail {
                    FavorecoContentUnavailableView(
                        "会場未登録",
                        systemImage: "map",
                        description: "会場や住所を登録すると地図が表示されます"
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                }
            }
        }
        .modifier(ExperienceOrTheaterSectionCard(
            isTheater: isTheater,
            tint: accentColor,
            emphasizesGenericCard: isGenericExperienceDetail
        ))
    }

    private func museumVisitHistorySection(accentColor: Color) -> some View {
        let visits = (visit.event?.visits ?? []).sorted {
            if $0.visitedAt != $1.visitedAt { return $0.visitedAt > $1.visitedAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString > $1.id.uuidString
        }

        return VStack(alignment: .leading, spacing: 12) {
            genericDisclosureHeader(
                "この展示の鑑賞履歴",
                countText: "\(visits.count)回",
                accentColor: accentColor,
                isExpanded: $isMuseumHistoryExpanded
            )

            if isMuseumHistoryExpanded {
                ForEach(Array(visits.enumerated()), id: \.element.id) { index, historyVisit in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.12))
                    }

                    Button {
                        openMuseumHistoryVisit(historyVisit)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: historyVisit.id == visit.id ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(historyVisit.id == visit.id ? accentColor : .white.opacity(0.48))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(ExperienceDetailPresentation.museumVisitOrdinal(for: historyVisit))
                                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                                    .foregroundStyle(.white)
                                HStack(spacing: 8) {
                                    Text(FavorecoDateText.compactDate(historyVisit.visitedAt))
                                    if !historyVisit.venueNameSnapshot.isEmpty {
                                        Text(historyVisit.venueNameSnapshot)
                                            .lineLimit(1)
                                    }
                                }
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.white.opacity(0.68))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if historyVisit.id != visit.id {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accentColor)
                            } else {
                                Text("表示中")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(historyVisit.id == visit.id)
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                Button {
                    isShowingRepeatEntry = true
                } label: {
                    FavorecoIconLabel(
                        "この展示をもう一度記録",
                        systemImage: "arrow.clockwise.circle",
                        iconSize: 16
                    )
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(ExperienceOrTheaterSectionCard(
            isTheater: false,
            tint: accentColor,
            emphasizesGenericCard: true
        ))
    }

    private func openMuseumHistoryVisit(_ historyVisit: Visit) {
        guard historyVisit.id != visit.id else { return }
        if let onOpenVisit {
            onOpenVisit(historyVisit.id)
        } else {
            navigatingSiblingVisit = historyVisit
        }
    }

    @ViewBuilder
    private func mapOpenButton(
        snapshot: ExperienceDetailSnapshot,
        hasMapSource: Bool,
        accentColor: Color,
        usesMapOverlayStyle: Bool = false
    ) -> some View {
        if snapshot.mapURL != nil, hasMapSource {
            Button {
                isShowingMapChooser = true
            } label: {
                Label("マップで開く", systemImage: "arrow.up.right")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(usesMapOverlayStyle ? Color.white : accentColor)
                    .padding(.horizontal, usesMapOverlayStyle ? 10 : 0)
                    .frame(minHeight: usesMapOverlayStyle ? 32 : nil)
                    .background {
                        if usesMapOverlayStyle {
                            Capsule().fill(Color.black.opacity(0.68))
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var googleMapsURL: URL? {
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        return PlaceSearchService.googleMapsURL(
            name: visit.venueNameSnapshot,
            address: visit.placeMaster?.address
                ?? VisitUnitFields(rawValue: visit.unitFieldsRaw).venueAddressSnapshot,
            latitude: hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0),
            longitude: hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        )
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
        let genericExpansion = genericPhotoExpansionBinding(for: purpose)
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        purpose.title,
                        countText: "\(photos.count)件",
                        accentColor: accentColor,
                        isExpanded: genericExpansion
                    )
                } else {
                    HStack {
                        sectionTitle("\(purpose.title)（\(photos.count)件）")
                        Spacer()
                        if isTheater {
                            detailPhotoPicker(purpose: purpose, accentColor: accentColor)
                        }
                    }
                }

                if !isGenericExperienceDetail || genericExpansion.wrappedValue {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        if index > 0 { Divider() }
                        HStack(alignment: .top, spacing: 12) {
                            RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                                .frame(width: 92, height: 92)
                                .clipped()
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 7) {
                                FavorecoIconLabel(
                                    "\(purpose.title) \(index + 1)",
                                    systemImage: purpose.systemImage,
                                    iconSize: 13
                                )
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(accentColor)

                                if photo.amount != Decimal(0) {
                                    Text(formattedPhotoAmount(photo.amount))
                                        .font(FavorecoTypography.bodyStrong)
                                        .foregroundStyle(.primary)
                                }

                                let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !caption.isEmpty {
                                    Text(caption)
                                        .font(FavorecoTypography.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(4)
                                }

                                let text = photo.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    Text(text)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                } else if photo.amount == Decimal(0) && caption.isEmpty {
                                    Text("画像として保存")
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater || isGenericExperienceDetail)
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
        case .memory, .placeScenery, .experienceHighlight, .food:
            Button {
                pendingPhotoPurpose = purpose
                isShowingPhotoSourceChoice = true
            } label: {
                detailPhotoPickerLabel(title, font: labelFont, accentColor: accentColor)
            }
        case .goods:
            Button {
                pendingPhotoPurpose = .goods
                isShowingPhotoSourceChoice = true
            } label: {
                detailPhotoPickerLabel(title, font: labelFont, accentColor: accentColor)
            }
        case .benefit:
            Button {
                pendingPhotoPurpose = .benefit
                isShowingPhotoSourceChoice = true
            } label: {
                detailPhotoPickerLabel(title, font: labelFont, accentColor: accentColor)
            }
        case .ticket:
            Button { isShowingEdit = true } label: {
                FavorecoIconLabel(title, systemImage: "plus", iconSize: 13)
                    .font(labelFont)
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var detailLibrarySelection: Binding<[PhotosPickerItem]> {
        switch pendingPhotoPurpose {
        case .goods: $goodsPhotoItems
        case .benefit: $benefitPhotoItems
        case .memory, .placeScenery, .experienceHighlight, .food, .ticket, .none: $memoryPhotoItems
        }
    }

    private func performQueuedPhotoSourceAction() {
        defer { queuedPhotoSourceAction = nil }
        switch queuedPhotoSourceAction {
        case .library:
            isShowingDetailLibrary = true
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                isShowingDetailCameraUnavailable = true
                pendingPhotoPurpose = nil
                return
            }
            isShowingDetailCamera = true
        case .none:
            pendingPhotoPurpose = nil
        }
    }

    private func addCapturedDetailPhoto(_ image: UIImage, purpose: ExperiencePhotoPurpose) {
        guard let sourceData = image.jpegData(compressionQuality: 0.9),
              var pending = PendingPhoto.make(
                from: sourceData,
                filename: "detail-camera.jpg",
                compressionQuality: 0.82
              ) else {
            photoAddErrorMessage = "撮影した画像を読み込めませんでした。もう一度お試しください。"
            return
        }
        pending.metadata.purpose = purpose
        modelContext.insert(pending.makePhotoBlob(visit: visit))
        visit.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            photoAddErrorMessage = "写真を保存できませんでした。もう一度お試しください。"
        }
    }

    private func detailPhotoPickerLabel(
        _ title: String,
        font: Font,
        accentColor: Color
    ) -> some View {
        FavorecoIconLabel(title, systemImage: "plus", iconSize: 13)
            .font(font)
            .foregroundStyle(accentColor)
            .padding(.horizontal, 6)
            .frame(minWidth: 66, minHeight: 44)
            .contentShape(Rectangle())
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
            ?? recordPreparationPlan
    }

    @ViewBuilder
    private func theaterTravelRecordSection(
        snapshot: ExperienceDetailSnapshot,
        plan: Plan?,
        accentColor: Color
    ) -> some View {
        let tasks = plan?.preparationFields.orderedTasks ?? []

        VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .travelRecord,
                countText: tasks.isEmpty ? "0件" : "\(tasks.count)件",
                tint: accentColor,
                isExpanded: $isTravelRecordExpanded
            )

            if isTravelRecordExpanded {
                if let plan {
                    PlanPreparationChecklistView(
                        plan: plan,
                        tint: accentColor,
                        title: "遠征・準備の記録",
                        presentation: .record,
                        showsHeader: false,
                        appliesCardBackground: false
                    )
                } else {
                    Text("宿泊・新幹線・飛行機など、実際に使った内容と金額をこの観劇回へ残せます。")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)

                    Button {
                        recordPreparationPlan = ensureTicketPlan(snapshot: snapshot)
                    } label: {
                        FavorecoIconLabel("遠征・準備の記録を追加", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                }
            }
        }
        .theaterDetailSectionCard(tint: accentColor)
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
                        FavorecoIconLabel("チケットを追加", systemImage: "ticket", iconSize: 17)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)

                    Button {
                        guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                        navigatingPlan = plan
                    } label: {
                        FavorecoIconLabel("遠征ToDo", systemImage: "suitcase.rolling", iconSize: 17)
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
        let outstanding = outstandingActionCount(in: plan)

        return VStack(alignment: .leading, spacing: 12) {
            TheaterDetailDisclosureHeader(
                .nextActions,
                countText: outstanding > 0 ? "未完了 \(outstanding)" : nil,
                tint: accentColor,
                isExpanded: $isNextActionsExpanded
            )

            if isNextActionsExpanded {
                Button {
                    guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                    navigatingPlan = plan
                } label: {
                    FavorecoIconLabel("遠征ToDo", systemImage: "suitcase.rolling", iconSize: 16)
                        .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.bordered)
                .tint(accentColor)

                Text("チケット取得のスケジュール設定と、旅程のコスト管理ができます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .theaterDetailSectionCard(tint: accentColor)
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
        let isTheater = snapshot.category?.templateKey == "theater"
        let seatSummary = visit.seatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attempts.first?.seatText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            : visit.seatText.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasVisitDetails || !attempts.isEmpty || isTheater {
            VStack(alignment: .leading, spacing: 12) {
                if isTheater {
                    TheaterDetailDisclosureHeader(
                        .ticket,
                        countText: attempts.isEmpty ? "0件" : "\(attempts.count)件",
                        tint: accentColor,
                        isExpanded: $isTicketExpanded
                    )
                } else {
                    genericDisclosureHeader(
                        "チケット・座席",
                        countText: attempts.isEmpty ? nil : "\(attempts.count)件",
                        accentColor: accentColor,
                        isExpanded: $isGenericTicketExpanded
                    )
                }

                if isTheater, !isTicketExpanded {
                    if !seatSummary.isEmpty {
                        DetailInfoRow(icon: "chair", title: "座席", value: seatSummary)
                    }
                } else if isTheater || isGenericTicketExpanded {
                    if isTheater {
                        Button {
                            guard let plan = ensureTicketPlan(snapshot: snapshot) else { return }
                            ticketPlanForEditor = plan
                        } label: {
                            FavorecoIconLabel(
                                attempts.isEmpty ? "チケット申込" : "別の申込を追加",
                                systemImage: "ticket",
                                iconSize: 15
                            )
                                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .subheadline))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                    }

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

                    if isTheater {
                        HStack(spacing: 8) {
                            compactImportButton("画像・OCR", icon: "doc.viewfinder")
                            compactImportButton("URL", icon: "link.badge.plus")
                            compactImportButton("手入力", icon: "plus")
                        }
                    }
                }
            }
            .modifier(ExperienceOrTheaterSectionCard(
                isTheater: isTheater,
                tint: accentColor,
                emphasizesGenericCard: !isTheater
            ))
        }
    }

    private func compactImportButton(_ title: String, icon: String) -> some View {
        Button {
            isShowingEdit = true
        } label: {
            Label {
                Text(title)
            } icon: {
                FavorecoIcon(systemName: icon, size: 14)
            }
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
            recordPreparationPlan = plan
            return plan
        } catch {
            modelContext.rollback()
            planCreationErrorMessage = "チケット・遠征管理を開始できませんでした。もう一度お試しください。"
            return nil
        }
    }

    private func theaterCastAndFocusSection(
        snapshot: ExperienceDetailSnapshot,
        accentColor: Color
    ) -> some View {
        let focusLinks = snapshot.linkedPeople.filter { $0.roleKey == PersonRoleOption.theaterFocus.key }
        let creditLines = theaterCreditLines(from: snapshot.eventCreditsText)

        return VStack(alignment: .leading, spacing: 14) {
            TheaterDetailDisclosureHeader(
                .cast,
                tint: accentColor,
                isExpanded: $isCastExpanded
            )

            if !isCastExpanded {
                theaterFocusSummary(focusLinks: focusLinks, accentColor: accentColor)
            } else {
                Text("公演全体のキャスト・スタッフ")
                    .font(FavorecoTypography.bodyStrong)

                if creditLines.isEmpty {
                    Text("キャスト・スタッフはまだ登録されていません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(creditLines) { line in
                            if let role = line.role, let name = line.name {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(role)
                                        .font(FavorecoTypography.captionStrong)
                                        .foregroundStyle(accentColor)
                                        .frame(width: 84, alignment: .leading)
                                    Text(name)
                                        .font(FavorecoTypography.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Text(line.rawValue)
                                    .font(FavorecoTypography.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .textSelection(.enabled)
                }

                Divider().overlay(accentColor.opacity(0.24))

                Text("お目当て・注目した人")
                    .font(FavorecoTypography.bodyStrong)

                if focusLinks.isEmpty {
                    Text("この回で注目した人はまだ登録されていません")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 74, maximum: 86), spacing: 12, alignment: .top)],
                        alignment: .leading,
                        spacing: 14
                    ) {
                        ForEach(focusLinks) { link in
                            theaterFocusPersonButton(link: link, accentColor: accentColor, showsRole: true)
                        }
                    }
                }
            }
        }
        .theaterDetailSectionCard(tint: accentColor)
    }

    @ViewBuilder
    private func theaterFocusSummary(
        focusLinks: [EventPersonLink],
        accentColor: Color
    ) -> some View {
        if !focusLinks.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(focusLinks.prefix(3))) { link in
                    theaterFocusPersonButton(link: link, accentColor: accentColor, showsRole: false)
                }
                if focusLinks.count > 3 {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(accentColor.opacity(0.16))
                            Text("+\(focusLinks.count - 3)")
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(accentColor)
                        }
                        .frame(width: 52, height: 52)
                        Text("ほか\(focusLinks.count - 3)人")
                            .font(FavorecoTypography.jpSans(10, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 64)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func theaterFocusPersonButton(
        link: EventPersonLink,
        accentColor: Color,
        showsRole: Bool
    ) -> some View {
        let reactionTitles = TheaterFocusLinkMetadata(memo: link.memo)
            .reactionKeys
            .map { TheaterFocusReaction.title(for: $0) }
        let item = TheaterCastItem(
            name: ExperienceDetailPresentation.personName(for: link),
            role: showsRole ? (reactionTitles.isEmpty ? "注目" : reactionTitles.joined(separator: "・")) : "",
            imageData: link.person?.imageData,
            imagePath: link.person?.imagePath ?? "",
            roleTagsRaw: link.person?.roleTagsRaw ?? "",
            tint: accentColor,
            compact: !showsRole
        )
        if let personID = link.person?.id {
            Button {
                personMasterEditTarget = PersonMasterEditTarget(id: personID)
            } label: {
                item
            }
            .buttonStyle(.plain)
            .accessibilityHint("人物マスターを編集")
        } else {
            item
        }
    }

    private func theaterCreditLines(from text: String) -> [TheaterCreditDisplayLine] {
        text.split(whereSeparator: \Character.isNewline).enumerated().compactMap { index, line in
            let rawValue = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { return nil }
            let separators: [Character] = ["：", ":"]
            if let separatorIndex = rawValue.firstIndex(where: { separators.contains($0) }) {
                let role = String(rawValue[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let name = String(rawValue[rawValue.index(after: separatorIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !role.isEmpty, !name.isEmpty {
                    return TheaterCreditDisplayLine(id: index, rawValue: rawValue, role: role, name: name)
                }
            }
            return TheaterCreditDisplayLine(id: index, rawValue: rawValue, role: nil, name: nil)
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
            TheaterDetailDisclosureHeader(
                .photos,
                countText: "\(memories.count + collection.count)枚",
                tint: accentColor,
                isExpanded: $isPhotoCollectionExpanded
            )

            if isPhotoCollectionExpanded {
                HStack {
                    FavorecoIconLabel("思い出", systemImage: "camera", iconSize: 17)
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
                    FavorecoIconLabel("グッズ・ノベルティ・特典", systemImage: "gift", iconSize: 17)
                        .font(FavorecoTypography.bodyStrong)
                    HStack(spacing: 12) {
                        Spacer()
                        detailPhotoPicker(purpose: .goods, accentColor: accentColor, title: "グッズ")
                        detailPhotoPicker(purpose: .benefit, accentColor: accentColor, title: "特典")
                    }
                    .zIndex(2)
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
        .theaterDetailSectionCard(tint: accentColor)
    }

    private func theaterPhotoGrid(
        _ photos: [PhotoBlob],
        accentColor: Color,
        showsPurpose: Bool
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
            spacing: 8
        ) {
            ForEach(photos) { photo in
                let purpose = ExperiencePhotoPurpose.resolved(from: photo.purpose)
                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        presentPhotoViewer(photos, initialPhoto: photo)
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            GeometryReader { proxy in
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 360, contentMode: .fill)
                                    .frame(width: proxy.size.width, height: proxy.size.width)
                                    .clipped()
                                    .background(Color(.secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .aspectRatio(1, contentMode: .fit)
                            if showsPurpose || purpose != .memory {
                                FavorecoIconLabel(purpose.title, systemImage: purpose.systemImage, iconSize: 9, spacing: 3)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.68)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.66), in: Capsule())
                                    .padding(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(purpose.title)の写真")
                    .accessibilityHint("開いて左右に送れます")
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
                if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        "写真・コレクション",
                        countText: "\(galleryPhotos.count)枚",
                        accentColor: accentColor,
                        isExpanded: $isPlacePhotosExpanded
                    )
                } else {
                    HStack {
                        sectionTitle(isTheater ? "思い出" : "写真")
                        Spacer()
                        if isTheater {
                            detailPhotoPicker(purpose: .memory, accentColor: accentColor)
                        }
                    }
                }

                if !isGenericExperienceDetail || isPlacePhotosExpanded {
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
                                let purpose = ExperiencePhotoPurpose.resolved(from: photo.purpose)
                                VStack(alignment: .leading, spacing: 5) {
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
                                                .frame(
                                                    maxWidth: .infinity,
                                                    maxHeight: .infinity,
                                                    alignment: .topTrailing
                                                )
                                        }
                                        photoPurposeCapsule(purpose)
                                            .padding(5)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    }

                                    let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !caption.isEmpty {
                                        Text(caption)
                                            .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption2))
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sectionCard(tint: accentColor, emphasized: isTheater || isGenericExperienceDetail)
        }
    }

    private func photoPurposeCapsule(_ purpose: ExperiencePhotoPurpose) -> some View {
        FavorecoIconLabel(
            purpose.title,
            systemImage: purpose.systemImage,
            iconSize: 9,
            spacing: 3
        )
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(.black.opacity(0.66), in: Capsule())
    }

    @ViewBuilder
    private func goshuinBookSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if snapshot.category?.templateKey == "goshuin", !snapshot.unitFields.goshuinBookSizeKey.isEmpty {
            let size = GoshuinBookSize.option(for: snapshot.unitFields.goshuinBookSizeKey)
            VStack(alignment: .leading, spacing: 12) {
                genericDisclosureHeader(
                    "御朱印帳",
                    accentColor: .white,
                    isExpanded: $isGoshuinBookExpanded
                )
                if isGoshuinBookExpanded {
                    DetailInfoRow(
                        icon: "book.closed",
                        title: "サイズ",
                        value: "\(size.name)（\(size.displaySize)）"
                    )
                }
            }
            .sectionCard(tint: .white, emphasized: true)
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
                let title = snapshot.category?.templateKey == "theater" ? "スタッフ・関係者" : "人物・団体"
                if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        title,
                        countText: "\(links.count)件",
                        accentColor: accentColor,
                        isExpanded: $isPlacePeopleExpanded
                    )
                } else {
                    sectionTitle(title)
                }

                if !isGenericExperienceDetail || isPlacePeopleExpanded {
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
            }
            .sectionCard(tint: accentColor, emphasized: isGenericExperienceDetail)
        }
    }

    @ViewBuilder
    private func ocrSection(snapshot: ExperienceDetailSnapshot, accentColor: Color, isTheater: Bool) -> some View {
        if !snapshot.unitFields.ocrText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                TheaterDetailDisclosureHeader(
                    .ocr,
                    countText: "1件",
                    tint: accentColor,
                    isExpanded: $isOCRExpanded
                )
                if isOCRExpanded {
                    Text(snapshot.unitFields.ocrText)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .modifier(ExperienceOrTheaterSectionCard(isTheater: isTheater, tint: accentColor))
        }
    }

    @ViewBuilder
    private func basicInfo(snapshot: ExperienceDetailSnapshot, template: CategoryRecordTemplate) -> some View {
        if !snapshot.unitFields.weatherSymbolName.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        template.visitSectionTitle,
                        accentColor: .white,
                        isExpanded: $isPlaceBasicInfoExpanded
                    )
                } else {
                    sectionTitle(template.visitSectionTitle)
                }

                if !isGenericExperienceDetail || isPlaceBasicInfoExpanded {
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
            }
            .sectionCard(tint: .white, emphasized: isGenericExperienceDetail)
        }
    }

    @ViewBuilder
    private func advancedSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if !snapshot.unitFields.advancedEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        "詳細オプション",
                        countText: "\(snapshot.unitFields.advancedEntries.filter { !$0.isEmpty }.count)件",
                        accentColor: .white,
                        isExpanded: $isPlaceAdvancedExpanded
                    )
                } else {
                    sectionTitle("詳細オプション")
                }
                if !isGenericExperienceDetail || isPlaceAdvancedExpanded {
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
            }
            .sectionCard(tint: .white, emphasized: isGenericExperienceDetail)
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
                if isTheater {
                    TheaterDetailDisclosureHeader(
                        .review,
                        tint: accentColor,
                        isExpanded: $isReviewSectionExpanded
                    )
                } else if isGenericExperienceDetail {
                    genericDisclosureHeader(
                        template.memoSectionTitle,
                        accentColor: accentColor,
                        isExpanded: $isPlaceMemoExpanded
                    )
                } else {
                    sectionTitle(template.memoSectionTitle)
                }

                if (isTheater && isReviewSectionExpanded)
                    || (isGenericExperienceDetail && isPlaceMemoExpanded)
                    || (!isTheater && !isGenericExperienceDetail) {
                    if !tagNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(tagNames, id: \.self) { tag in
                                    FavorecoIconLabel(tag, systemImage: "heart.text.square", iconSize: 13)
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
            .modifier(ExperienceOrTheaterSectionCard(
                isTheater: isTheater,
                tint: accentColor,
                emphasizesGenericCard: isGenericExperienceDetail
            ))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(detailSectionTitleFont)
    }

    private var isGenericExperienceDetail: Bool {
        let templateKey = visit.event?.category?.templateKey ?? ""
        return templateKey != "theater"
    }

    private var hasVenueMapSource: Bool {
        let venueName = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !venueName.isEmpty
            || !address.isEmpty
            || visit.latitude != 0
            || visit.longitude != 0
            || (visit.placeMaster?.latitude ?? 0) != 0
            || (visit.placeMaster?.longitude ?? 0) != 0
    }

    private func genericDisclosureHeader(
        _ title: String,
        countText: String? = nil,
        accentColor: Color,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let countText {
                    Text(countText)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.white.opacity(0.76))
                }
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded.wrappedValue ? "開いています" : "閉じています")
        .accessibilityHint(isExpanded.wrappedValue ? "ダブルタップで閉じます" : "ダブルタップで開きます")
    }

    private func genericPhotoExpansionBinding(for purpose: ExperiencePhotoPurpose) -> Binding<Bool> {
        switch purpose {
        case .ticket:
            return $isPlaceTicketPhotosExpanded
        case .goods:
            return $isPlaceGoodsPhotosExpanded
        case .benefit:
            return $isPlaceBenefitPhotosExpanded
        case .memory, .placeScenery, .experienceHighlight, .food:
            return $isPlacePhotosExpanded
        }
    }

    private var detailSectionTitleFont: Font {
        guard visit.event?.category?.templateKey == "theater" else {
            return FavorecoTypography.sectionTitle
        }
        return FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline)
    }

}

struct ExperiencePhotoViewer: View {
    let photos: [PhotoBlob]
    let initialPhotoID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoID: UUID
    @State private var saveResult: PhotoSaveResult?

    init(photos: [PhotoBlob], initialPhotoID: UUID) {
        self.photos = photos
        self.initialPhotoID = initialPhotoID
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.isEmpty {
                FavorecoContentUnavailableView("写真を表示できません", systemImage: "photo")
                    .foregroundStyle(.white)
            } else {
                TabView(selection: $selectedPhotoID) {
                    ForEach(photos) { photo in
                        RepresentativePhotoImage(photo: photo, maxPixelSize: 2_400, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 12)
                            .tag(photo.id)
                            .contextMenu {
                                Button {
                                    Task { await saveToPhotoLibrary(photo) }
                                } label: {
                                    Label("写真に保存", systemImage: "square.and.arrow.down")
                                }
                            }
                            .accessibilityLabel("写真 \(photoNumber(for: photo)) / \(photos.count)")
                            .accessibilityHint("左右にスワイプできます。長押しすると写真に保存できます")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    FavorecoIcon(systemName: "xmark", size: 18, fallbackWeight: .bold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.56), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")

                Spacer()

                if !photos.isEmpty {
                    Text("\(selectedPhotoNumber) / \(photos.count)")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(.black.opacity(0.56), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if !photos.isEmpty {
                Text("写真を長押しして保存")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.black.opacity(0.56), in: Capsule())
                    .padding(.bottom, 18)
                    .allowsHitTesting(false)
            }
        }
        .alert(item: $saveResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .preferredColorScheme(.dark)
    }

    private var selectedPhotoNumber: Int {
        guard let index = photos.firstIndex(where: { $0.id == selectedPhotoID }) else { return 1 }
        return index + 1
    }

    private func photoNumber(for photo: PhotoBlob) -> Int {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return 1 }
        return index + 1
    }

    @MainActor
    private func saveToPhotoLibrary(_ photo: PhotoBlob) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveResult = PhotoSaveResult(
                title: "写真を保存できません",
                message: "設定でFavorecoの写真追加を許可してください。"
            )
            return
        }

        let data = photo.data
        guard !data.isEmpty else {
            saveResult = PhotoSaveResult(
                title: "写真を保存できません",
                message: "画像データを読み込めませんでした。"
            )
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .photo, data: data, options: nil)
            }
            saveResult = PhotoSaveResult(
                title: "保存しました",
                message: "写真ライブラリへ追加しました。"
            )
        } catch {
            saveResult = PhotoSaveResult(
                title: "写真を保存できません",
                message: "もう一度お試しください。"
            )
        }
    }
}

private struct PhotoSaveResult: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct RecordDetailEyecatch: View {
    let event: ExperienceEvent?
    let photo: PhotoBlob?
    let aspectRatio: Double
    let fallbackSymbol: String
    let tint: Color
    let usesGoldFrame: Bool

    @ViewBuilder
    var body: some View {
        if usesGoldFrame {
            TheaterPosterArtwork(
                reference: event.map { .event($0.id) },
                backgroundColor: Color(.secondarySystemBackground)
            ) { _ in
                if let photo {
                    RepresentativePhotoImage(photo: photo, maxPixelSize: 720, contentMode: .fit)
                } else {
                    ZStack {
                        tint.opacity(0.18)
                        FavorecoIcon(systemName: fallbackSymbol, size: 34)
                            .foregroundStyle(tint)
                    }
                }
            }
            .theaterPosterFrame(tint: tint)
        } else {
            Group {
                if let photo {
                    RepresentativePhotoImage(photo: photo, maxPixelSize: 720, contentMode: .fill)
                } else if let event {
                    GeometryReader { geometry in
                        ThumbnailImage(
                            reference: .event(event.id),
                            displaySize: geometry.size,
                            contentMode: .fill
                        ) {
                            ZStack {
                                tint.opacity(0.18)
                                FavorecoIcon(systemName: fallbackSymbol, size: 34)
                                    .foregroundStyle(tint)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    ZStack {
                        tint.opacity(0.18)
                        FavorecoIcon(systemName: fallbackSymbol, size: 34)
                            .foregroundStyle(tint)
                    }
                }
            }
            .aspectRatio(CGFloat(max(aspectRatio, 0.35)), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(Color(.secondarySystemBackground))
            .modifier(
                RecordDetailEyecatchFrameModifier(tint: tint)
            )
        }
    }
}

private struct RecordDetailEyecatchFrameModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 0.8)
            }
    }
}

private struct TheaterCastItem: View {
    let name: String
    let role: String
    let imageData: Data?
    let imagePath: String
    let roleTagsRaw: String
    let tint: Color
    var compact = false

    var body: some View {
        VStack(spacing: 6) {
            avatar
                .frame(width: compact ? 52 : 64, height: compact ? 52 : 64)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(tint.opacity(0.46), lineWidth: 1)
                }

            Text(name)
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.primary)
                .lineLimit(compact ? 2 : 1)
                .multilineTextAlignment(.center)
                .frame(width: 74)

            if !role.isEmpty {
                Text(role)
                    .font(FavorecoTypography.jpSans(9, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 74)
            }
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
                FavorecoIcon(systemName: PersonActivityTags.icon(for: roleTagsRaw), size: 24)
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

private struct TheaterCreditDisplayLine: Identifiable {
    let id: Int
    let rawValue: String
    let role: String?
    let name: String?
}

private struct DetailInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
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

private struct ExperienceOrTheaterSectionCard: ViewModifier {
    let isTheater: Bool
    let tint: Color
    let emphasizesGenericCard: Bool

    init(isTheater: Bool, tint: Color, emphasizesGenericCard: Bool = false) {
        self.isTheater = isTheater
        self.tint = tint
        self.emphasizesGenericCard = emphasizesGenericCard
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isTheater {
            content.theaterDetailSectionCard(tint: tint)
        } else {
            content.sectionCard(tint: tint, emphasized: emphasizesGenericCard)
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
