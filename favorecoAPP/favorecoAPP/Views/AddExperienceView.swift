//
//  AddExperienceView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddExperienceView: View {
    let category: RecordCategory
    let onSave: (() -> Void)?

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "officialInfo", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var pendingPeople: [PendingPersonLink] = []

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    init(
        category: RecordCategory,
        initialDraft: AddExperienceDraft = AddExperienceDraft(),
        onSave: (() -> Void)? = nil
    ) {
        self.category = category
        self.onSave = onSave
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("入力ユニット") {
                    ForEach(activeUnitDefinitions(for: category)) { unit in
                        RecordUnitAccordion(
                            unit: unit,
                            status: addStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            addContent(for: unit)
                        }
                    }
                }
            }
            .navigationTitle("記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func binding(for unitID: String) -> Binding<Bool> {
        Binding {
            expandedUnitIDs.contains(unitID)
        } set: { isExpanded in
            if isExpanded {
                expandedUnitIDs.insert(unitID)
            } else {
                expandedUnitIDs.remove(unitID)
            }
        }
    }

    private func addStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "basic":
            return draft.canSave ? .entered : .required
        case "officialInfo":
            return draft.trimmedOfficialURL.isEmpty ? .optional : .entered
        case "people":
            return pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan ? .entered : .optional
        case "photos":
            return pendingPhotos.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty ? .optional : .entered
        default:
            return .planned
        }
    }

    @ViewBuilder
    private func addContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            targetFields
            Divider()
            visitFields
        case "officialInfo":
            officialInfoFields
        case "people":
            PeopleUnitEditor(
                existingLinks: [],
                deletedLinkIDs: .constant([]),
                pendingLinks: $pendingPeople,
                personMasters: personMasters
            )
        case "ticketPlan":
            ticketPlanFields(outcomeKey: $draft.outcomeKey, seatText: $draft.seatText)
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems
            )
        case "money":
            moneyFields(amountText: $draft.amountText)
        case "memo":
            memoEditor
        default:
            PendingUnitView(unit: unit)
        }
    }

    private var targetFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.targetSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            TextField(template.titlePlaceholder, text: $draft.title)
            TextField(template.seriesPlaceholder, text: $draft.seriesName)
        }
    }

    private var visitFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
            TextField(template.venuePlaceholder, text: $draft.venueName)
            ratingSlider(label: template.ratingLabel, value: $draft.overallRating, text: draft.ratingLabel)
        }
    }

    private var officialInfoFields: some View {
        TextField("公式URL（任意）", text: $draft.officialURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
    }

    private var memoEditor: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text(template.memoPlaceholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $draft.note)
                .frame(minHeight: 120)
        }
    }

    private func save() {
        let now = Date()
        let event = ExperienceEvent(
            title: draft.trimmedTitle,
            seriesName: draft.trimmedSeriesName,
            officialURL: draft.trimmedOfficialURL,
            createdAt: now,
            updatedAt: now,
            category: category
        )
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: draft.visitedAt,
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            outcomeKey: draft.outcomeKey,
            seatText: draft.trimmedSeatText,
            note: draft.trimmedNote,
            amount: parsedCurrencyAmount(from: draft.amountText),
            createdAt: now,
            updatedAt: now,
            event: event
        )

        modelContext.insert(event)
        modelContext.insert(visit)
        insertPendingPeople(for: event, visit: nil)
        insertPendingPhotos(for: visit)
        onSave?()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save experience: \(error)")
        }
    }

    private func insertPendingPhotos(for visit: Visit) {
        for pendingPhoto in pendingPhotos {
            modelContext.insert(pendingPhoto.makePhotoBlob(visit: visit))
        }
    }

    private func insertPendingPeople(for event: ExperienceEvent?, visit: Visit?) {
        for (index, pendingPerson) in pendingPeople.enumerated() {
            let person = findOrCreatePerson(named: pendingPerson.name, roleKey: pendingPerson.role.key)
            modelContext.insert(pendingPerson.makeEventPersonLink(person: person, event: event, visit: visit, sortOrder: index))
        }
    }

    private func findOrCreatePerson(named name: String, roleKey: String) -> PersonMaster {
        let normalizedName = normalizedPersonName(name)
        if let person = personMasters.first(where: { $0.normalizedName == normalizedName || normalizedPersonName($0.displayName) == normalizedName }) {
            person.updatedAt = Date()
            return person
        }

        let now = Date()
        let person = PersonMaster(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            roleTagsRaw: roleKey,
            normalizedName: normalizedName,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(person)
        return person
    }
}

