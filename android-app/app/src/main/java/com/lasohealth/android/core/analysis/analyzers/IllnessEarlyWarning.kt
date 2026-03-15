package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Detects early signs of illness by monitoring sustained multi-day deviations
 * across key physiological metrics simultaneously.
 *
 * Inspired by Stanford's COVID detection study (81% detection rate, 2.75 days
 * pre-symptomatic) and Oura's Symptom Radar.
 *
 * Core insight: single-metric deviations are noisy. When resting heart rate, HRV,
 * sleep, activity, and respiratory rate all shift unfavorably at the same time for
 * multiple consecutive days, the probability of illness onset is significantly higher.
 *
 * Requires at least 2 of the 5 monitored signals deviating simultaneously for 2+
 * consecutive days to trigger. Uses exercise recovery guard to avoid false positives
 * after intense workouts.
 *
 * Ported from iOS IllnessEarlyWarning.swift.
 */
class IllnessEarlyWarning : InsightAnalyzer {

    override val name: String = "IllnessEarlyWarning"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val calendar = Calendar.getInstance()
        val now = System.currentTimeMillis()

        // If the user had intense workouts during the signal window, skip detection
        if (isExerciseRecoveryLikely(context.timeSeries, context.baselines, now)) {
            return emptyList()
        }

        // Step 1: Compute per-day signals for each metric over the recent window
        val dailySignals = computeDailySignals(context.timeSeries, now)

        // Step 2: For each day, determine which metrics are signaling
        val consecutiveResult = computeConsecutiveMultiMetricDays(dailySignals)

        if (consecutiveResult.daysElevated < 2 || consecutiveResult.signalingMetrics.size < 2) {
            return emptyList()
        }

        // Step 3: Build MetricSignal objects for all signaling metrics
        val activeSignals = buildActiveSignals(
            signalingMetrics = consecutiveResult.signalingMetrics,
            timeSeries = context.timeSeries,
            now = now,
        )

        // Step 4: Apply sleep-duration special rule - only count it if other signals present
        val nonSleepSignals = activeSignals.filter { it.metric != HealthMetric.SLEEP_DURATION }
        val finalSignals = if (nonSleepSignals.size >= 2) activeSignals else nonSleepSignals
        if (finalSignals.size < 2) return emptyList()

        // Step 5: Determine severity and confidence
        val priority = determinePriority(finalSignals.size, consecutiveResult.daysElevated)
        val confidence = computeConfidence(finalSignals, consecutiveResult.daysElevated)

        // Step 6: Generate narrative and recommendation
        val narrative = generateNarrative(finalSignals, consecutiveResult.daysElevated)
        val recommendation = generateRecommendation(finalSignals, consecutiveResult.daysElevated, priority)
        val title = insightTitle(priority)

        val primaryMetric = finalSignals.firstOrNull()?.metric ?: HealthMetric.RESTING_HEART_RATE

