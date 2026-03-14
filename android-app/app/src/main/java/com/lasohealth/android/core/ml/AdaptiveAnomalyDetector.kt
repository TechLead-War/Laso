package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Isolation Forest anomaly detector with contextual conditioning, persistence gating,
 * and cross-signal confirmation.
 *
 * Learns "normal for this user on a Monday after a hard workout" instead of using
 * static thresholds. Produces scored anomalies with severity classification.
 *
 * Minimum 60 days of data required.
 *
 * Ported from iOS `AdaptiveAnomalyDetector.swift`.
 */
class AdaptiveAnomalyDetector {

    companion object {
        /** Minimum days of data required. */
        const val MINIMUM_DAYS = 60

        /** Number of isolation trees. */
        private const val NUM_TREES = 50
        /** Subsample size for each tree. */
        private const val SUBSAMPLE_SIZE = 256
        /** Minimum peers required for a context bucket to be valid. */
        private const val MIN_BUCKET_PEERS = 5

        /** Cross-signal confirmation groups: correlated metrics. */
        private val CONFIRMATION_GROUPS: List<List<HealthMetric>> = listOf(
            listOf(HealthMetric.HEART_RATE_VARIABILITY, HealthMetric.RESTING_HEART_RATE, HealthMetric.HEART_RATE),
            listOf(HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP, HealthMetric.SLEEP_REM),
            listOf(HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES, HealthMetric.EXERCISE_MINUTES),
        )
    }

    // -- Severity ---------------------------------------------------------------

    enum class AnomalySeverity(val level: Int) {
        NONE(0), INFO(1), WARNING(2), CRITICAL(3);
    }

    // -- Anomaly Result ---------------------------------------------------------

    data class AdaptiveAnomaly(
        val date: Long,
        val globalScore: Double,
        val contextualZScore: Double,
        val severity: AnomalySeverity,
        val contextBucket: String,
        val persistenceDays: Int,
        val crossSignalConfirmation: Boolean,
        val confirmingMetrics: List<HealthMetric>,
        val shouldSurface: Boolean,
        val isAnomaly: Boolean,
        val anomalousFeatures: List<Pair<FeatureKey, Double>>,
    )

    // -- Isolation Tree ---------------------------------------------------------

    private sealed class IsolationNode {
        data class Branch(
            val featureIndex: Int,
            val splitValue: Double,
            val left: IsolationNode,
            val right: IsolationNode,
        ) : IsolationNode()

        data class Leaf(val size: Int) : IsolationNode()
    }

    private data class IsolationTree(val root: IsolationNode, val maxDepth: Int)

    // -- Context Bucket ---------------------------------------------------------

    private data class DayContext(
        val isWeekend: Boolean,
        val hadIntenseExercise: Boolean,
        val hasSleepDebt: Boolean,
    ) {
        val bucketLabel: String
            get() {
                val parts = mutableListOf<String>()
                parts.add(if (isWeekend) "weekend" else "weekday")
                if (hadIntenseExercise) parts.add("intense")
                if (hasSleepDebt) parts.add("sleepdebt")
                if (!hadIntenseExercise && !hasSleepDebt) parts.add("normal")
                return parts.joinToString("_")
            }
    }

    private data class BucketStats(
        val bucketLabel: String,
        val peerCount: Int,
        val featureMeans: DoubleArray,
        val featureStds: DoubleArray,
    )

    // -- State ------------------------------------------------------------------

    private var forest: List<IsolationTree> = emptyList()
    private var featureDim: Int = 0
    private var trainingVectors: List<DailyFeatureVector> = emptyList()
    private var trainedKeys: List<FeatureKey> = emptyList()
    private var trainedBaselines: Map<HealthMetric, MetricBaseline> = emptyMap()
    private var bucketStatsCache: Map<String, BucketStats> = emptyMap()
    private var trainingContexts: List<DayContext> = emptyList()

    // Learned severity thresholds.
    private var criticalScoreThreshold = 0.8
    private var warningScoreThreshold = 0.65
    private var infoScoreThreshold = 0.5
    private var featureAttributionThreshold = 1.5

