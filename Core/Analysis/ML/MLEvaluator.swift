import Foundation

// MARK: - MLEvaluator

/// First-class evaluation pipeline that joins ML prediction events with their realized outcomes,
/// computes rolling evaluation metrics per component and horizon, tracks recommendation uplift,
/// and detects model drift via Welch's t-test.
///
/// Thread-safe via NSLock. Maintains a maximum of 500 resolved events in memory (FIFO eviction).
final class MLEvaluator {

    // MARK: - Constants

    private static let maxResolvedEvents = 500
    private static let minimumClassificationSamples = 10
    private static let minimumRegressionSamples = 5
    private static let minimumAUROCSamplesPerClass = 10
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

    /// Evaluates a specific ML component over a rolling window, computing classification,
    /// regression, interval, and calibration metrics.
    ///
    /// - Parameters:
    ///   - name: The component name to evaluate.
    ///   - horizon: The forecast horizon to filter on.
    ///   - windowDays: Number of days to look back (default 30).
    /// - Returns: A `ComponentEvaluation` with all computed metrics, or nil if no data.
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

        var accuracy: Double?
        var precision: Double?
        var recall: Double?
        var f1Score: Double?
        var auroc: Double?
        var brierScore: Double?
        var ece: Double?
        var calibrationBins: [(predicted: Double, observed: Double, count: Int)]?

        if classificationEvents.count >= Self.minimumClassificationSamples {
            let classMetrics = computeClassificationMetrics(events: classificationEvents)
            accuracy = classMetrics.accuracy
            precision = classMetrics.precision
            recall = classMetrics.recall
            f1Score = classMetrics.f1Score
            brierScore = classMetrics.brierScore
            ece = classMetrics.ece
            calibrationBins = classMetrics.calibrationBins
            auroc = computeAUROC(events: classificationEvents)
        }

        // Regression metrics (always available for resolved events)
        var mae: Double?
        var rmse: Double?
        var mape: Double?

        if events.count >= Self.minimumRegressionSamples {
            let regressionMetrics = computeRegressionMetrics(events: events)
            mae = regressionMetrics.mae
            rmse = regressionMetrics.rmse
            mape = regressionMetrics.mape
        }

        // Interval metrics
        var intervalCoverage: Double?
        var intervalWidth: Double?

        let intervalEvents = events.filter {
            $0.prediction.intervalLower != nil && $0.prediction.intervalUpper != nil
        }
        if intervalEvents.count >= Self.minimumRegressionSamples {
            let intervalMetrics = computeIntervalMetrics(events: intervalEvents)
            intervalCoverage = intervalMetrics.coverage
            intervalWidth = intervalMetrics.avgWidth
        }

        // Model version: use the most recent event's version
        let latestVersion = events
            .sorted { $0.predictedAt < $1.predictedAt }
            .last?.modelVersion

