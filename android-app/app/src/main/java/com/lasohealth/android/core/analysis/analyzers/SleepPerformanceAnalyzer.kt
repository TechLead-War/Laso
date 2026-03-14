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
 * Analyzes sleep duration, quality, and consistency patterns.
 *
 * Checks:
 *   - Sleep duration impact on next-day activity (good sleep >= 7hr vs poor < 6hr)
 *   - Sleep quality impact (deep+REM ratio vs next-day active calories)
 *   - Sleep consistency (coefficient of variation, weekday vs weekend split)
 *
 * Ported from iOS SleepPerformanceAnalyzer.swift.
 */
class SleepPerformanceAnalyzer : InsightAnalyzer {

    override val name: String = "SleepPerformanceAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        val sleepSamples = context.timeSeries[HealthMetric.SLEEP_DURATION] ?: return emptyList()

        // Duration impact on next-day performance
        analyzeDurationImpact(sleepSamples, context)?.let { insights += it }

        // Sleep quality impact (deep+REM ratio)
        analyzeQualityImpact(context)?.let { insights += it }

        // Sleep consistency
        analyzeConsistency(sleepSamples)?.let { insights += it }

        return insights
    }

    // ----- Duration Impact -----

    private fun analyzeDurationImpact(
        sleepSamples: List<DailySample>,
        context: AnalysisContext,
    ): AnalysisInsight? {
        val performanceMetrics = listOf(
            HealthMetric.ACTIVE_CALORIES,
            HealthMetric.STEPS,
            HealthMetric.EXERCISE_MINUTES,
        )

        for (perfMetric in performanceMetrics) {
            val perfSamples = context.timeSeries[perfMetric] ?: continue

            // Align sleep with next-day performance (1-day offset)
            val aligned = alignWithOffset(sleepSamples, perfSamples, dayOffset = 1)
            if (aligned.size < 14) continue

            val goodSleep = aligned.filter { it.first >= 7.0 }
            val poorSleep = aligned.filter { it.first < 6.0 }

            if (goodSleep.size < 5 || poorSleep.size < 3) continue

            val avgGood = goodSleep.map { it.second }.average()
            val avgPoor = poorSleep.map { it.second }.average()
            if (avgPoor <= 0) continue

            val percentDiff = ((avgGood - avgPoor) / avgPoor) * 100.0
            if (abs(percentDiff) < 10) continue

            val priority = if (abs(percentDiff) >= 25) InsightPriority.HIGH else InsightPriority.LOW

            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Sleep Drives ${perfMetric.displayName}",
                detail = "Good sleep (7+ hrs) boosts your next-day ${perfMetric.displayName.lowercase()} by " +
                    "${String.format("%.0f", abs(percentDiff))}% \u2014 averaging ${String.format("%.0f", avgGood)} " +
                    "${perfMetric.unit} vs ${String.format("%.0f", avgPoor)} on shorter nights across " +
                    "${goodSleep.size + poorSleep.size} measured nights.",
                metric = HealthMetric.SLEEP_DURATION,
                priority = priority,
                directive = InsightDirective.SLEEP_MORE,
                confidence = minOf((goodSleep.size + poorSleep.size) / 30.0, 1.0),
            )
        }
        return null
    }

    // ----- Quality Impact -----

    private fun analyzeQualityImpact(context: AnalysisContext): AnalysisInsight? {
        val deepSamples = context.timeSeries[HealthMetric.SLEEP_DEEP] ?: return null
        val remSamples = context.timeSeries[HealthMetric.SLEEP_REM] ?: return null
        val totalSamples = context.timeSeries[HealthMetric.SLEEP_DURATION] ?: return null
        val calSamples = context.timeSeries[HealthMetric.ACTIVE_CALORIES] ?: return null

        val deepMap = deepSamples.associateBy { startOfDay(it.date) }
        val remMap = remSamples.associateBy { startOfDay(it.date) }
        val totalMap = totalSamples.associateBy { startOfDay(it.date) }
        val calMap = calSamples.associateBy { startOfDay(it.date) }

        val highQualityDays = mutableListOf<Long>()
        val lowQualityDays = mutableListOf<Long>()

        for ((date, total) in totalMap) {
            if (total.value <= 0) continue
            val deep = deepMap[date]?.value ?: continue
            val rem = remMap[date]?.value ?: continue
            val qualityRatio = (deep + rem) / total.value
            if (qualityRatio > 0.30) {
                highQualityDays += date
            } else if (qualityRatio < 0.25) {
                lowQualityDays += date
            }
        }

        if (highQualityDays.size < 5 || lowQualityDays.size < 3) return null

        val highQualityCals = highQualityDays.mapNotNull { day ->
            calMap[day + DAY_MS]?.value ?: calMap[startOfDay(day + DAY_MS)]?.value
        }
        val lowQualityCals = lowQualityDays.mapNotNull { day ->
            calMap[day + DAY_MS]?.value ?: calMap[startOfDay(day + DAY_MS)]?.value
        }

        if (highQualityCals.size < 3 || lowQualityCals.size < 3) return null

        val avgHigh = highQualityCals.average()
        val avgLow = lowQualityCals.average()
        if (avgLow <= 0) return null

        val diff = ((avgHigh - avgLow) / avgLow) * 100.0
        if (abs(diff) < 8) return null

        val moreOrFewer = if (diff > 0) "more" else "fewer"
        val higherOrLower = if (diff > 0) "higher" else "lower"

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Sleep Quality Affects Activity",
            detail = "High-quality sleep nights (>30% deep+REM) lead to ${String.format("%.0f", abs(diff))}% " +
                "$moreOrFewer active calories the next day. Nights with >30% deep+REM correlate with " +
                "${String.format("%.0f", abs(diff))}% $higherOrLower next-day active calories " +
                "(${String.format("%.0f", avgHigh)} vs ${String.format("%.0f", avgLow)} kcal) across " +
                "${highQualityCals.size + lowQualityCals.size} measured nights.",
            metric = HealthMetric.SLEEP_DEEP,
            priority = InsightPriority.LOW,
            directive = InsightDirective.SLEEP_BETTER,
            confidence = minOf((highQualityCals.size + lowQualityCals.size) / 30.0, 1.0),
        )
    }

    // ----- Consistency -----

    private fun analyzeConsistency(sleepSamples: List<DailySample>): AnalysisInsight? {
        val now = System.currentTimeMillis()
        val thirtyDaysAgo = now - 30L * DAY_MS

        val last30 = sleepSamples.filter { it.date > thirtyDaysAgo }
        if (last30.size < 14) return null

        val values = last30.map { it.value }
        val mean = values.average()
        if (mean <= 0) return null

        val stdDev = standardDeviation(values, mean)
        val cv = stdDev / mean

        // Weekday vs weekend split
        val calendar = Calendar.getInstance()
        val weekdayValues = last30.filter { sample ->
            calendar.timeInMillis = sample.date
            val dow = calendar.get(Calendar.DAY_OF_WEEK)
            dow in Calendar.MONDAY..Calendar.FRIDAY
        }.map { it.value }

        val weekendValues = last30.filter { sample ->
            calendar.timeInMillis = sample.date
            val dow = calendar.get(Calendar.DAY_OF_WEEK)
            dow == Calendar.SATURDAY || dow == Calendar.SUNDAY
        }.map { it.value }

        val weekdayAvg = if (weekdayValues.isNotEmpty()) weekdayValues.average() else 0.0
        val weekendAvg = if (weekendValues.isNotEmpty()) weekendValues.average() else 0.0
        val hasWeekdayWeekendData = weekdayValues.isNotEmpty() && weekendValues.isNotEmpty()

        val isConsistent = cv < 0.15
        val priority = if (cv > 0.25) InsightPriority.HIGH else InsightPriority.LOW
        val directive = if (isConsistent) InsightDirective.MAINTAIN else InsightDirective.SLEEP_BETTER

        val summaryParts = mutableListOf<String>()
        if (isConsistent) {
            summaryParts += "Your sleep schedule is consistent (\u00B1${String.format("%.0f", stdDev * 60)} min variation)"
        } else {
            summaryParts += "Your sleep varies by \u00B1${String.format("%.1f", stdDev)} hours night to night"
        }
        if (hasWeekdayWeekendData) {
            summaryParts += "Weekday avg: ${String.format("%.1f", weekdayAvg)} hrs, weekend avg: ${String.format("%.1f", weekendAvg)} hrs"
        }

        val gapNote = if (hasWeekdayWeekendData && abs(weekdayAvg - weekendAvg) > 0.5) {
            val shorter = if (weekdayAvg < weekendAvg) "weekday" else "weekend"
            val longer = if (weekdayAvg < weekendAvg) "weekend" else "weekday"
            " Your $shorter sleep is ${String.format("%.1f", abs(weekdayAvg - weekendAvg))} hrs shorter than your $longer average."
        } else ""

        val detail = if (isConsistent) {
            "${summaryParts.joinToString(". ")}. Sleep variation is \u00B1${String.format("%.0f", stdDev * 60)} min " +
                "around your ${String.format("%.1f", mean)} hr average (CV: ${String.format("%.0f", cv * 100)}%).$gapNote"
        } else {
            "${summaryParts.joinToString(". ")}. Sleep varies by \u00B1${String.format("%.1f", stdDev)} hrs " +
                "night to night (CV: ${String.format("%.0f", cv * 100)}%). " +
                "Weekday avg: ${String.format("%.1f", weekdayAvg)} hrs, weekend avg: ${String.format("%.1f", weekendAvg)} hrs.$gapNote"
        }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Sleep Consistency",
            detail = detail,
            metric = HealthMetric.SLEEP_DURATION,
            priority = priority,
            directive = directive,
            confidence = minOf(last30.size / 30.0, 1.0),
        )
    }

    // ----- Helpers -----

    /**
     * Align two metric series with a day offset. Returns pairs of (valueA on day N, valueB on day N+offset).
     */
    private fun alignWithOffset(
        seriesA: List<DailySample>,
        seriesB: List<DailySample>,
        dayOffset: Int,
    ): List<Pair<Double, Double>> {
        val mapB = seriesB.associateBy { startOfDay(it.date) }
        return seriesA.mapNotNull { sampleA ->
            val dayA = startOfDay(sampleA.date)
            val dayB = dayA + dayOffset.toLong() * DAY_MS
            val matchB = mapB[dayB] ?: return@mapNotNull null
            sampleA.value to matchB.value
        }
    }

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
    }
}
