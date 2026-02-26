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

        // Compare across multiple time horizons — pick the most significant
        let calendar = Calendar.current
        let now = Date()
        let comparisons: [(days: Int, label: String)] = [
            (30, "month"),
            (90, "3 months"),
            (180, "6 months"),
            (365, "year")
        ]

        var bestDrift: (percent: Double, label: String, oldMean: Double)? = nil

        for (days, label) in comparisons {
            let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let olderBaselines = history.filter { $0.date <= cutoff }
            guard let oldBaseline = olderBaselines.last,
                  abs(oldBaseline.baseline.mean) > 0.001 else { continue }

            let drift = ((current.mean - oldBaseline.baseline.mean) / abs(oldBaseline.baseline.mean)) * 100

            // Longer periods need larger drift to be significant
            let threshold: Double = days <= 30 ? 8 : (days <= 90 ? 6 : 5)
            guard abs(drift) > threshold else { continue }

            // Prefer longer-term drift (more meaningful) if significant
            if bestDrift == nil || abs(drift) > abs(bestDrift!.percent) * 0.8 {
                bestDrift = (drift, label, oldBaseline.baseline.mean)
            }
        }

        guard let drift = bestDrift else { return nil }

        let improving: Bool
        if metric.higherIsBetter {
            improving = drift.percent > 0
        } else {
            improving = drift.percent < 0
        }

        let absDrift = String(format: "%.1f", abs(drift.percent))
        let direction = drift.percent > 0 ? "increased" : "decreased"
        let oldFormatted = metric.formatValue(drift.oldMean)
        let newFormatted = metric.formatValue(current.mean)

        return Insight(
            metric: metric,
            title: "\(metric.displayName) Baseline Shifted Over \(drift.label.capitalized)",
            summary: "Your \(metric.displayName.lowercased()) baseline has \(direction) \(absDrift)% over the last \(drift.label) (\(oldFormatted) → \(newFormatted) \(metric.unit)).",
            recommendation: improving
                ? "Your new normal is better than before. This baseline shift over \(drift.label) reflects genuine long-term improvement."
                : "Your \(metric.displayName.lowercased()) has been gradually worsening over \(drift.label). Small daily changes compound — focus on reversing this trend.",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: current.mean,
            baselineValue: drift.oldMean,
            deviationPercent: drift.percent,
            category: .baselineDrift
        )
    }
}
