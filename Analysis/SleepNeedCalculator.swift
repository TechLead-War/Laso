import Foundation

// MARK: - Performance Level

enum PerformanceLevel: String, CaseIterable, Sendable {
    case peak
    case perform
    case getBy

    var displayName: String {
        switch self {
        case .peak: "Peak"
        case .perform: "Perform"
        case .getBy: "Get By"
        }
    }

    var description: String {
        switch self {
        case .peak: "Maximize next-day cognitive and physical performance"
        case .perform: "Solid performance with good energy throughout the day"
        case .getBy: "Minimum viable sleep to function adequately"
        }
    }

    var multiplier: Double {
        switch self {
        case .peak: 1.0
        case .perform: 0.85
        case .getBy: 0.70
        }
    }
}

// MARK: - Sleep Need

struct SleepNeed {
    let totalHoursNeeded: Double
    let baselineNeed: Double
    let strainAdjustment: Double
    let debtAdjustment: Double
    let recommendedBedtime: Date?
    let recommendedWakeTime: Date?
    let performanceLevel: PerformanceLevel
}

// MARK: - Sleep Need Calculator

@Observable
final class SleepNeedCalculator {

    // MARK: - Public State

    private(set) var currentNeed: SleepNeed?
    private(set) var isReady: Bool = false
    private(set) var sleepConsistencyScore: Double = 0

    // MARK: - Constants

    private static let minimumDaysRequired = 7
    private static let baselineWindowDays = 30
    private static let wakeTimeWindowDays = 14
    private static let minBaselineHours = 6.0
    private static let maxBaselineHours = 10.0
    private static let strainThreshold = 10.0
    private static let strainIncrementPerPoints = 5.0
    private static let strainSleepBonus = 0.5
    private static let debtPayoffFraction = 0.25

    // MARK: - Compute

    @MainActor
    func compute(
        from store: HealthDataStore,
        currentStrain: Double,
        sleepDebt: Double,
        targetWakeTime: Date?,
        performanceLevel: PerformanceLevel = .peak,
        sleepSeries: MetricTimeSeries? = nil
    ) -> SleepNeed {
        guard let sleepSeries = sleepSeries ?? store.loadTimeSeries(for: .sleepDuration) else {
            return fallbackNeed(performanceLevel: performanceLevel)
        }

        let recentSamples = sleepSeries.samples(lastDays: Self.minimumDaysRequired)
        isReady = recentSamples.count >= Self.minimumDaysRequired

        // Base need: 30-day rolling average, clamped
        let baselineSamples = sleepSeries.samples(lastDays: Self.baselineWindowDays)
        let rawBaseline = baselineSamples.isEmpty ? 8.0 : baselineSamples.mean(of: \.value)
        let baselineNeed = min(max(rawBaseline, Self.minBaselineHours), Self.maxBaselineHours)

        // Strain adjustment: +0.5hr per 5 strain points above 10
        let strainAdjustment: Double
        if currentStrain > Self.strainThreshold {
            let excessStrain = currentStrain - Self.strainThreshold
            strainAdjustment = (excessStrain / Self.strainIncrementPerPoints) * Self.strainSleepBonus
        } else {
            strainAdjustment = 0
        }

        // Debt adjustment: pay off 25% of accumulated debt per night
        let debtAdjustment = max(0, sleepDebt * Self.debtPayoffFraction)

        // Total need scaled by performance level
        let rawTotal = baselineNeed + strainAdjustment + debtAdjustment
        let totalHoursNeeded = rawTotal * performanceLevel.multiplier

        // Wake time: use provided or estimate from 14-day average
        let wakeTime = targetWakeTime ?? estimateWakeTime(from: sleepSeries)

        // Bedtime: wake time minus total need
        let recommendedBedtime: Date?
        if let wake = wakeTime {
            let secondsNeeded = totalHoursNeeded * 3600
            recommendedBedtime = wake.addingTimeInterval(-secondsNeeded)
        } else {
            recommendedBedtime = nil
        }

        // Consistency score
        sleepConsistencyScore = computeConsistencyScore(from: sleepSeries)

        let need = SleepNeed(
            totalHoursNeeded: totalHoursNeeded,
            baselineNeed: baselineNeed,
            strainAdjustment: strainAdjustment,
            debtAdjustment: debtAdjustment,
            recommendedBedtime: recommendedBedtime,
            recommendedWakeTime: wakeTime,
            performanceLevel: performanceLevel
        )

        currentNeed = need
        return need
    }

