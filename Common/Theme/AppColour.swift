import SwiftUI

/// App-wide colour palette.
///
/// Layers (top → bottom):
///   1. Brand              primary hero colour, pulled from the app icon
///   2. Accent             call-to-action pop
///   3. Semantic state     success / warning / danger / info
///   4. Score tiers        optimal / good / fair / poor
///   5. Health categories  heart / sleep / activity / stress / vitality / brain
///   6. Feature-specific   achievement, vitality pace, health state, premium,
///                         shareable card gradients, live activity, launch
///
/// Swatch-pickable: every entry uses `#colorLiteral(...)` so Xcode shows an
/// inline colour well you can edit visually.
///
/// Dark-mode: brand tokens adapt via `dynamic(light:dark:)`. Semantic/score/
/// category tokens stay static because they're state indicators (same hue in
/// both modes per Apple HIG). Surface/text tokens are NOT defined here —
/// always use `Color.primary`, `.secondary`, `.systemGroupedBackground`, etc.
///
/// Not yet wired to most call-sites. Reference `AppColour.primary` etc. when
/// migrating.
enum AppColour {

    // MARK: - Dynamic Colour Helper
    // Wraps two `UIColor`s (light + dark variants) into a SwiftUI `Color`
    // that adapts automatically to the current interface style.
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // MARK: - 1. Brand
    // Coral pulled from the app icon (heart glyph). #EB5361 → warmer #F87081 in dark.
    static let primary = dynamic(
        light: #colorLiteral(red: 0.92, green: 0.33, blue: 0.38, alpha: 1.00), // #EB5361
        dark:  #colorLiteral(red: 0.97, green: 0.44, blue: 0.50, alpha: 1.00)  // #F87081
    )
    static let primarySoft = dynamic(
        light: #colorLiteral(red: 0.99, green: 0.89, blue: 0.91, alpha: 1.00), // #FCE4E7 pale rose card bg
        dark:  #colorLiteral(red: 0.30, green: 0.11, blue: 0.14, alpha: 1.00)  // #4C1D24 dark rose wash
    )

