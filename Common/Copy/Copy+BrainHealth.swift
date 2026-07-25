import Foundation

extension Copy {
    enum BrainHealth {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_title", default: "Brain Health") }

        // MARK: - Factor Labels

        static var factorHRV: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_factor_hrv", default: "HRV") }
        static var factorREM: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_factor_rem", default: "REM Sleep") }
        static var factorDeepSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_factor_deep_sleep", default: "Deep Sleep") }
        static var factorRestingHR: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_factor_resting_hr", default: "Resting HR") }
        static var factorSleepSchedule: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_factor_sleep_schedule", default: "Sleep Schedule") }

        // MARK: - Factor Impact Fragments

        static var directionAbove: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_direction_above", default: "above") }
        static var directionBelow: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_direction_below", default: "below") }
        static var timingConsistent: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_timing_consistent", default: "consistent timing") }
        static var timingIrregular: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_timing_irregular", default: "irregular timing") }

        static func percentAboveBelowBaseline(_ percent: Int, direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_percent_above_below_baseline", default: "%d%% %@ baseline"), percent, direction)
        }
        static func directionBaseline(_ direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_direction_baseline", default: "%@ baseline"), direction)
        }

        // MARK: - Hero

        static var brainHealthLabel: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_label", default: "BRAIN HEALTH") }
        static var heroExplainer: String { RemoteConfigManager.shared.copyString("copy_brain_health_hero_explainer", default: "How sharp and focused your mind is likely to feel today") }
        static var scaleAndDirection: String { RemoteConfigManager.shared.copyString("copy_brain_health_scale_and_direction", default: "out of 100  ·  Higher is sharper") }
        static var scaleSuffix: String { RemoteConfigManager.shared.copyString("copy_brain_health_scale_suffix", default: "/ 100") }

        // MARK: - Headlines (state-driven, with action guidance)

        static var headlineSharpStrong: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_sharp_strong", default: "Strong REM and high HRV. Great day for tough work.") }
        static var headlineSharpHRV: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_sharp_hrv", default: "High HRV shows sharp readiness. Take on hard tasks.") }
        static var headlineSharpSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_sharp_sleep", default: "Excellent sleep recovery. You can handle deep focus today.") }
        static var headlineSharpDefault: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_sharp_default", default: "Signals above your usual. A good day to take on hard problems.") }

        static var headlineFocusedHRV: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_focused_hrv", default: "Good HRV is helping focus. A solid day for steady work.") }
        static var headlineFocusedSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_focused_sleep", default: "Solid sleep recovery. Deep work should feel easier today.") }
        static var headlineFocusedDefault: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_focused_default", default: "Signals look good. Keep your usual work rhythm.") }

        static var headlineBaselineSteady: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_baseline_steady", default: "Signals near your usual range. Stick to routine tasks today.") }
        static var headlineBaselineMixed: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_baseline_mixed", default: "Mixed signals today. Match your effort to how you feel as the day goes on.") }

        static var headlineFoggyBoth: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_foggy_both", default: "HRV is low and REM was short last night. Keep work simple today.") }
        static var headlineFoggyHRV: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_foggy_hrv", default: "HRV is well below your usual. Keep work simple today.") }
        static var headlineFoggySleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_headline_foggy_sleep", default: "Sleep quality was low last night. Keep work simple today.") }

        // MARK: - Sleep Recovery

        static var sleepRecovery: String { RemoteConfigManager.shared.copyString("copy_brain_health_sleep_recovery", default: "Sleep Recovery") }
        static var heartRecovery: String { RemoteConfigManager.shared.copyString("copy_brain_health_heart_recovery", default: "Heart Recovery") }
        static var deepSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_deep_sleep", default: "Deep Sleep") }
        static var remSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_rem_sleep", default: "REM Sleep") }
        static var estimated: String { RemoteConfigManager.shared.copyString("copy_brain_health_estimated", default: "Estimated") }

        // MARK: - Sleep and Memory

        static var sleepAndMemory: String { RemoteConfigManager.shared.copyString("copy_brain_health_sleep_and_memory", default: "Sleep and Memory") }
        static var dreamSleep: String { RemoteConfigManager.shared.copyString("copy_brain_health_dream_sleep", default: "Dream Sleep") }

        static var noSleepStageData: String { RemoteConfigManager.shared.copyString("copy_brain_health_no_sleep_stage_data", default: "We do not have your sleep stage data yet. These are estimates based on your other health data.") }
        static var sleepBrainExplanation: String { RemoteConfigManager.shared.copyString("copy_brain_health_sleep_brain_explanation", default: "Deep sleep cleans your brain. Dream sleep helps lock in memories.") }

        // MARK: - Mental Energy

        static var mentalEnergy: String { RemoteConfigManager.shared.copyString("copy_brain_health_mental_energy", default: "Mental Energy") }
        static var mentalEnergyExplanation: String { RemoteConfigManager.shared.copyString("copy_brain_health_mental_energy_explanation", default: "How much mental energy is left after stress.") }

        // MARK: - Brain Health Over Time

