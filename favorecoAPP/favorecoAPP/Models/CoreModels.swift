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

    @Relationship(deleteRule: .nullify, inverse: \Plan.category)
    var plans: [Plan]? = []

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
    @Attribute(.externalStorage) var imageData: Data?
    var musicBrainzID: String = ""
    var wikidataQID: String = ""
    var appleMusicID: String = ""
    var sourceSnapshotRaw: String = ""
    var normalizedName: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \EventPersonLink.person)
    var eventLinks: [EventPersonLink]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoriteProfile.person)
    var favoriteProfile: FavoriteProfile?

    @Relationship(deleteRule: .cascade, inverse: \FavoPin.person)
    var favoPins: [FavoPin]? = []

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
        imageData: Data? = nil,
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
        self.imageData = imageData
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
final class CompanionMaster {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var iconSymbol: String = "person.crop.circle"
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        normalizedName: String = "",
        iconSymbol: String = "person.crop.circle",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.iconSymbol = iconSymbol
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class FavoriteProfile {
    var id: UUID = UUID()
    var isFavorite: Bool = true
    var isPrimary: Bool = false
    var isPinned: Bool = false
    var sortOrder: Int = 0
    var startedAt: Date = Date()
    var hasStartedAt: Bool = false
    var includesStartDay: Bool = true
    var colorHex: String = "#8F5E73"
    var nickname: String = ""
    var imagePath: String = ""
    @Attribute(.externalStorage) var heroImageData: Data?
    @Attribute(.externalStorage) var iconImageData: Data?
    var originText: String = ""
    var memo: String = ""
    var showOnHome: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var person: PersonMaster?
    var event: ExperienceEvent?
    var place: PlaceMaster?

    @Relationship(deleteRule: .cascade, inverse: \FavoGalleryPhoto.profile)
    var galleryPhotos: [FavoGalleryPhoto]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoAnniversary.profile)
    var anniversaries: [FavoAnniversary]? = []

    var targetKind: FavoTargetKind {
        if person != nil { return .person }
        if place != nil { return .place }
        return .event
    }

    var targetID: UUID? {
        person?.id ?? event?.id ?? place?.id
    }

    init(
        id: UUID = UUID(),
        isFavorite: Bool = true,
        isPrimary: Bool = false,
        isPinned: Bool = false,
        sortOrder: Int = 0,
        startedAt: Date = Date(),
        hasStartedAt: Bool = false,
        includesStartDay: Bool = true,
        colorHex: String = "#8F5E73",
        nickname: String = "",
        imagePath: String = "",
        heroImageData: Data? = nil,
        iconImageData: Data? = nil,
        originText: String = "",
        memo: String = "",
        showOnHome: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        person: PersonMaster? = nil,
        event: ExperienceEvent? = nil,
        place: PlaceMaster? = nil
    ) {
        self.id = id
        self.isFavorite = isFavorite
        self.isPrimary = isPrimary
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.startedAt = startedAt
        self.hasStartedAt = hasStartedAt
        self.includesStartDay = includesStartDay
        self.colorHex = colorHex
        self.nickname = nickname
        self.imagePath = imagePath
        self.heroImageData = heroImageData
        self.iconImageData = iconImageData
        self.originText = originText
        self.memo = memo
        self.showOnHome = showOnHome
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.person = person
        self.event = event
        self.place = place
    }
}

@Model
final class FavoGalleryPhoto {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var capturedAt: Date = Date()
    var hasCapturedAt: Bool = false
    var memo: String = ""
    var isFavorite: Bool = false
    var byteCount: Int = 0
    var width: Int = 0
    var height: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Attribute(.externalStorage)
    var data: Data = Data()

    var profile: FavoriteProfile?
    var sourcePhoto: PhotoBlob?

    var resolvedData: Data {
        if !data.isEmpty { return data }
        return sourcePhoto?.data ?? Data()
    }

