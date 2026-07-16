import Foundation

struct EventDetailSnapshot {
    let visits: [Visit]
    let representativePhoto: PhotoBlob?
    let hasPhotos: Bool
    let eventTitle: String
    let latestVisitText: String
    let averageRatingText: String

    var visitCount: Int { visits.count }

    static func make(event: ExperienceEvent) -> EventDetailSnapshot {
        let visits = (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
        let photoResolution = EventRepresentativePhotoResolver.resolve(
            for: event,
            sortedVisits: visits
        )
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        let averageRatingText: String
        if ratedVisits.isEmpty {
            averageRatingText = "-"
        } else {
            let total = ratedVisits.reduce(0) { $0 + $1.overallRating }
            averageRatingText = String(format: "%.1f", total / Double(ratedVisits.count))
        }

        return EventDetailSnapshot(
            visits: visits,
            representativePhoto: photoResolution.photo,
            hasPhotos: !photoResolution.photos.isEmpty,
            eventTitle: event.title.isEmpty ? "記録" : event.title,
            latestVisitText: visits.first.map { FavorecoDateText.compactDate($0.visitedAt) } ?? "-",
            averageRatingText: averageRatingText
        )
    }
}
