import SwiftUI
import Charts

/// WHOOP-style green requested for healthy/normal/slowing pace states.
private let vitalityWhoopGreen = Color(red: 0.0, green: 217.0 / 255.0, blue: 176.0 / 255.0) // #00D9B0
private let vitalityPaceYellow = Color(red: 0.96, green: 0.77, blue: 0.26) // #F5C542
private let vitalityPaceRed = Color(red: 1.0, green: 0.30, blue: 0.31) // #FF4D4F

/// Pace cutoffs tuned so normal/slowing pace stays green,
/// while faster-than-normal aging turns yellow/red earlier.
private let vitalityPaceGreenUpperBound = 1.08
private let vitalityPaceYellowUpperBound = 1.22

/// Full detail screen for Vitality Age:
/// - Organic orb hero with pace-aware color state
/// - Metric-by-metric contributions
/// - 90-day trend chart
/// - Targeted improvement opportunities
struct VitalityDetailView: View {
    let scorer: VitalityScorer

    @State private var orbPhase: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroSection

                if !scorer.isFullyMature {
                    dataMaturityBanner
                }

                if scorer.personalizationStatus != .buildingProfile && !scorer.componentAges.isEmpty {
                    metricContributionSection
                }

                if scorer.history.count >= 7 {
                    trendSection
                }

                if scorer.personalizationStatus != .buildingProfile && !scorer.topImprovementOpportunities.isEmpty {
                    improvementSection
                }

