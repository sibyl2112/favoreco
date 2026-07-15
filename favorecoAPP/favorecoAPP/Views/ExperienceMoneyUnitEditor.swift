//
//  ExperienceMoneyUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceMoneyUnitEditor: View {
    @Binding var amountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("合計金額（例: 8500）", text: $amountText)
                .keyboardType(.numberPad)
                .accessibilityLabel("合計金額")
                .accessibilityHint("数字で入力します")

            Text("チケット代、購入額、交通費などの合計メモとして保存します。内訳管理は後続で追加します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
