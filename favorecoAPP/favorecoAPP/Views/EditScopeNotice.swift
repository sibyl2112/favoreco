import SwiftUI

/// 入力した情報がどこへ反映されるかを、保存モデル名を使わずに示す。
struct EditScopeNotice: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let scope: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("反映先")
                .font(FavorecoTypography.jpSans(9.5, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(themePalette.globalTint)
                .padding(.horizontal, 7)
                .frame(minHeight: 21)
                .background(themePalette.globalTint.opacity(0.11), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(scope)
                    .font(FavorecoTypography.jpSans(12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(FavorecoTypography.jpSans(10.5, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themePalette.globalTint.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(themePalette.globalTint.opacity(0.22), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("反映先、\(scope)。\(detail)")
    }
}
