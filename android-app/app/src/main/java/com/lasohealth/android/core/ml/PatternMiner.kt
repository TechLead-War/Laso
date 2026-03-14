package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.log2
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Discovers periodic patterns in health data using autocorrelation and simplified
 * FFT-like frequency decomposition (Fourier power spectrum via Goertzel).
 *
 * Finds cycles the user may not be aware of: 7-day, 14-day, 28-day, seasonal.
 *
 * Minimum 60 days of data required per metric.
 *
 * Ported from iOS `PatternMiner.swift`.
 */
class PatternMiner {

    companion object {
        /** Minimum days of data required. */
        const val MINIMUM_DAYS = 60

        /** Standard lags to check for periodicity. */
        private val STANDARD_LAGS = intArrayOf(7, 14, 28)

        /** Periods to probe via Goertzel algorithm. */
        private val GOERTZEL_PERIODS = doubleArrayOf(
            3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 14.0, 16.0,
            21.0, 28.0, 30.0, 45.0, 60.0, 90.0,
        )
    }

    /** Discovered patterns sorted by strength descending. */
    var patterns: List<DiscoveredPattern> = emptyList()
        private set

    /** Per-metric weekday statistics (dayOfWeek -> mean). */
    var weekdayMeans: Map<HealthMetric, Map<Int, Double>> = emptyMap()
        private set

    /** Whether any patterns have been discovered. */
    val isReady: Boolean get() = patterns.isNotEmpty()

    // -- Mining -----------------------------------------------------------------

    /**
     * Discover periodic patterns across all metrics.
     */
    fun mine(timeSeries: Map<HealthMetric, List<DailySample>>) {
        val allPatterns = mutableListOf<DiscoveredPattern>()
        val allWeekdayMeans = mutableMapOf<HealthMetric, Map<Int, Double>>()
        val cal = Calendar.getInstance()

        for ((metric, samples) in timeSeries) {
            val sorted = samples.sortedBy { it.date }
            if (sorted.size < MINIMUM_DAYS) continue

            val values = sorted.map { it.value }

            // Compute day-of-week means for weekly pattern enrichment.
            val dayBuckets = mutableMapOf<Int, MutableList<Double>>()
            for (sample in sorted) {
                cal.timeInMillis = sample.date
                val weekday = cal.get(Calendar.DAY_OF_WEEK)
                dayBuckets.getOrPut(weekday) { mutableListOf() }.add(sample.value)
            }
            val means = mutableMapOf<Int, Double>()
            for ((day, vals) in dayBuckets) {
                if (vals.size >= 4) means[day] = vals.average()
            }
            allWeekdayMeans[metric] = means

            // Detrend: remove linear trend to isolate cyclical components.
            val detrended = detrend(values)

            // Method 1: Autocorrelation at standard lags.
            allPatterns.addAll(findAutocorrelationPatterns(metric, detrended, values.size, means))

            // Method 2: Goertzel frequency decomposition.
            allPatterns.addAll(findGoertzelPatterns(metric, detrended))
        }

        weekdayMeans = allWeekdayMeans

        // Deduplicate: keep strongest pattern per metric+period.
        patterns = deduplicatePatterns(allPatterns)
    }

    // -- Autocorrelation Analysis -----------------------------------------------

    private fun findAutocorrelationPatterns(
        metric: HealthMetric,
        values: List<Double>,
        totalCount: Int,
        weekdayMeans: Map<Int, Double>,
    ): List<DiscoveredPattern> {
        val results = mutableListOf<DiscoveredPattern>()

        // Bartlett SE with Bonferroni correction for 3 tests.
        val bonferroniZ = 2.39
        val significanceThreshold = bonferroniZ / sqrt(totalCount.toDouble())

        for (lag in STANDARD_LAGS) {
            if (lag >= values.size / 2) continue
            val r = autocorrelation(values, lag)
            if (abs(r) <= significanceThreshold) continue

            val patternType = classifyPeriod(lag)

            var peakDay: Int? = null
            var troughDay: Int? = null

            if (patternType == PatternType.WEEKLY && weekdayMeans.size >= 5) {
                val higherIsBetter = metric.higherIsBetter
                peakDay = if (higherIsBetter) {
                    weekdayMeans.maxByOrNull { it.value }?.key
                } else {
                    weekdayMeans.minByOrNull { it.value }?.key
                }
                troughDay = if (higherIsBetter) {
                    weekdayMeans.minByOrNull { it.value }?.key
                } else {
                    weekdayMeans.maxByOrNull { it.value }?.key
                }
            }

            val description = describePattern(metric, lag, abs(r), peakDay, troughDay)

            results.add(
                DiscoveredPattern(
                    metric = metric,
                    patternType = patternType,
                    periodDays = lag,
                    strength = abs(r),
                    description = description,
                    peakDayOfWeek = peakDay,
                    troughDayOfWeek = troughDay,
                ),
            )
        }

        return results
    }

    // -- Goertzel Frequency Analysis --------------------------------------------

