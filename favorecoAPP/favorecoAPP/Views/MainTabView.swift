//
//  MainTabView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query(sort: \RecordCategory.sortOrder) private var categories: [RecordCategory]
    @State private var selectedTab: MainTab = .home
    @State private var isShowingCreateMenu = false
    @State private var isShowingAddInboxItem = false
    @State private var selectedCategoryForRecord: RecordCategory?

    private var visibleCategories: [RecordCategory] {
        categories.filter { !$0.isArchived }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(MainTab.home)

                RecordsView()
                    .tabItem {
                        Label("記録", systemImage: "rectangle.stack")
                    }
                    .tag(MainTab.records)

                CalendarView()
                    .tabItem {
                        Label("カレンダー", systemImage: "calendar")
                    }
                    .tag(MainTab.calendar)

                StatsView()
                    .tabItem {
                        Label("統計", systemImage: "chart.bar")
                    }
                    .tag(MainTab.stats)
            }

            CenterCreateButton {
                isShowingCreateMenu = true
            }
        }
        .confirmationDialog("記録を追加", isPresented: $isShowingCreateMenu, titleVisibility: .visible) {
            if visibleCategories.isEmpty {
                Button("記録を追加") {}
                    .disabled(true)
            } else {
                ForEach(visibleCategories) { category in
                    Button("\(category.name)に記録を追加") {
                        selectedCategoryForRecord = category
                    }
                }
            }

            Button("あとで記録") {
                isShowingAddInboxItem = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今すぐ記録するか、Inboxに一時保存します。")
        }
        .sheet(item: $selectedCategoryForRecord) { category in
            AddExperienceView(category: category)
        }
        .sheet(isPresented: $isShowingAddInboxItem) {
            AddInboxItemView()
        }
    }
}

private enum MainTab: Hashable {
    case home
    case records
    case calendar
    case stats
}

private struct CenterCreateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
        }
        .accessibilityLabel("記録を追加")
        .padding(.bottom, 18)
    }
}

private struct RecordsView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]

    var body: some View {
        NavigationStack {
            List {
                if visits.isEmpty {
                    PlaceholderRow(
                        icon: "rectangle.stack",
                        title: "記録はまだありません",
                        message: "中央の＋から最初の記録を追加できます。"
                    )
                } else {
                    ForEach(visits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VisitSummaryRow(visit: visit)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("記録")
        }
    }
}

private struct CalendarView: View {
    var body: some View {
        NavigationStack {
            List {
                PlaceholderRow(
                    icon: "calendar",
                    title: "カレンダーは準備中です",
                    message: "予定、申込、訪問済みの記録を日付で見られる場所になります。"
                )
            }
            .navigationTitle("カレンダー")
        }
    }
}

private struct StatsView: View {
    var body: some View {
        NavigationStack {
            List {
                PlaceholderRow(
                    icon: "chart.bar",
                    title: "統計は準備中です",
                    message: "ジャンル別回数、年間まとめ、支出、評価などを集計します。"
                )
            }
            .navigationTitle("統計")
        }
    }
}

private struct PlaceholderRow: View {
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
        .padding(.vertical, 6)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self, SocialAccount.self], inMemory: true)
}
