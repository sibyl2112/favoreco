import SwiftUI

struct PlaceExperienceVisitRow: View {
    let visit: Visit
    let isPark: Bool
    let tint: Color

    private var eventTitle: String {
        guard let title = visit.event?.title, !title.isEmpty else {
            return isPark ? "来園記録" : "体験記録"
        }
        return title
    }

    private var placeText: String {
        if !visit.venueNameSnapshot.isEmpty { return visit.venueNameSnapshot }
        return visit.placeMaster?.name ?? ""
    }

    private var visitSubtitle: String {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
            .visitSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geometry in
                ThumbnailImage(
                    reference: visit.event.map { .event($0.id) },
                    displaySize: geometry.size,
                    contentMode: .fill
                ) {
                    ZStack {
                        tint.opacity(0.12)
                        FavorecoIcon(
                            systemName: isPark ? "ticket" : "leaf",
                            size: 24
                        )
                        .foregroundStyle(tint)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(eventTitle)
                    .font(FavorecoTypography.jpSans(16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !visitSubtitle.isEmpty {
                    Text(visitSubtitle)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }

                FavorecoIconLabel(
                    "\(FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt))  \(FavorecoDateText.time(visit.visitedAt))",
                    systemImage: "calendar",
                    iconSize: 12
                )
                .lineLimit(1)

                if !placeText.isEmpty {
                    FavorecoIconLabel(placeText, systemImage: "mappin.and.ellipse", iconSize: 12)
                        .lineLimit(1)
                } else if !visit.note.isEmpty {
                    Text(visit.note)
                        .lineLimit(1)
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint.opacity(0.72))
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eventTitle)、\(FavorecoDateText.compactDate(visit.visitedAt))")
    }
}
