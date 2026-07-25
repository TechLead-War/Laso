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
                    improveSection.frame(width: sectionWidth)
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
        // Hide the numeric score whenever we don't have enough confidence
        // (< 0.7) to back it. Replace it with a "—" placeholder + a clear
        // "Building accuracy (X%)" badge so users don't misread an under-
        // confident score as a real reading.
        let hasConfidence = brainScore.confidence >= 0.7

        return VStack(spacing: DS.itemSpacing) {
            // Heading sits above the number it names, so the number reads as Brain Health.
            Text(Copy.BrainHealth.brainHealthLabel)
                .font(DS.Typography.captionSemibold)
                .tracking(2)
                .foregroundStyle(AppColour.textSecondary)

            Text(hasConfidence ? "\(brainScore.score)" : "—")
                .font(DS.Typography.displayXL.monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .postHogMask()

            Text(Copy.BrainHealth.scaleAndDirection)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(AppColour.textTertiary)

            // Static explainer. teaches the user what this screen is about
            Text(Copy.BrainHealth.heroExplainer)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(AppColour.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space2)

            if hasConfidence {
                Text(brainScore.state.displayName)
                    .font(DS.Typography.title3.weight(.bold))
                    .foregroundStyle(brainScore.state.color)

                Text(brainScore.headline)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: DS.space1) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(DS.Typography.caption2.weight(.bold))
                    Text(Copy.BrainHealth.buildingAccuracy(percent: Int(brainScore.confidence * 100)))
                        .font(DS.Typography.captionSemibold)
                }
                .foregroundStyle(AppColour.textTertiary)
                .padding(.horizontal, DS.itemSpacing)
                .padding(.vertical, DS.space2)
                .background(AppColour.textSecondary.opacity(0.1), in: Capsule())

                Text(Copy.BrainHealth.needMoreData)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.space2)
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
                WeeklyBarChart(
                    points: lastSevenDayPoints,
                    value: { Double($0.score ?? 0) / 100.0 },
                    color: { chartBarColor(for: $0.score) },
                    label: { $0.isToday ? Copy.BrainHealth.chartToday : abbreviatedDay($0.date) },
                    topLabel: { $0.score.map { "\($0)" } ?? "—" },
                    tooltipLines: { point in
                        [
                            point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                            point.score.map { "\($0) \(Copy.BrainHealth.scaleSuffix)" } ?? Copy.Common.notEnoughData
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

    /// The seven calendar days ending today, so today always has a column even on days
    /// the scorer could not produce a score. Scoring gaps show an empty bar instead of
    /// silently sliding the window back to older days.
    private var lastSevenDayPoints: [BrainWeeklyPoint] {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let scoreByDay = Dictionary(
            weeklyHistory.map { (calendar.startOfDay(for: $0.date), $0.score) },
            uniquingKeysWith: { _, newest in newest }
        )

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return BrainWeeklyPoint(date: day, score: scoreByDay[day], isToday: offset == 0)
        }
    }

    private func chartBarColor(for score: Int?) -> Color {
        guard let score else { return AppColour.textTertiary.opacity(0.35) }
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

    // MARK: - Improve Your Score (masterclass)

    private var improveSection: some View {
        let hasConfidence = brainScore.confidence >= 0.7
        let levers = computeScoreLevers()

        return VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.BrainHealth.improveTitle)
                .font(DS.Typography.headline)

            if hasConfidence, let topLever = levers.first {
                heroLeverCard(lever: topLever, allLevers: levers)

                VStack(alignment: .leading, spacing: DS.space3) {
                    Text(Copy.BrainHealth.improveBreakdown)
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(AppColour.textSecondary)

                    ForEach(levers) { lever in
                        leverBreakdownRow(lever: lever)
                    }
                }
                .padding(.top, DS.space2)

                Text(Copy.BrainHealth.improveFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.space1)
            } else {
                Text(Copy.BrainHealth.improveNeedsConfidence)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func computeScoreLevers() -> [ScoreLever] {
        let raw: [(title: String, icon: String, score: Double, weight: Double, kind: ScoreLever.Kind)] = [
            (Copy.BrainHealth.subscaleCognitiveReadiness, "brain.head.profile.fill",
             brainScore.cognitiveReadiness, BrainHealthScorer.cognitiveReadinessWeight, .cognitiveReadiness),
            (Copy.BrainHealth.subscaleMemoryRecovery, "moon.zzz.fill",
             brainScore.memoryRecovery, BrainHealthScorer.memoryRecoveryWeight, .memoryRecovery),
            (Copy.BrainHealth.mentalEnergy, "bolt.heart.fill",
             brainScore.stressCognitionLoad, BrainHealthScorer.stressCognitionWeight, .stressCognition),
            (Copy.BrainHealth.heartAndBrain, "heart.fill",
             brainScore.neurovascularFitness, BrainHealthScorer.neurovascularWeight, .neurovascular),
            (Copy.BrainHealth.sleepRhythm, "clock.fill",
             brainScore.circadianAlignment, BrainHealthScorer.circadianWeight, .circadian)
        ]
        return raw.map { item in
            let s = Int(item.score.rounded())
            let pts = max(0, Int(((100.0 - item.score) * item.weight).rounded()))
            return ScoreLever(
                title: item.title,
                icon: item.icon,
                score: s,
                weight: item.weight,
                pointsOnTable: pts,
                kind: item.kind
            )
        }
        .sorted { $0.pointsOnTable > $1.pointsOnTable }
    }

    @ViewBuilder
    private func heroLeverCard(lever: ScoreLever, allLevers: [ScoreLever]) -> some View {
        // Strong threshold reuses the scorer's "sharp" boundary so we don't invent a new clinical cutoff.
        let isStrong = lever.score >= BrainHealthState.sharpLowerBound
        let bestScore = allLevers.map(\.score).max() ?? lever.score
        let projectedLift = max(0, Int((Double(bestScore - lever.score) * lever.weight).rounded()))
        let projectedScore = min(100, brainScore.score + projectedLift)
        let color = readinessColor(Double(lever.score) / 100)

        VStack(alignment: .leading, spacing: DS.space4) {
            HStack(spacing: DS.space3) {
                Image(systemName: lever.icon)
                    .font(DS.Typography.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.BrainHealth.biggestLeverHeader)
                        .font(DS.Typography.caption2Medium)
                        .tracking(1)
                        .foregroundStyle(AppColour.textTertiary)
                    Text(lever.title)
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(AppColour.textPrimary)
                }

                Spacer(minLength: 0)

                Text("\(lever.score)%")
                    .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .postHogMask()
            }

            ProgressBarView(fraction: Double(lever.score) / 100, color: color, height: 6)

            if isStrong {
                Text(Copy.BrainHealth.improveStrongState)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                projectionBlock(projectedScore: projectedScore, lift: projectedLift)
                actionsBlock(actions: actions(for: lever.kind), tint: color)
            }
        }
        .padding(DS.cardPadding)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(color.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func projectionBlock(projectedScore: Int, lift: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(Copy.BrainHealth.projectionLabel)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(AppColour.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                Text("\(projectedScore)")
                    .font(DS.Typography.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColour.textPrimary)
                    .postHogMask()
                Text(Copy.BrainHealth.scaleSuffix)
                    .font(DS.Typography.caption2Medium)
                    .foregroundStyle(AppColour.textTertiary)
                Spacer(minLength: 0)
                if lift > 0 {
                    Text(Copy.BrainHealth.projectionGain(points: lift))
                        .font(DS.Typography.captionSemibold.monospacedDigit())
                        .foregroundStyle(AppColour.success)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(AppColour.success.opacity(DS.badgeBg), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func actionsBlock(actions: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.BrainHealth.actionsHeader)
                .font(DS.Typography.caption2Medium)
                .tracking(1)
                .foregroundStyle(AppColour.textTertiary)
            ForEach(actions, id: \.self) { action in
                HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(action)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func leverBreakdownRow(lever: ScoreLever) -> some View {
        let color = readinessColor(Double(lever.score) / 100)
        HStack(alignment: .top, spacing: DS.space3) {
            Image(systemName: lever.icon)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.space1) {
                HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                    Text(lever.title)
                        .font(DS.Typography.subheadlineMedium)
                        .lineLimit(1)
                    Text(Copy.BrainHealth.weightOfScore(percent: Int((lever.weight * 100).rounded())))
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(AppColour.textTertiary)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(AppColour.textSecondary.opacity(0.10), in: Capsule())
                    Spacer(minLength: 0)
                    Text(lever.pointsOnTable > 0
                         ? Copy.BrainHealth.pointsLost(points: lever.pointsOnTable)
                         : Copy.BrainHealth.projectionGain(points: 0))
                        .font(DS.Typography.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(lever.pointsOnTable > 0 ? AppColour.warning : AppColour.success)
                        .postHogMask()
                }
                ProgressBarView(fraction: Double(lever.score) / 100, color: color, height: 4)
            }
        }
    }

    private func actions(for kind: ScoreLever.Kind) -> [String] {
        switch kind {
        case .cognitiveReadiness: return Copy.BrainHealth.actionsCognitiveReadiness
        case .memoryRecovery:     return Copy.BrainHealth.actionsMemoryRecovery
        case .stressCognition:    return Copy.BrainHealth.actionsStressCognition
        case .neurovascular:      return Copy.BrainHealth.actionsNeurovascular
        case .circadian:          return Copy.BrainHealth.actionsCircadian
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
    // The day is the identity, so bar selection survives a re-render.
    var id: Date { date }
    let date: Date
    let score: Int?
    let isToday: Bool
}

private struct ScoreLever: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let score: Int
    let weight: Double
    let pointsOnTable: Int
    let kind: Kind

    enum Kind {
        case cognitiveReadiness
        case memoryRecovery
        case stressCognition
        case neurovascular
        case circadian
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
                topFactors: [
                    (label: "REM Sleep", impact: "12% above baseline", isPositive: true),
                    (label: "HRV", impact: "Trending up this week", isPositive: true),
                    (label: "Sleep Regularity", impact: "Inconsistent bedtimes", isPositive: false)
                ],
                headline: "Good recovery signals from last night",
                confidence: 0.85
            ),
            weeklyHistory: [
                (date: Date.cal.date(byAdding: .day, value: -6, to: Date())!, score: 72),
                (date: Date.cal.date(byAdding: .day, value: -5, to: Date())!, score: 68),
                (date: Date.cal.date(byAdding: .day, value: -4, to: Date())!, score: 75),
                (date: Date.cal.date(byAdding: .day, value: -3, to: Date())!, score: 80),
                (date: Date.cal.date(byAdding: .day, value: -2, to: Date())!, score: 77),
                (date: Date.cal.date(byAdding: .day, value: -1, to: Date())!, score: 82),
                (date: Date(), score: 78)
            ],
            weeklyAverage: 76,
            trend: "improving"
        )
    }
}
