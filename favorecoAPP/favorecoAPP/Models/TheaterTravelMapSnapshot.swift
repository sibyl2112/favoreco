import Foundation

struct TheaterTravelMapPoint: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let visitCount: Int
}

struct TheaterTravelMapSnapshot {
    let points: [TheaterTravelMapPoint]
    let missingCoordinateCount: Int
    let totalVisitCount: Int

    @MainActor
    static func make(visits: [Visit]) -> TheaterTravelMapSnapshot {
        let locatedVisits = visits.compactMap(LocatedVisit.init)
        let points = Dictionary(grouping: locatedVisits, by: \.groupingKey)
            .map { key, grouped in
                let first = grouped[0]
                return TheaterTravelMapPoint(
                    id: key,
                    name: first.name,
                    latitude: first.latitude,
                    longitude: first.longitude,
                    visitCount: grouped.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.visitCount != rhs.visitCount { return lhs.visitCount > rhs.visitCount }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return TheaterTravelMapSnapshot(
            points: points,
            missingCoordinateCount: visits.count - locatedVisits.count,
            totalVisitCount: visits.count
        )
    }
}

private struct LocatedVisit {
    let groupingKey: String
    let name: String
    let latitude: Double
    let longitude: Double

    init?(visit: Visit) {
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        guard latitude != 0 || longitude != 0 else { return nil }

        let snapshotName = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let masterName = visit.placeMaster?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = snapshotName.isEmpty ? (masterName.isEmpty ? "会場" : masterName) : snapshotName

        if let placeID = visit.placeMaster?.id {
            groupingKey = "place-\(placeID.uuidString)"
        } else {
            let normalizedName = name
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined()
            groupingKey = String(
                format: "legacy-%@-%.3f-%.3f",
                normalizedName,
                latitude,
                longitude
            )
        }

        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
