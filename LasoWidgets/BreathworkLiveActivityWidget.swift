import ActivityKit
import SwiftUI
import WidgetKit

struct BreathworkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathworkActivityAttributes.self) { context in
            BreathworkLiveActivityView(context: context)
                // Fixed dark chrome — the activity is tuned for dark surfaces and
                // must not flip to white in light mode behind the lock screen, so
                // the canvas and every foreground on it use fixed-polarity tokens.
                .activityBackgroundTint(AppColour.liveActivityCanvas)
                .activitySystemActionForegroundColor(AppColour.textOnInverse)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BreathworkModePill(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BreathworkStamp(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BreathworkExpandedBody(context: context)
                        .widgetURL(Self.stressMonitorURL)
                }
            } compactLeading: {
                Image(systemName: context.state.activePhase.symbolName)
                    .foregroundStyle(AppColour.accent)
                    .accessibilityLabel(context.state.activePhase.accessibilityLabel)
                    .widgetURL(Self.stressMonitorURL)
            } compactTrailing: {
                CompactTimerText(context: context)
                    .accessibilityLabel(BreathworkCopy.timerAccessibilityLabel)
                    .widgetURL(Self.stressMonitorURL)
            } minimal: {
                ZStack {
                    Circle().fill(AppColour.accent.opacity(0.22))
                    Circle().stroke(AppColour.accent, lineWidth: 1.2)
                    Image(systemName: context.state.protocolType.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColour.accent)
                }
                .accessibilityLabel(context.state.protocolType.title)
            }
        }
    }

    /// Deep link target for the breathwork surface. `onOpenURL` (added by D3)
    /// maps this via `Route.fromUITestIdentifier` to `Route.stressMonitor`.
    private static let stressMonitorURL = URL(string: "laso://route/stressMonitor")
}

// MARK: - Dynamic Island: Expanded leading (mode pill)

/// Tinted capsule mirroring the HTML `modepill`: accent glyph + headline title.
/// Background is the accent at low opacity so it reads as branded but restrained.
private struct BreathworkModePill: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        // Fixed point sizes: the expanded island ignores `.dynamicTypeSize` and is
        // capped at 160 pt, so a scaling leading pill grows the head row and pushes
        // the bottom content past the cap. Pinning holds the height.
        HStack(spacing: 6) {
            Image(systemName: context.state.protocolType.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColour.accent)
            Text(context.attributes.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColour.textOnInverse)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppColour.accent.opacity(0.18), in: Capsule())
    }
}

// MARK: - Dynamic Island: Expanded trailing (stamp)

/// Small tertiary label naming the active protocol, matching the HTML `stamp`.
private struct BreathworkStamp: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        Text(context.state.protocolType.subtitle)
            .font(.system(size: 12))
            .foregroundStyle(AppColour.textOnInverseSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Dynamic Island: Expanded bottom (orb + phase + meta)

/// Centred breathing column from the HTML `breath-body`: the static orb, the
/// current phase label, and a session meta line (subtitle + remaining time).
private struct BreathworkExpandedBody: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        // Fixed point sizes (not Dynamic Type styles): the expanded island is capped
        // at 160 pt and ignores `.dynamicTypeSize`, so scaling fonts would push the
        // meta line past the cap and the system would clip it. Fixed sizes hold height.
        VStack(spacing: 8) {
            BreathingOrb(size: 56)

            Text(context.state.activePhase.label)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColour.textOnInverse)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            BreathworkMetaLine(context: context)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.state.activePhase.accessibilityLabel)
    }
}

