import SwiftUI

/// App-wide colour palette.
///
/// Layers (top → bottom):
///   0. Surface & text     base / raised / elevated / overlay + text & border tokens
///   1. Brand              primary hero colour (calm Apple/Oura-adjacent blue)
///   2. Accent             call-to-action pop (teal cyan)
///   3. Semantic state     success / warning / danger / info
///   4. Score tiers        optimal / good / fair / poor / resting
///   5. Health categories  heart / sleep / activity / stress / vitality / brain
///   6. Feature-specific   achievement, vitality pace, health state, premium,
///                         shareable card gradients, live activity, launch
///
/// Swatch-pickable: every entry uses `#colorLiteral(...)` so Xcode shows an
/// inline colour well you can edit visually.
///
/// Dark-mode: the app is force-locked to dark in `LasoApp.swift`. All tokens
/// are tuned for dark backgrounds. Brand tokens keep light variants for
/// future-proofing. Semantic/score/category values stay static because they
/// are state indicators (same hue across modes per Apple HIG).
///
/// Prefer these tokens over raw `.systemBackground`, `Color.white`, or
/// `.opacity(…)` literals — consistency of surface and text pairs is what
/// makes a design system feel coherent.
enum AppColour {

    // MARK: - Dynamic Colour Helper
    // Wraps two `UIColor`s (light + dark variants) into a SwiftUI `Color`
    // that adapts automatically to the current interface style.
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // MARK: - 0. Surface & Text (dark-mode safe stack)
    //
    // Apple semantic surface stack. In dark mode these resolve to
    // `#000 → #1C1C1E → #2C2C2E → ~#3A3A3C`. Use these instead of raw
    // `Color.black` / `Color(.systemBackground)` calls throughout the app.

