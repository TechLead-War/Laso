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
                "Your \(signalName.lowercased()) risk is at \(riskPercent). This needs your attention."
            }

            static func urgentDetail(explanation: String) -> String {
                explanation
            }

            /// Tomorrow risk prediction with top factor.
            static func tomorrowHeadline(probability: String) -> String {
                "There is a \(probability) chance tomorrow will be a tough day for your body."
            }

            static func tomorrowDetailWithFactor(metricName: String) -> String {
                "This is mainly because your \(metricName.lowercased()) has been off. Based on how your body has responded before, getting extra sleep tonight could help."
            }

            static let tomorrowDetailGeneric = "Based on several of your numbers shifting together. The last time this pattern showed up, a rest day helped."
        }

        // MARK: - Regime Shift Card (Something Changed)

        enum SomethingChanged {

            static func headline(metricName: String, direction: String, delta: String, dateStr: String) -> String {
                "Your \(metricName.lowercased()) has been \(direction) since \(dateStr), shifting by \(delta)."
            }

            static func detailWithCoChanges(before: String, after: String, coChanges: [String]) -> String {
                let base = "It went from \(before) to \(after)."
                if coChanges.isEmpty {
                    return base
                }
                let names = coChanges.joined(separator: " and ")
                return "\(base) Your \(names.lowercased()) changed around the same time, which is probably connected."
            }

            static func detailSimple(before: String, after: String) -> String {
                "It went from \(before) to \(after)."
            }
        }

        // MARK: - Cascade Forecast Card

        enum WhatMightHappen {

            /// Triggered precursor pattern.
            static func precursorHeadline(signalDescription: String, predictedEvent: String, accuracy: String) -> String {
                "The last time your \(signalDescription.lowercased()) looked like this, \(predictedEvent.lowercased()) followed. This pattern has appeared in your data before."
            }

            static func precursorDetail(description: String) -> String {
                description
            }

            /// Active temporal sequence.
            static func sequenceHeadline(outcome: String, confidence: String) -> String {
                "Based on a pattern in your data, \(outcome.lowercased()) is likely coming (\(confidence) confidence). This usually plays out over a few days."
            }

            static func sequenceDetail(description: String) -> String {
                description
            }
        }

        // MARK: - Hidden Driver Card (Why This is Happening)

        enum WhyThisIsHappening {

            static func headline(causeMetric: String, effectMetric: String, lagDays: Int, direction: String) -> String {
                let lagStr = lagDays == 1 ? "about a day later" : "about \(lagDays) days later"
                let verb = direction == "drives" ? "pushes" : "pulls down"
                return "Your \(causeMetric.lowercased()) \(verb) your \(effectMetric.lowercased()) \(lagStr). This connection has been consistent in your data."
            }

            static func detailWithPartial(partialR: String, stability: String, sampleCount: Int) -> String {
                "Even after accounting for other factors, this link holds up (strength: \(partialR)). Based on \(sampleCount) days of data."
            }

            static func detailSimple(sampleCount: Int, stability: String) -> String {
                "Based on \(sampleCount) days of your data. This pattern has been \(stability) stable over time."
            }
        }

        // MARK: - Body Clock Card

        enum YourBodyClock {

            static func workoutTimingHeadline(startTime: String, endTime: String) -> String {
                "Your body is at its best for exercise between \(startTime) and \(endTime)."
            }

            static func generalHeadline(peakTime: String) -> String {
                "Your energy peaks around \(peakTime) each day."
            }

            static func detail(bedtime: String?, hrvPeak: String?) -> String {
                var parts: [String] = []
                if let bedtime {
                    parts.append("Your ideal bedtime based on your patterns is around \(bedtime)")
                }
                if let hrvPeak {
                    parts.append("Your body tends to be most recovered around \(hrvPeak)")
                }
                if parts.isEmpty {
                    return "This is based on your natural rhythm over the past few weeks."
                }
                return parts.joined(separator: ". ") + "."
            }
        }

        // MARK: - Stress Load Card (Stress and Recovery)

        enum StressAndRecovery {

            static func highStressHeadline(score: String, worstSystem: String) -> String {
                "Your body is carrying more stress than usual (\(score) out of 100). Your \(worstSystem.lowercased()) numbers are the most affected."
            }

            static func lowStressHeadline(score: String) -> String {
                "Your stress levels are low right now (\(score) out of 100). Your body is well recovered."
            }

            static func normalStressHeadline(score: String) -> String {
                "Your stress levels are in your normal range (\(score) out of 100)."
            }

            static func detailWithPercentile(percentileStr: String, systemSummary: String) -> String {
                "\(percentileStr). Here is the breakdown: \(systemSummary)."
            }

            static func detailSimple(systemSummary: String) -> String {
                "Here is the breakdown: \(systemSummary)."
            }
        }

        // MARK: - Autonomic Balance Card (Nervous System / Stress and Recovery)

        enum NervousSystem {

            static func recoveryModeHeadline(hrvStr: String) -> String {
                "Your nervous system is in recovery mode right now. Your HRV is \(hrvStr), which is above your baseline. This is a good sign."
            }

            static func stressModeHeadline(hrvStr: String, rhrStr: String) -> String {
                "Your nervous system has not fully recovered. Your HRV is \(hrvStr) and resting heart rate is \(rhrStr), which suggests your body is still under stress. Consider going easy today."
            }

            static func mildShiftHeadline(direction: String) -> String {
                let plain = direction == "toward recovery" ? "leaning toward recovery" : "showing mild stress"
                return "Your nervous system is \(plain) today. A small shift, but worth noting."
            }

            static func detail(hrvStr: String, rhrStr: String) -> String {
                "HRV: \(hrvStr), resting heart rate: \(rhrStr)."
            }
        }

        // MARK: - Recovery Debt Card (Sleep Debt)

        enum SleepDebt {

            static func headlineWithRecovery(debtHours: String, recoveryDays: Int) -> String {
                let dayWord = recoveryDays == 1 ? "night" : "nights"
                return "You have built up \(debtHours) of sleep debt. Based on your history, it usually takes about \(recoveryDays) good \(dayWord) to get back on track."
            }

            static func headlineHRVSuppressed(dayCount: String, windowDays: Int) -> String {
                "Your HRV has been lower than usual for \(dayCount) of the last \(windowDays) days, which usually means your body needs more rest."
            }

            static func detailSleepDeficit(debtHours: String, windowDays: Int) -> String {
                "Sleep deficit: \(debtHours) over the past \(windowDays) days."
            }

            static func detailHRVBelow(dayCount: String, windowDays: Int) -> String {
                "HRV below your normal range for \(dayCount) of the last \(windowDays) days."
            }

            static func detailExerciseBelow(missedDays: Int, windowDays: Int) -> String {
                "Exercise was below your goal for \(missedDays) of the past \(windowDays) days."
            }

            static let trendImproving = "Getting better compared to last week."
            static let trendWorsening = "Getting worse compared to last week."
        }

        // MARK: - System Coherence Card (Everything Looks Good / or Warning)

        enum BodySystems {

            static func decoupledHeadline(dropPercent: String) -> String {
                "Your body's systems are \(dropPercent) less in sync than usual. This sometimes happens when something is off, like poor sleep or extra stress."
            }

            static func alignedHeadline(connectionCount: Int, metricCount: Int) -> String {
                "Your body's systems are working well together. \(connectionCount) strong connections across \(metricCount) health measures."
            }

            static func normalHeadline(connectionCount: Int) -> String {
                "Your body's systems are mostly in sync, with \(connectionCount) healthy connections between your health measures."
            }

            static func detailWithWeakLink(connectionCount: Int, metricCount: Int, metricA: String, metricB: String) -> String {
                "\(connectionCount) connections across \(metricCount) measures. The link between your \(metricA.lowercased()) and \(metricB.lowercased()) is weaker than usual."
            }

            static func detailSimple(connectionCount: Int, metricCount: Int) -> String {
                "\(connectionCount) connections across \(metricCount) tracked measures."
            }
        }

        // MARK: - Rhythm Deviation Card (Unusual Day)

        enum UnusualDay {

            static func headline(dayName: String) -> String {
                "Today is pretty different from your typical \(dayName)."
            }

            static func deviatorDescription(metricName: String, currentValue: String, direction: String, weekdayAvg: String, dayName: String) -> String {
                "Your \(metricName.lowercased()) is \(currentValue), which is \(direction) your usual \(dayName) average of \(weekdayAvg)."
            }

            static func detail(descriptions: [String]) -> String {
                let prefix = "The biggest differences: "
                return prefix + descriptions.joined(separator: " Also, ")
            }
        }

        // MARK: - Confidence Display

        static func confidenceBadge(percent: Int) -> String {
            "Based on \(percent)% confidence"
        }
    }
}
