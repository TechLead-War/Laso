import Foundation

/// Isolation Forest anomaly detector with contextual conditioning, persistence gating,
/// and cross-signal confirmation.
/// Learns "normal for this user on a Monday after a hard workout" instead of using static thresholds.
final class AdaptiveAnomalyDetector {
    /// Minimum days of data required
    static let minimumDays = 14

    /// Number of isolation trees
    private static let numTrees = 50
    /// Subsample size for each tree
    private static let subSampleSize = 256
    /// Minimum peers required for a context bucket to be valid
    private static let minBucketPeers = 5

    // MARK: - Severity Levels

    /// Severity classification for anomaly detection
    enum AnomalySeverity: Int, Comparable {
        case none = 0, info = 1, warning = 2, critical = 3
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    // MARK: - Cross-Signal Confirmation Groups

    /// Groups of correlated metrics for cross-signal confirmation
    private static let confirmationGroups: [[HealthMetric]] = [
        [.heartRateVariability, .restingHeartRate, .heartRate],
        [.sleepDuration, .sleepDeep, .sleepREM],
        [.steps, .activeCalories, .exerciseMinutes],
    ]

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
    /// Baselines provided during training for context computation
    private var trainedBaselines: [HealthMetric: UserBaseline] = [:]

    /// Cached per-feature training statistics (computed once in train(), reused in score()).
    /// Eliminates 7x redundant full-dataset conversion + mean/std computation per pipeline.
    private var cachedTrainingMeans: [Double] = []
    private var cachedTrainingStds: [Double] = []
    /// Cached global centroid for legacyContextualZScore fallback path
    private var cachedCentroid: [Double] = []
    private var cachedPeerDistanceMean: Double = 0
    private var cachedPeerDistanceStd: Double = 0

    // MARK: - Context Buckets

    /// A context vector describing the conditions of a specific day
    private struct DayContext {
        let isWeekend: Bool
        let hadIntenseExercise: Bool
        let hasSleepDebt: Bool

        /// Human-readable bucket label
        var bucketLabel: String {
            var parts: [String] = []
            parts.append(isWeekend ? "weekend" : "weekday")
            if hadIntenseExercise { parts.append("intense") }
            if hasSleepDebt { parts.append("sleepdebt") }
            if !hadIntenseExercise && !hasSleepDebt { parts.append("normal") }
            return parts.joined(separator: "_")
        }

        /// Whether two contexts belong to the same bucket
        func matches(_ other: DayContext) -> Bool {
            isWeekend == other.isWeekend &&
            hadIntenseExercise == other.hadIntenseExercise &&
            hasSleepDebt == other.hasSleepDebt
        }
    }

    /// Per-bucket statistics for each feature
    private struct BucketStats {
        let bucketLabel: String
        let peerCount: Int
        /// Per-feature mean and std for this bucket (indexed by trainedKeys position)
        let featureMeans: [Double]
        let featureStds: [Double]
    }

    /// Precomputed bucket stats, keyed by bucket label
    private var bucketStatsCache: [String: BucketStats] = [:]
    /// Context for each training vector (parallel array)
    private var trainingContexts: [DayContext] = []

    // MARK: - Persistence Tracking

    /// Learned severity thresholds from training score distribution
    /// These replace the hardcoded 0.8/0.65/0.5 thresholds
    private var criticalScoreThreshold: Double = 0.8
    private var warningScoreThreshold: Double = 0.65
    private var infoScoreThreshold: Double = 0.5

    /// Learned feature attribution threshold (replaces hardcoded 1.5σ)
    private var featureAttributionThreshold: Double = 1.5

    /// Tracks consecutive anomaly days per metric for persistence gating
    private var consecutiveAnomalyDays: [HealthMetric: Int] = [:]
    /// Last anomaly date per metric for streak tracking
    private var lastAnomalyDate: [HealthMetric: Date] = [:]

