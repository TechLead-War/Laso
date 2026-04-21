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
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize + 12, height: DS.iconSize + 12)
                        .background(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    // Center text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.BrainHealth.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            Text("\(score)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .postHogMask()

                            // State badge
                            Text(stateLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(accentColor.opacity(DS.badgeBg), in: Capsule())
                        }

                        // Headline text
                        Text(headline)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Brain Health score \(score) out of 100, \(stateLabel)")
        .accessibilityHint("View brain health details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.brainHealthCard")
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        if score >= 80 { return .green }
        if score >= 65 { return .blue }
        if score >= 45 { return .gray }
        return .orange
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
    .padding(.horizontal)
    .background(Color(.systemGroupedBackground))
}
