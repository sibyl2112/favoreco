import SwiftUI

struct DetailEyecatchPreviewRequest: Identifiable {
    let id = UUID()
    let reference: ThumbnailReference
}

struct DetailEyecatchPreview: View {
    let request: DetailEyecatchPreviewRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            GeometryReader { geometry in
                ThumbnailImage(
                    reference: request.reference,
                    displaySize: CGSize(
                        width: max(geometry.size.width - 32, 1),
                        height: max(geometry.size.height - 80, 1)
                    ),
                    contentMode: .fit
                ) {
                    ProgressView()
                        .tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 40)
                // The background owns the dismiss gesture so a tap anywhere
                // outside the rendered image (and a second tap on the image)
                // always has a deterministic way to close the preview.
                .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.52), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("拡大表示を閉じる")
                }
                Spacer()
            }
            .padding(16)
        }
        .presentationBackground(.clear)
        .statusBarHidden(true)
    }
}
