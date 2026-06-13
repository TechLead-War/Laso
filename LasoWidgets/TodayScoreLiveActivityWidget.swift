import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

struct TodayScoreLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayScoreActivityAttributes.self) { context in
            CoachLockScreenView(state: context.state)
                // Fixed dark chrome — matches AppColour.surfaceBase so the Live
                // Activity feels carved out of the lock screen and never flips to
                // a white card in light mode (Apple-Music vibe).
                .activityBackgroundTint(AppColour.surfaceBase)
                .activitySystemActionForegroundColor(AppColour.textPrimary)
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
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CoachActionBar(kind: context.state.actionKind, tint: bandColor(for: context.state))
                        .padding(.top, 2)
                }
            } compactLeading: {
                CompactLeadingRing(state: context.state)
                    .accessibilityLabel(context.state.mode.headline)
                    .widgetURL(Self.todaysActionURL)
            } compactTrailing: {
                Text("\(context.state.overallScore)")
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(scoreTint(for: context.state))
                    .contentTransition(.numericText())
                    .accessibilityLabel(scoreAccessibilityLabel(for: context.state))
                    .widgetURL(Self.todaysActionURL)
            } minimal: {
                MinimalModeBadge(state: context.state)
            }
        }
    }

    /// Deep link target for the dashboard surface. `onOpenURL` (added by D3) maps
    /// this via `Route.fromUITestIdentifier` to `Route.todaysAction`.
    private static let todaysActionURL = URL(string: "laso://route/todaysAction")
}

// MARK: - Lock Screen

private struct CoachLockScreenView: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = bandColor(for: state)

        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                CoachOrbRing(state: state, size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: state.mode.symbolName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                        Text(state.mode.headline)
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let stale = staleAgePhrase(state) {
                            Text(stale)
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(AppColour.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    Text(state.insight)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if state.actionKind != .noop {
                    CoachActionBar(kind: state.actionKind, tint: tint)
                        .layoutPriority(0)
                }
            }

            DayProgressStrip()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Pure-black card body. Score-band tint stays on the ring and the accent
        // icon so colour signals the score state without washing the card grey.
        .background(AppColour.surfaceBase)
        .overlay(alignment: .topLeading) {
            // 1px score-tint hairline at the top — subtle premium accent.
            Rectangle()
                .fill(tint.opacity(0.55))
                .frame(height: 1)
        }
    }
}

// MARK: - Time-of-Day Progress Strip

