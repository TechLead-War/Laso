import Foundation
import FirebaseCore
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

    /// nil when Firebase is not configured (e.g. UI test mode)
    private let remoteConfig: RemoteConfig?
    private(set) var lastFetchTime: Date?
    private(set) var fetchError: String?

    // MARK: - Init

    private init() {
        guard FirebaseApp.app() != nil else {
            remoteConfig = nil
            return
        }
        let rc = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0  // No throttle in debug
        #else
        settings.minimumFetchInterval = 3600  // 1 hour in production
        #endif
        rc.configSettings = settings
        rc.setDefaults(Self.defaults)
        remoteConfig = rc
    }

    // MARK: - Helpers

    private func stringValue(forKey key: String) -> String {
        remoteConfig?.configValue(forKey: key).stringValue ?? (Self.defaults[key] as? String ?? "")
    }

    private func intValue(forKey key: String) -> Int {
        remoteConfig?.configValue(forKey: key).numberValue.intValue ?? (Self.defaults[key] as? NSNumber)?.intValue ?? 0
    }

    private func doubleValue(forKey key: String) -> Double {
        remoteConfig?.configValue(forKey: key).numberValue.doubleValue ?? (Self.defaults[key] as? NSNumber)?.doubleValue ?? 0
    }

    private func boolValue(forKey key: String) -> Bool {
        remoteConfig?.configValue(forKey: key).boolValue ?? (Self.defaults[key] as? NSNumber)?.boolValue ?? false
    }

    // MARK: - Fetch

    /// Fetch and activate remote config. Call once at app launch.
    func fetchAndActivate() async {
        guard let remoteConfig else { return }
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
        let value = stringValue(forKey: feature.rawValue)
        let tiers = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return tiers.contains(tier)
    }

    /// All feature keys that are enabled for a given tier.
    func enabledFeatures(for tier: String) -> Set<FeatureKey> {
        Set(FeatureKey.allCases.filter { isFeatureEnabled($0, for: tier) })
    }

    // MARK: - Limits

    var freeMetricDetailLimit: Int {
        intValue(forKey: "free_metric_detail_limit")
    }

    var freeMetrics: [String] {
        let csv = stringValue(forKey: "free_metrics")
        return csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var freeInsightLimit: Int {
        intValue(forKey: "free_insight_limit")
    }

    var freePeriods: [String] {
        let csv = stringValue(forKey: "free_periods")
        return csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Pricing

    var proMonthlyProductID: String {
        let value = stringValue(forKey: "pricing_pro_monthly_product_id")
        return value.isEmpty ? SubscriptionConfig.fallbackMonthlyProductID : value
    }

    var proYearlyProductID: String {
        let value = stringValue(forKey: "pricing_pro_yearly_product_id")
        return value.isEmpty ? SubscriptionConfig.fallbackYearlyProductID : value
    }

    var proTrialDays: Int {
        let value = intValue(forKey: "pricing_pro_trial_days")
        return value > 0 ? value : SubscriptionConfig.fallbackTrialDays
    }

    var proMonthlyDisplayPrice: String {
        let value = stringValue(forKey: "pricing_pro_monthly_display_price")
        return value.isEmpty ? "$5.99" : value
    }

    var proYearlyDisplayPrice: String {
        let value = stringValue(forKey: "pricing_pro_yearly_display_price")
        return value.isEmpty ? "$29.99" : value
    }

    // MARK: - System

    var feedbackPromptAfterSessions: Int {
        intValue(forKey: "feedback_prompt_after_sessions")
    }

    var feedbackCooldownDays: Int {
        intValue(forKey: "feedback_cooldown_days")
    }

    var maxLocalAnalyticsEvents: Int {
        intValue(forKey: "max_local_analytics_events")
    }

    var sessionTimeoutSeconds: Int {
        intValue(forKey: "session_timeout_seconds")
    }

    // MARK: - Alert Thresholds

    /// Cooldown hours between repeated alerts for same identifier
    var alertCooldownHours: Double {
        doubleValue(forKey: "alert_cooldown_hours")
    }

    /// Multiplier above 7-day avg RHR that triggers spike alert (e.g. 1.15 = 15% above)
    var heartRateSpikeMultiplier: Double {
        doubleValue(forKey: "alert_hr_spike_multiplier")
    }

    /// Percentage below 7-day avg HRV that triggers drop alert (e.g. 0.7 = 30% drop)
    var hrvDropMultiplier: Double {
        doubleValue(forKey: "alert_hrv_drop_multiplier")
    }

    /// Blood oxygen critical threshold (below this = critical alert)
    var spo2CriticalThreshold: Double {
        doubleValue(forKey: "alert_spo2_critical")
    }

    /// Blood oxygen warning threshold (below this = warning alert)
    var spo2WarningThreshold: Double {
        doubleValue(forKey: "alert_spo2_warning")
    }

    /// Respiratory rate spike multiplier (e.g. 1.25 = 25% above avg)
    var respiratoryRateSpikeMultiplier: Double {
        doubleValue(forKey: "alert_rr_spike_multiplier")
    }

    /// Max heart-related alerts per day (capped separately from total)
    var heartAlertCap: Int {
        intValue(forKey: "alert_heart_cap_per_day")
    }

    // MARK: - Watch Monitor

    /// Interval in seconds between periodic watch status checks
    var watchMonitorCheckInterval: Int {
        intValue(forKey: "watch_monitor_check_seconds")
    }

    /// Hours of data lookback for checking if watch is being worn
    var watchDataFreshnessHours: Double {
        doubleValue(forKey: "watch_data_freshness_hours")
    }

    /// Cooldown hours between "watch not worn" notifications
    var watchNotWornCooldownHours: Double {
        doubleValue(forKey: "watch_not_worn_cooldown_hours")
    }

    /// Hours without data before "not worn" alert fires
    var watchNotWornThresholdHours: Double {
        doubleValue(forKey: "watch_not_worn_threshold_hours")
    }

    /// Battery percentage below which low battery alert fires (0.0-1.0)
    var watchBatteryLowThreshold: Double {
        doubleValue(forKey: "watch_battery_low_threshold")
    }

    // MARK: - Notification Optimizer

    /// Maximum non-daily-summary notifications per day
    var notificationDailyBudget: Int {
        intValue(forKey: "notification_daily_budget")
    }

    /// 7-day open rate below which user is considered fatigued
    var notificationFatigueThreshold: Double {
        doubleValue(forKey: "notification_fatigue_threshold")
    }

    /// Minimum priority score for a notification to be sent (except critical)
    var notificationMinPriorityScore: Int {
        intValue(forKey: "notification_min_priority_score")
    }

    // MARK: - Analysis Thresholds

    /// Warning deviation from baseline (proportion, e.g. 0.10 = 10%)
    var analysisWarningDeviation: Double {
        doubleValue(forKey: "analysis_warning_deviation")
    }

    /// Critical deviation from baseline (proportion, e.g. 0.20 = 20%)
    var analysisCriticalDeviation: Double {
        doubleValue(forKey: "analysis_critical_deviation")
    }

    /// Trend slope threshold for significance
    var analysisTrendSlopeThreshold: Double {
        doubleValue(forKey: "analysis_trend_slope_threshold")
    }

    // MARK: - UI Intervals

    /// Home screen auto-refresh interval in seconds
    var homeRefreshIntervalSeconds: Int {
        intValue(forKey: "home_refresh_interval_seconds")
    }

    /// Days before first feedback prompt
    var feedbackDaysBeforeFirstPrompt: Int {
        intValue(forKey: "feedback_days_before_first_prompt")
    }

    // MARK: - Data Retention (days)

    var retentionDailySampleDays: Int {
        intValue(forKey: "retention_daily_sample_days")
    }

    var retentionAnalysisSnapshotDays: Int {
        intValue(forKey: "retention_analysis_snapshot_days")
    }

    var retentionDailyStrainDays: Int {
        intValue(forKey: "retention_daily_strain_days")
    }

    var retentionRecommendationDays: Int {
        intValue(forKey: "retention_recommendation_days")
    }

    var retentionNotificationEventDays: Int {
        intValue(forKey: "retention_notification_event_days")
    }

    var retentionAdherenceRecordDays: Int {
        intValue(forKey: "retention_adherence_record_days")
    }

    var retentionECGFeaturesDays: Int {
        intValue(forKey: "retention_ecg_features_days")
    }

    var retentionJournalEntryDays: Int {
        intValue(forKey: "retention_journal_entry_days")
    }

    var retentionModelEvaluationDays: Int {
        intValue(forKey: "retention_model_evaluation_days")
    }

    // MARK: - Monetization

    /// Whether free-year mode is active (bypasses all subscription gating for PMF signal).
    var freeYearActive: Bool {
        boolValue(forKey: "free_year_active")
    }

    // MARK: - Intelligence Notifications

    /// Whether ML intelligence card notifications are enabled
    var intelligenceNotificationsEnabled: Bool {
        boolValue(forKey: "intelligence_notifications_enabled")
    }

    // MARK: - Kill Switches

    /// Master kill switch — disables the entire app with a maintenance message
    var killSwitchEnabled: Bool {
        boolValue(forKey: "kill_switch_enabled")
    }

    var killSwitchMessage: String {
        let value = stringValue(forKey: "kill_switch_message")
        return value.isEmpty ? "Laso is temporarily unavailable. Please try again later." : value
    }

    /// Kill switch for Live tab streaming
    var killLiveTab: Bool {
        boolValue(forKey: "kill_live_tab")
    }

    /// Kill switch for ML analysis pipeline
    var killMLPipeline: Bool {
        boolValue(forKey: "kill_ml_pipeline")
    }

    /// Kill switch for CloudKit backup
    var killCloudBackup: Bool {
        boolValue(forKey: "kill_cloud_backup")
    }

    /// Kill switch for push notifications (except critical)
    var killNotifications: Bool {
        boolValue(forKey: "kill_notifications")
    }

    // MARK: - Force Update

    /// Minimum app version required (e.g. "1.48"). Users below this see a force-update screen.
    var minimumAppVersion: String {
        let value = stringValue(forKey: "minimum_app_version")
        return value.isEmpty ? "0.0" : value
    }

    /// Whether the current app version is below the required minimum
    var requiresForceUpdate: Bool {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        return current.compare(minimumAppVersion, options: .numeric) == .orderedAscending
    }

    // MARK: - Generic Access

    /// Read any string value by key (for future keys added via admin panel).
    func string(forKey key: String) -> String? {
        let value = stringValue(forKey: key)
        return value.isEmpty ? nil : value
    }

    func bool(forKey key: String) -> Bool {
        boolValue(forKey: key)
    }

    func int(forKey key: String) -> Int {
        intValue(forKey: key)
    }

    func double(forKey key: String) -> Double {
        doubleValue(forKey: key)
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
        "pricing_pro_monthly_display_price": "₹499" as NSString,
        "pricing_pro_yearly_display_price":  "₹2,499" as NSString,
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

        // Data retention (days)
        "retention_daily_sample_days":        730 as NSNumber,   // 2 years
        "retention_analysis_snapshot_days":   365 as NSNumber,   // 1 year
        "retention_daily_strain_days":        365 as NSNumber,   // 1 year
        "retention_recommendation_days":      90 as NSNumber,
        "retention_notification_event_days":  90 as NSNumber,
        "retention_adherence_record_days":    90 as NSNumber,
        "retention_ecg_features_days":        730 as NSNumber,   // 2 years (clinical value)
        "retention_journal_entry_days":       365 as NSNumber,   // 1 year
        "retention_model_evaluation_days":    180 as NSNumber,   // 6 months

        // Intelligence notifications
        "intelligence_notifications_enabled": true as NSNumber,

        // Monetization
        "free_year_active":          true as NSNumber,

        // Kill switches (all off by default)
        "kill_switch_enabled":       false as NSNumber,
        "kill_switch_message":       "" as NSString,
        "kill_live_tab":             false as NSNumber,
        "kill_ml_pipeline":          false as NSNumber,
        "kill_cloud_backup":         false as NSNumber,
        "kill_notifications":        false as NSNumber,

        // Force update
        "minimum_app_version":       "0.0" as NSString,
    ]
}
