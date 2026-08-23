import PhotosUI
import SwiftUI

private struct TheaterCreditEditorTarget: Identifiable {
    let id = UUID()
    let pendingID: UUID?
    let existingLinkID: UUID?
    let initialValue: PendingPersonLink?

    static var new: TheaterCreditEditorTarget {
        TheaterCreditEditorTarget(pendingID: nil, existingLinkID: nil, initialValue: nil)
    }
}

struct TheaterCreditTextParser {
    private struct RoleRule {
        let labels: [String]
        let roleKey: String
    }

    private static let roleRules: [RoleRule] = [
        RoleRule(labels: ["アンサンブルキャスト", "アンサンブル", "キャスト", "出演", "俳優"], roleKey: "cast"),
        RoleRule(labels: ["主演"], roleKey: "lead"),
        RoleRule(labels: ["日替わりゲスト"], roleKey: "daily_guest"),
        RoleRule(labels: ["ゲスト"], roleKey: "guest"),
        RoleRule(labels: ["演出"], roleKey: "stage_director"),
        RoleRule(labels: ["脚本"], roleKey: "screenplay"),
        RoleRule(labels: ["原作"], roleKey: "original_work"),
        RoleRule(labels: ["振付"], roleKey: "choreography"),
        RoleRule(labels: ["音楽"], roleKey: "music"),
        RoleRule(labels: ["指揮"], roleKey: "conductor"),
        RoleRule(labels: ["演奏"], roleKey: "performer"),
        RoleRule(labels: ["美術"], roleKey: "stage_design"),
        RoleRule(labels: ["照明"], roleKey: "lighting"),
        RoleRule(labels: ["音響"], roleKey: "sound"),
        RoleRule(labels: ["衣裳", "衣装"], roleKey: "costume"),
        RoleRule(labels: ["ヘアメイク"], roleKey: "hair_makeup"),
        RoleRule(labels: ["舞台監督"], roleKey: "stage_manager"),
        RoleRule(labels: ["上演団体"], roleKey: "performing_organization"),
        RoleRule(labels: ["主催"], roleKey: "organizer"),
        RoleRule(labels: ["制作"], roleKey: "production"),
        RoleRule(labels: ["企画"], roleKey: "planning"),
        RoleRule(labels: ["招聘", "提供"], roleKey: "presenter"),
    ]

    static func parse(_ text: String) -> [PendingPersonLink] {
        var currentRole: PersonRoleOption?
        var results: [PendingPersonLink] = []
        var seen = Set<String>()

        for line in logicalLines(from: text) {
            guard !line.isEmpty, !isIgnoredLine(line) else { continue }

            if let headingRole = roleForExactLabel(line) {
                currentRole = headingRole
                continue
            }

            let parsed: PendingPersonLink?
            if let parts = splitCreditLine(line) {
                if let matched = roleMatch(for: parts.left) {
                    currentRole = matched.role
                    parsed = makeLink(
                        name: parts.right,
                        role: matched.role,
                        roleDetail: matched.detail
                    )
                } else {
                    parsed = makeLink(
                        name: parts.right,
                        role: currentRole ?? PersonRoleOption.defaultOption,
                        roleDetail: parts.left
                    )
                }
            } else if let currentRole, looksLikeStandaloneName(line) {
                parsed = makeLink(name: line, role: currentRole, roleDetail: "")
            } else {
                parsed = nil
            }

            guard let parsed else { continue }
            let key = normalizedKey(parsed)
            guard seen.insert(key).inserted else { continue }
            results.append(parsed)
        }
        return results
    }

