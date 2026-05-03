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
    private static let driftAlpha = 0.05


    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - State

    /// Pending events keyed by eventId, awaiting outcome resolution.
    private(set) var pendingEvents: [String: EvaluationEvent] = [:]

    /// Completed evaluation records with both prediction and outcome.
    private(set) var resolvedEvents: [EvaluationEvent] = []

    /// Tracked recommendation feedback for uplift analysis.
    private(set) var recommendationFeedback: [RecommendationFeedback] = []

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

    // MARK: - Recommendation Uplift Tracking

    /// Records a recommendation feedback event for uplift analysis.
    ///
    /// - Parameter feedback: The recommendation feedback to track.
    func recordRecommendationFeedback(_ feedback: RecommendationFeedback) {
        lock.lock()
        recommendationFeedback.append(feedback)
        lock.unlock()
    }

    /// Evaluates recommendation effectiveness over a rolling window.
    ///
    /// Computes adherence rates, average uplift by action type, identifies best/worst actions,
    /// and measures exposure fatigue (correlation between exposure count and adherence).
    ///
    /// - Parameter windowDays: Number of days to look back (default 30).
    /// - Returns: A `RecommendationEvaluation` summary, or nil if no feedback data.
    func evaluateRecommendations(windowDays: Int = 30) -> RecommendationEvaluation? {
        lock.lock()
        let feedbackSnapshot = recommendationFeedback
        lock.unlock()

        let cutoff = Date.cal.date(
            byAdding: .day, value: -windowDays, to: Date()
        ) ?? Date()

        let recentFeedback = feedbackSnapshot.filter { $0.shownAt >= cutoff }
        guard !recentFeedback.isEmpty else { return nil }

        let totalShown = recentFeedback.count
        let totalFollowed = recentFeedback.filter {
            ($0.adherenceScore ?? 0) > 0.5
        }.count

        // Compute uplift by action type
        var upliftByAction: [String: [Double]] = [:]
        for fb in recentFeedback {
            if let uplift = fb.estimatedUplift {
                upliftByAction[fb.actionType, default: []].append(uplift)
            }
        }

        var avgUpliftByAction: [String: Double] = [:]
        var allUplifts: [Double] = []
        for (action, uplifts) in upliftByAction {
            let avg = uplifts.mean
            avgUpliftByAction[action] = avg
            allUplifts.append(contentsOf: uplifts)
        }

        let averageUplift = allUplifts.isEmpty ? 0.0 : allUplifts.mean

        // Rank action types by average uplift
        let sortedActions = avgUpliftByAction.sorted { $0.value > $1.value }
        let bestActions = Array(sortedActions.prefix(3).map(\.key))
        let worstActions = Array(sortedActions.suffix(3).map(\.key))

        // Exposure fatigue: Pearson correlation between exposureCount7d and adherenceScore
        let exposureFatigueRate: Double
        let fatigueData = recentFeedback.compactMap { fb -> (x: Double, y: Double)? in
            guard let adherence = fb.adherenceScore else { return nil }
            return (Double(fb.exposureCount7d), adherence)
        }

        if fatigueData.count >= 5 {
            let xs = fatigueData.map(\.x)
            let ys = fatigueData.map(\.y)
            exposureFatigueRate = [Double].pearsonCorrelation(xs, ys) ?? 0.0
        } else {
            exposureFatigueRate = 0.0
        }

        return RecommendationEvaluation(
            totalShown: totalShown,
            totalFollowed: totalFollowed,
            averageUplift: averageUplift,
            upliftByActionType: avgUpliftByAction,
            bestActionTypes: bestActions,
            worstActionTypes: worstActions,
            exposureFatigueRate: exposureFatigueRate
        )
    }

    // MARK: - Persistence Export

    /// Exports a summary dictionary of all evaluation state for persistence or logging.
    ///
    /// - Returns: A dictionary with counts, recent evaluations, and recommendation summary.
    func exportEvaluationSummary() -> [String: Any] {
        lock.lock()
        let pending = pendingEvents.count
        let resolved = resolvedEvents.count
        let feedback = recommendationFeedback.count
        let resolvedSnapshot = resolvedEvents
        lock.unlock()

        var summary: [String: Any] = [
            "pendingEventCount": pending,
            "resolvedEventCount": resolved,
            "recommendationFeedbackCount": feedback,
            "exportedAt": Date.iso8601Formatter.string(from: Date())
        ]

        // Aggregate per-component counts
        var componentCounts: [String: Int] = [:]
        for event in resolvedSnapshot {
            componentCounts[event.componentName, default: 0] += 1
        }
        summary["resolvedByComponent"] = componentCounts

        // Add recommendation evaluation if available
        if let recEval = evaluateRecommendations() {
            summary["recommendationTotalShown"] = recEval.totalShown
            summary["recommendationTotalFollowed"] = recEval.totalFollowed
            summary["recommendationAverageUplift"] = recEval.averageUplift
            summary["recommendationExposureFatigue"] = recEval.exposureFatigueRate
        }

        return summary
    }

    /// Converts evaluation results for a specific component into persistable metric entries
    /// compatible with `StoredModelEvaluation` in SwiftData.
    ///
    /// - Parameter componentName: The component to generate entries for.
    /// - Returns: Array of (metric name, value) pairs for persistence.
    func toPersistableEntries(componentName: String) -> [(metric: String, value: Double)] {
        var entries: [(metric: String, value: Double)] = []

        // Evaluate across all horizons
        for horizon in [EvaluationEvent.ForecastHorizon.nextDay,
                        .next3Days,
                        .next7Days] {
            guard let eval = evaluateComponent(
                name: componentName, horizon: horizon, windowDays: 30
            ) else { continue }

            let suffix = "_\(horizon.rawValue)"

            if let v = eval.accuracy { entries.append(("accuracy\(suffix)", v)) }
            if let v = eval.precision { entries.append(("precision\(suffix)", v)) }
            if let v = eval.recall { entries.append(("recall\(suffix)", v)) }
            if let v = eval.f1Score { entries.append(("f1_score\(suffix)", v)) }
            if let v = eval.auroc { entries.append(("auroc\(suffix)", v)) }
            if let v = eval.brierScore { entries.append(("brier_score\(suffix)", v)) }
            if let v = eval.ece { entries.append(("calibration_error\(suffix)", v)) }
            if let v = eval.mae { entries.append(("mae\(suffix)", v)) }
            if let v = eval.rmse { entries.append(("rmse\(suffix)", v)) }
            if let v = eval.mape { entries.append(("mape\(suffix)", v)) }
            if let v = eval.intervalCoverage { entries.append(("interval_coverage\(suffix)", v)) }
            if let v = eval.intervalWidth { entries.append(("interval_width\(suffix)", v)) }
        }

        return entries
    }

    // MARK: - Drift Detection

    /// Detects model drift by comparing evaluation metrics between a recent window and a baseline window
    /// using Welch's t-test.
    ///
    /// - Parameters:
    ///   - componentName: The component to check for drift.
    ///   - recentWindow: Number of recent days to evaluate (default 7).
    ///   - baselineWindow: Number of baseline days to compare against (default 30).
    /// - Returns: A `DriftReport` indicating whether significant degradation was detected.
    func detectModelDrift(
        componentName: String,
        recentWindow: Int = 7,
        baselineWindow: Int = 30
    ) -> DriftReport? {
        lock.lock()
        let resolvedSnapshot = resolvedEvents
        lock.unlock()

        let calendar = Date.cal
        let now = Date()

        let recentCutoff = calendar.date(byAdding: .day, value: -recentWindow, to: now) ?? now
        let baselineCutoff = calendar.date(byAdding: .day, value: -baselineWindow, to: now) ?? now

        let componentEvents = resolvedSnapshot.filter { $0.componentName == componentName }

        // Collect absolute residuals in each window
        let recentResiduals = componentEvents
            .filter { $0.outcome != nil && $0.predictedAt >= recentCutoff }
            .compactMap { $0.outcome.map { abs($0.residual) } }

        let baselineResiduals = componentEvents
            .filter {
                $0.outcome != nil &&
                $0.predictedAt >= baselineCutoff &&
                $0.predictedAt < recentCutoff
            }
            .compactMap { $0.outcome.map { abs($0.residual) } }

        // Need minimum samples in both windows
        guard recentResiduals.count >= 3, baselineResiduals.count >= 5 else { return nil }

        let recentMean = recentResiduals.mean
        let baselineMean = baselineResiduals.mean

        let pValue = welchTTest(sample1: recentResiduals, sample2: baselineResiduals)

        let isDrifting = pValue < Self.driftAlpha && recentMean > baselineMean

        let recommendation: String
        if isDrifting {
            let degradation = ((recentMean - baselineMean) / Swift.max(baselineMean, 1e-9)) * 100.0
            recommendation = "Retrain recommended: mean absolute residual increased by "
                + String(format: "%.1f%%", degradation)
                + " (p=\(String(format: "%.4f", pValue)))"
        } else {
            recommendation = "Model stable"
        }

        return DriftReport(
            componentName: componentName,
            metricName: "absolute_residual",
            baselineMean: baselineMean,
            recentMean: recentMean,
            pValue: pValue,
            isDrifting: isDrifting,
            recommendation: recommendation
        )
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

    // MARK: - Welch's t-Test

    /// Performs a two-sample Welch's t-test (unequal variances) and returns the p-value.
    ///
    /// Uses the Welch-Satterthwaite approximation for degrees of freedom and a t-distribution
    /// CDF approximation for the p-value (two-tailed).
    private func welchTTest(sample1: [Double], sample2: [Double]) -> Double {
        let n1 = Double(sample1.count)
        let n2 = Double(sample2.count)
        guard n1 >= 2, n2 >= 2 else { return 1.0 }

        let mean1 = sample1.mean
        let mean2 = sample2.mean

        // Sample variances (Bessel-corrected)
        var ss1 = 0.0
        for v in sample1 { ss1 += (v - mean1) * (v - mean1) }
        let var1 = ss1 / (n1 - 1.0)

        var ss2 = 0.0
        for v in sample2 { ss2 += (v - mean2) * (v - mean2) }
        let var2 = ss2 / (n2 - 1.0)

        let se1 = var1 / n1
        let se2 = var2 / n2
        let seDiff = se1 + se2

        guard seDiff > 1e-15 else { return 1.0 }

        let tStat = (mean1 - mean2) / seDiff.squareRoot()

        // Welch-Satterthwaite degrees of freedom
        let numeratorDF = seDiff * seDiff
        let denom1 = se1 > 0 ? (se1 * se1) / (n1 - 1.0) : 0
        let denom2 = se2 > 0 ? (se2 * se2) / (n2 - 1.0) : 0
        let denominatorDF = denom1 + denom2

        guard denominatorDF > 1e-15 else { return 1.0 }
        let df = numeratorDF / denominatorDF

        // Two-tailed p-value from t-distribution CDF
        return tDistributionPValue(tStat: abs(tStat), df: df)
    }

    /// Approximates the two-tailed p-value from a t-distribution using the regularized
    /// incomplete beta function relationship: p = I(df/(df+t^2), df/2, 1/2).
    private func tDistributionPValue(tStat: Double, df: Double) -> Double {
        guard tStat.isFinite, df > 0 else { return 1.0 }

        let x = df / (df + tStat * tStat)
        let a = df / 2.0
        let b = 0.5

        let betaValue = regularizedIncompleteBeta(x: x, a: a, b: b)
        return Swift.max(0.0, Swift.min(1.0, betaValue))
    }

    /// Computes the regularized incomplete beta function I_x(a, b) using a continued fraction
    /// expansion (Lentz's method).
    private func regularizedIncompleteBeta(x: Double, a: Double, b: Double) -> Double {
        guard x > 0, x < 1 else {
            if x <= 0 { return 0.0 }
            return 1.0
        }

        // Use symmetry relation for numerical stability
        if x > (a + 1.0) / (a + b + 2.0) {
            return 1.0 - regularizedIncompleteBeta(x: 1.0 - x, a: b, b: a)
        }

        // Log-beta function for normalization
        let logBeta = lgamma(a) + lgamma(b) - lgamma(a + b)
        let prefactor = exp(a * log(x) + b * log(1.0 - x) - logBeta) / a

        // Continued fraction (Lentz's method)
        let maxIterations = 200
        let epsilon = 1e-12
        let tiny = 1e-30

        var c = 1.0
        var d = 1.0 / Swift.max(abs(1.0 - (a + b) * x / (a + 1.0)), tiny)
        var h = d

        for m in 1...maxIterations {
            let mDouble = Double(m)

            // Even step: d_{2m}
            let numerator1 = mDouble * (b - mDouble) * x /
                ((a + 2.0 * mDouble - 1.0) * (a + 2.0 * mDouble))

            d = 1.0 / Swift.max(abs(1.0 + numerator1 * d), tiny)
            c = Swift.max(abs(1.0 + numerator1 / c), tiny)
            h *= d * c

            // Odd step: d_{2m+1}
            let numerator2 = -((a + mDouble) * (a + b + mDouble) * x) /
                ((a + 2.0 * mDouble) * (a + 2.0 * mDouble + 1.0))

            d = 1.0 / Swift.max(abs(1.0 + numerator2 * d), tiny)
            c = Swift.max(abs(1.0 + numerator2 / c), tiny)
            let delta = d * c
            h *= delta

            if abs(delta - 1.0) < epsilon {
                break
            }
        }

        return Swift.max(0.0, Swift.min(1.0, prefactor * h))
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

/// Summary of recommendation effectiveness over a rolling window.
struct RecommendationEvaluation {
    /// Total recommendations shown in the window.
    let totalShown: Int
    /// Recommendations where adherenceScore > 0.5.
    let totalFollowed: Int
    /// Mean uplift across all recommendations with available data.
    let averageUplift: Double
    /// Average uplift broken down by action type.
    let upliftByActionType: [String: Double]
    /// Top 3 action types by average uplift.
    let bestActionTypes: [String]
    /// Bottom 3 action types by average uplift.
    let worstActionTypes: [String]
    /// Pearson correlation between exposure count and adherence (negative = fatigue).
    let exposureFatigueRate: Double
}

/// Report on whether a model component is experiencing performance drift.
struct DriftReport {
    /// The component being evaluated.
    let componentName: String
    /// The metric used for drift detection.
    let metricName: String
    /// Mean metric value over the baseline window.
    let baselineMean: Double
    /// Mean metric value over the recent window.
    let recentMean: Double
    /// Two-tailed p-value from Welch's t-test.
    let pValue: Double
    /// Whether statistically significant degradation was detected (p < 0.05 and recent > baseline).
    let isDrifting: Bool
    /// Human-readable recommendation.
    let recommendation: String
}
