import CoreLocation
import Foundation
import SwiftData
import WeatherKit

struct VisitWeatherSnapshot: Sendable {
    let symbolName: String
    let highCelsius: Double
    let lowCelsius: Double
    let fetchedAt: Date
    let attributionURL: String
}

enum VisitWeatherService {
    nonisolated private static let supportedTemplateKeys: Set<String> = [
        "theater", "museum", "live", "outing_facility", "theme_park", "nature_living",
    ]

    nonisolated static func isEligible(
        templateKey: String,
        visitedAt: Date,
        latitude: Double,
        longitude: Double,
        now: Date = Date()
    ) -> Bool {
        guard supportedTemplateKeys.contains(templateKey),
              latitude != 0 || longitude != 0 else {
            return false
        }
        let calendar = Calendar(identifier: .gregorian)
        guard let earliestDate = calendar.date(from: DateComponents(year: 2021, month: 8, day: 1)) else {
            return false
        }
        return visitedAt >= earliestDate && visitedAt < calendar.startOfDay(for: now)
    }

    nonisolated static func fetch(
        visitedAt: Date,
        latitude: Double,
        longitude: Double
    ) async throws -> VisitWeatherSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: visitedAt)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? visitedAt
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let forecast = try await WeatherService.shared.weather(
            for: location,
            including: .daily(startDate: startDate, endDate: endDate)
        )
        guard let day = forecast.forecast.first else {
            throw VisitWeatherError.noData
        }
        let attribution = try await WeatherService.shared.attribution
        return VisitWeatherSnapshot(
            symbolName: day.symbolName,
            highCelsius: day.highTemperature.converted(to: .celsius).value,
            lowCelsius: day.lowTemperature.converted(to: .celsius).value,
            fetchedAt: Date(),
            attributionURL: attribution.legalPageURL.absoluteString
        )
    }

    @MainActor
    static func fillIfNeeded(for visit: Visit, in modelContext: ModelContext) async {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: AppStorageKeys.usesWeatherAutoFill) != nil,
           !defaults.bool(forKey: AppStorageKeys.usesWeatherAutoFill) {
            return
        }

        var fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        guard fields.weatherSymbolName.isEmpty,
              let templateKey = visit.event?.category?.templateKey,
              isEligible(
                  templateKey: templateKey,
                  visitedAt: visit.visitedAt,
                  latitude: latitude,
                  longitude: longitude
              ) else {
            return
        }

        do {
            let snapshot = try await fetch(
                visitedAt: visit.visitedAt,
                latitude: latitude,
                longitude: longitude
            )
            guard fields.weatherSymbolName.isEmpty else { return }
            fields.weatherSymbolName = snapshot.symbolName
            fields.weatherHighCelsius = snapshot.highCelsius
            fields.weatherLowCelsius = snapshot.lowCelsius
            fields.weatherFetchedAt = snapshot.fetchedAt
            fields.weatherAttributionURL = snapshot.attributionURL
            visit.unitFieldsRaw = fields.encodedRawValue
            visit.updatedAt = Date()
            try modelContext.save()
        } catch {
            // Weather is supplementary; failures must not block or alter a record.
        }
    }
}

enum VisitWeatherError: Error {
    case noData
}
