//
//  HomeView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var events: [ExperienceEvent]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.createdAt, order: .reverse) private var inboxItems: [InboxItem]
    @Query(sort: \Plan.startsAt, order: .forward) private var plans: [Plan]
    @Query(sort: \TicketAttempt.updatedAt, order: .reverse) private var ticketAttempts: [TicketAttempt]
    @Query(sort: \TicketAccount.expiryDate, order: .forward) private var ticketAccounts: [TicketAccount]
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsAttention = true
    @AppStorage(AppStorageKeys.showsHomeExperienceGallery) private var showsExperienceGallery = true
    @AppStorage(AppStorageKeys.showsHomeInbox) private var showsInbox = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsStatsSummary = false
    @AppStorage(AppStorageKeys.showsHomeFavorites) private var showsFavorites = false
    @AppStorage(AppStorageKeys.profileImageData) private var profileImageData = Data()
    @AppStorage(AppStorageKeys.debugHomeCategoryLayout) private var categoryLayoutModeRaw = HomeCategoryLayoutMode.horizontal.rawValue
    @State private var isShowingSettings = false
    @State private var isShowingAttentionList = false
    @State private var selectedUpcomingPlanIndex = 0

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var categoryLayoutMode: HomeCategoryLayoutMode {
        HomeCategoryLayoutMode(rawValue: categoryLayoutModeRaw) ?? .horizontal
    }

    private var unresolvedInboxItems: [InboxItem] {
        inboxItems.filter { $0.state == "unresolved" }
    }

    private var interestedEvents: [ExperienceEvent] {
        events.filter { !$0.isArchived && $0.stateKey == "interested" }
    }

    private var visibleVisits: [Visit] {
        visits.filter { $0.event?.isArchived != true }
    }

    private var recentVisits: [Visit] {
        Array(visibleVisits.prefix(8))
    }

    private var upcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingItemCount: Int {
        upcomingPlans.count
    }

    private var currentYearVisitCount: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return visibleVisits.filter { calendar.component(.year, from: $0.visitedAt) == year }.count
    }

    private var attentionItems: [HomeAttentionItem] {
        var items = ticketAttentionItems

        if items.count < 5 {
            items.append(contentsOf: membershipAttentionItems.prefix(5 - items.count))
        }

        return Array(items.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.dueDate < rhs.dueDate
        }.prefix(5))
    }

    private var ticketAttentionItems: [HomeAttentionItem] {
        ticketAttempts
            .filter { attempt in
                !attempt.isArchived
                    && attempt.plan?.isArchived != true
                    && !["lost", "attended", "skipped"].contains(attempt.statusKey)
            }
            .flatMap { ticketAttentionItems(for: $0) }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.dueDate < rhs.dueDate
            }
            .prefix(5)
            .map { $0 }
    }

    private var membershipAttentionItems: [HomeAttentionItem] {
        let now = Date()
        let warningLimit = Calendar.current.date(byAdding: .day, value: 45, to: now) ?? now

        return ticketAccounts
            .filter { account in
                !account.isArchived
                    && account.renewalNotify
                    && account.expiryDate != Date.distantPast
                    && account.expiryDate >= now
                    && account.expiryDate <= warningLimit
            }
            .map { account in
                HomeAttentionItem(
                    icon: "person.text.rectangle",
                    title: account.serviceName.isEmpty ? "会員期限" : account.serviceName,
                    subtitle: "期限 \(attentionDateFormatter.string(from: account.expiryDate))",
                    dueDate: account.expiryDate,
                    tint: Color(hex: account.colorHex),
                    priority: 8
                )
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    private func ticketAttentionItems(for attempt: TicketAttempt) -> [HomeAttentionItem] {
        let now = Date()
        let plan = attempt.plan
        let title = plan?.title.isEmpty == false ? plan?.title ?? "予定" : "予定"
        let tint = themePalette.categoryColor(hex: plan?.category?.colorHex ?? "#147C88")
        var items: [HomeAttentionItem] = []

        if attempt.saleStartAt > now {
            items.append(ticketAttention(
                icon: "ticket",
                label: "申込開始",
                title: title,
                date: attempt.saleStartAt,
                plan: plan,
                tint: tint,
                priority: 12
            ))
        }

        if attempt.applyDeadlineAt > now {
            items.append(ticketAttention(
                icon: "hourglass",
                label: "申込締切",
                title: title,
                date: attempt.applyDeadlineAt,
                plan: plan,
                tint: .red,
                priority: 1
            ))
        }

        if attempt.resultAnnounceAt > now {
            items.append(ticketAttention(
                icon: "checkmark.seal",
                label: "当落発表",
                title: title,
                date: attempt.resultAnnounceAt,
                plan: plan,
                tint: .purple,
                priority: 5
            ))
        }

        if attempt.paymentDeadlineAt > now {
            items.append(ticketAttention(
                icon: "yensign.circle",
                label: "入金締切",
                title: title,
                date: attempt.paymentDeadlineAt,
                plan: plan,
                tint: .orange,
                priority: 2
            ))
        }

        if attempt.issueStartAt > now {
            items.append(ticketAttention(
                icon: "ticket.fill",
                label: "発券開始",
                title: title,
                date: attempt.issueStartAt,
                plan: plan,
                tint: .teal,
                priority: 10
            ))
        }

        return items
    }

    private func ticketAttention(
        icon: String,
        label: String,
        title: String,
        date: Date,
        plan: Plan?,
        tint: Color,
        priority: Int
    ) -> HomeAttentionItem {
        HomeAttentionItem(
            icon: icon,
            title: title,
            subtitle: "\(label) \(attentionDateFormatter.string(from: date))",
            dueDate: date,
            plan: plan,
            tint: tint,
            priority: priority
        )
    }

    private var attentionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    upcomingPlansSection

                    if showsAttention {
                        attentionSection
                    }

                    // 実機比較中: 横1段 / 4列を設定から切り替える。
                    if showsCategories {
                        categorySection
                    }

                    if showsExperienceGallery && !recentVisits.isEmpty {
                        experienceGallerySection
                    }

                    if showsInbox && (!interestedEvents.isEmpty || !unresolvedInboxItems.isEmpty) {
                        inboxSection
                    }

                    if showsRecentRecords && !visibleVisits.isEmpty {
                        recentSection
                    }

                    if showsStatsSummary && !visibleVisits.isEmpty {
                        statsSummarySection
                    }

                    if showsFavorites {
                        favoritesSection
                    }

                    crossGenreMiniStats

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("favoreco")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        ProfileAvatarView(data: profileImageData, size: 30)
                    }
                    .accessibilityLabel("マイ・設定")
                }
            }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingAttentionList) {
            HomeAttentionListView(items: attentionItems)
        }
        .task {
            try? LegacyInboxMigrationService.migrateIfNeeded(in: modelContext)
        }
        }
    }

    private var crossGenreMiniStats: some View {
        HStack(spacing: 10) {
            HomeMiniStatCell(
                value: "\(upcomingItemCount)",
                label: "今後の予定",
                icon: "calendar.badge.clock",
                tint: Color(hex: "#147C88")
            )
            HomeMiniStatCell(
                value: "\(currentYearVisitCount)",
                label: "今年の記録",
                icon: "sparkles.rectangle.stack",
                tint: Color(hex: "#8B2F45")
            )
            HomeMiniStatCell(
                value: "\(visibleVisits.count)",
                label: "総記録数",
                icon: "chart.bar.fill",
                tint: Color(hex: "#B8792F")
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var upcomingPlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("次の予定")
                    .font(FavorecoTypography.sectionTitle)

                Spacer()

                if !upcomingPlans.isEmpty {
                    Button("予定一覧") {
                        NotificationCenter.default.post(name: .openFavorecoPlanList, object: nil)
                    }
                    .font(FavorecoTypography.captionStrong)
                }
            }

            switch upcomingPlans.count {
            case 0:
                VStack(alignment: .leading, spacing: 12) {
                    EmptyStateRow(
                        icon: "calendar.badge.plus",
                        title: "次の予定はありません",
                        message: "行きたい作品や場所が決まったら、予定を立てておけます。"
                    )

                    Button {
                        NotificationCenter.default.post(name: .openFavorecoPlanCreation, object: nil)
                    } label: {
                        Label("予定を立てる", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case 1:
                NavigationLink {
                    PlanDetailView(plan: upcomingPlans[0])
                } label: {
                    HomeUpcomingPlanCard(plan: upcomingPlans[0])
                }
                .buttonStyle(.plain)

            default:
                TabView(selection: $selectedUpcomingPlanIndex) {
                    ForEach(Array(upcomingPlans.enumerated()), id: \.element.id) { index, plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            HomeUpcomingPlanCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 156)

                Text("\(min(selectedUpcomingPlanIndex + 1, upcomingPlans.count)) / \(upcomingPlans.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("予定 \(min(selectedUpcomingPlanIndex + 1, upcomingPlans.count))件目、全\(upcomingPlans.count)件")
            }
        }
        .onChange(of: upcomingPlans.count) { _, count in
            if count == 0 {
                selectedUpcomingPlanIndex = 0
            } else if selectedUpcomingPlanIndex >= count {
                selectedUpcomingPlanIndex = count - 1
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ジャンル", count: visibleCategories.count)

            if visibleCategories.isEmpty {
                EmptyStateRow(
                    icon: "square.grid.2x2",
                    title: "何もありません",
                    message: "設定からジャンルを選び直すと、記録の入口が表示されます。"
                )
            } else if categoryLayoutMode == .horizontal {
                horizontalCategoryLayout
            } else {
                gridCategoryLayout
            }
        }
    }

    private var horizontalCategoryLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                categoryLinks
            }
            .padding(.trailing, 20)
        }
        .scrollClipDisabled()
        .accessibilityLabel("ジャンル一覧 横スクロール")
    }

    private var gridCategoryLayout: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 8), count: 4),
            alignment: .leading,
            spacing: 12
        ) {
            categoryLinks
        }
        .accessibilityLabel("ジャンル一覧 4列表示")
    }

    @ViewBuilder
    private var categoryLinks: some View {
        ForEach(visibleCategories) { category in
            NavigationLink {
                CategoryTopView(category: category)
            } label: {
                HomeCategoryShortcut(category: category)
            }
            .buttonStyle(.plain)
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("アテンション", count: attentionItems.count)

            if attentionItems.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                    Text("対応が必要なお知らせはありません")
                        .font(FavorecoTypography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(attentionItems.prefix(2)) { item in
                    if let plan = item.plan {
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            AttentionRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AttentionRow(item: item)
                    }
                }

                if attentionItems.count > 2 {
                    Button("ほか\(attentionItems.count - 2)件") {
                        isShowingAttentionList = true
                    }
                    .font(FavorecoTypography.captionStrong)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var experienceGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("体験ギャラリー", count: recentVisits.count)

            if recentVisits.isEmpty {
                EmptyStateRow(
                    icon: "photo.on.rectangle.angled",
                    title: "ギャラリーはまだ空です",
                    message: "写真付きの記録やこれから参加する予定が、ここに並びます。"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recentVisits) { visit in
                            NavigationLink {
                                ExperienceDetailView(visit: visit)
                            } label: {
                                ExperienceGalleryCard(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近の記録", count: visibleVisits.count)

            if visibleVisits.isEmpty {
                EmptyStateRow(
                    icon: "sparkles.rectangle.stack",
                    title: "記録はまだありません",
                    message: "中央の＋から体験済みの記録を追加できます。"
                )
            } else {
                ForEach(visibleVisits.prefix(5)) { visit in
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

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("気になる", count: interestedEvents.count + unresolvedInboxItems.count)

            if interestedEvents.isEmpty && unresolvedInboxItems.isEmpty {
                EmptyStateRow(
                    icon: "tray",
                    title: "気になる対象はありません",
                    message: "クイック登録した作品や場所がここに表示されます。"
                )
            } else {
                ForEach(interestedEvents.prefix(3)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        InterestedEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(unresolvedInboxItems.prefix(max(0, 3 - interestedEvents.count))) { item in
                    NavigationLink {
                        InboxDetailView(item: item)
                    } label: {
                        InboxItemRow(item: item, categories: visibleCategories)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("統計サマリ", count: visibleVisits.count)

            HStack(spacing: 12) {
                SummaryMetricCard(title: "記録", value: "\(visibleVisits.count)", icon: "sparkles.rectangle.stack")
                SummaryMetricCard(title: "ジャンル", value: "\(visibleCategories.count)", icon: "square.grid.2x2")
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("お気に入り/ベスト", count: 0)
            EmptyStateRow(
                icon: "star",
                title: "ベスト候補はまだありません",
                message: "評価やお気に入り機能が入ると、年間ベスト候補をここに表示します。"
            )
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.sectionTitle)
            Spacer()
            Text("\(count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InterestedEventRow: View {
    let event: ExperienceEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = event.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title.isEmpty ? "無題" : event.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let category = event.category {
                        Label(category.name, systemImage: category.iconSymbol)
                    }
                    if !event.officialURL.isEmpty {
                        Label("URL", systemImage: "link")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeUpcomingPlanCard: View {
    let plan: Plan
    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        themePalette.categoryColor(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var dateText: String {
        plan.startsAt.formatted(
            .dateTime
                .locale(Locale(identifier: "ja_JP"))
                .month(.defaultDigits)
                .day()
                .weekday(.abbreviated)
                .hour()
                .minute()
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: plan.category?.iconSymbol ?? "calendar")
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(plan.category?.name ?? "予定")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)

                Text(plan.title.isEmpty ? plan.event?.title ?? "予定" : plan.title)
                    .font(FavorecoTypography.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label(dateText, systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !plan.venueNameSnapshot.isEmpty {
                    Label(plan.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeAttentionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let dueDate: Date
    var plan: Plan? = nil
    let tint: Color
    let priority: Int
}

private struct HomeMiniStatCell: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(value)
                .font(FavorecoTypography.jpSans(24, weight: .bold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AttentionRow: View {
    let item: HomeAttentionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(item.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAttentionListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HomeAttentionItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                if let plan = item.plan {
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        AttentionRow(item: item)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                } else {
                    AttentionRow(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct ExperienceGalleryCard: View {
    let visit: Visit

    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]
    @Environment(\.displayScale) private var displayScale
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var thumbnailImage: UIImage?

    private var categoryColor: Color {
        themePalette.categoryColor(hex: visit.event?.category?.colorHex ?? "#147C88")
    }

    private var firstPhoto: PhotoBlob? {
        let photos = (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
        if !visit.eyecatchPath.isEmpty,
           let cover = photos.first(where: { $0.relativePath == visit.eyecatchPath }) {
            return cover
        }
        return photos.min { $0.createdAt < $1.createdAt }
    }

    // 190pt幅カード。scale過剰を避けるため上限クランプ。
    private var thumbnailMaxPixel: CGFloat {
        min(200 * displayScale, 1200)
    }

    // 写真ID＋表示サイズをキーに含める（サイズ違いは別キャッシュ・task再実行の判定にも使う）
    private func cacheKey(for photo: PhotoBlob) -> String {
        "\(photo.id.uuidString)@\(Int(thumbnailMaxPixel.rounded()))"
    }

    private var thumbnailTaskID: String? {
        firstPhoto.map { cacheKey(for: $0) }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let photo = firstPhoto else {
            thumbnailImage = nil
            return
        }
        let targetID = photo.id
        let key = cacheKey(for: photo)
        if let cached = ThumbnailLoader.cached(forKey: key) {
            thumbnailImage = cached
            return
        }
        let data = photo.data // SwiftData プロパティはメインで読み、値型で渡す
        let maxPixel = thumbnailMaxPixel
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.makeThumbnail(from: data, maxPixelSize: maxPixel, cacheKey: key)
        }.value
        // セル再利用や写真変更後に遅れて届いた結果で、別の写真の画像を上書きしない
        guard !Task.isCancelled, firstPhoto?.id == targetID else { return }
        thumbnailImage = image
    }

    private var title: String {
        visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録"
    }

    private var statusText: String? {
        visitTicketStatusText(visit.outcomeKey)
    }

    private var unitFields: VisitUnitFields {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
    }

    private var eyecatchAspectRatio: Double {
        EyecatchAspectRatio.option(
            for: unitFields.eyecatchAspectRatioKey,
            category: visit.event?.category
        ).value
    }

    private var peopleSummary: String {
        let linkedPeople = personLinks
            .filter { link in
                !link.isArchived && (link.event?.id == visit.event?.id || link.visit?.id == visit.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(2)
            .map { link in
                link.nameSnapshot.isEmpty ? link.person?.displayName ?? "" : link.nameSnapshot
            }
            .filter { !$0.isEmpty }
        return linkedPeople.joined(separator: " / ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(categoryColor.opacity(0.18))
                    Image(systemName: visit.eyecatchPath.isEmpty ? "sparkles" : "photo.fill")
                        .font(.largeTitle)
                        .foregroundStyle(categoryColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(visit.event?.category?.name ?? "記録")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())

                    if let statusText {
                        Text(statusText)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(10)
            }
            .aspectRatio(CGFloat(eyecatchAspectRatio), contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                Label(visit.visitedAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)

                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !peopleSummary.isEmpty {
                    Label(peopleSummary, systemImage: "person.2")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if visit.amount != Decimal(0) || !unitFields.ocrText.isEmpty || !unitFields.advancedEntries.isEmpty {
                    HStack(spacing: 6) {
                        if visit.amount != Decimal(0) {
                            HomeVisitBadge(text: formattedVisitAmount(visit.amount), icon: "yensign.circle")
                        }
                        if !unitFields.ocrText.isEmpty {
                            HomeVisitBadge(text: "OCR", icon: "text.viewfinder")
                        }
                        if !unitFields.advancedEntries.isEmpty {
                            HomeVisitBadge(text: "詳細", icon: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .frame(width: 190, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(FavorecoTypography.sectionTitle)
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct InboxItemRow: View {
    let item: InboxItem
    let categories: [RecordCategory]

    private var categoryName: String? {
        guard !item.targetTemplateKey.isEmpty else { return nil }
        return categories.first(where: { $0.templateKey == item.targetTemplateKey })?.name
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = item.eyecatchData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title.isEmpty ? "無題" : item.title)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let categoryName {
                        Label(categoryName, systemImage: "square.grid.2x2")
                    }
                    if !item.sourceURL.isEmpty {
                        Label("URL", systemImage: "link")
                    }
                    Label(item.createdAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeCategoryShortcut: View {
    let category: RecordCategory
    @Environment(\.favorecoThemePalette) private var themePalette

    private var tint: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: category.iconSymbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            Text(category.name.isEmpty ? "無題" : category.name)
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 68, alignment: .top)
        .frame(minHeight: 64, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name.isEmpty ? "無題ジャンル" : category.name)
        .accessibilityHint("ジャンルトップを開きます")
    }
}

private struct HomeVisitBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private func visitTicketStatusText(_ key: String) -> String? {
    switch key {
    case "planned": return "予定"
    case "applied": return "申込中"
    case "won": return "当選"
    case "paid": return "入金済み"
    case "ticketed": return "発券済み"
    case "attended": return "参加済み"
    case "canceled": return "中止"
    default: return nil
    }
}

private func formattedVisitAmount(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "JPY"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥\(NSDecimalNumber(decimal: amount).stringValue)"
}

private struct EmptyStateRow: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}


#Preview {
    HomeView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}

extension Notification.Name {
    static let openFavorecoPlanList = Notification.Name("openFavorecoPlanList")
    static let openFavorecoPlanCreation = Notification.Name("openFavorecoPlanCreation")
}
