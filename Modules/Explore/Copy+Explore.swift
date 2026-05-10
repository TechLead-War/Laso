import Foundation

extension Copy {
    enum Explore {

        // MARK: - Navigation

        static let title = "Explore"

        // MARK: - Score Hero

        static let healthScore = "Weekly Health Score"
        static let healthScoreSubtitle = "Updated each morning. Recent days count more."

        // MARK: - Score Guide overrides (Weekly variant)
        // Reuses the shared ScoreGuideSheet, but the four sentences below
        // describe the EWMA weekly behaviour instead of the live daily score.
        enum ScoreGuide {
            static let title = "This is your Weekly Health Score"
            static let description = "A single number from 0 to 100 that shows how your body has been doing across the past two weeks, weighted toward your most recent days."
            static let howItsCalculatedBody = "Your Weekly Health Score is a smoothed average of your daily scores from the past two weeks. Recent days count for more, and today is not included until the day is finished."
            static let whenItUpdatesBody = "Your Weekly Health Score refreshes each morning when yesterday is added to the average. It does not change during the day, even when new data syncs from Apple Health."
        }
        static func ptsThisWeek(_ delta: Int) -> String { "\(delta > 0 ? "+" : "")\(delta) pts this week" }
        static func focusToImprove(_ category: String) -> String { "\(category) has the most room to grow" }

        // Score labels
        static let excellentShape = "Strong momentum"
        static let lookingGood = "Solid progress"
        static let roomToImprove = "Building up"
        static let needsAttention = "Getting started"

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
        static let almostThereBody = "A few more days of tracking and your score will be ready."
        static let noDataYetBody = "Open the Health app and allow access to see your analysis."
        static let emptyStateSyncing = "Syncing your first insights"
        static let emptyStateSyncingBody = "Apple Health is already connected. Explore will populate after the next batch of imported samples is analyzed."
        static let emptyStateConnectButton = "Connect Apple Health"

        // MARK: - Areas to Focus

        static let needsAttentionHeader = "Areas to Focus"

        // MARK: - Correlations

        static let connections = "Connections"
        static let seeAll = "See all"

        // MARK: - Categories

        static let categories = "Categories"
        static let onTrack = "On track"
        static let doingWell = "Doing well"
        static let needsWork = "Opportunity"
        static func insightCount(_ count: Int) -> String { "\(count) insight\(count == 1 ? "" : "s")" }

        // MARK: - Why this week (declining metrics + their causal explanation)

        static let decliningTrends = "Why this week"
        static let whyExplainerSubtitle = "What changed and why, in plain English."
        static let whyTapToExplain = "Tap to see why"

        // MARK: - Your Trends

        static let yourTrends = "Your Trends"
        static let trendPeriod = "Trend period"

        // MARK: - Health States

        static let healthStates = "Health States"
        static let seeHealthStatePatterns = "See your health state patterns"
        static func healthStateDuration(label: String, days: Int) -> String {
            "\(label) for \(days) day\(days == 1 ? "" : "s")"
        }

        // MARK: - Strongest Category Pill

        static func strongest(_ category: String) -> String { "Strongest: \(category)" }

        // MARK: - Pro Upsell

        static let pro = "PRO"
        static let discoverHiddenConnections = "Find hidden links between your health metrics."

        // MARK: - Declining Trends Section

        static func openMetric(_ name: String) -> String { "Open \(name)" }
        static func confidencePercent(_ percent: Int) -> String { "\(percent)% confidence" }
    }
}
