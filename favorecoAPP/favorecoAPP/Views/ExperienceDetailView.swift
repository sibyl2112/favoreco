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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.favorecoThemePalette) private var themePalette
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @State private var isShowingEdit = false
    @State private var calendarDraft: CalendarEventDraft?
    @State private var isShowingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?

    var body: some View {
        let snapshot = ExperienceDetailSnapshot.make(visit: visit, personLinks: personLinks)
        let accentColor = themePalette.categoryColor(hex: snapshot.category?.colorHex ?? "#6F8F7A")
        let template = CategoryRecordTemplate.template(for: snapshot.category)
        let isTheater = snapshot.category?.templateKey == "theater"

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isTheater {
                    theaterHero(snapshot: snapshot, accentColor: accentColor)
                        .padding(.horizontal, -8)
                    theaterCastSection(snapshot: snapshot, accentColor: accentColor)
                } else {
                    hero(snapshot: snapshot, accentColor: accentColor)
                }
                photoSection(snapshot: snapshot)
                goshuinBookSection(snapshot: snapshot)
                peopleSection(snapshot: snapshot, accentColor: accentColor)
                ocrSection(snapshot: snapshot)
                basicInfo(snapshot: snapshot, template: template)
                advancedSection(snapshot: snapshot)
                memoSection(template: template)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(isTheater ? TheaterDetailStyle.background : Color(.systemGroupedBackground))
        .environment(\.colorScheme, isTheater ? .dark : colorScheme)
        .navigationTitle(isTheater ? "観劇回詳細" : snapshot.eventTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isTheater {
                ToolbarItem(placement: .topBarTrailing) {
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
                        Label("メニュー", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEdit) {
            EditExperienceView(visit: visit)
        }
        .sheet(item: $calendarDraft) { draft in
            CalendarEventEditSheet(draft: draft)
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

    private func hero(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: snapshot.category?.iconSymbol ?? "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.eventTitle)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(snapshot.category?.name ?? "未分類")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)
                }
            }

            if let seriesName = snapshot.event?.seriesName, !seriesName.isEmpty {
                Label(seriesName, systemImage: "rectangle.stack")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func theaterHero(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            TheaterDetailPoster(event: snapshot.event)
                .frame(width: 126)

            VStack(alignment: .leading, spacing: 7) {
                Text(snapshot.eventTitle)
                    .font(FavorecoTypography.jpSerif(19, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(TheaterDetailStyle.ivory)
                    .lineLimit(2)

                Label(FavorecoDateText.fullDateTime(visit.visitedAt), systemImage: "calendar")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }

                if !visit.seatText.isEmpty {
                    Label(visit.seatText, systemImage: "chair")
                        .lineLimit(1)
                }

                theaterRating

                Spacer(minLength: 2)

                HStack(spacing: 8) {
                    Button {
                        isShowingEdit = true
                    } label: {
                        Label("記録を編集", systemImage: "pencil")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(TheaterDetailStyle.gold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .overlay {
                                Capsule().stroke(TheaterDetailStyle.gold.opacity(0.66), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("この記録だけ削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(TheaterDetailStyle.gold)
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle().stroke(TheaterDetailStyle.gold.opacity(0.66), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel("記録メニュー")
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(TheaterDetailStyle.ivory.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        }
        .padding(12)
        .background(TheaterDetailStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterDetailStyle.gold.opacity(0.42), lineWidth: 1)
        }
    }

    private var theaterRating: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: theaterRatingSymbol(at: index))
                    .foregroundStyle(visit.overallRating > 0 ? TheaterDetailStyle.gold : TheaterDetailStyle.ivory.opacity(0.34))
            }
            Text(visit.overallRating > 0 ? String(format: "%.1f", visit.overallRating) : "未評価")
                .foregroundStyle(TheaterDetailStyle.ivory.opacity(0.72))
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

    @ViewBuilder
    private func theaterCastSection(snapshot: ExperienceDetailSnapshot, accentColor: Color) -> some View {
        let castLinks = snapshot.linkedPeople.filter(isTheaterCastLink)
        if !castLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("キャスト（\(castLinks.count)人）")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(TheaterDetailStyle.ivory)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(castLinks) { link in
                            TheaterCastItem(
                                name: personName(for: link),
                                role: link.displayRole.isEmpty ? roleName(for: link.roleKey) : link.displayRole,
                                imagePath: link.person?.imagePath ?? "",
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
    private func photoSection(snapshot: ExperienceDetailSnapshot) -> some View {
        if !snapshot.photos.isEmpty {
            let contentMode: ContentMode = EyecatchAspectRatio.usesEyecatchFill(for: snapshot.category) ? .fill : .fit
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("写真")

                if snapshot.photos.count == 1, let firstPhoto = snapshot.photos.first {
                    RepresentativePhotoImage(photo: firstPhoto, maxPixelSize: 1600, contentMode: contentMode)
                        .aspectRatio(CGFloat(snapshot.eyecatchAspectRatio), contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                        ForEach(snapshot.photos) { photo in
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
            DetailInfoRow(
                icon: "calendar",
                title: template.dateLabel,
                value: FavorecoDateText.fullDate(visit.visitedAt)
            )

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

            if !visit.venueNameSnapshot.isEmpty {
                DetailInfoRow(icon: "mappin.and.ellipse", title: "場所", value: visit.venueNameSnapshot)
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

            DetailInfoRow(icon: "star.fill", title: template.ratingLabel, value: snapshot.ratingText)

            if !visit.outcomeKey.isEmpty {
                DetailInfoRow(icon: "ticket", title: "チケット状態", value: snapshot.ticketStatusText)
            }

            if !visit.seatText.isEmpty {
                DetailInfoRow(icon: "chair", title: "座席・チケット", value: visit.seatText)
            }

            if visit.amount != Decimal(0) {
                DetailInfoRow(icon: "yensign.circle", title: "金額", value: snapshot.formattedAmount)
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

private enum TheaterDetailStyle {
    static let background = Color(red: 0.035, green: 0.02, blue: 0.025)
    static let cardBackground = Color(red: 0.075, green: 0.045, blue: 0.05).opacity(0.96)
    static let wine = Color(red: 0.28, green: 0.035, blue: 0.08)
    static let gold = Color(red: 0.82, green: 0.62, blue: 0.30)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.84)
}

private struct TheaterDetailPoster: View {
    let event: ExperienceEvent?

    private var representativePhoto: PhotoBlob? {
        event.flatMap { EventRepresentativePhotoResolver.photo(for: $0) }
    }

    var body: some View {
        Group {
            if let representativePhoto {
                RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 720, contentMode: .fill)
            } else if let data = event?.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    TheaterDetailStyle.wine.opacity(0.72)
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(TheaterDetailStyle.gold)
                }
            }
        }
        .aspectRatio(CGFloat(EyecatchAspectRatio.bSeriesPoster.value), contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay {
            Rectangle().stroke(TheaterDetailStyle.gold.opacity(0.54), lineWidth: 1)
        }
    }
}

private struct TheaterCastItem: View {
    let name: String
    let role: String
    let imagePath: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            avatar
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(TheaterDetailStyle.gold.opacity(0.46), lineWidth: 1)
                }

            Text(name)
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(TheaterDetailStyle.ivory)
                .lineLimit(1)
                .frame(width: 74)

            Text(role)
                .font(FavorecoTypography.jpSans(9, weight: .regular, relativeTo: .caption2))
                .foregroundStyle(TheaterDetailStyle.ivory.opacity(0.58))
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
                Text(initial)
                    .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(TheaterDetailStyle.ivory)
            }
        }
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
    }

    private var personImage: UIImage? {
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
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
