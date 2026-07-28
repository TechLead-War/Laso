import SwiftUI

/// Centralized design tokens for visual consistency across Laso.
///
/// - Spacing: clean 4pt grid (4, 8, 12, 16, 20, 24, 32, 48).
/// - Typography: SF Pro — semantic Dynamic Type for text, monospacedDigit rounded for numerics.
/// - Color: use `AppColour.*` tokens; every token resolves for light and dark.
/// - Elevation: opaque surface steps carry depth in dark, `AppColour.shadowAmbient` in light.
/// - Motion: spring for user-triggered interactions, duration-based for data reveals.
enum DS {

    // MARK: - Radius Scale

    enum Radius {
        static let xs: CGFloat = 4     // chips, small badges
        static let sm: CGFloat = 8     // inputs, small buttons
        static let md: CGFloat = 12    // cards (metric tiles, nav rows)
        static let lg: CGFloat = 16    // large cards, section containers
        static let xl: CGFloat = 20    // sheets, modals (matches iPhone hardware corner)
        static let xxl: CGFloat = 24   // hero cards, feature panels
        static let full: CGFloat = 9999 // pills, circular avatars
    }

    /// Card corner radius — unified across content cards.
    static let cardRadius: CGFloat = Radius.xxl    // 24
    /// Icon background corner radius.
    static let iconRadius: CGFloat = Radius.md     // 12

    // MARK: - Spacing Scale (4pt grid)

    /// 4pt — hairline (icon-label gap, divider inset, tight chip padding).
    static let space1: CGFloat = 4
    /// 8pt — small (list row internal padding, small card inset).
    static let space2: CGFloat = 8
    /// 12pt — default-small (card internal vertical rhythm).
    static let space3: CGFloat = 12
    /// 16pt — default content padding.
    static let space4: CGFloat = 16
    /// 20pt — medium (section header top gap).
    static let space5: CGFloat = 20
    /// 24pt — large (card-to-card vertical gap, sheet top inset).
    static let space6: CGFloat = 24
    /// 32pt — xl (section separation, hero metric top padding).
    static let space7: CGFloat = 32
    /// 48pt — xxl (full-screen inset for modal/sheet content).
    static let space8: CGFloat = 48

    /// Standard screen horizontal padding.
    static let screenPadding: CGFloat = space3    // 12

    /// Standard card interior padding.
    static let cardPadding: CGFloat = space4      // 16 (was 16.8)

    /// Between sections on scrollable pages.
    static let sectionSpacing: CGFloat = space6   // 24
    /// Between cards/items within a section.
    static let itemSpacing: CGFloat = space3      // 12 (was 14.4)

    /// Standard metric icon size (width & height). 44pt = Apple HIG minimum tap target.
    static let iconSize: CGFloat = 44             // (was 43.2)

    /// Card tinted background opacity.
    static let tintBg: Double = 0.04
    /// Icon circle / badge background opacity.
    static let badgeBg: Double = 0.12
    /// Card border stroke opacity (tint-relative).
    static let strokeAlpha: Double = 0.18

    /// Standard vertical divider height in stat rows.
    static let dividerHeight: CGFloat = 40        // (was 38.4)

    /// Standard badge padding.
    static let badgeH: CGFloat = space2           // 8 (was 7.2)
    static let badgeV: CGFloat = space1           // 4 (was 3.6)

    // MARK: - Typography

    enum Typography {
        // Semantic fonts: the system face, so Dynamic Type and every accessibility
        // weight setting apply without a custom face fighting them.
        static let largeTitle: Font = .largeTitle.weight(.bold)
        static let title: Font = .title.weight(.bold)
        static let title2: Font = .title2.weight(.semibold)
        static let title3: Font = .title3.weight(.semibold)
        static let headline: Font = .headline
        static let subheadline: Font = .subheadline
        static let subheadlineMedium: Font = .subheadline.weight(.medium)
        static let subheadlineSemibold: Font = .subheadline.weight(.semibold)
        static let body: Font = .body
        static let bodyMedium: Font = .body.weight(.medium)
        static let bodySemibold: Font = .body.weight(.semibold)
        static let callout: Font = .callout
        static let calloutSemibold: Font = .callout.weight(.semibold)
        static let footnote: Font = .footnote
        static let footnoteMedium: Font = .footnote.weight(.medium)
        static let caption: Font = .caption
        static let captionMedium: Font = .caption.weight(.medium)
        static let captionSemibold: Font = .caption.weight(.semibold)
        static let caption2: Font = .caption2
        static let caption2Medium: Font = .caption2.weight(.medium)
        static let caption2Semibold: Font = .caption2.weight(.semibold)

        // Numeric readouts. Rounded plus monospacedDigit so digits do not jitter as
        // a score ticks over.
        static let displayXL: Font = .system(size: 56, weight: .bold, design: .rounded).monospacedDigit()
        static let displayL: Font = .system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
        static let displayM: Font = .system(size: 36, weight: .bold, design: .rounded).monospacedDigit()
        static let displayS: Font = .system(size: 28, weight: .bold, design: .rounded).monospacedDigit()

        // Large SF Symbols in empty states and hero slots.
        static let heroIcon: Font = .system(size: 56, weight: .medium)
        static let largeIcon: Font = .system(size: 44, weight: .medium)
        static let mediumIcon: Font = .system(size: 36, weight: .medium)
    }

