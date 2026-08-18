//
//  CategoryTopFeatureComponents.swift
//  favorecoAPP
//
//  Extracted from CategoryTopView to isolate feature and ticket presentation.
//

import SwiftUI
import SwiftData
import UIKit

enum CategoryFeatureItem: Identifiable {
    case plan(Plan)
    case visit(Visit)
    case interest(ExperienceEvent)

    var id: String {
        switch self {
        case .plan(let plan): return "plan-\(plan.id.uuidString)"
        case .visit(let visit): return "visit-\(visit.id.uuidString)"
        case .interest(let event): return "interest-\(event.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .plan(let plan):
            if !plan.title.isEmpty { return plan.title }
            return plan.event?.title ?? "予定"
        case .visit(let visit):
            return visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
        case .interest(let event):
            return event.title.isEmpty ? "興味あり" : event.title
        }
    }

    var subtitle: String {
        switch self {
        case .plan(let plan):
            return plan.subtitle.isEmpty ? plan.event?.seriesName ?? "" : plan.subtitle
        case .visit(let visit):
            return visit.event?.seriesName ?? ""
        case .interest(let event):
            return event.seriesName
        }
    }

    var badgeText: String {
        switch self {
        case .plan: return "予定"
        case .visit: return "記録済み"
        case .interest: return "興味あり"
        }
    }

    var actionText: String {
        switch self {
        case .plan: return "予定を見る"
        case .visit: return "記録を見る"
        case .interest: return "詳細を見る"
        }
    }

    var actionIcon: String {
        switch self {
        case .plan: return "calendar"
        case .visit: return "doc.text"
        case .interest: return "chevron.right"
        }
    }

    var dateText: String {
        switch self {
        case .plan(let plan): return FavorecoDateText.compactDate(plan.startsAt)
        case .visit(let visit): return FavorecoDateText.compactDate(visit.visitedAt)
        case .interest: return ""
        }
    }

    var placeText: String {
        switch self {
        case .plan(let plan):
            return plan.venueNameSnapshot.isEmpty ? plan.placeMaster?.name ?? "" : plan.venueNameSnapshot
        case .visit(let visit):
            return visit.venueNameSnapshot.isEmpty ? visit.placeMaster?.name ?? "" : visit.venueNameSnapshot
        case .interest:
            return ""
        }
    }

    var detailText: String {
        switch self {
        case .plan(let plan):
            return plan.organizerNameSnapshot
        case .visit(let visit):
            if visit.overallRating > 0 {
                return String(format: "評価 %.1f", visit.overallRating)
            }
            return ""
        case .interest:
            return ""
        }
    }

    var event: ExperienceEvent? {
        switch self {
        case .plan(let plan): return plan.event
        case .visit(let visit): return visit.event
        case .interest(let event): return event
        }
    }

    var visit: Visit? {
        switch self {
        case .plan(let plan): return plan.visit
        case .visit(let visit): return visit
        case .interest: return nil
        }
    }
}

