import SwiftUI
import SwiftData
import UIKit
import Charts

struct StatsView: View {
    let isActive: Bool
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \Plan.startsAt, order: .reverse) private var plans: [Plan]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Query(sort: \FavoPin.sortOrder) private var favoPins: [FavoPin]
    @State private var showsAmount = false
    @State private var selectedStatisticsCategoryID: UUID?
    @State private var selectedStatisticsYear = Calendar.current.component(.year, from: Date())
    @State private var selectedStatisticsMonth: Int?
    @AppStorage(AppStorageKeys.opensPreviousMonthlyReport) private var opensPreviousMonthlyReport = false
    @AppStorage(AppStorageKeys.opensPreviousYearlyReport) private var opensPreviousYearlyReport = false
    @State private var isShowingAutomaticMonthlyReport = false
    @State private var isShowingAutomaticYearlyReport = false

    private var calendar: Calendar {
        Calendar.current
    }

    private var visibleVisits: [Visit] {
        visits.filter { $0.event?.isArchived != true }
    }

    private var statisticsCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var selectedStatisticsCategory: RecordCategory? {
        guard let selectedStatisticsCategoryID else { return nil }
        return statisticsCategories.first { $0.id == selectedStatisticsCategoryID }
    }

    private var scopedStatisticsVisits: [Visit] {
        guard let selectedStatisticsCategoryID else { return visibleVisits }
        return visibleVisits.filter { $0.event?.category?.id == selectedStatisticsCategoryID }
    }

    private var selectedYearStatisticsVisits: [Visit] {
        scopedStatisticsVisits.filter {
            calendar.component(.year, from: $0.visitedAt) == selectedStatisticsYear
        }
    }

    private var previousYearStatisticsVisits: [Visit] {
        scopedStatisticsVisits.filter {
            calendar.component(.year, from: $0.visitedAt) == selectedStatisticsYear - 1
        }
    }

    private var earliestStatisticsYear: Int {
        visibleVisits.map { calendar.component(.year, from: $0.visitedAt) }.min()
            ?? calendar.component(.year, from: Date())
    }

    private var currentStatisticsYear: Int {
        calendar.component(.year, from: Date())
    }

    private var canMoveToPreviousStatisticsYear: Bool {
        selectedStatisticsYear > earliestStatisticsYear
    }

    private var canMoveToNextStatisticsYear: Bool {
        selectedStatisticsYear < currentStatisticsYear
    }

    private var statisticsAccent: Color {
        guard let selectedStatisticsCategory else { return themePalette.globalTint }
        return themePalette.categoryColor(hex: selectedStatisticsCategory.colorHex)
    }

    private var statisticsOverviewSeries: [StatsOverviewSeries] {
        if let selectedStatisticsCategory {
            return [
                StatsOverviewSeries(
                    key: selectedStatisticsCategory.id.uuidString,
                    name: selectedStatisticsCategory.name,
                    color: themePalette.categoryColor(hex: selectedStatisticsCategory.colorHex),
                    categoryIDs: [selectedStatisticsCategory.id]
                )
            ]
        }

        var countsByCategory: [UUID: Int] = [:]
        for visit in selectedYearStatisticsVisits {
            guard let categoryID = visit.event?.category?.id else { continue }
            countsByCategory[categoryID, default: 0] += 1
        }

        let rankedCategories = statisticsCategories
            .map { category in (category, countsByCategory[category.id] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 { return $0.0.sortOrder < $1.0.sortOrder }
                return $0.1 > $1.1
            }

        let primaryCategories = Array(rankedCategories.prefix(6).map(\.0))
        var result = primaryCategories.map { category in
            StatsOverviewSeries(
                key: category.id.uuidString,
                name: category.name,
                color: themePalette.categoryColor(hex: category.colorHex),
                categoryIDs: [category.id]
            )
        }

        let otherCategoryIDs = Set(rankedCategories.dropFirst(6).map { $0.0.id })
        if !otherCategoryIDs.isEmpty {
            result.append(
                StatsOverviewSeries(
                    key: "other",
                    name: "その他",
                    color: .secondary,
                    categoryIDs: otherCategoryIDs
                )
            )
        }
        return result
    }

    private var monthlyStackedStatistics: [StatsMonthlyCategoryValue] {
        var counts: [StatsMonthSeriesKey: Int] = [:]
        let seriesByCategoryID = Dictionary(
            uniqueKeysWithValues: statisticsOverviewSeries.flatMap { series in
                series.categoryIDs.map { ($0, series.key) }
            }
        )

        for visit in selectedYearStatisticsVisits {
            guard
                let categoryID = visit.event?.category?.id,
                let seriesKey = seriesByCategoryID[categoryID]
            else { continue }
            let month = calendar.component(.month, from: visit.visitedAt)
            counts[StatsMonthSeriesKey(month: month, seriesKey: seriesKey), default: 0] += 1
        }

        return (1...12).flatMap { month in
            statisticsOverviewSeries.map { series in
                StatsMonthlyCategoryValue(
                    month: month,
                    seriesKey: series.key,
                    name: series.name,
                    count: counts[StatsMonthSeriesKey(month: month, seriesKey: series.key)] ?? 0,
                    color: series.color
                )
            }
        }
    }

    private var monthlyStackedTotals: [StatsMonthlyTotal] {
        (1...12).map { month in
            StatsMonthlyTotal(
                month: month,
                count: monthlyStackedStatistics
                    .filter { $0.month == month }
                    .reduce(0) { $0 + $1.count }
            )
        }
    }

    private var selectedMonthStatistics: [StatsMonthlyCategoryValue] {
        guard let selectedStatisticsMonth else { return [] }
        return monthlyStackedStatistics.filter {
            $0.month == selectedStatisticsMonth && $0.count > 0
        }
    }

    private var selectedMonthVisits: [Visit] {
        guard let selectedStatisticsMonth else { return [] }
        return selectedYearStatisticsVisits
            .filter { calendar.component(.month, from: $0.visitedAt) == selectedStatisticsMonth }
            .sorted { $0.visitedAt > $1.visitedAt }
    }

    private var selectedMonthRepresentativeVisit: Visit? {
        selectedMonthVisits.sorted { lhs, rhs in
            let lhsPriority = representativePriority(for: lhs)
            let rhsPriority = representativePriority(for: rhs)
            if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
            if lhs.visitedAt != rhs.visitedAt { return lhs.visitedAt > rhs.visitedAt }
            return lhs.updatedAt > rhs.updatedAt
        }.first
    }

    private var busiestMonthSummary: String {
        guard let busiest = monthlyStackedTotals.max(by: { $0.count < $1.count }), busiest.count > 0 else {
            return "記録なし"
        }
        return "\(busiest.month)月が最多・\(busiest.count)件"
    }

    private var thisYearVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .year) }
    }

    private var thisMonthVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .month) }
    }

    private var totalAmount: Decimal {
        scopedStatisticsVisits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var averageRating: Double {
        let ratedVisits = scopedStatisticsVisits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else { return 0 }
        return ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
    }

    private var categoryStats: [CategoryStat] {
        categories
            .filter { !$0.isArchived }
            .map { category in
                let count = visibleVisits.filter { $0.event?.category?.id == category.id }.count
                return CategoryStat(category: category, count: count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var monthlyVisitStats: [MonthlyVisitStat] {
        let currentMonth = Date().startOfMonth
        return (0..<12).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset - 11, to: currentMonth) else {
                return nil
            }
            let count = visibleVisits.lazy.filter {
                calendar.isDate($0.visitedAt, equalTo: month, toGranularity: .month)
            }.count
            return MonthlyVisitStat(month: month, count: count)
        }
    }

    private var categoryChartStats: [CategoryChartStat] {
        let topStats = Array(categoryStats.prefix(5))
        var result = topStats.map {
            CategoryChartStat(
                name: $0.category.name,
                count: $0.count,
                color: themePalette.categoryColor(hex: $0.category.colorHex)
            )
        }
        let otherCount = categoryStats.dropFirst(5).reduce(0) { $0 + $1.count }
        if otherCount > 0 {
            result.append(CategoryChartStat(name: "その他", count: otherCount, color: .secondary))
        }
        return result
    }

    private var theaterOrganizationStats: [TheaterOrganizationStat] {
        TheaterOrganizationAnalytics.make(people: people, links: personLinks, visits: scopedStatisticsVisits)
    }

    private var theaterFocusPersonStats: [TheaterFocusPersonStat] {
        TheaterFocusPersonAnalytics.make(people: people, links: personLinks, visits: scopedStatisticsVisits)
    }

    private var activePlans: [Plan] {
        plans.filter { plan in
            guard !plan.isArchived else { return false }
            guard let selectedStatisticsCategoryID else { return true }
            return plan.category?.id == selectedStatisticsCategoryID
                || plan.event?.category?.id == selectedStatisticsCategoryID
        }
    }

    private var activeAttempts: [TicketAttempt] {
        ticketAttempts.filter { attempt in
            guard !attempt.isArchived, attempt.plan?.isArchived != true else { return false }
            guard let selectedStatisticsCategoryID else { return true }
            return attempt.plan?.category?.id == selectedStatisticsCategoryID
                || attempt.plan?.event?.category?.id == selectedStatisticsCategoryID
        }
    }

    private var thisYearPlans: [Plan] {
        activePlans.filter { calendar.component(.year, from: $0.startsAt) == selectedStatisticsYear }
    }

    private var thisYearAttempts: [TicketAttempt] {
        activeAttempts.filter { attempt in
            guard let startsAt = attempt.plan?.startsAt else { return false }
            return calendar.component(.year, from: startsAt) == selectedStatisticsYear
        }
    }

    private var submittedAttempts: [TicketAttempt] {
        let submittedKeys: Set<String> = [
            "waitingResult", "won", "lost", "waitingPayment", "waitingIssue", "issued", "attended",
        ]
        return thisYearAttempts.filter { submittedKeys.contains($0.statusKey) }
    }

    private var wonAttempts: [TicketAttempt] {
        let wonKeys: Set<String> = ["won", "waitingPayment", "waitingIssue", "issued", "attended"]
        return thisYearAttempts.filter { wonKeys.contains($0.statusKey) }
    }

    private var lostAttempts: [TicketAttempt] {
        thisYearAttempts.filter { $0.statusKey == "lost" }
    }

    private var attendedAttempts: [TicketAttempt] {
        thisYearAttempts.filter { $0.statusKey == "attended" }
    }

    private var winRateText: String {
        let decidedCount = wonAttempts.count + lostAttempts.count
        guard decidedCount > 0 else { return "-" }
        return String(format: "%.0f%%", Double(wonAttempts.count) / Double(decidedCount) * 100)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MainScreenHeader(title: "統計")
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        statisticsOverviewSection
                        if selectedStatisticsCategory?.templateKey == "theater" {
                            theaterFocusPersonStatsSection
                            theaterOrganizationStatsSection
                        }
                        if selectedStatisticsCategory == nil || !thisYearPlans.isEmpty || !thisYearAttempts.isEmpty {
                            ticketStatsSection
                        }
                        spendingSection
                        ratingSection
                        reportPreviewSection
                    }
                    .padding(20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingAutomaticMonthlyReport) {
                StatsReportDraftView(
                    kind: .monthly,
                    allVisits: visibleVisits,
                    categories: categories,
                    initialPeriodStart: previousMonthStart
                )
            }
            .navigationDestination(isPresented: $isShowingAutomaticYearlyReport) {
                StatsReportDraftView(
                    kind: .yearly,
                    allVisits: visibleVisits,
                    categories: categories,
                    initialPeriodStart: previousYearStart
                )
            }
        }
        .task { openAutomaticReportIfNeeded() }
        .onChange(of: opensPreviousMonthlyReport) { _, _ in
            openAutomaticReportIfNeeded()
        }
        .onChange(of: opensPreviousYearlyReport) { _, _ in
            openAutomaticReportIfNeeded()
        }
        .onChange(of: isActive) { _, _ in
            openAutomaticReportIfNeeded()
        }
        .onChange(of: selectedStatisticsCategoryID) { _, _ in
            selectedStatisticsMonth = nil
        }
        .onChange(of: selectedStatisticsYear) { _, _ in
            selectedStatisticsMonth = nil
        }
    }

    private var statisticsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            statisticsCategorySelector
            statisticsYearSelector
            LayeredCategorySectionTitle(
                englishTitle: "Overview",
                japaneseTitle: "概要",
                foregroundColor: statisticsAccent
            )
            StatsOverviewSummaryCard(
                year: selectedStatisticsYear,
                yearCount: selectedYearStatisticsVisits.count,
                cumulativeCount: scopedStatisticsVisits.count,
                previousYearCount: previousYearStatisticsVisits.count,
                tint: statisticsAccent
            )
            statisticsMonthlyStackedChart
        }
    }

    private var statisticsCategorySelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("表示する統計")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

            Menu {
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        selectedStatisticsCategoryID = nil
                    }
                } label: {
                    if selectedStatisticsCategoryID == nil {
                        Label("すべてのジャンル", systemImage: "checkmark")
                    } else {
                        Text("すべてのジャンル")
                    }
                }

                Divider()

                ForEach(statisticsCategories) { category in
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            selectedStatisticsCategoryID = category.id
                        }
                    } label: {
                        if selectedStatisticsCategoryID == category.id {
                            Label(category.name, systemImage: "checkmark")
                        } else {
                            Text(category.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    FavorecoIcon(
                        systemName: selectedStatisticsCategory?.iconSymbol ?? "square.grid.2x2",
                        size: 18
                    )
                    .foregroundStyle(statisticsAccent)

                    Text(selectedStatisticsCategory?.name ?? "すべてのジャンル")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(statisticsAccent.opacity(0.22), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("表示する統計、\(selectedStatisticsCategory?.name ?? "すべてのジャンル")")
        }
    }

    private var statisticsYearSelector: some View {
        HStack {
            Button {
                guard canMoveToPreviousStatisticsYear else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    selectedStatisticsYear -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(statisticsAccent)
            .disabled(!canMoveToPreviousStatisticsYear)
            .accessibilityLabel("前年を表示")

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: String(selectedStatisticsYear))
                    .font(StatsTypography.number(17, weight: .semibold, relativeTo: .body))
                Text("年")
                    .font(StatsTypography.supportingStrong(17, relativeTo: .body))
            }

            Spacer()

            Button {
                guard canMoveToNextStatisticsYear else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    selectedStatisticsYear += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(statisticsAccent)
            .disabled(!canMoveToNextStatisticsYear)
            .accessibilityLabel("翌年を表示")
        }
        .padding(.horizontal, 4)
    }

    private var statisticsMonthlyStackedChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                LayeredCategorySectionTitle(
                    englishTitle: "Monthly Experiences",
                    japaneseTitle: "月ごとの体験",
                    foregroundColor: statisticsAccent
                )
                Spacer()
                Text(busiestMonthSummary)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                if selectedYearStatisticsVisits.isEmpty {
                    PlaceholderRow(
                        icon: "chart.bar.xaxis",
                        title: "\(FavorecoDateText.year(selectedStatisticsYear))の記録はありません",
                        message: "記録が入ると、月ごとの件数とジャンル構成を表示します。"
                    )
                    .padding(.vertical, 16)
                } else {
                    Chart {
                        ForEach(monthlyStackedStatistics) { stat in
                            if stat.count > 0 {
                                BarMark(
                                    x: .value("月", stat.monthKey),
                                    y: .value("体験数", stat.count),
                                    width: .fixed(20)
                                )
                                .foregroundStyle(stat.color)
                                .opacity(
                                    selectedStatisticsMonth == nil || selectedStatisticsMonth == stat.month
                                        ? 1
                                        : 0.34
                                )
                                .accessibilityLabel("\(stat.month)月、\(stat.name)")
                                .accessibilityValue("\(stat.count)件")
                            }
                        }

                        ForEach(monthlyStackedTotals) { total in
                            if total.count > 0 {
                                PointMark(
                                    x: .value("月", total.monthKey),
                                    y: .value("体験数", total.count)
                                )
                                .foregroundStyle(Color.clear)
                                .opacity(
                                    selectedStatisticsMonth == nil || selectedStatisticsMonth == total.month
                                        ? 1
                                        : 0.34
                                )
                                .annotation(position: .top, spacing: 3) {
                                    Text("\(total.count)")
                                        .font(StatsTypography.number(11, weight: .medium, relativeTo: .caption2))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }

                        if let selectedStatisticsMonth {
                            RuleMark(x: .value("選択月", String(selectedStatisticsMonth)))
                                .foregroundStyle(statisticsAccent.opacity(0.54))
                                .lineStyle(StrokeStyle(lineWidth: 1.25))
                        }
                    }
                    .chartXScale(
                        domain: StatsMonthlyTotal.monthKeys,
                        range: .plotDimension(startPadding: 10, endPadding: 10)
                    )
                    .chartXAxis {
                        AxisMarks(values: StatsMonthlyTotal.monthKeys) { value in
                            AxisValueLabel {
                                if let month = value.as(String.self) {
                                    Text(month)
                                        .font(StatsTypography.number(11, weight: .medium, relativeTo: .caption2))
                                        .monospacedDigit()
                                }
                            }
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.secondary.opacity(0.18))
                            AxisValueLabel()
                                .font(StatsTypography.number(11, weight: .medium, relativeTo: .caption2))
                        }
                    }
                    .chartXSelection(value: statisticsMonthSelection)
                    .frame(height: 230)
                    .accessibilityLabel(
                        Text(verbatim: "\(FavorecoDateText.year(selectedStatisticsYear))の月別・ジャンル別体験数")
                    )
                    .animation(.snappy(duration: 0.28), value: selectedStatisticsYear)
                    .animation(.snappy(duration: 0.28), value: selectedStatisticsCategoryID)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), alignment: .leading)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(statisticsOverviewSeries) { series in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(series.color)
                                    .frame(width: 8, height: 8)
                                Text(series.name)
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    if let selectedStatisticsMonth {
                        selectedMonthDrillDown(month: selectedStatisticsMonth)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var statisticsMonthSelection: Binding<String?> {
        Binding(
            get: { selectedStatisticsMonth.map(String.init) },
            set: { rawValue in
                let nextMonth = rawValue.flatMap(Int.init)
                guard nextMonth != selectedStatisticsMonth else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    selectedStatisticsMonth = nextMonth
                }
                if nextMonth != nil {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        )
    }

    @ViewBuilder
    private func selectedMonthDrillDown(month: Int) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(month)")
                        .font(StatsTypography.number(17, weight: .semibold, relativeTo: .headline))
                    Text("月")
                        .font(StatsTypography.supportingStrong(17, relativeTo: .headline))
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(selectedMonthVisits.count)")
                        .font(StatsTypography.number(14, weight: .medium, relativeTo: .subheadline))
                    Text("件")
                        .font(StatsTypography.supporting(14, weight: .medium, relativeTo: .subheadline))
                }
                .foregroundStyle(.secondary)
                Spacer()
            }

            if selectedMonthVisits.isEmpty {
                Text("この月の記録はありません")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(selectedMonthStatistics.map { "\($0.name) \($0.count)" }.joined(separator: "・"))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let representativeVisit = selectedMonthRepresentativeVisit {
                    NavigationLink {
                        ExperienceDetailView(visit: representativeVisit)
                    } label: {
                        StatsMonthRepresentativeRow(
                            visit: representativeVisit,
                            isFavoRelated: isRelatedToFavo(representativeVisit)
                        )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    StatsMonthExperienceListView(
                        year: selectedStatisticsYear,
                        month: month,
                        visits: selectedMonthVisits
                    )
                } label: {
                    HStack(spacing: 6) {
                        Text("\(month)月の体験をすべて見る")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(statisticsAccent)
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(month)月の体験、\(selectedMonthVisits.count)件")
    }

    private func representativePriority(for visit: Visit) -> Int {
        if isRelatedToFavo(visit) { return 2 }
        if firstStoredPhoto(in: visit) != nil { return 1 }
        return 0
    }

    private func isRelatedToFavo(_ visit: Visit) -> Bool {
        let eventID = visit.event?.id
        let placeID = visit.placeMaster?.id
        let personIDs = Set(
            ((visit.event?.personLinks ?? []) + (visit.personLinks ?? []))
                .filter { !$0.isArchived }
                .compactMap { $0.person?.id }
        )

        return favoPins.contains { pin in
            switch pin.targetKind {
            case .event:
                guard let eventID else { return false }
                return pin.event?.id == eventID
            case .place:
                guard let placeID else { return false }
                return pin.place?.id == placeID
            case .person:
                return pin.person.map { personIDs.contains($0.id) } == true
            }
        }
    }

    private func firstStoredPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData && !$0.data.isEmpty }
            .min { $0.createdAt < $1.createdAt }
    }

    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: Date().startOfMonth) ?? Date().startOfMonth
    }

    private var previousYearStart: Date {
        let currentYearStart = calendar.date(from: calendar.dateComponents([.year], from: Date())) ?? Date()
        return calendar.date(byAdding: .year, value: -1, to: currentYearStart) ?? currentYearStart
    }

    private func openAutomaticReportIfNeeded() {
        guard isActive, purchaseManager.currentPlan.includesSync else { return }
        if opensPreviousYearlyReport {
            opensPreviousYearlyReport = false
            isShowingAutomaticYearlyReport = true
        } else if opensPreviousMonthlyReport {
            opensPreviousMonthlyReport = false
            isShowingAutomaticMonthlyReport = true
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsMetricCard(title: "総記録数", value: "\(visibleVisits.count)", icon: "rectangle.stack")
            StatsMetricCard(title: "今年", value: "\(thisYearVisits.count)", icon: "calendar")
            StatsMetricCard(title: "今月", value: "\(thisMonthVisits.count)", icon: "calendar.badge.clock")
            StatsMetricCard(title: "平均評価", value: averageRating == 0 ? "-" : String(format: "%.1f", averageRating), icon: "star.fill")
        }
    }

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LayeredCategorySectionTitle(
                englishTitle: "Spending",
                japaneseTitle: "支出",
                foregroundColor: statisticsAccent
            )

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

    private var theaterOrganizationStatsSection: some View {
        Group {
            if !theaterOrganizationStats.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("観劇・団体別")
                        .font(FavorecoTypography.sectionTitle)

                    if !purchaseManager.currentPlan.includesLocalFullFeatures {
                        StatsLockedFeatureCard(
                            title: "団体別の観劇統計",
                            message: "上演団体・主催・制作別に、公演数と観劇回数をまとめます。",
                            systemImage: "person.3.sequence",
                            requirement: "Pro以上"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(theaterOrganizationStats.prefix(8)) { stat in
                                HStack(spacing: 12) {
                                    FavorecoIcon(systemName: "theatermasks.circle", size: 17)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(stat.name)
                                                .font(FavorecoTypography.bodyStrong)
                                            if stat.includesChildOrganizations {
                                                Text("傘下を含む")
                                                    .font(FavorecoTypography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Text("\(stat.eventCount)公演・\(stat.visitCount)回観劇")
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(stat.visitCount)")
                                        .font(StatsTypography.number(22, weight: .semibold, relativeTo: .title2))
                                }
                                .padding(14)
                                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private var theaterFocusPersonStatsSection: some View {
        Group {
            if !theaterFocusPersonStats.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("観劇・注目人物別")
                        .font(FavorecoTypography.sectionTitle)

                    if !purchaseManager.currentPlan.includesLocalFullFeatures {
                        StatsLockedFeatureCard(
                            title: "注目人物別の観劇統計",
                            message: "お目当て・注目した人ごとに、公演数と観劇回数をまとめます。",
                            systemImage: "person.crop.circle.badge.checkmark",
                            requirement: "Pro以上"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(theaterFocusPersonStats.prefix(8)) { stat in
                                HStack(spacing: 12) {
                                    FavorecoIcon(systemName: "person.crop.circle", size: 17)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stat.name)
                                            .font(FavorecoTypography.bodyStrong)
                                        Text("\(stat.eventCount)公演・\(stat.visitCount)回観劇")
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(stat.visitCount)")
                                        .font(StatsTypography.number(22, weight: .semibold, relativeTo: .title2))
                                }
                                .padding(14)
                                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("記録の傾向")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "推移・構成グラフ",
                    message: "直近12か月の記録推移と、ジャンル構成を見返せます。",
                    systemImage: "chart.xyaxis.line",
                    requirement: "Pro以上"
                )
            } else if visibleVisits.isEmpty {
                PlaceholderRow(
                    icon: "chart.xyaxis.line",
                    title: "記録の傾向はまだありません",
                    message: "記録を追加すると、月ごとの推移とジャンル構成が表示されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("直近12か月")
                        .font(FavorecoTypography.bodyStrong)
                    Chart(monthlyVisitStats) { stat in
                        AreaMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.12))
                        LineMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("月", stat.month, unit: .month),
                            y: .value("記録数", stat.count)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 2)) { value in
                            if let month = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(FavorecoDateText.month(month))
                                }
                            }
                        }
                    }
                    .frame(height: 190)
                    .accessibilityLabel("直近12か月の記録数推移")

                    if !categoryChartStats.isEmpty {
                        Divider()
                        Text("ジャンル構成")
                            .font(FavorecoTypography.bodyStrong)
                        HStack(alignment: .center, spacing: 18) {
                            Chart(categoryChartStats) { stat in
                                SectorMark(
                                    angle: .value("記録数", stat.count),
                                    innerRadius: .ratio(0.58),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(stat.color)
                                .cornerRadius(2)
                            }
                            .frame(width: 150, height: 150)
                            .accessibilityLabel("ジャンル別の記録構成")

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(categoryChartStats) { stat in
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(stat.color)
                                            .frame(width: 9, height: 9)
                                        Text(stat.name)
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text("\(stat.count)")
                                            .font(StatsTypography.number(12, weight: .medium, relativeTo: .caption))
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(FavorecoTypography.caption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var ticketStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "\(FavorecoDateText.year(selectedStatisticsYear))の予定・チケット")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "予定・申込の詳細統計",
                    message: "今年の予定、申込済み、取得、参加、確定済み抽選の当選率をまとめます。",
                    systemImage: "ticket",
                    requirement: "Pro以上"
                )
            } else if thisYearPlans.isEmpty && thisYearAttempts.isEmpty {
                PlaceholderRow(
                    icon: "ticket",
                    title: "予定・チケット統計はまだありません",
                    message: "予定や申込を追加すると、ここへ集計されます。"
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatsMetricCard(
                        title: "\(FavorecoDateText.year(selectedStatisticsYear))の予定",
                        value: "\(thisYearPlans.count)",
                        icon: "calendar"
                    )
                    StatsMetricCard(title: "申込済み", value: "\(submittedAttempts.count)", icon: "paperplane.fill")
                    StatsMetricCard(title: "取得", value: "\(wonAttempts.count)", icon: "checkmark.seal.fill")
                    StatsMetricCard(title: "参加済み", value: "\(attendedAttempts.count)", icon: "figure.walk")
                }
                StatsWideCard(
                    title: "当選率",
                    value: winRateText,
                    caption: "当選または落選が確定した抽選だけを分母にしています。",
                    icon: "percent"
                )
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LayeredCategorySectionTitle(
                englishTitle: "Ratings",
                japaneseTitle: "評価",
                foregroundColor: statisticsAccent
            )

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
            LayeredCategorySectionTitle(
                englishTitle: "Memory Reports",
                japaneseTitle: "思い出レポート",
                foregroundColor: statisticsAccent
            )

            VStack(spacing: 10) {
                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    NavigationLink {
                        StatsReportDraftView(kind: .monthly, allVisits: visibleVisits, categories: categories)
                    } label: {
                        StatsReportPreviewCard(
                            title: "月刊Favoreco",
                            badge: "手動作成",
                            detail: "今月の記録、写真、ジャンル傾向、印象的な体験を1枚の思い出カードにまとめます。",
                            systemImage: "sparkles"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatsLockedFeatureCard(
                        title: "月刊Favoreco",
                        message: "月ごとの記録を集計し、思い出カードを手動で作成・共有できます。",
                        systemImage: "sparkles",
                        requirement: "Pro以上"
                    )
                }

                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    NavigationLink {
                        StatsReportDraftView(kind: .yearly, allVisits: visibleVisits, categories: categories)
                    } label: {
                        StatsReportPreviewCard(
                            title: "年間Favoreco",
                            badge: "手動作成",
                            detail: "年間ベスト、今年の10枚、よく通った場所、ジャンル横断の変化を見返します。",
                            systemImage: "calendar.badge.star"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    StatsLockedFeatureCard(
                        title: "年間Favoreco",
                        message: "1年分の記録を集計し、年間の思い出カードを手動で作成・共有できます。",
                        systemImage: "calendar.badge.star",
                        requirement: "Pro以上"
                    )
                }

                if !purchaseManager.currentPlan.includesSync {
                    StatsLockedFeatureCard(
                        title: "毎月・毎年届く思い出レポート",
                        message: "同期済みの記録から、前月の月刊と前年の年間Favorecoを自動で提案します。",
                        systemImage: "wand.and.stars",
                        requirement: "Premium限定"
                    )
                }
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

private struct StatsLockedFeatureCard: View {
    let title: String
    let message: String
    let systemImage: String
    let requirement: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: systemImage, size: 20)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(
                    requirement,
                    systemImage: requirement.contains("準備中") ? "clock" : "lock.fill"
                )
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BookReadingEntry: Equatable {
    let completedAt: Date
    let pageCount: Int
}

struct BookReadingMonthStat: Identifiable, Equatable {
    let month: Int
    let bookCount: Int
    let pageCount: Int

    var id: Int { month }
}

struct BookReadingYearSummary: Equatable {
    let year: Int
    let months: [BookReadingMonthStat]

    var bookCount: Int { months.reduce(0) { $0 + $1.bookCount } }
    var pageCount: Int { months.reduce(0) { $0 + $1.pageCount } }
}

enum BookReadingAnalytics {
    static func yearly(
        entries: [BookReadingEntry],
        yearContaining date: Date,
        calendar: Calendar = .current
    ) -> BookReadingYearSummary {
        let year = calendar.component(.year, from: date)
        let entriesInYear = entries.filter {
            calendar.component(.year, from: $0.completedAt) == year
        }
        let months = (1...12).map { month in
            let matching = entriesInYear.filter {
                calendar.component(.month, from: $0.completedAt) == month
            }
            return BookReadingMonthStat(
                month: month,
                bookCount: matching.count,
                pageCount: matching.reduce(0) { $0 + max($1.pageCount, 0) }
            )
        }
        return BookReadingYearSummary(year: year, months: months)
    }
}

private enum StatsReportKind {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly:
            return "月刊Favoreco"
        case .yearly:
            return "年間Favoreco"
        }
    }

    func periodStart(containing date: Date) -> Date {
        switch self {
        case .monthly:
            return date.startOfMonth
        case .yearly:
            return Calendar.current.date(
                from: Calendar.current.dateComponents([.year], from: date)
            ) ?? date
        }
    }

    func periodLabel(for date: Date) -> String {
        switch self {
        case .monthly:
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            return "\(FavorecoDateText.year(components.year ?? 0))\(components.month ?? 0)月"
        case .yearly:
            return FavorecoDateText.year(Calendar.current.component(.year, from: date))
        }
    }

    func moved(_ date: Date, by value: Int) -> Date {
        let component: Calendar.Component = self == .monthly ? .month : .year
        return Calendar.current.date(byAdding: component, value: value, to: date) ?? date
    }

    func contains(_ date: Date, in periodStart: Date) -> Bool {
        let granularity: Calendar.Component = self == .monthly ? .month : .year
        return Calendar.current.isDate(date, equalTo: periodStart, toGranularity: granularity)
    }

    func emptyMessage(for periodLabel: String) -> String {
        switch self {
        case .monthly:
            return "\(periodLabel)に記録が入ると、思い出カード候補がここに表示されます。"
        case .yearly:
            return "\(periodLabel)に記録が入ると、年間まとめやベスト候補がここに表示されます。"
        }
    }
}

private struct StatsReportDraftView: View {
    let kind: StatsReportKind
    let allVisits: [Visit]
    let categories: [RecordCategory]
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var selectedPeriodStart: Date
    @State private var showsAmount = false
    @State private var showsCopyConfirmation = false
    @State private var shareImage: UIImage?
    @State private var isShowingImageShare = false
    @State private var imageGenerationError = ""

    init(
        kind: StatsReportKind,
        allVisits: [Visit],
        categories: [RecordCategory],
        initialPeriodStart: Date? = nil
    ) {
        self.kind = kind
        self.allVisits = allVisits
        self.categories = categories
        _selectedPeriodStart = State(initialValue: kind.periodStart(containing: initialPeriodStart ?? Date()))
    }

    private var visits: [Visit] {
        allVisits.filter { kind.contains($0.visitedAt, in: selectedPeriodStart) }
    }

    private var periodLabel: String {
        kind.periodLabel(for: selectedPeriodStart)
    }

    private var canMoveForward: Bool {
        selectedPeriodStart < kind.periodStart(containing: Date())
    }

    private var sortedVisits: [Visit] {
        visits.sorted { $0.visitedAt > $1.visitedAt }
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

    private var totalAmount: Decimal {
        visits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var photoCount: Int {
        visits.reduce(0) { $0 + ($1.photos?.count ?? 0) }
    }

    private var averageRating: Double {
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else { return 0 }
        return ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
    }

    private var topVenueName: String {
        let names = visits
            .map { $0.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return mostFrequentValue(in: names) ?? "未記録"
    }

    private var topCategoryName: String {
        categoryStats.first?.category.name ?? "未記録"
    }

    private var bookReadingYearSummary: BookReadingYearSummary {
        let entries = allVisits.compactMap { visit -> BookReadingEntry? in
            guard visit.event?.category?.templateKey == "book" else { return nil }
            let visitFields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            // 旧データは読了日の有無フラグを持たないため、明示的な「読書中」だけを除外する。
            guard visitFields.bookReadingHasEndDate != false else { return nil }
            return BookReadingEntry(
                completedAt: visit.endedAt,
                pageCount: visit.event?.bookPageCount ?? 0
            )
        }
        return BookReadingAnalytics.yearly(
            entries: entries,
            yearContaining: selectedPeriodStart
        )
    }

    private var shareText: String {
        var lines = [
            "\(kind.title) \(periodLabel)",
            "記録: \(visits.count)",
            "写真: \(photoCount)",
            "ジャンル: \(categoryStats.count)",
            "平均評価: \(averageRating == 0 ? "-" : String(format: "%.1f", averageRating))",
            "最多ジャンル: \(topCategoryName)",
            "よく出てきた場所: \(topVenueName)"
        ]

        if let firstVisit = sortedVisits.first {
            lines.append("カード候補: \(firstVisit.event?.title ?? "無題")")
        }

        if kind == .yearly, bookReadingYearSummary.bookCount > 0 {
            lines.append("読了: \(bookReadingYearSummary.bookCount)冊")
            lines.append("読了ページ: \(bookReadingYearSummary.pageCount)ページ")
        }

        lines.append("#Favoreco")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                reportHero

                if visits.isEmpty {
                    PlaceholderRow(
                        icon: "sparkles",
                        title: "\(periodLabel)の記録はまだありません",
                        message: kind.emptyMessage(for: periodLabel)
                    )
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    reportCardPreview
                    reportMetrics
                    if kind == .yearly {
                        bookReadingYearSection
                    }
                    reportHighlights
                    reportCategories
                    recentRecords
                    reportNextStep
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("共有用テキストをコピーしました", isPresented: $showsCopyConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("画像化の前段として、レポートの要約をテキストで共有できます。")
        }
        .alert("画像を作成できませんでした", isPresented: Binding(
            get: { !imageGenerationError.isEmpty },
            set: { if !$0 { imageGenerationError = "" } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageGenerationError)
        }
        .sheet(isPresented: $isShowingImageShare) {
            if let shareImage {
                StatsReportActivityView(activityItems: [shareImage])
            }
        }
    }

    private var reportHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(kind == .monthly ? "前の月" : "前の年")

                Spacer()
                Text(periodLabel)
                    .font(FavorecoTypography.bodyStrong)
                Spacer()

                Button {
                    movePeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveForward)
                .accessibilityLabel(kind == .monthly ? "次の月" : "次の年")
            }
            Text(kind.title)
                .font(FavorecoTypography.jpSerif(32, weight: .bold, relativeTo: .largeTitle))
            Text("端末内の記録から集計した思い出レポートです。カード画像として保存・共有できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var reportCardPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カードプレビュー")
                .font(FavorecoTypography.sectionTitle)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .largeTitle))
                        Text(periodLabel)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    FavorecoIcon(
                        systemName: kind == .monthly ? "sparkles" : "calendar.badge.star",
                        size: 22
                    )
                        .foregroundStyle(Color.accentColor)
                }

                Divider()

                HStack(spacing: 12) {
                    StatsReportMiniMetric(title: "記録", value: "\(visits.count)")
                    StatsReportMiniMetric(title: "写真", value: "\(photoCount)")
                    StatsReportMiniMetric(title: "ジャンル", value: "\(categoryStats.count)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    FavorecoIconLabel(topCategoryName, systemImage: "square.grid.2x2", iconSize: 13)
                    FavorecoIconLabel(topVenueName, systemImage: "mappin.and.ellipse", iconSize: 13)
                    if let firstVisit = sortedVisits.first {
                        FavorecoIconLabel(
                            firstVisit.event?.title ?? "無題",
                            systemImage: "sparkles",
                            iconSize: 13
                        )
                    }
                }
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.16), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var reportMetrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsMetricCard(title: "記録", value: "\(visits.count)", icon: "rectangle.stack")
            StatsMetricCard(title: "写真", value: "\(photoCount)", icon: "photo.on.rectangle")
            StatsMetricCard(title: "ジャンル", value: "\(categoryStats.count)", icon: "square.grid.2x2")
            StatsMetricCard(title: "平均評価", value: averageRating == 0 ? "-" : String(format: "%.1f", averageRating), icon: "star.fill")
        }
    }

    @ViewBuilder
    private var bookReadingYearSection: some View {
        let summary = bookReadingYearSummary
        if summary.bookCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("年間読書量")
                    .font(FavorecoTypography.sectionTitle)

                HStack(spacing: 12) {
                    StatsMetricCard(title: "読了", value: "\(summary.bookCount)冊", icon: "books.vertical")
                    StatsMetricCard(title: "読了ページ", value: "\(summary.pageCount)ページ", icon: "doc.text")
                }

                VStack(spacing: 0) {
                    ForEach(summary.months) { stat in
                        HStack(spacing: 12) {
                            Text("\(stat.month)月")
                                .font(FavorecoTypography.bodyStrong)
                                .frame(width: 42, alignment: .leading)
                            Spacer(minLength: 8)
                            Text("\(stat.bookCount)冊")
                                .font(StatsTypography.number(17, weight: .regular, relativeTo: .body))
                                .monospacedDigit()
                                .frame(width: 56, alignment: .trailing)
                            Text("\(stat.pageCount)ページ")
                                .font(StatsTypography.number(17, weight: .regular, relativeTo: .body))
                                .monospacedDigit()
                                .frame(width: 96, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if stat.month < 12 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("ページ数が未設定の本も読了冊数には含まれます。再読は読書記録ごとに1冊として集計します。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reportHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ハイライト")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                StatsWideCard(
                    title: "いちばん多かったジャンル",
                    value: topCategoryName,
                    caption: "今後はジャンル横断の変化や、前月/前年との差もここに出します。",
                    icon: "chart.pie",
                    usesNumericFont: false
                )
                StatsWideCard(
                    title: "よく出てきた場所",
                    value: topVenueName,
                    caption: "会場マスターが育つと、よく通った劇場・映画館・寺社・施設も見返せます。",
                    icon: "mappin.and.ellipse",
                    usesNumericFont: false
                )
                StatsPrivateAmountCard(
                    title: "記録済み金額",
                    value: formattedAmount(totalAmount),
                    isRevealed: showsAmount,
                    caption: "金額はプライバシー情報なので、この下書きでも初期表示では伏せます。",
                    icon: "yensign.circle",
                    onToggle: {
                        withAnimation(.snappy) {
                            showsAmount.toggle()
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var reportCategories: some View {
        if !categoryStats.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("ジャンル傾向")
                    .font(FavorecoTypography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(categoryStats.prefix(5)) { stat in
                        CategoryStatRow(stat: stat, maxCount: categoryStats.first?.count ?? 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentRecords: some View {
        if !sortedVisits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("カード候補")
                    .font(FavorecoTypography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(Array(sortedVisits.prefix(3))) { visit in
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

    private var reportNextStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("共有")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                Button {
                    generateAndShareImage()
                } label: {
                    Label("カード画像を共有", systemImage: "photo.on.rectangle.angled")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                ShareLink(
                    item: shareText,
                    subject: Text(kind.title),
                    message: Text("Favorecoの思い出レポート")
                ) {
                    Label("テキストで共有", systemImage: "square.and.arrow.up")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    UIPasteboard.general.string = shareText
                    showsCopyConfirmation = true
                } label: {
                    Label("テキストをコピー", systemImage: "doc.on.doc")
                        .font(FavorecoTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            StatsWideCard(
                title: "カード画像",
                value: "手動生成",
                caption: "共有シートから画像保存やSNSへの共有ができます。金額はカード画像に含めません。",
                icon: "photo.on.rectangle",
                usesNumericFont: false
            )
        }
    }

    @MainActor
    private func generateAndShareImage() {
        let rows = categoryStats.prefix(4).map {
            StatsReportImageCategory(
                name: $0.category.name,
                count: $0.count,
                colorHex: themePalette.resolvedHex(categoryHex: $0.category.colorHex)
            )
        }
        let snapshot = StatsReportImageSnapshot(
            title: kind.title,
            period: periodLabel,
            recordCount: visits.count,
            photoCount: photoCount,
            categoryCount: categoryStats.count,
            averageRating: averageRating == 0 ? "-" : String(format: "%.1f", averageRating),
            topCategory: topCategoryName,
            topVenue: topVenueName,
            highlight: sortedVisits.first?.event?.title ?? "記録を重ねた時間",
            categories: rows
        )
        let renderer = ImageRenderer(content: StatsReportShareCard(snapshot: snapshot))
        renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            imageGenerationError = "画面を閉じてから、もう一度お試しください。"
            return
        }
        shareImage = image
        isShowingImageShare = true
    }

    private func movePeriod(by value: Int) {
        withAnimation(.snappy) {
            selectedPeriodStart = kind.moved(selectedPeriodStart, by: value)
            showsAmount = false
            shareImage = nil
        }
    }

    private func mostFrequentValue(in values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 })
            .map { (value: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.value < rhs.value
                }
                return lhs.count > rhs.count
            }
            .first?
            .value
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

private struct StatsReportImageSnapshot {
    let title: String
    let period: String
    let recordCount: Int
    let photoCount: Int
    let categoryCount: Int
    let averageRating: String
    let topCategory: String
    let topVenue: String
    let highlight: String
    let categories: [StatsReportImageCategory]
}

private struct StatsReportImageCategory: Identifiable {
    let name: String
    let count: Int
    let colorHex: String

    var id: String { "\(name)-\(colorHex)" }
}

private struct StatsReportShareCard: View {
    let snapshot: StatsReportImageSnapshot

    private var accent: Color {
        Color(hex: snapshot.categories.first?.colorHex ?? "#147C88")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.period)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(snapshot.title)
                    .font(FavorecoTypography.jpSerif(30, weight: .bold, relativeTo: .largeTitle))
                Rectangle()
                    .fill(accent)
                    .frame(width: 56, height: 4)
            }
            .padding(.bottom, 20)

            HStack(spacing: 8) {
                imageMetric("記録", "\(snapshot.recordCount)")
                imageMetric("写真", "\(snapshot.photoCount)")
                imageMetric("ジャンル", "\(snapshot.categoryCount)")
                imageMetric("平均評価", snapshot.averageRating)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("HIGHLIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                Text(snapshot.highlight)
                    .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                FavorecoIconLabel(snapshot.topCategory, systemImage: "square.grid.2x2", iconSize: 12)
                FavorecoIconLabel(snapshot.topVenue, systemImage: "mappin.and.ellipse", iconSize: 12)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 20)

            VStack(spacing: 9) {
                ForEach(snapshot.categories) { category in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: 9, height: 9)
                        Text(category.name)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(category.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
            }

            Spacer(minLength: 12)

            HStack {
                Text("Favoreco")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                Spacer()
                Text("MY EXPERIENCE ARCHIVE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .padding(24)
        .frame(width: 360, height: 450)
        .background(Color(red: 0.97, green: 0.97, blue: 0.95))
        .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.10))
    }

    private func imageMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct StatsReportActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StatsReportMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryStat: Identifiable {
    let category: RecordCategory
    let count: Int

    var id: UUID {
        category.id
    }
}

private struct StatsOverviewSeries: Identifiable {
    let key: String
    let name: String
    let color: Color
    let categoryIDs: Set<UUID>

    var id: String { key }
}

private struct StatsMonthSeriesKey: Hashable {
    let month: Int
    let seriesKey: String
}

private struct StatsMonthlyCategoryValue: Identifiable {
    let month: Int
    let seriesKey: String
    let name: String
    let count: Int
    let color: Color

    var id: String { "\(month)-\(seriesKey)" }
    var monthKey: String { String(month) }
}

private enum StatsTypography {
    static func number(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        FavorecoTypography.numericMono(size, weight: weight, relativeTo: textStyle)
    }

    static func heroNumber(_ size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        number(size, weight: .heavy, relativeTo: textStyle)
    }

    static func supporting(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom("Noto Sans JP", size: size, relativeTo: textStyle)
            .weight(weight)
    }

    static func supportingStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        supporting(size, weight: .semibold, relativeTo: textStyle)
    }
}

private struct StatsMonthRepresentativeRow: View {
    let visit: Visit
    let isFavoRelated: Bool

    @Environment(\.favorecoThemePalette) private var themePalette

    private var category: RecordCategory? { visit.event?.category }
    private var tint: Color { themePalette.categoryColor(hex: category?.colorHex ?? "#147C88") }
    private var title: String {
        let value = visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "記録" : value
    }
    private var firstPhoto: PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData && !$0.data.isEmpty }
            .min { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        HStack(spacing: 11) {
            artwork

            VStack(alignment: .leading, spacing: 4) {
                if isFavoRelated {
                    Text("MY FAVO")
                        .font(StatsTypography.supporting(9, weight: .semibold, relativeTo: .caption2))
                        .tracking(0.7)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 7) {
                    Text(FavorecoDateText.compactDate(visit.visitedAt))
                    if let categoryName = category?.name, !categoryName.isEmpty {
                        Text(categoryName)
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !visit.venueNameSnapshot.isEmpty {
                    FavorecoIconLabel(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse", iconSize: 11)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("代表体験、\(title)、\(FavorecoDateText.compactDate(visit.visitedAt))")
        .accessibilityHint("記録詳細を開きます")
    }

    @ViewBuilder
    private var artwork: some View {
        if let firstPhoto {
            RepresentativePhotoImage(photo: firstPhoto, maxPixelSize: 220, contentMode: .fill)
                .frame(width: 70, height: 62)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            CategoryEyecatchArtwork(
                reference: visit.event.map { .event($0.id) },
                templateKey: category?.templateKey ?? "",
                backgroundColor: tint.opacity(0.08),
                defaultContentMode: EyecatchAspectRatio.usesEyecatchFill(for: category) ? .fill : .fit
            ) { size in
                CategoryDefaultArtworkImage(
                    templateKey: category?.templateKey ?? "",
                    displaySize: size
                )
            }
            .frame(width: 70, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct StatsMonthExperienceListView: View {
    let year: Int
    let month: Int
    let visits: [Visit]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(visits) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        VisitSummaryRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(verbatim: "\(FavorecoDateText.year(year))\(month)月の体験"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct StatsMonthlyTotal: Identifiable {
    static let monthKeys = (1...12).map(String.init)

    let month: Int
    let count: Int

    var id: Int { month }
    var monthKey: String { String(month) }
}

private struct StatsOverviewSummaryCard: View {
    let year: Int
    let yearCount: Int
    let cumulativeCount: Int
    let previousYearCount: Int
    let tint: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var difference: Int {
        yearCount - previousYearCount
    }

    private var differenceText: String {
        if difference > 0 { return "+\(difference)" }
        return "\(difference)"
    }

    private var differenceSymbol: String {
        if difference > 0 { return "arrow.up.right" }
        if difference < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    yearMetricCard
                    cumulativeMetricCard
                    differenceMetricCard
                }
            } else {
                StatsOverviewDashboardLayout(
                    leadingFraction: 0.6,
                    trailingTopFraction: 0.62,
                    spacing: 10
                ) {
                    yearMetricCard
                    cumulativeMetricCard
                    differenceMetricCard
                }
            }
        }
    }

    private var yearMetricCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: "\(FavorecoDateText.year(year))の体験")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(yearCount)")
                    .font(StatsTypography.heroNumber(66, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .contentTransition(.numericText())
                Text("件")
                    .font(StatsTypography.supporting(15, relativeTo: .body))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { metricCardSurface(accentOpacity: 0.12, cornerRadius: 20) }
        .overlay { metricCardBorder(opacity: 0.18, cornerRadius: 20) }
        .shadow(color: tint.opacity(0.07), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(FavorecoDateText.year(year))の体験、\(yearCount)件"))
    }

    private var cumulativeMetricCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("累計体験")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(cumulativeCount)")
                    .font(StatsTypography.number(34, weight: .bold, relativeTo: .title))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("件")
                    .font(StatsTypography.supporting(12, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }

            Text("全期間")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { metricCardSurface(accentOpacity: 0.07, cornerRadius: 17) }
        .overlay { metricCardBorder(opacity: 0.14, cornerRadius: 17) }
        .shadow(color: tint.opacity(0.045), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("累計体験、\(cumulativeCount)件、全期間")
    }

    private var differenceMetricCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("前年比")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                Label {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(differenceText)
                            .monospacedDigit()
                        Text("件")
                            .font(StatsTypography.supporting(10, relativeTo: .caption2))
                    }
                } icon: {
                    Image(systemName: differenceSymbol)
                }
                .font(StatsTypography.number(18, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            }

            Text(verbatim: "\(FavorecoDateText.year(year - 1))の\(previousYearCount)件と比較")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { metricCardSurface(accentOpacity: 0.04, cornerRadius: 17) }
        .overlay { metricCardBorder(opacity: 0.11, cornerRadius: 17) }
        .shadow(color: tint.opacity(0.035), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim:
            "前年との差、\(differenceText)件、\(FavorecoDateText.year(year - 1))の\(previousYearCount)件と比較"
        ))
    }

    private func metricCardSurface(accentOpacity: Double, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay {
                LinearGradient(
                    colors: [Color.clear, tint.opacity(accentOpacity)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
    }

    private func metricCardBorder(opacity: Double, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(tint.opacity(opacity), lineWidth: 0.8)
    }
}

private struct StatsOverviewDashboardLayout: Layout {
    let leadingFraction: CGFloat
    let trailingTopFraction: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count >= 3 else { return .zero }
        return CGSize(width: proposal.width ?? 340, height: proposal.height ?? 214)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count >= 3 else { return }

        let usableWidth = max(0, bounds.width - spacing)
        let leadingWidth = floor(usableWidth * leadingFraction)
        let trailingWidth = max(0, usableWidth - leadingWidth)
        let usableTrailingHeight = max(0, bounds.height - spacing)
        let trailingTopHeight = floor(usableTrailingHeight * trailingTopFraction)
        let trailingBottomHeight = max(0, usableTrailingHeight - trailingTopHeight)
        let trailingX = bounds.minX + leadingWidth + spacing

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: leadingWidth, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: trailingX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: trailingWidth, height: trailingTopHeight)
        )
        subviews[2].place(
            at: CGPoint(x: trailingX, y: bounds.minY + trailingTopHeight + spacing),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: trailingWidth, height: trailingBottomHeight)
        )
    }
}

private struct MonthlyVisitStat: Identifiable {
    let month: Date
    let count: Int

    var id: Date { month }
}

private struct CategoryChartStat: Identifiable {
    let name: String
    let count: Int
    let color: Color

    var id: String { name }
}

private struct StatsMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(StatsTypography.number(30, weight: .bold, relativeTo: .largeTitle))
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
    @Environment(\.favorecoThemePalette) private var themePalette

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(stat.count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FavorecoIconLabel(stat.category.name, systemImage: stat.category.iconSymbol, iconSize: 17)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(themePalette.categoryColor(hex: stat.category.colorHex))
                Spacer()
                Text("\(stat.count)")
                    .font(StatsTypography.number(17, weight: .semibold, relativeTo: .body))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                    Capsule()
                        .fill(themePalette.categoryColor(hex: stat.category.colorHex))
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
    var usesNumericFont = true

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                Text(value)
                    .font(
                        usesNumericFont
                            ? StatsTypography.number(28, weight: .bold, relativeTo: .title)
                            : FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title)
                    )
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
            FavorecoIcon(systemName: icon, size: 20)
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
                    .font(StatsTypography.number(28, weight: .bold, relativeTo: .title))
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
            FavorecoIcon(systemName: systemImage, size: 20)
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
