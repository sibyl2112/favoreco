import SwiftUI

struct MovieWatchedItem: Identifiable {
    let event: ExperienceEvent
    let latestVisit: Visit

    var id: UUID { event.id }
}

struct MovieWatchedPosterTile: View {
    let item: MovieWatchedItem

    private let posterAspectRatio = CGFloat(EyecatchAspectRatio.cinemaPoster.value)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geometry in
                ThumbnailImage(
                    reference: .event(item.event.id),
                    displaySize: geometry.size,
                    contentMode: .fill
                ) {
                    CategoryDefaultArtworkImage(
                        templateKey: "movie",
                        displaySize: geometry.size
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .aspectRatio(posterAspectRatio, contentMode: .fit)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(FavorecoDateText.compactDate(item.latestVisit.visitedAt))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                Image(systemName: item.latestVisit.overallRating > 0 ? "star.fill" : "star")
                    .foregroundStyle(item.latestVisit.overallRating > 0 ? Color.yellow : Color.secondary)
                if item.latestVisit.overallRating > 0 {
                    Text(String(format: "%.1f", item.latestVisit.overallRating))
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
        .accessibilityHint("映画の作品詳細を開きます")
    }

    private var accessibilityLabel: String {
        let title = item.event.title.isEmpty ? "映画" : item.event.title
        let date = FavorecoDateText.compactDate(item.latestVisit.visitedAt)
        guard item.latestVisit.overallRating > 0 else {
            return "\(title)、\(date)、評価なし"
        }
        return "\(title)、\(date)、評価\(String(format: "%.1f", item.latestVisit.overallRating))"
    }
}