    /// Cached isolation scores keyed by date. Isolation forest scoring is deterministic
    /// (same features → same score), so we cache results and invalidate on retrain.
    private var isolationScoreCache: [Date: Double] = [:]

    // MARK: - Training

    /// Build the isolation forest from daily feature vectors.
    /// - Parameters:
    ///   - vectors: Feature vectors (minimum 60 days)
    ///   - orderedKeys: Feature key ordering
    ///   - baselines: User baselines for context computation (exercise intensity, sleep debt)
    func train(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey], baselines: [HealthMetric: UserBaseline] = [:]) {
        guard vectors.count >= Self.minimumDays else { return }

        trainedKeys = orderedKeys
        trainingVectors = vectors
        trainedBaselines = baselines

        // Convert to arrays
        let dataArrays = vectors.map { $0.toArray(orderedKeys: orderedKeys) }
        featureDim = orderedKeys.count
        guard featureDim > 0 else { return }

        // Build forest (unchanged)
        let maxDepth = Int(ceil(log2(Double(Self.subSampleSize))))
        forest = (0..<Self.numTrees).map { _ in
            let subsample = randomSubsample(dataArrays, size: Self.subSampleSize)
            let root = buildTree(data: subsample, depth: 0, maxDepth: maxDepth)
            return IsolationTree(root: root, maxDepth: maxDepth)
        }

        // Compute context for all training vectors
        trainingContexts = vectors.enumerated().map { index, vector in
            computeContext(for: vector, allVectors: vectors, index: index)
        }

        // Build per-bucket statistics
        buildBucketStats(dataArrays: dataArrays)

        // Learn severity thresholds from training score distribution
        learnSeverityThresholds(dataArrays: dataArrays)

        // Precompute per-feature mean/std for findAnomalousFeatures (avoids 7x recomputation per pipeline)
        let dim = orderedKeys.count
        cachedTrainingMeans = [Double](repeating: 0, count: dim)
        cachedTrainingStds = [Double](repeating: 0, count: dim)
        for i in 0..<dim {
            let vals = dataArrays.compactMap { row -> Double? in
                guard i < row.count else { return nil }
                let v = row[i]
                return v == FeatureKey.missingSentinel ? nil : v
            }
            guard !vals.isEmpty else { continue }
            let mean = vals.reduce(0, +) / Double(vals.count)
            cachedTrainingMeans[i] = mean
            let variance = vals.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(vals.count)
            cachedTrainingStds[i] = variance.squareRoot()
        }

        // Precompute centroid + peer distance stats for legacyContextualZScore fallback
        cachedCentroid = [Double](repeating: 0, count: dim)
        var centroidCounts = [Double](repeating: 0, count: dim)
        for arr in dataArrays {
            for i in 0..<dim where arr[i] != FeatureKey.missingSentinel {
                cachedCentroid[i] += arr[i]
                centroidCounts[i] += 1
            }
        }
        for i in 0..<dim {
            if centroidCounts[i] > 0 { cachedCentroid[i] /= centroidCounts[i] }
        }
        var peerDistances: [Double] = []
        for arr in dataArrays {
            peerDistances.append(euclideanDistanceIgnoringMissing(arr, cachedCentroid))
        }
        cachedPeerDistanceMean = peerDistances.isEmpty ? 0 : peerDistances.reduce(0, +) / Double(peerDistances.count)
        let peerVar = peerDistances.reduce(0.0) { $0 + ($1 - cachedPeerDistanceMean) * ($1 - cachedPeerDistanceMean) } / Double(max(peerDistances.count, 1))
        cachedPeerDistanceStd = peerVar.squareRoot()

        // Reset persistence tracking and score cache on retrain
        consecutiveAnomalyDays = [:]
        lastAnomalyDate = [:]
        isolationScoreCache = [:]

        lastRetrainDate = Date()
    }