enum CategoryFeatureContentBuilder {
    static func priorityItems(
        category: RecordCategory,
        allPlans: [Plan],
        events: [ExperienceEvent],
        screenWorkFilter: ScreenWorkFilter,
        now: Date
    ) -> [CategoryFeatureItem] {
        let upcomingPlans = allPlans
            .filter { plan in
                !plan.isArchived
                    && plan.isUpcomingOrOngoing(at: now)
                    && (plan.category ?? plan.event?.category)?.id == category.id
                    && (category.templateKey != "movie"
                        || plan.event.map { screenWorkFilter.includes($0.screenWorkType) } != false)
            }
            .sorted { $0.startsAt < $1.startsAt }
        let plannedEventIDs = Set(upcomingPlans.compactMap { $0.event?.id })
        let interestedEvents = events
            .filter {
                $0.stateKey == "interested"
                    && !plannedEventIDs.contains($0.id)
                    && (category.templateKey != "movie" || screenWorkFilter.includes($0.screenWorkType))
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        let planItems = upcomingPlans.map(CategoryFeatureItem.plan)
        let interestItems = interestedEvents.map(CategoryFeatureItem.interest)
        return Array((planItems + interestItems).prefix(10))
    }

    static func metrics(
        category: RecordCategory,
        snapshot: CategoryTopSnapshot,
        visits: [Visit],
        calendar: Calendar,
        currentYear: Int
    ) -> [MiniStatisticsItem] {
        let yearVisits = visits.filter { calendar.component(.year, from: $0.visitedAt) == currentYear }
        let ratedYearVisits = yearVisits.filter { $0.overallRating > 0 }
        let averageText: String = {
            guard !ratedYearVisits.isEmpty else { return "-" }
            let average = ratedYearVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedYearVisits.count)
            return String(format: "%.1f", average)
        }()
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        let movieReviewText: String = {
            guard !ratedVisits.isEmpty else { return "-" }
            let average = ratedVisits.reduce(0) { $0 + $1.overallRating } / Double(ratedVisits.count)
            return String(format: "%.1f", average)
        }()

        switch category.templateKey {
        case "movie":
            return [
                MiniStatisticsItem(title: "総鑑賞数", value: "\(snapshot.visitCount)", unit: "作品", icon: "movieclapper"),
                MiniStatisticsItem(title: "年間数", value: "\(yearVisits.count)", unit: "作品", icon: "calendar"),
                MiniStatisticsItem(title: "観たい", value: "\(snapshot.interestedEventCount)", unit: "作品", icon: "bookmark"),
                MiniStatisticsItem(title: "レビュー", value: movieReviewText, unit: movieReviewText == "-" ? "" : "点", icon: "text.bubble"),
            ]
        case "book":
            let favoriteCount = visits.filter { $0.overallRating >= 4.5 }.count
            return [
                MiniStatisticsItem(title: "総冊数", value: "\(snapshot.eventCount)", unit: "冊", icon: "books.vertical"),
                MiniStatisticsItem(title: "年間冊数", value: "\(yearVisits.count)", unit: "冊", icon: "calendar"),
                MiniStatisticsItem(title: "年間評価", value: averageText, unit: "", icon: "star"),
                MiniStatisticsItem(title: "お気に入り", value: "\(favoriteCount)", unit: "冊", icon: "bookmark"),
            ]
        case "theme_park":
            let repeatCount = repeatVisitCount(in: visits)
            return [
                MiniStatisticsItem(title: "総来園数", value: "\(snapshot.visitCount)", unit: "回", icon: "ticket"),
                MiniStatisticsItem(title: "年間来園", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "件", icon: "bookmark"),
            ]
        case "nature_living":
            let repeatCount = repeatVisitCount(in: visits)
            let encounteredCount = encounteredItemCount(in: visits)
            return [
                MiniStatisticsItem(title: "総訪問数", value: "\(snapshot.visitCount)", unit: "回", icon: "pawprint"),
                MiniStatisticsItem(title: "年間訪問", value: "\(yearVisits.count)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "リピート", value: "\(repeatCount)", unit: "回", icon: "arrow.triangle.2.circlepath"),
                MiniStatisticsItem(title: "出会った数", value: encounteredCount == 0 ? "-" : "\(encounteredCount)", unit: "種", icon: "pawprint"),
            ]
        case "outing_facility":
            return [
                MiniStatisticsItem(title: "施設", value: "\(snapshot.eventCount)", unit: "件", icon: "questionmark.folder"),
                MiniStatisticsItem(title: "訪問", value: "\(snapshot.visitCount)", unit: "回", icon: "calendar"),
                MiniStatisticsItem(title: "気になる", value: "\(snapshot.interestedEventCount)", unit: "件", icon: "bookmark"),
            ]
        default:
            return [
                MiniStatisticsItem(title: "対象", value: "\(snapshot.eventCount)", unit: "", icon: "rectangle.stack"),
                MiniStatisticsItem(title: "記録", value: "\(snapshot.visitCount)", unit: "", icon: "sparkles.rectangle.stack"),
                MiniStatisticsItem(title: "年間", value: "\(yearVisits.count)", unit: "", icon: "calendar"),
            ]
        }
    }

    private static func repeatVisitCount(in visits: [Visit]) -> Int {
        let grouped = Dictionary(grouping: visits) { visit in
            let venue = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !venue.isEmpty { return venue }
            return visit.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? visit.id.uuidString
        }
        return grouped.values.reduce(0) { total, groupedVisits in
            groupedVisits.count > 1 ? total + groupedVisits.count : total
        }
    }

    private static func encounteredItemCount(in visits: [Visit]) -> Int {
        let labels = ["出会った", "生きもの", "生き物", "動物", "魚", "種類"]
        var names = Set<String>()
        for visit in visits {
            let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
            for entry in fields.advancedEntries {
                guard labels.contains(where: { entry.trimmedLabel.contains($0) }) else { continue }
                entry.trimmedValue
                    .components(separatedBy: CharacterSet(charactersIn: ",、/\n "))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .forEach { names.insert($0) }
            }
        }
        return names.count
    }
}

struct PerformanceTicketManagementPlanCard: View {
    let plan: Plan
    let category: RecordCategory
    let tint: Color
    let onOpenPlan: (UUID) -> Void
    let onMarkAcquired: (TicketAttempt) -> Void

    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false
    @State private var isShowingAddAttempt = false
    @State private var editingProgressAttempt: TicketAttempt?
    @State private var quickActionAttempt: TicketAttempt?

