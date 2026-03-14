package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric

/**
 * A single daily-aggregated sample for a health metric.
 *
 * @property date epoch milliseconds (start of day, UTC).
 */
data class DailySample(
    val metric: HealthMetric,
    val date: Long,
    val value: Double,
)

/**
 * Statistical baseline for a metric, computed from recent history.
 */
data class MetricBaseline(
    val metric: HealthMetric,
    val mean: Double,
    val standardDeviation: Double,
    val sampleCount: Int,
    val lastUpdated: Long,
)

/**
 * Direction a metric is trending over a given period.
 */
enum class TrendDirection {
    RISING,
    FALLING,
    STABLE,
    INSUFFICIENT_DATA,
}

/**
 * Magnitude classification for rate of change.
 *
 * Thresholds are expressed in standard-deviations-per-day of the metric's baseline.
 */
enum class RateOfChange {
    NEGLIGIBLE,
    GRADUAL,
    MODERATE,
    RAPID;

    companion object {
        /** Threshold (in baseline standard deviations per day) below which change is negligible. */
        const val NEGLIGIBLE_THRESHOLD = 0.02
        /** Threshold below which change is gradual. */
        const val GRADUAL_THRESHOLD = 0.05
        /** Threshold below which change is moderate; above this is rapid. */
        const val MODERATE_THRESHOLD = 0.10

        /**
         * Classify a normalised slope (standard deviations per day) into a [RateOfChange] bucket.
         */
        fun from(normalizedSlope: Double): RateOfChange {
            val abs = kotlin.math.abs(normalizedSlope)
            return when {
                abs < NEGLIGIBLE_THRESHOLD -> NEGLIGIBLE
                abs < GRADUAL_THRESHOLD -> GRADUAL
                abs < MODERATE_THRESHOLD -> MODERATE
                else -> RAPID
            }
        }
    }
}

/**
 * Trend analysis result for a single metric.
 */
data class MetricTrend(
    val metric: HealthMetric,
    val direction: TrendDirection,
    val rateOfChange: Double,
    val confidence: Double,
    val periodDays: Int,
)

/**
 * Severity classification for an anomalous reading.
 */
enum class AnomalySeverity {
    MILD,
    MODERATE,
    SEVERE,
}

/**
 * A data point that deviates significantly from the metric's baseline.
 */
data class MetricAnomaly(
    val metric: HealthMetric,
    val value: Double,
    val expected: Double,
    val zScore: Double,
    val severity: AnomalySeverity,
    val timestamp: Long,
)

/**
 * Composite health score: overall (0-100), per-category, and per-metric contributions.
 */
data class HealthScore(
    val overall: Int,
    val categoryScores: Map<HealthCategory, Int>,
    val contributions: Map<HealthMetric, Double>,
)

/**
 * Shared data bag passed to all insight analyzers.
 *
 * Contains everything the analysis pipeline has computed up to the insight generation phase.
 */
data class AnalysisContext(
    val timeSeries: Map<HealthMetric, List<DailySample>>,
    val baselines: Map<HealthMetric, MetricBaseline>,
    val trends: Map<HealthMetric, MetricTrend>,
    val anomalies: List<MetricAnomaly>,
    val dayCount: Int,
)
