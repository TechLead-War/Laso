import SwiftUI

/// Shows discovered correlations between journal behaviors and health outcomes.
/// Presents "Your Top Discoveries" with confidence badges and correlation strength indicators.
struct JournalInsightsView: View {
    let correlations: [JournalCorrelationAnalyzer.JournalCorrelation]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                if correlations.isEmpty {
                    emptyState
                } else {
                    discoveriesSection
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Journal.Insights.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.journalInsights)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.journalInsights)
        }
    }

    // MARK: - Discoveries Section

    private var discoveriesSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Journal.Insights.topDiscoveries)
                    .font(DS.Typography.headline)
                    .padding(.horizontal)

                Text(Copy.Journal.Insights.topDiscoveriesSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal)
            }

            ForEach(correlations) { correlation in
                JournalCorrelationCard(correlation: correlation)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.space4) {
            Spacer().frame(height: 60)

            Image(systemName: "book.and.wrench.fill")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(AppColour.textSecondary)

            Text(Copy.Journal.Insights.insightsUnlocking)
                .font(DS.Typography.title3)

            Text(Copy.Journal.Insights.emptyStateDescription)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            // Progress indicator
            progressIndicator
        }
        .frame(maxWidth: .infinity)
    }

    private var progressIndicator: some View {
        VStack(spacing: DS.space2) {
            // Show a simple visual of logged categories
            HStack(spacing: DS.itemSpacing) {
                ForEach(JournalCategory.allCases.prefix(5)) { category in
                    VStack(spacing: DS.space1) {
                        Image(systemName: category.icon)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textTertiary)
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(AppColour.textTertiary)
                            .frame(width: 24, height: 3)
                    }
                }
            }
            .padding(.top, DS.space2)

            Text(Copy.Journal.Insights.startLogging)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
        }
    }
}

// MARK: - Correlation Card

/// Card showing a single journal behavior to health outcome correlation
private struct JournalCorrelationCard: View {
    let correlation: JournalCorrelationAnalyzer.JournalCorrelation

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            // Top row: behavior icon → health metric icon
            HStack(spacing: DS.space2) {
                // Journal category icon
                Image(systemName: correlation.category.icon)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(categoryColor, in: Circle())

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(correlation.category.displayName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)

                    confidenceBadge
                }

                Spacer()

                // Arrow → Health metric
                Image(systemName: "arrow.right")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textTertiary)

                Image(systemName: correlation.healthMetric.systemImageName)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(correlation.healthMetric.category.color)
                    .frame(width: 28)

                Text(correlation.healthMetric.displayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            // Insight text
            Text(correlation.insight)
                .font(DS.Typography.subheadlineMedium)
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(3)

            // Bottom row: strength + sample size + effect
            HStack(spacing: DS.space2) {
                StrengthBadge(label: correlation.strengthLabel)

                Text(Copy.Journal.daysText(correlation.sampleCount))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)

                Spacer()

                // Effect indicator
                effectIndicator
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: categoryColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Journal.affectsLabel(correlation.category.displayName, correlation.healthMetric.displayName))
        .accessibilityValue(Copy.Journal.correlationDaysOfDataValue(correlation.strengthLabel, correlation.sampleCount))
    }

    // MARK: - Confidence Badge

    private var confidenceBadge: some View {
        let confidence = correlation.confidenceLevel
        return HStack(spacing: 4) {
            Image(systemName: confidence.icon)
                .font(.caption2)
            Text(confidence.rawValue)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(confidenceColor)
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(confidenceColor.opacity(DS.badgeBg), in: Capsule())
    }

    private var confidenceColor: Color {
        switch correlation.confidenceLevel {
        case .high: return AppColour.success
        case .medium: return AppColour.info
        case .emerging: return AppColour.warning
        }
    }

    // MARK: - Effect Indicator

    private var effectIndicator: some View {
        let absDiff = abs(correlation.effectPercent)
        let direction = correlation.effectPercent > 0 ? "higher" : "lower"
        let arrow = correlation.effectPercent > 0 ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.caption2.weight(.bold))
            Text(String(format: "%.0f%% %@", absDiff, direction))
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(effectColor)
    }

    private var effectColor: Color {
        // Determine if the effect is good or bad based on the metric
        let isHRV = correlation.healthMetric == .heartRateVariability
        let isSleep = [HealthMetric.sleepDuration, .sleepDeep, .sleepREM].contains(correlation.healthMetric)
        let isRHR = correlation.healthMetric == .restingHeartRate

        if isHRV || isSleep {
            // Higher is better for HRV and sleep metrics
            return correlation.effectPercent > 0 ? AppColour.success : AppColour.danger
        } else if isRHR {
            // Lower is better for resting HR
            return correlation.effectPercent < 0 ? AppColour.success : AppColour.danger
        }
        return AppColour.info
    }

    private var categoryColor: Color {
        switch correlation.category {
        case .caffeine: return .brown
        case .alcohol: return AppColour.categoryStress
        case .stress: return AppColour.danger
        case .supplements: return AppColour.success
        case .meditation: return AppColour.categorySleep
        case .screenTime: return AppColour.info
        case .mealTiming: return AppColour.warning
        case .water: return AppColour.accent
        case .mood: return AppColour.categoryActivity
        }
    }
}
