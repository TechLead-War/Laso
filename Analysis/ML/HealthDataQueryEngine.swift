import Foundation
import NaturalLanguage

// MARK: - Health Data Query Engine

/// Natural language query engine for personal health data.
/// Inspired by Google's PHIA (Nature Communications 2025): transforms
/// user questions into structured queries over existing ML pipeline outputs.
///
/// Uses Apple's on-device NaturalLanguage framework for intent parsing —
/// no external API calls required.
final class HealthDataQueryEngine {

    // MARK: - Types

    enum QueryIntent {
        case trend(metric: HealthMetric, period: QueryPeriod)
        case comparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod)
        case correlation(metricA: HealthMetric, metricB: HealthMetric)
        case forecast(metric: HealthMetric, horizon: Int)
        case anomaly(metric: HealthMetric?)
        case bestWorst(metric: HealthMetric, seeking: BestWorst)
        case status(metric: HealthMetric?)
        case general

        enum BestWorst { case best, worst }
    }

    enum QueryPeriod: String {
        case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, last7Days, last30Days, last90Days

        var days: Int {
            switch self {
            case .today: return 1
            case .yesterday: return 1
            case .thisWeek, .lastWeek, .last7Days: return 7
            case .thisMonth, .lastMonth, .last30Days: return 30
            case .last90Days: return 90
            }
        }
    }

    struct QueryResult {
        let question: String
        let answer: String
        let dataPoints: [DataPoint]
        let confidence: Double
        let relatedQuestions: [String]

        struct DataPoint {
            let label: String
            let value: Double
            let unit: String
            let date: Date?
        }
    }

    // MARK: - Metric Vocabulary

    /// Maps natural language terms to HealthMetric values
    private static let metricVocabulary: [String: HealthMetric] = [
        "heart rate": .heartRate, "hr": .heartRate, "pulse": .heartRate,
        "resting heart rate": .restingHeartRate, "rhr": .restingHeartRate, "resting hr": .restingHeartRate,
        "hrv": .heartRateVariability, "heart rate variability": .heartRateVariability, "variability": .heartRateVariability,
        "sleep": .sleepDuration, "sleep duration": .sleepDuration, "hours slept": .sleepDuration,
        "deep sleep": .sleepDeep, "rem": .sleepREM, "rem sleep": .sleepREM,
        "steps": .steps, "step count": .steps, "walking": .steps,
        "calories": .activeCalories, "active calories": .activeCalories, "energy": .activeCalories,
        "exercise": .exerciseMinutes, "exercise minutes": .exerciseMinutes, "workout": .exerciseMinutes,
        "weight": .weight, "body weight": .weight,
        "blood pressure": .bloodPressureSystolic, "systolic": .bloodPressureSystolic, "diastolic": .bloodPressureDiastolic,
        "blood oxygen": .bloodOxygen, "spo2": .bloodOxygen, "oxygen": .bloodOxygen,
        "vo2 max": .vo2Max, "vo2": .vo2Max, "fitness": .vo2Max,
        "respiratory rate": .respiratoryRate, "breathing": .respiratoryRate,
        "body fat": .bodyFatPercentage, "fat": .bodyFatPercentage,
        "mindfulness": .mindfulMinutes, "meditation": .mindfulMinutes,
        "temperature": .bodyTemperature, "temp": .bodyTemperature,
    ]

    /// Maps natural language terms to time periods
    private static let periodVocabulary: [String: QueryPeriod] = [
        "today": .today, "yesterday": .yesterday,
        "this week": .thisWeek, "last week": .lastWeek,
        "this month": .thisMonth, "last month": .lastMonth,
        "past week": .last7Days, "last 7 days": .last7Days, "7 days": .last7Days,
        "past month": .last30Days, "last 30 days": .last30Days, "30 days": .last30Days,
        "last 3 months": .last90Days, "past 3 months": .last90Days, "90 days": .last90Days,
    ]

    // MARK: - Query Processing

    /// Process a natural language health question and generate an answer.
    func query(
        question: String,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        correlations: [MLCorrelation],
        forecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast]
    ) -> QueryResult {
        let normalizedQuestion = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = parseIntent(normalizedQuestion)

        switch intent {
        case .trend(let metric, let period):
            return answerTrend(metric: metric, period: period, timeSeries: timeSeries, trends: trends, baselines: baselines)

        case .comparison(let metric, let periodA, let periodB):
            return answerComparison(metric: metric, periodA: periodA, periodB: periodB, timeSeries: timeSeries)

        case .correlation(let metricA, let metricB):
            return answerCorrelation(metricA: metricA, metricB: metricB, correlations: correlations)

        case .forecast(let metric, let horizon):
            return answerForecast(metric: metric, horizon: horizon, forecasts: forecasts)

        case .anomaly(let metric):
            return answerAnomaly(metric: metric, timeSeries: timeSeries, baselines: baselines)

        case .bestWorst(let metric, let seeking):
            return answerBestWorst(metric: metric, seeking: seeking, timeSeries: timeSeries)

        case .status(let metric):
            return answerStatus(metric: metric, timeSeries: timeSeries, baselines: baselines, trends: trends, correlations: correlations)

        case .general:
            return answerGeneral(question: normalizedQuestion, timeSeries: timeSeries, baselines: baselines, trends: trends, correlations: correlations)
        }
    }

    // MARK: - Intent Parsing

    private func parseIntent(_ question: String) -> QueryIntent {
        let words = question.components(separatedBy: .whitespaces)

        // Detect metrics mentioned
        let detectedMetrics = detectMetrics(in: question)
        let detectedPeriods = detectPeriods(in: question)
        let primaryMetric = detectedMetrics.first
        let primaryPeriod = detectedPeriods.first ?? .last7Days

        // Pattern matching for intent type
        let correlationPatterns = ["affect", "impact", "correlat", "relat", "connect", "influence", "cause"]
        let forecastPatterns = ["predict", "forecast", "will", "expect", "next", "tomorrow", "future"]
        let trendPatterns = ["trend", "going", "changing", "improv", "declin", "getting"]
        let comparisonPatterns = ["compar", "versus", "vs", "better", "worse", "differ"]
        let anomalyPatterns = ["unusual", "abnormal", "anomal", "weird", "strange", "off", "spike"]
        let bestWorstPatterns = ["best", "highest", "most", "peak", "record", "worst", "lowest", "least"]
        let statusPatterns = ["how", "what", "status", "current", "average", "am i"]

        let questionLower = question.lowercased()

        // Check correlation (needs two metrics)
        if detectedMetrics.count >= 2 && correlationPatterns.contains(where: { questionLower.contains($0) }) {
            return .correlation(metricA: detectedMetrics[0], metricB: detectedMetrics[1])
        }

        // Check forecast
        if forecastPatterns.contains(where: { questionLower.contains($0) }), let metric = primaryMetric {
            let horizon = questionLower.contains("week") ? 7 : questionLower.contains("3 day") ? 3 : 1
            return .forecast(metric: metric, horizon: horizon)
        }

        // Check best/worst
        if let metric = primaryMetric {
            if bestWorstPatterns.prefix(5).contains(where: { questionLower.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .best)
            }
            if bestWorstPatterns.suffix(3).contains(where: { questionLower.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .worst)
            }
        }

        // Check anomaly
        if anomalyPatterns.contains(where: { questionLower.contains($0) }) {
            return .anomaly(metric: primaryMetric)
        }

        // Check trend
        if trendPatterns.contains(where: { questionLower.contains($0) }), let metric = primaryMetric {
            return .trend(metric: metric, period: primaryPeriod)
        }

        // Check comparison
        if comparisonPatterns.contains(where: { questionLower.contains($0) }), let metric = primaryMetric {
            let periods = detectedPeriods
            let periodA = periods.count > 0 ? periods[0] : .thisWeek
            let periodB = periods.count > 1 ? periods[1] : .lastWeek
            return .comparison(metric: metric, periodA: periodA, periodB: periodB)
        }

        // Default: status query
        if let metric = primaryMetric {
            return .status(metric: metric)
        }

        return .general
    }

    private func detectMetrics(in text: String) -> [HealthMetric] {
        let lower = text.lowercased()
        var found: [(metric: HealthMetric, position: Int)] = []

        for (term, metric) in Self.metricVocabulary {
            if let range = lower.range(of: term) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                // Avoid duplicates (same metric from different terms)
                if !found.contains(where: { $0.metric == metric }) {
                    found.append((metric: metric, position: position))
                }
            }
        }

        return found.sorted { $0.position < $1.position }.map(\.metric)
    }

    private func detectPeriods(in text: String) -> [QueryPeriod] {
        let lower = text.lowercased()
        var found: [(period: QueryPeriod, position: Int)] = []

        for (term, period) in Self.periodVocabulary {
            if let range = lower.range(of: term) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                found.append((period: period, position: position))
            }
        }

        return found.sorted { $0.position < $1.position }.map(\.period)
    }

    // MARK: - Answer Generators

    private func answerTrend(
        metric: HealthMetric,
        period: QueryPeriod,
        timeSeries: [HealthMetric: MetricTimeSeries],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline]
    ) -> QueryResult {
        guard let series = timeSeries[metric] else {
            return noDataResult(question: "trend for \(metric.displayName)", metric: metric)
        }

        let recentSamples = recentSamples(from: series, days: period.days)
        guard recentSamples.count >= 2 else {
            return noDataResult(question: "trend for \(metric.displayName)", metric: metric)
        }

        let values = recentSamples.map(\.value)
        let first = values.prefix(values.count / 2)
        let second = values.suffix(values.count / 2)
        let firstAvg = first.reduce(0, +) / Double(first.count)
        let secondAvg = second.reduce(0, +) / Double(second.count)
        let change = secondAvg - firstAvg
        let percentChange = firstAvg != 0 ? (change / firstAvg) * 100 : 0

        let direction: String
        if abs(percentChange) < 2 { direction = "stable" }
        else if percentChange > 0 { direction = metric.higherIsBetter ? "improving" : "increasing" }
        else { direction = metric.higherIsBetter ? "declining" : "decreasing" }

        let avgValue = values.reduce(0, +) / Double(values.count)

        let answer = "\(metric.displayName) has been \(direction) over the \(period.rawValue). Average: \(formatValue(avgValue, metric: metric)) (\(String(format: "%+.1f%%", percentChange)) change)."

        return QueryResult(
            question: "How is my \(metric.displayName) trending?",
            answer: answer,
            dataPoints: [
                .init(label: "Average", value: avgValue, unit: metric.unit, date: nil),
                .init(label: "Change", value: percentChange, unit: "%", date: nil),
                .init(label: "Latest", value: values.last ?? 0, unit: metric.unit, date: recentSamples.last?.date)
            ],
            confidence: min(1.0, Double(recentSamples.count) / 14.0),
            relatedQuestions: [
                "What's my best \(metric.displayName) this month?",
                "Is my \(metric.displayName) normal?",
                "What affects my \(metric.displayName)?"
            ]
        )
    }

    private func answerCorrelation(
        metricA: HealthMetric,
        metricB: HealthMetric,
        correlations: [MLCorrelation]
    ) -> QueryResult {
        let match = correlations.first {
            ($0.metricA == metricA && $0.metricB == metricB) ||
            ($0.metricA == metricB && $0.metricB == metricA)
        }

        if let corr = match {
            let strength: String
            switch abs(corr.pearsonR) {
            case 0.7...: strength = "strong"
            case 0.4..<0.7: strength = "moderate"
            case 0.2..<0.4: strength = "weak"
            default: strength = "very weak"
            }

            let direction = corr.pearsonR > 0 ? "positive" : "negative"
            let causal = corr.grangerCausal ? " There's evidence that \(corr.metricA.displayName) may causally influence \(corr.metricB.displayName) (Granger causal, p=\(String(format: "%.3f", corr.grangerPValue)))." : ""

            let answer = "There's a \(strength) \(direction) correlation (r=\(String(format: "%.2f", corr.pearsonR))) between \(metricA.displayName) and \(metricB.displayName).\(causal)"

            return QueryResult(
                question: "Does \(metricA.displayName) affect \(metricB.displayName)?",
                answer: answer,
                dataPoints: [
                    .init(label: "Correlation", value: corr.pearsonR, unit: "r", date: nil),
                    .init(label: "Stability", value: corr.stability, unit: "", date: nil)
                ],
                confidence: corr.stability,
                relatedQuestions: [
                    "What's my \(metricA.displayName) trend?",
                    "How is my \(metricB.displayName) doing?",
                    "What else affects my \(metricB.displayName)?"
                ]
            )
        }

        return QueryResult(
            question: "Does \(metricA.displayName) affect \(metricB.displayName)?",
            answer: "No significant relationship found between \(metricA.displayName) and \(metricB.displayName) in your data yet. This may change as more data accumulates.",
            dataPoints: [],
            confidence: 0.5,
            relatedQuestions: [
                "What correlates with my \(metricA.displayName)?",
                "What affects my \(metricB.displayName)?"
            ]
        )
    }

    private func answerForecast(
        metric: HealthMetric,
        horizon: Int,
        forecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast]
    ) -> QueryResult {
        guard let forecast = forecasts[metric] else {
            return QueryResult(
                question: "What will my \(metric.displayName) be?",
                answer: "Not enough data to forecast \(metric.displayName) yet. Need at least 21 days of history.",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: ["How is my \(metric.displayName) trending?"]
            )
        }

        let horizonResult = forecast.horizons.first { $0.horizon == horizon } ?? forecast.horizons.first

        guard let result = horizonResult else {
            return noDataResult(question: "forecast for \(metric.displayName)", metric: metric)
        }

        let dayLabel = horizon == 1 ? "tomorrow" : "in \(horizon) days"
        let answer = "Your \(metric.displayName) is predicted to be \(formatValue(result.value, metric: metric)) \(dayLabel) (range: \(formatValue(result.ciLower, metric: metric)) - \(formatValue(result.ciUpper, metric: metric)))."

        return QueryResult(
            question: "What will my \(metric.displayName) be \(dayLabel)?",
            answer: answer,
            dataPoints: [
                .init(label: "Predicted", value: result.value, unit: metric.unit, date: nil),
                .init(label: "Lower bound", value: result.ciLower, unit: metric.unit, date: nil),
                .init(label: "Upper bound", value: result.ciUpper, unit: metric.unit, date: nil)
            ],
            confidence: max(0.3, 1.0 - result.ciWidth / max(1, result.value)),
            relatedQuestions: [
                "How is my \(metric.displayName) trending?",
                "What affects my \(metric.displayName)?"
            ]
        )
    }

    private func answerComparison(
        metric: HealthMetric,
        periodA: QueryPeriod,
        periodB: QueryPeriod,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> QueryResult {
        guard let series = timeSeries[metric] else {
            return noDataResult(question: "comparison for \(metric.displayName)", metric: metric)
        }

        let samplesA = recentSamples(from: series, days: periodA.days)
        let samplesB = recentSamples(from: series, days: periodB.days, offset: periodA.days)

        guard !samplesA.isEmpty, !samplesB.isEmpty else {
            return noDataResult(question: "comparison for \(metric.displayName)", metric: metric)
        }

        let avgA = samplesA.map(\.value).reduce(0, +) / Double(samplesA.count)
        let avgB = samplesB.map(\.value).reduce(0, +) / Double(samplesB.count)
        let diff = avgA - avgB
        let percentDiff = avgB != 0 ? (diff / avgB) * 100 : 0

        let better = (diff > 0 && metric.higherIsBetter) || (diff < 0 && !metric.higherIsBetter)
        let verdict = better ? "improved" : abs(percentDiff) < 3 ? "remained similar" : "declined"

        let answer = "Your \(metric.displayName) has \(verdict). \(periodA.rawValue): \(formatValue(avgA, metric: metric)) vs \(periodB.rawValue): \(formatValue(avgB, metric: metric)) (\(String(format: "%+.1f%%", percentDiff)))."

        return QueryResult(
            question: "Compare my \(metric.displayName)",
            answer: answer,
            dataPoints: [
                .init(label: periodA.rawValue, value: avgA, unit: metric.unit, date: nil),
                .init(label: periodB.rawValue, value: avgB, unit: metric.unit, date: nil)
            ],
            confidence: 0.85,
            relatedQuestions: ["What's my \(metric.displayName) trend?"]
        )
    }

    private func answerAnomaly(
        metric: HealthMetric?,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> QueryResult {
        let metricsToCheck: [HealthMetric]
        if let specific = metric {
            metricsToCheck = [specific]
        } else {
            metricsToCheck = Array(timeSeries.keys.prefix(10))
        }

        var anomalies: [(metric: HealthMetric, deviation: Double, value: Double)] = []

        for m in metricsToCheck {
            guard let series = timeSeries[m],
                  let latest = series.samples.last,
                  let baseline = baselines[m] else { continue }

            let deviation = abs(latest.value - baseline.mean) / max(1, baseline.standardDeviation)
            if deviation > 2.0 {
                anomalies.append((metric: m, deviation: deviation, value: latest.value))
            }
        }

        if anomalies.isEmpty {
            return QueryResult(
                question: "Anything unusual in my data?",
                answer: "No significant anomalies detected in your recent data. Everything looks within normal ranges.",
                dataPoints: [],
                confidence: 0.7,
                relatedQuestions: ["How am I doing overall?", "What's trending?"]
            )
        }

        anomalies.sort { $0.deviation > $1.deviation }
        let topAnomaly = anomalies[0]
        let answer = "\(topAnomaly.metric.displayName) is unusual — \(formatValue(topAnomaly.value, metric: topAnomaly.metric)) is \(String(format: "%.1f", topAnomaly.deviation)) standard deviations from your baseline."

        return QueryResult(
            question: "Anything unusual?",
            answer: answer,
            dataPoints: anomalies.prefix(3).map {
                .init(label: $0.metric.displayName, value: $0.value, unit: $0.metric.unit, date: nil)
            },
            confidence: 0.8,
            relatedQuestions: anomalies.prefix(2).map { "What's happening with my \($0.metric.displayName)?" }
        )
    }

    private func answerBestWorst(
        metric: HealthMetric,
        seeking: QueryIntent.BestWorst,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> QueryResult {
        guard let series = timeSeries[metric], !series.samples.isEmpty else {
            return noDataResult(question: "\(seeking == .best ? "best" : "worst") \(metric.displayName)", metric: metric)
        }

        let sorted = series.samples.sorted { $0.value < $1.value }
        let target = seeking == .best
            ? (metric.higherIsBetter ? sorted.last! : sorted.first!)
            : (metric.higherIsBetter ? sorted.first! : sorted.last!)

        let dateStr = DateFormatter.localizedString(from: target.date, dateStyle: .medium, timeStyle: .none)
        let label = seeking == .best ? "best" : "worst"

        return QueryResult(
            question: "What was my \(label) \(metric.displayName)?",
            answer: "Your \(label) \(metric.displayName) was \(formatValue(target.value, metric: metric)) on \(dateStr).",
            dataPoints: [.init(label: label.capitalized, value: target.value, unit: metric.unit, date: target.date)],
            confidence: 0.95,
            relatedQuestions: [
                "How is my \(metric.displayName) trending?",
                "What was my \(seeking == .best ? "worst" : "best") \(metric.displayName)?"
            ]
        )
    }

    private func answerStatus(
        metric: HealthMetric?,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        correlations: [MLCorrelation]
    ) -> QueryResult {
        guard let m = metric, let series = timeSeries[m] else {
            return answerGeneral(question: "status", timeSeries: timeSeries, baselines: baselines, trends: trends, correlations: correlations)
        }

        let recent = recentSamples(from: series, days: 7)
        guard !recent.isEmpty else {
            return noDataResult(question: "status of \(m.displayName)", metric: m)
        }

        let avg = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let latest = recent.last?.value ?? avg

        var statusParts: [String] = []
        statusParts.append("Your current \(m.displayName) is \(formatValue(latest, metric: m)).")
        statusParts.append("7-day average: \(formatValue(avg, metric: m)).")

        if let baseline = baselines[m] {
            let deviation = (avg - baseline.mean) / max(1, baseline.standardDeviation)
            if abs(deviation) > 1 {
                statusParts.append(deviation > 0 ? "Above your baseline." : "Below your baseline.")
            } else {
                statusParts.append("Within your normal range.")
            }
        }

        return QueryResult(
            question: "How is my \(m.displayName)?",
            answer: statusParts.joined(separator: " "),
            dataPoints: [
                .init(label: "Current", value: latest, unit: m.unit, date: recent.last?.date),
                .init(label: "7-day avg", value: avg, unit: m.unit, date: nil)
            ],
            confidence: 0.85,
            relatedQuestions: [
                "What's my \(m.displayName) trend?",
                "What affects my \(m.displayName)?",
                "Predict my \(m.displayName) for tomorrow"
            ]
        )
    }

    private func answerGeneral(
        question: String,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        correlations: [MLCorrelation]
    ) -> QueryResult {
        // Instead of a dead-end help message, surface the most interesting
        // finding from the user's actual data.

        var highlights: [(priority: Int, answer: String, dataPoints: [QueryResult.DataPoint], followUps: [String])] = []

        // 1. Find biggest anomaly (most surprising data point)
        for (metric, series) in timeSeries {
            guard let latest = series.samples.last,
                  let baseline = baselines[metric] else { continue }
            let deviation = abs(latest.value - baseline.mean) / max(1, baseline.standardDeviation)
            if deviation > 2.0 {
                let dir = latest.value > baseline.mean ? "above" : "below"
                highlights.append((
                    priority: Int(deviation * 10),
                    answer: "Your \(metric.displayName) is unusual right now — \(formatValue(latest.value, metric: metric)) is \(String(format: "%.1f", deviation)) standard deviations \(dir) your baseline.",
                    dataPoints: [.init(label: metric.displayName, value: latest.value, unit: metric.unit, date: latest.date)],
                    followUps: ["What's happening with my \(metric.displayName)?", "Is my \(metric.displayName) trending?"]
                ))
            }
        }

        // 2. Find strongest trend (biggest mover)
        let sortedTrends = trends.sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
        if let top = sortedTrends.first, abs(top.value.weekOverWeekChange) > 5 {
            let dir = top.value.weekOverWeekChange > 0 ? "up" : "down"
            highlights.append((
                priority: Int(abs(top.value.weekOverWeekChange)),
                answer: "Your \(top.key.displayName) is moving — \(dir) \(String(format: "%.0f%%", abs(top.value.weekOverWeekChange))) week over week.",
                dataPoints: [.init(label: "Change", value: top.value.weekOverWeekChange, unit: "%", date: nil)],
                followUps: ["How is my \(top.key.displayName) trending?", "What affects my \(top.key.displayName)?"]
            ))
        }

        // 3. Find strongest correlation
        if let topCorr = correlations.sorted(by: { abs($0.pearsonR) > abs($1.pearsonR) }).first,
           abs(topCorr.pearsonR) > 0.4 {
            let dir = topCorr.pearsonR > 0 ? "positively" : "negatively"
            highlights.append((
                priority: Int(abs(topCorr.pearsonR) * 20),
                answer: "Interesting finding: your \(topCorr.metricA.displayName) and \(topCorr.metricB.displayName) are \(dir) linked (r=\(String(format: "%.2f", topCorr.pearsonR))).",
                dataPoints: [.init(label: "Correlation", value: topCorr.pearsonR, unit: "r", date: nil)],
                followUps: ["Does \(topCorr.metricA.displayName) affect \(topCorr.metricB.displayName)?", "How is my \(topCorr.metricA.displayName)?"]
            ))
        }

        // Pick the most interesting finding
        if let best = highlights.sorted(by: { $0.priority > $1.priority }).first {
            return QueryResult(
                question: question,
                answer: best.answer,
                dataPoints: best.dataPoints,
                confidence: 0.7,
                relatedQuestions: best.followUps
            )
        }

        // True fallback — no interesting findings at all (very early user)
        let metricsWithData = timeSeries.filter { !$0.value.samples.isEmpty }
        let metricCount = metricsWithData.count

        if metricCount == 0 {
            return QueryResult(
                question: question,
                answer: "No health data yet. Connect your Apple Watch or allow Health access to get started.",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: []
            )
        }

        return QueryResult(
            question: question,
            answer: "Tracking \(metricCount) metrics. Everything looks within normal ranges right now. Ask about a specific metric to dig deeper.",
            dataPoints: [],
            confidence: 0.6,
            relatedQuestions: Array(metricsWithData.keys.prefix(3)).map { "How is my \($0.displayName)?" }
        )
    }

    // MARK: - Helpers

    private func recentSamples(from series: MetricTimeSeries, days: Int, offset: Int = 0) -> [MetricSample] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        return series.samples.filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }

    private func formatValue(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps:
            return "\(Int(value))"
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore:
            let hours = value / 3600
            return String(format: "%.1fh", hours)
        case .heartRateVariability:
            return String(format: "%.0fms", value)
        case .bodyTemperature:
            return String(format: "%.1f°F", value)
        case .weight:
            return String(format: "%.1f lbs", value)
        case .vo2Max:
            return String(format: "%.1f", value)
        case .bloodOxygen:
            return String(format: "%.0f%%", value * 100)
        default:
            if value > 1000 { return String(format: "%.0f", value) }
            if value > 10 { return String(format: "%.1f", value) }
            return String(format: "%.2f", value)
        }
    }

    private func noDataResult(question: String, metric: HealthMetric) -> QueryResult {
        QueryResult(
            question: question,
            answer: "Not enough \(metric.displayName) data available yet. Keep wearing your device to build up history.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: ["What data do I have?"]
        )
    }
}
