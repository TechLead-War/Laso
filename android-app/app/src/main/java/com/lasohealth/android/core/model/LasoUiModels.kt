package com.lasohealth.android.core.model

import androidx.compose.ui.graphics.Color
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

data class HomeUiState(
    val greeting: String,
    val score: Int,
    val dailyScore: Int,
    val recoveryLabel: String,
    val recoveryStateLabel: String,
    val dayType: String,
    val dayClassification: String,
    val scoreDelta: Int?,
    val streakDays: Int,
    val level: String,
    val totalDaysTracked: Int,
    val progressToNextLevel: Float,
    val lastUpdated: String,
    val primaryAction: ActionCardUi,
    val alerts: List<AlertUi>,
    val metrics: List<MetricTileUi>,
    val insights: List<InsightUi>,
    val weeklyReview: WeeklyReviewUi,
    val illnessWarning: IllnessWarningUi? = null,
    val bodyInsight: BodyInsightUi? = null,
    val correlations: List<CorrelationUi> = emptyList(),
    val activityStreak: Int = 0,
    val sleepStreak: Int = 0,
    val recoveryStreak: Int = 0,
)

data class IllnessWarningUi(
    val narrative: String,
    val severity: String,
)

data class BodyInsightUi(
    val title: String,
    val narrative: String,
    val isChain: Boolean,
)

data class ActionCardUi(
    val title: String,
    val detail: String,
    val cta: String,
    val iconEmoji: String = "",
)

data class AlertUi(
    val title: String,
    val detail: String,
    val severity: AlertSeverity,
)

data class MetricTileUi(
    val metric: HealthMetric,
    val value: String,
    val trend: String,
    val label: String = "",
    val badge: String = "",
    val badgeColor: String = "",
)

data class InsightUi(
    val title: String,
    val detail: String,
    val metric: HealthMetric,
)

data class WeeklyReviewUi(
    val title: String,
    val detail: String,
    val highlight: String,
)

enum class AlertSeverity(
    val label: String,
    val accentColor: Color,
) {
    HIGH("High", AccentRed),
    MODERATE("Moderate", AccentOrange),
    LOW("Low", AccentYellow),
}

data class LiveUiState(
    val isStreaming: Boolean,
    val freshnessLabel: String,
    val currentHeartRate: Int?,
    val heartRateZoneLabel: String,
    val heartRateZonePercent: Float,
    val readinessScore: Int,
    val bloodOxygen: Int,
    val respiratoryRate: Double,
    val heartRateVariability: Int,
    val stressLabel: String,
    val activity: ActivityUi,
    val workout: WorkoutUi?,
    val lastUpdatedLabel: String,
    val heartRateMin: Int? = null,
    val heartRateAvg: Int? = null,
    val heartRateMax: Int? = null,
    val todayHeartRateMin: Int? = null,
    val todayHeartRateMax: Int? = null,
    val hasFreshData: Boolean = false,
    val isAging: Boolean = false,
    val isStale: Boolean = false,
    val hasAnyData: Boolean = true,
    val recentHeartRates: List<HeartRateEntry> = emptyList(),
    val systolic: Int? = null,
    val diastolic: Int? = null,
    val bodyTemperature: Double? = null,
    val bloodPressureStatus: String = "Normal",
)

data class ActivityUi(
    val steps: Int,
    val activeCalories: Int,
    val exerciseMinutes: Int,
    val standHours: Int,
    val moveGoal: Int = 500,
    val exerciseGoal: Int = 30,
    val standGoal: Int = 12,
    val moveProgress: Float = 0f,
    val exerciseProgress: Float = 0f,
    val standProgress: Float = 0f,
    val distance: Double = 0.0,
    val flightsClimbed: Int = 0,
)

data class WorkoutUi(
    val title: String,
    val durationMinutes: Int,
    val strainLabel: String,
    val suggestion: String,
)

data class HeartRateEntry(
    val minutesAgo: Int,
    val value: Int,
)

data class ExploreUiState(
    val overallScore: Int,
    val scoreChangeFromLastWeek: Int,
    val weakestCategory: HealthCategory,
    val metricsTracked: Int,
    val totalDataPoints: Int,
    val daysOfData: Int,
    val insightCount: Int = 0,
    val trendMetrics: List<TrendMetricUi>,
    val categoryScores: List<CategoryScoreUi>,
    val needsAttention: List<AttentionUi>,
    val correlations: List<CorrelationUi>,
    val decliningTrends: List<DecliningTrendUi> = emptyList(),
    val currentHealthState: String? = null,
    val healthStateDays: Int = 0,
    val strongestCategory: HealthCategory? = null,
    val hasData: Boolean = true,
)

data class DecliningTrendUi(
    val metric: HealthMetric,
    val title: String,
    val recommendation: String,
    val typeLabel: String = "Declining",
)

data class TrendMetricUi(
    val metric: HealthMetric,
    val summary: String,
    val sparklineValues: List<Float> = emptyList(),
    val direction: TrendDirection = TrendDirection.STABLE,
)

data class CategoryScoreUi(
    val category: HealthCategory,
    val score: Int,
    val insightCount: Int = 0,
)

