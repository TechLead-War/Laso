import Foundation

/// Rigorous calibration methods for ML prediction confidence.
///
/// Provides Platt scaling and temperature scaling for ML components that need
/// well-calibrated probability outputs.
final class ConformalCalibrator {

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
