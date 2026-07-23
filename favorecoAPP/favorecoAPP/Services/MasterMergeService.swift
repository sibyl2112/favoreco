import Foundation
import SwiftData

enum MasterMergeService {
    @MainActor
    static func merge(person source: PersonMaster, into destination: PersonMaster, in context: ModelContext) throws {
        guard source.id != destination.id else { return }
        let now = Date()
        let destinationLinks = Array(destination.eventLinks ?? [])
        let allPeople = try context.fetch(FetchDescriptor<PersonMaster>())

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
        if destination.entityKindKey.isEmpty || source.isOrganization {
            destination.entityKind = source.entityKind
        }
        if destination.parentOrganizationID == nil,
           let sourceParentID = source.parentOrganizationID,
           sourceParentID != destination.id {
            destination.parentOrganizationID = sourceParentID
        }
        for person in allPeople where person.id != destination.id && person.parentOrganizationID == source.id {
            person.parentOrganizationID = destination.id
            person.updatedAt = now
        }
        destination.aliasesRaw = mergedTerms(destination.aliasesRaw, source.aliasesRaw, source.displayName)
        destination.roleTagsRaw = mergedTerms(destination.roleTagsRaw, source.roleTagsRaw)
        destination.memo = preferred(destination.memo, fallback: source.memo)
        destination.officialURL = preferred(destination.officialURL, fallback: source.officialURL)
        destination.socialLinksRaw = preferred(destination.socialLinksRaw, fallback: source.socialLinksRaw)
        destination.imagePath = preferred(destination.imagePath, fallback: source.imagePath)
        if destination.imageData == nil {
            destination.imageData = source.imageData
        }
        destination.musicBrainzID = preferred(destination.musicBrainzID, fallback: source.musicBrainzID)
        destination.wikidataQID = preferred(destination.wikidataQID, fallback: source.wikidataQID)
        destination.appleMusicID = preferred(destination.appleMusicID, fallback: source.appleMusicID)
        destination.sourceSnapshotRaw = preferred(destination.sourceSnapshotRaw, fallback: source.sourceSnapshotRaw)
        mergeFavoriteProfile(from: source, into: destination, at: now, in: context)
        mergeFavoPins(from: source, into: destination, at: now, in: context)
        destination.updatedAt = now

        source.isArchived = true
        source.updatedAt = now
        try context.save()
    }

    @MainActor
    private static func mergeFavoPins(
        from source: PersonMaster,
        into destination: PersonMaster,
        at now: Date,
        in context: ModelContext
    ) {
        var destinationHasPin = (destination.favoPins ?? []).contains { $0.targetKind == .person }
        for pin in Array(source.favoPins ?? []) where pin.targetKind == .person {
            if destinationHasPin {
                context.delete(pin)
            } else {
                pin.person = destination
                pin.updatedAt = now
                destinationHasPin = true
            }
        }
    }

    @MainActor
    private static func mergeFavoriteProfile(
        from source: PersonMaster,
        into destination: PersonMaster,
        at now: Date,
        in context: ModelContext
    ) {
        guard let sourceProfile = source.favoriteProfile else { return }
        guard let destinationProfile = destination.favoriteProfile else {
            sourceProfile.person = destination
            sourceProfile.updatedAt = now
            return
        }

        destinationProfile.isFavorite = destinationProfile.isFavorite || sourceProfile.isFavorite
        destinationProfile.isPrimary = destinationProfile.isPrimary || sourceProfile.isPrimary
        destinationProfile.isPinned = destinationProfile.isPinned || sourceProfile.isPinned
        if !destinationProfile.hasStartedAt, sourceProfile.hasStartedAt {
            destinationProfile.startedAt = sourceProfile.startedAt
            destinationProfile.hasStartedAt = true
            destinationProfile.includesStartDay = sourceProfile.includesStartDay
        }
        destinationProfile.colorHex = preferred(destinationProfile.colorHex, fallback: sourceProfile.colorHex)
        destinationProfile.nickname = preferred(destinationProfile.nickname, fallback: sourceProfile.nickname)
        destinationProfile.imagePath = preferred(destinationProfile.imagePath, fallback: sourceProfile.imagePath)
        if destinationProfile.heroImageData == nil {
            destinationProfile.heroImageData = sourceProfile.heroImageData
        }
        if destinationProfile.iconImageData == nil {
            destinationProfile.iconImageData = sourceProfile.iconImageData
        }
        destinationProfile.originText = preferred(destinationProfile.originText, fallback: sourceProfile.originText)
        destinationProfile.memo = preferred(destinationProfile.memo, fallback: sourceProfile.memo)
        destinationProfile.showOnHome = destinationProfile.showOnHome || sourceProfile.showOnHome
        mergeGalleryPhotos(from: sourceProfile, into: destinationProfile, at: now)
        mergeAnniversaries(from: sourceProfile, into: destinationProfile, at: now)
        destinationProfile.updatedAt = now
        context.delete(sourceProfile)
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
        destination.prefecture = preferred(destination.prefecture, fallback: source.prefecture)
        if destination.prefecture.isEmpty {
            destination.prefecture = JapanPrefecture.extract(from: preferred(destination.address, fallback: source.address))
        }
        destination.address = preferred(destination.address, fallback: source.address)
        if destination.latitude == 0, destination.longitude == 0 {
            destination.latitude = source.latitude
            destination.longitude = source.longitude
        }
        destination.officialURL = preferred(destination.officialURL, fallback: source.officialURL)
        destination.memo = preferred(destination.memo, fallback: source.memo)
        destination.externalIDsRaw = preferred(destination.externalIDsRaw, fallback: source.externalIDsRaw)
        destination.sourceSnapshotRaw = preferred(destination.sourceSnapshotRaw, fallback: source.sourceSnapshotRaw)
        destination.pilgrimageMembershipsRaw = PlacePilgrimageMembership.merged(
            destination.pilgrimageMembershipsRaw,
            source.pilgrimageMembershipsRaw
        )
        destination.operationalStatusRaw = preferred(
            destination.operationalStatusRaw,
            fallback: source.operationalStatusRaw
        )
        destination.normalizedAddress = preferred(destination.normalizedAddress, fallback: source.normalizedAddress)
        mergeFavoriteProfile(from: source, into: destination, at: now, in: context)
        mergeFavoPins(from: source, into: destination, at: now, in: context)
        destination.updatedAt = now

        source.isArchived = true
        source.updatedAt = now
        try context.save()
    }

