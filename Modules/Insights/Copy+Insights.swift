import Foundation

extension Copy {
    enum Insights {

        // MARK: - Inflection Notes

        static let accelerating = " The rate of change is speeding up."
        static let decelerating = " The drop is slowing down. A recovery may be starting."
        static let reversing = " The trend has just turned around."

        // MARK: - Inflection Suffixes (for titles)

        static let andAccelerating = " & Accelerating"
        static let slowing = " (Slowing)"
        static let dashReversing = " (Reversing)"
        static let andGainingMomentum = " & Gaining Momentum"

        // MARK: - Title Patterns

        static func criticallyLow(_ metric: String, suffix: String) -> String {
            "\(metric) Running Low\(suffix)"
        }
        static func needsAttention(_ metric: String, prefix: String, suffix: String) -> String {
            "\(metric) \(prefix)Worth a Look\(suffix)"
        }
        static func declining(_ metric: String, prefix: String, suffix: String) -> String {
            "\(metric) \(prefix)Declining\(suffix)"
        }
        static func improving(_ metric: String, prefix: String, momentum: String) -> String {
            "\(metric) \(prefix)Improving\(momentum)"
        }
        static func outsideSafeRange(_ metric: String) -> String {
            "\(metric) Outside Your Usual Range"
        }
        static func elevated(_ metric: String) -> String {
            "\(metric) Higher Than Usual"
        }
        static func stable(_ metric: String) -> String {
            "\(metric) Stable"
        }

        // MARK: - Follow-Up Sentences

        static let recheckIn48Hours = "Follow up: check again in 48 hours to make sure this is steadying before it reaches warning range."
        static let reviewIn3Days = "Follow up: review this trend again in 3 days to confirm the direction has gotten better."

        // MARK: - Lead Time Labels

        static let sameDaySignal = "same-day signal"
        static let nextDaySignal = "next-day signal"
        static func dayLeadSignal(_ days: Int) -> String { "\(days)-day lead signal" }

        // MARK: - Evidence Labels

        static let evidenceHigh = "high"
        static let evidenceMedium = "medium"
        static let evidenceEarly = "early"

        // MARK: - Projection

        static func projectedWarning(days: Int) -> String {
            " At this rate, this could reach warning level in about \(days) days."
        }

        // MARK: - Historical Context

        static func yoyChange(direction: String, percent: String) -> String {
            "\(direction) \(percent)% vs this time last year"
        }
        static func percentileLabel(label: String) -> String {
            "in the \(label) of your history"
        }
        static func seasonalDeviation(direction: String, month: String, percent: String) -> String {
            "\(direction) your usual \(month) by \(percent)%"
        }

        // MARK: - Causal Hints

        static let causalHintHRV = "Based on your history, this level usually follows nights with less than 6 hours of sleep."
        static let causalHintRHR = "Based on your history, a higher resting heart rate often follows times of less sleep or high stress. Try for an earlier bedtime tonight."
        static let causalHintBloodOxygen = "Based on your history, lower blood oxygen usually goes with broken sleep patterns."
        static let causalHintSleepDuration = "Based on your history, shorter sleep often follows days with low activity or late workouts."
        static let causalHintSleepDeep = "Based on your history, drops in deep sleep often go with higher stress or shifting bedtimes."
        static let causalHintVO2Max = "Based on your history, VO2 Max changes tend to follow shifts in workout routine over 2 to 4 weeks."
        static let causalHintActiveCalories = "Based on your history, lower calorie burn usually follows fewer steps and workout minutes."
        static let causalHintExercise = "Based on your history, dips in exercise often line up with broken sleep patterns."
        static let causalHintBodyTemp = "Based on your history, changes in temperature often go with shifts in sleep length and HRV."
        static let causalHintRespiratoryRate = "Based on your history, breathing rate changes often track with sleep quality and stress levels."

        // MARK: - Action Protocol Strings

