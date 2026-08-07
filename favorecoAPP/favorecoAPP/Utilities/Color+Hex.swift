//
//  Color+Hex.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import UIKit

enum FavorecoBaseTheme: String, CaseIterable, Identifiable {
    case favoNeon
    case earthGlass
    case limeEditorial
    case skyBlue
    case redMagenta

    var id: String { rawValue }

    var name: String {
        switch self {
        case .favoNeon: return "エアリーティール"
        case .earthGlass: return "アースグラス"
        case .limeEditorial: return "ライムエディトリアル"
        case .skyBlue: return "スカイブルー"
        case .redMagenta: return "赤マゼンタ"
        }
    }

    var accentHex: String {
        switch self {
        case .favoNeon: return "#3296BD"
        case .earthGlass: return "#5E7056"
        case .limeEditorial: return "#566900"
        case .skyBlue: return "#3474A3"
        case .redMagenta: return "#B04464"
        }
    }

    var darkAccentHex: String {
        switch self {
        case .favoNeon: return "#60DDE4"
        case .earthGlass: return "#B8CBAA"
        case .limeEditorial: return "#D7FF55"
        case .skyBlue: return "#3474A3"
        case .redMagenta: return "#B04464"
        }
    }

    var softTintHex: String {
        switch self {
        case .favoNeon: return "#E9FAFC"
        case .earthGlass: return "#E8EEE2"
        case .limeEditorial: return "#F1F7CC"
        case .skyBlue: return "#E3EFF7"
        case .redMagenta: return "#F5E2E7"
        }
    }

    var darkSoftTintHex: String {
        switch self {
        case .favoNeon: return "#19383D"
        case .earthGlass: return "#313A2C"
        case .limeEditorial: return "#2B3217"
        case .skyBlue: return "#1B2B36"
        case .redMagenta: return "#38232B"
        }
    }

