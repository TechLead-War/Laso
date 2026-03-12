import Foundation

/// Generates cycle-phase-aware health insights by segmenting metric data across
/// completed menstrual cycles and comparing per-phase averages to overall baselines.
struct CycleInsightAnalyzer {

    // MARK: - CycleInsight

    /// A single phase-specific finding for one metric, including the raw numbers
    /// and human-readable insight plus actionable recommendation.
    struct CycleInsight: Identifiable {
        let id = UUID()
        let phase: MenstrualCycleTracker.CyclePhase
        let metric: HealthMetric
        let insight: String
        let recommendation: String
        let averageInPhase: Double
        let overallAverage: Double
        let percentDifference: Double
    }

    // MARK: - Configuration

    /// Metrics worth analyzing across cycle phases.
    private static let trackedMetrics: [HealthMetric] = [
        .heartRateVariability,
        .restingHeartRate,
        .sleepDuration,
        .sleepDeep,
        .activeCalories,
        .exerciseMinutes,
        .steps
    ]

    /// Minimum completed cycles required to produce meaningful insights.
    private static let minimumCompletedCycles = 2

    /// Phase average must differ from overall average by at least this fraction to generate an insight.
    private static let significanceThreshold = 0.10

    // MARK: - Analysis Entry Point

    /// Analyze health metrics across completed menstrual cycles and return
    /// insights where a phase average differs by more than 10% from the overall average.
    ///
    /// - Parameters:
    ///   - cycleInfo: The user's current cycle state (used for context, not required for history).
    ///   - store: The health data store providing per-metric time series.
    ///   - cycleHistory: Completed cycle records with start dates and lengths (days).
    /// - Returns: Array of `CycleInsight` values, sorted by absolute percent difference descending.
    static func analyze(
        cycleInfo: MenstrualCycleTracker.CycleInfo,
        store: HealthDataStore,
        cycleHistory: [(startDate: Date, length: Int)]
    ) -> [CycleInsight] {
        // Need at least 2 complete cycles for meaningful analysis
        let completedCycles = cycleHistory.filter { $0.length >= 18 && $0.length <= 45 }
        guard completedCycles.count >= minimumCompletedCycles else { return [] }

        // Build a date-to-phase mapping across all completed cycles
        let phaseMap = buildPhaseMap(from: completedCycles)
        guard !phaseMap.isEmpty else { return [] }

        // For each tracked metric, compute per-phase and overall averages
        var insights: [CycleInsight] = []

        for metric in trackedMetrics {
            guard let series = store.loadTimeSeries(for: metric) else { continue }

            let phaseBuckets = bucketSamplesByPhase(series: series, phaseMap: phaseMap)
            let allPhasedValues = phaseBuckets.values.flatMap { $0 }
            guard !allPhasedValues.isEmpty else { continue }

            let overallAverage = allPhasedValues.mean

            guard overallAverage > 0 else { continue }

            for phase in MenstrualCycleTracker.CyclePhase.allCases {
                guard let values = phaseBuckets[phase], values.count >= 3 else { continue }

                let phaseAverage = values.mean
                let percentDiff = ((phaseAverage - overallAverage) / overallAverage) * 100.0

                guard abs(percentDiff) > significanceThreshold * 100.0 else { continue }

                let insightText = generateInsightText(
                    phase: phase,
                    metric: metric,
                    percentDiff: percentDiff
                )
                let recommendation = generateRecommendation(
                    phase: phase,
                    metric: metric,
                    percentDiff: percentDiff
                )

                insights.append(CycleInsight(
                    phase: phase,
                    metric: metric,
                    insight: insightText,
                    recommendation: recommendation,
                    averageInPhase: phaseAverage,
                    overallAverage: overallAverage,
                    percentDifference: percentDiff
                ))
            }
        }

        // Sort by magnitude of difference — most notable insights first
        return insights.sorted { abs($0.percentDifference) > abs($1.percentDifference) }
    }

    // MARK: - Phase Mapping

