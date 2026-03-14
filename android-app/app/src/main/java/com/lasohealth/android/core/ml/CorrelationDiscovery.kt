package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Discovers statistically significant correlations between all N*(N-1)/2 metric pairs.
 *
 * For each pair with at least [MINIMUM_DAYS] of overlapping data:
 *   1. Pearson correlation (including lag analysis at 0-7 day offsets).
 *   2. Benjamini-Hochberg FDR correction at q = 0.05.
 *
 * Ported from iOS `CorrelationDiscovery.swift` (core Pearson + lag + FDR path).
 */
class CorrelationDiscovery {

    companion object {
        /** Minimum days of shared data required per metric pair. */
        const val MINIMUM_DAYS = 30
        /** Maximum lag to test (days). */
        private const val MAX_LAG = 7
        /** FDR significance level. */
        private const val FDR_ALPHA = 0.05
        /** Sliding window for stability tracking. */
        private const val STABILITY_WINDOW = 30
    }

    /** Correlations from the last [discover] run, sorted by strength descending. */
    var correlations: List<MLCorrelation> = emptyList()
        private set

    /** Whether any correlations have been discovered. */
    val isReady: Boolean get() = correlations.isNotEmpty()

    // -- Discovery ----------------------------------------------------------

    /**
     * Discover correlations from a per-metric time-series map.
     *
     * @param timeSeries  Daily samples grouped by metric.
     * @return The discovered (and FDR-corrected) correlations, also stored in [correlations].
     */
    fun discover(timeSeries: Map<HealthMetric, List<DailySample>>): List<MLCorrelation> {
        val cal = Calendar.getInstance()

        // Build date-aligned value maps (start-of-day epoch -> value).
        val dateValues: Map<HealthMetric, Map<Long, Double>> = timeSeries.mapValues { (_, samples) ->
            samples.associate { startOfDay(it.date, cal) to it.value }
        }

        // Filter to metrics active in the last 7 days.
        val recentCutoff = System.currentTimeMillis() - 7L * DAY_MS
        val activeMetrics = dateValues.keys
            .filter { metric -> dateValues[metric]?.keys?.any { it >= recentCutoff } == true }
            .sortedBy { it.name }

        if (activeMetrics.size < 2) {
            correlations = emptyList()
            return correlations
        }

        val results = mutableListOf<MLCorrelation>()

        for (i in activeMetrics.indices) {
            for (j in (i + 1) until activeMetrics.size) {
                val metricA = activeMetrics[i]
                val metricB = activeMetrics[j]

                val datesA = dateValues[metricA] ?: continue
                val datesB = dateValues[metricB] ?: continue

                // Overlapping dates, sorted.
                val commonDates = datesA.keys.intersect(datesB.keys).sorted()
                if (commonDates.size < MINIMUM_DAYS) continue

                val valuesA = commonDates.map { datesA.getValue(it) }
                val valuesB = commonDates.map { datesB.getValue(it) }

                // Find the best lag (0..MAX_LAG) by absolute Pearson r.
                var bestR = pearsonCorrelation(valuesA, valuesB) ?: continue
                var bestLag = 0

                for (lag in 1..MAX_LAG) {
                    if (commonDates.size - lag < MINIMUM_DAYS) break
                    val laggedA = valuesA.subList(0, valuesA.size - lag)
                    val laggedB = valuesB.subList(lag, valuesB.size)
                    val r = pearsonCorrelation(laggedA, laggedB) ?: continue
                    if (abs(r) > abs(bestR)) {
                        bestR = r
                        bestLag = lag
                    }
                    // Also test the reverse lag (B leads A).
                    val revA = valuesA.subList(lag, valuesA.size)
                    val revB = valuesB.subList(0, valuesB.size - lag)
                    val rRev = pearsonCorrelation(revA, revB) ?: continue
                    if (abs(rRev) > abs(bestR)) {
                        bestR = rRev
                        bestLag = -lag // negative = B leads A
                    }
                }

                // Skip negligible correlations early.
                if (abs(bestR) < 0.15) continue

                // Approximate two-tailed p-value from t-distribution.
                val n = commonDates.size
                val pValue = pearsonPValue(bestR, n)

                // Stability over sliding windows.
                val stability = correlationStability(valuesA, valuesB)

                results.add(
                    MLCorrelation(
                        metricA = metricA,
                        metricB = metricB,
                        coefficient = bestR,
                        pValue = pValue,
                        lagDays = bestLag,
                        isGrangerCausal = false, // Granger causality not yet ported
                        sampleCount = n,
                        stability = stability,
                        survivedFDR = true, // Updated below
                    ),
                )
            }
        }

        // Sort by strength descending.
        val sorted = results.sortedByDescending { it.overallStrength }.toMutableList()

        // Benjamini-Hochberg FDR correction.
        applyBenjaminiHochberg(sorted)

        correlations = sorted
        return correlations
    }

