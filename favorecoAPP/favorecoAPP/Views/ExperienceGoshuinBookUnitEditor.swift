import SwiftUI

struct ExperienceGoshuinBookUnitEditor: View {
    @Binding var sizeKey: String
    @Binding var aspectRatioKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("御朱印帳サイズ", selection: $sizeKey) {
                ForEach(GoshuinBookSize.all) { size in
                    Text("\(size.name)（\(size.displaySize)）").tag(size.key)
                }
            }

            let selectedSize = GoshuinBookSize.option(for: sizeKey)
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSize.note)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                Text("御朱印写真はこのサイズ比に合わせて表示します。見開きや横向きの場合は、ここでサイズを変えてから写真を追加してください。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if sizeKey.isEmpty {
                sizeKey = GoshuinBookSize.standard.key
            }
            if aspectRatioKey.isEmpty {
                aspectRatioKey = EyecatchAspectRatio.goshuinStandard.key
            }
        }
        .onChange(of: sizeKey) { _, newValue in
            let size = GoshuinBookSize.option(for: newValue)
            aspectRatioKey = size.key == GoshuinBookSize.wide.key
                ? EyecatchAspectRatio.labelLandscape.key
                : EyecatchAspectRatio.goshuinStandard.key
        }
    }
}
