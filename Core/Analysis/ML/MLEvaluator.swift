import Foundation

// MARK: - MLEvaluator

/// Evaluation pipeline that joins ML prediction events with their realized outcomes
/// and computes each component's rolling calibration error.
///
/// Thread-safe via NSLock. Maintains a maximum of 500 resolved events in memory (FIFO eviction).
final class MLEvaluator {

    // MARK: - Constants

    private static let maxResolvedEvents = 500
    private static let minimumClassificationSamples = 10
    private static let calibrationBinCount = 10

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - State

    /// Pending events keyed by eventId, awaiting outcome resolution.
    private(set) var pendingEvents: [String: EvaluationEvent] = [:]

    /// Completed evaluation records with both prediction and outcome.
    private(set) var resolvedEvents: [EvaluationEvent] = []

    // MARK: - Event Recording

    /// Records a new prediction event and returns a unique eventId for later resolution.
    ///
    /// - Parameters:
    ///   - componentName: The ML component that made the prediction.
    ///   - modelVersion: Version metadata for the model.
    ///   - horizon: Forecast horizon (nextDay, next3Days, next7Days).
    ///   - targetMetric: The metric being predicted.
    ///   - predictedValue: The predicted numeric value.
    ///   - probability: Optional predicted probability (for classifiers).
    ///   - confidence: Confidence level of the prediction (0-1).
    ///   - intervalLower: Optional lower bound of prediction interval.
    ///   - intervalUpper: Optional upper bound of prediction interval.
    /// - Returns: The unique eventId string.
    @discardableResult
    func recordPrediction(
        componentName: String,
        modelVersion: ModelVersion,
        horizon: EvaluationEvent.ForecastHorizon,
        targetMetric: String,
        predictedValue: Double,
        probability: Double? = nil,
        confidence: Double,
        intervalLower: Double? = nil,
        intervalUpper: Double? = nil
    ) -> String {
        let eventId = UUID().uuidString

        let prediction = EvaluationEvent.PredictionRecord(
            targetMetric: targetMetric,
            predictedValue: predictedValue,
            predictedProbability: probability,
            confidence: confidence,
            intervalLower: intervalLower,
            intervalUpper: intervalUpper
        )

        let event = EvaluationEvent(
            eventId: eventId,
            componentName: componentName,
            modelVersion: modelVersion,
            predictedAt: Date(),
            forecastHorizon: horizon,
            prediction: prediction,
            outcome: nil
        )

        lock.lock()
        pendingEvents[eventId] = event
        lock.unlock()

        return eventId
    }

    // MARK: - Outcome Resolution

    /// Resolves a pending prediction event with the actual observed value.
    ///
    /// Computes residual and classification correctness, moves the event from pending to resolved,
    /// and enforces the FIFO eviction cap on resolved events.
    ///
    /// - Parameters:
    ///   - eventId: The event to resolve.
    ///   - actualValue: The actual observed value for the target metric.
    func resolveOutcome(eventId: String, actualValue: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard var event = pendingEvents.removeValue(forKey: eventId) else { return }

        let residual = actualValue - event.prediction.predictedValue

        // For classifiers: determine correctness using 0.5 threshold on predicted probability
        let wasCorrect: Bool?
        if let probability = event.prediction.predictedProbability {
            let predictedPositive = probability >= 0.5
            // Actual outcome is "positive" if actualValue >= 0.5 (matches probability space)
            let actualPositive = actualValue >= 0.5
            wasCorrect = predictedPositive == actualPositive
        } else {
            wasCorrect = nil
        }

        let outcome = EvaluationEvent.OutcomeRecord(
            resolvedAt: Date(),
            actualValue: actualValue,
            wasCorrect: wasCorrect,
            residual: residual
        )

        event.outcome = outcome
        resolvedEvents.append(event)
        enforceResolvedCap()
    }

    // MARK: - Auto-Resolution

