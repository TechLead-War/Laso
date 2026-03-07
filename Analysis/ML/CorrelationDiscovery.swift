import Foundation

/// Tests ALL metric pairs (not just 35 hardcoded) using mutual information, Granger causality,
/// partial correlation, and dynamic stability tracking.
final class CorrelationDiscovery {
    /// Minimum days of paired data required
    static let minimumDays = 30

    /// Number of bins for mutual information estimation
    private static let miBins = 10
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

                // Early exit: skip weak correlations entirely
                guard abs(pearsonR) >= 0.15 else { continue }

                // 2. Mutual information
                let mi = mutualInformation(valuesA, valuesB)

                // Tiered pruning: skip expensive tests for moderate-weak correlations
                let grangerCausal: Bool
                let grangerP: Double
                var partialCorr: Double?
                var confounder: HealthMetric?
                let stability: Double

                if abs(pearsonR) >= 0.25 {
                    // 3. Granger causality (A → B)
                    (grangerCausal, grangerP) = grangerCausality(
                        cause: valuesA, effect: valuesB, maxLag: Self.maxGrangerLag
                    )

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
                    sampleCount: valuesA.count
                )

                if correlation.isSignificant {
                    correlations.append(correlation)
                }
            }
        }

        // Sort by overall strength
        correlations.sort { $0.overallStrength > $1.overallStrength }

        lastAnalysisDate = Date()
    }

    // MARK: - Mutual Information

    /// Estimate mutual information via binning
    private func mutualInformation(_ x: [Double], _ y: [Double]) -> Double {
        let n = x.count
        guard n >= Self.minimumDays else { return 0 }

        let bins = Self.miBins

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

    // MARK: - Granger Causality

    /// Test if `cause` Granger-causes `effect` using F-test
    private func grangerCausality(cause: [Double], effect: [Double], maxLag: Int) -> (causal: Bool, pValue: Double) {
        let n = effect.count
        guard n > maxLag + 2 else { return (false, 1.0) }

        // Restricted model: effect[t] = sum(a_i * effect[t-i]) for i=1..maxLag
        let restrictedSSE = autoregressiveSSE(series: effect, maxLag: maxLag)

        // Unrestricted model: effect[t] = sum(a_i * effect[t-i]) + sum(b_i * cause[t-i])
        let unrestrictedSSE = autoregressiveSSEWithExogenous(
            series: effect, exogenous: cause, maxLag: maxLag
        )

        guard restrictedSSE > 0, unrestrictedSSE > 0, unrestrictedSSE < restrictedSSE else {
            return (false, 1.0)
        }

        // F-test: F = ((SSE_r - SSE_u) / q) / (SSE_u / (n - 2*maxLag))
        let q = Double(maxLag) // additional parameters
        let dfDenom = Double(n - 2 * maxLag)
        guard dfDenom > 0 else { return (false, 1.0) }

        let fStat = ((restrictedSSE - unrestrictedSSE) / q) / (unrestrictedSSE / dfDenom)

        // Approximate p-value using F-distribution (simplified)
        let pValue = approximateFPValue(fStat: fStat, df1: Int(q), df2: Int(dfDenom))

        return (pValue < 0.05, pValue)
    }

    /// SSE from autoregressive model: y[t] = sum(a_i * y[t-i])
    private func autoregressiveSSE(series: [Double], maxLag: Int) -> Double {
        let n = series.count
        guard n > maxLag else { return 0 }

        var sse: Double = 0
        for t in maxLag..<n {
            // Simple: predict as weighted average of lagged values
            var predicted: Double = 0
            for lag in 1...maxLag {
                predicted += series[t - lag] / Double(maxLag)
            }
            let error = series[t] - predicted
            sse += error * error
        }
        return sse
    }

    /// SSE from autoregressive model with exogenous variable
    private func autoregressiveSSEWithExogenous(
        series: [Double], exogenous: [Double], maxLag: Int
    ) -> Double {
        let n = Swift.min(series.count, exogenous.count)
        guard n > maxLag else { return 0 }

        var sse: Double = 0
        for t in maxLag..<n {
            var predicted: Double = 0
            for lag in 1...maxLag {
                predicted += series[t - lag] / Double(2 * maxLag)
                predicted += exogenous[t - lag] / Double(2 * maxLag)
            }
            let error = series[t] - predicted
            sse += error * error
        }
        return sse
    }

    /// Approximate F-distribution p-value (simplified)
    private func approximateFPValue(fStat: Double, df1: Int, df2: Int) -> Double {
        // Use Abramowitz and Stegun approximation for quick p-value
        guard fStat > 0, fStat.isFinite, df1 > 0, df2 > 0 else { return 1.0 }
        let x = Double(df2) / (Double(df2) + Double(df1) * fStat)
        guard x > 0, x.isFinite else { return 1.0 }
        // Rough approximation: for large df2, F ~ chi-squared/df1
        // Use exponential approximation for quick evaluation
        let z = -0.5 * Double(df2) * log(x)
        return Swift.min(exp(-z + Double(df1) * 0.5), 1.0)
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
}
