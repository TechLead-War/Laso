package com.lasohealth.android.core.ml

import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Gradient Boosted Decision Trees for predicting P(bad day tomorrow).
 *
 * Standard algorithm used by XGBoost/LightGBM, implemented in pure Kotlin.
 * Uses histogram-based split finding for efficient tree construction,
 * early stopping on a temporal validation set, and Platt scaling for
 * probability calibration.
 *
 * Minimum 30 days of data required.
 *
 * Ported from iOS `PredictiveScorer.swift`.
 */
class PredictiveScorer {

    companion object {
        /** Minimum days of data required. */
        const val MINIMUM_DAYS = 30
        /** Maximum training samples for confidence scaling. */
        private const val MAX_CONFIDENCE_SAMPLES = 90
        /** Anomaly count threshold for bad-day classification. */
        private const val ANOMALY_COUNT_THRESHOLD = 2
    }

    // -- Hyperparameters --------------------------------------------------------

    private val numTrees = 80
    private val maxDepth = 4
    private val learningRate = 0.1
    private val minSamplesLeaf = 5
    private val subsampleRatio = 0.8
    private val colsampleRatio = 0.8
    private val l2Lambda = 1.0
    private val numBins = 64

    // -- Model State ------------------------------------------------------------

    private var trees: MutableList<DecisionTree> = mutableListOf()
    private var featureKeys: List<FeatureKey> = emptyList()
    private var baseScore: Double = 0.0
    private var trainingCount: Int = 0
    private var featureImportance: MutableMap<Int, Double> = mutableMapOf()

    // Platt calibration parameters.
    private var plattA: Double? = null
    private var plattB: Double? = null

    // Learned bad-day thresholds.
    private var learnedScoreDropThreshold = 10.0
    private var learnedLowScoreThreshold = 60.0

    // Validation metrics.
    var validationAUROC: Double? = null
        private set
    var validationBrierScore: Double? = null
        private set

    /** Current prediction. */
    var currentPrediction: MLPrediction? = null
        private set

    /** Whether the model has been trained. */
    val isReady: Boolean get() = trees.isNotEmpty() && trainingCount >= MINIMUM_DAYS

    // -- Decision Tree ----------------------------------------------------------

    private sealed class TreeNode {
        data class Split(
            val featureIndex: Int,
            val threshold: Double,
            val gain: Double,
            val left: TreeNode,
            val right: TreeNode,
        ) : TreeNode()

        data class Leaf(val value: Double) : TreeNode()
    }

    private data class DecisionTree(val root: TreeNode) {
        fun predict(features: DoubleArray): Double = predictNode(root, features)

        private fun predictNode(node: TreeNode, features: DoubleArray): Double = when (node) {
            is TreeNode.Split -> {
                if (node.featureIndex < features.size && features[node.featureIndex] < node.threshold) {
                    predictNode(node.left, features)
                } else {
                    predictNode(node.right, features)
                }
            }
            is TreeNode.Leaf -> node.value
        }
    }

    private data class HistogramBin(
        var gradientSum: Double = 0.0,
        var hessianSum: Double = 0.0,
        var count: Int = 0,
    )

    // -- Training ---------------------------------------------------------------

