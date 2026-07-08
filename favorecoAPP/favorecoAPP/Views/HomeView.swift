//
//  HomeView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/08.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query(sort: \InboxItem.createdAt, order: .reverse) private var inboxItems: [InboxItem]
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

    private var upcomingVisits: [Visit] {
        let now = Calendar.current.startOfDay(for: Date())
        return visits
            .filter { $0.visitedAt >= now }
            .sorted { $0.visitedAt < $1.visitedAt }
    }

    private var attentionItems: [HomeAttentionItem] {
        var items = upcomingVisits.prefix(3).map { visit in
            HomeAttentionItem(
                icon: "calendar.badge.clock",
                title: visit.event?.title.isEmpty == false ? visit.event?.title ?? "予定" : "予定",
                subtitle: visit.visitedAt.formatted(date: .long, time: .omitted),
                tint: Color(hex: visit.event?.category?.colorHex ?? "#147C88")
            )
        }

        if items.count < 3 {
            let inboxAttention = unresolvedInboxItems.prefix(3 - items.count).map { item in
                HomeAttentionItem(
                    icon: "tray",
                    title: item.title.isEmpty ? "あとで記録" : item.title,
                    subtitle: "未整理",
                    tint: .secondary
                )
            }
            items.append(contentsOf: inboxAttention)
        }

        return Array(items)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if showsAttention {
                        attentionSection
                    }
                    if showsExperienceGallery {
                        experienceGallerySection
                    }
                    if showsInbox {
                        inboxSection
                    }
                    if showsRecentRecords {
                        recentSection
                    }
                    if showsCategories {
                        categorySection
                    }
                    if showsStatsSummary {
                        statsSummarySection
                    }
                    if showsFavorites {
                        favoritesSection
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
            Text("まずは体験ジャンルを選んで、記録の器を育てていきます。")
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    AttentionRow(item: item)
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
                    HStack(spacing: 12) {
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
                        VisitRow(visit: visit)
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
    let tint: Color
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

    private var categoryColor: Color {
        Color(hex: visit.event?.category?.colorHex ?? "#147C88")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(categoryColor.opacity(0.18))
                Image(systemName: visit.eyecatchPath.isEmpty ? "sparkles" : "photo.fill")
                    .font(.largeTitle)
                    .foregroundStyle(categoryColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(visit.event?.category?.name ?? "記録")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録")
                    .font(FavorecoTypography.cardTitle)
                    .lineLimit(2)
                Text(visit.visitedAt.formatted(date: .numeric, time: .omitted))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
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

private struct VisitRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録")
                .font(FavorecoTypography.cardTitle)
            Text(visit.visitedAt, format: Date.FormatStyle(date: .numeric, time: .omitted))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
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
