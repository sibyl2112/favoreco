import SwiftUI

enum TheaterCategoryStyle {
    static let wine = Color(red: 0.28, green: 0.035, blue: 0.08)
    static let deepWine = Color(red: 0.11, green: 0.025, blue: 0.04)
    static let black = Color(red: 0.025, green: 0.02, blue: 0.022)
    static let tileBackground = Color(red: 0.075, green: 0.045, blue: 0.05).opacity(0.94)
    static let gold = Color(red: 0.82, green: 0.62, blue: 0.30)
    static let lightGold = Color(red: 0.96, green: 0.82, blue: 0.52)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.84)
    /// ワイン背景上で補助操作を読み取れる明るさに保つ観劇専用色。
    static let ticketActionRose = Color(red: 0.96, green: 0.43, blue: 0.58)
    /// チケット管理の補助情報用。操作色より一段抑え、状態の主役と競合させない。
    static let ticketMetadataRose = Color(red: 0.88, green: 0.32, blue: 0.47)
    static let brandGradient = LinearGradient(
        colors: [lightGold, Color(red: 0.70, green: 0.38, blue: 0.18), lightGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ArchivedTheaterEventsEntry: View {
    let category: RecordCategory
    let onOpen: () -> Void

    var body: some View {
        let archivedCount = (category.events ?? []).lazy.filter(\.isArchived).count
        if archivedCount > 0 {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    FavorecoIcon(systemName: "archivebox", size: 16)
                        .foregroundStyle(TheaterCategoryStyle.gold)
                        .frame(width: 30, height: 30)
                        .background(TheaterCategoryStyle.gold.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("非表示の公演")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(TheaterCategoryStyle.ivory)
                        Text("一覧から公演を再表示できます")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
                    }

                    Spacer(minLength: 8)

                    Text("\(archivedCount)件")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(TheaterCategoryStyle.gold)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.52))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    TheaterCategoryStyle.tileBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TheaterCategoryStyle.gold.opacity(0.34), lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("非表示にした公演の一覧を開きます")
        }
    }
}

struct TheaterPosterView: View {
    let event: ExperienceEvent?
    let width: CGFloat

    private var height: CGFloat {
        width / CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
    }