    // Persistence tracking.
    private val consecutiveAnomalyDays = mutableMapOf<HealthMetric, Int>()
    private val lastAnomalyDate = mutableMapOf<HealthMetric, Long>()

    /** Whether the forest has been trained. */
    val isReady: Boolean get() = forest.isNotEmpty()

    // -- Training ---------------------------------------------------------------

    /**
     * Build the isolation forest from daily feature vectors.
     */
    fun train(
        vectors: List<DailyFeatureVector>,
        orderedKeys: List<FeatureKey>,
        baselines: Map<HealthMetric, MetricBaseline> = emptyMap(),
    ) {
        if (vectors.size < MINIMUM_DAYS) return

        trainedKeys = orderedKeys
        trainingVectors = vectors
        trainedBaselines = baselines
        featureDim = orderedKeys.size
        if (featureDim == 0) return

        // Convert to arrays.
        val dataArrays = vectors.map { it.toArray(orderedKeys) }

        // Build forest.
        val maxDepth = ceil(log2(SUBSAMPLE_SIZE.toDouble())).toInt()
        forest = (0 until NUM_TREES).map {
            val subsample = randomSubsample(dataArrays, SUBSAMPLE_SIZE)
            val root = buildTree(subsample, 0, maxDepth)
            IsolationTree(root, maxDepth)
        }

        // Compute context for all training vectors.
        trainingContexts = vectors.mapIndexed { index, vector ->
            computeContext(vector, vectors, index)
        }

        // Build per-bucket statistics.
        buildBucketStats(dataArrays)

        // Learn severity thresholds from training score distribution.
        learnSeverityThresholds(dataArrays)

        // Reset persistence tracking.
        consecutiveAnomalyDays.clear()
        lastAnomalyDate.clear()
    }

    // -- Scoring ----------------------------------------------------------------

    /**
     * Score a single feature vector for anomaly.
     */
    fun score(vector: DailyFeatureVector, allVectors: List<DailyFeatureVector>? = null): AdaptiveAnomaly {
        val features = vector.toArray(trainedKeys)

        val globalScore = isolationScore(features)

        val context = if (allVectors != null) {
            val idx = allVectors.indexOfFirst { it.date == vector.date }
            if (idx >= 0) computeContext(vector, allVectors, idx)
            else computeContext(vector, trainingVectors, trainingVectors.size - 1)
        } else {
            computeContext(vector, trainingVectors, trainingVectors.size - 1)
        }

        val contextualZ = contextualZScoreFromBucket(features, context)
        var severity = classifySeverity(globalScore, contextualZ)

        val anomalousFeatures = findAnomalousFeatures(features)

        val (crossConfirmed, confirmingMetrics) = checkCrossSignalConfirmation(vector, anomalousFeatures)

        if (crossConfirmed) {
            severity = boostSeverity(severity)
        }

        val persistenceDays = updatePersistenceTracking(vector.date, severity, anomalousFeatures)
        val shouldSurface = passesPersistenceGate(severity, persistenceDays)
        val isAnomaly = severity.level >= AnomalySeverity.WARNING.level

        return AdaptiveAnomaly(
            date = vector.date,
            globalScore = globalScore,
            contextualZScore = contextualZ,
            severity = severity,
            contextBucket = context.bucketLabel,
            persistenceDays = persistenceDays,
            crossSignalConfirmation = crossConfirmed,
            confirmingMetrics = confirmingMetrics,
            shouldSurface = shouldSurface,
            isAnomaly = isAnomaly,
            anomalousFeatures = anomalousFeatures,
        )
    }

    /**
     * Score multiple vectors (recent days).
     */
    fun scoreRecent(vectors: List<DailyFeatureVector>, days: Int = 7): List<AdaptiveAnomaly> {
        consecutiveAnomalyDays.clear()
        lastAnomalyDate.clear()
        val recent = if (vectors.size > days) vectors.subList(vectors.size - days, vectors.size) else vectors
        return recent.map { score(it, vectors) }
    }

    // -- Severity Classification ------------------------------------------------

