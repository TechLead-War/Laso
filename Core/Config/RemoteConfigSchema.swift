import Foundation
import SwiftUI

// MARK: - Remote Config Schema
//
// Bundled defaults dictionary + typed `RemoteConfigManager` accessors for
// every key declared in `RemoteConfigKeys.swift`. This file is main-app-only
// because it depends on `RemoteConfigManager`, which imports
// `FirebaseRemoteConfig`. The widget extension uses `RemoteConfigKeys.swift`
// for the key namespace and reads bundled defaults directly through the
// conditional fallback in `AppColour`.
//
// Adding a new key:
//   1. Add the string constant in `RemoteConfigKeys.swift`.
//   2. Add a bundled default to `expandedDefaults` below.
//   3. Add a typed accessor in the extension at the bottom of this file.
//   4. Document it in `RemoteConfigTemplate.md` (operator-facing).
//   5. Wire it into the consumer site.

// MARK: - Defaults

extension RemoteConfigManager {

    /// In-binary defaults for every key declared in `RC`. Merged with the
    /// original defaults inside `RemoteConfigManager.init`. These are what
    /// the app uses on cold start, offline, throttle, or RC service outage.
    /// Treat them as production-quality, not placeholders — the documented
    /// 5.5-hour Firebase Remote Config outage on 2024-10-31 (Firebase Status
    /// Dashboard) is a reminder that fallbacks must run the app correctly.
    static let expandedDefaults: [String: NSObject] = [

        // Kill switches — all default OFF; flip ON in Firebase Console for incidents.
        RC.killReadinessScorer:           false as NSNumber,
        RC.killHomeLiveReadiness:         false as NSNumber,
        RC.killAnomalyAlerts:             false as NSNumber,
        RC.onboardingForceSkipToPaywall:  false as NSNumber,

        // Scoring — HealthScorer (mirrors HealthScorerConfig values).
        RC.healthCriticalDeductionCap:        50   as NSNumber,
        RC.healthCriticalDeductionPerZ:       12.0 as NSNumber,
        RC.healthWarningDeductionCap:         25   as NSNumber,
        RC.healthWarningDeductionPerZ:        8.0  as NSNumber,
        RC.healthDecliningDeductionCap:       30   as NSNumber,
        RC.healthDecliningDeductionPerPercent: 1.3 as NSNumber,
        RC.healthDecliningDeductionOffset:    2.0  as NSNumber,
        RC.healthImprovingBonusCap:           8    as NSNumber,
        RC.healthImprovingBonusPerPercent:    0.6  as NSNumber,
        RC.healthImprovingBonusOffset:        2.0  as NSNumber,
        RC.healthVolatilityFactorBase:        0.5  as NSNumber,
        RC.healthVolatilityFactorSlope:       5.0  as NSNumber,
        RC.healthVolatilityFactorCap:         2.0  as NSNumber,
        RC.healthRichnessFactorBase:          0.3  as NSNumber,
        RC.healthRichnessFactorRange:         0.7  as NSNumber,
        RC.healthAnomalyFactorBase:           0.5  as NSNumber,
        RC.healthAnomalyFactorSlope:          1.5  as NSNumber,
        RC.healthFocusBoost:                  1.2  as NSNumber,
        RC.healthCategoryWeightFloor:         0.05 as NSNumber,
        RC.healthCoverageFullWeightMetrics:   2.0  as NSNumber,
        RC.healthCoveragePower:               0.6  as NSNumber,
        RC.healthNeutralScore:                75.0 as NSNumber,

        // Scoring — ReadinessScorer (mirrors ReadinessScorerConfig values).
        RC.readinessHrvWeight:                0.40 as NSNumber,
        RC.readinessRhrWeight:                0.35 as NSNumber,
        RC.readinessSleepDurationWeight:      0.15 as NSNumber,
        RC.readinessSleepStageWeight:         0.06 as NSNumber,
        RC.readinessWorkoutWeight:            0.04 as NSNumber,
        RC.readinessBaselineSampleCap:        21.0 as NSNumber,
        RC.readinessDefaultBaselineConfidence: 0.55 as NSNumber,
        RC.readinessSleepStageConfidence:     0.85 as NSNumber,
        RC.readinessSleepDurationConfFloor:   0.5  as NSNumber,
        RC.readinessSleepDurationTargetHours: 7.0  as NSNumber,
        RC.readinessMissingCardiacAgeSeconds: 259200 as NSNumber, // 72h
        RC.readinessCardiacFreshnessHorizonSeconds: 172800 as NSNumber, // 48h
        RC.readinessFreshnessFloor:           0.35 as NSNumber,
        RC.readinessFreshnessRatioWeight:     0.65 as NSNumber,
        RC.readinessFreshnessRatioClampMax:   2.0  as NSNumber,
        RC.readinessScoreCenter:              50.0 as NSNumber,
        RC.readinessScoreConfidenceFloor:     0.35 as NSNumber,
        RC.readinessScoreConfidenceSlope:     0.65 as NSNumber,
        RC.readinessCardiacStalenessOnsetHours: 24.0 as NSNumber,
        RC.readinessCardiacStalenessPenaltyPerHour: 0.5 as NSNumber,
        RC.readinessCardiacStalenessMaxPenalty: 12.0 as NSNumber,
        RC.readinessHrvRhrTanhDivisor:        1.8  as NSNumber,
        RC.readinessHrvRhrScoreCenter:        55.0 as NSNumber,
        RC.readinessHrvRhrScoreSpread:        35.0 as NSNumber,
        RC.readinessHrvFallbackAnchor:        15.0 as NSNumber,
        RC.readinessHrvFallbackRange:         55.0 as NSNumber,
        RC.readinessRhrFallbackAnchor:        85.0 as NSNumber,
        RC.readinessRhrFallbackRange:         40.0 as NSNumber,
        RC.readinessSleepTargetHours:         7.5  as NSNumber,
        RC.readinessSleepDeficitLinear:       13.0 as NSNumber,
        RC.readinessSleepDeficitQuadratic:    4.0  as NSNumber,
        RC.readinessSleepExcessLinear:        7.0  as NSNumber,
        RC.readinessSleepExcessQuadratic:     2.0  as NSNumber,
        RC.readinessSleepDeficitFloor:        10.0 as NSNumber,
        RC.readinessSleepExcessFloor:         35.0 as NSNumber,
        RC.readinessSleepRestorativeFloor:    0.16 as NSNumber,
        RC.readinessSleepRestorativeRange:    0.24 as NSNumber,
        RC.readinessWorkoutLoadDurationCap:   75.0 as NSNumber,
        RC.readinessWorkoutLoadCalorieCap:    600.0 as NSNumber,
        RC.readinessWorkoutRecentBandHours:   6.0  as NSNumber,
        RC.readinessWorkoutMidBandHours:      18.0 as NSNumber,
        RC.readinessWorkoutRecentBase:        85.0 as NSNumber,
        RC.readinessWorkoutRecentLoadPenalty: 35.0 as NSNumber,
        RC.readinessWorkoutMidBase:           92.0 as NSNumber,
        RC.readinessWorkoutMidLoadPenalty:    25.0 as NSNumber,
        RC.readinessWorkoutLateBase:          96.0 as NSNumber,
        RC.readinessWorkoutLateLoadPenalty:   12.0 as NSNumber,
        RC.readinessWorkoutConfFloor:         0.4  as NSNumber,
        RC.readinessWorkoutConfOnsetHours:    36.0 as NSNumber,
        RC.readinessWorkoutConfDecayHours:    24.0 as NSNumber,
        RC.readinessStressHrvAnchor:          60.0 as NSNumber,
        RC.readinessStressHrvRange:           40.0 as NSNumber,
        RC.readinessStressRhrAnchor:          50.0 as NSNumber,
        RC.readinessStressRhrRange:           30.0 as NSNumber,
        RC.readinessStressChannelCap:         50.0 as NSNumber,

        // Scoring — StrainScorer (mirrors StrainScorerConfig values).
        RC.strainLowUpper:                    6.0  as NSNumber,
        RC.strainLightUpper:                  10.0 as NSNumber,
        RC.strainModerateUpper:               14.0 as NSNumber,
        RC.strainHighUpper:                   18.0 as NSNumber,
        RC.strainOverreachingUpper:           20.0 as NSNumber,
        RC.strainZoneMultiplier1:             1.0  as NSNumber,
        RC.strainZoneMultiplier2:             2.0  as NSNumber,
        RC.strainZoneMultiplier3:             4.0  as NSNumber,
        RC.strainZoneMultiplier4:             8.0  as NSNumber,
        RC.strainZoneMultiplier5:             14.0 as NSNumber,
        RC.strainMaxExpectedLoad:             800.0 as NSNumber,
        RC.strainMinDaysForBaseline:          7    as NSNumber,

        // Scoring — WorkoutBands (mirrors WorkoutBandsConfig values).
        RC.workoutGreenBandFloor:             75   as NSNumber,
        RC.workoutYellowBandFloor:            50   as NSNumber,
        RC.workoutRedBandSeed:                35   as NSNumber,
        RC.workoutYellowBandSeed:             65   as NSNumber,
        RC.workoutGreenBandSeed:              82   as NSNumber,
        RC.workoutZoneRestoringCeiling:       50   as NSNumber,
        RC.workoutZoneMaintainingCeiling:     75   as NSNumber,
        RC.workoutZoneBuildingCeiling:        90   as NSNumber,
        RC.workoutDefaultMaxHR:               190  as NSNumber,

        // Color tokens (hex strings; mirror the bundled #colorLiteral values).
        RC.colorScoreOptimal:                 "#10B981" as NSString,
        RC.colorScoreGood:                    "#34D399" as NSString,
        RC.colorScoreFair:                    "#F59E0B" as NSString,
        RC.colorScorePoor:                    "#E5484D" as NSString,
        RC.colorCategoryHeart:                "#F87171" as NSString,
        RC.colorCategorySleep:                "#818CF8" as NSString,
        RC.colorCategoryActivity:             "#FBBF24" as NSString,
        RC.colorCategoryStress:               "#A78BFA" as NSString,
        RC.colorStateRecovery:                "#34D399" as NSString,
        RC.colorStatePeakPerformance:         "#0071E3" as NSString,
        RC.colorStateStressed:                "#E5484D" as NSString,
        RC.colorStateUnderSlept:              "#A78BFA" as NSString,
        RC.colorStateActive:                  "#10B981" as NSString,
        RC.colorStateFatigued:                "#F59E0B" as NSString,
        RC.colorStateResting:                 "#4DA3FF" as NSString,
        RC.colorAchievementBronze:            "#CC8033" as NSString,
        RC.colorAchievementSilver:            "#BFBFC7" as NSString,
        RC.colorAchievementGold:              "#FFD600" as NSString,
        RC.colorAchievementPlatinum:          "#E6E8FA" as NSString,
        RC.colorAchievementDiamond:           "#B8F2FF" as NSString,
        RC.colorPremiumGradientTop:           "#FFD972" as NSString,
        RC.colorPremiumGradientBottom:        "#F5A32E" as NSString,
        RC.colorVitalityGreen:                "#34D399" as NSString,
        RC.colorVitalityYellow:               "#F59E0B" as NSString,
        RC.colorVitalityRed:                  "#E5484D" as NSString,

        // Onboarding flow shape.
        RC.onboardingSkipScreensCsv:          "" as NSString,

        // Paywall.
        RC.paywallWatchRowsMax:               4 as NSNumber,

        // Referral program master switch.
        RC.referralProgramEnabled:            true as NSNumber,

        // Quiet hours — SOURCE: common DND default (10 PM–7 AM). Overnight
        // window (start > end) handled by the consumer wrap-around comparison.
        RC.notificationQuietHoursStart:       22 as NSNumber,
        RC.notificationQuietHoursEnd:         7  as NSNumber,
        // SOURCE: industry push-conversion attribution window ~24h.
        RC.notificationConversionWindowHours: 24 as NSNumber,
        // Weekly summary fire time — 10:00 to avoid the wake-time morning daily.
        RC.weeklySummaryFireHour:             10 as NSNumber,
        RC.weeklySummaryFireMinute:           0  as NSNumber,

        // Recovery → Live Energy.
        RC.energyOnWristMaxAgeSeconds:                 600    as NSNumber,
        RC.energyMorningLockFreshnessHours:            12.0   as NSNumber,
        RC.energyKcalPerStrainPoint:                   50.0   as NSNumber,
        RC.energyMaxStrainDrain:                       60.0   as NSNumber,
        RC.energyFloor:                                5.0    as NSNumber,
        RC.energyLabelStrainThreshold:                 5.0    as NSNumber,
        RC.recoveryWeeklyTrendMinDays:                 4      as NSNumber,
        RC.recoveryWeeklyTrendThresholdSDMultiplier:   0.3    as NSNumber,
    ]
}

