import Foundation
import SwiftUI
import Observation

/// Recommends daily strain targets based on recovery state, recent training load, and strain history.
/// Uses a periodization-aware model: green days allow building/overreaching, yellow days maintain,
/// red days enforce active recovery only.
@Observable
final class StrainCoach {

    // MARK: - Types

    enum TrainingZone: String, CaseIterable, Sendable {
        case restoring
        case maintaining
        case building
        case overreaching

        var displayName: String {
            switch self {
            case .restoring: Copy.Strain.zoneRestoring
            case .maintaining: Copy.Strain.zoneMaintaining
            case .building: Copy.Strain.zoneBuilding
            case .overreaching: Copy.Strain.zoneOverreaching
            }
        }

        /// Strain ranges per recovery state.
        func strainRange(for recovery: DashboardViewModel.RecoveryState) -> ClosedRange<Double> {
            switch (self, recovery) {
            case (.restoring, .green):     return StrainCoachConfig.greenRestoringRange
            case (.maintaining, .green):   return StrainCoachConfig.greenMaintainingRange
            case (.building, .green):      return StrainCoachConfig.greenBuildingRange
            case (.overreaching, .green):  return StrainCoachConfig.greenOverreachingRange

            case (.restoring, .yellow):    return StrainCoachConfig.yellowRestoringRange
            case (.maintaining, .yellow):  return StrainCoachConfig.yellowMaintainingRange
            case (.building, .yellow),
                 (.overreaching, .yellow): return StrainCoachConfig.unavailableRange

            case (.restoring, .red):       return StrainCoachConfig.redRestoringRange
            case (.maintaining, .red),
                 (.building, .red),
                 (.overreaching, .red):    return StrainCoachConfig.unavailableRange
            }
        }
    }

    struct StrainTarget: Sendable {
        let minStrain: Double
        let maxStrain: Double
        let zone: TrainingZone
        let guidance: String
    }

    enum StrainBalance: String, CaseIterable, Sendable {
        case undertraining
        case optimal
        case overreaching
    }

    // MARK: - State

    /// The current recommended strain target, nil until computed
    private(set) var currentTarget: StrainTarget?

    /// 7-day strain balance relative to the recommended target zone
    private(set) var strainBalance: StrainBalance = .optimal

    // MARK: - Constants

    private typealias Cfg = StrainCoachConfig

    // MARK: - Public API

    /// Compute a strain target based on current recovery, today's strain so far, and recent history.
    ///
    /// - Parameters:
    ///   - recoveryState: Current day classification (green/yellow/red)
    ///   - currentStrain: Accumulated strain for today so far (0-21)
    ///   - recentStrainHistory: Dated strain values for recent days, sorted ascending by date
    ///   - daysOfData: Total number of days the user has data for (used for cold-start gating)
    /// - Returns: A `StrainTarget` with zone, range, and human-readable guidance
    func computeTarget(
        recoveryState: DashboardViewModel.RecoveryState,
        currentStrain: Double,
        recentStrainHistory: [(date: Date, strain: Double)],
        daysOfData: Int
    ) -> StrainTarget {
        let hasEnoughHistory = recentStrainHistory.count >= Cfg.minHistoryDays
        let consecutiveHighDays = countConsecutiveHighDays(recentStrainHistory)
        let hadRecentRest = hasRecentRestDay(recentStrainHistory, withinDays: Cfg.recentRestWindowDays)

        let (zone, target, min, max) = computeZoneAndRange(
            recovery: recoveryState,
            consecutiveHighDays: consecutiveHighDays,
            hadRecentRest: hadRecentRest,
            hasHistory: hasEnoughHistory
        )

        let guidance = buildGuidance(
            zone: zone,
            recovery: recoveryState,
            currentStrain: currentStrain,
            target: target,
            consecutiveHighDays: consecutiveHighDays,
            daysOfData: daysOfData
        )

        let result = StrainTarget(
            minStrain: min,
            maxStrain: max,
            zone: zone,
            guidance: guidance
        )

        currentTarget = result
        updateStrainBalance(recentHistory: recentStrainHistory, target: target)

        return result
    }

