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

    // MARK: - Phase-Specific Recommendations

    private static func menstrualRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        switch metric {
        case .heartRateVariability:
            return "Light exercise and extra rest support recovery when HRV is lower during menstruation. Focus on gentle movement like walking or yoga."
        case .restingHeartRate:
            if percentDiff > 0 {
                return "A higher resting heart rate during menstruation is common. Prioritize hydration, reduce caffeine, and allow more recovery time."
            }
            return "Your resting heart rate stays lower during menstruation, suggesting good cardiovascular adaptation. Maintain your current recovery routine."
        case .sleepDuration:
            return "If sleep dips during your period, try going to bed 30 minutes earlier and keeping your room cool. Magnesium-rich foods may help."
        case .sleepDeep:
            return "Deep sleep can be affected by menstrual discomfort. A consistent bedtime routine and avoiding screens before bed can help protect sleep quality."
        case .activeCalories:
            return "Lower calorie burn during menstruation is expected. Focus on gentle movement and listen to your body rather than pushing for intensity."
        case .exerciseMinutes:
            return "Light exercise like walking, stretching, or yoga during menstruation supports recovery without overloading your system."
        case .steps:
            return "Reduced activity during menstruation is normal. Short walks throughout the day can maintain circulation without adding fatigue."
        default:
            return "During menstruation, prioritize recovery and listen to your body. Light activity and extra rest support your cycle."
        }
    }

    private static func follicularRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        switch metric {
        case .heartRateVariability:
            return "Rising HRV in the follicular phase signals readiness. This is a great window for progressive training and challenging workouts."
        case .restingHeartRate:
            return "Your cardiovascular system is well-recovered in this phase. Take advantage for higher-intensity sessions."
        case .sleepDuration, .sleepDeep:
            return "Sleep quality often improves in the follicular phase. Use this energy boost for focused training and skill work."
        case .activeCalories, .exerciseMinutes:
            return "Energy peaks during your follicular phase. Great time for intense training, progressive overload, and trying new activities."
        case .steps:
            return "Higher natural activity in this phase supports fitness goals. Consider adding extra walks or active commuting."
        default:
            return "The follicular phase is your performance window. Schedule demanding workouts and high-focus tasks here."
        }
    }

    private static func ovulationRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        switch metric {
        case .heartRateVariability:
            return "HRV can shift around ovulation. Monitor readiness and adjust intensity based on how you feel day to day."
        case .restingHeartRate:
            return "Heart rate changes near ovulation are normal hormonal responses. Stay hydrated and maintain consistent sleep timing."
        case .activeCalories:
            return "You burn more calories around ovulation. Leverage this for challenging workouts and ensure adequate fueling."
        case .exerciseMinutes:
            return "Peak energy around ovulation supports longer training sessions. Schedule your key workouts in this window."
        case .steps:
            return "Higher natural movement around ovulation is common. Channel this energy into purposeful activity."
        case .sleepDuration, .sleepDeep:
            return "Protect sleep quality around ovulation by maintaining your bedtime routine, even when energy feels high."
        default:
            return "Ovulation often brings peak performance capacity. Schedule important workouts and protect recovery with good sleep."
        }
    }

    private static func lutealRecommendation(metric: HealthMetric, percentDiff: Double) -> String {
        switch metric {
        case .heartRateVariability:
            return "Lower HRV in the luteal phase is a normal progesterone response. Favor moderate intensity and prioritize recovery."
        case .restingHeartRate:
            if percentDiff > 0 {
                return "Elevated resting heart rate in the luteal phase is expected. Reduce training intensity and focus on stress management."
            }
            return "Your resting heart rate stays stable in the luteal phase, which is a positive sign. Keep up your recovery practices."
        case .sleepDuration:
            return "Sleep quality can drop in your luteal phase. Consider earlier bedtimes, limit evening screen time, and try calming activities before sleep."
        case .sleepDeep:
            return "Deep sleep often decreases in the luteal phase. A cool sleeping environment and consistent wind-down routine can help preserve sleep quality."
        case .activeCalories:
            return "Your basal metabolic rate increases slightly in the luteal phase. Ensure adequate nutrition and avoid extreme calorie restriction."
        case .exerciseMinutes:
            return "Favor steady-state cardio and moderate strength work over high-intensity intervals in the luteal phase. Your body recovers more slowly."
        case .steps:
            return "If daily activity drops in the luteal phase, short walks after meals can maintain movement without adding stress."
        default:
            return "The luteal phase favors moderate activity, earlier bedtimes, and steady routines. Adjust expectations and listen to your body."
        }
    }
}