// MARK: - Typed accessors for new keys

extension RemoteConfigManager {

    // MARK: Kill switches

    /// True → `ReadinessScorer.assess()` returns nil; views fall back to the
    /// daily health score. Flip ON for live ML incidents.
    var killReadinessScorer: Bool { bool(forKey: RC.killReadinessScorer) }

    /// True → `HomeView` stops the live-readiness 30-min timer. Flip ON when
    /// watch sync is thrashing battery.
    var killHomeLiveReadiness: Bool { bool(forKey: RC.killHomeLiveReadiness) }

    /// True → `AlertEvaluator.evaluate(...)` returns immediately. Flip ON
    /// when threshold tuning is producing false-positive alert floods.
    var killAnomalyAlerts: Bool { bool(forKey: RC.killAnomalyAlerts) }

    /// Affirmative gate for the iOS 26 daily narrative card. Defaults true so
    /// the card is on; flip OFF to silence without rebuilding.

    /// True → onboarding jumps Welcome → Paywall, bypassing every middle
    /// screen. Use when a screen crashes mid-flow and you need new installs
    /// to reach the paywall while you ship a fix.
    var onboardingForceSkipToPaywall: Bool { bool(forKey: RC.onboardingForceSkipToPaywall) }

    // MARK: Scoring — HealthScorer

