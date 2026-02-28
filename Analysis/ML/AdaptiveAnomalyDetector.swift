import Foundation

/// Isolation Forest anomaly detector with contextual peer comparison.
/// Learns "normal for this user on a Monday after a hard workout" instead of using static thresholds.
final class AdaptiveAnomalyDetector {
    /// Minimum days of data required
    static let minimumDays = 60

    /// Number of isolation trees
    private static let numTrees = 100
    /// Subsample size for each tree
    private static let subSampleSize = 256
    /// Anomaly score threshold (global)
    private static let globalThreshold = 0.65
    /// Contextual z-score threshold
    private static let contextualThreshold = 2.0

    // MARK: - Isolation Tree

    private indirect enum IsolationNode {
        case branch(featureIndex: Int, splitValue: Double, left: IsolationNode, right: IsolationNode)
        case leaf(size: Int)
    }

    private struct IsolationTree {
        let root: IsolationNode
        let maxDepth: Int
    }

    /// Trained forest
    private var forest: [IsolationTree] = []
    /// Feature dimension used during training
    private var featureDim: Int = 0
    /// Training data for contextual comparison
    private var trainingVectors: [DailyFeatureVector] = []
    /// Ordered keys matching the training feature dimension
    private var trainedKeys: [FeatureKey] = []
    /// Last full retrain date
    private var lastRetrainDate: Date?

    // MARK: - Training

