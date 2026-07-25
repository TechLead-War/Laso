import Foundation

/// Uncertainty estimation and confidence gating for ML predictions.
/// Prevents overconfident predictions from reaching users by combining
/// data sufficiency, confidence gating, and per-component readiness.
enum UncertaintyEstimator {

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
        "CorrelationDiscovery": CorrelationDiscovery.minimumDays, // 7
        "TimeSeriesForecaster": TimeSeriesForecaster.minimumDays, // 7
        "PersonalOptimizer": PersonalOptimizer.minimumDays,    // 7
        "CircadianAnalyzer": CircadianAnalyzer.minimumDays,    // 14
        "PredictiveScorer": PredictiveScorer.minimumDays,      // 14
        "PatternMiner": PatternMiner.minimumDays,              // 14
        "HealthStateClassifier": HealthStateClassifier.minimumDays, // 14
        "AdaptiveAnomalyDetector": AdaptiveAnomalyDetector.minimumDays, // 14
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
        let calendar = Date.cal
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
    /// - Parameters:
    ///   - modelConfidence: Raw confidence from the ML component (0-1).
    ///   - dataSufficiency: Data sufficiency assessment.
    ///   - minimumConfidence: Minimum effective confidence to pass the gate. Default 0.4.
    /// - Returns: A `ConfidenceGate` decision.
    static func gate(
        modelConfidence: Double,
        dataSufficiency: DataSufficiency,
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
            reason: tier == .suggestive ? "Suggestive. based on limited data." : nil,
            tier: tier
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
