import SwiftUI

struct TheaterPerformanceScheduleSection: View {
    let schedules: [TheaterPerformanceScheduleItem]
    let accentColor: Color

    @State private var showsAll = false
    @State private var expandedItemIDs: Set<String> = []

    private var visibleSchedules: [TheaterPerformanceScheduleItem] {
        showsAll
            ? schedules
            : EventDetailPresentation.prioritizedTheaterSchedules(schedules)
    }

    var body: some View {
        if !schedules.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    FavorecoIcon(systemName: "calendar", size: 20, fallbackWeight: .medium)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Text("公演スケジュール")
                        .font(FavorecoTypography.jpSerif(18, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
                    Spacer(minLength: 8)
                    Text("全\(schedules.count)公演地")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                ForEach(visibleSchedules) { schedule in
                    scheduleCard(schedule)
                }

                if schedules.count > 2 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showsAll.toggle()
                            if !showsAll { expandedItemIDs.removeAll() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showsAll ? "閉じる" : "ほか\(schedules.count - visibleSchedules.count)公演地を見る")
                            Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showsAll ? "公演地を2件の表示に戻します" : "すべての公演地を表示します")
                }
            }
        }
    }

    private func scheduleCard(_ schedule: TheaterPerformanceScheduleItem) -> some View {
        let isExpanded = expandedItemIDs.contains(schedule.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                if isExpanded {
                    expandedItemIDs.remove(schedule.id)
                } else {
                    expandedItemIDs.insert(schedule.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(schedule.performanceLabel.isEmpty ? "公演情報" : schedule.performanceLabel)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)
                    Spacer(minLength: 8)
                    Text(periodText(schedule))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.white.opacity(0.76))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                FavorecoIconLabel(schedule.venueName, systemImage: "mappin.and.ellipse")
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)

                if isExpanded, !schedule.address.isEmpty {
                    Text(schedule.address)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.leading, 27)
                        .transition(.opacity)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .theaterEventCard(accentColor: accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(schedule.performanceLabel)、\(periodText(schedule))、\(schedule.venueName)")
        .accessibilityHint(isExpanded ? "住所を閉じます" : "住所を表示します")
    }

    private func periodText(_ schedule: TheaterPerformanceScheduleItem) -> String {
        guard let start = schedule.startsAt else { return "会期未登録" }
        guard let end = schedule.endsAt,
              !Calendar.current.isDate(start, inSameDayAs: end) else {
            return FavorecoDateText.compactDateWithHalfWidthWeekday(start)
        }
        return "\(FavorecoDateText.compactDate(start))–\(FavorecoDateText.compactDateWithHalfWidthWeekday(end))"
    }
}

