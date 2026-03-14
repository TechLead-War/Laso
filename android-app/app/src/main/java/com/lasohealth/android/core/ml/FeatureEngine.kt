package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Converts raw health time series into standardised [DailyFeatureVector]s with 18 derived
 * features per metric per day.
 *
 * Uses Welford's online algorithm for incremental z-score normalisation and computes:
 *   raw, rateOfChange, volatility7/14/28, lag1/3/7/14/28/60,
 *   deviationFromBaseline, acceleration, entropy, periodicityStrength,
 *   weekdayOffset, weekendOffset, missingness.
 *
 * Minimum 7 days of data required before any vectors are produced.
 *
 * Ported from iOS `FeatureEngine.swift`.
 */
class FeatureEngine {

    // -- Configuration ------------------------------------------------------

    companion object {
        /** Minimum days of data before producing feature vectors. */
        const val MINIMUM_DAYS = 7

        /** z-score range mapped into entropy bins. */
        private const val ENTROPY_Z_MIN = -3.0
        private const val ENTROPY_Z_MAX = 3.0

        /** Lags evaluated for periodicity strength (autocorrelation). */
        private val PERIODICITY_LAGS = intArrayOf(7, 14, 28)

        /** Lag configurations: (lag days, feature type). */
        private val LAG_CONFIGS: List<Pair<Int, FeatureType>> = listOf(
            1 to FeatureType.LAG_1,
            3 to FeatureType.LAG_3,
            7 to FeatureType.LAG_7,
            14 to FeatureType.LAG_14,
            28 to FeatureType.LAG_28,
            60 to FeatureType.LAG_60,
        )

        /** Sturges' rule with floor 5, cap 15. */
        private fun adaptiveBinCount(sampleSize: Int): Int {
            val sturges = ceil(1.0 + log2(max(sampleSize, 2).toDouble())).toInt()
            return max(5, min(sturges, 15))
        }
    }

    // -- Running statistics (Welford) ---------------------------------------

    /** Incremental mean/variance tracker. */
    private data class WelfordState(
        var count: Int = 0,
        var mean: Double = 0.0,
        var m2: Double = 0.0,
    ) {
        val variance: Double get() = if (count > 1) m2 / count.toDouble() else 0.0
        val stdDev: Double get() = sqrt(variance)

        fun update(value: Double) {
            count++
            val delta = value - mean
            mean += delta / count.toDouble()
            val delta2 = value - mean
            m2 += delta * delta2
        }

        fun zScore(value: Double): Double {
            val sd = stdDev
            return if (sd > 0) (value - mean) / sd else 0.0
        }
    }

    private val runningStats = mutableMapOf<HealthMetric, WelfordState>()
    private val weekdayStats = mutableMapOf<HealthMetric, WelfordState>()
    private val weekendStats = mutableMapOf<HealthMetric, WelfordState>()

    /** Deterministic feature-key ordering produced by the last [extract] call. */
    var orderedKeys: List<FeatureKey> = emptyList()
        private set

    /** Whether the engine has enough data to produce useful features. */
    val isReady: Boolean
        get() = runningStats.values.any { it.count >= MINIMUM_DAYS }

    // -- Public API ---------------------------------------------------------