    /// Whether a full retrain is due (every 30 days)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    /// Learn severity thresholds from training data isolation score distribution.
    /// Uses percentiles: 95th → critical, 90th → warning, 80th → info.
    /// This replaces hardcoded 0.8/0.65/0.5 with user-adaptive thresholds.
    private func learnSeverityThresholds(dataArrays: [[Double]]) {
        let scores = dataArrays.map { isolationScore($0) }.sorted()
        guard scores.count >= 20 else { return }

        let n = scores.count
        criticalScoreThreshold = scores[min(Int(Double(n) * 0.95), n - 1)]
        warningScoreThreshold = scores[min(Int(Double(n) * 0.90), n - 1)]
        infoScoreThreshold = scores[min(Int(Double(n) * 0.80), n - 1)]

        // Ensure monotonic: critical > warning > info
        criticalScoreThreshold = max(criticalScoreThreshold, 0.6) // safety floor
        warningScoreThreshold = min(warningScoreThreshold, criticalScoreThreshold - 0.02)
        infoScoreThreshold = min(infoScoreThreshold, warningScoreThreshold - 0.02)

        // Learn feature attribution threshold from training deviation distribution
        let allDeviations = computeAllTrainingDeviations(dataArrays: dataArrays)
        if allDeviations.count >= 10 {
            let sortedDevs = allDeviations.sorted()
            // 90th percentile of deviations as the attribution threshold
            featureAttributionThreshold = sortedDevs[min(Int(Double(sortedDevs.count) * 0.90), sortedDevs.count - 1)]
            featureAttributionThreshold = max(featureAttributionThreshold, 1.0) // min 1σ
        }
    }

    /// Compute all per-feature deviations across training data for threshold learning
    private func computeAllTrainingDeviations(dataArrays: [[Double]]) -> [Double] {
        let dim = trainedKeys.count
        guard dim > 0, !dataArrays.isEmpty else { return [] }

        // Compute per-feature mean and std
        var means = [Double](repeating: 0, count: dim)
        var counts = [Double](repeating: 0, count: dim)
        for row in dataArrays {
            for i in 0..<min(row.count, dim) {
                if row[i] != FeatureKey.missingSentinel {
                    means[i] += row[i]
                    counts[i] += 1
                }
            }
        }
        for i in 0..<dim {
            if counts[i] > 0 { means[i] /= counts[i] }
        }

        var variances = [Double](repeating: 0, count: dim)
        for row in dataArrays {
            for i in 0..<min(row.count, dim) {
                if row[i] != FeatureKey.missingSentinel {
                    let diff = row[i] - means[i]
                    variances[i] += diff * diff
                }
            }
        }
        var stds = [Double](repeating: 0, count: dim)
        for i in 0..<dim {
            if counts[i] > 1 { stds[i] = (variances[i] / counts[i]).squareRoot() }
        }

        // Collect all deviations
        var deviations: [Double] = []
        for row in dataArrays {
            for i in 0..<min(row.count, dim) {
                if row[i] != FeatureKey.missingSentinel && stds[i] > 0 {
                    deviations.append(abs(row[i] - means[i]) / stds[i])
                }
            }
        }
        return deviations
    }

    // MARK: - Scoring

    /// Anomaly result from the adaptive detector
    struct AdaptiveAnomaly {
        let date: Date
        let globalScore: Double              // Isolation forest score (0-1, higher = more anomalous)
        let contextualZScore: Double         // Z-score vs same-context peers
        let severity: AnomalySeverity        // Classified severity level
        let contextBucket: String            // e.g. "weekday_normal", "weekend_intense"
        let persistenceDays: Int             // Consecutive anomaly days for this anomaly's metrics
        let crossSignalConfirmation: Bool    // Whether correlated metrics also deviate
        let confirmingMetrics: [HealthMetric] // Which correlated metrics confirm the anomaly
        let shouldSurface: Bool              // Passes persistence gate
        let isAnomaly: Bool                  // Kept for backward compatibility
        let anomalousFeatures: [(key: FeatureKey, contribution: Double)]
    }

