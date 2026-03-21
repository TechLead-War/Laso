import Foundation

/// Detects patterns impacting cognitive performance (brain fog, slow processing, poor focus)
/// and physical energy/fatigue using existing health metric data.
struct CognitiveEnergyAnalyzer {

    /// Generate cognitive and energy insights from available health data
    static func generateInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        correlations: [HealthCorrelation]
    ) -> [Insight] {
        var insights: [Insight] = []

        if let cogReadiness = cognitiveReadinessInsight(timeSeries: timeSeries, baselines: baselines) {
            insights.append(cogReadiness)
        }

        if let sleepDebt = sleepDebtInsight(timeSeries: timeSeries, baselines: baselines) {
            insights.append(sleepDebt)
        }

        if let mentalFatigue = mentalFatigueInsight(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(mentalFatigue)
        }

        if let energy = physicalEnergyInsight(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(energy)
        }

        if let recoveryDay = recoveryDayNeededInsight(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(recoveryDay)
        }

        if let daylightChain = daylightSleepCognitionInsight(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(daylightChain)
        }

        return insights
    }

    // MARK: - 1. Cognitive Readiness Score

    private static func cognitiveReadinessInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Insight? {
        // Need at least HRV + sleep duration to compute
        guard let hrvBaseline = baselines[.heartRateVariability],
              let sleepBaseline = baselines[.sleepDuration] else { return nil }

        var score: Double = 0
        var components: [(name: String, contribution: String)] = []
        var totalWeight: Double = 0

        // HRV z-score (30%)
        if let hrvSeries = timeSeries[.heartRateVariability] {
            let recent = hrvSeries.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let z = (avg - hrvBaseline.mean) / max(hrvBaseline.standardDeviation, 1)
                let normalizedScore = min(max((z + 2) / 4.0, 0), 1) * 100 // -2σ=0, +2σ=100
                score += normalizedScore * 0.30
                totalWeight += 0.30
                if z < -0.5 {
                    let pctBelow = String(format: "%.0f", abs(z * hrvBaseline.standardDeviation / hrvBaseline.mean * 100))
                    components.append(("HRV", "down \(pctBelow)% from baseline"))
                }
            }
        }

        // Deep sleep % (25%)
        if let deepSeries = timeSeries[.sleepDeep], let deepBaseline = baselines[.sleepDeep] {
            let recent = deepSeries.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let z = (avg - deepBaseline.mean) / max(deepBaseline.standardDeviation, 0.1)
                let normalizedScore = min(max((z + 2) / 4.0, 0), 1) * 100
                score += normalizedScore * 0.25
                totalWeight += 0.25
                if z < -0.5 {
                    let pctBelow = String(format: "%.0f", abs((avg - deepBaseline.mean) / deepBaseline.mean * 100))
                    components.append(("deep sleep", "\(pctBelow)% below baseline"))
                }
            }
        }

        // REM % (15%)
        if let remSeries = timeSeries[.sleepREM], let remBaseline = baselines[.sleepREM] {
            let recent = remSeries.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let z = (avg - remBaseline.mean) / max(remBaseline.standardDeviation, 0.1)
                let normalizedScore = min(max((z + 2) / 4.0, 0), 1) * 100
                score += normalizedScore * 0.15
                totalWeight += 0.15
                if z < -0.5 {
                    let pctBelow = String(format: "%.0f", abs((avg - remBaseline.mean) / remBaseline.mean * 100))
                    components.append(("REM sleep", "\(pctBelow)% below baseline"))
                }
            }
        }

        // Blood oxygen (15%)
        if let o2Series = timeSeries[.bloodOxygen], let o2Baseline = baselines[.bloodOxygen] {
            let recent = o2Series.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let z = (avg - o2Baseline.mean) / max(o2Baseline.standardDeviation, 0.1)
                let normalizedScore = min(max((z + 2) / 4.0, 0), 1) * 100
                score += normalizedScore * 0.15
                totalWeight += 0.15
            }
        }

        // Sleep duration vs target (15%)
        if let sleepSeries = timeSeries[.sleepDuration] {
            let recent = sleepSeries.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let z = (avg - sleepBaseline.mean) / max(sleepBaseline.standardDeviation, 0.1)
                let normalizedScore = min(max((z + 2) / 4.0, 0), 1) * 100
                score += normalizedScore * 0.15
                totalWeight += 0.15
                if z < -0.5 {
                    let deficit = String(format: "%.1f", sleepBaseline.mean - avg)
                    components.append(("sleep duration", "\(deficit) hrs below your baseline"))
                }
            }
        }

        guard totalWeight >= 0.45 else { return nil } // Need at least HRV + one sleep metric

        // Normalize score to 100 scale
        let finalScore = Int((score / totalWeight).rounded())

        // Only generate insight when score is noteworthy
        guard finalScore <= 65 || finalScore >= 85 else { return nil }

        let isLow = finalScore <= 65
        let componentText = components.isEmpty ? "" : " \u{2014} your \(components.map { "\($0.name) \($0.contribution)" }.joined(separator: ", "))"

        let severity: Severity = finalScore <= 40 ? .warning : .info

        let summary: String
        let recommendation: String
        if isLow {
            summary = "Your cognitive energy is at \(finalScore)/100\(componentText). Addressing these factors can sharpen mental clarity and processing speed."
            // Find the biggest lever
            let topComponent = components.first?.name ?? "sleep"
            recommendation = "Consider extending tonight's sleep by 45 min. Your \(topComponent) is the biggest factor right now. a single night of 8+ hr sleep typically improves next-day HRV and deep sleep."
        } else {
            summary = "Your cognitive energy is strong at \(finalScore)/100. HRV, sleep quality, and recovery markers are all above baseline."
            recommendation = Copy.Analysis.CognitiveEnergy.brainPrimedForWork
        }

        return Insight(
            metric: .heartRateVariability,
            title: isLow ? Copy.Analysis.CognitiveEnergy.lowCognitiveReadiness : Copy.Analysis.CognitiveEnergy.strongCognitiveReadiness,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: isLow ? .declining : .improving,
            currentValue: Double(finalScore),
            baselineValue: 70,
            deviationPercent: Double(finalScore - 70) / 70.0 * 100,
            category: .cognitiveEnergy,
            relatedMetrics: [.heartRateVariability, .sleepDeep, .sleepREM, .sleepDuration]
        )
    }

    // MARK: - 2. Sleep Debt Tracker

    private static func sleepDebtInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Insight? {
        guard let sleepSeries = timeSeries[.sleepDuration],
              let sleepBaseline = baselines[.sleepDuration] else { return nil }

        let last7 = sleepSeries.samples(lastDays: 7)
        guard last7.count >= 5 else { return nil }

        let weeklyAvg = last7.mean(of: \.value)
        let dailyDeficit = sleepBaseline.mean - weeklyAvg
        let cumulativeDebt = dailyDeficit * Double(last7.count)

        // Only trigger if meaningful debt accumulated
        guard cumulativeDebt >= 2.0 else { return nil }

        let avgStr = String(format: "%.1f", weeklyAvg)
        let baselineStr = String(format: "%.1f", sleepBaseline.mean)
        let debtStr = String(format: "%.1f", cumulativeDebt)
        let catchUpNights = Int(ceil(cumulativeDebt / 1.0)) // 1hr extra per night

        return Insight(
            metric: .sleepDuration,
            title: Copy.Analysis.CognitiveEnergy.sleepDebtAccumulating,
            summary: "You've accumulated \(debtStr) hours of sleep debt this week (averaging \(avgStr) hrs vs your \(baselineStr) hr baseline). Cognitive impairment compounds with each deficit day \u{2014} reaction time and decision-making are most affected.",
            recommendation: "An extra hour per night for \(catchUpNights) nights can help clear this deficit. Setting a bedtime alarm 45 min before your target sleep time is a good starting point.",
            severity: cumulativeDebt >= 5.0 ? .warning : .info,
            trend: .declining,
            currentValue: weeklyAvg,
            baselineValue: sleepBaseline.mean,
            deviationPercent: -abs(dailyDeficit / sleepBaseline.mean * 100),
            category: .cognitiveEnergy,
            relatedMetrics: [.sleepDuration, .sleepDeep, .heartRateVariability]
        )
    }

    // MARK: - 3. Mental Fatigue Pattern

    private static func mentalFatigueInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        // Trigger: HRV declining + sleep quality dropping + (optional: mindfulness decreasing)
        let hrvDeclining = trends[.heartRateVariability]?.direction == .declining
        let deepSleepDeclining = trends[.sleepDeep]?.direction == .declining

        guard hrvDeclining || deepSleepDeclining else { return nil }

        // Get specific magnitudes
        let hrvChange = trends[.heartRateVariability]?.weekOverWeekChange ?? 0
        let deepChange = trends[.sleepDeep]?.weekOverWeekChange ?? 0
        let mindfulChange = trends[.mindfulMinutes]?.weekOverWeekChange ?? 0
        let daylightChange = trends[.timeInDaylight]?.weekOverWeekChange ?? 0

        // Need at least 2 signals with meaningful decline
        var signals = 0
        if hrvDeclining && abs(hrvChange) > 5 { signals += 1 }
        if deepSleepDeclining && abs(deepChange) > 5 { signals += 1 }
        if mindfulChange < -10 { signals += 1 }
        guard signals >= 2 else { return nil }

        var summaryParts: [String] = []
        if hrvDeclining { summaryParts.append("HRV dropped \(String(format: "%.0f", abs(hrvChange)))%") }
        if deepSleepDeclining { summaryParts.append("deep sleep down \(String(format: "%.0f", abs(deepChange)))%") }

        let summary = "Your \(summaryParts.joined(separator: " and ")) over the past week \u{2014} this combination is strongly associated with mental fatigue, slower processing, and difficulty concentrating."

        // Build ranked recommendations
        var actions: [String] = []
        actions.append("(1) Add 30 min to tonight's sleep \u{2014} your #1 lever for cognitive recovery")
        if abs(daylightChange) > 10 {
            actions.append("(2) Get 20 min of morning daylight \u{2014} your daylight exposure is down \(String(format: "%.0f", abs(daylightChange)))%")
        } else {
            actions.append("(2) Get 20 min of morning daylight to reset your circadian clock")
        }
        if mindfulChange < -10 {
            actions.append("(3) Even 5 min of meditation \u{2014} your mindfulness dropped \(String(format: "%.0f", abs(mindfulChange)))% this week")
        } else {
            actions.append("(3) Try 5 min of guided breathing to reduce cognitive load")
        }

        return Insight(
            metric: .heartRateVariability,
            title: Copy.Analysis.CognitiveEnergy.mentalFatiguePatternDetected,
            summary: summary,
            recommendation: "Three actions ranked by impact: \(actions.joined(separator: ". ")).",
            severity: .warning,
            trend: .declining,
            currentValue: abs(hrvChange),
            baselineValue: 0,
            deviationPercent: abs(hrvChange),
            category: .cognitiveEnergy,
            relatedMetrics: [.heartRateVariability, .sleepDeep, .mindfulMinutes, .timeInDaylight]
        )
    }

    // MARK: - 4. Physical Energy Forecast

    private static func physicalEnergyInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        // Composite from: sleep duration, RHR trend, activity trend, recovery status
        var signals: [(label: String, severity: Double)] = []

        // Sleep deficit
        if let sleepSeries = timeSeries[.sleepDuration], let sleepBaseline = baselines[.sleepDuration] {
            let recent = sleepSeries.samples(lastDays: 3)
            if !recent.isEmpty {
                let avg = recent.mean(of: \.value)
                let deficit = (sleepBaseline.mean - avg) / sleepBaseline.mean * 100
                if deficit > 8 {
                    signals.append(("sleep averaging \(String(format: "%.1f", avg)) hrs (\(String(format: "%.0f", deficit))% below baseline)", deficit))
                }
            }
        }

        // Elevated RHR
        if let rhrTrend = trends[.restingHeartRate], rhrTrend.direction == .declining,
           let rhrBaseline = baselines[.restingHeartRate] {
            let rhrIncrease = abs(rhrTrend.weekOverWeekChange)
            if rhrIncrease > 3 {
                let bpmIncrease = rhrBaseline.mean * rhrIncrease / 100
                signals.append(("resting HR elevated \(String(format: "%.0f", bpmIncrease)) bpm", rhrIncrease))
            }
        }

        // Steps declining
        if let stepsTrend = trends[.steps], stepsTrend.direction == .declining {
            let stepsChange = abs(stepsTrend.weekOverWeekChange)
            if stepsChange > 10 {
                signals.append(("steps down \(String(format: "%.0f", stepsChange))%", stepsChange))
            }
        }

        guard signals.count >= 2 else { return nil }

        let signalText = signals.map(\.label).joined(separator: ", ")

        // Find a data-backed correlation for the recommendation
        let stepCorrelation = findCorrelation(for: .steps, in: timeSeries, baselines: baselines)

        let recommendation: String
        if let stepEffect = stepCorrelation {
            recommendation = "Counter-intuitive: a 20-min walk will boost energy more than rest. Your data shows that on higher-activity days, your next-day resting HR drops \(String(format: "%.0f", stepEffect))% and energy markers improve."
        } else {
            recommendation = "A 20-min walk will boost energy more than rest. Light movement improves circulation and reduces fatigue more effectively than staying sedentary."
        }

        return Insight(
            metric: .steps,
            title: Copy.Analysis.CognitiveEnergy.lowPhysicalEnergy,
            summary: "Your physical energy indicators are low: \(signalText). You're likely feeling fatigued and heavy.",
            recommendation: recommendation,
            severity: signals.count >= 3 ? .warning : .info,
            trend: .declining,
            currentValue: Double(signals.count),
            baselineValue: 0,
            deviationPercent: Double(signals.count) * 15,
            category: .cognitiveEnergy,
            relatedMetrics: [.sleepDuration, .restingHeartRate, .steps, .activeCalories]
        )
    }

    // MARK: - 5. Recovery Day Needed

    private static func recoveryDayNeededInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        // Trigger: 3+ days of high activity + HRV declining + RHR elevated
        guard let calSeries = timeSeries[.activeCalories],
              let calBaseline = baselines[.activeCalories] else { return nil }

        // Count consecutive high-activity days
        let recent = calSeries.samples(lastDays: 7)
        var consecutiveHighDays = 0
        let sortedRecent = recent.sorted { $0.date > $1.date }
        for sample in sortedRecent {
            if sample.value > calBaseline.mean * 1.2 {
                consecutiveHighDays += 1
            } else {
                break
            }
        }

        guard consecutiveHighDays >= 3 else { return nil }

        // Check recovery markers
        let hrvDeclining = trends[.heartRateVariability]?.direction == .declining
        let rhrElevated = trends[.restingHeartRate]?.direction == .declining // worse = higher for RHR

        guard hrvDeclining || rhrElevated else { return nil }

        var recoverySignals: [String] = []
        if hrvDeclining {
            let change = String(format: "%.0f", abs(trends[.heartRateVariability]?.weekOverWeekChange ?? 0))
            if let hrvBaseline = baselines[.heartRateVariability] {
                let drop = String(format: "%.0f", hrvBaseline.standardDeviation * abs(trends[.heartRateVariability]?.weekOverWeekChange ?? 0) / 100)
                recoverySignals.append("HRV down \(drop)ms")
            } else {
                recoverySignals.append("HRV down \(change)%")
            }
        }
        if rhrElevated {
            let change = String(format: "%.0f", abs(trends[.restingHeartRate]?.weekOverWeekChange ?? 0))
            if let rhrBaseline = baselines[.restingHeartRate] {
                let rise = String(format: "%.0f", rhrBaseline.mean * abs(trends[.restingHeartRate]?.weekOverWeekChange ?? 0) / 100)
                recoverySignals.append("resting HR up \(rise) bpm")
            } else {
                recoverySignals.append("resting HR up \(change)%")
            }
        }

        let signalText = recoverySignals.joined(separator: ", ")

        return Insight(
            metric: .heartRateVariability,
            title: Copy.Analysis.CognitiveEnergy.recoveryDayNeeded,
            summary: "You've been highly active for \(consecutiveHighDays) days straight and your recovery markers are strained \u{2014} \(signalText). Without recovery, both mental sharpness and physical performance decline.",
            recommendation: Copy.Analysis.CognitiveEnergy.recoveryDayRecommendation,
            severity: .warning,
            trend: .declining,
            currentValue: Double(consecutiveHighDays),
            baselineValue: 3,
            deviationPercent: Double(consecutiveHighDays - 3) / 3.0 * 100,
            category: .cognitiveEnergy,
            relatedMetrics: [.heartRateVariability, .restingHeartRate, .activeCalories]
        )
    }

    // MARK: - 6. Daylight-Sleep-Cognition Chain

    private static func daylightSleepCognitionInsight(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        // Trigger: daylight exposure declining + sleep quality declining
        guard let daylightTrend = trends[.timeInDaylight],
              daylightTrend.direction == .declining,
              abs(daylightTrend.weekOverWeekChange) > 10 else { return nil }

        // Check if sleep quality is also declining
        let deepDeclining = trends[.sleepDeep]?.direction == .declining
        let sleepDeclining = trends[.sleepDuration]?.direction == .declining

        guard deepDeclining || sleepDeclining else { return nil }

        let daylightChange = String(format: "%.0f", abs(daylightTrend.weekOverWeekChange))
        let deepChange: String
        if let deepTrend = trends[.sleepDeep] {
            deepChange = String(format: "%.0f", abs(deepTrend.weekOverWeekChange))
        } else if let sleepTrend = trends[.sleepDuration] {
            deepChange = String(format: "%.0f", abs(sleepTrend.weekOverWeekChange))
        } else {
            deepChange = "10"
        }

        // Check if we have correlation data to back this up
        let daylightEffect = findDaylightSleepEffect(timeSeries: timeSeries)
        let effectNote = daylightEffect.map { " Your data shows that on high-daylight days, your deep sleep is \(String(format: "%.0f", $0))% higher." } ?? ""

        return Insight(
            metric: .timeInDaylight,
            title: Copy.Analysis.CognitiveEnergy.daylightSleepCognitionChain,
            summary: "Your daylight exposure dropped \(daylightChange)% and \(deepDeclining ? "deep sleep" : "sleep duration") declined \(deepChange)% in the same window. These are connected \u{2014} natural light sets your circadian clock, which drives sleep architecture and next-day cognitive clarity.",
            recommendation: "Get 20+ min of outdoor light before noon tomorrow.\(effectNote) This single change impacts your sleep timing, deep sleep percentage, and next-day mental sharpness.",
            severity: .info,
            trend: .declining,
            currentValue: abs(daylightTrend.weekOverWeekChange),
            baselineValue: 0,
            deviationPercent: abs(daylightTrend.weekOverWeekChange),
            category: .cognitiveEnergy,
            relatedMetrics: [.timeInDaylight, .sleepDeep, .sleepDuration, .heartRateVariability]
        )
    }

    // MARK: - Helpers

    /// Find the effect size of steps/activity on resting HR from actual data
    private static func findCorrelation(
        for metric: HealthMetric,
        in timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Double? {
        guard let metricSeries = timeSeries[metric],
              let rhrSeries = timeSeries[.restingHeartRate] else { return nil }

        let aligned = TimeSeriesAligner.alignWithOffset(metricSeries, rhrSeries, dayOffset: 1)
        guard aligned.count >= 14 else { return nil }

        let averageMetric = aligned.mean(of: \.valueA)
        var aboveSum = 0.0
        var belowSum = 0.0
        var aboveCount = 0
        var belowCount = 0

        for pair in aligned {
            if pair.valueA >= averageMetric {
                aboveSum += pair.valueB
                aboveCount += 1
            } else {
                belowSum += pair.valueB
                belowCount += 1
            }
        }

        guard aboveCount > 0, belowCount > 0 else { return nil }

        let rhrAbove = aboveSum / Double(aboveCount)
        let rhrBelow = belowSum / Double(belowCount)

        guard rhrBelow > 0 else { return nil }

        let diff = abs((rhrAbove - rhrBelow) / rhrBelow * 100)
        return diff >= 3 ? diff : nil
    }

    /// Find the effect of daylight on deep sleep from actual data
    private static func findDaylightSleepEffect(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Double? {
        guard let daylightSeries = timeSeries[.timeInDaylight],
              let deepSeries = timeSeries[.sleepDeep] else { return nil }

        let aligned = TimeSeriesAligner.alignByDate(daylightSeries, deepSeries)
        guard aligned.count >= 14 else { return nil }

        let avgDaylight = aligned.mean(of: \.valueA)
        var highSum = 0.0
        var lowSum = 0.0
        var highCount = 0
        var lowCount = 0

        for pair in aligned {
            if pair.valueA >= avgDaylight {
                highSum += pair.valueB
                highCount += 1
            } else {
                lowSum += pair.valueB
                lowCount += 1
            }
        }

        guard highCount > 0, lowCount > 0 else { return nil }

        let deepOnHighDaylight = highSum / Double(highCount)
        let deepOnLowDaylight = lowSum / Double(lowCount)

        guard deepOnLowDaylight > 0 else { return nil }

        let diff = (deepOnHighDaylight - deepOnLowDaylight) / deepOnLowDaylight * 100
        return diff >= 8 ? diff : nil
    }
}

// MARK: - InsightAnalyzer Conformance

extension CognitiveEnergyAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "cognitiveEnergy" }
    static var insightCategory: InsightCategory { .cognitiveEnergy }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(
            timeSeries: context.timeSeries,
            baselines: context.baselines,
            trends: context.trends,
            correlations: context.correlations
        )
    }
}
