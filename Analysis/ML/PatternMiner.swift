import Foundation

/// Discovers periodic patterns in health data using autocorrelation and FFT frequency decomposition.
/// Finds cycles the user didn't know about: 7-day, 14-day, 28-day, seasonal.
final class PatternMiner {
    /// Minimum days of data required
    static let minimumDays = 60

    /// Standard lags to check for periodicity
    private static let standardLags = [7, 14, 28]

    /// Discovered patterns
    private(set) var patterns: [DiscoveredPattern] = []

    // MARK: - Mining

    /// Per-metric weekday statistics (day-of-week -> mean value)
    private(set) var weekdayMeans: [HealthMetric: [Int: Double]] = [:]

    /// Discover periodic patterns across all metrics
    func mine(timeSeries: [HealthMetric: MetricTimeSeries]) {
        patterns = []
        weekdayMeans = [:]

        let calendar = Calendar.current
        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }

            // Compute day-of-week means for weekly pattern enrichment
            var dayBuckets: [Int: [Double]] = [:]
            for sample in series.sortedSamples {
                let weekday = calendar.component(.weekday, from: sample.date)
                dayBuckets[weekday, default: []].append(sample.value)
            }
            var means: [Int: Double] = [:]
            for (day, vals) in dayBuckets where vals.count >= 4 {
                means[day] = vals.reduce(0, +) / Double(vals.count)
            }
            weekdayMeans[metric] = means

            // Detrend: remove linear trend to isolate cyclical components
            let detrended = detrend(values)

            // Method 1: Autocorrelation at standard lags
            let autoPatterns = findAutocorrelationPatterns(
                metric: metric, values: detrended, totalCount: values.count,
                weekdayMeans: means
            )
            patterns.append(contentsOf: autoPatterns)

