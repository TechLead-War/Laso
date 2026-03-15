import SwiftUI

let vitalityWhoopGreen = Color(red: 0.0, green: 217.0 / 255.0, blue: 176.0 / 255.0) // #00D9B0
let vitalityPaceYellow = Color(red: 0.96, green: 0.77, blue: 0.26) // #F5C542
let vitalityPaceRed = Color(red: 1.0, green: 0.30, blue: 0.31) // #FF4D4F

let vitalityPaceGreenUpperBound = 1.08
let vitalityPaceYellowUpperBound = 1.22

enum VitalityPaceState {
    case healthy
    case caution
    case risk
}

func vitalityPaceState(for scorer: VitalityScorer) -> VitalityPaceState {
    if scorer.paceOfAging <= vitalityPaceGreenUpperBound {
        return .healthy
    }
    if scorer.paceOfAging <= vitalityPaceYellowUpperBound {
        return .caution
    }
    return .risk
}

func vitalityPaceTint(for scorer: VitalityScorer) -> Color {
    // Delta overrides pace: a large positive delta (aging much older) should never show green
    let delta = scorer.delta
    if delta > 5 { return vitalityPaceRed }
    if delta > 2 { return vitalityPaceYellow }

    switch vitalityPaceState(for: scorer) {
    case .healthy: return vitalityWhoopGreen
    case .caution: return vitalityPaceYellow
    case .risk: return vitalityPaceRed
    }
}

func vitalityDeltaColor(for delta: Int) -> Color {
    if delta <= -3 { return vitalityWhoopGreen }
    if delta < 0 { return Color(red: 0.18, green: 0.87, blue: 0.78) }
    if delta == 0 { return .blue }
    if delta <= 3 { return .orange }
    return vitalityPaceRed
}

func vitalityPaceIcon(for scorer: VitalityScorer) -> String {
    switch vitalityPaceState(for: scorer) {
    case .healthy: return "checkmark.circle.fill"
    case .caution: return "exclamationmark.triangle.fill"
    case .risk: return "xmark.octagon.fill"
    }
}

func vitalityPaceStateText(for scorer: VitalityScorer) -> String {
    switch vitalityPaceState(for: scorer) {
    case .healthy: return Copy.Vitality.normalOrSlower
    case .caution: return Copy.Vitality.agingTooQuickly
    case .risk: return Copy.Vitality.agingVeryFast
    }
}

func vitalityPersonalizationIcon(for scorer: VitalityScorer) -> String {
    switch scorer.personalizationStatus {
    case .buildingProfile: return "hourglass"
    case .earlyEstimate: return "clock.arrow.circlepath"
    case .personalized: return "checkmark.circle.fill"
    }
}

func vitalityPersonalizationTint(for scorer: VitalityScorer) -> Color {
    switch scorer.personalizationStatus {
    case .buildingProfile: return .white.opacity(0.8)
    case .earlyEstimate: return .cyan
    case .personalized: return vitalityWhoopGreen
    }
}

func vitalityMetricDeltaLabel(_ delta: Int) -> String {
    if delta < 0 { return Copy.Vitality.metricYounger(abs(delta)) }
    if delta > 0 { return Copy.Vitality.metricOlder(delta) }
    return Copy.Vitality.onTrack
}

func vitalityFormatMetricValue(_ value: Double, unit: String, metric: HealthMetric?) -> String {
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

func vitalityMetricGaugePosition(_ component: VitalityComponent) -> Double {
    let median = component.populationMedian
    let current = component.currentValue
    let higherIsBetter = component.healthMetric?.higherIsBetter ?? true
    let range = max(0.0001, median * 0.6)
    let raw = (current - (median - range)) / (2 * range)
    let normalized = max(0, min(1, raw))
    return higherIsBetter ? normalized : (1 - normalized)
}

func vitalitySectionHeader(icon: String, title: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.subheadline)
            .foregroundStyle(.tint)
        Text(title)
            .font(.headline)
    }
    .padding(.horizontal)
}