    var healthCriticalDeductionCap: Int        { int(forKey: RC.healthCriticalDeductionCap) }
    var healthCriticalDeductionPerZ: Double    { double(forKey: RC.healthCriticalDeductionPerZ) }
    var healthWarningDeductionCap: Int         { int(forKey: RC.healthWarningDeductionCap) }
    var healthWarningDeductionPerZ: Double     { double(forKey: RC.healthWarningDeductionPerZ) }
    var healthDecliningDeductionCap: Int       { int(forKey: RC.healthDecliningDeductionCap) }
    var healthDecliningDeductionPerPercent: Double { double(forKey: RC.healthDecliningDeductionPerPercent) }
    var healthDecliningDeductionOffset: Double { double(forKey: RC.healthDecliningDeductionOffset) }
    var healthImprovingBonusCap: Int           { int(forKey: RC.healthImprovingBonusCap) }
    var healthImprovingBonusPerPercent: Double { double(forKey: RC.healthImprovingBonusPerPercent) }
    var healthImprovingBonusOffset: Double     { double(forKey: RC.healthImprovingBonusOffset) }
    var healthVolatilityFactorBase: Double     { double(forKey: RC.healthVolatilityFactorBase) }
    var healthVolatilityFactorSlope: Double    { double(forKey: RC.healthVolatilityFactorSlope) }
    var healthVolatilityFactorCap: Double      { double(forKey: RC.healthVolatilityFactorCap) }
    var healthRichnessFactorBase: Double       { double(forKey: RC.healthRichnessFactorBase) }
    var healthRichnessFactorRange: Double      { double(forKey: RC.healthRichnessFactorRange) }
    var healthAnomalyFactorBase: Double        { double(forKey: RC.healthAnomalyFactorBase) }
    var healthAnomalyFactorSlope: Double       { double(forKey: RC.healthAnomalyFactorSlope) }
    var healthFocusBoost: Double               { double(forKey: RC.healthFocusBoost) }
    var healthCategoryWeightFloor: Double      { double(forKey: RC.healthCategoryWeightFloor) }
    var healthCoverageFullWeightMetrics: Double { double(forKey: RC.healthCoverageFullWeightMetrics) }
    var healthCoveragePower: Double            { double(forKey: RC.healthCoveragePower) }
    var healthNeutralScore: Double             { double(forKey: RC.healthNeutralScore) }

