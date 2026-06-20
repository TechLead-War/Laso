import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

/// Dynamic Island + Lock Screen presentation for the evening wind-down window.
///
/// The countdown to bedtime advances without a push update via
/// `Text(timerInterval:)`, and the expanded moon-arc fills toward bedtime via
/// `ProgressView(timerInterval:)` — the only ring primitive iOS keeps moving in
/// a Live Activity. The stage phrase is computed once per render from `now`
/// (the system re-renders the island on its own cadence); it carries no
/// animation primitive of its own, so it never freezes a stale frame on screen.
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
                // EXPANDED — the HTML "type: count" card mapped onto the four
                // fixed regions: mode pill (leading) + stamp (trailing) form the
                // head, the insight/countdown sits centre, and the moon-arc tile
                // plus the full-width action button fill the bottom.
                DynamicIslandExpandedRegion(.leading) {
                    WindDownModePill()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WindDownStampLabel(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WindDownExpandedBody(state: context.state)
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

            WindDownBreatheButton(fullWidth: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func hrvHint(state: WindDownActivityAttributes.ContentState) -> String? {
        guard state.hrvIsLow, let hrv = state.hrvMs, hrv > 0 else { return nil }
        return String(format: WindDownCopy.hrvHintTemplate, hrv)
    }
}

// MARK: - Expanded head (mode pill + stamp)

/// Tint-tinted capsule with the moon glyph and the "Wind down" headline — the
/// HTML `modepill`. Background is the accent at 18% to match `color-mix(... 18%)`.
private struct WindDownModePill: View {
    var body: some View {
        // Fixed point sizes: the expanded island ignores `.dynamicTypeSize` and is
        // capped at 160 pt, so a scaling leading pill grows the head row and pushes
        // the bottom Breathe button past the cap. Pinning holds the height.
        HStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(windDownTint)
            Text(WindDownCopy.header)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(windDownTint.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WindDownCopy.header)
    }
}

/// HTML `stamp` — small tertiary "time until bedtime" label sitting opposite the
/// mode pill. Driven by `Text(timerInterval:)` so it stays live without a push.
private struct WindDownStampLabel: View {
    let state: WindDownActivityAttributes.ContentState

    var body: some View {
        Text(WindDownCopy.toBed)
            .font(.system(size: 12, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(AppColour.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityHidden(true)
    }
}

// MARK: - Expanded body (moon-arc + countdown copy + action)

/// The HTML `exp-body` grid `auto 1fr` followed by the `exp-foot` button, mapped
/// into the single `.bottom` region (the only region wide enough to host the
/// card). Left = moon-arc tile, right = big countdown + stage phrase + HRV hint,
/// below = full-width Breathe action.
private struct WindDownExpandedBody: View {
    let state: WindDownActivityAttributes.ContentState

    var body: some View {
        // Fixed point sizes (not Dynamic Type styles): the expanded island is capped
        // at 160 pt and ignores `.dynamicTypeSize`, so scaling fonts would push the
        // Breathe action past the cap and the system would clip it. Fixed sizes hold
        // the height constant; the lock-screen card still scales for accessibility.
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                WindDownMoonArc(state: state, size: 56)

                VStack(alignment: .leading, spacing: 3) {
                    // exp-count: big countdown number + "to bed" unit. The
                    // timer primitive renders the live minutes; the static unit
                    // sits beside it as the HTML `small`.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(timerInterval: WidgetStyle.timerRange(to: state.targetBedtime), countsDown: true)
                            .font(.system(size: 30, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppColour.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(WindDownCopy.toBed)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    // stage-phrase: accent-coloured, softens as bed nears.
                    Text(currentStage(now: Date(), bedtime: state.targetBedtime).phrase)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(windDownTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // hint: optional HRV nudge, tertiary.
                    if let hint = hrvHint(state: state) {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColour.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 4)
            }

            WindDownBreatheButton(fullWidth: true, fixedType: true)
        }
        .padding(.top, 4)
    }

    private func hrvHint(state: WindDownActivityAttributes.ContentState) -> String? {
        guard state.hrvIsLow, let hrv = state.hrvMs, hrv > 0 else { return nil }
        return String(format: WindDownCopy.hrvHintTemplate, hrv)
    }
}

// MARK: - Moon Arc Tile (expanded leading figure)

/// HTML `ring-wrap` for the wind-down count card: a soft radial bloom behind an
/// advancing accent arc, with the moon glyph centred. The arc fills from
/// `windDownStartedAt` to `targetBedtime` via `ProgressView(timerInterval:)` —
/// the only self-advancing ring primitive in a Live Activity. A static `.trim`
/// would freeze until the next push. The glow is a RadialGradient layer (never
/// `.blur`/`.shadow`, which render as a box and do not display in widgets).
private struct WindDownMoonArc: View {
    let state: WindDownActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        let (start, end) = arcWindow(state: state)

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 4)
            ProgressView(timerInterval: start...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(windDownTint)
            .accessibilityHidden(true)

            Image(systemName: currentStage(now: Date(), bedtime: state.targetBedtime).symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(windDownTint)
        }
        .frame(width: size, height: size)
        .background {
            RadialGradient(
                colors: [windDownTint.opacity(0.22), windDownTint.opacity(0)],
                center: .center, startRadius: 4, endRadius: size * 0.85
            )
            .scaleEffect(1.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentStage(now: Date(), bedtime: state.targetBedtime).accessibilityLabel)
    }

    /// Clamps the arc window so the progress timer always has a forward range:
    /// once bedtime has passed, peg `end` just ahead of `now` so the ring reads
    /// as full rather than crashing on an empty `ClosedRange`.
    private func arcWindow(state: WindDownActivityAttributes.ContentState) -> (Date, Date) {
        let start = state.windDownStartedAt
        let end = max(state.targetBedtime, start.addingTimeInterval(1))
        return (start, end)
    }
}

// MARK: - Icon Tile (lock screen)

/// Progress arc that fills from `windDownStartedAt` to `targetBedtime` with the
/// current stage glyph centred. A 60-second TimelineView advances both the fill
/// and the glyph; kept for the lock-screen card, where TimelineView refreshes
/// reliably while the screen is visible.
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

// MARK: - Countdown (lock screen)

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
            Text(timerInterval: WidgetStyle.timerRange(to: state.targetBedtime), countsDown: true)
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
        Text(timerInterval: WidgetStyle.timerRange(to: bedtime), countsDown: true)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .frame(minWidth: 34, alignment: .trailing)
    }
}

// MARK: - Phrase Line (lock screen)

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

// MARK: - Action Button

/// HTML `btn` — the single full-width "Breathe 2 min" action. Accent at 22%
/// background, accent glyph, white label. `fullWidth` lets the lock screen reuse
/// it as a trailing pill while the expanded island stretches it edge to edge.
private struct WindDownBreatheButton: View {
    var fullWidth: Bool
    /// Fixed point size instead of a Dynamic Type style. The expanded island has a
    /// hard 160 pt cap and ignores `.dynamicTypeSize`, so the island passes `true`
    /// to hold its height; the lock-screen card leaves this `false` so its action
    /// still scales for accessibility.
    var fixedType: Bool = false

    private var labelFont: Font {
        fixedType ? .system(size: 13, weight: .semibold) : .footnote.weight(.semibold)
    }

    var body: some View {
        Button(intent: WindDownBreatheIntent()) {
            HStack(spacing: 7) {
                Image(systemName: "wind")
                    .font(labelFont)
                    .foregroundStyle(windDownTint)
                Text(WindDownCopy.breatheButton)
                    .font(labelFont)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(windDownTint.opacity(0.22), in: Capsule())
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
