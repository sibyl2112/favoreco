import SwiftUI
import UIKit

enum TheaterCategoryStyle {
    static let wine = Color(red: 0.28, green: 0.035, blue: 0.08)
    static let deepWine = Color(red: 0.11, green: 0.025, blue: 0.04)
    static let black = Color(red: 0.025, green: 0.02, blue: 0.022)
    static let tileBackground = Color(red: 0.075, green: 0.045, blue: 0.05).opacity(0.94)
    static let gold = Color(red: 0.82, green: 0.62, blue: 0.30)
    static let lightGold = Color(red: 0.96, green: 0.82, blue: 0.52)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.84)

    static let brandGradient = LinearGradient(
        colors: [lightGold, Color(red: 0.70, green: 0.38, blue: 0.18), lightGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TheaterPosterView: View {
    let event: ExperienceEvent?
    let width: CGFloat

    private var representativePhoto: PhotoBlob? {
        event.flatMap { EventRepresentativePhotoResolver.photo(for: $0) }
    }

    var body: some View {
        Group {
            if let representativePhoto {
                RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 420, contentMode: .fill)
            } else if let data = event?.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    TheaterCategoryStyle.wine.opacity(0.72)
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(TheaterCategoryStyle.gold)
                }
            }
        }
        .frame(width: width, height: width * 1.414)
        .background(TheaterCategoryStyle.black)
        .clipped()
        .overlay {
            Rectangle()
                .stroke(TheaterCategoryStyle.gold.opacity(0.62), lineWidth: 0.7)
        }
    }
}
struct TheaterSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(TheaterCategoryStyle.ivory)
            Spacer()
            Text("\(count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(TheaterCategoryStyle.gold)
        }
    }
}

struct TheaterEventRow: View {
    let snapshot: CategoryEventSnapshot
    let event: ExperienceEvent
    let onAddVisit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                HStack(spacing: 13) {
                    TheaterPosterView(event: event, width: 72)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(TheaterCategoryStyle.ivory)
                            .lineLimit(2)

                        if !event.seriesName.isEmpty {
                            Text(event.seriesName)
                                .lineLimit(1)
                        }

                        HStack(spacing: 9) {
                            Label("\(snapshot.visitCount)件", systemImage: "number")
                            if let latestVisitDate = snapshot.latestVisitDate {
                                Label(FavorecoDateText.compactDate(latestVisitDate), systemImage: "calendar")
                            }
                        }
                    }
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button(action: onAddVisit) {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TheaterCategoryStyle.gold)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle().stroke(TheaterCategoryStyle.gold.opacity(0.65), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}

struct TheaterVisitRow: View {
    let visit: Visit

    private var event: ExperienceEvent? { visit.event }

    var body: some View {
        HStack(spacing: 13) {
            TheaterPosterView(event: event, width: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(event?.title.isEmpty == false ? event?.title ?? "観劇記録" : "観劇記録")
                    .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                    .lineLimit(2)

                Label(FavorecoDateText.compactDate(visit.visitedAt), systemImage: "calendar")
                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TheaterCategoryStyle.gold.opacity(0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}

struct TheaterEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TheaterCategoryStyle.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}