    func canvasHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .favoNeon, .skyBlue, .redMagenta: return "#F7F7F3"
            case .earthGlass: return "#F5F0E7"
            case .limeEditorial: return "#F5F5F0"
            }
        }
        switch self {
        case .favoNeon: return "#14191D"
        case .earthGlass: return "#171914"
        case .limeEditorial: return "#11130F"
        case .skyBlue: return "#14191D"
        case .redMagenta: return "#1B1517"
        }
    }

    func headingTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .favoNeon: return "#192735"
            case .earthGlass: return "#2D3029"
            case .limeEditorial: return "#181B18"
            case .skyBlue: return "#192735"
            case .redMagenta: return "#38232B"
            }
        }
        switch self {
        case .favoNeon: return "#EFF4F7"
        case .earthGlass: return "#F4EFE6"
        case .limeEditorial: return "#F4F6EE"
        case .skyBlue: return "#EFF4F7"
        case .redMagenta: return "#F7F0F2"
        }
    }

    func bodyTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .favoNeon: return "#293640"
            case .earthGlass: return "#45483F"
            case .limeEditorial: return "#343833"
            case .skyBlue: return "#293640"
            case .redMagenta: return "#443039"
            }
        }
        switch self {
        case .favoNeon: return "#DCE4E9"
        case .earthGlass: return "#DED8CC"
        case .limeEditorial: return "#DDE2D6"
        case .skyBlue: return "#DCE4E9"
        case .redMagenta: return "#E9DDE1"
        }
    }

    func secondaryTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .favoNeon: return "#68737D"
            case .earthGlass: return "#74786D"
            case .limeEditorial: return "#71766F"
            case .skyBlue: return "#68737D"
            case .redMagenta: return "#77656C"
            }
        }
        switch self {
        case .favoNeon: return "#AEBAC2"
        case .earthGlass: return "#B1AA9D"
        case .limeEditorial: return "#A7AEA0"
        case .skyBlue: return "#AEBAC2"
        case .redMagenta: return "#C0ADB4"
        }
    }

    func tertiaryTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .favoNeon: return "#8A949C"
            case .earthGlass: return "#969A8F"
            case .limeEditorial: return "#949A91"
            case .skyBlue: return "#8A949C"
            case .redMagenta: return "#998A90"
            }
        }
        switch self {
        case .favoNeon: return "#89979F"
        case .earthGlass: return "#858075"
        case .limeEditorial: return "#7E8678"
        case .skyBlue: return "#89979F"
        case .redMagenta: return "#9F8D94"
        }
    }

    var prominentActionHex: String {
        switch self {
        case .favoNeon: return "#3296BD"
        case .earthGlass: return "#AFC09F"
        case .limeEditorial: return "#D8FF3E"
        case .skyBlue, .redMagenta: return accentHex
        }
    }

    var darkProminentActionHex: String {
        switch self {
        case .favoNeon: return "#60DDE4"
        case .earthGlass: return "#8FA481"
        case .limeEditorial: return "#CEFF3B"
        case .skyBlue, .redMagenta: return darkAccentHex
        }
    }

    var emotionHex: String {
        switch self {
        case .favoNeon: return "#B62F58"
        case .earthGlass: return "#A95436"
        case .limeEditorial: return "#4F65D8"
        case .skyBlue: return "#B04464"
        case .redMagenta: return accentHex
        }
    }

    var darkEmotionHex: String {
        switch self {
        case .favoNeon: return "#FF84A1"
        case .earthGlass: return "#E39573"
        case .limeEditorial: return "#8A98FF"
        case .skyBlue: return "#FF84A1"
        case .redMagenta: return darkAccentHex
        }
    }

    var emotionSurfaceHex: String {
        switch self {
        case .favoNeon: return "#FF638A"
        case .earthGlass: return "#D98662"
        case .limeEditorial: return "#7183EF"
        case .skyBlue: return "#FF638A"
        case .redMagenta: return accentHex
        }
    }

    var darkEmotionSurfaceHex: String {
        switch self {
        case .favoNeon, .skyBlue: return "#FF638A"
        case .earthGlass: return "#C87554"
        case .limeEditorial: return "#6979E8"
        case .redMagenta: return darkAccentHex
        }
    }

    var emotionSoftTintHex: String {
        switch self {
        case .favoNeon, .skyBlue: return "#FFF0F5"
        case .earthGlass: return "#F6E3D7"
        case .limeEditorial: return "#EAEDFF"
        case .redMagenta: return softTintHex
        }
    }

    var darkEmotionSoftTintHex: String {
        switch self {
        case .favoNeon, .skyBlue: return "#3A222A"
        case .earthGlass: return "#3E2B24"
        case .limeEditorial: return "#252A45"
        case .redMagenta: return darkSoftTintHex
        }
    }
}

enum FavorecoThemeMode: String, CaseIterable, Identifiable {
    case categoryAccent
    case unified

    var id: String { rawValue }

    var name: String {
        switch self {
        case .categoryAccent: return "標準（ジャンル色）"
        case .unified: return "全体を同じ色にする"
        }
    }
}

struct FavorecoThemeColorPreset: Identifiable {
    let id: String
    let name: String
    let hex: String

    static let all: [FavorecoThemeColorPreset] = [
        FavorecoThemeColorPreset(id: "teal", name: "ティール", hex: "#147C88"),
        FavorecoThemeColorPreset(id: "wine", name: "ワイン", hex: "#8B2F45"),
        FavorecoThemeColorPreset(id: "sage", name: "セージ", hex: "#7D8C78"),
        FavorecoThemeColorPreset(id: "charcoal", name: "チャコール", hex: "#3B3D4A"),
        FavorecoThemeColorPreset(id: "amber", name: "アンバー", hex: "#B8792F"),
        FavorecoThemeColorPreset(id: "green", name: "グリーン", hex: "#2E7D60"),
        FavorecoThemeColorPreset(id: "rose", name: "ローズ", hex: "#A24C55"),
        FavorecoThemeColorPreset(id: "blue", name: "ブルー", hex: "#536C95"),
    ]
}

