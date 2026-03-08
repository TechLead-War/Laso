import Foundation

/// Double-seasonal Holt-Winters forecaster with damped trend, Fourier decomposition,
/// and multi-horizon confidence intervals.
///
/// Weekly (period=7) seasonality is always active. Monthly (period=30) seasonality
/// activates when data >= 60 days, otherwise falls back to single-season mode.
final class TimeSeriesForecaster {
    /// Minimum days of data required for forecasting
    static let minimumDays = 21

    /// Minimum days to activate monthly seasonality
    private static let monthlyMinimumDays = 60

    /// Seasonal periods
    private static let weeklyPeriod = 7
    private static let monthlyPeriod = 30

    // MARK: - Model Parameters (per metric)

    struct HoltWintersState: Codable {
        var level: Double
        var trend: Double
        var seasonal: [Double]              // length = weeklyPeriod (7)
        var alpha: Double                   // level smoothing
        var beta: Double                    // trend smoothing
        var gamma: Double                   // weekly seasonal smoothing (gamma1)
        var residualStdDev: Double
        var fittedCount: Int

        // --- New fields ---
        var monthlySeasonals: [Double]?     // length = monthlyPeriod (30), nil when single-season
        var dampingFactor: Double            // phi for damped trend (1.0 = undamped)
        var gamma2: Double?                 // monthly seasonal smoothing
        var fourierCoefficients: [[Double]]? // outer: per period, inner: [a1,b1,a2,b2,...] coefficients

        /// One-step-ahead forecast (backward compatible)
        func forecast(stepsAhead: Int = 1) -> Double {
            let weeklyIndex = stepsAhead % seasonal.count
            let weeklySeasonal = seasonal[weeklyIndex]

            // Damped trend sum: sum_{i=1}^{h} phi^i * b
            let dampedTrendSum = dampedTrendCumulative(horizon: stepsAhead)

            let baseValue = (level + dampedTrendSum) * weeklySeasonal

            // Apply monthly seasonality if available
            if let monthly = monthlySeasonals, !monthly.isEmpty {
                let monthlyIndex = stepsAhead % monthly.count
                return baseValue * monthly[monthlyIndex]
            }

            return baseValue
        }

        /// Confidence interval width at given horizon using Hyndman-Khandakar prediction intervals.
        ///
        /// For ETS models, prediction variance grows as: σ² * Σ_{j=0}^{h-1} c_j²
        /// where c_j depends on the model parameters. For damped-trend multiplicative seasonal:
        /// c_0 = 1, c_j ≈ 1 + j*α + α*β*Σ_{i=1}^{j} φ^i + γ*(j/m periodic)
        /// We use the simplified closed-form from Hyndman et al (2008), §6.5.
        func confidenceInterval(stepsAhead: Int, zScore: Double = 1.96) -> Double {
            let h = Double(stepsAhead)
            guard h > 0 else { return 0 }

            // Accumulate variance multiplier using the ETS(A,Ad,M) variance propagation
            // Variance at horizon h: σ² * Σ_{j=0}^{h-1} (1 + j*α)² (simplified for additive errors)
            // For multiplicative seasonality, scale by seasonal index uncertainty
            var cumulativeVariance = 0.0
            let alpha = min(0.3, max(0.01, 1.0 - pow(0.95, 1.0 / max(1, residualStdDev))))
            let beta = alpha * 0.1 // Typical β/α ratio
            let phi = dampingFactor

            for j in 0..<Int(h) {
                var c_j = 1.0 + Double(j) * alpha
                // Add damped trend contribution
                if phi < 1.0 && phi > 0 {
                    let phiSum = phi * (1.0 - pow(phi, Double(j + 1))) / (1.0 - phi)
                    c_j += alpha * beta * phiSum
                }
                cumulativeVariance += c_j * c_j
            }

            let predictionStdDev = residualStdDev * cumulativeVariance.squareRoot()
            return zScore * predictionStdDev
        }

