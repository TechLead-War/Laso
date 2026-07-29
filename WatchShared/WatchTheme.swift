import SwiftUI

/// The only colours the wrist uses.
///
/// Values are the dark-appearance literals from `Common/Theme/AppColour.swift`. They are
/// duplicated rather than imported because no watch target links `Common/`, and
/// `WatchVerdictTests.bandColoursMatchTheApp` fails the build if the two drift.
///
/// Colour is never the only carrier of meaning here. Apple warns that on watchOS "the
/// system may invert colors depending on the watch face a person chooses", so every
/// surface pairs the colour with the word itself or with a filled proportion.
/// https://developer.apple.com/design/human-interface-guidelines/widgets
enum WatchTheme {

    static let optimal = Color(red: 0.200, green: 0.769, blue: 0.553)
    static let fair = Color(red: 0.890, green: 0.706, blue: 0.353)
    static let poor = Color(red: 0.878, green: 0.361, blue: 0.392)

    /// Upkeep words that carry no recovery judgement. Using a band colour for these
    /// would imply a verdict the word is not making.
    static let neutral = Color(red: 0.302, green: 0.639, blue: 1.000)

    static let secondary = Color(red: 0.788, green: 0.788, blue: 0.824)
    static let tertiary = Color(red: 0.678, green: 0.678, blue: 0.722)
    static let track = Color(red: 0.090, green: 0.090, blue: 0.110)

    static func color(for band: WatchBand?) -> Color {
        switch band {
        case .optimal: return optimal
        case .fair: return fair
        case .poor: return poor
        case nil: return neutral
        }
    }

    /// A word's colour. States take the recovery band because they describe recovery.
    /// `breathe` and `sleep` are upkeep and stay neutral: neither is a statement about
    /// how recovered the wearer is.
    static func color(for verdict: WatchVerdict) -> Color {
        switch verdict.word {
        case .breathe, .sleep: return neutral
        default: return color(for: verdict.band)
        }
    }
}
