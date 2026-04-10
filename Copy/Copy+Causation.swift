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

            return "Your \(metricName.lowercased()) \(verb) \(absDeviation)% because your \(rootCauseName.lowercased()) was \(rootDirection) (\(rootCauseAbs)% off your baseline)\(timing)."
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
            "Based on \(dataPoints) days of your data."
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
            return "Your \(factorName.lowercased()) and \(metricName.lowercased()) are connected. The last \(sampleCount) times \(factorName.lowercased()) shifted, \(metricName.lowercased()) moved about \(impact)% \(timing)."
        }

        // MARK: - Confidence and Percentile Sentences

        /// "This is in the bottom 10% of your history."
        static func percentileSentence(percentile: Double) -> String {
            let pct = Int(percentile.rounded())
            if pct <= 20 {
                return "This is in the bottom \(pct)% of your history."
            } else if pct >= 80 {
                return "This is in the top \(100 - pct)% of your history."
            }
            return ""
        }

        /// "Your data confidence is still building. Keep syncing daily."
        static let lowConfidenceNote = "Your data confidence is still building. Keep syncing daily so your insights get more personal."

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
            return "Your \(metricName.lowercased()) improved \(absDeviation)% and your \(rootCauseName.lowercased()) was \(rootAbs)% above your baseline recently."
        }

        // MARK: - Projection with Causation

        /// "At this rate, your HRV could reach warning level in about 5 days. The main driver is your sleep quality."
        static func projectionWithCause(
            metricName: String,
            days: Int,
            rootCauseName: String
        ) -> String {
            "At this rate, your \(metricName.lowercased()) could reach warning level in about \(days) days. The main driver is your \(rootCauseName.lowercased())."
        }

        /// "At this pace, this could hit a warning level in about N days."
        static func projectionWithoutCause(metricName: String, days: Int) -> String {
            "At this rate, your \(metricName.lowercased()) could reach warning level in about \(days) days."
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
            let direction = changePercent > 0 ? "Up" : "Down"
            let absChange = String(format: "%.0f", abs(changePercent))
            return "\(direction) \(absChange)% from last week."
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
                return "Your \(metricName.lowercased()) trend just flipped positive. Whatever you changed recently is working."
            } else {
                return "Your \(metricName.lowercased()) was improving but just reversed direction."
            }
        }

        // MARK: - Reversal Recommendation Sentences

        static func reversalRecoveringWithCause(metricName: String, current: String, unit: String, previous: String, causeName: String) -> String {
            "your \(metricName.lowercased()) is recovering, now \(current) \(unit) vs \(previous) \(unit) previously. Keep your \(causeName.lowercased()) consistent"
        }

        static func reversalRecovering(metricName: String, current: String, unit: String, previous: String) -> String {
            "your \(metricName.lowercased()) is recovering, now \(current) \(unit) vs \(previous) \(unit) previously"
        }

        static func reversalDeclinedWithCause(metricName: String, causeName: String) -> String {
            "your \(metricName.lowercased()) reversed direction. Focus on your \(causeName.lowercased()) to get back on track"
        }

        static func reversalDeclined(metricName: String) -> String {
            "your \(metricName.lowercased()) reversed direction. Review what changed in the past few days"
        }

        // MARK: - Title Patterns (Causation Style)

        /// "HRV Dropped, Sleep Is Why"
        static func causationTitle(metricName: String, rootCauseName: String) -> String {
            "\(metricName) Shifted, \(rootCauseName) Is Why"
        }

        /// "HRV Improving, Sleep Helped"
        static func improvingCausationTitle(metricName: String, rootCauseName: String) -> String {
            "\(metricName) Improving, \(rootCauseName) Helped"
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
