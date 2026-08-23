import SwiftData
import SwiftUI

struct PlaceExperienceDetailSelection: Identifiable, Hashable {
    let placeID: UUID
    let categoryID: UUID

    var id: String { "\(categoryID.uuidString)-\(placeID.uuidString)" }
}

struct PlaceExperienceDetailDestination: View {
    @Query private var places: [PlaceMaster]
    @Query private var categories: [RecordCategory]

    init(placeID: UUID, categoryID: UUID) {
        _places = Query(filter: #Predicate<PlaceMaster> { $0.id == placeID })
        _categories = Query(filter: #Predicate<RecordCategory> { $0.id == categoryID })
    }

    var body: some View {
        if let place = places.first, let category = categories.first {
            PlaceExperienceDetailView(place: place, category: category)
        } else {
            FavorecoContentUnavailableView(
                "施設が見つかりません",
                systemImage: "mappin.slash",
                description: "場所マスターが削除または統合された可能性があります。"
            )
        }
    }
}

struct PlaceMasterFacilityRow: View {
    let place: PlaceMaster
    let category: RecordCategory
    let plans: [Plan]
    let visits: [Visit]
    let tint: Color

    private var upcomingCount: Int {
        plans.filter { $0.hasConfirmedSchedule && $0.startsAt >= Date() }.count
    }

    private var visitLabel: String {
        switch category.templateKey {
        case "theme_park": "来園"
        case "museum": "来館"
        default: "訪問"
        }
    }

    private var visitCount: Int {
        PlaceFacilityCardMetrics.uniqueVisitDayCount(in: visits)
    }

    var body: some View {
        HStack(spacing: 12) {
            PlaceMasterEyecatch(imageData: place.imageData, tint: tint)
                .frame(width: 82, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name.isEmpty ? "名称未設定" : place.name)
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    if upcomingCount > 0 {
                        Label("予定\(upcomingCount)件", systemImage: "calendar")
                    }
                    if visitCount > 0 {
                        Label("\(visitLabel)\(visitCount)回", systemImage: "checkmark.circle")
                    }
                    if upcomingCount == 0 && visitCount == 0 {
                        Text("登録済み")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    tint.opacity(0.22),
                    lineWidth: CategoryDetailChrome.borderLineWidth
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("施設の詳細を開きます")
    }
}

enum PlaceFacilityCardMetrics {
    static func uniqueVisitDayCount(
        in visits: [Visit],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        Set(visits.map { calendar.startOfDay(for: $0.visitedAt) }).count
    }

    static func recentPhotos(in visits: [Visit], limit: Int = 8) -> [PhotoBlob] {
        guard limit > 0 else { return [] }
        return visits
            .sorted { lhs, rhs in
                if lhs.visitedAt != rhs.visitedAt { return lhs.visitedAt > rhs.visitedAt }
                return lhs.updatedAt > rhs.updatedAt
            }
            .flatMap { visit in
                (visit.photos ?? [])
                    .filter { $0.mediaKind == "photo" && $0.hasStoredData }
                    .sorted { $0.createdAt > $1.createdAt }
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct PlaceMasterFacilityGridCard: View {
    let place: PlaceMaster
    let category: RecordCategory
    let plans: [Plan]
    let visits: [Visit]
    let tint: Color
    let onOpen: () -> Void

    private var upcomingCount: Int {
        plans.filter { $0.hasConfirmedSchedule && $0.startsAt >= Date() }.count
    }

    private var visitLabel: String {
        switch category.templateKey {
        case "theme_park": "来園"
        case "museum": "来館"
        default: "訪問"
        }
    }

    private var visitCount: Int {
        PlaceFacilityCardMetrics.uniqueVisitDayCount(in: visits)
    }

    private var recentPhotos: [PhotoBlob] {
        PlaceFacilityCardMetrics.recentPhotos(in: visits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlaceMasterEyecatch(imageData: place.imageData, tint: tint)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name.isEmpty ? "名称未設定" : place.name)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

                Label {
                    Text(place.address.isEmpty ? "住所未登録" : place.address)
                        .lineLimit(2)
                } icon: {
                    FavorecoIcon(systemName: "mappin.and.ellipse", size: 11)
                }
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 4) {
                    if upcomingCount > 0 {
                        Label("予定\(upcomingCount)件", systemImage: "calendar")
                    }
                    Label("\(visitLabel)\(visitCount)回", systemImage: "checkmark.circle")
                }
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, recentPhotos.isEmpty ? 10 : 8)

            if !recentPhotos.isEmpty {
                Divider()
                    .overlay(tint.opacity(0.16))

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(recentPhotos) { photo in
                            ThumbnailImage(
                                reference: .photo(photo.id),
                                displaySize: CGSize(width: 44, height: 44),
                                contentMode: .fill
                            ) {
                                tint.opacity(0.10)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(tint.opacity(0.28), lineWidth: 0.7)
                            }
                            .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 56)
                .accessibilityLabel("最新の\(visitLabel)写真\(recentPhotos.count)枚")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    tint.opacity(0.30),
                    lineWidth: CategoryDetailChrome.borderLineWidth
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("施設の詳細を開きます")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("施設詳細を開く"), onOpen)
    }

    private var accessibilitySummary: String {
        var parts = [
            place.name.isEmpty ? "名称未設定" : place.name,
            place.address.isEmpty ? "住所未登録" : place.address,
        ]
        if upcomingCount > 0 { parts.append("予定\(upcomingCount)件") }
        parts.append("\(visitLabel)\(visitCount)回")
        if !recentPhotos.isEmpty { parts.append("最新写真\(recentPhotos.count)枚") }
        return parts.joined(separator: "、")
    }
}

private struct PlaceExperienceDetailView: View {
    @Environment(\.favorecoThemePalette) private var themePalette
    let place: PlaceMaster
    let category: RecordCategory
    @State private var isShowingPlanCreation = false
    @State private var isShowingRecordCreation = false
    @State private var isShowingPlaceEdit = false

    private var tint: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    private var categoryPlans: [Plan] {
        (place.plans ?? [])
            .filter {
                !$0.isArchived
                    && ($0.category ?? $0.event?.category)?.id == category.id
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingPlans: [Plan] {
        categoryPlans.filter { $0.hasConfirmedSchedule && $0.startsAt >= Date() }
    }

    private var categoryVisits: [Visit] {
        (place.visits ?? [])
            .filter { $0.event?.category?.id == category.id }
            .sorted { $0.visitedAt > $1.visitedAt }
    }

    private var recordActionTitle: String {
        switch category.templateKey {
        case "theme_park": "来園を記録"
        case "museum": "鑑賞を記録"
        default: "体験を記録"
        }
    }

    private var recordSectionTitle: String {
        switch category.templateKey {
        case "theme_park": "来園記録"
        case "museum": "鑑賞記録"
        default: "体験記録"
        }
    }

    private var planActionTitle: String {
        category.templateKey == "museum" ? "観覧予定" : "行く予定"
    }

    private func planTitle(_ plan: Plan) -> String {
        let title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let eventTitle = plan.event?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return eventTitle.isEmpty ? place.name : eventTitle
    }

    private func planSubtitle(_ plan: Plan) -> String {
        let subtitle = plan.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subtitle.isEmpty { return subtitle }
        return VisitUnitFields(rawValue: plan.event?.unitFieldsRaw ?? "")
            .eventSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func visitSubtitle(_ visit: Visit) -> String {
        VisitUnitFields(rawValue: visit.unitFieldsRaw)
            .visitSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        PlaceMasterEyecatch(imageData: place.imageData, tint: tint)
                            .frame(width: 96, height: 64)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(place.name.isEmpty ? "名称未設定" : place.name)
                                .font(FavorecoTypography.jpSerif(24, weight: .semibold, relativeTo: .title2))
                            if !place.address.isEmpty {
                                Label(place.address, systemImage: "mappin.and.ellipse")
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if place.isClosed {
                                Text("閉館・閉園")
                                    .font(FavorecoTypography.captionStrong)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    if !place.officialURL.isEmpty, let url = URL(string: place.officialURL) {
                        Link(destination: url) {
                            FavorecoIconLabel("施設公式サイト", systemImage: "arrow.up.right.square", iconSize: 11)
                                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !place.name.isEmpty || !place.address.isEmpty || place.latitude != 0 || place.longitude != 0 {
                Section("場所・地図") {
                    PlaceMapPreview(
                        venueName: place.name,
                        address: place.address,
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                }
            }

            Section("これからの予定") {
                if upcomingPlans.isEmpty {
                    Text("予定はまだありません")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcomingPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(planTitle(plan))
                                    .font(FavorecoTypography.bodyStrong)
                                let subtitle = planSubtitle(plan)
                                if !subtitle.isEmpty, subtitle != planTitle(plan) {
                                    Text(subtitle)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(FavorecoDateText.compactDateTime(plan.startsAt))
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section(recordSectionTitle) {
                if categoryVisits.isEmpty {
                    Text("記録はまだありません")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categoryVisits) { visit in
                        NavigationLink {
                            ExperienceDetailView(visit: visit)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(visit.event?.title ?? place.name)
                                    .font(FavorecoTypography.bodyStrong)
                                let subtitle = visitSubtitle(visit)
                                if !subtitle.isEmpty, subtitle != visit.event?.title {
                                    Text(subtitle)
                                        .font(FavorecoTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(FavorecoDateText.compactDateTime(visit.visitedAt))
                                    .font(FavorecoTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !place.memo.isEmpty {
                Section("メモ") {
                    Text(place.memo)
                }
            }
        }
        .navigationTitle("施設詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingPlaceEdit = true
                } label: {
                    FavorecoIcon(systemName: "pencil", size: 16)
                }
                .accessibilityLabel("施設情報を編集")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    isShowingPlanCreation = true
                } label: {
                    FavorecoIconLabel(planActionTitle, systemImage: "calendar.badge.plus", iconSize: 16)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isShowingRecordCreation = true
                } label: {
                    FavorecoIconLabel(recordActionTitle, systemImage: "square.and.pencil", iconSize: 16)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(FavorecoTypography.captionStrong)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingPlanCreation) {
            AddTicketPlanView(
                entryMode: .plan,
                initialCategoryID: category.id,
                initialPlaceMaster: place
            )
            .favorecoRegistrationTheme(categoryHex: category.colorHex)
        }
        .sheet(isPresented: $isShowingRecordCreation) {
            AddExperienceView(
                category: category,
                initialPlaceMaster: place
            )
            .favorecoRegistrationTheme(categoryHex: category.colorHex)
        }
        .sheet(isPresented: $isShowingPlaceEdit) {
            NavigationStack {
                PlaceMasterEditDestination(placeID: place.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { isShowingPlaceEdit = false }
                        }
                    }
            }
        }
        .tint(tint)
    }
}
