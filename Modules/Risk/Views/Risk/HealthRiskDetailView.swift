import SwiftUI

/// Deep-dive view for a single health pattern showing all contributing factors and actionable focus areas
struct HealthRiskDetailView: View {
    let risk: HealthRisk
    let onTapMetric: (HealthMetric) -> Void
    /// Pass 11 AK (F45): freshness timestamp from the parent dashboard refresh.
    var lastUpdated: Date? = nil
    /// Pass 11 AK (F31): pull-to-refresh hook wired by the route destination.
    var onRefresh: (() async -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                if let lastUpdated, let caption = Copy.Common.relativeUpdated(lastUpdated) {
                    Text(caption)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(.tertiary)
                }
                // Hero: risk level gauge
                riskGaugeSection

                // Description
                Text(risk.riskType.description)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)

                // Focus Areas (what to do)
                if !risk.focusAreas.isEmpty {
                    focusAreasSection
                }

                // Contributing Factors
                contributingFactorsSection

                // Disclaimer
                disclaimerSection
            }
            .padding(.bottom)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .refreshable {
            await onRefresh?()
        }
        .navigationTitle(risk.riskType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.riskDetail, metadata: [
                "risk": risk.riskType.rawValue,
                "grade": risk.riskGrade.rawValue,
                "focus_area_count": risk.focusAreas.count
            ])
            AppAnalytics.shared.trackCoreAction(.viewedRiskDetail, screen: .riskDetail)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "viewed_risk_detail", screen: .riskDetail)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.riskDetail, metadata: ["risk": risk.riskType.rawValue]) }
    }

    // MARK: - Risk Gauge

    private var riskGaugeSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(AppColour.surfaceElevated, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(0))
                    .frame(width: 160, height: 160)

                // Risk level arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * Double(risk.level) / 100.0)
                    .stroke(
                        risk.riskGrade.color,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(0))
                    .frame(width: 160, height: 160)

                // Center content
                VStack(spacing: 4) {
                    Image(systemName: risk.riskType.systemImageName)
                        .font(DS.Typography.title)
                        .foregroundStyle(risk.riskType.color)

                    Text("\(risk.level)")
                        .font(DS.Typography.displayM)
                        .foregroundStyle(risk.riskGrade.color)

                    RiskGradeBadge(grade: risk.riskGrade)
                }
            }
            .padding(.top)

            // Measured metrics count
            Text(Copy.Analysis.RiskDetail.metricsMeasured(measured: risk.measuredFactors.count, total: risk.factors.count))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(risk.riskType.displayName), risk level \(risk.level) out of 100, \(risk.riskGrade.displayName)")
    }

    // MARK: - Focus Areas

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack {
                Image(systemName: "target")
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textPrimary)
                Text(Copy.Analysis.RiskDetail.whatToFocusOn)
                    .font(DS.Typography.headline)
            }
            .padding(.horizontal)

            ForEach(risk.focusAreas) { area in
                FocusAreaCard(area: area) {
                    AppAnalytics.shared.trackRiskTapped(
                        riskType: risk.riskType.rawValue,
                        grade: risk.riskGrade.rawValue,
                        screen: .riskDetail
                    )
                    onTapMetric(area.metric)
                }
            }
        }
    }

    // MARK: - Contributing Factors

    private var contributingFactorsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.Analysis.RiskDetail.contributingFactors)
                .font(DS.Typography.headline)
                .padding(.horizontal)

            ForEach(risk.factors) { factor in
                if factor.status != .unmeasured {
                    Button {
                        AppAnalytics.shared.trackRiskTapped(
                            riskType: risk.riskType.rawValue,
                            grade: risk.riskGrade.rawValue,
                            screen: .riskDetail
                        )
                        onTapMetric(factor.metric)
                    } label: {
                        factorRow(factor)
                    }
                    .buttonStyle(.dsPress)
                } else {
                    factorRow(factor)
                }
            }
        }
    }

    private func factorRow(_ factor: RiskFactor) -> some View {
        HStack(spacing: DS.itemSpacing) {
            // Status icon
            Image(systemName: factor.status.icon)
                .font(DS.Typography.body)
                .foregroundStyle(factor.status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DS.space1) {
                HStack {
                    Text(factor.metric.displayName)
                        .font(DS.Typography.subheadlineMedium)
                        .foregroundStyle(factor.status == .unmeasured ? AppColour.textSecondary : AppColour.textPrimary)

                    Spacer()

                    if factor.status != .unmeasured {
                        Text(formatValue(factor.currentValue, metric: factor.metric))
                            .font(DS.Typography.subheadlineSemibold)
                            .foregroundStyle(AppColour.textPrimary)
                    }
                }

                Text(factor.explanation)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(2)

                HStack {
                    Text(Copy.Analysis.RiskDetail.optimalRange(factor.optimalRange))
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)

                    Spacer()

                    if factor.status != .unmeasured {
                        // Risk contribution bar
                        RiskContributionBar(contribution: factor.contribution)
                    }
                }
            }

            if factor.status != .unmeasured {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
            }
        }
        .padding(DS.cardPadding)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal)
        .opacity(factor.status == .unmeasured ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.metric.displayName), \(factor.status.displayName)")
        .accessibilityValue(factor.status != .unmeasured ? formatValue(factor.currentValue, metric: factor.metric) : "not measured")
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: DS.space2) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.warning)

            Text(Copy.Analysis.RiskDetail.disclaimer)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textPrimary)
        }
        .padding(DS.cardPadding)
        .background(AppColour.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(AppColour.warning.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double, metric: HealthMetric) -> String {
        "\(metric.formatValue(value)) \(metric.unit)"
    }
}

/// Card showing a focus area with title, description, impact, and target
struct FocusAreaCard: View {
    let area: FocusArea
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack {
                    // Impact badge
                    HStack(spacing: DS.space1) {
                        Image(systemName: area.impact.icon)
                            .font(DS.Typography.caption2)
                        Text(area.impact.displayName)
                            .font(DS.Typography.caption2Semibold)
                    }
                    .foregroundStyle(area.impact.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(area.impact.color.opacity(0.12), in: Capsule())

                    Spacer()

                    Image(systemName: area.metric.systemImageName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(area.metric.category.color)
                }

                Text(area.title)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(area.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack {
                    Image(systemName: "scope")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.success)
                    Text(area.targetDescription)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(AppColour.success)
                }
            }
            .padding(DS.cardPadding)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .padding(.horizontal)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(area.impact.displayName): \(area.title)")
        .accessibilityHint("View \(area.metric.displayName) details")
    }
}

/// Tiny bar showing how much a factor contributes to risk
struct RiskContributionBar: View {
    let contribution: Int

    var body: some View {
        HStack(spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColour.surfaceElevated)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geometry.size.width * min(1.0, Double(contribution) / 100.0), height: 4)
                }
            }
            .frame(width: 40, height: 4)
        }
    }

    private var barColor: Color {
        switch contribution {
        case 0..<15: return AppColour.success
        case 15..<35: return AppColour.scoreGood
        case 35..<60: return AppColour.warning
        default: return AppColour.danger
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        let risks = SampleDataProvider.generateSampleRisks()
        if let first = risks.first {
            HealthRiskDetailView(risk: first, onTapMetric: { _ in })
        }
    }
}
#endif
