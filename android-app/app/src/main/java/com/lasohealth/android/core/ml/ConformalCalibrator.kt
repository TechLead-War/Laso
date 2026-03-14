package com.lasohealth.android.core.ml

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

/**
 * Rigorous calibration methods for ML prediction confidence.
 *
 * Provides:
 * - Split conformal prediction intervals
 * - Platt scaling (Newton-Raphson)
 * - Temperature scaling (grid search)
 * - Isotonic regression (Pool Adjacent Violators)
 * - Ensemble disagreement analysis
 * - Calibration diagnostics (ECE, MCE, Brier score, Brier skill)
 * - Rolling coverage tracking
 *
 * Used by [UncertaintyEstimator] and ML components that need well-calibrated
 * probability outputs.
 *
 * Ported from iOS `ConformalCalibrator.swift`.
 */
class ConformalCalibrator {

    // ---------------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------------

    data class CalibrationBin(
        val predictedMean: Double,
        val observedFraction: Double,
        val count: Int,
    ) {
        val gap: Double get() = abs(predictedMean - observedFraction)
    }

    data class CalibrationReport(
        val ece: Double,
        val mce: Double,
        val bins: List<CalibrationBin>,
        val brierScore: Double,
        val brierSkill: Double,
    )

    data class IsotonicStep(
        val threshold: Double,
        val calibrated: Double,
    )

    data class EnsembleUncertaintySummary(
        val mean: Double,
        val std: Double,
        val cv: Double,
        val isHighUncertainty: Boolean,
    )

    // ---------------------------------------------------------------------------
    // Coverage Tracking
    // ---------------------------------------------------------------------------

    private val coverageTracker = mutableListOf<Boolean>()
    private val coverageWindowSize = 100

    // ---------------------------------------------------------------------------
    // Split Conformal Prediction
    // ---------------------------------------------------------------------------

    /**
     * Compute a conformal prediction interval with finite-sample coverage guarantee.
     *
     * @return (lower, upper, actualRecentCoverage)
     */
    fun conformalPredictionInterval(
        calibrationResiduals: List<Double>,
        pointPrediction: Double,
        coverage: Double = 0.90,
    ): Triple<Double, Double, Double> {
        val clampedCoverage = coverage.coerceIn(0.5, 0.99)

        if (calibrationResiduals.isEmpty()) {
            return Triple(pointPrediction, pointPrediction, recentCoverage())
        }

        val sorted = calibrationResiduals.map { abs(it) }.sorted()
        val n = sorted.size

        val quantileRawIndex = ceil((n + 1).toDouble() * clampedCoverage).toInt()
        val quantileRadius = if (quantileRawIndex > n) {
            sorted[n - 1] * 1.1
        } else {
            val safeIndex = (quantileRawIndex - 1).coerceIn(0, n - 1)
            sorted[safeIndex]
        }

        return Triple(
            pointPrediction - quantileRadius,
            pointPrediction + quantileRadius,
            recentCoverage(),
        )
    }

    // ---------------------------------------------------------------------------
    // Platt Scaling
    // ---------------------------------------------------------------------------

    /**
     * Fit Platt scaling parameters (a, b) for P(y=1|s) = 1/(1+exp(a*s+b)).
     *
     * Uses Newton-Raphson with label smoothing.
     *
     * @return (a, b) or null if fitting fails.
     */
    fun plattScale(rawScores: List<Double>, labels: List<Double>): Pair<Double, Double>? {
        val n = rawScores.size
        if (n != labels.size || n < 5) return null

        val nPositive = labels.sumOf { it }
        val nNegative = n - nPositive
        if (nPositive <= 0 || nNegative <= 0) return null

        val tPositive = (nPositive + 1.0) / (nPositive + 2.0)
        val tNegative = 1.0 / (nNegative + 2.0)
        val targets = labels.map { if (it > 0.5) tPositive else tNegative }

        var a = 0.0
        var b = 0.0

        for (iter in 0 until 10) {
            var gradA = 0.0; var gradB = 0.0
            var hessAA = 0.0; var hessAB = 0.0; var hessBB = 0.0

            for (i in 0 until n) {
                val logit = a * rawScores[i] + b
                val p = stableSigmoid(logit)
                val diff = p - targets[i]
                val pq = p * (1.0 - p) + 1e-12

                gradA += diff * rawScores[i]
                gradB += diff
                hessAA += pq * rawScores[i] * rawScores[i]
                hessAB += pq * rawScores[i]
                hessBB += pq
            }

            val det = hessAA * hessBB - hessAB * hessAB
            if (abs(det) < 1e-15) break

            val da = -(hessBB * gradA - hessAB * gradB) / det
            val db = -(hessAA * gradB - hessAB * gradA) / det
            a += da
            b += db

            if (abs(da) < 1e-8 && abs(db) < 1e-8) break
        }

        return a to b
    }

