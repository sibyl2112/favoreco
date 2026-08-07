import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TheaterPerformanceRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]

    let category: RecordCategory

    @State private var title = ""
    @State private var seriesName = ""
    @State private var eventSubtitle = ""
    @State private var performanceTypeKey = ""
    @State private var performanceTypeCustomName = ""
    @State private var importURL = ""
    @State private var officialURL = ""
    @State private var xURL = ""
    @State private var instagramURL = ""
    @State private var threadsURL = ""
    @State private var creditsText = ""
    @State private var performanceMemo = ""
    @State private var eyecatchData: Data?
    @State private var venueEntries: [EventVenueEntry] = [EventVenueEntry()]
    @State private var selectedImportItems: [PhotosPickerItem] = []
    @State private var selectedLocalEyecatchItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var isFetchingURL = false
    @State private var isSaving = false
    @State private var importStatus = ""
    @State private var recognizedTitleCandidates: [String] = []
    @State private var recognizedOCRText = ""
    @State private var errorMessage = ""
    @State private var nextEvent: ExperienceEvent?
    @State private var nextEntryMode: AddTicketPlanView.EntryMode = .plan
    @State private var shouldDismissAfterNextStep = false
    @State private var showingPerformanceBasic = true
    @State private var showingOptionalBasicFields = false
    @State private var showingVenueSchedule = false
    @State private var showingPerformanceDetails = false
    @State private var showingImportDetails = false
    @State private var showingNextActions = false
    @State private var showingEyecatchRemovalConfirmation = false
    @State private var savedEventForNextAction: ExperienceEvent?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DisclosureGroup(isExpanded: $showingImportDetails) {
                        ExplicitFormControlRow(title: "公式ページURL", isOptional: true) {
                            HStack(spacing: 8) {
                                FavorecoIcon(systemName: "link", size: 16)
                                    .foregroundStyle(categoryTint)
                                TextField("URLを入力", text: $importURL)
                                    .font(
                                        FavorecoTypography.jpSans(
                                            ExplicitFormMetrics.inputFontSize,
                                            weight: .regular,
                                            relativeTo: .body
                                        )
                                    )
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                Button(isFetchingURL ? "取得中" : "取得") {
                                    Task { await fetchURLMetadata() }
                                }
                                .font(FavorecoTypography.captionStrong)
                                .buttonStyle(.bordered)
                                .disabled(
                                    importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        || isFetchingURL
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Divider()
                            .overlay(ExplicitFormMetrics.rowSeparatorColor)

                        PhotosPicker(
                            selection: $selectedImportItems,
                            maxSelectionCount: 2,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                FavorecoIcon(systemName: "photo.badge.plus", size: 16)
                                    .foregroundStyle(categoryTint)
                                Text(eyecatchData == nil
                                     ? "画像を追加（最大2枚）"
                                     : "画像・OCRを変更（最大2枚）")
                                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 32)
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessingImage)
                        .onChange(of: selectedImportItems) { _, items in
                            guard !items.isEmpty else { return }
                            Task { await loadImportedImages(from: items) }
                        }

                        if !importStatus.isEmpty {
                            Text(importStatus)
                                .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                        }

                        if !recognizedTitleCandidates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("読み取った公演名候補")
                                    .font(FavorecoTypography.captionStrong)
                                ForEach(recognizedTitleCandidates.prefix(4), id: \.self) { candidate in
                                    Button {
                                        title = candidate
                                        recognizedTitleCandidates = []
                                        importStatus = "公演名へ反映しました。"
                                    } label: {
                                        HStack {
                                            Text(candidate)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                            Spacer(minLength: 8)
                                            Image(systemName: "arrow.up.left")
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            FavorecoIcon(systemName: "wand.and.stars", size: 17)
                                .foregroundStyle(categoryTint)
                            Text("URL・画像・OCRから取得")
                                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 8)
                            Text("任意")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TheaterUnifiedFormIntroduction(entry: .performanceRegistration)
                }

                Section {
                    DisclosureGroup(isExpanded: $showingPerformanceBasic) {
                        ExplicitFormTextField(
                            title: "公演名",
                            prompt: "月影のアトリエ（必須）",
                            text: $title,
                            axis: .horizontal,
                            minimumLines: 1,
                            maximumLines: 1,
                            labelStyle: .horizontal
                        )
                        TheaterPerformanceTypePicker(
                            selection: $performanceTypeKey,
                            customName: $performanceTypeCustomName,
                            usesCompactLabelStyle: true
                        )
                        ExplicitFormTextField(
                            title: "公式URL",
                            prompt: "https://example.com（任意）",
                            text: $officialURL,
                            labelStyle: .horizontal
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                        DisclosureGroup(isExpanded: $showingOptionalBasicFields) {
                            ExplicitFormTextField(
                                title: "シリーズ（任意）",
                                prompt: "登録済みのシリーズ名から候補表示",
                                text: $seriesName,
                                labelStyle: .horizontal
                            )
                            ExplicitFormTextField(
                                title: "サブタイトル（任意）",
                                prompt: "例：東京公演限定版",
                                text: $eventSubtitle,
                                labelStyle: .horizontal
                            )
                        } label: {
                            Label(
                                showingOptionalBasicFields
                                    ? "追加項目を閉じる"
                                    : "サブタイトル・シリーズを追加",
                                systemImage: showingOptionalBasicFields ? "minus.circle" : "plus.circle"
                            )
                            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ExplicitFormFieldTitle(
                                title: "公演ビジュアル",
                                isOptional: true,
                                isRequired: false
                            )

                            if let eyecatchData, let image = UIImage(data: eyecatchData) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 150)
                                        .background(.secondary.opacity(0.08))

                                    Button(role: .destructive) {
                                        showingEyecatchRemovalConfirmation = true
                                    } label: {
                                        FavorecoIcon(systemName: "trash", size: 13, fallbackWeight: .semibold)
                                            .foregroundStyle(.red)
                                            .frame(width: 30, height: 30)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .overlay {
                                                Circle()
                                                    .stroke(Color.secondary.opacity(0.22), lineWidth: 0.8)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(7)
                                    .accessibilityLabel("公演ビジュアルを外す")
                                }

                                PhotosPicker(
                                    selection: $selectedLocalEyecatchItem,
                                    matching: .images
                                ) {
                                    localEyecatchPickerLabel("ローカル画像を変更")
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessingImage)
                            } else {
                                PhotosPicker(
                                    selection: $selectedLocalEyecatchItem,
                                    matching: .images
                                ) {
                                    VStack(spacing: 8) {
                                        FavorecoIcon(
                                            systemName: "photo.badge.plus",
                                            size: 24,
                                            fallbackWeight: .medium
                                        )
                                        Text("ローカルから画像を選ぶ")
                                            .font(
                                                FavorecoTypography.jpSans(
                                                    13,
                                                    weight: .semibold,
                                                    relativeTo: .body
                                                )
                                            )
                                    }
                                    .foregroundStyle(categoryTint)
                                    .frame(maxWidth: .infinity, minHeight: 96)
                                    .background(Color.secondary.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(
                                                Color.secondary.opacity(0.28),
                                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                                            )
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessingImage)
                            }
                        }
                        .padding(.vertical, 8)
                        .onChange(of: selectedLocalEyecatchItem) { _, item in
                            guard let item else { return }
                            Task { await loadLocalEyecatch(from: item) }
                        }
                    } label: {
                        TheaterUnifiedSectionLabel(section: .performanceBasic)
                    }
                } footer: {
                    if showingPerformanceBasic {
                        Text("タイトルは必須です。ほかの項目は必要になった時に追加できます。")
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showingVenueSchedule) {
                    ForEach($venueEntries) { $entry in
                        TheaterScheduleEntryEditor(
                            entry: $entry,
                            fallbackStart: Date(),
                            fallbackEnd: Date()
                        )
                    }
                    .onDelete { offsets in
                        venueEntries.remove(atOffsets: offsets)
                        if venueEntries.isEmpty {
                            venueEntries.append(EventVenueEntry())
                        }
                    }

                    Button {
                        venueEntries.append(EventVenueEntry())
                    } label: {
                        FavorecoIconLabel("公演地を追加", systemImage: "plus.circle.fill")
                    }
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                    } label: {
                        TheaterUnifiedSectionLabel(section: .venueSchedule)
                    }
                } header: {
                    EmptyView()
                }

                Section {
                    DisclosureGroup(isExpanded: $showingPerformanceDetails) {
                        TheaterSocialLinksEditor(
                            xURL: $xURL,
                            instagramURL: $instagramURL,
                            threadsURL: $threadsURL
                        )
                        ExplicitFormTextField(
                            title: "主催・出演（任意）",
                            prompt: "主催／制作団体、キャスト・スタッフ",
                            text: $creditsText,
                            axis: .vertical,
                            minimumLines: 1,
                            maximumLines: 4,
                            labelStyle: .horizontal
                        )
                        ExplicitFormTextField(
                            title: "メモ（任意）",
                            prompt: "あらすじなど必要な情報",
                            text: $performanceMemo,
                            axis: .vertical,
                            minimumLines: 5,
                            maximumLines: 5,
                            labelStyle: .horizontal,
                            reservesLineSpace: true
                        )
                    } label: {
                        TheaterUnifiedSectionLabel(section: .performanceDetails)
                    }
                }

                Section {
                    if showingNextActions {
                        postSaveActionsCard
                            .clearRegistrationCardRow()
                    } else {
                        registrationButton(
                            title: "公演を保存",
                            detail: "保存後に、観劇予定またはチケット手配へ進めます",
                            systemImage: "checkmark.circle.fill",
                            tint: categoryTint
                        ) {
                            save(nextStep: .interest)
                        }
                        .clearRegistrationCardRow()
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 48)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
            .navigationTitle("公演を登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .disabled(isSaving)
            .sheet(item: $nextEvent, onDismiss: {
                if shouldDismissAfterNextStep {
                    dismiss()
                }
            }) { event in
                AddTicketPlanView(event: event, entryMode: nextEntryMode)
            }
            .confirmationDialog(
                "公演ビジュアルを外しますか？",
                isPresented: $showingEyecatchRemovalConfirmation,
                titleVisibility: .visible
            ) {
                Button("画像を外す", role: .destructive) {
                    eyecatchData = nil
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("公演登録を保存するまでは、選び直すこともできます。")
            }
            .alert("公演を登録できませんでした", isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var postSaveActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FavorecoIcon(systemName: "checkmark.circle.fill", size: 18, fallbackWeight: .semibold)
                    .foregroundStyle(categoryTint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("公演を保存しました")
                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("続けて登録する内容を選べます")
                        .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button("完了") {
                    dismiss()
                }
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(categoryTint)
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                postSaveActionButton(
                    title: "観劇予定を追加",
                    systemImage: "calendar.badge.plus"
                ) {
                    openSavedEventNextStep(.plan)
                }

                postSaveActionButton(
                    title: "チケットを手配",
                    systemImage: "ticket"
                ) {
                    openSavedEventNextStep(.ticketSchedule)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(categoryTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(categoryTint.opacity(0.48), lineWidth: 1.1)
        }
    }

    private func postSaveActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                FavorecoIcon(systemName: systemImage, size: 13, fallbackWeight: .semibold)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(FavorecoTypography.jpSans(11.5, weight: .semibold, relativeTo: .body))
            .foregroundStyle(categoryTint)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(categoryTint.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(categoryTint.opacity(0.34), lineWidth: 0.8)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func openSavedEventNextStep(_ entryMode: AddTicketPlanView.EntryMode) {
        guard let savedEventForNextAction else { return }
        showingNextActions = false
        nextEntryMode = entryMode
        shouldDismissAfterNextStep = true
        nextEvent = savedEventForNextAction
    }

    private func registrationButton(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isEnabled = !trimmedTitle.isEmpty && !isSaving
        return Button(action: action) {
            registrationCardLabel(
                title: title,
                detail: detail,
                systemImage: systemImage,
                tint: tint,
                isEnabled: isEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var categoryTint: Color {
        themePalette.globalTint
    }

    private func registrationCardLabel(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: systemImage, size: 18, fallbackWeight: .semibold)
                .foregroundStyle(isEnabled ? tint : Color.secondary)
                .frame(width: 34, height: 34)
                .background(
                    (isEnabled ? tint.opacity(0.14) : Color.secondary.opacity(0.08)),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? tint : Color.secondary.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            (isEnabled ? tint.opacity(0.10) : Color(.secondarySystemGroupedBackground)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isEnabled ? tint.opacity(0.48) : Color.secondary.opacity(0.24),
                    lineWidth: isEnabled ? 1.1 : 0.8
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func localEyecatchPickerLabel(_ title: String) -> some View {
        HStack(spacing: 7) {
            FavorecoIcon(systemName: "photo.badge.plus", size: 15, fallbackWeight: .medium)
            Text(title)
                .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .body))
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(categoryTint)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(categoryTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func save(nextStep: TheaterPerformanceRegistrationNextStep) {
        guard !trimmedTitle.isEmpty else {
            errorMessage = "公演名を入力してください。"
            return
        }
        isSaving = true
        let now = Date()
        let existingEvent = ExperienceEvent.matchingProduction(
            title: trimmedTitle,
            categoryID: category.id,
            in: events
        )
        let event = existingEvent ?? ExperienceEvent(
            title: trimmedTitle,
            stateKey: "interested",
            createdAt: now,
            updatedAt: now,
            category: category
        )
        if existingEvent == nil {
            modelContext.insert(event)
        }

        var fields = VisitUnitFields(rawValue: event.unitFieldsRaw)
        event.title = trimmedTitle
        let trimmedSeriesName = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSeriesName.isEmpty {
            event.seriesName = trimmedSeriesName
        }
        if !performanceTypeKey.isEmpty {
            event.subTypeKey = performanceTypeKey
            fields.eventPerformanceTypeCustomName = TheaterPerformanceType.customNameForStorage(
                key: performanceTypeKey,
                input: performanceTypeCustomName
            )
        }
        let trimmedSubtitle = eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSubtitle.isEmpty {
            fields.eventSubtitle = trimmedSubtitle
        }
        let trimmedCredits = creditsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCredits.isEmpty {
            fields.eventCreditsText = trimmedCredits
        }
        let platformLinks = [xURL, instagramURL, threadsURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !platformLinks.isEmpty {
            fields.socialLinks = fields.socialLinks.filter {
                TheaterSocialPlatform.platform(for: $0) == nil
            } + platformLinks
        }
        if !recognizedOCRText.isEmpty {
            fields.ocrText = recognizedOCRText
        }
        if !trimmedOfficialURL.isEmpty {
            event.officialURL = trimmedOfficialURL
        }
        let trimmedMemo = performanceMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMemo.isEmpty {
            event.memo = trimmedMemo
        }
        if let eyecatchData {
            event.eyecatchData = eyecatchData
            ThumbnailLoader.purge()
        }
        let incomingVenues = normalizedVenueEntries
        if !incomingVenues.isEmpty {
            fields.eventVenues = mergedVenueEntries(
                existing: fields.eventVenues,
                incoming: incomingVenues
            )
        }
        event.unitFieldsRaw = fields.encodedRawValue
        event.updatedAt = now

        do {
            try modelContext.save()
            switch nextStep {
            case .interest:
                savedEventForNextAction = event
                showingNextActions = true
            case .datedPlan:
                nextEntryMode = .plan
                shouldDismissAfterNextStep = true
                nextEvent = event
            case .ticketSchedule:
                nextEntryMode = .ticketSchedule
                shouldDismissAfterNextStep = true
                nextEvent = event
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private var normalizedVenueEntries: [EventVenueEntry] {
        venueEntries.compactMap { entry in
            let normalized = EventVenueEntry(
                id: entry.id,
                name: entry.trimmedName,
                address: entry.trimmedAddress,
                performanceLabel: entry.trimmedPerformanceLabel.isEmpty
                    ? nil
                    : entry.trimmedPerformanceLabel,
                startsAt: entry.startsAt,
                endsAt: entry.startsAt.map { max(entry.endsAt ?? $0, $0) }
            )
            let hasAnyValue = !normalized.isEmpty
                || !normalized.trimmedPerformanceLabel.isEmpty
                || normalized.startsAt != nil
                || normalized.endsAt != nil
            return hasAnyValue ? normalized : nil
        }
    }

    private func mergedVenueEntries(
        existing: [EventVenueEntry],
        incoming: [EventVenueEntry]
    ) -> [EventVenueEntry] {
        var result = existing
        var keys = Set(existing.map(venueEntryKey))
        for entry in incoming where keys.insert(venueEntryKey(entry)).inserted {
            result.append(entry)
        }
        return result
    }

    private func venueEntryKey(_ entry: EventVenueEntry) -> String {
        let label = entry.trimmedPerformanceLabel.folding(
            options: [.caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ja_JP")
        )
        let name = entry.trimmedName.folding(
            options: [.caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ja_JP")
        )
        let start = entry.startsAt.map { Calendar.current.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
        let end = entry.endsAt.map { Calendar.current.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
        return "\(label)|\(name)|\(start)|\(end)"
    }

    @MainActor
    private func loadImportedImages(from items: [PhotosPickerItem]) async {
        isProcessingImage = true
        importStatus = "\(items.count)枚の画像を読み取り中です。"
        recognizedTitleCandidates = []
        defer {
            isProcessingImage = false
            selectedImportItems = []
        }
        var sourceDataItems: [Data] = []
        for item in items.prefix(2) {
            if let sourceData = try? await item.loadTransferable(type: Data.self) {
                sourceDataItems.append(sourceData)
            }
        }
        guard !sourceDataItems.isEmpty else {
            errorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        let results = await Task.detached(priority: .userInitiated, operation: {
            sourceDataItems.map { sourceData in
            let compressed = QuickCaptureImageService.compressedJPEG(from: sourceData)
            let analysis = QuickCaptureImageService.recognizedTextAnalysis(from: sourceData)
            return (compressed, analysis)
            }
        }).value
        guard let compressed = results.lazy.compactMap(\.0).first else {
            errorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed

        let analyses = results.map(\.1)
        recognizedOCRText = analyses
            .map(\.fullText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let venueName = analyses.lazy
            .compactMap { $0.venueCandidates.first }
            .first ?? ""
        let eventDateRange = analyses.lazy
            .compactMap(\.eventDateRange)
            .first
        let appliedVenue = applyImportedVenue(
            name: venueName,
            address: "",
            startsAt: eventDateRange?.startsAt,
            endsAt: eventDateRange?.endsAt
        )
        let reliableTitle = analyses.first {
            $0.isTitleSuggestionReliable && !$0.suggestedTitle.isEmpty
        }?.suggestedTitle
        let titleCandidates = analyses
            .flatMap(\.titleCandidates)
            .reduce(into: [String]()) { values, candidate in
                if !values.contains(candidate) {
                    values.append(candidate)
                }
            }
        if let reliableTitle,
           trimmedTitle.isEmpty {
            title = reliableTitle
            recognizedTitleCandidates = []
            importStatus = importResultMessage(
                source: "画像",
                fields: ["公演名", "公演ビジュアル"] + appliedVenue
            )
        } else if !titleCandidates.isEmpty {
            recognizedTitleCandidates = titleCandidates
            importStatus = importResultMessage(
                source: "画像",
                fields: ["公演ビジュアル", "公演名候補"] + appliedVenue
            )
        } else {
            importStatus = importResultMessage(
                source: "画像",
                fields: ["公演ビジュアル"] + appliedVenue
            )
        }
    }

    @MainActor
    private func loadLocalEyecatch(from item: PhotosPickerItem) async {
        isProcessingImage = true
        defer {
            isProcessingImage = false
            selectedLocalEyecatchItem = nil
        }
        guard let sourceData = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        let compressed = await Task.detached(priority: .userInitiated) {
            QuickCaptureImageService.compressedJPEG(from: sourceData)
        }.value
        guard let compressed else {
            errorMessage = "画像を読み込めませんでした。別の写真をお試しください。"
            return
        }
        eyecatchData = compressed
    }

    @discardableResult
    private func applyImportedVenue(
        name: String,
        address: String,
        startsAt: Date?,
        endsAt: Date?
    ) -> [String] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty || !trimmedAddress.isEmpty || startsAt != nil || endsAt != nil else {
            return []
        }

        let index = venueEntries.firstIndex(where: {
            $0.isEmpty && $0.startsAt == nil && $0.endsAt == nil
        }) ?? venueEntries.indices.first ?? 0
        if venueEntries.isEmpty {
            venueEntries.append(EventVenueEntry())
        }

        var applied: [String] = []
        if venueEntries[index].trimmedName.isEmpty, !trimmedName.isEmpty {
            venueEntries[index].name = trimmedName
            applied.append("会場")
        }
        if venueEntries[index].trimmedAddress.isEmpty, !trimmedAddress.isEmpty {
            venueEntries[index].address = trimmedAddress
            applied.append("住所")
        }
        if venueEntries[index].startsAt == nil, let startsAt {
            venueEntries[index].startsAt = startsAt
            venueEntries[index].endsAt = max(endsAt ?? startsAt, startsAt)
            applied.append("開催期間")
        }
        return applied
    }

    private func importResultMessage(source: String, fields: [String]) -> String {
        let uniqueFields = Array(NSOrderedSet(array: fields)) as? [String] ?? fields
        guard !uniqueFields.isEmpty else {
            return "\(source)から取得できる項目はありませんでした。空欄は手入力できます。"
        }
        return "\(source)から\(uniqueFields.joined(separator: "・"))を反映しました。空欄は手入力できます。"
    }

    @MainActor
    private func fetchURLMetadata() async {
        isFetchingURL = true
        importStatus = "URLを読み取り中です。"
        recognizedTitleCandidates = []
        defer { isFetchingURL = false }
        do {
            let candidate = try await URLMetadataService.fetch(
                from: importURL,
                includesStructuredData: true
            )
            title = candidate.title
            officialURL = candidate.resolvedURL.absoluteString
            importURL = candidate.resolvedURL.absoluteString
            var appliedFields = ["公演名", "公式URL"]
            if eyecatchData == nil, let sourceImageData = candidate.imageData {
                let compressed = await Task.detached(priority: .userInitiated) {
                    QuickCaptureImageService.compressedJPEG(from: sourceImageData)
                }.value
                if let compressed {
                    eyecatchData = compressed
                    appliedFields.append("公演ビジュアル")
                }
            }
            appliedFields.append(
                contentsOf: applyImportedVenue(
                    name: candidate.venueName,
                    address: candidate.venueAddress,
                    startsAt: candidate.eventDate,
                    endsAt: candidate.eventEndDate
                )
            )
            importStatus = importResultMessage(source: "URL", fields: appliedFields)
        } catch {
            importStatus = "URLから情報を取得できませんでした。URLと公演名は手入力できます。"
        }
    }
}

private enum TheaterPerformanceRegistrationNextStep {
    case interest
    case datedPlan
    case ticketSchedule
}

private extension View {
    func clearRegistrationCardRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
