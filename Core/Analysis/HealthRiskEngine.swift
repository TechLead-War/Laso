import Foundation

/// Evaluates health risk profiles by combining multiple metric signals to predict potential health issues.
/// Uses clinical thresholds, personal baselines, trend data, and anomaly detection to compute risk scores.
struct HealthRiskEngine {

    /// Assess all risk profiles given current analysis state
    static func assessAllRisks(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        anomalies: [AnomalyDetector.AnomalyResult]
    ) -> [HealthRisk] {
        HealthRiskType.allCases.compactMap { riskType in
            let risk = assessRisk(
                riskType: riskType,
                timeSeries: timeSeries,
                baselines: baselines,
                trends: trends,
                anomalies: anomalies
            )
            // Only include if we have at least 2 measured factors
            return risk.measuredFactors.count >= 2 ? risk : nil
        }
        .sorted { $0.level > $1.level }
    }

    /// Assess a single risk profile
    static func assessRisk(
        riskType: HealthRiskType,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        anomalies: [AnomalyDetector.AnomalyResult]
    ) -> HealthRisk {
        let metrics = riskType.relevantMetrics

        // Evaluate each contributing metric
        var factors: [RiskFactor] = []
        for metric in metrics {
            let factor = evaluateFactor(
                metric: metric,
                timeSeries: timeSeries[metric],
                baseline: baselines[metric],
                trend: trends[metric],
                anomaly: anomalies.first { $0.metric == metric }
            )
            factors.append(factor)
        }

        // Compute overall risk level from measured factors
        let measured = factors.filter { $0.status != .unmeasured }
        let level: Int
        if measured.isEmpty {
            level = 0
        } else {
            let totalContribution = measured.map(\.contribution).reduce(0, +)
            level = min(100, totalContribution / measured.count)
        }

        // Generate actionable focus areas from the worst factors
        let focusAreas = generateFocusAreas(riskType: riskType, factors: factors)

        return HealthRisk(
            riskType: riskType,
            level: level,
            factors: factors,
            focusAreas: focusAreas
        )
    }

    // MARK: - Factor Evaluation

    /// Evaluate how much a single metric contributes to risk
    private static func evaluateFactor(
        metric: HealthMetric,
        timeSeries: MetricTimeSeries?,
        baseline: UserBaseline?,
        trend: TrendAnalyzer.TrendResult?,
        anomaly: AnomalyDetector.AnomalyResult?
    ) -> RiskFactor {
        // No data = unmeasured
        guard let series = timeSeries,
              let currentValue = series.mean(lastDays: 3) as Double?,
              currentValue > 0 else {
            return RiskFactor(
                metric: metric,
                contribution: 0,
                status: .unmeasured,
                currentValue: 0,
                optimalRange: optimalRangeString(for: metric),
                explanation: Copy.Analysis.HealthRiskEngine.noRecentDataExplanation
            )
        }

        let normalRange = RulesConfiguration.normalRange(for: metric)
        let isInNormalRange = normalRange.contains(currentValue)
        let trendDirection = trend?.direction ?? .stable
        let isDeclineForHealth = isMetricDecliningForHealth(metric: metric, trend: trendDirection)

        // Score the risk contribution (0 = no risk, 100 = maximum risk)
        var riskScore = 0

        // 1. Position relative to normal range
        if !isInNormalRange {
            let distance = distanceFromNormalRange(value: currentValue, range: normalRange)
            riskScore += min(40, Int(distance * 100)) // Up to 40 points for being out of range
        }

        // 2. Anomaly severity
        if let anomaly {
            switch anomaly.severity {
            case .critical: riskScore += 30
            case .warning: riskScore += 15
            case .info: break
            }
        }

        // 3. Trend direction (declining health = more risk)
        if isDeclineForHealth {
            let wowChange = abs(trend?.weekOverWeekChange ?? 0)
            if wowChange > 10 {
                riskScore += 20 // Strong adverse trend
            } else if wowChange > 5 {
                riskScore += 12
            } else {
                riskScore += 6
            }
        }

        // 4. Deviation from personal baseline
        if let baseline, baseline.mean > 0 {
            let deviation = abs(baseline.deviationPercent(for: currentValue)) / 100.0
            if deviation > 0.20 { riskScore += 10 }
            else if deviation > 0.10 { riskScore += 5 }
        }

        riskScore = min(100, riskScore)

        let status: RiskFactorStatus
        switch riskScore {
        case 0..<15: status = .optimal
        case 15..<35: status = .borderline
        case 35..<60: status = .concerning
        default: status = .critical
        }

        let explanation = generateFactorExplanation(
            metric: metric,
            currentValue: currentValue,
            normalRange: normalRange,
            isInRange: isInNormalRange,
            trend: trendDirection,
            riskScore: riskScore
        )

        return RiskFactor(
            metric: metric,
            contribution: riskScore,
            status: status,
            currentValue: currentValue,
            optimalRange: optimalRangeString(for: metric),
            explanation: explanation
        )
    }

