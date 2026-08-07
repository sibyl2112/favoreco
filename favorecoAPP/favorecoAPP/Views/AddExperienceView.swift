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
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @AppStorage(AppStorageKeys.afterSaveRecordAction) private var afterSaveRecordAction = "openDetail"
    @AppStorage(AppStorageKeys.lastUsedCategoryTemplateKey) private var lastUsedCategoryTemplateKey = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "officialInfo", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath = ""
    @State private var heroBackgroundPath = ""
    @State private var heroBackgroundPresetKey = ""
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
        initialPlaceMaster: PlaceMaster? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.category = category
        self.onSave = onSave
        var preparedDraft = initialDraft
        if let initialPlaceMaster {
            if preparedDraft.trimmedTitle.isEmpty {
                preparedDraft.title = initialPlaceMaster.name
            }
            preparedDraft.apply(placeMaster: initialPlaceMaster)
        }
        if preparedDraft.subTypeKey.isEmpty {
            switch category.templateKey {
            case "theater": preparedDraft.subTypeKey = TheaterPerformanceType.play.rawValue
            case "movie": preparedDraft.subTypeKey = ScreenWorkType.movie.rawValue
            case "theme_park": preparedDraft.subTypeKey = OutingFacilityType.themePark.rawValue
            case "nature_living": preparedDraft.subTypeKey = OutingFacilityType.natureOther.rawValue
            default: break
            }
        }
        _draft = State(initialValue: preparedDraft)
        if category.templateKey == "theater" {
            _expandedUnitIDs = State(initialValue: ["basic"])
        } else if category.templateKey == "book" {
            _expandedUnitIDs = State(initialValue: ["photos", "memo"])
        } else if ["movie", "museum"].contains(category.templateKey) {
            _expandedUnitIDs = State(initialValue: ["basic", "photos", "memo"])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if category.templateKey == "book" {
                    addBookRecordForm
                } else if category.templateKey == "theater",
                   let photoUnit = activeUnitDefinitions(for: category).first(where: { $0.id == "photos" }) {
                    TheaterRecordUnitBlock(
                        unit: photoUnit,
                        status: addStatus(for: photoUnit.id),
                        isExpanded: binding(for: photoUnit.id)
                    ) {
                        addContent(for: photoUnit)
                    }
                }
                if category.templateKey != "book", category.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation)
                    }
                }
                if category.templateKey != "book", category.templateKey == "movie" {
                    FavorecoRegistrationSection("作品区分") {
                        ScreenWorkTypeAndSeasonEditor(
                            typeKey: $draft.subTypeKey,
                            seasonNumber: $draft.screenWorkSeasonNumber
                        )
                    }
                }
                if category.templateKey != "book", category.templateKey == "theater" {
                    ForEach(activeUnitDefinitions(for: category).filter { $0.id != "photos" }) { unit in
                        TheaterRecordUnitBlock(
                            unit: unit,
                            status: addStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            addContent(for: unit)
                        }
                    }
                } else if category.templateKey != "book" {
                    ForEach(activeUnitDefinitions(for: category)) { unit in
                        SeparatedRecordUnitBlock(
                            unit: unit,
                            status: addStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            addContent(for: unit)
                        }
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .navigationTitle(
                category.templateKey == "theater"
                    ? TheaterUnifiedFormEntry.visitCreation.navigationTitle
                    : ["movie", "museum"].contains(category.templateKey)
                        ? "鑑賞済みを記録"
                        : "記録を追加"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        if category.templateKey == "theater" {
                            FavorecoIcon(systemName: "xmark", size: 18, fallbackWeight: .semibold)
                        } else {
                            Text("キャンセル")
                        }
                    }
                    .accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave || !draft.hasValidPerformanceType(for: category))
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

    @ViewBuilder
    private var addBookRecordForm: some View {
        BookRecordEyecatchEditor(
            existingPhotos: [],
            pendingPhotos: $pendingPhotos,
            coverPhotoPath: $coverPhotoPath,
            fallbackImageData: nil
        )

        ForEach(bookRecordUnitDefinitions) { unit in
            SeparatedRecordUnitBlock(
                unit: unit,
                status: addBookStatus(for: unit.id),
                isExpanded: binding(for: unit.id)
            ) {
                addBookContent(for: unit.id)
            }
        }
    }

    private func addBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo": draft.canSave ? .entered : .required
        case "bookReading": .entered
        case "photos": addStatus(for: "photos")
        case "memo": addStatus(for: "memo")
        default: .optional
        }
    }

    @ViewBuilder
    private func addBookContent(for unitID: String) -> some View {
        switch unitID {
        case "bookInfo":
            BookInformationEditor(
                title: $draft.title,
                seriesName: $draft.bookSeriesName,
                volumeNumber: $draft.bookVolumeNumber,
                authorName: $draft.bookAuthorName,
                officialURL: $draft.officialURL,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: true
            )
        case "bookReading":
            BookReadingPeriodEditor(
                startsAt: $draft.visitedAt,
                endsAt: $draft.endedAt,
                hasEndDate: $draft.bookReadingHasEndDate,
                rating: $draft.overallRating,
                ratingText: draft.ratingLabel
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
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey,
                showsBookFormatPicker: false,
                showsHeroBackgroundPicker: false
            )
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        default:
            EmptyView()
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
            return draft.canSave && draft.hasValidPerformanceType(for: category) ? .entered : .required
        case "theaterRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "officialInfo":
            let hasOfficialInfo = !draft.trimmedOfficialURL.isEmpty
                || !draft.normalizedSocialLinks.isEmpty
                || !draft.trimmedTheaterCreditsText.isEmpty
            return hasOfficialInfo ? .entered : .optional
        case "people":
            return draft.trimmedTheaterCreditsText.isEmpty && pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan || !pendingPeople.isEmpty ? .entered : .optional
        case "photos":
            return pendingPhotos.isEmpty ? .optional : .entered
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty && draft.normalizedTagNamesRaw.isEmpty ? .optional : .entered
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
                    venueOfficialURL: draft.publicPlaceSelection?.entry.officialURL ?? "",
                    placeMasters: placeMasters,
                    usesPlaceSuggestions: usesInputSuggestionDictionary,
                    usesMapSearchAssist: usesMapSearchAssist,
                    supportsPerformanceTime: category.usesOpeningTime,
                    supportsStyles: category.templateKey == "theater",
                    usesExplicitTheaterLayout: category.templateKey == "theater",
                    showsRating: category.templateKey != "theater",
                    datePrecision: screenWorkDatePrecision(
                        for: draft.subTypeKey,
                        category: category
                    ),
                    usesSimpleScreenWorkLayout: category.templateKey == "movie",
                    ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
                if category.templateKey == "theater" {
                    Divider()
                    TheaterPerformanceTypePicker(
                        selection: $draft.subTypeKey,
                        customName: $draft.performanceTypeCustomName
                    )
                }
                if category.isOutingFacilityGenre {
                    Divider()
                    OutingFacilityTypePicker(selection: $draft.subTypeKey)
                }
            }
        case "officialInfo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceOfficialInfoUnitEditor(
                    officialURL: $draft.officialURL,
                    socialLinksText: $draft.socialLinksText,
                    eventSubtitle: $draft.eventSubtitle,
                    title: $draft.title,
                    seriesName: $draft.seriesName,
                    visitedAt: $draft.visitedAt,
                    venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    pendingPeople: $pendingPeople,
                    advancedEntries: $draft.advancedEntries,
                    allowsContributorCandidates: category.templateKey != "theater",
                    usesExplicitTheaterLayout: category.templateKey == "theater"
                )
                if category.templateKey == "theater" {
                    Divider()
                    TheaterCreditsTextEditor(text: $draft.theaterCreditsText)
                }
            }
        case "people":
            if category.templateKey == "theater" {
                VStack(alignment: .leading, spacing: 18) {
                    TheaterCreditsTextEditor(text: $draft.theaterCreditsText)
                    Divider()
                    TheaterFocusPeopleEditor(
                        existingLinks: [],
                        deletedLinkIDs: .constant([]),
                        pendingLinks: $pendingPeople,
                        personMasters: personMasters
                    )
                }
            } else {
                PeopleUnitEditor(
                    existingLinks: [],
                    deletedLinkIDs: .constant([]),
                    pendingLinks: $pendingPeople,
                    personMasters: personMasters,
                    emptyDescription: ""
                )
            }
        case "ticketPlan":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceTicketUnitEditor(
                    outcomeKey: $draft.outcomeKey,
                    seatText: $draft.seatText,
                    usesExplicitTheaterLayout: category.templateKey == "theater"
                )
                if category.templateKey == "theater" {
                    Divider()
                    TheaterFocusPeopleEditor(
                        existingLinks: [],
                        deletedLinkIDs: .constant([]),
                        pendingLinks: $pendingPeople,
                        personMasters: personMasters
                    )
                }
            }
        case "theaterRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
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
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey
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
                usesExplicitTheaterLayout: category.templateKey == "theater"
            ) { suggestion in
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
            ExperienceMoneyUnitEditor(
                amountText: $draft.amountText,
                usesExplicitTheaterLayout: category.templateKey == "theater"
            )
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: category.templateKey == "theater"
                )
                if category.templateKey == "theater" {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
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
        let existingEvent: ExperienceEvent? = if resolvedCategory?.templateKey == "theater" {
            ExperienceEvent.matchingProduction(
                title: draft.trimmedTitle,
                categoryID: resolvedCategory?.id,
                in: events
            )
        } else {
            nil
        }
        let event = existingEvent ?? ExperienceEvent(
            title: draft.trimmedTitle,
            createdAt: now,
            updatedAt: now,
            category: resolvedCategory
        )
        if existingEvent == nil {
            modelContext.insert(event)
        }
        event.title = draft.trimmedTitle
        if resolvedCategory?.templateKey != "book", !draft.trimmedSeriesName.isEmpty {
            event.seriesName = draft.trimmedSeriesName
        }
        if !draft.subTypeKey.isEmpty {
            event.subTypeKey = draft.subTypeKey
        }
        if !draft.trimmedOfficialURL.isEmpty {
            event.officialURL = draft.trimmedOfficialURL
        }
        let eventUnitFieldsRaw = draft.eventUnitFieldsRaw(for: category)
        if event.unitFieldsRaw.isEmpty || existingEvent == nil {
            event.unitFieldsRaw = eventUnitFieldsRaw
        }
        if resolvedCategory?.templateKey == "book" {
            event.applyBookMetadata(
                seriesName: draft.trimmedBookSeriesName,
                volumeNumber: draft.trimmedBookVolumeNumber,
                authorName: draft.trimmedBookAuthorName
            )
        }
        event.stateKey = "active"
        event.updatedAt = now
        let visit = Visit(
            visitedAt: draft.visitedAt,
            endedAt: category.templateKey == "book" && !draft.bookReadingHasEndDate
                ? draft.visitedAt
                : max(draft.endedAt, draft.visitedAt),
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            outcomeKey: draft.outcomeKey,
            seatText: draft.trimmedSeatText,
            eyecatchPath: coverPhotoPath,
            note: draft.trimmedNote,
            tagNamesRaw: draft.normalizedTagNamesRaw,
            amount: parsedCurrencyAmount(from: draft.amountText),
            latitude: draft.latitude,
            longitude: draft.longitude,
            unitFieldsRaw: {
                var fields = draft.makeUnitFields(for: category)
                fields.heroBackgroundPath = heroBackgroundPath
                fields.heroBackgroundPresetKey = heroBackgroundPresetKey
                return fields.encodedRawValue
            }(),
            createdAt: now,
            updatedAt: now,
            event: event,
            placeMaster: resolvePlaceMaster(
                for: draft.placeSnapshot,
                publicSelection: draft.publicPlaceSelection,
                from: placeMasters,
                in: modelContext
            )
        )

        if !coverPhotoPath.isEmpty {
            event.representativeEyecatchPath = coverPhotoPath
            ThumbnailLoader.purge()
        }
        modelContext.insert(visit)
        insertPendingPeople(
            for: category.templateKey == "theater" ? nil : event,
            visit: category.templateKey == "theater" ? visit : nil
        )
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

    @discardableResult
    private func insertPendingPeople(for event: ExperienceEvent?, visit: Visit?) -> [EventPersonLink] {
        var links: [EventPersonLink] = []
        for (index, pendingPerson) in pendingPeople.enumerated() {
            let person = resolvePersonMaster(for: pendingPerson, from: personMasters, in: modelContext)
            let link = pendingPerson.makeEventPersonLink(person: person, event: event, visit: visit, sortOrder: index)
            modelContext.insert(link)
            links.append(link)
        }
        return links
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
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var draft: AddExperienceDraft
    @State private var expandedUnitIDs: Set<String>
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath: String
    @State private var heroBackgroundPath: String
    @State private var heroBackgroundPresetKey: String
    @State private var deletedPhotoIDs: Set<UUID> = []
    @State private var existingPhotoMetadata: [UUID: PhotoMetadataDraft] = [:]
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var deletedPersonLinkIDs: Set<UUID> = []
    @State private var existingFocusReactionTagKeys: [UUID: Set<String>]
    @State private var isShowingPlaceSearch = false
    @State private var saveErrorMessage: String?

    private var event: ExperienceEvent? {
        visit.event
    }

    private var category: RecordCategory? {
        event?.category
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    private var isTheaterVisit: Bool {
        category?.templateKey == "theater"
    }

    private var isBookVisit: Bool {
        category?.templateKey == "book"
    }

    private var visitFocusLinks: [EventPersonLink] {
        personLinks
            .filter {
                !$0.isArchived
                    && $0.visit?.id == visit.id
                    && $0.roleKey == PersonRoleOption.theaterFocus.key
                    && !deletedPersonLinkIDs.contains($0.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    init(visit: Visit) {
        self.visit = visit
        _draft = State(initialValue: AddExperienceDraft(visit: visit))
        let isTheater = visit.event?.category?.templateKey == "theater"
        let isScreenWork = visit.event?.category?.templateKey == "movie"
        let initialUnits: Set<String> = if isTheater {
            ["basic"]
        } else if visit.event?.category?.templateKey == "book" {
            ["photos", "memo"]
        } else if isScreenWork {
            ["basic", "photos", "memo"]
        } else {
            ["basic", "people", "photos", "officialInfo", "memo"]
        }
        _expandedUnitIDs = State(initialValue: initialUnits)
        _coverPhotoPath = State(initialValue: visit.eyecatchPath)
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        _heroBackgroundPath = State(initialValue: unitFields.heroBackgroundPath)
        _heroBackgroundPresetKey = State(initialValue: unitFields.heroBackgroundPresetKey)
        _existingFocusReactionTagKeys = State(initialValue: Dictionary(uniqueKeysWithValues:
            (visit.personLinks ?? [])
                .filter { !$0.isArchived && $0.roleKey == PersonRoleOption.theaterFocus.key }
                .compactMap { link in
                    let keys = TheaterFocusLinkMetadata(memo: link.memo).reactionKeys
                    return keys.isEmpty ? nil : (link.id, Set(keys))
                }
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isBookVisit {
                    editBookRecordForm
                } else if isTheaterVisit,
                   let photoUnit = activeUnitDefinitions(for: category).first(where: { $0.id == "photos" }) {
                    TheaterRecordUnitBlock(
                        unit: photoUnit,
                        status: editStatus(for: photoUnit.id),
                        isExpanded: binding(for: photoUnit.id)
                    ) {
                        editContent(for: photoUnit)
                    }
                }
                if !isBookVisit, isTheaterVisit {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitEditing)
                    }
                }
                if !isBookVisit, category?.templateKey == "movie" {
                    FavorecoRegistrationSection("作品区分") {
                        ScreenWorkTypeAndSeasonEditor(
                            typeKey: $draft.subTypeKey,
                            seasonNumber: $draft.screenWorkSeasonNumber
                        )
                    }
                }
                if !isBookVisit, isTheaterVisit {
                    ForEach(activeUnitDefinitions(for: category).filter { $0.id != "photos" }) { unit in
                        TheaterRecordUnitBlock(
                            unit: unit,
                            status: editStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            editContent(for: unit)
                        }
                    }
                } else if !isBookVisit {
                    ForEach(activeUnitDefinitions(for: category)) { unit in
                        SeparatedRecordUnitBlock(
                            unit: unit,
                            status: editStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            editContent(for: unit)
                        }
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .navigationTitle(
                isTheaterVisit
                    ? TheaterUnifiedFormEntry.visitEditing.navigationTitle
                    : isBookVisit ? "読書記録を編集" : "記録を編集"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        if isTheaterVisit {
                            FavorecoIcon(systemName: "xmark", size: 18, fallbackWeight: .semibold)
                        } else {
                            Text("キャンセル")
                        }
                    }
                    .accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!isTheaterVisit && !draft.canSave)
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    let preservesVenueName = draft.shouldPreserveVenueNameForAddressSearch
                    draft.apply(place: candidate, preservingVenueName: preservesVenueName)
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

    @ViewBuilder
    private var editBookRecordForm: some View {
        BookRecordEyecatchEditor(
            existingPhotos: visibleExistingPhotos,
            pendingPhotos: $pendingPhotos,
            coverPhotoPath: $coverPhotoPath,
            fallbackImageData: event?.eyecatchData
        )

        ForEach(bookRecordUnitDefinitions) { unit in
            SeparatedRecordUnitBlock(
                unit: unit,
                status: editBookStatus(for: unit.id),
                isExpanded: binding(for: unit.id)
            ) {
                editBookContent(for: unit.id)
            }
        }
    }

    private func editBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo": draft.canSave ? .entered : .required
        case "bookReading": .entered
        case "photos": visibleExistingPhotos.isEmpty && pendingPhotos.isEmpty ? .optional : .entered
        case "memo": draft.trimmedNote.isEmpty ? .optional : .entered
        default: .optional
        }
    }

    @ViewBuilder
    private func editBookContent(for unitID: String) -> some View {
        switch unitID {
        case "bookInfo":
            BookInformationEditor(
                title: $draft.title,
                seriesName: $draft.bookSeriesName,
                volumeNumber: $draft.bookVolumeNumber,
                authorName: $draft.bookAuthorName,
                officialURL: $draft.officialURL,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: true
            )
        case "bookReading":
            BookReadingPeriodEditor(
                startsAt: $draft.visitedAt,
                endsAt: $draft.endedAt,
                hasEndDate: $draft.bookReadingHasEndDate,
                rating: $draft.overallRating,
                ratingText: draft.ratingLabel
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
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey,
                showsBookFormatPicker: false,
                showsHeroBackgroundPicker: false
            )
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        default:
            EmptyView()
        }
    }

    private func editStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "basic":
            return isTheaterVisit || draft.canSave ? .entered : .required
        case "theaterRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "officialInfo":
            if isTheaterVisit {
                let hasOfficialURL = !(event?.officialURL ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                let hasSocialLinks = !VisitUnitFields(rawValue: event?.unitFieldsRaw ?? "").socialLinks.isEmpty
                return hasOfficialURL || hasSocialLinks ? .entered : .optional
            }
            return draft.trimmedOfficialURL.isEmpty && draft.normalizedSocialLinks.isEmpty ? .optional : .entered
        case "people":
            if category?.templateKey == "theater" {
                return visitFocusLinks.isEmpty && pendingPeople.isEmpty ? .optional : .entered
            }
            return visiblePersonLinks.isEmpty && pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            let hasFocusPeople = !visitFocusLinks.isEmpty || !pendingPeople.isEmpty
            return draft.hasTicketPlan || hasFocusPeople ? .entered : .optional
        case "photos":
            return visibleExistingPhotos.isEmpty && pendingPhotos.isEmpty ? .optional : .entered
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "memo":
            return draft.trimmedNote.isEmpty && draft.normalizedTagNamesRaw.isEmpty ? .optional : .entered
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
                if isTheaterVisit {
                    ExperienceBasicUnitEditor(
                        template: template,
                        eventTitle: event?.title ?? "",
                        eventSeriesName: event?.seriesName ?? "",
                        visitedAt: $draft.visitedAt,
                        endedAt: $draft.endedAt,
                        styleNamesText: $draft.styleNamesText,
                        venueName: venueNameBinding,
                        venueAddress: venueAddressBinding,
                        overallRating: $draft.overallRating,
                        latitude: draft.latitude,
                        longitude: draft.longitude,
                        venueOfficialURL: draft.publicPlaceSelection?.entry.officialURL ?? "",
                        placeMasters: placeMasters,
                        usesPlaceSuggestions: usesInputSuggestionDictionary,
                        usesMapSearchAssist: usesMapSearchAssist,
                        supportsPerformanceTime: category?.usesOpeningTime == true,
                        supportsStyles: true,
                        usesExplicitTheaterLayout: true,
                        showsRating: false,
                        ratingText: draft.ratingLabel,
                        onSelectPlace: { draft.apply(placeMaster: $0) },
                        onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                        onOpenPlaceSearch: { isShowingPlaceSearch = true }
                    )
                } else {
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
                        venueOfficialURL: draft.publicPlaceSelection?.entry.officialURL ?? "",
                        placeMasters: placeMasters,
                        usesPlaceSuggestions: usesInputSuggestionDictionary,
                        usesMapSearchAssist: usesMapSearchAssist,
                        supportsPerformanceTime: category?.usesOpeningTime == true,
                        supportsStyles: false,
                        datePrecision: screenWorkDatePrecision(
                            for: draft.subTypeKey,
                            category: category
                        ),
                        usesSimpleScreenWorkLayout: category?.templateKey == "movie",
                        ratingText: draft.ratingLabel,
                        onSelectPlace: { draft.apply(placeMaster: $0) },
                        onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                        onOpenPlaceSearch: { isShowingPlaceSearch = true }
                    )
                }
                if category?.isOutingFacilityGenre == true {
                    Divider()
                    OutingFacilityTypePicker(selection: $draft.subTypeKey)
                }
            }
        case "officialInfo":
            if isTheaterVisit {
                ExperienceOfficialInfoReferenceView()
            } else {
                ExperienceOfficialInfoUnitEditor(
                    officialURL: $draft.officialURL,
                    socialLinksText: $draft.socialLinksText,
                    eventSubtitle: $draft.eventSubtitle,
                    title: $draft.title,
                    seriesName: $draft.seriesName,
                    visitedAt: $draft.visitedAt,
                    venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    pendingPeople: $pendingPeople,
                    advancedEntries: $draft.advancedEntries
                )
            }
        case "people":
            if category?.templateKey == "theater" {
                TheaterFocusPeopleEditor(
                    existingLinks: visitFocusLinks,
                    deletedLinkIDs: $deletedPersonLinkIDs,
                    pendingLinks: $pendingPeople,
                    personMasters: personMasters,
                    existingReactionTagKeys: $existingFocusReactionTagKeys
                )
            } else {
                PeopleUnitEditor(
                    existingLinks: visiblePersonLinks,
                    deletedLinkIDs: $deletedPersonLinkIDs,
                    pendingLinks: $pendingPeople,
                    personMasters: personMasters,
                    emptyDescription: ""
                )
            }
        case "ticketPlan":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceTicketUnitEditor(
                    outcomeKey: $draft.outcomeKey,
                    seatText: $draft.seatText,
                    usesExplicitTheaterLayout: isTheaterVisit
                )
                if isTheaterVisit {
                    Divider()
                    TheaterFocusPeopleEditor(
                        existingLinks: visitFocusLinks,
                        deletedLinkIDs: $deletedPersonLinkIDs,
                        pendingLinks: $pendingPeople,
                        personMasters: personMasters,
                        existingReactionTagKeys: $existingFocusReactionTagKeys
                    )
                }
            }
        case "theaterRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
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
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey
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
                supportsTitleSuggestion: !isTheaterVisit,
                usesExplicitTheaterLayout: isTheaterVisit
            ) { suggestion in
                switch suggestion.kind {
                case .title:
                    if !isTheaterVisit { draft.title = suggestion.value }
                case .date: if let date = suggestion.dateValue { draft.visitedAt = date }
                case .venue:
                    draft.venueName = suggestion.value
                    draft.clearPlaceSelection()
                case .amount: draft.amountText = suggestion.value
                }
            }
        case "money":
            ExperienceMoneyUnitEditor(
                amountText: $draft.amountText,
                usesExplicitTheaterLayout: isTheaterVisit
            )
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: isTheaterVisit
                )
                if isTheaterVisit {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
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
            applyTargetChangesFromExperienceEdit(
                to: event,
                draft: draft,
                categories: categories,
                at: now
            )
        }

        visit.visitedAt = draft.visitedAt
        visit.endedAt = category?.templateKey == "book" && !draft.bookReadingHasEndDate
            ? draft.visitedAt
            : max(draft.endedAt, draft.visitedAt)
        visit.venueNameSnapshot = draft.trimmedVenueName
        visit.latitude = draft.latitude
        visit.longitude = draft.longitude
        visit.placeMaster = resolvePlaceMaster(
            for: draft.placeSnapshot,
            publicSelection: draft.publicPlaceSelection,
            from: placeMasters,
            in: modelContext
        )
        visit.overallRating = draft.overallRating
        visit.outcomeKey = draft.outcomeKey
        visit.seatText = draft.trimmedSeatText
        visit.eyecatchPath = coverPhotoPath
        visit.amount = parsedCurrencyAmount(from: draft.amountText)
        visit.note = draft.trimmedNote
        visit.tagNamesRaw = draft.normalizedTagNamesRaw
        var updatedUnitFields = draft.makeUnitFields(for: event?.category)
        if category?.templateKey == "theater" {
            // 旧形式の「この回だけのキャスト」状態は保持するが、
            // 新しいシンプル入力で暗黙に旧スナップショットへ切り替えない。
            updatedUnitFields.hasVisitCastSnapshot = existingUnitFields.hasVisitCastSnapshot
        }
        updatedUnitFields.heroBackgroundPath = heroBackgroundPath
        updatedUnitFields.heroBackgroundPresetKey = heroBackgroundPresetKey
        if preservesWeather {
            updatedUnitFields.copyWeather(from: existingUnitFields)
        }
        visit.unitFieldsRaw = updatedUnitFields.encodedRawValue
        visit.updatedAt = now
        applyExistingFocusReactionTags(at: now)
        deleteMarkedPersonLinks()
        if category?.templateKey == "theater" {
            insertPendingPeople(for: nil, visit: visit)
        } else {
            insertPendingPeople(for: event, visit: nil)
        }
        applyExistingPhotoMetadata()
        deleteMarkedPhotos()
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            Task { await VisitWeatherService.fillIfNeeded(for: visit, in: modelContext) }
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = isTheaterVisit
                ? "観劇回を更新できませんでした。入力内容を確認して、もう一度お試しください。"
                : "記録を更新できませんでした。入力内容を確認して、もう一度お試しください。"
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
            photo.caption = metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            photo.ocrText = metadata.purpose.supportsAmount
                ? metadata.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            photo.amount = metadata.purpose.supportsAmount ? metadata.amount : Decimal(0)
            if !isTheaterVisit,
               metadata.purpose != .memory,
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

    private func applyExistingFocusReactionTags(at date: Date) {
        guard isTheaterVisit else { return }
        for link in visitFocusLinks {
            guard let tagKeys = existingFocusReactionTagKeys[link.id] else { continue }
            link.memo = TheaterFocusLinkMetadata(
                reactionKeys: TheaterFocusReaction.orderedKeys(tagKeys)
            ).encodedMemo
            link.updatedAt = date
        }
    }

    @discardableResult
    private func insertPendingPeople(for event: ExperienceEvent?, visit: Visit?) -> [EventPersonLink] {
        let startIndex = visiblePersonLinks.count
        var links: [EventPersonLink] = []
        for (offset, pendingPerson) in pendingPeople.enumerated() {
            let person = resolvePersonMaster(for: pendingPerson, from: personMasters, in: modelContext)
            let link = pendingPerson.makeEventPersonLink(person: person, event: event, visit: visit, sortOrder: startIndex + offset)
            modelContext.insert(link)
            links.append(link)
        }
        return links
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
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var draft: VisitDraft
    @State private var expandedUnitIDs: Set<String> = ["basic", "people", "ticketPlan", "photos", "memo"]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedOCRItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var coverPhotoPath = ""
    @State private var heroBackgroundPath = ""
    @State private var heroBackgroundPresetKey = ""
    @State private var pendingPeople: [PendingPersonLink] = []
    @State private var isShowingPlaceSearch = false
    @State private var savedVisit: Visit?
    @State private var isShowingSavedDetail = false
    @State private var saveErrorMessage: String?
    @State private var screenWorkTypeKey: String
    @State private var screenWorkSeasonNumber: Int

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    init(
        event: ExperienceEvent,
        initialDraft: VisitDraft = VisitDraft(),
        initialCoverPhotoPath: String = "",
        initialHeroBackgroundPath: String = "",
        initialHeroBackgroundPresetKey: String = "",
        inheritedVisualSource: Visit? = nil,
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
        let inheritedVisuals = Self.makeInheritedVisuals(from: inheritedVisualSource)
        _draft = State(initialValue: preparedDraft)
        _pendingPhotos = State(initialValue: inheritedVisuals.photos)
        _coverPhotoPath = State(initialValue: inheritedVisuals.coverPath ?? initialCoverPhotoPath)
        _heroBackgroundPath = State(initialValue: inheritedVisuals.backgroundPath ?? initialHeroBackgroundPath)
        _heroBackgroundPresetKey = State(initialValue: initialHeroBackgroundPresetKey)
        _screenWorkTypeKey = State(initialValue: event.screenWorkType.rawValue)
        _screenWorkSeasonNumber = State(initialValue: event.screenWorkSeasonNumber)
        if event.category?.templateKey == "theater" {
            _expandedUnitIDs = State(initialValue: ["basic"])
        } else if event.category?.templateKey == "book" {
            _expandedUnitIDs = State(initialValue: ["photos", "memo"])
        } else if ["movie", "museum"].contains(event.category?.templateKey ?? "") {
            _expandedUnitIDs = State(initialValue: ["basic", "photos", "memo"])
        }
    }

    private static func makeInheritedVisuals(
        from source: Visit?
    ) -> (photos: [PendingPhoto], coverPath: String?, backgroundPath: String?) {
        guard let source else { return ([], nil, nil) }
        let fields = VisitUnitFields(rawValue: source.unitFieldsRaw)
        let requestedPaths = Set([source.eyecatchPath, fields.heroBackgroundPath].filter { !$0.isEmpty })
        guard !requestedPaths.isEmpty else { return ([], nil, nil) }

        var copied: [PendingPhoto] = []
        var replacements: [String: String] = [:]
        for photo in (source.photos ?? []) where requestedPaths.contains(photo.relativePath) && !photo.data.isEmpty {
            let pending = PendingPhoto(
                data: photo.data,
                originalFilename: photo.originalFilename,
                width: photo.width,
                height: photo.height,
                metadata: PhotoMetadataDraft(
                    purpose: .memory,
                    caption: photo.caption
                )
            )
            copied.append(pending)
            replacements[photo.relativePath] = pending.relativePath
        }
        return (
            copied,
            replacements[source.eyecatchPath],
            replacements[fields.heroBackgroundPath]
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if event.category?.templateKey == "book" {
                    addVisitBookRecordForm
                }
                if event.category?.templateKey != "book",
                   event.category?.templateKey == "theater",
                   let photoUnit = activeUnitDefinitions(for: event.category).first(where: { $0.id == "photos" }) {
                    TheaterRecordUnitBlock(
                        unit: photoUnit,
                        status: visitStatus(for: photoUnit.id),
                        isExpanded: binding(for: photoUnit.id)
                    ) {
                        visitContent(for: photoUnit)
                    }
                }
                if event.category?.templateKey != "book", event.category?.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation)
                    }
                }
                if event.category?.templateKey != "book", event.category?.templateKey == "movie" {
                    FavorecoRegistrationSection("作品区分") {
                        ScreenWorkTypeAndSeasonEditor(
                            typeKey: $screenWorkTypeKey,
                            seasonNumber: $screenWorkSeasonNumber
                        )
                    }
                }
                if event.category?.templateKey != "book", event.category?.templateKey == "theater" {
                    ForEach(activeUnitDefinitions(for: event.category).filter { $0.id != "photos" }) { unit in
                        TheaterRecordUnitBlock(
                            unit: unit,
                            status: visitStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            visitContent(for: unit)
                        }
                    }
                } else if event.category?.templateKey != "book" {
                    ForEach(activeUnitDefinitions(for: event.category)) { unit in
                        SeparatedRecordUnitBlock(
                            unit: unit,
                            status: visitStatus(for: unit.id),
                            isExpanded: binding(for: unit.id)
                        ) {
                            visitContent(for: unit)
                        }
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .navigationTitle(
                event.category?.templateKey == "theater"
                    ? TheaterUnifiedFormEntry.visitCreation.navigationTitle
                    : event.category?.templateKey == "book"
                        ? "読書記録を追加"
                    : ["movie", "museum"].contains(event.category?.templateKey ?? "")
                        ? "鑑賞の記録をつける"
                        : "記録を追加"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        if event.category?.templateKey == "theater" {
                            FavorecoIcon(systemName: "xmark", size: 18, fallbackWeight: .semibold)
                        } else {
                            Text("キャンセル")
                        }
                    }
                    .accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                ExperiencePlaceSearchView(
                    initialQuery: draft.mapSearchQuery,
                    registeredVenues: VisitUnitFields(rawValue: event.unitFieldsRaw)
                        .eventVenues
                        .filter { !$0.isEmpty },
                    onSelectRegisteredVenue: { venue in
                        draft.clearPlaceSelection()
                        draft.venueName = venue.trimmedName
                        draft.venueAddress = venue.trimmedAddress
                    }
                ) { candidate in
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

    @ViewBuilder
    private var addVisitBookRecordForm: some View {
        BookRecordEyecatchEditor(
            existingPhotos: [],
            pendingPhotos: $pendingPhotos,
            coverPhotoPath: $coverPhotoPath,
            fallbackImageData: event.eyecatchData
        )

        ForEach(bookRecordUnitDefinitions) { unit in
            SeparatedRecordUnitBlock(
                unit: unit,
                status: addVisitBookStatus(for: unit.id),
                isExpanded: binding(for: unit.id)
            ) {
                addVisitBookContent(for: unit.id)
            }
        }
    }

    private func addVisitBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo", "bookReading": .entered
        case "photos": pendingPhotos.isEmpty ? .optional : .entered
        case "memo": draft.trimmedNote.isEmpty ? .optional : .entered
        default: .optional
        }
    }

    @ViewBuilder
    private func addVisitBookContent(for unitID: String) -> some View {
        switch unitID {
        case "bookInfo":
            BookInformationEditor(
                title: .constant(event.title),
                seriesName: .constant(event.bookSeriesName),
                volumeNumber: .constant(event.bookVolumeNumber),
                authorName: .constant(event.bookAuthorName),
                officialURL: .constant(event.officialURL),
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: false
            )
        case "bookReading":
            BookReadingPeriodEditor(
                startsAt: $draft.visitedAt,
                endsAt: $draft.endedAt,
                hasEndDate: $draft.bookReadingHasEndDate,
                rating: $draft.overallRating,
                ratingText: draft.ratingLabel
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
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey,
                showsBookFormatPicker: false,
                showsHeroBackgroundPicker: false
            )
        case "memo":
            ExperienceMemoUnitEditor(
                text: $draft.note,
                placeholder: template.memoPlaceholder
            )
        default:
            EmptyView()
        }
    }

    private func visitStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "basic":
            return .entered
        case "theaterRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "memo":
            return draft.trimmedNote.isEmpty && draft.normalizedTagNamesRaw.isEmpty ? .optional : .entered
        case "photos":
            return pendingPhotos.isEmpty ? .optional : .entered
        case "goshuinBook":
            return draft.goshuinBookSizeKey.isEmpty ? .optional : .entered
        case "importOCR":
            return draft.trimmedOCRText.isEmpty ? .optional : .entered
        case "money":
            return draft.trimmedAmountText.isEmpty ? .optional : .entered
        case "people":
            if event.category?.templateKey == "theater" {
                return pendingPeople.isEmpty ? .optional : .entered
            }
            return pendingPeople.isEmpty ? .optional : .entered
        case "ticketPlan":
            return draft.hasTicketPlan || !pendingPeople.isEmpty ? .entered : .optional
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
            VStack(alignment: .leading, spacing: 12) {
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
                    venueOfficialURL: draft.publicPlaceSelection?.entry.officialURL ?? "",
                    placeMasters: placeMasters,
                    usesPlaceSuggestions: usesInputSuggestionDictionary,
                    usesMapSearchAssist: usesMapSearchAssist,
                    supportsPerformanceTime: event.category?.usesOpeningTime == true,
                    supportsStyles: event.category?.templateKey == "theater",
                    usesExplicitTheaterLayout: event.category?.templateKey == "theater",
                    showsRating: event.category?.templateKey != "theater",
                    datePrecision: screenWorkDatePrecision(
                        for: screenWorkTypeKey,
                        category: event.category
                    ),
                    usesSimpleScreenWorkLayout: event.category?.templateKey == "movie",
                    ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
            }
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: event.category?.templateKey == "theater"
                )
                if event.category?.templateKey == "theater" {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                existingPhotoMetadata: .constant([:]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: event.category,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                coverPhotoPath: $coverPhotoPath,
                heroBackgroundPath: $heroBackgroundPath,
                heroBackgroundPresetKey: $heroBackgroundPresetKey
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
                supportsTitleSuggestion: false,
                usesExplicitTheaterLayout: event.category?.templateKey == "theater"
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
            if event.category?.templateKey == "theater" {
                TheaterFocusPeopleEditor(
                    existingLinks: [],
                    deletedLinkIDs: .constant([]),
                    pendingLinks: $pendingPeople,
                    personMasters: personMasters
                )
            } else {
                PeopleUnitEditor(
                    existingLinks: [],
                    deletedLinkIDs: .constant([]),
                    pendingLinks: $pendingPeople,
                    personMasters: personMasters,
                    emptyDescription: ""
                )
            }
        case "ticketPlan":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceTicketUnitEditor(
                    outcomeKey: $draft.outcomeKey,
                    seatText: $draft.seatText,
                    usesExplicitTheaterLayout: event.category?.templateKey == "theater"
                )
                if event.category?.templateKey == "theater" {
                    Divider()
                    TheaterFocusPeopleEditor(
                        existingLinks: [],
                        deletedLinkIDs: .constant([]),
                        pendingLinks: $pendingPeople,
                        personMasters: personMasters
                    )
                }
            }
        case "theaterRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
            )
        case "money":
            ExperienceMoneyUnitEditor(
                amountText: $draft.amountText,
                usesExplicitTheaterLayout: event.category?.templateKey == "theater"
            )
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
            endedAt: event.category?.templateKey == "book" && !draft.bookReadingHasEndDate
                ? draft.visitedAt
                : max(draft.endedAt, draft.visitedAt),
            venueNameSnapshot: draft.trimmedVenueName,
            overallRating: draft.overallRating,
            outcomeKey: draft.outcomeKey,
            seatText: draft.trimmedSeatText,
            eyecatchPath: coverPhotoPath,
            note: draft.trimmedNote,
            tagNamesRaw: draft.normalizedTagNamesRaw,
            amount: parsedCurrencyAmount(from: draft.amountText),
            latitude: draft.latitude,
            longitude: draft.longitude,
            unitFieldsRaw: {
                var fields = draft.makeUnitFields(for: event.category)
                fields.heroBackgroundPath = heroBackgroundPath
                fields.heroBackgroundPresetKey = heroBackgroundPresetKey
                return fields.encodedRawValue
            }(),
            createdAt: now,
            updatedAt: now,
            event: event,
            placeMaster: resolvePlaceMaster(
                for: draft.placeSnapshot,
                publicSelection: draft.publicPlaceSelection,
                from: placeMasters,
                in: modelContext
            )
        )

        event.stateKey = "active"
        if event.category?.templateKey == "movie" {
            event.applyScreenWorkClassification(
                typeKey: screenWorkTypeKey,
                seasonNumber: screenWorkSeasonNumber
            )
        }
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
            let person = resolvePersonMaster(for: pendingPerson, from: personMasters, in: modelContext)
            modelContext.insert(pendingPerson.makeEventPersonLink(person: person, event: nil, visit: visit, sortOrder: index))
        }
    }
}

