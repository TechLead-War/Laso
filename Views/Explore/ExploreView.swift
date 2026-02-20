import SwiftUI

/// Data exploration tab with overall score and category drill-down list
struct ExploreView: View {
    let viewModel: DashboardViewModel
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Health Score hero
                healthScoreHero
                    .padding(.horizontal)

                // Category rows
                VStack(spacing: 0) {
                    ForEach(HealthCategory.allCases) { category in
                        Button {
                            navigationPath.append(category)
                        } label: {
                            ExploreCategoryRow(
                                category: category,
                                score: viewModel.analysisEngine.score(for: category)?.score ?? 100,
                                insightCount: viewModel.analysisEngine.insights(for: category).count
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(category.displayName), score \(viewModel.analysisEngine.score(for: category)?.score ?? 100), \(viewModel.analysisEngine.insights(for: category).count) insights")
                        .accessibilityHint("View \(category.displayName) details")

                        if category != HealthCategory.allCases.last {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var healthScoreHero: some View {
        VStack(spacing: 12) {
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

                    Text(scoreLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Show weakest category to guide improvement
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health score \(viewModel.overallScore.score) out of 100, grade \(grade), \(scoreLabel)")
    }

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
    let score: Int
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

                Text(scoreStatus)
                    .font(.caption)
                    .foregroundStyle(scoreStatusColor)
            }

            Spacer()

            HealthScoreRing(
                score: score,
                label: "",
                size: 36,
                lineWidth: 4
            )

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var scoreStatus: String {
        switch score {
        case 85...100: return "On track"
        case 70..<85: return "Doing well"
        case 55..<70: return "Room to improve"
        case 40..<55: return "Needs work"
        default: return "Needs attention"
        }
    }

    private var scoreStatusColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .secondary
        case 40..<60: return .orange
        default: return .red
        }
    }
}

#Preview {
    NavigationStack {
        ExploreView(
            viewModel: DashboardViewModel(
                healthKitManager: HealthKitManager(),
                analysisEngine: AnalysisEngine()
            ),
            navigationPath: .constant(NavigationPath())
        )
    }
}
