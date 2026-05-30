import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

/// Dynamic Island + Lock Screen presentation for the evening wind-down window.
///
/// Two elements animate without a push update: `Text(timerInterval:)` (the
/// primitive iOS renders smoothly) and the icon-tile progress arc + evolving
/// phrase, both driven by a 60-second TimelineView so they advance as bedtime
/// approaches whenever the island is tapped or the lock screen is visible.
struct WindDownLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WindDownActivityAttributes.self) { context in
            WindDownLockScreenView(state: context.state)
                // Fixed dark chrome — the activity is tuned for dark surfaces and
                // must not flip to white in light mode behind the lock screen.
                .activityBackgroundTint(AppColour.surfaceOverlay.opacity(0.82))
                .activitySystemActionForegroundColor(AppColour.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WindDownIconTile(state: context.state, size: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WindDownCountdownStack(state: context.state, font: .title.weight(.bold))
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
                    .accessibilityLabel(WindDownCopy.header)
                    .widgetURL(Self.sleepCoachURL)
            } compactTrailing: {
                CompactCountdown(bedtime: context.state.targetBedtime)
                    .foregroundStyle(windDownTint)
                    .accessibilityLabel(WindDownCopy.compactCountdownAccessibilityLabel)
                    .widgetURL(Self.sleepCoachURL)
            } minimal: {
                ZStack {
                    Circle().fill(windDownTint.opacity(0.22))
                    Circle().stroke(windDownTint, lineWidth: 1.2)
                    Image(systemName: "moon.stars.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(windDownTint)
                }
                .accessibilityLabel(WindDownCopy.header)
            }
        }
    }

    /// Deep link target for the wind-down surface. `onOpenURL` (added by D3) maps
    /// this via `Route.fromUITestIdentifier` to `Route.sleepCoach`.
    private static let sleepCoachURL = URL(string: "laso://route/sleepCoach")
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
                    Text(WindDownCopy.header)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                WindDownPhraseLine(state: state)
                if let hint = hrvHint(state: state) {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 4)

            WindDownCountdownStack(state: state, font: .title2.weight(.bold))

            WindDownBreatheButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func hrvHint(state: WindDownActivityAttributes.ContentState) -> String? {
        guard state.hrvIsLow, let hrv = state.hrvMs, hrv > 0 else { return nil }
        return String(format: WindDownCopy.hrvHintTemplate, hrv)
    }
}

// MARK: - Icon Tile (expanded leading / lock screen)

/// Progress arc that fills from `windDownStartedAt` to `targetBedtime` with the
/// current stage glyph centred. A 60-second TimelineView advances both the fill
/// and the glyph without needing a push update each minute.
private struct WindDownIconTile: View {
    let state: WindDownActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let stage = currentStage(now: timeline.date, bedtime: state.targetBedtime)
            let progress = fillProgress(now: timeline.date)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(windDownTint.opacity(0.18))
                Circle()
                    .stroke(windDownTint.opacity(0.22), lineWidth: 3)
                    .padding(size * 0.12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(windDownTint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.12)
                Image(systemName: stage.symbolName)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(windDownTint)
            }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stage.accessibilityLabel)
        }
    }

    /// Clamped 0…1 fraction of the wind-down window elapsed so far.
    private func fillProgress(now: Date) -> Double {
        let total = state.targetBedtime.timeIntervalSince(state.windDownStartedAt)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(state.windDownStartedAt)
        return max(0, min(1, elapsed / total))
    }
}

// MARK: - Countdown (expanded trailing / lock screen)

private struct WindDownCountdownStack: View {
    let state: WindDownActivityAttributes.ContentState
    let font: Font

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(WindDownCopy.toBed)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(AppColour.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(timerInterval: Date()...state.targetBedtime, countsDown: true)
                .font(font.monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.trailing, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WindDownCopy.toBed)
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
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
        Button(intent: WindDownBreatheIntent()) {
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.footnote.weight(.semibold))
                Text(WindDownCopy.breatheButton)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(windDownTint.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(windDownTint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WindDownCopy.breatheButtonAccessibilityLabel)
    }
}

// MARK: - Shared helpers

private let windDownTint = AppColour.windDownTint

private func currentStage(now: Date, bedtime: Date) -> WindDownStage {
    let minutes = Int((bedtime.timeIntervalSince(now) / 60).rounded(.down))
    return WindDownStage.stage(minutesToBedtime: minutes)
}