    private let posterWidth: CGFloat = 116

    private var isLive: Bool { category.templateKey == "live" }

    private var posterHeight: CGFloat {
        let ratio = isLive
            ? CGFloat(EyecatchAspectRatio.resolved(for: displayPlan.event).value)
            : CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
        return posterWidth / ratio
    }

    private var primaryTextColor: Color {
        isLive ? LiveCategoryStyle.mist : TheaterCategoryStyle.ivory
    }

    private var secondaryTextColor: Color {
        isLive ? LiveCategoryStyle.mist.opacity(0.68) : TheaterCategoryStyle.ivory.opacity(0.68)
    }

    private var cardBackground: Color {
        isLive ? LiveCategoryStyle.tileBackground : TheaterCategoryStyle.tileBackground
    }

    private var decorativeColor: Color {
        isLive ? tint : TheaterCategoryStyle.gold
    }

    private var actionColor: Color {
        isLive ? tint : TheaterCategoryStyle.ticketActionRose
    }

    private var titleFont: Font {
        isLive
            ? FavorecoTypography.jpSans(20, weight: .bold, relativeTo: .title3)
            : FavorecoTypography.jpSerif(20, weight: .semibold, relativeTo: .title3)
    }

    init(
        plan: Plan,
        category: RecordCategory,
        tint: Color,
        onOpenPlan: @escaping (UUID) -> Void,
        onMarkAcquired: @escaping (TicketAttempt) -> Void
    ) {
        self.plan = plan
        self.category = category
        self.tint = tint
        self.onOpenPlan = onOpenPlan
        self.onMarkAcquired = onMarkAcquired
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    private var displayPlan: Plan {
        currentPlans.first ?? plan
    }

    private var displayTitle: String {
        let eventTitle = displayPlan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventTitle.isEmpty { return eventTitle }
        let planTitle = displayPlan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return planTitle.isEmpty ? "予定" : planTitle
    }

    private var displayVenue: String {
        let snapshot = displayPlan.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshot.isEmpty { return snapshot }
        return displayPlan.placeMaster?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var activeAttempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            allAttempts.filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
            }
        )
    }

    private var allAttempts: [TicketAttempt] {
        TicketAttemptPresentationOrder.sorted(
            (displayPlan.ticketAttempts ?? []).filter { !$0.isArchived }
        )
    }

