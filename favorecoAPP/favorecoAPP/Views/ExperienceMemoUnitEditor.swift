//
//  ExperienceMemoUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceMemoUnitEditor: View {
    @Binding var text: String
    @Binding var styleRuns: [MemoStyleRun]
    let placeholder: String
    var usesExplicitTheaterLayout = false
    var usesFlatToolbar = false
    @StateObject private var formattingController = RichMemoFormattingController()
    @State private var editorHeight: CGFloat = 190

    init(
        text: Binding<String>,
        styleRuns: Binding<[MemoStyleRun]>,
        placeholder: String,
        usesExplicitTheaterLayout: Bool = false,
        usesFlatToolbar: Bool = false
    ) {
        _text = text
        _styleRuns = styleRuns
        self.placeholder = placeholder
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
        self.usesFlatToolbar = usesFlatToolbar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usesExplicitTheaterLayout {
                Text("感想メモ（任意）")
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .subheadline))
            }

            formattingToolbar

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.055))

                if text.isEmpty {
                    Text(placeholder)
                        .font(FavorecoTypography.jpSans(15, weight: .regular, relativeTo: .body))
                        .foregroundStyle(.tertiary)
                        .padding(10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                RichMemoTextView(
                    text: $text,
                    styleRuns: $styleRuns,
                    controller: formattingController,
                    contentHeight: $editorHeight
                )
                .frame(maxWidth: .infinity, minHeight: 190)
                .clipped()
            }
            .frame(maxWidth: .infinity, minHeight: editorHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.24), lineWidth: 0.8)
            }
            .contentShape(Rectangle())
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: 6) {
            formatButton("B", accessibilityLabel: "太字") {
                formattingController.toggleBold()
            }
            formatButton("U", accessibilityLabel: "下線", isUnderlined: true) {
                formattingController.toggleUnderline()
            }
            Button {
                formattingController.toggleBullet()
            } label: {
                FavorecoIcon(systemName: "list.bullet", size: 15)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .modifier(FlatMemoToolbarButtonModifier(isEnabled: usesFlatToolbar))
            .accessibilityLabel("箇条書き")

            Menu {
                ForEach(MemoTextColorKey.allCases) { color in
                    Button {
                        formattingController.setColor(color)
                    } label: {
                        Text("\(color.menuSwatch)  \(color.title)")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    FavorecoIcon(systemName: "paintpalette", size: 15)
                    Text("文字色")
                        .font(FavorecoTypography.jpSans(11, weight: .semibold, relativeTo: .caption))
                }
                .frame(height: 30)
            }
            .buttonStyle(.plain)
            .modifier(FlatMemoToolbarButtonModifier(isEnabled: usesFlatToolbar))

            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .padding(usesFlatToolbar ? 5 : 0)
        .background(
            usesFlatToolbar ? Color.secondary.opacity(0.055) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func formatButton(
        _ title: String,
        accessibilityLabel: String,
        isUnderlined: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .underline(isUnderlined)
                .frame(width: 34, height: 30)
        }
        .buttonStyle(.plain)
        .modifier(FlatMemoToolbarButtonModifier(isEnabled: usesFlatToolbar))
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FlatMemoToolbarButtonModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .foregroundStyle(Color(hex: "#8B2F45"))
                .frame(minWidth: 38, minHeight: 32)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        } else {
            content
                .foregroundStyle(.primary)
                .frame(minWidth: 38, minHeight: 32)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        }
    }
}
