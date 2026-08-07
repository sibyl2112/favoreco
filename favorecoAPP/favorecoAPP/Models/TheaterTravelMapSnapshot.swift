import Foundation

struct TheaterTravelMapPoint: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let visitCount: Int
}

struct TheaterTravelMapVenue: Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

struct TheaterTravelMapSnapshot {
    let points: [TheaterTravelMapPoint]
    let missingCoordinateCount: Int
    let totalVisitCount: Int
    let totalVenueCount: Int

    @MainActor
    static func make(
        visits: [Visit],
        venues: [TheaterTravelMapVenue] = [],
        missingVenueCoordinateCount: Int = 0
    ) -> TheaterTravelMapSnapshot {
        let locatedVisits = visits.compactMap(LocatedVisit.init)
        var points = Dictionary(grouping: locatedVisits, by: \.groupingKey)
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
        for venue in venues {
            let normalizedVenueName = normalizedVenueKey(venue.name)
            let alreadyIncluded = points.contains { point in
                normalizedVenueKey(point.name) == normalizedVenueName
                    || coordinatesAreNearby(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        otherLatitude: venue.latitude,
                        otherLongitude: venue.longitude
                    )
            }
            guard !alreadyIncluded else { continue }
            points.append(
                TheaterTravelMapPoint(
                    id: "venue-\(venue.id)",
                    name: venue.name,
                    latitude: venue.latitude,
                    longitude: venue.longitude,
                    visitCount: 0
                )
            )
        }

        points.sort { lhs, rhs in
            if lhs.visitCount != rhs.visitCount { return lhs.visitCount > rhs.visitCount }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return TheaterTravelMapSnapshot(
            points: points,
            missingCoordinateCount: visits.count - locatedVisits.count + missingVenueCoordinateCount,
            totalVisitCount: visits.count,
            totalVenueCount: venues.count + missingVenueCoordinateCount
        )
    }

    func mergingVisitSnapshot(_ visitSnapshot: TheaterTravelMapSnapshot) -> TheaterTravelMapSnapshot {
        var mergedPoints = visitSnapshot.points
        for venuePoint in points {
            let normalizedVenueName = Self.normalizedVenueKey(venuePoint.name)
            let alreadyIncluded = mergedPoints.contains { point in
                Self.normalizedVenueKey(point.name) == normalizedVenueName
                    || Self.coordinatesAreNearby(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        otherLatitude: venuePoint.latitude,
                        otherLongitude: venuePoint.longitude
                    )
            }
            guard !alreadyIncluded else { continue }
            mergedPoints.append(venuePoint)
        }
        mergedPoints.sort { lhs, rhs in
            if lhs.visitCount != rhs.visitCount { return lhs.visitCount > rhs.visitCount }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return TheaterTravelMapSnapshot(
            points: mergedPoints,
            missingCoordinateCount: visitSnapshot.missingCoordinateCount + missingCoordinateCount,
            totalVisitCount: visitSnapshot.totalVisitCount,
            totalVenueCount: totalVenueCount
        )
    }

    private static func normalizedVenueKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
    }

    private static func coordinatesAreNearby(
        latitude: Double,
        longitude: Double,
        otherLatitude: Double,
        otherLongitude: Double
    ) -> Bool {
        abs(latitude - otherLatitude) < 0.003
            && abs(longitude - otherLongitude) < 0.003
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
