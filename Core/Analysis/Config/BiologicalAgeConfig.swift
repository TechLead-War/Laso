import Foundation

/// Shared physiological anchors that outlived the composite biological-age
/// analyzer. Vitality Age is now the only age model in the app, so the
/// component brackets that fed that analyzer are gone; what remains here is
/// the two anchor sets other code still reads.
///
/// HEURISTIC — unvalidated. Informed by widely cited population averages but
/// not anchored to a specific source DOI; treat outputs as informational
/// signals only, not clinical measurements.
enum BiologicalAgeConfig {

    // MARK: - Resting HR Bands (bpm)

    /// Resting HR at or below this is treated as "young fit adult".
    static let rhrYoungFitCeiling: Double = 55
    /// Anchor at the boundary between average and elevated.
    static let rhrElevatedCeiling: Double = 75

    // MARK: - Walking Speed Anchors (km/h)

    // Walking speed is stored in km/h (`HealthKitMetricRegistry`). These anchors
    // were once written in m/s, which every real reading cleared, so the reader
    // always landed in the youngest bracket. 1.4 / 1.2 / 1.0 m/s below.
    static let walkingSpeedYoungAnchor: Double = 5.04
    static let walkingSpeedMidAnchor: Double = 4.32
    static let walkingSpeedSlowAnchor: Double = 3.6
}
