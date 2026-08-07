import Foundation

enum CrossGenreSearchKind: String, CaseIterable, Identifiable, Hashable {
    case interest
    case event
    case plan
    case visit
    case person
    case place

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interest: "気になる"
        case .event: "作品・体験"
        case .plan: "予定"
        case .visit: "記録"
        case .person: "人物・団体"
        case .place: "場所"
        }
    }

    var systemImage: String {
        switch self {
        case .interest: "bookmark"
        case .event: "square.stack.3d.up"
        case .plan: "calendar"
        case .visit: "sparkles.rectangle.stack"
        case .person: "person.2"
        case .place: "mappin.and.ellipse"
        }
    }
}

enum CrossGenreSearchTarget: Hashable {
    case event(UUID)
    case plan(UUID)
    case visit(UUID)
    case inbox(UUID)
    case person(UUID)
    case place(UUID)
}

enum CrossGenreCategoryFilter: Hashable {
    case all
    case category(UUID)
    case common
}

struct CrossGenreSearchCategory: Identifiable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int
}

struct CrossGenreSearchItem: Identifiable, Hashable {
    let id: String
    let kind: CrossGenreSearchKind
    let title: String
    let subtitle: String
    let categoryID: UUID?
    let categoryName: String
    let categoryTemplateKey: String
    let colorHex: String
    let systemImage: String
    let thumbnailReference: ThumbnailReference?
    let target: CrossGenreSearchTarget
    let sortDate: Date
    let normalizedTitle: String
    let normalizedSearchText: String
}

struct CrossGenreSearchSnapshot {
    let items: [CrossGenreSearchItem]
    let categories: [CrossGenreSearchCategory]

    @MainActor
    static func make(
        categories: [RecordCategory],
        events: [ExperienceEvent],
        plans: [Plan],
        visits: [Visit],
        inboxItems: [InboxItem],
        people: [PersonMaster],
        places: [PlaceMaster]
    ) -> CrossGenreSearchSnapshot {
        var items: [CrossGenreSearchItem] = []
        items.reserveCapacity(
            events.count + plans.count + visits.count + inboxItems.count + people.count + places.count
        )

        for event in events where !event.isArchived {
            let category = event.category
            let fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            let subtitle = firstNonempty([
                fields.eventSubtitle,
                event.seriesName,
                event.organizerNameSnapshot,
                event.memo,
            ])
            let kind: CrossGenreSearchKind = event.stateKey == "interested" ? .interest : .event
            items.append(makeItem(
                id: "event-\(event.id.uuidString)",
                kind: kind,
                title: event.title.isEmpty ? "無題" : event.title,
                subtitle: subtitle,
                category: category,
                fallbackColorHex: "#147C88",
                systemImage: category?.iconSymbol ?? kind.systemImage,
                thumbnailReference: .event(event.id),
                target: .event(event.id),
                sortDate: event.updatedAt,
                searchValues: [
                    event.title,
                    event.seriesName,
                    event.subTypeKey,
                    event.organizerNameSnapshot,
                    event.memo,
                    event.importMemo,
                    fields.eventSubtitle,
                    fields.eventCreditsText,
                    fields.eventVenues.map(\.name).joined(separator: " "),
                    category?.name ?? "",
                ]
            ))
        }

        for plan in plans where !plan.isArchived {
            let category = plan.category ?? plan.event?.category
            let title = firstNonempty([plan.title, plan.event?.title ?? "", "予定"])
            let dateText = FavorecoDateText.compactDateTime(plan.startsAt)
            let subtitle = [dateText, plan.venueNameSnapshot]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "・")
            items.append(makeItem(
                id: "plan-\(plan.id.uuidString)",
                kind: .plan,
                title: title,
                subtitle: subtitle,
                category: category,
                fallbackColorHex: "#147C88",
                systemImage: category?.iconSymbol ?? CrossGenreSearchKind.plan.systemImage,
                thumbnailReference: plan.event.map { .event($0.id) },
                target: .plan(plan.id),
                sortDate: plan.updatedAt,
                searchValues: [
                    title,
                    plan.subtitle,
                    plan.venueNameSnapshot,
                    plan.organizerNameSnapshot,
                    plan.memo,
                    plan.event?.title ?? "",
                    plan.event?.seriesName ?? "",
                    category?.name ?? "",
                ]
            ))
        }

