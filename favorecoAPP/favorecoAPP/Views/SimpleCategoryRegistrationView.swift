import SwiftUI

enum SimpleCategoryRegistrationPurpose: String, CaseIterable, Identifiable {
    case interested
    case plan
    case visited

    var id: String { rawValue }
}

struct SimpleCategoryRegistrationView: View {
    @Environment(\.dismiss) private var dismiss

    let category: RecordCategory
    let onSelect: (SimpleCategoryRegistrationPurpose) -> Void

    @State private var purpose: SimpleCategoryRegistrationPurpose = .interested

    private var isMovie: Bool { category.templateKey == "movie" }

    var body: some View {
        NavigationStack {
            Form {
                FavorecoRegistrationSection("登録内容") {
                    Picker("登録内容", selection: $purpose) {
                        ForEach(SimpleCategoryRegistrationPurpose.allCases) { item in
                            Text(title(for: item)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Label(description(for: purpose), systemImage: icon(for: purpose))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        onSelect(purpose)
                    } label: {
                        Text("入力へ進む")
                            .font(FavorecoTypography.bodyStrong)
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    if !isMovie {
                        Text("作品・展示の基本情報を一度登録し、予定や鑑賞記録は同じ情報へ紐づけます。")
                    }
                }
            }
            .favorecoRegistrationFormCanvas()
            .navigationTitle(isMovie ? "作品を登録する" : "展示・イベントを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
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
            isMovie ? "日程を決めず、観たい作品として保存します。" : "日程を決めず、気になる展示として保存します。"
        case .plan:
            isMovie ? "作品情報と観る日時をまとめて登録します。" : "展示情報と鑑賞日時をまとめて登録します。"
        case .visited:
            isMovie ? "作品情報と今回の鑑賞記録を登録します。" : "展示情報と今回の鑑賞記録を登録します。"
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
