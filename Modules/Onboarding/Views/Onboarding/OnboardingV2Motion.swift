import SwiftUI

// MARK: - Shared motion system (consumed by every OnbV2 screen stage)
//
// Two primitives live here:
//   P1  .onbV2StaggerIn  — per-element entrance reveal a screen owns itself.
//   P2  RevealPhase + .onbV2RevealClock — a phase clock that gates data-story
//        screens (chart -> number -> body -> cta) so each beat lands in order.
//
// Both collapse to a single ~150ms crossfade under Reduce Motion and show
// final values instantly. They never scale from 0 or use a large offset, which
// reads as a jarring "fly-in" rather than the intended settle.

// MARK: - P1 Staggered reveal

/// Per-element entrance: opacity 0->1 and a small upward settle, delayed by
/// `index` so a column of items cascades. Drive `appeared` from the screen
/// (one `@State` flipped true in `.task`/`.onAppear`) so the whole group shares
/// one trigger. Set `tight` on dense blocks (chips, stat rows) for an 8px throw.
///
/// Reduce Motion: a single ~150ms crossfade with no offset and no per-index
/// delay, so assistive users see everything appear together, instantly settled.
struct OnbV2StaggerIn: ViewModifier {
    let index: Int
    let appeared: Bool
    let tight: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (reduceMotion ? 0 : (tight ? 8 : 10)))
            .animation(animation, value: appeared)
    }

    private var animation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.15)
        }
        // staggeredEntry already bakes the entryEase curve; just add the cascade delay.
        return OnbV2.staggeredEntry(Double(index) * 0.045)
    }
}

extension View {
    /// P1 staggered entrance. `index` sets the cascade slot, `appeared` is the
    /// shared trigger. `tight: true` shrinks the upward throw for dense blocks.
    func onbV2StaggerIn(index: Int, appeared: Bool, tight: Bool = false) -> some View {
        modifier(OnbV2StaggerIn(index: index, appeared: appeared, tight: tight))
    }
}

// MARK: - P2 Reveal-phase clock

/// Ordered beats of a data-story screen. A screen reads the current phase and
/// shows each layer (chart, then the headline number, then supporting body,
/// then the CTA) as the clock advances, so the reveal feels authored, not
/// dumped all at once. `.hidden` is the pre-roll before the first beat.
enum RevealPhase: Int, Comparable {
    case hidden, chart, number, body, cta

    static func < (lhs: RevealPhase, rhs: RevealPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// True once the clock has reached `phase`, so call sites can write
    /// `if phase.hasReached(.number)` instead of comparing raw values.
    func hasReached(_ phase: RevealPhase) -> Bool { self >= phase }
}

/// Drives a `RevealPhase` binding through its beats on a `.task`, which cancels
/// automatically when the router swaps screens (unlike `.onAppear`, whose work
/// would leak past the swap). `staggeredBars` lengthens the chart beat so a
/// bar-by-bar draw finishes before the number lands.
///
/// Reduce Motion: jump straight to `.cta` (the final phase) with no sleeps, so
/// the full screen is present instantly.
struct OnbV2RevealClock: ViewModifier {
    @Binding var phase: RevealPhase
    let staggeredBars: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.task {
            if reduceMotion {
                phase = .cta
                return
            }
            phase = .chart
            // Single-draw chart finishes in 700ms; a staggered bar draw needs longer.
            try? await Task.sleep(for: .milliseconds(staggeredBars ? 1350 : 700))
            guard !Task.isCancelled else { return }
            phase = .number
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            phase = .body
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            phase = .cta
        }
    }
}

extension View {
    /// P2 reveal clock. Bind a `RevealPhase` `@State`; it advances chart ->
    /// number -> body -> cta on a cancel-safe `.task`. Pass `staggeredBars: true`
    /// when the chart draws bar by bar so the number waits for it to finish.
    func onbV2RevealClock(_ phase: Binding<RevealPhase>, staggeredBars: Bool = false) -> some View {
        modifier(OnbV2RevealClock(phase: phase, staggeredBars: staggeredBars))
    }
}
