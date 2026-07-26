import SwiftUI

enum HomeReportPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "今月"
        case .year: "今年"
        }
    }
}

struct HomeReportSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette
    @AppStorage(AppStorageKeys.homeReportPeriod) private var selectedPeriodRaw = HomeReportPeriod.month.rawValue

    let visits: [HomeVisitSnapshot]
    private let now = Date()

    private var selectedPeriod: HomeReportPeriod {
        get { HomeReportPeriod(rawValue: selectedPeriodRaw) ?? .month }
        nonmutating set { selectedPeriodRaw = newValue.rawValue }
    }

    private var periodVisits: [HomeVisitSnapshot] {
        let calendar = Calendar.current
        return visits.filter { visit in
            switch selectedPeriod {
            case .month:
                calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .month)
            case .year:
                calendar.isDate(visit.visitedAt, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var periodLabel: String {
        switch selectedPeriod {
        case .month:
            now.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).year().month(.wide))
        case .year:
            now.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).year())
        }
    }

    private var genreCount: Int {
        Set(periodVisits.map(\.categoryName)).count
    }

    private var photoCount: Int {
        periodVisits.filter { $0.thumbnailReference != nil }.count
    }

    private var topGenre: String {
        let counts = Dictionary(grouping: periodVisits, by: \.categoryName).mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        }?.key ?? "ー"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FAVORECO REPORT")
                .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(FavorecoTypography.brandColor(for: colorScheme))

            VStack(spacing: 0) {
                reportTabs

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 1)

                reportBody
                    .padding(12)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(themePalette.globalTint.opacity(0.20), lineWidth: 1)
            }
        }
    }

    private var reportTabs: some View {
        HStack(spacing: 0) {
            ForEach(HomeReportPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.title)
                        .font(FavorecoTypography.jpSerif(14, weight: selectedPeriod == period ? .bold : .medium, relativeTo: .body))
                        .foregroundStyle(selectedPeriod == period ? Color.white : Color.primary.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            selectedPeriod == period ? themePalette.globalTint : Color.clear,
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: period == .month ? 7 : 0,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: period == .year ? 7 : 0
                            )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle().inset(by: -3))
                .accessibilityLabel("\(period.title)タブ")
                .accessibilityValue(selectedPeriod == period ? "選択中" : "")

                if period == .month {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 20)
                }
            }
        }
    }

    private var reportBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(periodLabel)
                    .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                Spacer()
                Text("あなたの体験の記録")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if periodVisits.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(themePalette.globalTint)
                    Text("この期間の記録はまだありません")
                        .font(FavorecoTypography.cardTitle)
                    Text("記録を追加すると、写真と数字でこの期間を振り返れます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 176)
            } else {
                reportCollage
                reportMetrics

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("よく記録したジャンル：\(topGenre)")
                }
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(themePalette.globalTint)
            }
        }
    }

    private var reportCollage: some View {
        let items = Array(periodVisits.prefix(3))
        return HStack(spacing: 6) {
            HomeReportArtwork(visit: items[0])
                .frame(maxWidth: .infinity)

            if items.count > 1 {
                VStack(spacing: 6) {
                    HomeReportArtwork(visit: items[1])
                    if items.count > 2 {
                        HomeReportArtwork(visit: items[2])
                    } else {
                        reportPlaceholder
                    }
                }
                .frame(width: 104)
            }
        }
        .frame(height: 184)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var reportPlaceholder: some View {
        ZStack {
            themePalette.globalTint.opacity(0.08)
            Image(systemName: "sparkles")
                .foregroundStyle(themePalette.globalTint.opacity(0.55))
        }
    }

    private var reportMetrics: some View {
        HStack(spacing: 0) {
            HomeReportMetric(value: "\(periodVisits.count)", label: "記録")
            reportMetricDivider
            HomeReportMetric(value: "\(genreCount)", label: "ジャンル")
            reportMetricDivider
            HomeReportMetric(value: "\(photoCount)", label: "写真つき")
        }
        .frame(minHeight: 62)
        .background(themePalette.globalTint.opacity(colorScheme == .dark ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var reportMetricDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 1, height: 34)
    }
}

private struct HomeReportArtwork: View {
    let visit: HomeVisitSnapshot

    var body: some View {
        GeometryReader { geometry in
            ThumbnailImage(
                reference: visit.thumbnailReference,
                displaySize: geometry.size,
                contentMode: .fill
            ) {
                ZStack {
                    Color(hex: visit.categoryColorHex).opacity(0.15)
                    Image(systemName: visit.categoryIcon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: visit.categoryColorHex))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityLabel("\(visit.title)、\(visit.categoryName)")
    }
}

private struct HomeReportMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(FavorecoTypography.latinDisplay(27, weight: .bold, relativeTo: .title2))
                .monospacedDigit()
            Text(label)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
