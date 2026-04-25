import Foundation
import Accelerate

/// Gaussian Mixture Model clustering on daily feature vectors to identify distinct health states,
/// with an HMM layer on top for temporally coherent state assignments.
/// - **GMM**: EM algorithm with diagonal covariance and BIC model selection (k=2..7).
/// - **HMM**: Treats GMM posteriors as emissions, learns Laplace-smoothed transition dynamics.
///   Viterbi decoding for MAP state sequence, forward-backward for posterior smoothing.
///   Transition matrix refined via forward-backward ξ estimates.
/// - **State versioning**: Tracks schema version across retrains with old→new state mapping.
final class HealthStateClassifier {
    /// Minimum days of data required
    static let minimumDays = 14

    /// Range of k values to try
    private static let kRange = 2...7
    /// EM convergence threshold (relative log-likelihood improvement)
    private static let emTolerance = 1e-4
    /// Maximum EM iterations
    private static let maxEMIterations = 50
    /// Minimum variance floor to prevent division by zero (scaled to data in fitGMM)
    private static let minVarianceFloor = 1e-6

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
    /// Per-feature medians computed during training for consistent imputation at classify time
    private var trainingMedians: [Double] = []

    /// Last full retrain date
    private var lastRetrainDate: Date?

    // HMM parameters
    /// K x K transition matrix A[i][j] = P(state_j | state_i)
    private(set) var hmmTransitionMatrix: [[Double]] = []
    /// Initial state distribution π
    private var hmmInitialDist: [Double] = []
    /// Viterbi-decoded state sequence (indices into `states`)
    private var viterbiPath: [Int] = []
    /// Forward-backward posterior probabilities per time step: T x K
    private var smoothedPosteriors: [[Double]] = []

    /// Previous centroids for state versioning across retrains
    private var previousCentroids: [[Double]] = []
    /// Previous labels corresponding to previousCentroids
    private var previousLabels: [String] = []
    /// Mapping from old state labels to new state labels after retrain
    private var oldToNewStateMap: [String: String] = [:]
    /// Schema version counter, incremented each retrain
    private var stateSchemaVersion: Int = 0

    /// Hash of input data from last training run. Skip recomputation if unchanged.
    private var lastInputHash: Int = 0

    /// Apple Neural Engine (CoreML) Pipeline
    private let coreMLEngine = CoreMLEngine()

    /// Laplace smoothing parameter for HMM transition matrix (adaptive: 1/k at train time)

    /// Whether a full retrain is needed (never trained, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Training

