import Foundation

/// Where a reading sits against the person's own recent history.
enum TrendBandStatus {
    case belowUsual
    case usual
    case aboveUsual
}

/// The person's own usual range for a daily score.
///
/// Mean ± 1 SD, so roughly two thirds of their own days fall inside it. This
/// describes their history and nothing else: it is not a clinical reference
/// range, and it says nothing about what is healthy for anyone else.
struct PersonalBand {
    let low: Double
    let high: Double

    /// Fewest recorded days before a usual range is claimed at all.
    static let minimumDays = 14

    /// Half-width of the band, in standard deviations.
    static let deviations: Double = 1.0

    /// Returns nil when there is too little history, or when every day is
    /// identical and a band would be a line with no width.
    static func make(from values: [Double]) -> PersonalBand? {
        guard values.count >= minimumDays else { return nil }
        let sd = values.standardDeviation
        guard sd > 0 else { return nil }
        let mean = values.mean
        return PersonalBand(low: mean - deviations * sd, high: mean + deviations * sd)
    }

    func status(for value: Double) -> TrendBandStatus {
        if value < low { return .belowUsual }
        if value > high { return .aboveUsual }
        return .usual
    }
}
