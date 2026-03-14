package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.model.HealthMetric
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max

/**
 * Generates insights from the overall health score trajectory.
 *
 * Analyses:
 *   1. Score trajectory over last 30 days (first-half vs second-half comparison)
 *   2. Score momentum (is improvement accelerating or decelerating over 3 weeks)
 *   3. Sustained high/low periods (>=85 for 10+ days, or <60 for 7+ days)
 *
 * Uses the health score stored as a pseudo-metric in the time series.
 * Falls back to HRV-based approximation if dedicated score series is unavailable.
 *
 * Ported from iOS ScoreTrajectoryAnalyzer.swift.
 */
class ScoreTrajectoryAnalyzer : InsightAnalyzer {

    override val name: String = "ScoreTrajectoryAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        // Build a score history from time series data.
        // Use all available baselines to compute a simplified composite score per day.
        val scoreHistory = buildScoreHistory(context)
        if (scoreHistory.size < 7) return emptyList()

        val insights = mutableListOf<AnalysisInsight>()

        analyzeTrajectory(scoreHistory, 30)?.let { insights += it }
        analyzeMomentum(scoreHistory)?.let { insights += it }
        analyzeSustainedPeriod(scoreHistory)?.let { insights += it }

        return insights
    }

    // ----- Score History Construction -----

    /**
     * Build a daily score history from the available time series data.
     * For each day, compute a simple composite score from key metrics relative to baselines.
     */
    private fun buildScoreHistory(context: AnalysisContext): List<Pair<Long, Int>> {
        val keyMetrics = listOf(
            HealthMetric.HEART_RATE_VARIABILITY,
            HealthMetric.RESTING_HEART_RATE,
            HealthMetric.SLEEP_DURATION,
            HealthMetric.STEPS,
            HealthMetric.EXERCISE_MINUTES,
        )

        // Build day -> metric -> value map
        val dayValues = mutableMapOf<Long, MutableMap<HealthMetric, Double>>()
        for (metric in keyMetrics) {
            val samples = context.timeSeries[metric] ?: continue
            for (sample in samples) {
                val day = startOfDay(sample.date)
                dayValues.getOrPut(day) { mutableMapOf() }[metric] = sample.value
            }
        }

        // Score each day
        return dayValues.mapNotNull { (day, metrics) ->
            if (metrics.size < 2) return@mapNotNull null
            var score = 0.0
            var count = 0

            for ((metric, value) in metrics) {
                val baseline = context.baselines[metric] ?: continue
                if (baseline.standardDeviation <= 0) continue

                val z = (value - baseline.mean) / baseline.standardDeviation
                // Map z-score to 0-100 range where 0 = -2 sigma, 100 = +2 sigma
                val rawScore = ((z + 2) / 4.0).coerceIn(0.0, 1.0) * 100.0

                // Flip for lower-is-better metrics (e.g., resting HR)
                val metricScore = if (metric.higherIsBetter) rawScore else 100.0 - rawScore
                score += metricScore
                count++
            }

            if (count == 0) null else day to (score / count).toInt().coerceIn(0, 100)
        }.sortedBy { it.first }
    }

    // ----- 1. Trajectory (30-day first-half vs second-half) -----

    private fun analyzeTrajectory(scoreHistory: List<Pair<Long, Int>>, days: Int): AnalysisInsight? {
        val now = System.currentTimeMillis()
        val cutoff = now - days.toLong() * DAY_MS
        val recent = scoreHistory.filter { it.first >= cutoff }
        if (recent.size < 5) return null

        val mid = recent.size / 2
        val firstHalf = recent.take(mid)
        val secondHalf = recent.drop(mid)

        val firstAvg = firstHalf.map { it.second.toDouble() }.average()
        val secondAvg = secondHalf.map { it.second.toDouble() }.average()
        if (firstAvg <= 0) return null

        val changePercent = ((secondAvg - firstAvg) / firstAvg) * 100.0
        if (abs(changePercent) <= 3) return null

        val improving = changePercent > 0
        val absChange = String.format("%.0f", abs(changePercent))
        val currentScore = secondAvg.toInt()

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = if (improving) "Health Score Trending Up" else "Health Score Declining",
            detail = "Your overall health score has ${if (improving) "improved" else "declined"} " +
                "${absChange}% over the last $days days. Current average: $currentScore.",
            metric = HealthMetric.RESTING_HEART_RATE,
            priority = if (improving) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (improving) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
        )
    }

    // ----- 2. Momentum (3-week acceleration) -----

    private fun analyzeMomentum(scoreHistory: List<Pair<Long, Int>>): AnalysisInsight? {
        if (scoreHistory.size < 21) return null
        val recent = scoreHistory.takeLast(21)

        val week1 = recent.take(7).map { it.second.toDouble() }.average()
        val week2 = recent.drop(7).take(7).map { it.second.toDouble() }.average()
        val week3 = recent.takeLast(7).map { it.second.toDouble() }.average()

        val change1to2 = week2 - week1
        val change2to3 = week3 - week2
        val acceleration = change2to3 - change1to2

        if (abs(acceleration) <= 2) return null

        val accelerating = acceleration > 0
        val isImproving = change2to3 > 0

        return when {
            accelerating && isImproving -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Improvement Accelerating",
                detail = "Your health score gains are picking up speed. Week-over-week score change " +
                    "accelerated: ${String.format("%.1f", change1to2)} pts to ${String.format("%.1f", change2to3)} pts. " +
                    "Current average: ${String.format("%.0f", week3)}.",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.INFORMATIONAL,
                directive = InsightDirective.MAINTAIN,
            )
            !accelerating && !isImproving -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Decline Accelerating",
                detail = "Your health score is dropping faster. Weekly decline rate increased from " +
                    "${String.format("%.1f", abs(change1to2))} pts to ${String.format("%.1f", abs(change2to3))} pts. " +
                    "Score dropped from ${String.format("%.0f", week1)} to ${String.format("%.0f", week3)} over 3 weeks.",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.HIGH,
                directive = InsightDirective.INFORMATIONAL,
            )
            else -> null
        }
    }

    // ----- 3. Sustained High/Low Periods -----

    private fun analyzeSustainedPeriod(scoreHistory: List<Pair<Long, Int>>): AnalysisInsight? {
        if (scoreHistory.size < 7) return null
        val recent = scoreHistory.takeLast(14)

        val highDays = recent.count { it.second >= 85 }
        val lowDays = recent.count { it.second < 60 }

        if (highDays >= 10) {
            val avg = recent.map { it.second.toDouble() }.average()
            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Consistently Strong Health",
                detail = "Your health score has been 85+ for $highDays of the last ${recent.size} days. " +
                    "This is excellent. Average: ${String.format("%.0f", avg)}.",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.INFORMATIONAL,
                directive = InsightDirective.MAINTAIN,
            )
        }

        if (lowDays >= 7) {
            val avg = recent.map { it.second.toDouble() }.average()
            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Extended Low Score Period",
                detail = "Your health score has been below 60 for $lowDays of the last ${recent.size} days. " +
                    "Average: ${String.format("%.0f", avg)}.",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.HIGH,
                directive = InsightDirective.INFORMATIONAL,
            )
        }

        return null
    }

    // ----- Helpers -----

    private fun startOfDay(epochMs: Long): Long {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
