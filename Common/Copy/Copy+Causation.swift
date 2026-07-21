import Foundation

extension Copy {
    /// WHOOP-style causation narrative templates.
    /// These build data-backed "because X happened" sentences from InsightContext.
    enum Causation {

        // MARK: - Root Cause Sentences

        /// "Your HRV dropped 18% because deep sleep was low 2 nights ago."
        static func rootCauseSentence(
            metricName: String,
            deviationPercent: Double,
            trend: TrendDirection,
            rootCauseName: String,
            rootCauseDeviation: Double,
            dayOffset: Int
        ) -> String {
            let absDeviation = String(format: "%.0f", abs(deviationPercent))
            let rootCauseAbs = String(format: "%.0f", abs(rootCauseDeviation))
            let verb = trendVerb(trend: trend, deviation: deviationPercent)
            let rootDirection = rootCauseDeviation < 0 ? "low" : "high"
            let timing = timingPhrase(dayOffset: dayOffset)

            return "Your \(metricName.lowercased()) \(verb) \(absDeviation)% because your \(rootCauseName.lowercased()) was \(rootDirection) (\(rootCauseAbs)% off your usual)\(timing)."
        }

        /// Builds the "the last N times that happened, X followed" evidence sentence.
        /// "The last 4 times your deep sleep was this low, your HRV dropped the next day."
        static func patternEvidenceSentence(
            rootCauseName: String,
            rootCauseDirection: String,
            sampleCount: Int,
            metricName: String,
            metricDirection: String
        ) -> String {
            "The last \(sampleCount) times your \(rootCauseName.lowercased()) was this \(rootCauseDirection), your \(metricName.lowercased()) \(metricDirection)."
        }

        /// "Based on 45 days of your data."
        static func dataDepthSentence(dataPoints: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_data_depth_sentence", default: "Based on %d days of your data."), dataPoints)
        }

        // MARK: - Correlated Factor Sentences

        /// "Your deep sleep and HRV are connected. The last 12 times deep sleep dropped, HRV followed within 1 day."
        static func correlatedFactorSentence(
            factorName: String,
            metricName: String,
            sampleCount: Int,
            dayOffset: Int,
            effectPercent: Double
        ) -> String {
            let timing = dayOffset <= 0
                ? "the same day"
                : dayOffset == 1 ? "within 1 day" : "within \(dayOffset) days"
            let impact = String(format: "%.0f", abs(effectPercent))
            return "Your \(factorName.lowercased()) and \(metricName.lowercased()) are linked. The last \(sampleCount) times \(factorName.lowercased()) shifted, \(metricName.lowercased()) moved about \(impact)% \(timing)."
        }

        // MARK: - Confidence and Percentile Sentences

        /// "This is in the bottom 10% of your history."
        static func percentileSentence(percentile: Double) -> String {
            let pct = Int(percentile.rounded())
            if pct <= 20 {
                return String(format: RemoteConfigManager.shared.copyString("copy_causation_percentile_bottom", default: "This is in the bottom %d%% of your history."), pct)
            } else if pct >= 80 {
                return String(format: RemoteConfigManager.shared.copyString("copy_causation_percentile_top", default: "This is in the top %d%% of your history."), 100 - pct)
            }
            return ""
        }

        /// "Your data confidence is still building. Keep syncing daily."
        static var lowConfidenceNote: String { RemoteConfigManager.shared.copyString("copy_causation_low_confidence_note", default: "Your data is still building. Keep syncing daily so your insights get more personal.") }

        // MARK: - Positive Causation (Improving)

        /// "Your HRV improved 12% and your deep sleep was above average 3 of the last 5 nights."
        static func improvementCauseSentence(
            metricName: String,
            deviationPercent: Double,
            rootCauseName: String,
            rootCauseDeviation: Double
        ) -> String {
            let absDeviation = String(format: "%.0f", abs(deviationPercent))
            let rootAbs = String(format: "%.0f", abs(rootCauseDeviation))
            return "Your \(metricName.lowercased()) improved \(absDeviation)% and your \(rootCauseName.lowercased()) was \(rootAbs)% above your usual recently."
        }

        // MARK: - Projection with Causation

        /// "At this rate, your HRV could reach warning level in about 5 days. The main driver is your sleep quality."
        static func projectionWithCause(
            metricName: String,
            days: Int,
            rootCauseName: String
        ) -> String {
            "At this rate, your \(metricName.lowercased()) could reach warning level in about \(days) days. The main reason is your \(rootCauseName.lowercased())."
        }

        /// "At this pace, this could hit a warning level in about N days."
        static func projectionWithoutCause(metricName: String, days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_projection_without_cause", default: "At this rate, your %@ could reach warning level in about %d days."), metricName.lowercased(), days)
        }

        // MARK: - Week Comparison with Causation