    @MainActor
    private static func mergeFavoriteProfile(
        from source: PlaceMaster,
        into destination: PlaceMaster,
        at now: Date,
        in context: ModelContext
    ) {
        guard let sourceProfile = source.favoriteProfile else { return }
        guard let destinationProfile = destination.favoriteProfile else {
            sourceProfile.place = destination
            sourceProfile.updatedAt = now
            return
        }

        destinationProfile.colorHex = preferred(destinationProfile.colorHex, fallback: sourceProfile.colorHex)
        destinationProfile.nickname = preferred(destinationProfile.nickname, fallback: sourceProfile.nickname)
        destinationProfile.originText = preferred(destinationProfile.originText, fallback: sourceProfile.originText)
        destinationProfile.memo = preferred(destinationProfile.memo, fallback: sourceProfile.memo)
        if destinationProfile.heroImageData == nil { destinationProfile.heroImageData = sourceProfile.heroImageData }
        if destinationProfile.iconImageData == nil { destinationProfile.iconImageData = sourceProfile.iconImageData }
        mergeGalleryPhotos(from: sourceProfile, into: destinationProfile, at: now)
        mergeAnniversaries(from: sourceProfile, into: destinationProfile, at: now)
        destinationProfile.updatedAt = now
        context.delete(sourceProfile)
    }

    @MainActor
    private static func mergeGalleryPhotos(
        from source: FavoriteProfile,
        into destination: FavoriteProfile,
        at now: Date
    ) {
        var nextSortOrder = (destination.galleryPhotos ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let destinationHasFavorite = (destination.galleryPhotos ?? []).contains(where: \.isFavorite)
        var keepsSourceFavorite = !destinationHasFavorite
        for photo in (source.galleryPhotos ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            photo.profile = destination
            photo.sortOrder = nextSortOrder
            if photo.isFavorite {
                photo.isFavorite = keepsSourceFavorite
                keepsSourceFavorite = false
            }
            photo.updatedAt = now
            nextSortOrder += 1
        }
    }

    @MainActor
    private static func mergeAnniversaries(
        from source: FavoriteProfile,
        into destination: FavoriteProfile,
        at now: Date
    ) {
        var nextSortOrder = (destination.anniversaries ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        for anniversary in (source.anniversaries ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            anniversary.profile = destination
            anniversary.sortOrder = nextSortOrder
            anniversary.updatedAt = now
            nextSortOrder += 1
        }
    }

    @MainActor
    private static func mergeFavoPins(
        from source: PlaceMaster,
        into destination: PlaceMaster,
        at now: Date,
        in context: ModelContext
    ) {
        var destinationHasPin = (destination.favoPins ?? []).contains { $0.targetKind == .place }
        for pin in Array(source.favoPins ?? []) where pin.targetKind == .place {
            if destinationHasPin {
                context.delete(pin)
            } else {
                pin.place = destination
                pin.updatedAt = now
                destinationHasPin = true
            }
        }
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
