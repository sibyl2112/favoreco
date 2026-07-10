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
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
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
    @State private var isShowingSettings = false

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    private var unresolvedInboxItems: [InboxItem] {
        inboxItems.filter { $0.state == "unresolved" }
    }

    private var recentVisits: [Visit] {
        Array(visits.prefix(8))
    }

    /// 記録・予定・締切・Inbox がいずれも無い＝Homeに出す中身が無い状態。
    private var isHomeContentEmpty: Bool {
        visits.isEmpty && attentionItems.isEmpty && unresolvedInboxItems.isEmpty
    }

    private var upcomingVisits: [Visit] {
        let now = Calendar.current.startOfDay(for: Date())
        return visits
            .filter { $0.visitedAt >= now }
            .sorted { $0.visitedAt < $1.visitedAt }
    }

    private var upcomingPlans: [Plan] {
        let now = Date()
        return plans
            .filter { !$0.isArchived && $0.endsAt >= now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingItemCount: Int {
        upcomingPlans.count + upcomingVisits.count
    }

    private var currentYearVisitCount: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return visits.filter { calendar.component(.year, from: $0.visitedAt) == year }.count
    }

    private var attentionItems: [HomeAttentionItem] {
        var items = ticketAttentionItems

        if items.count < 5 {
            items.append(contentsOf: membershipAttentionItems.prefix(5 - items.count))
        }

        if items.count < 5 {
            let planItems = upcomingPlans.prefix(5 - items.count).map { plan in
                HomeAttentionItem(
                    icon: "calendar.badge.clock",
                    title: plan.title.isEmpty ? "予定" : plan.title,
                    subtitle: "公演 \(attentionDateFormatter.string(from: plan.startsAt))",
                    dueDate: plan.startsAt,
                    plan: plan,
                    tint: Color(hex: plan.category?.colorHex ?? "#147C88"),
                    priority: 20
                )
            }
            items.append(contentsOf: planItems)
        }

        if items.count < 5 {
            let visitItems = upcomingVisits.prefix(5 - items.count).map { visit in
                HomeAttentionItem(
                    icon: "calendar.badge.clock",
                    title: visit.event?.title.isEmpty == false ? visit.event?.title ?? "予定" : "予定",
                    subtitle: visit.visitedAt.formatted(date: .long, time: .omitted),
                    dueDate: visit.visitedAt,
                    tint: Color(hex: visit.event?.category?.colorHex ?? "#147C88"),
                    priority: 30
                )
            }
            items.append(contentsOf: visitItems)
        }

        if items.count < 5 {
            let inboxAttention = unresolvedInboxItems.prefix(5 - items.count).map { item in
                HomeAttentionItem(
                    icon: "tray",
                    title: item.title.isEmpty ? "あとで記録" : item.title,
                    subtitle: "未整理",
                    dueDate: item.createdAt,
                    tint: .secondary,
                    priority: 90
                )
            }
            items.append(contentsOf: inboxAttention)
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
        let tint = Color(hex: plan?.category?.colorHex ?? "#147C88")
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
                    hero
                    crossGenreMiniStats

                    // 1. 次の予定・締切
                    if showsAttention && !attentionItems.isEmpty {
                        attentionSection
                    }
                    // 2. 最近の記録
                    if showsRecentRecords && !visits.isEmpty {
                        recentSection
                    }
                    // 3. 体験ギャラリー
                    if showsExperienceGallery && !recentVisits.isEmpty {
                        experienceGallerySection
                    }
                    // 4. お気に入り・統計（任意表示）
                    if showsFavorites {
                        favoritesSection
                    }
                    if showsStatsSummary && !visits.isEmpty {
                        statsSummarySection
                    }
                    // 5. その他
                    if showsInbox && !unresolvedInboxItems.isEmpty {
                        inboxSection
                    }
                    if showsCategories && !visibleCategories.isEmpty {
                        categorySection
                    }

                    // すべて空のときだけ、単一のプレースホルダーで導線を示す
                    if isHomeContentEmpty {
                        homeEmptyState
                    }
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
                        Label("マイ", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("favoreco")
                .font(FavorecoTypography.appLogo)
                .foregroundStyle(.primary)
            Text("観た・行った・体験したを、")
                .font(FavorecoTypography.heroLead)
            Text("美しく一生残す。")
                .font(FavorecoTypography.heroTitle)
            if isHomeContentEmpty {
                Text("まずは体験ジャンルを選んで、記録の器を育てていきます。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                value: "\(visits.count)",
                label: "総記録数",
                icon: "chart.bar.fill",
                tint: Color(hex: "#B8792F")
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("カテゴリ", count: visibleCategories.count)

            if visibleCategories.isEmpty {
                EmptyStateRow(
                    icon: "square.grid.2x2",
                    title: "何もありません",
                    message: "設定からジャンルを選び直すと、記録の入口が表示されます。"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    ForEach(visibleCategories) { category in
                        NavigationLink {
                            CategoryTopView(category: category)
                        } label: {
                            CategoryTile(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("アテンション", count: attentionItems.count)

            if attentionItems.isEmpty {
                EmptyStateRow(
                    icon: "bell.badge",
                    title: "今すぐ確認することはありません",
                    message: "今後は予定、申込締切、当落、リマインダーをここにまとめます。"
                )
            } else {
                ForEach(attentionItems) { item in
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
            sectionHeader("最近の記録", count: visits.count)

            if visits.isEmpty {
                EmptyStateRow(
                    icon: "sparkles.rectangle.stack",
                    title: "記録はまだありません",
                    message: "次の実装で、カテゴリから最初の記録を追加できるようにします。"
                )
            } else {
                ForEach(visits.prefix(5)) { visit in
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
            sectionHeader("あとで記録", count: unresolvedInboxItems.count)

            if unresolvedInboxItems.isEmpty {
                EmptyStateRow(
                    icon: "tray",
                    title: "Inboxは空です",
                    message: "気になる作品・行きたい場所・飲みたい酒を一時保存する場所になります。"
                )
            } else {
                ForEach(unresolvedInboxItems.prefix(3)) { item in
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
            sectionHeader("統計サマリ", count: visits.count)

            HStack(spacing: 12) {
                SummaryMetricCard(title: "記録", value: "\(visits.count)", icon: "sparkles.rectangle.stack")
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

    private var homeEmptyState: some View {
        EmptyStateRow(
            icon: "sparkles",
            title: "最初の記録を始めましょう",
            message: "予定・締切や最近の思い出がここにまとまります。下のカテゴリから体験を記録してみましょう。"
        )
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

private struct ExperienceGalleryCard: View {
    let visit: Visit

    @Query(sort: \EventPersonLink.sortOrder) private var personLinks: [EventPersonLink]

    private var categoryColor: Color {
        Color(hex: visit.event?.category?.colorHex ?? "#147C88")
    }

    private var firstPhotoImage: UIImage? {
        guard let photo = visit.photos?.first(where: { $0.mediaKind == "photo" }),
              !photo.data.isEmpty else {
            return nil
        }
        return UIImage(data: photo.data)
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
                if let firstPhotoImage {
                    Image(uiImage: firstPhotoImage)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CategoryTile: View {
    let category: RecordCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: category.iconSymbol)
                    .font(.title2)
                    .foregroundStyle(Color(hex: category.colorHex))
                Spacer(minLength: 8)
                if category.isBuiltIn {
                    Text("標準")
                        .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name.isEmpty ? "無題カテゴリ" : category.name)
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)
                Text(category.enabledUnitsRaw.isEmpty ? "ユニット未設定" : unitSummary(category.enabledUnitsRaw))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
    }

    private func unitSummary(_ rawValue: String) -> String {
        "ユニット \(rawValue.split(separator: ",").count)件"
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
