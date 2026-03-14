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
    }

    struct Recommendation: Equatable {
        let icon: String
        let title: String
        let subtitle: String
        var source: String = "context_rules"
    }

    func recommend(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot
    ) -> Recommendation {
        if let decision = analysis.policyDecision,
           decision.decisionConfidence >= 0.3 {
            return Recommendation(
                icon: icon(for: decision.primaryAction.candidate.actionType),
                title: decision.prescriptiveHeadline,
                subtitle: decision.primaryAction.description,
                source: "policy_engine"
            )
        }

        if let stress = live.stressLevel, stress >= 60 {
            return Recommendation(
                icon: "wind",
                title: "Take 5 min to breathe",
                subtitle: "Stress is elevated — box breathing (4-4-4-4) can lower it fast"
            )
        }

        if live.hasSleepData, live.sleepHours < 5.5 {
            return Recommendation(
                icon: "moon.zzz.fill",
                title: "Go easy today",
                subtitle: "Only \(Self.formatHoursMinutes(live.sleepHours)) of sleep — skip intense workouts"
            )
        }

        if let readiness = live.readinessScore, readiness < 40 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: "Prioritize recovery",
                subtitle: "Readiness is \(readiness)% — stretching or yoga only today"
            )
        }

        if let focusAction = focusAwareRecommendation(live: live, analysis: analysis) {
            return focusAction
        }

        if live.exerciseMinutes >= live.exerciseGoal {
            return Recommendation(
                icon: "checkmark.seal.fill",
                title: "Exercise goal reached!",
                subtitle: "\(Int(live.exerciseMinutes)) min today — stay active and hydrate"
            )
        }

        if let readiness = live.readinessScore, readiness >= 60 {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "bolt.heart.fill",
                title: "You have \(remaining) min to go",
                subtitle: "Recovery is strong — a run or workout would be great"
            )
        }

        if live.hour >= 20 {
            return Recommendation(
                icon: "moon.fill",
                title: "Wind down for sleep",
                subtitle: "Dim screens and skip caffeine for better rest"
            )
        }

        return Recommendation(
            icon: "figure.walk",
            title: "Take a 15 min walk",
            subtitle: "A short walk boosts mood and energy"
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
                    subtitle: "Only \(Int(live.deepSleepMinutes)) min of deep sleep — try cutting caffeine after 2 PM"
                )
            }
            if live.sleepHours < 7 {
                return Recommendation(
                    icon: "bed.double.fill",
                    title: "Get to bed 30 min earlier",
                    subtitle: "\(Self.formatHoursMinutes(live.sleepHours)) last night — aim for 7+ hours"
                )
            }
        }

        if analysis.userFocuses.contains(.fitness), live.exerciseMinutes < live.exerciseGoal {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "figure.run",
                title: "You're \(remaining) min from your goal",
                subtitle: "A brisk walk or quick workout would close the gap"
            )
        }

        if analysis.userFocuses.contains(.heartHealth),
           let restingHeartRate = live.latestRestingHeartRate,
           let baselineMean = analysis.restingHeartRateBaselineMean,
           restingHeartRate > baselineMean * 1.05 {
            return Recommendation(
                icon: "heart.fill",
                title: "Your resting HR is trending up",
                subtitle: "Try 10 min of meditation or deep breathing to bring it down"
            )
        }

        if analysis.userFocuses.contains(.recovery),
           let readiness = live.readinessScore,
           readiness < 60 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: "Focus on recovery today",
                subtitle: "Readiness is \(readiness)% — light stretching and hydration will help"
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