        /// "Down 8% from last week, mostly because your exercise dropped."
        static func weekComparisonWithCause(
            changePercent: Double,
            rootCauseName: String
        ) -> String {
            let direction = changePercent > 0 ? "Up" : "Down"
            let absChange = String(format: "%.0f", abs(changePercent))
            return "\(direction) \(absChange)% from last week, mostly because your \(rootCauseName.lowercased()) shifted."
        }

        /// "Down 8% from last week."
        static func weekComparisonSimple(changePercent: Double) -> String {
            let direction = changePercent > 0
                ? RemoteConfigManager.shared.copyString("copy_causation_direction_up", default: "Up")
                : RemoteConfigManager.shared.copyString("copy_causation_direction_down", default: "Down")
            let absChange = String(format: "%.0f", abs(changePercent))
            return String(format: RemoteConfigManager.shared.copyString("copy_causation_week_comparison_simple", default: "%@ %@%% from last week."), direction, absChange)
        }

        // MARK: - Reversal Sentences

        /// "Your HRV is turning around. The last 3 times this happened after deep sleep improved, it took about 2 days to recover."
        static func reversalWithContext(
            metricName: String,
            isPositive: Bool,
            rootCauseName: String?,
            sampleCount: Int?
        ) -> String {
            if isPositive, let cause = rootCauseName, let count = sampleCount {
                return "Your \(metricName.lowercased()) is turning around. The last \(count) times this happened after \(cause.lowercased()) improved, recovery followed."
            } else if !isPositive, let cause = rootCauseName {
                return "Your \(metricName.lowercased()) was improving but just reversed. Your \(cause.lowercased()) may be the reason."
            } else if isPositive {
                return "Your \(metricName.lowercased()) just turned upward. Whatever you changed recently is working."
            } else {
                return "Your \(metricName.lowercased()) was improving but just reversed direction."
            }
        }

        // MARK: - Reversal Recommendation Sentences

        static func reversalRecoveringWithCause(metricName: String, current: String, unit: String, previous: String, causeName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_reversal_recovering_with_cause", default: "Your %@ is recovering, now %@ %@ vs %@ %@ previously. Keep your %@ consistent."), metricName.lowercased(), current, unit, previous, unit, causeName.lowercased())
        }

        static func reversalRecovering(metricName: String, current: String, unit: String, previous: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_reversal_recovering", default: "Your %@ is recovering, now %@ %@ vs %@ %@ previously."), metricName.lowercased(), current, unit, previous, unit)
        }

        static func reversalDeclinedWithCause(metricName: String, causeName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_reversal_declined_with_cause", default: "Your %@ reversed direction. Focus on your %@ to get back on track."), metricName.lowercased(), causeName.lowercased())
        }

        static func reversalDeclined(metricName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_reversal_declined", default: "Your %@ reversed direction. Review what changed in the past few days."), metricName.lowercased())
        }

        // MARK: - Title Patterns (Causation Style)

        /// "HRV Dropped, Sleep Is Why"
        static func causationTitle(metricName: String, rootCauseName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_causation_title", default: "%@ Shifted, %@ Is Why"), metricName, rootCauseName)
        }

        /// "HRV Improving, Sleep Helped"
        static func improvingCausationTitle(metricName: String, rootCauseName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_improving_causation_title", default: "%@ Improving, %@ Helped"), metricName, rootCauseName)
        }

        // MARK: - Chain Engine Narratives

        static var directionIncreased: String { RemoteConfigManager.shared.copyString("copy_causation_direction_increased", default: "increased") }
        static var directionDecreased: String { RemoteConfigManager.shared.copyString("copy_causation_direction_decreased", default: "decreased") }
        static var directionDropped: String { RemoteConfigManager.shared.copyString("copy_causation_direction_dropped", default: "dropped") }
        static var directionRose: String { RemoteConfigManager.shared.copyString("copy_causation_direction_rose", default: "rose") }
        static var directionRising: String { RemoteConfigManager.shared.copyString("copy_causation_direction_rising", default: "rising") }
        static var directionDropping: String { RemoteConfigManager.shared.copyString("copy_causation_direction_dropping", default: "dropping") }
        static var directionLess: String { RemoteConfigManager.shared.copyString("copy_causation_direction_less", default: "less") }
        static var directionMore: String { RemoteConfigManager.shared.copyString("copy_causation_direction_more", default: "more") }
        static var directionLower: String { RemoteConfigManager.shared.copyString("copy_causation_direction_lower", default: "lower") }
        static var directionHigher: String { RemoteConfigManager.shared.copyString("copy_causation_direction_higher", default: "higher") }
        static var directionPushedUp: String { RemoteConfigManager.shared.copyString("copy_causation_direction_pushed_up", default: "pushed up") }
        static var directionBroughtDown: String { RemoteConfigManager.shared.copyString("copy_causation_direction_brought_down", default: "brought down") }
        static var directionReduced: String { RemoteConfigManager.shared.copyString("copy_causation_direction_reduced", default: "reduced") }
        static var directionElevated: String { RemoteConfigManager.shared.copyString("copy_causation_direction_elevated", default: "elevated") }
        static var strengthStrong: String { RemoteConfigManager.shared.copyString("copy_causation_strength_strong", default: "strong") }
        static var strengthModerate: String { RemoteConfigManager.shared.copyString("copy_causation_strength_moderate", default: "moderate") }

