import SwiftUI
import SwiftData

struct DisplaySettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsHomeAttention = true
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage(AppStorageKeys.baseTheme) private var baseThemeRaw = FavorecoBaseTheme.favoNeon.rawValue
    @AppStorage(AppStorageKeys.themeMode) private var themeModeRaw = FavorecoThemeMode.categoryAccent.rawValue
    @AppStorage(AppStorageKeys.unifiedThemeColorHex) private var unifiedThemeColorHex = "#3296BD"

    var body: some View {
        Form {
            FavorecoSettingsSection("Homeに表示する内容") {
                FavorecoSettingsToggleRow(title: "Ticket Schedule", detail: "期限や公演予定をHomeに表示", isOn: $showsHomeAttention)
                LabeledContent("PICK UP", value: "常に表示")
                LabeledContent("Favoreco Report", value: "常に表示")
            }

            FavorecoSettingsSection("文字と外観") {
                NavigationLink {
                    TextSizeSettingsView()
                } label: {
                    LabeledContent("文字サイズ", value: textSizeSummary)
                }
                NavigationLink {
                    FontStyleSettingsView()
                } label: {
                    LabeledContent("フォント", value: effectiveFontStyle.name)
                }
                Picker("外観モード", selection: $appearanceModeRaw) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.name).tag(mode.rawValue)
                    }
                }
            }

            FavorecoSettingsSection("テーマカラー") {
                Picker("ベーステーマ", selection: $baseThemeRaw) {
                    ForEach(FavorecoBaseTheme.allCases) { theme in
                        Label {
                            Text(theme.name)
                        } icon: {
                            HStack(spacing: -2) {
                                Circle()
                                    .fill(Color.adaptive(
                                        lightHex: theme.accentHex,
                                        darkHex: theme.darkAccentHex
                                    ))
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .fill(Color.adaptive(
                                        lightHex: theme.emotionHex,
                                        darkHex: theme.darkEmotionHex
                                    ))
                                    .frame(width: 10, height: 10)
                            }
                            .accessibilityHidden(true)
                        }
                        .tag(theme.rawValue)
                    }
                }

                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    Picker("ジャンル配色", selection: themeModeBinding) {
                        ForEach(FavorecoThemeMode.allCases) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }

                    if effectiveThemeMode == .unified {
                        Picker("全体カラー", selection: $unifiedThemeColorHex) {
                            ForEach(FavorecoThemeColorPreset.all) { preset in
                                Label {
                                    Text(preset.name)
                                } icon: {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 14, height: 14)
                                }
                                .tag(preset.hex)
                            }
                        }
                    }
                } else {
                    LabeledContent("ジャンル配色", value: FavorecoThemeMode.categoryAccent.name)
                    Label("全体統一テーマはPro以上", systemImage: "lock.fill")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                FavorecoSettingsInfoCallout(
                    title: "テーマが変わる場所",
                    message: themeDescription
                )
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("表示・外観")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var textSizeSummary: String {
        followsSystemTextSize
            ? "端末設定に従う"
            : (AppTextSize(rawValue: appTextSizeRaw) ?? .standard).name
    }

    private var effectiveThemeMode: FavorecoThemeMode {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return .categoryAccent }
        return FavorecoThemeMode(rawValue: themeModeRaw) ?? .categoryAccent
    }

    private var selectedBaseTheme: FavorecoBaseTheme {
        FavorecoBaseTheme(rawValue: baseThemeRaw) ?? .favoNeon
    }

    private var themeDescription: String {
        let paletteDescription: String
        switch selectedBaseTheme {
        case .favoNeon:
            paletteDescription = "エアリーティールはライトで青寄りのクリアブルー、ダークで明るいアクアを操作色にし、FAVOの感情表現をピンクで示します。"
        case .earthGlass:
            paletteDescription = "アースグラスはセージを操作、クレイをFAVOの感情表現に使います。"
        case .limeEditorial:
            paletteDescription = "ライムエディトリアルはライムを操作、コバルトをFAVOの感情表現に使います。"
        case .skyBlue:
            paletteDescription = "スカイブルーは澄んだ青を操作色に使います。"
        case .redMagenta:
            paletteDescription = "赤マゼンタは落ち着いた赤を操作色に使います。"
        }
        return "ベーステーマはHomeの背景・操作色・文字の墨色へ反映します。\(paletteDescription)標準ではジャンル固有色を維持し、全体統一では操作色を選んだ色へ揃えます。"
    }

    private var effectiveFontStyle: AppFontStyle {
        guard purchaseManager.currentPlan.includesLocalFullFeatures else { return .standard }
        return AppFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    private var themeModeBinding: Binding<FavorecoThemeMode> {
        Binding(
            get: { effectiveThemeMode },
            set: { themeModeRaw = $0.rawValue }
        )
    }
}

