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

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    categorySection
                    recentSection
                    inboxSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("favoreco")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("観た・行った・体験したを、")
                .font(.title2.weight(.semibold))
            Text("美しく一生残す。")
                .font(.largeTitle.weight(.bold))
            Text("まずは体験ジャンルを選んで、記録の器を育てていきます。")
                .font(.subheadline)
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
                    title: "カテゴリを準備中です",
                    message: "初回起動時に標準プリセットを注入します。"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    ForEach(visibleCategories) { category in
                        CategoryTile(category: category)
                    }
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
                    VisitRow(visit: visit)
                }
            }
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("あとで記録", count: inboxItems.count)

            if inboxItems.isEmpty {
                EmptyStateRow(
                    icon: "tray",
                    title: "Inboxは空です",
                    message: "気になる作品・行きたい場所・飲みたい酒を一時保存する場所になります。"
                )
            } else {
                ForEach(inboxItems.prefix(3)) { item in
                    Text(item.title.isEmpty ? "無題" : item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
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
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name.isEmpty ? "無題カテゴリ" : category.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(category.enabledUnitsRaw.isEmpty ? "ユニット未設定" : unitSummary(category.enabledUnitsRaw))
                    .font(.caption)
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
                .font(.headline)
            Text(visit.visitedAt, format: Date.FormatStyle(date: .numeric, time: .omitted))
                .font(.caption)
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
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        if sanitizedHex.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        } else {
            red = 0.44
            green = 0.56
            blue = 0.48
        }

        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
