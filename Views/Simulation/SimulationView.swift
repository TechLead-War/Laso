import SwiftUI

/// What-If Simulation sheet: adjust metric sliders → see predicted score change.
struct SimulationView: View {
    let viewModel: SimulationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasLoadedROI = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.sectionSpacing) {
                    // 1. Score comparison hero
                    scoreComparisonHero
                        .padding(.horizontal)

                    // 2. ROI recommendation cards
                    if !viewModel.rankedRecommendations.isEmpty {
                        roiSection
                    }

                    // 3. Metric adjustment sliders
                    slidersSection
                        .padding(.horizontal)

                    // 4. Impact breakdown
                    if let result = viewModel.simulationResult, !result.perMetricImpact.isEmpty {
                        impactBreakdown(result)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("What If?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") { viewModel.reset() }
                        .disabled(viewModel.adjustments.isEmpty)
                }
            }
            .onAppear {
                if !hasLoadedROI {
                    viewModel.computeROIRankings()
                    hasLoadedROI = true
                }
            }
        }
    }

    // MARK: - 1. Score Comparison Hero

    private var scoreComparisonHero: some View {
        let current = viewModel.simulationResult?.currentScore ?? 0
        let predicted = viewModel.simulationResult?.predictedScore ?? current
        let delta = viewModel.simulationResult?.scoreDelta ?? 0

        return HStack(spacing: 16) {
            // Current score ring
            VStack(spacing: 4) {
                HealthScoreRing(score: current, label: "", size: 72, lineWidth: 8)
                Text("Current")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Arrow with delta
            VStack(spacing: 2) {
                Image(systemName: delta >= 0 ? "arrow.right" : "arrow.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(delta > 0 ? .green : delta < 0 ? .red : .secondary)
                if delta != 0 {
                    Text("\(delta > 0 ? "+" : "")\(delta)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(delta > 0 ? .green : .red)
                }
            }

            // Predicted score ring
            VStack(spacing: 4) {
                HealthScoreRing(score: predicted, label: "", size: 72, lineWidth: 8)
                Text("Predicted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Confidence indicator
            if let result = viewModel.simulationResult {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(result.confidence * 100))%")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 2. ROI Recommendations

    private var roiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Suggestions")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.itemSpacing) {
                    ForEach(viewModel.rankedRecommendations.prefix(6)) { rec in
                        roiCard(rec)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func roiCard(_ rec: ROIRanker.RankedRecommendation) -> some View {
        Button {
            viewModel.applyQuickSuggestion(rec)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: rec.metric.systemImageName)
                        .font(.caption)
                        .foregroundStyle(rec.metric.category.color)
                    Text(rec.metric.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }

                Text("+\(Int(rec.predictedScoreGain)) pts")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.green)

                HStack(spacing: 4) {
                    Text(rec.effortLevel.displayName)
                        .font(.caption2)
                        .foregroundStyle(effortColor(rec.effortLevel))
                    Spacer()
                }
            }
            .padding(DS.cardPadding)
            .frame(width: 130)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func effortColor(_ effort: EffortLevel) -> Color {
        switch effort {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    // MARK: - 3. Metric Sliders

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Adjust Metrics")
                .font(.headline)

            ForEach(viewModel.availableMetrics, id: \.self) { metric in
                metricSlider(metric)
            }
        }
    }

    private func metricSlider(_ metric: HealthMetric) -> some View {
        let current = viewModel.currentValue(for: metric)
        let range = viewModel.range(for: metric)
        let step = viewModel.step(for: metric)
        let adjustment = Binding<Double>(
            get: { viewModel.adjustments[metric] ?? 0 },
            set: { newValue in
                viewModel.adjustments[metric] = newValue
                viewModel.runSimulation()
            }
        )

        let displayValue = current + adjustment.wrappedValue

        return VStack(spacing: 4) {
            HStack {
                Image(systemName: metric.systemImageName)
                    .font(.caption)
                    .foregroundStyle(metric.category.color)
                Text(metric.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(metric.formatValue(displayValue)) \(metric.unit)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(adjustment.wrappedValue != 0 ? .primary : .secondary)
            }

            Slider(
                value: Binding(
                    get: { current + adjustment.wrappedValue },
                    set: { adjustment.wrappedValue = $0 - current }
                ),
                in: range,
                step: step
            )
            .tint(metric.category.color)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 4. Impact Breakdown

    private func impactBreakdown(_ result: SimulationEngine.SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Impact Breakdown")
                .font(.headline)

            ForEach(result.perMetricImpact.sorted(by: { $0.scoreDelta > $1.scoreDelta })) { impact in
                HStack(spacing: 10) {
                    Image(systemName: impact.metric.systemImageName)
                        .font(.caption)
                        .foregroundStyle(impact.metric.category.color)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(impact.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(impact.metric.displayName)
                            .font(.subheadline.weight(.medium))
                        Text(impact.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(impact.scoreDelta > 0 ? "+" : "")\(Int(impact.scoreDelta))")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(impact.scoreDelta > 0 ? .green : impact.scoreDelta < 0 ? .red : .secondary)
                }
                .padding(.vertical, 4)
            }

            // Explanation footer
            Text(result.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}
