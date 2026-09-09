import SwiftUI

enum SimpleCategoryRegistrationPurpose: String, CaseIterable, Identifiable {
    case interested
    case plan
    case visited

    var id: String { rawValue }
}

/// 映像作品／ミュージアムの登録は、目的選択と入力を1枚のシート内で完結させる。
/// 3フォームを同じ階層に保持し、切替後も入力途中のStateを破棄しない。
struct SimpleCategoryRegistrationView: View {
    let category: RecordCategory

    @State private var purpose: SimpleCategoryRegistrationPurpose = .interested

    private var isMovie: Bool { category.templateKey == "movie" }

    var body: some View {
        ZStack {
            registrationForm(for: .interested)
                .registrationPurposeVisibility(purpose == .interested)

            registrationForm(for: .plan)
                .registrationPurposeVisibility(purpose == .plan)

            registrationForm(for: .visited)
                .registrationPurposeVisibility(purpose == .visited)
        }
    }

    @ViewBuilder
    private func registrationForm(for item: SimpleCategoryRegistrationPurpose) -> some View {
        switch item {
        case .interested:
            QuickRegistrationView(
                initialTemplateKey: category.templateKey,
                screenTitle: isMovie ? "観たい作品を登録" : "気になる展示を登録",
                locksCategory: true,
                simpleRegistrationPurpose: $purpose
            )
        case .plan:
            AddTicketPlanView(
                entryMode: .plan,
                initialCategoryID: category.id,
                simpleRegistrationPurpose: $purpose
            )
        case .visited:
            AddExperienceView(
                category: category,
                simpleRegistrationPurpose: $purpose
            )
        }
    }
}

struct SimpleCategoryRegistrationPurposePicker: View {
    @Binding var selection: SimpleCategoryRegistrationPurpose

    let category: RecordCategory

    private var isMovie: Bool { category.templateKey == "movie" }

    var body: some View {
        RegistrationPurposeSelectionSection(
            guidanceText: description(for: selection),
            systemImage: icon(for: selection)
        ) {
            Picker("登録内容", selection: $selection) {
                ForEach(SimpleCategoryRegistrationPurpose.allCases) { item in
                    Text(title(for: item)).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func title(for purpose: SimpleCategoryRegistrationPurpose) -> String {
        switch purpose {
        case .interested: isMovie ? "観たい" : "気になる"
        case .plan: isMovie ? "観る予定" : "鑑賞予定"
        case .visited: "鑑賞済み"
        }
    }

    private func description(for purpose: SimpleCategoryRegistrationPurpose) -> String {
        switch purpose {
        case .interested:
            isMovie
                ? "日程を決めず、観たい作品として保存します。"
                : "日程を決めず、気になる展示として保存します。"
        case .plan:
            isMovie
                ? "作品情報と、観る予定の日時・場所を登録します。"
                : "展示情報と、鑑賞予定の日時・会場を登録します。"
        case .visited:
            isMovie
                ? "作品情報と、鑑賞した日時・場所・感想を登録します。"
                : "展示情報と、鑑賞した日時・会場・感想を登録します。"
        }
    }

    private func icon(for purpose: SimpleCategoryRegistrationPurpose) -> String {
        switch purpose {
        case .interested: "heart"
        case .plan: "calendar.badge.plus"
        case .visited: "square.and.pencil"
        }
    }

}

private extension View {
    func registrationPurposeVisibility(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }
}
