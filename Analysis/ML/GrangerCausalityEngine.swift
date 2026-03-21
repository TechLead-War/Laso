import Foundation
import Accelerate

/// Proper Granger causality testing engine with OLS regression, F-distribution p-values
/// via regularized incomplete beta function, BIC-based lag selection, and stationarity checking.
///
/// **Mathematical basis:**
/// Granger causality tests whether past values of series X improve prediction of series Y
/// beyond what past values of Y alone can achieve. This is formalized as:
///
///   Restricted model (AR only):  y(t) = a0 + a1*y(t-1) + ... + ap*y(t-p) + e(t)
///   Unrestricted model (VAR):    y(t) = a0 + a1*y(t-1) + ... + ap*y(t-p) + b1*x(t-1) + ... + bp*x(t-p) + u(t)
///
/// The F-statistic tests H0: b1 = b2 = ... = bp = 0 (X does not Granger-cause Y).
///
///   F = ((SSE_r - SSE_u) / q) / (SSE_u / (n - k_u))
///
/// where q = p (number of restrictions), k_u = 2p + 1 (unrestricted model parameters), n = observations.
struct GrangerCausalityEngine {

    // MARK: - Result Types

    /// Complete result from a Granger causality test
    struct GrangerResult {
        /// The putative causal metric
        let cause: HealthMetric
        /// The putative effect metric
        let effect: HealthMetric
        /// F-statistic from the Granger test
        let fStatistic: Double
        /// p-value from the F-distribution
        let pValue: Double
        /// Optimal lag order selected by BIC
        let optimalLag: Int
        /// Whether the test is significant at the given significance level
        let isCausal: Bool
        /// Sum of squared errors from the restricted (AR-only) model
        let sseRestricted: Double
        /// Sum of squared errors from the unrestricted (AR + exogenous) model
        let sseUnrestricted: Double
        /// Number of observations used in the regression
        let nObservations: Int
        /// Whether the input series were first-differenced for stationarity
        let wasFirstDifferenced: Bool
        /// Cohen's f² effect size: (R²_unrestricted - R²_restricted) / (1 - R²_unrestricted)
        let effectSize: Double
        /// The optimal lag in days (same as optimalLag, explicit for clarity)
        let optimalLagDays: Int
        /// Directionality description: "A → B", "B → A", or "bidirectional"
        let directionality: String
    }

    /// Report from rolling stability analysis of a Granger causal relationship
    struct StabilityReport {
        /// Results for each sliding window
        let windowResults: [(startDate: Date, pValue: Double, fStat: Double, isCausal: Bool)]
        /// Fraction of windows where the causal relationship is significant
        let stabilityScore: Double
        /// Coefficient of variation of F-statistics across windows
        let effectSizeVariation: Double
        /// Whether the relationship is stable (stabilityScore > 0.6)
        let isStable: Bool
    }

    // MARK: - Public API

