import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Context Compressor

@available(iOS 26, *)
enum ContextCompressor {

    static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps: return "\(Int(value))"
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore: return String(format: "%.1fh", value / 3600)
        case .heartRateVariability: return String(format: "%.0fms", value)
        case .heartRate, .restingHeartRate: return String(format: "%.0f bpm", value)
        case .bodyTemperature, .appleSleepingWristTemperature: return String(format: "%.1f°F", value)
        case .weight: return String(format: "%.1f lbs", value)
        case .vo2Max: return String(format: "%.1f", value)
        case .bloodOxygen: return String(format: "%.0f%%", value * 100)
        case .exerciseMinutes, .mindfulMinutes: return String(format: "%.0f min", value)
        case .activeCalories, .basalCalories, .totalCaloriesIntake: return String(format: "%.0f kcal", value)
        case .waterIntake: return String(format: "%.0f mL", value)
        default:
            if value > 1000 { return String(format: "%.0f", value) }
            if value > 10 { return String(format: "%.1f", value) }
            return String(format: "%.2f", value)
        }
    }

    static func summarizeMetric(_ metric: HealthMetric, series: MetricTimeSeries?, baseline: UserBaseline?) -> String {
        guard let series, let latest = series.samples.last else { return "\(metric.displayName): no data" }
        let val = formatValue(latest.value, metric: metric)
        guard let baseline else { return "\(metric.displayName): \(val) (no baseline yet)" }
        let sigma = baseline.standardDeviation > 0 ? (latest.value - baseline.mean) / baseline.standardDeviation : 0
        return "\(metric.displayName): \(val) (baseline \(formatValue(baseline.mean, metric: metric)), \(String(format: "%+.1fσ", sigma)))"
    }

    static func summarizeTrend(_ trend: TrendAnalyzer.TrendResult, metric: HealthMetric) -> String {
        let dir: String
        switch trend.direction {
        case .improving: dir = "improving"
        case .declining: dir = "declining"
        case .stable: dir = "stable"
        }
        return "\(metric.displayName): \(dir), \(String(format: "%+.1f%%", trend.weekOverWeekChange)) week-over-week, 7d avg \(formatValue(trend.movingAverage7d, metric: metric))"
    }

    static func summarizeCorrelation(_ corr: MLCorrelation) -> String {
        var s = "\(corr.metricA.displayName) ↔ \(corr.metricB.displayName): r=\(String(format: "%.2f", corr.pearsonR))"
        if corr.grangerCausal { s += ", Granger-causal (lag \(corr.grangerOptimalLag)d)" }
        return s
    }

    static func buildHealthSnapshot(context: HealthDataQueryEngine.QueryContext) -> String {
        var lines: [String] = []
        lines.append("Health Score: \(context.overallScore)/100")
        if let state = context.currentHealthState {
            lines.append("Body State: \(state.label) (day \(state.daysInState))")
        }
        let priorityMetrics: [HealthMetric] = [.restingHeartRate, .heartRateVariability, .sleepDuration, .steps, .vo2Max]
        for metric in priorityMetrics {
            let summary = summarizeMetric(metric, series: context.timeSeries[metric], baseline: context.baselines[metric])
            if !summary.contains("no data") { lines.append(summary) }
        }
        if let report = context.healthSignalReport {
            let urgent = report.urgentSignals.prefix(2)
            if !urgent.isEmpty {
                lines.append("Active Risks: \(urgent.map { "\($0.signalName): \($0.riskLevel)" }.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Tool Wrapper

/// Wraps QueryContext for tool use. Marked @unchecked Sendable because
/// QueryContext is a value type with immutable fields, used read-only.
@available(iOS 26, *)
final class ToolContext: @unchecked Sendable {
    let ctx: HealthDataQueryEngine.QueryContext
    init(_ ctx: HealthDataQueryEngine.QueryContext) { self.ctx = ctx }
}

// MARK: - Tools

@available(iOS 26, *)
struct MetricDetailTool: Tool {
    let tc: ToolContext
    let name = "metricDetail"
    let description = "Get the current value, 7-day average, baseline, and deviation for a specific health metric."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue, e.g. 'heartRateVariability', 'restingHeartRate', 'sleepDuration', 'steps'")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        guard let metric = HealthMetric(rawValue: arguments.metricName) else {
            return "Unknown metric '\(arguments.metricName)'. Available: \(context.timeSeries.keys.map(\.rawValue).sorted().joined(separator: ", "))"
        }
        guard let series = context.timeSeries[metric], let latest = series.samples.last else {
            return "\(metric.displayName): no data available."
        }
        var lines: [String] = []
        lines.append("Latest: \(ContextCompressor.formatValue(latest.value, metric: metric)) (\(metric.unit))")
        let recent7 = series.samples.suffix(7)
        if recent7.count > 1 {
            let avg = recent7.mean(of: \.value)
            lines.append("7-day avg: \(ContextCompressor.formatValue(avg, metric: metric))")
        }
        if let baseline = context.baselines[metric] {
            let sigma = baseline.standardDeviation > 0 ? (latest.value - baseline.mean) / baseline.standardDeviation : 0
            lines.append("Baseline: \(ContextCompressor.formatValue(baseline.mean, metric: metric))")
            lines.append("Deviation: \(String(format: "%+.1fσ", sigma)) (\(abs(sigma) < 1 ? "normal" : abs(sigma) < 2 ? "notable" : "significant"))")
        }
        lines.append("Higher is \(metric.higherIsBetter ? "better" : "worse") for this metric")
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct TrendsTool: Tool {
    let tc: ToolContext
    let name = "trends"
    let description = "Get the trend direction, week-over-week change, and moving averages for a health metric."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        guard let metric = HealthMetric(rawValue: arguments.metricName), let trend = context.trends[metric] else {
            return "No trend data for '\(arguments.metricName)'."
        }
        var lines: [String] = []
        lines.append(ContextCompressor.summarizeTrend(trend, metric: metric))
        lines.append("30d avg: \(ContextCompressor.formatValue(trend.movingAverage30d, metric: metric))")
        if trend.movingAverage90d > 0 {
            lines.append("90d avg: \(ContextCompressor.formatValue(trend.movingAverage90d, metric: metric))")
        }
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct CorrelationsTool: Tool {
    let tc: ToolContext
    let name = "correlations"
    let description = "Find correlations between a health metric and other metrics."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        guard let metric = HealthMetric(rawValue: arguments.metricName) else { return "Unknown metric." }
        let relevant = context.correlations
            .filter { $0.metricA == metric || $0.metricB == metric }
            .filter { $0.isSignificant }
            .sorted(by: { abs($0.pearsonR) > abs($1.pearsonR) })
            .prefix(3)
        if relevant.isEmpty { return "No significant correlations found for \(metric.displayName)." }
        return relevant.map { ContextCompressor.summarizeCorrelation($0) }.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct ForecastTool: Tool {
    let tc: ToolContext
    let name = "forecasts"
    let description = "Get the predicted value and confidence interval for a metric over the next 1, 3, or 7 days."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        guard let metric = HealthMetric(rawValue: arguments.metricName), let forecast = context.forecasts[metric] else {
            return "No forecast available for '\(arguments.metricName)'."
        }
        return forecast.horizons.map { h in
            let val = ContextCompressor.formatValue(h.value, metric: metric)
            let lo = ContextCompressor.formatValue(h.ciLower, metric: metric)
            let hi = ContextCompressor.formatValue(h.ciUpper, metric: metric)
            return "\(h.horizon)-day: \(val) (range \(lo) – \(hi))"
        }.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct RiskReportTool: Tool {
    let tc: ToolContext
    let name = "riskReport"
    let description = "Get the current health risk assessment: fatigue, burnout, overtraining, insomnia, immune, inactivity signals."

    @Generable struct Arguments {
        @Guide(description: "Set to true to fetch the risk report")
        var fetch: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        var lines: [String] = []
        if let report = context.healthSignalReport {
            let signals: [(String, String, String)] = [
                (report.fatigueScore.signalName, "\(report.fatigueScore.riskLevel)", report.fatigueScore.explanation),
                (report.burnoutRisk.signalName, "\(report.burnoutRisk.riskLevel)", report.burnoutRisk.explanation),
                (report.overtrainingRisk.signalName, "\(report.overtrainingRisk.riskLevel)", report.overtrainingRisk.explanation),
                (report.insomniaRisk.signalName, "\(report.insomniaRisk.riskLevel)", report.insomniaRisk.explanation),
                (report.immuneRisk.signalName, "\(report.immuneRisk.riskLevel)", report.immuneRisk.explanation),
                (report.inactivityAlert.signalName, "\(report.inactivityAlert.riskLevel)", report.inactivityAlert.explanation),
            ]
            for (name, level, explanation) in signals { lines.append("\(name): \(level). \(explanation)") }
        } else {
            lines.append("No health signal report available yet.")
        }
        if let prediction = context.tomorrowRiskPrediction {
            lines.append("Tomorrow's risk: \(String(format: "%.0f%%", prediction.probability * 100)) chance of \(prediction.target)")
            let factors = prediction.topFactors.prefix(3).map { "\($0.metric.displayName) (\(String(format: "%+.2f", $0.contribution)))" }
            if !factors.isEmpty { lines.append("Top factors: \(factors.joined(separator: ", "))") }
        }
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct PatternsTool: Tool {
    let tc: ToolContext
    let name = "patterns"
    let description = "Find recurring patterns (weekly cycles, monthly rhythms) in a health metric."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue, or 'all'")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        let patterns: [DiscoveredPattern]
        if arguments.metricName == "all" {
            patterns = Array(context.discoveredPatterns.prefix(5))
        } else if let metric = HealthMetric(rawValue: arguments.metricName) {
            patterns = context.discoveredPatterns.filter { $0.metric == metric }
        } else {
            return "Unknown metric '\(arguments.metricName)'."
        }
        if patterns.isEmpty { return "No patterns discovered yet." }
        return patterns.map { p in
            "\(p.metric.displayName): \(p.patternType) pattern, \(String(format: "%.0f", p.periodDays))-day cycle, strength \(String(format: "%.0f%%", p.strength * 100))"
        }.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct CircadianTool: Tool {
    let tc: ToolContext
    let name = "circadian"
    let description = "Get the user's chronotype, peak activity times, and optimal timing recommendations."

    @Generable struct Arguments {
        @Guide(description: "Set to true to fetch circadian data")
        var fetch: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        var lines: [String] = []
        if let profile = context.circadianProfile {
            lines.append("Chronotype: \(profile.chronotype)")
            lines.append("Activity peak: \(String(format: "%.0f", profile.activityAcrophaseHour)):00")
            lines.append("HR nadir: \(String(format: "%.0f", profile.hrNadirHour)):00")
            if let hrvPeak = profile.hrvAcrophaseHour {
                lines.append("HRV peak: \(String(format: "%.0f", hrvPeak)):00")
            }
        } else { lines.append("No circadian profile computed yet.") }
        for rec in context.timingRecommendations.prefix(3) {
            lines.append("\(rec.activity): \(rec.optimalWindowDescription). \(rec.reasoning)")
        }
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct OptimizationTool: Tool {
    let tc: ToolContext
    let name = "optimization"
    let description = "Get the user's ideal day targets and which metrics most impact their health score."

    @Generable struct Arguments {
        @Guide(description: "Set to true to fetch optimization data")
        var fetch: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        var lines: [String] = []
        if let ideal = context.idealDay {
            lines.append("Ideal day targets:")
            for target in ideal.targets.prefix(5) {
                lines.append("  \(target.metric.displayName): \(ContextCompressor.formatValue(target.targetValue, metric: target.metric))")
            }
        }
        if !context.scoreSensitivities.isEmpty {
            lines.append("Score impact (biggest levers):")
            for sens in context.scoreSensitivities.prefix(3) {
                lines.append("  \(sens.metric.displayName): \(String(format: "%+.1f", sens.slope)) pts per σ change")
            }
        }
        if lines.isEmpty { lines.append("Optimization profile not yet computed.") }
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct CausalTool: Tool {
    let tc: ToolContext
    let name = "causal"
    let description = "Find causal relationships: what metrics drive changes in another metric, with time lags."

    @Generable struct Arguments {
        @Guide(description: "The health metric rawValue")
        var metricName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        guard let metric = HealthMetric(rawValue: arguments.metricName) else { return "Unknown metric." }
        let causal = context.correlations
            .filter { ($0.metricA == metric || $0.metricB == metric) && $0.grangerCausal }
            .sorted(by: { $0.grangerEffectSize > $1.grangerEffectSize })
            .prefix(3)
        var lines: [String] = []
        if causal.isEmpty {
            lines.append("No Granger-causal relationships found for \(metric.displayName).")
        } else {
            for c in causal {
                let other = c.metricA == metric ? c.metricB : c.metricA
                let dir = c.metricA == metric ? "drives" : "driven by"
                lines.append("\(metric.displayName) \(dir) \(other.displayName) (lag \(c.grangerOptimalLag)d, effect \(String(format: "%.2f", c.grangerEffectSize)))")
            }
        }
        let sequences = context.temporalSequences.filter { seq in seq.steps.contains { $0.metric == metric } }.prefix(2)
        for seq in sequences {
            let chain = seq.steps.map { "\($0.metric.displayName)(\($0.condition))" }.joined(separator: " → ")
            lines.append("Sequence: \(chain)")
        }
        return lines.joined(separator: "\n")
    }
}

@available(iOS 26, *)
struct ScoreBreakdownTool: Tool {
    let tc: ToolContext
    let name = "scoreBreakdown"
    let description = "Break down the overall health score: which metrics are boosting it and which are dragging it down."

    @Generable struct Arguments {
        @Guide(description: "Set to true to fetch score breakdown")
        var fetch: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let context = tc.ctx
        var lines: [String] = []
        lines.append("Overall Score: \(context.overallScore)/100")
        if !context.scoreSensitivities.isEmpty {
            let sorted = context.scoreSensitivities.sorted(by: { $0.slope > $1.slope })
            let boosters = sorted.filter { (sens: PersonalOptimizer.SensitivityResult) -> Bool in
                guard let baseline = context.baselines[sens.metric],
                      let latest = context.timeSeries[sens.metric]?.samples.last else { return false }
                let sigma = baseline.standardDeviation > 0 ? (latest.value - baseline.mean) / baseline.standardDeviation : 0
                return (sens.metric.higherIsBetter && sigma > 0.3) || (!sens.metric.higherIsBetter && sigma < -0.3)
            }.prefix(2)
            let draggers = sorted.filter { (sens: PersonalOptimizer.SensitivityResult) -> Bool in
                guard let baseline = context.baselines[sens.metric],
                      let latest = context.timeSeries[sens.metric]?.samples.last else { return false }
                let sigma = baseline.standardDeviation > 0 ? (latest.value - baseline.mean) / baseline.standardDeviation : 0
                return (sens.metric.higherIsBetter && sigma < -0.3) || (!sens.metric.higherIsBetter && sigma > 0.3)
            }.prefix(2)
            if !boosters.isEmpty { lines.append("Boosting: \(boosters.map { $0.metric.displayName }.joined(separator: ", "))") }
            if !draggers.isEmpty { lines.append("Dragging: \(draggers.map { $0.metric.displayName }.joined(separator: ", "))") }
        }
        if let state = context.currentHealthState { lines.append("Current state: \(state.label)") }
        return lines.joined(separator: "\n")
    }
}

#endif
