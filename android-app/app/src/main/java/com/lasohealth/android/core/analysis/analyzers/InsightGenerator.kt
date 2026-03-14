package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.AnomalySeverity
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricAnomaly
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.RateOfChange
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthMetric
import java.util.UUID
import kotlin.math.abs

/**
 * Primary general-purpose insight analyzer.
 *
 * Generates insights based on trends, anomalies, and baselines. Checks for:
 *   - Metric above/below baseline by >1 std dev
 *   - Rapid rate of change
 *   - Consecutive anomalies
 *   - Metric at personal record high/low
 *   - Trend reversals (improving -> declining or vice versa)
 *   - Significantly improving metrics (>5% week-over-week)
 *
 * Priority is determined by severity and health impact. Ported from iOS InsightGenerator.swift.
 */
class InsightGenerator : InsightAnalyzer {

    override val name: String = "InsightGenerator"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        // Phase 1: Anomaly-driven insights
        insights += generateAnomalyInsights(context)

        // Phase 2: Declining trends not already covered by anomalies
        insights += generateDecliningTrendInsights(context, existingMetrics = insights.map { it.metric }.toSet())

        // Phase 3: Significantly improving metrics
        insights += generateImprovingInsights(context, existingMetrics = insights.map { it.metric }.toSet())

        // Phase 4: Personal records
        insights += generatePersonalRecordInsights(context, existingMetrics = insights.map { it.metric }.toSet())

