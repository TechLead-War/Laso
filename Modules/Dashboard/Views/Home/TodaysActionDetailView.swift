import SwiftUI

/// Hero detail page for today's single action. shows the action, why it matters, and supporting insights.
struct TodaysActionDetailView: View {
    let action: DashboardViewModel.SmartAction
    let policyDecision: PolicyDecision?
    let readinessScore: Int
    let workoutRecoveryBand: WorkoutRecoveryBand
    let cyclePhase: CyclePhaseModifier?
    let topCausalChain: CausalChain?
    let recoverySignals: DashboardViewModel.RecoverySignalsSnapshot
    let onTapMetric: (HealthMetric) -> Void

    @State private var isShowingWorkoutPlan = false

    private var todayWorkoutPlan: WorkoutPlan {
        WorkoutProgrammer.generatePlan(
            recoveryBand: workoutRecoveryBand,
            cyclePhase: cyclePhase
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section
                heroSection

                // Content sections
                VStack(spacing: DS.sectionSpacing) {
                    // Why section
                    whySection

                    // What's off today — live signals vs personal baseline
                    whatsOffSection

                    // What's leading to what (top causal chain, high confidence only)
                    causalChainSection

                    // Do Today — concrete band-driven plan, enriched with policy values when present
                    doTodaySection

                    // Today's Workout
                    todayWorkoutSection

                    // What happened before — only when real proof exists
                    if let summary = action.proofSummary, summary.hasProof {
                        proofSection
                    }

                    // Supporting insights
                    if !action.supportingInsights.isEmpty {
                        insightsSection
                    }

                    Text(Copy.Analysis.RiskDetail.disclaimer)
                        .font(.system(size: 13.2))
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, DS.screenPadding)
                        .padding(.top, DS.space6)
                        .padding(.bottom, DS.space4)
                }
                .padding(.top, DS.space6)
                .padding(.bottom, DS.space7)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColour.surfaceSunken.ignoresSafeArea())
        .accessibilityIdentifier("screen.todaysAction")
        .navigationTitle(Copy.Home.todaysAction)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingWorkoutPlan) {
            NavigationStack {
                WorkoutPlanSheet(
                    plan: todayWorkoutPlan,
                    recoveryBand: workoutRecoveryBand,
                    cyclePhase: cyclePhase
                )
            }
            .presentationDetents([.large])
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.todaysActionDetail, metadata: [
                "source": action.source,
                "has_policy": policyDecision != nil,
                "insight_count": action.supportingInsights.count
            ])
            AppAnalytics.shared.trackCoreAction(.viewedDailyAction, screen: .todaysActionDetail)
            AppAnalytics.shared.trackRecommendationViewed(
                type: "todays_action_\(action.source)",
                metric: action.supportingInsights.first?.metric.rawValue ?? "general",
                difficulty: recommendationDifficulty
            )
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.todaysActionDetail)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        let tint = DS.scoreColor(readinessScore)
        return HStack(alignment: .top, spacing: DS.space4) {
            Image(systemName: action.icon)
                .font(DS.Typography.mediumIcon)
                .foregroundStyle(AppColour.textOnAccent)
                .frame(width: 72, height: 72)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
                .shadow(color: AppColour.shadowAmbient, radius: 10, y: 4)

            VStack(alignment: .leading, spacing: DS.space2) {
                Text(action.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(AppColour.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(action.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recoveryBandChipLabel)
                    .font(DS.Typography.calloutSemibold)
                    .foregroundStyle(tint)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(tint.opacity(DS.badgeBg), in: Capsule())
                    .padding(.top, DS.space1)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding + 4)
        .background(DS.recoveryGradient(readinessScore))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(tint.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: AppColour.shadowAmbient, radius: 12, y: 4)
        .padding(.horizontal, DS.screenPadding)
        .padding(.top, DS.space4)
    }

    private var recoveryBandChipLabel: String {
        switch workoutRecoveryBand {
        case .red: return "Red Day. Recover."
        case .yellow: return "Yellow Day. Maintain."
        case .green: return "Green Day. Push."
        }
    }

    // MARK: - Why Section

    private var whySection: some View {
        let rationale = effectiveRationale
        return Group {
            if !rationale.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: DS.space2) {
                        Image(systemName: "lightbulb.fill")
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.warning)
                        Text(Copy.Home.whyThisToday)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                    }
                    .padding(.horizontal, DS.screenPadding)

                    VStack(alignment: .leading, spacing: DS.space3) {
                        Text(rationale)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Confidence indicator
                        if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
                            HStack(spacing: DS.space1) {
                                Circle()
                                    .fill(confidenceColor(decision.decisionConfidence))
                                    .frame(width: 8, height: 8)
                                Text(Copy.Home.confidenceText(confidenceLabel(decision.decisionConfidence)))
                                    .font(DS.Typography.callout)
                                    .foregroundStyle(AppColour.textTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.cardPadding + 2)
                    .cardStyle()
                    .padding(.horizontal, DS.screenPadding)
                }
            }
        }
    }

    // MARK: - Proof Section

    @ViewBuilder
    private var proofSection: some View {
        if let summary = action.proofSummary, summary.hasProof {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(spacing: DS.space2) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.success)
                    Text(Copy.Home.ActionProof.whatHappenedBefore)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                }
                .padding(.horizontal, DS.screenPadding)

                VStack(alignment: .leading, spacing: DS.space3) {
                    if let detailLine = summary.detailProofLine {
                        Text(detailLine)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(summary.timeframeLine)
                        .font(DS.Typography.callout)
                        .foregroundStyle(AppColour.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.cardPadding + 2)
                .cardStyle()
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    // MARK: - Do Today

    private var doTodaySection: some View {
        let items = doTodayItems()
        let benefit = policyDecision?.primaryAction.expectedBenefit ?? ""

        return VStack(alignment: .leading, spacing: DS.space2) {
            HStack(spacing: DS.space2) {
                Image(systemName: "target")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(DS.scoreColor(readinessScore))
                Text(Copy.Home.TodaysActionDetail.doToday)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
            }
            .padding(.horizontal, DS.screenPadding)

            VStack(alignment: .leading, spacing: DS.space3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    doTodayRow(icon: item.icon, text: item.text)
                }

                if !benefit.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: DS.space1) {
                        Image(systemName: "arrow.up.right")
                            .font(DS.Typography.calloutSemibold)
                            .foregroundStyle(AppColour.success)
                        Text(benefit)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.cardPadding + 2)
            .cardStyle()
            .padding(.horizontal, DS.screenPadding)
        }
    }

    private struct DoTodayItem {
        let icon: String
        let text: String
    }

    private func doTodayItems() -> [DoTodayItem] {
        let bedtime = policyDecision?.targetSleepTime
        let strain = policyDecision?.strainBudget

        switch workoutRecoveryBand {
        case .red:
            return [
                DoTodayItem(icon: "figure.mind.and.body", text: strain ?? "Light movement only. Stretching, yoga, or a gentle walk."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Lights off by \($0) tonight." } ?? "Lights off by 10:30 PM tonight."),
                DoTodayItem(icon: "drop.fill", text: "Skip alcohol today. It blocks HRV recovery overnight.")
            ]
        case .yellow:
            return [
                DoTodayItem(icon: "figure.walk", text: strain ?? "Moderate effort only. Avoid anything maximal."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Lights off by \($0) tonight." } ?? "Lights off by 11:00 PM tonight."),
                DoTodayItem(icon: "drop.fill", text: "Steady hydration through the day. 2 L minimum.")
            ]
        case .green:
            return [
                DoTodayItem(icon: "flame.fill", text: strain ?? "Green light. Push one workout hard today."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Keep bedtime consistent. Aim for \($0)." } ?? "Keep bedtime consistent tonight."),
                DoTodayItem(icon: "drop.fill", text: "Hydrate ahead of the strain. 2 to 3 L.")
            ]
        }
    }

    private func doTodayRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.space3) {
            Image(systemName: icon)
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.textOnAccent)
                .frame(width: 24, height: 24)
                .background(DS.scoreColor(readinessScore), in: Circle())

            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - What's Off Today

    @ViewBuilder
    private var whatsOffSection: some View {
        if recoverySignals.hasAny {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(spacing: DS.space2) {
                    Image(systemName: "waveform.path.ecg")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.danger)
                    Text(Copy.Home.TodaysActionDetail.whatsOffToday)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                }
                .padding(.horizontal, DS.screenPadding)

                VStack(spacing: 0) {
                    if let current = recoverySignals.hrvCurrent {
                        whatsOffRow(
                            metric: .heartRateVariability,
                            current: current,
                            baseline: recoverySignals.hrvBaseline,
                            baselineLabel: Copy.Home.TodaysActionDetail.baseline
                        )
                    }
                    if let current = recoverySignals.rhrCurrent {
                        if recoverySignals.hrvCurrent != nil { Divider().padding(.leading, 44) }
                        whatsOffRow(
                            metric: .restingHeartRate,
                            current: current,
                            baseline: recoverySignals.rhrBaseline,
                            baselineLabel: Copy.Home.TodaysActionDetail.baseline
                        )
                    }
                    if let current = recoverySignals.sleepHoursLast {
                        if recoverySignals.hrvCurrent != nil || recoverySignals.rhrCurrent != nil {
                            Divider().padding(.leading, 44)
                        }
                        whatsOffRow(
                            metric: .sleepDuration,
                            current: current,
                            baseline: recoverySignals.sleepHoursGoal,
                            baselineLabel: "goal"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func whatsOffRow(metric: HealthMetric, current: Double, baseline: Double?, baselineLabel: String) -> some View {
        let deviation: Int? = {
            guard let base = baseline, base != 0 else { return nil }
            return Int(((current - base) / base) * 100)
        }()
        let isOff: Bool = {
            guard let d = deviation else { return false }
            return metric.higherIsBetter ? d < -10 : d > 10
        }()
        let deviationColor: Color = isOff ? AppColour.danger : AppColour.textSecondary

        return HStack(spacing: DS.space3) {
            Image(systemName: metric.systemImageName)
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.textOnAccent)
                .frame(width: 32, height: 32)
                .background(metric.category.color, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(metric.displayName)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(AppColour.textPrimary)
                if let base = baseline {
                    Text(Copy.Home.baselineWithUnitText(baselineLabel, metric.formatValue(base), metric.unit))
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.space1) {
                Text(Copy.Home.xText2(metric.formatValue(current), metric.unit))
                    .font(DS.Typography.bodySemibold.monospacedDigit())
                    .foregroundStyle(AppColour.textPrimary)
                if let d = deviation {
                    Text(d > 0 ? "+\(d)%" : "\(d)%")
                        .font(DS.Typography.captionSemibold.monospacedDigit())
                        .foregroundStyle(deviationColor)
                }
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space2)
    }

    // MARK: - Causal Chain

    @ViewBuilder
    private var causalChainSection: some View {
        if let chain = topCausalChain, chain.confidence >= 0.5 {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(spacing: DS.space2) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.categoryStress)
                    Text(Copy.Home.TodaysActionDetail.whatsLeadingToWhat)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                }
                .padding(.horizontal, DS.screenPadding)

                CausalChainCard(chain: chain) {
                    onTapMetric(chain.affectedMetric)
                }
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private var effectiveRationale: String {
        // Prefer policy engine rationale, then advisor rationale
        if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
            let why = decision.primaryAction.whyItMatters
            if !why.isEmpty { return why }
        }
        return action.rationale
    }

    private var recommendationDifficulty: String {
        guard let confidence = policyDecision?.decisionConfidence else {
            return "contextual"
        }
        return confidence >= 0.7 ? "high_confidence" : "medium_confidence"
    }

    // MARK: - Supporting Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack(spacing: DS.space2) {
                Image(systemName: "stethoscope")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.info)
                Text(Copy.Home.TodaysActionDetail.yourCoachsNotes)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
            }
            .padding(.horizontal, DS.screenPadding)

            ForEach(action.supportingInsights) { insight in
                Button {
                    AppAnalytics.shared.trackInsightTapped(
                        category: insight.category.rawValue,
                        severity: insight.severity.rawValue,
                        metric: insight.metric.rawValue,
                        screen: .todaysActionDetail
                    )
                    onTapMetric(insight.metric)
                } label: {
                    insightRow(insight)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Copy.Home.insightLabel(insight.metric.displayName, insight.title))
                .accessibilityHint(Copy.Home.opensDetailedMetricViewHint)
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: DS.space3) {
            Image(systemName: insight.metric.systemImageName)
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.textOnAccent)
                .frame(width: 32, height: 32)
                .background(insight.metric.category.color, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(insight.title)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(insight.actionSummary)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.textTertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - Today's Workout

    private var todayWorkoutSection: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            HStack(spacing: DS.space2) {
                Image(systemName: "figure.run.circle.fill")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.warning)
                Text(Copy.Home.TodaysActionDetail.todaysWorkout)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
            }
            .padding(.horizontal, DS.screenPadding)

            TodayWorkoutCard(
                plan: todayWorkoutPlan,
                recoveryBand: workoutRecoveryBand,
                cyclePhase: cyclePhase
            ) {
                AppAnalytics.shared.trackWorkoutPlanOpened(
                    plan: todayWorkoutPlan,
                    recoveryBand: workoutRecoveryBand,
                    cyclePhase: cyclePhase,
                    screen: .todaysActionDetail
                )
                AppAnalytics.shared.trackRecommendationViewed(
                    type: "todays_action_workout_plan",
                    metric: todayWorkoutPlan.zone.rawValue,
                    difficulty: workoutRecoveryBand.rawValue
                )
                isShowingWorkoutPlan = true
            }
            .padding(.horizontal, DS.screenPadding)
        }
    }

    // MARK: - Helpers

    private func confidenceLabel(_ value: Double) -> String {
        switch value {
        case 0.7...: return "High"
        case 0.5..<0.7: return "Moderate"
        default: return "Emerging"
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        switch value {
        case 0.7...: return AppColour.success
        case 0.5..<0.7: return AppColour.warning
        default: return AppColour.scoreFair
        }
    }
}
