import SwiftUI

/// Compact card for the Home tab showing the current stress level.
/// Matches the accent-bar card style used by StrainCard, SleepCard, VitalityCard.
struct StressCard: View {
    let stressScore: Double
    let stressLevel: String
    let levelColor: Color
    let trend: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(levelColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 14) {
                    // Stress icon. waveform in capsule, distinct from Brain Health
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 19.2).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize + 14, height: DS.iconSize)
                        .background(levelColor, in: Capsule())

                    // Center text
                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(Copy.Home.Cards.stressLevel)
                            .font(DS.Typography.calloutSemibold)
                            .foregroundStyle(AppColour.textSecondary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            Text(String(format: "%.1f", stressScore))
                                .font(.system(size: 26.4).weight(.bold).monospacedDigit())
                                .postHogMask()

                            Text(stressLevel)
                                .font(.system(size: 14.4).weight(.bold))
                                .foregroundStyle(levelColor)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(levelColor.opacity(DS.badgeBg), in: Capsule())

                            trendIndicator
                        }
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
            .cardStyle(tint: levelColor)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stress level \(String(format: "%.1f", stressScore)), \(stressLevel), trending \(trend)")
        .accessibilityHint(Copy.Home.viewStressMonitorDetailsHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.stressCard")
    }

    // MARK: - Trend Indicator

    private var trendIndicator: some View {
        let icon: String
        let color: Color

        switch trend.lowercased() {
        case "up", "rising":
            icon = "arrow.up.right"
            color = AppColour.danger
        case "down", "falling":
            icon = "arrow.down.right"
            color = AppColour.success
        default:
            icon = "arrow.right"
            color = AppColour.textSecondary
        }

        return Image(systemName: icon)
            .font(DS.Typography.captionSemibold)
            .foregroundStyle(color)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        StressCard(
            stressScore: 0.4,
            stressLevel: "Low",
            levelColor: .green,
            trend: "stable",
            onTap: {}
        )

        StressCard(
            stressScore: 1.2,
            stressLevel: "Mild",
            levelColor: .yellow,
            trend: "up",
            onTap: {}
        )

        StressCard(
            stressScore: 2.1,
            stressLevel: "Moderate",
            levelColor: .orange,
            trend: "down",
            onTap: {}
        )

        StressCard(
            stressScore: 2.8,
            stressLevel: "High",
            levelColor: .red,
            trend: "up",
            onTap: {}
        )
    }
    .padding(.horizontal, DS.screenPadding)
    .background(Color(.systemGroupedBackground))
}
