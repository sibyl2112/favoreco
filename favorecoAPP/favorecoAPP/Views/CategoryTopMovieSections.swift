import SwiftUI

struct CategoryVisitRecordItem: Identifiable {
    let event: ExperienceEvent
    let visit: Visit

    var id: UUID { visit.id }

    /// 記録ごとのアイキャッチを最優先し、未設定時だけ親作品へ戻す。
    /// 一覧と記録詳細で同じ解決順を使うための正本。
    var eyecatchReference: ThumbnailReference {
        let selectedPath = visit.eyecatchPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedPath.isEmpty,
           let selected = (visit.photos ?? []).first(where: {
               $0.relativePath == selectedPath && $0.mediaKind == "photo" && $0.hasStoredData
           }) {
            return .photo(selected.id)
        }
        return .event(event.id)
    }
}

enum CategoryVisitRecordItemBuilder {
    static func make(
        category: RecordCategory,
        visits: [Visit],
        screenWorkFilter: ScreenWorkFilter
    ) -> [CategoryVisitRecordItem] {
        visits.compactMap { visit in
            guard let event = visit.event,
                  event.category?.id == category.id else { return nil }
            if category.templateKey == "movie",
               !screenWorkFilter.includes(event.screenWorkType) {
                return nil
            }
            return CategoryVisitRecordItem(event: event, visit: visit)
        }
        .sorted { $0.visit.visitedAt > $1.visit.visitedAt }
    }
}

struct CategoryVisitRecordLibrarySection: View {
    let category: RecordCategory
    let items: [CategoryVisitRecordItem]
    let tint: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    @Binding var selectedLayout: CategoryLibraryLayoutMode
    let onOpenVisit: (Visit) -> Void

    var body: some View {
        let isLive = category.templateKey == "live"
        let layout: CategoryLibraryLayoutMode = isLive
            ? .banner
            : selectedLayout == .gallery ? .gallery : .banner
        let sectionTitle: (english: String, japanese: String) = switch category.templateKey {
        case "live": ("Live History", "ライブ記録")
        case "movie": ("Library", "鑑賞済み")
        default: ("Museum Log", "鑑賞記録")
        }
        let emptyCopy: (title: String, message: String) = switch category.templateKey {
        case "live": (
            "ライブ記録はまだありません",
            "参加した記録を追加すると、1回ごとにここへ並びます。"
        )
        default: (
            "鑑賞記録はまだありません",
            "鑑賞した記録を追加すると、1回ごとにここへ並びます。"
        )
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: sectionTitle.english,
                    japaneseTitle: sectionTitle.japanese,
                    foregroundColor: primaryTextColor
                )

                Text("\(items.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 4)

                if !isLive {
                    CategoryLibraryLayoutPicker(
                        selection: $selectedLayout,
                        tint: tint,
                        modes: [.gallery, .banner],
                        onSelect: { _ in }
                    )
                }
            }

            if items.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: emptyCopy.title,
                    message: emptyCopy.message,
                    tint: tint
                )
            } else if layout == .gallery {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                        count: 3
                    ),
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(items) { item in
                        Button {
                            onOpenVisit(item.visit)
                        } label: {
                            CategoryVisitRecordPosterTile(item: item, category: category)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            onOpenVisit(item.visit)
                        } label: {
                            CategoryVisitRecordBannerCard(
                                item: item,
                                category: category,
                                tint: tint
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CategoryVisitRecordPosterTile: View {
    let item: CategoryVisitRecordItem
    let category: RecordCategory

    private var posterAspectRatio: CGFloat {
        if category.templateKey == "movie" {
            return CGFloat(EyecatchAspectRatio.cinemaPoster.value)
        }
        return CGFloat(EyecatchAspectRatio.resolved(for: item.event).value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: category.templateKey == "live" ? 4 : 7) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    ThumbnailImage(
                        reference: item.eyecatchReference,
                        displaySize: geometry.size,
                        contentMode: .fill
                    ) {
                        CategoryDefaultArtworkImage(
                            templateKey: category.templateKey,
                            displaySize: geometry.size
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                    if category.templateKey == "museum" {
                        Text(ordinalBadgeText)
                            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.78), radius: 2, y: 1)
                            .padding(5)
                    }
                }
            }
            .aspectRatio(posterAspectRatio, contentMode: .fit)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(FavorecoDateText.compactDate(item.visit.visitedAt))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                Image(systemName: item.visit.overallRating > 0 ? "star.fill" : "star")
                    .foregroundStyle(item.visit.overallRating > 0 ? Color.yellow : Color.secondary)
                if item.visit.overallRating > 0 {
                    Text(String(format: "%.1f", item.visit.overallRating))
                        .monospacedDigit()
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.bottom, 7)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .overlay {
            Rectangle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("鑑賞記録の詳細を開きます")
    }

    private var accessibilityLabel: String {
        let title = item.event.title.isEmpty ? category.name : item.event.title
        let date = FavorecoDateText.compactDate(item.visit.visitedAt)
        let ordinal = category.templateKey == "museum"
            ? "、\(ExperienceDetailPresentation.museumVisitOrdinal(for: item.visit))"
            : ""
        guard item.visit.overallRating > 0 else {
            return "\(title)、\(date)\(ordinal)、評価なし"
        }
        return "\(title)、\(date)\(ordinal)、評価\(String(format: "%.1f", item.visit.overallRating))"
    }

    private var ordinalBadgeText: String {
        let ordinal = ExperienceDetailPresentation.visitOrdinal(for: item.visit)
        let circled = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"]
        return circled.indices.contains(ordinal) ? circled[ordinal] : "\(ordinal)"
    }
}

struct CategoryVisitRecordBannerCard: View {
    let item: CategoryVisitRecordItem
    let category: RecordCategory
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GeometryReader { geometry in
                ThumbnailImage(
                    reference: item.eyecatchReference,
                    displaySize: geometry.size,
                    contentMode: .fill
                ) {
                    CategoryDefaultArtworkImage(
                        templateKey: category.templateKey,
                        displaySize: geometry.size
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .frame(width: 82, height: 108)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.event.title.isEmpty ? category.name : item.event.title)
                    .font(FavorecoTypography.jpSans(15, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)

                FavorecoIconLabel(
                    category.templateKey == "live"
                        ? "\(FavorecoDateText.compactDateWithHalfWidthWeekday(item.visit.visitedAt)) \(FavorecoDateText.time(item.visit.visitedAt))"
                        : FavorecoDateText.compactDate(item.visit.visitedAt),
                    systemImage: "calendar",
                    iconSize: 14
                )
                .foregroundStyle(tint)

                if category.templateKey == "museum" {
                    FavorecoIconLabel(
                        ExperienceDetailPresentation.museumVisitOrdinal(for: item.visit),
                        systemImage: "arrow.clockwise",
                        iconSize: 14
                    )
                    .foregroundStyle(.secondary)
                }

                if category.templateKey == "movie" {
                    FavorecoIconLabel(
                        item.event.screenWorkType.displayName,
                        systemImage: "film",
                        iconSize: 14
                    )
                    .foregroundStyle(.secondary)
                } else if !item.visit.venueNameSnapshot.isEmpty {
                    FavorecoIconLabel(
                        item.visit.venueNameSnapshot,
                        systemImage: "mappin.and.ellipse",
                        iconSize: 14
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .font(FavorecoTypography.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(CategoryLibraryChrome.cardBorderOpacity), lineWidth: CategoryLibraryChrome.borderLineWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(category.templateKey == "live" ? "ライブ記録の詳細を開きます" : "鑑賞記録の詳細を開きます")
    }
}