                methodologySection
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Vitality Age")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.vitalityDetail)
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbPhase = .pi * 2
            }
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.vitalityDetail)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                OrganicParticleOrbView(phase: orbPhase, tint: paceTint)
                    .frame(width: 282, height: 254)

                VStack(spacing: 6) {
                    Text(String(format: "%.1f", Double(scorer.vitalityAge)))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("VITALITY AGE")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.68))

                    Text(deltaBadgeText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(paceTint)
                        .monospacedDigit()
                }

                if heroComponents.indices.contains(0) {
                    OrbMetricChip(
                        component: heroComponents[0],
                        chronologicalAge: scorer.chronologicalAge,
                        healthyTint: vitalityWhoopGreen,
                        cautionTint: vitalityPaceYellow,
                        riskTint: vitalityPaceRed
                    )
                    .offset(x: -122, y: -102)
                }

                if heroComponents.indices.contains(1) {
                    OrbMetricChip(
                        component: heroComponents[1],
                        chronologicalAge: scorer.chronologicalAge,
                        healthyTint: vitalityWhoopGreen,
                        cautionTint: vitalityPaceYellow,
                        riskTint: vitalityPaceRed
                    )
                    .offset(x: -120, y: 102)
                }

                if heroComponents.indices.contains(2) {
                    OrbMetricChip(
                        component: heroComponents[2],
                        chronologicalAge: scorer.chronologicalAge,
                        healthyTint: vitalityWhoopGreen,
                        cautionTint: vitalityPaceYellow,
                        riskTint: vitalityPaceRed
                    )
                    .offset(x: 122, y: 70)
                }
            }
            .frame(height: 352)

            HStack(spacing: 8) {
                badge(text: "Actual age \(scorer.chronologicalAge)", tint: .white.opacity(0.36), foreground: .white)

                if scorer.personalizationStatus == .personalized {
                    badge(
                        text: "90d \(scorer.paceLabel)",
                        tint: paceTint.opacity(0.26),
                        foreground: paceTint,
                        icon: paceIcon
                    )

                    badge(
                        text: paceStateText,
                        tint: paceTint.opacity(0.26),
                        foreground: paceTint
                    )
                } else {
                    badge(
                        text: scorer.personalizationStatus.rawValue,
                        tint: personalizationTint.opacity(0.24),
                        foreground: personalizationTint,
                        icon: personalizationIcon
                    )
                }
            }

            Text(heroNarrative)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(paceTint.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: paceTint.opacity(0.22), radius: 16, y: 8)
        .padding(.horizontal)
    }

    private func badge(text: String, tint: Color, foreground: Color, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, DS.badgeH + 3)
        .padding(.vertical, DS.badgeV + 2)
        .background(tint, in: Capsule())
    }

    // MARK: - Metric Contributions

    private var metricContributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.bar.fill", title: "Metric Contributions")

            VStack(spacing: 0) {
                ForEach(Array(scorer.componentAges.enumerated()), id: \.element.id) { index, component in
                    metricRow(component)

                    if index < scorer.componentAges.count - 1 {
                        Divider()
                            .padding(.leading, DS.cardPadding + 40 + 10)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func metricRow(_ component: VitalityComponent) -> some View {
        let metricDelta = component.delta(chronologicalAge: scorer.chronologicalAge)
        let tint = deltaColor(for: metricDelta)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: component.healthMetric?.systemImageName ?? "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(component.metric)
                        .font(.subheadline.weight(.semibold))

                    Text(metricSubtitle(for: component))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Age \(component.metricAge)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(tint)

                    Text(metricDeltaLabel(metricDelta))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.85))
                }
            }

            metricValueBar(component: component, tint: tint)
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 10)
    }

    private func metricValueBar(component: VitalityComponent, tint: Color) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let markerX = max(0, min(width - 8, width * metricGaugePosition(component)))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.28), Color.orange.opacity(0.28), vitalityWhoopGreen.opacity(0.28)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 5)

                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                    .offset(x: markerX, y: -1.5)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.xyaxis.line", title: "90-Day Trend")

            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    RuleMark(y: .value("Chronological Age", Double(scorer.chronologicalAge)))
                        .foregroundStyle(.red.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))

                    ForEach(Array(scorer.history.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", Double(scorer.chronologicalAge)),
                            yEnd: .value("Age", Double(point.age))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyFillColor)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Age", Double(point.age))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    if let latest = scorer.history.last {
                        PointMark(
                            x: .value("Latest Date", latest.date),
                            y: .value("Latest Age", Double(latest.age))
                        )
                        .symbolSize(42)
                        .foregroundStyle(historyLineColor)
                    }
                }
                .chartYScale(domain: chartYRange)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 15)) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let y = value.as(Double.self) {
                                Text("\(Int(y))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 196)

                HStack(spacing: 0) {
                    trendStat(title: "90d change", value: historyChangeText, color: historyChangeColor)

                    Divider()
                        .frame(height: DS.dividerHeight)
                        .padding(.horizontal, 12)

                    trendStat(title: "Pace", value: scorer.paceLabel, color: paceTint)

                    Divider()
                        .frame(height: DS.dividerHeight)
                        .padding(.horizontal, 12)

                    trendStat(title: "Current", value: "Age \(scorer.vitalityAge)", color: historyLineColor)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: historyLineColor)
            .padding(.horizontal)
        }
    }

    private func trendStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Improvements

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "lightbulb.fill", title: "Top Improvements")

            VStack(spacing: 10) {
                ForEach(scorer.topImprovementOpportunities) { component in
                    improvementCard(component)
                }
            }
            .padding(.horizontal)
        }
    }

    private func improvementCard(_ component: VitalityComponent) -> some View {
        let impact = max(component.delta(chronologicalAge: scorer.chronologicalAge), 0)
        let icon = component.healthMetric?.systemImageName ?? "arrow.up.circle.fill"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 30, height: 30)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

                Text(component.metric)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("+\(impact)y")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.badgeH + 2)
                    .padding(.vertical, DS.badgeV + 1)
                    .background(.orange, in: Capsule())
            }

            Text(component.improvementSuggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .orange)
    }

    // MARK: - Data Maturity Banner

    private var dataMaturityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(vitalityWhoopGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text(scorer.personalizationStatus.rawValue)
                    .font(.subheadline.weight(.semibold))

                Text(dataMaturityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(vitalityWhoopGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(vitalityWhoopGreen.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Methodology

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "info.circle.fill", title: "How this works")

            Text("Vitality Age compares your key metrics against age-adjusted population norms and combines them into one performance age estimate. It is for wellness guidance only and is not a medical diagnosis.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private enum PaceState {
        case healthy
        case caution
        case risk
    }

    private var paceState: PaceState {
        if scorer.paceOfAging <= vitalityPaceGreenUpperBound {
            return .healthy
        }
        if scorer.paceOfAging <= vitalityPaceYellowUpperBound {
            return .caution
        }
        return .risk
    }

    private var paceTint: Color {
        switch paceState {
        case .healthy: return vitalityWhoopGreen
        case .caution: return vitalityPaceYellow
        case .risk: return vitalityPaceRed
        }
    }

    private var paceStateText: String {
        switch paceState {
        case .healthy: return "Normal or slower"
        case .caution: return "Aging too quickly"
        case .risk: return "Aging very fast"
        }
    }

    private var heroNarrative: String {
        if scorer.personalizationStatus == .buildingProfile {
            return "We are building your profile. For now, your vitality age stays aligned with your chronological age."
        }
        if scorer.personalizationStatus == .earlyEstimate {
            if scorer.delta < 0 {
                return "Early estimate: your body currently appears about \(abs(scorer.delta)) years younger. Confidence improves as more data is collected."
            }
            if scorer.delta > 0 {
                return "Early estimate: your body currently appears about \(scorer.delta) years older. Confidence improves as more data is collected."
            }
            return "Early estimate: your vitality age is currently aligned with your chronological age."
        }

        if scorer.delta < 0 {
            return "Your body is performing about \(abs(scorer.delta)) years younger than your chronological age."
        }
        if scorer.delta > 0 {
            return "Your body is performing about \(scorer.delta) years older than your chronological age. Focus on the top improvement levers below."
        }
        return "Your vitality age is aligned with your chronological age. Maintaining your current routine can preserve this trend."
    }

    private var heroComponents: [VitalityComponent] {
        if scorer.personalizationStatus == .buildingProfile {
            return []
        }
        return Array(
            scorer.componentAges
                .sorted {
                    abs($0.delta(chronologicalAge: scorer.chronologicalAge)) >
                    abs($1.delta(chronologicalAge: scorer.chronologicalAge))
                }
                .prefix(3)
        )
    }

    private var deltaBadgeText: String {
        if scorer.personalizationStatus == .buildingProfile {
            return "Building your profile"
        }
        if scorer.delta < 0 { return "\(abs(scorer.delta)) years younger" }
        if scorer.delta > 0 { return "\(scorer.delta) years older" }
        return "On track"
    }

    private var paceIcon: String {
        switch paceState {
        case .healthy: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .risk: return "xmark.octagon.fill"
        }
    }

    private func deltaColor(for delta: Int) -> Color {
        if delta <= -3 { return vitalityWhoopGreen }
        if delta < 0 { return Color(red: 0.18, green: 0.87, blue: 0.78) }
        if delta == 0 { return .blue }
        if delta <= 3 { return .orange }
        return vitalityPaceRed
    }

    private func metricDeltaLabel(_ delta: Int) -> String {
        if delta < 0 { return "\(abs(delta))y younger" }
        if delta > 0 { return "+\(delta)y older" }
        return "On track"
    }

    private func metricSubtitle(for component: VitalityComponent) -> String {
        let current = formatMetricValue(component.currentValue, unit: component.unit, metric: component.healthMetric)
        let expected = formatMetricValue(component.populationMedian, unit: component.unit, metric: component.healthMetric)
        return "\(current) now, typical \(expected)"
    }

    private func formatMetricValue(_ value: Double, unit: String, metric: HealthMetric?) -> String {
        let raw: String
        if let metric {
            raw = metric.formatValue(value)
        } else if value == value.rounded() {
            raw = "\(Int(value))"
        } else {
            raw = String(format: "%.1f", value)
        }

        return unit.isEmpty ? raw : "\(raw) \(unit)"
    }

    private func metricGaugePosition(_ component: VitalityComponent) -> Double {
        let median = component.populationMedian
        let current = component.currentValue
        let higherIsBetter = component.healthMetric?.higherIsBetter ?? true
        let range = max(0.0001, median * 0.6)
        let raw = (current - (median - range)) / (2 * range)
        let normalized = max(0, min(1, raw))
        return higherIsBetter ? normalized : (1 - normalized)
    }

    private var chartYRange: ClosedRange<Double> {
        guard !scorer.history.isEmpty else {
            return Double(scorer.chronologicalAge - 8)...Double(scorer.chronologicalAge + 8)
        }

        let values = scorer.history.map { Double($0.age) } + [Double(scorer.chronologicalAge)]
        let minValue = (values.min() ?? Double(scorer.chronologicalAge)) - 2
        let maxValue = (values.max() ?? Double(scorer.chronologicalAge)) + 2
        return minValue...maxValue
    }

    private var historyLineColor: Color {
        paceTint
    }

    private var historyFillColor: Color {
        paceTint.opacity(0.16)
    }

    private var historyChangeText: String {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return "--"
        }

        let change = last - first
        if change > 0 { return "+\(change)y" }
        if change < 0 { return "\(change)y" }
        return "0y"
    }

    private var historyChangeColor: Color {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return .secondary
        }
        return deltaColor(for: last - first)
    }

    private var personalizationIcon: String {
        switch scorer.personalizationStatus {
        case .buildingProfile: return "hourglass"
        case .earlyEstimate: return "clock.arrow.circlepath"
        case .personalized: return "checkmark.circle.fill"
        }
    }

    private var personalizationTint: Color {
        switch scorer.personalizationStatus {
        case .buildingProfile: return .white.opacity(0.8)
        case .earlyEstimate: return .cyan
        case .personalized: return vitalityWhoopGreen
        }
    }

    private var dataMaturityDescription: String {
        let days = scorer.availableDays
        let target = VitalityScorer.minimumDaysRequired

        if scorer.personalizationStatus == .buildingProfile {
            return "\(days) of \(target) days of usable data. Biological age is held at your actual age while we build your profile."
        }
        return "\(days) of \(target) days of usable data. This is an early estimate and will keep personalizing as more data arrives."
    }
}

