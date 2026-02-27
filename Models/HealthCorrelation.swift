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
    let effectPercentDiff: Double    // Effect size as % difference between above/below baseline groups
    let isPositive: Bool             // direction of relationship
    let dayOffset: Int               // 0 = same day, 1 = next day
    /// Average of metricB when metricA is above its baseline
    let avgBAbove: Double
    /// Average of metricB when metricA is below its baseline
    let avgBBelow: Double

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
        effectPercentDiff: Double = 0,
        isPositive: Bool,
        dayOffset: Int,
        avgBAbove: Double = 0,
        avgBBelow: Double = 0
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
        self.effectPercentDiff = effectPercentDiff
        self.isPositive = isPositive
        self.dayOffset = dayOffset
        self.avgBAbove = avgBAbove
        self.avgBBelow = avgBBelow
    }
}
