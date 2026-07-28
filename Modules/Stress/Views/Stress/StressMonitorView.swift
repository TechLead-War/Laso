import SwiftUI

/// Full Stress Monitor detail view showing gauge, drivers, 7-day history, and tips.
struct StressMonitorView: View {
    let stressScore: Double
    let stressLevel: String
    let levelColor: Color
    let hrvDeviation: Double // 0.0–1.0 fraction showing HRV departure from baseline
    let hrElevation: Double  // 0.0–1.0 fraction showing HR elevation above baseline
    let weeklyScores: [DailyStressPoint]
    let weeklyAverage: Double
    let previousWeekAverage: Double
    /// Longer daily history behind the trend card, oldest first.
    let trendPoints: [TrendSparkPoint]

    /// True only when we actually have signal: drivers above zero, OR a non-
    /// trivial gauge reading, OR any meaningful weekly history. All-zero across
    /// these means baselines never built — render an honest empty state
    /// instead of "0.0 Calm / Your body feels relaxed".
    private var hasData: Bool {
        if stressScore > 0.01 { return true }
        if hrvDeviation > 0.01 { return true }
        if hrElevation > 0.01 { return true }
        if weeklyScores.contains(where: { $0.score > 0.01 }) { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                if hasData {
                    // One spine, same order on every detail screen: the score,
                    // the two numbers it is built from, one plain sentence, the
                    // shape of the period, then the comparison. Actions come
                    // after understanding, never before it.
                    heroGauge
                    driverTiles
                    readingSentence
                    weeklyChartSection
                    weeklyComparison
                    if trendPoints.count >= TrendSparkCard.minimumPoints {
                        trendsSection
                    }
                    tipsSection
                    breathingCTA
                } else {
                    emptyStateSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, DS.space7)
        }
        .background(AppColour.surfaceBase)
        .navigationTitle(Copy.StressMonitor.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.stressMonitor)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.stressMonitor)
        }
    }

    /// Honest empty state shown when no HRV/HR baseline has formed yet
    /// (typically requires 14 days of HRV samples). Replaces the previous
    /// silent "0.0 Calm / Your body feels relaxed" fallback.
    private var emptyStateSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.top, DS.space3)

            Text(Copy.StressMonitor.buildingBaselineTitle)
                .font(DS.Typography.title3.weight(.semibold))

            Text(Copy.StressMonitor.needHRVData)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.space4)
                .padding(.bottom, DS.space4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space4)
        .cardStyle()
    }

    // MARK: - Hero Gauge

    private var heroGauge: some View {
        VStack(spacing: 12) {
            // Static explainer. teaches the user what this screen is about
            Text(Copy.StressMonitor.heroExplainer)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ZStack {
                // Background arc
                arcSegment(from: 0, to: 1, color: Color(.systemGray5))

                // Colored arc segments
                arcSegment(from: 0, to: 0.25, color: AppColour.success)
                arcSegment(from: 0.25, to: 0.50, color: AppColour.warning)
                arcSegment(from: 0.50, to: 0.75, color: AppColour.scoreFair)
                arcSegment(from: 0.75, to: 1.0, color: AppColour.danger)

                // Needle indicator
                needleIndicator

                // Center: numeric value + level label. Context pulled out below for full width.
                VStack(spacing: 2) {
                    Text("\(Int(stressScore.rounded()))")
                        .font(DS.Typography.displayM)
                        .foregroundStyle(levelTint)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .postHogMask()

                    Text(displayLevel)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(levelTint)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(width: 130)
                .offset(y: 14)
            }
            .frame(height: 180)

            Text(Copy.StressMonitor.scaleAndDirection)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: levelTint)
    }

    // MARK: - Reading Sentence

    /// The only prose on the screen. Everything else is a number with a label,
    /// so a person can scan the page and still land on one plain takeaway.
    private var readingSentence: some View {
        Text(contextSubtitle)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.cardPadding)
            .cardStyle()
    }

    private func arcSegment(from startFraction: Double, to endFraction: Double, color: Color) -> some View {
        // 240° gauge arc anchored at 8 o'clock (150°) sweeping clockwise through 12 to 4 o'clock (390°).
        // Drawn with Path.addArc so the endpoints stay in degree space and never overflow trim's [0,1].
        let arcStart: Double = 150
        let arcSpan: Double = 240
        let lineWidth: CGFloat = 14
        let diameter: CGFloat = 160

        return Path { path in
            let radius = (diameter - lineWidth) / 2
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(arcStart + startFraction * arcSpan),
                endAngle: .degrees(arcStart + endFraction * arcSpan),
                clockwise: false
            )
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .frame(width: diameter, height: diameter)
        .opacity(scoreFraction >= startFraction ? 1.0 : 0.3)
    }

    private var needleIndicator: some View {
        // Aligns the needle with the 240° arc above: 0.0 score → 8 o'clock (calm end),
        // 1.0 → 4 o'clock (high-stress end), passing through 12 o'clock at the midpoint.
        let angle = 240 + scoreFraction * 240

        return Circle()
            .fill(AppColour.textPrimary)
            .frame(width: 10, height: 10)
            .shadow(color: AppColour.shadowAmbient, radius: 2, y: 1)
            .offset(y: -80)
            .rotationEffect(.degrees(angle))
    }

    private var scoreFraction: Double {
        StressScale.position(for: stressScore)
    }

    /// The average line is worth drawing only when it rounds to something a
    /// person can read. Below that it is a line labelled zero.
    private var showsWeeklyAverage: Bool {
        Int(weeklyAverage.rounded()) >= 1
    }

    private var normalizedLevel: String {
        stressLevel.lowercased()
    }

    private var displayLevel: String {
        if normalizedLevel.contains("high") { return Copy.StressMonitor.levelHigh }
        if normalizedLevel.contains("moderate") { return Copy.StressMonitor.levelElevated }
        if normalizedLevel.contains("mild") { return Copy.StressMonitor.levelMild }
        if normalizedLevel.contains("low") { return Copy.StressMonitor.levelCalm }
        return stressLevel
    }

    private var contextSubtitle: String {
        if normalizedLevel.contains("high") { return Copy.StressMonitor.contextHigh }
        if normalizedLevel.contains("moderate") { return Copy.StressMonitor.contextModerate }
        if normalizedLevel.contains("mild") { return Copy.StressMonitor.contextMild }
        if normalizedLevel.contains("low") { return Copy.StressMonitor.contextLow }
        return Copy.StressMonitor.contextDefault
    }

    // MARK: - Stress Drivers

    /// The two readings the score is built from, side by side under the dial.
    /// A bar filling to an unlabelled end never said how far from normal the
    /// reading actually was; a percentage of the person's own baseline does.
    private var driverTiles: some View {
        HStack(spacing: DS.itemSpacing) {
            driverTile(
                label: Copy.StressMonitor.hrvDeviation,
                icon: "waveform.path.ecg",
                fraction: hrvDeviation
            )
            driverTile(
                label: Copy.StressMonitor.hrElevation,
                icon: "heart.fill",
                fraction: hrElevation
            )
        }
    }

    private func driverTile(label: String, icon: String, fraction: Double) -> some View {
        let tint = driverColor(fraction)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(DS.Typography.caption)
                    .foregroundStyle(tint)
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(Copy.StressMonitor.driverOffUsual(Int((fraction * 100).rounded())))
                .font(DS.Typography.title3)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .postHogMask()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func driverColor(_ value: Double) -> Color {
        if value < 0.3 { return AppColour.success }
        if value < 0.6 { return AppColour.warning }
        if value < 0.8 { return AppColour.scoreFair }
        return AppColour.danger
    }

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.sevenDayStress)
                .font(DS.Typography.headline)

            if weeklyScores.isEmpty {
                Text(Copy.Common.notEnoughData)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
            } else {
                WeeklyBarChart(
                    points: weeklyScores,
                    value: { StressScale.barFill(for: $0.score) },
                    color: { tint(for: $0.score) },
                    label: { $0.dayLabel },
                    tooltipLines: { point in
                        [
                            point.dayLabel,
                            "\(Int(point.score.rounded())) \(Copy.StressMonitor.scaleSuffix(max: Int(StressScale.maxScore)))"
                        ]
                    },
                    tooltipColor: { tint(for: $0.score) },
                    // The person's own weekly average, so a bar can be read as
                    // high or low for them rather than against nothing. Drawn
                    // only once it rounds to a real value: a line captioned
                    // "Your average 0" is the same empty claim the rest of this
                    // screen was cleaned up to avoid.
                    referenceFraction: showsWeeklyAverage ? StressScale.position(for: weeklyAverage) : nil,
                    referenceLabel: showsWeeklyAverage ? Copy.StressMonitor.yourAverage(Int(weeklyAverage.rounded())) : nil
                )

                // Scale labels
                HStack {
                    Text(Copy.StressMonitor.scaleLow)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(Copy.StressMonitor.scaleHigh)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    /// The gauge numeral, card tint, tips glyphs and trend card all take this.
    private var levelTint: Color { tint(for: stressScore) }

    /// Bars take their colour from the same level the gauge uses. A second copy of
    /// the thresholds lived here and was missed when the scale changed, so every bar
    /// read as high stress while the gauge said calm.
    ///
    /// The ramp is the same one the gauge arc and the driver tiles already use.
    /// `StressLevel.color` is a raw system hue and is unreadable on a light card.
    private func tint(for score: Double) -> Color {
        switch StressLevel(score: score) {
        case .low:      return AppColour.success
        case .mild:     return AppColour.warning
        case .moderate: return AppColour.scoreFair
        case .high:     return AppColour.danger
        }
    }

    // MARK: - Trends

    private var trendsSection: some View {
        TrendSection {
            TrendSparkCard(
                icon: "gauge.with.dots.needle.33percent",
                title: Copy.StressMonitor.trendCardTitle,
                value: "\(Int(stressScore.rounded()))",
                points: trendPoints,
                band: PersonalBand.make(from: trendPoints.map(\.value)),
                tint: levelTint
            )
        }
    }

    // MARK: - Weekly Comparison

    private var weeklyComparison: some View {
        HStack(spacing: 16) {
            StatBoxView(
                label: Copy.Common.thisWeek,
                value: "\(Int(weeklyAverage.rounded()))",
                color: .primary,
                suffix: Copy.StressMonitor.scaleSuffix(max: Int(StressScale.maxScore))
            )

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(.separator))
                .frame(width: 1, height: DS.dividerHeight)

            StatBoxView(
                label: Copy.Common.lastWeek,
                value: "\(Int(previousWeekAverage.rounded()))",
                color: .secondary,
                suffix: Copy.StressMonitor.scaleSuffix(max: Int(StressScale.maxScore))
            )

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(.separator))
                .frame(width: 1, height: DS.dividerHeight)

            weeklyDelta
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var weeklyDelta: some View {
        let diff = weeklyAverage - previousWeekAverage
        let improved = diff <= 0
        let arrow = improved ? "arrow.down.right" : "arrow.up.right"
        let color: Color = improved ? AppColour.success : AppColour.danger
        let label = improved ? Copy.Common.improved : Copy.Common.increased

        return VStack(spacing: 4) {
            Image(systemName: arrow)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(color)

            Text(label)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.reduceStress)
                .font(DS.Typography.headline)

            ForEach(tipsForLevel, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tipIcon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(levelTint)
                        .frame(width: 20, height: 20)
                        .background(levelTint.opacity(DS.badgeBg), in: Circle())

                    Text(tip)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var tipsForLevel: [String] {
        if normalizedLevel.contains("high") { return Copy.StressMonitor.tipsHigh }
        if normalizedLevel.contains("moderate") { return Copy.StressMonitor.tipsModerate }
        if normalizedLevel.contains("mild") { return Copy.StressMonitor.tipsMild }
        if normalizedLevel.contains("low") { return Copy.StressMonitor.tipsLow }
        return Copy.StressMonitor.tipsDefault
    }

    private var tipIcon: String {
        if normalizedLevel.contains("high") { return "exclamationmark.triangle" }
        if normalizedLevel.contains("moderate") { return "figure.walk" }
        if normalizedLevel.contains("mild") { return "wind" }
        if normalizedLevel.contains("low") { return "checkmark" }
        return "lightbulb"
    }

    // MARK: - Breathing CTA

    private var breathingCTA: some View {
        NavigationLink {
            BreathworkView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lungs.fill")
                    .font(DS.Typography.bodySemibold)

                Text(Copy.StressMonitor.startBreathingExercise)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space4)
            .foregroundStyle(AppColour.textOnAccent)
            .background(AppColour.accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .shadow(color: AppColour.shadowAmbient, radius: 8, y: 4)
        }
        .buttonStyle(.dsPress)
        .accessibilityLabel(Copy.StressMonitor.startBreathingA11y)
        .simultaneousGesture(TapGesture().onEnded {
            AppAnalytics.shared.trackBlockTap(
                title: "Start Breathing Exercise",
                type: .smartAction,
                screen: .stressMonitor,
                metadata: [
                    "source": "stress_monitor_cta",
                    "destination": "breathwork",
                    "stress_level": normalizedLevel
                ]
            )
        })
    }
}

// MARK: - Daily Stress Point

struct DailyStressPoint: Identifiable {
    // The caller rebuilds this array inside a @ViewBuilder on every parent
    // re-render, so a fresh UUID here would drop WeeklyBarChart's selected bar
    // and its tooltip. Keyed on the day itself, not on `dayLabel`: the scorer
    // skips any day it cannot score, so the last seven scored days can span
    // more than a week and repeat a weekday abbreviation.
    var id: Date { date }
    let date: Date
    let dayLabel: String
    let score: Double
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StressMonitorView(
            stressScore: 40,
            stressLevel: "Mild",
            levelColor: .yellow,
            hrvDeviation: 0.35,
            hrElevation: 0.22,
            weeklyScores: [
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -6, to: .now)!, dayLabel: "Mon", score: 27),
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -5, to: .now)!, dayLabel: "Tue", score: 37),
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -4, to: .now)!, dayLabel: "Wed", score: 50),
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -3, to: .now)!, dayLabel: "Thu", score: 40),
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -2, to: .now)!, dayLabel: "Fri", score: 30),
                DailyStressPoint(date: Date.cal.date(byAdding: .day, value: -1, to: .now)!, dayLabel: "Sat", score: 20),
                DailyStressPoint(date: .now, dayLabel: "Sun", score: 40)
            ],
            weeklyAverage: 35,
            previousWeekAverage: 44,
            trendPoints: (0..<30).reversed().map { offset in
                TrendSparkPoint(
                    date: Date.cal.date(byAdding: .day, value: -offset, to: .now)!,
                    value: 30 + Double((offset * 7) % 25)
                )
            }
        )
    }
}
