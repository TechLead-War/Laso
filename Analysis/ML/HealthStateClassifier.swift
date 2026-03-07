import Foundation
import Accelerate

/// Gaussian Mixture Model clustering on daily feature vectors to identify distinct health states.
/// Uses EM algorithm with diagonal covariance and BIC model selection (k=2..7).
/// Replaces K-means with soft probabilistic assignments for better state identification.
final class HealthStateClassifier {
    /// Minimum days of data required
    static let minimumDays = 60

    /// Range of k values to try
    private static let kRange = 2...7
    /// EM convergence threshold
    private static let emTolerance = 1e-6
    /// Maximum EM iterations
    private static let maxEMIterations = 100
    /// Variance floor to prevent division by zero
    private static let varianceFloor = 1e-6

    /// Current health state
    private(set) var currentState: HealthState?
    /// All identified states
    private(set) var states: [HealthState] = []
    /// State transition matrix
    private(set) var transitionMatrix: [String: [String: Double]] = [:]
    /// State history (date -> state label)
    private(set) var stateHistory: [(date: Date, label: String)] = []

    // GMM parameters
    private var means: [[Double]] = []         // k x d
    private var variances: [[Double]] = []     // k x d (diagonal covariance)
    private var mixingWeights: [Double] = []   // k
    private var numComponents: Int = 0

    /// Hard assignments for training data
    private var assignments: [Int] = []
    /// Feature keys used during training
    private var trainedKeys: [FeatureKey] = []

    /// Last full retrain date
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

        // BIC model selection: try each k, pick lowest BIC
        var bestBIC = Double.infinity
        var bestMeans: [[Double]] = []
        var bestVariances: [[Double]] = []
        var bestWeights: [Double] = []
        var bestK = 2
        var bestAssignments: [Int] = []

        for k in Self.kRange {
            guard k < cleanData.count else { break }

            let result = fitGMM(data: cleanData, k: k, dim: dim)
            guard let result else { continue }

            let bic = computeBIC(
                logLikelihood: result.logLikelihood,
                k: k, dim: dim, n: cleanData.count
            )

            if bic < bestBIC {
                bestBIC = bic
                bestMeans = result.means
                bestVariances = result.variances
                bestWeights = result.weights
                bestK = k
                bestAssignments = result.assignments
            }
        }

        guard !bestMeans.isEmpty else { return }

        means = bestMeans
        variances = bestVariances
        mixingWeights = bestWeights
        numComponents = bestK
        assignments = bestAssignments

        // Label clusters and build states
        states = labelClusters(
            means: bestMeans, data: cleanData,
            assignments: bestAssignments, orderedKeys: orderedKeys
        )

        // Build state history and transition matrix
        buildStateHistory(vectors: vectors, data: cleanData)
        buildTransitionMatrix()

        // Classify the most recent day
        if let lastVector = vectors.last {
            currentState = classify(vector: lastVector)
        }