    private var hasAcquiredTicket: Bool {
        TicketAcquisitionState.hasAcquiredTicket(in: allAttempts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    onOpenPlan(displayPlan.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CategoryFeaturePoster(
                            item: .plan(displayPlan),
                            fallbackIcon: category.iconSymbol,
                            tint: tint
                        )
                        .frame(width: posterWidth, height: posterHeight)
                        .clipped()

                        VStack(alignment: .leading, spacing: 7) {
                            if hasUnacquiredTicket {
                                ticketAcquisitionChip
                            }

                            Text(displayTitle)
                                .font(titleFont)
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(3)

                            if displayPlan.hasConfirmedSchedule {
                                FavorecoIconLabel(
                                    FavorecoDateText.compactDate(displayPlan.startsAt),
                                    systemImage: "calendar",
                                    iconSize: 17
                                )
                                    .font(FavorecoTypography.body)
                                    .foregroundStyle(primaryTextColor.opacity(0.78))
                                    .lineLimit(1)

                                FavorecoIconLabel(
                                    "開演 \(FavorecoDateText.time(displayPlan.startsAt))",
                                    systemImage: "clock",
                                    iconSize: 13
                                )
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                            } else {
                                FavorecoIconLabel(
                                    "参加日未定",
                                    systemImage: "calendar.badge.exclamationmark",
                                    iconSize: 15
                                )
                                .font(FavorecoTypography.bodyStrong)
                                .foregroundStyle(TicketProgressColorPalette.scheduleUndated)
                                .lineLimit(1)
                            }

                            if !displayVenue.isEmpty {
                                FavorecoIconLabel(
                                    displayVenue,
                                    systemImage: "mappin.and.ellipse",
                                    iconSize: 13
                                )
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.trailing, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    isShowingEditPlan = true
                } label: {
                    FavorecoIcon(systemName: "pencil", size: 12)
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.09), in: Circle())
                        .overlay {
                            Circle().stroke(tint.opacity(0.38), lineWidth: 0.7)
                        }
                }
                .buttonStyle(.plain)
                .disabled(currentPlans.isEmpty)
                .accessibilityLabel("予定を編集")
            }

            if !activeAttempts.isEmpty {
                Divider()
                    .overlay(decorativeColor.opacity(0.46))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Ticket Progress")
                        .font(FavorecoTypography.latinDisplay(17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(decorativeColor)

                    ForEach(Array(activeAttempts.enumerated()), id: \.element.id) { index, attempt in
                        VStack(alignment: .leading, spacing: 6) {
                            if attempt.statusKey == "issued" {
                                ZStack {
                                    Button {
                                        quickActionAttempt = attempt
                                    } label: {
                                        acquiredTicketStatus
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("進捗管理を開きます")

                                    HStack {
                                        Spacer(minLength: 0)
                                        progressEditButton(for: attempt)
                                    }
                                }
                            } else {
                                HStack(spacing: 6) {
                                    performanceProgressMetadata(for: attempt)
                                    Spacer(minLength: 6)
                                    compactMarkAcquiredButton(for: attempt)
                                    progressEditButton(for: attempt)
                                }
                            }

                            if attempt.statusKey != "issued" {
                                let item = CategoryTicketProgressItem(
                                    plan: displayPlan,
                                    attempt: attempt
                                )
                                Button {
                                    quickActionAttempt = attempt
                                } label: {
                                    TicketProgressTimelineView(
                                        stages: item.stages,
                                        currentIndex: item.currentStageIndex,
                                        nodeBackground: cardBackground,
                                        secondaryTextColor: secondaryTextColor.opacity(0.92),
                                        completedTint: TicketProgressColorPalette.completedNeutral
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("進捗管理を開きます")
                            }

                            if index < activeAttempts.count - 1 {
                                Divider()
                                    .overlay(decorativeColor.opacity(0.22))
                            }
                        }
                    }
                }
            }

            Divider()
                .overlay(decorativeColor.opacity(0.46))

            HStack(spacing: 7) {
                Button {
                    isShowingAddAttempt = true
                } label: {
                    performanceActionLabel("チケット追加", systemImage: "ticket")
                }
                .buttonStyle(.plain)
                .disabled(currentPlans.isEmpty)

                Button {
                    onOpenPlan(displayPlan.id)
                } label: {
                    performanceActionLabel("詳細", systemImage: "book.pages")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(decorativeColor.opacity(0.62), lineWidth: 0.75)
        }
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingAddAttempt) {
            if let currentPlan = currentPlans.first {
                EditTicketAttemptView(plan: currentPlan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
        .sheet(item: $editingProgressAttempt) { attempt in
            EditTicketAttemptView(plan: displayPlan, attempt: attempt, prioritizesDates: true)
        }
        .sheet(item: $quickActionAttempt) { attempt in
            TicketQuickActionSheet(attempt: attempt)
        }
    }

    private func theaterChip(_ title: String, isEmphasized: Bool) -> some View {
        Text(title)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(isEmphasized ? tint : TheaterCategoryStyle.ivory.opacity(0.78))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                isEmphasized ? tint.opacity(0.12) : Color.white.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        isEmphasized ? tint.opacity(0.44) : TheaterCategoryStyle.ivory.opacity(0.18),
                        lineWidth: 0.7
                    )
            }
    }

    private var ticketAcquisitionChip: some View {
        let color = isLive ? tint : Color(red: 0.94, green: 0.43, blue: 0.52)
        return Text("チケット未取得")
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(color.opacity(0.38), lineWidth: 0.7)
            }
    }

    private var hasUnacquiredTicket: Bool {
        !hasAcquiredTicket || activeAttempts.contains { $0.statusKey != "issued" }
    }

    private func compactMarkAcquiredButton(for attempt: TicketAttempt) -> some View {
        Button {
            onMarkAcquired(attempt)
        } label: {
            Text("取得済みにする")
                .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    TicketProgressColorPalette.color(for: .acquired).opacity(0.76),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(TicketProgressColorPalette.color(for: .acquired), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("チケットを取得済みにする")
        .accessibilityHint("このチケットを受取済みに更新します")
    }

    @ViewBuilder
    private func performanceProgressMetadata(for attempt: TicketAttempt) -> some View {
        HStack(spacing: 5) {
            let entryRoute = TicketEntryRouteDefinition.name(for: attempt.entryRouteKey)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !entryRoute.isEmpty {
                performanceProgressMetadataChip(
                    entryRoute,
                    isEntryRoute: true
                )
            }

            let ticketSite = attempt.ticketSite.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ticketSite.isEmpty {
                performanceProgressMetadataChip(
                    ticketSite,
                    isEntryRoute: false
                )
            }
        }
    }

    private var acquiredTicketStatus: some View {
        FavorecoIconLabel(
            "チケット取得済み",
            systemImage: "checkmark.circle",
            iconSize: 15
        )
        .font(FavorecoTypography.captionStrong)
        .foregroundStyle(primaryTextColor)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(
            TicketProgressColorPalette.surface(for: .acquired).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(TicketProgressColorPalette.color(for: .acquired), lineWidth: 0.8)
        }
        .accessibilityLabel("チケット取得済み")
    }

    private func progressEditButton(for attempt: TicketAttempt) -> some View {
        Button {
            editingProgressAttempt = attempt
        } label: {
            FavorecoIcon(systemName: "pencil", size: 16)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("このチケットスケジュールの日付を編集")
    }

    private func performanceProgressMetadataChip(
        _ title: String,
        isEntryRoute: Bool
    ) -> some View {
        let foreground = isEntryRoute
            ? TicketProgressColorPalette.entryRouteChipText
            : TicketProgressColorPalette.metadataChipText
        let border = isEntryRoute
            ? TicketProgressColorPalette.entryRouteChipBorder
            : TicketProgressColorPalette.metadataChipBorder

        return Text(title)
            .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
                TicketProgressColorPalette.metadataChipSurface.opacity(0.86),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(border.opacity(isEntryRoute ? 0.78 : 0.24), lineWidth: 0.7)
            }
    }

    private func performanceActionLabel(_ title: String, systemImage: String) -> some View {
        FavorecoIconLabel(title, systemImage: systemImage, iconSize: 16)
            .font(FavorecoTypography.captionStrong)
            .foregroundStyle(actionColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .padding(.horizontal, 5)
            .overlay {
                Capsule()
                    .stroke(actionColor.opacity(0.86), lineWidth: 0.8)
            }
    }
}

struct CategoryComingUpRow: View {
    let plan: Plan
    let category: RecordCategory
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    private var activeAttempt: TicketAttempt? {
        guard let attempts = plan.ticketAttempts else { return nil }
        return TicketAttemptPresentationOrder.sorted(
            attempts.filter {
                !$0.isArchived
                    && !["interested", "lost", "attended", "skipped"].contains($0.statusKey)
            }
        ).first
    }

    var body: some View {
        if let activeAttempt {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(spacing: 0) {
                        Text(FavorecoDateText.monthDay(plan.startsAt))
                            .font(FavorecoTypography.latinDisplay(24, weight: .semibold, relativeTo: .title2))
                            .monospacedDigit()
                        Text(FavorecoDateText.weekdayName(plan.startsAt))
                            .font(FavorecoTypography.jpSerif(12, weight: .semibold, relativeTo: .caption))
                    }
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 50)

                    CategoryFeaturePoster(
                        item: .plan(plan),
                        fallbackIcon: category.iconSymbol,
                        tint: tint
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(TicketStatusDefinition.name(for: activeAttempt.statusKey))
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(tint)
                        Text(plan.title.isEmpty ? "予定" : plan.title)
                            .font(FavorecoTypography.jpSerif(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
                        if !plan.venueNameSnapshot.isEmpty {
                            Text(plan.venueNameSnapshot)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                let item = CategoryTicketProgressItem(plan: plan, attempt: activeAttempt)
                TicketProgressTimelineView(
                    stages: item.stages,
                    currentIndex: item.currentStageIndex,
                    nodeBackground: cardBackground,
                    secondaryTextColor: secondaryTextColor,
                    completedTint: TicketProgressColorPalette.completedNeutral
                )
            }
            .padding(10)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 0.75)
            }
        } else {
            FavorecoComingUpRow(
                date: plan.startsAt,
                categoryName: category.name,
                title: plan.title.isEmpty ? "予定" : plan.title,
                venue: plan.venueNameSnapshot,
                tint: tint,
                isTheater: isTheater,
                isLive: isLive
            ) {
                CategoryFeaturePoster(
                    item: .plan(plan),
                    fallbackIcon: category.iconSymbol,
                    tint: tint
                )
            }
        }
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory }
        if isLive { return LiveCategoryStyle.mist }
        return .primary
    }

    private var secondaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.62) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.58) }
        return .secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.82)
    }
}

struct CategoryScheduleEmptyRow: View {
    let icon: String
    let title: String
    let actionTitle: String?
    let tint: Color
    let isTheater: Bool
    let isLive: Bool

