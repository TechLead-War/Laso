import Foundation
import FirebaseRemoteConfig
import Observation

/// Fetches and caches Firebase Remote Config values.
/// Provides typed accessors matching the admin panel schema:
///   - Feature access flags (per tier)
///   - Limits (free tier)
///   - Pricing (product IDs, trial days)
///   - System config (feedback, analytics, sessions)
@Observable
final class RemoteConfigManager {

    static let shared = RemoteConfigManager()

    private let remoteConfig = RemoteConfig.remoteConfig()
    private(set) var lastFetchTime: Date?
    private(set) var fetchError: String?

    // MARK: - Init

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0  // No throttle in debug
        #else
        settings.minimumFetchInterval = 3600  // 1 hour in production
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(Self.defaults)
    }

    // MARK: - Fetch

    /// Fetch and activate remote config. Call once at app launch.
    func fetchAndActivate() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                lastFetchTime = Date()
                fetchError = nil
            }
        } catch {
            fetchError = error.localizedDescription
        }
    }

    // MARK: - Feature Access

    /// Check if a feature is available for the given tier ("free" or "pro").
    func isFeatureEnabled(_ feature: FeatureKey, for tier: String) -> Bool {
        let value = remoteConfig.configValue(forKey: feature.rawValue).stringValue
        let tiers = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return tiers.contains(tier)
    }

    /// All feature keys that are enabled for a given tier.
    func enabledFeatures(for tier: String) -> Set<FeatureKey> {
        Set(FeatureKey.allCases.filter { isFeatureEnabled($0, for: tier) })
    }

    // MARK: - Limits

    var freeMetricDetailLimit: Int {
        remoteConfig.configValue(forKey: "free_metric_detail_limit").numberValue.intValue
    }

    var freeMetrics: [String] {
        let csv = remoteConfig.configValue(forKey: "free_metrics").stringValue
        return csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var freeInsightLimit: Int {
        remoteConfig.configValue(forKey: "free_insight_limit").numberValue.intValue
    }

    var freePeriods: [String] {
        let csv = remoteConfig.configValue(forKey: "free_periods").stringValue
        return csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Pricing

    var proMonthlyProductID: String {
        let value = remoteConfig.configValue(forKey: "pricing_pro_monthly_product_id").stringValue
        return value.isEmpty ? SubscriptionConfig.fallbackMonthlyProductID : value
    }

    var proYearlyProductID: String {
        let value = remoteConfig.configValue(forKey: "pricing_pro_yearly_product_id").stringValue
        return value.isEmpty ? SubscriptionConfig.fallbackYearlyProductID : value
    }

    var proTrialDays: Int {
        let value = remoteConfig.configValue(forKey: "pricing_pro_trial_days").numberValue.intValue
        return value > 0 ? value : SubscriptionConfig.fallbackTrialDays
    }

    var proMonthlyDisplayPrice: String {
        let value = remoteConfig.configValue(forKey: "pricing_pro_monthly_display_price").stringValue
        return value.isEmpty ? "$5.99" : value
    }

    var proYearlyDisplayPrice: String {
        let value = remoteConfig.configValue(forKey: "pricing_pro_yearly_display_price").stringValue
        return value.isEmpty ? "$29.99" : value
    }

    // MARK: - System

    var feedbackPromptAfterSessions: Int {
        remoteConfig.configValue(forKey: "feedback_prompt_after_sessions").numberValue.intValue
    }

    var feedbackCooldownDays: Int {
        remoteConfig.configValue(forKey: "feedback_cooldown_days").numberValue.intValue
    }

    var maxLocalAnalyticsEvents: Int {
        remoteConfig.configValue(forKey: "max_local_analytics_events").numberValue.intValue
    }

    var sessionTimeoutSeconds: Int {
        remoteConfig.configValue(forKey: "session_timeout_seconds").numberValue.intValue
    }

    // MARK: - Alert Thresholds

    /// Cooldown hours between repeated alerts for same identifier
    var alertCooldownHours: Double {
        remoteConfig.configValue(forKey: "alert_cooldown_hours").numberValue.doubleValue
    }

    /// Multiplier above 7-day avg RHR that triggers spike alert (e.g. 1.15 = 15% above)
    var heartRateSpikeMultiplier: Double {
        remoteConfig.configValue(forKey: "alert_hr_spike_multiplier").numberValue.doubleValue
    }

    /// Percentage below 7-day avg HRV that triggers drop alert (e.g. 0.7 = 30% drop)
    var hrvDropMultiplier: Double {
        remoteConfig.configValue(forKey: "alert_hrv_drop_multiplier").numberValue.doubleValue
    }

    /// Blood oxygen critical threshold (below this = critical alert)
    var spo2CriticalThreshold: Double {
        remoteConfig.configValue(forKey: "alert_spo2_critical").numberValue.doubleValue
    }

    /// Blood oxygen warning threshold (below this = warning alert)
    var spo2WarningThreshold: Double {
        remoteConfig.configValue(forKey: "alert_spo2_warning").numberValue.doubleValue
    }

    /// Respiratory rate spike multiplier (e.g. 1.25 = 25% above avg)
    var respiratoryRateSpikeMultiplier: Double {
        remoteConfig.configValue(forKey: "alert_rr_spike_multiplier").numberValue.doubleValue
    }

    /// Max heart-related alerts per day (capped separately from total)
    var heartAlertCap: Int {
        remoteConfig.configValue(forKey: "alert_heart_cap_per_day").numberValue.intValue
    }

    // MARK: - Watch Monitor

    /// Interval in seconds between periodic watch status checks
    var watchMonitorCheckInterval: Int {
        remoteConfig.configValue(forKey: "watch_monitor_check_seconds").numberValue.intValue
    }

    /// Hours of data lookback for checking if watch is being worn
    var watchDataFreshnessHours: Double {
        remoteConfig.configValue(forKey: "watch_data_freshness_hours").numberValue.doubleValue
    }

    /// Cooldown hours between "watch not worn" notifications
    var watchNotWornCooldownHours: Double {
        remoteConfig.configValue(forKey: "watch_not_worn_cooldown_hours").numberValue.doubleValue
    }

    /// Hours without data before "not worn" alert fires
    var watchNotWornThresholdHours: Double {
        remoteConfig.configValue(forKey: "watch_not_worn_threshold_hours").numberValue.doubleValue
    }

    /// Battery percentage below which low battery alert fires (0.0-1.0)
    var watchBatteryLowThreshold: Double {
        remoteConfig.configValue(forKey: "watch_battery_low_threshold").numberValue.doubleValue
    }

    // MARK: - Notification Optimizer

    /// Maximum non-daily-summary notifications per day
    var notificationDailyBudget: Int {
        remoteConfig.configValue(forKey: "notification_daily_budget").numberValue.intValue
    }

    /// 7-day open rate below which user is considered fatigued
    var notificationFatigueThreshold: Double {
        remoteConfig.configValue(forKey: "notification_fatigue_threshold").numberValue.doubleValue
    }

    /// Minimum priority score for a notification to be sent (except critical)
    var notificationMinPriorityScore: Int {
        remoteConfig.configValue(forKey: "notification_min_priority_score").numberValue.intValue
    }

    // MARK: - Analysis Thresholds

    /// Warning deviation from baseline (proportion, e.g. 0.10 = 10%)
    var analysisWarningDeviation: Double {
        remoteConfig.configValue(forKey: "analysis_warning_deviation").numberValue.doubleValue
    }

    /// Critical deviation from baseline (proportion, e.g. 0.20 = 20%)
    var analysisCriticalDeviation: Double {
        remoteConfig.configValue(forKey: "analysis_critical_deviation").numberValue.doubleValue
    }

    /// Trend slope threshold for significance
    var analysisTrendSlopeThreshold: Double {
        remoteConfig.configValue(forKey: "analysis_trend_slope_threshold").numberValue.doubleValue
    }

    // MARK: - UI Intervals

    /// Home screen auto-refresh interval in seconds
    var homeRefreshIntervalSeconds: Int {
        remoteConfig.configValue(forKey: "home_refresh_interval_seconds").numberValue.intValue
    }

    /// Days before first feedback prompt
    var feedbackDaysBeforeFirstPrompt: Int {
        remoteConfig.configValue(forKey: "feedback_days_before_first_prompt").numberValue.intValue
    }

    // MARK: - Generic Access

    /// Read any string value by key (for future keys added via admin panel).
    func string(forKey key: String) -> String? {
        let value = remoteConfig.configValue(forKey: key).stringValue
        return value.isEmpty ? nil : value
    }

    func bool(forKey key: String) -> Bool {
        remoteConfig.configValue(forKey: key).boolValue
    }

    func int(forKey key: String) -> Int {
        remoteConfig.configValue(forKey: key).numberValue.intValue
    }

    func double(forKey key: String) -> Double {
        remoteConfig.configValue(forKey: key).numberValue.doubleValue
    }
}

// MARK: - Feature Keys

extension RemoteConfigManager {

    /// Matches the 13 feature access keys defined in the admin panel.
    enum FeatureKey: String, CaseIterable {
        case healthScore       = "feature_access_healthScore"
        case categoryScores    = "feature_access_categoryScores"
        case basicMetrics      = "feature_access_basicMetrics"
        case allMetrics        = "feature_access_allMetrics"
        case sevenDayTrends    = "feature_access_sevenDayTrends"
        case extendedHistory   = "feature_access_extendedHistory"
        case riskPredictions   = "feature_access_riskPredictions"
        case focusAreas        = "feature_access_focusAreas"
        case basicInsights     = "feature_access_basicInsights"
        case allInsights       = "feature_access_allInsights"
        case liveTab           = "feature_access_liveTab"
        case exportReport      = "feature_access_exportReport"
        case advancedAnalytics = "feature_access_advancedAnalytics"
        case simulation = "feature_access_simulation"
        case clinicalIntelligence = "feature_access_clinicalIntelligence"
        case ecgIntelligence = "feature_access_ecgIntelligence"
        case nutritionCorrelations = "feature_access_nutritionCorrelations"
        case circadianAnalysis = "feature_access_circadianAnalysis"
        case adherenceTracking = "feature_access_adherenceTracking"
    }
}

// MARK: - Defaults

extension RemoteConfigManager {

    /// In-app defaults used when Remote Config hasn't been fetched yet.
    /// These mirror the initial values set in the admin panel.
    private static let defaults: [String: NSObject] = [
        // Feature access — all features enabled for pro, selected for free
        "feature_access_healthScore":       "free,pro" as NSString,
        "feature_access_categoryScores":    "free,pro" as NSString,
        "feature_access_basicMetrics":      "free,pro" as NSString,
        "feature_access_allMetrics":        "pro" as NSString,
        "feature_access_sevenDayTrends":    "free,pro" as NSString,
        "feature_access_extendedHistory":   "pro" as NSString,
        "feature_access_riskPredictions":   "pro" as NSString,
        "feature_access_focusAreas":        "pro" as NSString,
        "feature_access_basicInsights":     "free,pro" as NSString,
        "feature_access_allInsights":       "pro" as NSString,
        "feature_access_liveTab":           "pro" as NSString,
        "feature_access_exportReport":      "pro" as NSString,
        "feature_access_advancedAnalytics": "pro" as NSString,
        "feature_access_simulation": "pro" as NSString,
        "feature_access_clinicalIntelligence": "pro" as NSString,
        "feature_access_ecgIntelligence": "pro" as NSString,
        "feature_access_nutritionCorrelations": "pro" as NSString,
        "feature_access_circadianAnalysis": "pro" as NSString,
        "feature_access_adherenceTracking": "pro" as NSString,

        // Limits
        "free_metric_detail_limit": 3 as NSNumber,
        "free_metrics":             "heartRate,steps,sleepAnalysis" as NSString,
        "free_insight_limit":       2 as NSNumber,
        "free_periods":             "7d,30d" as NSString,

        // Pricing
        "pricing_pro_monthly_display_price": "$5.99" as NSString,
        "pricing_pro_yearly_display_price":  "$29.99" as NSString,
        "pricing_pro_monthly_product_id":    "com.lasohealth.monthly" as NSString,
        "pricing_pro_yearly_product_id":     "com.lasohealth.yearly" as NSString,
        "pricing_pro_trial_days":            7 as NSNumber,

        // System
        "feedback_prompt_after_sessions": 5 as NSNumber,
        "feedback_cooldown_days":         30 as NSNumber,
        "max_local_analytics_events":     500 as NSNumber,
        "session_timeout_seconds":        1800 as NSNumber,

        // Alert thresholds
        "alert_cooldown_hours":        4 as NSNumber,
        "alert_hr_spike_multiplier":   1.15 as NSNumber,
        "alert_hrv_drop_multiplier":   0.7 as NSNumber,
        "alert_spo2_critical":         92 as NSNumber,
        "alert_spo2_warning":          95 as NSNumber,
        "alert_rr_spike_multiplier":   1.25 as NSNumber,
        "alert_heart_cap_per_day":     3 as NSNumber,

        // Watch monitor
        "watch_monitor_check_seconds":     900 as NSNumber,
        "watch_data_freshness_hours":      2 as NSNumber,
        "watch_not_worn_cooldown_hours":   4 as NSNumber,
        "watch_not_worn_threshold_hours":  1 as NSNumber,
        "watch_battery_low_threshold":     0.10 as NSNumber,

        // Notification optimizer
        "notification_daily_budget":            3 as NSNumber,
        "notification_fatigue_threshold":       0.15 as NSNumber,
        "notification_min_priority_score":      30 as NSNumber,

        // Analysis thresholds
        "analysis_warning_deviation":       0.10 as NSNumber,
        "analysis_critical_deviation":      0.20 as NSNumber,
        "analysis_trend_slope_threshold":   0.02 as NSNumber,

        // UI intervals
        "home_refresh_interval_seconds":       60 as NSNumber,
        "feedback_days_before_first_prompt":   5 as NSNumber,
    ]
}
