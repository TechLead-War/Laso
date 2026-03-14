package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Discovers cross-metric correlations from the user's daily time-series data
 * and generates human-readable insights about how health behaviours connect.
 *
 * Tests ~30 physiologically plausible metric pairs (not blind N^2), with automatic
 * lag discovery (0-1 day offsets) and effect-size validation.
 *
 * Ported from iOS CorrelationAnalyzer.swift.
 */
class CorrelationAnalyzer : InsightAnalyzer {

    override val name: String = "CorrelationAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val correlations = analyzeAll(context.timeSeries)
        return generateInsightsFromCorrelations(correlations)
    }

    // ----- Pair Registry -----

    private data class MetricPair(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val dayOffset: Int,
        val causeLabel: String,
        val effectLabel: String,
    )

    private val pairs = listOf(
        // Sleep -> Recovery (next-day)
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.RESTING_HEART_RATE, 1, "More sleep", "Lower resting HR next day"),
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.HEART_RATE_VARIABILITY, 1, "More sleep", "Higher HRV next day"),
        MetricPair(HealthMetric.SLEEP_DEEP, HealthMetric.HEART_RATE_VARIABILITY, 1, "More deep sleep", "Higher HRV next day"),
        MetricPair(HealthMetric.SLEEP_REM, HealthMetric.HEART_RATE_VARIABILITY, 1, "More REM sleep", "Higher HRV next day"),
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.BLOOD_OXYGEN, 1, "More sleep", "Better blood oxygen next day"),
        // Exercise -> Recovery
        MetricPair(HealthMetric.EXERCISE_MINUTES, HealthMetric.HEART_RATE_VARIABILITY, 1, "More exercise", "Higher HRV next day"),
        MetricPair(HealthMetric.ACTIVE_CALORIES, HealthMetric.RESTING_HEART_RATE, 1, "More active calories", "Lower resting HR next day"),
        MetricPair(HealthMetric.ACTIVE_CALORIES, HealthMetric.SLEEP_DEEP, 0, "More active calories", "More deep sleep"),
        MetricPair(HealthMetric.EXERCISE_MINUTES, HealthMetric.SLEEP_DURATION, 0, "More exercise", "Longer sleep"),
        MetricPair(HealthMetric.STEPS, HealthMetric.SLEEP_DURATION, 0, "More steps", "Longer sleep"),
        MetricPair(HealthMetric.VO2_MAX, HealthMetric.RESTING_HEART_RATE, 0, "Higher VO2 Max", "Lower resting HR"),
        // Activity -> Body
        MetricPair(HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES, 0, "More steps", "More calories burned"),
        MetricPair(HealthMetric.STAND_HOURS, HealthMetric.ACTIVE_CALORIES, 0, "More stand hours", "More calories burned"),
        // Heart / Stress / Mindfulness
        MetricPair(HealthMetric.MINDFUL_MINUTES, HealthMetric.HEART_RATE_VARIABILITY, 0, "More mindfulness", "Higher HRV"),
        MetricPair(HealthMetric.MINDFUL_MINUTES, HealthMetric.RESTING_HEART_RATE, 0, "More mindfulness", "Lower resting HR"),
        MetricPair(HealthMetric.RESPIRATORY_RATE, HealthMetric.HEART_RATE_VARIABILITY, 0, "Lower respiratory rate", "Higher HRV"),
        // Sleep -> Activity (next-day)
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.STEPS, 1, "More sleep", "More steps next day"),
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.EXERCISE_MINUTES, 1, "More sleep", "More exercise next day"),
        MetricPair(HealthMetric.SLEEP_DEEP, HealthMetric.ACTIVE_CALORIES, 1, "More deep sleep", "More calories burned next day"),
        // Respiratory -> Sleep
        MetricPair(HealthMetric.RESPIRATORY_RATE, HealthMetric.SLEEP_DEEP, 0, "Lower respiratory rate", "More deep sleep"),
        MetricPair(HealthMetric.BLOOD_OXYGEN, HealthMetric.SLEEP_DEEP, 0, "Better blood oxygen", "More deep sleep"),
        // Additional cross-domain
        MetricPair(HealthMetric.SLEEP_DURATION, HealthMetric.RESTING_HEART_RATE, 0, "More sleep", "Lower resting HR"),
        MetricPair(HealthMetric.EXERCISE_MINUTES, HealthMetric.SLEEP_DEEP, 0, "More exercise", "More deep sleep"),
        MetricPair(HealthMetric.STEPS, HealthMetric.HEART_RATE_VARIABILITY, 0, "More steps", "Higher HRV"),
        MetricPair(HealthMetric.ACTIVE_CALORIES, HealthMetric.HEART_RATE_VARIABILITY, 1, "More active calories", "Higher HRV next day"),
        MetricPair(HealthMetric.VO2_MAX, HealthMetric.HEART_RATE_VARIABILITY, 0, "Higher VO2 Max", "Higher HRV"),
        MetricPair(HealthMetric.EXERCISE_MINUTES, HealthMetric.RESTING_HEART_RATE, 1, "More exercise", "Lower resting HR next day"),
    )

    // ----- Analysis -----

    private data class CorrelationResult(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val r: Double,
        val sampleCount: Int,
        val causeLabel: String,
        val effectLabel: String,
        val avgBAbove: Double,
        val avgBBelow: Double,
        val effectPercentDiff: Double,
        val dayOffset: Int,
    )

    private fun analyzeAll(timeSeries: Map<HealthMetric, List<DailySample>>): List<CorrelationResult> {
        val results = mutableListOf<CorrelationResult>()

        for (pair in pairs) {
            val samplesA = timeSeries[pair.metricA] ?: continue
            val samplesB = timeSeries[pair.metricB] ?: continue

            val lagsToTest = setOf(pair.dayOffset, 0, 1)
            var bestResult: Triple<Double, Int, List<Pair<Double, Double>>>? = null

            for (lag in lagsToTest) {
                val aligned = alignSamples(samplesA, samplesB, lag)
                if (aligned.size < 14) continue

                val r = pearsonCorrelation(aligned) ?: continue
                if (abs(r) < 0.2) continue

                // T-test significance
                val n = aligned.size.toDouble()
                val rSquared = r * r
                if (rSquared >= 1.0) continue
                val t = abs(r) * sqrt((n - 2) / (1 - rSquared))
                if (t < 2.0) continue

                if (bestResult == null || abs(r) > abs(bestResult.first)) {
                    bestResult = Triple(r, lag, aligned)
                }
            }

            val (bestR, bestLag, aligned) = bestResult ?: continue

            // Effect size: require >= 8% difference between above/below baseline groups
            val effect = computeConditionalEffect(aligned)
            if (effect.percentDiff < 8.0) continue

            results += CorrelationResult(
                metricA = pair.metricA,
                metricB = pair.metricB,
                r = bestR,
                sampleCount = aligned.size,
                causeLabel = pair.causeLabel,
                effectLabel = pair.effectLabel,
                avgBAbove = effect.avgBAbove,
                avgBBelow = effect.avgBBelow,
                effectPercentDiff = effect.percentDiff,
                dayOffset = bestLag,
            )
        }

        return results.sortedByDescending { abs(it.r) }
    }

    private fun generateInsightsFromCorrelations(correlations: List<CorrelationResult>): List<AnalysisInsight> {
        return correlations.take(3).map { result ->
            val diffPct = fmt0(result.effectPercentDiff)
            val direction = if (result.r > 0) "higher" else "lower"
            val strength = strengthLabel(abs(result.r))

            val detail = "When your ${result.metricA.displayName.lowercase()} is above average, " +
                "your ${result.metricB.displayName.lowercase()} averages ${fmt1(result.avgBAbove)} " +
                "vs ${fmt1(result.avgBBelow)} ${result.metricB.unit} ($diffPct% $direction). " +
                "Based on ${result.sampleCount} days of data ($strength correlation, r=${String.format("%.2f", result.r)})."

            AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${result.causeLabel} \u2192 ${result.effectLabel}",
                detail = detail,
                metric = result.metricA,
                priority = if (abs(result.r) >= 0.5) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
                directive = InsightDirective.INFORMATIONAL,
                confidence = minOf(result.sampleCount / 90.0, 1.0),
            )
        }
    }

    // ----- Alignment -----

    private fun alignSamples(
        samplesA: List<DailySample>,
        samplesB: List<DailySample>,
        dayOffset: Int,
    ): List<Pair<Double, Double>> {
        val mapA = buildDayMap(samplesA)
        val mapB = buildDayMap(samplesB)
        val aligned = mutableListOf<Pair<Double, Double>>()
        for ((day, valueA) in mapA) {
            val targetDay = day + dayOffset.toLong() * DAY_MS
            val valueB = mapB[targetDay] ?: continue
            aligned += valueA to valueB
        }
        return aligned
    }

    private fun buildDayMap(samples: List<DailySample>): Map<Long, Double> {
        val map = mutableMapOf<Long, Double>()
        for (s in samples) {
            map[startOfDay(s.date)] = s.value
        }
        return map
    }

    // ----- Statistics -----

    private fun pearsonCorrelation(aligned: List<Pair<Double, Double>>): Double? {
        val n = aligned.size
        if (n < 5) return null

        val meanA = aligned.map { it.first }.average()
        val meanB = aligned.map { it.second }.average()

        var numerator = 0.0; var denomA = 0.0; var denomB = 0.0
        for ((a, b) in aligned) {
            val dA = a - meanA; val dB = b - meanB
            numerator += dA * dB; denomA += dA * dA; denomB += dB * dB
        }
        if (denomA <= 0 || denomB <= 0) return null
        return numerator / (sqrt(denomA) * sqrt(denomB))
    }

    private data class EffectResult(val percentDiff: Double, val avgBAbove: Double, val avgBBelow: Double)

    private fun computeConditionalEffect(aligned: List<Pair<Double, Double>>): EffectResult {
        if (aligned.isEmpty()) return EffectResult(0.0, 0.0, 0.0)
        val baselineA = aligned.map { it.first }.average()

        var aboveSum = 0.0; var aboveCount = 0
        var belowSum = 0.0; var belowCount = 0

        for ((a, b) in aligned) {
            if (a >= baselineA) { aboveSum += b; aboveCount++ }
            else { belowSum += b; belowCount++ }
        }

        if (aboveCount == 0 || belowCount == 0) return EffectResult(0.0, 0.0, 0.0)
        val avgAbove = aboveSum / aboveCount
        val avgBelow = belowSum / belowCount
        if (avgBelow == 0.0) return EffectResult(0.0, avgAbove, 0.0)

        val pctDiff = abs((avgAbove - avgBelow) / abs(avgBelow)) * 100.0
        return EffectResult(pctDiff, avgAbove, avgBelow)
    }

    private fun strengthLabel(absR: Double): String = when {
        absR >= 0.6 -> "strong"
        absR >= 0.4 -> "moderate"
        else -> "mild"
    }

    // ----- Helpers -----

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun fmt0(v: Double): String = String.format("%.0f", v)
    private fun fmt1(v: Double): String = String.format("%.1f", v)

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