    // -- Query helpers ------------------------------------------------------

    /** Correlations involving a specific metric. */
    fun correlationsFor(metric: HealthMetric): List<MLCorrelation> =
        correlations.filter { it.metricA == metric || it.metricB == metric }

    /** Top N strongest correlations. */
    fun topCorrelations(count: Int = 10): List<MLCorrelation> =
        correlations.take(count)

    /** Only correlations that survived FDR correction. */
    fun fdrSignificant(): List<MLCorrelation> =
        correlations.filter { it.survivedFDR }

    // -- Pearson correlation ------------------------------------------------

    /**
     * Pearson correlation coefficient between two equal-length series.
     * Returns null if the series are too short or have zero variance.
     */
    private fun pearsonCorrelation(x: List<Double>, y: List<Double>): Double? {
        val n = min(x.size, y.size)
        if (n < 3) return null

        val meanX = x.take(n).average()
        val meanY = y.take(n).average()

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

        val denom = sqrt(sumX2 * sumY2)
        return if (denom > 0) (sumXY / denom).coerceIn(-1.0, 1.0) else null
    }

    /**
     * Approximate two-tailed p-value for a Pearson r using the t-distribution.
     *
     * t = r * sqrt((n-2) / (1-r^2)), df = n-2.
     * Uses the regularised incomplete beta function approximation.
     */
    private fun pearsonPValue(r: Double, n: Int): Double {
        if (n <= 2) return 1.0
        val absR = abs(r).coerceAtMost(0.9999)
        val df = n - 2
        val t = absR * sqrt(df.toDouble() / (1.0 - absR * absR))
        // Approximation: p = 2 * (1 - cdf_t(t, df)).
        // For df > 30, t-distribution ~ N(0,1); use Abramowitz & Stegun approx for small df.
        val x = df.toDouble() / (df + t * t)
        val p = incompleteBeta(df / 2.0, 0.5, x)
        return p.coerceIn(0.0, 1.0)
    }

    /**
     * Regularised incomplete beta function I_x(a, b) via continued fraction (Lentz).
     * Adequate precision for p-value estimation.
     */
    private fun incompleteBeta(a: Double, b: Double, x: Double): Double {
        if (x <= 0.0) return 0.0
        if (x >= 1.0) return 1.0

        // For numerical stability, use the identity I_x(a,b) = 1 - I_{1-x}(b,a) when x > (a+1)/(a+b+2).
        if (x > (a + 1.0) / (a + b + 2.0)) {
            return 1.0 - incompleteBeta(b, a, 1.0 - x)
        }

        val lnBeta = lnGamma(a) + lnGamma(b) - lnGamma(a + b)
        val front = kotlin.math.exp(ln(x) * a + ln(1.0 - x) * b - lnBeta) / a

        // Lentz continued fraction.
        var c = 1.0
        var d = 1.0 / max(1.0 - (a + b) * x / (a + 1.0), 1e-30)
        var h = d

        for (m in 1..200) {
            val m2 = 2 * m

            // Even step.
            var aa = m.toDouble() * (b - m) * x / ((a + m2 - 1) * (a + m2))
            d = 1.0 / max(1.0 + aa * d, 1e-30)
            c = max(1.0 + aa / c, 1e-30)
            h *= d * c

            // Odd step.
            aa = -((a + m) * (a + b + m) * x) / ((a + m2) * (a + m2 + 1))
            d = 1.0 / max(1.0 + aa * d, 1e-30)
            c = max(1.0 + aa / c, 1e-30)
            val delta = d * c
            h *= delta
            if (abs(delta - 1.0) < 1e-10) break
        }

        return (front * h).coerceIn(0.0, 1.0)
    }

