import Foundation
import SwiftData

enum MovieBestPeriodKind: String, Codable, CaseIterable, Sendable {
    case monthly
    case yearly
}

struct MovieBestPeriod: Identifiable, Hashable, Sendable {
    let kind: MovieBestPeriodKind
    let year: Int
    let month: Int

    init(kind: MovieBestPeriodKind, year: Int, month: Int = 0) {
        self.kind = kind
        self.year = year
        self.month = kind == .monthly ? min(max(month, 1), 12) : 0
    }

    var id: String { "\(kind.rawValue)-\(year)-\(month)" }
    var maximumCount: Int { kind == .monthly ? 3 : 10 }

    var displayTitle: String {
        kind == .monthly ? "\(year)年\(month)月 MY BEST" : "\(year)年 MY BEST"
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard calendar.component(.year, from: date) == year else { return false }
        return kind == .yearly || calendar.component(.month, from: date) == month
    }
}

enum MovieBestPolicy {
    static func isMovieCandidate(_ visit: Visit, period: MovieBestPeriod) -> Bool {
        guard visit.event?.isArchived != true,
              visit.event?.category?.templateKey == "movie",
              visit.event?.screenWorkType == .movie else {
            return false
        }
        return period.contains(visit.visitedAt)
    }

    static func orderedVisits(
        entries: [MovieBestEntry],
        visits: [Visit],
        period: MovieBestPeriod
    ) -> [Visit] {
        let visitByID = Dictionary(uniqueKeysWithValues: visits.map { ($0.id, $0) })
        return entries
            .filter { $0.matches(period) }
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.updatedAt < $1.updatedAt
            }
            .prefix(period.maximumCount)
            .compactMap { entry in
                guard let visit = visitByID[entry.visitID], isMovieCandidate(visit, period: period) else {
                    return nil
                }
                return visit
            }
    }
}

@Model
final class MovieBestEntry {
    var id: UUID = UUID()
    var periodKindRaw: String = MovieBestPeriodKind.yearly.rawValue
    var year: Int = 0
    var month: Int = 0
    var rank: Int = 0
    var visitID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        period: MovieBestPeriod,
        rank: Int,
        visitID: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        periodKindRaw = period.kind.rawValue
        year = period.year
        month = period.month
        self.rank = max(rank, 0)
        self.visitID = visitID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var periodKind: MovieBestPeriodKind {
        MovieBestPeriodKind(rawValue: periodKindRaw) ?? .yearly
    }

    func matches(_ period: MovieBestPeriod) -> Bool {
        periodKind == period.kind && year == period.year && month == period.month
    }
}
