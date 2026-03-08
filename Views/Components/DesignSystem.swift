import SwiftUI

/// Centralized design tokens for visual consistency across HealthPulse.
enum DS {
    /// Card corner radius — unified across all cards
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

// MARK: - Unified Card Background

extension View {
    /// Tinted card — colored background, matching stroke, and shadow
    func cardStyle(tint: Color) -> some View {
        self
            .background(tint.opacity(DS.tintBg), in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(tint.opacity(DS.strokeAlpha), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    /// Neutral card — system background, subtle stroke, and shadow
    func cardStyle() -> some View {
        self
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
