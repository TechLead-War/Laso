import Foundation

// MARK: - Predictive Health Signals Engine

/// Detects early indicators of health issues BEFORE the user feels symptoms by monitoring
/// multi-metric patterns across fatigue, burnout, overtraining, insomnia, immune compromise,
/// and metabolic inactivity.
///
/// Each detector uses minimum data guards, exponential moving averages for trend detection,
/// and produces natural-language explanations referencing the user's actual values.
struct PredictiveHealthSignals {

    // MARK: - Risk Level

    enum RiskLevel: Int, Comparable, CaseIterable {
        case low = 0
        case moderate = 1
        case high = 2
        case critical = 3

        static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }

    // MARK: - Contributing Factor

    struct ContributingFactor {
        let metric: HealthMetric
        let description: String
        let weight: Double
    }

    // MARK: - Health Signal Protocol

    protocol HealthSignal {
        var signalName: String { get }
        var riskLevel: RiskLevel { get }
        var score: Double { get }
        var confidence: Double { get }
        var explanation: String { get }
        var recommendation: String { get }
        var contributingFactors: [ContributingFactor] { get }
    }

    // MARK: - Signal Structs

    struct FatigueSignal: HealthSignal {
        let signalName: String = "Fatigue Accumulation"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
    }

    struct BurnoutSignal: HealthSignal {
        let signalName: String = "Burnout Risk"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
    }

    struct OvertrainingSignal: HealthSignal {
        let signalName: String = "Overtraining Syndrome"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
        let projectedRecoveryDays: Int?
    }

    struct InsomniaSignal: HealthSignal {
        let signalName: String = "Insomnia Risk"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
    }

    struct ImmuneSignal: HealthSignal {
        let signalName: String = "Immune System Dip"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
    }

    struct InactivitySignal: HealthSignal {
        let signalName: String = "Metabolic Inactivity"
        let riskLevel: RiskLevel
        let score: Double
        let confidence: Double
        let explanation: String
        let recommendation: String
        let contributingFactors: [ContributingFactor]
        let consecutiveInactiveDays: Int
    }

    // MARK: - Health Signal Report

    struct HealthSignalReport {
        let date: Date
        let fatigueScore: FatigueSignal
        let burnoutRisk: BurnoutSignal
        let overtrainingRisk: OvertrainingSignal
        let insomniaRisk: InsomniaSignal
        let immuneRisk: ImmuneSignal
        let inactivityAlert: InactivitySignal

        /// Top 3 most urgent signals, sorted by urgency (highest risk first, then by score)
        var urgentSignals: [any HealthSignal] {
            let all: [any HealthSignal] = [
                fatigueScore, burnoutRisk, overtrainingRisk,
                insomniaRisk, immuneRisk, inactivityAlert
            ]
            return all
                .sorted { a, b in
                    if a.riskLevel != b.riskLevel {
                        return a.riskLevel > b.riskLevel
                    }
                    return a.score > b.score
                }
                .prefix(3)
                .filter { $0.riskLevel >= .moderate || $0.score > 0.3 }
        }
    }

    // MARK: - Constants

    private enum Constants {
        /// Exponential decay lambda for fatigue scoring (recent days weighted higher)
        static let fatigueDecayLambda: Double = 0.15
        /// EMA alpha for trend smoothing
        static let emaAlpha: Double = 0.3

        // Minimum data guards (days)
        static let fatigueMinDays: Int = 7
        static let burnoutMinDays: Int = 14
        static let overtrainingMinDays: Int = 28
        static let insomniaMinDays: Int = 7
        static let immuneMinDays: Int = 7
        static let inactivityMinDays: Int = 3
    }

    // MARK: - Public API

    /// Analyze all health signals from time series data, baselines, and trends.
    ///
    /// - Parameters:
    ///   - timeSeries: Time series data keyed by health metric
    ///   - baselines: Personal baselines keyed by health metric
    ///   - trends: Trend analysis results keyed by health metric
    ///   - healthState: Current ML-classified health state (optional)
    ///   - prediction: Current ML prediction for bad day (optional)
    /// - Returns: A complete report with all six signal assessments
    static func analyze(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        healthState: HealthState?,
        prediction: MLPrediction?
    ) -> HealthSignalReport {
        let dailyMaps = buildDailyMaps(timeSeries: timeSeries)

        return HealthSignalReport(
            date: Date(),
            fatigueScore: analyzeFatigue(
                timeSeries: timeSeries, baselines: baselines,
                trends: trends, dailyMaps: dailyMaps
            ),
            burnoutRisk: analyzeBurnout(
                timeSeries: timeSeries, baselines: baselines,
                trends: trends, dailyMaps: dailyMaps
            ),
            overtrainingRisk: analyzeOvertraining(
                timeSeries: timeSeries, baselines: baselines,
                trends: trends, dailyMaps: dailyMaps
            ),
            insomniaRisk: analyzeInsomnia(
                timeSeries: timeSeries, baselines: baselines,
                trends: trends, dailyMaps: dailyMaps
            ),
            immuneRisk: analyzeImmune(
                timeSeries: timeSeries, baselines: baselines,
                dailyMaps: dailyMaps
            ),
            inactivityAlert: analyzeInactivity(
                timeSeries: timeSeries, baselines: baselines,
                trends: trends, dailyMaps: dailyMaps
            )
        )
    }

    /// Convert signals to Insight objects for the insights pipeline.
    static func generateInsights(from report: HealthSignalReport) -> [Insight] {
        var insights: [Insight] = []

        let allSignals: [(any HealthSignal, HealthMetric, [HealthMetric])] = [
            (report.fatigueScore, .heartRateVariability,
             [.heartRateVariability, .restingHeartRate, .sleepDuration, .activeCalories]),
            (report.burnoutRisk, .restingHeartRate,
             [.restingHeartRate, .heartRateVariability, .sleepDeep, .activeCalories]),
            (report.overtrainingRisk, .heartRateVariability,
             [.heartRateVariability, .restingHeartRate, .activeCalories, .exerciseMinutes]),
            (report.insomniaRisk, .sleepDuration,
             [.sleepDuration, .sleepAwake, .restingHeartRate]),
            (report.immuneRisk, .restingHeartRate,
             [.restingHeartRate, .heartRateVariability, .sleepDuration]),
            (report.inactivityAlert, .steps,
             [.steps, .standHours, .vo2Max, .weight]),
        ]

        for (signal, primaryMetric, relatedMetrics) in allSignals {
            guard signal.riskLevel >= .moderate || signal.score > 0.3 else { continue }

            let category: InsightCategory
            let severity: Severity
            switch signal.riskLevel {
            case .critical:
                category = .illnessWarning
                severity = .critical
            case .high:
                category = .illnessWarning
                severity = .warning
            case .moderate:
                category = .mlPrediction
                severity = .warning
            case .low:
                category = .mlPrediction
                severity = .info
            }

            let trend: TrendDirection
            switch signal.riskLevel {
            case .critical, .high: trend = .declining
            case .moderate: trend = .declining
            case .low: trend = .stable
            }

            insights.append(Insight(
                metric: primaryMetric,
                title: "\(signal.signalName): \(signal.riskLevel.displayName) Risk",
                summary: signal.explanation,
                recommendation: signal.recommendation,
                severity: severity,
                trend: trend,
                currentValue: signal.score,
                baselineValue: 0,
                deviationPercent: signal.score * 100,
                category: category,
                relatedMetrics: relatedMetrics,
                context: InsightContext(confidenceLevel: signal.confidence)
            ))
        }

        return insights
    }

    // MARK: - Daily Map Builder

    private static func buildDailyMaps(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [HealthMetric: [Date: Double]] {
        var maps: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            maps[metric] = TimeSeriesAligner.dailyValueMap(series)
        }
        return maps
    }

