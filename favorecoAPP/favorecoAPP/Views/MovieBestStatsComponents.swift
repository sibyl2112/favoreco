import SwiftUI
import SwiftData
import UIKit

struct StatsScreenWorkFilterBar: View {
    @Binding var selection: ScreenWorkFilter
    let tint: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScreenWorkFilter.allCases) { filter in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = filter
                    }
                } label: {
                    Text(filter.displayName)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(selection == filter ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                        .background {
                            if selection == filter {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tint)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("映像作品の種類")
    }
}

struct MovieBestStatsSection: View {
    let period: MovieBestPeriod
    let candidates: [Visit]
    let selectedVisits: [Visit]
    let tint: Color
    let isUnlocked: Bool
    var compact = false
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var shareItems: [Any] = []
    @State private var isPreparingShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(compact ? "Monthly MY BEST" : "MY BEST")
                        .font(compact ? FavorecoTypography.bodyStrong : FavorecoTypography.sectionTitle)
                    Text("映画の記録から最大\(period.maximumCount)作品")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isUnlocked {
                    Button("編集", action: onEdit)
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .disabled(candidates.isEmpty)
                }
            }

            if !isUnlocked {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MY BESTを選ぶ")
                            .font(FavorecoTypography.bodyStrong)
                        Text("年・月ごとの映画ベストとシェア画像はPro以上で利用できます。")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(tint)
                }
            } else if candidates.isEmpty {
                Text("この期間に参加済みの映画記録はありません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            } else if selectedVisits.isEmpty {
                Button(action: onEdit) {
                    Label("作品を選ぶ", systemImage: "plus.circle")
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedVisits.enumerated()), id: \.element.id) { index, visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            MovieBestRankRow(rank: index + 1, visit: visit, tint: tint)
                        }
                        .buttonStyle(.plain)

                        if visit.id != selectedVisits.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }

                Button {
                    prepareShareImage()
                } label: {
                    Label(isPreparingShare ? "画像を作成中" : "シェア画像を作る", systemImage: "square.and.arrow.up")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .disabled(isPreparingShare)
            }
        }
        .padding(compact ? 12 : 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.8)
        }
        .sheet(isPresented: Binding(
            get: { !shareItems.isEmpty },
            set: { if !$0 { shareItems = [] } }
        )) {
            MovieBestActivityView(activityItems: shareItems)
        }
    }

    @MainActor
    private func prepareShareImage() {
        guard !selectedVisits.isEmpty else { return }
        isPreparingShare = true
        Task { @MainActor in
            var rows: [MovieBestShareRow] = []
            for (index, visit) in selectedVisits.enumerated() {
                let reference = (visit.photos ?? [])
                    .filter { $0.mediaKind == "photo" && $0.hasStoredData && !$0.data.isEmpty }
                    .min { $0.createdAt < $1.createdAt }
                    .map { ThumbnailReference.photo($0.id) }
                    ?? visit.event.map { ThumbnailReference.event($0.id) }
                let image: UIImage? = if let reference {
                    await ThumbnailLoader.load(
                        reference: reference,
                        displaySize: CGSize(width: 180, height: 240),
                        displayScale: 2,
                        modelContext: modelContext
                    )
                } else {
                    nil
                }
                rows.append(
                    MovieBestShareRow(
                        rank: index + 1,
                        title: visit.event?.title.nonEmptyTrimmed ?? "映画記録",
                        date: visit.visitedAt,
                        rating: visit.overallRating,
                        note: visit.note.trimmingCharacters(in: .whitespacesAndNewlines),
                        image: image
                    )
                )
            }

            let renderer = ImageRenderer(
                content: MovieBestShareCard(period: period, rows: rows, tint: tint)
                    .frame(width: 390)
            )
            renderer.scale = 3
            if let image = renderer.uiImage {
                shareItems = [image]
            }
            isPreparingShare = false
        }
    }
}

private struct MovieBestRankRow: View {
    let rank: Int
    let visit: Visit
    let tint: Color

