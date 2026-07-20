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
    var onSelectAll: (() -> Void)? = nil
    var onSelectCategory: ((RecordCategory) -> Void)? = nil

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .center, spacing: 0) {
                    if selectedCategoryID == nil {
                        allLabel(isSelected: true, showsLeadingDivider: false)
                    } else {
                        Button {
                            onSelectAll?()
                        } label: {
                            allLabel(isSelected: false, showsLeadingDivider: false)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(categories) { category in
                        if category.id == selectedCategoryID {
                            genreLabel(category: category, isSelected: true, showsLeadingDivider: true)
                        } else if let onSelectCategory {
                            Button {
                                onSelectCategory(category)
                            } label: {
                                genreLabel(category: category, isSelected: false, showsLeadingDivider: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                CategoryTopView(category: category)
                            } label: {
                                genreLabel(category: category, isSelected: false, showsLeadingDivider: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToSelection(with: proxy, animated: false)
            }
            .onChange(of: selectedCategoryID) { _, _ in
                scrollToSelection(with: proxy, animated: true)
            }
        }
        .frame(height: 46)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ジャンルを選ぶ")
    }

    private func allLabel(isSelected: Bool, showsLeadingDivider: Bool) -> some View {
        segmentLabel(
            title: "総合",
            tint: themePalette.globalTint,
            isSelected: isSelected,
            showsLeadingDivider: showsLeadingDivider
        )
        .id("all-genres")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ジャンル横断の総合画面")
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityHint(isSelected ? "ジャンル横断の情報を表示しています" : "総合画面へ戻ります")
    }

    private func genreLabel(category: RecordCategory, isSelected: Bool, showsLeadingDivider: Bool) -> some View {
        let tint = category.templateKey == "live"
            ? LiveCategoryStyle.teal
            : themePalette.categoryColor(hex: category.colorHex)
        let displayName = category.templateKey == "live"
            ? "LIVE"
            : category.name.isEmpty ? "無題" : category.name

        return segmentLabel(
            title: displayName,
            tint: tint,
            isSelected: isSelected,
            showsLeadingDivider: showsLeadingDivider
        )
        .id(category.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.templateKey == "live" ? "ライブ" : category.name.isEmpty ? "無題ジャンル" : category.name)
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityHint(
            isSelected
                ? "現在のジャンルです"
                : onSelectCategory == nil ? "ジャンルページを開きます" : "このジャンルへ切り替えます"
        )
    }

    private func segmentLabel(
        title: String,
        tint: Color,
        isSelected: Bool,
        showsLeadingDivider: Bool
    ) -> some View {
        Text(title)
            .font(FavorecoTypography.jpSerif(14, weight: isSelected ? .bold : .medium, relativeTo: .body))
            .foregroundStyle(isSelected ? tint : Color.primary.opacity(0.82))
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .overlay(alignment: .leading) {
                if showsLeadingDivider {
                    Rectangle()
                        .fill(Color.primary.opacity(0.16))
                        .frame(width: 1, height: 20)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(tint)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                }
            }
            .contentShape(Rectangle())
    }

    private func scrollToSelection(with proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            if let selectedCategoryID {
                proxy.scrollTo(selectedCategoryID, anchor: .center)
            } else {
                proxy.scrollTo("all-genres", anchor: .leading)
            }
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.2), action)
        } else {
            action()
        }
    }
}
