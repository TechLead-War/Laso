package com.lasohealth.android.core.ml

import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Gaussian Mixture Model clustering on daily feature vectors to identify distinct health states,
 * with an HMM layer on top for temporally coherent state assignments.
 *
 * - **GMM**: EM algorithm with diagonal covariance and BIC model selection (k=2..7).
 * - **HMM**: Treats GMM posteriors as emissions, learns Laplace-smoothed transition dynamics.
 *   Viterbi decoding for MAP state sequence, forward-backward for posterior smoothing.
 *
 * Minimum 60 days of data required.
 *
 * Ported from iOS `HealthStateClassifier.swift`.
 */
class HealthStateClassifier {

    companion object {
        /** Minimum days of data required. */
        const val MINIMUM_DAYS = 60

        /** Range of k values to try. */
        private val K_RANGE = 2..7
        /** EM convergence threshold. */
        private const val EM_TOLERANCE = 1e-6
        /** Maximum EM iterations. */
        private const val MAX_EM_ITERATIONS = 100
        /** Minimum variance floor. */
        private const val MIN_VARIANCE_FLOOR = 1e-6
    }

    // -- State ------------------------------------------------------------------

    /** Current health state. */
    var currentState: HealthState? = null
        private set

    /** All identified states. */
    var states: List<HealthState> = emptyList()
        private set

    /** State transition matrix: stateLabel -> (nextLabel -> probability). */
    var transitionMatrix: Map<String, Map<String, Double>> = emptyMap()
        private set

    /** State history: (date, stateLabel). */
    var stateHistory: List<Pair<Long, String>> = emptyList()
        private set

    /** Whether the classifier has been trained. */
    val isReady: Boolean get() = states.isNotEmpty()

    // GMM parameters.
    private var means: Array<DoubleArray> = emptyArray()       // k x d
    private var variances: Array<DoubleArray> = emptyArray()   // k x d (diagonal)
    private var mixingWeights: DoubleArray = doubleArrayOf()  // k
    private var numComponents: Int = 0
    private var trainedKeys: List<FeatureKey> = emptyList()

    // HMM parameters.
    private var hmmTransitionMatrix: Array<DoubleArray> = emptyArray() // k x k
    private var hmmInitialProbs: DoubleArray = doubleArrayOf()          // k

    // -- Training ---------------------------------------------------------------

    /**
     * Classify health states from daily feature vectors.
     */
    fun classify(
        vectors: List<DailyFeatureVector>,
        orderedKeys: List<FeatureKey>,
    ) {
        if (vectors.size < MINIMUM_DAYS) return

        trainedKeys = orderedKeys
        val dim = orderedKeys.size
        if (dim == 0) return

        // Convert to arrays, replacing missing sentinel with 0.
        val dataArrays = vectors.map { v ->
            val arr = v.toArray(orderedKeys)
            DoubleArray(arr.size) { i ->
                if (arr[i] == FeatureKey.MISSING_SENTINEL) 0.0 else arr[i]
            }
        }

        // BIC model selection: try k=2..7, pick lowest BIC.
        var bestK = 2
        var bestBIC = Double.MAX_VALUE
        var bestMeans: Array<DoubleArray> = emptyArray()
        var bestVariances: Array<DoubleArray> = emptyArray()
        var bestWeights: DoubleArray = doubleArrayOf()
        var bestPosteriors: Array<DoubleArray> = emptyArray()

        for (k in K_RANGE) {
            if (k > vectors.size / 5) break // Need at least 5 samples per component.

            val result = fitGMM(dataArrays, k, dim)
            if (result != null && result.bic < bestBIC) {
                bestBIC = result.bic
                bestK = k
                bestMeans = result.means
                bestVariances = result.variances
                bestWeights = result.weights
                bestPosteriors = result.posteriors
            }
        }

        if (bestMeans.isEmpty()) return

        numComponents = bestK
        means = bestMeans
        variances = bestVariances
        mixingWeights = bestWeights

        // HMM: learn transition matrix from GMM posteriors.
        learnHMMTransitions(bestPosteriors)

        // Viterbi decoding for MAP state sequence.
        val stateSequence = viterbiDecode(bestPosteriors)

        // Build HealthState objects.
        buildStates(orderedKeys, dim)

        // Build state history.
        stateHistory = vectors.mapIndexed { i, v ->
            val stateIdx = stateSequence[i]
            v.date to (if (stateIdx < states.size) states[stateIdx].label else "Unknown")
        }

        // Set current state.
        if (stateSequence.isNotEmpty() && stateSequence.last() < states.size) {
            currentState = states[stateSequence.last()]
        }
    }

