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

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroGauge
                driverSection
                weeklyChartSection
                weeklyComparison
                tipsSection
                breathingCTA
            }
            .padding(.horizontal)
            .padding(.bottom, DS.space7)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Copy.StressMonitor.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.stressMonitor)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.stressMonitor)
        }
    }

    // MARK: - Hero Gauge

    private var heroGauge: some View {
        VStack(spacing: 12) {
            // Static explainer. teaches the user what this screen is about
            Text(Copy.StressMonitor.heroExplainer)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ZStack {
                // Background arc
                arcSegment(from: 0, to: 1, color: Color(.systemGray5))

                // Colored arc segments
                arcSegment(from: 0, to: 0.25, color: .green)
                arcSegment(from: 0.25, to: 0.50, color: .yellow)
                arcSegment(from: 0.50, to: 0.75, color: .orange)
                arcSegment(from: 0.75, to: 1.0, color: .red)

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
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(levelColor)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(width: 130)
                .offset(y: 14)
            }
            .frame(height: 180)

            Text(Copy.StressMonitor.scaleAndDirection)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)

            // Context line. what this state means + what to do. Full width, no truncation.
            Text(contextSubtitle)
                .font(.subheadline)
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
        Circle()
            .trim(from: startFraction * 240 / 360 + 150 / 360,
                  to: endFraction * 240 / 360 + 150 / 360)
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .frame(width: 160, height: 160)
            .rotationEffect(.degrees(0))
            .opacity(scoreFraction >= startFraction ? 1.0 : 0.3)
    }

    private var needleIndicator: some View {
        let angle = 150 + scoreFraction * 240

        return Circle()
            .fill(.primary)
            .frame(width: 10, height: 10)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .offset(y: -80)
            .rotationEffect(.degrees(angle))
    }

    private var scoreFraction: Double {
        min(max(stressScore / 3.0, 0), 1.0)
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
                .font(.headline)

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
        if value < 0.3 { return .green }
        if value < 0.6 { return .yellow }
        if value < 0.8 { return .orange }
        return .red
    }

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.sevenDayStress)
                .font(.headline)

            if weeklyScores.isEmpty {
                Text(Copy.Common.notEnoughData)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
            } else {
                WeeklyBarChart(
                    points: weeklyScores,
                    value: { min(max($0.score / 3.0, 0), 1.0) },
                    color: { barColor(for: $0.score) },
                    label: { $0.dayLabel }
                )

                // Scale labels
                HStack {
                    Text(Copy.StressMonitor.scaleLow)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(Copy.StressMonitor.scaleHigh)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func barColor(for score: Double) -> Color {
        if score < 0.75 { return .green }
        if score < 1.5 { return .yellow }
        if score < 2.25 { return .orange }
        return .red
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
        let color: Color = improved ? .green : .red
        let label = improved ? Copy.Common.improved : Copy.Common.increased

        return VStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.body.weight(.bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.reduceStress)
                .font(.headline)

            ForEach(tipsForLevel, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tipIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(levelColor)
                        .frame(width: 20, height: 20)
                        .background(levelColor.opacity(DS.badgeBg), in: Circle())

                    Text(tip)
                        .font(.subheadline)
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
                    .font(.body.weight(.semibold))

                Text(Copy.StressMonitor.startBreathingExercise)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(.teal, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .shadow(color: .teal.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
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
