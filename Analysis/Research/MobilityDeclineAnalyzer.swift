import Foundation

/// Research: Google Research (2025) + npj Parkinson's Disease (2025)
/// Finding: Simultaneous deterioration of multiple gait metrics (walking speed,
/// double support time, step length, asymmetry) over months predicts
/// neurodegenerative decline years before clinical diagnosis.
/// Parkinson's detection: 88-98% sensitivity from gait data alone.
///
/// Implementation: Computes 6-month rolling trends across all mobility metrics.
/// Flags when 3+ metrics deteriorate concurrently.
struct MobilityDeclineAnalyzer {

    // MARK: - Mobility Metrics & Expected Directions

    /// Each metric with the direction that indicates decline
    private struct MobilityIndicator {
        let metric: HealthMetric
        let declineDirection: DeclineDirection
        let label: String

        enum DeclineDirection {
            case decreasing // Walking speed, step length — lower is worse
            case increasing // Double support %, asymmetry — higher is worse
        }
    }

    private static let indicators: [MobilityIndicator] = [
        .init(metric: .walkingSpeed, declineDirection: .decreasing, label: "walking speed"),
        .init(metric: .walkingStepLength, declineDirection: .decreasing, label: "step length"),
        .init(metric: .walkingDoubleSupportPercentage, declineDirection: .increasing, label: "double support time"),
        .init(metric: .walkingAsymmetry, declineDirection: .increasing, label: "gait asymmetry"),
        .init(metric: .stairAscentSpeed, declineDirection: .decreasing, label: "stair climbing speed"),
        .init(metric: .stairDescentSpeed, declineDirection: .decreasing, label: "stair descent speed"),
        .init(metric: .walkingSteadiness, declineDirection: .decreasing, label: "walking steadiness"),
    ]

    private static let minMonthsRequired = 3
    private static let minSamplesPerMetric = 15
    private static let significantChangeThreshold = 0.08 // 8% change

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        // Evaluate each mobility metric for decline
        var decliningMetrics: [(indicator: MobilityIndicator, changePercent: Double, samples: Int)] = []
        var improvingMetrics: [(indicator: MobilityIndicator, changePercent: Double)] = []
        var stableMetrics: [MobilityIndicator] = []

        for indicator in indicators {
            guard let series = context.timeSeries[indicator.metric] else { continue }
            let samples = series.samples(lastDays: 180) // 6 months
            guard samples.count >= minSamplesPerMetric else { continue }

            let sorted = samples.sorted { $0.date < $1.date }
            let firstQuarter = Array(sorted.prefix(sorted.count / 3)).map(\.value).mean
            let lastQuarter = Array(sorted.suffix(sorted.count / 3)).map(\.value).mean

            guard firstQuarter > 0 else { continue }

            let changePercent = (lastQuarter - firstQuarter) / firstQuarter

            // Determine if this represents decline based on metric direction
            let isDeclining: Bool
            switch indicator.declineDirection {
            case .decreasing:
                isDeclining = changePercent < -significantChangeThreshold
            case .increasing:
                isDeclining = changePercent > significantChangeThreshold
            }

            let isImproving: Bool
            switch indicator.declineDirection {
            case .decreasing:
                isImproving = changePercent > significantChangeThreshold
            case .increasing:
                isImproving = changePercent < -significantChangeThreshold
            }

            if isDeclining {
                decliningMetrics.append((indicator, abs(changePercent) * 100, samples.count))
            } else if isImproving {
                improvingMetrics.append((indicator, abs(changePercent) * 100))
            } else {
                stableMetrics.append(indicator)
            }
        }

        let totalEvaluated = decliningMetrics.count + improvingMetrics.count + stableMetrics.count
        guard totalEvaluated >= 3 else { return [] }

        // Critical: 3+ metrics declining simultaneously
        if decliningMetrics.count >= 3 {
            let worstMetrics = decliningMetrics
                .sorted { $0.changePercent > $1.changePercent }
                .prefix(4)
            let metricList = worstMetrics
                .map { "\($0.indicator.label) (\(String(format: "%.0f", $0.changePercent))%)" }
                .joined(separator: ", ")

            insights.append(InsightFactory.make(
                metric: decliningMetrics.first!.indicator.metric,
                title: "Multi-Metric Mobility Decline",
                summary: "\(decliningMetrics.count) of \(totalEvaluated) mobility metrics are declining over the past 6 months: \(metricList). Concurrent deterioration across multiple gait parameters warrants attention.",
                recommendation: "Research shows simultaneous decline in walking speed, step length, and gait symmetry is a sensitive early marker of neuromuscular or neurological changes — detectable years before clinical symptoms in studies with 88-98% sensitivity for Parkinson's disease.",
                severity: decliningMetrics.count >= 4 ? .warning : .info,
                trend: .declining,
                currentValue: Double(decliningMetrics.count),
                baselineValue: 0,
                deviationPercent: Double(decliningMetrics.count) / Double(totalEvaluated) * 100,
                category: .clinicalTrajectory,
                directive: decliningMetrics.count >= 4 ? .seekMedical : .informational,
                relatedMetrics: decliningMetrics.map(\.indicator.metric),
                context: InsightContext(
                    confidenceLevel: min(Double(totalEvaluated) / 5.0, 1.0),
                    dataPointCount: decliningMetrics.map(\.samples).reduce(0, +)
                )
            ))
        }