    private fun classifySeverity(globalScore: Double, contextualZ: Double): AnomalySeverity {
        val absZ = abs(contextualZ)
        if (globalScore >= criticalScoreThreshold || absZ >= 2.5) return AnomalySeverity.CRITICAL
        if (globalScore >= warningScoreThreshold || absZ >= 2.0) return AnomalySeverity.WARNING
        if (globalScore >= infoScoreThreshold || absZ >= 1.5) return AnomalySeverity.INFO
        return AnomalySeverity.NONE
    }

    private fun boostSeverity(severity: AnomalySeverity): AnomalySeverity = when (severity) {
        AnomalySeverity.NONE -> AnomalySeverity.NONE
        AnomalySeverity.INFO -> AnomalySeverity.WARNING
        AnomalySeverity.WARNING -> AnomalySeverity.CRITICAL
        AnomalySeverity.CRITICAL -> AnomalySeverity.CRITICAL
    }

    // -- Context Computation ----------------------------------------------------

    private fun computeContext(
        vector: DailyFeatureVector,
        allVectors: List<DailyFeatureVector>,
        index: Int,
    ): DayContext {
        val isWeekend = vector.context.isWeekend == 1.0

        // Exercise intensity: use baseline + 1 SD as threshold.
        val hadIntenseExercise: Boolean = run {
            val activeCalRaw = vector.rawValue(HealthMetric.ACTIVE_CALORIES) ?: return@run false
            val baseline = trainedBaselines[HealthMetric.ACTIVE_CALORIES]
            if (baseline != null && baseline.mean > 0 && baseline.standardDeviation > 0) {
                activeCalRaw > baseline.mean + baseline.standardDeviation
            } else {
                val trainingCals = trainingVectors.mapNotNull { it.rawValue(HealthMetric.ACTIVE_CALORIES) }
                val trainingMean = if (trainingCals.isEmpty()) 0.0 else trainingCals.average()
                trainingMean > 0 && activeCalRaw > trainingMean * 1.5
            }
        }

        // Sleep debt: cumulative deficit over past 3 days.
        val hasSleepDebt: Boolean = run {
            val sleepBaseline = trainedBaselines[HealthMetric.SLEEP_DURATION]
            if (sleepBaseline != null && sleepBaseline.mean > 0) {
                val threshold = max(0.5, sleepBaseline.standardDeviation)
                var cumulativeDeficit = 0.0
                val lookback = min(3, index)
                for (i in (index - lookback)..index) {
                    if (i in allVectors.indices) {
                        val sleepVal = allVectors[i].rawValue(HealthMetric.SLEEP_DURATION)
                        if (sleepVal != null) {
                            val deficit = sleepBaseline.mean - sleepVal
                            if (deficit > 0) cumulativeDeficit += deficit
                        }
                    }
                }
                cumulativeDeficit > threshold
            } else {
                false
            }
        }

        return DayContext(isWeekend, hadIntenseExercise, hasSleepDebt)
    }

    // -- Bucket Statistics ------------------------------------------------------

    private fun buildBucketStats(dataArrays: List<DoubleArray>) {
        val cache = mutableMapOf<String, BucketStats>()

        // Group indices by bucket.
        val bucketIndices = mutableMapOf<String, MutableList<Int>>()
        for ((i, ctx) in trainingContexts.withIndex()) {
            bucketIndices.getOrPut(ctx.bucketLabel) { mutableListOf() }.add(i)
        }

        for ((label, indices) in bucketIndices) {
            if (indices.size < MIN_BUCKET_PEERS) continue

            val means = DoubleArray(featureDim)
            val stds = DoubleArray(featureDim)

            for (featureIdx in 0 until featureDim) {
                val values = indices.mapNotNull { idx ->
                    val v = dataArrays[idx][featureIdx]
                    if (v == FeatureKey.MISSING_SENTINEL) null else v
                }
                if (values.isEmpty()) continue
                means[featureIdx] = values.average()
                stds[featureIdx] = welfordStdDev(values)
            }

            cache[label] = BucketStats(label, indices.size, means, stds)
        }

        bucketStatsCache = cache
    }

    private fun contextualZScoreFromBucket(features: DoubleArray, context: DayContext): Double {
        bucketStatsCache[context.bucketLabel]?.let { return maxFeatureZ(features, it) }

        val relaxedLabel = if (context.isWeekend) "weekend_normal" else "weekday_normal"
        bucketStatsCache[relaxedLabel]?.let { return maxFeatureZ(features, it) }

        return legacyContextualZScore(features)
    }

