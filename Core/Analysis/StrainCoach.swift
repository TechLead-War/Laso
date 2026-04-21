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
            case .restoring: "Recovery Focus"
            case .maintaining: "Maintain Fitness"
            case .building: "Progressive Overload"
            case .overreaching: "Functional Overreach"
            }
        }

        var icon: String {
            switch self {
            case .restoring: "bed.double.fill"
            case .maintaining: "figure.walk"
            case .building: "figure.run"
            case .overreaching: "flame.fill"
            }
        }

        var color: Color {
            switch self {
            case .restoring: .blue
            case .maintaining: .yellow
            case .building: .green
            case .overreaching: .orange
            }
        }

        /// Strain ranges per recovery state
        func strainRange(for recovery: DashboardViewModel.RecoveryState) -> ClosedRange<Double> {
            switch (self, recovery) {
            // Green recovery
            case (.restoring, .green):     return 0...9
            case (.maintaining, .green):   return 10...14
            case (.building, .green):      return 14...18
            case (.overreaching, .green):  return 18...21

            // Yellow recovery
            case (.restoring, .yellow):    return 0...7
            case (.maintaining, .yellow):  return 8...12
            case (.building, .yellow),
                 (.overreaching, .yellow): return 0...0 // not available

            // Red recovery
            case (.restoring, .red):       return 0...5
            case (.maintaining, .red),
                 (.building, .red),
                 (.overreaching, .red):    return 0...0 // not available
            }
        }
    }

    struct StrainTarget: Sendable {
        let targetStrain: Double
        let minStrain: Double
        let maxStrain: Double
        let zone: TrainingZone
        let guidance: String
        let icon: String

        /// Fraction of the 0-21 scale that the target represents
        var targetFraction: Double {
            targetStrain / 21.0
        }
    }

    enum StrainBalance: String, CaseIterable, Sendable {
        case undertraining
        case optimal
        case overreaching

        var displayName: String {
            switch self {
            case .undertraining: "Under-Training"
            case .optimal: "Optimal Load"
            case .overreaching: "Over-Reaching"
            }
        }

        var color: Color {
            switch self {
            case .undertraining: .blue
            case .optimal: .green
            case .overreaching: .red
            }
        }

        var icon: String {
            switch self {
            case .undertraining: "arrow.down.circle"
            case .optimal: "checkmark.circle.fill"
            case .overreaching: "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - State

    /// The current recommended strain target, nil until computed
    private(set) var currentTarget: StrainTarget?

    /// Whether the coach has enough data to produce a recommendation
    var isReady: Bool { currentTarget != nil }

    /// 7-day strain balance relative to the recommended target zone
    private(set) var strainBalance: StrainBalance = .optimal

    // MARK: - Constants

    /// Minimum days of strain history required for pattern-aware adjustments
    private static let minHistoryDays = 3

    /// Number of consecutive high-strain days that triggers a dial-back
    private static let consecutiveHighThreshold = 3

    /// High strain threshold on the 0-21 scale
    private static let highStrainValue: Double = 14.0

    /// Rest day threshold. strain below this counts as a rest day
    private static let restDayThreshold: Double = 5.0

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
        let hasEnoughHistory = recentStrainHistory.count >= Self.minHistoryDays
        let consecutiveHighDays = countConsecutiveHighDays(recentStrainHistory)
        let hadRecentRest = hasRecentRestDay(recentStrainHistory, withinDays: 3)

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
            targetStrain: target,
            minStrain: min,
            maxStrain: max,
            zone: zone,
            guidance: guidance,
            icon: zone.icon
        )

        currentTarget = result
        updateStrainBalance(recentHistory: recentStrainHistory, target: target)

        return result
    }

    /// Progress toward today's strain target as a fraction (0.0 to 1.0+).
    /// Values above 1.0 indicate the target has been exceeded.
    func progressTowardTarget(currentStrain: Double) -> Double {
        guard let target = currentTarget, target.targetStrain > 0 else { return 0 }
        return currentStrain / target.targetStrain
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
            // Dial back if 3+ consecutive high-strain days even on green
            if hasHistory && consecutiveHighDays >= Self.consecutiveHighThreshold {
                return (.maintaining, 12.0, 10.0, 14.0)
            }
            // Allow overreaching only if had recent rest
            if hadRecentRest && hasHistory {
                return (.building, 16.0, 14.0, 18.0)
            }
            // Default green day
            return (.building, 15.5, 14.0, 17.0)

        case .yellow:
            // If already stacking moderate days, pull back slightly
            if hasHistory && consecutiveHighDays >= 2 {
                return (.restoring, 7.0, 5.0, 9.0)
            }
            return (.maintaining, 11.5, 10.0, 13.0)

        case .red:
            return (.restoring, 5.0, 0.0, 5.0)
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
        // Cold-start caveat
        if daysOfData < 7 {
            return "Limited data \u{2014} this target is estimated. Keep logging for more accurate recommendations."
        }

        let remaining = max(0, target - currentStrain)

        switch zone {
        case .restoring:
            if recovery == .red {
                return "Your body needs recovery. Focus on gentle movement like walking or stretching. Aim to keep strain under \(formatted(target))."
            }
            if consecutiveHighDays >= Self.consecutiveHighThreshold {
                return "You've pushed hard \(consecutiveHighDays) days in a row. Take it easy today to avoid overtraining."
            }
            return "Active recovery day. Light activity to promote blood flow without adding fatigue."

        case .maintaining:
            if remaining > 0 {
                return "Moderate training day. You have \(formatted(remaining)) strain remaining to hit your target of \(formatted(target))."
            }
            return "You've reached your maintenance target. Additional strain is fine but keep intensity controlled."

        case .building:
            if remaining > 0 {
                return "Your body is ready for a challenge. Push toward a strain of \(formatted(target)) with a hard workout."
            }
            return "Great work \u{2014} you've hit your building target. You can keep going up to \(formatted(zone.strainRange(for: recovery).upperBound))."

        case .overreaching:
            return "Functional overreach zone. Push to your limit today, then plan recovery tomorrow."
        }
    }

    private func countConsecutiveHighDays(_ history: [(date: Date, strain: Double)]) -> Int {
        // Walk backward through sorted history counting consecutive high-strain days
        var count = 0
        for entry in history.reversed() {
            if entry.strain >= Self.highStrainValue {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func hasRecentRestDay(_ history: [(date: Date, strain: Double)], withinDays: Int) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
        return history.contains { entry in
            entry.date >= cutoff && entry.strain <= Self.restDayThreshold
        }
    }

    private func updateStrainBalance(
        recentHistory: [(date: Date, strain: Double)],
        target: Double
    ) {
        let last7 = recentHistory.suffix(7)
        guard last7.count >= 3 else {
            strainBalance = .optimal
            return
        }

        let averageStrain = last7.map(\.strain).reduce(0, +) / Double(last7.count)
        let ratio = target > 0 ? averageStrain / target : 1.0

        if ratio < 0.7 {
            strainBalance = .undertraining
        } else if ratio > 1.3 {
            strainBalance = .overreaching
        } else {
            strainBalance = .optimal
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
