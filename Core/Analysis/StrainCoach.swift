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
    }

    struct StrainTarget: Sendable {
        let minStrain: Double
        let maxStrain: Double
        let zone: TrainingZone
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

    /// Compute a strain target based on current recovery and recent history.
    ///
    /// - Parameters:
    ///   - recoveryState: Current day classification (green/yellow/red), or nil
    ///     when nothing has been scored yet
    ///   - recentStrainHistory: Dated strain values for recent days, sorted ascending by date
    /// - Returns: A `StrainTarget` with zone and range, or nil when there is no
    ///   recovery band to build one from
    @discardableResult
    func computeTarget(
        recoveryState: DashboardViewModel.RecoveryState?,
        recentStrainHistory: [(date: Date, strain: Double)]
    ) -> StrainTarget? {
        // Every zone and range below is selected by the recovery band. Without
        // one there is no target, and clearing rather than keeping the last one
        // is what makes a data wipe reach the widget's day-type line.
        guard let recoveryState else {
            currentTarget = nil
            strainBalance = .optimal
            return nil
        }

        let hasEnoughHistory = recentStrainHistory.count >= Cfg.minHistoryDays
        let consecutiveHighDays = countConsecutiveHighDays(recentStrainHistory)
        let hadRecentRest = hasRecentRestDay(recentStrainHistory, withinDays: Cfg.recentRestWindowDays)

        let (zone, target, min, max) = computeZoneAndRange(
            recovery: recoveryState,
            consecutiveHighDays: consecutiveHighDays,
            hadRecentRest: hadRecentRest,
            hasHistory: hasEnoughHistory
        )

        let result = StrainTarget(
            minStrain: min,
            maxStrain: max,
            zone: zone
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
}