    /**
     * Train the GBT model from feature vectors and score history.
     */
    fun train(
        vectors: List<DailyFeatureVector>,
        orderedKeys: List<FeatureKey>,
        scoreHistory: List<Pair<Long, Int>>,
        anomalyCounts: Map<Long, Int>,
    ) {
        if (vectors.size < MINIMUM_DAYS) return

        featureKeys = orderedKeys
        val contextSize = 5 // ContextFeatures.toArray().size
        val totalFeatures = orderedKeys.size + contextSize + 1 // +1 for bias

        val cal = Calendar.getInstance()

        // Build score lookup by start-of-day.
        val scoreLookup = mutableMapOf<Long, Int>()
        for ((date, score) in scoreHistory) {
            scoreLookup[startOfDay(date, cal)] = score
        }

        // Learn personalized bad-day thresholds.
        val allScores = scoreHistory.map { it.second.toDouble() }
        if (allScores.size >= 14) {
            val sorted = allScores.sorted()
            val p20Index = max(0, (sorted.size * 0.20).toInt() - 1)
            learnedLowScoreThreshold = sorted[p20Index]

            val drops = mutableListOf<Double>()
            for (i in 1 until allScores.size) {
                val delta = allScores[i - 1] - allScores[i]
                if (delta > 0) drops.add(delta)
            }
            if (drops.size >= 5) {
                drops.sort()
                val p75Index = (drops.size * 0.75).toInt()
                learnedScoreDropThreshold = drops[min(p75Index, drops.size - 1)]
            }
        }

        // Build training data.
        val X = mutableListOf<DoubleArray>()
        val y = mutableListOf<Double>()

        for (i in 0 until vectors.size - 1) {
            val today = vectors[i]
            val tomorrow = vectors[i + 1]
            val tomorrowDate = startOfDay(tomorrow.date, cal)
            val todayDate = startOfDay(today.date, cal)

            val tomorrowScore = scoreLookup[tomorrowDate]
            val todayScore = scoreLookup[todayDate]
            val anomalies = anomalyCounts[tomorrowDate] ?: 0

            val isBadDay = determineBadDay(todayScore, tomorrowScore, anomalies)
            val features = buildFeatureArray(today, orderedKeys)
            if (features.size != totalFeatures) continue

            X.add(features)
            y.add(if (isBadDay) 1.0 else 0.0)
        }

        if (X.size < MINIMUM_DAYS) return

        // Temporal train/validation split (80/20).
        val splitIdx = (X.size * 0.8).toInt()
        val trainX = X.subList(0, splitIdx)
        val trainY = y.subList(0, splitIdx)
        val valX = X.subList(splitIdx, X.size)
        val valY = y.subList(splitIdx, y.size)

        trainingCount = trainX.size

        // Compute base score (log-odds of positive class).
        val posCount = trainY.count { it > 0.5 }
        val negCount = trainY.size - posCount
        baseScore = ln(max(posCount.toDouble(), 1.0) / max(negCount.toDouble(), 1.0))

        // Pre-bin features for histogram-based split finding.
        val binEdges = precomputeBinEdges(trainX, numBins)

        // Initialize predictions to base score.
        val F = DoubleArray(trainX.size) { baseScore }
        val valF = DoubleArray(valX.size) { baseScore }
        trees = mutableListOf()
        featureImportance = mutableMapOf()

        var bestValLoss = Double.MAX_VALUE
        var roundsWithoutImprovement = 0
        val earlyStopPatience = 10

        for (round in 0 until numTrees) {
            // Compute gradients and hessians (logistic loss).
            val gradients = DoubleArray(trainX.size)
            val hessians = DoubleArray(trainX.size)
            for (i in trainX.indices) {
                val p = sigmoid(F[i])
                gradients[i] = p - trainY[i]
                hessians[i] = p * (1.0 - p)
            }

            // Subsample rows.
            val sampleIndices = trainX.indices.filter { Math.random() < subsampleRatio }
            if (sampleIndices.size < minSamplesLeaf * 2) break

            // Subsample columns.
            val numColsSample = max(1, (totalFeatures * colsampleRatio).toInt())
            val colIndices = (0 until totalFeatures).shuffled().take(numColsSample)

            // Build tree.
            val root = buildTree(trainX, gradients, hessians, sampleIndices, colIndices, binEdges, 0)
            val tree = DecisionTree(root)
            trees.add(tree)

            // Update training predictions.
            for (i in trainX.indices) {
                F[i] += learningRate * tree.predict(trainX[i])
            }

            // Validation loss and early stopping.
            if (valX.isNotEmpty()) {
                var valLoss = 0.0
                for (i in valX.indices) {
                    valF[i] += learningRate * tree.predict(valX[i])
                    val p = sigmoid(valF[i])
                    valLoss -= valY[i] * ln(max(p, 1e-15)) + (1 - valY[i]) * ln(max(1 - p, 1e-15))
                }
                valLoss /= valX.size

                if (valLoss < bestValLoss - 1e-4) {
                    bestValLoss = valLoss
                    roundsWithoutImprovement = 0
                } else {
                    roundsWithoutImprovement++
                    if (roundsWithoutImprovement >= earlyStopPatience) {
                        val toRemove = roundsWithoutImprovement
                        if (trees.size > toRemove) {
                            repeat(toRemove) { trees.removeLastOrNull() }
                        }
                        break
                    }
                }
            }
        }

        // Compute validation metrics and Platt calibration.
        if (valX.isNotEmpty()) {
            computeValidationMetrics(valX, valY)
            fitPlattCalibration(valX, valY)
        }
    }

