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
        /// The score the recovery hero card on the same screen is showing: live
        /// readiness, or the daily score when readiness is missing. Nil means no
        /// caller supplied it, which leaves the recovery gate off rather than
        /// grading a band from a guessed number.
        var heroRecoveryScore: Int? = nil
    }

    struct AnalysisSnapshot {
        let policyDecision: PolicyDecision?
        let restingHeartRateBaselineMean: Double?
        let userFocuses: Set<HealthFocus>
        let topInsights: [Insight]
        /// A rest context the user switched on, e.g. injured or unwell. Nil when
        /// none is active.
        var restContext: LifeContextStore.Context?
        /// The running sleep balance in hours. Zero when it is too small to act
        /// on or there are not enough recorded nights to know.
        var sleepDebtHours: Double = 0
        /// True only while the last three nights are worse than the three before
        /// them. A balance that is merely large is a standing fact about how
        /// this person sleeps; a growing one is today's news.
        var sleepDebtIsGrowing: Bool = false
    }

    struct Recommendation: Equatable {
        let icon: String
        let title: String
        let subtitle: String
        var source: String = "context_rules"
        /// True when the action asks for more intensity. Read only by the
        /// recovery gate in `recommend`, so every rung that can ask a person to
        /// push is vetoed in one place instead of each guarding itself.
        var isPushDirection: Bool = false

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.icon == rhs.icon && lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle && lhs.source == rhs.source
        }
    }

    /// Icons the advisor only assigns to bedtime and wind-down actions. The
    /// evening gate keys on what the action IS, not on the reminder hour: a
    /// walk at noon is honestly done at noon.
    static let eveningAnchoredIcons: Set<String> = ["bed.double.fill", "moon.zzz.fill", "moon.fill"]

    /// `daytimeOnly` drops every bedtime rung so the brief's day move can never
    /// be "get to bed early"; the night move owns bedtime. False keeps the
    /// original chain untouched.
    func recommend(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot,
        daytimeOnly: Bool = false
    ) -> Recommendation {
        let candidate = chooseRecommendation(live: live, analysis: analysis, daytimeOnly: daytimeOnly)
        // One veto, at the exit. The policy engine is not the only rung that
        // can ask for more intensity — both insight rungs and the fitness-focus
        // rung do too — so guarding one of them left the same contradiction
        // reachable: a red recovery hero and "push harder" on the card below
        // it. Both sides band the hero's own score through DS.recoveryTier, the
        // app's one readiness table. A nil hero score leaves the gate off
        // rather than grading a band from a number nobody supplied.
        if candidate.isPushDirection,
           let heroScore = live.heroRecoveryScore,
           DS.recoveryTier(for: heroScore) == .poor {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: Copy.Home.SmartAction.lowReadinessTitle,
                subtitle: Copy.Home.SmartAction.doActiveRecovery,
                source: "recovery_gate"
            )
        }
        return candidate
    }

    private func chooseRecommendation(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot,
        daytimeOnly: Bool
    ) -> Recommendation {
        // 0. A rest context the user set beats every signal below it. The body
        // data cannot see a sprained ankle, so without this a strong recovery
        // score tells an injured person to push harder.
        if let rest = analysis.restContext {
            return Recommendation(
                icon: rest.systemImage,
                title: Copy.Home.contextRestTitle,
                subtitle: Copy.Home.contextRestSubtitle(rest.displayName.lowercasedFirst),
                source: "life_context"
            )
        }

        // 0b. A sleep balance that is actively getting worse. It ranks above the
        // model because the model scores today in isolation: a good-looking
        // morning after five short nights still produced "push a little harder",
        // which is exactly the advice that keeps the hole open.
        //
        // Gated on the balance growing, not merely existing. Anyone who sleeps
        // under the 7.5 hour floor carries a standing balance, so without this
        // the daily action would read "get to bed early" every day forever and
        // stop being an action at all.
        if !daytimeOnly, analysis.sleepDebtIsGrowing, analysis.sleepDebtHours >= SleepDebtTracker.actionableDebtHours {
            let amount = analysis.sleepDebtHours.hoursAsClock
            let nights = SleepDebtTracker.nightsToClear(debtHours: analysis.sleepDebtHours)
            return Recommendation(
                icon: "bed.double.fill",
                title: Copy.Home.sleepBankActionTitle,
                subtitle: nights <= SleepDebtTracker.paybackNightsWorthQuoting
                    ? Copy.Home.sleepBankActionSubtitle(amount, nights)
                    : Copy.Home.sleepBankActionSubtitleLong(amount),
                source: "sleep_bank"
            )
        }

        // 1. ML policy engine. highest quality, fully personalized
        if let r = daytime(recommendFromPolicyEngine(analysis: analysis), daytimeOnly) { return r }

        // 2. Insight-driven. derive action from the highest-priority insight
        if let r = daytime(recommendFromHighPriorityInsight(analysis: analysis, daytimeOnly: daytimeOnly), daytimeOnly) { return r }

        // 3. Live-data rules (only when data signals something notable)
        if let r = daytime(recommendFromLiveDataRules(live: live), daytimeOnly) { return r }

        // 4. Any insight available. use it
        if let topInsight = analysis.topInsights.first,
           let r = daytime(insightDrivenRecommendation(topInsight, daytimeOnly: daytimeOnly), daytimeOnly) { return r }

        // 5. Focus-aware rules
        if let focusAction = focusAwareRecommendation(live: live, analysis: analysis, daytimeOnly: daytimeOnly) {
            return focusAction
        }

        // 6. Activity progress
        if let r = recommendFromActivityProgress(live: live) { return r }

        // 7. Late-hour wind-down
        if !daytimeOnly, let r = recommendLateHourWindDown(live: live) { return r }

        // 8. Default fallback
        return Recommendation(
            icon: "figure.walk",
            title: Copy.Home.SmartAction.defaultTitle,
            subtitle: Copy.Home.SmartAction.defaultSubtitle
        )
    }

    // MARK: - Recommendation Sources

    /// Under `daytimeOnly` an evening-anchored result is skipped so the chain
    /// falls through to the next rung instead of surfacing a bedtime.
    private func daytime(_ r: Recommendation?, _ daytimeOnly: Bool) -> Recommendation? {
        guard let r, daytimeOnly, Self.eveningAnchoredIcons.contains(r.icon) else { return r }
        return nil
    }

    private func recommendFromPolicyEngine(analysis: AnalysisSnapshot) -> Recommendation? {
        guard let decision = analysis.policyDecision,
              decision.decisionConfidence >= 0.3 else { return nil }
        // The headline is the action itself, not `decision.prescriptiveHeadline`:
        // that string comes from the recovery state bucket, so it could announce
        // strong recovery while the sentence below reported a metric 91% below
        // baseline. Card title and card reason now describe the same thing.
        return Recommendation(
            icon: icon(for: decision.primaryAction.candidate.actionType),
            title: actionTitle(for: decision.primaryAction.candidate.actionType),
            subtitle: decision.primaryAction.description,
            source: "policy_engine",
            isPushDirection: decision.primaryAction.candidate.actionType == .intensifyExercise
        )
    }

    private func recommendFromHighPriorityInsight(analysis: AnalysisSnapshot, daytimeOnly: Bool) -> Recommendation? {
        guard let topInsight = analysis.topInsights.first,
              topInsight.severity >= .warning || topInsight.priorityScore > 3.0 else { return nil }
        return insightDrivenRecommendation(topInsight, daytimeOnly: daytimeOnly)
    }

    private func recommendFromLiveDataRules(live: LiveSnapshot) -> Recommendation? {
        if let stress = live.stressLevel, stress >= 60 {
            return Recommendation(
                icon: "wind",
                title: Copy.Home.SmartAction.highStressTitle,
                subtitle: Copy.Home.SmartAction.highStressSubtitle
            )
        }

        if live.hasSleepData, live.sleepHours < 5.5 {
            return Recommendation(
                icon: "moon.zzz.fill",
                title: Copy.Home.SmartAction.lowSleepTitle,
                subtitle: Copy.Home.SmartAction.lowSleepSubtitle(Self.formatHoursMinutes(live.sleepHours))
            )
        }

        if let readiness = live.readinessScore, readiness < 40 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: Copy.Home.SmartAction.lowReadinessTitle,
                subtitle: Copy.Home.SmartAction.lowReadinessSubtitle(readiness)
            )
        }

        return nil
    }

    private func recommendFromActivityProgress(live: LiveSnapshot) -> Recommendation? {
        if live.exerciseMinutes >= live.exerciseGoal {
            return Recommendation(
                icon: "checkmark.seal.fill",
                title: Copy.Home.SmartAction.exerciseGoalTitle,
                subtitle: Copy.Home.SmartAction.exerciseGoalSubtitle(Int(live.exerciseMinutes))
            )
        }

        if let readiness = live.readinessScore, readiness >= 60 {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "bolt.heart.fill",
                title: Copy.Home.SmartAction.minutesToGoTitle(remaining),
                subtitle: Copy.Home.SmartAction.minutesToGoSubtitle
            )
        }

        return nil
    }

    private func recommendLateHourWindDown(live: LiveSnapshot) -> Recommendation? {
        guard live.hour >= 20 else { return nil }
        return Recommendation(
            icon: "moon.fill",
            title: Copy.Home.SmartAction.windDownTitle,
            subtitle: Copy.Home.SmartAction.windDownSubtitle
        )
    }

    // MARK: - Insight → Action

    /// nil when the insight carries no action we can phrase for a person, so the caller falls through to the next rule
    private func insightDrivenRecommendation(_ insight: Insight, daytimeOnly: Bool) -> Recommendation? {
        // A sleep directive on a non-sleep metric carries a non-bedtime icon,
        // so the icon gate alone would let "sleep better" through as a day move.
        if daytimeOnly, insight.directive == .sleepMore || insight.directive == .sleepBetter { return nil }
        let icon = insight.metric.systemImageName

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
            isPushDirection: insight.directive == .increaseActivity || insight.directive == .pushHarder
        )
    }

    private func focusAwareRecommendation(
        live: LiveSnapshot,
        analysis: AnalysisSnapshot,
        daytimeOnly: Bool
    ) -> Recommendation? {
        guard !analysis.userFocuses.isEmpty else { return nil }

        if !daytimeOnly, analysis.userFocuses.contains(.sleep), live.hasSleepData {
            if live.deepSleepMinutes < 45 {
                return Recommendation(
                    icon: "moon.zzz.fill",
                    title: Copy.Home.SmartAction.deepSleepTitle,
                    subtitle: Copy.Home.SmartAction.deepSleepSubtitle(Int(live.deepSleepMinutes))
                )
            }
            if live.sleepHours < 7 {
                return Recommendation(
                    icon: "bed.double.fill",
                    title: Copy.Home.SmartAction.earlyBedTitle,
                    subtitle: Copy.Home.SmartAction.earlyBedSubtitle(Self.formatHoursMinutes(live.sleepHours))
                )
            }
        }

        if analysis.userFocuses.contains(.fitness), live.exerciseMinutes < live.exerciseGoal {
            let remaining = Int(live.exerciseGoal - live.exerciseMinutes)
            return Recommendation(
                icon: "figure.run",
                title: Copy.Home.SmartAction.fitnessGapTitle(remaining),
                subtitle: Copy.Home.SmartAction.fitnessGapSubtitle,
                isPushDirection: true
            )
        }

        if analysis.userFocuses.contains(.heartHealth),
           let restingHeartRate = live.latestRestingHeartRate,
           let baselineMean = analysis.restingHeartRateBaselineMean,
           restingHeartRate > baselineMean * 1.05 {
            return Recommendation(
                icon: "heart.fill",
                title: Copy.Home.SmartAction.restingHRUpTitle,
                subtitle: Copy.Home.SmartAction.restingHRUpSubtitle
            )
        }

        if analysis.userFocuses.contains(.recovery),
           let readiness = live.readinessScore,
           readiness < 60 {
            return Recommendation(
                icon: "figure.mind.and.body",
                title: Copy.Home.SmartAction.focusRecoveryTitle,
                subtitle: Copy.Home.SmartAction.focusRecoverySubtitle(readiness)
            )
        }

        return nil
    }

    /// Verb-first headline for a policy action, so the card reads as one thing
    /// to do and the Mark done button has something to mark.
    private func actionTitle(for type: InterventionCandidate.ActionType) -> String {
        switch type {
        case .sleepEarlier:         return Copy.Home.SmartAction.doSleepEarlier
        case .sleepLater:           return Copy.Home.SmartAction.doSleepLater
        case .extendSleep:          return Copy.Home.SmartAction.doExtendSleep
        case .reduceScreenTime:     return Copy.Home.SmartAction.doReduceScreenTime
        case .reduceEvening:        return Copy.Home.SmartAction.doReduceEvening
        case .activeRecovery:       return Copy.Home.SmartAction.doActiveRecovery
        case .intensifyExercise:    return Copy.Home.SmartAction.doIntensifyExercise
        case .reduceExercise:       return Copy.Home.SmartAction.doReduceExercise
        case .shiftCaffeineTiming:  return Copy.Home.SmartAction.doShiftCaffeineTiming
        case .reduceCaffeine:       return Copy.Home.SmartAction.doReduceCaffeine
        case .breathingSession:     return Copy.Home.SmartAction.doBreathingSession
        case .meditation:           return Copy.Home.SmartAction.doMeditation
        case .adjustMealTiming:     return Copy.Home.SmartAction.doAdjustMealTiming
        case .hydration:            return Copy.Home.SmartAction.doHydration
        case .increaseSteps:        return Copy.Home.SmartAction.doIncreaseSteps
        case .reduceSteps:          return Copy.Home.SmartAction.doReduceSteps
        case .napRecommendation:    return Copy.Home.SmartAction.doNap
        }
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