    /// Page / screen background.
    static let surfaceBase     = Color(uiColor: .systemBackground)
    /// Card / raised container.
    static let surfaceRaised   = Color(uiColor: .secondarySystemBackground)
    /// Sheet / elevated surface.
    static let surfaceElevated = Color(uiColor: .tertiarySystemBackground)
    /// Floating overlay (toasts, popovers). Manually specified #3A3A3C for dark.
    static let surfaceOverlay  = Color(uiColor: #colorLiteral(red: 0.227, green: 0.227, blue: 0.235, alpha: 1.00))

    /// Primary text — full label (auto-adapts; white on dark).
    static let textPrimary     = Color(uiColor: .label)
    /// Secondary text — ~60% white on dark.
    static let textSecondary   = Color(uiColor: .secondaryLabel)
    /// Tertiary text — ~30% white on dark.
    static let textTertiary    = Color(uiColor: .tertiaryLabel)
    /// Disabled / placeholder text — ~18% white on dark.
    static let textQuaternary  = Color(uiColor: .quaternaryLabel)

    /// Hairline separator — platform-native opaque separator.
    static let separator       = Color(uiColor: .separator)

    /// Low-alpha border (Linear / Vercel pattern — 6% white on dark). For flat cards.
    static let borderLow       = Color.white.opacity(0.06)
    /// Medium-alpha border (10%). For raised cards that need definition without noise.
    static let borderMedium    = Color.white.opacity(0.10)
    /// High-alpha border (14%). For overlays and floating surfaces.
    static let borderHigh      = Color.white.opacity(0.14)

    // MARK: - 1. Brand
    // Calm blue (Apple-adjacent). Light #0071E3 → softer #4DA3FF in dark.
    static let primary = dynamic(
        light: #colorLiteral(red: 0.00, green: 0.44, blue: 0.89, alpha: 1.00), // #0071E3
        dark:  #colorLiteral(red: 0.30, green: 0.64, blue: 1.00, alpha: 1.00)  // #4DA3FF
    )
    static let primarySoft = dynamic(
        light: #colorLiteral(red: 0.88, green: 0.94, blue: 1.00, alpha: 1.00), // #E0F0FF pale blue card bg
        dark:  #colorLiteral(red: 0.06, green: 0.14, blue: 0.24, alpha: 1.00)  // #0F243D dark blue wash
    )

    // MARK: - 2. Accent (CTAs, pop)
    static let accent = dynamic(
        light: #colorLiteral(red: 0.02, green: 0.71, blue: 0.83, alpha: 1.00), // #06B6D4 cyan
        dark:  #colorLiteral(red: 0.13, green: 0.83, blue: 0.93, alpha: 1.00)  // #22D3EE
    )

    // MARK: - 3. Semantic State
    static let success = Color(uiColor: #colorLiteral(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.00)) // #10B981
    static let warning = Color(uiColor: #colorLiteral(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.00)) // #F59E0B amber
    static let danger  = Color(uiColor: #colorLiteral(red: 0.90, green: 0.28, blue: 0.30, alpha: 1.00)) // #E5484D soft red
    static let info    = Color(uiColor: #colorLiteral(red: 0.00, green: 0.44, blue: 0.89, alpha: 1.00)) // #0071E3 matches primary

    // MARK: - 4. Score Tiers
    static let scoreOptimal = Color(uiColor: #colorLiteral(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.00)) // #10B981
    static let scoreGood    = Color(uiColor: #colorLiteral(red: 0.20, green: 0.83, blue: 0.60, alpha: 1.00)) // #34D399 teal
    static let scoreFair    = Color(uiColor: #colorLiteral(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.00)) // #F59E0B
    static let scorePoor    = Color(uiColor: #colorLiteral(red: 0.90, green: 0.28, blue: 0.30, alpha: 1.00)) // #E5484D

    // MARK: - 5. Health Categories (desaturated)
    static let categoryHeart    = Color(uiColor: #colorLiteral(red: 0.97, green: 0.44, blue: 0.44, alpha: 1.00)) // #F87171 soft rose
    static let categorySleep    = Color(uiColor: #colorLiteral(red: 0.51, green: 0.55, blue: 0.97, alpha: 1.00)) // #818CF8 soft indigo
    static let categoryActivity = Color(uiColor: #colorLiteral(red: 0.98, green: 0.75, blue: 0.14, alpha: 1.00)) // #FBBF24 soft amber
    static let categoryStress   = Color(uiColor: #colorLiteral(red: 0.65, green: 0.55, blue: 0.98, alpha: 1.00)) // #A78BFA soft purple
    static let categoryVitality = Color(uiColor: #colorLiteral(red: 0.20, green: 0.83, blue: 0.60, alpha: 1.00)) // #34D399 teal
    static let categoryBrain    = Color(uiColor: #colorLiteral(red: 0.96, green: 0.45, blue: 0.71, alpha: 1.00)) // #F472B6 soft magenta

    // MARK: - 6a. Achievement / Gamification Tiers
    // Source: Modules/Profile/Views/Profile/AchievementsView.swift:29-33
    //         Core/Analysis/GamificationEngine.swift:32-37 (same RGB + legend)
    static let achievementBronze   = Color(uiColor: #colorLiteral(red: 0.80, green: 0.50, blue: 0.20, alpha: 1.00))
    static let achievementSilver   = Color(uiColor: #colorLiteral(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.00))
    static let achievementGold     = Color(uiColor: #colorLiteral(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.00))
    static let achievementPlatinum = Color(uiColor: #colorLiteral(red: 0.90, green: 0.91, blue: 0.98, alpha: 1.00))
    static let achievementDiamond  = Color(uiColor: #colorLiteral(red: 0.72, green: 0.95, blue: 1.00, alpha: 1.00))
    static let achievementLegend   = Color(uiColor: #colorLiteral(red: 0.75, green: 0.72, blue: 0.98, alpha: 1.00)) // shifted toward calm lavender

    // MARK: - 6b. Vitality Pace Palette
    // Source: Modules/Vitality/Views/Vitality/VitalityDetailHelpers.swift:3-5, 41
    static let vitalityWhoopGreen    = Color(uiColor: #colorLiteral(red: 0.20, green: 0.83, blue: 0.60, alpha: 1.00)) // #34D399 teal
    static let vitalityPaceYellow    = Color(uiColor: #colorLiteral(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.00)) // #F59E0B amber
    static let vitalityPaceRed       = Color(uiColor: #colorLiteral(red: 0.90, green: 0.28, blue: 0.30, alpha: 1.00)) // #E5484D soft red
    static let vitalityDeltaNegative = Color(uiColor: #colorLiteral(red: 0.13, green: 0.83, blue: 0.93, alpha: 1.00)) // cyan

    // MARK: - 6c. Health State Timeline
    // Source: Modules/HealthState/ViewModels/HealthStateTimelineViewModel.swift:42-52
    static let stateRecovery        = Color(uiColor: #colorLiteral(red: 0.20, green: 0.83, blue: 0.60, alpha: 1.00)) // #34D399
    static let statePeakPerformance = Color(uiColor: #colorLiteral(red: 0.00, green: 0.44, blue: 0.89, alpha: 1.00)) // #0071E3
    static let stateStressed        = Color(uiColor: #colorLiteral(red: 0.90, green: 0.28, blue: 0.30, alpha: 1.00)) // #E5484D
    static let stateUnderSlept      = Color(uiColor: #colorLiteral(red: 0.65, green: 0.55, blue: 0.98, alpha: 1.00)) // #A78BFA
    static let stateActive          = Color(uiColor: #colorLiteral(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.00)) // #10B981
    static let stateFatigued        = Color(uiColor: #colorLiteral(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.00)) // #F59E0B
    static let stateResting         = Color(uiColor: #colorLiteral(red: 0.30, green: 0.64, blue: 1.00, alpha: 1.00)) // #4DA3FF
    static let stateDefault         = Color(uiColor: #colorLiteral(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.00))

    // MARK: - 6d. Premium / Subscription Badge
    // Source: Modules/Settings/Views/SettingsView.swift:178, 185-186
    static let premiumBadgeText      = dynamic(
        light: #colorLiteral(red: 0.35, green: 0.22, blue: 0.02, alpha: 1.00),
        dark:  #colorLiteral(red: 0.12, green: 0.08, blue: 0.02, alpha: 1.00)
    )
    static let premiumGradientTop    = Color(uiColor: #colorLiteral(red: 1.00, green: 0.85, blue: 0.45, alpha: 1.00))
    static let premiumGradientBottom = Color(uiColor: #colorLiteral(red: 0.96, green: 0.64, blue: 0.18, alpha: 1.00))

    // MARK: - 6e. Shareable Score Card (dark-themed tier backgrounds)
    // Source: Common/Components/ShareableCard.swift:28-31, 186
    static let shareScoreHighStart      = Color(uiColor: #colorLiteral(red: 0.08, green: 0.18, blue: 0.15, alpha: 1.00))
    static let shareScoreHighEnd        = Color(uiColor: #colorLiteral(red: 0.04, green: 0.10, blue: 0.08, alpha: 1.00))
    static let shareScoreGoodStart      = Color(uiColor: #colorLiteral(red: 0.06, green: 0.16, blue: 0.22, alpha: 1.00))
    static let shareScoreGoodEnd        = Color(uiColor: #colorLiteral(red: 0.03, green: 0.09, blue: 0.14, alpha: 1.00))
    static let shareScoreFairStart      = Color(uiColor: #colorLiteral(red: 0.22, green: 0.14, blue: 0.06, alpha: 1.00))
    static let shareScoreFairEnd        = Color(uiColor: #colorLiteral(red: 0.14, green: 0.08, blue: 0.03, alpha: 1.00))
    static let shareScorePoorStart      = Color(uiColor: #colorLiteral(red: 0.20, green: 0.08, blue: 0.09, alpha: 1.00))
    static let shareScorePoorEnd        = Color(uiColor: #colorLiteral(red: 0.12, green: 0.04, blue: 0.05, alpha: 1.00))
    static let shareSecondaryBackground = Color(uiColor: #colorLiteral(red: 0.07, green: 0.09, blue: 0.11, alpha: 1.00))

    // MARK: - 6f. Live Activity
    // Source: LasoWidgets/WindDownLiveActivityWidget.swift:208
    static let windDownTint = Color(uiColor: #colorLiteral(red: 0.51, green: 0.55, blue: 0.97, alpha: 1.00)) // calm soft indigo

    // MARK: - 6g. Launch Screen
    // Source: Assets.xcassets/LaunchBackground.colorset
    static let launchBackground = Color(uiColor: #colorLiteral(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00))
}
