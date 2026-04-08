import Foundation
import SwiftUI

// MARK: - Sleep Debt Tracker

/// Computes cumulative sleep debt by comparing actual sleep duration against a personal baseline
/// derived from the user's 30-day average. Tracks deficits over a rolling 14-day window.
@Observable
final class SleepDebtTracker {

    // MARK: - Types

    enum DebtLevel: Int, CaseIterable, Comparable {
        case none
        case mild
        case moderate
        case significant
        case severe

        static func < (lhs: DebtLevel, rhs: DebtLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        init(hours: Double) {
            switch hours {
            case ..<1:    self = .none
            case 1..<3:   self = .mild
            case 3..<6:   self = .moderate
            case 6..<10:  self = .significant
            default:      self = .severe
            }
        }

        var displayName: String {
            switch self {
            case .none:        "No debt"
            case .mild:        "Mild debt"
            case .moderate:    "Moderate debt"
            case .significant: "Significant debt"
            case .severe:      "Severe debt"
            }
        }

        var color: Color {
            switch self {
            case .none:        .green
            case .mild:        .yellow
            case .moderate:    .orange
            case .significant: .red
            case .severe:      .purple
            }
        }

        var icon: String {
            switch self {
            case .none:        "moon.stars.fill"
            case .mild:        "moon.haze.fill"
            case .moderate:    "moon.dust.fill"
            case .significant: "exclamationmark.triangle.fill"
            case .severe:      "bolt.trianglebadge.exclamationmark.fill"
            }
        }

        var description: String {
            switch self {
            case .none:
                "You are well-rested. Your sleep is meeting your personal needs."
            case .mild:
                "A small sleep deficit is building. An extra 30 minutes tonight can help."
            case .moderate:
                "Noticeable sleep debt is accumulating. You may experience reduced focus and slower reaction times."
            case .significant:
                "Substantial sleep debt is affecting your recovery and cognitive performance. Prioritize sleep this week."
            case .severe:
                "Critical sleep debt. Expect impaired judgment, weakened immunity, and poor recovery. Extended catch-up sleep is needed."
            }
        }
    }

    enum DebtTrend: String {
        case increasing
        case stable
        case decreasing
    }

    struct SleepDebtInfo {
        let totalDebtHours: Double
        let debtLevel: DebtLevel
        let dailyDeficits: [(date: Date, deficit: Double)]
        let averageSleepDuration: Double
        let personalBaseline: Double
        let daysToPayOff: Int
    }

    // MARK: - Properties

    private(set) var currentDebt: SleepDebtInfo?
    private(set) var isReady: Bool = false
    private(set) var debtTrend: DebtTrend = .stable

    /// Formatted debt string, e.g. "3h 30m"
    var formattedDebt: String {
        guard let debt = currentDebt else { return "—" }
        let hours = debt.totalDebtHours
        if hours >= 20 { return "20+ hours" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 && m == 0 { return "0h" }
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// Color corresponding to the current debt level
    var debtColor: Color {
        currentDebt?.debtLevel.color ?? .green
    }

    // MARK: - Computation

    /// Recommended minimum sleep for adults (hours). Used as a floor for
    /// the personal baseline so that chronically short sleepers still
    /// accumulate debt against a science-backed target (NSF guidelines: 7-9h).
    private static let recommendedMinimumSleep: Double = 7.5

    /// Compute sleep debt from the data store's sleep duration time series.
    /// Requires at least 7 days of sleep data; uses max(30-day average, 7.5h)
    /// as the personal baseline so chronic short-sleepers accumulate realistic debt.
    @MainActor
    func compute(from store: HealthDataStore, sleepSeries: MetricTimeSeries? = nil) {
        guard let sleepSeries = sleepSeries ?? store.loadTimeSeries(for: .sleepDuration) else {
            isReady = false
            currentDebt = nil
            return
        }

        let last30 = sleepSeries.samples(lastDays: 30)
        let last14 = sleepSeries.samples(lastDays: 14)

        guard last14.count >= 7 else {
            isReady = false
            currentDebt = nil
            return
        }

        isReady = true

        // Personal baseline: 30-day average (fall back to 14-day if less data),
        // but never below the recommended minimum so chronic short sleepers
        // still accumulate meaningful debt.
        let baselineSamples = last30.count >= 21 ? last30 : last14
        let averageSleepBaseline = baselineSamples.map(\.value).reduce(0, +) / Double(baselineSamples.count)
        let personalBaseline = Swift.max(averageSleepBaseline, Self.recommendedMinimumSleep)

        // Build a date-indexed map of the last 14 days of sleep
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyMap: [Date: Double] = [:]
        for sample in last14 {
            let day = calendar.startOfDay(for: sample.date)
            // Keep the latest value per day (in case of duplicates)
            dailyMap[day] = sample.value
        }

        // Walk last 14 days and compute deficits
        var dailyDeficits: [(date: Date, deficit: Double)] = []
        var cumulativeDebt: Double = 0

        for offset in stride(from: -13, through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            if let actual = dailyMap[dayStart] {
                let deficit = personalBaseline - actual
                dailyDeficits.append((date: dayStart, deficit: deficit))

                // Positive deficit adds to debt; surplus reduces debt but never below 0
                cumulativeDebt = Swift.max(0, cumulativeDebt + deficit)
            } else {
                // Missing day: assume baseline met (no deficit)
                dailyDeficits.append((date: dayStart, deficit: 0))
            }
        }

        // Cap tracked debt at 20 hours
        let cappedDebt = Swift.min(cumulativeDebt, 20)

        // Average sleep duration over the 14-day window
        let averageSleep = last14.map(\.value).reduce(0, +) / Double(last14.count)

        // Estimate days to pay off at 25% payoff per night
        // Each night you can recoup ~25% of the deficit (sleeping 25% extra beyond baseline)
        let payoffPerNight = personalBaseline * 0.25
        let daysToPayOff: Int
        if cappedDebt <= 0 || payoffPerNight <= 0 {
            daysToPayOff = 0
        } else {
            daysToPayOff = Int(ceil(cappedDebt / payoffPerNight))
        }

        let debtLevel = DebtLevel(hours: cappedDebt)

        currentDebt = SleepDebtInfo(
            totalDebtHours: cappedDebt,
            debtLevel: debtLevel,
            dailyDeficits: dailyDeficits,
            averageSleepDuration: averageSleep,
            personalBaseline: personalBaseline,
            daysToPayOff: daysToPayOff
        )

        // Determine trend: compare average deficit of last 3 days vs prior 3 days
        computeTrend(from: dailyDeficits)
    }

    // MARK: - Private

    private func computeTrend(from deficits: [(date: Date, deficit: Double)]) {
        guard deficits.count >= 6 else {
            debtTrend = .stable
            return
        }

        let count = deficits.count
        let recent3 = deficits[(count - 3)...].map(\.deficit)
        let prior3 = deficits[(count - 6)..<(count - 3)].map(\.deficit)

        let recentAvg = recent3.reduce(0, +) / Double(recent3.count)
        let priorAvg = prior3.reduce(0, +) / Double(prior3.count)

        let difference = recentAvg - priorAvg

        // Threshold: 0.25 hours (~15 min) change in average deficit to qualify as a trend shift
        if difference > 0.25 {
            debtTrend = .increasing
        } else if difference < -0.25 {
            debtTrend = .decreasing
        } else {
            debtTrend = .stable
        }
    }
}
