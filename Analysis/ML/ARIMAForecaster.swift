import Foundation
import Accelerate

/// Auto-Regressive Integrated Moving Average (ARIMA) forecaster implemented natively in Swift using vDSP.
/// Model format: ARIMA(p,d,q)
/// - p = Auto-regressive lags
/// - d = Degree of differencing
/// - q = Moving average lags
final class ARIMAForecaster {
    /// Minimum days required for statistically significant ARIMA
    static let minimumDays = 30
    
    struct ARIMAParameters: Codable {
        var p: Int
        var d: Int
        var q: Int
        var arCoefficients: [Double]
        var maCoefficients: [Double]
        var intercept: Double
        var residualStdDev: Double
        var lastObservations: [Double]
        var lastResiduals: [Double]
        var aic: Double
    }
    
    // MARK: - State
    
    private var params: [HealthMetric: ARIMAParameters] = [:]
    
    /// Get the parameters for serialization
    func getState() -> [String: ARIMAParameters] {
        Dictionary(uniqueKeysWithValues: params.map { ($0.key.rawValue, $0.value) })
    }
    
    /// Restore from serialized state
    func restoreState(_ saved: [String: ARIMAParameters]) {
        for (rawValue, param) in saved {
            if let metric = HealthMetric(rawValue: rawValue) {
                params[metric] = param
            }
        }
    }
    
    // MARK: - Training
    
    /// Automated ARIMA fitting using an exhaustive grid search to minimize AIC (Akaike Information Criterion)
    func fit(timeSeries: [HealthMetric: MetricTimeSeries]) {
        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }
            
            // Grid search bounds
            let maxP = 3
            let maxD = 2
            let maxQ = 2
            
            var bestParams: ARIMAParameters?
            var bestAIC = Double.infinity
            
            for p in 0...maxP {
                for d in 0...maxD {
                    for q in 0...maxQ {
                        // Skip trivial model
                        if p == 0 && d == 0 && q == 0 { continue }
                        
                        // Fit model for this configuration
                        if let fitted = fitModel(values: values, p: p, d: d, q: q) {
                            if fitted.aic < bestAIC {
                                bestAIC = fitted.aic
                                bestParams = fitted
                            }
                        }
                    }
                }
            }
            
