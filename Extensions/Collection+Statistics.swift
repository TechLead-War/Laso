import Foundation

// MARK: - Statistical Extensions

extension Array where Element == Double {
    /// Arithmetic mean
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    /// Population standard deviation
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = mean
        let sumOfSquares = reduce(0.0) { $0 + ($1 - avg) * ($1 - avg) }
        return (sumOfSquares / Double(count)).squareRoot()
    }

    /// Variance (population)
    var variance: Double {
        let sd = standardDeviation
        return sd * sd
    }

    /// Median value
    var median: Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = count / 2
        if count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }

    /// Percentile (0-100)
    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = (p / 100.0) * Double(count - 1)
        let lower = Int(index.rounded(.down))
        let upper = Int(index.rounded(.up))
        if lower == upper || upper >= count {
            return sorted[Swift.min(lower, count - 1)]
        }
        let fraction = index - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    /// Simple linear regression: returns (slope, intercept)
    /// x values are assumed to be 0, 1, 2, ... (indices)
    var linearRegression: (slope: Double, intercept: Double) {
        guard count > 1 else { return (0, first ?? 0) }
        let xs = (0..<count).map { Double($0) }
        let xMean = xs.mean
        let yMean = mean

        var numerator: Double = 0
        var denominator: Double = 0
        for i in 0..<count {
            let xDiff = xs[i] - xMean
            let yDiff = self[i] - yMean
            numerator += xDiff * yDiff
            denominator += xDiff * xDiff
        }

        guard denominator != 0 else { return (0, yMean) }
        let slope = numerator / denominator
        let intercept = yMean - slope * xMean
        return (slope, intercept)
    }

    /// Moving average with given window size
    func movingAverage(window: Int) -> [Double] {
        guard window > 0, count >= window else { return self }
        var result: [Double] = []
        for i in (window - 1)..<count {
            let windowSlice = Array(self[(i - window + 1)...i])
            result.append(windowSlice.mean)
        }
        return result
    }

    /// Exponential smoothing with given alpha (0 < alpha <= 1)
    func exponentialSmoothing(alpha: Double) -> [Double] {
        guard !isEmpty else { return [] }
        var result: [Double] = [self[0]]
        for i in 1..<count {
            let smoothed = alpha * self[i] + (1.0 - alpha) * result[i - 1]
            result.append(smoothed)
        }
        return result
    }

    /// Filter outliers beyond N standard deviations from mean
    func filterOutliers(maxDeviations: Double = 2.0) -> [Double] {
        guard count > 2 else { return self }
        let avg = mean
        let sd = standardDeviation
        guard sd > 0 else { return self }
        return filter { abs($0 - avg) <= maxDeviations * sd }
    }

    /// Pearson correlation coefficient between two equal-length arrays
    /// Returns nil if fewer than 5 paired samples or zero variance
    static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double? {
        let n = Swift.min(x.count, y.count)
        guard n >= 5 else { return nil }

        let xSlice = Array(x.prefix(n))
        let ySlice = Array(y.prefix(n))
        let xMean = xSlice.mean
        let yMean = ySlice.mean

        var numerator: Double = 0
        var xDenom: Double = 0
        var yDenom: Double = 0

        for i in 0..<n {
            let xDiff = xSlice[i] - xMean
            let yDiff = ySlice[i] - yMean
            numerator += xDiff * yDiff
            xDenom += xDiff * xDiff
            yDenom += yDiff * yDiff
        }

        guard xDenom > 0, yDenom > 0 else { return nil }
        return numerator / (xDenom.squareRoot() * yDenom.squareRoot())
    }
}
