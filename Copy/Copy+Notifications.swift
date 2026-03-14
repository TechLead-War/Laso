import Foundation

extension Copy {
    enum Notifications {

        // MARK: - Alert Titles

        static func criticalMetric(_ name: String) -> String { "\(name) Needs Attention" }
        static func warningMetric(_ name: String) -> String { "\(name) Worth Monitoring" }

        // MARK: - Heart Rate Alerts

        static let restingHRTitle = "Resting Heart Rate Elevated"
        static func restingHRElevated(current: Int, average: Int) -> String {
            "Your resting heart rate (\(current) bpm) is significantly above your recent average (\(average) bpm). Rest and recheck \u{2014} if it stays elevated, consider speaking with a healthcare provider."
        }

        static let highHRTitle = "High Heart Rate Detected"
        static func highHRBody(current: Int, threshold: Int) -> String {
            "Your heart rate reached \(current) bpm (threshold: \(threshold) bpm). If you weren't exercising, you may want to check with a healthcare provider."
        }

        static let lowHRTitle = "Low Heart Rate Detected"
        static func lowHRBody(current: Int, threshold: Int) -> String {
            "Your heart rate dropped to \(current) bpm (threshold: \(threshold) bpm). If you feel dizzy or faint, consider contacting a healthcare provider."
        }

        // MARK: - HRV

        static let hrvLowTitle = "HRV Significantly Low"
        static func hrvLowBody(current: Int, dropPercent: Int) -> String {
            "Your heart rate variability (\(current) ms) dropped \(dropPercent)% below your recent average. This may indicate stress or overtraining."
        }

        // MARK: - Blood Oxygen

        static let spo2CriticalTitle = "Blood Oxygen Below Typical Range"
        static func spo2CriticalBody(value: String) -> String {
            "Your blood oxygen is \(value)%. Values below 92% are unusually low \u{2014} consider speaking with a healthcare provider."
        }

        static let spo2WarningTitle = "Blood Oxygen Worth Monitoring"
        static func spo2WarningBody(value: String) -> String {
            "Your blood oxygen is \(value)%. Normal range is 95-100%. Monitor closely."
        }

        // MARK: - Respiratory Rate

        static let respiratoryRateTitle = "Respiratory Rate Elevated"
        static func respiratoryRateBody(current: String, average: String) -> String {
            "Your respiratory rate (\(current) br/min) is elevated compared to your average (\(average) br/min)."
        }

        // MARK: - Anomaly Alerts

        static func anomalyBody(metric: String, deviation: String, direction: String, current: String, unit: String) -> String {
            "Your \(metric) is \(deviation)% \(direction) your baseline. Current: \(current) \(unit)"
        }
        static func anomalyWarningBody(metric: String, deviation: String, direction: String) -> String {
            "Your \(metric) is \(deviation)% \(direction) your baseline."
        }

        // MARK: - Trend Reversal

        static func trendRecoveringTitle(metric: String) -> String { "\(metric) Recovering" }
        static func trendRecoveringBody(metric: String) -> String {
            "Good news! Your \(metric) was declining but is now trending upward."
        }

        static func trendDecliningTitle(metric: String) -> String { "\(metric) Needs Attention" }
        static func trendDecliningBody(metric: String) -> String {
            "Your \(metric) was improving but has started declining. Check your recent habits."
        }

        // MARK: - Improvement Celebration

        static func improvementTitle(metric: String, percent: String) -> String {
            "\(metric) Up \(percent)%!"
        }
        static func improvementBody(metric: String) -> String {
            "Your \(metric) improved significantly this week. Keep up the great work!"
        }

        // MARK: - Daily Summary

        static func dailySummaryTitle(score: Int, grade: String, suffix: String) -> String {
            "Health Score: \(score)/100 (\(grade))\(suffix)"
        }
        static func anomalyCallout(metric: String, direction: String, percent: String) -> String {
            "\(metric) \(direction) \(percent)%."
        }
        static func metricsNeedAttention(_ count: Int) -> String {
            "\(count) metric\(count == 1 ? "" : "s") need\(count == 1 ? "s" : "") attention."
        }
        static let allMetricsHealthy = "All metrics looking healthy!"
        static func actionPrefix(_ action: String) -> String { "Action: \(action)" }
        static func streakDays(_ days: Int) -> String { "\(days)-day streak!" }

        // MARK: - Evening Summary

        static func eveningSummaryTitle(strainLevel: String) -> String {
            "Today's Recap: \(strainLevel) Day"
        }
        static func eveningSummaryBody(strainLevel: String, score: Int) -> String {
            "You had a \(strainLevel.lowercased()) strain day (score: \(score)/100). Sleep well tonight."
        }

        // MARK: - Weekly Summary

        static func weeklyReportTitle(score: Int, change: String) -> String {
            "Weekly Report: \(score)/100 (\(change))"
        }
        static func improvedCount(_ count: Int) -> String { "\(count) improved" }
        static func declinedCount(_ count: Int) -> String { "\(count) declined" }
        static let topMovers = "Top movers: "

        // MARK: - Reengagement

        static let healthSnapshot = "Your Health Snapshot"
        static func lastScoreBody(score: Int) -> String {
            "Your last health score was \(score)/100. Check in to see what's changed."
        }
        static let insightsReady = "Your Health Insights Are Ready"
        static let insightsReadyBody = "It's been a few days — open Laso to see your latest health trends."

        // MARK: - Watch Monitor

        static let watchBatteryLow = "Watch Battery Low"
        static func watchBatteryBody(device: String, percent: Int) -> String {
            "Your \(device) battery is at \(percent)%. Charge it soon to avoid missing health data."
        }
        static func watchNotWornScheduled(device: String, wearToTrack: String) -> String {
            "\(device) hasn't recorded data for a while. \(wearToTrack)"
        }
        static func watchNotWornHours(device: String, hours: Int, minutes: Int, wearToTrack: String) -> String {
            "\(device) hasn't recorded data for \(hours)h \(minutes)m. \(wearToTrack)"
        }
        static func watchNotWornRecent(device: String, wearToTrack: String) -> String {
            "\(device) hasn't recorded data recently. \(wearToTrack)"
        }
    }
}
