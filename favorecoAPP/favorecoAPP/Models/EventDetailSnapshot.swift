import Foundation

struct EventDetailMemoryPhoto: Identifiable {
    let photo: PhotoBlob
    let visit: Visit

    var id: UUID { photo.id }
}

struct EventDetailSnapshot {
    let visits: [Visit]
    let representativePhoto: PhotoBlob?
    let hasPhotos: Bool
    let castLinks: [EventPersonLink]
    let staffLinks: [EventPersonLink]
    let memoryPhotos: [EventDetailMemoryPhoto]
    let eventTitle: String
    let firstVisitText: String
    let latestVisitText: String
    let averageRatingText: String

    var visitCount: Int { visits.count }

    static func make(event: ExperienceEvent) -> EventDetailSnapshot {
        let visits = (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
        let photoResolution = EventRepresentativePhotoResolver.resolve(
            for: event,
            sortedVisits: visits
        )
        let people = deduplicatedPeople(in: event)
        let castLinks = people.filter { isTheaterCastLink($0) }
        let staffLinks = people.filter { !isTheaterCastLink($0) }
        let memoryPhotos = visits.flatMap { visit in
            (visit.photos ?? [])
                .filter {
                    $0.mediaKind == "photo"
                        && $0.hasStoredData
                        && ExperiencePhotoPurpose.resolved(from: $0.purpose) == .memory
                }
                .sorted { $0.createdAt < $1.createdAt }
                .map { EventDetailMemoryPhoto(photo: $0, visit: visit) }
        }
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
            castLinks: castLinks,
            staffLinks: staffLinks,
            memoryPhotos: memoryPhotos,
            eventTitle: event.title.isEmpty ? "記録" : event.title,
            firstVisitText: visits.last.map { FavorecoDateText.compactDate($0.visitedAt) } ?? "-",
            latestVisitText: visits.first.map { FavorecoDateText.compactDate($0.visitedAt) } ?? "-",
            averageRatingText: averageRatingText
        )
    }

    private static func deduplicatedPeople(in event: ExperienceEvent) -> [EventPersonLink] {
        let sortedLinks = (event.personLinks ?? [])
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }

        var seen = Set<String>()
        return sortedLinks.filter { link in
            let name = personName(for: link)
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let role = link.displayRole.isEmpty ? link.roleKey : link.displayRole
            let key = "\(name)|\(role)"
            return !name.isEmpty && seen.insert(key).inserted
        }
    }

    private static func isTheaterCastLink(_ link: EventPersonLink) -> Bool {
        let castRoleKeys: Set<String> = ["actor", "cast", "lead", "artist", "performer", "guest"]
        if castRoleKeys.contains(link.roleKey) { return true }
        let role = link.displayRole
        return role.contains("出演")
            || role.contains("主演")
            || role.contains("キャスト")
            || role.contains("俳優")
    }

    private static func personName(for link: EventPersonLink) -> String {
        let snapshotName = link.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshotName.isEmpty { return snapshotName }
        return link.person?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