    // MARK: - Focus Area Generation

    /// Generate prioritized focus areas from risk factors
    private static func generateFocusAreas(riskType: HealthRiskType, factors: [RiskFactor]) -> [FocusArea] {
        // Sort by contribution (highest risk first) and filter to actionable ones
        let actionable = factors
            .filter { $0.status != .unmeasured && $0.status != .optimal }
            .sorted { $0.contribution > $1.contribution }

        return actionable.prefix(3).map { factor in
            let impact: FocusImpact
            switch factor.status {
            case .critical: impact = .high
            case .concerning: impact = .high
            case .borderline: impact = .medium
            default: impact = .low
            }

            let (title, description, target) = focusRecommendation(
                riskType: riskType,
                metric: factor.metric,
                status: factor.status,
                currentValue: factor.currentValue
            )

            return FocusArea(
                title: title,
                description: description,
                impact: impact,
                metric: factor.metric,
                targetDescription: target
            )
        }
    }

    // MARK: - Helpers

    /// Whether the metric's trend direction is bad for health
    private static func isMetricDecliningForHealth(metric _: HealthMetric, trend: TrendDirection) -> Bool {
        // TrendAnalyzer already normalizes direction by metric semantics.
        return trend == .declining
    }

    /// Fractional distance from normal range (0 = at boundary, 1 = far out)
    private static func distanceFromNormalRange(value: Double, range: RulesConfiguration.NormalRange) -> Double {
        if value < range.low {
            let span = range.high - range.low
            guard span > 0 else { return 0 }
            return min(1.0, (range.low - value) / span)
        } else if value > range.high {
            let span = range.high - range.low
            guard span > 0 else { return 0 }
            return min(1.0, (value - range.high) / span)
        }
        return 0
    }

    private static func optimalRangeString(for metric: HealthMetric) -> String {
        let range = RulesConfiguration.normalRange(for: metric)
        let fmt: (Double) -> String = { value in
            if value >= 1000 { return String(format: "%.0f", value) }
            if value == value.rounded() && value < 100 { return String(format: "%.0f", value) }
            return String(format: "%.1f", value)
        }
        return "\(fmt(range.low))–\(fmt(range.high)) \(metric.unit)"
    }

    private static func generateFactorExplanation(
        metric: HealthMetric,
        currentValue: Double,
        normalRange: RulesConfiguration.NormalRange,
        isInRange: Bool,
        trend: TrendDirection,
        riskScore: Int
    ) -> String {
        let formatted = formatValue(currentValue, metric: metric)
        let unit = metric.unit

        if riskScore < 15 {
            return Copy.Analysis.HealthRiskEngine.withinHealthyRange(metricName: metric.displayName, formatted: formatted, unit: unit)
        }

        var parts: [String] = []
        parts.append(Copy.Analysis.HealthRiskEngine.metricValuePrefix(metricName: metric.displayName, formatted: formatted, unit: unit))

        if !isInRange {
            if currentValue < normalRange.low {
                parts.append(Copy.Analysis.HealthRiskEngine.belowOptimalRange)
            } else {
                parts.append(Copy.Analysis.HealthRiskEngine.aboveOptimalRange)
            }
        }

        switch trend {
        case .declining:
            let dir = metric.higherIsBetter ? Copy.Analysis.HealthRiskEngine.directionDecreasing : Copy.Analysis.HealthRiskEngine.directionRising
            parts.append(Copy.Analysis.HealthRiskEngine.andDirection(dir))
        case .improving:
            let dir = metric.higherIsBetter ? Copy.Analysis.HealthRiskEngine.directionIncreasing : Copy.Analysis.HealthRiskEngine.directionDecreasing
            parts.append(Copy.Analysis.HealthRiskEngine.whileTrending(dir))
        case .stable:
            break
        }

        return parts.joined(separator: ", ") + "."
    }

    // MARK: - Focus Recommendations

