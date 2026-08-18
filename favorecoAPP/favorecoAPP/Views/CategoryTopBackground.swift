//
//  CategoryTopBackground.swift
//  favorecoAPP
//
//  Extracted from CategoryTopView to isolate genre background presentation.
//

import SwiftUI
import UIKit

struct CategoryTopBackground: View {
    let style: CategoryTopBackgroundStyle
    let categoryColor: Color
    let colorScheme: ColorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch style {
        case .theater:
            [
                TheaterCategoryStyle.wine,
                TheaterCategoryStyle.deepWine,
                TheaterCategoryStyle.black,
            ]
        case .live:
            [
                LiveCategoryStyle.navy,
                LiveCategoryStyle.deepNavy,
                LiveCategoryStyle.blackNavy,
            ]
        case .themed:
            [
                categoryColor.opacity(colorScheme == .dark ? 0.12 : 0.10),
                Color(.systemGroupedBackground),
                Color(.systemGroupedBackground),
            ]
        }
    }
}
