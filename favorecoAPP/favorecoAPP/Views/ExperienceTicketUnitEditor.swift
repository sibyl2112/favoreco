//
//  ExperienceTicketUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceTicketUnitEditor: View {
    @Binding var outcomeKey: String
    @Binding var seatText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("状態", selection: $outcomeKey) {
                ForEach(ExperienceTicketPlanOption.all) { option in
                    Text(option.name).tag(option.key)
                }
            }

            TextField(
                "座席・チケットメモ（例: 1階A列12番 / 整理番号B120）",
                text: $seatText,
                axis: .vertical
            )
            .lineLimit(1...3)

            Text("この記録には状態と座席メモだけを残します。申込、当落、入金、発券期限などは「予定・チケット」で管理します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ExperienceTicketPlanOption: Identifiable {
    let key: String
    let name: String

    var id: String { key }

    static let all: [ExperienceTicketPlanOption] = [
        ExperienceTicketPlanOption(key: "", name: "未設定"),
        ExperienceTicketPlanOption(key: "planned", name: "予定"),
        ExperienceTicketPlanOption(key: "applied", name: "申込中"),
        ExperienceTicketPlanOption(key: "won", name: "当選"),
        ExperienceTicketPlanOption(key: "paid", name: "入金済み"),
        ExperienceTicketPlanOption(key: "ticketed", name: "発券済み"),
        ExperienceTicketPlanOption(key: "attended", name: "参加済み"),
        ExperienceTicketPlanOption(key: "canceled", name: "中止・キャンセル")
    ]
}