    private fun maxFeatureZ(features: DoubleArray, stats: BucketStats): Double {
        var maxZ = 0.0
        for (i in 0 until min(features.size, stats.featureMeans.size)) {
            val value = features[i]
            if (value == FeatureKey.MISSING_SENTINEL) continue
            val std = stats.featureStds[i]
            if (std <= 0) continue
            val z = abs(value - stats.featureMeans[i]) / std
            if (z > maxZ) maxZ = z
        }
        return maxZ
    }

    private fun legacyContextualZScore(features: DoubleArray): Double {
        if (trainedKeys.isEmpty()) return 0.0

        val allArrays = trainingVectors.map { it.toArray(trainedKeys) }
        val dim = trainedKeys.size

        // Compute global centroid.
        val centroid = DoubleArray(dim)
        val counts = DoubleArray(dim)
        for (arr in allArrays) {
            for (i in 0 until dim) {
                if (arr[i] != FeatureKey.MISSING_SENTINEL) {
                    centroid[i] += arr[i]
                    counts[i] += 1.0
                }
            }
        }
        for (i in 0 until dim) {
            if (counts[i] > 0) centroid[i] /= counts[i]
        }

        val peerDistances = allArrays.map { euclideanDistanceIgnoringMissing(it, centroid) }
        val targetDist = euclideanDistanceIgnoringMissing(features, centroid)
        val meanDist = peerDistances.average()
        val stdDist = welfordStdDev(peerDistances)

        return if (stdDist > 0) (targetDist - meanDist) / stdDist else 0.0
    }

    // -- Cross-Signal Confirmation ----------------------------------------------

    private fun checkCrossSignalConfirmation(
        vector: DailyFeatureVector,
        anomalousFeatures: List<Pair<FeatureKey, Double>>,
    ): Pair<Boolean, List<HealthMetric>> {
        if (anomalousFeatures.isEmpty()) return false to emptyList()

        val anomalousMetrics = anomalousFeatures.map { it.first.metric }.toSet()
        val confirming = mutableSetOf<HealthMetric>()

        for (metric in anomalousMetrics) {
            val group = CONFIRMATION_GROUPS.firstOrNull { it.contains(metric) } ?: continue
            for (sibling in group) {
                if (sibling == metric) continue
                val z = featureZScoreVsTraining(sibling, vector)
                if (abs(z) > 1.0) confirming.add(sibling)
            }
        }

        return confirming.isNotEmpty() to confirming.toList()
    }

    private fun featureZScoreVsTraining(metric: HealthMetric, vector: DailyFeatureVector): Double {
        val key = FeatureKey(metric, FeatureType.RAW)
        val value = vector.features[key]?.takeIf { it != FeatureKey.MISSING_SENTINEL } ?: return 0.0

        val trainingValues = trainingVectors.mapNotNull { v ->
            v.features[key]?.takeIf { it != FeatureKey.MISSING_SENTINEL }
        }
        if (trainingValues.isEmpty()) return 0.0

        val mean = trainingValues.average()
        val sd = welfordStdDev(trainingValues)
        return if (sd > 0) (value - mean) / sd else 0.0
    }

    // -- Persistence Gating -----------------------------------------------------

    private fun updatePersistenceTracking(
        date: Long,
        severity: AnomalySeverity,
        anomalousFeatures: List<Pair<FeatureKey, Double>>,
    ): Int {
        if (severity.level < AnomalySeverity.INFO.level) return 0

        val anomalousMetrics = anomalousFeatures.map { it.first.metric }.toSet()
        var maxStreak = 0
        val dayMs = 86_400_000L

        for (metric in anomalousMetrics) {
            val lastDate = lastAnomalyDate[metric]
            if (lastDate != null) {
                val daysBetween = ((date - lastDate) / dayMs).toInt()
                when (daysBetween) {
                    1 -> consecutiveAnomalyDays[metric] = (consecutiveAnomalyDays[metric] ?: 0) + 1
                    0 -> { /* Same day, no change. */ }
                    else -> consecutiveAnomalyDays[metric] = 1
                }
            } else {
                consecutiveAnomalyDays[metric] = 1
            }
            lastAnomalyDate[metric] = date
            maxStreak = max(maxStreak, consecutiveAnomalyDays[metric] ?: 1)
        }

        return maxStreak
    }

