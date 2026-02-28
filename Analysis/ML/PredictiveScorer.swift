import Foundation

/// Online logistic regression that predicts P(bad day tomorrow) from today's features.
/// Learns incrementally each day using SGD with L2 regularization.
final class PredictiveScorer {
    /// Minimum days of data required
    static let minimumDays = 30
    /// Maximum training samples for confidence cap
    private static let maxConfidenceSamples = 90

    /// Definition of a "bad day":
    /// - Score drop > 10 points from previous day
    /// - 2+ anomalies on the same day
    /// - Overall score < 60
    private static let scoreDrop = 10.0
    private static let anomalyCount = 2
    private static let lowScoreThreshold = 60.0

    /// Model weights (one per feature + bias)
    private var weights: [Double] = []
    /// Feature keys used during training
    private var featureKeys: [FeatureKey] = []
    /// Learning rate (decays over time)
    private var learningRate: Double = 0.01
    /// L2 regularization strength
    private let lambda: Double = 0.001
    /// Number of training examples seen
    private var trainingCount: Int = 0

    /// Latest prediction
    private(set) var currentPrediction: MLPrediction?

    // MARK: - Training

    /// Initial training from historical data
    func train(
        vectors: [DailyFeatureVector],
        orderedKeys: [FeatureKey],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int]
    ) {
        guard vectors.count >= Self.minimumDays else { return }

        featureKeys = orderedKeys
        let contextSize = 5 // sin/cos weekday, sin/cos month, isWeekend
        let totalFeatures = orderedKeys.count + contextSize + 1 // +1 for bias
        weights = [Double](repeating: 0, count: totalFeatures)

        // Build score lookup
        let calendar = Calendar.current
        var scoreLookup: [Date: Int] = [:]
        for entry in scoreHistory {
            scoreLookup[calendar.startOfDay(for: entry.date)] = entry.score
        }

        // Train on each consecutive day pair
        for i in 0..<(vectors.count - 1) {
            let today = vectors[i]
            let tomorrow = vectors[i + 1]
            let tomorrowDate = calendar.startOfDay(for: tomorrow.date)
            let todayDate = calendar.startOfDay(for: today.date)

            // Determine if tomorrow was a "bad day"
            let tomorrowScore = scoreLookup[tomorrowDate]
            let todayScore = scoreLookup[todayDate]
            let anomalies = anomalyCounts[tomorrowDate] ?? 0

            let isBadDay = determineBadDay(
                todayScore: todayScore, tomorrowScore: tomorrowScore, anomalyCount: anomalies
            )

            // Build feature vector
            let features = buildFeatureArray(from: today)
            guard features.count == totalFeatures else { continue }

            // SGD update
            sgdUpdate(features: features, label: isBadDay ? 1.0 : 0.0)
        }
    }

    /// Incremental update with one new day of data
    func trainIncremental(
        todayVector: DailyFeatureVector,
        wasBadDay: Bool
    ) {
        guard !weights.isEmpty else { return }

        let features = buildFeatureArray(from: todayVector)
        guard features.count == weights.count else { return }

        sgdUpdate(features: features, label: wasBadDay ? 1.0 : 0.0)
    }

    // MARK: - Prediction

    /// Predict probability of a bad day tomorrow given today's features
    func predict(todayVector: DailyFeatureVector) -> MLPrediction? {
        guard !weights.isEmpty else { return nil }

        let features = buildFeatureArray(from: todayVector)
        guard features.count == weights.count else { return nil }

        // Logistic regression: P(bad) = sigmoid(w . x)
        let logit = AccelerateML.dotProduct(weights, features)
        let probability = AccelerateML.sigmoid(logit)

        // Confidence scales with training data (capped at maxConfidenceSamples)
        let confidence = Swift.min(Double(trainingCount) / Double(Self.maxConfidenceSamples), 1.0)

        // Find top contributing features
        let topFactors = extractTopFactors(features: features, topN: 5)

        let prediction = MLPrediction(
            target: "Challenging day tomorrow",
            probability: probability,
            confidence: confidence,
            topFactors: topFactors,
            generatedAt: Date()
        )

        currentPrediction = prediction
        return prediction
    }

    // MARK: - SGD Update

    private func sgdUpdate(features: [Double], label: Double) {
        let n = features.count
        guard n == weights.count else { return }

        trainingCount += 1

        // Decaying learning rate
        let lr = learningRate / (1.0 + 0.001 * Double(trainingCount))

        // Forward pass
        let logit = AccelerateML.dotProduct(weights, features)
        let predicted = AccelerateML.sigmoid(logit)

        // Gradient: (predicted - label) * features + lambda * weights
        let error = predicted - label

        for i in 0..<n {
            let gradient = error * features[i] + lambda * weights[i]
            weights[i] -= lr * gradient
        }
    }

    // MARK: - Feature Construction

    private func buildFeatureArray(from vector: DailyFeatureVector) -> [Double] {
        // Metric features (replace missing with 0)
        var features = featureKeys.map { key -> Double in
            let v = vector.features[key] ?? FeatureKey.missingSentinel
            return v == FeatureKey.missingSentinel ? 0.0 : v
        }

        // Context features
        features.append(contentsOf: vector.context.asArray)

        // Bias term
        features.append(1.0)

        return features
    }

    // MARK: - Feature Attribution

    private func extractTopFactors(features: [Double], topN: Int) -> [PredictionFactor] {
        var contributions: [(index: Int, contribution: Double)] = []

        for i in 0..<Swift.min(featureKeys.count, features.count) {
            let contribution = weights[i] * features[i]
            contributions.append((index: i, contribution: contribution))
        }

        // Sort by absolute contribution
        contributions.sort { abs($0.contribution) > abs($1.contribution) }

        return contributions.prefix(topN).compactMap { item in
            guard item.index < featureKeys.count else { return nil }
            let key = featureKeys[item.index]
            return PredictionFactor(
                metric: key.metric,
                featureType: key.type,
                contribution: item.contribution,
                currentValue: features[item.index]
            )
        }
    }

    // MARK: - Bad Day Classification

    /// Determine if a day was "bad" based on score and anomalies
    func determineBadDay(
        todayScore: Int?, tomorrowScore: Int?, anomalyCount: Int
    ) -> Bool {
        // Score drop > 10
        if let today = todayScore, let tomorrow = tomorrowScore {
            if Double(today - tomorrow) > Self.scoreDrop {
                return true
            }
        }

        // Low absolute score
        if let tomorrow = tomorrowScore, Double(tomorrow) < Self.lowScoreThreshold {
            return true
        }

        // Multiple anomalies
        if anomalyCount >= Self.anomalyCount {
            return true
        }

        return false
    }

    // MARK: - State

    var isReady: Bool { !weights.isEmpty && trainingCount >= Self.minimumDays }

    /// Serializable model parameters
    struct ModelParameters: Codable {
        let weights: [Double]
        let featureKeysData: Data // Encoded [FeatureKey]
        let learningRate: Double
        let trainingCount: Int
    }

    func getParameters() -> ModelParameters? {
        guard let keysData = try? JSONEncoder().encode(featureKeys) else { return nil }
        return ModelParameters(
            weights: weights,
            featureKeysData: keysData,
            learningRate: learningRate,
            trainingCount: trainingCount
        )
    }

    func restoreParameters(_ params: ModelParameters) {
        weights = params.weights
        learningRate = params.learningRate
        trainingCount = params.trainingCount
        if let keys = try? JSONDecoder().decode([FeatureKey].self, from: params.featureKeysData) {
            featureKeys = keys
        }
    }
}
