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
    @Query(sort: \PlaceMaster.name) private var placeMasters: [PlaceMaster]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
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
    @State private var isSaving = false

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
        _expandedUnitIDs = State(
            initialValue: initialExpandedRecordUnitIDs(
                templateKey: category.templateKey,
                stage: .initialRecord
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if category.templateKey == "book" {
                    addBookRecordForm
                } else if category.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation)
                    }
                    stagedTheaterForm(
                        definitions: activeUnitDefinitions(for: category),
                        status: addStatus(for:),
                        isExpanded: binding(for:),
                        content: addContent(for:)
                    )
                } else if category.templateKey == "movie" {
                    stagedScreenWorkForm(
                        status: addStatus(for:),
                        isExpanded: binding(for:),
                        content: addContent(for:)
                    )
                } else if category.templateKey == "live" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation, isLive: true)
                    }
                    stagedLiveForm(
                        definitions: activeUnitDefinitions(for: category),
                        status: addStatus(for:),
                        isExpanded: binding(for:),
                        content: addContent(for:)
                    )
                } else if category.templateKey != "book", isStagedOutingTemplate(category.templateKey) {
                    stagedOutingForm(
                        category: category,
                        status: addStatus(for:),
                        isExpanded: binding(for:),
                        content: addContent(for:)
                    )
                } else if category.templateKey != "book" {
                    stagedGenericRecordForm(
                        category: category,
                        status: addStatus(for:),
                        isExpanded: binding(for:),
                        content: addContent(for:)
                    )
                }
                if category.templateKey == "goshuin" {
                    GoshuinPriorVisitHistory(visits: priorGoshuinVisits)
                }
            }
            .favorecoRegistrationFormCanvas()
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if ["theater", "live"].contains(category.templateKey) {
                    QuickRecordSaveBar(
                        date: draft.visitedAt,
                        isEnabled: draft.canSave && draft.hasValidPerformanceType(for: category),
                        isSaving: isSaving,
                        isLive: category.templateKey == "live",
                        requiresTitle: draft.trimmedTitle.isEmpty,
                        onSave: save
                    )
                }
            }
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
                    .disabled(
                        isSaving
                            || !draft.canSave
                            || !draft.hasValidPerformanceType(for: category)
                    )
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

    private var priorGoshuinVisits: [Visit] {
        matchingPriorVisits(
            in: allVisits,
            placeMasterID: nil,
            venueName: draft.trimmedVenueName
        )
    }

    @ViewBuilder
    private var addBookRecordForm: some View {
        BookRecordEyecatchEditor(
            existingPhotos: [],
            pendingPhotos: $pendingPhotos,
            coverPhotoPath: $coverPhotoPath,
            fallbackImageData: nil
        )

        stagedBookRecordForm(
            status: addBookStatus(for:),
            isExpanded: binding(for:)
        ) { unit in
            addBookContent(for: unit.id)
        }
    }

    private func addBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo": draft.canSave ? .entered : .required
        case "bookReading": .entered
        case "bookRating": draft.overallRating > 0 ? .entered : .optional
        case "photos": addStatus(for: "photos")
        case "memo": addStatus(for: "memo")
        case "advanced": draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
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
                translatorName: $draft.bookTranslatorName,
                isbn: $draft.bookISBN,
                publisherName: $draft.bookPublisherName,
                publishedDate: $draft.bookPublishedDate,
                priceText: $draft.bookPriceText,
                pageCountText: $draft.bookPageCountText,
                officialURL: $draft.officialURL,
                contentTypeKey: $draft.bookContentTypeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: true
            )
        case "bookReading":
            VStack(alignment: .leading, spacing: 14) {
                BookReadingMediumEditor(mediumKey: $draft.bookMediumKey)
                Divider()
                BookReadingPeriodEditor(
                    startsAt: $draft.visitedAt,
                    endsAt: $draft.endedAt,
                    hasEndDate: $draft.bookReadingHasEndDate,
                    rating: $draft.overallRating,
                    ratingText: draft.ratingLabel,
                    showsRating: false
                )
            }
        case "bookRating":
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
                theaterContentMode: .libraryOnly,
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
                styleRuns: $draft.memoStyleRuns,
                placeholder: "感想、引用したい言葉、ページ番号など"
            )
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
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
        case "screenWorkCore":
            return draft.canSave ? .entered : .required
        case "screenWorkViewing":
            return draft.hasScreenWorkViewingDetails ? .entered : .optional
        case "basic":
            return draft.canSave && draft.hasValidPerformanceType(for: category) ? .entered : .required
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "liveSetlist":
            return draft.normalizedLiveSetlistEntries.isEmpty ? .optional : .entered
        case "moments":
            return draft.normalizedMomentEntries.isEmpty ? .optional : .entered
        case "officialInfo":
            let hasOfficialInfo = !draft.trimmedOfficialURL.isEmpty
                || !draft.normalizedSocialLinks.isEmpty
                || !draft.trimmedTheaterCreditsText.isEmpty
            return hasOfficialInfo ? .entered : .optional
        case "people":
            if category.templateKey == "live" {
                return pendingPeople.isEmpty ? .optional : .entered
            }
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
            if category.templateKey == "movie" {
                return draft.trimmedAdvancedEntries.contains { $0.trimmedLabel != "作品時間" }
                    ? .entered
                    : .optional
            }
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        default:
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func addContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "screenWorkCore":
            ScreenWorkMinimumEditor(
                fixedTitle: nil,
                title: $draft.title,
                typeKey: $draft.subTypeKey,
                viewedAt: $draft.visitedAt,
                endedAt: $draft.endedAt,
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel,
                showsRating: false
            )
        case "screenWorkViewing":
            ScreenWorkViewingDetailsEditor(
                typeKey: $draft.subTypeKey,
                styleNamesText: $draft.styleNamesText,
                venueName: venueNameBinding,
                seatText: $draft.seatText,
                advancedEntries: $draft.advancedEntries
            )
        case "basic":
            VStack(alignment: .leading, spacing: 12) {
                ExperienceBasicUnitEditor(
                    template: template,
                    title: $draft.title,
                    seriesName: $draft.seriesName,
                    visitedAt: $draft.visitedAt,
                    endedAt: $draft.endedAt,
                    performanceOpensAt: category.usesOpeningTime ? $draft.performanceOpensAt : nil,
                    styleNamesText: $draft.styleNamesText,
                    venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    overallRating: $draft.overallRating,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    venueOfficialURL: $draft.venueOfficialURL,
                    placeMasters: placeMasters,
                    usesPlaceSuggestions: usesInputSuggestionDictionary,
                    usesMapSearchAssist: usesMapSearchAssist,
                    supportsPerformanceTime: category.usesOpeningTime,
                    supportsExperienceDuration: usesDurationBasedExperienceTime(category),
                    supportsStyles: category.templateKey == "theater",
                    usesExplicitTheaterLayout: ["theater", "live"].contains(category.templateKey),
                    showsRating: !["theater", "live", "museum", "theme_park", "nature_living", "sake"].contains(category.templateKey),
                    datePrecision: screenWorkDatePrecision(
                        for: draft.subTypeKey,
                        category: category
                    ),
                    usesSimpleScreenWorkLayout: category.templateKey == "movie",
                    categoryTemplateKey: category.templateKey,
                    subTypeKey: $draft.subTypeKey,
                    screenWorkSeasonNumber: $draft.screenWorkSeasonNumber,
                    performanceTypeCustomName: $draft.performanceTypeCustomName,
                    ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
                if category.templateKey == "theater" {
                    Divider()
                    PhotoUnitEditor(
                        existingPhotos: [],
                        deletedPhotoIDs: .constant([]),
                        existingPhotoMetadata: .constant([:]),
                        pendingPhotos: $pendingPhotos,
                        selectedItems: .constant([]),
                        category: category,
                        theaterContentMode: .eyecatchOnly,
                        aspectRatioKey: $draft.eyecatchAspectRatioKey,
                        coverPhotoPath: $coverPhotoPath,
                        heroBackgroundPath: $heroBackgroundPath,
                        heroBackgroundPresetKey: $heroBackgroundPresetKey
                    )
                }
                if isStagedOutingTemplate(category.templateKey) {
                    Divider()
                    VisitSubtitleEditor(
                        text: $draft.visitSubtitle,
                        categoryTemplateKey: category.templateKey
                    )
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
                    roleOptions: category.templateKey == "movie" ? screenWorkPeopleRoleOptions : PersonRoleOption.all,
                    emptyDescription: "",
                    allowsOrganizations: category.templateKey != "movie",
                    namePlaceholder: category.templateKey == "movie" ? "監督・出演者名" : "人物・団体名",
                    addButtonTitle: category.templateKey == "movie" ? "監督・出演者を追加" : "人物・団体を追加"
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
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
            )
        case "liveSetlist":
            LiveSetlistEditor(entries: $draft.liveSetlistEntries)
        case "moments":
            VisitMomentEntriesEditor(
                entries: $draft.momentEntries,
                availablePhotos: pendingPhotos.enumerated().map { index, photo in
                    MomentPhotoChoice(
                        id: photo.id,
                        title: photo.metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "写真 \(index + 1)"
                            : photo.metadata.caption,
                        data: photo.data
                    )
                },
                itemName: category.templateKey == "theme_park" ? "イベント・体験" : "見たもの・体験"
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                existingPhotoMetadata: .constant([:]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: category,
                theaterContentMode: .libraryOnly,
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
                expenseEntries: $draft.expenseEntries,
                usesExplicitTheaterLayout: category.templateKey == "theater"
            )
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    styleRuns: $draft.memoStyleRuns,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: category.templateKey == "theater"
                )
                if ["theater", "live"].contains(category.templateKey) {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
        case "advanced":
            if category.templateKey == "movie" {
                ScreenWorkAdditionalDetailsEditor(entries: $draft.advancedEntries)
            } else {
                ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
            }
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
        guard !isSaving,
              draft.canSave,
              draft.hasValidPerformanceType(for: category) else { return }
        isSaving = true
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
        let existingEvent: ExperienceEvent? = if ["theater", "live"].contains(resolvedCategory?.templateKey ?? "") {
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
                authorName: draft.trimmedBookAuthorName,
                translatorName: draft.trimmedBookTranslatorName,
                isbn: draft.trimmedBookISBN,
                publisherName: draft.trimmedBookPublisherName,
                publishedDate: draft.trimmedBookPublishedDate,
                priceText: draft.trimmedBookPriceText,
                pageCount: draft.bookPageCount
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

        let didChangeRepresentativeEyecatch = !coverPhotoPath.isEmpty
            && event.representativeEyecatchPath != coverPhotoPath
        if !coverPhotoPath.isEmpty {
            event.representativeEyecatchPath = coverPhotoPath
        }
        modelContext.insert(visit)
        let usesVisitPeople = ["theater", "live"].contains(category.templateKey)
        insertPendingPeople(for: usesVisitPeople ? nil : event, visit: usesVisitPeople ? visit : nil)
        insertPendingPhotos(for: visit)
        onSave?()

        do {
            try modelContext.save()
            if didChangeRepresentativeEyecatch {
                ThumbnailLoader.purge(reference: .event(event.id))
            }
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
            isSaving = false
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
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @AppStorage(AppStorageKeys.usesMapSearchAssist) private var usesMapSearchAssist = true
    @AppStorage(AppStorageKeys.usesInputSuggestionDictionary) private var usesInputSuggestionDictionary = true
    @AppStorage(AppStorageKeys.photoCompressionQuality) private var photoCompressionQuality = 0.85
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
    @State private var eventEyecatchData: Data?
    @State private var artworkCropDraft: ArtworkPhotoCropDraft?
    @State private var selectedTargetEyecatchItem: PhotosPickerItem?
    @State private var selectedHeroBackgroundItem: PhotosPickerItem?
    @State private var isLoadingTargetEyecatch = false
    @State private var isLoadingHeroBackground = false
    @State private var isShowingTargetEyecatchCamera = false
    @State private var isShowingTargetEyecatchCameraUnavailable = false

    private var event: ExperienceEvent? {
        visit.event
    }

    private var category: RecordCategory? {
        event?.category
    }

    private var isPerformanceVisit: Bool {
        ["theater", "live"].contains(category?.templateKey ?? "")
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
        let initialUnits = initialExpandedRecordUnitIDs(
            templateKey: visit.event?.category?.templateKey ?? "",
            stage: .afterExperience
        )
        _expandedUnitIDs = State(initialValue: initialUnits)
        _coverPhotoPath = State(initialValue: visit.eyecatchPath)
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        _heroBackgroundPath = State(initialValue: unitFields.heroBackgroundPath)
        _heroBackgroundPresetKey = State(initialValue: unitFields.heroBackgroundPresetKey)
        _eventEyecatchData = State(initialValue: visit.event?.eyecatchData)
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
            editRecordPresentationContent
        }
    }

    private var editRecordConfiguredContent: some View {
        editRecordForm
            .favorecoRegistrationFormCanvas()
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .navigationTitle(editRecordNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                editRecordToolbar
            }
    }

    private var editRecordSearchContent: some View {
        editRecordConfiguredContent
            .sheet(isPresented: $isShowingPlaceSearch) {
                ExperiencePlaceSearchView(initialQuery: draft.mapSearchQuery) { candidate in
                    let preservesVenueName = draft.shouldPreserveVenueNameForAddressSearch
                    draft.apply(place: candidate, preservingVenueName: preservesVenueName)
                }
            }
            .alert("保存に失敗しました", isPresented: Binding(
                get: { isShowingSaveError },
                set: { setSaveErrorPresentation($0) }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorText)
            }
    }

    private var editRecordPresentationContent: some View {
        editRecordSearchContent
            .fullScreenCover(item: $artworkCropDraft) { cropDraft in
                ArtworkImageCropView(
                    image: cropDraft.image,
                    aspectRatio: cropDraft.aspectRatio
                ) { adjustedData in
                    eventEyecatchData = adjustedData
                }
            }
            .fullScreenCover(isPresented: $isShowingTargetEyecatchCamera) {
                CameraImagePicker(
                    onCapture: { image in
                        isShowingTargetEyecatchCamera = false
                        presentTargetEyecatchCrop(image)
                    },
                    onCancel: { isShowingTargetEyecatchCamera = false }
                )
                .ignoresSafeArea()
            }
            .alert("カメラを使用できません", isPresented: $isShowingTargetEyecatchCameraUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("この端末ではカメラを利用できません。")
            }
            .onChange(of: selectedTargetEyecatchItem) { _, item in
                guard let item else { return }
                Task { await loadTargetEyecatch(from: item) }
            }
            .onChange(of: selectedHeroBackgroundItem) { _, item in
                guard let item else { return }
                Task { await loadHeroBackground(from: item) }
            }
    }

    private var editRecordNavigationTitle: String {
        if isPerformanceVisit {
            return category?.templateKey == "live"
                ? "参戦記録を編集"
                : TheaterUnifiedFormEntry.visitEditing.navigationTitle
        }
        return isBookVisit ? "読書記録を編集" : "記録を編集"
    }

    @ToolbarContentBuilder
    private var editRecordToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                if isPerformanceVisit {
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
            .disabled(!isPerformanceVisit && !draft.canSave)
        }
    }

    private var isShowingSaveError: Bool {
        saveErrorMessage != nil
    }

    private var saveErrorText: String {
        saveErrorMessage ?? ""
    }

    private func setSaveErrorPresentation(_ isPresented: Bool) {
        if !isPresented {
            saveErrorMessage = nil
        }
    }

    private var editRecordForm: some View {
        Form {
            editRecordFormContent
        }
    }

    @ViewBuilder
    private var editRecordFormContent: some View {
        if !isBookVisit, !isPerformanceVisit {
            editTargetEyecatchSection
        }

        switch category?.templateKey {
        case "book":
            editBookRecordForm
        case "theater":
            Section {
                TheaterUnifiedFormIntroduction(entry: .visitEditing)
            }
            stagedTheaterForm(
                definitions: activeUnitDefinitions(for: category),
                status: editStatus(for:),
                isExpanded: binding(for:),
                content: editContent(for:)
            )
        case "movie":
            stagedScreenWorkForm(
                status: editStatus(for:),
                isExpanded: binding(for:),
                content: editContent(for:)
            )
        case "live":
            Section {
                TheaterUnifiedFormIntroduction(entry: .visitEditing, isLive: true)
            }
            stagedLiveForm(
                definitions: activeUnitDefinitions(for: category),
                status: editStatus(for:),
                isExpanded: binding(for:),
                content: editContent(for:)
            )
        case "museum", "theme_park", "nature_living":
            if let category {
                stagedOutingForm(
                    category: category,
                    status: editStatus(for:),
                    isExpanded: binding(for:),
                    content: editContent(for:)
                )
            }
        default:
            stagedGenericRecordForm(
                category: category,
                status: editStatus(for:),
                isExpanded: binding(for:),
                content: editContent(for:)
            )
        }

        if category?.templateKey == "goshuin" {
            GoshuinPriorVisitHistory(visits: priorGoshuinVisits)
        }
    }

    private var priorGoshuinVisits: [Visit] {
        matchingPriorVisits(
            in: allVisits.filter { $0.id != visit.id },
            placeMasterID: visit.placeMaster?.id,
            venueName: draft.trimmedVenueName
        )
    }

    @ViewBuilder
    private var editTargetEyecatchSection: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let eventEyecatchData, let image = UIImage(data: eventEyecatchData) {
                        Button {
                            presentTargetEyecatchCrop(image)
                        } label: {
                            ZStack(alignment: .bottom) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                FavorecoIcon(systemName: "crop", size: 14)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.68), in: Circle())
                                    .padding(7)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color(.secondarySystemFill)
                            .overlay {
                                FavorecoIcon(systemName: "photo.on.rectangle.angled", size: 27)
                                    .foregroundStyle(themePalette.globalTint)
                            }
                    }
                }
                .frame(width: 132, height: 168)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    PhotosPicker(selection: $selectedTargetEyecatchItem, matching: .images) {
                        FavorecoIconLabel("ライブラリから選ぶ", systemImage: "photo.on.rectangle", iconSize: 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(isLoadingTargetEyecatch)

                    Button {
                        openTargetEyecatchCamera()
                    } label: {
                        FavorecoIconLabel("カメラで撮影", systemImage: "camera", iconSize: 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(role: .destructive) {
                        eventEyecatchData = nil
                    } label: {
                        FavorecoIconLabel("画像を削除", systemImage: "trash", iconSize: 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(eventEyecatchData == nil)
                }
                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                .foregroundStyle(themePalette.globalTint)
                .buttonStyle(.plain)
            }

            if isLoadingTargetEyecatch {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("アイキャッチを準備しています")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("トップ背景")
                    .font(FavorecoTypography.bodyStrong)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(HeroBackgroundPreset.presets(for: category?.templateKey)) { preset in
                        heroBackgroundPresetButton(preset)
                    }
                    heroBackgroundEyecatchButton
                }

                PhotosPicker(selection: $selectedHeroBackgroundItem, matching: .images) {
                    FavorecoIconLabel(
                        heroBackgroundPath.isEmpty ? "ライブラリから選ぶ" : "ライブラリ画像を変更",
                        systemImage: "photo.on.rectangle",
                        iconSize: 15
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingHeroBackground)

                if isLoadingHeroBackground {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("トップ背景を準備しています")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !heroBackgroundPath.isEmpty {
                    FavorecoIconLabel("ライブラリ画像を使用中", systemImage: "checkmark.circle.fill")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(themePalette.globalTint)
                }
            }
        } header: {
            FavorecoRegistrationSectionHeader(
                category?.templateKey == "movie" ? "作品アイキャッチ" : "対象アイキャッチ"
            )
        }
    }

    private func heroBackgroundPresetButton(_ preset: HeroBackgroundPreset) -> some View {
        let isSelected = heroBackgroundPath.isEmpty
            && heroBackgroundPresetKey != HeroBackgroundPreset.eventEyecatchKey
            && HeroBackgroundPreset.resolved(
                categoryKey: category?.templateKey,
                storedKey: heroBackgroundPresetKey
            ) == preset
        return Button {
            heroBackgroundPath = ""
            heroBackgroundPresetKey = preset.key
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let image = heroBackgroundBundledImage(named: preset.resourceName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.08)
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? themePalette.globalTint : Color.secondary.opacity(0.28), lineWidth: isSelected ? 3 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(preset.title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var heroBackgroundEyecatchButton: some View {
        let isSelected = heroBackgroundPath.isEmpty
            && heroBackgroundPresetKey == HeroBackgroundPreset.eventEyecatchKey
        return Button {
            heroBackgroundPath = ""
            heroBackgroundPresetKey = HeroBackgroundPreset.eventEyecatchKey
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let eventEyecatchData, let image = UIImage(data: eventEyecatchData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.08)
                            .overlay {
                                FavorecoIcon(systemName: "photo", size: 22)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? themePalette.globalTint : Color.secondary.opacity(0.28), lineWidth: isSelected ? 3 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("アイキャッチと同じ")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .buttonStyle(.plain)
        .disabled(eventEyecatchData == nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func heroBackgroundBundledImage(named resourceName: String) -> UIImage? {
        if let image = UIImage(named: resourceName) { return image }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    @MainActor
    private func loadHeroBackground(from item: PhotosPickerItem) async {
        isLoadingHeroBackground = true
        defer {
            isLoadingHeroBackground = false
            selectedHeroBackgroundItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let quality = photoCompressionQuality
        guard let photo = await Task.detached(priority: .userInitiated, operation: {
            PendingPhoto.make(
                from: data,
                filename: item.itemIdentifier ?? "hero-background.jpg",
                compressionQuality: quality
            )
        }).value else { return }
        pendingPhotos.append(photo)
        heroBackgroundPath = photo.relativePath
        heroBackgroundPresetKey = ""
    }

    @MainActor
    private func loadTargetEyecatch(from item: PhotosPickerItem) async {
        isLoadingTargetEyecatch = true
        defer {
            isLoadingTargetEyecatch = false
            selectedTargetEyecatchItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        presentTargetEyecatchCrop(image)
    }

    private var editTargetEyecatchAspectRatio: CGFloat {
        CGFloat(
            EyecatchAspectRatio.option(
                for: draft.eyecatchAspectRatioKey,
                category: category
            ).value
        )
    }

    private func presentTargetEyecatchCrop(_ image: UIImage) {
        artworkCropDraft = ArtworkPhotoCropDraft(
            image: image,
            aspectRatio: editTargetEyecatchAspectRatio
        )
    }

    private func openTargetEyecatchCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingTargetEyecatchCameraUnavailable = true
            return
        }
        isShowingTargetEyecatchCamera = true
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

        stagedBookRecordForm(
            status: editBookStatus(for:),
            isExpanded: binding(for:)
        ) { unit in
            editBookContent(for: unit.id)
        }
    }

    private func editBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo": draft.canSave ? .entered : .required
        case "bookReading": .entered
        case "bookRating": draft.overallRating > 0 ? .entered : .optional
        case "photos": visibleExistingPhotos.isEmpty && pendingPhotos.isEmpty ? .optional : .entered
        case "memo": draft.trimmedNote.isEmpty ? .optional : .entered
        case "advanced": draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
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
                translatorName: $draft.bookTranslatorName,
                isbn: $draft.bookISBN,
                publisherName: $draft.bookPublisherName,
                publishedDate: $draft.bookPublishedDate,
                priceText: $draft.bookPriceText,
                pageCountText: $draft.bookPageCountText,
                officialURL: $draft.officialURL,
                contentTypeKey: $draft.bookContentTypeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: true
            )
        case "bookReading":
            VStack(alignment: .leading, spacing: 14) {
                BookReadingMediumEditor(mediumKey: $draft.bookMediumKey)
                Divider()
                BookReadingPeriodEditor(
                    startsAt: $draft.visitedAt,
                    endsAt: $draft.endedAt,
                    hasEndDate: $draft.bookReadingHasEndDate,
                    rating: $draft.overallRating,
                    ratingText: draft.ratingLabel,
                    showsRating: false
                )
            }
        case "bookRating":
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
                theaterContentMode: .libraryOnly,
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
                styleRuns: $draft.memoStyleRuns,
                placeholder: "感想、引用したい言葉、ページ番号など"
            )
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
        default:
            EmptyView()
        }
    }

    private func editStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "screenWorkCore":
            return draft.canSave ? .entered : .required
        case "screenWorkViewing":
            return draft.hasScreenWorkViewingDetails ? .entered : .optional
        case "basic":
            return isTheaterVisit || draft.canSave ? .entered : .required
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "liveSetlist":
            return draft.normalizedLiveSetlistEntries.isEmpty ? .optional : .entered
        case "moments":
            return draft.normalizedMomentEntries.isEmpty ? .optional : .entered
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
            if category?.templateKey == "movie" {
                return draft.trimmedAdvancedEntries.contains { $0.trimmedLabel != "作品時間" }
                    ? .entered
                    : .optional
            }
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        default:
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func editContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "screenWorkCore":
            ScreenWorkMinimumEditor(
                fixedTitle: nil,
                title: $draft.title,
                typeKey: $draft.subTypeKey,
                viewedAt: $draft.visitedAt,
                endedAt: $draft.endedAt,
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel,
                showsRating: false
            )
        case "screenWorkViewing":
            ScreenWorkViewingDetailsEditor(
                typeKey: $draft.subTypeKey,
                styleNamesText: $draft.styleNamesText,
                venueName: venueNameBinding,
                seatText: $draft.seatText,
                advancedEntries: $draft.advancedEntries
            )
        case "basic":
            VStack(alignment: .leading, spacing: 12) {
                if isTheaterVisit || category?.templateKey == "live" {
                    ExperienceBasicUnitEditor(
                        template: template,
                        eventTitle: event?.title ?? "",
                        eventSeriesName: event?.seriesName ?? "",
                        visitedAt: $draft.visitedAt,
                        endedAt: $draft.endedAt,
                        performanceOpensAt: $draft.performanceOpensAt,
                        styleNamesText: $draft.styleNamesText,
                        venueName: venueNameBinding,
                        venueAddress: venueAddressBinding,
                        overallRating: $draft.overallRating,
                        latitude: draft.latitude,
                        longitude: draft.longitude,
                        venueOfficialURL: $draft.venueOfficialURL,
                        placeMasters: placeMasters,
                        usesPlaceSuggestions: usesInputSuggestionDictionary,
                        usesMapSearchAssist: usesMapSearchAssist,
                        supportsPerformanceTime: category?.usesOpeningTime == true,
                        supportsExperienceDuration: usesDurationBasedExperienceTime(category),
                        supportsStyles: category?.templateKey == "theater",
                        usesExplicitTheaterLayout: true,
                        showsRating: false,
                        categoryTemplateKey: category?.templateKey ?? "",
                        subTypeKey: $draft.subTypeKey,
                        screenWorkSeasonNumber: $draft.screenWorkSeasonNumber,
                        performanceTypeCustomName: $draft.performanceTypeCustomName,
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
                        performanceOpensAt: category?.usesOpeningTime == true ? $draft.performanceOpensAt : nil,
                        styleNamesText: $draft.styleNamesText,
                        venueName: venueNameBinding,
                        venueAddress: venueAddressBinding,
                        overallRating: $draft.overallRating,
                        latitude: draft.latitude,
                        longitude: draft.longitude,
                        venueOfficialURL: $draft.venueOfficialURL,
                        placeMasters: placeMasters,
                        usesPlaceSuggestions: usesInputSuggestionDictionary,
                        usesMapSearchAssist: usesMapSearchAssist,
                        supportsPerformanceTime: category?.usesOpeningTime == true,
                        supportsExperienceDuration: usesDurationBasedExperienceTime(category),
                        supportsStyles: false,
                        showsRating: !["museum", "theme_park", "nature_living", "sake"].contains(category?.templateKey ?? ""),
                        datePrecision: screenWorkDatePrecision(
                            for: draft.subTypeKey,
                            category: category
                        ),
                        usesSimpleScreenWorkLayout: category?.templateKey == "movie",
                        categoryTemplateKey: category?.templateKey ?? "",
                        subTypeKey: $draft.subTypeKey,
                        screenWorkSeasonNumber: $draft.screenWorkSeasonNumber,
                        performanceTypeCustomName: $draft.performanceTypeCustomName,
                        ratingText: draft.ratingLabel,
                        onSelectPlace: { draft.apply(placeMaster: $0) },
                        onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                        onOpenPlaceSearch: { isShowingPlaceSearch = true }
                    )
                }
                if let categoryTemplateKey = category?.templateKey,
                   ["theme_park", "nature_living"].contains(categoryTemplateKey) {
                    Divider()
                    VisitSubtitleEditor(
                        text: $draft.visitSubtitle,
                        categoryTemplateKey: categoryTemplateKey
                    )
                }
                if category?.templateKey == "theater" {
                    Divider()
                    PhotoUnitEditor(
                        existingPhotos: visibleExistingPhotos,
                        deletedPhotoIDs: $deletedPhotoIDs,
                        existingPhotoMetadata: $existingPhotoMetadata,
                        pendingPhotos: $pendingPhotos,
                        selectedItems: .constant([]),
                        category: category,
                        theaterContentMode: .eyecatchOnly,
                        aspectRatioKey: $draft.eyecatchAspectRatioKey,
                        coverPhotoPath: $coverPhotoPath,
                        heroBackgroundPath: $heroBackgroundPath,
                        heroBackgroundPresetKey: $heroBackgroundPresetKey
                    )
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
                    roleOptions: category?.templateKey == "movie" ? screenWorkPeopleRoleOptions : PersonRoleOption.all,
                    emptyDescription: "",
                    allowsOrganizations: category?.templateKey != "movie",
                    namePlaceholder: category?.templateKey == "movie" ? "監督・出演者名" : "人物・団体名",
                    addButtonTitle: category?.templateKey == "movie" ? "監督・出演者を追加" : "人物・団体を追加"
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
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
            )
        case "liveSetlist":
            LiveSetlistEditor(entries: $draft.liveSetlistEntries)
        case "moments":
            VisitMomentEntriesEditor(
                entries: $draft.momentEntries,
                availablePhotos: momentPhotoChoices,
                itemName: category?.templateKey == "theme_park" ? "イベント・体験" : "見たもの・体験"
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: visibleExistingPhotos,
                deletedPhotoIDs: $deletedPhotoIDs,
                existingPhotoMetadata: $existingPhotoMetadata,
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: event?.category,
                theaterContentMode: .libraryOnly,
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
                expenseEntries: $draft.expenseEntries,
                usesExplicitTheaterLayout: isTheaterVisit
            )
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    styleRuns: $draft.memoStyleRuns,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: isTheaterVisit
                )
                if isTheaterVisit {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
        case "advanced":
            if category?.templateKey == "movie" {
                ScreenWorkAdditionalDetailsEditor(entries: $draft.advancedEntries)
            } else {
                ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
            }
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

        let didChangeEventEyecatch = !isPerformanceVisit && event?.eyecatchData != eventEyecatchData
        if let event {
            applyTargetChangesFromExperienceEdit(
                to: event,
                draft: draft,
                categories: categories,
                at: now
            )
            if !isPerformanceVisit {
                event.eyecatchData = eventEyecatchData
            }
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
        if ["theater", "live"].contains(category?.templateKey ?? "") {
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
        if isPerformanceVisit {
            insertPendingPeople(for: nil, visit: visit)
        } else {
            insertPendingPeople(for: event, visit: nil)
        }
        applyExistingPhotoMetadata()
        deleteMarkedPhotos()
        insertPendingPhotos(for: visit)

        do {
            try modelContext.save()
            if didChangeEventEyecatch, let event {
                ThumbnailLoader.purge(reference: .event(event.id))
            }
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

    private var momentPhotoChoices: [MomentPhotoChoice] {
        let existing = visibleExistingPhotos.enumerated().map { index, photo in
            MomentPhotoChoice(
                id: photo.id,
                title: photo.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "写真 \(index + 1)"
                    : photo.caption,
                data: photo.data
            )
        }
        let pending = pendingPhotos.enumerated().map { index, photo in
            MomentPhotoChoice(
                id: photo.id,
                title: photo.metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "追加写真 \(index + 1)"
                    : photo.metadata.caption,
                data: photo.data
            )
        }
        return existing + pending
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
               !metadata.purpose.isGalleryPhoto,
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
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
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
    @State private var isSaving = false
    @State private var screenWorkTypeKey: String
    @State private var screenWorkSeasonNumber: Int
    @State private var performanceTypeKey: String
    @State private var performanceTypeCustomName: String
    @State private var bookTitle: String
    @State private var bookSeriesName: String
    @State private var bookVolumeNumber: String
    @State private var bookAuthorName: String
    @State private var bookTranslatorName: String
    @State private var bookISBN: String
    @State private var bookPublisherName: String
    @State private var bookPublishedDate: String
    @State private var bookPriceText: String
    @State private var bookPageCountText: String
    @State private var bookContentTypeKey: String
    @State private var bookOfficialURL: String

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
        if event.category?.templateKey == "book" {
            let eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            preparedDraft.bookMediumKey = eventFields.bookMediumKey.isEmpty
                ? BookReadingMedium.paper.rawValue
                : eventFields.bookMediumKey
        }
        let inheritedVisuals = Self.makeInheritedVisuals(from: inheritedVisualSource)
        _draft = State(initialValue: preparedDraft)
        _pendingPhotos = State(initialValue: inheritedVisuals.photos)
        _coverPhotoPath = State(initialValue: inheritedVisuals.coverPath ?? initialCoverPhotoPath)
        _heroBackgroundPath = State(initialValue: inheritedVisuals.backgroundPath ?? initialHeroBackgroundPath)
        _heroBackgroundPresetKey = State(initialValue: initialHeroBackgroundPresetKey)
        _screenWorkTypeKey = State(initialValue: event.screenWorkType.rawValue)
        _screenWorkSeasonNumber = State(initialValue: event.screenWorkSeasonNumber)
        _performanceTypeKey = State(initialValue: event.subTypeKey)
        _performanceTypeCustomName = State(
            initialValue: VisitUnitFields(rawValue: event.unitFieldsRaw).eventPerformanceTypeCustomName
        )
        _bookTitle = State(initialValue: event.title)
        _bookSeriesName = State(initialValue: event.bookSeriesName)
        _bookVolumeNumber = State(initialValue: event.bookVolumeNumber)
        _bookAuthorName = State(initialValue: event.bookAuthorName)
        _bookTranslatorName = State(initialValue: event.bookTranslatorName)
        _bookISBN = State(initialValue: event.bookISBN)
        _bookPublisherName = State(initialValue: event.bookPublisherName)
        _bookPublishedDate = State(initialValue: event.bookPublishedDate)
        _bookPriceText = State(initialValue: event.bookPriceText)
        _bookPageCountText = State(initialValue: event.bookPageCount > 0 ? String(event.bookPageCount) : "")
        _bookContentTypeKey = State(initialValue: VisitUnitFields(rawValue: event.unitFieldsRaw).bookContentTypeKey)
        _bookOfficialURL = State(initialValue: event.officialURL)
        let openingStage: RecordFormOpeningStage = if sourcePlan?.hasConfirmedSchedule == true {
            .afterExperience
        } else {
            .plannedTarget
        }
        _expandedUnitIDs = State(
            initialValue: initialExpandedRecordUnitIDs(
                templateKey: event.category?.templateKey ?? "",
                stage: openingStage
            )
        )
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
                } else if event.category?.templateKey == "theater" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation)
                    }
                    stagedTheaterForm(
                        definitions: activeUnitDefinitions(for: event.category),
                        status: visitStatus(for:),
                        isExpanded: binding(for:),
                        content: visitContent(for:)
                    )
                } else if event.category?.templateKey == "movie" {
                    stagedScreenWorkForm(
                        status: visitStatus(for:),
                        isExpanded: binding(for:),
                        content: visitContent(for:)
                    )
                } else if event.category?.templateKey == "live" {
                    Section {
                        TheaterUnifiedFormIntroduction(entry: .visitCreation, isLive: true)
                    }
                    stagedLiveForm(
                        definitions: activeUnitDefinitions(for: event.category),
                        status: visitStatus(for:),
                        isExpanded: binding(for:),
                        content: visitContent(for:)
                    )
                } else if event.category?.templateKey != "book",
                          let category = event.category,
                          isStagedOutingTemplate(category.templateKey) {
                    stagedOutingForm(
                        category: category,
                        status: visitStatus(for:),
                        isExpanded: binding(for:),
                        content: visitContent(for:)
                    )
                } else if event.category?.templateKey != "book" {
                    stagedGenericRecordForm(
                        category: event.category,
                        status: visitStatus(for:),
                        isExpanded: binding(for:),
                        content: visitContent(for:)
                    )
                }
                if event.category?.templateKey == "goshuin" {
                    GoshuinPriorVisitHistory(visits: priorGoshuinVisits)
                }
            }
            .favorecoRegistrationFormCanvas()
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .tint(themePalette.globalTint)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if ["theater", "live"].contains(event.category?.templateKey ?? "") {
                    QuickRecordSaveBar(
                        date: draft.visitedAt,
                        isEnabled: true,
                        isSaving: isSaving,
                        isLive: event.category?.templateKey == "live",
                        requiresTitle: false,
                        onSave: save
                    )
                }
            }
            .navigationTitle(
                ["theater", "live"].contains(event.category?.templateKey ?? "")
                    ? (event.category?.templateKey == "live" ? "参戦記録を追加" : TheaterUnifiedFormEntry.visitCreation.navigationTitle)
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
                        if ["theater", "live"].contains(event.category?.templateKey ?? "") {
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
                    .disabled(
                        isSaving
                            || (event.category?.templateKey == "book"
                                && bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
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

    private var priorGoshuinVisits: [Visit] {
        matchingPriorVisits(
            in: allVisits,
            placeMasterID: nil,
            venueName: draft.trimmedVenueName
        )
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

        stagedBookRecordForm(
            status: addVisitBookStatus(for:),
            isExpanded: binding(for:)
        ) { unit in
            addVisitBookContent(for: unit.id)
        }
    }

    private func addVisitBookStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "bookInfo", "bookReading": .entered
        case "bookRating": draft.overallRating > 0 ? .entered : .optional
        case "photos": pendingPhotos.isEmpty ? .optional : .entered
        case "memo": draft.trimmedNote.isEmpty ? .optional : .entered
        case "advanced": draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        default: .optional
        }
    }

    @ViewBuilder
    private func addVisitBookContent(for unitID: String) -> some View {
        switch unitID {
        case "bookInfo":
            BookInformationEditor(
                title: $bookTitle,
                seriesName: $bookSeriesName,
                volumeNumber: $bookVolumeNumber,
                authorName: $bookAuthorName,
                translatorName: $bookTranslatorName,
                isbn: $bookISBN,
                publisherName: $bookPublisherName,
                publishedDate: $bookPublishedDate,
                priceText: $bookPriceText,
                pageCountText: $bookPageCountText,
                officialURL: $bookOfficialURL,
                contentTypeKey: $bookContentTypeKey,
                aspectRatioKey: $draft.eyecatchAspectRatioKey,
                isEditable: true
            )
        case "bookReading":
            VStack(alignment: .leading, spacing: 14) {
                BookReadingMediumEditor(mediumKey: $draft.bookMediumKey)
                Divider()
                BookReadingPeriodEditor(
                    startsAt: $draft.visitedAt,
                    endsAt: $draft.endedAt,
                    hasEndDate: $draft.bookReadingHasEndDate,
                    rating: $draft.overallRating,
                    ratingText: draft.ratingLabel,
                    showsRating: false
                )
            }
        case "bookRating":
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
                category: event.category,
                theaterContentMode: .libraryOnly,
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
                styleRuns: $draft.memoStyleRuns,
                placeholder: "感想、引用したい言葉、ページ番号など"
            )
        case "advanced":
            ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
        default:
            EmptyView()
        }
    }

    private func visitStatus(for unitID: String) -> RecordUnitStatus {
        switch unitID {
        case "screenWorkCore":
            return .entered
        case "screenWorkViewing":
            return draft.hasScreenWorkViewingDetails ? .entered : .optional
        case "basic":
            return .entered
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            return draft.overallRating > 0 ? .entered : .optional
        case "liveSetlist":
            return draft.normalizedLiveSetlistEntries.isEmpty ? .optional : .entered
        case "moments":
            return draft.normalizedMomentEntries.isEmpty ? .optional : .entered
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
            if event.category?.templateKey == "movie" {
                return draft.trimmedAdvancedEntries.contains { $0.trimmedLabel != "作品時間" }
                    ? .entered
                    : .optional
            }
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        default:
            return draft.trimmedAdvancedEntries.isEmpty ? .optional : .entered
        }
    }

    @ViewBuilder
    private func visitContent(for unit: RecordUnitDefinition) -> some View {
        switch unit.id {
        case "screenWorkCore":
            ScreenWorkMinimumEditor(
                fixedTitle: event.title,
                title: nil,
                typeKey: $screenWorkTypeKey,
                viewedAt: $draft.visitedAt,
                endedAt: $draft.endedAt,
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel,
                showsRating: false
            )
        case "screenWorkViewing":
            ScreenWorkViewingDetailsEditor(
                typeKey: $screenWorkTypeKey,
                styleNamesText: $draft.styleNamesText,
                venueName: venueNameBinding,
                seatText: $draft.seatText,
                advancedEntries: $draft.advancedEntries
            )
        case "basic":
            VStack(alignment: .leading, spacing: 12) {
                ExperienceBasicUnitEditor(
                    template: template,
                    eventTitle: event.title,
                    eventSeriesName: event.seriesName,
                    visitedAt: $draft.visitedAt,
                    endedAt: $draft.endedAt,
                    performanceOpensAt: event.category?.usesOpeningTime == true ? $draft.performanceOpensAt : nil,
                    styleNamesText: $draft.styleNamesText,
                    venueName: venueNameBinding,
                    venueAddress: venueAddressBinding,
                    overallRating: $draft.overallRating,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    venueOfficialURL: $draft.venueOfficialURL,
                    placeMasters: placeMasters,
                    usesPlaceSuggestions: usesInputSuggestionDictionary,
                    usesMapSearchAssist: usesMapSearchAssist,
                    supportsPerformanceTime: event.category?.usesOpeningTime == true,
                    supportsExperienceDuration: usesDurationBasedExperienceTime(event.category),
                    supportsStyles: event.category?.templateKey == "theater",
                    usesExplicitTheaterLayout: ["theater", "live"].contains(event.category?.templateKey ?? ""),
                    showsRating: !["theater", "live", "museum", "theme_park", "nature_living", "sake"].contains(event.category?.templateKey ?? ""),
                    datePrecision: screenWorkDatePrecision(
                        for: screenWorkTypeKey,
                        category: event.category
                    ),
                    usesSimpleScreenWorkLayout: event.category?.templateKey == "movie",
                    categoryTemplateKey: event.category?.templateKey ?? "",
                    subTypeKey: event.category?.templateKey == "movie"
                        ? $screenWorkTypeKey
                        : ["theater", "live"].contains(event.category?.templateKey ?? "")
                            ? $performanceTypeKey
                            : .constant(event.subTypeKey),
                    screenWorkSeasonNumber: event.category?.templateKey == "movie" ? $screenWorkSeasonNumber : .constant(0),
                    performanceTypeCustomName: $performanceTypeCustomName,
                    ratingText: draft.ratingLabel,
                    onSelectPlace: { draft.apply(placeMaster: $0) },
                    onSelectPublicPlace: { draft.apply(publicPlace: $0) },
                    onOpenPlaceSearch: { isShowingPlaceSearch = true }
                )
                if let categoryTemplateKey = event.category?.templateKey,
                   ["theme_park", "nature_living"].contains(categoryTemplateKey) {
                    Divider()
                    VisitSubtitleEditor(
                        text: $draft.visitSubtitle,
                        categoryTemplateKey: categoryTemplateKey
                    )
                }
                if event.category?.templateKey == "theater" {
                    Divider()
                    PhotoUnitEditor(
                        existingPhotos: [],
                        deletedPhotoIDs: .constant([]),
                        existingPhotoMetadata: .constant([:]),
                        pendingPhotos: $pendingPhotos,
                        selectedItems: .constant([]),
                        category: event.category,
                        theaterContentMode: .eyecatchOnly,
                        aspectRatioKey: $draft.eyecatchAspectRatioKey,
                        coverPhotoPath: $coverPhotoPath,
                        heroBackgroundPath: $heroBackgroundPath,
                        heroBackgroundPresetKey: $heroBackgroundPresetKey
                    )
                }
            }
        case "memo":
            VStack(alignment: .leading, spacing: 16) {
                ExperienceMemoUnitEditor(
                    text: $draft.note,
                    styleRuns: $draft.memoStyleRuns,
                    placeholder: template.memoPlaceholder,
                    usesExplicitTheaterLayout: event.category?.templateKey == "theater"
                )
                if ["theater", "live"].contains(event.category?.templateKey ?? "") {
                    Divider()
                    ExperienceEmotionTagEditor(tagNamesText: $draft.tagNamesText)
                }
            }
        case "moments":
            VisitMomentEntriesEditor(
                entries: $draft.momentEntries,
                availablePhotos: pendingPhotos.enumerated().map { index, photo in
                    MomentPhotoChoice(
                        id: photo.id,
                        title: photo.metadata.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "写真 \(index + 1)"
                            : photo.metadata.caption,
                        data: photo.data
                    )
                },
                itemName: event.category?.templateKey == "theme_park" ? "イベント・体験" : "見たもの・体験"
            )
        case "photos":
            PhotoUnitEditor(
                existingPhotos: [],
                deletedPhotoIDs: .constant([]),
                existingPhotoMetadata: .constant([:]),
                pendingPhotos: $pendingPhotos,
                selectedItems: $selectedPhotoItems,
                category: event.category,
                theaterContentMode: .libraryOnly,
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
                    roleOptions: event.category?.templateKey == "movie" ? screenWorkPeopleRoleOptions : PersonRoleOption.all,
                    emptyDescription: "",
                    allowsOrganizations: event.category?.templateKey != "movie",
                    namePlaceholder: event.category?.templateKey == "movie" ? "監督・出演者名" : "人物・団体名",
                    addButtonTitle: event.category?.templateKey == "movie" ? "監督・出演者を追加" : "人物・団体を追加"
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
        case "theaterRating", "liveRating", "outingRating", "screenWorkRating":
            ExperienceRatingUnitEditor(
                overallRating: $draft.overallRating,
                ratingText: draft.ratingLabel
            )
        case "liveSetlist":
            LiveSetlistEditor(entries: $draft.liveSetlistEntries)
        case "money":
            ExperienceMoneyUnitEditor(
                amountText: $draft.amountText,
                expenseEntries: $draft.expenseEntries,
                usesExplicitTheaterLayout: event.category?.templateKey == "theater"
            )
        case "advanced":
            if event.category?.templateKey == "movie" {
                ScreenWorkAdditionalDetailsEditor(entries: $draft.advancedEntries)
            } else {
                ExperienceAdvancedUnitEditor(entries: $draft.advancedEntries)
            }
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
        guard !isSaving else { return }
        isSaving = true
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
        if event.category?.templateKey == "theater" {
            event.subTypeKey = performanceTypeKey
            var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            eventFields.eventPerformanceTypeCustomName = TheaterPerformanceType.customNameForStorage(
                key: performanceTypeKey,
                input: performanceTypeCustomName
            )
            event.unitFieldsRaw = eventFields.encodedRawValue
        } else if event.category?.templateKey == "live" {
            event.subTypeKey = performanceTypeKey
            var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            eventFields.eventPerformanceTypeCustomName = LivePerformanceType.customNameForStorage(
                key: performanceTypeKey,
                input: performanceTypeCustomName
            )
            event.unitFieldsRaw = eventFields.encodedRawValue
        }
        if event.category?.templateKey == "book" {
            event.title = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            event.officialURL = bookOfficialURL.trimmingCharacters(in: .whitespacesAndNewlines)
            event.applyBookMetadata(
                seriesName: bookSeriesName,
                volumeNumber: bookVolumeNumber,
                authorName: bookAuthorName,
                translatorName: bookTranslatorName,
                isbn: bookISBN,
                publisherName: bookPublisherName,
                publishedDate: bookPublishedDate,
                priceText: bookPriceText,
                pageCount: max(Int(bookPageCountText.filter(\.isNumber)) ?? 0, 0)
            )
            var eventFields = VisitUnitFields(rawValue: event.unitFieldsRaw)
            eventFields.eyecatchAspectRatioKey = draft.eyecatchAspectRatioKey
            eventFields.bookContentTypeKey = bookContentTypeKey
            eventFields.bookMediumKey = draft.bookMediumKey
            event.unitFieldsRaw = eventFields.encodedRawValue
        }
        event.updatedAt = now
        if let sourcePlan {
            for photo in sourcePlan.photos ?? [] {
                photo.plan = nil
                photo.visit = visit
            }
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
            isSaving = false
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
    var bookTranslatorName: String = ""
    var bookISBN: String = ""
    var bookPublisherName: String = ""
    var bookPublishedDate: String = ""
    var bookPriceText: String = ""
    var bookPageCountText: String = ""
    var bookContentTypeKey: String = ""
    var bookMediumKey: String = BookReadingMedium.paper.rawValue
    var subTypeKey: String = ""
    var screenWorkSeasonNumber: Int = 0
    var performanceTypeCustomName: String = ""
    var officialURL: String = ""
    var socialLinksText: String = ""
    var eventSubtitle: String = ""
    var visitSubtitle: String = ""
    var theaterCreditsText: String = ""
    var visitedAt: Date = Date()
    var endedAt: Date = Date()
    var performanceOpensAt: Date?
    var bookReadingHasEndDate: Bool = true
    var styleNamesText: String = ""
    var venueName: String = ""
    var venueAddress: String = ""
    var venueOfficialURL: String = ""
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
    var liveSetlistEntries: [LiveSetlistEntry] = []
    var amountText: String = ""
    var expenseEntries: [VisitExpenseEntry] = []
    var momentEntries: [VisitMomentEntry] = []
    var note: String = ""
    var memoStyleRuns: [MemoStyleRun] = []
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
        bookTranslatorName = eventFields.bookTranslatorName
        bookISBN = eventFields.bookISBN
        bookPublisherName = eventFields.bookPublisherName
        bookPublishedDate = eventFields.bookPublishedDate
        bookPriceText = eventFields.bookPriceText
        bookPageCountText = eventFields.bookPageCount > 0 ? String(eventFields.bookPageCount) : ""
        bookContentTypeKey = eventFields.bookContentTypeKey
        bookMediumKey = eventFields.bookMediumKey.isEmpty
            ? BookReadingMedium.paper.rawValue
            : eventFields.bookMediumKey
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
        venueAddress = visit.placeMaster?.address
            ?? VisitUnitFields(rawValue: visit.unitFieldsRaw).venueAddressSnapshot
        venueOfficialURL = visit.placeMaster?.officialURL ?? ""
        let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
        latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
        longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
        overallRating = visit.overallRating
        outcomeKey = visit.outcomeKey
        seatText = visit.seatText
        let unitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        performanceOpensAt = unitFields.performanceOpensAt
        visitSubtitle = unitFields.visitSubtitle
        ocrText = unitFields.ocrText
        eyecatchAspectRatioKey = unitFields.eyecatchAspectRatioKey
        goshuinBookSizeKey = unitFields.goshuinBookSizeKey
        advancedEntries = unitFields.advancedEntries
        liveSetlistEntries = unitFields.liveSetlistEntries
        expenseEntries = unitFields.expenseEntries
        momentEntries = unitFields.momentEntries
        amountText = formattedCurrencyAmount(visit.amount)
        note = visit.note
        memoStyleRuns = unitFields.memoStyleRuns
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

    var trimmedBookTranslatorName: String {
        bookTranslatorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookISBN: String {
        bookISBN.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublisherName: String {
        bookPublisherName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPublishedDate: String {
        bookPublishedDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBookPriceText: String {
        bookPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bookPageCount: Int {
        max(Int(bookPageCountText.filter(\.isNumber)) ?? 0, 0)
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
        PlaceSnapshot(
            name: trimmedVenueName,
            address: venueAddress,
            latitude: latitude,
            longitude: longitude,
            officialURL: venueOfficialURL
        )
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
        venueOfficialURL = ""
        venueOfficialURL = ""
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
        venueOfficialURL = placeMaster.officialURL
        latitude = placeMaster.latitude
        longitude = placeMaster.longitude
        venueOfficialURL = placeMaster.officialURL
    }

    mutating func apply(publicPlace selection: PublicPlaceSelectionDraft) {
        publicPlaceSelection = selection
        venueName = selection.entry.officialName
        venueAddress = selection.entry.address
        venueOfficialURL = selection.entry.officialURL
        latitude = selection.entry.latitude
        longitude = selection.entry.longitude
        venueOfficialURL = selection.entry.officialURL
    }

    mutating func clearPlaceSelection() {
        publicPlaceSelection = nil
        venueAddress = ""
        venueOfficialURL = ""
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

    var normalizedLiveSetlistEntries: [LiveSetlistEntry] {
        liveSetlistEntries.map(\.normalized).filter { !$0.isEmpty }
    }

    var normalizedMomentEntries: [VisitMomentEntry] {
        momentEntries.map(\.normalized).filter { !$0.isEmpty }
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    var hasScreenWorkViewingDetails: Bool {
        !styleNamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !trimmedVenueName.isEmpty
            || !trimmedSeatText.isEmpty
            || trimmedAdvancedEntries.contains { $0.trimmedLabel == "作品時間" && !$0.trimmedValue.isEmpty }
    }

    func makeUnitFields(for category: RecordCategory?) -> VisitUnitFields {
        VisitUnitFields(
            ocrText: trimmedOCRText,
            styleNames: normalizedStyleNames(from: styleNamesText),
            visitSubtitle: visitSubtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            venueAddressSnapshot: venueAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            performanceOpensAt: category?.usesOpeningTime == true ? performanceOpensAt : nil,
            excludedEventCastLinkIDs: excludedEventCastLinkIDs.sorted { $0.uuidString < $1.uuidString },
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
            memoStyleRuns: memoStyleRuns,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries,
            liveSetlistEntries: category?.templateKey == "live" ? normalizedLiveSetlistEntries : [],
            expenseEntries: expenseEntries
                .map { VisitExpenseEntry(id: $0.id, title: $0.normalizedTitle, amount: $0.normalizedAmount) }
                .filter { !$0.isEmpty },
            momentEntries: normalizedMomentEntries,
            bookMediumKey: category?.templateKey == "book" ? bookMediumKey : "",
            bookReadingHasEndDate: category?.templateKey == "book" ? bookReadingHasEndDate : nil
        )
    }

    func eventUnitFieldsRaw(for category: RecordCategory?) -> String {
        return VisitUnitFields(
            socialLinks: normalizedSocialLinks,
            eventSubtitle: trimmedEventSubtitle,
            eventCreditsText: trimmedTheaterCreditsText,
            eventPerformanceTypeCustomName: category?.templateKey == "live"
                ? LivePerformanceType.customNameForStorage(key: subTypeKey, input: performanceTypeCustomName)
                : TheaterPerformanceType.customNameForStorage(key: subTypeKey, input: performanceTypeCustomName),
            screenWorkSeasonNumber: category?.templateKey == "movie"
                && ScreenWorkType.resolved(from: subTypeKey).supportsSeason
                ? screenWorkSeasonNumber
                : 0,
            eyecatchAspectRatioKey: category?.templateKey == "book"
                ? (eyecatchAspectRatioKey.isEmpty ? EyecatchAspectRatio.hardcoverBook.key : eyecatchAspectRatioKey)
                : "",
            bookSeriesName: category?.templateKey == "book" ? trimmedBookSeriesName : "",
            bookVolumeNumber: category?.templateKey == "book" ? trimmedBookVolumeNumber : "",
            bookAuthorName: category?.templateKey == "book" ? trimmedBookAuthorName : "",
            bookTranslatorName: category?.templateKey == "book" ? trimmedBookTranslatorName : "",
            bookISBN: category?.templateKey == "book" ? trimmedBookISBN : "",
            bookPublisherName: category?.templateKey == "book" ? trimmedBookPublisherName : "",
            bookPublishedDate: category?.templateKey == "book" ? trimmedBookPublishedDate : "",
            bookPriceText: category?.templateKey == "book" ? trimmedBookPriceText : "",
            bookPageCount: category?.templateKey == "book" ? bookPageCount : 0,
            bookContentTypeKey: category?.templateKey == "book" ? bookContentTypeKey : "",
            bookMediumKey: category?.templateKey == "book" ? bookMediumKey : ""
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

struct OutingFacilityTypePicker: View {
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
    guard !["theater", "live"].contains(event.category?.templateKey ?? "") else { return }

    event.title = draft.trimmedTitle
    if event.category?.templateKey == "book" {
        event.applyBookMetadata(
            seriesName: draft.trimmedBookSeriesName,
            volumeNumber: draft.trimmedBookVolumeNumber,
            authorName: draft.trimmedBookAuthorName,
            translatorName: draft.trimmedBookTranslatorName,
            isbn: draft.trimmedBookISBN,
            publisherName: draft.trimmedBookPublisherName,
            publishedDate: draft.trimmedBookPublishedDate,
            priceText: draft.trimmedBookPriceText,
            pageCount: draft.bookPageCount
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
        eventFields.bookContentTypeKey = draft.bookContentTypeKey
        eventFields.bookSeriesName = draft.trimmedBookSeriesName
        eventFields.bookVolumeNumber = draft.trimmedBookVolumeNumber
        eventFields.bookAuthorName = draft.trimmedBookAuthorName
        eventFields.bookTranslatorName = draft.trimmedBookTranslatorName
        eventFields.bookISBN = draft.trimmedBookISBN
        eventFields.bookPublisherName = draft.trimmedBookPublisherName
        eventFields.bookPublishedDate = draft.trimmedBookPublishedDate
        eventFields.bookPriceText = draft.trimmedBookPriceText
        eventFields.bookPageCount = draft.bookPageCount
        eventFields.bookMediumKey = draft.bookMediumKey
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

private func usesDurationBasedExperienceTime(_ category: RecordCategory?) -> Bool {
    guard let templateKey = category?.templateKey else { return false }
    return ["museum", "theme_park", "nature_living", "outing_facility"].contains(templateKey)
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
    var performanceOpensAt: Date?
    var bookReadingHasEndDate: Bool = true
    var bookMediumKey: String = BookReadingMedium.paper.rawValue
    var styleNamesText: String = ""
    var visitSubtitle: String = ""
    var venueName: String = ""
    var venueAddress: String = ""
    var venueOfficialURL: String = ""
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
    var liveSetlistEntries: [LiveSetlistEntry] = []
    var amountText: String = ""
    var expenseEntries: [VisitExpenseEntry] = []
    var momentEntries: [VisitMomentEntry] = []
    var note: String = ""
    var memoStyleRuns: [MemoStyleRun] = []
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
        performanceOpensAt = plan.event?.category?.usesOpeningTime == true ? plan.opensAt : nil
        venueName = plan.venueNameSnapshot
        venueAddress = plan.placeMaster?.address ?? ""
        venueOfficialURL = plan.placeMaster?.officialURL ?? ""
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
        venueAddress = place?.address ?? previousFields.venueAddressSnapshot
        venueOfficialURL = place?.officialURL ?? ""
        latitude = hasVisitCoordinate ? visit.latitude : (place?.latitude ?? 0)
        longitude = hasVisitCoordinate ? visit.longitude : (place?.longitude ?? 0)
        eyecatchAspectRatioKey = previousFields.eyecatchAspectRatioKey
        bookMediumKey = previousFields.bookMediumKey.isEmpty
            ? BookReadingMedium.paper.rawValue
            : previousFields.bookMediumKey
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
        PlaceSnapshot(
            name: trimmedVenueName,
            address: venueAddress,
            latitude: latitude,
            longitude: longitude,
            officialURL: venueOfficialURL
        )
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

    var normalizedLiveSetlistEntries: [LiveSetlistEntry] {
        liveSetlistEntries.map(\.normalized).filter { !$0.isEmpty }
    }

    var normalizedMomentEntries: [VisitMomentEntry] {
        momentEntries.map(\.normalized).filter { !$0.isEmpty }
    }

    var hasTicketPlan: Bool {
        !outcomeKey.isEmpty || !trimmedSeatText.isEmpty
    }

    var hasScreenWorkViewingDetails: Bool {
        !styleNamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !trimmedVenueName.isEmpty
            || !trimmedSeatText.isEmpty
            || trimmedAdvancedEntries.contains { $0.trimmedLabel == "作品時間" && !$0.trimmedValue.isEmpty }
    }

    func makeUnitFields(for category: RecordCategory?) -> VisitUnitFields {
        VisitUnitFields(
            ocrText: trimmedOCRText,
            styleNames: normalizedStyleNames(from: styleNamesText),
            visitSubtitle: visitSubtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            venueAddressSnapshot: venueAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            performanceOpensAt: category?.usesOpeningTime == true ? performanceOpensAt : nil,
            excludedEventCastLinkIDs: excludedEventCastLinkIDs.sorted { $0.uuidString < $1.uuidString },
            eyecatchAspectRatioKey: eyecatchAspectRatioKey.isEmpty
                ? (category?.templateKey == "book" ? EyecatchAspectRatio.hardcoverBook.key : EyecatchAspectRatio.recommended(for: category).key)
                : eyecatchAspectRatioKey,
            memoStyleRuns: memoStyleRuns,
            goshuinBookSizeKey: category?.templateKey == "goshuin" && goshuinBookSizeKey.isEmpty ? GoshuinBookSize.standard.key : goshuinBookSizeKey,
            advancedEntries: trimmedAdvancedEntries,
            liveSetlistEntries: category?.templateKey == "live" ? normalizedLiveSetlistEntries : [],
            expenseEntries: expenseEntries
                .map { VisitExpenseEntry(id: $0.id, title: $0.normalizedTitle, amount: $0.normalizedAmount) }
                .filter { !$0.isEmpty },
            momentEntries: normalizedMomentEntries,
            bookMediumKey: category?.templateKey == "book" ? bookMediumKey : "",
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

private struct VisitSubtitleEditor: View {
    @Binding var text: String
    let categoryTemplateKey: String

    private var title: String {
        categoryTemplateKey == "theme_park" ? "イベント名" : "見たもの・体験"
    }

    private var prompt: String {
        categoryTemplateKey == "theme_park"
            ? "例：ハロウィーン"
            : "例：クラゲ展示"
    }

    var body: some View {
        ExplicitFormTextField(
            title: title,
            prompt: prompt,
            text: $text,
            axis: .vertical,
            minimumLines: 1,
            maximumLines: 2,
            labelStyle: .stacked
        )
        .textInputAutocapitalization(.sentences)
    }
}

struct PlaceSnapshot {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let officialURL: String

    init(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        officialURL: String = ""
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.officialURL = officialURL
    }
}

@MainActor
func resolvePlaceMaster(
    for snapshot: PlaceSnapshot,
    publicSelection: PublicPlaceSelectionDraft? = nil,
    from placeMasters: [PlaceMaster],
    in modelContext: ModelContext
) -> PlaceMaster? {
    if let publicSelection {
        let place = PublicPlaceCatalogImporter.resolveSelection(
            publicSelection,
            existingPlaces: placeMasters,
            in: modelContext
        )
        let officialURL = snapshot.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !officialURL.isEmpty {
            place.officialURL = officialURL
            place.updatedAt = Date()
        }
        return place
    }
    let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }

    let address = snapshot.address.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefecture = JapanPrefecture.extract(from: address)
    guard !prefecture.isEmpty else { return nil }
    let normalizedName = normalizedPlaceText(name)
    let normalizedAddress = normalizedPlaceText(address)
    let officialURL = snapshot.officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if !officialURL.isEmpty { matchedPlace.officialURL = officialURL }
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
        officialURL: officialURL,
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

private func isStagedOutingTemplate(_ templateKey: String) -> Bool {
    ["museum", "theme_park", "nature_living"].contains(templateKey)
}

/// 入力欄の初期展開はジャンルではなく、記録までの段階を主軸に決める。
/// - 初回登録: 基本記録
/// - 未定の対象: 基本記録 + 思い出
/// - 日付確定済みの予定・保存済み記録: 思い出 + 備考
private func initialExpandedRecordUnitIDs(
    templateKey: String,
    stage: RecordFormOpeningStage
) -> Set<String> {
    let main: Set<String>
    let memories: Set<String>
    let notes: Set<String>

    switch templateKey {
    case "theater":
        main = ["basic", "ticketPlan"]
        memories = ["theaterRating", "photos", "memo"]
        notes = ["money", "importOCR", "officialInfo", "advanced"]
    case "live":
        main = ["basic", "ticketPlan"]
        memories = ["liveRating", "liveSetlist", "people", "photos", "memo"]
        notes = ["officialInfo", "money", "importOCR", "advanced"]
    case "movie":
        main = ["screenWorkCore", "screenWorkViewing"]
        memories = ["screenWorkRating", "photos", "people", "memo"]
        notes = ["officialInfo", "importOCR", "advanced"]
    case "book":
        main = ["bookInfo", "bookReading"]
        memories = ["bookRating", "photos", "memo"]
        notes = ["advanced"]
    case "goshuin":
        main = ["basic", "goshuinBook"]
        memories = ["photos", "people", "memo"]
        notes = ["importOCR", "advanced"]
    case "sake":
        main = ["basic"]
        memories = ["outingRating", "photos", "memo"]
        notes = ["money", "officialInfo", "importOCR", "advanced"]
    case "random_goods":
        main = ["basic"]
        memories = ["photos", "memo"]
        notes = ["money", "importOCR", "advanced"]
    case "museum", "theme_park", "nature_living":
        main = ["basic"]
        memories = ["outingRating", "moments", "photos", "people", "memo"]
        notes = ["money", "officialInfo", "importOCR", "advanced"]
    default:
        main = ["basic"]
        memories = ["people", "photos", "memo"]
        notes = ["money", "officialInfo", "importOCR", "advanced"]
    }

    let expansion = RecordLifecycleBlockExpansion.resolved(for: stage)
    var result: Set<String> = []
    if expansion.primary { result.formUnion(main) }
    if expansion.memories { result.formUnion(memories) }
    if expansion.notes { result.formUnion(notes) }
    return result
}

private let screenWorkRecordUnitDefinitions: [RecordUnitDefinition] = [
    RecordUnitDefinition(
        id: "screenWorkCore",
        name: "作品・鑑賞",
        description: "タイトル・区分・鑑賞日時／年・季節・評価",
        isRequired: true
    ),
    RecordUnitDefinition(
        id: "screenWorkViewing",
        name: "作品時間・鑑賞方法",
        description: "作品時間、鑑賞方法、場所、座席",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "screenWorkRating",
        name: "評価",
        description: "鑑賞後の評価",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "people",
        name: "監督・出演者",
        description: "監督、主演、主な出演者",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "photos",
        name: "写真",
        description: "思い出とノベルティ・特典を写真で整理",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "memo",
        name: "感想・メモ",
        description: "感想、印象、あとで見返したいこと",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "officialInfo",
        name: "公式情報",
        description: "公式URL・SNS・参考リンク",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "importOCR",
        name: "画像・OCR取込",
        description: "半券、チケット、案内画像の読み取り",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "advanced",
        name: "制作・作品の追加情報",
        description: "脚本、原作、音楽など必要な項目だけ",
        isRequired: false
    ),
]

private let screenWorkPeopleRoleOptions: [PersonRoleOption] = [
    PersonRoleOption.option(for: "director"),
    PersonRoleOption.option(for: "lead"),
    PersonRoleOption.option(for: "cast"),
]

private enum TheaterRecordBlock: String, CaseIterable, Identifiable {
    case viewing
    case memories
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewing: "鑑賞記録"
        case .memories: "思い出"
        case .notes: "備考記録"
        }
    }

    var description: String {
        switch self {
        case .viewing: "アイキャッチ・参加日・天気・会場・鑑賞方法・座席"
        case .memories: "評価・注目した人・思い出・資料写真・同行者・感想"
        case .notes: "公式・参考情報・費用・OCR・自由項目"
        }
    }

    var isInitiallyExpanded: Bool { self != .notes }

    private var unitIDs: [String] {
        switch self {
        case .viewing:
            ["basic", "ticketPlan"]
        case .memories:
            ["theaterRating", "photos", "memo"]
        case .notes:
            ["officialInfo", "money", "importOCR", "advanced"]
        }
    }

    func units(from definitions: [RecordUnitDefinition]) -> [RecordUnitDefinition] {
        unitIDs.compactMap { id in
            definitions.first(where: { $0.id == id })
        }
    }
}

@ViewBuilder
private func stagedTheaterForm<Content: View>(
    definitions: [RecordUnitDefinition],
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    ForEach(TheaterRecordBlock.allCases) { block in
        StagedRecordBlock(
            title: block.title,
            description: block.description,
            units: block.units(from: definitions),
            isInitiallyExpanded: block.isInitiallyExpanded,
            status: status,
            isExpanded: isExpanded,
            content: content
        )
    }
}

private enum ScreenWorkRecordBlock: String, CaseIterable, Identifiable {
    case viewing
    case memories
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewing: "鑑賞記録"
        case .memories: "思い出"
        case .notes: "備考記録"
        }
    }

    var description: String {
        switch self {
        case .viewing: "アイキャッチ・鑑賞日・シリーズ・鑑賞方法・鑑賞場所"
        case .memories: "評価・写真・同行者・感想"
        case .notes: "出演者・公式情報・OCR・制作情報・自由項目"
        }
    }

    var isInitiallyExpanded: Bool { self != .notes }

    private var unitIDs: [String] {
        switch self {
        case .viewing:
            ["screenWorkCore", "screenWorkViewing"]
        case .memories:
            ["screenWorkRating", "photos", "people", "memo"]
        case .notes:
            ["officialInfo", "importOCR", "advanced"]
        }
    }

    var units: [RecordUnitDefinition] {
        unitIDs.compactMap { id in
            screenWorkRecordUnitDefinitions.first(where: { $0.id == id })
        }
    }
}

@ViewBuilder
private func stagedScreenWorkForm<Content: View>(
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    ForEach(ScreenWorkRecordBlock.allCases) { block in
        StagedRecordBlock(
            title: block.title,
            description: block.description,
            units: block.units,
            isInitiallyExpanded: block.isInitiallyExpanded,
            status: status,
            isExpanded: isExpanded,
            content: content
        )
    }
}

private enum LiveRecordBlock: String, CaseIterable, Identifiable {
    case attendance
    case memories
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attendance: "参戦記録"
        case .memories: "思い出"
        case .notes: "備考記録"
        }
    }

    var description: String {
        switch self {
        case .attendance: "アイキャッチ・参戦日・会場・チケット・座席"
        case .memories: "評価・セットリスト・写真・同行者・感想"
        case .notes: "公式情報・費用・OCR・自由項目"
        }
    }

    var isInitiallyExpanded: Bool { self != .notes }

    private var unitIDs: [String] {
        switch self {
        case .attendance:
            ["basic", "ticketPlan"]
        case .memories:
            ["liveRating", "liveSetlist", "people", "photos", "memo"]
        case .notes:
            ["officialInfo", "money", "importOCR", "advanced"]
        }
    }

    func units(from definitions: [RecordUnitDefinition]) -> [RecordUnitDefinition] {
        unitIDs.compactMap { id in
            if let definition = definitions.first(where: { $0.id == id }) {
                return liveRecordUnitDefinition(definition)
            }
            switch id {
            case "liveRating":
                return RecordUnitDefinition(id: id, name: "評価", description: "この回の満足度", isRequired: false)
            case "liveSetlist":
                return RecordUnitDefinition(id: id, name: "セットリスト", description: "曲・MC・アンコールを順番に記録", isRequired: false)
            case "advanced":
                return RecordUnitDefinition(id: id, name: "その他の詳細", description: "必要な項目だけ自由に追加", isRequired: false)
            default:
                return nil
            }
        }
    }
}

@ViewBuilder
private func stagedLiveForm<Content: View>(
    definitions: [RecordUnitDefinition],
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    ForEach(LiveRecordBlock.allCases) { block in
        StagedRecordBlock(
            title: block.title,
            description: block.description,
            units: block.units(from: definitions),
            isInitiallyExpanded: block.isInitiallyExpanded,
            status: status,
            isExpanded: isExpanded,
            content: content
        )
    }
}

private func liveRecordUnitDefinition(_ definition: RecordUnitDefinition) -> RecordUnitDefinition {
    switch definition.id {
    case "basic":
        RecordUnitDefinition(id: definition.id, name: "参戦日時・会場", description: "参戦日・開場・開演・終了・会場", isRequired: true)
    case "ticketPlan":
        RecordUnitDefinition(id: definition.id, name: "チケット・座席", description: "取得状況と座席", isRequired: false)
    case "people":
        RecordUnitDefinition(id: definition.id, name: "同行者", description: "一緒に参加した人", isRequired: false)
    case "photos":
        RecordUnitDefinition(id: definition.id, name: "写真・アイキャッチ", description: "この回の写真", isRequired: false)
    case "memo":
        RecordUnitDefinition(id: definition.id, name: "感想・タグ", description: "感想・感情タグ・その他のタグ", isRequired: false)
    case "money":
        RecordUnitDefinition(id: definition.id, name: "費用", description: "チケット・グッズ・遠征費など", isRequired: false)
    case "importOCR":
        RecordUnitDefinition(id: definition.id, name: "画像・OCR取込", description: "チケットやセトリ画像の原文", isRequired: false)
    case "officialInfo":
        RecordUnitDefinition(id: definition.id, name: "公式・参考情報", description: "公式URL・SNS・参考リンク", isRequired: false)
    default:
        definition
    }
}

private enum OutingRecordBlock: String, CaseIterable, Identifiable, Equatable {
    case experience
    case memories
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .experience: "体験記録"
        case .memories: "思い出"
        case .notes: "備考記録"
        }
    }

    var description: String {
        switch self {
        case .experience: "アイキャッチ・体験日・施設・施設種別"
        case .memories: "評価・体験したこと・写真・同行者・感想"
        case .notes: "費用・公式情報・OCR・補足情報"
        }
    }

    var isInitiallyExpanded: Bool { self != .notes }

    private var unitIDs: [String] {
        switch self {
        case .experience:
            ["basic"]
        case .memories:
            ["outingRating", "moments", "photos", "people", "memo"]
        case .notes:
            ["money", "officialInfo", "importOCR", "advanced"]
        }
    }

    func units(
        from definitions: [RecordUnitDefinition],
        templateKey: String
    ) -> [RecordUnitDefinition] {
        unitIDs.compactMap { id in
            if id == "outingRating" {
                return RecordUnitDefinition(
                    id: id,
                    name: "評価",
                    description: "この体験の満足度",
                    isRequired: false
                )
            }
            if id == "moments", ["theme_park", "nature_living"].contains(templateKey) {
                return RecordUnitDefinition(
                    id: id,
                    name: templateKey == "theme_park" ? "体験したイベント" : "見たもの・体験",
                    description: "箇条書きで追加し、この回の写真と任意で紐づけ",
                    isRequired: false
                )
            }
            if id == "people" {
                return definitions
                    .first(where: { $0.id == id })
                    .map { outingRecordUnitDefinition($0, templateKey: templateKey) }
                    ?? RecordUnitDefinition(
                        id: id,
                        name: "同行者",
                        description: "一緒に体験した人",
                        isRequired: false
                    )
            }
            return definitions
                .first(where: { $0.id == id })
                .map { outingRecordUnitDefinition($0, templateKey: templateKey) }
        }
    }
}

@ViewBuilder
private func stagedOutingForm<Content: View>(
    category: RecordCategory,
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    let definitions = activeUnitDefinitions(for: category)
    ForEach(OutingRecordBlock.allCases) { block in
        let units = block.units(from: definitions, templateKey: category.templateKey)
        if !units.isEmpty {
            StagedRecordBlock(
                title: outingBlockTitle(block, templateKey: category.templateKey),
                description: outingBlockDescription(block, templateKey: category.templateKey),
                units: units,
                isInitiallyExpanded: block.isInitiallyExpanded,
                status: status,
                isExpanded: isExpanded,
                content: content
            )
        }
    }
}

private func outingBlockTitle(_ block: OutingRecordBlock, templateKey: String) -> String {
    guard block == .experience else { return block.title }
    switch templateKey {
    case "museum": return "鑑賞記録"
    case "theme_park": return "来園記録"
    default: return "体験記録"
    }
}

private func outingBlockDescription(_ block: OutingRecordBlock, templateKey: String) -> String {
    guard block == .experience else { return block.description }
    switch templateKey {
    case "museum": return "アイキャッチ・鑑賞日・施設・展示名"
    case "theme_park": return "アイキャッチ・来園日・施設"
    default: return "アイキャッチ・訪問日・施設・施設種別"
    }
}

private func outingRecordUnitDefinition(
    _ definition: RecordUnitDefinition,
    templateKey: String
) -> RecordUnitDefinition {
    let isThemePark = templateKey == "theme_park"
    switch definition.id {
    case "basic":
        return RecordUnitDefinition(
            id: definition.id,
            name: isThemePark ? "来園の記録" : "体験の記録",
            description: isThemePark
                ? "施設・種別・来園日・評価・イベント名"
                : "施設・種別・訪問日・評価・今回の見どころ",
            isRequired: true
        )
    case "photos":
        return RecordUnitDefinition(
            id: definition.id,
            name: "写真",
            description: "分類とキャプションで思い出を整理",
            isRequired: false
        )
    case "memo":
        return RecordUnitDefinition(
            id: definition.id,
            name: "感想・メモ",
            description: "印象、混雑、また行きたいことなど",
            isRequired: false
        )
    case "money":
        return RecordUnitDefinition(
            id: definition.id,
            name: "費用",
            description: "入園料、食事、グッズ、交通費など",
            isRequired: false
        )
    case "ticketPlan":
        return RecordUnitDefinition(
            id: definition.id,
            name: "チケット",
            description: "取得状況やチケット情報",
            isRequired: false
        )
    case "importOCR":
        return RecordUnitDefinition(
            id: definition.id,
            name: "画像・OCR取込",
            description: "チケットやレシートの文字を読み取る",
            isRequired: false
        )
    case "officialInfo":
        return RecordUnitDefinition(
            id: definition.id,
            name: "補足・公式情報",
            description: "施設DBにないURLや補足情報",
            isRequired: false
        )
    default:
        return definition
    }
}

private enum GenericRecordBlock: String, CaseIterable, Identifiable {
    case primary
    case memories
    case notes

    var id: String { rawValue }

    func title(templateKey: String) -> String {
        switch (self, templateKey) {
        case (.primary, "goshuin"): "参拝記録"
        case (.primary, "sake"): "飲酒記録"
        case (.primary, "random_goods"): "収集記録"
        case (.primary, _): "体験記録"
        case (.memories, "sake"): "感想"
        case (.memories, _): "思い出"
        case (.notes, "sake"): "お酒情報"
        case (.notes, _): "備考記録"
        }
    }

    func description(templateKey: String) -> String {
        switch (self, templateKey) {
        case (.primary, "goshuin"): "アイキャッチ・参拝日・寺社・御朱印帳・御朱印の種類"
        case (.primary, "sake"): "飲んだ日・銘柄・飲んだ場所"
        case (.primary, "random_goods"): "アイキャッチ・入手日・シリーズ・対象・金額"
        case (.primary, _): "アイキャッチ・日時・場所"
        case (.memories, "goshuin"): "写真・同行者・感想"
        case (.memories, "sake"): "評価・写真・感想"
        case (.memories, "random_goods"): "画像・メモ"
        case (.memories, _): "評価・写真・同行者・感想"
        case (.notes, "goshuin"): "OCR・補足情報・以前の参拝記録"
        case (.notes, "sake"): "蔵元・度数・ヴィンテージ・購入情報・価格"
        case (.notes, "random_goods"): "入手・手放し履歴・OCR・タグ・補足情報"
        case (.notes, _): "費用・公式情報・OCR・補足情報"
        }
    }

    func unitIDs(templateKey: String) -> [String] {
        switch self {
        case .primary:
            switch templateKey {
            case "goshuin": return ["basic", "goshuinBook"]
            case "random_goods": return ["basic", "money"]
            default: return ["basic"]
            }
        case .memories:
            switch templateKey {
            case "sake": return ["outingRating", "photos", "memo"]
            case "random_goods": return ["photos", "memo"]
            default: return ["photos", "people", "memo"]
            }
        case .notes:
            switch templateKey {
            case "goshuin": return ["importOCR", "advanced"]
            case "random_goods": return ["importOCR", "advanced"]
            default: return ["money", "officialInfo", "importOCR", "advanced"]
            }
        }
    }
}

@ViewBuilder
private func stagedGenericRecordForm<Content: View>(
    category: RecordCategory?,
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    let templateKey = category?.templateKey ?? ""
    let definitions = activeUnitDefinitions(for: category)
    ForEach(GenericRecordBlock.allCases) { block in
        let units = block.unitIDs(templateKey: templateKey).compactMap { id in
            if id == "outingRating" {
                return RecordUnitDefinition(
                    id: id,
                    name: "評価",
                    description: "この記録の評価",
                    isRequired: false
                )
            }
            return definitions.first(where: { $0.id == id })
                ?? RecordUnitDefinition.all.first(where: { $0.id == id })
        }
        if !units.isEmpty {
            StagedRecordBlock(
                title: block.title(templateKey: templateKey),
                description: block.description(templateKey: templateKey),
                units: units,
                status: status,
                isExpanded: isExpanded,
                content: content
            )
        }
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
                description: "チケット取得状況・座席・注目した人",
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
        description: "書名・シリーズ・著者・出版社・ISBN・ページ数",
        isRequired: true
    ),
    RecordUnitDefinition(
        id: "bookReading",
        name: "読書の記録",
        description: "読書状態・媒体・読み始め・読了日",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "bookRating",
        name: "評価",
        description: "この本の評価",
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
        name: "感想・引用・ページメモ",
        description: "感想、引用したい言葉、読み返したいページ",
        isRequired: false
    ),
    RecordUnitDefinition(
        id: "advanced",
        name: "入手情報・補足情報",
        description: "入手先など必要な項目だけ追加",
        isRequired: false
    ),
]

private enum BookRecordBlock: String, CaseIterable, Identifiable {
    case reading
    case reflection
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: "読書記録"
        case .reflection: "読後感"
        case .notes: "備考記録"
        }
    }

    var description: String {
        switch self {
        case .reading: "アイキャッチ・読書状態・媒体・読書期間・書誌情報"
        case .reflection: "評価・写真・感想・引用・ページメモ"
        case .notes: "入手情報・補足情報"
        }
    }

    var isInitiallyExpanded: Bool { self != .notes }

    private var unitIDs: [String] {
        switch self {
        case .reading: ["bookInfo", "bookReading"]
        case .reflection: ["bookRating", "photos", "memo"]
        case .notes: ["advanced"]
        }
    }

    var units: [RecordUnitDefinition] {
        unitIDs.compactMap { id in
            bookRecordUnitDefinitions.first(where: { $0.id == id })
        }
    }
}

@ViewBuilder
private func stagedBookRecordForm<Content: View>(
    status: @escaping (String) -> RecordUnitStatus,
    isExpanded: @escaping (String) -> Binding<Bool>,
    @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
) -> some View {
    ForEach(BookRecordBlock.allCases) { block in
        StagedRecordBlock(
            title: block.title,
            description: block.description,
            units: block.units,
            isInitiallyExpanded: block.isInitiallyExpanded,
            status: status,
            isExpanded: isExpanded,
            content: content
        )
    }
}

private func theaterRecordUnitDefinition(
    _ definition: RecordUnitDefinition
) -> RecordUnitDefinition {
    switch definition.id {
    case "basic":
        return RecordUnitDefinition(
            id: definition.id,
            name: "参加日・会場・アイキャッチ",
            description: "鑑賞日・開演・終演・鑑賞方法・会場・代表画像",
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
            description: "チケット取得状況・座席・注目した人",
            isRequired: definition.isRequired
        )
    case "photos":
        return RecordUnitDefinition(
            id: definition.id,
            name: "思い出・資料写真",
            description: "追加写真の分類・キャプション・金額",
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

private struct MomentPhotoChoice: Identifiable {
    let id: UUID
    let title: String
    let data: Data
}

private struct MomentPhotoSelection: Identifiable {
    let id: UUID
}

private struct VisitMomentEntriesEditor: View {
    @Binding var entries: [VisitMomentEntry]
    let availablePhotos: [MomentPhotoChoice]
    let itemName: String
    @State private var photoSelection: MomentPhotoSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if entries.isEmpty {
                Text("\(itemName)を箇条書きで残せます。写真は追加後に任意で紐づけられます。")
                    .font(FavorecoTypography.jpSans(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)")
                            .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("\(itemName)名", text: $entries[index].title)
                            .font(FavorecoTypography.jpSans(14, weight: .medium, relativeTo: .body))
                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("ひとことメモ（任意）", text: $entries[index].note, axis: .vertical)
                        .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                        .lineLimit(1...3)

                    Button {
                        photoSelection = MomentPhotoSelection(id: entry.id)
                    } label: {
                        Label(
                            entry.linkedPhotoIDs.isEmpty
                                ? "写真を紐づける"
                                : "写真 \(entry.linkedPhotoIDs.count)枚",
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .font(FavorecoTypography.jpSans(12, weight: .medium, relativeTo: .caption))
                    }
                    .buttonStyle(.bordered)
                    .disabled(availablePhotos.isEmpty)
                }
                .padding(.vertical, 4)

                if index < entries.count - 1 { Divider() }
            }

            Button {
                entries.append(VisitMomentEntry())
            } label: {
                Label("\(itemName)を追加", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if availablePhotos.isEmpty {
                Text("写真との紐づけは、先に「写真」へ追加すると選べます。")
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $photoSelection) { selection in
            NavigationStack {
                List(availablePhotos) { photo in
                    Button {
                        toggle(photo.id, for: selection.id)
                    } label: {
                        HStack(spacing: 12) {
                            thumbnail(for: photo)
                            Text(photo.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if linkedPhotoIDs(for: selection.id).contains(photo.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .overlay {
                    if availablePhotos.isEmpty {
                        ContentUnavailableView("写真がありません", systemImage: "photo")
                    }
                }
                .navigationTitle("写真を紐づけ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") { photoSelection = nil }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for photo: MomentPhotoChoice) -> some View {
        if let image = UIImage(data: photo.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "photo")
                .frame(width: 52, height: 52)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func linkedPhotoIDs(for entryID: UUID) -> [UUID] {
        entries.first(where: { $0.id == entryID })?.linkedPhotoIDs ?? []
    }

    private func toggle(_ photoID: UUID, for entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if let linkedIndex = entries[index].linkedPhotoIDs.firstIndex(of: photoID) {
            entries[index].linkedPhotoIDs.remove(at: linkedIndex)
        } else {
            entries[index].linkedPhotoIDs.append(photoID)
        }
    }
}

private func matchingPriorVisits(
    in visits: [Visit],
    placeMasterID: UUID?,
    venueName: String
) -> [Visit] {
    let normalizedVenue = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard placeMasterID != nil || !normalizedVenue.isEmpty else { return [] }
    return visits.filter { visit in
        guard visit.event?.isArchived != true,
              visit.event?.category?.templateKey == "goshuin" else { return false }
        if let placeMasterID, visit.placeMaster?.id == placeMasterID {
            return true
        }
        return !normalizedVenue.isEmpty
            && visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedVenue) == .orderedSame
    }
}

private struct GoshuinPriorVisitHistory: View {
    let visits: [Visit]

    var body: some View {
        Section("以前の参拝記録") {
            if visits.isEmpty {
                Text("この寺社の参拝記録はまだありません")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visits.prefix(5)) { visit in
                    HStack(spacing: 10) {
                        FavorecoIcon(systemName: "calendar", size: 15)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.visitedAt.formatted(date: .long, time: .omitted))
                                .font(FavorecoTypography.bodyStrong)
                            if let title = visit.event?.title, !title.isEmpty {
                                Text(title)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                if visits.count > 5 {
                    Text("ほか\(visits.count - 5)件")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

private struct QuickRecordSaveBar: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let date: Date
    let isEnabled: Bool
    let isSaving: Bool
    let isLive: Bool
    let requiresTitle: Bool
    let onSave: () -> Void

    private var recordName: String {
        isLive ? "参戦記録" : "観劇記録"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(FavorecoDateText.compactDateWithHalfWidthWeekday(date))でまず残す")
                        .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(
                        requiresTitle
                            ? "タイトルを入力すると保存できます"
                            : "写真・人物・評価・費用はあとから追加できます"
                    )
                    .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }

                Spacer(minLength: 4)

                Button(action: onSave) {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isSaving ? "保存中" : "\(recordName)を保存")
                            .font(FavorecoTypography.jpSans(12, weight: .bold, relativeTo: .body))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(themePalette.globalTint)
                .disabled(!isEnabled || isSaving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themePalette.globalTint.opacity(0.16))
                .frame(height: 0.7)
        }
        .accessibilityElement(children: .contain)
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
