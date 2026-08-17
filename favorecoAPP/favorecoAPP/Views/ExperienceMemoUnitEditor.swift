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
    @StateObject private var formattingController = RichMemoFormattingController()
    @State private var editorHeight: CGFloat = 190

    init(
        text: Binding<String>,
        styleRuns: Binding<[MemoStyleRun]>,
        placeholder: String,
        usesExplicitTheaterLayout: Bool = false
    ) {
        _text = text
        _styleRuns = styleRuns
        self.placeholder = placeholder
        self.usesExplicitTheaterLayout = usesExplicitTheaterLayout
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
            .buttonStyle(.bordered)
            .accessibilityLabel("箇条書き")

            Menu {
                ForEach(MemoTextColorKey.allCases) { color in
                    Button {
                        formattingController.setColor(color)
                    } label: {
                        Label(color.title, systemImage: "circle.fill")
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
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .controlSize(.small)
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
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
    }
}
