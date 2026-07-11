//
//  JSONBackupImportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/11.
//

import Foundation
import SwiftData

enum JSONBackupImportService {
    static func inspect(data: Data) throws -> JSONBackupPreview {
        JSONBackupPreview(envelope: try decode(data: data))
    }

    @MainActor
    static func restore(data: Data, in context: ModelContext) throws -> JSONBackupRestoreResult {
        let envelope = try decode(data: data)
        var insertedCount = 0
        var updatedCount = 0

        var categories = Dictionary(grouping: try context.fetch(FetchDescriptor<RecordCategory>()), by: \.id).compactMapValues(\.first)
        var people = Dictionary(grouping: try context.fetch(FetchDescriptor<PersonMaster>()), by: \.id).compactMapValues(\.first)
        var places = Dictionary(grouping: try context.fetch(FetchDescriptor<PlaceMaster>()), by: \.id).compactMapValues(\.first)
        var ticketAccounts = Dictionary(grouping: try context.fetch(FetchDescriptor<TicketAccount>()), by: \.id).compactMapValues(\.first)
        var inboxItems = Dictionary(grouping: try context.fetch(FetchDescriptor<InboxItem>()), by: \.id).compactMapValues(\.first)
        var events = Dictionary(grouping: try context.fetch(FetchDescriptor<ExperienceEvent>()), by: \.id).compactMapValues(\.first)
        var visits = Dictionary(grouping: try context.fetch(FetchDescriptor<Visit>()), by: \.id).compactMapValues(\.first)
        var socialAccounts = Dictionary(grouping: try context.fetch(FetchDescriptor<SocialAccount>()), by: \.id).compactMapValues(\.first)
        var plans = Dictionary(grouping: try context.fetch(FetchDescriptor<Plan>()), by: \.id).compactMapValues(\.first)
        var attempts = Dictionary(grouping: try context.fetch(FetchDescriptor<TicketAttempt>()), by: \.id).compactMapValues(\.first)
        var personLinks = Dictionary(grouping: try context.fetch(FetchDescriptor<EventPersonLink>()), by: \.id).compactMapValues(\.first)

        for item in envelope.categories {
            let model: RecordCategory
            if let existing = categories[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = RecordCategory(id: item.id)
                context.insert(model)
                categories[item.id] = model
                insertedCount += 1
            }
            model.name = item.name
            model.iconSymbol = item.iconSymbol
            model.colorHex = item.colorHex
            model.sortOrder = item.sortOrder
            model.isBuiltIn = item.isBuiltIn
            model.templateKey = item.templateKey
            model.enabledUnitsRaw = item.enabledUnitsRaw
            model.templateTypeKey = item.templateTypeKey
            model.targetNameLabel = item.targetNameLabel
            model.recordUnitName = item.recordUnitName
            model.dateLabel = item.dateLabel
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
        }

        for item in envelope.people {
            let model: PersonMaster
            if let existing = people[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = PersonMaster(id: item.id)
                context.insert(model)
                people[item.id] = model
                insertedCount += 1
            }
            model.displayName = item.displayName
            model.reading = item.reading
            model.aliasesRaw = item.aliasesRaw
            model.roleTagsRaw = item.roleTagsRaw
            model.memo = item.memo
            model.officialURL = item.officialURL
            model.socialLinksRaw = item.socialLinksRaw
            model.imagePath = item.imagePath
            model.musicBrainzID = item.musicBrainzID
            model.wikidataQID = item.wikidataQID
            model.appleMusicID = item.appleMusicID
            model.sourceSnapshotRaw = item.sourceSnapshotRaw
            model.normalizedName = item.normalizedName
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
        }

        for item in envelope.places {
            let model: PlaceMaster
            if let existing = places[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = PlaceMaster(id: item.id)
                context.insert(model)
                places[item.id] = model
                insertedCount += 1
            }
            model.name = item.name
            model.reading = item.reading
            model.aliasesRaw = item.aliasesRaw
            model.placeTagsRaw = item.placeTagsRaw
            model.address = item.address
            model.latitude = item.latitude
            model.longitude = item.longitude
            model.officialURL = item.officialURL
            model.memo = item.memo
            model.externalIDsRaw = item.externalIDsRaw
            model.sourceSnapshotRaw = item.sourceSnapshotRaw
            model.normalizedName = item.normalizedName
            model.normalizedAddress = item.normalizedAddress
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
        }

        for item in envelope.ticketAccounts {
            let model: TicketAccount
            if let existing = ticketAccounts[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = TicketAccount(id: item.id)
                context.insert(model)
                ticketAccounts[item.id] = model
                insertedCount += 1
            }
            model.serviceName = item.serviceName
            model.accountTypeKey = item.accountTypeKey
            model.siteURL = item.siteURL
            model.loginID = item.loginID
            model.email = item.email
            model.memberNumber = item.memberNumber
            model.accountName = item.accountName
            model.membershipRank = item.membershipRank
            model.expiryDate = item.expiryDate
            model.annualFee = item.annualFee
            model.renewalNotify = item.renewalNotify
            model.note = item.note
            model.colorHex = item.colorHex
            model.keychainPasswordRef = ""
            model.normalizedServiceName = item.normalizedServiceName
            model.normalizedMemberNumber = item.normalizedMemberNumber
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
        }

        for item in envelope.inboxItems {
            let model: InboxItem
            if let existing = inboxItems[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = InboxItem(id: item.id)
                context.insert(model)
                inboxItems[item.id] = model
                insertedCount += 1
            }
            model.title = item.title
            model.body = item.body
            model.sourceURL = item.sourceURL
            model.sourceKind = item.sourceKind
            model.targetTemplateKey = item.targetTemplateKey
            model.state = item.state
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
        }

        for item in envelope.events {
            let model: ExperienceEvent
            if let existing = events[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = ExperienceEvent(id: item.id)
                context.insert(model)
                events[item.id] = model
                insertedCount += 1
            }
            model.title = item.title
            model.seriesName = item.seriesName
            model.subTypeKey = item.subTypeKey
            model.organizerNameSnapshot = item.organizerNameSnapshot
            model.representativeEyecatchPath = item.representativeEyecatchPath
            model.officialURL = item.officialURL
            model.memo = item.memo
            model.unitFieldsRaw = item.unitFieldsRaw
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.sakePolishingRatio = item.sakePolishingRatio
            model.sakeMeterValue = item.sakeMeterValue
            model.sakeAcidity = item.sakeAcidity
            model.alcoholPercentage = item.alcoholPercentage
            model.category = item.categoryID.flatMap { categories[$0] }
        }

        for item in envelope.visits {
            let model: Visit
            if let existing = visits[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = Visit(id: item.id)
                context.insert(model)
                visits[item.id] = model
                insertedCount += 1
            }
            model.visitedAt = item.visitedAt
            model.endedAt = item.endedAt
            model.venueNameSnapshot = item.venueNameSnapshot
            model.overallRating = item.overallRating
            model.outcomeKey = item.outcomeKey
            model.seatText = item.seatText
            model.eyecatchPath = item.eyecatchPath
            model.note = item.note
            model.tagNamesRaw = item.tagNamesRaw
            model.companionNamesRaw = item.companionNamesRaw
            model.amount = item.amount
            model.latitude = item.latitude
            model.longitude = item.longitude
            model.unitFieldsRaw = item.unitFieldsRaw
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.event = item.eventID.flatMap { events[$0] }
            model.placeMaster = item.placeID.flatMap { places[$0] }
        }

        for item in envelope.socialAccounts {
            let model: SocialAccount
            if let existing = socialAccounts[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = SocialAccount(id: item.id)
                context.insert(model)
                socialAccounts[item.id] = model
                insertedCount += 1
            }
            model.platformKey = item.platformKey
            model.label = item.label
            model.accountInput = item.accountInput
            model.memo = item.memo
            model.sortOrder = item.sortOrder
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.category = item.categoryID.flatMap { categories[$0] }
        }

        for item in envelope.plans {
            let model: Plan
            if let existing = plans[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = Plan(id: item.id)
                context.insert(model)
                plans[item.id] = model
                insertedCount += 1
            }
            model.title = item.title
            model.subtitle = item.subtitle
            model.planKindKey = item.planKindKey
            model.stateKey = item.stateKey
            model.startsAt = item.startsAt
            model.endsAt = item.endsAt
            model.opensAt = item.opensAt
            model.venueNameSnapshot = item.venueNameSnapshot
            model.organizerNameSnapshot = item.organizerNameSnapshot
            model.officialURL = item.officialURL
            model.sourceURL = item.sourceURL
            model.memo = item.memo
            model.notificationLeadTimeKey = item.notificationLeadTimeKey
            model.externalCalendarEventIdentifier = ""
            model.unitFieldsRaw = item.unitFieldsRaw
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.category = item.categoryID.flatMap { categories[$0] }
            model.event = item.eventID.flatMap { events[$0] }
            model.placeMaster = item.placeID.flatMap { places[$0] }
            model.visit = item.visitID.flatMap { visits[$0] }
        }

        for item in envelope.ticketAttempts {
            let model: TicketAttempt
            if let existing = attempts[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = TicketAttempt(id: item.id)
                context.insert(model)
                attempts[item.id] = model
                insertedCount += 1
            }
            model.statusKey = item.statusKey
            model.entryRouteKey = item.entryRouteKey
            model.ticketSite = item.ticketSite
            model.holderName = item.holderName
            model.saleStartAt = item.saleStartAt
            model.applyDeadlineAt = item.applyDeadlineAt
            model.resultAnnounceAt = item.resultAnnounceAt
            model.paymentDeadlineAt = item.paymentDeadlineAt
            model.issueStartAt = item.issueStartAt
            model.paidAt = item.paidAt
            model.issuedAt = item.issuedAt
            model.price = item.price
            model.fee = item.fee
            model.quantity = item.quantity
            model.purchaseURL = item.purchaseURL
            model.seatText = item.seatText
            model.notificationSettingsRaw = ""
            model.unitFieldsRaw = item.unitFieldsRaw
            model.memo = item.memo
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.plan = item.planID.flatMap { plans[$0] }
            model.account = item.accountID.flatMap { ticketAccounts[$0] }
        }

        for item in envelope.personLinks {
            let model: EventPersonLink
            if let existing = personLinks[item.id] {
                model = existing
                updatedCount += 1
            } else {
                model = EventPersonLink(id: item.id)
                context.insert(model)
                personLinks[item.id] = model
                insertedCount += 1
            }
            model.roleKey = item.roleKey
            model.displayRole = item.displayRole
            model.sortOrder = item.sortOrder
            model.nameSnapshot = item.nameSnapshot
            model.memo = item.memo
            model.isArchived = item.isArchived
            model.createdAt = item.createdAt
            model.updatedAt = item.updatedAt
            model.person = item.personID.flatMap { people[$0] }
            model.event = item.eventID.flatMap { events[$0] }
            model.visit = item.visitID.flatMap { visits[$0] }
        }

        try CategoryPresetSeeder.ensureAtLeastOneActiveCategory(in: context)
        try context.save()

        return JSONBackupRestoreResult(
            insertedCount: insertedCount,
            updatedCount: updatedCount,
            skippedPhotoCount: envelope.photos.count,
            clearedDeviceReferenceCount: envelope.plans.filter { !$0.externalCalendarEventIdentifier.isEmpty }.count
                + envelope.ticketAccounts.filter { $0.hasKeychainPasswordRef }.count
                + envelope.ticketAttempts.filter { !$0.notificationSettingsRaw.isEmpty }.count
        )
    }