        return listOf(
            AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = title,
                detail = "$narrative $recommendation",
                metric = primaryMetric,
                priority = priority,
                directive = InsightDirective.REST,
                confidence = confidence / 100.0,
            )
        )
    }

    // ----- Signal Configuration -----

    private enum class UnfavorableDirection { ABOVE, BELOW }

    private data class SignalConfig(
        val metric: HealthMetric,
        val unfavorableDirection: UnfavorableDirection,
        val isSleepDuration: Boolean,
    )

    private val signalMetrics = listOf(
        SignalConfig(HealthMetric.RESTING_HEART_RATE, UnfavorableDirection.ABOVE, false),
        SignalConfig(HealthMetric.HEART_RATE_VARIABILITY, UnfavorableDirection.BELOW, false),
        SignalConfig(HealthMetric.SLEEP_DURATION, UnfavorableDirection.ABOVE, true),
        SignalConfig(HealthMetric.STEPS, UnfavorableDirection.BELOW, false),
        SignalConfig(HealthMetric.RESPIRATORY_RATE, UnfavorableDirection.ABOVE, false),
    )

    // ----- Signal Types -----

    data class MetricSignal(
        val metric: HealthMetric,
        val currentValue: Double,
        val baselineValue: Double,
        val deviationSigma: Double,
        val direction: String,
    )

    private data class ConsecutiveResult(
        val daysElevated: Int,
        val signalingMetrics: Set<HealthMetric>,
    )

    // ----- Daily Signal Computation -----

    private fun computeDailySignals(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        now: Long,
    ): Map<HealthMetric, Map<Int, Double>> {
        val dailySignals = mutableMapOf<HealthMetric, Map<Int, Double>>()

        for (config in signalMetrics) {
            val samples = timeSeries[config.metric] ?: continue

            // Compute personal baseline from days (BASELINE_GAP_DAYS + 1) through
            // (BASELINE_GAP_DAYS + BASELINE_WINDOW_DAYS) ago
            val baselineStart = now - (BASELINE_GAP_DAYS + BASELINE_WINDOW_DAYS).toLong() * DAY_MS
            val baselineEnd = now - (BASELINE_GAP_DAYS + 1).toLong() * DAY_MS

            val baselineValues = samples
                .filter { it.date in baselineStart..baselineEnd }
                .map { it.value }

            if (baselineValues.size < MINIMUM_DATA_DAYS) continue

            val baselineMean = baselineValues.average()
            val baselineSD = standardDeviation(baselineValues, baselineMean)
            if (baselineSD <= 0.001) continue

            val metricDailySignals = mutableMapOf<Int, Double>()

            for (dayOffset in 0 until RECENT_WINDOW_DAYS) {
                val dayStart = startOfDay(now - dayOffset.toLong() * DAY_MS)
                val dayEnd = dayStart + DAY_MS

                val daySamples = samples.filter { it.date in dayStart until dayEnd }
                if (daySamples.isEmpty()) continue

                val dayMean = daySamples.map { it.value }.average()
                val deviation = (dayMean - baselineMean) / baselineSD

                val isUnfavorable = when (config.unfavorableDirection) {
                    UnfavorableDirection.ABOVE -> deviation >= SIGNAL_THRESHOLD_SIGMA
                    UnfavorableDirection.BELOW -> deviation <= -SIGNAL_THRESHOLD_SIGMA
                }

                if (isUnfavorable) {
                    metricDailySignals[dayOffset] = abs(deviation)
                }
            }

            if (metricDailySignals.isNotEmpty()) {
                dailySignals[config.metric] = metricDailySignals
            }
        }

        return dailySignals
    }

    // ----- Consecutive Day Analysis -----

    private fun computeConsecutiveMultiMetricDays(
        dailySignals: Map<HealthMetric, Map<Int, Double>>,
    ): ConsecutiveResult {
        var consecutiveDays = 0
        val allSignalingMetrics = mutableSetOf<HealthMetric>()

        for (dayOffset in 0 until RECENT_WINDOW_DAYS) {
            val metricsToday = dailySignals.entries
                .filter { it.value.containsKey(dayOffset) }
                .map { it.key }
                .toSet()

            if (metricsToday.size >= 2) {
                consecutiveDays++
                allSignalingMetrics += metricsToday
            } else {
                break // streak broken
            }
        }

        return ConsecutiveResult(consecutiveDays, allSignalingMetrics)
    }

    // ----- Active Signal Construction -----

    private fun buildActiveSignals(
        signalingMetrics: Set<HealthMetric>,
        timeSeries: Map<HealthMetric, List<DailySample>>,
        now: Long,
    ): List<MetricSignal> {
        val signals = mutableListOf<MetricSignal>()

        for (config in signalMetrics) {
            if (config.metric !in signalingMetrics) continue
            val samples = timeSeries[config.metric] ?: continue

            val baselineStart = now - (BASELINE_GAP_DAYS + BASELINE_WINDOW_DAYS).toLong() * DAY_MS
            val baselineEnd = now - (BASELINE_GAP_DAYS + 1).toLong() * DAY_MS

            val baselineValues = samples
                .filter { it.date in baselineStart..baselineEnd }
                .map { it.value }

            if (baselineValues.isEmpty()) continue

            val baselineMean = baselineValues.average()
            val baselineSD = standardDeviation(baselineValues, baselineMean)
            if (baselineSD <= 0.001) continue

            // Current value: average of the recent window
            val recentStart = now - RECENT_WINDOW_DAYS.toLong() * DAY_MS
            val recentValues = samples.filter { it.date >= recentStart }.map { it.value }
            if (recentValues.isEmpty()) continue

            val currentValue = recentValues.average()
            val deviation = (currentValue - baselineMean) / baselineSD

            val direction = when (config.unfavorableDirection) {
                UnfavorableDirection.ABOVE -> "elevated"
                UnfavorableDirection.BELOW -> "depressed"
            }

            signals += MetricSignal(
                metric = config.metric,
                currentValue = currentValue,
                baselineValue = baselineMean,
                deviationSigma = abs(deviation),
                direction = direction,
            )
        }

        return signals
    }

    // ----- Exercise Recovery Guard -----

    private fun isExerciseRecoveryLikely(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        now: Long,
    ): Boolean {
        val calSamples = timeSeries[HealthMetric.ACTIVE_CALORIES] ?: return false
        val calBaseline = baselines[HealthMetric.ACTIVE_CALORIES] ?: return false
        if (calBaseline.mean <= 0) return false

        val threshold = calBaseline.mean * EXERCISE_RECOVERY_MULTIPLIER

        for (dayOffset in 0 until RECENT_WINDOW_DAYS) {
            val dayStart = startOfDay(now - dayOffset.toLong() * DAY_MS)
            val dayEnd = dayStart + DAY_MS

            val dayTotal = calSamples
                .filter { it.date in dayStart until dayEnd }
                .sumOf { it.value }

            if (dayTotal > threshold) return true
        }

        return false
    }

    // ----- Priority / Severity -----

    private fun determinePriority(signalCount: Int, daysElevated: Int): InsightPriority = when {
        signalCount >= 3 && daysElevated >= 3 -> InsightPriority.CRITICAL
        signalCount >= 3 && daysElevated >= 2 -> InsightPriority.HIGH
        else -> InsightPriority.MEDIUM
    }

    // ----- Confidence Scoring -----

    private fun computeConfidence(signals: List<MetricSignal>, daysElevated: Int): Double {
        // Number of metrics scoring
        val metricScore = when (signals.size) {
            2 -> 20.0
            3 -> 30.0
            4 -> 40.0
            else -> minOf(signals.size * 9.0, 45.0)
        }

        // Consecutive days
        val daysScore = when (daysElevated) {
            2 -> 15.0
            3 -> 25.0
            else -> minOf(daysElevated * 10.0, 30.0)
        }

        // Average magnitude
        val avgSigma = signals.map { it.deviationSigma }.average()
        val magnitudeScore = minOf((avgSigma - SIGNAL_THRESHOLD_SIGMA) * 12.5, 25.0)

        val raw = metricScore + daysScore + maxOf(magnitudeScore, 0.0)
        return minOf(raw, 100.0)
    }

    // ----- Narrative Generation -----

    private fun generateNarrative(signals: List<MetricSignal>, daysElevated: Int): String {
        val daysLabel = if (daysElevated == 1) "day" else "days"
        val parts = signals.map { signal ->
            val metricName = signal.metric.displayName.lowercase()
            val formatted = InsightGenerator.formatValue(signal.currentValue, signal.metric)
            val baseFormatted = InsightGenerator.formatValue(signal.baselineValue, signal.metric)
            val unit = signal.metric.unit

            val devDescription = if (signal.baselineValue > 0.001) {
                val pctChange = abs((signal.currentValue - signal.baselineValue) / signal.baselineValue) * 100
                String.format("%.0f%%", pctChange)
            } else {
                String.format("%.1f\u03C3", signal.deviationSigma)
            }

            when (signal.direction) {
                "elevated" -> "$metricName has trended $devDescription above baseline for $daysElevated $daysLabel ($formatted vs $baseFormatted $unit)"
                "depressed" -> "$metricName dropped $devDescription below baseline over $daysElevated $daysLabel ($formatted vs $baseFormatted $unit)"
                else -> "$metricName deviated $devDescription from baseline"
            }
        }

        val signalSummary = when {
            parts.size == 1 -> "Your ${parts[0]}."
            parts.size == 2 -> "Your ${parts[0]}, while your ${parts[1]}."
            else -> {
                val allButLast = parts.dropLast(1).joinToString(", ") { "your $it" }
                "$allButLast, and your ${parts.last()}."
            }
        }

        return "$signalSummary When multiple metrics shift simultaneously over consecutive days, " +
            "it often reflects a systemic physiological response."
    }

    private fun generateRecommendation(
        signals: List<MetricSignal>,
        daysElevated: Int,
        priority: InsightPriority,
    ): String {
        val observations = mutableListOf<String>()

        if (priority <= InsightPriority.HIGH) {
            observations += "Your body is showing strain across ${signals.size} metrics over $daysElevated consecutive days."
        } else {
            observations += "Multiple metrics have shifted from your baseline at the same time."
        }

        observations += "This pattern is consistent with physiological strain."

        val hasCardiac = signals.any {
            it.metric == HealthMetric.RESTING_HEART_RATE || it.metric == HealthMetric.HEART_RATE_VARIABILITY
        }
        if (hasCardiac) {
            observations += "Your cardiac metrics are part of this pattern, suggesting autonomic nervous system involvement."
        }

        val hasActivityDecline = signals.any { it.metric == HealthMetric.STEPS }
        if (hasActivityDecline) {
            observations += "Your activity level has not returned to baseline."
        }

        if (priority == InsightPriority.CRITICAL) {
            observations += "This is a sustained multi-metric deviation \u2014 ${signals.size} signals active for $daysElevated consecutive days."
        }

        return observations.joinToString(" ")
    }

    private fun insightTitle(priority: InsightPriority): String = when (priority) {
        InsightPriority.CRITICAL -> "Significant Physiological Strain"
        InsightPriority.HIGH -> "Multiple Metric Strain Detected"
        else -> "Early Physiological Strain Signal"
    }

    // ----- Math Helpers -----

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun standardDeviation(values: List<Double>, mean: Double): Double {
        if (values.size < 2) return 0.0
        val variance = values.sumOf { (it - mean) * (it - mean) } / (values.size - 1)
        return sqrt(variance)
    }

    companion object {
        private const val DAY_MS = 86_400_000L
        private const val SIGNAL_THRESHOLD_SIGMA = 1.0
        private const val MINIMUM_DATA_DAYS = 14
        private const val RECENT_WINDOW_DAYS = 3
        private const val BASELINE_GAP_DAYS = 3
        private const val BASELINE_WINDOW_DAYS = 14
        private const val EXERCISE_RECOVERY_MULTIPLIER = 1.5
    }
}
