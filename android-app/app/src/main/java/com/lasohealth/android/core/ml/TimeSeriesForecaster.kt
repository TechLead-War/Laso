package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Double exponential smoothing (Holt-Winters additive-trend, multiplicative-seasonal)
 * forecaster with trend damping and multi-horizon confidence intervals.
 *
 * Weekly (period = 7) seasonality is always active. If 60+ days of data are
 * available, monthly (period = 30) seasonality is also estimated.
 *
 * Ported from iOS `TimeSeriesForecaster.swift`.
 */
class TimeSeriesForecaster {

    companion object {
        /** Minimum days of data to enable forecasting. */
        const val MINIMUM_DAYS = 21
        /** Minimum days to activate monthly seasonality. */
        private const val MONTHLY_MINIMUM_DAYS = 60
        private const val WEEKLY_PERIOD = 7
        private const val MONTHLY_PERIOD = 30
    }

    // -- Holt-Winters per-metric state --------------------------------------

    private data class HoltWintersState(
        var level: Double,
        var trend: Double,
        var seasonal: DoubleArray,               // length = WEEKLY_PERIOD
        var alpha: Double,                        // level smoothing
        var beta: Double,                         // trend smoothing
        var gamma: Double,                        // weekly seasonal smoothing
        var residualStdDev: Double,
        var fittedCount: Int,
        var monthlySeasonals: DoubleArray? = null, // length = MONTHLY_PERIOD, null when single-season
        var dampingFactor: Double = 0.9,           // phi for damped trend
        var gamma2: Double? = null,                // monthly seasonal smoothing
    ) {
        /** One-step-ahead (or h-step) point forecast. */
        fun forecast(stepsAhead: Int = 1): Double {
            val weeklyIdx = stepsAhead % seasonal.size
            val weeklySeasonal = seasonal[weeklyIdx]
            val dampedTrend = dampedTrendCumulative(stepsAhead)
            val base = (level + dampedTrend) * weeklySeasonal

            val monthly = monthlySeasonals
            return if (monthly != null && monthly.isNotEmpty()) {
                base * monthly[stepsAhead % monthly.size]
            } else {
                base
            }
        }

        /**
         * Prediction interval half-width at the given horizon using a simplified
         * ETS(A,Ad,M) variance propagation model (Hyndman et al. 2008, section 6.5).
         */
        fun confidenceInterval(stepsAhead: Int, zScore: Double = 1.96): Double {
            val h = stepsAhead
            if (h <= 0) return 0.0

            val a = (0.01).coerceAtLeast((0.95.pow(1.0 / max(1.0, residualStdDev))).let { 1.0 - it }.coerceAtMost(0.3))
            val b = a * 0.1
            val phi = dampingFactor

            var cumulativeVariance = 0.0
            for (j in 0 until h) {
                var cj = 1.0 + j * a
                if (phi < 1.0 && phi > 0) {
                    val phiSum = phi * (1.0 - phi.pow(j + 1.0)) / (1.0 - phi)
                    cj += a * b * phiSum
                }
                cumulativeVariance += cj * cj
            }
            return zScore * residualStdDev * sqrt(cumulativeVariance)
        }

        /** Cumulative damped trend over [h] steps: sum_{i=1..h} phi^i * trend. */
        private fun dampedTrendCumulative(h: Int): Double {
            if (dampingFactor == 1.0) return trend * h
            val phi = dampingFactor
            val phiSum = phi * (1.0 - phi.pow(h.toDouble())) / (1.0 - phi)
            return phiSum * trend
        }

        // equals/hashCode generated for DoubleArray fields are identity-based;
        // these are mutable internal state so that is acceptable.
    }

    /** Trained states keyed by metric. */
    private val states = mutableMapOf<HealthMetric, HoltWintersState>()

    /** Whether at least one metric has been trained. */
    val isReady: Boolean get() = states.isNotEmpty()

    // -- Training -----------------------------------------------------------

    /**
     * Fit a Holt-Winters model for a single metric from its daily samples.
     *
     * Requires at least [MINIMUM_DAYS] samples. Performs a grid search over
     * smoothing parameters and damping factors, selecting the combination that
     * minimises MAE on a one-step-ahead walk-forward evaluation.
     */
    fun train(metric: HealthMetric, samples: List<DailySample>) {
        val values = samples.sortedBy { it.date }.map { it.value }
        if (values.size < MINIMUM_DAYS) return

        val doubleSeasonal = values.size >= MONTHLY_MINIMUM_DAYS
        states[metric] = gridSearchFit(values, doubleSeasonal)
    }

