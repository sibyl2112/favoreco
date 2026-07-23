import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FavoProfileEditorView: View {
    let pin: FavoPin

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var visits: [Visit]
    @Query private var personLinks: [EventPersonLink]
    @State private var draft: Draft
    @State private var heroPickerItem: PhotosPickerItem?
    @State private var iconPickerItem: PhotosPickerItem?
    @State private var errorMessage = ""

    init(pin: FavoPin) {
        self.pin = pin
        _draft = State(initialValue: Draft(pin: pin))
    }

    var body: some View {
        Form {
            masterSection
            favoSection
            anniversarySection
            imageSection

            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("FAVOプロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .disabled(!draft.canSave || (pin.targetKind == .place && draft.trimmedMasterSecondary.isEmpty))
            }
        }
        .task(id: heroPickerItem) {
            await loadImage(from: heroPickerItem, kind: .hero)
        }
        .task(id: iconPickerItem) {
            await loadImage(from: iconPickerItem, kind: .icon)
        }
    }

    @ViewBuilder
    private var masterSection: some View {
        Section {
            switch pin.targetKind {
            case .person:
                TextField("正式名", text: $draft.masterName)
                TextField("よみ（任意）", text: $draft.masterSecondary)
                TextField("役割・活動タグ（カンマ区切り）", text: $draft.masterExtra)
                TextField("公式URL（任意）", text: $draft.officialURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            case .event:
                TextField("作品・体験名", text: $draft.masterName)
                TextField("シリーズ名（任意）", text: $draft.masterSecondary)
                TextField("公式URL（任意）", text: $draft.officialURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            case .place:
                TextField("場所名", text: $draft.masterName)
                Picker("都道府県", selection: $draft.masterSecondary) {
                    Text("選択してください").tag("")
                    ForEach(JapanPrefecture.all, id: \.self) { prefecture in
                        Text(prefecture).tag(prefecture)
                    }
                }
                TextField("住所（任意）", text: $draft.masterExtra)
                TextField("公式URL（任意）", text: $draft.officialURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
        } header: {
            Text("基本情報・全体へ反映")
        } footer: {
            Text("ここを変更すると、マスター管理、キャスト表示、作品・場所候補などアプリ全体へ反映されます。過去記録の名称スナップショットは変更しません。")
        }
    }

    private var favoSection: some View {
        Section("FAVOでの表示") {
            TextField("自分が使う呼び名（任意）", text: $draft.nickname)
            ColorPicker(
                "FAVOカラー",
                selection: Binding(
                    get: { Color(hex: draft.colorHex) },
                    set: { draft.colorHex = $0.hexString() ?? draft.colorHex }
                ),
                supportsOpacity: false
            )

            if pin.targetKind == .person {
                Toggle("推し始めた日を設定", isOn: $draft.hasStartedAt)
                if draft.hasStartedAt {
                    DatePicker("推し始めた日", selection: $draft.startedAt, displayedComponents: .date)
                    Toggle("初日を1日目に含める", isOn: $draft.includesStartDay)
                }
            }

            TextField("好きになったきっかけ（任意）", text: $draft.originText, axis: .vertical)
                .lineLimit(2...5)
            TextField("自分だけのメモ（任意）", text: $draft.memo, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var anniversarySection: some View {
        Section {
            if let profile = existingProfile {
                NavigationLink {
                    FavoAnniversaryManagementView(profile: profile)
                } label: {
                    Label("記念日を管理", systemImage: "calendar.badge.clock")
                }
            } else {
                Label("プロフィール保存後に記念日を追加できます", systemImage: "calendar.badge.clock")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("FAVO記念日")
        } footer: {
            Text("出会った日、初めて観た日、デビュー日などを複数登録できます。")
        }
    }

    private var imageSection: some View {
        let heroActionTitle = draft.heroImageData == nil ? "大きな写真を選ぶ" : "大きな写真を変更"
        let iconActionTitle = draft.iconImageData == nil ? "アイコンを選ぶ" : "アイコンを変更"
        return Section {
            imagePreview(data: draft.heroImageData, fallbackSymbol: "rectangle.on.rectangle")
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            PhotosPicker(selection: $heroPickerItem, matching: .images) {
                Label(heroActionTitle, systemImage: "photo")
            }
            if draft.heroImageData != nil {
                Button("大きな写真を外す", role: .destructive) { draft.heroImageData = nil }
            }

            HStack(spacing: 14) {
                imagePreview(data: draft.iconImageData, fallbackSymbol: pin.targetKind == .person ? "person.fill" : pin.targetKind == .event ? "sparkles.rectangle.stack" : "mappin")
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 8) {
                    Text("FAVO用アイコン")
                        .font(FavorecoTypography.bodyStrong)
                    PhotosPicker(selection: $iconPickerItem, matching: .images) {
                        Text(iconActionTitle)
                    }
            if draft.iconImageData != nil {
                        Button("アイコンを外す", role: .destructive) { draft.iconImageData = nil }
                    }
                }
            }

            if let profile = existingProfile {
                NavigationLink {
                    FavoGalleryManagementView(
                        profile: profile,
                        candidateVisits: galleryCandidateVisits
                    )
                } label: {
                    Label("推し専用写真ギャラリー", systemImage: "photo.stack")
                }
            } else {
                Label("プロフィール保存後にギャラリーを追加できます", systemImage: "photo.stack")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("FAVO写真")
        } footer: {
            Text("大きな写真とFAVO用アイコンは15枚に含みません。推しギャラリーは無料版で15枚まで、Pro以上は無制限です。端末写真または紐づく記録写真から選べます。")
        }
    }

    private var galleryCandidateVisits: [Visit] {
        let matches: [Visit]
        switch pin.targetKind {
        case .person:
            guard let personID = pin.person?.id else { return [] }
            let matchingLinks = personLinks.filter { $0.person?.id == personID && !$0.isArchived }
            let eventIDs = Set(matchingLinks.compactMap { $0.event?.id })
            let directVisitIDs = Set(matchingLinks.compactMap { $0.visit?.id })
            matches = visits.filter { visit in
                directVisitIDs.contains(visit.id) || visit.event.map { eventIDs.contains($0.id) } == true
            }
        case .event:
            guard let eventID = pin.event?.id else { return [] }
            matches = visits.filter { $0.event?.id == eventID }
        case .place:
            guard let placeID = pin.place?.id else { return [] }
            matches = visits.filter { $0.placeMaster?.id == placeID }
        }
        return Dictionary(grouping: matches, by: \.id)
            .values
            .compactMap(\.first)
            .sorted { $0.visitedAt > $1.visitedAt }
    }

    @ViewBuilder
    private func imagePreview(data: Data?, fallbackSymbol: String) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(hex: draft.colorHex).opacity(0.14)
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: draft.colorHex))
            }
        }
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem?, kind: FavoProfileImageKind) async {
        guard let item else { return }
        do {
            guard let sourceData = try await item.loadTransferable(type: Data.self) else {
                throw FavoProfileImageError.unreadable
            }
            let processed = await Task.detached(priority: .userInitiated) {
                FavoProfileImageProcessor.process(sourceData, kind: kind)
            }.value
            guard let processed else { throw FavoProfileImageError.unreadable }
            switch kind {
            case .hero: draft.heroImageData = processed
            case .icon: draft.iconImageData = processed
            }
            errorMessage = ""
        } catch {
            errorMessage = "写真を読み込めませんでした。別の写真を選んでください。"
        }
    }

    private func save() {
        let now = Date()
        switch pin.targetKind {
        case .person:
            guard let person = pin.person else { return }
            person.displayName = draft.trimmedMasterName
            person.reading = draft.trimmedMasterSecondary
            person.roleTagsRaw = draft.trimmedMasterExtra
            person.officialURL = draft.trimmedOfficialURL
            person.normalizedName = normalizedFavoMasterText(draft.trimmedMasterName)
            person.updatedAt = now
        case .event:
            guard let event = pin.event else { return }
            event.title = draft.trimmedMasterName
            event.seriesName = draft.trimmedMasterSecondary
            event.officialURL = draft.trimmedOfficialURL
            event.updatedAt = now
        case .place:
            guard let place = pin.place else { return }
            place.name = draft.trimmedMasterName
            place.prefecture = draft.trimmedMasterSecondary
            place.address = draft.trimmedMasterExtra
            place.officialURL = draft.trimmedOfficialURL
            place.normalizedName = normalizedFavoMasterText(draft.trimmedMasterName)
            place.normalizedAddress = normalizedFavoMasterText(draft.trimmedMasterExtra)
            place.updatedAt = now
        }

        let profile = existingProfile ?? makeProfile(now: now)
        profile.isFavorite = true
        profile.startedAt = draft.startedAt
        profile.hasStartedAt = pin.targetKind == .person && draft.hasStartedAt
        profile.includesStartDay = draft.includesStartDay
        profile.colorHex = draft.colorHex
        profile.nickname = draft.trimmedNickname
        profile.originText = draft.trimmedOriginText
        profile.memo = draft.trimmedMemo
        profile.heroImageData = draft.heroImageData
        profile.iconImageData = draft.iconImageData
        profile.updatedAt = now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private var existingProfile: FavoriteProfile? {
        pin.person?.favoriteProfile ?? pin.event?.favoriteProfile ?? pin.place?.favoriteProfile
    }

    private func makeProfile(now: Date) -> FavoriteProfile {
        let profile = FavoriteProfile(
            isFavorite: true,
            colorHex: draft.colorHex,
            createdAt: now,
            updatedAt: now,
            person: pin.targetKind == .person ? pin.person : nil,
            event: pin.targetKind == .event ? pin.event : nil,
            place: pin.targetKind == .place ? pin.place : nil
        )
        modelContext.insert(profile)
        return profile
    }
}

private extension FavoProfileEditorView {
    struct Draft {
        var masterName: String
        var masterSecondary: String
        var masterExtra: String
        var officialURL: String
        var nickname: String
        var colorHex: String
        var startedAt: Date
        var hasStartedAt: Bool
        var includesStartDay: Bool
        var originText: String
        var memo: String
        var heroImageData: Data?
        var iconImageData: Data?

        init(pin: FavoPin) {
            let profile = pin.person?.favoriteProfile ?? pin.event?.favoriteProfile ?? pin.place?.favoriteProfile
            switch pin.targetKind {
            case .person:
                masterName = pin.person?.displayName ?? ""
                masterSecondary = pin.person?.reading ?? ""
                masterExtra = pin.person?.roleTagsRaw ?? ""
                officialURL = pin.person?.officialURL ?? ""
            case .event:
                masterName = pin.event?.title ?? ""
                masterSecondary = pin.event?.seriesName ?? ""
                masterExtra = ""
                officialURL = pin.event?.officialURL ?? ""
            case .place:
                masterName = pin.place?.name ?? ""
                masterSecondary = pin.place?.prefecture ?? ""
                masterExtra = pin.place?.address ?? ""
                officialURL = pin.place?.officialURL ?? ""
            }
            nickname = profile?.nickname ?? ""
            colorHex = profile?.colorHex ?? pin.event?.category?.colorHex ?? (pin.targetKind == .place ? "#2F7FB8" : "#8F5E73")
            startedAt = profile?.startedAt ?? Date()
            hasStartedAt = profile?.hasStartedAt ?? false
            includesStartDay = profile?.includesStartDay ?? true
            originText = profile?.originText ?? ""
            memo = profile?.memo ?? ""
            heroImageData = profile?.heroImageData
            iconImageData = profile?.iconImageData
        }

        var trimmedMasterName: String { masterName.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedMasterSecondary: String { masterSecondary.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedMasterExtra: String { masterExtra.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedOfficialURL: String { officialURL.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedNickname: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedOriginText: String { originText.trimmingCharacters(in: .whitespacesAndNewlines) }
        var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
        var canSave: Bool { !trimmedMasterName.isEmpty }
    }
}

enum FavoProfileImageKind: Sendable {
    case hero
    case icon
}

private enum FavoProfileImageError: Error {
    case unreadable
}

enum FavoProfileImageProcessor {
    nonisolated static func process(_ data: Data, kind: FavoProfileImageKind) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let outputSize: CGSize
        let compressionQuality: CGFloat
        switch kind {
        case .hero:
            outputSize = CGSize(width: 1600, height: 900)
            compressionQuality = 0.82
        case .icon:
            outputSize = CGSize(width: 640, height: 640)
            compressionQuality = 0.84
        }
        let scale = max(outputSize.width / image.size.width, outputSize.height / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (outputSize.width - drawSize.width) / 2, y: (outputSize.height - drawSize.height) / 2)
        let renderer = pixelExactRenderer(size: outputSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func processGallery(_ data: Data) -> FavoProcessedGalleryImage? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let maximumDimension: CGFloat = 1600
        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let outputSize = CGSize(
            width: max((image.size.width * scale).rounded(), 1),
            height: max((image.size.height * scale).rounded(), 1)
        )
        let renderer = pixelExactRenderer(size: outputSize)
        guard let outputData = renderer.image(actions: { _ in
            image.draw(in: CGRect(origin: .zero, size: outputSize))
        }).jpegData(compressionQuality: 0.82) else { return nil }
        return FavoProcessedGalleryImage(
            data: outputData,
            width: Int(outputSize.width),
            height: Int(outputSize.height)
        )
    }

    nonisolated private static func pixelExactRenderer(size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}

struct FavoProcessedGalleryImage: Sendable {
    let data: Data
    let width: Int
    let height: Int
}

struct FavoNewPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonMaster.displayName) private var people: [PersonMaster]
    @Query(sort: \FavoPin.sortOrder) private var pins: [FavoPin]
    let nextSortOrder: Int
    @State private var name = ""
    @State private var reading = ""
    @State private var errorMessage = ""

    private var suggestions: [PersonMaster] {
        PersonMasterSuggestion.matching(people, query: trimmedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("人物・団体マスター") {
                    TextField("正式名", text: $name)
                    TextField("よみ（任意）", text: $reading)
                }
                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { person in
                            Button {
                                addExistingPerson(person)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: PersonActivityTags.icon(for: person.roleTagsRaw))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.displayName)
                                            .foregroundStyle(.primary)
                                        Text(PersonMasterSuggestion.subtitle(for: person))
                                            .font(FavorecoTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("選択")
                                        .font(FavorecoTypography.captionStrong)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("登録済み候補")
                    } footer: {
                        Text("候補を選ぶと人物マスターを重複作成せず、MY FAVOへ追加します。")
                    }
                }
                Section {
                    Text("保存すると人物・団体マスター、FAVOプロフィール、MY FAVOへの固定を同時に作成します。写真や詳細は保存後の「FAVOプロフィール」から設定できます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("人物・団体を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(trimmedName.isEmpty || nextSortOrder >= 4)
                }
            }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        let now = Date()
        let normalizedName = normalizedFavoMasterText(trimmedName)
        if let existing = PersonMasterSuggestion.exactMatch(in: people, query: trimmedName) {
            errorMessage = "「\(existing.displayName)」が登録済みです。上の候補から選んでください。"
            return
        }
        let person = PersonMaster(
            displayName: trimmedName,
            reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedName: normalizedName,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(person)
        do {
            _ = try PersonFavoRegistrationService.ensureRegistered(
                person: person,
                preferredSortOrder: nextSortOrder,
                in: modelContext,
                now: now
            )
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func addExistingPerson(_ person: PersonMaster) {
        guard nextSortOrder < 4 else {
            errorMessage = "MY FAVOは最大4件です。先に1件外してください。"
            return
        }
        if pins.contains(where: { $0.targetKind == .person && $0.person?.id == person.id }) {
            errorMessage = "「\(person.displayName)」はMY FAVOへ追加済みです。"
            return
        }

        do {
            _ = try PersonFavoRegistrationService.ensureRegistered(
                person: person,
                preferredSortOrder: nextSortOrder,
                in: modelContext
            )
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "MY FAVOへ追加できませんでした: \(error.localizedDescription)"
        }
    }
}

private func normalizedFavoMasterText(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "　", with: "")
}