private struct FontStyleSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.fontWeight) private var fontWeightRaw = AppFontWeight.standard.rawValue

    var body: some View {
        Form {
            FavorecoSettingsSectionWithFooter("フォントの種類") {
                ForEach(AppFontStyle.allCases) { style in
                    Button {
                        guard style == .standard || canChangeFont else { return }
                        fontStyleRaw = style.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.name)
                                    .font(font(for: style, size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(style.detail)
                                    .font(font(for: style, size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.tint)
                            } else if style != .standard && !canChangeFont {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(canChangeFont
                     ? "英字の見出しには、どの設定でも Cormorant Garamond を使います。"
                     : "フォント変更はPro以上で利用できます。標準表示は無料で使えます。")
            }

            FavorecoSettingsSectionWithFooter("文字の太さ") {
                Picker("文字の太さ", selection: fontWeightBinding) {
                    ForEach(AppFontWeight.allCases) { option in
                        Text(option.name).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canChangeFont)
            } footer: {
                if !canChangeFont {
                    Text("文字の太さ変更はPro以上で利用できます。")
                } else {
                    Text("本文と見出しの強弱を保ったまま、アプリ全体の文字を調整します。")
                }
            }

            FavorecoSettingsSection("プレビュー") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("記録が、美しい思い出になる")
                        .font(font(for: selectedStyle, size: 24, weight: .bold, prefersSerif: true))
                    Text("観た作品や訪れた場所を、写真と一緒に残せます。")
                        .font(font(for: selectedStyle, size: 15))
                    Text("Favoreco 2026")
                        .font(FavorecoTypography.latinDisplay(20, weight: .semibold, relativeTo: .headline))
                }
                .padding(.vertical, 6)
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("フォント")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canChangeFont: Bool {
        purchaseManager.currentPlan.includesLocalFullFeatures
    }

    private var selectedStyle: AppFontStyle {
        guard canChangeFont else { return .standard }
        return AppFontStyle(rawValue: fontStyleRaw) ?? .standard
    }

    private var fontWeightBinding: Binding<String> {
        Binding(
            get: { canChangeFont ? fontWeightRaw : AppFontWeight.standard.rawValue },
            set: { newValue in
                guard canChangeFont else { return }
                fontWeightRaw = newValue
            }
        )
    }

    private func font(
        for style: AppFontStyle,
        size: CGFloat,
        weight: Font.Weight = .regular,
        prefersSerif: Bool = false
    ) -> Font {
        let usesSerif = style == .serif || (style == .standard && prefersSerif)
        let name = usesSerif ? "Noto Serif JP" : "Noto Sans JP"
        return .custom(name, size: size, relativeTo: size >= 20 ? .title2 : .body)
            .weight(previewWeight(weight))
    }

    private func previewWeight(_ weight: Font.Weight) -> Font.Weight {
        let option = canChangeFont
            ? (AppFontWeight(rawValue: fontWeightRaw) ?? .standard)
            : .standard
        switch option {
        case .standard:
            return weight
        case .light:
            if weight == .bold || weight == .heavy || weight == .black { return .semibold }
            if weight == .semibold { return .medium }
            if weight == .medium { return .regular }
            return .light
        case .bold:
            if weight == .black || weight == .heavy { return .black }
            if weight == .bold || weight == .semibold { return .bold }
            if weight == .medium { return .semibold }
            return .medium
        }
    }
}

private struct TextSizeSettingsView: View {
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue

    var body: some View {
        Form {
            FavorecoSettingsSectionWithFooter("文字サイズ") {
                FavorecoSettingsToggleRow(
                    title: "iOS設定に従う",
                    detail: "端末の文字サイズとアクセシビリティ設定を反映",
                    isOn: $followsSystemTextSize
                )

                if !followsSystemTextSize {
                    Picker("アプリ内文字サイズ", selection: $appTextSizeRaw) {
                        ForEach(AppTextSize.allCases) { option in
                            Text(option.name).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("iOS設定に従う場合は、端末の文字サイズとアクセシビリティ設定を反映します。")
            }

            FavorecoSettingsSection("プレビュー") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("記録が、美しい思い出になる")
                        .font(FavorecoTypography.jpSerif(24, weight: .bold, relativeTo: .title2))
                    Text("観た作品や訪れた場所を、写真と一緒に残せます。")
                        .font(FavorecoTypography.body)
                    Text("Favoreco 2026")
                        .font(FavorecoTypography.latinDisplay(20, weight: .semibold, relativeTo: .headline))
                }
                .padding(.vertical, 6)
            }
        }
        .favorecoSettingsListLayout()
        .navigationTitle("文字サイズ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
