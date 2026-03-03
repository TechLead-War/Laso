import Foundation

/// K-means clustering on daily feature vectors to identify distinct health states.
/// Auto-selects k (3-7) via silhouette score and auto-labels clusters by dominant feature patterns.
final class HealthStateClassifier {
    /// Minimum days of data required
    static let minimumDays = 60

    /// Range of k values to try
    private static let kRange = 3...7

    /// Current health state
    private(set) var currentState: HealthState?
    /// All identified states
    private(set) var states: [HealthState] = []
    /// State transition matrix
    private(set) var transitionMatrix: [String: [String: Double]] = [:]
    /// State history (date → state label)
    private(set) var stateHistory: [(date: Date, label: String)] = []

    /// Trained centroids per cluster
    private var centroids: [[Double]] = []
    /// Cluster assignments for training data
    private var assignments: [Int] = []
    /// Feature keys used during training
    private var trainedKeys: [FeatureKey] = []

    /// Last full retrain date — guards against retraining too frequently
    private var lastRetrainDate: Date?

    /// Whether a full retrain is needed (never trained, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Training

    /// Train the classifier on daily feature vectors
    func train(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey]) {
        guard vectors.count >= Self.minimumDays else { return }

        trainedKeys = orderedKeys
        let data = vectors.map { $0.toArray(orderedKeys: orderedKeys) }
        let dim = orderedKeys.count
        guard dim > 0 else { return }

        // Replace missing sentinels with 0 for clustering
        let cleanData = data.map { row in
            row.map { $0 == FeatureKey.missingSentinel ? 0.0 : $0 }
        }

        // Auto-select k via silhouette score
        var bestSilhouette = -1.0
        var bestCentroids: [[Double]] = []
        var bestAssignments: [Int] = []

        for k in Self.kRange {
            guard k < cleanData.count else { break }

            let (c, a) = kMeansPlusPlus(data: cleanData, k: k, dim: dim, maxIterations: 50)
            let sil = silhouetteScore(data: cleanData, assignments: a, centroids: c)

            if sil > bestSilhouette {
                bestSilhouette = sil
                bestCentroids = c
                bestAssignments = a
            }
        }

        centroids = bestCentroids
        assignments = bestAssignments

        // Label clusters and build states
        states = labelClusters(centroids: bestCentroids, data: cleanData,
                               assignments: bestAssignments, orderedKeys: orderedKeys)

        // Build state history and transition matrix
        buildStateHistory(vectors: vectors, data: cleanData)
        buildTransitionMatrix()

        // Classify the most recent day
        if let lastVector = vectors.last {
            currentState = classify(vector: lastVector)
        }

        lastRetrainDate = Date()
    }

    // MARK: - Classification

    /// Classify a single day into a health state
    func classify(vector: DailyFeatureVector) -> HealthState? {
        guard !centroids.isEmpty else { return nil }

        let features = vector.toArray(orderedKeys: trainedKeys)
            .map { $0 == FeatureKey.missingSentinel ? 0.0 : $0 }

        let nearest = findNearestCentroid(features)
        guard nearest < states.count else { return nil }

        return states[nearest]
    }

    // MARK: - K-Means++ Implementation

    private func kMeansPlusPlus(
        data: [[Double]], k: Int, dim: Int, maxIterations: Int
    ) -> (centroids: [[Double]], assignments: [Int]) {
        let n = data.count
        guard n > k else { return (data, Array(0..<n)) }

        // K-means++ initialization
        var centroids: [[Double]] = []

        // First centroid: random
        centroids.append(data[Int.random(in: 0..<n)])

        // Remaining centroids: weighted by distance squared
        for _ in 1..<k {
            var distances = [Double](repeating: Double.infinity, count: n)
            for i in 0..<n {
                for c in centroids {
                    let d = AccelerateML.squaredDistance(data[i], c)
                    distances[i] = Swift.min(distances[i], d)
                }
            }

            let totalDist = AccelerateML.sum(distances)
            guard totalDist > 0 else { break }

            // Weighted random selection
            let target = Double.random(in: 0..<totalDist)
            var cumSum: Double = 0
            var selected = 0
            for i in 0..<n {
                cumSum += distances[i]
                if cumSum >= target {
                    selected = i
                    break
                }
            }
            centroids.append(data[selected])
        }

        // K-means iterations
        var assignments = [Int](repeating: 0, count: n)

        for _ in 0..<maxIterations {
            // Assign points to nearest centroid
            var changed = false
            for i in 0..<n {
                let nearest = findNearest(point: data[i], centroids: centroids)
                if nearest != assignments[i] {
                    assignments[i] = nearest
                    changed = true
                }
            }

            guard changed else { break }

            // Update centroids
            var newCentroids = [[Double]](repeating: [Double](repeating: 0, count: dim), count: k)
            var counts = [Int](repeating: 0, count: k)

            for i in 0..<n {
                let c = assignments[i]
                counts[c] += 1
                for d in 0..<dim {
                    newCentroids[c][d] += data[i][d]
                }
            }

            for c in 0..<k {
                if counts[c] > 0 {
                    for d in 0..<dim {
                        newCentroids[c][d] /= Double(counts[c])
                    }
                    centroids[c] = newCentroids[c]
                }
            }
        }

        return (centroids, assignments)
    }

    private func findNearest(point: [Double], centroids: [[Double]]) -> Int {
        var minDist = Double.infinity
        var nearest = 0
        for (i, c) in centroids.enumerated() {
            let d = AccelerateML.squaredDistance(point, c)
            if d < minDist {
                minDist = d
                nearest = i
            }
        }
        return nearest
    }

    private func findNearestCentroid(_ features: [Double]) -> Int {
        findNearest(point: features, centroids: centroids)
    }

    // MARK: - Silhouette Score

    private func silhouetteScore(data: [[Double]], assignments: [Int], centroids: [[Double]]) -> Double {
        let n = data.count
        let k = centroids.count
        guard n > k, k > 1 else { return 0 }

        var totalSilhouette: Double = 0
        var count = 0

        // Sample for performance (max 200 points)
        let sampleIndices: [Int]
        if n > 200 {
            sampleIndices = Array((0..<n).shuffled().prefix(200))
        } else {
            sampleIndices = Array(0..<n)
        }

        for i in sampleIndices {
            let cluster = assignments[i]

            // a(i) = mean distance to same cluster
            var sameCluster: [Int] = []
            for j in 0..<n where assignments[j] == cluster && j != i {
                sameCluster.append(j)
            }
            guard !sameCluster.isEmpty else { continue }

            let a = sameCluster.map { AccelerateML.euclideanDistance(data[i], data[$0]) }.mean

            // b(i) = min mean distance to other clusters
            var minB = Double.infinity
            for c in 0..<k where c != cluster {
                let otherMembers = (0..<n).filter { assignments[$0] == c }
                guard !otherMembers.isEmpty else { continue }
                let meanDist = otherMembers.map { AccelerateML.euclideanDistance(data[i], data[$0]) }.mean
                minB = Swift.min(minB, meanDist)
            }

            guard minB.isFinite else { continue }
            let s = (minB - a) / max(a, minB)
            totalSilhouette += s
            count += 1
        }

        return count > 0 ? totalSilhouette / Double(count) : 0
    }

    // MARK: - Auto-Labeling

    /// Key metrics used for state labeling
    private static let labelMetrics: [(metric: HealthMetric, highLabel: String, lowLabel: String)] = [
        (.heartRateVariability, "High HRV", "Low HRV"),
        (.restingHeartRate, "High RHR", "Low RHR"),
        (.sleepDuration, "Long Sleep", "Short Sleep"),
        (.sleepDeep, "Deep Sleep Rich", "Low Deep Sleep"),
        (.activeCalories, "High Activity", "Low Activity"),
        (.steps, "High Steps", "Low Steps"),
        (.vo2Max, "High VO2", "Low VO2"),
    ]

    private func labelClusters(
        centroids: [[Double]],
        data: [[Double]],
        assignments: [Int],
        orderedKeys: [FeatureKey]
    ) -> [HealthState] {
        var states: [HealthState] = []

        for (clusterIdx, centroid) in centroids.enumerated() {
            var characteristics: [HealthState.StateCharacteristic] = []

            // Find dominant features for this cluster
            for labelInfo in Self.labelMetrics {
                let key = FeatureKey(metric: labelInfo.metric, type: .raw)
                guard let featureIdx = orderedKeys.firstIndex(of: key),
                      featureIdx < centroid.count else { continue }

                let zScore = centroid[featureIdx]
                let level: HealthState.StateCharacteristic.Level
                if zScore > 0.5 { level = .high }
                else if zScore < -0.5 { level = .low }
                else { level = .normal }

                characteristics.append(HealthState.StateCharacteristic(
                    metric: labelInfo.metric, level: level, zScore: zScore
                ))
            }

            // Auto-generate label from dominant characteristics
            let label = generateLabel(characteristics: characteristics, clusterIndex: clusterIdx)

            // Count days in this cluster
            let daysInState = assignments.filter { $0 == clusterIdx }.count

            states.append(HealthState(
                label: label,
                centroid: centroid,
                characteristics: characteristics,
                daysInState: daysInState,
                transitionProbabilities: [:] // Filled later
            ))
        }

        return states
    }

    private func generateLabel(
        characteristics: [HealthState.StateCharacteristic],
        clusterIndex: Int
    ) -> String {
        let highHRV = characteristics.first { $0.metric == .heartRateVariability }?.level == .high
        let lowHRV = characteristics.first { $0.metric == .heartRateVariability }?.level == .low
        let highRHR = characteristics.first { $0.metric == .restingHeartRate }?.level == .high
        let lowRHR = characteristics.first { $0.metric == .restingHeartRate }?.level == .low
        let longSleep = characteristics.first { $0.metric == .sleepDuration }?.level == .high
        let shortSleep = characteristics.first { $0.metric == .sleepDuration }?.level == .low
        let highActivity = characteristics.first { $0.metric == .activeCalories }?.level == .high

        // Pattern matching for common states
        if highHRV && longSleep && lowRHR {
            return "Recovery"
        } else if highHRV && highActivity {
            return "Peak Performance"
        } else if lowHRV && highRHR && shortSleep {
            return "Stressed"
        } else if shortSleep && !highActivity {
            return "Under-Slept"
        } else if highActivity && !longSleep {
            return "Active"
        } else if lowHRV && !highRHR {
            return "Fatigued"
        } else if longSleep && !highActivity {
            return "Resting"
        }

        return "State \(clusterIndex + 1)"
    }

    // MARK: - State History & Transitions

    private func buildStateHistory(vectors: [DailyFeatureVector], data: [[Double]]) {
        stateHistory = []
        for (i, vector) in vectors.enumerated() {
            guard i < assignments.count, assignments[i] < states.count else { continue }
            stateHistory.append((date: vector.date, label: states[assignments[i]].label))
        }
    }

    private func buildTransitionMatrix() {
        guard stateHistory.count >= 2 else { return }

        var counts: [String: [String: Int]] = [:]
        let labels = Set(stateHistory.map(\.label))
        for label in labels {
            counts[label] = [:]
        }

        for i in 0..<(stateHistory.count - 1) {
            let from = stateHistory[i].label
            let to = stateHistory[i + 1].label
            counts[from, default: [:]][to, default: 0] += 1
        }

        // Normalize to probabilities
        transitionMatrix = [:]
        for (from, transitions) in counts {
            let total = Double(transitions.values.reduce(0, +))
            guard total > 0 else { continue }
            transitionMatrix[from] = Dictionary(uniqueKeysWithValues:
                transitions.map { ($0.key, Double($0.value) / total) }
            )
        }

        // Update states with transition probabilities
        states = states.map { state in
            HealthState(
                label: state.label,
                centroid: state.centroid,
                characteristics: state.characteristics,
                daysInState: state.daysInState,
                transitionProbabilities: transitionMatrix[state.label] ?? [:]
            )
        }
    }

    // MARK: - State

    var isReady: Bool { !centroids.isEmpty }

    /// Most likely next state based on transition probabilities
    func predictNextState() -> (label: String, probability: Double)? {
        guard let current = currentState,
              let transitions = transitionMatrix[current.label] else { return nil }

        return transitions.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
}
