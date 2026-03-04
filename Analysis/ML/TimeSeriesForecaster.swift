import Foundation

/// Holt-Winters triple exponential smoothing forecaster with multiplicative weekly seasonality.
/// Predicts expected metric values; anomaly = significant deviation from forecast.
final class TimeSeriesForecaster {
    /// Minimum days of data required for forecasting
    static let minimumDays = 21

    /// Seasonal period (weekly)
    private static let seasonalPeriod = 7

    // MARK: - Model Parameters (per metric)

    struct HoltWintersState: Codable {
        var level: Double
        var trend: Double
        var seasonal: [Double] // length = seasonalPeriod (7)
        var alpha: Double      // level smoothing
        var beta: Double       // trend smoothing
        var gamma: Double      // seasonal smoothing
        var residualStdDev: Double
        var fittedCount: Int

        /// One-step-ahead forecast
        func forecast(stepsAhead: Int = 1) -> Double {
            let seasonIndex = stepsAhead % seasonal.count
            return (level + trend * Double(stepsAhead)) * seasonal[seasonIndex]
        }

        /// Confidence interval width at given horizon
        func confidenceInterval(stepsAhead: Int, zScore: Double = 1.96) -> Double {
            zScore * residualStdDev * Double(stepsAhead).squareRoot()
        }
    }

    /// Learned state per metric
    private var states: [HealthMetric: HoltWintersState] = [:]

    /// Residuals for anomaly scoring
    private var recentResiduals: [HealthMetric: [Double]] = [:]

    /// Last full retrain date — guards against expensive grid search too frequently
    private var lastRetrainDate: Date?

    /// Whether a full retrain is needed (never trained, or >30 days since last)
    var needsRetrain: Bool {
        guard let lastRetrain = lastRetrainDate else { return true }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    // MARK: - Training

    /// Fit Holt-Winters model for each metric with sufficient data
    func fit(timeSeries: [HealthMetric: MetricTimeSeries]) {
        let period = Self.seasonalPeriod

        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            guard values.count >= Self.minimumDays else { continue }

            // Grid search for best smoothing parameters
            let bestState = gridSearchFit(values: values, period: period)
            states[metric] = bestState
        }

        lastRetrainDate = Date()
    }

    /// Fit a single metric
    func fit(metric: HealthMetric, values: [Double]) {
        guard values.count >= Self.minimumDays else { return }
        states[metric] = gridSearchFit(values: values, period: Self.seasonalPeriod)
    }

    /// Incremental update with one new observation
    func update(metric: HealthMetric, newValue: Double, dayOfWeek: Int) {
        guard var state = states[metric] else { return }

        let seasonIndex = dayOfWeek % Self.seasonalPeriod
        let oldSeasonal = state.seasonal[seasonIndex]

        // Holt-Winters multiplicative update
        guard oldSeasonal != 0 else { return }
        let newLevel = state.alpha * (newValue / oldSeasonal) +
                       (1 - state.alpha) * (state.level + state.trend)
        let newTrend = state.beta * (newLevel - state.level) +
                       (1 - state.beta) * state.trend
        let newSeasonal = state.gamma * (newValue / newLevel) +
                          (1 - state.gamma) * oldSeasonal

        // Track residual
        let predicted = state.forecast(stepsAhead: 1)
        let residual = newValue - predicted

        state.level = newLevel
        state.trend = newTrend
        state.seasonal[seasonIndex] = newSeasonal
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

    private func gridSearchFit(values: [Double], period: Int) -> HoltWintersState {
        let alphas = [0.1, 0.3, 0.5]
        let betas = [0.01, 0.1, 0.2]
        let gammas = [0.1, 0.5]

        var bestState: HoltWintersState?
        var bestSSE = Double.infinity

        for alpha in alphas {
            for beta in betas {
                for gamma in gammas {
                    let state = fitWithParams(values: values, period: period,
                                              alpha: alpha, beta: beta, gamma: gamma)
                    let sse = computeSSE(values: values, state: state, period: period)
                    if sse < bestSSE {
                        bestSSE = sse
                        bestState = state
                    }
                }
            }
        }

        return bestState ?? initializeState(values: values, period: period)
    }

    private func fitWithParams(
        values: [Double], period: Int,
        alpha: Double, beta: Double, gamma: Double
    ) -> HoltWintersState {
        var state = initializeState(values: values, period: period)
        state.alpha = alpha
        state.beta = beta
        state.gamma = gamma

        var residuals: [Double] = []

        // Run through data to fit
        for i in period..<values.count {
            let seasonIndex = i % period
            let observed = values[i]
            let oldSeasonal = state.seasonal[seasonIndex]
            guard oldSeasonal != 0 else { continue }

            let predicted = (state.level + state.trend) * oldSeasonal
            residuals.append(observed - predicted)

            let newLevel = alpha * (observed / oldSeasonal) + (1 - alpha) * (state.level + state.trend)
            let newTrend = beta * (newLevel - state.level) + (1 - beta) * state.trend
            let newSeasonal = gamma * (observed / max(newLevel, 0.001)) + (1 - gamma) * oldSeasonal

            state.level = newLevel
            state.trend = newTrend
            state.seasonal[seasonIndex] = newSeasonal
        }

        state.fittedCount = values.count
        if !residuals.isEmpty {
            let (_, variance) = AccelerateML.welfordVariance(residuals)
            state.residualStdDev = variance.squareRoot()
        }

        return state
    }

    private func initializeState(values: [Double], period: Int) -> HoltWintersState {
        // Initial level: mean of first period
        let firstPeriod = Array(values.prefix(period))
        let level = AccelerateML.mean(firstPeriod)

        // Initial trend: average difference between first two periods
        var trend = 0.0
        if values.count >= 2 * period {
            let secondPeriod = Array(values[period..<(2 * period)])
            let secondMean = AccelerateML.mean(secondPeriod)
            trend = (secondMean - level) / Double(period)
        }

        // Initial seasonal factors: ratio of each position to period mean
        var seasonal = [Double](repeating: 1.0, count: period)
        if level > 0 {
            for i in 0..<period where i < values.count {
                seasonal[i] = values[i] / level
            }
        }

        return HoltWintersState(
            level: level,
            trend: trend,
            seasonal: seasonal,
            alpha: 0.2,
            beta: 0.05,
            gamma: 0.3,
            residualStdDev: values.standardDeviation * 0.3,
            fittedCount: 0
        )
    }

    private func computeSSE(values: [Double], state: HoltWintersState, period: Int) -> Double {
        var currentState = state
        var sse = 0.0

        for i in period..<values.count {
            let seasonIndex = i % period
            let predicted = (currentState.level + currentState.trend) * currentState.seasonal[seasonIndex]
            let error = values[i] - predicted
            sse += error * error

            let oldSeasonal = currentState.seasonal[seasonIndex]
            guard oldSeasonal != 0 else { continue }

            let newLevel = currentState.alpha * (values[i] / oldSeasonal) +
                          (1 - currentState.alpha) * (currentState.level + currentState.trend)
            let newTrend = currentState.beta * (newLevel - currentState.level) +
                          (1 - currentState.beta) * currentState.trend
            let newSeasonal = currentState.gamma * (values[i] / max(newLevel, 0.001)) +
                             (1 - currentState.gamma) * oldSeasonal

            currentState.level = newLevel
            currentState.trend = newTrend
            currentState.seasonal[seasonIndex] = newSeasonal
        }

        return sse
    }
}
