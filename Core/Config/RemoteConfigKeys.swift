import Foundation
import SwiftUI

// MARK: - Remote Config Keys
//
// String-key constants for every Firebase Remote Config parameter the app
// reads beyond the original `RemoteConfigManager` set, plus the `Color(hex:)`
// parser used by RC-overridable colour tokens.
//
// This file is widget-safe — it has NO dependency on Firebase or
// `RemoteConfigManager`. It is shared between the main `Laso` target and the
// `LasoWidgets` extension so both can speak about the same key namespace.
//
// The bundled defaults and the typed accessors that read these keys live in
// `RemoteConfigSchema.swift`, which is main-app-only because it imports
// `FirebaseRemoteConfig`. Operators uploading to Firebase Console use
// `RemoteConfigTemplate.md`. Engineer source of truth = this file + the
// schema file together; the markdown table mirrors them.
//
// Adding a new key:
//   1. Add the string constant in the matching `// MARK:` block below.
//   2. Add a default + typed accessor in `RemoteConfigSchema.swift`.
//   3. Add the same key + default to `RemoteConfigTemplate.md`.
//   4. Wire it into the consumer site.

enum RC {

    // MARK: Kill switches (granular, per-module)
    //
    // Each kill switch is a boolean that, when true, short-circuits a specific
    // subsystem. Keep them granular so a bad ML model does not require
    // disabling the whole app via the master `kill_switch_enabled` flag.
    // Always default false — flip ON in Firebase Console for live incidents.

    /// Disables `ReadinessScorer.assess(_:)`. Returns nil so callers fall back
    /// to the daily health score. Use when readiness ML produces bad outputs.
    /// Consumer: Core/Analysis/ReadinessScorer.swift
    static let killReadinessScorer = "kill_readiness_scorer"

    /// Stops `HomeView`'s 30-minute live-readiness refresh timer. Use when
    /// watch-side syncing thrashes battery without warning.
    /// Consumer: Modules/Dashboard/Views/Home/HomeView.swift
    static let killHomeLiveReadiness = "kill_home_live_readiness_refresh"

    /// Disables `AlertEvaluator.evaluate(...)`. Use when threshold tuning is
    /// flooding users with false-positive HR / HRV / SpO2 alerts.
    /// Consumer: Core/Notifications/AlertEvaluator.swift
    static let killAnomalyAlerts = "kill_anomaly_alerts"

    /// Affirmative flag for the iOS 26 on-device Foundation Models narrative.
    /// Disable to silence the "For You Today" card without an app update.
    /// Consumer: Modules/Dashboard/Views/Home/DailyNarrativeCard.swift
    static let aiNarrativeEnabled = "ai_narrative_enabled"

    /// Force-skips onboarding directly to the paywall step when a screen
    /// crashes mid-flow. Unblocks new installs without a release.
    /// Consumer: Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift
    static let onboardingForceSkipToPaywall = "onboarding_force_skip_to_paywall"

    // MARK: Scoring — HealthScorer
    static let healthCriticalDeductionCap        = "scoring_health_critical_deduction_cap"
    static let healthCriticalDeductionPerZ       = "scoring_health_critical_deduction_per_z"
    static let healthWarningDeductionCap         = "scoring_health_warning_deduction_cap"
    static let healthWarningDeductionPerZ        = "scoring_health_warning_deduction_per_z"
    static let healthDecliningDeductionCap       = "scoring_health_declining_deduction_cap"
    static let healthDecliningDeductionPerPercent = "scoring_health_declining_deduction_per_percent"
    static let healthDecliningDeductionOffset    = "scoring_health_declining_deduction_offset"
    static let healthImprovingBonusCap           = "scoring_health_improving_bonus_cap"
    static let healthImprovingBonusPerPercent    = "scoring_health_improving_bonus_per_percent"
    static let healthImprovingBonusOffset        = "scoring_health_improving_bonus_offset"
    static let healthVolatilityFactorBase        = "scoring_health_volatility_factor_base"
    static let healthVolatilityFactorSlope       = "scoring_health_volatility_factor_slope"
    static let healthVolatilityFactorCap         = "scoring_health_volatility_factor_cap"
    static let healthRichnessFactorBase          = "scoring_health_richness_factor_base"
    static let healthRichnessFactorRange         = "scoring_health_richness_factor_range"
    static let healthAnomalyFactorBase           = "scoring_health_anomaly_factor_base"
    static let healthAnomalyFactorSlope          = "scoring_health_anomaly_factor_slope"
    static let healthFocusBoost                  = "scoring_health_focus_boost"
    static let healthCategoryWeightFloor         = "scoring_health_category_weight_floor"
    static let healthNoBaselineWeight            = "scoring_health_no_baseline_weight"
    static let healthFreshnessFreshDayCutoff     = "scoring_health_freshness_fresh_day_cutoff"
    static let healthFreshnessFreshScore         = "scoring_health_freshness_fresh_score"
    static let healthFreshnessRecentDayCutoff    = "scoring_health_freshness_recent_day_cutoff"
    static let healthFreshnessRecentDecayPerDay  = "scoring_health_freshness_recent_decay_per_day"
    static let healthFreshnessLongTermBase       = "scoring_health_freshness_long_term_base"
    static let healthFreshnessLongTermDecayPerDay = "scoring_health_freshness_long_term_decay_per_day"
    static let healthFreshnessFloor              = "scoring_health_freshness_floor"
    static let healthMetricWeightAbsoluteFloor   = "scoring_health_metric_weight_absolute_floor"
    static let healthMetricWeightEqualShareDivisor = "scoring_health_metric_weight_equal_share_divisor"
    static let healthCoverageFullWeightMetrics   = "scoring_health_coverage_full_weight_metrics"
    static let healthCoveragePower               = "scoring_health_coverage_power"
    static let healthNeutralScore                = "scoring_health_neutral_score"