        for visit in visits {
            let category = visit.event?.category
            let title = firstNonempty([visit.event?.title ?? "", "記録"])
            let subtitle = [
                FavorecoDateText.compactDate(visit.visitedAt),
                visit.venueNameSnapshot,
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "・")
            items.append(makeItem(
                id: "visit-\(visit.id.uuidString)",
                kind: .visit,
                title: title,
                subtitle: subtitle,
                category: category,
                fallbackColorHex: "#147C88",
                systemImage: category?.iconSymbol ?? CrossGenreSearchKind.visit.systemImage,
                thumbnailReference: visit.event.map { .event($0.id) },
                target: .visit(visit.id),
                sortDate: visit.updatedAt,
                searchValues: [
                    title,
                    visit.venueNameSnapshot,
                    visit.note,
                    visit.tagNamesRaw,
                    visit.companionNamesRaw,
                    visit.seatText,
                    visit.event?.seriesName ?? "",
                    category?.name ?? "",
                ]
            ))
        }

        for inbox in inboxItems where inbox.state == "unresolved" {
            let category = categories.first { $0.templateKey == inbox.targetTemplateKey }
            items.append(makeItem(
                id: "inbox-\(inbox.id.uuidString)",
                kind: .interest,
                title: inbox.title.isEmpty ? "無題" : inbox.title,
                subtitle: inbox.body,
                category: category,
                fallbackColorHex: "#147C88",
                systemImage: category?.iconSymbol ?? "tray",
                thumbnailReference: .inbox(inbox.id),
                target: .inbox(inbox.id),
                sortDate: inbox.updatedAt,
                searchValues: [inbox.title, inbox.body, inbox.sourceURL, category?.name ?? ""]
            ))
        }

        for person in people where !person.isArchived {
            let roleNames = PersonActivityTags.values(from: person.roleTagsRaw).joined(separator: "・")
            let subtitle = firstNonempty([roleNames, person.entityKind.displayName, person.memo])
            items.append(makeItem(
                id: "person-\(person.id.uuidString)",
                kind: .person,
                title: person.displayName.isEmpty ? "名前未設定" : person.displayName,
                subtitle: subtitle,
                category: nil,
                fallbackColorHex: "#8F5E73",
                systemImage: person.isOrganization ? "person.3" : "person.crop.circle",
                thumbnailReference: .person(person.id),
                target: .person(person.id),
                sortDate: person.updatedAt,
                searchValues: [
                    person.displayName,
                    person.reading,
                    person.aliasesRaw,
                    person.roleTagsRaw,
                    roleNames,
                    person.memo,
                ]
            ))
        }

        for place in places where !place.isArchived {
            let tags = place.placeTagsRaw
                .components(separatedBy: CharacterSet(charactersIn: ",、|\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "・")
            let subtitle = firstNonempty([place.address, place.prefecture, tags, place.memo])
            items.append(makeItem(
                id: "place-\(place.id.uuidString)",
                kind: .place,
                title: place.name.isEmpty ? "場所名未設定" : place.name,
                subtitle: subtitle,
                category: nil,
                fallbackColorHex: "#6F8F7A",
                systemImage: "mappin.and.ellipse",
                thumbnailReference: nil,
                target: .place(place.id),
                sortDate: place.updatedAt,
                searchValues: [
                    place.name,
                    place.reading,
                    place.aliasesRaw,
                    place.prefecture,
                    place.address,
                    place.placeTagsRaw,
                    tags,
                    place.memo,
                ]
            ))
        }

        let usedCategoryIDs = Set(items.compactMap(\.categoryID))
        let categoryFilters = categories
            .filter { usedCategoryIDs.contains($0.id) }
            .map {
                CrossGenreSearchCategory(
                    id: $0.id,
                    name: $0.name,
                    colorHex: $0.colorHex,
                    sortOrder: $0.sortOrder
                )
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return CrossGenreSearchSnapshot(
            items: items.sorted { lhs, rhs in
                if lhs.sortDate != rhs.sortDate { return lhs.sortDate > rhs.sortDate }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            },
            categories: categoryFilters
        )
    }

    @MainActor
    private static func makeItem(
        id: String,
        kind: CrossGenreSearchKind,
        title: String,
        subtitle: String,
        category: RecordCategory?,
        fallbackColorHex: String,
        systemImage: String,
        thumbnailReference: ThumbnailReference?,
        target: CrossGenreSearchTarget,
        sortDate: Date,
        searchValues: [String]
    ) -> CrossGenreSearchItem {
        CrossGenreSearchItem(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            categoryID: category?.id,
            categoryName: category?.name ?? "共通",
            categoryTemplateKey: category?.templateKey ?? "",
            colorHex: category?.colorHex ?? fallbackColorHex,
            systemImage: systemImage,
            thumbnailReference: thumbnailReference,
            target: target,
            sortDate: sortDate,
            normalizedTitle: normalizedCrossGenreSearchText(title),
            normalizedSearchText: normalizedCrossGenreSearchText(searchValues.joined(separator: " "))
        )
    }

    private static func firstNonempty(_ values: [String]) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }
}

nonisolated func normalizedCrossGenreSearchText(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: "　", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