struct EditExperienceView: View {
    let visit: Visit

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "photos", "officialInfo", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var deletedPhotoIDs: Set<UUID> = []
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var deletedPersonLinkIDs: Set<UUID> = []

    private var event: ExperienceEvent? {
        visit.event
    }

    private var category: RecordCategory? {
        event?.category
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    init(visit: Visit) {
        self.visit = visit
        _draft = State(initialValue: AddExperienceDraft(visit: visit))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("入力ユニット") {
                    ForEach(activeUnitDefinitions(for: category)) { unit in
                        RecordUnitAccordion(
                            unit: unit,
                            status: editStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            editContent(for: unit)
                        }
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func binding(for unitID: String) -> Binding<Bool> {
        Binding {
            expandedUnitIDs.contains(unitID)
        } set: { isExpanded in
            if isExpanded {
                expandedUnitIDs.insert(unitID)
            } else {
                expandedUnitIDs.remove(unitID)
            }
        }
    }

    private func editStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "basic":
            return draft.canSave ? .entered : .required
        case "officialInfo":
            return draft.trimmedOfficialURL.isEmpty ? .optional : .entered
        case "people":
            return visiblePersonLinks.isEmpty && pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan ? .entered : .optional
        case "photos":
            return visibleExistingPhotos.isEmpty && pendingPhotos.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty ? .optional : .entered
        default:
            return .planned
        }
    }

    @ViewBuilder
    private func editContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            targetFields
            Divider()
            visitFields
        case "officialInfo":
            officialInfoFields
        case "people":
            PeopleUnitEditor(
                existingLinks: visiblePersonLinks,
                deletedLinkIDs: $deletedPersonLinkIDs,
                pendingLinks: $pendingPeople,
                personMasters: personMasters
            )
        case "ticketPlan":
            ticketPlanFields(outcomeKey: $draft.outcomeKey, seatText: $draft.seatText)
        case "photos":
            PhotoUnitEditor(
                existingPhotos: visibleExistingPhotos,
                deletedPhotoIDs: $deletedPhotoIDs,
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems
            )
        case "money":
            moneyFields(amountText: $draft.amountText)
        case "memo":
            memoEditor
        default:
            PendingUnitView(unit: unit)
        }
    }