        static var brainHealthOverTime: String { RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_over_time", default: "Brain Health Over Time") }
        static var heartAndBrain: String { RemoteConfigManager.shared.copyString("copy_brain_health_heart_and_brain", default: "Heart and Brain") }
        static var sleepRhythm: String { RemoteConfigManager.shared.copyString("copy_brain_health_sleep_rhythm", default: "Sleep Rhythm") }
        static var longTermExplanation: String { RemoteConfigManager.shared.copyString("copy_brain_health_long_term_explanation", default: "A healthy heart and a regular sleep schedule help keep your brain sharp over time.") }

        // MARK: - Chart

        static var lastSevenDays: String { RemoteConfigManager.shared.copyString("copy_brain_health_last_seven_days", default: "Last 7 Days") }

        // MARK: - Key Factors

        static var whatHelpedAndHurt: String { RemoteConfigManager.shared.copyString("copy_brain_health_what_helped_and_hurt", default: "What Helped and Hurt") }

        // MARK: - Improve Your Score (masterclass)

        static var improveTitle: String { RemoteConfigManager.shared.copyString("copy_brain_health_improve_title", default: "Improve Your Score") }
        static var biggestLeverHeader: String { RemoteConfigManager.shared.copyString("copy_brain_health_biggest_lever_header", default: "BIGGEST LEVER TODAY") }
        static var projectionLabel: String { RemoteConfigManager.shared.copyString("copy_brain_health_projection_label", default: "Lift this and your score moves to") }
        static var actionsHeader: String { RemoteConfigManager.shared.copyString("copy_brain_health_actions_header", default: "TRY THIS TODAY") }
        static var improveBreakdown: String { RemoteConfigManager.shared.copyString("copy_brain_health_improve_breakdown", default: "Where Your 100 Points Are Earned") }
        static var improveFooter: String { RemoteConfigManager.shared.copyString("copy_brain_health_improve_footer", default: "Each area's weight matches its impact on cognition. Fix the biggest gap first.") }
        static var improveStrongState: String { RemoteConfigManager.shared.copyString("copy_brain_health_improve_strong_state", default: "You are already strong here. Keep your habits steady.") }
        static var improveNeedsConfidence: String { RemoteConfigManager.shared.copyString("copy_brain_health_improve_needs_confidence", default: "We will show your biggest lever once we have a few more nights of data.") }

        static func projectionGain(points: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_projection_gain", default: "+%d pts"), points)
        }
        static func pointsLost(points: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_points_lost", default: "−%d pts"), points)
        }
        static func weightOfScore(percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_weight_of_score", default: "%d%% of score"), percent)
        }

        // MARK: - Subscale labels (used by Improve section)

        static var subscaleCognitiveReadiness: String { RemoteConfigManager.shared.copyString("copy_brain_health_subscale_cognitive_readiness", default: "Cognitive Readiness") }
        static var subscaleMemoryRecovery: String { RemoteConfigManager.shared.copyString("copy_brain_health_subscale_memory_recovery", default: "Memory Recovery") }
        // mentalEnergy, heartAndBrain, sleepRhythm reused from Learn More.

        // MARK: - Actions per subscale (no dashes, plain English)

        static var actionsCognitiveReadiness: [String] { RemoteConfigManager.shared.copyArray("copy_brain_health_actions_cognitive_readiness", default: ["Sleep 30 minutes earlier tonight", "Skip alcohol and late screens, both lower HRV"]) }
        static var actionsMemoryRecovery: [String] { RemoteConfigManager.shared.copyArray("copy_brain_health_actions_memory_recovery", default: ["Sleep 7 plus hours, REM stacks late", "Avoid alcohol within 3 hours of bed"]) }
        static var actionsStressCognition: [String] { RemoteConfigManager.shared.copyArray("copy_brain_health_actions_stress_cognition", default: ["Try 10 minutes of slow breathing today", "No caffeine after 2 PM"]) }
        static var actionsNeurovascular: [String] { RemoteConfigManager.shared.copyArray("copy_brain_health_actions_neurovascular", default: ["Walk 8000 plus steps today", "Add one Zone 2 cardio session this week"]) }
        static var actionsCircadian: [String] { RemoteConfigManager.shared.copyArray("copy_brain_health_actions_circadian", default: ["Wake within 30 minutes of yesterday", "Keep weekend wake times like weekdays"]) }

        // MARK: - Simplified

        static var learnMore: String { RemoteConfigManager.shared.copyString("copy_brain_health_learn_more", default: "Learn More") }
        static var learnMoreHint: String { RemoteConfigManager.shared.copyString("copy_brain_health_learn_more_hint", default: "Dream sleep, mental energy, and long term trends.") }

        // MARK: - Building Confidence

        static func buildingAccuracy(percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_brain_health_brain_health_building_accuracy", default: "Building accuracy · %d%%"), percent)
        }
        static var needMoreData: String { RemoteConfigManager.shared.copyString("copy_brain_health_need_more_data", default: "We need more nights of sleep + HRV data before locking in your brain readiness number.") }

        // MARK: - State Trend Labels

        static var trendStable: String { RemoteConfigManager.shared.copyString("copy_brain_health_trend_stable", default: "stable") }
        static var trendImproving: String { RemoteConfigManager.shared.copyString("copy_brain_health_trend_improving", default: "improving") }
        static var trendDeclining: String { RemoteConfigManager.shared.copyString("copy_brain_health_trend_declining", default: "declining") }

        // MARK: - State Display Labels

        static var stateSharp: String { RemoteConfigManager.shared.copyString("copy_brain_health_state_sharp", default: "Sharp") }
        static var stateFocused: String { RemoteConfigManager.shared.copyString("copy_brain_health_state_focused", default: "Focused") }
        static var stateBaseline: String { RemoteConfigManager.shared.copyString("copy_brain_health_state_baseline", default: "Baseline") }
        static var stateLowEnergy: String { RemoteConfigManager.shared.copyString("copy_brain_health_state_low_energy", default: "Low energy") }
    }
}
