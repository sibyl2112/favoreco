import SwiftUI

struct FavorecoComingUpRow<Artwork: View>: View {
    let date: Date
    let timeText: String
    let categoryName: String
    let title: String
    let venue: String
    let tint: Color
    let isTheater: Bool
    let isLive: Bool
    @ViewBuilder let artwork: Artwork

    init(
        date: Date,
        timeText: String = "",
        categoryName: String,
        title: String,
        venue: String,
        tint: Color,
        isTheater: Bool,
        isLive: Bool = false,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.date = date
        self.timeText = timeText
        self.categoryName = categoryName
        self.title = title
        self.venue = venue
        self.tint = tint
        self.isTheater = isTheater
        self.isLive = isLive
        self.artwork = artwork()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 0) {
                Text(FavorecoDateText.monthDay(date))
                    .font(FavorecoTypography.latinDisplay(24, weight: .semibold, relativeTo: .title2))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(FavorecoDateText.weekdayName(date))
                    .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                    .lineLimit(1)

                if !timeText.isEmpty {
                    Text(timeText)
                        .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(primaryTextColor)
            .frame(width: 50)

            artwork
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Text(title)
                    .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)

                if !venue.isEmpty {
                    Text(venue)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isTheater || isLive ? 0.42 : 0.20), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityScheduleText)、\(categoryName)、\(title)、\(venue)")
    }

    private var accessibilityScheduleText: String {
        let dateText = FavorecoDateText.compactDate(date)
        return timeText.isEmpty ? dateText : "\(dateText)、\(timeText)"
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return .primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.62) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.58) }
        return .secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.82)
    }
}