    private var targetFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.targetSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            TextField(template.titlePlaceholder, text: $draft.title)
            TextField(template.seriesPlaceholder, text: $draft.seriesName)
        }
    }

    private var visitFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
            TextField(template.venuePlaceholder, text: $draft.venueName)
            ratingSlider(label: template.ratingLabel, value: $draft.overallRating, text: draft.ratingLabel)
        }
    }

    private var officialInfoFields: some View {
        TextField("公式URL（任意）", text: $draft.officialURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
    }

    private var memoEditor: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text(template.memoPlaceholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $draft.note)
                .frame(minHeight: 120)
        }
    }

    private func save() {
        let now = Date()

        if let event {
            event.title = draft.trimmedTitle
            event.seriesName = draft.trimmedSeriesName
            event.officialURL = draft.trimmedOfficialURL
            event.updatedAt = now
        }

        visit.visitedAt = draft.visitedAt
        visit.endedAt = draft.visitedAt
        visit.venueNameSnapshot = draft.trimmedVenueName
        visit.overallRating = draft.overallRating
        visit.outcomeKey = draft.outcomeKey
        visit.seatText = draft.trimmedSeatText
        visit.amount = parsedCurrencyAmount(from: draft.amountText)
        visit.note = draft.trimmedNote
        visit.updatedAt = now
        deleteMarkedPersonLinks()
        insertPendingPeople(for: event, visit: nil)
        deleteMarkedPhotos()
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to update experience: \(error)")
        }
    }

    private var visibleExistingPhotos: [PhotoBlob] {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && !deletedPhotoIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var visiblePersonLinks: [EventPersonLink] {
        personLinks
            .filter { link in
                !link.isArchived
                    && !deletedPersonLinkIDs.contains(link.id)
                    && (link.event?.id == event?.id || link.visit?.id == visit.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func deleteMarkedPhotos() {
        guard let photos = visit.photos else { return }
        for photo in photos where deletedPhotoIDs.contains(photo.id) {
            modelContext.delete(photo)
        }
    }

    private func insertPendingPhotos(for visit: Visit) {
        for pendingPhoto in pendingPhotos {
            modelContext.insert(pendingPhoto.makePhotoBlob(visit: visit))
        }
    }

    private func deleteMarkedPersonLinks() {
        for link in personLinks where deletedPersonLinkIDs.contains(link.id) {
            modelContext.delete(link)
        }
    }

    private func insertPendingPeople(for event: ExperienceEvent?, visit: Visit?) {
        let startIndex = visiblePersonLinks.count
        for (offset, pendingPerson) in pendingPeople.enumerated() {
            let person = findOrCreatePerson(named: pendingPerson.name, roleKey: pendingPerson.role.key)
            modelContext.insert(pendingPerson.makeEventPersonLink(person: person, event: event, visit: visit, sortOrder: startIndex + offset))
        }
    }

    private func findOrCreatePerson(named name: String, roleKey: String) -> PersonMaster {
        let normalizedName = normalizedPersonName(name)
        if let person = personMasters.first(where: { $0.normalizedName == normalizedName || normalizedPersonName($0.displayName) == normalizedName }) {
            person.updatedAt = Date()
            return person
        }

        let now = Date()
        let person = PersonMaster(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            roleTagsRaw: roleKey,
            normalizedName: normalizedName,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(person)
        return person
    }
}

struct AddVisitView: View {
    let event: ExperienceEvent

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = VisitDraft()
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var pendingPeople: [PendingPersonLink] = []

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("入力ユニット") {
                    ForEach(activeUnitDefinitions(for: event.category)) { unit in
                        RecordUnitAccordion(
                            unit: unit,
                            status: visitStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            visitContent(for: unit)
                        }
                    }
                }
            }
            .navigationTitle("回を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    private func binding(for unitID: String) -> Binding<Bool> {
        Binding {
            expandedUnitIDs.contains(unitID)
        } set: { isExpanded in
            if isExpanded {
                expandedUnitIDs.insert(unitID)
            } else {
                expandedUnitIDs.remove(unitID)
            }
        }
    }

    private func visitStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "basic":
            return .entered
        case "memo":
            return draft.trimmedNote.isEmpty ? .optional : .entered
        case "photos":
            return pendingPhotos.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "people":
            return pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan ? .entered : .optional
        default:
            return .planned
        }
    }

    @ViewBuilder
    private func visitContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            eventSummary
            Divider()
            visitFields
        case "memo":
            memoEditor
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems
            )
        case "people":
            PeopleUnitEditor(
                existingLinks: [],
                deletedLinkIDs: .constant([]),
                pendingLinks: $pendingPeople,
                personMasters: personMasters
            )
        case "ticketPlan":
            ticketPlanFields(outcomeKey: $draft.outcomeKey, seatText: $draft.seatText)
        case "money":
            moneyFields(amountText: $draft.amountText)
        case "officialInfo":
            Text("公式URLや参考リンクは対象詳細で編集します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        default:
            PendingUnitView(unit: unit)
        }
    }

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title.isEmpty ? "記録" : event.title)
                .font(FavorecoTypography.bodyStrong)
            if !event.seriesName.isEmpty {
                Text(event.seriesName)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var visitFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.visitSectionTitle)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            DatePicker(template.dateLabel, selection: $draft.visitedAt, displayedComponents: .date)
            TextField(template.venuePlaceholder, text: $draft.venueName)
            ratingSlider(label: template.ratingLabel, value: $draft.overallRating, text: draft.ratingLabel)
        }
    }

    private var memoEditor: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text(template.memoPlaceholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $draft.note)
                .frame(minHeight: 120)
        }
    }

    private func save() {
        let now = Date()
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: draft.visitedAt,
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            outcomeKey: draft.outcomeKey,
            seatText: draft.trimmedSeatText,
            note: draft.trimmedNote,
            amount: parsedCurrencyAmount(from: draft.amountText),
            createdAt: now,
            updatedAt: now,
            event: event
        )

        event.updatedAt = now
        modelContext.insert(visit)
        insertPendingPeople(for: visit)
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save visit: \(error)")
        }
    }

    private func insertPendingPhotos(for visit: Visit) {
        for pendingPhoto in pendingPhotos {
            modelContext.insert(pendingPhoto.makePhotoBlob(visit: visit))
        }
    }

    private func insertPendingPeople(for visit: Visit) {
        for (index, pendingPerson) in pendingPeople.enumerated() {
            let person = findOrCreatePerson(named: pendingPerson.name, roleKey: pendingPerson.role.key)
            modelContext.insert(pendingPerson.makeEventPersonLink(person: person, event: nil, visit: visit, sortOrder: index))
        }
    }

    private func findOrCreatePerson(named name: String, roleKey: String) -> PersonMaster {
        let normalizedName = normalizedPersonName(name)
        if let person = personMasters.first(where: { $0.normalizedName == normalizedName || normalizedPersonName($0.displayName) == normalizedName }) {
            person.updatedAt = Date()
            return person
        }

        let now = Date()
        let person = PersonMaster(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            roleTagsRaw: roleKey,
            normalizedName: normalizedName,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(person)
        return person
    }
}

struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var officialURL: String = ""
    var visitedAt: Date = Date()
    var venueName: String = ""
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var amountText: String = ""
    var note: String = ""

    init() {}

    init(visit: Visit) {
        title = visit.event?.title ?? ""
        seriesName = visit.event?.seriesName ?? ""
        officialURL = visit.event?.officialURL ?? ""
        visitedAt = visit.visitedAt
        venueName = visit.venueNameSnapshot
        overallRating = visit.overallRating
        outcomeKey = visit.outcomeKey
        seatText = visit.seatText
        amountText = formattedCurrencyAmount(visit.amount)
        note = visit.note
    }

    init(inboxItem: InboxItem) {
        title = inboxItem.title
        officialURL = inboxItem.sourceURL
        note = inboxItem.body
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedVenueName: String {
        venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAmountText: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeatText: String {
        seatText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    var ratingLabel: String {
        if overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", overallRating)
    }
}

private struct VisitDraft {
    var visitedAt: Date = Date()
    var venueName: String = ""
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var amountText: String = ""
    var note: String = ""

    var trimmedVenueName: String {
        venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAmountText: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeatText: String {
        seatText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    var ratingLabel: String {
        if overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", overallRating)
    }
}

private struct PendingPhoto: Identifiable {
    let id = UUID()
    var data: Data
    var originalFilename: String
    var width: Int
    var height: Int

    var image: UIImage? {
        UIImage(data: data)
    }

    func makePhotoBlob(visit: Visit) -> PhotoBlob {
        PhotoBlob(
            relativePath: "local/\(id.uuidString).jpg",
            originalFilename: originalFilename,
            mediaKind: "photo",
            purpose: "memory",
            byteCount: data.count,
            width: width,
            height: height,
            createdAt: Date(),
            data: data,
            visit: visit
        )
    }
}

private struct PendingPersonLink: Identifiable {
    let id = UUID()
    var name: String
    var role: PersonRoleOption

    func makeEventPersonLink(
        person: PersonMaster,
        event: ExperienceEvent?,
        visit: Visit?,
        sortOrder: Int
    ) -> EventPersonLink {
        EventPersonLink(
            roleKey: role.key,
            displayRole: role.name,
            sortOrder: sortOrder,
            nameSnapshot: name.trimmingCharacters(in: .whitespacesAndNewlines),
            person: person,
            event: event,
            visit: visit
        )
    }
}

private struct PersonRoleOption: Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [PersonRoleOption] = [
        PersonRoleOption(key: "artist", name: "アーティスト"),
        PersonRoleOption(key: "cast", name: "出演"),
        PersonRoleOption(key: "lead", name: "主演"),
        PersonRoleOption(key: "writer", name: "作家"),
        PersonRoleOption(key: "author", name: "作者"),
        PersonRoleOption(key: "director", name: "監督"),
        PersonRoleOption(key: "screenplay", name: "脚本"),
        PersonRoleOption(key: "stage_director", name: "演出"),
        PersonRoleOption(key: "original_work", name: "原作"),
        PersonRoleOption(key: "music", name: "音楽"),
        PersonRoleOption(key: "performer", name: "演奏"),
        PersonRoleOption(key: "translator", name: "翻訳"),
        PersonRoleOption(key: "curator", name: "キュレーター"),
        PersonRoleOption(key: "organizer", name: "主催"),
        PersonRoleOption(key: "production", name: "制作"),
        PersonRoleOption(key: "publisher", name: "出版社"),
        PersonRoleOption(key: "guest", name: "ゲスト"),
        PersonRoleOption(key: "other", name: "その他"),
    ]

    static let defaultOption = PersonRoleOption(key: "cast", name: "出演")

    static func option(for key: String) -> PersonRoleOption {
        all.first(where: { $0.key == key }) ?? defaultOption
    }
}

private func activeUnitDefinitions(for category: RecordCategory?) -> [RecordUnitDefinition] {
    let definitions = RecordUnitDefinition.definitions(for: category?.enabledUnitsRaw ?? "")
    let fallbackDefinitions = RecordUnitDefinition.definitions(for: "basic,officialInfo,memo")
    let baseDefinitions = definitions.isEmpty ? fallbackDefinitions : definitions
    let requiredDefinitions = RecordUnitDefinition.all.filter { RecordUnitDefinition.requiredIDs.contains($0.id) }
    let mergedDefinitions = baseDefinitions + requiredDefinitions
    var seenIDs = Set<String>()
    return mergedDefinitions.filter { definition in
        guard !seenIDs.contains(definition.id) else { return false }
        seenIDs.insert(definition.id)
        return true
    }
}

private func normalizedPersonName(_ name: String) -> String {
    name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}

private func ratingSlider(label: String, value: Binding<Double>, text: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(label)
            Spacer()
            Text(text)
                .foregroundStyle(.secondary)
        }
        Slider(value: value, in: 0...5, step: 0.5)
    }
}

private func ticketPlanFields(outcomeKey: Binding<String>, seatText: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Picker("状態", selection: outcomeKey) {
            ForEach(TicketPlanOption.all) { option in
                Text(option.name).tag(option.key)
            }
        }

        TextField("座席・チケットメモ（例: 1階A列12番 / 整理番号B120）", text: seatText, axis: .vertical)
            .lineLimit(1...3)

        Text("申込、当落、入金、発券などの詳細期限は後続で専用項目に分けます。")
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func moneyFields(amountText: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        TextField("合計金額（例: 8500）", text: amountText)
            .keyboardType(.numberPad)
        Text("チケット代、購入額、交通費などの合計メモとして保存します。内訳管理は後続で追加します。")
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func parsedCurrencyAmount(from text: String) -> Decimal {
    let normalized = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "¥", with: "")
        .replacingOccurrences(of: "￥", with: "")
    return Decimal(string: normalized) ?? Decimal(0)
}

private func formattedCurrencyAmount(_ amount: Decimal) -> String {
    guard amount != Decimal(0) else { return "" }
    return NSDecimalNumber(decimal: amount).stringValue
}

private struct TicketPlanOption: Identifiable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [TicketPlanOption] = [
        TicketPlanOption(key: "", name: "未設定"),
        TicketPlanOption(key: "planned", name: "予定"),
        TicketPlanOption(key: "applied", name: "申込中"),
        TicketPlanOption(key: "won", name: "当選"),
        TicketPlanOption(key: "paid", name: "入金済み"),
        TicketPlanOption(key: "ticketed", name: "発券済み"),
        TicketPlanOption(key: "attended", name: "参加済み"),
        TicketPlanOption(key: "canceled", name: "中止・キャンセル")
    ]

    static func name(for key: String) -> String {
        all.first(where: { $0.key == key })?.name ?? key
    }
}

private struct PeopleUnitEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]

    @State private var name = ""
    @State private var selectedRole = PersonRoleOption.defaultOption

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        guard !trimmedName.isEmpty else { return [] }
        let normalizedInput = normalizedPersonName(trimmedName)
        return personMasters
            .filter { !$0.isArchived }
            .filter { person in
                normalizedPersonName(person.displayName).contains(normalizedInput)
                    || person.normalizedName.contains(normalizedInput)
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if existingLinks.isEmpty && pendingLinks.isEmpty {
                Text("出演者、作家、作者、主催、制作などを役割つきで追加できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                peopleList
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField("人物・団体名", text: $name)
                Picker("役割", selection: $selectedRole) {
                    ForEach(PersonRoleOption.all) { role in
                        Text(role.name).tag(role)
                    }
                }

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("似た人物・団体")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        ForEach(suggestions) { person in
                            Button {
                                name = person.displayName
                            } label: {
                                HStack {
                                    Text(person.displayName)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    appendPerson()
                } label: {
                    Label("人物・団体を追加", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var peopleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(existingLinks) { link in
                PeopleLinkRow(
                    name: link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物・団体" : link.nameSnapshot,
                    role: link.displayRole.isEmpty ? PersonRoleOption.option(for: link.roleKey).name : link.displayRole,
                    sourceLabel: "保存済み",
                    onDelete: {
                        deletedLinkIDs.insert(link.id)
                    }
                )
            }

            ForEach(pendingLinks) { link in
                PeopleLinkRow(
                    name: link.name,
                    role: link.role.name,
                    sourceLabel: "追加予定",
                    onDelete: {
                        pendingLinks.removeAll { $0.id == link.id }
                    }
                )
            }
        }
    }

    private func appendPerson() {
        pendingLinks.append(PendingPersonLink(name: trimmedName, role: selectedRole))
        name = ""
        selectedRole = .defaultOption
    }
}

private struct PeopleLinkRow: View {
    let name: String
    let role: String
    let sourceLabel: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(FavorecoTypography.bodyStrong)
                Text("\(role) ・ \(sourceLabel)")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)を削除")
        }
        .padding(.vertical, 4)
    }
}

private struct PhotoUnitEditor: View {
    let existingPhotos: [PhotoBlob]
    @Binding var deletedPhotoIDs: Set<UUID>
    @Binding var pendingPhotos: [PendingPhoto]
    @Binding var selectedItems: [PhotosPickerItem]

    private let maxPhotoCount = 10

    private var currentPhotoCount: Int {
        existingPhotos.count + pendingPhotos.count
    }

    private var remainingPhotoSlots: Int {
        max(0, maxPhotoCount - currentPhotoCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("写真")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text("\(currentPhotoCount)/\(maxPhotoCount)")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if currentPhotoCount == 0 {
                Text("思い出写真、半券写真、表紙画像などを追加できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                photoGrid
            }

            if remainingPhotoSlots > 0 {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: remainingPhotoSlots,
                    matching: .images
                ) {
                    Label("写真を追加", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        await appendPhotos(from: newItems)
                        selectedItems.removeAll()
                    }
                }
            } else {
                Label("無料枠の10枚に達しています", systemImage: "checkmark.circle")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(existingPhotos) { photo in
                PhotoThumbnail(
                    image: UIImage(data: photo.data),
                    title: "保存済み",
                    onDelete: {
                        deletedPhotoIDs.insert(photo.id)
                    }
                )
            }

            ForEach(pendingPhotos) { photo in
                PhotoThumbnail(
                    image: photo.image,
                    title: "追加予定",
                    onDelete: {
                        pendingPhotos.removeAll { $0.id == photo.id }
                    }
                )
            }
        }
    }

    @MainActor
    private func appendPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        for item in items.prefix(remainingPhotoSlots) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let pendingPhoto = PendingPhoto.make(from: data, filename: item.itemIdentifier ?? "photo.jpg") else {
                continue
            }
            pendingPhotos.append(pendingPhoto)
        }
    }
}