    private fun passesPersistenceGate(severity: AnomalySeverity, persistenceDays: Int): Boolean =
        when (severity) {
            AnomalySeverity.NONE -> false
            AnomalySeverity.INFO -> persistenceDays >= 3
            AnomalySeverity.WARNING -> persistenceDays >= 2
            AnomalySeverity.CRITICAL -> true
        }

    // -- Feature Attribution ----------------------------------------------------

    private fun findAnomalousFeatures(features: DoubleArray): List<Pair<FeatureKey, Double>> {
        if (trainedKeys.isEmpty()) return emptyList()

        val allArrays = trainingVectors.map { it.toArray(trainedKeys) }
        val contributions = mutableListOf<Pair<FeatureKey, Double>>()

        for ((i, key) in trainedKeys.withIndex()) {
            val featureValue = if (i < features.size) features[i] else 0.0
            if (featureValue == FeatureKey.MISSING_SENTINEL) continue

            val trainingValues = allArrays.mapNotNull { row ->
                if (i < row.size && row[i] != FeatureKey.MISSING_SENTINEL) row[i] else null
            }
            if (trainingValues.isEmpty()) continue

            val mean = trainingValues.average()
            val sd = welfordStdDev(trainingValues)
            if (sd <= 0) continue

            val deviation = abs(featureValue - mean) / sd
            if (deviation > featureAttributionThreshold) {
                contributions.add(key to deviation)
            }
        }

        return contributions.sortedByDescending { it.second }.take(5)
    }

    // -- Isolation Forest Internals ---------------------------------------------

    private fun isolationScore(point: DoubleArray): Double {
        if (forest.isEmpty()) return 0.0

        val avgPathLength = forest.map { pathLength(point, it.root, 0) }.average()
        val cn = averagePathLength(SUBSAMPLE_SIZE)
        if (cn <= 0) return 0.0

        return 2.0.pow(-avgPathLength / cn)
    }

    private fun pathLength(point: DoubleArray, node: IsolationNode, depth: Int): Double = when (node) {
        is IsolationNode.Leaf -> depth.toDouble() + averagePathLength(node.size)
        is IsolationNode.Branch -> {
            if (node.featureIndex >= point.size) {
                depth.toDouble()
            } else {
                val value = point[node.featureIndex]
                if (value == FeatureKey.MISSING_SENTINEL) {
                    depth.toDouble() + averagePathLength(SUBSAMPLE_SIZE / 2)
                } else if (value < node.splitValue) {
                    pathLength(point, node.left, depth + 1)
                } else {
                    pathLength(point, node.right, depth + 1)
                }
            }
        }
    }

    /** c(n) = average path length of unsuccessful BST search. */
    private fun averagePathLength(n: Int): Double {
        if (n <= 2) return max(n - 1, 0).toDouble()
        val harmonic = Math.log(n - 1.0) + 0.5772156649
        return 2.0 * harmonic - (2.0 * (n - 1).toDouble() / n)
    }

    private fun buildTree(data: List<DoubleArray>, depth: Int, maxDepth: Int): IsolationNode {
        if (data.size <= 1 || depth >= maxDepth) {
            return IsolationNode.Leaf(data.size)
        }

        val dim = data.firstOrNull()?.size ?: return IsolationNode.Leaf(data.size)
        if (dim == 0) return IsolationNode.Leaf(data.size)

        val featureIndex = (0 until dim).random()
        val validValues = data.mapNotNull { row ->
            if (featureIndex < row.size && row[featureIndex] != FeatureKey.MISSING_SENTINEL) row[featureIndex] else null
        }

        val minVal = validValues.minOrNull()
        val maxVal = validValues.maxOrNull()
        if (minVal == null || maxVal == null || minVal >= maxVal) {
            return IsolationNode.Leaf(data.size)
        }

        val splitValue = minVal + Math.random() * (maxVal - minVal)

        val leftData = mutableListOf<DoubleArray>()
        val rightData = mutableListOf<DoubleArray>()

        for (row in data) {
            val v = if (featureIndex < row.size) row[featureIndex] else FeatureKey.MISSING_SENTINEL
            when {
                v == FeatureKey.MISSING_SENTINEL -> if (Math.random() < 0.5) leftData.add(row) else rightData.add(row)
                v < splitValue -> leftData.add(row)
                else -> rightData.add(row)
            }
        }

        if (leftData.isEmpty() || rightData.isEmpty()) {
            return IsolationNode.Leaf(data.size)
        }

        val left = buildTree(leftData, depth + 1, maxDepth)
        val right = buildTree(rightData, depth + 1, maxDepth)

        return IsolationNode.Branch(featureIndex, splitValue, left, right)
    }

