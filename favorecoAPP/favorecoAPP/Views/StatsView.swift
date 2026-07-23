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
    @State private var showsAmount = false
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

    private var thisYearVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .year) }
    }

    private var thisMonthVisits: [Visit] {
        visibleVisits.filter { calendar.isDate($0.visitedAt, equalTo: Date(), toGranularity: .month) }
    }

    private var totalAmount: Decimal {
        visibleVisits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var averageRating: Double {
        let ratedVisits = visibleVisits.filter { $0.overallRating > 0 }
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
        TheaterOrganizationAnalytics.make(people: people, links: personLinks, visits: visibleVisits)
    }

    private var theaterFocusPersonStats: [TheaterFocusPersonStat] {
        TheaterFocusPersonAnalytics.make(people: people, links: personLinks, visits: visibleVisits)
    }

    private var activePlans: [Plan] {
        plans.filter { !$0.isArchived }
    }

    private var activeAttempts: [TicketAttempt] {
        ticketAttempts.filter { !$0.isArchived && $0.plan?.isArchived != true }
    }

    private var thisYearPlans: [Plan] {
        activePlans.filter { calendar.isDate($0.startsAt, equalTo: Date(), toGranularity: .year) }
    }

    private var thisYearAttempts: [TicketAttempt] {
        activeAttempts.filter { attempt in
            guard let startsAt = attempt.plan?.startsAt else { return false }
            return calendar.isDate(startsAt, equalTo: Date(), toGranularity: .year)
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
                        summaryGrid
                        categoryStatsSection
                        theaterFocusPersonStatsSection
                        theaterOrganizationStatsSection
                        chartsSection
                        ticketStatsSection
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

    private var categoryStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ジャンル別")
                .font(FavorecoTypography.sectionTitle)

            if !purchaseManager.currentPlan.includesLocalFullFeatures {
                StatsLockedFeatureCard(
                    title: "詳細統計",
                    message: "ジャンル別の回数や傾向は、ProまたはPremiumで利用できます。",
                    systemImage: "chart.bar.xaxis",
                    requirement: "Pro以上"
                )
            } else if categoryStats.isEmpty {
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
                                    Image(systemName: "theatermasks.circle")
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
                                        .font(.title2.weight(.semibold))
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
                                    Image(systemName: "person.crop.circle")
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
                                        .font(.title2.weight(.semibold))
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
            Text("今年の予定・チケット")
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
                    StatsMetricCard(title: "今年の予定", value: "\(thisYearPlans.count)", icon: "calendar")
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

                if purchaseManager.currentPlan.includesSync {
                    NavigationLink {
                        StatsReportDraftView(
                            kind: .monthly,
                            allVisits: visibleVisits,
                            categories: categories,
                            initialPeriodStart: previousMonthStart
                        )
                    } label: {
                        StatsReportPreviewCard(
                            title: "先月の月刊Favoreco",
                            badge: "自動提案",
                            detail: "毎月1日に、先月の記録から新しい思い出カードを提案します。",
                            systemImage: "wand.and.stars"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        StatsReportDraftView(
                            kind: .yearly,
                            allVisits: visibleVisits,
                            categories: categories,
                            initialPeriodStart: previousYearStart
                        )
                    } label: {
                        StatsReportPreviewCard(
                            title: "昨年の年間Favoreco",
                            badge: "自動提案",
                            detail: "昨年の記録を横断して、ジャンル、場所、写真、印象的な体験を振り返ります。",
                            systemImage: "calendar.badge.star"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
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
            Image(systemName: systemImage)
                .font(.title3)
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
            return "\(components.year ?? 0)年\(components.month ?? 0)月"
        case .yearly:
            return date.formatted(.dateTime.year())
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
                    Image(systemName: kind == .monthly ? "sparkles" : "calendar.badge.star")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                Divider()

                HStack(spacing: 12) {
                    StatsReportMiniMetric(title: "記録", value: "\(visits.count)")
                    StatsReportMiniMetric(title: "写真", value: "\(photoCount)")
                    StatsReportMiniMetric(title: "ジャンル", value: "\(categoryStats.count)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(topCategoryName, systemImage: "square.grid.2x2")
                    Label(topVenueName, systemImage: "mappin.and.ellipse")
                    if let firstVisit = sortedVisits.first {
                        Label(firstVisit.event?.title ?? "無題", systemImage: "sparkles")
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

    private var reportHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ハイライト")
                .font(FavorecoTypography.sectionTitle)

            VStack(spacing: 10) {
                StatsWideCard(
                    title: "いちばん多かったジャンル",
                    value: topCategoryName,
                    caption: "今後はジャンル横断の変化や、前月/前年との差もここに出します。",
                    icon: "chart.pie"
                )
                StatsWideCard(
                    title: "よく出てきた場所",
                    value: topVenueName,
                    caption: "会場マスターが育つと、よく通った劇場・映画館・寺社・施設も見返せます。",
                    icon: "mappin.and.ellipse"
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
                icon: "photo.on.rectangle"
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
                Label(snapshot.topCategory, systemImage: "square.grid.2x2")
                Label(snapshot.topVenue, systemImage: "mappin.and.ellipse")
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
    @Environment(\.favorecoThemePalette) private var themePalette

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(stat.count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(stat.category.name, systemImage: stat.category.iconSymbol)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(themePalette.categoryColor(hex: stat.category.colorHex))
                Spacer()
                Text("\(stat.count)")
                    .font(FavorecoTypography.bodyStrong)
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