    /**
     * Build daily feature vectors from raw samples.
     *
     * @param samples  Flat list of daily samples (all metrics mixed).
     * @param baselines  Pre-computed baselines keyed by metric.
     * @return Feature vectors sorted oldest-first, empty if fewer than [MINIMUM_DAYS].
     */
    fun extract(
        samples: List<DailySample>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): List<DailyFeatureVector> {
        if (samples.isEmpty()) return emptyList()

        val cal = Calendar.getInstance()

        // Group by metric then by date (epoch-millis start-of-day).
        val metricByDate: Map<HealthMetric, Map<Long, Double>> = samples
            .groupBy { it.metric }
            .mapValues { (_, list) ->
                list.associate { startOfDay(it.date, cal) to it.value }
            }

        // Determine date range.
        val allDates = metricByDate.values.flatMap { it.keys }
        val earliest = allDates.minOrNull() ?: return emptyList()
        val today = startOfDay(System.currentTimeMillis(), cal)
        val totalDays = ((today - earliest) / DAY_MS).toInt()
        if (totalDays < MINIMUM_DAYS) return emptyList()

        // Initialise / rebuild running stats.
        for ((metric, dateMap) in metricByDate) {
            val existing = runningStats[metric]
            if (existing == null || existing.count == 0) {
                val state = WelfordState()
                dateMap.values.forEach { state.update(it) }
                runningStats[metric] = state
            }
        }

        // Rebuild weekday/weekend stats from scratch (cheap, ensures correctness).
        weekdayStats.clear()
        weekendStats.clear()
        for ((metric, dateMap) in metricByDate) {
            val wdState = WelfordState()
            val weState = WelfordState()
            for ((date, value) in dateMap) {
                cal.timeInMillis = date
                val dow = cal.get(Calendar.DAY_OF_WEEK)
                if (dow == Calendar.SUNDAY || dow == Calendar.SATURDAY) {
                    weState.update(value)
                } else {
                    wdState.update(value)
                }
            }
            weekdayStats[metric] = wdState
            weekendStats[metric] = weState
        }

        val sortedMetrics = metricByDate.keys.sortedBy { it.name }

        // Build deterministic ordered keys.
        orderedKeys = sortedMetrics.flatMap { metric ->
            FeatureType.entries.map { FeatureKey(metric, it) }
        }

        // Pre-compute z-score series per metric (oldest first) for autocorrelation.
        val zSeriesByMetric = mutableMapOf<HealthMetric, List<Pair<Long, Double>>>()
        for (metric in sortedMetrics) {
            val dateMap = metricByDate[metric] ?: continue
            val stats = runningStats[metric] ?: continue
            if (stats.count < MINIMUM_DAYS) continue
            zSeriesByMetric[metric] = dateMap.entries
                .map { (d, v) -> d to stats.zScore(v) }
                .sortedBy { it.first }
        }

        // Build vectors day-by-day (most recent first, reversed at end).
        val vectors = mutableListOf<DailyFeatureVector>()

        for (offset in 0 until totalDays) {
            val dayMillis = today - offset.toLong() * DAY_MS
            cal.timeInMillis = dayMillis

            val features = mutableMapOf<FeatureKey, Double>()
            var hasAnyData = false

            for (metric in sortedMetrics) {
                val dateMap = metricByDate[metric] ?: continue
                val stats = runningStats[metric] ?: continue
                if (stats.count < MINIMUM_DAYS) continue

                val rawValue = dateMap[dayMillis]

                // Missingness
                if (rawValue == null) {
                    features[FeatureKey(metric, FeatureType.MISSINGNESS)] = 1.0
                    for (ft in FeatureType.entries) {
                        if (ft != FeatureType.MISSINGNESS) {
                            features[FeatureKey(metric, ft)] = FeatureKey.MISSING_SENTINEL
                        }
                    }
                    continue
                }

                hasAnyData = true
                val value = rawValue
                val z = stats.zScore(value)

                features[FeatureKey(metric, FeatureType.MISSINGNESS)] = 0.0
                features[FeatureKey(metric, FeatureType.RAW)] = z

                // Rate of change (day-over-day).
                val prevDate = dayMillis - DAY_MS
                val prevValue = dateMap[prevDate]
                features[FeatureKey(metric, FeatureType.RATE_OF_CHANGE)] =
                    if (prevValue != null) z - stats.zScore(prevValue) else 0.0

                // Acceleration (2nd derivative).
                val prev2Date = dayMillis - 2 * DAY_MS
                val prev1Val = prevValue
                val prev2Val = dateMap[prev2Date]
                if (prev1Val != null && prev2Val != null && stats.count >= 3) {
                    val z1 = stats.zScore(prev1Val)
                    val z2 = stats.zScore(prev2Val)
                    features[FeatureKey(metric, FeatureType.ACCELERATION)] = (z - z1) - (z1 - z2)
                } else {
                    features[FeatureKey(metric, FeatureType.ACCELERATION)] = FeatureKey.MISSING_SENTINEL
                }

                // Rolling volatilities.
                val vol7Vals = collectRecentZScores(dateMap, stats, dayMillis, 7)
                val vol14Vals = collectRecentZScores(dateMap, stats, dayMillis, 14)
                val vol28Vals = collectRecentZScores(dateMap, stats, dayMillis, 28)

                features[FeatureKey(metric, FeatureType.VOLATILITY_7)] =
                    if (vol7Vals.size >= 3) stdDev(vol7Vals) else 0.0

                features[FeatureKey(metric, FeatureType.VOLATILITY_14)] =
                    if (stats.count >= 14 && vol14Vals.size >= 5) stdDev(vol14Vals)
                    else FeatureKey.MISSING_SENTINEL

                features[FeatureKey(metric, FeatureType.VOLATILITY_28)] =
                    if (stats.count >= 28 && vol28Vals.size >= 10) stdDev(vol28Vals)
                    else FeatureKey.MISSING_SENTINEL

                // Lag features.
                for ((lagDays, lagType) in LAG_CONFIGS) {
                    val lagDate = dayMillis - lagDays.toLong() * DAY_MS
                    val lagVal = dateMap[lagDate]
                    features[FeatureKey(metric, lagType)] =
                        if (lagVal != null) stats.zScore(lagVal) else FeatureKey.MISSING_SENTINEL
                }

                // Deviation from baseline.
                val baseline = baselines[metric]
                features[FeatureKey(metric, FeatureType.DEVIATION_BASELINE)] =
                    if (baseline != null && baseline.standardDeviation > 0) {
                        (value - baseline.mean) / baseline.standardDeviation
                    } else {
                        z
                    }

                // Shannon entropy (7-day window).
                features[FeatureKey(metric, FeatureType.ENTROPY)] =
                    if (stats.count >= 7 && vol7Vals.size >= 7) shannonEntropy(vol7Vals)
                    else FeatureKey.MISSING_SENTINEL

                // Periodicity strength.
                val zSeries = zSeriesByMetric[metric]
                if (stats.count >= 14 && zSeries != null && zSeries.size >= 14) {
                    val zVals = zSeries.map { it.second }
                    var maxAbsR = 0.0
                    for (lag in PERIODICITY_LAGS) {
                        if (lag >= zVals.size) continue
                        maxAbsR = max(maxAbsR, abs(autocorrelation(zVals, lag)))
                    }
                    features[FeatureKey(metric, FeatureType.PERIODICITY_STRENGTH)] = maxAbsR
                } else {
                    features[FeatureKey(metric, FeatureType.PERIODICITY_STRENGTH)] = FeatureKey.MISSING_SENTINEL
                }

                // Weekday / weekend offset.
                val wdS = weekdayStats[metric]
                features[FeatureKey(metric, FeatureType.WEEKDAY_OFFSET)] =
                    if (wdS != null && wdS.count >= 3 && stats.stdDev > 0) {
                        (wdS.mean - stats.mean) / stats.stdDev
                    } else {
                        FeatureKey.MISSING_SENTINEL
                    }

                val weS = weekendStats[metric]
                features[FeatureKey(metric, FeatureType.WEEKEND_OFFSET)] =
                    if (weS != null && weS.count >= 2 && stats.stdDev > 0) {
                        (weS.mean - stats.mean) / stats.stdDev
                    } else {
                        FeatureKey.MISSING_SENTINEL
                    }
            }

            if (!hasAnyData) continue

            val context = ContextFeatures.from(dayMillis)
            vectors.add(DailyFeatureVector(date = dayMillis, features = features, context = context))
        }

        // Return sorted oldest-first.
        vectors.sortBy { it.date }
        return vectors
    }

