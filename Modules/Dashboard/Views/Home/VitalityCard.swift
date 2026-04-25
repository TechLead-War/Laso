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
        .buttonStyle(.dsPress)
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
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text("Vitality Age")
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        Text("\(scorer.vitalityAge)")
                            .font(.system(size: 26.4).weight(.bold).monospacedDigit())
                            .postHogMask()

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
                    .font(.system(size: 13.2).weight(.semibold))
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
        HStack(spacing: DS.space1) {
            Image(systemName: personalizationIcon)
                .font(DS.Typography.captionSemibold)
            Text(scorer.personalizationStatus.rawValue)
                .font(DS.Typography.captionMedium)
        }
        .foregroundStyle(personalizationColor)
    }

    private var paceIndicator: some View {
        HStack(spacing: DS.space1) {
            Image(systemName: paceIcon)
                .font(DS.Typography.captionSemibold)
            Text(scorer.paceLabel)
                .font(DS.Typography.captionMedium)
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
                .font(.system(size: 24).weight(.semibold))
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
            .font(.system(size: 13.2).weight(.bold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(accentColor.opacity(DS.badgeBg), in: Capsule())
            .postHogMask()
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        let delta = scorer.delta
        if delta <= -5 { return AppColour.scoreOptimal }
        if delta < 0 { return AppColour.scoreGood }
        if delta == 0 { return AppColour.categoryVitality }
        if delta <= 3 { return AppColour.warning }
        return AppColour.danger
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
        if scorer.paceOfAging < 0.85 { return AppColour.success }
        if scorer.paceOfAging <= 1.15 { return AppColour.textSecondary }
        return AppColour.danger
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
        case .buildingProfile: return AppColour.textSecondary
        case .earlyEstimate: return AppColour.info
        case .personalized: return AppColour.success
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