    private static func decode(data: Data) throws -> FavorecoBackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: FavorecoBackupEnvelope
        do {
            envelope = try decoder.decode(FavorecoBackupEnvelope.self, from: data)
        } catch {
            throw JSONBackupImportError.invalidJSON(error.localizedDescription)
        }

        guard envelope.appName.lowercased() == "favoreco" else {
            throw JSONBackupImportError.unsupportedApp(envelope.appName)
        }
        guard envelope.schemaVersion > 0 else {
            throw JSONBackupImportError.invalidSchemaVersion(envelope.schemaVersion)
        }
        guard envelope.schemaVersion <= JSONBackupExportService.schemaVersion else {
            throw JSONBackupImportError.newerSchemaVersion(
                fileVersion: envelope.schemaVersion,
                supportedVersion: JSONBackupExportService.schemaVersion
            )
        }

        return envelope
    }
}

struct JSONBackupRestoreResult {
    let insertedCount: Int
    let updatedCount: Int
    let skippedPhotoCount: Int
    let clearedDeviceReferenceCount: Int

    var totalRestoredCount: Int { insertedCount + updatedCount }
}

struct JSONBackupPreview {
    let schemaVersion: Int
    let exportedAt: Date
    let note: String
    let categoryCount: Int
    let eventCount: Int
    let visitCount: Int
    let inboxCount: Int
    let photoMetadataCount: Int
    let socialAccountCount: Int
    let personCount: Int
    let personLinkCount: Int
    let placeCount: Int
    let planCount: Int
    let ticketAccountCount: Int
    let ticketAttemptCount: Int

