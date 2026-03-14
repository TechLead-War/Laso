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
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Detects days where the COMBINATION of metrics is unusual even if individual metrics
 * look normal. Uses a simplified Mahalanobis-inspired approach with pairwise correlation
 * analysis and historical rarity to find multivariate anomalies that single-metric
 * detectors miss.
 *
 * Ported from iOS CrossMetricAnomalyDetector.swift.
 */
class CrossMetricAnomalyDetector : InsightAnalyzer {

    override val name: String = "CrossMetricAnomalyDetector"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val anomalies = detect(context.timeSeries, context.baselines)
        return anomalies.mapNotNull { anomaly ->
            if (anomaly.score < 75.0) return@mapNotNull null

            val primaryMetric = anomaly.deviations
                .maxByOrNull { abs(it.zScore) }?.metric ?: HealthMetric.HEART_RATE

            AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = buildTitle(anomaly),
                detail = anomaly.narrative,
                metric = primaryMetric,
                priority = if (anomaly.score >= 90) InsightPriority.HIGH else InsightPriority.MEDIUM,
                directive = InsightDirective.INFORMATIONAL,
            )
        }
    }

    // ----- Data models -----

    private data class MetricDeviation(
        val metric: HealthMetric,
        val zScore: Double,
        val direction: String,
    )

    private data class BrokenCorrelation(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val expectedRelationship: String,
        val actualBehavior: String,
    )

    private data class CrossMetricAnomaly(
        val date: Long,
        val score: Double,
        val deviations: List<MetricDeviation>,
        val brokenCorrelations: List<BrokenCorrelation>,
        val similarDays: Int,
        val narrative: String,
    )

    private data class DailyFeatureVector(
        val date: Long,
        val zScores: Map<HealthMetric, Double>,
    )

    private data class NormalProfile(
        val meanZScores: Map<HealthMetric, Double>,
        val zScoreStdDevs: Map<HealthMetric, Double>,
    )

    private data class MetricCorrelation(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val r: Double,
    )

    // ----- Configuration -----

    companion object {
        private const val MIN_METRICS_PER_DAY = 4
        private const val MIN_HISTORY_DAYS = 30
        private const val HISTORY_WINDOW_DAYS = 90
        private const val RECENT_WINDOW_DAYS = 7
        private const val CORRELATION_THRESHOLD = 0.3
        private const val MAX_SIMILAR_DAYS = 5
        private const val DAY_MS = 86_400_000L
    }

    // ----- Detection Pipeline -----

    private fun detect(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): List<CrossMetricAnomaly> {
        val dailyVectors = buildDailyFeatureVectors(timeSeries, baselines, HISTORY_WINDOW_DAYS)
        val now = System.currentTimeMillis()

        val historyVectors = dailyVectors.filter { (now - it.date) / DAY_MS >= RECENT_WINDOW_DAYS }
        if (historyVectors.size < MIN_HISTORY_DAYS) return emptyList()

        val normalProfile = computeNormalProfile(historyVectors)
        val correlationStructure = computeCorrelationStructure(historyVectors)

        val recentVectors = dailyVectors.filter { (now - it.date) / DAY_MS < RECENT_WINDOW_DAYS }

        return recentVectors.mapNotNull { recentDay ->
            scoreDay(recentDay, normalProfile, correlationStructure, historyVectors)
        }.sortedByDescending { it.score }
    }

    // ----- Step 1: Build daily z-score feature vectors -----

    private fun buildDailyFeatureVectors(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        days: Int,
    ): List<DailyFeatureVector> {
        val now = System.currentTimeMillis()
        val metricByDate = mutableMapOf<HealthMetric, Map<Long, Double>>()
        for ((metric, samples) in timeSeries) {
            val dateMap = mutableMapOf<Long, Double>()
            for (sample in samples) {
                if ((now - sample.date) / DAY_MS <= days) {
                    dateMap[startOfDay(sample.date)] = sample.value
                }
            }
            metricByDate[metric] = dateMap
        }

        val vectors = mutableListOf<DailyFeatureVector>()
        for (dayOffset in 0 until days) {
            val date = startOfDay(now - dayOffset * DAY_MS)
            val zScores = mutableMapOf<HealthMetric, Double>()

            for ((metric, dateMap) in metricByDate) {
                val value = dateMap[date] ?: continue
                val baseline = baselines[metric] ?: continue
                if (baseline.standardDeviation <= 0 || baseline.sampleCount < 7) continue
                zScores[metric] = (value - baseline.mean) / baseline.standardDeviation
            }

            if (zScores.size >= MIN_METRICS_PER_DAY) {
                vectors += DailyFeatureVector(date, zScores)
            }
        }
        return vectors.sortedBy { it.date }
    }

    // ----- Step 2: Normal profile -----

    private fun computeNormalProfile(history: List<DailyFeatureVector>): NormalProfile {
        val zByMetric = mutableMapOf<HealthMetric, MutableList<Double>>()
        for (v in history) {
            for ((m, z) in v.zScores) {
                zByMetric.getOrPut(m) { mutableListOf() }.add(z)
            }
        }
        val means = mutableMapOf<HealthMetric, Double>()
        val stdDevs = mutableMapOf<HealthMetric, Double>()
        for ((m, values) in zByMetric) {
            if (values.size < 7) continue
            means[m] = values.average()
            val mean = values.average()
            stdDevs[m] = sqrt(values.map { (it - mean) * (it - mean) }.average())
        }
        return NormalProfile(means, stdDevs)
    }

    // ----- Step 3: Pairwise correlations -----

    private fun computeCorrelationStructure(history: List<DailyFeatureVector>): List<MetricCorrelation> {
        val metricCounts = mutableMapOf<HealthMetric, Int>()
        for (v in history) {
            for (m in v.zScores.keys) metricCounts[m] = (metricCounts[m] ?: 0) + 1
        }
        val eligible = metricCounts.entries
            .filter { it.value >= 14 }
            .sortedByDescending { it.value }
            .take(12)
            .map { it.key }
            .sortedBy { it.name }

        if (eligible.size < 2) return emptyList()

        val results = mutableListOf<MetricCorrelation>()
        for (i in eligible.indices) {
            for (j in (i + 1) until eligible.size) {
                val a = eligible[i]; val b = eligible[j]
                val aVals = mutableListOf<Double>(); val bVals = mutableListOf<Double>()
                for (v in history) {
                    val zA = v.zScores[a] ?: continue; val zB = v.zScores[b] ?: continue
                    aVals += zA; bVals += zB
                }
                val r = pearsonCorrelation(aVals, bVals) ?: continue
                if (abs(r) >= CORRELATION_THRESHOLD) results += MetricCorrelation(a, b, r)
            }
        }
        return results
    }

    // ----- Step 4: Score recent days -----

    private fun scoreDay(
        day: DailyFeatureVector,
        normalProfile: NormalProfile,
        correlationStructure: List<MetricCorrelation>,
        historyVectors: List<DailyFeatureVector>,
    ): CrossMetricAnomaly? {
        val combinedZ = computeCombinedZScore(day, normalProfile)
        val brokenCorrelations = findBrokenCorrelations(day, correlationStructure)
        val similarDays = countSimilarDays(day, historyVectors)

        val deviations = day.zScores
            .filter { abs(it.value) > 0.5 }
            .map { (m, z) -> MetricDeviation(m, z, if (z > 0) "above" else "below") }
            .sortedByDescending { abs(it.zScore) }

        val hasStrongIndividual = deviations.any { abs(it.zScore) >= 2.5 }
        val hasCombination = brokenCorrelations.isNotEmpty() || deviations.size >= 3
        if (hasStrongIndividual && !hasCombination) return null

        val anomalyScore = computeAnomalyScore(combinedZ, brokenCorrelations.size, similarDays, deviations.size)
        if (anomalyScore < 60) return null
        if (similarDays >= MAX_SIMILAR_DAYS) return null

        val narrative = buildNarrative(deviations, brokenCorrelations, similarDays, historyVectors.size)

        return CrossMetricAnomaly(day.date, anomalyScore, deviations, brokenCorrelations, similarDays, narrative)
    }

    private fun computeCombinedZScore(day: DailyFeatureVector, profile: NormalProfile): Double {
        var sumSq = 0.0; var count = 0
        for ((m, z) in day.zScores) {
            val histMean = profile.meanZScores[m] ?: continue
            val histStd = profile.zScoreStdDevs[m] ?: continue
            if (histStd <= 0) continue
            val nd = (z - histMean) / histStd
            sumSq += nd * nd; count++
        }
        return if (count > 0) sqrt(sumSq / count) else 0.0
    }

    private fun findBrokenCorrelations(
        day: DailyFeatureVector,
        structure: List<MetricCorrelation>,
    ): List<BrokenCorrelation> {
        val broken = mutableListOf<BrokenCorrelation>()
        for (c in structure) {
            val zA = day.zScores[c.metricA] ?: continue
            val zB = day.zScores[c.metricB] ?: continue

            val bothUp = zA > 0.5 && zB > 0.5
            val bothDown = zA < -0.5 && zB < -0.5
            val same = bothUp || bothDown
            val diverging = (zA > 0.5 && zB < -0.5) || (zA < -0.5 && zB > 0.5)

            val isBroken: Boolean
            val expected: String
            val actual: String

            if (c.r > 0 && diverging) {
                isBroken = true; expected = "normally correlated"
                val aDir = if (zA > 0) "elevated" else "reduced"
                val bDir = if (zB > 0) "elevated" else "reduced"
                actual = "${c.metricA.displayName} $aDir, ${c.metricB.displayName} $bDir"
            } else if (c.r < 0 && same) {
                isBroken = true; expected = "normally inverse"
                actual = if (bothUp) "both elevated" else "both reduced"
            } else {
                continue
            }

            if (abs(zA) < 0.8 && abs(zB) < 0.8) continue
            broken += BrokenCorrelation(c.metricA, c.metricB, expected, actual)
        }
        return broken
    }

    private fun countSimilarDays(day: DailyFeatureVector, history: List<DailyFeatureVector>): Int {
        var count = 0
        for (hist in history) {
            var matching = 0; var compared = 0
            for ((m, z) in day.zScores) {
                val hz = hist.zScores[m] ?: continue
                compared++
                if (abs(z - hz) <= 1.0) matching++
            }
            if (compared < MIN_METRICS_PER_DAY) continue
            if (matching.toDouble() / compared >= 0.8) {
                count++
                if (count >= MAX_SIMILAR_DAYS) return count
            }
        }
        return count
    }

    private fun computeAnomalyScore(
        combinedZ: Double,
        brokenCount: Int,
        similarDays: Int,
        deviationCount: Int,
    ): Double {
        val zComp = min(combinedZ / 3.0, 1.0) * 40.0
        val corrComp = min(brokenCount / 3.0, 1.0) * 30.0
        val rarityComp = when {
            similarDays == 0 -> 20.0
            similarDays == 1 -> 15.0
            similarDays <= 3 -> 10.0
            else -> maxOf(0.0, 20.0 - similarDays * 4.0)
        }
        val breadthComp = min(deviationCount / 5.0, 1.0) * 10.0
        return min(zComp + corrComp + rarityComp + breadthComp, 100.0)
    }

    // ----- Narrative & Title -----

    private fun buildNarrative(
        deviations: List<MetricDeviation>,
        brokenCorrelations: List<BrokenCorrelation>,
        similarDays: Int,
        historyDays: Int,
    ): String {
        val parts = mutableListOf<String>()

        val top = deviations.take(3)
        if (top.size >= 2) {
            parts += "Your " + top.joinToString(", ") { "${it.metric.displayName.lowercase()} is ${it.direction} baseline" }
        } else if (top.isNotEmpty()) {
            parts += "Your ${top[0].metric.displayName.lowercase()} is ${top[0].direction} baseline"
        }

        brokenCorrelations.firstOrNull()?.let {
            parts += "your ${it.metricA.displayName} and ${it.metricB.displayName} are " +
                "${it.expectedRelationship} for you, but today ${it.actualBehavior}"
        }

        when {
            similarDays == 0 -> parts += "this combination has never appeared in your $historyDays-day history"
            similarDays <= 2 -> parts += "this combination has only appeared $similarDays other ${if (similarDays == 1) "time" else "times"} in your $historyDays-day history"
        }

        if (parts.isEmpty()) return "An unusual combination of metric values was detected."

        var narrative = parts[0].replaceFirstChar { it.uppercase() }
        if (parts.size > 1) narrative += " \u2014 ${parts[1]}"
        if (parts.size > 2) narrative += ". ${parts[2].replaceFirstChar { it.uppercase() }}"
        narrative += "."
        return narrative
    }

    private fun buildTitle(anomaly: CrossMetricAnomaly): String {
        if (anomaly.brokenCorrelations.isNotEmpty()) {
            val b = anomaly.brokenCorrelations[0]
            return "Unusual ${b.metricA.displayName} / ${b.metricB.displayName} Pattern"
        }
        if (anomaly.deviations.size >= 3) return "Unusual Multi-Metric Pattern"
        return "Rare Metric Combination"
    }

    // ----- Statistics -----

    private fun pearsonCorrelation(x: List<Double>, y: List<Double>): Double? {
        if (x.size < 5 || x.size != y.size) return null
        val meanX = x.average(); val meanY = y.average()
        var num = 0.0; var dX = 0.0; var dY = 0.0
        for (i in x.indices) {
            val dx = x[i] - meanX; val dy = y[i] - meanY
            num += dx * dy; dX += dx * dx; dY += dy * dy
        }
        if (dX <= 0 || dY <= 0) return null
        return num / (sqrt(dX) * sqrt(dY))
    }

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
