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
        val candidates = mutableListOf<CorrelationCandidate>()
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

                val n = valuesA.size
                val correlation = pearsonCorrelation(valuesA, valuesB)

                val pValue = pearsonPValue(correlation, n)

                candidates.add(
                    CorrelationCandidate(
                        metricA = metricA,
                        metricB = metricB,
                        coefficient = correlation,
                        pValue = pValue,
                    ),
                )
            }
        }

        // Apply Benjamini-Hochberg FDR correction (alpha = 0.05)
        val surviving = benjaminiHochberg(candidates, alpha = 0.05)

        // Filter by |r| >= 0.3 AFTER BH correction so that all tests are counted
        // when computing FDR thresholds (filtering before BH inflates thresholds).
        return surviving.filter { kotlin.math.abs(it.coefficient) >= 0.3 }.map { c ->
            AnalysisCorrelation(
                metricA = c.metricA,
                metricB = c.metricB,
                coefficient = c.coefficient,
                strength = when {
                    kotlin.math.abs(c.coefficient) >= 0.7 -> "Strong"
                    kotlin.math.abs(c.coefficient) >= 0.5 -> "Moderate"
                    else -> "Weak"
                },
                description = buildCorrelationDescription(c.metricA, c.metricB, c.coefficient),
            )
        }.sortedByDescending { kotlin.math.abs(it.coefficient) }
    }

    /**
     * Intermediate holder for correlation candidates before FDR filtering.
     */
    private data class CorrelationCandidate(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val coefficient: Double,
        val pValue: Double,
    )

    /**
     * Compute two-tailed p-value for Pearson's r using the t-distribution approximation.
     *
     * t = r * sqrt((n - 2) / (1 - r²)), with n - 2 degrees of freedom.
     * Uses the regularised incomplete beta function for the CDF.
     */
    private fun pearsonPValue(r: Double, n: Int): Double {
        if (n <= 2) return 1.0
        val r2 = r * r
        if (r2 >= 1.0) return 0.0
        val df = n - 2
        val t = kotlin.math.abs(r) * kotlin.math.sqrt(df.toDouble() / (1.0 - r2))
        // Two-tailed p-value from t-distribution via incomplete beta
        val x = df.toDouble() / (df.toDouble() + t * t)
        return regularizedIncompleteBeta(df / 2.0, 0.5, x)
    }

    /**
     * Regularised incomplete beta function I_x(a, b) via continued fraction (Lentz's method).
     *
     * Used to compute CDF of the t-distribution for p-value calculation.
     */
    private fun regularizedIncompleteBeta(a: Double, b: Double, x: Double): Double {
        if (x <= 0.0) return 0.0
        if (x >= 1.0) return 1.0

        // Use symmetry relation when x > (a+1)/(a+b+2) for better convergence
        if (x > (a + 1.0) / (a + b + 2.0)) {
            return 1.0 - regularizedIncompleteBeta(b, a, 1.0 - x)
        }

        val lnPrefactor = a * kotlin.math.ln(x) + b * kotlin.math.ln(1.0 - x) -
            kotlin.math.ln(a) - lnBeta(a, b)
        val prefactor = kotlin.math.exp(lnPrefactor)

        // Lentz's continued fraction
        var c = 1.0
        var d = 1.0 - (a + b) * x / (a + 1.0)
        if (kotlin.math.abs(d) < 1e-30) d = 1e-30
        d = 1.0 / d
        var result = d

        for (m in 1..200) {
            val mDouble = m.toDouble()

            // Even step: d_{2m}
            var numerator = mDouble * (b - mDouble) * x /
                ((a + 2.0 * mDouble - 1.0) * (a + 2.0 * mDouble))
            d = 1.0 + numerator * d
            if (kotlin.math.abs(d) < 1e-30) d = 1e-30
            d = 1.0 / d
            c = 1.0 + numerator / c
            if (kotlin.math.abs(c) < 1e-30) c = 1e-30
            result *= d * c

            // Odd step: d_{2m+1}
            numerator = -(a + mDouble) * (a + b + mDouble) * x /
                ((a + 2.0 * mDouble) * (a + 2.0 * mDouble + 1.0))
            d = 1.0 + numerator * d
            if (kotlin.math.abs(d) < 1e-30) d = 1e-30
            d = 1.0 / d
            c = 1.0 + numerator / c
            if (kotlin.math.abs(c) < 1e-30) c = 1e-30
            val delta = d * c
            result *= delta

            if (kotlin.math.abs(delta - 1.0) < 1e-10) break
        }

        return prefactor * result
    }

    /** Log of the Beta function via log-gamma (Stirling). */
    private fun lnBeta(a: Double, b: Double): Double =
        lnGamma(a) + lnGamma(b) - lnGamma(a + b)

    /** Lanczos approximation for log-gamma. */
    private fun lnGamma(x: Double): Double {
        val coefficients = doubleArrayOf(
            76.18009172947146, -86.50532032941677,
            24.01409824083091, -1.231739572450155,
            0.1208650973866179e-2, -0.5395239384953e-5,
        )
        var y = x
        var tmp = x + 5.5
        tmp -= (x - 0.5) * kotlin.math.ln(tmp)
        var ser = 1.000000000190015
        for (coeff in coefficients) {
            y += 1.0
            ser += coeff / y
        }
        return -tmp + kotlin.math.ln(2.5066282746310005 * ser / x)
    }

    /**
     * Benjamini-Hochberg FDR correction.
     *
     * Procedure: sort p-values ascending, compare each p_{(i)} to (i / m) * alpha,
     * reject all hypotheses up to the largest i where p_{(i)} <= threshold.
     *
     * @return Only the candidates that survive FDR correction.
     */
    private fun benjaminiHochberg(
        candidates: List<CorrelationCandidate>,
        alpha: Double,
    ): List<CorrelationCandidate> {
        if (candidates.isEmpty()) return emptyList()

        val sorted = candidates.sortedBy { it.pValue }
        val m = sorted.size

        // Find the largest rank where p_{(i)} <= (i/m) * alpha
        var maxSurvivingRank = -1
        for (i in sorted.indices) {
            val rank = i + 1 // 1-based
            val bhThreshold = (rank.toDouble() / m.toDouble()) * alpha
            if (sorted[i].pValue <= bhThreshold) {
                maxSurvivingRank = i
            }
        }

        if (maxSurvivingRank < 0) return emptyList()
        return sorted.subList(0, maxSurvivingRank + 1)
    }

    // TODO: Add Granger causality testing (iOS uses GrangerCausalityEngine with OLS + F-test).
    // This would detect directional/causal relationships (e.g., poor sleep → elevated resting HR
    // next day) rather than just symmetric correlations. See iOS Analysis/ML/GrangerCausalityEngine.swift.

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
