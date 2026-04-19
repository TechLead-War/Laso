import SwiftUI

/// Simplified Stress Monitor. Hero gauge + 7-day chart + one-line week summary + two
/// compact drivers + one primary tip + breathing CTA. Extra tips sit behind a single
/// Learn More disclosure.
struct StressMonitorView: View {
    let stressScore: Double
    let stressLevel: String
    let levelColor: Color
    let hrvDeviation: Double
    let hrElevation: Double
    let weeklyScores: [DailyStressPoint]
    let weeklyAverage: Double
    let previousWeekAverage: Double

    @State private var showMoreTips = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroGauge
                weeklyChartSection
                weekSummaryCard
                driverSection
                primaryTipCard
                moreTipsDisclosure
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
                arcSegment(from: 0, to: 1, color: Color(.systemGray5))
                arcSegment(from: 0, to: 0.25, color: .green)
                arcSegment(from: 0.25, to: 0.50, color: .yellow)
                arcSegment(from: 0.50, to: 0.75, color: .orange)
                arcSegment(from: 0.75, to: 1.0, color: .red)
                needleIndicator

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", stressScore))
                        .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                    Text(Copy.StressMonitor.ofScale)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .offset(y: 10)
            }
            .frame(height: 180)

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
            .fill(.primary)
            .frame(width: 10, height: 10)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .offset(y: -80)
            .rotationEffect(.degrees(angle))
    }

    private var scoreFraction: Double {
        min(max(stressScore / 3.0, 0), 1.0)
    }

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.sevenDayStress)
                .font(.headline)

            if weeklyScores.isEmpty {
                Text(Copy.StressMonitor.notEnoughData)
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
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                HStack {
                    Text("0").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("3.0").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Week Summary (one-line delta)

    private var weekSummaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: deltaIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(deltaColor.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(Copy.StressMonitor.weekSummaryTitle)
                    .font(.subheadline.weight(.semibold))
                Text(weekSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var weekSummaryText: String {
        let thisWeek = String(format: "%.1f", weeklyAverage)
        let lastWeek = String(format: "%.1f", previousWeekAverage)
        let diff = weeklyAverage - previousWeekAverage
        let prevBase = max(previousWeekAverage, 0.1)
        let percent = Int((abs(diff) / prevBase) * 100)

        if abs(diff) < 0.1 || percent < 3 {
            return Copy.StressMonitor.weekDeltaSteady(thisWeek)
        }
        if diff < 0 {
            return Copy.StressMonitor.weekDeltaImproved(thisWeek, lastWeek, percent)
        }
        return Copy.StressMonitor.weekDeltaIncreased(thisWeek, lastWeek, percent)
    }

    private var deltaIcon: String {
        let diff = weeklyAverage - previousWeekAverage
        if abs(diff) < 0.1 { return "equal.circle.fill" }
        return diff < 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill"
    }

    private var deltaColor: Color {
        let diff = weeklyAverage - previousWeekAverage
        if abs(diff) < 0.1 { return .gray }
        return diff < 0 ? .green : .orange
    }

    // MARK: - Drivers

    private var driverSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.StressMonitor.whatsDrivingStress)
                .font(.headline)

            driverRow(
                label: Copy.StressMonitor.hrvDeviation,
                icon: "waveform.path.ecg",
                value: hrvDeviation,
                color: driverColor(hrvDeviation)
            )

            driverRow(
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

    // MARK: - Primary Tip

    private var primaryTipCard: some View {
        let tip = tipsForLevel.first ?? ""
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: tipIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(levelColor.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(Copy.StressMonitor.primaryTip)
                    .font(.subheadline.weight(.semibold))
                Text(tip)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: levelColor)
    }

    // MARK: - More Tips Disclosure

    @ViewBuilder
    private var moreTipsDisclosure: some View {
        if tipsForLevel.count > 1 {
            DisclosureGroup(isExpanded: $showMoreTips) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(tipsForLevel.dropFirst()), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(levelColor)
                                .padding(.top, 7)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.gray.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.StressMonitor.moreTips)
                            .font(.subheadline.weight(.semibold))
                        Text(Copy.StressMonitor.moreTipsHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
    }

    private var tipsForLevel: [String] {
        switch stressLevel.lowercased() {
        case "low":
            return [
                "Your body is calm. Great time for challenging work.",
                "Maintain this state with regular sleep and hydration.",
                "Consider a creative or deep focus task right now."
            ]
        case "mild":
            return [
                "Try a 5 minute breathing exercise.",
                "Step outside for fresh air if possible.",
                "A short walk can help reset your nervous system."
            ]
        case "moderate":
            return [
                "Consider a walk or gentle stretching.",
                "Limiting caffeine for the next few hours may help.",
                "Try progressive muscle relaxation.",
                "Shorten your to do list and focus on essentials."
            ]
        case "high":
            return [
                "Your body is signaling for rest. Lighter activity may serve you better right now.",
                "Box breathing can help. Inhale 4s, hold 4s, exhale 4s, hold 4s.",
                "A quieter, screen free environment may help your nervous system settle.",
                "Many people find that 8 plus hours of sleep tonight helps them feel more resilient tomorrow."
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
