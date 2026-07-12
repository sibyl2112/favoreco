//
//  Color+Hex.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI
import UIKit

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

struct FavorecoThemePalette {
    let mode: FavorecoThemeMode
    let unifiedColorHex: String

    static let standard = FavorecoThemePalette(
        mode: .categoryAccent,
        unifiedColorHex: "#147C88"
    )

    var globalTint: Color {
        Color(hex: mode == .unified ? unifiedColorHex : "#147C88")
    }

    func categoryColor(hex: String) -> Color {
        Color(hex: mode == .unified ? unifiedColorHex : hex)
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