    /**
     * Produce HMM-smoothed state history using forward-backward.
     */
    fun smoothedStates(vectors: List<DailyFeatureVector>): List<SmoothedHealthState> {
        if (states.isEmpty() || vectors.size < MINIMUM_DAYS) return emptyList()

        val dataArrays = vectors.map { v ->
            val arr = v.toArray(trainedKeys)
            DoubleArray(arr.size) { i ->
                if (arr[i] == FeatureKey.MISSING_SENTINEL) 0.0 else arr[i]
            }
        }

        // Compute GMM posteriors.
        val posteriors = computePosteriors(dataArrays)
        if (posteriors.isEmpty()) return emptyList()

        // Forward-backward smoothing.
        val smoothed = forwardBackward(posteriors)

        val result = mutableListOf<SmoothedHealthState>()
        var prevStateIdx = -1
        var daysSinceTransition = 0

        for (i in vectors.indices) {
            val statePosteriors = smoothed[i]
            val bestIdx = statePosteriors.indices.maxByOrNull { statePosteriors[it] } ?: 0
            val bestState = if (bestIdx < states.size) states[bestIdx] else continue

            val isTransition = bestIdx != prevStateIdx && prevStateIdx >= 0
            if (isTransition) daysSinceTransition = 0 else daysSinceTransition++

            val transitionProb = if (prevStateIdx >= 0 && prevStateIdx < numComponents) {
                hmmTransitionMatrix[prevStateIdx][bestIdx]
            } else {
                0.0
            }

            result.add(
                SmoothedHealthState(
                    state = bestState,
                    confidence = statePosteriors[bestIdx],
                    transitionProbability = transitionProb,
                    date = vectors[i].date,
                    isTransitionDay = isTransition,
                    daysSinceTransition = daysSinceTransition,
                ),
            )
            prevStateIdx = bestIdx
        }

        return result
    }

    // -- GMM Fitting (EM) -------------------------------------------------------

    private data class GMMResult(
        val means: Array<DoubleArray>,
        val variances: Array<DoubleArray>,
        val weights: DoubleArray,
        val posteriors: Array<DoubleArray>,
        val bic: Double,
    )

    private fun fitGMM(data: List<DoubleArray>, k: Int, dim: Int): GMMResult? {
        val n = data.size
        if (n < k * 2) return null

        // Initialize means with k-means++ seeding.
        val initMeans = kMeansPlusPlusInit(data, k, dim)
        val initVariances = List(k) { DoubleArray(dim) { 1.0 } }
        val initWeights = DoubleArray(k) { 1.0 / k }

        var currentMeans = Array(k) { initMeans[it].copyOf() }
        var currentVariances = Array(k) { initVariances[it].copyOf() }
        var currentWeights = initWeights.copyOf()
        var posteriors = Array(n) { DoubleArray(k) }
        var prevLogLikelihood = Double.NEGATIVE_INFINITY

        // Compute data variance for variance floor.
        val dataVariance = computeDataVariance(data, dim)
        val varianceFloor = DoubleArray(dim) { i ->
            max(MIN_VARIANCE_FLOOR, dataVariance[i] * 0.01)
        }

        for (iter in 0 until MAX_EM_ITERATIONS) {
            // E-step: compute posteriors.
            var logLikelihood = 0.0

            for (i in 0 until n) {
                val logProbs = DoubleArray(k)
                for (j in 0 until k) {
                    logProbs[j] = ln(max(currentWeights[j], 1e-30)) +
                        diagonalGaussianLogPdf(data[i], currentMeans[j], currentVariances[j])
                }

                // Log-sum-exp for numerical stability.
                val maxLog = logProbs.max()
                val sumExp = logProbs.sumOf { exp(it - maxLog) }
                val logNorm = maxLog + ln(sumExp)
                logLikelihood += logNorm

                for (j in 0 until k) {
                    posteriors[i][j] = exp(logProbs[j] - logNorm)
                }
            }

            // Check convergence.
            if (iter > 0 && abs(logLikelihood - prevLogLikelihood) < EM_TOLERANCE * abs(logLikelihood)) {
                break
            }
            prevLogLikelihood = logLikelihood

            // M-step: update parameters.
            val newMeans = Array(k) { DoubleArray(dim) }
            val newVariances = Array(k) { DoubleArray(dim) }
            val newWeights = DoubleArray(k)

            for (j in 0 until k) {
                var nj = 0.0
                for (i in 0 until n) nj += posteriors[i][j]
                newWeights[j] = max(nj / n, 1e-30)

                if (nj < 1e-10) {
                    newMeans[j] = currentMeans[j].copyOf()
                    newVariances[j] = currentVariances[j].copyOf()
                    continue
                }

                // Weighted mean.
                for (d in 0 until dim) {
                    var sumWeighted = 0.0
                    for (i in 0 until n) sumWeighted += posteriors[i][j] * data[i][d]
                    newMeans[j][d] = sumWeighted / nj
                }

                // Weighted variance.
                for (d in 0 until dim) {
                    var sumWeightedVar = 0.0
                    for (i in 0 until n) {
                        val diff = data[i][d] - newMeans[j][d]
                        sumWeightedVar += posteriors[i][j] * diff * diff
                    }
                    newVariances[j][d] = max(sumWeightedVar / nj, varianceFloor[d])
                }
            }

            currentMeans = newMeans
            currentVariances = newVariances
            currentWeights = newWeights
        }

        // Compute BIC: -2 * logLikelihood + numParams * ln(n).
        val numParams = k * (2 * dim + 1) - 1 // k means (dim each) + k variances (dim each) + k-1 weights
        var finalLL = 0.0
        for (i in 0 until n) {
            val logProbs = DoubleArray(k) { j ->
                ln(max(currentWeights[j], 1e-30)) +
                    diagonalGaussianLogPdf(data[i], currentMeans[j], currentVariances[j])
            }
            val maxLog = logProbs.max()
            finalLL += maxLog + ln(logProbs.sumOf { exp(it - maxLog) })
        }
        val bic = -2.0 * finalLL + numParams * ln(n.toDouble())

        return GMMResult(currentMeans, currentVariances, currentWeights, posteriors, bic)
    }