    /**
     * Convenience: train all metrics that have enough data.
     */
    fun train(samplesByMetric: Map<HealthMetric, List<DailySample>>) {
        for ((metric, samples) in samplesByMetric) {
            train(metric, samples)
        }
    }

    // -- Forecasting --------------------------------------------------------

    /**
     * Multi-horizon forecast for a metric.
     *
     * @param metric   Target metric (must have been [train]ed).
     * @param horizons Forecast horizons in days (default: 1, 3, 7).
     * @return [MultiHorizonForecast] or `null` if the metric has not been trained.
     */
    fun forecast(
        metric: HealthMetric,
        horizons: List<Int> = listOf(1, 3, 7),
    ): MultiHorizonForecast? {
        val state = states[metric] ?: return null

        val predictions = horizons.associateWith { h ->
            val value = state.forecast(h)
            val ci = state.confidenceInterval(h)
            MLPrediction(
                metric = metric,
                predictedValue = value,
                confidence = confidenceFromCI(ci, state.residualStdDev),
                horizon = h,
            )
        }

        return MultiHorizonForecast(metric = metric, forecasts = predictions)
    }

    /**
     * Single-horizon forecast returning point value and CI half-width.
     */
    fun forecast(metric: HealthMetric, stepsAhead: Int = 1): Pair<Double, Double>? {
        val state = states[metric] ?: return null
        return state.forecast(stepsAhead) to state.confidenceInterval(stepsAhead)
    }

    // -- Incremental update --------------------------------------------------

    /**
     * Lightweight daily update with one new observation (no grid search).
     *
     * @param metric     The metric being updated.
     * @param newValue   Observed value for today.
     * @param dayOfWeek  0-indexed day of the week (0 = Sunday .. 6 = Saturday).
     */
    fun update(metric: HealthMetric, newValue: Double, dayOfWeek: Int) {
        val state = states[metric] ?: return
        val weeklyIdx = dayOfWeek % WEEKLY_PERIOD
        val oldWeekly = state.seasonal[weeklyIdx]
        if (oldWeekly == 0.0 || !newValue.isFinite()) return

        val predicted = state.forecast(1)
        val residual = newValue - predicted

        val monthlyFactor = state.monthlySeasonals?.let { it[state.fittedCount % MONTHLY_PERIOD] } ?: 1.0
        val combined = oldWeekly * monthlyFactor
        if (combined == 0.0) return

        val newLevel = state.alpha * (newValue / combined) +
            (1 - state.alpha) * (state.level + state.dampingFactor * state.trend)
        if (!newLevel.isFinite() || newLevel == 0.0) return

        val newTrend = state.beta * (newLevel - state.level) +
            (1 - state.beta) * state.dampingFactor * state.trend
        if (!newTrend.isFinite()) return

        val newWeekly = state.gamma * (newValue / (newLevel * monthlyFactor)) +
            (1 - state.gamma) * oldWeekly
        if (!newWeekly.isFinite()) return

        state.level = newLevel
        state.trend = newTrend
        state.seasonal[weeklyIdx] = newWeekly

        // Monthly seasonal update.
        state.monthlySeasonals?.let { monthly ->
            state.gamma2?.let { g2 ->
                val mIdx = state.fittedCount % MONTHLY_PERIOD
                val denom = newLevel * newWeekly
                if (abs(denom) > 0.001) {
                    val newMonthly = g2 * (newValue / denom) + (1 - g2) * monthly[mIdx]
                    if (newMonthly.isFinite()) {
                        monthly[mIdx] = newMonthly
                    }
                }
            }
        }

        state.fittedCount++

        // Exponentially smooth residual std dev.
        val residualAlpha = 0.1
        state.residualStdDev = (1 - residualAlpha) * state.residualStdDev + residualAlpha * abs(residual)
    }

    // -- Grid search --------------------------------------------------------

