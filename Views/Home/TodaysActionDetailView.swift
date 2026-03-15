import SwiftUI

/// Hero detail page for today's single action — shows the action, why it matters, and supporting insights.
struct TodaysActionDetailView: View {
    let action: DashboardViewModel.SmartAction
    let policyDecision: PolicyDecision?
    let readinessScore: Int
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section
                heroSection

                // Content sections
                VStack(spacing: DS.sectionSpacing) {
                    // Why section
                    whySection

                    // Guidance tiles (from policy engine)
                    if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
                        if decision.targetSleepTime != nil || decision.strainBudget != nil {
                            guidanceSection(decision: decision)
                        }
                    }

                    // Supporting insights
                    if !action.supportingInsights.isEmpty {
                        insightsSection
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Today's Action")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.todaysActionDetail, metadata: [
                "source": action.source,
                "has_policy": policyDecision != nil,
                "insight_count": action.supportingInsights.count
            ])
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.todaysActionDetail)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        let tint = DS.scoreColor(readinessScore)
        return VStack(spacing: 20) {
            Image(systemName: action.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: tint.opacity(0.4), radius: 12, y: 6)

            VStack(spacing: 10) {
                Text(action.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(action.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Why Section

    private var whySection: some View {
        let rationale = effectiveRationale
        return Group {
            if !rationale.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("Why this, today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(rationale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Confidence indicator
                    if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(confidenceColor(decision.decisionConfidence))
                                .frame(width: 8, height: 8)
                            Text("\(confidenceLabel(decision.decisionConfidence)) confidence")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.cardPadding + 2)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    private var effectiveRationale: String {
        // Prefer policy engine rationale, then advisor rationale
        if let decision = policyDecision, decision.decisionConfidence >= 0.3 {
            let why = decision.primaryAction.whyItMatters
            if !why.isEmpty { return why }
        }
        return action.rationale
    }

    // MARK: - Guidance Tiles

    private func guidanceSection(decision: PolicyDecision) -> some View {
        HStack(spacing: DS.itemSpacing) {
            if let bedtime = decision.targetSleepTime {
                guidanceTile(icon: "moon.fill", label: "Target bedtime", value: bedtime, color: .indigo)
            }
            if let strain = decision.strainBudget {
                guidanceTile(icon: "flame.fill", label: "Strain budget", value: strain, color: .orange)
            }
        }
        .padding(.horizontal)
    }

    private func guidanceTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle(tint: color)
    }

    // MARK: - Supporting Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("What we're seeing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)

            ForEach(action.supportingInsights) { insight in
                Button {
                    AppAnalytics.shared.trackInsightTapped(
                        category: insight.category.rawValue,
                        severity: insight.severity.rawValue,
                        metric: insight.metric.rawValue,
                        screen: .todaysActionDetail
                    )
                    onTapMetric(insight.metric)
                } label: {
                    insightRow(insight)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: insight.metric.systemImageName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(insight.metric.category.color, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(insight.category.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(insight.category.color)

                    if abs(insight.deviationPercent) > 0.5 {
                        Text(impactText(insight))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            severityDot(insight.severity)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func severityDot(_ severity: Severity) -> some View {
        Circle()
            .fill(severityColor(severity))
            .frame(width: 8, height: 8)
    }

    // MARK: - Helpers

    private func impactText(_ insight: Insight) -> String {
        let dev = abs(insight.deviationPercent)
        let direction = insight.deviationPercent > 0 ? "above" : "below"
        return String(format: "%.0f%% %@ baseline", dev, direction)
    }

    private func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func confidenceLabel(_ value: Double) -> String {
        switch value {
        case 0.7...: return "High"
        case 0.5..<0.7: return "Moderate"
        default: return "Emerging"
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        switch value {
        case 0.7...: return .green
        case 0.5..<0.7: return .yellow
        default: return .orange
        }
    }
}
