import Foundation

/// Uncertainty estimation and confidence gating for ML predictions.
/// Prevents overconfident predictions from reaching users by combining
/// conformal prediction intervals, ensemble disagreement, data sufficiency,
/// and evaluation-aware confidence gates.
enum UncertaintyEstimator {

    // MARK: - Conformal Prediction Intervals

    /// A prediction interval with guaranteed coverage (given exchangeability).
    struct PredictionInterval {
        let lower: Double
        let upper: Double
        let coverage: Double               // e.g., 0.90 for 90% interval
        let width: Double                  // upper - lower
    }

    /// Compute a conformal prediction interval using split conformal prediction.
    ///
    /// Given a set of calibration residuals (|actual - predicted| from a held-out calibration set),
    /// the interval is formed by taking the quantile at level ceil((n+1) * coverage) / n
    /// of the sorted absolute residuals.
    ///
    /// - Parameters:
    ///   - calibrationResiduals: Absolute residuals |actual - predicted| from calibration data.
    ///   - pointPrediction: The model's point prediction for the new input.
    ///   - coverageLevel: Desired coverage probability (e.g., 0.90 for 90%). Clamped to [0.5, 0.99].
    /// - Returns: A `PredictionInterval` centered on the point prediction.
    static func conformalInterval(
        calibrationResiduals: [Double],
        pointPrediction: Double,
        coverageLevel: Double = 0.90
    ) -> PredictionInterval {
        let coverage = Swift.max(0.5, Swift.min(coverageLevel, 0.99))

        guard !calibrationResiduals.isEmpty else {
            // No calibration data — return a degenerate interval
            return PredictionInterval(
                lower: pointPrediction,
                upper: pointPrediction,
                coverage: coverage,
                width: 0
            )
        }

        let sorted = calibrationResiduals.map { abs($0) }.sorted()
        let n = sorted.count

        // Quantile index: ceil((n+1) * coverage) - 1, clamped to [0, n-1]
        let quantileIndex = Swift.min(
            Int(ceil(Double(n + 1) * coverage)) - 1,
            n - 1
        )
        let safeIndex = Swift.max(0, quantileIndex)
        let radius = sorted[safeIndex]

        return PredictionInterval(
            lower: pointPrediction - radius,
            upper: pointPrediction + radius,
            coverage: coverage,
            width: 2.0 * radius
        )
    }

    // MARK: - Ensemble Disagreement

    /// Disagreement statistics from an ensemble of model predictions.
    struct EnsembleUncertainty {
        let meanPrediction: Double
        let stdDeviation: Double
        let coefficientOfVariation: Double  // stdDev / |mean|, or 0 if mean is near zero
        let isHighUncertainty: Bool         // CV > threshold
    }

    /// Measure ensemble disagreement across multiple predictions from model variants.
    ///
    /// For the PredictiveScorer, this could use bootstrap subsets of the weight vector.
    /// For the TimeSeriesForecaster, this could use multiple parameter configurations from the grid search.
    ///
    /// - Parameters:
    ///   - predictions: Predictions from N model variants (at least 2).
    ///   - cvThreshold: Coefficient of variation above which uncertainty is considered "high". Default 0.3.
    /// - Returns: An `EnsembleUncertainty` summary, or nil if fewer than 2 predictions.
    static func ensembleDisagreement(
        predictions: [Double],
        cvThreshold: Double = 0.3
    ) -> EnsembleUncertainty? {
        guard predictions.count >= 2 else { return nil }

        let mean = AccelerateML.mean(predictions)
        let (_, variance) = AccelerateML.welfordVariance(predictions)
        let stdDev = variance.squareRoot()

        let cv: Double
        if abs(mean) > 1e-9 {
            cv = stdDev / abs(mean)
        } else {
            cv = stdDev > 1e-9 ? 1.0 : 0.0
        }

        return EnsembleUncertainty(
            meanPrediction: mean,
            stdDeviation: stdDev,
            coefficientOfVariation: cv,
            isHighUncertainty: cv > cvThreshold
        )
    }

    // MARK: - Data Sufficiency

    /// Assessment of how much data a user has relative to each ML component's needs.
    struct DataSufficiency {
        let overallScore: Double            // 0-1, composite
        let totalDays: Int
        let metricCoverage: Double          // Fraction of expected metrics present
        let recencyScore: Double            // How recent is the latest data (1.0 = today)
        let minimumMetDays: Int             // Days above minimum for all components
        let recommendation: String          // e.g., "Keep tracking for 12 more days for full predictions"
    }

