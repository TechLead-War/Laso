import Foundation

extension Copy {
    /// All user-facing strings for the Today Briefing intelligence cards.
    /// Each card type has a plain-English label and template functions that produce
    /// causal, personal narratives instead of status labels.
    enum Briefing {

        // MARK: - Card Type Labels

        enum Labels {
            static let headsUp = "Heads Up"
            static let somethingChanged = "Something Changed"
            static let cascadeAlert = "Heads Up"
            static let cascadeForecast = "What Might Happen Next"
            static let whyThisIsHappening = "Why This Is Happening"
            static let yourBodyClock = "Your Body Clock"
            static let stressAndRecovery = "Stress and Recovery"
            static let nervousSystem = "Stress and Recovery"
            static let sleepDebt = "Sleep Debt"
            static let everythingLooksGood = "Everything Looks Good"
            static let unusualDay = "Unusual Day"
        }

        // MARK: - Trend Signal Card

        enum TrendSignal {

            /// Urgent health signal detected.
            static func urgentHeadline(riskPercent: String, signalName: String) -> String {
                "Your body might be getting tired. Extra sleep tonight would help."
            }

            static func urgentDetail(explanation: String) -> String {
                explanation
            }

            /// Tomorrow risk prediction with top factor.
            static func tomorrowHeadline(probability: String) -> String {
                "Tomorrow might feel heavy on your body. Going to bed early could help."
            }

            static func tomorrowDetailWithFactor(metricName: String) -> String {
                "Your \(metricName.lowercased()) has been a little off lately. A good night of sleep tonight should help you feel better."
            }

            static let tomorrowDetailGeneric = "A few of your numbers are shifting together. Taking it easy tomorrow should help."
        }

        // MARK: - Regime Shift Card (Something Changed)

        enum SomethingChanged {

            static func headline(metricName: String, direction: String, delta: String, dateStr: String) -> String {
                "Your \(metricName.lowercased()) has been \(direction) since \(dateStr). That is a real shift worth noticing."
            }

            static func detailWithCoChanges(before: String, after: String, coChanges: [String]) -> String {
                let base = "It moved from \(before) to \(after)."
                if coChanges.isEmpty {
                    return base
                }
                let names = coChanges.joined(separator: " and ")
                return "\(base) Your \(names.lowercased()) shifted around the same time, so they are likely connected."
            }

            static func detailSimple(before: String, after: String) -> String {
                "It moved from \(before) to \(after)."
            }
        }

        // MARK: - Cascade Forecast Card

        enum WhatMightHappen {

            /// Triggered precursor pattern.
            static func precursorHeadline(signalDescription: String, predictedEvent: String, accuracy: String) -> String {
                "Your \(signalDescription.lowercased()) looks the way it did before \(predictedEvent.lowercased()) last time. A calmer day could really help."
            }

            static func precursorDetail(description: String) -> String {
                description
            }

            /// Active temporal sequence.
            static func sequenceHeadline(outcome: String, confidence: String) -> String {
                "It looks like \(outcome.lowercased()) might be on the way over the next few days. Some extra rest now would go a long way."
            }

            static func sequenceDetail(description: String) -> String {
                description
            }
        }

        // MARK: - Hidden Driver Card (Why This is Happening)

        enum WhyThisIsHappening {

            static func headline(causeMetric: String, effectMetric: String, lagDays: Int, direction: String) -> String {
                let lagStr = lagDays == 1 ? "about a day later" : "about \(lagDays) days later"
                let verb = direction == "drives" ? "lifts" : "pulls down"
                return "Your \(causeMetric.lowercased()) \(verb) your \(effectMetric.lowercased()) \(lagStr). This pattern keeps showing up for you."
            }

            static func detailWithPartial(partialR: String, stability: String, sampleCount: Int) -> String {
                "Even after other things are considered, this link still holds. Based on the past few weeks of your data."
            }

            static func detailSimple(sampleCount: Int, stability: String) -> String {
                "This pattern has been steady over the past few weeks of your data."
            }
        }

        // MARK: - Body Clock Card

        enum YourBodyClock {

            static func workoutTimingHeadline(startTime: String, endTime: String) -> String {
                "Your body feels strongest for exercise between \(startTime) and \(endTime)."
            }

            static func generalHeadline(peakTime: String) -> String {
                "Your energy feels best around \(peakTime) each day."
            }

            static func detail(bedtime: String?, hrvPeak: String?) -> String {
                var parts: [String] = []
                if let bedtime {
                    parts.append("A good bedtime for you looks like around \(bedtime)")
                }
                if let hrvPeak {
                    parts.append("Your body tends to feel most rested around \(hrvPeak)")
                }
                if parts.isEmpty {
                    return "Based on your natural rhythm over the past few weeks."
                }
                return parts.joined(separator: ". ") + "."
            }
        }

