import SwiftUI

private struct TheaterLifecycleFlatLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var usesTheaterLifecycleFlatLayout: Bool {
        get { self[TheaterLifecycleFlatLayoutKey.self] }
        set { self[TheaterLifecycleFlatLayoutKey.self] = newValue }
    }
}

/// 観劇のフラット編集で共有する視覚トークン。
/// ページと入力面の明度差を保ち、入力欄の角丸は控えめにする。
enum TheaterLifecycleFlatStyle {
    static let fieldCornerRadius: CGFloat = 6
    static let actionCornerRadius: CGFloat = 8
    static let fieldBackground = Color(uiColor: .systemBackground)
    static let fieldBorder = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.30)
                : UIColor(red: 0.63, green: 0.57, blue: 0.59, alpha: 0.42)
        }
    )
    static let sectionBorder = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.22)
                : UIColor(red: 0.63, green: 0.57, blue: 0.59, alpha: 0.34)
        }
    )
    static let canvasBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.secondarySystemBackground
                : UIColor(red: 0.949, green: 0.933, blue: 0.938, alpha: 1)
        }
    )
}

/// 長い補足文を画面に常設せず、必要な時だけ表示する。
struct TheaterLifecycleInfoButton: View {
    let text: String
    var tint = Color(hex: "#8B2F45")

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("説明を表示")
        .accessibilityHint(text)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            Text(text)
                .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(idealWidth: 280, maxWidth: 310, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// 閉じた時にも編集ユニット同士の境界を残す共通カード面。
/// 展開時は同じ面の中へ入力内容を続け、見出しと本文を分断しない。
private struct TheaterLifecycleDisclosureSurface: ViewModifier {
    let isExpanded: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, isExpanded ? 14 : 10)
            .background(
                TheaterLifecycleFlatStyle.fieldBackground,
                in: RoundedRectangle(
                    cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius,
                    style: .continuous
                )
                .stroke(
                    TheaterLifecycleFlatStyle.sectionBorder.opacity(isExpanded ? 0.82 : 1),
                    lineWidth: 1
                )
            }
    }
}

extension View {
    func theaterLifecycleDisclosureSurface(isExpanded: Bool) -> some View {
        modifier(TheaterLifecycleDisclosureSurface(isExpanded: isExpanded))
    }
}

/// 観劇の気になる・予定・公演後記録を必ず同じシート型から開く。
/// 保存先は既存のEvent / Plan / Visit編集へ委譲し、入口差は初期展開だけに限定する。
struct TheaterLifecycleEditorSheet: View {
    private enum Source {
        case newRegistration(TheaterLifecycleRegistrationPurpose, categoryID: UUID?)
        case interested(ExperienceEvent)
        case planned(Plan)
        case recorded(Visit)
    }

    private let source: Source

    init(
        initialPurpose: TheaterLifecycleRegistrationPurpose = .interested,
        initialCategoryID: UUID? = nil
    ) {
        source = .newRegistration(initialPurpose, categoryID: initialCategoryID)
    }

    init(interested event: ExperienceEvent) {
        source = .interested(event)
    }

    init(planned plan: Plan) {
        source = .planned(plan)
    }

    init(recorded visit: Visit) {
        source = .recorded(visit)
    }

    var body: some View {
        lifecycleEditor
            .favorecoRegistrationTheme(categoryHex: categoryHex)
    }

    @ViewBuilder
    private var lifecycleEditor: some View {
        switch source {
        case .newRegistration(let purpose, let categoryID):
            AddTicketPlanView(
                entryMode: .unified,
                initialCategoryID: categoryID,
                initialUnifiedPurpose: purpose
            )
        case .interested(let event):
            EditEventView(event: event, usesTheaterLifecycleLayout: true)
        case .planned(let plan):
            EditExperienceView(plan: plan, usesTheaterLifecycleLayout: true)
        case .recorded(let visit):
            EditExperienceView(visit: visit, usesTheaterLifecycleLayout: true)
        }
    }