    var hasStoredData: Bool { byteCount > 0 && !resolvedData.isEmpty }

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        capturedAt: Date = Date(),
        hasCapturedAt: Bool = false,
        memo: String = "",
        isFavorite: Bool = false,
        byteCount: Int = 0,
        width: Int = 0,
        height: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        data: Data = Data(),
        profile: FavoriteProfile? = nil,
        sourcePhoto: PhotoBlob? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.capturedAt = capturedAt
        self.hasCapturedAt = hasCapturedAt
        self.memo = memo
        self.isFavorite = isFavorite
        self.byteCount = byteCount
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.data = data
        self.profile = profile
        self.sourcePhoto = sourcePhoto
    }
}

@Model
final class FavoAnniversary {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var profile: FavoriteProfile?

    init(
        id: UUID = UUID(),
        title: String = "",
        date: Date = Date(),
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        profile: FavoriteProfile? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.profile = profile
    }
}

enum FavoTargetKind: String, CaseIterable {
    case person
    case event
    case place

    var displayName: String {
        switch self {
        case .person: "人物・団体"
        case .event: "作品・体験"
        case .place: "場所"
        }
    }
}

@Model
final class FavoPin {
    var id: UUID = UUID()
    var targetKindKey: String = FavoTargetKind.event.rawValue
    var sortOrder: Int = 0
    var customTitle: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var person: PersonMaster?
    var event: ExperienceEvent?
    var place: PlaceMaster?

    var targetKind: FavoTargetKind {
        FavoTargetKind(rawValue: targetKindKey) ?? inferredTargetKind
    }

    var targetID: UUID? {
        switch targetKind {
        case .person: person?.id
        case .event: event?.id
        case .place: place?.id
        }
    }

    var isValid: Bool {
        switch targetKind {
        case .person: person != nil
        case .event: event != nil
        case .place: place != nil
        }
    }

    private var inferredTargetKind: FavoTargetKind {
        if person != nil { return .person }
        if place != nil { return .place }
        return .event
    }

    init(
        id: UUID = UUID(),
        targetKindKey: String = FavoTargetKind.event.rawValue,
        sortOrder: Int = 0,
        customTitle: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        person: PersonMaster? = nil,
        event: ExperienceEvent? = nil,
        place: PlaceMaster? = nil
    ) {
        self.id = id
        self.targetKindKey = targetKindKey
        self.sortOrder = sortOrder
        self.customTitle = customTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.person = person
        self.event = event
        self.place = place
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

struct PlacePilgrimageMembership: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var pilgrimageKey: String = ""
    var pilgrimageName: String = ""
    var siteNumber: Int?
    var siteNumberLabel: String = ""

    init(
        id: UUID = UUID(),
        pilgrimageKey: String = "",
        pilgrimageName: String = "",
        siteNumber: Int? = nil,
        siteNumberLabel: String = ""
    ) {
        self.id = id
        self.pilgrimageKey = pilgrimageKey
        self.pilgrimageName = pilgrimageName
        self.siteNumber = siteNumber
        self.siteNumberLabel = siteNumberLabel
    }

    nonisolated var resolvedNumberLabel: String {
        let trimmed = siteNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return siteNumber.map { "第\($0)番" } ?? ""
    }

    nonisolated static func decode(_ rawValue: String) -> [PlacePilgrimageMembership] {
        guard let data = rawValue.data(using: .utf8), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([PlacePilgrimageMembership].self, from: data)) ?? []
    }

    nonisolated static func encode(_ memberships: [PlacePilgrimageMembership]) -> String {
        let normalized = memberships.compactMap { membership -> PlacePilgrimageMembership? in
            var value = membership
            value.pilgrimageKey = value.pilgrimageKey.trimmingCharacters(in: .whitespacesAndNewlines)
            value.pilgrimageName = value.pilgrimageName.trimmingCharacters(in: .whitespacesAndNewlines)
            value.siteNumberLabel = value.siteNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.pilgrimageName.isEmpty else { return nil }
            return value
        }
        guard let data = try? JSONEncoder().encode(normalized) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    nonisolated static func merged(_ currentRawValue: String, _ sourceRawValue: String) -> String {
        var merged = decode(currentRawValue)
        var seen = Set(merged.map(mergeKey))
        for membership in decode(sourceRawValue) where seen.insert(mergeKey(membership)).inserted {
            merged.append(membership)
        }
        return encode(merged)
    }

    nonisolated private static func mergeKey(_ membership: PlacePilgrimageMembership) -> String {
        let route = membership.pilgrimageKey.isEmpty ? membership.pilgrimageName : membership.pilgrimageKey
        return "\(route.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current))|\(membership.siteNumber.map(String.init) ?? "")|\(membership.resolvedNumberLabel)"
    }
}

@Model
final class PlaceMaster {
    var id: UUID = UUID()
    var name: String = ""
    var reading: String = ""
    var aliasesRaw: String = ""
    var placeTagsRaw: String = ""
    var prefecture: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var officialURL: String = ""
    var memo: String = ""
    var externalIDsRaw: String = ""
    var sourceSnapshotRaw: String = ""
    var pilgrimageMembershipsRaw: String = "[]"
    var operationalStatusRaw: String = ""
    var normalizedName: String = ""
    var normalizedAddress: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Plan.placeMaster)
    var plans: [Plan]? = []

