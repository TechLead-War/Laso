import SwiftUI

/// "Your Focus Areas" section on the Home tab. shows top health risks with actionable recommendations
struct FocusAreasSection: View {
    let risks: [HealthRisk]
    let onTapRisk: (HealthRisk) -> Void

    var body: some View {
        Group {
            if !risks.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    HStack {
                        Image(systemName: "target")
                            .font(DS.Typography.title3)
                            .foregroundStyle(AppColour.textPrimary)

                        Text(Copy.Home.focusAreasTitle)
                            .font(DS.Typography.title3)

                        Spacer()

                        Text("\(elevatedCount) worth noticing")
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    .padding(.horizontal, DS.screenPadding)

                    ForEach(risks.prefix(3)) { risk in
                        FocusRiskCard(risk: risk) {
                            AppAnalytics.shared.trackRiskTapped(
                                riskType: risk.riskType.rawValue,
                                grade: risk.riskGrade.rawValue,
                                screen: .home
                            )
                            onTapRisk(risk)
                        }
                        .padding(.horizontal, DS.screenPadding)
                    }
                }
            }
        }
    }

    private var elevatedCount: Int {
        risks.filter { $0.riskGrade != .low }.count
    }
}

/// Compact card showing a single risk profile with grade, top factor, and primary focus action
struct FocusRiskCard: View {
    let risk: HealthRisk
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Risk level indicator bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(risk.riskGrade.color)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 12) {
                    // Risk type icon
                    Image(systemName: risk.riskType.systemImageName)
                        .font(.system(size: 20.4).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(risk.riskType.color, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: DS.space1) {
                        HStack {
                            Text(risk.riskType.displayName)
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(AppColour.textPrimary)

                            Spacer()

                            // Risk grade badge
                            RiskGradeBadge(grade: risk.riskGrade)
                        }

                        // Primary focus action
                        if let topFocus = risk.focusAreas.first {
                            HStack(spacing: DS.space1) {
                                Image(systemName: topFocus.impact.icon)
                                    .font(DS.Typography.footnote)
                                    .foregroundStyle(topFocus.impact.color)

                                Text(topFocus.title)
                                    .font(DS.Typography.callout)
                                    .foregroundStyle(AppColour.textSecondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                            }
                        }

                        // Contributing factors summary
                        HStack(spacing: DS.space1) {
                            let concerning = risk.concerningFactors.prefix(3)
                            ForEach(Array(concerning)) { factor in
                                HStack(spacing: DS.space1) {
                                    Image(systemName: factor.status.icon)
                                        .font(DS.Typography.footnote)
                                        .foregroundStyle(factor.status.color)
                                    Text(factor.metric.displayName)
                                        .font(DS.Typography.footnote)
                                        .foregroundStyle(AppColour.textSecondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(DS.Typography.footnoteMedium)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                    }
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: risk.riskType.color)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(risk.riskType.displayName), \(risk.riskGrade.displayName) risk")
        .accessibilityValue(risk.focusAreas.first.map { "Focus: \($0.title)" } ?? "")
        .accessibilityHint("View risk details and recommendations")
        .accessibilityAddTraits(.isButton)
    }
}

/// Small badge showing the risk grade
struct RiskGradeBadge: View {
    let grade: RiskGrade

    var body: some View {
        HStack(spacing: DS.space1) {
            Image(systemName: grade.icon)
                .font(DS.Typography.footnote)
            Text(grade.displayName)
                .font(DS.Typography.captionSemibold)
        }
        .foregroundStyle(grade.color)
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(grade.color.opacity(DS.badgeBg), in: Capsule())
    }
}

#if DEBUG
#Preview {
    ScrollView {
        FocusAreasSection(
            risks: SampleDataProvider.generateSampleRisks(),
            onTapRisk: { _ in }
        )
        .padding(.vertical)
    }
}
#endif
