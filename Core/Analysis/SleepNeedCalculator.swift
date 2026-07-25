import Foundation

// MARK: - Performance Level

enum PerformanceLevel: String, CaseIterable, Sendable {
    case peak
    case perform
    case getBy

    /// Base sleep need per level (replaces the old multiplier approach)
    var baseHours: Double {
        switch self {
        case .peak: 7.5
        case .perform: 7.0
        case .getBy: 6.5
        }
    }
}

// MARK: - Sleep Need

struct SleepNeed {
    let totalHoursNeeded: Double
    let recommendedBedtime: Date?
    let recommendedWakeTime: Date?
}

// MARK: - Sleep Need Calculator

@Observable
final class SleepNeedCalculator {

    // MARK: - Public State

    private(set) var currentNeed: SleepNeed?
    private(set) var isReady: Bool = false
    private(set) var sleepConsistencyScore: Double = 0

    // MARK: - Constants

    private typealias Cfg = SleepNeedConfig

    // Bedtime is rendered on the Sleep tile, so it must follow the
    // user's clock preference (12h vs 24h, AM/PM symbols). The Date.FormatStyle
    // path below uses `Locale.current` automatically and Foundation caches
    // the underlying formatter, so the per-call cost is negligible — no
    // explicit DateFormatter cache needed.

    // MARK: - Compute

    @MainActor
    func compute(
        from store: HealthDataStore,
        currentStrain: Double,
        sleepDebt: Double,
        targetWakeTime: Date?,
        performanceLevel: PerformanceLevel = .peak,
        age: Int = 30,
        recoveryScore: Double = 70,
        sleepSeries: MetricTimeSeries? = nil
    ) -> SleepNeed {
        guard let sleepSeries = sleepSeries ?? store.loadTimeSeries(for: .sleepDuration) else {
            return fallbackNeed(performanceLevel: performanceLevel)
        }

        let recentSamples = sleepSeries.samples(lastDays: Cfg.minimumDaysRequired)
        isReady = recentSamples.count >= Cfg.minimumDaysRequired

        let base = performanceLevel.baseHours

        let ageAdjustment: Double
        if age < Cfg.ageYoungAdultUpper {
            ageAdjustment = Cfg.ageYoungAdultAdjustment
        } else if age <= Cfg.ageOlderAdultLower {
            ageAdjustment = 0
        } else {
            ageAdjustment = Cfg.ageOlderAdultAdjustment
        }

        let recoveryAdjustment: Double
        if recoveryScore < Cfg.recoveryLowCeiling {
            recoveryAdjustment = Cfg.recoveryLowAdjustment
        } else if recoveryScore < Cfg.recoveryModerateCeiling {
            recoveryAdjustment = Cfg.recoveryModerateAdjustment
        } else if recoveryScore < Cfg.recoveryGoodCeiling {
            recoveryAdjustment = 0
        } else {
            recoveryAdjustment = Cfg.recoveryExcellentAdjustment
        }

        let strainAdjustment: Double
        if currentStrain > Cfg.strainHeavyFloor {
            strainAdjustment = Cfg.strainHeavyAdjustment
        } else if currentStrain > Cfg.strainModerateFloor {
            strainAdjustment = Cfg.strainModerateAdjustment
        } else {
            strainAdjustment = 0
        }

        let debtAdjustment = sleepDebt > 0 ? Cfg.maxDebtAdjustment : 0.0

        let trendAdjustment = sleepQualityDeclining(sleepSeries) ? Cfg.qualityTrendAdjustment : 0.0

        let rawTotal = base + ageAdjustment + recoveryAdjustment + strainAdjustment + debtAdjustment + trendAdjustment
        let totalHoursNeeded = min(max(rawTotal, Cfg.floorHours), Cfg.ceilingHours)

        // Wake time: use circadian-optimal or estimate from 14-day average
        let wakeTime = targetWakeTime ?? estimateWakeTime(from: sleepSeries)

        // Bedtime: wake time minus total need
        let recommendedBedtime: Date?
        if let wake = wakeTime {
            recommendedBedtime = wake.addingTimeInterval(-totalHoursNeeded * 3600)
        } else {
            recommendedBedtime = nil
        }

        // Consistency score
        sleepConsistencyScore = computeConsistencyScore(from: sleepSeries)

        let need = SleepNeed(
            totalHoursNeeded: totalHoursNeeded,
            recommendedBedtime: recommendedBedtime,
            recommendedWakeTime: wakeTime
        )

        currentNeed = need
        return need
    }

    // MARK: - Private Helpers