enum TicketProgressVisualStage: String, Equatable {
    case application
    case sale
    case result
    case payment
    case acquired

    var accentHex: String {
        switch self {
        case .application: "#257F94"
        case .sale: "#3D73A3"
        case .result: "#B34769"
        case .payment: "#8A6817"
        case .acquired: "#2F8063"
        }
    }

    var darkAccentHex: String { accentHex }

    var surfaceHex: String {
        switch self {
        case .application: "#D5F3F8"
        case .sale: "#DDEFFC"
        case .result: "#F8D8E2"
        case .payment: "#F8E9BB"
        case .acquired: "#D7F1E7"
        }
    }

    var darkSurfaceHex: String {
        switch self {
        case .application: "#173A43"
        case .sale: "#1A354A"
        case .result: "#4B2534"
        case .payment: "#493B16"
        case .acquired: "#1C4033"
        }
    }

    var textHex: String {
        switch self {
        case .application: "#164B5A"
        case .sale: "#244C6C"
        case .result: "#632E42"
        case .payment: "#554112"
        case .acquired: "#194A39"
        }
    }

    var darkTextHex: String { "#FFFDF8" }
}

enum TicketProgressColorPalette {
    // One semantic palette is shared by Home, ticket management and progress sheets.
    static let sale = Color(hex: "#D47A36")
    static let application = Color(hex: "#983650")
    static let result = Color(hex: "#76528B")
    static let payment = Color(hex: "#247E85")
    static let acquired = Color(hex: "#54745A")
    static let attendance = Color(hex: "#B66A32")
    /// 参加日が未確定で、日程入力による解消が必要な状態。
    static let scheduleUndated = Color.adaptive(lightHex: "#C85A00", darkHex: "#FF9F0A")
    static let warning = Color.adaptive(lightHex: "#E45F57", darkHex: "#FF8B82")
    static let completedNeutral = Color.adaptive(lightHex: "#53606A", darkHex: "#C5CED4")
    static let metadataChipSurface = Color.adaptive(lightHex: "#FFFDF8", darkHex: "#30383C")
    static let metadataChipText = Color.adaptive(lightHex: "#293640", darkHex: "#F5F7F8")
    static let metadataChipBorder = Color.adaptive(lightHex: "#293640", darkHex: "#F5F7F8")
    static let entryRouteChipText = Color.adaptive(lightHex: "#2C6F96", darkHex: "#9DD7F2")
    static let entryRouteChipBorder = Color.adaptive(lightHex: "#74A9C5", darkHex: "#79B6D3")

    static func color(for visualStage: TicketProgressVisualStage) -> Color {
        Color.adaptive(
            lightHex: visualStage.accentHex,
            darkHex: visualStage.darkAccentHex
        )
    }

    static func surface(for visualStage: TicketProgressVisualStage) -> Color {
        Color.adaptive(
            lightHex: visualStage.surfaceHex,
            darkHex: visualStage.darkSurfaceHex
        )
    }

    static func text(for visualStage: TicketProgressVisualStage) -> Color {
        Color.adaptive(
            lightHex: visualStage.textHex,
            darkHex: visualStage.darkTextHex
        )
    }

    static func visualStage(for stage: TicketProgressStage) -> TicketProgressVisualStage {
        switch stage.kind {
        case .entry:
            return stage.title == "発売" ? .sale : .application
        case .result:
            return .result
        case .payment:
            return .payment
        case .acquired:
            return .acquired
        }
    }

    static func visualStage(forDeadlineLabel label: String) -> TicketProgressVisualStage? {
        switch label {
        case "チケ発売": .sale
        case "抽選申込": .application
        case "抽選当落": .result
        case "チケ支払": .payment
        case "チケ受取", "チケ取得", "参加日": .acquired
        default: nil
        }
    }

