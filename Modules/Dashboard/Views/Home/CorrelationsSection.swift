import SwiftUI

/// Compact section on the Home tab showing top correlations between health metrics
struct CorrelationsSection: View {
    let correlations: [HealthCorrelation]
    let onTapSeeAll: () -> Void
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        Group {
            if !correlations.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    // Header
                    HStack {
                        Text(Copy.Home.fromYourData)
                            .font(DS.Typography.title3)

                        Spacer()

                        Button(action: onTapSeeAll) {
                            HStack(spacing: DS.space1) {
                                Text(Copy.Home.Cards.seeAll)
                                    .font(DS.Typography.bodyMedium)
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.footnoteMedium)
                            }
                            .foregroundStyle(.tint)
                        }
                        .accessibilityLabel(Copy.Home.seeAllCorrelationsLabel)
                        .accessibilityHint(Copy.Home.opensTheFullHealthIntelligenceViewHint)
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
            VStack(alignment: .leading, spacing: DS.space2) {
                // Cause → Effect row
                HStack(spacing: DS.space2) {
                    // Cause metric icon
                    Image(systemName: correlation.metricA.systemImageName)
                        .font(DS.Typography.title3)
                        .foregroundStyle(correlation.metricA.category.color)
                        .frame(width: 24)

                    Text(correlation.causeLabel)
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(AppColour.textPrimary)

                    Image(systemName: "arrow.right")
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(AppColour.textTertiary)

                    // Effect metric icon
                    Image(systemName: correlation.metricB.systemImageName)
                        .font(DS.Typography.title3)
                        .foregroundStyle(correlation.metricB.category.color)
                        .frame(width: 24)

                    Text(correlation.effectLabel)
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(AppColour.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Spacer()
                }

                // Bottom row: strength badge + day offset + chevron
                HStack(spacing: DS.space2) {
                    StrengthBadge(label: correlation.strengthLabel)

                    Text(correlation.dayOffset == 0 ? "Same day" : "Next day effect")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)

                    Spacer()

                    Text(correlation.effectSummary)
                        .font(DS.Typography.callout)
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: AppColour.categoryStress)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.leadsToLabel(correlation.causeLabel, correlation.effectLabel))
        .accessibilityValue(Copy.Home.correlationValue(correlation.strengthLabel))
        .accessibilityHint(Copy.Home.viewMetricDetailsHint)
        .accessibilityAddTraits(.isButton)
    }
}

/// Small badge showing correlation strength
struct StrengthBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(DS.Typography.captionSemibold)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(badgeColor.opacity(DS.badgeBg), in: Capsule())
    }

    private var badgeColor: Color {
        switch label {
        case "Strong": return AppColour.success
        case "Moderate": return AppColour.warning
        default: return AppColour.textSecondary
        }
    }
}
