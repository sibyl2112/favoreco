import SwiftUI

private struct TheaterPosterFrameModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.95), lineWidth: 2)
                    .padding(3)
            }
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.46), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.48), radius: 18, y: 9)
    }
}

extension View {
    func theaterPosterFrame(tint: Color) -> some View {
        modifier(TheaterPosterFrameModifier(tint: tint))
    }
}
