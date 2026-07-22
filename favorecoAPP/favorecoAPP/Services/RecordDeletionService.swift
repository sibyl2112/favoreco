//
//  RecordDeletionService.swift
//  favorecoAPP
//
//  通常記録（Visit / ExperienceEvent）のハード削除と、関連モデルの安全な解除・削除を担う。
//  - PhotoBlob は Visit.photos の deleteRule = .cascade で自動削除される（CoreModels の Visit を参照）。
//  - EventPersonLink（event/visit 参照）と Plan.visit は inverse 未定義のため、ここで明示的に解除・削除する。
//  データモデル定義は変更しない（削除時の後始末のみ）。
//

import Foundation
import SwiftData

enum RecordDeletionService {
    struct ExternalCalendarDeletionTarget {
        let planID: UUID
        let eventIdentifier: String
    }

    struct EventDeletionResult {
        let externalCalendarTargets: [ExternalCalendarDeletionTarget]
    }

    struct ArchivedDeletionResult {
        let eventCount: Int
        let visitCount: Int
        let planCount: Int
        let attemptCount: Int
        let masterCount: Int
        let linkCount: Int
        let externalCalendarTargets: [ExternalCalendarDeletionTarget]

        var totalCount: Int {
            eventCount + visitCount + planCount + attemptCount + masterCount + linkCount
        }
    }

    struct AllDataDeletionResult {
        let deletedModelCount: Int
        let externalCalendarTargets: [ExternalCalendarDeletionTarget]
    }

    /// この記録（Visit）だけを削除する。Event は残す（配下の Visit が 0 件になっても自動削除しない）。
    /// PhotoBlob は cascade で削除。Plan.visit 参照は nil 解除、EventPersonLink の visit 参照は削除。
    @MainActor
    static func deleteVisit(_ visit: Visit, in context: ModelContext) throws {
        detachReferences(toVisitID: visit.id, in: context)
        context.delete(visit) // PhotoBlob は Visit.photos の .cascade で連鎖削除
        try context.save()
    }

    /// この対象（Event）と配下のすべての記録を削除する。
    /// Event の .cascade で Visit / Plan（さらに各 Visit の PhotoBlob、Plan の TicketAttempt）が連鎖削除される。
    /// inverse 未定義の EventPersonLink（event 参照・各 visit 参照）と、外部 Plan.visit 参照はここで後始末する。
    @MainActor
    static func deleteEvent(_ event: ExperienceEvent, in context: ModelContext) throws -> EventDeletionResult {
        let eventID = event.id
        let allLinks = (try? context.fetch(FetchDescriptor<EventPersonLink>())) ?? []
        let allPlans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        let visitIDs = Set((event.visits ?? []).map(\.id))
        let ownedPlans = allPlans.filter { $0.event?.id == eventID }
        let notificationTargets = ownedPlans.map { plan in
            (
                planID: plan.id,
                attemptIDs: (plan.ticketAttempts ?? []).map(\.id)
            )
        }
        let externalCalendarTargets = externalCalendarTargets(for: ownedPlans)

        // 配下 Visit を参照する Plan.visit を解除（Event 配下の Plan は cascade 対象だが、外部参照も安全に外す）
        for plan in allPlans where plan.visit.map({ visitIDs.contains($0.id) }) == true {
            plan.visit = nil
        }
        // event 参照・配下 visit 参照の EventPersonLink を削除
        for link in allLinks where link.event?.id == eventID || link.visit.map({ visitIDs.contains($0.id) }) == true {
            context.delete(link)
        }

        context.delete(event) // Visit / Plan は Event の .cascade、PhotoBlob / TicketAttempt はさらに cascade
        try context.save()

        for target in notificationTargets {
            for attemptID in target.attemptIDs {
                TicketNotificationScheduler.cancel(planID: target.planID, attemptID: attemptID)
            }
            TicketNotificationScheduler.cancel(planID: target.planID, attemptID: nil)
        }

        return EventDeletionResult(externalCalendarTargets: externalCalendarTargets)
    }