            if let best = bestParams {
                params[metric] = best
            }
        }
    }
    
    // MARK: - Forecasting
    
    /// Step-wise forecasting for n-horizons
    func forecast(metric: HealthMetric, stepsAhead: Int = 1) -> (value: Double, ci: Double)? {
        guard let model = params[metric] else { return nil }
        
        let p = model.p
        let d = model.d
        let q = model.q
        
        let currentObs = model.lastObservations
        let currentResids = model.lastResiduals
        
        // Ensure we have enough history to difference back up
        var baseDifferencingHistory = currentObs
        var diffHistory = currentObs
        for _ in 0..<d {
            diffHistory = difference(diffHistory)
        }
        
        var predictions: [Double] = []
        var differencedPredictions: [Double] = []
        
        for step in 0..<stepsAhead {
            var forecastValue = model.intercept
            
            // AR term
            if p > 0 {
                let history = differencedPredictions.isEmpty ? diffHistory : diffHistory + differencedPredictions
                for lag in 1...p {
                    if lag <= history.count {
                        forecastValue += model.arCoefficients[lag - 1] * history[history.count - lag]
                    }
                }
            }
            
            // MA term
            if q > 0 {
                for lag in 1...q {
                    if lag <= currentResids.count {
                        // Assuming expected value of future white noise residuals is 0,
                        // we only multiply actual historic residuals.
                        if step == 0 {
                            forecastValue += model.maCoefficients[lag - 1] * currentResids[currentResids.count - lag]
                        }
                    }
                }
            }
            
            differencedPredictions.append(forecastValue)
            
            // Inverse differencing
            let undifferencedValue = inverseDifference(
                target: forecastValue,
                history: baseDifferencingHistory,
                d: d
            )
            predictions.append(undifferencedValue)
            baseDifferencingHistory.append(undifferencedValue)
        }
        
        guard let finalPred = predictions.last else { return nil }
        
        // Compute standard error of forecast roughly
        let confidenceVariance = pow(model.residualStdDev, 2) * Double(stepsAhead)
        let ci = 1.96 * confidenceVariance.squareRoot()
        
        return (finalPred, ci)
    }
    
    // MARK: - Core Implementation
    
    private func fitModel(values: [Double], p: Int, d: Int, q: Int) -> ARIMAParameters? {
        // 1. Differencing
        var workingSeries = values
        for _ in 0..<d {
            workingSeries = difference(workingSeries)
        }
        
        let n = workingSeries.count
        guard n > max(p, q) + 1 else { return nil }
        
        // 2. Intercept (Mean)
        let intercept = AccelerateML.mean(workingSeries)
        
        // Center the series for AR/MA calculation
        let centeredSeries = workingSeries.map { $0 - intercept }
        
        // 3. AR Coefficients (Yule-Walker Equations)
        var arCoeffs = [Double](repeating: 0, count: p)
        if p > 0 {
            if let solvedAR = solveYuleWalker(series: centeredSeries, order: p) {
                arCoeffs = solvedAR
            } else {
                return nil // Matrix singular or insufficient data
            }
        }
        
        // 4. MA Coefficients (Innovation Algorithm / Simple Gradient Descent approach using vDSP)
        // For simplicity in a high-performance native port without optimization packages,
        // we approximate MA coefficients via residuals of the AR model.
        var maCoeffs = [Double](repeating: 0, count: q)
        var residuals = [Double](repeating: 0, count: n)
        
        if q > 0 {
            // Compute AR residuals
            for i in p..<n {
                var arPrediction = 0.0
                for lag in 1...p {
                    arPrediction += arCoeffs[lag - 1] * centeredSeries[i - lag]
                }
                residuals[i] = centeredSeries[i] - arPrediction
            }
            
            // Regress current residuals on past residuals to find MA
            if let solvedMA = solveMovingAverage(residuals: residuals, order: q) {
                maCoeffs = solvedMA
            }
        } else {
            // Just AR residuals
            for i in p..<n {
                var arPrediction = 0.0
                for lag in 1...p {
                    arPrediction += arCoeffs[lag - 1] * centeredSeries[i - lag]
                }
                residuals[i] = centeredSeries[i] - arPrediction
            }
        }
        
        // 5. Compute Final Residuals & Variance
        var finalResiduals: [Double] = []
        let startIndex = max(p, q)
        for i in startIndex..<n {
            var arTerm = 0.0
            for lag in 1...max(p, 1) {
                if p > 0 { arTerm += arCoeffs[lag - 1] * centeredSeries[i - lag] }
            }
            var maTerm = 0.0
            for lag in 1...max(q, 1) {
                if q > 0 { maTerm += maCoeffs[lag - 1] * residuals[i - lag] }
            }
            
            let prediction = intercept + arTerm + maTerm
            let error = workingSeries[i] - prediction
            finalResiduals.append(error)
        }
        
        guard !finalResiduals.isEmpty else { return nil }
        
        let sse = finalResiduals.reduce(0) { $0 + pow($1, 2) }
        let residualVar = sse / Double(finalResiduals.count)
        
        guard residualVar > 0 else { return nil }
        
        // 6. AIC Computation
        // AIC = 2k + n * ln(SSE/n) where k = params
        let kParam = Double(p + q + 1)
        let aic = 2 * kParam + Double(finalResiduals.count) * log(residualVar)
        
        return ARIMAParameters(
            p: p,
            d: d,
            q: q,
            arCoefficients: arCoeffs,
            maCoefficients: maCoeffs,
            intercept: intercept,
            residualStdDev: residualVar.squareRoot(),
            lastObservations: Array(values.suffix(max(p, d) + 2)), // Keep enough history for un-differencing
            lastResiduals: Array(finalResiduals.suffix(q)),
            aic: aic
        )
    }
    
    // MARK: - Math Helpers
    
    private func difference(_ series: [Double]) -> [Double] {
        guard series.count > 1 else { return [] }
        var result = [Double](repeating: 0, count: series.count - 1)
        // vDSP subtract: var2 = var1 - var2.  C = A - B
        // C = series[1...] - series[0...n-1]
        let a = Array(series.dropFirst())
        let b = Array(series.dropLast())
        vDSP_vsubD(b, 1, a, 1, &result, 1, vDSP_Length(result.count))
        return result
    }
    
    private func inverseDifference(target: Double, history: [Double], d: Int) -> Double {
        if d == 0 { return target }
        if d == 1 { return target + (history.last ?? 0) }
        
        // If d=2: y_t - 2y_{t-1} + y_{t-2} = diff_diff
        // y_t = target + 2y_{t-1} - y_{t-2}
        if d == 2, history.count >= 2 {
            let yt_1 = history[history.count - 1]
            let yt_2 = history[history.count - 2]
            return target + 2 * yt_1 - yt_2
        }
        return target
    }
    
    /// Solves Yule-Walker equations for AR coefficients using auto-covariance matrix
    private func solveYuleWalker(series: [Double], order p: Int) -> [Double]? {
        let n = series.count
        guard n > p else { return nil }
        
        var acvf = [Double](repeating: 0, count: p + 1)
        
        // Compute autocovariance
        let mean = AccelerateML.mean(series)
        for lag in 0...p {
            var sum = 0.0
            for i in 0..<(n - lag) {
                sum += (series[i] - mean) * (series[i + lag] - mean)
            }
            acvf[lag] = sum / Double(n)
        }
        
        guard acvf[0] > 0 else { return nil }
        
        // Construct Toeplitz matrix R and vector r
        var R = [Double](repeating: 0, count: p * p)
        var r = [Double](repeating: 0, count: p)
        
        for i in 0..<p {
            r[i] = acvf[i + 1]
            for j in 0..<p {
                R[i * p + j] = acvf[abs(i - j)]
            }
        }
        
        // Solve R * phi = r -> phi = R^-1 * r
        return AccelerateML.solveLinearSystem(A: R, b: r, n: p)
    }
    
    /// Approx MA via OLS on residuals
    private func solveMovingAverage(residuals: [Double], order q: Int) -> [Double]? {
        let n = residuals.count
        guard n > q else { return nil }
        
        // Design matrix X of lagged residuals
        var X = [Double](repeating: 0, count: (n - q) * q)
        var y = [Double](repeating: 0, count: n - q)
        
        for i in q..<n {
            y[i - q] = residuals[i]
            for lag in 1...q {
                X[(i - q) * q + (lag - 1)] = residuals[i - lag]
            }
        }
        
        // (X'X)^-1 X'Y
        let rows = n - q
        let cols = q
        
        var Xt = [Double](repeating: 0, count: rows * cols)
        vDSP_mtransD(X, 1, &Xt, 1, vDSP_Length(cols), vDSP_Length(rows))
        
        let XtX = AccelerateML.matrixMultiply(A: Xt, B: X, rows: cols, cols: rows, n: cols)
        let XtY = AccelerateML.matVecMultiply(matrix: Xt, vector: y, rows: cols, cols: rows)
        
        guard !XtX.isEmpty else { return nil }
        
        return AccelerateML.solveLinearSystem(A: XtX, b: XtY, n: cols)
    }
}
