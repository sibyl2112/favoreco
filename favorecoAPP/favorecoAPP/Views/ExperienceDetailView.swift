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
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @State private var isShowingEdit = false
    @State private var calendarDraft: CalendarEventDraft?
    @State private var isShowingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?

    private var event: ExperienceEvent? {
        visit.event
    }

    private var category: RecordCategory? {
        event?.category
    }

    private var accentColor: Color {
        Color(hex: category?.colorHex ?? "#6F8F7A")
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    private var firstPhotoImage: UIImage? {
        guard let photo = sortedPhotos.first,
              !photo.data.isEmpty else {
            return nil
        }
        return UIImage(data: photo.data)
    }

    private var sortedPhotos: [PhotoBlob] {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && !$0.data.isEmpty }
            .sorted { lhs, rhs in
                let lhsIsCover = !visit.eyecatchPath.isEmpty && lhs.relativePath == visit.eyecatchPath
                let rhsIsCover = !visit.eyecatchPath.isEmpty && rhs.relativePath == visit.eyecatchPath
                if lhsIsCover != rhsIsCover { return lhsIsCover }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private var linkedPeople: [EventPersonLink] {
        personLinks
            .filter { link in
                !link.isArchived && (link.event?.id == event?.id || link.visit?.id == visit.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var eyecatchAspectRatio: Double {
        EyecatchAspectRatio.option(
            for: unitFields.eyecatchAspectRatioKey,
            category: category
        ).value
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                photoSection
                goshuinBookSection
                peopleSection
                ocrSection
                basicInfo
                advancedSection
                memoSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(eventTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            Text("この回の記録と写真を削除します。対象（\(eventTitle)）と他の記録は残ります。取り消せません。")
        }
        .alert("削除に失敗しました", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deletionErrorMessage = nil }
        } message: {
            Text(deletionErrorMessage ?? "")
        }
        .task(id: weatherTaskID) {
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category?.iconSymbol ?? "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(eventTitle)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(category?.name ?? "未分類")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)
                }
            }

            if let seriesName = event?.seriesName, !seriesName.isEmpty {
                Label(seriesName, systemImage: "rectangle.stack")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var photoSection: some View {
        if !sortedPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("写真")

                if sortedPhotos.count == 1, let firstPhotoImage {
                    Image(uiImage: firstPhotoImage)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(CGFloat(eyecatchAspectRatio), contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                        ForEach(sortedPhotos) { photo in
                            if let image = UIImage(data: photo.data) {
                                ZStack(alignment: .bottomLeading) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .aspectRatio(CGFloat(eyecatchAspectRatio), contentMode: .fill)
                                        .frame(maxWidth: .infinity)
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
            }
            .sectionCard()
        }
    }

    @ViewBuilder
    private var goshuinBookSection: some View {
        if category?.templateKey == "goshuin", !unitFields.goshuinBookSizeKey.isEmpty {
            let size = GoshuinBookSize.option(for: unitFields.goshuinBookSizeKey)
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
    private var peopleSection: some View {
        if !linkedPeople.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("人物・団体")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(linkedPeople) { link in
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
    private var ocrSection: some View {
        if !unitFields.ocrText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("OCR・取込")
                Text(unitFields.ocrText)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .sectionCard()
        }
    }

    private var basicInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(template.visitSectionTitle)
            DetailInfoRow(icon: "calendar", title: template.dateLabel, value: visit.visitedAt.formatted(date: .long, time: .omitted))

            if !unitFields.weatherSymbolName.isEmpty {
                DetailInfoRow(
                    icon: unitFields.weatherSymbolName,
                    title: "天気",
                    value: weatherTemperatureText
                )
                if let weatherAttributionURL {
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

            if let mapURL {
                Button {
                    openURL(mapURL)
                } label: {
                    Label("地図で見る", systemImage: "map")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            DetailInfoRow(icon: "star.fill", title: template.ratingLabel, value: ratingText)

            if !visit.outcomeKey.isEmpty {
                DetailInfoRow(icon: "ticket", title: "チケット状態", value: ticketStatusText)
            }

            if !visit.seatText.isEmpty {
                DetailInfoRow(icon: "chair", title: "座席・チケット", value: visit.seatText)
            }

            if visit.amount != Decimal(0) {
                DetailInfoRow(icon: "yensign.circle", title: "金額", value: formattedAmount)
            }

            Button {
                calendarDraft = makeCalendarDraft()
            } label: {
                Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .sectionCard()
    }

    private var mapURL: URL? {
        PlaceSearchService.appleMapsURL(
            name: visit.venueNameSnapshot,
            address: visit.placeMaster?.address ?? "",
            latitude: visit.latitude,
            longitude: visit.longitude
        )
    }

    @ViewBuilder
    private var advancedSection: some View {
        if !unitFields.advancedEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("詳細オプション")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(unitFields.advancedEntries) { entry in
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
    private var memoSection: some View {
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

    private var eventTitle: String {
        guard let title = event?.title, !title.isEmpty else {
            return "記録"
        }
        return title
    }

    private var ratingText: String {
        if visit.overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", visit.overallRating)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    private var weatherTaskID: String {
        "\(visit.visitedAt.timeIntervalSinceReferenceDate)-\(visit.latitude)-\(visit.longitude)-\(unitFields.weatherSymbolName)"
    }

    private var weatherTemperatureText: String {
        guard let high = unitFields.weatherHighCelsius,
              let low = unitFields.weatherLowCelsius else {
            return "記録済み"
        }
        return "最高 \(Int(high.rounded()))° / 最低 \(Int(low.rounded()))°"
    }

    private var weatherAttributionURL: URL? {
        URL(string: unitFields.weatherAttributionURL)
    }

    private var ticketStatusText: String {
        switch visit.outcomeKey {
        case "planned": return "予定"
        case "applied": return "申込中"
        case "won": return "当選"
        case "paid": return "入金済み"
        case "ticketed": return "発券済み"
        case "attended": return "参加済み"
        case "canceled": return "中止・キャンセル"
        default: return visit.outcomeKey
        }
    }

    private var formattedAmount: String {
        let number = NSDecimalNumber(decimal: visit.amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }

    private func makeCalendarDraft() -> CalendarEventDraft {
        let endDate = visit.endedAt > visit.visitedAt
            ? visit.endedAt
            : Calendar.current.date(byAdding: .hour, value: 2, to: visit.visitedAt) ?? visit.visitedAt
        var notes: [String] = []
        if !visit.seatText.isEmpty {
            notes.append("座席・チケット: \(visit.seatText)")
        }
        if !ticketStatusText.isEmpty && !visit.outcomeKey.isEmpty {
            notes.append("チケット状態: \(ticketStatusText)")
        }
        if visit.amount != Decimal(0) {
            notes.append("金額: \(formattedAmount)")
        }
        if !visit.note.isEmpty {
            notes.append("")
            notes.append(visit.note)
        }
        if let url = event?.officialURL, !url.isEmpty {
            notes.append("")
            notes.append(url)
        }

        return CalendarEventDraft(
            title: eventTitle,
            location: preferredLocationText,
            notes: notes.joined(separator: "\n"),
            startDate: visit.visitedAt,
            endDate: endDate
        )
    }

    private var preferredLocationText: String {
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? visit.venueNameSnapshot : address
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
