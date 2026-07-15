//
//  GenreNavigationStrip.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/15.
//

import SwiftUI

struct GenreNavigationStrip: View {
    let categories: [RecordCategory]
    var selectedCategoryID: UUID?

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(categories) { category in
                        if category.id == selectedCategoryID {
                            genreLabel(category: category, isSelected: true)
                        } else {
                            NavigationLink {
                                CategoryTopView(category: category)
                            } label: {
                                genreLabel(category: category, isSelected: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToSelection(with: proxy, animated: false)
            }
            .onChange(of: selectedCategoryID) { _, _ in
                scrollToSelection(with: proxy, animated: true)
            }
        }
        .frame(minHeight: 66)
        .accessibilityLabel("ジャンルを選ぶ")
    }

    private func genreLabel(category: RecordCategory, isSelected: Bool) -> some View {
        let tint = themePalette.categoryColor(hex: category.colorHex)

        return VStack(spacing: 5) {
            Image(systemName: category.iconSymbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : tint)
                .frame(width: 36, height: 36)
                .background(isSelected ? tint : tint.opacity(0.12), in: Circle())

            Text(category.name.isEmpty ? "無題" : category.name)
                .font(FavorecoTypography.jpSans(11, weight: isSelected ? .bold : .semibold, relativeTo: .caption2))
                .foregroundStyle(isSelected ? tint : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Capsule()
                .fill(isSelected ? tint : Color.clear)
                .frame(width: 24, height: 2)
        }
        .frame(width: 62, alignment: .top)
        .contentShape(Rectangle())
        .id(category.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name.isEmpty ? "無題ジャンル" : category.name)
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityHint(isSelected ? "現在のジャンルです" : "ジャンルページを開きます")
    }

    private func scrollToSelection(with proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedCategoryID else { return }
        let action = {
            proxy.scrollTo(selectedCategoryID, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.2), action)
        } else {
            action()
        }
    }
}
