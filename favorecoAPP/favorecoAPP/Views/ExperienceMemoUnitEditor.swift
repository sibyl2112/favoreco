//
//  ExperienceMemoUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceMemoUnitEditor: View {
    @Binding var text: String
    let placeholder: String
    var usesExplicitTheaterLayout = false

    var body: some View {
        Group {
            if usesExplicitTheaterLayout {
                ExplicitFormTextField(
                    title: "感想メモ（任意）",
                    prompt: placeholder,
                    text: $text,
                    axis: .vertical,
                    minimumLines: 5,
                    maximumLines: 5,
                    labelStyle: .horizontal,
                    reservesLineSpace: true,
                    showsInputBoundary: true
                )
            } else {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.055))

                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 10)
                            .padding(.horizontal, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
                        .padding(.horizontal, 2)
                        .background(Color.clear)
                        .accessibilityLabel("メモ")
                }
                .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.24), lineWidth: 0.8)
                }
                .contentShape(Rectangle())
            }
        }
    }
}
