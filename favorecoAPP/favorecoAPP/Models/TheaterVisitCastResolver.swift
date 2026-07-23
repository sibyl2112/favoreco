import Foundation

enum TheaterVisitCastResolver {
    private static let inheritedMemoPrefix = "favoreco:inherited-event-cast:"
    static let castRoleKeys: Set<String> = [
        "actor", "artist", "cast", "lead", "performer", "guest", "replacement", "daily_guest",
    ]

    static func isCastLink(_ link: EventPersonLink) -> Bool {
        if castRoleKeys.contains(link.roleKey) { return true }
        let role = link.displayRole
        return role.contains("出演")
            || role.contains("主演")
            || role.contains("キャスト")
            || role.contains("俳優")
            || role.contains("代役")
    }

    static func actualCastLinks(
        eventLinks: [EventPersonLink],
        visitLinks: [EventPersonLink],
        excludedEventLinkIDs: Set<UUID>,
        usesVisitSnapshot: Bool = false
    ) -> [EventPersonLink] {
        let inheritedCast = (usesVisitSnapshot ? visitLinks : eventLinks)
            .filter { !$0.isArchived && isCastLink($0) && !excludedEventLinkIDs.contains($0.id) }
            .filter { usesVisitSnapshot ? isInheritedSnapshotLink($0) : true }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
        let visitSpecificCast = visitLinks
            .filter { !$0.isArchived && isCastLink($0) && !isInheritedSnapshotLink($0) }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }

        var result: [EventPersonLink] = []
        var seen: Set<String> = []
        let visitSpecificByIdentity = Dictionary(
            visitSpecificCast.map { (identityKey(for: $0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for inheritedLink in inheritedCast {
            let key = identityKey(for: inheritedLink)
            guard seen.insert(key).inserted else { continue }
            result.append(visitSpecificByIdentity[key] ?? inheritedLink)
        }
        for link in visitSpecificCast where seen.insert(identityKey(for: link)).inserted {
            result.append(link)
        }
        return result
    }

    static func resolvedLinks(
        eventLinks: [EventPersonLink],
        visitLinks: [EventPersonLink],
        excludedEventLinkIDs: Set<UUID>,
        usesVisitSnapshot: Bool = false
    ) -> [EventPersonLink] {
        let cast = actualCastLinks(
            eventLinks: eventLinks,
            visitLinks: visitLinks,
            excludedEventLinkIDs: excludedEventLinkIDs,
            usesVisitSnapshot: usesVisitSnapshot
        )
        let otherLinks = (eventLinks + visitLinks)
            .filter { !$0.isArchived && !isCastLink($0) }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }

        var seen = Set<String>()
        return (cast + otherLinks).filter { link in
            seen.insert("\(identityKey(for: link))|\(link.roleKey)|\(link.displayRole)").inserted
        }
    }

    static func personName(for link: EventPersonLink) -> String {
        let snapshot = link.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshot.isEmpty { return snapshot }
        return link.person?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func isInheritedSnapshotLink(_ link: EventPersonLink) -> Bool {
        link.memo.hasPrefix(inheritedMemoPrefix)
    }

    static func sourceEventLinkID(for link: EventPersonLink) -> UUID? {
        guard isInheritedSnapshotLink(link) else { return nil }
        return UUID(uuidString: String(link.memo.dropFirst(inheritedMemoPrefix.count)))
    }

    static func makeInheritedSnapshotLink(
        from eventLink: EventPersonLink,
        visit: Visit,
        sortOrder: Int
    ) -> EventPersonLink {
        EventPersonLink(
            roleKey: eventLink.roleKey,
            displayRole: eventLink.displayRole,
            sortOrder: sortOrder,
            nameSnapshot: personName(for: eventLink),
            memo: inheritedMemoPrefix + eventLink.id.uuidString,
            person: eventLink.person,
            visit: visit
        )
    }

    private static func identityKey(for link: EventPersonLink) -> String {
        if let personID = link.person?.id {
            return "person:\(personID.uuidString)"
        }
        return "name:\(normalizedPersonName(personName(for: link)))"
    }

}
