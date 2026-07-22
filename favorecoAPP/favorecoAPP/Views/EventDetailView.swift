//
//  EventDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct EventDetailBackSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TheaterPublicVenue: Identifiable {
    let id = UUID()
    let name: String
    let address: String
}

private struct TheaterPublicLink: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let url: URL
}

private struct EventHeroBackgroundPicker: View {
    let categoryKey: String
    @Binding var selection: String

    private var presets: [HeroBackgroundPreset] {
        HeroBackgroundPreset.presets(for: categoryKey)
    }

    private var resolvedSelection: String {
        HeroBackgroundPreset.resolved(categoryKey: categoryKey, storedKey: selection)?.key ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ページ背景")
                .font(FavorecoTypography.bodyStrong)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
    }

    private func presetButton(_ preset: HeroBackgroundPreset) -> some View {
        let isSelected = resolvedSelection == preset.key
        return Button {
            selection = preset.key
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Image(preset.resourceName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 100)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color(red: 0.82, green: 0.62, blue: 0.30) : Color.secondary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(preset.title)
                    .font(FavorecoTypography.caption)
                    .lineLimit(2)
                    .frame(width: 82, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EventDetailView: View {
    let event: ExperienceEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.automaticallyUpdatesExternalCalendar) private var automaticallyUpdatesExternalCalendar = false
    @State private var isShowingAddVisit = false
    @State private var isShowingAddPlan = false
    @State private var isShowingEditEvent = false
    @State private var isShowingRepresentativePhotoPicker = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var actionErrorMessage: String?
    @State private var backSwipeExclusionFrames: [CGRect] = []

    private var category: RecordCategory? {
        event.category
    }

    private var accentColor: Color {
        themePalette.categoryColor(hex: category?.colorHex ?? "#6F8F7A")
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    var body: some View {
        let snapshot = EventDetailSnapshot.make(event: event)
        let scheduleSnapshot = TheaterEventScheduleSnapshot.make(event: event)
        let expenseSnapshot = TheaterEventExpenseSnapshot.make(event: event)
        let isTheater = category?.templateKey == "theater"

        ScrollView {
            VStack(alignment: .leading, spacing: isTheater ? 24 : 20) {
                if isTheater {
                    theaterHero(snapshot: snapshot)
                        .padding(.horizontal, -20)
                        .padding(.top, -24)
                    TheaterEventInformationSection(event: event, accentColor: theaterGold)
                    TheaterEventPeopleSection(
                        castLinks: snapshot.castLinks,
                        staffLinks: snapshot.staffLinks,
                        accentColor: theaterGold
                    )
                    TheaterEventTicketProgressSection(
                        references: scheduleSnapshot.ticketReferences,
                        accentColor: theaterGold
                    )
                    TheaterEventParticipationHistorySection(
                        visits: snapshot.visits,
                        accentColor: theaterGold
                    )
                    TheaterEventUpcomingPlansSection(
                        event: event,
                        plans: scheduleSnapshot.upcomingPlans,
                        representativePhoto: snapshot.representativePhoto,
                        accentColor: theaterGold,
                        onAddPlan: { isShowingAddPlan = true }
                    )
                    TheaterEventExpenseSection(
                        snapshot: expenseSnapshot,
                        accentColor: theaterGold
                    )
                    TheaterEventMemoryGallerySection(
                        items: snapshot.memoryPhotos,
                        accentColor: theaterGold
                    )
                } else if category?.templateKey == "random_goods" {
                    hero(snapshot: snapshot)
                    CollectibleSeriesDashboard(series: event, accentColor: accentColor)
                } else {
                    hero(snapshot: snapshot)
                    eventMemoSection
                    stats(snapshot: snapshot)
                    visitHistory(snapshot: snapshot)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .ignoresSafeArea(edges: isTheater ? .top : [])
        .background {
            if isTheater {
                theaterPageBackground
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .environment(\.colorScheme, isTheater ? .dark : systemColorScheme)
        .navigationTitle(snapshot.eventTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isTheater ? .hidden : .visible, for: .navigationBar)
        .simultaneousGesture(theaterEdgeBackGesture)
        .onPreferenceChange(EventDetailBackSwipeExclusionPreferenceKey.self) { frames in
            backSwipeExclusionFrames = frames
        }
        .overlay(alignment: .top) {
            if isTheater {
                theaterNavigationControls
            }
        }
        .toolbar {
            if !isTheater {
                ToolbarItem(placement: .topBarTrailing) {
                    eventMenu
                }
            }
        }
        .sheet(isPresented: $isShowingAddVisit) {
            if category?.templateKey == "random_goods" {
                CollectibleTransactionEditorView(series: event)
            } else {
                AddVisitView(event: event)
            }
        }
        .sheet(isPresented: $isShowingAddPlan) {
            AddTicketPlanView(event: event, entryMode: .plan)
        }
        .sheet(isPresented: $isShowingEditEvent) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $isShowingRepresentativePhotoPicker) {
            RepresentativePhotoPicker(event: event)
        }
        .confirmationDialog("この対象を非表示にしますか？", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                archiveThisEvent()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("履歴と写真は削除せず、通常の対象一覧から外します。データ管理の「非表示の対象」から復元できます。")
        }
        .confirmationDialog("この対象を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("この対象とすべての記録を削除", role: .destructive) {
                deleteThisEvent()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(snapshot.eventTitle)」と、ひもづく記録 \(snapshot.visitCount) 件（写真を含む）をすべて削除します。取り消せません。")
        }
        .alert("処理に失敗しました", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var eventMenu: some View {
        Menu {
            eventMenuItems
        } label: {
            Label("メニュー", systemImage: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var eventMenuItems: some View {
        Button {
            isShowingEditEvent = true
        } label: {
            Label("対象情報・画像を編集", systemImage: "pencil")
        }

        if EventRepresentativePhotoResolver.resolve(
            for: event,
            sortedVisits: (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
        ).photos.isEmpty == false {
            Button {
                isShowingRepresentativePhotoPicker = true
            } label: {
                Label("代表写真を選ぶ", systemImage: "photo.badge.checkmark")
            }
        }

        Button(role: .destructive) {
            isShowingArchiveConfirmation = true
        } label: {
            Label("対象を非表示", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("この対象とすべての記録を削除", systemImage: "trash")
        }
    }

    private var theaterNavigationControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.black.opacity(0.48), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.20), lineWidth: 0.7) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            Menu {
                eventMenuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theaterGold)
                    .frame(width: 50, height: 50)
                    .background(theaterWine.opacity(0.88), in: Circle())
                    .overlay { Circle().stroke(theaterGold.opacity(0.72), lineWidth: 1) }
            }
            .accessibilityLabel("メニュー")
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 8)
    }

    private var theaterPageBackground: some View {
        LinearGradient(
            colors: [theaterWine, Color(red: 0.18, green: 0.025, blue: 0.05), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var theaterWine: Color {
        Color(red: 0.55, green: 0.18, blue: 0.27)
    }

    private var theaterGold: Color {
        Color(red: 0.82, green: 0.62, blue: 0.30)
    }

    private func theaterHero(snapshot: EventDetailSnapshot) -> some View {
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        let venues = resolvedTheaterVenues(fields: fields)
        return ZStack(alignment: .top) {
            theaterHeroBackground(fields: fields)

            VStack(spacing: 12) {
                Spacer().frame(height: 88)
                theaterPoster(snapshot: snapshot)

                if !event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(event.seriesName)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Text(snapshot.eventTitle)
                    .font(FavorecoTypography.jpSerif(29, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !fields.eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(fields.eventSubtitle)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(resolvedTheaterPeriodText(fields: fields), systemImage: "calendar")
                    ForEach(venues) { venue in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(venue.name, systemImage: "mappin.and.ellipse")
                            if !venue.address.isEmpty {
                                Text(venue.address)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                                    .padding(.leading, 27)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    if !event.organizerNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(event.organizerNameSnapshot, systemImage: "building.2")
                    }
                }
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)

                theaterOfficialLinks(fields: fields)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        theaterPlanButton
                        theaterVisitButton
                    }
                    VStack(spacing: 10) {
                        theaterPlanButton
                        theaterVisitButton
                    }
                }
                .tint(theaterGold)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(minHeight: 720, alignment: .top)
    }

    private func theaterHeroBackground(fields: VisitUnitFields) -> some View {
        GeometryReader { proxy in
            let resourceName = HeroBackgroundPreset.resolved(
                categoryKey: "theater",
                storedKey: fields.heroBackgroundPresetKey
            )?.resourceName ?? "theater-hero-venue-v2"
            ZStack(alignment: .top) {
                theaterWine
                Image(resourceName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: 470)
                    .clipped()
                LinearGradient(
                    colors: [.black.opacity(0.48), .clear, theaterWine.opacity(0.3), theaterWine],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 520)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func theaterPoster(snapshot: EventDetailSnapshot) -> some View {
        Group {
            if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let photo = snapshot.representativePhoto {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 900, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.black.opacity(0.42))
                    .overlay {
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(theaterGold.opacity(0.8))
                    }
            }
        }
        .frame(width: 190, height: 269)
        .clipped()
        .overlay {
            Rectangle().stroke(theaterGold.opacity(0.95), lineWidth: 2).padding(3)
        }
        .overlay { Rectangle().stroke(theaterGold.opacity(0.46), lineWidth: 0.8) }
        .shadow(color: .black.opacity(0.48), radius: 18, y: 9)
    }

    private var theaterPlanButton: some View {
        Button { isShowingAddPlan = true } label: {
            Label("予定を立てる", systemImage: "calendar.badge.plus")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var theaterVisitButton: some View {
        Button { isShowingAddVisit = true } label: {
            Label("記録を追加", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var theaterEdgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .global)
            .onEnded { value in
                guard category?.templateKey == "theater" else { return }
                let startsAtLeadingEdge = value.startLocation.x <= 32
                let startsInExcludedArea = backSwipeExclusionFrames.contains {
                    $0.contains(value.startLocation)
                }
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)
                let isHorizontalSwipe = horizontalDistance >= 72
                    && horizontalDistance > verticalDistance * 1.35
                    && value.predictedEndTranslation.width >= 110

                guard startsAtLeadingEdge, !startsInExcludedArea, isHorizontalSwipe else { return }
                dismiss()
            }
    }

    @ViewBuilder
    private func theaterOfficialLinks(fields: VisitUnitFields) -> some View {
        let links = resolvedTheaterLinks(fields: fields)
        if !links.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(links) { link in
                        Button { openURL(link.url) } label: {
                            Label(link.title, systemImage: link.systemImage)
                                .font(FavorecoTypography.captionStrong)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.20), in: Capsule())
                                .overlay { Capsule().stroke(theaterGold.opacity(0.24), lineWidth: 0.6) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theaterGold)
                    }
                }
            }
        }
    }

    private func resolvedTheaterPeriodText(fields: VisitUnitFields) -> String {
        let plans = (event.plans ?? []).filter { !$0.isArchived }
        let visits = event.visits ?? []
        let fallbackDates = plans.flatMap { [$0.startsAt, $0.endsAt] }
            + visits.flatMap { [$0.visitedAt, max($0.endedAt, $0.visitedAt)] }
        let start = fields.eventPeriodStartsAt ?? fallbackDates.min()
        let end = fields.eventPeriodEndsAt ?? fallbackDates.max()
        guard let start else { return "公演期間 未登録" }
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(start)
        }
        return "\(FavorecoDateText.compactDate(start))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
    }

    private func resolvedTheaterVenues(fields: VisitUnitFields) -> [TheaterPublicVenue] {
        let explicit = fields.eventVenues.compactMap { entry -> TheaterPublicVenue? in
            guard !entry.trimmedName.isEmpty else { return nil }
            return TheaterPublicVenue(name: entry.trimmedName, address: entry.trimmedAddress)
        }
        if !explicit.isEmpty { return deduplicatedTheaterVenues(explicit) }

        let planVenues = (event.plans ?? []).filter { !$0.isArchived }.compactMap { plan -> TheaterPublicVenue? in
            let name = plan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TheaterPublicVenue(name: name, address: plan.placeMaster?.address ?? "")
        }
        let visitVenues = (event.visits ?? []).compactMap { visit -> TheaterPublicVenue? in
            let name = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TheaterPublicVenue(name: name, address: visit.placeMaster?.address ?? "")
        }
        let venues = deduplicatedTheaterVenues(planVenues + visitVenues)
        return venues.isEmpty ? [TheaterPublicVenue(name: "会場 未登録", address: "")] : venues
    }

    private func deduplicatedTheaterVenues(_ venues: [TheaterPublicVenue]) -> [TheaterPublicVenue] {
        var seen = Set<String>()
        return venues.filter { venue in
            let key = venue.name.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            return seen.insert(key).inserted
        }
    }

    private func resolvedTheaterLinks(fields: VisitUnitFields) -> [TheaterPublicLink] {
        var result: [TheaterPublicLink] = []
        if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
            result.append(TheaterPublicLink(title: "公式", systemImage: "link", url: url))
        }
        let ticketURLText = (event.plans ?? [])
            .filter { !$0.isArchived }
            .flatMap { $0.ticketAttempts ?? [] }
            .map(\.purchaseURL)
            .first { !$0.isEmpty }
            ?? (event.plans ?? []).map(\.sourceURL).first { !$0.isEmpty }
        if let ticketURLText, let url = URL(string: ticketURLText) {
            result.append(TheaterPublicLink(title: "チケット", systemImage: "ticket", url: url))
        }
        for (index, value) in fields.socialLinks.enumerated() {
            if let url = URL(string: value) {
                result.append(TheaterPublicLink(title: "SNS \(index + 1)", systemImage: "bubble.left.and.bubble.right", url: url))
            }
        }
        return result
    }

    private func archiveThisEvent() {
        event.isArchived = true
        event.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            actionErrorMessage = "この対象を非表示にできませんでした。もう一度お試しください。"
        }
    }

    private func deleteThisEvent() {
        do {
            let result = try RecordDeletionService.deleteEvent(event, in: modelContext)
            reconcileExternalCalendarAfterDeletion(result.externalCalendarTargets)
            dismiss()
        } catch {
            actionErrorMessage = "この対象を削除できませんでした。もう一度お試しください。"
            assertionFailure("Failed to delete event: \(error)")
        }
    }

    private func reconcileExternalCalendarAfterDeletion(
        _ targets: [RecordDeletionService.ExternalCalendarDeletionTarget]
    ) {
        guard !targets.isEmpty else { return }
        let removesExternalEvents = purchaseManager.currentPlan.includesSync
            && automaticallyUpdatesExternalCalendar

        guard removesExternalEvents else {
            for target in targets {
                ExternalCalendarLinkStore.clear(planID: target.planID)
            }
            return
        }

        Task {
            for target in targets {
                _ = try? await ExternalCalendarSyncService.remove(
                    identifier: target.eventIdentifier,
                    planID: target.planID
                )
            }
        }
    }

    private func hero(snapshot: EventDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let representativePhoto = snapshot.representativePhoto {
                RepresentativePhotoImage(
                    photo: representativePhoto,
                    maxPixelSize: 1200,
                    contentMode: representativeContentMode
                )
                    .aspectRatio(representativeAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: representativeContentMode)
                    .aspectRatio(representativeAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category?.iconSymbol ?? "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.eventTitle)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(category?.name ?? "未分類")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)

                    if event.stateKey == "interested" {
                        Label("気になる", systemImage: "bookmark.fill")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !event.seriesName.isEmpty {
                Label(event.seriesName, systemImage: "rectangle.stack")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    isShowingAddPlan = true
                } label: {
                    Label("予定を立てる", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingAddVisit = true
                } label: {
                    Label("記録を追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .tint(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var representativeAspectRatio: CGFloat {
        CGFloat(EyecatchAspectRatio.resolved(for: event).value)
    }

    private var representativeContentMode: ContentMode {
        EyecatchAspectRatio.usesEyecatchFill(for: category) ? .fill : .fit
    }

    private func stats(snapshot: EventDetailSnapshot) -> some View {
        HStack(spacing: 12) {
            StatSummaryTile(title: "記録", value: "\(snapshot.visitCount)")
            StatSummaryTile(title: "最新", value: snapshot.latestVisitText)
            StatSummaryTile(title: template.ratingLabel, value: snapshot.averageRatingText)
        }
    }

    @ViewBuilder
    private var eventMemoSection: some View {
        if !event.memo.isEmpty || !event.importMemo.isEmpty || !event.officialURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.targetSectionTitle)
                    .font(FavorecoTypography.sectionTitle)

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !event.importMemo.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Label("読み取りメモ", systemImage: "text.viewfinder")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        Text(event.importMemo)
                            .font(FavorecoTypography.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
                    Link(destination: url) {
                        Label("公式リンク", systemImage: "link")
                            .font(FavorecoTypography.bodyStrong)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func visitHistory(snapshot: EventDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("履歴")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(snapshot.visitCount)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if snapshot.visits.isEmpty {
                EventEmptyState(icon: "calendar.badge.plus", message: "この対象の回はまだありません。")
            } else {
                ForEach(snapshot.visits) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        VisitSummaryRow(visit: visit, showsCategory: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

enum EventRepresentativePhotoResolver {
    static func photo(for event: ExperienceEvent) -> PhotoBlob? {
        resolve(for: event, sortedVisits: sortedVisits(event)).photo
    }

    static func resolve(
        for event: ExperienceEvent,
        sortedVisits: [Visit]
    ) -> (photo: PhotoBlob?, photos: [PhotoBlob]) {
        var photos: [PhotoBlob] = []
        var automaticPhoto: PhotoBlob?
        for visit in sortedVisits {
            let visitPhotos = photoItems(in: visit)
            photos.append(contentsOf: visitPhotos)
            if automaticPhoto == nil {
                if !visit.eyecatchPath.isEmpty,
                   let cover = visitPhotos.first(where: { $0.relativePath == visit.eyecatchPath }) {
                    automaticPhoto = cover
                } else {
                    automaticPhoto = visitPhotos.first
                }
            }
        }

        let photo: PhotoBlob?
        if !event.representativeEyecatchPath.isEmpty,
           let selected = photos.first(where: { $0.relativePath == event.representativeEyecatchPath }) {
            photo = selected
        } else if event.eyecatchData != nil {
            photo = nil
        } else {
            photo = automaticPhoto
        }
        return (photo, photos)
    }

    static func allPhotos(in event: ExperienceEvent) -> [PhotoBlob] {
        resolve(for: event, sortedVisits: sortedVisits(event)).photos
    }

    private static func sortedVisits(_ event: ExperienceEvent) -> [Visit] {
        (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
    }

    private static func photoItems(in visit: Visit) -> [PhotoBlob] {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

struct RepresentativePhotoImage: View {
    let photo: PhotoBlob
    let maxPixelSize: CGFloat
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var loadedCacheKey: String?

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill))
                    .overlay { ProgressView() }
            }
        }
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
                ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixelSize, cacheKey: key)
            }.value
            guard !Task.isCancelled else { return }
            image = loadedImage
            loadedCacheKey = key
        }
    }

    private var displayedImage: UIImage? {
        if loadedCacheKey == cacheKey {
            return image
        }
        return ThumbnailLoader.cached(forKey: cacheKey)
    }

    private var cacheKey: String {
        "representative-\(photo.id.uuidString)-\(photo.byteCount)-\(Int(maxPixelSize))"
    }
}

private struct RepresentativePhotoPicker: View {
    let event: ExperienceEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var saveErrorMessage: String?

    private var photos: [PhotoBlob] {
        EventRepresentativePhotoResolver.allPhotos(in: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(photos) { photo in
                        Button {
                            save(photo.relativePath)
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 360)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                if photo.relativePath == event.representativeEyecatchPath {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.accentColor)
                                        .padding(7)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(photo.relativePath == event.representativeEyecatchPath ? "選択中の代表写真" : "代表写真に設定")
                    }
                }
                .padding(16)
            }
            .navigationTitle("代表写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("自動") { save("") }
                        .disabled(event.representativeEyecatchPath.isEmpty)
                }
            }
            .alert("保存に失敗しました", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private func save(_ path: String) {
        let previousPath = event.representativeEyecatchPath
        event.representativeEyecatchPath = path
        event.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            event.representativeEyecatchPath = previousPath
            saveErrorMessage = "代表写真を保存できませんでした。もう一度お試しください。"
        }
    }
}

struct EditEventView: View {
    let event: ExperienceEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: EventDraft
    @State private var eyecatchData: Data?
    @State private var selectedEyecatchItem: PhotosPickerItem?
    @State private var isProcessingEyecatch = false
    @State private var saveErrorMessage: String?

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    init(event: ExperienceEvent) {
        self.event = event
        _draft = State(initialValue: EventDraft(event: event))
        _eyecatchData = State(initialValue: event.eyecatchData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let eyecatchData, let image = UIImage(data: eyecatchData) {
                        eyecatchPreview(image)

                        Button("画像を外す", role: .destructive) {
                            self.eyecatchData = nil
                        }
                    }

                    PhotosPicker(selection: $selectedEyecatchItem, matching: .images) {
                        Label(eyecatchData == nil ? "写真を選ぶ" : "写真を変更", systemImage: "photo")
                    }
                    .disabled(isProcessingEyecatch)
                    .onChange(of: selectedEyecatchItem) { _, item in
                        guard let item else { return }
                        Task { await loadEyecatch(from: item) }
                    }

                    if isProcessingEyecatch {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("画像を準備しています")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if event.category?.templateKey == "book" {
                        Picker("本の種類", selection: $draft.eyecatchAspectRatioKey) {
                            ForEach(bookFormatOptions) { format in
                                Text(format.name).tag(format.key)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(selectedEyecatchAspectRatio.note)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if event.category?.templateKey == "theater" {
                        EventHeroBackgroundPicker(
                            categoryKey: "theater",
                            selection: $draft.heroBackgroundPresetKey
                        )
                    }
                } header: {
                    Text("対象アイキャッチ")
                } footer: {
                    Text("クイック登録の表紙や、記録写真がない対象の代表画像として表示します。")
                }

                Section(template.targetSectionTitle) {
                    TextField(template.titlePlaceholder, text: $draft.title)
                    TextField(template.seriesPlaceholder, text: $draft.seriesName)
                    TextField("サブタイトル（任意）", text: $draft.eventSubtitle)
                    TextField("公式URL（任意）", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("SNSリンク（1行1件・任意）", text: $draft.socialLinksText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .lineLimit(2...5)
                }

                if event.category?.templateKey == "theater" {
                    Section("公演期間・会場") {
                        Toggle("公式の公演期間を登録", isOn: $draft.hasPerformancePeriod)

                        if draft.hasPerformancePeriod {
                            DatePicker(
                                "開始日",
                                selection: $draft.performanceStartsAt,
                                displayedComponents: .date
                            )
                            DatePicker(
                                "終了日",
                                selection: $draft.performanceEndsAt,
                                in: draft.performanceStartsAt...,
                                displayedComponents: .date
                            )
                        }

                        ForEach($draft.venueEntries) { $venue in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("会場名", text: $venue.name)
                                TextField("住所（任意）", text: $venue.address)
                            }
                        }
                        .onDelete { offsets in
                            draft.venueEntries.remove(atOffsets: offsets)
                        }

                        Button {
                            draft.venueEntries.append(EventVenueEntry())
                        } label: {
                            Label("会場を追加", systemImage: "plus.circle")
                        }
                    } footer: {
                        Text("未登録の場合は、予定と参加履歴の日付・会場から補完表示します。")
                    }
                }

                Section(event.category?.templateKey == "theater" ? "あらすじ" : "対象メモ") {
                    ZStack(alignment: .topLeading) {
                        if draft.memo.isEmpty {
                            Text(event.category?.templateKey == "theater" ? "公演のあらすじ（任意）" : "対象そのものについて残しておきたいこと")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.memo)
                            .frame(minHeight: 120)
                    }
                }

                Section("読み取りメモ") {
                    TextEditor(text: $draft.importMemo)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("対象を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave || isProcessingEyecatch)
                }
            }
            .alert("保存に失敗しました", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    @MainActor
    private func loadEyecatch(from item: PhotosPickerItem) async {
        isProcessingEyecatch = true
        defer {
            isProcessingEyecatch = false
            selectedEyecatchItem = nil
        }
        guard let sourceData = try? await item.loadTransferable(type: Data.self),
              let compressed = await Task.detached(priority: .userInitiated, operation: {
                  QuickCaptureImageService.compressedJPEG(from: sourceData)
              }).value else {
            saveErrorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed
    }

    @ViewBuilder
    private func eyecatchPreview(_ image: UIImage) -> some View {
        if EyecatchAspectRatio.usesEyecatchFill(for: event.category) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(
                    CGFloat(selectedEyecatchAspectRatio.value),
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func save() {
        event.title = draft.trimmedTitle
        event.seriesName = draft.trimmedSeriesName
        event.officialURL = draft.trimmedOfficialURL
        var unitFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        unitFields.socialLinks = draft.normalizedSocialLinks
        unitFields.eventSubtitle = draft.trimmedEventSubtitle
        unitFields.eventPeriodStartsAt = draft.hasPerformancePeriod ? draft.performanceStartsAt : nil
        unitFields.eventPeriodEndsAt = draft.hasPerformancePeriod ? draft.performanceEndsAt : nil
        unitFields.eventVenues = draft.normalizedVenueEntries
        unitFields.heroBackgroundPresetKey = draft.heroBackgroundPresetKey
        event.memo = draft.trimmedMemo
        event.importMemo = draft.trimmedImportMemo
        event.eyecatchData = eyecatchData
        if event.category?.templateKey == "book" {
            unitFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
        }
        event.unitFieldsRaw = unitFields.encodedRawValue
        event.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "対象情報を保存できませんでした。もう一度お試しください。"
            assertionFailure("Failed to update event: \(error)")
        }
    }

    private var selectedEyecatchAspectRatio: EyecatchAspectRatio {
        EyecatchAspectRatio.option(for: draft.eyecatchAspectRatioKey, category: event.category)
    }

    private var bookFormatOptions: [EyecatchAspectRatio] {
        if draft.eyecatchAspectRatioKey == EyecatchAspectRatio.bookCover.key {
            return [EyecatchAspectRatio.bookCover] + EyecatchAspectRatio.selectableBookFormats
        }
        return EyecatchAspectRatio.selectableBookFormats
    }
}

private struct EventDraft {
    var title: String
    var seriesName: String
    var officialURL: String
    var socialLinksText: String
    var eventSubtitle: String
    var memo: String
    var importMemo: String
    var eyecatchAspectRatioKey: String
    var hasPerformancePeriod: Bool
    var performanceStartsAt: Date
    var performanceEndsAt: Date
    var venueEntries: [EventVenueEntry]
    var heroBackgroundPresetKey: String

    init(event: ExperienceEvent) {
        title = event.title
        seriesName = event.seriesName
        officialURL = event.officialURL
        let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        socialLinksText = fields.socialLinks.joined(separator: "\n")
        eventSubtitle = fields.eventSubtitle
        memo = event.memo
        importMemo = event.importMemo
        eyecatchAspectRatioKey = EyecatchAspectRatio.resolved(for: event).key
        hasPerformancePeriod = fields.eventPeriodStartsAt != nil || fields.eventPeriodEndsAt != nil
        performanceStartsAt = fields.eventPeriodStartsAt ?? (event.plans ?? []).map(\.startsAt).min() ?? Date()
        let fallbackEnd = (event.plans ?? []).map(\.endsAt).max() ?? performanceStartsAt
        performanceEndsAt = max(fields.eventPeriodEndsAt ?? fallbackEnd, performanceStartsAt)
        venueEntries = fields.eventVenues
        heroBackgroundPresetKey = fields.heroBackgroundPresetKey
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEventSubtitle: String {
        eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSocialLinks: [String] {
        socialLinksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedImportMemo: String {
        importMemo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedVenueEntries: [EventVenueEntry] {
        venueEntries.compactMap { entry in
            let normalized = EventVenueEntry(
                id: entry.id,
                name: entry.trimmedName,
                address: entry.trimmedAddress
            )
            return normalized.isEmpty ? nil : normalized
        }
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }
}

private struct StatSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FavorecoTypography.latinDisplay(22, weight: .bold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EventEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(message)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let category = RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45", templateKey: "theater")
    let event = ExperienceEvent(title: "サンプル公演", seriesName: "東京公演", category: category)

    NavigationStack {
        EventDetailView(event: event)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
