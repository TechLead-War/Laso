import SwiftUI

/// Simplified Cognitive Wellness detail. Hero score + 7-day chart + top 3 drivers +
/// key factors tell the story. Dream/deep sleep stats, mental energy, and long term
/// brain fitness live behind one Learn More disclosure so the main page stays calm.
struct BrainHealthDetailView: View {
    let brainScore: BrainHealthScore
    let weeklyHistory: [(date: Date, score: Int)]
    let weeklyAverage: Int?
    let trend: String
    /// Pass 8 V (F45): freshness timestamp from the parent dashboard refresh.
    /// Drives a small "Updated …" caption at the top of the screen.
    var lastUpdated: Date? = nil

    @State private var showLearnMore = false

    var body: some View {
        GeometryReader { proxy in
            let sectionWidth = max(proxy.size.width - 32, 0)

            ScrollView {
                VStack(spacing: DS.sectionSpacing) {
                    if let lastUpdated, let caption = Copy.Common.relativeUpdated(lastUpdated) {
                        Text(caption)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: sectionWidth)
                    }
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
            .background(AppColour.surfaceBase.ignoresSafeArea())
        }
        .navigationTitle(Copy.BrainHealth.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.brainHealth) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.brainHealth) }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DS.itemSpacing) {
            Text("\(brainScore.score)")
                .font(DS.Typography.displayXL.monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .postHogMask()

            Text(Copy.BrainHealth.scaleAndDirection)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(AppColour.textTertiary)

            Text(Copy.BrainHealth.brainHealthLabel)
                .font(DS.Typography.captionSemibold)
                .tracking(2)
                .foregroundStyle(AppColour.textSecondary)

            // Static explainer. teaches the user what this screen is about
            Text(Copy.BrainHealth.heroExplainer)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(AppColour.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space2)

            Text(brainScore.state.displayName)
                .font(DS.Typography.title3.weight(.bold))
                .foregroundStyle(brainScore.state.color)

            // What this state means + what to do today
            Text(brainScore.headline)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if brainScore.confidence < 0.7 {
                HStack(spacing: DS.space1) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(DS.Typography.caption2.weight(.bold))
                    Text(Copy.BrainHealth.learningPatterns)
                        .font(DS.Typography.captionSemibold)
                }
                .foregroundStyle(AppColour.textTertiary)
                .padding(.horizontal, DS.itemSpacing)
                .padding(.vertical, DS.space2)
                .background(AppColour.textSecondary.opacity(0.1), in: Capsule())
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(brainScore.state.color.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: brainScore.state.color.opacity(0.22), radius: 16, y: 8)
    }

    // MARK: - 7-Day Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.lastSevenDays)
                .font(DS.Typography.headline)

            if weeklyHistory.isEmpty {
                Text(Copy.Common.notEnoughData)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
            } else {
                let visibleHistory = Array(weeklyHistory.suffix(7)).map { BrainWeeklyPoint(date: $0.date, score: $0.score) }
                WeeklyBarChart(
                    points: visibleHistory,
                    value: { Double($0.score) / 100.0 },
                    color: { chartBarColor(for: $0.score) },
                    label: { abbreviatedDay($0.date) },
                    topLabel: { "\($0.score)" },
                    tooltipLines: { point in
                        [
                            point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                            "\(point.score) \(Copy.BrainHealth.scaleSuffix)"
                        ]
                    },
                    tooltipColor: { chartBarColor(for: $0.score) }
                )

                HStack {
                    Text("0").font(DS.Typography.caption2Medium).foregroundStyle(AppColour.textTertiary)
                    Spacer()
                    Text("100").font(DS.Typography.caption2Medium).foregroundStyle(AppColour.textTertiary)
                }

                if let avg = weeklyAverage {
                    HStack(spacing: DS.space4) {
                        HStack(spacing: DS.space1) {
                            Text(Copy.Common.avg)
                                .font(DS.Typography.caption2Medium)
                                .foregroundStyle(AppColour.textSecondary)
                            HStack(spacing: DS.space1) {
                                Text("\(avg)")
                                    .font(DS.Typography.caption.weight(.bold).monospacedDigit())
                                    .postHogMask()
                                Text(Copy.BrainHealth.scaleSuffix)
                                    .font(DS.Typography.caption2Medium.monospacedDigit())
                                    .foregroundStyle(AppColour.textSecondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: DS.space1) {
                            Image(systemName: trendIcon)
                                .font(DS.Typography.caption2.weight(.bold))
                                .foregroundStyle(trendColor)
                            Text(trend.capitalized)
                                .font(DS.Typography.caption2Medium)
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
                .font(DS.Typography.headline)

            DriverRowView(
                label: Copy.BrainHealth.heartRecovery,
                icon: "waveform.path.ecg",
                value: brainScore.cognitiveReadiness / 100,
                color: readinessColor(brainScore.cognitiveReadiness / 100),
                isEstimate: false
            )

            DriverRowView(
                label: Copy.BrainHealth.deepSleep,
                icon: "moon.zzz.fill",
                value: deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9,
                color: readinessColor(deepValue ?? brainScore.cognitiveReadiness / 100 * 0.9),
                isEstimate: deepValue == nil
            )

            DriverRowView(
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

    private func readinessColor(_ value: Double) -> Color {
        if value >= 0.7 { return AppColour.success }
        if value >= 0.5 { return AppColour.warning }
        if value >= 0.3 { return AppColour.warning }
        return AppColour.danger
    }

    // MARK: - Key Factors

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.whatHelpedAndHurt)
                .font(DS.Typography.headline)

            ForEach(Array(brainScore.topFactors.prefix(3)), id: \.label) { factor in
                HStack(spacing: DS.itemSpacing) {
                    Image(systemName: factor.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(factor.isPositive ? AppColour.success : AppColour.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.label)
                            .font(DS.Typography.subheadlineMedium)
                        Text(factor.impact)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
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
            VStack(alignment: .leading, spacing: DS.space5) {
                memoryBlock
                stressLoadBlock
                fitnessBlock
            }
            .padding(.top, DS.space3)
        } label: {
            HStack(spacing: DS.itemSpacing) {
                Image(systemName: "book.closed.fill")
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(.gray.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.BrainHealth.learnMore)
                        .font(DS.Typography.subheadlineSemibold)
                    Text(Copy.BrainHealth.learnMoreHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
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

        return VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.sleepAndMemory)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(AppColour.textSecondary)

            HStack(spacing: DS.space4) {
                StatBoxView(
                    label: brainScore.remSleepScore != nil ? Copy.BrainHealth.dreamSleep : "\(Copy.BrainHealth.dreamSleep) (Est.)",
                    value: "\(Int(remDisplay))%",
                    color: readinessColor(remDisplay / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                StatBoxView(
                    label: brainScore.deepSleepScore != nil ? Copy.BrainHealth.deepSleep : "\(Copy.BrainHealth.deepSleep) (Est.)",
                    value: "\(Int(deepDisplay))%",
                    color: readinessColor(deepDisplay / 100)
                )
            }
            .frame(maxWidth: .infinity)

            Text(hasSleepStages ? Copy.BrainHealth.sleepBrainExplanation : Copy.BrainHealth.noSleepStageData)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
    }

    private var stressLoadBlock: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.mentalEnergy)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(AppColour.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: DS.itemSpacing) {
                Text("\(Int(brainScore.stressCognitionLoad))%")
                    .font(DS.Typography.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(capacityColor)
                    .postHogMask()

                ProgressBarView(
                    fraction: brainScore.stressCognitionLoad / 100,
                    color: capacityColor,
                    height: 8
                )
            }

            Text(Copy.BrainHealth.mentalEnergyExplanation)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
    }

    private var capacityColor: Color {
        if brainScore.stressCognitionLoad >= 70 { return AppColour.success }
        if brainScore.stressCognitionLoad >= 50 { return AppColour.warning }
        if brainScore.stressCognitionLoad >= 30 { return AppColour.warning }
        return AppColour.danger
    }

    private var fitnessBlock: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.brainHealthOverTime)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(AppColour.textSecondary)

            HStack(spacing: DS.space4) {
                StatBoxView(
                    label: Copy.BrainHealth.heartAndBrain,
                    value: "\(Int(brainScore.neurovascularFitness))%",
                    color: readinessColor(brainScore.neurovascularFitness / 100)
                )

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.separator))
                    .frame(width: 1, height: DS.dividerHeight)

                StatBoxView(
                    label: Copy.BrainHealth.sleepRhythm,
                    value: "\(Int(brainScore.circadianAlignment))%",
                    color: readinessColor(brainScore.circadianAlignment / 100)
                )
            }
            .frame(maxWidth: .infinity)

            Text(Copy.BrainHealth.longTermExplanation)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
    }

    // MARK: - Chart Helpers

    private func chartBarColor(for score: Int) -> Color {
        if score >= 80 { return AppColour.success }
        if score >= 65 { return AppColour.info }
        if score >= 45 { return AppColour.textTertiary }
        return AppColour.warning
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
        case "improving": return AppColour.success
        case "declining": return AppColour.warning
        default: return AppColour.textSecondary
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Text(Copy.Analysis.RiskDetail.disclaimer)
            .font(DS.Typography.caption2)
            .foregroundStyle(AppColour.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, DS.space6)
            .padding(.bottom, DS.space4)
    }
}

private struct BrainWeeklyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
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
