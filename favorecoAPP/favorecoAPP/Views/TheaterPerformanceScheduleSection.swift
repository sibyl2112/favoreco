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
                HStack(alignment: .firstTextBaseline) {
                    Text("公演スケジュール")
                        .font(FavorecoTypography.sectionTitle)
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

                Label(schedule.venueName, systemImage: "mappin.and.ellipse")
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
    @Binding var entry: EventVenueEntry
    let fallbackStart: Date
    let fallbackEnd: Date

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
        VStack(alignment: .leading, spacing: 10) {
            TextField("公演名（例：東京公演）", text: performanceLabel)
            TextField("会場名", text: $entry.name)
            TextField("住所（任意）", text: $entry.address)
            Toggle("この公演地の会期を登録", isOn: hasPeriod)

            if hasPeriod.wrappedValue {
                DatePicker("開始日", selection: startsAt, displayedComponents: .date)
                DatePicker(
                    "終了日",
                    selection: endsAt,
                    in: startsAt.wrappedValue...,
                    displayedComponents: .date
                )
            }
        }
        .padding(.vertical, 4)
    }
}
