import SwiftUI

struct OrganicParticleOrbView: View {
    let phase: CGFloat
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulse = false
    @State private var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState

    private static let fullParticles: [ParticleSeed] = makeParticles(count: 120)
    private static let reducedParticles: [ParticleSeed] = makeParticles(count: 40)

    private var effectiveParticles: [ParticleSeed] {
        if reduceMotion { return [] }
        if thermalState == .serious || thermalState == .critical {
            return Self.reducedParticles
        }
        return Self.fullParticles
    }

    private var animationPaused: Bool {
        reduceMotion || thermalState == .critical
    }

    var body: some View {
        let blobShape = OrganicBlobShape(phase: phase)

        return Group {
            if reduceMotion {
                staticOrb(blobShape: blobShape)
            } else {
                animatedOrb(blobShape: blobShape)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
        ) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
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
            .shadow(color: tint.opacity(0.14), radius: 8, y: 4)
    }

    @ViewBuilder
    private func animatedOrb(blobShape: OrganicBlobShape) -> some View {
        OrbParticleCanvas(
            tint: tint,
            particles: effectiveParticles,
            paused: animationPaused,
            frameRate: thermalState == .serious ? 12.0 : 24.0
        )
        .clipShape(OrganicBlobShape(phase: phase))
        .overlay(
            blobShape
                .stroke(tint.opacity(0.78), lineWidth: 1.4)
        )
        .overlay(
            blobShape
                .stroke(tint.opacity(glowPulse ? 0.5 : 0.15), lineWidth: 14)
                .blur(radius: 12)
                .blendMode(BlendMode.screen)
        )
        .shadow(color: tint.opacity(glowPulse ? 0.38 : 0.14), radius: glowPulse ? 20 : 8, y: 4)
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
            let radius = pow(h2, 0.62) * 0.47
            let x = 0.5 + cos(angle) * radius
            let y = 0.5 + sin(angle) * radius

            let size: CGFloat = h3 < 0.08 ? CGFloat(3.6 + h4 * 2.2) : CGFloat(0.9 + h4 * 1.6)
            let speed = 0.06 + h5 * 0.09
            let phase = h4 * .pi * 2
            let drift = 3.5 + h3 * 6.0
            let alpha = 0.34 + h2 * 0.62

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
                drawBackground(context: context, size: size)
                drawParticles(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let gradient = Gradient(colors: [
            Color(red: 0.02, green: 0.07, blue: 0.09),
            Color(red: 0.02, green: 0.11, blue: 0.13),
            tint.opacity(0.22)
        ])

        context.fill(
            Path(rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                startRadius: 10,
                endRadius: max(size.width, size.height) * 0.66
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
        let steps = 160

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
