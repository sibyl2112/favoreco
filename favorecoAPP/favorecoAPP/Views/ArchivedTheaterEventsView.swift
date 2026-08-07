import SwiftUI
import SwiftData
import UIKit

struct ArchivedTheaterEventsView: View {
    let categoryID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExperienceEvent.updatedAt, order: .reverse) private var allEvents: [ExperienceEvent]
    @State private var restoreErrorMessage: String?

    private var archivedEvents: [ExperienceEvent] {
        allEvents.filter {
            $0.isArchived && $0.category?.id == categoryID
        }
    }

    var body: some View {
        List {
            if archivedEvents.isEmpty {
                FavorecoContentUnavailableView(
                    "非表示の公演はありません",
                    systemImage: "archivebox",
                    description: "再表示した公演は、観劇の公演一覧へ戻ります。"
                )
            } else {
                Section {
                    ForEach(archivedEvents) { event in
                        archivedEventRow(event)
                    }
                } footer: {
                    Text("再表示しても、観劇記録・予定・チケット・写真は変更されません。")
                }
            }
        }
        .navigationTitle("非表示の公演")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        .alert("再表示できませんでした", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { if !$0 { restoreErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                restoreErrorMessage = nil
            }
        } message: {
            Text(restoreErrorMessage ?? "")
        }
    }

    private func archivedEventRow(_ event: ExperienceEvent) -> some View {
        HStack(spacing: 12) {
            eventThumbnail(event)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "名称未設定の公演" : event.title)
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !event.seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(event.seriesName)
                            .lineLimit(1)
                    }
                    Text("観劇記録 \((event.visits ?? []).count)件")
                        .lineLimit(1)
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("再表示") {
                restore(event)
            }
            .font(FavorecoTypography.captionStrong)
            .buttonStyle(.bordered)
            .tint(TheaterCategoryStyle.gold)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("再表示") {
                restore(event)
            }
            .tint(TheaterCategoryStyle.gold)
        }
    }

    @ViewBuilder
    private func eventThumbnail(_ event: ExperienceEvent) -> some View {
        TheaterPosterArtwork(
            reference: .event(event.id),
            backgroundColor: TheaterCategoryStyle.black
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: event.category?.templateKey ?? "theater",
                displaySize: size
            )
        }
        .frame(width: 44, height: 62)
    }

    private func restore(_ event: ExperienceEvent) {
        event.isArchived = false
        event.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            restoreErrorMessage = "「\(event.title.isEmpty ? "名称未設定の公演" : event.title)」を再表示できませんでした。"
        }
    }
}
