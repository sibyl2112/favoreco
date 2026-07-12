import Foundation
import SwiftData

enum MasterMergeService {
    @MainActor
    static func merge(person source: PersonMaster, into destination: PersonMaster, in context: ModelContext) throws {
        guard source.id != destination.id else { return }
        let now = Date()
        let destinationLinks = Array(destination.eventLinks ?? [])

        for link in Array(source.eventLinks ?? []) {
            let isDuplicate = destinationLinks.contains { existing in
                !existing.isArchived
                    && existing.roleKey == link.roleKey
                    && existing.event?.id == link.event?.id
                    && existing.visit?.id == link.visit?.id
            }
            link.person = destination
            if isDuplicate {
                link.isArchived = true
            }
            link.updatedAt = now
        }

        destination.reading = preferred(destination.reading, fallback: source.reading)
        destination.aliasesRaw = mergedTerms(destination.aliasesRaw, source.aliasesRaw, source.displayName)
        destination.roleTagsRaw = mergedTerms(destination.roleTagsRaw, source.roleTagsRaw)
        destination.memo = preferred(destination.memo, fallback: source.memo)
        destination.officialURL = preferred(destination.officialURL, fallback: source.officialURL)
        destination.socialLinksRaw = preferred(destination.socialLinksRaw, fallback: source.socialLinksRaw)
        destination.imagePath = preferred(destination.imagePath, fallback: source.imagePath)
        destination.musicBrainzID = preferred(destination.musicBrainzID, fallback: source.musicBrainzID)
        destination.wikidataQID = preferred(destination.wikidataQID, fallback: source.wikidataQID)
        destination.appleMusicID = preferred(destination.appleMusicID, fallback: source.appleMusicID)
        destination.sourceSnapshotRaw = preferred(destination.sourceSnapshotRaw, fallback: source.sourceSnapshotRaw)
        destination.updatedAt = now

        source.isArchived = true
        source.updatedAt = now
        try context.save()
    }

    @MainActor
    static func merge(place source: PlaceMaster, into destination: PlaceMaster, in context: ModelContext) throws {
        guard source.id != destination.id else { return }
        let now = Date()

        for visit in Array(source.visits ?? []) {
            visit.placeMaster = destination
            visit.updatedAt = now
        }
        for plan in Array(source.plans ?? []) {
            plan.placeMaster = destination
            plan.updatedAt = now
        }

        destination.reading = preferred(destination.reading, fallback: source.reading)
        destination.aliasesRaw = mergedTerms(destination.aliasesRaw, source.aliasesRaw, source.name)
        destination.placeTagsRaw = mergedTerms(destination.placeTagsRaw, source.placeTagsRaw)
        destination.address = preferred(destination.address, fallback: source.address)
        if destination.latitude == 0, destination.longitude == 0 {
            destination.latitude = source.latitude
            destination.longitude = source.longitude
        }
        destination.officialURL = preferred(destination.officialURL, fallback: source.officialURL)
        destination.memo = preferred(destination.memo, fallback: source.memo)
        destination.externalIDsRaw = preferred(destination.externalIDsRaw, fallback: source.externalIDsRaw)
        destination.sourceSnapshotRaw = preferred(destination.sourceSnapshotRaw, fallback: source.sourceSnapshotRaw)
        destination.normalizedAddress = preferred(destination.normalizedAddress, fallback: source.normalizedAddress)
        destination.updatedAt = now

        source.isArchived = true
        source.updatedAt = now
        try context.save()
    }

    nonisolated private static func preferred(_ current: String, fallback: String) -> String {
        current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : current
    }

    nonisolated private static func mergedTerms(_ values: String...) -> String {
        var seen = Set<String>()
        return values
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ",、\n")) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)).inserted }
            .joined(separator: ", ")
    }
}