    private var categoryHex: String? {
        switch source {
        case .newRegistration:
            // 新規登録は選択中カテゴリを持つ親ルートのテーマを引き継ぐ。
            return nil
        case .interested(let event):
            return event.category?.colorHex
        case .planned(let plan):
            return plan.event?.category?.colorHex ?? plan.category?.colorHex
        case .recorded(let visit):
            return visit.event?.category?.colorHex
        }
    }
}

/// iPhone 16原寸を基準にした観劇編集の共通外枠。
struct TheaterLifecycleFlatScaffold<Content: View>: View {
    let title: String
    let canSave: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let content: Content

    init(
        title: String,
        canSave: Bool,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.canSave = canSave
        self.onClose = onClose
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")

                Spacer(minLength: 0)
                Text(title)
                    .font(FavorecoTypography.jpSans(18, weight: .semibold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)

                Button("保存", action: onSave)
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 44)
                    .background(Color(hex: "#8B2F45"), in: RoundedRectangle(cornerRadius: 11))
                    .opacity(canSave ? 1 : 0.38)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(TheaterLifecycleFlatStyle.fieldBackground)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TheaterLifecycleFlatStyle.canvasBackground)
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.usesTheaterLifecycleFlatLayout, true)
        .dynamicTypeSize(.xSmall ... .large)
    }
}

/// 既存の保存ロジックを保ったまま、同じ入力内容をFormまたは観劇フラット面へ載せる境界。
struct TheaterLifecycleEditorCanvas<Content: View>: View {
    let usesFlatLayout: Bool
    let title: String
    let canSave: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let content: Content

    init(
        usesFlatLayout: Bool,
        title: String,
        canSave: Bool,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.usesFlatLayout = usesFlatLayout
        self.title = title
        self.canSave = canSave
        self.onClose = onClose
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        if usesFlatLayout {
            TheaterLifecycleFlatScaffold(
                title: title,
                canSave: canSave,
                onClose: onClose,
                onSave: onSave
            ) {
                content
            }
        } else {
            Form {
                content
            }
            .favorecoRegistrationFormCanvas()
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
        }
    }
}

/// 予定から体験後まで、同じ編集シートをどの深さで開くかを表す。
enum RecordFormOpeningStage {
    case initialRecord
    case plannedTarget
    case afterExperience
}

/// 入口が違っても展開規則がずれないよう、予定・記録で共有する。
struct RecordLifecycleBlockExpansion: Equatable {
    let primary: Bool
    let memories: Bool
    let notes: Bool

    static func resolved(for stage: RecordFormOpeningStage) -> Self {
        switch stage {
        case .initialRecord:
            Self(primary: true, memories: false, notes: false)
        case .plannedTarget:
            Self(primary: true, memories: false, notes: false)
        case .afterExperience:
            Self(primary: false, memories: true, notes: false)
        }
    }
}

/// 予定・体験記録で共有する入力状態。
/// 見た目だけを揃えるのではなく、同じライフサイクル見出しで状態を伝える。
enum RecordUnitStatus {
    case required
    case entered
    case optional

    var title: String {
        switch self {
        case .required: "必須"
        case .entered: "入力済み"
        case .optional: "任意"
        }
    }

    var color: Color {
        switch self {
        case .required: .red
        case .entered: .green
        case .optional: .secondary
        }
    }
}

/// 予定・記録の双方が使う、3段階編集シートの共通ブロック。
/// 展開状態の正本は呼び出し側のBindingとし、入口ごとの初期状態を常に反映する。
struct StagedRecordBlock<Content: View>: View {
    let title: String
    let description: String
    let units: [RecordUnitDefinition]
    let status: (String) -> RecordUnitStatus
    let isExpanded: (String) -> Binding<Bool>
    let content: (RecordUnitDefinition) -> Content
    @Environment(\.usesTheaterLifecycleFlatLayout) private var usesFlatLayout

    init(
        title: String,
        description: String,
        units: [RecordUnitDefinition],
        isInitiallyExpanded _: Bool = true,
        status: @escaping (String) -> RecordUnitStatus,
        isExpanded: @escaping (String) -> Binding<Bool>,
        @ViewBuilder content: @escaping (RecordUnitDefinition) -> Content
    ) {
        self.title = title
        self.description = description
        self.units = units
        self.status = status
        self.isExpanded = isExpanded
        self.content = content
    }

