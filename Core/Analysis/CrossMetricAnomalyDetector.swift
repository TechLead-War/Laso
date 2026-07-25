import Foundation

/// Detects days where the COMBINATION of metrics is unusual even if individual metrics look normal.
/// Uses a simplified Mahalanobis-inspired approach with pairwise correlation analysis to find
/// multivariate anomalies that single-metric detectors miss.
struct CrossMetricAnomalyDetector {

    // MARK: - Models

    struct CrossMetricAnomaly: Identifiable {
        let id = UUID()
        let severity: Severity
        let anomalyScore: Double  // 0-100
        let involvedMetrics: [MetricDeviation]
        let brokenCorrelations: [BrokenCorrelation]
        let narrative: String
    }

    struct MetricDeviation {
        let metric: HealthMetric
        let zScore: Double
        let direction: String  // "above" or "below"
    }

    struct BrokenCorrelation {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let expectedRelationship: String  // "normally inverse"
        let actualBehavior: String  // "both elevated"
    }

    // MARK: - Configuration

    /// Minimum metrics per day to form a valid feature vector
    private static let minMetricsPerDay = 4

    /// Minimum history days needed to establish "normal day" profile
    private static let minHistoryDays = 30

    /// History window for building the normal profile (days 7-90)
    private static let historyWindowDays = 90
    private static let recentWindowDays = 7

    /// Threshold for flagging broken correlations (|r| must be at least this in history)
    private static let correlationThreshold: Double = 0.3

    /// Maximum similar days in history before we stop considering it anomalous
    private static let maxSimilarDaysThreshold = 5


    // MARK: - Severity thresholds (composite anomaly score 0-100)
    private static let criticalScoreThreshold: Double = 90
    private static let warningScoreThreshold: Double = 75
    private static let infoScoreThreshold: Double = 60

    // MARK: - Day-similarity / broken-correlation z-score gates
    /// Minimum |z-score| on at least one side to count a correlation as broken.
    private static let brokenCorrelationMinAbsZ: Double = 0.8
    /// Z-score magnitude above which a metric counts as elevated/reduced for correlation-pair direction logic.
    private static let directionZThreshold: Double = 0.5
    /// Two days are "matching" on a metric when their z-scores differ by less than this.
    private static let perMetricMatchTolerance: Double = 1.0
    /// Match-ratio threshold across compared metrics for a day to count as "similar" historically.
    private static let dayMatchRatioThreshold: Double = 0.8

    // MARK: - Anomaly score component weights
    private static let zComponentCapZ: Double = 3.0
    private static let zComponentMaxPoints: Double = 40.0
    private static let correlationComponentSaturationCount: Double = 3.0
    private static let correlationComponentMaxPoints: Double = 30.0
    private static let breadthComponentSaturationCount: Double = 5.0
    private static let breadthComponentMaxPoints: Double = 10.0
    /// Rarity points awarded to days with zero similar historical occurrences.
    private static let rarityScoreNoMatch: Double = 20.0
    /// Rarity points awarded to days with exactly one similar historical occurrence.
    private static let rarityScoreSingleMatch: Double = 15.0
    /// Rarity points awarded to days with 2-3 similar historical occurrences.
    private static let rarityScoreFewMatches: Double = 10.0
    /// Decay slope (points lost per similar day) once more than three similar days exist.
    private static let rarityScoreDecayPerDay: Double = 4.0

    // MARK: - Public API

