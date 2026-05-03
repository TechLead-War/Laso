import Foundation

extension Copy {
    enum Insights {

        // MARK: - Summary Templates

        static func decliningSummary(metricLower: String, deviation: String, direction: String, baseline: String, unit: String, current: String, inflectionNote: String, projectionNote: String, causalHint: String, historyNote: String) -> String {
            "Your \(metricLower) is \(deviation)% \(direction) your baseline (\(baseline) \(unit)). Current: \(current) \(unit).\(inflectionNote)\(projectionNote)\(causalHint)\(historyNote)"
        }
        static func improvingSummary(metricLower: String, deviation: String, current: String, unit: String, inflectionNote: String, causalHint: String, historyNote: String) -> String {
            "Your \(metricLower) has improved \(deviation)% from your baseline. Current: \(current) \(unit).\(inflectionNote)\(causalHint)\(historyNote)"
        }
        static func stableSummary(metricLower: String, deviation: String, direction: String, baseline: String, unit: String, causalHint: String, historyNote: String) -> String {
            "Your \(metricLower) is \(deviation)% \(direction) your baseline (\(baseline) \(unit)).\(causalHint)\(historyNote)"
        }
        static func projectionWarning(days: Int) -> String {
            " At the current rate, this could reach warning level in about \(days) days."
        }
        static func priorityToday(actionProtocol: String) -> String {
            "Priority today: \(actionProtocol)."
        }

        // MARK: - Compound Insight Engine Titles

        static let healthBuildingMomentum = "Your Health Is Building Momentum"
        static let multipleMetricsDecliningTogether = "Multiple Metrics Declining Together"
        static func newHealthPhase(_ label: String) -> String { "New Health Phase: \(label)" }
        static func troughProblem(_ name: String) -> String { "Your \(name) Problem" }
        static func categoriesLinked(_ a: String, _ b: String) -> String { "Your \(a) and \(b) Are Linked" }
        static let mostResponsiveMetric = "Your Most Responsive Metric"
        static let warningSignsConverging = "Warning Signs Converging"
        static func tomorrowsRisk(_ percent: Int) -> String { "Tomorrow's Risk: \(percent)%" }
        static func biggestOpportunity(_ metric: String) -> String { "Biggest Opportunity: \(metric)" }
        static let yourBestDayFormula = "Your Best-Day Formula"
        static let recoveryUnderway = "Recovery Underway"
        static let normalAcrossMetrics = "This state is characterized by normal levels across metrics."
        static func characterizedBy(_ descriptions: String) -> String { "Characterized by \(descriptions)." }

        // MARK: - ML Risk Levels

        static let riskLevelHigh = "High"
        static let riskLevelModerate = "Moderate"
        static let riskLevelLow = "Low"
        static let riskLevelVeryLow = "Very Low"

        // MARK: - Today Intelligence

        static func highestInDays(days: Int, topPercent: Int) -> String {
            "Highest in \(days) days (top \(topPercent)%)"
        }
        static func lowestInDays(days: Int, bottomPercent: Int) -> String {
            "Lowest in \(days) days (bottom \(bottomPercent)%)"
        }

        // MARK: - Day Names

        static let daySunday = "Sunday"
        static let dayMonday = "Monday"
        static let dayTuesday = "Tuesday"
        static let dayWednesday = "Wednesday"
        static let dayThursday = "Thursday"
        static let dayFriday = "Friday"
        static let daySaturday = "Saturday"

        // MARK: - ML Compound / Aggregator Title Templates

        static func discoveredPattern(_ patternType: String) -> String {
            "Discovered \(patternType) Pattern"
        }
        static func currentState(_ label: String) -> String {
            "Current State: \(label)"
        }
        static func tomorrowOutlook(_ riskLevel: String) -> String {
            "Tomorrow Outlook: \(riskLevel) Risk"
        }
        static func activeWarning(_ predictedEvent: String) -> String {
            "Active Warning: \(predictedEvent)"
        }
        static let sequenceInProgress = "Sequence In Progress"
        static func optimizationGap(_ percent: Int) -> String {
            "Optimization: \(percent)% Gap to Your Best"
        }
        static let yourIdealDayBlueprint = "Your Ideal Day Blueprint"

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

        static let recheckIn48Hours = "Follow up: Check again in 48 hours to make sure this is steadying before it reaches warning range."
        static let reviewIn3Days = "Follow up: Review this trend again in 3 days to confirm the direction has gotten better."

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
        //
        // Generic guidance shown alongside per-metric insights. Earlier copies
        // led with "Based on your history…" which falsely implied the hint
        // was personalized from each user's data — it isn't, it's general
        // population guidance. Reworded as "Heads up:" / "Worth knowing:" to
        // stay honest while still being useful.

        static let causalHintHRV = "Heads up: this level often follows nights with less than 6 hours of sleep."
        static let causalHintRHR = "Heads up: a higher resting heart rate often follows times of less sleep or high stress. Try for an earlier bedtime tonight."
        static let causalHintBloodOxygen = "Worth knowing: lower blood oxygen often goes with broken sleep patterns."
        static let causalHintSleepDuration = "Worth knowing: shorter sleep often follows days with low activity or late workouts."
        static let causalHintSleepDeep = "Worth knowing: drops in deep sleep often go with higher stress or shifting bedtimes."
        static let causalHintVO2Max = "Worth knowing: VO2 Max changes tend to follow shifts in workout routine over 2 to 4 weeks."
        static let causalHintActiveCalories = "Worth knowing: lower calorie burn often follows fewer steps and workout minutes."
        static let causalHintExercise = "Worth knowing: dips in exercise often line up with broken sleep patterns."
        static let causalHintBodyTemp = "Worth knowing: changes in temperature often go with shifts in sleep length and HRV."
        static let causalHintRespiratoryRate = "Worth knowing: breathing rate changes often track with sleep quality and stress levels."

        // MARK: - Action Protocol Strings

        static func sleepMetricsOff(dev: Int) -> String {
            "Your sleep numbers are \(dev)% off your usual"
        }
        static func activityDeviation(dev: Int, direction: String) -> String {
            "Your activity is \(dev)% \(direction) your recent average"
        }
        static func hrvTrending(direction: String, dev: Int) -> String {
            "Your HRV is trending \(direction), \(dev)% from your usual"
        }
        static func rhrShifted(dev: Int) -> String {
            "Your resting heart rate shifted \(dev)% from your usual"
        }
        static func mindfulnessDeviation(dev: Int, direction: String) -> String {
            "Your mindfulness time is \(dev)% \(direction) your average"
        }
        static func daylightDeviation(dev: Int, direction: String) -> String {
            "Your daylight time is \(dev)% \(direction) your average"
        }
        static let bpOutsideRange = "Your blood pressure reading is outside your usual range"
        static let recheckSingleReading = "Check again to confirm, since single readings can vary"
        static let readingOutsideRange = "this reading is outside your usual range. Keep an eye on it."
        static let recheckMetricTrend = "Check this again to confirm the trend"
        static func bodyMetricsShifted(dev: Int) -> String {
            "Your body numbers shifted \(dev)% from your usual"
        }
        static func vo2MaxTrending(direction: String, dev: Int) -> String {
            "Your VO2 max is trending \(direction), \(dev)% from your usual"
        }
        static func mobilityMetricsOff(dev: Int) -> String {
            "Your mobility numbers are \(dev)% off your usual"
        }
        static func genericMetricDeviation(metricName: String, dev: Int) -> String {
            "Your \(metricName) is \(dev)% from your usual"
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
