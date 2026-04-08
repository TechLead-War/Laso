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

    // Hard bounds (science-backed: NSF, AASM, Cappuccio 2010)
    private static let floorHours = 6.5
    private static let ceilingHours = 9.0

    // Debt
    private static let maxDebtAdjustment = 0.5

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

        let recentSamples = sleepSeries.samples(lastDays: Self.minimumDaysRequired)
        isReady = recentSamples.count >= Self.minimumDaysRequired

        // --- New formula: base + adjustments, clamped to [6.5, 9.0] ---

        // 1. Base from performance level
        let base = performanceLevel.baseHours

        // 2. Age adjustment
        let ageAdjustment: Double
        if age < 26 {
            ageAdjustment = 0.25       // Young adults need slightly more
        } else if age <= 64 {
            ageAdjustment = 0           // Standard adult range
        } else {
            ageAdjustment = -0.25       // Older adults need slightly less (NSF)
        }

        // 3. Recovery adjustment (how recovered is the body right now)
        let recoveryAdjustment: Double
        if recoveryScore < 40 {
            recoveryAdjustment = 0.5    // Low recovery — body needs more sleep
        } else if recoveryScore < 60 {
            recoveryAdjustment = 0.25   // Moderate recovery
        } else if recoveryScore < 80 {
            recoveryAdjustment = 0      // Good recovery — on track
        } else {
            recoveryAdjustment = -0.25  // Excellent recovery — can get by with less
        }

        // 4. Strain adjustment (how hard was today)
        let strainAdjustment: Double
        if currentStrain > 15 {
            strainAdjustment = 0.5      // Heavy strain day
        } else if currentStrain > 10 {
            strainAdjustment = 0.25     // Moderate strain
        } else {
            strainAdjustment = 0        // Light day
        }

        // 5. Debt adjustment (accumulated sleep deficit, capped)
        let debtAdjustment = sleepDebt > 0 ? Self.maxDebtAdjustment : 0.0

        // 6. Sleep quality trend (declining quality over 7+ days)
        let trendAdjustment = sleepQualityDeclining(sleepSeries) ? 0.25 : 0.0

        // Total, clamped to hard bounds
        let rawTotal = base + ageAdjustment + recoveryAdjustment + strainAdjustment + debtAdjustment + trendAdjustment
        let totalHoursNeeded = min(max(rawTotal, Self.floorHours), Self.ceilingHours)

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
            baselineNeed: base,
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
        let hours = currentNeed?.totalHoursNeeded ?? 7.5
        let (h, m) = hoursToHoursMinutes(hours)
        return "\(h)h \(m)m"
    }

    func hoursToHoursMinutes(_ hours: Double) -> (hours: Int, minutes: Int) {
        let totalMinutes = Int((hours * 60).rounded())
        return (hours: totalMinutes / 60, minutes: totalMinutes % 60)
    }

    // MARK: - Private Helpers

    /// Check if sleep quality has been declining over the last 7 days
    /// compared to the 30-day average.
    private func sleepQualityDeclining(_ sleepSeries: MetricTimeSeries) -> Bool {
        let recent = sleepSeries.samples(lastDays: 7)
        let baseline = sleepSeries.samples(lastDays: 30)
        guard recent.count >= 5, baseline.count >= 14 else { return false }

        let recentAvg = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let baselineAvg = baseline.map(\.value).reduce(0, +) / Double(baseline.count)

        // Declining if recent 7-day average is 30+ minutes below 30-day average
        return baselineAvg - recentAvg > 0.5
    }

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
            if minutesFromMidnight > 1080 {
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
        SleepNeed(
            totalHoursNeeded: performanceLevel.baseHours,
            baselineNeed: performanceLevel.baseHours,
            strainAdjustment: 0,
            debtAdjustment: 0,
            recommendedBedtime: nil,
            recommendedWakeTime: nil,
            performanceLevel: performanceLevel
        )
    }
}
