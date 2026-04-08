import SwiftUI

struct BrainHealthDetailView: View {
    let brainScore: BrainHealthScore
    let weeklyHistory: [(date: Date, score: Int)]
    let weeklyAverage: Int?
    let trend: String // "improving", "stable", "declining"

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroSection
                readinessSection
                memorySection
                stressLoadSection
                fitnessSection
                weeklyChartSection
                insightsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Brain Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.brainHealth) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.brainHealth) }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Text("\(brainScore.score)")
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            Text("BRAIN HEALTH")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.secondary)

            Text(brainScore.state.displayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(brainScore.state.color)

            Text(brainScore.headline)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if brainScore.confidence < 0.7 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2.weight(.bold))
                    Text("Building your brain profile")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.1), in: Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(brainScore.state.color.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: brainScore.state.color.opacity(0.22), radius: 16, y: 8)
    }

    // MARK: - Cognitive Readiness

    private var readinessSection: some View {
        let deepValue = brainScore.deepSleepScore.map { $0 / 100 }
        let remValue = brainScore.remSleepScore.map { $0 / 100 }
        let durationValue = brainScore.sleepDurationScore.map { $0 / 100 }

        return VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Cognitive Recovery")
                .font(.headline)

            driverRow(
                label: "HRV Signal",
                icon: "waveform.path.ecg",
                value: brainScore.cognitiveReadiness / 100,
                color: readinessColor(brainScore.cognitiveReadiness / 100),
                isEstimate: false
            )

            driverRow(
                label: "Deep Sleep",
                icon: "moon.zzz.fill",
                value: deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9,
                color: readinessColor(deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9),
                isEstimate: deepValue == nil
            )

            driverRow(
                label: "REM Sleep",
                icon: "brain.fill",
                value: remValue ?? brainScore.memoryRecovery / 100,
                color: readinessColor(remValue ?? brainScore.memoryRecovery / 100),
                isEstimate: remValue == nil
            )

            driverRow(
                label: "Sleep Duration",
                icon: "bed.double.fill",
                value: durationValue ?? brainScore.circadianAlignment / 100,
                color: readinessColor(durationValue ?? brainScore.circadianAlignment / 100),
                isEstimate: durationValue == nil
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func driverRow(label: String, icon: String, value: Double, color: Color, isEstimate: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.subheadline.weight(.medium))

                    if isEstimate {
                        Text("Est.")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5), in: Capsule())
                    }

                    Spacer()

                    Text("\(Int(min(max(value, 0), 1.0) * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isEstimate ? color.opacity(0.5) : color)
                            .frame(width: geo.size.width * min(max(value, 0), 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func readinessColor(_ value: Double) -> Color {
        if value >= 0.7 { return .green }
        if value >= 0.5 { return .yellow }
        if value >= 0.3 { return .orange }
        return .red
    }

    // MARK: - Memory & Recovery

    private var memorySection: some View {
        let remDisplay = brainScore.remSleepScore ?? brainScore.memoryRecovery
        let deepDisplay = brainScore.deepSleepScore ?? brainScore.cognitiveReadiness * 0.9
        let hasSleepStages = brainScore.remSleepScore != nil || brainScore.deepSleepScore != nil

        return VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Memory & Recovery")
                .font(.headline)

            HStack(spacing: 16) {
                statBox(
                    label: brainScore.remSleepScore != nil ? "REM Quality" : "REM Quality (Est.)",
                    value: "\(Int(remDisplay))%",
                    color: readinessColor(remDisplay / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                statBox(
                    label: brainScore.deepSleepScore != nil ? "Deep Sleep" : "Deep Sleep (Est.)",
                    value: "\(Int(deepDisplay))%",
                    color: readinessColor(deepDisplay / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                trendIndicator
            }

            if !hasSleepStages {
                Text("Sleep stage data not available. Values are estimated from other signals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Deep sleep clears brain waste. REM consolidates memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendIndicator: some View {
        let isImproving = trend == "improving"
        let isDeclining = trend == "declining"
        let arrow = isImproving ? "arrow.up.right" : (isDeclining ? "arrow.down.right" : "minus")
        let color: Color = isImproving ? .green : (isDeclining ? .orange : .secondary)
        let label = trend.capitalized

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

    // MARK: - Stress-Cognition Load

    private var stressLoadSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Cognitive Capacity")
                .font(.headline)

            VStack(spacing: 8) {
                Text("\(Int(brainScore.stressCognitionLoad))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(capacityColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(capacityColor)
                            .frame(
                                width: geo.size.width * min(max(brainScore.stressCognitionLoad / 100, 0), 1.0),
                                height: 10
                            )
                    }
                }
                .frame(height: 10)

                Text("Available cognitive bandwidth after stress load")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var capacityColor: Color {
        if brainScore.stressCognitionLoad >= 70 { return .green }
        if brainScore.stressCognitionLoad >= 50 { return .yellow }
        if brainScore.stressCognitionLoad >= 30 { return .orange }
        return .red
    }

    // MARK: - Long-Term Brain Fitness

    private var fitnessSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Long-Term Brain Fitness")
                .font(.headline)

            HStack(spacing: 16) {
                statBox(
                    label: "Neurovascular",
                    value: "\(Int(brainScore.neurovascularFitness))%",
                    color: readinessColor(brainScore.neurovascularFitness / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                statBox(
                    label: "Circadian",
                    value: "\(Int(brainScore.circadianAlignment))%",
                    color: readinessColor(brainScore.circadianAlignment / 100)
                )
            }

            Text("Cardiovascular fitness and sleep regularity predict long-term brain health.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("7-Day Brain Health")
                .font(.headline)

            if weeklyHistory.isEmpty {
                Text("Not enough data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(weeklyHistory.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 4) {
                            Text("\(entry.score)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(chartBarColor(for: entry.score))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(chartBarColor(for: entry.score))
                                .frame(height: max(chartBarHeight(for: entry.score), 4))

                            Text(abbreviatedDay(entry.date))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)

                HStack {
                    Text("0")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("100")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }

                if let avg = weeklyAverage {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Avg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(avg)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: trendIcon)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(trendColor)
                            Text(trend.capitalized)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(trendColor)
                        }
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(trendColor.opacity(DS.badgeBg), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func chartBarHeight(for score: Int) -> CGFloat {
        CGFloat(min(max(Double(score) / 100.0, 0), 1.0)) * 80
    }

    private func chartBarColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 65 { return .blue }
        if score >= 45 { return .gray }
        return .orange
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private func abbreviatedDay(_ date: Date) -> String {
        String(Self.dayFormatter.string(from: date).prefix(3))
    }

    private var trendIcon: String {
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private var trendColor: Color {
        switch trend {
        case "improving": return .green
        case "declining": return .orange
        default: return .secondary
        }
    }

    // MARK: - Key Factors

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Key Factors")
                .font(.headline)

            ForEach(brainScore.topFactors, id: \.label) { factor in
                HStack(spacing: 10) {
                    Image(systemName: factor.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(factor.isPositive ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.label)
                            .font(.subheadline.weight(.medium))
                        Text(factor.impact)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BrainHealthDetailView(
            brainScore: BrainHealthScore(
                score: 78,
                state: .focused,
                cognitiveReadiness: 82,
                memoryRecovery: 71,
                stressCognitionLoad: 75,
                neurovascularFitness: 80,
                circadianAlignment: 68,
                deepSleepScore: 74,
                remSleepScore: 68,
                sleepDurationScore: 72,
                topFactors: [
                    (label: "REM Sleep", impact: "12% above baseline", isPositive: true),
                    (label: "HRV", impact: "Trending up this week", isPositive: true),
                    (label: "Sleep Regularity", impact: "Inconsistent bedtimes", isPositive: false)
                ],
                headline: "Good recovery signals from last night",
                confidence: 0.85
            ),
            weeklyHistory: [
                (date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, score: 72),
                (date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, score: 68),
                (date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, score: 75),
                (date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, score: 80),
                (date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, score: 77),
                (date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, score: 82),
                (date: Date(), score: 78)
            ],
            weeklyAverage: 76,
            trend: "improving"
        )
    }
}