    @Relationship(deleteRule: .nullify, inverse: \Visit.placeMaster)
    var visits: [Visit]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoPin.place)
    var favoPins: [FavoPin]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoriteProfile.place)
    var favoriteProfile: FavoriteProfile?

    init(
        id: UUID = UUID(),
        name: String = "",
        reading: String = "",
        aliasesRaw: String = "",
        placeTagsRaw: String = "",
        prefecture: String = "",
        address: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        officialURL: String = "",
        memo: String = "",
        externalIDsRaw: String = "",
        sourceSnapshotRaw: String = "",
        pilgrimageMembershipsRaw: String = "[]",
        operationalStatusRaw: String = "",
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
        self.prefecture = prefecture
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.officialURL = officialURL
        self.memo = memo
        self.externalIDsRaw = externalIDsRaw
        self.sourceSnapshotRaw = sourceSnapshotRaw
        self.pilgrimageMembershipsRaw = pilgrimageMembershipsRaw
        self.operationalStatusRaw = operationalStatusRaw
        self.normalizedName = normalizedName
        self.normalizedAddress = normalizedAddress
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var operationalStatus: PlaceOperationalStatus {
        get { PlaceOperationalStatus(rawValue: operationalStatusRaw) ?? .unknown }
        set { operationalStatusRaw = newValue.rawValue }
    }

    var isClosed: Bool { operationalStatus == .closed }
}

enum PlaceOperationalStatus: String, CaseIterable, Identifiable {
    case unknown = ""
    case open
    case closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown: "未設定"
        case .open: "営業中"
        case .closed: "閉館・閉園"
        }
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
    var stateKey: String = "active"
    var memo: String = ""
    var importMemo: String = ""
    var unitFieldsRaw: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Attribute(.externalStorage)
    var eyecatchData: Data?

    var sakePolishingRatio: Double = 0
    var sakeMeterValue: Double = 0
    var sakeAcidity: Double = 0
    var alcoholPercentage: Double = 0

    var category: RecordCategory?

    @Relationship(deleteRule: .cascade, inverse: \Visit.event)
    var visits: [Visit]? = []

    @Relationship(deleteRule: .cascade, inverse: \Plan.event)
    var plans: [Plan]? = []

    @Relationship(deleteRule: .cascade, inverse: \EventPersonLink.event)
    var personLinks: [EventPersonLink]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoPin.event)
    var favoPins: [FavoPin]? = []

    @Relationship(deleteRule: .cascade, inverse: \FavoriteProfile.event)
    var favoriteProfile: FavoriteProfile?

    @Relationship(deleteRule: .cascade, inverse: \CollectibleItem.series)
    var collectibleItems: [CollectibleItem]? = []

    init(
        id: UUID = UUID(),
        title: String = "",
        seriesName: String = "",
        subTypeKey: String = "",
        organizerNameSnapshot: String = "",
        representativeEyecatchPath: String = "",
        officialURL: String = "",
        stateKey: String = "active",
        memo: String = "",
        importMemo: String = "",
        unitFieldsRaw: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        eyecatchData: Data? = nil,
        category: RecordCategory? = nil
    ) {
        self.id = id
        self.title = title
        self.seriesName = seriesName
        self.subTypeKey = subTypeKey
        self.organizerNameSnapshot = organizerNameSnapshot
        self.representativeEyecatchPath = representativeEyecatchPath
        self.officialURL = officialURL
        self.stateKey = stateKey
        self.memo = memo
        self.importMemo = importMemo
        self.unitFieldsRaw = unitFieldsRaw
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.eyecatchData = eyecatchData
        self.category = category
    }
}