    // -- Prediction -------------------------------------------------------------

    /**
     * Predict P(bad day tomorrow) from today's feature vector.
     */
    fun predict(todayVector: DailyFeatureVector): MLPrediction? {
        if (trees.isEmpty()) return null

        val features = buildFeatureArray(todayVector, featureKeys)
        if (features.isEmpty()) return null

        var rawScore = baseScore
        for (tree in trees) {
            rawScore += learningRate * tree.predict(features)
        }

        // Use Platt-calibrated probability if available.
        val probability = if (plattA != null && plattB != null) {
            sigmoid(plattA!! * rawScore + plattB!!)
        } else {
            sigmoid(rawScore)
        }

        val confidence = min(trainingCount.toDouble() / MAX_CONFIDENCE_SAMPLES, 1.0)

        val prediction = MLPrediction(
            metric = HealthMetric.HEART_RATE, // Placeholder: general prediction target
            predictedValue = probability,
            confidence = confidence,
            horizon = 1,
        )

        currentPrediction = prediction
        return prediction
    }

    /**
     * Raw predict with a feature array — for counterfactual simulation.
     */
    fun predict(features: DoubleArray): Double {
        if (trees.isEmpty()) return 0.5
        var rawScore = baseScore
        for (tree in trees) {
            rawScore += learningRate * tree.predict(features)
        }
        return sigmoid(rawScore)
    }

    // -- Incremental Training ---------------------------------------------------

    fun trainIncremental(todayVector: DailyFeatureVector, wasBadDay: Boolean) {
        if (trees.isEmpty()) return

        val features = buildFeatureArray(todayVector, featureKeys)
        if (features.isEmpty()) return

        trainingCount++

        val label = if (wasBadDay) 1.0 else 0.0
        var rawScore = baseScore
        for (tree in trees) {
            rawScore += learningRate * tree.predict(features)
        }
        val p = sigmoid(rawScore)
        val gradient = p - label
        val hessian = p * (1.0 - p)
        val leafValue = -gradient / (hessian + l2Lambda)

        trees.add(DecisionTree(TreeNode.Leaf(leafValue)))

        if (trees.size > numTrees + 50) {
            trees = trees.takeLast(numTrees).toMutableList()
        }
    }

    // -- Bad Day Classification -------------------------------------------------

    fun determineBadDay(todayScore: Int?, tomorrowScore: Int?, anomalyCount: Int): Boolean {
        if (todayScore != null && tomorrowScore != null) {
            if ((todayScore - tomorrowScore).toDouble() > learnedScoreDropThreshold) return true
        }
        if (tomorrowScore != null && tomorrowScore.toDouble() < learnedLowScoreThreshold) return true
        if (anomalyCount >= ANOMALY_COUNT_THRESHOLD) return true
        return false
    }

    // -- Feature Importance -----------------------------------------------------

