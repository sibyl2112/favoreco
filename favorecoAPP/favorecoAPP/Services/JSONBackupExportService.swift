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
    static let schemaVersion = 6

    static func makeBackupJSON(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        visits: [Visit],
        inboxItems: [InboxItem],
        photos: [PhotoBlob],
        socialAccounts: [SocialAccount],
        people: [PersonMaster],
        companions: [CompanionMaster],
        favoriteProfiles: [FavoriteProfile],
        favoPins: [FavoPin],
        personLinks: [EventPersonLink],
        places: [PlaceMaster],
        plans: [Plan],
        ticketAccounts: [TicketAccount],
        ticketAttempts: [TicketAttempt],
        includesPhotoBinaryData: Bool = false,
        isFullBackupManifest: Bool = false
    ) throws -> String {
        let envelope = FavorecoBackupEnvelope(
            appName: "favoreco",
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            note: isFullBackupManifest
                ? "Favoreco full backup manifest. Photo binary data is stored in the media directory."
                : "Manual JSON backup. Photo binary data is not included.",
            categories: categories.sorted { $0.sortOrder < $1.sortOrder }.map(BackupCategory.init),
            events: events.sorted { $0.updatedAt > $1.updatedAt }.map {
                BackupEvent($0, includesBinaryData: includesPhotoBinaryData || isFullBackupManifest)
            },
            visits: visits.sorted { $0.visitedAt > $1.visitedAt }.map(BackupVisit.init),
            inboxItems: inboxItems.sorted { $0.updatedAt > $1.updatedAt }.map {
                BackupInboxItem($0, includesBinaryData: includesPhotoBinaryData || isFullBackupManifest)
            },
            photos: photos.sorted { $0.createdAt > $1.createdAt }.map {
                BackupPhoto($0, includesBinaryData: includesPhotoBinaryData)
            },
            socialAccounts: socialAccounts.sorted { $0.sortOrder < $1.sortOrder }.map(BackupSocialAccount.init),
            people: people.sorted { $0.displayName < $1.displayName }.map(BackupPerson.init),
            companions: companions.sorted { $0.name < $1.name }.map(BackupCompanion.init),
            favoriteProfiles: favoriteProfiles.sorted { $0.sortOrder < $1.sortOrder }.map(BackupFavoriteProfile.init),
            favoPins: favoPins.sorted { $0.sortOrder < $1.sortOrder }.map(BackupFavoPin.init),
            personLinks: personLinks.sorted { $0.sortOrder < $1.sortOrder }.map(BackupPersonLink.init),
            places: places.sorted { $0.name < $1.name }.map(BackupPlace.init),
            plans: plans.sorted { $0.startsAt > $1.startsAt }.map(BackupPlan.init),
            ticketAccounts: ticketAccounts.sorted { $0.serviceName < $1.serviceName }.map(BackupTicketAccount.init),
            ticketAttempts: ticketAttempts.sorted { $0.updatedAt > $1.updatedAt }.map(BackupTicketAttempt.init)
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
    var companions: [BackupCompanion]?
    var favoriteProfiles: [BackupFavoriteProfile]?
    var favoPins: [BackupFavoPin]?
    var personLinks: [BackupPersonLink]
    var places: [BackupPlace]
    var plans: [BackupPlan]
    var ticketAccounts: [BackupTicketAccount]
    var ticketAttempts: [BackupTicketAttempt]
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
    var stateKey: String?
    var memo: String
    var importMemo: String?
    var eyecatchDataBase64: String?
    var unitFieldsRaw: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var sakePolishingRatio: Double
    var sakeMeterValue: Double
    var sakeAcidity: Double
    var alcoholPercentage: Double

    nonisolated init(_ event: ExperienceEvent, includesBinaryData: Bool = false) {
        id = event.id
        categoryID = event.category?.id
        title = event.title
        seriesName = event.seriesName
        subTypeKey = event.subTypeKey
        organizerNameSnapshot = event.organizerNameSnapshot
        representativeEyecatchPath = event.representativeEyecatchPath
        officialURL = event.officialURL
        stateKey = event.stateKey
        memo = event.memo
        importMemo = event.importMemo
        eyecatchDataBase64 = includesBinaryData ? event.eyecatchData?.base64EncodedString() : nil
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
    var eyecatchData: Data?
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ item: InboxItem, includesBinaryData: Bool = false) {
        id = item.id
        title = item.title
        body = item.body
        sourceURL = item.sourceURL
        sourceKind = item.sourceKind
        targetTemplateKey = item.targetTemplateKey
        state = item.state
        eyecatchData = includesBinaryData ? item.eyecatchData : nil
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
    var ocrText: String?
    var amount: Decimal?
    var byteCount: Int
    var width: Int
    var height: Int
    var createdAt: Date
    var includesBinaryData: Bool

    nonisolated init(_ photo: PhotoBlob, includesBinaryData: Bool = false) {
        id = photo.id
        visitID = photo.visit?.id
        relativePath = photo.relativePath
        originalFilename = photo.originalFilename
        mediaKind = photo.mediaKind
        purpose = photo.purpose
        ocrText = photo.ocrText
        amount = photo.amount
        byteCount = photo.byteCount
        width = photo.width
        height = photo.height
        createdAt = photo.createdAt
        self.includesBinaryData = includesBinaryData
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
    var imageDataBase64: String?
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
        imageDataBase64 = person.imageData?.base64EncodedString()
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

struct BackupCompanion: Codable {
    var id: UUID
    var name: String
    var normalizedName: String
    var iconSymbol: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ companion: CompanionMaster) {
        id = companion.id
        name = companion.name
        normalizedName = companion.normalizedName
        iconSymbol = companion.iconSymbol
        isArchived = companion.isArchived
        createdAt = companion.createdAt
        updatedAt = companion.updatedAt
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

struct BackupFavoriteProfile: Codable {
    var id: UUID
    var personID: UUID?
    var isFavorite: Bool
    var isPrimary: Bool
    var isPinned: Bool
    var sortOrder: Int
    var startedAt: Date
    var hasStartedAt: Bool
    var includesStartDay: Bool
    var colorHex: String
    var nickname: String
    var imagePath: String
    var originText: String
    var memo: String
    var showOnHome: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ profile: FavoriteProfile) {
        id = profile.id
        personID = profile.person?.id
        isFavorite = profile.isFavorite
        isPrimary = profile.isPrimary
        isPinned = profile.isPinned
        sortOrder = profile.sortOrder
        startedAt = profile.startedAt
        hasStartedAt = profile.hasStartedAt
        includesStartDay = profile.includesStartDay
        colorHex = profile.colorHex
        nickname = profile.nickname
        imagePath = profile.imagePath
        originText = profile.originText
        memo = profile.memo
        showOnHome = profile.showOnHome
        createdAt = profile.createdAt
        updatedAt = profile.updatedAt
    }
}

struct BackupFavoPin: Codable {
    var id: UUID
    var targetKindKey: String
    var sortOrder: Int
    var customTitle: String
    var personID: UUID?
    var eventID: UUID?
    var placeID: UUID?
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ pin: FavoPin) {
        id = pin.id
        targetKindKey = pin.targetKindKey
        sortOrder = pin.sortOrder
        customTitle = pin.customTitle
        personID = pin.person?.id
        eventID = pin.event?.id
        placeID = pin.place?.id
        createdAt = pin.createdAt
        updatedAt = pin.updatedAt
    }
}

struct BackupPlace: Codable {
    var id: UUID
    var name: String
    var reading: String
    var aliasesRaw: String
    var placeTagsRaw: String
    var prefecture: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var officialURL: String
    var memo: String
    var externalIDsRaw: String
    var sourceSnapshotRaw: String
    var pilgrimageMembershipsRaw: String?
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
        prefecture = place.prefecture
        address = place.address
        latitude = place.latitude
        longitude = place.longitude
        officialURL = place.officialURL
        memo = place.memo
        externalIDsRaw = place.externalIDsRaw
        sourceSnapshotRaw = place.sourceSnapshotRaw
        pilgrimageMembershipsRaw = place.pilgrimageMembershipsRaw
        normalizedName = place.normalizedName
        normalizedAddress = place.normalizedAddress
        isArchived = place.isArchived
        createdAt = place.createdAt
        updatedAt = place.updatedAt
    }
}

struct BackupPlan: Codable {
    var id: UUID
    var categoryID: UUID?
    var eventID: UUID?
    var placeID: UUID?
    var visitID: UUID?
    var title: String
    var subtitle: String
    var planKindKey: String
    var stateKey: String
    var startsAt: Date
    var endsAt: Date
    var opensAt: Date
    var venueNameSnapshot: String
    var organizerNameSnapshot: String
    var officialURL: String
    var sourceURL: String
    var memo: String
    var notificationLeadTimeKey: String
    var externalCalendarEventIdentifier: String
    var unitFieldsRaw: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ plan: Plan) {
        id = plan.id
        categoryID = plan.category?.id
        eventID = plan.event?.id
        placeID = plan.placeMaster?.id
        visitID = plan.visit?.id
        title = plan.title
        subtitle = plan.subtitle
        planKindKey = plan.planKindKey
        stateKey = plan.stateKey
        startsAt = plan.startsAt
        endsAt = plan.endsAt
        opensAt = plan.opensAt
        venueNameSnapshot = plan.venueNameSnapshot
        organizerNameSnapshot = plan.organizerNameSnapshot
        officialURL = plan.officialURL
        sourceURL = plan.sourceURL
        memo = plan.memo
        notificationLeadTimeKey = plan.notificationLeadTimeKey
        externalCalendarEventIdentifier = plan.externalCalendarEventIdentifier
        unitFieldsRaw = plan.unitFieldsRaw
        isArchived = plan.isArchived
        createdAt = plan.createdAt
        updatedAt = plan.updatedAt
    }
}

struct BackupTicketAccount: Codable {
    var id: UUID
    var serviceName: String
    var accountTypeKey: String
    var siteURL: String
    var loginID: String
    var email: String
    var memberNumber: String
    var accountName: String
    var membershipRank: String
    var expiryDate: Date
    var annualFee: Int
    var renewalNotify: Bool
    var note: String
    var colorHex: String
    var hasKeychainPasswordRef: Bool
    var normalizedServiceName: String
    var normalizedMemberNumber: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ account: TicketAccount) {
        id = account.id
        serviceName = account.serviceName
        accountTypeKey = account.accountTypeKey
        siteURL = account.siteURL
        loginID = account.loginID
        email = account.email
        memberNumber = account.memberNumber
        accountName = account.accountName
        membershipRank = account.membershipRank
        expiryDate = account.expiryDate
        annualFee = account.annualFee
        renewalNotify = account.renewalNotify
        note = account.note
        colorHex = account.colorHex
        hasKeychainPasswordRef = !account.keychainPasswordRef.isEmpty
        normalizedServiceName = account.normalizedServiceName
        normalizedMemberNumber = account.normalizedMemberNumber
        isArchived = account.isArchived
        createdAt = account.createdAt
        updatedAt = account.updatedAt
    }
}

