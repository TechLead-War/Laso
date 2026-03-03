import Foundation

/// All trackable sections across the app's views
enum AppSection: String {
    // Home (7)
    case homeRecovery = "home_recovery"
    case homeIllness = "home_illness"
    case homeBodyInsights = "home_body_insights"
    case homeTrends = "home_trends"
    case homeRisks = "home_risks"
    case homeWeeklyReview = "home_weekly_review"
    case homeHistorical = "home_historical"

    // Explore (6)
    case exploreScoreHero = "explore_score_hero"
    case exploreDataSummary = "explore_data_summary"
    case exploreNeedsAttention = "explore_needs_attention"
    case exploreDecliningTrends = "explore_declining_trends"
    case exploreCorrelations = "explore_correlations"
    case exploreCategories = "explore_categories"

    // InsightsDetail (2)
    case insightsActionItems = "insights_action_items"
    case insightsAllInsights = "insights_all_insights"

    // WeeklyReview (3)
    case weeklyReviewScore = "weekly_review_score"
    case weeklyReviewWins = "weekly_review_wins"
    case weeklyReviewWatchOut = "weekly_review_watch_out"
}

/// Tracks section-level visibility duration. Hold as @State in views (class, not struct).
final class SectionTracker {
    let section: AppSection
    let tab: AppFeature
    private var appearDate: Date?

    init(section: AppSection, tab: AppFeature) {
        self.section = section
        self.tab = tab
    }

    func appeared() {
        appearDate = Date()
        AppAnalytics.shared.trackSectionViewed(section: section, tab: tab, durationMs: 0)
    }

    func disappeared() {
        guard let start = appearDate else { return }
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        AppAnalytics.shared.trackSectionViewed(section: section, tab: tab, durationMs: durationMs)
        appearDate = nil
    }
}