    // MARK: Scoring — ReadinessScorer
    static let readinessHrvWeight                = "scoring_readiness_hrv_weight"
    static let readinessRhrWeight                = "scoring_readiness_rhr_weight"
    static let readinessSleepDurationWeight      = "scoring_readiness_sleep_duration_weight"
    static let readinessSleepStageWeight         = "scoring_readiness_sleep_stage_weight"
    static let readinessWorkoutWeight            = "scoring_readiness_workout_weight"
    static let readinessBaselineSampleCap        = "scoring_readiness_baseline_sample_cap"
    static let readinessDefaultBaselineConfidence = "scoring_readiness_default_baseline_confidence"
    static let readinessSleepStageConfidence     = "scoring_readiness_sleep_stage_confidence"
    static let readinessSleepDurationConfFloor   = "scoring_readiness_sleep_duration_conf_floor"
    static let readinessSleepDurationTargetHours = "scoring_readiness_sleep_duration_target_hours"
    static let readinessMissingCardiacAgeSeconds = "scoring_readiness_missing_cardiac_age_seconds"
    static let readinessCardiacFreshnessHorizonSeconds = "scoring_readiness_cardiac_freshness_horizon_seconds"
    static let readinessFreshnessFloor           = "scoring_readiness_freshness_floor"
    static let readinessFreshnessRatioWeight     = "scoring_readiness_freshness_ratio_weight"
    static let readinessFreshnessRatioClampMax   = "scoring_readiness_freshness_ratio_clamp_max"
    static let readinessScoreCenter              = "scoring_readiness_score_center"
    static let readinessScoreConfidenceFloor     = "scoring_readiness_score_confidence_floor"
    static let readinessScoreConfidenceSlope     = "scoring_readiness_score_confidence_slope"
    static let readinessCardiacStalenessOnsetHours = "scoring_readiness_cardiac_staleness_onset_hours"
    static let readinessCardiacStalenessPenaltyPerHour = "scoring_readiness_cardiac_staleness_penalty_per_hour"
    static let readinessCardiacStalenessMaxPenalty = "scoring_readiness_cardiac_staleness_max_penalty"
    static let readinessHrvRhrTanhDivisor        = "scoring_readiness_hrv_rhr_tanh_divisor"
    static let readinessHrvRhrScoreCenter        = "scoring_readiness_hrv_rhr_score_center"
    static let readinessHrvRhrScoreSpread        = "scoring_readiness_hrv_rhr_score_spread"
    static let readinessHrvFallbackAnchor        = "scoring_readiness_hrv_fallback_anchor"
    static let readinessHrvFallbackRange         = "scoring_readiness_hrv_fallback_range"
    static let readinessRhrFallbackAnchor        = "scoring_readiness_rhr_fallback_anchor"
    static let readinessRhrFallbackRange         = "scoring_readiness_rhr_fallback_range"
    static let readinessSleepTargetHours         = "scoring_readiness_sleep_target_hours"
    static let readinessSleepDeficitLinear       = "scoring_readiness_sleep_deficit_linear_penalty"
    static let readinessSleepDeficitQuadratic    = "scoring_readiness_sleep_deficit_quadratic_penalty"
    static let readinessSleepExcessLinear        = "scoring_readiness_sleep_excess_linear_penalty"
    static let readinessSleepExcessQuadratic     = "scoring_readiness_sleep_excess_quadratic_penalty"
    static let readinessSleepDeficitFloor        = "scoring_readiness_sleep_duration_deficit_floor"
    static let readinessSleepExcessFloor         = "scoring_readiness_sleep_duration_excess_floor"
    static let readinessSleepRestorativeFloor    = "scoring_readiness_sleep_restorative_ratio_floor"
    static let readinessSleepRestorativeRange    = "scoring_readiness_sleep_restorative_ratio_range"
    static let readinessWorkoutLoadDurationCap   = "scoring_readiness_workout_load_duration_cap"
    static let readinessWorkoutLoadCalorieCap    = "scoring_readiness_workout_load_calorie_cap"
    static let readinessWorkoutRecentBandHours   = "scoring_readiness_workout_recent_band_hours"
    static let readinessWorkoutMidBandHours      = "scoring_readiness_workout_mid_band_hours"
    static let readinessWorkoutRecentBase        = "scoring_readiness_workout_recent_base"
    static let readinessWorkoutRecentLoadPenalty = "scoring_readiness_workout_recent_load_penalty"
    static let readinessWorkoutMidBase           = "scoring_readiness_workout_mid_base"
    static let readinessWorkoutMidLoadPenalty    = "scoring_readiness_workout_mid_load_penalty"
    static let readinessWorkoutLateBase          = "scoring_readiness_workout_late_base"
    static let readinessWorkoutLateLoadPenalty   = "scoring_readiness_workout_late_load_penalty"
    static let readinessWorkoutConfFloor         = "scoring_readiness_workout_conf_floor"
    static let readinessWorkoutConfOnsetHours    = "scoring_readiness_workout_conf_onset_hours"
    static let readinessWorkoutConfDecayHours    = "scoring_readiness_workout_conf_decay_hours"
    static let readinessStressHrvAnchor          = "scoring_readiness_stress_hrv_anchor"
    static let readinessStressHrvRange           = "scoring_readiness_stress_hrv_range"
    static let readinessStressRhrAnchor          = "scoring_readiness_stress_rhr_anchor"
    static let readinessStressRhrRange           = "scoring_readiness_stress_rhr_range"
    static let readinessStressChannelCap         = "scoring_readiness_stress_channel_cap"

