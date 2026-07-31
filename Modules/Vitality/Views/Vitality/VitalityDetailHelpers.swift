import SwiftUI

// Computed, not `let`: Swift initializes a global `let` lazily once, so a
// Remote Config colour activation later in the session never repainted these.
var vitalityWhoopGreen: Color { AppColour.vitalityWhoopGreen }
var vitalityPaceYellow: Color { AppColour.vitalityPaceYellow }
var vitalityPaceRed: Color { AppColour.vitalityPaceRed }

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
    // With no pace yet, `paceOfAging` is the 1.0 placeholder. Tinting that green
    // would tell the user their aging is normal on the strength of no evidence.
    guard scorer.hasPaceEstimate else { return AppColour.textSecondary }

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
    guard scorer.hasPaceEstimate else { return "hourglass" }
    switch vitalityPaceState(for: scorer) {
    case .healthy: return "checkmark.circle.fill"
    case .caution: return "exclamationmark.triangle.fill"
    case .risk: return "xmark.octagon.fill"
    }
}

func vitalityPaceStateText(for scorer: VitalityScorer) -> String {
    guard scorer.hasPaceEstimate else { return Copy.Vitality.paceNeedsDays(VitalityScorer.minimumPaceDays) }
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
    case .buildingProfile: return AppColour.textSecondary
    case .earlyEstimate: return AppColour.accent
    case .personalized: return vitalityWhoopGreen
    }
}

func vitalityMetricDeltaLabel(_ component: VitalityComponent, chronologicalAge: Int) -> String {
    // The metric age is clamped at a reference row on either end here, so the
    // year gap is a floor or a ceiling and not a reading. Name the end of the
    // scale instead of a number we cannot support.
    if component.isBeyondYoungestReference { return Copy.Vitality.metricTopOfRange }
    if component.isBelowOldestReference { return Copy.Vitality.metricBelowRange }

    let delta = component.delta(chronologicalAge: chronologicalAge)
    if delta < 0 { return Copy.Vitality.metricYounger(abs(delta)) }
    if delta > 0 { return Copy.Vitality.metricOlder(delta) }
    return Copy.Vitality.onTrack
}

func vitalityFormatMetricValue(_ value: Double, unit: String, metric: HealthMetric?) -> String {
    // Walking speed is the only Vitality component whose canonical
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

/// Marker position on the red-to-green bar. 0 is the oldest reference age, 1 the
/// youngest.
///
/// Driven by the metric age, so the bar and the age label beside it are on one
/// scale. This used to be a ±60% band around the population median, which put a
/// narrow-range metric like sleep efficiency near the middle of the bar while its
/// label read "+10y older", and ranked a metric with a 54 year gap above one with
/// a 16 year gap.
func vitalityMetricGaugePosition(_ component: VitalityComponent) -> Double {
    let youngest = Double(VitalityNorms.youngestReferenceAge)
    let oldest = Double(VitalityNorms.oldestReferenceAge)
    let span = max(1, oldest - youngest)
    return max(0, min(1, (oldest - Double(component.metricAge)) / span))
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
