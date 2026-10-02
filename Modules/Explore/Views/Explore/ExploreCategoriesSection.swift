import SwiftUI

struct ExploreCategoriesSection: View {
    let categories: [(category: HealthCategory, score: Int?)]
    let insightCountProvider: (HealthCategory) -> Int
    let onCategoryTapped: (HealthCategory, Int?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Explore.categories)
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.space3),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: DS.space3) {
                ForEach(categories, id: \.category) { item in
                    Button {
                        // The owner of `onCategoryTapped` is the single emitter
                        // for this tap. Firing here too double-counted every
                        // category tap under a second block type.
                        onCategoryTapped(item.category, item.score)
                    } label: {
                        ExploreCategoryRow(
                            category: item.category,
                            score: item.score,
                            insightCount: insightCountProvider(item.category)
                        )
                    }
                    .buttonStyle(.dsPress)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("explore.category.\(item.category.rawValue)")
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Copy.Explore.categoryLabel(item.category.displayName))
                    .accessibilityValue(item.score.map { "Score \($0)" } ?? "No score yet")
                    .accessibilityHint(Copy.Explore.opensTheCategoryDetailHint(item.category.displayName))


                }
            }

        }
    }
}

struct ExploreCategoryRow: View {
    let category: HealthCategory
    let score: Int?
    let insightCount: Int

    private var needsAttention: Bool {
        guard let score else { return false }
        return HealthScoreBand.from(score: score).requiresAttention
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            HStack(alignment: .center) {
                Image(systemName: category.systemImageName)
                    .font(.title3)
                    .foregroundStyle(category.color)
                Spacer(minLength: 4)
                Text(score.map { $0.formatted() } ?? "—")
                    .font(.title2.weight(.regular).monospacedDigit())
                    .foregroundStyle(AppColour.textPrimary)
                    .postHogMask()
            }
            VStack(alignment: .leading, spacing: DS.space1) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColour.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(scoreStatus)
                    .font(.caption)
                    .foregroundStyle(scoreStatusColor)
                    .fixedSize(horizontal: false, vertical: true)
                if insightCount > 0 {
                    Text(Copy.Explore.insightCount(insightCount))
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DS.space4)
        .cardStyle()
    }

    private var scoreStatus: String {
        guard let score else { return Copy.Explore.noDataYet }
        switch HealthScoreBand.from(score: score) {
        case .excellent: return Copy.Explore.onTrack
        case .good: return Copy.Explore.doingWell
        case .fair: return Copy.Explore.roomToImprove
        case .needsAttention: return Copy.Explore.needsWork
        case .critical: return Copy.Explore.needsAttention
        }
    }

    private var scoreStatusColor: Color {
        guard let score else { return AppColour.textSecondary }
        switch HealthScoreBand.from(score: score) {
        case .excellent: return AppColour.success
        case .good: return AppColour.textSecondary
        case .fair: return AppColour.warning
        case .needsAttention, .critical: return AppColour.danger
        }
    }
}