    private static func focusRecommendation(
        riskType: HealthRiskType,
        metric: HealthMetric,
        status: RiskFactorStatus,
        currentValue: Double
    ) -> (title: String, description: String, target: String) {
        let mapped: (title: String, description: String, target: String)?
        switch riskType {
        case .cardiac:
            mapped = cardiacFocusRecommendation(metric: metric)
        case .sleepDeficit:
            mapped = sleepDeficitFocusRecommendation(metric: metric)
        case .overtraining:
            mapped = overtrainingFocusRecommendation(metric: metric)
        case .respiratory:
            mapped = respiratoryFocusRecommendation(metric: metric)
        case .metabolic:
            mapped = metabolicFocusRecommendation(metric: metric)
        case .stress:
            mapped = stressFocusRecommendation(metric: metric)
        case .mobilityDecline:
            mapped = mobilityFocusRecommendation(metric: metric)
        }
        if let mapped { return mapped }
        return defaultFocusRecommendation(metric: metric)
    }

    private static func cardiacFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .restingHeartRate: return Copy.Analysis.HealthRiskFocus.lowerRHR
        case .heartRateVariability: return Copy.Analysis.HealthRiskFocus.improveHRV
        case .bloodPressureSystolic, .bloodPressureDiastolic: return Copy.Analysis.HealthRiskFocus.supportBP
        case .heartRateRecovery: return Copy.Analysis.HealthRiskFocus.improveHRR
        case .atrialFibrillationBurden: return Copy.Analysis.HealthRiskFocus.aboutAFib
        default: return nil
        }
    }

    private static func sleepDeficitFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .sleepDuration: return Copy.Analysis.HealthRiskFocus.increaseSleepDuration
        case .sleepDeep: return Copy.Analysis.HealthRiskFocus.boostDeepSleep
        case .sleepREM: return Copy.Analysis.HealthRiskFocus.improveREM
        case .sleepAwake: return Copy.Analysis.HealthRiskFocus.reduceWaking
        default: return nil
        }
    }

    private static func overtrainingFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .heartRateVariability: return Copy.Analysis.HealthRiskFocus.allowRecovery
        case .restingHeartRate: return Copy.Analysis.HealthRiskFocus.watchElevatedRHR
        case .exerciseMinutes: return Copy.Analysis.HealthRiskFocus.balanceLoad
        default: return nil
        }
    }

    private static func respiratoryFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .bloodOxygen: return Copy.Analysis.HealthRiskFocus.trackBloodOxygen
        case .vo2Max: return Copy.Analysis.HealthRiskFocus.buildCardio
        case .respiratoryRate: return Copy.Analysis.HealthRiskFocus.steadyBreathing
        default: return nil
        }
    }

    private static func metabolicFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .bmi, .weight: return Copy.Analysis.HealthRiskFocus.optimizeBodyComp
        case .bodyFatPercentage: return Copy.Analysis.HealthRiskFocus.reduceBodyFat
        case .waistCircumference: return Copy.Analysis.HealthRiskFocus.reduceWaist
        case .steps: return Copy.Analysis.HealthRiskFocus.increaseMovement
        default: return nil
        }
    }

    private static func stressFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .heartRateVariability: return Copy.Analysis.HealthRiskFocus.reduceChronicStress
        case .sleepDuration: return Copy.Analysis.HealthRiskFocus.prioritizeRecoverySleep
        case .mindfulMinutes: return Copy.Analysis.HealthRiskFocus.buildMindfulness
        case .electrodermalActivity: return Copy.Analysis.HealthRiskFocus.manageSympathetic
        default: return nil
        }
    }

    private static func mobilityFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String)? {
        switch metric {
        case .walkingSpeed: return Copy.Analysis.HealthRiskFocus.maintainWalkingSpeed
        case .walkingAsymmetry: return Copy.Analysis.HealthRiskFocus.correctGaitAsymmetry
        case .sixMinuteWalkTestDistance: return Copy.Analysis.HealthRiskFocus.buildFunctionalEndurance
        case .walkingDoubleSupportPercentage: return Copy.Analysis.HealthRiskFocus.improveBalance
        default: return nil
        }
    }

    private static func defaultFocusRecommendation(metric: HealthMetric) -> (title: String, description: String, target: String) {
        return (
            Copy.Analysis.HealthRiskFocus.improveMetric(metric.displayName),
            Copy.Analysis.HealthRiskFocus.bringIntoOptimalRange(metric.displayName.lowercased()),
            Copy.Analysis.HealthRiskFocus.targetRange(optimalRangeString(for: metric))
        )
    }

    private static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        metric.formatValue(value)
    }
}
