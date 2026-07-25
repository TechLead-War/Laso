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
                    heroGauge
                    driverSection
                    weeklyChartSection
                    weeklyComparison
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
                    Text(String(format: "%.1f", stressScore))
                        .font(DS.Typography.displayM)
                        .foregroundStyle(levelColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .postHogMask()

                    Text(displayLevel)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(levelColor)
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

            // Context line. what this state means + what to do. Full width, no truncation.
            Text(contextSubtitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.space2)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: levelColor)
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
            .fill(.primary)
            .frame(width: 10, height: 10)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .offset(y: -80)
            .rotationEffect(.degrees(angle))
    }

    private var scoreFraction: Double {
        StressScale.position(for: stressScore)
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

    private var driverSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.whatsDrivingStress)
                .font(DS.Typography.headline)

            DriverRowView(
                label: Copy.StressMonitor.hrvDeviation,
                icon: "waveform.path.ecg",
                value: hrvDeviation,
                color: driverColor(hrvDeviation)
            )

            DriverRowView(
                label: Copy.StressMonitor.hrElevation,
                icon: "heart.fill",
                value: hrElevation,
                color: driverColor(hrElevation)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
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
                    color: { barColor(for: $0.score) },
                    label: { $0.dayLabel },
                    tooltipLines: { point in
                        [
                            point.dayLabel,
                            "\(String(format: "%.1f", point.score)) \(Copy.StressMonitor.scaleSuffix)"
                        ]
                    },
                    tooltipColor: { barColor(for: $0.score) }
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

    private func barColor(for score: Double) -> Color {
        if score < 0.75 { return AppColour.success }
        if score < 1.5 { return AppColour.warning }
        if score < 2.25 { return AppColour.scoreFair }
        return AppColour.danger
    }

    // MARK: - Weekly Comparison

    private var weeklyComparison: some View {
        HStack(spacing: 16) {
            StatBoxView(
                label: Copy.Common.thisWeek,
                value: String(format: "%.1f", weeklyAverage),
                color: .primary,
                suffix: Copy.StressMonitor.scaleSuffix
            )

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(.separator))
                .frame(width: 1, height: DS.dividerHeight)

            StatBoxView(
                label: Copy.Common.lastWeek,
                value: String(format: "%.1f", previousWeekAverage),
                color: .secondary,
                suffix: Copy.StressMonitor.scaleSuffix
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
                        .foregroundStyle(levelColor)
                        .frame(width: 20, height: 20)
                        .background(levelColor.opacity(DS.badgeBg), in: Circle())

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
            .foregroundStyle(.white)
            .background(AppColour.accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .shadow(color: AppColour.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.dsPress)
        .accessibilityLabel(Copy.StressMonitor.startBreathingA11y)
    }
}

// MARK: - Daily Stress Point

struct DailyStressPoint: Identifiable {
    let id = UUID()
    let dayLabel: String
    let score: Double
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StressMonitorView(
            stressScore: 1.2,
            stressLevel: "Mild",
            levelColor: .yellow,
            hrvDeviation: 0.35,
            hrElevation: 0.22,
            weeklyScores: [
                DailyStressPoint(dayLabel: "Mon", score: 0.8),
                DailyStressPoint(dayLabel: "Tue", score: 1.1),
                DailyStressPoint(dayLabel: "Wed", score: 1.5),
                DailyStressPoint(dayLabel: "Thu", score: 1.2),
                DailyStressPoint(dayLabel: "Fri", score: 0.9),
                DailyStressPoint(dayLabel: "Sat", score: 0.6),
                DailyStressPoint(dayLabel: "Sun", score: 1.2)
            ],
            weeklyAverage: 1.04,
            previousWeekAverage: 1.32
        )
    }
}