    // MARK: Scoring — ReadinessScorer

    var readinessHrvWeight: Double             { double(forKey: RC.readinessHrvWeight) }
    var readinessRhrWeight: Double             { double(forKey: RC.readinessRhrWeight) }
    var readinessSleepDurationWeight: Double   { double(forKey: RC.readinessSleepDurationWeight) }
    var readinessSleepStageWeight: Double      { double(forKey: RC.readinessSleepStageWeight) }
    var readinessWorkoutWeight: Double         { double(forKey: RC.readinessWorkoutWeight) }
    var readinessBaselineSampleCap: Double     { double(forKey: RC.readinessBaselineSampleCap) }
    var readinessDefaultBaselineConfidence: Double { double(forKey: RC.readinessDefaultBaselineConfidence) }
    var readinessSleepStageConfidence: Double  { double(forKey: RC.readinessSleepStageConfidence) }
    var readinessSleepDurationConfFloor: Double { double(forKey: RC.readinessSleepDurationConfFloor) }
    var readinessSleepDurationTargetHours: Double { double(forKey: RC.readinessSleepDurationTargetHours) }
    var readinessMissingCardiacAgeSeconds: TimeInterval { double(forKey: RC.readinessMissingCardiacAgeSeconds) }
    var readinessCardiacFreshnessHorizonSeconds: TimeInterval { double(forKey: RC.readinessCardiacFreshnessHorizonSeconds) }
    var readinessFreshnessFloor: Double        { double(forKey: RC.readinessFreshnessFloor) }
    var readinessFreshnessRatioWeight: Double  { double(forKey: RC.readinessFreshnessRatioWeight) }
    var readinessFreshnessRatioClampMax: Double { double(forKey: RC.readinessFreshnessRatioClampMax) }
    var readinessScoreCenter: Double           { double(forKey: RC.readinessScoreCenter) }
    var readinessScoreConfidenceFloor: Double  { double(forKey: RC.readinessScoreConfidenceFloor) }
    var readinessScoreConfidenceSlope: Double  { double(forKey: RC.readinessScoreConfidenceSlope) }
    var readinessCardiacStalenessOnsetHours: Double { double(forKey: RC.readinessCardiacStalenessOnsetHours) }
    var readinessCardiacStalenessPenaltyPerHour: Double { double(forKey: RC.readinessCardiacStalenessPenaltyPerHour) }
    var readinessCardiacStalenessMaxPenalty: Double { double(forKey: RC.readinessCardiacStalenessMaxPenalty) }
    var readinessHrvRhrTanhDivisor: Double     { double(forKey: RC.readinessHrvRhrTanhDivisor) }
    var readinessHrvRhrScoreCenter: Double     { double(forKey: RC.readinessHrvRhrScoreCenter) }
    var readinessHrvRhrScoreSpread: Double     { double(forKey: RC.readinessHrvRhrScoreSpread) }
    var readinessHrvFallbackAnchor: Double     { double(forKey: RC.readinessHrvFallbackAnchor) }
    var readinessHrvFallbackRange: Double      { double(forKey: RC.readinessHrvFallbackRange) }
    var readinessRhrFallbackAnchor: Double     { double(forKey: RC.readinessRhrFallbackAnchor) }
    var readinessRhrFallbackRange: Double      { double(forKey: RC.readinessRhrFallbackRange) }
    var readinessSleepTargetHours: Double      { double(forKey: RC.readinessSleepTargetHours) }
    var readinessSleepDeficitLinear: Double    { double(forKey: RC.readinessSleepDeficitLinear) }
    var readinessSleepDeficitQuadratic: Double { double(forKey: RC.readinessSleepDeficitQuadratic) }
    var readinessSleepExcessLinear: Double     { double(forKey: RC.readinessSleepExcessLinear) }
    var readinessSleepExcessQuadratic: Double  { double(forKey: RC.readinessSleepExcessQuadratic) }
    var readinessSleepDeficitFloor: Double     { double(forKey: RC.readinessSleepDeficitFloor) }
    var readinessSleepExcessFloor: Double      { double(forKey: RC.readinessSleepExcessFloor) }
    var readinessSleepRestorativeFloor: Double { double(forKey: RC.readinessSleepRestorativeFloor) }
    var readinessSleepRestorativeRange: Double { double(forKey: RC.readinessSleepRestorativeRange) }
    var readinessWorkoutLoadDurationCap: Double { double(forKey: RC.readinessWorkoutLoadDurationCap) }
    var readinessWorkoutLoadCalorieCap: Double { double(forKey: RC.readinessWorkoutLoadCalorieCap) }
    var readinessWorkoutRecentBandHours: Double { double(forKey: RC.readinessWorkoutRecentBandHours) }
    var readinessWorkoutMidBandHours: Double   { double(forKey: RC.readinessWorkoutMidBandHours) }
    var readinessWorkoutRecentBase: Double     { double(forKey: RC.readinessWorkoutRecentBase) }
    var readinessWorkoutRecentLoadPenalty: Double { double(forKey: RC.readinessWorkoutRecentLoadPenalty) }
    var readinessWorkoutMidBase: Double        { double(forKey: RC.readinessWorkoutMidBase) }
    var readinessWorkoutMidLoadPenalty: Double { double(forKey: RC.readinessWorkoutMidLoadPenalty) }
    var readinessWorkoutLateBase: Double       { double(forKey: RC.readinessWorkoutLateBase) }
    var readinessWorkoutLateLoadPenalty: Double { double(forKey: RC.readinessWorkoutLateLoadPenalty) }
    var readinessWorkoutConfFloor: Double      { double(forKey: RC.readinessWorkoutConfFloor) }
    var readinessWorkoutConfOnsetHours: Double { double(forKey: RC.readinessWorkoutConfOnsetHours) }
    var readinessWorkoutConfDecayHours: Double { double(forKey: RC.readinessWorkoutConfDecayHours) }
    var readinessStressHrvAnchor: Double       { double(forKey: RC.readinessStressHrvAnchor) }
    var readinessStressHrvRange: Double        { double(forKey: RC.readinessStressHrvRange) }
    var readinessStressRhrAnchor: Double       { double(forKey: RC.readinessStressRhrAnchor) }
    var readinessStressRhrRange: Double        { double(forKey: RC.readinessStressRhrRange) }
    var readinessStressChannelCap: Double      { double(forKey: RC.readinessStressChannelCap) }

