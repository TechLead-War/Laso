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

    // Discovery (1)
    case discoveryFlow = "discovery_flow"

    // Live (7)
    case liveHeader = "live_header"
    case liveHeartRate = "live_heart_rate"
    case liveVitals = "live_vitals"
    case liveActivity = "live_activity"
    case liveQuickStats = "live_quick_stats"
    case liveBloodPressureTemperature = "live_blood_pressure_temperature"
    case liveWorkout = "live_workout"

    // Simulation (4)
    case simulationScoreHero = "simulation_score_hero"
    case simulationRoi = "simulation_roi"
    case simulationSliders = "simulation_sliders"
    case simulationImpact = "simulation_impact"

    // Health State Timeline (5)
    case healthStateCurrent = "health_state_current"
    case healthStateCalendar = "health_state_calendar"
    case healthStateDistribution = "health_state_distribution"
    case healthStateTransitions = "health_state_transitions"
    case healthStateGuide = "health_state_guide"

    // Paywall (4)
    case paywallHeader = "paywall_header"
    case paywallFeatures = "paywall_features"
    case paywallPricing = "paywall_pricing"
    case paywallFooter = "paywall_footer"

    // Sheets
    case scoreGuideContent = "score_guide_content"
    case recoveryInfoContent = "recovery_info_content"
    case metricLogForm = "metric_log_form"
}

/// Tracks section-level visibility duration. Hold as @State in views (class, not struct).
final class SectionTracker {
    static let stuckThresholdMs = 20_000

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
        if durationMs >= Self.stuckThresholdMs {
            AppAnalytics.shared.trackSectionStuck(section: section, tab: tab, durationMs: durationMs)
        }
        appearDate = nil
    }

    func tapped(target: String) {
        AppAnalytics.shared.trackSectionTapped(section: section, tab: tab, target: target)
    }
}