    /// Detect cross-metric anomalies by analyzing combinations of metric z-scores
    static func detect(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [CrossMetricAnomaly] {
        // Step 1: Build daily feature vectors (z-scores) for the last 90 days
        let dailyVectors = buildDailyFeatureVectors(
            timeSeries: timeSeries,
            baselines: baselines,
            days: historyWindowDays
        )

        // Need enough history to establish what "normal" looks like
        let historyVectors = dailyVectors.filter { vector in
            let daysAgo = Date.cal.dateComponents([.day], from: vector.date, to: Date()).day ?? 0
            return daysAgo >= recentWindowDays
        }
        guard historyVectors.count >= minHistoryDays else { return [] }

        // Step 2: Compute the "normal day" profile from historical data
        let normalProfile = computeNormalProfile(from: historyVectors)

        // Step 3: Compute pairwise correlation structure from history
        let correlationStructure = computeCorrelationStructure(from: historyVectors)

        // Step 4: Score recent days and generate anomalies
        let recentVectors = dailyVectors.filter { vector in
            let daysAgo = Date.cal.dateComponents([.day], from: vector.date, to: Date()).day ?? 0
            return daysAgo < recentWindowDays
        }

        var anomalies: [CrossMetricAnomaly] = []

        for recentDay in recentVectors {
            if let anomaly = scoreDay(
                recentDay,
                normalProfile: normalProfile,
                correlationStructure: correlationStructure,
                historyVectors: historyVectors
            ) {
                anomalies.append(anomaly)
            }
        }

        return anomalies.sorted { $0.anomalyScore > $1.anomalyScore }
    }

    /// Generate insights from detected cross-metric anomalies
    static func generateInsights(from anomalies: [CrossMetricAnomaly]) -> [Insight] {
        anomalies.compactMap { anomaly in
            // Only generate insights for warning+ severity
            guard anomaly.severity >= .warning else { return nil }

            // Use the most deviated metric as the primary metric for the insight
            let primaryMetric = anomaly.involvedMetrics
                .sorted { abs($0.zScore) > abs($1.zScore) }
                .first?.metric ?? .heartRate

            let relatedMetrics = anomaly.involvedMetrics
                .map(\.metric)
                .filter { $0 != primaryMetric }

            let recommendation = buildRecommendation(for: anomaly)

            return Insight(
                metric: primaryMetric,
                title: buildInsightTitle(for: anomaly),
                summary: anomaly.narrative,
                recommendation: recommendation,
                severity: anomaly.severity,
                trend: .stable,
                currentValue: anomaly.anomalyScore,
                baselineValue: 50,
                deviationPercent: anomaly.anomalyScore - 50,
                category: .crossMetricAnomaly,
                relatedMetrics: relatedMetrics
            )
        }
    }

    // MARK: - Step 1: Build Daily Feature Vectors

    /// A single day's worth of normalized metric values
    private struct DailyFeatureVector {
        let date: Date
        let zScores: [HealthMetric: Double]
    }

    /// Build z-score feature vectors for each day in the window
    private static func buildDailyFeatureVectors(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        days: Int
    ) -> [DailyFeatureVector] {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())

        // Build a date-indexed lookup for each metric
        var metricByDate: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            var dateMap: [Date: Double] = [:]
            for sample in series.samples(lastDays: days) {
                let sampleDay = calendar.startOfDay(for: sample.date)
                dateMap[sampleDay] = sample.value
            }
            metricByDate[metric] = dateMap
        }

        // For each day, compute z-scores across all available metrics
        var vectors: [DailyFeatureVector] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            var zScores: [HealthMetric: Double] = [:]

            for (metric, dateMap) in metricByDate {
                guard let value = dateMap[date],
                      let baseline = baselines[metric],
                      baseline.standardDeviation > 0,
                      baseline.sampleCount >= 7 else { continue }

                let z = (value - baseline.mean) / baseline.standardDeviation
                zScores[metric] = z
            }