        /// Cumulative damped trend: sum_{i=1}^{h} phi^i * trend
        func dampedTrendCumulative(horizon h: Int) -> Double {
            guard dampingFactor != 1.0 else {
                return trend * Double(h)
            }
            // Geometric series: phi * (1 - phi^h) / (1 - phi) * trend
            let phi = dampingFactor
            let phiSum = phi * (1.0 - pow(phi, Double(h))) / (1.0 - phi)
            return phiSum * trend
        }
    }

    /// Multi-horizon forecast result
    struct MultiHorizonForecast {
        let metric: HealthMetric
        let horizons: [HorizonResult]

        struct HorizonResult {
            let horizon: Int            // days ahead
            let value: Double           // point forecast
            let ciLower: Double         // lower bound of confidence interval
            let ciUpper: Double         // upper bound of confidence interval
            let ciWidth: Double         // total CI width
        }
    }

    /// Fourier decomposition result
    struct FourierDecomposition {
        let mean: Double
        let coefficients: [PeriodCoefficients]
        let residuals: [Double]
        let varianceExplained: Double

        struct PeriodCoefficients {
            let period: Int
            let harmonics: [(a: Double, b: Double)] // cosine and sine coefficients per harmonic
            let amplitude: [Double]                   // amplitude per harmonic
            let phase: [Double]                       // phase per harmonic (radians)
        }
    }

    /// Learned state per metric
    private var states: [HealthMetric: HoltWintersState] = [:]

    /// Residuals for anomaly scoring
    private var recentResiduals: [HealthMetric: [Double]] = [:]

    /// Last full retrain date -- guards against expensive grid search too frequently
    private var lastRetrainDate: Date?

    /// Whether a full retrain is needed (never trained, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Training

    /// Fit Holt-Winters model for each metric with sufficient data
    func fit(timeSeries: [HealthMetric: MetricTimeSeries]) {
        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }

            let useDoubleSeasonal = values.count >= Self.monthlyMinimumDays
            let bestState = gridSearchFit(values: values, doubleSeasonal: useDoubleSeasonal)
            states[metric] = bestState
        }

        lastRetrainDate = Date()
    }

    /// Fit a single metric
    func fit(metric: HealthMetric, values: [Double]) {
        guard values.count >= Self.minimumDays else { return }
        let useDoubleSeasonal = values.count >= Self.monthlyMinimumDays
        states[metric] = gridSearchFit(values: values, doubleSeasonal: useDoubleSeasonal)
    }

    /// Incremental update with one new observation
    func update(metric: HealthMetric, newValue: Double, dayOfWeek: Int) {
        guard var state = states[metric] else { return }

        let weeklyIndex = dayOfWeek % Self.weeklyPeriod
        let oldWeeklySeasonal = state.seasonal[weeklyIndex]

        guard oldWeeklySeasonal != 0, newValue.isFinite else { return }

        // Track residual before updating
        let predicted = state.forecast(stepsAhead: 1)
        let residual = newValue - predicted

        // Determine monthly seasonal factor for deseasonalizing
        let monthlyFactor: Double
        if let monthly = state.monthlySeasonals {
            let monthlyIndex = state.fittedCount % Self.monthlyPeriod
            monthlyFactor = monthly[monthlyIndex]
        } else {
            monthlyFactor = 1.0
        }

        // Double-seasonal Holt-Winters multiplicative update
        let combinedSeasonal = oldWeeklySeasonal * monthlyFactor
        guard combinedSeasonal != 0 else { return }

        let newLevel = state.alpha * (newValue / combinedSeasonal) +
                       (1 - state.alpha) * (state.level + state.dampingFactor * state.trend)
        guard newLevel.isFinite, newLevel != 0 else { return }

        let newTrend = state.beta * (newLevel - state.level) +
                       (1 - state.beta) * state.dampingFactor * state.trend
        guard newTrend.isFinite else { return }

        let newWeeklySeasonal = state.gamma * (newValue / (newLevel * monthlyFactor)) +
                                (1 - state.gamma) * oldWeeklySeasonal
        guard newWeeklySeasonal.isFinite else { return }

        state.level = newLevel
        state.trend = newTrend
        state.seasonal[weeklyIndex] = newWeeklySeasonal

        // Update monthly seasonal if active
        if var monthly = state.monthlySeasonals, let g2 = state.gamma2 {
            let monthlyIndex = state.fittedCount % Self.monthlyPeriod
            let newMonthlySeasonal = g2 * (newValue / (newLevel * newWeeklySeasonal)) +
                                     (1 - g2) * monthly[monthlyIndex]
            if newMonthlySeasonal.isFinite {
                monthly[monthlyIndex] = newMonthlySeasonal
                state.monthlySeasonals = monthly
            }
        }

        state.fittedCount += 1

        // Update residual std dev with exponential smoothing
        let residualAlpha = 0.1
        state.residualStdDev = (1 - residualAlpha) * state.residualStdDev +
                                residualAlpha * abs(residual)

        states[metric] = state

        // Track recent residuals for anomaly detection
        var residuals = recentResiduals[metric] ?? []
        residuals.append(residual)
        if residuals.count > 90 { residuals.removeFirst(residuals.count - 90) }
        recentResiduals[metric] = residuals
    }

    // MARK: - Forecasting

    /// Get forecast for a metric N steps ahead
    func forecast(metric: HealthMetric, stepsAhead: Int = 1) -> (value: Double, ci: Double)? {
        guard let state = states[metric] else { return nil }
        let value = state.forecast(stepsAhead: stepsAhead)
        let ci = state.confidenceInterval(stepsAhead: stepsAhead)
        return (value, ci)
    }

    /// Multi-horizon forecast with per-horizon confidence intervals
    func forecast(metric: HealthMetric, horizons: [Int] = [1, 3, 7]) -> MultiHorizonForecast? {
        guard let state = states[metric] else { return nil }

        let results = horizons.map { h -> MultiHorizonForecast.HorizonResult in
            let value = state.forecast(stepsAhead: h)
            let ciWidth = state.confidenceInterval(stepsAhead: h)
            return MultiHorizonForecast.HorizonResult(
                horizon: h,
                value: value,
                ciLower: value - ciWidth,
                ciUpper: value + ciWidth,
                ciWidth: ciWidth * 2
            )
        }

        return MultiHorizonForecast(metric: metric, horizons: results)
    }

    // MARK: - Fourier Seasonal Decomposition

    /// Fit a Fourier seasonal decomposition model.
    ///
    /// Model: y(t) = mu + sum_k sum_j [a_kj * cos(2*pi*j*t / P_k) + b_kj * sin(2*pi*j*t / P_k)]
    ///
    /// Solves via OLS using normal equations (X'X)^{-1} X'y.
    ///
    /// - Parameters:
    ///   - values: Time series values
    ///   - periods: Seasonal periods to decompose (default: [7, 30])
    ///   - harmonics: Number of harmonics per period (default: 3)
    /// - Returns: Decomposition result with coefficients, residuals, and variance explained
    func fourierDecompose(
        values: [Double],
        periods: [Int] = [7, 30],
        harmonics: Int = 3
    ) -> FourierDecomposition? {
        let n = values.count
        guard n > 0 else { return nil }

        // Total number of Fourier terms: 2 * harmonics per period (cos + sin) + 1 for intercept
        let numFourierTerms = periods.count * harmonics * 2
        let numParams = 1 + numFourierTerms  // intercept + Fourier terms

        guard n > numParams else { return nil } // Need more data than parameters

        // Build design matrix X (n x numParams), row-major
        var designMatrix = [Double](repeating: 0, count: n * numParams)

        for t in 0..<n {
            // Intercept
            designMatrix[t * numParams + 0] = 1.0

            var col = 1
            for period in periods {
                let pDouble = Double(period)
                for j in 1...harmonics {
                    let angle = 2.0 * .pi * Double(j) * Double(t) / pDouble
                    designMatrix[t * numParams + col] = cos(angle)
                    col += 1
                    designMatrix[t * numParams + col] = sin(angle)
                    col += 1
                }
            }
        }

        // Solve via normal equations: (X'X) beta = X'y
        // X'X is (numParams x numParams)
        let XtX = AccelerateML.matrixMultiply(
            A: transposeRowMajor(designMatrix, rows: n, cols: numParams),
            B: designMatrix,
            rows: numParams, cols: n, n: numParams
        )
        guard !XtX.isEmpty else { return nil }

        // X'y is (numParams x 1)
        let Xt = transposeRowMajor(designMatrix, rows: n, cols: numParams)
        let XtY = AccelerateML.matVecMultiply(matrix: Xt, vector: values, rows: numParams, cols: n)
        guard XtY.count == numParams else { return nil }

        // Solve (X'X) beta = X'y
        // Add small ridge regularization for numerical stability
        var XtXReg = XtX
        for i in 0..<numParams {
            XtXReg[i * numParams + i] += 1e-8
        }

        guard let beta = AccelerateML.solveLinearSystem(A: XtXReg, b: XtY, n: numParams) else {
            return nil
        }

        // Compute fitted values and residuals
        let fitted = AccelerateML.matVecMultiply(matrix: designMatrix, vector: beta, rows: n, cols: numParams)
        let residuals = AccelerateML.subtract(values, fitted)

        // Variance explained
        let totalVariance = AccelerateML.sumOfSquares(
            AccelerateML.scalarAdd(values, -AccelerateML.mean(values))
        )
        let residualVariance = AccelerateML.sumOfSquares(residuals)
        let varianceExplained = totalVariance > 0 ? 1.0 - residualVariance / totalVariance : 0.0

        // Parse coefficients into structured form
        let meanCoeff = beta[0]
        var periodCoefficients: [FourierDecomposition.PeriodCoefficients] = []

        var idx = 1
        for period in periods {
            var harmonicPairs: [(a: Double, b: Double)] = []
            var amplitudes: [Double] = []
            var phases: [Double] = []

            for _ in 1...harmonics {
                let a = beta[idx]
                let b = beta[idx + 1]
                harmonicPairs.append((a: a, b: b))
                amplitudes.append((a * a + b * b).squareRoot())
                phases.append(atan2(b, a))
                idx += 2
            }

            periodCoefficients.append(FourierDecomposition.PeriodCoefficients(
                period: period,
                harmonics: harmonicPairs,
                amplitude: amplitudes,
                phase: phases
            ))
        }

        return FourierDecomposition(
            mean: meanCoeff,
            coefficients: periodCoefficients,
            residuals: residuals,
            varianceExplained: varianceExplained
        )
    }

    // MARK: - Anomaly Detection

    /// A forecast-based anomaly result
    struct ForecastAnomaly {
        let metric: HealthMetric
        let currentValue: Double
        let predictedValue: Double
        let residual: Double
        let normalizedResidual: Double // residual / CI
        let severity: Severity
        let deviationPercent: Double
    }

    /// Detect anomalies based on forecast residuals (smarter than static z-score)
    func detectAnomalies(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [ForecastAnomaly] {
        var results: [ForecastAnomaly] = []

        for (metric, series) in timeSeries {
            guard let state = states[metric],
                  let latest = series.sortedSamples.last else { continue }

            let predicted = state.forecast(stepsAhead: 1)
            let residual = latest.value - predicted
            let ci = state.confidenceInterval(stepsAhead: 1)

            guard ci > 0 else { continue }

            let normalizedResidual = abs(residual) / ci

            let severity: Severity
            if normalizedResidual > 2.5 {
                severity = .critical
            } else if normalizedResidual > 1.5 {
                severity = .warning
            } else {
                continue // Not anomalous
            }

            let deviationPercent = predicted != 0 ? (residual / predicted) * 100 : residual * 100

            results.append(ForecastAnomaly(
                metric: metric,
                currentValue: latest.value,
                predictedValue: predicted,
                residual: residual,
                normalizedResidual: normalizedResidual,
                severity: severity,
                deviationPercent: deviationPercent
            ))
        }

        return results
    }

    // MARK: - Persistence

    /// Whether the forecaster is ready
    var isReady: Bool { !states.isEmpty }

    /// Get serializable state for persistence
    func getState() -> [String: HoltWintersState] {
        Dictionary(uniqueKeysWithValues: states.map { ($0.key.rawValue, $0.value) })
    }

    /// Restore from persisted state
    func restoreState(_ saved: [String: HoltWintersState]) {
        for (rawValue, state) in saved {
            if let metric = HealthMetric(rawValue: rawValue) {
                states[metric] = state
            }
        }
    }

    // MARK: - Private: Grid Search Fit

    /// Expanded grid search with damping and double-seasonal support.
    /// Uses MAE for robustness to outliers.
    private func gridSearchFit(values: [Double], doubleSeasonal: Bool) -> HoltWintersState {
        let alphas = [0.05, 0.1, 0.2, 0.3, 0.5]
        let betas = [0.005, 0.01, 0.05, 0.1]
        let gamma1s = [0.05, 0.1, 0.3, 0.5]
        let phis = [0.8, 0.9, 0.98, 1.0]
        let gamma2s: [Double] = doubleSeasonal ? [0.05, 0.1, 0.3] : [0.0] // 0.0 = no monthly

        var bestState: HoltWintersState?
        var bestMAE = Double.infinity

        for alpha in alphas {
            for beta in betas {
                for gamma1 in gamma1s {
                    for phi in phis {
                        for gamma2 in gamma2s {
                            let useMonthly = doubleSeasonal && gamma2 > 0
                            let state = fitWithParams(
                                values: values,
                                alpha: alpha, beta: beta,
                                gamma1: gamma1, gamma2: useMonthly ? gamma2 : nil,
                                phi: phi,
                                doubleSeasonal: useMonthly
                            )
                            let mae = computeMAE(
                                values: values, state: state,
                                doubleSeasonal: useMonthly
                            )
                            if mae < bestMAE {
                                bestMAE = mae
                                bestState = state
                            }
                        }
                    }
                }
            }
        }

        return bestState ?? initializeState(values: values, doubleSeasonal: doubleSeasonal)
    }

    /// Fit model with specific parameters (supports both single and double seasonal)
    private func fitWithParams(
        values: [Double],
        alpha: Double, beta: Double,
        gamma1: Double, gamma2: Double?,
        phi: Double,
        doubleSeasonal: Bool
    ) -> HoltWintersState {
        let wP = Self.weeklyPeriod
        let mP = Self.monthlyPeriod

        var state = initializeState(values: values, doubleSeasonal: doubleSeasonal)
        state.alpha = alpha
        state.beta = beta
        state.gamma = gamma1
        state.gamma2 = gamma2
        state.dampingFactor = phi

        var residuals: [Double] = []

        // Start index: need at least one full weekly period; for double-seasonal, need monthly period
        let startIndex = doubleSeasonal ? mP : wP

        for i in startIndex..<values.count {
            let weeklyIdx = i % wP
            let observed = values[i]
            let oldWeekly = state.seasonal[weeklyIdx]

            guard oldWeekly != 0 else { continue }

            // Get monthly seasonal factor
            let oldMonthly: Double
            if doubleSeasonal, let monthly = state.monthlySeasonals {
                let monthlyIdx = i % mP
                oldMonthly = monthly[monthlyIdx]
            } else {
                oldMonthly = 1.0
            }

            let combinedSeasonal = oldWeekly * oldMonthly
            guard combinedSeasonal != 0 else { continue }

            // Predicted value
            let predicted = (state.level + phi * state.trend) * combinedSeasonal
            residuals.append(observed - predicted)

            // Level update: deseasonalize observation
            let newLevel = alpha * (observed / combinedSeasonal) +
                           (1 - alpha) * (state.level + phi * state.trend)

            // Trend update with damping
            let newTrend = beta * (newLevel - state.level) +
                           (1 - beta) * phi * state.trend

            // Weekly seasonal update
            let weeklyDenom = newLevel * oldMonthly
            let newWeekly: Double
            if abs(weeklyDenom) > 0.001 {
                newWeekly = gamma1 * (observed / weeklyDenom) + (1 - gamma1) * oldWeekly
            } else {
                newWeekly = oldWeekly
            }

            // Monthly seasonal update
            if doubleSeasonal, var monthly = state.monthlySeasonals, let g2 = gamma2 {
                let monthlyIdx = i % mP
                let monthlyDenom = newLevel * newWeekly
                if abs(monthlyDenom) > 0.001 {
                    let newMonthly = g2 * (observed / monthlyDenom) + (1 - g2) * monthly[monthlyIdx]
                    if newMonthly.isFinite {
                        monthly[monthlyIdx] = newMonthly
                    }
                }
                state.monthlySeasonals = monthly
            }

            state.level = newLevel
            state.trend = newTrend
            state.seasonal[weeklyIdx] = newWeekly
        }

        state.fittedCount = values.count
        if !residuals.isEmpty {
            let (_, variance) = AccelerateML.welfordVariance(residuals)
            state.residualStdDev = variance.squareRoot()
        }

        // Optionally compute Fourier coefficients for interpretability
        if values.count >= Self.monthlyMinimumDays {
            let periods = doubleSeasonal ? [Self.weeklyPeriod, Self.monthlyPeriod] : [Self.weeklyPeriod]
            if let decomp = fourierDecompose(values: values, periods: periods, harmonics: 3) {
                var allCoeffs: [[Double]] = []
                for pc in decomp.coefficients {
                    var flat: [Double] = []
                    for h in pc.harmonics {
                        flat.append(h.a)
                        flat.append(h.b)
                    }
                    allCoeffs.append(flat)
                }
                state.fourierCoefficients = allCoeffs
            }
        }

        return state
    }

    /// Initialize state with sensible defaults for both single and double seasonal
    private func initializeState(values: [Double], doubleSeasonal: Bool) -> HoltWintersState {
        let wP = Self.weeklyPeriod
        let mP = Self.monthlyPeriod

        // Initial level: mean of first weekly period
        let firstPeriod = Array(values.prefix(wP))
        let level = AccelerateML.mean(firstPeriod)

        // Initial trend: average difference between first two weekly periods
        var trend = 0.0
        if values.count >= 2 * wP {
            let secondPeriod = Array(values[wP..<(2 * wP)])
            let secondMean = AccelerateML.mean(secondPeriod)
            trend = (secondMean - level) / Double(wP)
        }

        // Initial weekly seasonal factors: ratio of each position to period mean
        var weeklySeasonal = [Double](repeating: 1.0, count: wP)
        if level > 0 {
            // Average seasonal factors over all complete weeks
            let completeWeeks = values.count / wP
            if completeWeeks >= 1 {
                for dayOfWeek in 0..<wP {
                    var daySum = 0.0
                    var dayCount = 0
                    for week in 0..<completeWeeks {
                        let idx = week * wP + dayOfWeek
                        if idx < values.count {
                            daySum += values[idx]
                            dayCount += 1
                        }
                    }
                    if dayCount > 0 {
                        let weekMean = daySum / Double(dayCount)
                        weeklySeasonal[dayOfWeek] = weekMean / level
                    }
                }
            } else {
                for i in 0..<wP where i < values.count {
                    weeklySeasonal[i] = values[i] / level
                }
            }
        }

        // Initial monthly seasonal factors
        var monthlySeasonals: [Double]?
        var gamma2: Double?
        if doubleSeasonal && values.count >= mP {
            var monthly = [Double](repeating: 1.0, count: mP)
            if level > 0 {
                let completeMonths = values.count / mP
                if completeMonths >= 1 {
                    for dayOfMonth in 0..<mP {
                        var daySum = 0.0
                        var dayCount = 0
                        for month in 0..<completeMonths {
                            let idx = month * mP + dayOfMonth
                            if idx < values.count {
                                daySum += values[idx]
                                dayCount += 1
                            }
                        }
                        if dayCount > 0 {
                            let monthMean = daySum / Double(dayCount)
                            // Deseasonalize by weekly factor first
                            let weeklyFactor = weeklySeasonal[dayOfMonth % wP]
                            if weeklyFactor > 0 {
                                monthly[dayOfMonth] = (monthMean / level) / weeklyFactor
                            }
                        }
                    }
                }
            }
            // Normalize monthly factors so their mean is 1.0
            let monthlyMean = AccelerateML.mean(monthly)
            if monthlyMean > 0 {
                monthly = monthly.map { $0 / monthlyMean }
            }
            monthlySeasonals = monthly
            gamma2 = 0.1 // default, will be overridden by grid search
        }

        return HoltWintersState(
            level: level,
            trend: trend,
            seasonal: weeklySeasonal,
            alpha: 0.2,
            beta: 0.05,
            gamma: 0.3,
            residualStdDev: values.standardDeviation * 0.3,
            fittedCount: 0,
            monthlySeasonals: monthlySeasonals,
            dampingFactor: 1.0,
            gamma2: gamma2,
            fourierCoefficients: nil
        )
    }

    /// Compute Mean Absolute Error for model evaluation (robust to outliers)
    private func computeMAE(values: [Double], state: HoltWintersState, doubleSeasonal: Bool) -> Double {
        let wP = Self.weeklyPeriod
        let mP = Self.monthlyPeriod
        let startIndex = doubleSeasonal ? mP : wP

        var currentState = state
        var totalAbsError = 0.0
        var count = 0

        for i in startIndex..<values.count {
            let weeklyIdx = i % wP
            let weeklySeasonal = currentState.seasonal[weeklyIdx]

            let monthlySeasonal: Double
            if doubleSeasonal, let monthly = currentState.monthlySeasonals {
                monthlySeasonal = monthly[i % mP]
            } else {
                monthlySeasonal = 1.0
            }

            let predicted = (currentState.level + currentState.dampingFactor * currentState.trend) *
                            weeklySeasonal * monthlySeasonal
            let error = abs(values[i] - predicted)
            totalAbsError += error
            count += 1

            // Update state forward
            let oldWeekly = currentState.seasonal[weeklyIdx]
            let combinedSeasonal = oldWeekly * monthlySeasonal
            guard abs(combinedSeasonal) > 0.001 else { continue }

            let newLevel = currentState.alpha * (values[i] / combinedSeasonal) +
                          (1 - currentState.alpha) * (currentState.level + currentState.dampingFactor * currentState.trend)
            let newTrend = currentState.beta * (newLevel - currentState.level) +
                          (1 - currentState.beta) * currentState.dampingFactor * currentState.trend

            let weeklyDenom = newLevel * monthlySeasonal
            if abs(weeklyDenom) > 0.001 {
                let newWeekly = currentState.gamma * (values[i] / weeklyDenom) +
                               (1 - currentState.gamma) * oldWeekly
                currentState.seasonal[weeklyIdx] = newWeekly
            }

            if doubleSeasonal, var monthly = currentState.monthlySeasonals, let g2 = currentState.gamma2 {
                let monthlyIdx = i % mP
                let monthlyDenom = newLevel * currentState.seasonal[weeklyIdx]
                if abs(monthlyDenom) > 0.001 {
                    let newMonthly = g2 * (values[i] / monthlyDenom) + (1 - g2) * monthly[monthlyIdx]
                    if newMonthly.isFinite {
                        monthly[monthlyIdx] = newMonthly
                    }
                }
                currentState.monthlySeasonals = monthly
            }

            currentState.level = newLevel
            currentState.trend = newTrend
        }

        guard count > 0 else { return Double.infinity }
        return totalAbsError / Double(count)
    }

    // MARK: - Private: Matrix Helpers

    /// Transpose a row-major matrix (rows x cols) -> (cols x rows)
    private func transposeRowMajor(_ matrix: [Double], rows: Int, cols: Int) -> [Double] {
        guard matrix.count >= rows * cols else { return [] }
        var result = [Double](repeating: 0, count: rows * cols)
        for i in 0..<rows {
            for j in 0..<cols {
                result[j * rows + i] = matrix[i * cols + j]
            }
        }
        return result
    }
}