    // -- k-means++ Initialization -----------------------------------------------

    private fun kMeansPlusPlusInit(data: List<DoubleArray>, k: Int, dim: Int): List<DoubleArray> {
        val centers = mutableListOf<DoubleArray>()
        centers.add(data.random().copyOf())

        for (c in 1 until k) {
            val distances = data.map { point ->
                centers.minOf { center -> squaredDistance(point, center) }
            }
            val totalDist = distances.sum()
            if (totalDist <= 0) {
                centers.add(data.random().copyOf())
                continue
            }

            var target = Math.random() * totalDist
            var idx = 0
            for (i in distances.indices) {
                target -= distances[i]
                if (target <= 0) {
                    idx = i
                    break
                }
            }
            centers.add(data[idx].copyOf())
        }

        return centers
    }

    private fun squaredDistance(a: DoubleArray, b: DoubleArray): Double {
        var sum = 0.0
        for (i in 0 until min(a.size, b.size)) {
            val diff = a[i] - b[i]
            sum += diff * diff
        }
        return sum
    }

    // -- Gaussian PDF -----------------------------------------------------------

    private fun diagonalGaussianLogPdf(x: DoubleArray, mean: DoubleArray, variance: DoubleArray): Double {
        val dim = min(x.size, min(mean.size, variance.size))
        var logPdf = -0.5 * dim * ln(2.0 * PI)
        for (d in 0 until dim) {
            val v = max(variance[d], MIN_VARIANCE_FLOOR)
            val diff = x[d] - mean[d]
            logPdf -= 0.5 * (ln(v) + diff * diff / v)
        }
        return logPdf
    }

    // -- HMM Transition Learning ------------------------------------------------

    private fun learnHMMTransitions(posteriors: Array<DoubleArray>) {
        val k = numComponents
        val n = posteriors.size
        if (n < 2 || k == 0) return

        // Initial state distribution (from first posterior).
        hmmInitialProbs = posteriors[0].copyOf()

        // Transition counts with Laplace smoothing.
        val counts = Array(k) { DoubleArray(k) { 1.0 } } // Laplace prior of 1.

        for (t in 0 until n - 1) {
            val stateT = posteriors[t].indices.maxByOrNull { posteriors[t][it] } ?: 0
            val stateT1 = posteriors[t + 1].indices.maxByOrNull { posteriors[t + 1][it] } ?: 0
            counts[stateT][stateT1] += 1.0
        }

        // Normalize rows.
        hmmTransitionMatrix = Array(k) { i ->
            val rowSum = counts[i].sum()
            DoubleArray(k) { j -> if (rowSum > 0) counts[i][j] / rowSum else 1.0 / k }
        }

        // Build readable transition matrix.
        val labels = (0 until k).map { labelForCluster(it) }
        val matrix = mutableMapOf<String, Map<String, Double>>()
        for (i in 0 until k) {
            val row = mutableMapOf<String, Double>()
            for (j in 0 until k) {
                row[labels[j]] = hmmTransitionMatrix[i][j]
            }
            matrix[labels[i]] = row
        }
        transitionMatrix = matrix
    }

