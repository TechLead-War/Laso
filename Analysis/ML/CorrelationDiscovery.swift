import Foundation

/// Tests ALL metric pairs (not just 35 hardcoded) using mutual information, Granger causality,
/// partial correlation, and dynamic stability tracking.
final class CorrelationDiscovery {
    /// Minimum days of paired data required
    static let minimumDays = 30

    /// Minimum bins for mutual information estimation (adaptive: sqrt(n))
    private static let minMIBins = 5
    /// Maximum lag for Granger causality (days)
    private static let maxGrangerLag = 3
    /// Sliding window for stability tracking
    private static let stabilityWindow = 30

    /// Discovered correlations
    private(set) var correlations: [MLCorrelation] = []

    /// Last analysis date — guards against rerunning too frequently
    private var lastAnalysisDate: Date?

    /// Whether a full reanalysis is needed (never run, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastAnalysis = lastAnalysisDate else { return true }
        return Date().timeIntervalSince(lastAnalysis) > 30 * 24 * 3600
    }

    // MARK: - Discovery

    /// Discover all significant correlations between metric pairs
    func discover(timeSeries: [HealthMetric: MetricTimeSeries]) {
        correlations = []
        let calendar = Calendar.current
        let recentCutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Filter to metrics with data in the past 7 days
        let activeMetrics = Array(timeSeries.keys.filter { metric in
            guard let series = timeSeries[metric] else { return false }
            return series.sortedSamples.last.map { $0.date >= recentCutoff } ?? false
        }).sorted { $0.rawValue < $1.rawValue }

        let metrics = activeMetrics
        guard metrics.count >= 2 else { return }

        // Build date-aligned values for each metric
        var dateValues: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            var dv: [Date: Double] = [:]
            for sample in series.sortedSamples {
                dv[calendar.startOfDay(for: sample.date)] = sample.value
            }
            dateValues[metric] = dv
        }

        // Test all N*(N-1)/2 pairs
        for i in 0..<metrics.count {
            for j in (i + 1)..<metrics.count {
                let metricA = metrics[i]
                let metricB = metrics[j]

                guard let datesA = dateValues[metricA],
                      let datesB = dateValues[metricB] else { continue }

                // Find overlapping dates
                let commonDates = Set(datesA.keys).intersection(Set(datesB.keys))
                    .sorted()

                guard commonDates.count >= Self.minimumDays else { continue }

                let valuesA = commonDates.compactMap { datesA[$0] }
                let valuesB = commonDates.compactMap { datesB[$0] }

                guard valuesA.count == valuesB.count,
                      valuesA.count >= Self.minimumDays else { continue }

                // 1. Pearson correlation
                let pearsonR = [Double].pearsonCorrelation(valuesA, valuesB) ?? 0

                // 2. Mutual information (always compute — catches non-linear relationships
                // that Pearson misses, e.g., U-shaped dose-response curves)
                let mi = mutualInformation(valuesA, valuesB)

                // Adaptive MI significance: MI > log(n)/n is a rough threshold for
                // independent variables (higher MI than expected by chance)
                let n = valuesA.count
                let miSignificanceThreshold = log(Double(n)) / Double(n)

                // Skip only if BOTH linear and non-linear associations are negligible
                guard abs(pearsonR) >= 0.10 || mi > miSignificanceThreshold else { continue }

                // Tiered pruning: skip expensive tests for weak correlations
                let grangerCausal: Bool
                let grangerP: Double
                var partialCorr: Double?
                var confounder: HealthMetric?
                let stability: Double

                var effectSize: Double = 0
                var optimalLagDays: Int = 0

                if abs(pearsonR) >= 0.25 || mi > miSignificanceThreshold * 3 {
                    // 3. Granger causality (A → B) using proper OLS + F-distribution
                    let grangerResult = GrangerCausalityEngine.test(
                        cause: valuesA, effect: valuesB,
                        causeMetric: metricA, effectMetric: metricB,
                        maxLag: Self.maxGrangerLag
                    )
                    grangerCausal = grangerResult?.isCausal ?? false
                    grangerP = grangerResult?.pValue ?? 1.0
                    effectSize = grangerResult?.effectSize ?? 0
                    optimalLagDays = grangerResult?.optimalLagDays ?? 0

                    // 4. Partial correlation (controlling for strongest confounder)
                    if metrics.count > 2 {
                        (partialCorr, confounder) = partialCorrelation(
                            a: valuesA, b: valuesB,
                            metricA: metricA, metricB: metricB,
                            allDateValues: dateValues,
                            commonDates: commonDates
                        )
                    }

                    // 5. Stability over sliding windows
                    stability = correlationStability(valuesA, valuesB)
                } else {
                    // Weak-moderate (0.15-0.25): only Pearson + MI
                    grangerCausal = false
                    grangerP = 1.0
                    stability = 1.0
                }

                let correlation = MLCorrelation(
                    metricA: metricA,
                    metricB: metricB,
                    pearsonR: pearsonR,
                    mutualInformation: mi,
                    grangerCausal: grangerCausal,
                    grangerPValue: grangerP,
                    partialCorrelation: partialCorr,
                    confounderMetric: confounder,
                    stability: stability,
                    sampleCount: valuesA.count,
                    grangerEffectSize: effectSize,
                    grangerOptimalLag: optimalLagDays,
                    survivedFDR: true // Will be updated by applyBenjaminiHochberg
                )

                if correlation.isSignificant {
                    correlations.append(correlation)
                }
            }
        }

        // Sort by overall strength
        correlations.sort { $0.overallStrength > $1.overallStrength }

        // Apply Benjamini-Hochberg FDR correction
        applyBenjaminiHochberg(alpha: 0.05)

        lastAnalysisDate = Date()
    }

    // MARK: - Mutual Information

    /// Estimate mutual information via adaptive binning (sqrt(n) bins instead of hardcoded 10)
    private func mutualInformation(_ x: [Double], _ y: [Double]) -> Double {
        let n = x.count
        guard n >= Self.minimumDays else { return 0 }

        // Adaptive bin count: sqrt(n) is optimal for MI estimation (Kraskov et al.)
        // Clamped to [5, 20] to avoid under/over-binning
        let bins = max(Self.minMIBins, min(Int(Double(n).squareRoot()), 20))

        guard let xMin = x.min(), let xMax = x.max(),
              let yMin = y.min(), let yMax = y.max(),
              xMax > xMin, yMax > yMin else { return 0 }

        let xRange = xMax - xMin
        let yRange = yMax - yMin

        // Build joint histogram
        var joint = [[Int]](repeating: [Int](repeating: 0, count: bins), count: bins)
        var margX = [Int](repeating: 0, count: bins)
        var margY = [Int](repeating: 0, count: bins)

        for i in 0..<n {
            let xBin = Swift.min(Int((x[i] - xMin) / xRange * Double(bins)), bins - 1)
            let yBin = Swift.min(Int((y[i] - yMin) / yRange * Double(bins)), bins - 1)
            joint[xBin][yBin] += 1
            margX[xBin] += 1
            margY[yBin] += 1
        }

        // Compute MI = sum p(x,y) * log(p(x,y) / (p(x) * p(y)))
        var mi: Double = 0
        let nDouble = Double(n)

        for xi in 0..<bins {
            for yi in 0..<bins {
                let jointCount = joint[xi][yi]
                guard jointCount > 0 else { continue }

                let pxy = Double(jointCount) / nDouble
                let px = Double(margX[xi]) / nDouble
                let py = Double(margY[yi]) / nDouble

                guard px > 0, py > 0 else { continue }
                mi += pxy * log(pxy / (px * py))
            }
        }

        return max(mi, 0) // MI is non-negative
    }

    // MARK: - Partial Correlation

    /// Compute partial correlation r_ab|c controlling for the strongest confounder
    private func partialCorrelation(
        a: [Double], b: [Double],
        metricA: HealthMetric, metricB: HealthMetric,
        allDateValues: [HealthMetric: [Date: Double]],
        commonDates: [Date]
    ) -> (partialR: Double?, confounder: HealthMetric?) {
        var bestConfounder: HealthMetric?
        var bestConfR: Double = 0

        // Find the metric most correlated with both A and B
        for (metric, dv) in allDateValues {
            guard metric != metricA, metric != metricB else { continue }

            let cValues = commonDates.compactMap { dv[$0] }
            guard cValues.count == a.count else { continue }

            let rAC = abs([Double].pearsonCorrelation(a, cValues) ?? 0)
            let rBC = abs([Double].pearsonCorrelation(b, cValues) ?? 0)
            let confStrength = rAC * rBC

            if confStrength > bestConfR {
                bestConfR = confStrength
                bestConfounder = metric
            }
        }

        guard let confounder = bestConfounder,
              let confValues = allDateValues[confounder] else { return (nil, nil) }

        let c = commonDates.compactMap { confValues[$0] }
        guard c.count == a.count else { return (nil, nil) }

        let rAB = [Double].pearsonCorrelation(a, b) ?? 0
        let rAC = [Double].pearsonCorrelation(a, c) ?? 0
        let rBC = [Double].pearsonCorrelation(b, c) ?? 0

        let denominator = ((1 - rAC * rAC) * (1 - rBC * rBC)).squareRoot()
        guard denominator > 0 else { return (nil, nil) }

        let partialR = (rAB - rAC * rBC) / denominator
        return (partialR, confounder)
    }

    // MARK: - Stability Tracking

    /// Track how stable the correlation is over sliding windows
    private func correlationStability(_ x: [Double], _ y: [Double]) -> Double {
        let windowSize = Self.stabilityWindow
        let n = Swift.min(x.count, y.count)
        guard n >= windowSize * 2 else { return 1.0 } // Not enough data to assess

        var windowCorrelations: [Double] = []
        let step = max(windowSize / 3, 1)

        var start = 0
        while start + windowSize <= n {
            let xWindow = Array(x[start..<(start + windowSize)])
            let yWindow = Array(y[start..<(start + windowSize)])
            if let r = [Double].pearsonCorrelation(xWindow, yWindow) {
                windowCorrelations.append(r)
            }
            start += step
        }

        guard windowCorrelations.count >= 2 else { return 1.0 }

        // Stability = 1 - coefficient of variation of window correlations
        let sd = windowCorrelations.standardDeviation
        let mean = windowCorrelations.mean
        guard mean != 0 else { return 0.5 }

        let cv = abs(sd / mean)
        return max(0, min(1, 1.0 - cv))
    }

    // MARK: - State

    var isReady: Bool { !correlations.isEmpty }

    /// Get correlations for a specific metric
    func correlations(for metric: HealthMetric) -> [MLCorrelation] {
        correlations.filter { $0.metricA == metric || $0.metricB == metric }
    }

    /// Get top N strongest correlations
    func topCorrelations(_ count: Int = 10) -> [MLCorrelation] {
        Array(correlations.prefix(count))
    }

    /// Get only causal relationships
    func causalRelationships() -> [MLCorrelation] {
        correlations.filter { $0.grangerCausal }
    }

    /// Get only correlations that survived FDR correction
    func fdrSignificantCorrelations() -> [MLCorrelation] {
        correlations.filter { $0.survivedFDR }
    }

    // MARK: - Multivariate Extension

    /// Minimum days required for multivariate regression
    static let minimumDaysMultivariate = 45

    /// Run multivariate Granger regression for a target metric using individually
    /// significant pairwise predictors. This reduces spurious causality from omitted variables.
    ///
    /// Only predictors with pairwise Granger p < 0.1 are included.
    /// Requires at least 3 significant pairwise correlations for the target.
    ///
    /// - Parameters:
    ///   - target: The target metric
    ///   - candidates: Pairwise correlations involving the target
    ///   - timeSeries: Dictionary mapping metrics to date-aligned values (chronologically ordered)
    /// - Returns: MultivariateRegressionResult, or nil if insufficient predictors or data
    func discoverMultivariate(
        target: HealthMetric,
        candidates: [MLCorrelation],
        timeSeries: [HealthMetric: [Double]]
    ) -> MultivariateRegressionResult? {
        // Filter to individually significant predictors (pairwise Granger p < 0.1)
        let significantPredictors = candidates.compactMap { corr -> HealthMetric? in
            guard corr.grangerPValue < 0.1 else { return nil }
            // Identify which metric is the predictor (not the target)
            if corr.metricA == target { return corr.metricB }
            if corr.metricB == target { return corr.metricA }
            return nil
        }

        // Need at least 3 individually significant predictors
        let uniquePredictors = Array(Set(significantPredictors))
        guard uniquePredictors.count >= 3 else { return nil }

        // Check data sufficiency
        guard let targetSeries = timeSeries[target],
              targetSeries.count >= Self.minimumDaysMultivariate else { return nil }

        // Build aligned time series dict for the engine
        var alignedSeries: [HealthMetric: [Double]] = [target: targetSeries]
        var validPredictors: [HealthMetric] = []

        for pred in uniquePredictors {
            guard let predSeries = timeSeries[pred],
                  predSeries.count == targetSeries.count else { continue }
            alignedSeries[pred] = predSeries
            validPredictors.append(pred)
        }

        guard validPredictors.count >= 3 else { return nil }

        // Cap predictors to avoid overfitting (max 8 predictors)
        let cappedPredictors = Array(validPredictors.prefix(8))

        return GrangerCausalityEngine.multivariateGrangerTest(
            target: target,
            predictors: cappedPredictors,
            timeSeries: alignedSeries,
            maxLag: Self.maxGrangerLag
        )
    }

    // MARK: - Benjamini-Hochberg FDR Correction

    /// Apply Benjamini-Hochberg False Discovery Rate correction to all pairwise Granger p-values.
    ///
    /// Procedure:
    ///   1. Collect all Granger p-values and sort ascending
    ///   2. For each sorted p-value p_{(i)}, compute BH threshold: (i / m) * α
    ///   3. Find the largest i where p_{(i)} ≤ threshold
    ///   4. All correlations with p_{(i)} at or below that index survive FDR
    ///
    /// - Parameter alpha: FDR significance level (default 0.05)
    private func applyBenjaminiHochberg(alpha: Double = 0.05) {
        let m = correlations.count
        guard m > 0 else { return }

        // Create indexed p-values, only considering correlations that had Granger tests
        struct IndexedPValue {
            let index: Int
            let pValue: Double
        }

        var indexedPValues: [IndexedPValue] = []
        for (idx, corr) in correlations.enumerated() {
            // Only include correlations that actually had a Granger test
            if corr.grangerPValue < 1.0 {
                indexedPValues.append(IndexedPValue(index: idx, pValue: corr.grangerPValue))
            }
        }

        let totalTests = indexedPValues.count
        guard totalTests > 0 else { return }

        // Sort by p-value ascending
        indexedPValues.sort { $0.pValue < $1.pValue }

        // Find the largest rank i where p_{(i)} ≤ (i / m) * α
        var maxSurvivingRank = -1
        for (rank, ipv) in indexedPValues.enumerated() {
            let i = rank + 1 // 1-based rank
            let bhThreshold = (Double(i) / Double(m)) * alpha
            if ipv.pValue <= bhThreshold {
                maxSurvivingRank = rank
            }
        }

        // Mark all correlations: default to not surviving FDR
        for i in 0..<correlations.count {
            correlations[i].survivedFDR = false
        }

        // Mark those that survived
        if maxSurvivingRank >= 0 {
            for rank in 0...maxSurvivingRank {
                let originalIndex = indexedPValues[rank].index
                correlations[originalIndex].survivedFDR = true
            }
        }

        // Correlations without Granger tests retain survivedFDR = false
    }
}