    // MARK: Scoring — StrainScorer

    var strainLowUpper: Double                 { double(forKey: RC.strainLowUpper) }
    var strainLightUpper: Double               { double(forKey: RC.strainLightUpper) }
    var strainModerateUpper: Double            { double(forKey: RC.strainModerateUpper) }
    var strainHighUpper: Double                { double(forKey: RC.strainHighUpper) }
    var strainOverreachingUpper: Double        { double(forKey: RC.strainOverreachingUpper) }
    /// Re-built each call so a remote tweak to any of the 5 zone multipliers
    /// is picked up immediately. The dictionary is small (5 entries) so the
    /// allocation cost is negligible at notification / scoring frequency.
    var strainZoneMultipliers: [Int: Double] {
        [
            1: double(forKey: RC.strainZoneMultiplier1),
            2: double(forKey: RC.strainZoneMultiplier2),
            3: double(forKey: RC.strainZoneMultiplier3),
            4: double(forKey: RC.strainZoneMultiplier4),
            5: double(forKey: RC.strainZoneMultiplier5),
        ]
    }
    var strainMaxExpectedLoad: Double          { double(forKey: RC.strainMaxExpectedLoad) }
    var strainMinDaysForBaseline: Int          { int(forKey: RC.strainMinDaysForBaseline) }