    var body: some View {
        HStack(spacing: 12) {
            FavorecoIcon(systemName: icon, size: 17)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: Circle())

            Text(title)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 8)

            if let actionTitle {
                Text(actionTitle)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isTheater || isLive ? 0.34 : 0.16), lineWidth: 0.75)
        }
    }

    private var primaryTextColor: Color {
        if isTheater { return TheaterCategoryStyle.ivory.opacity(0.78) }
        if isLive { return LiveCategoryStyle.mist.opacity(0.78) }
        return Color.secondary
    }

    private var cardBackground: Color {
        if isTheater { return TheaterCategoryStyle.tileBackground }
        if isLive { return LiveCategoryStyle.tileBackground }
        return Color(.secondarySystemGroupedBackground).opacity(0.64)
    }
}

struct CategoryFeatureCarousel: View {
    let title: String
    let japaneseTitle: String
    let emptyMessage: String
    let items: [CategoryFeatureItem]
    @Binding var selectedIndex: Int
    let tint: Color
    let fallbackIcon: String
    let onOpenPlan: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                LayeredCategorySectionTitle(
                    englishTitle: title,
                    japaneseTitle: japaneseTitle,
                    foregroundColor: .primary
                )

                Spacer(minLength: 0)

            }

            if items.isEmpty {
                Button(action: onAdd) {
                    CategoryFeatureEmptyCard(message: emptyMessage, tint: tint, fallbackIcon: fallbackIcon)
                }
                .buttonStyle(.plain)
            } else if items.count == 1 {
                CategoryFeatureCardLink(
                    item: items[0],
                    tint: tint,
                    fallbackIcon: fallbackIcon,
                    onOpenPlan: onOpenPlan,
                    onOpenVisit: onOpenVisit
                )
            } else {
                GeometryReader { geometry in
                    let cardWidth = max(0, geometry.size.width - 36)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                CategoryFeatureCardLink(
                                    item: item,
                                    tint: tint,
                                    fallbackIcon: fallbackIcon,
                                    onOpenPlan: onOpenPlan,
                                    onOpenVisit: onOpenVisit
                                )
                                    .frame(width: cardWidth, alignment: .top)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 18, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: selectedPosition)
                }
                .frame(height: CategoryFeatureHeroMetrics.cardHeight)

                HStack(spacing: 7) {
                    ForEach(items.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? tint : Color.secondary.opacity(0.28))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var selectedPosition: Binding<Int?> {
        Binding(
            get: { selectedIndex },
            set: { newValue in
                if let newValue {
                    selectedIndex = newValue
                }
            }
        )
    }
}

