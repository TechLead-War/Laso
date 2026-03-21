import Foundation

/// Rigorous calibration methods for ML prediction confidence.
///
/// Provides split conformal prediction intervals, Platt scaling, temperature scaling,
/// isotonic regression, ensemble disagreement analysis, and calibration diagnostics.
/// Designed to be called by `UncertaintyEstimator` and ML components that need
/// well-calibrated probability outputs.
final class ConformalCalibrator {

    // MARK: - Types

    /// A single bin in a calibration reliability diagram.
    struct CalibrationBin {
        /// Mean predicted probability in this bin
        let predictedMean: Double
        /// Observed fraction of positives in this bin
        let observedFraction: Double
        /// Number of samples in this bin
        let count: Int
        /// Absolute calibration gap: |predicted - observed|
        var gap: Double { abs(predictedMean - observedFraction) }
    }

    /// Full calibration diagnostics report.
    struct CalibrationReport {
        /// Expected Calibration Error: weighted average of per-bin gaps
        let ece: Double
        /// Maximum Calibration Error: worst-case bin gap
        let mce: Double
        /// Per-bin calibration details
        let bins: [CalibrationBin]
        /// Brier score: mean squared error of probability estimates
        let brierScore: Double
        /// Brier skill score vs climatology baseline (1.0 = perfect, 0.0 = no skill, negative = worse)
        let brierSkill: Double
        /// Reliability diagram data points: (predicted mean, observed fraction, count) per bin
        let reliabilityDiagram: [(predicted: Double, observed: Double, count: Int)]
    }

    /// A step in the isotonic regression mapping.
    struct IsotonicStep {
        let threshold: Double
        let calibrated: Double
    }

    /// Ensemble uncertainty summary.
    struct EnsembleUncertaintySummary {
        let mean: Double
        let std: Double
        let cv: Double
        let isHighUncertainty: Bool
    }

    // MARK: - Coverage Tracking State

    /// Rolling window of recent coverage hits (true = actual was within interval).
    private var coverageTracker: [Bool] = []

    /// Maximum number of recent entries to track for coverage.
    private let coverageWindowSize: Int = 100

    // MARK: - Split Conformal Prediction

    /// Compute a conformal prediction interval using split conformal prediction.
    ///
    /// Given calibration residuals (|actual - predicted|) from a held-out set, computes
    /// a symmetric interval around the point prediction with finite-sample coverage guarantee.
    ///
    /// - Parameters:
    ///   - calibrationResiduals: Absolute residuals |actual - predicted| from calibration data.
    ///   - pointPrediction: The model's point prediction for a new input.
    ///   - coverage: Desired coverage probability (e.g., 0.90). Clamped to [0.5, 0.99].
    /// - Returns: Tuple of (lower bound, upper bound, actual recent coverage fraction).
    func conformalPredictionInterval(
        calibrationResiduals: [Double],
        pointPrediction: Double,
        coverage: Double = 0.90
    ) -> (lower: Double, upper: Double, actualCoverage: Double) {
        let clampedCoverage = Swift.max(0.5, Swift.min(coverage, 0.99))

        guard !calibrationResiduals.isEmpty else {
            return (pointPrediction, pointPrediction, recentCoverage())
        }

        // Sort absolute residuals ascending
        let sorted = calibrationResiduals.map { abs($0) }.sorted()
        let n = sorted.count

        // Finite sample correction: quantile index = ceil((n+1) * coverage)
        let quantileRawIndex = Int(ceil(Double(n + 1) * clampedCoverage))

        let quantileRadius: Double
        if quantileRawIndex > n {
            // Extrapolation guard: beyond available data, use max * 1.1
            quantileRadius = sorted[n - 1] * 1.1
        } else {
            // 1-indexed to 0-indexed: subtract 1, clamp to valid range
            let safeIndex = Swift.max(0, Swift.min(quantileRawIndex - 1, n - 1))
            quantileRadius = sorted[safeIndex]
        }

        let lower = pointPrediction - quantileRadius
        let upper = pointPrediction + quantileRadius
        let actualCov = recentCoverage()

        return (lower: lower, upper: upper, actualCoverage: actualCov)
    }

    // MARK: - Platt Scaling

