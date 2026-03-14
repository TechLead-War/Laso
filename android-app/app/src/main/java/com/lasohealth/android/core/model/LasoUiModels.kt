package com.lasohealth.android.core.model

import androidx.compose.ui.graphics.Color
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
)

data class ActivityUi(
    val steps: Int,
    val activeCalories: Int,
    val exerciseMinutes: Int,
    val standHours: Int,
)

data class WorkoutUi(
    val title: String,
    val durationMinutes: Int,
    val strainLabel: String,
    val suggestion: String,
)

data class ExploreUiState(
    val overallScore: Int,
    val scoreChangeFromLastWeek: Int,
    val weakestCategory: HealthCategory,
    val metricsTracked: Int,
    val totalDataPoints: Int,
    val daysOfData: Int,
    val trendMetrics: List<TrendMetricUi>,
    val categoryScores: List<CategoryScoreUi>,
    val needsAttention: List<AttentionUi>,
    val correlations: List<CorrelationUi>,
)

data class TrendMetricUi(
    val metric: HealthMetric,
    val summary: String,
)

data class CategoryScoreUi(
    val category: HealthCategory,
    val score: Int,
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
    val contributions: List<MetricContributionUi>,
    val historicalComparison: String?,
)

data class MetricContributionUi(
    val name: String,
    val value: String,
    val impact: String,
)

data class StrainDetailUiState(
    val strainScore: Double,
    val strainLevel: String,
    val targetMin: Double,
    val targetMax: Double,
    val zoneMinutes: Int,
    val weeklyHistory: List<Float>,
    val balanceLabel: String,
    val guidance: String,
)

data class StressMonitorUiState(
    val stressScore: Int,
    val stressLevel: String,
    val hrvDeviation: String,
    val hrElevation: String,
    val weeklyScores: List<Int>,
    val weeklyAverage: Int,
    val previousWeekAverage: Int,
)

data class BrainHealthUiState(
    val score: Int,
    val grade: String,
    val stateLabel: String,
    val weeklyHistory: List<Int>,
    val contributingFactors: List<MetricContributionUi>,
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
