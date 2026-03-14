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

/**
 * Deep historical analysis leveraging up to 1 year of health data.
 *
 * Produces per-metric context: year-over-year change, all-time percentile,
 * seasonal norms, long-term trajectory, and historical rarity.
 *
 * Ported from iOS HistoricalAnalyzer.swift.
 */
class HistoricalAnalyzer : InsightAnalyzer {

    override val name: String = "HistoricalAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        for ((metric, samples) in context.timeSeries) {
            if (samples.size < 90) continue
            val baseline = context.baselines[metric] ?: continue

            val recentValues = samples.sortedByDescending { it.date }.take(3).map { it.value }
            if (recentValues.isEmpty()) continue
            val currentValue = recentValues.average()
            if (currentValue <= 0) continue

            yearOverYearInsight(metric, samples, currentValue)?.let { insights += it }
            allTimeExtremeInsight(metric, samples, currentValue)?.let { insights += it }
            seasonalInsight(metric, samples, currentValue)?.let { insights += it }
            longTermTrajectoryInsight(metric, samples, currentValue)?.let { insights += it }
            rarityInsight(metric, samples, currentValue)?.let { insights += it }
        }

        return insights
    }

    // ----- Year-over-Year -----

    private fun yearOverYearInsight(
        metric: HealthMetric,
        samples: List<DailySample>,
        currentValue: Double,
    ): AnalysisInsight? {
        val cal = Calendar.getInstance()
        val currentMonth = cal.get(Calendar.MONTH)
        val currentYear = cal.get(Calendar.YEAR)

        val lastYearSamples = samples.filter { s ->
            cal.timeInMillis = s.date
            cal.get(Calendar.MONTH) == currentMonth && cal.get(Calendar.YEAR) == currentYear - 1
        }
        if (lastYearSamples.isEmpty()) return null

        val lastYearAvg = lastYearSamples.map { it.value }.average()
        if (lastYearAvg <= 0) return null

        val yoyChange = ((currentValue - lastYearAvg) / lastYearAvg) * 100.0
        if (abs(yoyChange) <= 5) return null

        val improving = if (metric.higherIsBetter) yoyChange > 0 else yoyChange < 0
        val monthName = monthName(currentMonth)
        val absChange = fmt0(abs(yoyChange))

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName}: ${absChange}% ${if (improving) "Better" else "Worse"} vs $monthName Last Year",
            detail = "Compared to $monthName last year (${fmt1(lastYearAvg)} ${metric.unit}), " +
                "your ${metric.displayName.lowercase()} is ${absChange}% " +
                "${if (yoyChange > 0) "higher" else "lower"}.",
            metric = metric,
            priority = if (improving) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (improving) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
            confidence = minOf(lastYearSamples.size / 20.0, 1.0),
        )
    }

    // ----- All-Time Extreme -----

    private fun allTimeExtremeInsight(
        metric: HealthMetric,
        samples: List<DailySample>,
        currentValue: Double,
    ): AnalysisInsight? {
        if (samples.size < 180) return null
        val allValues = samples.map { it.value }.sorted()
        val high = allValues.max()
        val low = allValues.min()
        if (high <= low) return null

        val percentile = allValues.count { it <= currentValue }.toDouble() / allValues.size * 100.0

        val isNearHigh = percentile >= 95
        val isNearLow = percentile <= 5
        if (!isNearHigh && !isNearLow) return null

        val goodExtreme = if (isNearHigh) metric.higherIsBetter else !metric.higherIsBetter

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName}: Near All-Time ${if (isNearHigh) "High" else "Low"}",
            detail = "Your ${metric.displayName.lowercase()} is in the ${if (isNearHigh) "top" else "bottom"} 5% " +
                "of all values recorded over the past year (${samples.size} data points).",
            metric = metric,
            priority = if (goodExtreme) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (goodExtreme) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Seasonal Norm -----

    private fun seasonalInsight(
        metric: HealthMetric,
        samples: List<DailySample>,
        currentValue: Double,
    ): AnalysisInsight? {
        val cal = Calendar.getInstance()
        val currentMonth = cal.get(Calendar.MONTH)

        val seasonalSamples = samples.filter { s ->
            cal.timeInMillis = s.date
            cal.get(Calendar.MONTH) == currentMonth
        }
        if (seasonalSamples.size < 7) return null

        val seasonalAvg = seasonalSamples.map { it.value }.average()
        if (seasonalAvg <= 0) return null

        val deviation = ((currentValue - seasonalAvg) / seasonalAvg) * 100.0
        if (abs(deviation) <= 10) return null

        val isAbove = deviation > 0
        val improving = if (metric.higherIsBetter) isAbove else !isAbove
        val monthName = monthName(currentMonth)

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName}: ${if (improving) "Above" else "Below"} $monthName Norm",
            detail = "Your ${metric.displayName.lowercase()} is ${fmt0(abs(deviation))}% " +
                "${if (isAbove) "above" else "below"} your typical $monthName levels " +
                "(historical average: ${fmt1(seasonalAvg)} ${metric.unit}).",
            metric = metric,
            priority = if (improving) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (improving) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Long-Term Trajectory -----

    private fun longTermTrajectoryInsight(
        metric: HealthMetric,
        samples: List<DailySample>,
        currentValue: Double,
    ): AnalysisInsight? {
        if (samples.size < 180) return null
        val now = System.currentTimeMillis()
        val yearAgo = now - 365L * DAY_MS
        val longSamples = samples.filter { it.date > yearAgo }.sortedBy { it.date }
        if (longSamples.size < 60) return null

        val firstValue = longSamples.first().value
        if (firstValue <= 0) return null

        val changePercent = ((currentValue - firstValue) / firstValue) * 100.0
        if (abs(changePercent) <= 10) return null

        val improving = if (metric.higherIsBetter) changePercent > 0 else changePercent < 0

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName}: Long-Term ${if (improving) "Up" else "Down"} ${fmt0(abs(changePercent))}%",
            detail = "Looking at ${longSamples.size} data points over the past year, " +
                "your ${metric.displayName.lowercase()} has ${if (changePercent > 0) "increased" else "decreased"} " +
                "${fmt0(abs(changePercent))}% overall.",
            metric = metric,
            priority = if (improving) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (improving) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Historical Rarity -----

    private fun rarityInsight(
        metric: HealthMetric,
        samples: List<DailySample>,
        currentValue: Double,
    ): AnalysisInsight? {
        if (samples.size < 180) return null
        val now = System.currentTimeMillis()
        val tolerance = currentValue * 0.05
        val lower = currentValue - tolerance
        val upper = currentValue + tolerance

        // Find last similar value more than 7 days ago
        val olderSamples = samples.filter { (now - it.date) > 7 * DAY_MS }.sortedByDescending { it.date }
        val lastSimilar = olderSamples.firstOrNull { it.value in lower..upper }
        val daysSince = lastSimilar?.let { ((now - it.date) / DAY_MS).toInt() } ?: return null

        if (daysSince <= 90) return null

        val monthsAgo = daysSince / 30

        // Count occurrences in last year
        val yearSamples = samples.filter { it.date > now - 365 * DAY_MS }
        val occurrences = yearSamples.count { it.value in lower..upper }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName}: Rare ${if (currentValue > samples.map { it.value }.average()) "High" else "Low"} (${monthsAgo}mo)",
            detail = "Your current ${metric.displayName.lowercase()} level hasn't been seen in $monthsAgo months. " +
                "It occurred only $occurrences times in the past year.",
            metric = metric,
            priority = InsightPriority.INFORMATIONAL,
            directive = InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Helpers -----

    private fun monthName(calendarMonth: Int): String {
        val names = arrayOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        )
        return names.getOrElse(calendarMonth) { "Unknown" }
    }

    private fun fmt0(v: Double): String = String.format("%.0f", v)
    private fun fmt1(v: Double): String = String.format("%.1f", v)

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
