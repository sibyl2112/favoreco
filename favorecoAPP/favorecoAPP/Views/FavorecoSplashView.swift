import SwiftUI

struct FavorecoSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var hasEmerged = false
    @State private var isVisible = true
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            Color(hex: "#F7F7F3")
                .ignoresSafeArea()

            Text("FAVORECO")
                .font(FavorecoTypography.latinDisplay(42, weight: .semibold, relativeTo: .largeTitle))
                .tracking(5.5)
                .foregroundStyle(Color(hex: "#172735"))
                .scaleEffect(reduceMotion ? 1 : (hasEmerged ? 1 : 0.93))
                .opacity(hasEmerged ? 1 : 0.12)
                .shadow(
                    color: Color.black.opacity(hasEmerged ? 0.24 : 0),
                    radius: hasEmerged ? 13 : 1,
                    x: 0,
                    y: hasEmerged ? 9 : 1
                )
                .overlay {
                    Text("FAVORECO")
                        .font(FavorecoTypography.latinDisplay(42, weight: .semibold, relativeTo: .largeTitle))
                        .tracking(5.5)
                        .foregroundStyle(Color.white.opacity(hasEmerged ? 0.34 : 0))
                        .offset(y: -1)
                        .blendMode(.screen)
                }
                .accessibilityLabel("Favoreco")
        }
        .opacity(isVisible ? 1 : 0)
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            if reduceMotion {
                hasEmerged = true
                try? await Task.sleep(for: .milliseconds(450))
            } else {
                withAnimation(.easeOut(duration: 0.72)) {
                    hasEmerged = true
                }
                try? await Task.sleep(for: .milliseconds(1_050))
            }

            withAnimation(.easeInOut(duration: 0.24)) {
                isVisible = false
            }
            try? await Task.sleep(for: .milliseconds(260))
            onFinished()
        }
        .allowsHitTesting(isVisible)
    }
}

#Preview {
    FavorecoSplashView(onFinished: {})
}
