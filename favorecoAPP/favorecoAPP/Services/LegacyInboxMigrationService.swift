import Foundation
import SwiftData

@MainActor
enum LegacyInboxMigrationService {
    static func migrateIfNeeded(in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<InboxItem>())
        guard !items.isEmpty else { return }

        let categories = try context.fetch(FetchDescriptor<RecordCategory>())
        let events = try context.fetch(FetchDescriptor<ExperienceEvent>())
        let existingEventIDs = Set(events.map(\.id))
        var changed = false

        for item in items {
            if item.state == "resolved" || existingEventIDs.contains(item.id) {
                context.delete(item)
                changed = true
                continue
            }

            guard let category = categories.first(where: { $0.templateKey == item.targetTemplateKey }) else {
                continue
            }

            let separated = separateLegacyBody(item.body)
            let event = ExperienceEvent(
                id: item.id,
                title: item.title,
                officialURL: item.sourceURL,
                stateKey: "interested",
                memo: separated.memo,
                importMemo: separated.importMemo,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                eyecatchData: item.eyecatchData,
                category: category
            )
            context.insert(event)
            context.delete(item)
            changed = true
        }

        if changed {
            try context.save()
        }
    }

    private static func separateLegacyBody(_ body: String) -> (memo: String, importMemo: String) {
        let marker = "\n\n読み取り結果\n"
        guard let range = body.range(of: marker) else {
            return (body, "")
        }
        return (
            String(body[..<range.lowerBound]),
            String(body[range.upperBound...])
        )
    }
}