    /// Test whether `cause` Granger-causes `effect`.
    ///
    /// Uses BIC to select the optimal lag order from 1..maxLag, then runs an F-test
    /// comparing the restricted (AR-only) model against the unrestricted (AR + exogenous) model.
    ///
    /// - Parameters:
    ///   - cause: Time series of the putative cause variable (ordered chronologically)
    ///   - effect: Time series of the putative effect variable (ordered chronologically, same length)
    ///   - causeMetric: HealthMetric identifier for the cause series
    ///   - effectMetric: HealthMetric identifier for the effect series
    ///   - maxLag: Maximum lag order to consider (default 5)
    ///   - significanceLevel: Threshold for significance (default 0.05)
    /// - Returns: A GrangerResult, or nil if insufficient data or degenerate input
    static func test(
        cause: [Double],
        effect: [Double],
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        maxLag: Int = 5,
        significanceLevel: Double = 0.05
    ) -> GrangerResult? {
        let minObservations = 2 * maxLag + 10
        guard cause.count == effect.count,
              cause.count >= minObservations else { return nil }

        // Guard against zero-variance (constant) series
        guard hasVariance(cause), hasVariance(effect) else { return nil }

        // Stationarity check via simplified ADF: if AR(1) coefficient >= 1, first-difference
        var workCause = cause
        var workEffect = effect
        var wasFirstDifferenced = false

        if !isStationary(workCause) || !isStationary(workEffect) {
            workCause = firstDifference(workCause)
            workEffect = firstDifference(workEffect)
            wasFirstDifferenced = true

            // After differencing we lose one observation; re-check minimum
            guard workCause.count >= minObservations,
                  hasVariance(workCause), hasVariance(workEffect) else { return nil }
        }

        // Select optimal lag via BIC
        let optimalLag = selectOptimalLag(
            cause: workCause, effect: workEffect, maxLag: maxLag
        )

        // Fit restricted model: y(t) = intercept + sum_{i=1}^{p} a_i * y(t-i)
        let n = workEffect.count - optimalLag // usable observations
        guard n > 2 * optimalLag + 1 else { return nil }

        let restrictedDesign = buildRestrictedDesignMatrix(effect: workEffect, lag: optimalLag)
        let unrestrictedDesign = buildUnrestrictedDesignMatrix(
            cause: workCause, effect: workEffect, lag: optimalLag
        )

        // Dependent variable: y(t) for t = lag..end
        let y = Array(workEffect[optimalLag...])

        guard let restrictedSSE = fitOLSAndComputeSSE(designMatrix: restrictedDesign, y: y, nRows: n),
              let unrestrictedSSE = fitOLSAndComputeSSE(designMatrix: unrestrictedDesign, y: y, nRows: n) else {
            return nil
        }

        // Guard: unrestricted SSE should not exceed restricted SSE (unless numerical noise)
        guard restrictedSSE > 0, unrestrictedSSE > 0 else { return nil }

        // F-statistic: F = ((SSE_r - SSE_u) / q) / (SSE_u / (n - k_u))
        let q = Double(optimalLag) // number of restrictions = number of exogenous lag terms
        let kUnrestricted = 2 * optimalLag + 1 // AR lags + exogenous lags + intercept
        let dfDenominator = Double(n) - Double(kUnrestricted)

        guard dfDenominator > 0 else { return nil }

        // If unrestricted SSE >= restricted SSE (exogenous lags don't help), F <= 0
        let sseDiff = restrictedSSE - unrestrictedSSE
        let fStatistic: Double
        if sseDiff <= 0 {
            fStatistic = 0
        } else {
            fStatistic = (sseDiff / q) / (unrestrictedSSE / dfDenominator)
        }

        // p-value from F-distribution using regularized incomplete beta function
        let pValue = fDistributionSurvival(f: fStatistic, df1: Int(q), df2: Int(dfDenominator))

        // Compute R² for restricted and unrestricted models for effect size
        let yMean = y.reduce(0, +) / Double(n)
        let sst = y.reduce(0.0) { $0 + ($1 - yMean) * ($1 - yMean) }
        let rSquaredRestricted = sst > 0 ? 1.0 - restrictedSSE / sst : 0
        let rSquaredUnrestricted = sst > 0 ? 1.0 - unrestrictedSSE / sst : 0

        // Cohen's f² = (R²_unrestricted - R²_restricted) / (1 - R²_unrestricted)
        let cohensF2: Double
        if rSquaredUnrestricted < 1.0 && rSquaredUnrestricted > rSquaredRestricted {
            cohensF2 = (rSquaredUnrestricted - rSquaredRestricted) / (1.0 - rSquaredUnrestricted)
        } else {
            cohensF2 = 0
        }

        return GrangerResult(
            cause: causeMetric,
            effect: effectMetric,
            fStatistic: fStatistic,
            pValue: pValue,
            optimalLag: optimalLag,
            isCausal: pValue < significanceLevel,
            sseRestricted: restrictedSSE,
            sseUnrestricted: unrestrictedSSE,
            nObservations: n,
            wasFirstDifferenced: wasFirstDifferenced,
            effectSize: cohensF2,
            optimalLagDays: optimalLag,
            directionality: "\(causeMetric.rawValue) → \(effectMetric.rawValue)"
        )
    }

    /// Test Granger causality in both directions: A->B and B->A.
    ///
    /// Results include a `directionality` field reflecting the bidirectional outcome:
    /// - "A → B" if only A Granger-causes B
    /// - "B → A" if only B Granger-causes A
    /// - "bidirectional" if both directions are significant
    /// - Original single-direction string if only one direction was tested
    ///
    /// - Parameters:
    ///   - seriesA: Time series A (ordered chronologically)
    ///   - seriesB: Time series B (ordered chronologically, same length as A)
    ///   - metricA: HealthMetric identifier for series A
    ///   - metricB: HealthMetric identifier for series B
    ///   - maxLag: Maximum lag order to consider (default 5)
    /// - Returns: A tuple of optional results for each causal direction
    static func testBidirectional(
        seriesA: [Double],
        seriesB: [Double],
        metricA: HealthMetric,
        metricB: HealthMetric,
        maxLag: Int = 5
    ) -> (aToB: GrangerResult?, bToA: GrangerResult?) {
        var aToB = test(
            cause: seriesA, effect: seriesB,
            causeMetric: metricA, effectMetric: metricB,
            maxLag: maxLag
        )
        var bToA = test(
            cause: seriesB, effect: seriesA,
            causeMetric: metricB, effectMetric: metricA,
            maxLag: maxLag
        )

        // Update directionality based on bidirectional results
        let aCausesB = aToB?.isCausal ?? false
        let bCausesA = bToA?.isCausal ?? false
        let direction: String
        if aCausesB && bCausesA {
            direction = "bidirectional"
        } else if aCausesB {
            direction = "\(metricA.rawValue) → \(metricB.rawValue)"
        } else if bCausesA {
            direction = "\(metricB.rawValue) → \(metricA.rawValue)"
        } else {
            direction = "none"
        }

        if let result = aToB {
            aToB = GrangerResult(
                cause: result.cause, effect: result.effect,
                fStatistic: result.fStatistic, pValue: result.pValue,
                optimalLag: result.optimalLag, isCausal: result.isCausal,
                sseRestricted: result.sseRestricted, sseUnrestricted: result.sseUnrestricted,
                nObservations: result.nObservations, wasFirstDifferenced: result.wasFirstDifferenced,
                effectSize: result.effectSize, optimalLagDays: result.optimalLagDays,
                directionality: direction
            )
        }
        if let result = bToA {
            bToA = GrangerResult(
                cause: result.cause, effect: result.effect,
                fStatistic: result.fStatistic, pValue: result.pValue,
                optimalLag: result.optimalLag, isCausal: result.isCausal,
                sseRestricted: result.sseRestricted, sseUnrestricted: result.sseUnrestricted,
                nObservations: result.nObservations, wasFirstDifferenced: result.wasFirstDifferenced,
                effectSize: result.effectSize, optimalLagDays: result.optimalLagDays,
                directionality: direction
            )
        }

        return (aToB: aToB, bToA: bToA)
    }