    // -- Viterbi Decoding -------------------------------------------------------

    private fun viterbiDecode(posteriors: Array<DoubleArray>): List<Int> {
        val n = posteriors.size
        val k = numComponents
        if (n == 0 || k == 0) return emptyList()

        // Use MAP assignment per day as a simplified Viterbi when HMM not yet trained.
        if (hmmTransitionMatrix.isEmpty()) {
            return posteriors.map { p -> p.indices.maxByOrNull { p[it] } ?: 0 }
        }

        // Full Viterbi.
        val logDelta = Array(n) { DoubleArray(k) { Double.NEGATIVE_INFINITY } }
        val psi = Array(n) { IntArray(k) }

        // Initialization.
        for (j in 0 until k) {
            logDelta[0][j] = ln(max(hmmInitialProbs[j], 1e-30)) + ln(max(posteriors[0][j], 1e-30))
        }

        // Recursion.
        for (t in 1 until n) {
            for (j in 0 until k) {
                var bestLogProb = Double.NEGATIVE_INFINITY
                var bestPrev = 0
                for (i in 0 until k) {
                    val logProb = logDelta[t - 1][i] + ln(max(hmmTransitionMatrix[i][j], 1e-30))
                    if (logProb > bestLogProb) {
                        bestLogProb = logProb
                        bestPrev = i
                    }
                }
                logDelta[t][j] = bestLogProb + ln(max(posteriors[t][j], 1e-30))
                psi[t][j] = bestPrev
            }
        }

        // Backtrack.
        val path = IntArray(n)
        path[n - 1] = logDelta[n - 1].indices.maxByOrNull { logDelta[n - 1][it] } ?: 0
        for (t in n - 2 downTo 0) {
            path[t] = psi[t + 1][path[t + 1]]
        }

        return path.toList()
    }

    // -- Forward-Backward -------------------------------------------------------

    private fun forwardBackward(posteriors: Array<DoubleArray>): Array<DoubleArray> {
        val n = posteriors.size
        val k = numComponents
        if (n == 0 || k == 0 || hmmTransitionMatrix.isEmpty()) return posteriors

        // Forward pass.
        val alpha = Array(n) { DoubleArray(k) }
        for (j in 0 until k) {
            alpha[0][j] = hmmInitialProbs[j] * max(posteriors[0][j], 1e-30)
        }
        normalizeRow(alpha[0])

        for (t in 1 until n) {
            for (j in 0 until k) {
                var sum = 0.0
                for (i in 0 until k) {
                    sum += alpha[t - 1][i] * hmmTransitionMatrix[i][j]
                }
                alpha[t][j] = sum * max(posteriors[t][j], 1e-30)
            }
            normalizeRow(alpha[t])
        }

        // Backward pass.
        val beta = Array(n) { DoubleArray(k) }
        for (j in 0 until k) beta[n - 1][j] = 1.0

        for (t in n - 2 downTo 0) {
            for (i in 0 until k) {
                var sum = 0.0
                for (j in 0 until k) {
                    sum += hmmTransitionMatrix[i][j] * max(posteriors[t + 1][j], 1e-30) * beta[t + 1][j]
                }
                beta[t][i] = sum
            }
            normalizeRow(beta[t])
        }

        // Smoothed posteriors.
        val smoothed = Array(n) { t ->
            val gamma = DoubleArray(k) { j -> alpha[t][j] * beta[t][j] }
            normalizeRow(gamma)
            gamma
        }

        return smoothed
    }

    private fun normalizeRow(row: DoubleArray) {
        val sum = row.sum()
        if (sum > 0) {
            for (i in row.indices) row[i] /= sum
        }
    }