        static func sleepMetricsOff(dev: Int) -> String {
            "your sleep numbers are \(dev)% off your usual"
        }
        static func activityDeviation(dev: Int, direction: String) -> String {
            "your activity is \(dev)% \(direction) your recent average"
        }
        static func hrvTrending(direction: String, dev: Int) -> String {
            "your HRV is trending \(direction), \(dev)% from your usual"
        }
        static func rhrShifted(dev: Int) -> String {
            "your resting heart rate shifted \(dev)% from your usual"
        }
        static func mindfulnessDeviation(dev: Int, direction: String) -> String {
            "your mindfulness time is \(dev)% \(direction) your average"
        }
        static func daylightDeviation(dev: Int, direction: String) -> String {
            "your daylight time is \(dev)% \(direction) your average"
        }
        static let bpOutsideRange = "your blood pressure reading is outside your usual range"
        static let recheckSingleReading = "check again to confirm, since single readings can vary"
        static let readingOutsideRange = "this reading is outside your usual range. Keep an eye on it."
        static let recheckMetricTrend = "check this again to confirm the trend"
        static func bodyMetricsShifted(dev: Int) -> String {
            "your body numbers shifted \(dev)% from your usual"
        }
        static func vo2MaxTrending(direction: String, dev: Int) -> String {
            "your VO2 max is trending \(direction), \(dev)% from your usual"
        }
        static func mobilityMetricsOff(dev: Int) -> String {
            "your mobility numbers are \(dev)% off your usual"
        }
        static func genericMetricDeviation(metricName: String, dev: Int) -> String {
            "your \(metricName) is \(dev)% from your usual"
        }

        // MARK: - Correlations

        enum Correlations {
            static let keyDiscoveries = "Key Discoveries"
            static let whyThingsChanged = "Why Things Changed"
            static let howMuchMatters = "How Much It Matters"
            static let allConnections = "All Connections"
            static let buildingIntelligence = "Still building your insight profile."
            static let keepWearingDevice = "Keep wearing your device and syncing daily so we can find patterns in your data."

            // MARK: - Detail / Cards

            static let navigationTitle = "Health Intelligence"
            static let actionableBadge = "Actionable"
            static let evidenceLabel = "Evidence"
            static let sameDay = "Same day"
            static let nextDay = "Next day"
            static func correlationSummary(strength: String, dayLabel: String, effectPercent: Int) -> String {
                "\(strength) \u{00B7} \(dayLabel) \u{00B7} \(effectPercent)% effect"
            }
        }

        // MARK: - Insights Detail

        enum Detail {
            static let navigationTitle = "Insights"
            static let emptyTitle = "No insights yet"
            static let emptyMessageAll = "More data will open up deeper insights over time."
            static func emptyMessageFiltered(_ filter: String) -> String {
                "No \(filter) insights right now."
            }
        }

        // MARK: - Metric Detail

        enum MetricDetail {
            static func expandedRangeNotice(_ days: Int) -> String {
                "Expanded to \(days) days to show available data"
            }

            static let noDataYet = "No Data Yet"

            static func noDataDescription(_ metricName: String) -> String {
                "We do not have enough \(metricName) data to show charts yet. Keep wearing your device and syncing daily."
            }

            static let insights = "Insights"
            static let outsideNormalRange = "Outside Range"

            static func baselineDeviation(_ deviation: String) -> String {
                "\(deviation) from your usual"
            }

            static let trend = "Trend"
            static let forecast = "Forecast"
            static let periodAvg = "Period Avg"
            static let outsideRange = "Outside Range"
            static let withinRange = "Within Range"
            static let thisMonthVsLastMonth = "This Month vs Last Month"
            static let scoreImpact = "Score Impact"
            static let historicalContext = "Historical Context"

            static func dataPointsSummary(_ count: Int) -> String {
                "Based on \(count) data points"
            }
        }

        // MARK: - InsightCard Context Lines

        enum InsightCard {
            /// "Because" line showing the root cause metric and its deviation
            static func linkedToMetric(_ metricName: String, deviationPercent: Int) -> String {
                "May be linked to your \(metricName) being \(deviationPercent)% off"
            }

            /// Fallback when we have a root cause metric but no deviation value
            static func connectedToMetric(_ metricName: String) -> String {
                "May be connected to your \(metricName)"
            }

            /// Data basis line showing how many days of data back the finding
            static func basedOnDays(_ count: Int) -> String {
                "Based on \(count) days of your data"
            }

            /// Confidence qualifier when we have a confidence level but no day count
            static func confidenceQualifier(_ level: String) -> String {
                "\(level) confidence from your history"
            }
        }
    }
}