    // MARK: - 2. Accent (CTAs, pop)
    static let accent = Color(uiColor: #colorLiteral(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.00)) // #F59E0B warm amber

    // MARK: - 3. Semantic State
    static let success = Color(uiColor: #colorLiteral(red: 0.09, green: 0.64, blue: 0.29, alpha: 1.00)) // #16A34A
    static let warning = Color(uiColor: #colorLiteral(red: 0.92, green: 0.70, blue: 0.03, alpha: 1.00)) // #EAB308
    static let danger  = Color(uiColor: #colorLiteral(red: 0.86, green: 0.15, blue: 0.15, alpha: 1.00)) // #DC2626
    static let info    = Color(uiColor: #colorLiteral(red: 0.15, green: 0.39, blue: 0.92, alpha: 1.00)) // #2563EB

    // MARK: - 4. Score Tiers (alias semantic + one distinct "good")
    static let scoreOptimal = success
    static let scoreGood    = Color(uiColor: #colorLiteral(red: 0.64, green: 0.72, blue: 0.28, alpha: 1.00)) // #A3B847 olive
    static let scoreFair    = warning
    static let scorePoor    = danger

    // MARK: - 5. Health Categories
    static let categoryHeart    = Color(uiColor: #colorLiteral(red: 0.88, green: 0.11, blue: 0.28, alpha: 1.00)) // #E11D48 crimson
    static let categorySleep    = Color(uiColor: #colorLiteral(red: 0.26, green: 0.22, blue: 0.79, alpha: 1.00)) // #4338CA indigo
    static let categoryActivity = Color(uiColor: #colorLiteral(red: 0.98, green: 0.45, blue: 0.09, alpha: 1.00)) // #F97316 orange
    static let categoryStress   = Color(uiColor: #colorLiteral(red: 0.58, green: 0.20, blue: 0.92, alpha: 1.00)) // #9333EA purple
    static let categoryVitality = Color(uiColor: #colorLiteral(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.00)) // #10B981 green
    static let categoryBrain    = Color(uiColor: #colorLiteral(red: 0.86, green: 0.16, blue: 0.47, alpha: 1.00)) // #DB2777 magenta

    // MARK: - 6a. Achievement / Gamification Tiers
    // Source: Modules/Profile/Views/Profile/AchievementsView.swift:29-33
    //         Core/Analysis/GamificationEngine.swift:32-37 (same RGB + legend)
    static let achievementBronze   = Color(uiColor: #colorLiteral(red: 0.80, green: 0.50, blue: 0.20, alpha: 1.00))
    static let achievementSilver   = Color(uiColor: #colorLiteral(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.00))
    static let achievementGold     = Color(uiColor: #colorLiteral(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.00))
    static let achievementPlatinum = Color(uiColor: #colorLiteral(red: 0.90, green: 0.91, blue: 0.98, alpha: 1.00))
    static let achievementDiamond  = Color(uiColor: #colorLiteral(red: 0.72, green: 0.95, blue: 1.00, alpha: 1.00))
    static let achievementLegend   = Color(uiColor: #colorLiteral(red: 0.85, green: 0.65, blue: 1.00, alpha: 1.00))

    // MARK: - 6b. Vitality Pace Palette
    // Source: Modules/Vitality/Views/Vitality/VitalityDetailHelpers.swift:3-5, 41
    static let vitalityWhoopGreen    = Color(uiColor: #colorLiteral(red: 0.00, green: 0.85, blue: 0.69, alpha: 1.00)) // #00D9B0 (approx, from 217/255, 176/255)
    static let vitalityPaceYellow    = Color(uiColor: #colorLiteral(red: 0.96, green: 0.77, blue: 0.26, alpha: 1.00)) // #F5C542
    static let vitalityPaceRed       = Color(uiColor: #colorLiteral(red: 1.00, green: 0.30, blue: 0.31, alpha: 1.00)) // #FF4D4F
    static let vitalityDeltaNegative = Color(uiColor: #colorLiteral(red: 0.18, green: 0.87, blue: 0.78, alpha: 1.00))

    // MARK: - 6c. Health State Timeline
    // Source: Modules/HealthState/ViewModels/HealthStateTimelineViewModel.swift:42-52
    static let stateRecovery        = Color(uiColor: #colorLiteral(red: 0.20, green: 0.80, blue: 0.40, alpha: 1.00))
    static let statePeakPerformance = Color(uiColor: #colorLiteral(red: 0.20, green: 0.50, blue: 1.00, alpha: 1.00))
    static let stateStressed        = Color(uiColor: #colorLiteral(red: 1.00, green: 0.30, blue: 0.30, alpha: 1.00))
    static let stateUnderSlept      = Color(uiColor: #colorLiteral(red: 0.60, green: 0.30, blue: 0.80, alpha: 1.00))
    static let stateActive          = Color(uiColor: #colorLiteral(red: 0.30, green: 0.90, blue: 0.60, alpha: 1.00))
    static let stateFatigued        = Color(uiColor: #colorLiteral(red: 0.80, green: 0.60, blue: 0.20, alpha: 1.00))
    static let stateResting         = Color(uiColor: #colorLiteral(red: 0.50, green: 0.70, blue: 0.90, alpha: 1.00))
    static let stateDefault         = Color(uiColor: #colorLiteral(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.00))

    // MARK: - 6d. Premium / Subscription Badge
    // Source: Modules/Settings/Views/SettingsView.swift:178, 185-186
    static let premiumBadgeText      = Color(uiColor: #colorLiteral(red: 0.35, green: 0.22, blue: 0.02, alpha: 1.00))
    static let premiumGradientTop    = Color(uiColor: #colorLiteral(red: 1.00, green: 0.85, blue: 0.45, alpha: 1.00))
    static let premiumGradientBottom = Color(uiColor: #colorLiteral(red: 0.96, green: 0.64, blue: 0.18, alpha: 1.00))

    // MARK: - 6e. Shareable Score Card (dark-themed tier backgrounds)
    // Source: Common/Components/ShareableCard.swift:28-31, 186
    static let shareScoreHighStart      = Color(uiColor: #colorLiteral(red: 0.10, green: 0.20, blue: 0.15, alpha: 1.00))
    static let shareScoreHighEnd        = Color(uiColor: #colorLiteral(red: 0.05, green: 0.12, blue: 0.08, alpha: 1.00))
    static let shareScoreGoodStart      = Color(uiColor: #colorLiteral(red: 0.20, green: 0.18, blue: 0.08, alpha: 1.00))
    static let shareScoreGoodEnd        = Color(uiColor: #colorLiteral(red: 0.12, green: 0.10, blue: 0.04, alpha: 1.00))
    static let shareScoreFairStart      = Color(uiColor: #colorLiteral(red: 0.22, green: 0.14, blue: 0.06, alpha: 1.00))
    static let shareScoreFairEnd        = Color(uiColor: #colorLiteral(red: 0.14, green: 0.08, blue: 0.03, alpha: 1.00))
    static let shareScorePoorStart      = Color(uiColor: #colorLiteral(red: 0.22, green: 0.08, blue: 0.08, alpha: 1.00))
    static let shareScorePoorEnd        = Color(uiColor: #colorLiteral(red: 0.14, green: 0.04, blue: 0.04, alpha: 1.00))
    static let shareSecondaryBackground = Color(uiColor: #colorLiteral(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.00))

    // MARK: - 6f. Live Activity
    // Source: LasoWidgets/WindDownLiveActivityWidget.swift:208
    static let windDownTint = Color(uiColor: #colorLiteral(red: 0.52, green: 0.49, blue: 0.86, alpha: 1.00)) // calm violet

    // MARK: - 6g. Launch Screen
    // Source: Assets.xcassets/LaunchBackground.colorset
    static let launchBackground = Color(uiColor: #colorLiteral(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00))
}
