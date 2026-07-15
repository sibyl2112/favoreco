import Foundation

struct CategoryTopSnapshot {
    let visibleCategories: [RecordCategory]
    let events: [CategoryEventSnapshot]
    let visits: [Visit]

    var eventCount: Int { events.count }
    var visitCount: Int { visits.count }
    var interestedEventCount: Int {
        events.lazy.filter { $0.event.stateKey == "interested" }.count
    }

    static func make(
        category: RecordCategory,
        categories: [RecordCategory],
        visits allVisits: [Visit]
    ) -> CategoryTopSnapshot {
        let visibleCategories = categories.filter { !$0.isArchived }
        let categoryEvents = (category.events ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
        let eventIDs = Set(categoryEvents.map(\.id))
        let visits = allVisits.filter { visit in
            guard let eventID = visit.event?.id else { return false }
            return eventIDs.contains(eventID)
        }
        let eventSnapshots = categoryEvents.map { event in
            let eventVisits = event.visits ?? []
            return CategoryEventSnapshot(
                event: event,
                visitCount: eventVisits.count,
                latestVisitDate: eventVisits.map(\.visitedAt).max()
            )
        }

        return CategoryTopSnapshot(
            visibleCategories: visibleCategories,
            events: eventSnapshots,
            visits: visits
        )
    }
}

struct CategoryEventSnapshot: Identifiable {
    let event: ExperienceEvent
    let visitCount: Int
    let latestVisitDate: Date?

    var id: UUID { event.id }
}