    private fun randomSubsample(data: List<DoubleArray>, size: Int): List<DoubleArray> {
        if (data.size <= size) return data
        return data.shuffled().take(size)
    }

    private fun learnSeverityThresholds(dataArrays: List<DoubleArray>) {
        val scores = dataArrays.map { isolationScore(it) }.sorted()
        if (scores.size < 20) return

        val n = scores.size
        criticalScoreThreshold = scores[min((n * 0.95).toInt(), n - 1)]
        warningScoreThreshold = scores[min((n * 0.90).toInt(), n - 1)]
        infoScoreThreshold = scores[min((n * 0.80).toInt(), n - 1)]

        criticalScoreThreshold = max(criticalScoreThreshold, 0.6)
        warningScoreThreshold = min(warningScoreThreshold, criticalScoreThreshold - 0.02)
        infoScoreThreshold = min(infoScoreThreshold, warningScoreThreshold - 0.02)

        // Learn feature attribution threshold from training deviation distribution.
        val allDeviations = computeAllTrainingDeviations(dataArrays)
        if (allDeviations.size >= 10) {
            val sorted = allDeviations.sorted()
            featureAttributionThreshold = sorted[min((sorted.size * 0.90).toInt(), sorted.size - 1)]
            featureAttributionThreshold = max(featureAttributionThreshold, 1.0)
        }
    }

    private fun computeAllTrainingDeviations(dataArrays: List<DoubleArray>): List<Double> {
        val dim = trainedKeys.size
        if (dim == 0 || dataArrays.isEmpty()) return emptyList()

        val means = DoubleArray(dim)
        val counts = DoubleArray(dim)
        for (row in dataArrays) {
            for (i in 0 until min(row.size, dim)) {
                if (row[i] != FeatureKey.MISSING_SENTINEL) {
                    means[i] += row[i]
                    counts[i] += 1.0
                }
            }
        }
        for (i in 0 until dim) {
            if (counts[i] > 0) means[i] /= counts[i]
        }

        val variances = DoubleArray(dim)
        for (row in dataArrays) {
            for (i in 0 until min(row.size, dim)) {
                if (row[i] != FeatureKey.MISSING_SENTINEL) {
                    val diff = row[i] - means[i]
                    variances[i] += diff * diff
                }
            }
        }
        val stds = DoubleArray(dim) { i ->
            if (counts[i] > 1) sqrt(variances[i] / counts[i]) else 0.0
        }

        val deviations = mutableListOf<Double>()
        for (row in dataArrays) {
            for (i in 0 until min(row.size, dim)) {
                if (row[i] != FeatureKey.MISSING_SENTINEL && stds[i] > 0) {
                    deviations.add(abs(row[i] - means[i]) / stds[i])
                }
            }
        }
        return deviations
    }

    // -- Helpers ----------------------------------------------------------------

    private fun euclideanDistanceIgnoringMissing(a: DoubleArray, b: DoubleArray): Double {
        var sumSq = 0.0
        var count = 0
        for (i in 0 until min(a.size, b.size)) {
            if (a[i] != FeatureKey.MISSING_SENTINEL && b[i] != FeatureKey.MISSING_SENTINEL) {
                val diff = a[i] - b[i]
                sumSq += diff * diff
                count++
            }
        }
        return if (count > 0) sqrt(sumSq / count) else 0.0
    }

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
}