    // MARK: - Elevation
    //
    // In dark, drop shadows against near-black are near-invisible, so elevation is
    // carried by surface steps (AppColour.surfaceBase / surfaceRaised /
    // surfaceElevated / surfaceOverlay) + borders (AppColour.borderLow /
    // borderMedium / borderHigh). In light the ramp cannot separate a card from the
    // page on its own, so the shadow does the work. AppColour.shadowAmbient and
    // shadowFloating already flip between the two; never use a raw .black alpha.

    enum Elevation {
        struct Shadow {
            let radius: CGFloat
            let y: CGFloat
            let opacity: Double
        }
        static let shadowLow = Shadow(radius: 2, y: 1, opacity: 0.12)
    }

    // MARK: - Motion

    enum Motion {
        // Interaction — user taps, drags.
        static let pressIn:  Animation = .easeIn(duration: 0.08)
        static let pressOut: Animation = .spring(response: 0.3, dampingFraction: 0.7)

        // Ambient — toasts, chips, subtle state changes.
        static let toast: Animation = .easeInOut(duration: 0.25)
    }

    // MARK: - Score Mapping

    /// Score-based recovery color. Uses AppColour tokens for dark-mode safe tints.
    ///
    /// IMPORTANT: This must mirror `DashboardViewModel.RecoveryState`'s 3-band model
    /// (>75 green, ≥50 yellow/amber, <50 red) so the day-type pill, ring, and any
    /// other surface tinted by score all agree on the same threshold table.
    /// Adding a tier here without also updating `RecoveryState` will reintroduce
    /// the green-pill-saying-Yellow-Day kind of bug.
    static func scoreColor(_ score: Int) -> Color {
        switch recoveryTier(for: score) {
        case .optimal: return AppColour.scoreOptimal
        case .fair:    return AppColour.scoreFair
        case .poor:    return AppColour.scorePoor
        }
    }

    /// Score-based gradient for hero card backgrounds.
    static func recoveryGradient(_ score: Int) -> LinearGradient {
        let tint = scoreColor(score)
        return LinearGradient(
            colors: [tint.opacity(0.28), tint.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Human-readable recovery label from score bands. Mirrors `scoreColor`'s tiers.
    static func scoreLabel(_ score: Int) -> String {
        switch recoveryTier(for: score) {
        case .optimal: return "Optimal"
        case .fair:    return "Moderate"
        case .poor:    return "Low"
        }
    }

    enum RecoveryTier {
        case optimal, fair, poor
    }

    /// The ONLY readiness threshold table in the app. `RecoveryState`, the ring
    /// colour, the summary sentence and the explainer sheet all read it, so a
    /// score can never be amber in one place and "decent recovery" in another.
    /// Anything that grades a readiness score and does not call this is a bug.
    static func recoveryTier(for score: Int) -> RecoveryTier {
        // Green from 67 up (WHOOP-style "good recovery" zone): a 73 Ready is a good
        // day and should read green, not the amber warning it showed before.
        if score >= optimalFloor { return .optimal }
        if score >= fairFloor { return .fair }
        return .poor
    }

    /// Exposed so the explainer sheet can print the same numbers it grades by,
    /// rather than a second table that drifts.
    static let optimalFloor = 67
    static let fairFloor = 45
}

// MARK: - Unified Card Background

extension View {
    /// Tinted card — colored background, matching stroke, and subtle shadow.
    ///
    /// The tint wash rides on an opaque `surfaceRaised` base. Without the base the
    /// card is a 4% tint over the page, which is white-on-white in light mode.
    func cardStyle(tint: Color) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .fill(AppColour.surfaceRaised)
                    .shadow(color: AppColour.shadowAmbient,
                            radius: DS.Elevation.shadowLow.radius, y: DS.Elevation.shadowLow.y)
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .fill(tint.opacity(DS.tintBg))
            }
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(tint.opacity(DS.strokeAlpha), lineWidth: 1.0))
    }

    /// Neutral card — system background, subtle stroke, and shadow.
    ///
    /// The shadow hangs on the background SHAPE, not on the card as a whole. As a
    /// whole-view modifier it forced every card to rasterize offscreen and blur
    /// its entire contents each frame: the Biology month calendar, 31 day dials
    /// inside one card, measured 883 ms to rasterize that way. The silhouette is
    /// identical either way because the background is opaque.
    func cardStyle() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .fill(AppColour.surfaceRaised)
                    .shadow(color: AppColour.shadowAmbient,
                            radius: DS.Elevation.shadowLow.radius, y: DS.Elevation.shadowLow.y)
            }
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1.0))
    }
}

// MARK: - Liquid Glass (floating chrome)

extension View {
    /// Liquid Glass background for shaped floating chrome (banners, overlay controls).
    /// Falls back to `.ultraThinMaterial` on iOS < 26 to preserve the current look.
    /// Per Apple HIG, use only on floating surfaces, never on content cards.
    @ViewBuilder
    func glassChrome<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Tinted Liquid Glass for colored floating chrome (billing, warnings, brand banners).
    @ViewBuilder
    func glassChrome<S: Shape>(tinted color: Color, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(color.opacity(0.35)), in: shape)
        } else {
            // Opaque base under the wash: an 8% tint alone has no visible container
            // on a light page.
            self.background {
                shape.fill(AppColour.surfaceElevated)
                shape.fill(color.opacity(0.12))
            }
        }
    }
}
