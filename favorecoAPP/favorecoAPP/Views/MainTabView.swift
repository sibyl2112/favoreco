//
//  MainTabView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var selectedTab: MainTab = .home
    @State private var isShowingCreateMenu = false
    @State private var isShowingAddInboxItem = false
    @State private var selectedCategoryForRecord: RecordCategory?

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(MainTab.home)

                RecordsView()
                    .tabItem {
                        Label("記録", systemImage: "rectangle.stack")
                    }
                    .tag(MainTab.records)

                CalendarView()
                    .tabItem {
                        Label("カレンダー", systemImage: "calendar")
                    }
                    .tag(MainTab.calendar)

                StatsView()
                    .tabItem {
                        Label("統計", systemImage: "chart.bar")
                    }
                    .tag(MainTab.stats)
            }

            CenterCreateButton {
                isShowingCreateMenu = true
            }
        }
        .confirmationDialog("記録を追加", isPresented: $isShowingCreateMenu, titleVisibility: .visible) {
            if visibleCategories.isEmpty {
                Button("記録を追加") {}
                    .disabled(true)
            } else {
                ForEach(visibleCategories) { category in
                    Button("\(category.name)に記録を追加") {
                        selectedCategoryForRecord = category
                    }
                }
            }

            Button("あとで記録") {
                isShowingAddInboxItem = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今すぐ記録するか、Inboxに一時保存します。")
        }
        .sheet(item: $selectedCategoryForRecord) { category in
            AddExperienceView(category: category)
        }
        .sheet(isPresented: $isShowingAddInboxItem) {
            AddInboxItemView()
        }
    }
}

private enum MainTab: Hashable {
    case home
    case records
    case calendar
    case stats
}

private struct CenterCreateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
        }
        .accessibilityLabel("記録を追加")
        .padding(.bottom, 18)
    }
}

private struct RecordsView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]

    var body: some View {
        NavigationStack {
            List {
                if visits.isEmpty {
                    PlaceholderRow(
                        icon: "rectangle.stack",
                        title: "記録はまだありません",
                        message: "中央の＋から最初の記録を追加できます。"
                    )
                } else {
                    ForEach(visits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("記録")
        }
    }
}

private struct CalendarView: View {
    @Query(sort: \Visit.visitedAt, order: .forward) private var visits: [Visit]
    @State private var displayedMonth = Date().startOfMonth
    @State private var selectedDate = Date()

    private let calendar = Calendar.current

    private var daysInDisplayedMonth: [CalendarDay] {
        CalendarDay.days(for: displayedMonth, calendar: calendar)
    }

    private var visitsByDay: [Date: [Visit]] {
        Dictionary(grouping: visits) { visit in
            calendar.startOfDay(for: visit.visitedAt)
        }
    }

    private var selectedDayVisits: [Visit] {
        visitsByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    private var upcomingVisits: [Visit] {
        let today = calendar.startOfDay(for: Date())
        return visits
            .filter { calendar.startOfDay(for: $0.visitedAt) >= today }
            .prefix(5)
            .map { $0 }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    selectedDaySection
                    upcomingSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("カレンダー")
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)

            Spacer()

            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(FavorecoTypography.sectionTitle)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(daysInDisplayedMonth) { day in
                let dayVisits = visitsByDay[calendar.startOfDay(for: day.date)] ?? []
                CalendarDayCell(
                    day: day,
                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day.date),
                    visitCount: dayVisits.count
                ) {
                    selectedDate = day.date
                    if !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month) {
                        displayedMonth = day.date.startOfMonth
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .long, time: .omitted))
                .font(FavorecoTypography.sectionTitle)

            if selectedDayVisits.isEmpty {
                PlaceholderRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "この日の記録はありません",
                    message: "予定や訪問記録を追加するとここに表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedDayVisits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingVisits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("直近の予定")
                    .font(FavorecoTypography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(upcomingVisits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isInDisplayedMonth: Bool

    static func days(for month: Date, calendar: Calendar) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leadingDays = (0..<leadingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leadingCount, to: monthInterval.start)
        }
        let currentMonthDays = monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        let totalCount = leadingDays.count + currentMonthDays.count
        let trailingCount = (7 - totalCount % 7) % 7
        let trailingDays = (0..<trailingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset + 1, to: currentMonthDays.last ?? monthInterval.start)
        }

        return (leadingDays + currentMonthDays + trailingDays).map { date in
            CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthInterval.start, toGranularity: .month)
            )
        }
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let visitCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(day.date.formatted(.dateTime.day()))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(day.isInDisplayedMonth ? .primary : .tertiary)

                HStack(spacing: 3) {
                    ForEach(0..<min(visitCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? .white : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(backgroundShape)
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        }
        if visitCount > 0 {
            return AnyShapeStyle(Color.accentColor.opacity(0.10))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }
}

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}

private struct StatsView: View {
    var body: some View {
        NavigationStack {
            List {
                PlaceholderRow(
                    icon: "chart.bar",
                    title: "統計は準備中です",
                    message: "ジャンル別回数、年間まとめ、支出、評価などを集計します。"
                )
            }
            .navigationTitle("統計")
        }
    }
}

private struct PlaceholderRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
