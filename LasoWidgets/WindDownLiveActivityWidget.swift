import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

/// Dynamic Island + Lock Screen presentation for the evening wind-down window.
///
/// The only element that truly animates is `Text(timerInterval:)` — that's the
/// primitive iOS renders smoothly in the Live Activity surface. The evolving
/// phrase is driven by a 60-second TimelineView (works when the island is tapped
/// or the lock screen is visible) so the text updates as bedtime approaches.
struct WindDownLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WindDownActivityAttributes.self) { context in
            WindDownLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WindDownIconTile(state: context.state, size: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WindDownCountdownStack(state: context.state, font: .system(size: 30, weight: .bold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.center) {
                    WindDownPhraseLine(state: context.state)
                        .padding(.top, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WindDownActionRow(state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(windDownTint)
            } compactTrailing: {
                CompactCountdown(bedtime: context.state.targetBedtime)
                    .foregroundStyle(windDownTint)
            } minimal: {
                ZStack {
                    Circle().fill(windDownTint.opacity(0.22))
                    Circle().stroke(windDownTint, lineWidth: 1.2)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(windDownTint)
                }
            }
        }
    }
}

// MARK: - Lock Screen

private struct WindDownLockScreenView: View {
    let state: WindDownActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            WindDownIconTile(state: state, size: 58)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(windDownTint)
                    Text("WIND DOWN")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
                WindDownPhraseLine(state: state)
                if let hint = hrvHint(state: state) {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            WindDownCountdownStack(
                state: state,
                font: .system(size: 26, weight: .bold, design: .rounded)
            )

            WindDownBreatheButton()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func hrvHint(state: WindDownActivityAttributes.ContentState) -> String? {
        guard state.hrvIsLow, let hrv = state.hrvMs, hrv > 0 else { return nil }
        return "HRV \(hrv) ms — an earlier night helps"
    }
}

// MARK: - Icon Tile (expanded leading / lock screen)

private struct WindDownIconTile: View {
    let state: WindDownActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let stage = currentStage(now: timeline.date, bedtime: state.targetBedtime)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(windDownTint.opacity(0.18))
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .stroke(windDownTint.opacity(0.55), lineWidth: 1)
                Image(systemName: stage.symbolName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(windDownTint)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Countdown (expanded trailing / lock screen)

private struct WindDownCountdownStack: View {
    let state: WindDownActivityAttributes.ContentState
    let font: Font

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("TO BED")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(timerInterval: Date()...state.targetBedtime, countsDown: true)
                .font(font.monospacedDigit())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.trailing, 6)
    }
}

// MARK: - Compact Trailing Countdown

private struct CompactCountdown: View {
    let bedtime: Date

    var body: some View {
        Text(timerInterval: Date()...bedtime, countsDown: true)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .frame(minWidth: 34, alignment: .trailing)
    }
}

// MARK: - Phrase Line

private struct WindDownPhraseLine: View {
    let state: WindDownActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Text(currentStage(now: timeline.date, bedtime: state.targetBedtime).phrase)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
    }
}

// MARK: - Action Row

private struct WindDownActionRow: View {
    let state: WindDownActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            WindDownBreatheButton()
            Spacer()
        }
    }
}

private struct WindDownBreatheButton: View {
    var body: some View {
        Button(intent: CoachBreatheIntent()) {
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.footnote.weight(.semibold))
                Text("Breathe 2 min")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(windDownTint.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(windDownTint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared helpers

private let windDownTint = Color(red: 0.52, green: 0.49, blue: 0.86) // calm violet

private func currentStage(now: Date, bedtime: Date) -> WindDownStage {
    let minutes = Int((bedtime.timeIntervalSince(now) / 60).rounded(.down))
    return WindDownStage.stage(minutesToBedtime: minutes)
}
