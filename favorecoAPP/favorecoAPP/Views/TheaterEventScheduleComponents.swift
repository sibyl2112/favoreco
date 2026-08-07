import SwiftUI
import UIKit

struct TheaterEventUpcomingPlansSection: View {
    let event: ExperienceEvent
    let plans: [Plan]
    let representativePhoto: PhotoBlob?
    let accentColor: Color
    let onAddPlan: () -> Void
    let onOpenPlan: (UUID) -> Void

    @State private var showsAll = false

    private var displayedPlans: [Plan] {
        showsAll ? plans : Array(plans.prefix(1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                FavorecoIcon(systemName: "calendar.badge.clock", size: 17, fallbackWeight: .medium)
                    .foregroundStyle(accentColor)
                    .frame(width: 22)
                Text("次の予定")
                    .font(FavorecoTypography.jpSerif(18, weight: .semibold, relativeTo: .headline))
                Spacer(minLength: 8)
                Text("\(plans.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if plans.isEmpty {
                Button(action: onAddPlan) {
                    HStack(spacing: 10) {
                        FavorecoIcon(systemName: "calendar.badge.plus", size: 20)
                            .foregroundStyle(accentColor)
                            .frame(width: 34, height: 34)
                            .background(accentColor.opacity(0.10), in: Circle())
                        Text("次の観劇予定はまだありません")
                            .font(FavorecoTypography.bodyStrong)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("予定を追加")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.032), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(displayedPlans) { plan in
                    Button {
                        onOpenPlan(plan.id)
                    } label: {
                        FavorecoComingUpRow(
                            date: plan.startsAt,
                            categoryName: "観劇予定",
                            title: plan.title.isEmpty ? event.title : plan.title,
                            venue: resolvedVenue(for: plan),
                            tint: accentColor,
                            isTheater: false
                        ) {
                            TheaterEventScheduleArtwork(
                                event: event,
                                representativePhoto: representativePhoto,
                                accentColor: accentColor
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("予定詳細を開きます")
                }

                if plans.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(showsAll ? "予定を閉じる" : "ほか\(plans.count - 1)件の予定を見る")
                            Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        }
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
    }

    private func resolvedVenue(for plan: Plan) -> String {
        if !plan.venueNameSnapshot.isEmpty { return plan.venueNameSnapshot }
        return plan.placeMaster?.name ?? ""
    }
}

struct TheaterEventTicketProgressSection: View {
    let references: [TheaterEventTicketReference]
    let accentColor: Color
    let onOpenPlan: (UUID) -> Void

    @State private var selectedAttemptID: UUID?
    @State private var editingAttempt: TicketAttempt?

    init(
        references: [TheaterEventTicketReference],
        accentColor: Color,
        onOpenPlan: @escaping (UUID) -> Void
    ) {
        self.references = references
        self.accentColor = accentColor
        self.onOpenPlan = onOpenPlan
        _selectedAttemptID = State(initialValue: references.first?.id)
    }

    private var selectedReference: TheaterEventTicketReference? {
        references.first(where: { $0.id == selectedAttemptID }) ?? references.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                FavorecoIcon(systemName: "ticket", size: 17, fallbackWeight: .medium)
                    .foregroundStyle(accentColor)
                    .frame(width: 22)
                Text("チケット管理")
                    .font(FavorecoTypography.jpSerif(18, weight: .semibold, relativeTo: .headline))
                Spacer(minLength: 8)
                if let selectedReference {
                    Button {
                        editingAttempt = selectedReference.attempt
                    } label: {
                        FavorecoIconLabel("日付編集", systemImage: "pencil", iconSize: 13)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("申込日、当落日、入金期限、取得日を編集します")
                }
                Text("\(references.count)")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            if references.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    FavorecoIcon(systemName: "ticket", size: 20)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text("この公演のチケット情報はまだ登録されていません。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.032), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                if references.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(references) { reference in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.16)) {
                                        selectedAttemptID = reference.id
                                    }
                                } label: {
                                    Text(selectorTitle(for: reference))
                                        .font(FavorecoTypography.captionStrong)
                                        .foregroundStyle(selectedAttemptID == reference.id ? Color.white : accentColor)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 10)
                                        .frame(height: 28)
                                        .background(
                                            selectedAttemptID == reference.id ? accentColor : accentColor.opacity(0.10),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedAttemptID == reference.id ? .isSelected : [])
                            }
                        }
                    }
                }

                if let selectedReference {
                    VStack(alignment: .leading, spacing: 7) {
                        if references.count == 1 {
                            Text(TicketStatusDefinition.name(for: selectedReference.attempt.statusKey))
                                .font(FavorecoTypography.captionStrong)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.10), in: Capsule())
                        }

                        Button {
                            onOpenPlan(selectedReference.plan.id)
                        } label: {
                            CategoryTicketProgressCard(
                                item: CategoryTicketProgressItem(
                                    plan: selectedReference.plan,
                                    attempt: selectedReference.attempt
                                ),
                                tint: accentColor,
                                isTheater: false,
                                isLive: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("予定詳細を開きます")
                    }
                    .id(selectedReference.id)
                    .transition(.opacity)
                }
            }
        }
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
        .onChange(of: references.map(\.id)) { _, ids in
            if let selectedAttemptID, ids.contains(selectedAttemptID) { return }
            self.selectedAttemptID = ids.first
        }
        .sheet(item: $editingAttempt) { attempt in
            if let plan = attempt.plan {
                EditTicketAttemptView(plan: plan, attempt: attempt, prioritizesDates: true)
            } else {
                FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
            }
        }
    }

    private func selectorTitle(for reference: TheaterEventTicketReference) -> String {
        let item = CategoryTicketProgressItem(plan: reference.plan, attempt: reference.attempt)
        return "\(item.selectorTitle)・\(TicketStatusDefinition.name(for: reference.attempt.statusKey))"
    }
}

private struct TheaterEventScheduleArtwork: View {
    let event: ExperienceEvent
    let representativePhoto: PhotoBlob?
    let accentColor: Color

    var body: some View {
        TheaterPosterArtwork(
            reference: .event(event.id),
            backgroundColor: TheaterCategoryStyle.black
        ) { size in
            CategoryDefaultArtworkImage(
                templateKey: event.category?.templateKey ?? "theater",
                displaySize: size
            )
        }
    }
}