    private fun gridSearchFit(values: List<Double>, doubleSeasonal: Boolean): HoltWintersState {
        val alphas = doubleArrayOf(0.05, 0.1, 0.2, 0.3, 0.5)
        val betas = doubleArrayOf(0.005, 0.01, 0.05, 0.1)
        val gamma1s = doubleArrayOf(0.05, 0.1, 0.3, 0.5)
        val phis = doubleArrayOf(0.8, 0.9, 0.98, 1.0)
        val gamma2s = if (doubleSeasonal) doubleArrayOf(0.05, 0.1, 0.3) else doubleArrayOf(0.0)

        var bestState: HoltWintersState? = null
        var bestMAE = Double.MAX_VALUE

        for (alpha in alphas) {
            for (beta in betas) {
                for (gamma1 in gamma1s) {
                    for (phi in phis) {
                        for (g2 in gamma2s) {
                            val useMonthly = doubleSeasonal && g2 > 0
                            val state = fitWithParams(values, alpha, beta, gamma1, if (useMonthly) g2 else null, phi, useMonthly)
                            val mae = computeMAE(values, state, useMonthly)
                            if (mae < bestMAE) {
                                bestMAE = mae
                                bestState = state
                            }
                        }
                    }
                }
            }
        }

        return bestState ?: initState(values, doubleSeasonal)
    }

    private fun fitWithParams(
        values: List<Double>,
        alpha: Double,
        beta: Double,
        gamma1: Double,
        gamma2: Double?,
        phi: Double,
        doubleSeasonal: Boolean,
    ): HoltWintersState {
        val state = initState(values, doubleSeasonal).copy(
            alpha = alpha,
            beta = beta,
            gamma = gamma1,
            gamma2 = gamma2,
            dampingFactor = phi,
        )

        val startIdx = if (doubleSeasonal) MONTHLY_PERIOD else WEEKLY_PERIOD
        val residuals = mutableListOf<Double>()

        for (i in startIdx until values.size) {
            val weeklyIdx = i % WEEKLY_PERIOD
            val oldWeekly = state.seasonal[weeklyIdx]
            if (oldWeekly == 0.0) continue

            val oldMonthly = if (doubleSeasonal) {
                state.monthlySeasonals?.get(i % MONTHLY_PERIOD) ?: 1.0
            } else 1.0

            val combined = oldWeekly * oldMonthly
            if (combined == 0.0) continue

            val predicted = (state.level + phi * state.trend) * combined
            residuals.add(values[i] - predicted)

            val newLevel = alpha * (values[i] / combined) + (1 - alpha) * (state.level + phi * state.trend)
            val newTrend = beta * (newLevel - state.level) + (1 - beta) * phi * state.trend

            val weeklyDenom = newLevel * oldMonthly
            val newWeekly = if (abs(weeklyDenom) > 0.001) {
                gamma1 * (values[i] / weeklyDenom) + (1 - gamma1) * oldWeekly
            } else oldWeekly

            if (doubleSeasonal) {
                state.monthlySeasonals?.let { monthly ->
                    gamma2?.let { g2 ->
                        val mIdx = i % MONTHLY_PERIOD
                        val denom = newLevel * newWeekly
                        if (abs(denom) > 0.001) {
                            val nm = g2 * (values[i] / denom) + (1 - g2) * monthly[mIdx]
                            if (nm.isFinite()) monthly[mIdx] = nm
                        }
                    }
                }
            }

            state.level = newLevel
            state.trend = newTrend
            state.seasonal[weeklyIdx] = newWeekly
        }

        state.fittedCount = values.size
        if (residuals.isNotEmpty()) {
            state.residualStdDev = welfordStdDev(residuals)
        }
        return state
    }

    private fun computeMAE(values: List<Double>, state: HoltWintersState, doubleSeasonal: Boolean): Double {
        val startIdx = if (doubleSeasonal) MONTHLY_PERIOD else WEEKLY_PERIOD
        val s = state.copy(
            seasonal = state.seasonal.copyOf(),
            monthlySeasonals = state.monthlySeasonals?.copyOf(),
        )

        var totalAbsErr = 0.0
        var count = 0

        for (i in startIdx until values.size) {
            val weeklyIdx = i % WEEKLY_PERIOD
            val wS = s.seasonal[weeklyIdx]
            val mS = if (doubleSeasonal) s.monthlySeasonals?.get(i % MONTHLY_PERIOD) ?: 1.0 else 1.0
            val predicted = (s.level + s.dampingFactor * s.trend) * wS * mS
            totalAbsErr += abs(values[i] - predicted)
            count++

            val combined = wS * mS
            if (abs(combined) < 0.001) continue

            val newLevel = s.alpha * (values[i] / combined) + (1 - s.alpha) * (s.level + s.dampingFactor * s.trend)
            val newTrend = s.beta * (newLevel - s.level) + (1 - s.beta) * s.dampingFactor * s.trend
            val weeklyDenom = newLevel * mS
            if (abs(weeklyDenom) > 0.001) {
                s.seasonal[weeklyIdx] = s.gamma * (values[i] / weeklyDenom) + (1 - s.gamma) * wS
            }

            if (doubleSeasonal) {
                s.monthlySeasonals?.let { monthly ->
                    s.gamma2?.let { g2 ->
                        val mIdx = i % MONTHLY_PERIOD
                        val denom = newLevel * s.seasonal[weeklyIdx]
                        if (abs(denom) > 0.001) {
                            val nm = g2 * (values[i] / denom) + (1 - g2) * monthly[mIdx]
                            if (nm.isFinite()) monthly[mIdx] = nm
                        }
                    }
                }
            }

            s.level = newLevel
            s.trend = newTrend
        }

        return if (count > 0) totalAbsErr / count else Double.MAX_VALUE
    }

