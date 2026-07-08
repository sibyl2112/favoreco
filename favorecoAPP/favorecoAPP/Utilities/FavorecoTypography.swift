//
//  FavorecoTypography.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI

enum FavorecoTypography {
    private static let jpSans = "Noto Sans JP"
    private static let jpSerif = "Noto Serif JP"
    private static let latinDisplay = "Cormorant Garamond"

    static func jpSans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(jpSans, size: size, relativeTo: textStyle).weight(weight)
    }

    static func jpSerif(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(jpSerif, size: size, relativeTo: textStyle).weight(weight)
    }

    static func latinDisplay(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(latinDisplay, size: size, relativeTo: textStyle).weight(weight)
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
