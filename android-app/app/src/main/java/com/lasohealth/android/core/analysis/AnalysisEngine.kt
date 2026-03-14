package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.analysis.analyzers.BaselineDriftDetector
import com.lasohealth.android.core.analysis.analyzers.CausalChainEngine
import com.lasohealth.android.core.analysis.analyzers.ClinicalIntelligence
import com.lasohealth.android.core.analysis.analyzers.CognitiveEnergyAnalyzer
import com.lasohealth.android.core.analysis.analyzers.CorrelationAnalyzer
import com.lasohealth.android.core.analysis.analyzers.CrossMetricAnomalyDetector
import com.lasohealth.android.core.analysis.analyzers.HistoricalAnalyzer
import com.lasohealth.android.core.analysis.analyzers.IllnessEarlyWarning
import com.lasohealth.android.core.analysis.analyzers.InsightCoordinator
import com.lasohealth.android.core.analysis.analyzers.InsightGenerator
import com.lasohealth.android.core.analysis.analyzers.MultiMetricClusterAnalyzer
import com.lasohealth.android.core.analysis.analyzers.NutritionCorrelationAnalyzer
import com.lasohealth.android.core.analysis.analyzers.PersonalRecordAnalyzer
import com.lasohealth.android.core.analysis.analyzers.RecoveryAnalyzer
import com.lasohealth.android.core.analysis.analyzers.ScoreTrajectoryAnalyzer
import com.lasohealth.android.core.analysis.analyzers.SleepPerformanceAnalyzer
import com.lasohealth.android.core.analysis.analyzers.WeeklyPatternAnalyzer
import com.lasohealth.android.core.analysis.analyzers.WorkoutEffectivenessAnalyzer
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Master analysis orchestrator — ports iOS AnalysisEngine.swift.
 *
 * Pipeline: Baselines → Trends → Anomalies → Scores → Insights → Correlations.
 * Three phases:
 * 1. Core (required before UI renders): baselines, trends, anomalies, scores
 * 2. Essential deferred: insights, health risks, illness warnings
 * 3. Heavy deferred (1-hour TTL): correlations, historical context
 */