            // Only include days with enough metrics
            guard zScores.count >= minMetricsPerDay else { continue }
            vectors.append(DailyFeatureVector(date: date, zScores: zScores))
        }

        return vectors.sorted { $0.date < $1.date }
    }

    // MARK: - Step 2: Compute Normal Day Profile

    /// Statistical profile of what a "normal day" looks like across metrics
    private struct NormalProfile {
        /// Mean z-score for each metric across history (should be near 0)
        let meanZScores: [HealthMetric: Double]
        /// Standard deviation of z-scores for each metric across history
        let zScoreStdDevs: [HealthMetric: Double]
    }

    private static func computeNormalProfile(from history: [DailyFeatureVector]) -> NormalProfile {
        // Collect all z-scores per metric across history
        var zScoresByMetric: [HealthMetric: [Double]] = [:]

        for vector in history {
            for (metric, z) in vector.zScores {
                zScoresByMetric[metric, default: []].append(z)
            }
        }

        var meanZScores: [HealthMetric: Double] = [:]
        var zScoreStdDevs: [HealthMetric: Double] = [:]

        for (metric, values) in zScoresByMetric {
            guard values.count >= 7 else { continue }
            meanZScores[metric] = values.mean
            zScoreStdDevs[metric] = values.standardDeviation
        }

        return NormalProfile(meanZScores: meanZScores, zScoreStdDevs: zScoreStdDevs)
    }

    // MARK: - Step 3: Compute Correlation Structure

    /// A pair of metrics and their historical correlation
    private struct MetricCorrelation {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let r: Double  // Pearson correlation of z-scores
    }

    /// Compute pairwise correlations between metric z-scores from history
    private static func computeCorrelationStructure(
        from history: [DailyFeatureVector]
    ) -> [MetricCorrelation] {
        // Find metrics that appear in enough days
        var metricCounts: [HealthMetric: Int] = [:]
        for vector in history {
            for metric in vector.zScores.keys {
                metricCounts[metric, default: 0] += 1
            }
        }

        let eligibleMetrics = metricCounts
            .filter { $0.value >= 14 }
            .sorted { $0.value > $1.value }  // most-observed first
            .prefix(12)                       // cap pairs to O(66) instead of O(M²)
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }

        guard eligibleMetrics.count >= 2 else { return [] }

        var correlations: [MetricCorrelation] = []

        for i in 0..<eligibleMetrics.count {
            for j in (i + 1)..<eligibleMetrics.count {
                let metricA = eligibleMetrics[i]
                let metricB = eligibleMetrics[j]

                // Extract paired z-scores (only days where both exist)
                var aValues: [Double] = []
                var bValues: [Double] = []

                for vector in history {
                    if let zA = vector.zScores[metricA],
                       let zB = vector.zScores[metricB] {
                        aValues.append(zA)
                        bValues.append(zB)
                    }
                }

                guard let r = [Double].pearsonCorrelation(aValues, bValues),
                      abs(r) >= correlationThreshold else { continue }

                correlations.append(MetricCorrelation(
                    metricA: metricA,
                    metricB: metricB,
                    r: r
                ))
            }
        }

        return correlations
    }

    // MARK: - Step 4: Score Recent Days

    private static func scoreDay(
        _ day: DailyFeatureVector,
        normalProfile: NormalProfile,
        correlationStructure: [MetricCorrelation],
        historyVectors: [DailyFeatureVector]
    ) -> CrossMetricAnomaly? {
        // Component 1: Combined z-score magnitude (weighted by unusualness)
        let combinedZScore = computeCombinedZScore(day: day, normalProfile: normalProfile)

        // Component 2: Broken correlations
        let brokenCorrelations = findBrokenCorrelations(
            day: day,
            correlationStructure: correlationStructure
        )

        // Component 3: Historical rarity. how many similar days exist
        let similarDays = countSimilarDays(day: day, history: historyVectors)

        let deviations = day.zScores.compactMap { (metric, z) -> MetricDeviation? in
            guard abs(z) > 0.5 else { return nil }  // Only include notably deviated metrics
            return MetricDeviation(
                metric: metric,
                zScore: z,
                direction: z > 0 ? "above" : "below"
            )
        }.sorted { abs($0.zScore) > abs($1.zScore) }

        // Skip if individual z-scores fully explain the anomaly (no interesting combination)
        let hasStrongIndividualAnomaly = deviations.contains { abs($0.zScore) >= 2.5 }
        let hasCombinationSignal = !brokenCorrelations.isEmpty || deviations.count >= 3

        // If the anomaly is just one very deviated metric, the existing AnomalyDetector handles it
        if hasStrongIndividualAnomaly && !hasCombinationSignal {
            return nil
        }

        // Compute composite anomaly score (0-100)
        let anomalyScore = computeAnomalyScore(
            combinedZScore: combinedZScore,
            brokenCorrelationCount: brokenCorrelations.count,
            similarDays: similarDays,
            deviationCount: deviations.count
        )

        // Apply severity thresholds
        let severity: Severity
        if anomalyScore >= Self.criticalScoreThreshold {
            severity = .critical
        } else if anomalyScore >= Self.warningScoreThreshold {
            severity = .warning
        } else if anomalyScore >= Self.infoScoreThreshold {
            severity = .info
        } else {
            return nil  // Not anomalous enough
        }

        // Only flag truly rare combinations
        guard similarDays < maxSimilarDaysThreshold else { return nil }

        // Generate narrative
        let narrative = buildNarrative(
            deviations: deviations,
            brokenCorrelations: brokenCorrelations,
            similarDays: similarDays,
            historyDays: historyVectors.count
        )

        return CrossMetricAnomaly(
            severity: severity,
            anomalyScore: anomalyScore,
            involvedMetrics: deviations,
            brokenCorrelations: brokenCorrelations,
            narrative: narrative
        )
    }

    // MARK: - Scoring Components

    /// Compute a combined z-score that reflects how unusual the full metric vector is
    private static func computeCombinedZScore(
        day: DailyFeatureVector,
        normalProfile: NormalProfile
    ) -> Double {
        var sumSquaredDeviations: Double = 0
        var count = 0

        for (metric, z) in day.zScores {
            guard let histMean = normalProfile.meanZScores[metric],
                  let histStd = normalProfile.zScoreStdDevs[metric],
                  histStd > 0 else { continue }

            // How unusual is this metric's z-score relative to its own historical z-score distribution
            let normalizedDeviation = (z - histMean) / histStd
            sumSquaredDeviations += normalizedDeviation * normalizedDeviation
            count += 1
        }

        guard count > 0 else { return 0 }

        // Root mean squared deviation. like a simplified Mahalanobis distance
        return (sumSquaredDeviations / Double(count)).squareRoot()
    }

    /// Find metric pairs whose normal correlation is broken on this day
    private static func findBrokenCorrelations(
        day: DailyFeatureVector,
        correlationStructure: [MetricCorrelation]
    ) -> [BrokenCorrelation] {
        var broken: [BrokenCorrelation] = []

        for correlation in correlationStructure {
            guard let zA = day.zScores[correlation.metricA],
                  let zB = day.zScores[correlation.metricB] else { continue }

            // Check if the relationship is broken:
            // If normally positively correlated (r > 0), one going up while the other goes down is anomalous
            // If normally inversely correlated (r < 0), both going the same direction is anomalous

            let bothElevated = zA > Self.directionZThreshold && zB > Self.directionZThreshold
            let bothReduced = zA < -Self.directionZThreshold && zB < -Self.directionZThreshold
            let sameDirection = bothElevated || bothReduced

            let diverging = (zA > Self.directionZThreshold && zB < -Self.directionZThreshold) || (zA < -Self.directionZThreshold && zB > Self.directionZThreshold)

            let isBroken: Bool
            let expectedRelationship: String
            let actualBehavior: String

            if correlation.r > 0 && diverging {
                // Normally move together, but diverging today
                isBroken = true
                expectedRelationship = "normally correlated"
                let aDir = zA > 0 ? "elevated" : "reduced"
                let bDir = zB > 0 ? "elevated" : "reduced"
                actualBehavior = "\(correlation.metricA.displayName) \(aDir), \(correlation.metricB.displayName) \(bDir)"
            } else if correlation.r < 0 && sameDirection {
                // Normally inverse, but moving together today
                isBroken = true
                expectedRelationship = "normally inverse"
                let dir = bothElevated ? "both elevated" : "both reduced"
                actualBehavior = dir
            } else {
                isBroken = false
                expectedRelationship = ""
                actualBehavior = ""
            }

            guard isBroken else { continue }

            // Require at least moderate z-scores to count as a broken correlation
            guard abs(zA) >= Self.brokenCorrelationMinAbsZ || abs(zB) >= Self.brokenCorrelationMinAbsZ else { continue }

            broken.append(BrokenCorrelation(
                metricA: correlation.metricA,
                metricB: correlation.metricB,
                expectedRelationship: expectedRelationship,
                actualBehavior: actualBehavior
            ))
        }

        return broken
    }

    /// Count how many historical days had a similar multi-metric profile
    private static func countSimilarDays(
        day: DailyFeatureVector,
        history: [DailyFeatureVector]
    ) -> Int {
        var count = 0

        for histDay in history {
            var matchingMetrics = 0
            var comparedMetrics = 0

            for (metric, z) in day.zScores {
                guard let histZ = histDay.zScores[metric] else { continue }
                comparedMetrics += 1

                // "Similar" = within `perMetricMatchTolerance` stddev on each metric
                if abs(z - histZ) <= Self.perMetricMatchTolerance {
                    matchingMetrics += 1
                }
            }

            // Day is "similar" if the vast majority of metrics match
            guard comparedMetrics >= minMetricsPerDay else { continue }
            let matchRatio = Double(matchingMetrics) / Double(comparedMetrics)
            if matchRatio >= Self.dayMatchRatioThreshold {
                count += 1
                // Early-exit: once we know it's not rare, skip remaining history
                if count >= maxSimilarDaysThreshold { return count }
            }
        }

        return count
    }

    /// Compute a 0-100 anomaly score from the individual components
    private static func computeAnomalyScore(
        combinedZScore: Double,
        brokenCorrelationCount: Int,
        similarDays: Int,
        deviationCount: Int
    ) -> Double {
        // Component weights
        // Combined z-score: capped at zComponentCapZ
        let zComponent = min(combinedZScore / Self.zComponentCapZ, 1.0) * Self.zComponentMaxPoints

        // Broken correlations: each broken correlation adds signal
        let correlationComponent = min(Double(brokenCorrelationCount) / Self.correlationComponentSaturationCount, 1.0) * Self.correlationComponentMaxPoints

        // Historical rarity: fewer similar days = more anomalous
        let rarityComponent: Double
        if similarDays == 0 {
            rarityComponent = Self.rarityScoreNoMatch
        } else if similarDays == 1 {
            rarityComponent = Self.rarityScoreSingleMatch
        } else if similarDays <= 3 {
            rarityComponent = Self.rarityScoreFewMatches
        } else {
            rarityComponent = max(0, Self.rarityScoreNoMatch - Double(similarDays) * Self.rarityScoreDecayPerDay)
        }

        // Multi-metric involvement
        let breadthComponent = min(Double(deviationCount) / Self.breadthComponentSaturationCount, 1.0) * Self.breadthComponentMaxPoints

        return min(zComponent + correlationComponent + rarityComponent + breadthComponent, 100.0)
    }

    // MARK: - Narrative Generation

    private static func buildNarrative(
        deviations: [MetricDeviation],
        brokenCorrelations: [BrokenCorrelation],
        similarDays: Int,
        historyDays: Int
    ) -> String {
        var parts: [String] = []

        // Lead with the most unusual metric deviations
        let topDeviations = Array(deviations.prefix(3))
        if topDeviations.count >= 2 {
            let descriptions = topDeviations.map { deviation in
                "\(deviation.metric.displayName.lowercased()) is \(deviation.direction) baseline"
            }
            parts.append("Your " + joinNaturalLanguage(descriptions))
        } else if let first = topDeviations.first {
            parts.append("Your \(first.metric.displayName.lowercased()) is \(first.direction) baseline")
        }

        // Describe the most significant broken correlation
        if let topBroken = brokenCorrelations.first {
            let relationship = topBroken.expectedRelationship
            parts.append(
                "your \(topBroken.metricA.displayName) and \(topBroken.metricB.displayName) " +
                "are \(relationship) for you, but today \(topBroken.actualBehavior)"
            )
        }

        // Add rarity context
        if similarDays == 0 {
            parts.append("this combination has never appeared in your \(historyDays)-day history")
        } else if similarDays <= 2 {
            parts.append(
                "this combination has only appeared \(similarDays) " +
                "\(similarDays == 1 ? "other time" : "other times") in your \(historyDays)-day history"
            )
        }

        // Combine into a flowing narrative
        guard !parts.isEmpty else { return Copy.Analysis.CrossMetricAnomaly.unusualCombinationDetected }

        var narrative = parts[0].prefix(1).uppercased() + parts[0].dropFirst()
        if parts.count > 1 {
            // Join with em-dashes and periods for readability
            narrative += " \u{2014} " + parts[1]
        }
        if parts.count > 2 {
            narrative += ". " + parts[2].prefix(1).uppercased() + String(parts[2].dropFirst())
        }
        narrative += "."

        return narrative
    }

    /// Join strings like: "A, B, and C"
    private static func joinNaturalLanguage(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            let allButLast = items.dropLast().joined(separator: ", ")
            let last = items.last ?? ""
            return "\(allButLast), and \(last)"
        }
    }

    // MARK: - Insight Helpers

    private static func buildInsightTitle(for anomaly: CrossMetricAnomaly) -> String {
        let metricCount = anomaly.involvedMetrics.count

        if !anomaly.brokenCorrelations.isEmpty {
            let broken = anomaly.brokenCorrelations[0]
            return Copy.Analysis.CrossMetricAnomaly.unusualPattern(metricA: broken.metricA.displayName, metricB: broken.metricB.displayName)
        }

        if metricCount >= 3 {
            return Copy.Analysis.CrossMetricAnomaly.unusualMultiMetricPattern
        }

        return Copy.Analysis.CrossMetricAnomaly.rareMetricCombination
    }

    private static func buildRecommendation(for anomaly: CrossMetricAnomaly) -> String {
        let involvedCategories = Set(anomaly.involvedMetrics.map { $0.metric.category })
        let topMetrics = anomaly.involvedMetrics.prefix(3).map { $0.metric.displayName.lowercased() }.joined(separator: ", ")

        switch anomaly.severity {
        case .critical:
            return Copy.Analysis.CrossMetricNarratives.extremelyRare(metrics: topMetrics)
        case .warning:
            if !anomaly.brokenCorrelations.isEmpty {
                let broken = anomaly.brokenCorrelations[0]
                return Copy.Analysis.CrossMetricNarratives.brokenRelationship(metricA: broken.metricA.displayName.lowercased(), metricB: broken.metricB.displayName.lowercased())
            }
            if involvedCategories.count >= 2 {
                return Copy.Analysis.CrossMetricNarratives.unusualMultiCategory(categoryCount: involvedCategories.count, metrics: topMetrics)
            }
            return Copy.Analysis.CrossMetricNarratives.unusualCombination(metrics: topMetrics)
        case .info:
            return Copy.Analysis.CrossMetricNarratives.unusualMild(metrics: topMetrics)
        }
    }
}

// MARK: - InsightAnalyzer Conformance

extension CrossMetricAnomalyDetector: InsightAnalyzer {
    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(from: context.crossMetricAnomalies)
    }
}