    /**
     * Incremental update with a single new observation (daily update path).
     */
    fun updateIncremental(metric: HealthMetric, newValue: Double) {
        val state = runningStats.getOrPut(metric) { WelfordState() }
        state.update(newValue)
    }

    // -- Private helpers ----------------------------------------------------

    private fun collectRecentZScores(
        dateMap: Map<Long, Double>,
        stats: WelfordState,
        dayMillis: Long,
        windowDays: Int,
    ): List<Double> {
        val result = ArrayList<Double>(windowDays)
        for (d in 0 until windowDays) {
            val pastDate = dayMillis - d.toLong() * DAY_MS
            val v = dateMap[pastDate] ?: continue
            result.add(stats.zScore(v))
        }
        return result
    }

    /**
     * Shannon entropy normalised to [0, 1] using adaptive bin count.
     */
    private fun shannonEntropy(zScores: List<Double>): Double {
        val binCount = adaptiveBinCount(zScores.size)
        val binWidth = (ENTROPY_Z_MAX - ENTROPY_Z_MIN) / binCount
        val bins = IntArray(binCount)
        val n = zScores.size
        if (n == 0) return 0.0

        for (z in zScores) {
            val clamped = z.coerceIn(ENTROPY_Z_MIN, ENTROPY_Z_MAX - 1e-9)
            val idx = ((clamped - ENTROPY_Z_MIN) / binWidth).toInt().coerceIn(0, binCount - 1)
            bins[idx]++
        }

        var entropy = 0.0
        val nDouble = n.toDouble()
        for (count in bins) {
            if (count == 0) continue
            val p = count.toDouble() / nDouble
            entropy -= p * ln(p)
        }
        val maxEntropy = ln(binCount.toDouble())
        return if (maxEntropy > 0) entropy / maxEntropy else 0.0
    }

    /**
     * Autocorrelation of [values] at the given [lag].
     */
    private fun autocorrelation(values: List<Double>, lag: Int): Double {
        val n = values.size
        if (lag >= n || n < 2) return 0.0

        val mean = values.average()
        var numerator = 0.0
        var denominator = 0.0

        for (i in values.indices) {
            val diff = values[i] - mean
            denominator += diff * diff
            if (i + lag < n) {
                numerator += diff * (values[i + lag] - mean)
            }
        }
        return if (denominator > 0) numerator / denominator else 0.0
    }

    private fun stdDev(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.average()
        val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
        return sqrt(variance)
    }

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
