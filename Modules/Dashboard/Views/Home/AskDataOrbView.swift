import SwiftUI

// MARK: - Cache Types

/// Pre-computed shell particle position and appearance for one frame.
private struct CachedParticle: Sendable {
    let x: CGFloat
    let y: CGFloat
    let alpha: Double
    let size: CGFloat
    let isCyan: Bool
}

/// Pre-computed geometry for a single animation frame — paths, scalars, positions.
private struct CachedFrame: Sendable {
    let breathe: Double
    let glowPulse: Double
    let pulse: Double

    let atmosphereClip: Path

    let mainRingPath: Path
    let secondRingPath: Path
    let hotA: CGPoint
    let hotB: CGPoint

    let driftX: Double
    let driftY: Double
    let outerBlob: Path
    let cavityBlob: Path
    let pocketBlob: Path
    let innerRing1: Path
    let innerRing2: Path
    let energyCenter: CGPoint

    let particles: [CachedParticle]
}

/// Holds the full pre-computed frame loop. Lookups are O(1) modular index.
private struct FrameCache: Sendable {
    let frames: [CachedFrame]
    let loopDuration: Double

    func frame(at t: Double) -> CachedFrame {
        // Ping-pong: play forward then backward so there is never a discontinuity.
        let cycle = loopDuration * 2
        let wrapped = t.truncatingRemainder(dividingBy: cycle)
        let safe = wrapped < 0 ? wrapped + cycle : wrapped
        let half = safe / loopDuration          // 0 → 2
        let mirror = half <= 1 ? half : 2 - half // 0→1→0 (seamless)
        let index = min(Int(mirror * Double(frames.count)), frames.count - 1)
        return frames[index]
    }
}

// MARK: - AskDataOrbView

/// Neon plasma orb. exact SwiftUI Canvas replica of the website's vitality orb.
/// All geometry is pre-computed on a background thread; per-frame rendering is path-free.
struct AskDataOrbView: View {
    let size: CGFloat
    @State private var thermalManager = ThermalManager.shared
    @State private var cache: FrameCache?
    @State private var isVisible = false

    /// 180 frames at 30 fps = 6 seconds of real-time animation before the loop wraps.
    private nonisolated static let cacheFrameCount = 180
    /// Duration of the loop in t-space (t = elapsed * 0.4, so 2.4 t ≈ 6 s real).
    private nonisolated static let cacheLoopDuration: Double = 2.4
    /// The only two tints across every shell particle, from the web original's neon
    /// palette (sRGB 0-255: 0,113,227 and 6,182,212). Held here so the draw loop can
    /// resolve them once per frame instead of per particle.
    private nonisolated static let shellTintBlue = Color(.sRGB, red: 0, green: 113 / 255, blue: 227 / 255, opacity: 1)
    private nonisolated static let shellTintCyan = Color(.sRGB, red: 6 / 255, green: 182 / 255, blue: 212 / 255, opacity: 1)

    init(size: CGFloat = 200) {
        self.size = size
    }

