//
//  ExperienceMemoUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceMemoUnitEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
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
