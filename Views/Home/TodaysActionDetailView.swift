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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                        .padding(.top, DS.space6)
                        .padding(.bottom, DS.space4)
                }
                .padding(.top, DS.space6)
                .padding(.bottom, DS.space7)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .accessibilityIdentifier("screen.todaysAction")
        .navigationTitle("Today's Action")
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
        return HStack(alignment: .top, spacing: 16) {
            Image(systemName: action.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: tint.opacity(0.35), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(action.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(action.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recoveryBandChipLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(DS.badgeBg), in: Capsule())
                    .padding(.top, 2)
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
        .shadow(color: tint.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal)
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
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(Copy.Home.whyThisToday)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(rationale)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Confidence indicator
                        if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(confidenceColor(decision.decisionConfidence))
                                    .frame(width: 8, height: 8)
                                Text("\(confidenceLabel(decision.decisionConfidence)) confidence")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.cardPadding + 2)
                    .cardStyle()
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Proof Section

    @ViewBuilder
    private var proofSection: some View {
        if let summary = action.proofSummary, summary.hasProof {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(Copy.Home.ActionProof.whatHappenedBefore)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    if let detailLine = summary.detailProofLine {
                        Text(detailLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(summary.timeframeLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.cardPadding + 2)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Do Today

    private var doTodaySection: some View {
        let items = doTodayItems()
        let benefit = policyDecision?.primaryAction.expectedBenefit ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Do Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    doTodayRow(index: index + 1, icon: item.icon, text: item.text)
                }

                if !benefit.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                        Text(benefit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.cardPadding + 2)
            .cardStyle()
            .padding(.horizontal)
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
                DoTodayItem(icon: "figure.mind.and.body", text: strain ?? "Light movement only — stretching, yoga, or a gentle walk."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Lights off by \($0) tonight." } ?? "Lights off by 10:30 PM tonight."),
                DoTodayItem(icon: "drop.fill", text: "Skip alcohol today — it blocks HRV recovery overnight.")
            ]
        case .yellow:
            return [
                DoTodayItem(icon: "figure.walk", text: strain ?? "Moderate effort only — avoid anything maximal."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Lights off by \($0) tonight." } ?? "Lights off by 11:00 PM tonight."),
                DoTodayItem(icon: "drop.fill", text: "Steady hydration through the day — 2 L minimum.")
            ]
        case .green:
            return [
                DoTodayItem(icon: "flame.fill", text: strain ?? "Green light — push one workout hard today."),
                DoTodayItem(icon: "moon.fill", text: bedtime.map { "Keep bedtime consistent — aim for \($0)." } ?? "Keep bedtime consistent tonight."),
                DoTodayItem(icon: "drop.fill", text: "Hydrate ahead of the strain — 2 to 3 L.")
            ]
        }
    }

    private func doTodayRow(index: Int, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - What's Off Today

    @ViewBuilder
    private var whatsOffSection: some View {
        if recoverySignals.hasAny {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text("What's off today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    if let current = recoverySignals.hrvCurrent {
                        whatsOffRow(
                            metric: .heartRateVariability,
                            current: current,
                            baseline: recoverySignals.hrvBaseline,
                            baselineLabel: "baseline"
                        )
                    }
                    if let current = recoverySignals.rhrCurrent {
                        if recoverySignals.hrvCurrent != nil { Divider().padding(.leading, 44) }
                        whatsOffRow(
                            metric: .restingHeartRate,
                            current: current,
                            baseline: recoverySignals.rhrBaseline,
                            baselineLabel: "baseline"
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
                .padding(.horizontal)
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
        let deviationColor: Color = isOff ? .red : .secondary

        return HStack(spacing: 12) {
            Image(systemName: metric.systemImageName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(metric.category.color, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let base = baseline {
                    Text("\(baselineLabel) \(metric.formatValue(base)) \(metric.unit)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(metric.formatValue(current)) \(metric.unit)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                if let d = deviation {
                    Text(d > 0 ? "+\(d)%" : "\(d)%")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(deviationColor)
                }
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Causal Chain

    @ViewBuilder
    private var causalChainSection: some View {
        if let chain = topCausalChain, chain.confidence >= 0.5 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                    Text("What's leading to what")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal)

                CausalChainCard(chain: chain) {
                    onTapMetric(chain.affectedMetric)
                }
                .padding(.horizontal)
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
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Your coach's notes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)

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
                .padding(.horizontal)
            }
        }
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: insight.metric.systemImageName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(insight.metric.category.color, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(insight.actionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - Today's Workout

    private var todayWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Today's Workout")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)

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
            .padding(.horizontal)
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
        case 0.7...: return .green
        case 0.5..<0.7: return .yellow
        default: return .orange
        }
    }
}
