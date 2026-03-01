import SwiftUI
import SwiftData

/// Data exploration tab — deep-dive dashboard surfacing score breakdown,
/// historical context, correlations, and category scores from the analysis engine.
struct ExploreView: View {
    let viewModel: DashboardViewModel
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if hasScoreData {
                    // 1. Score Hero with trend
                    scoreHeroSection
                        .padding(.horizontal)

                    // 2. Data depth bar
                    dataSummaryBar
                        .padding(.horizontal)

                    // 3. Score Breakdown — what's driving the score
                    scoreBreakdownSection
                        .padding(.horizontal)

                    // 4. From Your History
                    if !viewModel.historicalHighlights.isEmpty {
                        historicalSection
                    }

                    // 5. Correlations preview
                    if FeatureGate.canAccess(.advancedAnalytics), !viewModel.topCorrelations.isEmpty {
                        correlationsPreview
                    }

                    // 6. Categories drill-down
                    categoriesSection
                        .padding(.horizontal)
                } else {
                    emptyState
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.explore, metadata: [
                "weakest_category": weakestCategory?.category.displayName ?? "none",
                "insights_count": viewModel.focusedInsights.count,
                "data_days": viewModel.dataDepth.daysOfData
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstScoreSeen)
            AppAnalytics.shared.trackCoreAction(.viewedScore, screen: .explore)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.explore) }
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .explore)
            await viewModel.refresh()
        }
    }

    // MARK: - Data

    private var hasScoreData: Bool {
        !viewModel.analysisEngine.categoryScores.isEmpty
    }

    // MARK: - 1. Score Hero

    private var scoreHeroSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                HealthScoreRing(
                    score: viewModel.overallScore.score,
                    label: "",
                    size: 100,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Health Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(grade)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)

                    // Score trend from last week
                    if let delta = viewModel.scoreChangeFromLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text("\(delta > 0 ? "+" : "")\(delta) pts this week")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(delta > 0 ? .green : .red)
                    } else {
                        Text(scoreLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Weakest category suggestion
            if let weakest = weakestCategory {
                HStack(spacing: 6) {
                    Image(systemName: weakest.category.systemImageName)
                        .font(.caption)
                        .foregroundStyle(weakest.category.color)
                    Text("Focus on \(weakest.category.displayName) to improve your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(weakest.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 2. Data Summary Bar

    private var dataSummaryBar: some View {
        let depth = viewModel.dataDepth
        let insightCount = viewModel.focusedInsights.count

        return HStack(spacing: 0) {
            dataStat(value: "\(depth.metricsTracked)", label: "Metrics")
            Divider().frame(height: 28)
            dataStat(value: formatDataPoints(depth.totalDataPoints), label: "Data Points")
            if depth.daysOfData > 0 {
                Divider().frame(height: 28)
                dataStat(value: "\(depth.daysOfData)", label: depth.daysOfData == 1 ? "Day" : "Days")
            }
            Divider().frame(height: 28)
            dataStat(value: "\(insightCount)", label: "Insights")
        }
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dataStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDataPoints(_ count: Int) -> String {
        if count >= 10_000 { return "\(count / 1000)k" }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    // MARK: - 3. Score Breakdown

    @ViewBuilder
    private var scoreBreakdownSection: some View {
        if let explanation = viewModel.scoreExplanation {
            VStack(alignment: .leading, spacing: 10) {
                Text("What's Driving Your Score")
                    .font(.headline)

                // Top factors
                ForEach(Array(explanation.topFactors.prefix(4).enumerated()), id: \.offset) { _, factor in
                    HStack(spacing: 10) {
                        Image(systemName: factor.metric.systemImageName)
                            .font(.caption)
                            .foregroundStyle(factor.metric.category.color)
                            .frame(width: 24)

                        Text(factor.reason)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        Text("\(factor.impact > 0 ? "+" : "")\(factor.impact)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(factor.isPositive ? .green : .red)
                    }
                    .padding(.vertical, 4)
                }

                // Category weights
                if !explanation.categoryContributions.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 0) {
                        ForEach(explanation.categoryContributions.sorted(by: { $0.weight > $1.weight }).prefix(4), id: \.category) { contrib in
                            VStack(spacing: 2) {
                                Image(systemName: contrib.category.systemImageName)
                                    .font(.caption2)
                                    .foregroundStyle(contrib.category.color)
                                Text("\(contrib.score)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                Text("\(Int(contrib.weight * 100))%")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - 4. From Your History

    private var historicalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From Your History")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.historicalHighlights) { highlight in
                Button {
                    navigationPath.append(highlight.metric)
                } label: {
                    historicalCard(highlight)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private func historicalCard(_ highlight: DashboardViewModel.HistoricalHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.body)
                .foregroundStyle(highlight.isPositive ? .green : .orange)
                .frame(width: 32, height: 32)
                .background(
                    (highlight.isPositive ? Color.green : Color.orange).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlight.metric.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(highlight.typeLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(highlight.isPositive ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            (highlight.isPositive ? Color.green : Color.orange).opacity(0.12),
                            in: Capsule()
                        )
                }

                Text(highlight.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(highlight.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 5. Correlations Preview

    private var correlationsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Connections")
                    .font(.headline)

                Spacer()

                Button {
                    navigationPath.append("correlationsDetail")
                } label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ForEach(Array(viewModel.topCorrelations.prefix(2))) { correlation in
                correlationCard(correlation)
                    .padding(.horizontal)
            }
        }
    }

    private func correlationCard(_ c: HealthCorrelation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: c.metricA.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricA.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricA.category.color.opacity(0.12), in: Circle())

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: c.metricB.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricB.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricB.category.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(c.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(c.strengthLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 6. Categories (focus-sorted)

    /// Categories sorted so user's focus areas appear first
    private var sortedCategories: [HealthCategory] {
        let focuses = viewModel.focusCategories
        guard !focuses.isEmpty else { return HealthCategory.allCases.map { $0 } }
        return HealthCategory.allCases.sorted { a, b in
            let aFocus = focuses.contains(a)
            let bFocus = focuses.contains(b)
            if aFocus != bFocus { return aFocus }
            return false // preserve relative order for same-group items
        }
    }

    private var categoriesSection: some View {
        let categories = sortedCategories
        return VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                    Button {
                        navigationPath.append(category)
                    } label: {
                        ExploreCategoryRow(
                            category: category,
                            score: viewModel.analysisEngine.score(for: category)?.score,
                            insightCount: viewModel.analysisEngine.insights(for: category).count
                        )
                    }
                    .buttonStyle(.plain)

                    if index < categories.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Empty State

    private var hasAnyHealthData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    private var emptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: hasAnyHealthData ? "chart.line.text.clipboard" : "heart.text.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Health Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(hasAnyHealthData ? "Almost there..." : "No data yet")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                Text(hasAnyHealthData
                     ? "A few more days of tracking and your score will be ready"
                     : "Open the Health app and allow access to see your analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Computed Helpers

    private var weakestCategory: (category: HealthCategory, score: Int)? {
        let scored = HealthCategory.allCases.compactMap { cat -> (category: HealthCategory, score: Int)? in
            guard let score = viewModel.analysisEngine.score(for: cat)?.score else { return nil }
            return (category: cat, score: score)
        }
        return scored.min(by: { $0.score < $1.score })
    }

    private var grade: String {
        switch viewModel.overallScore.score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private var gradeColor: Color {
        switch viewModel.overallScore.score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var scoreLabel: String {
        switch viewModel.overallScore.score {
        case 85...100: return "Excellent shape"
        case 70..<85: return "Looking good"
        case 55..<70: return "Room to improve"
        default: return "Needs attention"
        }
    }
}

/// A single category row in the Explore list
private struct ExploreCategoryRow: View {
    let category: HealthCategory
    let score: Int?
    let insightCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.systemImageName)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(scoreStatus)
                        .font(.caption)
                        .foregroundStyle(scoreStatusColor)

                    if insightCount > 0 {
                        Text("\(insightCount) insight\(insightCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let score {
                HealthScoreRing(
                    score: score,
                    label: "",
                    size: 36,
                    lineWidth: 4
                )
            } else {
                Text("--")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var scoreStatus: String {
        guard let score else { return "No data yet" }
        switch score {
        case 85...100: return "On track"
        case 70..<85: return "Doing well"
        case 55..<70: return "Room to improve"
        case 40..<55: return "Needs work"
        default: return "Needs attention"
        }
    }

    private var scoreStatusColor: Color {
        guard let score else { return .secondary }
        switch score {
        case 80...100: return .green
        case 60..<80: return .secondary
        case 40..<60: return .orange
        default: return .red
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        ExploreView(
            viewModel: DashboardViewModel(
                healthKitManager: HealthKitManager(),
                analysisEngine: AnalysisEngine(),
                store: HealthDataStore(modelContainer: container)
            ),
            navigationPath: .constant(NavigationPath())
        )
    }
}