    /// Builds a dictionary from calendar date to cycle phase for all completed cycles.
    private static func buildPhaseMap(
        from cycles: [(startDate: Date, length: Int)]
    ) -> [Date: MenstrualCycleTracker.CyclePhase] {
        let calendar = Calendar.current
        var map: [Date: MenstrualCycleTracker.CyclePhase] = [:]

        for cycle in cycles {
            let length = cycle.length
            let phaseBoundaries = computePhaseBoundaries(cycleLength: length)

            for dayOffset in 0..<length {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycle.startDate) else {
                    continue
                }
                let day = calendar.startOfDay(for: date)
                let cycleDay = dayOffset + 1 // 1-indexed
                map[day] = phaseForDay(cycleDay, boundaries: phaseBoundaries)
            }
        }

        return map
    }

    /// Phase day boundaries based on cycle length.
    private struct PhaseBoundaries {
        let menstrualEnd: Int      // last day of menstrual phase
        let follicularEnd: Int     // last day of follicular phase
        let ovulationEnd: Int      // last day of ovulation phase
        // luteal runs from ovulationEnd+1 through cycle end
    }

    private static func computePhaseBoundaries(cycleLength: Int) -> PhaseBoundaries {
        // Menstrual: ~days 1-5 (scales slightly with cycle length)
        let menstrualEnd = max(3, min(7, Int(round(Double(cycleLength) * 5.0 / 28.0))))

        // Ovulation window: centered around day cycleLength-14
        let ovulationCenter = max(menstrualEnd + 3, cycleLength - 14)
        let ovulationStart = max(menstrualEnd + 1, ovulationCenter - 1)
        let ovulationEnd = min(cycleLength, ovulationCenter + 1)

        // Follicular: from menstrualEnd+1 to ovulationStart-1
        let follicularEnd = ovulationStart - 1

        return PhaseBoundaries(
            menstrualEnd: menstrualEnd,
            follicularEnd: follicularEnd,
            ovulationEnd: ovulationEnd
        )
    }

    private static func phaseForDay(
        _ cycleDay: Int,
        boundaries: PhaseBoundaries
    ) -> MenstrualCycleTracker.CyclePhase {
        if cycleDay <= boundaries.menstrualEnd {
            return .menstrual
        } else if cycleDay <= boundaries.follicularEnd {
            return .follicular
        } else if cycleDay <= boundaries.ovulationEnd {
            return .ovulation
        } else {
            return .luteal
        }
    }

    // MARK: - Sample Bucketing

    /// Groups metric sample values by their corresponding cycle phase.
    private static func bucketSamplesByPhase(
        series: MetricTimeSeries,
        phaseMap: [Date: MenstrualCycleTracker.CyclePhase]
    ) -> [MenstrualCycleTracker.CyclePhase: [Double]] {
        let calendar = Calendar.current
        var buckets: [MenstrualCycleTracker.CyclePhase: [Double]] = [:]

        for sample in series.samples {
            let day = calendar.startOfDay(for: sample.date)
            guard let phase = phaseMap[day] else { continue }
            buckets[phase, default: []].append(sample.value)
        }

        return buckets
    }

    // MARK: - Insight Text Generation

    private static func generateInsightText(
        phase: MenstrualCycleTracker.CyclePhase,
        metric: HealthMetric,
        percentDiff: Double
    ) -> String {
        let direction = percentDiff > 0 ? "increases" : "drops"
        let magnitude = String(format: "%.0f", abs(percentDiff))
        let metricName = metric.displayName

        switch phase {
        case .menstrual:
            return "Your \(metricName) \(direction) \(magnitude)% during menstruation compared to your cycle average."
        case .follicular:
            return "Your \(metricName) \(direction) \(magnitude)% during your follicular phase, when estrogen is rising."
        case .ovulation:
            return "Your \(metricName) \(direction) \(magnitude)% around ovulation, when energy tends to peak."
        case .luteal:
            return "Your \(metricName) \(direction) \(magnitude)% in your luteal phase, when progesterone is elevated."
        }
    }

    private static func generateRecommendation(
        phase: MenstrualCycleTracker.CyclePhase,
        metric: HealthMetric,
        percentDiff: Double
    ) -> String {
        switch phase {
        case .menstrual:
            return menstrualRecommendation(metric: metric, percentDiff: percentDiff)
        case .follicular:
            return follicularRecommendation(metric: metric, percentDiff: percentDiff)
        case .ovulation:
            return ovulationRecommendation(metric: metric, percentDiff: percentDiff)
        case .luteal:
            return lutealRecommendation(metric: metric, percentDiff: percentDiff)
        }
    }

    // MARK: - Phase-Specific Data Observations

    private static func menstrualRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        let changeStr = String(format: "%.0f%%", abs(percentDiff))
        let direction = percentDiff > 0 ? "higher" : "lower"
        switch metric {
        case .heartRateVariability:
            return "Your HRV typically runs \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .restingHeartRate:
            return "Your resting heart rate runs \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .sleepDuration:
            return "Your sleep duration is \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .sleepDeep:
            return "Your deep sleep is \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .activeCalories:
            return "Your active calorie burn is \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .exerciseMinutes:
            return "Your exercise minutes are \(changeStr) \(direction) during menstruation compared to your cycle average."
        case .steps:
            return "Your step count is \(changeStr) \(direction) during menstruation compared to your cycle average."
        default:
            return "Your \(metric.displayName) is \(changeStr) \(direction) during menstruation compared to your cycle average."
        }
    }

    private static func follicularRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        let changeStr = String(format: "%.0f%%", abs(percentDiff))
        let direction = percentDiff > 0 ? "higher" : "lower"
        switch metric {
        case .heartRateVariability:
            return "Your HRV typically peaks during your follicular phase — \(changeStr) \(direction) than your cycle average."
        case .restingHeartRate:
            return "Your resting heart rate is \(changeStr) \(direction) during your follicular phase compared to your cycle average."
        case .sleepDuration, .sleepDeep:
            return "Your \(metric.displayName.lowercased()) is \(changeStr) \(direction) during your follicular phase compared to your cycle average."
        case .activeCalories, .exerciseMinutes:
            return "Your \(metric.displayName.lowercased()) is \(changeStr) \(direction) during your follicular phase — your highest-output phase in your data."
        case .steps:
            return "Your step count is \(changeStr) \(direction) during your follicular phase compared to your cycle average."
        default:
            return "Your \(metric.displayName) is \(changeStr) \(direction) during your follicular phase compared to your cycle average."
        }
    }

    private static func ovulationRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        let changeStr = String(format: "%.0f%%", abs(percentDiff))
        let direction = percentDiff > 0 ? "higher" : "lower"
        switch metric {
        case .heartRateVariability:
            return "Your HRV shifts \(changeStr) \(direction) around ovulation compared to your cycle average."
        case .restingHeartRate:
            return "Your resting heart rate is \(changeStr) \(direction) around ovulation compared to your cycle average."
        case .activeCalories:
            return "Your active calorie burn is \(changeStr) \(direction) around ovulation compared to your cycle average."
        case .exerciseMinutes:
            return "Your exercise minutes are \(changeStr) \(direction) around ovulation compared to your cycle average."
        case .steps:
            return "Your step count is \(changeStr) \(direction) around ovulation compared to your cycle average."
        case .sleepDuration, .sleepDeep:
            return "Your \(metric.displayName.lowercased()) is \(changeStr) \(direction) around ovulation compared to your cycle average."
        default:
            return "Your \(metric.displayName) is \(changeStr) \(direction) around ovulation compared to your cycle average."
        }
    }

    private static func lutealRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        let changeStr = String(format: "%.0f%%", abs(percentDiff))
        let direction = percentDiff > 0 ? "higher" : "lower"
        switch metric {
        case .heartRateVariability:
            return "Your HRV runs \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .restingHeartRate:
            return "Your resting heart rate is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .sleepDuration:
            return "Your sleep duration is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .sleepDeep:
            return "Your deep sleep is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .activeCalories:
            return "Your active calorie burn is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .exerciseMinutes:
            return "Your exercise minutes are \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        case .steps:
            return "Your step count is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        default:
            return "Your \(metric.displayName) is \(changeStr) \(direction) in your luteal phase compared to your cycle average."
        }
    }
}
