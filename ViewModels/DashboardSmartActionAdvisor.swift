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
        if let decision = analysis.policyDecision,
           decision.decisionConfidence >= 0.3 {
            return Recommendation(
                icon: icon(for: decision.primaryAction.candidate.actionType),
                title: decision.prescriptiveHeadline,
                subtitle: decision.primaryAction.description,
                source: "policy_engine",
                rationale: decision.primaryAction.whyItMatters
            )
        }

        // 2. Insight-driven. derive action from the highest-priority insight
        if let topInsight = analysis.topInsights.first,
           topInsight.severity >= .warning || topInsight.priorityScore > 3.0 {
            return insightDrivenRecommendation(topInsight)
        }

        // 3. Live-data rules (only when data signals something notable)
        if let stress = live.stressLevel, stress >= 60 {
            return Recommendation(
                icon: "wind",
                title: "Your stress is elevated right now",
                subtitle: "Box breathing (4-4-4-4) for 5 min can bring it down. your body is asking for a reset",
                rationale: "Real-time stress reading is \(stress)%, which is above your comfortable range."
            )
        }

        if live.hasSleepData, live.sleepHours < 5.5 {
            return Recommendation(
                icon: "moon.zzz.fill",
                title: "Go easy today",
                subtitle: "Only \(Self.formatHoursMinutes(live.sleepHours)) of sleep. skip intense workouts, your body needs to conserve",
                rationale: "You got significantly less sleep than your body needs. High-intensity effort today would compound the deficit."
            )
        }

        if let readiness = live.readinessScore, readiness < 40 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: "Recovery day. your body needs it",
                subtitle: "Readiness is \(readiness)%. stretching or yoga only",
                rationale: "Multiple signals (HRV, resting HR, sleep) indicate your body hasn't recovered from recent strain."
            )
        }

        // 4. Any insight available. use it
        if let topInsight = analysis.topInsights.first {
            return insightDrivenRecommendation(topInsight)
        }

        // 5. Focus-aware rules
        if let focusAction = focusAwareRecommendation(live: live, analysis: analysis) {
            return focusAction
        }

        // 6. Activity progress
        if live.exerciseMinutes >= live.exerciseGoal {
            return Recommendation(
                icon: "checkmark.seal.fill",
                title: "Exercise goal reached!",
                subtitle: "\(Int(live.exerciseMinutes)) min today. stay active and hydrate",
                rationale: "You've already hit your daily exercise target."
            )
        }

        if let readiness = live.readinessScore, readiness >= 60 {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "bolt.heart.fill",
                title: "You have \(remaining) min to go",
                subtitle: "Recovery is strong. a run or workout would be great",
                rationale: "Your body is well-recovered and ready for effort. Closing the exercise gap today would build momentum."
            )
        }

        if live.hour >= 20 {
            return Recommendation(
                icon: "moon.fill",
                title: "Wind down for sleep",
                subtitle: "Dim screens and skip caffeine for better rest tonight",
                rationale: "It's late evening. Limiting blue light and stimulants now directly improves tonight's sleep quality."
            )
        }

        return Recommendation(
            icon: "figure.walk",
            title: "Get moving for 15 minutes",
            subtitle: "A short walk boosts mood, energy, and sleep quality tonight",
            rationale: "No specific signals today. a walk is the single highest-ROI activity for overall health."
        )
    }

    // MARK: - Insight → Action

    private func insightDrivenRecommendation(_ insight: Insight) -> Recommendation {
        let icon = insight.metric.systemImageName
        let rationale = insight.summary

        // Use the insight's actionable recommendation as the subtitle
        let subtitle = insight.actionSummary

        // Build a specific, data-grounded title
        let title: String
        switch insight.directive {
        case .rest, .reduceIntensity:
            title = "Ease off. \(insight.metric.displayName) needs attention"
        case .increaseActivity, .pushHarder:
            title = "Push harder. \(insight.metric.displayName) is ready"
        case .sleepMore, .sleepBetter:
            title = "Improve your sleep tonight"
        case .seekMedical:
            title = "\(insight.metric.displayName). worth checking"
        case .maintain:
            title = "Keep it up. \(insight.metric.displayName) is solid"
        case .informational:
            title = insight.title
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
                    title: "Boost your deep sleep",
                    subtitle: "Only \(Int(live.deepSleepMinutes)) min of deep sleep. try cutting caffeine after 2 PM",
                    rationale: "Deep sleep is when your body repairs muscle, consolidates memory, and regulates hormones. You're getting less than the 45-minute threshold."
                )
            }
            if live.sleepHours < 7 {
                return Recommendation(
                    icon: "bed.double.fill",
                    title: "Get to bed 30 min earlier",
                    subtitle: "\(Self.formatHoursMinutes(live.sleepHours)) last night. aim for 7+ hours",
                    rationale: "Sleep is your top focus area and you're falling short. Even 30 minutes more makes a measurable difference."
                )
            }
        }

        if analysis.userFocuses.contains(.fitness), live.exerciseMinutes < live.exerciseGoal {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "figure.run",
                title: "You're \(remaining) min from your goal",
                subtitle: "A brisk walk or quick workout would close the gap",
                rationale: "Fitness is your focus area and you have \(remaining) minutes left to hit today's target."
            )
        }

        if analysis.userFocuses.contains(.heartHealth),
           let restingHeartRate = live.latestRestingHeartRate,
           let baselineMean = analysis.restingHeartRateBaselineMean,
           restingHeartRate > baselineMean * 1.05 {
            return Recommendation(
                icon: "heart.fill",
                title: "Your resting HR is trending up",
                subtitle: "Try 10 min of meditation or deep breathing to bring it down",
                rationale: "Your resting heart rate is \(Int(restingHeartRate)) bpm. above your baseline of \(Int(baselineMean)) bpm. This could signal incomplete recovery or elevated stress."
            )
        }

        if analysis.userFocuses.contains(.recovery),
           let readiness = live.readinessScore,
           readiness < 60 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: "Focus on recovery today",
                subtitle: "Readiness is \(readiness)%. light stretching and hydration will help",
                rationale: "Recovery is your focus area and your readiness score indicates your body hasn't fully bounced back yet."
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
