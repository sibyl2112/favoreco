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
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var showsAmount = false

    private var calendar: Calendar {
        Calendar.current
    }

    private var thisYearVisits: [Visit] {
        visits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .year) }
    }

    private var thisMonthVisits: [Visit] {
        visits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .month) }
    }

    private var totalAmount: Decimal {
        visits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var averageRating: Double {
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else { return 0 }
        return ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
    }

    private var categoryStats: [CategoryStat] {
        categories
            .filter { !$0.isArchived }
            .map { category in
                let count = visits.filter { $0.event?.category?.id == category.id }.count
                return CategoryStat(category: category, count: count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryGrid
                    categoryStatsSection
                    spendingSection
                    ratingSection
                    reportPreviewSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("統計")
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsMetricCard(title: "総記録数", value: "\(visits.count)", icon: "rectangle.stack")
            StatsMetricCard(title: "今年", value: "\(thisYearVisits.count)", icon: "calendar")
            StatsMetricCard(title: "今月", value: "\(thisMonthVisits.count)", icon: "calendar.badge.clock")
            StatsMetricCard(title: "平均評価", value: averageRating == 0 ? "-" : String(format: "%.1f", averageRating), icon: "star.fill")
        }
    }

    private var categoryStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ジャンル別")
                .font(FavorecoTypography.sectionTitle)

            if categoryStats.isEmpty {
                PlaceholderRow(
                    icon: "square.grid.2x2",
                    title: "ジャンル別統計はまだありません",
                    message: "記録を追加すると、ジャンルごとの回数が表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(categoryStats) { stat in
                        CategoryStatRow(stat: stat, maxCount: categoryStats.first?.count ?? 1)
                    }
                }
            }
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出")
                .font(FavorecoTypography.sectionTitle)

            StatsPrivateAmountCard(
                title: "記録済み金額",
                value: formattedAmount(totalAmount),
                isRevealed: showsAmount,
                caption: "チケット代、購入額、遠征費など、金額ユニットに入力された合計です。",
                icon: "yensign.circle",
                onToggle: {
                    withAnimation(.snappy) {
                        showsAmount.toggle()
                    }
                }
            )
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価")
                .font(FavorecoTypography.sectionTitle)

            StatsWideCard(
                title: "平均評価",
                value: averageRating == 0 ? "未評価" : String(format: "%.1f", averageRating),
                caption: "評価が入力された記録だけを平均しています。",
                icon: "star.fill"
            )
        }
    }

    private var reportPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("思い出レポート")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                StatsReportPreviewCard(
                    title: "月刊Favoreco",
                    badge: "Premium候補",
                    detail: "毎月の記録、写真、ジャンル傾向、印象的な体験を自動で1枚の思い出カードにまとめる構想です。",
                    systemImage: "sparkles"
                )
                StatsReportPreviewCard(
                    title: "年間Favoreco",
                    badge: "Pro / Premium候補",
                    detail: "年間ベスト、今年の10枚、よく通った場所、ジャンル横断の変化を画像化できるようにします。",
                    systemImage: "calendar.badge.star"
                )
            }
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "¥\(number.stringValue)"
    }
}

private struct CategoryStat: Identifiable {
    let category: RecordCategory
    let count: Int

    var id: UUID {
        category.id
    }
}

private struct StatsMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(FavorecoTypography.jpSerif(30, weight: .bold, relativeTo: .largeTitle))
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CategoryStatRow: View {
    let stat: CategoryStat
    let maxCount: Int

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(stat.count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(stat.category.name, systemImage: stat.category.iconSymbol)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(Color(hex: stat.category.colorHex))
                Spacer()
                Text("\(stat.count)")
                    .font(FavorecoTypography.bodyStrong)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                    Capsule()
                        .fill(Color(hex: stat.category.colorHex))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsWideCard: View {
    let title: String
    let value: String
    let caption: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(value)
                    .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                Text(caption)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsPrivateAmountCard: View {
    let title: String
    let value: String
    let isRevealed: Bool
    let caption: String
    let icon: String
    let onToggle: () -> Void

    private var displayValue: String {
        isRevealed ? value : "••••••"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "金額を隠す" : "金額を表示")
                }

                Text(displayValue)
                    .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title))
                    .contentTransition(.numericText())
                    .privacySensitive(!isRevealed)

                Text(caption)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsReportPreviewCard: View {
    let title: String
    let badge: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(FavorecoTypography.bodyStrong)
                    Spacer()
                    Text(badge)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }

                Text(detail)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
