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
import ImageIO
import Vision

struct AddExperienceView: View {
    let category: RecordCategory
    let onSave: (() -> Void)?

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @AppStorage(AppStorageKeys.afterSaveRecordAction) private var afterSaveRecordAction = "openDetail"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "officialInfo", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath = ""
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var isShowingPlaceSearch = false
    @State private var savedVisit: Visit?
    @State private var isShowingSavedDetail = false

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
            .sheet(isPresented: $isShowingPlaceSearch) {
                PlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    let preservesVenueName = draft.shouldPreserveVenueNameForAddressSearch
                    draft.apply(place: candidate, preservingVenueName: preservesVenueName)
                }
            }
            .navigationDestination(isPresented: $isShowingSavedDetail) {
                if let savedVisit {
                    SavedExperienceDetailView(visit: savedVisit) {
                        dismiss()
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
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty ? .optional : .entered
        case "advanced":
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
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
                selectedItems: $selectedPhotoItems,
                category: category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            goshuinBookFields(
                sizeKey: $draft.goshuinBookSizeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey
            )
        case "importOCR":
            OCRUnitEditor(ocrText: $draft.ocrText, selectedItems: $selectedOCRItems) { suggestion in
                switch suggestion.kind {
                case .title: draft.title = suggestion.value
                case .date: if let date = suggestion.dateValue { draft.visitedAt = date }
                case .venue:
                    draft.venueName = suggestion.value
                    draft.clearPlaceSelection()
                case .amount: draft.amountText = suggestion.value
                }
            }
        case "money":
            moneyFields(amountText: $draft.amountText)
        case "memo":
            memoEditor
        case "advanced":
            AdvancedUnitEditor(entries: $draft.advancedEntries)
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
            TextField(template.venuePlaceholder, text: venueNameBinding)
            placeSuggestionList(
                suggestions: usesInputSuggestionDictionary ? placeSuggestions(for: draft.venueName, from: placeMasters) : [],
                onSelect: { draft.apply(placeMaster: $0) }
            )
            placeSearchAssist(
                isEnabled: usesMapSearchAssist,
                address: venueAddressBinding,
                action: { isShowingPlaceSearch = true }
            )
            ratingSlider(label: template.ratingLabel, value: $draft.overallRating, text: draft.ratingLabel)
        }
    }

    private var officialInfoFields: some View {
        URLImportAssistEditor(
            officialURL: $draft.officialURL,
            title: $draft.title,
            seriesName: $draft.seriesName
        )
    }

    private var venueNameBinding: Binding<String> {
        Binding {
            draft.venueName
        } set: { value in
            draft.venueName = value
            draft.clearPlaceSelection()
        }
    }

    private var venueAddressBinding: Binding<String> {
        Binding {
            draft.venueAddress
        } set: { value in
            draft.venueAddress = value
            draft.clearPlaceCoordinates()
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
            eyecatchPath: coverPhotoPath,
            note: draft.trimmedNote,
            amount: parsedCurrencyAmount(from: draft.amountText),
            latitude: draft.latitude,
            longitude: draft.longitude,
            unitFieldsRaw: draft.makeUnitFields(for: category).encodedRawValue,
            createdAt: now,
            updatedAt: now,
            event: event,
            placeMaster: resolvePlaceMaster(for: draft.placeSnapshot, from: placeMasters, in: modelContext)
        )

        modelContext.insert(event)
        event.representativeEyecatchPath = coverPhotoPath
        modelContext.insert(visit)
        insertPendingPeople(for: event, visit: nil)
        insertPendingPhotos(for: visit)
        onSave?()

        do {
            try modelContext.save()
            Task { await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext) }
            lastUsedCategoryTemplateKey = category.templateKey
            if afterSaveRecordAction == "openDetail" {
                savedVisit = visit
                isShowingSavedDetail = true
            } else {
                dismiss()
            }
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
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "photos", "officialInfo", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath: String
    @State private var deletedPhotoIDs: Set<UUID> = []
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var deletedPersonLinkIDs: Set<UUID> = []
    @State private var isShowingPlaceSearch = false

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
        _coverPhotoPath = State(initialValue: visit.eyecatchPath)
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
            .sheet(isPresented: $isShowingPlaceSearch) {
                PlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    let preservesVenueName = draft.shouldPreserveVenueNameForAddressSearch
                    draft.apply(place: candidate, preservingVenueName: preservesVenueName)
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
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty ? .optional : .entered
        case "advanced":
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
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
                selectedItems: $selectedPhotoItems,
                category: event?.category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            goshuinBookFields(
                sizeKey: $draft.goshuinBookSizeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey
            )
        case "importOCR":
            OCRUnitEditor(ocrText: $draft.ocrText, selectedItems: $selectedOCRItems) { suggestion in
                switch suggestion.kind {
                case .title: draft.title = suggestion.value
                case .date: if let date = suggestion.dateValue { draft.visitedAt = date }
                case .venue:
                    draft.venueName = suggestion.value
                    draft.clearPlaceSelection()
                case .amount: draft.amountText = suggestion.value
                }
            }
        case "money":
            moneyFields(amountText: $draft.amountText)
        case "memo":
            memoEditor
        case "advanced":
            AdvancedUnitEditor(entries: $draft.advancedEntries)
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
            TextField(template.venuePlaceholder, text: venueNameBinding)
            placeSuggestionList(
                suggestions: usesInputSuggestionDictionary ? placeSuggestions(for: draft.venueName, from: placeMasters) : [],
                onSelect: { draft.apply(placeMaster: $0) }
            )
            placeSearchAssist(
                isEnabled: usesMapSearchAssist,
                address: venueAddressBinding,
                action: { isShowingPlaceSearch = true }
            )
            ratingSlider(label: template.ratingLabel, value: $draft.overallRating, text: draft.ratingLabel)
        }
    }

    private var officialInfoFields: some View {
        URLImportAssistEditor(
            officialURL: $draft.officialURL,
            title: $draft.title,
            seriesName: $draft.seriesName
        )
    }

    private var venueNameBinding: Binding<String> {
        Binding {
            draft.venueName
        } set: { value in
            draft.venueName = value
            draft.clearPlaceSelection()
        }
    }

    private var venueAddressBinding: Binding<String> {
        Binding {
            draft.venueAddress
        } set: { value in
            draft.venueAddress = value
            draft.clearPlaceCoordinates()
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
        let preservesWeather = visit.visitedAt == draft.visitedAt
            && visit.latitude == draft.latitude
            && visit.longitude == draft.longitude
        let existingUnitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)

        if let event {
            event.title = draft.trimmedTitle
            event.seriesName = draft.trimmedSeriesName
            event.officialURL = draft.trimmedOfficialURL
            event.updatedAt = now
        }

        visit.visitedAt = draft.visitedAt
        visit.endedAt = draft.visitedAt
        visit.venueNameSnapshot = draft.trimmedVenueName
        visit.latitude = draft.latitude
        visit.longitude = draft.longitude
        visit.placeMaster = resolvePlaceMaster(for: draft.placeSnapshot, from: placeMasters, in: modelContext)
        visit.overallRating = draft.overallRating
        visit.outcomeKey = draft.outcomeKey
        visit.seatText = draft.trimmedSeatText
        visit.eyecatchPath = coverPhotoPath
        visit.amount = parsedCurrencyAmount(from: draft.amountText)
        visit.note = draft.trimmedNote
        var updatedUnitFields = draft.makeUnitFields(for: event?.category)
        if preservesWeather {
            updatedUnitFields.copyWeather(from: existingUnitFields)
        }
        visit.unitFieldsRaw = updatedUnitFields.encodedRawValue
        visit.updatedAt = now
        deleteMarkedPersonLinks()
        insertPendingPeople(for: event, visit: nil)
        deleteMarkedPhotos()
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            Task { await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext) }
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
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @AppStorage(AppStorageKeys.afterSaveRecordAction) private var afterSaveRecordAction = "openDetail"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = VisitDraft()
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath = ""
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var isShowingPlaceSearch = false
    @State private var savedVisit: Visit?
    @State private var isShowingSavedDetail = false

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
            .sheet(isPresented: $isShowingPlaceSearch) {
                PlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    let preservesVenueName = draft.shouldPreserveVenueNameForAddressSearch
                    draft.apply(place: candidate, preservingVenueName: preservesVenueName)
                }
            }
            .navigationDestination(isPresented: $isShowingSavedDetail) {
                if let savedVisit {
                    SavedExperienceDetailView(visit: savedVisit) {
                        dismiss()
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
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "people":
            return pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan ? .entered : .optional
        case "advanced":
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
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
                selectedItems: $selectedPhotoItems,
                category: event.category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            goshuinBookFields(
                sizeKey: $draft.goshuinBookSizeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey
            )
        case "importOCR":
            OCRUnitEditor(
                ocrText: $draft.ocrText,
                selectedItems: $selectedOCRItems,
                supportsTitleSuggestion: false
            ) { suggestion in
                switch suggestion.kind {
                case .title: break
                case .date: if let date = suggestion.dateValue { draft.visitedAt = date }
                case .venue:
                    draft.venueName = suggestion.value
                    draft.clearPlaceSelection()
                case .amount: draft.amountText = suggestion.value
                }
            }
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
        case "advanced":
            AdvancedUnitEditor(entries: $draft.advancedEntries)
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
            TextField(template.venuePlaceholder, text: venueNameBinding)
            placeSuggestionList(
                suggestions: usesInputSuggestionDictionary ? placeSuggestions(for: draft.venueName, from: placeMasters) : [],
                onSelect: { draft.apply(placeMaster: $0) }
            )
            placeSearchAssist(
                isEnabled: usesMapSearchAssist,
                address: venueAddressBinding,
                action: { isShowingPlaceSearch = true }
            )
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

    private var venueNameBinding: Binding<String> {
        Binding {
            draft.venueName
        } set: { value in
            draft.venueName = value
            draft.clearPlaceSelection()
        }
    }

    private var venueAddressBinding: Binding<String> {
        Binding {
            draft.venueAddress
        } set: { value in
            draft.venueAddress = value
            draft.clearPlaceCoordinates()
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
            eyecatchPath: coverPhotoPath,
            note: draft.trimmedNote,
            amount: parsedCurrencyAmount(from: draft.amountText),
            latitude: draft.latitude,
            longitude: draft.longitude,
            unitFieldsRaw: draft.makeUnitFields(for: event.category).encodedRawValue,
            createdAt: now,
            updatedAt: now,
            event: event,
            placeMaster: resolvePlaceMaster(for: draft.placeSnapshot, from: placeMasters, in: modelContext)
        )

        event.updatedAt = now
        modelContext.insert(visit)
        insertPendingPeople(for: visit)
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            Task { await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext) }
            lastUsedCategoryTemplateKey = event.category?.templateKey ?? lastUsedCategoryTemplateKey
            if afterSaveRecordAction == "openDetail" {
                savedVisit = visit
                isShowingSavedDetail = true
            } else {
                dismiss()
            }
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

private struct SavedExperienceDetailView: View {
    let visit: Visit
    let onDone: () -> Void

    var body: some View {
        ExperienceDetailView(visit: visit)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完了") {
                        onDone()
                    }
                }
            }
    }
}

struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var officialURL: String = ""
    var visitedAt: Date = Date()
    var venueName: String = ""
    var venueAddress: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey: String = ""
    var goshuinBookSizeKey: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    var amountText: String = ""
    var note: String = ""

    init() {}

    init(visit: Visit) {
        title = visit.event?.title ?? ""
        seriesName = visit.event?.seriesName ?? ""
        officialURL = visit.event?.officialURL ?? ""
        visitedAt = visit.visitedAt
        venueName = visit.venueNameSnapshot
        venueAddress = visit.placeMaster?.address ?? ""
        latitude = visit.latitude
        longitude = visit.longitude
        overallRating = visit.overallRating
        outcomeKey = visit.outcomeKey
        seatText = visit.seatText
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        ocrText = unitFields.ocrText
        eyecatchAspectRatioKey = unitFields.eyecatchAspectRatioKey
        goshuinBookSizeKey = unitFields.goshuinBookSizeKey
        advancedEntries = unitFields.advancedEntries
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

    fileprivate var placeSnapshot: PlaceSnapshot {
        PlaceSnapshot(name: trimmedVenueName, address: venueAddress, latitude: latitude, longitude: longitude)
    }

    var mapSearchQuery: String {
        let address = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? trimmedVenueName : address
    }

    var shouldPreserveVenueNameForAddressSearch: Bool {
        !trimmedVenueName.isEmpty && !venueAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func apply(place: PlaceSearchCandidate, preservingVenueName: Bool) {
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
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
    }

    mutating func clearPlaceSelection() {
        venueAddress = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        latitude = 0
        longitude = 0
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAmountText: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOCRText: String {
        ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeatText: String {
        seatText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAdvancedEntries: [AdvancedFieldEntry] {
        advancedEntries
            .map(\.normalized)
            .filter { !$0.isEmpty }
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    func makeUnitFields(for category: RecordCategory?) -> VisitUnitFields {
        VisitUnitFields(
            ocrText: trimmedOCRText,
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty ? EyecatchAspectRatio.recommended(for: category).key : eyecatchAspectRatioKey,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries
        )
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
    var venueAddress: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey: String = ""
    var goshuinBookSizeKey: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    var amountText: String = ""
    var note: String = ""

    var trimmedVenueName: String {
        venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var placeSnapshot: PlaceSnapshot {
        PlaceSnapshot(name: trimmedVenueName, address: venueAddress, latitude: latitude, longitude: longitude)
    }

    var mapSearchQuery: String {
        let address = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? trimmedVenueName : address
    }

    var shouldPreserveVenueNameForAddressSearch: Bool {
        !trimmedVenueName.isEmpty && !venueAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func apply(place: PlaceSearchCandidate, preservingVenueName: Bool) {
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
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
    }

    mutating func clearPlaceSelection() {
        venueAddress = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        latitude = 0
        longitude = 0
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAmountText: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOCRText: String {
        ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeatText: String {
        seatText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAdvancedEntries: [AdvancedFieldEntry] {
        advancedEntries
            .map(\.normalized)
            .filter { !$0.isEmpty }
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    func makeUnitFields(for category: RecordCategory?) -> VisitUnitFields {
        VisitUnitFields(
            ocrText: trimmedOCRText,
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty ? EyecatchAspectRatio.recommended(for: category).key : eyecatchAspectRatioKey,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries
        )
    }

    var ratingLabel: String {
        if overallRating == 0 {
            return "未評価"
        }
        return String(format: "%.1f", overallRating)
    }
}

private struct PlaceSnapshot {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

@MainActor
private func resolvePlaceMaster(
    for snapshot: PlaceSnapshot,
    from placeMasters: [PlaceMaster],
    in modelContext: ModelContext
) -> PlaceMaster? {
    let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }

    let address = snapshot.address.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedName = normalizedPlaceText(name)
    let normalizedAddress = normalizedPlaceText(address)
    let matchedPlace = placeMasters.first { place in
        let sameName = place.normalizedName == normalizedName || normalizedPlaceText(place.name) == normalizedName
        let sameAddress = !normalizedAddress.isEmpty && (
            place.normalizedAddress == normalizedAddress || normalizedPlaceText(place.address) == normalizedAddress
        )
        let sameCoordinate = snapshot.latitude != 0 && snapshot.longitude != 0
            && abs(place.latitude - snapshot.latitude) < 0.00001
            && abs(place.longitude - snapshot.longitude) < 0.00001
        return sameCoordinate || (sameName && (normalizedAddress.isEmpty || sameAddress))
    }

    let now = Date()
    if let matchedPlace {
        if !address.isEmpty { matchedPlace.address = address }
        if snapshot.latitude != 0 || snapshot.longitude != 0 {
            matchedPlace.latitude = snapshot.latitude
            matchedPlace.longitude = snapshot.longitude
        }
        matchedPlace.normalizedName = normalizedName
        matchedPlace.normalizedAddress = normalizedAddress
        matchedPlace.updatedAt = now
        return matchedPlace
    }

    let place = PlaceMaster(
        name: name,
        address: address,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        normalizedName: normalizedName,
        normalizedAddress: normalizedAddress,
        createdAt: now,
        updatedAt: now
    )
    modelContext.insert(place)
    return place
}

private func normalizedPlaceText(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}

private func placeSuggestions(for query: String, from placeMasters: [PlaceMaster]) -> [PlaceMaster] {
    let normalizedQuery = normalizedPlaceText(query)
    guard !normalizedQuery.isEmpty else { return [] }
    return placeMasters
        .filter { !$0.isArchived }
        .filter { place in
            normalizedPlaceText(place.name).contains(normalizedQuery)
                || place.normalizedName.contains(normalizedQuery)
                || normalizedPlaceText(place.reading).contains(normalizedQuery)
                || normalizedPlaceText(place.aliasesRaw).contains(normalizedQuery)
        }
        .prefix(4)
        .map { $0 }
}

@ViewBuilder
private func placeSuggestionList(
    suggestions: [PlaceMaster],
    onSelect: @escaping (PlaceMaster) -> Void
) -> some View {
    if !suggestions.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
            Text("登録済みの場所")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            ForEach(suggestions) { place in
                Button {
                    onSelect(place)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .foregroundStyle(.primary)
                            if !place.address.isEmpty {
                                Text(place.address)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

@ViewBuilder
private func placeSearchAssist(isEnabled: Bool, address: Binding<String>, action: @escaping () -> Void) -> some View {
    if isEnabled {
        TextField("住所（地図では住所を優先）", text: address)
            .textContentType(.fullStreetAddress)
        Button(action: action) {
            Label("Apple Mapsから会場を選択", systemImage: "map")
        }
    }
}

private struct URLImportAssistEditor: View {
    @Binding var officialURL: String
    @Binding var title: String
    @Binding var seriesName: String

    @AppStorage(AppStorageKeys.usesURLImportAssist) private var usesURLImportAssist = true
    @State private var candidate: URLMetadataCandidate?
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("公式URL（任意）", text: $officialURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            if usesURLImportAssist {
                Button {
                    Task { await fetchMetadata() }
                } label: {
                    if isLoading {
                        Label("候補を取得中", systemImage: "hourglass")
                    } else {
                        Label("URLから候補を取得", systemImage: "link.badge.plus")
                    }
                }
                .disabled(isLoading || officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let candidate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("取得したタイトル")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(candidate.title)
                            .font(FavorecoTypography.bodyStrong)
                            .textSelection(.enabled)
                        HStack {
                            Button("タイトルに反映") {
                                title = candidate.title
                            }
                            .buttonStyle(.bordered)
                            Button("シリーズ名に反映") {
                                seriesName = candidate.title
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: officialURL) { _, _ in
            candidate = nil
            errorMessage = ""
        }
        .onChange(of: usesURLImportAssist) { _, isEnabled in
            if !isEnabled {
                candidate = nil
                errorMessage = ""
            }
        }
    }

    @MainActor
    private func fetchMetadata() async {
        isLoading = true
        candidate = nil
        errorMessage = ""
        defer { isLoading = false }
        do {
            let result = try await URLMetadataService.fetch(from: officialURL)
            candidate = result
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "候補を取得できませんでした。"
        }
    }
}

private struct PlaceSearchView: View {
    let initialQuery: String
    let onSelect: (PlaceSearchCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [PlaceSearchCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage = ""

    init(initialQuery: String, onSelect: @escaping (PlaceSearchCandidate) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("検索中")
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "検索できませんでした",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "会場を検索",
                        systemImage: "map",
                        description: Text("会場名や住所を入力してください")
                    )
                } else {
                    List(results) { candidate in
                        Button {
                            onSelect(candidate)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.name)
                                    .font(FavorecoTypography.bodyStrong)
                                    .foregroundStyle(.primary)
                                if !candidate.address.isEmpty {
                                    Text(candidate.address)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("会場を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "会場名・住所")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                guard !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                await search()
            }
        }
    }

    @MainActor
    private func search() async {
        isSearching = true
        errorMessage = ""
        defer { isSearching = false }
        do {
            results = try await PlaceSearchService.search(query: query)
        } catch {
            results = []
            errorMessage = "通信状態を確認して、もう一度お試しください。"
        }
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

    var relativePath: String {
        "local/\(id.uuidString).jpg"
    }

    func makePhotoBlob(visit: Visit) -> PhotoBlob {
        PhotoBlob(
            relativePath: relativePath,
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

private func goshuinBookFields(sizeKey: Binding<String>, aspectRatioKey: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Picker("御朱印帳サイズ", selection: sizeKey) {
            ForEach(GoshuinBookSize.all) { size in
                Text("\(size.name)（\(size.displaySize)）").tag(size.key)
            }
        }

        let selectedSize = GoshuinBookSize.option(for: sizeKey.wrappedValue)
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedSize.note)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text("御朱印写真はこのサイズ比に合わせて表示します。見開きや横向きの場合は、ここでサイズを変えてから写真を追加してください。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .onAppear {
        if sizeKey.wrappedValue.isEmpty {
            sizeKey.wrappedValue = GoshuinBookSize.standard.key
        }
        if aspectRatioKey.wrappedValue.isEmpty {
            aspectRatioKey.wrappedValue = EyecatchAspectRatio.goshuinStandard.key
        }
    }
    .onChange(of: sizeKey.wrappedValue) { _, newValue in
        let size = GoshuinBookSize.option(for: newValue)
        aspectRatioKey.wrappedValue = size.key == GoshuinBookSize.wide.key
            ? EyecatchAspectRatio.labelLandscape.key
            : EyecatchAspectRatio.goshuinStandard.key
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

private struct OCRImportSuggestion: Identifiable {
    enum Kind: String {
        case title, date, venue, amount

        var label: String {
            switch self {
            case .title: return "タイトル"
            case .date: return "日付"
            case .venue: return "会場・場所"
            case .amount: return "金額"
            }
        }

        var systemImage: String {
            switch self {
            case .title: return "textformat"
            case .date: return "calendar"
            case .venue: return "mappin.and.ellipse"
            case .amount: return "yensign.circle"
            }
        }
    }

    let kind: Kind
    let value: String
    let displayValue: String
    let dateValue: Date?

    var id: String { "\(kind.rawValue):\(value)" }
}

private enum OCRImportSuggestionParser {
    static func suggestions(from text: String) -> [OCRImportSuggestion] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var results: [OCRImportSuggestion] = []

        for line in lines {
            appendLabeled(from: line, labels: ["公演名", "イベント名", "作品名", "タイトル"], kind: .title, to: &results)
            appendLabeled(from: line, labels: ["会場", "劇場", "場所", "VENUE"], kind: .venue, to: &results)
            if let date = parsedDate(from: line) {
                results.append(OCRImportSuggestion(
                    kind: .date,
                    value: date.formatted(.iso8601.year().month().day()),
                    displayValue: date.formatted(date: .long, time: .omitted),
                    dateValue: date
                ))
            }
            if let amount = parsedAmount(from: line) {
                results.append(OCRImportSuggestion(kind: .amount, value: amount, displayValue: "¥\(amount)", dateValue: nil))
            }
        }

        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }

    private static func appendLabeled(
        from line: String,
        labels: [String],
        kind: OCRImportSuggestion.Kind,
        to results: inout [OCRImportSuggestion]
    ) {
        let uppercased = line.uppercased()
        guard let label = labels.first(where: { uppercased.hasPrefix($0.uppercased()) }) else { return }
        let value = String(line.dropFirst(label.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: " :：-　"))
        guard !value.isEmpty else { return }
        results.append(OCRImportSuggestion(kind: kind, value: value, displayValue: value, dateValue: nil))
    }

    private static func parsedDate(from line: String) -> Date? {
        let patterns = [#"20\d{2}[年./-]\d{1,2}[月./-]\d{1,2}日?"#, #"\d{1,2}月\d{1,2}日"#]
        guard let match = firstMatch(in: line, patterns: patterns) else { return nil }
        let normalized = match
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let components = normalized.split(separator: "-").compactMap { Int($0) }
        let calendar = Calendar.current
        if components.count == 3 {
            return calendar.date(from: DateComponents(year: components[0], month: components[1], day: components[2]))
        }
        if components.count == 2 {
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: Date()),
                month: components[0],
                day: components[1]
            ))
        }
        return nil
    }

    private static func parsedAmount(from line: String) -> String? {
        guard line.contains("¥") || line.contains("￥") || line.contains("円") else { return nil }
        let patterns = [#"[¥￥]\s*[0-9][0-9,]*"#, #"[0-9][0-9,]*\s*円"#]
        guard let match = firstMatch(in: line, patterns: patterns) else { return nil }
        let digits = match.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else { return nil }
        return String(value)
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = expression.firstMatch(in: text, range: range),
                  let swiftRange = Range(match.range, in: text) else { continue }
            return String(text[swiftRange])
        }
        return nil
    }
}

private struct OCRUnitEditor: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @Binding var ocrText: String
    @Binding var selectedItems: [PhotosPickerItem]
    var supportsTitleSuggestion = true
    let onApplySuggestion: (OCRImportSuggestion) -> Void
    @State private var isRecognizing = false
    @State private var statusText = ""
    @State private var suggestions: [OCRImportSuggestion] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if usesOCRImportAssist {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                    Label(isRecognizing ? "読み取り中" : "画像から読み取る", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRecognizing)
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        await recognize(from: newItems)
                        selectedItems.removeAll()
                    }
                }
            } else {
                Label("画像OCRは設定でOFFになっています", systemImage: "text.viewfinder")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if ocrText.isEmpty {
                    Text("読み取ったテキスト、または手入力の取込メモ")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $ocrText)
                    .frame(minHeight: 140)
            }

            if !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                advancedSuggestionSection
            }

            Text("基本OCRは読み取り結果をそのまま保存します。高度OCRの候補は確認して選んだ項目だけに反映され、自動で上書きしません。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: ocrText) { _, newValue in
            refreshSuggestions(from: newValue)
        }
        .onChange(of: purchaseManager.currentPlan) { _, _ in
            refreshSuggestions(from: ocrText)
        }
        .onAppear {
            refreshSuggestions(from: ocrText)
        }
    }

    @ViewBuilder
    private var advancedSuggestionSection: some View {
        if purchaseManager.currentPlan.includesLocalFullFeatures {
            VStack(alignment: .leading, spacing: 8) {
                Label("項目候補", systemImage: "wand.and.stars")
                    .font(FavorecoTypography.captionStrong)

                if suggestions.isEmpty {
                    Text("日付・金額、または「会場：」「公演名：」のようなラベル付き情報が見つかると候補を表示します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onApplySuggestion(suggestion)
                            statusText = "\(suggestion.kind.label)へ反映しました。"
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.kind.systemImage)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.kind.label)
                                        .font(FavorecoTypography.captionStrong)
                                    Text(suggestion.displayValue)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.turn.down.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        } else {
            Label("項目候補への振り分けはライト以上", systemImage: "lock.fill")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshSuggestions(from text: String) {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else {
            suggestions = []
            return
        }
        suggestions = OCRImportSuggestionParser.suggestions(from: text)
            .filter { supportsTitleSuggestion || $0.kind != .title }
    }

    @MainActor
    private func recognize(from items: [PhotosPickerItem]) async {
        guard usesOCRImportAssist, let item = items.first else { return }
        isRecognizing = true
        statusText = ""
        defer { isRecognizing = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            statusText = "画像を読み込めませんでした。"
            return
        }

        let recognizedText = await recognizedText(from: data)
        guard !recognizedText.isEmpty else {
            statusText = "文字を読み取れませんでした。必要なら手入力してください。"
            return
        }

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ocrText = recognizedText
        } else {
            ocrText += "\n\n" + recognizedText
        }
        statusText = "読み取り結果を追加しました。"
    }

    private func recognizedText(from data: Data) async -> String {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                return ""
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:])
            do {
                try handler.perform([request])
                return request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
            } catch {
                return ""
            }
        }.value
    }
}

private struct AdvancedUnitEditor: View {
    @Binding var entries: [AdvancedFieldEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text("ジャンル固有の項目を自由に追加できます。例: 精米歩合、所要時間、購入店舗、同行者メモなど。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach($entries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("項目名（例: 所要時間）", text: $entry.label)
                        TextField("値（例: 90分）", text: $entry.value, axis: .vertical)
                            .lineLimit(1...3)

                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Label("この項目を削除", systemImage: "minus.circle")
                        }
                        .font(FavorecoTypography.caption)
                    }
                    .padding(.vertical, 6)
                }
            }

            Button {
                entries.append(AdvancedFieldEntry())
            } label: {
                Label("項目を追加", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
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

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

private struct PeopleUnitEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]

    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true

    @State private var name = ""
    @State private var selectedRole = PersonRoleOption.defaultOption

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        guard usesInputSuggestionDictionary, !trimmedName.isEmpty else { return [] }
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
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.photoCompressionQuality) private var compressionQuality = 0.85
    @AppStorage(AppStorageKeys.photoAddStartMode) private var photoAddStartMode = "camera"
    let existingPhotos: [PhotoBlob]
    @Binding var deletedPhotoIDs: Set<UUID>
    @Binding var pendingPhotos: [PendingPhoto]
    @Binding var selectedItems: [PhotosPickerItem]
    let category: RecordCategory?
    @Binding var aspectRatioKey: String
    @Binding var coverPhotoPath: String
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailableAlert = false

    private var maxPhotoCount: Int {
        purchaseManager.currentPlan.includesLocalFullFeatures ? 30 : 10
    }

    private var selectedAspectRatio: EyecatchAspectRatio {
        EyecatchAspectRatio.option(for: aspectRatioKey, category: category)
    }

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

            Picker("カバー比率", selection: $aspectRatioKey) {
                ForEach(EyecatchAspectRatio.all) { ratio in
                    Text("\(ratio.name)（\(ratio.displayValue)）").tag(ratio.key)
                }
            }

            Text(selectedAspectRatio.note)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if currentPhotoCount == 0 {
                Text("思い出写真、半券写真、表紙画像などを追加できます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                photoGrid
            }

            if remainingPhotoSlots > 0 {
                photoAddControls
            } else {
                Label(photoLimitMessage, systemImage: "checkmark.circle")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if aspectRatioKey.isEmpty {
                aspectRatioKey = EyecatchAspectRatio.recommended(for: category).key
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePicker(
                onCapture: { image in
                    appendCapturedPhoto(image)
                    isShowingCamera = false
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .alert("カメラを使用できません", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラを起動できません。写真ライブラリから追加してください。")
        }
    }

    private var photoLimitMessage: String {
        if purchaseManager.currentPlan.includesLocalFullFeatures {
            return "写真上限の30枚に達しています"
        }
        if currentPhotoCount > maxPhotoCount {
            return "既存写真は保持します。無料枠では新しい写真を追加できません"
        }
        return "無料枠の10枚に達しています"
    }

    @ViewBuilder
    private var photoAddControls: some View {
        if photoAddStartMode == "library" {
            libraryPicker(label: "写真ライブラリから追加", prominent: true)
            cameraButton(label: "カメラで撮影", prominent: false)
        } else {
            cameraButton(label: "カメラで撮影", prominent: true)
            libraryPicker(label: "写真ライブラリから選ぶ", prominent: false)
        }
    }

    @ViewBuilder
    private func libraryPicker(label: String, prominent: Bool) -> some View {
        let picker = PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: remainingPhotoSlots,
            matching: .images
        ) {
            Label(label, systemImage: "photo.on.rectangle.angled")
                .frame(maxWidth: .infinity)
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await appendPhotos(from: newItems)
                selectedItems.removeAll()
            }
        }
        if prominent {
            picker.buttonStyle(.borderedProminent)
        } else {
            picker.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func cameraButton(label: String, prominent: Bool) -> some View {
        let button = Button {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                isShowingCameraUnavailableAlert = true
                return
            }
            isShowingCamera = true
        } label: {
            Label(label, systemImage: "camera")
                .frame(maxWidth: .infinity)
        }
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(existingPhotos) { photo in
                PhotoThumbnail(
                    image: UIImage(data: photo.data),
                    title: "保存済み",
                    aspectRatio: selectedAspectRatio.value,
                    isCover: coverPhotoPath == photo.relativePath,
                    onSetCover: {
                        coverPhotoPath = photo.relativePath
                    },
                    onDelete: {
                        deletedPhotoIDs.insert(photo.id)
                        selectFallbackCover(excluding: photo.relativePath)
                    }
                )
            }

            ForEach(pendingPhotos) { photo in
                PhotoThumbnail(
                    image: photo.image,
                    title: "追加予定",
                    aspectRatio: selectedAspectRatio.value,
                    isCover: coverPhotoPath == photo.relativePath,
                    onSetCover: {
                        coverPhotoPath = photo.relativePath
                    },
                    onDelete: {
                        pendingPhotos.removeAll { $0.id == photo.id }
                        selectFallbackCover(excluding: photo.relativePath)
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
                  let pendingPhoto = PendingPhoto.make(
                    from: data,
                    filename: item.itemIdentifier ?? "photo.jpg",
                    compressionQuality: compressionQuality
                  ) else {
                continue
            }
            pendingPhotos.append(pendingPhoto)
            if coverPhotoPath.isEmpty {
                coverPhotoPath = pendingPhoto.relativePath
            }
        }
    }

    private func selectFallbackCover(excluding path: String) {
        guard coverPhotoPath == path else { return }
        coverPhotoPath = existingPhotos
            .first(where: { $0.relativePath != path })?
            .relativePath
            ?? pendingPhotos.first(where: { $0.relativePath != path })?.relativePath
            ?? ""
    }

    private func appendCapturedPhoto(_ image: UIImage) {
        guard remainingPhotoSlots > 0,
              let data = image.jpegData(compressionQuality: 1),
              let pendingPhoto = PendingPhoto.make(
                from: data,
                filename: "camera-\(UUID().uuidString).jpg",
                compressionQuality: compressionQuality
              ) else {
            return
        }
        pendingPhotos.append(pendingPhoto)
        if coverPhotoPath.isEmpty {
            coverPhotoPath = pendingPhoto.relativePath
        }
    }
}

private struct PhotoThumbnail: View {
    let image: UIImage?
    let title: String
    let aspectRatio: Double
    let isCover: Bool
    let onSetCover: () -> Void
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
            .aspectRatio(CGFloat(aspectRatio), contentMode: .fill)
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

            VStack {
                Spacer()
                HStack {
                    Button(action: onSetCover) {
                        Image(systemName: isCover ? "star.fill" : "star")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isCover ? Color.yellow : Color.white)
                            .padding(7)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCover ? "カバー写真に設定済み" : "カバー写真に設定")
                    Spacer()
                }
            }
            .padding(5)
        }
    }
}

private extension PendingPhoto {
    static func make(from data: Data, filename: String, compressionQuality: Double) -> PendingPhoto? {
        guard let image = UIImage(data: data) else { return nil }
        let targetWidth: CGFloat = 1600
        let scale = min(1, targetWidth / max(image.size.width, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let redrawnImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        let safeQuality = min(max(compressionQuality, 0.5), 0.95)
        let compressedData = redrawnImage.jpegData(compressionQuality: safeQuality) ?? data

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
