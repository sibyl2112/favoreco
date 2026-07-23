import Foundation

enum PersonEntityKind: String, CaseIterable, Identifiable {
    case person
    case organization

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .person: "人物"
        case .organization: "団体"
        }
    }
}

extension PersonMaster {
    var entityKind: PersonEntityKind {
        get {
            if let stored = PersonEntityKind(rawValue: entityKindKey) {
                return stored
            }
            return PersonActivityTags.selectedPresetIDs(from: roleTagsRaw).isDisjoint(with: [
                "theater_company", "production_company", "talent_agency", "publisher", "organizer", "band", "brewery",
            ]) ? .person : .organization
        }
        set { entityKindKey = newValue.rawValue }
    }

    var isOrganization: Bool { entityKind == .organization }

    var parentOrganizationID: UUID? {
        get { UUID(uuidString: parentOrganizationIDRaw) }
        set { parentOrganizationIDRaw = newValue?.uuidString ?? "" }
    }
}

func eligibleParentOrganizations(
    for childID: UUID,
    among people: [PersonMaster]
) -> [PersonMaster] {
    let organizationsByID = Dictionary(
        uniqueKeysWithValues: people
            .filter(\.isOrganization)
            .map { ($0.id, $0) }
    )

    return people.filter { candidate in
        guard !candidate.isArchived,
              candidate.isOrganization,
              candidate.id != childID else {
            return false
        }

        var currentID: UUID? = candidate.id
        var visitedIDs: Set<UUID> = []
        while let organizationID = currentID,
              visitedIDs.insert(organizationID).inserted {
            if organizationID == childID {
                return false
            }
            currentID = organizationsByID[organizationID]?.parentOrganizationID
        }
        return true
    }
}
