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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
                    .font(.headline)
                    .padding(.horizontal)

                Text(Copy.Journal.Insights.topDiscoveriesSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "book.and.wrench.fill")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(.secondary)

            Text(Copy.Journal.Insights.insightsUnlocking)
                .font(.title3.weight(.semibold))

            Text(Copy.Journal.Insights.emptyStateDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            // Progress indicator
            progressIndicator
        }
        .frame(maxWidth: .infinity)
    }

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            // Show a simple visual of logged categories
            HStack(spacing: 12) {
                ForEach(JournalCategory.allCases.prefix(5)) { category in
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.tertiary)
                            .frame(width: 24, height: 3)
                    }
                }
            }
            .padding(.top, DS.space2)

            Text(Copy.Journal.Insights.startLogging)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Correlation Card

/// Card showing a single journal behavior to health outcome correlation
private struct JournalCorrelationCard: View {
    let correlation: JournalCorrelationAnalyzer.JournalCorrelation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: behavior icon → health metric icon
            HStack(spacing: 8) {
                // Journal category icon
                Image(systemName: correlation.category.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(categoryColor, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(correlation.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    confidenceBadge
                }

                Spacer()

                // Arrow → Health metric
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)

                Image(systemName: correlation.healthMetric.systemImageName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(correlation.healthMetric.category.color)
                    .frame(width: 28)

                Text(correlation.healthMetric.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            // Insight text
            Text(correlation.insight)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)

            // Bottom row: strength + sample size + effect
            HStack(spacing: 8) {
                StrengthBadge(label: correlation.strengthLabel)

                Text("\(correlation.sampleCount) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                // Effect indicator
                effectIndicator
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: categoryColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(correlation.category.displayName) affects \(correlation.healthMetric.displayName)")
        .accessibilityValue("\(correlation.strengthLabel) correlation, \(correlation.sampleCount) days of data")
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
        case .high: return .green
        case .medium: return .blue
        case .emerging: return .orange
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
            return correlation.effectPercent > 0 ? .green : .red
        } else if isRHR {
            // Lower is better for resting HR
            return correlation.effectPercent < 0 ? .green : .red
        }
        return .blue
    }

    private var categoryColor: Color {
        switch correlation.category {
        case .caffeine: return .brown
        case .alcohol: return .purple
        case .stress: return .red
        case .supplements: return .green
        case .meditation: return .indigo
        case .screenTime: return .blue
        case .mealTiming: return .orange
        case .water: return .cyan
        case .mood: return .yellow
        }
    }
}