        // MARK: - Stress Load Card (Stress and Recovery)

        enum StressAndRecovery {

            static func highStressHeadline(score: String, worstSystem: String) -> String {
                "Your body is carrying more than usual right now. Your \(worstSystem.lowercased()) feels the most tired, so a slower day would help."
            }

            static func lowStressHeadline(score: String) -> String {
                "Your body feels well rested today. A great day to make the most of."
            }

            static func normalStressHeadline(score: String) -> String {
                "Your body feels about normal today. Nothing unusual going on."
            }

            static func detailWithPercentile(percentileStr: String, systemSummary: String) -> String {
                "\(percentileStr). Here is what is going on: \(systemSummary)."
            }

            static func detailSimple(systemSummary: String) -> String {
                "Here is what is going on: \(systemSummary)."
            }
        }

        // MARK: - Autonomic Balance Card (Nervous System / Stress and Recovery)

        enum NervousSystem {

            static func recoveryModeHeadline(hrvStr: String) -> String {
                "Your body feels well recovered today. A great day to move and feel good."
            }

            static func stressModeHeadline(hrvStr: String, rhrStr: String) -> String {
                "Your body still feels stressed. Try a calm, slow day to help it catch up."
            }

            static func mildShiftHeadline(direction: String) -> String {
                let plain = direction == "toward recovery" ? "leaning toward feeling better" : "feeling a little tired"
                return "Your body is \(plain) today. A small shift, but worth noticing."
            }

            static func detail(hrvStr: String, rhrStr: String) -> String {
                "HRV: \(hrvStr), resting heart rate: \(rhrStr)."
            }
        }

        // MARK: - Recovery Debt Card (Sleep Debt)

        enum SleepDebt {

            static func headlineWithRecovery(debtHours: String, recoveryDays: Int) -> String {
                let dayWord = recoveryDays == 1 ? "night" : "nights"
                return "You are short on sleep by \(debtHours). A few good \(dayWord) of rest should get you back on track."
            }

            static func headlineHRVSuppressed(dayCount: String, windowDays: Int) -> String {
                "Your body has been running low over the past couple of weeks. A few good nights of sleep will help."
            }

            static func detailSleepDeficit(debtHours: String, windowDays: Int) -> String {
                "You have missed about \(debtHours) of sleep over the past couple of weeks."
            }

            static func detailHRVBelow(dayCount: String, windowDays: Int) -> String {
                "Your body has felt tired on \(dayCount) of the past \(windowDays) days."
            }

            static func detailExerciseBelow(missedDays: Int, windowDays: Int) -> String {
                "You moved less than your usual on \(missedDays) of the past \(windowDays) days."
            }

            static let trendImproving = "Getting better compared to last week."
            static let trendWorsening = "Not quite as good as last week. A little more rest will help."
        }

        // MARK: - System Coherence Card (Everything Looks Good / or Warning)

        enum BodySystems {

            static func decoupledHeadline(dropPercent: String) -> String {
                "Your body's systems are a bit out of sync today. A calm day with good sleep should help bring things back together."
            }

            static func alignedHeadline(connectionCount: Int, metricCount: Int) -> String {
                "Your body's systems are working together really well right now. Nice and steady."
            }

            static func normalHeadline(connectionCount: Int) -> String {
                "Your body is mostly in sync today. Things are ticking along nicely."
            }

            static func detailWithWeakLink(connectionCount: Int, metricCount: Int, metricA: String, metricB: String) -> String {
                "Your \(metricA.lowercased()) and \(metricB.lowercased()) are a little out of step today. Some extra rest should help them line back up."
            }

            static func detailSimple(connectionCount: Int, metricCount: Int) -> String {
                "Your key health measures are moving together nicely."
            }
        }

        // MARK: - Rhythm Deviation Card (Unusual Day)

        enum UnusualDay {

            static func headline(dayName: String) -> String {
                "Today is shaping up pretty different from your usual \(dayName)."
            }

            static func deviatorDescription(metricName: String, currentValue: String, direction: String, weekdayAvg: String, dayName: String) -> String {
                "Your \(metricName.lowercased()) is \(currentValue) today, \(direction) what you normally see on a \(dayName)."
            }

            static func detail(descriptions: [String]) -> String {
                let prefix = "Here is what stood out: "
                return prefix + descriptions.joined(separator: " And ")
            }
        }

        // MARK: - Confidence Display

        static func confidenceBadge(percent: Int) -> String {
            "Based on \(percent)% confidence"
        }
    }
}