    /// Build the isolation forest from daily feature vectors
    func train(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey]) {
        guard vectors.count >= Self.minimumDays else { return }

        trainedKeys = orderedKeys
        trainingVectors = vectors

        // Convert to arrays
        let dataArrays = vectors.map { $0.toArray(orderedKeys: orderedKeys) }
        featureDim = orderedKeys.count
        guard featureDim > 0 else { return }

        // Build forest
        let maxDepth = Int(ceil(log2(Double(Self.subSampleSize))))
        forest = (0..<Self.numTrees).map { _ in
            let subsample = randomSubsample(dataArrays, size: Self.subSampleSize)
            let root = buildTree(data: subsample, depth: 0, maxDepth: maxDepth)
            return IsolationTree(root: root, maxDepth: maxDepth)
        }

        lastRetrainDate = Date()
    }

    /// Whether a full retrain is due (every 30 days)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Scoring

    /// Anomaly result from the adaptive detector
    struct AdaptiveAnomaly {
        let date: Date
        let globalScore: Double     // Isolation forest score (0-1, higher = more anomalous)
        let contextualZScore: Double // Z-score vs same-context peers
        let isAnomaly: Bool
        let anomalousFeatures: [(key: FeatureKey, contribution: Double)]
    }

    /// Score a single feature vector for anomaly
    func score(vector: DailyFeatureVector) -> AdaptiveAnomaly {
        let features = vector.toArray(orderedKeys: trainedKeys)

        // Global isolation score
        let globalScore = isolationScore(features)

        // Contextual comparison (same day-of-week ± 1, same season)
        let contextualZ = contextualZScore(vector: vector)

        let isAnomaly = globalScore > Self.globalThreshold ||
                        abs(contextualZ) > Self.contextualThreshold

        // Find most anomalous features by comparing to training distribution
        let anomalousFeatures = findAnomalousFeatures(features: features)

        return AdaptiveAnomaly(
            date: vector.date,
            globalScore: globalScore,
            contextualZScore: contextualZ,
            isAnomaly: isAnomaly,
            anomalousFeatures: anomalousFeatures
        )
    }

    /// Score multiple vectors (recent days)
    func scoreRecent(vectors: [DailyFeatureVector], days: Int = 7) -> [AdaptiveAnomaly] {
        let recent = vectors.suffix(days)
        return recent.map { score(vector: $0) }
    }

    // MARK: - Isolation Forest Internals

    private func isolationScore(_ point: [Double]) -> Double {
        guard !forest.isEmpty else { return 0 }

        let avgPathLength = forest.map { pathLength(point: point, node: $0.root, depth: 0) }
            .reduce(0.0, +) / Double(forest.count)

        let cn = averagePathLength(n: Self.subSampleSize)
        guard cn > 0 else { return 0 }

        // Anomaly score: s = 2^(-avgPathLength / c(n))
        return pow(2.0, -avgPathLength / cn)
    }

    private func pathLength(point: [Double], node: IsolationNode, depth: Int) -> Double {
        switch node {
        case .leaf(let size):
            return Double(depth) + averagePathLength(n: size)

        case .branch(let featureIndex, let splitValue, let left, let right):
            guard featureIndex < point.count else {
                return Double(depth)
            }
            let value = point[featureIndex]
            // Skip missing values — treat as average depth
            if value == FeatureKey.missingSentinel {
                return Double(depth) + averagePathLength(n: Self.subSampleSize / 2)
            }
            if value < splitValue {
                return pathLength(point: point, node: left, depth: depth + 1)
            } else {
                return pathLength(point: point, node: right, depth: depth + 1)
            }
        }
    }

    /// c(n) = average path length of unsuccessful search in BST
    private func averagePathLength(n: Int) -> Double {
        guard n > 2 else { return max(Double(n) - 1, 0) }
        let harmonic = log(Double(n - 1)) + 0.5772156649 // Euler-Mascheroni
        return 2.0 * harmonic - (2.0 * Double(n - 1) / Double(n))
    }

    private func buildTree(data: [[Double]], depth: Int, maxDepth: Int) -> IsolationNode {
        guard data.count > 1, depth < maxDepth else {
            return .leaf(size: data.count)
        }

        guard let dim = data.first?.count, dim > 0 else {
            return .leaf(size: data.count)
        }

        // Random feature selection
        let featureIndex = Int.random(in: 0..<dim)

        // Get valid (non-missing) values for this feature
        let validValues = data.compactMap { row -> Double? in
            guard featureIndex < row.count else { return nil }
            let v = row[featureIndex]
            return v == FeatureKey.missingSentinel ? nil : v
        }

        guard let minVal = validValues.min(),
              let maxVal = validValues.max(),
              minVal < maxVal else {
            return .leaf(size: data.count)
        }

        // Random split point between min and max
        let splitValue = Double.random(in: minVal...maxVal)

        var leftData: [[Double]] = []
        var rightData: [[Double]] = []

        for row in data {
            let val = featureIndex < row.count ? row[featureIndex] : FeatureKey.missingSentinel
            if val == FeatureKey.missingSentinel {
                // Randomly assign missing values
                if Bool.random() { leftData.append(row) } else { rightData.append(row) }
            } else if val < splitValue {
                leftData.append(row)
            } else {
                rightData.append(row)
            }
        }

        // Prevent degenerate splits
        guard !leftData.isEmpty, !rightData.isEmpty else {
            return .leaf(size: data.count)
        }

        let left = buildTree(data: leftData, depth: depth + 1, maxDepth: maxDepth)
        let right = buildTree(data: rightData, depth: depth + 1, maxDepth: maxDepth)

        return .branch(featureIndex: featureIndex, splitValue: splitValue, left: left, right: right)
    }

    private func randomSubsample(_ data: [[Double]], size: Int) -> [[Double]] {
        guard data.count > size else { return data }
        return Array(data.shuffled().prefix(size))
    }

    // MARK: - Contextual Comparison

    /// Compare a vector against peers with similar context (day-of-week, season)
    private func contextualZScore(vector: DailyFeatureVector) -> Double {
        let calendar = Calendar.current
        let targetWeekday = calendar.component(.weekday, from: vector.date)
        let targetMonth = calendar.component(.month, from: vector.date)

        // Find peer vectors: same weekday ± 1, same season (± 1 month)
        let peers = trainingVectors.filter { v in
            let weekday = calendar.component(.weekday, from: v.date)
            let month = calendar.component(.month, from: v.date)
            let weekdayMatch = abs(weekday - targetWeekday) <= 1 ||
                               abs(weekday - targetWeekday) >= 6 // Handle wrap-around
            let monthDiff = abs(month - targetMonth)
            let monthMatch = monthDiff <= 1 || monthDiff >= 11 // Handle Dec-Jan wrap

            return weekdayMatch && monthMatch
        }

        guard peers.count >= 5 else { return 0 }

        // Compute mean feature vector of peers
        let peerArrays = peers.map { $0.toArray(orderedKeys: trainedKeys) }
        let targetArray = vector.toArray(orderedKeys: trainedKeys)
        let dim = trainedKeys.count

        var meanDist: Double = 0
        var peerDistances: [Double] = []

        // Compute distances between each peer and peer centroid
        var centroid = [Double](repeating: 0, count: dim)
        for arr in peerArrays {
            for i in 0..<dim where arr[i] != FeatureKey.missingSentinel {
                centroid[i] += arr[i] / Double(peerArrays.count)
            }
        }

        for arr in peerArrays {
            let dist = euclideanDistanceIgnoringMissing(arr, centroid)
            peerDistances.append(dist)
        }

        let targetDist = euclideanDistanceIgnoringMissing(targetArray, centroid)
        meanDist = peerDistances.mean
        let stdDist = peerDistances.standardDeviation

        guard stdDist > 0 else { return 0 }
        return (targetDist - meanDist) / stdDist
    }

    private func euclideanDistanceIgnoringMissing(_ a: [Double], _ b: [Double]) -> Double {
        var sumSq: Double = 0
        var count = 0
        for i in 0..<Swift.min(a.count, b.count) {
            if a[i] != FeatureKey.missingSentinel && b[i] != FeatureKey.missingSentinel {
                let diff = a[i] - b[i]
                sumSq += diff * diff
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return (sumSq / Double(count) * Double(a.count)).squareRoot()
    }

    // MARK: - Feature Attribution

    /// Find which features contribute most to anomaly score
    private func findAnomalousFeatures(features: [Double]) -> [(key: FeatureKey, contribution: Double)] {
        guard !trainedKeys.isEmpty else { return [] }

        // Simple approach: for each feature, compute how different it is from training mean
        var contributions: [(key: FeatureKey, contribution: Double)] = []

        let allArrays = trainingVectors.map { $0.toArray(orderedKeys: trainedKeys) }

        for (i, key) in trainedKeys.enumerated() {
            let featureValue = i < features.count ? features[i] : 0
            guard featureValue != FeatureKey.missingSentinel else { continue }

            let trainingValues = allArrays.compactMap { row -> Double? in
                guard i < row.count else { return nil }
                let v = row[i]
                return v == FeatureKey.missingSentinel ? nil : v
            }

            guard !trainingValues.isEmpty else { continue }
            let mean = trainingValues.mean
            let sd = trainingValues.standardDeviation
            guard sd > 0 else { continue }

            let deviation = abs(featureValue - mean) / sd
            if deviation > 1.5 {
                contributions.append((key: key, contribution: deviation))
            }
        }

        return contributions.sorted { $0.contribution > $1.contribution }.prefix(5).map { $0 }
    }

    // MARK: - State

    var isReady: Bool { !forest.isEmpty }
}