private struct CategoryFeatureCardLink: View {
    let item: CategoryFeatureItem
    let tint: Color
    let fallbackIcon: String
    let onOpenPlan: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void

    var body: some View {
        switch item {
        case .plan(let plan):
            CategoryFeaturePlanCard(
                item: item,
                plan: plan,
                tint: tint,
                fallbackIcon: fallbackIcon,
                onOpen: { onOpenPlan(plan.id) }
            )
        case .visit(let visit):
            Button {
                onOpenVisit(visit.id)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon) {
                    CategoryFeatureSingleActionLabel(
                        title: item.actionText,
                        systemImage: item.actionIcon,
                        tint: tint
                    )
                }
            }
            .buttonStyle(.plain)
        case .interest(let event):
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                CategoryFeatureCard(item: item, tint: tint, fallbackIcon: fallbackIcon) {
                    CategoryFeatureSingleActionLabel(
                        title: item.actionText,
                        systemImage: item.actionIcon,
                        tint: tint
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CategoryFeaturePlanCard: View {
    let item: CategoryFeatureItem
    let plan: Plan
    let tint: Color
    let fallbackIcon: String
    let onOpen: () -> Void
    @Query private var currentPlans: [Plan]
    @State private var isShowingEditPlan = false

    init(
        item: CategoryFeatureItem,
        plan: Plan,
        tint: Color,
        fallbackIcon: String,
        onOpen: @escaping () -> Void
    ) {
        self.item = item
        self.plan = plan
        self.tint = tint
        self.fallbackIcon = fallbackIcon
        self.onOpen = onOpen
        let planID = plan.id
        _currentPlans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        CategoryFeatureCard(
            item: item,
            tint: tint,
            fallbackIcon: fallbackIcon,
            onOpen: onOpen
        ) {
            HStack(spacing: 6) {
                Button(action: onOpen) {
                    CategoryFeatureActionLabel(
                        title: "予定詳細",
                        systemImage: "book.pages",
                        tint: tint
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    isShowingEditPlan = true
                } label: {
                    CategoryFeatureActionLabel(
                        title: "編集",
                        systemImage: "pencil",
                        tint: tint,
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)
                .frame(width: 58)
                .disabled(currentPlans.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingEditPlan) {
            if let currentPlan = currentPlans.first {
                AddTicketPlanView(plan: currentPlan, entryMode: .plan)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
    }
}

private struct CategoryFeatureCard<Actions: View>: View {
    let item: CategoryFeatureItem
    let tint: Color
    let fallbackIcon: String
    let onOpen: (() -> Void)?
    let actions: Actions

    init(
        item: CategoryFeatureItem,
        tint: Color,
        fallbackIcon: String,
        onOpen: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.item = item
        self.tint = tint
        self.fallbackIcon = fallbackIcon
        self.onOpen = onOpen
        self.actions = actions()
    }

    var body: some View {
        CategoryFeatureHeroLayout(posterAspectRatio: posterAspectRatio) {
            interactivePoster

            VStack(alignment: .leading, spacing: 4) {
                interactiveDetails

                Spacer(minLength: 0)

                actions
            }
        }
        .frame(height: CategoryFeatureHeroMetrics.contentHeight, alignment: .top)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.75)
        }
    }

    private var posterAspectRatio: CGFloat {
        if let event = item.event {
            return CGFloat(EyecatchAspectRatio.resolved(for: event).value)
        }
        return 0.7
    }

    @ViewBuilder
    private var interactivePoster: some View {
        let poster = CategoryFeaturePoster(
            item: item,
            fallbackIcon: fallbackIcon,
            tint: tint
        )
        if let onOpen {
            poster
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
        } else {
            poster
        }
    }

    @ViewBuilder
    private var interactiveDetails: some View {
        if let onOpen {
            detailsContent
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
        } else {
            detailsContent
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.badgeText)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(tint)

            Text(item.title)
                .font(FavorecoTypography.jpSerif(18.5, weight: .bold, relativeTo: .headline))
                .lineSpacing(-2)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.primary.opacity(0.68))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if !item.dateText.isEmpty {
                FavorecoIconLabel(item.dateText, systemImage: "calendar", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.placeText.isEmpty {
                FavorecoIconLabel(item.placeText, systemImage: "mappin.and.ellipse", iconSize: 13)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.detailText.isEmpty {
                Text(item.detailText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryFeatureActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isPrimary: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            FavorecoIcon(systemName: systemImage, size: isPrimary ? 12 : 10.5)
            Text(title)
        }
            .font(FavorecoTypography.jpSans(isPrimary ? 12 : 10.5, weight: isPrimary ? .semibold : .medium, relativeTo: .caption))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .overlay {
                Capsule().stroke(tint.opacity(0.48), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private struct CategoryFeatureSingleActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        CategoryFeatureActionLabel(title: title, systemImage: systemImage, tint: tint)
    }
}

private enum CategoryFeatureHeroMetrics {
    static let contentHeight: CGFloat = 224
    static let cardHeight: CGFloat = contentHeight + 24
}

private struct CategoryFeatureHeroLayout: Layout {
    let posterAspectRatio: CGFloat
    private let posterFraction: CGFloat = 0.45
    private let maximumPosterWidth: CGFloat = 152.5
    private let spacing: CGFloat = 14

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 340
        let availableWidth = max(0, width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.55, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio
        let detailsSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: detailsWidth, height: posterHeight)
        )
        return CGSize(width: width, height: max(posterHeight, detailsSize.height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let availableWidth = max(0, bounds.width - spacing)
        let posterWidth = min(maximumPosterWidth, availableWidth * posterFraction)
        let detailsWidth = availableWidth - posterWidth
        let safeRatio = max(0.55, posterAspectRatio)
        let posterHeight = posterWidth / safeRatio

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: posterWidth, height: posterHeight)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + posterWidth + spacing, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailsWidth, height: max(posterHeight, bounds.height))
        )
    }
}

struct CategoryFeaturePoster: View {
    let item: CategoryFeatureItem
    let fallbackIcon: String
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            if isTheater {
                TheaterPosterArtwork(
                    reference: item.event.map { .event($0.id) },
                    backgroundColor: tint.opacity(0.08)
                ) { size in
                    CategoryDefaultArtworkImage(templateKey: "theater", displaySize: size)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ThumbnailImage(
                    reference: item.event.map { .event($0.id) },
                    displaySize: geometry.size,
                    contentMode: usesEyecatchFill ? .fill : .fit
                ) {
                    CategoryDefaultArtworkImage(
                        templateKey: item.event?.category?.templateKey ?? "",
                        displaySize: geometry.size
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: usesPosterFill ? 0 : 7, style: .continuous))
            }
        }
    }

    private var isTheater: Bool {
        item.event?.category?.templateKey == "theater"
    }

    private var usesPosterFill: Bool {
        EyecatchAspectRatio.usesPosterFill(for: item.event?.category)
    }

    private var usesEyecatchFill: Bool {
        EyecatchAspectRatio.usesEyecatchFill(for: item.event?.category)
    }
}

private struct CategoryFeatureEmptyCard: View {
    let message: String
    let tint: Color
    let fallbackIcon: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                tint.opacity(0.14)
                FavorecoIcon(systemName: fallbackIcon, size: 32)
                    .foregroundStyle(tint)
            }
            .frame(width: 104, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("まだ記録・予定がありません")
                    .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title3))
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FavorecoIconLabel("追加する", systemImage: "plus.circle.fill", iconSize: 13)
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
            }
            Spacer()
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: CategoryFeatureHeroMetrics.cardHeight,
            maxHeight: CategoryFeatureHeroMetrics.cardHeight
        )
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.75)
        }
    }
}

struct CategoryFeatureMetricsGrid: View {
    let metrics: [MiniStatisticsItem]
    let tint: Color
    var backgroundColor: Color = Color(.systemBackground)
    var primaryTextColor: Color = .primary
    var secondaryTextColor: Color = .secondary
    var borderColor: Color? = nil
    var dividerColor: Color? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(dividerColor ?? tint.opacity(0.20))
                        .frame(width: 1, height: 76)
                }

                VStack(spacing: 6) {
                    FavorecoIcon(systemName: metric.icon, size: 12)
                        .foregroundStyle(tint)
                    Text(metric.title)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(metric.value)
                            .font(FavorecoTypography.latinDisplay(24, weight: .bold, relativeTo: .title3))
                            .foregroundStyle(primaryTextColor)
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
            }
        }
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor ?? tint.opacity(0.16), lineWidth: 0.75)
        }
    }
}
