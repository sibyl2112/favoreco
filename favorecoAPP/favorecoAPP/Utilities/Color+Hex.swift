//
//  Color+Hex.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/09.
//

import SwiftUI

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
}
