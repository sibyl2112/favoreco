import SwiftUI

struct TheaterFocusPeopleEditor: View {
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]
    var existingReactionTagKeys: Binding<[UUID: Set<String>]> = .constant([:])

    @State private var editorTarget: FocusEditorTarget?

    private let tint = Color(hex: "#8B2F45")

    private var activeExistingLinks: [EventPersonLink] {
        existingLinks.filter { !deletedLinkIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("お目当て・注目した人")
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                TheaterLifecycleInfoButton(
                    text: "この観劇回で特に見た人だけを登録します。人物のMY FAVOや恒久的な推し設定には自動で追加されません。"
                )
                Spacer(minLength: 0)
                Text("任意")
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }

            if activeExistingLinks.isEmpty && pendingLinks.isEmpty {
                Text("まだ登録されていません")
                    .font(FavorecoTypography.jpSans(13, weight: .regular, relativeTo: .body))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(
                        TheaterLifecycleFlatStyle.fieldBackground,
                        in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    }
            } else {
                peopleRows
            }

            Button {
                editorTarget = .new
            } label: {
                Label("注目した人を追加", systemImage: "plus")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius)
                            .stroke(tint.opacity(0.72), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editorTarget) { target in
            TheaterFocusPersonSheet(
                target: target,
                personMasters: personMasters,
                onSave: save,
                onDelete: delete
            )
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private var peopleRows: some View {
        VStack(spacing: 0) {
            ForEach(activeExistingLinks) { link in
                focusRow(
                    name: displayName(for: link),
                    reading: link.person?.reading ?? "",
                    tagKeys: reactionKeys(for: link)
                ) {
                    editorTarget = .existing(
                        id: link.id,
                        name: displayName(for: link),
                        reading: link.person?.reading ?? "",
                        reactionKeys: reactionKeys(for: link)
                    )
                }
                if link.id != activeExistingLinks.last?.id || !pendingLinks.isEmpty { Divider() }
            }

            ForEach(pendingLinks) { pending in
                focusRow(
                    name: pending.name,
                    reading: pending.reading,
                    tagKeys: pending.relationshipTagKeys
                ) {
                    editorTarget = .pending(
                        id: pending.id,
                        name: pending.name,
                        reading: pending.reading,
                        reactionKeys: pending.relationshipTagKeys
                    )
                }
                if pending.id != pendingLinks.last?.id { Divider() }
            }
        }
        .background(
            TheaterLifecycleFlatStyle.fieldBackground,
            in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    private func focusRow(
        name: String,
        reading: String,
        tagKeys: [String],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.primary)
                    let details = rowDetails(reading: reading, tagKeys: tagKeys)
                    if !details.isEmpty {
                        Text(details)
                            .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("登録内容を編集します")
    }

    private func rowDetails(reading: String, tagKeys: [String]) -> String {
        let tags = tagKeys.map(TheaterFocusReaction.title(for:)).joined(separator: "・")
        return [reading.trimmingCharacters(in: .whitespacesAndNewlines), tags]
            .filter { !$0.isEmpty }
            .joined(separator: " ｜ ")
    }

    private func displayName(for link: EventPersonLink) -> String {
        link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物" : link.nameSnapshot
    }

    private func reactionKeys(for link: EventPersonLink) -> [String] {
        let values = existingReactionTagKeys.wrappedValue[link.id]
            ?? Set(TheaterFocusLinkMetadata(memo: link.memo).reactionKeys)
        return TheaterFocusReaction.orderedKeys(values)
    }

    private func save(_ draft: FocusPersonDraft, for target: FocusEditorTarget) {
        switch target {
        case .new:
            pendingLinks.append(draft.pendingLink)
        case let .pending(id, _, _, _):
            guard let index = pendingLinks.firstIndex(where: { $0.id == id }) else { return }
            pendingLinks[index].name = draft.name
            pendingLinks[index].reading = draft.reading
            pendingLinks[index].relationshipTagKeys = draft.reactionKeys
        case let .existing(id, _, _, _):
            existingReactionTagKeys.wrappedValue[id] = Set(draft.reactionKeys)
        }
        editorTarget = nil
    }

    private func delete(_ target: FocusEditorTarget) {
        switch target {
        case .new:
            break
        case let .pending(id, _, _, _):
            pendingLinks.removeAll { $0.id == id }
        case let .existing(id, _, _, _):
            deletedLinkIDs.insert(id)
        }
        editorTarget = nil
    }
}

private enum FocusEditorTarget: Identifiable {
    case new
    case pending(id: UUID, name: String, reading: String, reactionKeys: [String])
    case existing(id: UUID, name: String, reading: String, reactionKeys: [String])

    var id: String {
        switch self {
        case .new: "new"
        case let .pending(id, _, _, _): "pending-\(id.uuidString)"
        case let .existing(id, _, _, _): "existing-\(id.uuidString)"
        }
    }
}

private struct FocusPersonDraft {
    var name: String
    var reading: String
    var reactionKeys: [String]

    var pendingLink: PendingPersonLink {
        PendingPersonLink(
            name: name,
            reading: reading,
            role: .theaterFocus,
            relationshipTagKeys: reactionKeys
        )
    }
}

private struct TheaterFocusPersonSheet: View {
    let target: FocusEditorTarget
    let personMasters: [PersonMaster]
    let onSave: (FocusPersonDraft, FocusEditorTarget) -> Void
    let onDelete: (FocusEditorTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var reading: String
    @State private var selectedReactionKeys: Set<String>

    private let tint = Color(hex: "#8B2F45")

    init(
        target: FocusEditorTarget,
        personMasters: [PersonMaster],
        onSave: @escaping (FocusPersonDraft, FocusEditorTarget) -> Void,
        onDelete: @escaping (FocusEditorTarget) -> Void
    ) {
        self.target = target
        self.personMasters = personMasters
        self.onSave = onSave
        self.onDelete = onDelete
        switch target {
        case .new:
            _name = State(initialValue: "")
            _reading = State(initialValue: "")
            _selectedReactionKeys = State(initialValue: [])
        case let .pending(_, name, reading, reactionKeys),
             let .existing(_, name, reading, reactionKeys):
            _name = State(initialValue: name)
            _reading = State(initialValue: reading)
            _selectedReactionKeys = State(initialValue: Set(reactionKeys))
        }
    }

    private var isExisting: Bool {
        if case .existing = target { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        guard !isExisting else { return [] }
        return PersonMasterSuggestion.matching(
            personMasters,
            query: trimmedName,
            allowsOrganizations: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    personSection
                    reactionSection
                    if target.id != "new" {
                        Button(role: .destructive) {
                            onDelete(target)
                        } label: {
                            Text("この回から削除")
                                .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .overlay {
                                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius)
                                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TheaterLifecycleFlatStyle.canvasBackground)
        .tint(tint)
    }

    private var sheetHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button("保存") { save() }
                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(minWidth: 62, minHeight: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius))
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.38 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TheaterLifecycleFlatStyle.fieldBackground)
        .overlay {
            Text(target.id == "new" ? "注目した人を追加" : "注目した人を編集")
                .font(FavorecoTypography.jpSans(18, weight: .semibold, relativeTo: .headline))
                .lineLimit(1)
                .allowsHitTesting(false)
        }
    }

    private var personSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("人物")
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                TheaterLifecycleInfoButton(text: "登録済みの人物を検索できます。新しい名前は保存時に人物マスターへ登録されます。")
            }
            sheetField(title: "人物名", required: true, prompt: "名前を入力・検索", text: $name, disabled: isExisting)
            if !suggestions.isEmpty { suggestionList }
            sheetField(title: "よみがな", prompt: "例：もりた ゆう", text: $reading, disabled: isExisting)
        }
        .padding(14)
        .background(TheaterLifecycleFlatStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.20), lineWidth: 1) }
    }

    private var reactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("この回での印象")
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .headline))
                Text("任意・複数選択")
                    .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(TheaterFocusReaction.presets) { reaction in
                    let selected = selectedReactionKeys.contains(reaction.key)
                    Button {
                        if selected { selectedReactionKeys.remove(reaction.key) }
                        else { selectedReactionKeys.insert(reaction.key) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                            Text(reaction.title)
                                .lineLimit(1)
                        }
                        .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(selected ? tint : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selected ? tint.opacity(0.07) : TheaterLifecycleFlatStyle.fieldBackground,
                            in: RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                                .stroke(selected ? tint.opacity(0.6) : Color.secondary.opacity(0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(TheaterLifecycleFlatStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.20), lineWidth: 1) }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { person in
                Button {
                    name = person.displayName
                    reading = person.reading
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName).foregroundStyle(.primary)
                            Text(PersonMasterSuggestion.subtitle(for: person))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left").foregroundStyle(tint)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                if person.id != suggestions.last?.id { Divider() }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
        }
    }

    private func sheetField(
        title: String,
        required: Bool = false,
        prompt: String,
        text: Binding<String>,
        disabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                Text(required ? "必須" : "任意")
                    .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(required ? tint : Color.secondary)
            }
            TextField(prompt, text: text)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .padding(.horizontal, 12)
                .frame(minHeight: 50)
                .background(TheaterLifecycleFlatStyle.fieldBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
                .disabled(disabled)
                .foregroundStyle(disabled ? Color.secondary : Color.primary)
        }
    }

    private func save() {
        onSave(
            FocusPersonDraft(
                name: trimmedName,
                reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
                reactionKeys: TheaterFocusReaction.orderedKeys(selectedReactionKeys)
            ),
            target
        )
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
