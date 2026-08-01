//
//  Color+Hex.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import UIKit

enum FavorecoBaseTheme: String, CaseIterable, Identifiable {
    case skyBlue
    case redMagenta

    var id: String { rawValue }

    var name: String {
        switch self {
        case .skyBlue: return "スカイブルー"
        case .redMagenta: return "赤マゼンタ"
        }
    }

    var accentHex: String {
        switch self {
        case .skyBlue: return "#3474A3"
        case .redMagenta: return "#B04464"
        }
    }

    var softTintHex: String {
        switch self {
        case .skyBlue: return "#E3EFF7"
        case .redMagenta: return "#F5E2E7"
        }
    }

    func canvasHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else { return "#F7F7F3" }
        switch self {
        case .skyBlue: return "#14191D"
        case .redMagenta: return "#1B1517"
        }
    }

    func headingTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .skyBlue: return "#192735"
            case .redMagenta: return "#38232B"
            }
        }
        switch self {
        case .skyBlue: return "#EFF4F7"
        case .redMagenta: return "#F7F0F2"
        }
    }

    func bodyTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .skyBlue: return "#293640"
            case .redMagenta: return "#443039"
            }
        }
        switch self {
        case .skyBlue: return "#DCE4E9"
        case .redMagenta: return "#E9DDE1"
        }
    }

    func secondaryTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .skyBlue: return "#68737D"
            case .redMagenta: return "#77656C"
            }
        }
        switch self {
        case .skyBlue: return "#AEBAC2"
        case .redMagenta: return "#C0ADB4"
        }
    }

    func tertiaryTextHex(for colorScheme: ColorScheme) -> String {
        guard colorScheme == .dark else {
            switch self {
            case .skyBlue: return "#8A949C"
            case .redMagenta: return "#998A90"
            }
        }
        switch self {
        case .skyBlue: return "#89979F"
        case .redMagenta: return "#9F8D94"
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

enum TicketProgressColorPalette {
    static let sale = Color(hex: "#D47A36")
    static let application = Color(hex: "#983650")
    static let result = Color(hex: "#76528B")
    static let payment = Color(hex: "#247E85")
    static let acquired = Color(hex: "#54745A")
    static let attendance = Color(hex: "#B66A32")

    static func color(for stage: TicketProgressStage) -> Color {
        switch stage.kind {
        case .entry:
            return stage.title == "発売" ? sale : application
        case .result:
            return result
        case .payment:
            return payment
        case .acquired:
            return acquired
        }
    }

    static func color(forDeadlineLabel label: String, fallback: Color) -> Color {
        switch label {
        case "チケ発売":
            return sale
        case "抽選申込":
            return application
        case "抽選当落":
            return result
        case "チケ支払":
            return payment
        case "チケ取得":
            return acquired
        case "参加日":
            return attendance
        default:
            return fallback
        }
    }
}

struct FavorecoThemePalette {
    let baseTheme: FavorecoBaseTheme
    let mode: FavorecoThemeMode
    let unifiedColorHex: String

    static let standard = FavorecoThemePalette(
        baseTheme: .skyBlue,
        mode: .categoryAccent,
        unifiedColorHex: "#147C88"
    )

    var globalTint: Color {
        Color(hex: mode == .unified ? unifiedColorHex : baseTheme.accentHex)
    }

    var softTint: Color {
        Color(hex: baseTheme.softTintHex)
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

extension EnvironmentValues {
    var favorecoThemePalette: FavorecoThemePalette {
        get { self[FavorecoThemePaletteKey.self] }
        set { self[FavorecoThemePaletteKey.self] = newValue }
    }
}

extension Color {
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