@Model
final class Plan {
    var id: UUID = UUID()
    var title: String = ""
    var subtitle: String = ""
    var planKindKey: String = "performance"
    var stateKey: String = "planned"
    var startsAt: Date = Date()
    var endsAt: Date = Date()
    var opensAt: Date = Date()
    var venueNameSnapshot: String = ""
    var organizerNameSnapshot: String = ""
    var officialURL: String = ""
    var sourceURL: String = ""
    var memo: String = ""
    var notificationLeadTimeKey: String = "previousDay"
    var externalCalendarEventIdentifier: String = ""
    var unitFieldsRaw: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var category: RecordCategory?
    var event: ExperienceEvent?
    var placeMaster: PlaceMaster?
    var visit: Visit?

    @Relationship(deleteRule: .cascade, inverse: \TicketAttempt.plan)
    var ticketAttempts: [TicketAttempt]? = []

    init(
        id: UUID = UUID(),
        title: String = "",
        subtitle: String = "",
        planKindKey: String = "performance",
        stateKey: String = "planned",
        startsAt: Date = Date(),
        endsAt: Date = Date(),
        opensAt: Date = Date(),
        venueNameSnapshot: String = "",
        organizerNameSnapshot: String = "",
        officialURL: String = "",
        sourceURL: String = "",
        memo: String = "",
        notificationLeadTimeKey: String = "previousDay",
        externalCalendarEventIdentifier: String = "",
        unitFieldsRaw: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        category: RecordCategory? = nil,
        event: ExperienceEvent? = nil,
        placeMaster: PlaceMaster? = nil,
        visit: Visit? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.planKindKey = planKindKey
        self.stateKey = stateKey
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.opensAt = opensAt
        self.venueNameSnapshot = venueNameSnapshot
        self.organizerNameSnapshot = organizerNameSnapshot
        self.officialURL = officialURL
        self.sourceURL = sourceURL
        self.memo = memo
        self.notificationLeadTimeKey = notificationLeadTimeKey
        self.externalCalendarEventIdentifier = externalCalendarEventIdentifier
        self.unitFieldsRaw = unitFieldsRaw
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.event = event
        self.placeMaster = placeMaster
        self.visit = visit
    }
}