    // MARK: - Multivariate Granger Test

    /// Multivariate lagged regression: test whether multiple predictors jointly Granger-cause a target.
    ///
    /// Builds a design matrix with columns:
    ///   [intercept, target_lag1..target_lagP, pred1_lag1..pred1_lagP, pred2_lag1..pred2_lagP, ...]
    ///
    /// Uses BIC to select optimal lag from 1..maxLag. Fits via OLS normal equations solved
    /// by AccelerateML.solveLinearSystem. Computes per-predictor t-statistics and p-values
    /// via t-distribution CDF (regularizedIncompleteBeta with df = n - k - 1).
    ///
    /// - Parameters:
    ///   - target: The target metric to predict
    ///   - predictors: Array of predictor metrics
    ///   - timeSeries: Dictionary mapping metrics to their time series values (chronologically ordered, same length)
    ///   - maxLag: Maximum lag order to consider (default 5)
    /// - Returns: MultivariateRegressionResult, or nil if insufficient data or degenerate input
    static func multivariateGrangerTest(
        target: HealthMetric,
        predictors: [HealthMetric],
        timeSeries: [HealthMetric: [Double]],
        maxLag: Int = 5
    ) -> MultivariateRegressionResult? {
        guard let targetSeries = timeSeries[target] else { return nil }
        let predSeries = predictors.compactMap { timeSeries[$0] }
        guard predSeries.count == predictors.count else { return nil }

        let seriesLength = targetSeries.count
        let nPredictors = predictors.count
        let minObservations = 2 * maxLag * (1 + nPredictors) + 10
        guard seriesLength >= max(minObservations, 45) else { return nil }

        // Check all series are same length and have variance
        for s in predSeries {
            guard s.count == seriesLength, hasVariance(s) else { return nil }
        }
        guard hasVariance(targetSeries) else { return nil }

        // Stationarity check: first-difference all if any is non-stationary
        var workTarget = targetSeries
        var workPreds = predSeries

        let anyNonStationary = !isStationary(workTarget) || workPreds.contains { !isStationary($0) }
        if anyNonStationary {
            workTarget = firstDifference(workTarget)
            workPreds = workPreds.map { firstDifference($0) }

            guard workTarget.count >= max(minObservations, 45),
                  hasVariance(workTarget),
                  workPreds.allSatisfy({ hasVariance($0) }) else { return nil }
        }

        // Select optimal lag via BIC
        let optimalLag = selectMultivariateLag(
            target: workTarget, predictors: workPreds, maxLag: maxLag
        )

        // Number of usable observations after lagging
        let n = workTarget.count - optimalLag
        // Total parameters: intercept + optimalLag (target lags) + nPredictors * optimalLag (predictor lags)
        let k = 1 + optimalLag + nPredictors * optimalLag
        guard n > k + 2 else { return nil }

        // Build multivariate design matrix
        let designMatrix = buildMultivariateDesignMatrix(
            target: workTarget, predictors: workPreds, lag: optimalLag
        )

        // Dependent variable: target(t) for t = lag..end
        let y = Array(workTarget[optimalLag...])
        guard y.count == n else { return nil }

        // Solve OLS: compute X'X, X'y, then β = (X'X)^{-1} X'y
        let nCols = k
        var xtx = [Double](repeating: 0, count: nCols * nCols)
        for i in 0..<nCols {
            for j in i..<nCols {
                var dot: Double = 0
                for row in 0..<n {
                    dot += designMatrix[row * nCols + i] * designMatrix[row * nCols + j]
                }
                xtx[i * nCols + j] = dot
                xtx[j * nCols + i] = dot
            }
        }

        var xty = [Double](repeating: 0, count: nCols)
        for i in 0..<nCols {
            var dot: Double = 0
            for row in 0..<n {
                dot += designMatrix[row * nCols + i] * y[row]
            }
            xty[i] = dot
        }

        guard let beta = solveLinearSystem(a: xtx, b: xty, n: nCols) else { return nil }

        // Compute residuals and SSE
        var sse: Double = 0
        var residuals = [Double](repeating: 0, count: n)
        for row in 0..<n {
            var predicted: Double = 0
            for col in 0..<nCols {
                predicted += designMatrix[row * nCols + col] * beta[col]
            }
            let residual = y[row] - predicted
            residuals[row] = residual
            sse += residual * residual
        }
        guard sse > 0 else { return nil }

        // Total sum of squares
        let yMean = y.reduce(0, +) / Double(n)
        let sst = y.reduce(0.0) { $0 + ($1 - yMean) * ($1 - yMean) }
        guard sst > 0 else { return nil }

        // R² and adjusted R²
        let rSquared = 1.0 - sse / sst
        let adjustedRSquared = 1.0 - (1.0 - rSquared) * Double(n - 1) / Double(n - k - 1)

        // Overall F-statistic: F = (R²/k_pred) / ((1-R²)/(n-k-1))
        // where k_pred = number of predictor parameters (excluding intercept and target lags)
        let kPred = Double(nPredictors * optimalLag)
        let dfDenom = Double(n - k)
        guard dfDenom > 0, kPred > 0 else { return nil }
        let overallF = (rSquared / kPred) / ((1.0 - rSquared) / dfDenom)
        let overallFPValue = fDistributionSurvival(f: overallF, df1: Int(kPred), df2: Int(dfDenom))

        // Residual standard error
        let sigma2 = sse / dfDenom
        let residualStdError = sigma2.squareRoot()

        // Compute (X'X)^{-1} for standard errors
        // We need the diagonal of (X'X)^{-1}
        let xtxInvDiag = computeXtXInverseDiagonal(xtx: xtx, n: nCols)

        // Per-predictor statistics (for each predictor metric, summarize across its lags)
        // Column layout: [intercept, target_lag1..target_lagP, pred1_lag1..pred1_lagP, ...]
        var coefficients: [HealthMetric: Double] = [:]
        var standardErrors: [HealthMetric: Double] = [:]
        var tStatistics: [HealthMetric: Double] = [:]
        var pValues: [HealthMetric: Double] = [:]
        let dfResidual = n - k

        for (predIdx, predMetric) in predictors.enumerated() {
            // Column indices for this predictor's lags
            let startCol = 1 + optimalLag + predIdx * optimalLag

            // Find the lag with largest absolute coefficient
            var bestLagCol = startCol
            var bestAbsBeta: Double = 0
            for lagIdx in 0..<optimalLag {
                let col = startCol + lagIdx
                if abs(beta[col]) > bestAbsBeta {
                    bestAbsBeta = abs(beta[col])
                    bestLagCol = col
                }
            }

            let betaJ = beta[bestLagCol]
            let seJ: Double
            if let diagVal = xtxInvDiag?[bestLagCol], diagVal > 0 {
                seJ = residualStdError * diagVal.squareRoot()
            } else {
                seJ = residualStdError // fallback
            }

            let tStat = seJ > 0 ? betaJ / seJ : 0
            // p-value from t-distribution: P(|T| > |t|) with df = n - k
            let tPValue = tDistributionSurvival(t: abs(tStat), df: dfResidual) * 2.0

            coefficients[predMetric] = betaJ
            standardErrors[predMetric] = seJ
            tStatistics[predMetric] = tStat
            pValues[predMetric] = min(tPValue, 1.0)
        }

        // BIC = n * ln(SSE/n) + k * ln(n)
        let bicScore = Double(n) * log(sse / Double(n)) + Double(k) * log(Double(n))

        return MultivariateRegressionResult(
            targetMetric: target,
            predictorMetrics: predictors,
            optimalLag: optimalLag,
            coefficients: coefficients,
            standardErrors: standardErrors,
            tStatistics: tStatistics,
            pValues: pValues,
            rSquared: rSquared,
            adjustedRSquared: adjustedRSquared,
            fStatistic: overallF,
            fPValue: overallFPValue,
            residualStdError: residualStdError,
            observationCount: n,
            bicScore: bicScore
        )
    }

