import Foundation

extension Copy {
    /// All user-facing strings for the Today Briefing intelligence cards.
    /// Each card type has a plain-English label and template functions that produce
    /// causal, personal narratives instead of status labels.
    enum Briefing {

        // MARK: - Card Type Labels

        enum Labels {
            static var headsUp: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_heads_up", default: "Heads Up") }
            static var somethingChanged: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_something_changed", default: "Something Changed") }
            static var cascadeAlert: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_cascade_alert", default: "Heads Up") }
            static var cascadeForecast: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_cascade_forecast", default: "What Might Happen Next") }
            static var whyThisIsHappening: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_why_this_is_happening", default: "Why This Is Happening") }
            static var yourBodyClock: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_your_body_clock", default: "Your Body Clock") }
            static var stressAndRecovery: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_stress_and_recovery", default: "Stress and Recovery") }
            static var nervousSystem: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_nervous_system", default: "Stress and Recovery") }
            static var sleepDebt: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_sleep_debt", default: "Sleep Debt") }
            static var everythingLooksGood: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_everything_looks_good", default: "Everything Looks Good") }
            static var unusualDay: String { RemoteConfigManager.shared.copyString("copy_briefing_briefing_labels_unusual_day", default: "Unusual Day") }
        }

        // MARK: - Trend Signal Card

        enum TrendSignal {

            /// Urgent health signal detected.
            static func urgentHeadline(riskPercent: String, signalName: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_briefing_trend_signal_urgent_headline", default: "Your body might be getting tired. Extra sleep tonight would help.")
            }

            static func urgentDetail(explanation: String) -> String {
                explanation
            }

            /// Tomorrow risk prediction with top factor.
            static func tomorrowHeadline(probability: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_briefing_tomorrow_headline", default: "A few of your numbers are shifting together. An earlier bedtime tonight could help.")
            }

            static func tomorrowDetailWithFactor(metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_tomorrow_detail_with_factor", default: "Your %@ has been a little off lately. A good night of sleep tonight could help."), metricName.lowercased())
            }

            static var tomorrowDetailGeneric: String { RemoteConfigManager.shared.copyString("copy_briefing_tomorrow_detail_generic", default: "A few of your numbers are shifting together. Taking it easy could help.") }
        }

        // MARK: - Regime Shift Card (Something Changed)

        enum SomethingChanged {

            static func headline(metricName: String, direction: String, delta: String, dateStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_something_changed_headline", default: "Your %@ has been %@ since %@. That is a real shift worth noticing."), metricName.lowercased(), direction, dateStr)
            }

            static func detailWithCoChanges(before: String, after: String, coChanges: [String]) -> String {
                let base = String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_with_co_changes_base", default: "It moved from %@ to %@."), before, after)
                if coChanges.isEmpty {
                    return base
                }
                let names = coChanges.joined(separator: " and ")
                return base + " " + String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_with_co_changes_suffix", default: "Your %@ shifted around the same time, so they are likely connected."), names.lowercased())
            }

            static func detailSimple(before: String, after: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_simple", default: "It moved from %@ to %@."), before, after)
            }
        }

        // MARK: - Cascade Forecast Card

        enum WhatMightHappen {

            /// Triggered precursor pattern.
            static func precursorHeadline(signalDescription: String, predictedEvent: String, accuracy: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_what_might_happen_precursor_headline", default: "Your %@ is shifting in a way that has often been linked with %@ before. A calmer day could help."), signalDescription.lowercased(), predictedEvent.lowercased())
            }

            static func precursorDetail(description: String) -> String {
                description
            }

            /// Active temporal sequence.
            static func sequenceHeadline(outcome: String, confidence: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_sequence_headline", default: "Some of your numbers are shifting in a pattern often seen with %@. Extra rest over the next few days could help."), outcome.lowercased())
            }

            static func sequenceDetail(description: String) -> String {
                description
            }
        }

        // MARK: - Hidden Driver Card (Why This is Happening)

        enum WhyThisIsHappening {

