//
//  FontRegistrar.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import CoreText
import Foundation

enum FontRegistrar {
    nonisolated static func registerBundledFonts() {
        [
            "NotoSansJP-wght",
            "NotoSerifJP-wght",
            "CormorantGaramond-wght",
        ].forEach(registerFont)
    }

    nonisolated private static func registerFont(named resourceName: String) {
        let bundledURL = Bundle.main.url(
            forResource: resourceName,
            withExtension: "ttf",
            subdirectory: "Resources/Fonts"
        ) ?? Bundle.main.url(forResource: resourceName, withExtension: "ttf")

        guard let url = bundledURL else {
            assertionFailure("Missing bundled font: \(resourceName)")
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
}