    init(envelope: FavorecoBackupEnvelope) {
        schemaVersion = envelope.schemaVersion
        exportedAt = envelope.exportedAt
        note = envelope.note
        categoryCount = envelope.categories.count
        eventCount = envelope.events.count
        visitCount = envelope.visits.count
        inboxCount = envelope.inboxItems.count
        photoMetadataCount = envelope.photos.count
        socialAccountCount = envelope.socialAccounts.count
        personCount = envelope.people.count
        personLinkCount = envelope.personLinks.count
        placeCount = envelope.places.count
        planCount = envelope.plans.count
        ticketAccountCount = envelope.ticketAccounts.count
        ticketAttemptCount = envelope.ticketAttempts.count
    }

    var totalModelCount: Int {
        categoryCount
            + eventCount
            + visitCount
            + inboxCount
            + socialAccountCount
            + personCount
            + personLinkCount
            + placeCount
            + planCount
            + ticketAccountCount
            + ticketAttemptCount
    }
}

enum JSONBackupImportError: LocalizedError {
    case invalidJSON(String)
    case unsupportedApp(String)
    case invalidSchemaVersion(Int)
    case newerSchemaVersion(fileVersion: Int, supportedVersion: Int)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "FavorecoのバックアップJSONとして読み取れませんでした。"
        case .unsupportedApp(let appName):
            "別のアプリ用ファイルです（\(appName.isEmpty ? "アプリ名なし" : appName)）。"
        case .invalidSchemaVersion(let version):
            "バックアップ形式のバージョンが不正です（\(version)）。"
        case let .newerSchemaVersion(fileVersion, supportedVersion):
            "このバックアップは新しい形式です（ファイル: \(fileVersion)、対応: \(supportedVersion)）。アプリを更新してください。"
        }
    }

    var failureReason: String? {
        if case .invalidJSON(let detail) = self {
            return detail
        }
        return nil
    }
}
