//
//  EventDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import SwiftData

struct EventDetailView: View {
    let event: ExperienceEvent
    @State private var isShowingAddVisit = false
    @State private var isShowingEditEvent = false

    private var category: RecordCategory? {
        event.category
    }

    private var accentColor: Color {
        Color(hex: category?.colorHex ?? "#6F8F7A")
    }

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: category)
    }

    private var visits: [Visit] {
        (event.visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                eventMemoSection
                stats
                visitHistory
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(eventTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditEvent = true
                } label: {
                    Label("対象を編集", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddVisit = true
                } label: {
                    Label("回を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddVisit) {
            AddVisitView(event: event)
        }
        .sheet(isPresented: $isShowingEditEvent) {
            EditEventView(event: event)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: category?.iconSymbol ?? "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(eventTitle)
                        .font(FavorecoTypography.jpSerif(26, weight: .bold, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(category?.name ?? "未分類")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(accentColor)
                }
            }

            if !event.seriesName.isEmpty {
                Label(event.seriesName, systemImage: "rectangle.stack")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                isShowingAddVisit = true
            } label: {
                Label(template.visitSectionTitle + "を追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatSummaryTile(title: "記録", value: "\(visits.count)")
            StatSummaryTile(title: "最新", value: latestVisitText)
            StatSummaryTile(title: template.ratingLabel, value: averageRatingText)
        }
    }

    @ViewBuilder
    private var eventMemoSection: some View {
        if !event.memo.isEmpty || !event.officialURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.targetSectionTitle)
                    .font(FavorecoTypography.sectionTitle)

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let url = URL(string: event.officialURL), !event.officialURL.isEmpty {
                    Link(destination: url) {
                        Label("公式リンク", systemImage: "link")
                            .font(FavorecoTypography.bodyStrong)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var visitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("履歴")
                    .font(FavorecoTypography.sectionTitle)
                Spacer()
                Text("\(visits.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if visits.isEmpty {
                EventEmptyState(icon: "calendar.badge.plus", message: "この対象の回はまだありません。")
            } else {
                ForEach(visits) { visit in
                    NavigationLink {
                        ExperienceDetailView(visit: visit)
                    } label: {
                        EventVisitRow(visit: visit, ratingLabel: template.ratingLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var eventTitle: String {
        event.title.isEmpty ? "記録" : event.title
    }

    private var latestVisitText: String {
        guard let latestVisit = visits.first else {
            return "-"
        }
        return latestVisit.visitedAt.formatted(date: .numeric, time: .omitted)
    }

    private var averageRatingText: String {
        let ratedVisits = visits.filter { $0.overallRating > 0 }
        guard !ratedVisits.isEmpty else {
            return "-"
        }

        let total = ratedVisits.reduce(0) { $0 + $1.overallRating }
        return String(format: "%.1f", total / Double(ratedVisits.count))
    }
}

struct EditEventView: View {
    let event: ExperienceEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: EventDraft

    private var template: CategoryRecordTemplate {
        CategoryRecordTemplate.template(for: event.category)
    }

    init(event: ExperienceEvent) {
        self.event = event
        _draft = State(initialValue: EventDraft(event: event))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(template.targetSectionTitle) {
                    TextField(template.titlePlaceholder, text: $draft.title)
                    TextField(template.seriesPlaceholder, text: $draft.seriesName)
                    TextField("公式URL（任意）", text: $draft.officialURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("対象メモ") {
                    ZStack(alignment: .topLeading) {
                        if draft.memo.isEmpty {
                            Text("対象そのものについて残しておきたいこと")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $draft.memo)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("対象を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func save() {
        event.title = draft.trimmedTitle
        event.seriesName = draft.trimmedSeriesName
        event.officialURL = draft.trimmedOfficialURL
        event.memo = draft.trimmedMemo
        event.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to update event: \(error)")
        }
    }
}

private struct EventDraft {
    var title: String
    var seriesName: String
    var officialURL: String
    var memo: String

    init(event: ExperienceEvent) {
        title = event.title
        seriesName = event.seriesName
        officialURL = event.officialURL
        memo = event.memo
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSeriesName: String {
        seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfficialURL: String {
        officialURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }
}

private struct StatSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FavorecoTypography.latinDisplay(22, weight: .bold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EventVisitRow: View {
    let visit: Visit
    let ratingLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(visit.visitedAt.formatted(date: .long, time: .omitted))
                .font(FavorecoTypography.cardTitle)
            HStack(spacing: 10) {
                if !visit.venueNameSnapshot.isEmpty {
                    Label(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
                if visit.overallRating > 0 {
                    Label("\(ratingLabel) \(String(format: "%.1f", visit.overallRating))", systemImage: "star.fill")
                }
            }
            .font(FavorecoTypography.caption)
            .foregroundStyle(.secondary)

            if !visit.note.isEmpty {
                Text(visit.note)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EventEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(message)
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let category = RecordCategory(name: "観劇", iconSymbol: "theatermasks.fill", colorHex: "#8B2F45", templateKey: "theater")
    let event = ExperienceEvent(title: "サンプル公演", seriesName: "東京公演", category: category)

    NavigationStack {
        EventDetailView(event: event)
    }
    .modelContainer(for: [RecordCategory.self, ExperienceEvent.self, Visit.self, InboxItem.self, PhotoBlob.self], inMemory: true)
}