    // MARK: Scoring — StrainScorer
    static let strainLowUpper                    = "scoring_strain_low_upper_exclusive"
    static let strainLightUpper                  = "scoring_strain_light_upper_exclusive"
    static let strainModerateUpper               = "scoring_strain_moderate_upper_exclusive"
    static let strainHighUpper                   = "scoring_strain_high_upper_exclusive"
    static let strainOverreachingUpper           = "scoring_strain_overreaching_upper_exclusive"
    static let strainZoneMultiplier1             = "scoring_strain_zone_multiplier_1"
    static let strainZoneMultiplier2             = "scoring_strain_zone_multiplier_2"
    static let strainZoneMultiplier3             = "scoring_strain_zone_multiplier_3"
    static let strainZoneMultiplier4             = "scoring_strain_zone_multiplier_4"
    static let strainZoneMultiplier5             = "scoring_strain_zone_multiplier_5"
    static let strainMaxExpectedLoad             = "scoring_strain_max_expected_load"
    static let strainMinDaysForBaseline          = "scoring_strain_min_days_for_baseline"
    static let strainFallbackTodayCalorieCap     = "scoring_strain_fallback_today_calorie_cap"
    static let strainDefaultRestingHeartRate     = "scoring_strain_default_resting_heart_rate"

    // MARK: Scoring — WorkoutBands
    static let workoutGreenBandFloor             = "scoring_workout_green_band_floor"
    static let workoutYellowBandFloor            = "scoring_workout_yellow_band_floor"
    static let workoutRedBandSeed                = "scoring_workout_red_band_seed"
    static let workoutYellowBandSeed             = "scoring_workout_yellow_band_seed"
    static let workoutGreenBandSeed              = "scoring_workout_green_band_seed"
    static let workoutZoneRestoringCeiling       = "scoring_workout_zone_restoring_ceiling"
    static let workoutZoneMaintainingCeiling     = "scoring_workout_zone_maintaining_ceiling"
    static let workoutZoneBuildingCeiling        = "scoring_workout_zone_building_ceiling"
    static let workoutDefaultMaxHR               = "scoring_workout_default_max_hr"