    /**
     * Apply Platt scaling to a raw score.
     * Returns calibrated probability P(y=1|s) = 1/(1+exp(a*s+b)).
     */
    fun calibrate(rawScore: Double, a: Double, b: Double): Double =
        stableSigmoid(a * rawScore + b)

    // ---------------------------------------------------------------------------
    // Temperature Scaling
    // ---------------------------------------------------------------------------

    /**
     * Fit temperature scaling parameter T minimizing NLL on a calibration set.
     * Grid search over T in {0.1, 0.2, ..., 5.0}.
     */
    fun temperatureScale(logits: List<Double>, labels: List<Double>): Double {
        val n = logits.size
        if (n != labels.size || n < 5) return 1.0

        var bestT = 1.0
        var bestNLL = Double.MAX_VALUE

        for (step in 1..50) {
            val t = step * 0.1
            var nll = 0.0
            for (i in 0 until n) {
                val p = stableSigmoid(logits[i] / t)
                val clampedP = p.coerceIn(1e-15, 1.0 - 1e-15)
                nll -= if (labels[i] > 0.5) ln(clampedP) else ln(1.0 - clampedP)
            }
            if (nll < bestNLL) {
                bestNLL = nll
                bestT = t
            }
        }

        return bestT
    }

    /** Apply temperature scaling: P = sigmoid(logit / T). */
    fun calibrateWithTemperature(logit: Double, T: Double): Double =
        stableSigmoid(logit / max(T, 1e-6))

    // ---------------------------------------------------------------------------
    // Isotonic Regression (Pool Adjacent Violators)
    // ---------------------------------------------------------------------------

    /**
     * Fit isotonic regression using the PAV algorithm.
     *
     * Produces a monotone non-decreasing step function mapping raw predicted
     * probabilities to calibrated probabilities.
     */
    fun isotonicCalibrate(predictions: List<Double>, labels: List<Double>): List<IsotonicStep> {
        val n = predictions.size
        if (n != labels.size || n < 2) return emptyList()

        val indices = (0 until n).sortedBy { predictions[it] }
        val sortedPreds = indices.map { predictions[it] }
        val sortedLabels = indices.map { labels[it] }

        // PAV: each block tracks (predSum, labelSum, count).
        data class Block(var predSum: Double, var labelSum: Double, var count: Double) {
            val calibrated: Double get() = if (count > 0) labelSum / count else 0.0
        }

        var blocks = sortedPreds.zip(sortedLabels).map { (p, l) -> Block(p, l, 1.0) }.toMutableList()

        var changed = true
        while (changed) {
            changed = false
            val merged = mutableListOf<Block>()
            for (block in blocks) {
                val last = merged.lastOrNull()
                if (last != null && block.calibrated < last.calibrated) {
                    last.predSum += block.predSum
                    last.labelSum += block.labelSum
                    last.count += block.count
                    changed = true
                } else {
                    merged.add(block)
                }
            }
            blocks = merged
        }

        return blocks.map { block ->
            IsotonicStep(
                threshold = block.predSum / block.count,
                calibrated = block.calibrated.coerceIn(0.0, 1.0),
            )
        }
    }

    /**
     * Apply isotonic calibration using linear interpolation.
     */
    fun applyIsotonic(rawProbability: Double, mapping: List<IsotonicStep>): Double {
        if (mapping.isEmpty()) return rawProbability
        val p = rawProbability.coerceIn(0.0, 1.0)

        if (mapping.size == 1) return mapping[0].calibrated
        if (p <= mapping[0].threshold) return mapping[0].calibrated
        if (p >= mapping.last().threshold) return mapping.last().calibrated

        for (i in 0 until mapping.size - 1) {
            val lower = mapping[i]
            val upper = mapping[i + 1]
            if (p in lower.threshold..upper.threshold) {
                val range = upper.threshold - lower.threshold
                if (range < 1e-15) return (lower.calibrated + upper.calibrated) / 2.0
                val t = (p - lower.threshold) / range
                return lower.calibrated + t * (upper.calibrated - lower.calibrated)
            }
        }

        return mapping.last().calibrated
    }

    // ---------------------------------------------------------------------------
    // Ensemble Disagreement
    // ---------------------------------------------------------------------------

