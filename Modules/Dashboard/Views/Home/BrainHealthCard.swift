import SwiftUI

/// Compact card for the Home tab showing the user's brain health score.
/// Matches the accent-bar card style used by StressCard, VitalityCard, etc.
struct BrainHealthCard: View {
    let score: Int           // 0-100
    let stateLabel: String   // "Sharp", "Focused", "Baseline", "Foggy"
    let stateColor: Color    // from BrainHealthState.color
    let headline: String     // "Strong REM + high HRV this morning"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 14) {
                    // Icon in rounded rectangle. distinct from Vitality (ring) and Strain (square)
                    Image(systemName: "brain")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize + 12, height: DS.iconSize + 12)
                        .background(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        )

                    // Center text
                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(Copy.BrainHealth.title)
                            .font(DS.Typography.calloutSemibold)
                            .foregroundStyle(AppColour.textSecondary)
                            .textCase(.uppercase)

                        HStack(spacing: DS.space2) {
                            Text(Copy.Home.xText(score))
                                .font(DS.Typography.displayS)
                                .postHogMask()

                            // State badge
                            Text(stateLabel)
                                .font(DS.Typography.calloutSemibold)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(accentColor.opacity(DS.badgeBg), in: Capsule())
                        }

                        // Headline text
                        Text(headline)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textTertiary)
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: accentColor)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.brainHealthScoreOutOfLabel(score, stateLabel))
        .accessibilityHint(Copy.Home.viewBrainHealthDetailsHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.brainHealthCard")
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        if score >= 80 { return AppColour.scoreOptimal }
        if score >= 65 { return AppColour.categoryBrain }
        if score >= 45 { return AppColour.textTertiary }
        return AppColour.warning
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        BrainHealthCard(
            score: 85,
            stateLabel: "Sharp",
            stateColor: .green,
            headline: "Strong REM + high HRV",
            onTap: {}
        )

        BrainHealthCard(
            score: 72,
            stateLabel: "Focused",
            stateColor: .blue,
            headline: "Good sleep architecture",
            onTap: {}
        )

        BrainHealthCard(
            score: 55,
            stateLabel: "Baseline",
            stateColor: .gray,
            headline: "Average recovery signals",
            onTap: {}
        )

        BrainHealthCard(
            score: 38,
            stateLabel: "Foggy",
            stateColor: .orange,
            headline: "Low deep sleep + HRV dip",
            onTap: {}
        )
    }
    .padding(.horizontal, DS.screenPadding)
    .background(Color(.systemGroupedBackground))
}