    // MARK: Color tokens (designer-tweakable subset)
    //
    // Hex strings (e.g. "#10B981"). Locked tokens (brand `primary`, `accent`,
    // surface stack, semantic state, share-card gradients) stay code-side
    // because they encode brand identity / iOS HIG semantics.
    static let colorScoreOptimal                 = "color_score_optimal"
    static let colorScoreGood                    = "color_score_good"
    static let colorScoreFair                    = "color_score_fair"
    static let colorScorePoor                    = "color_score_poor"
    static let colorCategoryHeart                = "color_category_heart"
    static let colorCategorySleep                = "color_category_sleep"
    static let colorCategoryActivity             = "color_category_activity"
    static let colorCategoryStress               = "color_category_stress"
    static let colorCategoryVitality             = "color_category_vitality"
    static let colorCategoryBrain                = "color_category_brain"
    static let colorStateRecovery                = "color_state_recovery"
    static let colorStatePeakPerformance         = "color_state_peak_performance"
    static let colorStateStressed                = "color_state_stressed"
    static let colorStateUnderSlept              = "color_state_under_slept"
    static let colorStateActive                  = "color_state_active"
    static let colorStateFatigued                = "color_state_fatigued"
    static let colorStateResting                 = "color_state_resting"
    static let colorAchievementBronze            = "color_achievement_bronze"
    static let colorAchievementSilver            = "color_achievement_silver"
    static let colorAchievementGold              = "color_achievement_gold"
    static let colorAchievementPlatinum          = "color_achievement_platinum"
    static let colorAchievementDiamond           = "color_achievement_diamond"
    static let colorAchievementLegend            = "color_achievement_legend"
    static let colorPremiumGradientTop           = "color_premium_gradient_top"
    static let colorPremiumGradientBottom        = "color_premium_gradient_bottom"
    static let colorVitalityGreen                = "color_vitality_green"
    static let colorVitalityYellow               = "color_vitality_yellow"
    static let colorVitalityRed                  = "color_vitality_red"

    // MARK: Onboarding
    static let onboardingSkipScreensCsv          = "onboarding_skip_screens"
    static let onboardingFastTrackEnabled        = "onboarding_fast_track_enabled"
    static let onboardingVariant                 = "onboarding_variant"

    // MARK: Paywall
    static let paywallVariant                    = "paywall_variant"
    static let paywallShowYearlyDefault          = "paywall_show_yearly_default"

    // MARK: Notification timing
    static let notificationMorningStartHour      = "notification_morning_start_hour"
    static let notificationMorningEndHour        = "notification_morning_end_hour"
    static let notificationEveningStartHour      = "notification_evening_start_hour"
    static let notificationEveningEndHour        = "notification_evening_end_hour"
    static let notificationHookStyle             = "notification_hook_style"

    /// Local-hour bounds of the do-not-disturb window. Non-critical pushes
    /// scheduled to fire inside [start, end) are suppressed. Overnight window
    /// (start > end) is handled by the consumer's wrap-around comparison.
    /// Consumer: Core/Notifications/NotificationManager.isWithinQuietHours +
    /// Core/Analysis/ML/ReceptivityEstimator.swift.
    static let notificationQuietHoursStart       = "notification_quiet_hours_start"
    static let notificationQuietHoursEnd         = "notification_quiet_hours_end"

    /// Attribution window (hours) a caller uses to credit a goal completion to
    /// a prior notification tap. Industry push-conversion attribution ~24h.
    /// Consumer: AppAnalytics.trackNotificationConverted gate (caller-side).
    static let notificationConversionWindowHours = "notification_conversion_window_hours"

    /// Local fire time of the weekly summary push. Default 10:00 (not 09:00)
    /// to avoid colliding with the morning daily summary around wake time.
    /// Consumer: Core/Notifications/WeeklySummaryScheduler.swift.
    static let weeklySummaryFireHour             = "weekly_summary_fire_hour"
    static let weeklySummaryFireMinute           = "weekly_summary_fire_minute"

    // MARK: A/B experiments
    static let experimentRecoveryCardStyle       = "experiment_recovery_card_style"

    // MARK: Recovery → Live Energy
    //
    // Tunables for the morning Recovery lock + live Energy drain on Home.
    // Consumer: Modules/Live/ViewModels/LiveViewModel.swift via
    // `ReadinessScorerConfig` typed accessors.
    static let energyOnWristMaxAgeSeconds        = "energy_on_wrist_max_age_seconds"
    static let energyMorningLockFreshnessHours   = "energy_morning_lock_freshness_hours"
    static let energyKcalPerStrainPoint          = "energy_kcal_per_strain_point"
    static let energyMaxStrainDrain              = "energy_max_strain_drain"
    static let energyFloor                       = "energy_floor"
    static let energyLabelStrainThreshold        = "energy_label_strain_threshold"
    static let recoveryWeeklyTrendMinDays        = "recovery_weekly_trend_min_days"
    static let recoveryWeeklyTrendThresholdSDMultiplier = "recovery_weekly_trend_threshold_sd_multiplier"
}

// MARK: - Hex → Color

extension Color {

    /// Parses `"#RRGGBB"`, `"RRGGBB"`, `"#RRGGBBAA"`, or `"RRGGBBAA"`. Returns
    /// nil for anything else so callers can fall back to a bundled default.
    /// Tolerates leading whitespace and case-insensitive hex digits.
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6 || raw.count == 8 else { return nil }
        guard let value = UInt64(raw, radix: 16) else { return nil }
        let r, g, b, a: Double
        if raw.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF)  / 255.0
            b = Double(value & 0xFF)         / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF)  / 255.0
            a = Double(value & 0xFF)         / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