    /// 非表示済みのモデルだけを完全削除する。ジャンルは非表示設定として保持する。
    /// Archived Event/Plan の配下は cascade 対象なので、子を重ねて delete しない。
    @MainActor
    static func deleteArchivedData(in context: ModelContext) throws -> ArchivedDeletionResult {
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        let attempts = try context.fetch(FetchDescriptor<TicketAttempt>())
        let accounts = try context.fetch(FetchDescriptor<TicketAccount>())
        let socialAccounts = try context.fetch(FetchDescriptor<SocialAccount>())
        let people = try context.fetch(FetchDescriptor<PersonMaster>())
        let companions = try context.fetch(FetchDescriptor<CompanionMaster>())
        let places = try context.fetch(FetchDescriptor<PlaceMaster>())
        let links = try context.fetch(FetchDescriptor<EventPersonLink>())

        let archivedEvents = events.filter(\.isArchived)
        let archivedEventIDs = Set(archivedEvents.map(\.id))
        let archivedVisits = archivedEvents.flatMap { $0.visits ?? [] }
        let archivedVisitIDs = Set(archivedVisits.map(\.id))
        let archivedPlans = plans.filter { plan in
            plan.isArchived || plan.event.map { archivedEventIDs.contains($0.id) } == true
        }
        let archivedPlanIDs = Set(archivedPlans.map(\.id))
        let archivedAttempts = attempts.filter { attempt in
            attempt.isArchived || attempt.plan.map { archivedPlanIDs.contains($0.id) } == true
        }
        let archivedAccounts = accounts.filter(\.isArchived)
        let archivedPeople = people.filter(\.isArchived)
        let archivedCompanions = companions.filter(\.isArchived)
        let archivedPersonIDs = Set(archivedPeople.map(\.id))
        let archivedPlaces = places.filter(\.isArchived)
        let archivedSocialAccounts = socialAccounts.filter(\.isArchived)
        let externalCalendarTargets = externalCalendarTargets(for: archivedPlans)
        let archivedPlanNotificationIDs = archivedPlans.map(\.id)
        let archivedAttemptNotificationIDs = archivedAttempts.map(\.id)
        let archivedAccountNotificationIDs = archivedAccounts.map(\.id)

        let archivedLinks = links.filter { link in
            link.isArchived
            || link.event.map({ archivedEventIDs.contains($0.id) }) == true
            || link.visit.map({ archivedVisitIDs.contains($0.id) }) == true
            || link.person.map({ archivedPersonIDs.contains($0.id) }) == true
        }
        for link in archivedLinks {
            context.delete(link)
        }
        for attempt in archivedAttempts {
            if let plan = attempt.plan, archivedPlanIDs.contains(plan.id) { continue }
            context.delete(attempt)
        }
        for plan in archivedPlans {
            if let event = plan.event, archivedEventIDs.contains(event.id) { continue }
            context.delete(plan)
        }
        for event in archivedEvents {
            context.delete(event)
        }
        for account in archivedAccounts { context.delete(account) }
        for account in archivedSocialAccounts { context.delete(account) }
        for person in archivedPeople { context.delete(person) }
        for companion in archivedCompanions { context.delete(companion) }
        for place in archivedPlaces { context.delete(place) }

        try context.save()
        ThumbnailLoader.purge()

        for attemptID in archivedAttemptNotificationIDs {
            TicketNotificationScheduler.cancel(attemptID: attemptID)
        }
        for planID in archivedPlanNotificationIDs {
            TicketNotificationScheduler.cancel(planID: planID, attemptID: nil)
        }
        for accountID in archivedAccountNotificationIDs {
            TicketAccountNotificationScheduler.cancel(accountID: accountID)
        }

        return ArchivedDeletionResult(
            eventCount: archivedEvents.count,
            visitCount: archivedVisits.count,
            planCount: archivedPlans.count,
            attemptCount: archivedAttempts.count,
            masterCount: archivedAccounts.count
                + archivedSocialAccounts.count
                + archivedPeople.count
                + archivedCompanions.count
                + archivedPlaces.count,
            linkCount: archivedLinks.count,
            externalCalendarTargets: externalCalendarTargets
        )
    }

