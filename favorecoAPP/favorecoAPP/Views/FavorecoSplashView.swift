import SwiftUI

struct FavorecoSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var hasEmerged = false
    @State private var burstProgress: CGFloat = 0
    @State private var isVisible = true
    @State private var hasStarted = false

    private static let inkParticles = FavorecoSplashInkParticle.makeParticles(count: 68)

    var body: some View {
        ZStack {
            Color(hex: "#F7F7F3")
                .ignoresSafeArea()

            ZStack {
                Text("FAVORECO")
                    .font(FavorecoTypography.latinDisplay(42, weight: .semibold, relativeTo: .largeTitle))
                    .tracking(5.5)
                    .foregroundStyle(Color(hex: "#172735"))
                    .scaleEffect(reduceMotion ? 1 : (hasEmerged ? 1 + (burstProgress * 0.035) : 0.93))
                    .blur(radius: reduceMotion ? 0 : burstProgress * 2.2)
                    .opacity(wordOpacity)
                    .shadow(
                        color: Color.black.opacity(hasEmerged ? 0.24 * Double(1 - burstProgress) : 0),
                        radius: hasEmerged ? 13 : 1,
                        x: 0,
                        y: hasEmerged ? 9 : 1
                    )
                    .overlay {
                        Text("FAVORECO")
                            .font(FavorecoTypography.latinDisplay(42, weight: .semibold, relativeTo: .largeTitle))
                            .tracking(5.5)
                            .foregroundStyle(Color.white.opacity(hasEmerged ? 0.34 * Double(1 - burstProgress) : 0))
                            .offset(y: -1)
                            .blendMode(.screen)
                    }

                if !reduceMotion {
                    inkSplash
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Favoreco")
        }
        .opacity(isVisible ? 1 : 0)
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            if reduceMotion {
                hasEmerged = true
                guard await wait(for: .milliseconds(1_800)) else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    isVisible = false
                }
                guard await wait(for: .milliseconds(480)) else { return }
            } else {
                withAnimation(.easeOut(duration: 0.9)) {
                    hasEmerged = true
                }
                guard await wait(for: .milliseconds(2_250)) else { return }

                withAnimation(.easeOut(duration: 0.9)) {
                    burstProgress = 1
                }
                guard await wait(for: .milliseconds(920)) else { return }

                withAnimation(.easeInOut(duration: 0.24)) {
                    isVisible = false
                }
                guard await wait(for: .milliseconds(260)) else { return }
            }

            onFinished()
        }
        .allowsHitTesting(isVisible)
    }

    private var wordOpacity: Double {
        guard hasEmerged else { return 0.12 }
        return Double(max(0, 1 - (burstProgress * 1.35)))
    }

    private var inkSplash: some View {
        ZStack {
            ForEach(Self.inkParticles) { particle in
                FavorecoSplashInkParticleView(
                    particle: particle,
                    totalProgress: burstProgress
                )
            }
        }
        .frame(width: 280, height: 120)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func wait(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

private struct FavorecoSplashInkParticleView: View {
    let particle: FavorecoSplashInkParticle
    let totalProgress: CGFloat

    private var progress: CGFloat {
        particle.progress(for: totalProgress)
    }

    private var particleWidth: CGFloat {
        particle.diameter * particle.stretch
    }

    private var particleScale: CGFloat {
        max(0.35, 1 - (progress * 0.6))
    }

    private var particleRotation: Double {
        particle.rotation + (Double(progress) * particle.spin)
    }

    private var particleOffset: CGSize {
        let easedProgress = particle.eased(progress)
        return CGSize(
            width: particle.origin.width + (particle.travel.width * easedProgress),
            height: particle.origin.height + (particle.travel.height * easedProgress)
        )
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color(hex: "#172735").opacity(particle.inkOpacity))
            .frame(width: particleWidth, height: particle.diameter)
            .scaleEffect(particleScale)
            .rotationEffect(.degrees(particleRotation))
            .offset(particleOffset)
            .opacity(particle.opacity(for: progress))
    }
}

private struct FavorecoSplashInkParticle: Identifiable {
    let id: Int
    let origin: CGSize
    let travel: CGSize
    let diameter: CGFloat
    let stretch: CGFloat
    let rotation: Double
    let spin: Double
    let delay: CGFloat
    let inkOpacity: Double

    func progress(for totalProgress: CGFloat) -> CGFloat {
        guard totalProgress > delay else { return 0 }
        return min(1, (totalProgress - delay) / (1 - delay))
    }

    func eased(_ progress: CGFloat) -> CGFloat {
        1 - pow(1 - progress, 2.4)
    }

    func opacity(for progress: CGFloat) -> Double {
        guard progress > 0, progress < 1 else { return 0 }
        let appearance = min(1, progress * 8)
        return Double(appearance * (1 - progress))
    }

    static func makeParticles(count: Int) -> [Self] {
        (0..<count).map { index in
            let originX = CGFloat((index * 47) % 251) - 125
            let originY = CGFloat((index * 31) % 39) - 19
            let angle = (Double(index) * 2.399) + (Double((index * 17) % 13) * 0.07)
            let distance = CGFloat(48 + ((index * 43) % 92))
            let outwardX = originX * 0.48
            let outwardY = originY * 1.1
            let travel = CGSize(
                width: (CGFloat(cos(angle)) * distance) + outwardX,
                height: (CGFloat(sin(angle)) * distance * 0.7) + outwardY
            )

            return Self(
                id: index,
                origin: CGSize(width: originX, height: originY),
                travel: travel,
                diameter: CGFloat(2 + ((index * 11) % 5)),
                stretch: CGFloat(1 + Double((index * 7) % 16) / 10),
                rotation: Double((index * 29) % 180),
                spin: Double(70 + ((index * 19) % 220)),
                delay: CGFloat(Double((index * 23) % 19) / 100),
                inkOpacity: 0.48 + (Double((index * 13) % 43) / 100)
            )
        }
    }
}

#Preview {
    FavorecoSplashView(onFinished: {})
}
