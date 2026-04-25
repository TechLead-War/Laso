import SwiftUI

/// Full-screen intelligence view surfacing causal chains, compound insights, interaction effects,
/// and raw correlations in a tiered layout. from most sophisticated to simplest.
struct CorrelationsView: View {
    let correlations: [HealthCorrelation]
    let causalChains: [CausalChain]
    let compoundInsights: [CompoundInsightEngine.CompoundInsight]
    let interactionEffects: [InteractionEffectEngine.InteractionEffect]
    let onTapMetric: (HealthMetric) -> Void

    /// Guard against free-tier access via deep navigation
    private var isGated: Bool { !FeatureGate.canAccess(.advancedAnalytics) }

    @State private var showAllConnections = false
    @State private var filtersTracker = SectionTracker(section: .correlationsFilters, tab: .correlations)
    @State private var listTracker = SectionTracker(section: .correlationsList, tab: .correlations)

    private var hasIntelligence: Bool {
        !causalChains.isEmpty || !compoundInsights.isEmpty || !interactionEffects.isEmpty
    }

    /// Evidence correlations grouped by causal chain id. Each chain's links pull
    /// matching correlations out of the flat list so they appear as evidence
    /// inside the Why card instead of duplicating in All Connections.
    private var evidenceByChainID: [UUID: [HealthCorrelation]] {
        var grouped: [UUID: [HealthCorrelation]] = [:]
        for chain in causalChains {
            let metricsInChain: Set<HealthMetric> = Set(chain.links.flatMap { [$0.causeMetric, $0.effectMetric] })
            grouped[chain.id] = correlations.filter { c in
                metricsInChain.contains(c.metricA) && metricsInChain.contains(c.metricB)
            }
        }
        return grouped
    }

    /// Correlations not consumed as evidence by any causal chain — surfaced in
    /// the All Connections section to avoid showing the same rule twice.
    private var unmatchedCorrelations: [HealthCorrelation] {
        let consumedIDs: Set<UUID> = Set(evidenceByChainID.values.flatMap { $0 }.map(\.id))
        return correlations.filter { !consumedIDs.contains($0.id) }
    }

