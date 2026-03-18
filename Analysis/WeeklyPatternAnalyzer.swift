import Foundation

/// Identifies day-of-week patterns, best/worst days, and weekday vs weekend gaps
struct WeeklyPatternAnalyzer {

    private static let keyMetrics: [HealthMetric] = [
        .steps, .activeCalories, .exerciseMinutes, .sleepDuration, .restingHeartRate, .heartRateVariability
    ]

    private static let weekdaySymbols: [String] = DateFormatter().weekdaySymbols

    /// Analyze weekly patterns and generate insights
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        // --- Weakest Day Insight ---
        if let weakestDayInsight = findWeakestDay(timeSeries: timeSeries) {
            insights.append(weakestDayInsight)
        }

        // --- Weekend vs Weekday Gap ---
        if let gapInsight = analyzeWeekendGap(timeSeries: timeSeries) {
            insights.append(gapInsight)
        }

        // --- Consistency Score ---
        if let consistencyInsight = analyzeWeeklyConsistency(timeSeries: timeSeries) {
            insights.append(consistencyInsight)
        }

        return insights
    }

    // MARK: - Weakest Day (multi-metric)

    private static func findWeakestDay(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Find the weakest day across multiple metrics, not just steps
        let metricsToCheck: [(metric: HealthMetric, label: String)] = [
            (.steps, "steps"), (.activeCalories, "active calories"), (.exerciseMinutes, "exercise minutes")
        ]

        for entry in metricsToCheck {
            guard let series = timeSeries[entry.metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            var dayAverages: [(day: Int, avg: Double)] = []
            for (day, values) in groups {
                guard values.count >= 2 else { continue }
                dayAverages.append((day: day, avg: values.mean))
            }

            guard dayAverages.count >= 5 else { continue }

            dayAverages.sort { $0.avg < $1.avg }
            let overallAvg = dayAverages.mean { $0.avg }

            guard let weakest = dayAverages.first,
                  let strongest = dayAverages.last,
                  overallAvg > 0 else { continue }

            let weakestName = dayName(for: weakest.day)
            let strongestName = dayName(for: strongest.day)
            let deficit = ((overallAvg - weakest.avg) / overallAvg) * 100

            guard deficit >= 10 else { continue }

            return Insight(
                metric: entry.metric,
                title: "Weakest Day: \(weakestName)",
                summary: "\(weakestName) is your least active day with \(entry.metric.formatWithUnit(weakest.avg)) avg — \(String(format: "%.0f", deficit))% below your daily average. \(strongestName) is your strongest (\(entry.metric.formatWithUnit(strongest.avg))).",
                recommendation: "\(weakestName) averages \(entry.metric.formatWithUnit(weakest.avg)) — \(String(format: "%.0f", deficit))% below your daily mean of \(entry.metric.formatWithUnit(overallAvg)). Your strongest day is \(strongestName) at \(entry.metric.formatWithUnit(strongest.avg)).",
                severity: deficit >= 25 ? .warning : .info,
                trend: .stable,
                currentValue: weakest.avg,
                baselineValue: overallAvg,
                deviationPercent: -deficit,
                category: .weeklyPattern,
                relatedMetrics: [entry.metric]
            )
        }
        return nil
    }

    // MARK: - Weekend Gap (multi-metric)

    private static func analyzeWeekendGap(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Check multiple metrics for weekend gaps
        let metricsToCheck: [(metric: HealthMetric, label: String)] = [
            (.steps, "steps"),
            (.exerciseMinutes, "exercise"),
            (.activeCalories, "active calories"),
            (.sleepDuration, "sleep")
        ]

        for entry in metricsToCheck {
            guard let series = timeSeries[entry.metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            var weekdaySum = 0.0
            var weekendSum = 0.0
            var weekdayCount = 0
            var weekendCount = 0

            for day in [2, 3, 4, 5, 6] {
                guard let values = groups[day] else { continue }
                weekdayCount += values.count
                for value in values {
                    weekdaySum += value
                }
            }

            for day in [1, 7] {
                guard let values = groups[day] else { continue }
                weekendCount += values.count
                for value in values {
                    weekendSum += value
                }
            }

            guard weekdayCount >= 5, weekendCount >= 2 else { continue }

            let weekdayAvg = weekdaySum / Double(weekdayCount)
            let weekendAvg = weekendSum / Double(weekendCount)

            guard weekdayAvg > 0 else { continue }

            let gap = ((weekdayAvg - weekendAvg) / weekdayAvg) * 100

            guard abs(gap) >= 15 else { continue }

            let moreActive = gap > 0 ? "weekdays" : "weekends"

            return Insight(
                metric: entry.metric,
                title: "\(entry.metric.displayName): Weekday vs Weekend",
                summary: "Your \(entry.label) is \(String(format: "%.0f", abs(gap)))% higher on \(moreActive). Weekday avg: \(entry.metric.formatWithUnit(weekdayAvg)), weekend avg: \(entry.metric.formatWithUnit(weekendAvg)).",
                recommendation: gap > 20 ?
                    "Weekend \(entry.label) averages \(entry.metric.formatWithUnit(weekendAvg)) vs \(entry.metric.formatWithUnit(weekdayAvg)) on weekdays — a \(String(format: "%.0f", abs(gap)))% gap." :
                    "Weekday avg: \(entry.metric.formatWithUnit(weekdayAvg)), weekend avg: \(entry.metric.formatWithUnit(weekendAvg)) — \(String(format: "%.0f", abs(gap)))% difference.",
                severity: abs(gap) >= 30 ? .warning : .info,
                trend: .stable,
                currentValue: weekendAvg,
                baselineValue: weekdayAvg,
                deviationPercent: -gap,
                category: .weeklyPattern,
                relatedMetrics: [entry.metric]
            )
        }
        return nil
    }

    // MARK: - Weekly Consistency (multi-metric)

    private static func analyzeWeeklyConsistency(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Analyze consistency across the best available metric
        let metricsToCheck: [HealthMetric] = [.steps, .exerciseMinutes, .activeCalories, .sleepDuration]

        for metric in metricsToCheck {
            guard let series = timeSeries[metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            let dayAverages = (1...7).compactMap { day -> Double? in
                let values = groups[day] ?? []
                guard values.count >= 2 else { return nil }
                return values.mean
            }

            guard dayAverages.count >= 5 else { continue }

            let mean = dayAverages.mean
            guard mean > 0 else { continue }

            let cv = dayAverages.standardDeviation / mean * 100

            let isConsistent = cv < 20

            return Insight(
                metric: metric,
                title: "\(metric.displayName) Consistency",
                summary: isConsistent ?
                    "Your \(metric.displayName.lowercased()) is consistent across the week with a coefficient of variation of \(String(format: "%.0f", cv))%." :
                    "Your \(metric.displayName.lowercased()) varies \(String(format: "%.0f", cv))% across the week (coefficient of variation).",
                recommendation: isConsistent ?
                    "Day-to-day variation is \(String(format: "%.0f", cv))% (coefficient of variation) — your \(metric.displayName.lowercased()) is distributed evenly across the week." :
                    "Day-to-day variation is \(String(format: "%.0f", cv))% (coefficient of variation). Your \(metric.displayName.lowercased()) swings significantly between your most and least active days.",
                severity: cv > 35 ? .warning : .info,
                trend: isConsistent ? .improving : .stable,
                currentValue: cv,
                baselineValue: 20,
                deviationPercent: cv - 20,
                category: .weeklyPattern,
                relatedMetrics: [metric]
            )
        }
        return nil
    }

    // MARK: - Helpers

    private static func dayName(for weekday: Int) -> String {
        let index = weekday - 1
        guard index >= 0, index < weekdaySymbols.count else { return "Unknown" }
        return weekdaySymbols[index]  // weekday is 1-indexed
    }
}

/// Maps daily health data against menstrual cycle phases and generates phase-aware guidance.
struct CyclePhaseAnalyzer {

    private enum Phase: String, CaseIterable {
        case menstrual
        case follicular
        case ovulatory
        case luteal

        var displayName: String {
            rawValue.capitalized
        }

        var baselineExpectation: String {
            switch self {
            case .menstrual:
                return "Lower energy and recovery variability can be normal during menstruation."
            case .follicular:
                return "Energy and training readiness often improve through the follicular phase."
            case .ovulatory:
                return "Many people experience peak readiness around ovulation."
            case .luteal:
                return "Slightly lower energy in the luteal phase is common and usually expected."
            }
        }

        var recommendation: String {
            switch self {
            case .menstrual:
                return "Prioritize recovery-first days: lighter training, hydration, and consistent sleep."
            case .follicular:
                return "Use this phase for progressive overload and higher-focus tasks while readiness is trending up."
            case .ovulatory:
                return "Schedule your key workouts here, then protect sleep and hydration to stabilize recovery."
            case .luteal:
                return "Plan slightly lower-intensity sessions, lock in an earlier bedtime, and favor steady routines."
            }
        }
    }

    private struct MenstrualEpisode {
        let start: Date
        let end: Date

        var lengthDays: Int {
            daysBetween(start, end) + 1
        }
    }

    private struct PhaseSnapshot {
        let hrv: Double?
        let restingHeartRate: Double?
        let sleepQuality: Double?
        let activitySteps: Double?
    }

    private struct MetricSignal {
        let metric: HealthMetric
        let label: String
        let current: Double
        let baseline: Double
        let deviationPercent: Double
    }

    static func generateInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        menstrualFlowSamples: [HealthKitManager.MenstrualFlowSample],
        now: Date = Date()
    ) -> [Insight] {
        let episodes = extractMenstrualEpisodes(from: menstrualFlowSamples)
        guard episodes.count >= 2 else { return [] }

        let cycleStarts = episodes.map(\.start).sorted()
        let cycleLengths = zip(cycleStarts.dropLast(), cycleStarts.dropFirst())
            .map { daysBetween($0, $1) }
            .filter { (18...45).contains($0) }

        let estimatedCycleLength = clamp(median(cycleLengths) ?? 28, min: 21, max: 40)
        let estimatedMenstrualLength = clamp(
            median(episodes.map(\.lengthDays).filter { (2...10).contains($0) }) ?? 5,
            min: 3,
            max: 8
        )

        guard let latestCycleStart = cycleStarts.last else { return [] }
        let dayInCycle = daysBetween(latestCycleStart, now.startOfDay) + 1
        guard dayInCycle >= 1 else { return [] }

        let currentPhase = phase(
            forCycleDay: dayInCycle,
            cycleLength: estimatedCycleLength,
            menstrualLength: estimatedMenstrualLength
        )

        let windowStart = now.daysAgo(180).startOfDay
        let phaseByDate = assignPhases(
            from: windowStart,
            to: now.startOfDay,
            cycleStarts: cycleStarts,
            fallbackCycleLength: estimatedCycleLength,
            menstrualLength: estimatedMenstrualLength
        )
        guard phaseByDate.count >= 20 else { return [] }

        let stepsMap = dailyValueMap(for: .steps, timeSeries: timeSeries)
        let hrvMap = dailyValueMap(for: .heartRateVariability, timeSeries: timeSeries)
        let restingHRMap = dailyValueMap(for: .restingHeartRate, timeSeries: timeSeries)
        let sleepDurationMap = dailyValueMap(for: .sleepDuration, timeSeries: timeSeries)
        let sleepDeepMap = dailyValueMap(for: .sleepDeep, timeSeries: timeSeries)
        let sleepRemMap = dailyValueMap(for: .sleepREM, timeSeries: timeSeries)
        let sleepQualityMap = buildSleepQualityMap(
            duration: sleepDurationMap,
            deep: sleepDeepMap,
            rem: sleepRemMap
        )

        let allTrackedDates = Array(phaseByDate.keys)
        let overallSnapshot = PhaseSnapshot(
            hrv: mean(on: allTrackedDates, from: hrvMap),
            restingHeartRate: mean(on: allTrackedDates, from: restingHRMap),
            sleepQuality: mean(on: allTrackedDates, from: sleepQualityMap),
            activitySteps: mean(on: allTrackedDates, from: stepsMap)
        )

        let currentPhaseDates = phaseByDate.compactMap { date, phase in
            phase == currentPhase ? date : nil
        }
        guard currentPhaseDates.count >= 4 else { return [] }

        let currentSnapshot = PhaseSnapshot(
            hrv: mean(on: currentPhaseDates, from: hrvMap),
            restingHeartRate: mean(on: currentPhaseDates, from: restingHRMap),
            sleepQuality: mean(on: currentPhaseDates, from: sleepQualityMap),
            activitySteps: mean(on: currentPhaseDates, from: stepsMap)
        )

        let signals = metricSignals(current: currentSnapshot, baseline: overallSnapshot)
        guard let primarySignal = signals.max(by: { abs($0.deviationPercent) < abs($1.deviationPercent) }) else {
            return []
        }

        let deviations = Dictionary(uniqueKeysWithValues: signals.map { ($0.metric, $0.deviationPercent) })
        let highLoadShift =
            (deviations[.restingHeartRate] ?? 0) >= 8 ||
            (deviations[.heartRateVariability] ?? 0) <= -12 ||
            (deviations[.steps] ?? 0) <= -20 ||
            (deviations[.sleepDuration] ?? 0) <= -15

        let severity: Severity = highLoadShift ? .warning : .info
        let trend = trendDirection(for: primarySignal)

        let highlights = signals
            .sorted { abs($0.deviationPercent) > abs($1.deviationPercent) }
            .prefix(3)
            .map { signal in
                let direction = signal.deviationPercent >= 0 ? "up" : "down"
                return "\(signal.label) \(direction) \(String(format: "%.0f", abs(signal.deviationPercent)))%"
            }

        var summary = "You're in your \(currentPhase.rawValue) phase (day \(dayInCycle) of ~\(estimatedCycleLength)). \(currentPhase.baselineExpectation)"
        if !highlights.isEmpty {
            summary += " Compared with your cycle average: \(highlights.joined(separator: ", "))."
        }

        var recommendation = currentPhase.recommendation
        if highLoadShift {
            recommendation += " Your current shift is stronger than your norm, so scale intensity for 48 hours and monitor how you feel."
        } else {
            recommendation += " Keep logging daily so the phase model can keep adapting to your own baseline."
        }

        let relatedMetrics = signals.map(\.metric)

        let insight = Insight(
            metric: primarySignal.metric,
            title: "Cycle Phase Analyzer: \(currentPhase.displayName)",
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: primarySignal.current,
            baselineValue: primarySignal.baseline,
            deviationPercent: primarySignal.deviationPercent,
            category: .cyclePhase,
            relatedMetrics: relatedMetrics
        )
        return [insight]
    }

    private static func extractMenstrualEpisodes(
        from samples: [HealthKitManager.MenstrualFlowSample]
    ) -> [MenstrualEpisode] {
        let bleedingDays = Array(Set(
            samples
                .filter(\.isBleedingDay)
                .map(\.day)
        )).sorted()

        guard !bleedingDays.isEmpty else { return [] }

        var episodes: [MenstrualEpisode] = []
        var episodeStart = bleedingDays[0]
        var episodeEnd = bleedingDays[0]

        for day in bleedingDays.dropFirst() {
            if daysBetween(episodeEnd, day) <= 1 {
                episodeEnd = day
            } else {
                episodes.append(MenstrualEpisode(start: episodeStart, end: episodeEnd))
                episodeStart = day
                episodeEnd = day
            }
        }
        episodes.append(MenstrualEpisode(start: episodeStart, end: episodeEnd))

        return episodes.filter { (2...10).contains($0.lengthDays) }
    }

    private static func assignPhases(
        from startDate: Date,
        to endDate: Date,
        cycleStarts: [Date],
        fallbackCycleLength: Int,
        menstrualLength: Int
    ) -> [Date: Phase] {
        guard !cycleStarts.isEmpty else { return [:] }

        var phaseByDay: [Date: Phase] = [:]
        var day = startDate.startOfDay

        while day <= endDate {
            guard let startIndex = cycleStarts.lastIndex(where: { $0 <= day }) else {
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
                continue
            }

            let cycleStart = cycleStarts[startIndex]
            let nextStart = (startIndex + 1) < cycleStarts.count ? cycleStarts[startIndex + 1] : nil
            let cycleLength = clamp(
                nextStart.map { daysBetween(cycleStart, $0) } ?? fallbackCycleLength,
                min: 21,
                max: 40
            )
            let dayInCycle = daysBetween(cycleStart, day) + 1
            phaseByDay[day] = phase(
                forCycleDay: dayInCycle,
                cycleLength: cycleLength,
                menstrualLength: menstrualLength
            )

            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        }

        return phaseByDay
    }

    private static func phase(forCycleDay day: Int, cycleLength: Int, menstrualLength: Int) -> Phase {
        if day <= menstrualLength {
            return .menstrual
        }

        let ovulationCenter = clamp(cycleLength - 14, min: menstrualLength + 3, max: cycleLength - 6)
        let ovulationStart = max(menstrualLength + 1, ovulationCenter - 1)
        let ovulationEnd = min(cycleLength, ovulationCenter + 1)

        if day < ovulationStart {
            return .follicular
        }
        if day <= ovulationEnd {
            return .ovulatory
        }
        return .luteal
    }

    private static func metricSignals(current: PhaseSnapshot, baseline: PhaseSnapshot) -> [MetricSignal] {
        var signals: [MetricSignal] = []

        if let currentHRV = current.hrv, let baselineHRV = baseline.hrv, baselineHRV > 0 {
            signals.append(MetricSignal(
                metric: .heartRateVariability,
                label: "HRV",
                current: currentHRV,
                baseline: baselineHRV,
                deviationPercent: percentChange(current: currentHRV, baseline: baselineHRV)
            ))
        }
        if let currentRHR = current.restingHeartRate, let baselineRHR = baseline.restingHeartRate, baselineRHR > 0 {
            signals.append(MetricSignal(
                metric: .restingHeartRate,
                label: "Resting HR",
                current: currentRHR,
                baseline: baselineRHR,
                deviationPercent: percentChange(current: currentRHR, baseline: baselineRHR)
            ))
        }
        if let currentSleepQuality = current.sleepQuality,
           let baselineSleepQuality = baseline.sleepQuality,
           baselineSleepQuality > 0 {
            signals.append(MetricSignal(
                metric: .sleepDuration,
                label: "Sleep quality",
                current: currentSleepQuality,
                baseline: baselineSleepQuality,
                deviationPercent: percentChange(current: currentSleepQuality, baseline: baselineSleepQuality)
            ))
        }
        if let currentSteps = current.activitySteps, let baselineSteps = baseline.activitySteps, baselineSteps > 0 {
            signals.append(MetricSignal(
                metric: .steps,
                label: "Activity",
                current: currentSteps,
                baseline: baselineSteps,
                deviationPercent: percentChange(current: currentSteps, baseline: baselineSteps)
            ))
        }

        return signals
    }

    private static func trendDirection(for signal: MetricSignal) -> TrendDirection {
        guard abs(signal.deviationPercent) >= 4 else { return .stable }
        if signal.metric.higherIsBetter {
            return signal.deviationPercent >= 0 ? .improving : .declining
        }
        return signal.deviationPercent <= 0 ? .improving : .declining
    }

    private static func buildSleepQualityMap(
        duration: [Date: Double],
        deep: [Date: Double],
        rem: [Date: Double]
    ) -> [Date: Double] {
        let candidateDays = Set(duration.keys)
        var quality: [Date: Double] = [:]

        for day in candidateDays {
            guard let sleepDuration = duration[day], sleepDuration >= 3 else { continue }
            let restorativeSleep = (deep[day] ?? 0) + (rem[day] ?? 0)
            guard restorativeSleep > 0 else { continue }

            let ratio = min(max(restorativeSleep / sleepDuration, 0), 1.0)
            quality[day] = ratio * 100
        }
        return quality
    }

    private static func dailyValueMap(
        for metric: HealthMetric,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Date: Double] {
        guard let series = timeSeries[metric] else { return [:] }
        var buckets: [Date: [Double]] = [:]
        for sample in series.sortedSamples {
            buckets[sample.date.startOfDay, default: []].append(sample.value)
        }
        return buckets.mapValues(\.mean)
    }

    private static func mean(on dates: [Date], from map: [Date: Double]) -> Double? {
        let values = dates.compactMap { map[$0] }
        guard values.count >= 3 else { return nil }
        return values.mean
    }

    private static func percentChange(current: Double, baseline: Double) -> Double {
        guard baseline != 0 else { return 0 }
        return ((current - baseline) / baseline) * 100
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day ?? 0
    }
}

// MARK: - InsightAnalyzer Conformance

extension WeeklyPatternAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "weeklyPattern" }
    static var insightCategory: InsightCategory { .weeklyPattern }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(timeSeries: context.timeSeries)
    }
}

extension CyclePhaseAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "cyclePhase" }
    static var insightCategory: InsightCategory { .cyclePhase }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(
            timeSeries: context.timeSeries,
            menstrualFlowSamples: context.cycleFlowSamples
        )
    }
}