struct BackupTicketAttempt: Codable {
    var id: UUID
    var planID: UUID?
    var accountID: UUID?
    var statusKey: String
    var entryRouteKey: String
    var ticketSite: String
    var holderName: String
    var saleStartAt: Date
    var applyDeadlineAt: Date
    var resultAnnounceAt: Date
    var paymentDeadlineAt: Date
    var issueStartAt: Date
    var paidAt: Date
    var issuedAt: Date
    var price: Decimal
    var fee: Decimal
    var quantity: Int
    var purchaseURL: String
    var seatText: String
    var notificationSettingsRaw: String
    var unitFieldsRaw: String
    var memo: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(_ attempt: TicketAttempt) {
        id = attempt.id
        planID = attempt.plan?.id
        accountID = attempt.account?.id
        statusKey = attempt.statusKey
        entryRouteKey = attempt.entryRouteKey
        ticketSite = attempt.ticketSite
        holderName = attempt.holderName
        saleStartAt = attempt.saleStartAt
        applyDeadlineAt = attempt.applyDeadlineAt
        resultAnnounceAt = attempt.resultAnnounceAt
        paymentDeadlineAt = attempt.paymentDeadlineAt
        issueStartAt = attempt.issueStartAt
        paidAt = attempt.paidAt
        issuedAt = attempt.issuedAt
        price = attempt.price
        fee = attempt.fee
        quantity = attempt.quantity
        purchaseURL = attempt.purchaseURL
        seatText = attempt.seatText
        notificationSettingsRaw = attempt.notificationSettingsRaw
        unitFieldsRaw = attempt.unitFieldsRaw
        memo = attempt.memo
        isArchived = attempt.isArchived
        createdAt = attempt.createdAt
        updatedAt = attempt.updatedAt
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
