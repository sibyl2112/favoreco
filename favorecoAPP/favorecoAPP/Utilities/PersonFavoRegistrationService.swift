import Foundation
import SwiftData

struct PersonFavoRegistrationResult {
    let profile: FavoriteProfile
    let pin: FavoPin
    let createdProfile: Bool
    let createdPin: Bool
}

enum PersonFavoRegistrationError: LocalizedError {
    case pinLimitReached

    var errorDescription: String? {
        switch self {
        case .pinLimitReached:
            "MY FAVOは最大4件です。先に1件外してください。"
        }
    }
}

enum PersonFavoRegistrationService {
    @MainActor
    static func ensureRegistered(
        person: PersonMaster,
        preferredSortOrder: Int,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> PersonFavoRegistrationResult {
        let pins = try context.fetch(FetchDescriptor<FavoPin>())
        let existingPin = pins.first {
            $0.targetKind == .person && $0.person?.id == person.id
        }

        if let existingPin {
            let (profile, createdProfile) = ensureProfile(
                for: person,
                in: context,
                now: now
            )
            do {
                try context.save()
                return PersonFavoRegistrationResult(
                    profile: profile,
                    pin: existingPin,
                    createdProfile: createdProfile,
                    createdPin: false
                )
            } catch {
                context.rollback()
                throw error
            }
        }

        let activePins = pins.filter(\.isValid)
        guard activePins.count < 4 else {
            throw PersonFavoRegistrationError.pinLimitReached
        }

        let (profile, createdProfile) = ensureProfile(
            for: person,
            in: context,
            now: now
        )
        let occupiedSortOrders = Set(activePins.map(\.sortOrder))
        let requestedSortOrder = max(0, preferredSortOrder)
        let resolvedSortOrder: Int
        if !occupiedSortOrders.contains(requestedSortOrder) {
            resolvedSortOrder = requestedSortOrder
        } else {
            resolvedSortOrder = (0..<4).first { !occupiedSortOrders.contains($0) } ?? activePins.count
        }

        let pin = FavoPin(
            targetKindKey: FavoTargetKind.person.rawValue,
            sortOrder: resolvedSortOrder,
            createdAt: now,
            updatedAt: now,
            person: person
        )
        context.insert(pin)
        do {
            try context.save()
            return PersonFavoRegistrationResult(
                profile: profile,
                pin: pin,
                createdProfile: createdProfile,
                createdPin: true
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func ensureProfile(
        for person: PersonMaster,
        in context: ModelContext,
        now: Date
    ) -> (profile: FavoriteProfile, created: Bool) {
        let profile: FavoriteProfile
        let createdProfile: Bool
        if let existingProfile = person.favoriteProfile {
            profile = existingProfile
            createdProfile = false
        } else {
            profile = FavoriteProfile(
                isFavorite: true,
                createdAt: now,
                updatedAt: now,
                person: person
            )
            context.insert(profile)
            createdProfile = true
        }
        profile.isFavorite = true
        profile.updatedAt = now
        return (profile, createdProfile)
    }
}
