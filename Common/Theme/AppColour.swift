import SwiftUI

/// App-wide colour palette. Every token resolves for BOTH light and dark.
///
/// One rule governs the whole file: a token keeps the same colour identity in both
/// modes and only its lightness moves. Hue drift across a pair is at most 5 degrees.
/// That is what lets a status colour still mean the same thing after the user flips
/// the theme.
///
/// Contrast here is not a matter of taste. Every text token clears WCAG AA 4.5:1
/// against the surface named in its comment, and every load-bearing graphic clears
/// 3:1, in BOTH modes. The values were machine-checked against the WCAG 2.2
/// relative-luminance formula before they were written. Editing one by hand without
/// re-running that check is how the guarantee quietly disappears.
///
/// Yellow is the one hue that cannot survive both grounds unchanged: no yellow
/// reaches 3:1 on white at any saturation. So `warning`, `scoreFair`,
/// `categoryActivity`, `stateFatigued` and `vitalityPaceYellow` are a brown-gold in
/// light and return to gold in dark.
///
/// Some tokens are identical in both modes on purpose. `surfaceInverse` and its
/// companions paint surfaces that must stay dark whichever theme is active (the
/// Vitality hero, the orb, Live Activities) because the blend modes they rely on
/// — `.plusLighter`, `.screen` — are arithmetic no-ops against a light destination.
///
/// Swatch-pickable: every entry uses `#colorLiteral(...)` so Xcode shows an inline
/// colour well you can edit visually.
enum AppColour {

    // MARK: - Dynamic Colour Helper

    private struct DynamicKey: Hashable {
        let light: UInt64
        let dark: UInt64
    }

    /// One shared closure-backed `UIColor` per (light, dark) pair.
    ///
    /// The RC-backed tokens below are computed `static var`s, so before this
    /// cache every read minted a brand-new `UIColor`. Two `Color`s wrapping
    /// different `UIColor` instances are not equal, which silently defeated
    /// SwiftUI's value-diffing early-out in every view that stores a
    /// `let color: Color` — across 186 read sites.
    ///
    /// `nonisolated(unsafe)` + `NSLock`: colours are read from background
    /// scorers as well as view bodies, and the entries are immutable once
    /// written. Bounded by the number of distinct token pairs in this file.
    private static let dynamicCacheLock = NSLock()
    nonisolated(unsafe) private static var dynamicCache: [DynamicKey: Color] = [:]

