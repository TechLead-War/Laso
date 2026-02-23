import Foundation

/// A discovered correlation between two health metrics with cause-effect context
struct HealthCorrelation: Identifiable {
    let id: UUID
    let metricA: HealthMetric
    let metricB: HealthMetric
    let correlation: Double          // Pearson r (-1 to 1)
    let sampleCount: Int
    let strengthLabel: String        // "Strong" / "Moderate" / "Mild"
    let causeLabel: String           // "More deep sleep"
    let effectLabel: String          // "Higher HRV next day"
    let effectSummary: String        // "When deep sleep is above average, HRV is 18% higher"
    let isPositive: Bool             // direction of relationship
    let dayOffset: Int               // 0 = same day, 1 = next day

    init(
        id: UUID = UUID(),
        metricA: HealthMetric,
        metricB: HealthMetric,
        correlation: Double,
        sampleCount: Int,
        strengthLabel: String,
        causeLabel: String,
        effectLabel: String,
        effectSummary: String,
        isPositive: Bool,
        dayOffset: Int
    ) {
        self.id = id
        self.metricA = metricA
        self.metricB = metricB
        self.correlation = correlation
        self.sampleCount = sampleCount
        self.strengthLabel = strengthLabel
        self.causeLabel = causeLabel
        self.effectLabel = effectLabel
        self.effectSummary = effectSummary
        self.isPositive = isPositive
        self.dayOffset = dayOffset
    }
}