    /// Fit Platt scaling parameters (a, b) for a binary classifier via Newton-Raphson.
    ///
    /// Fits the logistic model P(y=1|s) = 1/(1 + exp(a*s + b)) to minimize negative
    /// log-likelihood with label smoothing for numerical stability.
    ///
    /// - Parameters:
    ///   - rawScores: Raw model scores (e.g., decision function outputs or log-odds).
    ///   - labels: Binary labels (0 or 1) corresponding to each score.
    /// - Returns: Fitted parameters (a, b), or nil if fitting fails.
    func plattScale(rawScores: [Double], labels: [Double]) -> (a: Double, b: Double)? {
        let n = rawScores.count
        guard n == labels.count, n >= 5 else { return nil }

        // Count positives and negatives for label smoothing
        let nPositive = labels.reduce(0.0) { $0 + $1 }
        let nNegative = Double(n) - nPositive
        guard nPositive > 0, nNegative > 0 else { return nil }

        // Smoothed targets (Platt's original label smoothing)
        // t_i = (N_+ + 1) / (N_+ + 2) if y_i = 1, else 1 / (N_- + 2)
        let tPositive = (nPositive + 1.0) / (nPositive + 2.0)
        let tNegative = 1.0 / (nNegative + 2.0)
        let targets = labels.map { $0 > 0.5 ? tPositive : tNegative }

        // Newton-Raphson optimization
        var a = 0.0
        var b = 0.0
        let maxIterations = 10
        let convergenceThreshold = 1e-8

        for _ in 0..<maxIterations {
            // Compute probabilities p_i = 1 / (1 + exp(a*s_i + b))
            // Gradient and Hessian for negative log-likelihood:
            // NLL = sum(-t_i * log(p_i) - (1 - t_i) * log(1 - p_i))
            // d(NLL)/da = sum((p_i - t_i) * s_i)
            // d(NLL)/db = sum(p_i - t_i)
            // d2(NLL)/da2 = sum(p_i * (1 - p_i) * s_i^2)
            // d2(NLL)/dadb = sum(p_i * (1 - p_i) * s_i)
            // d2(NLL)/db2 = sum(p_i * (1 - p_i))

            var gradA = 0.0
            var gradB = 0.0
            var hessAA = 0.0
            var hessAB = 0.0
            var hessBB = 0.0

            for i in 0..<n {
                let logit = a * rawScores[i] + b
                // Numerically stable sigmoid
                let p = stableSigmoid(logit)
                let diff = p - targets[i]
                let pq = p * (1.0 - p) + 1e-12 // Regularize to avoid zero

                gradA += diff * rawScores[i]
                gradB += diff
                hessAA += pq * rawScores[i] * rawScores[i]
                hessAB += pq * rawScores[i]
                hessBB += pq
            }

            // Solve 2x2 system via Cramer's rule:
            // [hessAA  hessAB] [da]   [-gradA]
            // [hessAB  hessBB] [db] = [-gradB]
            let det = hessAA * hessBB - hessAB * hessAB
            guard abs(det) > 1e-15 else { break } // Singular Hessian

            let da = -(hessBB * gradA - hessAB * gradB) / det
            let db = -(hessAA * gradB - hessAB * gradA) / det

            a += da
            b += db

            // Check convergence
            if abs(da) < convergenceThreshold && abs(db) < convergenceThreshold {
                break
            }
        }

        return (a: a, b: b)
    }

    /// Apply Platt scaling to a raw score using fitted parameters.
    ///
    /// Returns calibrated probability P(y=1|s) = 1/(1 + exp(a*s + b)).
    func calibrate(rawScore: Double, a: Double, b: Double) -> Double {
        let logit = a * rawScore + b
        return stableSigmoid(logit)
    }

    // MARK: - Temperature Scaling

