import Foundation

enum TicketPlanEntryMode {
    case plan
    case ticketSchedule
    case unified
}

struct TicketPlanDraft {
    var categoryID: UUID?
    var title = ""
    var subtitle = ""
    var seriesName = ""
    var performanceTypeKey = TheaterPerformanceType.play.rawValue
    var performanceTypeCustomName = ""
    var organizerName = ""
    var socialLinksText = ""
    var eventCreditsText = ""
    var attendanceMethodKey = "onsite"
    var startsAt = Date().roundedToNearestTenMinutes()
    var endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: Date().roundedToNearestTenMinutes()) ?? Date()
    var opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: Date().roundedToNearestTenMinutes()) ?? Date()
    var hasOpeningTime = false
    var hasEndTime = false
    var venueName = ""
    var venueAddress = ""
    var venueOfficialURL = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var publicPlaceSelection: PublicPlaceSelectionDraft?
    var officialURL = ""
    var hasConfirmedSchedule = false
    var createsTicketAttempt = true
    var flowKey = "lotteryPlanned"
    var statusKey = "beforeApply"
    var entryRouteKey = ""
    var accountID: UUID?
    var ticketGuideKey = TicketGuideDefinition.customKey
    var ticketSite = ""
    var holderName = ""
    var applicationGroupIDRaw = ""
    var applicationGroupName = ""
    var hasSaleStart = false
    var saleStartAt = Date().roundedToNearestFiveMinutes()
    var hasApplyDeadline = true
    var applyDeadlineAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var hasResultAnnounce = false
    var resultAnnounceAt = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    var hasPaymentDeadline = false
    var paymentDeadlineAt = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    var hasIssueStart = false
    var issueStartAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var priceText = ""
    var feeText = ""
    var quantity = 1
    var seatText = ""
    var tagNamesText = ""
    var planTagNamesText = ""
    var planMemoStyleRuns: [MemoStyleRun] = []
    var planOverallRating: Double = 0
    var planMomentEntries: [VisitMomentEntry] = []
    var planLiveSetlistEntries: [LiveSetlistEntry] = []
    var planPeople: [PlanMemoryPerson] = []
    var planUnitFieldsRawSnapshot = ""
    var purchaseURL = ""
    var memo = ""

    init(entryMode: TicketPlanEntryMode = .ticketSchedule) {
        switch entryMode {
        case .plan:
            createsTicketAttempt = false
            hasConfirmedSchedule = true
        case .ticketSchedule:
            createsTicketAttempt = true
            hasConfirmedSchedule = false
        case .unified:
            createsTicketAttempt = false
            hasConfirmedSchedule = false
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
            hasIssueStart = false
        }
    }

    init(inboxItem: InboxItem, categoryID: UUID) {
        self.categoryID = categoryID
        title = inboxItem.title
        officialURL = inboxItem.sourceURL
        memo = inboxItem.body
        createsTicketAttempt = false
        hasConfirmedSchedule = true
    }

    init(
        event: ExperienceEvent,
        entryMode: TicketPlanEntryMode = .plan,
        continuingApplication: TicketAttempt? = nil
    ) {
        categoryID = event.category?.id
        title = event.title
        seriesName = event.seriesName
        performanceTypeKey = event.subTypeKey.isEmpty ? TheaterPerformanceType.play.rawValue : event.subTypeKey
        organizerName = event.organizerNameSnapshot
        let eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        performanceTypeCustomName = eventFields.eventPerformanceTypeCustomName
        socialLinksText = eventFields.socialLinks.joined(separator: "\n")
        eventCreditsText = eventFields.eventCreditsText
        officialURL = event.officialURL
        memo = event.memo
        let registeredVenues = VisitUnitFields(rawValue: event.unitFieldsRaw)
            .eventVenues
            .filter { !$0.isEmpty }
        if registeredVenues.count == 1, let venue = registeredVenues.first {
            venueName = venue.trimmedName
            venueAddress = venue.trimmedAddress
        }
        createsTicketAttempt = entryMode == .ticketSchedule
        hasConfirmedSchedule = entryMode != .ticketSchedule
        if let continuingApplication {
            applyContinuation(continuingApplication)
        }
    }

    init(plan: Plan?, entryMode: TicketPlanEntryMode = .ticketSchedule) {
        guard let plan else {
            switch entryMode {
            case .plan:
                createsTicketAttempt = false
                hasConfirmedSchedule = true
            case .ticketSchedule:
                createsTicketAttempt = true
                hasConfirmedSchedule = false
            case .unified:
                createsTicketAttempt = false
                hasConfirmedSchedule = false
                hasApplyDeadline = false
                hasResultAnnounce = false
                hasPaymentDeadline = false
                hasIssueStart = false
            }
            return
        }
        let attempt = plan.ticketAttempts?
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        categoryID = plan.category?.id
        title = plan.event?.title.isEmpty == false ? plan.event?.title ?? plan.title : plan.title
        seriesName = plan.event?.seriesName ?? ""
        performanceTypeKey = plan.event?.subTypeKey.isEmpty == false
            ? plan.event?.subTypeKey ?? TheaterPerformanceType.play.rawValue
            : TheaterPerformanceType.play.rawValue
        organizerName = plan.event?.organizerNameSnapshot ?? ""
        let eventFields = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
        performanceTypeCustomName = eventFields.eventPerformanceTypeCustomName
        socialLinksText = eventFields.socialLinks.joined(separator: "\n")
        eventCreditsText = eventFields.eventCreditsText
        subtitle = plan.subtitle
        hasConfirmedSchedule = plan.hasConfirmedSchedule
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        hasEndTime = plan.endsAt > plan.startsAt
        opensAt = plan.opensAt
        hasOpeningTime = plan.opensAt != Date.distantPast
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        venueOfficialURL = plan.placeMaster?.officialURL ?? ""
        latitude = plan.placeMaster?.latitude ?? 0
        longitude = plan.placeMaster?.longitude ?? 0
        officialURL = plan.officialURL
        attendanceMethodKey = PlanPreparationFields(rawValue: plan.unitFieldsRaw).attendanceMethodKey
        memo = plan.memo
        planUnitFieldsRawSnapshot = plan.unitFieldsRaw
        let preparationFields = PlanPreparationFields(rawValue: plan.unitFieldsRaw)
        attendanceMethodKey = preparationFields.attendanceMethodKey
        planTagNamesText = preparationFields.tagNames.joined(separator: "\n")
        planMemoStyleRuns = preparationFields.memoStyleRuns
        planOverallRating = preparationFields.overallRating
        planMomentEntries = preparationFields.momentEntries
        planLiveSetlistEntries = preparationFields.liveSetlistEntries
        planPeople = preparationFields.people

        guard entryMode == .ticketSchedule else {
            createsTicketAttempt = false
            return
        }

        createsTicketAttempt = true
        guard let attempt else { return }
        flowKey = TicketFlowDefinition.inferredKey(statusKey: attempt.statusKey, entryRouteKey: attempt.entryRouteKey)
        statusKey = attempt.statusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketGuideKey = TicketGuideDefinition.inferredKey(siteName: attempt.ticketSite, urlString: attempt.purchaseURL)
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        applicationGroupIDRaw = attempt.applicationGroupIDRaw
        applicationGroupName = attempt.applicationGroupName
        hasSaleStart = attempt.saleStartAt != Date.distantPast
        saleStartAt = hasSaleStart ? attempt.saleStartAt : Date()
        hasApplyDeadline = attempt.applyDeadlineAt != Date.distantPast
        applyDeadlineAt = hasApplyDeadline ? attempt.applyDeadlineAt : Date()
        hasResultAnnounce = attempt.resultAnnounceAt != Date.distantPast
        resultAnnounceAt = hasResultAnnounce ? attempt.resultAnnounceAt : Date()
        hasPaymentDeadline = attempt.paymentDeadlineAt != Date.distantPast
        paymentDeadlineAt = hasPaymentDeadline ? attempt.paymentDeadlineAt : Date()
        hasIssueStart = attempt.issueStartAt != Date.distantPast
        issueStartAt = hasIssueStart ? attempt.issueStartAt : Date()
        priceText = decimalText(attempt.price)
        feeText = decimalText(attempt.fee)
        quantity = attempt.quantity
        seatText = attempt.seatText
        tagNamesText = TicketAttemptUnitFields(rawValue: attempt.unitFieldsRaw).tagNames.joined(separator: "\n")
        purchaseURL = attempt.purchaseURL
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSubtitle: String { subtitle.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSeriesName: String { seriesName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOrganizerName: String { organizerName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var normalizedSocialLinks: [String] {
        socialLinksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    var trimmedEventCreditsText: String {
        eventCreditsText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var trimmedVenueName: String { venueName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedTicketSite: String { ticketSite.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHolderName: String { holderName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedApplicationGroupName: String {
        applicationGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func resolvedApplicationGroupName(for plan: Plan) -> String {
        if !trimmedApplicationGroupName.isEmpty {
            return trimmedApplicationGroupName
        }
        return TicketApplicationCollectionNaming.scheduleName(for: plan)
    }
    func resolvedApplicationGroupIDRaw(for groupName: String) -> String {
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        let draftID = applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return draftID.isEmpty ? UUID().uuidString : draftID
    }
    func resolvedApplicationGroupIDRaw(preserving existingID: String = "") -> String {
        guard !trimmedApplicationGroupName.isEmpty else { return "" }
        let draftID = applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draftID.isEmpty { return draftID }
        let preservedID = existingID.trimmingCharacters(in: .whitespacesAndNewlines)
        return preservedID.isEmpty ? UUID().uuidString : preservedID
    }
    var trimmedSeatText: String { seatText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var ticketUnitFieldsRaw: String {
        TicketAttemptUnitFields(
            tagNames: TicketAttemptUnitFields.normalizedTagNames(from: tagNamesText)
        ).encodedRawValue
    }
    var planUnitFieldsRaw: String {
        var fields = PlanPreparationFields(rawValue: planUnitFieldsRawSnapshot)
        fields.tagNames = TicketAttemptUnitFields.normalizedTagNames(from: planTagNamesText)
        fields.memoStyleRuns = planMemoStyleRuns
        fields.overallRating = planOverallRating
        fields.momentEntries = planMomentEntries
        fields.liveSetlistEntries = planLiveSetlistEntries
        fields.people = planPeople
        fields.attendanceMethodKey = attendanceMethodKey
        return fields.encodedRawValue
    }
    var trimmedPurchaseURL: String { purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
    var resolvedStatusKey: String {
        flowKey == "acquired" ? "issued" : statusKey
    }

    var placeSnapshot: PlaceSnapshot {
        PlaceSnapshot(
            name: trimmedVenueName,
            address: venueAddress,
            latitude: latitude,
            longitude: longitude,
            officialURL: venueOfficialURL
        )
    }

    var mapSearchQuery: String {
        let address = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? trimmedVenueName : address
    }

    var shouldPreserveVenueNameForAddressSearch: Bool {
        !trimmedVenueName.isEmpty && !venueAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func apply(place: PlaceSearchCandidate, preservingVenueName: Bool) {
        publicPlaceSelection = nil
        venueOfficialURL = ""
        if !preservingVenueName {
            venueName = place.name
        }
        if !place.address.isEmpty {
            venueAddress = place.address
        }
        latitude = place.latitude
        longitude = place.longitude
    }

    mutating func apply(placeMaster: PlaceMaster) {
        publicPlaceSelection = nil
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
        venueOfficialURL = placeMaster.officialURL
    }

    mutating func applyDestination(placeMaster: PlaceMaster) {
        apply(placeMaster: placeMaster)
        title = placeMaster.name
    }

    mutating func apply(publicPlace selection: PublicPlaceSelectionDraft) {
        publicPlaceSelection = selection
        venueName = selection.entry.officialName
        venueAddress = selection.entry.address
        latitude = selection.entry.latitude
        longitude = selection.entry.longitude
        venueOfficialURL = selection.entry.officialURL
    }

    mutating func applyDestination(publicPlace selection: PublicPlaceSelectionDraft) {
        apply(publicPlace: selection)
        title = selection.entry.officialName
    }

    mutating func applyDestination(place: PlaceSearchCandidate) {
        apply(place: place, preservingVenueName: false)
        title = place.name
    }

    mutating func clearPlaceSelection() {
        publicPlaceSelection = nil
        venueAddress = ""
        venueOfficialURL = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        publicPlaceSelection = nil
        latitude = 0
        longitude = 0
    }

    func placeSuggestions(from placeMasters: [PlaceMaster]) -> [PlaceMaster] {
        let query = normalizedPlaceText(trimmedVenueName)
        guard !query.isEmpty else { return [] }
        let matches = placeMasters
            .filter { !$0.isArchived && !$0.isClosed }
            .filter {
                normalizedPlaceText($0.name).contains(query)
                    || normalizedPlaceText($0.reading).contains(query)
                    || normalizedPlaceText($0.aliasesRaw).contains(query)
            }
        return deduplicatedPlaceSuggestions(matches)
            .prefix(4)
            .map { $0 }
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    func validationMessage(usesOpeningTime: Bool) -> String? {
        if hasConfirmedSchedule && endsAt < startsAt {
            return "終了日時は開始日時以降にしてください。"
        }
        if hasConfirmedSchedule && usesOpeningTime && hasOpeningTime && opensAt > startsAt {
            return "開場日時は開始日時以前にしてください。"
        }
        guard createsTicketAttempt else { return nil }
        if hasSaleStart && hasApplyDeadline && saleStartAt > applyDeadlineAt {
            return "抽選申込開始は抽選申込締切以前にしてください。"
        }
        if hasApplyDeadline && hasResultAnnounce && applyDeadlineAt > resultAnnounceAt {
            return "当落発表は抽選申込締切以降にしてください。"
        }
        if hasResultAnnounce && hasPaymentDeadline && resultAnnounceAt > paymentDeadlineAt {
            return "支払締切は当落発表以降にしてください。"
        }
        return nil
    }

    var flowOptions: [TicketFlowDefinition] {
        if flowKey == "interested",
           let interested = TicketFlowDefinition.all.first(where: { $0.key == "interested" }) {
            return [interested] + TicketFlowDefinition.registrationOptions
        }
        return TicketFlowDefinition.registrationOptions
    }

    var showsEntryRoute: Bool {
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
    }

    var showsAccountFields: Bool {
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
    }

    var showsTicketGuide: Bool {
        flowKey != "interested"
    }

    var showsSaleStart: Bool {
        flowKey == "lotteryPlanned" || flowKey == "saleWaiting"
    }

    var showsApplyDeadline: Bool {
        flowKey == "lotteryPlanned"
    }

    var showsResultAnnounce: Bool {
        flowKey == "lotteryPlanned"
    }

    var showsPaymentDeadline: Bool {
        flowKey == "lotteryPlanned"
    }

    var showsIssueStart: Bool {
        flowKey == "saleWaiting"
    }

    var showsAnyTicketMilestone: Bool {
        showsSaleStart || showsApplyDeadline || showsResultAnnounce || showsPaymentDeadline || showsIssueStart
    }

    var showsTicketDetails: Bool {
        flowKey == "acquired"
    }

    var saleStartLabel: String {
        flowKey == "saleWaiting" ? "発売開始" : "抽選申込開始"
    }

    var entryRouteLabel: String {
        flowKey == "lotteryPlanned" ? "申込枠" : "販売方法"
    }

    var entryRouteOptions: [TicketEntryRouteDefinition] {
        switch flowKey {
        case "lotteryPlanned":
            return TicketEntryRouteDefinition.all.filter {
                ["fanClub", "official", "lottery", "card", "generalLottery", "other"].contains($0.key)
            }
        case "saleWaiting":
            return TicketEntryRouteDefinition.all.filter {
                ["presale", "general", "resale", "other"].contains($0.key)
            }
        default:
            return []
        }
    }

    mutating func setInitialCategoryIfNeeded(_ categories: [RecordCategory]) {
        guard categoryID == nil else { return }
        categoryID = categories.first { category in
            category.enabledUnitsRaw.components(separatedBy: ",").contains("ticketPlan")
        }?.id ?? categories.first?.id
    }

    mutating func applyTarget(_ event: ExperienceEvent) {
        categoryID = event.category?.id
        title = event.title
        seriesName = event.seriesName
        performanceTypeKey = event.subTypeKey.isEmpty ? TheaterPerformanceType.play.rawValue : event.subTypeKey
        organizerName = event.organizerNameSnapshot
        let eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        performanceTypeCustomName = eventFields.eventPerformanceTypeCustomName
        socialLinksText = eventFields.socialLinks.joined(separator: "\n")
        eventCreditsText = eventFields.eventCreditsText
        officialURL = event.officialURL
        venueName = ""
        venueAddress = ""
        latitude = 0
        longitude = 0
        publicPlaceSelection = nil
        let registeredVenues = VisitUnitFields(rawValue: event.unitFieldsRaw)
            .eventVenues
            .filter { !$0.isEmpty }
        if registeredVenues.count == 1, let venue = registeredVenues.first {
            venueName = venue.trimmedName
            venueAddress = venue.trimmedAddress
        }
    }

    mutating func applyTarget(_ plan: Plan) {
        categoryID = plan.category?.id
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = eventTitle.isEmpty ? plan.title : eventTitle
        seriesName = plan.event?.seriesName ?? ""
        performanceTypeKey = plan.event?.subTypeKey.isEmpty == false
            ? plan.event?.subTypeKey ?? TheaterPerformanceType.play.rawValue
            : TheaterPerformanceType.play.rawValue
        organizerName = plan.event?.organizerNameSnapshot ?? ""
        let eventFields = VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
        performanceTypeCustomName = eventFields.eventPerformanceTypeCustomName
        socialLinksText = eventFields.socialLinks.joined(separator: "\n")
        eventCreditsText = eventFields.eventCreditsText
        subtitle = plan.subtitle
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        hasEndTime = plan.endsAt > plan.startsAt
        opensAt = plan.opensAt
        hasOpeningTime = plan.opensAt != Date.distantPast
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        latitude = plan.placeMaster?.latitude ?? 0
        longitude = plan.placeMaster?.longitude ?? 0
        officialURL = plan.officialURL
        attendanceMethodKey = PlanPreparationFields(rawValue: plan.unitFieldsRaw).attendanceMethodKey

        guard applicationGroupIDRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let groupedAttempt = plan.ticketAttempts?
            .filter {
                !$0.isArchived
                    && !$0.applicationGroupIDRaw
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        if let groupedAttempt {
            applicationGroupIDRaw = groupedAttempt.applicationGroupIDRaw
            applicationGroupName = TicketApplicationCollectionNaming.displayName(
                storedName: groupedAttempt.applicationGroupName,
                attempts: [groupedAttempt]
            ) ?? TicketApplicationCollectionNaming.scheduleName(for: plan)
        } else {
            applicationGroupIDRaw = UUID().uuidString
            applicationGroupName = TicketApplicationCollectionNaming.scheduleName(for: plan)
        }
    }

    mutating func applyRegisteredVenue(_ venue: EventVenueEntry) {
        venueName = venue.trimmedName
        venueAddress = venue.trimmedAddress
        latitude = 0
        longitude = 0
        publicPlaceSelection = nil
    }

    mutating func clearTarget() {
        let now = Date().roundedToNearestTenMinutes()
        categoryID = nil
        title = ""
        subtitle = ""
        seriesName = ""
        performanceTypeKey = TheaterPerformanceType.play.rawValue
        performanceTypeCustomName = ""
        organizerName = ""
        socialLinksText = ""
        eventCreditsText = ""
        attendanceMethodKey = "onsite"
        startsAt = now
        endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now
        opensAt = Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now
        hasOpeningTime = false
        hasEndTime = false
        venueName = ""
        venueAddress = ""
        latitude = 0
        longitude = 0
        officialURL = ""
    }

    mutating func applyFlowDefaults(_ key: String) {
        let flow = TicketFlowDefinition.definition(for: key)
        flowKey = flow.key
        statusKey = flow.defaultStatusKey
        if flow.key != "acquired",
           (entryRouteKey.isEmpty || !entryRouteOptions.contains(where: { $0.key == entryRouteKey })) {
            entryRouteKey = flow.defaultEntryRouteKey
        }

        switch flow.key {
        case "interested":
            applicationGroupIDRaw = ""
            applicationGroupName = ""
            hasSaleStart = false
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
            hasIssueStart = false
            priceText = ""
            feeText = ""
            seatText = ""
            purchaseURL = ""
        case "lotteryPlanned":
            hasApplyDeadline = true
            hasResultAnnounce = true
            hasIssueStart = false
        case "saleWaiting":
            hasSaleStart = true
            hasApplyDeadline = false
            hasResultAnnounce = false
            hasPaymentDeadline = false
        case "acquired":
            applicationGroupIDRaw = ""
            applicationGroupName = ""
            hasApplyDeadline = false
            hasResultAnnounce = false
        default:
            break
        }
    }

    mutating func applyContinuation(_ attempt: TicketAttempt) {
        flowKey = TicketFlowDefinition.inferredKey(
            statusKey: attempt.statusKey,
            entryRouteKey: attempt.entryRouteKey
        )
        statusKey = TicketFlowDefinition.definition(for: flowKey).defaultStatusKey
        entryRouteKey = attempt.entryRouteKey
        accountID = attempt.account?.id
        ticketGuideKey = TicketGuideDefinition.inferredKey(
            siteName: attempt.ticketSite,
            urlString: attempt.purchaseURL
        )
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        applicationGroupIDRaw = attempt.applicationGroupIDRaw
        applicationGroupName = attempt.applicationGroupName
        hasSaleStart = attempt.saleStartAt != Date.distantPast
        saleStartAt = hasSaleStart ? attempt.saleStartAt : Date()
        hasApplyDeadline = attempt.applyDeadlineAt != Date.distantPast
        applyDeadlineAt = hasApplyDeadline ? attempt.applyDeadlineAt : Date()
        hasResultAnnounce = attempt.resultAnnounceAt != Date.distantPast
        resultAnnounceAt = hasResultAnnounce ? attempt.resultAnnounceAt : Date()
        hasPaymentDeadline = attempt.paymentDeadlineAt != Date.distantPast
        paymentDeadlineAt = hasPaymentDeadline ? attempt.paymentDeadlineAt : Date()
        hasIssueStart = attempt.issueStartAt != Date.distantPast
        issueStartAt = hasIssueStart ? attempt.issueStartAt : Date()
        purchaseURL = attempt.purchaseURL
    }

    mutating func applyTicketGuide(_ key: String) {
        guard accountID == nil else { return }
        guard let guide = TicketGuideDefinition.guide(for: key) else {
            ticketGuideKey = TicketGuideDefinition.customKey
            return
        }
        ticketSite = guide.name
        purchaseURL = guide.urlString
    }

    mutating func applyAccount(
        _ account: TicketAccount?,
        replacing previousAccount: TicketAccount? = nil
    ) {
        if let previousAccount {
            let previousServiceName = previousAccount.serviceName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousHolderName = previousAccount.accountName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousSiteURL = previousAccount.siteURL
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let previousGuideKey = TicketGuideDefinition.inferredKey(
                siteName: previousServiceName,
                urlString: previousSiteURL
            )
            let previousPurchaseURL = !previousSiteURL.isEmpty
                ? previousSiteURL
                : (TicketGuideDefinition.guide(for: previousGuideKey)?.urlString ?? "")

            if trimmedTicketSite == previousServiceName {
                ticketSite = ""
            }
            if trimmedHolderName == previousHolderName {
                holderName = ""
            }
            if trimmedPurchaseURL == previousPurchaseURL {
                purchaseURL = ""
            }
            if ticketGuideKey == previousGuideKey {
                ticketGuideKey = TicketGuideDefinition.customKey
            }
        }

        guard let account else {
            accountID = nil
            return
        }
        let serviceName = account.serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let siteURL = account.siteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        accountID = account.id
        ticketSite = serviceName
        holderName = account.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        ticketGuideKey = TicketGuideDefinition.inferredKey(
            siteName: serviceName,
            urlString: siteURL
        )
        purchaseURL = !siteURL.isEmpty
            ? siteURL
            : (TicketGuideDefinition.guide(for: ticketGuideKey)?.urlString ?? "")
    }

    private func decimalText(_ value: Decimal) -> String {
        guard value != Decimal(0) else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}
