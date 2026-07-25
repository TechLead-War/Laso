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
                // The top slots flank the TrueDepth camera and are NARROW — a wide pill
                // or label truncates there (the "Re..." bug). So leading/trailing carry
                // only a glyph + the time, the centre is left empty (the camera squeezes
                // it), and ALL wide content — ring, mode label, insight, stats, action —
                // lives in the full-width, roomy .bottom card. Researched region model.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.mode.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(bandColor(for: context.state))
                        .accessibilityLabel(context.state.mode.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CoachStamp(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CoachExpandedCard(state: context.state)
                }
            } compactLeading: {
                CompactLeadingRing(state: context.state)
                    .accessibilityLabel(context.state.mode.headline)
                    .widgetURL(Self.todaysActionURL)
            } compactTrailing: {
                Text("\(context.state.overallScore)")
                    // Fixed size + scale-to-fit: the compact pill is the only place a
                    // scaling font remained; a 3-digit score (100) at large text widens
                    // the pill and crowds the leading ring.
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                // GLOW HERO: a large score ring with a soft band-colour radial bloom
                // behind it (lock screen only). RadialGradient, not .blur — widgets do
                // not render blur. Single soft radial <=20% opacity, no white halo.
                CoachOrbRing(state: state, size: 78)
                    .background {
                        // Circle-clipped bloom (see CoachExpandedRing) so the soft band
                        // glow never renders as a square behind the lock-screen ring.
                        Circle()
                            .fill(RadialGradient(
                                colors: [tint.opacity(0.22), .clear],
                                center: .center, startRadius: 8, endRadius: 56
                            ))
                            .frame(width: 118, height: 118)
                    }

                VStack(alignment: .leading, spacing: 5) {
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
                    // Hero insight — promoted to headline so it carries real weight.
                    Text(state.insight)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    // Supporting stat + weakest-pillar limiter, both demoted.
                    HStack(spacing: 10) {
                        if let hrv = state.hrvMs {
                            Text("HRV \(hrv) ms")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(AppColour.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if let pillar = state.weakestPillarScore {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("\(state.weakestPillar) \(pillar)")
                            }
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppColour.warning)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        }
                    }
                }

                Spacer(minLength: 4)
            }

            // Full-width action below the hero row (matches the chosen Glow Hero look).
            if state.actionKind != .noop {
                CoachActionBar(kind: state.actionKind, tint: tint, fullWidth: true)
            }

            DayProgressStrip()
        }
        .padding(14)
        .background(AppColour.surfaceBase)
        .overlay(alignment: .top) {
            // 1px score-tint hairline at the top — the only chrome accent.
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
    /// Expanded Dynamic Island passes `false` for a single bold score arc (no day
    /// track) so the ring reads large and clean in the tight leading slot; the lock
    /// screen keeps the day track since it has room.
    var showDayTrack: Bool = true

    /// Inset of the inner score ring inside the outer day track so the two arcs
    /// read as distinct concentric rings instead of one fat stroke.
    private let dayTrackInset: CGFloat = 5

    var body: some View {
        let tint = scoreTint(for: state)
        let progress = max(0, min(1, Double(state.overallScore) / 100.0))
        let (dayStart, dayEnd) = todayDayWindow()
        let inset: CGFloat = showDayTrack ? dayTrackInset : 0
        let arcWidth: CGFloat = showDayTrack ? 3 : 5

        ZStack {
            Circle()
                .fill(AppColour.surfaceOverlay.opacity(0.55))

            if showDayTrack {
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
            }

            // Score ring — band-coloured arc (greyed when stale). Bolder and at full
            // radius when the day track is hidden, so the expanded island reads as one
            // clean, prominent ring instead of two thin concentric strokes.
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: arcWidth)
                .padding(inset)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: arcWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(inset)

            VStack(spacing: 1) {
                Text("\(state.overallScore)")
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(TodayScoreCopy.scoreUnit)
                    .font(.system(size: max(7, size * 0.12), weight: .semibold))
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

// MARK: - Mode Pill (expanded leading)

/// Tint-tinted capsule with the mode glyph and headline — the HTML `.modepill`
/// (accent at ~18% background). Reuses `state.mode.symbolName` / `.headline` so
/// the eyebrow always matches the time-of-day mode driving the rest of the card.
private struct CoachModePill: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = bandColor(for: state)
        // Fixed point sizes (not Dynamic Type styles): the expanded island has a
        // hard 160 pt height cap and ignores `.dynamicTypeSize`, so scaling fonts
        // would grow the card past the cap and the system would clip the bottom
        // action row. Fixed sizes keep the card height constant at any text size.
        HStack(spacing: 6) {
            Image(systemName: state.mode.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(state.mode.headline)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(tint.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.mode.headline)
    }
}

// MARK: - Stamp (expanded trailing)

/// Small tertiary time stamp (HTML `.stamp`). Switches to the honest "Updated Nh
/// ago" phrase once the data is stale so an old reading never shows a fresh time.
private struct CoachStamp: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        Text(staleAgePhrase(state) ?? WidgetStyle.timeString(from: state.lastUpdated))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColour.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.trailing, 4)
    }
}

