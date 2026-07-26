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
        var visitIDs: [UUID] = []
        var visitStatsByEventID: [UUID: (count: Int, latestDate: Date?)] = [:]
        for visit in allVisits {
            guard let eventID = visit.event?.id,
                  eventIDs.contains(eventID) else { continue }
            visitIDs.append(visit.id)
            var stats = visitStatsByEventID[eventID] ?? (count: 0, latestDate: nil)
            stats.count += 1
            if stats.latestDate == nil || visit.visitedAt > stats.latestDate! {
                stats.latestDate = visit.visitedAt
            }
            visitStatsByEventID[eventID] = stats
        }
        let eventSnapshots = categoryEvents.map { event in
            let stats = visitStatsByEventID[event.id]
            return CategoryEventSnapshot(
                event: event,
                visitCount: stats?.count ?? 0,
                latestVisitDate: stats?.latestDate
            )
        }

        return CategoryTopSnapshot(
            visibleCategoryIDs: visibleCategories.map(\.id),
            events: eventSnapshots,
            visitIDs: visitIDs
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
