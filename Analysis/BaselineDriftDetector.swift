import Foundation

/// Detects when a metric's personal baseline has drifted significantly over time.
/// Uses stored daily analysis snapshots to track baseline evolution.
struct BaselineDriftDetector {

    /// Generate insights from baseline history for all metrics
    static func generateInsights(
        currentBaselines: [HealthMetric: UserBaseline],
        baselineHistory: [HealthMetric: [(date: Date, baseline: UserBaseline)]]
    ) -> [Insight] {
        var insights: [Insight] = []

        for (metric, history) in baselineHistory {
            guard let current = currentBaselines[metric] else { continue }
            if let insight = detectDrift(metric: metric, current: current, history: history) {
                insights.append(insight)
            }
        }

        return insights
    }

    // MARK: - Drift Detection

    private static func detectDrift(
        metric: HealthMetric,
        current: UserBaseline,
        history: [(date: Date, baseline: UserBaseline)]
    ) -> Insight? {
        // Need at least 30 days of baseline history
        guard history.count >= 30 else { return nil }

        // Compare current baseline to baseline 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let olderBaselines = history.filter { $0.date <= thirtyDaysAgo }

        guard let oldBaseline = olderBaselines.last else { return nil }
        guard abs(oldBaseline.baseline.mean) > 0.001 else { return nil }

        let driftPercent = ((current.mean - oldBaseline.baseline.mean) / abs(oldBaseline.baseline.mean)) * 100

        // Only report significant baseline drift (>8%)
        guard abs(driftPercent) > 8 else { return nil }

        let improving: Bool
        if metric.higherIsBetter {
            improving = driftPercent > 0
        } else {
            improving = driftPercent < 0
        }

        let absDrift = String(format: "%.1f", abs(driftPercent))
        let direction = driftPercent > 0 ? "increased" : "decreased"
        let oldFormatted = metric.formatValue(oldBaseline.baseline.mean)
        let newFormatted = metric.formatValue(current.mean)

        return Insight(
            metric: metric,
            title: "\(metric.displayName) Baseline Shifted",
            summary: "Your \(metric.displayName.lowercased()) baseline has \(direction) \(absDrift)% over the last 30 days (\(oldFormatted) → \(newFormatted) \(metric.unit)).",
            recommendation: improving
                ? "Your new normal is better than before. This baseline shift reflects genuine improvement in your \(metric.displayName.lowercased())."
                : "Your \(metric.displayName.lowercased()) has been gradually worsening. Small daily changes compound — focus on reversing this trend now.",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: current.mean,
            baselineValue: oldBaseline.baseline.mean,
            deviationPercent: driftPercent,
            category: .baselineDrift
        )
    }
}