// MARK: - Expanded Card (the whole briefing, in the roomy bottom region)

/// The full score card — ring on the left, mode pill + insight + hairline 3-stat row
/// on the right, then a full-width action capsule beside the weakest-pillar chip. It
/// all lives in the bottom region because that is the only region clear of the camera
/// and wide enough to hold it without truncating any label.
private struct CoachExpandedCard: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = bandColor(for: state)
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 13) {
                CoachExpandedRing(state: state)
                VStack(alignment: .leading, spacing: 3) {
                    CoachModePill(state: state)
                    Text(state.insight)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    CoachStatRow(state: state)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 9) {
                CoachActionBar(kind: state.actionKind, tint: tint, fullWidth: true, fixedType: true)
                if let weakest = state.weakestPillarScore {
                    CoachWeakChip(pillar: state.weakestPillar, score: weakest)
                }
            }
        }
    }
}

// MARK: - Expanded Leading Ring

/// Score ring with its soft radial bloom for the expanded card. Single clean arc
/// (no day track) so it reads bold. RadialGradient bloom (widgets cannot render .blur).
private struct CoachExpandedRing: View {
    let state: TodayScoreActivityAttributes.ContentState

    var body: some View {
        let tint = bandColor(for: state)
        CoachOrbRing(state: state, size: 54, showDayTrack: false)
            .background {
                // Circle-clipped bloom (never a square), sized close to the ring.
                Circle()
                    .fill(RadialGradient(
                        colors: [tint.opacity(0.30), .clear],
                        center: .center, startRadius: 8, endRadius: 40
                    ))
                    .frame(width: 80, height: 80)
            }
    }
}

// MARK: - Stat Row (3 stats, hairline dividers)

/// Up to three supporting stats with thin vertical hairline rules between them
/// (HTML `.stat-row`). Each cell is a bold monospaced value + tiny unit over an
/// UPPERCASE caption. Stats are built ONLY from fields the ContentState actually
/// carries — missing optionals (HRV / resting HR) are dropped, never faked.
private struct CoachStatRow: View {
    let state: TodayScoreActivityAttributes.ContentState

    /// (value, unit?, caption) tuples. Order is mode-led: the day mode leads with
    /// the effort metric (Steps); recovery modes lead with HRV / resting HR.
    private var stats: [(value: String, unit: String?, caption: String)] {
        var out: [(String, String?, String)] = []
        switch state.mode {
        case .day:
            out.append((stepsDisplay(state.steps), nil, CoachMode.day.secondaryLabel))
            if let hr = state.restingHR { out.append(("\(hr)", TodayScoreCopy.bpmUnit, CoachMode.night.headline)) }
            if let hrv = state.hrvMs { out.append(("\(hrv)", TodayScoreCopy.msUnit, CoachMode.morning.secondaryLabel)) }
        case .morning, .evening, .night:
            if let hrv = state.hrvMs { out.append(("\(hrv)", TodayScoreCopy.msUnit, CoachMode.morning.secondaryLabel)) }
            if let hr = state.restingHR { out.append(("\(hr)", TodayScoreCopy.bpmUnit, CoachMode.night.headline)) }
            out.append((stepsDisplay(state.steps), nil, CoachMode.day.secondaryLabel))
        }
        return Array(out.prefix(3))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    // Hairline rule, inset top/bottom so it never spans full height.
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1)
                        .padding(.vertical, 3)
                }
                StatCell(value: stat.value, unit: stat.unit, caption: stat.caption)
                    .padding(.leading, index == 0 ? 0 : 10)
                    .padding(.trailing, index == stats.count - 1 ? 0 : 10)
            }
        }
    }

    private func stepsDisplay(_ steps: Int) -> String {
        if steps >= 10_000 {
            return String(format: "%.1fK", Double(steps) / 1_000)
        }
        return "\(steps)"
    }
}

