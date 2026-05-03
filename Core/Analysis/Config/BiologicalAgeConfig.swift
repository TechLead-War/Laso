import Foundation

/// Configuration constants for `BiologicalAgeAnalyzer`.
///
/// HEURISTIC — unvalidated. The bracket cutoffs below are informed by widely
/// cited population averages but are not anchored to a specific source DOI;
/// treat outputs as informational signals only, not clinical measurements.
enum BiologicalAgeConfig {

    // MARK: - Component Weights (sum = 1.0)

    static let cardioFitnessWeight: Double = 0.35
    static let restingHeartRateWeight: Double = 0.20
    static let activityRhythmWeight: Double = 0.20
    static let mobilityWeight: Double = 0.15
    static let hrvWeight: Double = 0.10

    // MARK: - Ceilings & Floors

    static let maxComputedAge: Double = 90
    static let minComputedAge: Double = 18

    // MARK: - RHR → Age Brackets (bpm → years)

    /// Resting HR at or below this is treated as "young fit adult".
    static let rhrYoungFitCeiling: Double = 55
    /// Anchor at the boundary between low-normal and average.
    static let rhrAverageCeiling: Double = 65
    /// Anchor at the boundary between average and elevated.
    static let rhrElevatedCeiling: Double = 75
    /// Mapped age at the young-fit anchor.
    static let rhrYoungFitAge: Double = 20
    /// Slope (years of age per bpm) inside the young-fit → average band.
    static let rhrSlopeYoungToAverage: Double = 2.0
    /// Mapped age at the average anchor.
    static let rhrAverageAge: Double = 40
    /// Slope across the average → elevated band.
    static let rhrSlopeAverageToElevated: Double = 2.0
    /// Mapped age at the elevated anchor.
    static let rhrElevatedAge: Double = 60
    /// Slope above the elevated anchor.
    static let rhrSlopeElevated: Double = 1.5

    // MARK: - HRV → Age Brackets (SDNN ms → years)

    static let hrvYoungAnchor: Double = 70
    static let hrvAdultAnchor: Double = 50
    static let hrvMidlifeAnchor: Double = 35
    static let hrvOlderAnchor: Double = 20
    static let hrvYoungAge: Double = 22
    /// Range over the (young → adult) bracket.
    static let hrvAdultBracketSpan: Double = 20
    static let hrvAdultBracketAgeSpan: Double = 18
    /// Range over the (adult → midlife) bracket.
    static let hrvMidlifeBracketSpan: Double = 15
    static let hrvMidlifeBracketAgeSpan: Double = 15
    /// Range over the (midlife → older) bracket.
    static let hrvOlderBracketSpan: Double = 15
    static let hrvOlderBracketAgeSpan: Double = 20
    /// Range over the (older → very-low) bracket.
    static let hrvVeryLowBracketSpan: Double = 10
    static let hrvVeryLowBracketAgeSpan: Double = 10
    static let hrvAdultAge: Double = 40
    static let hrvMidlifeAge: Double = 55
    static let hrvOlderAge: Double = 75

    // MARK: - Activity Rhythm

    /// Rhythm score at or above this maps to the youngest band.
    static let rhythmYoungThreshold: Double = 0.55
    /// Rhythm score at the boundary between mid and older bands.
    static let rhythmMidThreshold: Double = 0.35
    static let rhythmAmplitudeWeight: Double = 0.5
    static let rhythmRegularityWeight: Double = 0.5
    static let rhythmYoungAge: Double = 25
    static let rhythmMidBracketSpan: Double = 0.20
    static let rhythmMidBracketAgeSpan: Double = 25
    static let rhythmOlderBracketSpan: Double = 0.20
    static let rhythmOlderBracketAgeSpan: Double = 25
    static let rhythmMidAge: Double = 50

    // MARK: - Mobility (walking speed m/s, double support %)

    static let walkingSpeedYoungAnchor: Double = 1.4
    static let walkingSpeedMidAnchor: Double = 1.2
    static let walkingSpeedSlowAnchor: Double = 1.0
    static let walkingSpeedYoungAge: Double = 25
    static let walkingSpeedMidBracketSpan: Double = 0.2
    static let walkingSpeedMidBracketAgeSpan: Double = 15
    static let walkingSpeedSlowBracketSpan: Double = 0.2
    static let walkingSpeedSlowBracketAgeSpan: Double = 15
    static let walkingSpeedVerySlowBracketSpan: Double = 0.2
    static let walkingSpeedVerySlowBracketAgeSpan: Double = 20
    static let walkingSpeedMidAge: Double = 40
    static let walkingSpeedSlowAge: Double = 55
    static let walkingSpeedAgeCap: Double = 85

    /// Double-support % anchor mapped to the young end of the band.
    static let doubleSupportYoungAnchor: Double = 20
    /// Slope (years of age per percentage point above anchor).
    static let doubleSupportSlope: Double = 3
    static let doubleSupportYoungAge: Double = 20
    static let doubleSupportFloorAge: Double = 18
    static let doubleSupportCapAge: Double = 85
}
