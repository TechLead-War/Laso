import ActivityKit
import SwiftUI
import WidgetKit

struct BreathworkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathworkActivityAttributes.self) { context in
            BreathworkLiveActivityView(context: context)
                .activityBackgroundTint(AppColour.surfaceBase)
                .activitySystemActionForegroundColor(AppColour.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.protocolType.title, systemImage: context.state.protocolType.symbolName)
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BreathworkTimerLabel(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        HStack(spacing: 10) {
                            Image(systemName: phase(at: timeline.date, context: context).symbolName)
                                .foregroundStyle(AppColour.accent)
                            Text(phase(at: timeline.date, context: context).label)
                                .font(.headline)
                            Spacer()
                            Text(context.state.protocolType.subtitle)
                                .font(.caption)
                                .foregroundStyle(AppColour.textSecondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: phase(at: .now, context: context).symbolName)
            } compactTrailing: {
                CompactTimerText(context: context)
            } minimal: {
                Image(systemName: context.state.protocolType.symbolName)
            }
        }
    }

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

private struct BreathworkLiveActivityView: View {
    let context: ActivityViewContext<BreathworkActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack(spacing: 12) {
                Image(systemName: phase(at: timeline.date).symbolName)
                    .font(.title2)
                    .foregroundStyle(AppColour.accent)
                    .frame(width: 40, height: 40)
                    .background(AppColour.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.protocolType.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)
                    Text(phase(at: timeline.date).label)
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    timerLabel(at: timeline.date)
                    Text(context.state.status == .paused ? "Paused" : "Remaining")
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
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
            return "Session paused"
        case .completed:
            return "Session complete"
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
            Text("Done")
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
                Text("Done")
                    .font(.headline)
            }
        }
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
                Text("II")
                    .font(.caption2.weight(.bold))
            case .completed:
                Text("OK")
                    .font(.caption2.weight(.bold))
            }
        }
    }

    private func shortRemaining(at date: Date) -> String {
        let seconds = max(Int(context.state.sessionEndDate.timeIntervalSince(date)), 0)
        return seconds >= 60 ? "\(seconds / 60)m" : "\(seconds)s"
    }
}
