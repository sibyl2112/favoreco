import Foundation

struct ExperienceDetailSnapshot {
    let event: ExperienceEvent?
    let category: RecordCategory?
    let photos: [PhotoBlob]
    let linkedPeople: [EventPersonLink]
    let unitFields: VisitUnitFields
    let eventCreditsText: String
    let eyecatchAspectRatio: Double
    let eventTitle: String
    let ratingText: String
    let weatherTaskID: String
    let weatherTemperatureText: String
    let weatherAttributionURL: URL?
    let ticketStatusText: String
    let formattedAmount: String
    let venueAddress: String
    let mapURL: URL?
    let preferredLocationText: String

    static func make(
        visit: Visit,
        personLinks: [EventPersonLink]
    ) -> ExperienceDetailSnapshot {
        let event = visit.event
        let category = event?.category
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let photos = (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .sorted { lhs, rhs in
                let lhsIsCover = !visit.eyecatchPath.isEmpty && lhs.relativePath == visit.eyecatchPath
                let rhsIsCover = !visit.eyecatchPath.isEmpty && rhs.relativePath == visit.eyecatchPath
                if lhsIsCover != rhsIsCover { return lhsIsCover }
                return lhs.createdAt < rhs.createdAt
            }
        let eventLinks = personLinks.filter { !$0.isArchived && $0.event?.id == event?.id }
        let visitLinks = personLinks.filter { !$0.isArchived && $0.visit?.id == visit.id }
        let linkedPeople: [EventPersonLink]
        if category?.templateKey == "theater" {
            linkedPeople = TheaterVisitCastResolver.resolvedLinks(
                eventLinks: eventLinks,
                visitLinks: visitLinks,
                excludedEventLinkIDs: Set(unitFields.excludedEventCastLinkIDs),
                usesVisitSnapshot: unitFields.hasVisitCastSnapshot
            )
        } else {
            linkedPeople = (eventLinks + visitLinks).sorted { $0.sortOrder < $1.sortOrder }
        }
        let weatherTemperatureText: String
        if let high = unitFields.weatherHighCelsius,
           let low = unitFields.weatherLowCelsius {
            weatherTemperatureText = "最高 \(Int(high.rounded()))° / 最低 \(Int(low.rounded()))°"
        } else {
            weatherTemperatureText = "記録済み"
        }
        let ticketStatusText = Self.ticketStatusText(
            for: visit.outcomeKey,
            templateKey: category?.templateKey
        )
        let formattedAmount = Self.formattedAmount(visit.amount)
        let eventFields = VisitUnitFields(rawValue: event?.unitFieldsRaw ?? "")
        let planAddresses = (visit.plans ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { $0.placeMaster?.address }
        let address = Self.resolvedVenueAddress(
            venueName: visit.venueNameSnapshot,
            masterAddress: visit.placeMaster?.address,
            visitAddress: unitFields.venueAddressSnapshot,
            planAddresses: planAddresses,
            eventVenues: eventFields.eventVenues
        )
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)

        return ExperienceDetailSnapshot(
            event: event,
            category: category,
            photos: photos,
            linkedPeople: linkedPeople,
            unitFields: unitFields,
            eventCreditsText: eventFields.eventCreditsText,
            eyecatchAspectRatio: EyecatchAspectRatio.option(
                for: unitFields.eyecatchAspectRatioKey,
                category: category
            ).value,
            eventTitle: event?.title.isEmpty == false ? event?.title ?? "記録" : "記録",
            ratingText: visit.overallRating == 0 ? "未評価" : String(format: "%.1f", visit.overallRating),
            weatherTaskID: "\(visit.visitedAt.timeIntervalSinceReferenceDate)-\(latitude)-\(longitude)-\(unitFields.weatherSymbolName)",
            weatherTemperatureText: weatherTemperatureText,
            weatherAttributionURL: URL(string: unitFields.weatherAttributionURL),
            ticketStatusText: ticketStatusText,
            formattedAmount: formattedAmount,
            venueAddress: address,
            mapURL: PlaceSearchService.appleMapsURL(
                name: visit.venueNameSnapshot,
                address: address,
                latitude: latitude,
                longitude: longitude
            ),
            preferredLocationText: address.isEmpty ? visit.venueNameSnapshot : address
        )
    }

    /// 記録詳細の住所は保存場所が世代ごとに異なるため、空文字を値として扱わず
    /// Visit固有値、紐づく予定、公演の会場一覧まで順に補完する。
    static func resolvedVenueAddress(
        venueName: String,
        masterAddress: String?,
        visitAddress: String,
        planAddresses: [String],
        eventVenues: [EventVenueEntry]
    ) -> String {
        let directCandidates = [masterAddress ?? "", visitAddress] + planAddresses
        if let address = directCandidates.lazy
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return address
        }

        let normalizedVenueName = PlaceSearchService.normalizedSearchText(venueName)
        if !normalizedVenueName.isEmpty,
           let matchingAddress = eventVenues.lazy
            .filter({ PlaceSearchService.normalizedSearchText($0.trimmedName) == normalizedVenueName })
            .map(\.trimmedAddress)
            .first(where: { !$0.isEmpty }) {
            return matchingAddress
        }

        let populatedEventVenues = eventVenues.filter { !$0.trimmedAddress.isEmpty }
        if populatedEventVenues.count == 1 {
            return populatedEventVenues[0].trimmedAddress
        }
        return ""
    }

    private static func ticketStatusText(for key: String, templateKey: String?) -> String {
        switch key {
        case "planned": return "予定"
        case "applied": return "申込中"
        case "won": return "当選"
        case "paid": return "支払済み"
        case "ticketed": return "発券済み"
        case "attended": return GenreVocabulary.completedStatus(for: templateKey)
        case "canceled": return "中止・キャンセル"
        default: return key
        }
    }

    private static func formattedAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }
}