@Model
final class TicketAccount {
    var id: UUID = UUID()
    var serviceName: String = ""
    var accountTypeKey: String = "other"
    var siteURL: String = ""
    var loginID: String = ""
    var email: String = ""
    var memberNumber: String = ""
    var accountName: String = ""
    var membershipRank: String = ""
    var expiryDate: Date = Date.distantPast
    var annualFee: Int = 0
    var renewalNotify: Bool = false
    var note: String = ""
    var colorHex: String = "#6F8F7A"
    var keychainPasswordRef: String = ""
    var normalizedServiceName: String = ""
    var normalizedMemberNumber: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TicketAttempt.account)
    var ticketAttempts: [TicketAttempt]? = []

    init(
        id: UUID = UUID(),
        serviceName: String = "",
        accountTypeKey: String = "other",
        siteURL: String = "",
        loginID: String = "",
        email: String = "",
        memberNumber: String = "",
        accountName: String = "",
        membershipRank: String = "",
        expiryDate: Date = Date.distantPast,
        annualFee: Int = 0,
        renewalNotify: Bool = false,
        note: String = "",
        colorHex: String = "#6F8F7A",
        keychainPasswordRef: String = "",
        normalizedServiceName: String = "",
        normalizedMemberNumber: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.serviceName = serviceName
        self.accountTypeKey = accountTypeKey
        self.siteURL = siteURL
        self.loginID = loginID
        self.email = email
        self.memberNumber = memberNumber
        self.accountName = accountName
        self.membershipRank = membershipRank
        self.expiryDate = expiryDate
        self.annualFee = annualFee
        self.renewalNotify = renewalNotify
        self.note = note
        self.colorHex = colorHex
        self.keychainPasswordRef = keychainPasswordRef
        self.normalizedServiceName = normalizedServiceName
        self.normalizedMemberNumber = normalizedMemberNumber
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class TicketAttempt {
    var id: UUID = UUID()
    var statusKey: String = "interested"
    var entryRouteKey: String = ""
    var ticketSite: String = ""
    var holderName: String = ""
    var saleStartAt: Date = Date.distantPast
    var applyDeadlineAt: Date = Date.distantPast
    var resultAnnounceAt: Date = Date.distantPast
    var paymentDeadlineAt: Date = Date.distantPast
    var issueStartAt: Date = Date.distantPast
    var paidAt: Date = Date.distantPast
    var issuedAt: Date = Date.distantPast
    var price: Decimal = Decimal(0)
    var fee: Decimal = Decimal(0)
    var quantity: Int = 1
    var purchaseURL: String = ""
    var seatText: String = ""
    var notificationSettingsRaw: String = ""
    var unitFieldsRaw: String = ""
    var memo: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var plan: Plan?
    var account: TicketAccount?

    init(
        id: UUID = UUID(),
        statusKey: String = "interested",
        entryRouteKey: String = "",
        ticketSite: String = "",
        holderName: String = "",
        saleStartAt: Date = Date.distantPast,
        applyDeadlineAt: Date = Date.distantPast,
        resultAnnounceAt: Date = Date.distantPast,
        paymentDeadlineAt: Date = Date.distantPast,
        issueStartAt: Date = Date.distantPast,
        paidAt: Date = Date.distantPast,
        issuedAt: Date = Date.distantPast,
        price: Decimal = Decimal(0),
        fee: Decimal = Decimal(0),
        quantity: Int = 1,
        purchaseURL: String = "",
        seatText: String = "",
        notificationSettingsRaw: String = "",
        unitFieldsRaw: String = "",
        memo: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        plan: Plan? = nil,
        account: TicketAccount? = nil
    ) {
        self.id = id
        self.statusKey = statusKey
        self.entryRouteKey = entryRouteKey
        self.ticketSite = ticketSite
        self.holderName = holderName
        self.saleStartAt = saleStartAt
        self.applyDeadlineAt = applyDeadlineAt
        self.resultAnnounceAt = resultAnnounceAt
        self.paymentDeadlineAt = paymentDeadlineAt
        self.issueStartAt = issueStartAt
        self.paidAt = paidAt
        self.issuedAt = issuedAt
        self.price = price
        self.fee = fee
        self.quantity = quantity
        self.purchaseURL = purchaseURL
        self.seatText = seatText
        self.notificationSettingsRaw = notificationSettingsRaw
        self.unitFieldsRaw = unitFieldsRaw
        self.memo = memo
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.plan = plan
        self.account = account
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

    @Relationship(deleteRule: .nullify, inverse: \Plan.visit)
    var plans: [Plan]? = []

    @Relationship(deleteRule: .cascade, inverse: \EventPersonLink.visit)
    var personLinks: [EventPersonLink]? = []

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
    @Attribute(.externalStorage)
    var eyecatchData: Data?
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
        eyecatchData: Data? = nil,
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
        self.eyecatchData = eyecatchData
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
    var ocrText: String = ""
    var amount: Decimal = Decimal(0)
    var byteCount: Int = 0
    var width: Int = 0
    var height: Int = 0
    var createdAt: Date = Date()

    @Attribute(.externalStorage)
    var data: Data = Data()

    var visit: Visit?

    @Relationship(deleteRule: .cascade, inverse: \FavoGalleryPhoto.sourcePhoto)
    var favoGallerySelections: [FavoGalleryPhoto]? = []

    var hasStoredData: Bool {
        byteCount > 0
    }

    init(
        id: UUID = UUID(),
        relativePath: String = "",
        originalFilename: String = "",
        mediaKind: String = "photo",
        purpose: String = "memory",
        ocrText: String = "",
        amount: Decimal = Decimal(0),
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
        self.ocrText = ocrText
        self.amount = amount
        self.byteCount = byteCount
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.data = data
        self.visit = visit
    }
}