    // -- State initialisation -----------------------------------------------

    private fun initState(values: List<Double>, doubleSeasonal: Boolean): HoltWintersState {
        val firstWeek = values.take(WEEKLY_PERIOD)
        val level = firstWeek.average()

        val trend = if (values.size >= 2 * WEEKLY_PERIOD) {
            val secondMean = values.subList(WEEKLY_PERIOD, 2 * WEEKLY_PERIOD).average()
            (secondMean - level) / WEEKLY_PERIOD
        } else 0.0

        // Weekly seasonal factors.
        val weeklySeasonal = DoubleArray(WEEKLY_PERIOD) { 1.0 }
        if (level > 0) {
            val completeWeeks = values.size / WEEKLY_PERIOD
            if (completeWeeks >= 1) {
                for (dow in 0 until WEEKLY_PERIOD) {
                    var sum = 0.0
                    var cnt = 0
                    for (wk in 0 until completeWeeks) {
                        val idx = wk * WEEKLY_PERIOD + dow
                        if (idx < values.size) { sum += values[idx]; cnt++ }
                    }
                    if (cnt > 0) weeklySeasonal[dow] = (sum / cnt) / level
                }
            } else {
                for (i in 0 until WEEKLY_PERIOD) {
                    if (i < values.size) weeklySeasonal[i] = values[i] / level
                }
            }
        }

        // Monthly seasonal factors (optional).
        var monthlySeasonals: DoubleArray? = null
        var gamma2: Double? = null
        if (doubleSeasonal && values.size >= MONTHLY_PERIOD) {
            val monthly = DoubleArray(MONTHLY_PERIOD) { 1.0 }
            if (level > 0) {
                val completeMonths = values.size / MONTHLY_PERIOD
                if (completeMonths >= 1) {
                    for (dom in 0 until MONTHLY_PERIOD) {
                        var sum = 0.0
                        var cnt = 0
                        for (m in 0 until completeMonths) {
                            val idx = m * MONTHLY_PERIOD + dom
                            if (idx < values.size) { sum += values[idx]; cnt++ }
                        }
                        if (cnt > 0) {
                            val wf = weeklySeasonal[dom % WEEKLY_PERIOD]
                            if (wf > 0) monthly[dom] = ((sum / cnt) / level) / wf
                        }
                    }
                }
            }
            // Normalise so mean == 1.0.
            val mMean = monthly.average()
            if (mMean > 0) for (i in monthly.indices) monthly[i] /= mMean
            monthlySeasonals = monthly
            gamma2 = 0.1
        }

        val residualEstimate = if (values.size > 1) {
            welfordStdDev(values) * 0.3
        } else 0.0

        return HoltWintersState(
            level = level,
            trend = trend,
            seasonal = weeklySeasonal,
            alpha = 0.3,
            beta = 0.1,
            gamma = 0.3,
            residualStdDev = residualEstimate,
            fittedCount = 0,
            monthlySeasonals = monthlySeasonals,
            dampingFactor = 0.9,
            gamma2 = gamma2,
        )
    }

    // -- Helpers ------------------------------------------------------------

    /** Welford single-pass standard deviation. */
    private fun welfordStdDev(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        var mean = 0.0
        var m2 = 0.0
        for ((i, v) in values.withIndex()) {
            val n = i + 1
            val delta = v - mean
            mean += delta / n
            m2 += delta * (v - mean)
        }
        return sqrt(m2 / values.size)
    }

    /** Map CI half-width to a [0, 1] confidence value (tighter CI = higher confidence). */
    private fun confidenceFromCI(ci: Double, baseStdDev: Double): Double {
        if (baseStdDev <= 0) return 0.5
        val ratio = ci / baseStdDev
        // Sigmoid-like mapping: ratio near 0 -> confidence ~1, ratio large -> ~0.
        return (1.0 / (1.0 + ratio)).coerceIn(0.0, 1.0)
    }
}