            // Method 2: FFT frequency decomposition
            let fftPatterns = findFFTPatterns(metric: metric, values: detrended)
            patterns.append(contentsOf: fftPatterns)
        }

        // Deduplicate: keep strongest pattern per metric+period
        patterns = deduplicatePatterns(patterns)
    }

    // MARK: - Autocorrelation Analysis

    private func findAutocorrelationPatterns(
        metric: HealthMetric,
        values: [Double],
        totalCount: Int,
        weekdayMeans: [Int: Double]
    ) -> [DiscoveredPattern] {
        var results: [DiscoveredPattern] = []
        // Bartlett's formula for autocorrelation SE under white noise null: 1/sqrt(n)
        // Apply Bonferroni correction for testing 3 lags: divide α by 3 → z = 2.39 (99.2% CI)
        // Bonferroni: z_crit for α/(2*numTests) where α=0.05, numTests=3
        let bonferroniZ = 2.39 // z for 0.05/6 ≈ 0.0083 one-tailed
        let significanceThreshold = bonferroniZ / Double(totalCount).squareRoot()

        for lag in Self.standardLags {
            guard lag < values.count / 2 else { continue }

            let r = AccelerateML.autocorrelation(values, lag: lag)

            guard abs(r) > significanceThreshold else { continue }

            let patternType = classifyPeriod(lag)

            // Compute peak/trough for weekly patterns
            var peakDay: Int?
            var troughDay: Int?
            var peakMean: Double?
            var troughMean: Double?

            if patternType == .weekly && weekdayMeans.count >= 5 {
                let higherIsBetter = metric.higherIsBetter
                if let best = weekdayMeans.max(by: { a, b in
                    higherIsBetter ? a.value < b.value : a.value > b.value
                }) {
                    peakDay = best.key
                    peakMean = best.value
                }
                if let worst = weekdayMeans.min(by: { a, b in
                    higherIsBetter ? a.value < b.value : a.value > b.value
                }) {
                    troughDay = worst.key
                    troughMean = worst.value
                }
            }

            let description = describePattern(
                metric: metric, lag: lag, strength: r,
                peakDayName: peakDay.flatMap { DiscoveredPattern.dayName($0) },
                troughDayName: troughDay.flatMap { DiscoveredPattern.dayName($0) }
            )

            results.append(DiscoveredPattern(
                metric: metric,
                patternType: patternType,
                periodDays: Double(lag),
                strength: abs(r),
                description: description,
                discoveredAt: Date(),
                peakDayOfWeek: peakDay,
                troughDayOfWeek: troughDay,
                peakMeanValue: peakMean,
                troughMeanValue: troughMean
            ))
        }

        return results
    }

    // MARK: - FFT Analysis

    private func findFFTPatterns(
        metric: HealthMetric,
        values: [Double]
    ) -> [DiscoveredPattern] {
        let magnitudes = AccelerateML.fftMagnitude(values)
        guard magnitudes.count > 2 else { return [] }

        var results: [DiscoveredPattern] = []

        // Find the N/2 power-of-2 length used by FFT
        let log2n = Int(floor(log2(Double(values.count))))
        let fftLength = 1 << log2n

        // Compute mean magnitude for significance testing (skip DC component at index 0)
        let nonDC = Array(magnitudes.dropFirst())
        guard !nonDC.isEmpty else { return [] }
        let meanMag = nonDC.mean
        let sdMag = nonDC.standardDeviation
        guard sdMag > 0 else { return [] }

        // Find peaks that are significantly above background
        let threshold = meanMag + 2.0 * sdMag

        for i in 1..<magnitudes.count {
            guard magnitudes[i] > threshold else { continue }

            // Convert frequency bin to period in days
            let frequency = Double(i) / Double(fftLength)
            let periodDays = 1.0 / frequency

            // Only report meaningful periods (3 days to half the data length)
            guard periodDays >= 3, periodDays <= Double(values.count) / 2 else { continue }

            // Normalize strength relative to max magnitude
            let strength = magnitudes[i] / (magnitudes.max() ?? 1.0)
            guard strength > 0.3 else { continue } // At least 30% of peak

            let patternType = classifyPeriod(Int(periodDays.rounded()))

            // Check if this is close to a standard period
            let nearestStandard = Self.standardLags.min { abs($0 - Int(periodDays.rounded())) < abs($1 - Int(periodDays.rounded())) }
            let isNearStandard = nearestStandard.map { abs(Double($0) - periodDays) < 2.0 } ?? false

            let description: String
            if isNearStandard {
                description = describePattern(metric: metric, lag: Int(periodDays.rounded()), strength: strength)
            } else {
                description = "\(metric.displayName) shows a \(String(format: "%.0f", periodDays))-day cycle (FFT strength: \(String(format: "%.0f", strength * 100))%)"
            }

            results.append(DiscoveredPattern(
                metric: metric,
                patternType: patternType,
                periodDays: periodDays,
                strength: strength,
                description: description,
                discoveredAt: Date(),
                peakDayOfWeek: nil,
                troughDayOfWeek: nil,
                peakMeanValue: nil,
                troughMeanValue: nil
            ))
        }

        return results
    }

    // MARK: - Helpers

    /// Remove linear trend from time series
    private func detrend(_ values: [Double]) -> [Double] {
        let reg = values.linearRegression
        return values.enumerated().map { i, v in
            v - (reg.slope * Double(i) + reg.intercept)
        }
    }

    private func classifyPeriod(_ days: Int) -> DiscoveredPattern.PatternType {
        switch days {
        case 6...8: return .weekly
        case 13...15: return .biweekly
        case 26...32: return .monthly
        case 80...100: return .seasonal
        default: return .custom
        }
    }

    private func describePattern(
        metric: HealthMetric,
        lag: Int,
        strength: Double,
        peakDayName: String? = nil,
        troughDayName: String? = nil
    ) -> String {
        let strengthLabel: String
        switch strength {
        case 0.7...: strengthLabel = "strong"
        case 0.4..<0.7: strengthLabel = "moderate"
        default: strengthLabel = "mild"
        }

        let periodLabel: String
        switch lag {
        case 6...8: periodLabel = "weekly"
        case 13...15: periodLabel = "biweekly"
        case 26...32: periodLabel = "monthly"
        case 80...100: periodLabel = "seasonal (~quarterly)"
        default: periodLabel = "\(lag)-day"
        }

        if lag == 7, let peak = peakDayName, let trough = troughDayName {
            return "Your \(metric.displayName) follows a \(strengthLabel) \(periodLabel) cycle. peaks on \(peak)s, dips on \(trough)s"
        }

        return "Your \(metric.displayName) shows a \(strengthLabel) \(periodLabel) pattern (r=\(String(format: "%.2f", strength)))"
    }

    /// Deduplicate patterns: keep strongest per metric + approximate period
    private func deduplicatePatterns(_ patterns: [DiscoveredPattern]) -> [DiscoveredPattern] {
        var best: [String: DiscoveredPattern] = [:]

        for pattern in patterns {
            // Group by metric + period bucket (within 3 days)
            let periodBucket = Int(pattern.periodDays / 3.0) * 3
            let key = "\(pattern.metric.rawValue)_\(periodBucket)"

            if let existing = best[key] {
                if pattern.strength > existing.strength {
                    best[key] = pattern
                }
            } else {
                best[key] = pattern
            }
        }

        return Array(best.values).sorted { $0.strength > $1.strength }
    }

    // MARK: - State

    var isReady: Bool { !patterns.isEmpty }

    /// Get patterns for a specific metric
    func patterns(for metric: HealthMetric) -> [DiscoveredPattern] {
        patterns.filter { $0.metric == metric }
    }

    /// Get the strongest patterns across all metrics
    func topPatterns(_ count: Int = 5) -> [DiscoveredPattern] {
        Array(patterns.prefix(count))
    }
}
