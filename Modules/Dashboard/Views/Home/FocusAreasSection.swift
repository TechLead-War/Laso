import SwiftUI

/// "Your Focus Areas" section on the Home tab. shows top health risks with actionable recommendations
struct FocusAreasSection: View {
    let risks: [HealthRisk]
    let onTapRisk: (HealthRisk) -> Void

    var body: some View {
        Group {
            if !risks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .font(.system(size: 20.4, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(Copy.Home.focusAreasTitle)
                            .font(.system(size: 20.4, weight: .semibold))

                        Spacer()

                        Text("\(elevatedCount) worth noticing")
                            .font(.system(size: 14.4))
                            .foregroundStyle(.secondary)
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(risk.riskType.displayName)
                                .font(.system(size: 18).weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            // Risk grade badge
                            RiskGradeBadge(grade: risk.riskGrade)
                        }

                        // Primary focus action
                        if let topFocus = risk.focusAreas.first {
                            HStack(spacing: 4) {
                                Image(systemName: topFocus.impact.icon)
                                    .font(.system(size: 13.2))
                                    .foregroundStyle(topFocus.impact.color)

                                Text(topFocus.title)
                                    .font(.system(size: 14.4))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                            }
                        }

                        // Contributing factors summary
                        HStack(spacing: 6) {
                            let concerning = risk.concerningFactors.prefix(3)
                            ForEach(Array(concerning)) { factor in
                                HStack(spacing: 2) {
                                    Image(systemName: factor.status.icon)
                                        .font(.system(size: 13.2))
                                        .foregroundStyle(factor.status.color)
                                    Text(factor.metric.displayName)
                                        .font(.system(size: 13.2))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13.2).weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: risk.riskType.color)
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 3) {
            Image(systemName: grade.icon)
                .font(.system(size: 13.2))
            Text(grade.displayName)
                .font(.system(size: 13.2).weight(.bold))
        }
        .foregroundStyle(grade.color)
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(grade.color.opacity(DS.badgeBg), in: Capsule())
    }
}

#Preview {
    ScrollView {
        FocusAreasSection(
            risks: SampleDataProvider.generateSampleRisks(),
            onTapRisk: { _ in }
        )
        .padding(.vertical)
    }
}