    /// Component minimum day requirements (from each ML class's `minimumDays`).
    private static let componentMinimums: [String: Int] = [
        "FeatureEngine": FeatureEngine.minimumDays,            // 7
        "CircadianAnalyzer": CircadianAnalyzer.minimumDays,    // 14
        "TimeSeriesForecaster": TimeSeriesForecaster.minimumDays, // 21
        "PredictiveScorer": PredictiveScorer.minimumDays,      // 30
        "CorrelationDiscovery": CorrelationDiscovery.minimumDays, // 30
        "PatternMiner": PatternMiner.minimumDays,              // 60
        "HealthStateClassifier": HealthStateClassifier.minimumDays, // 60
        "AdaptiveAnomalyDetector": AdaptiveAnomalyDetector.minimumDays, // 60
    ]

    /// Assess how sufficient the user's data is for ML analysis.
    ///
    /// - Parameters:
    ///   - timeSeries: Available metric time series.
    ///   - requiredMetrics: Metrics the app expects to see for full analysis.
    ///   - overrideMinimums: Optional override for component minimums (for testing).
    /// - Returns: A `DataSufficiency` assessment.
    static func assessDataSufficiency(
        timeSeries: [HealthMetric: MetricTimeSeries],
        requiredMetrics: [HealthMetric],
        overrideMinimums: [String: Int]? = nil
    ) -> DataSufficiency {
        let minimums = overrideMinimums ?? componentMinimums

        // Total days of data (based on longest time series)
        let totalDays = timeSeries.values.map(\.daysOfData).max() ?? 0

        // Metric coverage: fraction of required metrics that have any data
        let presentCount: Int
        if requiredMetrics.isEmpty {
            presentCount = 0
        } else {
            presentCount = requiredMetrics.filter { timeSeries[$0] != nil }.count
        }
        let metricCoverage = requiredMetrics.isEmpty ? 0 : Double(presentCount) / Double(requiredMetrics.count)

        // Recency: exponential decay from most recent data point
        let calendar = Calendar.current
        let now = Date()
        let latestDate = timeSeries.values
            .compactMap { $0.sortedSamples.last?.date }
            .max()

        let recencyScore: Double
        if let latest = latestDate {
            let daysSinceLast = calendar.dateComponents([.day], from: latest, to: now).day ?? 0
            // Score decays: 1.0 for today, 0.5 for 3 days ago, ~0 for 14+ days
            recencyScore = Swift.max(0, exp(-0.23 * Double(daysSinceLast)))
        } else {
            recencyScore = 0
        }

        // Minimum met days: how many days past the hardest minimum
        let maxMinimum = minimums.values.max() ?? 60
        let minimumMetDays = Swift.max(0, totalDays - maxMinimum)

        // Overall score: weighted combination
        // 40% data volume (capped at maxMinimum days), 30% metric coverage, 30% recency
        let volumeScore = Swift.min(Double(totalDays) / Double(maxMinimum), 1.0)
        let overallScore = 0.4 * volumeScore + 0.3 * metricCoverage + 0.3 * recencyScore

        // Recommendation message
        let recommendation = generateSufficiencyRecommendation(
            totalDays: totalDays,
            metricCoverage: metricCoverage,
            recencyScore: recencyScore,
            minimums: minimums
        )

        return DataSufficiency(
            overallScore: Swift.min(1.0, Swift.max(0, overallScore)),
            totalDays: totalDays,
            metricCoverage: metricCoverage,
            recencyScore: recencyScore,
            minimumMetDays: minimumMetDays,
            recommendation: recommendation
        )
    }

    /// Generate a human-readable recommendation based on data gaps.
    private static func generateSufficiencyRecommendation(
        totalDays: Int,
        metricCoverage: Double,
        recencyScore: Double,
        minimums: [String: Int]
    ) -> String {
        if recencyScore < 0.3 {
            return "Your data is stale. Open the app to sync the latest health data."
        }

        if metricCoverage < 0.5 {
            return "Enable more health metrics in Apple Health for richer analysis."
        }

        // Find the next milestone the user hasn't reached
        let sortedMinimums = minimums.sorted { $0.value < $1.value }
        for entry in sortedMinimums {
            if totalDays < entry.value {
                let remaining = entry.value - totalDays
                return "Keep tracking for \(remaining) more day\(remaining == 1 ? "" : "s") to unlock \(entry.key) predictions."
            }
        }

        if metricCoverage < 1.0 {
            return "Great data depth. Enable additional metrics for even better insights."
        }

        return "Excellent data coverage across all ML components."
    }