// MARK: - Orb Metric Chip

private struct OrbMetricChip: View {
    let component: VitalityComponent
    let chronologicalAge: Int
    let healthyTint: Color
    let cautionTint: Color
    let riskTint: Color

    private var metricDelta: Int { component.delta(chronologicalAge: chronologicalAge) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(component.metric.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(valueText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(deltaText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(deltaTint)
                    .monospacedDigit()
            }

            chipGauge
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 176)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var chipGauge: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let markerX = max(0, min(width - 6, width * gaugePosition))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [riskTint.opacity(0.8), cautionTint.opacity(0.8), healthyTint.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 4)

                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 6, height: 6)
                    .offset(x: markerX, y: -1)
            }
        }
        .frame(height: 7)
    }

    private var gaugePosition: Double {
        let median = component.populationMedian
        let current = component.currentValue
        let higherIsBetter = component.healthMetric?.higherIsBetter ?? true
        let range = max(0.0001, median * 0.6)
        let raw = (current - (median - range)) / (2 * range)
        let normalized = max(0, min(1, raw))
        return higherIsBetter ? normalized : (1 - normalized)
    }

    private var valueText: String {
        let raw: String
        if let metric = component.healthMetric {
            raw = metric.formatValue(component.currentValue)
        } else if component.currentValue == component.currentValue.rounded() {
            raw = "\(Int(component.currentValue))"
        } else {
            raw = String(format: "%.1f", component.currentValue)
        }

        if component.unit.isEmpty { return raw }
        return "\(raw) \(component.unit)"
    }

    private var deltaText: String {
        if metricDelta < 0 { return "\(abs(metricDelta)).0y" }
        if metricDelta > 0 { return "+\(metricDelta).0y" }
        return "0.0y"
    }

    private var deltaTint: Color {
        if metricDelta <= 0 { return healthyTint }
        if metricDelta <= 2 { return cautionTint }
        return riskTint
    }
}

