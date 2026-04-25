import Foundation

/// Research: Stanford SleepFM (Nature Medicine, Jan 2026)
/// Finding: When body systems go out of sync during sleep. brain asleep but heart awake —
/// that signals disease risk. 130 conditions predictable from sleep signal coherence.
///
/// Implementation: Measures whether HR/HRV/respiratory rate follow expected
/// stage-appropriate patterns during each sleep phase. Flags incoherence.
struct SleepCoherenceAnalyzer {

    // MARK: - Expected Ranges per Sleep Stage (from literature)

    /// Expected physiological ranges during deep sleep vs REM vs core.
    /// Deep sleep: lowest HR, highest HRV, lowest respiratory rate.
    /// REM sleep: elevated HR, reduced HRV, variable respiratory rate (dream activity).
    /// Core (N1/N2): intermediate values.
    private struct StageExpectation {
        let hrDropFromResting: ClosedRange<Double>   // % below resting HR
        let hrvBoostFromBaseline: ClosedRange<Double> // % above baseline HRV
        let rrDropFromBaseline: ClosedRange<Double>   // % below baseline respiratory rate
    }

    private static let deepExpectation = StageExpectation(
        hrDropFromResting: 10...30,     // HR should be 10-30% below resting
        hrvBoostFromBaseline: 10...80,  // HRV should be 10-80% above baseline
        rrDropFromBaseline: 5...20      // Respiratory rate 5-20% below baseline
    )

    private static let remExpectation = StageExpectation(
        hrDropFromResting: 0...15,      // HR closer to resting during REM
        hrvBoostFromBaseline: -20...20, // HRV can be near or below baseline in REM
        rrDropFromBaseline: -10...10    // Respiratory rate variable in REM
    )

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        // Need: sleep stages, HR, HRV, respiratory rate
        guard let deepSeries = context.timeSeries[.sleepDeep],
              let remSeries = context.timeSeries[.sleepREM],
              let hrSeries = context.timeSeries[.heartRate],
              let hrvSeries = context.timeSeries[.heartRateVariability],
              let rhrBaseline = context.baselines[.restingHeartRate],
              let hrvBaseline = context.baselines[.heartRateVariability] else { return [] }

        let rrSeries = context.timeSeries[.respiratoryRate]
        let rrBaseline = context.baselines[.respiratoryRate]

        let deepMap = TimeSeriesAligner.dailyValueMap(deepSeries)
        let remMap = TimeSeriesAligner.dailyValueMap(remSeries)
        let hrMap = TimeSeriesAligner.dailyValueMap(hrSeries)
        let hrvMap = TimeSeriesAligner.dailyValueMap(hrvSeries)

        let rrMap: [Date: Double]? = rrSeries.map { TimeSeriesAligner.dailyValueMap($0) }

        // Compute nightly coherence scores over last 30 days
        let last30 = deepSeries.samples(lastDays: 30)
        guard last30.count >= 14 else { return [] }

        let coherence = computeNightlyCoherence(
            samples: last30,
            deepMap: deepMap,
            remMap: remMap,
            hrMap: hrMap,
            hrvMap: hrvMap,
            rrMap: rrMap,
            rhrBaseline: rhrBaseline,
            hrvBaseline: hrvBaseline,
            rrBaseline: rrBaseline,
            context: context
        )

        guard coherence.scores.count >= 10 else { return [] }

        let avgCoherence = coherence.scores.map(\.score).mean
        let recentCoherence = Array(coherence.scores.suffix(7)).map(\.score).mean
        let priorCoherence = coherence.scores.count >= 14
            ? Array(coherence.scores.dropLast(7).suffix(7)).map(\.score).mean
            : avgCoherence

        let coherenceTrend: TrendDirection = recentCoherence > priorCoherence + 5 ? .improving
            : recentCoherence < priorCoherence - 5 ? .declining : .stable

