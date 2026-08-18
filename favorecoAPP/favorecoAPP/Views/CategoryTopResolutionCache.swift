//
//  CategoryTopResolutionCache.swift
//  favorecoAPP
//

import Foundation

@MainActor
final class CategoryTopResolutionCache {
    private var visitIDs: [UUID] = []
    private var visits: [Visit] = []
    private var categoryID: UUID?
    private var eventIDs: [UUID] = []
    private var events: [ExperienceEvent] = []
    private var eventsByID: [UUID: ExperienceEvent] = [:]

    func resolvedVisits(snapshot: CategoryTopSnapshot, allVisits: [Visit]) -> [Visit] {
        guard visitIDs != snapshot.visitIDs else { return visits }
        let idSet = Set(snapshot.visitIDs)
        visitIDs = snapshot.visitIDs
        visits = allVisits.filter { idSet.contains($0.id) }
        return visits
    }

    func resolvedEvents(
        snapshot: CategoryTopSnapshot,
        category: RecordCategory
    ) -> [ExperienceEvent] {
        let nextEventIDs = snapshot.events.map(\.id)
        guard categoryID != category.id || eventIDs != nextEventIDs else { return events }
        let categoryEventsByID = Dictionary(
            (category.events ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        categoryID = category.id
        eventIDs = nextEventIDs
        events = nextEventIDs.compactMap { categoryEventsByID[$0] }
        eventsByID = Dictionary(
            events.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        return events
    }

    func resolvedEventsByID(
        snapshot: CategoryTopSnapshot,
        category: RecordCategory
    ) -> [UUID: ExperienceEvent] {
        _ = resolvedEvents(snapshot: snapshot, category: category)
        return eventsByID
    }
}
