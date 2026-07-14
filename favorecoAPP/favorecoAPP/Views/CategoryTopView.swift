//
//  CategoryTopView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData
import UIKit

struct CategoryTopView: View {
    let category: RecordCategory

    @Environment(\.favorecoThemePalette) private var themePalette
    @Query(sort: \RecordCategory.sortOrder) private var allCategories: [RecordCategory]
    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @AppStorage(AppStorageKeys.homeSelectedCategoryTemplateKey) private var homeSelectedCategoryTemplateKey = ""
    @State private var isShowingAddExperience = false
    @State private var isShowingAddVisit = false
    @State private var selectedEventForNewVisit: ExperienceEvent?

    private var visibleCategories: [RecordCategory] {
        allCategories.filter { !$0.isArchived }
    }

    private var events: [ExperienceEvent] {
        (category.events ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var visits: [Visit] {
        let eventIDs = Set(events.map(\.id))
        return allVisits.filter { visit in
            guard let event = visit.event else { return false }
            return eventIDs.contains(event.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                stats
                eventSection
                recentVisits
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddExperience = true
                } label: {
                    Label("記録を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddExperience) {
            AddExperienceView(category: category)
        }
        .sheet(isPresented: $isShowingAddVisit) {
            if let selectedEventForNewVisit {
                AddVisitView(event: selectedEventForNewVisit)
            }
        }
        .onAppear {
            homeSelectedCategoryTemplateKey = category.templateKey
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category.iconSymbol)
                    .font(.title)
                    .foregroundStyle(themePalette.categoryColor(hex: category.colorHex))
                    .frame(width: 44, height: 44)
                    .background(themePalette.categoryColor(hex: category.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    GenreHeadingSwitcher(
                        currentCategory: category,
                        categories: visibleCategories
                    )
                    Text(heroMessage)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                isShowingAddExperience = true
            } label: {
                Label(events.isEmpty ? "最初の記録を追加" : "新しい対象を追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(themePalette.categoryColor(hex: category.colorHex))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatTile(title: "対象", value: "\(events.count)")
            StatTile(title: "記録", value: "\(visits.count)")
            StatTile(title: "ユニット", value: "\(unitCount)")
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("対象")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(events.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                EmptyStateMessage(
                    icon: "rectangle.stack.badge.plus",
                    title: "対象はまだありません",
                    message: "最初の記録を追加すると、ここから同じ対象に回を重ねられます。"
                )
            } else {
                ForEach(events.prefix(10)) { event in
                    EventRow(event: event) {
                        selectedEventForNewVisit = event
                        isShowingAddVisit = true
                    }
                }
            }
        }
    }

    private var recentVisits: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近の記録")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(visits.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if visits.isEmpty {
                EmptyStateMessage(
                    icon: category.iconSymbol,
                    title: "まだ記録がありません",
                    message: "タイトル、日付、場所、評価、メモだけの軽い記録から始められます。",
                    tint: themePalette.categoryColor(hex: category.colorHex)
                )
            } else {
                ForEach(visits.prefix(10)) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        VisitSummaryRow(visit: visit, showsCategory: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var heroMessage: String {
        if visits.isEmpty {
            return "まだ記録はありません。まずは1件だけ、タイトルと日付から残せます。"
        }
        return "このカテゴリに \(visits.count) 件の記録があります。"
    }

    private var unitCount: Int {
        category.enabledUnitsRaw.split(separator: ",").count
    }
}

private struct GenreHeadingSwitcher: View {
    let currentCategory: RecordCategory
    let categories: [RecordCategory]

    var body: some View {
        Menu {
            ForEach(categories) { category in
                if category.id == currentCategory.id {
                    Label(category.name, systemImage: "checkmark")
                } else {
                    NavigationLink {
                        CategoryTopView(category: category)
                    } label: {
                        Label(category.name, systemImage: category.iconSymbol)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentCategory.name)
                    .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ジャンルを切り替え")
    }
}

private struct EventRow: View {
    let event: ExperienceEvent
    let onAddVisit: () -> Void

    private var visits: [Visit] {
        (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
    }

    private var representativePhoto: PhotoBlob? {
        EventRepresentativePhotoResolver.photo(for: event)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                EventDetailView(event: event)
            } label: {
                HStack(spacing: 12) {
                    if let representativePhoto {
                        RepresentativePhotoImage(photo: representativePhoto, maxPixelSize: 220)
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if let data = event.eyecatchData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.cardTitle)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            if !event.seriesName.isEmpty {
                                Label(event.seriesName, systemImage: "rectangle.stack")
                                    .lineLimit(1)
                            }
                            Label("\(visits.count)件", systemImage: "number")
                            if let latestVisit = visits.first {
                                Label(latestVisit.visitedAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                            }
                        }
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onAddVisit) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FavorecoTypography.latinDisplay(24, weight: .bold, relativeTo: .title3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CategoryVisitRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "記録" : "記録")
                .font(FavorecoTypography.cardTitle)
                .lineLimit(2)
            HStack(spacing: 10) {
                Label(visit.visitedAt.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
                if visit.overallRating > 0 {
                    Label(String(format: "%.1f", visit.overallRating), systemImage: "star.fill")
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyStateMessage: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
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
    let category = RecordCategory(
        name: "観劇",
        iconSymbol: "theatermasks.fill",
        colorHex: "#8B2F45",
        isBuiltIn: true,
        templateKey: "theater",
        enabledUnitsRaw: "basic,people,ticketPlan,photos,importOCR,money,officialInfo,memo"
    )

    NavigationStack {
        CategoryTopView(category: category)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