struct TheaterScheduleEntryEditor: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    @Binding var entry: EventVenueEntry
    let fallbackStart: Date
    let fallbackEnd: Date

    @State private var venueSuggestions: [PlaceSearchCandidate] = []
    @State private var selectedVenueCandidate: PlaceSearchCandidate?

    private var selectedVenueCoordinate: PlaceSearchCandidate? {
        guard let candidate = selectedVenueCandidate,
              candidate.name.trimmingCharacters(in: .whitespacesAndNewlines) == entry.trimmedName,
              candidate.address.trimmingCharacters(in: .whitespacesAndNewlines) == entry.trimmedAddress else {
            return nil
        }
        return candidate
    }

    private var hasPeriod: Binding<Bool> {
        Binding(
            get: { entry.startsAt != nil || entry.endsAt != nil },
            set: { enabled in
                if enabled {
                    let start = entry.startsAt ?? fallbackStart
                    entry.startsAt = start
                    entry.endsAt = max(entry.endsAt ?? fallbackEnd, start)
                } else {
                    entry.startsAt = nil
                    entry.endsAt = nil
                }
            }
        )
    }

    private var performanceLabel: Binding<String> {
        Binding(
            get: { entry.performanceLabel ?? "" },
            set: { entry.performanceLabel = $0 }
        )
    }

    private var startsAt: Binding<Date> {
        Binding(
            get: { entry.startsAt ?? fallbackStart },
            set: { newValue in
                entry.startsAt = newValue
                if let end = entry.endsAt, end < newValue { entry.endsAt = newValue }
            }
        )
    }

    private var endsAt: Binding<Date> {
        Binding(
            get: { max(entry.endsAt ?? fallbackEnd, entry.startsAt ?? fallbackStart) },
            set: { entry.endsAt = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormTextField(
                title: "公演地名",
                prompt: "例：東京公演",
                text: performanceLabel,
                labelStyle: .horizontal
            )
            scheduleDivider
            ExplicitFormTextField(
                title: "会場",
                prompt: "例：東京ドーム",
                text: $entry.name,
                labelStyle: .horizontal
            )
            if !venueSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(venueSuggestions.prefix(3)) { candidate in
                        Button {
                            entry.name = candidate.name
                            entry.address = candidate.address
                            selectedVenueCandidate = candidate
                            venueSuggestions = []
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                FavorecoIcon(
                                    systemName: "mappin.and.ellipse",
                                    size: 15,
                                    fallbackWeight: .medium
                                )
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 20, height: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(
                                            FavorecoTypography.jpSans(
                                                13,
                                                weight: .semibold,
                                                relativeTo: .body
                                            )
                                        )
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if !candidate.address.isEmpty {
                                        Text(candidate.address)
                                            .font(
                                                FavorecoTypography.jpSans(
                                                    11,
                                                    weight: .regular,
                                                    relativeTo: .caption
                                                )
                                            )
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if candidate.id != venueSuggestions.prefix(3).last?.id {
                            Divider()
                                .padding(.leading, 45)
                        }
                    }
                }
                .background(Color.secondary.opacity(0.06))
            }
            scheduleDivider
            ExplicitFormTextField(
                title: "住所",
                prompt: "例：東京都文京区後楽1丁目（任意）",
                text: $entry.address,
                labelStyle: .horizontal
            )
            scheduleDivider
            ExplicitFormControlRow(title: "会期") {
                Toggle("この公演地の会期を登録", isOn: hasPeriod)
                    .labelsHidden()
                    .tint(themePalette.prominentAction)
                    .accessibilityLabel("この公演地の会期を登録")
            }

            if hasPeriod.wrappedValue {
                scheduleDivider
                ExplicitFormControlRow(title: "開始日") {
                    DatePicker("開始日", selection: startsAt, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(
                            ExplicitFormMetrics.dateControlScale,
                            anchor: .trailing
                        )
                }
                scheduleDivider
                ExplicitFormControlRow(title: "終了日") {
                    DatePicker(
                        "終了日",
                        selection: endsAt,
                        in: startsAt.wrappedValue...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .scaleEffect(
                        ExplicitFormMetrics.dateControlScale,
                        anchor: .trailing
                    )
                }
            }

            if !entry.trimmedName.isEmpty, !entry.trimmedAddress.isEmpty {
                scheduleDivider
                VStack(alignment: .leading, spacing: 7) {
                    ExplicitFormFieldTitle(
                        title: "会場マップ",
                        isOptional: false,
                        isRequired: false
                    )

                    PlaceMapPreview(
                        venueName: entry.trimmedName,
                        address: entry.trimmedAddress,
                        latitude: selectedVenueCoordinate?.latitude ?? 0,
                        longitude: selectedVenueCoordinate?.longitude ?? 0
                    )
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 1)
        .task(id: entry.name) {
            await refreshVenueSuggestions()
        }
    }

    @MainActor
    private func refreshVenueSuggestions() async {
        let query = entry.trimmedName
        guard query.count >= 2, query != selectedVenueCandidate?.name else {
            venueSuggestions = []
            return
        }

        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, query == entry.trimmedName else { return }

        do {
            venueSuggestions = Array(
                try await PlaceSearchService.search(query: query)
                    .prefix(3)
            )
        } catch {
            venueSuggestions = []
        }
    }

    private var scheduleDivider: some View {
        Rectangle()
            .fill(ExplicitFormMetrics.rowSeparatorColor)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
