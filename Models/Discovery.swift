import SwiftUI

/// A single personalized health discovery revealed during the Day 0 experience.
struct Discovery: Identifiable {
    let id: UUID
    let headline: String
    let detail: String
    let evidence: String
    let metrics: [HealthMetric]
    let type: DiscoveryType
    let impactScore: Double
    let icon: String
    let accentColor: Color

    init(
        id: UUID = UUID(),
        headline: String,
        detail: String,
        evidence: String,
        metrics: [HealthMetric],
        type: DiscoveryType,
        impactScore: Double,
        icon: String,
        accentColor: Color
    ) {
        self.id = id
        self.headline = headline
        self.detail = detail
        self.evidence = evidence
        self.metrics = metrics
        self.type = type
        self.impactScore = impactScore
        self.icon = icon
        self.accentColor = accentColor
    }
}

enum DiscoveryType: String {
    case conditionalImpact
    case thresholdEffect
    case dayOfWeekPattern
    case longTermTrend
    case personalExtreme
    case compoundPattern
}