        static var timeThisWeek: String { RemoteConfigManager.shared.copyString("copy_causation_time_this_week", default: "this week") }
        static var timePastFewDays: String { RemoteConfigManager.shared.copyString("copy_causation_time_past_few_days", default: "over the past few days") }
        static func timePastDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_causation_time_past_days", default: "over the past %d days"), days) }
        static var timePastWeek: String { RemoteConfigManager.shared.copyString("copy_causation_time_past_week", default: "over the past week") }
        static func timeInPastDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_causation_time_in_past_days", default: " in the past %d days"), days) }

        static func chainEffectOpening(effect: String, direction: String, dev: String, timeFrame: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_effect_opening", default: "Your %@ %@ %@ %@. "), effect, direction, dev, timeFrame)
        }
        static func chainConnectedTo(cause: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_connected_to", default: "Based on your personal data, this appears most likely connected to your %@ "), cause)
        }
        static func chainCauseChange(change: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_cause_change", default: "%@ %@"), change, dev)
        }
        static func chainBaselineParenthetical(baseline: String, unit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_baseline_parenthetical", default: " (from your usual %@ %@)"), baseline, unit)
        }
        static func chainPersonalPattern(strength: String, r: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_personal_pattern", default: "Your data shows a %@ personal pattern between these two (r=%@)"), strength, r)
        }
        static var chainNextDay: String { RemoteConfigManager.shared.copyString("copy_causation_chain_next_day", default: "the next day") }
        static func chainAfterDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_after_days", default: "after %d days"), days) }
        static func chainEffectsAppearing(_ phrase: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_effects_appearing", default: " with effects typically showing %@"), phrase) }

        static func twoLinkOpening(affected: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_opening", default: "Your %@ %@ %@ this week. "), affected, direction, dev)
        }
        static func twoLinkConnected(intermediate: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_connected", default: "This appears connected to your %@. "), intermediate)
        }
        static func twoLinkIntermediateOver(intermediate: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_intermediate_over", default: "your %@ %@ %@ over the same period. "), intermediate, direction, dev)
        }
        static func twoLinkIntermediateRecent(intermediate: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_intermediate_recent", default: "your %@ %@ %@ recently. "), intermediate, direction, dev)
        }
        static func twoLinkRootDeeper(root: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_root_deeper", default: "Looking deeper, your %@ %@ %@"), root, direction, dev)
        }
        static func twoLinkCorrelation(intermediateChange: String, intermediate: String, r: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_correlation", default: ", which usually moves with %@ %@ for you (r=%@). "), intermediateChange, intermediate, r)
        }
        static func twoLinkChainPunchline(rootDir: String, root: String, intermDir: String, intermediate: String, affDir: String, affected: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_two_link_chain_punchline", default: "The likely chain: %@ %@ -> %@ %@ -> %@ %@."), rootDir, root, intermDir, intermediate, affDir, affected)
        }

        static var threeLinkCascade: String { RemoteConfigManager.shared.copyString("copy_causation_three_link_cascade", default: "Your data suggests a chain of connected changes. ") }
        static func threeLinkRootStarted(root: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_three_link_root_started", default: "It started with your %@, which %@ %@. "), root, direction, dev)
        }
        static func threeLinkMidEffect(verb: String, midEffect: String, direction: String, dev: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_three_link_mid_effect", default: "That appears to have %@ your %@ (%@ %@). "), verb, midEffect, direction, dev)
        }
        static func threeLinkFinalEffect(finalCause: String, direction: String, affected: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_three_link_final_effect", default: "In turn, the change in %@ likely %@ your %@. "), finalCause, direction, affected)
        }
        static func threeLinkChainSummary(_ chain: String, _ affDir: String, _ affected: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_three_link_chain_summary", default: "Likely chain: %@ -> %@ %@."), chain, affDir, affected)
        }
        static func chainCauseDirNoun(direction: String, cause: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_causation_chain_cause_dir_noun", default: "%@ %@"), direction, cause)
        }

        // MARK: - Helpers

        private static func trendVerb(trend: TrendDirection, deviation: Double) -> String {
            switch trend {
            case .declining: return "dropped"
            case .improving: return "improved"
            case .stable: return deviation > 0 ? "rose" : "shifted"
            }
        }

        private static func timingPhrase(dayOffset: Int) -> String {
            if dayOffset <= 0 { return "" }
            if dayOffset == 1 { return " yesterday" }
            return " \(dayOffset) days ago"
        }
    }
}