/// Thin progress bar that auto-fills from sunrise (5:00) to bedtime (23:00)
/// using `ProgressView(timerInterval:)` so it advances without needing a
/// state push. Gives the Live Activity a visible "moving through the day"
/// signal independent of score updates.
private struct DayProgressStrip: View {
    var body: some View {
        let (start, end) = todayDayWindow()
        ProgressView(timerInterval: start...end, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        // Brand primary keeps the moving fill on-palette across every mode.
        .tint(AppColour.primary)
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Orb Ring (expanded leading / lock screen)

/// Ring fill and centre number both read the overall 0–100 score from the same
/// quantity, so the gauge and the digit can never disagree. Mode-specific hero
/// metrics (HRV, steps) live only in the trailing stack.
private struct CoachOrbRing: View {
    let state: TodayScoreActivityAttributes.ContentState
    let size: CGFloat

    /// Inset of the inner score ring inside the outer day track so the two arcs
    /// read as distinct concentric rings instead of one fat stroke.
    private let dayTrackInset: CGFloat = 5

    var body: some View {
        let tint = scoreTint(for: state)
        let progress = max(0, min(1, Double(state.overallScore) / 100.0))
        let (dayStart, dayEnd) = todayDayWindow()

        ZStack {
            Circle()
                .fill(AppColour.surfaceOverlay.opacity(0.55))

            // OUTER day track — faint full circle + a self-advancing fill that
            // crawls sunrise→bedtime via ProgressView(timerInterval:) with no push.
            // `.circular` is the only self-advancing ring primitive in a Live
            // Activity; a static `.trim` would freeze until the next push.
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
            ProgressView(timerInterval: dayStart...dayEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(AppColour.textTertiary)
            .accessibilityHidden(true)

            // INNER score ring — band-coloured arc (greyed when stale).
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .padding(dayTrackInset)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(dayTrackInset)

            VStack(spacing: 1) {
                Text("\(state.overallScore)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(TodayScoreCopy.scoreUnit)
                    .font(.system(size: max(7, size * 0.11), weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scoreAccessibilityLabel(for: state))
    }
}

// MARK: - Trailing Stack (expanded trailing)

private struct CoachTrailingStack: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = scoreTint(for: state)

        VStack(alignment: .trailing, spacing: 4) {
            Text(state.mode.secondaryLabel)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(AppColour.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(secondaryValue)
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColour.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit = secondaryUnit {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(String(format: TodayScoreCopy.scoreCaptionTemplate, state.overallScore))
                .font(.caption2)
                .foregroundStyle(tint.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Quiet weakest-pillar nudge — only when the score is known.
            if let weakest = state.weakestPillarScore {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColour.warning)
                    Text("\(state.weakestPillar) \(weakest)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.trailing, 6)
    }

    private var secondaryValue: String {
        switch state.mode {
        case .morning:
            if let hrv = state.hrvMs { return "\(hrv)" }
            return "\(state.restingHR ?? state.heroValue)"
        case .day:
            return stepsDisplay(state.steps)
        case .evening, .night:
            return "\(state.heroValue)"
        }
    }

    private var secondaryUnit: String? {
        switch state.mode {
        case .morning: return state.hrvMs != nil ? TodayScoreCopy.msUnit : (state.restingHR != nil ? TodayScoreCopy.bpmUnit : nil)
        case .day:     return nil
        case .evening, .night: return nil
        }
    }

    private func stepsDisplay(_ steps: Int) -> String {
        if steps >= 10_000 {
            let k = Double(steps) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(steps)"
    }
}

// MARK: - Compact Leading Ring

/// Small score ring for the Dynamic Island compact leading slot. Mirrors the
/// orb's inner arc (surface backing + faint track + band-coloured score arc)
/// so the compact and expanded presentations read as the same gauge. Greys to
/// `textTertiary` when the data is stale, matching every other surface.
private struct CompactLeadingRing: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = scoreTint(for: state)
        let progress = max(0, min(1, Double(state.overallScore) / 100.0))
        ZStack {
            Circle()
                .fill(AppColour.surfaceOverlay.opacity(0.55))
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Minimal

private struct MinimalModeBadge: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = scoreTint(for: state)
        let progress = max(0, min(1, Double(state.overallScore) / 100.0))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1.8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(state.overallScore)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(2)
        }
        .accessibilityLabel(scoreAccessibilityLabel(for: state))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.accessibilityLabel ?? kind.label)
    }
}

// MARK: - Shared helpers

/// All score-driven tints route through the single `WidgetStyle.scoreBandColor`
/// ramp so the ring, number, and accent icon never disagree.
private func bandColor(for state: TodayScoreActivityAttributes.ContentState) -> Color {
    WidgetStyle.scoreBandColor(score: state.overallScore)
}

/// Score-band tint, but greyed to `textTertiary` once the data is stale so a
/// frozen ring never keeps showing a confident "green" hours after the last
/// push. Drives the score arc + centre number everywhere the band colour reads.
private func scoreTint(for state: TodayScoreActivityAttributes.ContentState) -> Color {
    isStale(state) ? AppColour.textTertiary : bandColor(for: state)
}

private func scoreAccessibilityLabel(for state: TodayScoreActivityAttributes.ContentState) -> String {
    String(format: TodayScoreCopy.ringAccessibilityTemplate, state.overallScore, state.mode.headline)
}

// MARK: - Day window (shared by the dual ring + DayProgressStrip)

/// Sunrise (5:00) → bedtime (23:00) window for the current day. Both the
/// `DayProgressStrip` linear bar and the `CoachOrbRing` outer day track drive
/// their `ProgressView(timerInterval:)` from this single window so they crawl
/// through the day in lockstep with no extra push.
private func todayDayWindow() -> (Date, Date) {
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)
    let start = calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? startOfDay
    let end = calendar.date(byAdding: .hour, value: 23, to: startOfDay) ?? startOfDay
    return (start, end)
}

// MARK: - Staleness (pure render logic over `lastUpdated`)

/// Live Activities can sit on the lock screen long after the last data push.
/// Past this window the ring is treated as stale: the score arc + number grey
/// out and the eyebrow gains a "Updated Nh ago" note. Pure render-time logic —
/// no new ContentState field and no extra push.
private let staleThreshold: TimeInterval = 20 * 60 * 60 // 20h

private func isStale(_ state: TodayScoreActivityAttributes.ContentState) -> Bool {
    Date().timeIntervalSince(state.lastUpdated) > staleThreshold
}

/// Short "Updated 21h ago" phrase for the eyebrow, or `nil` when the data is
/// still fresh. Uses an abbreviated relative formatter so it stays one line.
private func staleAgePhrase(_ state: TodayScoreActivityAttributes.ContentState) -> String? {
    guard isStale(state) else { return nil }
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.maximumUnitCount = 1
    formatter.unitsStyle = .abbreviated
    let elapsed = Date().timeIntervalSince(state.lastUpdated)
    let age = formatter.string(from: elapsed) ?? ""
    return String(format: TodayScoreCopy.staleAgeTemplate, age)
}