    private static func logicalLines(from text: String) -> [String] {
        var lines: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = cleanedLine(rawLine)
            guard !line.isEmpty else { continue }
            if (line.hasPrefix("（") || line.hasPrefix("(")),
               let previous = lines.last,
               previous.contains(":") || previous.contains("：") {
                lines[lines.count - 1] = previous + line
            } else {
                lines.append(line)
            }
        }
        return lines
    }

    private static func cleanedLine(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "・●○■□◆◇▪︎▸▶︎-—–"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitCreditLine(_ line: String) -> (left: String, right: String)? {
        guard let separator = line.firstIndex(where: { $0 == "：" || $0 == ":" }) else { return nil }
        let left = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
        let right = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty, !right.isEmpty else { return nil }
        return (left, right)
    }

    private static func roleForExactLabel(_ line: String) -> PersonRoleOption? {
        let compact = line.replacingOccurrences(of: " ", with: "")
        for rule in roleRules {
            if rule.labels.contains(where: { compact == $0 }) {
                return PersonRoleOption.option(for: rule.roleKey)
            }
        }
        return nil
    }

    private static func roleMatch(for label: String) -> (role: PersonRoleOption, detail: String)? {
        let compact = label.replacingOccurrences(of: " ", with: "")
        for rule in roleRules {
            for candidate in rule.labels.sorted(by: { $0.count > $1.count }) where compact.hasPrefix(candidate) {
                let detail = String(compact.dropFirst(candidate.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "（）()・ "))
                return (PersonRoleOption.option(for: rule.roleKey), detail)
            }
        }
        return nil
    }

    private static func makeLink(
        name: String,
        role: PersonRoleOption,
        roleDetail: String
    ) -> PendingPersonLink? {
        let cleanedName = cleanedLine(name)
        guard looksLikeStandaloneName(cleanedName) else { return nil }
        return PendingPersonLink(
            name: cleanedName,
            role: role,
            roleDetail: roleDetail.trimmingCharacters(in: .whitespacesAndNewlines),
            entityKind: role.defaultsToOrganization ? .organization : .person
        )
    }

    private static func looksLikeStandaloneName(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...60).contains(value.count) else { return false }
        guard !value.hasPrefix("※"), !value.contains("http"), !value.contains("非公開") else { return false }
        return !value.contains("この役のみ") && !value.contains("役名は")
    }

    private static func isIgnoredLine(_ line: String) -> Bool {
        line.hasPrefix("※")
            || line.hasPrefix("注：")
            || line.hasPrefix("注:")
            || line.contains("会員登録")
            || line.contains("ログイン")
    }

    private static func normalizedKey(_ value: PendingPersonLink) -> String {
        [value.name, value.role.key, value.roleDetail]
            .joined(separator: "|")
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: " ", with: "")
    }
}

/// 公演全体へ保存するキャスト・スタッフ入力。
/// 改行テキストの一括入力と、PersonMasterへつなぐ個別登録を同じユニットで扱う。
struct TheaterEventCreditsEditor: View {
    @Binding var bulkText: String
    let existingLinks: [EventPersonLink]
    @Binding var deletedLinkIDs: Set<UUID>
    @Binding var pendingLinks: [PendingPersonLink]
    let personMasters: [PersonMaster]
    var showsHeader = true

    @AppStorage(AppStorageKeys.usesOCRImportAssist) private var usesOCRImportAssist = true
    @State private var selectedOCRItem: PhotosPickerItem?
    @State private var isReadingImage = false
    @State private var importStatus = ""
    @State private var pastedText = ""
    @State private var showsTextImport = false
    @State private var personEditorTarget: TheaterCreditEditorTarget?

