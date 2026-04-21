import SwiftUI

/// Compact section on the Home tab showing top correlations between health metrics
struct CorrelationsSection: View {
    let correlations: [HealthCorrelation]
    let onTapSeeAll: () -> Void
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        Group {
            if !correlations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text(Copy.Home.fromYourData)
                            .font(.system(size: 20.4, weight: .semibold))

                        Spacer()

                        Button(action: onTapSeeAll) {
                            HStack(spacing: 4) {
                                Text("See all")
                                    .font(.system(size: 18).weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13.2).weight(.semibold))
                            }
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)

                    ForEach(correlations) { correlation in
                        CorrelationCard(correlation: correlation) {
                            AppAnalytics.shared.trackCorrelationTapped(
                                metricA: correlation.metricA.rawValue,
                                metricB: correlation.metricB.rawValue,
                                strength: correlation.strengthLabel,
                                screen: .home
                            )
                            onTapMetric(correlation.metricA)
                        }
                        .padding(.horizontal, DS.screenPadding)
                    }
                }
            }
        }
    }
}

/// Compact card showing a single cause→effect correlation
struct CorrelationCard: View {
    let correlation: HealthCorrelation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Cause → Effect row
                HStack(spacing: 8) {
                    // Cause metric icon
                    Image(systemName: correlation.metricA.systemImageName)
                        .font(.system(size: 20.4).weight(.semibold))
                        .foregroundStyle(correlation.metricA.category.color)
                        .frame(width: 24)

                    Text(correlation.causeLabel)
                        .font(.system(size: 18).weight(.medium))
                        .foregroundStyle(.primary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14.4).weight(.bold))
                        .foregroundStyle(.tertiary)

                    // Effect metric icon
                    Image(systemName: correlation.metricB.systemImageName)
                        .font(.system(size: 20.4).weight(.semibold))
                        .foregroundStyle(correlation.metricB.category.color)
                        .frame(width: 24)

                    Text(correlation.effectLabel)
                        .font(.system(size: 18).weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Spacer()
                }

                // Bottom row: strength badge + day offset + chevron
                HStack(spacing: 8) {
                    StrengthBadge(label: correlation.strengthLabel)

                    Text(correlation.dayOffset == 0 ? "Same day" : "Next day effect")
                        .font(.system(size: 13.2))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(correlation.effectSummary)
                        .font(.system(size: 14.4))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13.2).weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: .purple)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(correlation.causeLabel) leads to \(correlation.effectLabel)")
        .accessibilityValue("\(correlation.strengthLabel) correlation")
        .accessibilityHint("View metric details")
        .accessibilityAddTraits(.isButton)
    }
}

/// Small badge showing correlation strength
struct StrengthBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 13.2).weight(.bold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(badgeColor.opacity(DS.badgeBg), in: Capsule())
    }

    private var badgeColor: Color {
        switch label {
        case "Strong": return .green
        case "Moderate": return .yellow
        default: return .gray
        }
    }
}
