//
//  FavorecoTypography.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI

enum AppFontStyle: String, CaseIterable, Identifiable {
    case standard
    case sans
    case serif

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return "スタンダード"
        case .sans: return "ゴシック中心"
        case .serif: return "明朝中心"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "本文はゴシック、印象的な見出しは明朝"
        case .sans: return "日本語をすっきりしたゴシックで統一"
        case .serif: return "日本語を落ち着いた明朝で統一"
        }
    }
}

enum AppFontWeight: String, CaseIterable, Identifiable {
    case light
    case standard
    case bold

    var id: String { rawValue }

    var name: String {
        switch self {
        case .light: return "細め"
        case .standard: return "標準"
        case .bold: return "太め"
        }
    }
}

enum FavorecoTypography {
    private static let jpSansName = "Noto Sans JP"
    private static let jpSerifName = "Noto Serif JP"
    private static let latinDisplayName = "Cormorant Garamond"

    static func brandColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.84, green: 0.88, blue: 0.91)
            : Color(red: 25 / 255, green: 39 / 255, blue: 53 / 255)
    }

    static var effectiveStyle: AppFontStyle {
        let rawStyle = UserDefaults.standard.string(forKey: AppStorageKeys.fontStyle) ?? ""
        let style = AppFontStyle(rawValue: rawStyle) ?? .standard
        let rawPlan = UserDefaults.standard.string(forKey: AppStorageKeys.purchasedPlanCache) ?? ""
        let plan = FavorecoPlan(rawValue: rawPlan) ?? .free
        return plan.includesLocalFullFeatures ? style : .standard
    }

    static var effectiveWeight: AppFontWeight {
        let rawWeight = UserDefaults.standard.string(forKey: AppStorageKeys.fontWeight) ?? ""
        let weight = AppFontWeight(rawValue: rawWeight) ?? .standard
        let rawPlan = UserDefaults.standard.string(forKey: AppStorageKeys.purchasedPlanCache) ?? ""
        let plan = FavorecoPlan(rawValue: rawPlan) ?? .free
        return plan.includesLocalFullFeatures ? weight : .standard
    }

    static func jpSans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(japaneseFontName(prefersSerif: false), size: size, relativeTo: textStyle)
            .weight(adjusted(weight))
    }

    static func jpSerif(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(japaneseFontName(prefersSerif: true), size: size, relativeTo: textStyle)
            .weight(adjusted(weight))
    }

    static func latinDisplay(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(latinDisplayName, size: size, relativeTo: textStyle)
            .weight(adjusted(weight))
    }

    private static func japaneseFontName(prefersSerif: Bool) -> String {
        switch effectiveStyle {
        case .standard:
            return prefersSerif ? jpSerifName : jpSansName
        case .sans:
            return jpSansName
        case .serif:
            return jpSerifName
        }
    }

    private static func adjusted(_ weight: Font.Weight) -> Font.Weight {
        switch effectiveWeight {
        case .standard:
            return weight
        case .light:
            switch weight {
            case .black, .heavy, .bold: return .semibold
            case .semibold: return .medium
            case .medium: return .regular
            default: return .light
            }
        case .bold:
            switch weight {
            case .black, .heavy: return .black
            case .bold, .semibold: return .bold
            case .medium: return .semibold
            default: return .medium
            }
        }
    }

    static var appLogo: Font {
        latinDisplay(36, weight: .semibold, relativeTo: .largeTitle)
    }

    static var heroLead: Font {
        jpSans(22, weight: .semibold, relativeTo: .title2)
    }

    static var heroTitle: Font {
        jpSerif(34, weight: .bold, relativeTo: .largeTitle)
    }

    static var sectionTitle: Font {
        jpSans(17, weight: .semibold, relativeTo: .headline)
    }

    static var cardTitle: Font {
        jpSans(17, weight: .semibold, relativeTo: .headline)
    }

    static var body: Font {
        jpSans(15, weight: .regular, relativeTo: .body)
    }

    static var bodyStrong: Font {
        jpSans(15, weight: .semibold, relativeTo: .body)
    }

    static var caption: Font {
        jpSans(12, weight: .regular, relativeTo: .caption)
    }

    static var captionStrong: Font {
        jpSans(12, weight: .semibold, relativeTo: .caption)
    }
}

enum AppTextSize: String, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var name: String {
        switch self {
        case .small: return "小さめ"
        case .standard: return "標準"
        case .large: return "大きめ"
        case .extraLarge: return "特大"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .medium
        case .standard: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "端末設定に従う"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppTextSizeModifier: ViewModifier {
    @AppStorage(AppStorageKeys.followsSystemTextSize) private var followsSystemTextSize = true
    @AppStorage(AppStorageKeys.appTextSize) private var appTextSizeRaw = AppTextSize.standard.rawValue

    @ViewBuilder
    func body(content: Content) -> some View {
        if followsSystemTextSize {
            content
        } else {
            content.dynamicTypeSize(appTextSize.dynamicTypeSize)
        }
    }

    private var appTextSize: AppTextSize {
        AppTextSize(rawValue: appTextSizeRaw) ?? .standard
    }
}
