//
//  CategoryTopView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct CategoryTopView: View {
    let category: RecordCategory

    @Query(sort: \Visit.visitedAt, order: .reverse) private var allVisits: [Visit]
    @State private var isShowingAddExperience = false

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
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category.iconSymbol)
                    .font(.title)
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: category.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                    Text(heroMessage)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                isShowingAddExperience = true
            } label: {
                Label("最初の記録を追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: category.colorHex))
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
                EmptyCategoryState(category: category)
            } else {
                ForEach(visits.prefix(10)) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        CategoryVisitRow(visit: visit)
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

private struct EmptyCategoryState: View {
    let category: RecordCategory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: category.iconSymbol)
                .font(.title3)
                .foregroundStyle(Color(hex: category.colorHex))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("まだ記録がありません")
                    .font(FavorecoTypography.bodyStrong)
                Text("タイトル、日付、場所、評価、メモだけの軽い記録から始められます。")
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
        enabledUnitsRaw: "U1,U3,U4,U7,U11,U12,U14,U15,U18"
    )

    NavigationStack {
        CategoryTopView(category: category)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
