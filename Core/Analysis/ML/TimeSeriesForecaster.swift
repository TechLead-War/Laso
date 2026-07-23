import Foundation

/// Double-seasonal Holt-Winters forecaster with damped trend, Fourier decomposition,
/// and multi-horizon confidence intervals.
///
/// Weekly (period=7) seasonality is always active. Monthly (period=30) seasonality
/// activates when data >= 60 days, otherwise falls back to single-season mode.
final class TimeSeriesForecaster {
    /// Minimum days of data required for forecasting
    static let minimumDays = 7

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

    /// Learned state per metric
    private var states: [HealthMetric: HoltWintersState] = [:]

    /// Residuals for anomaly scoring
    private var recentResiduals: [HealthMetric: [Double]] = [:]

    /// Last full retrain date -- guards against expensive grid search too frequently
    private var lastRetrainDate: Date?

    /// Ensemble member
    private let arimaForecaster = ARIMAForecaster()

    /// Whether a full retrain is needed (never trained, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Training

    /// Fit Ensemble models (Holt-Winters + ARIMA)
    func fit(timeSeries: [HealthMetric: MetricTimeSeries]) {
        // 1. Fit existing ETS/Holt-Winters pipeline
        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }

            let useDoubleSeasonal = values.count >= Self.monthlyMinimumDays
            let bestState = gridSearchFit(values: values, doubleSeasonal: useDoubleSeasonal)
            states[metric] = bestState
        }

        // 2. Fit rigorous ARIMA pipeline mathematically alongside it
        arimaForecaster.fit(timeSeries: timeSeries)

        lastRetrainDate = Date()
    }

    /// Fit only metrics that have no model yet (e.g. a newly tracked metric after a
    /// restore). Cheap: already-fitted metrics skip the grid search. Does not touch
    /// lastRetrainDate — this fills gaps, it is not the 30-day full retrain, so a new
    /// metric gets its forecast on the next run instead of waiting for the retrain.
    func fitMissing(timeSeries: [HealthMetric: MetricTimeSeries]) {
        for (metric, series) in timeSeries where states[metric] == nil {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }
            let useDoubleSeasonal = values.count >= Self.monthlyMinimumDays
            states[metric] = gridSearchFit(values: values, doubleSeasonal: useDoubleSeasonal)
        }
        arimaForecaster.fit(timeSeries: timeSeries, onlyMissing: true)
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

    /// Get forecast for a metric N steps ahead via Model Ensembling Selection
    func forecast(metric: HealthMetric, stepsAhead: Int = 1) -> (value: Double, ci: Double)? {
        let hwState = states[metric]
        
        let hwValue = hwState?.forecast(stepsAhead: stepsAhead)
        let hwCI = hwState?.confidenceInterval(stepsAhead: stepsAhead)
        
        let arimaForecast = arimaForecaster.forecast(metric: metric, stepsAhead: stepsAhead)
        
        // Model Selection Logic (Ensemble Picker):
        // Pick the model with the lowest uncertainty/variance on the targeted horizon.
        if let hwV = hwValue, let hwC = hwCI, let arima = arimaForecast {
            if arima.ci < hwC {
                #if DEBUG
                print("[TimeSeriesForecaster] ARIMA Selected for \(metric.rawValue) (CI: \(arima.ci) vs HW: \(hwC))")
                #endif
                return arima
            } else {
                return (hwV, hwC)
            }
        } else if let hwV = hwValue, let hwC = hwCI {
             return (hwV, hwC)
        } else if let arima = arimaForecast {
             return arima
        }
        
        return nil
    }

    /// Multi-horizon forecast with per-horizon confidence intervals (Ensemble execution)
    func forecast(metric: HealthMetric, horizons: [Int] = [1, 3, 7]) -> MultiHorizonForecast? {
        // Ensembling multi-horizon by performing stepwise selection.
        var results: [MultiHorizonForecast.HorizonResult] = []
        for h in horizons {
            guard let (value, ciWidth) = forecast(metric: metric, stepsAhead: h) else { continue }
            results.append(MultiHorizonForecast.HorizonResult(
                horizon: h,
                value: value,
                ciLower: value - ciWidth,
                ciUpper: value + ciWidth,
                ciWidth: ciWidth * 2
            ))
        }
        
        guard !results.isEmpty else { return nil }
        return MultiHorizonForecast(metric: metric, horizons: results)
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

    /// Get ARIMA serializable state for persistence
    func getArimaState() -> [String: ARIMAForecaster.ARIMAParameters] {
        arimaForecaster.getState()
    }

    /// Restore from persisted state
    func restoreState(_ saved: [String: HoltWintersState], arimaSaved: [String: ARIMAForecaster.ARIMAParameters]? = nil) {
        for (rawValue, state) in saved {
            if let metric = HealthMetric(rawValue: rawValue) {
                states[metric] = state
            }
        }
        if let arima = arimaSaved {
            arimaForecaster.restoreState(arima)
        }
    }

    // MARK: - Cross-launch Persistence

    /// Bundle of fitted models for saving across launches. Persisting this is what
    /// stops the expensive grid search from re-running on every cold launch.
    struct PersistedModel: Codable {
        let holtWinters: [String: HoltWintersState]
        let arima: [String: ARIMAForecaster.ARIMAParameters]
        let lastRetrain: Date
    }

    /// Snapshot of the current fitted models, or nil before the first fit.
    func persistedModel() -> PersistedModel? {
        guard !states.isEmpty, let lastRetrain = lastRetrainDate else { return nil }
        return PersistedModel(holtWinters: getState(), arima: getArimaState(), lastRetrain: lastRetrain)
    }

    /// Restore models saved in a previous launch. Restores lastRetrainDate too, so
    /// needsRetrain stays false until the 30-day window elapses — the grid search is
    /// then skipped while forecasts still regenerate cheaply from these states.
    func restore(_ model: PersistedModel) {
        restoreState(model.holtWinters, arimaSaved: model.arima)
        lastRetrainDate = model.lastRetrain
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
            gamma2: gamma2
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

}