    /// Fit temperature scaling parameter T that minimizes negative log-likelihood
    /// on a calibration set.
    ///
    /// For binary classification: P = sigmoid(logit / T).
    /// Uses grid search over T in {0.1, 0.2, ..., 5.0} for robustness.
    ///
    /// - Parameters:
    ///   - logits: Raw logits (pre-sigmoid) from the model.
    ///   - labels: Binary labels (0 or 1) corresponding to each logit.
    /// - Returns: Optimal temperature T, or 1.0 if fitting fails.
    func temperatureScale(logits: [Double], labels: [Double]) -> Double {
        let n = logits.count
        guard n == labels.count, n >= 5 else { return 1.0 }

        var bestT = 1.0
        var bestNLL = Double.infinity

        // Grid search: T in {0.1, 0.2, ..., 5.0}. 50 candidates
        for step in 1...50 {
            let t = Double(step) * 0.1
            var nll = 0.0

            for i in 0..<n {
                let scaledLogit = logits[i] / t
                let p = stableSigmoid(scaledLogit)
                // Cross-entropy: -[y * log(p) + (1-y) * log(1-p)]
                let clampedP = Swift.max(1e-15, Swift.min(1.0 - 1e-15, p))
                if labels[i] > 0.5 {
                    nll -= log(clampedP)
                } else {
                    nll -= log(1.0 - clampedP)
                }
            }

            if nll < bestNLL {
                bestNLL = nll
                bestT = t
            }
        }

        return bestT
    }

    /// Apply temperature scaling to a logit.
    ///
    /// Returns calibrated probability P = sigmoid(logit / T).
    func calibrateWithTemperature(logit: Double, T: Double) -> Double {
        let safeT = Swift.max(T, 1e-6) // Avoid division by zero
        return stableSigmoid(logit / safeT)
    }

    // MARK: - Isotonic Regression (Pool Adjacent Violators)

    /// Fit isotonic regression using the Pool Adjacent Violators (PAV) algorithm.
    ///
    /// Produces a monotone non-decreasing step function mapping raw predicted
    /// probabilities to calibrated probabilities.
    ///
    /// - Parameters:
    ///   - predictions: Raw predicted probabilities from the model.
    ///   - labels: Binary labels (0 or 1) corresponding to each prediction.
    /// - Returns: Sorted step function mapping, or empty array if input is insufficient.
    func isotonicCalibrate(
        predictions: [Double],
        labels: [Double]
    ) -> [IsotonicStep] {
        let n = predictions.count
        guard n == labels.count, n >= 2 else { return [] }

        // Sort by predicted probability ascending
        let indices = (0..<n).sorted { predictions[$0] < predictions[$1] }
        var sortedPreds = indices.map { predictions[$0] }
        var sortedLabels = indices.map { labels[$0] }

        // PAV: pool adjacent violators to ensure monotone non-decreasing calibrated values
        // Use weighted pooling: each block tracks (sum of labels, count)
        var blockSums = sortedLabels     // Running sums of labels within each block
        var blockCounts = [Double](repeating: 1.0, count: n)
        var blockPreds = sortedPreds     // Representative prediction for each block

        // Track which blocks are active (not yet merged)
        var blockValues = (0..<n).map { i -> (predSum: Double, labelSum: Double, count: Double) in
            (predSum: sortedPreds[i], labelSum: sortedLabels[i], count: 1.0)
        }

        // Iterative PAV: merge adjacent blocks where calibrated value decreases
        var changed = true
        while changed {
            changed = false
            var merged: [(predSum: Double, labelSum: Double, count: Double)] = []

            for block in blockValues {
                if let last = merged.last {
                    let lastCalibrated = last.labelSum / last.count
                    let currentCalibrated = block.labelSum / block.count
                    if currentCalibrated < lastCalibrated {
                        // Violation: pool with previous block
                        let pooled = (
                            predSum: last.predSum + block.predSum,
                            labelSum: last.labelSum + block.labelSum,
                            count: last.count + block.count
                        )
                        merged[merged.count - 1] = pooled
                        changed = true
                        continue
                    }
                }
                merged.append(block)
            }
            blockValues = merged
        }

        // Build step function: each block maps its mean prediction to its calibrated value
        var steps: [IsotonicStep] = []
        steps.reserveCapacity(blockValues.count)

        for block in blockValues {
            let threshold = block.predSum / block.count
            let calibrated = block.labelSum / block.count
            steps.append(IsotonicStep(
                threshold: threshold,
                calibrated: Swift.max(0, Swift.min(1.0, calibrated))
            ))
        }

        return steps
    }

