//
//  CoreModels.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import Foundation
import SwiftData

@Model
final class RecordCategory {
    var id: UUID = UUID()
    var name: String = ""
    var iconSymbol: String = "square.grid.2x2"
    var colorHex: String = "#6F8F7A"
    var sortOrder: Int = 0
    var isBuiltIn: Bool = false
    var templateKey: String = ""
    var enabledUnitsRaw: String = ""
    var templateTypeKey: String = "free"
    var targetNameLabel: String = "対象"
    var recordUnitName: String = "回"
    var dateLabel: String = "日付"
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \ExperienceEvent.category)
    var events: [ExperienceEvent]? = []

    @Relationship(deleteRule: .nullify, inverse: \SocialAccount.category)
    var socialAccounts: [SocialAccount]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        iconSymbol: String = "square.grid.2x2",
        colorHex: String = "#6F8F7A",
        sortOrder: Int = 0,
        isBuiltIn: Bool = false,
        templateKey: String = "",
        enabledUnitsRaw: String = "",
        templateTypeKey: String = "free",
        targetNameLabel: String = "対象",
        recordUnitName: String = "回",
        dateLabel: String = "日付",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.templateKey = templateKey
        self.enabledUnitsRaw = enabledUnitsRaw
        self.templateTypeKey = templateTypeKey
        self.targetNameLabel = targetNameLabel
        self.recordUnitName = recordUnitName
        self.dateLabel = dateLabel
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SocialAccount {
    var id: UUID = UUID()
    var platformKey: String = "instagram"
    var label: String = ""
    var accountInput: String = ""
    var memo: String = ""
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var category: RecordCategory?

    init(
        id: UUID = UUID(),
        platformKey: String = "instagram",
        label: String = "",
        accountInput: String = "",
        memo: String = "",
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        category: RecordCategory? = nil
    ) {
        self.id = id
        self.platformKey = platformKey
        self.label = label
        self.accountInput = accountInput
        self.memo = memo
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
    }
}

@Model
final class PersonMaster {
    var id: UUID = UUID()
    var displayName: String = ""
    var reading: String = ""
    var aliasesRaw: String = ""
    var roleTagsRaw: String = ""
    var memo: String = ""
    var officialURL: String = ""
    var socialLinksRaw: String = ""
    var imagePath: String = ""
    var musicBrainzID: String = ""
    var wikidataQID: String = ""
    var appleMusicID: String = ""
    var sourceSnapshotRaw: String = ""
    var normalizedName: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        displayName: String = "",
        reading: String = "",
        aliasesRaw: String = "",
        roleTagsRaw: String = "",
        memo: String = "",
        officialURL: String = "",
        socialLinksRaw: String = "",
        imagePath: String = "",
        musicBrainzID: String = "",
        wikidataQID: String = "",
        appleMusicID: String = "",
        sourceSnapshotRaw: String = "",
        normalizedName: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.reading = reading
        self.aliasesRaw = aliasesRaw
        self.roleTagsRaw = roleTagsRaw
        self.memo = memo
        self.officialURL = officialURL
        self.socialLinksRaw = socialLinksRaw
        self.imagePath = imagePath
        self.musicBrainzID = musicBrainzID
        self.wikidataQID = wikidataQID
        self.appleMusicID = appleMusicID
        self.sourceSnapshotRaw = sourceSnapshotRaw
        self.normalizedName = normalizedName
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class EventPersonLink {
    var id: UUID = UUID()
    var roleKey: String = "other"
    var displayRole: String = ""
    var sortOrder: Int = 0
    var nameSnapshot: String = ""
    var memo: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var person: PersonMaster?
    var event: ExperienceEvent?
    var visit: Visit?

    init(
        id: UUID = UUID(),
        roleKey: String = "other",
        displayRole: String = "",
        sortOrder: Int = 0,
        nameSnapshot: String = "",
        memo: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        person: PersonMaster? = nil,
        event: ExperienceEvent? = nil,
        visit: Visit? = nil
    ) {
        self.id = id
        self.roleKey = roleKey
        self.displayRole = displayRole
        self.sortOrder = sortOrder
        self.nameSnapshot = nameSnapshot
        self.memo = memo
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.person = person
        self.event = event
        self.visit = visit
    }
}

@Model
final class PlaceMaster {
    var id: UUID = UUID()
    var name: String = ""
    var reading: String = ""
    var aliasesRaw: String = ""
    var placeTagsRaw: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var officialURL: String = ""
    var memo: String = ""
    var externalIDsRaw: String = ""
    var sourceSnapshotRaw: String = ""
    var normalizedName: String = ""
    var normalizedAddress: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        reading: String = "",
        aliasesRaw: String = "",
        placeTagsRaw: String = "",
        address: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        officialURL: String = "",
        memo: String = "",
        externalIDsRaw: String = "",
        sourceSnapshotRaw: String = "",
        normalizedName: String = "",
        normalizedAddress: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.reading = reading
        self.aliasesRaw = aliasesRaw
        self.placeTagsRaw = placeTagsRaw
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.officialURL = officialURL
        self.memo = memo
        self.externalIDsRaw = externalIDsRaw
        self.sourceSnapshotRaw = sourceSnapshotRaw
        self.normalizedName = normalizedName
        self.normalizedAddress = normalizedAddress
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ExperienceEvent {
    var id: UUID = UUID()
    var title: String = ""
    var seriesName: String = ""
    var subTypeKey: String = ""
    var organizerNameSnapshot: String = ""
    var representativeEyecatchPath: String = ""
    var officialURL: String = ""
    var memo: String = ""
    var unitFieldsRaw: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var sakePolishingRatio: Double = 0
    var sakeMeterValue: Double = 0
    var sakeAcidity: Double = 0
    var alcoholPercentage: Double = 0

    var category: RecordCategory?

    @Relationship(deleteRule: .cascade, inverse: \Visit.event)
    var visits: [Visit]? = []

    init(
        id: UUID = UUID(),
        title: String = "",
        seriesName: String = "",
        subTypeKey: String = "",
        organizerNameSnapshot: String = "",
        representativeEyecatchPath: String = "",
        officialURL: String = "",
        memo: String = "",
        unitFieldsRaw: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        category: RecordCategory? = nil
    ) {
        self.id = id
        self.title = title
        self.seriesName = seriesName
        self.subTypeKey = subTypeKey
        self.organizerNameSnapshot = organizerNameSnapshot
        self.representativeEyecatchPath = representativeEyecatchPath
        self.officialURL = officialURL
        self.memo = memo
        self.unitFieldsRaw = unitFieldsRaw
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
    }
}

@Model
final class Visit {
    var id: UUID = UUID()
    var visitedAt: Date = Date()
    var endedAt: Date = Date()
    var venueNameSnapshot: String = ""
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var eyecatchPath: String = ""
    var note: String = ""
    var tagNamesRaw: String = ""
    var companionNamesRaw: String = ""
    var amount: Decimal = Decimal(0)
    var latitude: Double = 0
    var longitude: Double = 0
    var unitFieldsRaw: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var event: ExperienceEvent?
    var placeMaster: PlaceMaster?