    static func color(for stage: TicketProgressStage) -> Color {
        color(for: visualStage(for: stage))
    }

    static func color(forDeadlineLabel label: String, fallback: Color) -> Color {
        switch label {
        case "チケ発売": return sale
        case "抽選申込": return application
        case "抽選当落": return result
        case "チケ支払": return payment
        case "チケ受取", "チケ取得": return acquired
        case "参加日": return attendance
        default: return fallback
        }
    }

    static func surface(forDeadlineLabel label: String, fallback: Color) -> Color {
        guard let visualStage = visualStage(forDeadlineLabel: label) else { return fallback }
        return surface(for: visualStage)
    }

    static func text(forDeadlineLabel label: String, fallback: Color) -> Color {
        guard let visualStage = visualStage(forDeadlineLabel: label) else { return fallback }
        return text(for: visualStage)
    }
}

struct FavorecoThemePalette {
    let baseTheme: FavorecoBaseTheme
    let mode: FavorecoThemeMode
    let unifiedColorHex: String

    static let standard = FavorecoThemePalette(
        baseTheme: .favoNeon,
        mode: .categoryAccent,
        unifiedColorHex: "#3296BD"
    )

    var globalTint: Color {
        guard mode != .unified else { return Color(hex: unifiedColorHex) }
        return Color.adaptive(
            lightHex: baseTheme.accentHex,
            darkHex: baseTheme.darkAccentHex
        )
    }

    var softTint: Color {
        Color.adaptive(
            lightHex: baseTheme.softTintHex,
            darkHex: baseTheme.darkSoftTintHex
        )
    }

    var prominentAction: Color {
        guard mode != .unified else { return Color(hex: unifiedColorHex) }
        return Color.adaptive(
            lightHex: baseTheme.prominentActionHex,
            darkHex: baseTheme.darkProminentActionHex
        )
    }

    /// 登録・編集フォームの外側Section見出し。テーマ変更時はこのトークン経由で一括追従する。
    var registrationSectionHeaderTint: Color {
        globalTint
    }

    func prominentActionForeground(for colorScheme: ColorScheme) -> Color {
        let backgroundHex: String
        if mode == .unified {
            backgroundHex = unifiedColorHex
        } else {
            backgroundHex = colorScheme == .dark
                ? baseTheme.darkProminentActionHex
                : baseTheme.prominentActionHex
        }
        return Color.highContrastForeground(forBackgroundHex: backgroundHex)
    }

    var emotionTint: Color {
        guard mode != .unified else { return Color(hex: unifiedColorHex) }
        return Color.adaptive(
            lightHex: baseTheme.emotionHex,
            darkHex: baseTheme.darkEmotionHex
        )
    }

    var emotionSurface: Color {
        guard mode != .unified else { return Color(hex: unifiedColorHex) }
        return Color.adaptive(
            lightHex: baseTheme.emotionSurfaceHex,
            darkHex: baseTheme.darkEmotionSurfaceHex
        )
    }

    var emotionSoftTint: Color {
        Color.adaptive(
            lightHex: baseTheme.emotionSoftTintHex,
            darkHex: baseTheme.darkEmotionSoftTintHex
        )
    }

    func canvas(for colorScheme: ColorScheme) -> Color {
        Color(hex: baseTheme.canvasHex(for: colorScheme))
    }

    func headingText(for colorScheme: ColorScheme) -> Color {
        Color(hex: baseTheme.headingTextHex(for: colorScheme))
    }

    func bodyText(for colorScheme: ColorScheme) -> Color {
        Color(hex: baseTheme.bodyTextHex(for: colorScheme))
    }

    func secondaryText(for colorScheme: ColorScheme) -> Color {
        Color(hex: baseTheme.secondaryTextHex(for: colorScheme))
    }

    func tertiaryText(for colorScheme: ColorScheme) -> Color {
        Color(hex: baseTheme.tertiaryTextHex(for: colorScheme))
    }

