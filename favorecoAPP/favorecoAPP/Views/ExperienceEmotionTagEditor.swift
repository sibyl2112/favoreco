import Foundation
import SwiftUI

enum TheaterEmotionTags {
    static let presets = [
        "感動", "笑った", "泣いた", "圧倒された", "考えさせられた", "胸が熱くなった", "癒やされた", "驚いた",
    ]

    static func names(from rawValue: String) -> [String] {
        var seen = Set<String>()
        return rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert(normalizedKey($0)).inserted }
    }

    static func encoded(_ values: [String]) -> String {
        names(from: values.joined(separator: "、")).joined(separator: "、")
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }
}

struct ExperienceEmotionTagEditor: View {
    @Binding var tagNamesText: String

    private var selectedNames: Set<String> {
        Set(TheaterEmotionTags.names(from: tagNamesText))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("感情タグ")
                .font(FavorecoTypography.bodyStrong)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(TheaterEmotionTags.presets, id: \.self) { tag in
                    Button {
                        toggle(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedNames.contains(tag) ? "checkmark.circle.fill" : "circle")
                            Text(tag).lineLimit(1)
                        }
                        .font(FavorecoTypography.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(
                            selectedNames.contains(tag) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("その他のタグ（カンマ区切り）", text: $tagNamesText)
            Text("この観劇回で感じたことです。共通のタグマスターへ集約され、他ジャンルでも再利用できます。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggle(_ tag: String) {
        var names = TheaterEmotionTags.names(from: tagNamesText)
        if names.contains(tag) {
            names.removeAll { $0 == tag }
        } else {
            names.append(tag)
        }
        tagNamesText = TheaterEmotionTags.encoded(names)
    }
}