    /** Feature importance ranking (normalized 0-1). */
    fun normalizedFeatureImportance(): List<Pair<FeatureKey, Double>> {
        val maxImp = featureImportance.values.maxOrNull() ?: return emptyList()
        if (maxImp <= 0) return emptyList()
        return featureImportance
            .filter { it.key < featureKeys.size }
            .map { (idx, imp) -> featureKeys[idx] to imp / maxImp }
            .sortedByDescending { it.second }
    }

    // -- Tree Building ----------------------------------------------------------

    private fun buildTree(
        X: List<DoubleArray>,
        gradients: DoubleArray,
        hessians: DoubleArray,
        indices: List<Int>,
        colIndices: List<Int>,
        binEdges: List<DoubleArray>,
        depth: Int,
    ): TreeNode {
        val G = indices.sumOf { gradients[it] }
        val H = indices.sumOf { hessians[it] }
        val leafValue = -G / (H + l2Lambda)

        if (depth >= maxDepth || indices.size < minSamplesLeaf * 2) {
            return TreeNode.Leaf(leafValue)
        }

        var bestGain = 0.0
        var bestFeature = -1
        var bestThreshold = 0.0
        val parentScore = (G * G) / (H + l2Lambda)

        for (featureIdx in colIndices) {
            if (featureIdx >= binEdges.size) continue
            val edges = binEdges[featureIdx]
            if (edges.isEmpty()) continue

            val bins = Array(edges.size + 1) { HistogramBin() }
            for (i in indices) {
                val v = X[i][featureIdx]
                val binIdx = findBin(v, edges)
                bins[binIdx].gradientSum += gradients[i]
                bins[binIdx].hessianSum += hessians[i]
                bins[binIdx].count++
            }

            var leftG = 0.0
            var leftH = 0.0
            var leftCount = 0
            for (binIdx in 0 until bins.size - 1) {
                leftG += bins[binIdx].gradientSum
                leftH += bins[binIdx].hessianSum
                leftCount += bins[binIdx].count
                val rightCount = indices.size - leftCount
                if (leftCount < minSamplesLeaf || rightCount < minSamplesLeaf) continue

                val rightG = G - leftG
                val rightH = H - leftH
                val leftScore = (leftG * leftG) / (leftH + l2Lambda)
                val rightScore = (rightG * rightG) / (rightH + l2Lambda)
                val gain = 0.5 * (leftScore + rightScore - parentScore)

                if (gain > bestGain) {
                    bestGain = gain
                    bestFeature = featureIdx
                    bestThreshold = if (binIdx < edges.size) edges[binIdx] else edges.last() + 1
                }
            }
        }

        if (bestGain <= 0 || bestFeature < 0) return TreeNode.Leaf(leafValue)

        featureImportance[bestFeature] = (featureImportance[bestFeature] ?: 0.0) + bestGain

        val leftIndices = indices.filter { X[it][bestFeature] < bestThreshold }
        val rightIndices = indices.filter { X[it][bestFeature] >= bestThreshold }

        if (leftIndices.isEmpty() || rightIndices.isEmpty()) return TreeNode.Leaf(leafValue)

        val left = buildTree(X, gradients, hessians, leftIndices, colIndices, binEdges, depth + 1)
        val right = buildTree(X, gradients, hessians, rightIndices, colIndices, binEdges, depth + 1)

        return TreeNode.Split(bestFeature, bestThreshold, bestGain, left, right)
    }

    // -- Histogram Helpers ------------------------------------------------------

    private fun precomputeBinEdges(X: List<DoubleArray>, numBins: Int): List<DoubleArray> {
        val first = X.firstOrNull() ?: return emptyList()
        return (first.indices).map { featureIdx ->
            val values = X.mapNotNull { row ->
                val v = row[featureIdx]
                if (v == FeatureKey.MISSING_SENTINEL) null else v
            }.sorted()
            if (values.size <= numBins) values.toDoubleArray()
            else {
                val step = max(1, values.size / numBins)
                (step until values.size step step).map { values[it] }.toDoubleArray()
            }
        }
    }

