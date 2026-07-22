//
//  AddExperienceView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddExperienceView: View {
    let category: RecordCategory
    let onSave: (() -> Void)?

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
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
        var preparedDraft = initialDraft
        if preparedDraft.subTypeKey.isEmpty {
            switch category.templateKey {
            case "theme_park": preparedDraft.subTypeKey = OutingFacilityType.themePark.rawValue
            case "nature_living": preparedDraft.subTypeKey = OutingFacilityType.natureOther.rawValue
            default: break
            }
        }
        _draft = State(initialValue: preparedDraft)
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
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
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
            return draft.trimmedOfficialURL.isEmpty && draft.normalizedSocialLinks.isEmpty ? .optional : .entered
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
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func addContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            VStack(alignment: .leading, spacing: 12) {
                ExperienceBasicUnitEditor(
                    template: template,
                    title: $draft.title,
                    seriesName: $draft.seriesName,
                    visitedAt: $draft.visitedAt,
                    endedAt: $draft.endedAt,
                    styleNamesText: $draft.styleNamesText,
                    venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    overallRating: $draft.overallRating,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    placeMasters: placeMasters,
                    usesPlaceSuggestions: usesInputSuggestionDictionary,
                    usesMapSearchAssist: usesMapSearchAssist,
                    supportsPerformanceTime: category.usesOpeningTime,
                    supportsStyles: category.templateKey == "theater",
                    ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
                if category.isOutingFacilityGenre {
                    Divider()
                    OutingFacilityTypePicker(selection: $draft.subTypeKey)
                }
            }
        case "officialInfo":
            ExperienceOfficialInfoUnitEditor(
                officialURL: $draft.officialURL,
                socialLinksText: $draft.socialLinksText,
                title: $draft.title,
                seriesName: $draft.seriesName,
                visitedAt: $draft.visitedAt,
                venueName: venueNameBinding,
                venueAddress: venueAddressBinding,
                pendingPeople: $pendingPeople,
                advancedEntries: $draft.advancedEntries
            )
        case "people":
            PeopleUnitEditor(
                existingLinks: [],
                deletedLinkIDs: .constant([]),
                pendingLinks: $pendingPeople,
                personMasters: personMasters
            )
        case "ticketPlan":
            ExperienceTicketUnitEditor(
                outcomeKey: $draft.outcomeKey,
                seatText: $draft.seatText
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                existingPhotoMetadata: .constant([:]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            ExperienceGoshuinBookUnitEditor(
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
            ExperienceMoneyUnitEditor(amountText: $draft.amountText)
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
        default:
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
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
        let resolvedCategory = outingCategory(
            for: draft.subTypeKey,
            fallback: category,
            in: categories
        )
        if resolvedCategory?.isArchived == true {
            resolvedCategory?.isArchived = false
            resolvedCategory?.updatedAt = now
        }
        let event = ExperienceEvent(
            title: draft.trimmedTitle,
            seriesName: draft.trimmedSeriesName,
            subTypeKey: draft.subTypeKey,
            officialURL: draft.trimmedOfficialURL,
            unitFieldsRaw: draft.eventUnitFieldsRaw(for: category),
            createdAt: now,
            updatedAt: now,
            category: resolvedCategory
        )
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: max(draft.endedAt, draft.visitedAt),
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
            lastUsedCategoryTemplateKey = resolvedCategory?.templateKey ?? category.templateKey
            if afterSaveRecordAction == "openDetail" {
                savedVisit = visit
                isShowingSavedDetail = true
            } else {
                dismiss()
            }
        } catch {
            modelContext.rollback()
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
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
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
    @State private var existingPhotoMetadata: [UUID: PhotoMetadataDraft] = [:]
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
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
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
            return draft.trimmedOfficialURL.isEmpty && draft.normalizedSocialLinks.isEmpty ? .optional : .entered
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
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func editContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            VStack(alignment: .leading, spacing: 12) {
                ExperienceBasicUnitEditor(
                    template: template,
            title: $draft.title,
            seriesName: $draft.seriesName,
            visitedAt: $draft.visitedAt,
            endedAt: $draft.endedAt,
            styleNamesText: $draft.styleNamesText,
            venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    overallRating: $draft.overallRating,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    placeMasters: placeMasters,
            usesPlaceSuggestions: usesInputSuggestionDictionary,
            usesMapSearchAssist: usesMapSearchAssist,
            supportsPerformanceTime: category?.usesOpeningTime == true,
            supportsStyles: category?.templateKey == "theater",
            ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
                if category?.isOutingFacilityGenre == true {
                    Divider()
                    OutingFacilityTypePicker(selection: $draft.subTypeKey)
                }
            }
        case "officialInfo":
            ExperienceOfficialInfoUnitEditor(
                officialURL: $draft.officialURL,
                socialLinksText: $draft.socialLinksText,
                title: $draft.title,
                seriesName: $draft.seriesName,
                visitedAt: $draft.visitedAt,
                venueName: venueNameBinding,
                venueAddress: venueAddressBinding,
                pendingPeople: $pendingPeople,
                advancedEntries: $draft.advancedEntries
            )
        case "people":
            PeopleUnitEditor(
                existingLinks: visiblePersonLinks,
                deletedLinkIDs: $deletedPersonLinkIDs,
                pendingLinks: $pendingPeople,
                personMasters: personMasters
            )
        case "ticketPlan":
            ExperienceTicketUnitEditor(
                outcomeKey: $draft.outcomeKey,
                seatText: $draft.seatText
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: visibleExistingPhotos,
                deletedPhotoIDs: $deletedPhotoIDs,
                existingPhotoMetadata: $existingPhotoMetadata,
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: event?.category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            ExperienceGoshuinBookUnitEditor(
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
            ExperienceMoneyUnitEditor(amountText: $draft.amountText)
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
        default:
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
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
        let preservesWeather = visit.visitedAt == draft.visitedAt
            && visit.latitude == draft.latitude
            && visit.longitude == draft.longitude
        let existingUnitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)

        if let event {
            event.title = draft.trimmedTitle
            event.seriesName = draft.trimmedSeriesName
            if event.category?.isOutingFacilityGenre == true {
                event.subTypeKey = draft.subTypeKey
                let destination = outingCategory(
                    for: draft.subTypeKey,
                    fallback: event.category,
                    in: categories
                )
                if destination?.isArchived == true {
                    destination?.isArchived = false
                    destination?.updatedAt = now
                }
                event.category = destination
                for plan in event.plans ?? [] {
                    plan.category = destination
                    plan.updatedAt = now
                }
            }
            event.officialURL = draft.trimmedOfficialURL
            var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            eventFields.socialLinks = draft.normalizedSocialLinks
            if event.category?.templateKey == "book" {
                eventFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
            }
            event.unitFieldsRaw = eventFields.encodedRawValue
            event.updatedAt = now
        }

        visit.visitedAt = draft.visitedAt
        visit.endedAt = max(draft.endedAt, draft.visitedAt)
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
        applyExistingPhotoMetadata()
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

    private func applyExistingPhotoMetadata() {
        for photo in visibleExistingPhotos {
            guard let metadata = existingPhotoMetadata[photo.id] else { continue }
            photo.purpose = metadata.purpose.rawValue
            photo.ocrText = metadata.purpose.supportsAmount
                ? metadata.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            photo.amount = metadata.purpose.supportsAmount ? metadata.amount : Decimal(0)
            if metadata.purpose != .memory,
               event?.representativeEyecatchPath == photo.relativePath {
                event?.representativeEyecatchPath = coverPhotoPath
            }
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
    let sourcePlan: Plan?
    let onSave: (() -> Void)?

    @Query(sort: \PersonMaster.displayName) private var personMasters: [PersonMaster]
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @AppStorage(AppStorageKeys.afterSaveRecordAction) private var afterSaveRecordAction = "openDetail"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: VisitDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath = ""
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var isShowingPlaceSearch = false
    @State private var savedVisit: Visit?
    @State private var isShowingSavedDetail = false
    @State private var saveErrorMessage: String?

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    init(
        event: ExperienceEvent,
        initialDraft: VisitDraft = VisitDraft(),
        sourcePlan: Plan? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.event = event
        self.sourcePlan = sourcePlan
        self.onSave = onSave
        var preparedDraft = initialDraft
        if event.category?.templateKey == "book", preparedDraft.eyecatchAspectRatioKey.isEmpty {
            preparedDraft.eyecatchAspectRatioKey = EyecatchAspectRatio.resolved(for: event).key
        }
        _draft = State(initialValue: preparedDraft)
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
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
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
            .alert("保存に失敗しました", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
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
        case "officialInfo":
            let hasOfficialURL = !event.officialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasSocialLinks = !VisitUnitFields(rawValue: event.unitFieldsRaw).socialLinks.isEmpty
            return hasOfficialURL || hasSocialLinks ? .entered : .optional
        case "advanced":
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        default:
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func visitContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "basic":
            ExperienceBasicUnitEditor(
                template: template,
                eventTitle: event.title,
                eventSeriesName: event.seriesName,
                visitedAt: $draft.visitedAt,
                endedAt: $draft.endedAt,
                styleNamesText: $draft.styleNamesText,
                venueName: venueNameBinding,
                venueAddress: venueAddressBinding,
                overallRating: $draft.overallRating,
                latitude: draft.latitude,
                longitude: draft.longitude,
                placeMasters: placeMasters,
                usesPlaceSuggestions: usesInputSuggestionDictionary,
                usesMapSearchAssist: usesMapSearchAssist,
                supportsPerformanceTime: event.category?.usesOpeningTime == true,
                supportsStyles: event.category?.templateKey == "theater",
                ratingText: draft.ratingLabel,
                onSelectPlace: { draft.apply(placeMaster: $0) },
                onOpenPlaceSearch: { isShowingPlaceSearch = true }
            )
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                existingPhotoMetadata: .constant([:]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: event.category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath
            )
        case "goshuinBook":
            ExperienceGoshuinBookUnitEditor(
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
            ExperienceTicketUnitEditor(
                outcomeKey: $draft.outcomeKey,
                seatText: $draft.seatText
            )
        case "money":
            ExperienceMoneyUnitEditor(amountText: $draft.amountText)
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
        case "officialInfo":
            ExperienceOfficialInfoReferenceView()
        default:
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
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
        var attendedAttempt: TicketAttempt?
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: max(draft.endedAt, draft.visitedAt),
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

        event.stateKey = "active"
        if event.category?.templateKey == "book" {
            var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            eventFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
            event.unitFieldsRaw = eventFields.encodedRawValue
        }
        event.updatedAt = now
        if let sourcePlan {
            sourcePlan.visit = visit
            sourcePlan.stateKey = "attended"
            sourcePlan.updatedAt = now
            if let attempt = (sourcePlan.ticketAttempts ?? [])
                .filter({ !$0.isArchived })
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .first,
               !["lost", "skipped"].contains(attempt.statusKey) {
                attempt.statusKey = "attended"
                attempt.updatedAt = now
                attempt.notificationSettingsRaw = ""
                attendedAttempt = attempt
            }
        }
        modelContext.insert(visit)
        insertPendingPeople(for: visit)
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            if let sourcePlan {
                if let attendedAttempt {
                    TicketNotificationScheduler.cancel(plan: sourcePlan, attempt: attendedAttempt)
                }
                TicketNotificationScheduler.cancel(plan: sourcePlan, attempt: nil)
            }
            Task { await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext) }
            lastUsedCategoryTemplateKey = event.category?.templateKey ?? lastUsedCategoryTemplateKey
            onSave?()
            if afterSaveRecordAction == "openDetail" {
                savedVisit = visit
                isShowingSavedDetail = true
            } else {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = "記録を保存できませんでした。入力内容を確認して、もう一度お試しください。"
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
        ExperienceDetailView(visit: visit, onBack: onDone)
            .navigationBarBackButtonHidden()
    }
}

struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var subTypeKey: String = ""
    var officialURL: String = ""
    var socialLinksText: String = ""
    var visitedAt: Date = Date()
    var endedAt: Date = Date()
    var styleNamesText: String = ""
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
        subTypeKey = visit.event?.subTypeKey ?? ""
        officialURL = visit.event?.officialURL ?? ""
        socialLinksText = VisitUnitFields(rawValue: visit.event?.unitFieldsRaw ?? "").socialLinks.joined(separator: "\n")
        visitedAt = visit.visitedAt
        endedAt = visit.endedAt
        styleNamesText = VisitUnitFields(rawValue: visit.unitFieldsRaw).styleNames.joined(separator: "、")
        venueName = visit.venueNameSnapshot
        venueAddress = visit.placeMaster?.address ?? ""
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
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

    var normalizedSocialLinks: [String] {
        socialLinksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
            styleNames: normalizedStyleNames(from: styleNamesText),
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries
        )
    }

    func eventUnitFieldsRaw(for category: RecordCategory?) -> String {
        return VisitUnitFields(
            socialLinks: normalizedSocialLinks,
            eyecatchAspectRatioKey: category?.templateKey == "book"
                ? (eyecatchAspectRatioKey.isEmpty ? EyecatchAspectRatio.hardcoverBook.key : eyecatchAspectRatioKey)
                : ""
        ).encodedRawValue
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

private struct OutingFacilityTypePicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("施設種別", selection: $selection) {
                Text("未分類").tag("")
                ForEach(OutingFacilityType.allCases) { facilityType in
                    Text(facilityType.displayName).tag(facilityType.rawValue)
                }
            }
            .pickerStyle(.menu)

            Text("テーマパークと自然・いきものを分けて表示するために使います")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private func outingCategory(
    for subTypeKey: String,
    fallback: RecordCategory?,
    in categories: [RecordCategory]
) -> RecordCategory? {
    guard let fallback, fallback.isOutingFacilityGenre else { return fallback }
    let destinationTemplateKey = OutingFacilityType(rawValue: subTypeKey)?.destinationTemplateKey
        ?? "outing_facility"
    return categories.first(where: {
        $0.isBuiltIn && $0.templateKey == destinationTemplateKey
    }) ?? fallback
}

struct VisitDraft {
    var visitedAt: Date = Date()
    var endedAt: Date = Date()
    var styleNamesText: String = ""
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

    init(plan: Plan) {
        let attempt = (plan.ticketAttempts ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        visitedAt = plan.startsAt
        endedAt = max(plan.endsAt, plan.startsAt)
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        latitude = plan.placeMaster?.latitude ?? 0
        longitude = plan.placeMaster?.longitude ?? 0
        outcomeKey = "attended"
        seatText = attempt?.seatText ?? ""
        amountText = formattedCurrencyAmount(
            attempt.map { ($0.price + $0.fee) * Decimal($0.quantity) } ?? Decimal(0)
        )
        note = [
            plan.memo,
            attempt?.memo ?? "",
            plan.officialURL.isEmpty ? "" : "公式: \(plan.officialURL)",
            attempt?.purchaseURL.isEmpty == false ? "購入/申込: \(attempt?.purchaseURL ?? "")" : "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    init(inboxItem: InboxItem) {
        note = [inboxItem.body, inboxItem.sourceURL]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
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
            styleNames: normalizedStyleNames(from: styleNamesText),
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
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

struct PlaceSnapshot {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

@MainActor
func resolvePlaceMaster(
    for snapshot: PlaceSnapshot,
    from placeMasters: [PlaceMaster],
    in modelContext: ModelContext
) -> PlaceMaster? {
    let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }

    let address = snapshot.address.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefecture = JapanPrefecture.extract(from: address)
    guard !prefecture.isEmpty else { return nil }
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
        if !prefecture.isEmpty { matchedPlace.prefecture = prefecture }
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
        prefecture: prefecture,
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

func normalizedPlaceText(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
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

private func normalizedStyleNames(from text: String) -> [String] {
    var seen = Set<String>()
    return text
        .components(separatedBy: CharacterSet(charactersIn: ",、\n"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { value in
            !value.isEmpty && seen.insert(value).inserted
        }
}

private enum RecordUnitStatus {
    case required
    case entered
    case optional

    var title: String {
        switch self {
        case .required:
            return "必須"
        case .entered:
            return "入力済み"
        case .optional:
            return "任意"
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

#Preview {
    AddExperienceView(category: RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45"))
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