    /// Automatically resolves all pending events whose forecast horizon has expired.
    ///
    /// Looks up actual values from the provided time series data and score history.
    /// Should be called daily during the ML orchestrator pipeline.
    ///
    /// - Parameters:
    ///   - timeSeries: Dictionary of metric time series keyed by HealthMetric.
    ///   - scores: Array of (date, score) pairs representing overall health scores.
    func resolveExpiredEvents(
        timeSeries: [HealthMetric: MetricTimeSeries],
        scores: [(date: Date, score: Double)]
    ) {
        let calendar = Date.cal
        let now = Date()

        // Snapshot pending event IDs under lock
        lock.lock()
        let pendingSnapshot = pendingEvents
        lock.unlock()

        for (eventId, event) in pendingSnapshot {
            let horizonDays = Self.horizonToDays(event.forecastHorizon)
            let expirationDate = calendar.date(
                byAdding: .day, value: horizonDays, to: event.predictedAt
            ) ?? event.predictedAt

            // Only resolve if the horizon has fully elapsed
            guard now >= expirationDate else { continue }

            let targetDateStart = calendar.startOfDay(for: expirationDate)
            let targetDateEnd = calendar.date(byAdding: .day, value: 1, to: targetDateStart)
                ?? targetDateStart

            // Try to find actual value from time series
            var actualValue: Double?

            // Match target metric string to HealthMetric
            for (metric, series) in timeSeries {
                if metric.rawValue == event.prediction.targetMetric {
                    // Find sample closest to the target date
                    let matchingSamples = series.samples.filter {
                        $0.date >= targetDateStart && $0.date < targetDateEnd
                    }
                    if let sample = matchingSamples.last {
                        actualValue = sample.value
                    }
                    break
                }
            }

            // If the target metric is "overallScore", look up from scores
            if actualValue == nil && event.prediction.targetMetric == "overallScore" {
                let matchingScores = scores.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= targetDateStart && d < targetDateEnd
                }
                actualValue = matchingScores.last?.score
            }

            // Resolve if we found an actual value
            if let actual = actualValue {
                resolveOutcome(eventId: eventId, actualValue: actual)
            }
        }
    }

    // MARK: - Rolling Component Evaluation

    /// Evaluates a specific ML component over a rolling window, computing its
    /// calibration error.
    ///
    /// - Parameters:
    ///   - name: The component name to evaluate.
    ///   - horizon: The forecast horizon to filter on.
    ///   - windowDays: Number of days to look back (default 30).
    /// - Returns: A `ComponentEvaluation`, or nil if no data.
    func evaluateComponent(
        name: String,
        horizon: EvaluationEvent.ForecastHorizon,
        windowDays: Int = 30
    ) -> ComponentEvaluation? {
        let events = filteredResolvedEvents(
            componentName: name, horizon: horizon, windowDays: windowDays
        )
        guard !events.isEmpty else { return nil }

        // Classification metrics (requires predicted probability)
        let classificationEvents = events.filter {
            $0.prediction.predictedProbability != nil && $0.outcome?.wasCorrect != nil
        }

        var ece: Double?
        if classificationEvents.count >= Self.minimumClassificationSamples {
            ece = computeExpectedCalibrationError(events: classificationEvents)
        }

        return ComponentEvaluation(sampleCount: events.count, ece: ece)
    }

    // MARK: - Private Helpers

    /// Enforces the maximum resolved event cap via FIFO eviction.
    private func enforceResolvedCap() {
        // Called under lock
        if resolvedEvents.count > Self.maxResolvedEvents {
            let excess = resolvedEvents.count - Self.maxResolvedEvents
            resolvedEvents.removeFirst(excess)
        }
    }

    /// Returns resolved events filtered by component, horizon, and recency.
    private func filteredResolvedEvents(
        componentName: String,
        horizon: EvaluationEvent.ForecastHorizon,
        windowDays: Int
    ) -> [EvaluationEvent] {
        lock.lock()
        let snapshot = resolvedEvents
        lock.unlock()

        let cutoff = Date.cal.date(
            byAdding: .day, value: -windowDays, to: Date()
        ) ?? Date()

        return snapshot.filter {
            $0.componentName == componentName &&
            $0.forecastHorizon == horizon &&
            $0.predictedAt >= cutoff &&
            $0.outcome != nil
        }
    }

    /// Converts a ForecastHorizon to its integer day count.
    private static func horizonToDays(_ horizon: EvaluationEvent.ForecastHorizon) -> Int {
        switch horizon {
        case .nextDay: return 1
        case .next3Days: return 3
        case .next7Days: return 7
        }
    }

    // MARK: - Calibration Error

    /// Expected calibration error: probability-weighted gap between predicted
    /// probability and observed frequency across equal-width probability bins.
    private func computeExpectedCalibrationError(events: [EvaluationEvent]) -> Double {
        let binCount = Self.calibrationBinCount
        let binWidth = 1.0 / Double(binCount)
        var binPredicted: [[Double]] = Array(repeating: [], count: binCount)
        var binActual: [[Bool]] = Array(repeating: [], count: binCount)
        var total = 0

        for event in events {
            guard let prob = event.prediction.predictedProbability,
                  let outcome = event.outcome,
                  outcome.wasCorrect != nil else { continue }

            let clamped = Swift.max(0.0, Swift.min(prob, 1.0))
            var binIndex = Int(clamped / binWidth)
            if binIndex >= binCount { binIndex = binCount - 1 }
            binPredicted[binIndex].append(clamped)
            binActual[binIndex].append(outcome.actualValue >= 0.5)
            total += 1
        }

        var eceSum = 0.0
        for i in 0..<binCount {
            let count = binPredicted[i].count
            guard count > 0 else { continue }
            let predMean = binPredicted[i].mean
            let obsMean = Double(binActual[i].filter { $0 }.count) / Double(count)
            let weight = Double(count) / Double(Swift.max(total, 1))
            eceSum += weight * abs(predMean - obsMean)
        }
        return eceSum
    }

}

// MARK: - Supporting Types

/// Evaluation results for a single ML component at a specific forecast horizon.
struct ComponentEvaluation {
    let sampleCount: Int
    /// Expected calibration error. drives temperature rescaling in MLCalibrationManager.
    let ece: Double?
}