    private let tint = Color(hex: "#8B2F45")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("一括入力")
                        .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                    Text("任意")
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                importActions
            }

            TextEditor(text: $bulkText)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 118, maxHeight: 170)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    TheaterLifecycleFlatStyle.fieldBackground,
                    in: RoundedRectangle(
                        cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                        style: .continuous
                    )
                        .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if bulkText.isEmpty {
                        Text("エレナ役：佐倉ミナ\n演出：月島レン")
                            .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }

            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("個別登録")
                    .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                TheaterLifecycleInfoButton(
                    text: "人物ごとに担当・役名・よみがなを設定できます。個別に登録すると、人物検索や観劇後の注目人物へ引き継ぎます。"
                )
            }

            if !existingLinks.isEmpty || !pendingLinks.isEmpty {
                creditRows
            }

            Button {
                personEditorTarget = .new
            } label: {
                Label("キャスト・スタッフを追加", systemImage: "plus")
                    .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius,
                            style: .continuous
                        )
                            .stroke(tint.opacity(0.72), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showsTextImport) {
            TheaterCreditsTextImportSheet(text: $pastedText) {
                let addedCount = appendImportedText(pastedText)
                importStatus = importStatusText(addedCount: addedCount, source: "貼り付け")
                pastedText = ""
                showsTextImport = false
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
        }
        .sheet(item: $personEditorTarget) { target in
            TheaterCreditPersonSheet(
                personMasters: personMasters,
                initialValue: target.initialValue
            ) { pending in
                applyEditedCredit(pending, target: target)
                personEditorTarget = nil
            }
            .presentationDetents([.fraction(0.76), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .onChange(of: selectedOCRItem) { _, item in
            guard let item else { return }
            Task { await readText(from: item) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 4, height: 28)
            Text("キャスト・スタッフ")
                .font(FavorecoTypography.jpSans(19, weight: .semibold, relativeTo: .headline))
            TheaterLifecycleInfoButton(
                text: "公式サイトやパンフレットから、画像OCR・テキスト貼付け・直接入力でまとめて登録できます。"
            )
            Spacer(minLength: 0)
        }
    }

    private var importActions: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedOCRItem, matching: .images) {
                compactImportButtonLabel(
                    title: isReadingImage ? "読取中" : "画像OCR",
                    systemImage: "viewfinder"
                )
            }
            .disabled(!usesOCRImportAssist || isReadingImage)
            .accessibilityHint(usesOCRImportAssist ? "画像から文字を読み取ります" : "設定で画像OCRを有効にしてください")

            Button {
                showsTextImport = true
            } label: {
                compactImportButtonLabel(title: "テキスト貼付", systemImage: "doc.text")
            }
            .buttonStyle(.plain)
        }
    }

    private func compactImportButtonLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .regular))
                .frame(width: 42, height: 36)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: TheaterLifecycleFlatStyle.actionCornerRadius,
                        style: .continuous
                    )
                        .stroke(tint.opacity(0.72), lineWidth: 1)
                )
            Text(title)
                .font(FavorecoTypography.jpSans(9.5, weight: .semibold, relativeTo: .caption2))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
    }

    private var creditRows: some View {
        VStack(spacing: 0) {
            ForEach(existingLinks) { link in
                creditRow(
                    name: link.nameSnapshot.isEmpty ? link.person?.displayName ?? "人物" : link.nameSnapshot,
                    role: PersonRoleOption.option(for: link.roleKey).name,
                    roleDetail: roleDetail(for: link),
                    isHighlighted: TheaterEventCreditMetadata.isHighlighted(link),
                    onEdit: { personEditorTarget = editorTarget(for: link) }
                ) {
                    deletedLinkIDs.insert(link.id)
                }
                if link.id != existingLinks.last?.id || !pendingLinks.isEmpty { Divider() }
            }
            ForEach(pendingLinks) { pending in
                creditRow(
                    name: pending.name,
                    role: pending.role.name,
                    roleDetail: pending.roleDetail,
                    isHighlighted: pending.isEventFocus,
                    onEdit: {
                        personEditorTarget = TheaterCreditEditorTarget(
                            pendingID: pending.id,
                            existingLinkID: nil,
                            initialValue: pending
                        )
                    }
                ) {
                    pendingLinks.removeAll { $0.id == pending.id }
                }
                if pending.id != pendingLinks.last?.id { Divider() }
            }
        }
        .overlay(
            RoundedRectangle(
                cornerRadius: TheaterLifecycleFlatStyle.fieldCornerRadius,
                style: .continuous
            )
                .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
        )
    }

    private func creditRow(
        name: String,
        role: String,
        roleDetail: String,
        isHighlighted: Bool,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: onEdit) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(role)
                            if !roleDetail.isEmpty {
                                Text("・")
                                Text(roleDetail)
                            }
                        }
                        .font(FavorecoTypography.jpSans(12.5, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    if isHighlighted {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                            .accessibilityLabel("注目キャスト")
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)を編集")

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)を削除")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
    }

    private func editorTarget(for link: EventPersonLink) -> TheaterCreditEditorTarget {
        let role = PersonRoleOption.option(for: link.roleKey)
        let person = link.person
        let affiliationName: String = if let organizationID = person?.parentOrganizationID {
            personMasters.first(where: { $0.id == organizationID })?.displayName ?? ""
        } else {
            ""
        }
        return TheaterCreditEditorTarget(
            pendingID: nil,
            existingLinkID: link.id,
            initialValue: PendingPersonLink(
                name: link.nameSnapshot.isEmpty ? person?.displayName ?? "" : link.nameSnapshot,
                reading: person?.reading ?? "",
                role: role,
                roleDetail: roleDetail(for: link),
                affiliationName: affiliationName,
                parentOrganizationID: person?.parentOrganizationID,
                isEventFocus: TheaterEventCreditMetadata.isHighlighted(link)
            )
        )
    }

    private func roleDetail(for link: EventPersonLink) -> String {
        let displayRole = link.displayRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseRole = PersonRoleOption.option(for: link.roleKey).name
        guard !displayRole.isEmpty, displayRole != baseRole else { return "" }
        if let separator = displayRole.firstIndex(of: "｜") {
            return String(displayRole[displayRole.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return displayRole
    }

    private func applyEditedCredit(_ updated: PendingPersonLink, target: TheaterCreditEditorTarget) {
        if let pendingID = target.pendingID,
           let index = pendingLinks.firstIndex(where: { $0.id == pendingID }) {
            pendingLinks[index].name = updated.name
            pendingLinks[index].reading = updated.reading
            pendingLinks[index].role = updated.role
            pendingLinks[index].roleDetail = updated.roleDetail
            pendingLinks[index].affiliationName = updated.affiliationName
            pendingLinks[index].entityKind = updated.entityKind
            pendingLinks[index].parentOrganizationID = updated.parentOrganizationID
            pendingLinks[index].isEventFocus = updated.isEventFocus
            return
        }
        if let existingLinkID = target.existingLinkID {
            deletedLinkIDs.insert(existingLinkID)
        }
        pendingLinks.append(updated)
    }

    @MainActor
    private func readText(from item: PhotosPickerItem) async {
        isReadingImage = true
        importStatus = "画像から文字を読み取っています"
        defer {
            isReadingImage = false
            selectedOCRItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            importStatus = "画像を読み込めませんでした"
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            QuickCaptureImageService.recognizedText(from: data)
        }.value
        guard !result.isEmpty else {
            importStatus = "文字を読み取れませんでした。必要なら直接入力してください"
            return
        }
        let addedCount = appendImportedText(result)
        importStatus = importStatusText(addedCount: addedCount, source: "読み取り")
    }

    @discardableResult
    private func appendImportedText(_ value: String) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        if bulkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bulkText = trimmed
        } else {
            bulkText += "\n" + trimmed
        }

        let existingKeys = Set(existingLinks.map { link in
            normalizedCreditKey(
                name: link.nameSnapshot.isEmpty ? link.person?.displayName ?? "" : link.nameSnapshot,
                roleKey: link.roleKey,
                roleDetail: roleDetail(for: link)
            )
        })
        var knownKeys = existingKeys.union(pendingLinks.map {
            normalizedCreditKey(name: $0.name, roleKey: $0.role.key, roleDetail: $0.roleDetail)
        })
        let candidates = TheaterCreditTextParser.parse(trimmed)
        let newCandidates = candidates.filter { candidate in
            knownKeys.insert(
                normalizedCreditKey(
                    name: candidate.name,
                    roleKey: candidate.role.key,
                    roleDetail: candidate.roleDetail
                )
            ).inserted
        }
        pendingLinks.append(contentsOf: newCandidates)
        return newCandidates.count
    }

    private func normalizedCreditKey(name: String, roleKey: String, roleDetail: String) -> String {
        [name, roleKey, roleDetail]
            .joined(separator: "|")
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: " ", with: "")
    }

    private func importStatusText(addedCount: Int, source: String) -> String {
        if addedCount > 0 {
            return "\(source)結果を一括入力へ残し、個別登録候補を\(addedCount)件追加しました"
        }
        return "\(source)結果を一括入力へ追加しました。解析できない行は個別登録で補ってください"
    }
}

