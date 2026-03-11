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
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Stress Monitor")
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

                // Center score
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", stressScore))
                        .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())

                    Text("of 3.0")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .offset(y: 10)
            }
            .frame(height: 180)

            // Level badge
            Text(stressLevel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(levelColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(levelColor.opacity(DS.badgeBg), in: Capsule())
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
            .fill(.white)
            .frame(width: 10, height: 10)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .offset(y: -80)
            .rotationEffect(.degrees(angle))
    }

    private var scoreFraction: Double {
        min(max(stressScore / 3.0, 0), 1.0)
    }

    // MARK: - Stress Drivers

    private var driverSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("What's Driving Your Stress")
                .font(.headline)

            driverRow(
                label: "HRV Deviation",
                icon: "waveform.path.ecg",
                value: hrvDeviation,
                color: driverColor(hrvDeviation)
            )

            driverRow(
                label: "HR Elevation",
                icon: "heart.fill",
                value: hrElevation,
                color: driverColor(hrElevation)
            )
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func driverRow(label: String, icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(Int(value * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geo.size.width * min(max(value, 0), 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
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
            Text("7-Day Stress")
                .font(.headline)

            if weeklyScores.isEmpty {
                Text("Not enough data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(weeklyScores) { point in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: point.score))
                                .frame(height: max(barHeight(for: point.score), 4))

                            Text(point.dayLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                // Scale labels
                HStack {
                    Text("0")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("3.0")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func barHeight(for score: Double) -> CGFloat {
        CGFloat(min(max(score / 3.0, 0), 1.0)) * 80
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
            comparisonStat(
                label: "This Week",
                value: weeklyAverage,
                isPrimary: true
            )

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(.separator))
                .frame(width: 1, height: DS.dividerHeight)

            comparisonStat(
                label: "Last Week",
                value: previousWeekAverage,
                isPrimary: false
            )

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(.separator))
                .frame(width: 1, height: DS.dividerHeight)

            weeklyDelta
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func comparisonStat(label: String, value: Double, isPrimary: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(String(format: "%.1f", value))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(isPrimary ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyDelta: some View {
        let diff = weeklyAverage - previousWeekAverage
        let improved = diff <= 0
        let arrow = improved ? "arrow.down.right" : "arrow.up.right"
        let color: Color = improved ? .green : .red
        let label = improved ? "Improved" : "Increased"

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
            Text("Reduce Stress")
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
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var tipsForLevel: [String] {
        switch stressLevel.lowercased() {
        case "low":
            return [
                "Your body is calm. Great time for challenging work.",
                "Maintain this state with regular sleep and hydration.",
                "Consider a creative or deep-focus task right now."
            ]
        case "mild":
            return [
                "Try a 5-minute breathing exercise.",
                "Step outside for fresh air if possible.",
                "A short walk can help reset your nervous system."
            ]
        case "moderate":
            return [
                "Consider a walk or gentle stretching.",
                "Avoid caffeine and stimulants for the next few hours.",
                "Try progressive muscle relaxation.",
                "Shorten your to-do list and focus on essentials."
            ]
        case "high":
            return [
                "Your body needs rest. Postpone intense activity.",
                "Practice box breathing: inhale 4s, hold 4s, exhale 4s, hold 4s.",
                "Avoid screens and find a quiet environment.",
                "Prioritize sleep tonight — aim for 8+ hours."
            ]
        default:
            return [
                "Monitor your stress throughout the day.",
                "Regular breaks can help manage stress levels."
            ]
        }
    }

    private var tipIcon: String {
        switch stressLevel.lowercased() {
        case "low": return "checkmark"
        case "mild": return "wind"
        case "moderate": return "figure.walk"
        case "high": return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }

    // MARK: - Breathing CTA

    private var breathingCTA: some View {
        NavigationLink {
            BreathworkView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lungs.fill")
                    .font(.body.weight(.semibold))

                Text("Start Breathing Exercise")
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(.teal, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .shadow(color: .teal.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start breathing exercise")
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