    private fun computePosteriors(data: List<DoubleArray>): Array<DoubleArray> {
        val n = data.size
        val k = numComponents
        return Array(n) { i ->
            val logProbs = DoubleArray(k) { j ->
                ln(max(mixingWeights[j], 1e-30)) +
                    diagonalGaussianLogPdf(data[i], means[j], variances[j])
            }
            val maxLog = logProbs.max()
            val probs = DoubleArray(k) { j -> exp(logProbs[j] - maxLog) }
            val sum = probs.sum()
            if (sum > 0) DoubleArray(k) { j -> probs[j] / sum } else DoubleArray(k) { 1.0 / k }
        }
    }

    // -- State Building ---------------------------------------------------------

    private fun buildStates(orderedKeys: List<FeatureKey>, dim: Int) {
        val builtStates = mutableListOf<HealthState>()

        for (j in 0 until numComponents) {
            val label = labelForCluster(j)

            // Extract per-metric centroids.
            val metricMeans = mutableMapOf<HealthMetric, Double>()
            val characteristics = mutableListOf<StateCharacteristic>()

            val seenMetrics = mutableSetOf<HealthMetric>()
            for (d in 0 until min(dim, orderedKeys.size)) {
                val key = orderedKeys[d]
                if (key.type == FeatureType.RAW && key.metric !in seenMetrics) {
                    seenMetrics.add(key.metric)
                    val zScore = means[j][d]
                    metricMeans[key.metric] = zScore

                    val level = when {
                        zScore > 0.5 -> CharacteristicLevel.HIGH
                        zScore < -0.5 -> CharacteristicLevel.LOW
                        else -> CharacteristicLevel.NORMAL
                    }
                    characteristics.add(StateCharacteristic(key.metric, level, zScore))
                }
            }

            // Transition probabilities.
            val transProbs = if (hmmTransitionMatrix.isNotEmpty()) {
                val map = mutableMapOf<String, Double>()
                for (next in 0 until numComponents) {
                    map[labelForCluster(next)] = hmmTransitionMatrix[j][next]
                }
                map
            } else {
                emptyMap()
            }

            builtStates.add(
                HealthState(
                    label = label,
                    metrics = metricMeans,
                    probability = mixingWeights[j],
                    characteristics = characteristics,
                    transitionProbabilities = transProbs,
                ),
            )
        }

        states = builtStates
    }

    /** Generate a human-readable label for a cluster based on its centroid characteristics. */
    private fun labelForCluster(index: Int): String {
        if (means.isEmpty() || index >= means.size) return "State ${index + 1}"

        val centroid = means[index]
        val dim = trainedKeys.size

        // Find dominant characteristics.
        var highHRV = false
        var lowHRV = false
        var highActivity = false
        var lowActivity = false
        var goodSleep = false
        var poorSleep = false

        for (d in 0 until min(dim, centroid.size)) {
            val key = trainedKeys[d]
            if (key.type != FeatureType.RAW) continue
            val z = centroid[d]
            when (key.metric) {
                HealthMetric.HEART_RATE_VARIABILITY -> {
                    if (z > 0.5) highHRV = true
                    if (z < -0.5) lowHRV = true
                }
                HealthMetric.ACTIVE_CALORIES, HealthMetric.STEPS -> {
                    if (z > 0.5) highActivity = true
                    if (z < -0.5) lowActivity = true
                }
                HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP -> {
                    if (z > 0.5) goodSleep = true
                    if (z < -0.5) poorSleep = true
                }
                else -> {}
            }
        }

        return when {
            highHRV && highActivity && goodSleep -> "Peak Performance"
            highHRV && goodSleep -> "Well Recovered"
            lowHRV && poorSleep -> "Stressed"
            lowHRV && lowActivity -> "Fatigued"
            highActivity && poorSleep -> "Overreaching"
            lowActivity && goodSleep -> "Resting"
            highActivity -> "Active"
            else -> "State ${index + 1}"
        }
    }

    // -- Helpers ----------------------------------------------------------------

    private fun computeDataVariance(data: List<DoubleArray>, dim: Int): DoubleArray {
        val variance = DoubleArray(dim)
        if (data.isEmpty()) return variance
        val means = DoubleArray(dim)
        for (row in data) {
            for (d in 0 until min(dim, row.size)) means[d] += row[d]
        }
        val n = data.size.toDouble()
        for (d in 0 until dim) means[d] /= n
        for (row in data) {
            for (d in 0 until min(dim, row.size)) {
                val diff = row[d] - means[d]
                variance[d] += diff * diff
            }
        }
        for (d in 0 until dim) variance[d] /= n
        return variance
    }
}
