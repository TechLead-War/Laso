import SwiftUI

struct OrganicParticleOrbView: View {
    let phase: CGFloat
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulse = false
    @State private var thermalManager = ThermalManager.shared

    private static let fullParticles: [ParticleSeed] = makeParticles(count: 160)
    private static let reducedParticles: [ParticleSeed] = makeParticles(count: 80)

    private var effectiveParticles: [ParticleSeed] {
        if reduceMotion { return [] }
        if thermalManager.shouldReduceVisualEffects {
            return Self.reducedParticles
        }
        return Self.fullParticles
    }

    private var animationPaused: Bool {
        reduceMotion || thermalManager.shouldThrottle
    }

    var body: some View {
        let blobShape = OrganicBlobShape(phase: phase)

        return Group {
            if reduceMotion || thermalManager.shouldThrottle {
                staticOrb(blobShape: blobShape)
            } else {
                animatedOrb(blobShape: blobShape)
            }
        }
    }

    @ViewBuilder
    private func staticOrb(blobShape: OrganicBlobShape) -> some View {
        blobShape
            .fill(tint.opacity(0.22))
            .overlay(
                blobShape
                    .stroke(tint.opacity(0.78), lineWidth: 1.4)
            )
            .overlay(
                blobShape
                    .stroke(tint.opacity(0.45), lineWidth: 14)
                    .blur(radius: 12)
                    .blendMode(BlendMode.screen)
            )
            .shadow(color: tint.opacity(0.38), radius: 18, y: 4)
    }

    @ViewBuilder
    private func animatedOrb(blobShape: OrganicBlobShape) -> some View {
        OrbParticleCanvas(
            tint: tint,
            particles: effectiveParticles,
            paused: animationPaused,
            frameRate: thermalManager.maxFrameRate
        )
        .overlay(
            blobShape
                .stroke(tint.opacity(0.22), lineWidth: 1.0)
        )
        .overlay(
            blobShape
                .stroke(tint.opacity(glowPulse ? 0.65 : 0.38), lineWidth: 16)
                .blur(radius: 14)
                .blendMode(BlendMode.screen)
        )
        .shadow(color: tint.opacity(glowPulse ? 0.5 : 0.3), radius: glowPulse ? 24 : 16, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private static func makeParticles(count: Int) -> [ParticleSeed] {
        (0..<count).map { i in
            let index = Double(i)
            let h1 = vfract(sin(index * 127.1 + 14.7) * 43758.5453)
            let h2 = vfract(sin(index * 269.5 + 41.3) * 43758.5453)
            let h3 = vfract(sin(index * 419.2 + 29.9) * 43758.5453)
            let h4 = vfract(sin(index * 631.3 + 91.1) * 43758.5453)
            let h5 = vfract(sin(index * 853.7 + 57.2) * 43758.5453)

            let angle = h1 * .pi * 2
            // Ring distribution: density peaks near the outer edge, thins toward center.
            // abs(sin(h2 * .pi)) peaks at h2 = 0.5, giving a soft gaussian-like ring.
            let ringness = abs(sin(h2 * .pi))
            let radius = 0.22 + ringness * 0.28
            let x = 0.5 + cos(angle) * radius
            let y = 0.5 + sin(angle) * radius

            let size: CGFloat = h3 < 0.10 ? CGFloat(3.2 + h4 * 2.6) : CGFloat(0.7 + h4 * 1.5)
            let speed = 0.06 + h5 * 0.10
            let phase = h4 * .pi * 2
            let drift = 3.0 + h3 * 5.5
            let alpha = 0.38 + ringness * 0.52

            return ParticleSeed(
                x: CGFloat(x),
                y: CGFloat(y),
                size: size,
                speed: speed,
                phase: phase,
                drift: drift,
                tintMix: h1,
                alpha: alpha
            )
        }
    }
}

private struct OrbParticleCanvas: View {
    let tint: Color
    let particles: [ParticleSeed]
    let paused: Bool
    let frameRate: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / frameRate, paused: paused)) { timeline in
            Canvas { context, size in
                drawDarkCore(context: context, size: size)
                drawParticles(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    /// Subtle dark orb body behind the particles. Keeps the center near black like the Whoop reference
    /// while letting the parent card tint bleed through at the edges.
    private func drawDarkCore(context: GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) * 0.5
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let path = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        let gradient = Gradient(stops: [
            .init(color: Color.black.opacity(0.62), location: 0),
            .init(color: Color.black.opacity(0.42), location: 0.72),
            .init(color: Color.black.opacity(0.0), location: 1.0),
        ])
        context.fill(
            path,
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for particle in particles {
            let x = size.width * particle.x
                + CGFloat(cos(time * particle.speed + particle.phase) * particle.drift)
            let y = size.height * particle.y
                + CGFloat(sin(time * particle.speed * 0.82 + particle.phase) * particle.drift)

            let dotRect = CGRect(
                x: x - particle.size / 2,
                y: y - particle.size / 2,
                width: particle.size,
                height: particle.size
            )

            let color: Color = particle.tintMix < 0.44
                ? tint.opacity(particle.alpha)
                : Color.white.opacity(particle.alpha)

            context.fill(Path(ellipseIn: dotRect), with: .color(color))

            if particle.size > 3.0 {
                let glow = particle.size * 2.6
                let glowRect = CGRect(
                    x: x - glow / 2,
                    y: y - glow / 2,
                    width: glow,
                    height: glow
                )
                context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.12)))
            }
        }
    }
}

struct ParticleSeed {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: Double
    let phase: Double
    let drift: Double
    let tintMix: Double
    let alpha: Double
}

private struct OrganicBlobShape: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.43
        let steps = 80

        var path = Path()
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps) * .pi * 2
            let wobbleA = 0.0675 * sin(t * 3 + phase)
            let wobbleB = 0.0405 * sin(t * 5 + phase * 1.7)
            let wobbleC = 0.027 * cos(t * 2 - phase * 0.9)
            let radius = baseRadius * (1 + wobbleA + wobbleB + wobbleC)

            let point = CGPoint(
                x: center.x + cos(t) * radius,
                y: center.y + sin(t) * radius
            )

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

func vfract(_ value: Double) -> Double {
    value - value.rounded(.down)
}
