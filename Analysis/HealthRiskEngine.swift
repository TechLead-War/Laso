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
                explanation: "No recent data available. Keep Apple Health syncing to track this metric."
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
            return "\(metric.displayName) is \(formatted) \(unit), within the healthy range."
        }

        var parts: [String] = []
        parts.append("\(metric.displayName) is \(formatted) \(unit)")

        if !isInRange {
            if currentValue < normalRange.low {
                parts.append("below the optimal range")
            } else {
                parts.append("above the optimal range")
            }
        }

        switch trend {
        case .declining:
            let dir = metric.higherIsBetter ? "decreasing" : "rising"
            parts.append("and \(dir)")
        case .improving:
            let dir = metric.higherIsBetter ? "increasing" : "decreasing"
            parts.append("while trending \(dir)")
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
        switch (riskType, metric) {
        // Cardiac
        case (.cardiac, .restingHeartRate):
            return (
                "Lower Resting Heart Rate",
                "Regular aerobic exercise (brisk walking, cycling) 30 min/day can reduce RHR by 5-10 bpm over weeks. Reduce caffeine and manage stress.",
                "Target: 50–70 bpm"
            )
        case (.cardiac, .heartRateVariability):
            return (
                "Improve Heart Rate Variability",
                "HRV reflects autonomic nervous system health. Prioritize sleep quality, practice box breathing (4-4-4-4), and include recovery days between hard workouts.",
                "Target: 40+ ms (SDNN)"
            )
        case (.cardiac, .bloodPressureSystolic), (.cardiac, .bloodPressureDiastolic):
            return (
                "Manage Blood Pressure",
                "Reduce sodium to <2,300mg/day, exercise 150 min/week, maintain healthy weight, limit alcohol. Monitor regularly.",
                "Target: <120/80 mmHg"
            )
        case (.cardiac, .heartRateRecovery):
            return (
                "Improve Heart Rate Recovery",
                "Better recovery indicates stronger cardiac fitness. Increase cardio frequency and include cool-down periods after exercise.",
                "Target: >12 bpm drop in 1 min"
            )
        case (.cardiac, .atrialFibrillationBurden):
            return (
                "Monitor AFib Patterns",
                "Track when episodes occur. Reduce alcohol, caffeine, and stress. Consult a cardiologist if burden increases.",
                "Target: <1% burden"
            )

        // Sleep
        case (.sleepDeficit, .sleepDuration):
            return (
                "Increase Sleep Duration",
                "Set a fixed bedtime 8 hours before your alarm. No screens 1 hour before bed. Keep your bedroom cool (65-68°F) and dark.",
                "Target: 7–9 hours"
            )
        case (.sleepDeficit, .sleepDeep):
            return (
                "Boost Deep Sleep",
                "Exercise earlier in the day (not within 3 hours of bedtime), avoid alcohol which fragments deep sleep, and maintain a cool bedroom.",
                "Target: 1–2 hours per night"
            )
        case (.sleepDeficit, .sleepREM):
            return (
                "Improve REM Sleep",
                "REM sleep is essential for memory and emotional processing. Consistent sleep schedule and avoiding sleep aids can increase REM proportion.",
                "Target: 1.5–2 hours per night"
            )
        case (.sleepDeficit, .sleepAwake):
            return (
                "Reduce Nighttime Waking",
                "Limit fluids 2 hours before bed, avoid caffeine after noon, use white noise, and keep the room dark. Address any sleep apnea concerns.",
                "Target: <30 min per night"
            )

        // Overtraining
        case (.overtraining, .heartRateVariability):
            return (
                "Allow Recovery Time",
                "Low HRV with high training load signals insufficient recovery. Take 1-2 rest days, prioritize sleep, and reduce workout intensity by 20%.",
                "Target: HRV returning to baseline"
            )
        case (.overtraining, .restingHeartRate):
            return (
                "Watch for Elevated RHR",
                "A rising RHR despite regular training is a classic overtraining sign. Reduce volume this week and monitor RHR each morning before getting up.",
                "Target: Within 5 bpm of personal baseline"
            )
        case (.overtraining, .exerciseMinutes):
            return (
                "Balance Training Load",
                "More isn't always better. Follow the 80/20 rule: 80% easy, 20% hard. Include at least 2 rest days per week.",
                "Target: 150–300 min/week with rest days"
            )

        // Respiratory
        case (.respiratory, .bloodOxygen):
            return (
                "Monitor Blood Oxygen",
                "SpO2 below 95% warrants attention. Below 90% is a medical emergency requiring urgent care. Practice deep breathing exercises and sleep with head slightly elevated if levels drop at night. If readings fall below 90%, retake the measurement and seek immediate medical attention if confirmed.",
                "Target: 95–100% (below 90% = emergency)"
            )
        case (.respiratory, .vo2Max):
            return (
                "Build Cardiovascular Fitness",
                "VO2 Max is the single strongest predictor of longevity. Add 3-4 sessions of zone 2 cardio (conversational pace) per week for 30+ minutes.",
                "Target: Improve by 5% in 8 weeks"
            )
        case (.respiratory, .respiratoryRate):
            return (
                "Normalize Breathing Rate",
                "Elevated respiratory rate may indicate stress or illness. Practice diaphragmatic breathing: 4 seconds in, 6 seconds out, 5 minutes daily.",
                "Target: 12–20 breaths/min at rest"
            )

        // Metabolic
        case (.metabolic, .bmi), (.metabolic, .weight):
            return (
                "Optimize Body Composition",
                "Focus on sustainable changes: reduce processed foods, increase protein and vegetables, combine cardio with resistance training.",
                "Target: BMI 18.5–25"
            )
        case (.metabolic, .bodyFatPercentage):
            return (
                "Reduce Body Fat",
                "Combine resistance training 3x/week with 150+ min cardio/week. Prioritize protein (0.8g/lb bodyweight) and sleep for fat loss.",
                "Target: 10–20% (men) / 18–28% (women)"
            )
        case (.metabolic, .waistCircumference):
            return (
                "Reduce Waist Circumference",
                "Abdominal fat is a key metabolic risk indicator. Daily walks, core exercises, and reduced sugar intake have the biggest impact.",
                "Target: <94 cm (men) / <80 cm (women)"
            )
        case (.metabolic, .steps):
            return (
                "Increase Daily Movement",
                "Low step count is strongly linked to metabolic risk. Start with 2,000 more steps than current average. Take walking meetings and post-meal walks.",
                "Target: 8,000–10,000 steps/day"
            )

        // Stress
        case (.stress, .heartRateVariability):
            return (
                "Reduce Chronic Stress",
                "HRV is the most reliable stress biomarker. Try 10 minutes of meditation daily, box breathing before bed, and time in nature.",
                "Target: HRV trending upward week over week"
            )
        case (.stress, .sleepDuration):
            return (
                "Prioritize Recovery Sleep",
                "Sleep is the #1 stress recovery tool. Set a non-negotiable bedtime. Remove work apps from your phone after 9 PM.",
                "Target: 7–8 hours consistently"
            )
        case (.stress, .mindfulMinutes):
            return (
                "Build Mindfulness Practice",
                "Even 5 minutes of daily mindfulness reduces cortisol levels. Use a guided app to start. Morning sessions have the most impact.",
                "Target: 10–20 min daily"
            )
        case (.stress, .electrodermalActivity):
            return (
                "Manage Sympathetic Activation",
                "Elevated EDA reflects sympathetic nervous system arousal. Practice progressive muscle relaxation and reduce stimulant intake.",
                "Target: Return to personal baseline"
            )

        // Mobility
        case (.mobilityDecline, .walkingSpeed):
            return (
                "Maintain Walking Speed",
                "Walking speed is a key vitality indicator. Include brisk walking intervals (2 min fast, 2 min normal) in daily walks.",
                "Target: >1.0 m/s (3.6 km/h)"
            )
        case (.mobilityDecline, .walkingAsymmetry):
            return (
                "Correct Gait Asymmetry",
                "Asymmetry above 10% may indicate muscle imbalance or joint issues. Single-leg exercises and stretching can help. See a PT if persistent.",
                "Target: <10% asymmetry"
            )
        case (.mobilityDecline, .sixMinuteWalkTestDistance):
            return (
                "Build Functional Endurance",
                "The 6-minute walk distance reflects overall functional capacity. Daily walks of increasing duration will improve this steadily.",
                "Target: >500 meters"
            )
        case (.mobilityDecline, .walkingDoubleSupportPercentage):
            return (
                "Improve Balance",
                "High double support time indicates balance challenges. Practice single-leg stands, heel-to-toe walking, and tai chi or yoga.",
                "Target: 20–30%"
            )

        default:
            return (
                "Improve \(metric.displayName)",
                "Focus on bringing \(metric.displayName.lowercased()) into the optimal range through consistent healthy habits.",
                "Target: \(optimalRangeString(for: metric))"
            )
        }
    }

    private static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        metric.formatValue(value)
    }
}