    /// Train the classifier on daily feature vectors
    func train(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey]) {
        guard vectors.count >= Self.minimumDays else { return }

        // Skip if input data hasn't changed since last successful train
        let inputHash = computeInputHash(vectors: vectors, orderedKeys: orderedKeys)
        if inputHash == lastInputHash && isReady { return }
        lastInputHash = inputHash

        trainedKeys = orderedKeys
        let data = vectors.map { $0.toArray(orderedKeys: orderedKeys) }
        let dim = orderedKeys.count
        guard dim > 0 else { return }

        // Handle missing sentinels: replace with per-feature median (not 0.0, which
        // conflates "missing" with "exactly at mean" in z-score space and biases clusters)
        let featureMedians = computeFeatureMedians(data: data, dim: dim)
        trainingMedians = featureMedians // Store for consistent imputation at classify time
        let cleanData = data.map { row in
            row.enumerated().map { idx, val in
                val == FeatureKey.missingSentinel ? featureMedians[idx] : val
            }
        }

        // BIC model selection: try each k, pick lowest BIC
        var bestBIC = Double.infinity
        var bestMeans: [[Double]] = []
        var bestVariances: [[Double]] = []
        var bestWeights: [Double] = []
        var bestK = 2
        var bestAssignments: [Int] = []

        // Early-stop: once BIC increases for 2 consecutive k values, further k won't improve.
        // This saves ~50% of EM runs in practice (typically best k is 2-4).
        var consecutiveIncreases = 0
        for k in Self.kRange {
            guard k < cleanData.count else { break }
            // Bail out of BIC grid search if device reaches critical thermal state
            if ProcessInfo.processInfo.thermalState == .critical { break }

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
                consecutiveIncreases = 0
            } else {
                consecutiveIncreases += 1
                if consecutiveIncreases >= 2 { break }
            }
        }

        guard !bestMeans.isEmpty else { return }

        // Save previous centroids and labels for state versioning
        if !states.isEmpty {
            previousCentroids = states.map(\.centroid)
            previousLabels = states.map(\.label)
        }

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

        // Build old-to-new state mapping based on centroid proximity
        buildOldToNewStateMap()

        // Build state history and transition matrix (GMM-based)
        buildStateHistory(vectors: vectors, data: cleanData)
        buildTransitionMatrix()

        // Compute GMM posteriors for each observation (emission probabilities for HMM)
        let emissionPosteriors = computeEmissionPosteriors(data: cleanData)

        // Build HMM layer on top of GMM
        buildHMMLayer(emissionPosteriors: emissionPosteriors)

        // Run Viterbi decoding for MAP state sequence
        viterbiPath = viterbiDecode(emissionPosteriors: emissionPosteriors)

        // Run forward-backward for smoothed posteriors
        let (smoothedPost, logAlpha, logBeta) = forwardBackward(emissionPosteriors: emissionPosteriors)
        smoothedPosteriors = smoothedPost

        // Refine transition matrix using forward-backward xi estimates
        refineTransitionMatrix(emissionPosteriors: emissionPosteriors, logAlpha: logAlpha, logBeta: logBeta)

        // Update state history with Viterbi-decoded assignments
        buildSmoothedStateHistory(vectors: vectors)

        // Increment state schema version
        stateSchemaVersion += 1

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

        // Data-adaptive variance floor: 1% of each feature's global variance
        // This prevents zero-variance degeneracy while preserving meaningful differences
        var perFeatureVarFloor = [Double](repeating: Self.minVarianceFloor, count: dim)
        for d in 0..<dim {
            let colValues = (0..<n).map { data[$0][d] }
            let colMean = colValues.reduce(0, +) / Double(n)
            let colVar = colValues.reduce(0.0) { $0 + ($1 - colMean) * ($1 - colMean) } / Double(n)
            perFeatureVarFloor[d] = max(Self.minVarianceFloor, 0.01 * colVar)
        }

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

            // Check convergence (both absolute and relative)
            let improvement = totalLogLikelihood - prevLogLikelihood
            let relativeImprovement = abs(prevLogLikelihood) > 1e-10
                ? abs(improvement / prevLogLikelihood)
                : abs(improvement)
            if improvement >= 0 && (improvement < Self.emTolerance || relativeImprovement < Self.emTolerance) {
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
                    newVar[d] = max(weightedSumSqDiff / Nj, perFeatureVarFloor[d])
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

    /// Classify a single day into a health state using CoreML (Primary) or soft GMM assignment (Fallback)
    func classify(vector: DailyFeatureVector) -> HealthState? {
        // 1. CoreML Neural Inference (Primary Engine)
        if coreMLEngine.isAvailable {
            do {
                let riskScore = try coreMLEngine.predictRisk(vector: vector, orderedKeys: trainedKeys)
                
                // Construct a Neural-assigned state representation
                // In a full implementation, we would extract the ML feature matrix and clustering
                // explicitly from `coreml_classifier`. We use the Risk Score for direct narrative here.
                let stateLabel: String
                if riskScore > 0.75 { stateLabel = "Stressed" }
                else if riskScore > 0.5 { stateLabel = "Fatigued" }
                else if riskScore < 0.2 { stateLabel = "Peak Performance" }
                else { stateLabel = "Recovery" }
                
                return HealthState(
                    label: stateLabel,
                    centroid: [],
                    characteristics: [HealthState.StateCharacteristic(metric: .heartRateVariability, level: riskScore > 0.5 ? .low : .high, zScore: riskScore)],
                    daysInState: 1,
                    transitionProbabilities: [:]
                )
            } catch {
                #if DEBUG
                print("[HealthStateClassifier] CoreML inference failed. Falling back to GMM. Error: \(error)")
                #endif
            }
        }
        
        // 2. GMM Fallback
        guard !means.isEmpty, numComponents > 0 else { return nil }

        // Use training-derived medians for missing values (consistent with train-time imputation)
        let rawFeatures = vector.toArray(orderedKeys: trainedKeys)
        let features = rawFeatures.enumerated().map { idx, val -> Double in
            guard val == FeatureKey.missingSentinel else { return val }
            // Fall back to 0.0 if we don't have stored medians (shouldn't happen post-training)
            guard idx < trainedKeys.count else { return 0.0 }
            return trainingMedians.count > idx ? trainingMedians[idx] : 0.0
        }

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

    /// Compute per-feature median from non-sentinel values for robust missing data imputation.
    /// Falls back to 0.0 only if a feature has no valid observations at all.
    private func computeFeatureMedians(data: [[Double]], dim: Int) -> [Double] {
        var medians = [Double](repeating: 0.0, count: dim)
        for featureIdx in 0..<dim {
            var validValues: [Double] = []
            validValues.reserveCapacity(data.count)
            for row in data {
                guard featureIdx < row.count else { continue }
                let val = row[featureIdx]
                if val != FeatureKey.missingSentinel {
                    validValues.append(val)
                }
            }
            if !validValues.isEmpty {
                validValues.sort()
                let mid = validValues.count / 2
                medians[featureIdx] = validValues.count % 2 == 0
                    ? (validValues[mid - 1] + validValues[mid]) / 2.0
                    : validValues[mid]
            }
        }
        return medians
    }

    private func labelClusters(
        means: [[Double]],
        data: [[Double]],
        assignments: [Int],
        orderedKeys: [FeatureKey]
    ) -> [HealthState] {
        var states: [HealthState] = []

        // Compute per-feature adaptive thresholds from the centroid spread:
        // threshold = max(0.3, stddev(centroid values for feature))
        // This adapts to how much the clusters actually differ on each feature
        var featureThresholds: [Int: Double] = [:]
        for labelInfo in Self.labelMetrics {
            let key = FeatureKey(metric: labelInfo.metric, type: .raw)
            guard let featureIdx = orderedKeys.firstIndex(of: key) else { continue }
            let centroidValues = means.compactMap { featureIdx < $0.count ? $0[featureIdx] : nil }
            guard centroidValues.count >= 2 else { continue }
            let mean = centroidValues.reduce(0, +) / Double(centroidValues.count)
            let variance = centroidValues.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(centroidValues.count)
            featureThresholds[featureIdx] = max(0.3, variance.squareRoot())
        }

        for (clusterIdx, clusterMean) in means.enumerated() {
            var characteristics: [HealthState.StateCharacteristic] = []

            // Find dominant features for this cluster
            for labelInfo in Self.labelMetrics {
                let key = FeatureKey(metric: labelInfo.metric, type: .raw)
                guard let featureIdx = orderedKeys.firstIndex(of: key),
                      featureIdx < clusterMean.count else { continue }

                let zScore = clusterMean[featureIdx]
                let threshold = featureThresholds[featureIdx] ?? 0.5
                let level: HealthState.StateCharacteristic.Level
                if zScore > threshold { level = .high }
                else if zScore < -threshold { level = .low }
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

        // Deterministic fallback: derive a semantic name from the strongest
        // non-normal characteristic so users never see "State N" in the UI.
        let notable = characteristics.filter { $0.level != .normal }
        guard let dominant = notable.max(by: { abs($0.zScore) < abs($1.zScore) }) else {
            return "Balanced"
        }

        switch (dominant.metric, dominant.level) {
        case (.heartRateVariability, .high), (.restingHeartRate, .low), (.vo2Max, .high):
            return "Recovering"
        case (.heartRateVariability, .low), (.restingHeartRate, .high), (.sleepDeep, .low):
            return "Strained"
        case (.activeCalories, .low), (.steps, .low), (.vo2Max, .low):
            return "Low Energy"
        case (.sleepDuration, .high), (.sleepDeep, .high):
            return "Restful"
        case (.activeCalories, .high), (.steps, .high):
            return "Active"
        case (.sleepDuration, .low):
            return "Under-Slept"
        default:
            return "Balanced"
        }
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

    // MARK: - Emission Posteriors

    /// Compute GMM posterior P(z=k|x) for each observation. used as HMM emission probabilities
    private func computeEmissionPosteriors(data: [[Double]]) -> [[Double]] {
        let n = data.count
        let k = numComponents
        var posteriors = [[Double]](repeating: [Double](repeating: 0, count: k), count: n)

        for i in 0..<n {
            var logProbs = [Double](repeating: 0, count: k)
            for j in 0..<k {
                let logPrior = log(max(mixingWeights[j], 1e-300))
                let logLik = AccelerateML.diagonalMVNLogLikelihood(
                    x: data[i], mean: means[j], diagVariance: variances[j]
                )
                logProbs[j] = logPrior + logLik
            }
            posteriors[i] = AccelerateML.softmax(logProbs)
        }

        return posteriors
    }

    // MARK: - HMM Layer

    /// Build HMM layer: initialize transition matrix from observed counts with Laplace smoothing,
    /// and initial state distribution from first observation posteriors.
    private func buildHMMLayer(emissionPosteriors: [[Double]]) {
        let k = numComponents
        guard k > 0, assignments.count >= 2 else { return }

        // Adaptive Laplace smoothing: alpha = 1/k ensures uniform prior has equal weight
        // to observing one full transition per state pair. For k=3 this gives 0.33, for k=7 gives 0.14.
        let alpha = 1.0 / Double(k)

        // Count observed transitions from GMM hard assignments
        var counts = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)
        for t in 0..<(assignments.count - 1) {
            let from = assignments[t]
            let to = assignments[t + 1]
            if from < k && to < k {
                counts[from][to] += 1.0
            }
        }

        // Laplace-smoothed transition matrix: A[i][j] = (count[i][j] + α) / (Σ_j count[i][j] + K*α)
        hmmTransitionMatrix = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)
        for i in 0..<k {
            let rowSum = counts[i].reduce(0, +)
            let denominator = rowSum + Double(k) * alpha
            for j in 0..<k {
                hmmTransitionMatrix[i][j] = (counts[i][j] + alpha) / denominator
            }
        }

        // Initial state distribution from mixing weights
        hmmInitialDist = mixingWeights
    }

    // MARK: - Viterbi Decoding

    /// Viterbi algorithm for MAP state sequence
    /// δ(t,k) = max_j [δ(t-1,j) + log A[j,k]] + log P(x_t|z=k)
    /// ψ(t,k) = argmax_j [δ(t-1,j) + log A[j,k]]
    private func viterbiDecode(emissionPosteriors: [[Double]]) -> [Int] {
        let T = emissionPosteriors.count
        let k = numComponents
        guard T > 0, k > 0, hmmTransitionMatrix.count == k else {
            return assignments
        }

        // Log transition matrix
        let logA = hmmTransitionMatrix.map { row in
            row.map { log(max($0, 1e-300)) }
        }

        // δ and ψ tables: T x K
        var delta = [[Double]](repeating: [Double](repeating: -Double.infinity, count: k), count: T)
        var psi = [[Int]](repeating: [Int](repeating: 0, count: k), count: T)

        // Initialization: δ(0,k) = log π(k) + log P(x_0|k)
        for j in 0..<k {
            let logPi = log(max(hmmInitialDist[j], 1e-300))
            let logEmit = log(max(emissionPosteriors[0][j], 1e-300))
            delta[0][j] = logPi + logEmit
        }

        // Recursion
        for t in 1..<T {
            for j in 0..<k {
                let logEmit = log(max(emissionPosteriors[t][j], 1e-300))
                var bestVal = -Double.infinity
                var bestIdx = 0

                for i in 0..<k {
                    let val = delta[t - 1][i] + logA[i][j]
                    if val > bestVal {
                        bestVal = val
                        bestIdx = i
                    }
                }

                delta[t][j] = bestVal + logEmit
                psi[t][j] = bestIdx
            }
        }

        // Backtracking
        var path = [Int](repeating: 0, count: T)
        // Find argmax of δ(T-1, ·)
        var bestFinal = -Double.infinity
        for j in 0..<k {
            if delta[T - 1][j] > bestFinal {
                bestFinal = delta[T - 1][j]
                path[T - 1] = j
            }
        }

        for t in stride(from: T - 2, through: 0, by: -1) {
            path[t] = psi[t + 1][path[t + 1]]
        }

        return path
    }

    // MARK: - Forward-Backward

    /// Forward-backward algorithm for posterior smoothing (all in log-space for stability).
    /// Returns T x K posterior probabilities γ(t,k) along with log-alpha and log-beta intermediates.
    private func forwardBackward(emissionPosteriors: [[Double]]) -> (posteriors: [[Double]], logAlpha: [[Double]], logBeta: [[Double]]) {
        let T = emissionPosteriors.count
        let k = numComponents
        guard T > 0, k > 0, hmmTransitionMatrix.count == k else {
            let emptyAlpha = [[Double]](repeating: [Double](repeating: -Double.infinity, count: k), count: T)
            let emptyBeta = [[Double]](repeating: [Double](repeating: -Double.infinity, count: k), count: T)
            return (posteriors: emissionPosteriors, logAlpha: emptyAlpha, logBeta: emptyBeta)
        }

        let logA = hmmTransitionMatrix.map { row in
            row.map { log(max($0, 1e-300)) }
        }

        // Forward pass: log α(t,k)
        var logAlpha = [[Double]](repeating: [Double](repeating: -Double.infinity, count: k), count: T)

        // Initialization
        for j in 0..<k {
            let logPi = log(max(hmmInitialDist[j], 1e-300))
            let logEmit = log(max(emissionPosteriors[0][j], 1e-300))
            logAlpha[0][j] = logPi + logEmit
        }

        // Forward recursion: α(t,k) = P(x_t|k) * Σ_j α(t-1,j)*A[j,k]
        for t in 1..<T {
            for j in 0..<k {
                let logEmit = log(max(emissionPosteriors[t][j], 1e-300))
                // log Σ_i α(t-1,i)*A[i,j] = logSumExp over i of (logAlpha[t-1][i] + logA[i][j])
                var terms = [Double](repeating: -Double.infinity, count: k)
                for i in 0..<k {
                    terms[i] = logAlpha[t - 1][i] + logA[i][j]
                }
                logAlpha[t][j] = AccelerateML.logSumExp(terms) + logEmit
            }
        }

        // Backward pass: log β(t,k)
        var logBeta = [[Double]](repeating: [Double](repeating: -Double.infinity, count: k), count: T)

        // Initialization: β(T-1,k) = 0 (log(1) = 0)
        for j in 0..<k {
            logBeta[T - 1][j] = 0.0
        }

        // Backward recursion: β(t,k) = Σ_j A[k,j]*P(x_{t+1}|j)*β(t+1,j)
        for t in stride(from: T - 2, through: 0, by: -1) {
            for i in 0..<k {
                var terms = [Double](repeating: -Double.infinity, count: k)
                for j in 0..<k {
                    let logEmitNext = log(max(emissionPosteriors[t + 1][j], 1e-300))
                    terms[j] = logA[i][j] + logEmitNext + logBeta[t + 1][j]
                }
                logBeta[t][i] = AccelerateML.logSumExp(terms)
            }
        }

        // Posterior: γ(t,k) = α(t,k)*β(t,k) / Σ_k α(t,k)*β(t,k)
        // In log-space: logGamma(t,k) = logAlpha(t,k) + logBeta(t,k) - logSumExp_k(logAlpha(t,k) + logBeta(t,k))
        var posteriors = [[Double]](repeating: [Double](repeating: 0, count: k), count: T)
        for t in 0..<T {
            var logGamma = [Double](repeating: -Double.infinity, count: k)
            for j in 0..<k {
                logGamma[j] = logAlpha[t][j] + logBeta[t][j]
            }
            let logNorm = AccelerateML.logSumExp(logGamma)
            for j in 0..<k {
                posteriors[t][j] = exp(logGamma[j] - logNorm)
            }
        }

        return (posteriors: posteriors, logAlpha: logAlpha, logBeta: logBeta)
    }

    // MARK: - Smoothed Transition Matrix Refinement

    /// Refine transition matrix using forward-backward ξ(t,i,j) estimates:
    /// ξ(t,i,j) = α(t,i) * A[i,j] * P(x_{t+1}|j) * β(t+1,j) / P(observations)
    private func refineTransitionMatrix(emissionPosteriors: [[Double]], logAlpha: [[Double]], logBeta: [[Double]]) {
        let T = emissionPosteriors.count
        let k = numComponents
        guard T > 1, k > 0, hmmTransitionMatrix.count == k else { return }

        let logA = hmmTransitionMatrix.map { row in
            row.map { log(max($0, 1e-300)) }
        }

        // Log-likelihood of entire sequence P(O|λ) = logSumExp_k(logAlpha[T-1][k])
        let logPObs = AccelerateML.logSumExp(logAlpha[T - 1])

        // Accumulate ξ in log-space, then exponentiate
        var xiSum = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)

        for t in 0..<(T - 1) {
            for i in 0..<k {
                for j in 0..<k {
                    let logEmitNext = log(max(emissionPosteriors[t + 1][j], 1e-300))
                    let logXi = logAlpha[t][i] + logA[i][j] + logEmitNext + logBeta[t + 1][j] - logPObs
                    xiSum[i][j] += exp(logXi)
                }
            }
        }

        // Normalize rows to get refined transition probabilities
        for i in 0..<k {
            let rowSum = xiSum[i].reduce(0, +)
            guard rowSum > 1e-10 else { continue }
            for j in 0..<k {
                hmmTransitionMatrix[i][j] = xiSum[i][j] / rowSum
            }
        }

        // Update the string-based transition matrix to match
        transitionMatrix = [:]
        for i in 0..<k {
            guard i < states.count else { continue }
            var row: [String: Double] = [:]
            for j in 0..<k {
                guard j < states.count else { continue }
                row[states[j].label] = hmmTransitionMatrix[i][j]
            }
            transitionMatrix[states[i].label] = row
        }

        // Update states with refined transition probabilities
        states = states.enumerated().map { (idx, state) in
            HealthState(
                label: state.label,
                centroid: state.centroid,
                characteristics: state.characteristics,
                daysInState: state.daysInState,
                transitionProbabilities: transitionMatrix[state.label] ?? [:]
            )
        }
    }

    /// Rebuild state history using Viterbi-decoded path
    private func buildSmoothedStateHistory(vectors: [DailyFeatureVector]) {
        stateHistory = []
        for (i, vector) in vectors.enumerated() {
            guard i < viterbiPath.count, viterbiPath[i] < states.count else { continue }
            stateHistory.append((date: vector.date, label: states[viterbiPath[i]].label))
        }
    }

    // MARK: - State Versioning

    /// Build mapping from old state labels to new state labels based on centroid proximity
    private func buildOldToNewStateMap() {
        oldToNewStateMap = [:]
        guard !previousCentroids.isEmpty, !states.isEmpty else { return }

        for (oldIdx, oldCentroid) in previousCentroids.enumerated() {
            guard oldIdx < previousLabels.count else { continue }
            let oldLabel = previousLabels[oldIdx]

            // Find the new state whose centroid is closest to the old centroid
            var bestDist = Double.infinity
            var bestNewLabel = ""

            for newState in states {
                let dim = min(oldCentroid.count, newState.centroid.count)
                guard dim > 0 else { continue }
                let oldTrunc = Array(oldCentroid.prefix(dim))
                let newTrunc = Array(newState.centroid.prefix(dim))
                let dist = AccelerateML.squaredDistance(oldTrunc, newTrunc)
                if dist < bestDist {
                    bestDist = dist
                    bestNewLabel = newState.label
                }
            }

            if !bestNewLabel.isEmpty {
                oldToNewStateMap[oldLabel] = bestNewLabel
            }
        }
    }

    /// Map an old state label to the corresponding new state label after retrain
    func mapOldStateToNew(oldLabel: String) -> String? {
        oldToNewStateMap[oldLabel]
    }

    // MARK: - Smoothed State History & Classification

    /// Return the full Viterbi-decoded + forward-backward-smoothed state history
    func smoothedStateHistory(vectors: [DailyFeatureVector], dates: [Date]) -> [SmoothedHealthState] {
        let k = numComponents
        guard k > 0, !states.isEmpty, !viterbiPath.isEmpty, !smoothedPosteriors.isEmpty else {
            return []
        }

        let T = min(vectors.count, min(viterbiPath.count, smoothedPosteriors.count))
        guard T > 0 else { return [] }

        var result: [SmoothedHealthState] = []
        var lastStateIdx = viterbiPath[0]
        var daysSinceLastTransition = 0

        for t in 0..<T {
            let stateIdx = viterbiPath[t]
            guard stateIdx < states.count else { continue }

            let isTransition = (t > 0 && stateIdx != lastStateIdx)
            if isTransition {
                daysSinceLastTransition = 0
                lastStateIdx = stateIdx
            } else if t > 0 {
                daysSinceLastTransition += 1
            }

            // Build state posteriors dictionary
            var posteriorDict: [String: Double] = [:]
            for j in 0..<k {
                guard j < states.count else { continue }
                posteriorDict[states[j].label] = smoothedPosteriors[t][j]
            }

            // Build smoothed transition probabilities for the assigned state
            var transProbs: [String: Double] = [:]
            if stateIdx < hmmTransitionMatrix.count {
                for j in 0..<k {
                    guard j < states.count else { continue }
                    transProbs[states[j].label] = hmmTransitionMatrix[stateIdx][j]
                }
            }

            let date = t < dates.count ? dates[t] : vectors[t].date
            result.append(SmoothedHealthState(
                date: date,
                assignedState: states[stateIdx],
                statePosteriors: posteriorDict,
                smoothedTransitionProb: transProbs,
                isTransitionDay: isTransition,
                daysSinceTransition: daysSinceLastTransition
            ))
        }

        return result
    }

    /// Classify the latest day with HMM-smoothed temporal coherence
    func classifySmoothed(vectors: [DailyFeatureVector], dates: [Date]) -> SmoothedHealthState? {
        guard vectors.count >= Self.minimumDays, !means.isEmpty, numComponents > 0 else {
            return nil
        }

        let dim = trainedKeys.count
        let data = vectors.map { $0.toArray(orderedKeys: trainedKeys) }
        let featureMedians = computeFeatureMedians(data: data, dim: dim)
        let cleanData = data.map { row in
            row.enumerated().map { idx, val in
                val == FeatureKey.missingSentinel ? featureMedians[idx] : val
            }
        }

        // Compute emission posteriors for the full sequence
        let emissions = computeEmissionPosteriors(data: cleanData)

        // Run Viterbi on the full sequence
        let path = viterbiDecode(emissionPosteriors: emissions)

        // Run forward-backward for posteriors
        let (posteriors, _, _) = forwardBackward(emissionPosteriors: emissions)

        guard let lastIdx = path.last, lastIdx < states.count,
              let lastPosterior = posteriors.last else {
            return nil
        }

        let k = numComponents

        // Build posterior dict
        var posteriorDict: [String: Double] = [:]
        for j in 0..<k {
            guard j < states.count else { continue }
            posteriorDict[states[j].label] = lastPosterior[j]
        }

        // Transition probs from last state
        var transProbs: [String: Double] = [:]
        if lastIdx < hmmTransitionMatrix.count {
            for j in 0..<k {
                guard j < states.count else { continue }
                transProbs[states[j].label] = hmmTransitionMatrix[lastIdx][j]
            }
        }

        // Determine transition info from path
        let T = path.count
        var daysSince = 0
        var isTransition = false
        if T >= 2 {
            isTransition = (path[T - 1] != path[T - 2])
            if isTransition {
                daysSince = 0
            } else {
                // Count backwards
                var d = 0
                for t in stride(from: T - 2, through: 0, by: -1) {
                    if path[t] == path[T - 1] {
                        d += 1
                    } else {
                        break
                    }
                }
                daysSince = d
            }
        }

        let date = dates.count == vectors.count ? dates[T - 1] : vectors[T - 1].date
        return SmoothedHealthState(
            date: date,
            assignedState: states[lastIdx],
            statePosteriors: posteriorDict,
            smoothedTransitionProb: transProbs,
            isTransitionDay: isTransition,
            daysSinceTransition: daysSince
        )
    }

    // MARK: - Transition Pattern Explanations

    /// Generate a human-readable description of the transition pattern between two states
    func describeTransitionPattern(from fromLabel: String, to toLabel: String) -> String {
        // Look up transition probability
        let prob = transitionMatrix[fromLabel]?[toLabel]

        // Gather characteristics for both states
        let fromState = states.first { $0.label == fromLabel }
        let toState = states.first { $0.label == toLabel }

        guard let fromState, let toState else {
            return "Transition from \(fromLabel) to \(toLabel) not observed."
        }

        // Compute average duration in destination state from history
        var durations: [Int] = []
        var currentRun = 0
        var inTarget = false
        for entry in stateHistory {
            if entry.label == toLabel {
                if !inTarget {
                    // Check if previous was fromLabel
                    inTarget = true
                    currentRun = 1
                } else {
                    currentRun += 1
                }
            } else {
                if inTarget && currentRun > 0 {
                    durations.append(currentRun)
                }
                inTarget = false
                currentRun = 0
            }
        }
        if inTarget && currentRun > 0 {
            durations.append(currentRun)
        }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count

        // Dominant characteristics of each state
        let fromTraits = fromState.characteristics
            .filter { $0.level != .normal }
            .prefix(2)
            .map { trait -> String in
                let levelStr = trait.level == .high ? "High" : "Low"
                return "\(levelStr) \(trait.metric.displayName)"
            }

        let toTraits = toState.characteristics
            .filter { $0.level != .normal }
            .prefix(2)
            .map { trait -> String in
                let levelStr = trait.level == .high ? "High" : "Low"
                return "\(levelStr) \(trait.metric.displayName)"
            }

        let fromDesc = fromTraits.isEmpty ? fromLabel : fromTraits.joined(separator: " + ")
        let toDesc = toTraits.isEmpty ? toLabel : toTraits.joined(separator: " + ")

        var description = "You typically move from \(fromDesc) into"

        if avgDuration > 1 {
            description += " a \(avgDuration)-day \(toLabel.lowercased()) state"
        } else {
            description += " \(toLabel.lowercased())"
        }

        if let prob, prob > 0 {
            let pct = Int(prob * 100)
            description += " (\(pct)% of the time)"
        }

        description += "."

        // Add dominant trait shift
        if !toTraits.isEmpty {
            description += " Key shift: \(toDesc)."
        }

        return description
    }

    // MARK: - State

    var isReady: Bool { !means.isEmpty && numComponents > 0 }

    /// Most likely next state based on transition probabilities
    func predictNextState() -> (label: String, probability: Double)? {
        guard let current = currentState,
              let transitions = transitionMatrix[current.label] else { return nil }

        return transitions.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - Input Hashing

    /// Lightweight hash of input data to skip recomputation when unchanged.
    private func computeInputHash(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey]) -> Int {
        var hasher = Hasher()
        hasher.combine(vectors.count)
        hasher.combine(orderedKeys.count)
        if let first = vectors.first {
            hasher.combine(first.date.timeIntervalSinceReferenceDate)
        }
        if let last = vectors.last {
            hasher.combine(last.date.timeIntervalSinceReferenceDate)
        }
        // Sample a few values from middle of dataset for collision resistance
        let mid = vectors.count / 2
        if mid < vectors.count {
            let midArray = vectors[mid].toArray(orderedKeys: orderedKeys)
            for value in midArray.prefix(4) {
                hasher.combine(value)
            }
        }
        return hasher.finalize()
    }
}
