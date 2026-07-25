import Foundation

struct DashboardSmartActionAdvisor {
    struct LiveSnapshot {
        let hour: Int
        let stressLevel: Int?
        let readinessScore: Int?
        let hasSleepData: Bool
        let sleepHours: Double
        let deepSleepMinutes: Double
        let exerciseMinutes: Double
        let exerciseGoal: Double
        let latestRestingHeartRate: Double?
    }

    struct AnalysisSnapshot {
        let policyDecision: PolicyDecision?
        let restingHeartRateBaselineMean: Double?
        let userFocuses: Set<HealthFocus>
        let topInsights: [Insight]
    }

    struct Recommendation: Equatable {
        let icon: String
        let title: String
        let subtitle: String
        var source: String = "context_rules"
        /// Why we chose this specific action. shown on the detail page
        var rationale: String = ""

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.icon == rhs.icon && lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle && lhs.source == rhs.source
        }
    }

    func recommend(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot
    ) -> Recommendation {
        // 1. ML policy engine. highest quality, fully personalized
        if let r = recommendFromPolicyEngine(analysis: analysis) { return r }

        // 2. Insight-driven. derive action from the highest-priority insight
        if let r = recommendFromHighPriorityInsight(analysis: analysis) { return r }

        // 3. Live-data rules (only when data signals something notable)
        if let r = recommendFromLiveDataRules(live: live) { return r }

        // 4. Any insight available. use it
        if let topInsight = analysis.topInsights.first,
           let r = insightDrivenRecommendation(topInsight) { return r }

        // 5. Focus-aware rules
        if let focusAction = focusAwareRecommendation(live: live, analysis: analysis) {
            return focusAction
        }

        // 6. Activity progress
        if let r = recommendFromActivityProgress(live: live) { return r }

        // 7. Late-hour wind-down
        if let r = recommendLateHourWindDown(live: live) { return r }

        // 8. Default fallback
        return Recommendation(
            icon: "figure.walk",
            title: Copy.Home.SmartAction.defaultTitle,
            subtitle: Copy.Home.SmartAction.defaultSubtitle,
            rationale: Copy.Home.SmartAction.defaultRationale
        )
    }

    // MARK: - Recommendation Sources

    private func recommendFromPolicyEngine(analysis: AnalysisSnapshot) -> Recommendation? {
        guard let decision = analysis.policyDecision,
              decision.decisionConfidence >= 0.3 else { return nil }
        return Recommendation(
            icon: icon(for: decision.primaryAction.candidate.actionType),
            title: decision.prescriptiveHeadline,
            subtitle: decision.primaryAction.description,
            source: "policy_engine",
            rationale: decision.primaryAction.whyItMatters
        )
    }

    private func recommendFromHighPriorityInsight(analysis: AnalysisSnapshot) -> Recommendation? {
        guard let topInsight = analysis.topInsights.first,
              topInsight.severity >= .warning || topInsight.priorityScore > 3.0 else { return nil }
        return insightDrivenRecommendation(topInsight)
    }

    private func recommendFromLiveDataRules(live: LiveSnapshot) -> Recommendation? {
        if let stress = live.stressLevel, stress >= 60 {
            return Recommendation(
                icon: "wind",
                title: Copy.Home.SmartAction.highStressTitle,
                subtitle: Copy.Home.SmartAction.highStressSubtitle,
                rationale: Copy.Home.SmartAction.highStressRationale(stress)
            )
        }

        if live.hasSleepData, live.sleepHours < 5.5 {
            return Recommendation(
                icon: "moon.zzz.fill",
                title: Copy.Home.SmartAction.lowSleepTitle,
                subtitle: Copy.Home.SmartAction.lowSleepSubtitle(Self.formatHoursMinutes(live.sleepHours)),
                rationale: Copy.Home.SmartAction.lowSleepRationale
            )
        }

        if let readiness = live.readinessScore, readiness < 40 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: Copy.Home.SmartAction.lowReadinessTitle,
                subtitle: Copy.Home.SmartAction.lowReadinessSubtitle(readiness),
                rationale: Copy.Home.SmartAction.lowReadinessRationale
            )
        }

        return nil
    }

    private func recommendFromActivityProgress(live: LiveSnapshot) -> Recommendation? {
        if live.exerciseMinutes >= live.exerciseGoal {
            return Recommendation(
                icon: "checkmark.seal.fill",
                title: Copy.Home.SmartAction.exerciseGoalTitle,
                subtitle: Copy.Home.SmartAction.exerciseGoalSubtitle(Int(live.exerciseMinutes)),
                rationale: Copy.Home.SmartAction.exerciseGoalRationale
            )
        }

        if let readiness = live.readinessScore, readiness >= 60 {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "bolt.heart.fill",
                title: Copy.Home.SmartAction.minutesToGoTitle(remaining),
                subtitle: Copy.Home.SmartAction.minutesToGoSubtitle,
                rationale: Copy.Home.SmartAction.minutesToGoRationale
            )
        }

        return nil
    }

    private func recommendLateHourWindDown(live: LiveSnapshot) -> Recommendation? {
        guard live.hour >= 20 else { return nil }
        return Recommendation(
            icon: "moon.fill",
            title: Copy.Home.SmartAction.windDownTitle,
            subtitle: Copy.Home.SmartAction.windDownSubtitle,
            rationale: Copy.Home.SmartAction.windDownRationale
        )
    }

    // MARK: - Insight → Action

    /// nil when the insight carries no action we can phrase for a person, so the caller falls through to the next rule
    private func insightDrivenRecommendation(_ insight: Insight) -> Recommendation? {
        let icon = insight.metric.systemImageName
        let rationale = insight.summary

        // Use the insight's actionable recommendation as the subtitle
        let subtitle = insight.actionSummary

        // Build a specific, data-grounded title
        let title: String
        switch insight.directive {
        case .rest, .reduceIntensity:
            title = Copy.Home.SmartAction.insightEaseOff(insight.metric.displayName)
        case .increaseActivity, .pushHarder:
            title = Copy.Home.SmartAction.insightPushHarder(insight.metric.displayName)
        case .sleepMore, .sleepBetter:
            title = Copy.Home.SmartAction.insightSleepBetter
        case .seekMedical:
            title = Copy.Home.SmartAction.insightWorthChecking(insight.metric.displayName)
        case .maintain:
            title = Copy.Home.SmartAction.insightKeepItUp(insight.metric.displayName)
        case .informational:
            // insight.title is machine assembled, so it must never reach the hero headline
            return nil
        }

        return Recommendation(
            icon: icon,
            title: title,
            subtitle: subtitle,
            source: "insight_driven",
            rationale: rationale
        )
    }

    private func focusAwareRecommendation(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot
    ) -> Recommendation? {
        guard !analysis.userFocuses.isEmpty else { return nil }

        if analysis.userFocuses.contains(.sleep), live.hasSleepData {
            if live.deepSleepMinutes < 45 {
                return Recommendation(
                    icon: "moon.zzz.fill",
                    title: Copy.Home.SmartAction.deepSleepTitle,
                    subtitle: Copy.Home.SmartAction.deepSleepSubtitle(Int(live.deepSleepMinutes)),
                    rationale: Copy.Home.SmartAction.deepSleepRationale
                )
            }
            if live.sleepHours < 7 {
                return Recommendation(
                    icon: "bed.double.fill",
                    title: Copy.Home.SmartAction.earlyBedTitle,
                    subtitle: Copy.Home.SmartAction.earlyBedSubtitle(Self.formatHoursMinutes(live.sleepHours)),
                    rationale: Copy.Home.SmartAction.earlyBedRationale
                )
            }
        }

        if analysis.userFocuses.contains(.fitness), live.exerciseMinutes < live.exerciseGoal {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "figure.run",
                title: Copy.Home.SmartAction.fitnessGapTitle(remaining),
                subtitle: Copy.Home.SmartAction.fitnessGapSubtitle,
                rationale: Copy.Home.SmartAction.fitnessGapRationale(remaining)
            )
        }

        if analysis.userFocuses.contains(.heartHealth),
           let restingHeartRate = live.latestRestingHeartRate,
           let baselineMean = analysis.restingHeartRateBaselineMean,
           restingHeartRate > baselineMean * 1.05 {
            return Recommendation(
                icon: "heart.fill",
                title: Copy.Home.SmartAction.restingHRUpTitle,
                subtitle: Copy.Home.SmartAction.restingHRUpSubtitle,
                rationale: Copy.Home.SmartAction.restingHRUpRationale(currentRHR: Int(restingHeartRate), baselineRHR: Int(baselineMean))
            )
        }

        if analysis.userFocuses.contains(.recovery),
           let readiness = live.readinessScore,
           readiness < 60 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: Copy.Home.SmartAction.focusRecoveryTitle,
                subtitle: Copy.Home.SmartAction.focusRecoverySubtitle(readiness),
                rationale: Copy.Home.SmartAction.focusRecoveryRationale
            )
        }

        return nil
    }

    private func icon(for type: InterventionCandidate.ActionType) -> String {
        switch type {
        case .sleepEarlier, .sleepLater, .extendSleep: return "moon.zzz.fill"
        case .reduceScreenTime, .reduceEvening: return "moon.fill"
        case .activeRecovery: return "figure.mind.and.body"
        case .intensifyExercise: return "bolt.heart.fill"
        case .reduceExercise: return "figure.cooldown"
        case .shiftCaffeineTiming, .reduceCaffeine: return "cup.and.saucer.fill"
        case .breathingSession: return "wind"
        case .meditation: return "brain.head.profile"
        case .adjustMealTiming: return "fork.knife"
        case .hydration: return "drop.fill"
        case .increaseSteps: return "figure.walk"
        case .reduceSteps: return "figure.stand"
        case .napRecommendation: return "bed.double.fill"
        }
    }

    private static func formatHoursMinutes(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        if wholeHours == 0 { return "\(minutes)m" }
        return "\(wholeHours)h \(String(format: "%02d", minutes))m"
    }
}
