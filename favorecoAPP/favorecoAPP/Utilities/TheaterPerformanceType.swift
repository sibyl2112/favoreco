import SwiftUI

enum ExplicitFormMetrics {
    static let rowMinimumHeight: CGFloat = 66
    static let labelFontSize: CGFloat = 16
    static let inputFontSize: CGFloat = 16
    static let dateControlScale: CGFloat = 15.0 / 17.0
    static let rowTopPadding: CGFloat = 9
    static let rowBottomPadding: CGFloat = 8
    static let controlTrailingPadding: CGFloat = 4
    static let rowSeparatorColor = Color.secondary.opacity(0.46)
}

enum TheaterPerformanceType: String, CaseIterable, Identifiable {
    case play = "theater_play"
    case twoPointFiveD = "theater_2_5d"
    case musical = "theater_musical"
    case kabuki = "theater_kabuki"
    case rakugoYose = "theater_rakugo_yose"
    case danceBallet = "theater_dance_ballet"
    case opera = "theater_opera"
    case other = "theater_other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .play: "演劇"
        case .twoPointFiveD: "2.5次元舞台"
        case .musical: "ミュージカル"
        case .kabuki: "歌舞伎"
        case .rakugoYose: "落語・寄席"
        case .danceBallet: "ダンス・バレエ"
        case .opera: "オペラ"
        case .other: "その他"
        }
    }

    static func displayName(for key: String, customName: String) -> String {
        let trimmedCustomName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let type = TheaterPerformanceType(rawValue: key) else {
            return trimmedCustomName.isEmpty ? key : trimmedCustomName
        }
        if type == .other, !trimmedCustomName.isEmpty {
            return trimmedCustomName
        }
        return type.displayName
    }

    static func customNameForStorage(key: String, input: String) -> String {
        guard key == TheaterPerformanceType.other.rawValue else { return "" }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidSelection(key: String, customName: String) -> Bool {
        key != TheaterPerformanceType.other.rawValue
            || !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TheaterPerformanceTypePicker: View {
    @Binding var selection: String
    @Binding var customName: String
    var usesCompactLabelStyle = false

    var body: some View {
        VStack(alignment: .leading, spacing: usesCompactLabelStyle ? 3 : 8) {
            if usesCompactLabelStyle {
                ExplicitFormControlRow(title: "公演種別") {
                    performanceTypePicker
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                performanceTypePicker
            }

            if selection == TheaterPerformanceType.other.rawValue {
                ExplicitFormTextField(
                    title: "その他の種別",
                    prompt: "例：能、狂言、朗読劇",
                    text: $customName,
                    labelStyle: usesCompactLabelStyle ? .horizontal : .stacked
                )
                if !usesCompactLabelStyle {
                    Text("入力した名称を公演種別として保存します。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowInsets(
            usesCompactLabelStyle
                ? EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                : nil
        )
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }

    private var isLegacySelection: Bool {
        !selection.isEmpty && TheaterPerformanceType(rawValue: selection) == nil
    }

    private var performanceTypePicker: some View {
        Group {
            if usesCompactLabelStyle {
                Menu {
                    compactSelectionButton(title: "未設定", key: "")
                    ForEach(TheaterPerformanceType.allCases) { type in
                        compactSelectionButton(title: type.displayName, key: type.rawValue)
                    }
                    if isLegacySelection {
                        compactSelectionButton(
                            title: TheaterPerformanceType.displayName(
                                for: selection,
                                customName: customName
                            ),
                            key: selection
                        )
                    }
                } label: {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text(
                            selection.isEmpty
                                ? "未設定"
                                : TheaterPerformanceType.displayName(
                                    for: selection,
                                    customName: customName
                                )
                        )
                        .font(
                            FavorecoTypography.jpSans(
                                ExplicitFormMetrics.inputFontSize,
                                weight: .regular,
                                relativeTo: .body
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 27, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("公演種別")
            } else {
                Picker("公演種別", selection: $selection) {
                    Text("未設定").tag("")
                    ForEach(TheaterPerformanceType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                    if isLegacySelection {
                        Text(TheaterPerformanceType.displayName(for: selection, customName: customName))
                            .tag(selection)
                    }
                }
                .pickerStyle(.menu)
                .font(FavorecoTypography.body)
            }
        }
    }

    private func compactSelectionButton(title: String, key: String) -> some View {
        Button {
            selection = key
        } label: {
            if selection == key {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

struct ExplicitFormTextField: View {
    enum LabelStyle: Equatable {
        case stacked
        case horizontal
    }

    let title: String
    let prompt: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var minimumLines = 1
    var maximumLines = 1
    var labelStyle: LabelStyle = .stacked
    var inputFontSize: CGFloat = ExplicitFormMetrics.inputFontSize
    var reservesLineSpace = false
    var labelLineLimit = 1
    var labelNote = ""

    private var isOptional: Bool {
        title.contains("任意") || prompt.contains("任意")
    }

    private var isRequired: Bool {
        title.contains("必須") || prompt.contains("必須")
    }

    private var displayedTitle: String {
        removingOptionalNotation(from: title)
    }

    private var displayedPrompt: String {
        removingOptionalNotation(from: prompt)
    }

    private var effectiveInputFontSize: CGFloat {
        let usesCompactLongText = displayedTitle == "住所"
            || displayedTitle.localizedCaseInsensitiveContains("URL")
        return usesCompactLongText ? min(inputFontSize, 14) : inputFontSize
    }

    private var minimumRowHeight: CGFloat {
        guard minimumLines > 1 else { return ExplicitFormMetrics.rowMinimumHeight }
        return 24 + CGFloat(minimumLines) * 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldTitle
            HStack(alignment: .top, spacing: 6) {
                inputField
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.secondary.opacity(0.72))
                            .frame(width: 28, height: 27)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(displayedTitle)をすべて消去")
                }
            }
        }
        .padding(.top, ExplicitFormMetrics.rowTopPadding)
        .padding(.bottom, ExplicitFormMetrics.rowBottomPadding)
        .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        .listRowInsets(
            EdgeInsets(
                top: 0,
                leading: 16,
                bottom: 0,
                trailing: 16
            )
        )
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }

    private var fieldTitle: some View {
        ExplicitFormFieldTitle(
            title: displayedTitle,
            isOptional: isOptional,
            isRequired: isRequired,
            note: labelNote
        )
    }

    @ViewBuilder
    private var inputField: some View {
        if reservesLineSpace {
            baseInputField
                .lineLimit(maximumLines, reservesSpace: true)
        } else {
            baseInputField
                .lineLimit(minimumLines...maximumLines)
        }
    }

    private var baseInputField: some View {
        TextField(
            displayedTitle,
            text: $text,
            prompt: Text(displayedPrompt)
                .font(
                    FavorecoTypography.jpSans(
                        effectiveInputFontSize,
                        weight: .regular,
                        relativeTo: .body
                    )
                )
                .foregroundStyle(Color.secondary.opacity(0.7)),
            axis: axis
        )
        .font(FavorecoTypography.jpSans(effectiveInputFontSize, weight: .regular, relativeTo: .body))
        .frame(minHeight: 27, alignment: .topLeading)
    }

    private func removingOptionalNotation(from value: String) -> String {
        let trimmed = value
            .replacingOccurrences(of: "（任意）", with: "")
            .replacingOccurrences(of: "(任意)", with: "")
            .replacingOccurrences(of: "（必須）", with: "")
            .replacingOccurrences(of: "(必須)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "任意", trimmed != "必須" else { return "" }
        if trimmed.hasPrefix("任意（"), trimmed.hasSuffix("）") {
            return String(trimmed.dropFirst(3).dropLast())
        }
        return trimmed
    }
}

struct ExplicitFormControlRow<Control: View>: View {
    let title: String
    var isOptional = false
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormFieldTitle(
                title: title,
                isOptional: isOptional,
                isRequired: false
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                control()
                    .font(
                        FavorecoTypography.jpSans(
                            ExplicitFormMetrics.inputFontSize,
                            weight: .regular,
                            relativeTo: .body
                        )
                    )
            }
            .frame(height: 27)
            .padding(.trailing, ExplicitFormMetrics.controlTrailingPadding)
        }
        .padding(.top, ExplicitFormMetrics.rowTopPadding)
        .padding(.bottom, ExplicitFormMetrics.rowBottomPadding)
        .frame(minHeight: ExplicitFormMetrics.rowMinimumHeight, alignment: .topLeading)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct ExplicitFormFieldTitle: View {
    let title: String
    let isOptional: Bool
    let isRequired: Bool
    var note = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(title)
                .font(
                    FavorecoTypography.jpSans(
                        ExplicitFormMetrics.labelFontSize,
                        weight: .semibold,
                        relativeTo: .caption
                    )
                )
                .foregroundStyle(Color.primary.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)

            if isOptional {
                Text("任意")
                    .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(Color.secondary.opacity(0.72))
            } else if isRequired {
                Text("必須")
                    .font(FavorecoTypography.jpSans(10, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color.accentColor)
            }

            if !note.isEmpty {
                Text("（\(note)）")
                    .font(FavorecoTypography.jpSans(10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }
        }
        .frame(height: 21, alignment: .bottom)
    }
}

struct TicketTagInputField: View {
    @Binding var text: String

    var body: some View {
        ExplicitFormTextField(
            title: "タグ（任意）",
            prompt: "1行に1件入力",
            text: $text,
            axis: .vertical,
            minimumLines: 3,
            maximumLines: 6,
            labelStyle: .horizontal,
            labelNote: "改行すると次のタグを追加します"
        )
    }
}

enum TheaterSocialPlatform: String, CaseIterable, Identifiable, Equatable {
    case x
    case instagram
    case threads

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .x: "X"
        case .instagram: "Instagram"
        case .threads: "Threads"
        }
    }

    var prompt: String {
        switch self {
        case .x: "https://x.com/..."
        case .instagram: "https://instagram.com/..."
        case .threads: "https://threads.net/@..."
        }
    }

    static func platform(for value: String) -> TheaterSocialPlatform? {
        guard let host = URL(string: value)?.host?.lowercased() else { return nil }
        if host == "x.com" || host.hasSuffix(".x.com")
            || host == "twitter.com" || host.hasSuffix(".twitter.com") {
            return .x
        }
        if host == "instagram.com" || host.hasSuffix(".instagram.com") {
            return .instagram
        }
        if host == "threads.net" || host.hasSuffix(".threads.net") {
            return .threads
        }
        return nil
    }
}

struct TheaterSocialPlatformIcon: View {
    let platform: TheaterSocialPlatform
    let isActive: Bool
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            background
            icon
                .foregroundStyle(isActive ? Color.white : Color.secondary.opacity(0.72))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    isActive ? Color.white.opacity(0.24) : Color.secondary.opacity(0.30),
                    lineWidth: 0.8
                )
        }
    }

    @ViewBuilder
    private var background: some View {
        if !isActive {
            Color.secondary.opacity(0.12)
        } else if platform == .instagram {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.37, blue: 0.24),
                    Color(red: 0.76, green: 0.17, blue: 0.62),
                    Color(red: 0.32, green: 0.25, blue: 0.88)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        } else {
            Color.black
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch platform {
        case .x:
            Text("X")
                .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
        case .instagram:
            FavorecoIcon(systemName: "camera", size: size * 0.42)
        case .threads:
            Text("@")
                .font(.system(size: size * 0.50, weight: .bold, design: .rounded))
        }
    }
}

struct TheaterSocialLinksEditor: View {
    @Binding var xURL: String
    @Binding var instagramURL: String
    @Binding var threadsURL: String

    @State private var editingPlatform: TheaterSocialPlatform?
    @State private var pendingURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ExplicitFormFieldTitle(
                title: "SNS",
                isOptional: true,
                isRequired: false
            )

            HStack(spacing: 8) {
                ForEach(TheaterSocialPlatform.allCases) { platform in
                    Button {
                        pendingURL = binding(for: platform).wrappedValue
                        editingPlatform = platform
                    } label: {
                        HStack(spacing: 5) {
                            TheaterSocialPlatformIcon(
                                platform: platform,
                                isActive: !trimmedValue(for: platform).isEmpty,
                                size: 28
                            )
                            Text(platform.displayName)
                                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .padding(.horizontal, 6)
                        .background(
                            Color.secondary.opacity(0.07),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(Color.secondary.opacity(0.20), lineWidth: 0.8)
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(platform.displayName)を入力")
                    .accessibilityValue(trimmedValue(for: platform).isEmpty ? "未登録" : "登録済み")
                }
            }
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
        .sheet(item: $editingPlatform) { platform in
            NavigationStack {
                Form {
                    ExplicitFormTextField(
                        title: "URL",
                        prompt: platform.prompt,
                        text: $pendingURL,
                        labelStyle: .horizontal
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                }
                .navigationTitle(platform.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            editingPlatform = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            binding(for: platform).wrappedValue = pendingURL
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            editingPlatform = nil
                        }
                    }
                }
            }
            .presentationDetents([.height(230)])
        }
    }

    private func binding(for platform: TheaterSocialPlatform) -> Binding<String> {
        switch platform {
        case .x: $xURL
        case .instagram: $instagramURL
        case .threads: $threadsURL
        }
    }

    private func trimmedValue(for platform: TheaterSocialPlatform) -> String {
        binding(for: platform).wrappedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
