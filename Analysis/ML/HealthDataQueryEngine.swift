import Foundation
import NaturalLanguage

// MARK: - Health Data Query Engine

/// Natural language query engine for personal health data.
/// Inspired by Google's PHIA (Nature Communications 2025): transforms
/// user questions into structured queries over the full ML pipeline.
///
/// Uses Apple's on-device NaturalLanguage framework for semantic intent
/// matching via NLEmbedding. no external API calls required.
final class HealthDataQueryEngine {

    // MARK: - Types

    /// Bundles all ML pipeline data needed to answer questions.
    struct QueryContext {
        let timeSeries: [HealthMetric: MetricTimeSeries]
        let baselines: [HealthMetric: UserBaseline]
        let trends: [HealthMetric: TrendAnalyzer.TrendResult]
        let correlations: [MLCorrelation]
        let forecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast]
        let healthSignalReport: PredictiveHealthSignals.HealthSignalReport?
        let currentHealthState: HealthState?
        let discoveredPatterns: [DiscoveredPattern]
        let circadianProfile: CircadianAnalyzer.CircadianProfile?
        let timingRecommendations: [CircadianAnalyzer.TimingRecommendation]
        let optimalProfile: PersonalOptimizer.OptimalProfile?
        let idealDay: PersonalOptimizer.IdealDay?
        let scoreSensitivities: [PersonalOptimizer.SensitivityResult]
        let tomorrowRiskPrediction: MLPrediction?
        let compoundInsights: [CompoundInsightEngine.CompoundInsight]
        let temporalSequences: [TemporalSequenceMiner.TemporalSequence]
        let overallScore: Int
    }

    enum QueryIntent {
        case trend(metric: HealthMetric, period: QueryPeriod)
        case comparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod)
        case correlation(metricA: HealthMetric, metricB: HealthMetric)
        case forecast(metric: HealthMetric, horizon: Int)
        case anomaly(metric: HealthMetric?)
        case bestWorst(metric: HealthMetric, seeking: BestWorst)
        case status(metric: HealthMetric?)
        case healthState
        case risk
        case optimization
        case pattern(metric: HealthMetric?)
        case circadian
        case whyScore
        case causal(metric: HealthMetric)
        case general

        enum BestWorst { case best, worst }
    }

    enum MatchingMode {
        case full
        case keywordOnly
    }

    /// Intermediate category for semantic matching (no associated values)
    private enum IntentCategory: String, CaseIterable {
        case trend, comparison, correlation, forecast, anomaly, bestWorst, status
        case healthState, risk, optimization, pattern, circadian, whyScore, causal
        case general
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

        var displayName: String {
            switch self {
            case .today: return "today"
            case .yesterday: return "yesterday"
            case .thisWeek: return "this week"
            case .lastWeek: return "last week"
            case .thisMonth: return "this month"
            case .lastMonth: return "last month"
            case .last7Days: return "the past week"
            case .last30Days: return "the past month"
            case .last90Days: return "the past 3 months"
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

    // MARK: - Properties

    private let nlAnalyzer = NLEmbeddingAnalyzer()
    private let semanticCacheLock = NSLock()
    private var semanticIntentCache: [String: IntentCategory] = [:]
    private var semanticMissCache = Set<String>()

    // MARK: - Metric Vocabulary

    private static let metricVocabulary: [String: HealthMetric] = [
        // Heart
        "heart rate": .heartRate, "hr": .heartRate, "pulse": .heartRate, "bpm": .heartRate,
        "resting heart rate": .restingHeartRate, "rhr": .restingHeartRate, "resting hr": .restingHeartRate, "resting pulse": .restingHeartRate,
        "hrv": .heartRateVariability, "heart rate variability": .heartRateVariability, "variability": .heartRateVariability,
        "heart rate recovery": .heartRateRecovery, "hr recovery": .heartRateRecovery,
        "afib": .atrialFibrillationBurden, "atrial fibrillation": .atrialFibrillationBurden,
        // Sleep
        "sleep": .sleepDuration, "sleep duration": .sleepDuration, "hours slept": .sleepDuration, "time asleep": .sleepDuration,
        "deep sleep": .sleepDeep, "rem": .sleepREM, "rem sleep": .sleepREM, "core sleep": .sleepCore,
        "breathing disturbances": .sleepBreathingDisturbances, "sleep apnea": .sleepBreathingDisturbances,
        // Activity
        "steps": .steps, "step count": .steps,
        "calories": .activeCalories, "active calories": .activeCalories, "active energy": .activeCalories,
        "basal calories": .basalCalories, "resting energy": .basalCalories,
        "exercise": .exerciseMinutes, "exercise minutes": .exerciseMinutes, "workout": .exerciseMinutes, "workouts": .exerciseMinutes,
        "workout duration": .workoutDuration, "training time": .workoutDuration,
        "stand hours": .standHours, "standing": .standHours, "stand time": .standHours,
        "distance": .distanceWalkingRunning, "walking distance": .distanceWalkingRunning, "running distance": .distanceWalkingRunning,
        "cycling distance": .distanceCycling, "cycling": .distanceCycling, "biking": .distanceCycling,
        "swimming distance": .distanceSwimming, "swimming": .distanceSwimming,
        "flights climbed": .flightsClimbed, "stairs": .flightsClimbed, "flights": .flightsClimbed,
        // Body
        "weight": .weight, "body weight": .weight,
        "bmi": .bmi, "body mass index": .bmi,
        "body fat": .bodyFatPercentage, "fat percentage": .bodyFatPercentage,
        "lean mass": .leanBodyMass, "lean body mass": .leanBodyMass, "muscle mass": .leanBodyMass,
        "waist": .waistCircumference, "waist circumference": .waistCircumference,
        "blood pressure": .bloodPressureSystolic, "systolic": .bloodPressureSystolic, "diastolic": .bloodPressureDiastolic,
        "body temperature": .bodyTemperature, "temperature": .bodyTemperature, "temp": .bodyTemperature,
        "wrist temperature": .appleSleepingWristTemperature, "wrist temp": .appleSleepingWristTemperature, "sleeping temperature": .appleSleepingWristTemperature,
        // Respiratory
        "blood oxygen": .bloodOxygen, "spo2": .bloodOxygen, "oxygen saturation": .bloodOxygen, "oxygen": .bloodOxygen,
        "vo2 max": .vo2Max, "vo2": .vo2Max, "aerobic fitness": .vo2Max, "cardio fitness": .vo2Max,
        "respiratory rate": .respiratoryRate, "breathing rate": .respiratoryRate, "breaths per minute": .respiratoryRate,
        // Mindfulness
        "mindfulness": .mindfulMinutes, "meditation": .mindfulMinutes, "mindful minutes": .mindfulMinutes,
        "daylight": .timeInDaylight, "sunlight": .timeInDaylight, "time in daylight": .timeInDaylight, "sun exposure": .timeInDaylight,
        // Mobility
        "walking speed": .walkingSpeed, "pace": .walkingSpeed, "gait speed": .walkingSpeed,
        "step length": .walkingStepLength, "stride length": .walkingStepLength,
        "walking asymmetry": .walkingAsymmetry, "gait asymmetry": .walkingAsymmetry,
        "walking steadiness": .walkingSteadiness, "steadiness": .walkingSteadiness, "balance": .walkingSteadiness,
        "six minute walk": .sixMinuteWalkTestDistance, "6 minute walk": .sixMinuteWalkTestDistance,
        // Nutrition
        "water": .waterIntake, "water intake": .waterIntake, "hydration": .waterIntake,
        "caffeine": .caffeineIntake, "coffee": .caffeineIntake,
        "protein": .proteinIntake, "protein intake": .proteinIntake,
        "fiber": .fiberIntake, "fibre": .fiberIntake,
        "sugar": .sugarIntake, "sugar intake": .sugarIntake,
        "sodium": .sodiumIntake, "salt": .sodiumIntake,
        "carbs": .carbohydrateIntake, "carbohydrates": .carbohydrateIntake,
        "dietary fat": .fatIntake,
        "diet calories": .totalCaloriesIntake, "food calories": .totalCaloriesIntake,
        // Metabolic
        "blood glucose": .bloodGlucose, "glucose": .bloodGlucose, "blood sugar": .bloodGlucose,
        // Hearing
        "headphone audio": .headphoneAudioExposure, "headphone volume": .headphoneAudioExposure,
    ]

    private static let periodVocabulary: [String: QueryPeriod] = [
        "today": .today, "yesterday": .yesterday,
        "this week": .thisWeek, "last week": .lastWeek,
        "this month": .thisMonth, "last month": .lastMonth,
        "past week": .last7Days, "last 7 days": .last7Days, "7 days": .last7Days, "recent week": .last7Days,
        "past month": .last30Days, "last 30 days": .last30Days, "30 days": .last30Days, "recent month": .last30Days,
        "last 3 months": .last90Days, "past 3 months": .last90Days, "90 days": .last90Days, "past quarter": .last90Days,
    ]

    // MARK: - Semantic Exemplars

    /// Canonical questions for semantic matching when keyword detection is ambiguous.
    private static let intentExemplars: [IntentCategory: [String]] = [
        .trend: [
            "how is my heart rate trending", "is my hrv going up or down",
            "what direction is my sleep heading", "am i improving over time",
            "show me the trend", "has my weight been changing",
        ],
        .risk: [
            "am i at risk for anything", "any health warnings",
            "should i be worried about anything", "are there any red flags",
            "is anything concerning in my data", "health risks",
        ],
        .healthState: [
            "what state is my body in", "how is my body doing overall",
            "am i recovered", "what is my current health state",
            "how am i doing right now", "overall body status",
        ],
        .optimization: [
            "how do i improve my score", "what should i do today",
            "how to have a great day", "optimize my health",
            "what does my ideal day look like", "tips for better recovery",
        ],
        .pattern: [
            "do i have any patterns", "weekly cycles in my data",
            "when does my heart rate peak", "any recurring rhythms",
            "day of week patterns", "seasonal trends",
        ],
        .circadian: [
            "when should i work out", "best time to exercise",
            "what is my chronotype", "my body clock",
            "optimal time for sleep", "when am i most alert",
        ],
        .whyScore: [
            "why is my score low", "what is affecting my score",
            "explain my recovery score", "score breakdown",
            "why did my score drop", "what drives my score",
        ],
        .causal: [
            "what causes my hrv to drop", "why does my sleep suffer",
            "what drives my heart rate up", "root cause analysis",
            "what influences my recovery", "what leads to bad days",
        ],
        .forecast: [
            "predict my heart rate", "what will my hrv be tomorrow",
            "forecast my sleep", "what should i expect next week",
        ],
        .comparison: [
            "compare this week to last week", "am i better than last month",
            "this month versus last month", "how does today compare",
        ],
        .anomaly: [
            "anything unusual in my data", "any weird readings",
            "anomalies or spikes", "something seems off",
        ],
        .correlation: [
            "does sleep affect my heart rate", "relationship between exercise and hrv",
            "connection between caffeine and sleep", "are these metrics linked",
        ],
    ]

    private static let semanticCorpus: [(category: IntentCategory, exemplar: String)] = IntentCategory.allCases.flatMap { category in
        (intentExemplars[category] ?? []).map { (category: category, exemplar: $0) }
    }

    // MARK: - Query Processing

    /// Primary entry point. uses full ML pipeline context.
    func query(question: String, context: QueryContext, matchingMode: MatchingMode = .full) -> QueryResult {
        let normalized = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle conversational inputs before parsing health intent
        if let conversational = handleConversational(normalized, ctx: context) {
            return conversational
        }

        let intent = parseIntent(normalized, context: context, matchingMode: matchingMode)

        switch intent {
        case .trend(let metric, let period):
            return answerTrend(metric: metric, period: period, ctx: context)
        case .comparison(let metric, let periodA, let periodB):
            return answerComparison(metric: metric, periodA: periodA, periodB: periodB, ctx: context)
        case .correlation(let metricA, let metricB):
            return answerCorrelation(metricA: metricA, metricB: metricB, ctx: context)
        case .forecast(let metric, let horizon):
            return answerForecast(metric: metric, horizon: horizon, ctx: context)
        case .anomaly(let metric):
            return answerAnomaly(metric: metric, ctx: context)
        case .bestWorst(let metric, let seeking):
            return answerBestWorst(metric: metric, seeking: seeking, ctx: context)
        case .status(let metric):
            return answerStatus(metric: metric, ctx: context)
        case .healthState:
            return answerHealthState(ctx: context)
        case .risk:
            return answerRisk(ctx: context)
        case .optimization:
            return answerOptimization(ctx: context)
        case .pattern(let metric):
            return answerPattern(metric: metric, ctx: context)
        case .circadian:
            return answerCircadian(ctx: context)
        case .whyScore:
            return answerWhyScore(ctx: context)
        case .causal(let metric):
            return answerCausal(metric: metric, ctx: context)
        case .general:
            return answerGeneral(question: normalized, ctx: context)
        }
    }

    /// Backward-compatible entry point.
    func query(
        question: String,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        correlations: [MLCorrelation],
        forecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast]
    ) -> QueryResult {
        let ctx = QueryContext(
            timeSeries: timeSeries, baselines: baselines, trends: trends,
            correlations: correlations, forecasts: forecasts,
            healthSignalReport: nil, currentHealthState: nil, discoveredPatterns: [],
            circadianProfile: nil, timingRecommendations: [], optimalProfile: nil,
            idealDay: nil, scoreSensitivities: [], tomorrowRiskPrediction: nil,
            compoundInsights: [], temporalSequences: [], overallScore: 0
        )
        return query(question: question, context: ctx)
    }

    // MARK: - Intent Parsing

    private func parseIntent(_ question: String, context: QueryContext, matchingMode: MatchingMode) -> QueryIntent {
        let detectedMetrics = detectMetrics(in: question)
        let detectedPeriods = detectPeriods(in: question)
        let primaryMetric = detectedMetrics.first
        _ = detectedPeriods.first ?? .last7Days

        // Try keyword matching first
        if let keywordResult = keywordIntent(question, metrics: detectedMetrics, periods: detectedPeriods) {
            return keywordResult
        }

        // Semantic matching fallback via NLEmbedding
        if matchingMode == .full, let category = semanticIntentMatch(question) {
            return resolveCategory(category, metrics: detectedMetrics, periods: detectedPeriods)
        }

        // Default: status if we found a metric, general otherwise
        if let metric = primaryMetric {
            return .status(metric: metric)
        }
        return .general
    }

    private func keywordIntent(_ question: String, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent? {
        let primaryMetric = metrics.first
        let primaryPeriod = periods.first ?? .last7Days

        let healthStatePatterns = ["state", "body doing", "body status", "recovered", "health state"]
        let riskPatterns = ["risk", "warning", "worried", "danger", "concern", "red flag", "careful"]
        let optimizationPatterns = ["optimize", "improve", "ideal day", "best day", "tip", "should i do", "better score", "great day"]
        let patternPatterns = ["pattern", "cycle", "rhythm", "recurring", "weekly pattern", "routine"]
        let circadianPatterns = ["body clock", "chronotype", "best time", "when should", "optimal time", "when to"]
        let whyScorePatterns = ["why is my score", "score low", "score drop", "score breakdown", "explain my score", "affecting my score", "what's driving my score"]
        let causalPatterns = ["cause", "why does", "what drives", "root cause", "what leads to", "what makes my"]
        let correlationPatterns = ["affect", "impact", "correlat", "relat", "connect", "influence", "relationship", "linked"]
        let forecastPatterns = ["predict", "forecast", "will my", "expect", "next", "tomorrow", "future"]
        let trendPatterns = ["trend", "going", "changing", "improv", "declin", "getting", "heading", "direction"]
        let comparisonPatterns = ["compar", "versus", "vs", "better than", "worse than", "differ"]
        let anomalyPatterns = ["unusual", "abnormal", "anomal", "weird", "strange", "spike", "something off"]
        let bestPatterns = ["best", "highest", "most", "peak", "record", "personal best"]
        let worstPatterns = ["worst", "lowest", "least", "minimum"]

        // New intents first (higher priority for specific questions)
        if whyScorePatterns.contains(where: { question.contains($0) }) {
            return .whyScore
        }
        if healthStatePatterns.contains(where: { question.contains($0) }) {
            return .healthState
        }
        if riskPatterns.contains(where: { question.contains($0) }) {
            return .risk
        }
        if optimizationPatterns.contains(where: { question.contains($0) }) {
            return .optimization
        }
        if circadianPatterns.contains(where: { question.contains($0) }) {
            return .circadian
        }
        if patternPatterns.contains(where: { question.contains($0) }) {
            return .pattern(metric: primaryMetric)
        }

        // Correlation (needs two metrics)
        if metrics.count >= 2 && correlationPatterns.contains(where: { question.contains($0) }) {
            return .correlation(metricA: metrics[0], metricB: metrics[1])
        }

        // Causal (one metric + causal keyword)
        if causalPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            return .causal(metric: metric)
        }

        // Forecast
        if forecastPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            let horizon = question.contains("week") ? 7 : question.contains("3 day") ? 3 : 1
            return .forecast(metric: metric, horizon: horizon)
        }

        // Best/Worst
        if let metric = primaryMetric {
            if bestPatterns.contains(where: { question.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .best)
            }
            if worstPatterns.contains(where: { question.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .worst)
            }
        }

        // Anomaly
        if anomalyPatterns.contains(where: { question.contains($0) }) {
            return .anomaly(metric: primaryMetric)
        }

        // Trend
        if trendPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            return .trend(metric: metric, period: primaryPeriod)
        }

        // Comparison
        if comparisonPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            let periodA = periods.count > 0 ? periods[0] : .thisWeek
            let periodB = periods.count > 1 ? periods[1] : .lastWeek
            return .comparison(metric: metric, periodA: periodA, periodB: periodB)
        }

        return nil // No keyword match. fall through to semantic
    }

    /// Sentence-embedding semantic match for ambiguous queries.
    private func semanticIntentMatch(_ question: String) -> IntentCategory? {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 8 else { return nil }

        semanticCacheLock.lock()
        if let cached = semanticIntentCache[normalized] {
            semanticCacheLock.unlock()
            return cached
        }
        if semanticMissCache.contains(normalized) {
            semanticCacheLock.unlock()
            return nil
        }
        semanticCacheLock.unlock()

        var bestCategory: IntentCategory?
        var bestDistance = Double.infinity

        for (category, exemplar) in Self.semanticCorpus {
            let dist = nlAnalyzer.computeSemanticDistance(sentenceA: normalized, sentenceB: exemplar)
            if dist < bestDistance {
                bestDistance = dist
                bestCategory = category
            }
        }

        let match = bestDistance < 1.2 ? bestCategory : nil

        semanticCacheLock.lock()
        if semanticIntentCache.count + semanticMissCache.count > 256 {
            semanticIntentCache.removeAll(keepingCapacity: true)
            semanticMissCache.removeAll(keepingCapacity: true)
        }
        if let match {
            semanticIntentCache[normalized] = match
        } else {
            semanticMissCache.insert(normalized)
        }
        semanticCacheLock.unlock()

        return match
    }

    /// Convert a category (from semantic match) into a full QueryIntent with extracted params.
    private func resolveCategory(_ category: IntentCategory, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent {
        let metric = metrics.first
        let period = periods.first ?? .last7Days

        switch category {
        case .trend:
            return metric.map { .trend(metric: $0, period: period) } ?? .general
        case .comparison:
            let a = periods.count > 0 ? periods[0] : .thisWeek
            let b = periods.count > 1 ? periods[1] : .lastWeek
            return metric.map { .comparison(metric: $0, periodA: a, periodB: b) } ?? .general
        case .correlation:
            return metrics.count >= 2 ? .correlation(metricA: metrics[0], metricB: metrics[1]) : .general
        case .forecast:
            return metric.map { .forecast(metric: $0, horizon: 1) } ?? .general
        case .anomaly:
            return .anomaly(metric: metric)
        case .bestWorst:
            return metric.map { .bestWorst(metric: $0, seeking: .best) } ?? .general
        case .status:
            return .status(metric: metric)
        case .healthState:
            return .healthState
        case .risk:
            return .risk
        case .optimization:
            return .optimization
        case .pattern:
            return .pattern(metric: metric)
        case .circadian:
            return .circadian
        case .whyScore:
            return .whyScore
        case .causal:
            return metric.map { .causal(metric: $0) } ?? .general
        case .general:
            return .general
        }
    }

    // MARK: - Metric & Period Detection

    private func detectMetrics(in text: String) -> [HealthMetric] {
        let lower = text.lowercased()
        var found: [(metric: HealthMetric, position: Int)] = []

        // Sort vocabulary by term length descending to match longer phrases first
        let sortedVocab = Self.metricVocabulary.sorted { $0.key.count > $1.key.count }

        for (term, metric) in sortedVocab {
            if let range = lower.range(of: term) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
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

    // MARK: - Answer Generators (Original, Improved)

    private func answerTrend(metric: HealthMetric, period: QueryPeriod, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric] else {
            return noDataResult(for: metric)
        }

        let recent = recentSamples(from: series, days: period.days)
        guard recent.count >= 2 else { return noDataResult(for: metric) }

        let values = recent.map(\.value)
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let pctChange = firstAvg != 0 ? ((secondAvg - firstAvg) / firstAvg) * 100 : 0
        let avg = values.reduce(0, +) / Double(values.count)

        let direction: String
        let sentiment: Sentiment
        if abs(pctChange) < 2 {
            direction = "holding steady"
            sentiment = .neutral
        } else if pctChange > 0 {
            direction = metric.higherIsBetter ? "on an upward trend" : "creeping up"
            sentiment = metric.higherIsBetter ? .positive : .negative
        } else {
            direction = metric.higherIsBetter ? "dipping down" : "coming down"
            sentiment = metric.higherIsBetter ? .negative : .positive
        }

        let opening = openingPhrase(sentiment)
        let interpretation = trendInterpretation(metric: metric, pctChange: pctChange, sentiment: sentiment)
        let answer = "\(opening)Your \(metric.displayName) is \(direction) over \(period.displayName), averaging \(formatValue(avg, metric: metric)). that's a \(String(format: "%.1f%%", abs(pctChange))) \(pctChange >= 0 ? "increase" : "decrease"). \(interpretation)"

        return QueryResult(
            question: "How is my \(metric.displayName) trending?",
            answer: answer,
            dataPoints: [
                .init(label: "Average", value: avg, unit: metric.unit, date: nil),
                .init(label: "Change", value: pctChange, unit: "%", date: nil),
                .init(label: "Latest", value: values.last ?? 0, unit: metric.unit, date: recent.last?.date),
            ],
            confidence: min(1.0, Double(recent.count) / 14.0),
            relatedQuestions: [
                "What affects my \(metric.displayName)?",
                "Predict my \(metric.displayName) for tomorrow",
                "Do I have any \(metric.displayName) patterns?",
            ]
        )
    }

    private func answerComparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric] else {
            return noDataResult(for: metric)
        }

        let samplesA = recentSamples(from: series, days: periodA.days)
        let samplesB = recentSamples(from: series, days: periodB.days, offset: periodA.days)
        guard !samplesA.isEmpty, !samplesB.isEmpty else { return noDataResult(for: metric) }

        let avgA = samplesA.map(\.value).reduce(0, +) / Double(samplesA.count)
        let avgB = samplesB.map(\.value).reduce(0, +) / Double(samplesB.count)
        let pctDiff = avgB != 0 ? ((avgA - avgB) / avgB) * 100 : 0

        let better = (pctDiff > 0 && metric.higherIsBetter) || (pctDiff < 0 && !metric.higherIsBetter)
        let verdict: String
        if abs(pctDiff) < 3 {
            verdict = "roughly the same"
        } else {
            verdict = better ? "looking better" : "a bit lower"
        }

        let answer = "Your \(metric.displayName) \(periodA.displayName) is \(verdict) compared to \(periodB.displayName). You averaged \(formatValue(avgA, metric: metric)) vs \(formatValue(avgB, metric: metric)). a \(String(format: "%.1f%%", abs(pctDiff))) \(pctDiff >= 0 ? "increase" : "decrease")."

        return QueryResult(
            question: "Compare my \(metric.displayName)",
            answer: answer,
            dataPoints: [
                .init(label: periodA.displayName.capitalized, value: avgA, unit: metric.unit, date: nil),
                .init(label: periodB.displayName.capitalized, value: avgB, unit: metric.unit, date: nil),
            ],
            confidence: 0.85,
            relatedQuestions: [
                "How is my \(metric.displayName) trending?",
                "What affects my \(metric.displayName)?",
            ]
        )
    }

    private func answerCorrelation(metricA: HealthMetric, metricB: HealthMetric, ctx: QueryContext) -> QueryResult {
        let match = ctx.correlations.first {
            ($0.metricA == metricA && $0.metricB == metricB) ||
            ($0.metricA == metricB && $0.metricB == metricA)
        }

        if let corr = match {
            let strength = abs(corr.pearsonR) >= 0.7 ? "strong" : abs(corr.pearsonR) >= 0.4 ? "moderate" : abs(corr.pearsonR) >= 0.2 ? "mild" : "very weak"
            let direction = corr.pearsonR > 0 ? "move together" : "move in opposite directions"

            var answer = "Yes. there's a \(strength) link between your \(metricA.displayName) and \(metricB.displayName). They tend to \(direction) (r=\(String(format: "%.2f", corr.pearsonR)))."

            if corr.grangerCausal {
                let lagText = corr.grangerOptimalLag == 1 ? "about a day" : "about \(corr.grangerOptimalLag) days"
                answer += " In fact, changes in \(corr.metricA.displayName) seem to predict changes in \(corr.metricB.displayName) \(lagText) later."
            }

            return QueryResult(
                question: "Does \(metricA.displayName) affect \(metricB.displayName)?",
                answer: answer,
                dataPoints: [
                    .init(label: "Correlation", value: corr.pearsonR, unit: "r", date: nil),
                    .init(label: "Stability", value: corr.stability, unit: "", date: nil),
                ],
                confidence: corr.stability,
                relatedQuestions: [
                    "How is my \(metricA.displayName) trending?",
                    "What else affects my \(metricB.displayName)?",
                ]
            )
        }

        return QueryResult(
            question: "Does \(metricA.displayName) affect \(metricB.displayName)?",
            answer: "I haven't found a clear connection between your \(metricA.displayName) and \(metricB.displayName) yet. As more data comes in, patterns may emerge. keep tracking.",
            dataPoints: [],
            confidence: 0.5,
            relatedQuestions: [
                "What correlates with my \(metricA.displayName)?",
                "What affects my \(metricB.displayName)?",
            ]
        )
    }

    private func answerForecast(metric: HealthMetric, horizon: Int, ctx: QueryContext) -> QueryResult {
        guard let forecast = ctx.forecasts[metric],
              let result = forecast.horizons.first(where: { $0.horizon == horizon }) ?? forecast.horizons.first else {
            return QueryResult(
                question: "What will my \(metric.displayName) be?",
                answer: "I don't have enough history to forecast your \(metric.displayName) yet. I need at least 21 days of data. In the meantime, I can tell you about your current trend.",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: ["How is my \(metric.displayName) trending?"]
            )
        }

        let when = horizon == 1 ? "tomorrow" : "in \(horizon) days"
        let answer = "Based on your patterns, I'm expecting your \(metric.displayName) to land around \(formatValue(result.value, metric: metric)) \(when). The range could be anywhere from \(formatValue(result.ciLower, metric: metric)) to \(formatValue(result.ciUpper, metric: metric)), depending on how today goes."

        return QueryResult(
            question: "What will my \(metric.displayName) be \(when)?",
            answer: answer,
            dataPoints: [
                .init(label: "Predicted", value: result.value, unit: metric.unit, date: nil),
                .init(label: "Low end", value: result.ciLower, unit: metric.unit, date: nil),
                .init(label: "High end", value: result.ciUpper, unit: metric.unit, date: nil),
            ],
            confidence: max(0.3, 1.0 - result.ciWidth / max(1, result.value)),
            relatedQuestions: [
                "How is my \(metric.displayName) trending?",
                "What affects my \(metric.displayName)?",
            ]
        )
    }

    private func answerAnomaly(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        let metricsToCheck: [HealthMetric] = metric.map { [$0] } ?? Array(ctx.timeSeries.keys.prefix(15))

        var anomalies: [(metric: HealthMetric, deviation: Double, value: Double)] = []
        for m in metricsToCheck {
            guard let series = ctx.timeSeries[m], let latest = series.samples.last,
                  let baseline = ctx.baselines[m] else { continue }
            let dev = abs(latest.value - baseline.mean) / max(1, baseline.standardDeviation)
            if dev > 2.0 { anomalies.append((m, dev, latest.value)) }
        }

        if anomalies.isEmpty {
            return QueryResult(
                question: "Anything unusual?",
                answer: "Everything looks within your normal ranges right now. No spikes, no dips. your body is humming along as expected.",
                dataPoints: [],
                confidence: 0.7,
                relatedQuestions: ["How am I doing overall?", "Am I at risk for anything?"]
            )
        }

        anomalies.sort { $0.deviation > $1.deviation }
        let top = anomalies[0]
        let dir = (ctx.baselines[top.metric].map { top.value > $0.mean } ?? true) ? "higher" : "lower"
        var answer = "Your \(top.metric.displayName) is standing out right now. \(formatValue(top.value, metric: top.metric)) is significantly \(dir) than usual (\(String(format: "%.1f", top.deviation))x your normal variation)."
        if anomalies.count > 1 {
            let others = anomalies.dropFirst().prefix(2).map { $0.metric.displayName }.joined(separator: " and ")
            answer += " I'm also seeing unusual readings in your \(others)."
        }

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

    private func answerBestWorst(metric: HealthMetric, seeking: QueryIntent.BestWorst, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric], !series.samples.isEmpty else {
            return noDataResult(for: metric)
        }

        let sorted = series.samples.sorted { $0.value < $1.value }
        let target = seeking == .best
            ? (metric.higherIsBetter ? sorted.last! : sorted.first!)
            : (metric.higherIsBetter ? sorted.first! : sorted.last!)

        let dateStr = DateFormatter.localizedString(from: target.date, dateStyle: .medium, timeStyle: .none)
        let label = seeking == .best ? "best" : "worst"

        let answer = "Your \(label) \(metric.displayName) on record was \(formatValue(target.value, metric: metric)), recorded on \(dateStr). \(seeking == .best ? "That's a solid benchmark to work toward again." : "Everyone has off days. what matters is the overall trajectory.")"

        return QueryResult(
            question: "What was my \(label) \(metric.displayName)?",
            answer: answer,
            dataPoints: [.init(label: label.capitalized, value: target.value, unit: metric.unit, date: target.date)],
            confidence: 0.95,
            relatedQuestions: [
                "How is my \(metric.displayName) trending?",
                "What was my \(seeking == .best ? "worst" : "best") \(metric.displayName)?",
            ]
        )
    }

    private func answerStatus(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        guard let m = metric, let series = ctx.timeSeries[m] else {
            return answerGeneral(question: "status", ctx: ctx)
        }

        let recent = recentSamples(from: series, days: 7)
        guard !recent.isEmpty else { return noDataResult(for: m) }

        let avg = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let latest = recent.last?.value ?? avg

        var answer = "Your \(m.displayName) is currently at \(formatValue(latest, metric: m)), with a 7-day average of \(formatValue(avg, metric: m)). "

        if let baseline = ctx.baselines[m] {
            let dev = (avg - baseline.mean) / max(1, baseline.standardDeviation)
            if dev > 1 {
                answer += metric?.higherIsBetter == true
                    ? "That's above your personal baseline. nice work."
                    : "That's running a bit high compared to your baseline."
            } else if dev < -1 {
                answer += metric?.higherIsBetter == true
                    ? "That's below your usual baseline. might be worth paying attention to."
                    : "That's below your baseline, which is a good sign."
            } else {
                answer += "Right in line with your normal range."
            }
        }

        return QueryResult(
            question: "How is my \(m.displayName)?",
            answer: answer,
            dataPoints: [
                .init(label: "Current", value: latest, unit: m.unit, date: recent.last?.date),
                .init(label: "7-day avg", value: avg, unit: m.unit, date: nil),
            ],
            confidence: 0.85,
            relatedQuestions: [
                "How is my \(m.displayName) trending?",
                "What affects my \(m.displayName)?",
                "Predict my \(m.displayName) for tomorrow",
            ]
        )
    }

    // MARK: - Answer Generators (New. ML Pipeline)

    private func answerHealthState(ctx: QueryContext) -> QueryResult {
        guard let state = ctx.currentHealthState else {
            return QueryResult(
                question: "How is my body doing?",
                answer: "I'm still building your personal health profile. I need a few more days of data before I can classify your body's state. In the meantime, everything I'm tracking looks within expected ranges.",
                dataPoints: [],
                confidence: 0.4,
                relatedQuestions: ["Am I at risk for anything?", "How is my HRV trending?"]
            )
        }

        let topTraits = state.characteristics.prefix(4)
        let traitDescriptions = topTraits.map { trait -> String in
            switch trait.level {
            case .high: return "\(trait.metric.displayName) is elevated"
            case .low: return "\(trait.metric.displayName) is on the low side"
            case .normal: return "\(trait.metric.displayName) is right where it should be"
            }
        }

        let durationNote = state.daysInState > 1
            ? "You've been in this state for \(state.daysInState) days. "
            : ""

        let traitList = traitDescriptions.joined(separator: ", ")
        let answer = "Your body is currently in a \"\(state.label)\" state. \(traitList). \(durationNote)\(healthStateConclusion(state: state))"

        let dataPoints: [QueryResult.DataPoint] = topTraits.map {
            .init(label: $0.metric.displayName, value: $0.zScore, unit: "z", date: nil)
        }

        return QueryResult(
            question: "What state is my body in?",
            answer: answer,
            dataPoints: dataPoints,
            confidence: 0.8,
            relatedQuestions: [
                "Am I at risk for anything?",
                "What should I do today?",
                "How is my HRV trending?",
            ]
        )
    }

    private func answerRisk(ctx: QueryContext) -> QueryResult {
        guard let report = ctx.healthSignalReport else {
            if let risk = ctx.tomorrowRiskPrediction {
                let pct = Int(risk.probability * 100)
                let answer = pct > 50
                    ? "Based on your recent data, there's a \(pct)% chance tomorrow could be a rough day. \(riskFactorSummary(risk.topFactors))"
                    : "Looking ahead, your risk of a bad day tomorrow is low (\(pct)%). You're in a good position."
                return QueryResult(
                    question: "Am I at risk?",
                    answer: answer,
                    dataPoints: [.init(label: "Tomorrow risk", value: risk.probability * 100, unit: "%", date: nil)],
                    confidence: risk.confidence,
                    relatedQuestions: ["What state is my body in?", "What should I do today?"]
                )
            }
            return QueryResult(
                question: "Am I at risk?",
                answer: "I don't have enough data yet to assess your health risks. Keep wearing your device. the more data I have, the better I can watch out for you.",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: ["How am I doing overall?"]
            )
        }

        // Collect all signals and sort by severity
        let signals: [(name: String, risk: PredictiveHealthSignals.RiskLevel, score: Double, explanation: String, recommendation: String)] = [
            (report.fatigueScore.signalName, report.fatigueScore.riskLevel, report.fatigueScore.score, report.fatigueScore.explanation, report.fatigueScore.recommendation),
            (report.burnoutRisk.signalName, report.burnoutRisk.riskLevel, report.burnoutRisk.score, report.burnoutRisk.explanation, report.burnoutRisk.recommendation),
            (report.overtrainingRisk.signalName, report.overtrainingRisk.riskLevel, report.overtrainingRisk.score, report.overtrainingRisk.explanation, report.overtrainingRisk.recommendation),
            (report.insomniaRisk.signalName, report.insomniaRisk.riskLevel, report.insomniaRisk.score, report.insomniaRisk.explanation, report.insomniaRisk.recommendation),
            (report.immuneRisk.signalName, report.immuneRisk.riskLevel, report.immuneRisk.score, report.immuneRisk.explanation, report.immuneRisk.recommendation),
            (report.inactivityAlert.signalName, report.inactivityAlert.riskLevel, report.inactivityAlert.score, report.inactivityAlert.explanation, report.inactivityAlert.recommendation),
        ]

        let elevated = signals.filter { $0.risk >= .moderate }.sorted { $0.score > $1.score }

        if elevated.isEmpty {
            var answer = "No significant health risks detected. your fatigue, burnout, overtraining, sleep, immune, and activity signals all look healthy."
            if let risk = ctx.tomorrowRiskPrediction, risk.probability < 0.3 {
                answer += " Tomorrow is looking good too."
            }
            return QueryResult(
                question: "Am I at risk?",
                answer: answer,
                dataPoints: [],
                confidence: 0.85,
                relatedQuestions: ["What state is my body in?", "How is my HRV trending?"]
            )
        }

        let top = elevated[0]
        var answer = "Heads up. your \(top.name.lowercased()) is \(top.risk == .critical ? "at a critical level" : top.risk == .high ? "elevated" : "worth watching"). \(top.explanation) \(top.recommendation)"
        if elevated.count > 1 {
            let others = elevated.dropFirst().prefix(2).map { $0.name.lowercased() }.joined(separator: " and ")
            answer += " I'm also keeping an eye on your \(others)."
        }

        return QueryResult(
            question: "Am I at risk?",
            answer: answer,
            dataPoints: elevated.prefix(3).map {
                .init(label: $0.name, value: $0.score * 100, unit: "%", date: nil)
            },
            confidence: 0.85,
            relatedQuestions: [
                "What should I do today?",
                "What state is my body in?",
                "How is my sleep trending?",
            ]
        )
    }

    private func answerOptimization(ctx: QueryContext) -> QueryResult {
        // Try ideal day first
        if let ideal = ctx.idealDay, !ideal.targets.isEmpty {
            let topTargets = ideal.targets.prefix(4)
            let targetLines = topTargets.map { target -> String in
                "\(target.metric.displayName): aim for \(formatValue(target.targetValue, metric: target.metric))"
            }
            let targetList = targetLines.joined(separator: "; ")

            var answer = "For your best days, here's what your data says to target. \(targetList). When you hit these numbers, your predicted score is \(Int(ideal.predictedScore))."

            // Add gap info from optimal profile
            if let profile = ctx.optimalProfile {
                let unmet = profile.conditions.filter { !$0.isCurrentlyMet }.prefix(2)
                if !unmet.isEmpty {
                    let gaps = unmet.map { $0.metric.displayName }.joined(separator: " and ")
                    answer += " Right now, your \(gaps) \(unmet.count == 1 ? "is" : "are") the biggest gap between where you are and where you could be."
                }
            }

            return QueryResult(
                question: "How do I have a great day?",
                answer: answer,
                dataPoints: topTargets.map {
                    .init(label: $0.metric.displayName, value: $0.targetValue, unit: $0.metric.unit, date: nil)
                },
                confidence: ideal.confidence,
                relatedQuestions: [
                    "What state is my body in?",
                    "Why is my score what it is?",
                    "Am I at risk for anything?",
                ]
            )
        }

        // Fallback to sensitivities
        if !ctx.scoreSensitivities.isEmpty {
            let top = ctx.scoreSensitivities.sorted { abs($0.slope) > abs($1.slope) }.prefix(3)
            let levers = top.map { "\($0.metric.displayName) (\($0.description))" }.joined(separator: "; ")

            return QueryResult(
                question: "How do I improve?",
                answer: "The metrics with the biggest impact on your score are: \(levers). Small improvements here will move the needle the most.",
                dataPoints: top.map { .init(label: $0.metric.displayName, value: $0.slope, unit: "pts/σ", date: nil) },
                confidence: 0.7,
                relatedQuestions: top.map { "How is my \($0.metric.displayName) trending?" }
            )
        }

        return QueryResult(
            question: "How do I improve?",
            answer: "I need more data to build your personal optimization profile. about 30 days of tracking. Keep going and I'll learn what makes your best days tick.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: ["How am I doing overall?", "Am I at risk for anything?"]
        )
    }

    private func answerPattern(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        let patterns: [DiscoveredPattern]
        if let m = metric {
            patterns = ctx.discoveredPatterns.filter { $0.metric == m }
        } else {
            patterns = ctx.discoveredPatterns
        }

        let strong = patterns.filter { $0.strength > 0.3 }.sorted { $0.strength > $1.strength }

        guard let top = strong.first else {
            let target = metric?.displayName ?? "your metrics"
            return QueryResult(
                question: "Any patterns?",
                answer: "I haven't found any strong recurring patterns in \(target) yet. These usually emerge after 2-3 weeks of consistent tracking as I look for weekly and monthly rhythms.",
                dataPoints: [],
                confidence: 0.4,
                relatedQuestions: ["How is my HRV trending?", "Anything unusual in my data?"]
            )
        }

        var answer = "Yes. your \(top.metric.displayName) follows a clear \(top.patternType.rawValue) cycle."
        if let peakDay = top.peakDayOfWeek, let troughDay = top.troughDayOfWeek {
            answer += " It tends to peak on \(weekdayName(peakDay))s and dip on \(weekdayName(troughDay))s."
        }
        if let peakVal = top.peakMeanValue, let troughVal = top.troughMeanValue {
            answer += " The swing is about \(formatValue(peakVal - troughVal, metric: top.metric)) \(top.metric.unit) between highs and lows."
        }

        if strong.count > 1 {
            let others = strong.dropFirst().prefix(2).map { "\($0.metric.displayName) (\($0.patternType.rawValue))" }.joined(separator: ", ")
            answer += " I also see patterns in \(others)."
        }

        return QueryResult(
            question: "Any patterns in my data?",
            answer: answer,
            dataPoints: strong.prefix(3).map {
                .init(label: $0.metric.displayName, value: $0.strength * 100, unit: "% strength", date: nil)
            },
            confidence: Double(top.strength),
            relatedQuestions: [
                "How is my \(top.metric.displayName) trending?",
                "Does sleep affect my \(top.metric.displayName)?",
            ]
        )
    }

    private func answerCircadian(ctx: QueryContext) -> QueryResult {
        guard let profile = ctx.circadianProfile else {
            return QueryResult(
                question: "When should I work out?",
                answer: "I need more data to map your body clock. After about 2 weeks of consistent wear, I'll know your chronotype and can suggest optimal timing for workouts, sleep, and focused work.",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: ["How is my sleep trending?", "Do I have any patterns?"]
            )
        }

        let chronotype = profile.chronotype.rawValue
        var answer = "You're a \(chronotype). Your body's activity peak is around \(formatHour(profile.activityAcrophaseHour)), and your heart rate hits its lowest point around \(formatHour(profile.hrNadirHour))."

        if let hrvPeak = profile.hrvAcrophaseHour {
            answer += " Your HRV. a key recovery marker. peaks around \(formatHour(hrvPeak))."
        }

        if !ctx.timingRecommendations.isEmpty {
            let recs = ctx.timingRecommendations.prefix(3)
            let timingLines = recs.map { rec -> String in
                "\(rec.activity.rawValue): \(formatHour(Double(rec.optimalWindowStart)))-\(formatHour(Double(rec.optimalWindowEnd)))"
            }
            answer += " Based on all this, here are your optimal windows. \(timingLines.joined(separator: "; "))."
        }

        return QueryResult(
            question: "What's my body clock like?",
            answer: answer,
            dataPoints: [
                .init(label: "Activity peak", value: profile.activityAcrophaseHour, unit: "hr", date: nil),
                .init(label: "HR nadir", value: profile.hrNadirHour, unit: "hr", date: nil),
            ],
            confidence: profile.confidence,
            relatedQuestions: [
                "Do I have any weekly patterns?",
                "How is my sleep trending?",
                "What should I do today?",
            ]
        )
    }

    private func answerWhyScore(ctx: QueryContext) -> QueryResult {
        let score = ctx.overallScore
        let sentiment: Sentiment = score > 75 ? .positive : score >= 50 ? .neutral : .negative

        // Use score sensitivities to explain
        if !ctx.scoreSensitivities.isEmpty {
            let sorted = ctx.scoreSensitivities.sorted { abs($0.slope) > abs($1.slope) }
            let topDrivers = sorted.prefix(3)

            // Check which drivers are currently dragging or boosting
            var dragging: [String] = []
            var boosting: [String] = []

            for driver in topDrivers {
                if let baseline = ctx.baselines[driver.metric],
                   let series = ctx.timeSeries[driver.metric],
                   let latest = series.samples.last {
                    let dev = (latest.value - baseline.mean) / max(1, baseline.standardDeviation)
                    let isBad = (dev < -0.5 && driver.metric.higherIsBetter) || (dev > 0.5 && !driver.metric.higherIsBetter)
                    if isBad {
                        dragging.append(driver.metric.displayName)
                    } else if (dev > 0.5 && driver.metric.higherIsBetter) || (dev < -0.5 && !driver.metric.higherIsBetter) {
                        boosting.append(driver.metric.displayName)
                    }
                }
            }

            var answer = "Your score is \(score). "
            if !dragging.isEmpty {
                answer += "The biggest thing pulling it down right now is your \(dragging.joined(separator: " and ")). "
            }
            if !boosting.isEmpty {
                answer += "On the bright side, your \(boosting.joined(separator: " and ")) \(boosting.count == 1 ? "is" : "are") helping. "
            }
            if dragging.isEmpty && boosting.isEmpty {
                answer += "All your key metrics are close to baseline. no single factor is dominating. "
            }
            answer += conclusion(sentiment)

            return QueryResult(
                question: "Why is my score \(score)?",
                answer: answer,
                dataPoints: topDrivers.map {
                    .init(label: $0.metric.displayName, value: $0.slope, unit: "pts/σ", date: nil)
                },
                confidence: 0.8,
                relatedQuestions: [
                    "How do I improve my score?",
                    dragging.first.map { "How is my \($0) trending?" } ?? "Am I at risk for anything?",
                    "What state is my body in?",
                ]
            )
        }

        // Simple fallback
        let answer = "Your score is \(score). \(conclusion(sentiment)) I need about 30 days of data to break down exactly what's driving it."
        return QueryResult(
            question: "Why is my score \(score)?",
            answer: answer,
            dataPoints: [.init(label: "Score", value: Double(score), unit: "", date: nil)],
            confidence: 0.5,
            relatedQuestions: ["How am I doing overall?", "Am I at risk for anything?"]
        )
    }

    private func answerCausal(metric: HealthMetric, ctx: QueryContext) -> QueryResult {
        // Find Granger-causal relationships targeting this metric
        let causalRelations = ctx.correlations.filter {
            $0.grangerCausal && ($0.metricB == metric || $0.metricA == metric)
        }.sorted { abs($0.grangerEffectSize) > abs($1.grangerEffectSize) }

        if !causalRelations.isEmpty {
            let topCauses = causalRelations.prefix(3)
            var answer = "Here's what your data shows drives your \(metric.displayName):"
            for cause in topCauses {
                let driver = cause.metricA == metric ? cause.metricB : cause.metricA
                let lagText = cause.grangerOptimalLag == 1 ? "the next day" : "\(cause.grangerOptimalLag) days later"
                let direction = cause.pearsonR > 0 ? "higher" : "lower"
                answer += " When your \(driver.displayName) goes up, your \(metric.displayName) tends to go \(direction) \(lagText)."
            }

            // Check temporal sequences for richer chains
            let relevantSequences = ctx.temporalSequences.filter {
                $0.steps.contains { $0.metric == metric }
            }.prefix(1)

            if let seq = relevantSequences.first {
                answer += " \(seq.description)"
            }

            return QueryResult(
                question: "What causes my \(metric.displayName) to change?",
                answer: answer,
                dataPoints: topCauses.map {
                    let driver = $0.metricA == metric ? $0.metricB : $0.metricA
                    return .init(label: driver.displayName, value: $0.grangerEffectSize, unit: "effect", date: nil)
                },
                confidence: 0.8,
                relatedQuestions: [
                    "How is my \(metric.displayName) trending?",
                    topCauses.first.map {
                        let d = $0.metricA == metric ? $0.metricB : $0.metricA
                        return "How is my \(d.displayName) doing?"
                    } ?? "Do I have any patterns?",
                ]
            )
        }

        // Fallback: use correlations (non-causal)
        let correlated = ctx.correlations.filter {
            ($0.metricA == metric || $0.metricB == metric) && abs($0.pearsonR) > 0.3
        }.sorted { abs($0.pearsonR) > abs($1.pearsonR) }

        if let top = correlated.first {
            let other = top.metricA == metric ? top.metricB : top.metricA
            let answer = "I haven't established clear causal links for your \(metric.displayName) yet, but it's correlated with your \(other.displayName) (r=\(String(format: "%.2f", top.pearsonR))). As I gather more data, I'll be able to tell you what actually drives the changes. not just what moves alongside them."
            return QueryResult(
                question: "What causes my \(metric.displayName) to change?",
                answer: answer,
                dataPoints: [.init(label: other.displayName, value: top.pearsonR, unit: "r", date: nil)],
                confidence: 0.6,
                relatedQuestions: [
                    "Does \(other.displayName) affect \(metric.displayName)?",
                    "How is my \(metric.displayName) trending?",
                ]
            )
        }

        return QueryResult(
            question: "What causes my \(metric.displayName) to change?",
            answer: "I need more data to figure out what drives your \(metric.displayName). Causal analysis requires about 30 days of history. keep tracking and I'll map out the relationships.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: ["How is my \(metric.displayName) trending?"]
        )
    }

    // MARK: - General (Enhanced)

    // MARK: - Conversational Handling

    private static let greetings: Set<String> = [
        "hi", "hey", "hello", "hola", "yo", "sup", "hii", "hiii",
        "good morning", "good afternoon", "good evening", "gm",
        "what's up", "whats up", "howdy",
    ]

    private static let thanks: Set<String> = [
        "thanks", "thank you", "thx", "ty", "thank u", "cheers", "appreciated",
    ]

    private static let farewells: Set<String> = [
        "bye", "goodbye", "see you", "later", "cya", "take care",
    ]

    private func handleConversational(_ question: String, ctx: QueryContext) -> QueryResult? {
        let words = question.components(separatedBy: .whitespaces).joined(separator: " ")

        // Greetings
        if Self.greetings.contains(words) || Self.greetings.contains(where: { words.hasPrefix($0) && words.count < $0.count + 3 }) {
            let scorePhrase: String
            switch ctx.overallScore {
            case 85...100: scorePhrase = "You're doing great. your health score is \(ctx.overallScore)."
            case 70..<85: scorePhrase = "Your health score is \(ctx.overallScore), looking solid."
            case 50..<70: scorePhrase = "Your health score is \(ctx.overallScore). some room to improve."
            default: scorePhrase = "Your health score is \(ctx.overallScore). let's work on that."
            }

            let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
            let trackingNote = metricCount > 0
                ? "I'm keeping an eye on \(metricCount) metrics for you."
                : "Connect a device so I can start tracking your health."

            return QueryResult(
                question: question,
                answer: "Hey! \(scorePhrase) \(trackingNote) Ask me anything. like \"How's my sleep?\" or \"Am I at risk for anything?\"",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    "How am I doing overall?",
                    "What should I focus on?",
                    "Any health risks?",
                ]
            )
        }

        // Thanks
        if Self.thanks.contains(words) || Self.thanks.contains(where: { words.hasPrefix($0) }) {
            return QueryResult(
                question: question,
                answer: "Happy to help! I'm here whenever you want to check in on your health.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    "How am I doing overall?",
                    "What's my best metric?",
                    "Any patterns in my data?",
                ]
            )
        }

        // Farewells
        if Self.farewells.contains(words) || Self.farewells.contains(where: { words.hasPrefix($0) }) {
            return QueryResult(
                question: question,
                answer: "Take care! I'll keep watching your data in the background.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: []
            )
        }

        return nil
    }

    private func answerGeneral(question: String, ctx: QueryContext) -> QueryResult {
        // 1. Surface compound insights first (richest, most synthesized)
        if let topInsight = ctx.compoundInsights.sorted(by: { $0.surpriseScore > $1.surpriseScore }).first,
           topInsight.surpriseScore > 0.3 {
            return QueryResult(
                question: question,
                answer: topInsight.narrative + (topInsight.isActionable ? " " + topInsight.recommendation : ""),
                dataPoints: topInsight.involvedMetrics.prefix(3).compactMap { metric in
                    guard let series = ctx.timeSeries[metric],
                          let latest = series.samples.last else { return nil }
                    return QueryResult.DataPoint(label: metric.displayName, value: latest.value, unit: metric.unit, date: latest.date)
                },
                confidence: topInsight.confidence,
                relatedQuestions: [
                    "Am I at risk for anything?",
                    "What state is my body in?",
                    topInsight.involvedMetrics.first.map { "How is my \($0.displayName) trending?" } ?? "What should I do today?",
                ]
            )
        }

        // 2. Health signal warnings
        if let report = ctx.healthSignalReport {
            let signals: [(String, PredictiveHealthSignals.RiskLevel, String)] = [
                (report.fatigueScore.signalName, report.fatigueScore.riskLevel, report.fatigueScore.explanation),
                (report.burnoutRisk.signalName, report.burnoutRisk.riskLevel, report.burnoutRisk.explanation),
                (report.overtrainingRisk.signalName, report.overtrainingRisk.riskLevel, report.overtrainingRisk.explanation),
                (report.insomniaRisk.signalName, report.insomniaRisk.riskLevel, report.insomniaRisk.explanation),
                (report.immuneRisk.signalName, report.immuneRisk.riskLevel, report.immuneRisk.explanation),
                (report.inactivityAlert.signalName, report.inactivityAlert.riskLevel, report.inactivityAlert.explanation),
            ]
            if let warning = signals.filter({ $0.1 >= .high }).first {
                return QueryResult(
                    question: question,
                    answer: "Something worth your attention: \(warning.2)",
                    dataPoints: [],
                    confidence: 0.8,
                    relatedQuestions: ["Am I at risk for anything?", "What should I do today?"]
                )
            }
        }

        // 3. Biggest trend mover
        let sortedTrends = ctx.trends.sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
        if let top = sortedTrends.first, abs(top.value.weekOverWeekChange) > 5 {
            let dir = top.value.weekOverWeekChange > 0 ? "up" : "down"
            let answer = "Here's what stands out: your \(top.key.displayName) is moving \(dir) \(String(format: "%.0f%%", abs(top.value.weekOverWeekChange))) week over week. That's the biggest shift in your data right now."
            return QueryResult(
                question: question,
                answer: answer,
                dataPoints: [.init(label: "Change", value: top.value.weekOverWeekChange, unit: "%", date: nil)],
                confidence: 0.7,
                relatedQuestions: [
                    "How is my \(top.key.displayName) trending?",
                    "What affects my \(top.key.displayName)?",
                ]
            )
        }

        // 4. Strongest correlation discovery
        if let topCorr = ctx.correlations.sorted(by: { abs($0.pearsonR) > abs($1.pearsonR) }).first,
           abs(topCorr.pearsonR) > 0.4 {
            let dir = topCorr.pearsonR > 0 ? "move together" : "move in opposite directions"
            return QueryResult(
                question: question,
                answer: "Interesting discovery: your \(topCorr.metricA.displayName) and \(topCorr.metricB.displayName) \(dir) (r=\(String(format: "%.2f", topCorr.pearsonR))). This is one of the strongest connections in your data.",
                dataPoints: [.init(label: "Correlation", value: topCorr.pearsonR, unit: "r", date: nil)],
                confidence: 0.7,
                relatedQuestions: [
                    "Does \(topCorr.metricA.displayName) affect \(topCorr.metricB.displayName)?",
                    "How is my \(topCorr.metricA.displayName) doing?",
                ]
            )
        }

        // 5. True fallback
        let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
        if metricCount == 0 {
            return QueryResult(
                question: question,
                answer: "No health data yet. Once you connect your Apple Watch or allow Health access, I'll start learning about your body and can answer questions like \"How is my HRV trending?\" or \"Am I at risk for anything?\"",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: []
            )
        }

        return QueryResult(
            question: question,
            answer: "I'm tracking \(metricCount) metrics and everything looks within normal ranges right now. Try asking about a specific metric, or ask me things like \"Am I at risk?\" or \"What should I do today?\" to dig deeper.",
            dataPoints: [],
            confidence: 0.6,
            relatedQuestions: [
                "Am I at risk for anything?",
                "What state is my body in?",
                "Do I have any patterns?",
            ]
        )
    }

    // MARK: - Response Composition

    private enum Sentiment { case positive, neutral, negative }

    private func openingPhrase(_ sentiment: Sentiment) -> String {
        let options: [String]
        switch sentiment {
        case .positive:
            options = ["Good news. ", "Things are looking good. ", "Here's something encouraging: ", ""]
        case .neutral:
            options = ["Here's what I see: ", "Looking at your data. ", "", ""]
        case .negative:
            options = ["Something to note. ", "Worth paying attention: ", "Heads up. ", ""]
        }
        return options[abs(Date().hashValue) % options.count]
    }

    private func conclusion(_ sentiment: Sentiment) -> String {
        switch sentiment {
        case .positive: return "Keep doing what you're doing."
        case .neutral: return "Keep an eye on this over the next few days."
        case .negative: return "Small adjustments now can make a real difference."
        }
    }

    private func trendInterpretation(metric: HealthMetric, pctChange: Double, sentiment: Sentiment) -> String {
        if abs(pctChange) < 2 { return "Consistency is a strength. your body likes this routine." }
        switch sentiment {
        case .positive: return "Your body is responding well to whatever you've been doing."
        case .neutral: return "Keep tracking to see if this shift continues or levels off."
        case .negative: return "This might be worth investigating if it continues."
        }
    }

    private func healthStateConclusion(state: HealthState) -> String {
        let label = state.label.lowercased()
        if label.contains("recovery") || label.contains("resting") {
            return "Your body is in repair mode. honor that with lighter activity."
        }
        if label.contains("peak") || label.contains("performance") || label.contains("active") {
            return "You're primed for a strong effort today."
        }
        if label.contains("stress") || label.contains("fatigue") {
            return "Your nervous system is under load. prioritize rest and sleep tonight."
        }
        return "Listen to how you're feeling and adjust your day accordingly."
    }

    private func riskFactorSummary(_ factors: [PredictionFactor]) -> String {
        let riskFactors = factors.filter { $0.isRiskFactor }.prefix(2)
        if riskFactors.isEmpty { return "" }
        let names = riskFactors.map { $0.metric.displayName }.joined(separator: " and ")
        return "The main drivers are your \(names)."
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
        case .bodyTemperature, .appleSleepingWristTemperature:
            return String(format: "%.1f°F", value)
        case .weight:
            return String(format: "%.1f lbs", value)
        case .vo2Max:
            return String(format: "%.1f", value)
        case .bloodOxygen:
            return String(format: "%.0f%%", value * 100)
        case .exerciseMinutes, .mindfulMinutes:
            return String(format: "%.0f min", value)
        case .activeCalories, .basalCalories, .totalCaloriesIntake:
            return String(format: "%.0f kcal", value)
        case .waterIntake:
            return String(format: "%.0f mL", value)
        default:
            if value > 1000 { return String(format: "%.0f", value) }
            if value > 10 { return String(format: "%.1f", value) }
            return String(format: "%.2f", value)
        }
    }

    private func noDataResult(for metric: HealthMetric) -> QueryResult {
        QueryResult(
            question: "About \(metric.displayName)",
            answer: "I don't have enough \(metric.displayName) data yet. Keep wearing your device and I'll be able to answer this soon.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: ["What data do I have?"]
        )
    }

    private func weekdayName(_ day: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return (day >= 1 && day <= 7) ? names[day - 1] : "day \(day)"
    }

    private func formatHour(_ hour: Double) -> String {
        let h = Int(hour) % 24
        let m = Int((hour - Double(Int(hour))) * 60)
        let period = h >= 12 ? "PM" : "AM"
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return m == 0 ? "\(displayH) \(period)" : "\(displayH):\(String(format: "%02d", m)) \(period)"
    }
}