/// HTML `breath-meta`: protocol subtitle plus the live remaining countdown.
/// Active sessions stream the countdown via `Text(timerInterval:)`; paused /
/// completed states show a static string so nothing claims to be ticking.
private struct BreathworkMetaLine: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Text(context.state.protocolType.subtitle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            switch context.state.status {
            case .active:
                Text(BreathworkCopy.remaining)
                Text(timerInterval: WidgetStyle.timerRange(to: context.state.sessionEndDate), countsDown: true)
                    .monospacedDigit()
                    .frame(minWidth: 36, alignment: .leading)
            case .paused:
                Text(BreathworkCopy.statusPaused)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            case .completed:
                Text(BreathworkCopy.statusComplete)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(AppColour.textOnInverseSecondary)
    }
}

// MARK: - Breathing Orb (static)

/// Static stand-in for the HTML breathing `orb`. A Live Activity cannot run the
/// scale keyframe, so the orb is rendered as concentric circles over a soft
/// accent RadialGradient bloom — the same filter-free glow technique the ring
/// glow uses (a radial gradient on a circular frame reads as a circular bloom,
/// never a box; `.blur`/`.shadow` would not render here).
private struct BreathingOrb: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColour.accent.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
            Circle()
                .stroke(AppColour.accent.opacity(0.5), lineWidth: 2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Lock Screen content

private struct BreathworkLiveActivityView: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let phase = phase(at: timeline.date)
            HStack(spacing: 12) {
                LockScreenBreathingOrb(phase: phase, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.protocolType.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColour.textOnInverseSecondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(phase.label)
                        .font(.headline)
                        .foregroundStyle(AppColour.textOnInverse)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(AppColour.textOnInverseSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    timerLabel(at: timeline.date)
                        .foregroundStyle(AppColour.textOnInverse)
                    Text(context.state.status == .paused ? BreathworkCopy.paused : BreathworkCopy.remaining)
                        .font(.caption2)
                        .foregroundStyle(AppColour.textOnInverseSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var statusText: String {
        switch context.state.status {
        case .active:
            return context.state.protocolType.title
        case .paused:
            return BreathworkCopy.statusPaused
        case .completed:
            return BreathworkCopy.statusComplete
        }
    }

    private func phase(at date: Date) -> BreathworkLivePhase {
        guard context.state.status == .active else {
            return context.state.currentPhase
        }

        let elapsed = max(0, date.timeIntervalSince(context.state.sessionStartDate))
        return context.state.protocolType.phase(atElapsed: elapsed)
    }

    @ViewBuilder
    private func timerLabel(at date: Date) -> some View {
        switch context.state.status {
        case .active:
            Text(timerInterval: WidgetStyle.timerRange(from: date, to: context.state.sessionEndDate), countsDown: true)
                .font(.title3.weight(.bold).monospacedDigit())
        case .paused:
            Text(format(seconds: context.state.remainingSeconds))
                .font(.title3.weight(.bold).monospacedDigit())
        case .completed:
            Text(BreathworkCopy.done)
                .font(.title3.weight(.bold))
        }
    }

    private func format(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainder = max(seconds, 0) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

/// Lock-screen pace cue. Scales between phases following `orbScale` so the orb
/// tracks the lungs; suppressed when Reduce Motion is on. Lock-screen Live
/// Activity views may animate, unlike the Dynamic Island orb above.
private struct LockScreenBreathingOrb: View {
    let phase: BreathworkLivePhase
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(AppColour.accent.opacity(0.22))
            .overlay(Circle().stroke(AppColour.accent, lineWidth: 1.4))
            .frame(width: size, height: size)
            .scaleEffect(phase.orbScale)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1), value: phase)
            .accessibilityHidden(true)
    }
}

// MARK: - Compact trailing timer

private struct CompactTimerText: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        switch context.state.status {
        case .active:
            Text(timerInterval: WidgetStyle.timerRange(to: context.state.sessionEndDate), countsDown: true)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AppColour.accent)
                .frame(minWidth: 40, alignment: .trailing)
        case .paused:
            Text(BreathworkCopy.pausedCompact)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColour.accent)
        case .completed:
            Text(BreathworkCopy.completeCompact)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColour.accent)
        }
    }
}