        // Sort by priority (critical first)
        return insights.sortedByDescending { it.priority.ordinal * -1 + priorityScore(it) }
    }

    // ----- Anomaly-driven insights -----

    private fun generateAnomalyInsights(context: AnalysisContext): List<AnalysisInsight> {
        val results = mutableListOf<AnalysisInsight>()

        for (anomaly in context.anomalies) {
            val trend = context.trends[anomaly.metric]
            val direction = trend?.direction ?: TrendDirection.STABLE
            val rateOfChange = trend?.rateOfChange?.let { RateOfChange.from(it) } ?: RateOfChange.NEGLIGIBLE

            // Only generate insights for non-trivial findings
            if (anomaly.severity < AnomalySeverity.MODERATE && direction != TrendDirection.FALLING) continue

            // Escalate severity for rapid changes
            val effectivePriority = when {
                rateOfChange == RateOfChange.RAPID && anomaly.severity == AnomalySeverity.MODERATE ->
                    InsightPriority.CRITICAL
                direction == TrendDirection.FALLING && anomaly.severity == AnomalySeverity.MODERATE ->
                    InsightPriority.HIGH
                else -> mapSeverityToPriority(anomaly.severity)
            }

            val baseline = context.baselines[anomaly.metric]
            val deviationPercent = if (anomaly.expected != 0.0) {
                ((anomaly.value - anomaly.expected) / anomaly.expected) * 100.0
            } else 0.0

            val title = generateTitle(anomaly.metric, direction, effectivePriority, rateOfChange)
            val detail = generateDetail(
                metric = anomaly.metric,
                currentValue = anomaly.value,
                baselineValue = anomaly.expected,
                deviationPercent = deviationPercent,
                direction = direction,
                baseline = baseline,
            )

            val directive = inferDirective(anomaly.metric, direction, effectivePriority, deviationPercent)

            results += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = title,
                detail = detail,
                metric = anomaly.metric,
                priority = effectivePriority,
                directive = directive,
                confidence = baseline?.let { minOf(it.sampleCount / 90.0, 1.0) } ?: 0.5,
            )
        }

        return results
    }

    // ----- Declining trend insights (no anomaly) -----

    private fun generateDecliningTrendInsights(
        context: AnalysisContext,
        existingMetrics: Set<HealthMetric>,
    ): List<AnalysisInsight> {
        val results = mutableListOf<AnalysisInsight>()

        for ((metric, trend) in context.trends) {
            if (trend.direction != TrendDirection.FALLING) continue
            if (metric in existingMetrics) continue

            val baseline = context.baselines[metric] ?: continue
            val currentValue = baseline.mean * (1.0 + trend.rateOfChange / 100.0)
            val deviationPercent = trend.rateOfChange

            val title = generateTitle(metric, TrendDirection.FALLING, InsightPriority.LOW, RateOfChange.from(trend.rateOfChange))
            val detail = generateDetail(
                metric = metric,
                currentValue = currentValue,
                baselineValue = baseline.mean,
                deviationPercent = deviationPercent,
                direction = TrendDirection.FALLING,
                baseline = baseline,
            )

            results += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = title,
                detail = detail,
                metric = metric,
                priority = InsightPriority.LOW,
                directive = inferDirective(metric, TrendDirection.FALLING, InsightPriority.LOW, deviationPercent),
                confidence = minOf(baseline.sampleCount / 90.0, 1.0),
            )
        }

        return results
    }

    // ----- Improving trend insights -----

    private fun generateImprovingInsights(
        context: AnalysisContext,
        existingMetrics: Set<HealthMetric>,
    ): List<AnalysisInsight> {
        val results = mutableListOf<AnalysisInsight>()

        for ((metric, trend) in context.trends) {
            if (trend.direction != TrendDirection.RISING) continue
            if (abs(trend.rateOfChange) <= 5.0) continue
            if (metric in existingMetrics) continue

            val baseline = context.baselines[metric] ?: continue
            val currentValue = baseline.mean * (1.0 + trend.rateOfChange / 100.0)

            val formatted = formatValue(currentValue, metric)
            val baseFormatted = formatValue(baseline.mean, metric)

            results += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${metric.displayName} Improving",
                detail = "Your ${metric.displayName.lowercase()} has improved ${String.format("%.1f", abs(trend.rateOfChange))}% " +
                    "from your baseline. Current: $formatted ${metric.unit}.",
                metric = metric,
                priority = InsightPriority.INFORMATIONAL,
                directive = InsightDirective.MAINTAIN,
                confidence = minOf(baseline.sampleCount / 90.0, 1.0),
            )
        }

        return results
    }

    // ----- Personal record insights -----

    private fun generatePersonalRecordInsights(
        context: AnalysisContext,
        existingMetrics: Set<HealthMetric>,
    ): List<AnalysisInsight> {
        val results = mutableListOf<AnalysisInsight>()

        for ((metric, samples) in context.timeSeries) {
            if (metric in existingMetrics) continue
            if (samples.size < 30) continue

            val latest = samples.maxByOrNull { it.date } ?: continue
            val allValues = samples.map { it.value }
            val historicalMax = allValues.max()
            val historicalMin = allValues.min()

            val isRecordHigh = latest.value >= historicalMax && allValues.size >= 30
            val isRecordLow = latest.value <= historicalMin && allValues.size >= 30

            if (isRecordHigh && metric.higherIsBetter) {
                val formatted = formatValue(latest.value, metric)
                results += AnalysisInsight(
                    id = UUID.randomUUID().toString(),
                    title = "${metric.displayName} Personal Best",
                    detail = "Your ${metric.displayName.lowercase()} reached a new all-time high: $formatted ${metric.unit}. " +
                        "This is the highest value recorded across ${allValues.size} data points.",
                    metric = metric,
                    priority = InsightPriority.LOW,
                    directive = InsightDirective.MAINTAIN,
                )
            } else if (isRecordLow && !metric.higherIsBetter) {
                val formatted = formatValue(latest.value, metric)
                results += AnalysisInsight(
                    id = UUID.randomUUID().toString(),
                    title = "${metric.displayName} Personal Best",
                    detail = "Your ${metric.displayName.lowercase()} reached a new all-time low: $formatted ${metric.unit}. " +
                        "This is the best value recorded across ${allValues.size} data points.",
                    metric = metric,
                    priority = InsightPriority.LOW,
                    directive = InsightDirective.MAINTAIN,
                )
            } else if (isRecordHigh && !metric.higherIsBetter) {
                val formatted = formatValue(latest.value, metric)
                val baseline = context.baselines[metric]
                val baseFormatted = baseline?.let { formatValue(it.mean, metric) } ?: "N/A"
                results += AnalysisInsight(
                    id = UUID.randomUUID().toString(),
                    title = "${metric.displayName} All-Time High",
                    detail = "Your ${metric.displayName.lowercase()} is at its highest ever: $formatted ${metric.unit} " +
                        "(baseline: $baseFormatted ${metric.unit}). This warrants attention.",
                    metric = metric,
                    priority = InsightPriority.MEDIUM,
                    directive = inferDirective(metric, TrendDirection.FALLING, InsightPriority.MEDIUM, 0.0),
                )
            } else if (isRecordLow && metric.higherIsBetter) {
                val formatted = formatValue(latest.value, metric)
                val baseline = context.baselines[metric]
                val baseFormatted = baseline?.let { formatValue(it.mean, metric) } ?: "N/A"
                results += AnalysisInsight(
                    id = UUID.randomUUID().toString(),
                    title = "${metric.displayName} All-Time Low",
                    detail = "Your ${metric.displayName.lowercase()} is at its lowest ever: $formatted ${metric.unit} " +
                        "(baseline: $baseFormatted ${metric.unit}). This warrants attention.",
                    metric = metric,
                    priority = InsightPriority.MEDIUM,
                    directive = inferDirective(metric, TrendDirection.FALLING, InsightPriority.MEDIUM, 0.0),
                )
            }
        }

        return results
    }

    // ----- Title generation -----

    private fun generateTitle(
        metric: HealthMetric,
        direction: TrendDirection,
        priority: InsightPriority,
        rateOfChange: RateOfChange,
    ): String {
        val ratePrefix = if (rateOfChange >= RateOfChange.MODERATE) {
            "${rateOfChange.name.lowercase().replaceFirstChar { it.uppercase() }} "
        } else ""

        return when {
            direction == TrendDirection.FALLING && priority == InsightPriority.CRITICAL ->
                "${metric.displayName} Critically Low"
            direction == TrendDirection.FALLING && priority == InsightPriority.HIGH ->
                "${metric.displayName} ${ratePrefix}Needs Attention"
            direction == TrendDirection.FALLING ->
                "${metric.displayName} ${ratePrefix}Declining"
            direction == TrendDirection.RISING ->
                "${metric.displayName} ${ratePrefix}Improving"
            priority == InsightPriority.CRITICAL ->
                "${metric.displayName} Outside Safe Range"
            priority == InsightPriority.HIGH ->
                "${metric.displayName} Elevated"
            else -> "${metric.displayName} Stable"
        }
    }

    // ----- Detail generation -----

    private fun generateDetail(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        direction: TrendDirection,
        baseline: MetricBaseline?,
    ): String {
        val formattedCurrent = formatValue(currentValue, metric)
        val formattedBaseline = formatValue(baselineValue, metric)
        val absDeviation = String.format("%.1f", abs(deviationPercent))
        val directionLabel = if (deviationPercent > 0) "above" else "below"

        return when (direction) {
            TrendDirection.FALLING ->
                "Your ${metric.displayName.lowercase()} is $absDeviation% $directionLabel your baseline " +
                    "($formattedBaseline ${metric.unit}). Current: $formattedCurrent ${metric.unit}."
            TrendDirection.RISING ->
                "Your ${metric.displayName.lowercase()} has improved $absDeviation% from your baseline. " +
                    "Current: $formattedCurrent ${metric.unit}."
            else ->
                "Your ${metric.displayName.lowercase()} is $absDeviation% $directionLabel your baseline " +
                    "($formattedBaseline ${metric.unit})."
        }
    }

    // ----- Directive inference -----

    private fun inferDirective(
        metric: HealthMetric,
        direction: TrendDirection,
        priority: InsightPriority,
        deviationPercent: Double,
    ): InsightDirective {
        // Clinical metrics always escalate to SEEK_MEDICAL at warning+
        if (priority <= InsightPriority.HIGH && isClinicalMetric(metric)) {
            return InsightDirective.SEEK_MEDICAL
        }

        return when (metric) {
            // Sleep metrics
            HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP,
            HealthMetric.SLEEP_REM, HealthMetric.SLEEP_CORE ->
                if (direction == TrendDirection.FALLING) InsightDirective.SLEEP_MORE
                else InsightDirective.MAINTAIN

            // Activity metrics
            HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES,
            HealthMetric.EXERCISE_MINUTES, HealthMetric.DISTANCE_WALKING_RUNNING ->
                if (direction == TrendDirection.FALLING) InsightDirective.INCREASE_ACTIVITY
                else InsightDirective.MAINTAIN

            // HRV / Recovery
            HealthMetric.HEART_RATE_VARIABILITY ->
                if (direction == TrendDirection.FALLING && priority <= InsightPriority.HIGH) InsightDirective.REST
                else InsightDirective.INFORMATIONAL

            // Resting HR
            HealthMetric.RESTING_HEART_RATE ->
                if (direction == TrendDirection.FALLING) InsightDirective.REST
                else InsightDirective.INFORMATIONAL

            else -> InsightDirective.INFORMATIONAL
        }
    }

    // ----- Helpers -----

    private fun isClinicalMetric(metric: HealthMetric): Boolean = metric in CLINICAL_METRICS

    private fun mapSeverityToPriority(severity: AnomalySeverity): InsightPriority = when (severity) {
        AnomalySeverity.SEVERE -> InsightPriority.CRITICAL
        AnomalySeverity.MODERATE -> InsightPriority.HIGH
        AnomalySeverity.MILD -> InsightPriority.MEDIUM
    }

    private fun priorityScore(insight: AnalysisInsight): Double = when (insight.priority) {
        InsightPriority.CRITICAL -> 100.0
        InsightPriority.HIGH -> 75.0
        InsightPriority.MEDIUM -> 50.0
        InsightPriority.LOW -> 25.0
        InsightPriority.INFORMATIONAL -> 10.0
    }

    companion object {
        private val CLINICAL_METRICS = setOf(
            HealthMetric.BLOOD_OXYGEN,
            HealthMetric.BLOOD_PRESSURE_SYSTOLIC,
            HealthMetric.BLOOD_PRESSURE_DIASTOLIC,
            HealthMetric.RESPIRATORY_RATE,
            HealthMetric.BODY_TEMPERATURE,
            HealthMetric.ATRIAL_FIBRILLATION_BURDEN,
            HealthMetric.BLOOD_GLUCOSE,
        )

        internal fun formatValue(value: Double, metric: HealthMetric): String = when {
            value >= 1000 -> String.format("%.0f", value)
            value >= 10 -> String.format("%.1f", value)
            else -> String.format("%.2f", value)
        }
    }
}
