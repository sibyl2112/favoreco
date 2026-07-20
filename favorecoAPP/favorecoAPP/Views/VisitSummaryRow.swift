//
//  VisitSummaryRow.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI
import SwiftData
import UIKit

struct VisitSummaryRow: View {
    let visit: Visit
    var showsCategory: Bool = true

    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Environment(\.displayScale) private var displayScale
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var thumbnailImage: UIImage?
    @State private var loadedThumbnailKey: String?

    private var title: String {
        visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
    }

    private var category: RecordCategory? {
        visit.event?.category
    }

    private var categoryColor: Color {
        themePalette.categoryColor(hex: category?.colorHex ?? "#147C88")
    }

    private var firstPhoto: PhotoBlob? {
        let photos = (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
        if !visit.eyecatchPath.isEmpty,
           let cover = photos.first(where: { $0.relativePath == visit.eyecatchPath }) {
            return cover
        }
        return photos.min { $0.createdAt < $1.createdAt }
    }

    // 64pt幅サムネ。scale過剰を避けるため上限クランプ。
    private var thumbnailMaxPixel: CGFloat {
        min(80 * displayScale, 480)
    }

    // 写真ID＋表示サイズをキーに含める
    private func cacheKey(for photo: PhotoBlob) -> String {
        "\(photo.id.uuidString)@\(Int(thumbnailMaxPixel.rounded()))"
    }

    private var thumbnailTaskID: String? {
        firstPhoto.map { cacheKey(for: $0) }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let photo = firstPhoto else {
            thumbnailImage = nil
            loadedThumbnailKey = nil
            return
        }
        let targetID = photo.id
        let key = cacheKey(for: photo)
        if let cached = ThumbnailLoader.cached(forKey: key) {
            thumbnailImage = cached
            loadedThumbnailKey = key
            return
        }
        thumbnailImage = nil
        loadedThumbnailKey = nil
        let data = photo.data // SwiftData プロパティはメインで読み、値型で渡す
        let maxPixel = thumbnailMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixel, cacheKey: key)
        }.value
        // セル再利用や写真変更後に遅れて届いた結果で、別の写真の画像を上書きしない
        guard !Task.isCancelled, firstPhoto?.id == targetID else { return }
        thumbnailImage = image
        loadedThumbnailKey = key
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    private var eyecatchAspectRatio: Double {
        EyecatchAspectRatio.option(for: unitFields.eyecatchAspectRatioKey, category: category).value
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(FavorecoTypography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let statusText = VisitSummaryFormatter.ticketStatusText(visit.outcomeKey) {
                        Text(statusText)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(categoryColor)
                            .lineLimit(1)
                    }
                }

                VisitSummaryMetaLine(items: metaItems)

                if !peopleSummary.isEmpty {
                    Label(peopleSummary, systemImage: "person.2")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !visit.note.isEmpty {
                    Text(visit.note)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if hasBadges {
                    HStack(spacing: 6) {
                        if visit.amount != Decimal(0) {
                            VisitSummaryBadge(text: VisitSummaryFormatter.amount(visit.amount), icon: "yensign.circle")
                        }
                        if !unitFields.ocrText.isEmpty {
                            VisitSummaryBadge(text: "OCR", icon: "text.viewfinder")
                        }
                        if !unitFields.advancedEntries.isEmpty {
                            VisitSummaryBadge(text: "詳細", icon: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let displayedThumbnailImage {
            Image(uiImage: displayedThumbnailImage)
                .resizable()
                .aspectRatio(
                    contentMode: EyecatchAspectRatio.usesEyecatchFill(for: category) ? .fill : .fit
                )
                .frame(width: 64, height: thumbnailHeight)
                .clipped()
                .background(categoryColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: category?.iconSymbol ?? "sparkles.rectangle.stack")
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 64, height: thumbnailHeight)
                .background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var displayedThumbnailImage: UIImage? {
        guard let key = thumbnailTaskID else { return nil }
        if loadedThumbnailKey == key {
            return thumbnailImage
        }
        return ThumbnailLoader.cached(forKey: key)
    }

    private var thumbnailHeight: CGFloat {
        let rawHeight = 64 / max(0.45, eyecatchAspectRatio)
        return min(96, max(56, rawHeight))
    }

    private var metaItems: [VisitSummaryMetaItem] {
        var items: [VisitSummaryMetaItem] = [
            VisitSummaryMetaItem(
                icon: unitFields.weatherSymbolName.isEmpty ? "calendar" : unitFields.weatherSymbolName,
                text: FavorecoDateText.compactDate(visit.visitedAt)
            )
        ]
        if showsCategory, let categoryName = category?.name, !categoryName.isEmpty {
            items.append(VisitSummaryMetaItem(icon: category?.iconSymbol ?? "square.grid.2x2", text: categoryName))
        }
        if !visit.venueNameSnapshot.isEmpty {
            items.append(VisitSummaryMetaItem(icon: "mappin.and.ellipse", text: visit.venueNameSnapshot))
        }
        if visit.overallRating > 0 {
            items.append(VisitSummaryMetaItem(icon: "star.fill", text: String(format: "%.1f", visit.overallRating)))
        }
        return items
    }

    private var peopleSummary: String {
        let linkedPeople = personLinks
            .filter { link in
                !link.isArchived && (link.event?.id == visit.event?.id || link.visit?.id == visit.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(2)
            .map { link in
                link.nameSnapshot.isEmpty ? link.person?.displayName ?? "" : link.nameSnapshot
            }
            .filter { !$0.isEmpty }
        return linkedPeople.joined(separator: " / ")
    }

    private var hasBadges: Bool {
        visit.amount != Decimal(0) || !unitFields.ocrText.isEmpty || !unitFields.advancedEntries.isEmpty
    }
}

struct VisitRecordGalleryGrid: View {
    let visits: [Visit]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(visits) { visit in
                NavigationLink {
                    ExperienceDetailView(visit: visit)
                } label: {
                    VisitRecordGalleryTile(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VisitRecordCompactGrid: View {
    let visits: [Visit]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 2
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(visits) { visit in
                NavigationLink {
                    ExperienceDetailView(visit: visit)
                } label: {
                    VisitRecordCompactTile(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VisitRecordBannerList: View {
    let visits: [Visit]

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(visits) { visit in
                NavigationLink {
                    ExperienceDetailView(visit: visit)
                } label: {
                    VisitRecordBannerRow(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VisitRecordGalleryTile: View {
    let visit: Visit

    @Environment(\.favorecoThemePalette) private var themePalette

    private var category: RecordCategory? { visit.event?.category }
    private var tint: Color { themePalette.categoryColor(hex: category?.colorHex ?? "#147C88") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VisitRecordArtwork(visit: visit, maxPixelSize: 520)

            HStack(alignment: .center, spacing: 3) {
                Text(FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt))
                    .foregroundStyle(dateColor)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 1)

                Rectangle()
                    .fill(tint.opacity(0.34))
                    .frame(width: 0.6, height: 11)

                Spacer(minLength: 1)

                HStack(spacing: 2) {
                    Image(systemName: visit.overallRating > 0 ? "star.fill" : "star")
                    Text(ratingText)
                }
                .foregroundStyle(visit.overallRating > 0 ? Color.yellow : Color.secondary)
            }
            .font(FavorecoTypography.jpSans(9.5, weight: .medium, relativeTo: .caption2))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .overlay {
            Rectangle().stroke(tint.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var dateColor: Color {
        switch FavorecoDateText.weekdayNumber(visit.visitedAt) {
        case 1: .red
        case 7: .blue
        default: .secondary
        }
    }

    private var ratingText: String {
        visit.overallRating > 0 ? String(format: "%.1f", visit.overallRating) : "—"
    }

    private var accessibilitySummary: String {
        "\(visit.event?.title ?? "記録")、\(FavorecoDateText.compactDate(visit.visitedAt))、評価\(ratingText)"
    }
}

private struct VisitRecordCompactTile: View {
    let visit: Visit

    @Environment(\.favorecoThemePalette) private var themePalette

    private var category: RecordCategory? { visit.event?.category }
    private var tint: Color { themePalette.categoryColor(hex: category?.colorHex ?? "#147C88") }
    private var isMovie: Bool { category?.templateKey == "movie" }
    private var cardHeight: CGFloat { isMovie ? 108 : 106 }
    private var artworkWidth: CGFloat { isMovie ? 76 : 58 }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VisitRecordArtwork(
                visit: visit,
                aspectRatioOverride: artworkWidth / (isMovie ? cardHeight : cardHeight - 16),
                maxPixelSize: 420
            )
            .frame(width: artworkWidth, height: isMovie ? cardHeight : cardHeight - 16)

            VStack(alignment: .leading, spacing: isMovie ? 3 : 4) {
                Text(title)
                    .font(FavorecoTypography.jpSans(isMovie ? 10.5 : 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.primary)
                    .tracking(-0.35)
                    .lineSpacing(-1.5)
                    .lineLimit(2, reservesSpace: true)

                Label(FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt), systemImage: "calendar")
                    .font(FavorecoTypography.jpSans(isMovie ? 8.5 : 9, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                compactRating
            }
            .padding(.vertical, isMovie ? 7 : 0)
            .padding(.trailing, isMovie ? 7 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(isMovie ? 0 : 8)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)、\(FavorecoDateText.compactDate(visit.visitedAt))")
    }

    private var title: String {
        visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
    }

    @ViewBuilder
    private var compactRating: some View {
        HStack(spacing: 4) {
            if visit.overallRating > 0 {
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: starSymbol(at: index))
                    }
                }
            } else {
                Image(systemName: "star")
            }

            Text(visit.overallRating > 0 ? String(format: "%.1f", visit.overallRating) : "—")
                .monospacedDigit()
        }
        .font(.system(size: 7.5, weight: .medium))
        .foregroundStyle(visit.overallRating > 0 ? Color.yellow : Color.secondary)
        .lineLimit(1)
    }

    private func starSymbol(at index: Int) -> String {
        let roundedRating = (visit.overallRating * 2).rounded() / 2
        if roundedRating >= Double(index) { return "star.fill" }
        if roundedRating >= Double(index) - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

private struct VisitRecordBannerRow: View {
    let visit: Visit

    @Environment(\.favorecoThemePalette) private var themePalette

    private var category: RecordCategory? { visit.event?.category }
    private var tint: Color { themePalette.categoryColor(hex: category?.colorHex ?? "#147C88") }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VisitRecordArtwork(visit: visit, maxPixelSize: 520)
                .frame(width: 82)

            VStack(alignment: .leading, spacing: 5) {
                Text(statusText)
                    .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(tint.opacity(0.12), in: Capsule())

                Text(title)
                    .font(FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineSpacing(-1)
                    .lineLimit(2, reservesSpace: true)

                VStack(alignment: .leading, spacing: 4) {
                    Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar")
                    if !visit.venueNameSnapshot.isEmpty {
                        Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 45)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
    }

    private var statusText: String {
        switch category?.templateKey {
        case "theater": "観劇済み"
        case "movie": "鑑賞済み"
        case "museum": "鑑賞済み"
        case "live": "参加済み"
        case "book": "読了"
        case "sake": "飲んだ"
        case "outing_facility": "訪問済み"
        case "goshuin": "参拝済み"
        default: category?.name.isEmpty == false ? category?.name ?? "体験済み" : "体験済み"
        }
    }
}

private struct VisitRecordArtwork: View {
    let visit: Visit
    var aspectRatioOverride: CGFloat? = nil
    var maxPixelSize: CGFloat = 520

    @Environment(\.displayScale) private var displayScale
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var thumbnailImage: UIImage?
    @State private var loadedThumbnailKey: String?

    private var category: RecordCategory? {
        visit.event?.category
    }

    private var categoryColor: Color {
        themePalette.categoryColor(hex: category?.colorHex ?? "#147C88")
    }

    private var firstPhoto: PhotoBlob? {
        let photos = (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
        if !visit.eyecatchPath.isEmpty,
           let cover = photos.first(where: { $0.relativePath == visit.eyecatchPath }) {
            return cover
        }
        return photos.min { $0.createdAt < $1.createdAt }
            ?? visit.event.flatMap { EventRepresentativePhotoResolver.photo(for: $0) }
    }

    private var thumbnailMaxPixel: CGFloat {
        min(maxPixelSize * displayScale, 1040)
    }

    private func cacheKey(for photo: PhotoBlob) -> String {
        "\(photo.id.uuidString)@record-library-\(Int(thumbnailMaxPixel.rounded()))"
    }

    private var thumbnailTaskID: String? {
        firstPhoto.map { cacheKey(for: $0) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                categoryColor.opacity(0.12)

                if let displayedThumbnailImage {
                    Image(uiImage: displayedThumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: category?.iconSymbol ?? "sparkles.rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }

    private var aspectRatio: CGFloat {
        if let aspectRatioOverride { return aspectRatioOverride }
        if let event = visit.event { return CGFloat(EyecatchAspectRatio.resolved(for: event).value) }
        let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        return CGFloat(EyecatchAspectRatio.option(for: fields.eyecatchAspectRatioKey, category: category).value)
    }

    private var displayedThumbnailImage: UIImage? {
        guard let key = thumbnailTaskID else { return nil }
        if loadedThumbnailKey == key {
            return thumbnailImage
        }
        return ThumbnailLoader.cached(forKey: key)
    }

    @MainActor
    private func loadThumbnail() async {
        guard let photo = firstPhoto else {
            thumbnailImage = nil
            loadedThumbnailKey = nil
            return
        }
        let targetID = photo.id
        let key = cacheKey(for: photo)
        if let cached = ThumbnailLoader.cached(forKey: key) {
            thumbnailImage = cached
            loadedThumbnailKey = key
            return
        }
        thumbnailImage = nil
        loadedThumbnailKey = nil
        let data = photo.data
        let maxPixel = thumbnailMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixel, cacheKey: key)
        }.value
        guard !Task.isCancelled, firstPhoto?.id == targetID else { return }
        thumbnailImage = image
        loadedThumbnailKey = key
    }
}

private struct VisitSummaryMetaItem: Identifiable {
    let id = UUID()
    var icon: String
    var text: String
}

private struct VisitSummaryMetaLine: View {
    let items: [VisitSummaryMetaItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Label(item.text, systemImage: item.icon)
                    .lineLimit(1)
            }
        }
        .font(FavorecoTypography.caption)
        .foregroundStyle(.secondary)
    }
}

private struct VisitSummaryBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private enum VisitSummaryFormatter {
    static func ticketStatusText(_ key: String) -> String? {
        switch key {
        case "planned": return "予定"
        case "applied": return "申込中"
        case "won": return "当選"
        case "paid": return "入金済み"
        case "ticketed": return "発券済み"
        case "attended": return "参加済み"
        case "canceled": return "中止"
        default: return nil
        }
    }

    static func amount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
    }
}