class AnalysisEngine(
    private val baselineCalculator: BaselineCalculator = BaselineCalculator(),
    private val trendAnalyzer: TrendAnalyzer = TrendAnalyzer(),
    private val anomalyDetector: AnomalyDetector = AnomalyDetector(),
    private val healthScorer: HealthScorer = HealthScorer(),
    private val insightCoordinator: InsightCoordinator = InsightCoordinator(),
) {
    // ── Observable State ────────────────────────────────────────────────────────

    var baselines: Map<HealthMetric, MetricBaseline> = emptyMap()
        private set

    var trends: Map<HealthMetric, MetricTrend> = emptyMap()
        private set

    var anomalies: List<MetricAnomaly> = emptyList()
        private set

    var overallScore: HealthScore = HealthScore(
        overall = 100,
        categoryScores = emptyMap(),
        contributions = emptyMap(),
    )
        private set

    var categoryScores: Map<HealthCategory, Int> = emptyMap()
        private set

    var insights: List<AnalysisInsight> = emptyList()
        private set

    var correlations: List<AnalysisCorrelation> = emptyList()
        private set

    var isAnalyzing: Boolean = false
        private set

    var lastAnalysisTimestamp: Long? = null
        private set

    // ── Deferred Analysis TTL ───────────────────────────────────────────────────

    private var lastHeavyAnalysisTimestamp: Long? = null
    private val heavyAnalysisTtlMs = 3_600_000L // 1 hour

    val needsHeavyAnalysis: Boolean
        get() {
            val last = lastHeavyAnalysisTimestamp ?: return true
            return System.currentTimeMillis() - last >= heavyAnalysisTtlMs
        }

    // ── Full Analysis Pipeline ──────────────────────────────────────────────────

    suspend fun runFullAnalysis(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ) {
        runCoreAnalysis(timeSeries)
        runDeferredEssentials(timeSeries)
        if (needsHeavyAnalysis) {
            runDeferredHeavy(timeSeries)
        }
    }

    // ── Phase 1: Core Analysis ──────────────────────────────────────────────────

    suspend fun runCoreAnalysis(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ) = withContext(Dispatchers.Default) {
        isAnalyzing = true

        // Step 1: Baselines
        val newBaselines = baselineCalculator.calculateAll(timeSeries)

        // Step 2: Trends
        val newTrends = trendAnalyzer.analyzeAll(timeSeries)

        // Step 3: Anomalies
        val newAnomalies = anomalyDetector.detectAll(timeSeries, newBaselines)

        // Step 4: Scores
        val newScore = healthScorer.score(timeSeries, newBaselines, newTrends)

        // Commit state
        baselines = newBaselines
        trends = newTrends
        anomalies = newAnomalies
        overallScore = newScore
        categoryScores = newScore.categoryScores
        lastAnalysisTimestamp = System.currentTimeMillis()
    }

    // ── Phase 2: Essential Deferred ─────────────────────────────────────────────

    suspend fun runDeferredEssentials(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ) = withContext(Dispatchers.Default) {
        val dayCount = timeSeries.values
            .maxOfOrNull { it.map { s -> s.date }.distinct().size } ?: 0

        val context = AnalysisContext(
            timeSeries = timeSeries,
            baselines = baselines,
            trends = trends,
            anomalies = anomalies,
            dayCount = dayCount,
        )

        // Essential analyzers (fast, run every refresh) — iOS: AnalyzerRegistry.essential
        val essentialAnalyzers: List<InsightAnalyzer> = listOf(
            InsightGenerator(),
            RecoveryAnalyzer(),
            SleepPerformanceAnalyzer(),
            ClinicalIntelligence(),
            IllnessEarlyWarning(),
            WeeklyPatternAnalyzer(),
            PersonalRecordAnalyzer(),
            CognitiveEnergyAnalyzer(),
            ScoreTrajectoryAnalyzer(),
            WorkoutEffectivenessAnalyzer(),
        )

        // Heavy analyzers (slower, only when dayCount >= 30) — iOS: AnalyzerRegistry.heavy
        val heavyAnalyzers: List<InsightAnalyzer> = if (dayCount >= 30) {
            listOf(
                CorrelationAnalyzer(),
                HistoricalAnalyzer(),
                CrossMetricAnomalyDetector(),
                NutritionCorrelationAnalyzer(),
                BaselineDriftDetector(),
                MultiMetricClusterAnalyzer(),
                CausalChainEngine(),
            )
        } else {
            emptyList()
        }

        val newInsights = insightCoordinator.coordinate(context, essentialAnalyzers + heavyAnalyzers)
        insights = newInsights
    }

    // ── Phase 3: Heavy Deferred ─────────────────────────────────────────────────

    suspend fun runDeferredHeavy(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ) = withContext(Dispatchers.Default) {
        // Correlation analysis for all metric pairs
        val newCorrelations = analyzeCorrelations(timeSeries)

        correlations = newCorrelations
        lastHeavyAnalysisTimestamp = System.currentTimeMillis()
        isAnalyzing = false
    }

    // ── Correlation Analysis ────────────────────────────────────────────────────

    private fun analyzeCorrelations(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ): List<AnalysisCorrelation> {
        val results = mutableListOf<AnalysisCorrelation>()
        val metrics = timeSeries.keys.toList()

        for (i in metrics.indices) {
            for (j in (i + 1) until metrics.size) {
                val metricA = metrics[i]
                val metricB = metrics[j]
                val samplesA = timeSeries[metricA] ?: continue
                val samplesB = timeSeries[metricB] ?: continue

                // Align by date
                val datesA = samplesA.associateBy { it.date }
                val datesB = samplesB.associateBy { it.date }
                val sharedDates = datesA.keys.intersect(datesB.keys)
                if (sharedDates.size < 14) continue

                val valuesA = sharedDates.sorted().map { datesA[it]!!.value }
                val valuesB = sharedDates.sorted().map { datesB[it]!!.value }

                val correlation = pearsonCorrelation(valuesA, valuesB)
                if (kotlin.math.abs(correlation) >= 0.3) {
                    results.add(
                        AnalysisCorrelation(
                            metricA = metricA,
                            metricB = metricB,
                            coefficient = correlation,
                            strength = when {
                                kotlin.math.abs(correlation) >= 0.7 -> "Strong"
                                kotlin.math.abs(correlation) >= 0.5 -> "Moderate"
                                else -> "Weak"
                            },
                            description = buildCorrelationDescription(metricA, metricB, correlation),
                        ),
                    )
                }
            }
        }

        return results.sortedByDescending { kotlin.math.abs(it.coefficient) }
    }

    private fun pearsonCorrelation(x: List<Double>, y: List<Double>): Double {
        val n = x.size
        if (n < 3) return 0.0
        val meanX = x.average()
        val meanY = y.average()
        var sumXY = 0.0
        var sumX2 = 0.0
        var sumY2 = 0.0
        for (i in 0 until n) {
            val dx = x[i] - meanX
            val dy = y[i] - meanY
            sumXY += dx * dy
            sumX2 += dx * dx
            sumY2 += dy * dy
        }
        val denom = kotlin.math.sqrt(sumX2 * sumY2)
        return if (denom > 0) sumXY / denom else 0.0
    }

    private fun buildCorrelationDescription(
        metricA: HealthMetric,
        metricB: HealthMetric,
        coefficient: Double,
    ): String {
        val direction = if (coefficient > 0) "positively" else "inversely"
        val strength = when {
            kotlin.math.abs(coefficient) >= 0.7 -> "strongly"
            kotlin.math.abs(coefficient) >= 0.5 -> "moderately"
            else -> "weakly"
        }
        return "Your ${metricA.displayName} is $strength $direction correlated with ${metricB.displayName}."
    }
}

/**
 * Correlation result between two metrics.
 */
data class AnalysisCorrelation(
    val metricA: HealthMetric,
    val metricB: HealthMetric,
    val coefficient: Double,
    val strength: String,
    val description: String,
)