    // MARK: - Rolling Stability Test

    /// Perform rolling window Granger causality analysis to assess temporal stability.
    ///
    /// Runs pairwise Granger tests on overlapping windows of the time series and reports
    /// what fraction of windows show a significant causal relationship.
    ///
    /// - Parameters:
    ///   - metricA: The putative cause metric
    ///   - metricB: The putative effect metric
    ///   - timeSeries: Dictionary mapping metrics to chronologically-ordered daily values
    ///   - windowSize: Size of each window in days (default 60)
    ///   - stepSize: Step between windows in days (default 20)
    /// - Returns: StabilityReport, or nil if insufficient data
    static func rollingStabilityTest(
        metricA: HealthMetric,
        metricB: HealthMetric,
        timeSeries: [HealthMetric: [Double]],
        windowSize: Int = 60,
        stepSize: Int = 20
    ) -> StabilityReport? {
        guard let seriesA = timeSeries[metricA],
              let seriesB = timeSeries[metricB],
              seriesA.count == seriesB.count,
              seriesA.count >= windowSize + stepSize else { return nil }

        let n = seriesA.count
        var windowResults: [(startDate: Date, pValue: Double, fStat: Double, isCausal: Bool)] = []
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: Date())

        var start = 0
        while start + windowSize <= n {
            let windowA = Array(seriesA[start..<(start + windowSize)])
            let windowB = Array(seriesB[start..<(start + windowSize)])

            // Compute a synthetic start date (relative to current date, counting back)
            let daysFromEnd = n - start
            let windowStartDate = calendar.date(byAdding: .day, value: -daysFromEnd, to: baseDate) ?? baseDate

            if let result = test(
                cause: windowA, effect: windowB,
                causeMetric: metricA, effectMetric: metricB,
                maxLag: 3 // Use smaller lag for shorter windows
            ) {
                windowResults.append((
                    startDate: windowStartDate,
                    pValue: result.pValue,
                    fStat: result.fStatistic,
                    isCausal: result.isCausal
                ))
            }

            start += stepSize
        }

        guard !windowResults.isEmpty else { return nil }

        // Stability score: fraction of windows where causal
        let causalCount = windowResults.filter(\.isCausal).count
        let stabilityScore = Double(causalCount) / Double(windowResults.count)

