import SwiftUI

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
            Self(primary: true, memories: true, notes: false)
        case .afterExperience:
            Self(primary: false, memories: true, notes: true)
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
        Section {
            if isGroupExpanded {
                ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                    VStack(alignment: .leading, spacing: 12) {
                        if units.count > 1 {
                            unitHeading(unit)
                        }

                        content(unit)
                            .padding(.bottom, 4)
                    }

                    if index < units.count - 1 {
                        Divider()
                    }
                }
            }
        } header: {
            Button(action: toggleGroup) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(.primary)
                        Text(collapsedSummary)
                            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(.secondary.opacity(0.88))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    statusCapsule(aggregateStatus)
                    Image(systemName: isGroupExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .textCase(nil)
        }
    }

    private func toggleGroup() {
        let nextValue = !isGroupExpanded
        withAnimation(.easeInOut(duration: 0.18)) {
            for unit in units {
                isExpanded(unit.id).wrappedValue = nextValue
            }
        }
    }

    private func unitHeading(_ unit: RecordUnitDefinition) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(unit.name)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)
                Text(unit.description)
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary.opacity(0.88))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            statusCapsule(status(unit.id))
        }
    }

    private func statusCapsule(_ unitStatus: RecordUnitStatus) -> some View {
        Text(unitStatus.title)
            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
            .foregroundStyle(unitStatus.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(unitStatus.color.opacity(0.10), in: Capsule())
    }

    private var collapsedSummary: String {
        guard !isGroupExpanded else { return description }
        let enteredNames = units.compactMap { unit -> String? in
            if case .entered = status(unit.id) { return unit.name }
            return nil
        }
        return enteredNames.isEmpty ? description : enteredNames.joined(separator: "・")
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