    // MARK: - Confidence Gate

    /// Confidence tier for gating decisions.
    enum ConfidenceTier: String {
        case confident = "confident"      // >= 0.4 effective confidence
        case suggestive = "suggestive"    // >= 0.2 effective confidence
        case gated = "gated"             // below 0.2
    }

    /// Result of the confidence gate: should this prediction be shown?
    struct ConfidenceGate {
        let shouldShow: Bool
        let confidenceScore: Double         // 0-1 final confidence
        let reason: String?                 // Why it was gated (if shouldShow == false)
        let tier: ConfidenceTier
    }

    /// Determine whether a prediction/insight should be shown to the user.
    ///
    /// Requires BOTH:
    /// 1. Sufficient data (overallScore >= 0.3)
    /// 2. Model confidence (adjusted by evaluation quality) >= minimumConfidence
    ///
    /// If evaluation metrics are available, accuracy degrades the effective confidence
    /// to prevent showing outputs from poorly performing models.
    ///
    /// - Parameters:
    ///   - modelConfidence: Raw confidence from the ML component (0-1).
    ///   - dataSufficiency: Data sufficiency assessment.
    ///   - evaluationMetrics: Optional classification metrics from model evaluation.
    ///   - minimumConfidence: Minimum effective confidence to pass the gate. Default 0.4.
    /// - Returns: A `ConfidenceGate` decision.
    static func gate(
        modelConfidence: Double,
        dataSufficiency: DataSufficiency,
        evaluationMetrics: ModelEvaluationEngine.ClassificationMetrics?,
        minimumConfidence: Double = 0.4
    ) -> ConfidenceGate {
        // Gate 1: Data sufficiency
        let dataSufficiencyThreshold = 0.3
        guard dataSufficiency.overallScore >= dataSufficiencyThreshold else {
            return ConfidenceGate(
                shouldShow: false,
                confidenceScore: 0,
                reason: "Insufficient data: \(dataSufficiency.recommendation)",
                tier: .gated
            )
        }

        // Compute effective confidence
        var effectiveConfidence = modelConfidence

        // If we have evaluation metrics, adjust confidence by model accuracy
        if let eval = evaluationMetrics {
            // Softened accuracy penalty: pow(accuracy, 0.3)
            // 60% accuracy only reduces confidence by ~15%; 90% barely reduces it.
            let accuracyMultiplier = pow(eval.accuracy, 0.3)
            effectiveConfidence *= accuracyMultiplier

            // Further penalize badly calibrated models
            // ECE of 0 is perfect; ECE of 0.2+ is poor calibration
            let calibrationPenalty = Swift.max(0, 1.0 - eval.calibrationError * 2.5)
            effectiveConfidence *= calibrationPenalty
        }

        // Clamp
        effectiveConfidence = Swift.max(0, Swift.min(1.0, effectiveConfidence))

        // Tiered gating instead of binary threshold
        let tier: ConfidenceTier
        if effectiveConfidence >= minimumConfidence {
            tier = .confident
        } else if effectiveConfidence >= 0.2 {
            tier = .suggestive
        } else {
            tier = .gated
        }

        guard tier != .gated else {
            return ConfidenceGate(
                shouldShow: false,
                confidenceScore: effectiveConfidence,
                reason: "Model confidence too low (\(Int(effectiveConfidence * 100))%). Need at least 20%.",
                tier: .gated
            )
        }

        return ConfidenceGate(
            shouldShow: true,
            confidenceScore: effectiveConfidence,
            reason: tier == .suggestive ? "Suggestive — based on limited data." : nil,
            tier: tier
        )
    }

    // MARK: - Personalization Blend Weight

