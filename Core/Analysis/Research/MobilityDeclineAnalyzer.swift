import Foundation

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
            case decreasing // Walking speed, step length. lower is worse
            case increasing // Double support %, asymmetry. higher is worse
        }
    }

    private static let indicators: [MobilityIndicator] = [
        .init(metric: .walkingSpeed, declineDirection: .decreasing, label: Copy.Analysis.Research.MobilityDecline.walkingSpeedLabel),
        .init(metric: .walkingStepLength, declineDirection: .decreasing, label: Copy.Analysis.Research.MobilityDecline.stepLengthLabel),
        .init(metric: .walkingDoubleSupportPercentage, declineDirection: .increasing, label: Copy.Analysis.Research.MobilityDecline.doubleSupportLabel),
        .init(metric: .walkingAsymmetry, declineDirection: .increasing, label: Copy.Analysis.Research.MobilityDecline.asymmetryLabel),
        .init(metric: .stairAscentSpeed, declineDirection: .decreasing, label: Copy.Analysis.Research.MobilityDecline.stairAscentLabel),
        .init(metric: .stairDescentSpeed, declineDirection: .decreasing, label: Copy.Analysis.Research.MobilityDecline.stairDescentLabel),
        .init(metric: .walkingSteadiness, declineDirection: .decreasing, label: Copy.Analysis.Research.MobilityDecline.steadinessLabel)
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
            let lastQuarter = sorted.tailMean(sorted.count / 3)

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
        if decliningMetrics.count >= 3, let leadDecline = decliningMetrics.first {
            let worstMetrics = decliningMetrics
                .sorted { $0.changePercent > $1.changePercent }
                .prefix(4)
            let metricList = worstMetrics
                .map { "\($0.indicator.label) (\(String(format: "%.0f", $0.changePercent))%)" }
                .joined(separator: ", ")

            insights.append(InsightFactory.make(
                metric: leadDecline.indicator.metric,
                title: Copy.Analysis.Research.MobilityDecline.multiMetricDeclineTitle,
                summary: Copy.Analysis.Research.MobilityDecline.multiMetricSummary(declining: decliningMetrics.count, total: totalEvaluated, metricList: metricList),
                recommendation: Copy.Analysis.Research.MobilityDecline.multiMetricRecommendation,
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
            let percentText = String(format: "%.0f", speedDecline.changePercent)
            insights.append(InsightFactory.make(
                metric: .walkingSpeed,
                title: Copy.Analysis.Research.MobilityDecline.walkingSpeedDecliningTitle,
                summary: Copy.Analysis.Research.MobilityDecline.walkingSpeedSummary(percent: percentText),
                recommendation: Copy.Analysis.Research.MobilityDecline.walkingSpeedRecommendation(percent: percentText, samples: speedDecline.samples),
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
            let percentText = String(format: "%.0f", asymDecline.changePercent)
            insights.append(InsightFactory.make(
                metric: .walkingAsymmetry,
                title: Copy.Analysis.Research.MobilityDecline.asymmetryIncreasingTitle,
                summary: Copy.Analysis.Research.MobilityDecline.asymmetrySummary(percent: percentText),
                recommendation: Copy.Analysis.Research.MobilityDecline.asymmetryRecommendation(percent: percentText),
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
            let improvingList: String
            if improvingMetrics.isEmpty {
                improvingList = ""
            } else {
                let items = improvingMetrics.map { "\($0.indicator.label) (+\(String(format: "%.0f", $0.changePercent))%)" }.joined(separator: ", ")
                improvingList = Copy.Analysis.Research.MobilityDecline.mobilityStableImprovingFragment(items: items)
            }

            insights.append(InsightFactory.observation(
                metric: .walkingSpeed,
                title: Copy.Analysis.Research.MobilityDecline.mobilityStableTitle,
                summary: Copy.Analysis.Research.MobilityDecline.mobilityStableSummary(total: totalEvaluated, improvingList: improvingList),
                recommendation: Copy.Analysis.Research.MobilityDecline.mobilityStableRecommendation(total: totalEvaluated),
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
