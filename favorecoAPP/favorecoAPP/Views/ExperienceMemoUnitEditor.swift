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
                    reservesLineSpace: true
                )
            } else {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .accessibilityLabel("メモ")
                }
            }
        }
    }
}
