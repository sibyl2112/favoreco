import SwiftUI

struct LiveSetlistEditor: View {
    @Binding var entries: [LiveSetlistEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曲だけでなく、MCやアンコールの区切りも同じ並びに残せます。未入力でも参戦記録は保存できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)

            ForEach($entries) { $entry in
                HStack(alignment: .center, spacing: 8) {
                    Menu {
                        ForEach(LiveSetlistEntryKind.allCases) { kind in
                            Button {
                                entry.kind = kind
                            } label: {
                                if entry.kind == kind {
                                    Label(kind.displayName, systemImage: "checkmark")
                                } else {
                                    Text(kind.displayName)
                                }
                            }
                        }
                    } label: {
                        Text(entry.kind.displayName)
                            .font(FavorecoTypography.captionStrong)
                            .frame(minWidth: 54)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.10), in: Capsule())
                    }

                    TextField(entry.kind == .song ? "曲名" : "内容（任意）", text: $entry.text)
                        .textFieldStyle(.plain)

                    Button(role: .destructive) {
                        entries.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("この行を削除")
                }
                .padding(.vertical, 4)

                Divider()
            }

            Button {
                entries.append(LiveSetlistEntry())
            } label: {
                Label("曲・MC・アンコールを追加", systemImage: "plus.circle.fill")
                    .font(FavorecoTypography.jpSans(13, weight: .semibold, relativeTo: .body))
            }
            .buttonStyle(.plain)
        }
    }
}