private struct StatCell: View {
    let value: String
    let unit: String?
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppColour.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            Text(caption)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(AppColour.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Weakest-Pillar Chip

/// HTML `.chip-weak`: a soft pill with a fixed amber warning dot, the pillar
/// name, then the bold score. Dot is always `AppColour.warning` (#F59E0B) per
/// spec, independent of the score band tint.
private struct CoachWeakChip: View {
    let pillar: String
    let score: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AppColour.warning)
                .frame(width: 7, height: 7)
            Text(pillar)
                .foregroundStyle(AppColour.textSecondary)
            Text("\(score)")
                .foregroundStyle(AppColour.textPrimary)
                .monospacedDigit()
        }
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.white.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pillar) \(score)")
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
    /// Full-width capsule in the expanded island bottom region (matches the
    /// mockup's full-width action); content-hugging on the lock card right side.
    var fullWidth: Bool = false
    /// Fixed point size instead of a Dynamic Type style. The expanded island has a
    /// hard 160 pt cap and ignores `.dynamicTypeSize`, so the island passes `true`
    /// to keep its height constant; the lock-screen card leaves this `false` so its
    /// action still scales for accessibility.
    var fixedType: Bool = false

    private var labelFont: Font {
        fixedType ? .system(size: 13, weight: .semibold) : .footnote.weight(.semibold)
    }

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
                    .font(labelFont)
                Text(kind.label)
                    .font(labelFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: fullWidth ? .infinity : nil)
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

// MARK: - Xcode Previews (open this file, show the canvas to render the real output)

#if DEBUG
private func previewState(
    _ score: Int, _ tint: TodayScoreTint, _ mode: CoachMode,
    _ action: CoachActionKind, _ insight: String,
    weakest: String = "Mobility", weakestScore: Int? = 69, hrv: Int? = 53, ageHours: Double = 0
) -> TodayScoreActivityAttributes.ContentState {
    .init(
        overallScore: score, scoreTint: tint,
        weakestPillar: weakest, weakestPillarScore: weakestScore,
        steps: 6400, stepsGoal: 10000, hrvMs: hrv, restingHR: 57,
        lastUpdated: Date(timeIntervalSinceNow: -ageHours * 3600),
        mode: mode, heroValue: score, insight: insight, actionKind: action
    )
}

#Preview("Lock Screen", as: .content, using: TodayScoreActivityAttributes()) {
    TodayScoreLiveActivityWidget()
} contentStates: {
    previewState(78, .good, .morning, .setIntention, "HRV is high after deep sleep. Good day to push.")
    previewState(61, .fair, .evening, .windDown, "Sleep is your limiter today. Wind down a little earlier.", weakest: "Sleep", weakestScore: 48, hrv: 44)
    previewState(42, .poor, .morning, .breathe, "Low recovery. Keep it easy and breathe.", weakest: "HRV", weakestScore: 38, hrv: 38)
    previewState(75, .good, .morning, .noop, "Open Laso to refresh. This reading is from yesterday.", ageHours: 22)
}

#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: TodayScoreActivityAttributes()) {
    TodayScoreLiveActivityWidget()
} contentStates: {
    previewState(78, .good, .morning, .setIntention, "HRV is high after deep sleep. Good day to push.")
    previewState(42, .poor, .morning, .breathe, "Low recovery. Keep it easy and breathe.", weakest: "HRV", weakestScore: 38, hrv: 38)
}
#endif