    /// Check if sleep quality has been declining over the last 7 days
    /// compared to the 30-day average.
    private func sleepQualityDeclining(_ sleepSeries: MetricTimeSeries) -> Bool {
        let recent = sleepSeries.samples(lastDays: Cfg.qualityTrendRecentWindowDays)
        let baseline = sleepSeries.samples(lastDays: Cfg.qualityTrendBaselineWindowDays)
        guard recent.count >= Cfg.qualityTrendRecentMinSamples,
              baseline.count >= Cfg.qualityTrendBaselineMinSamples else { return false }

        let recentAvg = recent.valueMean
        let baselineAvg = baseline.valueMean

        return baselineAvg - recentAvg > Cfg.qualityTrendDecliningGapHours
    }

    private func estimateWakeTime(from sleepSeries: MetricTimeSeries) -> Date? {
        let recentSamples = sleepSeries.samples(lastDays: Cfg.wakeTimeWindowDays)
        guard recentSamples.count >= Cfg.wakeTimeMinSamples else { return nil }

        // Estimate wake time from sleep end: sample date represents the sleep period end.
        // Compute average wake hour across recent samples.
        let calendar = Date.cal
        var totalMinutesFromMidnight = 0.0

        for sample in recentSamples {
            let components = calendar.dateComponents([.hour, .minute], from: sample.date)
            let minutesFromMidnight = Double(components.hour ?? 7) * 60 + Double(components.minute ?? 0)
            totalMinutesFromMidnight += minutesFromMidnight
        }

        let avgMinutes = totalMinutesFromMidnight / Double(recentSamples.count)
        let avgHour = Int(avgMinutes) / 60
        let avgMinute = Int(avgMinutes) % 60

        // Project to tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else {
            return nil
        }
        return calendar.date(bySettingHour: avgHour, minute: avgMinute, second: 0, of: tomorrow)
    }

    private func computeConsistencyScore(from sleepSeries: MetricTimeSeries) -> Double {
        let samples = sleepSeries.samples(lastDays: Cfg.baselineWindowDays)
        guard samples.count >= Cfg.minimumDaysRequired else { return 0 }

        // Duration consistency: lower standard deviation = higher score
        let values = samples.map(\.value)
        let mean = values.mean(of: \.self)
        guard mean > 0 else { return 0 }

        let variance = values.reduce(0.0) { sum, val in
            let delta = val - mean
            return sum + delta * delta
        } / Double(values.count)
        let stdDev = variance.squareRoot()

        let cv = stdDev / mean
        let score = max(Cfg.consistencyMinScore, min(Cfg.consistencyMaxScore, (1.0 - cv / Cfg.consistencyCVZeroScoreThreshold) * Cfg.consistencyMaxScore))

        // Timing consistency from sample dates
        let calendar = Date.cal
        var bedtimeMinutes: [Double] = []

        for sample in samples {
            // Estimate bedtime by subtracting sleep duration from sample date
            let sleepHours = sample.value
            let estimatedBedtime = sample.date.addingTimeInterval(-sleepHours * 3600)
            let components = calendar.dateComponents([.hour, .minute], from: estimatedBedtime)
            var minutesFromMidnight = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
            // Bedtimes after 6 PM are treated as a negative offset from midnight.
            if minutesFromMidnight > Cfg.bedtimeWrapAroundThresholdMinutes {
                minutesFromMidnight -= Cfg.minutesPerDay
            }
            bedtimeMinutes.append(minutesFromMidnight)
        }

        guard !bedtimeMinutes.isEmpty else { return score }

        let bedtimeMean = bedtimeMinutes.reduce(0, +) / Double(bedtimeMinutes.count)
        let bedtimeVariance = bedtimeMinutes.reduce(0.0) { sum, val in
            let delta = val - bedtimeMean
            return sum + delta * delta
        } / Double(bedtimeMinutes.count)
        let bedtimeStdDev = bedtimeVariance.squareRoot()

        let timingScore = max(Cfg.consistencyMinScore, min(Cfg.consistencyMaxScore, (1.0 - bedtimeStdDev / Cfg.timingStdDevZeroScoreMinutes) * Cfg.consistencyMaxScore))

        return score * Cfg.consistencyDurationWeight + timingScore * Cfg.consistencyTimingWeight
    }

    private func fallbackNeed(performanceLevel: PerformanceLevel) -> SleepNeed {
        SleepNeed(
            totalHoursNeeded: performanceLevel.baseHours,
            recommendedBedtime: nil,
            recommendedWakeTime: nil
        )
    }
}