    // MARK: Scoring — WorkoutBands

    var workoutGreenBandFloor: Int             { int(forKey: RC.workoutGreenBandFloor) }
    var workoutYellowBandFloor: Int            { int(forKey: RC.workoutYellowBandFloor) }
    var workoutRedBandSeed: Int                { int(forKey: RC.workoutRedBandSeed) }
    var workoutYellowBandSeed: Int             { int(forKey: RC.workoutYellowBandSeed) }
    var workoutGreenBandSeed: Int              { int(forKey: RC.workoutGreenBandSeed) }
    var workoutZoneRestoringCeiling: Int       { int(forKey: RC.workoutZoneRestoringCeiling) }
    var workoutZoneMaintainingCeiling: Int     { int(forKey: RC.workoutZoneMaintainingCeiling) }
    var workoutZoneBuildingCeiling: Int        { int(forKey: RC.workoutZoneBuildingCeiling) }
    var workoutDefaultMaxHR: Int               { int(forKey: RC.workoutDefaultMaxHR) }

    // MARK: Colors
    //
    // Returns the parsed `Color` if RC has a valid hex string, or `nil` if
    // the value is missing / malformed. Callers must supply the bundled
    // default — kept in `AppColour` — as a guaranteed fallback. This keeps
    // the design system safe during cold start, offline, throttle, and the
    // documented Firebase Remote Config outages.

