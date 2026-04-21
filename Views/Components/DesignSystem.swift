import SwiftUI

/// Centralized design tokens for visual consistency across Laso.
enum DS {
    /// Card corner radius. unified across all cards
    static let cardRadius: CGFloat = 16
    /// Icon background corner radius
    static let iconRadius: CGFloat = 10
    /// Accent bar corner radius
    static let accentRadius: CGFloat = 2

    /// Standard card interior padding
    static let cardPadding: CGFloat = 14
    /// Accent bar card: leading content padding
    static let accentLeading: CGFloat = 10
    /// Accent bar card: trailing content padding
    static let accentTrailing: CGFloat = 14
    /// Accent bar card: vertical content padding
    static let accentVertical: CGFloat = 12

    /// Standard metric icon size (width & height)
    static let iconSize: CGFloat = 36

    /// Between sections on scrollable pages
    static let sectionSpacing: CGFloat = 20
    /// Between cards/items within a section
    static let itemSpacing: CGFloat = 12

    /// Card tinted background opacity
    static let tintBg: Double = 0.04
    /// Icon circle / badge background opacity
    static let badgeBg: Double = 0.12
    /// Card border stroke opacity
    static let strokeAlpha: Double = 0.1

    /// Standard vertical divider height in stat rows
    static let dividerHeight: CGFloat = 32

    /// Standard badge padding
    static let badgeH: CGFloat = 6
    static let badgeV: CGFloat = 3

    // MARK: - Spacing Scale (8pt grid)

    /// Hairline spacing (4pt) — between tightly related elements
    static let space1: CGFloat = 4
    /// Micro spacing (8pt) — compact stacks, small gaps
    static let space2: CGFloat = 8
    /// Small spacing (12pt) — between items inside a section
    static let space3: CGFloat = 12
    /// Medium spacing (16pt) — default screen edge padding
    static let space4: CGFloat = 16
    /// Large spacing (20pt) — between sections
    static let space5: CGFloat = 20
    /// XL spacing (24pt) — hero card padding, generous separators
    static let space6: CGFloat = 24
    /// Section spacing (32pt) — major section breaks
    static let space7: CGFloat = 32
    /// Screen-level vertical rhythm (48pt) — top/bottom screen padding
    static let space8: CGFloat = 48

    /// Standard screen horizontal padding
    static let screenPadding: CGFloat = 16

    // MARK: - Typography

    enum Typography {
        // Semantic fonts (preferred default)
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

        // Numeric readouts (rounded + monospacedDigit so digits don't shift)
        static let displayXL: Font = .system(size: 56, weight: .bold, design: .rounded).monospacedDigit()
        static let displayL: Font = .system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
        static let displayM: Font = .system(size: 36, weight: .bold, design: .rounded).monospacedDigit()
        static let displayS: Font = .system(size: 28, weight: .bold, design: .rounded).monospacedDigit()

        // Icon fonts (large SF symbols in empty states and hero slots)
        static let heroIcon: Font = .system(size: 56, weight: .medium)
        static let largeIcon: Font = .system(size: 44, weight: .medium)
        static let mediumIcon: Font = .system(size: 36, weight: .medium)
    }

    /// Score-based recovery color for consistent state visualization.
    static func scoreColor(_ score: Int) -> Color {
        switch recoveryTier(for: score) {
        case .optimal:
            return .green
        case .good:
            return .yellow
        case .fair:
            return .orange
        case .poor:
            return .red
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

    /// Human-readable recovery label from score bands.
    static func scoreLabel(_ score: Int) -> String {
        switch recoveryTier(for: score) {
        case .optimal:
            return "Optimal"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        }
    }

    private enum RecoveryTier {
        case optimal
        case good
        case fair
        case poor
    }

    private static func recoveryTier(for score: Int) -> RecoveryTier {
        if score > 75 {
            return .optimal
        }

        if score >= 50 {
            return .good
        }

        if score >= 30 {
            return .fair
        }

        return .poor
    }
}

// MARK: - Safe Text (no ellipsis ghost)

extension View {
    /// Text that shrinks to fit its container before showing an ellipsis.
    /// Default lineLimit = 1, scale floor = 0.75. Use on labels/numbers where
    /// truncation would destroy meaning.
    func dsFit(_ lineLimit: Int = 1, minScale: CGFloat = 0.75) -> some View {
        self
            .lineLimit(lineLimit)
            .minimumScaleFactor(minScale)
            .truncationMode(.tail)
    }
}

// MARK: - Unified Card Background

extension View {
    /// Tinted card. colored background, matching stroke, and shadow
    func cardStyle(tint: Color) -> some View {
        self
            .background(tint.opacity(DS.tintBg), in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(tint.opacity(DS.strokeAlpha), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    /// Neutral card. system background, subtle stroke, and shadow
    func cardStyle() -> some View {
        self
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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

    /// Edge-to-edge Liquid Glass for system bars (tab bar, top bars).
    @ViewBuilder
    func glassChromeBar() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: Rectangle())
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    /// Tinted Liquid Glass for colored floating chrome (billing, warnings, brand banners).
    @ViewBuilder
    func glassChrome<S: Shape>(tinted color: Color, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(color.opacity(0.35)), in: shape)
        } else {
            self.background(color.opacity(0.08), in: shape)
        }
    }
}
