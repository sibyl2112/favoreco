import SwiftUI

struct TheaterFocusPeopleEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]
    var existingReactionTagKeys: Binding<[UUID: Set<String>]> = .constant([:])

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("お目当て・注目した人")
                    .font(FavorecoTypography.bodyStrong)
                Text("全キャストの登録は不要です。目当てだった人や、観劇後に気になった人だけ選びます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PeopleUnitEditor(
                existingLinks: existingLinks,
                deletedLinkIDs: $deletedLinkIDs,
                pendingLinks: $pendingLinks,
                personMasters: personMasters,
                roleOptions: [PersonRoleOption.theaterFocus],
                emptyDescription: "人物を登録しなくても観劇回を保存できます。",
                showsRolePicker: false,
                allowsOrganizations: false,
                namePlaceholder: "人物名",
                addButtonTitle: "注目した人を追加",
                relationshipTagOptions: TheaterFocusReaction.presets,
                existingRelationshipTagKeys: existingReactionTagKeys
            )
        }
    }
}

struct TheaterCreditsTextEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("公式サイトやパンフレットから、そのまま貼り付けられます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("例：\nハムレット：山田太郎\nオフィーリア：佐藤花子\n演出：鈴木一郎")
                        .font(FavorecoTypography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .frame(minHeight: 150)
            }
        }
    }
}