    /** Lanczos approximation of ln(Gamma(x)). */
    private fun lnGamma(x: Double): Double {
        val coeffs = doubleArrayOf(
            76.18009172947146,
            -86.50532032941677,
            24.01409824083091,
            -1.231739572450155,
            0.1208650973866179e-2,
            -0.5395239384953e-5,
        )
        var y = x
        var tmp = x + 5.5
        tmp -= (x - 0.5) * ln(tmp)
        var ser = 1.000000000190015
        for (c in coeffs) {
            y += 1.0
            ser += c / y
        }
        return -tmp + ln(2.5066282746310005 * ser / x)
    }

    // -- Correlation stability ----------------------------------------------

    private fun correlationStability(x: List<Double>, y: List<Double>): Double {
        val n = min(x.size, y.size)
        if (n < STABILITY_WINDOW * 2) return 1.0

        val windowRs = mutableListOf<Double>()
        val step = max(STABILITY_WINDOW / 3, 1)
        var start = 0

        while (start + STABILITY_WINDOW <= n) {
            val wx = x.subList(start, start + STABILITY_WINDOW)
            val wy = y.subList(start, start + STABILITY_WINDOW)
            pearsonCorrelation(wx, wy)?.let { windowRs.add(it) }
            start += step
        }

        if (windowRs.size < 2) return 1.0

        val mean = windowRs.average()
        if (mean == 0.0) return 0.5
        val sd = sqrt(windowRs.sumOf { (it - mean) * (it - mean) } / windowRs.size)
        val cv = abs(sd / mean)
        return (1.0 - cv).coerceIn(0.0, 1.0)
    }

    // -- Benjamini-Hochberg -------------------------------------------------

    private fun applyBenjaminiHochberg(correlations: MutableList<MLCorrelation>) {
        val m = correlations.size
        if (m == 0) return

        // Sort indices by p-value ascending.
        val indexed = correlations.indices
            .filter { correlations[it].pValue < 1.0 }
            .sortedBy { correlations[it].pValue }

        val totalTests = indexed.size
        if (totalTests == 0) return

        // Find largest rank i where p_{(i)} <= (i / m) * alpha.
        var maxSurvivingRank = -1
        for ((rank, idx) in indexed.withIndex()) {
            val i = rank + 1
            val bhThreshold = (i.toDouble() / totalTests) * FDR_ALPHA
            if (correlations[idx].pValue <= bhThreshold) {
                maxSurvivingRank = rank
            }
        }

        // Default: nothing survives.
        for (i in correlations.indices) {
            correlations[i] = correlations[i].copy(survivedFDR = false)
        }

        // Mark survivors.
        if (maxSurvivingRank >= 0) {
            for (rank in 0..maxSurvivingRank) {
                val origIdx = indexed[rank]
                correlations[origIdx] = correlations[origIdx].copy(survivedFDR = true)
            }
        }
    }

    // -- Helpers ------------------------------------------------------------

    private fun startOfDay(epochMillis: Long, cal: Calendar): Long {
        cal.timeInMillis = epochMillis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}

private const val DAY_MS: Long = 86_400_000L