    @Relationship(deleteRule: .cascade, inverse: \PhotoBlob.visit)
    var photos: [PhotoBlob]? = []

    init(
        id: UUID = UUID(),
        visitedAt: Date = Date(),
        endedAt: Date = Date(),
        venueNameSnapshot: String = "",
        overallRating: Double = 0,
        outcomeKey: String = "",
        seatText: String = "",
        eyecatchPath: String = "",
        note: String = "",
        tagNamesRaw: String = "",
        companionNamesRaw: String = "",
        amount: Decimal = Decimal(0),
        latitude: Double = 0,
        longitude: Double = 0,
        unitFieldsRaw: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        event: ExperienceEvent? = nil,
        placeMaster: PlaceMaster? = nil
    ) {
        self.id = id
        self.visitedAt = visitedAt
        self.endedAt = endedAt
        self.venueNameSnapshot = venueNameSnapshot
        self.overallRating = overallRating
        self.outcomeKey = outcomeKey
        self.seatText = seatText
        self.eyecatchPath = eyecatchPath
        self.note = note
        self.tagNamesRaw = tagNamesRaw
        self.companionNamesRaw = companionNamesRaw
        self.amount = amount
        self.latitude = latitude
        self.longitude = longitude
        self.unitFieldsRaw = unitFieldsRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.event = event
        self.placeMaster = placeMaster
    }
}

@Model
final class InboxItem {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var sourceURL: String = ""
    var sourceKind: String = "manual"
    var targetTemplateKey: String = ""
    var state: String = "unresolved"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        sourceURL: String = "",
        sourceKind: String = "manual",
        targetTemplateKey: String = "",
        state: String = "unresolved",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.targetTemplateKey = targetTemplateKey
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PhotoBlob {
    var id: UUID = UUID()
    var relativePath: String = ""
    var originalFilename: String = ""
    var mediaKind: String = "photo"
    var purpose: String = "memory"
    var byteCount: Int = 0
    var width: Int = 0
    var height: Int = 0
    var createdAt: Date = Date()

    @Attribute(.externalStorage)
    var data: Data = Data()

    var visit: Visit?

    init(
        id: UUID = UUID(),
        relativePath: String = "",
        originalFilename: String = "",
        mediaKind: String = "photo",
        purpose: String = "memory",
        byteCount: Int = 0,
        width: Int = 0,
        height: Int = 0,
        createdAt: Date = Date(),
        data: Data = Data(),
        visit: Visit? = nil
    ) {
        self.id = id
        self.relativePath = relativePath
        self.originalFilename = originalFilename
        self.mediaKind = mediaKind
        self.purpose = purpose
        self.byteCount = byteCount
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.data = data
        self.visit = visit
    }
}