data class AttentionUi(
    val metric: HealthMetric,
    val summary: String,
    val impact: Int = 0,
)

data class CorrelationUi(
    val title: String,
    val summary: String,
    val metricA: HealthMetric = HealthMetric.HEART_RATE,
    val metricB: HealthMetric = HealthMetric.SLEEP_DURATION,
)

data class PlatformStatus(
    val sourceName: String,
    val notes: List<String>,
)

// ── Detail Screen Models ────────────────────────────────────────────────────

data class MetricDetailUiState(
    val metric: HealthMetric,
    val currentValue: String,
    val unit: String,
    val baselineValue: String,
    val statusLabel: String,
    val average: String,
    val min: String,
    val max: String,
    val monthOverMonthChange: String?,
    val scoreContribution: Int,
    val categoryImpact: String,
    val historicalFacts: List<String>,
    val relatedInsights: List<InsightUi>,
    val chartValues: List<Float> = emptyList(),
    val weekOverWeekBadge: String = "",
    val dataSource: String = "",
    val actionRecommendation: String = "",
)

data class CategoryDetailUiState(
    val category: HealthCategory,
    val score: Int,
    val scoreContribution: String,
    val historicalHighlights: List<String>,
    val insights: List<InsightUi>,
    val metrics: List<CategoryMetricRow>,
)

data class CategoryMetricRow(
    val metric: HealthMetric,
    val currentValue: String,
    val statusLabel: String,
)

data class WeeklyReviewDetailUiState(
    val score: Int,
    val scoreDeltaFromLastWeek: Int?,
    val avgHeartRate: Int,
    val avgSleep: String,
    val avgSteps: Int,
    val alertCount: Int,
    val trendDirection: String,
    val winCount: Int,
    val bestMetric: MetricChangeUi?,
    val worstMetric: MetricChangeUi?,
    val wins: List<MetricChangeUi>,
    val watchOuts: List<MetricChangeUi>,
    val topInsight: InsightUi?,
    val coachTarget: CoachTargetUi?,
    val nextWeekMessage: String,
)

data class MetricChangeUi(
    val metricName: String,
    val changePercent: String,
    val nudge: String = "",
)

data class CoachTargetUi(
    val currentTarget: String,
    val currentAverage: String,
    val adherenceLabel: String,
    val nextWeekTarget: String,
    val nextWeekDelta: String,
    val coachingMessage: String,
)

data class AchievementsUiState(
    val levelName: String,
    val levelEmoji: String,
    val progressToNext: Float,
    val totalDaysTracked: Int,
    val totalAchievements: Int,
    val unlockedAchievements: Int,
    val longestStreak: Int,
    val streaks: StreaksUi,
    val achievements: List<AchievementUi>,
)

data class StreaksUi(
    val activity: StreakUi,
    val sleep: StreakUi,
    val recovery: StreakUi,
    val checkIn: StreakUi,
    val master: StreakUi,
)

data class StreakUi(
    val current: Int,
    val best: Int,
)

data class AchievementUi(
    val title: String,
    val description: String,
    val emoji: String,
    val isUnlocked: Boolean,
    val unlockDate: String? = null,
    val category: String,
)

data class ConnectedDevicesUiState(
    val headline: String,
    val detail: String,
    val connectedCount: Int,
    val coveragePercent: Int,
    val lastSync: String,
    val activeSources: List<DeviceUi>,
    val inactiveSources: List<DeviceUi>,
    val availableSources: List<DeviceUi>,
)

data class DeviceUi(
    val id: String,
    val name: String,
    val emoji: String,
    val statusLabel: String,
    val metricsCount: Int,
    val isActive: Boolean,
)

data class DeviceDetailUiState(
    val id: String,
    val name: String,
    val emoji: String,
    val statusLabel: String,
    val metricsProvided: List<String>,
    val lastSync: String,
    val troubleshooting: String?,
)

data class VitalityDetailUiState(
    val vitalityAge: Int,
    val biologicalAge: Int,
    val delta: Int,
    val score: Int,
    val trendDirection: String,
    val paceLabel: String = "Healthy",
    val heroNarrative: String = "",
    val contributions: List<MetricContributionUi>,
    val improvements: List<VitalityImprovementUi> = emptyList(),
    val trendHistory: List<Float> = emptyList(),
    val historicalComparison: String?,
    val methodologyText: String = "Vitality Age compares your health metrics against age-matched population norms. Each metric contributes a component age — the weighted average becomes your Vitality Age. Lower is better.",
)

data class MetricContributionUi(
    val name: String,
    val value: String,
    val impact: String,
    val metricAge: Int = 0,
    val delta: Int = 0,
    val gaugePosition: Float = 0.5f,
    val subtitle: String = "",
    val metric: HealthMetric? = null,
)

data class VitalityImprovementUi(
    val metricName: String,
    val impactYears: Int,
    val description: String,
)

data class StrainDetailUiState(
    val strainScore: Double,
    val strainLevel: String,
    val targetMin: Double,
    val targetMax: Double,
    val zoneMinutes: Map<Int, Double> = emptyMap(),
    val weeklyHistory: List<Float>,
    val balanceLabel: String,
    val guidance: String,
    val trainingZone: String = "",
    val strainBalance: String = "Optimal",
)

