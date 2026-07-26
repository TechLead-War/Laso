import Foundation
import Accelerate

/// Gradient Boosted Decision Trees for predicting P(bad day tomorrow).
/// Standard algorithm used by XGBoost/LightGBM, implemented with Apple Accelerate.
/// Far superior to logistic regression for tabular health data.
final class PredictiveScorer {
    static let minimumDays = 14
    private static let maxConfidenceSamples = 90

    // Bad day detection: personalized percentile-based thresholds
    // These are learned from user data at training time, not hardcoded globals
    private var learnedScoreDropThreshold: Double = 10.0
    private var learnedLowScoreThreshold: Double = 60.0
    private static let anomalyCount = 2

    // Platt scaling calibration parameters (fitted on validation set)
    private var plattA: Double?
    private var plattB: Double?
    private let calibrator = ConformalCalibrator()

    // GBT hyperparameters
    private let numTrees: Int = 80
    private let maxDepth: Int = 4
    private let learningRate: Double = 0.1
    private let minSamplesLeaf: Int = 5
    private let subsampleRatio: Double = 0.8
    private let colsampleRatio: Double = 0.8
    private let l2Lambda: Double = 1.0
    private let numBins: Int = 64

    // MARK: - Training & calibration thresholds (named so reviewers can audit them)

    /// Number of context features appended to the per-feature vector during training.
    private static let contextFeatureCount = 5
    /// Train/validation temporal split fraction (0.8 = first 80% train, last 20% validate).
    private static let trainValidationSplit: Double = 0.8
    /// Bottom-percentile cutoff used to learn the per-user "low score" bad-day threshold.
    private static let lowScorePercentile: Double = 0.20
    /// Quantile of day-to-day score drops used to learn the per-user "score crash" threshold.
    private static let scoreDropPercentile: Double = 0.75
    /// Minimum size of the day-to-day drops sample before the learned drop threshold replaces the default.
    private static let scoreDropMinSamples = 5
    /// Loss-improvement threshold used by early stopping (epsilon below current best to count as progress).
    private static let earlyStopLossEpsilon: Double = 1e-4
    /// Boosting rounds without validation-loss improvement before training stops early.
    private static let earlyStopPatience = 10
    /// Minimum validation samples required before Platt scaling calibration is fitted.
    private static let plattMinSamples = 10
    /// Numerical floor used when taking log(p) / log(1-p) to avoid log(0) explosions.
    private static let logProbFloor: Double = 1e-15
    /// Exponent clamp limit applied to sigmoid input to avoid overflow on extreme z-scores.
    private static let sigmoidClamp: Double = 500
    /// Extra buffer of trees retained beyond `numTrees` during incremental updates before pruning.
    private static let incrementalTreeBuffer = 50
    /// Top-N risk factors surfaced in `MLPrediction.topFactors`.
    private static let topFactorCount = 5

    // Model state
    private var trees: [DecisionTree] = []
    private var featureKeys: [FeatureKey] = []
    private var baseScore: Double = 0 // Initial log-odds
    private var trainingCount: Int = 0
    private var featureImportance: [Int: Double] = [:] // feature index -> total gain

    private(set) var currentPrediction: MLPrediction?
    /// Date of the last cached prediction. Invalidated on new training data.
    private var lastPredictionDate: Date?

    // MARK: - Decision Tree Node

    private indirect enum TreeNode {
        case split(featureIndex: Int, threshold: Double, gain: Double, left: TreeNode, right: TreeNode)
        case leaf(value: Double)
    }

    private struct DecisionTree {
        let root: TreeNode

        func predict(_ features: [Double]) -> Double {
            predictNode(root, features)
        }

        private func predictNode(_ node: TreeNode, _ features: [Double]) -> Double {
            switch node {
            case .split(let featureIndex, let threshold, _, let left, let right):
                if featureIndex < features.count && features[featureIndex] < threshold {
                    return predictNode(left, features)
                } else {
                    return predictNode(right, features)
                }
            case .leaf(let value):
                return value
            }
        }
    }

