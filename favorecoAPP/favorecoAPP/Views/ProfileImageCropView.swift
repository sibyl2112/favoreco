import SwiftUI
import UIKit

struct ProfilePhotoCropDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ProfileImageCropView: View {
    let image: UIImage
    let onApply: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cropSide: CGFloat = 1
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    private let maximumZoom: CGFloat = 4

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width - 40, 1)
                let availableHeight = max(proxy.size.height - 150, 1)
                let side = min(availableWidth, availableHeight, 420)

                VStack(spacing: 22) {
                    Spacer(minLength: 12)

                    cropCanvas(side: side)
                        .frame(width: side, height: side)
                        .onAppear {
                            updateCropSide(side)
                        }
                        .onChange(of: side) { _, newValue in
                            updateCropSide(newValue)
                        }

                    Text("ピンチで拡大・縮小、ドラッグで位置を調整")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(Color.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Color.black.opacity(0.72),
                            in: Capsule()
                        )

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            resetPosition()
                        }
                    } label: {
                        Label("位置をリセット", systemImage: "arrow.counterclockwise")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(Color.white.opacity(0.94))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Color.black.opacity(0.72),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black)
            .navigationTitle("位置とサイズを調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.82), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        guard let data = croppedImageData() else { return }
                        onApply(data)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private func cropCanvas(side: CGFloat) -> some View {
        let baseSize = aspectFillSize(for: side)
        let displayedSize = CGSize(
            width: baseSize.width * zoom,
            height: baseSize.height * zoom
        )

        return ZStack {
            Color.black

            Image(uiImage: image)
                .resizable()
                .frame(width: displayedSize.width, height: displayedSize.height)
                .offset(offset)
        }
        .frame(width: side, height: side)
        .clipped()
        .overlay {
            ProfileCropShade()
                .fill(Color.black.opacity(0.46), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            Circle()
                .strokeBorder(Color.white.opacity(0.96), lineWidth: 2)
                .padding(1)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .accessibilityLabel("プロフィール写真の切り抜き範囲")
        .accessibilityHint("ピンチで拡大縮小し、ドラッグで位置を調整します")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let proposed = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, zoom: zoom)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, zoom: zoom)
                settledOffset = offset
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(max(settledZoom * value.magnification, 1), maximumZoom)
                offset = clampedOffset(offset, zoom: zoom)
            }
            .onEnded { _ in
                zoom = min(max(zoom, 1), maximumZoom)
                settledZoom = zoom
                offset = clampedOffset(offset, zoom: zoom)
                settledOffset = offset
            }
    }

    private func updateCropSide(_ side: CGFloat) {
        guard side > 1, abs(cropSide - side) > 0.5 else { return }
        cropSide = side
        offset = clampedOffset(offset, zoom: zoom)
        settledOffset = offset
    }

    private func resetPosition() {
        zoom = 1
        settledZoom = 1
        offset = .zero
        settledOffset = .zero
    }

    private func aspectFillSize(for side: CGFloat) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGSize(width: side, height: side)
        }
        let scale = max(side / image.size.width, side / image.size.height)
        return CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
    }

    private func clampedOffset(_ proposed: CGSize, zoom: CGFloat) -> CGSize {
        let baseSize = aspectFillSize(for: cropSide)
        let horizontalLimit = max((baseSize.width * zoom - cropSide) / 2, 0)
        let verticalLimit = max((baseSize.height * zoom - cropSide) / 2, 0)
        return CGSize(
            width: min(max(proposed.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit), verticalLimit)
        )
    }

    private func croppedImageData() -> Data? {
        guard cropSide > 1, image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let outputSide: CGFloat = 320
        let baseSize = aspectFillSize(for: cropSide)
        let outputScale = outputSide / cropSide
        let drawSize = CGSize(
            width: baseSize.width * zoom * outputScale,
            height: baseSize.height * zoom * outputScale
        )
        let drawOrigin = CGPoint(
            x: (outputSide - drawSize.width) / 2 + offset.width * outputScale,
            y: (outputSide - drawSize.height) / 2 + offset.height * outputScale
        )

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide)
        )
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}

private struct ProfileCropShade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
        return path
    }
}