    /// 記録コンテンツをすべて削除し、標準ジャンルを再生成して初回選択へ戻す。
    /// 表示・入力補助などのUserDefaults設定は利用者の好みとして保持する。
    @MainActor
    static func deleteAllData(in context: ModelContext) throws -> AllDataDeletionResult {
        let categories = try context.fetch(FetchDescriptor<RecordCategory>())
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let inboxItems = try context.fetch(FetchDescriptor<InboxItem>())
        let photos = try context.fetch(FetchDescriptor<PhotoBlob>())
        let socialAccounts = try context.fetch(FetchDescriptor<SocialAccount>())
        let people = try context.fetch(FetchDescriptor<PersonMaster>())
        let companions = try context.fetch(FetchDescriptor<CompanionMaster>())
        let favoriteProfiles = try context.fetch(FetchDescriptor<FavoriteProfile>())
        let favoGalleryPhotos = try context.fetch(FetchDescriptor<FavoGalleryPhoto>())
        let favoAnniversaries = try context.fetch(FetchDescriptor<FavoAnniversary>())
        let favoPins = try context.fetch(FetchDescriptor<FavoPin>())
        let links = try context.fetch(FetchDescriptor<EventPersonLink>())
        let places = try context.fetch(FetchDescriptor<PlaceMaster>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        let accounts = try context.fetch(FetchDescriptor<TicketAccount>())
        let attempts = try context.fetch(FetchDescriptor<TicketAttempt>())
        let collectibleItems = try context.fetch(FetchDescriptor<CollectibleItem>())
        let collectibleTransactions = try context.fetch(FetchDescriptor<CollectibleTransaction>())
        let externalCalendarTargets = externalCalendarTargets(for: plans)
        let planNotificationIDs = plans.map(\.id)
        let attemptNotificationIDs = attempts.map(\.id)
        let accountNotificationIDs = accounts.map(\.id)

        let coreModelCount = categories.count + events.count + visits.count + inboxItems.count + photos.count
        let masterModelCount = socialAccounts.count + people.count + companions.count + favoriteProfiles.count + favoGalleryPhotos.count + favoAnniversaries.count + favoPins.count
        let planningModelCount = links.count + places.count + plans.count + accounts.count + attempts.count
        let collectionModelCount = collectibleItems.count + collectibleTransactions.count
        let deletedModelCount = coreModelCount + masterModelCount + planningModelCount + collectionModelCount

        // 親を先に削除し、親を持たない孤立モデルだけを個別削除する。
        for link in links { context.delete(link) }
        for event in events { context.delete(event) }
        for plan in plans where plan.event == nil { context.delete(plan) }
        for visit in visits where visit.event == nil { context.delete(visit) }
        for attempt in attempts where attempt.plan == nil { context.delete(attempt) }
        for item in collectibleItems where item.series == nil { context.delete(item) }
        for transaction in collectibleTransactions where transaction.item == nil { context.delete(transaction) }
        for photo in photos where photo.visit == nil { context.delete(photo) }
        for item in inboxItems { context.delete(item) }
        for account in socialAccounts { context.delete(account) }
        for pin in favoPins { context.delete(pin) }
        for photo in favoGalleryPhotos where photo.profile == nil { context.delete(photo) }
        for anniversary in favoAnniversaries where anniversary.profile == nil { context.delete(anniversary) }
        for profile in favoriteProfiles where profile.person == nil && profile.event == nil && profile.place == nil {
            context.delete(profile)
        }
        for person in people { context.delete(person) }
        for companion in companions { context.delete(companion) }
        for place in places { context.delete(place) }
        for account in accounts { context.delete(account) }
        for category in categories { context.delete(category) }

        // ジャンル0件の状態を保存しない。削除と標準ジャンル再生成を同じsaveに含める。
        let now = Date()
        for preset in CategoryPresetSeeder.presets {
            context.insert(RecordCategory(
                name: preset.name,
                iconSymbol: preset.iconSymbol,
                colorHex: preset.colorHex,
                sortOrder: preset.sortOrder,
                isBuiltIn: true,
                templateKey: preset.templateKey,
                enabledUnitsRaw: preset.enabledUnitsRaw,
                templateTypeKey: preset.templateTypeKey,
                targetNameLabel: preset.targetNameLabel,
                recordUnitName: preset.recordUnitName,
                dateLabel: preset.dateLabel,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            ))
        }

        try context.save()
        URLCache.shared.removeAllCachedResponses()
        ThumbnailLoader.purge()

        for attemptID in attemptNotificationIDs {
            TicketNotificationScheduler.cancel(attemptID: attemptID)
        }
        for planID in planNotificationIDs {
            TicketNotificationScheduler.cancel(planID: planID, attemptID: nil)
        }
        for accountID in accountNotificationIDs {
            TicketAccountNotificationScheduler.cancel(accountID: accountID)
        }

        UserDefaults.standard.set(false, forKey: AppStorageKeys.hasCompletedGenreOnboarding)
        SampleDataSeeder.resetAutomaticInsertionState()
        UserDefaults.standard.set(false, forKey: AppStorageKeys.hasMigratedLegacyFavoritesToFavoPins)

        return AllDataDeletionResult(
            deletedModelCount: deletedModelCount,
            externalCalendarTargets: externalCalendarTargets
        )
    }

    @MainActor
    private static func externalCalendarTargets(for plans: [Plan]) -> [ExternalCalendarDeletionTarget] {
        plans.compactMap { plan in
            let storedIdentifier = ExternalCalendarLinkStore.identifier(planID: plan.id)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let legacyIdentifier = plan.externalCalendarEventIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let identifier = storedIdentifier.isEmpty ? legacyIdentifier : storedIdentifier
            guard !identifier.isEmpty else { return nil }
            return ExternalCalendarDeletionTarget(planID: plan.id, eventIdentifier: identifier)
        }
    }

    /// 指定 Visit を参照する関連（Plan.visit / EventPersonLink.visit）を安全に解除・削除する。
    @MainActor
    private static func detachReferences(toVisitID visitID: UUID, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        for plan in plans where plan.visit?.id == visitID {
            plan.visit = nil
        }
        let links = (try? context.fetch(FetchDescriptor<EventPersonLink>())) ?? []
        for link in links where link.visit?.id == visitID {
            context.delete(link)
        }
    }
}
