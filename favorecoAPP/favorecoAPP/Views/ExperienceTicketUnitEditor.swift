//
//  ExperienceTicketUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceTicketUnitEditor: View {
    @Binding var outcomeKey: String
    @Binding var seatText: String
    var usesExplicitTheaterLayout = false

    var body: some View {
        Group {
            if usesExplicitTheaterLayout {
                explicitTheaterContent
            } else {
                standardContent
            }
        }
    }

    private var explicitTheaterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplicitFormControlRow(title: "チケット取得状況", isOptional: true) {
                Picker("チケット取得状況", selection: $outcomeKey) {
                    ForEach(ExperienceTicketPlanOption.all) { option in
                        Text(option.name).tag(option.key)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()
                .overlay(ExplicitFormMetrics.rowSeparatorColor)

            ExplicitFormTextField(
                title: "座席・整理番号（任意）",
                prompt: "例：S席・1階A列12番",
                text: $seatText,
                axis: .vertical,
                minimumLines: 1,
                maximumLines: 2,
                labelStyle: .horizontal
            )

            Text("この回のチケット取得状況と座席を記録します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("チケット取得状況", selection: $outcomeKey) {
                ForEach(ExperienceTicketPlanOption.all) { option in
                    Text(option.name).tag(option.key)
                }
            }

            TextField(
                "席種・座席・メモ（例: S席・1階A列12番 / 整理番号B120）",
                text: $seatText,
                axis: .vertical
            )
            .lineLimit(1...3)

            Text("この回のチケット取得状況と座席を記録します。")
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
        ExperienceTicketPlanOption(key: "paid", name: "支払済み"),
        ExperienceTicketPlanOption(key: "ticketed", name: "発券済み"),
        ExperienceTicketPlanOption(key: "attended", name: "参加済み"),
        ExperienceTicketPlanOption(key: "canceled", name: "中止・キャンセル")
    ]
}
