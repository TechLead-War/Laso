import SwiftUI

/// Simplified Cognitive Wellness detail. Hero score + 7-day chart + top 3 drivers +
/// key factors tell the story. Dream/deep sleep stats, mental energy, and long term
/// brain fitness live behind one Learn More disclosure so the main page stays calm.
struct BrainHealthDetailView: View {
    let brainScore: BrainHealthScore
    let weeklyHistory: [(date: Date, score: Int)]
    let weeklyAverage: Int?
    let trend: String

    @State private var showLearnMore = false

    var body: some View {
        GeometryReader { proxy in
            let sectionWidth = max(proxy.size.width - 32, 0)

            ScrollView {
                VStack(spacing: DS.sectionSpacing) {
                    heroSection.frame(width: sectionWidth)
                    weeklyChartSection.frame(width: sectionWidth)
                    readinessSection.frame(width: sectionWidth)
                    insightsSection.frame(width: sectionWidth)
                    learnMoreSection.frame(width: sectionWidth)
                    disclaimerSection.frame(width: sectionWidth, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, DS.space7)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationTitle(Copy.BrainHealth.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.brainHealth) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.brainHealth) }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Text("\(brainScore.score)")
                .font(DS.Typography.displayXL.monospacedDigit())
                .foregroundStyle(.primary)
                .postHogMask()

            Text(Copy.BrainHealth.brainHealthLabel)
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.secondary)

            // Static explainer. teaches the user what this screen is about
            Text(Copy.BrainHealth.heroExplainer)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space2)

            Text(brainScore.state.displayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(brainScore.state.color)

            // What this state means + what to do today
            Text(brainScore.headline)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if brainScore.confidence < 0.7 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2.weight(.bold))
                    Text(Copy.BrainHealth.learningPatterns)
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

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.lastSevenDays)
                .font(.headline)

            if weeklyHistory.isEmpty {
                Text("Not enough data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
            } else {
                let visibleHistory = Array(weeklyHistory.suffix(7))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(visibleHistory.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 4) {
                            Text("\(entry.score)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(chartBarColor(for: entry.score))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .postHogMask()

                            RoundedRectangle(cornerRadius: 4)
                                .fill(chartBarColor(for: entry.score))
                                .frame(height: max(chartBarHeight(for: entry.score), 4))

                            Text(abbreviatedDay(entry.date))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)

                HStack {
                    Text("0").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("100").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                }

                if let avg = weeklyAverage {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Avg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(avg)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .postHogMask()
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
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Readiness Drivers (Top 3)

    private var readinessSection: some View {
        let deepValue = brainScore.deepSleepScore.map { $0 / 100 }
        let remValue = brainScore.remSleepScore.map { $0 / 100 }

        return VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.sleepRecovery)
                .font(.headline)

            driverRow(
                label: Copy.BrainHealth.heartRecovery,
                icon: "waveform.path.ecg",
                value: brainScore.cognitiveReadiness / 100,
                color: readinessColor(brainScore.cognitiveReadiness / 100),
                isEstimate: false
            )

            driverRow(
                label: Copy.BrainHealth.deepSleep,
                icon: "moon.zzz.fill",
                value: deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9,
                color: readinessColor(deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9),
                isEstimate: deepValue == nil
            )

            driverRow(
                label: Copy.BrainHealth.remSleep,
                icon: "brain.fill",
                value: remValue ?? brainScore.memoryRecovery / 100,
                color: readinessColor(remValue ?? brainScore.memoryRecovery / 100),
                isEstimate: remValue == nil
            )
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func driverRow(label: String, icon: String, value: Double, color: Color, isEstimate: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        if isEstimate {
                            Text(Copy.BrainHealth.estimated)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(Int(min(max(value, 0), 1.0) * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                        .frame(minWidth: 40, alignment: .trailing)
                        .postHogMask()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readinessColor(_ value: Double) -> Color {
        if value >= 0.7 { return .green }
        if value >= 0.5 { return .yellow }
        if value >= 0.3 { return .orange }
        return .red
    }

    // MARK: - Key Factors

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.whatHelpedAndHurt)
                .font(.headline)

            ForEach(Array(brainScore.topFactors.prefix(3)), id: \.label) { factor in
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Learn More (collapses memory + mental energy + fitness)

    private var learnMoreSection: some View {
        DisclosureGroup(isExpanded: $showLearnMore) {
            VStack(alignment: .leading, spacing: 18) {
                memoryBlock
                stressLoadBlock
                fitnessBlock
            }
            .padding(.top, DS.space3)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(.gray.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.BrainHealth.learnMore)
                        .font(.subheadline.weight(.semibold))
                    Text(Copy.BrainHealth.learnMoreHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var memoryBlock: some View {
        let remDisplay = brainScore.remSleepScore ?? brainScore.memoryRecovery
        let deepDisplay = brainScore.deepSleepScore ?? brainScore.cognitiveReadiness * 0.9
        let hasSleepStages = brainScore.remSleepScore != nil || brainScore.deepSleepScore != nil

        return VStack(alignment: .leading, spacing: 10) {
            Text(Copy.BrainHealth.sleepAndMemory)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statBox(
                    label: brainScore.remSleepScore != nil ? Copy.BrainHealth.dreamSleep : "\(Copy.BrainHealth.dreamSleep) (Est.)",
                    value: "\(Int(remDisplay))%",
                    color: readinessColor(remDisplay / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                statBox(
                    label: brainScore.deepSleepScore != nil ? Copy.BrainHealth.deepSleep : "\(Copy.BrainHealth.deepSleep) (Est.)",
                    value: "\(Int(deepDisplay))%",
                    color: readinessColor(deepDisplay / 100)
                )
            }
            .frame(maxWidth: .infinity)

            Text(hasSleepStages ? Copy.BrainHealth.sleepBrainExplanation : Copy.BrainHealth.noSleepStageData)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stressLoadBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.BrainHealth.mentalEnergy)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(Int(brainScore.stressCognitionLoad))%")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(capacityColor)
                    .postHogMask()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(capacityColor)
                            .frame(
                                width: geo.size.width * min(max(brainScore.stressCognitionLoad / 100, 0), 1.0),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
            }

            Text(Copy.BrainHealth.mentalEnergyExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var capacityColor: Color {
        if brainScore.stressCognitionLoad >= 70 { return .green }
        if brainScore.stressCognitionLoad >= 50 { return .yellow }
        if brainScore.stressCognitionLoad >= 30 { return .orange }
        return .red
    }

    private var fitnessBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.BrainHealth.brainHealthOverTime)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statBox(
                    label: Copy.BrainHealth.heartAndBrain,
                    value: "\(Int(brainScore.neurovascularFitness))%",
                    color: readinessColor(brainScore.neurovascularFitness / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                statBox(
                    label: Copy.BrainHealth.sleepRhythm,
                    value: "\(Int(brainScore.circadianAlignment))%",
                    color: readinessColor(brainScore.circadianAlignment / 100)
                )
            }
            .frame(maxWidth: .infinity)

            Text(Copy.BrainHealth.longTermExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .postHogMask()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart Helpers

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

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Text(Copy.Analysis.RiskDetail.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, DS.space6)
            .padding(.bottom, DS.space4)
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