    /// Score a single feature vector for anomaly
    func score(vector: DailyFeatureVector, allVectors: [DailyFeatureVector]? = nil) -> AdaptiveAnomaly {
        let features = vector.toArray(orderedKeys: trainedKeys)

        // Global isolation score — use cache to avoid redundant 50-tree traversals.
        // Isolation forest is deterministic: same features always produce the same score.
        let globalScore: Double
        if let cached = isolationScoreCache[vector.date] {
            globalScore = cached
        } else {
            let computed = isolationScore(features)
            isolationScoreCache[vector.date] = computed
            globalScore = computed
        }

        // Compute context for this vector
        let context: DayContext
        if let allVectors = allVectors, let idx = allVectors.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: vector.date) }) {
            context = computeContext(for: vector, allVectors: allVectors, index: idx)
        } else {
            context = computeContext(for: vector, allVectors: trainingVectors, index: trainingVectors.count - 1)
        }

        // Contextual z-score using bucket-based conditioning
        let contextualZ = contextualZScoreFromBucket(features: features, context: context)

        // Classify severity
        var severity = classifySeverity(globalScore: globalScore, contextualZ: contextualZ)

        // Feature attribution
        let anomalousFeatures = findAnomalousFeatures(features: features)

        // Cross-signal confirmation
        let (crossConfirmed, confirmingMetrics) = checkCrossSignalConfirmation(
            vector: vector,
            anomalousFeatures: anomalousFeatures
        )

        // Boost severity if cross-confirmed
        if crossConfirmed {
            severity = boostSeverity(severity)
        }

        // Update persistence tracking for anomalous metrics
        let persistenceDays = updatePersistenceTracking(
            date: vector.date,
            severity: severity,
            anomalousFeatures: anomalousFeatures
        )

        // Persistence gating: determine whether to surface
        let shouldSurface = passesPersistenceGate(severity: severity, persistenceDays: persistenceDays)

        // Backward-compatible isAnomaly
        let isAnomaly = severity >= .warning

        return AdaptiveAnomaly(
            date: vector.date,
            globalScore: globalScore,
            contextualZScore: contextualZ,
            severity: severity,
            contextBucket: context.bucketLabel,
            persistenceDays: persistenceDays,
            crossSignalConfirmation: crossConfirmed,
            confirmingMetrics: confirmingMetrics,
            shouldSurface: shouldSurface,
            isAnomaly: isAnomaly,
            anomalousFeatures: anomalousFeatures
        )
    }

    /// Score multiple vectors (recent days)
    func scoreRecent(vectors: [DailyFeatureVector], days: Int = 7) -> [AdaptiveAnomaly] {
        // Reset persistence tracking before scoring a batch so we compute streaks correctly
        consecutiveAnomalyDays = [:]
        lastAnomalyDate = [:]

        let recent = vectors.suffix(days)
        return recent.map { score(vector: $0, allVectors: vectors) }
    }

    // MARK: - Severity Classification

    /// Classify anomaly severity based on global and contextual scores.
    /// Uses learned thresholds from training score distribution instead of hardcoded values.
    private func classifySeverity(globalScore: Double, contextualZ: Double) -> AnomalySeverity {
        let absContextualZ = abs(contextualZ)

        // Critical: global >= learned 95th percentile OR |contextualZ| >= 2.5
        if globalScore >= criticalScoreThreshold || absContextualZ >= 2.5 {
            return .critical
        }
        // Warning: global >= learned 90th percentile OR |contextualZ| >= 2.0
        if globalScore >= warningScoreThreshold || absContextualZ >= 2.0 {
            return .warning
        }
        // Info: global >= learned 80th percentile OR |contextualZ| >= 1.5
        if globalScore >= infoScoreThreshold || absContextualZ >= 1.5 {
            return .info
        }
        // None
        return .none
    }

    /// Boost severity by one level (for cross-signal confirmation)
    private func boostSeverity(_ severity: AnomalySeverity) -> AnomalySeverity {
        switch severity {
        case .none: return .none // Don't promote "none". not an anomaly at all
        case .info: return .warning
        case .warning: return .critical
        case .critical: return .critical // Already max
        }
    }

    // MARK: - Context Computation

    /// Compute the context vector for a given day
    private func computeContext(for vector: DailyFeatureVector, allVectors: [DailyFeatureVector], index: Int) -> DayContext {
        let isWeekend = vector.context.isWeekend == 1.0

        // Exercise intensity: use baseline + 1σ as threshold (not arbitrary 1.5x multiplier)
        // This adapts to each user's activity level. an elite athlete's "intense" differs from sedentary
        let hadIntenseExercise: Bool
        if let activeCalRaw = vector.rawValue(for: .activeCalories) {
            if let baseline = trainedBaselines[.activeCalories], baseline.mean > 0, baseline.standardDeviation > 0 {
                hadIntenseExercise = activeCalRaw > baseline.mean + baseline.standardDeviation
            } else {
                let trainingCalories = trainingVectors.compactMap { $0.rawValue(for: .activeCalories) }
                let trainingMean = trainingCalories.isEmpty ? 0 : trainingCalories.mean
                hadIntenseExercise = trainingMean > 0 && activeCalRaw > trainingMean * 1.5
            }
        } else {
            hadIntenseExercise = false
        }

        // Sleep debt: cumulative deficit > 1σ of personal sleep variation over past 3 days
        // This replaces the hardcoded 1-hour threshold with a user-relative measure
        let hasSleepDebt: Bool
        let sleepDebtThreshold: Double
        if let sleepBaseline = trainedBaselines[.sleepDuration], sleepBaseline.mean > 0 {
            // Threshold = 1 standard deviation of user's sleep, minimum 0.5 hours
            sleepDebtThreshold = max(0.5, sleepBaseline.standardDeviation)
            var cumulativeDeficit: Double = 0
            let lookback = min(3, index)
            let startIdx = index - lookback
            for i in startIdx...index {
                if i >= 0, i < allVectors.count,
                   let sleepVal = allVectors[i].rawValue(for: .sleepDuration) {
                    let deficit = sleepBaseline.mean - sleepVal
                    if deficit > 0 { cumulativeDeficit += deficit }
                }
            }
            hasSleepDebt = cumulativeDeficit > sleepDebtThreshold
        } else {
            let trainingSleep = trainingVectors.compactMap { $0.rawValue(for: .sleepDuration) }
            let sleepMean = trainingSleep.isEmpty ? 0 : trainingSleep.mean
            if sleepMean > 0 {
                var cumulativeDeficit: Double = 0
                let lookback = min(3, index)
                let startIdx = index - lookback
                for i in startIdx...index {
                    if i >= 0, i < allVectors.count,
                       let sleepVal = allVectors[i].rawValue(for: .sleepDuration) {
                        let deficit = sleepMean - sleepVal
                        if deficit > 0 { cumulativeDeficit += deficit }
                    }
                }
                hasSleepDebt = cumulativeDeficit > 1.0
            } else {
                hasSleepDebt = false
            }
        }

        return DayContext(
            isWeekend: isWeekend,
            hadIntenseExercise: hadIntenseExercise,
            hasSleepDebt: hasSleepDebt
        )
    }

    // MARK: - Bucket Statistics

    /// Precompute per-bucket mean/std for each feature
    private func buildBucketStats(dataArrays: [[Double]]) {
        bucketStatsCache = [:]

        // Group indices by bucket
        var bucketIndices: [String: [Int]] = [:]
        for (i, ctx) in trainingContexts.enumerated() {
            bucketIndices[ctx.bucketLabel, default: []].append(i)
        }

        let dim = featureDim
        for (label, indices) in bucketIndices {
            guard indices.count >= Self.minBucketPeers else { continue }

            var means = [Double](repeating: 0, count: dim)
            var stds = [Double](repeating: 0, count: dim)

            for featureIdx in 0..<dim {
                let values = indices.compactMap { idx -> Double? in
                    let v = dataArrays[idx][featureIdx]
                    return v == FeatureKey.missingSentinel ? nil : v
                }
                guard !values.isEmpty else { continue }
                means[featureIdx] = values.mean
                stds[featureIdx] = values.standardDeviation
            }

            bucketStatsCache[label] = BucketStats(
                bucketLabel: label,
                peerCount: indices.count,
                featureMeans: means,
                featureStds: stds
            )
        }
    }

    /// Compute contextual z-score using per-bucket statistics.
    /// Falls back to the legacy distance-based method if the bucket is too small.
    private func contextualZScoreFromBucket(features: [Double], context: DayContext) -> Double {
        // Try exact bucket first
        if let stats = bucketStatsCache[context.bucketLabel] {
            return maxFeatureZ(features: features, stats: stats)
        }

        // Fall back: relax to just weekend/weekday bucket
        let relaxedLabel = context.isWeekend ? "weekend_normal" : "weekday_normal"
        if let stats = bucketStatsCache[relaxedLabel] {
            return maxFeatureZ(features: features, stats: stats)
        }

        // Final fallback: legacy distance-based contextual z-score across all training data
        return legacyContextualZScore(features: features)
    }

    /// Contextual anomaly score = max(|feature_z_vs_context_peers|) across all features
    private func maxFeatureZ(features: [Double], stats: BucketStats) -> Double {
        var maxZ: Double = 0
        for i in 0..<min(features.count, stats.featureMeans.count) {
            let value = features[i]
            guard value != FeatureKey.missingSentinel else { continue }
            let std = stats.featureStds[i]
            guard std > 0 else { continue }
            let z = abs(value - stats.featureMeans[i]) / std
            if z > maxZ { maxZ = z }
        }
        return maxZ
    }

    /// Legacy distance-based contextual z-score (fallback when bucket has < 5 peers).
    /// Uses cached centroid and peer distance stats from train() instead of recomputing.
    private func legacyContextualZScore(features: [Double]) -> Double {
        guard !cachedCentroid.isEmpty, cachedPeerDistanceStd > 0 else { return 0 }

        let targetDist = euclideanDistanceIgnoringMissing(features, cachedCentroid)
        return (targetDist - cachedPeerDistanceMean) / cachedPeerDistanceStd
    }

    // MARK: - Cross-Signal Confirmation

    /// Check if correlated metrics in the same confirmation group also deviate
    private func checkCrossSignalConfirmation(
        vector: DailyFeatureVector,
        anomalousFeatures: [(key: FeatureKey, contribution: Double)]
    ) -> (confirmed: Bool, confirmingMetrics: [HealthMetric]) {
        guard !anomalousFeatures.isEmpty else { return (false, []) }

        // Get the set of anomalous metrics
        let anomalousMetrics = Set(anomalousFeatures.map(\.key.metric))

        var allConfirming: Set<HealthMetric> = []

        // For each anomalous metric, check its confirmation group
        for anomalousMetric in anomalousMetrics {
            guard let group = Self.confirmationGroups.first(where: { $0.contains(anomalousMetric) }) else {
                continue
            }

            // Check if any other metric in the group also deviates
            let siblings = group.filter { $0 != anomalousMetric }
            for sibling in siblings {
                let zScore = featureZScoreVsTraining(metric: sibling, vector: vector)
                if abs(zScore) > 1.0 {
                    allConfirming.insert(sibling)
                }
            }
        }

        return (!allConfirming.isEmpty, Array(allConfirming))
    }

    /// Compute the z-score of a single metric's raw value vs training distribution.
    /// Uses cached training means/stds from train() instead of recomputing from training vectors.
    private func featureZScoreVsTraining(metric: HealthMetric, vector: DailyFeatureVector) -> Double {
        let key = FeatureKey(metric: metric, type: .raw)
        guard let keyIndex = trainedKeys.firstIndex(of: key) else { return 0 }
        guard let value = vector.features[key], value != FeatureKey.missingSentinel else { return 0 }
        guard keyIndex < cachedTrainingMeans.count, keyIndex < cachedTrainingStds.count else { return 0 }

        let sd = cachedTrainingStds[keyIndex]
        guard sd > 0 else { return 0 }
        return (value - cachedTrainingMeans[keyIndex]) / sd
    }

    // MARK: - Persistence Gating

    /// Update consecutive anomaly day tracking and return the max streak across anomalous metrics
    private func updatePersistenceTracking(
        date: Date,
        severity: AnomalySeverity,
        anomalousFeatures: [(key: FeatureKey, contribution: Double)]
    ) -> Int {
        guard severity >= .info else {
            // No anomaly. reset streaks for metrics not flagged
            return 0
        }

        let calendar = Calendar.current
        let anomalousMetrics = Set(anomalousFeatures.map(\.key.metric))
        var maxStreak = 0

        for metric in anomalousMetrics {
            if let lastDate = lastAnomalyDate[metric] {
                // Check if this is the next consecutive day
                let daysBetween = calendar.dateComponents([.day], from: lastDate, to: date).day ?? 0
                if daysBetween == 1 {
                    consecutiveAnomalyDays[metric, default: 0] += 1
                } else if daysBetween == 0 {
                    // Same day. no change
                } else {
                    // Gap. reset streak
                    consecutiveAnomalyDays[metric] = 1
                }
            } else {
                // First anomaly for this metric
                consecutiveAnomalyDays[metric] = 1
            }
            lastAnomalyDate[metric] = date
            maxStreak = max(maxStreak, consecutiveAnomalyDays[metric, default: 1])
        }

        return maxStreak
    }

    /// Determine whether an anomaly should be surfaced based on persistence rules.
    /// - Single day: Only surface if severity >= critical (global > 0.8 AND contextual > 2.5)
    /// - 2+ consecutive anomaly days: Surface at warning level
    /// - 3+ consecutive: Surface at any level (info+)
    private func passesPersistenceGate(severity: AnomalySeverity, persistenceDays: Int) -> Bool {
        switch severity {
        case .none:
            return false
        case .info:
            return persistenceDays >= 3
        case .warning:
            return persistenceDays >= 2
        case .critical:
            return true // Always surface critical
        }
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
            // Skip missing values. treat as average depth
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

    // MARK: - Distance Helpers

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
        return (sumSq / Double(count)).squareRoot()
    }

    // MARK: - Feature Attribution

    /// Find which features contribute most to anomaly score.
    /// Uses cached per-feature mean/std from train() instead of recomputing from scratch.
    private func findAnomalousFeatures(features: [Double]) -> [(key: FeatureKey, contribution: Double)] {
        guard !trainedKeys.isEmpty, !cachedTrainingMeans.isEmpty else { return [] }

        var contributions: [(key: FeatureKey, contribution: Double)] = []

        for (i, key) in trainedKeys.enumerated() {
            let featureValue = i < features.count ? features[i] : 0
            guard featureValue != FeatureKey.missingSentinel else { continue }
            guard i < cachedTrainingMeans.count, i < cachedTrainingStds.count else { continue }

            let sd = cachedTrainingStds[i]
            guard sd > 0 else { continue }

            let deviation = abs(featureValue - cachedTrainingMeans[i]) / sd
            if deviation > featureAttributionThreshold {
                contributions.append((key: key, contribution: deviation))
            }
        }

        return contributions.sorted { $0.contribution > $1.contribution }.prefix(5).map { $0 }
    }

    // MARK: - State

    var isReady: Bool { !forest.isEmpty }
}