    var body: some View {
        Group {
            if thermalManager.shouldThrottle {
                staticOrb
            } else if let cache {
                // This screen stays alive under anything pushed or presented over it,
                // so an unpaused tick keeps rendering an orb nobody can see.
                TimelineView(.animation(minimumInterval: frameInterval, paused: !isVisible)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate * 0.4
                    Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { ctx, canvasSize in
                        renderCached(ctx: ctx, size: canvasSize, time: t, cache: cache)
                    }
                }
            } else {
                staticOrb
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: size) {
            cache = await Self.buildCache(size: size)
        }
    }

    private var frameInterval: TimeInterval {
        switch thermalManager.currentState {
        case .nominal:
            return 1.0 / 30.0
        case .fair:
            return 1.0 / 20.0
        case .serious, .critical:
            return 1.0 / 8.0
        @unknown default:
            return 1.0 / 20.0
        }
    }

    // MARK: - Static Fallback

    private var staticOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.sRGB, red: 0.06, green: 0.35, blue: 0.74, opacity: 0.36),
                            Color(.sRGB, red: 0.04, green: 0.12, blue: 0.32, opacity: 0.18),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.72
                    )
                )
                .blur(radius: size * 0.06)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color(.sRGB, red: 0.02, green: 0.44, blue: 0.89, opacity: 0.9),
                            Color(.sRGB, red: 0.02, green: 0.71, blue: 0.83, opacity: 0.85),
                            Color.white.opacity(0.9),
                        ],
                        center: .center
                    ),
                    lineWidth: size * 0.02
                )
                .frame(width: size * 0.62, height: size * 0.62)
                .blur(radius: size * 0.01)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.sRGB, red: 0.02, green: 0.09, blue: 0.24, opacity: 0.9),
                            Color(.sRGB, red: 0.01, green: 0.05, blue: 0.16, opacity: 0.98),
                        ],
                        center: UnitPoint(x: 0.42, y: 0.38),
                        startRadius: 0,
                        endRadius: size * 0.28
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)

            Circle()
                .fill(Color(.sRGB, red: 0.56, green: 0.94, blue: 1.0, opacity: 0.16))
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: -size * 0.1, y: -size * 0.08)
                .blur(radius: size * 0.03)
        }
        .compositingGroup()
    }

    // MARK: - Cached Rendering

    private func renderCached(ctx: GraphicsContext, size: CGSize, time t: Double, cache: FrameCache) {
        let frame = cache.frame(at: t)
        let W = size.width, H = size.height
        let cx = W / 2, cy = H / 2
        let R = min(W, H) * 0.314

        var main = ctx
        main.translateBy(x: cx, y: cy)
        main.scaleBy(x: frame.breathe, y: frame.breathe)
        main.translateBy(x: -cx, y: -cy)

        // Layer 1: Atmosphere (pulsed opacity)
        var atmo = main
        atmo.opacity = frame.glowPulse
        drawAtmosphereCached(&atmo, cx: cx, cy: cy, R: R, frame: frame)

        // Layer 2: Outer Shell
        drawOuterShellCached(&main, frame: frame)

        // Layer 3: Rings
        drawRingsCached(&main, cx: cx, cy: cy, R: R, frame: frame)

        // Layer 4: Inner Void
        drawInnerVoidCached(&main, cx: cx, cy: cy, R: R, frame: frame)
    }

    // MARK: - Layer 1: Atmosphere

    private func drawAtmosphereCached(_ ctx: inout GraphicsContext, cx: Double, cy: Double, R: Double, frame: CachedFrame) {
        let center = CGPoint(x: cx, y: cy)

        // Outer halo
        let haloPath = Path(ellipseIn: CGRect(x: cx - R * 1.6, y: cy - R * 1.6, width: R * 3.2, height: R * 3.2))
        ctx.fill(haloPath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(6, 182, 212, 0.2), location: 0),
                .init(color: rgba(0, 113, 227, 0.18), location: 0.55),
                .init(color: rgba(3, 14, 44, 0), location: 1),
            ]),
            center: center, startRadius: R * 0.2, endRadius: R * 1.58
        ))

        // Clipped body
        var clipped = ctx
        clipped.clip(to: frame.atmosphereClip)

        let bodyRect = CGRect(x: cx - R * 1.26, y: cy - R * 1.26, width: R * 2.52, height: R * 2.52)
        clipped.fill(Path(bodyRect), with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(7, 31, 74, 0.08), location: 0),
                .init(color: rgba(5, 26, 74, 0.24), location: 0.4),
                .init(color: rgba(2, 18, 58, 0.86), location: 1),
            ]),
            center: CGPoint(x: cx - R * 0.2, y: cy - R * 0.21), startRadius: R * 0.05, endRadius: R * 1.05
        ))

        // Hotspots (additive + blur)
        var hotCtx = clipped
        hotCtx.blendMode = .plusLighter
        hotCtx.addFilter(.blur(radius: R * 0.1))

        let hotCenter = CGPoint(x: cx - R * 0.28, y: cy - R * 0.17)
        let hotPath = Path(ellipseIn: CGRect(x: hotCenter.x - R * 0.66, y: hotCenter.y - R * 0.66, width: R * 1.32, height: R * 1.32))
        hotCtx.fill(hotPath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(140, 240, 255, 0.18), location: 0),
                .init(color: rgba(6, 182, 212, 0.09), location: 0.32),
                .init(color: rgba(6, 182, 212, 0), location: 1),
            ]),
            center: hotCenter, startRadius: 0, endRadius: R * 0.66
        ))

        let rimCenter = CGPoint(x: cx + R * 0.16, y: cy + R * 0.32)
        let rimPath = Path(ellipseIn: CGRect(x: rimCenter.x - R * 0.76, y: rimCenter.y - R * 0.76, width: R * 1.52, height: R * 1.52))
        hotCtx.fill(rimPath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(34, 197, 255, 0.1), location: 0),
                .init(color: rgba(34, 197, 255, 0), location: 1),
            ]),
            center: rimCenter, startRadius: 0, endRadius: R * 0.76
        ))

        let coreCenter = CGPoint(x: cx - R * 0.03, y: cy + R * 0.02)
        let corePath = Path(ellipseIn: CGRect(x: coreCenter.x - R * 0.55, y: coreCenter.y - R * 0.55, width: R * 1.1, height: R * 1.1))
        hotCtx.fill(corePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(0, 113, 227, 0.07), location: 0),
                .init(color: rgba(0, 113, 227, 0), location: 1),
            ]),
            center: coreCenter, startRadius: 0, endRadius: R * 0.55
        ))

        // Center void
        let voidPath = Path(ellipseIn: CGRect(x: cx - R * 0.72, y: cy - R * 0.72, width: R * 1.44, height: R * 1.44))
        clipped.fill(voidPath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(2, 16, 50, 0.78), location: 0),
                .init(color: rgba(2, 16, 50, 0.38), location: 0.58),
                .init(color: rgba(2, 16, 50, 0), location: 1),
            ]),
            center: center, startRadius: 0, endRadius: R * 0.72
        ))
    }

    // MARK: - Layer 2: Outer Shell

    private func drawOuterShellCached(_ ctx: inout GraphicsContext, frame: CachedFrame) {
        var shell = ctx
        shell.blendMode = .plusLighter

        // 1,920 particles share two tints and differ only in alpha, so both shadings
        // are resolved once rather than building a Color per fill. plusLighter works
        // on a premultiplied source, so carrying the alpha on the context lands on
        // the same pixels as baking it into the color.
        let blue = shell.resolve(.color(Self.shellTintBlue))
        let cyan = shell.resolve(.color(Self.shellTintCyan))

        for p in frame.particles {
            let rect = Path(CGRect(x: p.x - p.size / 2, y: p.y - p.size / 2, width: p.size, height: p.size))
            shell.opacity = p.alpha
            shell.fill(rect, with: p.isCyan ? cyan : blue)
        }
    }

    // MARK: - Layer 3: Rings

    private func drawRingsCached(_ ctx: inout GraphicsContext, cx: Double, cy: Double, R: Double, frame: CachedFrame) {
        let pulse = frame.pulse

        // Single combined glow
        var glow = ctx
        glow.addFilter(.blur(radius: R * 0.09))
        glow.stroke(frame.mainRingPath, with: .color(rgba(3, 148, 220, 0.2 * pulse)), lineWidth: R * 0.15)

        // Main ring (gradient stroke)
        var mainRing = ctx
        mainRing.opacity = 0.9
        mainRing.stroke(frame.mainRingPath, with: .linearGradient(
            Gradient(stops: [
                .init(color: rgba(255, 255, 255, 0.97 * pulse), location: 0),
                .init(color: rgba(254, 254, 255, 0.96 * pulse), location: 0.3),
                .init(color: rgba(251, 253, 255, 0.94 * pulse), location: 0.66),
                .init(color: rgba(247, 251, 255, 0.93 * pulse), location: 1),
            ]),
            startPoint: CGPoint(x: cx - R, y: cy - R * 0.85),
            endPoint: CGPoint(x: cx + R, y: cy + R)
        ), lineWidth: R * 0.0155)

        // Second ring (blur layer)
        var blur7 = ctx
        blur7.addFilter(.blur(radius: R * 0.032))
        blur7.stroke(frame.secondRingPath, with: .linearGradient(
            Gradient(stops: [
                .init(color: rgba(0, 113, 227, 0.42 * pulse), location: 0),
                .init(color: rgba(6, 182, 212, 0.38 * pulse), location: 0.45),
                .init(color: rgba(52, 211, 153, 0.28 * pulse), location: 1),
            ]),
            startPoint: CGPoint(x: cx - R * 1.15, y: cy + R * 0.6),
            endPoint: CGPoint(x: cx + R * 1.15, y: cy - R * 0.7)
        ), lineWidth: R * 0.04)

        // Second ring core
        ctx.stroke(frame.secondRingPath, with: .linearGradient(
            Gradient(stops: [
                .init(color: rgba(255, 255, 255, 0.52 * pulse), location: 0),
                .init(color: rgba(6, 182, 212, 0.52 * pulse), location: 0.45),
                .init(color: rgba(52, 211, 153, 0.44 * pulse), location: 1),
            ]),
            startPoint: CGPoint(x: cx - R * 1.15, y: cy + R * 0.6),
            endPoint: CGPoint(x: cx + R * 1.15, y: cy - R * 0.7)
        ), lineWidth: R * 0.0105)

        // Traveling hotspots
        var hotGlow = ctx
        hotGlow.addFilter(.blur(radius: R * 0.068))

        let h1 = frame.hotA, h2 = frame.hotB

        let g1Path = Path(ellipseIn: CGRect(x: h1.x - R * 0.26, y: h1.y - R * 0.26, width: R * 0.52, height: R * 0.52))
        hotGlow.fill(g1Path, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(255, 255, 255, 0.48), location: 0),
                .init(color: rgba(6, 182, 212, 0.2), location: 0.35),
                .init(color: .clear, location: 1),
            ]),
            center: h1, startRadius: 0, endRadius: R * 0.26
        ))

        let g2Path = Path(ellipseIn: CGRect(x: h2.x - R * 0.2, y: h2.y - R * 0.2, width: R * 0.4, height: R * 0.4))
        hotGlow.fill(g2Path, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(52, 211, 153, 0.36), location: 0),
                .init(color: .clear, location: 1),
            ]),
            center: h2, startRadius: 0, endRadius: R * 0.2
        ))
    }

    // MARK: - Layer 4: Inner Void

    private func drawInnerVoidCached(_ ctx: inout GraphicsContext, cx: Double, cy: Double, R: Double, frame: CachedFrame) {
        let driftX = frame.driftX, driftY = frame.driftY

        // Dark outer blob
        let outerCenter = CGPoint(x: cx - R * 0.12 + driftX, y: cy + R * 0.06 + driftY)
        ctx.fill(frame.outerBlob, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(2, 16, 50, 0.68), location: 0),
                .init(color: rgba(2, 16, 50, 0.34), location: 0.58),
                .init(color: rgba(2, 16, 50, 0), location: 1),
            ]),
            center: outerCenter, startRadius: R * 0.08, endRadius: R * 0.92
        ))

        // Cavity blob
        let cavityCenter = CGPoint(x: cx + R * 0.03 - driftX * 0.6, y: cy - R * 0.05 - driftY * 0.3)
        ctx.fill(frame.cavityBlob, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(2, 16, 50, 0.56), location: 0),
                .init(color: rgba(2, 16, 50, 0), location: 1),
            ]),
            center: cavityCenter, startRadius: 0, endRadius: R * 0.66
        ))

        // Pocket blob
        let pocketCenter = CGPoint(x: cx + R * 0.08, y: cy - R * 0.08)
        ctx.fill(frame.pocketBlob, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(2, 16, 50, 0.44), location: 0),
                .init(color: rgba(2, 16, 50, 0), location: 1),
            ]),
            center: pocketCenter, startRadius: 0, endRadius: R * 0.45
        ))

        // Additive inner ring strokes
        var glowInner = ctx
        glowInner.blendMode = .plusLighter
        glowInner.addFilter(.blur(radius: R * 0.045))

        glowInner.stroke(frame.innerRing1, with: .color(rgba(6, 182, 212, 0.1)), lineWidth: R * 0.038)
        glowInner.stroke(frame.innerRing2, with: .color(rgba(0, 113, 227, 0.08)), lineWidth: R * 0.03)

        // Energy glow
        var energyCtx = ctx
        energyCtx.blendMode = .plusLighter
        energyCtx.addFilter(.blur(radius: R * 0.073))
        let eCenter = frame.energyCenter
        let ePath = Path(ellipseIn: CGRect(x: eCenter.x - R * 0.3, y: eCenter.y - R * 0.3, width: R * 0.6, height: R * 0.6))
        energyCtx.fill(ePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: rgba(6, 182, 212, 0.08), location: 0),
                .init(color: rgba(6, 182, 212, 0), location: 1),
            ]),
            center: eCenter, startRadius: 0, endRadius: R * 0.3
        ))
    }

    // MARK: - Color Helper

    private func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    // MARK: - Cache Generation

    private nonisolated static func buildCache(size: CGFloat) async -> FrameCache {
        await Task.detached(priority: .userInitiated) {
            let s = Double(size)
            let cx = s / 2, cy = s / 2
            let R = s * 0.314
            let dt = cacheLoopDuration / Double(cacheFrameCount)

            var frames: [CachedFrame] = []
            frames.reserveCapacity(cacheFrameCount)

            for i in 0..<cacheFrameCount {
                let t = Double(i) * dt
                frames.append(computeFrame(t: t, cx: cx, cy: cy, R: R))
            }

            return FrameCache(frames: frames, loopDuration: cacheLoopDuration)
        }.value
    }

    private nonisolated static func computeFrame(t: Double, cx: Double, cy: Double, R: Double) -> CachedFrame {
        let driftX = sin(t * 0.63) * R * 0.032
        let driftY = cos(t * 0.47) * R * 0.026

        return CachedFrame(
            breathe: 1 + 0.018 * sin(t * 0.9),
            glowPulse: 0.7 + 0.3 * sin(t * 1.1),
            pulse: 0.92 + 0.08 * sin(t * 1.25),
            atmosphereClip: traceLoop(cx: cx, cy: cy, radius: R * 0.968, t: t * 0.31, wobble: R * 0.02, drift: 1.3, detail: 150, rippleScale: 0.1),
            mainRingPath: traceLoop(cx: cx, cy: cy, radius: R * 0.982, t: t * 0.52, wobble: R * 0.008, drift: 0.2, detail: 180, rippleScale: 0.08),
            secondRingPath: traceLoop(cx: cx, cy: cy, radius: R * 1.016, t: -t * 0.64, wobble: R * 0.049, drift: 2.1, detail: 200, rippleScale: 0.38),
            hotA: CGPoint(x: cx + cos(t * 0.42 + 2.24) * R * 0.985, y: cy + sin(t * 0.42 + 2.24) * R * 0.985),
            hotB: CGPoint(x: cx + cos(t * 0.42 + 5.14) * R * 0.985, y: cy + sin(t * 0.42 + 5.14) * R * 0.985),
            driftX: driftX,
            driftY: driftY,
            outerBlob: traceBlob(cx: cx, cy: cy, baseR: R * 0.79, wobble: R * 0.078, drift: 0.9, ripple: 0.72, squashX: 0.14, squashY: -0.12, offsetX: driftX, offsetY: driftY, t: t, detail: 160),
            cavityBlob: traceBlob(cx: cx, cy: cy, baseR: R * 0.56, wobble: R * 0.062, drift: 2.4, ripple: 0.78, squashX: -0.16, squashY: 0.12, offsetX: -driftX * 0.8, offsetY: -driftY * 0.6, t: t, detail: 140),
            pocketBlob: traceBlob(cx: cx, cy: cy, baseR: R * 0.37, wobble: R * 0.048, drift: 4.1, ripple: 0.82, squashX: 0.2, squashY: -0.18, offsetX: R * 0.06, offsetY: -R * 0.03, t: t, detail: 120),
            innerRing1: traceBlob(cx: cx, cy: cy, baseR: R * 0.62, wobble: R * 0.022, drift: 1.2, ripple: 0.5, squashX: 0.08, squashY: -0.05, offsetX: driftX * 0.3, offsetY: driftY * 0.3, t: t, detail: 130),
            innerRing2: traceBlob(cx: cx, cy: cy, baseR: R * 0.46, wobble: R * 0.02, drift: 3.1, ripple: 0.55, squashX: -0.09, squashY: 0.07, offsetX: -R * 0.05, offsetY: R * 0.03, t: t, detail: 130),
            energyCenter: CGPoint(x: cx - R * 0.15 + driftX * 0.5, y: cy - R * 0.11 + driftY * 0.4),
            particles: computeShellParticles(cx: cx, cy: cy, R: R, t: t)
        )
    }

    private nonisolated static func computeShellParticles(cx: Double, cy: Double, R: Double, t: Double) -> [CachedParticle] {
        let TAU = Double.pi * 2

        struct ShellConfig {
            let base: Double, spread: Double, ribs: Int, points: Int
            let offset: Double, alpha: Double, size: Double, speed: Double, spin: Double
            let isCyan: Bool
        }

        let shells: [ShellConfig] = [
            ShellConfig(base: R * 1.35, spread: R * 0.08, ribs: 12, points: 100, offset: 0, alpha: 0.74, size: 2.2, speed: 1.35, spin: 0.42, isCyan: false),
            ShellConfig(base: R * 1.3, spread: R * 0.064, ribs: 8, points: 90, offset: 1.34, alpha: 0.56, size: 1.7, speed: 0.95, spin: -0.24, isCyan: true),
        ]

        func outerRadius(a: Double, phase: Double, base: Double, spread: Double) -> Double {
            let slow = sin(a * 2.04 + phase) * spread
            let mid = sin(a * 3.66 - phase * 1.24) * spread * 0.56
            let carrier = sin(a * 9.4 + phase * 2.3 + slow / max(spread, 0.0001) * 0.6)
            let nested = sin(a * 18.4 - phase * 3.1 + carrier * 2.7) * spread * 0.18
            let envelope = 0.5 + 0.5 * pow(abs(sin(a * 1.08 - phase * 0.46)), 0.84)
            return base + slow + mid + (carrier * spread * 0.3 + nested) * envelope
        }

        var particles: [CachedParticle] = []
        particles.reserveCapacity(1920)

        for s in shells {
            for rib in 0..<s.ribs {
                let ribNorm = s.ribs <= 1 ? 0.5 : Double(rib) / Double(s.ribs - 1)
                let ribCenter = 1 - pow(abs(ribNorm - 0.5) * 2, 1.45)
                let ribPhase = t * s.speed + Double(rib) * 0.165 + s.offset
                let ribRadiusShift = (ribNorm - 0.5) * R * 0.02

                for i in 0..<s.points {
                    let p = Double(i) / Double(s.points)
                    let a = p * TAU + t * s.spin + Double(rib) * 0.006
                    let rr = outerRadius(a: a, phase: ribPhase, base: s.base + ribRadiusShift, spread: s.spread)
                    let x = cx + cos(a) * rr
                    let y = cy + sin(a) * rr
                    let lobe = pow(abs(sin(a * 1.14 - t * 0.76 + s.offset * 0.5)), 1.48)
                    let shimmer = 0.72 + 0.28 * sin(a * 7.2 + t * 3.35 + Double(rib) * 0.11)
                    let travel = 0.7 + 0.3 * sin(a * 2.1 - t * 2.4 + s.offset)
                    let alpha = (0.18 + s.alpha * ribCenter * (0.54 + 0.46 * lobe)) * shimmer * travel
                    let sz = s.size * (0.74 + ribCenter * 0.66)

                    particles.append(CachedParticle(
                        x: CGFloat(x), y: CGFloat(y),
                        alpha: alpha, size: CGFloat(sz),
                        isCyan: s.isCyan
                    ))
                }
            }
        }

        return particles
    }

    // MARK: - Core Math (exact port — used only during cache generation)

    private nonisolated static func loopDisplacement(a: Double, t: Double, wobble: Double, drift: Double, rippleScale: Double) -> Double {
        let safeWobble = max(wobble, 0.0001)
        let macro = sin(a * 2.08 + t * 0.86 + drift) * wobble
            + sin(a * 3.46 - t * 0.64 - drift * 0.48) * wobble * 0.52
            + cos(a * 5.52 + t * 0.36 - drift * 0.25) * wobble * 0.24
        let macroNorm = macro / safeWobble
        let carrier = sin(a * 8.7 - t * 1.2 + drift * 1.3 + macroNorm * 0.95)
        let nested = sin(a * 17.8 + t * 1.92 + carrier * 2.4 - drift * 0.7)
        let envelope = 0.54 + 0.46 * pow(abs(sin(a * 1.12 - t * 0.34 + drift * 0.45)), 0.82)
        return macro + (carrier * wobble * rippleScale + nested * wobble * rippleScale * 0.46) * envelope
    }

    private nonisolated static func traceLoop(cx: Double, cy: Double, radius: Double, t: Double, wobble: Double, drift: Double, detail: Int, rippleScale: Double = 0.2) -> Path {
        let TAU = Double.pi * 2
        var path = Path()
        for i in 0...detail {
            let p = Double(i) / Double(detail)
            let a = p * TAU
            let d = loopDisplacement(a: a, t: t, wobble: wobble, drift: drift, rippleScale: rippleScale)
            let rr = radius + d
            let pt = CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private nonisolated static func traceBlob(cx: Double, cy: Double, baseR: Double, wobble: Double, drift: Double, ripple: Double, squashX: Double, squashY: Double, offsetX: Double, offsetY: Double, t: Double, detail: Int = 130) -> Path {
        let TAU = Double.pi * 2
        var path = Path()
        for i in 0...detail {
            let p = Double(i) / Double(detail)
            let a = p * TAU
            let disp = loopDisplacement(a: a, t: t * 0.88, wobble: wobble, drift: drift, rippleScale: ripple)
            let rr = baseR + disp
            let sx = 1 + squashX * sin(a * 1.35 - t * 0.37 + drift)
            let sy = 1 + squashY * cos(a * 1.72 + t * 0.42 - drift * 0.5)
            let pt = CGPoint(
                x: cx + offsetX + cos(a) * rr * sx,
                y: cy + offsetY + sin(a) * rr * sy
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