// MARK: - Organic Orb

private struct OrganicParticleOrbView: View {
    let phase: CGFloat
    let tint: Color

    private static let particles: [ParticleSeed] = makeParticles()

    var body: some View {
        let blobShape = OrganicBlobShape(phase: phase)

        return OrbParticleCanvas(tint: tint, particles: Self.particles)
        .clipShape(OrganicBlobShape(phase: phase))
        .overlay(
            blobShape
                .stroke(tint.opacity(0.78), lineWidth: 1.4)
        )
        .overlay(
            blobShape
                .stroke(tint.opacity(0.3), lineWidth: 10)
                .blur(radius: 8)
                .blendMode(BlendMode.screen)
        )
        .shadow(color: tint.opacity(0.24), radius: 10, y: 4)
    }

    private static func makeParticles() -> [ParticleSeed] {
        (0..<260).map { i in
            let index = Double(i)
            let h1 = vfract(sin(index * 127.1 + 14.7) * 43758.5453)
            let h2 = vfract(sin(index * 269.5 + 41.3) * 43758.5453)
            let h3 = vfract(sin(index * 419.2 + 29.9) * 43758.5453)
            let h4 = vfract(sin(index * 631.3 + 91.1) * 43758.5453)
            let h5 = vfract(sin(index * 853.7 + 57.2) * 43758.5453)

            let angle = h1 * .pi * 2
            let radius = pow(h2, 0.62) * 0.47
            let x = 0.5 + cos(angle) * radius
            let y = 0.5 + sin(angle) * radius

            let size: CGFloat = h3 < 0.08 ? CGFloat(3.6 + h4 * 2.2) : CGFloat(0.9 + h4 * 1.6)
            let speed = 0.06 + h5 * 0.09
            let phase = h4 * .pi * 2
            let drift = 3.5 + h3 * 6.0
            let alpha = 0.34 + h2 * 0.62

            return ParticleSeed(
                x: CGFloat(x),
                y: CGFloat(y),
                size: size,
                speed: speed,
                phase: phase,
                drift: drift,
                tintMix: h1,
                alpha: alpha
            )
        }
    }
}