        return ComponentEvaluation(
            componentName: name,
            horizon: horizon,
            windowDays: windowDays,
            sampleCount: events.count,
            accuracy: accuracy,
            precision: precision,
            recall: recall,
            f1Score: f1Score,
            auroc: auroc,
            brierScore: brierScore,
            ece: ece,
            mae: mae,
            rmse: rmse,
            mape: mape,
            intervalCoverage: intervalCoverage,
            intervalWidth: intervalWidth,
            calibrationBins: calibrationBins,
            modelVersion: latestVersion
        )
    }

    // MARK: - AUROC Computation

    /// Computes the Area Under the ROC Curve for classification events.
    ///
    /// Uses threshold sweeping with trapezoidal integration. Requires at least 10 positive
    /// and 10 negative outcomes for a reliable estimate.
    ///
    /// - Parameter events: Resolved events with predicted probabilities and outcomes.
    /// - Returns: AUROC value (0.0 to 1.0), or nil if insufficient data.
    func computeAUROC(events: [EvaluationEvent]) -> Double? {
        // Filter to events with probability and correctness
        let valid = events.compactMap { event -> (probability: Double, actual: Bool)? in
            guard let prob = event.prediction.predictedProbability,
                  let outcome = event.outcome else { return nil }
            let actualPositive = outcome.actualValue >= 0.5
            return (prob, actualPositive)
        }

        let positiveCount = valid.filter(\.actual).count
        let negativeCount = valid.count - positiveCount

        guard positiveCount >= Self.minimumAUROCSamplesPerClass,
              negativeCount >= Self.minimumAUROCSamplesPerClass else {
            return nil
        }

        // Sort by predicted probability descending
        let sorted = valid.sorted { $0.probability > $1.probability }

        // Sweep thresholds and compute ROC points
        var rocPoints: [(fpr: Double, tpr: Double)] = []
        rocPoints.reserveCapacity(sorted.count + 2)

        // Start with (0, 0). threshold = 1.0+
        rocPoints.append((fpr: 0.0, tpr: 0.0))

        var tp = 0
        var fp = 0

        for item in sorted {
            if item.actual {
                tp += 1
            } else {
                fp += 1
            }

            let tpr = Double(tp) / Double(positiveCount)
            let fpr = Double(fp) / Double(negativeCount)
            rocPoints.append((fpr: fpr, tpr: tpr))
        }

        // End with (1, 1). threshold = 0.0
        if rocPoints.last?.fpr != 1.0 || rocPoints.last?.tpr != 1.0 {
            rocPoints.append((fpr: 1.0, tpr: 1.0))
        }

        // Trapezoidal rule for area
        var area = 0.0
        for i in 1..<rocPoints.count {
            let dx = rocPoints[i].fpr - rocPoints[i - 1].fpr
            let avgY = (rocPoints[i].tpr + rocPoints[i - 1].tpr) / 2.0
            area += dx * avgY
        }

        return Swift.max(0.0, Swift.min(1.0, area))
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

    // MARK: - Classification Metric Computation

    private struct ClassificationResult {
        let accuracy: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let brierScore: Double
        let ece: Double
        let calibrationBins: [(predicted: Double, observed: Double, count: Int)]
    }

    private func computeClassificationMetrics(events: [EvaluationEvent]) -> ClassificationResult {
        var tp = 0, fp = 0, tn = 0, fn = 0
        var brierSum = 0.0

        // For calibration: group into bins
        let binCount = Self.calibrationBinCount
        let binWidth = 1.0 / Double(binCount)
        var binPredicted: [[Double]] = Array(repeating: [], count: binCount)
        var binActual: [[Bool]] = Array(repeating: [], count: binCount)

        for event in events {
            guard let prob = event.prediction.predictedProbability,
                  let outcome = event.outcome,
                  outcome.wasCorrect != nil else { continue }

            let actualPositive = outcome.actualValue >= 0.5
            let predictedPositive = prob >= 0.5

            if predictedPositive && actualPositive { tp += 1 }
            else if predictedPositive && !actualPositive { fp += 1 }
            else if !predictedPositive && actualPositive { fn += 1 }
            else { tn += 1 }

            let label = actualPositive ? 1.0 : 0.0
            let diff = prob - label
            brierSum += diff * diff

            // Binning
            let clamped = Swift.max(0.0, Swift.min(prob, 1.0))
            var binIndex = Int(clamped / binWidth)
            if binIndex >= binCount { binIndex = binCount - 1 }
            binPredicted[binIndex].append(clamped)
            binActual[binIndex].append(actualPositive)
        }

        let n = Double(tp + fp + tn + fn)
        let accuracy = n > 0 ? Double(tp + tn) / n : 0.0

        let precision: Double
        if tp + fp > 0 { precision = Double(tp) / Double(tp + fp) }
        else { precision = 0.0 }

        let recall: Double
        if tp + fn > 0 { recall = Double(tp) / Double(tp + fn) }
        else { recall = 0.0 }

        let f1Score: Double
        if precision + recall > 0 { f1Score = 2.0 * precision * recall / (precision + recall) }
        else { f1Score = 0.0 }

        let brierScore = n > 0 ? brierSum / n : 0.0

        // Calibration bins and ECE
        var calibBins: [(predicted: Double, observed: Double, count: Int)] = []
        var eceSum = 0.0
        let totalCount = Int(n)

        for i in 0..<binCount {
            let count = binPredicted[i].count
            if count > 0 {
                let predMean = binPredicted[i].mean
                let positives = binActual[i].filter { $0 }.count
                let obsMean = Double(positives) / Double(count)
                calibBins.append((predicted: predMean, observed: obsMean, count: count))

                let weight = Double(count) / Double(Swift.max(totalCount, 1))
                eceSum += weight * abs(predMean - obsMean)
            } else {
                let center = (Double(i) + 0.5) * binWidth
                calibBins.append((predicted: center, observed: 0.0, count: 0))
            }
        }

        return ClassificationResult(
            accuracy: accuracy,
            precision: precision,
            recall: recall,
            f1Score: f1Score,
            brierScore: brierScore,
            ece: eceSum,
            calibrationBins: calibBins
        )
    }

    // MARK: - Regression Metric Computation

    private struct RegressionResult {
        let mae: Double
        let rmse: Double
        let mape: Double
    }

    private func computeRegressionMetrics(events: [EvaluationEvent]) -> RegressionResult {
        var sumAE = 0.0
        var sumSE = 0.0
        var sumAPE = 0.0
        var validAPECount = 0
        var count = 0

        for event in events {
            guard let outcome = event.outcome else { continue }
            let residual = outcome.residual
            sumAE += abs(residual)
            sumSE += residual * residual
            count += 1

            if abs(outcome.actualValue) > 1e-9 {
                sumAPE += abs(residual / outcome.actualValue)
                validAPECount += 1
            }
        }

        let n = Double(Swift.max(count, 1))
        let mae = sumAE / n
        let rmse = (sumSE / n).squareRoot()
        let mape = validAPECount > 0 ? sumAPE / Double(validAPECount) : 0.0

        return RegressionResult(mae: mae, rmse: rmse, mape: mape)
    }

    // MARK: - Interval Metric Computation

    private struct IntervalResult {
        let coverage: Double
        let avgWidth: Double
    }

    private func computeIntervalMetrics(events: [EvaluationEvent]) -> IntervalResult {
        var coveredCount = 0
        var totalWidth = 0.0
        var count = 0

        for event in events {
            guard let outcome = event.outcome,
                  let lower = event.prediction.intervalLower,
                  let upper = event.prediction.intervalUpper else { continue }

            let width = upper - lower
            totalWidth += width
            count += 1

            if outcome.actualValue >= lower && outcome.actualValue <= upper {
                coveredCount += 1
            }
        }

        let n = Double(Swift.max(count, 1))
        return IntervalResult(
            coverage: Double(coveredCount) / n,
            avgWidth: totalWidth / n
        )
    }

}

// MARK: - Supporting Types

/// Comprehensive evaluation results for a single ML component at a specific forecast horizon.
struct ComponentEvaluation {
    let componentName: String
    let horizon: EvaluationEvent.ForecastHorizon
    let windowDays: Int
    let sampleCount: Int

    // Classification metrics
    let accuracy: Double?
    let precision: Double?
    let recall: Double?
    let f1Score: Double?
    let auroc: Double?
    let brierScore: Double?
    let ece: Double?

    // Regression metrics
    let mae: Double?
    let rmse: Double?
    let mape: Double?

    // Interval metrics
    let intervalCoverage: Double?
    let intervalWidth: Double?

    // Calibration
    let calibrationBins: [(predicted: Double, observed: Double, count: Int)]?

    // Model version
    let modelVersion: ModelVersion?
}
