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
                .background(Color(.secondarySystemGroupedBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.20), lineWidth: 1)
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
        .frame(height: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ジャンルを選ぶ")
    }

    private func allLabel(isSelected: Bool, showsLeadingDivider: Bool) -> some View {
        segmentLabel(
            title: "すべて",
            tint: themePalette.globalTint,
            isSelected: isSelected,
            showsLeadingDivider: showsLeadingDivider
        )
        .id("all-genres")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("すべてのジャンル")
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityHint(isSelected ? "全ジャンルを表示しています" : "Homeへ戻ります")
    }

    private func genreLabel(category: RecordCategory, isSelected: Bool, showsLeadingDivider: Bool) -> some View {
        let tint = themePalette.categoryColor(hex: category.colorHex)

        return segmentLabel(
            title: category.name.isEmpty ? "無題" : category.name,
            tint: tint,
            isSelected: isSelected,
            showsLeadingDivider: showsLeadingDivider
        )
        .id(category.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name.isEmpty ? "無題ジャンル" : category.name)
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
            .font(FavorecoTypography.jpSans(13, weight: isSelected ? .bold : .semibold, relativeTo: .caption))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(isSelected ? tint : Color.clear)
            .overlay(alignment: .leading) {
                if showsLeadingDivider {
                    Rectangle()
                        .fill(isSelected ? Color.white.opacity(0.28) : Color.primary.opacity(0.16))
                        .frame(width: 1, height: 22)
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
