import SwiftUI

struct ExperienceAdvancedUnitEditor: View {
    @Binding var entries: [AdvancedFieldEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text("ジャンル固有の項目を自由に追加できます。例: 精米歩合、所要時間、購入店舗、同行者メモなど。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach($entries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("項目名（例: 所要時間）", text: $entry.label)
                        TextField("値（例: 90分）", text: $entry.value, axis: .vertical)
                            .lineLimit(1...3)

                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Label("この項目を削除", systemImage: "minus.circle")
                        }
                        .font(FavorecoTypography.caption)
                    }
                    .padding(.vertical, 6)
                }
            }

            Button {
                entries.append(AdvancedFieldEntry())
            } label: {
                Label("項目を追加", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
