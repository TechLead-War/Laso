import Foundation

/// All trackable sections across the app's views
enum AppSection: String {
    // Home (5)
    case homeRecovery = "home_recovery"
    case homeIllness = "home_illness"
    case homeBodyInsights = "home_body_insights"
    case homeRisks = "home_risks"
    case homeWeeklyReview = "home_weekly_review"

    // Explore (6)
    case exploreScoreHero = "explore_score_hero"
    case exploreDataSummary = "explore_data_summary"
    case exploreNeedsAttention = "explore_needs_attention"
    case exploreDecliningTrends = "explore_declining_trends"
    case exploreCorrelations = "explore_correlations"
    case exploreCategories = "explore_categories"
    case exploreYourTrends = "explore_your_trends"

    // InsightsDetail (1)
    case insightsAllInsights = "insights_all_insights"

    // WeeklyReview (3)
    case weeklyReviewScore = "weekly_review_score"
    case weeklyReviewWins = "weekly_review_wins"
    case weeklyReviewWatchOut = "weekly_review_watch_out"

    // Category Detail (5)
    case categoryDetailScore = "category_detail_score"
    case categoryDetailAnalytics = "category_detail_analytics"
    case categoryDetailHistory = "category_detail_history"
    case categoryDetailInsights = "category_detail_insights"
    case categoryDetailMetrics = "category_detail_metrics"

    // Metric Detail (6)
    case metricDetailHeader = "metric_detail_header"
    case metricDetailChart = "metric_detail_chart"
    case metricDetailSummary = "metric_detail_summary"
    case metricDetailHistory = "metric_detail_history"
    case metricDetailScoreImpact = "metric_detail_score_impact"
    case metricDetailInsights = "metric_detail_insights"
    case metricDetailComparison = "metric_detail_comparison"

    // Correlations (2)
    case correlationsFilters = "correlations_filters"
    case correlationsList = "correlations_list"

    // Settings (8)
    case settingsDevices = "settings_devices"
    case settingsNotifications = "settings_notifications"
    case settingsAlerts = "settings_alerts"
    case settingsMetricAlerts = "settings_metric_alerts"
    case settingsExport = "settings_export"
    case settingsDataStorage = "settings_data_storage"
    case settingsAbout = "settings_about"

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
@MainActor
final class SectionTracker {
    let section: AppSection
    let tab: AppFeature
    private var appearDate: Date?

    init(section: AppSection, tab: AppFeature) {
        self.section = section
        self.tab = tab
    }

    /// Only stamps the appear time. `section_viewed` is emitted once, on
    /// disappear, with the real dwell — emitting here too doubled every section
    /// impression count and half the rows carried duration_ms = 0.
    func appeared() {
        appearDate = Date()
    }

    func disappeared() {
        guard let start = appearDate else { return }
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        SectionViewBuffer.add(section: section, tab: tab, durationMs: durationMs)
        appearDate = nil
    }

    func tapped(target: String) {
        AppAnalytics.shared.trackSectionTapped(section: section, tab: tab, target: target)
    }
}

/// Batches `section_viewed` so a LazyVStack recycling five sections mid-scroll
/// does not run five analytics pipelines inside the gesture's frame budget.
/// Same events, same properties, just emitted together shortly after the scroll
/// instead of one per recycle. Flushed on screen change and on backgrounding so
/// a buffered event never outlives the screen it describes.
@MainActor
enum SectionViewBuffer {
    private struct Pending {
        let section: AppSection
        let tab: AppFeature
        let durationMs: Int
    }

    private static var pending: [Pending] = []
    private static var flushTask: Task<Void, Never>?

    /// Throttle, not debounce: the first buffered event schedules the flush and
    /// later ones join that batch. A debounce would keep restarting the timer
    /// during a long scroll and could starve the flush indefinitely.
    private static let flushDelay: Duration = .seconds(1)

    static func add(section: AppSection, tab: AppFeature, durationMs: Int) {
        pending.append(Pending(section: section, tab: tab, durationMs: durationMs))
        guard flushTask == nil else { return }
        flushTask = Task {
            try? await Task.sleep(for: flushDelay)
            flushTask = nil
            flush()
        }
    }

    static func flushNow() {
        flushTask?.cancel()
        flushTask = nil
        flush()
    }

    private static func flush() {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        for item in batch {
            AppAnalytics.shared.trackSectionViewed(
                section: item.section,
                tab: item.tab,
                durationMs: item.durationMs
            )
        }
    }
}