    /// Apply isotonic calibration using linear interpolation between step function points.
    ///
    /// - Parameters:
    ///   - rawProbability: The raw predicted probability to calibrate.
    ///   - mapping: The isotonic step function from `isotonicCalibrate`.
    /// - Returns: Calibrated probability in [0, 1].
    func applyIsotonic(rawProbability: Double, mapping: [IsotonicStep]) -> Double {
        guard !mapping.isEmpty else { return rawProbability }

        // Clamp to [0, 1]
        let p = Swift.max(0, Swift.min(1.0, rawProbability))

        // Edge cases: below or above all thresholds
        if mapping.count == 1 {
            return mapping[0].calibrated
        }

        if p <= mapping[0].threshold {
            return mapping[0].calibrated
        }

        if p >= mapping[mapping.count - 1].threshold {
            return mapping[mapping.count - 1].calibrated
        }

        // Find surrounding steps and linearly interpolate
        for i in 0..<(mapping.count - 1) {
            let lower = mapping[i]
            let upper = mapping[i + 1]

            if p >= lower.threshold && p <= upper.threshold {
                let range = upper.threshold - lower.threshold
                if range < 1e-15 {
                    // Steps at same threshold: average
                    return (lower.calibrated + upper.calibrated) / 2.0
                }
                let t = (p - lower.threshold) / range
                return lower.calibrated + t * (upper.calibrated - lower.calibrated)
            }
        }

        // Fallback (should not reach here)
        return mapping[mapping.count - 1].calibrated
    }

    // MARK: - Ensemble Disagreement

    /// Compute ensemble uncertainty from multiple model predictions.
    ///
    /// - Parameters:
    ///   - predictions: Predictions from N model variants (at least 2).
    /// - Returns: Summary with mean, std, coefficient of variation, and high-uncertainty flag.
    ///   Returns nil if fewer than 2 predictions provided.
    func ensembleUncertainty(
        predictions: [Double]
    ) -> EnsembleUncertaintySummary? {
        guard predictions.count >= 2 else { return nil }

        let mean = AccelerateML.mean(predictions)
        let (_, variance) = AccelerateML.welfordVariance(predictions)
        let std = variance.squareRoot()

        let cv: Double
        if abs(mean) > 1e-9 {
            cv = std / abs(mean)
        } else {
            cv = std > 1e-9 ? 1.0 : 0.0
        }

        // High uncertainty if CV > 0.3 or std > 0.15 (probability-scale outputs)
        let isHigh = cv > 0.3 || std > 0.15

        return EnsembleUncertaintySummary(
            mean: mean,
            std: std,
            cv: cv,
            isHighUncertainty: isHigh
        )
    }

    // MARK: - Calibration Diagnostics

    /// Compute comprehensive calibration diagnostics for a set of predictions.
    ///
    /// Bins predictions by predicted probability, computes ECE, MCE, Brier score,
    /// Brier skill score, and reliability diagram data.
    ///
    /// - Parameters:
    ///   - predictions: Predicted probabilities in [0, 1].
    ///   - labels: Binary labels (0 or 1) corresponding to each prediction.
    ///   - bins: Number of equal-width bins for calibration analysis. Default 10.
    /// - Returns: A `CalibrationReport`, or nil if input is insufficient.
    func calibrationDiagnostics(
        predictions: [Double],
        labels: [Double],
        bins: Int = 10
    ) -> CalibrationReport? {
        let n = predictions.count
        guard n == labels.count, n >= 10, bins >= 2 else { return nil }

        // Build equal-width bins
        let binWidth = 1.0 / Double(bins)
        var calBins: [CalibrationBin] = []
        calBins.reserveCapacity(bins)

        var totalECE = 0.0
        var maxCE = 0.0

        for b in 0..<bins {
            let binLower = Double(b) * binWidth
            let binUpper = Double(b + 1) * binWidth

            var predSum = 0.0
            var labelSum = 0.0
            var count = 0

            for i in 0..<n {
                let inBin: Bool
                if b == bins - 1 {
                    // Last bin includes upper bound
                    inBin = predictions[i] >= binLower && predictions[i] <= binUpper
                } else {
                    inBin = predictions[i] >= binLower && predictions[i] < binUpper
                }

                if inBin {
                    predSum += predictions[i]
                    labelSum += labels[i]
                    count += 1
                }
            }

            let predMean = count > 0 ? predSum / Double(count) : (binLower + binUpper) / 2.0
            let obsFraction = count > 0 ? labelSum / Double(count) : 0.0

            let bin = CalibrationBin(
                predictedMean: predMean,
                observedFraction: obsFraction,
                count: count
            )
            calBins.append(bin)

            if count > 0 {
                let weightedGap = (Double(count) / Double(n)) * bin.gap
                totalECE += weightedGap
                maxCE = Swift.max(maxCE, bin.gap)
            }
        }

        // Brier score: (1/N) * sum((p_i - y_i)^2)
        var brierSum = 0.0
        var labelMean = 0.0
        for i in 0..<n {
            let diff = predictions[i] - labels[i]
            brierSum += diff * diff
            labelMean += labels[i]
        }
        let brierScore = brierSum / Double(n)
        labelMean /= Double(n)

        // Climatology (no-skill) Brier score: p_bar * (1 - p_bar)
        let brierClimatology = labelMean * (1.0 - labelMean)

        // Brier skill score: 1 - Brier / Climatology
        let brierSkill: Double
        if brierClimatology > 1e-12 {
            brierSkill = 1.0 - brierScore / brierClimatology
        } else {
            // All labels are the same class: climatology is 0, skill is undefined
            brierSkill = brierScore < 1e-12 ? 1.0 : 0.0
        }

        // Reliability diagram data (only non-empty bins)
        let reliabilityDiagram = calBins
            .filter { $0.count > 0 }
            .map { (predicted: $0.predictedMean, observed: $0.observedFraction, count: $0.count) }

        return CalibrationReport(
            ece: totalECE,
            mce: maxCE,
            bins: calBins,
            brierScore: brierScore,
            brierSkill: brierSkill,
            reliabilityDiagram: reliabilityDiagram
        )
    }