data class StressMonitorUiState(
    val stressScore: Double,
    val stressLevel: String,
    val hrvDeviation: Double = 0.0,
    val hrElevation: Double = 0.0,
    val weeklyScores: List<Double> = emptyList(),
    val weeklyAverage: Double = 0.0,
    val previousWeekAverage: Double = 0.0,
)

data class BrainHealthUiState(
    val score: Int,
    val grade: String,
    val stateLabel: String,
    val headline: String = "",
    val weeklyHistory: List<Int>,
    val contributingFactors: List<MetricContributionUi>,
    val cognitiveReadiness: Int = 0,
    val memoryRecovery: Int = 0,
    val stressCognitionLoad: Int = 0,
    val neurovascularFitness: Int = 0,
    val circadianAlignment: Int = 0,
    val confidence: Float = 1f,
    val trend: String = "stable",
    val topFactors: List<BrainFactorUi> = emptyList(),
)

data class BrainFactorUi(
    val label: String,
    val impact: String,
    val isPositive: Boolean,
)

data class SleepCoachUiState(
    val baseHoursNeeded: Double,
    val recommendedBedtime: String,
    val recommendedWakeTime: String,
    val sleepDebt: Double,
    val consistencyScore: Int,
    val dailyHistory: List<SleepDayUi>,
)

data class SleepDayUi(
    val day: String,
    val actual: Double,
    val target: Double,
)

data class CycleDetailUiState(
    val currentPhase: String,
    val dayInCycle: Int,
    val cycleLength: Int,
    val daysUntilPeriod: Int?,
    val phaseColor: String,
    val phaseProgress: Float,
    val phaseDurations: List<PhaseDurationUi>,
    val cycleHistory: List<Int>,
    val nextPeriodEstimate: String?,
)

data class PhaseDurationUi(
    val name: String,
    val days: Int,
    val color: String,
)

data class HealthStateTimelineUiState(
    val currentState: String,
    val stateDuration: String,
    val states: List<HealthStateEntryUi>,
)

data class HealthStateEntryUi(
    val label: String,
    val startDate: String,
    val duration: String,
    val color: String,
)

data class SettingsUiState(
    val connectedDeviceCount: Int,
    val dailySummaryEnabled: Boolean,
    val weeklySummaryEnabled: Boolean,
    val hrAlertsEnabled: Boolean,
    val highHrThreshold: Int,
    val lowHrThreshold: Int,
    val criticalAlertsEnabled: Boolean,
    val warningAlertsEnabled: Boolean,
    val trendReversalEnabled: Boolean,
    val celebrationsEnabled: Boolean,
    val maxAlertsPerDay: Int,
    val storedSamplesCount: Int,
    val dataHistorySpan: String,
    val metricsTrackedCount: Int,
    val isPro: Boolean,
)

// ── Report Models ───────────────────────────────────────────────────────────

data class AnnualReportUiState(
    val year: Int,
    val monthlyScores: List<Int>,
    val averageScore: Int,
    val totalDaysTracked: Int,
    val insightsGenerated: Int,
    val achievementsUnlocked: Int,
    val longestStreak: Int,
    val categoryPerformance: List<CategoryPerformanceUi>,
    val milestones: List<MilestoneUi>,
    val topDiscoveries: List<DiscoveryUi>,
    val recommendations: List<RecommendationUi>,
)

data class CategoryPerformanceUi(
    val name: String,
    val emoji: String,
    val score: Int,
    val trend: String,
)

data class MilestoneUi(
    val title: String,
    val emoji: String,
    val date: String,
)

data class DiscoveryUi(
    val text: String,
    val date: String,
)

data class RecommendationUi(
    val title: String,
    val description: String,
    val emoji: String,
)

data class MonthlyReviewUiState(
    val monthName: String,
    val year: Int,
    val overallScore: Int,
    val scoreChangeFromPreviousMonth: Int,
    val dailyScores: List<Int>,
    val bestDay: DayHighlightUi?,
    val worstDay: DayHighlightUi?,
    val categoryBreakdown: List<CategoryMonthUi>,
    val topChangedMetrics: List<MetricChangeMonthUi>,
    val topInsights: List<String>,
)

data class DayHighlightUi(
    val date: String,
    val score: Int,
    val reason: String,
)

data class CategoryMonthUi(
    val name: String,
    val averageScore: Int,
    val trend: String,
    val dailyScores: List<Int>,
)

data class MetricChangeMonthUi(
    val name: String,
    val changePercent: String,
    val direction: String,
)

// ── Performance Profile Models ──────────────────────────────────────────────

data class PerformanceProfileUiState(
    val overallScore: Int,
    val personalRecords: List<PersonalRecordUi>,
    val totalWorkouts: Int,
    val avgWeeklyStrain: String,
    val recoveryDays: Int,
    val activeDaysPerWeek: Float,
    val performanceTrend: String,
)

data class PersonalRecordUi(
    val label: String,
    val value: String,
    val date: String,
    val emoji: String,
)
