import SwiftUI
import SwiftData

struct DisplaySettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @AppStorage(AppStorageKeys.showsHomeAttention) private var showsHomeAttention = true
    @AppStorage(AppStorageKeys.showsHomeExperienceGallery) private var showsHomeExperienceGallery = true
    @AppStorage(AppStorageKeys.showsHomeInbox) private var showsHomeInbox = true
    @AppStorage(AppStorageKeys.showsHomeRecentRecords) private var showsHomeRecentRecords = true
    @AppStorage(AppStorageKeys.showsHomeCategories) private var showsHomeCategories = true
    @AppStorage(AppStorageKeys.showsHomeStatsSummary) private var showsHomeStatsSummary = false
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue
    @AppStorage(AppStorageKeys.fontStyle) private var fontStyleRaw = AppFontStyle.standard.rawValue
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage(AppStorageKeys.themeMode) private var themeModeRaw = FavorecoThemeMode.categoryAccent.rawValue
    @AppStorage(AppStorageKeys.unifiedThemeColorHex) private var unifiedThemeColorHex = "#147C88"

    var body: some View {
        Form {
            Section("Home表示") {
                Toggle("次にやること・チケット", isOn: $showsHomeAttention)
                Toggle("最近の思い出", isOn: $showsHomeExperienceGallery)
                Toggle("気になる", isOn: $showsHomeInbox)
                Toggle("最近の記録", isOn: $showsHomeRecentRecords)
                Toggle("ジャンル一覧", isOn: $showsHomeCategories)
                Toggle("統計サマリ", isOn: $showsHomeStatsSummary)
            }

            Section("外観") {
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

            Section("テーマ") {
                if purchaseManager.currentPlan.includesLocalFullFeatures {
                    Picker("配色", selection: themeModeBinding) {
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
                    LabeledContent("配色", value: FavorecoThemeMode.categoryAccent.name)
                    Label("全体統一テーマはPro以上", systemImage: "lock.fill")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }

                Text("標準では白を基調にジャンル色をアクセントとして使います。全体統一では操作色を選んだ色へ揃えます。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            Section {
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

            Section {
                Picker("文字の太さ", selection: fontWeightBinding) {
                    ForEach(AppFontWeight.allCases) { option in
                        Text(option.name).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canChangeFont)
            } header: {
                Text("文字の太さ")
            } footer: {
                if !canChangeFont {
                    Text("文字の太さ変更はPro以上で利用できます。")
                } else {
                    Text("本文と見出しの強弱を保ったまま、アプリ全体の文字を調整します。")
                }
            }

            Section("プレビュー") {
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
            Section {
                Toggle("iOS設定に従う", isOn: $followsSystemTextSize)

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

            Section("プレビュー") {
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
        .navigationTitle("文字サイズ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