private struct PhotoThumbnail: View {
    let image: UIImage?
    let title: String
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title)の写真を削除")
        }
    }
}

private extension PendingPhoto {
    static func make(from data: Data, filename: String) -> PendingPhoto? {
        guard let image = UIImage(data: data) else { return nil }
        let targetWidth: CGFloat = 1600
        let scale = min(1, targetWidth / max(image.size.width, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let redrawnImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        let compressedData = redrawnImage.jpegData(compressionQuality: 0.85) ?? data

        return PendingPhoto(
            data: compressedData,
            originalFilename: filename,
            width: Int(targetSize.width),
            height: Int(targetSize.height)
        )
    }
}

private enum RecordUnitStatus {
    case required
    case entered
    case optional
    case planned

    var title: String {
        switch self {
        case .required:
            return "必須"
        case .entered:
            return "入力済み"
        case .optional:
            return "任意"
        case .planned:
            return "準備中"
        }
    }

    var color: Color {
        switch self {
        case .required:
            return .red
        case .entered:
            return .green
        case .optional:
            return .secondary
        case .planned:
            return .orange
        }
    }
}

private struct RecordUnitAccordion<Content: View>: View {
    let unit: RecordUnitDefinition
    let status: RecordUnitStatus
    @Binding var isExpanded: Bool
    let content: () -> Content

    init(
        unit: RecordUnitDefinition,
        status: RecordUnitStatus,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.unit = unit
        self.status = status
        _isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
                .padding(.top, 8)
                .padding(.bottom, 4)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.name)
                        .font(FavorecoTypography.bodyStrong)
                    Text(unit.description)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(status.title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.12), in: Capsule())
            }
        }
    }
}

private struct PendingUnitView: View {
    let unit: RecordUnitDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("このユニットの入力UIは準備中です。")
                .font(FavorecoTypography.body)
            Text("\(unit.name)はジャンル設定には含まれています。次の実装ステップで、ここに専用項目を接続します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AddExperienceView(category: RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45"))
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
