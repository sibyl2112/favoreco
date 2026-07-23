import Foundation

enum PersonMasterSuggestion {
    static func matching(
        _ people: [PersonMaster],
        query: String,
        allowsOrganizations: Bool = true,
        limit: Int = 4
    ) -> [PersonMaster] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty, limit > 0 else { return [] }

        return people
            .filter { !$0.isArchived && (allowsOrganizations || !$0.isOrganization) }
            .compactMap { person -> (person: PersonMaster, score: Int)? in
                guard let score = matchScore(person, normalizedQuery: normalizedQuery) else { return nil }
                return (person, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.person.displayName.localizedStandardCompare(rhs.person.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map(\.person)
    }

    static func matches(_ person: PersonMaster, query: String) -> Bool {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return true }
        return matchScore(person, normalizedQuery: normalizedQuery) != nil
    }

    static func exactMatch(
        in people: [PersonMaster],
        query: String,
        entityKind: PersonEntityKind? = nil
    ) -> PersonMaster? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }
        return people
            .filter { person in
                !person.isArchived && entityKind.map { person.entityKind == $0 } ?? true
            }
            .first { searchableTerms(for: $0).contains(normalizedQuery) }
    }

    static func subtitle(for person: PersonMaster) -> String {
        let reading = person.reading.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reading.isEmpty { return reading }
        return aliases(for: person).first ?? "登録済みの人物・団体"
    }

    nonisolated static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
    }

    private static func matchScore(_ person: PersonMaster, normalizedQuery: String) -> Int? {
        let name = normalize(person.displayName)
        let reading = normalize(person.reading)
        let aliasTerms = aliases(for: person).map(normalize)

        if name == normalizedQuery { return 0 }
        if aliasTerms.contains(normalizedQuery) { return 1 }
        if reading == normalizedQuery { return 2 }
        if name.hasPrefix(normalizedQuery) { return 3 }
        if reading.hasPrefix(normalizedQuery) { return 4 }
        if aliasTerms.contains(where: { $0.hasPrefix(normalizedQuery) }) { return 5 }
        if name.contains(normalizedQuery) { return 6 }
        if reading.contains(normalizedQuery) { return 7 }
        if aliasTerms.contains(where: { $0.contains(normalizedQuery) }) { return 8 }
        return nil
    }

    private static func searchableTerms(for person: PersonMaster) -> [String] {
        [normalize(person.displayName), normalize(person.reading)]
            + aliases(for: person).map(normalize)
    }

    private static func aliases(for person: PersonMaster) -> [String] {
        person.aliasesRaw
            .components(separatedBy: CharacterSet(charactersIn: ",、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