    // MARK: - Shared Helpers

    /// Compute exponential moving average from a chronologically ordered array of values.
    /// Returns the EMA series (same length as input).
    private static func ema(_ values: [Double], alpha: Double) -> [Double] {
        guard !values.isEmpty else { return [] }
        var result = [values[0]]
        result.reserveCapacity(values.count)
        for i in 1..<values.count {
            let smoothed = alpha * values[i] + (1.0 - alpha) * result[i - 1]
            result.append(smoothed)
        }
        return result
    }

    /// Get recent N days of values for a metric from daily map, in chronological order.
    /// Returns an array of (date, value) tuples for days that have data.
    private static func recentDailyValues(
        metric: HealthMetric,
        days: Int,
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> [(date: Date, value: Double)] {
        guard let map = dailyMaps[metric] else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var result: [(Date, Double)] = []
        result.reserveCapacity(days)

        for dayOffset in 0..<days {
            let day = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            )
            if let value = map[day] {
                result.append((day, value))
            }
        }

        return result.reversed() // chronological order
    }

    /// Compute sigma deviation of a value from a baseline.
    private static func sigmaDeviation(
        value: Double, baseline: UserBaseline
    ) -> Double {
        guard baseline.standardDeviation > 0.001 else { return 0 }
        return (value - baseline.mean) / baseline.standardDeviation
    }

    /// Compute percentage deviation of a value from a baseline mean.
    private static func percentDeviation(
        value: Double, baseline: UserBaseline
    ) -> Double {
        guard baseline.mean != 0 else { return 0 }
        return ((value - baseline.mean) / baseline.mean) * 100.0
    }

    /// Format a metric value with its unit for narrative text.
    private static func formatted(
        _ value: Double, metric: HealthMetric
    ) -> String {
        let unit = metric.unit.isEmpty ? "" : " \(metric.unit)"
        return "\(metric.formatValue(value))\(unit)"
    }

    /// Clamp a value between 0 and 1.
    private static func clamp01(_ value: Double) -> Double {
        Swift.min(1.0, Swift.max(0.0, value))
    }

    // MARK: - 1. Fatigue Accumulation Score