        var insights: [Insight] = []
        if let overall = buildOverallCoherenceInsight(
            avgCoherence: avgCoherence,
            recentCoherence: recentCoherence,
            priorCoherence: priorCoherence,
            coherenceTrend: coherenceTrend,
            incoherentNights: coherence.incoherentNights,
            totalNights: coherence.totalNights,
            scoreCount: coherence.scores.count
        ) {
            insights.append(overall)
        }

        if let trendInsight = buildCoherenceTrendInsight(
            recentCoherence: recentCoherence,
            priorCoherence: priorCoherence,
            coherenceTrend: coherenceTrend
        ) {
            insights.append(trendInsight)
        }

        return insights
    }

    // MARK: - Helpers

    private struct NightlyCoherence {
        let scores: [(date: Date, score: Double)]
        let incoherentNights: Int
        let totalNights: Int
    }

    private static func computeNightlyCoherence(
        samples: [MetricSample],
        deepMap: [Date: Double],
        remMap: [Date: Double],
        hrMap: [Date: Double],
        hrvMap: [Date: Double],
        rrMap: [Date: Double]?,
        rhrBaseline: UserBaseline,
        hrvBaseline: UserBaseline,
        rrBaseline: UserBaseline?,
        context: AnalysisContext
    ) -> NightlyCoherence {
        var coherenceScores: [(date: Date, score: Double)] = []
        var incoherentNights = 0
        var totalNights = 0

        for sample in samples {
            let date = sample.date.startOfDay
            guard let deepHrs = deepMap[date], deepHrs > 0,
                  let remHrs = remMap[date], remHrs > 0,
                  let nightHR = hrMap[date],
                  let nightHRV = hrvMap[date] else { continue }

            totalNights += 1
            var scoreComponents: [Double] = []

            // 1. HR coherence: overnight HR should be well below resting
            let hrDrop = ((rhrBaseline.mean - nightHR) / rhrBaseline.mean) * 100
            let hrCoherence = hrDrop >= 5 ? min(hrDrop / 20.0, 1.0) : max(0, hrDrop / 5.0)
            scoreComponents.append(hrCoherence)

            // 2. HRV coherence: overnight HRV should be above daytime baseline
            let hrvBoost = ((nightHRV - hrvBaseline.mean) / max(hrvBaseline.mean, 1)) * 100
            let hrvCoherence = hrvBoost >= 0 ? min(hrvBoost / 30.0, 1.0) : max(0, (hrvBoost + 20) / 20.0)
            scoreComponents.append(hrvCoherence)

            // 3. Deep sleep proportion coherence
            let totalSleep = deepHrs + remHrs + (context.timeSeries[.sleepCore].flatMap { TimeSeriesAligner.dailyValueMap($0)[date] } ?? 0)
            guard totalSleep > 0 else { continue }
            let deepRatio = deepHrs / totalSleep
            let deepCoherence = deepRatio >= 0.13 ? min(deepRatio / 0.25, 1.0) : deepRatio / 0.13
            scoreComponents.append(deepCoherence)

            // 4. Respiratory rate coherence (if available)
            if let rrMap = rrMap, let nightRR = rrMap[date],
               let rrBase = rrBaseline {
                let rrDrop = ((rrBase.mean - nightRR) / rrBase.mean) * 100
                let rrCoherence = rrDrop >= 0 ? min(rrDrop / 10.0, 1.0) : max(0, (rrDrop + 10) / 10.0)
                scoreComponents.append(rrCoherence)
            }

            let nightScore = scoreComponents.isEmpty ? 0 : scoreComponents.mean * 100
            coherenceScores.append((date: date, score: nightScore))

            if nightScore < 40 {
                incoherentNights += 1
            }
        }

        return NightlyCoherence(scores: coherenceScores, incoherentNights: incoherentNights, totalNights: totalNights)
    }

    private static func buildOverallCoherenceInsight(
        avgCoherence: Double,
        recentCoherence: Double,
        priorCoherence: Double,
        coherenceTrend: TrendDirection,
        incoherentNights: Int,
        totalNights: Int,
        scoreCount: Int
    ) -> Insight? {
        let severity: Severity = avgCoherence < 35 ? .warning : .info
        _ = Double(incoherentNights) / Double(totalNights) * 100

        if avgCoherence < 60 || incoherentNights >= 4 {
            return InsightFactory.make(
                metric: .sleepDeep,
                title: "Sleep Systems Out of Sync",
                summary: "Your body's systems aren't fully aligning during sleep. On \(incoherentNights) of \(totalNights) recent nights, your heart rate and HRV didn't follow expected sleep-stage patterns. coherence score: \(String(format: "%.0f", avgCoherence))/100.",
                recommendation: "Research shows that physiological incoherence during sleep. when your heart stays 'awake' while your brain sleeps. is associated with reduced overall wellness. Your coherence score of \(String(format: "%.0f", avgCoherence)) suggests \(avgCoherence < 35 ? "significant" : "moderate") desynchronization across \(totalNights) measured nights.",
                severity: severity,
                trend: coherenceTrend,
                currentValue: avgCoherence,
                baselineValue: 70,
                deviationPercent: ((avgCoherence - 70) / 70) * 100,
                category: .sleepPerformance,
                directive: avgCoherence < 35 ? .sleepBetter : .informational,
                relatedMetrics: [.sleepDeep, .sleepREM, .heartRate, .heartRateVariability],
                context: InsightContext(
                    slope: (recentCoherence - priorCoherence) / 7,
                    confidenceLevel: min(Double(scoreCount) / 30.0, 1.0),
                    dataPointCount: scoreCount
                )
            )
        } else if avgCoherence >= 75 {
            return InsightFactory.observation(
                metric: .sleepDeep,
                title: "Strong Sleep Coherence",
                summary: "Your body's systems sync well during sleep. heart rate drops appropriately, HRV rises, and sleep architecture looks healthy. Coherence score: \(String(format: "%.0f", avgCoherence))/100 across \(totalNights) nights.",
                recommendation: "A coherence score of \(String(format: "%.0f", avgCoherence)) means your heart and nervous system are well-aligned during sleep. Research links high sleep coherence to better overall wellness across many dimensions of health.",
                currentValue: avgCoherence,
                baselineValue: 70,
                deviationPercent: ((avgCoherence - 70) / 70) * 100,
                category: .sleepPerformance,
                relatedMetrics: [.sleepDeep, .sleepREM, .heartRate, .heartRateVariability],
                context: InsightContext(
                    confidenceLevel: min(Double(scoreCount) / 30.0, 1.0),
                    dataPointCount: scoreCount
                )
            )
        }
        return nil
    }

    private static func buildCoherenceTrendInsight(
        recentCoherence: Double,
        priorCoherence: Double,
        coherenceTrend: TrendDirection
    ) -> Insight? {
        guard coherenceTrend == .declining && (priorCoherence - recentCoherence) >= 10 else { return nil }
        return InsightFactory.make(
            metric: .heartRateVariability,
            title: "Sleep Coherence Declining",
            summary: "Your sleep coherence dropped from \(String(format: "%.0f", priorCoherence)) to \(String(format: "%.0f", recentCoherence)) over the past two weeks. Your heart and nervous system are less synchronized during sleep than before.",
            recommendation: "A \(String(format: "%.0f", priorCoherence - recentCoherence))-point drop in sleep coherence over 2 weeks may reflect increased stress, an irregular schedule, or your body working harder to recover. This pattern often appears before you start feeling off.",
            severity: .warning,
            trend: .declining,
            currentValue: recentCoherence,
            baselineValue: priorCoherence,
            deviationPercent: ((recentCoherence - priorCoherence) / max(priorCoherence, 1)) * 100,
            category: .sleepPerformance,
            directive: .sleepBetter,
            relatedMetrics: [.heartRate, .heartRateVariability, .sleepDeep, .sleepREM]
        )
    }
}

// MARK: - InsightAnalyzer Conformance

extension SleepCoherenceAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "sleepCoherence" }
    static var insightCategory: InsightCategory { .sleepPerformance }
}

