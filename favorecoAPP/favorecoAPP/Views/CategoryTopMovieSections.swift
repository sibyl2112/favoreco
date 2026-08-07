import SwiftUI

struct CategoryVisitRecordItem: Identifiable {
    let event: ExperienceEvent
    let visit: Visit

    var id: UUID { visit.id }
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
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geometry in
                ThumbnailImage(
                    reference: .event(item.event.id),
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
            .aspectRatio(posterAspectRatio, contentMode: .fit)

            if category.templateKey == "museum" {
                Text(ExperienceDetailPresentation.museumVisitOrdinal(for: item.visit))
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }

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
}

struct CategoryVisitRecordBannerCard: View {
    let item: CategoryVisitRecordItem
    let category: RecordCategory
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GeometryReader { geometry in
                ThumbnailImage(
                    reference: .event(item.event.id),
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
                    FavorecoDateText.compactDate(item.visit.visitedAt),
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
        .accessibilityHint("鑑賞記録の詳細を開きます")
    }
}