    // MARK: - Histogram Bin

    private struct HistogramBin {
        var gradientSum: Double = 0
        var hessianSum: Double = 0
        var count: Int = 0
    }

    // MARK: - Training

    func train(
        vectors: [DailyFeatureVector],
        orderedKeys: [FeatureKey],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int]
    ) {
        guard vectors.count >= Self.minimumDays else { return }

        featureKeys = orderedKeys
        let contextSize = Self.contextFeatureCount
        let totalFeatures = orderedKeys.count + contextSize + 1

        // Build training data
        let calendar = Date.cal
        var scoreLookup: [Date: Int] = [:]
        for entry in scoreHistory {
            scoreLookup[calendar.startOfDay(for: entry.date)] = entry.score
        }

        // Learn personalized bad-day thresholds from score distribution
        let allScores = scoreHistory.map { Double($0.score) }
        if allScores.count >= Self.minimumDays {
            let sorted = allScores.sorted()
            // Low score = bottom Nth percentile of this user's scores
            let pLowIndex = max(0, Int(Double(sorted.count) * Self.lowScorePercentile) - 1)
            learnedLowScoreThreshold = sorted[pLowIndex]

            // Score drop = configured percentile of day-to-day negative deltas
            var drops: [Double] = []
            for i in 1..<allScores.count {
                let delta = allScores[i - 1] - allScores[i]
                if delta > 0 { drops.append(delta) }
            }
            if drops.count >= Self.scoreDropMinSamples {
                drops.sort()
                let pDropIndex = Int(Double(drops.count) * Self.scoreDropPercentile)
                learnedScoreDropThreshold = drops[min(pDropIndex, drops.count - 1)]
            }
        }

        var X: [[Double]] = []
        var y: [Double] = []

        for i in 0..<(vectors.count - 1) {
            let today = vectors[i]
            let tomorrow = vectors[i + 1]
            let tomorrowDate = calendar.startOfDay(for: tomorrow.date)
            let todayDate = calendar.startOfDay(for: today.date)

            let tomorrowScore = scoreLookup[tomorrowDate]
            let todayScore = scoreLookup[todayDate]
            let anomalies = anomalyCounts[tomorrowDate] ?? 0

            let isBadDay = determineBadDay(
                todayScore: todayScore, tomorrowScore: tomorrowScore, anomalyCount: anomalies
            )

            let features = buildFeatureArray(from: today, orderedKeys: orderedKeys)
            guard features.count == totalFeatures else { continue }

            X.append(features)
            y.append(isBadDay ? 1.0 : 0.0)
        }

        guard X.count >= Self.minimumDays else { return }

        // Time-ordered train/validation split (80/20 by default). temporal split, not random
        let splitIdx = Int(Double(X.count) * Self.trainValidationSplit)
        let trainX = Array(X[..<splitIdx])
        let trainY = Array(y[..<splitIdx])
        let valX = Array(X[splitIdx...])
        let valY = Array(y[splitIdx...])

        trainingCount = trainX.count

        // Compute base score: log-odds of positive class
        let posCount = trainY.filter { $0 > 0.5 }.count
        let negCount = trainY.count - posCount
        baseScore = log(max(Double(posCount), 1.0) / max(Double(negCount), 1.0))

        // Pre-bin features for histogram-based split finding
        let binEdges = precomputeBinEdges(X: trainX, numBins: numBins)
        // Materialise the binned matrix once, feature-major, so the split search
        // reads one contiguous byte per row instead of chasing a row pointer into
        // a separate buffer and binary-searching 64 edges for every
        // (node, candidate feature, row). Bin indices are bounded by
        // `numBins` (64), so a byte is wide enough.
        let binnedMatrix = precomputeBinnedMatrix(X: trainX, binEdges: binEdges)

        // Initialize predictions to base score
        var F = [Double](repeating: baseScore, count: trainX.count)
        var valF = [Double](repeating: baseScore, count: valX.count)
        trees = []
        featureImportance = [:]

        // Track validation loss for early stopping
        var bestValLoss = Double.infinity
        var roundsWithoutImprovement = 0
        let earlyStopPatience = Self.earlyStopPatience

        // Boosting rounds with early stopping on validation set
        for _ in 0..<numTrees {
            // Compute gradients and hessians on training data (logistic loss)
            var gradients = [Double](repeating: 0, count: trainX.count)
            var hessians = [Double](repeating: 0, count: trainX.count)

            for i in 0..<trainX.count {
                let p = sigmoid(F[i])
                gradients[i] = p - trainY[i]
                hessians[i] = p * (1.0 - p)
            }

            // Subsample rows
            let sampleMask = (0..<trainX.count).map { _ in Double.random(in: 0...1) < subsampleRatio }
            let sampleIndices = (0..<trainX.count).filter { sampleMask[$0] }
            guard sampleIndices.count >= minSamplesLeaf * 2 else { break }

            // Subsample columns
            let numColsSample = max(1, Int(Double(totalFeatures) * colsampleRatio))
            let colIndices = Array((0..<totalFeatures).shuffled().prefix(numColsSample))

            // Build tree
            let root = buildTree(
                X: trainX, gradients: gradients, hessians: hessians,
                indices: sampleIndices, colIndices: colIndices,
                binEdges: binEdges, binned: binnedMatrix, rowCount: trainX.count, depth: 0
            )

            let tree = DecisionTree(root: root)
            trees.append(tree)

            // Update training predictions
            for i in 0..<trainX.count {
                F[i] += learningRate * tree.predict(trainX[i])
            }

            // Update validation predictions and compute validation loss
            if !valX.isEmpty {
                var valLoss = 0.0
                for i in 0..<valX.count {
                    valF[i] += learningRate * tree.predict(valX[i])
                    let p = sigmoid(valF[i])
                    valLoss -= valY[i] * log(max(p, Self.logProbFloor)) + (1 - valY[i]) * log(max(1 - p, Self.logProbFloor))
                }
                valLoss /= Double(valX.count)

                if valLoss < bestValLoss - Self.earlyStopLossEpsilon {
                    bestValLoss = valLoss
                    roundsWithoutImprovement = 0
                } else {
                    roundsWithoutImprovement += 1
                    if roundsWithoutImprovement >= earlyStopPatience {
                        // Remove trees added after best validation point
                        let treesToRemove = roundsWithoutImprovement
                        if trees.count > treesToRemove {
                            trees.removeLast(treesToRemove)
                        }
                        break
                    }
                }
            }
        }

        // Fit Platt scaling calibration on the validation split
        if !valX.isEmpty {
            fitPlattCalibration(valX: valX, valY: valY)
        }
    }

    /// Fit Platt scaling on validation set to calibrate raw sigmoid outputs.
    /// Maps raw log-odds to well-calibrated probabilities via logistic regression.
    private func fitPlattCalibration(valX: [[Double]], valY: [Double]) {
        guard valX.count >= Self.plattMinSamples else {
            plattA = nil
            plattB = nil
            return
        }

        // Collect raw log-odds (pre-sigmoid) for each validation example
        var rawScores = [Double](repeating: 0, count: valX.count)
        for i in 0..<valX.count {
            var score = baseScore
            for tree in trees {
                score += learningRate * tree.predict(valX[i])
            }
            rawScores[i] = score
        }

        // Fit Platt scaling: P(y=1|s) = 1/(1+exp(a*s+b))
        if let params = calibrator.plattScale(rawScores: rawScores, labels: valY) {
            plattA = params.a
            plattB = params.b
        } else {
            plattA = nil
            plattB = nil
        }
    }

    // MARK: - Tree Building (Histogram-based)

    private func buildTree(
        X: [[Double]], gradients: [Double], hessians: [Double],
        indices: [Int], colIndices: [Int],
        binEdges: [[Double]], binned: [UInt8], rowCount: Int, depth: Int
    ) -> TreeNode {
        // Compute leaf value
        let G = indices.reduce(0.0) { $0 + gradients[$1] }
        let H = indices.reduce(0.0) { $0 + hessians[$1] }
        let leafValue = -G / (H + l2Lambda)

        // Stop conditions
        if depth >= maxDepth || indices.count < minSamplesLeaf * 2 {
            return .leaf(value: leafValue)
        }

        var bestGain = 0.0
        var bestFeature = -1
        var bestThreshold = 0.0
        var bestLeftIndices: [Int] = []
        var bestRightIndices: [Int] = []

        let parentScore = (G * G) / (H + l2Lambda)

        // Histogram accumulators, allocated once per node and reset per feature
        // rather than reallocated for every (node, feature) pair. Sized from the
        // widest feature: `precomputeBinEdges` returns every distinct value as an
        // edge when a feature has fewer than `numBins` of them, so `edges.count`
        // is not bounded by `numBins`.
        let maxBins = (binEdges.map(\.count).max() ?? 0) + 1
        guard maxBins > 1 else { return .leaf(value: leafValue) }
        var binGrad = [Double](repeating: 0, count: maxBins)
        var binHess = [Double](repeating: 0, count: maxBins)
        var binCount = [Int](repeating: 0, count: maxBins)

        // Try each candidate feature
        for featureIdx in colIndices {
            guard featureIdx < binEdges.count else { continue }
            let edges = binEdges[featureIdx]
            guard !edges.isEmpty else { continue }

            let usedBins = edges.count + 1
            for b in 0..<usedBins { binGrad[b] = 0; binHess[b] = 0; binCount[b] = 0 }

            // Build histogram from the pre-binned matrix
            binned.withUnsafeBufferPointer { bin in
                let col = bin.baseAddress! + featureIdx * rowCount
                for i in indices {
                    let binIdx = Int(col[i])
                    binGrad[binIdx] += gradients[i]
                    binHess[binIdx] += hessians[i]
                    binCount[binIdx] += 1
                }
            }

            // Scan bins for best split
            var leftG = 0.0, leftH = 0.0
            var leftCount = 0
            for binIdx in 0..<usedBins - 1 {
                leftG += binGrad[binIdx]
                leftH += binHess[binIdx]
                leftCount += binCount[binIdx]
                let rightG = G - leftG
                let rightH = H - leftH
                let rightCount = indices.count - leftCount
                guard leftCount >= minSamplesLeaf, rightCount >= minSamplesLeaf else { continue }

                let leftScore = (leftG * leftG) / (leftH + l2Lambda)
                let rightScore = (rightG * rightG) / (rightH + l2Lambda)
                let gain = 0.5 * (leftScore + rightScore - parentScore)

                if gain > bestGain {
                    bestGain = gain
                    bestFeature = featureIdx
                    bestThreshold = binIdx < edges.count ? edges[binIdx] : edges[edges.count - 1] + 1
                }
            }
        }

        guard bestGain > 0, bestFeature >= 0 else {
            return .leaf(value: leafValue)
        }

        // Record feature importance
        featureImportance[bestFeature, default: 0] += bestGain

        // Split indices
        bestLeftIndices = indices.filter { X[$0][bestFeature] < bestThreshold }
        bestRightIndices = indices.filter { X[$0][bestFeature] >= bestThreshold }

        guard !bestLeftIndices.isEmpty, !bestRightIndices.isEmpty else {
            return .leaf(value: leafValue)
        }

        let left = buildTree(X: X, gradients: gradients, hessians: hessians,
                            indices: bestLeftIndices, colIndices: colIndices,
                            binEdges: binEdges, binned: binned, rowCount: rowCount, depth: depth + 1)
        let right = buildTree(X: X, gradients: gradients, hessians: hessians,
                             indices: bestRightIndices, colIndices: colIndices,
                             binEdges: binEdges, binned: binned, rowCount: rowCount, depth: depth + 1)

        return .split(featureIndex: bestFeature, threshold: bestThreshold,
                     gain: bestGain, left: left, right: right)
    }

    // MARK: - Histogram Helpers

    private func precomputeBinEdges(X: [[Double]], numBins: Int) -> [[Double]] {
        guard let first = X.first else { return [] }
        let numFeatures = first.count

        return (0..<numFeatures).map { featureIdx in
            let values = X.compactMap { row -> Double? in
                let v = row[featureIdx]
                return v == FeatureKey.missingSentinel ? nil : v
            }.sorted()
            guard values.count > numBins else { return values }

            // Quantile-based bin edges
            let step = max(1, values.count / numBins)
            return stride(from: step, to: values.count, by: step).map { values[$0] }
        }
    }

    /// Bin every training value once, feature-major (`[featureIdx * rowCount + row]`).
    /// `findBin` is unchanged and still the single definition of the bin boundary,
    /// so a pre-binned lookup and a live search always agree.
    private func precomputeBinnedMatrix(X: [[Double]], binEdges: [[Double]]) -> [UInt8] {
        let rowCount = X.count
        let featureCount = binEdges.count
        guard rowCount > 0, featureCount > 0 else { return [] }

        // A bin index is at most `edges.count`. `precomputeBinEdges` is widest
        // when the quantile stride is still 1, which happens only for a feature
        // with between `numBins + 1` and `2 * numBins - 1` distinct values; that
        // yields at most `2 * numBins - 2` (126) edges. Comfortably inside UInt8.
        // The conversion is left trapping on purpose: if that bound ever changes,
        // this must fail loudly rather than wrap silently.
        var binned = [UInt8](repeating: 0, count: featureCount * rowCount)
        for featureIdx in 0..<featureCount {
            let edges = binEdges[featureIdx]
            guard !edges.isEmpty else { continue }
            let base = featureIdx * rowCount
            for i in 0..<rowCount {
                binned[base + i] = UInt8(findBin(X[i][featureIdx], edges: edges))
            }
        }
        return binned
    }

    private func findBin(_ value: Double, edges: [Double]) -> Int {
        // Binary search for the bin
        var lo = 0, hi = edges.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if edges[mid] <= value { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-max(-Self.sigmoidClamp, min(Self.sigmoidClamp, x))))
    }

    // MARK: - Prediction

    func predict(todayVector: DailyFeatureVector) -> MLPrediction? {
        guard !trees.isEmpty else { return nil }

        // Return cached prediction if it was computed today (tree walk is deterministic for same input)
        let calendar = Date.cal
        if let cached = currentPrediction,
           let lastDate = lastPredictionDate,
           calendar.isDateInToday(lastDate) {
            return cached
        }

        let features = buildFeatureArray(from: todayVector, orderedKeys: featureKeys)
        guard !features.isEmpty else { return nil }

        // Sum base score + all tree predictions
        var rawScore = baseScore
        for tree in trees {
            rawScore += learningRate * tree.predict(features)
        }

        // Use Platt-calibrated probability if calibration was fitted, otherwise raw sigmoid
        let probability: Double
        if let a = plattA, let b = plattB {
            probability = calibrator.calibrate(rawScore: rawScore, a: a, b: b)
        } else {
            probability = sigmoid(rawScore)
        }
        let confidence = Swift.min(Double(trainingCount) / Double(Self.maxConfidenceSamples), 1.0)

        let topFactors = extractTopFactors(features: features, topN: Self.topFactorCount)

        let prediction = MLPrediction(
            target: "Challenging day tomorrow",
            probability: probability,
            confidence: confidence,
            topFactors: topFactors
        )

        currentPrediction = prediction
        lastPredictionDate = Date()
        return prediction
    }

    // MARK: - Incremental Training

    func trainIncremental(todayVector: DailyFeatureVector, wasBadDay: Bool) {
        guard !trees.isEmpty else { return }

        let features = buildFeatureArray(from: todayVector, orderedKeys: featureKeys)
        guard !features.isEmpty else { return }

        // Invalidate cached prediction since model weights are about to change
        lastPredictionDate = nil

        trainingCount += 1

        // Add one more tree fitted to this single data point's gradient
        let label = wasBadDay ? 1.0 : 0.0
        var rawScore = baseScore
        for tree in trees {
            rawScore += learningRate * tree.predict(features)
        }
        let p = sigmoid(rawScore)
        let gradient = p - label
        let hessian = p * (1.0 - p)
        let leafValue = -gradient / (hessian + l2Lambda)

        // Simple single-leaf tree for incremental update
        trees.append(DecisionTree(root: .leaf(value: leafValue)))

        // Keep tree count bounded
        if trees.count > numTrees + Self.incrementalTreeBuffer {
            trees = Array(trees.suffix(numTrees))
        }
    }

    // MARK: - Feature Construction

    /// Build feature array with NaN-safe missing data handling.
    /// GBT handles missing values natively by routing them to the direction that minimizes loss,
    /// so we use NaN for missing values instead of 0.0 (which is a valid z-score meaning "at mean").
    /// The tree split logic sends NaN to the right branch, effectively treating missing as "high".
    private func buildFeatureArray(from vector: DailyFeatureVector, orderedKeys: [FeatureKey]) -> [Double] {
        var features = orderedKeys.map { key -> Double in
            let v = vector.features[key] ?? FeatureKey.missingSentinel
            // Use 0.0 for missing since histogram-based GBT pre-filters sentinels during binning.
            // The precomputeBinEdges already filters sentinels from quantile computation.
            // Missing features effectively get binned into whichever split direction reduces loss.
            return v == FeatureKey.missingSentinel ? 0.0 : v
        }
        features.append(contentsOf: vector.context.asArray)
        features.append(1.0) // bias
        return features
    }

    // MARK: - Feature Attribution (using accumulated split gains)

    private func extractTopFactors(features: [Double], topN: Int) -> [PredictionFactor] {
        // Use feature importance from training + current feature values for direction
        var contributions: [(index: Int, importance: Double, direction: Double)] = []

        for (idx, importance) in featureImportance {
            guard idx < featureKeys.count, idx < features.count else { continue }
            let direction = features[idx] // positive feature value = risk increasing
            contributions.append((idx, importance, direction))
        }

        contributions.sort { $0.importance > $1.importance }

        return contributions.prefix(topN).compactMap { item in
            guard item.index < featureKeys.count else { return nil }
            let key = featureKeys[item.index]
            // Contribution sign: importance * feature value direction
            let signedContribution = item.importance * (item.direction >= 0 ? 1 : -1)
            return PredictionFactor(
                metric: key.metric,
                featureType: key.type,
                contribution: signedContribution
            )
        }
    }

    // MARK: - Bad Day Classification

    func determineBadDay(todayScore: Int?, tomorrowScore: Int?, anomalyCount: Int) -> Bool {
        // Use personalized thresholds learned from this user's score distribution
        if let today = todayScore, let tomorrow = tomorrowScore {
            if Double(today - tomorrow) > learnedScoreDropThreshold { return true }
        }
        if let tomorrow = tomorrowScore, Double(tomorrow) < learnedLowScoreThreshold { return true }
        if anomalyCount >= Self.anomalyCount { return true }
        return false
    }

    // MARK: - State

    var isReady: Bool { !trees.isEmpty && trainingCount >= Self.minimumDays }
}
