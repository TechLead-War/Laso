import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

struct TodayScoreLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayScoreActivityAttributes.self) { context in
            CoachLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CoachOrbRing(state: context.state, size: 62)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CoachTrailingStack(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.insight)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CoachActionBar(kind: context.state.actionKind, tint: tintColor(for: context.state.scoreTint))
                        .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.state.mode.symbolName)
                    .foregroundStyle(tintColor(for: context.state.scoreTint))
            } compactTrailing: {
                Text("\(context.state.heroValue)")
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tintColor(for: context.state.scoreTint))
                    .contentTransition(.numericText())
            } minimal: {
                MinimalModeBadge(state: context.state)
            }
        }
    }
}

// MARK: - Lock Screen

private struct CoachLockScreenView: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = tintColor(for: state.scoreTint)

        HStack(alignment: .center, spacing: 14) {
            CoachOrbRing(state: state, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: state.mode.symbolName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(state.mode.headline.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
                Text(state.insight)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if state.actionKind != .noop {
                CoachActionBar(kind: state.actionKind, tint: tint)
                    .layoutPriority(0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Orb Ring (expanded leading / lock screen)

private struct CoachOrbRing: View {
    let state: TodayScoreActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        let tint = tintColor(for: state.scoreTint)
        // Ring always represents the overall score (0-100). heroValue may be a
        // raw metric (HRV ms, RHR bpm, steps) that does not map 0-100, so using
        // it directly makes the ring over or under fill for non-score modes.
        let progress = max(0, min(1, Double(state.overallScore) / 100.0))

        ZStack {
            Circle()
                .fill(Color.black.opacity(0.55))
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(state.heroValue)")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(state.heroLabel.uppercased())
                    .font(.system(size: max(7, size * 0.11), weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Trailing Stack (expanded trailing)

private struct CoachTrailingStack: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = tintColor(for: state.scoreTint)

        VStack(alignment: .trailing, spacing: 3) {
            Text(secondaryLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(secondaryValue)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                if let unit = secondaryUnit {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(scoreTrailingCaption)
                .font(.caption2)
                .foregroundStyle(tint.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.trailing, 6)
    }

    private var secondaryLabel: String {
        switch state.mode {
        case .morning: return "HRV"
        case .day:     return "Steps"
        case .evening: return "Score"
        case .night:   return "Score"
        }
    }

    private var secondaryValue: String {
        switch state.mode {
        case .morning:
            if let hrv = state.hrvMs { return "\(hrv)" }
            return "\(state.restingHR ?? state.overallScore)"
        case .day:
            return stepsDisplay(state.steps)
        case .evening, .night:
            return "\(state.overallScore)"
        }
    }

    private var secondaryUnit: String? {
        switch state.mode {
        case .morning: return state.hrvMs != nil ? "ms" : (state.restingHR != nil ? "bpm" : nil)
        case .day:     return nil
        case .evening, .night: return nil
        }
    }

    private var scoreTrailingCaption: String {
        "Laso score \(state.overallScore)"
    }

    private func stepsDisplay(_ steps: Int) -> String {
        if steps >= 10_000 {
            let k = Double(steps) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(steps)"
    }
}

// MARK: - Minimal

private struct MinimalModeBadge: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = tintColor(for: state.scoreTint)
        ZStack {
            Circle()
                .fill(tint.opacity(0.24))
            Circle()
                .stroke(tint, lineWidth: 1.4)
            Image(systemName: state.mode.symbolName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Action Bar (App Intent buttons)

private struct CoachActionBar: View {
    let kind: CoachActionKind
    let tint: Color

    var body: some View {
        switch kind {
        case .setIntention:
            actionButton(CoachSetIntentionIntent())
        case .breathe:
            actionButton(CoachBreatheIntent())
        case .windDown:
            actionButton(CoachWindDownIntent())
        case .noop:
            EmptyView()
        }
    }

    @ViewBuilder
    private func actionButton<I: AppIntent>(_ intent: I) -> some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.footnote.weight(.semibold))
                Text(kind.label)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tint Mapping

private func tintColor(for tint: TodayScoreTint) -> Color {
    switch tint {
    case .excellent: return .green
    case .good:      return .mint
    case .fair:      return .orange
    case .poor:      return .red
    }
}
