import Foundation

/// Configuration constants for `StrainCoach`.
///
/// HEURISTIC — unvalidated. The strain-range cutoffs and balance ratios are
/// inspired by WHOOP-style periodisation guidance but are not anchored to
/// a specific peer-reviewed dataset. Treat outputs as coaching suggestions.
enum StrainCoachConfig {

    // MARK: - History Gates

    /// Minimum history days required before pattern-aware adjustments kick in.
    static let minHistoryDays: Int = 3

    /// Days back the analyzer scans for a recent rest day.
    static let recentRestWindowDays: Int = 3

    /// Cold-start day count at which the coach drops the "limited data" caveat.
    static let coldStartDays: Int = 7

    // MARK: - Balance Window

    static let balanceWindowDays: Int = 7
    static let balanceMinSamples: Int = 3
    static let undertrainingRatioCeiling: Double = 0.7
    static let overreachingRatioFloor: Double = 1.3

    // MARK: - High-Strain Pattern

    /// Consecutive high-strain days that triggers a dial-back on green days.
    static let consecutiveHighThreshold: Int = 3

    /// Strain at or above this counts as a "high" day.
    static let highStrainValue: Double = 14.0

    /// Strain at or below this counts as a rest day.
    static let restDayThreshold: Double = 5.0

    /// Yellow-day consecutive-high count that pulls back into restoring zone.
    static let yellowConsecutiveHighThreshold: Int = 2

    // MARK: - Per-Zone Targets (target, min, max)

    struct StrainBand: Sendable {
        let target: Double
        let min: Double
        let max: Double
    }

    /// Green day with 3+ consecutive high-strain days → dial back to maintaining.
    static let greenDialBackBand = StrainBand(target: 12.0, min: 10.0, max: 14.0)

    /// Green day after recent rest → allow building.
    static let greenAfterRestBand = StrainBand(target: 16.0, min: 14.0, max: 18.0)

    /// Default green day building band.
    static let greenDefaultBand = StrainBand(target: 15.5, min: 14.0, max: 17.0)

    /// Yellow day after stacking → restoring band.
    static let yellowDialBackBand = StrainBand(target: 7.0, min: 5.0, max: 9.0)

    /// Default yellow day maintaining band.
    static let yellowDefaultBand = StrainBand(target: 11.5, min: 10.0, max: 13.0)

    /// Red day → strict restoring band.
    static let redBand = StrainBand(target: 5.0, min: 0.0, max: 5.0)

    // MARK: - Per-Zone Strain Ranges (for `TrainingZone.strainRange(for:)`)

    static let greenRestoringRange: ClosedRange<Double> = 0...9
    static let greenMaintainingRange: ClosedRange<Double> = 10...14
    static let greenBuildingRange: ClosedRange<Double> = 14...18
    static let greenOverreachingRange: ClosedRange<Double> = 18...21

    static let yellowRestoringRange: ClosedRange<Double> = 0...7
    static let yellowMaintainingRange: ClosedRange<Double> = 8...12

    static let redRestoringRange: ClosedRange<Double> = 0...5

    /// Sentinel range used for combinations that are not allowed (e.g. building on red).
    static let unavailableRange: ClosedRange<Double> = 0...0
}