    /// Compute how much to trust the personalized model vs a base/rule-based model.
    ///
    /// Uses a sigmoid ramp: w = sigmoid((days - rampUpDays/2) / (rampUpDays/6))
    /// - At 0 days: w ~ 0 (all base model)
    /// - At rampUpDays/2: w = 0.5
    /// - At rampUpDays: w ~ 1.0 (all personalized)
    ///
    /// If model accuracy is known and poor, the weight is reduced proportionally.
    ///
    /// - Parameters:
    ///   - userDataDays: Number of days of user data available.
    ///   - modelAccuracy: Optional accuracy from evaluation (0-1). If nil, only time-based ramp is used.
    ///   - rampUpDays: Days to reach near-full personalization. Default 60.
    /// - Returns: Personalization weight in [0, 1].
    static func personalizationWeight(
        userDataDays: Int,
        modelAccuracy: Double?,
        rampUpDays: Int = 60
    ) -> Double {
        let ramp = Double(rampUpDays)
        guard ramp > 0 else { return 1.0 }

        // Sigmoid ramp: sigmoid((days - rampUpDays/2) / (rampUpDays/6))
        let midpoint = ramp / 2.0
        let steepness = ramp / 6.0
        guard steepness > 0 else { return Double(userDataDays) >= midpoint ? 1.0 : 0.0 }

        let x = (Double(userDataDays) - midpoint) / steepness
        let sigmoidValue = AccelerateML.sigmoid(x)

        // Clamp to [0, 1]
        var weight = Swift.max(0, Swift.min(1.0, sigmoidValue))

        // If accuracy is known and poor, reduce personalization weight
        if let accuracy = modelAccuracy {
            // Below 0.5 accuracy, prefer base model entirely
            // Above 0.7 accuracy, full personalization weight
            let accuracyFactor = Swift.max(0, Swift.min(1.0, (accuracy - 0.5) / 0.2))
            weight *= accuracyFactor
        }

        return weight
    }

    // MARK: - Bootstrap Confidence Interval

    /// Compute a bootstrap confidence interval for a statistic (e.g., mean, median).
    /// Useful for estimating uncertainty in baseline calculations.
    ///
    /// - Parameters:
    ///   - values: The original sample.
    ///   - statistic: Function to compute the statistic of interest on a bootstrap sample.
    ///   - bootstrapCount: Number of bootstrap resamples. Default 200.
    ///   - confidenceLevel: Coverage level for the interval. Default 0.95.
    /// - Returns: A `PredictionInterval` for the statistic.
    static func bootstrapInterval(
        values: [Double],
        statistic: ([Double]) -> Double,
        bootstrapCount: Int = 200,
        confidenceLevel: Double = 0.95
    ) -> PredictionInterval? {
        guard values.count >= 5 else { return nil }

        let n = values.count
        var bootstrapStats = [Double]()
        bootstrapStats.reserveCapacity(bootstrapCount)

        for _ in 0..<bootstrapCount {
            var resample = [Double]()
            resample.reserveCapacity(n)
            for _ in 0..<n {
                resample.append(values[Int.random(in: 0..<n)])
            }
            bootstrapStats.append(statistic(resample))
        }

        bootstrapStats.sort()

        let alpha = 1.0 - confidenceLevel
        let lowerIndex = Swift.max(0, Int(floor(alpha / 2.0 * Double(bootstrapCount))))
        let upperIndex = Swift.min(bootstrapCount - 1, Int(ceil((1.0 - alpha / 2.0) * Double(bootstrapCount))) - 1)

        let lower = bootstrapStats[lowerIndex]
        let upper = bootstrapStats[upperIndex]

        return PredictionInterval(
            lower: lower,
            upper: upper,
            coverage: confidenceLevel,
            width: upper - lower
        )
    }

    // MARK: - Per-Component Readiness

    /// Quick summary of which ML components have enough data to produce reliable results.
    struct ComponentReadiness {
        let componentName: String
        let minimumDays: Int
        let currentDays: Int
        let isReady: Bool
        let readinessPercent: Double        // 0-100, capped at 100
    }

    /// Check readiness of all ML components given the available data.
    static func checkComponentReadiness(
        totalDays: Int
    ) -> [ComponentReadiness] {
        return componentMinimums
            .sorted { $0.value < $1.value }
            .map { (name, minimum) in
                let percent = Swift.min(100.0, Double(totalDays) / Double(minimum) * 100.0)
                return ComponentReadiness(
                    componentName: name,
                    minimumDays: minimum,
                    currentDays: totalDays,
                    isReady: totalDays >= minimum,
                    readinessPercent: percent
                )
            }
    }
}