        // Effect size variation: coefficient of variation of F-statistics
        let fStats = windowResults.map(\.fStat)
        let fMean = fStats.reduce(0, +) / Double(fStats.count)
        let fVariance = fStats.reduce(0.0) { $0 + ($1 - fMean) * ($1 - fMean) } / Double(fStats.count)
        let fStdDev = fVariance.squareRoot()
        let effectSizeVariation = fMean > 0 ? fStdDev / fMean : 0

        return StabilityReport(
            windowResults: windowResults,
            stabilityScore: stabilityScore,
            effectSizeVariation: effectSizeVariation,
            isStable: stabilityScore > 0.6
        )
    }

    // MARK: - Design Matrix Construction

    /// Build the restricted (AR-only) design matrix for the regression:
    ///   y(t) = intercept + a1*y(t-1) + a2*y(t-2) + ... + ap*y(t-p)
    ///
    /// Each row corresponds to time t (for t = lag, lag+1, ..., N-1).
    /// Columns: [y(t-1), y(t-2), ..., y(t-p), 1]
    ///
    /// Returns a flat row-major array with nRows = (N - lag), nCols = (lag + 1)
    private static func buildRestrictedDesignMatrix(effect: [Double], lag: Int) -> [Double] {
        let n = effect.count
        let nRows = n - lag
        let nCols = lag + 1 // AR lags + intercept

        var matrix = [Double](repeating: 0, count: nRows * nCols)

        for t in 0..<nRows {
            let rowOffset = t * nCols
            // AR lag columns: y(t+lag-1), y(t+lag-2), ..., y(t)
            for j in 0..<lag {
                matrix[rowOffset + j] = effect[t + lag - 1 - j]
            }
            // Intercept column
            matrix[rowOffset + lag] = 1.0
        }

        return matrix
    }

    /// Build the unrestricted design matrix for the regression:
    ///   y(t) = intercept + a1*y(t-1) + ... + ap*y(t-p) + b1*x(t-1) + ... + bp*x(t-p)
    ///
    /// Each row corresponds to time t (for t = lag, lag+1, ..., N-1).
    /// Columns: [y(t-1), ..., y(t-p), x(t-1), ..., x(t-p), 1]
    ///
    /// Returns a flat row-major array with nRows = (N - lag), nCols = (2*lag + 1)
    private static func buildUnrestrictedDesignMatrix(
        cause: [Double], effect: [Double], lag: Int
    ) -> [Double] {
        let n = effect.count
        let nRows = n - lag
        let nCols = 2 * lag + 1 // AR lags + exogenous lags + intercept

        var matrix = [Double](repeating: 0, count: nRows * nCols)

        for t in 0..<nRows {
            let rowOffset = t * nCols
            // AR lag columns: y(t+lag-1), y(t+lag-2), ..., y(t)
            for j in 0..<lag {
                matrix[rowOffset + j] = effect[t + lag - 1 - j]
            }
            // Exogenous lag columns: x(t+lag-1), x(t+lag-2), ..., x(t)
            for j in 0..<lag {
                matrix[rowOffset + lag + j] = cause[t + lag - 1 - j]
            }
            // Intercept column
            matrix[rowOffset + 2 * lag] = 1.0
        }

        return matrix
    }

    // MARK: - OLS Regression

    /// Fit an OLS regression and return the sum of squared errors (SSE).
    ///
    /// Solves the normal equations: (X'X) beta = X'y
    /// Then computes SSE = sum((y - X*beta)^2)
    ///
    /// Uses Gaussian elimination with partial pivoting to solve the (nCols x nCols) system.
    ///
    /// - Parameters:
    ///   - designMatrix: Row-major flat array of shape (nRows x nCols)
    ///   - y: Dependent variable vector of length nRows
    ///   - nRows: Number of observations
    /// - Returns: SSE, or nil if the system is singular or degenerate
    private static func fitOLSAndComputeSSE(
        designMatrix: [Double], y: [Double], nRows: Int
    ) -> Double? {
        let nCols = designMatrix.count / nRows
        guard nCols > 0, nRows > nCols, y.count == nRows else { return nil }

        // Compute X'X (nCols x nCols, symmetric)
        var xtx = [Double](repeating: 0, count: nCols * nCols)
        for i in 0..<nCols {
            for j in i..<nCols {
                var dot: Double = 0
                // X[:,i] dot X[:,j]. columns are strided in row-major layout
                for row in 0..<nRows {
                    dot += designMatrix[row * nCols + i] * designMatrix[row * nCols + j]
                }
                xtx[i * nCols + j] = dot
                xtx[j * nCols + i] = dot // symmetric
            }
        }

        // Compute X'y (nCols x 1)
        var xty = [Double](repeating: 0, count: nCols)
        for i in 0..<nCols {
            var dot: Double = 0
            for row in 0..<nRows {
                dot += designMatrix[row * nCols + i] * y[row]
            }
            xty[i] = dot
        }

        // Solve (X'X) beta = X'y via Gaussian elimination with partial pivoting
        guard let beta = solveLinearSystem(a: xtx, b: xty, n: nCols) else { return nil }

        // Compute residuals: e = y - X * beta, then SSE = sum(e^2)
        var sse: Double = 0
        for row in 0..<nRows {
            var predicted: Double = 0
            for col in 0..<nCols {
                predicted += designMatrix[row * nCols + col] * beta[col]
            }
            let residual = y[row] - predicted
            sse += residual * residual
        }

        return sse
    }

    /// Solve A*x = b using AccelerateML's Gaussian elimination with partial pivoting.
    ///
    /// If the system is ill-conditioned (pivot < 1e-10), applies a ridge penalty
    /// λ = 1e-6 to the diagonal of A and retries.
    ///
    /// A is n x n (row-major flat array), b is length n.
    /// Returns the solution vector x, or nil if the system is singular even after regularization.
    private static func solveLinearSystem(a: [Double], b: [Double], n: Int) -> [Double]? {
        guard a.count == n * n, b.count == n, n > 0 else { return nil }

        // First attempt: direct solve via AccelerateML
        if let solution = AccelerateML.solveLinearSystem(A: a, b: b, n: n),
           solution.allSatisfy({ $0.isFinite }) {
            return solution
        }

        // Ill-conditioned: add ridge penalty λ = 1e-6 to diagonal
        var regularized = a
        let lambda = 1e-6
        for i in 0..<n {
            regularized[i * n + i] += lambda
        }

        if let solution = AccelerateML.solveLinearSystem(A: regularized, b: b, n: n),
           solution.allSatisfy({ $0.isFinite }) {
            return solution
        }

        return nil
    }

    // MARK: - BIC Lag Selection

    /// Select the optimal lag order using BIC (Bayesian Information Criterion).
    ///
    /// BIC = n * ln(SSE/n) + k * ln(n)
    ///
    /// where n = number of observations, k = number of parameters, SSE = sum of squared errors
    /// from the unrestricted model. Lower BIC is better; it penalizes model complexity.
    ///
    /// - Parameters:
    ///   - cause: The putative cause series
    ///   - effect: The putative effect series
    ///   - maxLag: Maximum lag order to test
    /// - Returns: The lag order (1..maxLag) that minimizes BIC
    private static func selectOptimalLag(cause: [Double], effect: [Double], maxLag: Int) -> Int {
        var bestLag = 1
        var bestBIC = Double.infinity

        for lag in 1...maxLag {
            let n = effect.count - lag
            guard n > 2 * lag + 1 else { continue }

            let design = buildUnrestrictedDesignMatrix(cause: cause, effect: effect, lag: lag)
            let y = Array(effect[lag...])

            guard let sse = fitOLSAndComputeSSE(designMatrix: design, y: y, nRows: n),
                  sse > 0 else { continue }

            let k = Double(2 * lag + 1) // number of parameters in unrestricted model
            let nDouble = Double(n)

            // BIC = n * ln(SSE/n) + k * ln(n)
            let bic = nDouble * log(sse / nDouble) + k * log(nDouble)

            if bic < bestBIC {
                bestBIC = bic
                bestLag = lag
            }
        }

        return bestLag
    }

    // MARK: - Stationarity Check

    /// Simplified stationarity check using the AR(1) coefficient.
    ///
    /// Fits y(t) = phi * y(t-1) + e(t) via OLS and checks if |phi| < 1.
    /// This is a simplified Augmented Dickey-Fuller test: if the AR(1) coefficient
    /// is >= 1 in absolute value, the series likely has a unit root (non-stationary).
    ///
    /// - Parameter series: Time series to check
    /// - Returns: true if the series appears stationary (|phi| < 1)
    private static func isStationary(_ series: [Double]) -> Bool {
        let n = series.count
        guard n >= 10 else { return true } // Too short to reliably test; assume stationary

        // Fit y(t) = phi * y(t-1) + intercept
        // X = [[y(0), 1], [y(1), 1], ..., [y(n-2), 1]]
        // y = [y(1), y(2), ..., y(n-1)]
        let nObs = n - 1
        var designMatrix = [Double](repeating: 0, count: nObs * 2)
        var y = [Double](repeating: 0, count: nObs)

        for t in 0..<nObs {
            designMatrix[t * 2 + 0] = series[t]
            designMatrix[t * 2 + 1] = 1.0
            y[t] = series[t + 1]
        }

        // Solve normal equations for [phi, intercept]
        // X'X is 2x2, X'y is 2x1
        var xtx = [Double](repeating: 0, count: 4)
        var xty = [Double](repeating: 0, count: 2)

        for t in 0..<nObs {
            let x0 = designMatrix[t * 2]
            let x1 = designMatrix[t * 2 + 1]
            xtx[0] += x0 * x0
            xtx[1] += x0 * x1
            xtx[2] += x1 * x0
            xtx[3] += x1 * x1
            xty[0] += x0 * y[t]
            xty[1] += x1 * y[t]
        }

        guard let beta = solveLinearSystem(a: xtx, b: xty, n: 2) else {
            return true // Can't determine; assume stationary
        }

        let phi = beta[0]
        return abs(phi) < 1.0
    }

    /// First-difference a series: d(t) = y(t) - y(t-1)
    ///
    /// Removes unit roots (I(1) non-stationarity) by computing successive differences.
    /// The resulting series has length n-1.
    private static func firstDifference(_ series: [Double]) -> [Double] {
        guard series.count >= 2 else { return [] }
        var result = [Double](repeating: 0, count: series.count - 1)
        for i in 0..<result.count {
            result[i] = series[i + 1] - series[i]
        }
        return result
    }

    // MARK: - F-Distribution P-Value

    /// Compute the survival function (upper-tail probability) of the F-distribution:
    ///   P(F > f | df1, df2) = I_x(df2/2, df1/2)
    ///
    /// where x = df2 / (df2 + df1 * f), and I_x(a, b) is the regularized incomplete beta function.
    ///
    /// - Parameters:
    ///   - f: The F-statistic value
    ///   - df1: Numerator degrees of freedom (number of restrictions)
    ///   - df2: Denominator degrees of freedom (n - k_unrestricted)
    /// - Returns: p-value (probability of observing F >= f under H0)
    static func fDistributionSurvival(f: Double, df1: Int, df2: Int) -> Double {
        guard f > 0, f.isFinite, df1 > 0, df2 > 0 else { return 1.0 }

        let d1 = Double(df1)
        let d2 = Double(df2)
        let x = d2 / (d2 + d1 * f)

        guard x > 0, x < 1 else {
            if x <= 0 { return 0.0 } // f is extremely large
            return 1.0               // f is extremely small
        }

        return regularizedIncompleteBeta(x: x, a: d2 / 2.0, b: d1 / 2.0)
    }

    /// Compute the regularized incomplete beta function I_x(a, b) = B(x; a, b) / B(a, b)
    /// using the continued fraction expansion (Lentz's modified algorithm).
    ///
    /// The continued fraction for I_x(a, b) converges rapidly for x < (a+1)/(a+b+2).
    /// For x >= (a+1)/(a+b+2), we use the symmetry relation:
    ///   I_x(a, b) = 1 - I_{1-x}(b, a)
    ///
    /// **Continued fraction (Abramowitz & Stegun 26.5.8):**
    ///
    ///   I_x(a, b) = [x^a * (1-x)^b / (a * B(a,b))] * 1/(1 + d1/(1 + d2/(1 + ...)))
    ///
    /// where the coefficients d_m are:
    ///   d_{2m+1} = -(a+m)(a+b+m)x / ((a+2m)(a+2m+1))
    ///   d_{2m}   = m(b-m)x / ((a+2m-1)(a+2m))
    ///
    /// - Parameters:
    ///   - x: The upper limit of integration (0 < x < 1)
    ///   - a: First shape parameter (> 0)
    ///   - b: Second shape parameter (> 0)
    /// - Returns: I_x(a, b), the regularized incomplete beta function value
    static func regularizedIncompleteBeta(x: Double, a: Double, b: Double) -> Double {
        // Edge cases
        guard x > 0 else { return 0.0 }
        guard x < 1 else { return 1.0 }
        guard a > 0, b > 0 else { return 0.0 }

        // Use symmetry relation for faster convergence when x >= (a+1)/(a+b+2)
        if x >= (a + 1.0) / (a + b + 2.0) {
            return 1.0 - regularizedIncompleteBeta(x: 1.0 - x, a: b, b: a)
        }

        // Compute the log of the prefactor: x^a * (1-x)^b / (a * B(a,b))
        // Using log-gamma for numerical stability: B(a,b) = exp(lgamma(a) + lgamma(b) - lgamma(a+b))
        let logPrefactor = a * log(x) + b * log(1.0 - x)
            - log(a)
            - (lgamma(a) + lgamma(b) - lgamma(a + b))

        let prefactor = exp(logPrefactor)
        guard prefactor.isFinite else { return 0.0 }

        // Evaluate the continued fraction using Lentz's modified algorithm
        let cf = betaContinuedFraction(x: x, a: a, b: b)

        let result = prefactor * cf
        // Clamp to [0, 1]
        return Swift.min(Swift.max(result, 0.0), 1.0)
    }

    /// Evaluate the continued fraction for the regularized incomplete beta function
    /// using Lentz's modified algorithm.
    ///
    /// The continued fraction is: 1/(1 + d1/(1 + d2/(1 + ...)))
    ///
    /// Lentz's algorithm converts this to a product of successive terms,
    /// avoiding deep recursion and providing fast convergence.
    ///
    /// Reference: Numerical Recipes, Section 6.4; Press et al.
    ///
    /// - Parameters:
    ///   - x: Upper limit of integration
    ///   - a: First shape parameter
    ///   - b: Second shape parameter
    /// - Returns: The continued fraction value
    private static func betaContinuedFraction(x: Double, a: Double, b: Double) -> Double {
        let maxIterations = 200
        let epsilon = 1e-10
        let tiny = 1e-30 // Prevents division by zero in Lentz's algorithm

        // Lentz's algorithm: f = f_0, C_0 = f_0, D_0 = 0
        // where f_0 = 1 (the leading 1 in 1/(1+...))
        var f = 1.0
        var c = 1.0
        var d = 0.0

        for m in 1...maxIterations {
            let mDouble = Double(m)

            // Compute the continued fraction coefficient a_m
            // For odd m (m = 2k+1): coefficient uses d_{2k+1}
            // For even m (m = 2k): coefficient uses d_{2k}
            let coeff: Double
            if m % 2 == 0 {
                // Even: m = 2k, so k = m/2
                let k = mDouble / 2.0
                coeff = k * (b - k) * x / ((a + 2.0 * k - 1.0) * (a + 2.0 * k))
            } else {
                // Odd: m = 2k+1, so k = (m-1)/2
                let k = (mDouble - 1.0) / 2.0
                coeff = -(a + k) * (a + b + k) * x / ((a + 2.0 * k) * (a + 2.0 * k + 1.0))
            }

            // Lentz's update:
            // D_m = 1 / (1 + a_m * D_{m-1})
            d = 1.0 + coeff * d
            if abs(d) < tiny { d = tiny }
            d = 1.0 / d

            // C_m = 1 + a_m / C_{m-1}
            c = 1.0 + coeff / c
            if abs(c) < tiny { c = tiny }

            // f_m = f_{m-1} * C_m * D_m
            let delta = c * d
            f *= delta

            // Check convergence
            if abs(delta - 1.0) < epsilon {
                break
            }
        }

        return f
    }

    // MARK: - Multivariate Helpers

    /// Build design matrix for multivariate lagged regression.
    ///
    /// Column layout: [intercept, target_lag1..target_lagP, pred1_lag1..pred1_lagP, pred2_lag1..pred2_lagP, ...]
    ///
    /// Returns a flat row-major array with nRows = (N - lag), nCols = (1 + lag + predictors.count * lag)
    private static func buildMultivariateDesignMatrix(
        target: [Double], predictors: [[Double]], lag: Int
    ) -> [Double] {
        let n = target.count
        let nPredictors = predictors.count
        let nRows = n - lag
        let nCols = 1 + lag + nPredictors * lag // intercept + target lags + predictor lags

        var matrix = [Double](repeating: 0, count: nRows * nCols)

        for t in 0..<nRows {
            let rowOffset = t * nCols

            // Intercept column (column 0)
            matrix[rowOffset] = 1.0

            // Target lag columns (columns 1..lag): target(t+lag-1), target(t+lag-2), ..., target(t)
            for j in 0..<lag {
                matrix[rowOffset + 1 + j] = target[t + lag - 1 - j]
            }

            // Predictor lag columns
            for (pIdx, predSeries) in predictors.enumerated() {
                let predOffset = 1 + lag + pIdx * lag
                for j in 0..<lag {
                    matrix[rowOffset + predOffset + j] = predSeries[t + lag - 1 - j]
                }
            }
        }

        return matrix
    }

    /// Select optimal lag for multivariate regression via BIC.
    ///
    /// BIC = n * ln(SSE/n) + k * ln(n)
    ///
    /// Tests lags 1..maxLag and returns the one with lowest BIC.
    private static func selectMultivariateLag(
        target: [Double], predictors: [[Double]], maxLag: Int
    ) -> Int {
        var bestLag = 1
        var bestBIC = Double.infinity

        for lag in 1...maxLag {
            let n = target.count - lag
            let k = 1 + lag + predictors.count * lag
            guard n > k + 2 else { continue }

            let design = buildMultivariateDesignMatrix(target: target, predictors: predictors, lag: lag)
            let y = Array(target[lag...])

            guard let sse = fitOLSAndComputeSSE(designMatrix: design, y: y, nRows: n),
                  sse > 0 else { continue }

            let nDouble = Double(n)
            let kDouble = Double(k)
            let bic = nDouble * log(sse / nDouble) + kDouble * log(nDouble)

            if bic < bestBIC {
                bestBIC = bic
                bestLag = lag
            }
        }

        return bestLag
    }

    /// Compute the diagonal of (X'X)^{-1} by solving (X'X) * e_j = e_j for each j.
    ///
    /// This gives the variance multipliers for computing standard errors of coefficients.
    /// Returns an array of diagonal values, or nil if the system is singular.
    private static func computeXtXInverseDiagonal(xtx: [Double], n: Int) -> [Double]? {
        var diagonal = [Double](repeating: 0, count: n)

        for j in 0..<n {
            // Solve (X'X) * column_j = e_j where e_j is the j-th standard basis vector
            var ej = [Double](repeating: 0, count: n)
            ej[j] = 1.0

            guard let col = solveLinearSystem(a: xtx, b: ej, n: n) else { return nil }
            diagonal[j] = col[j]
        }

        return diagonal
    }

    // MARK: - t-Distribution P-Value

    /// Compute the upper-tail probability of the t-distribution: P(T > t | df).
    ///
    /// Uses the relationship between the t-distribution and the F-distribution:
    ///   If T ~ t(df), then T² ~ F(1, df)
    ///   P(|T| > t) = P(F > t² | 1, df)
    ///
    /// For a one-tailed test, this returns P(T > t) = P(F > t²) / 2 when t > 0.
    ///
    /// - Parameters:
    ///   - t: The t-statistic (assumed positive for one-tailed)
    ///   - df: Degrees of freedom
    /// - Returns: One-tailed p-value (upper tail)
    static func tDistributionSurvival(t: Double, df: Int) -> Double {
        guard t > 0, t.isFinite, df > 0 else { return 0.5 }

        // t² is distributed as F(1, df)
        let f = t * t
        let x = Double(df) / (Double(df) + f)

        guard x > 0, x < 1 else {
            if x <= 0 { return 0.0 }
            return 0.5
        }

        // P(|T| > t) = I_x(df/2, 1/2)
        let twoTailed = regularizedIncompleteBeta(x: x, a: Double(df) / 2.0, b: 0.5)

        // One-tailed: divide by 2
        return twoTailed / 2.0
    }

    // MARK: - Utility

    /// Check if a series has non-zero variance (not all identical values)
    private static func hasVariance(_ series: [Double]) -> Bool {
        guard let first = series.first else { return false }
        return series.contains { $0 != first }
    }
}