    private var isGroupExpanded: Bool {
        units.contains { isExpanded($0.id).wrappedValue }
    }

    var body: some View {
        Group {
            if usesFlatLayout {
                VStack(alignment: .leading, spacing: 12) {
                    blockHeader
                    if isGroupExpanded {
                        expandedBlockContents
                    }
                }
                .theaterLifecycleDisclosureSurface(isExpanded: isGroupExpanded)
            } else {
                Section {
                    blockHeader
                    expandedBlockContents
                }
            }
        }
    }

    private var blockHeader: some View {
        Button(action: toggleGroup) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 10) {
                    if usesFlatLayout {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#8B2F45"))
                            .frame(width: 4, height: 24)
                    }
                    Text(displayTitle)
                        .font(
                            FavorecoTypography.jpSans(
                                usesFlatLayout ? 17 : 16,
                                weight: .semibold,
                                relativeTo: .headline
                            )
                        )
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if !usesFlatLayout {
                        statusCapsule(aggregateStatus)
                    }
                    Image(systemName: isGroupExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }

                if !usesFlatLayout {
                    Text(displayDescription)
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expandedBlockContents: some View {
        if isGroupExpanded {
            ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                VStack(alignment: .leading, spacing: 8) {
                    if units.count > 1 {
                        unitHeading(unit)
                    }

                    content(unit)
                        .padding(.bottom, 2)

                    if index < units.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func toggleGroup() {
        let nextValue = !isGroupExpanded
        for unit in units {
            isExpanded(unit.id).wrappedValue = nextValue
        }
    }

    private var displayTitle: String {
        guard usesFlatLayout else { return title }
        return switch title {
        case "鑑賞記録": "参加日時・会場"
        case "思い出": "評価・写真・同行者・感想"
        case "備考記録": "ToDo・費用・その他"
        default: title
        }
    }

    private var displayDescription: String {
        guard usesFlatLayout else { return description }
        return switch title {
        case "鑑賞記録": "観劇日、開場・開演・終演、会場、チケット"
        case "思い出": "評価、写真、同行者、感想・タグ"
        case "備考記録": "ToDo、費用、公式情報、読み取り結果"
        default: description
        }
    }

    private func unitHeading(_ unit: RecordUnitDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                if usesFlatLayout {
                    ExplicitFormFieldTitle(
                        title: unit.name,
                        isOptional: !unit.isRequired,
                        isRequired: unit.isRequired
                    )
                } else {
                    ExplicitFormProminentInlineLabel(
                        title: unit.name,
                        isOptional: !unit.isRequired,
                        isRequired: unit.isRequired,
                        width: nil
                    )
                }
                if usesFlatLayout,
                   !unit.description.isEmpty,
                   !compactUnitHeadingIDs.contains(unit.id) {
                    TheaterLifecycleInfoButton(text: unit.description)
                }
                Spacer(minLength: 8)
                if !usesFlatLayout {
                    statusCapsule(status(unit.id))
                }
            }

            if !usesFlatLayout,
               !unit.description.isEmpty,
               !compactUnitHeadingIDs.contains(unit.id) {
                Text(unit.description)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private var compactUnitHeadingIDs: Set<String> {
        [
            "theaterRating", "liveRating", "outingRating", "screenWorkRating", "bookRating",
            "photos", "planPhotos", "memo", "planMemo", "planTags",
        ]
    }

    private func statusCapsule(_ unitStatus: RecordUnitStatus) -> some View {
        Text(unitStatus.title)
            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
            .foregroundStyle(unitStatus.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(unitStatus.color.opacity(0.10), in: Capsule())
    }

    private var aggregateStatus: RecordUnitStatus {
        let statuses = units.map { status($0.id) }
        if statuses.contains(where: { if case .required = $0 { return true }; return false }) {
            return .required
        }
        if statuses.contains(where: { if case .entered = $0 { return true }; return false }) {
            return .entered
        }
        return .optional
    }
}
