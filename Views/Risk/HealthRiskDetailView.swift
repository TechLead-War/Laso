import SwiftUI

/// Deep-dive view for a single health risk showing all contributing factors and actionable focus areas
struct HealthRiskDetailView: View {
    let risk: HealthRisk
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero: risk level gauge
                riskGaugeSection

                // Description
                Text(risk.riskType.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(risk.riskType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.riskDetail, metadata: ["risk": risk.riskType.rawValue]) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.riskDetail, metadata: ["risk": risk.riskType.rawValue]) }
    }

    // MARK: - Risk Gauge

    private var riskGaugeSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 14, lineCap: .round))
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
                        .font(.title)
                        .foregroundStyle(risk.riskType.color)

                    Text("\(risk.level)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(risk.riskGrade.color)

                    RiskGradeBadge(grade: risk.riskGrade)
                }
            }
            .padding(.top)

            // Measured metrics count
            Text("\(risk.measuredFactors.count) of \(risk.factors.count) metrics measured")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(risk.riskType.displayName), risk level \(risk.level) out of 100, \(risk.riskGrade.displayName)")
    }

    // MARK: - Focus Areas

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("What to Focus On")
                    .font(.headline)
            }
            .padding(.horizontal)

            ForEach(risk.focusAreas) { area in
                FocusAreaCard(area: area) {
                    AppAnalytics.shared.trackBlockTap(title: area.title, type: .focusAreaCard, screen: .riskDetail)
                    onTapMetric(area.metric)
                }
            }
        }
    }

    // MARK: - Contributing Factors

    private var contributingFactorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contributing Factors")
                .font(.headline)
                .padding(.horizontal)

            ForEach(risk.factors) { factor in
                Button {
                    if factor.status != .unmeasured {
                        AppAnalytics.shared.trackBlockTap(title: factor.metric.displayName, type: .riskFactor, screen: .riskDetail)
                        onTapMetric(factor.metric)
                    }
                } label: {
                    factorRow(factor)
                }
                .buttonStyle(.plain)
                .disabled(factor.status == .unmeasured)
            }
        }
    }

    private func factorRow(_ factor: RiskFactor) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: factor.status.icon)
                .font(.body)
                .foregroundStyle(factor.status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(factor.metric.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(factor.status == .unmeasured ? .secondary : .primary)

                    Spacer()

                    if factor.status != .unmeasured {
                        Text(formatValue(factor.currentValue, metric: factor.metric))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }

                Text(factor.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("Optimal: \(factor.optimalRange)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if factor.status != .unmeasured {
                        // Risk contribution bar
                        RiskContributionBar(contribution: factor.contribution)
                    }
                }
            }

            if factor.status != .unmeasured {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .opacity(factor.status == .unmeasured ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.metric.displayName), \(factor.status.displayName)")
        .accessibilityValue(factor.status != .unmeasured ? formatValue(factor.currentValue, metric: factor.metric) : "not measured")
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Risk assessments are based on patterns in your health data and published clinical ranges. They are not medical diagnoses. Always consult a healthcare provider for medical decisions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double, metric: HealthMetric) -> String {
        let formatted: String
        if value >= 1000 { formatted = String(format: "%.0f", value) }
        else if value >= 100 { formatted = String(format: "%.0f", value) }
        else { formatted = String(format: "%.1f", value) }
        return "\(formatted) \(metric.unit)"
    }
}

/// Card showing a focus area with title, description, impact, and target
struct FocusAreaCard: View {
    let area: FocusArea
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Impact badge
                    HStack(spacing: 3) {
                        Image(systemName: area.impact.icon)
                            .font(.caption2)
                        Text(area.impact.displayName)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(area.impact.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(area.impact.color.opacity(0.12), in: Capsule())

                    Spacer()

                    Image(systemName: area.metric.systemImageName)
                        .font(.caption)
                        .foregroundStyle(area.metric.category.color)
                }

                Text(area.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(area.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack {
                    Image(systemName: "scope")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(area.targetDescription)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
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
                        .fill(Color(.systemGray5))
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
        case 0..<15: return .green
        case 15..<35: return .yellow
        case 35..<60: return .orange
        default: return .red
        }
    }
}

#Preview {
    NavigationStack {
        let risks = SampleDataProvider.generateSampleRisks()
        if let first = risks.first {
            HealthRiskDetailView(risk: first, onTapMetric: { _ in })
        }
    }
}