private struct SavedExperienceDetailView: View {
    let visit: Visit
    let onDone: () -> Void

    var body: some View {
        ExperienceDetailView(
            visit: visit,
            onBack: onDone,
            showsScrollingFrame: false
        )
            .navigationBarBackButtonHidden()
    }
}

struct AddExperienceDraft {
    var title: String = ""
    var seriesName: String = ""
    var bookSeriesName: String = ""
    var bookVolumeNumber: String = ""
    var bookAuthorName: String = ""
    var subTypeKey: String = ""
    var screenWorkSeasonNumber: Int = 0
    var performanceTypeCustomName: String = ""
    var officialURL: String = ""
    var socialLinksText: String = ""
    var eventSubtitle: String = ""
    var theaterCreditsText: String = ""
    var visitedAt: Date = Date()
    var endedAt: Date = Date()
    var bookReadingHasEndDate: Bool = true
    var styleNamesText: String = ""
    var venueName: String = ""
    var venueAddress: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var publicPlaceSelection: PublicPlaceSelectionDraft?
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey: String = ""
    var goshuinBookSizeKey: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    var amountText: String = ""
    var note: String = ""
    var tagNamesText: String = ""
    var excludedEventCastLinkIDs: Set<UUID> = []

    init() {}

    init(visit: Visit) {
        title = visit.event?.title ?? ""
        seriesName = visit.event?.seriesName ?? ""
        subTypeKey = visit.event?.subTypeKey ?? ""
        officialURL = visit.event?.officialURL ?? ""
        let eventFields = VisitUnitFields(rawValue: visit.event?.unitFieldsRaw ?? "")
        bookSeriesName = eventFields.bookSeriesName
        bookVolumeNumber = eventFields.bookVolumeNumber
        bookAuthorName = eventFields.bookAuthorName
        if visit.event?.category?.templateKey == "movie" {
            subTypeKey = ScreenWorkType.resolved(from: subTypeKey).rawValue
            screenWorkSeasonNumber = eventFields.screenWorkSeasonNumber
        }
        performanceTypeCustomName = eventFields.eventPerformanceTypeCustomName
        socialLinksText = eventFields.socialLinks.joined(separator: "\n")
        eventSubtitle = eventFields.eventSubtitle
        theaterCreditsText = eventFields.eventCreditsText
        visitedAt = visit.visitedAt
        endedAt = visit.endedAt
        bookReadingHasEndDate = VisitUnitFields(rawValue: visit.unitFieldsRaw).bookReadingHasEndDate ?? true
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
        tagNamesText = visit.tagNamesRaw
        excludedEventCastLinkIDs = Set(unitFields.excludedEventCastLinkIDs)
        if unitFields.hasVisitCastSnapshot {
            let capturedEventLinkIDs = Set(
                (visit.personLinks ?? []).compactMap { TheaterVisitCastResolver.sourceEventLinkID(for: $0) }
            )
            let currentEventCastLinkIDs = Set(
                (visit.event?.personLinks ?? [])
                    .filter { TheaterVisitCastResolver.isCastLink($0) }
                    .map(\.id)
            )
            excludedEventCastLinkIDs.formUnion(currentEventCastLinkIDs.subtracting(capturedEventLinkIDs))
        }
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

    var trimmedBookSeriesName: String {
        bookSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookVolumeNumber: String {
        bookVolumeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookAuthorName: String {
        bookAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEventSubtitle: String {
        eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTheaterCreditsText: String {
        theaterCreditsText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        publicPlaceSelection = nil
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
        publicPlaceSelection = nil
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
    }

    mutating func apply(publicPlace selection: PublicPlaceSelectionDraft) {
        publicPlaceSelection = selection
        venueName = selection.entry.officialName
        venueAddress = selection.entry.address
        latitude = selection.entry.latitude
        longitude = selection.entry.longitude
    }

    mutating func clearPlaceSelection() {
        publicPlaceSelection = nil
        venueAddress = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        publicPlaceSelection = nil
        latitude = 0
        longitude = 0
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedTagNamesRaw: String {
        TheaterEmotionTags.encoded(TheaterEmotionTags.names(from: tagNamesText))
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
            excludedEventCastLinkIDs: excludedEventCastLinkIDs.sorted { $0.uuidString < $1.uuidString },
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries,
            bookReadingHasEndDate: category?.templateKey == "book" ? bookReadingHasEndDate : nil
        )
    }

    func eventUnitFieldsRaw(for category: RecordCategory?) -> String {
        return VisitUnitFields(
            socialLinks: normalizedSocialLinks,
            eventSubtitle: trimmedEventSubtitle,
            eventCreditsText: trimmedTheaterCreditsText,
            eventPerformanceTypeCustomName: TheaterPerformanceType.customNameForStorage(
                key: subTypeKey,
                input: performanceTypeCustomName
            ),
            screenWorkSeasonNumber: category?.templateKey == "movie"
                && ScreenWorkType.resolved(from: subTypeKey).supportsSeason
                ? screenWorkSeasonNumber
                : 0,
            eyecatchAspectRatioKey: category?.templateKey == "book"
                ? (eyecatchAspectRatioKey.isEmpty ? EyecatchAspectRatio.hardcoverBook.key : eyecatchAspectRatioKey)
                : "",
            bookSeriesName: category?.templateKey == "book" ? trimmedBookSeriesName : "",
            bookVolumeNumber: category?.templateKey == "book" ? trimmedBookVolumeNumber : "",
            bookAuthorName: category?.templateKey == "book" ? trimmedBookAuthorName : ""
        ).encodedRawValue
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    func hasValidPerformanceType(for category: RecordCategory?) -> Bool {
        category?.templateKey != "theater"
            || TheaterPerformanceType.isValidSelection(
                key: subTypeKey,
                customName: performanceTypeCustomName
            )
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

@MainActor
func applyTargetChangesFromExperienceEdit(
    to event: ExperienceEvent,
    draft: AddExperienceDraft,
    categories: [RecordCategory],
    at now: Date
) {
    // 観劇回は過去の一回を記録する単位。公演情報の正本は公演ハブの対象編集だけで更新する。
    guard event.category?.templateKey != "theater" else { return }

    event.title = draft.trimmedTitle
    if event.category?.templateKey == "book" {
        event.applyBookMetadata(
            seriesName: draft.trimmedBookSeriesName,
            volumeNumber: draft.trimmedBookVolumeNumber,
            authorName: draft.trimmedBookAuthorName
        )
    } else {
        event.seriesName = draft.trimmedSeriesName
    }
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
    } else if event.category?.templateKey == "movie" {
        event.subTypeKey = ScreenWorkType.resolved(from: draft.subTypeKey).rawValue
    }
    event.officialURL = draft.trimmedOfficialURL
    var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
    eventFields.socialLinks = draft.normalizedSocialLinks
    eventFields.eventSubtitle = draft.trimmedEventSubtitle
    if event.category?.templateKey == "book" {
        eventFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
        eventFields.bookSeriesName = draft.trimmedBookSeriesName
        eventFields.bookVolumeNumber = draft.trimmedBookVolumeNumber
        eventFields.bookAuthorName = draft.trimmedBookAuthorName
    }
    if event.category?.templateKey == "movie" {
        eventFields.screenWorkSeasonNumber = ScreenWorkType.resolved(from: draft.subTypeKey).supportsSeason
            ? draft.screenWorkSeasonNumber
            : 0
    }
    event.unitFieldsRaw = eventFields.encodedRawValue
    event.updatedAt = now
}

private func screenWorkDatePrecision(
    for subTypeKey: String,
    category: RecordCategory?
) -> ExperienceDatePrecision {
    guard category?.templateKey == "movie" else { return .day }
    return ScreenWorkType.resolved(from: subTypeKey) == .movie ? .day : .year
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
    var visitedAt: Date
    var endedAt: Date
    var bookReadingHasEndDate: Bool = true
    var styleNamesText: String = ""
    var venueName: String = ""
    var venueAddress: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var publicPlaceSelection: PublicPlaceSelectionDraft?
    var overallRating: Double = 0
    var outcomeKey: String = ""
    var seatText: String = ""
    var ocrText: String = ""
    var eyecatchAspectRatioKey: String = ""
    var goshuinBookSizeKey: String = ""
    var advancedEntries: [AdvancedFieldEntry] = []
    var amountText: String = ""
    var note: String = ""
    var tagNamesText: String = ""
    var excludedEventCastLinkIDs: Set<UUID> = []

    init() {
        let initialTime = Date().roundedToNearestFiveMinutes()
        visitedAt = initialTime
        endedAt = initialTime
    }

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

    /// 同じ対象をもう一度記録する時に、場所と表示設定だけを引き継ぐ。
    /// 日時・評価・感想・写真・費用・人物・タグは新しい体験として空にする。
    init(repeating visit: Visit) {
        let initialTime = Date().roundedToNearestFiveMinutes()
        let previousFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let place = visit.placeMaster
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0

        visitedAt = initialTime
        endedAt = initialTime
        styleNamesText = previousFields.styleNames.joined(separator: "・")
        venueName = visit.venueNameSnapshot
        venueAddress = place?.address ?? ""
        latitude = hasVisitCoordinate ? visit.latitude : (place?.latitude ?? 0)
        longitude = hasVisitCoordinate ? visit.longitude : (place?.longitude ?? 0)
        eyecatchAspectRatioKey = previousFields.eyecatchAspectRatioKey
    }

    init(inboxItem: InboxItem) {
        self.init()
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
        publicPlaceSelection = nil
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
        publicPlaceSelection = nil
        venueName = placeMaster.name
        venueAddress = placeMaster.address
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
    }

    mutating func apply(publicPlace selection: PublicPlaceSelectionDraft) {
        publicPlaceSelection = selection
        venueName = selection.entry.officialName
        venueAddress = selection.entry.address
        latitude = selection.entry.latitude
        longitude = selection.entry.longitude
    }

    mutating func clearPlaceSelection() {
        publicPlaceSelection = nil
        venueAddress = ""
        latitude = 0
        longitude = 0
    }

    mutating func clearPlaceCoordinates() {
        publicPlaceSelection = nil
        latitude = 0
        longitude = 0
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedTagNamesRaw: String {
        TheaterEmotionTags.encoded(TheaterEmotionTags.names(from: tagNamesText))
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
            excludedEventCastLinkIDs: excludedEventCastLinkIDs.sorted { $0.uuidString < $1.uuidString },
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries,
            bookReadingHasEndDate: category?.templateKey == "book" ? bookReadingHasEndDate : nil
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
    publicSelection: PublicPlaceSelectionDraft? = nil,
    from placeMasters: [PlaceMaster],
    in modelContext: ModelContext
) -> PlaceMaster? {
    if let publicSelection {
        return PublicPlaceCatalogImporter.resolveSelection(
            publicSelection,
            existingPlaces: placeMasters,
            in: modelContext
        )
    }
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

func deduplicatedPlaceSuggestions(_ places: [PlaceMaster]) -> [PlaceMaster] {
    var results: [PlaceMaster] = []
    for place in places {
        if let index = results.firstIndex(where: { placeSuggestionsReferToSameLocation($0, place) }) {
            if placeSuggestionQuality(place) > placeSuggestionQuality(results[index]) {
                results[index] = place
            }
        } else {
            results.append(place)
        }
    }
    return results
}

func normalizedPlaceSuggestionAddress(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: #"〒?\s*\d{3}[-ー‐‑‒–—―]?\d{4}"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"[-ー‐‑‒–—―]"#, with: "-", options: .regularExpression)
        .replacingOccurrences(of: #"[\s,，、。]"#, with: "", options: .regularExpression)
}

func placeAddressesReferToSameLocation(_ lhs: String, _ rhs: String) -> Bool {
    guard !lhs.isEmpty, !rhs.isEmpty else { return lhs.isEmpty || rhs.isEmpty }
    return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
}

private func placeSuggestionsReferToSameLocation(_ lhs: PlaceMaster, _ rhs: PlaceMaster) -> Bool {
    guard normalizedPlaceText(lhs.name) == normalizedPlaceText(rhs.name) else { return false }

    let lhsHasCoordinate = lhs.latitude != 0 || lhs.longitude != 0
    let rhsHasCoordinate = rhs.latitude != 0 || rhs.longitude != 0
    if lhsHasCoordinate, rhsHasCoordinate {
        let coordinatesAreNear = abs(lhs.latitude - rhs.latitude) < 0.001
            && abs(lhs.longitude - rhs.longitude) < 0.001
        if coordinatesAreNear { return true }
    }

    return placeAddressesReferToSameLocation(
        normalizedPlaceSuggestionAddress(lhs.address),
        normalizedPlaceSuggestionAddress(rhs.address)
    )
}

private func placeSuggestionQuality(_ place: PlaceMaster) -> Int {
    let hasCoordinate = place.latitude != 0 || place.longitude != 0
    let normalizedAddress = normalizedPlaceSuggestionAddress(place.address)
    return (hasCoordinate ? 10_000 : 0) + normalizedAddress.count
}

private extension Date {
    func roundedToNearestFiveMinutes(calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: self)
        let roundedMinute = Int((Double(minute) / 5).rounded()) * 5
        let startOfHour = calendar.dateInterval(of: .hour, for: self)?.start ?? self
        return calendar.date(byAdding: .minute, value: roundedMinute, to: startOfHour) ?? self
    }
}

private func activeUnitDefinitions(for category: RecordCategory?) -> [RecordUnitDefinition] {
    let definitions = RecordUnitDefinition.definitions(for: category?.enabledUnitsRaw ?? "")
    let fallbackDefinitions = RecordUnitDefinition.definitions(for: "basic,officialInfo,memo")
    let baseDefinitions = definitions.isEmpty ? fallbackDefinitions : definitions
    let requiredDefinitions = RecordUnitDefinition.all.filter { RecordUnitDefinition.requiredIDs.contains($0.id) }
    let mergedDefinitions = baseDefinitions + requiredDefinitions
    var seenIDs = Set<String>()
    let uniqueDefinitions = mergedDefinitions.filter { definition in
        guard !seenIDs.contains(definition.id) else { return false }
        seenIDs.insert(definition.id)
        return true
    }
    guard category?.templateKey == "theater" else {
        return uniqueDefinitions
    }

    var theaterDefinitions = uniqueDefinitions.filter { $0.id != "people" }
    let hasViewingRecordUnit = uniqueDefinitions.contains { $0.id == "ticketPlan" || $0.id == "people" }
    if hasViewingRecordUnit, !theaterDefinitions.contains(where: { $0.id == "ticketPlan" }) {
        theaterDefinitions.append(
            RecordUnitDefinition(
                id: "ticketPlan",
                name: "鑑賞記録",
                description: "チケット状態・座席・注目した人",
                isRequired: false
            )
        )
    }
    theaterDefinitions.append(
        RecordUnitDefinition(
            id: "theaterRating",
            name: "評価",
            description: "この回の満足度",
            isRequired: false
        )
    )

    let theaterOrder = [
        "basic",
        "theaterRating",
        "ticketPlan",
        "photos",
        "memo",
        "money",
        "importOCR",
        "officialInfo",
        "advanced",
    ]
    let orderIndex = Dictionary(
        uniqueKeysWithValues: theaterOrder.enumerated().map { ($1, $0) }
    )
    return theaterDefinitions
        .sorted {
            (orderIndex[$0.id] ?? Int.max) < (orderIndex[$1.id] ?? Int.max)
        }
        .map(theaterRecordUnitDefinition)
}

private let bookRecordUnitDefinitions: [RecordUnitDefinition] = [
    RecordUnitDefinition(
        id: "bookInfo",
        name: "本の情報",
        description: "書名、シリーズ・巻数・著者、本の種類",
        isRequired: true
    ),
    RecordUnitDefinition(
        id: "bookReading",
        name: "読書の記録",
        description: "読み始めた日、読み終えた日、評価",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "photos",
        name: "写真",
        description: "この読書記録に残す写真",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "memo",
        name: "読書メモ",
        description: "感想や残しておきたいこと",
        isRequired: false
    ),
]

private func theaterRecordUnitDefinition(
    _ definition: RecordUnitDefinition
) -> RecordUnitDefinition {
    switch definition.id {
    case "basic":
        return RecordUnitDefinition(
            id: definition.id,
            name: "参加日・会場",
            description: "鑑賞日・開演・終演・鑑賞方法・会場",
            isRequired: definition.isRequired
        )
    case "theaterRating":
        return RecordUnitDefinition(
            id: definition.id,
            name: "評価",
            description: "この回の満足度",
            isRequired: false
        )
    case "ticketPlan":
        return RecordUnitDefinition(
            id: definition.id,
            name: "鑑賞記録",
            description: "チケット状態・座席・注目した人",
            isRequired: definition.isRequired
        )
    case "photos":
        return RecordUnitDefinition(
            id: definition.id,
            name: "写真・アイキャッチ",
            description: "この回のアイキャッチ・観劇の写真",
            isRequired: definition.isRequired
        )
    case "memo":
        return RecordUnitDefinition(
            id: definition.id,
            name: "感想・感情タグ",
            description: "感想・感情タグ・その他のタグ",
            isRequired: definition.isRequired
        )
    case "money":
        return RecordUnitDefinition(
            id: definition.id,
            name: "集計記録",
            description: "金額",
            isRequired: definition.isRequired
        )
    case "importOCR":
        return RecordUnitDefinition(
            id: definition.id,
            name: "読み取り情報",
            description: "OCRで取得した原文",
            isRequired: definition.isRequired
        )
    case "officialInfo":
        return RecordUnitDefinition(
            id: definition.id,
            name: "公演公式情報",
            description: "公式URL・SNS・参考リンク",
            isRequired: definition.isRequired
        )
    default:
        return definition
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

private struct TheaterRecordUnitBlock<Content: View>: View {
    @Environment(\.favorecoThemePalette) private var themePalette
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
        if unit.id == "photos" {
            Section {
                content()
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            } header: {
                unitHeader
            }
        } else {
            Section {
                DisclosureGroup(isExpanded: $isExpanded) {
                    content()
                        .padding(.bottom, 4)
                } label: {
                    HStack(spacing: 10) {
                        Text(unit.description)
                            .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text(status.title)
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status.color.opacity(0.12), in: Capsule())
                    }
                    .frame(minHeight: 34)
                }
            } header: {
                unitHeader
            }
        }
    }

    private var unitHeader: some View {
        FavorecoRegistrationSectionHeader(unit.name)
            .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .headline))
            .textCase(nil)
    }
}

private struct SeparatedRecordUnitBlock<Content: View>: View {
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
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                content()
                    .padding(.bottom, 4)
            } label: {
                HStack(spacing: 10) {
                    Text(unit.description)
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary.opacity(0.82))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(status.title)
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(status.color.opacity(0.10), in: Capsule())
                }
                .frame(minHeight: 32)
            }
        } header: {
            FavorecoRegistrationSectionHeader(unit.name)
                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .headline))
                .textCase(nil)
        }
    }
}

#Preview {
    AddExperienceView(category: RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45"))
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
