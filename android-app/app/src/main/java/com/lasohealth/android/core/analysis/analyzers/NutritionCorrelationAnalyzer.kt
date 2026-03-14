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
 * Time-aware correlation engine for nutrition -> health outcome pairs.
 * Tests ~16 curated physiologically plausible pairs (not blind N^2 search).
 *
 * Ported from iOS NutritionCorrelationAnalyzer.swift.
 */
class NutritionCorrelationAnalyzer : InsightAnalyzer {

    override val name: String = "NutritionCorrelationAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val correlations = analyze(context.timeSeries)
        return generateInsightsFromCorrelations(correlations)
    }

    // ----- Curated Pairs -----

    private data class CuratedPair(
        val nutrition: HealthMetric,
        val outcome: HealthMetric,
        val dayOffset: Int,
    )

    private val curatedPairs = listOf(
        // Caffeine -> sleep
        CuratedPair(HealthMetric.CAFFEINE_INTAKE, HealthMetric.SLEEP_DURATION, 0),
        CuratedPair(HealthMetric.CAFFEINE_INTAKE, HealthMetric.SLEEP_DEEP, 0),
        CuratedPair(HealthMetric.CAFFEINE_INTAKE, HealthMetric.SLEEP_REM, 0),
        CuratedPair(HealthMetric.CAFFEINE_INTAKE, HealthMetric.RESTING_HEART_RATE, 0),
        CuratedPair(HealthMetric.CAFFEINE_INTAKE, HealthMetric.HEART_RATE_VARIABILITY, 1),
        // Hydration -> outcomes
        CuratedPair(HealthMetric.WATER_INTAKE, HealthMetric.HEART_RATE_VARIABILITY, 1),
        CuratedPair(HealthMetric.WATER_INTAKE, HealthMetric.RESTING_HEART_RATE, 1),
        // Protein -> recovery
        CuratedPair(HealthMetric.PROTEIN_INTAKE, HealthMetric.HEART_RATE_VARIABILITY, 1),
        // Sugar -> sleep
        CuratedPair(HealthMetric.SUGAR_INTAKE, HealthMetric.SLEEP_DEEP, 0),
        CuratedPair(HealthMetric.SUGAR_INTAKE, HealthMetric.HEART_RATE_VARIABILITY, 1),
        // Sodium -> BP
        CuratedPair(HealthMetric.SODIUM_INTAKE, HealthMetric.BLOOD_PRESSURE_SYSTOLIC, 1),
        // Fiber -> glucose stability
        CuratedPair(HealthMetric.FIBER_INTAKE, HealthMetric.BLOOD_GLUCOSE, 0),
        // Total calories -> activity
        CuratedPair(HealthMetric.TOTAL_CALORIES_INTAKE, HealthMetric.ACTIVE_CALORIES, 1),
        // Fat -> sleep
        CuratedPair(HealthMetric.FAT_INTAKE, HealthMetric.SLEEP_DEEP, 0),
        // Carbs -> activity
        CuratedPair(HealthMetric.CARBOHYDRATE_INTAKE, HealthMetric.EXERCISE_MINUTES, 1),
    )

    // ----- Analysis -----

    private data class NutritionCorrelation(
        val nutritionMetric: HealthMetric,
        val outcomeMetric: HealthMetric,
        val correlation: Double,
        val thresholdValue: Double?,
        val thresholdImpact: Double?,
        val sampleCount: Int,
        val insightText: String,
    )

    private fun analyze(timeSeries: Map<HealthMetric, List<DailySample>>): List<NutritionCorrelation> {
        val results = mutableListOf<NutritionCorrelation>()

        for (pair in curatedPairs) {
            val nutritionSamples = timeSeries[pair.nutrition] ?: continue
            val outcomeSamples = timeSeries[pair.outcome] ?: continue
            if (nutritionSamples.size < 14 || outcomeSamples.size < 14) continue

            val nutritionByDate = buildDateLookup(nutritionSamples)
            val outcomeByDate = buildDateLookup(outcomeSamples)

            val nutritionValues = mutableListOf<Double>()
            val outcomeValues = mutableListOf<Double>()

            for ((date, nv) in nutritionByDate) {
                val targetDate = date + pair.dayOffset.toLong() * DAY_MS
                val ov = outcomeByDate[targetDate] ?: continue
                nutritionValues += nv
                outcomeValues += ov
            }

            if (nutritionValues.size < 10) continue

            val r = pearsonCorrelation(nutritionValues, outcomeValues) ?: continue
            if (abs(r) < 0.15) continue

            val threshold = detectThreshold(nutritionValues, outcomeValues)
            val insightText = generateInsightText(pair, r, threshold, nutritionValues.size)

            results += NutritionCorrelation(
                nutritionMetric = pair.nutrition,
                outcomeMetric = pair.outcome,
                correlation = r,
                thresholdValue = threshold?.first,
                thresholdImpact = threshold?.second,
                sampleCount = nutritionValues.size,
                insightText = insightText,
            )
        }

        return results.sortedByDescending { abs(it.correlation) }
    }

    private fun generateInsightsFromCorrelations(correlations: List<NutritionCorrelation>): List<AnalysisInsight> {
        return correlations.take(5).map { corr ->
            AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${corr.nutritionMetric.displayName} Affects ${corr.outcomeMetric.displayName}",
                detail = corr.insightText,
                metric = corr.nutritionMetric,
                priority = if (abs(corr.correlation) > 0.4) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
                directive = InsightDirective.INFORMATIONAL,
                confidence = minOf(corr.sampleCount / 60.0, 1.0),
            )
        }
    }

    // ----- Threshold Detection -----

    private fun detectThreshold(
        nutritionValues: List<Double>,
        outcomeValues: List<Double>,
    ): Pair<Double, Double>? {
        val sorted = nutritionValues.zip(outcomeValues).sortedBy { it.first }
        val n = sorted.size
        if (n < 20) return null

        val q3Start = n * 3 / 4
        val bottomHalf = sorted.take(n / 2).map { it.second }
        val topQuartile = sorted.drop(q3Start).map { it.second }

        if (bottomHalf.isEmpty() || topQuartile.isEmpty()) return null

        val bottomAvg = bottomHalf.average()
        val topAvg = topQuartile.average()
        if (bottomAvg == 0.0) return null

        val impact = ((topAvg - bottomAvg) / abs(bottomAvg)) * 100.0
        if (abs(impact) < 5.0) return null

        val thresholdValue = sorted[q3Start].first
        return thresholdValue to impact
    }

    // ----- Text Generation -----

    private fun generateInsightText(
        pair: CuratedPair,
        correlation: Double,
        threshold: Pair<Double, Double>?,
        sampleCount: Int,
    ): String {
        val direction = if (correlation > 0) "increases" else "decreases"
        val strength = when {
            abs(correlation) > 0.5 -> "strongly"
            abs(correlation) > 0.3 -> "moderately"
            else -> "slightly"
        }

        var text = "Your ${pair.nutrition.displayName} $strength $direction ${pair.outcome.displayName}"
        if (pair.dayOffset > 0) text += " the next day"
        text += " (r=${String.format("%.2f", correlation)}, n=$sampleCount)."

        threshold?.let { (value, impact) ->
            text += " Impact becomes more pronounced above ${String.format("%.0f", value)} ${pair.nutrition.unit} " +
                "(${String.format("%.0f", abs(impact))}% change)."
        }

        return text
    }

    // ----- Helpers -----

    private fun buildDateLookup(samples: List<DailySample>): Map<Long, Double> {
        val map = mutableMapOf<Long, Double>()
        for (s in samples) map[startOfDay(s.date)] = s.value
        return map
    }

    private fun pearsonCorrelation(x: List<Double>, y: List<Double>): Double? {
        val n = x.size.toDouble()
        if (n <= 2) return null
        val sumX = x.sum(); val sumY = y.sum()
        val sumXY = x.zip(y).sumOf { it.first * it.second }
        val sumX2 = x.sumOf { it * it }; val sumY2 = y.sumOf { it * it }

        val num = n * sumXY - sumX * sumY
        val den = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        return if (den > 0) num / den else null
    }

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
