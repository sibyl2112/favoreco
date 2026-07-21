//
//  ExperienceDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit

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
        let backgroundPhoto = detailBackgroundPhoto(in: snapshot, excluding: eyecatchPhoto)

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

                memoSection(template: template)
                photoSection(
                    snapshot: snapshot,
                    excluding: Set([backgroundPhoto?.id, eyecatchPhoto?.id].compactMap { $0 })
                )
                classifiedPhotoSection(snapshot: snapshot, purpose: .ticket, accentColor: accentColor)
                classifiedPhotoSection(snapshot: snapshot, purpose: .goods, accentColor: accentColor)
                if isTheater {
                    theaterCastSection(snapshot: snapshot, accentColor: accentColor)
                }
                expenseAndTicketSection(
                    snapshot: snapshot,
                    plan: activePlan,
                    accentColor: accentColor
                )
                goshuinBookSection(snapshot: snapshot)
                peopleSection(snapshot: snapshot, accentColor: accentColor)
                ocrSection(snapshot: snapshot)
                basicInfo(snapshot: snapshot, template: template)
                advancedSection(snapshot: snapshot)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(detailPageBackground(genreColor: genreColor))
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
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
        ZStack(alignment: .bottomLeading) {
            recordHeroBackground(photo: backgroundPhoto, genreColor: genreColor)

            VStack(alignment: .leading, spacing: 14) {
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

                if let seriesName = snapshot.event?.seriesName, !seriesName.isEmpty {
                    Text(seriesName)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                HStack(alignment: .top, spacing: 16) {
                    RecordDetailEyecatch(
                        event: snapshot.event,
                        photo: eyecatchPhoto,
                        aspectRatio: snapshot.eyecatchAspectRatio,
                        fallbackSymbol: snapshot.category?.iconSymbol ?? "sparkles.rectangle.stack",
                        tint: accentColor
                    )
                    .frame(width: 112)

                    VStack(alignment: .leading, spacing: 11) {
                        recordMetadataRow(
                            icon: "calendar",
                            text: FavorecoDateText.fullDate(visit.visitedAt),
                            accentColor: .white.opacity(0.86)
                        )

                        recordMetadataRow(
                            icon: "clock",
                            text: performanceTimeText,
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

                        if !visit.seatText.isEmpty {
                            recordMetadataRow(
                                icon: "chair",
                                text: visit.seatText,
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

    private func recordHeroBackground(photo: PhotoBlob?, genreColor: Color) -> some View {
        GeometryReader { proxy in
            let imageBandHeight = min(proxy.size.height * 0.74, 420)

            ZStack(alignment: .top) {
                genreColor

                Group {
                    if let photo {
                        RepresentativePhotoImage(photo: photo, maxPixelSize: 1600, contentMode: .fill)
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
                    .opacity(photo == nil ? 0.10 : 0.08)
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
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
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

    private var performanceTimeText: String {
        let start = FavorecoDateText.time(visit.visitedAt)
        guard visit.endedAt > visit.visitedAt else {
            return start
        }
        return "\(start)–\(FavorecoDateText.time(visit.endedAt))"
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
                Image(systemName: theaterRatingSymbol(at: index))
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

    private func theaterRatingSymbol(at index: Int) -> String {
        let threshold = Double(index)
        if visit.overallRating >= threshold { return "star.fill" }
        if visit.overallRating >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
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

    private func detailBackgroundPhoto(
        in snapshot: ExperienceDetailSnapshot,
        excluding eyecatchPhoto: PhotoBlob?
    ) -> PhotoBlob? {
        memoryPhotos(in: snapshot).first { photo in
            photo.id != eyecatchPhoto?.id && photo.relativePath != eyecatchPhoto?.relativePath
        }
    }

    private func memoryPhotos(in snapshot: ExperienceDetailSnapshot) -> [PhotoBlob] {
        snapshot.photos.filter { photo in
            ExperiencePhotoPurpose.resolved(from: photo.purpose) == .memory
        }
    }

    @ViewBuilder
    private func classifiedPhotoSection(
        snapshot: ExperienceDetailSnapshot,
        purpose: ExperiencePhotoPurpose,
        accentColor: Color
    ) -> some View {
        let photos = snapshot.photos.filter {
            ExperiencePhotoPurpose.resolved(from: $0.purpose) == purpose
        }
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("\(purpose.title)（\(photos.count)件）")

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
            .sectionCard()
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
        accentColor: Color
    ) -> some View {
        let supportsTicketManagement = ["theater", "live"].contains(snapshot.category?.templateKey ?? "")
        VStack(alignment: .leading, spacing: 12) {
            ExperienceExpenseSummaryCard(
                summary: ExperienceExpenseSummary.make(visit: visit, plan: plan),
                tint: accentColor
            )

            if supportsTicketManagement {
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
    private func theaterCastSection(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        let castLinks = snapshot.linkedPeople.filter(isTheaterCastLink)
        if !castLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("キャスト（\(castLinks.count)人）")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(castLinks) { link in
                            TheaterCastItem(
                                name: personName(for: link),
                                role: link.displayRole.isEmpty ? roleName(for: link.roleKey) : link.displayRole,
                                imageData: link.person?.imageData,
                                imagePath: link.person?.imagePath ?? "",
                                roleTagsRaw: link.person?.roleTagsRaw ?? "",
                                tint: accentColor
                            )
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func photoSection(snapshot: ExperienceDetailSnapshot, excluding excludedPhotoIDs: Set<UUID>) -> some View {
        let galleryPhotos = memoryPhotos(in: snapshot).filter { !excludedPhotoIDs.contains($0.id) }
        if !galleryPhotos.isEmpty {
            let contentMode: ContentMode = EyecatchAspectRatio.usesEyecatchFill(for: snapshot.category) ? .fill : .fit
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("写真")

                if galleryPhotos.count == 1, let firstPhoto = galleryPhotos.first {
                    RepresentativePhotoImage(photo: firstPhoto, maxPixelSize: 1600, contentMode: contentMode)
                        .aspectRatio(CGFloat(snapshot.eyecatchAspectRatio), contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                        ForEach(galleryPhotos) { photo in
                            ZStack(alignment: .bottomLeading) {
                                RepresentativePhotoImage(photo: photo, maxPixelSize: 720, contentMode: contentMode)
                                    .aspectRatio(CGFloat(snapshot.eyecatchAspectRatio), contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .background(Color(.secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                if photo.relativePath == visit.eyecatchPath {
                                    Label("カバー", systemImage: "star.fill")
                                        .font(FavorecoTypography.captionStrong)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(.black.opacity(0.58), in: Capsule())
                                        .padding(7)
                                }
                            }
                        }
                    }
                }
            }
            .sectionCard()
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
            ? snapshot.linkedPeople.filter { !isTheaterCastLink($0) }
            : snapshot.linkedPeople
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(snapshot.category?.templateKey == "theater" ? "スタッフ・関係者" : "人物・団体")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(links) { link in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(link.displayRole.isEmpty ? roleName(for: link.roleKey) : link.displayRole)
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
    private func ocrSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if !snapshot.unitFields.ocrText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("OCR・取込")
                Text(snapshot.unitFields.ocrText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .sectionCard()
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

            if let address = visit.placeMaster?.address, !address.isEmpty {
                DetailInfoRow(icon: "signpost.right", title: "住所", value: address)
            }

            if let mapURL = snapshot.mapURL {
                Button {
                    openURL(mapURL)
                } label: {
                    Label("地図で見る", systemImage: "map")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !visit.outcomeKey.isEmpty {
                DetailInfoRow(icon: "ticket", title: "チケット状態", value: snapshot.ticketStatusText)
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
    private func memoSection(template: CategoryRecordTemplate) -> some View {
        if !visit.note.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(template.memoSectionTitle)
                Text(visit.note)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .sectionCard()
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

    private func roleName(for roleKey: String) -> String {
        switch roleKey {
        case "artist": return "アーティスト"
        case "cast": return "出演"
        case "lead": return "主演"
        case "writer": return "作家"
        case "author": return "作者"
        case "director": return "監督"
        case "screenplay": return "脚本"
        case "stage_director": return "演出"
        case "original_work": return "原作"
        case "music": return "音楽"
        case "performer": return "演奏"
        case "translator": return "翻訳"
        case "curator": return "キュレーター"
        case "organizer": return "主催"
        case "production": return "制作"
        case "publisher": return "出版社"
        case "guest": return "ゲスト"
        default: return "その他"
        }
    }

    private func isTheaterCastRole(_ roleKey: String) -> Bool {
        ["cast", "lead", "artist", "performer", "guest"].contains(roleKey)
    }

    private func isTheaterCastLink(_ link: EventPersonLink) -> Bool {
        if isTheaterCastRole(link.roleKey) { return true }
        let displayRole = link.displayRole
        return displayRole.contains("出演") || displayRole.contains("主演") || displayRole.contains("キャスト")
    }

    private func personName(for link: EventPersonLink) -> String {
        let snapshotName = link.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshotName.isEmpty { return snapshotName }
        let masterName = link.person?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return masterName.isEmpty ? "出演者" : masterName
    }
}

private struct RecordDetailEyecatch: View {
    let event: ExperienceEvent?
    let photo: PhotoBlob?
    let aspectRatio: Double
    let fallbackSymbol: String
    let tint: Color

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