    func categoryColor(hex: String) -> Color {
        Color(hex: resolvedHex(categoryHex: hex))
    }

    func resolvedHex(categoryHex: String) -> String {
        mode == .unified ? unifiedColorHex : categoryHex
    }
}

private struct FavorecoThemePaletteKey: EnvironmentKey {
    static let defaultValue = FavorecoThemePalette.standard
}

private struct FavorecoAppColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    var favorecoThemePalette: FavorecoThemePalette {
        get { self[FavorecoThemePaletteKey.self] }
        set { self[FavorecoThemePaletteKey.self] = newValue }
    }

    var favorecoAppColorScheme: ColorScheme {
        get { self[FavorecoAppColorSchemeKey.self] }
        set { self[FavorecoAppColorSchemeKey.self] = newValue }
    }
}

private struct FavorecoAppAppearanceModifier: ViewModifier {
    @Environment(\.favorecoAppColorScheme) private var appColorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, appColorScheme)
            .preferredColorScheme(appColorScheme)
    }
}

extension View {
    /// ジャンル固有のLight / Dark環境を引き継がず、利用者が選んだアプリ外観へ戻す境界。
    func favorecoAppAppearance() -> some View {
        modifier(FavorecoAppAppearanceModifier())
    }
}

extension Color {
    /// Immersive detail pages force a dark canvas, so lift a stored category color
    /// toward white while preserving its hue. This keeps links and disclosure
    /// controls readable even when the original category color is dark.
    static func legibleDetailAccent(hex: String, whiteBlend: Double = 0.42) -> Color {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitizedHex.count == 6,
              let value = UInt64(sanitizedHex, radix: 16) else {
            return Color(red: 0.72, green: 0.91, blue: 1.0)
        }
        let blend = min(max(whiteBlend, 0), 1)
        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        return Color(
            red: red + ((1 - red) * blend),
            green: green + ((1 - green) * blend),
            blue: blue + ((1 - blue) * blend)
        )
    }

    static func highContrastForeground(
        forBackgroundHex backgroundHex: String,
        darkHex: String = "#192735",
        lightHex: String = "#FFFFFF"
    ) -> Color {
        let backgroundLuminance = relativeLuminance(hex: backgroundHex)
        let darkLuminance = relativeLuminance(hex: darkHex)
        let lightLuminance = relativeLuminance(hex: lightHex)
        let darkContrast = contrastRatio(backgroundLuminance, darkLuminance)
        let lightContrast = contrastRatio(backgroundLuminance, lightLuminance)
        return Color(hex: darkContrast >= lightContrast ? darkHex : lightHex)
    }

    static func adaptive(lightHex: String, darkHex: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }

    private static func relativeLuminance(hex: String) -> Double {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitizedHex.count == 6,
              let value = UInt64(sanitizedHex, radix: 16) else {
            return 0
        }
        let channels = [
            Double((value & 0xFF0000) >> 16) / 255,
            Double((value & 0x00FF00) >> 8) / 255,
            Double(value & 0x0000FF) / 255
        ].map { channel in
            channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
    }

    private static func contrastRatio(_ first: Double, _ second: Double) -> Double {
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        if sanitizedHex.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        } else {
            red = 0.44
            green = 0.56
            blue = 0.48
        }

        self.init(red: red, green: green, blue: blue)
    }

    func hexString() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let redValue = Int(round(red * 255))
        let greenValue = Int(round(green * 255))
        let blueValue = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", redValue, greenValue, blueValue)
    }
}

private struct FavorecoProminentActionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.favorecoThemePalette) private var themePalette

    func body(content: Content) -> some View {
        content
            .tint(themePalette.prominentAction)
            .foregroundStyle(themePalette.prominentActionForeground(for: colorScheme))
    }
}

extension View {
    func favorecoProminentActionStyle() -> some View {
        modifier(FavorecoProminentActionModifier())
    }
}
