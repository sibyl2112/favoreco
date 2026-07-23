import Foundation

struct CategoryTopSnapshot {
    let visibleCategoryIDs: [UUID]
    let events: [CategoryEventSnapshot]
    let visitIDs: [UUID]

    var eventCount: Int { events.count }
    var visitCount: Int { visitIDs.count }
    var interestedEventCount: Int {
        events.lazy.filter { $0.stateKey == "interested" }.count
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
            visibleCategoryIDs: visibleCategories.map(\.id),
            events: eventSnapshots,
            visitIDs: visits.map(\.id)
        )
    }
}

struct CategoryEventSnapshot: Identifiable {
    let id: UUID
    let title: String
    let stateKey: String
    let visitCount: Int
    let latestVisitDate: Date?

    init(event: ExperienceEvent, visitCount: Int, latestVisitDate: Date?) {
        id = event.id
        title = event.title
        stateKey = event.stateKey
        self.visitCount = visitCount
        self.latestVisitDate = latestVisitDate
    }
}