            static func headline(causeMetric: String, effectMetric: String, lagDays: Int, direction: String) -> String {
                let lagStr: String
                if lagDays == 1 {
                    lagStr = RemoteConfigManager.shared.copyString("copy_briefing_lag_one_day", default: "about a day later")
                } else {
                    lagStr = String(format: RemoteConfigManager.shared.copyString("copy_briefing_lag_n_days", default: "about %d days later"), lagDays)
                }
                let verb = direction == "drives"
                    ? RemoteConfigManager.shared.copyString("copy_briefing_verb_drives", default: "lifts")
                    : RemoteConfigManager.shared.copyString("copy_briefing_verb_pulls_down", default: "pulls down")
                return String(format: RemoteConfigManager.shared.copyString("copy_briefing_why_this_headline", default: "Your %@ %@ your %@ %@. This pattern keeps showing up for you."), causeMetric.lowercased(), verb, effectMetric.lowercased(), lagStr)
            }

            static func detailWithPartial(partialR: String, stability: String, sampleCount: Int) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_detail_with_partial", default: "This connection seems strong, even when looking at other factors. Based on the past few weeks of your data.")
            }

            static func detailSimple(sampleCount: Int, stability: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_detail_simple", default: "This pattern has been steady over the past few weeks of your data.")
            }
        }

        // MARK: - Body Clock Card

        enum YourBodyClock {

            static func workoutTimingHeadline(startTime: String, endTime: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_your_body_clock_workout_timing_headline", default: "Your body feels strongest for exercise between %@ and %@."), startTime, endTime)
            }

            static func generalHeadline(peakTime: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_your_body_clock_general_headline", default: "Your energy feels best around %@ each day."), peakTime)
            }

            static func detail(bedtime: String?, hrvPeak: String?) -> String {
                var parts: [String] = []
                if let bedtime {
                    parts.append(String(format: RemoteConfigManager.shared.copyString("copy_briefing_body_clock_bedtime", default: "A good bedtime for you looks like around %@"), bedtime))
                }
                if let hrvPeak {
                    parts.append(String(format: RemoteConfigManager.shared.copyString("copy_briefing_body_clock_hrv_peak", default: "Your body tends to feel most rested around %@"), hrvPeak))
                }
                if parts.isEmpty {
                    return RemoteConfigManager.shared.copyString("copy_briefing_body_clock_fallback", default: "Based on your natural rhythm over the past few weeks.")
                }
                return parts.joined(separator: ". ") + "."
            }
        }

        // MARK: - Stress Load Card (Stress and Recovery)

        enum StressAndRecovery {

            static func highStressHeadline(score: String, worstSystem: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_stress_and_recovery_high_stress_headline", default: "Your body is carrying more than usual right now. Your %@ feels the most tired, so a slower day would help."), worstSystem.lowercased())
            }

            static func lowStressHeadline(score: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_low_stress_headline", default: "Your body feels well rested today. A great day to make the most of.")
            }

            static func normalStressHeadline(score: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_normal_stress_headline", default: "Your body feels about normal today. Nothing unusual going on.")
            }

            static func detailWithPercentile(percentileStr: String, systemSummary: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_with_percentile", default: "%@. Here is what is going on: %@."), percentileStr, systemSummary)
            }

            static func detailSimple(systemSummary: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_simple", default: "Here is what is going on: %@."), systemSummary)
            }
        }

        // MARK: - Autonomic Balance Card (Nervous System / Stress and Recovery)

        enum NervousSystem {

            static func recoveryModeHeadline(hrvStr: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_nervous_system_recovery_mode_headline", default: "Your body feels well recovered today. A great day to move and feel good.")
            }

            static func stressModeHeadline(hrvStr: String, rhrStr: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_nervous_system_stress_mode_headline", default: "Your body still feels stressed. Try a calm, slow day to help it catch up.")
            }

            static func mildShiftHeadline(direction: String) -> String {
                let plain = direction == "toward recovery"
                    ? RemoteConfigManager.shared.copyString("copy_briefing_mild_shift_recovery", default: "leaning toward feeling better")
                    : RemoteConfigManager.shared.copyString("copy_briefing_mild_shift_tired", default: "feeling a little tired")
                return String(format: RemoteConfigManager.shared.copyString("copy_briefing_mild_shift_headline", default: "Your body is %@ today. A small shift, but worth noticing."), plain)
            }