    // MARK: - Formatted Output

    var formattedBedtime: String? {
        guard let bedtime = currentNeed?.recommendedBedtime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: bedtime)
    }

    var formattedNeed: String {
        let hours = currentNeed?.totalHoursNeeded ?? 8.0
        let (h, m) = hoursToHoursMinutes(hours)
        return "\(h)h \(m)m"
    }

    func hoursToHoursMinutes(_ hours: Double) -> (hours: Int, minutes: Int) {
        let totalMinutes = Int((hours * 60).rounded())
        return (hours: totalMinutes / 60, minutes: totalMinutes % 60)
    }

    // MARK: - Private Helpers

    private func estimateWakeTime(from sleepSeries: MetricTimeSeries) -> Date? {
        let recentSamples = sleepSeries.samples(lastDays: Self.wakeTimeWindowDays)
        guard recentSamples.count >= 3 else { return nil }

        // Estimate wake time from sleep end: sample date represents the sleep period end.
        // Compute average wake hour across recent samples.
        let calendar = Calendar.current
        var totalMinutesFromMidnight = 0.0

        for sample in recentSamples {
            let components = calendar.dateComponents([.hour, .minute], from: sample.date)
            let minutesFromMidnight = Double(components.hour ?? 7) * 60 + Double(components.minute ?? 0)

            // Sleep duration values represent hours of sleep, and the sample date
            // is typically the end of the sleep period. Use the date directly to
            // infer wake time.
            totalMinutesFromMidnight += minutesFromMidnight
        }

        let avgMinutes = totalMinutesFromMidnight / Double(recentSamples.count)
        let avgHour = Int(avgMinutes) / 60
        let avgMinute = Int(avgMinutes) % 60

        // Project to tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: avgHour, minute: avgMinute, second: 0, of: tomorrow)
    }

    private func computeConsistencyScore(from sleepSeries: MetricTimeSeries) -> Double {
        let samples = sleepSeries.samples(lastDays: Self.baselineWindowDays)
        guard samples.count >= Self.minimumDaysRequired else { return 0 }

        // Duration consistency: lower standard deviation = higher score
        let values = samples.map(\.value)
        let mean = values.mean(of: \.self)
        guard mean > 0 else { return 0 }

        let variance = values.reduce(0.0) { sum, val in
            let delta = val - mean
            return sum + delta * delta
        } / Double(values.count)
        let stdDev = variance.squareRoot()

        // Coefficient of variation: stdDev / mean
        // Perfect consistency (CV = 0) → score 100
        // Poor consistency (CV >= 0.3) → score 0
        let cv = stdDev / mean
        let score = max(0, min(100, (1.0 - cv / 0.3) * 100))

        // Timing consistency from sample dates
        let calendar = Calendar.current
        var bedtimeMinutes: [Double] = []

        for sample in samples {
            // Estimate bedtime by subtracting sleep duration from sample date
            let sleepHours = sample.value
            let estimatedBedtime = sample.date.addingTimeInterval(-sleepHours * 3600)
            let components = calendar.dateComponents([.hour, .minute], from: estimatedBedtime)
            var minutesFromMidnight = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
            // Normalize: bedtimes after 6 PM are treated as negative offset from midnight
            if minutesFromMidnight > 360 {
                minutesFromMidnight -= 1440
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

        // Bedtime stdDev of 0 minutes → 100, 90+ minutes → 0
        let timingScore = max(0, min(100, (1.0 - bedtimeStdDev / 90.0) * 100))

        // Blend duration consistency (40%) and timing consistency (60%)
        return score * 0.4 + timingScore * 0.6
    }

    private func fallbackNeed(performanceLevel: PerformanceLevel) -> SleepNeed {
        let baseline = 8.0
        return SleepNeed(
            totalHoursNeeded: baseline * performanceLevel.multiplier,
            baselineNeed: baseline,
            strainAdjustment: 0,
            debtAdjustment: 0,
            recommendedBedtime: nil,
            recommendedWakeTime: nil,
            performanceLevel: performanceLevel
        )
    }
}