    /**
     * Compute ensemble uncertainty from multiple model predictions.
     */
    fun ensembleUncertainty(predictions: List<Double>): EnsembleUncertaintySummary? {
        if (predictions.size < 2) return null

        val mean = predictions.average()
        val variance = predictions.sumOf { (it - mean) * (it - mean) } / predictions.size
        val std = kotlin.math.sqrt(variance)

        val cv = if (abs(mean) > 1e-9) std / abs(mean)
        else if (std > 1e-9) 1.0 else 0.0

        val isHigh = cv > 0.3 || std > 0.15

        return EnsembleUncertaintySummary(mean, std, cv, isHigh)
    }

    // ---------------------------------------------------------------------------
    // Calibration Diagnostics
    // ---------------------------------------------------------------------------

    /**
     * Compute comprehensive calibration diagnostics: ECE, MCE, Brier, Brier skill.
     */
    fun calibrationDiagnostics(
        predictions: List<Double>,
        labels: List<Double>,
        bins: Int = 10,
    ): CalibrationReport? {
        val n = predictions.size
        if (n != labels.size || n < 10 || bins < 2) return null

        val binWidth = 1.0 / bins
        val calBins = mutableListOf<CalibrationBin>()
        var totalECE = 0.0
        var maxCE = 0.0

        for (b in 0 until bins) {
            val binLower = b * binWidth
            val binUpper = (b + 1) * binWidth

            var predSum = 0.0
            var labelSum = 0.0
            var count = 0

            for (i in 0 until n) {
                val inBin = if (b == bins - 1) {
                    predictions[i] >= binLower && predictions[i] <= binUpper
                } else {
                    predictions[i] >= binLower && predictions[i] < binUpper
                }
                if (inBin) {
                    predSum += predictions[i]
                    labelSum += labels[i]
                    count++
                }
            }

            val predMean = if (count > 0) predSum / count else (binLower + binUpper) / 2.0
            val obsFraction = if (count > 0) labelSum / count else 0.0

            val bin = CalibrationBin(predMean, obsFraction, count)
            calBins.add(bin)

            if (count > 0) {
                totalECE += (count.toDouble() / n) * bin.gap
                maxCE = max(maxCE, bin.gap)
            }
        }

        // Brier score.
        var brierSum = 0.0
        var labelMean = 0.0
        for (i in 0 until n) {
            val diff = predictions[i] - labels[i]
            brierSum += diff * diff
            labelMean += labels[i]
        }
        val brierScore = brierSum / n
        labelMean /= n

        val brierClimatology = labelMean * (1.0 - labelMean)
        val brierSkill = if (brierClimatology > 1e-12) {
            1.0 - brierScore / brierClimatology
        } else {
            if (brierScore < 1e-12) 1.0 else 0.0
        }

        return CalibrationReport(totalECE, maxCE, calBins, brierScore, brierSkill)
    }

    // ---------------------------------------------------------------------------
    // Coverage Tracking
    // ---------------------------------------------------------------------------

    /**
     * Record whether the actual value fell within the predicted interval.
     */
    fun updateCoverage(actual: Double, intervalLower: Double, intervalUpper: Double) {
        val covered = actual in intervalLower..intervalUpper
        coverageTracker.add(covered)
        if (coverageTracker.size > coverageWindowSize) {
            coverageTracker.removeAt(0)
        }
    }

    /** Compute recent empirical coverage rate. */
    fun recentCoverage(window: Int? = null): Double {
        if (coverageTracker.isEmpty()) return 1.0
        val effectiveWindow = min(window ?: coverageTracker.size, coverageTracker.size)
        if (effectiveWindow <= 0) return 1.0
        val recent = coverageTracker.takeLast(effectiveWindow)
        return recent.count { it }.toDouble() / recent.size
    }

    /** Check if coverage has dropped below acceptable threshold. */
    fun isCoverageCriticallyLow(nominalCoverage: Double = 0.90): Boolean {
        val actual = recentCoverage()
        val threshold = nominalCoverage - 0.10
        return coverageTracker.size >= 20 && actual < threshold
    }

    /** Reset coverage tracking state. */
    fun resetCoverageTracker() {
        coverageTracker.clear()
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /** Numerically stable sigmoid: 1 / (1 + exp(-x)). */
    private fun stableSigmoid(x: Double): Double = if (x >= 0) {
        val expNeg = exp(-x)
        1.0 / (1.0 + expNeg)
    } else {
        val expPos = exp(x)
        expPos / (1.0 + expPos)
    }
}