    private var reference: ThumbnailReference? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData && !$0.data.isEmpty }
            .min { $0.createdAt < $1.createdAt }
            .map { .photo($0.id) }
            ?? visit.event.map { .event($0.id) }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(tint)
                .frame(width: 24)

            CategoryEyecatchArtwork(
                reference: reference,
                templateKey: "movie",
                backgroundColor: tint.opacity(0.08),
                defaultContentMode: .fill
            ) { _ in
                Image(systemName: "film")
                    .foregroundStyle(tint.opacity(0.65))
            }
            .frame(width: 42, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(visit.event?.title.nonEmptyTrimmed ?? "映画記録")
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(visit.visitedAt.formatted(.dateTime.month().day()))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if visit.overallRating > 0 {
                Label(String(format: "%.1f", visit.overallRating), systemImage: "star.fill")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(tint)
                    .labelStyle(.titleAndIcon)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

struct MovieBestEditorView: View {
    let period: MovieBestPeriod
    let candidates: [Visit]
    let entries: [MovieBestEntry]
    let tint: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedVisitIDs: [UUID]
    @State private var isShowingLimitAlert = false

    init(period: MovieBestPeriod, candidates: [Visit], entries: [MovieBestEntry], tint: Color) {
        self.period = period
        self.candidates = candidates.sorted { $0.visitedAt > $1.visitedAt }
        self.entries = entries
        self.tint = tint
        _selectedVisitIDs = State(
            initialValue: MovieBestPolicy.orderedVisits(entries: entries, visits: candidates, period: period).map(\.id)
        )
    }

    private var visitsByID: [UUID: Visit] {
        Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
    }

    private var selectedVisits: [Visit] {
        selectedVisitIDs.compactMap { visitsByID[$0] }
    }

    private var unselectedVisits: [Visit] {
        candidates.filter { !selectedVisitIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if selectedVisits.isEmpty {
                        Text("下の映画記録から選んでください。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selectedVisits.enumerated()), id: \.element.id) { index, visit in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(tint)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visit.event?.title.nonEmptyTrimmed ?? "映画記録")
                                    Text(visit.visitedAt.formatted(.dateTime.year().month().day()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    selectedVisitIDs.removeAll { $0 == visit.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("選択から外す")
                            }
                        }
                        .onMove { source, destination in
                            selectedVisitIDs.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                } header: {
                    Text("選択中 \(selectedVisitIDs.count)／\(period.maximumCount)")
                } footer: {
                    Text("右上の並べ替えを押し、ドラッグして順位を変更できます。")
                }

                Section("この期間の映画記録") {
                    if unselectedVisits.isEmpty {
                        Text(candidates.isEmpty ? "対象になる映画記録はありません。" : "すべて選択済みです。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(unselectedVisits) { visit in
                            Button {
                                guard selectedVisitIDs.count < period.maximumCount else {
                                    isShowingLimitAlert = true
                                    return
                                }
                                selectedVisitIDs.append(visit.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(visit.event?.title.nonEmptyTrimmed ?? "映画記録")
                                            .foregroundStyle(.primary)
                                        Text(visit.visitedAt.formatted(.dateTime.year().month().day()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(period.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    EditButton()
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                }
            }
            .alert("選択できる上限です", isPresented: $isShowingLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(period.displayTitle)には最大\(period.maximumCount)作品まで選べます。")
            }
        }
    }

    private func save() {
        for entry in entries where entry.matches(period) {
            modelContext.delete(entry)
        }
        let now = Date()
        for (index, visitID) in selectedVisitIDs.prefix(period.maximumCount).enumerated() {
            modelContext.insert(
                MovieBestEntry(
                    period: period,
                    rank: index,
                    visitID: visitID,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct MovieBestShareRow {
    let rank: Int
    let title: String
    let date: Date
    let rating: Double
    let note: String
    let image: UIImage?
}

private struct MovieBestShareCard: View {
    let period: MovieBestPeriod
    let rows: [MovieBestShareRow]
    let tint: Color

    private var columns: [GridItem] {
        period.kind == .yearly
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Favoreco")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(tint)
                Text(period.displayTitle)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                Text("MOVIE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.rank) { row in
                    HStack(alignment: .top, spacing: 9) {
                        ZStack(alignment: .topLeading) {
                            Group {
                                if let image = row.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Rectangle()
                                        .fill(tint.opacity(0.10))
                                        .overlay(Image(systemName: "film").foregroundStyle(tint))
                                }
                            }
                            .frame(width: period.kind == .yearly ? 54 : 72, height: period.kind == .yearly ? 72 : 96)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                            Text("\(row.rank)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(tint, in: Circle())
                                .offset(x: -5, y: -5)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.system(size: period.kind == .yearly ? 13 : 17, weight: .semibold))
                                .lineLimit(2)
                            Text(row.date.formatted(.dateTime.month().day()))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            if row.rating > 0 {
                                Text("★ \(String(format: "%.1f", row.rating))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(tint)
                            }
                            if period.kind == .monthly, !row.note.isEmpty {
                                Text(row.note)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack {
                Text("記録から選んだ、わたしのベスト")
                Spacer()
                Text("#Favoreco")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), tint.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .light)
    }
}

private struct MovieBestActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension String {
    var nonEmptyTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