    private fun findBin(value: Double, edges: DoubleArray): Int {
        var lo = 0
        var hi = edges.size
        while (lo < hi) {
            val mid = (lo + hi) / 2
            if (edges[mid] <= value) lo = mid + 1 else hi = mid
        }
        return lo
    }

    // -- Feature Construction ---------------------------------------------------

    private fun buildFeatureArray(vector: DailyFeatureVector, orderedKeys: List<FeatureKey>): DoubleArray {
        val features = DoubleArray(orderedKeys.size + 5 + 1) // +5 context +1 bias
        for ((i, key) in orderedKeys.withIndex()) {
            val v = vector.features[key] ?: FeatureKey.MISSING_SENTINEL
            features[i] = if (v == FeatureKey.MISSING_SENTINEL) 0.0 else v
        }
        val ctx = vector.context.toArray()
        for (i in ctx.indices) {
            features[orderedKeys.size + i] = ctx[i]
        }
        features[features.size - 1] = 1.0 // bias
        return features
    }

    // -- Calibration & Validation -----------------------------------------------

    private fun fitPlattCalibration(valX: List<DoubleArray>, valY: List<Double>) {
        if (valX.size < 10) {
            plattA = null; plattB = null; return
        }

        val rawScores = DoubleArray(valX.size) { i ->
            var score = baseScore
            for (tree in trees) score += learningRate * tree.predict(valX[i])
            score
        }

        // Platt scaling via Newton-Raphson.
        val nPos = valY.count { it > 0.5 }.toDouble()
        val nNeg = valY.size - nPos
        if (nPos == 0.0 || nNeg == 0.0) { plattA = null; plattB = null; return }

        val tPos = (nPos + 1.0) / (nPos + 2.0)
        val tNeg = 1.0 / (nNeg + 2.0)
        val targets = valY.map { if (it > 0.5) tPos else tNeg }

        var a = 0.0
        var b = 0.0
        for (iter in 0 until 10) {
            var gradA = 0.0; var gradB = 0.0
            var hessAA = 0.0; var hessAB = 0.0; var hessBB = 0.0

            for (i in rawScores.indices) {
                val logit = a * rawScores[i] + b
                val p = sigmoid(logit)
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
            a += da; b += db
            if (abs(da) < 1e-8 && abs(db) < 1e-8) break
        }

        plattA = a
        plattB = b
    }

    private fun computeValidationMetrics(valX: List<DoubleArray>, valY: List<Double>) {
        val predictions = valX.mapIndexed { i, features ->
            var rawScore = baseScore
            for (tree in trees) rawScore += learningRate * tree.predict(features)
            sigmoid(rawScore) to valY[i]
        }

        // Brier score.
        validationBrierScore = predictions.sumOf { (p, l) -> (p - l) * (p - l) } / predictions.size

        // AUROC.
        val positives = predictions.filter { it.second > 0.5 }
        val negatives = predictions.filter { it.second <= 0.5 }
        if (positives.isEmpty() || negatives.isEmpty()) {
            validationAUROC = null; return
        }
        var concordant = 0
        var ties = 0
        for (pos in positives) {
            for (neg in negatives) {
                if (pos.first > neg.first) concordant++
                else if (pos.first == neg.first) ties++
            }
        }
        val totalPairs = positives.size * negatives.size
        validationAUROC = (concordant.toDouble() + 0.5 * ties) / totalPairs
    }

    // -- Helpers ----------------------------------------------------------------

    private fun sigmoid(x: Double): Double = 1.0 / (1.0 + exp(-x.coerceIn(-500.0, 500.0)))

    private fun startOfDay(epochMillis: Long, cal: Calendar): Long {
        cal.timeInMillis = epochMillis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
