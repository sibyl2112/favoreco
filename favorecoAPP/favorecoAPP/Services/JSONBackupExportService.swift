//
//  JSONBackupExportService.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum JSONBackupExportService {
    static let schemaVersion = 1

    static func makeBackupJSON(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        visits: [Visit],
        inboxItems: [InboxItem],
        photos: [PhotoBlob],
        socialAccounts: [SocialAccount],
        people: [PersonMaster],
        personLinks: [EventPersonLink],
        places: [PlaceMaster]
    ) throws -> String {
        let envelope = FavorecoBackupEnvelope(
            appName: "favoreco",
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            note: "Manual JSON backup. Photo binary data is not included.",
            categories: categories.sorted { $0.sortOrder < $1.sortOrder }.map(BackupCategory.init),
            events: events.sorted { $0.updatedAt > $1.updatedAt }.map(BackupEvent.init),
            visits: visits.sorted { $0.visitedAt > $1.visitedAt }.map(BackupVisit.init),
            inboxItems: inboxItems.sorted { $0.updatedAt > $1.updatedAt }.map(BackupInboxItem.init),
            photos: photos.sorted { $0.createdAt > $1.createdAt }.map(BackupPhoto.init),
            socialAccounts: socialAccounts.sorted { $0.sortOrder < $1.sortOrder }.map(BackupSocialAccount.init),
            people: people.sorted { $0.displayName < $1.displayName }.map(BackupPerson.init),
            personLinks: personLinks.sorted { $0.sortOrder < $1.sortOrder }.map(BackupPersonLink.init),
            places: places.sorted { $0.name < $1.name }.map(BackupPlace.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct FavorecoBackupEnvelope: Codable {
    var appName: String
    var schemaVersion: Int
    var exportedAt: Date
    var note: String
    var categories: [BackupCategory]
    var events: [BackupEvent]
    var visits: [BackupVisit]
    var inboxItems: [BackupInboxItem]
    var photos: [BackupPhoto]
    var socialAccounts: [BackupSocialAccount]
    var people: [BackupPerson]
    var personLinks: [BackupPersonLink]
    var places: [BackupPlace]
}

struct BackupCategory: Codable {
    var id: UUID
    var name: String
    var iconSymbol: String
    var colorHex: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var templateKey: String
    var enabledUnitsRaw: String
    var templateTypeKey: String
    var targetNameLabel: String
    var recordUnitName: String
    var dateLabel: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ category: RecordCategory) {
        id = category.id
        name = category.name
        iconSymbol = category.iconSymbol
        colorHex = category.colorHex
        sortOrder = category.sortOrder
        isBuiltIn = category.isBuiltIn
        templateKey = category.templateKey
        enabledUnitsRaw = category.enabledUnitsRaw
        templateTypeKey = category.templateTypeKey
        targetNameLabel = category.targetNameLabel
        recordUnitName = category.recordUnitName
        dateLabel = category.dateLabel
        isArchived = category.isArchived
        createdAt = category.createdAt
        updatedAt = category.updatedAt
    }
}

struct BackupEvent: Codable {
    var id: UUID
    var categoryID: UUID?
    var title: String
    var seriesName: String
    var subTypeKey: String
    var organizerNameSnapshot: String
    var representativeEyecatchPath: String
    var officialURL: String
    var memo: String
    var unitFieldsRaw: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var sakePolishingRatio: Double
    var sakeMeterValue: Double
    var sakeAcidity: Double
    var alcoholPercentage: Double

    nonisolated init(_ event: ExperienceEvent) {
        id = event.id
        categoryID = event.category?.id
        title = event.title
        seriesName = event.seriesName
        subTypeKey = event.subTypeKey
        organizerNameSnapshot = event.organizerNameSnapshot
        representativeEyecatchPath = event.representativeEyecatchPath
        officialURL = event.officialURL
        memo = event.memo
        unitFieldsRaw = event.unitFieldsRaw
        isArchived = event.isArchived
        createdAt = event.createdAt
        updatedAt = event.updatedAt
        sakePolishingRatio = event.sakePolishingRatio
        sakeMeterValue = event.sakeMeterValue
        sakeAcidity = event.sakeAcidity
        alcoholPercentage = event.alcoholPercentage
    }
}

struct BackupVisit: Codable {
    var id: UUID
    var eventID: UUID?
    var placeID: UUID?
    var visitedAt: Date
    var endedAt: Date
    var venueNameSnapshot: String
    var overallRating: Double
    var outcomeKey: String
    var seatText: String
    var eyecatchPath: String
    var note: String
    var tagNamesRaw: String
    var companionNamesRaw: String
    var amount: Decimal
    var latitude: Double
    var longitude: Double
    var unitFieldsRaw: String
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ visit: Visit) {
        id = visit.id
        eventID = visit.event?.id
        placeID = visit.placeMaster?.id
        visitedAt = visit.visitedAt
        endedAt = visit.endedAt
        venueNameSnapshot = visit.venueNameSnapshot
        overallRating = visit.overallRating
        outcomeKey = visit.outcomeKey
        seatText = visit.seatText
        eyecatchPath = visit.eyecatchPath
        note = visit.note
        tagNamesRaw = visit.tagNamesRaw
        companionNamesRaw = visit.companionNamesRaw
        amount = visit.amount
        latitude = visit.latitude
        longitude = visit.longitude
        unitFieldsRaw = visit.unitFieldsRaw
        createdAt = visit.createdAt
        updatedAt = visit.updatedAt
    }
}

struct BackupInboxItem: Codable {
    var id: UUID
    var title: String
    var body: String
    var sourceURL: String
    var sourceKind: String
    var targetTemplateKey: String
    var state: String
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ item: InboxItem) {
        id = item.id
        title = item.title
        body = item.body
        sourceURL = item.sourceURL
        sourceKind = item.sourceKind
        targetTemplateKey = item.targetTemplateKey
        state = item.state
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }
}