        lastRetrainDate = Date()
    }

    // MARK: - GMM Fitting (EM Algorithm)

    private struct GMMResult {
        let means: [[Double]]
        let variances: [[Double]]
        let weights: [Double]
        let assignments: [Int]
        let logLikelihood: Double
    }

    private func fitGMM(data: [[Double]], k: Int, dim: Int) -> GMMResult? {
        let n = data.count
        guard n > k, dim > 0 else { return nil }

        // Initialize with K-means++ seeding for stable starting points
        var currentMeans = kMeansPlusPlusInit(data: data, k: k, dim: dim)
        var currentVariances = [[Double]](
            repeating: [Double](repeating: 1.0, count: dim), count: k
        )
        var currentWeights = [Double](repeating: 1.0 / Double(k), count: k)

        // Responsibilities: n x k
        var responsibilities = [[Double]](
            repeating: [Double](repeating: 0, count: k), count: n
        )

        var prevLogLikelihood = -Double.infinity

        for _ in 0..<Self.maxEMIterations {
            // E-step: compute responsibilities
            var totalLogLikelihood = 0.0

            for i in 0..<n {
                var logProbs = [Double](repeating: 0, count: k)

                for j in 0..<k {
                    let logPrior = log(max(currentWeights[j], 1e-300))
                    let logLik = AccelerateML.diagonalMVNLogLikelihood(
                        x: data[i], mean: currentMeans[j], diagVariance: currentVariances[j]
                    )
                    logProbs[j] = logPrior + logLik
                }

                // Normalize responsibilities using softmax (numerically stable)
                let resp = AccelerateML.softmax(logProbs)
                responsibilities[i] = resp

                // Accumulate log-likelihood using log-sum-exp
                totalLogLikelihood += AccelerateML.logSumExp(logProbs)
            }

            // Check convergence
            let improvement = totalLogLikelihood - prevLogLikelihood
            if improvement >= 0 && improvement < Self.emTolerance {
                break
            }
            prevLogLikelihood = totalLogLikelihood

            // M-step: update parameters
            for j in 0..<k {
                // Extract responsibilities for component j
                let rj = (0..<n).map { responsibilities[$0][j] }

                // Effective count
                var Nj: Double = 0
                vDSP_sveD(rj, 1, &Nj, vDSP_Length(n))
                guard Nj > 1e-10 else { continue }

                // Update weight
                currentWeights[j] = Nj / Double(n)

                // Update mean: weighted mean of data points
                var newMean = [Double](repeating: 0, count: dim)
                for d in 0..<dim {
                    let colValues = (0..<n).map { data[$0][d] }
                    newMean[d] = AccelerateML.weightedMean(colValues, weights: rj)
                }
                currentMeans[j] = newMean

                // Update variance: weighted variance with floor
                var newVar = [Double](repeating: 0, count: dim)
                for d in 0..<dim {
                    var weightedSumSqDiff: Double = 0
                    for i in 0..<n {
                        let diff = data[i][d] - newMean[d]
                        weightedSumSqDiff += rj[i] * diff * diff
                    }
                    newVar[d] = max(weightedSumSqDiff / Nj, Self.varianceFloor)
                }
                currentVariances[j] = newVar
            }
        }

        // Hard assignments via argmax of responsibilities
        let hardAssignments = responsibilities.map { AccelerateML.argmax($0) }

        return GMMResult(
            means: currentMeans,
            variances: currentVariances,
            weights: currentWeights,
            assignments: hardAssignments,
            logLikelihood: prevLogLikelihood
        )
    }

    // MARK: - BIC

    /// BIC = -2 * logL + numParams * ln(n)
    /// For diagonal GMM: numParams = k * (2*d + 1) - 1
    /// (k means of dim d, k variances of dim d, k-1 free mixing weights)
    private func computeBIC(logLikelihood: Double, k: Int, dim: Int, n: Int) -> Double {
        let numParams = Double(k * (2 * dim + 1) - 1)
        return -2.0 * logLikelihood + numParams * log(Double(n))
    }

    // MARK: - K-Means++ Initialization

    private func kMeansPlusPlusInit(data: [[Double]], k: Int, dim: Int) -> [[Double]] {
        let n = data.count
        var centers: [[Double]] = []

        // First center: random
        centers.append(data[Int.random(in: 0..<n)])

        // Remaining centers: weighted by distance squared
        for _ in 1..<k {
            var distances = [Double](repeating: Double.infinity, count: n)
            for i in 0..<n {
                for c in centers {
                    let d = AccelerateML.squaredDistance(data[i], c)
                    distances[i] = Swift.min(distances[i], d)
                }
            }

            let totalDist = AccelerateML.sum(distances)
            guard totalDist > 0 else { break }

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
            centers.append(data[selected])
        }

        return centers
    }

    // MARK: - Classification

    /// Classify a single day into a health state using soft GMM assignment
    func classify(vector: DailyFeatureVector) -> HealthState? {
        guard !means.isEmpty, numComponents > 0 else { return nil }

        let features = vector.toArray(orderedKeys: trainedKeys)
            .map { $0 == FeatureKey.missingSentinel ? 0.0 : $0 }

        // Compute log-posterior for each component
        var logProbs = [Double](repeating: 0, count: numComponents)
        for j in 0..<numComponents {
            let logPrior = log(max(mixingWeights[j], 1e-300))
            let logLik = AccelerateML.diagonalMVNLogLikelihood(
                x: features, mean: means[j], diagVariance: variances[j]
            )
            logProbs[j] = logPrior + logLik
        }

        let nearest = AccelerateML.argmax(logProbs)
        guard nearest < states.count else { return nil }

        return states[nearest]
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
        means: [[Double]],
        data: [[Double]],
        assignments: [Int],
        orderedKeys: [FeatureKey]
    ) -> [HealthState] {
        var states: [HealthState] = []

        for (clusterIdx, clusterMean) in means.enumerated() {
            var characteristics: [HealthState.StateCharacteristic] = []

            // Find dominant features for this cluster
            for labelInfo in Self.labelMetrics {
                let key = FeatureKey(metric: labelInfo.metric, type: .raw)
                guard let featureIdx = orderedKeys.firstIndex(of: key),
                      featureIdx < clusterMean.count else { continue }

                let zScore = clusterMean[featureIdx]
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
                centroid: clusterMean,
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

    var isReady: Bool { !means.isEmpty && numComponents > 0 }

    /// Most likely next state based on transition probabilities
    func predictNextState() -> (label: String, probability: Double)? {
        guard let current = currentState,
              let transitions = transitionMatrix[current.label] else { return nil }

        return transitions.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
}