        // Single critical metric: walking speed declining (strongest individual predictor)
        if let speedDecline = decliningMetrics.first(where: { $0.indicator.metric == .walkingSpeed }),
           speedDecline.changePercent >= 10,
           decliningMetrics.count < 3 { // Don't double-report if already in multi-metric
            insights.append(InsightFactory.make(
                metric: .walkingSpeed,
                title: "Walking Speed Declining",
                summary: "Your walking speed has decreased \(String(format: "%.0f", speedDecline.changePercent))% over the past 6 months. Walking speed is called the 'sixth vital sign' — it's one of the strongest predictors of functional health and longevity.",
                recommendation: "In population studies, each 0.1 m/s decrease in walking speed is associated with measurably higher mortality risk. Your \(String(format: "%.0f", speedDecline.changePercent))% decline across \(speedDecline.samples) measurements is worth monitoring.",
                severity: speedDecline.changePercent >= 15 ? .warning : .info,
                trend: .declining,
                currentValue: 100 - speedDecline.changePercent,
                baselineValue: 100,
                deviationPercent: -speedDecline.changePercent,
                category: .clinicalTrajectory,
                directive: .increaseActivity,
                relatedMetrics: [.walkingSpeed, .walkingStepLength, .walkingDoubleSupportPercentage]
            ))
        }

        // Growing asymmetry (early neurological signal)
        if let asymDecline = decliningMetrics.first(where: { $0.indicator.metric == .walkingAsymmetry }),
           asymDecline.changePercent >= 15 {
            insights.append(InsightFactory.make(
                metric: .walkingAsymmetry,
                title: "Gait Asymmetry Increasing",
                summary: "Your walking asymmetry has increased \(String(format: "%.0f", asymDecline.changePercent))% over 6 months. Growing left-right imbalance in gait is an early neurological and musculoskeletal indicator.",
                recommendation: "Increasing gait asymmetry — the difference between left and right step patterns — can reflect musculoskeletal compensation, joint issues, or early neurological changes. A \(String(format: "%.0f", asymDecline.changePercent))% increase warrants investigation.",
                severity: asymDecline.changePercent >= 25 ? .warning : .info,
                trend: .declining,
                currentValue: asymDecline.changePercent,
                baselineValue: 0,
                deviationPercent: asymDecline.changePercent,
                category: .clinicalTrajectory,
                directive: asymDecline.changePercent >= 25 ? .seekMedical : .informational,
                relatedMetrics: [.walkingAsymmetry, .walkingSpeed, .walkingStepLength]
            ))
        }

        // Positive: All mobility metrics stable or improving
        if decliningMetrics.isEmpty && totalEvaluated >= 3 {
            let improvingList = improvingMetrics.isEmpty ? ""
                : " Improving: \(improvingMetrics.map { "\($0.indicator.label) (+\(String(format: "%.0f", $0.changePercent))%)" }.joined(separator: ", "))."

            insights.append(InsightFactory.observation(
                metric: .walkingSpeed,
                title: "Mobility Profile Stable",
                summary: "All \(totalEvaluated) tracked mobility metrics are stable or improving over the past 6 months. This indicates preserved neuromuscular function.\(improvingList)",
                recommendation: "Stable or improving gait metrics across \(totalEvaluated) parameters (walking speed, step length, symmetry, steadiness) reflect strong functional health. Research shows these are among the best predictors of healthspan and longevity.",
                currentValue: Double(totalEvaluated),
                baselineValue: Double(totalEvaluated),
                deviationPercent: 0,
                category: .clinicalTrajectory,
                relatedMetrics: indicators.prefix(4).map(\.metric)
            ))
        }

        return insights
    }
}

// MARK: - InsightAnalyzer Conformance

extension MobilityDeclineAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "mobilityDecline" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }
}
