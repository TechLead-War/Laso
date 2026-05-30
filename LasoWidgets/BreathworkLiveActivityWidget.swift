import ActivityKit
import SwiftUI
import WidgetKit

struct BreathworkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathworkActivityAttributes.self) { context in
            BreathworkLiveActivityView(context: context)
                // Fixed dark chrome — the activity is tuned for dark surfaces and
                // must not flip to white in light mode behind the lock screen.
                .activityBackgroundTint(AppColour.surfaceBase)
                .activitySystemActionForegroundColor(AppColour.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.protocolType.title, systemImage: context.state.protocolType.symbolName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BreathworkTimerLabel(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let phase = phase(at: timeline.date, context: context)
                        HStack(spacing: 10) {
                            BreathingOrb(phase: phase, size: 22)
                            Text(phase.label)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Text(context.state.protocolType.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppColour.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(phase.accessibilityLabel)
                        .widgetURL(Self.stressMonitorURL)
                    }
                }
            } compactLeading: {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let phase = phase(at: timeline.date, context: context)
                    Image(systemName: phase.symbolName)
                        .foregroundStyle(AppColour.accent)
                        .accessibilityLabel(phase.accessibilityLabel)
                        .widgetURL(Self.stressMonitorURL)
                }
            } compactTrailing: {
                CompactTimerText(context: context)
                    .accessibilityLabel(BreathworkCopy.timerAccessibilityLabel)
                    .widgetURL(Self.stressMonitorURL)
            } minimal: {
                Image(systemName: context.state.protocolType.symbolName)
                    .accessibilityLabel(context.state.protocolType.title)
            }
        }
    }

    /// Deep link target for the breathwork surface. `onOpenURL` (added by D3)
    /// maps this via `Route.fromUITestIdentifier` to `Route.stressMonitor`.
    private static let stressMonitorURL = URL(string: "laso://route/stressMonitor")

    private func phase(
        at date: Date,
        context: ActivityViewContext<BreathworkActivityAttributes>
    ) -> BreathworkLivePhase {
        guard context.state.status == .active else {
            return context.state.currentPhase
        }

        let elapsed = max(0, date.timeIntervalSince(context.state.sessionStartDate))
        return context.state.protocolType.phase(atElapsed: elapsed)
    }
}

// MARK: - Breathing Orb

/// Signature pace cue. Scales between phases following `BreathworkLivePhase.orbScale`
/// so the orb tracks the lungs. The scaling animation is suppressed when Reduce
/// Motion is on — the orb then renders at the phase's fixed size with no movement.
private struct BreathingOrb: View {
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

private struct BreathworkLiveActivityView: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let phase = phase(at: timeline.date)
            HStack(spacing: 12) {
                BreathingOrb(phase: phase, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.protocolType.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(phase.label)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    timerLabel(at: timeline.date)
                    Text(context.state.status == .paused ? BreathworkCopy.paused : BreathworkCopy.remaining)
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
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
            Text(timerInterval: date...context.state.sessionEndDate, countsDown: true)
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

private struct BreathworkTimerLabel: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            switch context.state.status {
            case .active:
                Text(timerInterval: timeline.date...context.state.sessionEndDate, countsDown: true)
                    .font(.headline.monospacedDigit())
            case .paused:
                Text(format(seconds: context.state.remainingSeconds))
                    .font(.headline.monospacedDigit())
            case .completed:
                Text(BreathworkCopy.done)
                    .font(.headline)
            }
        }
        .accessibilityLabel(BreathworkCopy.timerAccessibilityLabel)
    }

    private func format(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainder = max(seconds, 0) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct CompactTimerText: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            switch context.state.status {
            case .active:
                Text(shortRemaining(at: timeline.date))
                    .font(.caption2.monospacedDigit())
            case .paused:
                Text(BreathworkCopy.pausedCompact)
                    .font(.caption2.weight(.bold))
            case .completed:
                Text(BreathworkCopy.completeCompact)
                    .font(.caption2.weight(.bold))
            }
        }
    }

    private func shortRemaining(at date: Date) -> String {
        let seconds = max(Int(context.state.sessionEndDate.timeIntervalSince(date)), 0)
        return seconds >= 60 ? "\(seconds / 60)m" : "\(seconds)s"
    }
}
