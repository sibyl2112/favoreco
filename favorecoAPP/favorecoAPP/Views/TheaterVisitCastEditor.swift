import SwiftUI

struct TheaterFocusPeopleEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]
    var existingReactionTagKeys: Binding<[UUID: Set<String>]> = .constant([:])

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("お目当て・注目した人")
                    .font(
                        FavorecoTypography.jpSans(
                            ExplicitFormMetrics.labelFontSize,
                            weight: .semibold,
                            relativeTo: .body
                        )
                    )
                Text("この回で印象に残った人だけ選びます。")
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
                emptyDescription: "人物は選ばなくても保存できます。",
                showsRolePicker: false,
                allowsOrganizations: false,
                namePlaceholder: "人物名",
                addButtonTitle: "注目した人を追加",
                relationshipTagOptions: TheaterFocusReaction.presets,
                existingRelationshipTagKeys: existingReactionTagKeys,
                usesExplicitTheaterLayout: true
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
            ExplicitFormTextField(
                title: "キャスト・スタッフ（任意）",
                prompt: "役名：出演者、演出：担当者",
                text: $text,
                axis: .vertical,
                minimumLines: 5,
                maximumLines: 10,
                labelStyle: .horizontal,
                reservesLineSpace: true
            )
        }
    }
}