    /// sRGB components packed at 16 bits per channel. Keying on the components
    /// rather than on the `UIColor` objects keeps the cache exact for the
    /// three-decimal literals below without depending on `UIColor`'s own
    /// hashing, where a miss would mean unbounded growth rather than a wrong
    /// colour. nil for any colour that is not component-readable, which then
    /// simply skips the cache.
    private static func packedComponents(_ colour: UIColor) -> UInt64? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard colour.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func quantise(_ value: CGFloat) -> UInt64 {
            UInt64((min(max(value, 0), 1) * 65_535).rounded())
        }
        return quantise(r) << 48 | quantise(g) << 32 | quantise(b) << 16 | quantise(a)
    }

    /// Wraps a light + dark pair into a `Color` that follows the active theme.
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        guard let lightKey = packedComponents(light), let darkKey = packedComponents(dark) else {
            return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
        let key = DynamicKey(light: lightKey, dark: darkKey)

        dynamicCacheLock.lock()
        defer { dynamicCacheLock.unlock() }
        if let hit = dynamicCache[key] { return hit }
        let colour = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        dynamicCache[key] = colour
        return colour
    }

    // MARK: - Remote-overridable wrapper
    //
    // Designer-tweakable tokens read Firebase Remote Config at call time. Remote
    // Config stores ONE hex per key, so publishing an override deliberately
    // collapses that token's light/dark pair to a single colour in both modes.
    // That is the price of recolouring without shipping a build, and it is exactly
    // why the bundled pair below has to be correct on its own.
    //
    // These keys carry no in-app default (see `RemoteConfigSchema.expandedDefaults`),
    // so this returns nil until someone actually publishes a value and the bundled
    // pair is what ships. Giving them in-app defaults is what previously made the
    // app and the widget render different score colours.
    //
    // The widget extension does not link Firebase and always uses the bundled pair.
    private static func remote(_ key: String, light: UIColor, dark: UIColor) -> Color {
        #if WIDGET_EXTENSION
        return dynamic(light: light, dark: dark)
        #else
        if let override = RemoteConfigManager.shared.color(forKey: key) { return override }
        return dynamic(light: light, dark: dark)
        #endif
    }

    // MARK: - 0. Surfaces — page, cards, sheets, overlays

    /// Page behind a page: grouped-list background, scroll container under cards, sheet backdrop.
    static let surfaceSunken = dynamic(
        light: #colorLiteral(red: 0.894, green: 0.894, blue: 0.925, alpha: 1.00),
        dark:  #colorLiteral(red: 0.031, green: 0.031, blue: 0.039, alpha: 1.00)
    )

    /// Default page/screen background.
    static let surfaceBase = dynamic(
        light: #colorLiteral(red: 0.933, green: 0.933, blue: 0.957, alpha: 1.00),
        dark:  #colorLiteral(red: 0.059, green: 0.059, blue: 0.075, alpha: 1.00)
    )

    /// Card fill: cardStyle(), chips, tiles, icon discs, field backgrounds.
    static let surfaceRaised = dynamic(
        light: #colorLiteral(red: 0.973, green: 0.973, blue: 0.984, alpha: 1.00),
        dark:  #colorLiteral(red: 0.106, green: 0.106, blue: 0.129, alpha: 1.00)
    )

    /// Sheet, popover body, card nested inside a card.
    static let surfaceElevated = dynamic(
        light: #colorLiteral(red: 0.988, green: 0.988, blue: 0.992, alpha: 1.00),
        dark:  #colorLiteral(red: 0.149, green: 0.149, blue: 0.176, alpha: 1.00)
    )

    /// Opaque floating chrome: toasts, chart scrub tooltips, menus. Replaces .ultraThinMaterial where the surface must occlude.
    static let surfaceOverlay = dynamic(
        light: #colorLiteral(red: 0.996, green: 0.996, blue: 1.000, alpha: 1.00),
        dark:  #colorLiteral(red: 0.200, green: 0.200, blue: 0.231, alpha: 1.00)
    )

    /// Barely-there fill: inactive rows, badge/pill containers, mock-sheet bodies, unselected chips. Replaces the tint@12% pattern.
    static let surfaceSubtle = dynamic(
        light: #colorLiteral(red: 0.918, green: 0.918, blue: 0.945, alpha: 1.00),
        dark:  #colorLiteral(red: 0.090, green: 0.090, blue: 0.110, alpha: 1.00)
    )

    /// Neutral solid chip/badge fill carrying textOnAccent. Replaces raw Color.gray and .gray.gradient. Sits on `surfaceRaised`.
    static let surfaceMuted = dynamic(
        light: #colorLiteral(red: 0.431, green: 0.431, blue: 0.478, alpha: 1.00),
        dark:  #colorLiteral(red: 0.557, green: 0.557, blue: 0.604, alpha: 1.00)
    )

    /// Declared always-dark island: Vitality hero card, VitalityOrganicOrb canvas, AskDataOrb canvas. Static because .screen and .plusLighter are arithmetic no-ops on a light destination.
    static let surfaceInverse = Color(uiColor: #colorLiteral(red: 0.063, green: 0.063, blue: 0.078, alpha: 1.00))

    /// Raised chip on surfaceInverse: OrbMetricChip, hero badges. Static for the same reason as surfaceInverse.
    static let surfaceInverseRaised = Color(uiColor: #colorLiteral(red: 0.165, green: 0.165, blue: 0.196, alpha: 1.00))

    /// Deliberately mode-independent light surface simulating iOS chrome: the mock push banner in onboarding. Static because it depicts system UI, not app UI.
    static let surfaceFixedLight = Color(uiColor: #colorLiteral(red: 0.969, green: 0.969, blue: 0.976, alpha: 1.00))

    /// activityBackgroundTint for all three Live Activities. Static: the widget target does not inherit the app theme and all activity art is white-alpha strokes plus additive blooms. WindDownLiveActivityWidget already does this correctly by accident.
    static let liveActivityCanvas = Color(uiColor: #colorLiteral(red: 0.086, green: 0.086, blue: 0.106, alpha: 1.00))

    /// Launch screen and cold-start splash. LaunchBackground.colorset must gain a light appearance.
    static let splashBackground = dynamic(
        light: #colorLiteral(red: 0.933, green: 0.933, blue: 0.957, alpha: 1.00),
        dark:  #colorLiteral(red: 0.031, green: 0.031, blue: 0.039, alpha: 1.00)
    )


    // MARK: - 1. Text — the four-step label ramp plus on-fill pairs

    /// Headings, body copy, hero numerals. Sits on `surfaceBase`.
    static let textPrimary = dynamic(
        light: #colorLiteral(red: 0.106, green: 0.106, blue: 0.125, alpha: 1.00),
        dark:  #colorLiteral(red: 0.949, green: 0.949, blue: 0.965, alpha: 1.00)
    )

    /// Supporting copy, subtitles, row detail. Sits on `surfaceBase`.
    static let textSecondary = dynamic(
        light: #colorLiteral(red: 0.267, green: 0.267, blue: 0.302, alpha: 1.00),
        dark:  #colorLiteral(red: 0.788, green: 0.788, blue: 0.824, alpha: 1.00)
    )

    /// Captions, units, timestamps, metadata. Sits on `surfaceBase`.
    static let textTertiary = dynamic(
        light: #colorLiteral(red: 0.357, green: 0.357, blue: 0.396, alpha: 1.00),
        dark:  #colorLiteral(red: 0.678, green: 0.678, blue: 0.722, alpha: 1.00)
    )

    /// Placeholder and disabled label. Raised above the legal exemption to AA because a greyed-out health metric still has to be identifiable; hierarchy below tertiary is now carried by size and weight, not colour. Sits on `surfaceBase`.
    static let textQuaternary = dynamic(
        light: #colorLiteral(red: 0.384, green: 0.384, blue: 0.424, alpha: 1.00),
        dark:  #colorLiteral(red: 0.651, green: 0.651, blue: 0.698, alpha: 1.00)
    )

    /// Every label, glyph and numeral drawn ON a saturated fill. Flips polarity with the fill (M3 onPrimary tone 100 light / tone 20 dark). Clears 4.5:1 on all 34 fill tokens in both modes. Sits on `primary`.
    static let textOnAccent = dynamic(
        light: #colorLiteral(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.00),
        dark:  #colorLiteral(red: 0.086, green: 0.086, blue: 0.102, alpha: 1.00)
    )

    /// Primary foreground on surfaceInverse / surfaceInverseRaised: vitality age numeral, orb particles, chip values. Static because its surface is static. Sits on `surfaceInverse`.
    static let textOnInverse = Color(uiColor: #colorLiteral(red: 0.961, green: 0.961, blue: 0.973, alpha: 1.00))

    /// Supporting foreground on surfaceInverse: VITALITY AGE label, hero narrative sentence, chip metric name. Sits on `surfaceInverse`.
    static let textOnInverseSecondary = Color(uiColor: #colorLiteral(red: 0.706, green: 0.706, blue: 0.753, alpha: 1.00))

    /// Dark text pinned to surfaceFixedLight (mock push banner). Named specifically so a future refactor does not migrate it to textPrimary and invert it. Sits on `surfaceFixedLight`.
    static let textOnLightFixed = Color(uiColor: #colorLiteral(red: 0.110, green: 0.110, blue: 0.125, alpha: 1.00))


    // MARK: - 2. Borders — opaque neutral steps, never alpha

    /// Decorative hairline: dividers, flat-card outlines, row separators. Opaque neutral step, not alpha. WCAG 1.4.11 decorative exemption, tuned to the APCA Lc 15 discernibility floor.
    static let borderLow = dynamic(
        light: #colorLiteral(red: 0.878, green: 0.878, blue: 0.910, alpha: 1.00),
        dark:  #colorLiteral(red: 0.180, green: 0.180, blue: 0.212, alpha: 1.00)
    )

    /// Component outline that is not the sole identifier: raised-card definition, dashed coupon border, chip strokes.
    static let borderMedium = dynamic(
        light: #colorLiteral(red: 0.788, green: 0.788, blue: 0.827, alpha: 1.00),
        dark:  #colorLiteral(red: 0.255, green: 0.255, blue: 0.286, alpha: 1.00)
    )

    /// Strong outline on floating surfaces, selected chips, emphasised card edges.
    static let borderHigh = dynamic(
        light: #colorLiteral(red: 0.659, green: 0.659, blue: 0.706, alpha: 1.00),
        dark:  #colorLiteral(red: 0.361, green: 0.361, blue: 0.408, alpha: 1.00)
    )

    /// Focus ring and any border that is the ONLY thing identifying an interactive control (text field outline, unselected toggle). Meets SC 1.4.11 3:1. Sits on `surfaceRaised`.
    static let borderFocus = dynamic(
        light: #colorLiteral(red: 0.431, green: 0.431, blue: 0.478, alpha: 1.00),
        dark:  #colorLiteral(red: 0.557, green: 0.557, blue: 0.604, alpha: 1.00)
    )

    /// Hairline on surfaceInverse and liveActivityCanvas. Replaces the six Color.white.opacity(0.06-0.12) strokes inside the Live Activity widgets.
    static let borderOnInverse = Color(uiColor: #colorLiteral(red: 0.290, green: 0.290, blue: 0.329, alpha: 1.00))


    // MARK: - 3. Brand

    /// Brand blue: primary buttons, links, selection state, section glyphs. Carries textOnAccent. Sits on `surfaceRaised`.
    static let primary = dynamic(
        light: #colorLiteral(red: 0.000, green: 0.392, blue: 0.800, alpha: 1.00),
        dark:  #colorLiteral(red: 0.302, green: 0.639, blue: 1.000, alpha: 1.00)
    )

    /// Pale brand wash behind callout cards. Container fill only, never a graphic boundary; textPrimary on it scores 14.1 light / 13.7 dark.
    static let primarySoft = dynamic(
        light: #colorLiteral(red: 0.863, green: 0.922, blue: 0.980, alpha: 1.00),
        dark:  #colorLiteral(red: 0.063, green: 0.149, blue: 0.247, alpha: 1.00)
    )

    /// Cyan CTA pop: breathwork controls, Ask-your-data affordances, accent eyebrows. Light variant darkened from #06B6D4 (2.4:1) to clear white text. Sits on `surfaceRaised`.
    static let accent = dynamic(
        light: #colorLiteral(red: 0.055, green: 0.455, blue: 0.565, alpha: 1.00),
        dark:  #colorLiteral(red: 0.133, green: 0.827, blue: 0.933, alpha: 1.00)
    )


    // MARK: - 4. Semantic state

    /// Positive state: fills, dots, positive deltas, success glyphs, and the same value as text on a surface. Sits on `surfaceRaised`.
    static let success = dynamic(
        light: #colorLiteral(red: 0.055, green: 0.478, blue: 0.322, alpha: 1.00),
        dark:  #colorLiteral(red: 0.200, green: 0.769, blue: 0.553, alpha: 1.00)
    )

    /// Caution state: banner glyphs, severity badges, weakest-pillar dot, billing-grace banner. Light variant is a brown-gold because no yellow reaches 3:1 on a light surface. Sits on `surfaceRaised`.
    static let warning = dynamic(
        light: #colorLiteral(red: 0.541, green: 0.392, blue: 0.000, alpha: 1.00),
        dark:  #colorLiteral(red: 0.890, green: 0.706, blue: 0.353, alpha: 1.00)
    )

    /// Alert state: critical badges, declining trends, destructive actions. Sits on `surfaceRaised`.
    static let danger = dynamic(
        light: #colorLiteral(red: 0.769, green: 0.169, blue: 0.200, alpha: 1.00),
        dark:  #colorLiteral(red: 0.878, green: 0.361, blue: 0.392, alpha: 1.00)
    )

    /// Neutral information: share CTA fill, informational badges, setup-guide chips. Sits on `surfaceRaised`.
    static let info = dynamic(
        light: #colorLiteral(red: 0.000, green: 0.392, blue: 0.800, alpha: 1.00),
        dark:  #colorLiteral(red: 0.302, green: 0.639, blue: 1.000, alpha: 1.00)
    )


    // MARK: - 5. Score tiers

    /// Score band 85-100: ring stroke, hero numeral, widget arc, day-dial ticks. Sits on `surfaceRaised`.
    static var scoreOptimal: Color {
        remote(RC.colorScoreOptimal,
               light: #colorLiteral(red: 0.055, green: 0.478, blue: 0.322, alpha: 1.00),
               dark:  #colorLiteral(red: 0.200, green: 0.769, blue: 0.553, alpha: 1.00))
    }

    /// Score band 70-84: ring stroke, hero numeral, widget arc. Sits on `surfaceRaised`.
    static var scoreGood: Color {
        remote(RC.colorScoreGood,
               light: #colorLiteral(red: 0.047, green: 0.467, blue: 0.322, alpha: 1.00),
               dark:  #colorLiteral(red: 0.239, green: 0.800, blue: 0.600, alpha: 1.00))
    }

    /// Score band 50-69: ring stroke and the 45pt hero numeral in HealthScoreRing:74, the single most-read number in the product. Sits on `surfaceRaised`.
    static var scoreFair: Color {
        remote(RC.colorScoreFair,
               light: #colorLiteral(red: 0.541, green: 0.392, blue: 0.000, alpha: 1.00),
               dark:  #colorLiteral(red: 0.890, green: 0.706, blue: 0.353, alpha: 1.00))
    }

    /// Score band 0-49: ring stroke, hero numeral, band label. Vermillion-leaning red for deuteranope separation from the green end. Sits on `surfaceRaised`.
    static var scorePoor: Color {
        remote(RC.colorScorePoor,
               light: #colorLiteral(red: 0.769, green: 0.169, blue: 0.200, alpha: 1.00),
               dark:  #colorLiteral(red: 0.878, green: 0.361, blue: 0.392, alpha: 1.00))
    }


    // MARK: - 6. Health categories

    /// Cardiovascular category tint: icon fills, chart lines, category labels. Sits on `surfaceRaised`.
    static var categoryHeart: Color {
        remote(RC.colorCategoryHeart,
               light: #colorLiteral(red: 0.725, green: 0.227, blue: 0.227, alpha: 1.00),
               dark:  #colorLiteral(red: 0.973, green: 0.443, blue: 0.443, alpha: 1.00))
    }

    /// Sleep category tint: sleep-coach glyphs, sleep bars, category labels. Sits on `surfaceRaised`.
    static var categorySleep: Color {
        remote(RC.colorCategorySleep,
               light: #colorLiteral(red: 0.329, green: 0.357, blue: 0.839, alpha: 1.00),
               dark:  #colorLiteral(red: 0.506, green: 0.549, blue: 0.973, alpha: 1.00))
    }

    /// Activity category tint. Worst offender today at 1.68:1 on white; light variant is a dark amber. Sits on `surfaceRaised`.
    static var categoryActivity: Color {
        remote(RC.colorCategoryActivity,
               light: #colorLiteral(red: 0.541, green: 0.353, blue: 0.000, alpha: 1.00),
               dark:  #colorLiteral(red: 0.984, green: 0.749, blue: 0.141, alpha: 1.00))
    }

    /// Stress/recovery category tint: gauges, chain arrows, callout borders. Sits on `surfaceRaised`.
    static var categoryStress: Color {
        remote(RC.colorCategoryStress,
               light: #colorLiteral(red: 0.427, green: 0.294, blue: 0.839, alpha: 1.00),
               dark:  #colorLiteral(red: 0.655, green: 0.545, blue: 0.980, alpha: 1.00))
    }


    // MARK: - 7. Health state timeline

    /// Health state Recovery: opaque calendar-cell fill, timeline band, state icon disc. Fill must be opaque so textOnAccent holds; the old .opacity(0.7) is what drops the day number to 1.4:1. Sits on `surfaceRaised`.
    static var stateRecovery: Color {
        remote(RC.colorStateRecovery,
               light: #colorLiteral(red: 0.051, green: 0.486, blue: 0.333, alpha: 1.00),
               dark:  #colorLiteral(red: 0.204, green: 0.827, blue: 0.600, alpha: 1.00))
    }

    /// Health state Peak Performance: calendar-cell fill, timeline band, state icon disc. Sits on `surfaceRaised`.
    static var statePeakPerformance: Color {
        remote(RC.colorStatePeakPerformance,
               light: #colorLiteral(red: 0.000, green: 0.392, blue: 0.800, alpha: 1.00),
               dark:  #colorLiteral(red: 0.302, green: 0.639, blue: 1.000, alpha: 1.00))
    }

    /// Health state Stressed: calendar-cell fill, timeline band, state icon disc. Sits on `surfaceRaised`.
    static var stateStressed: Color {
        remote(RC.colorStateStressed,
               light: #colorLiteral(red: 0.761, green: 0.125, blue: 0.149, alpha: 1.00),
               dark:  #colorLiteral(red: 0.918, green: 0.353, blue: 0.373, alpha: 1.00))
    }

    /// Health state Under-slept: calendar-cell fill, timeline band, state icon disc. Sits on `surfaceRaised`.
    static var stateUnderSlept: Color {
        remote(RC.colorStateUnderSlept,
               light: #colorLiteral(red: 0.427, green: 0.294, blue: 0.839, alpha: 1.00),
               dark:  #colorLiteral(red: 0.655, green: 0.545, blue: 0.980, alpha: 1.00))
    }

    /// Health state Active: calendar-cell fill, timeline band, state icon disc. Sits on `surfaceRaised`.
    static var stateActive: Color {
        remote(RC.colorStateActive,
               light: #colorLiteral(red: 0.039, green: 0.451, blue: 0.314, alpha: 1.00),
               dark:  #colorLiteral(red: 0.063, green: 0.725, blue: 0.506, alpha: 1.00))
    }

    /// Health state Fatigued: calendar-cell fill, timeline band, state icon disc. Sits on `surfaceRaised`.
    static var stateFatigued: Color {
        remote(RC.colorStateFatigued,
               light: #colorLiteral(red: 0.541, green: 0.337, blue: 0.000, alpha: 1.00),
               dark:  #colorLiteral(red: 0.961, green: 0.620, blue: 0.043, alpha: 1.00))
    }

    /// Health state Resting: calendar-cell fill, timeline band, state icon disc. Previously the dark-only #4DA3FF frozen as a static literal. Sits on `surfaceRaised`.
    static var stateResting: Color {
        remote(RC.colorStateResting,
               light: #colorLiteral(red: 0.000, green: 0.392, blue: 0.800, alpha: 1.00),
               dark:  #colorLiteral(red: 0.302, green: 0.639, blue: 1.000, alpha: 1.00))
    }

    /// Unknown health state and unclassified training zone. Never RC-overridden. Sits on `surfaceRaised`.
    static let stateDefault = dynamic(
        light: #colorLiteral(red: 0.400, green: 0.400, blue: 0.431, alpha: 1.00),
        dark:  #colorLiteral(red: 0.604, green: 0.604, blue: 0.643, alpha: 1.00)
    )


    // MARK: - 8. Vitality pace

    /// Vitality pace ahead: bar fill, pace badge, gauge healthy end. Sits on `surfaceRaised`.
    static var vitalityWhoopGreen: Color {
        remote(RC.colorVitalityGreen,
               light: #colorLiteral(red: 0.051, green: 0.486, blue: 0.333, alpha: 1.00),
               dark:  #colorLiteral(red: 0.204, green: 0.827, blue: 0.600, alpha: 1.00))
    }

    /// Vitality pace holding: bar fill, pace badge, gauge caution band. Sits on `surfaceRaised`.
    static var vitalityPaceYellow: Color {
        remote(RC.colorVitalityYellow,
               light: #colorLiteral(red: 0.541, green: 0.337, blue: 0.000, alpha: 1.00),
               dark:  #colorLiteral(red: 0.961, green: 0.620, blue: 0.043, alpha: 1.00))
    }

    /// Vitality pace behind: bar fill, pace badge, gauge risk end. Dark variant lifted from #E5484D to clear 4.5:1 as text on the dark card. Sits on `surfaceRaised`.
    static var vitalityPaceRed: Color {
        remote(RC.colorVitalityRed,
               light: #colorLiteral(red: 0.761, green: 0.125, blue: 0.149, alpha: 1.00),
               dark:  #colorLiteral(red: 0.918, green: 0.353, blue: 0.373, alpha: 1.00))
    }

    /// Cyan years-delta indicator. Brand-locked, never RC-exposed. Sits on `surfaceRaised`.
    static let vitalityDeltaNegative = dynamic(
        light: #colorLiteral(red: 0.055, green: 0.455, blue: 0.565, alpha: 1.00),
        dark:  #colorLiteral(red: 0.133, green: 0.827, blue: 0.933, alpha: 1.00)
    )


    // MARK: - 9. Achievement tiers

    /// Bronze tier: level ring arc, tier icon, tier label. Sits on `surfaceRaised`.
    static var achievementBronze: Color {
        remote(RC.colorAchievementBronze,
               light: #colorLiteral(red: 0.541, green: 0.322, blue: 0.125, alpha: 1.00),
               dark:  #colorLiteral(red: 0.800, green: 0.502, blue: 0.200, alpha: 1.00))
    }

    /// Silver tier: level ring arc, tier icon, tier label. Sits on `surfaceRaised`.
    static var achievementSilver: Color {
        remote(RC.colorAchievementSilver,
               light: #colorLiteral(red: 0.424, green: 0.424, blue: 0.471, alpha: 1.00),
               dark:  #colorLiteral(red: 0.749, green: 0.749, blue: 0.780, alpha: 1.00))
    }

    /// Gold tier: level ring arc, tier icon, tier label. 1.4:1 on white today. Sits on `surfaceRaised`.
    static var achievementGold: Color {
        remote(RC.colorAchievementGold,
               light: #colorLiteral(red: 0.478, green: 0.384, blue: 0.000, alpha: 1.00),
               dark:  #colorLiteral(red: 1.000, green: 0.843, blue: 0.000, alpha: 1.00))
    }

    /// Platinum tier: level ring arc, tier icon, tier label. 1.15:1 on white today. Sits on `surfaceRaised`.
    static var achievementPlatinum: Color {
        remote(RC.colorAchievementPlatinum,
               light: #colorLiteral(red: 0.380, green: 0.404, blue: 0.529, alpha: 1.00),
               dark:  #colorLiteral(red: 0.902, green: 0.910, blue: 0.980, alpha: 1.00))
    }

    /// Diamond tier: level ring arc, tier icon, max-level celebration text. 1.2:1 on white today. Sits on `surfaceRaised`.
    static var achievementDiamond: Color {
        remote(RC.colorAchievementDiamond,
               light: #colorLiteral(red: 0.173, green: 0.447, blue: 0.525, alpha: 1.00),
               dark:  #colorLiteral(red: 0.722, green: 0.949, blue: 1.000, alpha: 1.00))
    }


    // MARK: - 10. Premium / subscription

    /// Top stop of the Pro badge gold gradient. Fill only; the badge is identified by its dark label, not by a 3:1 edge, which is Carbon's documented handling of yellow.
    static var premiumGradientTop: Color {
        remote(RC.colorPremiumGradientTop,
               light: #colorLiteral(red: 0.941, green: 0.725, blue: 0.235, alpha: 1.00),
               dark:  #colorLiteral(red: 1.000, green: 0.851, blue: 0.451, alpha: 1.00))
    }

    /// Bottom stop of the Pro badge gold gradient, and the worst-case background for premiumBadgeText.
    static var premiumGradientBottom: Color {
        remote(RC.colorPremiumGradientBottom,
               light: #colorLiteral(red: 0.851, green: 0.541, blue: 0.094, alpha: 1.00),
               dark:  #colorLiteral(red: 0.961, green: 0.639, blue: 0.180, alpha: 1.00))
    }

    /// Label on the gold Pro badge. Light variant darkened from #593805, which measured 3.78:1 on the light gradient bottom. Sits on `premiumGradientBottom`.
    static let premiumBadgeText = dynamic(
        light: #colorLiteral(red: 0.239, green: 0.149, blue: 0.000, alpha: 1.00),
        dark:  #colorLiteral(red: 0.122, green: 0.078, blue: 0.020, alpha: 1.00)
    )


    // MARK: - 11. Charts

    /// Chart axis tick labels and legend text. Same ramp step as textTertiary, named separately so charts can be retuned without touching body copy. Sits on `surfaceRaised`.
    static let chartAxisLabel = dynamic(
        light: #colorLiteral(red: 0.357, green: 0.357, blue: 0.396, alpha: 1.00),
        dark:  #colorLiteral(red: 0.678, green: 0.678, blue: 0.722, alpha: 1.00)
    )

    /// Axis gridlines on every Charts plot. Decorative under SC 1.4.11 (the axis labels carry the scale), tuned to the APCA discernibility floor.
    static let chartGridline = dynamic(
        light: #colorLiteral(red: 0.871, green: 0.871, blue: 0.902, alpha: 1.00),
        dark:  #colorLiteral(red: 0.188, green: 0.188, blue: 0.220, alpha: 1.00)
    )

    /// Load-bearing baselines: SleepBank zero axis, target reference lines, average rules. Held at 4.3:1 because surplus vs deficit is unreadable without it. Sits on `surfaceRaised`.
    static let chartZeroLine = dynamic(
        light: #colorLiteral(red: 0.459, green: 0.459, blue: 0.498, alpha: 1.00),
        dark:  #colorLiteral(red: 0.522, green: 0.522, blue: 0.561, alpha: 1.00)
    )

    /// Usual-range / normal-band RectangleMark behind sparklines and trend lines. Opaque so it cannot evaporate at low alpha over a light card.
    static let chartBandFill = dynamic(
        light: #colorLiteral(red: 0.906, green: 0.906, blue: 0.937, alpha: 1.00),
        dark:  #colorLiteral(red: 0.137, green: 0.137, blue: 0.169, alpha: 1.00)
    )

    /// Opaque bottom stop for every AreaMark gradient; the series tint sits on top at 0.35 light / 0.28 dark instead of fading to a 2% no-op.
    static let chartAreaFill = dynamic(
        light: #colorLiteral(red: 0.894, green: 0.894, blue: 0.925, alpha: 1.00),
        dark:  #colorLiteral(red: 0.118, green: 0.118, blue: 0.149, alpha: 1.00)
    )


    // MARK: - 12. Feature-specific and deliberately fixed-polarity

    /// Modal dim and photo readability scrim. Black in both modes per Material 3 (shadow and scrim are pinned to tone 0 in both schemes).
    static let scrim = dynamic(
        light: #colorLiteral(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.45),
        dark:  #colorLiteral(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.62)
    )

    /// Unfilled rail of every progress bar, ring, gauge and day-dial, plus toggle-off tracks and missing-data placeholder bars. Load-bearing, so 3:1 minimum. Sits on `surfaceRaised`.
    static let trackNeutral = dynamic(
        light: #colorLiteral(red: 0.541, green: 0.541, blue: 0.588, alpha: 1.00),
        dark:  #colorLiteral(red: 0.451, green: 0.451, blue: 0.494, alpha: 1.00)
    )

    /// Ring and progress track on liveActivityCanvas / surfaceInverse. Static with its canvas. Sits on `liveActivityCanvas`.
    static let trackOnInverse = Color(uiColor: #colorLiteral(red: 0.416, green: 0.416, blue: 0.455, alpha: 1.00))

    /// Halo, donut hole and separator ring that must read as the card showing through: selected chart points, cycle-wheel marker, gauge marker outline. Tracks surfaceRaised by definition.
    static let markerOnSurface = dynamic(
        light: #colorLiteral(red: 0.973, green: 0.973, blue: 0.984, alpha: 1.00),
        dark:  #colorLiteral(red: 0.106, green: 0.106, blue: 0.129, alpha: 1.00)
    )

    /// Marker dot and particle colour on surfaceInverse: orb particles, chip gauge position marker. Sits on `surfaceInverse`.
    static let markerOnInverse = Color(uiColor: #colorLiteral(red: 0.961, green: 0.961, blue: 0.973, alpha: 1.00))

    /// Card and tile elevation. Light carries the elevation the lightness ramp cannot; dark is a supporting cue only, since surface steps do the work there. Radius and y must also be mode-aware (light r8 y2, dark r2 y1).
    static let shadowAmbient = dynamic(
        light: #colorLiteral(red: 0.078, green: 0.078, blue: 0.102, alpha: 0.10),
        dark:  #colorLiteral(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.40)
    )

    /// Floating chrome: tab pill, tooltips, toasts, sheets. Light replaces the current .black@0.22 r14, which is a grey smudge on a light page.
    static let shadowFloating = dynamic(
        light: #colorLiteral(red: 0.078, green: 0.078, blue: 0.102, alpha: 0.16),
        dark:  #colorLiteral(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.55)
    )

    /// Replacement for the 20 zero-offset coloured .shadow blooms. Degrades to a neutral ambient lift in light and stays an emitted-light cue in dark; the hue comes from the element, not from this token.
    static let glowTint = dynamic(
        light: #colorLiteral(red: 0.078, green: 0.078, blue: 0.102, alpha: 0.10),
        dark:  #colorLiteral(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.12)
    )

    /// Wind-down Live Activity indigo: arcs, glyphs, caption text. Gets a light variant even though its canvas is pinned dark, because it is also used in-app. Sits on `surfaceRaised`.
    static let windDownTint = dynamic(
        light: #colorLiteral(red: 0.329, green: 0.357, blue: 0.839, alpha: 1.00),
        dark:  #colorLiteral(red: 0.506, green: 0.549, blue: 0.973, alpha: 1.00)
    )

    /// Share-card optimal tier gradient top. Static: ImageRenderer artwork pinned with .environment(\.colorScheme, .dark), consumed outside the app as a PNG.
    static let shareScoreHighStart = Color(uiColor: #colorLiteral(red: 0.078, green: 0.180, blue: 0.149, alpha: 1.00))

    /// Share-card optimal tier gradient bottom. Static artwork.
    static let shareScoreHighEnd = Color(uiColor: #colorLiteral(red: 0.039, green: 0.102, blue: 0.078, alpha: 1.00))

    /// Share-card good tier gradient top. Static artwork.
    static let shareScoreGoodStart = Color(uiColor: #colorLiteral(red: 0.059, green: 0.161, blue: 0.220, alpha: 1.00))

    /// Share-card good tier gradient bottom. Static artwork.
    static let shareScoreGoodEnd = Color(uiColor: #colorLiteral(red: 0.031, green: 0.090, blue: 0.141, alpha: 1.00))

    /// Share-card fair tier gradient top. Static artwork.
    static let shareScoreFairStart = Color(uiColor: #colorLiteral(red: 0.220, green: 0.141, blue: 0.059, alpha: 1.00))

    /// Share-card fair tier gradient bottom. Static artwork.
    static let shareScoreFairEnd = Color(uiColor: #colorLiteral(red: 0.141, green: 0.082, blue: 0.031, alpha: 1.00))

    /// Share-card poor tier gradient top. Static artwork.
    static let shareScorePoorStart = Color(uiColor: #colorLiteral(red: 0.200, green: 0.078, blue: 0.086, alpha: 1.00))

    /// Share-card poor tier gradient bottom. Static artwork.
    static let shareScorePoorEnd = Color(uiColor: #colorLiteral(red: 0.122, green: 0.039, blue: 0.051, alpha: 1.00))

    /// Share-card secondary panel. Static artwork.
    static let shareSecondaryBackground = Color(uiColor: #colorLiteral(red: 0.071, green: 0.090, blue: 0.110, alpha: 1.00))
}
