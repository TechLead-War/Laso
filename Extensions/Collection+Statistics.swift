import Foundation

// MARK: - Statistical Extensions

extension Array where Element == Double {
    /// Arithmetic mean
    var mean: Double {
        guard !isEmpty else { return 0 }
        var total = 0.0
        for value in self {
            total += value
        }
        return total / Double(count)
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
        let xMean = Double(count - 1) / 2.0
        let yMean = mean

        var numerator: Double = 0
        var denominator: Double = 0
        for i in 0..<count {
            let xDiff = Double(i) - xMean
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
        result.reserveCapacity(count - window + 1)

        var runningTotal = 0.0
        for index in 0..<window {
            runningTotal += self[index]
        }
        result.append(runningTotal / Double(window))

        if count == window {
            return result
        }

        for index in window..<count {
            runningTotal += self[index]
            runningTotal -= self[index - window]
            result.append(runningTotal / Double(window))
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

        var xTotal = 0.0
        var yTotal = 0.0
        for i in 0..<n {
            xTotal += x[i]
            yTotal += y[i]
        }
        let xMean = xTotal / Double(n)
        let yMean = yTotal / Double(n)

        var numerator: Double = 0
        var xDenom: Double = 0
        var yDenom: Double = 0

        for i in 0..<n {
            let xDiff = x[i] - xMean
            let yDiff = y[i] - yMean
            numerator += xDiff * yDiff
            xDenom += xDiff * xDiff
            yDenom += yDiff * yDiff
        }

        guard xDenom > 0, yDenom > 0 else { return nil }
        return numerator / (xDenom.squareRoot() * yDenom.squareRoot())
    }
}

extension Sequence {
    /// Mean over transformed values without materializing an intermediate array.
    func mean(of transform: (Element) -> Double) -> Double {
        var total = 0.0
        var count = 0

        for element in self {
            total += transform(element)
            count += 1
        }

        guard count > 0 else { return 0 }
        return total / Double(count)
    }

    /// Mean over a Double key path without materializing an intermediate array.
    func mean(of keyPath: KeyPath<Element, Double>) -> Double {
        mean { $0[keyPath: keyPath] }
    }
}
