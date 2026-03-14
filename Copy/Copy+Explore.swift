import Foundation

extension Copy {
    enum Explore {

        // MARK: - Navigation

        static let title = "Explore"

        // MARK: - Score Hero

        static let healthScore = "Health Score"
        static func ptsThisWeek(_ delta: Int) -> String { "\(delta > 0 ? "+" : "")\(delta) pts this week" }
        static func focusToImprove(_ category: String) -> String { "Focus on \(category) to improve your score" }

        // Score labels
        static let excellentShape = "Excellent shape"
        static let lookingGood = "Looking good"
        static let roomToImprove = "Room to improve"
        static let needsAttention = "Needs attention"

        // MARK: - Data Summary

        static let metrics = "Metrics"
        static let dataPoints = "Data Points"
        static let day = "Day"
        static let days = "Days"
        static let insights = "Insights"

        // MARK: - Empty State

        static let yourHealthScore = "Your Health Score"
        static let almostThere = "Almost there..."
        static let noDataYet = "No data yet"
        static let almostThereBody = "A few more days of tracking and your score will be ready"
        static let noDataYetBody = "Open the Health app and allow access to see your analysis"

        // MARK: - Needs Attention

        static let needsAttentionHeader = "Needs Attention"

        // MARK: - Correlations

        static let connections = "Connections"
        static let seeAll = "See all"

        // MARK: - Categories

        static let categories = "Categories"
        static let onTrack = "On track"
        static let doingWell = "Doing well"
        static let needsWork = "Needs work"
        static func insightCount(_ count: Int) -> String { "\(count) insight\(count == 1 ? "" : "s")" }

        // MARK: - Declining Trends

        static let decliningTrends = "Declining Trends"

        // MARK: - Your Trends

        static let yourTrends = "Your Trends"
        static let trendPeriod = "Trend period"

        // MARK: - Health States

        static let healthStates = "Health States"
        static let seeHealthStatePatterns = "See your health state patterns"
        static func healthStateDuration(label: String, days: Int) -> String {
            "\(label) for \(days) day\(days == 1 ? "" : "s")"
        }
    }
}