    var body: some View {
        TheaterPosterArtwork(
            reference: event.map { .event($0.id) },
            backgroundColor: TheaterCategoryStyle.black
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: "theater",
                displaySize: size
            )
        }
        .frame(width: width, height: height)
        .overlay {
            Rectangle()
                .stroke(
                    TheaterCategoryStyle.gold.opacity(CategoryLibraryChrome.artworkBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
    }
}
struct TheaterSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(FavorecoTypography.jpSerif(20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(TheaterCategoryStyle.ivory)
            Spacer()
            Text("\(count)")
                .font(FavorecoTypography.captionStrong)
                .foregroundStyle(TheaterCategoryStyle.gold)
        }
    }
}

struct TheaterEventRow: View {
    let snapshot: CategoryEventSnapshot
    let event: ExperienceEvent
    let onAddVisit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            NavigationLink {
                CategoryEventDestination(eventID: event.id)
            } label: {
                HStack(spacing: 13) {
                    TheaterPosterView(event: event, width: 72)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(event.title.isEmpty ? "記録" : event.title)
                            .font(FavorecoTypography.jpSerif(18, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(TheaterCategoryStyle.ivory)
                            .lineLimit(2)

                        if !event.seriesName.isEmpty {
                            Text(event.seriesName)
                                .lineLimit(1)
                        }

                        HStack(spacing: 9) {
                            FavorecoIconLabel("\(snapshot.visitCount)件", systemImage: "number", iconSize: 12)
                            if let latestVisitDate = snapshot.latestVisitDate {
                                FavorecoIconLabel(
                                    FavorecoDateText.compactDate(latestVisitDate),
                                    systemImage: "calendar",
                                    iconSize: 12
                                )
                            }
                        }
                    }
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button(action: onAddVisit) {
                FavorecoIcon(systemName: "plus", size: 13, fallbackWeight: .semibold)
                    .foregroundStyle(TheaterCategoryStyle.gold)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle().stroke(TheaterCategoryStyle.gold.opacity(0.65), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("この対象に回を追加")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    TheaterCategoryStyle.gold.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
    }
}

struct TheaterVisitRow: View {
    let visit: Visit

    private var event: ExperienceEvent? { visit.event }

    private var performancePeriodTitle: String {
        isMatinee ? "マチネ" : "ソワレ"
    }

    private var isMatinee: Bool {
        Calendar.autoupdatingCurrent.component(.hour, from: visit.visitedAt) < 17
    }

    private var performancePeriodColor: Color {
        isMatinee
            ? TheaterCategoryStyle.lightGold
            : Color(red: 0.70, green: 0.74, blue: 0.90)
    }

    private var performancePeriodIcon: String {
        isMatinee ? "sun.max.fill" : "moon.stars.fill"
    }

    private var performanceTimeText: String {
        let endDate = visit.endedAt > visit.visitedAt ? visit.endedAt : visit.visitedAt
        return "\(FavorecoDateText.time(visit.visitedAt))-\(FavorecoDateText.time(endDate))"
    }

    private var performancePeriodBadge: some View {
        HStack(spacing: 3) {
            FavorecoIcon(systemName: performancePeriodIcon, size: 8, fallbackWeight: .semibold)
            Text(performancePeriodTitle)
                .font(FavorecoTypography.jpSans(9, weight: .semibold, relativeTo: .caption2))
        }
        .foregroundStyle(performancePeriodColor)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(
            performancePeriodColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(performancePeriodTitle)
    }

    var body: some View {
        HStack(spacing: 13) {
            TheaterPosterView(event: event, width: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(event?.title.isEmpty == false ? event?.title ?? "観劇記録" : "観劇記録")
                    .font(FavorecoTypography.jpSerif(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    FavorecoIconLabel(
                        "\(FavorecoDateText.compactDate(visit.visitedAt))  \(performanceTimeText)",
                        systemImage: "calendar",
                        iconSize: 12
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                    Spacer(minLength: 0)

                    performancePeriodBadge
                }
                if !visit.venueNameSnapshot.isEmpty {
                    FavorecoIconLabel(visit.venueNameSnapshot, systemImage: "mappin.and.ellipse", iconSize: 12)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(FavorecoTypography.caption)
            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TheaterCategoryStyle.gold.opacity(0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    TheaterCategoryStyle.gold.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
    }
}

struct TheaterPerformanceLogLayoutPicker: View {
    @Binding var selection: TheaterPerformanceLogLayoutMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TheaterPerformanceLogLayoutMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            selection == mode
                                ? TheaterCategoryStyle.deepWine
                                : TheaterCategoryStyle.gold
                        )
                        .frame(width: 30, height: 28)
                        .background(
                            selection == mode
                                ? TheaterCategoryStyle.lightGold
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.displayName)表示")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            TheaterCategoryStyle.gold.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.24), lineWidth: 0.75)
        }
    }
}

struct TheaterVisitCompactGrid: View {
    let visits: [Visit]
    let onSelect: (Visit) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 2
    )

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(visits) { visit in
                Button {
                    onSelect(visit)
                } label: {
                    TheaterVisitCompactCard(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TheaterVisitCompactCard: View {
    let visit: Visit

    private let cardHeight: CGFloat = 112

    private var artworkHeight: CGFloat {
        cardHeight - 16
    }

    private var artworkWidth: CGFloat {
        artworkHeight * CGFloat(EyecatchAspectRatio.bSeriesPoster.value)
    }

    private var event: ExperienceEvent? {
        visit.event
    }

    private var title: String {
        guard let event, !event.title.isEmpty else {
            return "観劇記録"
        }
        return event.title
    }

    private var performanceTimeText: String {
        let endDate = visit.endedAt > visit.visitedAt ? visit.endedAt : visit.visitedAt
        return "\(FavorecoDateText.time(visit.visitedAt))-\(FavorecoDateText.time(endDate))"
    }

    private var dateText: String {
        FavorecoDateText.compactDateWithHalfWidthWeekday(visit.visitedAt)
    }

    private var venueText: String {
        let trimmed = visit.venueNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TheaterPosterArtwork(
                reference: event.map { .event($0.id) },
                backgroundColor: TheaterCategoryStyle.black
            ) { size in
                CategoryDefaultArtworkImage(templateKey: "theater", displaySize: size)
            }
            .frame(width: artworkWidth, height: artworkHeight)
            .overlay {
                Rectangle()
                    .stroke(
                        TheaterCategoryStyle.gold.opacity(CategoryLibraryChrome.artworkBorderOpacity),
                        lineWidth: CategoryLibraryChrome.borderLineWidth
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FavorecoTypography.jpSans(10.5, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                    .tracking(-0.35)
                    .lineSpacing(-2)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                FavorecoIconLabel(dateText, systemImage: "calendar", iconSize: 9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                FavorecoIconLabel(performanceTimeText, systemImage: "clock", iconSize: 9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                FavorecoIconLabel(venueText, systemImage: "mappin.and.ellipse", iconSize: 9)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(FavorecoTypography.jpSans(8.5, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .frame(
            maxWidth: .infinity,
            minHeight: cardHeight,
            maxHeight: cardHeight,
            alignment: .topLeading
        )
        .background(
            TheaterCategoryStyle.tileBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    TheaterCategoryStyle.gold.opacity(CategoryLibraryChrome.cardBorderOpacity),
                    lineWidth: CategoryLibraryChrome.borderLineWidth
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)、\(dateText)、\(performanceTimeText)、\(venueText)")
    }
}

struct TheaterEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoIcon(systemName: icon, size: 20)
                .foregroundStyle(TheaterCategoryStyle.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(TheaterCategoryStyle.ivory)
                Text(message)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(TheaterCategoryStyle.ivory.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TheaterCategoryStyle.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TheaterCategoryStyle.gold.opacity(0.42), lineWidth: 0.7)
        }
    }
}