    /**
     * Uses the Goertzel algorithm to probe specific frequencies without a full FFT.
     * More efficient than FFT when testing a small number of candidate periods.
     */
    private fun findGoertzelPatterns(
        metric: HealthMetric,
        values: List<Double>,
    ): List<DiscoveredPattern> {
        if (values.size < MINIMUM_DAYS) return emptyList()

        val n = values.size
        val results = mutableListOf<DiscoveredPattern>()

        // Compute power at each candidate period.
        val powers = mutableListOf<Pair<Double, Double>>() // (period, power)
        for (period in GOERTZEL_PERIODS) {
            if (period > n / 2.0) continue
            val frequency = 1.0 / period
            val power = goertzelPower(values, frequency)
            powers.add(period to power)
        }

        if (powers.isEmpty()) return emptyList()

        // Compute mean and std of power for significance testing.
        val allPowers = powers.map { it.second }
        val meanPower = allPowers.average()
        val sdPower = stdDev(allPowers)
        if (sdPower <= 0) return emptyList()

        val threshold = meanPower + 2.0 * sdPower
        val maxPower = allPowers.max()

        for ((period, power) in powers) {
            if (power <= threshold) continue

            val strength = if (maxPower > 0) power / maxPower else 0.0
            if (strength < 0.3) continue

            // Skip if very close to a standard lag (autocorrelation already found it).
            val nearStandard = STANDARD_LAGS.any { abs(it.toDouble() - period) < 2.0 }
            if (nearStandard) continue

            val patternType = classifyPeriod(period.roundToInt())
            val description =
                "${metric.displayName} shows a ${period.roundToInt()}-day cycle (strength: ${(strength * 100).roundToInt()}%)"

            results.add(
                DiscoveredPattern(
                    metric = metric,
                    patternType = patternType,
                    periodDays = period.roundToInt(),
                    strength = strength,
                    description = description,
                ),
            )
        }

        return results
    }

    /**
     * Goertzel algorithm: compute power at a single frequency without full FFT.
     * O(N) per frequency, much cheaper than O(N log N) FFT when probing few frequencies.
     */
    private fun goertzelPower(values: List<Double>, frequency: Double): Double {
        val n = values.size
        val w = 2.0 * PI * frequency
        val coeff = 2.0 * cos(w)
        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0

        for (i in 0 until n) {
            s0 = values[i] + coeff * s1 - s2
            s2 = s1
            s1 = s0
        }

        // Power = |X(k)|^2 / N
        val real = s1 - s2 * cos(w)
        val imag = s2 * sin(w)
        return (real * real + imag * imag) / n
    }

    // -- Helpers ----------------------------------------------------------------

    /** Remove linear trend from time series via OLS. */
    private fun detrend(values: List<Double>): List<Double> {
        val n = values.size
        if (n < 2) return values
        val (slope, intercept) = linearRegression(values)
        return values.mapIndexed { i, v -> v - (slope * i + intercept) }
    }

    /** Simple OLS linear regression returning (slope, intercept). */
    private fun linearRegression(values: List<Double>): Pair<Double, Double> {
        val n = values.size
        if (n < 2) return 0.0 to (values.firstOrNull() ?: 0.0)
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0
        for (i in values.indices) {
            val x = i.toDouble()
            sumX += x
            sumY += values[i]
            sumXY += x * values[i]
            sumX2 += x * x
        }
        val denom = n * sumX2 - sumX * sumX
        if (abs(denom) < 1e-15) return 0.0 to (sumY / n)
        val slope = (n * sumXY - sumX * sumY) / denom
        val intercept = (sumY - slope * sumX) / n
        return slope to intercept
    }

    /** Autocorrelation at the given lag. */
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

    private fun classifyPeriod(days: Int): PatternType = when (days) {
        in 6..8 -> PatternType.WEEKLY
        in 13..15 -> PatternType.BIWEEKLY
        in 26..32 -> PatternType.MONTHLY
        in 80..100 -> PatternType.SEASONAL
        else -> PatternType.CUSTOM
    }

    private fun describePattern(
        metric: HealthMetric,
        lag: Int,
        strength: Double,
        peakDay: Int?,
        troughDay: Int?,
    ): String {
        val strengthLabel = when {
            strength >= 0.7 -> "strong"
            strength >= 0.4 -> "moderate"
            else -> "mild"
        }
        val periodLabel = when (lag) {
            in 6..8 -> "weekly"
            in 13..15 -> "biweekly"
            in 26..32 -> "monthly"
            in 80..100 -> "seasonal (~quarterly)"
            else -> "$lag-day"
        }

        val peakName = peakDay?.let { dayName(it) }
        val troughName = troughDay?.let { dayName(it) }
        if (lag == 7 && peakName != null && troughName != null) {
            return "Your ${metric.displayName} follows a $strengthLabel $periodLabel cycle — peaks on ${peakName}s, dips on ${troughName}s"
        }
        return "Your ${metric.displayName} shows a $strengthLabel $periodLabel pattern (r=${"%.2f".format(strength)})"
    }

    /** Deduplicate patterns: keep strongest per metric + approximate period. */
    private fun deduplicatePatterns(patterns: List<DiscoveredPattern>): List<DiscoveredPattern> {
        val best = mutableMapOf<String, DiscoveredPattern>()
        for (pattern in patterns) {
            val periodBucket = (pattern.periodDays / 3) * 3
            val key = "${pattern.metric.name}_$periodBucket"
            val existing = best[key]
            if (existing == null || pattern.strength > existing.strength) {
                best[key] = pattern
            }
        }
        return best.values.sortedByDescending { it.strength }
    }

    /** Get patterns for a specific metric. */
    fun patternsFor(metric: HealthMetric): List<DiscoveredPattern> =
        patterns.filter { it.metric == metric }

    /** Get the strongest patterns across all metrics. */
    fun topPatterns(count: Int = 5): List<DiscoveredPattern> =
        patterns.take(count)

    private fun stdDev(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.average()
        val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
        return sqrt(variance)
    }

    private fun dayName(weekday: Int): String? = when (weekday) {
        1 -> "Sunday"
        2 -> "Monday"
        3 -> "Tuesday"
        4 -> "Wednesday"
        5 -> "Thursday"
        6 -> "Friday"
        7 -> "Saturday"
        else -> null
    }
}