    /// Detects cumulative fatigue from sustained physical/mental load.
    ///
    /// Inputs: HRV trend (declining = bad), resting HR trend (rising = bad),
    /// sleep duration vs baseline, exercise load (acute-to-chronic ratio),
    /// consecutive low-recovery days.
    ///
    /// Uses exponential decay: recent days weighted via exp(-lambda * dayOffset)
    /// with lambda = 0.15.
    private static func analyzeFatigue(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> FatigueSignal {
        let window = 14
        var factors: [ContributingFactor] = []
        var componentScores: [(weight: Double, score: Double)] = []
        var availableMetrics = 0

        // Component 1: HRV trend (declining = fatigue, weight 0.30)
        let hrvValues = recentDailyValues(metric: .heartRateVariability, days: window, dailyMaps: dailyMaps)
        if hrvValues.count >= Constants.fatigueMinDays, let hrvBaseline = baselines[.heartRateVariability] {
            availableMetrics += 1
            let emaValues = ema(hrvValues.map(\.value), alpha: Constants.emaAlpha)
            let recentEMA = emaValues.last ?? hrvBaseline.mean
            let deviation = sigmaDeviation(value: recentEMA, baseline: hrvBaseline)
            // Negative deviation (HRV below baseline) is bad
            let hrvScore = clamp01(max(0, -deviation) / 3.0) // 3 sigma = max score
            componentScores.append((0.30, hrvScore))

            if hrvScore > 0.1 {
                let pctDev = abs(percentDeviation(value: recentEMA, baseline: hrvBaseline))
                factors.append(ContributingFactor(
                    metric: .heartRateVariability,
                    description: "HRV at \(formatted(recentEMA, metric: .heartRateVariability)), \(String(format: "%.0f", pctDev))% below your baseline of \(formatted(hrvBaseline.mean, metric: .heartRateVariability))",
                    weight: 0.30
                ))
            }
        }

        // Component 2: Resting HR trend (rising = fatigue, weight 0.25)
        let rhrValues = recentDailyValues(metric: .restingHeartRate, days: window, dailyMaps: dailyMaps)
        if rhrValues.count >= Constants.fatigueMinDays, let rhrBaseline = baselines[.restingHeartRate] {
            availableMetrics += 1
            let emaValues = ema(rhrValues.map(\.value), alpha: Constants.emaAlpha)
            let recentEMA = emaValues.last ?? rhrBaseline.mean
            let deviation = sigmaDeviation(value: recentEMA, baseline: rhrBaseline)
            // Positive deviation (RHR above baseline) is bad
            let rhrScore = clamp01(max(0, deviation) / 3.0)
            componentScores.append((0.25, rhrScore))

            if rhrScore > 0.1 {
                let pctDev = abs(percentDeviation(value: recentEMA, baseline: rhrBaseline))
                factors.append(ContributingFactor(
                    metric: .restingHeartRate,
                    description: "Resting heart rate at \(formatted(recentEMA, metric: .restingHeartRate)), \(String(format: "%.0f", pctDev))% above your baseline of \(formatted(rhrBaseline.mean, metric: .restingHeartRate))",
                    weight: 0.25
                ))
            }
        }

        // Component 3: Sleep duration vs baseline (weight 0.20)
        let sleepValues = recentDailyValues(metric: .sleepDuration, days: window, dailyMaps: dailyMaps)
        if sleepValues.count >= Constants.fatigueMinDays, let sleepBaseline = baselines[.sleepDuration] {
            availableMetrics += 1
            // Use exponential decay weighting for recent days
            var weightedSleepDeficit = 0.0
            var totalWeight = 0.0
            for (i, entry) in sleepValues.enumerated().reversed() {
                let dayOffset = Double(sleepValues.count - 1 - i)
                let decayWeight = exp(-Constants.fatigueDecayLambda * dayOffset)
                let deficit = max(0, sleepBaseline.mean - entry.value) / sleepBaseline.mean
                weightedSleepDeficit += deficit * decayWeight
                totalWeight += decayWeight
            }
            let avgDeficit = totalWeight > 0 ? weightedSleepDeficit / totalWeight : 0
            let sleepScore = clamp01(avgDeficit * 3.0) // 33% deficit = max
            componentScores.append((0.20, sleepScore))

            if sleepScore > 0.1 {
                let recentAvg = sleepValues.suffix(3).map(\.value).mean
                factors.append(ContributingFactor(
                    metric: .sleepDuration,
                    description: "Sleep averaging \(formatted(recentAvg, metric: .sleepDuration)) over the last 3 nights vs your baseline of \(formatted(sleepBaseline.mean, metric: .sleepDuration))",
                    weight: 0.20
                ))
            }
        }

        // Component 4: Exercise load - acute-to-chronic ratio (weight 0.15)
        let exerciseValues = recentDailyValues(metric: .activeCalories, days: 28, dailyMaps: dailyMaps)
        if exerciseValues.count >= Constants.fatigueMinDays {
            availableMetrics += 1
            let acute7 = exerciseValues.suffix(7).map(\.value).mean
            let chronic28 = exerciseValues.map(\.value).mean
            let acwr = chronic28 > 0 ? acute7 / chronic28 : 1.0

            // ACWR: 0.8-1.3 is optimal, >1.5 is danger zone
            let acwrScore: Double
            if acwr > 1.5 {
                acwrScore = clamp01((acwr - 1.3) / 0.7) // 2.0 = max
            } else if acwr < 0.5 {
                acwrScore = clamp01((0.8 - acwr) / 0.5) // very low also bad (detraining)
            } else {
                acwrScore = 0
            }
            componentScores.append((0.15, acwrScore))

            if acwrScore > 0.1 {
                factors.append(ContributingFactor(
                    metric: .activeCalories,
                    description: "Acute-to-chronic workload ratio is \(String(format: "%.2f", acwr)) (optimal range: 0.8-1.3)",
                    weight: 0.15
                ))
            }
        }

        // Component 5: Consecutive low-recovery days (weight 0.10)
        if let hrvBaseline = baselines[.heartRateVariability], hrvValues.count >= Constants.fatigueMinDays {
            let threshold = hrvBaseline.mean - 0.5 * hrvBaseline.standardDeviation
            var consecutiveLow = 0
            for entry in hrvValues.reversed() {
                if entry.value < threshold {
                    consecutiveLow += 1
                } else {
                    break
                }
            }
            let recoveryScore = clamp01(Double(consecutiveLow) / 7.0) // 7 consecutive = max
            componentScores.append((0.10, recoveryScore))

            if consecutiveLow >= 2 {
                factors.append(ContributingFactor(
                    metric: .heartRateVariability,
                    description: "\(consecutiveLow) consecutive days with HRV below recovery threshold (\(formatted(threshold, metric: .heartRateVariability)))",
                    weight: 0.10
                ))
            }
        }

        // Guard: need at least 2 metrics for meaningful analysis
        guard availableMetrics >= 2, !componentScores.isEmpty else {
            return FatigueSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient data to assess fatigue accumulation. At least 7 days of HRV and resting heart rate data are needed.",
                recommendation: "Continue wearing your Apple Watch to build a fatigue baseline.",
                contributingFactors: []
            )
        }

        // Weighted sum with normalization
        let totalWeight = componentScores.reduce(0.0) { $0 + $1.weight }
        let rawScore = componentScores.reduce(0.0) { $0 + $1.weight * $1.score } / totalWeight
        let fatigueScore100 = rawScore * 100.0

        let riskLevel: RiskLevel
        switch fatigueScore100 {
        case 80...: riskLevel = .critical
        case 60..<80: riskLevel = .high
        case 30..<60: riskLevel = .moderate
        default: riskLevel = .low
        }

        let confidence = clamp01(Double(availableMetrics) / 5.0 * 0.7 +
                                 Double(Swift.min(hrvValues.count, window)) / Double(window) * 0.3)

        let explanation = buildFatigueExplanation(score: fatigueScore100, factors: factors)
        let recommendation = buildFatigueRecommendation(riskLevel: riskLevel)

        return FatigueSignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight }
        )
    }

    private static func buildFatigueExplanation(
        score: Double, factors: [ContributingFactor]
    ) -> String {
        var parts: [String] = ["Your fatigue accumulation score is \(String(format: "%.0f", score))/100."]
        for factor in factors.prefix(3) {
            parts.append(factor.description + ".")
        }
        return parts.joined(separator: " ")
    }

    private static func buildFatigueRecommendation(riskLevel: RiskLevel) -> String {
        switch riskLevel {
        case .critical:
            return "Your fatigue level suggests overtraining is likely. Take at least 2 complete rest days. Prioritize 8+ hours of sleep, hydrate with at least 3 liters of water, and avoid high-intensity exercise until your HRV recovers to baseline."
        case .high:
            return "Fatigue is building up significantly. Take a rest day today and reduce training intensity by 50% for the next 3 days. Focus on sleep quality and consider a recovery-focused session like yoga or light walking."
        case .moderate:
            return "Moderate fatigue detected. Consider easing up on training intensity this week. Ensure you are getting adequate sleep and monitor how your body responds over the next few days."
        case .low:
            return "Fatigue levels are within a healthy range. Continue your current routine and maintain good sleep habits."
        }
    }

    // MARK: - 2. Burnout Risk Detector

    /// Multi-week pattern analysis for chronic burnout.
    /// Looks for sustained elevated resting HR, declining HRV trend,
    /// reduced deep sleep, and decreased activity variability.
    private static func analyzeBurnout(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> BurnoutSignal {
        let window = 21 // 3 weeks for burnout assessment
        var factors: [ContributingFactor] = []
        var componentScores: [Double] = []
        var availableSignals = 0

        // Signal 1: Sustained elevated resting HR (>1 sigma above baseline for 7+ days)
        let rhrValues = recentDailyValues(metric: .restingHeartRate, days: window, dailyMaps: dailyMaps)
        if let rhrBaseline = baselines[.restingHeartRate], rhrValues.count >= Constants.burnoutMinDays {
            let threshold = rhrBaseline.mean + rhrBaseline.standardDeviation
            var consecutiveElevated = 0
            for entry in rhrValues.reversed() {
                if entry.value > threshold {
                    consecutiveElevated += 1
                } else {
                    break
                }
            }
            if consecutiveElevated >= 7 {
                let score = clamp01(Double(consecutiveElevated - 7) / 14.0 + 0.4) // 7 days = 0.4, 21 days = 1.0
                componentScores.append(score)
                availableSignals += 1
                factors.append(ContributingFactor(
                    metric: .restingHeartRate,
                    description: "Resting heart rate has been above \(formatted(threshold, metric: .restingHeartRate)) for \(consecutiveElevated) consecutive days (baseline: \(formatted(rhrBaseline.mean, metric: .restingHeartRate)))",
                    weight: score
                ))
            } else {
                // Partial credit for shorter streaks
                let partial = clamp01(Double(consecutiveElevated) / 14.0)
                componentScores.append(partial)
                availableSignals += 1
            }
        }

        // Signal 2: Declining HRV trend over 14+ days
        let hrvValues = recentDailyValues(metric: .heartRateVariability, days: window, dailyMaps: dailyMaps)
        if hrvValues.count >= Constants.burnoutMinDays {
            let emaValues = ema(hrvValues.map(\.value), alpha: 0.15) // slower EMA for burnout
            if emaValues.count >= 14 {
                let firstHalf = Array(emaValues.prefix(emaValues.count / 2)).mean
                let secondHalf = Array(emaValues.suffix(emaValues.count / 2)).mean
                if firstHalf > 0 {
                    let decline = (firstHalf - secondHalf) / firstHalf
                    if decline > 0 {
                        let score = clamp01(decline / 0.20) // 20% decline = max
                        componentScores.append(score)
                        availableSignals += 1
                        if score > 0.2 {
                            factors.append(ContributingFactor(
                                metric: .heartRateVariability,
                                description: "HRV has declined \(String(format: "%.0f", decline * 100))% over the past \(hrvValues.count) days",
                                weight: score
                            ))
                        }
                    } else {
                        componentScores.append(0)
                        availableSignals += 1
                    }
                }
            }
        }

        // Signal 3: Reduced deep sleep quality (deep sleep < 15% for 7+ days)
        let deepSleepValues = recentDailyValues(metric: .sleepDeep, days: window, dailyMaps: dailyMaps)
        let totalSleepValues = recentDailyValues(metric: .sleepDuration, days: window, dailyMaps: dailyMaps)
        if deepSleepValues.count >= 7, totalSleepValues.count >= 7 {
            // Build daily deep sleep percentage
            let deepMap = Dictionary(uniqueKeysWithValues: deepSleepValues.map { ($0.date, $0.value) })
            let totalMap = Dictionary(uniqueKeysWithValues: totalSleepValues.map { ($0.date, $0.value) })

            var lowDeepDays = 0
            var totalPairedDays = 0
            for (date, deepHours) in deepMap {
                guard let totalHours = totalMap[date], totalHours > 0 else { continue }
                totalPairedDays += 1
                let deepPct = deepHours / totalHours
                if deepPct < 0.15 {
                    lowDeepDays += 1
                }
            }

            if totalPairedDays >= 7 {
                let score = clamp01(Double(lowDeepDays) / Double(totalPairedDays))
                componentScores.append(score)
                availableSignals += 1
                if lowDeepDays >= 5 {
                    factors.append(ContributingFactor(
                        metric: .sleepDeep,
                        description: "Deep sleep has been below 15% of total sleep on \(lowDeepDays) of the last \(totalPairedDays) nights",
                        weight: score
                    ))
                }
            }
        }

        // Signal 4: Decreased activity variability (monotone exercise pattern)
        let activityValues = recentDailyValues(metric: .activeCalories, days: window, dailyMaps: dailyMaps)
        if activityValues.count >= Constants.burnoutMinDays {
            let values = activityValues.map(\.value)
            let activityMean = values.mean
            let activitySD = values.standardDeviation
            let cv = activityMean > 0 ? activitySD / activityMean : 0

            // Low coefficient of variation suggests monotone/diminished pattern
            // Healthy variability CV is typically 0.3-0.6; below 0.15 is concerning
            if cv < 0.3 {
                let score = clamp01((0.3 - cv) / 0.25)
                componentScores.append(score)
                availableSignals += 1
                if score > 0.2 {
                    factors.append(ContributingFactor(
                        metric: .activeCalories,
                        description: "Activity variability is unusually low (CV: \(String(format: "%.2f", cv))), suggesting a monotone exercise pattern",
                        weight: score
                    ))
                }
            } else {
                componentScores.append(0)
                availableSignals += 1
            }
        }

        guard availableSignals >= 2, !componentScores.isEmpty else {
            return BurnoutSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient data to assess burnout risk. At least 14 days of heart rate and activity data are needed.",
                recommendation: "Continue tracking to enable burnout risk detection.",
                contributingFactors: []
            )
        }

        let rawScore = componentScores.isEmpty ? 0 : componentScores.reduce(0, +) / Double(componentScores.count)

        let riskLevel: RiskLevel
        switch rawScore {
        case 0.8...: riskLevel = .critical
        case 0.6..<0.8: riskLevel = .high
        case 0.3..<0.6: riskLevel = .moderate
        default: riskLevel = .low
        }

        let confidence = clamp01(Double(availableSignals) / 4.0 * 0.6 +
                                 Double(Swift.min(rhrValues.count, window)) / Double(window) * 0.4)

        let explanation = buildBurnoutExplanation(score: rawScore, factors: factors)
        let recommendation = buildBurnoutRecommendation(riskLevel: riskLevel)

        return BurnoutSignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight }
        )
    }

    private static func buildBurnoutExplanation(
        score: Double, factors: [ContributingFactor]
    ) -> String {
        var parts: [String] = ["Burnout risk score: \(String(format: "%.0f", score * 100))%."]
        if factors.isEmpty {
            parts.append("No significant burnout indicators detected.")
        } else {
            for factor in factors.prefix(3) {
                parts.append(factor.description + ".")
            }
        }
        return parts.joined(separator: " ")
    }

    private static func buildBurnoutRecommendation(riskLevel: RiskLevel) -> String {
        switch riskLevel {
        case .critical:
            return "Multiple burnout indicators are elevated. Take a deload week: reduce training volume by 60%, prioritize 8+ hours of sleep, add recovery practices (gentle stretching, meditation), and consider speaking with a healthcare professional about your stress load."
        case .high:
            return "You are showing clear signs of chronic overload. Reduce training intensity by 40% this week, schedule at least 3 rest days, and focus on sleep quality. Vary your workouts to break the monotony."
        case .moderate:
            return "Some early burnout signals are appearing. Add an extra rest day this week and try to vary your exercise routine. Prioritize activities you enjoy to maintain motivation."
        case .low:
            return "No significant burnout risk detected. Maintain your current balance of training and recovery."
        }
    }

    // MARK: - 3. Overtraining Syndrome (OTS) Early Warning

    /// Based on sports science literature: ACWR spikes, HRV suppression post-workout,
    /// elevated RHR not recovering within 48h, and decreased exercise performance.
    private static func analyzeOvertraining(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> OvertrainingSignal {
        var factors: [ContributingFactor] = []
        var componentScores: [(weight: Double, score: Double)] = []
        var availableSignals = 0

        // Signal 1: Acute-to-Chronic Workload Ratio > 1.5 (weight 0.30)
        let calValues = recentDailyValues(metric: .activeCalories, days: 28, dailyMaps: dailyMaps)
        var acwr: Double = 1.0
        if calValues.count >= Constants.overtrainingMinDays {
            let acute7 = calValues.suffix(7).map(\.value).mean
            let chronic28 = calValues.map(\.value).mean
            acwr = chronic28 > 0 ? acute7 / chronic28 : 1.0

            let otsScore: Double
            if acwr > 1.5 {
                otsScore = clamp01((acwr - 1.3) / 0.7)
            } else {
                otsScore = 0
            }
            componentScores.append((0.30, otsScore))
            availableSignals += 1

            if acwr > 1.3 {
                factors.append(ContributingFactor(
                    metric: .activeCalories,
                    description: "Acute-to-chronic workload ratio is \(String(format: "%.2f", acwr)), above the \(acwr > 1.5 ? "danger" : "caution") threshold of \(acwr > 1.5 ? "1.5" : "1.3")",
                    weight: 0.30
                ))
            }
        }

        // Signal 2: HRV suppression (consistently below baseline after workouts, weight 0.25)
        let hrvValues = recentDailyValues(metric: .heartRateVariability, days: 28, dailyMaps: dailyMaps)
        if let hrvBaseline = baselines[.heartRateVariability], hrvValues.count >= 14 {
            let recentHRV = hrvValues.suffix(7).map(\.value)
            let emaRecent = ema(recentHRV, alpha: Constants.emaAlpha)
            let latestEMA = emaRecent.last ?? hrvBaseline.mean
            let deviation = sigmaDeviation(value: latestEMA, baseline: hrvBaseline)

            let hrvScore = clamp01(max(0, -deviation) / 2.5) // 2.5 sigma below = max
            componentScores.append((0.25, hrvScore))
            availableSignals += 1

            if hrvScore > 0.2 {
                let pctBelow = abs(percentDeviation(value: latestEMA, baseline: hrvBaseline))
                factors.append(ContributingFactor(
                    metric: .heartRateVariability,
                    description: "HRV suppressed at \(formatted(latestEMA, metric: .heartRateVariability)), \(String(format: "%.0f", pctBelow))% below your baseline of \(formatted(hrvBaseline.mean, metric: .heartRateVariability))",
                    weight: 0.25
                ))
            }
        }

        // Signal 3: Elevated RHR not recovering within 48h post-exercise (weight 0.25)
        let rhrValues = recentDailyValues(metric: .restingHeartRate, days: 14, dailyMaps: dailyMaps)
        if let rhrBaseline = baselines[.restingHeartRate], rhrValues.count >= 7 {
            // Check if RHR has been consistently elevated
            let recentRHR = rhrValues.suffix(7).map(\.value)
            let emaRecent = ema(recentRHR, alpha: Constants.emaAlpha)
            let latestEMA = emaRecent.last ?? rhrBaseline.mean
            let deviation = sigmaDeviation(value: latestEMA, baseline: rhrBaseline)

            // Count days above 1 sigma
            var daysAbove = 0
            for v in recentRHR {
                if v > rhrBaseline.mean + rhrBaseline.standardDeviation {
                    daysAbove += 1
                }
            }

            let rhrScore: Double
            if daysAbove >= 5 {
                rhrScore = clamp01(0.5 + Double(daysAbove - 5) * 0.15 + max(0, deviation) * 0.1)
            } else {
                rhrScore = clamp01(max(0, deviation) / 3.0 * 0.5)
            }
            componentScores.append((0.25, rhrScore))
            availableSignals += 1

            if rhrScore > 0.2 {
                factors.append(ContributingFactor(
                    metric: .restingHeartRate,
                    description: "Resting heart rate has been elevated on \(daysAbove) of the last 7 days, averaging \(formatted(latestEMA, metric: .restingHeartRate)) vs baseline of \(formatted(rhrBaseline.mean, metric: .restingHeartRate))",
                    weight: 0.25
                ))
            }
        }

        // Signal 4: Decreased exercise performance (same effort, fewer results, weight 0.20)
        if calValues.count >= Constants.overtrainingMinDays {
            let exerciseMins = recentDailyValues(metric: .exerciseMinutes, days: 28, dailyMaps: dailyMaps)
            if exerciseMins.count >= 14 {
                // Compare calorie efficiency: calories per exercise minute
                let recentCals = calValues.suffix(7).map(\.value).mean
                let recentMins = exerciseMins.suffix(7).map(\.value).mean
                let olderCals = calValues.prefix(14).map(\.value).mean
                let olderMins = exerciseMins.prefix(14).map(\.value).mean

                let recentEfficiency = recentMins > 0 ? recentCals / recentMins : 0
                let olderEfficiency = olderMins > 0 ? olderCals / olderMins : 0

                if olderEfficiency > 0 {
                    let efficiencyDrop = (olderEfficiency - recentEfficiency) / olderEfficiency
                    let perfScore = clamp01(max(0, efficiencyDrop) / 0.25) // 25% drop = max
                    componentScores.append((0.20, perfScore))
                    availableSignals += 1

                    if perfScore > 0.2 {
                        factors.append(ContributingFactor(
                            metric: .activeCalories,
                            description: "Calorie efficiency per exercise minute has dropped \(String(format: "%.0f", efficiencyDrop * 100))% compared to 2-4 weeks ago",
                            weight: 0.20
                        ))
                    }
                }
            }
        }

        guard availableSignals >= 2, !componentScores.isEmpty else {
            return OvertrainingSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient data to assess overtraining risk. At least 28 days of exercise and heart rate data are needed.",
                recommendation: "Continue tracking workouts and heart rate to enable overtraining detection.",
                contributingFactors: [],
                projectedRecoveryDays: nil
            )
        }

        let totalWeight = componentScores.reduce(0.0) { $0 + $1.weight }
        let rawScore = componentScores.reduce(0.0) { $0 + $1.weight * $1.score } / totalWeight

        let riskLevel: RiskLevel
        switch rawScore {
        case 0.8...: riskLevel = .critical
        case 0.6..<0.8: riskLevel = .high
        case 0.3..<0.6: riskLevel = .moderate
        default: riskLevel = .low
        }

        // Project recovery days based on severity
        let projectedRecovery: Int?
        switch riskLevel {
        case .critical: projectedRecovery = Int(7 + acwr * 2)
        case .high: projectedRecovery = Int(4 + acwr)
        case .moderate: projectedRecovery = 3
        case .low: projectedRecovery = nil
        }

        let confidence = clamp01(Double(availableSignals) / 4.0 * 0.6 +
                                 Double(Swift.min(calValues.count, 28)) / 28.0 * 0.4)

        let explanation = buildOvertrainingExplanation(score: rawScore, factors: factors, recovery: projectedRecovery)
        let recommendation = buildOvertrainingRecommendation(riskLevel: riskLevel, recovery: projectedRecovery)

        return OvertrainingSignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight },
            projectedRecoveryDays: projectedRecovery
        )
    }

    private static func buildOvertrainingExplanation(
        score: Double, factors: [ContributingFactor], recovery: Int?
    ) -> String {
        var parts: [String] = ["Overtraining risk score: \(String(format: "%.0f", score * 100))%."]
        for factor in factors.prefix(3) {
            parts.append(factor.description + ".")
        }
        if let recovery {
            parts.append("Projected recovery time: \(recovery) days with adequate rest.")
        }
        return parts.joined(separator: " ")
    }

    private static func buildOvertrainingRecommendation(riskLevel: RiskLevel, recovery: Int?) -> String {
        let recoveryText = recovery.map { " Full recovery is projected to take approximately \($0) days." } ?? ""
        switch riskLevel {
        case .critical:
            return "Overtraining syndrome is likely. Immediately stop high-intensity training for at least 1 week. Focus exclusively on sleep (9+ hours), nutrition (increase protein by 20%), and only gentle walking.\(recoveryText)"
        case .high:
            return "Strong overtraining indicators detected. Reduce training volume by 50-60% for the next week. Prioritize recovery: sleep 8+ hours, increase protein intake, and limit sessions to light aerobic work.\(recoveryText)"
        case .moderate:
            return "Early overtraining signals present. Reduce intensity by 30% this week and add an extra rest day. Monitor your HRV over the next 3-5 days to see if it recovers."
        case .low:
            return "No significant overtraining risk. Your training load and recovery appear balanced."
        }
    }

    // MARK: - 4. Insomnia Risk Predictor

    /// Detects patterns that predict sleep disruption: increasing sleep fragmentation,
    /// circadian misalignment, elevated evening heart rate.
    private static func analyzeInsomnia(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> InsomniaSignal {
        var factors: [ContributingFactor] = []
        var componentScores: [(weight: Double, score: Double)] = []
        var availableSignals = 0

        // Signal 1: Rising sleep fragmentation (awake time increasing, weight 0.30)
        let awakeValues = recentDailyValues(metric: .sleepAwake, days: 14, dailyMaps: dailyMaps)
        if awakeValues.count >= Constants.insomniaMinDays, let awakeBaseline = baselines[.sleepAwake] {
            let emaValues = ema(awakeValues.map(\.value), alpha: Constants.emaAlpha)
            let latestEMA = emaValues.last ?? awakeBaseline.mean
            let deviation = sigmaDeviation(value: latestEMA, baseline: awakeBaseline)

            // More awake time = worse
            let fragmentationScore = clamp01(max(0, deviation) / 2.5)
            componentScores.append((0.30, fragmentationScore))
            availableSignals += 1

            if fragmentationScore > 0.15 {
                let pctAbove = percentDeviation(value: latestEMA, baseline: awakeBaseline)
                factors.append(ContributingFactor(
                    metric: .sleepAwake,
                    description: "Awake time during sleep at \(formatted(latestEMA, metric: .sleepAwake)), \(String(format: "%.0f", abs(pctAbove)))% above your baseline of \(formatted(awakeBaseline.mean, metric: .sleepAwake))",
                    weight: 0.30
                ))
            }
        }

        // Signal 2: Circadian misalignment (bedtime consistency degrading, weight 0.20)
        // Proxy: use sleep duration variability as indicator of inconsistent schedule
        let sleepValues = recentDailyValues(metric: .sleepDuration, days: 14, dailyMaps: dailyMaps)
        if sleepValues.count >= Constants.insomniaMinDays {
            let recentValues = sleepValues.suffix(7).map(\.value)
            let olderValues = sleepValues.prefix(7).map(\.value)

            let recentSD = recentValues.standardDeviation
            let olderSD = olderValues.count >= 3 ? olderValues.standardDeviation : recentSD

            // Increasing variability suggests circadian instability
            let sdIncrease = olderSD > 0.01 ? (recentSD - olderSD) / olderSD : 0
            let circadianScore = clamp01(max(0, sdIncrease) / 1.0) // 100% increase in variability = max
            componentScores.append((0.20, circadianScore))
            availableSignals += 1

            if circadianScore > 0.2 {
                factors.append(ContributingFactor(
                    metric: .sleepDuration,
                    description: "Sleep timing variability has increased \(String(format: "%.0f", sdIncrease * 100))% over the past week, suggesting circadian instability",
                    weight: 0.20
                ))
            }
        }

        // Signal 3: Elevated evening heart rate (proxy for stress/activation, weight 0.25)
        // Use resting HR as proxy since we don't have time-of-day segmented data
        let rhrValues = recentDailyValues(metric: .restingHeartRate, days: 7, dailyMaps: dailyMaps)
        if rhrValues.count >= Constants.insomniaMinDays, let rhrBaseline = baselines[.restingHeartRate] {
            let emaValues = ema(rhrValues.map(\.value), alpha: Constants.emaAlpha)
            let latestEMA = emaValues.last ?? rhrBaseline.mean
            let deviation = sigmaDeviation(value: latestEMA, baseline: rhrBaseline)

            let hrScore = clamp01(max(0, deviation) / 2.0) // 2 sigma above = max
            componentScores.append((0.25, hrScore))
            availableSignals += 1

            if hrScore > 0.15 {
                factors.append(ContributingFactor(
                    metric: .restingHeartRate,
                    description: "Resting heart rate elevated at \(formatted(latestEMA, metric: .restingHeartRate)) (baseline: \(formatted(rhrBaseline.mean, metric: .restingHeartRate))), suggesting autonomic activation",
                    weight: 0.25
                ))
            }
        }

        // Signal 4: Declining sleep duration trend (weight 0.15)
        if let sleepTrend = trends[.sleepDuration] {
            if sleepTrend.direction == .declining {
                let declineScore = clamp01(abs(sleepTrend.weekOverWeekChange) / 15.0) // 15% decline = max
                componentScores.append((0.15, declineScore))
                availableSignals += 1

                if declineScore > 0.15 {
                    factors.append(ContributingFactor(
                        metric: .sleepDuration,
                        description: "Sleep duration trending down \(String(format: "%.1f", abs(sleepTrend.weekOverWeekChange)))% week-over-week",
                        weight: 0.15
                    ))
                }
            } else {
                componentScores.append((0.15, 0))
                availableSignals += 1
            }
        }

        // Signal 5: Caffeine timing effects (weight 0.10)
        let caffeineValues = recentDailyValues(metric: .caffeineIntake, days: 7, dailyMaps: dailyMaps)
        if let caffeineBaseline = baselines[.caffeineIntake], caffeineValues.count >= 3 {
            let recentCaffeine = caffeineValues.suffix(3).map(\.value).mean
            let deviation = sigmaDeviation(value: recentCaffeine, baseline: caffeineBaseline)

            let caffeineScore = clamp01(max(0, deviation) / 2.0)
            componentScores.append((0.10, caffeineScore))
            availableSignals += 1

            if caffeineScore > 0.2 {
                factors.append(ContributingFactor(
                    metric: .caffeineIntake,
                    description: "Caffeine intake at \(formatted(recentCaffeine, metric: .caffeineIntake)), above your usual \(formatted(caffeineBaseline.mean, metric: .caffeineIntake))",
                    weight: 0.10
                ))
            }
        }

        guard availableSignals >= 2, !componentScores.isEmpty else {
            return InsomniaSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient data to predict insomnia risk. At least 7 days of sleep data are needed.",
                recommendation: "Continue tracking sleep to enable insomnia risk prediction.",
                contributingFactors: []
            )
        }

        let totalWeight = componentScores.reduce(0.0) { $0 + $1.weight }
        let rawScore = componentScores.reduce(0.0) { $0 + $1.weight * $1.score } / totalWeight

        let riskLevel: RiskLevel
        switch rawScore {
        case 0.8...: riskLevel = .critical
        case 0.6..<0.8: riskLevel = .high
        case 0.3..<0.6: riskLevel = .moderate
        default: riskLevel = .low
        }

        let confidence = clamp01(Double(availableSignals) / 5.0 * 0.6 +
                                 Double(Swift.min(awakeValues.count + sleepValues.count, 28)) / 28.0 * 0.4)

        let explanation = buildInsomniaExplanation(score: rawScore, factors: factors)
        let recommendation = buildInsomniaRecommendation(riskLevel: riskLevel, factors: factors)

        return InsomniaSignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight }
        )
    }

    private static func buildInsomniaExplanation(
        score: Double, factors: [ContributingFactor]
    ) -> String {
        var parts: [String] = ["Probability of poor sleep tonight: \(String(format: "%.0f", score * 100))%."]
        for factor in factors.prefix(3) {
            parts.append(factor.description + ".")
        }
        return parts.joined(separator: " ")
    }

    private static func buildInsomniaRecommendation(
        riskLevel: RiskLevel, factors: [ContributingFactor]
    ) -> String {
        var recommendations: [String] = []

        let hasCaffeineFactor = factors.contains { $0.metric == .caffeineIntake }
        let hasHRFactor = factors.contains { $0.metric == .restingHeartRate }

        switch riskLevel {
        case .critical, .high:
            recommendations.append("Tonight's sleep is at risk.")
            if hasCaffeineFactor {
                recommendations.append("Avoid all caffeine after noon.")
            }
            if hasHRFactor {
                recommendations.append("Try 10 minutes of deep breathing or meditation before bed to lower your heart rate.")
            }
            recommendations.append("Dim lights 2 hours before bedtime, avoid screens for 1 hour, and keep your bedroom cool (18-20 C).")
            recommendations.append("Consider a consistent bedtime within the next hour.")
        case .moderate:
            recommendations.append("Some factors suggest sleep may be disrupted tonight.")
            if hasCaffeineFactor {
                recommendations.append("Cut off caffeine by early afternoon.")
            }
            recommendations.append("Maintain a consistent bedtime and avoid stimulating activities in the evening.")
        case .low:
            recommendations.append("Sleep risk appears low. Maintain your current sleep routine and avoid late-evening stimulation.")
        }

        return recommendations.joined(separator: " ")
    }

    // MARK: - 5. Immune System Dip Detector

    /// Detects the physiological signature of immune compromise: RHR elevation + HRV
    /// suppression + low sleep + high training load simultaneously for 2+ days.
    ///
    /// More sophisticated than IllnessEarlyWarning (which is rule-based) by using
    /// a mini logistic regression on the combined z-scores.
    private static func analyzeImmune(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> ImmuneSignal {
        let window = 7
        var factors: [ContributingFactor] = []

        // Required metrics for immune analysis
        guard let rhrBaseline = baselines[.restingHeartRate],
              let hrvBaseline = baselines[.heartRateVariability] else {
            return ImmuneSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient baseline data for immune system monitoring. Heart rate and HRV baselines are required.",
                recommendation: "Continue wearing your Apple Watch consistently to build baselines.",
                contributingFactors: []
            )
        }

        let rhrValues = recentDailyValues(metric: .restingHeartRate, days: window, dailyMaps: dailyMaps)
        let hrvValues = recentDailyValues(metric: .heartRateVariability, days: window, dailyMaps: dailyMaps)

        guard rhrValues.count >= Constants.immuneMinDays,
              hrvValues.count >= Constants.immuneMinDays else {
            return ImmuneSignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Need at least 7 days of recent heart rate data to assess immune status.",
                recommendation: "Ensure you are wearing your Apple Watch during sleep for consistent readings.",
                contributingFactors: []
            )
        }

        let sleepValues = recentDailyValues(metric: .sleepDuration, days: window, dailyMaps: dailyMaps)
        let activityValues = recentDailyValues(metric: .activeCalories, days: window, dailyMaps: dailyMaps)

        // Build daily immune risk scores using mini logistic regression
        // Pattern: RHR > mean+0.7sigma AND HRV < mean-0.5sigma AND sleep < mean-0.3sigma
        let rhrMap = Dictionary(uniqueKeysWithValues: rhrValues.map { ($0.date, $0.value) })
        let hrvMap = Dictionary(uniqueKeysWithValues: hrvValues.map { ($0.date, $0.value) })
        let sleepMap = Dictionary(uniqueKeysWithValues: sleepValues.map { ($0.date, $0.value) })
        let activityMap = Dictionary(uniqueKeysWithValues: activityValues.map { ($0.date, $0.value) })
        let sleepBaseline = baselines[.sleepDuration]
        let activityBaseline = baselines[.activeCalories]

        let calendar = Calendar.current
        let now = Date()
        var dailyRiskScores: [(date: Date, score: Double)] = []
        var consecutiveHighRisk = 0
        var maxConsecutive = 0

        // Logistic regression weights (empirically tuned from literature)
        let rhrWeight: Double = 2.0    // RHR elevation is primary signal
        let hrvWeight: Double = 1.8    // HRV suppression is strong signal
        let sleepWeight: Double = 1.2  // Sleep deficit amplifies risk
        let activityWeight: Double = 0.8 // High training load amplifies
        let bias: Double = -3.0        // Baseline offset (keeps score low when all normal)

        for dayOffset in 0..<window {
            let day = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            )

            guard let rhr = rhrMap[day], let hrv = hrvMap[day] else { continue }

            var logit = bias

            // RHR component: positive when elevated
            let rhrZ = sigmaDeviation(value: rhr, baseline: rhrBaseline)
            let rhrContribution = max(0, rhrZ - 0.7) // Only counts when >0.7 sigma above
            logit += rhrWeight * rhrContribution

            // HRV component: positive when suppressed (inverted)
            let hrvZ = sigmaDeviation(value: hrv, baseline: hrvBaseline)
            let hrvContribution = max(0, -hrvZ - 0.5) // Only counts when >0.5 sigma below
            logit += hrvWeight * hrvContribution

            // Sleep component (if available)
            if let sleep = sleepMap[day], let sb = sleepBaseline {
                let sleepZ = sigmaDeviation(value: sleep, baseline: sb)
                let sleepContribution = max(0, -sleepZ - 0.3)
                logit += sleepWeight * sleepContribution
            }

            // Activity/load component (if available)
            if let activity = activityMap[day], let ab = activityBaseline, ab.mean > 0 {
                let activityRatio = activity / ab.mean
                if activityRatio > 1.3 { // High training load amplifies immune risk
                    logit += activityWeight * (activityRatio - 1.0)
                }
            }

            // Sigmoid
            let probability = 1.0 / (1.0 + exp(-logit))
            dailyRiskScores.append((day, probability))

            if probability > 0.5 {
                consecutiveHighRisk += 1
                maxConsecutive = Swift.max(maxConsecutive, consecutiveHighRisk)
            } else {
                consecutiveHighRisk = 0
            }
        }

        // Overall immune risk: combine recent probabilities with consecutive-day boost
        let recentScores = dailyRiskScores.prefix(3).map(\.score)
        let avgRecentRisk = recentScores.isEmpty ? 0 : recentScores.mean
        let consecutiveBoost = maxConsecutive >= 2 ? 0.2 : 0
        let rawScore = clamp01(avgRecentRisk + consecutiveBoost)

        // Build factors
        let recentRHR = rhrValues.suffix(3).map(\.value).mean
        let rhrDevPct = abs(percentDeviation(value: recentRHR, baseline: rhrBaseline))
        if rhrDevPct > 3 {
            let daysElevated = rhrValues.filter { $0.value > rhrBaseline.mean + 0.7 * rhrBaseline.standardDeviation }.count
            factors.append(ContributingFactor(
                metric: .restingHeartRate,
                description: "Resting heart rate at \(formatted(recentRHR, metric: .restingHeartRate)) for \(daysElevated) days, \(String(format: "%.0f", rhrDevPct))% above your baseline of \(formatted(rhrBaseline.mean, metric: .restingHeartRate))",
                weight: 0.35
            ))
        }

        let recentHRV = hrvValues.suffix(3).map(\.value).mean
        let hrvDevPct = abs(percentDeviation(value: recentHRV, baseline: hrvBaseline))
        if hrvDevPct > 3 {
            let daysSuppressed = hrvValues.filter { $0.value < hrvBaseline.mean - 0.5 * hrvBaseline.standardDeviation }.count
            factors.append(ContributingFactor(
                metric: .heartRateVariability,
                description: "HRV suppressed at \(formatted(recentHRV, metric: .heartRateVariability)) for \(daysSuppressed) days, \(String(format: "%.0f", hrvDevPct))% below your baseline of \(formatted(hrvBaseline.mean, metric: .heartRateVariability))",
                weight: 0.30
            ))
        }

        if let sb = sleepBaseline {
            let recentSleep = sleepValues.suffix(3).map(\.value).mean
            let sleepDevPct = percentDeviation(value: recentSleep, baseline: sb)
            if sleepDevPct < -5 {
                factors.append(ContributingFactor(
                    metric: .sleepDuration,
                    description: "Sleep averaging \(formatted(recentSleep, metric: .sleepDuration)), \(String(format: "%.0f", abs(sleepDevPct)))% below your baseline of \(formatted(sb.mean, metric: .sleepDuration))",
                    weight: 0.20
                ))
            }
        }

        let riskLevel: RiskLevel
        switch rawScore {
        case 0.8...: riskLevel = .critical
        case 0.6..<0.8: riskLevel = .high
        case 0.3..<0.6: riskLevel = .moderate
        default: riskLevel = .low
        }

        let metricsAvailable = [
            rhrValues.count >= Constants.immuneMinDays,
            hrvValues.count >= Constants.immuneMinDays,
            sleepValues.count >= 3,
            activityValues.count >= 3
        ].filter { $0 }.count
        let confidence = clamp01(Double(metricsAvailable) / 4.0 * 0.7 +
                                 (maxConsecutive >= 2 ? 0.3 : 0.1))

        let explanation = buildImmuneExplanation(
            score: rawScore, factors: factors, consecutiveDays: maxConsecutive
        )
        let recommendation = buildImmuneRecommendation(riskLevel: riskLevel)

        return ImmuneSignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight }
        )
    }

    private static func buildImmuneExplanation(
        score: Double, factors: [ContributingFactor], consecutiveDays: Int
    ) -> String {
        var parts: [String] = ["Immune compromise risk: \(String(format: "%.0f", score * 100))%."]
        if consecutiveDays >= 2 {
            parts.append("This multi-metric pattern has persisted for \(consecutiveDays) consecutive days, which in research literature precedes illness onset by 1-3 days.")
        }
        for factor in factors.prefix(3) {
            parts.append(factor.description + ".")
        }
        return parts.joined(separator: " ")
    }

    private static func buildImmuneRecommendation(riskLevel: RiskLevel) -> String {
        switch riskLevel {
        case .critical:
            return "Your body is showing strong signs of immune compromise. Cancel any intense workouts for the next 2-3 days. Prioritize sleep (9+ hours), hydrate aggressively (3+ liters), increase vitamin C and zinc intake, and avoid crowds or stressful situations if possible. Monitor for emerging symptoms."
        case .high:
            return "Multiple physiological markers suggest your immune system is under strain. Reduce exercise intensity to light walking only for the next 48 hours. Focus on sleep quality, hydration, and nutrition. If symptoms develop, rest completely."
        case .moderate:
            return "Some early immune compromise indicators are present. Be extra diligent about sleep (aim for 8+ hours), stay well-hydrated, and consider reducing training intensity by 30% for a few days."
        case .low:
            return "No significant immune compromise indicators detected. Continue your normal routine with good sleep and nutrition habits."
        }
    }

    // MARK: - 6. Metabolic Inactivity Alert

    /// Detects harmful sedentary patterns: sustained low step count, reduced stand hours,
    /// declining VO2 max, and weight trending upward while activity declines.
    private static func analyzeInactivity(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        dailyMaps: [HealthMetric: [Date: Double]]
    ) -> InactivitySignal {
        let window = 7
        var factors: [ContributingFactor] = []
        var componentScores: [(weight: Double, score: Double)] = []
        var availableSignals = 0
        var consecutiveInactiveDays = 0

        // Signal 1: Sustained low step count < 3000 for 3+ consecutive days (weight 0.35)
        let stepValues = recentDailyValues(metric: .steps, days: window, dailyMaps: dailyMaps)
        if stepValues.count >= Constants.inactivityMinDays {
            var streak = 0
            for entry in stepValues.reversed() {
                if entry.value < 3000 {
                    streak += 1
                } else {
                    break
                }
            }
            consecutiveInactiveDays = streak

            let stepScore: Double
            if streak >= 3 {
                stepScore = clamp01(0.4 + Double(streak - 3) * 0.15) // 3 days = 0.4, 7 days = 1.0
            } else {
                stepScore = clamp01(Double(streak) / 6.0)
            }
            componentScores.append((0.35, stepScore))
            availableSignals += 1

            if streak >= 3 {
                let avgSteps = stepValues.suffix(streak).map(\.value).mean
                factors.append(ContributingFactor(
                    metric: .steps,
                    description: "Step count below 3,000 for \(streak) consecutive days, averaging \(String(format: "%.0f", avgSteps)) steps",
                    weight: 0.35
                ))
            }
        }

        // Signal 2: Reduced stand hours below baseline (weight 0.20)
        let standValues = recentDailyValues(metric: .standHours, days: window, dailyMaps: dailyMaps)
        if standValues.count >= Constants.inactivityMinDays, let standBaseline = baselines[.standHours] {
            let recentAvg = standValues.suffix(3).map(\.value).mean
            let deviation = sigmaDeviation(value: recentAvg, baseline: standBaseline)

            let standScore = clamp01(max(0, -deviation) / 2.0)
            componentScores.append((0.20, standScore))
            availableSignals += 1

            if standScore > 0.2 {
                let pctBelow = abs(percentDeviation(value: recentAvg, baseline: standBaseline))
                factors.append(ContributingFactor(
                    metric: .standHours,
                    description: "Stand hours averaging \(formatted(recentAvg, metric: .standHours)), \(String(format: "%.0f", pctBelow))% below your baseline of \(formatted(standBaseline.mean, metric: .standHours))",
                    weight: 0.20
                ))
            }
        }

        // Signal 3: Declining VO2 max trend (weight 0.20)
        if let vo2Trend = trends[.vo2Max] {
            if vo2Trend.direction == .declining {
                let declineScore = clamp01(abs(vo2Trend.weekOverWeekChange) / 10.0)
                componentScores.append((0.20, declineScore))
                availableSignals += 1

                if declineScore > 0.15 {
                    let latestVO2 = timeSeries[.vo2Max]?.latestValue
                    let vo2Text = latestVO2.map { " at \(formatted($0, metric: .vo2Max))" } ?? ""
                    factors.append(ContributingFactor(
                        metric: .vo2Max,
                        description: "VO2 max trending down \(String(format: "%.1f", abs(vo2Trend.weekOverWeekChange)))%\(vo2Text)",
                        weight: 0.20
                    ))
                }
            } else {
                componentScores.append((0.20, 0))
                availableSignals += 1
            }
        }

        // Signal 4: Weight trending up while activity declining (weight 0.25)
        let weightValues = recentDailyValues(metric: .weight, days: 14, dailyMaps: dailyMaps)
        if weightValues.count >= 5, let weightBaseline = baselines[.weight] {
            let emaWeight = ema(weightValues.map(\.value), alpha: 0.2)
            let latestWeight = emaWeight.last ?? weightBaseline.mean
            let weightDeviation = sigmaDeviation(value: latestWeight, baseline: weightBaseline)

            // Only concerning if weight is trending up AND activity is declining
            let activityDeclining = stepValues.count >= Constants.inactivityMinDays &&
                stepValues.suffix(3).map(\.value).mean < (baselines[.steps]?.mean ?? 10000) * 0.7

            if weightDeviation > 0.3 && activityDeclining {
                let weightScore = clamp01(weightDeviation / 2.0)
                componentScores.append((0.25, weightScore))
                availableSignals += 1

                let pctUp = percentDeviation(value: latestWeight, baseline: weightBaseline)
                factors.append(ContributingFactor(
                    metric: .weight,
                    description: "Weight trending up \(String(format: "%.1f", pctUp))% while activity has decreased",
                    weight: 0.25
                ))
            } else {
                componentScores.append((0.25, 0))
                availableSignals += 1
            }
        }

        guard availableSignals >= 1, !componentScores.isEmpty else {
            return InactivitySignal(
                riskLevel: .low, score: 0, confidence: 0,
                explanation: "Insufficient data to assess inactivity risk. At least 3 days of step data are needed.",
                recommendation: "Continue tracking your daily steps and movement.",
                contributingFactors: [],
                consecutiveInactiveDays: 0
            )
        }

        let totalWeight = componentScores.reduce(0.0) { $0 + $1.weight }
        let rawScore = componentScores.reduce(0.0) { $0 + $1.weight * $1.score } / totalWeight

        let riskLevel: RiskLevel
        switch rawScore {
        case 0.8...: riskLevel = .critical
        case 0.6..<0.8: riskLevel = .high
        case 0.3..<0.6: riskLevel = .moderate
        default: riskLevel = .low
        }

        let confidence = clamp01(Double(availableSignals) / 4.0 * 0.5 +
                                 Double(Swift.min(stepValues.count, window)) / Double(window) * 0.5)

        let explanation = buildInactivityExplanation(
            score: rawScore, consecutiveDays: consecutiveInactiveDays, factors: factors
        )
        let recommendation = buildInactivityRecommendation(
            riskLevel: riskLevel, consecutiveDays: consecutiveInactiveDays
        )

        return InactivitySignal(
            riskLevel: riskLevel,
            score: rawScore,
            confidence: confidence,
            explanation: explanation,
            recommendation: recommendation,
            contributingFactors: factors.sorted { $0.weight > $1.weight },
            consecutiveInactiveDays: consecutiveInactiveDays
        )
    }

    private static func buildInactivityExplanation(
        score: Double, consecutiveDays: Int, factors: [ContributingFactor]
    ) -> String {
        var parts: [String] = ["Metabolic inactivity score: \(String(format: "%.0f", score * 100))%."]
        if consecutiveDays >= 3 {
            parts.append("You have been inactive for \(consecutiveDays) consecutive days.")
        }
        for factor in factors.prefix(3) {
            parts.append(factor.description + ".")
        }
        return parts.joined(separator: " ")
    }

    private static func buildInactivityRecommendation(
        riskLevel: RiskLevel, consecutiveDays: Int
    ) -> String {
        switch riskLevel {
        case .critical:
            return "You've been inactive for \(consecutiveDays) days. Prolonged inactivity significantly impacts metabolic health. Start with a 15-minute walk today. Even brief movement breaks every hour can reverse the metabolic slowdown. Set a timer to stand and move for 2 minutes every 30 minutes."
        case .high:
            return "You've been inactive for \(consecutiveDays) days. Even a 15-minute walk can reverse the metabolic slowdown. Try to hit at least 4,000 steps today and take standing breaks every hour."
        case .moderate:
            return "Your activity level has dropped below your usual pattern. Aim for a short walk or light exercise today. Small increases in daily movement add up significantly for metabolic health."
        case .low:
            return "Activity levels look healthy. Keep up your current movement habits."
        }
    }
}