struct BackupPhoto: Codable {
    var id: UUID
    var visitID: UUID?
    var relativePath: String
    var originalFilename: String
    var mediaKind: String
    var purpose: String
    var byteCount: Int
    var width: Int
    var height: Int
    var createdAt: Date
    var includesBinaryData: Bool

    nonisolated init(_ photo: PhotoBlob) {
        id = photo.id
        visitID = photo.visit?.id
        relativePath = photo.relativePath
        originalFilename = photo.originalFilename
        mediaKind = photo.mediaKind
        purpose = photo.purpose
        byteCount = photo.byteCount
        width = photo.width
        height = photo.height
        createdAt = photo.createdAt
        includesBinaryData = false
    }
}

struct BackupSocialAccount: Codable {
    var id: UUID
    var categoryID: UUID?
    var platformKey: String
    var label: String
    var accountInput: String
    var memo: String
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ account: SocialAccount) {
        id = account.id
        categoryID = account.category?.id
        platformKey = account.platformKey
        label = account.label
        accountInput = account.accountInput
        memo = account.memo
        sortOrder = account.sortOrder
        isArchived = account.isArchived
        createdAt = account.createdAt
        updatedAt = account.updatedAt
    }
}

struct BackupPerson: Codable {
    var id: UUID
    var displayName: String
    var reading: String
    var aliasesRaw: String
    var roleTagsRaw: String
    var memo: String
    var officialURL: String
    var socialLinksRaw: String
    var imagePath: String
    var musicBrainzID: String
    var wikidataQID: String
    var appleMusicID: String
    var sourceSnapshotRaw: String
    var normalizedName: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ person: PersonMaster) {
        id = person.id
        displayName = person.displayName
        reading = person.reading
        aliasesRaw = person.aliasesRaw
        roleTagsRaw = person.roleTagsRaw
        memo = person.memo
        officialURL = person.officialURL
        socialLinksRaw = person.socialLinksRaw
        imagePath = person.imagePath
        musicBrainzID = person.musicBrainzID
        wikidataQID = person.wikidataQID
        appleMusicID = person.appleMusicID
        sourceSnapshotRaw = person.sourceSnapshotRaw
        normalizedName = person.normalizedName
        isArchived = person.isArchived
        createdAt = person.createdAt
        updatedAt = person.updatedAt
    }
}

struct BackupPersonLink: Codable {
    var id: UUID
    var personID: UUID?
    var eventID: UUID?
    var visitID: UUID?
    var roleKey: String
    var displayRole: String
    var sortOrder: Int
    var nameSnapshot: String
    var memo: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ link: EventPersonLink) {
        id = link.id
        personID = link.person?.id
        eventID = link.event?.id
        visitID = link.visit?.id
        roleKey = link.roleKey
        displayRole = link.displayRole
        sortOrder = link.sortOrder
        nameSnapshot = link.nameSnapshot
        memo = link.memo
        isArchived = link.isArchived
        createdAt = link.createdAt
        updatedAt = link.updatedAt
    }
}

struct BackupPlace: Codable {
    var id: UUID
    var name: String
    var reading: String
    var aliasesRaw: String
    var placeTagsRaw: String
    var address: String
    var latitude: Double
    var longitude: Double
    var officialURL: String
    var memo: String
    var externalIDsRaw: String
    var sourceSnapshotRaw: String
    var normalizedName: String
    var normalizedAddress: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ place: PlaceMaster) {
        id = place.id
        name = place.name
        reading = place.reading
        aliasesRaw = place.aliasesRaw
        placeTagsRaw = place.placeTagsRaw
        address = place.address
        latitude = place.latitude
        longitude = place.longitude
        officialURL = place.officialURL
        memo = place.memo
        externalIDsRaw = place.externalIDsRaw
        sourceSnapshotRaw = place.sourceSnapshotRaw
        normalizedName = place.normalizedName
        normalizedAddress = place.normalizedAddress
        isArchived = place.isArchived
        createdAt = place.createdAt
        updatedAt = place.updatedAt
    }
}

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            self.text = ""
            return
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