    // MARK: - Coverage Tracking

    /// Update coverage tracking with a new prediction-actual pair.
    ///
    /// Records whether the actual value fell within the predicted interval.
    /// Maintains a rolling window of the most recent entries.
    ///
    /// - Parameters:
    ///   - predicted: The point prediction.
    ///   - actual: The realized actual value.
    ///   - interval: The prediction interval (lower, upper).
    func updateCoverage(predicted: Double, actual: Double, interval: (lower: Double, upper: Double)) {
        let covered = actual >= interval.lower && actual <= interval.upper
        coverageTracker.append(covered)

        // Trim to rolling window
        if coverageTracker.count > coverageWindowSize {
            coverageTracker.removeFirst(coverageTracker.count - coverageWindowSize)
        }
    }

    /// Compute recent empirical coverage rate from the rolling window.
    ///
    /// - Parameter window: Number of most recent entries to consider. Defaults to all tracked entries.
    /// - Returns: Fraction of recent predictions where actual fell within the interval.
    ///   Returns 1.0 if no coverage data has been recorded yet.
    func recentCoverage(window: Int? = nil) -> Double {
        guard !coverageTracker.isEmpty else { return 1.0 }

        let windowSize = window ?? coverageTracker.count
        let effectiveWindow = Swift.min(windowSize, coverageTracker.count)
        guard effectiveWindow > 0 else { return 1.0 }

        let recentEntries = coverageTracker.suffix(effectiveWindow)
        let coveredCount = recentEntries.filter { $0 }.count
        return Double(coveredCount) / Double(recentEntries.count)
    }

    /// Check whether coverage has dropped below an acceptable threshold.
    ///
    /// Alerts if empirical coverage falls more than 10 percentage points below nominal.
    /// For example, at 90% nominal coverage, alerts if actual coverage < 80%.
    ///
    /// - Parameter nominalCoverage: The target coverage level (e.g., 0.90).
    /// - Returns: True if coverage is critically low and requires recalibration.
    func isCoverageCriticallyLow(nominalCoverage: Double = 0.90) -> Bool {
        let actual = recentCoverage()
        let threshold = nominalCoverage - 0.10
        // Only alert if we have enough data to be meaningful (at least 20 entries)
        return coverageTracker.count >= 20 && actual < threshold
    }

    /// Reset coverage tracking state.
    func resetCoverageTracker() {
        coverageTracker.removeAll()
    }

    // MARK: - Private Helpers

    /// Numerically stable sigmoid: 1 / (1 + exp(-x)).
    ///
    /// For large positive x, returns ~1.0 without overflow.
    /// For large negative x, returns ~0.0 without underflow.
    private func stableSigmoid(_ x: Double) -> Double {
        if x >= 0 {
            let expNeg = exp(-x)
            return 1.0 / (1.0 + expNeg)
        } else {
            let expPos = exp(x)
            return expPos / (1.0 + expPos)
        }
    }
}
