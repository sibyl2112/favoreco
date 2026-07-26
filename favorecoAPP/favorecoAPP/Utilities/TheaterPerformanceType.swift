import SwiftUI

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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("公演種別")
                        .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.secondary.opacity(0.92))
                        .frame(width: 72, alignment: .leading)

                    Divider()
                        .frame(height: 22)

                    performanceTypePicker
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                ? EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)
                : nil
        )
    }

    private var isLegacySelection: Bool {
        !selection.isEmpty && TheaterPerformanceType(rawValue: selection) == nil
    }

    private var performanceTypePicker: some View {
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
        .font(
            usesCompactLabelStyle
                ? FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body)
                : FavorecoTypography.body
        )
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

    private var promptFontSize: CGFloat {
        switch prompt.count {
        case 22...: 10.5
        case 17...: 11.5
        case 13...: 12.5
        default: 14
        }
    }

    var body: some View {
        Group {
            if labelStyle == .horizontal {
                HStack(alignment: axis == .vertical ? .top : .firstTextBaseline, spacing: 8) {
                    fieldTitle
                        .frame(width: 72, alignment: .leading)

                    Divider()
                        .frame(height: 22)

                    inputField
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    fieldTitle
                    inputField
                }
            }
        }
        .padding(.vertical, labelStyle == .horizontal ? 0 : 1)
        .listRowInsets(
            EdgeInsets(
                top: labelStyle == .horizontal ? 3 : 5,
                leading: 16,
                bottom: labelStyle == .horizontal ? 3 : 5,
                trailing: 16
            )
        )
    }

    private var fieldTitle: some View {
        Text(title)
            .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Color.secondary.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }

    private var inputField: some View {
        TextField(
            title,
            text: $text,
            prompt: Text(prompt)
                .font(FavorecoTypography.jpSans(promptFontSize, weight: .regular, relativeTo: .body))
                .foregroundStyle(Color.secondary.opacity(0.7)),
            axis: axis
        )
        .font(FavorecoTypography.jpSans(14, weight: .regular, relativeTo: .body))
        .lineLimit(minimumLines...maximumLines)
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
            Image(systemName: "camera")
                .font(.system(size: size * 0.42, weight: .semibold))
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
        HStack(spacing: 8) {
            Text("SNS")
                .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.secondary.opacity(0.92))
                .frame(width: 72, alignment: .leading)

            Divider()
                .frame(height: 30)

            HStack(spacing: 12) {
                ForEach(TheaterSocialPlatform.allCases) { platform in
                    Button {
                        pendingURL = binding(for: platform).wrappedValue
                        editingPlatform = platform
                    } label: {
                        TheaterSocialPlatformIcon(
                            platform: platform,
                            isActive: !trimmedValue(for: platform).isEmpty,
                            size: 36
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(platform.displayName)を入力")
                    .accessibilityValue(trimmedValue(for: platform).isEmpty ? "未登録" : "登録済み")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
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