    // MARK: - Private Helpers

    private func computeZoneAndRange(
        recovery: DashboardViewModel.RecoveryState,
        consecutiveHighDays: Int,
        hadRecentRest: Bool,
        hasHistory: Bool
    ) -> (zone: TrainingZone, target: Double, min: Double, max: Double) {
        switch recovery {
        case .green:
            if hasHistory && consecutiveHighDays >= Cfg.consecutiveHighThreshold {
                let band = Cfg.greenDialBackBand
                return (.maintaining, band.target, band.min, band.max)
            }
            if hadRecentRest && hasHistory {
                let band = Cfg.greenAfterRestBand
                return (.building, band.target, band.min, band.max)
            }
            let band = Cfg.greenDefaultBand
            return (.building, band.target, band.min, band.max)

        case .yellow:
            if hasHistory && consecutiveHighDays >= Cfg.yellowConsecutiveHighThreshold {
                let band = Cfg.yellowDialBackBand
                return (.restoring, band.target, band.min, band.max)
            }
            let band = Cfg.yellowDefaultBand
            return (.maintaining, band.target, band.min, band.max)

        case .red:
            let band = Cfg.redBand
            return (.restoring, band.target, band.min, band.max)
        }
    }

    private func buildGuidance(
        zone: TrainingZone,
        recovery: DashboardViewModel.RecoveryState,
        currentStrain: Double,
        target: Double,
        consecutiveHighDays: Int,
        daysOfData: Int
    ) -> String {
        if daysOfData < Cfg.coldStartDays {
            return Copy.Strain.coachLimitedData
        }

        let remaining = max(0, target - currentStrain)

        switch zone {
        case .restoring:
            if recovery == .red {
                return Copy.Strain.coachRedRecovery(target: formatted(target))
            }
            if consecutiveHighDays >= Cfg.consecutiveHighThreshold {
                return Copy.Strain.coachConsecutiveHigh(days: consecutiveHighDays)
            }
            return Copy.Strain.coachActiveRecovery

        case .maintaining:
            if remaining > 0 {
                return Copy.Strain.coachMaintaining(remaining: formatted(remaining), target: formatted(target))
            }
            return Copy.Strain.coachMaintainHit

        case .building:
            if remaining > 0 {
                return Copy.Strain.coachBuilding(target: formatted(target))
            }
            return Copy.Strain.coachBuildingHit(upper: formatted(zone.strainRange(for: recovery).upperBound))

        case .overreaching:
            return Copy.Strain.coachOverreaching
        }
    }

    private func countConsecutiveHighDays(_ history: [(date: Date, strain: Double)]) -> Int {
        var count = 0
        for entry in history.reversed() {
            if entry.strain >= Cfg.highStrainValue {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func hasRecentRestDay(_ history: [(date: Date, strain: Double)], withinDays: Int) -> Bool {
        let cutoff = Date.cal.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
        return history.contains { entry in
            entry.date >= cutoff && entry.strain <= Cfg.restDayThreshold
        }
    }

    private func updateStrainBalance(
        recentHistory: [(date: Date, strain: Double)],
        target: Double
    ) {
        let recentWindow = recentHistory.suffix(Cfg.balanceWindowDays)
        guard recentWindow.count >= Cfg.balanceMinSamples else {
            strainBalance = .optimal
            return
        }

        let averageStrain = recentWindow.map(\.strain).reduce(0, +) / Double(recentWindow.count)
        let ratio = target > 0 ? averageStrain / target : 1.0

        if ratio < Cfg.undertrainingRatioCeiling {
            strainBalance = .undertraining
        } else if ratio > Cfg.overreachingRatioFloor {
            strainBalance = .overreaching
        } else {
            strainBalance = .optimal
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