    var body: some View {
        if isGated {
            ProFeatureOverlay(
                feature: "Health Intelligence",
                icon: "brain.head.profile",
                description: "Discover how your health metrics influence each other."
            )
        }
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {

                // MARK: - Tier 1: Key Discoveries (compound insights)
                if !compoundInsights.isEmpty {
                    discoverySection
                }

                // MARK: - Tier 2: Causal Chains
                if !causalChains.isEmpty {
                    causalChainsSection
                }

                // MARK: - Tier 3: Interaction Effects
                if !interactionEffects.isEmpty {
                    interactionEffectsSection
                }

                // MARK: - Tier 4: All Connections (collapsible) — only correlations
                // not already shown as evidence inside a Why card.
                if !unmatchedCorrelations.isEmpty {
                    connectionsSection
                }

                // Empty state when nothing at all
                if !hasIntelligence && correlations.isEmpty {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .accessibilityIdentifier("screen.correlations")
        .navigationTitle(Copy.Insights.Correlations.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.correlations)
            AppAnalytics.shared.trackActivationMilestone(.firstCorrelation)
            AppAnalytics.shared.trackCoreAction(.viewedCorrelation, screen: .correlations)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "viewed_correlation", screen: .correlations)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.correlations) }
    }

    // MARK: - Tier 1: Key Discoveries

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: Copy.Insights.Correlations.keyDiscoveries, icon: "lightbulb.max.fill", color: AppColour.warning)
                .padding(.horizontal)

            ForEach(Array(compoundInsights.prefix(5).enumerated()), id: \.offset) { _, insight in
                CompoundInsightCard(insight: insight) {
                    if let metric = insight.involvedMetrics.first {
                        onTapMetric(metric)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Tier 2: Causal Chains

    private var causalChainsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: Copy.Insights.Correlations.whyThingsChanged, icon: "arrow.triangle.branch", color: .purple)
                .padding(.horizontal)

            ForEach(causalChains.prefix(4)) { chain in
                CausalChainCard(
                    chain: chain,
                    evidence: evidenceByChainID[chain.id] ?? []
                ) {
                    onTapMetric(chain.affectedMetric)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Tier 3: Interaction Effects

    private var interactionEffectsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: Copy.Insights.Correlations.howMuchMatters, icon: "chart.line.uptrend.xyaxis", color: .cyan)
                .padding(.horizontal)

            ForEach(Array(interactionEffects.prefix(4).enumerated()), id: \.offset) { _, effect in
                InteractionEffectCard(effect: effect) {
                    onTapMetric(effect.cause)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Tier 4: All Connections (collapsible)

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Button {
                withAnimation(DS.Motion.toast) {
                    showAllConnections.toggle()
                }
            } label: {
                HStack {
                    sectionHeader(
                        title: Copy.Insights.Correlations.allConnections,
                        icon: "point.3.connected.trianglepath.dotted",
                        color: .secondary
                    )

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(unmatchedCorrelations.count)")
                            .font(DS.Typography.subheadlineMedium.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: showAllConnections ? "chevron.up" : "chevron.down")
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.dsPress)
            .padding(.horizontal)

            if showAllConnections {
                LazyVStack(spacing: DS.space2) {
                    ForEach(unmatchedCorrelations) { correlation in
                        CompactCorrelationRow(correlation: correlation) {
                            AppAnalytics.shared.trackCorrelationTapped(
                                metricA: correlation.metricA.rawValue,
                                metricB: correlation.metricB.rawValue,
                                strength: correlation.strengthLabel,
                                screen: .correlations
                            )
                            listTracker.tapped(target: "\(correlation.metricA.rawValue)_\(correlation.metricB.rawValue)")
                            onTapMetric(correlation.metricA)
                        }
                        .padding(.horizontal)
                    }
                }
                .onAppear { listTracker.appeared() }
                .onDisappear { listTracker.disappeared() }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(color)
            Text(title)
                .font(DS.Typography.headline)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(DS.Typography.mediumIcon)
                .foregroundStyle(.tertiary)
            Text(Copy.Insights.Correlations.buildingIntelligence)
                .font(DS.Typography.subheadlineMedium)
                .foregroundStyle(.secondary)
            Text(Copy.Insights.Correlations.keepWearingDevice)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Compound Insight Card

/// Rich card for multi-metric compound insights from the ML pipeline
private struct CompoundInsightCard: View {
    let insight: CompoundInsightEngine.CompoundInsight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.space2) {
                // Category + severity header
                HStack(spacing: DS.space2) {
                    Image(systemName: categoryIcon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(categoryColor, in: Circle())

                    Text(insight.category.rawValue.camelCaseToWords.capitalized)
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(categoryColor)
                        .textCase(.uppercase)

                    Spacer()

                    if insight.confidence >= 0.7 {
                        ConfidenceBadge(confidence: insight.confidence)
                    }
                }

                // Title
                Text(insight.title)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Narrative
                Text(insight.narrative)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                // Metrics involved + action hint
                HStack(spacing: DS.space2) {
                    ForEach(insight.involvedMetrics.prefix(4), id: \.rawValue) { metric in
                        Image(systemName: metric.systemImageName)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(metric.category.color)
                            .frame(width: 18, height: 18)
                            .background(metric.category.color.opacity(0.12), in: Circle())
                    }

                    if insight.involvedMetrics.count > 4 {
                        Text("+\(insight.involvedMetrics.count - 4)")
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if insight.isActionable {
                        Text(Copy.Insights.Correlations.actionableBadge)
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(AppColour.success)
                            .padding(.horizontal, DS.badgeH)
                            .padding(.vertical, DS.badgeV)
                            .background(AppColour.success.opacity(DS.badgeBg), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: categoryColor)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insight.title)
        .accessibilityValue(insight.narrative)
        .accessibilityAddTraits(.isButton)
    }

    private var categoryIcon: String {
        switch insight.category {
        case .trajectory: return "arrow.up.right"
        case .hiddenPattern: return "eye"
        case .causeAndEffect: return "arrow.triangle.branch"
        case .personalRecord: return "star.fill"
        case .riskWarning: return "exclamationmark.triangle.fill"
        case .optimization: return "slider.horizontal.3"
        case .recovery: return "heart.circle.fill"
        case .breakthrough: return "sparkles"
        }
    }

    private var categoryColor: Color {
        switch insight.category {
        case .trajectory: return AppColour.info
        case .hiddenPattern: return AppColour.categorySleep
        case .causeAndEffect: return AppColour.categoryStress
        case .personalRecord: return AppColour.warning
        case .riskWarning: return AppColour.danger
        case .optimization: return AppColour.accent
        case .recovery: return AppColour.success
        case .breakthrough: return AppColour.warning
        }
    }
}

// MARK: - Causal Chain Card

/// Card showing a multi-link causal chain (A → B → C) with narrative
struct CausalChainCard: View {
    let chain: CausalChain
    var evidence: [HealthCorrelation] = []
    let onTap: () -> Void

    @State private var showEvidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: DS.space2) {
                    // Chain visualization: metric icons connected by arrows
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.space2) {
                            ForEach(Array(chain.links.enumerated()), id: \.offset) { index, link in
                                if index == 0 {
                                    metricPill(link.causeMetric, deviation: link.causeDeviation)
                                }

                                Image(systemName: "arrow.right")
                                    .font(DS.Typography.caption2Semibold)
                                    .foregroundStyle(AppColour.categoryStress.opacity(0.6))

                                metricPill(link.effectMetric, deviation: link.effectDeviation)
                            }
                        }
                    }

                    // Narrative explanation
                    Text(chain.narrative)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)

                    // Confidence footer
                    HStack(spacing: 8) {
                        ConfidenceBadge(confidence: chain.confidence)

                        Text("\(chain.links.count)-step chain")
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.dsPress)

            if !evidence.isEmpty {
                Divider().opacity(0.5)

                Button {
                    withAnimation(DS.Motion.toast) { showEvidence.toggle() }
                } label: {
                    HStack(spacing: DS.space2) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.purple)
                        Text(Copy.Insights.Correlations.evidenceLabel)
                            .font(DS.Typography.subheadlineSemibold)
                            .foregroundStyle(.primary)
                        Text("\(evidence.count)")
                            .font(DS.Typography.captionMedium.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showEvidence ? "chevron.up" : "chevron.down")
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.dsPress)

                if showEvidence {
                    VStack(spacing: DS.space2) {
                        ForEach(evidence) { c in
                            CompactCorrelationRow(correlation: c) {
                                onTap()
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .purple)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Causal chain affecting \(chain.affectedMetric.displayName)")
        .accessibilityValue(chain.narrative)
    }

    private func metricPill(_ metric: HealthMetric, deviation: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: metric.systemImageName)
                .font(DS.Typography.caption2Semibold)
                .foregroundStyle(metric.category.color)

            if abs(deviation) >= 5 {
                Text("\(deviation > 0 ? "+" : "")\(Int(deviation))%")
                    .font(DS.Typography.caption2Semibold.monospacedDigit())
                    .foregroundStyle(deviation > 0 ? AppColour.success : AppColour.danger)
            }
        }
        .padding(.horizontal, DS.space2)
        .padding(.vertical, DS.space1)
        .background(metric.category.color.opacity(0.08), in: Capsule())
    }
}

// MARK: - Interaction Effect Card

/// Card showing dose-response, threshold, or moderation effects
private struct InteractionEffectCard: View {
    let effect: InteractionEffectEngine.InteractionEffect
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.space2) {
                // Effect type badge + metrics
                HStack(spacing: 8) {
                    Image(systemName: effectTypeIcon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.cyan, in: Circle())

                    Text(effectTypeLabel)
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(.cyan)
                        .textCase(.uppercase)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: effect.cause.systemImageName)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(effect.cause.category.color)
                        Image(systemName: "arrow.right")
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.tertiary)
                        Image(systemName: effect.effect.systemImageName)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(effect.effect.category.color)
                    }
                }

                // Description
                Text(effect.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                // Strength + sample count + condition
                HStack(spacing: 8) {
                    StrengthDots(strength: effect.strength)

                    Text("\(effect.sampleCount) days")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(.secondary)

                    if let condition = effect.condition {
                        Text(condition)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: .cyan)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(effectTypeLabel): \(effect.cause.displayName) affects \(effect.effect.displayName)")
        .accessibilityValue(effect.description)
        .accessibilityAddTraits(.isButton)
    }

    private var effectTypeIcon: String {
        switch effect.effectType {
        case .doseResponse: return "chart.bar.fill"
        case .conditionalPositive: return "checkmark.circle.fill"
        case .conditionalNegative: return "xmark.circle.fill"
        case .uShape: return "chart.line.downtrend.xyaxis"
        case .invertedU: return "mountain.2.fill"
        case .threshold: return "line.horizontal.star.fill.line.horizontal"
        case .saturation: return "chart.line.flattrend.xyaxis"
        case .moderation: return "dial.medium.fill"
        }
    }

    private var effectTypeLabel: String {
        switch effect.effectType {
        case .doseResponse: return "Dose-Response"
        case .conditionalPositive: return "Conditional Boost"
        case .conditionalNegative: return "Conditional Drop"
        case .uShape: return "U-Shaped"
        case .invertedU: return "Sweet Spot"
        case .threshold: return "Threshold"
        case .saturation: return "Diminishing Returns"
        case .moderation: return "Moderated"
        }
    }
}

// MARK: - Compact Correlation Row (for All Connections)

/// Minimal row for the collapsible "All Connections" section
private struct CompactCorrelationRow: View {
    let correlation: HealthCorrelation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: correlation.metricA.systemImageName)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(correlation.metricA.category.color)
                    .frame(width: 28, height: 28)
                    .background(correlation.metricA.category.color.opacity(0.12), in: Circle())

                Image(systemName: "arrow.right")
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(.tertiary)

                Image(systemName: correlation.metricB.systemImageName)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(correlation.metricB.category.color)
                    .frame(width: 28, height: 28)
                    .background(correlation.metricB.category.color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text("\(correlation.causeLabel) → \(correlation.effectLabel)")
                        .font(DS.Typography.subheadlineMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Copy.Insights.Correlations.correlationSummary(strength: correlation.strengthLabel, dayLabel: correlation.dayOffset == 0 ? Copy.Insights.Correlations.sameDay : Copy.Insights.Correlations.nextDay, effectPercent: Int(correlation.effectPercentDiff)))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.space2)
            .padding(.horizontal, DS.space3)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.dsPress)
    }
}

// MARK: - Supporting Views

private struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: DS.space1) {
            Image(systemName: "checkmark.seal.fill")
                .font(DS.Typography.caption2)
            Text("\(Int(confidence * 100))%")
                .font(DS.Typography.caption2Semibold.monospacedDigit())
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, DS.badgeH)
        .padding(.vertical, DS.badgeV)
        .background(badgeColor.opacity(DS.badgeBg), in: Capsule())
    }

    private var badgeColor: Color {
        if confidence >= 0.8 { return AppColour.success }
        if confidence >= 0.6 { return AppColour.warning }
        return AppColour.warning
    }
}

private struct StrengthDots: View {
    let strength: Double

    var body: some View {
        HStack(spacing: DS.space1) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? AppColour.accent : AppColour.accent.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var filledCount: Int {
        if strength >= 0.7 { return 3 }
        if strength >= 0.4 { return 2 }
        return 1
    }
}

// MARK: - String Extension

private extension String {
    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                return result + " " + String(scalar).lowercased()
            }
            return result + String(scalar)
        }
    }
}
