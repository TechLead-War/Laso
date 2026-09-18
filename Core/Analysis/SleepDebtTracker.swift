import Foundation
import SwiftUI

// MARK: - Sleep Debt Tracker

/// Computes cumulative sleep debt by comparing actual sleep duration against a personal baseline
/// derived from the user's 30-day average. Tracks deficits over a rolling 14-day window.
@Observable
final class SleepDebtTracker {

    // MARK: - Types

    enum DebtTrend: String {
        case increasing
        case stable
        case decreasing
    }

    struct DailyDeficit {
        let date: Date
        /// Hours short of the personal baseline. Negative means a surplus.
        let deficit: Double
        /// False when that night recorded nothing. The running total treats a
        /// missing night as met so it cannot invent debt, but a chart must not
        /// draw it as a night slept exactly to target.
        let hasData: Bool
    }

    struct SleepDebtInfo {
        let totalDebtHours: Double
        let dailyDeficits: [DailyDeficit]
        let personalBaseline: Double

        var nightsRecorded: Int { dailyDeficits.filter(\.hasData).count }
    }

    /// Below this the balance is small enough that naming it would be noise
    /// rather than a finding, so the Home card stays quiet and the daily action
    /// is left to the usual ranking. 2.0h over the 14-night window was 8.5
    /// min/night — near-daily furniture, not a finding. Cumulative-restriction
    /// studies show effects from roughly 20-30 min/night sustained (Van Dongen
    /// 2003; Rupp 2009); 5h over 14 nights is about 21 min/night. This is a
    /// product dial pending the real debtHours distribution pull
    /// (KEEP-KILL dataNeeded #7: target roughly the worst ~20% of weeks).
    static let actionableDebtHours: Double = 5.0

    /// The extra sleep the payback line is quoted against. A fixed, stated
    /// amount keeps the line plain arithmetic on the balance instead of a claim
    /// about how fast a body clears a deficit.
    static let paybackExtraMinutes: Double = 45

    /// Past this many nights, "N nights clears it" stops being a plan and starts
    /// being a sentence. Beyond it the card says what one early night is worth
    /// instead, which is true at any size of balance.
    static let paybackNightsWorthQuoting = 7

    /// How many nights of `paybackExtraMinutes` extra sleep clear the balance.
    static func nightsToClear(debtHours: Double) -> Int {
        guard debtHours > 0 else { return 0 }
        return Int((debtHours / (paybackExtraMinutes / 60)).rounded(.up))
    }

    // MARK: - Properties

    private(set) var currentDebt: SleepDebtInfo?
    private(set) var isReady: Bool = false
    private(set) var debtTrend: DebtTrend = .stable

    // MARK: - Computation

    /// Recommended minimum sleep for adults (hours). Used as a floor for
    /// the personal baseline so that chronically short sleepers still
    /// accumulate debt against a 7-9h target rather than against their
    /// already-too-low personal average.
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
        let averageSleepBaseline = baselineSamples.valueMean
        let personalBaseline = Swift.max(averageSleepBaseline, Self.recommendedMinimumSleep)

        // Build a date-indexed map of the last 14 days of sleep
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())

        var dailyMap: [Date: Double] = [:]
        for sample in last14 {
            let day = calendar.startOfDay(for: sample.date)
            // Keep the latest value per day (in case of duplicates)
            dailyMap[day] = sample.value
        }

        // Walk last 14 days and compute deficits
        var dailyDeficits: [DailyDeficit] = []
        var cumulativeDebt: Double = 0

        for offset in stride(from: -13, through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            if let actual = dailyMap[dayStart] {
                let deficit = personalBaseline - actual
                dailyDeficits.append(DailyDeficit(date: dayStart, deficit: deficit, hasData: true))

                // Positive deficit adds to debt; surplus reduces debt but never below 0
                cumulativeDebt = Swift.max(0, cumulativeDebt + deficit)
            } else {
                // Missing day: assume baseline met (no deficit)
                dailyDeficits.append(DailyDeficit(date: dayStart, deficit: 0, hasData: false))
            }
        }

        currentDebt = SleepDebtInfo(
            totalDebtHours: cumulativeDebt,
            dailyDeficits: dailyDeficits,
            personalBaseline: personalBaseline
        )

        // Determine trend: compare average deficit of last 3 days vs prior 3 days
        computeTrend(from: dailyDeficits)
    }

    // MARK: - Private

    private func computeTrend(from deficits: [DailyDeficit]) {
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