private struct OrbParticleCanvas: View {
    let tint: Color
    let particles: [ParticleSeed]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            Canvas { context, size in
                drawBackground(context: context, size: size)
                drawParticles(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let gradient = Gradient(colors: [
            Color(red: 0.02, green: 0.07, blue: 0.09),
            Color(red: 0.02, green: 0.11, blue: 0.13),
            tint.opacity(0.22)
        ])

        context.fill(
            Path(rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                startRadius: 10,
                endRadius: max(size.width, size.height) * 0.66
            )
        )
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for particle in particles {
            let x = size.width * particle.x
                + CGFloat(cos(time * particle.speed + particle.phase) * particle.drift)
            let y = size.height * particle.y
                + CGFloat(sin(time * particle.speed * 0.82 + particle.phase) * particle.drift)

            let dotRect = CGRect(
                x: x - particle.size / 2,
                y: y - particle.size / 2,
                width: particle.size,
                height: particle.size
            )

            let color: Color = particle.tintMix < 0.44
                ? tint.opacity(particle.alpha)
                : Color.white.opacity(particle.alpha)

            context.fill(Path(ellipseIn: dotRect), with: .color(color))

            if particle.size > 3.0 {
                let glow = particle.size * 2.6
                let glowRect = CGRect(
                    x: x - glow / 2,
                    y: y - glow / 2,
                    width: glow,
                    height: glow
                )
                context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.12)))
            }
        }
    }
}

private struct ParticleSeed {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: Double
    let phase: Double
    let drift: Double
    let tintMix: Double
    let alpha: Double
}

private struct OrganicBlobShape: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.43
        let steps = 160

        var path = Path()
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps) * .pi * 2
            let wobbleA = 0.075 * sin(t * 3 + phase)
            let wobbleB = 0.045 * sin(t * 5 + phase * 1.7)
            let wobbleC = 0.03 * cos(t * 2 - phase * 0.9)
            let radius = baseRadius * (1 + wobbleA + wobbleB + wobbleC)

            let point = CGPoint(
                x: center.x + cos(t) * radius,
                y: center.y + sin(t) * radius
            )

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private func vfract(_ value: Double) -> Double {
    value - value.rounded(.down)
}
