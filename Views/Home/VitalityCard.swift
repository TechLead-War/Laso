import SwiftUI

/// Compact card for the Home screen showing the user's Vitality Age summary.
/// Tappable to navigate to the full VitalityDetailView.
struct VitalityCard: View {
    let scorer: VitalityScorer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            readyContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("View vitality age details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.vitalityCard")
    }

    // MARK: - Ready State

    private var readyContent: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: DS.accentRadius)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 6)

            HStack(spacing: 12) {
                // Vitality age ring
                vitalityRing

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vitality Age")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        Text("\(scorer.vitalityAge)")
                            .font(.title2.weight(.bold).monospacedDigit())

                        deltaBadge
                    }

                    if scorer.personalizationStatus == .personalized {
                        paceIndicator
                    } else {
                        personalizationIndicator
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, DS.accentLeading)
            .padding(.trailing, DS.accentTrailing)
            .padding(.vertical, DS.accentVertical)
        }
        .cardStyle(tint: accentColor)
    }

    // MARK: - Data Maturity Indicator

    private var personalizationIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: personalizationIcon)
                .font(.caption2.weight(.bold))
            Text(scorer.personalizationStatus.rawValue)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(personalizationColor)
    }

    private var paceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: paceIcon)
                .font(.caption2.weight(.bold))
            Text(scorer.paceLabel)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(paceColor)
    }

    // MARK: - Subviews

    private static let orbSize: CGFloat = DS.iconSize + 12

    private var vitalityRing: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 5)
                .frame(width: Self.orbSize, height: Self.orbSize)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: Self.orbSize, height: Self.orbSize)
                .rotationEffect(.degrees(-90))

            Image(systemName: "figure.run")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var deltaBadge: some View {
        let delta = scorer.delta
        let text: String
        if delta == 0 {
            text = "On track"
        } else if delta < 0 {
            text = "\(abs(delta))y younger"
        } else {
            text = "\(delta)y older"
        }

        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(accentColor.opacity(DS.badgeBg), in: Capsule())
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        let delta = scorer.delta
        if delta <= -5 { return .green }
        if delta < 0 { return .green }
        if delta == 0 { return .blue }
        if delta <= 3 { return .orange }
        return .red
    }

    /// Ring fill: 1.0 when vitality age is 10+ years younger, 0.0 when 10+ years older
    private var ringProgress: Double {
        let clamped = max(-10, min(10, -scorer.delta))
        return Double(clamped + 10) / 20.0
    }

    private var paceIcon: String {
        if scorer.paceOfAging < 0.85 { return "arrow.down.right" }
        if scorer.paceOfAging <= 1.15 { return "arrow.right" }
        return "arrow.up.right"
    }

    private var paceColor: Color {
        if scorer.paceOfAging < 0.85 { return .green }
        if scorer.paceOfAging <= 1.15 { return .gray }
        return .red
    }

    private var personalizationIcon: String {
        switch scorer.personalizationStatus {
        case .buildingProfile: return "hourglass"
        case .earlyEstimate: return "clock.arrow.circlepath"
        case .personalized: return "checkmark.circle"
        }
    }

    private var personalizationColor: Color {
        switch scorer.personalizationStatus {
        case .buildingProfile: return .secondary
        case .earlyEstimate: return .blue
        case .personalized: return .green
        }
    }

    private var accessibilityDescription: String {
        let delta = scorer.delta
        let comparison: String
        if delta < 0 {
            comparison = "\(abs(delta)) years younger than your age"
        } else if delta > 0 {
            comparison = "\(delta) years older than your age"
        } else {
            comparison = "matching your age"
        }

        if scorer.personalizationStatus == .personalized {
            return "Vitality Age \(scorer.vitalityAge), \(comparison), trend \(scorer.paceLabel), \(scorer.personalizationStatus.rawValue)"
        }
        return "Vitality Age \(scorer.vitalityAge), \(comparison), \(scorer.personalizationStatus.rawValue)"
    }
}