private struct TheaterCreditsTextImportSheet: View {
    @Binding var text: String
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("キャンセル") { dismiss() }
                Spacer()
                Text("テキストを貼り付けて入力")
                    .font(FavorecoTypography.jpSans(17, weight: .semibold, relativeTo: .headline))
                Spacer()
                Button("反映", action: onApply)
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("公式サイトや案内メールのキャスト・スタッフ部分を貼り付けます。反映後も修正できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
            Spacer(minLength: 0)
        }
        .padding(20)
        .tint(Color(hex: "#8B2F45"))
    }
}

private struct TheaterCreditPersonSheet: View {
    let personMasters: [PersonMaster]
    let onAdd: (PendingPersonLink) -> Void
    let isEditing: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var reading = ""
    @State private var role = PersonRoleOption.defaultOption
    @State private var roleDetail = ""
    @State private var affiliation = ""
    @State private var addsToFocus = false

    private let tint = Color(hex: "#8B2F45")

    init(
        personMasters: [PersonMaster],
        initialValue: PendingPersonLink? = nil,
        onAdd: @escaping (PendingPersonLink) -> Void
    ) {
        self.personMasters = personMasters
        self.onAdd = onAdd
        self.isEditing = initialValue != nil
        _name = State(initialValue: initialValue?.name ?? "")
        _reading = State(initialValue: initialValue?.reading ?? "")
        _role = State(initialValue: initialValue?.role ?? PersonRoleOption.defaultOption)
        _roleDetail = State(initialValue: initialValue?.roleDetail ?? "")
        _affiliation = State(initialValue: initialValue?.affiliationName ?? "")
        _addsToFocus = State(initialValue: initialValue?.isEventFocus ?? false)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [PersonMaster] {
        PersonMasterSuggestion.matching(personMasters, query: trimmedName, allowsOrganizations: false)
    }

    private var supportsFocus: Bool {
        TheaterVisitCastResolver.castRoleKeys.contains(role.key)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text(isEditing ? "キャスト・スタッフを編集" : "キャスト・スタッフを追加")
                    .font(FavorecoTypography.jpSans(18, weight: .semibold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 44)
            }
            .padding(.horizontal, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    inputField("人物名", required: true, prompt: "名前を入力・検索", text: $name)
                    if !suggestions.isEmpty {
                        suggestionList
                    } else {
                        Text("登録済みの人物から検索できます")
                            .font(FavorecoTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    inputField("よみがな", prompt: "例：もりた ゆう", text: $reading)

                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("担当", required: true)
                        Menu {
                            ForEach(PersonRoleOption.theaterEvent) { option in
                                Button(option.name) { role = option }
                            }
                        } label: {
                            HStack {
                                Text(role.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundStyle(.secondary)
                            }
                            .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.28)))
                        }
                    }
                    inputField("役名・担当名", prompt: "例：冬木役", text: $roleDetail)
                    inputField("所属", prompt: "劇団・事務所など", text: $affiliation)

                    if supportsFocus {
                        VStack(alignment: .leading, spacing: 5) {
                            Toggle("注目キャストにも追加", isOn: $addsToFocus)
                                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
                                .tint(tint)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 52)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.24)))
                            Text("観劇後の「お目当て・注目した人」へ引き継ぎます")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }

                    Button(action: add) {
                        Text(isEditing ? "更新する" : "追加する")
                            .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(tint, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.38 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .tint(tint)
        .onChange(of: role) { _, _ in
            if !supportsFocus { addsToFocus = false }
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { person in
                Button {
                    name = person.displayName
                    reading = person.reading
                    if let organizationID = person.parentOrganizationID,
                       let organization = personMasters.first(where: { $0.id == organizationID }) {
                        affiliation = organization.displayName
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName).foregroundStyle(.primary)
                            Text(PersonMasterSuggestion.subtitle(for: person))
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                if person.id != suggestions.last?.id { Divider() }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.22)))
    }

    private func inputField(
        _ title: String,
        required: Bool = false,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel(title, required: required)
            TextField(prompt, text: text)
                .font(FavorecoTypography.jpSans(16, weight: .regular, relativeTo: .body))
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.28)))
        }
    }

    private func fieldLabel(_ title: String, required: Bool = false) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(FavorecoTypography.jpSans(15, weight: .semibold, relativeTo: .body))
            Text(required ? "必須" : "任意")
                .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption))
                .foregroundStyle(required ? tint : Color.secondary)
        }
    }

    private func add() {
        onAdd(PendingPersonLink(
            name: trimmedName,
            reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role,
            roleDetail: roleDetail.trimmingCharacters(in: .whitespacesAndNewlines),
            affiliationName: affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
            entityKind: .person,
            isEventFocus: supportsFocus && addsToFocus
        ))
    }
}