    func color(forKey key: String) -> Color? {
        let hex = string(forKey: key) ?? ""
        return Color(hex: hex)
    }

    // MARK: Onboarding

    /// CSV of `OnboardingV2View.Screen` raw names to skip (e.g. "symptoms,activity").
    /// Empty string = follow normal flow. Unknown names are ignored.
    var onboardingSkipScreens: Set<String> {
        let csv = string(forKey: RC.onboardingSkipScreensCsv) ?? ""
        return Set(csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    // MARK: Referral

    var referralProgramEnabled: Bool           { bool(forKey: RC.referralProgramEnabled) }

    // MARK: Notification timing

    /// Start/end of the non-critical notification do-not-disturb window
    /// (local hour 0-23). Overnight (start > end) is handled by the consumer.
    var quietHoursStartHour: Int               { int(forKey: RC.notificationQuietHoursStart) }
    var quietHoursEndHour: Int                 { int(forKey: RC.notificationQuietHoursEnd) }

    /// Hours after a notification tap within which a goal counts as a conversion.
    var notificationConversionWindowHours: Int { int(forKey: RC.notificationConversionWindowHours) }

    /// Local hour/minute the weekly summary fires (default 10:00).
    var weeklySummaryFireHour: Int             { int(forKey: RC.weeklySummaryFireHour) }
    var weeklySummaryFireMinute: Int           { int(forKey: RC.weeklySummaryFireMinute) }

    // MARK: Recovery → Live Energy

    var energyOnWristMaxAgeSeconds: TimeInterval        { double(forKey: RC.energyOnWristMaxAgeSeconds) }
    var energyMorningLockFreshnessHours: Double         { double(forKey: RC.energyMorningLockFreshnessHours) }
    var energyKcalPerStrainPoint: Double                { double(forKey: RC.energyKcalPerStrainPoint) }
    var energyMaxStrainDrain: Double                    { double(forKey: RC.energyMaxStrainDrain) }
    var energyFloor: Double                             { double(forKey: RC.energyFloor) }
    var energyLabelStrainThreshold: Double              { double(forKey: RC.energyLabelStrainThreshold) }
    var recoveryWeeklyTrendMinDays: Int                 { int(forKey: RC.recoveryWeeklyTrendMinDays) }
    var recoveryWeeklyTrendThresholdSDMultiplier: Double { double(forKey: RC.recoveryWeeklyTrendThresholdSDMultiplier) }
}
