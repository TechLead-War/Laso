import Foundation

/// Detects when a metric's personal baseline has drifted significantly over time.
/// Uses stored daily analysis snapshots to track baseline evolution.
struct BaselineDriftDetector {

    /// Generate insights from baseline history for all metrics, with optional correlation context
    static func generateInsights(
        currentBaselines: [HealthMetric: UserBaseline],
        baselineHistory: [HealthMetric: [(date: Date, baseline: UserBaseline)]],
        correlations: [HealthCorrelation] = []
    ) -> [Insight] {
        var insights: [Insight] = []

        // Build drift results for all metrics first (to find co-drifting metrics)
        var driftResults: [HealthMetric: (percent: Double, label: String)] = [:]
        for (metric, history) in baselineHistory {
            guard let current = currentBaselines[metric] else { continue }
            if let drift = computeDrift(metric: metric, current: current, history: history) {
                driftResults[metric] = drift
            }
        }

        for (metric, history) in baselineHistory {
            guard let current = currentBaselines[metric] else { continue }
            if let insight = detectDrift(metric: metric, current: current, history: history, driftResults: driftResults, correlations: correlations) {
                insights.append(insight)
            }
        }

        return insights
    }

    /// Compute the drift magnitude without generating an insight (used for co-drift detection)
    private static func computeDrift(
        metric: HealthMetric,
        current: UserBaseline,
        history: [(date: Date, baseline: UserBaseline)]
    ) -> (percent: Double, label: String)? {
        guard history.count >= 30 else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let comparisons: [(days: Int, label: String)] = [
            (30, "month"), (90, "3 months"), (180, "6 months"), (365, "year")
        ]

        var bestDrift: (percent: Double, label: String)? = nil
        for (days, label) in comparisons {
            let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let olderBaselines = history.filter { $0.date <= cutoff }
            guard let oldBaseline = olderBaselines.last,
                  abs(oldBaseline.baseline.mean) > 0.001 else { continue }
            let drift = ((current.mean - oldBaseline.baseline.mean) / abs(oldBaseline.baseline.mean)) * 100
            let threshold: Double = days <= 30 ? 8 : (days <= 90 ? 6 : 5)
            guard abs(drift) > threshold else { continue }
            if bestDrift == nil || abs(drift) > abs(bestDrift!.percent) * 0.8 {
                bestDrift = (drift, label)
            }
        }
        return bestDrift
    }

    // MARK: - Drift Detection

    private static func detectDrift(
        metric: HealthMetric,
        current: UserBaseline,
        history: [(date: Date, baseline: UserBaseline)],
        driftResults: [HealthMetric: (percent: Double, label: String)] = [:],
        correlations: [HealthCorrelation] = []
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

        // Find co-drifting metrics (correlated metrics that also shifted in the same period)
        let coDriftMetrics = driftResults
            .filter { $0.key != metric && abs($0.value.percent) > 5 }
            .sorted { abs($0.value.percent) > abs($1.value.percent) }
            .prefix(2)
        let coDriftNote: String
        if !coDriftMetrics.isEmpty {
            let parts = coDriftMetrics.map { "\($0.key.displayName.lowercased()) \($0.value.percent > 0 ? "+" : "")\(String(format: "%.0f", $0.value.percent))%" }
            coDriftNote = " Over the same period: \(parts.joined(separator: ", ")) also shifted."
        } else {
            coDriftNote = ""
        }

        return Insight(
            metric: metric,
            title: "\(metric.displayName) Baseline Shifted Over \(drift.label.capitalized)",
            summary: "Your \(metric.displayName.lowercased()) baseline has \(direction) \(absDrift)% over the last \(drift.label) (\(oldFormatted) \u{2192} \(newFormatted) \(metric.unit)).\(coDriftNote)",
            recommendation: improving
                ? "\(metric.displayName) baseline shifted \(direction) \(absDrift)% over \(drift.label): \(oldFormatted) \u{2192} \(newFormatted) \(metric.unit)."
                : "\(metric.displayName) baseline shifted \(direction) \(absDrift)% over \(drift.label): \(oldFormatted) \u{2192} \(newFormatted) \(metric.unit).",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: current.mean,
            baselineValue: drift.oldMean,
            deviationPercent: drift.percent,
            category: .baselineDrift
        )
    }
}
