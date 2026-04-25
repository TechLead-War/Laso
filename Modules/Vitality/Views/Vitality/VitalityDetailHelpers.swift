import SwiftUI

let vitalityWhoopGreen = AppColour.vitalityWhoopGreen
let vitalityPaceYellow = AppColour.vitalityPaceYellow
let vitalityPaceRed = AppColour.vitalityPaceRed

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
    if delta < 0 { return AppColour.vitalityDeltaNegative }
    if delta == 0 { return AppColour.info }
    if delta <= 3 { return AppColour.warning }
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
    // Pass 8 Y: walking speed is the only Vitality component whose canonical
    // unit (km/h) does not match the US imperial unit (mph). Convert
    // value + unit label in lock-step when locale is US/imperial.
    if metric == .walkingSpeed, Locale.current.measurementSystem == .us {
        let m = Measurement(value: value, unit: UnitSpeed.kilometersPerHour)
            .converted(to: .milesPerHour)
        return String(format: "%.1f mph", m.value)
    }

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
            .font(DS.Typography.subheadline)
            .foregroundStyle(.tint)
        Text(title)
            .font(DS.Typography.headline)
    }
    .padding(.horizontal)
}
