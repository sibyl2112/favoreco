import Foundation

struct TheaterFocusPersonStat: Identifiable {
    let id: UUID
    let name: String
    let eventCount: Int
    let visitCount: Int
    let latestVisitedAt: Date
}

enum TheaterFocusPersonAnalytics {
    static let roleKey = "theater_focus"

    static func make(
        people: [PersonMaster],
        links: [EventPersonLink],
        visits: [Visit]
    ) -> [TheaterFocusPersonStat] {
        let activePeopleByID = Dictionary(
            uniqueKeysWithValues: people
                .filter { !$0.isArchived && !$0.isOrganization }
                .map { ($0.id, $0) }
        )
        let theaterVisitsByID = Dictionary(
            uniqueKeysWithValues: visits
                .filter {
                    $0.event?.isArchived != true
                        && $0.event?.category?.templateKey == "theater"
                }
                .map { ($0.id, $0) }
        )

        var visitIDsByPerson: [UUID: Set<UUID>] = [:]
        var eventIDsByPerson: [UUID: Set<UUID>] = [:]
        var latestVisitedAtByPerson: [UUID: Date] = [:]

        for link in links where !link.isArchived && link.roleKey == roleKey {
            guard let personID = link.person?.id,
                  activePeopleByID[personID] != nil,
                  let visitID = link.visit?.id,
                  let visit = theaterVisitsByID[visitID] else { continue }

            visitIDsByPerson[personID, default: []].insert(visitID)
            if let eventID = visit.event?.id {
                eventIDsByPerson[personID, default: []].insert(eventID)
            }
            latestVisitedAtByPerson[personID] = max(
                latestVisitedAtByPerson[personID] ?? .distantPast,
                visit.visitedAt
            )
        }

        return activePeopleByID.compactMap { personID, person in
            guard let visitIDs = visitIDsByPerson[personID], !visitIDs.isEmpty else { return nil }
            return TheaterFocusPersonStat(
                id: personID,
                name: person.displayName,
                eventCount: eventIDsByPerson[personID]?.count ?? 0,
                visitCount: visitIDs.count,
                latestVisitedAt: latestVisitedAtByPerson[personID] ?? .distantPast
            )
        }
        .sorted {
            if $0.visitCount != $1.visitCount { return $0.visitCount > $1.visitCount }
            if $0.latestVisitedAt != $1.latestVisitedAt { return $0.latestVisitedAt > $1.latestVisitedAt }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

struct TheaterOrganizationStat: Identifiable {
    let id: UUID
    let name: String
    let directEventCount: Int
    let eventCount: Int
    let visitCount: Int

    var includesChildOrganizations: Bool { eventCount > directEventCount }
}

enum TheaterOrganizationAnalytics {
    static let includedRoleKeys: Set<String> = [
        "performing_organization", "organizer", "production", "planning", "presenter",
    ]

    static func make(
        people: [PersonMaster],
        links: [EventPersonLink],
        visits: [Visit]
    ) -> [TheaterOrganizationStat] {
        let organizations = people.filter { !$0.isArchived && $0.isOrganization }
        let organizationsByID = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0) })
        let theaterVisits = visits.filter {
            $0.event?.isArchived != true && $0.event?.category?.templateKey == "theater"
        }
        let visitsByEventID = Dictionary(grouping: theaterVisits) { $0.event?.id }

        var directEventIDsByOrganization: [UUID: Set<UUID>] = [:]
        var eventIDsByOrganization: [UUID: Set<UUID>] = [:]
        var visitIDsByOrganization: [UUID: Set<UUID>] = [:]

        for link in links where !link.isArchived && includedRoleKeys.contains(link.roleKey) {
            guard let eventID = link.event?.id,
                  let organizationID = link.person?.id,
                  organizationsByID[organizationID] != nil,
                  let eventVisits = visitsByEventID[eventID],
                  !eventVisits.isEmpty else { continue }

            directEventIDsByOrganization[organizationID, default: []].insert(eventID)
            for rollupID in rollupIDs(from: organizationID, organizationsByID: organizationsByID) {
                eventIDsByOrganization[rollupID, default: []].insert(eventID)
                visitIDsByOrganization[rollupID, default: []].formUnion(eventVisits.map(\.id))
            }
        }

        return organizations.compactMap { organization in
            let visitCount = visitIDsByOrganization[organization.id]?.count ?? 0
            guard visitCount > 0 else { return nil }
            return TheaterOrganizationStat(
                id: organization.id,
                name: organization.displayName,
                directEventCount: directEventIDsByOrganization[organization.id]?.count ?? 0,
                eventCount: eventIDsByOrganization[organization.id]?.count ?? 0,
                visitCount: visitCount
            )
        }
        .sorted {
            if $0.visitCount != $1.visitCount { return $0.visitCount > $1.visitCount }
            if $0.eventCount != $1.eventCount { return $0.eventCount > $1.eventCount }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func rollupIDs(
        from organizationID: UUID,
        organizationsByID: [UUID: PersonMaster]
    ) -> [UUID] {
        var result: [UUID] = []
        var visited = Set<UUID>()
        var currentID: UUID? = organizationID
        while let id = currentID, visited.insert(id).inserted {
            result.append(id)
            currentID = organizationsByID[id]?.parentOrganizationID
        }
        return result
    }
}