            static func detail(hrvStr: String, rhrStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail", default: "HRV: %@, resting heart rate: %@."), hrvStr, rhrStr)
            }
        }

        // MARK: - Recovery Debt Card (Sleep Debt)

        enum SleepDebt {

            static func headlineWithRecovery(debtHours: String, recoveryDays: Int) -> String {
                let dayWord = recoveryDays == 1
                    ? RemoteConfigManager.shared.copyString("copy_briefing_night_singular", default: "night")
                    : RemoteConfigManager.shared.copyString("copy_briefing_night_plural", default: "nights")
                return String(format: RemoteConfigManager.shared.copyString("copy_briefing_headline_with_recovery", default: "You are short on sleep by %@. A few good %@ of rest should get you back on track."), debtHours, dayWord)
            }

            static func headlineHRVSuppressed(dayCount: String, windowDays: Int) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_headline_hrv_suppressed", default: "Your body has been running low over the past couple of weeks. A few good nights of sleep will help.")
            }

            static func detailSleepDeficit(debtHours: String, windowDays: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_sleep_deficit", default: "You have missed about %@ of sleep over the past couple of weeks."), debtHours)
            }

            static func detailHRVBelow(dayCount: String, windowDays: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_hrv_below", default: "Your body has felt tired on %@ of the past %d days."), dayCount, windowDays)
            }

            static func detailExerciseBelow(missedDays: Int, windowDays: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_exercise_below", default: "You moved less than your usual on %d of the past %d days."), missedDays, windowDays)
            }

            static var trendImproving: String { RemoteConfigManager.shared.copyString("copy_briefing_trend_improving", default: "Getting better compared to last week.") }
            static var trendWorsening: String { RemoteConfigManager.shared.copyString("copy_briefing_trend_worsening", default: "Not quite as good as last week. A little more rest will help.") }
        }

        // MARK: - System Coherence Card (Everything Looks Good / or Warning)

        enum BodySystems {

            static func decoupledHeadline(dropPercent: String) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_body_systems_decoupled_headline", default: "Your body's systems are a bit out of sync today. A calm day with good sleep should help bring things back together.")
            }

            static func alignedHeadline(connectionCount: Int, metricCount: Int) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_body_systems_aligned_headline", default: "Your body's systems are working together really well right now. Nice and steady.")
            }

            static func normalHeadline(connectionCount: Int) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_body_systems_normal_headline", default: "Your body is mostly in sync today. Things are ticking along nicely.")
            }

            static func detailWithWeakLink(connectionCount: Int, metricCount: Int, metricA: String, metricB: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_detail_with_weak_link", default: "Your %@ and %@ are a little out of step today. Some extra rest should help them line back up."), metricA.lowercased(), metricB.lowercased())
            }

            static func detailSimple(connectionCount: Int, metricCount: Int) -> String {
                RemoteConfigManager.shared.copyString("copy_briefing_detail_simple", default: "Your key health measures are moving together nicely.")
            }
        }

        // MARK: - Rhythm Deviation Card (Unusual Day)

        enum UnusualDay {

            static func headline(dayName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_unusual_day_headline", default: "Today is shaping up pretty different from your usual %@."), dayName)
            }

            static func deviatorDescription(metricName: String, currentValue: String, direction: String, weekdayAvg: String, dayName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_briefing_deviator_description", default: "Your %@ is %@ today, %@ what you normally see on a %@."), metricName.lowercased(), currentValue, direction, dayName)
            }

            static func detail(descriptions: [String]) -> String {
                let prefix = RemoteConfigManager.shared.copyString("copy_briefing_unusual_day_detail_prefix", default: "Here is what stood out: ")
                let separator = RemoteConfigManager.shared.copyString("copy_briefing_unusual_day_detail_separator", default: " And ")
                return prefix + descriptions.joined(separator: separator)
            }
        }

        // MARK: - Confidence Display

        static func confidenceBadge(percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_briefing_confidence_badge", default: "Based on %d%% confidence"), percent)
        }
    }
}
